# Invaders at small ln-trait moves from the closed resident, in its recorded
# field: finite differences of ln R' against the swept g.
Sys.setenv(EVOLVE = "lma,rho,hmat,vcmax_25")
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a99c78a1743350c42/spikes/reference-community/common.R")
lnb <- 3.595
r <- record(lnb, rep(0, length(EVOLVE)), scm_out = TRUE)
hs <- c(1e-3, 1e-2, 5e-2)
xi <- do.call(rbind, lapply(seq_along(EVOLVE), function(j)
  do.call(rbind, lapply(hs, function(h)
    rbind(replace(numeric(4), j, h), replace(numeric(4), j, -h))))))
inv <- invade(r$scm, rbind(0, xi), grad = FALSE)
saveRDS(inv, file.path(TMP, "probe_fd.rds"))
l0 <- inv$lnR[1]; lr <- inv$lnR[-1]
k <- 0
for (j in seq_along(EVOLVE)) for (h in hs) {
  up <- lr[k + 1]; dn <- lr[k + 2]; k <- k + 2
  cat(sprintf("%-9s h %.0e  central %.4f  fwd %.4f  bwd %.4f  curv %.2f\n",
              EVOLVE[j], h, (up - dn) / (2 * h), (up - l0) / h, (l0 - dn) / h,
              (up - 2 * l0 + dn) / h^2))
}
cat("secs", inv$secs_run, "\n")
