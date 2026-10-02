# A run_record_probe.R output: its phases, failures, the sweeps' replayed values
# against J (equal when the sweep differentiates the run it replays), and the
# invader's lma elasticity beside a central-difference run on the same schedule.
# Usage: Rscript check_full.R full.rds [inv_probe.rds]
f <- commandArgs(TRUE); x <- readRDS(f[1])
cat(sprintf("%s: %d nodes, probe [%s]\n", basename(f[1]), length(x$node_times),
            paste(names(x$setting$probe), x$setting$probe, sep = "=", collapse = " ")))
cat("phases (s):", paste(names(x$phases), sprintf("%.0f", vapply(x$phases, `[[`, 0, "secs")), collapse = ", "), "\n")
if (length(x$failures)) { cat("failures:\n"); print(x$failures) }
for (r in c("stand", "invader")) if (!is.null(x[[r]]$value))
  cat(sprintf("%-7s J %.12g  sweep value - J %.3g  refusal %s  lma elasticity %.5f\n", r, x[[r]]$J,
              x[[r]]$value - x[[r]]$J, paste(x[[r]]$refusal, collapse = ","), x[[r]]$elasticity[[1]]))
if (length(f) > 1) {
  y <- readRDS(f[2]); J <- vapply(y$invader, `[[`, 0, "J")
  cat(sprintf("central difference run: stand J %.12g (diff %.3g relative), invader lma %.5f\n", y$stand$J,
              x$stand$J / y$stand$J - 1, (J[["plus"]] - J[["minus"]]) / (2 * y$u * y$stand$J)))
}
