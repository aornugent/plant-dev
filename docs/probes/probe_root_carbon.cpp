// The root-carbon direction, analytic against differenced.
//
// The acceptance test the design names: the analytic rows must reproduce the
// differenced ones they replace, at wet, dry and shaded states, to the accuracy
// of the difference. Differencing rebuilds the network from perturbed carbon,
// which is exactly what the forward model does when a plant's root mass moves --
// there is no interpolant and no grid between carbon and resistance, so unlike
// the vulnerability curve there is no second function to differentiate by
// mistake.

#include <phylloptim.hpp>

#include "root_network.hpp"

#include <cmath>
#include <cstdio>
#include <vector>

namespace {

const double kTheta = 0.000157, kKs = 1.0, kH = 5.0;

struct State { const char* name; std::vector<double> psi_soil; double ppfd; };

std::vector<double> kDepth{0.3, 0.6, 1.0, 1.4, 1.8};

void seat(phylloptim::Leaf& l, const std::vector<double>& carbon,
          const State& st) {
  l.set_physiology(fixture::root_network(carbon, kDepth), st.ppfd, st.psi_soil,
                   kDepth, kKs * kTheta / kH, 2.0, 40.0, 25.0, 21.0, 101.3);
}

double rel(double a, double b) {
  const double s = std::max(std::abs(a), std::abs(b));
  return s > 0 ? std::abs(a - b) / s : 0.0;
}

}  // namespace

int main() {
  const std::vector<State> states = {
      {"wet",    {1.0, 1.1, 1.2, 1.3, 1.4}, 900.0},
      {"dry",    {2.6, 2.8, 3.0, 3.2, 3.4}, 900.0},
      {"shaded", {1.4, 1.5, 1.6, 1.7, 1.8},  60.0},
  };
  // A carbon profile that thins with depth, so no two layers are commensurate
  // and the lower-triangular structure is visible.
  const std::vector<double> carbon{9.0, 6.0, 4.0, 2.5, 1.5};
  const std::size_t L = carbon.size();

  for (const State& st : states) {
    phylloptim::Leaf l;
    seat(l, carbon, st);
    l.find_root_collar_psi();
    const double collar = l.opt_root_psi_;
    printf("\n=== %s: collar %.10g, %zu layers ===\n", st.name, collar, L);

    std::vector<std::vector<double>> dE, dD;
    l.roots_.duptake_droot_carbon(collar, st.psi_soil, dE, dD);

    // The differenced version: perturb one layer's carbon, rebuild the network,
    // and read the same two quantities back at the SAME frozen collar.
    double worst_E = 0, worst_D = 0;
    std::size_t wi = 0, wa = 0;
    for (std::size_t a = 0; a < L; ++a) {
      const double h = carbon[a] * 1e-5;
      std::vector<double> up = carbon, dn = carbon;
      up[a] += h; dn[a] -= h;
      std::vector<double> Eu(L), Ed(L), Du(L), Dd(L);
      double eup = 0.0;
      seat(l, up, st);
      l.roots_.uptake_at(collar, st.psi_soil, Eu, eup);
      l.roots_.duptake_dpsi_by_layer(collar, st.psi_soil, Du);
      seat(l, dn, st);
      l.roots_.uptake_at(collar, st.psi_soil, Ed, eup);
      l.roots_.duptake_dpsi_by_layer(collar, st.psi_soil, Dd);
      seat(l, carbon, st);
      for (std::size_t i = 0; i < L; ++i) {
        const double fdE =
            ((Eu[i] - Ed[i]) / (2 * h)) * phylloptim::kg_per_mol_h2o;
        const double fdD = (Du[i] - Dd[i]) / (2 * h);
        const double rE = rel(fdE, dE[i][a]);
        const double rD = rel(fdD, dD[i][a]);
        if (rE > worst_E) { worst_E = rE; wi = i; wa = a; }
        worst_D = std::max(worst_D, rD);
        // The structural claim: strictly upper entries must be exactly zero.
        if (i < a && (dE[i][a] != 0.0 || dD[i][a] != 0.0)) {
          printf("  !! upper entry (%zu,%zu) is not zero\n", i, a);
        }
      }
    }
    printf("  worst rel, dE_i/drc_a : %.3e   (at i=%zu a=%zu)\n", worst_E, wi, wa);
    printf("  worst rel, dD_i/drc_a : %.3e\n", worst_D);

    // ---- the step plant actually changed: dR/drc from the factorisation ----
    // Fit (a,b) exactly as plant does -- one soil potential and the deepest
    // layer's cumulative vertical resistance -- then predict dR/drc and hold it
    // to a difference of the marginal profit itself.
    {
      std::vector<double> dEup_dpsi, d2Eup_dcollar_dpsi;
      l.dE_from_soil_dpsi_soil(collar, st.psi_soil, dEup_dpsi);
      l.roots_.d2uptake_dpsi_dpsi_soil(collar, st.psi_soil, d2Eup_dcollar_dpsi);
      const double fit = 1e-3;
      std::size_t wet = 0;
      for (std::size_t j = 0; j < L; ++j) { if (dEup_dpsi[j] != 0.0) { wet = j; break; } }
      const double hp = std::max(std::abs(st.psi_soil[wet]), 1.0) * fit;
      std::vector<double> pu = st.psi_soil, pd = st.psi_soil;
      pu[wet] += hp; pd[wet] -= hp;
      auto marg = [&](const std::vector<double>& ps) {
        seat(l, carbon, st); l.roots_.set_soil_state(ps, kDepth);
        return l.dprofit_droot_collar_psi(collar); };
      const double dR_dpsi0 = (marg(pu) - marg(pd)) / (2 * hp);
      seat(l, carbon, st);

      std::size_t deep = L - 1;
      const double rb = l.roots_.network_.r_R_V_sum[deep];
      const double hr = std::abs(rb) * fit;
      double m_up, m_dn, eup_u, eup_d, sum_u = 0, sum_d = 0;
      std::vector<double> tmp(L), du(L), dd(L);
      l.roots_.network_.r_R_V_sum[deep] = rb + hr;
      m_up = l.dprofit_droot_collar_psi(collar);
      l.roots_.uptake_at(collar, st.psi_soil, tmp, eup_u);
      l.roots_.duptake_dpsi_by_layer(collar, st.psi_soil, du);
      l.roots_.network_.r_R_V_sum[deep] = rb - hr;
      m_dn = l.dprofit_droot_collar_psi(collar);
      l.roots_.uptake_at(collar, st.psi_soil, tmp, eup_d);
      l.roots_.duptake_dpsi_by_layer(collar, st.psi_soil, dd);
      l.roots_.network_.r_R_V_sum[deep] = rb;
      for (std::size_t j = 0; j < L; ++j) { sum_u += du[j]; sum_d += dd[j]; }
      const double dR_dr = (m_up - m_dn) / (2 * hr);
      const double a21 = (eup_u - eup_d) / (2 * hr);
      const double a22 = (sum_u - sum_d) / (2 * hr);
      const double a11 = dEup_dpsi[wet], a12 = d2Eup_dcollar_dpsi[wet];
      const double det = a11 * a22 - a12 * a21;
      const double A = (dR_dpsi0 * a22 - dR_dr * a12) / det;
      const double B = (a11 * dR_dr - a21 * dR_dpsi0) / det;
      printf("  fitted a=% .6e  b=% .6e  det=% .3e\n", A, B, det);

      for (std::size_t a = 0; a < L; ++a) {
        double dEup = 0, d2Eup = 0;
        for (std::size_t i = 0; i < L; ++i) { dEup += dE[i][a]; d2Eup += dD[i][a]; }
        const double pred = A * dEup + B * d2Eup;
        // differenced: rebuild from perturbed carbon and read R back
        const double h = carbon[a] * 1e-5;
        std::vector<double> up = carbon, dn = carbon;
        up[a] += h; dn[a] -= h;
        seat(l, up, st); const double ru = l.dprofit_droot_collar_psi(collar);
        seat(l, dn, st); const double rd = l.dprofit_droot_collar_psi(collar);
        seat(l, carbon, st);
        const double diff = (ru - rd) / (2 * h);
        printf("  layer %zu  dR/drc: predicted % .6e  differenced % .6e  rel %.3e\n",
               a, pred, diff, rel(pred, diff));
        // The profit row the design takes from the SECOND scalar alone.
        seat(l, up, st); l.evaluate_root_collar_psi(collar);
        const double pu2 = l.profit_;
        seat(l, dn, st); l.evaluate_root_collar_psi(collar);
        const double pd2 = l.profit_;
        seat(l, carbon, st); l.evaluate_root_collar_psi(collar);
        const double dpi_diff = (pu2 - pd2) / (2 * h);
        const double dpi_pred = -B * dEup;
        printf("           dPi/drc: -b*dEup % .6e  differenced % .6e  rel %.3e\n",
               dpi_pred, dpi_diff, rel(dpi_pred, dpi_diff));
      }
    }

    // Show one column so the triangularity is visible rather than asserted.
    printf("  dE_i/drc_2 by layer (analytic): ");
    for (std::size_t i = 0; i < L; ++i) printf("% .4e ", dE[i][2]);
    printf("\n");
  }
  return 0;
}
