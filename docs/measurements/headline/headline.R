# The headline (prereg.txt here): one record under one configuration, the stand's
# forward and, where the build has one, its gradient, timed.
#   develop  upstream develop as installed, plant's default Control, 108 nodes
#   floor    brute force on the stack: 215 uniform nodes at 1e-5, plain control
#   stack    control_tf24(3e-5) with the soil alone, the pilot's window and the
#            splits, 108 nodes; the pilot is timed with the run
#   PLANT_LIB=... CONFIG=stack REGIME=long-drought OUT=x.rds \
#     Rscript docs/measurements/headline/headline.R     # from plant-dev's root
local({
  source("harness/long_drought.R")
})
config <- Sys.getenv("CONFIG")
regime <- Sys.getenv("REGIME")
scen <- sprintf("%s, seed %d", regime, RAIN_SPECS[[regime]]$seed)
RAIN_SPECS[[scen]] <- RAIN_SPECS[[regime]]
clock <- function() proc.time()[["elapsed"]]
knots <- function(p) events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))
elasticities <- function(scm, p) {
  g <- stand_gradient(scm, metrics = "offspring_production")
  grad <- g$gradient["offspring_production", ]
  pars <- p$strategies[[1]]$pars
  theta <- vapply(names(grad), function(n) pars[[sub("^1\\.", "", n)]], 0)
  ifelse(theta == 0, 1, theta) * grad / sum(scm$offspring_production)
}
out <- list(config = config, regime = regime, lib = Sys.getenv("PLANT_LIB"))

if (config == "develop") {
  p <- stand_at(uniform_times(108))
  t0 <- clock()
  scm <- run_scm(p, mkenv(scen), Control())
  out$forward_secs <- clock() - t0
} else if (config == "floor") {
  p <- stand_at(uniform_times(215))
  ct <- Control(node_density_in_birth_date = TRUE)
  ct$ode_tol_rel <- 1e-5
  ct$ode_tol_abs <- 1e-9
  t0 <- clock()
  scm <- run_scm(p, mkenv(scen), ct, events = knots(p), record_trajectory = TRUE)
  out$forward_secs <- clock() - t0
} else if (config == "stack") {
  base <- control_tf24(3e-5, Control(node_density_in_birth_date = TRUE,
                                     ode_split_sign_changes = TRUE))
  base$ode_soil_alone_share <- 0.1
  pt <- uniform_times(54)
  pp <- stand_at(pt)
  pc <- control_tf24(1e-3, Control(node_density_in_birth_date = TRUE))
  pc$ode_soil_alone_share <- 0.1
  t0 <- clock()
  pilot <- run_scm(pp, mkenv(scen), pc, events = knots(pp), record_trajectory = TRUE)
  ct <- control_window(pilot, list(stand_at(pt, "lma", 0.5), stand_at(pt, "lma", 2)),
                       base = base)
  out$pilot_secs <- clock() - t0
  p <- stand_at(uniform_times(as.integer(Sys.getenv("NODES", "108"))))
  t0 <- clock()
  scm <- run_scm(p, mkenv(scen), ct, events = knots(p), record_trajectory = TRUE)
  out$forward_secs <- clock() - t0
}
out$J <- sum(scm$offspring_production)
out$steps <- length(scm$ode_times) - 1L
if (config != "develop") {
  t0 <- clock()
  out$elasticity <- elasticities(scm, p)
  out$gradient_secs <- clock() - t0
}
saveRDS(out, Sys.getenv("OUT"))
cat(sprintf("%s %s: J %.10g, %d steps, forward %.1f s, gradient %s s, pilot %s s\n", config,
            regime, out$J, out$steps, out$forward_secs,
            if (is.null(out$gradient_secs)) "-" else sprintf("%.1f", out$gradient_secs),
            if (is.null(out$pilot_secs)) "-" else sprintf("%.1f", out$pilot_secs)))
