# The stand's reverse-mode gradient on the SCM at the driver's setting (tied
# tolerance, knots as step targets, uniform 108, long drought seed 31), on the
# build given (the probe builds cannot sweep: tf24_probe.patch adds an active
# member no walk releases): the grid the driver's adaptive run takes, so its elasticities are
# the exact frozen-grid derivatives the driver's central differences estimate.
#   PLANT_LIB=... TOL=1e-4 OUT=ad.rds Rscript ad_check.R
local({
  source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events/harness/long_drought.R")
})
tol <- as.numeric(Sys.getenv("TOL", "1e-4"))
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(uniform_times(108))
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- 1e-4 * tol
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(SCEN)))))
t0 <- proc.time()[["elapsed"]]
scm <- run_scm(p, mkenv(SCEN), ct, events = ev, record_trajectory = TRUE)
t1 <- proc.time()[["elapsed"]]
g <- stand_gradient(scm, metrics = "offspring_production")
t2 <- proc.time()[["elapsed"]]
pars <- p$strategies[[1]]$pars
grad <- g$gradient["offspring_production", ]
theta <- vapply(names(grad), function(n) pars[[sub("^1\\.", "", n)]], 0)
J <- sum(scm$offspring_production)
el <- ifelse(theta == 0, 1, theta) * grad / J
saveRDS(list(J = J, steps = length(scm$ode_times), elasticity = el, gradient = grad, theta = theta,
             secs_run = t1 - t0, secs_sweep = t2 - t1), Sys.getenv("OUT"))
cat(sprintf("tol %g: J %.17g, %d steps; run %.0f s, sweep %.0f s\n", tol, J, length(scm$ode_times), t1 - t0, t2 - t1))
for (k in c("lma", "a_dG2", "a_dG1", "d_I", "storage_relaxation_offset", "TF24_cost_scale")) {
  cat(sprintf("  elasticity %s %.10g\n", k, el[[paste0("1.", k)]]))
}
