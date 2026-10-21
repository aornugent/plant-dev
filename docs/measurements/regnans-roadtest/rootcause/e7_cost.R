# E7: TF24's costs on regnans's footing, long drought at b*, 201 uniform nodes,
# at the absolute tolerance ABS: a plain forward, a recorded forward, the
# resident's sweep (every trait), an invader run at the resident's traits and its
# sweep (every trait), and two invaders for a central difference. Gradients
# chained along the trade-off, sweep against difference.
.libPaths(c(Sys.getenv("PLANT_LIB"), .libPaths()))
source("/home/user/plant-dev/harness/long_drought.R")
out <- commandArgs(TRUE)[[1]]; ABS <- as.numeric(Sys.getenv("ABS", "1e-8"))
ENV <- mkenv("long-drought"); B <- 4.6759709
stand <- function(lma, b, times) {
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(lma, "lma"), hyperpar = TF24_hyperpar,
                      birth_rate = as.list(rep_len(b, length(lma))))
  p$node_schedule_times <- rep(list(times), length(lma)); p }
ctrl <- control(); ctrl$node_density_in_birth_date <- TRUE
ctrl$ode_tol_rel <- 1e-4; ctrl$ode_tol_abs <- ABS; ctrl$ode_step_size_max <- 15 / 365
cpu <- function() sum(proc.time()[c("user.self", "sys.self")])
tm <- function(expr) { c0 <- cpu(); force(expr); cpu() - c0 }
times <- uniform_times(201)
t_plain <- tm(run_scm(stand(LMA0, B, times), ENV, ctrl, record_trajectory = FALSE))
scm <- NULL; t_rec <- tm(scm <- run_scm(stand(LMA0, B, times), ENV, ctrl, record_trajectory = TRUE))
gr <- NULL; t_rsweep <- tm(gr <- stand_gradient(scm, metrics = "1.offspring_production"))
pars_at <- function(l) unlist(stand(l, 1, times)$strategies[[1]]$pars)
dpar <- (pars_at(LMA0 * exp(1e-6)) - pars_at(LMA0 * exp(-1e-6))) / 2e-6
chain <- function(G, R) { cn <- sub("^1\\.", "", colnames(G)); k <- cn %in% names(dpar)
  sum(G[1, k] * dpar[cn[k]]) / R }
J <- gr$value[[1]]; Ftheta <- chain(gr$gradient, J)
t_inv <- tm({scm$record_trajectory <- TRUE; scm$run_mutant(stand(LMA0, 1, times))})
R <- scm$net_reproduction_ratios
gi <- NULL; t_isweep <- tm(gi <- stand_gradient(scm, metrics = "1.net_reproduction_ratio"))
g_sweep <- chain(gi$gradient, R)
h <- 1e-3; lr <- NULL; t_cd <- tm({scm$run_mutant(stand(LMA0 * exp(c(-h, h)), 1, times)); lr <- log(scm$net_reproduction_ratios)})
r <- list(abs = ABS, J = J, F = log(J) - log(B), F_theta = Ftheta, g_sweep = g_sweep, g_cd = (lr[2] - lr[1]) / (2 * h),
          n_traits = ncol(gi$gradient),
          cpu = c(plain = t_plain, recorded = t_rec, resident_sweep = t_rsweep, invader = t_inv,
                  invader_sweep = t_isweep, cd_2_invaders = t_cd))
r$ratio_to_plain <- r$cpu / t_plain
print(r); saveRDS(r, out)
