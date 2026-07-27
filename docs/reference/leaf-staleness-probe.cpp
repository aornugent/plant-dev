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

// Replay one segment from a whole Patch copy over the same ODE times, and return the
// worst absolute difference against `reference` (plus which node component carries it).
template <class Strat, class Env>
std::pair<double, int> replay(plant::Patch<Strat, Env> copy,
                              const std::vector<std::size_t>& added,
                              const std::vector<double>& times,
                              const std::vector<double>& reference,
                              const plant::Control& ctrl) {
  using Patch = plant::Patch<Strat, Env>;
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
Rcpp::List staleness_probe(double birth_rate, double lifetime, int segment) {
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

  // The leaf now holds END-OF-RUN state, because pass A ran to completion above.
  const auto deferred = replay<Strat, Env>(entering_A, added_k, times, leaving_ref, ctrl);

  // ---- Pass B: fresh SCM, walk to segment K, replay BEFORE advancing past it, so the
  // leaf holds exactly what pass A's leaf held entering K.
  plant::SCM<Strat, Env> B(p, env, ctrl);
  B.set_schedule(schedule);
  std::pair<double, int> inl = {NA_REAL, -1};
  for (std::size_t k = 0; !B.complete(); ++k) {
    if (k == K) {
      inl = replay<Strat, Env>(B.r_patch(), added_k, times, leaving_ref, ctrl);
      break;
    }
    B.run_next();
  }

  const std::vector<std::string> names = plant::Node<Strat, Env>::ode_names();
  return Rcpp::List::create(
      Rcpp::Named("ok") = true,
      Rcpp::Named("segment") = segment,
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
                                double lifetime = 20.0, int segment = 40) {
  if (model == "K93") return staleness_probe<plant::K93_Strategy>(birth_rate, lifetime, segment);
  if (model == "FF16") return staleness_probe<plant::FF16_Strategy>(birth_rate, lifetime, segment);
  if (model == "TF24") return staleness_probe<plant::TF24_Strategy>(birth_rate, lifetime, segment);
  Rcpp::stop("model must be K93, FF16 or TF24");
}
