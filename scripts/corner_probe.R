# Is TF24's collar operating point a stationary interior maximum, or a corner?
#
# Report 5 section 3 asserts a corner, on evidence measured elsewhere. This tests
# it on develop, from R, using surfaces develop already exposes.
#
# The classifier is a sign change, not a magnitude. At an interior maximum
# dprofit/dp passes through zero, so it is positive just below p* and negative
# just above. At a corner the gradient is one-signed across p* and jumps. Both
# quantities are available: find_root_collar_psi() locates p*, and
# dprofit_droot_collar_psi(p) is develop's exact analytic gradient.
#
#   Rscript scripts/corner_probe.R
#
# Run with a TIGHT GSS_tol_abs so the argmax is well located; the question here is
# the geometry of the objective, not the search's resolution.

suppressMessages({ library(odelia); pkgload::load_all("plant", quiet = TRUE) })

make_leaf <- function(gss_tol = 1e-8) {
  vcmax_25 <- 100
  b <- 3; c_ <- 2.04; psi_crit <- 5
  root_c <- 2.65; root_b <- 1.29
  Leaf(vcmax_25 = vcmax_25, jmax_25 = vcmax_25 * 167, c = c_, b = b,
       psi_crit = psi_crit, root_c = root_c, root_b = root_b,
       root_psi_crit = root_b * (log(1 / 0.05))^(1 / root_c),
       beta2 = 1, a = 0.3, curv_fact_elec_trans = 0.7, curv_fact_colim = 0.99,
       GSS_tol_abs = gss_tol, vulnerability_curve_ncontrol = 100,
       ci_abs_tol = 1e-6, ci_niter = 1000, g1_TF24 = 46.32995,
       beta_R_H = 3.4e3, beta_R_V = 9.4e4)
}

# One layer, so the operating point is unambiguous and psi_soil is the only knob.
set_phys <- function(l, psi_soil, PPFD = 900) {
  theta <- 0.000157; h <- 5
  l$set_physiology(area_leaf = 0.05, mass_root_prop = 1, rho = 608,
                   a_bio = 0.0245, PPFD = PPFD, psi_soil = psi_soil,
                   soil_depth = 1,
                   leaf_specific_conductance_max = 1 * theta / h,
                   atm_vpd = 2, ca = 40,
                   sapwood_volume_per_leaf_area = theta * h,
                   leaf_temp = 25, atm_o2_kpa = 21, atm_kpa = 101.3)
}

# ---------------------------------------------------------------- classify -----
# Returns the operating point, the analytic gradient there, and the gradient a
# little either side. A sign change straddling p* means stationary; one sign
# means the optimum is where the objective stops being defined the other way.
classify <- function(psi_soil, d_rel = 1e-4, gss_tol = 1e-8) {
  l <- make_leaf(gss_tol)
  set_phys(l, psi_soil)
  ok <- tryCatch({ l$find_root_collar_psi(); TRUE }, error = function(e) FALSE)
  if (!ok) return(NULL)
  p_star <- -l$root_collar_psi_          # positive magnitude
  prof   <- l$profit_
  d <- max(1e-9, d_rel * abs(p_star))
  g  <- function(x) tryCatch(l$dprofit_droot_collar_psi(x), error = function(e) NA_real_)
  v  <- function(x) tryCatch(l$evaluate_root_collar_psi(x), error = function(e) NA_real_)
  out <- list(psi_soil = psi_soil, p_star = p_star, profit = prof,
              g_at = g(p_star), g_lo = g(p_star - d), g_hi = g(p_star + d),
              v_lo = v(p_star - d), v_at = v(p_star), v_hi = v(p_star + d))
  # evaluate_root_collar_psi mutates the leaf; re-solve before reading anything else
  out
}

cat("=== 1. operating point, and the analytic gradient there ===\n")
cat("psi_soil is a positive magnitude (MPa). p* is the collar potential magnitude.\n")
cat("g = dprofit/dp from develop's exact analytic gradient.\n\n")
cat(sprintf("%9s %9s %11s %12s %12s %12s %8s\n",
            "psi_soil", "p*", "profit", "g(p*-d)", "g(p*)", "g(p*+d)", "verdict"))
rows <- list()
for (ps in c(0.05, 0.2, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5)) {
  r <- classify(ps)
  if (is.null(r)) { cat(sprintf("%9.2f  <solve failed>\n", ps)); next }
  sgn_change <- is.finite(r$g_lo) && is.finite(r$g_hi) && (r$g_lo > 0) && (r$g_hi < 0)
  verdict <- if (sgn_change) "stationary" else "corner?"
  cat(sprintf("%9.2f %9.4f %11.4f %12.4g %12.4g %12.4g %8s\n",
              ps, r$p_star, r$profit, r$g_lo, r$g_at, r$g_hi, verdict))
  rows[[length(rows) + 1]] <- r
}

cat("\n=== 2. the objective across its feasible interval, at one state ===\n")
cat("Mapping evaluate_root_collar_psi finely. A shelf then a jump then a smooth\n")
cat("decline is the corner geometry; a single smooth hump is a stationary max.\n\n")
l <- make_leaf(); set_phys(l, 2.0)
l$find_root_collar_psi()
p_star <- -l$root_collar_psi_
grid <- sort(unique(c(seq(max(1e-3, p_star - 0.30), p_star + 0.60, length.out = 61),
                      p_star + c(-0.02, -0.005, -0.001, 0, 0.001, 0.005, 0.02))))
prof <- sapply(grid, function(x) tryCatch(l$evaluate_root_collar_psi(x),
                                          error = function(e) NA_real_))
ci   <- rep(NA_real_, length(grid))
for (i in seq_along(grid)) {
  tryCatch({ l$evaluate_root_collar_psi(grid[i]); ci[i] <- l$ci_ }, error = function(e) NULL)
}
d <- data.frame(p = grid, offset = grid - p_star, profit = prof, ci = ci)
d$dprofit <- c(NA, diff(d$profit) / diff(d$p))
print(d[seq(1, nrow(d), by = 2), ], row.names = FALSE, digits = 5)

cat(sprintf("\np* = %.6f;  profit(p*) = %.6f\n", p_star, max(prof, na.rm = TRUE)))
cat(sprintf("largest single-step jump in profit over the grid: %.4f\n",
            max(abs(diff(d$profit)), na.rm = TRUE)))
cat(sprintf("ci range over the grid: %.4f to %.4f\n",
            min(d$ci, na.rm = TRUE), max(d$ci, na.rm = TRUE)))
