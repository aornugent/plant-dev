# Does the step in invader ln R' at theta' = theta scale with node spacing?
# The closed resident at NODES introductions, invaders at small ln-lma moves.
#   NODES=216 Rscript probe_nodes.R
Sys.setenv(EVOLVE = "lma")
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a99c78a1743350c42/spikes/reference-community/common.R")
lnb <- 3.595
t0 <- proc.time()[[3]]
p <- stand(lnb, 0)
scm <- run_scm(p, mkenv(REGIME), ctrl(), run = FALSE)
scm$keep_states <- TRUE
scm$run()
F <- log(scm$net_reproduction_ratios)
secs_res <- proc.time()[[3]] - t0
hs <- c(1e-3, 1e-2, 5e-2)
xi <- cbind(c(0, rbind(hs, -hs)))
inv <- invade(scm, xi, grad = FALSE)
out <- list(nodes = NODES, F = F, steps = length(scm$ode_times), inv = inv,
            secs_res = secs_res)
saveRDS(out, file.path(TMP, sprintf("probe_nodes_%d_e%d.rds", NODES, EARLY)))
l0 <- inv$lnR[1]
cat(sprintf("nodes %d F %.5f steps %d resident %.0fs invaders %.0fs; lnR'(0) %.5f\n",
            NODES, F, out$steps, secs_res, inv$secs_run, l0))
for (i in seq_along(hs)) {
  up <- inv$lnR[2 * i]; dn <- inv$lnR[2 * i + 1]; h <- hs[i]
  cat(sprintf("  h %.0e  up %+.4f  down %+.4f  central %.3f  (up-down)/2 %.4f\n",
              h, up - l0, dn - l0, (up - dn) / (2 * h), (up - dn) / 2))
}
