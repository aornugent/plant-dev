# plant-116 whole game, run verbatim on B95: Newton to the resident's
# equilibrium birth rate, then an invader's fitness and gradient there.
#   PLANT_LIB=<B95> Rscript wholegame-run.R
source("/home/user/plant-dev/docs/prs/v2/figures/plant-116/fixture.R"); load_plant()
env  <- fitness_stand_environment()
ctrl <- Control(node_density_in_birth_date = TRUE, ode_tol_rel = 1e-6, ode_tol_abs = 1e-6)

b <- 10
repeat {
  scm <- run_scm(fitness_stand_parameters(b), env, ctrl, record_trajectory = TRUE)
  g <- stand_gradient(scm, metrics = "1.offspring_production", traits = "1.birth_rate")
  J <- g$value[[1]]
  cat(sprintf("b %-12.10g ln J - ln b %+.2e\n", b, log(J) - log(b)))
  if (abs(log(J) - log(b)) < 1e-8) break
  b <- exp(log(b) - (log(J) - log(b)) / (b * g$gradient[[1]] / J - 1))
}

scm$run_mutant(fitness_stand_parameters(1, lma_factor = 0.9))
gi <- stand_gradient(scm, metrics = "1.net_reproduction_ratio",
                     traits = c("1.lma", "1.hmat"))
gi$value
gi$gradient
