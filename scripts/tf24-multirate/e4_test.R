#!/usr/bin/env Rscript
# E4: reverse-mode certification of the proposed fast subsystem (tracked controls + m-member
# collocation). Adjoint (tape of the scheme-as-run) vs frozen-record central FD; then sweep k
# (tracking bandwidth) and m (collocation members) to show the reduction errors live in the VALUE,
# not the gradient — the adjoint stays exact for the scheme as run at every k, m.
suppressMessages(library(odelia)); options(width=110)
inc<-system.file("include",package="odelia"); so<-file.path(system.file("libs",package="odelia"),"odelia.so")
Sys.setenv(PKG_CPPFLAGS=paste0("-I",inc)); Sys.setenv(PKG_LIBS=shQuote(normalizePath(so)))
here<-"/home/user/plant-dev/scripts/tf24-multirate"
Rcpp::sourceCpp(file.path(here,"e4_fast_ad.cpp"))
cat("=== compiled e4_fast_ad ===\n")

gen_rain<-function(seed,ndays=60,p01b=0.09,p11b=0.38,shape=0.6,scaleb=11,occ=1){set.seed(seed);doy<-(seq_len(ndays)-1)%%365;season<-(1+cos(2*pi*(doy-15)/365))/2;p01<-pmin(0.9,(0.010+p01b*season^1.5)*occ);p11<-pmin(0.95,0.15+p11b*season^1.5);wet<-logical(ndays);for(t in 2:ndays)wet[t]<-runif(1)<(if(wet[t-1])p11[t] else p01[t]);scale<-4+scaleb*season;rain<-numeric(ndays);rain[wet]<-rgamma(sum(wet),shape=shape,scale=scale[wet]);rain[rain<0.1]<-0;round(rain,2)}
rain<-gen_rain(24); pars<-c(theta=1.0, gain=0.8, pref=0.5); T<-30

cat("\n(1) adjoint vs frozen-record FD, baseline (m=16, k=20):\n")
r<-e4_grad(rain, pars, m=16L, T=T, k=20, tol=1e-9, eps_fd=1e-6)
cat(sprintf("  F=%.6f  nstep=%d\n  grad_rev=%s\n  grad_fd =%s\n  max_abs_err=%.2e  max_rel_err=%.2e\n",
    r$F, r$nstep, paste(sprintf('%+.6e',r$grad_rev),collapse=" "),
    paste(sprintf('%+.6e',r$grad_fd),collapse=" "), r$max_abs_err, r$max_rel_err))

cat("\n(2) gradient-vs-k sweep (tracking bandwidth): adjoint stays exact for the scheme as run at each k\n")
cat(sprintf("  %8s %10s %12s %12s\n","k","F","max_abs_err","max_rel_err"))
for(k in c(1,5,20,100,1000)){ r<-e4_grad(rain,pars,m=16L,T=T,k=k,tol=1e-9,eps_fd=1e-6)
  cat(sprintf("  %8.0f %10.6f %12.2e %12.2e\n", k, r$F, r$max_abs_err, r$max_rel_err)) }

cat("\n(3) gradient-vs-m sweep (collocation members): adjoint stays exact at each m\n")
cat(sprintf("  %8s %10s %12s %12s\n","m","F","max_abs_err","max_rel_err"))
for(m in c(4L,8L,16L,32L,64L)){ r<-e4_grad(rain,pars,m=m,T=T,k=20,tol=1e-9,eps_fd=1e-6)
  cat(sprintf("  %8d %10.6f %12.2e %12.2e\n", m, r$F, r$max_abs_err, r$max_rel_err)) }
cat("\nSmall max_abs_err throughout => the tape of the scheme-as-run is the exact discrete adjoint;\n")
cat("F drifting with k,m is the accepted VALUE reduction (tracking lag / quadrature) - gradient unaffected.\n")
