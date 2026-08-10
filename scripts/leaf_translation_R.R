# R's translation defect: the stem side, and a re-examination of A3.
#
# scripts/leaf_translation.R settled the root side. The uptake's only
# translation-breaking term is the root vulnerability integral over a sliding
# interval, and its derivative is exact in closed form (0.002-0.012%). What is
# left is R's own defect,
#
#     D = dR/dp + sum_i dR/dpsi_i        so   1 - dp*/dpsi_unif = D/Pi_pp
#
# and A3 reported the diagonal difference gapping 3.18-29.55% against
# subtraction. I attributed that to a relocated cancellation. That diagnosis is
# probably WRONG, and B1 tests it: near a stationary point R is ~1e-7, so a
# diagonal difference with step 1e-6 has a signal of D*h ~ 5e-8 -- at or below R's
# own residual noise. If so the gap is a STEP SIZE artifact, the defect costs only
# the 1-1.5 digits its 4-9% survival implies, and the amplification is affordable
# rather than a crisis.
#
#   B1  D by diagonal central difference of R, swept over five step sizes,
#       against defect_sub * Pi_pp. Does it converge?
#
#   B2  the stem side's structural result. psi_from_transpiration P and
#       transpiration_from_psi S are INVERSES, so P(S(x)) = x and
#       P'(S(x)) S'(x) = 1. With psi_stem = P(E_up/kappa + S(p)):
#
#         dpsi_stem/dd = P'(E_ps) * [ (dE_up/dd)/kappa + S'(p) ]
#                      = 1 + P'(E_ps)*(dE_up/dd)/kappa
#                          + S'(p)*[ P'(E_ps) - P'(S(p)) ]
#
#       so the stem potential tracks the translation EXACTLY but for two terms:
#       the root side's uptake defect carried through the transport, and the
#       curvature of the transport spline over the transpiration interval. Both
#       are directly computable. Tested against a difference of psi_stem.
#
#       S and P are reachable without new accessors: transpiration(x, 0) =
#       kappa*S(x) and transpiration_to_psi_stem(y*kappa, 0) = P(y).
#
# CONFIGURATION as scripts/leaf_translation.R: develop @141dc8df,
# TF24_Strategy() defaults, 20 layers over 1.5 m, GSS_tol_abs 1e-10.
#
#   Rscript scripts/leaf_translation_R.R [n_layers]
#
# RESULTS, develop @141dc8df, 20 layers.
#
#   B1  NOT a step size, and NOT a cancellation either. D by diagonal difference is
#       identical at every step from 1e-6 to 1e-2 (-0.941, -3.03, -7.54), so it is
#       well resolved. The disagreement with the reference is the REFERENCE:
#       scripts/leaf_uniform_check.R shows the whole-solve response is unconverged
#       at 1e-6 and that D's value is right. Pi_pp here is -14.4, -71.9, -198.3 --
#       an order larger than at 5 layers, since more layers means more conductance
#       and a sharper optimum.
#
#   B2  THE STEM SIDE IS EXACT, and the stem does not track the soil:
#         sapling  dpsi_stem/dd = 1.28007123 measured, 1.28007376 predicted
#         tree                    1.99185490            1.99185461
#         canopy                  2.97141233            2.97142348
#       Relative error below 5e-06 at all three. So
#         dpsi_stem/dd = 1 + P'(E_ps)*(dE_up/dd)/kappa + S'(p)*[P'(E_ps) - P'(S(p))]
#       is exact, and P(S(x)) = x is what makes the leading 1 appear.
#
#       The split matters: the uptake term is -0.0098 to -0.036, the transport
#       CURVATURE term is +0.29 to +2.01. So the stem potential falls 1.3 to 3.0
#       times as fast as the soil under uniform drying, dominated by the xylem
#       transport spline's curvature, not by the root side at all. The collar
#       tracks the soil (dp*/dpsi ~ 0.93-0.96); the stem amplifies it.

suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE)
})
n_layers <- as.integer(commandArgs(TRUE)[1]); if (is.na(n_layers)) n_layers <- 20L

s0 <- TF24_Strategy(); p <- s0$pars
soil_depth <- (1:n_layers) * (1.5 / n_layers)
z_mid <- soil_depth - (1.5 / n_layers) / 2; grav <- 9.8e-3 * z_mid
eta_c <- 1 - 2 / (1 + p$eta) + 1 / (1 + 2 * p$eta)
root_scale <- 83.26 * 0.5
root_b <- 3.898245; root_c <- 2.680147
f_r <- function(m) ifelse(m <= 0, 1, exp(-(m / root_b)^root_c))
kg_per_mol <- 0.018015

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
R_at <- function(h, psi, p0, pe) { phys(h, psi); invisible(l$evaluate_root_collar_psi(p0))
  tryCatch(l$dprofit_droot_collar_psi(pe), error = function(e) NA_real_) }
# psi_stem at a given collar magnitude, soil as given
stem_at <- function(h, psi, pm) { phys(h, psi)
  invisible(l$evaluate_root_collar_psi(pm)); l$opt_psi_stem_ }

states <- list(list(h = 2.0, ps = 0.05, tag = "sapling, wet"),
               list(h = 8.0, ps = 0.17, tag = "tree, dry end"),
               list(h = 17.9, ps = 0.17, tag = "canopy max, dry end"))

cat(sprintf("develop build, %d layers, GSS_tol_abs 1e-10\n\n", n_layers))

## ---- B1 -------------------------------------------------------------------
cat("=== B1  was A3 a cancellation, or a step size? ===\n")
cat("reference D = (1 - dp*/dpsi_unif) * Pi_pp, from the whole-solve response.\n")
cat("Then D by diagonal central difference of R at five steps.\n\n")
cat(sprintf("%-22s %10s %10s %11s | %s\n", "state", "Pi_pp", "D ref", "|R(p*)|",
            "D at h = 1e-6 / 1e-5 / 1e-4 / 1e-3 / 1e-2  (rel err)"))
for (st in states) {
  psi <- rep(st$ps, n_layers); h <- st$h
  p0 <- solve_at(h, psi); hr <- 1e-5 * p0
  hpp <- (R_at(h, psi, p0, p0 + hr) - R_at(h, psi, p0, p0 - hr)) / (2 * hr)
  hs <- 1e-6
  dps <- (solve_at(h, psi + hs) - solve_at(h, psi - hs)) / (2 * hs)
  Dref <- (1 - dps) * hpp
  R0 <- R_at(h, psi, p0, p0)
  cat(sprintf("%-22s %10.4g %10.4g %11.3g |", st$tag, hpp, Dref, abs(R0)))
  for (hh in c(1e-6, 1e-5, 1e-4, 1e-3, 1e-2)) {
    D <- (R_at(h, psi + hh, p0, p0 + hh) - R_at(h, psi - hh, p0, p0 - hh)) / (2 * hh)
    cat(sprintf(" %9.3g(%6.2f%%)", D, 100 * abs(D - Dref) / max(abs(Dref), 1e-300)))
  }
  cat("\n")
}

## ---- B2 -------------------------------------------------------------------
cat("\n=== B2  the stem potential's translation defect, in closed form ===\n")
cat("measured  = central difference of psi_stem along psi and p together\n")
cat("predicted = 1 + P'(E_ps)*(dE_up/dd)/kappa + S'(p)*[P'(E_ps) - P'(S(p))]\n")
cat("P and S recovered from transpiration_to_psi_stem(.,0) and transpiration(.,0)\n\n")
cat(sprintf("%-22s %12s %12s %9s | %12s %12s\n", "state", "measured", "predicted",
            "rel err", "uptake term", "curv term"))
for (st in states) {
  psi <- rep(st$ps, n_layers); h <- st$h
  p0 <- solve_at(h, psi)
  hd <- 1e-6
  meas <- (stem_at(h, psi + hd, p0 + hd) - stem_at(h, psi - hd, p0 - hd)) / (2 * hd)

  # the pieces, at the operating point
  phys(h, psi); invisible(l$evaluate_root_collar_psi(p0))
  kap <- l$leaf_specific_conductance_max_
  E0m <- l$soil_consumption_                      # mol, per layer
  al <- al_of(h); rVsum <- l$r_R_V_sum; rHmin <- l$r_R_H_min; msl <- l$max_soil_layer
  num <- (-psi) - (-p0) - grav
  rR <- num / (al * E0m); rH <- rR - rVsum[seq_along(rR)]
  span <- abs(p0 - psi); integ <- rHmin[seq_along(rR)] * span / rH
  mmax <- pmax(psi, p0); mmin <- pmin(psi, p0)
  dEi <- E0m * (rH / rR) * (f_r(mmax) - f_r(mmin)) / integ      # validated in A2
  dEup <- sum(dEi[seq_len(msl)]) * kg_per_mol                   # kg, as E_up_ is

  Sof  <- function(x) l$transpiration(x, 0) / kap
  Pof  <- function(y) l$transpiration_to_psi_stem(y * kap, 0)
  dd <- 1e-6
  Sp_at <- function(x) (Sof(x + dd) - Sof(x - dd)) / (2 * dd)
  Pp_at <- function(y) (Pof(y + dd) - Pof(y - dd)) / (2 * dd)

  Sp0 <- Sof(p0)
  E_ps <- l$E_up_ / kap + Sp0
  t_up <- Pp_at(E_ps) * dEup / kap
  t_cv <- Sp_at(p0) * (Pp_at(E_ps) - Pp_at(Sp0))
  pred <- 1 + t_up + t_cv
  cat(sprintf("%-22s %12.8f %12.8f %8.3f%% | %12.4g %12.4g\n", st$tag, meas, pred,
              100 * abs(pred - meas) / max(abs(meas), 1e-300), t_up, t_cv))
}
