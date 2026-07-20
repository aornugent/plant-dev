# Item B / fresh-Oracle lineage-decomposition: is the inter-scheme J spread a
# handful of survival flips, or diffuse conditioning across the member axis?
#
# J_species = trapezium(node_times, weighted_fecundity x birth_rate), where
# weighted_fecundity_i = fecundity_i (= offspring_produced_survival_weighted,
# carries the cohort-extinction structure) x patch_density_i x S_D. node_times
# IS the lineage coordinate (cohort introduction age). Both exposed to R:
# net_reproduction_ratio_by_node (= fecundity_i) and patch_densities.
#
# Two schemes = two ADAPTIVELY REFINED node schedules at different schedule_eps
# (refine_schedule=TRUE; the default fixed schedule is not mesh-converged).
# Both ODE-converged. Interpolate each weighted integrand g(tau) onto a common
# fine lineage grid, form dG = g_A - g_B, measure how concentrated integral|dG|
# is along tau. Concentrated (a few tau hold most) => survival bits; spread =>
# diffuse conditioning.

options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                     export_all = TRUE, quiet = TRUE)
})
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
TOL <- 1e-6

run_scheme <- function(nm, years, sched_eps) {
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years * 365))
  rain <- b$rain[seq_len(nd)]; times <- (0:(nd - 1)) / 365
  e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall", times, rain)
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- max(times)
  p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = 1)
  ctrl <- control(ode_method = "rkck", ode_tol_rel = TOL, ode_tol_abs = TOL,
                  schedule_eps = sched_eps, schedule_nsteps = 30)
  scm <- run_scm(p, e, ctrl, refine_schedule = TRUE)
  sp <- scm$patch$species[[1]]
  tau <- sp$node_times
  g   <- sp$net_reproduction_ratio_by_node * sp$patch_densities  # weighted (up to S_D const)
  list(J = sum(scm$offspring_production), tau = tau, g = g,
       fec = sp$net_reproduction_ratio_by_node)
}

analyze <- function(nm, years, epsA = 2e-2, epsB = 2e-3) {
  A <- run_scheme(nm, years, epsA); B <- run_scheme(nm, years, epsB)
  tmax <- max(c(A$tau, B$tau))
  grid <- seq(0, tmax, length.out = 5000); dt <- grid[2] - grid[1]
  gA <- approx(A$tau, A$g, grid, rule = 2)$y
  gB <- approx(B$tau, B$g, grid, rule = 2)$y
  dG <- gA - gB; absdG <- abs(dG); tot <- sum(absdG)
  cum <- cumsum(sort(absdG, decreasing = TRUE)) / tot
  frac_axis <- function(p) which(cum >= p)[1] / length(cum)
  # top-3 lineage locations of the discrepancy
  o <- order(absdG, decreasing = TRUE)
  top_tau <- grid[o[1:3]]
  saveRDS(list(A = A, B = B, grid = grid, dG = dG),
          file.path(outdir, paste0("deltaJ_", nm, ".rds")))
  data.frame(scenario = nm, nA = length(A$tau), nB = length(B$tau),
    JA = A$J, JB = B$J, relspread = abs(A$J - B$J) / A$J,
    axis_50 = frac_axis(0.5), axis_80 = frac_axis(0.8), axis_90 = frac_axis(0.9),
    cancel = abs(sum(dG)) / tot,
    top1_tau = top_tau[1], top2_tau = top_tau[2], tmax = tmax)
}

scen <- list(intense_storms = 20, dry_to_wet = 25, extended_drought = 40)
res <- do.call(rbind, lapply(names(scen), function(n) analyze(n, scen[[n]])))
print(res, digits = 3)
saveRDS(res, file.path(outdir, "deltaJ_decomp_summary.rds"))
cat("\naxis_XX = fraction of the lineage (tau) axis holding XX% of integral|g_A-g_B|.",
    "\n  small (<~0.1) => spread is a few survival bits (concentrated);",
    "\n  large (~0.5) => diffuse across the member axis.",
    "\ncancel = |int dG|/int|dG|: ~1 one-signed, ~0 oscillatory.",
    "\ntop{1,2}_tau = lineage ages holding the largest |dG|.\n")
