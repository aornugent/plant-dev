# Height and mortality of the panel's cohorts (born 7.985-8.519) at t = 9..20:
# range, and the birth date where height crosses 1.5 m (the rooting-depth cap).
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_109", .libPaths()))
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
for (L in c(9, 10, 11, 12, 14, 17, 20)) { f <- file.path(S, sprintf("placed2/runs/rc_life%d_episodic.rds", L)); if (!file.exists(f)) next
  x <- readRDS(f); n <- x$stand$nodes; if (is.null(n$height)) { cat(L, "failed\n"); next }
  k <- which(n$birth >= 7.985 & n$birth <= 8.52); h <- n$height[k]; b <- n$birth[k]
  cr <- if (any(h > 1.5) && any(h < 1.5)) b[which.min(abs(h - 1.5))] else NA
  d2 <- diff(h, differences = 2); kink <- b[1 + which.max(abs(d2))]
  cat(sprintf("t = %2d: height %.3f-%.3f m, survival-weighted mort %.2f-%.2f | crosses 1.5 m at b = %s | largest |d2 height| at b = %.3f (%.1e)\n",
    L, min(h), max(h), min(n$mortality[k]), max(n$mortality[k]), if (is.na(cr)) "-" else sprintf("%.3f", cr), kink, max(abs(d2)))) }
