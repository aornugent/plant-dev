# mk_ladder.R: the committed schedule (insc) with its founders' nodes in [0, bF] (bF the
# inset node beside b1) replaced by f even intervals; the rest unchanged. Written for the
# trapezium (ladT<f>) and Simpson (ladS<f>, the same nodes) runs; bF printed for Simpson.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R"))
OUT <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
for (cs in c("dry", "episodic-lma")) { S <- readRDS(file.path(POUT, "sched", sprintf("insc_%s.rds", cs))); b1 <- pilot_edges(cs)$b1
  bF <- max(S[S <= b1 + 1e-9]); rest <- S[S > bF + 1e-9]
  for (f in c(6, 12, 24, 48)) { Sf <- c(seq(0, bF, length.out = f + 1), rest); stopifnot(all(diff(Sf) > 1e-7))
    saveRDS(Sf, file.path(OUT, "sched", sprintf("ladT%d_%s.rds", f, cs))); saveRDS(Sf, file.path(OUT, "sched", sprintf("ladS%d_%s.rds", f, cs))) }
  cat(sprintf("%s bF %.10f, committed founders' intervals %d, rest %d nodes\n", cs, bF, sum(S <= bF + 1e-9) - 1, length(rest))) }
