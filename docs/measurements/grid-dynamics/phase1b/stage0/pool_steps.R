# A pool relaxing at tau_s = 7 days, y' = -y / tau_s, on one step of h days:
# each pair's stage values (I + (h / tau_s) A) Y = 1, the lowest of them, and
# the step's factor R(-h / tau_s).
#   Rscript stage0/pool_steps.R   (from phase1b/)
tab <- new.env(); sys.source("harness/ark436.R", envir = tab)
pairs <- with(tab, list(CK = list(A = ACK, b = bCK), DP = list(A = ADP, b = bDP)))
for (h in c(7, 7.3, 10, 15, 23, 26)) {
  z <- h / 7
  cat(sprintf("h = %4.1f days (h / tau_s = %.2f):", h, z))
  for (m in names(pairs)) {
    Y <- solve(diag(6) + z * pairs[[m]]$A, rep(1, 6))
    R <- 1 - z * sum(pairs[[m]]$b * Y)
    cat(sprintf("  %s lowest stage %+.2f (stage %d), step factor %+.3f;", m, min(Y), which.min(Y), R))
  }
  cat("\n")
}
