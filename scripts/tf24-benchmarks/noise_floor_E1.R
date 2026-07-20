# Oracle test E1 -- measure the derivative noise floor of the TF24 inner argmax.
#
# CLAIM (Oracle, 2026-07-20): the fixed-tolerance golden-section argmax
# `p_hat = argmax profit(collar_psi)` is continuous but NOT smooth below its
# resolution floor eps_p ~ GSS_tol_abs. As a continuous input moves, the search's
# interior-comparison outcomes flip one by one, so p_hat follows a path with dense
# sub-resolution kinks of size ~eps_p. Pushed through the RHS: non-stationary
# outputs (transpiration, assim -> the coupling c and growth g) inherit an O(eps_p)
# ripple, while the STATIONARY objective (profit) hides it at O(eps_p^2) (envelope).
# The embedded RK controller then bisects against this tolerance-independent floor.
#
# DECISIVE, SPECIFIC PREDICTIONS (a generic "roundoff" story cannot make these):
#  P1. opt_psi_stem_ vs a swept input is a staircase; step height ~ GSS_tol_abs
#      (scales ~linearly as tol shrinks).
#  P2. transpiration_ ripple amplitude ~ O(eps_p)      -> shrinks ~linearly in tol.
#  P3. profit_        ripple amplitude ~ O(eps_p^2)     -> shrinks ~quadratically.
#  => the P2/P3 asymmetry is the envelope signature and the sharpest tell.
#
# Zero production changes: GSS_tol_abs is a ctor arg. This drives the Leaf directly
# via the same R interface as tests/testthat/test-tf24-shutdown.R.

suppressMessages({
  options(pkg.build_extra_flags = FALSE)
  pkgload::load_all("plant", export_all = TRUE, quiet = TRUE)
})

mkleaf <- function(gss_tol) Leaf(
  vcmax_25 = 100, jmax_25 = 100 * 167, c = 2.04, b = 3, psi_crit = 5,
  root_c = 2.65, root_b = 1.29, root_psi_crit = 1.29 * (log(1 / 0.05))^(1 / 2.65),
  beta2 = 1, a = 0.3, curv_fact_elec_trans = 0.7, curv_fact_colim = 0.99,
  GSS_tol_abs = gss_tol, vulnerability_curve_ncontrol = 100,
  ci_abs_tol = 1e-8, ci_niter = 1000, g1_TF24 = 46.32995,
  beta_R_H = 3.4e3, beta_R_V = 9.4e4)

# uniform soil moisture at level `psi` (MPa, positive magnitude), 5 layers.
setp <- function(L, psi) L$set_physiology(
  area_leaf = 1, mass_root_prop = rep(1 / 5, 5), rho = 608, a_bio = 0.0245,
  PPFD = 1800, psi_soil = rep(psi, 5),
  soil_depth = seq(0.3, by = 0.3, length.out = 5),
  leaf_specific_conductance_max = 1e-4, atm_vpd = 1, ca = 40,
  sapwood_volume_per_leaf_area = 1e-4, leaf_temp = 25, atm_o2_kpa = 21,
  atm_kpa = 101.3)

# One solve: argmax (direct + derived), non-stationary outputs, stationary objective.
solve_at <- function(L, psi) {
  setp(L, psi)
  L$find_root_collar_psi()
  c(root_collar = L$root_collar_psi_, opt_psi_stem = L$opt_psi_stem_,
    transp = L$transpiration_, assim = L$assim_colimited_,
    profit = L$profit_, E_up = L$E_up_)
}

# Sweep a soil-moisture window wide enough to contain MANY GSS treads. The floor
# is measured as deviation from a near-exact reference run (tol=1e-8), NOT by
# detrending -- this is the clean observable.
base_psi <- 1.0           # actively transpiring (psi < psi_crit=5), interior optimum
half_win <- 0.30          # +/- window in MPa: p* moves >> eps_p over this range
npt      <- 3000

phi_inv <- 1 / 1.6180339887
tols <- c(current = 1e-3, n8 = 1e-3 * phi_inv^8, n16 = 1e-3 * phi_inv^16, ref = 1e-8)

psis <- seq(base_psi - half_win, base_psi + half_win, length.out = npt)

cat("=== E1: leaf-solve noise floor vs GSS_tol_abs ===\n")
cat(sprintf("base_psi=%.3f  window=+/-%.2f MPa  npt=%d\n\n", base_psi, half_win, npt))

runs <- list()
for (nm in names(tols)) {
  L <- mkleaf(tols[[nm]])
  M <- t(vapply(psis, function(p) solve_at(L, p), numeric(6)))
  colnames(M) <- c("root_collar", "opt_psi_stem", "transp", "assim", "profit", "E_up")
  runs[[nm]] <- M
}
ref <- runs$ref
# branch-consistency mask: only points where every run stayed in the transpiring
# GSS branch (E_up>0), so branch-switching can't contaminate the floor estimate.
mask <- Reduce(`&`, lapply(runs, function(M) M[, "E_up"] > 0))
cat(sprintf("branch-consistent transpiring points: %d / %d\n", sum(mask), length(mask)))
cat(sprintf("scales (ref, over masked pts): E_up~%.3g  assim~%.3g  profit~%.3g\n\n",
            mean(abs(ref[mask,"E_up"])), mean(abs(ref[mask,"assim"])),
            mean(abs(ref[mask,"profit"]))))

# floor(tol) := median-abs deviation of a coarse-tol run from the near-exact ref
# run (median => robust to the rare branch-switch outlier). Non-stationary outputs
# that feed the RHS: E_up (coupling c), assim (growth g). Stationary: profit.
mad <- function(a, b) median(abs(a - b))
cat("floor := median|output_tol - output_ref| on branch-consistent points\n")
cat(sprintf("%-8s %-10s %-12s %-12s %-12s %-12s\n",
            "run", "tol", "d(argmax)", "d(E_up)", "d(assim)", "d(profit)"))
floor_of <- list()
for (nm in c("current", "n8", "n16")) {
  M <- runs[[nm]]
  fl <- c(argmax = mad(M[mask,"root_collar"], ref[mask,"root_collar"]),
          E_up   = mad(M[mask,"E_up"],        ref[mask,"E_up"]),
          assim  = mad(M[mask,"assim"],       ref[mask,"assim"]),
          profit = mad(M[mask,"profit"],      ref[mask,"profit"]))
  floor_of[[nm]] <- fl
  cat(sprintf("%-8s %-10.2e %-12.3e %-12.3e %-12.3e %-12.3e\n",
              nm, tols[[nm]], fl["argmax"], fl["E_up"], fl["assim"], fl["profit"]))
}

# log-log slope of floor vs tol. P1 argmax ~1; P2 non-stationary (E_up, assim) ~1;
# P3 stationary objective (profit) ~2 (envelope theorem: dP/dp=0 at optimum).
tv <- vapply(c("current","n8","n16"), function(k) tols[[k]], numeric(1))
slope <- function(key) {
  y <- vapply(c("current","n8","n16"), function(k) floor_of[[k]][key], numeric(1))
  ok <- is.finite(y) & y > 0
  if (sum(ok) < 2) return(NA_real_)
  unname(coef(lm(log(y[ok]) ~ log(tv[ok])))[2])
}
cat(sprintf("\nlog-log slope d log(floor)/d log(tol):\n  argmax=%.2f (P1 ~1)   E_up=%.2f  assim=%.2f (P2 ~1, O(eps))   profit=%.2f (P3 ~2, O(eps^2))\n",
            slope("argmax"), slope("E_up"), slope("assim"), slope("profit")))
sa <- slope("assim"); se <- slope("E_up"); sp <- slope("profit")
ns_slope <- mean(c(sa, se), na.rm = TRUE)
cat(sprintf("\nENVELOPE ASYMMETRY (the sharp tell): non-stationary slope ~1 (%.2f) vs profit slope ~2 (%.2f) => %s\n",
            ns_slope, sp,
            if (!is.na(sp) && !is.na(ns_slope) && sp > ns_slope + 0.5) "CONFIRMED" else "NOT SEEN"))

# --- Is the profit peak a SMOOTH interior max or a CORNER? ---------------------
# Envelope theorem holds only for a smooth interior optimum (dP/dp=0 there), which
# would give profit_err ~ argmax_err^2. A corner (dP/dp jumps sign) gives
# profit_err ~ argmax_err^1. This decides whether fix F1 (Newton on dP/dp=0 + IFT
# node) is even well-posed: a corner has no stationary point to polish to.
# Use the tol=1e-3 run vs ref; regress log|profit_err| on log|argmax_err| per point.
M <- runs$current
ae <- abs(M[mask,"root_collar"] - ref[mask,"root_collar"])
pe <- abs(M[mask,"profit"]      - ref[mask,"profit"])
ok <- ae > 1e-10 & pe > 1e-12
peak_slope <- if (sum(ok) > 20) unname(coef(lm(log(pe[ok]) ~ log(ae[ok])))[2]) else NA_real_
cat(sprintf("\n--- profit-peak geometry ---\n  regress log(profit_err) ~ log(argmax_err) over %d pts: slope = %.2f\n",
            sum(ok), peak_slope))
cat(sprintf("  => %s\n", if (is.na(peak_slope)) "insufficient data" else
      if (peak_slope < 1.4) "CORNER optimum (dP/dp jumps sign) -- F1 Newton/IFT NOT well-posed as posed"
      else if (peak_slope > 1.7) "SMOOTH interior optimum -- envelope holds, F1 well-posed"
      else "ambiguous (between corner and smooth)"))

saveRDS(list(psis = psis, runs = runs, tols = tols, floor_of = floor_of,
             peak_slope = peak_slope),
        "scripts/tf24-benchmarks/results/noise_floor_E1.rds")
cat("\nsaved results/noise_floor_E1.rds\n")
