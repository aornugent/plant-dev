# The SCM's actual soil-water trajectory at the realistic birth rate, for
# comparison with the stochastic patch's frozen initial value.
source("probes/lib.R"); setwd("/home/user/plant-dev")
TEND <- 3.5
p0 <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
tt <- p0$node_schedule_times[[1]]; tt <- tt[tt <= TEND]
for (br in c(1, 1e-6)) {
  p <- p0; p$max_patch_lifetime <- TEND; p$node_schedule_times <- list(tt)
  p$strategies[[1]]$birth_rate_y <- br
  ct <- Control(); ct$node_density_in_birth_date <- TRUE
  scm <- scm_collect(p, "TF24", ct)
  tm <- vapply(seq_along(scm$history), function(k) scm$history[[k]]$time, 0)
  cat(sprintf("\n=== SCM soil water, birth_rate_y = %g ===\n", br))
  cat(sprintf("%8s %s %12s\n", "time", paste(sprintf("%10s", paste0("layer",1:5)), collapse=" "), "LAI"))
  for (tgt in c(0.05, 0.2, 0.5, 1, 1.5, 2, 2.5, 3)) {
    k <- which.min(abs(tm - tgt)); e <- scm$history[[k]]$environment
    cat(sprintf("%8.3f %s %12.6f\n", tm[k],
        paste(sprintf("%10.6f", e$get_soil_water_state()), collapse=" "),
        scm$history[[k]]$species[[1]]$compute_competition(0)))
  }
}
cat("\nstochastic patch soil water: 0.214 at every time (never integrated)\n")
