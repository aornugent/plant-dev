# Root cause of the old own-node estimate's 0.04-0.05x (perf-adjoint.md 4.2):
# which input is wrong, the nodal values of g or what nodal values can see?
ADJ <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/perf/adjoint"
O <- file.path(ADJ, "out")
source(file.path(ADJ, "indicators.R"))
JINF <- 12.5734
rd <- function(n) read.csv(file.path(O, sprintf("nodes_uniform_%d.csv", n)))
N <- list(`108` = rd(108), `215` = rd(215), `429` = rd(429))
fwdJ <- function(tg) readRDS(file.path(O, paste0("fwd_", tg, ".rds")))$J
J <- c(`108` = fwdJ("uniform_108"), `215` = fwdJ("uniform_215"), `429` = fwdJ("uniform_429"))
trap <- function(x, y) sum(0.5 * diff(x) * (y[-1] + y[-length(y)]))
eta <- function(x, y) sum(panel_errors(drop_one(x, y)$e))
F <- N[["429"]]
options(width = 200)
cat("J:", J, " J - Jinf:", J - JINF, "\n")
for (n in c("108", "215")) {
  A <- N[[n]]; step <- if (n == "108") 4 else 2
  k <- seq(1, nrow(F), by = step)
  stopifnot(max(abs(F$b[k] - A$b)) < 1e-9)
  true <- J[[n]] - J[["429"]]
  # (1) the old premise: 429's g on the coarse nodes, against 429's own trapezium
  prem <- trap(F$b[k], F$g[k]) - trap(F$b, F$g)
  # (2) own-node estimate from the coarse run's own g (the 0.04x)
  own <- eta(A$b, A$g)
  # (3) own-node estimate fed 429's g subsampled at the coarse nodes only
  sub <- eta(F$b[k], F$g[k])
  cat(sprintf("u%s: J_h - J_429 %+.4f | premise(429 g, in-between seen) %+.4f (%.2fx) | own-node eta(own g) %+.4f (%.3fx) | own-node eta(429 g at coarse nodes only) %+.4f (%.3fx)\n",
              n, true, prem, prem / true, own, own / true, sub, sub / true))
  d <- data.frame(b = A$b, g_own = A$g, g_429 = F$g[k], f_own = A$f, f_429 = F$f[k],
                  c_own = A$c, c_429 = F$c[k])
  cat(sprintf("  sum w*g own %.4f vs 429 at those nodes %.4f; max |g_own - g_429| %.3f at b=%.3f\n",
              sum(A$w * A$g), sum(A$w * F$g[k]), max(abs(d$g_own - d$g_429)), d$b[which.max(abs(d$g_own - d$g_429))]))
  cat(sprintf("  eta_f own %+.4f, eta_f 429@coarse %+.4f | eta_c own %+.4f, eta_c 429@coarse %+.4f\n",
              eta(A$b, A$f), eta(F$b[k], F$f[k]), eta(A$b, A$c), eta(F$b[k], F$c[k])))
  bands <- c(0, 0.5, 1, 2, 3, 5, 10, 20, 40)
  pdef <- vapply(seq_len(length(k) - 1), function(j) { idx <- k[j]:k[j + 1]
    0.5 * (F$b[k[j + 1]] - F$b[k[j]]) * (F$g[k[j]] + F$g[k[j + 1]]) - trap(F$b[idx], F$g[idx]) }, 0)
  pown <- panel_errors(drop_one(A$b, A$g)$e)
  psub <- panel_errors(drop_one(F$b[k], F$g[k])$e)
  cb <- cut(A$b[-nrow(A)], bands, right = FALSE)
  print(data.frame(band = levels(cb), premise = as.vector(tapply(pdef, cb, sum)),
                   own = as.vector(tapply(pown, cb, sum)), sub429 = as.vector(tapply(psub, cb, sum))), digits = 4)
  print(head(d, 12), digits = 4)
}
sel <- F$b >= 4.5 & F$b <= 10
print(data.frame(b = F$b[sel], g = F$g[sel], f = F$f[sel], c = F$c[sel]), digits = 4)
