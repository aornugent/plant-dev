# probe.R: a pinned replay of a saved dry run (PIN), then in the window WIN the state at
# every recorded step: soil by layer, each node's net production, collar and
# transpiration, the seedling's net production and establishment probability, and the
# TF24_cost_scale column of the rates' trait Jacobian. SWEEP=1 then runs the gradient
# (on libD, with ODELIA_ADJOINT_TRACE=params and ODELIA_TRACE_T0/T1 set by the caller).
# Env: PIN TOL LIB OUT WIN (t0,t1) SWEEP FINE (step of an extra Hermite-interpolated grid, yr)
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
DEV <- dirname(S)
Sys.setenv(PLANT_LIB = Sys.getenv("LIB", file.path(S, "libD")))
source("/home/user/plant-dev/harness/long_drought.R")
regime <- "dry"
seed <- RAIN_SPECS[[regime]]$seed
tol <- as.numeric(Sys.getenv("TOL", "3e-4")); atol <- 1e-4
scen <- sprintf("%s, seed %d", regime, seed)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = seed))
knots <- active_knots(scen)
times <- readRDS(Sys.getenv("TIMES", file.path(S, "P_out/sched/ins3c_dry.rds")))
out_file <- Sys.getenv("OUT")
win <- as.numeric(strsplit(Sys.getenv("WIN", "9.60,9.80"), ",")[[1]])

p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
if (nzchar(Sys.getenv("TRAIT_REL"))) {
  st_ <- p$strategies[[1]]
  for (kv in strsplit(strsplit(Sys.getenv("TRAIT_REL"), ",")[[1]], "=")) st_$pars[[kv[1]]] <- st_$pars[[kv[1]]] * (1 + as.numeric(kv[2]))
  p$strategies[[1]] <- st_
}
p$node_schedule_times <- list(times)
base <- list(J = NA)
if (nzchar(Sys.getenv("PIN"))) {
  pinned <- readRDS(Sys.getenv("PIN"))
  base <- pinned$stand
  p$ode_times <- base$times; p$ode_step_sizes <- base$sizes
  p$ode_soil_input_slopes <- base$input_slopes; p$ode_soil_substep_ends <- base$substep_ends
}
ct <- control()
ct$ode_tol_rel <- tol; ct$ode_tol_abs <- atol * tol
ct$node_density_in_birth_date <- TRUE
ct$ode_tol_factor_soil <- 10
w <- readRDS(file.path(DEV, "window/rule_A/weight_dry.rds"))
ct$ode_tol_factor_times <- w$t; ct$ode_tol_factor_values <- w$weight
ct$ode_tol_factor_max <- 100
ct$ode_step_size_max <- 15 / 365
ct$ode_split_sign_changes <- TRUE
ct$ode_soil_substep_max_uptake <- 0.1
ev <- events(events_default(p), pulse_rows(sort(unique(knots))))
types <- plant:::extract_RcppR6_template_types(p, "Parameters")
env0 <- mkenv(scen)
scm <- do.call(plant:::SCM, types)(p, env0, ev, ct)
scm$record_trajectory <- TRUE
cpu <- function() sum(proc.time()[c("user.self", "sys.self")])
c0 <- cpu(); scm$run()
out <- list(J = sum(scm$offspring_production), J_saved = base$J,
            same_times = isTRUE(all.equal(scm$ode_times, base$times, tolerance = 0)), fwd_cpu = cpu() - c0,
            times = scm$ode_times, attempts = scm$ode_step_attempts,
            op_counts = tryCatch(setNames(plant:::census_operating_point_counts_tf24(scm)[[1]],
                                          plant:::census_operating_point_names_tf24()), error = function(e) conditionMessage(e)))
if (Sys.getenv("SAVETRAJ") == "1") {
  rows <- scm$store_trajectory()
  out$traj <- list(t = vapply(rows, `[[`, 0, "time"), state = lapply(rows, `[[`, "state"))
}
if (Sys.getenv("STOPONLY") == "1") { if (nzchar(out_file)) saveRDS(out, out_file); print(out$op_counts); print(out$attempts); cat(sprintf("J %.15g, %d steps\n", out$J, length(out$times))); quit(save = "no") }
sv <- function() if (nzchar(out_file)) saveRDS(out, out_file)
cat(sprintf("J %.15g saved %.15g; same times %s; %.0f s\n", out$J, base$J, out$same_times, out$fwd_cpu))
sv()

nm <- plant:::census_trait_names_tf24(scm)
ic <- which(nm == "1.TF24_cost_scale")
rows <- scm$store_trajectory()
tt <- vapply(rows, `[[`, 0, "time")
# A patch carrying the window's nodes: those born before the window's end, introduced
# at their birth dates into a fresh patch, whose state is then loaded row by row.
hp <- do.call(plant:::Patch, types)(p, mkenv(scen), ct)
born <- times[times <= as.numeric(Sys.getenv("BORN", "9.70"))]
for (b in born) hp$introduce_new_node(1, b)
width <- hp$ode_size
nn <- hp$species[[1]]$size
onames <- hp$species[[1]]$new_node$ode_names
out$node_times <- hp$species[[1]]$node_times
out$ode_names <- onames
nsoil <- env0$get_soil_number_of_depths()
cat(sprintf("patch: %d nodes, width %d; ode names %s\n", nn, width,
            paste(onames, collapse = " ")))

read_state <- function(state, time, jac = TRUE) {
  hp$set_ode_state(state, time)
  r <- hp$ode_rates
  sp <- hp$species[[1]]
  nodes <- sp$nodes
  aux <- function(a) vapply(nodes, function(n) n$individual$aux(a), 0)
  en <- hp$environment
  th <- en$get_soil_water_state()
  nb <- sp$new_node$individual
  res <- list(time = time, state = state, rates = r,
              theta = th, psi = vapply(th[seq_len(nsoil)], en$psi_from_soil_moist, 0),
              P = aux("net_mass_production_dt"), collar = aux("opt_root_psi"),
              psi_stem = aux("opt_psi_stem"), E = aux("transpiration"), Eup = aux("E_up_"),
              seed_P = nb$aux("net_mass_production_dt"), seed_collar = nb$aux("opt_root_psi"),
              seed_E = nb$aux("transpiration"),
              seed_pe = nb$establishment_probability(en),
              arm_dry = if ("arm_margin_dry" %in% nodes[[1]]$individual$aux_names) aux("arm_margin_dry"),
              arm_wet = if ("arm_margin_dry" %in% nodes[[1]]$individual$aux_names) aux("arm_margin_wet"),
              arm_kind = if ("arm_margin_dry" %in% nodes[[1]]$individual$aux_names) aux("arm_kind"),
              est_w = sp$establishment_weights)
  if (jac) {
    J <- plant:::ladder_rhs_trait_jacobian_forward_tf24(hp)
    res$dfdth <- J[, ic]
  }
  res
}
k <- which(tt >= win[1] & tt <= win[2] & vapply(rows, function(r) length(r$state), 0) == width)
out$steps <- lapply(k, function(i) read_state(rows[[i]]$state, tt[i]))
out$steps_k <- k
cat(sprintf("probed %d recorded states in [%g, %g]\n", length(k), win[1], win[2]))
sv()
for (s in out$steps) cat(sprintf("t %.5f psi %s | seedP %.4g pe %.4g | P<0 %d/%d | collar max %.4f | min P %.3g\n",
  s$time, paste(sprintf("%.3f", s$psi), collapse = " "), s$seed_P, s$seed_pe, sum(s$P < 0), length(s$P),
  max(s$collar), min(abs(s$P))))

# A finer grid by cubic Hermite interpolation between recorded states (rates at both ends).
fine <- as.numeric(Sys.getenv("FINE", "0"))
if (fine > 0) {
  st <- out$steps
  g <- NULL
  for (j in seq_len(length(st) - 1)) {
    a <- st[[j]]; b <- st[[j + 1]]; h <- b$time - a$time
    if (h <= 0) next
    for (u in seq(0, 1, by = min(1, fine / h))[-1]) {
      if (u >= 1) next
      h00 <- 2 * u^3 - 3 * u^2 + 1; h10 <- u^3 - 2 * u^2 + u; h01 <- -2 * u^3 + 3 * u^2; h11 <- u^3 - u^2
      y <- h00 * a$state + h10 * h * a$rates + h01 * b$state + h11 * h * b$rates
      x <- read_state(y, a$time + u * h, jac = Sys.getenv("FINEJAC") == "1")
      x$state <- NULL; x$rates <- NULL
      g[[length(g) + 1]] <- x
    }
  }
  out$fine <- g
  sv()
}

if (Sys.getenv("SWEEP") == "1") {
  c0 <- cpu()
  gr <- plant:::census_trait_gradient_tf24(scm, "offspring_production")
  out$sweep_cpu <- cpu() - c0
  out$gradient <- setNames(gr$gradient[[1]], nm)
  pars <- p$strategies[[1]]$pars
  theta <- vapply(nm, function(n) pars[[sub("^1\\.", "", n)]], 0)
  out$theta <- theta
  out$elasticity <- ifelse(theta == 0, 1, theta) * out$gradient / out$J
  if (!is.null(base$elasticity)) cat(sprintf("max |elasticity - saved| %.3g\n", max(abs(out$elasticity - base$elasticity))))
  sv()
}
out$finished <- TRUE; sv()
