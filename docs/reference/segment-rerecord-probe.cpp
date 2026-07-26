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
Rcpp::List rerecord_probe(double birth_rate, double lifetime, int probe_every,
                          bool settle_twice) {
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

  std::vector<Patch> entering_patch;           // the forward patch, whole, entering k
  std::vector<std::vector<double>> entering;   // state before segment k's introduction
  std::vector<std::vector<double>> leaving;    // state after segment k integrates
  std::vector<std::vector<std::size_t>> added; // species introduced opening segment k
  std::vector<double> t_in, t_out;
  std::vector<std::vector<std::size_t>> counts;  // individuals per species, entering k
  std::vector<std::vector<double>> light_state;  // the spline's nodes and values, entering k

  while (!fwd.complete()) {
    const plant::Patch<Strat, Env>& pk = fwd.r_patch();
    std::vector<double> y(pk.ode_size());
    pk.ode_state(y.begin());
    entering.push_back(y);
    entering_patch.push_back(pk);
    {
      // One species in this probe, so the node count follows from the state width:
      // each node carries the strategy's states plus fecundity and log-density.
      const std::size_t per_node =
          plant::Node<Strat, Env>::ode_names().size();
      const std::size_t env_ode = pk.ode_size() - pk.node_ode_size();
      counts.push_back({(pk.ode_size() - env_ode) / per_node});
      const Rcpp::NumericMatrix m = pk.r_environment().light_availability.r_get_state();
      light_state.push_back(std::vector<double>(m.begin(), m.end()));
    }
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
  // The spline that shapes the segment: if a rebuilt patch does not choose the same
  // nodes as the forward pass, the two see different backgrounds and no amount of
  // state restoration will make them agree.
  std::vector<int> fwd_nodes, reb_nodes, nodes_match;
  std::vector<double> from_copy_abs;

  for (std::size_t k = 0; k < U; k += static_cast<std::size_t>(probe_every)) {
    // The segment's own slice of the recorded grid.
    std::vector<double> times;
    for (double t : schedule) {
      if (t >= t_in[k] - 1e-12 && t <= t_out[k] + 1e-12) times.push_back(t);
    }
    if (times.size() < 2) continue;
    times.front() = t_in[k];
    times.back() = t_out[k];

    // The forward pass's spline entering this segment, for comparison.
    std::vector<double> fwd_x;
    {
      plant::SCM<Strat, Env> upto(p, env, ctrl);
      upto.set_schedule(schedule);
      for (std::size_t j = 0; j < k; ++j) upto.run_next();
      fwd_x = upto.r_patch().r_environment().light_availability.spline.get_x();
    }

    // Restore through plant's own entry point, which takes the three things a patch
    // needs: the state, the individuals per species, and the light spline's nodes and
    // values. The earlier version of this probe faked the widths and installed no
    // spline, which is what made it drift.
    plant::Patch<Strat, Env> unit(p, env, ctrl);
    // An environment that fits no spline (K93 reads the exact field) still needs
    // SOMETHING for r_set_state to install, since init wants three points. A flat
    // one is fine precisely because it is never read.
    std::vector<double> light = light_state[k];
    if (light.size() < 6) light = {0.0, 0.5, 1.0, 1.0, 1.0, 1.0};
    if (true) {
      // plant's own restore: state, individuals per species, and the spline's nodes
      // and values. This is the piece the earlier version of this probe omitted.
      unit.r_set_state(t_in[k], entering[k], counts[k], light);
    } else {
      // Nothing to install: this environment fits no spline (K93 reads the exact
      // field), so the restore is the state and the cohort count alone.
      unit.reset();
      int guard = 0;
      while (unit.ode_size() < entering[k].size() && ++guard < 100000) {
        unit.introduce_new_nodes({0});
      }
      if (unit.ode_size() != entering[k].size()) {
        probed.push_back(static_cast<int>(k));
        width_ok.push_back(0);
        max_reld.push_back(NA_REAL);
        max_abs.push_back(NA_REAL);
        fwd_nodes.push_back(0); reb_nodes.push_back(0); nodes_match.push_back(0);
        from_copy_abs.push_back(NA_REAL);
        continue;
      }
      unit.set_ode_state(entering[k].begin(), t_in[k]);
    }
    unit.introduce_new_nodes(added[k]);
    // Settle once more before integrating. compute_environment runs BEFORE
    // compute_rates inside set_ode_state, and the competition source weight is read
    // from an aux slot that compute_rates writes -- so the first settle builds the
    // field from whatever aux the fresh patch happened to hold, and only the second
    // sees aux consistent with this state. Aux is not part of ode_state, so a rebuilt
    // patch cannot inherit it.
    if (settle_twice) {
      std::vector<double> y_now(unit.ode_size());
      unit.ode_state(y_now.begin());
      unit.set_ode_state(y_now.begin(), t_in[k]);
    }

    odelia::ode::Solver<Patch> solver(unit, plant::make_ode_control(ctrl));
    solver.set_collect(false);
    solver.set_state_from_system();
    solver.advance_fixed(times);

    {
      const std::vector<double> rx =
          solver.get_system_ref().r_environment().light_availability.spline.get_x();
      fwd_nodes.push_back(static_cast<int>(fwd_x.size()));
      reb_nodes.push_back(static_cast<int>(rx.size()));
      bool same = fwd_x.size() == rx.size();
      if (same)
        for (std::size_t i = 0; i < rx.size(); ++i)
          if (fwd_x[i] != rx[i]) { same = false; break; }
      nodes_match.push_back(same ? 1 : 0);
    }

    // Same segment, but started from a whole copy of the forward patch rather than a
    // patch rebuilt out of the stored state vector.
    double ma_copy = -1.0;
    {
      Patch from_copy = entering_patch[k];
      from_copy.introduce_new_nodes(added[k]);
      odelia::ode::Solver<Patch> s2(from_copy, plant::make_ode_control(ctrl));
      s2.set_collect(false);
      s2.set_state_from_system();
      s2.advance_fixed(times);
      const Patch& d2 = s2.get_system_ref();
      std::vector<double> y2(d2.ode_size());
      d2.ode_state(y2.begin());
      if (y2.size() == leaving[k].size()) {
        ma_copy = 0.0;
        for (std::size_t i = 0; i < y2.size(); ++i)
          ma_copy = std::max(ma_copy, std::fabs(y2[i] - leaving[k][i]));
      }
    }
    from_copy_abs.push_back(ma_copy);

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
      Rcpp::Named("max_abs") = Rcpp::wrap(max_abs),
      Rcpp::Named("fwd_nodes") = Rcpp::wrap(fwd_nodes),
      Rcpp::Named("reb_nodes") = Rcpp::wrap(reb_nodes),
      Rcpp::Named("nodes_match") = Rcpp::wrap(nodes_match),
      Rcpp::Named("from_copy_abs") = Rcpp::wrap(from_copy_abs));
}

}  // namespace

// [[Rcpp::export]]
Rcpp::List segment_rerecord_probe(std::string model = "K93", double birth_rate = 20.0,
                                  double lifetime = 20.0, int probe_every = 10,
                                  bool settle_twice = false) {
  if (model == "K93") {
    return rerecord_probe<plant::K93_Strategy>(birth_rate, lifetime, probe_every,
                                              settle_twice);
  }
  return rerecord_probe<plant::FF16_Strategy>(birth_rate, lifetime, probe_every,
                                             settle_twice);
}
