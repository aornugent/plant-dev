#!/usr/bin/env Rscript
# R1 payoff (reformulation exploration): the gating measurement the reformulations-evaluation flagged
# but did not run. Gravitational drainage water_out_i = K(theta_i) = K_sat*(theta_i/theta_sat)^p (p=2n+3
# ~ 16.14) is the wet-end stiffness whose Jacobian dK/dtheta = p*K/theta forces the current
# stability-limited explicit step (and Rosenbrock-W). R1 = Strang-split it out and integrate the diagonal
# drainage EXACTLY (closed-form recession theta(t) = [theta0^(1-p) + (p-1) c t]^(-1/(p-1))), leaving the
# GENTLE part (infiltration + downward cascade + root uptake) for the coupling substep.
# Two questions, on a REAL stand + real uptake:
#   (A) how much of the soil Jacobian's spectral radius is the diagonal drainage (removed by R1)?
#   (B) end-to-end: current explicit step count vs R1-split step count at matched accuracy = enlargement.
# and: after removing drainage, is the remainder nonstiff enough to step EXPLICITLY (retire Rosenbrock-W
# for the common case)?
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE)); options(width=120)

gen_rain<-function(seed,ndays=365,p01b=0.09,p11b=0.38,shape=0.6,scaleb=11,occ=1){set.seed(seed);doy<-(seq_len(ndays)-1)%%365;season<-(1+cos(2*pi*(doy-15)/365))/2;p01<-pmin(0.9,(0.010+p01b*season^1.5)*occ);p11<-pmin(0.95,0.15+p11b*season^1.5);wet<-logical(ndays);for(t in 2:ndays)wet[t]<-runif(1)<(if(wet[t-1])p11[t] else p01[t]);scale<-4+scaleb*season;rain<-numeric(ndays);rain[wet]<-rgamma(sum(wet),shape=shape,scale=scale[wet]);rain[rain<0.1]<-0;round(rain,2)}
SCEN<-{a<-commandArgs(trailingOnly=TRUE); if(length(a)>=1) a[1] else "semiarid"}
scen<-list(semiarid=gen_rain(24), wet=gen_rain(11,occ=1.8,scaleb=16))[[SCEN]]
SAT<-0.428;KSAT<-163.0411;NPSI<-6.57;DZ<-0.3;RESID<-1e-2;P<-2*NPSI+3
Kf<-function(th)KSAT*(pmax(th,1e-6)/SAT)^P               # drainage flux K(theta)  (mm/day equiv in theta-units)
cc <- KSAT/(DZ*SAT^P)                                    # dtheta/dt|_drain = -cc*theta^P
drain_exact<-function(th0,t) (pmax(th0,1e-9)^(1-P) + (P-1)*cc*t)^(-1/(P-1))   # closed-form recession

# real frozen stand + soil indices (as e2_e3)
p0<-scm_base_parameters("TF24"); p0$max_patch_lifetime<-30
p1<-add_strategies(p0, trait_matrix(0.0825,"lma"))
env<-Environment("TF24"); env$extrinsic_drivers_set_variable("rainfall",0:(length(scen)-1),scen)
H<-c(14,10,7,5,3.5,2.2,1.3,0.7); D<-c(0.015,0.03,0.06,0.12,0.25,0.6,1.5,4.0)
st<-make_initial_state(p1,heights=H,densities=D,env=env,ctrl=Control())
patch<-SCM("TF24","TF24_Env")(set_initial_state(p1,st),env,Control())$patch
ne<-patch$environment$ode_size; ns<-patch$ode_size; si<-(ns-ne+1):(ns-ne+5)
clampT<-function(th) pmin(pmax(th,RESID),SAT-1e-6)
soil_rate<-function(th,t){ y<-patch$ode_state; y[si]<-clampT(th); patch$derivs(y,t)[si] } # full: infil+cascade-drain-uptake
# remainder rate = full - (diagonal drainage loss).  diagonal drainage loss_i = -K(theta_i)/DZ
rem_rate <-function(th,t){ soil_rate(th,t) + Kf(th)/DZ }   # add back the drainage we integrate exactly
# hydrology-only (NO uptake), analytic: infiltration into layer 0, downward cascade, drainage loss
env_rain<-function(t) patch$environment$extrinsic_drivers_evaluate("rainfall",t)
hydro_rate<-function(th,t){ n<-length(th); r<-numeric(n); K<-Kf(th)
  infil<-env_rain(t)*max(0,1-1*(th[1]/SAT)^8); win<-c(infil,K[-n])
  (win - K)/DZ }

# ---- (A) stiffness decomposition along a real episode ----
epis<-seq(0,10,by=0.25)
th<-rep(0.30,5); traj<-list()
# generate a realistic theta episode with the current explicit stepper
soil_h<-function(th){ lam<-max((2*NPSI+3)*Kf(th)/(pmax(th,1e-3)*DZ)); min(5e-3, 1.5/max(lam,1)) }
t<-0; rec<-list(); k<-1
while(t<10-1e-9){ h<-soil_h(th); th<-clampT(th+h*soil_rate(th,t)); t<-t+h
  if(k%%50==0) rec[[length(rec)+1]]<-c(t=t,th); k<-k+1 }
cat(sprintf("Scenario %s. Stiffness decomposition on a real theta episode (%d sampled states).\n\n",SCEN,length(rec)))
jac_spec<-function(f,th,t,dh=1e-5){ n<-length(th); J<-matrix(0,n,n); f0<-f(th,t)
  for(j in 1:n){ tp<-th; tp[j]<-tp[j]+dh; J[,j]<-(f(tp,t)-f0)/dh }; max(abs(eigen(J,only.values=TRUE)$values)) }
cat("|J_full| = real soil Jacobian (incl. uptake); |J_hydro| = drainage+cascade+infil only (no uptake);\n")
cat("|J_rem| = full minus exact diagonal drainage (what R1's remainder stepper faces).\n\n")
cat(sprintf("%6s | %8s | %10s %10s %10s | %12s %10s\n","t","min th","|J_full|","|J_hydro|","|J_rem|","uptake/hydro","drain dK/dth"))
for(r in rec){ t<-r["t"]; thv<-r[2:6]
  Jf<-jac_spec(soil_rate,thv,t); Jh<-jac_spec(hydro_rate,thv,t); Jr<-jac_spec(rem_rate,thv,t)
  jdr<-max(P*Kf(thv)/(pmax(thv,1e-3)*DZ))
  cat(sprintf("%6.2f | %8.4f | %10.4g %10.4g %10.4g | %12.1f %10.4g\n", t, min(thv), Jf, Jh, Jr, Jf/max(Jh,1e-30), jdr)) }

# ---- (B) end-to-end: current explicit vs R1 Strang-split, matched accuracy ----
cat("\n--- (B) end-to-end soil integration over 10 d: steps & accuracy ---\n")
# tight reference: full RHS, tiny fixed RK4
rk4<-function(th,t,h,f){ k1<-f(th,t);k2<-f(th+h/2*k1,t+h/2);k3<-f(th+h/2*k2,t+h/2);k4<-f(th+h*k3,t+h); th+h/6*(k1+2*k2+2*k3+k4) }
ref<-function(){ th<-rep(0.30,5);t<-0;h<-2e-4; while(t<10-1e-12){hh<-min(h,10-t); th<-clampT(rk4(th,t,hh,soil_rate)); t<-t+hh}; th }
th_ref<-ref()
# current explicit: stability-limited step on full RHS (RK4 for fair accuracy comparison)
cur<-function(){ th<-rep(0.30,5);t<-0;n<-0L; while(t<10-1e-9){h<-soil_h(th);hh<-min(h,10-t); th<-clampT(rk4(th,t,hh,soil_rate));t<-t+hh;n<-n+1L}; list(th=th,n=n) }
# R1 Strang: exact drainage half-step (closed form), explicit RK4 remainder full step, exact drainage half-step
strang<-function(H){ th<-rep(0.30,5);t<-0;n<-0L; while(t<10-1e-9){hh<-min(H,10-t)
  th<-drain_exact(th,hh/2); th<-clampT(rk4(th,t+hh/2,hh,rem_rate)); th<-drain_exact(th,hh/2); th<-clampT(th); t<-t+hh; n<-n+1L}; list(th=th,n=n) }
cc0<-cur(); cerr<-max(abs(cc0$th-th_ref))
cat(sprintf("reference (RK4 h=2e-4). current explicit (stability-limited): %d steps, max|dθ|=%.2e\n\n",cc0$n,cerr))
cat(sprintf("%10s | %8s | %10s | %s\n","R1 step H","steps","max|dθ|","note"))
for(H in c(0.02,0.05,0.1,0.2,0.5,1.0)){ s<-strang(H); e<-max(abs(s$th-th_ref))
  cat(sprintf("%10.3f | %8d | %10.2e | %s\n",H,s$n,e, if(e<cerr*3) "<= current accuracy" else "")) }
cat("\nRatio (current steps)/(R1 steps at matched accuracy) = the step enlargement R1 buys.\n")
cat("If |J_remain| << |J_full| and h*|J_remain| < ~2.5 at the accuracy-limited H, the remainder steps\n")
cat("EXPLICITLY -> Rosenbrock-W retires for the common case (kept only for the near-bound uptake passage).\n")
