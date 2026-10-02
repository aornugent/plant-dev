# J's move between two invader_nodes.R-style runs of the stand, per panel
# (node_parts.R's panel_moves), in percent of the coarser J: field and
# interpolation parts, all and born before 0.5, and the top two nodes' field part
# over their own contribution. Usage: Rscript j_parts.R a.rds b.rds [c.rds]
source("/home/user/plant-dev/.claude/worktrees/agent-a2ac0b96ecd6256ba/harness/node_parts.R")
f <- commandArgs(TRUE); x <- lapply(f, readRDS)
st <- function(x) nodes_of(list(setting = x$setting, stand = list(nodes = x$stand)))
for (i in seq_len(length(x) - 1)) {
  a <- st(x[[i]]); b <- st(x[[i + 1]]); pm <- panel_moves(a, b); J <- sum(a$w * a$offspring)
  top <- pm$birth < 0.5; own <- a$w * a$offspring
  cat(sprintf("%s -> %s: J %.6f -> %.6f | field %+.3f%% (b<0.5 %+.3f%%) | interp %+.3f%% (b<0.5 %+.3f%%) | top nodes' field %.2f%%, %.2f%% of own\n",
              basename(f[i]), basename(f[i + 1]), x[[i]]$stand$J, x[[i + 1]]$stand$J,
              100 * sum(pm$field) / J, 100 * sum(pm$field[top]) / J, 100 * sum(pm$interpolation) / J,
              100 * sum(pm$interpolation[top]) / J, 100 * pm$field[1] / own[1], 100 * pm$field[2] / own[2]))
}
