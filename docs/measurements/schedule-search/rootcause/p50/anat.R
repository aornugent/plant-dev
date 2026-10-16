# anat.R CASE: res's intervals by region, with the pilot's spells, for designing the region refinements.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R")
cs <- commandArgs(TRUE)[1]; S <- sort(readRDS(file.path(CL, "sched", sprintf("res_%s.rds", cs)))); c0 <- sort(rd5(sprintf("val_insk_c_%s", cs))$node_times)
et <- edge_table(cs); b1 <- PIL[[cs]]$b1; cat(sprintf("%s b1 %.3f, res n %d (c n %d), max node %.2f; nodes > 25: %d (c %d)\n", cs, b1, length(S), length(c0), max(S), sum(S > 25), sum(c0 > 25)))
cat("c nodes > 20:", round(c0[c0 > 20], 2), "\n")
op <- et$b[et$opening]; cl <- et$b[!et$opening]
for (o in op[op > b1]) { c1 <- min(cl[cl > o], 25); i <- S >= o - 30/365 & S <= c1 + 1e-9
  cat(sprintf("spell %.3f-%.3f (%.0f d): res offsets from o (d): %s\n", o, c1, (c1 - o) * 365, paste(round((S[i] - o) * 365, 1), collapse = " "))) }
