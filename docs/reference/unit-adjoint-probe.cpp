/* Do trait adjoints accumulate across units? And what does one unit's tape cost?
 *
 * The worry on record: "`field_ptrs()` returns pointers INTO the Strategy instance, so if
 * units own copies, each seeds a different AD input and a single read at the end captures
 * only the LAST unit's contribution -- plausible magnitude, right sign, nothing thrown."
 * That was called the highest-risk untested assumption in the design.
 *
 * It resolves into a CONDITIONAL, and the ownership graph decides it. `Individual` holds
 * `strategy_type_ptr`, which is `std::shared_ptr` (`k93_strategy.h:68`), and
 * `Species::ad_parameters()` returns `strategy->field_ptrs()` (`species.h:141-142`) --
 * pointers into that one shared Strategy's `pars`. So:
 *
 *   COPY THE MOULD PATCH (what the design does) -- the copy shares the Strategy, hence
 *     the SAME AD input. Every unit accumulates into one adjoint automatically.
 *   GIVE EACH UNIT ITS OWN STRATEGY (what Leaf-fix candidate 1 does) -- each unit gets
 *     its own `pars`, hence a DISTINCT AD input, and a single read captures one unit.
 *
 * So the hazard is not present in the design as written, and Leaf-fix candidate 1 would
 * CREATE it. That couples #37 and #40 by a mechanism instead of a suspicion, which is
 * why this probe measures both arrangements.
 *
 * (1) pointer identity -- is the seeded address shared across a Patch copy, or not?
 * (2) the adjoint consequence -- one tape, two units, J = f(u1) + f(u2):
 *       shared    : one input, one adjoint, should equal the frozen-trajectory FD
 *       per-unit  : two inputs; their SUM should equal the shared adjoint, and either
 *                   one ALONE is the silently-wrong number the worry describes
 * (3) the per-unit tape INCLUDING the restore, which the ~89 MB estimate omits (that
 *     came from a whole-run gradient, which performs no restores; a unit also records
 *     compute_environment + compute_rates over every cohort).
 *
 * The trajectory is frozen: units are restored from stored PLAIN values, so each unit's
 * state entering is a tape constant and what is measured is the trait channel alone. The
 * FD reference is taken the same way -- perturb the trait, re-run the same units from the
 * same stored states -- so AD and FD are the same functional, not two different ones.
 *
 * K93: no leaf, no soil, and a segment replay that is exact from a copy, so a failure here
 * is unambiguously about the adjoint and not about the restore.
 *
 * Run from /home/user/plant-dev via docs/reference/unit-adjoint-probe.R.
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
#include <memory>
#include <vector>

using namespace Rcpp;

namespace {

// b_0 is index 1 of K93_AD_FIELDS: height_0, b_0, b_1, ... (k93_strategy.h:47-49).
constexpr int B0_INDEX = 1;

// One frozen segment of a K93 run: everything a unit needs to be rebuilt from plain
// values, captured on a double forward pass.
struct Frozen {
  std::vector<double> y;                 // state entering
  std::vector<std::size_t> counts;       // nodes per species
  std::vector<double> light;             // the light spline's nodes and values
  std::vector<std::size_t> added;        // species introduced opening the segment
  std::vector<double> times;             // the segment's slice of the L1 grid
  double t_in;
};

template <class S>
std::vector<Frozen> freeze(const plant::Parameters<plant::K93_Strategy_<S>,
                                                   plant::K93_Environment_<S>>&,
                           double birth_rate, double lifetime, int n_units,
                           int first_unit) {
  using Strat = plant::K93_Strategy;   // the forward pass is always double
  using Env = Strat::environment_type;
  using Patch = plant::Patch<Strat, Env>;

  plant::Control ctrl;
  Env env;
  plant::Parameters<Strat, Env> p;
  Strat st;
  st.is_variable_birth_rate = false;
  st.birth_rate_y = {birth_rate};
  p.strategies.push_back(st);
  p.max_patch_lifetime = lifetime;
  p.validate();

  plant::SCM<Strat, Env> sched(p, env, ctrl);
  sched.refine_schedule();
  const std::vector<double> schedule = sched.recorded_steps();

  plant::SCM<Strat, Env> fwd(p, env, ctrl);
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

  std::vector<Frozen> picked;
  for (int u = 0; u < n_units; ++u) {
    const std::size_t k = static_cast<std::size_t>(first_unit + u);
    if (k < all.size() && all[k].times.size() >= 2) picked.push_back(all[k]);
  }
  return picked;
}

// Advance one restored unit and reduce it: the summed height of every node, a functional
// with an obvious trait dependence and no reliance on the stamps this probe does not set.
template <class S>
S run_unit(plant::Patch<plant::K93_Strategy_<S>, plant::K93_Environment_<S>> unit,
           const Frozen& f, const plant::Control& ctrl) {
  using Patch = plant::Patch<plant::K93_Strategy_<S>, plant::K93_Environment_<S>>;
  unit.r_set_state(f.t_in, f.y, f.counts, f.light);
  unit.introduce_new_nodes(f.added);
  odelia::ode::Solver<Patch> s(unit, plant::make_ode_control(ctrl));
  s.set_collect(false);
  s.set_state_from_system();
  s.advance_fixed(f.times);
  const Patch& done = s.get_system_ref();
  S acc = S(0.0);
  for (std::size_t i = 0; i < done.size(); ++i)
    for (auto it = done.at_species(i).node_begin(); it != done.at_species(i).node_end(); ++it)
      acc += it->height();
  return acc;
}

template <class S>
plant::Parameters<plant::K93_Strategy_<S>, plant::K93_Environment_<S>>
make_params(double birth_rate, double lifetime, double b0_scale) {
  plant::Parameters<plant::K93_Strategy_<S>, plant::K93_Environment_<S>> p;
  plant::K93_Strategy_<S> st;
  st.is_variable_birth_rate = false;
  st.birth_rate_y = {birth_rate};   // always plain: birth_rate_y is std::vector<double>
  st.pars.b_0 = st.pars.b_0 * S(b0_scale);
  p.strategies.push_back(st);
  p.max_patch_lifetime = lifetime;
  p.validate();
  return p;
}

}  // namespace

// [[Rcpp::export]]
Rcpp::List unit_adjoint_probe(double birth_rate = 20.0, double lifetime = 20.0,
                              int n_units = 2, int first_unit = 40,
                              double d_rel = 1e-6) {
  using ad = xad::adj<double>;
  using RevS = ad::active_type;
  using StratA = plant::K93_Strategy_<RevS>;
  using EnvA = plant::K93_Environment_<RevS>;
  using PatchA = plant::Patch<StratA, EnvA>;
  using StratD = plant::K93_Strategy;
  using EnvD = StratD::environment_type;
  using PatchD = plant::Patch<StratD, EnvD>;

  plant::Control ctrl;
  const auto pd0 = make_params<double>(birth_rate, lifetime, 1.0);
  const std::vector<Frozen> units = freeze<double>(pd0, birth_rate, lifetime, n_units, first_unit);
  if (units.size() < 2) Rcpp::stop("need at least two usable units -- lower first_unit");

  // (1) Pointer identity: does a Patch COPY share the seeded address, or not?
  int copy_shares = 0, fresh_shares = 0;
  {
    EnvD env;
    PatchD mould(pd0, env, ctrl);
    PatchD copy = mould;
    PatchD fresh(pd0, env, ctrl);
    copy_shares = (mould.ad_parameters()[B0_INDEX] == copy.ad_parameters()[B0_INDEX]);
    fresh_shares = (mould.ad_parameters()[B0_INDEX] == fresh.ad_parameters()[B0_INDEX]);
  }

  const std::size_t U = units.size();
  std::size_t tape_bytes_one_unit = 0, tape_ops_one_unit = 0;

  // (2a) SHARED: seed the mould's Strategy once; every unit is a COPY of the mould, so
  // every unit reads the same AD input and the adjoints accumulate on one tape.
  double shared_value = 0.0, shared_adjoint = 0.0;
  {
    ad::tape_type tape(false);
    tape.activate();
    std::vector<RevS> inputs(1, plant::K93_Pars_<double>().b_0);
    // Explicit return type: an AD lambda must never deduce one (dangling expression
    // templates -- see HANDOFF Part 2).
    std::function<std::vector<RevS>(std::vector<RevS>&)> forward =
        [&](std::vector<RevS>& x) -> std::vector<RevS> {
      EnvA env;
      auto pa = make_params<RevS>(birth_rate, lifetime, 1.0);
      PatchA mould(pa, env, ctrl);
      *mould.ad_parameters()[B0_INDEX] = x[0];   // seeded ONCE, into the shared Strategy
      RevS J = RevS(0.0);
      for (std::size_t u = 0; u < U; ++u) J += run_unit<RevS>(mould, units[u], ctrl);
      return {J};
    };
    const auto jac = xad::computeJacobian(inputs, forward, 1, &tape);
    shared_adjoint = jac[0][0];
    tape_bytes_one_unit = tape.getMemory() / (U > 0 ? U : 1);
    tape_ops_one_unit = static_cast<std::size_t>(tape.getNumOperations()) / (U > 0 ? U : 1);
  }

  // (2b) PER-UNIT STRATEGY: each unit is built from its OWN Parameters, so each has its
  // own `pars` and therefore a DISTINCT AD input. This is Leaf-fix candidate 1's shape.
  std::vector<double> per_unit_adjoints;
  {
    ad::tape_type tape(false);
    tape.activate();
    std::vector<RevS> inputs(U, plant::K93_Pars_<double>().b_0);
    std::function<std::vector<RevS>(std::vector<RevS>&)> forward =
        [&](std::vector<RevS>& x) -> std::vector<RevS> {
      RevS J = RevS(0.0);
      for (std::size_t u = 0; u < U; ++u) {
        EnvA env;
        auto pa = make_params<RevS>(birth_rate, lifetime, 1.0);
        PatchA unit(pa, env, ctrl);            // its own Strategy
        *unit.ad_parameters()[B0_INDEX] = x[u];  // its own input
        J += run_unit<RevS>(unit, units[u], ctrl);
      }
      return {J};
    };
    const auto jac = xad::computeJacobian(inputs, forward, 1, &tape);
    for (std::size_t u = 0; u < U; ++u) per_unit_adjoints.push_back(jac[0][u]);
  }

  // (3) FD on the SAME frozen functional: perturb b_0, re-run the same units from the
  // same stored states. Central difference, relative step.
  double fd = 0.0;
  {
    const double b0 = plant::K93_Pars_<double>().b_0;
    const double h = d_rel * std::fabs(b0);
    double jp = 0.0, jm = 0.0;
    for (int sgn = -1; sgn <= 1; sgn += 2) {
      const double scale = (b0 + sgn * h) / b0;
      EnvD env;
      auto pdp = make_params<double>(birth_rate, lifetime, scale);
      PatchD mould(pdp, env, ctrl);
      double J = 0.0;
      for (std::size_t u = 0; u < U; ++u) J += run_unit<double>(mould, units[u], ctrl);
      if (sgn < 0) jm = J; else jp = J;
    }
    fd = (jp - jm) / (2.0 * h);
  }

  // The value, for scale.
  {
    EnvD env;
    PatchD mould(pd0, env, ctrl);
    for (std::size_t u = 0; u < U; ++u) shared_value += run_unit<double>(mould, units[u], ctrl);
  }

  double sum_per_unit = 0.0;
  for (double g : per_unit_adjoints) sum_per_unit += g;

  return Rcpp::List::create(
      Rcpp::Named("units") = static_cast<int>(U),
      Rcpp::Named("first_unit") = first_unit,
      Rcpp::Named("copy_shares_strategy") = copy_shares,
      Rcpp::Named("fresh_shares_strategy") = fresh_shares,
      Rcpp::Named("value") = shared_value,
      Rcpp::Named("shared_adjoint") = shared_adjoint,
      Rcpp::Named("per_unit_adjoints") = per_unit_adjoints,
      Rcpp::Named("sum_per_unit") = sum_per_unit,
      Rcpp::Named("fd") = fd,
      Rcpp::Named("tape_bytes_per_unit") = static_cast<double>(tape_bytes_one_unit),
      Rcpp::Named("tape_ops_per_unit") = static_cast<double>(tape_ops_one_unit));
}
