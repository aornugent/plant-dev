# plant's full serial sweep (AGENTS.md tier 4) under load_all, one file at a time:
# each file's passes, failures, errors, skips and seconds, and every failure.
# Usage: Rscript sweep.R PLANT_SRC
library(odelia)
src <- commandArgs(TRUE)[[1]]
pkgload::load_all(src, quiet = TRUE)
Sys.setenv(TESTTHAT_PARALLEL = "false")
d <- file.path(src, "tests", "testthat")
rows <- list()
for (f in list.files(d, "^test-.*\\.[Rr]$")) {
  t0 <- proc.time()[["elapsed"]]
  r <- as.data.frame(testthat::test_file(file.path(d, f), reporter = "silent",
                                         stop_on_failure = FALSE))
  s <- proc.time()[["elapsed"]] - t0
  bad <- r[r$failed > 0 | r$error, , drop = FALSE]
  cat(sprintf("%-55s passed %4d failed %2d error %2d skipped %2d %6.1fs\n", f,
              sum(r$passed), sum(r$failed), sum(r$error), sum(r$skipped), s))
  for (i in seq_len(nrow(bad))) cat("   FAIL:", bad$test[i], "\n")
  rows[[f]] <- r
}
all <- do.call(rbind, rows)
cat(sprintf("TOTAL passed %d failed %d error %d skipped %d\n", sum(all$passed),
            sum(all$failed), sum(all$error), sum(all$skipped)))
