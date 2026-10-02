# The defect in density x leaf area, panel by panel, at the snapshot times: the
# virtual node (order 1 and order 2 interpolation of u108's states) against the
# real mid node of u215 (relative to its own neighbours there).
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap"
S <- readRDS(file.path(A, "out", "snapshots.rds"))
Af <- function(h) (h / 5.44)^(1 / 0.306)
dA <- function(H, mu) exp(-mu) * Af(H)
dd <- function(x, f, i) ((f[i + 2] - f[i + 1]) / (x[i + 2] - x[i + 1]) - (f[i + 1] - f[i]) / (x[i + 1] - x[i])) / (x[i + 2] - x[i])
options(width = 200)
for (k in seq_along(S$s108)) {
  a <- S$s108[[k]]; f <- S$s215[[k]]
  n <- length(a$H); P <- min(n - 1, floor((length(f$H) - 1) / 2))
  res <- t(vapply(seq_len(P), function(p) {
    x <- a$birth; m <- (x[p] + x[p + 1]) / 2
    share <- (dA(a$H[p], a$mu[p]) + dA(a$H[p + 1], a$mu[p + 1])) / 2
    H1 <- (a$H[p] + a$H[p + 1]) / 2; mu1 <- (a$mu[p] + a$mu[p + 1]) / 2
    cH <- c(if (p > 1) dd(x, a$H, p - 1), if (p + 2 <= n) dd(x, a$H, p))
    cM <- c(if (p > 1) dd(x, a$mu, p - 1), if (p + 2 <= n) dd(x, a$mu, p))
    H2 <- H1 + mean(cH) * (m - x[p]) * (m - x[p + 1]); mu2 <- mu1 + mean(cM) * (m - x[p]) * (m - x[p + 1])
    j <- 2 * p
    share_f <- (dA(f$H[j - 1], f$mu[j - 1]) + dA(f$H[j + 1], f$mu[j + 1])) / 2
    c(birth = m, share = share, o1 = dA(H1, mu1) - share, o2 = dA(H2, mu2) - share,
      real = dA(f$H[j], f$mu[j]) - share_f)
  }, numeric(5)))
  w <- abs(res[, "real"]) + abs(res[, "o1"])
  top <- res[, "birth"] < 3.5
  cat(sprintf("t = %.2f: panels %d | sum of defects (b < 3.5): order1 %+.4g order2 %+.4g real %+.4g | (b > 3.5): order1 %+.4g order2 %+.4g real %+.4g\n",
              a$t, P, sum(res[top, "o1"]), sum(res[top, "o2"]), sum(res[top, "real"]),
              sum(res[!top, "o1"]), sum(res[!top, "o2"]), sum(res[!top, "real"])))
  if (k %in% c(5, 6)) { r <- res[10:min(40, P), ]; print(round(r[order(-abs(r[, "real"]))[1:15], ], 5)) }
}
