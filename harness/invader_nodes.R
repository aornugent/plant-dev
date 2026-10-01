# The invader's establishment weight and net reproduction ratio at each node, at
# lma' = lma e^{-U} and lma e^{+U} on the stand's recorded field, beside the
# stand's own. Over nested schedules, node_parts.R places the move in the
# invader's lma elasticity in birth date, by central difference of each part.
#
#   PLANT_LIB=... TIMES=t.rds [U=1e-6] [REGIME=long-drought] [TOL=3e-5] OUT=x.rds \
#     Rscript harness/invader_nodes.R
#
# The invader replays the stand's steps, so at a small U the difference is the
# local slope the sweep returns unless a crossing slides past a stage within U.
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
regime <- Sys.getenv("REGIME", SCEN)
u <- as.numeric(Sys.getenv("U", "1e-6"))
tol <- as.numeric(Sys.getenv("TOL", "3e-5"))
times <- readRDS(Sys.getenv("TIMES"))
scen <- sprintf("%s, seed %d", regime, RAIN_SPECS[[regime]]$seed)
RAIN_SPECS[[scen]] <- RAIN_SPECS[[regime]]

p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
with_lma <- function(v) {
  q <- p
  q$strategies[[1]]$pars$lma <- q$strategies[[1]]$pars$lma * exp(v)
  q
}
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- 1e-4 * tol
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))

nodes <- function(scm) {
  sp <- scm$patch$species[[1]]
  list(birth = sp$node_times, establishment = sp$establishment_weights,
       nrr = sp$net_reproduction_ratio_by_node, J = sum(scm$offspring_production))
}
scm <- run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE)
out <- list(u = u, setting = list(regime = regime, tol = tol, lifetime = LIFETIME),
            node_times = times, stand = nodes(scm))
out$invader <- lapply(c(minus = -u, plus = u), function(v) {
  scm$run_mutant(with_lma(v))
  nodes(scm)
})
saveRDS(out, Sys.getenv("OUT"))
J <- vapply(out$invader, `[[`, 0, "J")
cat(sprintf("%s, %d nodes: J %.10g; invader lma elasticity %.6g by central difference over %g\n",
            scen, length(times), out$stand$J, (J[["plus"]] - J[["minus"]]) / (2 * u * out$stand$J), u))
