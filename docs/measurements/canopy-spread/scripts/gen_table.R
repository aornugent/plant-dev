# One line per (case, scheme): the invader's lma elasticity on each rung found, J,
# the u108 -> u215 move's field and interpolation parts (all, and born before 0.5),
# and, with three rungs, the ratio of successive moves and the extrapolation.
# Usage: Rscript gen_table.R PREFIX [PREFIX ...]   (files runs/PREFIX_{lumped,spread}_{u108,u215,u429}.rds)
wt <- "/home/user/plant-dev/.claude/worktrees/agent-a2ac0b96ecd6256ba"
runs <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb/runs"
source(file.path(wt, "harness/node_parts.R"))
el <- function(x) { J <- vapply(x$invader, `[[`, 0, "J"); (J[["plus"]] - J[["minus"]]) / (2 * x$u * x$stand$J) }
rows <- list()
for (pre in commandArgs(TRUE)) for (s in c("lumped", "spread")) {
  f <- file.path(runs, sprintf("%s_%s_%s.rds", pre, s, c("u108", "u215", "u429")))
  ok <- file.exists(f)
  if (!ok[1] || !ok[2]) next
  x <- lapply(f[ok], readRDS)
  e <- vapply(x, el, 0); J <- vapply(x, function(v) v$stand$J, 0)
  em <- elasticity_moves(x[[1]], x[[2]]); top <- em[, "birth"] < 0.5
  line <- data.frame(case = pre, scheme = s, el = paste(sprintf("%.4f", e), collapse = " "),
                     J = paste(sprintf("%.5f", J), collapse = " "),
                     field = sprintf("%+.4f (%+.4f)", sum(em[, "field"]), sum(em[top, "field"])),
                     interp = sprintf("%+.4f (%+.4f)", sum(em[, "interpolation"]), sum(em[top, "interpolation"])),
                     ratio = NA, extrapolated = NA, stringsAsFactors = FALSE)
  if (length(x) == 3) {
    em2 <- elasticity_moves(x[[2]], x[[3]]); top2 <- em2[, "birth"] < 0.5
    line$ratio <- sprintf("%.2f | field %.1f (top %.1f) | interp %.1f (top %.1f)", (e[1] - e[2]) / (e[2] - e[3]),
                          sum(em[, "field"]) / sum(em2[, "field"]), sum(em[top, "field"]) / sum(em2[top2, "field"]),
                          sum(em[, "interpolation"]) / sum(em2[, "interpolation"]),
                          sum(em[top, "interpolation"]) / sum(em2[top2, "interpolation"]))
    line$extrapolated <- sprintf("%.4f", e[3] + (e[3] - e[2]) / 3)
  }
  rows[[length(rows) + 1]] <- line
}
if (length(rows)) print(do.call(rbind, rows), row.names = FALSE)
