# E1b -- objective-peak geometry. Map the collar-profit objective g(p) over its
# full feasible range at a fixed soil state, to decide: (a) is the optimum a SMOOTH
# interior max, a CORNER (two smooth branches crossing), or a BOUNDARY max? (b) does
# the analytic derivative dprofit_droot_collar_psi track g's true slope on BOTH
# branches? This decides whether the Oracle's fix F1 (Newton on dP/dp=0 + IFT node)
# is well-posed, or whether a corner/boundary-locating fix is the right object.
#
# E1 established: argmax & non-stationary outputs ~ eps (P1,P2 confirmed); the
# objective ~ eps^1 not eps^2 (P3 refuted) -> the corner signature. Confirm here.

suppressMessages({
  options(pkg.build_extra_flags = FALSE)
  pkgload::load_all("plant", export_all = TRUE, quiet = TRUE)
})

L <- Leaf(vcmax_25 = 100, jmax_25 = 100 * 167, c = 2.04, b = 3, psi_crit = 5,
  root_c = 2.65, root_b = 1.29, root_psi_crit = 1.29 * (log(1 / 0.05))^(1 / 2.65),
  beta2 = 1, a = 0.3, curv_fact_elec_trans = 0.7, curv_fact_colim = 0.99,
  GSS_tol_abs = 1e-8, vulnerability_curve_ncontrol = 100,
  ci_abs_tol = 1e-8, ci_niter = 1000, g1_TF24 = 46.32995,
  beta_R_H = 3.4e3, beta_R_V = 9.4e4)

setp <- function(psi) L$set_physiology(
  area_leaf = 1, mass_root_prop = rep(1/5, 5), rho = 608, a_bio = 0.0245,
  PPFD = 1800, psi_soil = rep(psi, 5),
  soil_depth = seq(0.3, by = 0.3, length.out = 5),
  leaf_specific_conductance_max = 1e-4, atm_vpd = 1, ca = 40,
  sapwood_volume_per_leaf_area = 1e-4, leaf_temp = 25, atm_o2_kpa = 21,
  atm_kpa = 101.3)

map_objective <- function(psi_soil, lo = NA, hi = NA) {
  setp(psi_soil)
  L$find_root_collar_psi()
  pstar <- -L$root_collar_psi_
  root_crit <- L$root_psi_crit         # upper feasible edge scale (approx)
  if (is.na(lo)) lo <- psi_soil                    # wet boundary ~ soil potential
  if (is.na(hi)) hi <- psi_soil + 2.0              # toward drier stem
  b  <- seq(lo, hi, length.out = 6001)
  g  <- vapply(b, function(x) tryCatch(L$evaluate_root_collar_psi(x), error = function(e) NA_real_), numeric(1))
  dg <- vapply(b, function(x) tryCatch(L$dprofit_droot_collar_psi(x), error = function(e) NA_real_), numeric(1))
  fin <- is.finite(g)
  imax <- which.max(ifelse(fin, g, -Inf))
  list(psi_soil = psi_soil, pstar = pstar, b = b, g = g, dg = dg, imax = imax, fin = fin)
}

corner_report <- function(r) {
  b <- r$b; g <- r$g; imax <- r$imax
  n <- length(b)
  # secant slopes over a small offset on each side of the numerical peak
  k <- 30
  iL0 <- max(1, imax - 2*k); iL1 <- max(1, imax - k)
  iR0 <- min(n, imax + k);   iR1 <- min(n, imax + 2*k)
  sL <- if (iL1 > iL0) (g[iL1] - g[iL0]) / (b[iL1] - b[iL0]) else NA
  sR <- if (iR1 > iR0) (g[iR1] - g[iR0]) / (b[iR1] - b[iR0]) else NA
  # how well does dg (analytic) match the true secant slope of g on each side?
  dgL <- median(r$dg[iL0:iL1], na.rm = TRUE)
  dgR <- median(r$dg[iR0:iR1], na.rm = TRUE)
  # peak position relative to feasible span
  bmin <- min(b[r$fin]); bmax <- max(b[r$fin])
  rel <- (b[imax] - bmin) / (bmax - bmin)
  cat(sprintf("psi_soil=%.1f | p*=%.4f  peak@%.4f (%.1f%% into feasible span [%.3f,%.3f])\n",
              r$psi_soil, r$pstar, b[imax], 100*rel, bmin, bmax))
  cat(sprintf("           g secant: left=%+.3g  right=%+.3g   ratio|L/R|=%.1f  => %s\n",
              sL, sR, abs(sL/sR),
              if (is.finite(sL) && is.finite(sR) && abs(sL/sR) > 5) "CORNER (asymmetric)" else "roughly symmetric"))
  cat(sprintf("           analytic dP/dp: left=%+.3g right=%+.3g  (true left=%+.3g right=%+.3g) => analytic tracks true: L=%s R=%s\n\n",
              dgL, dgR, sL, sR,
              isTRUE(sign(dgL)==sign(sL) && abs(dgL) > 0.3*abs(sL)),
              isTRUE(sign(dgR)==sign(sR) && abs(dgR) > 0.3*abs(sR))))
}

cat("=== E1b: collar-profit objective peak geometry ===\n\n")
rr <- list()
for (psi in c(0.5, 1.0, 2.0, 3.0)) { r <- map_objective(psi); corner_report(r); rr[[as.character(psi)]] <- r }

saveRDS(rr, "scripts/tf24-benchmarks/results/noise_floor_E1b_peak.rds")
cat("saved results/noise_floor_E1b_peak.rds\n")
