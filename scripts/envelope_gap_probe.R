# How much of d(profit)/d(soil) is the argmax's motion?
#
# The corner probe showed dprofit/dp is nonzero at p*, so the total derivative is
#
#   d(profit)/d(psi)  =  [explicit partial at fixed p*]  +  g * dp*/dpsi ,
#                                                          g = dprofit/dp
#
# and an envelope argument drops the second term on the grounds that g = 0. It is
# not. This measures each piece separately and reports the split.
#
# Two things make this delicate and both are handled explicitly:
#
#  * p* tracks the soil almost exactly (dp*/dpsi ~ 1), so evaluating at a FIXED
#    collar while perturbing the soil immediately lands on the other side of the
#    corner. The resulting difference is the jump height (~1.5) divided by the
#    step, i.e. it diverges as 1/step. That is not an estimate of anything, and a
#    naive frozen finite difference reports it as a derivative.
#  * a re-solved difference can also straddle the corner at some step sizes. ci
#    identifies the branch (~4.33 non-productive, ~5.49 productive), so each
#    evaluation is checked and a crossing is reported rather than averaged into a
#    slope.
#
#   Rscript scripts/envelope_gap_probe.R

suppressMessages({ library(odelia); pkgload::load_all("plant", quiet = TRUE) })

make_leaf <- function(gss_tol = 1e-10) {
  v <- 100; rb <- 1.29; rc <- 2.65
  Leaf(vcmax_25 = v, jmax_25 = v * 167, c = 2.04, b = 3, psi_crit = 5,
       root_c = rc, root_b = rb, root_psi_crit = rb * (log(1 / 0.05))^(1 / rc),
       beta2 = 1, a = 0.3, curv_fact_elec_trans = 0.7, curv_fact_colim = 0.99,
       GSS_tol_abs = gss_tol, vulnerability_curve_ncontrol = 100,
       ci_abs_tol = 1e-8, ci_niter = 1000, g1_TF24 = 46.32995,
       beta_R_H = 3.4e3, beta_R_V = 9.4e4)
}
set_phys <- function(l, psi) {
  th <- 0.000157; h <- 5
  l$set_physiology(area_leaf = 0.05, mass_root_prop = 1, rho = 608, a_bio = 0.0245,
                   PPFD = 900, psi_soil = psi, soil_depth = 1,
                   leaf_specific_conductance_max = 1 * th / h, atm_vpd = 2, ca = 40,
                   sapwood_volume_per_leaf_area = th * h, leaf_temp = 25,
                   atm_o2_kpa = 21, atm_kpa = 101.3)
}

# The model as run: solve, and report which branch it landed on.
solved <- function(psi, gss_tol = 1e-10) {
  l <- make_leaf(gss_tol); set_phys(l, psi)
  l$find_root_collar_psi()
  list(p = -l$root_collar_psi_, profit = l$profit_, ci = l$ci_,
       cons = l$soil_consumption_[1], g = l$dprofit_droot_collar_psi(-l$root_collar_psi_))
}

# Central difference of the model as run, with a branch-consistency check.
total_deriv <- function(psi, d) {
  a <- solved(psi - d); b <- solved(psi + d); m <- solved(psi)
  crossed <- (abs(a$ci - m$ci) > 0.5) || (abs(b$ci - m$ci) > 0.5)
  list(prof = (b$profit - a$profit) / (2 * d),
       cons = (b$cons - a$cons) / (2 * d),
       dp   = (b$p - a$p) / (2 * d),
       crossed = crossed)
}

cat("=== 1. the total derivative, and its stability in the step ===\n")
cat("A branch crossing is flagged; those rows are differencing the jump, not a slope.\n\n")
cat(sprintf("%8s %8s %13s %13s %10s %8s\n",
            "psi", "step", "dprofit/dpsi", "dcons/dpsi", "dp*/dpsi", "crossed"))
keep <- list()
for (psi in c(0.5, 1.0, 1.5, 2.0)) {
  for (d in c(1e-3, 3e-4, 1e-4, 3e-5)) {
    r <- tryCatch(total_deriv(psi, d), error = function(e) NULL)
    if (is.null(r)) { cat(sprintf("%8.2f %8.0e   <failed>\n", psi, d)); next }
    cat(sprintf("%8.2f %8.0e %13.6g %13.4g %10.5f %8s\n",
                psi, d, r$prof, r$cons, r$dp, ifelse(r$crossed, "YES", "-")))
    if (!r$crossed && d == 1e-4) keep[[as.character(psi)]] <- r
  }
}

cat("\n=== 2. the split: how much of the total is the argmax's motion? ===\n")
cat("total = explicit + g * dp*/dpsi.  The envelope argument keeps only 'explicit'.\n\n")
cat(sprintf("%8s %12s %10s %14s %12s %10s\n",
            "psi", "total", "g", "g * dp*/dpsi", "explicit", "argmax %"))
for (psi in names(keep)) {
  r <- keep[[psi]]; s <- solved(as.numeric(psi))
  motion <- s$g * r$dp
  explicit <- r$prof - motion
  cat(sprintf("%8s %12.6g %10.4g %14.6g %12.4g %9.1f%%\n",
              psi, r$prof, s$g, motion, explicit,
              100 * abs(motion) / max(1e-30, abs(r$prof))))
}

cat("\n=== 3. the water channel, on its own terms ===\n")
cat("soil_consumption at the re-solved operating point, across soil potential.\n\n")
cat(sprintf("%8s %14s %14s %12s\n", "psi", "consumption", "p*", "p* - psi"))
for (psi in c(0.5, 1.0, 1.5, 2.0)) {
  s <- solved(psi)
  cat(sprintf("%8.2f %14.8g %14.6f %12.6f\n", psi, s$cons, s$p, s$p - psi))
}
cat("\nIf p* tracks psi one-for-one the driving gradient (psi - P_collar - grav) is\n")
cat("nearly invariant, so uptake barely responds to soil potential at the re-solved\n")
cat("operating point -- which is a statement about the coupling, not about AD.\n")
