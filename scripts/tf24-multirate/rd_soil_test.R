#!/usr/bin/env Rscript
# Step 1: does odelia's RODAS suffice for / help R-D? The TF24-shaped soil block (log chart), integrated
# by the REAL odelia adaptive solver. A gentle smooth block is NOT stiff for adaptive explicit RKCK, so
# we sweep the vulnerability-shutoff steepness (sh) -- which sets the coupling stiffness -- and find where
# RKCK becomes step-limited and RODAS (implicit) wins. The real soil-block Jacobian was measured ~ -86 at
# theta~0.13 (T4 / r1_split_payoff); the sweep brackets that.
suppressMessages(library(odelia)); options(width=120)
inc <- system.file("include", package="odelia")
so  <- file.path(system.file("libs", package="odelia"), "odelia.so")
Sys.setenv(PKG_CPPFLAGS = paste0("-I", inc), PKG_LIBS = shQuote(normalizePath(so)))
Rcpp::sourceCpp("/home/user/plant-dev/scripts/tf24-multirate/rd_soil_runner.cpp")
cat("=== compiled rd_soil_runner ===\n")

acc <- function(r, ref) if (any(!is.finite(r$theta)) || any(!is.finite(ref$theta))) NA else max(abs(r$theta - ref$theta))

cat("\nStiff window: chronic stress near theta~0.13 (rin=1.0 mm/day), T=10 d. Sweep shutoff steepness sh.\n")
cat("Higher sh = steeper vulnerability = stiffer coupling. Reports accepted step counts (accuracy in [] vs\n")
cat("a tight zeta+RODAS reference).\n\n")
cat(sprintf("%5s | %-18s | %-18s | %-18s\n", "sh", "theta+RKCK", "zeta+RKCK", "zeta+RODAS"))
for (sh in c(60, 120, 250, 500, 1000, 2000)) {
  s <- rd_soil_compare(urate = 0.06, rin = 1.0, theta0 = 0.13, Tend = 10, tol = 1e-6, psi50 = 3.0, sh = sh)
  f <- function(r, isz=TRUE) {
    th <- if (isz) r$theta else r$theta
    e <- if (any(!is.finite(th))||any(!is.finite(s$ref$theta))) NA else max(abs(th - s$ref$theta))
    sprintf("%5s [%s]", ifelse(r$n_steps<0,"FAIL",r$n_steps), ifelse(is.na(e),"NA",sprintf("%.0e",e)))
  }
  cat(sprintf("%5.0f | %-18s | %-18s | %-18s   (ref %d st)\n", sh,
      f(s$theta_rkck, FALSE), f(s$zeta_rkck), f(s$zeta_rodas), s$ref$n_steps))
}
cat("\nRead: if at realistic steepness RKCK step counts blow up while zeta+RODAS stays low + accurate,\n")
cat("RODAS is the implicit stepper R-D needs. If RKCK keeps up across the range, R-D needs no implicit\n")
cat("stepper (correctness/conditioning only) and step 2 is unnecessary.\n")
