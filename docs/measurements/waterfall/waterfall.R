# The waterfall (prereg.txt here): one cumulative configuration on long drought,
# the stand's forward and its gradient timed, and for the last its pilot.
#   brute     215 introductions, tied tolerance 1e-5, plain control
#   halved    the same on 108 introductions
#   cut       + the cut at sign changes, tolerance 3e-5
#   preset    + control_tf24's soil weight, bound and cap, the soil coupled
#   alone     + the soil stepped alone below a share of 0.1
#   window    + the window's weights from a pilot, the pilot timed with it
#   PLANT_LIB=... CONFIG=cut OUT=x.rds Rscript docs/measurements/waterfall/waterfall.R
local({
  source("harness/long_drought.R")
})
config <- Sys.getenv("CONFIG")
regime <- "long-drought"
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
tied <- function(tol, ct) { ct$ode_tol_rel <- tol; ct$ode_tol_abs <- 1e-4 * tol; ct }
birth <- Control(node_density_in_birth_date = TRUE)
split <- Control(node_density_in_birth_date = TRUE, ode_split_sign_changes = TRUE)
preset <- function(share) {
  ct <- control_tf24(3e-5, split)
  ct$ode_soil_alone_share <- share
  ct
}
out <- list(config = config, regime = regime, lib = Sys.getenv("PLANT_LIB"))
nodes <- if (config == "brute") 215L else 108L
ct <- switch(config,
  brute = tied(1e-5, birth), halved = tied(1e-5, birth), cut = tied(3e-5, split),
  preset = preset(0), alone = preset(0.1), window = preset(0.1))
if (config == "window") {
  pt <- uniform_times(54)
  pp <- stand_at(pt)
  t0 <- clock()
  pilot <- run_scm(pp, mkenv(scen), control_tf24(1e-3, birth), events = knots(pp),
                   record_trajectory = TRUE)
  ct <- control_window(pilot, list(stand_at(pt, "lma", 0.5), stand_at(pt, "lma", 2)),
                       base = ct)
  out$pilot_secs <- clock() - t0
}
p <- stand_at(uniform_times(nodes))
t0 <- clock()
scm <- run_scm(p, mkenv(scen), ct, events = knots(p), record_trajectory = TRUE)
out$forward_secs <- clock() - t0
out$J <- sum(scm$offspring_production)
out$steps <- length(scm$ode_times) - 1L
t0 <- clock()
out$elasticity <- elasticities(scm, p)
out$gradient_secs <- clock() - t0
saveRDS(out, Sys.getenv("OUT"))
cat(sprintf("%s: J %.10g, %d steps, forward %.1f s, gradient %.1f s, pilot %s s\n", config,
            out$J, out$steps, out$forward_secs, out$gradient_secs,
            if (is.null(out$pilot_secs)) "-" else sprintf("%.1f", out$pilot_secs)))
