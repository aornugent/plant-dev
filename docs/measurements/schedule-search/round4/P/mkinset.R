# Writes the fixed-inset (12 d) form of a09's c and f schedules for all ten cases.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
tot <- c(0, 0, 0, 0)
for (cs in ALL) for (sd in c("c", "f")) { S <- sched(cs, sd); I <- inset_rule(S, cs); saveRDS(as.numeric(I), file.path(POUT, "sched", sprintf("ins%s_%s.rds", sd, cs)))
  et <- edge_table(cs); stopifnot(!any(is_edge(I, et$b)))
  A <- anatomy(I[I < 25], cs); open_gap <- sum(A$E > 0 & A$open > 0 & (A$gap_lo > 0.5 | A$gap_hi > 0.5), na.rm = TRUE)
  cat(sprintf("%-13s %s: %3d -> %3d (strip interior dropped %d, short-spell merges %d) | min gap between nodes %.1f d | intervals whose node sits in a gap next to births: %d | proxy %.3f -> %.3f\n", cs, sd, length(S), length(I),
    attr(I, "dropped_interior"), sum(et$spell < 24 & et$opening), min(diff(I)) * 365, open_gap, proxy(cs, S), proxy(cs, I)))
  tot <- tot + if (sd == "c") c(length(S), length(I), 0, 0) else c(0, 0, length(S), length(I)) }
cat("all ten: c", tot[1], "->", tot[2], "; f", tot[3], "->", tot[4], "\n")
