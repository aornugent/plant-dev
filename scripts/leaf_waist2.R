# The leaf's waist, established rather than suggested: 20 layers, two species,
# the coefficient checked against its closed form, and the disequilibrium
# coordinate measured against the difference it replaces.
#
# WHAT scripts/leaf_waist.R LEFT OPEN, and why each item is here.
#
#  T1  Its projection fitted 2 coefficients to 5 layers -- 3 residual degrees of
#      freedom, so five points can lie near a 2-plane by luck. At 20 layers that
#      is 18. T1 also FIXES A CONVENTION BUG in it: E_from_Soil_to_Root_Collar
#      takes the SIGNED collar potential (find_psi_stem_from_psi_root passes it
#      -opt_root_psi), and leaf_waist.R passed +p0. The basis vectors were the
#      right shape with the wrong weights, which a 3-dof fit can absorb.
#  T2  psi is not the only family that reaches R through the waist. E_i =
#      (psi_i - p - grav_i)/area_leaf/r_R,i and r_R,i is built only from
#      mass_root_prop, so the root masses and area_leaf go through the SAME two
#      scalars. Fit (a, b) on the psi family alone, then PREDICT the other two.
#  T3  A good fit is not structure. b = dR/d(dE_up/dr) should equal
#      (A'*dci/dpsi_stem - C') * P'(E_psi_stem) * (-1/kappa) by inspection of R's
#      body -- every factor measurable from an exposed function.
#  T4  dp*/dpsi ~ 0.86-1.34, so the flux derivative is amplified 1/(1-dp*/dpsi) =
#      15-238x. In the disequilibrium coordinate delta = p - psi_1 the small
#      quantity is a variable, and the sum (dR/dpsi_1 + Pi_pp) it needs is a
#      DIAGONAL directional derivative -- computable as one difference instead of
#      a cancellation between two separately-computed O(1) numbers.
#  T5  The seedling was anomalous twice (L5 drift 0.75, L4 cond 639). Diagnose it
#      by layer. And demonstrate R's undeclared input.
#  T6  Every leaf number so far is single-species. Two species share the soil
#      vector and own a Leaf each, so the waist must hold per Leaf with its own
#      coefficients.
#
# CONFIGURATION. develop @141dc8df. TF24_Strategy() defaults for species A; for
# species B, lma and vcmax_25 moved so the leaf is genuinely different. 20 soil
# layers over 1.5 m (0.075 m each), radiation 0.5*1800, atm_vpd 1, ca 40,
# leaf_temp 25, o2 21, atm 100.5, integrator (21, 1e-3), GSS_tol_abs 1e-10 so the
# numbers are geometry rather than search.
#
# CONVENTIONS, since three of them collide here:
#   set_physiology                psi_soil as POSITIVE magnitudes
#   prepare_collar_solve          builds psi_soil_inverted_ = -psi_soil_
#   E_from_Soil_to_Root_Collar    BOTH arguments SIGNED (negative)
#   dprofit_droot_collar_psi      collar as a POSITIVE magnitude; r = -psi inside
#   transpiration_to_psi_stem     psi_upstream SIGNED; transpiration() positive
#
#   Rscript scripts/leaf_waist2.R [n_layers]
#
# RESULTS, develop @141dc8df, 20 layers, both species.
#   T1  rank <= 2 holds at 18 residual degrees of freedom: resid/norm 1.2e-08 to
#       1.1e-07, cond 1.29-2.86, and it survives the sign fix. Six of six.
#   T2  FALSIFIED AS RUN. The psi fit's (a,b) mispredicts the root-mass rows by
#       7.9-36% and area_leaf by 7.7-35%. Not noise.
#   T3  the fitted b disagrees with its closed form by 98-101%, sometimes in sign.
#       Taken with T2 this says the psi-only fit does not identify b -- see
#       scripts/leaf_waist3.R, which shows the psi family is nearly RANK ONE and
#       recovers both coefficients from a joint fit, matching the closed form to
#       0.16-1.04%. The waist is real; this estimator was not.
#   T4  NO-OP. split and diagonal agree to every printed digit because they are
#       the same expression: -(dR/dpsi_1 + Pi_pp)/Pi_pp == -dR/dpsi_1/Pi_pp - 1.
#       The disequilibrium coordinate is algebraically trivial here. Note also
#       dp*/dpsi_1 ~ 0.79 for ONE layer, against report 00's 0.9329-0.9958 for a
#       UNIFORM soil change -- so the 15-238x amplification belongs to the uniform
#       direction, and conflating the two overstated the single-layer case.
#   T5a the seedling anomaly is P0.1, not physiology. max_soil_layer = 6 of 20,
#       and layers 7-20 -- ZERO root mass -- report nonzero E_i (7.2e-10 down to
#       9.0e-12) drifting exactly 0.75 = (2.0-0.5)/2.0 as the area_leaf multiplier
#       moves while the stale value does not. Layers 1-6 drift exactly 0. So
#       dE_i/d(area_leaf) = -E_i/area_leaf is exact wherever the value is real.
#   T5b R's undeclared input is total, not a drift: R after set_physiology alone
#       is -4.3244858e-07 against 0.12438779 after evaluate_root_collar_psi
#       refreshes psi_soil_inverted_. Relative difference 1.
#   T6  the coefficients differ between species as they must, at identical soil
#       and kappa: a = -1.79e+05 vs -1.51e+05 (sapling), -9.11e+05 vs -7.66e+05
#       (tree). The waist is per Leaf, hence per species.

suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE)
})
n_layers <- as.integer(commandArgs(TRUE)[1]); if (is.na(n_layers)) n_layers <- 20L

s0 <- TF24_Strategy()
soil_depth <- (1:n_layers) * (1.5 / n_layers)
root_scale <- 83.26 * 0.5

# A species is a parameter set plus the Leaf it builds in prepare_strategy.
make_species <- function(mods = list()) {
  p <- s0$pars; for (nm in names(mods)) p[[nm]] <- mods[[nm]]
  eta_c <- 1 - 2 / (1 + p$eta) + 1 / (1 + 2 * p$eta)
  l <- Leaf(p$vcmax_25, p$c, p$b, p$psi_crit, 2.680147, 3.898245,
            3.898245 * log(1 / 0.05)^(1 / 2.680147), p$beta2, p$jmax_25, p$a,
            p$curv_fact_elec_trans, p$curv_fact_colim,
            1e-10, 100, 1e-6, 1000, p$g1_TF24, 3.4e2, 9.4e3)
  l$initialize_integrator(21L, 1e-3)
  list(p = p, eta_c = eta_c, l = l)
}

root_prop <- function(sp, height) {
  p <- sp$p; rd <- min(height, 1.5)
  scale <- root_scale * p$a_r1 * (height / p$a_l1)^(1 / p$a_l2)
  out <- numeric(n_layers); prev_q <- 1
  for (a in seq_len(n_layers)) {
    if (prev_q == 0) break
    q <- if (soil_depth[a] > rd) 0 else (1 - (soil_depth[a] / rd)^p$root_depth_shape_eta)^2
    out[a] <- scale * (prev_q - q); prev_q <- q
  }
  out
}
area_leaf_of <- function(sp, h) (h / sp$p$a_l1)^(1 / sp$p$a_l2)

phys <- function(sp, height, psi, area_leaf = area_leaf_of(sp, height),
                 mrp = root_prop(sp, height)) {
  p <- sp$p
  sp$l$set_physiology(area_leaf, mrp, p$rho, p$a_bio, 0.5 * 1800, psi, soil_depth,
                      p$K_s * p$theta / (height * sp$eta_c), 1, 40,
                      p$theta * height * sp$eta_c, 25, 21, 100.5)
}
solve_at <- function(sp, height, psi) {
  phys(sp, height, psi); sp$l$find_root_collar_psi(); -sp$l$root_collar_psi_
}
# R at a GIVEN collar magnitude, caches refreshed by evaluate_root_collar_psi first.
R_frozen <- function(sp, height, psi, p0, area_leaf = area_leaf_of(sp, height),
                     mrp = root_prop(sp, height), p_eval = p0) {
  phys(sp, height, psi, area_leaf, mrp)
  sp$l$evaluate_root_collar_psi(p0)
  tryCatch(sp$l$dprofit_droot_collar_psi(p_eval), error = function(e) NA_real_)
}
# E_up at SIGNED collar r, both arguments in the signed convention.
Eup <- function(sp, height, psi, p0, r, area_leaf = area_leaf_of(sp, height),
                mrp = root_prop(sp, height)) {
  phys(sp, height, psi, area_leaf, mrp)
  sp$l$evaluate_root_collar_psi(p0)
  sp$l$E_from_Soil_to_Root_Collar(r, -psi)
  sp$l$E_up_
}

# dR/d(param) and the two waist basis values, for one perturbation direction.
# `set` returns the (psi, area_leaf, mrp) triple for a signed step.
waist_row <- function(sp, height, p0, set, h, hr) {
  a <- set(+1); b <- set(-1)
  dR <- (R_frozen(sp, height, a$psi, p0, a$al, a$mrp) -
         R_frozen(sp, height, b$psi, p0, b$al, b$mrp)) / (2 * h)
  ea <- Eup(sp, height, a$psi, p0, -p0, a$al, a$mrp)
  eb <- Eup(sp, height, b$psi, p0, -p0, b$al, b$mrp)
  dE <- (ea - eb) / (2 * h)
  # d/d(param) of (dE_up/dr), r the SIGNED collar potential
  ga <- (Eup(sp, height, a$psi, p0, -p0 + hr, a$al, a$mrp) -
         Eup(sp, height, a$psi, p0, -p0 - hr, a$al, a$mrp)) / (2 * hr)
  gb <- (Eup(sp, height, b$psi, p0, -p0 + hr, b$al, b$mrp) -
         Eup(sp, height, b$psi, p0, -p0 - hr, b$al, b$mrp)) / (2 * hr)
  c(dR = dR, dE = dE, dEr = (ga - gb) / (2 * h))
}

fitab <- function(M) {                       # M: rows of (dR, dE, dEr)
  keep <- apply(is.finite(M), 1, all) & (abs(M[, "dE"]) + abs(M[, "dEr"]) > 0)
  if (sum(keep) < 3) return(NULL)
  X <- M[keep, c("dE", "dEr"), drop = FALSE]; y <- M[keep, "dR"]
  co <- tryCatch(qr.solve(X, y), error = function(e) NULL); if (is.null(co)) return(NULL)
  pred <- X %*% co
  sv <- svd(scale(X, center = FALSE, scale = TRUE))$d
  list(a = co[1], b = co[2], n = sum(keep), dof = sum(keep) - 2,
       resid = sqrt(sum((y - pred)^2)) / max(sqrt(sum(y^2)), 1e-300),
       cond = if (min(sv) > 0) max(sv) / min(sv) else Inf)
}

species <- list(A = make_species(),
                B = make_species(list(lma = s0$pars$lma * 1.8,
                                      vcmax_25 = s0$pars$vcmax_25 * 0.7)))
states <- list(list(h = 2.0,  ps = 0.05, tag = "sapling, wet"),
               list(h = 8.0,  ps = 0.17, tag = "tree, dry end"),
               list(h = 17.9, ps = 0.17, tag = "canopy max, dry end"))

cat(sprintf("develop build, %d soil layers (%.3f m each), GSS_tol_abs 1e-10\n",
            n_layers, 1.5 / n_layers))
cat("species A = TF24_Strategy() defaults; B = lma x1.8, vcmax_25 x0.7\n\n")

## ---- T1/T2/T3/T6 ----------------------------------------------------------
cat("=== T1  the waist at 20 layers: dR/dpsi in span{dE_up/dpsi, d(dE_up/dr)/dpsi} ===\n")
cat("=== T2  the same (a,b) must predict the root-mass and area_leaf rows ===\n")
cat("=== T3  b against its closed form; T6 per species ===\n\n")
cat(sprintf("%-3s %-22s %6s %5s %11s %8s | %10s %10s | %9s %9s %8s\n",
            "sp", "state", "nfit", "dof", "resid/norm", "cond",
            "pred mrp", "pred a_l", "b fit", "b closed", "b err"))
store <- list()
for (snm in names(species)) {
  sp <- species[[snm]]
  for (st in states) {
    psi <- rep(st$ps, n_layers); h <- st$h
    p0 <- solve_at(sp, h, psi)
    hp <- 1e-6; hr <- 1e-5 * p0
    al0 <- area_leaf_of(sp, h); mrp0 <- root_prop(sp, h)

    # --- psi family
    Mp <- t(vapply(seq_len(n_layers), function(i)
      waist_row(sp, h, p0, function(sg) {
        q <- psi; q[i] <- q[i] + sg * hp; list(psi = q, al = al0, mrp = mrp0) }, hp, hr),
      numeric(3)))
    colnames(Mp) <- c("dR", "dE", "dEr")
    f <- fitab(Mp)

    # --- root-mass family, PREDICTED with the psi fit
    live <- which(mrp0 > 0)
    Mm <- t(vapply(live, function(i) {
      hm <- 1e-6 * mrp0[i]
      waist_row(sp, h, p0, function(sg) {
        m <- mrp0; m[i] <- m[i] + sg * hm; list(psi = psi, al = al0, mrp = m) }, hm, hr)
    }, numeric(3)))
    colnames(Mm) <- c("dR", "dE", "dEr")
    predm <- Mm[, "dE"] * f$a + Mm[, "dEr"] * f$b
    errm <- sqrt(sum((Mm[, "dR"] - predm)^2)) / max(sqrt(sum(Mm[, "dR"]^2)), 1e-300)

    # --- area_leaf, one direction, also predicted
    ha <- 1e-6 * al0
    va <- waist_row(sp, h, p0, function(sg)
      list(psi = psi, al = al0 + sg * ha, mrp = mrp0), ha, hr)
    preda <- va["dE"] * f$a + va["dEr"] * f$b
    erra <- abs(va["dR"] - preda) / max(abs(va["dR"]), 1e-300)

    # --- T3: b from R's own intermediates
    phys(sp, h, psi); sp$l$evaluate_root_collar_psi(p0)
    ps <- sp$l$opt_psi_stem_; ci <- sp$l$ci_
    kap <- sp$l$leaf_specific_conductance_max_
    dd <- 1e-6
    Ap  <- (sp$l$assim_colimited(ci + dd) - sp$l$assim_colimited(ci - dd)) / (2 * dd)
    dci <- (sp$l$psi_stem_to_ci(ps + dd, p0) - sp$l$psi_stem_to_ci(ps - dd, p0)) / (2 * dd)
    phys(sp, h, psi); sp$l$evaluate_root_collar_psi(p0)
    Cp  <- (sp$l$hydraulic_cost_TF(ps + dd) - sp$l$hydraulic_cost_TF(ps - dd)) / (2 * dd)
    E0  <- Eup(sp, h, psi, p0, -p0)
    dE_ <- 1e-6 * max(abs(E0), 1e-6)
    Pk  <- (sp$l$transpiration_to_psi_stem(E0 + dE_, -p0) -
            sp$l$transpiration_to_psi_stem(E0 - dE_, -p0)) / (2 * dE_)   # = P'/kappa
    b_cl <- -(Ap * dci - Cp) * Pk
    cat(sprintf("%-3s %-22s %6d %5d %11.3g %8.4g | %10.3g %10.3g | %9.5g %9.5g %7.2f%%\n",
                snm, st$tag, f$n, f$dof, f$resid, f$cond, errm, erra,
                f$b, b_cl, 100 * abs(f$b - b_cl) / max(abs(b_cl), 1e-300)))
    store[[paste(snm, st$tag)]] <- list(sp = snm, a = f$a, b = f$b, p0 = p0, kap = kap)
  }
}

cat("\nfitted coefficients per species (they should differ -- the leaf differs):\n")
for (k in names(store)) with(store[[k]],
  cat(sprintf("  %-28s a = %12.5g   b = %12.5g   kappa = %10.4g\n", k, a, b, kap)))

## ---- T4 -------------------------------------------------------------------
cat("\n=== T4  the disequilibrium coordinate delta = p - psi_1 ===\n")
cat("truth    = (whole-solve p*(psi_1+h) - p*(psi_1-h))/2h  -  1\n")
cat("split    = -dR/dpsi_1/Pi_pp - 1, the two pieces computed separately\n")
cat("diagonal = -(dR along p and psi_1 TOGETHER)/Pi_pp, one difference\n\n")
cat(sprintf("%-3s %-22s %11s %11s %11s %9s %9s\n", "sp", "state",
            "truth", "split", "diagonal", "split%", "diag%"))
for (snm in names(species)) {
  sp <- species[[snm]]
  for (st in states) {
    psi <- rep(st$ps, n_layers); h <- st$h
    p0 <- solve_at(sp, h, psi); hp <- 1e-6; hr <- 1e-5 * p0
    hpp <- (R_frozen(sp, h, psi, p0, p_eval = p0 + hr) -
            R_frozen(sp, h, psi, p0, p_eval = p0 - hr)) / (2 * hr)
    bump <- function(sg) { q <- psi; q[1] <- q[1] + sg * hp; q }
    truth <- (solve_at(sp, h, bump(+1)) - solve_at(sp, h, bump(-1))) / (2 * hp) - 1
    dR1 <- (R_frozen(sp, h, bump(+1), p0) - R_frozen(sp, h, bump(-1), p0)) / (2 * hp)
    split <- -dR1 / hpp - 1
    # diagonal: move psi_1 and the evaluation point together, so the
    # disequilibrium is held fixed and the sum is one difference
    dg <- (R_frozen(sp, h, bump(+1), p0, p_eval = p0 + hp) -
           R_frozen(sp, h, bump(-1), p0, p_eval = p0 - hp)) / (2 * hp)
    diag_ <- -dg / hpp
    cat(sprintf("%-3s %-22s %11.4g %11.4g %11.4g %8.2f%% %8.2f%%\n", snm, st$tag,
                truth, split, diag_,
                100 * abs(split - truth) / max(abs(truth), 1e-300),
                100 * abs(diag_ - truth) / max(abs(truth), 1e-300)))
  }
}

## ---- T5 -------------------------------------------------------------------
cat("\n=== T5a  the seedling, by layer ===\n")
sp <- species$A; hs <- 0.4; psi <- rep(0.05, n_layers)
p0 <- solve_at(sp, hs, psi)
cat(sprintf("height %.2f, rooting depth %.2f m, layer thickness %.3f m, p* %.5f\n",
            hs, min(hs, 1.5), 1.5 / n_layers, p0))
mrp0 <- root_prop(sp, hs); al0 <- area_leaf_of(sp, hs)
phys(sp, hs, psi); sp$l$evaluate_root_collar_psi(p0)
cat(sprintf("max_soil_layer = %d of %d;  layers with root mass > 0 = %d\n",
            sp$l$max_soil_layer, n_layers, sum(mrp0 > 0)))
prods <- lapply(c(0.5, 1.0, 2.0), function(f) {
  phys(sp, hs, psi, area_leaf = al0 * f); sp$l$evaluate_root_collar_psi(p0)
  sp$l$E_from_Soil_to_Root_Collar(-p0, -psi)
  sp$l$soil_consumption_ * (al0 * f)
})
M <- do.call(rbind, prods)
cat(sprintf("%6s %14s %14s %14s %12s\n", "layer", "root mass", "E_i*a (0.5x)",
            "E_i*a (2x)", "rel drift"))
for (i in seq_len(n_layers)) {
  v <- M[, i]
  if (all(v == 0)) next
  cat(sprintf("%6d %14.6g %14.6g %14.6g %12.3g\n", i, mrp0[i], v[1], v[3],
              (max(v) - min(v)) / max(abs(v))))
}
cat("\n=== T5b  R's undeclared input ===\n")
psi2 <- psi; psi2[1] <- psi2[1] * 1.5
phys(sp, hs, psi); sp$l$find_root_collar_psi(); pb <- -sp$l$root_collar_psi_
phys(sp, hs, psi2)                                  # soil changed, caches NOT refreshed
stale <- tryCatch(sp$l$dprofit_droot_collar_psi(pb), error = function(e) NA)
phys(sp, hs, psi2); sp$l$evaluate_root_collar_psi(pb)
fresh <- tryCatch(sp$l$dprofit_droot_collar_psi(pb), error = function(e) NA)
cat(sprintf("R after set_physiology only            : %.8g\n", stale))
cat(sprintf("R after set_physiology + evaluate_...  : %.8g\n", fresh))
cat(sprintf("relative difference                    : %.4g\n",
            abs(stale - fresh) / max(abs(fresh), 1e-300)))
