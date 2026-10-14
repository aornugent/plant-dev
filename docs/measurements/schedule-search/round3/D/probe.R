# PIN replay of a saved run, then its sweep, the differentiated diagnostics, and
# forward tangents along TANGENT (comma-separated trait names). Env as adj_run.R.
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap"
Sys.setenv(PLANT_LIB = Sys.getenv("LIB", file.path(A, "lib")))
source("/home/user/plant-dev/harness/long_drought.R")
regime <- Sys.getenv("REGIME", SCEN)
seed <- as.integer(Sys.getenv("SEED", RAIN_SPECS[[regime]]$seed))
tol <- as.numeric(Sys.getenv("TOL", "3e-5")); atol <- as.numeric(Sys.getenv("ATOL", "1e-4"))
scen <- sprintf("%s, seed %d", regime, seed)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = seed))
knots <- active_knots(scen)
times <- readRDS(Sys.getenv("TIMES"))
out_file <- Sys.getenv("OUT")
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
moved <- function(q, spec) {
  s <- q$strategies[[1]]
  for (kv in strsplit(strsplit(spec, ",")[[1]], "=")) s$pars[[kv[1]]] <- s$pars[[kv[1]]] * (1 + as.numeric(kv[2]))
  q$strategies[[1]] <- s; q
}
if (nzchar(Sys.getenv("TRAIT_REL"))) p <- moved(p, Sys.getenv("TRAIT_REL"))
p$node_schedule_times <- list(times)
pinned <- readRDS(Sys.getenv("PIN"))
base <- pinned$stand
p$ode_times <- base$times; p$ode_step_sizes <- base$sizes
p$ode_soil_input_slopes <- base$input_slopes; p$ode_soil_substep_ends <- base$substep_ends
ct <- control()
ct$ode_tol_rel <- tol; ct$ode_tol_abs <- atol * tol
ct$node_density_in_birth_date <- TRUE
env_num <- function(v) as.numeric(Sys.getenv(v))
if (nzchar(Sys.getenv("WEIGHT_SOIL"))) ct$ode_tol_factor_soil <- env_num("WEIGHT_SOIL")
w <- readRDS(Sys.getenv("WEIGHT")); ct$ode_tol_factor_times <- w$t; ct$ode_tol_factor_values <- w$weight
if (nzchar(Sys.getenv("WEIGHT_MAX"))) ct$ode_tol_factor_max <- env_num("WEIGHT_MAX")
if (nzchar(Sys.getenv("HMAX"))) ct$ode_step_size_max <- env_num("HMAX") / 365
if (Sys.getenv("SPLIT") == "1") ct$ode_split_sign_changes <- TRUE
if (nzchar(Sys.getenv("SHARE"))) ct$ode_soil_substep_max_uptake <- env_num("SHARE")
if (nzchar(Sys.getenv("FLOOR"))) ct$gradient_curvature_floor <- env_num("FLOOR")
ev <- events(events_default(p), pulse_rows(sort(unique(knots))))
types <- plant:::extract_RcppR6_template_types(p, "Parameters")
scm <- do.call(plant:::SCM, types)(p, mkenv(scen), ev, ct)
scm$record_trajectory <- TRUE
cpu <- function() sum(proc.time()[c("user.self", "sys.self")])
c0 <- cpu(); scm$run()
out <- list(J = sum(scm$offspring_production), J_saved = base$J, steps = length(scm$ode_times),
            same_times = isTRUE(all.equal(scm$ode_times, base$times, tolerance = 0)), fwd_cpu = cpu() - c0)
cat(sprintf("J %.12g saved %.12g diff %.3g; same times %s; %.0f s\n", out$J, base$J, out$J - base$J, out$same_times, out$fwd_cpu))
sv <- function() if (nzchar(out_file)) saveRDS(out, out_file)
if (Sys.getenv("SOILREC") == "1") {
  rows <- scm$store_trajectory()
  out$soil <- list(time = vapply(rows, `[[`, 0, "time"),
                   theta = t(vapply(rows, function(r) head(tail(r$state, 10), 5), numeric(5))))
}
sv()
nm <- plant:::census_trait_names_tf24(scm)
pars <- p$strategies[[1]]$pars
theta <- vapply(nm, function(n) pars[[sub("^1\\.", "", n)]], 0)
if (Sys.getenv("SWEEP", "1") == "1") {
  plant:::census_clear_diagnostics_tf24(scm)
  c0 <- cpu()
  g <- plant:::census_trait_gradient_tf24(scm, "offspring_production")
  out$sweep_cpu <- cpu() - c0
  out$gradient <- setNames(g$gradient[[1]], nm)
  out$refusal <- g$refusal
  out$elasticity <- ifelse(theta == 0, 1, theta) * out$gradient / out$J
  out$margin <- plant:::census_curvature_margin_tf24(scm)
  out$clamps_diff <- tryCatch(plant:::census_clamp_counts_differentiated_tf24(scm), error = function(e) conditionMessage(e))
  out$opcounts <- tryCatch(plant:::census_operating_point_counts_tf24(scm), error = function(e) conditionMessage(e))
  cat(sprintf("sweep %.0f s; max|el| %.1f; margin %s; refusal %s\n", out$sweep_cpu, max(abs(out$elasticity)),
      paste(format(out$margin), collapse = " "), paste(format(out$refusal), collapse = " ")))
  if (!is.null(pinned$stand$gradient)) cat("max |sweep - saved gradient| / max|saved|:",
      max(abs(out$gradient - pinned$stand$gradient)) / max(abs(pinned$stand$gradient)), "\n")
  sv()
}
for (tn in strsplit(Sys.getenv("TANGENT", ""), ",")[[1]]) {
  d <- as.numeric(nm == paste0("1.", tn))
  c0 <- cpu()
  tg <- plant:::ladder_trajectory_tangent_tf24(scm, d)
  off <- length(tg$tangent)  # offspring_production is the last census metric
  out$tangent[[tn]] <- list(value = tg$value, tangent = tg$tangent, cpu = cpu() - c0,
                            elasticity = theta[[paste0("1.", tn)]] * tg$tangent[off] / out$J)
  cat(sprintf("tangent %s: elasticity %.4f (value %.12g), %.0f s\n", tn, out$tangent[[tn]]$elasticity, tg$value[off], cpu() - c0))
  sv()
}
out$finished <- TRUE; sv()
