# Where in birth date the step in invader ln R' at theta' = theta comes from:
# per-node net reproduction of invaders at ln lma 0 and +-H.
#   NODES=108 H=1e-3 Rscript probe_where.R
Sys.setenv(EVOLVE = "lma")
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a99c78a1743350c42/spikes/reference-community/common.R")
H <- as.numeric(Sys.getenv("H", "1e-3"))
p <- stand(3.595, 0)
scm <- run_scm(p, mkenv(REGIME), ctrl(), run = FALSE)
scm$keep_states <- TRUE
scm$run()
inv <- invade(scm, cbind(c(0, H, -H)), grad = FALSE)
by_node <- lapply(1:3, function(i) scm$patch$species[[i]]$net_reproduction_ratio_by_node)
nt <- scm$patch$species[[1]]$node_times
out <- list(nodes = NODES, h = H, lnR = inv$lnR, by_node = by_node, node_times = nt)
saveRDS(out, file.path(TMP, sprintf("probe_where_%d_%g.rds", NODES, H)))
n <- min(lengths(by_node))
d <- by_node[[2]][1:n] - by_node[[3]][1:n]
cat("lnR'", inv$lnR, "\n")
cat("total R up-down", sum(by_node[[2]]) - sum(by_node[[3]]), "\n")
o <- order(-abs(d))[1:15]
print(data.frame(node = o, t = nt[o], R0 = by_node[[1]][o], up = by_node[[2]][o],
                 down = by_node[[3]][o], diff = d[o]))
