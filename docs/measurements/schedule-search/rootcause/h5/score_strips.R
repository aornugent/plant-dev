# score_strips.R: the fixed strips' own error on dry, -(N10r - N10) (no order assumed), and the
# jitter floor under H5, N10@jit - N10 (tolerance 1.05e-4 against 1e-4).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/score_lib.R")
cs <- if (length(commandArgs(TRUE))) commandArgs(TRUE)[1] else "dry"
c0 <- h5_run(sprintf("h5_N10_%s", cs)); r <- h5_run(sprintf("h5_N10r_%s", cs)); j <- h5_run(sprintf("h5_N10@jit_%s", cs))
if (!is.null(r)) { e <- -mv(r, c0); cat(sprintf("fixed strips' error -(N10r - N10), %s (N10r %d nodes, rows %.0f): %s\n   leaf rms %.3f hyd rms %.3f | max over quantities %.3f (eps/10 = 0.1) | n over 0.1: %d\n", cs, length(r$node_times), rows_of(r), fmt1(e),
  r2(e[intersect(LEAF, names(e))]), r2(e[intersect(HYD, names(e))]), max(abs(e)), sum(abs(e) > 0.1))) }
if (!is.null(j)) { e <- mv(j, c0); cat(sprintf("jitter N10@jit - N10, %s: %s | leaf rms %.3f hyd rms %.3f\n", cs, fmt1(e), r2(e[intersect(LEAF, names(e))]), r2(e[intersect(HYD, names(e))]))) }
