# The AD derivative of ln R' in the direction that scales P. Scaling the solved
# P by 1 + eps moves net production by a_bio a_y A eps; the same move is a_y
# scaled by 1 + eps and every respiration rate by 1 / (1 + eps), since
#   net = a_bio a_y (A - (r_l m_l + r_b m_b + r_s m_s + r_r m_r)) - turnover.
# So d ln R'/d ln P = e(a_y) - e(r_l) - e(r_b) - e(r_s) - e(r_r), each an
# elasticity from stand_gradient with hyperpar = NULL (partials).
#
#   CASE=closed ROWS=1,2 TAG=closed Rscript ad.R
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a3c3295eb8ad97b06/spikes/break-even/stand.R")
ROWS <- as.integer(strsplit(Sys.getenv("ROWS", "1,2"), ",")[[1]])
TAG <- Sys.getenv("TAG", CASE)
PARS <- c("a_y", "r_l", "r_b", "r_s", "r_r", "vcmax_25")
m <- variant_traits(ROWS)
scm <- run_resident()
inv <- invade(scm, m, keep_states = TRUE)
metrics <- paste0(seq_along(ROWS), ".net_reproduction_ratio")
traits <- as.vector(outer(seq_along(ROWS), PARS, paste, sep = "."))
t0 <- proc.time()[["elapsed"]]
g <- stand_gradient(scm, metrics = metrics, traits = traits, hyperpar = NULL)
secs <- proc.time()[["elapsed"]] - t0
saveRDS(list(g = g, lnR = inv$lnR, secs = secs), file.path(OUTDIR, paste0("ad_", TAG, "_raw.rds")))
el <- t(vapply(seq_along(ROWS), function(i) {
  s <- scm$parameters$strategies[[i]]$pars
  th <- vapply(PARS, function(n) s[[n]], 0)
  g$gradient[metrics[i], paste(i, PARS, sep = ".")] * th / g$value[[metrics[i]]]
}, numeric(length(PARS))))
dimnames(el) <- list(ROWS, PARS)
P_dir <- el[, "a_y"] - rowSums(el[, c("r_l", "r_b", "r_s", "r_r"), drop = FALSE])
print(el)
print(data.frame(row = ROWS, lnR = inv$lnR, dlnR_dlnP_AD = P_dir))
print(g$refusal)
saveRDS(list(case = CASE, rows = ROWS, lnR = inv$lnR, elasticity = el,
             P_dir = P_dir, gradient = g, secs = secs, cohorts = inv$cohorts),
        file.path(OUTDIR, paste0("ad_", TAG, ".rds")))
