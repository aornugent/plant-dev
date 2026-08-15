// What prepare_collar_solve costs, and which perturbations may share one.
//
// Every drive plant makes calls evaluate_root_collar_psi, which runs
// prepare_collar_solve on entry: one supply cache rebuild and two root-finds for
// the feasible interval's endpoints. phylloptim provides profit_at_collar_psi as
// a separate entry point so a caller taking several collar potentials in one
// step can prepare once -- but the hoist is only legitimate where the
// perturbation cannot move the interval, and that has to be argued per family
// rather than applied to the loop.
//
// This answers both halves with numbers: what share of a drive the preparation
// is now that the vulnerability rebuild is four times cheaper, and whether each
// family's perturbation moves the two endpoints at all.
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
struct T { double v[14]; };
const T kBase{{96.0, 2.680147, 3.898245, 5.870283, 2.680147, 3.898245,
               5.870283, 1.5, 157.44, 0.30, 0.7, 0.99, 7.5, 1.44}};
const char* kName[14] = {"vcmax_25", "stem_c", "stem_b", "psi_crit", "root_c",
                         "root_b", "root_psi_crit", "beta2", "jmax_25", "a",
                         "curv_elec", "curv_colim", "cost_scale", "R_d_25"};

void apply(phylloptim::Leaf& l, const T& t) {
  l.set_traits(t.v[0], t.v[1], t.v[2], t.v[3], t.v[4], t.v[5], t.v[6], t.v[7],
               t.v[8], t.v[9], t.v[10], t.v[11], t.v[12], t.v[13]);
}
void seat(phylloptim::Leaf& l, const std::vector<double>& carbon,
          const std::vector<double>& psi, double ppfd, double kmax) {
  l.set_physiology(fixture::root_network(carbon, kDepth), ppfd, psi, kDepth,
                   kmax, 2.0, 40.0, 25.0, 21.0, 101.3);
}
template <class F> double time_us(F&& f, int reps) {
  const auto t0 = std::chrono::steady_clock::now();
  for (int i = 0; i < reps; ++i) f();
  const auto t1 = std::chrono::steady_clock::now();
  return std::chrono::duration<double, std::micro>(t1 - t0).count() / reps;
}
double rel(double a, double b) {
  const double s = std::max(std::abs(a), std::abs(b));
  return s > 0 ? std::abs(a - b) / s : 0.0;
}

}  // namespace

int main() {
  const std::vector<double> psi{2.6, 2.8, 3.0, 3.2, 3.4};   // dry: the regime that matters
  const double ppfd = 900.0, kmax = kKs * kTheta / kH;

  phylloptim::Leaf l;
  apply(l, kBase);
  seat(l, kCarbon, psi, ppfd, kmax);
  l.find_root_collar_psi();
  const double collar = l.opt_root_psi_;

  // ---- 1. what the preparation costs, against what it precedes ------------
  {
    double a = 0, b = 0, bnd_a = 0, bnd_b = 0;
    l.prepare_collar_solve(bnd_a, bnd_b);
    printf("=== cost per call, dry state ===\n");
    printf("  prepare_collar_solve            %8.3f us\n",
           time_us([&] { l.prepare_collar_solve(a, b); }, 20000));
    printf("  supply_begin_solve alone        %8.3f us\n",
           time_us([&] { volatile double v = l.supply_begin_solve(); (void)v; }, 20000));
    l.prepare_collar_solve(a, b);
    printf("  evaluate_root_collar_psi        %8.3f us   <- what every drive calls\n",
           time_us([&] { volatile double v = l.evaluate_root_collar_psi(collar); (void)v; }, 5000));
    printf("  profit_at_collar_psi (prepared) %8.3f us   <- the hoisted entry point\n",
           time_us([&] { volatile double v = l.profit_at_collar_psi(collar, bnd_a, bnd_b); (void)v; }, 5000));
    printf("  dprofit_droot_collar_psi        %8.3f us\n",
           time_us([&] { volatile double v = l.dprofit_droot_collar_psi(collar); (void)v; }, 5000));
    l.evaluate_root_collar_psi(collar);
    printf("  a CURVE set_traits              %8.3f us\n", time_us([&] {
      static int s = 0; T t = kBase;
      t.v[2] = kBase.v[2] * (s ? 1.001 : 0.999); s ^= 1; apply(l, t); }, 5000));
    apply(l, kBase); seat(l, kCarbon, psi, ppfd, kmax);
  }

  // ---- 2. does the family's perturbation move the interval? ---------------
  // The endpoints prepare_collar_solve computes, read back after each move. A
  // family whose bounds are bit-identical may share one preparation; one whose
  // bounds move may not, whatever the argument says.
  {
    printf("\n=== do the feasible bounds move? (relative, and bit-equality) ===\n");
    auto bounds = [&](double& lo, double& hi) {
      l.prepare_collar_solve(lo, hi);
    };
    double lo0 = 0, hi0 = 0;
    apply(l, kBase); seat(l, kCarbon, psi, ppfd, kmax); bounds(lo0, hi0);
    printf("  base bounds: %.17g  %.17g\n", lo0, hi0);

    auto report = [&](const char* what, double lo, double hi) {
      const bool same = (lo == lo0) && (hi == hi0);
      printf("  %-22s %-9s lo rel %.2e  hi rel %.2e\n", what,
             same ? "IDENTICAL" : "MOVES", rel(lo, lo0), rel(hi, hi0));
    };

    double lo = 0, hi = 0;
    // radiation
    seat(l, kCarbon, psi, ppfd * 1.001, kmax); bounds(lo, hi);
    report("radiation", lo, hi);
    // conductance
    seat(l, kCarbon, psi, ppfd, kmax * 1.001); bounds(lo, hi);
    report("conductance kmax", lo, hi);
    // one layer's root carbon
    {
      std::vector<double> c2 = kCarbon; c2[2] *= 1.001;
      seat(l, c2, psi, ppfd, kmax); bounds(lo, hi);
      report("root carbon (layer 2)", lo, hi);
    }
    // one soil potential
    {
      std::vector<double> p2 = psi; p2[2] *= 1.001;
      seat(l, kCarbon, p2, ppfd, kmax); bounds(lo, hi);
      report("soil potential (2)", lo, hi);
    }
    // every leaf trait, one at a time
    for (int k = 0; k < 14; ++k) {
      T t = kBase; t.v[k] = kBase.v[k] * 1.001;
      apply(l, t); seat(l, kCarbon, psi, ppfd, kmax); bounds(lo, hi);
      report(kName[k], lo, hi);
    }
    apply(l, kBase); seat(l, kCarbon, psi, ppfd, kmax);
  }

  // ---- 3. what a hoist would actually save, at the current drive count ----
  {
    printf("\n=== what is left to hoist, per cohort per stage ===\n");
    double a = 0, b = 0;
    const double t_prep = time_us([&] { l.prepare_collar_solve(a, b); }, 20000);
    l.prepare_collar_solve(a, b);
    const double t_eval = time_us([&] {
      volatile double v = l.evaluate_root_collar_psi(collar); (void)v; }, 5000);
    const double t_curve = time_us([&] {
      static int s = 0; T t = kBase;
      t.v[2] = kBase.v[2] * (s ? 1.001 : 0.999); s ^= 1; apply(l, t); }, 5000);
    apply(l, kBase); seat(l, kCarbon, psi, ppfd, kmax);
    // Families that can share one preparation once the photosynthesis and cost
    // traits are answered in closed form: radiation (2), conductance (2), the
    // curvature (0 -- it re-uses the seated leaf). Everything else moves the
    // supply or is gone.
    const int hoistable_drives = 4;
    printf("  prepare is %.1f%% of one evaluate_root_collar_psi\n",
           100.0 * t_prep / t_eval);
    printf("  hoistable drives %d  ->  saves %.2f us\n",
           hoistable_drives, hoistable_drives * t_prep);
    printf("  against 8 curve drives at %.2f us of set_traits alone = %.1f us\n",
           t_curve, 8 * t_curve);
  }
  return 0;
}
