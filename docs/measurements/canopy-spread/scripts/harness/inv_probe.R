# harness/invader_nodes.R with two additions for the comb probes: RULE sets
# Control's function_integration_rule (the crown's Gauss-Kronrod rule, 21 by
# default), and the PLANT_PROBE_* variables the probe build reads are recorded
# in out$setting. Everything else is invader_nodes.R as committed at d553254.
#
#   PLANT_LIB=... TIMES=t.rds [U=1e-6] [TOL=3e-5] [RULE=21] OUT=x.rds Rscript inv_probe.R
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
regime <- Sys.getenv("REGIME", SCEN)
u <- as.numeric(Sys.getenv("U", "1e-6"))
tol <- as.numeric(Sys.getenv("TOL", "3e-5"))
rule <- as.integer(Sys.getenv("RULE", "21"))
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
ct$function_integration_rule <- rule
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))

nodes <- function(scm) {
  sp <- scm$patch$species[[1]]
  list(birth = sp$node_times, establishment = sp$establishment_weights,
       nrr = sp$net_reproduction_ratio_by_node, J = sum(scm$offspring_production))
}
t0 <- proc.time()[["elapsed"]]
scm <- run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE)
probe <- Sys.getenv(c("PLANT_PROBE_KNOTS", "PLANT_PROBE_SPREAD", "PLANT_PROBE_SELF"))
out <- list(u = u, setting = list(regime = regime, tol = tol, lifetime = LIFETIME, rule = rule,
                                  probe = probe, lib = Sys.getenv("PLANT_LIB")),
            node_times = times, stand = nodes(scm), steps = length(scm$ode_times))
out$invader <- lapply(c(minus = -u, plus = u), function(v) {
  scm$run_mutant(with_lma(v))
  nodes(scm)
})
out$secs <- proc.time()[["elapsed"]] - t0
saveRDS(out, Sys.getenv("OUT"))
J <- vapply(out$invader, `[[`, 0, "J")
cat(sprintf("%s, %d nodes, rule %d, probe [%s]: J %.10g; invader lma elasticity %.6g by central difference over %g; %d steps; %.0f s\n",
            scen, length(times), rule, paste(names(probe), probe, sep = "=", collapse = " "),
            out$stand$J, (J[["plus"]] - J[["minus"]]) / (2 * u * out$stand$J), u, out$steps, out$secs))
