# The first run at a looser tolerance: its CPU, and how far the schedule it builds moves.
#   PLANT_LIB=<lib> Rscript first_tol.R CASE OUT TOL...
a <- commandArgs(TRUE); CASE <- a[1]; OUT <- a[2]; tols <- as.numeric(a[-(1:2)])
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine2/perf/common.R")
cs <- case_setup(CASE); pars <- cs$p$strategies[[1]]$pars
res <- list()
for (tol in tols) {
  c2 <- cs; c2$ctrl$ode_tol_rel <- tol; c2$ctrl$ode_tol_abs <- tol * 1e-4
  f <- timed_run(c2, seq(0, HORIZON, length.out = 100), gradient = FALSE, records = TRUE, label = sprintf("first %g", tol))
  sch <- schedule_of(f, pars, 1)
  res[[as.character(tol)]] <- list(cpu = f$cpu, meta = f$meta, spells = sch$spells[c("edges", "b1", "t50", "t90")],
                                   S = nodes_of(sch, 0), half = nodes_of(sch, 0, half = TRUE))
  saveRDS(res, OUT)
}
ref <- res[[1]]
for (r in res[-1]) {
  same <- length(r$S) == length(ref$S)
  cat(sprintf("nodes %d vs %d; replay %d vs %d; edges %d vs %d, worst edge shift %.2f d; t50 %+.2f d, t90 %+.2f d; worst node shift %s d\n",
              length(r$S), length(ref$S), length(r$half), length(ref$half), length(r$spells$edges), length(ref$spells$edges),
              if (length(r$spells$edges) == length(ref$spells$edges)) 365 * max(abs(r$spells$edges - ref$spells$edges)) else NA,
              365 * (r$spells$t50 - ref$spells$t50), 365 * (r$spells$t90 - ref$spells$t90),
              if (same) sprintf("%.2f (median spacing %.1f)", 365 * max(abs(r$S - ref$S)), 365 * median(diff(ref$S))) else "n/a"))
}
