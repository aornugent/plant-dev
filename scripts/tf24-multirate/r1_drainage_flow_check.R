# R1 check: TF24 gravitational drainage per layer is dθ/dt = -c θ^p (p=2n+3), a scalar power-law
# recession with a CLOSED-FORM flow θ(t)=[θ0^(1-p)+(p-1)c t]^(-1/(p-1)). Confirm (i) it matches a tight
# RK integration of the drainage-only ODE, (ii) it is positivity-preserving (never < 0 -> removes the
# clamp), (iii) it carries the wet-end stiffness the micro-stepper otherwise pays for.
SAT<-0.428; KSAT<-163.0411; NPSI<-6.57; DZ<-300; p<-2*NPSI+3           # dz in mm to match K units? use ratio form
c_ <- KSAT/(DZ*SAT^p)                                                  # dθ/dt = -c θ^p  (units consistent in θ)
exact<-function(th0,t) (th0^(1-p) + (p-1)*c_*t)^(-1/(p-1))
# tight RK4 reference of dθ/dt=-c θ^p
rk<-function(th0,T,h=1e-5){ th<-th0; t<-0; while(t<T-1e-12){ hh<-min(h,T-t)
  k1<--c_*th^p;k2<--c_*(th+hh/2*k1)^p;k3<--c_*(th+hh/2*k2)^p;k4<--c_*(th+hh*k3)^p
  th<-th+hh/6*(k1+2*k2+2*k3+k4); t<-t+hh }; th }
cat(sprintf("p=%.2f  c=%.3e   drainage Jacobian dK/dθ at θ=sat = %.0f /day\n", p, c_, p*c_*SAT^(p-1)))
cat(sprintf("%8s | %12s %12s %10s | %10s\n","θ0","exact(1d)","RK4(1d)","rel.err","min over 1d"))
for(th0 in c(0.42,0.30,0.20,0.12)){ te<-exact(th0,1); tr<-rk(th0,1)
  cat(sprintf("%8.3f | %12.6f %12.6f %10.1e | %10.6f\n", th0, te, tr, abs(te-tr)/tr, exact(th0,1))) }
cat("\nexact flow is positivity-preserving by construction (θ->0+ as t->inf, never negative);\n")
cat("it reproduces the stiff wet-end recession with ZERO truncation -> Strang-split it out and the\n")
cat("micro-stepper sees only the gentle infiltration-cascade + uptake coupling.\n")
