# mk_p2.R: P2 = C2 (every other node of L) with every interval bisected: L's node count,
# every pair (from node 0) two equal halves of one C2 interval.
SU <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/summing"
for (cs in c("dry", "episodic-lma", "long-wet", "dry-flat")) { C <- readRDS(file.path(SU, "sched", sprintf("C2_%s.rds", cs)))
  P <- sort(c(C, (head(C, -1) + C[-1]) / 2)); saveRDS(P, file.path(SU, "sched", sprintf("P2_%s.rds", cs)))
  cat(sprintf("%-12s P2 nodes %d (L %d)\n", cs, length(P), length(readRDS(file.path(SU, "sched", sprintf("L_%s.rds", cs)))))) }
