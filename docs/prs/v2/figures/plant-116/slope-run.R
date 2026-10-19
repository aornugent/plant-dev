# plant-116: why Newton converges linearly. At b* (newton.csv, ode_tol 1e-6) on
# B95: the swept d ln J/d ln b, a central difference of runs pinned to the
# resident's own steps, and a central difference of adaptive runs (step 1e-4 in ln b).
#   PLANT_LIB=<B95> Rscript slope-run.R
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-116"
source(file.path(here, "fixture.R")); load_plant()
nw <- read.csv(file.path(here, "newton.csv")); b <- nw$b[nw$tol == 1e-6]; b <- b[length(b)]
scm <- fitness_stand_run(fitness_stand_parameters(b), 1e-6, record = TRUE)
g <- stand_gradient(scm, metrics = "1.offspring_production", traits = "1.birth_rate")
J <- g$value[[1]]; swept <- b * g$gradient[[1]] / J
pinned <- function(x) {
  q <- fitness_stand_parameters(x); q$ode_times <- scm$ode_times; q$ode_step_sizes <- scm$ode_step_sizes
  log(fitness_stand_run(q, 1e-6, record = FALSE)$offspring_production)
}
adaptive <- function(x) log(fitness_stand_run(fitness_stand_parameters(x), 1e-6, record = FALSE)$offspring_production)
h <- 1e-4
fd_p <- (pinned(b * exp(h)) - pinned(b * exp(-h))) / (2 * h)
fd_a <- (adaptive(b * exp(h)) - adaptive(b * exp(-h))) / (2 * h)
cat(sprintf("b* %.10g: d ln J/d ln b swept %.6f, pinned-step difference %.6f, adaptive difference %.6f (%.1f%% off)\n",
            b, swept, fd_p, fd_a, 100 * (fd_a / swept - 1)))
cat(sprintf("predicted Newton contraction |1 - (s_a - 1)/(s - 1)| = %.3f\n", abs(1 - (fd_a - 1) / (swept - 1))))
