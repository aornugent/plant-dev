// The photosynthesis family's profit row, and whether it collapses.
//
// At a frozen collar these three traits move nothing but assimilation: the stem
// potential, the stomatal conductance and the hydraulic cost are all fixed, and
// the only thing that responds is the intercellular CO2 the residual places. So
//
//   dPi/dtheta = dA/dtheta * (1 - A'/g_ci * umol_to_mol)
//              = dA/dtheta * gc * inv_atm / g_ci
//
// with dA/dtheta the kernel's own partial at FIXED ci -- which costs no solve at
// all, only a re-evaluation of a pure function.
#include <phylloptim.hpp>
#include "root_network.hpp"
#include <cmath>
#include <cstdio>
#include <vector>

namespace {
const double kTheta = 0.000157, kKs = 1.0, kH = 5.0;
std::vector<double> kDepth{0.3, 0.6, 1.0, 1.4, 1.8};
std::vector<double> kCarbon{9.0, 6.0, 4.0, 2.5, 1.5};
struct T { double v[13]; };
const T kBase{{96.0, 2.680147, 3.898245, 5.870283, 2.680147, 3.898245,
               5.870283, 1.5, 157.44, 0.30, 0.7, 0.99, 7.5}};
void apply(phylloptim::Leaf& l, const T& t) {
  l.set_traits(t.v[0],t.v[1],t.v[2],t.v[3],t.v[4],t.v[5],t.v[6],t.v[7],
               t.v[8],t.v[9],t.v[10],t.v[11],t.v[12], 1.44);
}
void seat(phylloptim::Leaf& l, const std::vector<double>& psi, double ppfd) {
  l.set_physiology(fixture::root_network(kCarbon, kDepth), ppfd, psi, kDepth,
                   kKs*kTheta/kH, 2.0, 40.0, 25.0, 21.0, 101.3);
}
double rel(double a,double b){double s=std::max(std::abs(a),std::abs(b));return s>0?std::abs(a-b)/s:0.0;}

// dA/dtheta at FIXED ci, by moving the trait on the leaf and re-evaluating the
// kernel. No solve: `a` and the electron-transport curvature reach A only
// through electron_transport_, which is one kernel call to refresh.
double dA_dtheta(phylloptim::Leaf& l, int which, double ci, double step) {
  double out[2];
  const double base = (which == 0) ? l.a
                    : (which == 1) ? l.curv_fact_elec_trans
                                   : l.curv_fact_colim;
  const double h = base * step;
  for (int side = 0; side < 2; ++side) {
    const double v = base + (side == 0 ? h : -h);
    if (which == 0) { l.a = v; } else if (which == 1) { l.curv_fact_elec_trans = v; }
    else { l.curv_fact_colim = v; }
    if (which != 2) { l.electron_transport_ = l.electron_transport(); }
    out[side] = l.assim_colimited(ci);
  }
  if (which == 0) { l.a = base; } else if (which == 1) { l.curv_fact_elec_trans = base; }
  else { l.curv_fact_colim = base; }
  if (which != 2) { l.electron_transport_ = l.electron_transport(); }
  return (out[0] - out[1]) / (2 * h);
}
}  // namespace

int main() {
  struct S { const char* n; std::vector<double> psi; double ppfd; };
  const std::vector<S> states = {{"wet",{1.0,1.1,1.2,1.3,1.4},900.0},
                                 {"dry",{2.6,2.8,3.0,3.2,3.4},900.0},
                                 {"shaded",{1.4,1.5,1.6,1.7,1.8},60.0}};
  const int idx[3] = {9, 10, 11};                 // a, curv_elec, curv_colim
  const char* nm[3] = {"a", "curv_elec", "curv_colim"};

  for (const S& st : states) {
    phylloptim::Leaf l; apply(l, kBase); seat(l, st.psi, st.ppfd);
    l.find_root_collar_psi();
    const double collar = l.opt_root_psi_;
    l.evaluate_root_collar_psi(collar);
    const double ci = l.ci_;
    const double gc = l.stom_cond_CO2_;
    using AD = xad::fwd<double>::active_type;
    AD ci_ad = ci;  xad::derivative(ci_ad) = 1.0;
    const double A_prime = xad::derivative(l.assim_colimited_kernel(ci_ad));
    const double inv_atm = 1.0 / (l.atm_kpa_ * phylloptim::kPa_to_Pa);
    const double g_ci = A_prime * phylloptim::umol_to_mol + gc * inv_atm;
    printf("\n=== %s: collar %.8g  ci %.8g  A' %.8g  gc %.6e  g_ci %.6e\n",
           st.n, collar, ci, A_prime, gc, g_ci);

    for (int k = 0; k < 3; ++k) {
      // The claim.
      const double dA = dA_dtheta(l, k, ci, 1e-6);
      const double pred = dA * gc * inv_atm / g_ci;

      // Differencing the solve, as the production path does.
      const double base = kBase.v[idx[k]];
      const double h = base * 1e-4;
      double p[2];
      for (int side = 0; side < 2; ++side) {
        T t = kBase; t.v[idx[k]] = base + (side == 0 ? h : -h);
        apply(l, t); seat(l, st.psi, st.ppfd);
        l.evaluate_root_collar_psi(collar);
        p[side] = l.profit_;
      }
      apply(l, kBase); seat(l, st.psi, st.ppfd); l.evaluate_root_collar_psi(collar);
      const double diff = (p[0] - p[1]) / (2 * h);
      printf("  %-11s dA/dtheta % .8e   predicted % .8e   solve-differenced % .8e   rel %.3e\n",
             nm[k], dA, pred, diff, rel(pred, diff));
    }
  }
  return 0;
}
