/* Is the step-local sweep's restore path lossy, and if so what is missing from it?
 *
 * `segment-rerecord-probe` measures two storage models and they disagree sharply:
 *
 *   from_copy_abs -- store a whole Patch per unit: EXACTLY 0 for K93/FF16
 *   rebuilt_abs   -- store plain values and restore (THE DESIGN'S PATH): drifts, and
 *                    the drift grows geometrically with segment index, reaching a
 *                    RELATIVE 14% (K93) and 45% (TF24) by segment 90
 *
 * The design stores plain values, so the second column is the one that matters, and a
 * 45% relative error would sink it. Settling twice does not fix it (that is the aux
 * lag, and for FF16 refreshing aux makes the match much WORSE -- the forward pass
 * genuinely uses the lagged value), and it is not the shared Leaf either, because the
 * copy path is exact for the leafless models and at the worst TF24 segments.
 *
 * The suspect is birth bookkeeping. `Patch::r_set_state` restores the ODE state, the
 * per-species node counts and the light spline -- and NOTHING ELSE. Each node also
 * carries three birth stamps (introduction time, patch density at birth,
 * pr_patch_survival_at_birth); the fecundity rate divides by the last of these, and
 * patch survival decays with patch age, so a wrong stamp costs more the later the
 * segment. That matches both the growth with segment index and where the error lands
 * (K93's worst component is `offspring_produced_survival_weighted`).
 *
 * This probe re-runs the rebuilt path twice -- without and with the stamps restored
 * via `Species::set_birth_state` -- and reports both against the same forward
 * reference. If the stamps are the cause, the second column collapses to the copy
 * path's exactness and the storage requirement is simply three doubles per node.
 *
 * DIAGNOSTIC SHORTCUT, and itself a finding: `Patch` exposes `at_species()` as const
 * only and keeps `species` private, so there is NO public way to restore birth stamps.
 * This probe const_casts to answer the question without changing plant's API mid-design.
 * A real fix needs a public entry point (extend `r_set_state`, most likely).
 *
 * Everything here is double -- this asks about reproduction, not derivatives. Run from
 * /home/user/plant-dev via docs/reference/restore-stamp-probe.R.
 */

// [[Rcpp::depends(Rcpp, odelia, plant)]]
// [[Rcpp::plugins(cpp20)]]

#include <Rcpp.h>
#include <plant.h>
#include <plant/models/k93_strategy.h>
#include <plant/models/ff16_strategy.h>
#include <plant/models/tf24_strategy.h>
#include <plant/scm.h>
#include <odelia/ode_solver.hpp>

#include <cmath>
#include <vector>

using namespace Rcpp;

namespace {

// The three birth stamps of every node of every species, entering a segment.
struct BirthState {
  std::vector<std::vector<double>> times;
  std::vector<std::vector<double>> patch_density;
  std::vector<std::vector<double>> pr_survival;
};

template <class Strat, class Env>
BirthState capture_birth(const plant::Patch<Strat, Env>& p) {
  BirthState b;
  for (std::size_t i = 0; i < p.size(); ++i) {
    const auto& sp = p.at_species(i);
    b.times.push_back(sp.node_times());
    b.patch_density.push_back(sp.r_patch_densities());
    b.pr_survival.push_back(sp.r_pr_patch_survival_at_birth());
  }
  return b;
}

// See the header: no public mutable species accessor exists, so a probe must cast.
template <class Strat, class Env>
void apply_birth(plant::Patch<Strat, Env>& p, const BirthState& b) {
  for (std::size_t i = 0; i < p.size(); ++i) {
    auto& sp = const_cast<typename plant::Patch<Strat, Env>::species_type&>(
        p.at_species(i));
    sp.set_birth_state(b.times[i], b.patch_density[i], b.pr_survival[i]);
  }
}

// Worst absolute and relative difference against `reference`, with the component.
// `ref_at_abs` is the forward value at the worst-ABSOLUTE component. Without it the
// relative column is unreadable: at segment 0 an absolute 4e-31 shows as a relative
// 9e-05 because the reference there is ~1e-27, a quantity no metric cares about. A
// relative error is only alarming when its reference is a live number.
struct Diff { double abs; double rel; int worst; double ref_at_abs; };

template <class Strat, class Env>
Diff compare(const plant::Patch<Strat, Env>& done,
             const std::vector<double>& reference) {
  std::vector<double> y(done.ode_size());
  done.ode_state(y.begin());
  if (y.size() != reference.size()) return {NA_REAL, NA_REAL, -1, NA_REAL};
  Diff d{0.0, 0.0, 0, 0.0};
  for (std::size_t i = 0; i < y.size(); ++i) {
    const double a = std::fabs(y[i] - reference[i]);
    const double scale = std::max(std::fabs(reference[i]), 1e-300);
    if (a > d.abs) { d.abs = a; d.worst = static_cast<int>(i); d.ref_at_abs = reference[i]; }
    d.rel = std::max(d.rel, a / scale);
  }
  const std::size_t per = plant::Node<Strat, Env>::ode_names().size();
  d.worst = static_cast<int>(static_cast<std::size_t>(d.worst) % per);
  return d;
}

template <class Strat>
Rcpp::List stamp_probe(double birth_rate, double lifetime, int probe_every) {
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

  plant::SCM<Strat, Env> fwd(p, env, ctrl);
  fwd.set_schedule(schedule);

  std::vector<std::vector<double>> entering, leaving, light_state;
  std::vector<std::vector<std::size_t>> counts, added;
  std::vector<BirthState> birth;
  std::vector<double> t_in, t_out;

  while (!fwd.complete()) {
    const Patch& pk = fwd.r_patch();
    std::vector<double> y(pk.ode_size());
    pk.ode_state(y.begin());
    entering.push_back(y);
    birth.push_back(capture_birth(pk));
    const std::size_t per = plant::Node<Strat, Env>::ode_names().size();
    const std::size_t env_ode = pk.ode_size() - pk.node_ode_size();
    counts.push_back({(pk.ode_size() - env_ode) / per});
    const Rcpp::NumericMatrix m = pk.r_environment().light_availability.r_get_state();
    light_state.push_back(std::vector<double>(m.begin(), m.end()));
    t_in.push_back(fwd.time());

    added.push_back(fwd.run_next());

    const Patch& pk2 = fwd.r_patch();
    std::vector<double> y2(pk2.ode_size());
    pk2.ode_state(y2.begin());
    leaving.push_back(y2);
    t_out.push_back(fwd.time());
  }

  std::vector<int> probed;
  std::vector<double> plain_abs, plain_rel, stamped_abs, stamped_rel;
  std::vector<double> plain_ref, stamped_ref;
  std::vector<int> plain_worst, stamped_worst;

  for (std::size_t k = 0; k < entering.size();
       k += static_cast<std::size_t>(probe_every)) {
    std::vector<double> times;
    for (double t : schedule)
      if (t >= t_in[k] - 1e-12 && t <= t_out[k] + 1e-12) times.push_back(t);
    if (times.size() < 2) continue;
    times.front() = t_in[k];
    times.back() = t_out[k];

    std::vector<double> light = light_state[k];
    if (light.size() < 6) light = {0.0, 0.5, 1.0, 1.0, 1.0, 1.0};

    // Identical restores except for the stamps, so the difference isolates them.
    for (int with_stamps = 0; with_stamps < 2; ++with_stamps) {
      Patch unit(p, env, ctrl);
      unit.r_set_state(t_in[k], entering[k], counts[k], light);
      if (with_stamps) apply_birth(unit, birth[k]);
      unit.introduce_new_nodes(added[k]);
      odelia::ode::Solver<Patch> s(unit, plant::make_ode_control(ctrl));
      s.set_collect(false);
      s.set_state_from_system();
      s.advance_fixed(times);
      const Diff d = compare(s.get_system_ref(), leaving[k]);
      if (with_stamps) {
        stamped_abs.push_back(d.abs);
        stamped_rel.push_back(d.rel);
        stamped_worst.push_back(d.worst);
        stamped_ref.push_back(d.ref_at_abs);
      } else {
        plain_abs.push_back(d.abs);
        plain_rel.push_back(d.rel);
        plain_worst.push_back(d.worst);
        plain_ref.push_back(d.ref_at_abs);
      }
    }
    probed.push_back(static_cast<int>(k));
  }

  const std::vector<std::string> names = plant::Node<Strat, Env>::ode_names();
  return Rcpp::List::create(
      Rcpp::Named("probed") = probed,
      Rcpp::Named("segments") = static_cast<int>(entering.size()),
      Rcpp::Named("ode_steps") = static_cast<int>(schedule.size() - 1),
      Rcpp::Named("plain_abs") = plain_abs,
      Rcpp::Named("plain_rel") = plain_rel,
      Rcpp::Named("plain_worst") = plain_worst,
      Rcpp::Named("plain_ref") = plain_ref,
      Rcpp::Named("stamped_ref") = stamped_ref,
      Rcpp::Named("stamped_abs") = stamped_abs,
      Rcpp::Named("stamped_rel") = stamped_rel,
      Rcpp::Named("stamped_worst") = stamped_worst,
      Rcpp::Named("component_names") = names);
}

}  // namespace

// [[Rcpp::export]]
Rcpp::List restore_stamp_probe(std::string model = "K93", double birth_rate = 20.0,
                               double lifetime = 20.0, int probe_every = 10) {
  if (model == "K93") return stamp_probe<plant::K93_Strategy>(birth_rate, lifetime, probe_every);
  if (model == "FF16") return stamp_probe<plant::FF16_Strategy>(birth_rate, lifetime, probe_every);
  if (model == "TF24") return stamp_probe<plant::TF24_Strategy>(birth_rate, lifetime, probe_every);
  Rcpp::stop("model must be K93, FF16 or TF24");
}
