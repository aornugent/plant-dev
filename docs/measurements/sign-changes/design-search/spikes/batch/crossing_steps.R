# What sets the steps that hold a sign change: their size against the steps
# either side, and how their size moves with tol (kink-limited steps go as
# sqrt(tol); the rest as tol^0.15-0.2).
ev <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events/runs"
for (tt in c("1e-4", "3e-5")) {
  st <- readRDS(file.path(ev, sprintf("g_%s.rds", tt)))$st
  f <- if (tt == "1e-4") file.path(ev, "slq_1e-4.rds") else "/home/user/plant-dev/docs/measurements/grid-dynamics/cross_tied_3e-5.rds"
  rows <- sort(unique(readRDS(f)$row))
  rows <- rows[rows > 1 & rows < nrow(st)]
  nb <- sort(unique(c(rows - 1, rows + 1)))
  nb <- setdiff(nb, rows)
  cat(sprintf("%s: crossing steps %d, median h %.3f d; non-crossing neighbours %d, median h %.3f d; error ratio at crossing steps median %.2f vs all %.2f\n",
              tt, length(rows), 365 * median(st$h[rows]), length(nb), 365 * median(st$h[nb]),
              median(st$er[rows]), median(st$er)))
  if ("ei" %in% names(st)) {
    tb <- sort(table(st$ei[rows]), decreasing = TRUE)[1:5]
    cat("  binding component index at crossing steps (top 5):", paste(names(tb), tb, sep = ":", collapse = " "), "\n")
  }
}
