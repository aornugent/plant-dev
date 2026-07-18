#!/usr/bin/env Rscript
# E2 + E3 (Oracle), faithful patch-level: tracked control (TF24f, dq/dt=k*dprofit, EVALUATE) vs
# solved optimum (TF24, re-OPTIMISE = QSS). On the same seeded stand, freeze cohort size/density and
# integrate the soil (+ the per-cohort tracked q, for TF24f) forward under a stiff rainfall window,
# using the REAL patch soil rate each micro-step (uptake refreshed continuously -> no held-coupling
# plateau by construction). Compare the tracked-q soil trajectory to the QSS soil trajectory, sweeping
# k_acclim. E2 = does tracked-q keep up (lag vs k)? E3 = does the continuously-refreshed fast subsystem
# reproduce the QSS/global soil trajectory on exactly the regimes that plateaued? go/no-go.
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE)); options(width=115)
gen_rain<-function(seed,ndays=365,p01b=0.09,p11b=0.38,shape=0.6,scaleb=11,occ=1){set.seed(seed);doy<-(seq_len(ndays)-1)%%365;season<-(1+cos(2*pi*(doy-15)/365))/2;p01<-pmin(0.9,(0.010+p01b*season^1.5)*occ);p11<-pmin(0.95,0.15+p11b*season^1.5);wet<-logical(ndays);for(t in 2:ndays)wet[t]<-runif(1)<(if(wet[t-1])p11[t] else p01[t]);scale<-4+scaleb*season;rain<-numeric(ndays);rain[wet]<-rgamma(sum(wet),shape=shape,scale=scale[wet]);rain[rain<0.1]<-0;round(rain,2)}
args<-commandArgs(trailingOnly=TRUE); SCEN<-if(length(args)>=1) args[1] else "semiarid"
scen<-list(semiarid=gen_rain(24), wet=gen_rain(11,occ=1.8,scaleb=16), drought=gen_rain(5,occ=0.18,scaleb=6))[[SCEN]]
SAT<-0.428;KSAT<-163.0411;NPSI<-6.57;A<-1;B<-8;DZ<-0.3;RESID<-1e-2
Kf<-function(th)KSAT*(pmax(th,0)/SAT)^(2*NPSI+3)
soil_h<-function(th){ lam<-max((2*NPSI+3)*Kf(th)/(pmax(th,1e-3)*DZ)); min(5e-3, 1.5/max(lam,1)) }
mk<-function(model,k=NULL){ p0<-scm_base_parameters(model); p0$max_patch_lifetime<-30
  p1<-add_strategies(p0, trait_matrix(0.0825,"lma")); if(!is.null(k)) p1$strategies[[1]]$k_acclim<-k
  env<-Environment("TF24"); env$extrinsic_drivers_set_variable("rainfall",0:(length(scen)-1),scen)
  h<-c(14,10,7,5,3.5,2.2,1.3,0.7); d<-c(0.015,0.03,0.06,0.12,0.25,0.6,1.5,4.0)
  st<-make_initial_state(p1,heights=h,densities=d,env=env,ctrl=Control())
  patch<-SCM(model,"TF24_Env")(set_initial_state(p1,st),env,Control())$patch
  ne<-patch$environment$ode_size; ns<-patch$ode_size; nn<-patch$node_ode_size
  list(patch=patch, si=(ns-ne+1):(ns-ne+5), qidx=if(model=="TF24f"){nc<-nn/9;(0:(nc-1))*9+7}else integer(0), y=patch$ode_state) }
clampT<-function(th) pmin(pmax(th,RESID),SAT-1e-6)

Tend<-12L; daily<-0:Tend
# reference: TF24 QSS (re-optimise every micro-step); soil evolves by the real patch soil rate
runQSS<-function(){ M<-mk("TF24"); y<-M$y; th<-y[M$si]; sav<-matrix(NA,Tend+1,5); sav[1,]<-th; nd<-1L; t<-0; fe<-0L
  while(t<Tend-1e-9){ h<-min(soil_h(th),Tend-t,nd-t); y[M$si]<-th; d<-M$patch$derivs(y,t); fe<-fe+1L
    th<-clampT(th+h*d[M$si]); t<-t+h; if(abs(t-nd)<1e-9){ sav[nd+1,]<-th; nd<-nd+1L } }
  list(theta=sav, evals=fe) }
# tracked: TF24f; spin q to optimum at theta0, then co-evolve theta + q with the real patch rates
# (theta and q both advanced from the single derivs call at the pre-step state)
# clamp the tracked q into the feasible interval (below psi_crit) - the clamp/event handling the
# scheme specifies; a freely-evolving q can otherwise overshoot the leaf solve's solvable domain.
QLO<-1e-2; QHI<-3.2
runTrk<-function(k){ M<-mk("TF24f",k); y<-M$y
  for(s in 1:3000){ d<-M$patch$derivs(y,0); y[M$qidx]<-pmin(pmax(y[M$qidx]+0.001*d[M$qidx],QLO),QHI) } # spin-up
  th<-y[M$si]; sav<-matrix(NA,Tend+1,5); sav[1,]<-th; nd<-1L; t<-0; fe<-0L
  while(t<Tend-1e-9){ h<-min(soil_h(th),Tend-t,nd-t); y[M$si]<-th; d<-M$patch$derivs(y,t); fe<-fe+1L
    th<-clampT(th+h*d[M$si]); y[M$qidx]<-pmin(pmax(y[M$qidx]+h*d[M$qidx],QLO),QHI); t<-t+h
    if(abs(t-nd)<1e-9){ sav[nd+1,]<-th; nd<-nd+1L } }
  list(theta=sav, evals=fe) }

cat(sprintf("Scenario %s (%.0f mm/yr), window %d d. TF24 QSS (re-optimise) vs TF24f tracked-q (k-sweep).\n",
    SCEN, sum(scen), Tend))
qss<-runQSS()
cat(sprintf("QSS reference: %d soil steps. Final theta = %s\n\n", qss$evals, paste(sprintf('%.4f',qss$theta[Tend+1,]),collapse=",")))
cat(sprintf("%8s | %10s %10s | %8s\n","k_acclim","max|dθ|","rms|dθ|","steps"))
for(k in c(5,20,100,1000)){
  r<-runTrk(k); err<-abs(r$theta-qss$theta)
  cat(sprintf("%8.0f | %10.2e %10.2e | %8d\n", k, max(err,na.rm=TRUE), sqrt(mean(err^2,na.rm=TRUE)), r$evals))
}
cat("\nSmall max|dθ| at moderate k => tracked-q (TF24f, EVALUATE) reproduces the QSS/global soil\n")
cat("trajectory with no plateau; larger k -> tighter tracking but stiffer q-ODE. Sets k for #2.\n")
