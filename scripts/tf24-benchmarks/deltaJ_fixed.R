# Lineage decomposition without the (very slow) adaptive refine_schedule.
# One R session: load once, take the default node schedule as the base cohort-
# introduction pattern, densify it by two different factors -> two fixed meshes,
# run each in a single pass (refine=FALSE, fast), and decompose the inter-mesh
# J spread along the lineage (tau) axis.
#
# Weighted integrand per node = fecundity (survival-weighted lifetime offspring,
# carries the extinction structure) x patch_density. node_times = lineage age.

options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                     export_all = TRUE, quiet = TRUE)
})
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"

mkbits <- function(nm, years) {
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years * 365))
  rain <- b$rain[seq_len(nd)]; times <- (0:(nd - 1)) / 365
  list(rain = rain, times = times, tmax = max(times))
}
mkenv <- function(bits) {
  e <- Environment("TF24")
  e$extrinsic_drivers_set_variable("rainfall", bits$times, bits$rain); e
}
mkpars <- function(bits) {
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- bits$tmax
  add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = 1)
}
ctrl <- control(ode_method = "rkck", ode_tol_rel = 1e-6, ode_tol_abs = 1e-6)

# densify a monotone time vector: insert k-1 equally spaced points per interval
densify <- function(t, k) {
  if (k <= 1) return(t)
  out <- numeric(0)
  for (i in seq_len(length(t) - 1))
    out <- c(out, seq(t[i], t[i + 1], length.out = k + 1)[-(k + 1)])
  c(out, t[length(t)])
}

run_fixed <- function(bits, sched_times) {
  scm <- SCM("TF24", "TF24_Env")(mkpars(bits), mkenv(bits), ctrl)
  scm$set_node_schedule_times(list(sched_times))
  scm$run()
  sp <- scm$patch$species[[1]]
  list(J = sum(scm$offspring_production), tau = sp$node_times,
       fec = sp$net_reproduction_ratio_by_node, pdens = sp$patch_densities)
}

analyze <- function(nm, years, kA = 3, kB = 5) {
  bits <- mkbits(nm, years)
  # base pattern from the default schedule (one fast refine=FALSE run)
  scm0 <- SCM("TF24", "TF24_Env")(mkpars(bits), mkenv(bits), ctrl); scm0$run()
  base <- scm0$patch$species[[1]]$node_times
  J0 <- sum(scm0$offspring_production)
  A <- run_fixed(bits, densify(base, kA))
  B <- run_fixed(bits, densify(base, kB))
  gA_n <- A$fec * A$pdens; gB_n <- B$fec * B$pdens
  grid <- seq(0, bits$tmax, length.out = 5000)
  gA <- approx(A$tau, gA_n, grid, rule = 2)$y
  gB <- approx(B$tau, gB_n, grid, rule = 2)$y
  dG <- gA - gB; absdG <- abs(dG); tot <- sum(absdG)
  cum <- cumsum(sort(absdG, decreasing = TRUE)) / tot
  frac_axis <- function(p) which(cum >= p)[1] / length(cum)
  o <- order(absdG, decreasing = TRUE)
  saveRDS(list(nm = nm, base_n = length(base), J0 = J0, A = A, B = B,
               grid = grid, gA = gA, gB = gB, dG = dG),
          file.path(outdir, paste0("deltaJ_fixed_", nm, ".rds")))
  cat(sprintf("%-16s J0(n=%d)=%.4e  JA(n=%d)=%.4e  JB(n=%d)=%.4e  relAB=%.3f\n",
      nm, length(base), J0, length(A$tau), A$J, length(B$tau), B$J,
      abs(A$J - B$J) / A$J))
  data.frame(scenario = nm, base_n = length(base), nA = length(A$tau),
    nB = length(B$tau), J0 = J0, JA = A$J, JB = B$J,
    relAB = abs(A$J - B$J) / A$J,
    axis_50 = frac_axis(0.5), axis_80 = frac_axis(0.8), axis_90 = frac_axis(0.9),
    cancel = abs(sum(dG)) / tot, top1 = grid[o[1]], top2 = grid[o[2]])
}

res <- do.call(rbind, lapply(
  list(c("intense_storms", 15), c("dry_to_wet", 15), c("extended_drought", 20)),
  function(j) { r <- analyze(j[1], as.numeric(j[2])); flush(stdout()); r }))
print(res, digits = 3)
saveRDS(res, file.path(outdir, "deltaJ_fixed_summary.rds"))
cat("\naxis_XX = fraction of tau axis holding XX% of integral|g_A-g_B|.",
    "small=>survival bits, ~0.5=>diffuse. cancel=|int dG|/int|dG|.\n")
cat("ALLDONE\n")
