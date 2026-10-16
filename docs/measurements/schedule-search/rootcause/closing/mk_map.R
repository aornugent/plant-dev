# mk_map.R CASE: a fate map for the derivation check, forward only. The committed insk
# schedule with each long spell's (> 60 d) last 120 d re-noded every 3 d up to its closing
# edge c (the edge a node), and zero-weight probes every 5 d through the gap that follows
# (to 3 d before the next opening edge). Nodes elsewhere unchanged.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
cs <- commandArgs(TRUE)[1]; S <- sort(rd(sprintf("val_insk_c_%s", cs))$node_times)
et <- edge_table(cs); b1 <- PIL[[cs]]$b1; ce <- et[!et$opening & et$b > b1 & et$spell > 60, ]; op <- et$b[et$opening]
add <- c(); drop <- rep(FALSE, length(S))
for (i in seq_len(nrow(ce))) { c0 <- ce$b[i]; a <- max(c(b1, op[op < c0])); lo <- max(a + 12 / 365, c0 - 120 / 365)
  drop <- drop | (S >= lo - 1e-9 & S <= c0 + 1e-9); add <- c(add, rev(seq(c0, lo, by = -3 / 365)))
  nx <- min(c(op[op > c0], 25)); if ((nx - c0) * 365 > 6) add <- c(add, seq(c0 + 2 / 365, nx - 3 / 365, by = 5 / 365)) }
out <- sort(unique(round(c(S[!drop], add), 10))); out <- out[c(TRUE, diff(out) > 0.5 / 365)]
saveRDS(as.numeric(out), file.path(CL, "sched", sprintf("map_%s.rds", cs)))
cat(sprintf("%s: %d long-spell closing edges, %d nodes (committed %d)\n", cs, nrow(ce), length(out), length(S)))
