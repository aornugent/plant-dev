# q2_traj.R CASE...: the founders' race from the trajectory runs. Per founder: delay in
# reaching heights, calendar time of its mortality, and survival-weighted offspring over
# time; the soil's top layer and storage (net production's sign) beside them.
FO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
args <- commandArgs(TRUE)
for (cs in args) { x <- readRDS(file.path(FO, "runs", sprintf("traj_%s.rds", cs))); T <- x$traj; t <- T$time; b <- T$birth; nb <- length(b)
  b1 <- tail(b, 1); n <- x$stand$nodes; nrr <- n$nrr[seq_len(nb)]
  sel <- unique(round(seq(1, nb, length.out = 9)))
  cross <- function(y, lev) { i <- which(y >= lev)[1]; if (is.na(i) || i == 1) return(NA); t[i - 1] + (lev - y[i - 1]) / (y[i] - y[i - 1]) * (t[i] - t[i - 1]) }
  hmax <- max(T$height, na.rm = TRUE)
  cat(sprintf("== %s: %d founders over [0, %.2f); J %.4g; final height max %.2f m\n", cs, nb, b1, x$stand$J, hmax))
  cat(" birth | t at h=1m, 5m, 10m, 90%% final | delay over node 0 at 10m, 90%% | t at 10/50/90%% of final mortality | ln nrr | ln O(t) at t = 6, 9, 12, 15, 20 | ln nrr - ln O(20)\n")
  d10 <- c(); d90 <- c()
  for (j in sel) { h <- T$height[, j]; hf <- tail(h[!is.na(h)], 1); mo <- T$mortality[, j]; mf <- tail(mo[!is.na(mo)], 1); O <- T$offspring[, j]
    a <- c(cross(h, 1), cross(h, 5), cross(h, 10), cross(h, 0.9 * hf)); m3 <- c(cross(mo, 0.1 * mf), cross(mo, 0.5 * mf), cross(mo, 0.9 * mf))
    if (j == 1) a0 <- a
    Ot <- sapply(c(6, 9, 12, 15, 20), function(s) { i <- which.min(abs(t - s)); log(max(O[i], 1e-300)) })
    cat(sprintf(" %.3f | %5.2f %5.2f %5.2f %5.2f | %+5.2f %+5.2f (b %.2f) | %5.2f %5.2f %5.2f | %6.2f | %s | %+.2f\n", b[j], a[1], a[2], a[3], a[4], a[3] - a0[3], a[4] - a0[4], b[j], m3[1], m3[2], m3[3], log(nrr[j]),
      paste(sprintf("%6.2f", Ot), collapse = " "), log(nrr[j]) - Ot[5])) }
  # where mortality accrues in calendar time: founders' mean mortality rate by year
  yr <- floor(t); mr <- sapply(split(seq_along(t), yr), function(i) { k <- range(i); mean(T$mortality[k[2], ] - T$mortality[k[1], ], na.rm = TRUE) })
  cat(" founders' mean mortality integral gained per calendar year:", paste(sprintf("%d:%.2f", as.integer(names(mr)), mr), collapse = " "), "\n")
  # storage of node 0 and of the mid founder, and the soil's top layer, by year (minimum within the year)
  mid <- sel[5]
  smin <- function(v) sapply(split(v, yr), min, na.rm = TRUE)
  cat(" min storage by year, node 0:", paste(sprintf("%.2f", smin(T$storage[, 1])), collapse = " "), "\n")
  cat(" min storage by year, mid founder:", paste(sprintf("%.2f", smin(T$storage[, mid])), collapse = " "), "\n")
  cat(" min soil top layer by year:", paste(sprintf("%.3f", smin(T$soil[, 1])), collapse = " "), "\n")
}
# C4: a delayed copy under a common mortality schedule. If founder b reproduces like
# founder 0 shifted by its delay D(b), then d ln nrr / dD = -mbar, the mortality rate
# averaged over founder 0's (survival-weighted) reproduction. So g'(b) = -dD/db * mbar.
for (cs in args) { x <- readRDS(file.path(FO, "runs", sprintf("traj_%s.rds", cs))); T <- x$traj; t <- T$time; b <- T$birth; nb <- length(b)
  cross <- function(y, lev) { i <- which(y >= lev)[1]; if (is.na(i) || i == 1) return(NA); t[i - 1] + (lev - y[i - 1]) / (y[i] - y[i - 1]) * (t[i] - t[i - 1]) }
  dO <- diff(T$offspring[, 1]); dm <- diff(T$mortality[, 1]); dt <- diff(t)
  mbar <- sum((dm / dt) * dO, na.rm = TRUE) / sum(dO, na.rm = TRUE)
  D90 <- sapply(seq_len(nb), function(j) { h <- T$height[, j]; cross(h, 0.9 * tail(h[!is.na(h)], 1)) - b[j] })   # age at 90% final height
  D90 <- D90 - D90[1] + b                                                           # delay over founder 0
  k <- which(b <= b[nb] / 5); slope <- coef(lm(D90[k] ~ b[k]))[2]
  g <- log(x$stand$nodes$nrr[seq_len(nb)]); gs <- coef(lm(g[k] ~ b[k]))[2]
  cat(sprintf("C4 %s: mbar (founder 0's reproduction-weighted mortality rate) %.2f /y; dD90/db (first fifth) %.2f; predicted g' %.2f /y against measured %.2f (L %.2f vs %.2f y)\n",
    cs, mbar, slope, -slope * mbar, gs, 1 / (slope * mbar), -1 / gs)) }
# Where the fall in ln nrr comes from: ln nrr = ln of the survival-weighted seed output.
# Per founder: its mortality integral at the time its own offspring reach 50% (t_rep),
# its unweighted lifetime seed output, and its mortality integral at fixed calendar times.
for (cs in args) { x <- readRDS(file.path(FO, "runs", sprintf("traj_%s.rds", cs))); T <- x$traj; t <- T$time; b <- T$birth; nb <- length(b)
  sel <- unique(round(seq(1, nb, length.out = 9)))
  cross <- function(y, lev) { i <- which(y >= lev)[1]; if (is.na(i) || i == 1) return(NA); t[i - 1] + (lev - y[i - 1]) / (y[i] - y[i - 1]) * (t[i] - t[i - 1]) }
  at <- function(y, s) approx(t, y, s)$y
  cat(sprintf("== %s: ln nrr against the mortality integral at its reproduction\n birth | ln nrr | t_rep | M(t_rep) | ln seed out | M at t = 2, 4, 6, 9, 12, 15\n", cs))
  for (j in sel) { O <- T$offspring[, j]; Of <- tail(O[!is.na(O)], 1); tr <- cross(O, 0.5 * Of); M <- T$mortality[, j]
    cat(sprintf(" %.3f | %6.2f | %5.2f | %5.2f | %6.2f | %s\n", b[j], log(x$stand$nodes$nrr[j]), tr, at(M, tr), log(x$stand$nodes$state["fecundity", j]),
      paste(sprintf("%5.2f", sapply(c(2, 4, 6, 9, 12, 15), function(s) at(M, s))), collapse = " "))) } }
