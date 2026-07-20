# Ecological characterisation of the TF24 soil profile (task #24).
#
# The classifier gate found leaf shutdown nearly unreachable: it keys on the
# WETTEST accessible layer, and even 12 yr of zero rain does not dry the profile
# to psi_crit (~5.6 MPa). Is that ecologically defensible, or a mechanistic
# artifact of the drainage / root-access representation? This quantifies the
# drydown physics from a collected SCM run (no new instrumentation):
#   * per-layer psi/theta trajectories -- does the DEEPEST layer ever dry?
#   * water budget -- cumulative rainfall vs infiltration vs deep drainage vs
#     uptake: where does the water go / why does a deep reservoir persist?
#   * stand vs soil timing -- does the stand die (uptake -> 0) before the soil
#     dries, so the reservoir is never drawn down?

options(pkg.build_extra_flags = FALSE)
suppressMessages({ library(odelia); pkgload::load_all("plant", export_all = TRUE, quiet = TRUE) })

b <- readRDS("scripts/tf24-benchmarks/data/drydown.rds")
rain <- b$rain; nd <- length(rain); times <- (0:(nd - 1)) / 365
e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall", times, rain)
p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- max(times)
p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = 1)
ctrl <- control(ode_method = "rkck", ode_tol_rel = 1e-6, ode_tol_abs = 1e-6)

res <- run_scm(p, e, ctrl, collect = TRUE)

# psi from theta (MPa), matching TF24_plot_diagnostics / psi_from_soil_moist.
psi_mpa <- function(theta) (1.78e3 * (theta / 0.428)^-6.57) / 1e6

sm <- res$env$soil_moist            # LONG: (time, step, patch_density, soil_moist),
                                    # 5 rows per time in depth order 0.3..1.5
cat("soil_moist columns:", paste(names(sm), collapse = ", "), "\n")
depth_levels <- sort(unique(res$env$soil_depth$soil_depth))
nl <- length(depth_levels)
cat("layer depths (m):", paste(depth_levels, collapse = ", "), "\n\n")

# reshape: layer index is minor within each time block (depths repeat 0.3..1.5).
sm$layer <- depth_levels[rep(seq_len(nl), length.out = nrow(sm))]
utime <- unique(sm$time)
layers <- lapply(depth_levels, function(d) {
  s <- sm[sm$layer == d, ]; data.frame(time = s$time, soil_moist = s$soil_moist)
})
names(layers) <- paste0(depth_levels, "m")

cat("=== per-layer soil drydown (psi in MPa; shutdown needs wettest layer >= 5.6) ===\n")
for (nm in names(layers)) {
  L <- layers[[nm]]; th <- L$soil_moist
  cat(sprintf("  layer %-8s theta: min=%.4f end=%.4f | psi(MPa): max=%.3g end=%.3g\n",
              nm, min(th, na.rm = TRUE), tail(th[!is.na(th)], 1),
              max(psi_mpa(th), na.rm = TRUE), tail(psi_mpa(th[!is.na(th)]), 1)))
}
# wettest layer over time = min psi across layers; shutdown reachable iff its max >= 5.6
psi_by_layer <- sapply(layers, function(L) psi_mpa(L$soil_moist))
wettest_psi <- apply(psi_by_layer, 1, min, na.rm = TRUE)
cat(sprintf("\nwettest-layer psi over the whole run: max reached = %.3g MPa (psi_crit ~ 5.6)\n",
            max(wettest_psi[is.finite(wettest_psi)])))
cat("  => shutdown", if (max(wettest_psi[is.finite(wettest_psi)]) >= 5.6) "REACHED" else "NEVER reached", "\n\n")

# water budget from cumulative fluxes (rainfall, infiltration, deep drainage, uptake)
cf <- res$env$soil_moist_cumulative_flux
cat("cumulative-flux columns:", paste(names(cf), collapse = ", "), "\n")
last <- cf[nrow(cf), ]
cat("final cumulative fluxes:\n"); print(last)

# stand vs soil timing: total patch leaf area over time
la <- tryCatch(
  integrate_over_size_distribution(purrr::pluck(expand_state(res), "species")),
  error = function(e) NULL)
if (!is.null(la)) {
  cat(sprintf("\nstand leaf area: peak=%.3g at t=%.1f yr | end=%.3g at t=%.1f yr\n",
              max(la$area_leaf, na.rm = TRUE), la$time[which.max(la$area_leaf)],
              tail(la$area_leaf, 1), tail(la$time, 1)))
}
saveRDS(list(layers = layers, wettest_psi = wettest_psi, times = sm$time,
             cum_flux = cf, leaf_area = la),
        "scripts/tf24-benchmarks/results/eco_soil_drydown.rds")
cat("\nsaved eco_soil_drydown.rds\n")
