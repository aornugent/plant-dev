/* A1 and A2: does the CHAINED state adjoint work in plant, and does a newborn created
 * inside a unit carry its adjoint?
 *
 * This is the design's central mechanism and, until now, it had never run in plant.
 * Everything measured in plant was either a whole-run single tape, or a unit on a FROZEN
 * trajectory (unit-adjoint-probe) where the entering state is a tape CONSTANT and only the
 * trait channel moves. Carrying lambda = d(functional)/d(entering state) backwards from
 * unit k+1 into unit k -- the thing that makes the sweep a sweep -- was witnessed only on
 * an odelia toy.
 *
 * THE COMPARISON. Two computations of the same derivative:
 *
 *   REFERENCE  one tape over N consecutive units. Restore the entering state of the first
 *              unit, seed it AND the trait as inputs, then run all N units with state
 *              flowing naturally. One reverse sweep gives d(J)/d(trait) and
 *              d(J)/d(entering state of unit 0).
 *
 *   CHAINED    N tapes, one per unit, walked backwards. Unit k is restored from its STORED
 *              plain state, that state is re-seeded as AD inputs, the unit is advanced, and
 *              the output is reduced as dot(lambda_{k+1}, y_out). The reverse sweep then
 *              returns lambda_k (w.r.t. the entering state) and this unit's trait
 *              contribution, which accumulates.
 *
 * If the chained lambda and trait adjoint match the reference, the sweep is correct in
 * plant. The dot(lambda, y_out) reduction is what makes this work with no new seeding API:
 * the adjoint of a linear functional of the outputs IS the seeded output adjoint.
 *
 * A2 IS THE SAME MEASUREMENT AT A UNIT THAT OPENS WITH AN INTRODUCTION. The order is
 * load-bearing and is the design's stated hazard: restore the pre-change state, seed it,
 * THEN `introduce_new_nodes` -- so the newborn is created ON TAPE inside the unit. If the
 * change were applied between units instead, a stand-dependent newborn would lose its
 * adjoint silently (19% error, right sign, per the toy). Here the introduction happens
 * after the AD state is installed, so any dependence of the newborn's initial condition on
 * the entering state is on tape and must show up in lambda.
 *
 * A2 also asks a prior question this probe answers separately, because the 19% hazard is
 * conditional on it: IS a newborn's initial condition stand-dependent at all in this
 * configuration? With `is_variable_birth_rate = false` the seed rain is a constant and K93's
 * seedling height is a parameter, so it may not be -- in which case the hazard is confined
 * to variable-birth-rate runs and the design should say so. `newborn_state_sensitivity`
 * measures it directly in double: perturb one entering-state component, re-introduce, and
 * see whether the newborn's own initial state moves.
 *
 * K93: no leaf (P8 does not block it), no soil, and a copy-path replay that is exact, so a
 * failure here is unambiguously the adjoint.
 *
 * Run from /home/user/plant-dev via docs/reference/chained-adjoint-probe.R.
 */

// [[Rcpp::depends(Rcpp, odelia, plant)]]
// [[Rcpp::plugins(cpp20)]]

#include <Rcpp.h>
#include <plant.h>
#include <plant/models/k93_strategy.h>
#include <plant/scm.h>
#include <odelia/ode_solver.hpp>
#include <odelia/gradient.hpp>

#include <cmath>
#include <functional>
#include <vector>

using namespace Rcpp;

namespace {

constexpr int B0_INDEX = 1;   // b_0 in K93_AD_FIELDS

struct Frozen {
  std::vector<double> y;             // state ENTERING the unit, pre-introduction
  std::vector<std::size_t> counts;   // nodes per species entering
  std::vector<double> light;
  std::vector<std::size_t> added;    // species introduced opening the unit
  std::vector<double> times;
  double t_in;
};

template <class S>
using PatchOf = plant::Patch<plant::K93_Strategy_<S>, plant::K93_Environment_<S>>;

template <class S>
plant::Parameters<plant::K93_Strategy_<S>, plant::K93_Environment_<S>>
make_params(double birth_rate, double lifetime) {
  plant::Parameters<plant::K93_Strategy_<S>, plant::K93_Environment_<S>> p;
  plant::K93_Strategy_<S> st;
  st.is_variable_birth_rate = false;
  st.birth_rate_y = {birth_rate};
  p.strategies.push_back(st);
  p.max_patch_lifetime = lifetime;
  p.validate();
  return p;
}

// Forward double pass: freeze every unit, then hand back a consecutive window.
std::vector<Frozen> freeze_window(double birth_rate, double lifetime, int n_units,
                                  int first_unit, bool require_introduction) {
  using Patch = PatchOf<double>;
  plant::Control ctrl;
  plant::K93_Strategy::environment_type env;
  const auto p = make_params<double>(birth_rate, lifetime);

  plant::SCM<plant::K93_Strategy, plant::K93_Strategy::environment_type> sched(p, env, ctrl);
  sched.refine_schedule();
  const std::vector<double> schedule = sched.recorded_steps();

  plant::SCM<plant::K93_Strategy, plant::K93_Strategy::environment_type> fwd(p, env, ctrl);
  fwd.set_schedule(schedule);

  std::vector<Frozen> all;
  while (!fwd.complete()) {
    const Patch& pk = fwd.r_patch();
    Frozen f;
    f.y.assign(pk.ode_size(), 0.0);
    pk.ode_state(f.y.begin());
    for (std::size_t i = 0; i < pk.size(); ++i) f.counts.push_back(pk.at_species(i).size());
    const Rcpp::NumericMatrix m = pk.r_environment().light_availability.r_get_state();
    f.light.assign(m.begin(), m.end());
    if (f.light.size() < 6) f.light = {0.0, 0.5, 1.0, 1.0, 1.0, 1.0};
    f.t_in = fwd.time();
    const double t0 = fwd.time();
    f.added = fwd.run_next();
    const double t1 = fwd.time();
    for (double t : schedule)
      if (t >= t0 - 1e-12 && t <= t1 + 1e-12) f.times.push_back(t);
    if (f.times.size() < 2) f.times = {t0, t1};
    f.times.front() = t0;
    f.times.back() = t1;
    all.push_back(f);
  }

  std::size_t start = static_cast<std::size_t>(first_unit);
  if (require_introduction) {
    while (start < all.size() && all[start].added.empty()) ++start;
  }
  std::vector<Frozen> win;
  for (int u = 0; u < n_units && start + u < all.size(); ++u) {
    const Frozen& f = all[start + u];
    if (f.times.size() < 2) break;
    win.push_back(f);
  }
  return win;
}

// Advance one unit. Structure comes from the stored PLAIN values (the design's rule);
// `state_in` then overwrites the VALUES at the active scalar, so the entering state is a
// set of AD inputs. The introduction runs AFTER that, hence on tape.
template <class S>
std::vector<S> advance_unit(PatchOf<S>& unit, const Frozen& f,
                            const std::vector<S>& state_in,
                            const plant::Control& ctrl) {
  unit.r_set_state(f.t_in, f.y, f.counts, f.light);   // structure, plain
  std::vector<S> tmp = state_in;
  unit.set_ode_state(tmp.begin(), f.t_in);            // values, active
  unit.introduce_new_nodes(f.added);                  // ON TAPE -- A2
  odelia::ode::Solver<PatchOf<S>> s(unit, plant::make_ode_control(ctrl));
  s.set_collect(false);
  s.set_state_from_system();
  s.advance_fixed(f.times);
  const PatchOf<S>& done = s.get_system_ref();
  std::vector<S> y_out(done.ode_size());
  done.ode_state(y_out.begin());
  return y_out;
}

// The functional: summed height over every node of the final state. Its adjoint w.r.t. the
// final state is the seed for the backward walk.
template <class S>
S sum_heights(const PatchOf<S>& done) {
  S acc = S(0.0);
  for (std::size_t i = 0; i < done.size(); ++i)
    for (auto it = done.at_species(i).node_begin(); it != done.at_species(i).node_end(); ++it)
      acc += it->height();
  return acc;
}

}  // namespace

// A2's prior question, in double: is a newborn's initial condition stand-dependent here?
// Perturb one entering-state component, re-introduce, and compare the NEWBORN's own
// initial state. If nothing moves, the 19% between-units hazard cannot arise in this
// configuration and the design should say under what configuration it can.
// [[Rcpp::export]]
Rcpp::List newborn_state_sensitivity(double birth_rate = 20.0, double lifetime = 20.0,
                                     int first_unit = 40, double d_rel = 1e-4) {
  plant::Control ctrl;
  plant::K93_Strategy::environment_type env;
  const auto p = make_params<double>(birth_rate, lifetime);
  const auto win = freeze_window(birth_rate, lifetime, 1, first_unit, true);
  if (win.empty()) Rcpp::stop("no unit with an introduction found");
  const Frozen& f = win[0];

  const std::size_t per = plant::Node<plant::K93_Strategy,
                                      plant::K93_Strategy::environment_type>::ode_names().size();

  // The newborn is the node introduce_new_nodes appends; read the state right after the
  // introduction, before any integration.
  auto newborn_after = [&](const std::vector<double>& y_in) {
    PatchOf<double> u(p, env, ctrl);
    u.r_set_state(f.t_in, f.y, f.counts, f.light);
    std::vector<double> tmp = y_in;
    u.set_ode_state(tmp.begin(), f.t_in);
    u.introduce_new_nodes(f.added);
    std::vector<double> y(u.ode_size());
    u.ode_state(y.begin());
    // The appended node's block: the last `per` entries of the node region.
    const std::size_t env_ode = u.ode_size() - u.node_ode_size();
    std::vector<double> nb(y.begin() + (u.ode_size() - env_ode - per), y.begin() + (u.ode_size() - env_ode));
    return nb;
  };

  const std::vector<double> base = newborn_after(f.y);
  // Perturb the tallest cohort's height, the component most likely to move the stand.
  std::size_t idx = 0;
  double worst = 0.0;
  std::vector<double> moved(base.size(), 0.0);
  for (std::size_t j = 0; j < f.y.size(); ++j) {
    std::vector<double> y2 = f.y;
    const double h = d_rel * (std::fabs(y2[j]) + 1e-12);
    y2[j] += h;
    const std::vector<double> nb = newborn_after(y2);
    for (std::size_t c = 0; c < nb.size() && c < base.size(); ++c) {
      const double d = std::fabs(nb[c] - base[c]);
      if (d > worst) { worst = d; idx = j; }
      moved[c] = std::max(moved[c], d);
    }
  }

  return Rcpp::List::create(
      Rcpp::Named("newborn_base") = base,
      Rcpp::Named("component_names") =
          plant::Node<plant::K93_Strategy,
                      plant::K93_Strategy::environment_type>::ode_names(),
      Rcpp::Named("max_move_per_component") = moved,
      Rcpp::Named("worst_move") = worst,
      Rcpp::Named("worst_state_index") = static_cast<int>(idx),
      Rcpp::Named("n_state") = static_cast<int>(f.y.size()),
      Rcpp::Named("introduced") = static_cast<int>(f.added.size()));
}

// A1 (and A2 at a unit with an introduction): chained lambda vs a single-tape reference.
//
// `functional_kind` matters for whether this test can FAIL, and that is the point.
//   0 = summed height. Its lambda turns out to be TRIVIAL -- exactly 1 on every height and
//       ~1e-12 elsewhere -- because K93 height growth barely feels the stand over a few
//       units. Matching a trivial lambda tests almost nothing, the same vacuity that made a
//       constant-IC toy unable to see the 19% newborn error.
//   1 = summed DENSITY-WEIGHTED height, sum exp(log_density)*height. Density couples to the
//       light field, so lambda has real structure across components and the comparison has
//       something to detect.
// Always read `lambda_nonzero` / `lambda_distinct` in the output before believing a match.
// [[Rcpp::export]]
Rcpp::List chained_adjoint_probe(double birth_rate = 20.0, double lifetime = 20.0,
                                 int n_units = 3, int first_unit = 40,
                                 bool require_introduction = true,
                                 int functional_kind = 1) {
  using ad = xad::adj<double>;
  using RevS = ad::active_type;

  plant::Control ctrl;
  const auto win = freeze_window(birth_rate, lifetime, n_units, first_unit, require_introduction);
  if (win.size() < 2u) Rcpp::stop("need at least two usable units");
  const std::size_t U = win.size();
  const std::size_t n0 = win[0].y.size();

  int units_with_introduction = 0;
  for (const auto& f : win) if (!f.added.empty()) units_with_introduction++;

  // ---- REFERENCE: one tape, N units, state flowing naturally.
  double ref_value = 0.0, ref_trait = 0.0;
  std::vector<double> ref_lambda0(n0, 0.0);
  {
    ad::tape_type tape(false);
    tape.activate();
    std::vector<RevS> inputs;
    inputs.push_back(plant::K93_Pars_<double>().b_0);
    for (double v : win[0].y) inputs.push_back(v);

    std::function<std::vector<RevS>(std::vector<RevS>&)> forward =
        [&](std::vector<RevS>& x) -> std::vector<RevS> {
      plant::K93_Environment_<RevS> env;
      auto pa = make_params<RevS>(birth_rate, lifetime);
      PatchOf<RevS> unit(pa, env, ctrl);
      *unit.ad_parameters()[B0_INDEX] = x[0];
      std::vector<RevS> state(x.begin() + 1, x.end());
      // Unit 0 restores from the seeded state; later units continue from what the
      // previous one produced, so no restore intervenes and this is a genuine
      // whole-window recording.
      for (std::size_t u = 0; u < U; ++u) {
        state = advance_unit<RevS>(unit, win[u], state, ctrl);
      }
      // Reduce the final state through a fresh patch of the right width.
      PatchOf<RevS> fin(pa, env, ctrl);
      RevS acc = RevS(0.0);
      {
        // `state` already holds the final ODE state; sum its height components directly
        // so the reduction needs no extra structure.
        const std::size_t per = plant::Node<plant::K93_Strategy_<RevS>,
                                            plant::K93_Environment_<RevS>>::ode_names().size();
        for (std::size_t i = 0; i + per <= state.size(); i += per)
          acc += (functional_kind == 0) ? state[i] : exp(state[i + 4]) * state[i];
      }
      return {acc};
    };
    const auto jac = xad::computeJacobian(inputs, forward, 1, &tape);
    ref_trait = jac[0][0];
    for (std::size_t i = 0; i < n0; ++i) ref_lambda0[i] = jac[0][1 + i];
  }

  // ---- CHAINED: N tapes, walked backwards, lambda carried between them.
  double chain_trait = 0.0;
  std::vector<double> lambda;      // adjoint w.r.t. the state ENTERING the current unit
  std::vector<double> per_unit_trait;
  {
    // Height component index within a node block, for seeding the last unit.
    const std::size_t per = plant::Node<plant::K93_Strategy,
                                        plant::K93_Strategy::environment_type>::ode_names().size();
    for (std::size_t back = 0; back < U; ++back) {
      const std::size_t k = U - 1 - back;
      const std::size_t nk = win[k].y.size();

      ad::tape_type tape(false);
      tape.activate();
      std::vector<RevS> inputs;
      inputs.push_back(plant::K93_Pars_<double>().b_0);
      for (double v : win[k].y) inputs.push_back(v);

      const std::vector<double> lam = lambda;   // empty for the last unit
      std::function<std::vector<RevS>(std::vector<RevS>&)> forward =
          [&](std::vector<RevS>& x) -> std::vector<RevS> {
        plant::K93_Environment_<RevS> env;
        auto pa = make_params<RevS>(birth_rate, lifetime);
        PatchOf<RevS> unit(pa, env, ctrl);
        *unit.ad_parameters()[B0_INDEX] = x[0];
        std::vector<RevS> state(x.begin() + 1, x.end());
        std::vector<RevS> y_out = advance_unit<RevS>(unit, win[k], state, ctrl);
        RevS acc = RevS(0.0);
        if (lam.empty()) {
          // Last unit: the functional itself.
          for (std::size_t i = 0; i + per <= y_out.size(); i += per)
            acc += (functional_kind == 0) ? y_out[i] : exp(y_out[i + 4]) * y_out[i];
        } else {
          // Earlier unit: dot(lambda_{k+1}, y_out). The adjoint of a linear functional of
          // the outputs IS the seeded output adjoint, so this needs no seeding API.
          const std::size_t n = std::min(lam.size(), y_out.size());
          for (std::size_t i = 0; i < n; ++i) acc += RevS(lam[i]) * y_out[i];
        }
        return {acc};
      };
      const auto jac = xad::computeJacobian(inputs, forward, 1, &tape);
      per_unit_trait.push_back(jac[0][0]);
      chain_trait += jac[0][0];
      lambda.assign(nk, 0.0);
      for (std::size_t i = 0; i < nk; ++i) lambda[i] = jac[0][1 + i];
    }
    std::reverse(per_unit_trait.begin(), per_unit_trait.end());
  }

  double lam_worst = 0.0, lam_scale = 0.0;
  for (std::size_t i = 0; i < n0 && i < lambda.size(); ++i) {
    lam_worst = std::max(lam_worst, std::fabs(lambda[i] - ref_lambda0[i]));
    lam_scale = std::max(lam_scale, std::fabs(ref_lambda0[i]));
  }

  int lam_nonzero = 0;
  std::vector<double> lam_seen;
  for (std::size_t i = 0; i < n0 && i < ref_lambda0.size(); ++i) {
    if (ref_lambda0[i] != 0.0) lam_nonzero++;
    bool fresh = true;
    for (double v : lam_seen) if (v == ref_lambda0[i]) { fresh = false; break; }
    if (fresh) lam_seen.push_back(ref_lambda0[i]);
  }

  return Rcpp::List::create(
      Rcpp::Named("units") = static_cast<int>(U),
      Rcpp::Named("functional_kind") = functional_kind,
      Rcpp::Named("lambda_nonzero") = lam_nonzero,
      Rcpp::Named("lambda_distinct") = static_cast<int>(lam_seen.size()),
      Rcpp::Named("n_state_first_unit") = static_cast<int>(n0),
      Rcpp::Named("units_with_introduction") = units_with_introduction,
      Rcpp::Named("ref_trait_adjoint") = ref_trait,
      Rcpp::Named("chained_trait_adjoint") = chain_trait,
      Rcpp::Named("per_unit_trait") = per_unit_trait,
      Rcpp::Named("lambda_worst_abs") = lam_worst,
      Rcpp::Named("lambda_scale") = lam_scale,
      Rcpp::Named("ref_lambda0") = ref_lambda0,
      Rcpp::Named("chained_lambda0") = lambda);
}
