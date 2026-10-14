# refine.R CASE: how the check refines each committed interval (f nodes strictly inside),
# weighted by establishment under each gate (lib19's and libAG's committed runs).
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
cs <- commandArgs(TRUE)[1]; tags <- commandArgs(TRUE)[-1]; if (!length(tags)) tags <- "a09"
for (tg in tags) {
  pr <- switch(tg, a09 = list(c19 = rd_run("a09", "c", cs), f19 = rd_run("a09", "f", cs), cAG = ag_run(sprintf("AG_a09c_%s", cs))),
                   ins = list(c19 = ag_run(sprintf("P_insc_%s", cs)), f19 = ag_run(sprintf("P_insf_%s", cs)), cAG = ag_run(sprintf("AG_insc_%s", cs))))
  S <- pr$c19$node_times; F <- pr$f19$node_times; n <- length(S)
  inside <- vapply(seq_len(n - 1), function(i) sum(F > S[i] + 1e-9 & F < S[i + 1] - 1e-9), 1L)
  nested <- mean(vapply(S, function(s) any(abs(F - s) < 1e-7), TRUE))
  E19 <- pr$c19$stand$nodes$establishment[1:(n - 1)]; EAG <- pr$cAG$stand$nodes$establishment[1:(n - 1)]
  cat(sprintf("%s %s: c %d nodes, f %d, c nodes in f %.0f%% | f nodes inside each c interval: %s\n", cs, tg, n, length(F), 100 * nested, paste(names(table(inside)), table(inside), sep = ":", collapse = " ")))
  for (m in sort(unique(inside))) cat(sprintf("   inside %d: intervals %3d, establishment share lib19 %.3f, libAG %.3f\n", m, sum(inside == m), sum(E19[inside == m]) / sum(E19), sum(EAG[inside == m]) / sum(EAG)))
}
