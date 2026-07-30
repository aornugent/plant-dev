# The leaf's injected derivative bundle, against a finite difference of the
# whole leaf solve.
#
# The design differentiates the census through the leaf's BOUNDARY, not through
# the leaf: the interior stays double and a fixed bundle of partials is injected.
# Report 06 section 6.2 reduces that bundle to envelope rows, explicit flux rows,
# and one rank-one correction mu_k * grad(dPi/dp). This probe measures the four
# claims that bundle rests on, at production states, before anything is built on
# them.
#
#   L1  is the operating point stationary at production tolerance? The envelope
#       row is only valid where dPi/dp = 0, and GSS_tol_abs is 1e-3.
#   L2  Pi_pp, directly, against the ratio-of-two-measurements estimate the
#       design has been carrying. These differ by four orders in the corpus.
#   L3  dp*/dpsi by the implicit function theorem against a finite difference of
#       the whole solve. The IFT route is what the bundle uses.
#   L4  the waist: R reads the five soil potentials ONLY through E_up and
#       dE_up/dp, so dR/dpsi_i must lie in the span of two 5-vectors. If it does,
#       the bundle does not grow with the layer count.
#   L5  dE_i/d(area_leaf) = -E_i/area_leaf exactly, because inv_area_leaf is a
#       single factor and the root resistances contain no area_leaf.
#   L6  a leaf-only trait end to end: how much of dPi/d(vcmax_25) the envelope
#       covers, and how much of dE/d(vcmax_25) needs the argmax channel.
#
# CONFIGURATION. Identical to scripts/curvature_probe.R so the numbers compose:
# develop build, TF24_Strategy() defaults, 5 soil layers over 1.5 m, radiation
# 0.5*1800, atm_vpd 1, ca 40, leaf_temp 25, o2 21, atm 100.5, integrator (21,
# 1e-3). States are inside the default driver's psi_soil range (0.015-0.17 MPa)
# plus one drier point; heights span seedling to canopy.
#
#   Rscript scripts/leaf_bundle.R
#
# RESULTS, develop @141dc8df, 5 layers.
#   L1  the returned point is NOT stationary at production tolerance: |R| runs
#       8.8e-05 to 1.2e-03 at GSS_tol_abs 1e-3, against 1.6e-08 to 4.7e-07 at
#       1e-10. Three to four orders. The envelope row needs the tighter point.
#   L2  Pi_pp direct: -1.0896, -2.1577, -2.0747, -6.5278, -14.015, -6.3446 --
#       negative at 6/6. R(1e-3)/displacement reproduces each to 3-4 digits, so
#       the ratio method is sound; the ~1.1e5 it once gave came from pairing an
#       11-23 gradient with a 1e-4 displacement, and neither reproduces here.
#   L5  E_i * area_leaf invariant to 1.5e-16 - 4.1e-16 at five of six states, so
#       dE_i/d(area_leaf) = -E_i/area_leaf is exact. The SEEDLING drifts 0.75 and
#       needs diagnosis; at height 0.4 the rooting depth is 0.4 m against 0.3 m
#       layers, so the root distribution is degenerate there.
#   L6  the envelope theorem holds for a leaf trait: d(profit)/d(vcmax_25) at
#       frozen p* equals the full-solve difference to every printed digit at 6/6.
#       And dE/d(vcmax_25) at frozen p* is STRUCTURALLY zero -- E_from_Soil reads
#       no photosynthetic parameter -- so 100% of the uptake derivative for that
#       trait class arrives through the argmax channel.
#   the restore: one un-restored dprofit call at 1.05 p* moves soil_consumption_
#       by 5.643%.
#
# L3/L4 as run here are INVALID: dprofit_droot_collar_psi reads psi_soil_inverted_,
# refreshed only by prepare_collar_solve, and E_from_Soil_to_Root_Collar wants the
# inverted convention. scripts/leaf_waist.R re-runs both correctly.

suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE)
})

n_layers   <- 5L
s <- TF24_Strategy(); p <- s$pars
soil_depth <- (1:n_layers) * (1.5 / n_layers)
eta_c      <- 1 - 2 / (1 + p$eta) + 1 / (1 + 2 * p$eta)
root_scale <- 83.26 * 0.5

new_leaf <- function(gss_tol, vcmax = p$vcmax_25) {
  l <- Leaf(vcmax, p$c, p$b, p$psi_crit, 2.680147, 3.898245,
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

area_leaf_of <- function(height) (height / p$a_l1)^(1 / p$a_l2)

# set_physiology with every argument exactly as net_mass_production_dt assembles it
phys <- function(l, height, psi_soil, area_leaf = area_leaf_of(height),
                 mrp = root_prop(height)) {
  l$set_physiology(area_leaf, mrp, p$rho, p$a_bio, 0.5 * 1800,
                   psi_soil, soil_depth, p$K_s * p$theta / (height * eta_c),
                   1, 40, p$theta * height * eta_c, 25, 21, 100.5)
}

solved <- function(l, height, psi_soil) {
  phys(l, height, psi_soil); l$find_root_collar_psi()
  list(pstar = -l$root_collar_psi_, profit = l$profit_,
       cons = l$soil_consumption_, E_up = l$E_up_)
}

# R = dPi/dp. dprofit_droot_collar_psi leaves the leaf at ITS probe point (it
# refreshes E_up_ there), so restore afterwards -- develop does the same in
# tf24f_strategy.cpp:66.
R_at <- function(l, pp, pstar) {
  v <- tryCatch(l$dprofit_droot_collar_psi(pp), error = function(e) NA_real_)
  l$evaluate_root_collar_psi(pstar); v
}

states <- list(
  list(h = 0.4,  ps = 0.05, tag = "seedling, wet"),
  list(h = 2.0,  ps = 0.05, tag = "sapling, wet"),
  list(h = 2.0,  ps = 0.17, tag = "sapling, driver's dry end"),
  list(h = 8.0,  ps = 0.17, tag = "tree, driver's dry end"),
  list(h = 17.9, ps = 0.17, tag = "canopy max, driver's dry end"),
  list(h = 8.0,  ps = 0.50, tag = "tree, beyond the driver"))

cat("develop build, 5 soil layers, TF24_Strategy() defaults\n")
cat(sprintf("production GSS_tol_abs = %.0e; reference solve at 1e-10\n\n", 1e-3))

## ---- L1, L2 ---------------------------------------------------------------
cat("=== L1/L2  stationarity at production tolerance, and Pi_pp directly ===\n")
cat("R = dPi/dp at the returned point. displacement = p*(1e-3) - p*(1e-10).\n")
cat("ratio = R(1e-3)/displacement, which is how Pi_pp ~ 1.1e5 was obtained.\n\n")
cat(sprintf("%-28s %9s %11s %11s %11s %11s %11s\n", "state", "p*", "R @1e-3",
            "R @1e-10", "displacemt", "Pi_pp dir", "ratio est"))
l3 <- new_leaf(1e-3); lr <- new_leaf(1e-10)
L12 <- list()
for (st in states) {
  psi <- rep(st$ps, n_layers)
  a <- solved(l3, st$h, psi); b <- solved(lr, st$h, psi)
  Ra <- R_at(l3, a$pstar, a$pstar); Rb <- R_at(lr, b$pstar, b$pstar)
  hh <- 1e-4 * max(b$pstar, 1e-3)
  hpp <- (R_at(lr, b$pstar + hh, b$pstar) - R_at(lr, b$pstar - hh, b$pstar)) / (2 * hh)
  disp <- a$pstar - b$pstar
  cat(sprintf("%-28s %9.5f %11.4g %11.4g %11.3g %11.5g %11.4g\n",
              st$tag, a$pstar, Ra, Rb, disp, hpp,
              if (abs(disp) > 0) Ra / disp else NA))
  L12[[st$tag]] <- list(pstar = b$pstar, hpp = hpp, disp = disp, R3 = Ra, R10 = Rb)
}

## ---- L3, L4 ---------------------------------------------------------------
cat("\n=== L3/L4  dp*/dpsi_1 by the IFT, and the two-scalar waist ===\n")
cat("truth   = central difference of the WHOLE solve at 1e-10\n")
cat("IFT     = -(dR/dpsi_1)/Pi_pp, dR/dpsi_1 differenced at FROZEN p*\n")
cat("waist   = residual of dR/dpsi[1:5] projected onto span{dE_up/dpsi,\n")
cat("          d2E_up/dp dpsi}; near zero means the bundle is layer-count-free\n\n")
cat(sprintf("%-28s %12s %12s %9s %11s\n", "state", "truth", "IFT", "rel err", "waist resid"))
for (st in states) {
  psi <- rep(st$ps, n_layers)
  base <- solved(lr, st$h, psi); ps0 <- base$pstar
  hpp <- L12[[st$tag]]$hpp
  hp <- 1e-6

  bump <- function(i, sgn) { q <- psi; q[i] <- q[i] + sgn * hp; q }
  # truth: re-solve
  tp <- solved(lr, st$h, bump(1, +1))$pstar
  tm <- solved(lr, st$h, bump(1, -1))$pstar
  truth <- (tp - tm) / (2 * hp)

  # dR/dpsi_i at frozen p*, and the two E_up 5-vectors, all at frozen p*
  dR <- dEup <- dEup_p <- numeric(n_layers)
  hq <- 1e-5 * max(ps0, 1e-3)
  for (i in seq_len(n_layers)) {
    phys(lr, st$h, bump(i, +1)); rp <- R_at(lr, ps0, ps0)
    lr$E_from_Soil_to_Root_Collar(ps0, bump(i, +1)); ep <- lr$E_up_
    lr$E_from_Soil_to_Root_Collar(ps0 + hq, bump(i, +1)); epp <- lr$E_up_
    lr$E_from_Soil_to_Root_Collar(ps0 - hq, bump(i, +1)); epm <- lr$E_up_
    phys(lr, st$h, bump(i, -1)); rm <- R_at(lr, ps0, ps0)
    lr$E_from_Soil_to_Root_Collar(ps0, bump(i, -1)); em <- lr$E_up_
    lr$E_from_Soil_to_Root_Collar(ps0 + hq, bump(i, -1)); emp <- lr$E_up_
    lr$E_from_Soil_to_Root_Collar(ps0 - hq, bump(i, -1)); emm <- lr$E_up_
    dR[i]     <- (rp - rm) / (2 * hp)
    dEup[i]   <- (ep - em) / (2 * hp)
    dEup_p[i] <- (((epp - epm) / (2 * hq)) - ((emp - emm) / (2 * hq))) / (2 * hp)
  }
  phys(lr, st$h, psi); lr$find_root_collar_psi()

  ift <- -dR[1] / hpp
  # least squares of dR on the two waist vectors
  X <- cbind(dEup, dEup_p)
  keep <- is.finite(dR) & apply(is.finite(X), 1, all)
  resid <- NA_real_
  if (sum(keep) >= 3) {
    fit <- tryCatch(qr.solve(X[keep, , drop = FALSE], dR[keep]), error = function(e) NULL)
    if (!is.null(fit)) {
      pred <- X[keep, , drop = FALSE] %*% fit
      resid <- sqrt(sum((dR[keep] - pred)^2)) / max(sqrt(sum(dR[keep]^2)), 1e-300)
    }
  }
  cat(sprintf("%-28s %12.5g %12.5g %9.2f%% %11.3g\n", st$tag, truth, ift,
              100 * abs(ift - truth) / max(abs(truth), 1e-300), resid))
}

## ---- L5 -------------------------------------------------------------------
cat("\n=== L5  dE_i/d(area_leaf) = -E_i/area_leaf, exactly ===\n")
cat("E_i * area_leaf must be invariant to area_leaf. Reported as max relative\n")
cat("drift over a 2x range, at frozen p*.\n\n")
cat(sprintf("%-28s %13s %13s\n", "state", "max rel drift", "layers used"))
for (st in states) {
  psi <- rep(st$ps, n_layers); base <- solved(lr, st$h, psi); ps0 <- base$pstar
  a0 <- area_leaf_of(st$h); prods <- list()
  for (f in c(0.5, 0.8, 1.0, 1.3, 2.0)) {
    phys(lr, st$h, psi, area_leaf = a0 * f)
    lr$E_from_Soil_to_Root_Collar(ps0, psi)
    prods[[length(prods) + 1]] <- lr$soil_consumption_ * (a0 * f)
  }
  M <- do.call(rbind, prods); nz <- which(abs(M[1, ]) > 0)
  drift <- if (length(nz)) max(apply(M[, nz, drop = FALSE], 2,
                  function(v) (max(v) - min(v)) / max(abs(v)))) else NA
  cat(sprintf("%-28s %13.3g %13d\n", st$tag, drift, length(nz)))
  phys(lr, st$h, psi); lr$find_root_collar_psi()
}

## ---- L6 -------------------------------------------------------------------
cat("\n=== L6  a leaf-only trait, end to end: vcmax_25 ===\n")
cat("envelope = difference of profit at FROZEN p*; truth = difference of the\n")
cat("full solve. For the flux, the gap between them IS the argmax channel that\n")
cat("mu_k * grad(dPi/dp) has to supply.\n\n")
cat(sprintf("%-28s %11s %11s %8s | %11s %11s %8s\n", "state",
            "dPi env", "dPi truth", "gap", "dE env", "dE truth", "argmax%"))
hv <- 1e-4 * p$vcmax_25
for (st in states) {
  psi <- rep(st$ps, n_layers)
  base <- solved(lr, st$h, psi); ps0 <- base$pstar; E0 <- sum(base$cons)
  lp <- new_leaf(1e-10, p$vcmax_25 + hv); lm <- new_leaf(1e-10, p$vcmax_25 - hv)
  # frozen p*: evaluate the perturbed leaf AT the base operating point
  phys(lp, st$h, psi); lp$evaluate_root_collar_psi(ps0)
  fp <- lp$profit_; Efp <- sum(lp$soil_consumption_)
  phys(lm, st$h, psi); lm$evaluate_root_collar_psi(ps0)
  fm <- lm$profit_; Efm <- sum(lm$soil_consumption_)
  # truth: re-optimise
  tp <- solved(lp, st$h, psi); tm <- solved(lm, st$h, psi)
  d_env <- (fp - fm) / (2 * hv);           d_tru <- (tp$profit - tm$profit) / (2 * hv)
  E_env <- (Efp - Efm) / (2 * hv)
  E_tru <- (sum(tp$cons) - sum(tm$cons)) / (2 * hv)
  cat(sprintf("%-28s %11.5g %11.5g %7.2f%% | %11.5g %11.5g %7.1f%%\n",
              st$tag, d_env, d_tru, 100 * abs(d_env - d_tru) / max(abs(d_tru), 1e-300),
              E_env, E_tru, 100 * abs(E_tru - E_env) / max(abs(E_tru), 1e-300)))
}

## ---- the restore, measured ------------------------------------------------
cat("\n=== the restore: does dprofit_droot_collar_psi move the outputs? ===\n")
st <- states[[4]]; psi <- rep(st$ps, n_layers)
base <- solved(lr, st$h, psi); before <- base$cons
invisible(lr$dprofit_droot_collar_psi(base$pstar * 1.05))   # no restore
after <- lr$soil_consumption_
cat(sprintf("state: %s\n", st$tag))
cat(sprintf("max relative change in soil_consumption_ after one un-restored\n"))
cat(sprintf("dprofit call at 1.05 p*: %.4g\n",
            max(abs(after - before) / pmax(abs(before), 1e-300))))
