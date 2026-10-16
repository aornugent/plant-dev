# mk_fbis.R: the committed schedule (insc, the 12-day inset) with every founders'
# interval bisected: intervals whose upper node is at or before the inset node beside b1.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R"))
OUT <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
ALL <- c("episodic", "dry", "long-wet", "long-drought", "episodic-lma", "dry-flat", "ld-102", "ld-105", "dry-p50", "wet-adG2")
for (cs in ALL) { S <- readRDS(file.path(POUT, "sched", sprintf("insc_%s.rds", cs))); b1 <- pilot_edges(cs)$b1
  lo <- head(S, -1); hi <- S[-1]; f <- hi <= b1 + 1e-9
  Sb <- sort(c(S, (lo[f] + hi[f]) / 2))
  saveRDS(Sb, file.path(OUT, "sched", sprintf("fbis_%s.rds", cs)))
  cat(sprintf("%-13s b1 %.3f n %d, founders' intervals %d (h %.3f-%.3f y, last hi %.3f), bisected n %d\n", cs, b1, length(S), sum(f),
    min(diff(S)[f]), max(diff(S)[f]), max(hi[f]), length(Sb))) }
