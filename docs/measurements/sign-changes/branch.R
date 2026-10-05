# One branch per side (prereg.txt, eleventh extension).
#   OUTD=... Rscript branch.R
OUTD <- Sys.getenv("OUTD")
lj <- function(f) log(readRDS(file.path(OUTD, paste0(f, ".rds")))$stand$J)
secs <- function(f) {
  l <- grep(" s$", readLines(file.path(OUTD, paste0(f, ".log"))), value = TRUE)[1]
  as.numeric(sub(".*; ([0-9.]+) s$", "\\1", l))
}
k <- seq(0, 32, 2); r <- k * 1e-3 / 32
# The second difference of ln J in ln lma from lma (1 + u), lma (1 - u) and lma,
# as uscan.R's H_of.
H <- function(arm, u) {
  r <- as.numeric(u); hp <- log1p(r); hm <- -log1p(-r)
  2 * (lj(sprintf("%s_%s", arm, u)) / (hp * (hp + hm)) + lj(sprintf("%s_-%s", arm, u)) / (hm * (hp + hm)) -
       lj(sprintf("%s_t1", arm)) / (hp * hm))
}
sdv <- c()
for (arm in c("smooth", "branch")) {
  y <- sapply(k, function(i) lj(if (i == 0) sprintf("%s_t1", arm) else sprintf("%s_k%d", arm, i)))
  fit <- lm(y ~ r + I(r^2)); e <- residuals(fit); sdv[arm] <- sd(e)
  cat(sprintf("%s: ln J %.12f; fine grid: curvature in r %.2f, residual sd %.2e, largest %.2e\n",
              arm, lj(sprintf("%s_t1", arm)), 2 * coef(fit)[3], sd(e), max(abs(e))))
  cat(sprintf("  residuals: %s\n", paste(sprintf("%+.1e", e), collapse = " ")))
  cat(sprintf("  second difference in ln lma: %.3f at 1e-3, %.3f at 1e-2, residue %+.3f\n",
              H(arm, "1e-3"), H(arm, "1e-2"), H(arm, "1e-3") - H(arm, "1e-2")))
}
d <- lj("branch_t1") - lj("smooth_t1")
cat(sprintf("B1 (ln J moves at most 1e-8): %+.3e, %s\n", d,
            if (abs(d) <= 1e-8) "holds" else if (abs(d) >= 1e-6) "fails" else "neither"))
q <- sdv["branch"] / sdv["smooth"]
cat(sprintf("B2 (residual sd at most a third of smooth's): ratio %.2f, %s\n", q,
            if (q <= 1 / 3) "holds" else if (q >= 2 / 3) "fails" else "neither"))
ts <- sapply(1:2, function(i) secs(sprintf("smooth_t%d", i)))
tb <- sapply(1:2, function(i) secs(sprintf("branch_t%d", i)))
cat(sprintf("cost: smooth %s s, branch %s s: %+.1f%%\n", paste(ts, collapse = ", "),
            paste(tb, collapse = ", "), 100 * (mean(tb) / mean(ts) - 1)))
