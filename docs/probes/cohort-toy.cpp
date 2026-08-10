// One tape per cohort per step: is it feasible, and does it scale?
//
// A stand of N cohorts coupled through a shared light field, with soil water as
// ODE state that the cohorts deplete and read back. The shape plant has:
//
//   layer 1  y_j            -> (w_j, H_j)                 per cohort, closed form
//   layer 2  {(w_j, H_j)}   -> (A, A') at nodes -> light  ONE reduction + interpolant
//   layer 3  y_j, light_j   -> rates_j, uptake_j          per cohort, has an implicit node
//   layer 4  sum uptake_j   -> soil rates                 ONE reduction
//
// Two gradient paths over the same Euler trajectory:
//   whole   -- one tape for the entire run, one sweep
//   cohort  -- plain trajectory stored; backward over steps; within a step, one
//              small tape per cohort plus one for the field assembly
// The reverse order has no cycle: layer 3's sweeps produce the light adjoints
// that layer 2 needs, and layer 1/2 never need anything layer 3 has not produced.

// [[Rcpp::plugins(cpp20)]]
#include <Rcpp.h>
#include <XAD/XAD.hpp>
#include <odelia/hermite_interpolator.hpp>
#include <odelia/implicit_node.hpp>
#include <odelia/ode_util.hpp>
#include <algorithm>
#include <cmath>
#include <memory>
#include <numeric>
#include <vector>

using odelia::util::to_passive;
using RevTape = xad::adj<double>::tape_type;
using Rev     = xad::adj<double>::active_type;

namespace {

int    g_leaf_mode = 0;       // 0 = implicit root, 1 = golden-section argmax
bool   g_freeze_uptake_xstar = false;  // sever the argmax -> uptake channel
double g_gss_tol = 1e-9;      // argmax search tolerance (tau)
double g_bound_tight = 1e300; // shrink the argmax bracket to force the boundary regime
bool   g_polish_argmax = false;   // Newton-polish x* after the search
bool   g_no_envelope = false;     // carry x*'s derivative into profit instead
long   g_interior = 0, g_boundary = 0;
bool   g_exact_field = false; // query the reduction directly, with no interpolant
double g_merge_rel = 1e-10;   // spans below this fraction of the domain are merged
double g_min_span  = 1e300;   // smallest span built, for diagnosis

constexpr int NS = 2;   // per-cohort states: height, mass
constexpr int NQ = 5;   // crown quadrature points
constexpr int NL = 3;   // soil layers
constexpr int NT = 5;   // traits: k_I, p, eta, g0, r

struct Shape {
  int N;
  int ny() const { return N * NS + NL; }
  int ih(int j) const { return j * NS; }
  int im(int j) const { return j * NS + 1; }
  int isoil(int a) const { return N * NS + a; }
};

// Gauss-Legendre-ish fixed weights on (0,1); a fixed rule, so the abscissae are
// structure and carry no derivative -- but z = u*H does, which is the channel
// that needs dlight/dz.
const double UQ[NQ] = {0.0469, 0.2308, 0.5000, 0.7692, 0.9531};
const double WQ[NQ] = {0.1185, 0.2393, 0.2844, 0.2393, 0.1185};

// ---- layer 1 + 2: the field, and the light every cohort reads ----------------
// Returns light and dlight/dz at each cohort's quadrature points.
template <class S>
void field_reads(const Shape& sh, const std::vector<S>& y, const S* tr,
                 std::vector<S>& Lq, std::vector<S>& dLq) {
  const S& k_I = tr[0]; const S& p = tr[1]; const S& eta = tr[2];

  // layer 1: amplitude and top per cohort
  std::vector<S> w(sh.N), H(sh.N);
  for (int j = 0; j < sh.N; ++j) {
    H[j] = y[sh.ih(j)];
    w[j] = k_I * pow(H[j], p) * S(1.0 / sh.N);
  }

  // Nodes at the cohort tops (ascending, deduped) plus the ground.
  std::vector<int> ord(sh.N);
  std::iota(ord.begin(), ord.end(), 0);
  std::sort(ord.begin(), ord.end(), [&](int a, int b) {
    const double ha = to_passive(H[a]), hb = to_passive(H[b]);
    return ha != hb ? ha < hb : a < b;
  });
  // Cohorts that have converged in height share one node: a span far below the
  // domain scale makes the Hermite coefficients a difference of near-equal
  // numbers divided by that span, which is ill-conditioned however exact the
  // node data is.
  double htop = 0.0;
  for (int j = 0; j < sh.N; ++j) htop = std::max(htop, to_passive(H[j]));
  const double merge = g_merge_rel * htop;
  std::vector<double> nz; nz.push_back(0.0);
  for (int j : ord) {
    const double h = to_passive(H[j]);
    if (h > nz.back() + merge) nz.push_back(h);
  }
  const std::size_t M = nz.size();
  for (std::size_t k = 1; k < M; ++k)
    g_min_span = std::min(g_min_span, nz[k] - nz[k - 1]);

  // layer 2: A and dA/dz at every node -- one reduction over cohorts, and the
  // two share pow(z/H,eta), so they are formed together.
  std::vector<S> An(M), dAn(M);
  for (std::size_t k = 0; k < M; ++k) {
    S a(0.0), d(0.0);
    for (int j = 0; j < sh.N; ++j) {
      if (nz[k] >= to_passive(H[j])) continue;
      if (nz[k] == 0.0) { a += w[j]; continue; }   // u == 0: no pow, and dA/dz -> 0
      const S u = pow(S(nz[k]) / H[j], eta);
      const S one_u = S(1.0) - u;
      a += w[j] * one_u * one_u;
      d -= w[j] * S(2.0) * eta * one_u * u / S(nz[k]);
    }
    An[k] = a; dAn[k] = d;
  }
  // light = exp(-A); the interpolant carries the pair, so value and slope of the
  // read come from one polynomial.
  std::vector<S> Ln(M), dLn(M);
  for (std::size_t k = 0; k < M; ++k) {
    Ln[k] = exp(-An[k]);
    dLn[k] = -Ln[k] * dAn[k];
  }
  Lq.assign(sh.N * NQ, S(0.0));
  dLq.assign(sh.N * NQ, S(0.0));

  // The control: evaluate the reduction at the query point itself. No nodes, so
  // no node-position channel -- what remains is the adjoint machinery alone.
  if (g_exact_field) {
    for (int j = 0; j < sh.N; ++j) {
      const double Hp = to_passive(H[j]);
      for (int q = 0; q < NQ; ++q) {
        const double z = UQ[q] * Hp;
        S a(0.0), d(0.0);
        for (int i = 0; i < sh.N; ++i) {
          if (z >= to_passive(H[i]) || z == 0.0) { if (z == 0.0) a += w[i]; continue; }
          const S u = pow(S(z) / H[i], eta);
          const S one_u = S(1.0) - u;
          a += w[i] * one_u * one_u;
          d -= w[i] * S(2.0) * eta * one_u * u / S(z);
        }
        const S L = exp(-a);
        Lq[j * NQ + q] = L;
        dLq[j * NQ + q] = -L * d;
      }
    }
    return;
  }

  odelia::interpolator::hermite_interpolator<S> interp;
  interp.init(nz, Ln, dLn);
  for (int j = 0; j < sh.N; ++j) {
    const double Hp = to_passive(H[j]);
    for (int q = 0; q < NQ; ++q) {
      // The abscissa is passive (the interpolant is indexed at a plain height);
      // the H-dependence of z = u*H is carried by the caller through dlight/dz.
      S v, s;
      interp.value_and_slope(UQ[q] * Hp, v, s);
      Lq[j * NQ + q] = v;
      dLq[j * NQ + q] = s;
    }
  }
}

// ---- layer 3: one cohort's rates, with an implicit node in them --------------
// Inputs are exactly the cohort's boundary: own state, the light pair it reads,
// soil potential, traits. Outputs are its rates and its per-layer uptake.
template <class S>
void cohort_rates(const S* yj, const S* Lq_j, const S* dLq_j, const S* psi,
                  const S* tr, S* rates, S* uptake, double draw_scale) {
  const S& eta = tr[2]; const S& g0 = tr[3]; const S& r = tr[4];
  const S& h = yj[0]; const S& m = yj[1];

  // Crown-integrated light capture. The moving abscissa z = u*h contributes
  // dlight/dz * u, which is why the interpolant must carry the slope.
  S capture(0.0);
  for (int q = 0; q < NQ; ++q)
    capture += S(WQ[q]) * (Lq_j[q] + dLq_j[q] * (S(UQ[q]) * h - S(UQ[q] * to_passive(h))));

  // Mean soil potential the roots see.
  S psi_bar(0.0);
  for (int a = 0; a < NL; ++a) psi_bar += psi[a] * S(1.0 / NL);

  // The implicit node: stomatal aperture x solves
  //   x*(1 + eta*x^2) - capture/(1 + psi_bar) = 0,  dF/dx > 0.
  const double av = to_passive(eta);
  const double tv = to_passive(capture) / (1.0 + to_passive(psi_bar));
  double xs = 1.0;
  for (int it = 0; it < 60; ++it) {
    const double f = xs * (1.0 + av * xs * xs) - tv;
    const double df = 1.0 + 3.0 * av * xs * xs;
    const double dx = f / df;
    xs -= dx;
    if (std::abs(dx) < 1e-15) break;
  }
  S x_star;
  S profit;
  if (g_leaf_mode == 0) {
    auto F = [&](S x) -> S { return x * (S(1.0) + eta * x * x) - capture / (S(1.0) + psi_bar); };
    x_star = odelia::implicit_value<S>(xs, F, odelia::denom_sign::positive);
    profit = x_star;
  } else {
    // TF24's shape: maximise a profit over a feasible aperture interval whose
    // upper bound comes from the soil, by a fixed-tolerance golden-section
    // search. The argmax depends on the objective only through the comparison
    // pattern, so the search is never taped.
    //   P(x) = capture*x/(1+x) - eta*x^2/(1+psi_bar)
    auto P_d = [&](double x) -> double {
      const double cv = to_passive(capture), pv = to_passive(psi_bar), ev = to_passive(eta);
      return cv * x / (1.0 + x) - ev * x * x / (1.0 + pv);
    };
    const double lo = 0.02;
    const double hi = std::min(g_bound_tight, 0.35 * (1.0 + to_passive(psi_bar)));
    double xstar_d;
    if (hi <= lo) { xstar_d = lo; }
    else {
      const double gr = (std::sqrt(5.0) + 1.0) / 2.0;
      double a = lo, b = hi;
      double c = b - (b - a) / gr, d2 = a + (b - a) / gr;
      double fc = P_d(c), fd2 = P_d(d2);
      while (std::abs(b - a) > g_gss_tol) {
        if (fc > fd2) { b = d2; d2 = c; fd2 = fc; c = b - (b - a) / gr; fc = P_d(c); }
        else          { a = c;  c = d2; fc = fd2; d2 = a + (b - a) / gr; fd2 = P_d(d2); }
      }
      xstar_d = 0.5 * (a + b);
      if (g_polish_argmax) {
        // dP/dx = 0 by Newton, so x* is exact to rounding rather than to tol/2.
        const double cv = to_passive(capture), pv = to_passive(psi_bar), ev = to_passive(eta);
        for (int it = 0; it < 40; ++it) {
          const double g  = cv / ((1.0 + xstar_d) * (1.0 + xstar_d))
                            - 2.0 * ev * xstar_d / (1.0 + pv);
          const double dg = -2.0 * cv / std::pow(1.0 + xstar_d, 3.0) - 2.0 * ev / (1.0 + pv);
          const double dx = g / dg;
          xstar_d -= dx;
          if (std::abs(dx) < 1e-16) break;
        }
      }
    }
    const bool at_bound = std::abs(xstar_d - hi) <= 2.0 * g_gss_tol;
    if (at_bound) ++g_boundary; else ++g_interior;

    auto P = [&](S x) -> S { return capture * x / (S(1.0) + x) - eta * x * x / (S(1.0) + psi_bar); };

    if (at_bound) {
      // Boundary optimum: x* IS the bound, so dx*/dtheta = d(bound)/dtheta and
      // the envelope argument does not apply -- the bound is differentiated.
      x_star = S(0.35) * (S(1.0) + psi_bar);
      if (to_passive(x_star) > g_bound_tight) x_star = S(g_bound_tight);
      profit = P(x_star);
    } else {
      // Interior optimum. dP/dx = 0 defines x*, so implicit_value gives dx*/dtheta
      // for the consumers that need it (uptake below), while `profit` is the
      // objective AT its own maximiser -- the envelope theorem, obtained here by
      // evaluating P at the passive argmax so its motion contributes nothing.
      auto dP = [&](S x) -> S {
        return capture / ((S(1.0) + x) * (S(1.0) + x)) - S(2.0) * eta * x / (S(1.0) + psi_bar);
      };
      x_star = odelia::implicit_value<S>(xstar_d, dP, odelia::denom_sign::negative);
      profit = g_no_envelope ? P(x_star) : P(S(xstar_d));
    }
  }

  const S assim = g0 * profit * capture;
  rates[0] = assim / (S(1.0) + h) - r * h;            // dh/dt
  rates[1] = assim - S(0.15) * m;                     // dm/dt
  for (int a = 0; a < NL; ++a)
    uptake[a] = (g_freeze_uptake_xstar ? S(to_passive(x_star)) : x_star)
                * psi[a] * S(0.35 * draw_scale / NL);   // per-layer draw
}

// ---- layer 4: soil ----------------------------------------------------------
template <class S>
void soil_rates(const S* theta, const S* depletion, S* out) {
  for (int a = 0; a < NL; ++a)
    out[a] = S(0.6) * (S(0.30) - theta[a]) - depletion[a];
}

template <class S>
void soil_potential(const S* theta, S* psi) {
  for (int a = 0; a < NL; ++a) psi[a] = S(1.0) / (S(0.05) + theta[a]);
}

// ---- the whole right-hand side ---------------------------------------------
template <class S>
void rhs(const Shape& sh, const std::vector<S>& y, const S* tr, std::vector<S>& dydt) {
  std::vector<S> Lq, dLq;
  field_reads(sh, y, tr, Lq, dLq);

  std::vector<S> psi(NL);
  soil_potential(&y[sh.isoil(0)], psi.data());

  dydt.assign(sh.ny(), S(0.0));
  std::vector<S> depletion(NL, S(0.0));
  std::vector<S> rates(NS), uptake(NL);
  for (int j = 0; j < sh.N; ++j) {
    cohort_rates(&y[sh.ih(j)], &Lq[j * NQ], &dLq[j * NQ], psi.data(), tr,
                 rates.data(), uptake.data(), 1.0 / sh.N);
    dydt[sh.ih(j)] = rates[0];
    dydt[sh.im(j)] = rates[1];
    for (int a = 0; a < NL; ++a) depletion[a] += uptake[a];
  }
  std::vector<S> sr(NL);
  soil_rates(&y[sh.isoil(0)], depletion.data(), sr.data());
  for (int a = 0; a < NL; ++a) dydt[sh.isoil(a)] = sr[a];
}

template <class S>
std::vector<S> initial_state(const Shape& sh) {
  std::vector<S> y(sh.ny());
  for (int j = 0; j < sh.N; ++j) {
    y[sh.ih(j)] = S(0.6 + 2.4 * std::pow((j + 1.0) / sh.N, 1.6));
    y[sh.im(j)] = S(0.4 + 0.2 * j / std::max(1, sh.N - 1));
  }
  for (int a = 0; a < NL; ++a) y[sh.isoil(a)] = S(0.22 + 0.01 * a);
  return y;
}

// Mass-weighted census -- a non-trivial reduction (a summed height would give a
// constant adjoint and could not detect a lost cohort term).
template <class S>
S census(const Shape& sh, const std::vector<S>& y) {
  S s(0.0);
  for (int j = 0; j < sh.N; ++j)
    s += S(0.5 + 1.5 * (j + 1.0) / sh.N) * y[sh.im(j)] * y[sh.ih(j)];
  return s;
}


// ---------------------------------------------------------------------------
// The layered vector-Jacobian product at one state: given v, the adjoint of
// dydt, return (df/dy)^T v and accumulate (df/dtheta)^T v. This is section 1's
// steps (a) to (e) of report 01, with no time-step factor folded in, so an
// explicit Runge-Kutta stage can use it as-is.
//
// Order matters and has no cycle: the per-cohort sweeps produce the light
// adjoints the field assembly needs, and the field and allometry adjoints never
// need anything a cohort sweep has not already produced.
template <class Peaks>
void vjp_rhs(const Shape& sh, const std::vector<double>& y, const double* tr,
             const std::vector<double>& v, std::vector<double>& lam_y,
             std::vector<double>& lam_tr, Peaks& peaks) {
  const int ny = sh.ny();
  lam_y.assign(ny, 0.0);

  std::vector<double> Lq, dLq;
  field_reads(sh, y, tr, Lq, dLq);
  std::vector<double> psi(NL);
  soil_potential(&y[sh.isoil(0)], psi.data());

  // (a) soil rates -> theta and depletion
  std::vector<double> lam_depl(NL, 0.0), lam_theta(NL, 0.0);
  for (int a = 0; a < NL; ++a) {
    lam_theta[a] += v[sh.isoil(a)] * (-0.6);
    lam_depl[a]  += v[sh.isoil(a)] * (-1.0);
  }

  // (b) one tape per cohort, recorded once and swept once
  std::vector<double> lam_L(sh.N * NQ, 0.0), lam_dL(sh.N * NQ, 0.0);
  std::vector<double> lam_psi(NL, 0.0);
  for (int j = 0; j < sh.N; ++j) {
    auto tp = std::make_unique<RevTape>(false);
    tp->activate();
    Rev yj[NS], Lj[NQ], dLj[NQ], ps[NL], trj[NT];
    for (int i = 0; i < NS; ++i) { yj[i] = y[sh.ih(j) + i]; tp->registerInput(yj[i]); }
    for (int q = 0; q < NQ; ++q) { Lj[q]  = Lq[j*NQ+q];  tp->registerInput(Lj[q]); }
    for (int q = 0; q < NQ; ++q) { dLj[q] = dLq[j*NQ+q]; tp->registerInput(dLj[q]); }
    for (int a = 0; a < NL; ++a) { ps[a]  = psi[a];      tp->registerInput(ps[a]); }
    for (int i = 0; i < NT; ++i) { trj[i] = tr[i];       tp->registerInput(trj[i]); }
    tp->newRecording();

    Rev rates[NS], uptake[NL];
    cohort_rates(yj, Lj, dLj, ps, trj, rates, uptake, 1.0 / sh.N);
    for (int i = 0; i < NS; ++i) tp->registerOutput(rates[i]);
    for (int a = 0; a < NL; ++a) tp->registerOutput(uptake[a]);
    xad::derivative(rates[0]) = v[sh.ih(j)];
    xad::derivative(rates[1]) = v[sh.im(j)];
    for (int a = 0; a < NL; ++a) xad::derivative(uptake[a]) = lam_depl[a];
    tp->computeAdjoints();

    for (int i = 0; i < NS; ++i) lam_y[sh.ih(j) + i] += xad::derivative(yj[i]);
    for (int q = 0; q < NQ; ++q) lam_L[j*NQ+q]  += xad::derivative(Lj[q]);
    for (int q = 0; q < NQ; ++q) lam_dL[j*NQ+q] += xad::derivative(dLj[q]);
    for (int a = 0; a < NL; ++a) lam_psi[a] += xad::derivative(ps[a]);
    for (int i = 0; i < NT; ++i) lam_tr[i] += xad::derivative(trj[i]);

    peaks.cohort = std::max(peaks.cohort, (double)tp->getMemory());
    tp->deactivate();
  }

  // (c) and (d) the field assembly and the allometry feeding it
  {
    auto tf = std::make_unique<RevTape>(false);
    tf->activate();
    std::vector<Rev> ya(ny);
    Rev trf[NT];
    for (int i = 0; i < ny; ++i) { ya[i] = y[i]; tf->registerInput(ya[i]); }
    for (int i = 0; i < NT; ++i) { trf[i] = tr[i]; tf->registerInput(trf[i]); }
    tf->newRecording();
    std::vector<Rev> Lqa, dLqa;
    field_reads(sh, ya, trf, Lqa, dLqa);
    for (auto& q : Lqa)  tf->registerOutput(q);
    for (auto& q : dLqa) tf->registerOutput(q);
    for (int i = 0; i < sh.N * NQ; ++i) {
      xad::derivative(Lqa[i])  = lam_L[i];
      xad::derivative(dLqa[i]) = lam_dL[i];
    }
    tf->computeAdjoints();
    for (int i = 0; i < ny; ++i) lam_y[i] += xad::derivative(ya[i]);
    for (int i = 0; i < NT; ++i) lam_tr[i] += xad::derivative(trf[i]);
    peaks.field = std::max(peaks.field, (double)tf->getMemory());
    tf->deactivate();
  }

  // psi -> theta, closed form
  for (int a = 0; a < NL; ++a)
    lam_theta[a] += lam_psi[a] * (-1.0 / std::pow(0.05 + y[sh.isoil(a)], 2.0));
  for (int a = 0; a < NL; ++a) lam_y[sh.isoil(a)] += lam_theta[a];
}

// Classical four-stage Runge-Kutta, written with its tableau explicit so the
// adjoint below reads against it.
const double RK_A21 = 0.5, RK_A32 = 0.5, RK_A43 = 1.0;
const double RK_B[4] = {1.0/6.0, 2.0/6.0, 2.0/6.0, 1.0/6.0};

template <class S>
void rk4_step(const Shape& sh, std::vector<S>& y, const S* tr, double h) {
  const int ny = sh.ny();
  std::vector<S> k1, k2, k3, k4, Y(ny);
  rhs(sh, y, tr, k1);
  for (int i = 0; i < ny; ++i) Y[i] = y[i] + S(h * RK_A21) * k1[i];
  rhs(sh, Y, tr, k2);
  for (int i = 0; i < ny; ++i) Y[i] = y[i] + S(h * RK_A32) * k2[i];
  rhs(sh, Y, tr, k3);
  for (int i = 0; i < ny; ++i) Y[i] = y[i] + S(h * RK_A43) * k3[i];
  rhs(sh, Y, tr, k4);
  for (int i = 0; i < ny; ++i)
    y[i] += S(h) * (S(RK_B[0]) * k1[i] + S(RK_B[1]) * k2[i]
                  + S(RK_B[2]) * k3[i] + S(RK_B[3]) * k4[i]);
}

const double TR0[NT] = {0.55, 0.72, 4.0, 1.10, 0.06};

}  // namespace

// ---- path 1: one tape for the whole run ------------------------------------
// [[Rcpp::export]]
Rcpp::List grad_whole(int N, int nstep, double dt) {
  Shape sh{N};
  auto tape = std::make_unique<RevTape>(false);
  tape->activate();
  Rev tr[NT];
  for (int i = 0; i < NT; ++i) { tr[i] = TR0[i]; tape->registerInput(tr[i]); }
  tape->newRecording();

  auto y = initial_state<Rev>(sh);
  std::vector<Rev> dydt;
  for (int k = 0; k < nstep; ++k) {
    rhs(sh, y, tr, dydt);
    for (int i = 0; i < sh.ny(); ++i) y[i] += Rev(dt) * dydt[i];
  }
  double theta_min = 1e300;
  for (int a = 0; a < NL; ++a) theta_min = std::min(theta_min, xad::value(y[sh.isoil(a)]));
  Rev out = census(sh, y);
  tape->registerOutput(out);
  const double value = xad::value(out);
  xad::derivative(out) = 1.0;
  tape->computeAdjoints();
  std::vector<double> g(NT);
  for (int i = 0; i < NT; ++i) g[i] = xad::derivative(tr[i]);
  const double mem = (double)tape->getMemory();
  tape->deactivate();
  return Rcpp::List::create(Rcpp::_["value"] = value, Rcpp::_["grad"] = g,
                            Rcpp::_["peak_tape_bytes"] = mem,
                            Rcpp::_["theta_min"] = theta_min);
}

// ---- path 2: one tape per cohort per step ----------------------------------
// [[Rcpp::export]]
Rcpp::List grad_cohort(int N, int nstep, double dt) {
  Shape sh{N};
  const int ny = sh.ny();

  // Forward in plain double, storing the trajectory.
  std::vector<std::vector<double>> traj;
  traj.reserve(nstep + 1);
  {
    auto y = initial_state<double>(sh);
    traj.push_back(y);
    std::vector<double> dydt;
    for (int k = 0; k < nstep; ++k) {
      rhs(sh, y, TR0, dydt);
      for (int i = 0; i < ny; ++i) y[i] += dt * dydt[i];
      traj.push_back(y);
    }
  }
  const double value = census(sh, traj.back());

  // Seed the functional's adjoint on the final state.
  std::vector<double> lam(ny, 0.0);
  for (int j = 0; j < sh.N; ++j) {
    const double wj = 0.5 + 1.5 * (j + 1.0) / sh.N;
    lam[sh.im(j)] += wj * traj.back()[sh.ih(j)];
    lam[sh.ih(j)] += wj * traj.back()[sh.im(j)];
  }
  std::vector<double> lam_tr(NT, 0.0);
  double peak_cohort = 0.0, peak_field = 0.0;

  // Backward over steps. Euler: lam_k = lam_{k+1} + dt * (df/dy)^T lam_{k+1},
  // and lam_theta += dt * (df/dtheta)^T lam_{k+1}.
  for (int k = nstep - 1; k >= 0; --k) {
    const std::vector<double>& y = traj[k];

    // Plain re-run of layers 1-2 to get the light pairs the cohorts read.
    std::vector<double> Lq, dLq;
    field_reads(sh, y, TR0, Lq, dLq);
    std::vector<double> psi(NL);
    soil_potential(&y[sh.isoil(0)], psi.data());

    // --- layer 4 adjoint: soil rates -> theta and depletion ------------------
    std::vector<double> lam_depl(NL, 0.0), lam_theta(NL, 0.0);
    for (int a = 0; a < NL; ++a) {
      const double s = lam[sh.isoil(a)] * dt;
      lam_theta[a] += s * (-0.6);
      lam_depl[a]  += s * (-1.0);
    }

    // --- layer 3: one tape per cohort, recorded once and swept once ----------
    std::vector<double> lam_L(sh.N * NQ, 0.0), lam_dL(sh.N * NQ, 0.0);
    std::vector<double> lam_psi(NL, 0.0);
    std::vector<double> lam_y_direct(ny, 0.0);
    for (int j = 0; j < sh.N; ++j) {
      auto tp = std::make_unique<RevTape>(false);
      tp->activate();
      Rev yj[NS], Lj[NQ], dLj[NQ], ps[NL], tr[NT];
      for (int i = 0; i < NS; ++i) { yj[i] = y[sh.ih(j) + i]; tp->registerInput(yj[i]); }
      for (int q = 0; q < NQ; ++q) { Lj[q] = Lq[j*NQ+q];  tp->registerInput(Lj[q]); }
      for (int q = 0; q < NQ; ++q) { dLj[q] = dLq[j*NQ+q]; tp->registerInput(dLj[q]); }
      for (int a = 0; a < NL; ++a) { ps[a] = psi[a];       tp->registerInput(ps[a]); }
      for (int i = 0; i < NT; ++i) { tr[i] = TR0[i];       tp->registerInput(tr[i]); }
      tp->newRecording();

      Rev rates[NS], uptake[NL];
      cohort_rates(yj, Lj, dLj, ps, tr, rates, uptake, 1.0 / sh.N);
      for (int i = 0; i < NS; ++i) tp->registerOutput(rates[i]);
      for (int a = 0; a < NL; ++a) tp->registerOutput(uptake[a]);
      xad::derivative(rates[0]) = lam[sh.ih(j)] * dt;
      xad::derivative(rates[1]) = lam[sh.im(j)] * dt;
      for (int a = 0; a < NL; ++a) xad::derivative(uptake[a]) = lam_depl[a];
      tp->computeAdjoints();

      for (int i = 0; i < NS; ++i) lam_y_direct[sh.ih(j) + i] += xad::derivative(yj[i]);
      for (int q = 0; q < NQ; ++q) lam_L[j*NQ+q]  += xad::derivative(Lj[q]);
      for (int q = 0; q < NQ; ++q) lam_dL[j*NQ+q] += xad::derivative(dLj[q]);
      for (int a = 0; a < NL; ++a) lam_psi[a] += xad::derivative(ps[a]);
      for (int i = 0; i < NT; ++i) lam_tr[i] += xad::derivative(tr[i]);

      peak_cohort = std::max(peak_cohort, (double)tp->getMemory());
      tp->deactivate();
    }

    // --- layers 1-2 adjoint: one tape for the field assembly ----------------
    std::vector<double> lam_y_field(ny, 0.0);
    {
      auto tf = std::make_unique<RevTape>(false);
      tf->activate();
      std::vector<Rev> ya(ny);
      Rev tr[NT];
      for (int i = 0; i < ny; ++i) { ya[i] = y[i]; tf->registerInput(ya[i]); }
      for (int i = 0; i < NT; ++i) { tr[i] = TR0[i]; tf->registerInput(tr[i]); }
      tf->newRecording();

      std::vector<Rev> Lqa, dLqa;
      field_reads(sh, ya, tr, Lqa, dLqa);
      for (auto& v : Lqa)  tf->registerOutput(v);
      for (auto& v : dLqa) tf->registerOutput(v);
      for (int i = 0; i < sh.N * NQ; ++i) {
        xad::derivative(Lqa[i])  = lam_L[i];
        xad::derivative(dLqa[i]) = lam_dL[i];
      }
      tf->computeAdjoints();
      for (int i = 0; i < ny; ++i) lam_y_field[i] += xad::derivative(ya[i]);
      for (int i = 0; i < NT; ++i) lam_tr[i] += xad::derivative(tr[i]);
      peak_field = std::max(peak_field, (double)tf->getMemory());
      tf->deactivate();
    }

    // --- soil potential adjoint: psi -> theta (closed form) -----------------
    for (int a = 0; a < NL; ++a) {
      const double d = -1.0 / std::pow(0.05 + y[sh.isoil(a)], 2.0);
      lam_theta[a] += lam_psi[a] * d;
    }

    // --- assemble lam_k -----------------------------------------------------
    for (int i = 0; i < ny; ++i) lam[i] += lam_y_direct[i] + lam_y_field[i];
    for (int a = 0; a < NL; ++a) lam[sh.isoil(a)] += lam_theta[a];
  }

  return Rcpp::List::create(
    Rcpp::_["value"] = value, Rcpp::_["grad"] = lam_tr,
    Rcpp::_["peak_cohort_tape_bytes"] = peak_cohort,
    Rcpp::_["peak_field_tape_bytes"] = peak_field,
    Rcpp::_["trajectory_bytes"] = (double)(traj.size() * ny * 8));
}

// ---- finite differences on the trait vector --------------------------------
// [[Rcpp::export]]
Rcpp::NumericVector grad_fd(int N, int nstep, double dt, double rel = 1e-6) {
  Shape sh{N};
  auto run = [&](const double* tr) {
    auto y = initial_state<double>(sh);
    std::vector<double> dydt;
    for (int k = 0; k < nstep; ++k) {
      rhs(sh, y, tr, dydt);
      for (int i = 0; i < sh.ny(); ++i) y[i] += dt * dydt[i];
    }
    return census(sh, y);
  };
  Rcpp::NumericVector g(NT);
  for (int i = 0; i < NT; ++i) {
    double a[NT], b[NT];
    std::copy(TR0, TR0 + NT, a); std::copy(TR0, TR0 + NT, b);
    const double d = rel * std::abs(TR0[i]);
    a[i] -= d; b[i] += d;
    g[i] = (run(b) - run(a)) / (2 * d);
  }
  return g;
}

// [[Rcpp::export]] 
void set_merge_rel(double v) { g_merge_rel = v; g_min_span = 1e300; }
// [[Rcpp::export]]
double get_min_span() { return g_min_span; }

// [[Rcpp::export]]
void set_exact_field(bool v) { g_exact_field = v; }

// [[Rcpp::export]]
void set_leaf_mode(int m, double bound_tight = 1e300, double gss_tol = 1e-9,
                   bool freeze_uptake = false, bool polish = false,
                   bool no_envelope = false) {
  g_polish_argmax = polish; g_no_envelope = no_envelope;
  g_freeze_uptake_xstar = freeze_uptake; g_leaf_mode = m; g_bound_tight = bound_tight; g_gss_tol = gss_tol; g_interior = 0; g_boundary = 0;
}
// [[Rcpp::export]]
Rcpp::NumericVector leaf_branch_counts() {
  return Rcpp::NumericVector::create(Rcpp::_["interior"] = (double)g_interior,
                                     Rcpp::_["boundary"] = (double)g_boundary);
}

// ---------------------------------------------------------------------------
// Runge-Kutta: does the cohort decomposition survive a multi-stage step?
// ---------------------------------------------------------------------------

// [[Rcpp::export]]
Rcpp::List rk_whole(int N, int nstep, double dt) {
  Shape sh{N};
  auto tape = std::make_unique<RevTape>(false);
  tape->activate();
  Rev tr[NT];
  for (int i = 0; i < NT; ++i) { tr[i] = TR0[i]; tape->registerInput(tr[i]); }
  tape->newRecording();
  auto y = initial_state<Rev>(sh);
  for (int k = 0; k < nstep; ++k) rk4_step(sh, y, tr, dt);
  Rev out = census(sh, y);
  tape->registerOutput(out);
  const double value = xad::value(out);
  xad::derivative(out) = 1.0;
  tape->computeAdjoints();
  std::vector<double> g(NT);
  for (int i = 0; i < NT; ++i) g[i] = xad::derivative(tr[i]);
  const double mem = (double)tape->getMemory();
  tape->deactivate();
  return Rcpp::List::create(Rcpp::_["value"] = value, Rcpp::_["grad"] = g,
                            Rcpp::_["peak_tape_bytes"] = mem);
}

// [[Rcpp::export]]
Rcpp::NumericVector rk_fd(int N, int nstep, double dt, double rel = 1e-6) {
  Shape sh{N};
  auto run = [&](const double* tr) {
    auto y = initial_state<double>(sh);
    for (int k = 0; k < nstep; ++k) rk4_step(sh, y, tr, dt);
    return census(sh, y);
  };
  Rcpp::NumericVector g(NT);
  for (int i = 0; i < NT; ++i) {
    double a[NT], b[NT];
    std::copy(TR0, TR0 + NT, a); std::copy(TR0, TR0 + NT, b);
    const double d = rel * std::abs(TR0[i]);
    a[i] -= d; b[i] += d;
    g[i] = (run(b) - run(a)) / (2 * d);
  }
  return g;
}

// The stage-aware cohort-granular sweep. Only y_n is stored per step; the stage
// states are rebuilt by re-running the step in double, which is what makes the
// storage independent of the stage count.
//
//   lambda_k_i starts at h*b_i*lambda_{n+1}
//   stages are visited in REVERSE order, so lambda_k_i is complete when used:
//   stage i contributes h*a_ij*lambda_Y_i to every earlier stage's lambda_k_j
//
// [[Rcpp::export]]
Rcpp::List rk_cohort(int N, int nstep, double dt) {
  Shape sh{N};
  const int ny = sh.ny();

  std::vector<std::vector<double>> traj;
  traj.reserve(nstep + 1);
  {
    auto y = initial_state<double>(sh);
    traj.push_back(y);
    for (int k = 0; k < nstep; ++k) { rk4_step(sh, y, TR0, dt); traj.push_back(y); }
  }
  const double value = census(sh, traj.back());

  std::vector<double> lam(ny, 0.0);
  for (int j = 0; j < sh.N; ++j) {
    const double wj = 0.5 + 1.5 * (j + 1.0) / sh.N;
    lam[sh.im(j)] += wj * traj.back()[sh.ih(j)];
    lam[sh.ih(j)] += wj * traj.back()[sh.im(j)];
  }
  std::vector<double> lam_tr(NT, 0.0);
  struct { double cohort = 0.0, field = 0.0; } peaks;

  std::vector<double> Y[4], kk[4];
  std::vector<double> lam_k[4], lam_Y(ny);

  for (int step = nstep - 1; step >= 0; --step) {
    const std::vector<double>& yn = traj[step];

    // Rebuild this step's stage states in plain double.
    Y[0] = yn;                        rhs(sh, Y[0], TR0, kk[0]);
    Y[1] = yn; for (int i = 0; i < ny; ++i) Y[1][i] += dt * RK_A21 * kk[0][i];
    rhs(sh, Y[1], TR0, kk[1]);
    Y[2] = yn; for (int i = 0; i < ny; ++i) Y[2][i] += dt * RK_A32 * kk[1][i];
    rhs(sh, Y[2], TR0, kk[2]);
    Y[3] = yn; for (int i = 0; i < ny; ++i) Y[3][i] += dt * RK_A43 * kk[2][i];
    rhs(sh, Y[3], TR0, kk[3]);

    for (int i = 0; i < 4; ++i) {
      lam_k[i].assign(ny, 0.0);
      for (int m = 0; m < ny; ++m) lam_k[i][m] = dt * RK_B[i] * lam[m];
    }

    std::vector<double> lam_next = lam;   // y_n enters y_{n+1} directly
    for (int i = 3; i >= 0; --i) {
      vjp_rhs(sh, Y[i], TR0, lam_k[i], lam_Y, lam_tr, peaks);
      for (int m = 0; m < ny; ++m) lam_next[m] += lam_Y[m];
      // Y_i = y_n + h*a_i,i-1*k_{i-1}, so only the immediately preceding stage
      // receives a contribution under this tableau.
      if (i == 3) for (int m = 0; m < ny; ++m) lam_k[2][m] += dt * RK_A43 * lam_Y[m];
      if (i == 2) for (int m = 0; m < ny; ++m) lam_k[1][m] += dt * RK_A32 * lam_Y[m];
      if (i == 1) for (int m = 0; m < ny; ++m) lam_k[0][m] += dt * RK_A21 * lam_Y[m];
    }
    lam = lam_next;
  }

  return Rcpp::List::create(
    Rcpp::_["value"] = value, Rcpp::_["grad"] = lam_tr,
    Rcpp::_["peak_cohort_tape_bytes"] = peaks.cohort,
    Rcpp::_["peak_field_tape_bytes"] = peaks.field,
    Rcpp::_["trajectory_bytes"] = (double)(traj.size() * ny * 8));
}
