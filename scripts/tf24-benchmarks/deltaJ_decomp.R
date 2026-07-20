# Item B / fresh-Oracle lineage-decomposition: is the inter-scheme J spread a
# handful of survival flips, or diffuse conditioning across the member axis?
#
# J_species = trapezium(node_times, survival-weighted fecundity x birth_rate).
# node_times() IS the lineage coordinate (cohort introduction age). The exposed
# net_reproduction_ratio_by_node = fecundity() = offspring_produced_survival_
# weighted per node -- it already carries the cohort-survival structure (a
# cohort that goes extinct contributes ~0). The only omitted factor is the
# smooth patch_density(tau) envelope, which cannot create a flip -- so this
# unweighted integrand is sufficient to answer concentrated-vs-diffuse.
#
# Two schemes = two node-insertion schedules (schedule_eps), both at converged
# ODE tol. Interpolate each integrand g(tau) onto a common fine lineage grid,
# form dG = g_A - g_B, and measure how concentrated integral|dG| is along tau.
# Concentrated (a few tau hold most of it) => survival bits. Spread => diffuse.

options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia); pkgload::load_all("plant", export_all = TRUE, quiet = TRUE)
})
datadir <- "scripts/tf24-benchmarks/data"
TOL <- 1e-6

run_scheme <- function(nm, years, sched_eps) {
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years * 365))
  rain <- b$rain[seq_len(nd)]; times <- (0:(nd - 1)) / 365
  e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall", times, rain)
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- max(times)
  p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = 1)
  ctrl <- control(ode_method = "rkck", ode_tol_rel = TOL, ode_tol_abs = TOL,
                  schedule_eps = sched_eps)
  scm <- run_scm(p, e, ctrl)
  sp <- scm$patch$species[[1]]
  list(J = sum(scm$offspring_production),
       tau = sp$node_times,
       g = sp$net_reproduction_ratio_by_node)
}

analyze <- function(nm, years, epsA = 2e-2, epsB = 5e-3) {
  A <- run_scheme(nm, years, epsA); B <- run_scheme(nm, years, epsB)
  tmax <- max(c(A$tau, B$tau))
  grid <- seq(0, tmax, length.out = 4000)
  gA <- approx(A$tau, A$g, grid, rule = 2)$y
  gB <- approx(B$tau, B$g, grid, rule = 2)$y
  dG <- gA - gB
  dJ <- sum(A$g * c(diff(A$tau), 0)) - sum(B$g * c(diff(B$tau), 0)) # rough
  dJ_true <- A$J - B$J
  absdG <- abs(dG)
  tot <- sum(absdG)
  o <- order(absdG, decreasing = TRUE)
  cum <- cumsum(absdG[o]) / tot
  # fraction of the tau-axis needed to accumulate 50/80/90% of integral|dG|
  frac_axis <- function(p) which(cum >= p)[1] / length(cum)
  # signed cancellation: |integral dG| / integral|dG|  (low => oscillatory/diffuse,
  # high => one-signed concentrated mass)
  cancel <- abs(sum(dG)) / tot
  data.frame(
    scenario = nm, nA = length(A$tau), nB = length(B$tau),
    JA = A$J, JB = B$J, relspread = abs(dJ_true) / A$J,
    axis_50 = frac_axis(0.5), axis_80 = frac_axis(0.8), axis_90 = frac_axis(0.9),
    cancel = cancel)
}

scen <- list(intense_storms = 20, dry_to_wet = 25, extended_drought = 40)
res <- do.call(rbind, lapply(names(scen), function(n) analyze(n, scen[[n]])))
print(res, digits = 3)
saveRDS(res, "scripts/tf24-benchmarks/results/deltaJ_decomp_summary.rds")
cat("\naxis_XX = fraction of the lineage (tau) axis holding XX% of integral|g_A-g_B|.",
    "\n  Small (<~0.1) => ODEJ spread is a few survival bits (concentrated);",
    "\n  large (~0.5) => diffuse conditioning across the member axis.",
    "\ncancel = |int dG| / int|dG|: ~1 one-signed concentrated, ~0 oscillatory.\n")
