# stretch.R CASE...: per spell before 25 (after b1), the number of intervals in its scaled
# stretch [o + 12, c - 12] at s = 2, 1.6, 1, 1/1.6 (rule N): how many spells do not refine
# between rungs.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/lib.R")
for (cs in commandArgs(TRUE)) { et <- edge_table(cs); b1 <- pilot_of(cs)$b1; op <- et[et$opening & et$b > b1, ]
  S <- lapply(c(2, 1.6, 1, 1 / 1.6), function(s) h5_sched(cs, s, "node"))
  n <- t(sapply(seq_len(nrow(op)), function(i) { o <- op$b[i]; c0 <- o + op$spell[i] / 365; sapply(S, function(G) sum(G > o + 12 * D + 1e-9 & G < c0 - 12 * D - 1e-9) + 1) }))
  long <- op$spell >= 26; n <- n[long, , drop = FALSE]
  cat(sprintf("%-13s spells >= 26 d after b1: %d | intervals per stretch, median s=2/1.6/1/0.625: %s | stretches with 1 interval: %s | same count 1.6 vs 1: %d, 1 vs 0.625: %d, 2 vs 1.6: %d\n",
    cs, nrow(n), paste(apply(n, 2, median), collapse = "/"), paste(colSums(n == 1), collapse = "/"), sum(n[, 2] == n[, 3]), sum(n[, 3] == n[, 4]), sum(n[, 1] == n[, 2]))) }
