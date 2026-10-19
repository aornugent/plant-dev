# The TF24 fitness stand of test-tf24-fitness-gradient.R: one species with hmat
# lowered to 6 m and TF24_floor_lambda_o 0, 6 years, 12 introductions from the
# default schedule, constant rain 1 m/yr, soil starting half full, birth date.
fitness_stand_parameters <- function(birth_rate, lma_factor = 1) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- 6
  lma <- p$strategy_default$pars[["lma"]]
  p <- add_strategies(p, trait_matrix(c(0, 6, lma * lma_factor),
                                      c("TF24_floor_lambda_o", "hmat", "lma")),
                      hyperpar = TF24_hyperpar, birth_rate = birth_rate)
  full <- p$node_schedule_times[[1]]
  p$node_schedule_times <- list(full[round(seq(1, length(full), length.out = 12))])
  p
}
fitness_stand_environment <- function() {
  env <- Environment("TF24")
  env$set_soil_water_state(rep(0.428 * 0.5, env$get_soil_number_of_depths()))
  env$extrinsic_drivers_set_constant("rainfall", 1)
  env
}
fitness_stand_run <- function(p, tol = 1e-6, record = TRUE) {
  run_scm(p, fitness_stand_environment(),
          Control(node_density_in_birth_date = TRUE, ode_tol_rel = tol, ode_tol_abs = tol),
          record_trajectory = record)
}
load_plant <- function() {
  lib <- Sys.getenv("PLANT_LIB")
  .libPaths(c(lib, .libPaths()))
  suppressMessages({library(odelia, lib.loc = lib); library(plant, lib.loc = lib)})
  cat(sprintf("plant %s, odelia %s from %s\n", packageVersion("plant"),
              packageVersion("odelia"), lib))
}
