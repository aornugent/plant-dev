# score.R A B [A B ...]: B − A in ε (nudge.R's quantities and ε), rms over the traits and
# over all quantities, max, TF24_cost_scale and ln J; plus each pinned pass's program check
# (its step count and times against its pin's).
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R"))
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/held-ends"
rd <- function(n) { f <- file.path(O, paste0(n, ".rds")); if (!file.exists(f)) f <- n; readRDS(f) }
check <- function(n) { x <- rd(n); pin <- x$setting$env[["PIN"]]
  if (!nzchar(pin)) return(sprintf("%s: unpinned, %d steps", n, length(x$stand$times)))
  p <- readRDS(pin)$stand$times; t <- x$stand$times
  sprintf("%s: %d steps, pin %d, max |t - pin| %.2g", n, length(t), length(p), if (length(t) == length(p)) max(abs(t - p)) else NA) }
a <- commandArgs(TRUE)
for (i in seq(1, length(a), 2)) {
  x <- rd(a[i]); y <- rd(a[i + 1]); qx <- quantities(x); qy <- quantities(y)
  k <- intersect(names(qx), names(qy)); d <- (qy[k] - qx[k]) / eps_vec(k); tr <- d[k != "lnJ"]
  cat(sprintf("%s -> %s: rms traits %.4f (all %.4f), max %.4f (%s), TF24_cost_scale %+.4f, lnJ %+.2e | n %d\n",
    a[i], a[i + 1], sqrt(mean(tr^2)), sqrt(mean(d^2)), max(abs(d)), k[which.max(abs(d))],
    d[["TF24_cost_scale"]], d[["lnJ"]], length(tr)))
}
for (n in unique(a)) cat(check(n), "\n")
