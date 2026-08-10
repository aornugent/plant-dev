# Does the search tolerance corrupt the gradient? The Chesterton's-fence test for
# proposing to change the collar solve at all.
#
# Two quantities the leaf owes a gradient consumer:
#
#   profit_            the objective at its own maximiser. If the operating point
#                      is stationary this is the envelope partial and needs no
#                      argmax derivative -- error from a mislocated argmax is
#                      g * delta, second order.
#   soil_consumption_  a consumer of the argmax, so it needs dp*/dtheta, and the
#                      argmax's location enters as the linearisation point.
#
# Report 2 measured a 3.5% derivative error at GSS_tol_abs = 1e-3 and concluded a
# Newton polish is mandatory -- but on a toy with a smooth interior maximum and an
# analytic second derivative. This runs the same test on TF24's leaf at the soil
# potentials and leaf areas a production run visits.
#
# Reference for dp*/dpsi: central difference of the re-solved operating point at
# GSS_tol_abs = 1e-12. Candidate: the same at develop's 1e-3. Also reports the
# implicit-function estimate built from develop's analytic gradient.
#
#   Rscript scripts/argmax_accuracy.R

suppressMessages({ library(odelia); pkgload::load_all("plant", quiet = TRUE) })

mk <- function(gss) Leaf(vcmax_25 = 100, jmax_25 = 100 * 167, c = 2.04, b = 3,
  psi_crit = 5, root_c = 2.65, root_b = 1.29,
  root_psi_crit = 1.29 * (log(1 / 0.05))^(1 / 2.65), beta2 = 1, a = 0.3,
  curv_fact_elec_trans = 0.7, curv_fact_colim = 0.99, GSS_tol_abs = gss,
  vulnerability_curve_ncontrol = 100, ci_abs_tol = 1e-6, ci_niter = 1000,
  g1_TF24 = 46.32995, beta_R_H = 3.4e3, beta_R_V = 9.4e4)

solve_at <- function(psi, ar, gss, nl = 5, dep = 1.5) {
  l <- mk(gss); th <- 0.000157; h <- 5
  l$set_physiology(area_leaf = ar, mass_root_prop = rep(1/nl, nl), rho = 608,
    a_bio = 0.0245, PPFD = 900, psi_soil = rep(psi, nl),
    soil_depth = dep * seq_len(nl) / nl,
    leaf_specific_conductance_max = 1 * th / h, atm_vpd = 2, ca = 40,
    sapwood_volume_per_leaf_area = th * h, leaf_temp = 25, atm_o2_kpa = 21,
    atm_kpa = 101.3)
  l$find_root_collar_psi()
  p <- -l$root_collar_psi_
  list(p = p, profit = l$profit_, cons = sum(l$soil_consumption_),
       g = l$dprofit_droot_collar_psi(p), tr = l$transpiration_)
}

dstar <- function(psi, ar, gss, d = 1e-5) {
  a <- solve_at(psi - d, ar, gss); b <- solve_at(psi + d, ar, gss)
  m <- solve_at(psi, ar, gss)
  list(dp = (b$p - a$p) / (2 * d), dprof = (b$profit - a$profit) / (2 * d),
       dcons = (b$cons - a$cons) / (2 * d), g = m$g, p = m$p, tr = m$tr)
}

# the psi_soil / area_leaf envelope a production run actually visits
PSIS  <- c(0.0146, 0.0165, 0.158, 0.169)
AREAS <- c(1.209e-4, 1.075e-3)

cat("=== 1. how far the search's argmax is from a well-located one ===\n")
cat(sprintf("%8s %10s %14s %14s %12s %12s\n",
            "psi", "area", "p*(tol 1e-3)", "p*(tol 1e-12)", "abs diff", "tol/2"))
for (psi in PSIS) for (ar in AREAS) {
  a <- solve_at(psi, ar, 1e-3); b <- solve_at(psi, ar, 1e-12)
  cat(sprintf("%8.4f %10.3e %14.8f %14.8f %12.3e %12.0e\n",
              psi, ar, a$p, b$p, abs(a$p - b$p), 5e-4))
}

cat("\n=== 2. dp*/dpsi_soil: does the search tolerance move it? ===\n")
cat("Reference is tol 1e-12. Relative error of the tol 1e-3 answer is the number\n")
cat("report 2 measured as 3.5% on a toy.\n\n")
cat(sprintf("%8s %10s %14s %14s %11s\n", "psi", "area", "dp*/dpsi @1e-3",
            "dp*/dpsi @1e-12", "rel err"))
for (psi in PSIS) for (ar in AREAS) {
  a <- dstar(psi, ar, 1e-3); b <- dstar(psi, ar, 1e-12)
  cat(sprintf("%8.4f %10.3e %14.8f %14.8f %11.2e\n",
              psi, ar, a$dp, b$dp, abs(a$dp - b$dp) / max(1e-30, abs(b$dp))))
}

cat("\n=== 3. the two output channels, same comparison ===\n")
cat(sprintf("%8s %10s %13s %13s %10s %13s %13s %10s\n", "psi", "area",
            "dprof @1e-3", "dprof @1e-12", "rel err", "dcons @1e-3",
            "dcons @1e-12", "rel err"))
for (psi in PSIS) for (ar in AREAS) {
  a <- dstar(psi, ar, 1e-3); b <- dstar(psi, ar, 1e-12)
  cat(sprintf("%8.4f %10.3e %13.6g %13.6g %10.2e %13.6g %13.6g %10.2e\n",
              psi, ar, a$dprof, b$dprof, abs(a$dprof - b$dprof)/max(1e-30, abs(b$dprof)),
              a$dcons, b$dcons, abs(a$dcons - b$dcons)/max(1e-30, abs(b$dcons))))
}

cat("\n=== 4. how stationary is the operating point at each tolerance? ===\n")
cat("g = dprofit/dp at the returned point. At a true interior maximum this is 0.\n\n")
cat(sprintf("%8s %10s %14s %14s\n", "psi", "area", "g @1e-3", "g @1e-12"))
for (psi in PSIS) for (ar in AREAS) {
  cat(sprintf("%8.4f %10.3e %14.4e %14.4e\n", psi, ar,
              solve_at(psi, ar, 1e-3)$g, solve_at(psi, ar, 1e-12)$g))
}
