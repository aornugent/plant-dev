/* What does ONE unit of the step-local sweep cost in plant, in wall clock?
 *
 * The design's headline time figure is "a flat 4.2x the whole-run reverse pass", measured on an
 * odelia toy at ~22 us per unit. That toy's restore is `set_ode_state` on a handful of doubles.
 * plant's restore is not: `Patch::r_set_state` reinstalls the light spline and then
 * `set_ode_state` runs `compute_environment(true)` AND `compute_rates()` over every cohort. At
 * production TF24 that is 2 598 units x 987 cohorts, and nobody has priced it. If a restore costs
 * 1 ms the sweep adds 3 s; if it costs 0.5 s it adds 20 minutes per gradient.
 *
 * This measures the three pieces of a unit separately, in double (the active scalar multiplies
 * them by a constant, it does not change their ratio):
 *
 *   copy      -- duplicating the mould Patch
 *   restore   -- r_set_state: spline install + compute_environment + compute_rates
 *   advance   -- one ODE step through the Solver
 *
 * and reports per-unit totals plus the extrapolation to a given unit count. Run at two lifetimes
 * to see how each scales with cohort width.
 *
 * Run from /home/user/plant-dev via docs/reference/unit-cost-probe.R.
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

#include <chrono>
#include <vector>

using namespace Rcpp;

namespace {

using clk = std::chrono::steady_clock;
static double us_since(clk::time_point t0) {
  return std::chrono::duration<double, std::micro>(clk::now() - t0).count();
}

template <class Strat>
Rcpp::List cost_probe(double birth_rate, double lifetime, int reps) {
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

  // Walk to the LAST segment, so the width is the widest this lifetime reaches -- the
  // pessimistic end, which is the one that matters for a per-unit cost.
  plant::SCM<Strat, Env> fwd(p, env, ctrl);
  fwd.set_schedule(schedule);
  Patch mould(p, env, ctrl);
  std::vector<double> y;
  std::vector<std::size_t> counts;
  std::vector<double> light;
  double t_in = 0.0, t_out = 0.0;
  std::size_t n_units = 0;
  while (!fwd.complete()) {
    const Patch& pk = fwd.r_patch();
    mould = pk;
    y.assign(pk.ode_size(), 0.0);
    pk.ode_state(y.begin());
    const std::size_t per = plant::Node<Strat, Env>::ode_names().size();
    const std::size_t env_ode = pk.ode_size() - pk.node_ode_size();
    counts.assign(1, (pk.ode_size() - env_ode) / per);
    const Rcpp::NumericMatrix m = pk.r_environment().light_availability.r_get_state();
    light.assign(m.begin(), m.end());
    t_in = fwd.time();
    fwd.run_next();
    t_out = fwd.time();
    n_units++;
  }
  if (light.size() < 6) light = {0.0, 0.5, 1.0, 1.0, 1.0, 1.0};

  std::vector<double> times;
  for (double t : schedule)
    if (t >= t_in - 1e-12 && t <= t_out + 1e-12) times.push_back(t);
  if (times.size() < 2) times = {t_in, t_out};
  times.front() = t_in;
  times.back() = t_out;

  double t_copy = 0.0, t_restore = 0.0, t_advance = 0.0;
  for (int r = 0; r < reps; ++r) {
    auto a = clk::now();
    Patch unit = mould;
    t_copy += us_since(a);

    auto b = clk::now();
    unit.r_set_state(t_in, y, counts, light);
    t_restore += us_since(b);

    auto c = clk::now();
    odelia::ode::Solver<Patch> s(unit, plant::make_ode_control(ctrl));
    s.set_collect(false);
    s.set_state_from_system();
    s.advance_fixed(times);
    t_advance += us_since(c);
  }

  const double n = static_cast<double>(reps);
  return Rcpp::List::create(
      Rcpp::Named("lifetime") = lifetime,
      Rcpp::Named("ode_size") = static_cast<int>(y.size()),
      Rcpp::Named("cohorts") = static_cast<int>(counts[0]),
      Rcpp::Named("units_this_run") = static_cast<int>(n_units),
      Rcpp::Named("steps_in_unit") = static_cast<int>(times.size() - 1),
      Rcpp::Named("copy_us") = t_copy / n,
      Rcpp::Named("restore_us") = t_restore / n,
      Rcpp::Named("advance_us") = t_advance / n,
      Rcpp::Named("unit_us") = (t_copy + t_restore + t_advance) / n);
}

}  // namespace

// [[Rcpp::export]]
Rcpp::List unit_cost_probe(std::string model = "TF24", double birth_rate = 20.0,
                           double lifetime = 20.0, int reps = 10) {
  if (model == "K93") return cost_probe<plant::K93_Strategy>(birth_rate, lifetime, reps);
  if (model == "FF16") return cost_probe<plant::FF16_Strategy>(birth_rate, lifetime, reps);
  if (model == "TF24") return cost_probe<plant::TF24_Strategy>(birth_rate, lifetime, reps);
  Rcpp::stop("model must be K93, FF16 or TF24");
}
