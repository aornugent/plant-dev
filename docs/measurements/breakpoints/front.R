# Fate fronts from one run: the largest jumps in cumulative mortality (at the
# run's end) between neighbouring nodes, and where they sit.
args <- commandArgs(TRUE)
for (f in args) {
  n <- readRDS(f)$stand$nodes; b <- n$birth; m <- n$mortality; k <- length(b)
  dm <- diff(m); o <- order(-abs(dm))[1:3]
  cat(sprintf("%-28s %4d nodes | largest |dm| %s\n", basename(f), k,
      paste(sprintf("%.2f at [%.2f, %.2f] d", abs(dm[o]), 365 * b[o], 365 * b[o + 1]), collapse = "; ")))
}
