# Forward run on dry with the JT settings; reports clamp tallies and arm counts.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
DEV <- dirname(S)
Sys.setenv(PLANT_LIB = Sys.getenv("LIB", file.path(S, "libD")))
source("/home/user/plant-dev/harness/long_drought.R")
regime <- "dry"; seed <- RAIN_SPECS[[regime]]$seed
tol <- 3e-4; atol <- 1e-4
scen <- sprintf("%s, seed %d", regime, seed)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = seed))
knots <- active_knots(scen)
times <- readRDS(file.path(S, "P_out/sched/ins3c_dry.rds"))
p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma")); p$node_schedule_times <- list(times)
ct <- control(); ct$ode_tol_rel <- tol; ct$ode_tol_abs <- atol * tol
ct$node_density_in_birth_date <- TRUE; ct$ode_tol_factor_soil <- 10
w <- readRDS(file.path(DEV, "window/rule_A/weight_dry.rds"))
ct$ode_tol_factor_times <- w$t; ct$ode_tol_factor_values <- w$weight; ct$ode_tol_factor_max <- 100
ct$ode_step_size_max <- 15 / 365; ct$ode_split_sign_changes <- TRUE; ct$ode_soil_substep_max_uptake <- 0.1
ev <- events(events_default(p), pulse_rows(sort(unique(knots))))
types <- plant:::extract_RcppR6_template_types(p, "Parameters")
scm <- do.call(plant:::SCM, types)(p, mkenv(scen), ev, ct)
c0 <- proc.time()[["user.self"]]; scm$record_trajectory <- TRUE; scm$run()
cat(sprintf("J %.13g, %d steps, %d nodes, %d knots, %.0f s\n", sum(scm$offspring_production),
            length(scm$ode_times), length(times), length(unique(knots)), proc.time()[["user.self"]] - c0))
st <- p$strategies[[1]]; saveRDS(list(rows = scm$store_trajectory(), times = times, st = st), "traj.rds")
cl <- plant:::census_clamp_counts_tf24(scm); nm <- plant:::census_clamp_names_tf24()
print(cl); print(nm)
print(setNames(plant:::census_operating_point_counts_tf24(scm)[[1]], plant:::census_operating_point_names_tf24()))
print(scm$ode_step_attempts)
