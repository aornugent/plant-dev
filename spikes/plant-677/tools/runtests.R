args <- commandArgs(TRUE); dir <- args[1]; pkg <- args[2]; pat <- if (length(args) > 2) args[3] else NULL
Sys.setenv(TESTTHAT_PARALLEL = "false", NOT_CRAN = "true")
suppressMessages(library(testthat))
r <- testthat::test_dir(dir, package = pkg, load_package = "installed", filter = pat,
                        reporter = "silent", stop_on_failure = FALSE, stop_on_warning = FALSE)
d <- as.data.frame(r)
cat(sprintf("%s: files=%d tests=%d failed=%d skipped=%d errors=%d\n", Sys.getenv("ARM"), length(unique(d$file)), nrow(d), sum(d$failed > 0), sum(d$skipped), sum(d$error)))
bad <- d[d$failed > 0 | d$error, c("file", "test")]
if (nrow(bad)) { cat("NOT PASSING:\n"); print(bad, row.names = FALSE) }
