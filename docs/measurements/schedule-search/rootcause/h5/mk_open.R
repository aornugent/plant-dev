# mk_open.R CASE: the opening-edge step on one case, all at s = 1 with H5's closing
# treatment (c and c - 12 d nodes).
#   oin24 / oin12 / oin6 : opening inset d_o = 24, 12, 6 d (no node at o);
#   ores                 : the opening side resolved: a node at o, the strip [o, o + 12 d]
#                          at 3 d, and every spell under 26 d at <= 3 d (the reference for
#                          the opening treatment's error);
#   omap                 : fate map across opening edges (forward only): each opening edge
#                          after b1 with a gap > 8 d before it and a spell > 40 d after it
#                          gets gap probes at o - 6, -3, -1 d and nodes at o + {0, 1, 2, 3,
#                          4.5, 6, 8, 10, 12, 15, 18, 22, 26, 30, 36} d; base oin12.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/lib.R")
cs <- commandArgs(TRUE)[1]; et <- edge_table(cs); b1 <- PIL0 <- pilot_of(cs)$b1
put <- function(S, nm) { stopifnot(all(diff(S) > 1e-6)); saveRDS(as.numeric(S), file.path(H5, "sched", sprintf("%s_%s.rds", nm, cs))); cat(sprintf(" %s %d", nm, length(S))) }
cat(cs, ":")
for (d in c(24, 12, 6)) put(h5_sched(cs, 1, "inset", d_o = d), sprintf("oin%d", d))
S <- h5_sched(cs, 1, "node"); add <- c()
op <- et[et$opening, ]; cl <- et[!et$opening, ]
for (i in seq_len(nrow(op))) { o <- op$b[i]; L <- op$spell[i]
  if (L >= 26) add <- c(add, o + c(3, 6, 9) * D)
  else if (L > 4) add <- c(add, o + seq(0, L, length.out = ceiling(L / 3) + 1)[-c(1, ceiling(L / 3) + 1)] * D) }
put(sort(unique(round(c(S, add), 10))), "ores")
M <- h5_sched(cs, 1, "inset", d_o = 12); sel <- op[op$b > b1 & op$gap > 8 & op$spell > 40, ]
for (o in sel$b) { M <- M[!(M > o - 8 * D & M < o + 37 * D)]; M <- c(M, o + c(-6, -3, -1, 0, 1, 2, 3, 4.5, 6, 8, 10, 12, 15, 18, 22, 26, 30, 36) * D) }
put(sort(unique(round(M, 10))), "omap"); cat(sprintf(" | %d mapped opening edges\n", nrow(sel)))
