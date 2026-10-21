# E2: the node count regnans's quantities need on long drought at b*: ln J, the
# invader's ln R' gradient in ln lma along the trade-off (central difference,
# h = 1e-3), and ln R' at lma x 0.95. Uniform grids, the roadtest's tolerances.
.libPaths(c(Sys.getenv("PLANT_LIB"), .libPaths()))
source("/home/user/plant-dev/harness/long_drought.R")
n <- as.integer(commandArgs(TRUE)[[1]]); out <- commandArgs(TRUE)[[2]]
ENV <- mkenv("long-drought"); B <- 4.6759709
stand <- function(lma, b, times) {
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(lma, "lma"), hyperpar = TF24_hyperpar,
                      birth_rate = as.list(rep_len(b, length(lma))))
  p$node_schedule_times <- rep(list(times), length(lma)); p }
ctrl <- control(); ctrl$node_density_in_birth_date <- TRUE
ctrl$ode_tol_rel <- 1e-4; ctrl$ode_tol_abs <- 1e-8; ctrl$ode_step_size_max <- 15 / 365
cpu <- function() sum(proc.time()[c("user.self", "sys.self")])
times <- uniform_times(n)
c0 <- cpu(); scm <- run_scm(stand(LMA0, B, times), ENV, ctrl, record_trajectory = TRUE); t_res <- cpu() - c0
J <- sum(scm$offspring_production)
h <- 1e-3
c0 <- cpu(); scm$run_mutant(stand(LMA0 * exp(c(-h, h, 0)) * c(1, 1, 0.95), 1, times)); t_inv <- cpu() - c0
lr <- log(scm$net_reproduction_ratios)
r <- data.frame(nodes = n, lnJ = log(J), steps = length(scm$ode_times) - 1,
                grad = (lr[2] - lr[1]) / (2 * h), lnR_095 = lr[3], cpu_resident = t_res, cpu_3_invaders = t_inv)
print(r); saveRDS(r, out)
