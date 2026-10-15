# detect.R: a forward on dry with libJTstop in detection-only mode (JT_STOP=0), logging
# every f_hi root (JTROOT lines on stderr). Env: TOL, NODES ("inset" or a count of uniform
# nodes), WINDOW (1: the rule-A window factors; 0: none, as a pilot), TRAIT_REL (k=rel,...).
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
DEV <- dirname(S)
Sys.setenv(PLANT_LIB = file.path(S, "libJTstop"))
source("/home/user/plant-dev/harness/long_drought.R")
regime <- "dry"; seed <- RAIN_SPECS[[regime]]$seed
tol <- as.numeric(Sys.getenv("TOL", "3e-4")); atol <- 1e-4
scen <- sprintf("%s, seed %d", regime, seed)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = seed))
knots <- active_knots(scen)
nodes <- Sys.getenv("NODES", "inset")
times <- if (nodes == "inset") readRDS(file.path(S, "P_out/sched/ins3c_dry.rds")) else uniform_times(as.integer(nodes))
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
if (nzchar(Sys.getenv("TRAIT_REL"))) {
  st_ <- p$strategies[[1]]
  for (kv in strsplit(strsplit(Sys.getenv("TRAIT_REL"), ",")[[1]], "=")) st_$pars[[kv[1]]] <- st_$pars[[kv[1]]] * (1 + as.numeric(kv[2]))
  p$strategies[[1]] <- st_
}
p$node_schedule_times <- list(times)
ct <- control()
ct$ode_tol_rel <- tol; ct$ode_tol_abs <- atol * tol
ct$node_density_in_birth_date <- TRUE
ct$ode_tol_factor_soil <- 10
if (Sys.getenv("WINDOW", "1") == "1") {
  w <- readRDS(file.path(DEV, "window/rule_A/weight_dry.rds"))
  ct$ode_tol_factor_times <- w$t; ct$ode_tol_factor_values <- w$weight
}
ct$ode_tol_factor_max <- 100
ct$ode_step_size_max <- 15 / 365
ct$ode_split_sign_changes <- TRUE
ct$ode_soil_substep_max_uptake <- 0.1
ev <- events(events_default(p), pulse_rows(sort(unique(knots))))
types <- plant:::extract_RcppR6_template_types(p, "Parameters")
scm <- do.call(plant:::SCM, types)(p, mkenv(scen), ev, ct)
c0 <- proc.time()[["elapsed"]]; scm$run()
cat(sprintf("J %.12g, %d steps, %d nodes, %.0f s\n", sum(scm$offspring_production),
            length(scm$ode_times), length(times), proc.time()[["elapsed"]] - c0))
saveRDS(list(times = scm$ode_times), Sys.getenv("OUT"))
