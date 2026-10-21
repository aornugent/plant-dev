# E8: is constant rain's jump in ln R' at the resident one introduction flipping
# at the stall edge? Resident at b* on the roadtest's rebuilt schedule; invaders
# at lma x (1 - 1e-4, 1, 1 + 1e-4); each invader's offspring by node.
.libPaths(c(Sys.getenv("PLANT_LIB"), .libPaths()))
source("/home/user/plant-dev/harness/long_drought.R")
x <- readRDS("../rt/out3/roadtest-constant.rds")
times <- x$refine_again$nodes; B <- x$equilibrium$b
ENV <- mkenv("constant")
stand <- function(lma, b, times) {
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(lma, "lma"), hyperpar = TF24_hyperpar,
                      birth_rate = as.list(rep_len(b, length(lma))))
  p$node_schedule_times <- rep(list(times), length(lma)); p }
ctrl <- control(); ctrl$node_density_in_birth_date <- TRUE
ctrl$ode_tol_rel <- 1e-4; ctrl$ode_tol_abs <- 1e-8; ctrl$ode_step_size_max <- 15 / 365
scm <- run_scm(stand(LMA0, B, times), ENV, ctrl, record_trajectory = TRUE)
res <- scm$patch$species[[1]]$net_reproduction_ratio_by_node
f <- c(1 - 1e-4, 1, 1 + 1e-4)
scm$run_mutant(stand(LMA0 * f, 1, times))
by <- sapply(seq_along(f), function(i) scm$patch$species[[i]]$net_reproduction_ratio_by_node)
R <- scm$net_reproduction_ratios
cat("nodes", length(times), " b*", B, " ln R'", format(log(R), digits = 6), "\n")
d <- by[, 3] - by[, 1]
o <- order(-abs(d))[1:8]
print(data.frame(node = o, birth = times[o], resident = res[o], minus = by[o, 1], same = by[o, 2], plus = by[o, 3]), digits = 4)
cat("share of the change in the top node:", abs(d[o[1]]) / sum(abs(d)), "\n")
saveRDS(list(times = times, res = res, by = by, R = R), "e8_cliff.rds")
