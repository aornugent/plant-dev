# m5_soil.R CASE: the top soil layer on res's and I4's forward trajectories (traj.R), on a
# common daily grid: mean difference (res - I4) on drydown days (I4's top layer below its
# 20th percentile) and on wet days (above its 80th), by era of the patch's age.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R")
cs <- commandArgs(TRUE)[1]; a <- rd5(sprintf("traj_res_%s", cs))$traj; b <- rd5(sprintf("traj_I4_%s", cs))$traj
tg <- seq(0.5, 39.5, by = 1 / 365); fa <- approx(a$time, a$soil[, 1], tg)$y; fb <- approx(b$time, b$soil[, 1], tg)$y
d <- fa - fb; lo <- fb < quantile(fb, 0.2, na.rm = TRUE); hi <- fb > quantile(fb, 0.8, na.rm = TRUE)
cat(sprintf("%s top layer: I4 mean %.4f | res - I4: drydown days %+.2e, wet days %+.2e, all %+.2e\n", cs, mean(fb, na.rm = TRUE), mean(d[lo], na.rm = TRUE), mean(d[hi], na.rm = TRUE), mean(d, na.rm = TRUE)))
for (er in list(c(0.5, 10), c(10, 15), c(15, 20), c(20, 25), c(25, 30), c(30, 40))) { k <- tg >= er[1] & tg < er[2]
  cat(sprintf("  t %4.1f-%4.1f: res - I4 drydown %+.2e, wet %+.2e, all %+.2e; layers 1-5 mean diff %s\n", er[1], er[2], mean(d[k & lo], na.rm = TRUE), mean(d[k & hi], na.rm = TRUE), mean(d[k], na.rm = TRUE),
    paste(sprintf("%+.1e", sapply(1:5, function(L) mean(approx(a$time, a$soil[, L], tg[k])$y - approx(b$time, b$soil[, L], tg[k])$y, na.rm = TRUE))), collapse = " "))) }
