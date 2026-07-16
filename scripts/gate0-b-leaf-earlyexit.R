#!/usr/bin/env Rscript
# Gate-0 check B (#4): compile the leaf-early-exit sweep driver and test whether
# leaf profit is C0 (continuous) across the shut-down transition. Method: sweep
# soil moisture at two resolutions; the largest adjacent |d profit| must SHRINK
# ~proportionally with the step (continuous -- even if kinked) rather than
# plateau at an O(1) value (a genuine jump, which would force a breakpoint node).

suppressMessages({library(odelia); Sys.setenv(TESTTHAT_PARALLEL="false")
  pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE)})

dlls <- getLoadedDLLs()
plant_so  <- dlls[["plant"]][["path"]]; odelia_so <- dlls[["odelia"]][["path"]]
plant_inc <- system.file("include", package="plant")
odelia_inc<- system.file("include", package="odelia")
bh_inc    <- system.file("include", package="BH")
Sys.setenv(PKG_CXXFLAGS = paste0("-isystem", plant_inc, " -I", odelia_inc, " -I", bh_inc))
Sys.setenv(PKG_LIBS = paste(shQuote(odelia_so), shQuote(plant_so)))
Rcpp::sourceCpp("/home/user/plant-dev/scripts/gate0_b_leaf_earlyexit_driver.cpp")

cat("=== Gate-0 B: leaf shut-down early-exits -- C0 continuity ===\n")

analyse <- function(n) {
  r <- tf24_leaf_earlyexit_sweep(height = 5.0, theta_lo = 0.0105, theta_hi = 0.214, n = n)
  dp <- abs(diff(r$profit)); dth <- diff(r$theta)[1]
  list(r = r, max_jump = max(dp), dth = dth,
       # regime marker: shutdown holds psi_stem at psi_crit (a constant)
       shutdown_frac = mean(abs(diff(r$psi_stem)) < 1e-9))
}

a1 <- analyse(400); a2 <- analyse(1600)
cat(sprintf("profit range over sweep: [%.4f, %.4f]\n",
            min(a1$r$profit), max(a1$r$profit)))
cat(sprintf("n= 400: step=%.2e  max adjacent |d profit|=%.3e\n", a1$dth, a1$max_jump))
cat(sprintf("n=1600: step=%.2e  max adjacent |d profit|=%.3e\n", a2$dth, a2$max_jump))

ratio_step   <- a1$dth / a2$dth                 # = 4 (4x finer)
ratio_jump   <- a1$max_jump / a2$max_jump       # ~4 if continuous, ~1 if a jump
cat(sprintf("\nstep refined %.1fx; max-jump shrank %.2fx\n", ratio_step, ratio_jump))
continuous <- ratio_jump > 2.0                  # shrinks with step => no O(1) discontinuity
cat(sprintf("profit is C0 across the transition = %s\n", continuous))
cat(sprintf("  -> early-exits classify as %s\n",
            ifelse(continuous, "decide() predicates (Kind A) -- confirmed",
                   "GENUINE KINKS -- promote to breakpoint nodes")))

# locate the transition for context
r <- a2$r; tr <- which(abs(diff(r$psi_stem)) < 1e-9)
if (length(tr)) {
  th_sd <- r$theta[min(tr)]
  cat(sprintf("\nshut-down onset near theta=%.4f (psi_stem pinned at psi_crit below this)\n", th_sd))
  cat(sprintf("fraction of sweep in shut-down = %.0f%%\n", 100*a2$shutdown_frac))
}
