# Per-panel test: refine a few panels of uniform 108 and compare the measured
# field and interpolation parts with the u108 sweep's prediction for those panels.
#
#   Rscript compare_partial.R SWEEP.rds PLAIN1.rds [PLAIN2.rds ...]
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap"
.libPaths(c(file.path(A, "lib"), .libPaths()))
suppressMessages(library(plant))
source(file.path(A, "harness", "node_parts.R"))
args <- commandArgs(TRUE)
sw <- readRDS(args[1])
setting <- list(lifetime = 40)
nodes <- function(x) nodes_of(list(setting = setting, stand = list(nodes = x$base$nodes)))
a <- nodes(sw); J <- sw$base$J; Jn <- sum(a$w * a$offspring)
L <- colSums(sw$light); S <- colSums(sw$soil)
for (f in args[-1]) {
  x <- readRDS(f); b <- nodes(x)
  pm <- panel_moves(a, b)
  extra <- setdiff(round(b$birth, 10), round(a$birth, 10))
  panels <- findInterval(extra, a$birth)
  cat(sprintf("%s: %d panels refined (%s); J %.8f -> %.8f (%+.4f%%)\n", basename(f), length(panels),
              paste(range(panels), collapse = "-"), J, x$base$J, 100 * (x$base$J - J) / J))
  cat(sprintf("  measured: field %+.4f%%, interpolation %+.4f%%, establishment %+.5f%%\n",
              100 * sum(pm$field) / Jn, 100 * sum(pm$interpolation) / Jn, 100 * sum(pm$establishment) / Jn))
  cat(sprintf("  predicted field, those panels: light %+.4f%%, soil %+.4f%%, total %+.4f%%; ratio %.3f\n",
              100 * sum(L[panels]) / J, 100 * sum(S[panels]) / J, 100 * sum(L[panels] + S[panels]) / J,
              (sum(L[panels] + S[panels]) / J) / (sum(pm$field) / Jn)))
}
