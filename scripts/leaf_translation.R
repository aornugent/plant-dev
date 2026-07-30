# The amplification is a broken symmetry, and the defect has a closed form.
#
# THE OBSERVATION. Uptake responds to a UNIFORM soil drying only weakly, because
# the plant pulls harder and almost tracks it: report 06 section 9 measures
# dp*/dpsi = 0.9329-0.9958, so the driving disequilibrium changes by only
# (1 - dp*/dpsi) = 0.004-0.067 and any absolute error in dp*/dpsi shows up
# 15-238x larger in the flux derivative. scripts/leaf_waist2.R's T4 looked like a
# no-op only because it perturbed ONE layer of twenty, where dp*/dpsi_1 = 0.79 and
# there is no cancellation to expose. The uniform direction is the one that
# matters, and it was untested.
#
# THE MATHEMATICS. Translate the whole water column: psi_i -> psi_i + d and
# p -> p + d, in magnitudes. Read E_i off report 06 section 4.2 and the code:
#
#     E_i    = (psi_i - p - g_i) / (a * r_R,i)
#     r_R,i  = r_H,i * span_i / integral_i + r_V,i
#     span_i = |p - psi_i|                          INVARIANT under translation
#     integral_i = G(|P_min|) - G(|P_max|)          the vulnerability integral over
#                                                   a SLIDING interval -- NOT invariant
#
# The numerator is invariant. span, r_H, r_V, 1/a are invariant. So the ONLY
# translation-breaking term in the whole per-layer uptake is the cumulative root
# vulnerability integral, whose endpoints both slide. Differentiating,
#
#     d(integral_i)/dd = f_r(|P_min,i|) - f_r(|P_max,i|)
#     dE_i/dd          = E_i * (r_H,i / r_R,i) * (f_r(|P_min,i|) - f_r(|P_max,i|))
#                             / integral_i
#
# Every factor is already computed in the forward pass, plus two evaluations of
# the root vulnerability curve. So the badly-conditioned direction has an EXACT
# closed form that is a product of small things rather than a difference of large
# ones -- no cancellation to lose.
#
# THE ECOLOGY. If root conductivity did not decline with tension, f_r would be
# constant, the defect would be exactly zero, and uptake would be exactly
# insensitive to uniform drying. So the sensitivity of water uptake to a drying
# soil is set entirely by how much the ROOT vulnerability curve bends across the
# soil-to-collar span. Embolism is an absolute-potential phenomenon; the driving
# gradient is a difference. The whole amplification lives in that mismatch.
#
# WHAT THIS TESTS
#   A1  dp*/dpsi in the UNIFORM direction, which nothing has measured.
#   A2  the closed form above against a central difference of E_i along the
#       translation. This is the claim; if it fails the derivation is wrong.
#   A3  1 - dp*/dpsi two ways: by subtraction, and as D/Pi_pp where D is R's
#       translation defect taken as ONE diagonal directional derivative. In the
#       uniform direction these are NOT the same computation.
#
# CONFIGURATION as scripts/leaf_waist2.R: develop @141dc8df, TF24_Strategy()
# defaults, 20 soil layers over 1.5 m, GSS_tol_abs 1e-10, radiation 0.5*1800,
# atm_vpd 1, ca 40, leaf_temp 25, o2 21, atm 100.5, integrator (21, 1e-3).
#
#   Rscript scripts/leaf_translation.R [n_layers]
#
# RESULTS, develop @141dc8df, 20 layers.
#
#   A1  the uniform direction, measured for the first time:
#         sapling  dp*/dpsi = 0.907443   amplification 10.8x
#         tree     dp*/dpsi = 0.959159   amplification 24.5x
#         canopy   dp*/dpsi = 0.954816   amplification 22.1x
#       Against 0.79 (4.8x) for a single layer of twenty, so the near-cancellation
#       is real and belongs to the uniform direction. But it is 11-25x here, not
#       the 15-238x report 06 section 9's 0.9329-0.9958 implies -- that range is
#       from another configuration and does not reproduce at these states.
#
#   A2  THE CLOSED FORM IS EXACT. Predicted against a central difference of E_i
#       along the translation: 0.002% to 0.012% relative error, uniform across
#       every layer and all three states -- that is the difference's own
#       truncation error, which is what an exact formula looks like. The defect is
#       0.7-1.3% of the uptake level. So the badly-conditioned direction is
#       available in closed form from quantities the forward pass already holds,
#       plus two evaluations of the root vulnerability curve.
#
#   A3  MY VERDICT HERE WAS WRONG -- see scripts/leaf_uniform_check.R. The
#       diagonal route is the ACCURATE one and the reference it was judged against
#       (a whole-solve difference at step 1e-6) is not converged. Corrected defect
#       0.0652/0.0421/0.0380. Original text kept below for the record.
#
#   A3  [WRONG] D taken as a central difference along the diagonal gaps
#       3.18-29.55% against subtraction. A difference in a direction where R
#       barely moves puts the cancellation in the numerator: it relocates the
#       problem rather than removing it. The idea pays only if the directional
#       derivative is ANALYTIC. That is the remaining piece -- R's own translation
#       breakers are the xylem vulnerability integral S_t(p), the cost C(sigma)
#       and gc = kappa(S_t(sigma) - S_t(p)), so D has a closed form of the same
#       shape as A2's, on the stem side instead of the root side.

suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE)
})
n_layers <- as.integer(commandArgs(TRUE)[1]); if (is.na(n_layers)) n_layers <- 20L

s0 <- TF24_Strategy(); p <- s0$pars
soil_depth <- (1:n_layers) * (1.5 / n_layers)
z_mid <- soil_depth - (1.5 / n_layers) / 2
grav <- 9.8e-3 * z_mid
eta_c <- 1 - 2 / (1 + p$eta) + 1 / (1 + 2 * p$eta)
root_scale <- 83.26 * 0.5
root_b <- 3.898245; root_c <- 2.680147          # the hard-coded Leaf root curve
f_r <- function(m) ifelse(m <= 0, 1, exp(-(m / root_b)^root_c))

l <- Leaf(p$vcmax_25, p$c, p$b, p$psi_crit, root_c, root_b,
          root_b * log(1 / 0.05)^(1 / root_c), p$beta2, p$jmax_25, p$a,
          p$curv_fact_elec_trans, p$curv_fact_colim,
          1e-10, 100, 1e-6, 1000, p$g1_TF24, 3.4e2, 9.4e3)
l$initialize_integrator(21L, 1e-3)

root_prop <- function(h) {
  rd <- min(h, 1.5); sc <- root_scale * p$a_r1 * (h / p$a_l1)^(1 / p$a_l2)
  out <- numeric(n_layers); pq <- 1
  for (a in seq_len(n_layers)) { if (pq == 0) break
    q <- if (soil_depth[a] > rd) 0 else (1 - (soil_depth[a] / rd)^p$root_depth_shape_eta)^2
    out[a] <- sc * (pq - q); pq <- q }
  out
}
al_of <- function(h) (h / p$a_l1)^(1 / p$a_l2)
phys <- function(h, psi) l$set_physiology(al_of(h), root_prop(h), p$rho, p$a_bio,
  0.5 * 1800, psi, soil_depth, p$K_s * p$theta / (h * eta_c), 1, 40,
  p$theta * h * eta_c, 25, 21, 100.5)
solve_at <- function(h, psi) { phys(h, psi); l$find_root_collar_psi(); -l$root_collar_psi_ }
# E_i per layer at a given collar MAGNITUDE pm, signed conventions inside.
Ei <- function(h, psi, p0, pm) { phys(h, psi); invisible(l$evaluate_root_collar_psi(p0))
  l$E_from_Soil_to_Root_Collar(-pm, -psi); l$soil_consumption_ }
R_at <- function(h, psi, p0, pe) { phys(h, psi); invisible(l$evaluate_root_collar_psi(p0))
  tryCatch(l$dprofit_droot_collar_psi(pe), error = function(e) NA_real_) }

states <- list(list(h = 2.0, ps = 0.05, tag = "sapling, wet"),
               list(h = 8.0, ps = 0.17, tag = "tree, dry end"),
               list(h = 17.9, ps = 0.17, tag = "canopy max, dry end"))

cat(sprintf("develop build, %d layers, GSS_tol_abs 1e-10\n\n", n_layers))

cat("=== A1/A3  the uniform direction ===\n")
cat("dp*/dpsi_unif: all layers moved together, whole solve re-run.\n")
cat("defect_sub = 1 - dp*/dpsi_unif, by subtraction.\n")
cat("defect_dir = D/Pi_pp, D = dR along (p, psi) TOGETHER -- one difference in a\n")
cat("             direction where R barely moves, so no cancellation.\n\n")
cat(sprintf("%-22s %10s %11s %11s %11s %9s\n", "state", "p*", "dp*/dpsi",
            "defect_sub", "defect_dir", "gap"))
keep <- list()
for (st in states) {
  psi <- rep(st$ps, n_layers); h <- st$h
  p0 <- solve_at(h, psi); hp <- 1e-6; hr <- 1e-5 * p0
  dps <- (solve_at(h, psi + hp) - solve_at(h, psi - hp)) / (2 * hp)
  hpp <- (R_at(h, psi, p0, p0 + hr) - R_at(h, psi, p0, p0 - hr)) / (2 * hr)
  # D: move the soil AND the evaluation point together
  D <- (R_at(h, psi + hp, p0, p0 + hp) - R_at(h, psi - hp, p0, p0 - hp)) / (2 * hp)
  sub <- 1 - dps; dir <- D / hpp
  cat(sprintf("%-22s %10.5f %11.6f %11.4g %11.4g %8.2f%%\n", st$tag, p0, dps,
              sub, dir, 100 * abs(dir - sub) / max(abs(sub), 1e-300)))
  keep[[st$tag]] <- list(h = h, psi = psi, p0 = p0, amp = 1 / max(abs(sub), 1e-300))
}
cat("\namplification 1/(1 - dp*/dpsi_unif) per state:\n")
for (k in names(keep)) cat(sprintf("  %-22s %10.1fx\n", k, keep[[k]]$amp))

cat("\n=== A2  the closed form for the uptake's translation defect ===\n")
cat("measured  = central difference of E_i along psi and p together\n")
cat("predicted = E_i * (r_H/r_R) * (f_r(|Pmin|) - f_r(|Pmax|)) / integral\n")
cat("with r_R recovered from E_i, r_H = r_R - r_V_sum, integral = r_H_min*span/r_H\n\n")
for (st in states) {
  k <- keep[[st$tag]]; psi <- k$psi; h <- k$h; p0 <- k$p0
  hp <- 1e-7
  Ep <- Ei(h, psi + hp, p0, p0 + hp)
  Em <- Ei(h, psi - hp, p0, p0 - hp)
  meas <- (Ep - Em) / (2 * hp)

  E0 <- Ei(h, psi, p0, p0)
  phys(h, psi); invisible(l$evaluate_root_collar_psi(p0))
  rHmin <- l$r_R_H_min; rVsum <- l$r_R_V_sum; msl <- l$max_soil_layer
  al <- al_of(h)
  num  <- (-psi) - (-p0) - grav                 # signed numerator, per layer
  rR   <- num / (al * E0)                       # recovered
  rH   <- rR - rVsum[seq_along(rR)]
  span <- abs(p0 - psi)
  integ <- rHmin[seq_along(rR)] * span / rH
  mmax <- pmax(psi, p0); mmin <- pmin(psi, p0)  # magnitudes of P_min / P_max
  pred <- E0 * (rH / rR) * (f_r(mmax) - f_r(mmin)) / integ

  ok <- seq_len(msl)
  cat(sprintf("--- %s   p* = %.5f   max_soil_layer = %d\n", st$tag, p0, msl))
  cat(sprintf("%6s %13s %13s %13s %10s\n", "layer", "E_i", "measured", "predicted", "rel err"))
  for (i in ok) cat(sprintf("%6d %13.5g %13.5g %13.5g %9.3f%%\n", i, E0[i], meas[i],
      pred[i], 100 * abs(pred[i] - meas[i]) / max(abs(meas[i]), 1e-300)))
  cat(sprintf("%6s %13s %13.5g %13.5g %9.3f%%\n", "sum", "", sum(meas[ok]),
      sum(pred[ok]), 100 * abs(sum(pred[ok]) - sum(meas[ok])) /
        max(abs(sum(meas[ok])), 1e-300)))
  # what the naive route would give: dE/dpsi_unif assembled from two O(1) pieces
  cat(sprintf("  for scale: sum |E_i| = %.5g, so the defect is %.3g of the level\n\n",
              sum(abs(E0[ok])), abs(sum(meas[ok])) / max(sum(abs(E0[ok])), 1e-300)))
}
