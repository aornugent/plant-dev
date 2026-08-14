// Verification probe for the three proposals in docs/leaf-rows-cost.md §9.
//
// Nothing here is a test. Each block answers one question the design rests on,
// and prints the number rather than a verdict.
//
//   A  is moving stem_b by the homogeneity rescale the same row as rebuilding?
//   B  what does the moving knot grid cost the stem_c row?
//   C  what does a curve trait's drive cost against a non-curve one?
//   D  does vcmax_25 reach profit through set_traits?

#include <phylloptim.hpp>

#include "root_network.hpp"

#include <chrono>
#include <cmath>
#include <cstdio>
#include <vector>

namespace {

// The default trait vector in set_traits' argument order, from bench_gradient.
struct Traits { double v[13]; };
const Traits kBase{{96.0, 2.680147, 3.898245, 5.870283, 2.680147, 3.898245,
                    5.870283, 1.5, 157.44, 0.30, 0.7, 0.99, 7.5}};
const double kR_d_25 = 1.44;

void apply_traits(phylloptim::Leaf& l, const Traits& t) {
  l.set_traits(t.v[0], t.v[1], t.v[2], t.v[3], t.v[4], t.v[5], t.v[6], t.v[7],
               t.v[8], t.v[9], t.v[10], t.v[11], t.v[12], kR_d_25);
}

// One interior operating point, drivers as the rest of the suite uses them.
// Three layers, so the per-layer uptake rows are non-trivial.
const double kTheta = 0.000157, kKs = 1.0, kH = 5.0, kAreaLeaf = 0.05;

void set_drivers(phylloptim::Leaf& l) {
  std::vector<double> root(3, 1.0 / (3.0 * kAreaLeaf));
  std::vector<double> psi_soil{1.8, 2.0, 2.2};
  std::vector<double> depth{0.3, 0.6, 1.0};
  l.set_physiology(fixture::root_network(root, depth), 900.0, psi_soil, depth,
                   kKs * kTheta / kH, 2.0, 40.0, 25.0, 21.0, 101.3);
}

// What plant's record_leaf_outputs reads back after every drive: profit, the
// marginal profit at the held collar, and per-layer uptake.
struct Outputs {
  double profit;
  double marginal;
  double uptake[3];
};

Outputs read_at(phylloptim::Leaf& l, double collar) {
  Outputs o{};
  o.marginal = l.dprofit_droot_collar_psi(collar);
  l.evaluate_root_collar_psi(collar);
  o.profit = l.profit_;
  for (int i = 0; i < 3; ++i) { o.uptake[i] = l.soil_consumption_[i]; }
  return o;
}

// A central difference of every output in one trait, the way plant takes it:
// set_traits, re-drive, hold the collar.
Outputs row_by_rebuild(phylloptim::Leaf& l, int idx, double step,
                       double collar) {
  const double base = kBase.v[idx];
  const double h = std::max(std::abs(base), 1.0) * step;
  Outputs up{}, dn{};
  for (int side = 0; side < 2; ++side) {
    Traits t = kBase;
    t.v[idx] = base + (side == 0 ? h : -h);
    apply_traits(l, t);
    set_drivers(l);
    (side == 0 ? up : dn) = read_at(l, collar);
  }
  apply_traits(l, kBase);
  set_drivers(l);
  Outputs d{};
  d.profit = (up.profit - dn.profit) / (2 * h);
  d.marginal = (up.marginal - dn.marginal) / (2 * h);
  for (int i = 0; i < 3; ++i) {
    d.uptake[i] = (up.uptake[i] - dn.uptake[i]) / (2 * h);
  }
  return d;
}

// The same row in stem_b, moved by the homogeneity rescale. No rebuild, and no
// set_physiology either -- nothing it derives reads stem_b.
Outputs row_by_rescale_stem_b(phylloptim::Leaf& l, double step, double collar) {
  const double base = kBase.v[2];
  const double h = std::abs(base) * step;
  Outputs up{}, dn{};
  for (int side = 0; side < 2; ++side) {
    l.perturb_stem_b(base + (side == 0 ? h : -h));
    (side == 0 ? up : dn) = read_at(l, collar);
  }
  apply_traits(l, kBase);   // set_traits is the way back, and forces the rebuild
  set_drivers(l);
  Outputs d{};
  d.profit = (up.profit - dn.profit) / (2 * h);
  d.marginal = (up.marginal - dn.marginal) / (2 * h);
  for (int i = 0; i < 3; ++i) {
    d.uptake[i] = (up.uptake[i] - dn.uptake[i]) / (2 * h);
  }
  return d;
}

void print_row(const char* what, double step, const Outputs& o) {
  printf("  %-28s step=%.0e  dprofit=% .10e  dmarginal=% .10e  dE0=% .10e\n",
         what, step, o.profit, o.marginal, o.uptake[0]);
}

double rel(double x, double y) {
  const double s = std::max(std::abs(x), std::abs(y));
  return s > 0 ? std::abs(x - y) / s : 0.0;
}

using clock_type = std::chrono::steady_clock;
double us_per(clock_type::time_point a, clock_type::time_point b, long n) {
  return std::chrono::duration<double, std::micro>(b - a).count() / double(n);
}

}  // namespace

int main() {
  phylloptim::Leaf l;
  apply_traits(l, kBase);
  set_drivers(l);
  l.find_root_collar_psi();
  const double collar = l.opt_root_psi_;
  printf("operating point: collar=%.12g  profit=%.12g  marginal=%.3e\n\n",
         collar, l.profit_, l.dprofit_droot_collar_psi(collar));

  // ---- A. stem_b: is the rescale the same row as the rebuild? --------------
  printf("A. the stem_b row, rebuild against homogeneity rescale\n");
  const double steps[] = {1e-2, 1e-3, 1e-4, 1e-5, 1e-6};
  for (double s : steps) {
    const Outputs a = row_by_rebuild(l, 2, s, collar);
    const Outputs b = row_by_rescale_stem_b(l, s, collar);
    printf("  step=%.0e  rel diff: profit=%.3e marginal=%.3e E0=%.3e\n",
           s, rel(a.profit, b.profit), rel(a.marginal, b.marginal),
           rel(a.uptake[0], b.uptake[0]));
  }
  printf("\n  the two routes, side by side at plant's own step (1e-3):\n");
  print_row("rebuild", 1e-3, row_by_rebuild(l, 2, 1e-3, collar));
  print_row("rescale", 1e-3, row_by_rescale_stem_b(l, 1e-3, collar));

  // Jitter: neighbouring steps should agree if the route is quiet.
  printf("\n  jitter between neighbouring steps (dprofit/dstem_b):\n");
  for (int k = 0; k < 4; ++k) {
    const double s1 = 1e-3 * (1.0 + 0.01 * k), s2 = 1e-3 * (1.0 + 0.01 * (k + 1));
    const double r1 = row_by_rebuild(l, 2, s1, collar).profit;
    const double r2 = row_by_rebuild(l, 2, s2, collar).profit;
    const double c1 = row_by_rescale_stem_b(l, s1, collar).profit;
    const double c2 = row_by_rescale_stem_b(l, s2, collar).profit;
    printf("    rebuild %.12g -> %.12g (rel %.2e)   rescale %.12g -> %.12g (rel %.2e)\n",
           r1, r2, rel(r1, r2), c1, c2, rel(c1, c2));
  }

  // ---- B. stem_c: what does the moving grid cost? --------------------------
  // The rebuild moves every knot, because psi_max = b*log(100)^(1/c). Holding
  // the positions and reseeding the values at the new c is the same difference
  // with the discretisation held still.
  printf("\nB. the stem_c row, moving grid against held knot positions\n");
  {
    std::vector<double> x_base, y_base;
    phylloptim::cumulative_vulnerability_integral(kBase.v[2], kBase.v[1], 100,
                                                 x_base, y_base);
    printf("  base grid: %zu knots, psi_max=%.12g\n", x_base.size(),
           x_base.back());
    for (double s : steps) {
      const double base_c = kBase.v[1];
      const double h = std::abs(base_c) * s;
      // How far the knots themselves move over the perturbation.
      std::vector<double> xu, yu, xd, yd;
      phylloptim::cumulative_vulnerability_integral(kBase.v[2], base_c + h, 100,
                                                   xu, yu);
      phylloptim::cumulative_vulnerability_integral(kBase.v[2], base_c - h, 100,
                                                   xd, yd);
      const double knot_shift = rel(xu.back(), xd.back());
      // The row as plant takes it, and the row with the grid held.
      const Outputs moving = row_by_rebuild(l, 1, s, collar);
      Outputs up{}, dn{};
      for (int side = 0; side < 2; ++side) {
        const double c_new = base_c + (side == 0 ? h : -h);
        std::vector<double> y_held(x_base.size());
        for (size_t i = 0; i < x_base.size(); ++i) {
          y_held[i] = phylloptim::cumulative_vulnerability_integral_at(
              x_base[i], kBase.v[2], c_new);
        }
        Traits t = kBase;
        t.v[1] = c_new;
        apply_traits(l, t);
        // Overwrite the rebuilt splines with ones on the BASE positions.
        l.transpiration_from_psi.init(x_base, y_held);
        l.transpiration_from_psi.set_extrapolate(false);
        l.psi_from_transpiration.init(y_held, x_base);
        l.psi_from_transpiration.set_extrapolate(false);
        set_drivers(l);
        (side == 0 ? up : dn) = read_at(l, collar);
      }
      apply_traits(l, kBase);
      set_drivers(l);
      const double held_profit = (up.profit - dn.profit) / (2 * h);
      const double held_E0 = (up.uptake[0] - dn.uptake[0]) / (2 * h);
      printf("  step=%.0e knot_shift=%.2e | moving dprofit=% .10e held=% .10e "
             "rel=%.3e | E0 rel=%.3e\n",
             s, knot_shift, moving.profit, held_profit,
             rel(moving.profit, held_profit),
             rel(moving.uptake[0], held_E0));
    }
  }

  // ---- C. what a curve trait's drive costs -------------------------------
  printf("\nC. cost of one perturbed evaluation, by trait family\n");
  {
    const long reps = 2000;
    struct { int idx; const char* name; } probe[] = {
      {2, "stem_b (curve)"}, {1, "stem_c (curve)"}, {5, "root_b (curve)"},
      {4, "root_c (curve)"}, {7, "beta2 (no curve)"}, {9, "a (no curve)"},
      {12, "cost_scale (no curve)"}, {0, "vcmax_25 (no curve)"}};
    for (auto& p : probe) {
      double sink = 0;
      const auto t0 = clock_type::now();
      for (long r = 0; r < reps; ++r) {
        Traits t = kBase;
        t.v[p.idx] = kBase.v[p.idx] * (1.0 + 1e-3 * (1.0 + r * 1e-9));
        apply_traits(l, t);
        set_drivers(l);
        sink += l.dprofit_droot_collar_psi(collar);
        sink += l.evaluate_root_collar_psi(collar);
      }
      printf("  %-24s %8.3f us/drive   (sink %.6g)\n", p.name,
             us_per(t0, clock_type::now(), reps), sink);
    }
    // And the rescale route for stem_b, which pays neither.
    double sink = 0;
    const auto t0 = clock_type::now();
    for (long r = 0; r < reps; ++r) {
      l.perturb_stem_b(kBase.v[2] * (1.0 + 1e-3 * (1.0 + r * 1e-9)));
      sink += l.dprofit_droot_collar_psi(collar);
      sink += l.evaluate_root_collar_psi(collar);
    }
    printf("  %-24s %8.3f us/drive   (sink %.6g)\n", "stem_b by rescale",
           us_per(t0, clock_type::now(), reps), sink);
    apply_traits(l, kBase);
    set_drivers(l);
  }

  // ---- D. does vcmax_25 reach profit through set_traits? ------------------
  printf("\nD. vcmax_25, jmax_25 and R_d_25 through set_traits\n");
  {
    // R_d_25 is the 14th argument rather than a member of the vector, so it is
    // moved on its own below.
    const double base_rd = kR_d_25;
    const double h_rd = base_rd * 1e-3;
    double p_rd[2], rd[2];
    for (int side = 0; side < 2; ++side) {
      const double v = base_rd + (side == 0 ? h_rd : -h_rd);
      l.set_traits(kBase.v[0], kBase.v[1], kBase.v[2], kBase.v[3], kBase.v[4],
                   kBase.v[5], kBase.v[6], kBase.v[7], kBase.v[8], kBase.v[9],
                   kBase.v[10], kBase.v[11], kBase.v[12], v);
      set_drivers(l);
      l.evaluate_root_collar_psi(collar);
      p_rd[side] = l.profit_;
      rd[side] = l.R_d_;
    }
    apply_traits(l, kBase);
    set_drivers(l);
    printf("  %-9s derived moved %.12g -> %.12g   dprofit/dtrait = % .10e\n",
           "R_d_25", rd[1], rd[0], (p_rd[0] - p_rd[1]) / (2 * h_rd));

    for (int idx : {0, 8}) {
      const double base = kBase.v[idx];
      const double h = base * 1e-3;
      double p[2], vc[2];
      for (int side = 0; side < 2; ++side) {
        Traits t = kBase;
        t.v[idx] = base + (side == 0 ? h : -h);
        apply_traits(l, t);
        set_drivers(l);
        l.evaluate_root_collar_psi(collar);
        p[side] = l.profit_;
        vc[side] = (idx == 0 ? l.vcmax_ : l.jmax_);
      }
      apply_traits(l, kBase);
      set_drivers(l);
      printf("  %-9s derived moved %.12g -> %.12g   dprofit/dtrait = % .10e\n",
             idx == 0 ? "vcmax_25" : "jmax_25", vc[1], vc[0],
             (p[0] - p[1]) / (2 * h));
    }
  }
  return 0;
}
