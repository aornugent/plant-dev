# q1_score.R: Q1. The committed error e_c, the closing regions' error -(res - c), the
# bisection's -4/3 (bisC - c), and on dry res2x - res (res's own residual check).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
for (cs in c("dry", "dry-p50", "dry-flat", "long-wet")) { c0 <- rd(sprintf("val_insk_c_%s", cs)); ec <- err_run(c0, cs)
  cat(sprintf("== %s\n  e_c               %s\n", cs, fmt(ec)))
  for (k in c("res", "bisC", "res2x")) { f <- file.path(CL, "runs", sprintf("cl_%s_%s.rds", k, cs)); if (!file.exists(f)) next; x <- readRDS(f); if (is.null(x$stand$elasticity)) next
    m <- mv_run(x, c0); v <- if (k == "bisC") -4 / 3 * m else -m
    cat(sprintf("  %-17s %s\n", c(res = "region -(res-c)", bisC = "-4/3 (bisC-c)", res2x = "-(res2x-c)")[k], fmt(v, ec)))
    if (k == "res") cat(sprintf("  e_res             %s\n", fmt(err_run(x, cs))))
    if (k == "res2x") cat(sprintf("  res2x - res       %s\n", fmt(mv_run(x, readRDS(file.path(CL, "runs", sprintf("cl_res_%s.rds", cs)))))))
    cat(sprintf("     (%s: %d nodes, %.0f rows, cpu %.0f + %.0f s)\n", k, length(x$node_times), x$stand$rows, x$stand$cpu, x$sweep_cpu)) } }
