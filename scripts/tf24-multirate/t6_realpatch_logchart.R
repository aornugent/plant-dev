#!/usr/bin/env Rscript
# T6 (verification, probe 3): the log-depletion chart on the REAL TF24 patch coupling.
# Integrate the 5 real soil states in zeta=ln(theta-theta_res) using the REAL patch$derivs soil rate
# (real per-cohort uptake with the production vulnerability curve + psi_crit pin, real drainage/cascade),
# stepped by a zeta-Rosenbrock, vs the real soil rate integrated in theta at tight tolerance. Two questions:
#   (a) does R-D (the chart) compose with the real coupling -- stable, accurate?
#   (b) is the real aggregate uptake SMOOTH in zeta, or does the production pin/clamp put a KINK/FLAT in it
#       (the dead-gradient zone found in T1)? -> shows whether R-C (the C++ smooth shutoff) is a prerequisite.
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE)); options(width=120)
SAT<-0.428; KSAT<-163.0411; DZmm<-300; RESID<-1e-2; P<-2*6.57+3; Q<-6.57; APSI<-1.78e3; L<-5
psi<-function(th) APSI*(pmax(th,RESID)/SAT)^(-Q)/1e6
p0<-scm_base_parameters("TF24"); p0$max_patch_lifetime<-30
p1<-add_strategies(p0, trait_matrix(0.0825,"lma"))
env<-Environment("TF24"); env$extrinsic_drivers_set_variable("rainfall",0:364,rep(0,365))   # r=0 dry-down
H<-c(14,10,7,5,3.5,2.2,1.3,0.7); D<-c(0.015,0.03,0.06,0.12,0.25,0.6,1.5,4.0)
st<-make_initial_state(p1,heights=H,densities=D,env=env,ctrl=Control())
patch<-SCM("TF24","TF24_Env")(set_initial_state(p1,st),env,Control())$patch; patch$compute_environment()
ne<-patch$environment$ode_size; ns<-patch$ode_size; si<-(ns-ne+1):(ns-ne+5)
clampT<-function(th) pmin(pmax(th,RESID+1e-5),SAT-1e-3)
soil_rate<-function(th){ y<-patch$ode_state; y[si]<-clampT(th)
  r<-tryCatch(patch$derivs(y,0)[si], error=function(e) rep(NA_real_,5)); r[!is.finite(r)]<-0; r }   # REAL soil rate, guarded

# (b) is the real aggregate uptake smooth in zeta? back out per-layer uptake at uniform theta (r=0):
#     uptake_i = win_i - K - dz*rate_i ; win_0=0, win_{i>0}=K(theta) ; sink S_i=K+uptake_i.
cc<-KSAT/(DZmm*SAT^P); Kf<-function(th)KSAT*(pmax(th,1e-9)/SAT)^P
uptake_L3<-function(theta){ r<-soil_rate(rep(theta,5)); -DZmm/1000*r[3] }  # layer-3 uptake proxy (theta/day units aside)
cat("=== (b) real uptake vs the log-depletion coordinate: is it smooth, or does the pin flatten it? ===\n")
cat(sprintf("%8s %9s %11s %13s\n","theta","zeta","uptake_L3","d(uptake)/dzeta"))
zs<-c(); us<-c()
for(theta in c(0.20,0.16,0.14,0.13,0.12,0.115,0.11,0.09,0.06,0.03)){
  u<-uptake_L3(theta); z<-log(theta-RESID); zs<-c(zs,z); us<-c(us,u)
  d<-1e-3; du<-(uptake_L3(theta*(1+d))-uptake_L3(theta*(1-d)))/(log(theta*(1+d)-RESID)-log(theta*(1-d)-RESID))
  cat(sprintf("%8.3f %9.3f %11.4e %13.3e\n", theta, z, u, du)) }
cat("  -> a FLAT (d(uptake)/dzeta ~ 0) below theta~0.11 is the production pin's dead zone, now visible in zeta:\n")
cat("     the chart cannot smooth what the coupling zeroed; R-C (C++ smooth shutoff) is the prerequisite.\n\n")

# (a) integrate the real soil block: theta-explicit tight ref vs zeta-Rosenbrock
rk4<-function(y,h,f){k1<-f(y);k2<-f(y+h/2*k1);k3<-f(y+h/2*k2);k4<-f(y+h*k3);y+h/6*(k1+2*k2+2*k3+k4)}
th0<-rep(0.22,L); Tend<-8
reftheta<-function(){th<-th0;t<-0;h<-5e-4;while(t<Tend-1e-12){hh<-min(h,Tend-t);th<-clampT(rk4(th,hh,soil_rate));t<-t+hh};th}
rf<-reftheta()
th_of<-function(z) RESID+exp(z)
fz<-function(z){ th<-th_of(z); soil_rate(th)/(th-RESID) }
Jz<-function(z,dh=1e-5){n<-length(z);J<-matrix(0,n,n);f0<-fz(z);for(j in 1:n){zp<-z;zp[j]<-zp[j]+dh;J[,j]<-(fz(zp)-f0)/dh};J}
ros2<-function(z,h){g<-1+1/sqrt(2);A<-diag(length(z))-g*h*Jz(z);k1<-solve(A,h*fz(z));k2<-solve(A,h*fz(z+k1)-2*k1);z+1.5*k1+0.5*k2}
zclamp<-function(z) pmin(pmax(z, log(1e-4)), log(SAT-RESID-1e-3))
runZ<-function(Hh){z<-log(th0-RESID);t<-0;n<-0L;while(t<Tend-1e-9){h<-min(Hh,Tend-t)
  zn<-tryCatch(ros2(z,h),error=function(e)rep(NA,L)); if(any(!is.finite(zn)))return(list(th=rep(NA,L),n=n)); z<-zclamp(zn);t<-t+h;n<-n+1L};list(th=th_of(z),n=n)}
# theta-explicit stability-limited (the current scheme) for step-count reference
soil_h<-function(th){lam<-max((P)*Kf(th)/(pmax(th,1e-3)*DZmm)); min(5e-3,1.5/max(lam,1))}
runA<-function(){th<-th0;t<-0;n<-0L;while(t<Tend-1e-9){h<-min(soil_h(th),Tend-t);th<-clampT(rk4(th,h,soil_rate));t<-t+h;n<-n+1L};list(th=th,n=n)}
a<-runA()
cat(sprintf("=== (a) real soil block, dry-down theta0=0.22, T=%d d ===\n", Tend))
cat(sprintf("reference (theta RK4 h=5e-4) final theta = %s\n", paste(sprintf('%.4f',rf),collapse=",")))
cat(sprintf("theta explicit (current)  : %d steps, max|dθ| vs ref = %.2e\n", a$n, max(abs(a$th-rf))))
cat(sprintf("  %10s | %6s | %10s\n","zeta H","steps","max|dθ|"))
for(Hh in c(0.05,0.1,0.2,0.5)){ b<-runZ(Hh)
  cat(sprintf("  %10.3f | %6s | %10s %s\n",Hh, ifelse(is.na(b$n),"NA",b$n),
      ifelse(is.finite(max(abs(b$th-rf))),sprintf('%.2e',max(abs(b$th-rf))),"NA"),
      if(is.finite(max(abs(b$th-rf)))&&max(abs(b$th-rf))<3*max(abs(a$th-rf))+1e-4)"<= current accuracy" else "")) }
