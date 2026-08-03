# TF24's environment carries a dynamic soil-water state as well as light.  Compare
# what the SCM's environment, the stochastic patch's environment, and a fixed
# environment actually present to an individual, in the open-canopy limit.
source("probes/lib.R"); setwd("/home/user/plant-dev")
TEND <- 3.0
p0 <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
tt <- p0$node_schedule_times[[1]]; tt <- tt[tt <= TEND]
s1 <- p0$strategies[[1]]
nms <- TF24_Individual(s1)$ode_names

dump_env <- function(e, tag) {
  sw <- tryCatch(e$get_soil_water_state(), error = function(x) NA_real_)
  cf <- tryCatch(e$get_soil_water_state_cumulative_flux(), error = function(x) NA_real_)
  cat(sprintf("%-26s time=%8.4f  soil_water=%s  cumflux=%s  ode_size=%s  light(0,1,5)=%s\n",
      tag, e$time, paste(sprintf("%.6g", sw), collapse=","),
      paste(sprintf("%.4g", cf), collapse=","), paste(e$ode_size, collapse=","),
      paste(sprintf("%.6f", vapply(c(0,1,5), function(z)
        tryCatch(e$get_environment_at_height(z), error=function(x) NA_real_), 0)), collapse=",")))
}

cat("=== fresh / fixed environments ===\n")
e0 <- Environment("TF24");                      dump_env(e0, "fresh Environment")
e1 <- Environment("TF24"); e1$set_fixed_environment(1.0, 150); dump_env(e1, "set_fixed_environment")
cat("driver names:", paste(e0$extrinsic_drivers_get_names(), collapse=" "), "\n\n")

cat("=== SCM, open canopy (birth_rate_y = 1e-6) ===\n")
p <- p0; p$max_patch_lifetime <- TEND; p$node_schedule_times <- list(tt)
p$strategies[[1]]$birth_rate_y <- 1e-6
ct <- Control(); ct$node_density_in_birth_date <- TRUE
scm <- scm_collect(p, "TF24", ct)
tm <- vapply(seq_along(scm$history), function(k) scm$history[[k]]$time, 0)
envs_scm <- list()
for (tgt in c(0.05, 0.5, 1, 2, 3)) {
  k <- which.min(abs(tm - tgt)); e <- scm$history[[k]]$environment
  dump_env(e, sprintf("SCM patch t=%.2f", tm[k])); envs_scm[[as.character(tgt)]] <- e
}

cat("\n=== IBM, open canopy (one individual per 1e5 m2) ===\n")
pI <- p0; pI$patch_area <- 1e5; pI$max_patch_lifetime <- TEND
ty  <- plant:::extract_RcppR6_template_types(pI, "Parameters")
obj <- do.call(plant:::StochasticPatchRunner, ty)(pI, Environment("TF24"), Control())
scq <- plant:::NodeSchedule(1); scq$max_time <- TEND
scq$set_times(seq(0, TEND, by = 0.02), 1); obj$node_schedule <- scq
snapt <- c(0.05, 0.5, 1, 2, 3); envs_ibm <- list(); got <- c()
while (!obj$complete) {
  obj$run_next()
  for (tgt in snapt) if (!(tgt %in% got) && obj$patch$time >= tgt) {
    envs_ibm[[as.character(tgt)]] <- obj$patch$environment; got <- c(got, tgt)
    dump_env(obj$patch$environment, sprintf("IBM patch t=%.2f", obj$patch$time))
  }
}

cat("\n=== dh/dt for the SAME state under each environment ===\n")
k <- which.min(abs(tm - 1)); ind <- scm$history[[k]]$species[[1]]$nodes[[1]]$individual
st <- vapply(nms, function(n) ind$state(n), 0)
cat(sprintf("state: %s\n", paste(sprintf("%s=%.5e", nms, st), collapse="  ")))
mk <- function() { i <- TF24_Individual(s1); for (n in nms) i$set_state(n, st[[n]]); i }
ref <- ind$rate("height")
for (nm2 in c("fresh","fixed","scm@1","ibm@1")) {
  e <- switch(nm2, fresh = e0, fixed = e1, `scm@1` = envs_scm[["1"]], `ibm@1` = envs_ibm[["1"]])
  i <- mk(); ok <- tryCatch({ i$compute_rates(e); TRUE }, error = function(x) FALSE)
  cat(sprintf("  %-8s dh/dt = %-14.6e  ratio to SCM node's own rate = %s\n", nm2,
      if (ok) i$rate("height") else NA_real_,
      if (ok) sprintf("%.4f", i$rate("height")/ref) else "err"))
}
cat(sprintf("  SCM node's own reported dh/dt = %.6e\n", ref))
