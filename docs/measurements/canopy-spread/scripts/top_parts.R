# Per-node parts of the invader's lma elasticity move at the top of the layer,
# and the square-law check: each part's ratio between successive moves.
# Usage: Rscript top_parts.R a.rds b.rds [c.rds]
wt <- "/home/user/plant-dev/.claude/worktrees/agent-a2ac0b96ecd6256ba"
source(file.path(wt, "harness/node_parts.R"))
f <- commandArgs(TRUE)
x <- lapply(f, readRDS)
ems <- lapply(seq_len(length(x) - 1), function(i) elasticity_moves(x[[i]], x[[i + 1]]))
for (i in seq_along(ems)) {
  em <- ems[[i]]
  cat(sprintf("\n%s -> %s, first 6 coarse nodes (birth, field, establishment, interpolation):\n",
              basename(f[i]), basename(f[i + 1])))
  print(round(head(em, 6), 4))
  bands <- c(-1, 0.5, 1, 3.5, 41)
  b <- cut(em[, "birth"], bands, right = FALSE)
  print(rbind(field = tapply(em[, "field"], b, sum), interpolation = tapply(em[, "interpolation"], b, sum)))
}
if (length(ems) == 2) {
  r <- function(k, sel) sum(ems[[1]][sel(ems[[1]]), k]) / sum(ems[[2]][sel(ems[[2]]), k])
  all <- function(e) rep(TRUE, nrow(e)); top <- function(e) e[, "birth"] < 0.5; rest <- function(e) e[, "birth"] >= 0.5
  cat(sprintf("\nratio of moves: field all %.2f, top %.2f, rest %.2f | interpolation all %.2f, top %.2f, rest %.2f\n",
              r("field", all), r("field", top), r("field", rest), r("interpolation", all),
              r("interpolation", top), r("interpolation", rest)))
}
