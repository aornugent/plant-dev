// Step 1 (does odelia's RODAS suffice for R-D?): the TF24-shaped soil block, in either the theta
// chart or the log-depletion chart (compile-time LOG), integrated by the REAL odelia adaptive solver
// with method = rkck (explicit) or rodas (implicit RODAS4(3)). Smooth vulnerability shutoff (R-C) so
// uptake -> 0 at the bound (Case A). Compares step counts + accuracy across {chart} x {method} to see
// whether RODAS on the zeta soil block delivers the reformulation's stiff-regime step win with the
// production stepper (replacing the hand-rolled ROS2 of T2/T5).
// [[Rcpp::plugins(cpp20)]]
#include <Rcpp.h>
#include <vector>
#include <cmath>
#include <XAD/XAD.hpp>
#include <odelia/ode_solver.hpp>
using namespace odelia;

template <class S> static inline S powS(S a, double b){ using std::pow; using xad::pow; return pow(a, b); }

static constexpr double SAT = 0.428, KSAT = 163.0411, DZMM = 300.0, RESID = 1e-2,
                        Q = 6.57, APSI = 1.78e3, PEXP = 2 * 6.57 + 3;

// LOG = true: state is zeta = ln(theta - theta_res); false: state is theta.
// psi50/sh set the vulnerability-shutoff steepness -> the coupling stiffness (tuned to the real
// soil-block Jacobian eigenvalue measured on the patch, ~ -86 at theta~0.13).
template <typename T = double, bool LOG = true>
class Soil {
public:
  using value_type = T;
  static constexpr int L = 5;

  Soil(T urate_, double rin_, double theta0_ = 0.30, double psi50_ = 3.0, double sh_ = 4.0)
    : urate(urate_), rin(rin_), theta0(theta0_), psi50(psi50_), sh(sh_) {
    for (int i = 0; i < L; ++i) { s_init[i] = to_state(T(theta0)); s[i] = s_init[i]; }
    t0 = 0.0; time = 0.0; compute_rates();
  }

  size_t ode_size() const { return L; }
  double ode_time() const { return time; }
  double ode_t0() const { return t0; }
  template <typename It> It set_ode_state(It it, double time_){ time = time_; for (int i=0;i<L;++i) s[i]=*it++; compute_rates(); return it; }
  template <typename It> It set_initial_state(It it, double t0_=0.0){ t0=t0_; for (int i=0;i<L;++i) s_init[i]=*it++; return it; }
  template <typename It> It ode_state(It it) const { for (int i=0;i<L;++i) *it++=s[i]; return it; }
  template <typename It> It ode_initial_state(It it) const { for (int i=0;i<L;++i) *it++=s_init[i]; return it; }
  template <typename It> It ode_rates(It it) const { for (int i=0;i<L;++i) *it++=ds[i]; return it; }
  void reset(){ for (int i=0;i<L;++i) s[i]=s_init[i]; time=t0; compute_rates(); }
  std::vector<double> pars() const { return { xad::value(urate) }; }

  template <typename U> Soil<U, LOG> rebind() const {
    Soil<U, LOG> o(U(xad::value(urate)), rin, theta0, psi50, sh);
    std::vector<U> init(L); for (int i=0;i<L;++i) init[i]=U(xad::value(s_init[i])); o.set_initial_state(init.begin(), t0);
    std::vector<U> st(L);   for (int i=0;i<L;++i) st[i]=U(xad::value(s[i]));       o.set_ode_state(st.begin(), time);
    return o;
  }

  void compute_rates(){
    T th[L], K[L];
    for (int i=0;i<L;++i){ th[i]=theta_of(s[i]); K[i]=drain(th[i]); }
    for (int i=0;i<L;++i){
      T win = (i==0) ? T(rin/DZMM) : K[i-1];              // inflow: constant into layer 0, cascade below
      T up  = urate * beta(th[i]) * T(rootf[i]);          // smooth vulnerability shutoff (R-C)
      T dth = win - K[i] - up;                            // theta-rate
      ds[i] = LOG ? dth / (th[i] - T(RESID)) : dth;       // log-chart rate, or theta-rate
    }
  }

private:
  static T to_state(T th){ if constexpr (LOG){ T d=th-T(RESID); return log(d); } else return th; }
  T theta_of(T v) const { if constexpr (LOG){ return T(RESID)+exp(v); } else { T lo=T(RESID+1e-9); return (v<lo)?lo:v; } }
  T drain(T th) const { T r=th/T(SAT); T b=powS(r, PEXP); return T(KSAT/DZMM)*b; }
  T beta(T th)  const { T r=th/T(SAT); T p=T(APSI)*powS(r,-Q)/T(1e6); T x=p/T(psi50); T d=T(1.0)+powS(x,sh); return T(1.0)/d; }

  double rootf[5] = {0.30,0.28,0.22,0.13,0.07};
  T urate; double rin; double theta0; double psi50, sh;
  T s[L], s_init[L], ds[L];
  double t0, time;
};

template <typename Sys>
static Rcpp::List run_one(Sys sys, double T, double tol, ode::Method m){
  ode::OdeControl ctrl(tol, tol, 1.0, 0.0, 1e-12, 100.0, 1e-6);
  ode::Solver<Sys> solver(sys, ctrl, m);
  int n = -1; std::vector<double> st;
  try {
    solver.advance_adaptive(std::vector<double>{0.0, T});
    st = solver.state();
    n  = static_cast<int>(solver.times().size());
  } catch (...) { st.assign(Sys::L, NA_REAL); }
  // convert state -> theta for reporting
  Rcpp::NumericVector theta(st.size());
  for (size_t i=0;i<st.size();++i) theta[i] = RESID + std::exp(st[i]);  // caller passes LOG systems here
  return Rcpp::List::create(Rcpp::_["n_steps"]=n, Rcpp::_["theta"]=theta, Rcpp::_["state"]=Rcpp::wrap(st));
}

// [[Rcpp::export]]
Rcpp::List rd_soil_compare(double urate, double rin, double theta0, double Tend, double tol, double psi50, double sh){
  using ZS = Soil<double, true>;   // log chart
  using TS = Soil<double, false>;  // theta chart
  // theta-chart explicit (baseline) -- report theta directly
  auto run_theta = [&](ode::Method m){
    ode::OdeControl ctrl(tol, tol, 1.0, 0.0, 1e-12, 100.0, 1e-6);
    TS sys(urate, rin, theta0, psi50, sh); ode::Solver<TS> solver(sys, ctrl, m);
    int n=-1; std::vector<double> st;
    try { solver.advance_adaptive(std::vector<double>{0.0,Tend}); st=solver.state(); n=(int)solver.times().size(); }
    catch(...){ st.assign(5, NA_REAL); }
    return Rcpp::List::create(Rcpp::_["n_steps"]=n, Rcpp::_["theta"]=Rcpp::wrap(st));
  };
  auto run_zeta = [&](ode::Method m, double tl){ return run_one<ZS>(ZS(urate, rin, theta0, psi50, sh), Tend, tl, m); };

  return Rcpp::List::create(
    Rcpp::_["ref"]        = run_zeta(ode::Method::rodas, tol*1e-3),  // tight reference (zeta+RODAS)
    Rcpp::_["theta_rkck"] = run_theta(ode::Method::rkck),
    Rcpp::_["zeta_rkck"]  = run_zeta(ode::Method::rkck, tol),
    Rcpp::_["theta_rodas"]= run_theta(ode::Method::rodas),           // implicit on the RAW chart (clamped)
    Rcpp::_["zeta_rodas"] = run_zeta(ode::Method::rodas, tol));
}
