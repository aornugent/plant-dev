// E4 (Oracle): reverse-mode certification of the proposed fast subsystem — the (L + m) ODE
//   u̇_l = infil_l(t) - drain(u_l) - a_l,   a_l = Σ_n W_n c_l(x_n, u, p_n)      (m-member collocation)
//   ṗ_n = k · ∂P/∂p(p_n; u)                                                     (tracked control, no argmax)
// carrying the NEW structural elements vs Phase B: (i) per-member controls promoted to differential
// states (the tracked-q / TF24f idea), (ii) the coupling as an m-member quadrature with active weights.
// Two-level record→replay: an adaptive double pass records the micro step schedule; an active pass
// replays it (fixed steps) so the tape IS the discrete adjoint. We check adjoint vs frozen-record FD,
// and sweep k (tracking lag) and m (collocation) to show the reduction errors live in the VALUE, not
// the gradient — the adjoint stays exact for the scheme as run at every k, m.
// [[Rcpp::plugins(cpp20)]]
#include <Rcpp.h>
#include <vector>
#include <cmath>
#include <functional>
#include <XAD/XAD.hpp>
#include <XAD/Jacobian.hpp>

template <class S> static inline S powS(const S& a, double b){ using std::pow; using xad::pow; return pow(a,b); }
static const int L = 3;                                  // fast (soil-like) states
static const double THSAT = 0.428, DR_P = 6.0, KD = 40.0, RESID = 1e-2;
static double rain_at(const std::vector<double>& r, double t){ long d=(long)std::floor(t); if(d<0)d=0; if(d>=(long)r.size())d=r.size()-1; return r[d]; }

// differentiable params: [0]=uptake scale theta, [1]=control gain, [2]=pref (control setpoint offset)
template <class S> struct Par { S theta, gain, pref; };

// smoothstep stress in [0,1]
template <class S> static inline S stress(const S& u){ S s=(u-RESID)/(0.12-RESID);
  if(s<=S(0.0)) return S(0.0); if(s>=S(1.0)) return S(1.0); return s*s*(S(3.0)-S(2.0)*s); }
// per-member root weight for layer l at member coordinate x in [0,1] (smooth in x -> collocatable)
static inline double rootw(int l, double x){ double c[3]={0.55,0.30,0.15}; return c[l]*(0.5+x); }
// control optimum given the soil aggregate (the control tracks the soil): drier -> larger control
template <class S> static inline S popt(const std::vector<S>& u, const Par<S>& pr){
  S ub=S(0.0); for(auto&e:u) ub+=e; ub/=double(L);
  return pr.pref + pr.gain*(S(1.0) - ub/THSAT);          // dry (small ub) -> larger control
}
// objective gradient dP/dp = -(p - p_opt); tracked control relaxes p -> p_opt at rate k
template <class S> static inline S dPdp(const S& p, const std::vector<S>& u, const Par<S>& pr){ return -(p - popt(u,pr)); }
// B3 footgun probe: an interior member-coordinate regime boundary whose crossing MOVES with u
// (members below x_cut(u) shut off; drier soil -> higher cutoff). GATE_ON toggles it; GATE_W is the
// smoothing scale (0 = hard step -> the kink-crossing quadrature error the Oracle flagged; >0 = the
// model-level smoothing cure). x_cut(u) moving at the micro rate is what makes the quadrature error's
// u-derivative oscillate, so its gradient converges slower than its value unless smoothed.
static bool   GATE_ON = false;
static double GATE_W  = 0.0;
template <class S> static inline S gate(double x, const std::vector<S>& u){
  if(!GATE_ON) return S(1.0);
  S ub=S(0.0); for(int l=0;l<L;++l) ub+=u[l]; ub/=double(L);
  S xcut = S(0.30) + S(0.40)*(S(1.0) - ub/THSAT);          // dry -> higher cutoff (moves with u)
  S z = (S(x) - xcut);
  if(GATE_W<=0.0) return (z>S(0.0))? S(1.0):S(0.0);         // hard step (kink)
  S s = z/S(GATE_W); if(s<=S(-0.5))return S(0.0); if(s>=S(0.5))return S(1.0);
  S t = s+S(0.5); return t*t*(S(3.0)-S(2.0)*t);             // smoothstep over width GATE_W
}
// per-member, per-layer coupling c_l(x,u,p): uptake proportional to control p and soil availability
template <class S> static inline S cfun(int l, double x, const std::vector<S>& u, const S& p, const Par<S>& pr){
  return pr.theta * S(rootw(l,x)) * p * stress(u[l]) * gate(x,u);
}

// aggregate a_l = Σ_n W_n c_l  over m members at x_n (midpoint), W_n = 1/m (a smooth quadrature)
template <class S>
static void aggregate(const std::vector<S>& u, const std::vector<S>& p, int m,
                      const Par<S>& pr, std::vector<S>& a){
  for(int l=0;l<L;++l) a[l]=S(0.0);
  for(int n=0;n<m;++n){ double x=(n+0.5)/m; double W=1.0/m;
    for(int l=0;l<L;++l) a[l]+=S(W)*cfun(l,x,u,p[n],pr); }
}
// full RHS of the (L+m) fast system: y = [u(0..L-1), p(0..m-1)]
template <class S>
static void rhs(const std::vector<S>& y, double t, int m, double k, const Par<S>& pr,
                const std::vector<double>& rain, std::vector<S>& dy){
  std::vector<S> u(y.begin(), y.begin()+L), p(y.begin()+L, y.begin()+L+m), a(L);
  aggregate(u,p,m,pr,a);
  std::vector<S> drain(L); for(int l=0;l<L;++l){ S r=u[l]/THSAT; if(r<S(0.0))r=S(0.0); drain[l]=S(KD)*powS(r,DR_P); }
  S infil = S(rain_at(rain,t));
  for(int l=0;l<L;++l){ S win = (l==0)? infil : drain[l-1]; dy[l]=(win - drain[l] - a[l]); }
  for(int n=0;n<m;++n) dy[L+n] = S(k) * dPdp(p[n], u, pr);
}

namespace rkck { static constexpr double c2=.2,c3=.3,c4=.6,c5=1.,c6=.875,
  a21=.2,a31=3./40,a32=9./40,a41=.3,a42=-.9,a43=1.2,a51=-11./54,a52=2.5,a53=-70./27,a54=35./27,
  a61=1631./55296,a62=175./512,a63=575./13824,a64=44275./110592,a65=253./4096,
  b1=37./378,b3=250./621,b4=125./594,b6=512./1771,
  e1=b1-2825./27648,e3=b3-18575./48384,e4=b4-13525./55296,e5=-277./14336,e6=b6-.25; }

// replay fixed recorded steps (tapes in S)
template <class S>
static void replay(std::vector<S>& y, const std::vector<double>& hs, double t0, int m, double k,
                   const Par<S>& pr, const std::vector<double>& rain){
  using namespace rkck; int n=y.size(); double t=t0;
  std::vector<S> k1(n),k2(n),k3(n),k4(n),k5(n),k6(n),tmp(n);
  for(double h:hs){
    rhs(y,t,m,k,pr,rain,k1);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*a21*k1[i]; rhs(tmp,t+c2*h,m,k,pr,rain,k2);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*(a31*k1[i]+a32*k2[i]); rhs(tmp,t+c3*h,m,k,pr,rain,k3);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*(a41*k1[i]+a42*k2[i]+a43*k3[i]); rhs(tmp,t+c4*h,m,k,pr,rain,k4);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*(a51*k1[i]+a52*k2[i]+a53*k3[i]+a54*k4[i]); rhs(tmp,t+c5*h,m,k,pr,rain,k5);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*(a61*k1[i]+a62*k2[i]+a63*k3[i]+a64*k4[i]+a65*k5[i]); rhs(tmp,t+c6*h,m,k,pr,rain,k6);
    for(int i=0;i<n;++i)y[i]+=h*(b1*k1[i]+b3*k3[i]+b4*k4[i]+b6*k6[i]);
    t+=h;
  }
}
// adaptive double pass; records accepted steps; returns functional F = time-avg of mean(u)
static double record(std::vector<double>& y, double T, int m, double k, const Par<double>& pr,
                     const std::vector<double>& rain, double tol, std::vector<double>& hs){
  using namespace rkck; int n=y.size(); double t=0,h=std::min(0.01,T);
  std::vector<double> k1(n),k2(n),k3(n),k4(n),k5(n),k6(n),tmp(n),y5(n);
  double Fsum=0; long ns=0; int guard=0;
  auto ubar=[&](const std::vector<double>& yy){ double s=0; for(int l=0;l<L;++l)s+=yy[l]; return s/L; };
  while(t<T-1e-12 && guard++<500000){ if(t+h>T)h=T-t;
    rhs(y,t,m,k,pr,rain,k1);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*a21*k1[i]; rhs(tmp,t+c2*h,m,k,pr,rain,k2);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*(a31*k1[i]+a32*k2[i]); rhs(tmp,t+c3*h,m,k,pr,rain,k3);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*(a41*k1[i]+a42*k2[i]+a43*k3[i]); rhs(tmp,t+c4*h,m,k,pr,rain,k4);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*(a51*k1[i]+a52*k2[i]+a53*k3[i]+a54*k4[i]); rhs(tmp,t+c5*h,m,k,pr,rain,k5);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*(a61*k1[i]+a62*k2[i]+a63*k3[i]+a64*k4[i]+a65*k5[i]); rhs(tmp,t+c6*h,m,k,pr,rain,k6);
    double err=0; for(int i=0;i<n;++i){ y5[i]=y[i]+h*(b1*k1[i]+b3*k3[i]+b4*k4[i]+b6*k6[i]);
      double e=h*(e1*k1[i]+e3*k3[i]+e4*k4[i]+e5*k5[i]+e6*k6[i]); double sc=1e-9+tol*std::max(std::fabs(y[i]),std::fabs(y5[i])); err+=(e/sc)*(e/sc); }
    err=std::sqrt(err/n); if(!std::isfinite(err))err=1e3;
    if(err<=1.0){ for(int i=0;i<n;++i)y[i]=y5[i]; t+=h; hs.push_back(h); Fsum+=ubar(y); ns++;
      h*=std::min(5.0,std::max(0.2,0.9*std::pow(err+1e-30,-0.2))); }
    else { h*=std::max(0.1,0.9*std::pow(err,-0.2)); if(h<1e-11){hs.push_back(T-t>0?T-t:1e-11);t=T;} }
  }
  return Fsum/std::max(1L,ns);
}
// functional over a replayed trajectory (S) reusing the recorded steps
template <class S>
static S functional(std::vector<S> y, const std::vector<double>& hs, int m, double k,
                    const Par<S>& pr, const std::vector<double>& rain){
  using namespace rkck; int n=y.size(); double t=0; S Fsum=S(0.0); long ns=0;
  std::vector<S> k1(n),k2(n),k3(n),k4(n),k5(n),k6(n),tmp(n);
  auto ubar=[&](const std::vector<S>& yy){ S s=S(0.0); for(int l=0;l<L;++l)s+=yy[l]; return s/double(L); };
  for(double h:hs){
    rhs(y,t,m,k,pr,rain,k1);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*a21*k1[i]; rhs(tmp,t+c2*h,m,k,pr,rain,k2);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*(a31*k1[i]+a32*k2[i]); rhs(tmp,t+c3*h,m,k,pr,rain,k3);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*(a41*k1[i]+a42*k2[i]+a43*k3[i]); rhs(tmp,t+c4*h,m,k,pr,rain,k4);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*(a51*k1[i]+a52*k2[i]+a53*k3[i]+a54*k4[i]); rhs(tmp,t+c5*h,m,k,pr,rain,k5);
    for(int i=0;i<n;++i)tmp[i]=y[i]+h*(a61*k1[i]+a62*k2[i]+a63*k3[i]+a64*k4[i]+a65*k5[i]); rhs(tmp,t+c6*h,m,k,pr,rain,k6);
    for(int i=0;i<n;++i)y[i]+=h*(b1*k1[i]+b3*k3[i]+b4*k4[i]+b6*k6[i]);
    t+=h; Fsum+=ubar(y); ns++;
  }
  return Fsum/double(std::max(1L,ns));
}

static std::vector<double> init_state(int m, const std::vector<double>& p3){
  std::vector<double> y(L+m, 0.30*THSAT); Par<double> pr{p3[0],p3[1],p3[2]};
  std::vector<double> u(y.begin(),y.begin()+L); double po=popt(u,pr);
  for(int n=0;n<m;++n) y[L+n]=po;   // seed controls at their optimum (spin-up analogue)
  return y;
}

// [[Rcpp::export]]
Rcpp::List e4_grad(std::vector<double> rain, std::vector<double> pars, int m, double T, double k,
                   double tol, double eps_fd, int gate_on=0, double gate_w=0.0){
  GATE_ON = (gate_on!=0); GATE_W = gate_w;
  // pass 1: record schedule (double)
  std::vector<double> y0=init_state(m,pars), y=y0, hs;
  Par<double> pr{pars[0],pars[1],pars[2]};
  double F0=record(y, T, m, k, pr, rain, tol, hs);
  // reverse-mode adjoint wrt the 3 params over the frozen schedule
  using ad=xad::adj<double>; using AD=ad::active_type; ad::tape_type tape(false); tape.activate();
  std::vector<AD> in={AD(pars[0]),AD(pars[1]),AD(pars[2])};
  std::function<std::vector<AD>(std::vector<AD>&)> fwd=[&](std::vector<AD>& x){
    Par<AD> p{x[0],x[1],x[2]}; std::vector<AD> ya(y0.begin(),y0.end());
    // re-seed controls at optimum in AD (matches init_state, keeps it on-tape)
    std::vector<AD> u(ya.begin(),ya.begin()+L); AD po=popt(u,p); for(int n=0;n<m;++n) ya[L+n]=po;
    return std::vector<AD>{ functional(ya, hs, m, k, p, rain) }; };
  auto jac=xad::computeJacobian(in, fwd, (size_t)1, &tape); tape.deactivate();
  std::vector<double> grad_rev(jac[0].begin(), jac[0].end());
  // frozen-schedule central FD (same recorded steps, same re-seed)
  std::vector<double> grad_fd(3);
  for(int j=0;j<3;++j){ double e=eps_fd*std::max(1.0,std::fabs(pars[j]));
    std::vector<double> vp=pars, vm=pars; vp[j]+=e; vm[j]-=e;
    Par<double> pp{vp[0],vp[1],vp[2]}, pm{vm[0],vm[1],vm[2]};
    std::vector<double> yp(y0.begin(),y0.end()), ym(y0.begin(),y0.end());
    { std::vector<double> u(yp.begin(),yp.begin()+L); double po=popt(u,pp); for(int n=0;n<m;++n)yp[L+n]=po; }
    { std::vector<double> u(ym.begin(),ym.begin()+L); double po=popt(u,pm); for(int n=0;n<m;++n)ym[L+n]=po; }
    double Fp=functional(yp,hs,m,k,pp,rain), Fm=functional(ym,hs,m,k,pm,rain);
    grad_fd[j]=(Fp-Fm)/(2*e); }
  double max_abs=0, max_rel=0;
  for(int j=0;j<3;++j){ double ae=std::fabs(grad_rev[j]-grad_fd[j]); max_abs=std::max(max_abs,ae);
    max_rel=std::max(max_rel, ae/std::max(1e-12,std::fabs(grad_fd[j]))); }
  return Rcpp::List::create(Rcpp::Named("F")=F0, Rcpp::Named("nstep")=(double)hs.size(),
    Rcpp::Named("grad_rev")=Rcpp::wrap(grad_rev), Rcpp::Named("grad_fd")=Rcpp::wrap(grad_fd),
    Rcpp::Named("max_abs_err")=max_abs, Rcpp::Named("max_rel_err")=max_rel);
}
