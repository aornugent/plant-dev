# The bank cases at the refine loop's run setting (harness/schedule/refine_case.R), with a
# tolerance argument for the references.
WEIGHTS <- file.path(Sys.getenv("PLANT_DEV", "."), "harness/schedule/data/weights")
CASES <- list(
  dry = list(regime = "dry", trait = c(), weight = "dry"),
  `long-wet` = list(regime = "long-wet", trait = c(), weight = "long-wet"),
  episodic = list(regime = "episodic", trait = c(), weight = "episodic"),
  `episodic-lma` = list(regime = "episodic", trait = c(lma = 1.25), weight = "episodic"),
  `dry-flat` = list(regime = "dry-flat", trait = c(), weight = "dry"),
  `epi-adG208` = list(regime = "episodic", trait = c(a_dG2 = 0.8), weight = "episodic"))

case_setup <- function(name, tol = 1e-4) {
  case <- CASES[[name]]
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(LMA0, "lma"))
  for (n in names(case$trait)) p$strategies[[1]]$pars[[n]] <- p$strategies[[1]]$pars[[n]] * case$trait[[n]]
  ctrl <- control()
  ctrl$ode_tol_rel <- tol
  ctrl$ode_tol_abs <- tol * 1e-4
  ctrl$node_density_in_birth_date <- TRUE
  ctrl$ode_tol_factor_soil <- 10
  w <- readRDS(file.path(WEIGHTS, sprintf("weight_%s.rds", case$weight)))
  ctrl$ode_tol_factor_times <- w$t
  ctrl$ode_tol_factor_values <- w$weight
  ctrl$ode_tol_factor_max <- 100
  ctrl$ode_step_size_max <- 15 / 365
  ctrl$ode_soil_substep_max_uptake <- 0.1
  list(p = p, env = mkenv(case$regime), ctrl = ctrl)
}
