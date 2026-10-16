# guard.R A B [CASE ...]: run A_<case> against B_<case> (a name in summing/runs, or
# "libS" for adjmap/runs/val_insk_c_<case>): J, step times, node weights and elasticities,
# identical() and largest relative difference.
SU <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/summing"
ADJ <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
a <- commandArgs(TRUE); rd <- function(n, cs) readRDS(if (n == "libS") file.path(ADJ, sprintf("val_insk_c_%s.rds", cs)) else file.path(SU, "runs", sprintf("%s_%s.rds", n, cs)))
rel <- function(x, y) if (length(x) != length(y)) NA else max(abs(x - y) / pmax(abs(y), 1e-300))
for (cs in a[-(1:2)]) { x <- rd(a[1], cs); y <- rd(a[2], cs); sx <- x$stand; sy <- y$stand
  cat(sprintf("%s %s vs %s: J %.15g vs %.15g identical %s (rel %.1e) | steps %d vs %d identical %s | weights identical %s | elasticities (%d) identical %s (max rel %.1e) | cpu %.0f+%.0f vs %.0f+%.0f s\n",
    cs, a[1], a[2], sx$J, sy$J, identical(sx$J, sy$J), sx$J / sy$J - 1, length(sx$times), length(sy$times), identical(sx$times, sy$times),
    identical(sx$nodes$establishment, sy$nodes$establishment), length(sx$elasticity), identical(sx$elasticity, sy$elasticity),
    if (is.null(sx$elasticity) || is.null(sy$elasticity)) NA else rel(sx$elasticity, sy$elasticity), sx$cpu, x$sweep_cpu %||% NA, sy$cpu, y$sweep_cpu %||% NA)) }
