# Run the reverse-sweep ladder and print where it stands.
#
#   Rscript tests/run-gradient-ladder.R            all rungs
#   Rscript tests/run-gradient-ladder.R floor      one file
#
# The ladder is a specification as much as a suite, so a red line is the point
# rather than a fault to route around. Each rung reports how much of its
# tolerance budget it used; a check passing at three-quarters of budget is a
# check about to stop working.
#
# Run from the plant-dev root. Build plant optimised first -- an unoptimised
# build makes the trajectory fixtures several times slower:
#
#   cd plant && make

suppressMessages({
  library(odelia)
  pkgload::load_all("plant", quiet = TRUE)
  library(testthat)
})

rungs <- c(
  floor         = "the objective, the decomposition family, and the zero classes",
  factorisation = "the one seam: the rows the reference and the sweep share",
  sweep         = "whether the sweep runs at all, and on which channels",
  rung3         = "one cohort, the Jacobian formed entirely",
  switches      = "one switch per route a parameter takes to a census",
  rung4         = "two species, two cohorts each, over a trajectory",
  rung5         = "introductions, where the state changes dimension")

selected <- commandArgs(trailingOnly = TRUE)
if (length(selected) == 0L) selected <- names(rungs)

results <- list()
for (name in selected) {
  path <- file.path("plant", "tests", "testthat",
                    paste0("test-gradient-ladder-", name, ".R"))
  cat(sprintf("\n===== %s -- %s\n", name, rungs[[name]]))
  out <- testthat::test_file(path, package = "plant", reporter = "summary")
  frame <- as.data.frame(out)
  results[[name]] <- c(
    pass = sum(frame$passed),
    fail = sum(frame$failed),
    skip = sum(frame$skipped),
    error = sum(frame$error))
}

cat("\n\n===== the ladder =====\n")
table <- do.call(rbind, results)
print(table)

blocked <- rownames(table)[table[, "skip"] > 0]
if (length(blocked) > 0) {
  cat("\nSkips are the ladder naming what it cannot yet ask. They are not\n",
      "passes: a rung whose checks were skipped has not been climbed.\n",
      sep = "")
}
