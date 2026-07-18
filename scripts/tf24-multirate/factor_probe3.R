#!/usr/bin/env Rscript
# LEAN PROBE 3 for #1: uptake(theta) is strongly nonlinear (probe 2 killed the linear
# surrogate) but mostly diagonal (off-diag J 0.088 vs diag 0.93). Test a cheap NONLINEAR
# per-layer response surrogate: for each layer i, sample U_i as theta_i varies (others held
# at theta0), build a monotone interpolant curve_i(theta_i); predict U(theta) ~ curve_i(theta_i).
# k points/layer = 5k physiology evals per macro. Does it track true uptake on realistic
# differential-drying profiles? This decides #2's sub-cycle surrogate.
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
uptake<-function(th,t){ yt<-y0;yt[si]<-th; dd<-patch$derivs(yt,t)[si]
  r<-rfn(t);win<-numeric(5);wo<-Kf(th);win[1]<-inf(th[1],r);for(i in 2:5)win[i]<-wo[i-1]; win-wo-dd*DZ }
theta0<-y0[si]; t0<-3.0

build_curves<-function(k){                       # k points/layer over [0.02, theta0_i]
  grid<-lapply(1:5, function(i) seq(0.02, theta0[i], length.out=k))
  Uc<-lapply(1:5, function(i){ sapply(grid[[i]], function(v){ th<-theta0; th[i]<-v; uptake(th,t0)[i] }) })
  list(grid=grid, Uc=Uc)
}
predict_sep<-function(cur, th) sapply(1:5, function(i) approx(cur$grid[[i]], cur$Uc[[i]], xout=th[i], rule=2)$y)

tests<-list("uniform -0.05"=theta0-0.05,"top -0.08"=theta0-c(0.08,0,0,0,0),
  "graded"=theta0-c(0.08,0.05,0.03,0.015,0.005),"graded x2"=pmax(theta0-c(0.14,0.09,0.05,0.025,0.01),0.02))
for(k in c(4,8)){ cur<-build_curves(k)
  cat(sprintf("--- separable nonlinear curves, %d pts/layer (%d physiology evals/macro) ---\n",k,5*k))
  for(nm in names(tests)){ th<-pmax(tests[[nm]],0.02); Ut<-uptake(th,t0); Up<-predict_sep(cur,th)
    cat(sprintf("  %-16s abs=%.2e rel=%.2e\n", nm, max(abs(Up-Ut)), max(abs(Up-Ut))/max(abs(Ut),1e-6))) } }
cat("\nIf separable curves track (< ~1e-2), #2 sub-cycle = per-layer uptake curves refreshed per macro.\n")
