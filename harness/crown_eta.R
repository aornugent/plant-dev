# Long drought forward on a schedule with TF24's crown shape eta set, saving J and
# each node's birth, establishment weight and net reproduction ratio, for
# node_parts.R between nested schedules.
#
#   PLANT_LIB=... TIMES=t.rds ETA=6 OUT=x.rds Rscript harness/crown_eta.R
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
times <- readRDS(Sys.getenv("TIMES"))
scen <- sprintf("%s, seed %d", SCEN, RAIN_SPECS[[SCEN]]$seed)
RAIN_SPECS[[scen]] <- RAIN_SPECS[[SCEN]]
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
p$strategies[[1]]$pars$eta <- as.numeric(Sys.getenv("ETA"))
ct <- control()
ct$ode_tol_rel <- 3e-5
ct$ode_tol_abs <- 3e-9
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))
scm <- run_scm(p, mkenv(scen), ct, events = ev)
sp <- scm$patch$species[[1]]
out <- list(setting = list(regime = SCEN, eta = p$strategies[[1]]$pars$eta, lifetime = LIFETIME),
            node_times = times,
            stand = list(J = sum(scm$offspring_production),
                         nodes = list(birth = sp$node_times, establishment = sp$establishment_weights,
                                      nrr = sp$net_reproduction_ratio_by_node)))
saveRDS(out, Sys.getenv("OUT"))
cat(sprintf("eta %g, %d nodes: J %.8g\n", out$setting$eta, length(times), out$stand$J))
