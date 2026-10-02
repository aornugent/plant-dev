# Print the invader's lma elasticity and its moves split per panel, for a ladder
# of invader_nodes.R runs. Usage: Rscript moves.R a.rds b.rds [c.rds ...]
wt <- "/home/user/plant-dev/.claude/worktrees/agent-a2ac0b96ecd6256ba"
source(file.path(wt, "harness/node_parts.R"))
f <- commandArgs(TRUE)
x <- lapply(f, readRDS)
el <- function(x) {
  J <- vapply(x$invader, `[[`, 0, "J")
  (J[["plus"]] - J[["minus"]]) / (2 * x$u * x$stand$J)
}
for (i in seq_along(x))
  cat(sprintf("%-28s %4d nodes  J %.8f  invader lma elasticity %.5f\n", basename(f[i]),
              length(x[[i]]$node_times), x[[i]]$stand$J, el(x[[i]])))
for (i in seq_len(length(x) - 1)) {
  em <- elasticity_moves(x[[i]], x[[i + 1]])
  top <- em[, "birth"] < 0.5
  cat(sprintf("%s -> %s: net %+.4f (el diff %+.4f) | field %+.4f (b<0.5 %+.4f) | estab %+.4f | interp %+.4f (b<0.5 %+.4f)\n",
              basename(f[i]), basename(f[i + 1]), sum(em[, -1]), el(x[[i + 1]]) - el(x[[i]]),
              sum(em[, "field"]), sum(em[top, "field"]), sum(em[, "establishment"]),
              sum(em[, "interpolation"]), sum(em[top, "interpolation"])))
}
if (length(x) >= 3) {
  e <- vapply(x, el, 0)
  for (i in seq_len(length(x) - 2)) {
    a <- elasticity_moves(x[[i]], x[[i + 1]]); b <- elasticity_moves(x[[i + 1]], x[[i + 2]])
    ta <- a[, "birth"] < 0.5; tb <- b[, "birth"] < 0.5
    cat(sprintf("ratio of successive moves: elasticity %.3f | field %.2f (top %.2f) | interpolation %.2f (top %.2f)\n",
                (e[i] - e[i + 1]) / (e[i + 1] - e[i + 2]),
                sum(a[, "field"]) / sum(b[, "field"]), sum(a[ta, "field"]) / sum(b[tb, "field"]),
                sum(a[, "interpolation"]) / sum(b[, "interpolation"]),
                sum(a[ta, "interpolation"]) / sum(b[tb, "interpolation"])))
  }
}
