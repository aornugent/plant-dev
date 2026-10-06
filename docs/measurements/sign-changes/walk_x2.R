# The invader at lma x 2 walked on a long-wet stand, with splits or without, to
# tell the split's carried correction from the walk itself when the walk fails.
#   PLANT_LIB=... SPLIT=0|1 [REGIME=long-wet] [HMAX=15] [FACTOR=2] OUT=x.rds \
#     Rscript walk_x2.R   (from the plant-dev root)
source("harness/long_drought.R")
regime <- Sys.getenv("REGIME", "long-wet")
scen <- sprintf("%s, seed %d", regime, 31L)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = 31L))
times <- uniform_times(108)
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
ct <- control()
ct$ode_tol_rel <- 1e-4
ct$ode_tol_abs <- 1e-8
ct$node_density_in_birth_date <- TRUE
if (Sys.getenv("SPLIT") == "1") ct$ode_split_sign_changes <- TRUE
if (nzchar(Sys.getenv("HMAX"))) ct$ode_step_size_max <- as.numeric(Sys.getenv("HMAX")) / 365
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))
scm <- run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE)
out <- list(split = Sys.getenv("SPLIT") == "1", J = sum(scm$offspring_production),
            steps = length(scm$ode_times), splits = sum(scm$ode_splits))
q <- stand_at(times, "lma", as.numeric(Sys.getenv("FACTOR", "2")))
out$walk <- tryCatch({
  scm$run_mutant(q)
  sum(scm$offspring_production)
}, error = function(e) conditionMessage(e))
saveRDS(out, Sys.getenv("OUT"))
cat(sprintf("split %s: J %.10g over %d steps, %d node steps split; walk: %s\n",
            out$split, out$J, out$steps, out$splits, format(out$walk)))
