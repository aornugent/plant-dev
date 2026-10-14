# One stand run on the stack tip (PLANT-110 + the node drop), at the harness's
# settings with lib_109's control names mapped to the stack's. Modes:
#   plain: the stand (and gradient unless FORWARD=1), then INVADERS_REL walks.
#   map:   the stand, then the sweep of offspring_production with the node drop
#          at zero: every dropped node's light and soil coefficient per time band
#          is a gradient column after the 50 traits.
#   drop1: the stand with the drop's coefficients at LIGHT and SOIL (default 1),
#          so its field is the coarser schedule's to first order; then the
#          INVADERS_REL walks in that field.
# Env: as harness/run_record.R (REGIME SEED TOL ATOL NODES TIMES WEIGHT_SOIL WEIGHT
# WEIGHT_MAX HMAX SHARE SPLIT TRAIT_REL INVADERS_REL OUT), plus MODE, LIB, PIN
# (replay that run's steps), COARSE (rds of the coarser schedule, or "odd": drop
# every other node, the first and last kept).
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap"
Sys.setenv(PLANT_LIB = Sys.getenv("LIB", file.path(A, "lib")))
source("/home/user/plant-dev/harness/long_drought.R")
mode <- Sys.getenv("MODE", "plain")
regime <- Sys.getenv("REGIME", SCEN)
seed <- as.integer(Sys.getenv("SEED", RAIN_SPECS[[regime]]$seed))
tol <- as.numeric(Sys.getenv("TOL", "3e-5"))
atol <- as.numeric(Sys.getenv("ATOL", "1e-4"))
scen <- sprintf("%s, seed %d", regime, seed)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = seed))
knots <- active_knots(scen)
# G: KNOT_MAX keeps only the rainfall knots before that patch age as step targets.
if (nzchar(Sys.getenv("KNOT_MAX"))) knots <- knots[knots < as.numeric(Sys.getenv("KNOT_MAX"))]
times <- uniform_times(as.integer(Sys.getenv("NODES", "108")))
if (nzchar(Sys.getenv("TIMES"))) times <- readRDS(Sys.getenv("TIMES"))
out_file <- Sys.getenv("OUT")
BANDS <- c(0.5, 1, 2, 3, 5, 10, 20)

p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
moved <- function(q, spec) {
  s <- q$strategies[[1]]
  for (kv in strsplit(strsplit(spec, ",")[[1]], "=")) {
    s$pars[[kv[1]]] <- s$pars[[kv[1]]] * (1 + as.numeric(kv[2]))
  }
  q$strategies[[1]] <- s
  q
}
if (nzchar(Sys.getenv("TRAIT_REL"))) p <- moved(p, Sys.getenv("TRAIT_REL"))
p$node_schedule_times <- list(times)
if (nzchar(Sys.getenv("PIN"))) {
  base <- readRDS(Sys.getenv("PIN"))$stand
  p$ode_times <- base$times
  p$ode_step_sizes <- base$sizes
  p$ode_soil_input_slopes <- base$input_slopes
  p$ode_soil_substep_ends <- base$substep_ends
}
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- atol * tol
ct$node_density_in_birth_date <- TRUE
env_num <- function(v) as.numeric(Sys.getenv(v))
if (nzchar(Sys.getenv("WEIGHT_SOIL"))) ct$ode_tol_factor_soil <- env_num("WEIGHT_SOIL")
if (nzchar(Sys.getenv("WEIGHT"))) {
  w <- readRDS(Sys.getenv("WEIGHT"))
  ct$ode_tol_factor_times <- w$t
  ct$ode_tol_factor_values <- w$weight
}
if (nzchar(Sys.getenv("WEIGHT_MAX"))) ct$ode_tol_factor_max <- env_num("WEIGHT_MAX")
if (nzchar(Sys.getenv("HMAX"))) ct$ode_step_size_max <- env_num("HMAX") / 365
if (Sys.getenv("SPLIT") == "1") ct$ode_split_sign_changes <- TRUE
if (nzchar(Sys.getenv("SHARE"))) ct$ode_soil_substep_max_uptake <- env_num("SHARE")
ev <- events(events_default(p), pulse_rows(sort(unique(knots))))

# The dropped nodes, counting from one: those of `times` the coarser schedule lacks.
dropped <- NULL
if (nzchar(Sys.getenv("COARSE"))) {
  cs <- Sys.getenv("COARSE")
  dropped <- if (cs == "odd") seq(2, length(times) - 1, by = 2) else
    which(!(round(times, 10) %in% round(readRDS(cs), 10)))
}
nb <- length(BANDS) + 1

cpu <- function() sum(proc.time()[c("user.self", "sys.self")])
per_node <- function(scm) {
  sp <- scm$patch$species[[1]]
  state <- matrix(sp$ode_state, ncol = sp$size, dimnames = list(sp$new_node$ode_names))
  list(birth = sp$node_times, establishment = sp$establishment_weights,
       nrr = sp$net_reproduction_ratio_by_node, state = state)
}
# Accepted steps times the nodes alive at each step's start, the boundary node with them.
rows_of <- function(scm) {
  t <- scm$ode_times
  sum(vapply(t[-length(t)], function(s) sum(times <= s) + 1, 0))
}
out <- list(mode = mode, setting = list(regime = regime, seed = seed, tol = tol, atol = atol,
            env = Sys.getenv(c("WEIGHT_SOIL", "WEIGHT", "WEIGHT_MAX", "HMAX", "SHARE", "SPLIT",
                               "TRAIT_REL", "PIN", "COARSE", "LIB", "KNOT_MAX")), lifetime = LIFETIME),
            node_times = times, dropped = dropped, bands = BANDS, started = format(Sys.time()))
save <- function() if (nzchar(out_file)) saveRDS(out, out_file)

types <- plant:::extract_RcppR6_template_types(p, "Parameters")
scm <- do.call(plant:::SCM, types)(p, mkenv(scen), ev, ct)
if (mode %in% c("map", "drop1")) {
  stopifnot(length(dropped) > 0)
  k <- length(dropped) * nb
  light <- if (mode == "map") 0 else as.numeric(Sys.getenv("LIGHT", "1"))
  soil <- if (mode == "map") 0 else as.numeric(Sys.getenv("SOIL", "1"))
  plant:::node_drop_set_tf24(scm, dropped, BANDS, rep(light, k), rep(soil, k))
}
scm$record_trajectory <- TRUE
c0 <- cpu()
scm$run()
out$stand <- list(J = sum(scm$offspring_production), times = scm$ode_times,
                  sizes = scm$ode_step_sizes, input_slopes = scm$ode_soil_input_slopes,
                  substep_ends = scm$ode_soil_substep_ends, splits = scm$ode_splits,
                  nodes = per_node(scm), rows = rows_of(scm), cpu = cpu() - c0)
save()
# SOILREC=1: the soil layers at every recorded state, and the forward clamp tallies.
if (Sys.getenv("SOILREC") == "1") {
  rows <- scm$store_trajectory()
  out$soil <- list(time = vapply(rows, `[[`, 0, "time"),
                   theta = t(vapply(rows, function(r) head(tail(r$state, 10), 5), numeric(5))))
  out$forward_clamps_all <- tryCatch(plant:::census_clamp_counts_tf24(scm), error = function(e) conditionMessage(e))
  out$forward_clamps <- tryCatch(setNames(plant:::census_clamp_counts_tf24(scm)[[1]][3:5],
    c("moisture_floor", "potential_ceiling", "positivity")), error = function(e) conditionMessage(e))
  save()
}
cat(sprintf("%s %s: J %.12g, %d steps, %.0f rows, %.0f s\n", scen, mode, out$stand$J,
            length(out$stand$times), out$stand$rows, out$stand$cpu))

# SWEEP0=1: first the sweep without the drop's columns, timed, in the same process.
if (mode == "map" && Sys.getenv("SWEEP0") == "1") {
  plant:::node_drop_set_tf24(scm, integer(0), BANDS, numeric(0), numeric(0))
  c0 <- cpu()
  g0 <- plant:::census_trait_gradient_tf24(scm, "offspring_production")
  out$sweep0_cpu <- cpu() - c0
  out$sweep0_gradient <- setNames(g0$gradient[[1]], plant:::census_trait_names_tf24(scm))
  k <- length(dropped) * nb
  plant:::node_drop_set_tf24(scm, dropped, BANDS, rep(0, k), rep(0, k))
  save()
}
if ((mode == "plain" && Sys.getenv("FORWARD") != "1") || mode == "map") {
  c0 <- cpu()
  g <- plant:::census_trait_gradient_tf24(scm, "offspring_production")
  out$sweep_cpu <- cpu() - c0
  grad <- setNames(g$gradient[[1]], plant:::census_trait_names_tf24(scm))
  out$refusal <- g$refusal
  traits <- grad[!grepl("^drop\\.", names(grad))]
  pars <- p$strategies[[1]]$pars
  theta <- vapply(names(traits), function(n) pars[[sub("^1\\.", "", n)]], 0)
  out$stand$gradient <- traits
  out$stand$elasticity <- ifelse(theta == 0, 1, theta) * traits / out$stand$J
  if (mode == "map") {
    m <- length(dropped) * nb
    out$light <- matrix(grad[length(traits) + seq_len(m)], nrow = nb)
    out$soil <- matrix(grad[length(traits) + m + seq_len(m)], nrow = nb)
    cat(sprintf("map: light %+.5f%%, soil %+.5f%% of J; sweep %.0f s\n",
                100 * sum(out$light) / out$stand$J, 100 * sum(out$soil) / out$stand$J, out$sweep_cpu))
  }
  save()
}
for (inv in strsplit(Sys.getenv("INVADERS_REL", ""), ",")[[1]]) {
  c0 <- cpu()
  scm$run_mutant(moved(p, inv))
  out$invaders[[inv]] <- list(J = sum(scm$offspring_production), nodes = per_node(scm), cpu = cpu() - c0)
  save()
}
out$finished <- format(Sys.time())
save()
