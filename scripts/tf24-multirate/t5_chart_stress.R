#!/usr/bin/env Rscript
# T5 (verification, self-contained): stress the log-depletion chart on the cases T2 did NOT exercise.
#   V1 differential depletion: a near-floor layer directly under a WET layer -> big cascade inflow
#       K(theta_above)/(theta-theta_res) : does zeta+Rosenbrock stay stable/accurate?
#   V2 fast rewetting from the floor + a forcing kink: dzeta/dt = inflow/e^zeta blows up as zeta->-inf,
#       so the log chart may SINGULARIZE rewetting (the flip side of desingularizing drying). And a micro
#       step must not straddle a rainfall kink (the "two clocks" footgun). Aligned vs straddling steps.
# Same faithful smooth-shutoff soil block as T2.
options(width=120)
SAT<-0.428; KSAT<-163.0411; DZmm<-300; RESID<-1e-2; P<-2*6.57+3; Q<-6.57; APSI<-1.78e3; L<-5
# physical units: fluxes are mm/day, converted to theta/day by /dz_mm. cc*theta^P = drainage theta-rate.
cc<-KSAT/(DZmm*SAT^P); psi<-function(th) APSI*(pmax(th,RESID)/SAT)^(-Q)/1e6
PSI50<-3.0; SH<-4.0; URATE<-0.06; rootf<-c(0.30,0.28,0.22,0.13,0.07)   # URATE = peak uptake theta/day
beta<-function(th) 1/(1+(psi(th)/PSI50)^SH)
frhs<-function(th,t,rainf){ th<-pmax(th,RESID); K<-cc*th^P
  infil<-rainf(t)/DZmm*max(0,1-(th[1]/SAT)^8); win<-c(infil, K[-L]); win - K - URATE*beta(th)*rootf }
rk4<-function(y,t,h,f){k1<-f(y,t);k2<-f(y+h/2*k1,t+h/2);k3<-f(y+h/2*k2,t+h/2);k4<-f(y+h*k3,t+h);y+h/6*(k1+2*k2+2*k3+k4)}
th_of<-function(z) RESID+exp(z)
fz<-function(z,t,rainf){ th<-th_of(z); frhs(th,t,rainf)/(th-RESID) }
Jz<-function(z,t,rainf,dh=1e-6){n<-length(z);J<-matrix(0,n,n);f0<-fz(z,t,rainf);for(j in 1:n){zp<-z;zp[j]<-zp[j]+dh;J[,j]<-(fz(zp,t,rainf)-f0)/dh};J}
ros2<-function(z,t,h,rainf){g<-1+1/sqrt(2);A<-diag(length(z))-g*h*Jz(z,t,rainf);k1<-solve(A,h*fz(z,t,rainf));k2<-solve(A,h*fz(z+k1,t+h,rainf)-2*k1);z+1.5*k1+0.5*k2}
reftheta<-function(y0,T,rainf,h=1e-4){th<-y0;t<-0;while(t<T-1e-12){hh<-min(h,T-t);th<-pmax(rk4(th,t,hh,function(y,tt)frhs(y,tt,rainf)),RESID);t<-t+hh};th}
# zeta ROS2 with an optional set of mandatory breakpoints (kink alignment)
runZ<-function(y0,T,rainf,H,breaks=numeric(0)){ z<-log(pmax(y0-RESID,1e-12));t<-0;n<-0L;maxrate<-0
  while(t<T-1e-9){ h<-min(H,T-t); nb<-breaks[breaks>t+1e-12]; if(length(nb))h<-min(h,min(nb)-t)
    maxrate<-max(maxrate,max(abs(fz(z,t,rainf)))); z<-ros2(z,t,h,rainf); if(any(!is.finite(z)))return(list(th=rep(NA,L),n=n,mr=NA)); t<-t+h;n<-n+1L}
  list(th=th_of(z),n=n,mr=maxrate) }

cat("=== V1: differential depletion (near-floor layer under a WET layer; r=0) ===\n")
norain<-function(t)0
for(lab in c("alt wet/near-floor","wet-over-dry stack")){
  y0<-if(lab=="alt wet/near-floor") c(0.42,0.012,0.42,0.012,0.42) else c(0.42,0.34,0.22,0.05,0.012)
  rf<-reftheta(y0,3,norain); z<-runZ(y0,3,norain,0.1)
  cat(sprintf("  %-20s init=%s\n     ref final=%s\n     zeta+ROS2 (H=0.1): %d steps, max|dζ/dt|=%.1f, max|dθ| vs ref=%.2e\n",
      lab, paste(sprintf('%.3f',y0),collapse=","), paste(sprintf('%.4f',rf),collapse=","), z$n, z$mr, max(abs(z$th-rf)))) }

cat("\n=== V2: fast rewetting from the floor + forcing kink (storm on dry soil) ===\n")
storm<-function(t) if(t>=1 && t<1.4) 45 else 0            # a hard rainfall kink at t=1 and t=1.4
y0<-rep(0.03,L)                                            # start near the floor
rf<-reftheta(y0,3,storm)
cat(sprintf("start theta=0.03 (near floor); storm 45mm/d on [1,1.4]. ref final theta=%s\n", paste(sprintf('%.4f',rf),collapse=",")))
# theta-chart explicit baseline (stability-limited) -- rewetting is EASY in theta
stepA<-function(th){K<-cc*pmax(th,RESID)^P; min(5e-3,1.5/max(max(P*K/pmax(th,RESID)),1))}
runA<-function(y0,T,rainf){th<-y0;t<-0;n<-0L; while(t<T-1e-9){h<-min(stepA(th),T-t);th<-pmax(rk4(th,t,h,function(y,tt)frhs(y,tt,rainf)),RESID);t<-t+h;n<-n+1L}; list(th=th,n=n)}
a<-runA(y0,3,storm)
cat(sprintf("  theta explicit (baseline): %d steps, max|dθ| vs ref=%.2e   <- rewetting is easy in theta\n", a$n, max(abs(a$th-rf))))
cat(sprintf("  %-28s | %6s | %10s | %10s\n","zeta ROS2 (kink-aligned)","steps","max|dζ/dt|","max|dθ|"))
for(H in c(0.2,0.1,0.05,0.02,0.01,0.005,0.002)){
  za<-runZ(y0,3,storm,H,breaks=c(1,1.4))
  cat(sprintf("  H=%.3f                       | %6s | %10s | %10s\n", H, ifelse(is.na(za$n),"NA",za$n),
      ifelse(is.na(za$mr),"NA",sprintf('%.0f',za$mr)), ifelse(is.finite(max(abs(za$th-rf))),sprintf('%.2e',max(abs(za$th-rf))),"NA"))) }
cat("  (kink-straddling, H=0.05, no breakpoints): "); zs<-runZ(y0,3,storm,0.05)
cat(sprintf("%s\n", ifelse(is.na(zs$n)||!is.finite(max(abs(zs$th-rf))),"NA/blow-up",sprintf('%d steps, max|dθ|=%.2e',zs$n,max(abs(zs$th-rf))))))
cat("\nWatch: (V1) does zeta+ROS2 survive big cascade inflow into a floor layer? (V2) rewetting drives\n")
cat("|dζ/dt| large (inflow/e^zeta) -> the chart singularizes rewetting; and straddling the rain kink\n")
cat("loses accuracy/order vs aligned. Decides: one chart everywhere, or theta for wetting / zeta for drying.\n")
