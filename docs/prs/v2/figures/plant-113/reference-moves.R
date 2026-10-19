# How many rows of tests/testthat/reference/reference-gradient.tsv move between
# two commits: rows matched on regime, species, parameter and metric; a row
# moves when its converged value changes by more than 1e-3 of the largest
# |converged| for its regime and metric.
#   Rscript reference-moves.R <plant clone> <old commit> <new commit>
args <- commandArgs(TRUE)
rd <- function(c) {
  x <- read.delim(pipe(sprintf("git -C %s show %s:tests/testthat/reference/reference-gradient.tsv",
                               args[[1]], c)), colClasses = "character")
  x$converged <- suppressWarnings(as.numeric(x$converged)); x
}
A <- rd(args[[2]]); B <- rd(args[[3]])
k <- c("regime", "species", "parameter", "metric")
m <- merge(A[, c(k, "converged")], B[, c(k, "converged")], by = k, suffixes = c(".old", ".new"))
scale <- ave(abs(m$converged.new), m$regime, m$metric, FUN = function(x) max(x, na.rm = TRUE))
moved <- abs(m$converged.new - m$converged.old) > 1e-3 * scale
moved[is.na(moved)] <- FALSE
cat(sprintf("rows %d -> %d, matched %d, identical %d, moved %d\n", nrow(A), nrow(B), nrow(m),
            sum(m$converged.old == m$converged.new, na.rm = TRUE), sum(moved)))
print(table(regime = m$regime[moved])); print(sort(table(parameter = m$parameter[moved]), decreasing = TRUE))
x <- m[moved, ]; x$relative <- abs(x$converged.new - x$converged.old) / scale[moved]
print(x[order(-x$relative), ][seq_len(min(8, nrow(x))), ], row.names = FALSE)
