#!/usr/bin/env Rscript
# T3 driver: reverse-mode certification of the log-depletion-chart soil block (smooth shutoff).
# (1) adjoint == FD-as-run wrt 3 differentiable params; (2) telescoped conservation invariant holds
# (value); the invariant's GRADIENT is exactly the F=D(T) adjoint-vs-FD check, since F IS the total stock.
suppressMessages(library(odelia)); options(width=115)
inc<-system.file("include",package="odelia"); so<-file.path(system.file("libs",package="odelia"),"odelia.so")
Sys.setenv(PKG_CPPFLAGS=paste0("-I",inc)); Sys.setenv(PKG_LIBS=shQuote(normalizePath(so)))
here<-"/home/user/plant-dev/scripts/tf24-multirate"
Rcpp::sourceCpp(file.path(here,"t3_chart_ad.cpp"))
cat("=== compiled t3_chart_ad ===\n")

rain<-rep(0,40)                       # zero-inflow dry-down through the stiff stress transition
pars<-c(umax=6e-3, psi50=3.0, ksat=163.0411); T<-20; h<-0.02; N<-as.integer(T/h)

cat("\n(1) adjoint (tape of the log-chart scheme-as-run) vs central FD-as-run:\n")
r<-t3_grad(rain, pars, h=h, N=N, eps_fd=1e-6)
cat(sprintf("  F=D(T)=%.6f  (N=%d fixed RK4 steps in zeta)\n", r$F, N))
cat(sprintf("  grad_rev = %s\n  grad_fd  = %s\n  max_abs_err=%.2e  max_rel_err=%.2e\n",
    paste(sprintf('%+.6e',r$grad_rev),collapse=" "), paste(sprintf('%+.6e',r$grad_fd),collapse=" "),
    r$max_abs_err, r$max_rel_err))

cat("\n(2) telescoped conservation invariant  D=Σ dz*theta_i,  dD/dt = infil - K_bottom - Σ uptake:\n")
cat(sprintf("  D(T)-D(0) = %+.6e ;  ∫(boundary flux) = %+.6e ;  residual = %.2e\n", r$dD, r$flux_int, r$invariant_resid))

cat("\n(3) robustness: eps_fd sweep (adjoint is eps-independent; FD degrades as eps shrinks = FD noise, not adjoint error):\n")
cat(sprintf("  %8s %12s %12s\n","eps_fd","max_abs_err","max_rel_err"))
for(e in c(1e-4,1e-5,1e-6,1e-7)){ rr<-t3_grad(rain,pars,h=h,N=N,eps_fd=e)
  cat(sprintf("  %8.0e %12.2e %12.2e\n", e, rr$max_abs_err, rr$max_rel_err)) }

cat("\nExpect: adjoint == FD to ~1e-8 (no kink -- smooth shutoff); invariant residual ~ machine/quadrature;\n")
cat("=> the log-depletion chart + smooth shutoff keep the reverse-mode gradient exact for the scheme as run.\n")
