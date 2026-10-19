# Whole game, as it appears in comment 1. Run from the odelia checkout.
library(odelia)
testthat::source_test_helpers("tests/testthat", env = globalenv())
toy <- parse("tests/testthat/test-substeps.R")
for (e in toy[1:4]) eval(e)  # the System, its compiler, its parameters
compile_substep_interface()

pars <- store_pars  # a = 1, m = 0.8, K = 1e4, s0 = 200, c = 0.3
y0 <- store_y       # x = 1, w1 = 0.5, w2 = 0.5
reference <- store_plain_run(1e-12, 2.0, pars, y0)
plain <- store_plain_run(1e-6, 2.0, pars, y0)
substepped <- store_run(0.1, 1e-6, 2.0, pars, y0)

c(plain = plain$steps, substepped = substepped$steps)
c(plain = max(abs(plain$y - reference$y)),
  substepped = max(abs(substepped$y - reference$y)))
substepped$substeps / substepped$substepped
