# Part 2, mechanism: does bisecting below a flagged node actually reduce that
# node's refinement error?  Trace, pass by pass, WHICH nodes are flagged (their
# introduction times and error values) in each coordinate.  If the same handful
# of nodes stays flagged while the schedule grows, refinement is stalled rather
# than lax.
source("/home/user/plant-dev/probes/40-lib.R")
a <- commandArgs(TRUE); model <- a[1]; eps <- as.numeric(a[2]); npass <- as.integer(a[3])
res <- list()
for (bd in c(FALSE, TRUE)) {
  scm <- make_scm(model, bd, eps, npass)
  scm$collect_refinement_errors <- TRUE
  tt <- scm$parameters$node_schedule_times[[1]]
  for (it in seq_len(npass)) {
    scm$run()
    e <- scm$refinement_error_by_node[[1]]
    rp <- scm$net_reproduction_ratio_errors[[1]]
    fl <- which(is.finite(e) & e > eps)
    res[[length(res)+1]] <- data.frame(bd = bd, iter = it, n = length(tt),
      value = scm$offspring_production[[1]], nflag = length(fl),
      t_flag = if (length(fl)) tt[fl] else NA_real_,
      e_flag = if (length(fl)) e[fl] else NA_real_,
      rep_flag = if (length(fl)) rp[fl] else NA_real_,
      max_e = max(e[is.finite(e)]), max_rep = max(rp[is.finite(rp)]))
    cat(sprintf("%s iter %2d n=%-4d val=%-12.7g nflag=%-3d maxE=%-10.4g maxRep=%-10.4g flagged t: %s\n",
      if (bd) "bd" else "ht", it, length(tt), scm$offspring_production[[1]], length(fl),
      max(e[is.finite(e)]), max(rp[is.finite(rp)]),
      paste(sprintf("%.4g(%.3g)", tt[fl], e[fl]), collapse=" ")))
    flush.console()
    if (!length(fl)) break
    tt <- bisect_flagged(tt, seq_along(tt) %in% fl)
    scm$reset(); scm$set_node_schedule_times(list(tt))
  }
  saveRDS(do.call(rbind, res), sprintf("/home/user/plant-dev/probes/out/50-stall-%s.rds", model))
}
cat("DONE\n")
