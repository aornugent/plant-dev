# mk_sched.R: E6+ ladder schedules (s = 1.6, 1, 1/1.6) for the bank and the held-out cases.
# Guard: with edge nodes off and s = 1, ep_sched reproduces E6's committed schedule exactly
# (the bank's insc_ and the held-out round's c_ schedules); with them off at s = 1.6 it
# reproduces the H1 round's insx12_ where saved.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/loop/lib.R")
H1S <- file.path(SP, "deep/rootcause/h1/sched")
for (cs in c(BANK, HELD)) {
  a <- if (cs %in% BANK) readRDS(file.path(POUT, "sched", sprintf("insc_%s.rds", cs))) else readRDS(file.path(HO_OUT, "sched", sprintf("c_%s.rds", cs)))
  b <- ep_sched(cs, 1, edges = FALSE); stopifnot(identical(as.numeric(a), b))
  f <- file.path(H1S, sprintf("insx12_%s.rds", cs)); if (file.exists(f)) stopifnot(identical(as.numeric(readRDS(f)), ep_sched(cs, 1.6, edges = FALSE)))
  n <- sapply(c(1.6, 1, 1 / 1.6), function(s) { S <- ep_sched(cs, s); nm <- sprintf("ep%.3f_%s", s, cs); prep(cs, S, nm); length(S) })
  et <- edge_table(cs); added <- length(ep_sched(cs, 1)) - length(b)
  cat(sprintf("%-14s E6 committed %d identical | E6+ x/c/f %d/%d/%d (+%d edge nodes before 10; %d edges before 10)%s\n", cs, length(a), n[1], n[2], n[3], added,
    sum(et$b < 10), if (file.exists(f)) " | insx12 identical" else ""))
}
