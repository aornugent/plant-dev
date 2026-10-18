# The hint's effect with the steps held: a run (hint off) saves its stand; a second process
# (hint on) replays those steps, so any difference is the roots', not the controller's.
#   LIFETIME=.. CASE=.. PLANT_LIB=<ws lib> [PLANT_HINT_WIDTH=w] Rscript ws_check.R OUT [BASE]
a <- commandArgs(TRUE); CASE <- Sys.getenv("CASE", "episodic-lma")
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine2/perf/common.R")
cs <- case_setup(CASE)
times <- if (Sys.getenv("LIFETIME") == "") r22_nodes(CASE)$S else seq(0, HORIZON, length.out = 12)
base <- if (length(a) > 1) list(stand = readRDS(a[2])$stand) else NULL
p <- cs$p; p$node_schedule_times <- list(times)
if (!is.null(base)) { p$ode_times <- base$stand$times; p$ode_step_sizes <- base$stand$sizes
  p$ode_soil_input_slopes <- base$stand$input_slopes; p$ode_soil_substep_ends <- base$stand$substep_ends }
types <- plant:::extract_RcppR6_template_types(p, "Parameters")
scm <- do.call(plant:::SCM, types)(p, cs$env, events(events_default(p)), cs$ctrl)
scm$record_trajectory <- TRUE
c0 <- proc.time()[["user.self"]]; scm$run(); fwd <- proc.time()[["user.self"]] - c0
counts <- plant:::census_operating_point_counts_tf24(scm)
c0 <- proc.time()[["user.self"]]; g <- plant:::census_trait_gradient_tf24(scm, "offspring_production"); sw <- proc.time()[["user.self"]] - c0
J <- sum(scm$offspring_production)
grad <- setNames(g$gradient[[1]], plant:::census_trait_names_tf24(scm)); pars <- p$strategies[[1]]$pars
theta <- vapply(names(grad), function(n) pars[[sub("^1\\.", "", n)]], 0)
x <- list(stand = list(J = J, times = scm$ode_times, sizes = scm$ode_step_sizes, input_slopes = scm$ode_soil_input_slopes,
          substep_ends = scm$ode_soil_substep_ends, elasticity = ifelse(theta == 0, 1, theta) * grad / J),
          counts = counts, cpu = c(forward = fwd, sweep = sw))
saveRDS(x, a[1])
cat(sprintf("J %.15g steps %d fwd %.1f s sweep %.1f s\n", J, length(scm$ode_times), fwd, sw)); print(counts)
