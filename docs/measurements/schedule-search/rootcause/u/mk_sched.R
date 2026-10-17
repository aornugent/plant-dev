# mk_sched.R CASE...: U's ladder schedules (s = 1.6, 1, 1/1.6; kinds U16/U10/U06). Guard: the
# changed h5_sched reproduces the H5 round's U schedules on dry and dry-flat.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/u/lib.R")
for (cs in c("dry", "dry-flat")) for (k in names(SK)) { a <- readRDS(file.path(UOUT, "sched", sprintf("U%s_%s.rds", k, cs))); b <- as.numeric(u_sched(cs, SK[[k]]))
  stopifnot(length(a) == length(b), max(abs(a - b)) < 1e-12) }
cat("guard: U on dry and dry-flat reproduced\n")
for (cs in commandArgs(TRUE)) { n <- sapply(names(SK), function(k) { S <- as.numeric(u_sched(cs, SK[[k]])); stopifnot(all(diff(S) > 1e-6))
  saveRDS(S, file.path(UOUT, "sched", sprintf("U%s_%s.rds", k, cs))); length(S) })
  e6 <- length(readRDS(file.path(POUT, "sched", sprintf("insc_%s.rds", cs))))
  cat(sprintf("%-13s U nodes x/c/f %s | E6 committed %d\n", cs, paste(n, collapse = "/"), e6)) }
