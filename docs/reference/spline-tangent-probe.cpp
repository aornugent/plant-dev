/* Can the fitted spline carry the query-height derivative accurately enough to make
 * the exact field unnecessary?
 *
 * The spline is what the forward model already uses, so it is the smaller change; the
 * field was added because the interpolant's tangent was judged unreliable. But that
 * judgement was made against a spline fitted to the LIGHT, exp(-A). A refines
 * smoothly and monotonically where exp(-A) does not, so a spline in A may have a
 * usable tangent, with light and its derivative recovered as
 *     E   = exp(-A),
 *     dE  = -A'(z) exp(-A).
 * The field gives A and A' exactly, so it is the reference here rather than the rival.
 *
 * Run from /home/user/plant-dev via docs/reference/spline-tangent-probe.R.
 */

// [[Rcpp::depends(Rcpp, odelia, plant)]]
// [[Rcpp::plugins(cpp20)]]

#include <Rcpp.h>
#include <odelia/separable_field.hpp>
#include <odelia/interpolator.hpp>
#include <plant/canopy_shape.h>

#include <algorithm>
#include <cmath>
#include <functional>
#include <vector>

using namespace Rcpp;

namespace {

// A stand: `n` cohorts spread over [h_min, h_top] with weights falling off with
// height, which is the shape a real size distribution has.
struct stand {
  std::vector<double> h;                       // descending
  odelia::separable_field<double, 3> field;
  plant::CanopyShape<double> canopy;
  std::vector<double> cumulative_amp;

  stand(int n, double h_min, double h_top, double eta) : canopy(eta) {
    h.resize(n);
    for (int j = 0; j < n; ++j) {
      h[j] = h_top - (h_top - h_min) * j / static_cast<double>(n - 1);
    }
    std::array<std::vector<double>, 3> sw;
    for (int p = 0; p < 3; ++p) sw[p].resize(n);
    for (int j = 0; j < n; ++j) {
      const double amp = 0.02 * std::exp(-2.0 * (h_top - h[j]) / h_top);
      const auto b = canopy.shading_source_factors<double>(h[j]);
      for (int p = 0; p < 3; ++p) sw[p][j] = amp * b[p];
    }
    field.assemble(sw);
  }

  std::size_t rank_at(double z) const {
    auto it = std::upper_bound(h.begin(), h.end(), z, std::greater<double>());
    return static_cast<std::size_t>(it - h.begin());
  }

  // Optical depth and its exact slope at a query height.
  double A(double z) const {
    const std::size_t k = rank_at(z);
    if (k == 0) return 0.0;
    return field.at(canopy.shading_query_factors<double>(z), k - 1);
  }
  double dA(double z) const {
    const std::size_t k = rank_at(z);
    if (k == 0) return 0.0;
    return field.slope(canopy.shading_query_slopes<double>(z), k - 1);
  }
};

}  // namespace

// [[Rcpp::export]]
Rcpp::List spline_tangent_probe(int n_cohort = 200, double h_top = 20.0,
                                double h_min = 0.2, double eta = 12.0,
                                double tol = 1e-4, int nbase = 17,
                                int max_depth = 16, int n_query = 400) {
  const stand s(n_cohort, h_min, h_top, eta);
  const std::size_t nb = static_cast<std::size_t>(nbase);
  const std::size_t md = static_cast<std::size_t>(max_depth);

  // Two fits at plant's own tolerance: one to the light, one to the optical depth.
  odelia::interpolator::basic_interpolator<double> fit_light, fit_depth;
  fit_light.construct([&](double z) -> double { return std::exp(-s.A(z)); }, 0.0,
                      h_top, tol, tol, nb, md);
  fit_depth.construct([&](double z) -> double { return s.A(z); }, 0.0, h_top, tol,
                      tol, nb, md);

  double max_val_light = 0.0, max_val_depth = 0.0;
  double max_slope_light = 0.0, max_slope_depth = 0.0;
  double sum_slope_light = 0.0, sum_slope_depth = 0.0;
  int counted = 0;

  for (int i = 1; i < n_query; ++i) {
    const double z = h_top * i / static_cast<double>(n_query);
    const double A = s.A(z), dA = s.dA(z);
    const double E = std::exp(-A), dE = -dA * E;      // the exact pair
    if (std::fabs(dE) < 1e-14) continue;

    // Value error, both fits.
    max_val_light = std::max(max_val_light, std::fabs(fit_light.eval(z) - E));
    max_val_depth =
        std::max(max_val_depth, std::fabs(std::exp(-fit_depth.eval(z)) - E));

    // Slope error. The light fit differentiates directly; the depth fit gives A'
    // and light's slope follows as -A' exp(-A).
    const double dE_light = fit_light.deriv(z);
    const double dE_depth = -fit_depth.deriv(z) * std::exp(-fit_depth.eval(z));
    const double rl = std::fabs(dE_light - dE) / std::fabs(dE);
    const double rd = std::fabs(dE_depth - dE) / std::fabs(dE);
    max_slope_light = std::max(max_slope_light, rl);
    max_slope_depth = std::max(max_slope_depth, rd);
    sum_slope_light += rl;
    sum_slope_depth += rd;
    ++counted;
  }

  return Rcpp::List::create(
      Rcpp::Named("nodes_light") = static_cast<int>(fit_light.get_x().size()),
      Rcpp::Named("nodes_depth") = static_cast<int>(fit_depth.get_x().size()),
      Rcpp::Named("max_value_err_light") = max_val_light,
      Rcpp::Named("max_value_err_depth") = max_val_depth,
      Rcpp::Named("max_slope_reld_light") = max_slope_light,
      Rcpp::Named("max_slope_reld_depth") = max_slope_depth,
      Rcpp::Named("mean_slope_reld_light") = sum_slope_light / counted,
      Rcpp::Named("mean_slope_reld_depth") = sum_slope_depth / counted,
      Rcpp::Named("n_query") = counted);
}
