# Share of rows (member-steps) after patch age T, from stored step times and node births.
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
Ts <- c(25, 30, 32, 33.5, 34.5, 36)
for (cs in c("episodic", "dry", "long-wet", "long-drought", "episodic-lma")) for (pt in c("f16_l70", "f32_l35")) {
  f <- file.path(A, sprintf("lat_%s_%s.rds", cs, pt)); if (!file.exists(f)) next
  x <- readRDS(f); b <- x$stand$nodes$birth; t <- x$stand$times; alive <- findInterval(t, b); R <- sum(alive)
  sh <- vapply(Ts, function(T) sum(alive[t > T]) / R, 0); st <- vapply(Ts, function(T) mean(t > T), 0)
  cat(sprintf("%-13s %s n=%d steps=%d  rows after T=%s: %s | steps after: %s\n", cs, pt, length(b), length(t), paste(Ts, collapse="/"),
    paste(sprintf("%.3f", sh), collapse=" "), paste(sprintf("%.3f", st), collapse=" "))) }
