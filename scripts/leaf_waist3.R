# Resolve T2/T3: is the waist real, or was the psi-family fit degenerate?
#
# scripts/leaf_waist2.R found, at 20 layers and 18 residual degrees of freedom,
# that dR/dpsi lies in span{dE_up/dpsi, d(dE_up/dr)/dpsi} to 1e-08 - 1e-07. But
# the SAME fitted (a, b) mispredicted the root-mass and area_leaf rows by 8-36%,
# and the fitted b disagreed with its closed form by ~100%. Those three results
# cannot all mean what they appear to.
#
# The hypothesis: the psi family is nearly RANK ONE -- dE_up/dpsi_i and
# d(dE_up/dr)/dpsi_i are nearly proportional across layers -- so the fit absorbs
# everything into `a`, leaves `b` unidentified, and the tight residual says only
# "rank <= 2", not "these are the structural coefficients". A family whose two
# vectors sit in a different proportion then fails to be predicted.
#
# Three diagnostics settle it:
#   D1  unscaled singular values of [dE, dEr] PER FAMILY. If s2/s1 is tiny for
#       psi, the psi fit cannot identify b, whatever its residual.
#   D2  the two contributions at the closed-form b: |a*dE| against |b_cl*dEr|.
#       If the second is negligible for psi, same conclusion.
#   D3  a JOINT fit over psi + root mass + area_leaf. If the waist is real, one
#       (a, b) fits all three with a small residual AND b matches b_closed. If
#       the joint residual is large, the waist does not carry across families and
#       the two-scalar claim is false.
#
# CONFIGURATION as scripts/leaf_waist2.R: develop @141dc8df, TF24_Strategy()
# defaults, 20 soil layers over 1.5 m, GSS_tol_abs 1e-10.
#
#   Rscript scripts/leaf_waist3.R [n_layers]
#
# RESULTS, develop @141dc8df, 20 layers. The hypothesis is confirmed and the
# waist is real.
#
#   D1  the psi family is nearly RANK ONE. Unscaled s2/s1 = 1.97e-05 (sapling),
#       1.30e-05 (tree). The two basis vectors are nearly parallel over psi, so a
#       psi-only fit cannot identify the second coefficient however small its
#       residual. Root mass: 4.4e-03 and 8.8e-03 -- identifiable.
#   D2  at the closed-form b, |b*dEr| / |a*dE| is 5.2e-06 and 6.9e-07 for the psi
#       family, against 0.23 and 0.10 for root mass and area_leaf. So the second
#       channel is a millionth of the psi response and a tenth to a quarter of the
#       other two. That is why the psi fit is blind to it.
#   D3  JOINT fit over 41 directions (20 psi + 20 root masses + area_leaf), one
#       shared (a, b):
#              sapling  a = -178099   b = -28958.2   resid/norm = 9.18e-04
#              tree     a = -910767   b = -39354.4   resid/norm = 2.61e-04
#       and b agrees with its closed form to 1.04% and 0.16%. Pinning b at the
#       closed form and refitting a leaves the residual unchanged (9.24e-04,
#       2.63e-04), so the closed form is right.
#
# CONCLUSION. 2n+1 input directions reach the operating point through TWO scalars.
# `b` = -(A'*dci/dpsi_stem - C') * P'/kappa is closed form in intermediates R
# already computes. `a` = dR/dE_up is the only quantity needing second
# derivatives (A'', C'', P'') -- and because the psi family is rank one, one
# psi-direction difference identifies it to five figures, so it can be recovered
# at runtime instead. That is a real choice with numbers on both sides.

suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE)
})
n_layers <- as.integer(commandArgs(TRUE)[1]); if (is.na(n_layers)) n_layers <- 20L

s0 <- TF24_Strategy(); p <- s0$pars
soil_depth <- (1:n_layers) * (1.5 / n_layers)
eta_c <- 1 - 2 / (1 + p$eta) + 1 / (1 + 2 * p$eta)
root_scale <- 83.26 * 0.5
l <- Leaf(p$vcmax_25, p$c, p$b, p$psi_crit, 2.680147, 3.898245,
          3.898245 * log(1 / 0.05)^(1 / 2.680147), p$beta2, p$jmax_25, p$a,
          p$curv_fact_elec_trans, p$curv_fact_colim,
          1e-10, 100, 1e-6, 1000, p$g1_TF24, 3.4e2, 9.4e3)
l$initialize_integrator(21L, 1e-3)

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
area_leaf_of <- function(h) (h / p$a_l1)^(1 / p$a_l2)
phys <- function(height, psi, al = area_leaf_of(height), mrp = root_prop(height))
  l$set_physiology(al, mrp, p$rho, p$a_bio, 0.5 * 1800, psi, soil_depth,
                   p$K_s * p$theta / (height * eta_c), 1, 40,
                   p$theta * height * eta_c, 25, 21, 100.5)
solve_at <- function(height, psi) { phys(height, psi); l$find_root_collar_psi()
                                    -l$root_collar_psi_ }
R_frozen <- function(height, psi, p0, al, mrp, p_eval = p0) {
  phys(height, psi, al, mrp); invisible(l$evaluate_root_collar_psi(p0))
  tryCatch(l$dprofit_droot_collar_psi(p_eval), error = function(e) NA_real_)
}
Eup <- function(height, psi, p0, r, al, mrp) {
  phys(height, psi, al, mrp); invisible(l$evaluate_root_collar_psi(p0))
  l$E_from_Soil_to_Root_Collar(r, -psi); l$E_up_
}
row_of <- function(height, p0, set, h, hr) {
  a <- set(+1); b <- set(-1)
  dR <- (R_frozen(height, a$psi, p0, a$al, a$mrp) -
         R_frozen(height, b$psi, p0, b$al, b$mrp)) / (2 * h)
  dE <- (Eup(height, a$psi, p0, -p0, a$al, a$mrp) -
         Eup(height, b$psi, p0, -p0, b$al, b$mrp)) / (2 * h)
  ga <- (Eup(height, a$psi, p0, -p0 + hr, a$al, a$mrp) -
         Eup(height, a$psi, p0, -p0 - hr, a$al, a$mrp)) / (2 * hr)
  gb <- (Eup(height, b$psi, p0, -p0 + hr, b$al, b$mrp) -
         Eup(height, b$psi, p0, -p0 - hr, b$al, b$mrp)) / (2 * hr)
  c(dR = dR, dE = dE, dEr = (ga - gb) / (2 * h))
}
fitab <- function(M) {
  k <- apply(is.finite(M), 1, all) & (abs(M[, "dE"]) + abs(M[, "dEr"]) > 0)
  X <- M[k, c("dE", "dEr"), drop = FALSE]; y <- M[k, "dR"]
  co <- qr.solve(X, y); pred <- X %*% co
  list(a = co[1], b = co[2], n = sum(k),
       resid = sqrt(sum((y - pred)^2)) / max(sqrt(sum(y^2)), 1e-300))
}

states <- list(list(h = 2.0, ps = 0.05, tag = "sapling, wet"),
               list(h = 8.0, ps = 0.17, tag = "tree, dry end"))

cat(sprintf("develop build, %d layers, GSS_tol_abs 1e-10\n\n", n_layers))
for (st in states) {
  psi <- rep(st$ps, n_layers); h <- st$h
  p0 <- solve_at(h, psi); hp <- 1e-6; hr <- 1e-5 * p0
  al0 <- area_leaf_of(h); mrp0 <- root_prop(h); live <- which(mrp0 > 0)

  Mp <- t(vapply(seq_len(n_layers), function(i) row_of(h, p0, function(sg) {
    q <- psi; q[i] <- q[i] + sg * hp; list(psi = q, al = al0, mrp = mrp0) }, hp, hr),
    numeric(3)))
  Mm <- t(vapply(live, function(i) { hm <- 1e-6 * mrp0[i]
    row_of(h, p0, function(sg) { m <- mrp0; m[i] <- m[i] + sg * hm
      list(psi = psi, al = al0, mrp = m) }, hm, hr) }, numeric(3)))
  ha <- 1e-6 * al0
  Ma <- matrix(row_of(h, p0, function(sg)
    list(psi = psi, al = al0 + sg * ha, mrp = mrp0), ha, hr), nrow = 1)
  colnames(Mp) <- colnames(Mm) <- colnames(Ma) <- c("dR", "dE", "dEr")

  # closed-form b from R's own intermediates
  phys(h, psi); invisible(l$evaluate_root_collar_psi(p0))
  ps <- l$opt_psi_stem_; ci <- l$ci_; kap <- l$leaf_specific_conductance_max_
  dd <- 1e-6
  Ap  <- (l$assim_colimited(ci + dd) - l$assim_colimited(ci - dd)) / (2 * dd)
  dci <- (l$psi_stem_to_ci(ps + dd, p0) - l$psi_stem_to_ci(ps - dd, p0)) / (2 * dd)
  phys(h, psi); invisible(l$evaluate_root_collar_psi(p0))
  Cp  <- (l$hydraulic_cost_TF(ps + dd) - l$hydraulic_cost_TF(ps - dd)) / (2 * dd)
  E0  <- Eup(h, psi, p0, -p0, al0, mrp0); dE_ <- 1e-6 * max(abs(E0), 1e-6)
  Pk  <- (l$transpiration_to_psi_stem(E0 + dE_, -p0) -
          l$transpiration_to_psi_stem(E0 - dE_, -p0)) / (2 * dE_)
  b_cl <- -(Ap * dci - Cp) * Pk

  cat(sprintf("--- %s   p* = %.5f   kappa = %.5g   b_closed = %.6g\n",
              st$tag, p0, kap, b_cl))

  cat("\nD1  rank of [dE, dEr] per family, UNSCALED singular values\n")
  cat(sprintf("%-12s %5s %12s %12s %12s\n", "family", "n", "s1", "s2", "s2/s1"))
  for (nm in c("psi", "rootmass", "area_leaf")) {
    M <- switch(nm, psi = Mp, rootmass = Mm, area_leaf = Ma)
    X <- M[, c("dE", "dEr"), drop = FALSE]
    sv <- svd(X)$d; sv <- c(sv, 0)[1:2]
    cat(sprintf("%-12s %5d %12.4g %12.4g %12.3g\n", nm, nrow(M), sv[1], sv[2],
                sv[2] / max(sv[1], 1e-300)))
  }

  cat("\nD2  the two contributions at the closed-form b\n")
  cat(sprintf("%-12s %14s %14s %14s %10s\n", "family", "|dR|", "|a_fit*dE|",
              "|b_cl*dEr|", "2nd/1st"))
  fp <- fitab(Mp)
  for (nm in c("psi", "rootmass", "area_leaf")) {
    M <- switch(nm, psi = Mp, rootmass = Mm, area_leaf = Ma)
    n1 <- sqrt(sum((fp$a * M[, "dE"])^2)); n2 <- sqrt(sum((b_cl * M[, "dEr"])^2))
    cat(sprintf("%-12s %14.5g %14.5g %14.5g %10.3g\n", nm,
                sqrt(sum(M[, "dR"]^2)), n1, n2, n2 / max(n1, 1e-300)))
  }

  cat("\nD3  joint fit over all three families\n")
  J <- rbind(Mp, Mm, Ma); fj <- fitab(J)
  cat(sprintf("  joint:  n = %d   a = %.6g   b = %.6g   resid/norm = %.3g\n",
              fj$n, fj$a, fj$b, fj$resid))
  cat(sprintf("  b_joint vs b_closed: %.2f%% apart\n",
              100 * abs(fj$b - b_cl) / max(abs(b_cl), 1e-300)))
  # per-family residual under the JOINT coefficients
  for (nm in c("psi", "rootmass", "area_leaf")) {
    M <- switch(nm, psi = Mp, rootmass = Mm, area_leaf = Ma)
    pr <- M[, "dE"] * fj$a + M[, "dEr"] * fj$b
    cat(sprintf("  under joint (a,b): %-10s resid/norm = %.3g\n", nm,
                sqrt(sum((M[, "dR"] - pr)^2)) / max(sqrt(sum(M[, "dR"]^2)), 1e-300)))
  }
  # and with b PINNED to its closed form, a refitted
  a2 <- sum((J[, "dR"] - b_cl * J[, "dEr"]) * J[, "dE"]) / sum(J[, "dE"]^2)
  pr2 <- J[, "dE"] * a2 + J[, "dEr"] * b_cl
  cat(sprintf("  b pinned at closed form, a refit: a = %.6g  resid/norm = %.3g\n\n",
              a2, sqrt(sum((J[, "dR"] - pr2)^2)) / max(sqrt(sum(J[, "dR"]^2)), 1e-300)))
}
