// T3 (Oracle reformulation-response): reverse-mode certification of the REFORMULATED soil block.
// The L-layer balance is integrated in the LOG-DEPLETION chart zeta=ln(theta-theta_res) with a SMOOTH
// vulnerability shutoff (R-C), fixed-step RK4 (the chart change + smoothing are what's under test; the
// implicit-stepper adjoint is the separately-certified passive-W-Jacobian path). We check:
//   (1) adjoint (tape of the scheme-as-run) == central FD-as-run, wrt 3 differentiable params;
//   (2) the telescoped conservation invariant  D=Σ dz*theta_i  obeys  dD/dt = infil - K_bottom - Σ uptake
//       in VALUE (integrated), and dD(T)/dparam from the adjoint == FD.
// [[Rcpp::plugins(cpp20)]]
#include <Rcpp.h>
#include <vector>
#include <cmath>
#include <functional>
#include <XAD/XAD.hpp>
#include <XAD/Jacobian.hpp>

template <class S> static inline S powS(const S& a, double b){ using std::pow; using xad::pow; return pow(a,b); }
static const int L = 5;
static const double THSAT=0.428, DZ=0.3, RESID=1e-2, PDR=2*6.57+3, Q=6.57, APSI=1.78e3, SH=4.0;
static const double ROOTF[L]={0.30,0.28,0.22,0.13,0.07};
static double rain_at(const std::vector<double>& r,double t){ long d=(long)std::floor(t); if(d<0)d=0; if(d>=(long)r.size())d=r.size()-1; return r[d]; }

// differentiable params: [0]=uptake scale UMAX, [1]=vulnerability midpoint PSI50, [2]=drainage scale KSAT
template <class S> struct Par { S umax, psi50, ksat; };

template <class S> static inline S psi_of(const S& th){ S r=(th<S(RESID))?S(RESID):th; S ratio=r/S(THSAT); return S(APSI)*powS(ratio,-Q)/S(1e6); }
template <class S> static inline S beta_of(const S& th, const Par<S>& pr){ // smooth shutoff in (0,1]
  S p=psi_of(th); S ratio=p/pr.psi50; S d=S(1.0)+powS(ratio,SH); return S(1.0)/d; }
template <class S> static inline S drain_of(const S& th, const Par<S>& pr){ S r=(th<S(RESID))?S(RESID):th;
  S base=powS(r,PDR); S norm=std::pow(THSAT,PDR); return pr.ksat/(S(DZ)*S(norm)) * base; }   // dtheta/dt drainage magnitude

// dtheta/dt per layer: infil(0)+cascade - drainage - uptake
template <class S> static void frhs_theta(const std::vector<S>& th, double t, const Par<S>& pr,
                                          const std::vector<double>& rain, std::vector<S>& d){
  std::vector<S> K(L); for(int l=0;l<L;++l) K[l]=drain_of(th[l],pr);
  S sr = th[0]/S(THSAT); S runoff = powS(sr, 8.0);
  S infil = S(rain_at(rain,t))/S(DZ) * ( S(1.0) - runoff );
  if(infil<S(0.0)) infil=S(0.0);
  for(int l=0;l<L;++l){ S win = (l==0)? infil : K[l-1];
    S up = pr.umax/S(DZ) * beta_of(th[l],pr) * S(ROOTF[l]);
    d[l] = win - K[l] - up; }
}
// log-depletion chart rate: dzeta/dt = (dtheta/dt)/(theta-theta_res), theta=theta_res+exp(zeta)
template <class S> static void rhs_zeta(const std::vector<S>& z, double t, const Par<S>& pr,
                                        const std::vector<double>& rain, std::vector<S>& dz){
  std::vector<S> th(L); for(int l=0;l<L;++l) th[l]=S(RESID)+exp(z[l]);
  std::vector<S> dth(L); frhs_theta(th,t,pr,rain,dth);
  for(int l=0;l<L;++l) dz[l] = dth[l]/(th[l]-S(RESID));
}
// fixed-step RK4 in zeta over N steps of size h; F = final total stock D = DZ*sum(theta)
template <class S> static S integrate_F(std::vector<S> z, double h, int N, const Par<S>& pr,
                                        const std::vector<double>& rain){
  std::vector<S> k1(L),k2(L),k3(L),k4(L),tmp(L); double t=0;
  for(int s=0;s<N;++s){
    rhs_zeta(z,t,pr,rain,k1);
    for(int l=0;l<L;++l)tmp[l]=z[l]+h/2*k1[l]; rhs_zeta(tmp,t+h/2,pr,rain,k2);
    for(int l=0;l<L;++l)tmp[l]=z[l]+h/2*k2[l]; rhs_zeta(tmp,t+h/2,pr,rain,k3);
    for(int l=0;l<L;++l)tmp[l]=z[l]+h*k3[l];   rhs_zeta(tmp,t+h,pr,rain,k4);
    for(int l=0;l<L;++l)z[l]+=h/6*(k1[l]+2*k2[l]+2*k3[l]+k4[l]); t+=h;
  }
  S D=S(0.0); for(int l=0;l<L;++l) D += S(DZ)*(S(RESID)+exp(z[l])); return D;
}

// [[Rcpp::export]]
Rcpp::List t3_grad(std::vector<double> rain, std::vector<double> pars, double h, int N, double eps_fd){
  Par<double> pr{pars[0],pars[1],pars[2]};
  std::vector<double> z0(L, std::log(0.30-RESID));
  double F0 = integrate_F(z0, h, N, pr, rain);
  // reverse-mode adjoint wrt the 3 params
  using ad=xad::adj<double>; using AD=ad::active_type; ad::tape_type tape(false); tape.activate();
  std::vector<AD> in={AD(pars[0]),AD(pars[1]),AD(pars[2])};
  std::function<std::vector<AD>(std::vector<AD>&)> fwd=[&](std::vector<AD>& x){
    Par<AD> p{x[0],x[1],x[2]}; std::vector<AD> za(z0.begin(),z0.end());
    return std::vector<AD>{ integrate_F(za, h, N, p, rain) }; };
  auto jac=xad::computeJacobian(in, fwd, (size_t)1, &tape); tape.deactivate();
  std::vector<double> grad_rev(jac[0].begin(), jac[0].end());
  // central FD-as-run (same fixed steps)
  std::vector<double> grad_fd(3);
  for(int j=0;j<3;++j){ double e=eps_fd*std::max(1.0,std::fabs(pars[j]));
    std::vector<double> vp=pars, vm=pars; vp[j]+=e; vm[j]-=e;
    Par<double> pp{vp[0],vp[1],vp[2]}, pm{vm[0],vm[1],vm[2]};
    grad_fd[j]=(integrate_F(z0,h,N,pp,rain)-integrate_F(z0,h,N,pm,rain))/(2*e); }
  double mae=0,mre=0; for(int j=0;j<3;++j){ double a=std::fabs(grad_rev[j]-grad_fd[j]); mae=std::max(mae,a);
    mre=std::max(mre,a/std::max(1e-30,std::fabs(grad_fd[j]))); }

  // telescoped invariant (VALUE): D(N)-D(0) vs integral of (infil - K_bottom - sum uptake) over the run
  std::vector<double> z=z0; double t=0, D0=0; for(int l=0;l<L;++l)D0+=DZ*(RESID+std::exp(z[l]));
  double flux_int=0; std::vector<double> k1(L),k2(L),k3(L),k4(L),tmp(L);
  auto boundary=[&](const std::vector<double>& zz,double tt){ std::vector<double> th(L); for(int l=0;l<L;++l)th[l]=RESID+std::exp(zz[l]);
    double infil=rain_at(rain,tt)/DZ*std::max(0.0,1-std::pow(th[0]/THSAT,8.0)); double Kb=drain_of(th[L-1],pr);
    double up=0; for(int l=0;l<L;++l) up+=pr.umax/DZ*beta_of(th[l],pr)*ROOTF[l];
    return DZ*(infil - Kb - up); };  // dD/dt
  for(int s=0;s<N;++s){ // RK4 in zeta, accumulate boundary flux by RK4 too (consistent quadrature)
    double b1=boundary(z,t);
    rhs_zeta(z,t,pr,rain,k1); for(int l=0;l<L;++l)tmp[l]=z[l]+h/2*k1[l]; double b2=boundary(tmp,t+h/2);
    rhs_zeta(tmp,t+h/2,pr,rain,k2); for(int l=0;l<L;++l)tmp[l]=z[l]+h/2*k2[l]; double b3=boundary(tmp,t+h/2);
    rhs_zeta(tmp,t+h/2,pr,rain,k3); for(int l=0;l<L;++l)tmp[l]=z[l]+h*k3[l]; double b4=boundary(tmp,t+h);
    rhs_zeta(tmp,t+h,pr,rain,k4);
    for(int l=0;l<L;++l)z[l]+=h/6*(k1[l]+2*k2[l]+2*k3[l]+k4[l]);
    flux_int += h/6*(b1+2*b2+2*b3+b4); t+=h; }
  double DN=0; for(int l=0;l<L;++l)DN+=DZ*(RESID+std::exp(z[l]));
  double inv_resid = (DN-D0) - flux_int;

  return Rcpp::List::create(Rcpp::_["F"]=F0, Rcpp::_["grad_rev"]=grad_rev, Rcpp::_["grad_fd"]=grad_fd,
    Rcpp::_["max_abs_err"]=mae, Rcpp::_["max_rel_err"]=mre,
    Rcpp::_["invariant_resid"]=inv_resid, Rcpp::_["dD"]=DN-D0, Rcpp::_["flux_int"]=flux_int);
}
