# The time-based alternative to the chain guard, from the logs: cap each attempt
# in the first day after a knot at the chain alone's own accepted step there
# (docs/measurements/grid-dynamics/soil_chain_ld_theta.rds, odelia's law, 3e-5).
# Counted as in t1_cure_price.R: a rejected attempt is pre-empted when the cap
# is at or below the size then accepted from its start; an accepted attempt
# above the cap loses (1 - cap/h) of its member evaluations.
#   nice -n 10 Rscript DEV/rej_class/t1_program_cap.R > DEV/rej_class/t1_program_cap.txt
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/rej_class"
W <- "/home/user/plant-dev/.claude/worktrees/agent-a4dae3c2572021890"
D <- dirname(O)
ch <- readRDS(file.path(W, "docs", "measurements", "grid-dynamics", "soil_chain_ld_theta.rds"))$rows
for (name in c("pics_3e-5", "pi_3e-5", "base_3e-5")) {
  x <- readRDS(file.path(O, paste0("t1_", name, ".rds")))
  total <- readRDS(file.path(D, "pi", "runs", paste0(name, ".rds")))$counts$members
  zone <- (x$since > 0.001 & x$since <= 1) | (x$since <= 0.001 & x$t0 > 0)
  i <- findInterval(x$t0, ch[, "t0"])
  cap <- ch[pmax(i, 1), "h"]
  # The size accepted from each rejected attempt's start.
  acc_h <- tapply(x$h[!x$rej], x$t0[!x$rej], function(v) v[1])
  h_ok <- acc_h[as.character(x$t0)]
  B <- x$rej & x$cls == "other" & x$since > 0.001 & x$since <= 1 & x$part == "soil"
  capped <- zone & x$h > cap
  caught <- capped & x$rej & !is.na(h_ok) & cap <= h_ok
  false <- capped & !x$rej
  saved <- sum(x$members[caught]); lost <- sum((1 - cap[false] / x$h[false]) * x$members[false])
  cat(sprintf("%s: caught %d rejections (%.1f%% of the first-day soil 'other'); capped accepted %d (%.1f%% of accepted); net %+.2f%% (saved %.2f%%, lost %.2f%%)\n",
              name, sum(caught), 100 * sum(caught & B) / sum(B), sum(false), 100 * sum(false) / sum(!x$rej),
              100 * (saved - lost) / total, 100 * saved / total, 100 * lost / total))
}
