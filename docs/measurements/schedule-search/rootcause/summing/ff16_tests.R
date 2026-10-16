# ff16_tests.R: test-strategy-ff16.R and test-strategy-ff16-reference-comparison.R against
# lib1 with PLANT_SIMPSON as set in the environment; each failing expectation listed.
lib <- Sys.getenv("LIB"); .libPaths(c(lib, .libPaths()))
suppressMessages({ library(odelia, lib.loc = lib); library(plant, lib.loc = lib); library(testthat) })
d <- commandArgs(TRUE)[1]  # a scratch copy of plant/tests/testthat
setwd(d)
for (f in c("test-strategy-ff16.R", "test-strategy-ff16-reference-comparison.R")) {
  r <- as.data.frame(testthat::test_file(f, reporter = "silent", package = "plant", load_package = "none"))
  cat(sprintf("%s [PLANT_SIMPSON=%s]: %d tests, %d expectations, failed %d, errors %d, skipped %d\n", f, Sys.getenv("PLANT_SIMPSON"), nrow(r), sum(r$nb), sum(r$failed), sum(r$error), sum(r$skipped)))
  for (i in which(r$failed > 0 | r$error)) cat("   FAIL:", r$test[i], "\n")
}
