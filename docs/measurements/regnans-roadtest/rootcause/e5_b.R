# E5: how the selection gradient and F = ln J - ln b move with ln b around b*,
# long drought, 201 uniform nodes, the roadtest's tolerances. With E3's run at b*
# this gives dg/d ln b, so how loosely the equilibrium may be solved for g.
.libPaths(c(Sys.getenv("PLANT_LIB"), .libPaths()))
source("/home/user/plant-dev/harness/long_drought.R")
d <- as.numeric(commandArgs(TRUE)[[1]]); out <- commandArgs(TRUE)[[2]]
ENV <- mkenv("long-drought"); B <- 4.6759709 * exp(d)
stand <- function(lma, b, times) {
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(lma, "lma"), hyperpar = TF24_hyperpar,
                      birth_rate = as.list(rep_len(b, length(lma))))
  p$node_schedule_times <- rep(list(times), length(lma)); p }
ctrl <- control(); ctrl$node_density_in_birth_date <- TRUE
ctrl$ode_tol_rel <- 1e-4; ctrl$ode_tol_abs <- 1e-8; ctrl$ode_step_size_max <- 15 / 365
times <- uniform_times(201)
scm <- run_scm(stand(LMA0, B, times), ENV, ctrl, record_trajectory = TRUE)
J <- sum(scm$offspring_production); h <- 1e-3
scm$run_mutant(stand(LMA0 * exp(c(-h, h, 0)), 1, times)); lr <- log(scm$net_reproduction_ratios)
r <- data.frame(dlnb = d, b = B, F = log(J) - log(B), grad = (lr[2] - lr[1]) / (2 * h), lnR_self = lr[3])
print(r, digits = 7); saveRDS(r, out)
