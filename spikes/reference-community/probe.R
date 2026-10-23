# One recording of the closed resident at the field-dimension ln b*, with the
# invader at its own traits: timing, and the cut against the invader gradient.
Sys.setenv(EVOLVE = "lma,rho,hmat,vcmax_25")
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a99c78a1743350c42/spikes/reference-community/common.R")
lnb <- 3.595
r <- record(lnb, rep(0, length(EVOLVE)), scm_out = TRUE)
scm <- r$scm; r$scm <- NULL
print(r[c("F", "F_lnb", "g", "steps", "secs_run", "secs_sweep")])
print(matrix(r$F_theta, 1, dimnames = list(NULL, EVOLVE)))
inv <- invade(scm, rbind(rep(0, length(EVOLVE))))
print(inv)
saveRDS(list(rec = r, inv = inv), file.path(TMP, "probe.rds"))
