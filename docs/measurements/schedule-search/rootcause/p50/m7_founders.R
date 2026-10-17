# m7_founders.R CASE: the founders on res's and I4's forward trajectories (traj.R, BLO 0, BHI b1).
# Per founder, res - I4 in mortality integral, height, storage over calendar time (daily grid);
# when the extra mortality accrues (pulse days: the founders' mean mortality rate above its
# 90th percentile), and the environment states (res - I4) on those days.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R")
aa <- commandArgs(TRUE); cs <- aa[1]; pre <- if (length(aa) > 1) aa[2] else "trajF"; a <- rd5(sprintf("%s_res_%s", pre, cs))$traj; b <- rd5(sprintf("%s_I4_%s", pre, cs))$traj
stopifnot(all(abs(a$birth - b$birth) < 1e-9)); tg <- seq(0.05, 39.9, by = 1 / 365); nf <- length(a$birth)
ip <- function(tr, v, j) approx(tr$time, tr[[v]][, j], tg)$y
w <- rd5(sprintf("cl_res_%s", cs))$stand$nodes; ww <- (w$establishment[seq_along(w$nrr)] * w$nrr)[seq_len(nf)]; ww <- ww / sum(ww)  # each founder's share of the founders' J
dM <- sapply(seq_len(nf), function(j) ip(a, "mortality", j) - ip(b, "mortality", j)) %*% ww
mI <- sapply(seq_len(nf), function(j) ip(b, "mortality", j)) %*% ww; rate <- c(NA, diff(mI) * 365)
dH <- sapply(seq_len(nf), function(j) ip(a, "height", j) - ip(b, "height", j)) %*% ww
sR <- sapply(seq_len(nf), function(j) (ip(a, "storage", j) - ip(b, "storage", j)) / pmax(ip(b, "storage", j), 1e-12)) %*% ww
pulse <- !is.na(rate) & rate > quantile(rate, 0.9, na.rm = TRUE); inc <- c(0, diff(dM))
cat(sprintf("%s: %d founders; J-weighted final res - I4 mortality %+.4f, height %+.5f m\n", cs, nf, tail(na.omit(dM), 1), tail(na.omit(dH), 1)))
cat(sprintf("share of the extra mortality accrued on pulse days (founders' mortality rate above its 90th percentile, %.0f days): %.2f\n", sum(pulse), sum(inc[pulse], na.rm = TRUE) / sum(inc, na.rm = TRUE)))
for (er in list(c(0, 5), c(5, 10), c(10, 15), c(15, 20), c(20, 25), c(25, 30), c(30, 40))) { k <- tg >= er[1] & tg < er[2]
  cat(sprintf("  t %2d-%2d: extra mortality accrued %+.4f (on pulses %+.4f) | founders' mortality rate mean %.3f/y | rel. storage res-I4 %+.4f (pulses %+.4f) | height %+.5f\n", er[1], er[2],
    sum(inc[k], na.rm = TRUE), sum(inc[k & pulse], na.rm = TRUE), mean(rate[k], na.rm = TRUE), mean(sR[k], na.rm = TRUE), mean(sR[k & pulse], na.rm = TRUE), mean(dH[k], na.rm = TRUE))) }
E <- sapply(seq_len(a$extra), function(L) approx(a$time, a$soil[, L], tg)$y - approx(b$time, b$soil[, L], tg)$y)
E0 <- sapply(seq_len(a$extra), function(L) approx(b$time, b$soil[, L], tg)$y)
cat("environment states, I4 mean on pulse days:      ", sprintf("%.4f", colMeans(E0[pulse, ], na.rm = TRUE)), "\n")
cat("environment states, res - I4 on pulse days:     ", sprintf("%+.1e", colMeans(E[pulse, ], na.rm = TRUE)), "\n")
cat("environment states, res - I4 on the 10 days before pulses start:", sprintf("%+.1e", colMeans(E[pmax(1, as.vector(outer(which(diff(c(FALSE, pulse)) == 1), 1:10, "-"))), , drop = FALSE], na.rm = TRUE)), "\n")
# drydown periods on I4's record: top layer falling and below 0.17; share of the extra
# mortality accrued in them, and res - I4 top layer there.
top <- approx(b$time, b$soil[, 1], tg)$y; dd <- !is.na(top) & c(0, diff(top)) < 0 & top < 0.17
cat(sprintf("drydown days (I4 top layer falling, below 0.17): %.0f of %d; share of the extra mortality accrued in them %.2f; res - I4 top layer there %+.2e (elsewhere %+.2e)\n",
  sum(dd), length(tg), sum(inc[dd], na.rm = TRUE) / sum(inc, na.rm = TRUE), mean(E[dd, 1], na.rm = TRUE), mean(E[!dd, 1], na.rm = TRUE)))
