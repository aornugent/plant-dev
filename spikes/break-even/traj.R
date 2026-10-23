# Cohort trajectories inside run_mutant: for each invader variant, every
# cohort's states and net production at each introduction (scm$history keeps
# one patch per leg), with the relative reserves
# r = S / S_max, the reserve-driven hazard and the share of gross carbon gain
# in net production (d ln net / d ln P).
#
#   CASE=closed ROWS=1,1,1,2 SCALES=1,1.0001,0.9999,1 TAG=closed Rscript traj.R
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a3c3295eb8ad97b06/spikes/break-even/stand.R")
ROWS <- as.integer(strsplit(Sys.getenv("ROWS", "1,1,1,2"), ",")[[1]])
SCALES <- as.numeric(strsplit(Sys.getenv("SCALES", "1,1.0001,0.9999,1"), ",")[[1]])
TAG <- Sys.getenv("TAG", CASE)
m <- variant_traits(ROWS)
set_scales(m, SCALES)
scm <- run_resident()
q <- add_mutant(scm$parameters, m, birth_rate = rep(1, nrow(m)))
for (i in seq_len(nrow(m))) q$strategies[[i]]$collect_all_auxiliary <- TRUE
q$node_schedule_times <- rep(list(TIMES_INV), nrow(m))
scm$collect <- TRUE
scm$run_mutant(q)
lnR <- log(scm$net_reproduction_ratios)
pars <- lapply(q$strategies, function(s) s$pars)
rows <- list()
for (h in scm$history) {
  tm <- h$time
  for (i in seq_along(h$species)) {
    sp <- h$species[[i]]
    nd <- sp$nodes
    if (!length(nd)) next
    pp <- pars[[i]]
    bt <- sp$node_times
    for (k in seq_along(nd)) {
      ind <- nd[[k]]$individual
      x <- ind$ode_state
      ht <- x[1]
      al <- (ht / pp$a_l1)^(1 / pp$a_l2)
      sapw <- ind$aux("area_sapwood")
      eta_c <- 1 - 2 / (1 + pp$eta) + 1 / (1 + 2 * pp$eta)
      smax <- pp$a_st1 * sapw * ht * eta_c * pp$rho
      gross <- pp$a_bio * pp$a_y * (ind$aux("profit") + ind$aux("shadow_cost")) *
        al * 60 * 60 * 12 * 365 / 1e6
      rows[[length(rows) + 1]] <- c(
        variant = i, time = tm, cohort = k, birth = bt[k], height = ht,
        H = x[2], fecundity = x[3], storage = x[6], smax = smax,
        net = ind$aux("net_mass_production_dt"), gross = gross)
    }
  }
}
d <- as.data.frame(do.call(rbind, rows))
saveRDS(d, file.path(OUTDIR, paste0("traj_", TAG, "_raw.rds")))
d$r <- d$storage / d$smax
d$mu <- vapply(d$variant, function(i) pars[[i]]$d_I, 0) +
  vapply(d$variant, function(i) pars[[i]]$a_dG1, 0) *
  exp(-vapply(d$variant, function(i) pars[[i]]$a_dG2, 0) * d$r)
saveRDS(list(rows = ROWS, scales = SCALES, lnR = lnR, traj = d,
             pars = pars[[1]][c("a_st1", "a_st2", "a_dG1", "a_dG2", "d_I")]),
        file.path(OUTDIR, paste0("traj_", TAG, ".rds")))
print(lnR)
