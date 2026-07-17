#!/usr/bin/env Rscript
# T1 (Oracle reformulation-response, "decides everything"): Osgood reachability of the lower bound.
# The near-bound difficulty is one mechanism (a scarcity-driven sink) wearing three hats; which CHART fixes
# the singularity/clamp depends on whether the continuous trajectory can actually CONTACT theta_res under
# worst-case (zero-inflow) drying.
#   S(theta) = total sink from a layer = drainage K(theta) + root uptake a(theta).  Under r=0: dtheta/dt =
#   -S(theta)/dz.  Time to reach the bound tau = integral_{theta_res}^{theta0} dz*dtheta/S(theta).
#     diverges -> Case A: bound UNREACHABLE (uptake shuts off above theta_res; S~K~theta^16). Chart = LOG-
#                 depletion zeta=ln(theta-theta_res): deletes the clamp, the psi floor, the significand loss.
#     converges -> Case B: contact REAL. Chart = power z=(theta-theta_res)^(1-gamma); touchdown = an event.
# Also: gamma-1 = slope of d(uptake)/dtheta on log-log (Oracle: already in our data); T4 = eigen-realness of
# the soil-block Jacobian (licenses forward-substitution Rosenbrock, certifies no oscillatory stiffness).
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE)); options(width=125)

SAT<-0.428; KSAT<-163.0411; NPSI<-6.57; DZ<-0.3; RESID<-1e-2; P<-2*NPSI+3
Kf<-function(th) KSAT*(pmax(th,1e-12)/SAT)^P
p0<-scm_base_parameters("TF24"); p0$max_patch_lifetime<-30
p1<-add_strategies(p0, trait_matrix(0.0825,"lma"))
# frozen real stand; ZERO inflow (worst-case r=0 drying, as the Osgood test specifies)
env<-Environment("TF24"); env$extrinsic_drivers_set_variable("rainfall",0:364,rep(0,365))
H<-c(14,10,7,5,3.5,2.2,1.3,0.7); D<-c(0.015,0.03,0.06,0.12,0.25,0.6,1.5,4.0)
st<-make_initial_state(p1,heights=H,densities=D,env=env,ctrl=Control())
patch<-SCM("TF24","TF24_Env")(set_initial_state(p1,st),env,Control())$patch
patch$compute_environment()
ne<-patch$environment$ode_size; ns<-patch$ode_size; si<-(ns-ne+1):(ns-ne+5)
# per-layer uptake at UNIFORM theta, zero inflow: rate_i=(win_i-K-uptake_i)/dz, win_0=0, win_{i>0}=K(theta)
# => uptake_0 = -K - dz*rate_0 ;  uptake_{i>0} = -dz*rate_i ;  sink S_i = K + uptake_i
soil_rate<-function(th){ y<-patch$ode_state; y[si]<-pmin(pmax(th,1e-6),SAT-1e-6); patch$derivs(y,0)[si] }
uptake_layers<-function(theta){ th<-rep(theta,5); r<-soil_rate(th); K<-Kf(theta)
  up<-numeric(5); up[1]<- -K - DZ*r[1]; for(i in 2:5) up[i]<- -DZ*r[i]; pmax(up,0) }

cat("Frozen stand, ZERO inflow. Sweep theta -> theta_res=0.01. Sink S = drainage K + uptake a (per layer).\n")
cat("uptake backed out of the real patch derivs; representative = layer 3 (mid-column, active roots).\n\n")
grid <- RESID + 10^seq(log10(0.34-RESID), log10(2e-4), length.out=26)   # log grid in delta=theta-theta_res
LAY<-3
cat(sprintf("%9s %10s | %11s %11s %11s | %11s\n","theta","delta","K(drain)","uptake_L3","S_L3","d(uptake)/dth"))
th_v<-c(); S_v<-c(); up_v<-c(); dup_v<-c()
for(theta in grid){
  up<-tryCatch(uptake_layers(theta), error=function(e) rep(NA,5))
  K<-Kf(theta); S<-K+up[LAY]
  # FD of layer-3 uptake wrt theta
  d<-1e-4; um<-tryCatch(uptake_layers(theta-d)[LAY],error=function(e)NA); upp<-tryCatch(uptake_layers(theta+d)[LAY],error=function(e)NA)
  dup<-(upp-um)/(2*d)
  cat(sprintf("%9.5f %10.2e | %11.4e %11.4e %11.4e | %11.3e\n", theta, theta-RESID, K, up[LAY], S, dup))
  th_v<-c(th_v,theta); S_v<-c(S_v,S); up_v<-c(up_v,up[LAY]); dup_v<-c(dup_v,dup)
}

# locate uptake shutoff (theta where uptake falls to ~1% of its peak)
pk<-max(up_v,na.rm=TRUE); shut<-th_v[which(up_v < 0.01*pk & th_v < 0.15)]
cat(sprintf("\nuptake peak=%.3e ; falls below 1%% of peak at theta ~ %.4f (bound theta_res=%.3f)\n",
    pk, if(length(shut)) max(shut) else NA, RESID))

# fit near-bound exponent of the TOTAL sink S ~ delta^gammaS  (last ~8 points before the bound)
delta<-th_v-RESID; ok<-is.finite(S_v)&S_v>0; n<-sum(ok); idx<-tail(which(ok),8)
gS<-coef(lm(log(S_v[idx])~log(delta[idx])))[2]
# gamma-1 from d(uptake)/dtheta divergence (active regime, where uptake>0): slope on log-log
oka<-is.finite(dup_v)&dup_v>0&up_v>0.05*pk; ga1<-if(sum(oka)>=3) coef(lm(log(dup_v[oka])~log(delta[oka])))[2] else NA
cat(sprintf("near-bound total-sink exponent  gammaS = dlnS/dln(delta) ~ %.2f  (S~delta^gammaS)\n", gS))
cat(sprintf("uptake-feedback exponent        gamma-1 = dln(da/dth)/dln(delta) ~ %.2f  => gamma ~ %.2f\n", ga1, ga1+1))

# Osgood integral tau(theta_low) = int_{theta_low}^{theta0} dz*dtheta/S : does it diverge as theta_low->theta_res?
cat("\nOsgood: cumulative drain-time tau from theta0=0.30 down to theta_low (dz*dtheta/S). Diverges => Case A.\n")
gi<-order(th_v); ts<-th_v[gi]; Ss<-S_v[gi]
cat(sprintf("%10s | %12s\n","theta_low","tau (d)"))
for(tl in c(0.15,0.08,0.05,0.03,0.02,0.015,0.011)){
  sel<-ts>=tl & ts<=0.30 & is.finite(Ss)
  if(sum(sel)>=2){ x<-ts[sel]; y<-DZ/Ss[sel]; tau<-sum(diff(x)*(head(y,-1)+tail(y,-1))/2)
    cat(sprintf("%10.3f | %12.4g\n", tl, tau)) }
}

# T4: eigen-realness of the soil-block Jacobian, active stress regime AND floor regime
cat("\nT4: soil-block Jacobian eigenvalues (active stress regime theta=0.13, and floor regime theta=0.02).\n")
Jac<-function(th,dh=1e-6){ n<-length(th); J<-matrix(0,n,n); f0<-soil_rate(th); for(j in 1:n){tp<-th;tp[j]<-tp[j]+dh;J[,j]<-(soil_rate(tp)-f0)/dh}; J }
for(tv in c(0.13,0.02)){ ev<-eigen(Jac(rep(tv,5)),only.values=TRUE)$values
  mre<-max(abs(Re(ev))); mim<-max(abs(Im(ev))); rr<-if(mre>1e-14) mim/mre else NA
  cat(sprintf("  theta=%.2f eigs: %s\n", tv, paste(sprintf('%.3g%+.3gi',Re(ev),Im(ev)),collapse=", ")))
  cat(sprintf("           max|Re|=%.3g max|Im|=%.3g  %s\n", mre, mim,
      if(is.na(rr)) "Jacobian ~ 0 (clamped/floored: no stiffness AND no gradient here)"
      else if(rr<1e-3) "REAL spectrum: no oscillatory stiffness, forward-subst Rosenbrock OK" else "complex present")) }

cat("\nVERDICT: see reading in oracle-consultation-reformulation-response.md.\n")
