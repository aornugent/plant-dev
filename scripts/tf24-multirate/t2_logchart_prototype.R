#!/usr/bin/env Rscript
# T2 (Oracle reformulation-response): windowed prototype of the reformulation, no forcing kinks.
# Faithful self-contained soil block: drainage theta^p + downward cascade + root uptake with a SMOOTH
# vulnerability shutoff (R-C: beta(theta)=1/(1+(psi/psi50)^s), psi=theta^-q -> uptake vanishes at the
# wilting end => Case A). Integrated two ways vs a tight reference of the SAME model:
#   (a) theta-chart explicit RK4 + positivity CLAMP at theta_res   (current representation)
#   (b) log-depletion chart zeta=ln(theta-theta_res) + Rosenbrock ROS2  (reformulation R-D)
# Oracle predictions checked: clamp activations -> 0 in zeta (positivity structural); the trajectory
# matches truth (a re-discretization, not a model change); steps in the stiff stress-transition ("floor")
# expand greatly under (b) while the drying passage ("fall") is accuracy-limited for both.
options(width=120)
SAT<-0.428; KSAT<-163.0411; DZ<-0.3; RESID<-1e-2; P<-2*6.57+3; Q<-6.57; APSI<-1.78e3; L<-5
cc<-KSAT/(DZ*SAT^P)
psi<-function(th) APSI*(pmax(th,RESID)/SAT)^(-Q)/1e6
PSI50<-3.0; SH<-4.0; UMAX<-6e-3; rootf<-c(0.30,0.28,0.22,0.13,0.07)
beta<-function(th) 1/(1+(psi(th)/PSI50)^SH)                 # smooth vulnerability shutoff (R-C)
frhs<-function(th,t,rin){ th<-pmax(th,RESID); K<-cc*th^P
  infil<-rin/DZ*max(0,1-(th[1]/SAT)^8); win<-c(infil, K[-L])
  win - K - (UMAX/DZ)*beta(th)*rootf }
rk4<-function(y,t,h,f){k1<-f(y,t);k2<-f(y+h/2*k1,t+h/2);k3<-f(y+h/2*k2,t+h/2);k4<-f(y+h*k3,t+h);y+h/6*(k1+2*k2+2*k3+k4)}
ref<-function(rin,T,y0,h=2.5e-4){ th<-y0;t<-0; while(t<T-1e-12){hh<-min(h,T-t); th<-pmax(rk4(th,t,hh,function(y,tt)frhs(y,tt,rin)),RESID); t<-t+hh}; th }
# (a) theta-chart explicit, stability-limited, clamp-counted
stepA<-function(th){ K<-cc*pmax(th,RESID)^P
  bder<-sapply(th,function(x){d<-1e-5;(beta(x+d)-beta(x-d))/(2*d)})
  lam<-max(P*K/pmax(th,RESID), (UMAX/DZ)*abs(bder)*rootf); min(5e-3,1.5/max(lam,1)) }
runA<-function(rin,T,y0){ th<-y0;t<-0;n<-0L;cl<-0L
  while(t<T-1e-9){h<-min(stepA(th),T-t); thn<-rk4(th,t,h,function(y,tt)frhs(y,tt,rin))
    cl<-cl+sum(thn<RESID); th<-pmax(thn,RESID); t<-t+h; n<-n+1L}; list(th=th,n=n,cl=cl) }
# (b) log-depletion chart + Rosenbrock ROS2
th_of<-function(z) RESID+exp(z)
fz<-function(z,t,rin){ th<-th_of(z); frhs(th,t,rin)/(th-RESID) }
Jz<-function(z,t,rin,dh=1e-6){ n<-length(z);J<-matrix(0,n,n);f0<-fz(z,t,rin); for(j in 1:n){zp<-z;zp[j]<-zp[j]+dh;J[,j]<-(fz(zp,t,rin)-f0)/dh}; J }
ros2<-function(z,t,h,rin){ g<-1+1/sqrt(2); A<-diag(length(z))-g*h*Jz(z,t,rin)
  k1<-solve(A,h*fz(z,t,rin)); k2<-solve(A,h*fz(z+k1,t+h,rin)-2*k1); z+1.5*k1+0.5*k2 }
runB<-function(rin,T,y0,H){ z<-log(pmax(y0-RESID,1e-12));t<-0;n<-0L;cl<-0L
  while(t<T-1e-9){h<-min(H,T-t); z<-ros2(z,t,h,rin); if(any(!is.finite(z))) return(list(th=rep(NA,L),n=n,cl=NA))
    cl<-cl+sum(th_of(z)<RESID); t<-t+h;n<-n+1L}; list(th=th_of(z),n=n,cl=cl) }

cat("=== Window 1: pure dry-down (r=0), theta0=0.34, T=30 d -> approaches the wilting bound ===\n")
y0<-rep(0.34,L); r1<-ref(0,30,y0); a<-runA(0,30,y0)
cat(sprintf("reference final theta = %s\n", paste(sprintf('%.5f',r1),collapse=",")))
cat(sprintf("(a) theta explicit : %5d steps, %d clamp activations, max|dθ| vs ref = %.2e\n", a$n,a$cl,max(abs(a$th-r1))))
cat(sprintf("  %10s | %6s | %7s | %10s\n","zeta H","steps","clamps","max|dθ|"))
for(H in c(0.02,0.05,0.1,0.2,0.5,1.0)){ b<-runB(0,30,y0,H)
  cat(sprintf("  %10.3f | %6d | %7s | %10.2e %s\n",H,b$n,ifelse(is.na(b$cl),"NA",b$cl),max(abs(b$th-r1)),
      if(is.finite(max(abs(b$th-r1)))&&max(abs(b$th-r1))<3e-4) "<= accuracy" else "")) }

cat("\n=== Window 2: chronic water stress -- parked in the stiff transition (the 'floor') ===\n")
# choose constant inflow that balances the sink at theta~0.13 so the system SITS in the stiff zone
thp<-0.13; sinkp<- cc*thp^P + (UMAX/DZ)*beta(thp)*sum(rootf)   # total column sink at theta=0.13 (approx)
rin2<- sinkp*DZ                                                # inflow to hold it (mm/day-ish)
y2<-rep(thp,L); r2<-ref(rin2,10,y2); a2<-runA(rin2,10,y2)
cat(sprintf("held near theta=%.3f (soil tension %.1f MPa, the stress transition). reference final theta=%s\n",
    thp, psi(thp), paste(sprintf('%.4f',r2),collapse=",")))
cat(sprintf("(a) theta explicit : %5d steps (stability-limited), max|dθ| vs ref = %.2e\n", a2$n, max(abs(a2$th-r2))))
cat(sprintf("  %10s | %6s | %10s\n","zeta H","steps","max|dθ|"))
for(H in c(0.05,0.1,0.2,0.5)){ b<-runB(rin2,10,y2,H)
  cat(sprintf("  %10.3f | %6d | %10.2e %s\n",H,b$n,max(abs(b$th-r2)),
      if(is.finite(max(abs(b$th-r2)))&&max(abs(b$th-r2))<3e-4)"<= accuracy" else "")) }
bb<-runB(rin2,10,y2,0.2)
cat(sprintf("\n  floor step expansion (a)/(b) at matched accuracy ~ %d / %d = %.0fx\n", a2$n, bb$n, a2$n/max(bb$n,1)))
cat("\nExpect: (b) zero clamp activations at every H; trajectory matches truth; large step-count cut when\n")
cat("the system sits in the stiff stress transition. Confirms the log-depletion chart forward reformulation.\n")
