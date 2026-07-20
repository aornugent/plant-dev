# Analysis pass for the lineage decomposition. Reads the saved refined schemes
# (deltaJ_schemes/<scenario>_eps<...>.rds) and decomposes the inter-mesh J
# spread along the lineage (tau) axis. No SCM runs -- pure post-processing, so
# it is cheap and re-runnable.

sd <- "/home/user/plant-dev/scripts/tf24-benchmarks/results/deltaJ_schemes"
outdir <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"

analyze <- function(nm, epsA = 2e-2, epsB = 2e-3) {
  fa <- file.path(sd, sprintf("%s_eps%.0e.rds", nm, epsA))
  fb <- file.path(sd, sprintf("%s_eps%.0e.rds", nm, epsB))
  if (!file.exists(fa) || !file.exists(fb)) return(NULL)
  A <- readRDS(fa); B <- readRDS(fb)
  gA_nodes <- A$fec * A$pdens; gB_nodes <- B$fec * B$pdens  # weighted integrand
  tmax <- max(c(A$tau, B$tau))
  grid <- seq(0, tmax, length.out = 5000)
  gA <- approx(A$tau, gA_nodes, grid, rule = 2)$y
  gB <- approx(B$tau, gB_nodes, grid, rule = 2)$y
  dG <- gA - gB; absdG <- abs(dG); tot <- sum(absdG)
  cum <- cumsum(sort(absdG, decreasing = TRUE)) / tot
  frac_axis <- function(p) which(cum >= p)[1] / length(cum)
  o <- order(absdG, decreasing = TRUE)
  saveRDS(list(A = A, B = B, grid = grid, gA = gA, gB = gB, dG = dG),
          file.path(outdir, paste0("deltaJ_", nm, ".rds")))
  data.frame(scenario = nm, nA = length(A$tau), nB = length(B$tau),
    JA = A$J, JB = B$J, relspread = abs(A$J - B$J) / A$J,
    axis_50 = frac_axis(0.5), axis_80 = frac_axis(0.8), axis_90 = frac_axis(0.9),
    cancel = abs(sum(dG)) / tot,
    top1_tau = grid[o[1]], top2_tau = grid[o[2]], top3_tau = grid[o[3]],
    tmax = tmax)
}

res <- do.call(rbind, Filter(Negate(is.null),
  lapply(c("intense_storms", "dry_to_wet", "extended_drought"), analyze)))
print(res, digits = 3)
saveRDS(res, file.path(outdir, "deltaJ_decomp_summary.rds"))
cat("\naxis_XX = fraction of the tau axis holding XX% of integral|g_A-g_B|.",
    "\n  small => concentrated (survival bits); ~0.5 => diffuse.",
    "\ncancel = |int dG|/int|dG|.  top{1,2,3}_tau = lineage ages of largest |dG|.\n")
