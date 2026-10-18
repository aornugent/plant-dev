# twin.R: one forward run (adj_run_nk.R's setting, no gradient) on TIMES with TRAIT_REL, that
# keeps per node: fate, establishment weight, splits, and from its recorded mortality the
# peak drydown hazard (increment rate less d_I), its time, and r_min = -ln(h/a_dG1)/a_dG2.
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap"
Sys.setenv(PLANT_LIB = Sys.getenv("LIB", file.path(A, "libS")))
source("/home/user/plant-dev/harness/long_drought.R")
regime <- Sys.getenv("REGIME"); seed <- as.integer(Sys.getenv("SEED", RAIN_SPECS[[regime]]$seed))
scen <- sprintf("%s, seed %d", regime, seed); RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = seed))
times <- readRDS(Sys.getenv("TIMES"))
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
scm <- do.call(plant:::SCM, types)(p, mkenv(scen), ev, ct); scm$record_trajectory <- TRUE
t0 <- proc.time()[["elapsed"]]; scm$run(); cpu <- proc.time()[["elapsed"]] - t0
sp <- scm$patch$species[[1]]; per <- length(sp$ode_state) / sp$size; nm <- sp$new_node$ode_names; km <- which(nm == "mortality")
rows <- scm$store_trajectory(); tt <- vapply(rows, `[[`, 0, "time"); n <- length(times)
pars <- p$strategies[[1]]$pars; hmax <- rep(0, n); tmax <- rep(NA_real_, n); prev <- rep(NA_real_, n); tprev <- NA
for (i in seq_along(rows)) { s <- rows[[i]]$state; held <- min(n, floor((length(s) - 10) / per)); if (held < 1) { tprev <- tt[i]; next }
  m <- s[per * (seq_len(held) - 1) + km]
  if (!is.na(tprev) && tt[i] > tprev) { dt <- tt[i] - tprev; ok <- !is.na(prev[seq_len(held)]) & m < 700
    h <- (m - prev[seq_len(held)]) / dt - pars$d_I; up <- ok & h > hmax[seq_len(held)]
    hmax[seq_len(held)][up] <- h[up]; tmax[seq_len(held)][up] <- tt[i] }
  prev[seq_len(held)] <- m; tprev <- tt[i] }
rmin <- ifelse(hmax > pars$a_dG1 * exp(-pars$a_dG2), -log(pmin(hmax, pars$a_dG1) / pars$a_dG1) / pars$a_dG2, 1)
out <- list(J = sum(scm$offspring_production), birth = sp$node_times, nrr = sp$net_reproduction_ratio_by_node, w = sp$establishment_weights,
  splits = scm$ode_splits, hmax = hmax, tmax = tmax, rmin = rmin, steps = length(scm$ode_times), cpu = cpu, trait = Sys.getenv("TRAIT_REL"))
saveRDS(out, Sys.getenv("OUT")); cat(sprintf("J %.10g, %d steps, %.0f s\n", out$J, out$steps, cpu))
