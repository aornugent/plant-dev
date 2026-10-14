# plant's test-scm.R fixtures under the build in R_LIBS: the daily-rain stand
# without stops against the same stand stopped at every knot, and the share of
# steps that substep the soil in the seasonal replay fixture.
# Usage: Rscript fixture.R [SRC]  (SRC: a plant source tree to load_all; else
# library(plant) from R_LIBS).
library(odelia)
a <- commandArgs(TRUE)
if (length(a)) pkgload::load_all(a[[1]], quiet = TRUE) else library(plant)
p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- 2
p0$patch_type <- "fixed"
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
set.seed(4)
days <- seq(0, 2 * 365 + 5)
rain <- ifelse(runif(length(days)) < 0.15, rgamma(length(days), 0.8, 0.2), 0)
knots <- local({
  wet <- rain != 0
  n <- length(wet)
  x <- (days / 365)[wet | c(FALSE, wet[-n]) | c(wet[-1], FALSE)]
  x[x > 0 & x < 2]
})
env <- function() {
  e <- Environment("TF24")
  e$extrinsic_drivers_set_variable("rainfall", days / 365, rain)
  e
}
J <- function(r) sum(r$offspring_production)
for (setting in list(c(share = 0.1, tol = 1e-4), c(share = 0.1, tol = 1e-5),
                     c(share = 0.1, tol = 1e-6), c(share = 0, tol = 1e-4),
                     c(share = 0, tol = 1e-5), c(share = 0, tol = 1e-6))) {
  ctrl <- control_tf24(setting[["tol"]], Control(node_density_in_birth_date = TRUE))
  ctrl$ode_soil_substep_max_uptake <- setting[["share"]]
  stops <- events(events_default(p),
                  rainfall_pulse(time = knots, depth = rep(0, length(knots))))
  stopped <- run_scm(p, env(), ctrl, events = stops)
  free <- run_scm(p, env(), ctrl)
  cat(sprintf("share %.1f tol %g: stopped %d steps (%d substepped) | free %d steps (%d substepped), J free/stopped - 1 = %+.2e\n",
              setting[["share"]], setting[["tol"]], length(stopped$ode_times) - 1,
              sum(lengths(stopped$ode_soil_substep_ends) > 0),
              length(free$ode_times) - 1, sum(lengths(free$ode_soil_substep_ends) > 0),
              J(free) / J(stopped) - 1))
  if (setting[["tol"]] == 1e-6) ref <- J(stopped)
}
ctrl <- control_tf24(1e-7, Control(node_density_in_birth_date = TRUE))
ctrl$ode_soil_substep_max_uptake <- 0
ref <- J(run_scm(p, env(), ctrl, events = events(events_default(p),
  rainfall_pulse(time = knots, depth = rep(0, length(knots))))))
cat(sprintf("reference (coupled, stopped, 1e-7): J %.12g\n", ref))
for (setting in list(c(0.1, 1e-4), c(0.1, 1e-5), c(0.1, 1e-6), c(0, 1e-4), c(0, 1e-5), c(0, 1e-6))) {
  ctrl <- control_tf24(setting[2], Control(node_density_in_birth_date = TRUE))
  ctrl$ode_soil_substep_max_uptake <- setting[1]
  free <- run_scm(p, env(), ctrl)
  cat(sprintf("free share %.1f tol %g: J/ref - 1 = %+.2e, %d steps\n", setting[1], setting[2],
              J(free) / ref - 1, length(free$ode_times) - 1))
}
# The seasonal fixture of "A run that substepped the soil replays...".
p0$max_patch_lifetime <- 3
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
env3 <- function() {
  e <- Environment("TF24")
  t <- seq(0, 3, length.out = 601)
  e$extrinsic_drivers_set_variable("rainfall", t, 0.25 * (1 + 0.95 * sin(2 * pi * t)))
  e
}
ctrl <- control_tf24(1e-4, Control(node_density_in_birth_date = TRUE,
                                   ode_split_sign_changes = TRUE))
r <- run_scm(p, env3(), ctrl)
cat(sprintf("seasonal fixture: %d steps, substepped share %.3f, J %.12g\n",
            length(r$ode_times) - 1, mean(lengths(r$ode_soil_substep_ends) > 0), J(r)))
