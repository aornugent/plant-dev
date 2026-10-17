# mk_var.R: W and V schedules. N20 (s = 2) for the three cases; on dry N1 (kind M), N1 from
# b = 17 with E6's inset after (kind T), and C (opening inset fixed 12 d; kind C).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/lib.R")
put <- function(S, k, cs) { stopifnot(all(diff(S) > 1e-6)); saveRDS(as.numeric(S), file.path(H5, "sched", sprintf("%s_%s.rds", k, cs))); cat(sprintf("%s_%s %d\n", k, cs, length(S))) }
for (cs in c("dry", "long-wet", "episodic-lma")) put(h5_sched(cs, 2, "node"), "N20", cs)
sk <- c("16" = 1.6, "10" = 1, "06" = 1 / 1.6)
for (k in names(sk)) { s <- sk[[k]]; put(h5_sched("dry", s, "node1"), paste0("M", k), "dry"); put(h5_sched("dry", s, "node1", tcut = 17), paste0("T", k), "dry")
  put(h5_sched("dry", s, "inset", d_o = 12), paste0("C", k), "dry") }
# U (added after V): M with E6's inset from b = 10, on dry and dry-flat.
for (cs in c("dry", "dry-flat")) for (k in names(sk)) put(h5_sched(cs, sk[[k]], "node1", tcut = 10), paste0("U", k), cs)
