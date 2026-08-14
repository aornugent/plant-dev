// Two questions about the carbon-side leaf traits.
//   A  is d(uptake_i)/d(trait) at a frozen collar already exactly zero?
//   B  the cost traits enter one kernel and nothing else, so their rows are
//      elementary. Check the closed forms against differencing.
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
}
int main() {
  struct S { const char* n; std::vector<double> psi; double ppfd; };
  const std::vector<S> states = {{"wet",{1.0,1.1,1.2,1.3,1.4},900.0},
                                 {"dry",{2.6,2.8,3.0,3.2,3.4},900.0},
                                 {"shaded",{1.4,1.5,1.6,1.7,1.8},60.0}};
  // beta2 is index 7, cost_scale (g1_TF24) index 12.
  const int idx[2] = {7, 12};  const char* nm[2] = {"beta2", "cost_scale"};
  for (const S& st : states) {
    phylloptim::Leaf l; apply(l, kBase); seat(l, st.psi, st.ppfd);
    l.find_root_collar_psi();
    const double collar = l.opt_root_psi_;
    const double psi_stem = l.opt_psi_stem_;
    const double q = 1.0 - l.proportion_of_conductivity(psi_stem);
    const double C  = l.hydraulic_cost_TF(psi_stem);
    printf("\n=== %s: collar %.8g  psi_stem %.8g  q %.8g  C %.8g\n",
           st.n, collar, psi_stem, q, C);
    for (int k = 0; k < 2; ++k) {
      const double base = kBase.v[idx[k]];
      const double h = base * 1e-4;
      double p[2], u0[5], u1[5], m[2];
      for (int side = 0; side < 2; ++side) {
        T t = kBase; t.v[idx[k]] = base + (side==0?h:-h);
        apply(l, t); seat(l, st.psi, st.ppfd);
        m[side] = l.dprofit_droot_collar_psi(collar);
        l.evaluate_root_collar_psi(collar);
        p[side] = l.profit_;
        for (int i=0;i<5;++i) (side==0?u0:u1)[i] = l.soil_consumption_[i];
      }
      apply(l, kBase); seat(l, st.psi, st.ppfd); l.evaluate_root_collar_psi(collar);
      bool uptake_moved = false;
      for (int i=0;i<5;++i) if (u0[i] != u1[i]) uptake_moved = true;
      const double dpi = (p[0]-p[1])/(2*h);
      const double dR  = (m[0]-m[1])/(2*h);
      // closed forms: dC/dscale = C/scale, dC/dbeta2 = C*ln q, and profit = A - C
      const double dC = (k==0) ? C*std::log(q) : C/base;
      printf("  %-11s uptake moved at frozen collar: %s\n", nm[k],
             uptake_moved ? "YES" : "no (exactly)");
      printf("              dprofit differenced % .8e   -dC/dtheta % .8e   rel %.3e\n",
             dpi, -dC, rel(dpi, -dC));
      const phylloptim::Leaf::CostTraitRows cr = l.cost_trait_rows();
      const double dpi_c = (k==0) ? cr.dprofit_dbeta2 : cr.dprofit_dcost_scale;
      const double dR_c  = (k==0) ? cr.dmarginal_dbeta2 : cr.dmarginal_dcost_scale;
      printf("              dprofit accessor   % .8e   rel %.3e\n", dpi_c, rel(dpi, dpi_c));
      printf("              dR      differenced % .8e   accessor % .8e   rel %.3e\n",
             dR, dR_c, rel(dR, dR_c));
    }
  }
  return 0;
}
