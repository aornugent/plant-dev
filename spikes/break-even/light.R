# The light the leading cohort sees. From the resident's history: the heights
# and densities of its tallest cohorts at each introduction. From the
# invaders' history (identity invader at P x (1, 1 +- 1e-4)): the openness
# profile E(z) around cohort 1's height, its slope d ln E / d ln z there, and
# the ground light E(0).
#
#   CASE=closed TAG=closed Rscript light.R
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a3c3295eb8ad97b06/spikes/break-even/stand.R")
TAG <- Sys.getenv("TAG", CASE)
SCALES <- c(1, 1.0001, 0.9999)
m <- variant_traits(rep(1, 3))
set_scales(m, SCALES)
p <- resident_parameters()
scm <- run_scm(p, mkenv(REGIME), ctrl, run = FALSE)
scm$collect <- TRUE
scm$run()
res_top <- do.call(rbind, lapply(scm$history, function(h) {
  sp <- h$species[[1]]
  nd <- sp$nodes
  if (!length(nd)) return(NULL)
  ht <- vapply(nd, function(n) n$individual$ode_state[1], 0)
  ld <- vapply(nd, function(n) n$log_density, 0)
  k <- seq_len(min(6, length(nd)))
  data.frame(time = h$time, rank = k, height = ht[k], log_density = ld[k],
             birth = sp$node_times[k])
}))
n_res <- length(scm$history)
saveRDS(list(res_top = res_top), file.path(OUTDIR, paste0("light_", TAG, ".rds")))
q <- add_mutant(scm$parameters, m, birth_rate = rep(1, 3))
q$node_schedule_times <- rep(list(TIMES_INV), 3)
scm$run_mutant(q)
hist <- scm$history
hist <- hist[seq.int(n_res + 1, length.out = max(0, length(hist) - n_res))]
openness <- function(env, z) {
  tryCatch(env$get_environment_at_height(z), error = function(e) NA_real_)
}
DELTA <- c(-0.05, -0.02, -0.01, -0.005, -0.001, 0, 0.001, 0.005, 0.01, 0.02)
inv <- do.call(rbind, lapply(hist, function(h) {
  env <- h$environment
  hv <- vapply(1:3, function(i) {
    nd <- h$species[[i]]$nodes
    if (length(nd)) nd[[1]]$individual$ode_state[1] else NA_real_
  }, 0)
  if (is.na(hv[1])) return(NULL)
  E <- vapply(hv[1] * (1 + DELTA), function(z) openness(env, z), 0)
  data.frame(time = h$time, h1 = hv[1], h_plus = hv[2], h_minus = hv[3],
             E_ground = openness(env, 0), E_h = E[DELTA == 0],
             E_plus = openness(env, hv[2]), E_minus = openness(env, hv[3]),
             slope = (log(E[DELTA == 0.001]) - log(E[DELTA == -0.001])) / 0.002,
             t(setNames(E, paste0("E", DELTA))))
}))
saveRDS(list(res_top = res_top, inv = inv, lnR = log(scm$net_reproduction_ratios)),
        file.path(OUTDIR, paste0("light_", TAG, ".rds")))
print(inv[, 1:9], digits = 4)
