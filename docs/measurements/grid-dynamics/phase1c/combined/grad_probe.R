# The stand alone and its gradient, under run_record.R's settings and its
# WEIGHT_SOIL, WEIGHT, WEIGHT_MAX and HMAX, to find which part of the combined
# setting makes plant refuse the gradient. Saves the stand's steps, J, the
# refusal, how many gradient columns are finite, and the soil's clamp tallies on
# the forward run and on the sweep.
#
#   PLANT_LIB=... REGIME=episodic TOL=3e-5 ATOL=1e-4 TIMES=t.rds [WEIGHT_SOIL=10] \
#     [WEIGHT=weight.rds] [WEIGHT_MAX=100] [HMAX=15] OUT=x.rds Rscript grad_probe.R
#   (from the snapshot)
local({
  here <- "harness"
  source(file.path(here, "long_drought.R"))
})
regime <- Sys.getenv("REGIME", SCEN)
scen <- sprintf("%s, seed %d", regime, RAIN_SPECS[[regime]]$seed)
RAIN_SPECS[[scen]] <- RAIN_SPECS[[regime]]
tol <- as.numeric(Sys.getenv("TOL", "3e-5"))
times <- readRDS(Sys.getenv("TIMES"))
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- as.numeric(Sys.getenv("ATOL", "1e-4")) * tol
ct$node_density_in_birth_date <- TRUE
if (nzchar(Sys.getenv("WEIGHT_SOIL"))) ct$ode_weight_soil <- as.numeric(Sys.getenv("WEIGHT_SOIL"))
if (nzchar(Sys.getenv("WEIGHT"))) {
  w <- readRDS(Sys.getenv("WEIGHT"))
  ct$ode_weight_times <- w$t
  ct$ode_weight_factors <- w$weight
}
if (nzchar(Sys.getenv("WEIGHT_MAX"))) ct$ode_weight_max <- as.numeric(Sys.getenv("WEIGHT_MAX"))
if (nzchar(Sys.getenv("HMAX"))) ct$ode_step_size_max <- as.numeric(Sys.getenv("HMAX")) / 365
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))
t0 <- proc.time()[["elapsed"]]
scm <- run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE)
t1 <- proc.time()[["elapsed"]]
# The environment's tallies land on the first species' row, at plant's
# clamp_site order: moisture floor, potential ceiling, positivity.
soil_sites <- c(soil_moisture_floor = 3, soil_potential_ceiling = 4, soil_positivity = 5)
forward_clamps <- plant:::census_clamp_counts_tf24(scm)[[1]][soil_sites]
g <- stand_gradient(scm, metrics = "offspring_production")
t2 <- proc.time()[["elapsed"]]
swept_clamps <- plant:::census_clamp_counts_differentiated_tf24(scm)[[1]][soil_sites]
names(forward_clamps) <- names(swept_clamps) <- names(soil_sites)
out <- list(J = sum(scm$offspring_production), times = scm$ode_times, attempts = scm$ode_step_attempts,
            gradient = g$gradient["offspring_production", ], refusal = g$refusal[["offspring_production"]],
            forward_clamps = forward_clamps, swept_clamps = swept_clamps,
            setting = Sys.getenv(c("REGIME", "TOL", "WEIGHT_SOIL", "WEIGHT", "WEIGHT_MAX", "HMAX")))
saveRDS(out, Sys.getenv("OUT"))
h <- diff(out$times) * 365
cat(sprintf("soil clamps, forward: %s; sweep: %s\n",
            paste(names(forward_clamps), forward_clamps, collapse = " "),
            paste(names(swept_clamps), swept_clamps, collapse = " ")))
cat(sprintf("%s soil %s weight %s max %s hmax %s: J %.9f, %d steps (longest %.1f d, first over 15 d at t = %s); gradient finite %d of %d; refusal: %s; %.0f + %.0f s\n",
            regime, Sys.getenv("WEIGHT_SOIL", "1"), if (nzchar(Sys.getenv("WEIGHT"))) "rule A" else "none",
            Sys.getenv("WEIGHT_MAX", "-"), Sys.getenv("HMAX", "-"), out$J, length(out$times), max(h),
            if (any(h > 15 + 1e-9)) sprintf("%.3f", out$times[which(h > 15 + 1e-9)[1]]) else "-",
            sum(is.finite(out$gradient)), length(out$gradient),
            if (is.null(out$refusal) || !any(nzchar(out$refusal))) "none" else paste(out$refusal, collapse = " | "),
            t1 - t0, t2 - t1))
