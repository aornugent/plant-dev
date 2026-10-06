# For each of the seven nudged tolerances, the driver's recorded program (plain
# Cash-Karp, long drought, u108, tied tol) as is (m1) and with every step that
# holds a sign change of a node's net production cut into m equal steps (m2, m4).
# The steps holding a sign change are the split log's rows at that tolerance.
ev <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events/runs"
out <- "runs"
tols <- c("9.5e-5", "9.7e-5", "9.85e-5", "1e-4", "1.015e-4", "1.03e-4", "1.05e-4")
for (tt in tols) {
  st <- readRDS(file.path(ev, sprintf("g_%s.rds", tt)))$st[, c("time", "h")]
  rows <- sort(unique(readRDS(file.path(ev, sprintf("slq_%s.rds", tt)))$row))
  start <- c(0, head(st$time, -1))
  stopifnot(all(abs(start + st$h - st$time) < 1e-12 * pmax(1, st$time)))
  for (m in c(1, 2, 4)) {
    times <- st$time
    if (m > 1) {
      extra <- unlist(lapply(rows, function(r) start[r] + (1:(m - 1)) * st$h[r] / m))
      times <- sort(c(times, extra))
    }
    prog <- data.frame(time = times, h = diff(c(0, times)))
    saveRDS(list(st = prog), file.path(out, sprintf("prog_m%d_%s.rds", m, tt)))
    cat(sprintf("%s m%d: %d steps (%d crossing rows)\n", tt, m, nrow(prog), length(rows)))
  }
}
