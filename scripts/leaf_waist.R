# L3/L4 re-run: the implicit-function route for dp*/dpsi, and the two-scalar waist.
#
# The first attempt (scripts/leaf_bundle.R) was INVALID and the reason is a
# finding. dprofit_droot_collar_psi reads the member psi_soil_inverted_, which
# only prepare_collar_solve refreshes, and E_from_Soil_to_Root_Collar expects the
# INVERTED (negative) convention while set_physiology takes positive magnitudes.
# So perturbing the soil and calling either one directly differentiates against a
# stale or sign-flipped soil vector. Both are corrected here:
#
#   * evaluate_root_collar_psi(p0) is called BEFORE dprofit, not after -- it runs
#     prepare_collar_solve, which rebuilds psi_soil_inverted_ and the per-layer
#     cumulative-integral cache, and it leaves the operating point at p0 so the
#     difference is taken at frozen p*.
#   * E_from_Soil_to_Root_Collar is handed -psi, matching what
#     find_psi_stem_from_psi_root passes it.
#
# CONFIGURATION as scripts/curvature_probe.R and scripts/leaf_bundle.R: develop
# build, TF24_Strategy() defaults, 5 layers over 1.5 m, radiation 0.5*1800,
# atm_vpd 1, ca 40, leaf_temp 25, o2 21, atm 100.5, integrator (21, 1e-3),
# GSS_tol_abs 1e-10 so the numbers are geometry rather than search.
#
#   Rscript scripts/leaf_waist.R
#
# RESULTS, develop @141dc8df, 5 layers, GSS_tol_abs 1e-10.
#
#   L3  dp*/dpsi_1 by the implicit function theorem against a central difference
#       of the whole solve: relative error 0.45%, 2.16%, 3.19%, 3.34%, 4.16%,
#       7.66% over the six states. That is the double-differencing noise floor
#       (Pi_pp is itself a central difference), so the route is confirmed.
#       dp*/dpsi_1 itself runs 0.857 to 1.339 -- the plant tracks the soil, which
#       is why the flux derivative is a cancellation.
#
# SUPERSEDED, L4 ONLY, by scripts/leaf_waist2.R and leaf_waist3.R. Two faults:
# this probe passed E_from_Soil_to_Root_Collar a POSITIVE collar potential where
# it takes the signed one, and it fitted two coefficients to five layers. The
# tight residual below is real but says only "rank <= 2" -- the psi family is
# nearly rank ONE (s2/s1 ~ 1e-05), so the second coefficient is unidentified and
# the fitted value is noise. leaf_waist3.R identifies both from a joint fit and
# confirms the closed form. L3 stands.
#
#   L4  Residual of dR/dpsi[1:5] after projection onto
#       span{dE_up/dpsi, d2E_up/dp dpsi}, relative to |dR/dpsi|:
#         seedling 4.7e-16 | sapling wet 6.6e-07 | sapling dry 1.3e-06
#         tree dry 2.3e-07 | canopy max 1.7e-07 | beyond driver 6.4e-07
#       with cond(X) 1.00-6.06 at five of six (639 at the seedling, where the two
#       vectors are nearly parallel), so the fit is well posed and the residual is
#       the difference noise rather than left-over structure. The five potentials
#       reach the operating point through exactly two scalars, so this part of the
#       injected bundle does not grow with the soil layer count.

suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE)
})

n_layers <- 5L
s <- TF24_Strategy(); p <- s$pars
soil_depth <- (1:n_layers) * (1.5 / n_layers)
eta_c      <- 1 - 2 / (1 + p$eta) + 1 / (1 + 2 * p$eta)
root_scale <- 83.26 * 0.5

new_leaf <- function(gss_tol) {
  l <- Leaf(p$vcmax_25, p$c, p$b, p$psi_crit, 2.680147, 3.898245,
            3.898245 * log(1 / 0.05)^(1 / 2.680147), p$beta2, p$jmax_25, p$a,
            p$curv_fact_elec_trans, p$curv_fact_colim,
            gss_tol, 100, 1e-6, 1000, p$g1_TF24, 3.4e2, 9.4e3)
  l$initialize_integrator(21L, 1e-3); l
}
root_prop <- function(height) {
  rd <- min(height, 1.5); scale <- root_scale * p$a_r1 * (height / p$a_l1)^(1 / p$a_l2)
  out <- numeric(n_layers); prev_q <- 1
  for (a in seq_len(n_layers)) {
    if (prev_q == 0) break
    q <- if (soil_depth[a] > rd) 0 else (1 - (soil_depth[a] / rd)^p$root_depth_shape_eta)^2
    out[a] <- scale * (prev_q - q); prev_q <- q
  }
  out
}
phys <- function(l, height, psi) {
  l$set_physiology((height / p$a_l1)^(1 / p$a_l2), root_prop(height), p$rho, p$a_bio,
                   0.5 * 1800, psi, soil_depth, p$K_s * p$theta / (height * eta_c),
                   1, 40, p$theta * height * eta_c, 25, 21, 100.5)
}

# R at a GIVEN operating point, with the soil caches refreshed first.
R_frozen <- function(l, height, psi, p0) {
  phys(l, height, psi)
  l$evaluate_root_collar_psi(p0)          # refreshes psi_soil_inverted_, sets p = p0
  tryCatch(l$dprofit_droot_collar_psi(p0), error = function(e) NA_real_)
}
# E_up at a given collar magnitude, inverted convention, caches refreshed.
Eup_frozen <- function(l, height, psi, p0, pq) {
  phys(l, height, psi)
  l$evaluate_root_collar_psi(p0)
  l$E_from_Soil_to_Root_Collar(pq, -psi)
  l$E_up_
}

states <- list(
  list(h = 0.4,  ps = 0.05, tag = "seedling, wet"),
  list(h = 2.0,  ps = 0.05, tag = "sapling, wet"),
  list(h = 2.0,  ps = 0.17, tag = "sapling, driver's dry end"),
  list(h = 8.0,  ps = 0.17, tag = "tree, driver's dry end"),
  list(h = 17.9, ps = 0.17, tag = "canopy max, driver's dry end"),
  list(h = 8.0,  ps = 0.50, tag = "tree, beyond the driver"))

l <- new_leaf(1e-10)
cat("develop build, 5 layers, GSS_tol_abs 1e-10\n\n")
cat("=== L3  dp*/dpsi_1: implicit function theorem vs the whole solve ===\n")
cat(sprintf("%-28s %11s %11s %11s %9s\n", "state", "Pi_pp", "truth", "IFT", "rel err"))
res <- list()
for (st in states) {
  psi <- rep(st$ps, n_layers)
  phys(l, st$h, psi); l$find_root_collar_psi(); p0 <- -l$root_collar_psi_
  hq <- 1e-5 * p0
  hpp <- (R_frozen(l, st$h, psi, p0 + hq) - R_frozen(l, st$h, psi, p0 - hq)) / (2 * hq)

  hp <- 1e-6
  bump <- function(i, sgn) { q <- psi; q[i] <- q[i] + sgn * hp; q }
  # truth: re-solve the whole thing
  phys(l, st$h, bump(1, +1)); l$find_root_collar_psi(); tp <- -l$root_collar_psi_
  phys(l, st$h, bump(1, -1)); l$find_root_collar_psi(); tm <- -l$root_collar_psi_
  truth <- (tp - tm) / (2 * hp)

  dR <- numeric(n_layers)
  for (i in seq_len(n_layers)) {
    dR[i] <- (R_frozen(l, st$h, bump(i, +1), p0) -
              R_frozen(l, st$h, bump(i, -1), p0)) / (2 * hp)
  }
  ift <- -dR[1] / hpp
  cat(sprintf("%-28s %11.5g %11.5g %11.5g %8.2f%%\n", st$tag, hpp, truth, ift,
              100 * abs(ift - truth) / max(abs(truth), 1e-300)))
  res[[st$tag]] <- list(h = st$h, psi = psi, p0 = p0, hpp = hpp, dR = dR)
}

cat("\n=== L4  the waist: does dR/dpsi lie in span{dE_up/dpsi, d2E_up/dp dpsi}? ===\n")
cat("R reads the five potentials only through E_up and dE_up/dp, so the 5-vector\n")
cat("dR/dpsi_i must be a fixed linear combination of two other 5-vectors. The\n")
cat("residual is what is left after the best such combination.\n\n")
cat(sprintf("%-28s %12s %12s %12s\n", "state", "|dR/dpsi|", "resid / norm", "cond(X)"))
for (st in states) {
  r <- res[[st$tag]]; psi <- r$psi; p0 <- r$p0
  hp <- 1e-6; hq <- 1e-5 * p0
  bump <- function(i, sgn) { q <- psi; q[i] <- q[i] + sgn * hp; q }
  dEup <- dEup_p <- numeric(n_layers)
  for (i in seq_len(n_layers)) {
    ep <- Eup_frozen(l, st$h, bump(i, +1), p0, p0)
    em <- Eup_frozen(l, st$h, bump(i, -1), p0, p0)
    dEup[i] <- (ep - em) / (2 * hp)
    gp <- (Eup_frozen(l, st$h, bump(i, +1), p0, p0 + hq) -
           Eup_frozen(l, st$h, bump(i, +1), p0, p0 - hq)) / (2 * hq)
    gm <- (Eup_frozen(l, st$h, bump(i, -1), p0, p0 + hq) -
           Eup_frozen(l, st$h, bump(i, -1), p0, p0 - hq)) / (2 * hq)
    dEup_p[i] <- (gp - gm) / (2 * hp)
  }
  X <- cbind(dEup, dEup_p); y <- r$dR
  keep <- is.finite(y) & apply(is.finite(X), 1, all)
  resid <- cnd <- NA_real_
  if (sum(keep) >= 3) {
    Xk <- X[keep, , drop = FALSE]
    sv <- svd(scale(Xk, center = FALSE, scale = TRUE))$d
    cnd <- if (min(sv) > 0) max(sv) / min(sv) else Inf
    fit <- tryCatch(qr.solve(Xk, y[keep]), error = function(e) NULL)
    if (!is.null(fit))
      resid <- sqrt(sum((y[keep] - Xk %*% fit)^2)) / max(sqrt(sum(y[keep]^2)), 1e-300)
  }
  cat(sprintf("%-28s %12.4g %12.3g %12.4g\n", st$tag, sqrt(sum(y^2)), resid, cnd))
}
