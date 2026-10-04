# The fine grids against each one's own quadratic in r rather than the fixed
# curvature band.R takes, so a change of the model's curvature with the
# positive part's width does not read as a departure (prereg.txt, sixth
# extension, reported after B1).
#   SC=... T=... Rscript band_fit.R
SC <- Sys.getenv("SC"); T <- Sys.getenv("T")
lj <- function(f) log(readRDS(paste0(f, ".rds"))$stand$J)
k <- seq(0, 32, 2); r <- k * 1e-3 / 32
scan <- function(dir, k0) sapply(k, function(i) if (i == 0) lj(k0) else lj(file.path(dir, sprintf("fine_split_k%d", i))))
for (b in list(c("split build, width 1e-4", file.path(SC, "runs"), file.path(SC, "runs", "fine_split_k0")),
               c("tight build, width 1e-4", file.path(T, "runs"), file.path(T, "runs", "split_lma_0")),
               c("tight build, width 1e-3", file.path(T, "runs_eps"), file.path(T, "runs_eps", "split_lma_0")))) {
  y <- scan(b[2], b[3])
  fit <- lm(y ~ r + I(r^2))
  e <- residuals(fit)
  d <- diff(e)
  cat(sprintf("%s: curvature in r %.2f; residual sd %.2e, largest %.2e; interval departures sd %.2e\n  residuals: %s\n",
              b[1], 2 * coef(fit)[3], sd(e), max(abs(e)), sd(d), paste(sprintf("%+.1e", e), collapse = " ")))
}
