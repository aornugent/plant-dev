# The price of a chain guard, read from the logs: before each coupled attempt,
# one Cash-Karp step of the soil chain alone from the coupled soil state at the
# proposed size (t1_chain.R's 'chain' ratio); where it exceeds a threshold the
# attempt is shrunk by the rejection law until the chain passes. Counted:
#   caught  rejected attempts the guard would have pre-empted (their member
#           evaluations saved, the shrunk retry then taken first time);
#   false   accepted attempts the guard would have shrunk: each costs about
#           (1 - shrink) of an attempt's member evaluations in lost progress.
# Applied in the first day after a knot only, or everywhere.
#   nice -n 10 Rscript DEV/rej_class/t1_cure_price.R > DEV/rej_class/t1_cure_price.txt
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/rej_class"
D <- dirname(O)
for (name in c("pics_3e-5", "pi_3e-5", "base_3e-5")) {
  x <- readRDS(file.path(O, paste0("t1_", name, ".rds")))
  run <- readRDS(file.path(D, "pi", "runs", paste0(name, ".rds")))
  total <- run$counts$members
  first_day <- x$since > 0.001 & x$since <= 1
  ok <- !is.na(x$ratio)
  cat(sprintf("\n==== %s: %.4g member evaluations in the run; rejected attempts hold %.4g (%.1f%%)\n",
              name, total, sum(x$members[x$rej]), 100 * sum(x$members[x$rej]) / total))
  B <- x$rej & x$cls == "other" & first_day & x$part == "soil"
  cat(sprintf("first-day soil-bound 'other' rejections: %d, %.4g member evaluations (%.2f%% of the run)\n",
              sum(B), sum(x$members[B]), 100 * sum(x$members[B]) / total))
  # The guard shrinks by the rejection law, 0.9 r^(-1/5) floored at 0.2, until the
  # chain passes; one shrink is taken here (the chain's ratio falls as h^5).
  shrink <- pmax(0.2, pmin(1, 0.9 / pmax(x$chain, 1e-300)^(1 / 5)))
  cat("threshold | where | rejections caught (of all rejected; of the first-day soil 'other') | false alarms on accepted | net saving, % of the run's member evaluations\n")
  for (where in c("first day", "everywhere")) {
    zone <- if (where == "first day") (first_day | (x$since <= 0.001 & x$t0 > 0)) else rep(TRUE, nrow(x))
    for (thr in c(1.1, 1.5, 2, 3)) {
      flag <- ok & zone & x$chain > thr
      caught <- flag & x$rej
      false <- flag & !x$rej
      saved <- sum(x$members[caught])
      lost <- sum((1 - shrink[false]) * x$members[false])
      cat(sprintf("  %4.1f | %-10s | %4d (%4.1f%%; %4.1f%%) | %4d (%.2f%% of accepted) | %+.2f%% (saved %.2f%%, lost %.2f%%)\n",
                  thr, where, sum(caught), 100 * sum(caught) / sum(x$rej), 100 * sum(caught & B) / sum(B),
                  sum(false), 100 * sum(false) / sum(!x$rej),
                  100 * (saved - lost) / total, 100 * saved / total, 100 * lost / total))
    }
  }
  # How far the false alarms' coupled ratios sit below the bar.
  fa <- ok & !x$rej & x$chain > 1.1
  cat("false alarms at 1.1 everywhere: coupled ratio 10/50/90%:",
      paste(signif(quantile(x$ratio[fa], c(.1, .5, .9)), 3), collapse = " / "),
      "; chain alone:", paste(signif(quantile(x$chain[fa], c(.1, .5, .9)), 3), collapse = " / "),
      "; binding part:", paste(names(table(x$part[fa])), table(x$part[fa]), collapse = ", "), "\n")
}
