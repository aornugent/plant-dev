// What a vulnerability rebuild spends, and what one series loop would spend
// instead.
//
// The four curve traits are most of a reverse-mode block, and the only sanctioned
// route out is to make the REBUILD cheaper -- the grid moves with the trait
// because the forward model rebuilds it, so holding the grid differentiates a
// different function (that route was built twice and refuted twice).
//
// This measures the rebuild's parts, the series-seeded alternative, and -- the
// part that decides whether it is takeable -- how far the two disagree in the
// leaf's own outputs and in the ROWS plant reads off them.
//
// Two things it is looking for that the work plan has not priced:
//   * the ROOT rebuild seeds two knot vectors from two separate loops, and the
//     series returns both from one -- exp(-x) is already computed inside it;
//   * whether a series-seeded curve moves a ROW, as against moving a value.
#include <phylloptim.hpp>
#include "root_network.hpp"
#include <chrono>
#include <cmath>
#include <cstdio>
#include <vector>

namespace {

const double kTheta = 0.000157, kKs = 1.0, kH = 5.0;
std::vector<double> kDepth{0.3, 0.6, 1.0, 1.4, 1.8};
std::vector<double> kCarbon{9.0, 6.0, 4.0, 2.5, 1.5};

// vcmax_25, stem_c, stem_b, psi_crit, root_c, root_b, root_psi_crit, beta2,
// jmax_25, a, curv_elec, curv_colim, cost_scale, R_d_25
struct T { double v[14]; };
const T kBase{{96.0, 2.680147, 3.898245, 5.870283, 2.680147, 3.898245,
               5.870283, 1.5, 157.44, 0.30, 0.7, 0.99, 7.5, 1.44}};

void apply(phylloptim::Leaf& l, const T& t) {
  l.set_traits(t.v[0], t.v[1], t.v[2], t.v[3], t.v[4], t.v[5], t.v[6], t.v[7],
               t.v[8], t.v[9], t.v[10], t.v[11], t.v[12], t.v[13]);
}
void seat(phylloptim::Leaf& l, const std::vector<double>& psi, double ppfd) {
  l.set_physiology(fixture::root_network(kCarbon, kDepth), ppfd, psi, kDepth,
                   kKs * kTheta / kH, 2.0, 40.0, 25.0, 21.0, 101.3);
}
double rel(double a, double b) {
  const double s = std::max(std::abs(a), std::abs(b));
  return s > 0 ? std::abs(a - b) / s : 0.0;
}
template <class F> double time_us(F&& f, int reps) {
  const auto t0 = std::chrono::steady_clock::now();
  for (int i = 0; i < reps; ++i) f();
  const auto t1 = std::chrono::steady_clock::now();
  return std::chrono::duration<double, std::micro>(t1 - t0).count() / reps;
}

// The knot grid, exactly as cumulative_vulnerability_integral lays it out.
std::vector<double> grid(double b, double c, double resolution) {
  std::vector<double> x{0.0};
  const double psi_max = phylloptim::vulnerability_psi_max(b, c);
  const double step = psi_max / resolution;
  for (double psi = step; psi <= psi_max; psi += step) x.push_back(psi);
  return x;
}

// Seed BOTH knot vectors the root curve needs from one series pass. The stem
// needs only the first.
void seed_series(const std::vector<double>& x, double b, double c,
                 std::vector<double>& G, std::vector<double>& f_r) {
  G.resize(x.size());
  f_r.resize(x.size());
  for (std::size_t i = 0; i < x.size(); ++i) {
    const auto d =
        phylloptim::cumulative_vulnerability_integral_derivatives_at(x[i], b, c);
    G[i] = d.value;
    f_r[i] = d.dpsi;
  }
}

// The same two vectors the way the model seeds them today.
void seed_boost(const std::vector<double>& x, double b, double c,
                std::vector<double>& G, std::vector<double>& f_r) {
  G.resize(x.size());
  f_r.resize(x.size());
  for (std::size_t i = 0; i < x.size(); ++i) {
    G[i] = phylloptim::cumulative_vulnerability_integral_at(x[i], b, c);
    f_r[i] = exp(-pow(x[i] / b, c));
  }
}

}  // namespace

int main() {
  const double res = 100.0;
  const double b = kBase.v[2], c = kBase.v[1];

  // ---- 1. what a knot costs, by route ------------------------------------
  {
    const std::vector<double> x = grid(b, c, res);
    printf("=== knot seeding, %zu knots, b=%g c=%g ===\n", x.size(), b, c);

    std::vector<double> Gb(x.size()), fb(x.size()), Gs(x.size()), fs(x.size());
    const double t_boost_G = time_us([&] {
      for (std::size_t i = 0; i < x.size(); ++i)
        Gb[i] = phylloptim::cumulative_vulnerability_integral_at(x[i], b, c);
    }, 2000);
    seed_boost(x, b, c, Gb, fb);

    const double t_boost_pair = time_us([&] { seed_boost(x, b, c, Gb, fb); }, 2000);
    const double t_series_pair = time_us([&] { seed_series(x, b, c, Gs, fs); }, 2000);
    seed_series(x, b, c, Gs, fs);

    // and the series' trait partials, which come out of the same loop
    const double t_series_full = time_us([&] {
      for (std::size_t i = 0; i < x.size(); ++i) {
        const auto d =
            phylloptim::cumulative_vulnerability_integral_derivatives_at(x[i], b, c);
        Gs[i] = d.value + d.db * 0.0 + d.dc * 0.0;
      }
    }, 2000);
    seed_series(x, b, c, Gs, fs);

    printf("  boost, G only              %8.2f us\n", t_boost_G);
    printf("  boost, G + exp(-x) loop    %8.2f us   <- what the ROOT curve seeds\n",
           t_boost_pair);
    printf("  series, G + f_r together   %8.2f us\n", t_series_pair);
    printf("  series, + both partials    %8.2f us\n", t_series_full);

    double wG = 0, wf = 0;
    std::size_t bitG = 0, bitf = 0;
    for (std::size_t i = 0; i < x.size(); ++i) {
      wG = std::max(wG, rel(Gb[i], Gs[i]));
      wf = std::max(wf, rel(fb[i], fs[i]));
      if (Gb[i] == Gs[i]) ++bitG;
      if (fb[i] == fs[i]) ++bitf;
    }
    printf("  worst rel per knot: G %.3e (%zu/%zu bit-identical), "
           "f_r %.3e (%zu/%zu)\n", wG, bitG, x.size(), wf, bitf, x.size());

    const double t_limit = time_us([&] {
      volatile double v =
          phylloptim::cumulative_vulnerability_integral_limit(b, c);
      (void)v;
    }, 20000);
    printf("  boost tgamma for the cap   %8.3f us\n", t_limit);
  }

  // ---- 2. what a whole drive costs today ---------------------------------
  {
    phylloptim::Leaf l;
    apply(l, kBase);
    seat(l, {1.0, 1.1, 1.2, 1.3, 1.4}, 900.0);
    printf("\n=== set_traits, by which trait moved ===\n");

    auto drive_trait = [&](int idx, const char* name) {
      T t = kBase;
      const double h = t.v[idx] * 1e-3;
      int side = 0;
      const double us = time_us([&] {
        t.v[idx] = kBase.v[idx] + (side ? h : -h);
        side ^= 1;
        apply(l, t);
      }, 2000);
      apply(l, kBase);
      printf("  %-14s %8.2f us\n", name, us);
    };
    drive_trait(2, "stem_b");
    drive_trait(1, "stem_c");
    drive_trait(5, "root_b");
    drive_trait(4, "root_c");
    drive_trait(9, "a");
    drive_trait(7, "beta2");

    // The two interpolator inits, so the residue after the gammas is named.
    const std::vector<double> x = grid(b, c, res);
    std::vector<double> G, f;
    seed_boost(x, b, c, G, f);
    odelia::interpolator::Interpolator sp;
    printf("  one init       %8.2f us\n", time_us([&] { sp.init(x, G); }, 2000));
  }

  // ---- 3. does a series-seeded curve move a VALUE, or a ROW? --------------
  // Two leaves at identical traits: one as the model builds it, one with both
  // curves re-seeded from the series on the SAME grid. Then the same central
  // differences plant takes, on each.
  {
    struct S { const char* n; std::vector<double> psi; double ppfd; };
    const std::vector<S> states = {{"wet", {1.0, 1.1, 1.2, 1.3, 1.4}, 900.0},
                                   {"dry", {2.6, 2.8, 3.0, 3.2, 3.4}, 900.0},
                                   {"shaded", {1.4, 1.5, 1.6, 1.7, 1.8}, 60.0}};

    // Re-seed both curves from the series, on the grid set_traits just built.
    auto reseed = [&](phylloptim::Leaf& l) {
      const std::vector<double> xs = grid(l.stem_b, l.stem_c, res);
      std::vector<double> G, f;
      seed_series(xs, l.stem_b, l.stem_c, G, f);
      l.transpiration_from_psi.init(xs, G);
      l.transpiration_from_psi.set_extrapolate(false);
      l.psi_from_transpiration.init(G, xs);
      l.psi_from_transpiration.set_extrapolate(false);

      const std::vector<double> xr = grid(l.roots_.root_b, l.roots_.root_c, res);
      std::vector<double> Gr, fr;
      seed_series(xr, l.roots_.root_b, l.roots_.root_c, Gr, fr);
      l.roots_.root_vuln_from_psi.init(xr, fr);
      l.roots_.root_vuln_from_psi.set_extrapolate(false);
      l.roots_.root_vuln_integral_from_psi.init(xr, Gr);
      l.roots_.root_vuln_integral_from_psi.set_extrapolate(true);
      l.roots_.root_vuln_last_knot_ = l.roots_.root_vuln_from_psi.max();
    };

    for (const S& st : states) {
      phylloptim::Leaf l;
      apply(l, kBase);
      seat(l, st.psi, st.ppfd);
      l.find_root_collar_psi();
      const double collar = l.opt_root_psi_;

      printf("\n=== %s: collar %.10g ===\n", st.n, collar);

      // the VALUE, both seedings
      l.evaluate_root_collar_psi(collar);
      const double p_boost = l.profit_, m_boost = l.dprofit_droot_collar_psi(collar);
      reseed(l);
      l.evaluate_root_collar_psi(collar);
      const double p_ser = l.profit_, m_ser = l.dprofit_droot_collar_psi(collar);
      printf("  profit   boost % .12g  series % .12g   rel %.3e\n",
             p_boost, p_ser, rel(p_boost, p_ser));
      printf("  marginal boost % .12g  series % .12g   rel %.3e\n",
             m_boost, m_ser, rel(m_boost, m_ser));

      // the ROWS, both seedings: the same central difference plant takes
      const int idx[4] = {2, 1, 5, 4};
      const char* nm[4] = {"stem_b", "stem_c", "root_b", "root_c"};
      for (int k = 0; k < 4; ++k) {
        double row[2][2];  // [seeding][profit, marginal]
        for (int mode = 0; mode < 2; ++mode) {
          double p[2], m[2];
          for (int side = 0; side < 2; ++side) {
            T t = kBase;
            const double h = kBase.v[idx[k]] * 1e-3;
            t.v[idx[k]] = kBase.v[idx[k]] + (side == 0 ? h : -h);
            apply(l, t);
            seat(l, st.psi, st.ppfd);
            if (mode == 1) reseed(l);
            l.evaluate_root_collar_psi(collar);
            p[side] = l.profit_;
            m[side] = l.dprofit_droot_collar_psi(collar);
          }
          const double h = kBase.v[idx[k]] * 1e-3;
          row[mode][0] = (p[0] - p[1]) / (2 * h);
          row[mode][1] = (m[0] - m[1]) / (2 * h);
        }
        apply(l, kBase);
        seat(l, st.psi, st.ppfd);
        printf("  %-8s dPi/dt  boost % .10e  series % .10e  rel %.3e\n",
               nm[k], row[0][0], row[1][0], rel(row[0][0], row[1][0]));
        printf("  %-8s dR/dt   boost % .10e  series % .10e  rel %.3e\n",
               "", row[0][1], row[1][1], rel(row[0][1], row[1][1]));
      }
    }
  }

  // ---- 4. the falsifier: can the series' domain guard fire? ---------------
  // It calls util::stop past x_max, and a stop inside a gradient run is a hard
  // failure rather than a wrong number. The grid ends where x == x_max by
  // construction, so the margin is the whole of the safety.
  {
    printf("\n=== domain sweep, b in [0.05, 50], c in [0.25, 30] ===\n");
    double worst_G = 0, worst_f = 0, worst_x = 0, wb = 0, wc = 0;
    long n = 0, stops = 0;
    const double x_max = phylloptim::vulnerability_x_max();
    for (double cc = 0.25; cc <= 30.0; cc *= 1.15) {
      for (double bb = 0.05; bb <= 50.0; bb *= 1.4) {
        for (double psi : grid(bb, cc, res)) {
          const double xv = (psi > 0) ? pow(psi / bb, cc) : 0.0;
          worst_x = std::max(worst_x, xv / x_max);
          double Gs = 0, fs = 0;
          try {
            const auto d =
                phylloptim::cumulative_vulnerability_integral_derivatives_at(
                    psi, bb, cc);
            Gs = d.value;
            fs = d.dpsi;
          } catch (...) {
            ++stops;
            printf("  STOP at b=%g c=%g psi=%g  x/x_max=%.17g\n", bb, cc, psi,
                   xv / x_max);
            continue;
          }
          const double G = phylloptim::cumulative_vulnerability_integral_at(psi, bb, cc);
          const double f = (psi > 0) ? exp(-pow(psi / bb, cc)) : 1.0;
          const double rG = rel(G, Gs);
          if (rG > worst_G) { worst_G = rG; wb = bb; wc = cc; }
          worst_f = std::max(worst_f, rel(f, fs));
          ++n;
        }
      }
    }
    printf("  knots swept %ld, guard fired %ld times\n", n, stops);
    printf("  worst x/x_max reached   %.17g\n", worst_x);
    printf("  worst rel G             %.3e  at b=%g c=%g\n", worst_G, wb, wc);
    printf("  worst rel f_r           %.3e\n", worst_f);
  }
  return 0;
}
