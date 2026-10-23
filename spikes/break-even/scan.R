# ln R'(eps) for one pool invader, its solved P scaled by 1 + eps, over a log
# ladder and a fine linear scan, all against one resident in one process.
#
#   CASE=closed ROW=1 TAG=closed_r1 Rscript scan.R
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a3c3295eb8ad97b06/spikes/break-even/stand.R")
# ROWS (comma list) runs every row at every eps; ROW is the one-row form.
ROWS <- as.integer(strsplit(Sys.getenv("ROWS", Sys.getenv("ROW", "1")), ",")[[1]])
TAG <- Sys.getenv("TAG", paste0(CASE, "_r", ROWS[1]))
EPS <- if (nzchar(Sys.getenv("EPS"))) as.numeric(strsplit(Sys.getenv("EPS"), ",")[[1]]) else {
  ladder <- 10^(-7:-3)
  fine <- c(1:4, 6, 8) * 1e-6
  c(0, 0, ladder, -ladder, fine, -fine)
}
grid <- expand.grid(eps = EPS, row = ROWS)
m <- variant_traits(grid$row)
set_scales(m, 1 + grid$eps)
t0 <- proc.time()[["elapsed"]]
scm <- run_resident()
F <- log(scm$net_reproduction_ratios)
t1 <- proc.time()[["elapsed"]]
inv <- invade(scm, m)
t2 <- proc.time()[["elapsed"]]
res <- list(case = CASE, row = grid$row, eps = grid$eps, lnR = inv$lnR, F = F,
            cohorts = inv$cohorts, steps = length(scm$ode_times),
            tol = TOL, every = EVERY, gate = Sys.getenv("PLANT_GATE_WIDTH"),
            storage_eps = Sys.getenv("PLANT_STORAGE_EPS"),
            secs = c(resident = t1 - t0, invade = t2 - t1))
saveRDS(res, file.path(OUTDIR, paste0("scan_", TAG, ".rds")))
print(data.frame(row = grid$row, eps = grid$eps, lnR = inv$lnR), digits = 10)
cat("F", F, "steps", res$steps, "secs", res$secs, "\n")
