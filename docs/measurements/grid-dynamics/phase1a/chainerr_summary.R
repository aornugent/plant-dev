# The chain-error diagnostic's agreement with the measured soil error, per run
# (chain_err.R's saved outputs): correlation and slope over every layer and common
# time, the maxima and medians, and the estimate over the measurement at the 20 worst events.
#   Rscript chainerr_summary.R > chainerr_summary.txt
for (r in c("arkfree_3e-5", "ark100_3e-5", "ark100_1e-5", "ck100a_3e-5")) {
  x <- readRDS(sprintf("runs/chainerr_%s.rds", r))
  est <- x$est[x$ok, ]; meas <- x$meas
  mx <- function(m) apply(abs(m), 1, max)
  big <- order(-mx(meas))[1:20]
  q <- mx(est)[big] / mx(meas)[big]
  cat(sprintf("%-13s corr %.3f slope %.3f | max est %.2e meas %.2e | median est %.2e meas %.2e | 20 worst: est/meas median %.3f, range %.3f-%.3f\n",
              r, cor(as.vector(est), as.vector(meas)), coef(lm(as.vector(meas) ~ as.vector(est) + 0)),
              max(abs(est)), max(abs(meas)), median(mx(est)), median(mx(meas)), median(q), min(q), max(q)))
}
