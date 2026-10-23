# The cut's g against finite differences of invader ln R' at a saved step of a
# one-shot run, one trait per process.
#   RUN=closed STEP=6 TRAIT=rho EARLY=8 Rscript probe_fd2.R
Sys.setenv(EVOLVE = Sys.getenv("EVOLVE", "lma,rho,hmat,vcmax_25"))
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a99c78a1743350c42/spikes/reference-community/common.R")
RUN <- Sys.getenv("RUN", "closed")
STEP <- as.integer(Sys.getenv("STEP"))
TRAIT <- Sys.getenv("TRAIT", "rho")
s <- readRDS(file.path(TMP, "runs", RUN, sprintf("step_%03d.rds", STEP)))
j <- match(TRAIT, EVOLVE)
r <- record(s$lnb, s$x, scm_out = TRUE)
hs <- c(1e-3, 1e-2, 3e-2)
xi <- rbind(s$x, do.call(rbind, lapply(hs, function(h)
  rbind(s$x + replace(numeric(length(EVOLVE)), j, h),
        s$x - replace(numeric(length(EVOLVE)), j, h)))))
inv <- invade(r$scm, xi, grad = FALSE)
out <- list(run = RUN, step = STEP, trait = TRAIT, early = EARLY, g = r$g,
            F = r$F, inv = inv, hs = hs)
saveRDS(out, file.path(TMP, sprintf("probe_fd2_%s_%d_%s_e%d.rds", RUN, STEP, TRAIT, EARLY)))
l0 <- inv$lnR[1]
cat(sprintf("%s step %d %s early %d: F %.5f (saved %.5f) cut g %.4f\n", RUN, STEP,
            TRAIT, EARLY, r$F, s$F, r$g[1, j]))
for (i in seq_along(hs)) {
  up <- inv$lnR[2 * i]; dn <- inv$lnR[2 * i + 1]; h <- hs[i]
  cat(sprintf("  h %.0e  up %+.5f  down %+.5f  central %.3f  curv %.1f\n",
              h, up - l0, dn - l0, (up - dn) / (2 * h), (up + dn - 2 * l0) / h^2))
}
