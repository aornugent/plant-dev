# m8_drydown.R CASE RES_TRAJ I4_TRAJ: timing of each drydown: the day the top soil layer first
# falls below a level (0.14, 0.15, 0.17) after being above 0.19, on res's and I4's
# trajectories; the lag res - I4 in days (negative: res dries first), by era.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R")
a0 <- commandArgs(TRUE); cs <- a0[1]; a <- rd5(a0[2])$traj; b <- rd5(a0[3])$traj; tg <- seq(0.05, 39.9, by = 0.1 / 365)
fa <- approx(a$time, a$soil[, 1], tg)$y; fb <- approx(b$time, b$soil[, 1], tg)$y
cross <- function(f, lev) { up <- FALSE; out <- c(); for (i in seq_along(f)) { if (is.na(f[i])) next; if (f[i] > 0.19) up <- TRUE; if (up && f[i] < lev) { out <- c(out, tg[i]); up <- FALSE } }; out }
for (lev in c(0.17, 0.15, 0.14)) { cb <- cross(fb, lev); ca <- cross(fa, lev)
  lag <- sapply(cb, function(t) { d <- ca - t; d <- d[abs(d) < 10 / 365]; if (length(d)) d[which.min(abs(d))] * 365 else NA })
  cat(sprintf("level %.2f: %d drydowns on I4, matched %d | lag res - I4 (days): mean %+.3f, median %+.3f, share negative %.2f\n", lev, length(cb), sum(!is.na(lag)), mean(lag, na.rm = TRUE), median(lag, na.rm = TRUE), mean(lag < 0, na.rm = TRUE)))
  for (er in list(c(0, 10), c(10, 20), c(20, 30), c(30, 40))) { k <- cb >= er[1] & cb < er[2]; cat(sprintf("    t %2d-%2d: n %d, mean lag %+.3f d\n", er[1], er[2], sum(k & !is.na(lag)), mean(lag[k], na.rm = TRUE))) } }
