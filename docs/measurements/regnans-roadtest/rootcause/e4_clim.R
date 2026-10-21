# E1: what sets a forward's cost on long drought at b*: the absolute tolerance,
# the 15-day step cap, the node count. One variable at a time.
.libPaths(c(Sys.getenv("PLANT_LIB"), .libPaths()))
source("/home/user/plant-dev/harness/long_drought.R")
arm <- commandArgs(TRUE)[[1]]; out <- commandArgs(TRUE)[[2]]
ENV <- mkenv(Sys.getenv("CLIM"))
B <- as.numeric(Sys.getenv("B"))
stand <- function(times) {
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(LMA0, "lma"), hyperpar = TF24_hyperpar, birth_rate = list(B))
  p$node_schedule_times <- list(times); p }
ctrl <- control(); ctrl$node_density_in_birth_date <- TRUE
ctrl$ode_tol_rel <- 1e-4; ctrl$ode_tol_abs <- 1e-8; ctrl$ode_step_size_max <- 15 / 365
n <- 201
if (arm == "abs1e-4") ctrl$ode_tol_abs <- 1e-4
if (arm == "nocap") ctrl$ode_step_size_max <- 1e9
if (arm == "n108") n <- 108
if (arm == "n54") n <- 54
cpu <- function() sum(proc.time()[c("user.self", "sys.self")])
c0 <- cpu()
scm <- run_scm(stand(uniform_times(n)), ENV, ctrl, record_trajectory = FALSE)
t <- cpu() - c0
st <- diff(scm$ode_times) * 365
r <- data.frame(arm = arm, nodes = n, cpu = t, J = sum(scm$offspring_production),
                accepted = length(st), step_median_d = median(st), step_p90_d = quantile(st, .9),
                at_cap = mean(st > 14.9))
print(r); saveRDS(r, out)
