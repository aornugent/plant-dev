# Which of the three cases does the collar operating point actually occupy?
#
# The three are distinguishable from fields develop already exposes, with no
# access to bound_a / bound_b:
#
#   pinned wet (bound_a, zero uptake)   transpiration_ == 0 exactly
#   pinned dry (bound_b)                opt_psi_stem_ == psi_crit
#   interior                            neither; then dprofit/dp says whether it
#                                       is stationary
#
# corner-and-envelope-result.md classified one configuration (single layer,
# area_leaf 0.05, psi_soil 0.5-2.0 MPa) and found the wet bound at every state.
# This sweeps the two axes that separate that configuration from a production
# stand -- soil potential and leaf area -- and adds the five-layer case.
#
#   Rscript scripts/operating_point_classify.R

suppressMessages({ library(odelia); pkgload::load_all("plant", quiet = TRUE) })

mk <- function(gss = 1e-10) Leaf(
  vcmax_25 = 100, jmax_25 = 100 * 167, c = 2.04, b = 3, psi_crit = 5,
  root_c = 2.65, root_b = 1.29, root_psi_crit = 1.29 * (log(1 / 0.05))^(1 / 2.65),
  beta2 = 1, a = 0.3, curv_fact_elec_trans = 0.7, curv_fact_colim = 0.99,
  GSS_tol_abs = gss, vulnerability_curve_ncontrol = 100, ci_abs_tol = 1e-8,
  ci_niter = 1000, g1_TF24 = 46.32995, beta_R_H = 3.4e3, beta_R_V = 9.4e4)

PSI_CRIT <- 5
ROOT_PSI_CRIT <- 1.29 * (log(1 / 0.05))^(1 / 2.65)

classify <- function(psi, area_leaf, nlayer = 1, depth = 1, PPFD = 900) {
  l <- mk()
  th <- 0.000157; h <- 5
  psi_v <- rep(psi, nlayer)
  dep_v <- depth * seq_len(nlayer) / nlayer
  mrp   <- rep(1 / nlayer, nlayer)
  ok <- tryCatch({
    l$set_physiology(area_leaf = area_leaf, mass_root_prop = mrp, rho = 608,
                     a_bio = 0.0245, PPFD = PPFD, psi_soil = psi_v,
                     soil_depth = dep_v,
                     leaf_specific_conductance_max = 1 * th / h, atm_vpd = 2,
                     ca = 40, sapwood_volume_per_leaf_area = th * h,
                     leaf_temp = 25, atm_o2_kpa = 21, atm_kpa = 101.3)
    l$find_root_collar_psi(); TRUE }, error = function(e) FALSE)
  if (!ok) return(NULL)
  p  <- -l$root_collar_psi_
  ps <- l$opt_psi_stem_
  tr <- l$transpiration_
  g  <- tryCatch(l$dprofit_droot_collar_psi(p), error = function(e) NA_real_)
  case <- if (tr == 0) "wet bound (E=0)"
          else if (abs(ps - PSI_CRIT) < 1e-8 || abs(ps - ROOT_PSI_CRIT) < 1e-8) "dry bound"
          else "interior"
  list(psi = psi, area = area_leaf, n = nlayer, p = p, ps = ps, tr = tr,
       margin = ps - p, g = g, profit = l$profit_, E = l$E_up_, case = case)
}

row <- function(r) cat(sprintf("%7.3f %9.2e %2d %9.4f %9.4f %10.3e %10.4f %11.4g  %s\n",
  r$psi, r$area, r$n, r$p, r$ps, r$tr, r$margin, r$g, r$case))
hdr <- function() cat(sprintf("%7s %9s %2s %9s %9s %10s %10s %11s  %s\n",
  "psi", "area_leaf", "L", "p*", "psi_stem", "transpir", "margin", "dprofit/dp", "case"))

cat("=== 1. single layer, the corner report's leaf area (0.05), across soil potential ===\n")
cat("A stationary interior optimum needs dprofit/dp ~ 0. Note where it is not.\n\n"); hdr()
for (psi in c(0.02, 0.05, 0.08, 0.1, 0.15, 0.2, 0.3, 0.5, 1.0, 2.0, 3.0)) {
  r <- classify(psi, 0.05); if (!is.null(r)) row(r) else cat(sprintf("%7.3f  <failed>\n", psi))
}

cat("\n=== 2. single layer, production-scale leaf area, across soil potential ===\n")
cat("A production run's competition_effect (= area_leaf) starts near 1.2e-4.\n\n"); hdr()
for (psi in c(0.02, 0.05, 0.1, 0.2, 0.5, 1.0, 2.0)) {
  r <- classify(psi, 1.2e-4); if (!is.null(r)) row(r) else cat(sprintf("%7.3f  <failed>\n", psi))
}

cat("\n=== 3. five layers over 1.5 m, as TF24 runs it ===\n"); hdr()
for (ar in c(1.2e-4, 1e-3, 1e-2, 0.05)) for (psi in c(0.05, 0.2, 1.0, 2.0)) {
  r <- classify(psi, ar, nlayer = 5, depth = 1.5)
  if (!is.null(r)) row(r) else cat(sprintf("%7.3f %9.2e  <failed>\n", psi, ar))
}

cat("\n=== 4. leaf-area sweep at one soil potential, single layer ===\n"); hdr()
for (ar in 10^seq(-4, -1, by = 0.5)) {
  r <- classify(1.0, ar); if (!is.null(r)) row(r) else cat(sprintf("        %9.2e  <failed>\n", ar))
}
