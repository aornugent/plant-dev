#!/usr/bin/env Rscript
# Benchmark: does R-D (the log chart) help the IMPLICIT RODAS stepper, or does
# RODAS on the raw theta chart already handle the stiffness? Four arms:
#   theta+RKCK  theta+RODAS  zeta+RKCK  zeta+RODAS
# theta+RODAS is RODAS on the raw chart -- whose theta_of() carries the residual
# clamp branch, i.e. a derivative kink the forward-AD Jacobian must cross.
suppressMessages(library(odelia)); options(width=130)
inc <- system.file("include", package="odelia")
so  <- file.path(system.file("libs", package="odelia"), "odelia.so")
Sys.setenv(PKG_CPPFLAGS = paste0("-I", inc), PKG_LIBS = shQuote(normalizePath(so)))
Rcpp::sourceCpp("/home/user/plant-dev/scripts/tf24-multirate/rd_soil_runner.cpp")
cat("=== compiled rd_soil_runner (with theta+RODAS arm) ===\n\n")

cat("Stiff window: chronic stress near theta~0.13 (rin=1.0 mm/day), T=10 d. Sweep shutoff steepness sh.\n")
cat("steps [accuracy vs a tight zeta+RODAS reference]. Question: does theta+RODAS match zeta+RODAS,\n")
cat("or does the raw-chart clamp degrade the implicit stepper's step count / accuracy?\n\n")
cat(sprintf("%5s | %-16s | %-16s | %-16s | %-16s\n","sh","theta+RKCK","theta+RODAS","zeta+RKCK","zeta+RODAS"))
fmt <- function(r, ref){
  e <- if (any(!is.finite(r$theta))||any(!is.finite(ref$theta))) NA else max(abs(r$theta - ref$theta))
  sprintf("%5s [%s]", ifelse(r$n_steps<0 || r$n_steps>1e6,"FAIL",r$n_steps),
          ifelse(is.na(e),"NA",sprintf("%.0e",e)))
}
for (sh in c(60, 120, 250, 500, 1000, 2000)) {
  s <- rd_soil_compare(urate = 0.06, rin = 1.0, theta0 = 0.13, Tend = 10, tol = 1e-6, psi50 = 3.0, sh = sh)
  cat(sprintf("%5.0f | %-16s | %-16s | %-16s | %-16s   (ref %d st)\n", sh,
      fmt(s$theta_rkck, s$ref), fmt(s$theta_rodas, s$ref),
      fmt(s$zeta_rkck, s$ref), fmt(s$zeta_rodas, s$ref), s$ref$n_steps))
}
cat("\nRead: if theta+RODAS tracks zeta+RODAS (same low step count, same accuracy), RODAS handles the\n")
cat("stiffness on either chart and R-D adds nothing to the implicit path. If theta+RODAS needs more\n")
cat("steps / loses accuracy / FAILs where zeta+RODAS is clean, the raw-chart clamp is degrading the\n")
cat("Jacobian and R-D is what makes the implicit stepper well-conditioned.\n")
