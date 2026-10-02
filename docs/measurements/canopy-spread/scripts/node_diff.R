# Two runs on the same schedule: each top node's relative change in the stand's
# offspring, and in its contribution to the invader's lma elasticity.
# Usage: Rscript node_diff.R base.rds probe.rds   (via rs.sh: needs plant)
source("/home/user/plant-dev/.claude/worktrees/agent-a2ac0b96ecd6256ba/harness/node_parts.R")
f <- commandArgs(TRUE); a <- readRDS(f[1]); b <- readRDS(f[2])
stopifnot(isTRUE(all.equal(a$node_times, b$node_times)))
at <- function(x, s) nodes_of(list(setting = x$setting, stand = list(nodes = x$invader[[s]])))
el_node <- function(x) {
  p <- at(x, "plus"); m <- at(x, "minus")
  (p$w * p$offspring - m$w * m$offspring) / (2 * x$u) / sum(m$w * m$offspring)
}
st <- function(x) nodes_of(list(setting = x$setting, stand = list(nodes = x$stand)))
ea <- el_node(a); eb <- el_node(b); sa <- st(a); sb <- st(b)
cat(sprintf("elasticity %.5f -> %.5f (move %+.5f); J %.8f -> %.8f\n", sum(ea), sum(eb), sum(eb) - sum(ea),
            a$stand$J, b$stand$J))
k <- 1:6
print(data.frame(birth = round(sa$birth[k], 4), offspring_rel_change = signif(sb$offspring[k] / sa$offspring[k] - 1, 3),
                 el_node_base = round(ea[k], 4), el_node_probe = round(eb[k], 4), el_move = round(eb[k] - ea[k], 5)))
top <- sa$birth < 0.5
cat(sprintf("elasticity move born before 0.5: %+.5f, after: %+.5f\n", sum((eb - ea)[top]), sum((eb - ea)[!top])))
