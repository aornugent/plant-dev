# prep.R: the parent grids as TIMES files (and episodic-lma's own grid for the forward
# guard), with guard G1: each file equals the saved run's node times bit for bit.
AR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
MV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/moved"
for (cs in c("dry", "long-wet", "episodic", "episodic-lma")) {
  t <- readRDS(file.path(AR, sprintf("val_insk_c_%s.rds", cs)))$node_times
  f <- file.path(MV, "sched", sprintf("grid_%s.rds", cs)); saveRDS(t, f)
  cat(sprintf("G1 %-13s nodes %d identical %s\n", cs, length(t), identical(readRDS(f), t))) }
