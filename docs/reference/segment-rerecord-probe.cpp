/* Can one event segment of an SCM run be re-run from a stored state and reproduce
 * the forward pass? That is the one plant-side thing the step-local sweep needs and
 * the one place the two passes could diverge structurally: restoring a patch goes
 * through compute_environment(true), which reuses stretched spline nodes rather than
 * re-refining, so the rebuilt segment could see a different background.
 *
 * Everything here is double -- this asks about reproduction, not derivatives. Run
 * from /home/user/plant-dev via docs/reference/segment-rerecord-probe.R.
 */

// [[Rcpp::depends(Rcpp, odelia, plant)]]
// [[Rcpp::plugins(cpp20)]]

#include <Rcpp.h>
#include <plant.h>
#include <plant/models/k93_strategy.h>
#include <plant/models/ff16_strategy.h>
#include <plant/scm.h>
#include <odelia/ode_solver.hpp>

#include <cmath>
#include <vector>

using namespace Rcpp;

namespace {

template <class Strat>
Rcpp::List rerecord_probe(double birth_rate, double lifetime, int probe_every) {
  using Env = typename Strat::environment_type;
  using Patch = plant::Patch<Strat, Env>;

  Strat s;
  s.is_variable_birth_rate = false;
  s.birth_rate_y = {birth_rate};
  plant::Parameters<Strat, Env> p;
  p.strategies.push_back(s);
  p.max_patch_lifetime = lifetime;
  p.validate();
  plant::Control ctrl;
  Env env;

  // Forward pass, segment by segment, keeping the state entering each segment (that
  // is the state left by the previous one, so it is pre-introduction) alongside the
  // species introduced and the segment's end time.
  plant::SCM<Strat, Env> scm(p, env, ctrl);
  scm.refine_schedule();
  const std::vector<double> schedule = scm.recorded_steps();

  plant::SCM<Strat, Env> fwd(p, env, ctrl);
  fwd.set_schedule(schedule);

  std::vector<std::vector<double>> entering;   // state before segment k's introduction
  std::vector<std::vector<double>> leaving;    // state after segment k integrates
  std::vector<std::vector<std::size_t>> added; // species introduced opening segment k
  std::vector<double> t_in, t_out;

  while (!fwd.complete()) {
    const plant::Patch<Strat, Env>& pk = fwd.r_patch();
    std::vector<double> y(pk.ode_size());
    pk.ode_state(y.begin());
    entering.push_back(y);
    t_in.push_back(fwd.time());

    const std::vector<std::size_t> a = fwd.run_next();
    added.push_back(a);

    const plant::Patch<Strat, Env>& pk2 = fwd.r_patch();
    std::vector<double> y2(pk2.ode_size());
    pk2.ode_state(y2.begin());
    leaving.push_back(y2);
    t_out.push_back(fwd.time());
  }

  const std::size_t U = entering.size();

  // Re-run selected segments in isolation: a fresh patch restored to the stored
  // entering state, the same introduction, the same ODE times.
  std::vector<int> probed;
  std::vector<double> max_reld, max_abs;
  std::vector<int> width_ok;

  for (std::size_t k = 0; k < U; k += static_cast<std::size_t>(probe_every)) {
    // The segment's own slice of the recorded grid.
    std::vector<double> times;
    for (double t : schedule) {
      if (t >= t_in[k] - 1e-12 && t <= t_out[k] + 1e-12) times.push_back(t);
    }
    if (times.size() < 2) continue;
    times.front() = t_in[k];
    times.back() = t_out[k];

    plant::Patch<Strat, Env> unit(p, env, ctrl);
    unit.reset();
    // Restore to the entering width by introducing until the widths agree; the
    // schedule that produced `entering[k]` is the same one, so this reproduces the
    // cohort count without replaying the whole run.
    // (reset() gives the t=0 population; every later segment has more cohorts.)
    bool width_reached = true;
    int guard = 0;
    while (unit.ode_size() < entering[k].size()) {
      unit.introduce_new_nodes({0});
      if (++guard > 100000) { width_reached = false; break; }
    }
    if (!width_reached || unit.ode_size() != entering[k].size()) {
      probed.push_back(static_cast<int>(k));
      width_ok.push_back(0);
      max_reld.push_back(NA_REAL);
      max_abs.push_back(NA_REAL);
      continue;
    }

    unit.set_ode_state(entering[k].begin(), t_in[k]);
    unit.introduce_new_nodes(added[k]);

    odelia::ode::Solver<Patch> solver(unit, plant::make_ode_control(ctrl));
    solver.set_collect(false);
    solver.set_state_from_system();
    solver.advance_fixed(times);

    const Patch& done = solver.get_system_ref();
    std::vector<double> y(done.ode_size());
    done.ode_state(y.begin());

    if (y.size() != leaving[k].size()) {
      probed.push_back(static_cast<int>(k));
      width_ok.push_back(0);
      max_reld.push_back(NA_REAL);
      max_abs.push_back(NA_REAL);
      continue;
    }
    double mr = 0.0, ma = 0.0;
    for (std::size_t i = 0; i < y.size(); ++i) {
      const double d = std::fabs(y[i] - leaving[k][i]);
      ma = std::max(ma, d);
      mr = std::max(mr, d / (std::fabs(leaving[k][i]) + 1e-300));
    }
    probed.push_back(static_cast<int>(k));
    width_ok.push_back(1);
    max_reld.push_back(mr);
    max_abs.push_back(ma);
  }

  return Rcpp::List::create(
      Rcpp::Named("segments") = static_cast<int>(U),
      Rcpp::Named("ode_steps") = static_cast<int>(schedule.size() - 1),
      Rcpp::Named("probed") = Rcpp::wrap(probed),
      Rcpp::Named("width_ok") = Rcpp::wrap(width_ok),
      Rcpp::Named("max_reld") = Rcpp::wrap(max_reld),
      Rcpp::Named("max_abs") = Rcpp::wrap(max_abs));
}

}  // namespace

// [[Rcpp::export]]
Rcpp::List segment_rerecord_probe(std::string model = "K93", double birth_rate = 20.0,
                                  double lifetime = 20.0, int probe_every = 10) {
  if (model == "K93") {
    return rerecord_probe<plant::K93_Strategy>(birth_rate, lifetime, probe_every);
  }
  return rerecord_probe<plant::FF16_Strategy>(birth_rate, lifetime, probe_every);
}
