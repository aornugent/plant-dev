/* TF24's soil rates contain four non-smooth constructs. Do they matter for a
 * gradient, and does a real trajectory cross them?
 *
 * The four, from tf24_environment.h:
 *   (1) runoff floor          `runoff_factor > 0 ? runoff_factor : 0`     :303
 *   (2) drying guard          `theta <= theta_r && rate < 0 -> rate = 0`  :335
 *   (3) conductivity floor    `theta > 0 ? theta : 0`                     :354
 *   (4) retention floor       `theta > theta_r ? theta : theta_r`         :365
 *
 * They are not equally dangerous, and the distinction is the point of this probe:
 * (1), (3) and (4) are KINKS -- the rate stays continuous, only its slope jumps, and
 * on the clamped side a zero derivative is what the model actually means. (2) is a
 * SEVERANCE -- the rate itself jumps to a constant, so d(rate)/d(theta) AND
 * d(rate)/d(resource_depletion) are both zero on a set of positive measure. The
 * second is the one that matters: it is the plant->soil uptake channel, so while any
 * layer sits in the guard, a trait that changes water uptake has no effect on soil
 * state at all. That is the same severance class as the a1-a4 fixes.
 *
 * So the question is which boundaries a trajectory actually visits. This walks a
 * TF24 SCM forward and reports, per layer, the closest approach to each boundary.
 * Everything is double: this asks where the trajectory goes, not for a derivative.
 *
 * Run from /home/user/plant-dev via docs/reference/soil-clamp-probe.R.
 */

// [[Rcpp::depends(Rcpp, odelia, plant)]]
// [[Rcpp::plugins(cpp20)]]

#include <Rcpp.h>
#include <plant.h>
#include <plant/models/tf24_strategy.h>
#include <plant/scm.h>

#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>

using namespace Rcpp;

// [[Rcpp::export]]
Rcpp::List soil_clamp_probe(double birth_rate = 20.0, double lifetime = 20.0,
                            double rainfall = 1.0) {
  using Strat = plant::TF24_Strategy;
  using Env = typename Strat::environment_type;

  Strat s;
  s.is_variable_birth_rate = false;
  s.birth_rate_y = {birth_rate};
  plant::Parameters<Strat, Env> p;
  p.strategies.push_back(s);
  p.max_patch_lifetime = lifetime;
  p.validate();
  plant::Control ctrl;
  Env env;
  // The model default is a constant 1. Drying the driver is the point: TF24 is a
  // water-limited model, so the drought regime is a parameter regime a study visits,
  // not a pathology -- and it is where the guard lives.
  env.extrinsic_drivers.set_constant("rainfall", rainfall);

  plant::SCM<Strat, Env> scm(p, env, ctrl);
  scm.refine_schedule();
  const std::vector<double> schedule = scm.recorded_steps();

  plant::SCM<Strat, Env> fwd(p, env, ctrl);
  fwd.set_schedule(schedule);

  const Env& e0 = fwd.r_patch().r_environment();
  const double theta_r = e0.soil_moist_residual;
  const double theta_sat = e0.soil_moist_sat;
  const double a_infil = e0.a_infil, b_infil = e0.b_infil;
  const std::size_t L = static_cast<std::size_t>(e0.soil_number_of_depths);

  std::vector<double> theta_min(L, std::numeric_limits<double>::infinity());
  std::vector<double> theta_max(L, -std::numeric_limits<double>::infinity());
  // Layer-steps within a whisker of each boundary. "Visited" is generous on purpose:
  // a gradient is wrong on the clamped side, not only exactly at the crossing.
  std::vector<int> n_at_guard(L, 0);      // theta <= theta_r    -> severance (2)
  std::vector<int> n_near_guard(L, 0);    // theta <= 2*theta_r  -> approaching it
  std::vector<int> n_negative(L, 0);      // theta <= 0          -> floor (3)
  int n_runoff_floor = 0;                 // runoff_factor <= 0  -> kink (1)
  double runoff_factor_min = std::numeric_limits<double>::infinity();
  int samples = 0;

  auto sample = [&]() {
    const std::vector<double> th = fwd.r_patch().r_environment().get_soil_water_state();
    for (std::size_t i = 0; i < th.size() && i < L; i++) {
      theta_min[i] = std::min(theta_min[i], th[i]);
      theta_max[i] = std::max(theta_max[i], th[i]);
      if (th[i] <= theta_r) n_at_guard[i]++;
      if (th[i] <= 2.0 * theta_r) n_near_guard[i]++;
      if (th[i] <= 0.0) n_negative[i]++;
    }
    if (!th.empty()) {
      const double rf = 1.0 - a_infil * std::pow(th[0] / theta_sat, b_infil);
      runoff_factor_min = std::min(runoff_factor_min, rf);
      if (rf <= 0.0) n_runoff_floor++;
    }
    samples++;
  };

  sample();
  while (!fwd.complete()) {
    fwd.run_next();
    sample();
  }

  return Rcpp::List::create(
      Rcpp::Named("theta_r") = theta_r,
      Rcpp::Named("theta_sat") = theta_sat,
      Rcpp::Named("a_infil") = a_infil,
      Rcpp::Named("b_infil") = b_infil,
      Rcpp::Named("rainfall") = rainfall,
      Rcpp::Named("samples") = samples,
      Rcpp::Named("layer") = Rcpp::wrap(std::vector<int>([&] {
        std::vector<int> v(L);
        for (std::size_t i = 0; i < L; i++) v[i] = static_cast<int>(i);
        return v;
      }())),
      Rcpp::Named("theta_min") = Rcpp::wrap(theta_min),
      Rcpp::Named("theta_max") = Rcpp::wrap(theta_max),
      Rcpp::Named("n_at_guard") = Rcpp::wrap(n_at_guard),
      Rcpp::Named("n_near_guard") = Rcpp::wrap(n_near_guard),
      Rcpp::Named("n_negative") = Rcpp::wrap(n_negative),
      Rcpp::Named("n_runoff_floor") = n_runoff_floor,
      Rcpp::Named("runoff_factor_min") = runoff_factor_min);
}
