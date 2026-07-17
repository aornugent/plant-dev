#!/usr/bin/env Rscript
# LEAN PROBE 2 for #1: the expensive piece is the per-cohort physiology (uptake(theta)),
# not the light field (probe 1). So the sub-cycle needs a CHEAP surrogate of uptake(theta).
# The per-layer scaling probe failed earlier because uptake is non-separable across layers.
# Test the next candidate: a per-macro LINEARIZATION with the full 5x5 Jacobian
#   U(theta) ~ U0 + J (theta - theta0),  J_ij = d uptake_i / d theta_j
# built from 5 extra physiology evals at macro start. Does it track true uptake over the
# theta excursion a day (or a few days) of drying produces? If yes, #2's sub-cycle can run
# a cheap linear uptake model refreshed once per macro.
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE))
options(width=110)
gen_rain<-function(seed,ndays=365,p01b=0.09,p11b=0.38,shape=0.6,scaleb=11,occ=1){set.seed(seed);doy<-(seq_len(ndays)-1)%%365;season<-(1+cos(2*pi*(doy-15)/365))/2;p01<-pmin(0.9,(0.010+p01b*season^1.5)*occ);p11<-pmin(0.95,0.15+p11b*season^1.5);wet<-logical(ndays);for(t in 2:ndays)wet[t]<-runif(1)<(if(wet[t-1])p11[t] else p01[t]);scale<-4+scaleb*season;rain<-numeric(ndays);rain[wet]<-rgamma(sum(wet),shape=shape,scale=scale[wet]);rain[rain<0.1]<-0;round(rain,2)}
rr<-gen_rain(24)
p0<-scm_base_parameters("TF24"); p0$max_patch_lifetime<-30
p1<-add_strategies(p0, trait_matrix(0.0825,"lma"))
env<-Environment("TF24"); env$extrinsic_drivers_set_variable("rainfall",0:364,rr)
h<-exp(seq(log(14),log(0.5),length.out=20)); d<-0.02*(h/max(h))^-1.3
st<-make_initial_state(p1,heights=h,densities=d,env=env,ctrl=Control())
patch<-SCM("TF24","TF24_Env")(set_initial_state(p1,st),env,Control())$patch
ne<-patch$environment$ode_size; ns<-patch$ode_size; si<-(ns-ne+1):(ns-ne+5); y0<-patch$ode_state
SAT<-0.428;KSAT<-163.0411;NPSI<-6.57;A<-1;B<-8;DZ<-0.3
Kf<-function(th)KSAT*(pmax(th,0)/SAT)^(2*NPSI+3); inf<-function(t0,r)r*max(0,1-A*(t0/SAT)^B)
rfn<-function(t)env$extrinsic_drivers_evaluate("rainfall",t)
# true per-layer uptake at soil state theta (backed out of the real patch derivs)
uptake<-function(th,t){ yt<-y0;yt[si]<-th; dd<-patch$derivs(yt,t)[si]
  r<-rfn(t);win<-numeric(5);wo<-Kf(th);win[1]<-inf(th[1],r);for(i in 2:5)win[i]<-wo[i-1]; win-wo-dd*DZ }

theta0<-y0[si]; t0<-3.0
U0<-uptake(theta0,t0)
# 5x5 Jacobian by central FD (10 evals; a one-off per macro in #2 it'd be 5 forward)
eps<-1e-3; J<-matrix(0,5,5)
for(j in 1:5){ tp<-theta0; tp[j]<-tp[j]+eps; tm<-theta0; tm[j]<-tm[j]-eps
  J[,j]<-(uptake(tp,t0)-uptake(tm,t0))/(2*eps) }
cat("U0 (uptake at theta0):", sprintf("%.4f",U0),"\n")
cat("diag(J) (dU_i/dtheta_i):", sprintf("%.3f",diag(J)),"\n")
cat("max |off-diagonal J| (cross-layer coupling):", sprintf("%.3f",max(abs(J-diag(diag(J))))),"\n\n")

lin<-function(th) as.numeric(U0 + J %*% (th-theta0))
cat(sprintf("%-28s %10s %10s %10s\n","test theta (drying)","||U_true||","lin err","rel err"))
# drying paths: uniform, top-heavy, and a realistic differential-drying profile
tests<-list(
  "uniform -0.02"      = theta0-0.02,
  "uniform -0.05"      = theta0-0.05,
  "top -0.08 only"     = theta0-c(0.08,0,0,0,0),
  "graded (top drier)" = theta0-c(0.08,0.05,0.03,0.015,0.005),
  "graded x2"          = theta0-c(0.14,0.09,0.05,0.025,0.01))
for(nm in names(tests)){ th<-pmax(tests[[nm]],0.02); Ut<-uptake(th,t0); Ul<-lin(th)
  cat(sprintf("%-28s %10.4f %10.2e %10.2e\n", nm, sqrt(sum(Ut^2)), max(abs(Ul-Ut)), max(abs(Ul-Ut))/max(abs(Ut),1e-6))) }
cat("\nSmall lin err over a day's excursion => a per-macro linear uptake surrogate is enough for #2.\n")
