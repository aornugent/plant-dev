# traj.R: one forward run (adj_run_nk.R's setting, no gradient) that keeps the states of the
# cohorts born near chosen closing edges. For each node born within [c - 40 d, c + 12 d] of
# an edge c in EDGES (comma-separated birth dates, years), its height, mortality, storage
# and survival-weighted offspring at its age tau (0-60 d daily, then to 3 yr), and the five
# soil layers' water on the same calendar grid around each edge.
# Env as adj_run_nk.R (REGIME TOL ATOL TIMES WEIGHT_SOIL WEIGHT WEIGHT_MAX HMAX SHARE SPLIT
# TRAIT_REL OUT LIB), plus EDGES.
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap"
Sys.setenv(PLANT_LIB = Sys.getenv("LIB", file.path(A, "libS")))
source("/home/user/plant-dev/harness/long_drought.R")
regime <- Sys.getenv("REGIME"); seed <- as.integer(Sys.getenv("SEED", RAIN_SPECS[[regime]]$seed))
scen <- sprintf("%s, seed %d", regime, seed); RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = seed))
times <- readRDS(Sys.getenv("TIMES")); edges <- as.numeric(strsplit(Sys.getenv("EDGES"), ",")[[1]])
p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- LIFETIME; p <- add_strategies(p, trait_matrix(LMA0, "lma"))
if (nzchar(Sys.getenv("TRAIT_REL"))) for (kv in strsplit(strsplit(Sys.getenv("TRAIT_REL"), ",")[[1]], "=")) p$strategies[[1]]$pars[[kv[1]]] <- p$strategies[[1]]$pars[[kv[1]]] * (1 + as.numeric(kv[2]))
p$node_schedule_times <- list(times)
ct <- control(); tol <- as.numeric(Sys.getenv("TOL")); ct$ode_tol_rel <- tol; ct$ode_tol_abs <- as.numeric(Sys.getenv("ATOL")) * tol
ct$node_density_in_birth_date <- TRUE; ct$ode_tol_factor_soil <- as.numeric(Sys.getenv("WEIGHT_SOIL"))
w <- readRDS(Sys.getenv("WEIGHT")); ct$ode_tol_factor_times <- w$t; ct$ode_tol_factor_values <- w$weight
ct$ode_tol_factor_max <- as.numeric(Sys.getenv("WEIGHT_MAX")); ct$ode_step_size_max <- as.numeric(Sys.getenv("HMAX")) / 365
ct$ode_split_sign_changes <- Sys.getenv("SPLIT") == "1"; ct$ode_soil_substep_max_uptake <- as.numeric(Sys.getenv("SHARE"))
ev <- events(events_default(p))
types <- plant:::extract_RcppR6_template_types(p, "Parameters")
scm <- do.call(plant:::SCM, types)(p, mkenv(scen), ev, ct); scm$record_trajectory <- TRUE; scm$run()
sp <- scm$patch$species[[1]]; per <- length(sp$ode_state) / sp$size; nm <- sp$new_node$ode_names
rows <- scm$store_trajectory(); t <- vapply(rows, `[[`, 0, "time"); len <- lengths(lapply(rows, `[[`, "state"))
held <- (len - (tail(len, 1) - per * sp$size)) / per
tau <- c(seq(0, 60, by = 1), seq(65, 365, by = 5), seq(380, 1095, by = 15)) / 365
idx <- function(tt) vapply(tt, function(g) max(which(t <= g)), 0L)
out <- list(edges = edges, tau = tau, J = sum(scm$offspring_production), birth = sp$node_times, nrr = sp$net_reproduction_ratio_by_node,
  w = sp$establishment_weights, per_edge = list())
for (c0 in edges) { js <- which(times >= c0 - 40 / 365 & times <= c0 + 12 / 365)
  pick <- function(name) { k <- which(nm == name); sapply(js, function(j) { at <- idx(times[j] + tau); vapply(at, function(i) if (held[i] >= j) rows[[i]]$state[per * (j - 1) + k] else NA_real_, 0) }) }
  cal <- c0 + seq(-60, 120, by = 1) / 365; ai <- idx(cal)
  out$per_edge[[as.character(c0)]] <- list(j = js, birth = times[js], height = pick("height"), mortality = pick("mortality"), storage = pick("storage"),
    offspring = pick("offspring_produced_survival_weighted"), cal = cal, theta = t(vapply(ai, function(i) head(tail(rows[[i]]$state, 10), 5), numeric(5)))) }
saveRDS(out, Sys.getenv("OUT")); cat(sprintf("J %.10g; %d edges kept\n", out$J, length(edges)))
