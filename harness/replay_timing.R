# Times the stand's forward run and two identical invader replays after it, on
# uniform 108 at 3e-5 under the tied tolerance. The absolute tolerance is the
# literal 3e-9, one ulp from run_record.R's 1e-4 * 3e-5, so J differs from its
# run by 4.7e-7.
#   PLANT_LIB=... Rscript harness/replay_timing.R
source("harness/long_drought.R")
scen <- sprintf("%s, seed %d", SCEN, RAIN_SPECS[[SCEN]]$seed)
RAIN_SPECS[[scen]] <- RAIN_SPECS[[SCEN]]
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(uniform_times(108))
ct <- control()
ct$ode_tol_rel <- 3e-5
ct$ode_tol_abs <- 3e-9
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))
clock <- function() proc.time()[["elapsed"]]
t0 <- clock(); scm <- run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE); t1 <- clock()
J <- sum(scm$offspring_production)
scm$run_mutant(p); t2 <- clock(); J1 <- sum(scm$offspring_production)
scm$run_mutant(p); t3 <- clock(); J2 <- sum(scm$offspring_production)
cat(sprintf("forward %.1f s; first replay %.1f s; second replay %.1f s | J %.10g, replays %.10g %.10g\n",
            t1 - t0, t2 - t1, t3 - t2, J, J1, J2))
