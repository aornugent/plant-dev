// What a light interpolant that carries a slope actually costs plant.
//
// Report 3 projected +11.8% on the forward run from a kernel-evaluation count.
// That projection had two inputs: a per-knot arithmetic ratio, and a knot count of
// 142 against plant's 65. This harness measures four things the count did not
// separate.
//
//   1. Is dQ/dz == -q, and does the fused evaluation hold at the ground knot?
//   2. Value and slope out of ONE sweep over the cohorts, against two sweeps.
//   3. The build step alone: the cubic's band solve against the Hermite's spans.
//   4. Accuracy at MATCHED knot count, which decides whether 142 knots are needed.
//
// Build (paths as installed in this workspace):
//
//   g++ -O2 -std=c++20 \
//     -I$(Rscript -e 'cat(find.package("odelia"))')/include \
//     -I$(Rscript -e 'cat(find.package("Rcpp"))')/include \
//     -I$(R CMD config --includedir) \
//     -Iplant/inst/include \
//     -o interpolant_cost docs/reports/interpolant-cost.cpp \
//     $(Rscript -e 'cat(find.package("Rcpp"))')/libs/Rcpp.so \
//     $(R CMD config --ldflags)
//
// plant's canopy_shape.h needs the Q_and_q accessor from
// docs/reports/canopy-shape-fused-q.patch. Errors are normalised on the global
// range of the target, never pointwise: light spans [~0, 1] and dQ/dz is flat to
// roundoff at small u, where a pointwise ratio divides a cancelled difference by a
// 1e-26 analytic value and reports a meaningless 1.0.

#include <plant/canopy_shape.h>

#include <odelia/interpolator.hpp>
#include <odelia/hermite_interpolator.hpp>

#include <chrono>
#include <cmath>
#include <cstdio>
#include <random>
#include <vector>

using plant::CanopyShape;
using plant::ShadingModel;

namespace {

// A production stand is top-heavy in height and bottom-heavy in density: a few
// tall cohorts, many small ones near the birth height.
struct Stand {
  std::vector<double> height, area, density, inv_h, knot;
  double k_I = 0.5, h_max = 20.0;
};

Stand make_stand(std::size_t n_cohort, std::size_t n_knot) {
  std::mt19937 rng(42u);
  std::uniform_real_distribution<double> u01(0.0, 1.0);
  Stand s;
  for (std::size_t j = 0; j < n_cohort; ++j) {
    const double f = static_cast<double>(j) / static_cast<double>(n_cohort - 1);
    s.height.push_back(s.h_max * std::pow(1.0 - f, 2.0) + 0.1);   // descending
    s.area.push_back(0.3 * std::pow(s.height.back(), 1.8));
    s.density.push_back(std::exp(-3.0 * (1.0 - f)) * (0.5 + u01(rng)));
    s.inv_h.push_back(1.0 / s.height.back());
  }
  for (std::size_t k = 0; k < n_knot; ++k)
    s.knot.push_back(s.h_max * static_cast<double>(k) /
                     static_cast<double>(n_knot - 1));
  return s;
}

// plant compiles with no -flto and no UseLTO, so Individual::compute_competition
// is a real call per cohort per knot rather than inlined arithmetic. noinline
// reproduces that boundary in one translation unit (checked against a genuine
// two-TU build: 15.2 us vs 15.1 us on the value sweep at 141 cohorts).
__attribute__((noinline)) double kernel_value(const CanopyShape& c, double z,
                                              double inv_h, double w) {
  return w * c.leaf_area_above(z * inv_h);
}

__attribute__((noinline)) void kernel_value_and_slope(const CanopyShape& c,
                                                      double z, double inv_h,
                                                      double w, double& v,
                                                      double& g) {
  double Q, q;
  c.Q_and_q(z * inv_h, inv_h, Q, q);
  v = w * Q;
  g = -w * q;
}

// plant's Species::compute_competition: a trapezium over cohorts in descending
// height, breaking once a cohort falls below the query.
double sweep_value(const Stand& s, const CanopyShape& c, double z) {
  const std::size_t n = s.height.size();
  double h1 = s.height[0];
  double f1 = kernel_value(c, z, s.inv_h[0], s.density[0] * s.k_I * s.area[0]);
  double tot = 0.0;
  for (std::size_t j = 1; j < n; ++j) {
    const double h0 = s.height[j];
    const double f0 =
        kernel_value(c, z, s.inv_h[j], s.density[j] * s.k_I * s.area[j]);
    tot += (h1 - h0) * (f1 + f0);
    h1 = h0; f1 = f0;
    if (h0 < z) break;
  }
  return tot / 2.0;
}

void sweep_fused(const Stand& s, const CanopyShape& c, double z, double& value,
                 double& slope) {
  const std::size_t n = s.height.size();
  double h1 = s.height[0], f1, g1;
  kernel_value_and_slope(c, z, s.inv_h[0], s.density[0] * s.k_I * s.area[0], f1,
                         g1);
  double tv = 0.0, tg = 0.0;
  for (std::size_t j = 1; j < n; ++j) {
    const double h0 = s.height[j];
    double f0, g0;
    kernel_value_and_slope(c, z, s.inv_h[j],
                           s.density[j] * s.k_I * s.area[j], f0, g0);
    tv += (h1 - h0) * (f1 + f0);
    tg += (h1 - h0) * (g1 + g0);
    h1 = h0; f1 = f0; g1 = g0;
    if (h0 < z) break;
  }
  value = tv / 2.0;
  slope = tg / 2.0;
}

// The exact light and its exact z-derivative, both out of the cohort sum -- the
// pair a fused sweep hands a Hermite build.
void light_exact(const Stand& s, const CanopyShape& c, double z, double& L,
                 double& dL) {
  double A, dA;
  sweep_fused(s, c, z, A, dA);
  L = std::exp(-A);
  dL = -dA * L;
}

template <class F>
double time_it(F&& f, int reps, double& sink) {
  sink += f();
  const auto t0 = std::chrono::steady_clock::now();
  for (int r = 0; r < reps; ++r) sink += f();
  const auto t1 = std::chrono::steady_clock::now();
  return std::chrono::duration<double>(t1 - t0).count() / reps;
}

void report_identity() {
  CanopyShape c;
  c.initialise(12.0, ShadingModel::DeepCrown);
  const double H = 17.3;
  double worst = 0.0, span = 0.0;
  for (int i = 1; i < 200; ++i) {
    const double z = H * i / 200.0, d = 1e-6 * H;
    const double fd =
        (c.Q_from_height(z + d, H) - c.Q_from_height(z - d, H)) / (2 * d);
    double Qv, qv;
    c.Q_and_q(z / H, 1.0 / H, Qv, qv);
    span = std::max(span, std::fabs(qv));
    worst = std::max(worst, std::fabs(fd + qv));
  }
  double Q0, q0;
  c.Q_and_q(0.0, 1.0 / H, Q0, q0);
  std::printf("1. dQ/dz == -q\n");
  std::printf("   worst |FD(dQ/dz) + q| / max|q| over the crown : %.3e\n",
              worst / span);
  std::printf("   at the ground knot z = 0: Q = %.6f, q = %.6f"
              "  (the u^eta/z form: %.6f)\n\n",
              Q0, q0, c.q_from_height(0.0, H));
}

void report_sweep() {
  std::printf("2. value and slope from one sweep, against two\n");
  std::printf("   eta  cohorts  value(us)  two-pass(us)  fused(us)"
              "  two/value  fused/value\n");
  double sink = 0.0;
  for (double eta : {12.0, 4.0, 11.0}) {   // 11 is unspecialised -> libm pow
    CanopyShape c;
    c.initialise(eta, ShadingModel::DeepCrown);
    for (std::size_t n_cohort : {40u, 141u, 300u}) {
      const Stand s = make_stand(n_cohort, 65);
      const int reps = 2000;
      const double t_val = time_it([&] {
        double a = 0.0;
        for (double z : s.knot) a += sweep_value(s, c, z);
        return a;
      }, reps, sink);
      const double t_two = time_it([&] {
        double a = 0.0;
        for (double z : s.knot) {
          double v, g;
          a += sweep_value(s, c, z);
          sweep_fused(s, c, z, v, g);
          a += g;
        }
        return a;
      }, reps, sink);
      const double t_fus = time_it([&] {
        double a = 0.0;
        for (double z : s.knot) {
          double v, g;
          sweep_fused(s, c, z, v, g);
          a += v + g;
        }
        return a;
      }, reps, sink);
      std::printf("   %4.0f %8zu %10.3f %13.3f %10.3f %10.3f %12.3f\n", eta,
                  n_cohort, t_val * 1e6, t_two * 1e6, t_fus * 1e6,
                  t_two / t_val, t_fus / t_val);
    }
  }
  std::printf("   (sink %.3e)\n\n", sink);
}

void report_build_step() {
  std::printf("3. the build step alone, kernel evaluations excluded\n");
  std::printf("   knots  cubic band solve(us)  hermite spans(us)  hermite/cubic\n");
  double sink = 0.0;
  for (std::size_t n : {17u, 33u, 65u, 129u}) {
    std::vector<double> x(n), y(n), dydx(n);
    for (std::size_t k = 0; k < n; ++k) {
      x[k] = 20.0 * static_cast<double>(k) / static_cast<double>(n - 1);
      y[k] = std::exp(-0.4 * (20.0 - x[k]));
      dydx[k] = 0.4 * y[k];
    }
    odelia::interpolator::basic_interpolator<double> cubic;
    odelia::interpolator::hermite_interpolator<double> herm;
    const int reps = 20000;
    // Driven the way rescale_spline drives them: fresh knot values into an
    // already-constructed object, once per Runge-Kutta stage.
    const double t_c = time_it([&] { cubic.init(x, y); return 0.0; }, reps, sink);
    const double t_h =
        time_it([&] { herm.init(x, y, dydx); return 0.0; }, reps, sink);
    sink += cubic.eval(11.0) + herm.eval(11.0);
    std::printf("   %5zu %20.3f %18.3f %14.3f\n", n, t_c * 1e6, t_h * 1e6,
                t_h / t_c);
  }
  std::printf("   (sink %.3e)\n\n", sink);
}

void report_knot_count() {
  const Stand s = make_stand(141, 2);
  CanopyShape c;
  c.initialise(12.0, ShadingModel::DeepCrown);

  const std::size_t n_ref = 4001;
  std::vector<double> zr(n_ref), Lr(n_ref), dLr(n_ref);
  double L_span = 0.0, dL_span = 0.0;
  for (std::size_t i = 0; i < n_ref; ++i) {   // deliberately off the knots
    zr[i] = s.h_max * (static_cast<double>(i) + 0.5) / static_cast<double>(n_ref);
    light_exact(s, c, zr[i], Lr[i], dLr[i]);
    L_span = std::max(L_span, std::fabs(Lr[i]));
    dL_span = std::max(dL_span, std::fabs(dLr[i]));
  }

  std::printf("4. accuracy at matched knot count, 141 cohorts\n");
  std::printf("   knots   cubic value   hermite value   cubic slope"
              "   hermite slope\n");
  for (std::size_t n : {9u, 17u, 33u, 65u, 129u}) {
    std::vector<double> x(n), y(n), dy(n);
    for (std::size_t k = 0; k < n; ++k) {
      x[k] = s.h_max * static_cast<double>(k) / static_cast<double>(n - 1);
      light_exact(s, c, x[k], y[k], dy[k]);
    }
    odelia::interpolator::basic_interpolator<double> cubic;
    odelia::interpolator::hermite_interpolator<double> herm;
    cubic.init(x, y);
    herm.init(x, y, dy);
    double ec = 0.0, eh = 0.0, sc = 0.0, sh = 0.0;
    for (std::size_t i = 0; i < n_ref; ++i) {
      ec = std::max(ec, std::fabs(cubic.eval(zr[i]) - Lr[i]));
      double hv, hs;
      herm.value_and_slope(zr[i], hv, hs);
      eh = std::max(eh, std::fabs(hv - Lr[i]));
      sc = std::max(sc, std::fabs(cubic.deriv(zr[i]) - dLr[i]));
      sh = std::max(sh, std::fabs(hs - dLr[i]));
    }
    std::printf("   %5zu %13.3e %15.3e %13.3e %15.3e\n", n, ec / L_span,
                eh / L_span, sc / dL_span, sh / dL_span);
  }
  std::printf("   normalised on max|light| = %.4f, max|dlight/dz| = %.4f;"
              "  ResourceSpline tol = 1e-4\n",
              L_span, dL_span);
}

}  // namespace

int main() {
  report_identity();
  report_sweep();
  report_build_step();
  report_knot_count();
  return 0;
}
