// The photosynthesis family's marginal row, and the waist it factors through.
//
// Three traits are still driven by moving a member and re-solving: `a`,
// `curv_fact_elec_trans` and `curv_fact_colim`. The profit row is already
// derived; what gates removing the drives is the MARGINAL row, which needs A''
// and the mixed second partial d2A/dtheta dci.
//
// The structural claim this probe is built to test: over the whole leaf, `a` and
// `curv_fact_elec_trans` appear in exactly ONE expression -- electron_transport_
// -- and `curv_fact_colim` in exactly one -- the colimitation. So the family is a
// rank-one waist plus a singleton, and every derivative it needs comes from
// second-order forward mode on two pure kernels rather than from six leaf solves.
//
// Nothing here replicates model algebra: the threaded electron-limited rate is
// the model's own kernel scaled by J_ad/J, and the probe asserts it reproduces
// the model's value before reading any derivative off it.
#include <phylloptim.hpp>
#include "root_network.hpp"
#include <cmath>
#include <cstdio>
#include <chrono>
#include <vector>

namespace {

const double kTheta = 0.000157, kKs = 1.0, kH = 5.0;
std::vector<double> kDepth{0.3, 0.6, 1.0, 1.4, 1.8};
std::vector<double> kCarbon{9.0, 6.0, 4.0, 2.5, 1.5};
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

using AD1 = xad::fwd<double>::active_type;
using AD2 = xad::fwd_fwd<double>::active_type;

// Everything the two rows need out of the assimilation kernel, at one ci.
struct AssimJet {
  double A, A_ci, A_cici;      // value and both ci derivatives
  double A_J, A_J_ci;          // through the electron-transport waist
  double A_cv, A_cv_ci;        // through the colimitation curvature
};

// One second-order pass per direction, on the model's own kernels.
AssimJet assim_jet(phylloptim::Leaf& l, double ci) {
  const double J = l.electron_transport_;
  const double cv = l.curv_fact_colim;
  AssimJet out{};

  // A, A' and A'' : seed ci twice.
  {
    AD2 x = ci;
    x.value().derivative() = 1.0;
    x.derivative().value() = 1.0;
    AD2 A = l.assim_colimited_kernel(x);
    out.A = A.value().value();
    out.A_ci = A.value().derivative();
    out.A_cici = A.derivative().derivative();
  }
  // A_J and d2A/dJ dci : ci on the inner seed, J on the outer.
  // ae is exactly proportional to J, so carrying J on the scalar is the model's
  // own electron-limited kernel times J_ad/J -- no second expression.
  {
    AD2 x = ci;             x.value().derivative() = 1.0;
    AD2 Jad = J;            Jad.derivative().value() = 1.0;
    AD2 ar = l.assim_rubisco_limited_kernel(x);
    AD2 ae = l.assim_electron_limited_kernel(x) * (Jad / J);
    AD2 A = l.colimit_kernel(ar, ae);
    out.A_J = A.derivative().value();
    out.A_J_ci = A.derivative().derivative();
    // the value must be the model's, or the scaling has drifted
    if (rel(A.value().value(), out.A) > 1e-14) {
      printf("  !! threaded ae does not reproduce the model's A: %.17g vs %.17g\n",
             A.value().value(), out.A);
    }
  }
  // A_cv and d2A/dcv dci : the curvature is a bare member the kernel reads, so
  // this is where a trait scalar has to be threaded. Until it is, the same two
  // numbers come from a central difference of the KERNEL -- no solve, no
  // interpolant, no root-find, so the step is the only error.
  {
    const double h = cv * 1e-5;
    double A_up = 0, A_dn = 0, Aci_up = 0, Aci_dn = 0;
    for (int side = 0; side < 2; ++side) {
      l.curv_fact_colim = cv + (side == 0 ? h : -h);
      AD1 x = ci;  xad::derivative(x) = 1.0;
      AD1 A = l.assim_colimited_kernel(x);
      (side == 0 ? A_up : A_dn) = xad::value(A);
      (side == 0 ? Aci_up : Aci_dn) = xad::derivative(A);
    }
    l.curv_fact_colim = cv;
    out.A_cv = (A_up - A_dn) / (2 * h);
    out.A_cv_ci = (Aci_up - Aci_dn) / (2 * h);
  }
  return out;
}

// dJ/dtheta for the two traits that reach A only through J. One line of the
// model, differentiated by moving the trait and re-calling its own kernel.
void dJ_dtraits(phylloptim::Leaf& l, double& dJ_da, double& dJ_dce) {
  const double a0 = l.a, ce0 = l.curv_fact_elec_trans;
  auto J_at = [&](double a, double ce) {
    l.a = a; l.curv_fact_elec_trans = ce;
    const double v = l.electron_transport();
    l.a = a0; l.curv_fact_elec_trans = ce0;
    return v;
  };
  const double ha = a0 * 1e-6, hc = ce0 * 1e-6;
  dJ_da = (J_at(a0 + ha, ce0) - J_at(a0 - ha, ce0)) / (2 * ha);
  dJ_dce = (J_at(a0, ce0 + hc) - J_at(a0, ce0 - hc)) / (2 * hc);
}

}  // namespace

int main() {
  struct S { const char* n; std::vector<double> psi; double ppfd; };
  const std::vector<S> states = {{"wet", {1.0, 1.1, 1.2, 1.3, 1.4}, 900.0},
                                 {"dry", {2.6, 2.8, 3.0, 3.2, 3.4}, 900.0},
                                 {"shaded", {1.4, 1.5, 1.6, 1.7, 1.8}, 60.0}};
  const int idx[3] = {9, 10, 11};
  const char* nm[3] = {"a", "curv_elec", "curv_colim"};

  for (const S& st : states) {
    phylloptim::Leaf l;
    apply(l, kBase);
    seat(l, st.psi, st.ppfd);
    l.find_root_collar_psi();
    const double collar = l.opt_root_psi_;
    l.evaluate_root_collar_psi(collar);

    const double ci = l.ci_;
    const double psi_stem = l.opt_psi_stem_;
    const double J = l.electron_transport_;
    const double gc = l.stom_cond_CO2_;
    const double inv_atm = 1.0 / (l.atm_kpa_ * phylloptim::kPa_to_Pa);

    const AssimJet jet = assim_jet(l, ci);
    double dJ_da = 0, dJ_dce = 0;
    dJ_dtraits(l, dJ_da, dJ_dce);

    const double g_ci = jet.A_ci * phylloptim::umol_to_mol + gc * inv_atm;

    // D and C' -- the theta-independent half of R, formed exactly as
    // dprofit_at_collar_psi forms it.
    const double gc_const = l.atm_kpa_ * phylloptim::kg_to_mol_h2o / l.atm_vpd_ /
                            phylloptim::H2O_CO2_stom_diff_ratio;
    const double dgc_dpsistem = gc_const * l.leaf_specific_conductance_max_ *
                                l.stem_curve_integral_deriv(psi_stem);
    const double dgc_dpsi = gc_const * l.leaf_specific_conductance_max_ *
                            (-l.stem_curve_integral_deriv(collar));
    const double dEup_dp = l.dE_from_soil_dpsi_collar(collar, l.roots_.psi_soil_);
    l.E_from_Soil_to_Root_Collar(collar, l.roots_.psi_soil_);
    const double E_x = l.E_up_ / l.leaf_specific_conductance_max_ +
                       l.stem_curve_integral(collar, "probe");
    const double dpsistem_dp =
        l.stem_curve_integral_inverse_deriv(E_x) *
        (dEup_dp / l.leaf_specific_conductance_max_ +
         l.stem_curve_integral_deriv(collar));
    const double D = dgc_dpsistem * dpsistem_dp + dgc_dpsi;
    const double K = (l.ca_ - ci) * inv_atm / g_ci;

    printf("\n=== %s: collar %.10g  ci %.10g  J %.8g  A' %.8g  A'' %.8g\n",
           st.n, collar, ci, J, jet.A_ci, jet.A_cici);
    printf("    A_J %.8e  A_J_ci %.8e  A_cv %.8e  A_cv_ci %.8e\n",
           jet.A_J, jet.A_J_ci, jet.A_cv, jet.A_cv_ci);
    printf("    dJ/da %.8e  dJ/dcurv_elec %.8e\n", dJ_da, dJ_dce);

    for (int k = 0; k < 3; ++k) {
      // The two ingredients, routed through the waist.
      double dA_dt = 0, dAci_dt = 0;
      if (k == 0)      { dA_dt = jet.A_J * dJ_da;  dAci_dt = jet.A_J_ci * dJ_da; }
      else if (k == 1) { dA_dt = jet.A_J * dJ_dce; dAci_dt = jet.A_J_ci * dJ_dce; }
      else             { dA_dt = jet.A_cv;         dAci_dt = jet.A_cv_ci; }

      // The rows.
      const double dci_dt = -dA_dt * phylloptim::umol_to_mol / g_ci;
      const double dAprime_dt = dAci_dt + jet.A_cici * dci_dt;
      const double dg_ci_dt = phylloptim::umol_to_mol * dAprime_dt;
      const double dK_dt = -(dci_dt * inv_atm * g_ci +
                             (l.ca_ - ci) * inv_atm * dg_ci_dt) / (g_ci * g_ci);
      const double dR_pred = dAprime_dt * D * K + jet.A_ci * D * dK_dt;
      const double dPi_pred = dA_dt * gc * inv_atm / g_ci;

      // Against differencing the whole solve at a frozen collar, which is what
      // plant does today.
      const double base = kBase.v[idx[k]];
      const double h = base * 1e-4;
      double p[2], m[2];
      std::vector<double> u_up(kDepth.size()), u_dn(kDepth.size());
      for (int side = 0; side < 2; ++side) {
        T t = kBase;
        t.v[idx[k]] = base + (side == 0 ? h : -h);
        apply(l, t);
        seat(l, st.psi, st.ppfd);
        l.evaluate_root_collar_psi(collar);
        p[side] = l.profit_;
        m[side] = l.dprofit_droot_collar_psi(collar);
        for (std::size_t i = 0; i < kDepth.size(); ++i) {
          (side == 0 ? u_up : u_dn)[i] = l.soil_consumption_[i];
        }
      }
      apply(l, kBase); seat(l, st.psi, st.ppfd);
      l.evaluate_root_collar_psi(collar);
      const double dPi_diff = (p[0] - p[1]) / (2 * h);
      const double dR_diff = (m[0] - m[1]) / (2 * h);
      double worst_u = 0.0;
      for (std::size_t i = 0; i < kDepth.size(); ++i) {
        worst_u = std::max(worst_u, std::abs(u_up[i] - u_dn[i]));
      }

      printf("  %-11s dPi  pred % .8e  diff % .8e  rel %.3e\n",
             nm[k], dPi_pred, dPi_diff, rel(dPi_pred, dPi_diff));
      printf("  %-11s dR   pred % .8e  diff % .8e  rel %.3e\n",
             "", dR_pred, dR_diff, rel(dR_pred, dR_diff));
      printf("  %-11s frozen-collar uptake moved by at most %.3e (mol)\n",
             "", worst_u);
    }
  }

  // ---- what the two routes cost -------------------------------------------
  {
    phylloptim::Leaf l;
    apply(l, kBase);
    seat(l, states[0].psi, states[0].ppfd);
    l.find_root_collar_psi();
    const double collar = l.opt_root_psi_;
    l.evaluate_root_collar_psi(collar);
    const double ci = l.ci_;

    printf("\n=== cost, per cohort per stage ===\n");
    const double t_jet = time_us([&] { volatile double v = assim_jet(l, ci).A_J; (void)v; }, 20000);
    double a1 = 0, a2 = 0;
    const double t_dJ = time_us([&] { dJ_dtraits(l, a1, a2); }, 20000);
    int side = 0;
    const double t_drive = time_us([&] {
      T t = kBase;
      t.v[9] = kBase.v[9] * (side ? 1.0001 : 0.9999);
      side ^= 1;
      apply(l, t);
      seat(l, states[0].psi, states[0].ppfd);
      l.evaluate_root_collar_psi(collar);
      volatile double v = l.dprofit_droot_collar_psi(collar);
      (void)v;
    }, 2000);
    apply(l, kBase); seat(l, states[0].psi, states[0].ppfd);
    printf("  one assim_jet (all three traits)   %8.3f us\n", t_jet);
    printf("  dJ/dtheta for the two              %8.3f us\n", t_dJ);
    printf("  ONE drive of the six it replaces   %8.3f us\n", t_drive);
    printf("  today: 6 drives = %.1f us    designed: %.3f us\n",
           6 * t_drive, t_jet + t_dJ);
  }
  return 0;
}
