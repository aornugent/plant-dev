# mk_ladder.R RULE CASE...: H5 ladder schedules at s = 1.6, 1, 1/1.6 (kinds RULE16/10/06) and
# the committed rung with its fixed strips refined (RULE10r: every [c - 12 d, c] cut at 3 d,
# and in rule N every [o, o + 12 d] too).
#   N: opening edge a node plus a fixed node at o + 12 d;
#   S: opening inset scaled with the spacing, d_o = 12 s.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/lib.R")
a <- commandArgs(TRUE); RULE <- a[1]
mk <- function(cs, s) if (RULE == "N") h5_sched(cs, s, "node") else h5_sched(cs, s, "inset", d_o = 12 * s)
for (cs in a[-1]) { put <- function(S, k) { stopifnot(all(diff(S) > 1e-6)); saveRDS(as.numeric(S), file.path(H5, "sched", sprintf("%s%s_%s.rds", RULE, k, cs))); length(S) }
  n <- c(put(mk(cs, 1.6), "16"), put(S1 <- mk(cs, 1), "10"), put(mk(cs, 1 / 1.6), "06"))
  et <- edge_table(cs); has <- function(x) any(abs(S1 - x) < 1e-9); add <- c()
  for (c0 in et$b[!et$opening]) if (has(c0) && has(c0 - 12 * D)) add <- c(add, c0 - c(9, 6, 3) * D)
  if (RULE == "N") for (o in et$b[et$opening]) if (has(o) && has(o + 12 * D)) add <- c(add, o + c(3, 6, 9) * D)
  nr <- put(sort(unique(round(c(S1, add), 10))), "10r")
  cat(sprintf("%s %-13s nodes x/c/f %d/%d/%d, strips refined %d\n", RULE, cs, n[1], n[2], n[3], nr)) }
