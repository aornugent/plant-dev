/* Is TF24's inexact segment re-run caused by STALE SHARED LEAF STATE? A discriminating
 * test that needs no change to plant.
 *
 * The claim (v3-facts.md section 5, task #37): `Individual` holds a *pointer* to the
 * Strategy, so copying a Patch copies the Individuals but they all keep pointing at ONE
 * Strategy and therefore ONE `Leaf`, which carries per-solve state. In
 * segment-rerecord-probe.cpp the whole forward pass completes BEFORE any segment is
 * replayed, so every replay inherits END-OF-RUN leaf state rather than the state that
 * segment actually saw. TF24 is inexact there (1.8e-13 -> 1.3e-8); FF16 and K93 are
 * exactly 0 and have no leaf.
 *
 * If staleness is the cause, then replaying a segment while the leaf still holds that
 * segment's own state must be exact. That is the whole experiment:
 *
 *   DEFERRED  replay segment k after the full forward pass  -> leaf is end-of-run
 *   INLINE    replay segment k before the forward pass advances past it
 *                                                           -> leaf is entering-k
 *
 * Both are compared against the SAME reference: the undisturbed forward pass's state
 * leaving segment k.
 *
 * The confound this is built to avoid: a replay mutates the shared leaf, so an inline
 * replay would perturb the very forward pass it is compared against. Hence two
 * independent passes. Pass A runs undisturbed start to finish and supplies the
 * reference. Pass B is a fresh SCM that walks to segment k and replays the copy BEFORE
 * calling run_next, so its history up to k is undisturbed and its leaf holds exactly
 * what pass A's leaf held entering k.
 *
 * ---------------------------------------------------------------------------------------
 * QC (added 2026-07-27): THE ORIGINAL MEASUREMENT USED ONLY THE COPY PATH, WHICH IS NOT THE
 * PATH THE DESIGN USES. A code chain says a restored unit should get a FRESH leaf:
 *
 *   r_set_state -> reset()            patch.h:838, :325
 *   reset()     -> prepare_strategy() on every species
 *   TF24's prepare_strategy() does `leaf = Leaf(...)`     tf24_strategy.cpp:1112
 *   Leaf's ctor runs setup_clean_leaf(), fields -> NA_REAL   leaf_model.cpp:35
 *
 * So `restore_mode` selects how a replay is set up, giving all four cells:
 *
 *   0 COPY           advance the Patch copy directly (the original measurement)
 *   1 REBUILT        copy, then r_set_state from the stored PLAIN values (the design's unit)
 *   2 REBUILT+STAMPS mode 1 plus Species::set_birth_state, so the residual drift that §4b
 *                    attributes to the dropped stamps is removed and cannot be confused
 *                    with a leaf effect
 *
 * Mode 1 deliberately restores INTO A COPY rather than into a freshly-constructed Patch. A
 * fresh Patch would build its own Strategy and hence its own Leaf, so deferred and inline
 * would agree trivially -- for the wrong reason. Restoring into a copy keeps the shared-Leaf
 * ownership intact, so the question actually being asked is "does reset() clear it".
 *
 * POSITIVE CONTROL, and it decides whether the result means anything: mode 0 must STILL show
 * the deferred/inline split (1.84e-13 / 4.99e-11 / 1.30e-08 against exactly 0). If it does
 * not, this probe can no longer detect staleness at all and a null result in mode 1 is
 * indistinguishable from a broken probe -- conclude nothing.
 *
 * Everything is double -- this asks about reproduction, not derivatives.
 * Run from /home/user/plant-dev via docs/reference/leaf-staleness-probe.R.
 */

// [[Rcpp::depends(Rcpp, odelia, plant)]]
// [[Rcpp::plugins(cpp20)]]

#include <Rcpp.h>
#include <plant.h>
#include <plant/models/ff16_strategy.h>
#include <plant/models/k93_strategy.h>
#include <plant/models/tf24_strategy.h>
#include <plant/scm.h>
#include <odelia/ode_solver.hpp>

#include <algorithm>
#include <cmath>
#include <vector>

using namespace Rcpp;

namespace {

// Everything a mode-1/2 restore needs, read off the patch entering the segment.
struct Restore {
  std::vector<double> y;
  std::vector<std::size_t> counts;
  std::vector<double> light;
  std::vector<std::vector<double>> times, density, pr_survival;   // birth stamps, mode 2
  double t_in = 0.0;
};

template <class Strat, class Env>
Restore capture(const plant::Patch<Strat, Env>& pk, double t_in) {
  Restore r;
  r.t_in = t_in;
  r.y.assign(pk.ode_size(), 0.0);
  pk.ode_state(r.y.begin());
  for (std::size_t i = 0; i < pk.size(); ++i) {
    r.counts.push_back(pk.at_species(i).size());
    r.times.push_back(pk.at_species(i).node_times());
    r.density.push_back(pk.at_species(i).r_patch_densities());
    r.pr_survival.push_back(pk.at_species(i).r_pr_patch_survival_at_birth());
  }
  const Rcpp::NumericMatrix m = pk.r_environment().light_availability.r_get_state();
  r.light.assign(m.begin(), m.end());
  if (r.light.size() < 6) r.light = {0.0, 0.5, 1.0, 1.0, 1.0, 1.0};
  return r;
}

// No public mutable species accessor exists (patch.h:101 is const, `species` private), so a
// probe must cast. See restore-stamp-probe.cpp's header -- a real fix needs an API.
template <class Strat, class Env>
void apply_stamps(plant::Patch<Strat, Env>& p, const Restore& r) {
  for (std::size_t i = 0; i < p.size(); ++i) {
    auto& sp = const_cast<typename plant::Patch<Strat, Env>::species_type&>(p.at_species(i));
    sp.set_birth_state(r.times[i], r.density[i], r.pr_survival[i]);
  }
}

// Replay one segment over the same ODE times and return the worst absolute difference
// against `reference` (plus which node component carries it). `restore_mode` per the header.
template <class Strat, class Env>
std::pair<double, int> replay(plant::Patch<Strat, Env> copy,
                              const std::vector<std::size_t>& added,
                              const std::vector<double>& times,
                              const std::vector<double>& reference,
                              const plant::Control& ctrl,
                              int restore_mode = 0,
                              const Restore* r = nullptr) {
  using Patch = plant::Patch<Strat, Env>;
  if (restore_mode > 0 && r != nullptr) {
    // Into the COPY, so the shared Leaf is still shared when reset() runs.
    copy.r_set_state(r->t_in, r->y, r->counts, r->light);
    if (restore_mode == 2) apply_stamps<Strat, Env>(copy, *r);
  }
  copy.introduce_new_nodes(added);
  odelia::ode::Solver<Patch> s(copy, plant::make_ode_control(ctrl));
  s.set_collect(false);
  s.set_state_from_system();
  s.advance_fixed(times);
  const Patch& done = s.get_system_ref();
  std::vector<double> y(done.ode_size());
  done.ode_state(y.begin());
  if (y.size() != reference.size()) return {NA_REAL, -1};
  double ma = 0.0;
  std::size_t worst = 0;
  for (std::size_t i = 0; i < y.size(); ++i) {
    const double d = std::fabs(y[i] - reference[i]);
    if (d > ma) { ma = d; worst = i; }
  }
  const std::size_t per = plant::Node<Strat, Env>::ode_names().size();
  return {ma, static_cast<int>(worst % per)};
}

template <class Strat>
Rcpp::List staleness_probe(double birth_rate, double lifetime, int segment,
                           int restore_mode) {
  using Env = typename Strat::environment_type;
  using Patch = plant::Patch<Strat, Env>;

  Strat st;
  st.is_variable_birth_rate = false;
  st.birth_rate_y = {birth_rate};
  plant::Parameters<Strat, Env> p;
  p.strategies.push_back(st);
  p.max_patch_lifetime = lifetime;
  p.validate();
  plant::Control ctrl;
  Env env;

  plant::SCM<Strat, Env> sched(p, env, ctrl);
  sched.refine_schedule();
  const std::vector<double> schedule = sched.recorded_steps();
  const std::size_t K = static_cast<std::size_t>(segment);

  // ---- Pass A: undisturbed. Supplies the reference and the DEFERRED measurement.
  plant::SCM<Strat, Env> A(p, env, ctrl);
  A.set_schedule(schedule);
  Patch entering_A(p, env, ctrl);
  std::vector<double> leaving_ref;
  std::vector<std::size_t> added_k;
  double t_in_k = 0.0, t_out_k = 0.0;
  bool found = false;
  for (std::size_t k = 0; !A.complete(); ++k) {
    if (k == K) { entering_A = A.r_patch(); t_in_k = A.time(); }
    const std::vector<std::size_t> a = A.run_next();
    if (k == K) {
      added_k = a;
      t_out_k = A.time();
      const Patch& pk = A.r_patch();
      leaving_ref.resize(pk.ode_size());
      pk.ode_state(leaving_ref.begin());
      found = true;
    }
  }
  if (!found) return Rcpp::List::create(Rcpp::Named("ok") = false);

  std::vector<double> times;
  for (double t : schedule)
    if (t >= t_in_k - 1e-12 && t <= t_out_k + 1e-12) times.push_back(t);
  times.front() = t_in_k;
  times.back() = t_out_k;

  const Restore rest = capture<Strat, Env>(entering_A, t_in_k);

  // The leaf now holds END-OF-RUN state, because pass A ran to completion above.
  const auto deferred =
      replay<Strat, Env>(entering_A, added_k, times, leaving_ref, ctrl, restore_mode, &rest);

  // ---- Pass B: fresh SCM, walk to segment K, replay BEFORE advancing past it, so the
  // leaf holds exactly what pass A's leaf held entering K.
  plant::SCM<Strat, Env> B(p, env, ctrl);
  B.set_schedule(schedule);
  std::pair<double, int> inl = {NA_REAL, -1};
  for (std::size_t k = 0; !B.complete(); ++k) {
    if (k == K) {
      inl = replay<Strat, Env>(B.r_patch(), added_k, times, leaving_ref, ctrl,
                               restore_mode, &rest);
      break;
    }
    B.run_next();
  }

  const std::vector<std::string> names = plant::Node<Strat, Env>::ode_names();
  return Rcpp::List::create(
      Rcpp::Named("ok") = true,
      Rcpp::Named("segment") = segment,
      Rcpp::Named("restore_mode") = restore_mode,
      Rcpp::Named("steps_in_segment") = static_cast<int>(times.size() - 1),
      Rcpp::Named("deferred_abs") = deferred.first,
      Rcpp::Named("deferred_worst") =
          deferred.second >= 0 ? names[deferred.second] : std::string("-"),
      Rcpp::Named("inline_abs") = inl.first,
      Rcpp::Named("inline_worst") =
          inl.second >= 0 ? names[inl.second] : std::string("-"));
}

}  // namespace

// [[Rcpp::export]]
Rcpp::List leaf_staleness_probe(std::string model = "TF24", double birth_rate = 20.0,
                                double lifetime = 20.0, int segment = 40,
                                int restore_mode = 0) {
  if (model == "K93") return staleness_probe<plant::K93_Strategy>(birth_rate, lifetime, segment, restore_mode);
  if (model == "FF16") return staleness_probe<plant::FF16_Strategy>(birth_rate, lifetime, segment, restore_mode);
  if (model == "TF24") return staleness_probe<plant::TF24_Strategy>(birth_rate, lifetime, segment, restore_mode);
  Rcpp::stop("model must be K93, FF16 or TF24");
}

// QC-2 -- the OBJECT DIFF, not the inference. Read the TF24 leaf's per-solve fields on the
// patch entering a segment, then again after r_set_state, and report both. If the chain in
// the header holds, the `after` column is a clean leaf. The fields are public.
// [[Rcpp::export]]
Rcpp::List leaf_state_around_restore(double birth_rate = 20.0, double lifetime = 20.0,
                                     int segment = 40) {
  using Strat = plant::TF24_Strategy;
  using Env = Strat::environment_type;
  using Patch = plant::Patch<Strat, Env>;

  Strat st;
  st.is_variable_birth_rate = false;
  st.birth_rate_y = {birth_rate};
  plant::Parameters<Strat, Env> p;
  p.strategies.push_back(st);
  p.max_patch_lifetime = lifetime;
  p.validate();
  plant::Control ctrl;
  Env env;

  plant::SCM<Strat, Env> sched(p, env, ctrl);
  sched.refine_schedule();
  const std::vector<double> schedule = sched.recorded_steps();

  plant::SCM<Strat, Env> A(p, env, ctrl);
  A.set_schedule(schedule);
  Patch entering(p, env, ctrl);
  double t_in = 0.0;
  bool found = false;
  for (std::size_t k = 0; !A.complete(); ++k) {
    if (k == static_cast<std::size_t>(segment)) {
      entering = A.r_patch();
      t_in = A.time();
      found = true;
    }
    A.run_next();
  }
  if (!found) return Rcpp::List::create(Rcpp::Named("ok") = false);

  auto read_leaf = [](const Patch& pk) {
    // r_get_strategy() returns a temporary by value, so this is a snapshot -- which is
    // exactly what a before/after comparison wants.
    const auto strat = pk.at_species(0).node_begin()->individual.r_get_strategy();
    const auto& lf = strat.leaf;
    return Rcpp::NumericVector::create(
        Rcpp::Named("ci_") = lf.ci_,
        Rcpp::Named("profit_") = lf.profit_,
        Rcpp::Named("n_psi_soil_inverted") = static_cast<double>(lf.psi_soil_inverted_.size()),
        Rcpp::Named("n_root_vuln_integral_soil") =
            static_cast<double>(lf.root_vuln_integral_soil_.size()));
  };

  const Rcpp::NumericVector before = read_leaf(entering);
  const Restore rest = capture<Strat, Env>(entering, t_in);
  Patch after = entering;
  after.r_set_state(rest.t_in, rest.y, rest.counts, rest.light);
  const Rcpp::NumericVector aft = read_leaf(after);

  return Rcpp::List::create(Rcpp::Named("ok") = true,
                            Rcpp::Named("segment") = segment,
                            Rcpp::Named("before") = before,
                            Rcpp::Named("after") = aft);
}
