# Cash-Karp on x' = a (t - ts)^+ over one step [0, h]: the local error's mean over ts,
# and the jumps of its ts-derivative at the stage abscissae.
cc <- c(0, 1/5, 3/10, 3/5, 1, 7/8)
b5 <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)
h <- 1; a <- 1
err <- function(ts) sum(b5 * h * a * pmax(cc * h - ts, 0)) - a * (h - ts)^2 / 2
ts <- seq(0, h, length.out = 200001)
e <- vapply(ts, err, 0)
cat(sprintf("mean of e over ts: %.3e (max |e| %.3e)\n", mean(e), max(abs(e))))
d <- diff(e) / diff(ts)
for (k in seq_along(cc)) {
  if (cc[k] <= 0 || cc[k] >= 1) next
  i <- which.min(abs(ts - cc[k]))
  jump <- d[i + 5] - d[i - 5]
  cat(sprintf("c = %.3f: derivative jumps by %+.5f; b5 h a = %.5f\n", cc[k], jump, b5[k] * h * a))
}
cat(sprintf("mean of de/dts: %.3e (max |de/dts| %.3e, a h = %.1f)\n", mean(d), max(abs(d)), a * h))
