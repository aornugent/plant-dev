# How many of theta1's edges (before 25) fall strictly inside an interval of theta0's grid.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/F/lib.R")
for (u in list(c("dry", "dry-p50", "F_use_dryp50"), c("episodic", "episodic-lma", "F_use_lma"))) {
  G <- readRDS(file.path(R, paste0(u[3], ".rds")))$node_times; e1 <- pilot_edges(u[2])$edges; e1 <- e1[e1 < 25]
  d <- vapply(e1, function(x) min(abs(G - x)), 0); own <- readRDS(file.path(R, sprintf("val_a09_c_%s.rds", u[2])))$node_times
  cat(sprintf("%s's %d edges before 25 on %s's grid (%d nodes): %d not nodes (>1e-6 y), %d off by > 1 d, %d by > 5 d; its own grid has %d nodes\n",
    u[2], length(e1), u[1], length(G), sum(d > 1e-6), sum(d > 1 / 365), sum(d > 5 / 365), length(own))) }
