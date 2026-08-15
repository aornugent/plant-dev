// All six photosynthesis-family rows, held to a central difference of the solve
// at a frozen collar, with the reference's step swept -- an analytic row is flat
// in the step, a difference is not, so the sweep is what says which is right.
#include <phylloptim.hpp>
#include "root_network.hpp"
#include <chrono>
#include <cmath>
#include <cstdio>
#include <vector>
namespace {
const double kT=0.000157,kKs=1.0,kH=5.0;
std::vector<double> kDepth{0.3,0.6,1.0,1.4,1.8};
std::vector<double> kCarbon{9.0,6.0,4.0,2.5,1.5};
struct T{double v[14];};
const T kB{{96.0,2.680147,3.898245,5.870283,2.680147,3.898245,5.870283,1.5,
            157.44,0.30,0.7,0.99,7.5,1.44}};
void apply(phylloptim::Leaf&l,const T&t){l.set_traits(t.v[0],t.v[1],t.v[2],t.v[3],
  t.v[4],t.v[5],t.v[6],t.v[7],t.v[8],t.v[9],t.v[10],t.v[11],t.v[12],t.v[13]);}
void seat(phylloptim::Leaf&l,const std::vector<double>&p,double ppfd,double tleaf){
  l.set_physiology(fixture::root_network(kCarbon,kDepth),ppfd,p,kDepth,
                   kKs*kT/kH,2.0,40.0,tleaf,21.0,101.3);}
double rel(double a,double b){double s=std::max(std::abs(a),std::abs(b));
  return s>0?std::abs(a-b)/s:0.0;}
template<class F> double time_us(F&&f,int n){auto t0=std::chrono::steady_clock::now();
  for(int i=0;i<n;++i)f();auto t1=std::chrono::steady_clock::now();
  return std::chrono::duration<double,std::micro>(t1-t0).count()/n;}
}
int main(){
  struct S{const char*n;std::vector<double> psi;double ppfd;double tleaf;};
  // 40 C as well as 25: at 25 the Arrhenius factors are exactly 1, so a chain
  // through them is inert there BY CONSTRUCTION and the check would be blind.
  const std::vector<S> st={{"wet 25C",{1.0,1.1,1.2,1.3,1.4},900.0,25.0},
                           {"dry 25C",{2.6,2.8,3.0,3.2,3.4},900.0,25.0},
                           {"shaded 25C",{1.4,1.5,1.6,1.7,1.8},60.0,25.0},
                           {"wet 40C",{1.0,1.1,1.2,1.3,1.4},900.0,40.0},
                           {"dry 40C",{2.6,2.8,3.0,3.2,3.4},900.0,40.0}};
  const int idx[6]={9,10,11,0,8,13};
  const char*nm[6]={"a","curv_elec","curv_colim","vcmax_25","jmax_25","R_d_25"};
  const double steps[4]={1e-3,1e-4,1e-5,1e-6};
  for(const S&s:st){
    phylloptim::Leaf l; apply(l,kB); seat(l,s.psi,s.ppfd,s.tleaf);
    l.find_root_collar_psi();
    const double collar=l.opt_root_psi_;
    l.evaluate_root_collar_psi(collar);
    const phylloptim::Leaf::PhotoTraitRows R=l.photo_trait_rows();
    const double pp[6]={R.dprofit_da,R.dprofit_dcurv_elec,R.dprofit_dcurv_colim,
                        R.dprofit_dvcmax_25,R.dprofit_djmax_25,R.dprofit_dR_d_25};
    const double rr[6]={R.dmarginal_da,R.dmarginal_dcurv_elec,R.dmarginal_dcurv_colim,
                        R.dmarginal_dvcmax_25,R.dmarginal_djmax_25,R.dmarginal_dR_d_25};
    printf("\n=== %s: collar %.8g  vcmax_ %.6g jmax_ %.6g R_d_ %.6g\n",
           s.n,collar,l.vcmax_,l.jmax_,l.R_d_);
    for(int k=0;k<6;++k){
      double bestP=1,bestR=1; double du=0;
      for(double rs:steps){
        const double base=kB.v[idx[k]],h=base*rs;
        double p[2],m[2]; std::vector<double> u0(kDepth.size()),u1(kDepth.size());
        for(int side=0;side<2;++side){
          T t=kB; t.v[idx[k]]=base+(side==0?h:-h);
          apply(l,t); seat(l,s.psi,s.ppfd,s.tleaf); l.evaluate_root_collar_psi(collar);
          p[side]=l.profit_; m[side]=l.dprofit_droot_collar_psi(collar);
          for(size_t i=0;i<kDepth.size();++i)(side==0?u0:u1)[i]=l.soil_consumption_[i];
        }
        apply(l,kB); seat(l,s.psi,s.ppfd,s.tleaf); l.evaluate_root_collar_psi(collar);
        for(size_t i=0;i<kDepth.size();++i) du=std::max(du,std::abs(u0[i]-u1[i]));
        bestP=std::min(bestP,rel((p[0]-p[1])/(2*h),pp[k]));
        bestR=std::min(bestR,rel((m[0]-m[1])/(2*h),rr[k]));
      }
      printf("  %-10s dPi % .8e (best rel %.2e)   dR % .8e (best rel %.2e)  uptake moved %.1e\n",
             nm[k],pp[k],bestP,rr[k],bestR,du);
    }
  }
  // cost
  {
    phylloptim::Leaf l; apply(l,kB); seat(l,st[0].psi,st[0].ppfd,25.0);
    l.find_root_collar_psi(); const double c=l.opt_root_psi_;
    l.evaluate_root_collar_psi(c);
    printf("\n=== cost ===\n  photo_trait_rows (all six) %7.3f us\n",
           time_us([&]{volatile double v=l.photo_trait_rows().dmarginal_dR_d_25;(void)v;},20000));
    int sd=0;
    printf("  ONE drive of the twelve    %7.3f us\n", time_us([&]{
      T t=kB; t.v[9]=kB.v[9]*(sd?1.0001:0.9999); sd^=1;
      apply(l,t); seat(l,st[0].psi,st[0].ppfd,25.0); l.evaluate_root_collar_psi(c);
      volatile double v=l.dprofit_droot_collar_psi(c); (void)v;},2000));
  }
  return 0;
}
