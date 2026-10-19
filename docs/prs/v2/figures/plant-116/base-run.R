# plant-116, the base (B105) on the same calls: what a TF24 stand offers
# before this change.  PLANT_LIB=<lib> Rscript base-run.R
source("/home/user/plant-dev/docs/prs/v2/figures/plant-116/fixture.R"); load_plant()
env  <- fitness_stand_environment()
ctrl <- Control(node_density_in_birth_date = TRUE, ode_tol_rel = 1e-6, ode_tol_abs = 1e-6)
scm <- run_scm(fitness_stand_parameters(21.49367145), env, ctrl, record_trajectory = TRUE)
show <- function(expr) tryCatch(print(expr), error = function(e) cat("Error:", conditionMessage(e), "\n"))
show(stand_gradient(scm, metrics = "1.offspring_production", traits = "1.birth_rate")$gradient)
two <- fitness_stand_parameters(1, 1)
two$strategies <- c(two$strategies, fitness_stand_parameters(1, 0.9)$strategies)
two$node_schedule_times <- rep(two$node_schedule_times, 2)
show({ scm$run_mutant(two); scm$net_reproduction_ratios })
show({ scm$run_mutant(fitness_stand_parameters(1, 0.9)); scm$net_reproduction_ratios })
