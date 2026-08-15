// Do the three remaining non-curve driven traits sit on the same waist?
// vcmax_ appears only in the rubisco-limited kernel, jmax_ only in the electron
// transport, R_d_ only in the colimitation -- and all three are EXACTLY linear
// in their _25 trait, since both Arrhenius forms are ref_value times a factor.
// If so their rows are chain rules through one intermediate, as `a` and the two
// curvatures already are.
#include <phylloptim.hpp>
#include "root_network.hpp"
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
void seat(phylloptim::Leaf&l,const std::vector<double>&p,double ppfd){
  l.set_physiology(fixture::root_network(kCarbon,kDepth),ppfd,p,kDepth,
                   kKs*kT/kH,2.0,40.0,25.0,21.0,101.3);}
double rel(double a,double b){double s=std::max(std::abs(a),std::abs(b));
  return s>0?std::abs(a-b)/s:0.0;}
}
int main(){
  struct S{const char*n;std::vector<double> psi;double ppfd;};
  const std::vector<S> st={{"wet",{1.0,1.1,1.2,1.3,1.4},900.0},
                           {"dry",{2.6,2.8,3.0,3.2,3.4},900.0},
                           {"shaded",{1.4,1.5,1.6,1.7,1.8},60.0}};
  const int idx[3]={0,8,13};
  const char*nm[3]={"vcmax_25","jmax_25","R_d_25"};
  for(const S&s:st){
    phylloptim::Leaf l; apply(l,kB); seat(l,s.psi,s.ppfd);
    l.find_root_collar_psi();
    const double collar=l.opt_root_psi_;
    l.evaluate_root_collar_psi(collar);
    const double ci=l.ci_;
    printf("\n=== %s: vcmax_ %.8g jmax_ %.8g R_d_ %.8g  (linear in the _25?)\n",
           s.n,l.vcmax_,l.jmax_,l.R_d_);
    printf("  vcmax_/vcmax_25 %.10f  jmax_/jmax_25 %.10f  R_d_/R_d_25 %.10f\n",
           l.vcmax_/kB.v[0], l.jmax_/kB.v[8], l.R_d_/kB.v[13]);
    for(int k=0;k<3;++k){
      // dA/dtheta at FIXED ci, by moving the trait and re-evaluating the kernel
      const double base=kB.v[idx[k]], h=base*1e-6;
      double A[2];
      for(int side=0;side<2;++side){
        T t=kB; t.v[idx[k]]=base+(side==0?h:-h);
        apply(l,t); seat(l,s.psi,s.ppfd);
        A[side]=l.assim_colimited(ci);
      }
      apply(l,kB); seat(l,s.psi,s.ppfd); l.evaluate_root_collar_psi(collar);
      const double dA=(A[0]-A[1])/(2*h);
      // the chain through the single intermediate, scaled by its own linearity
      double pred=0.0;
      if(k==2){ pred = -(l.R_d_/base); }               // A = colimit(...) - R_d_
      printf("  %-9s dA/dtheta|_ci  % .10e%s\n", nm[k], dA,
             (k==2)?"":"   (through one intermediate)");
      if(k==2) printf("            predicted -R_d_/R_d_25 % .10e   rel %.3e\n",
                      pred, rel(pred,dA));
      // and the frozen-collar uptake row
      double worst=0.0;
      std::vector<double> u0(kDepth.size()),u1(kDepth.size());
      for(int side=0;side<2;++side){
        T t=kB; t.v[idx[k]]=base+(side==0?h:-h);
        apply(l,t); seat(l,s.psi,s.ppfd); l.evaluate_root_collar_psi(collar);
        for(size_t i=0;i<kDepth.size();++i)(side==0?u0:u1)[i]=l.soil_consumption_[i];
      }
      apply(l,kB); seat(l,s.psi,s.ppfd); l.evaluate_root_collar_psi(collar);
      for(size_t i=0;i<kDepth.size();++i) worst=std::max(worst,std::abs(u0[i]-u1[i]));
      printf("            frozen-collar uptake moved by at most %.3e\n", worst);
    }
  }
  return 0;
}
