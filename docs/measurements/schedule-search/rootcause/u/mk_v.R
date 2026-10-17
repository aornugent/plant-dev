# mk_v.R CASE...: the fix V, U with every stretch at least W = 90 d wide given at least
# ceiling(3 / s) intervals; kinds V16 / V10 / V06.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/u/lib.R")
for (cs in commandArgs(TRUE)) { n <- sapply(names(SK), function(k) { S <- as.numeric(u_sched(cs, SK[[k]], n0 = 3, W = 90)); saveRDS(S, file.path(UOUT, "sched", sprintf("V%s_%s.rds", k, cs))); length(S) })
  cat(cs, "V nodes x/c/f", paste(n, collapse = "/"), "\n") }
