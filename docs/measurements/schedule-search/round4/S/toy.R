# The store toy of odelia's test-substeps.R under pulses of inflow: each run's
# distance from the reference and its steps. Run from the odelia source root,
# with the odelia under test installed.
library(odelia)
setwd("tests/testthat")
source("helper-load-odelia.R")
ex <- parse("test-substeps.R")
for (e in ex) if (!grepl("^testthat::test_that", deparse(e)[1])) eval(e, globalenv())
compile_substep_interface()
slow <- store_pars * c(1, 1, 1e-3, 1, 1)
for (t_end in c(1, 2)) {
  knots <- pulse_knots[pulse_knots < t_end]
  ref <- store_pulsed_run(0.0, 1e-11, c(0, knots, t_end), slow, store_y, pulse_x, pulse_y)$y
  for (share in c(0, 0.1)) for (tol in c(1e-4, 1e-5, 1e-6)) {
    st <- store_pulsed_run(share, tol, c(0, knots, t_end), slow, store_y, pulse_x, pulse_y)
    fr <- store_pulsed_run(share, tol, c(0, t_end), slow, store_y, pulse_x, pulse_y)
    cat(sprintf("t_end %g share %.1f tol %g: stopped %d steps (%d substepped) err %.2e | free %d steps (%d substepped) err %.2e\n",
                t_end, share, tol, st$steps, sum(st$substepped), max(abs(st$y - ref)),
                fr$steps, sum(fr$substepped), max(abs(fr$y - ref))))
  }
}
