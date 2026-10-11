# State at the end of short runs (t = 8.6, 9.5) for cohorts born in [7.985, 8.519], with
# the rain onsets: does early size oscillate in birth date with the pulses?
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_109", .libPaths()))
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
d <- readRDS(file.path(S, "rc/onsets_episodic.rds")); on <- d$t[d$t > 7.95 & d$t < 8.55]
cat("rain onsets (rise > 0.05):", round(on, 3), "\n")
for (L in c("9.5")) { f <- file.path(S, sprintf("placed2/runs/rc_early%s_episodic.rds", L)); if (!file.exists(f)) { cat(L, "missing\n"); next }
  n <- readRDS(f)$stand$nodes; k <- which(n$birth >= 7.985 & n$birth <= 8.52)
  h <- n$height[k]; b <- n$birth[k]; dh <- c(NA, diff(h))
  cat(sprintf("\n== t = %s: height of cohorts by birth date (every 2nd node)\n", L))
  i <- seq(1, length(k), by = 2); print(data.frame(b = round(b[i], 3), height = round(h[i], 4), mort = round(n$mortality[k][i], 4), dh = signif(dh[i], 2)), row.names = FALSE) }
