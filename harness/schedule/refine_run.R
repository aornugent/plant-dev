# One TF24 stand run for refine_schedule, then its gradient unless FORWARD=1. PIN names an
# earlier run whose steps this one reuses; FIRST=1 also records the establishment rate and
# T(t), the share of J still to be produced. ATOL is relative to TOL.
Sys.setenv(PLANT_LIB = Sys.getenv("LIB"))
source("/home/user/plant-dev/harness/long_drought.R")
regime <- Sys.getenv("REGIME")
seed <- as.integer(Sys.getenv("SEED", RAIN_SPECS[[regime]]$seed))
tol <- as.numeric(Sys.getenv("TOL", "1e-4"))
scen <- sprintf("%s, seed %d", regime, seed)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = seed))
times <- readRDS(Sys.getenv("TIMES"))
out_file <- Sys.getenv("OUT")

p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
for (kv in strsplit(strsplit(Sys.getenv("TRAIT_REL"), ",")[[1]], "=")) {
  p$strategies[[1]]$pars[[kv[1]]] <- p$strategies[[1]]$pars[[kv[1]]] * (1 + as.numeric(kv[2]))
}
p$node_schedule_times <- list(times)
if (nzchar(Sys.getenv("PIN"))) {
  base <- readRDS(Sys.getenv("PIN"))$stand
  p$ode_times <- base$times
  p$ode_step_sizes <- base$sizes
  p$ode_soil_input_slopes <- base$input_slopes
  p$ode_soil_substep_ends <- base$substep_ends
}
env_num <- function(v) as.numeric(Sys.getenv(v))
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- env_num("ATOL") * tol
ct$node_density_in_birth_date <- TRUE
ct$ode_tol_factor_soil <- env_num("WEIGHT_SOIL")
w <- readRDS(Sys.getenv("WEIGHT"))
ct$ode_tol_factor_times <- w$t
ct$ode_tol_factor_values <- w$weight
ct$ode_tol_factor_max <- env_num("WEIGHT_MAX")
ct$ode_step_size_max <- env_num("HMAX") / 365
ct$ode_split_sign_changes <- Sys.getenv("SPLIT") == "1"
ct$ode_soil_substep_max_uptake <- env_num("SHARE")

cpu <- function() sum(proc.time()[c("user.self", "sys.self")])
out <- list(node_times = times, pars = p$strategies[[1]]$pars, started = format(Sys.time()))
write_out <- function() saveRDS(out, out_file)
types <- plant:::extract_RcppR6_template_types(p, "Parameters")
scm <- do.call(plant:::SCM, types)(p, mkenv(scen), events(events_default(p)), ct)
scm$record_trajectory <- TRUE
c0 <- cpu()
scm$run()
sp <- scm$patch$species[[1]]
t <- scm$ode_times
out$stand <- list(J = sum(scm$offspring_production), times = t, sizes = scm$ode_step_sizes,
                  input_slopes = scm$ode_soil_input_slopes, substep_ends = scm$ode_soil_substep_ends,
                  nodes = list(birth = sp$node_times, establishment = sp$establishment_weights,
                               nrr = sp$net_reproduction_ratio_by_node),
                  rows = sum(vapply(t[-length(t)], function(s) sum(times <= s) + 1, 0)),
                  cpu = cpu() - c0)
# The newest node's establishment integral is the only one still open, so its growth over
# a step is the establishment rate; the nodes' survival-weighted offspring so far give T(t).
if (Sys.getenv("FIRST") == "1") {
  rows <- scm$store_trajectory()
  per <- length(sp$ode_state) / sp$size
  names_ <- sp$new_node$ode_names
  at_e <- which(names_ == "interval_establishment")
  at_o <- which(names_ == "offspring_produced_survival_weighted")
  len <- lengths(lapply(rows, `[[`, "state"))
  held <- (len - (tail(len, 1) - per * sp$size)) / per
  tt <- vapply(rows, `[[`, 0, "time")
  E <- vapply(seq_along(rows), function(i)
    if (held[i] > 0) rows[[i]]$state[per * (held[i] - 1) + at_e] else NA_real_, 0)
  wt <- sp$establishment_weights
  O <- vapply(seq_along(rows), function(i) { j <- seq_len(held[i])
    sum(wt[j] * rows[[i]]$state[per * (j - 1) + at_o]) }, 0)
  i <- which(diff(held) == 0 & diff(tt) > 0)
  out$stand$establishment <- list(start = tt[i], end = tt[i + 1], rate = (E[i + 1] - E[i]) / (tt[i + 1] - tt[i]))
  out$stand$remaining <- list(time = tt, share = 1 - O / tail(O, 1))
}
write_out()
if (Sys.getenv("FORWARD") != "1") {
  c0 <- cpu()
  g <- plant:::census_trait_gradient_tf24(scm, "offspring_production")
  out$sweep_cpu <- cpu() - c0
  grad <- setNames(g$gradient[[1]], plant:::census_trait_names_tf24(scm))
  pars <- p$strategies[[1]]$pars
  theta <- vapply(names(grad), function(n) pars[[sub("^1\\.", "", n)]], 0)
  out$stand$elasticity <- ifelse(theta == 0, 1, theta) * grad / out$stand$J
  out$stand$refusal <- g$refusal[["offspring_production"]]
}
out$finished <- format(Sys.time())
write_out()
cat(sprintf("%s: J %.10g, %d steps, %.0f rows, forward %.0f s, sweep %.0f s\n", scen, out$stand$J,
            length(t), out$stand$rows, out$stand$cpu, if (is.null(out$sweep_cpu)) 0 else out$sweep_cpu))
