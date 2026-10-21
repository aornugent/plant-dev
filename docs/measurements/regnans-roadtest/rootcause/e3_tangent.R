# E3: the invader's selection gradient at the resident's traits, three ways, on
# one resident run: a reverse sweep, a forward tangent along the trade-off, and a
# central difference of two invaders. Long drought at b*, 201 uniform nodes.
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

# The trade-off's direction in parameter space: d(par)/d ln lma, by a central
# difference of the hyperparameter function (closed form, no runs).
s <- scm$parameters$strategies[[1]]
pars_at <- function(l) unlist(stand(l, 1, times)$strategies[[1]]$pars)
dpar <- (pars_at(LMA0 * exp(1e-6)) - pars_at(LMA0 * exp(-1e-6))) / 2e-6
cols <- plant:::census_backend(scm)$trait_names(scm)
dir <- unname(dpar[sub("^1\\.", "", cols)]); dir[is.na(dir)] <- 0

c0 <- cpu(); scm$record_trajectory <- TRUE; scm$run_mutant(stand(LMA0, 1, times)); t_inv <- cpu() - c0
R <- scm$net_reproduction_ratios
c0 <- cpu()
g <- stand_gradient(scm, metrics = "1.net_reproduction_ratio", traits = paste0("1.", names(dpar)[dpar != 0 & paste0("1.", names(dpar)) %in% cols]))
t_sweep <- cpu() - c0
gs <- sum(g$gradient[1, ] * dpar[sub("^1\\.", "", colnames(g$gradient))]) / R
c0 <- cpu(); tg <- plant:::ladder_trajectory_tangent_tf24(scm, dir); t_tan <- cpu() - c0
c0 <- cpu(); h <- 1e-3; scm2 <- scm; scm$run_mutant(stand(LMA0 * exp(c(-h, h)), 1, times))
lr <- log(scm$net_reproduction_ratios); t_cd <- cpu() - c0
r <- list(nodes = n, R = R, sweep = gs, tangent = tg, cd = (lr[2] - lr[1]) / (2 * h),
          cpu = c(resident = t_res, invader = t_inv, sweep = t_sweep, tangent = t_tan, cd_2_invaders = t_cd))
print(r); saveRDS(r, out)
