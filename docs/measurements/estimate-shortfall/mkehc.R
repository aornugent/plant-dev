# One-panel spacing ladder: pass 3 with [7.985, 8.519] given even spacing of
# s = 270, 135, 67, 33, 16, 8, 4 days (endpoints kept); everything else unchanged.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
t <- readRDS(file.path(S, "refine/ref_u108e_episodic_p3_times.rds")); lo <- 7.9852; hi <- 8.5185
lo <- t[which.min(abs(t - lo))]; hi <- t[which.min(abs(t - hi))]; out <- t[t <= lo | t >= hi]
for (n in c(1, 2, 4, 8, 16, 32, 64)) { s <- sort(unique(c(out, seq(lo, hi, length.out = n + 1))))
  saveRDS(s, file.path(S, sprintf("rc/ehc_%02d.rds", n))); cat(n, "intervals:", round((hi - lo) * 365 / n, 1), "days\n") }
