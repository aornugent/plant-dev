// The vulnerability curve, traced op by op.
//
// Four questions, each printing a number:
//
//   A  is the interpolant exactly linear in its knot values? If so, the honest
//      derivative of the SPLINE in a curve trait is the spline through the knots'
//      own derivatives, on the same grid -- no rebuild, no closed-form
//      substitution, and it differentiates the model being evaluated.
//   B  how does the total split into a fixed-grid part and a grid-motion part?
//   C  does the root side rescale in root_b the way the stem side does, across
//      all four objects built from it?
//   D  what does each piece of a rebuild cost?

#include <phylloptim.hpp>

#include <chrono>
#include <cmath>
#include <cstdio>
#include <vector>

namespace {

using Interp = odelia::interpolator::Interpolator;

const double kB = 3.898245, kC = 2.680147, kRes = 100;

double rel(double a, double b) {
  const double s = std::max(std::abs(a), std::abs(b));
  return s > 0 ? std::abs(a - b) / s : 0.0;
}

// The value spline exactly as setup_transpiration builds it.
Interp value_spline(double b, double c, std::vector<double>& x) {
  std::vector<double> y;
  phylloptim::cumulative_vulnerability_integral(b, c, kRes, x, y);
  Interp s;
  s.init(x, y);
  s.set_extrapolate(false);
  return s;
}

// A spline on a GIVEN grid whose knot values are dG/dc at those knots. If the
// interpolant is linear in its knot values this is dG_spline/dc at fixed grid,
// exactly.
Interp deriv_spline_c(const std::vector<double>& x, double b, double c) {
  std::vector<double> dy(x.size());
  for (size_t i = 0; i < x.size(); ++i) {
    dy[i] = phylloptim::cumulative_vulnerability_integral_derivatives_at(x[i], b, c).dc;
  }
  Interp s;
  s.init(x, dy);
  s.set_extrapolate(false);
  return s;
}

Interp deriv_spline_b(const std::vector<double>& x, double b, double c) {
  std::vector<double> dy(x.size());
  for (size_t i = 0; i < x.size(); ++i) {
    dy[i] = phylloptim::cumulative_vulnerability_integral_derivatives_at(x[i], b, c).db;
  }
  Interp s;
  s.init(x, dy);
  s.set_extrapolate(false);
  return s;
}

// The value spline reseeded at a perturbed trait on the BASE grid: the same
// interpolant with only its knot values moved.
Interp reseeded(const std::vector<double>& x, double b, double c) {
  std::vector<double> y(x.size());
  for (size_t i = 0; i < x.size(); ++i) {
    y[i] = phylloptim::cumulative_vulnerability_integral_at(x[i], b, c);
  }
  Interp s;
  s.init(x, y);
  s.set_extrapolate(false);
  return s;
}

using clock_type = std::chrono::steady_clock;
double us_per(clock_type::time_point a, clock_type::time_point b, long n) {
  return std::chrono::duration<double, std::micro>(b - a).count() / double(n);
}

}  // namespace

int main() {
  std::vector<double> x_base;
  Interp G = value_spline(kB, kC, x_base);
  printf("base grid: %zu knots, [%.12g, %.12g], psi_max=%.12g\n\n",
         x_base.size(), x_base.front(), x_base.back(),
         phylloptim::vulnerability_psi_max(kB, kC));

  // Sample points spread over the domain, strictly inside so no extrapolation.
  std::vector<double> probe;
  for (int k = 1; k <= 9; ++k) { probe.push_back(x_base.back() * k / 10.0); }

  // ---- A. is the interpolant linear in its knot values? -------------------
  printf("A. dG_spline/dc at FIXED grid: the derivative spline against a\n");
  printf("   central difference of the reseeded value spline.\n");
  printf("   If interpolation is linear in y these agree to the difference's own\n");
  printf("   truncation, at every psi and every step.\n\n");
  {
    Interp Dc = deriv_spline_c(x_base, kB, kC);
    for (double step : {1e-3, 1e-5, 1e-7}) {
      const double h = kC * step;
      Interp up = reseeded(x_base, kB, kC + h);
      Interp dn = reseeded(x_base, kB, kC - h);
      double worst = 0.0, worst_psi = 0.0;
      for (double psi : probe) {
        const double fd = (up.eval(psi) - dn.eval(psi)) / (2 * h);
        const double an = Dc.eval(psi);
        const double r = rel(fd, an);
        if (r > worst) { worst = r; worst_psi = psi; }
      }
      printf("   step=%.0e  worst rel over 9 points = %.3e  (at psi=%.4g)\n",
             step, worst, worst_psi);
    }
    // And the same for b, where an exact independent check also exists.
    Interp Db = deriv_spline_b(x_base, kB, kC);
    const double h = kB * 1e-5;
    Interp up = reseeded(x_base, kB + h, kC), dn = reseeded(x_base, kB - h, kC);
    double worst = 0.0;
    for (double psi : probe) {
      worst = std::max(worst, rel((up.eval(psi) - dn.eval(psi)) / (2 * h), Db.eval(psi)));
    }
    printf("   the same in b, step=1e-05: worst rel = %.3e\n", worst);
  }

  // ---- B. the total, split ------------------------------------------------
  printf("\nB. the total dG/dc a rebuild measures, split into its two terms.\n");
  printf("   total = fixed-grid + grid-motion. The second is what report 05 7.6\n");
  printf("   rules out, and it is the only part that is not the model's own.\n\n");
  {
    Interp Dc = deriv_spline_c(x_base, kB, kC);
    const double h = kC * 1e-5;
    std::vector<double> xu, yu, xd, yd;
    phylloptim::cumulative_vulnerability_integral(kB, kC + h, kRes, xu, yu);
    phylloptim::cumulative_vulnerability_integral(kB, kC - h, kRes, xd, yd);
    Interp Gu, Gd;
    Gu.init(xu, yu); Gu.set_extrapolate(false);
    Gd.init(xd, yd); Gd.set_extrapolate(false);
    printf("   knots: %zu -> %zu / %zu, last knot %.10g -> %.10g / %.10g\n",
           x_base.size(), xu.size(), xd.size(), x_base.back(), xu.back(), xd.back());
    printf("   %10s %16s %16s %16s %10s\n", "psi", "total(rebuild)",
           "fixed grid", "grid motion", "share");
    for (double psi : probe) {
      const double total = (Gu.eval(psi) - Gd.eval(psi)) / (2 * h);
      const double fixed = Dc.eval(psi);
      const double motion = total - fixed;
      printf("   %10.4g %16.9e %16.9e %16.9e %9.2e\n", psi, total, fixed, motion,
             std::abs(total) > 0 ? std::abs(motion / total) : 0.0);
    }
  }

  // ---- C. does the root side rescale in root_b? ---------------------------
  printf("\nC. the root apparatus under root_b -> s*root_b, all four objects.\n");
  printf("   G scales, f_r does not, both arguments divide by s, and the two\n");
  printf("   bounds scale. If any one of these is wrong a rescale is unsound.\n\n");
  {
    for (double s : {1.001, 1.01, 1.1, 1.2}) {
      std::vector<double> x0, y0, x1, y1;
      phylloptim::cumulative_vulnerability_integral(kB, kC, kRes, x0, y0);
      phylloptim::cumulative_vulnerability_integral(kB * s, kC, kRes, x1, y1);
      Interp G0, G1;
      G0.init(x0, y0); G0.set_extrapolate(false);
      G1.init(x1, y1); G1.set_extrapolate(false);
      // f_r knots: exp(-(x_i/b)^c) with x_i proportional to b, so the VALUES are
      // identical at both b and only the positions move.
      std::vector<double> f0(x0.size()), f1(x1.size());
      for (size_t i = 0; i < x0.size(); ++i) f0[i] = exp(-pow(x0[i] / kB, kC));
      for (size_t i = 0; i < x1.size(); ++i) f1[i] = exp(-pow(x1[i] / (kB * s), kC));
      double fknot = 0.0;
      const size_t n = std::min(f0.size(), f1.size());
      for (size_t i = 0; i < n; ++i) fknot = std::max(fknot, rel(f0[i], f1[i]));
      Interp F0, F1;
      F0.init(x0, f0); F0.set_extrapolate(false);
      F1.init(x1, f1); F1.set_extrapolate(false);
      double wG = 0.0, wF = 0.0;
      for (double psi : probe) {
        // psi is inside the BASE domain; the rescaled read is at psi*s.
        wG = std::max(wG, rel(G1.eval(psi * s), s * G0.eval(psi)));
        wF = std::max(wF, rel(F1.eval(psi * s), F0.eval(psi)));
      }
      const double lim0 = phylloptim::cumulative_vulnerability_integral_limit(kB, kC);
      const double lim1 = phylloptim::cumulative_vulnerability_integral_limit(kB * s, kC);
      printf("   s=%-6.4g  knot count %zu/%zu  f_r knots identical to %.1e  "
             "G rescale %.2e  f_r rescale %.2e  limit %.2e  last knot %.2e\n",
             s, x0.size(), x1.size(), fknot, wG, wF,
             rel(lim1, s * lim0), rel(x1.back(), s * x0.back()));
    }
  }

  // ---- D. what a rebuild costs, by piece ---------------------------------
  printf("\nD. the pieces of a rebuild.\n");
  {
    const long reps = 3000;
    double sink = 0;
    auto t0 = clock_type::now();
    for (long r = 0; r < reps; ++r) {
      std::vector<double> x, y;
      phylloptim::cumulative_vulnerability_integral(kB, kC * (1 + r * 1e-12), kRes, x, y);
      sink += y.back();
    }
    printf("   seed %3zu knots (incomplete gammas): %8.3f us\n", x_base.size(),
           us_per(t0, clock_type::now(), reps));

    std::vector<double> x, y;
    phylloptim::cumulative_vulnerability_integral(kB, kC, kRes, x, y);
    t0 = clock_type::now();
    for (long r = 0; r < reps; ++r) {
      Interp s; s.init(x, y); s.set_extrapolate(false); sink += s.eval(1.0);
    }
    printf("   one interpolator init:              %8.3f us\n",
           us_per(t0, clock_type::now(), reps));

    t0 = clock_type::now();
    for (long r = 0; r < reps; ++r) {
      std::vector<double> dy(x.size());
      for (size_t i = 0; i < x.size(); ++i) {
        dy[i] = phylloptim::cumulative_vulnerability_integral_derivatives_at(
                    x[i], kB, kC * (1 + r * 1e-12)).dc;
      }
      sink += dy.back();
    }
    printf("   seed %3zu knots WITH dG/db, dG/dc:   %8.3f us   (the series)\n",
           x_base.size(), us_per(t0, clock_type::now(), reps));
    printf("   (sink %.6g)\n", sink);
  }
  return 0;
}
