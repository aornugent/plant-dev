# Which route is wrong: the uniform difference of R, or the whole-solve response?
#
# scripts/leaf_translation_R.R's B1 found D by a diagonal difference of R
# disagreeing with (1 - dp*/dpsi_unif)*Pi_pp by 3.18-29.55%, and IDENTICALLY at
# every step from 1e-6 to 1e-2 -- so it is not a step-size artifact. The identity
# itself is not in doubt:
#
#     R(p*(psi), psi) = 0  =>  dp*/dd = -(sum_i dR/dpsi_i)/Pi_pp
#                         =>  D = Pi_pp + sum_i dR/dpsi_i = Pi_pp (1 - dp*/dd)
#
# so one of the two measurements is. scripts/leaf_waist.R's L3 already validated
# the PER-LAYER implicit-function route against the whole solve to 0.45-7.66%, so
# the discriminating test is whether the sum of twenty per-layer derivatives
# equals the single uniform-direction derivative:
#
#   C1  sum_i dR/dpsi_i, twenty separate one-layer differences
#   C2  dR/dpsi_unif, one difference with all layers moved together
#   C3  dp*/dpsi_unif from the whole solve, swept over step sizes
#   C4  the same by the IFT from C1 and from C2
#
# If C1 == C2 the R side is sound and C3 is suspect. If C1 != C2 the uniform
# perturbation is doing something a single-layer one does not.
#
# CONFIGURATION as scripts/leaf_translation.R: develop @141dc8df,
# TF24_Strategy() defaults, 20 layers over 1.5 m, GSS_tol_abs 1e-10.
#
#   Rscript scripts/leaf_uniform_check.R [n_layers]
#
# RESULTS, develop @141dc8df, 20 layers. The R side was right and the REFERENCE
# was wrong, at both A3 and B1.
#
#   C1 == C2 to five digits (ratio 1.0000 at all three states). Twenty per-layer
#   derivatives of R sum exactly to the uniform-direction derivative, so R's psi
#   gradient is sound and additive.
#
#   C3 the whole-solve response is NOT converged at h = 1e-6, which is what A3 and
#   B1 used as their reference:
#        sapling  1.0556891 (1e-7)  0.9074431 (1e-6)  0.9344321 (1e-5)  0.9351877 (1e-4)
#        tree     0.8874038         0.9591587         0.9587408         0.9578152
#        canopy   0.9832991         0.9548161         0.9626863         0.9619033
#
#   C4 the IFT from C1/C2 gives 0.9347920, 0.9578602, 0.9619823 -- matching the
#   SETTLED whole-solve values at 1e-5/1e-4 to 1e-4 or better, and disagreeing
#   with the h=1e-6 value the earlier probes trusted.
#
# So the defect is 0.0652, 0.0421, 0.0380 (amplification 15.3x, 23.7x, 26.3x) from
# the R route, and the whole-solve difference at 1e-6 gave 0.0926 for the sapling
# -- wrong by 40%. That IS the amplification, demonstrated: dp*/dpsi is fine to
# four digits either way, but 1 - dp*/dpsi is 0.04-0.065, so the solve difference
# cannot measure the defect while R's derivatives can.
#
# CONSEQUENCE FOR VERIFICATION. A re-run finite difference is the amplified route.
# Any V-level check of the flux derivative against one is limited by this, not by
# the scheme under test.

suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE)
})
n_layers <- as.integer(commandArgs(TRUE)[1]); if (is.na(n_layers)) n_layers <- 20L

s0 <- TF24_Strategy(); p <- s0$pars
soil_depth <- (1:n_layers) * (1.5 / n_layers)
eta_c <- 1 - 2 / (1 + p$eta) + 1 / (1 + 2 * p$eta)
root_scale <- 83.26 * 0.5
root_b <- 3.898245; root_c <- 2.680147
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
phys <- function(h, psi) l$set_physiology((h / p$a_l1)^(1 / p$a_l2), root_prop(h),
  p$rho, p$a_bio, 0.5 * 1800, psi, soil_depth,
  p$K_s * p$theta / (h * eta_c), 1, 40, p$theta * h * eta_c, 25, 21, 100.5)
solve_at <- function(h, psi) { phys(h, psi); l$find_root_collar_psi(); -l$root_collar_psi_ }
R_at <- function(h, psi, p0, pe) { phys(h, psi); invisible(l$evaluate_root_collar_psi(p0))
  tryCatch(l$dprofit_droot_collar_psi(pe), error = function(e) NA_real_) }

states <- list(list(h = 2.0, ps = 0.05, tag = "sapling, wet"),
               list(h = 8.0, ps = 0.17, tag = "tree, dry end"),
               list(h = 17.9, ps = 0.17, tag = "canopy max, dry end"))

cat(sprintf("develop build, %d layers, GSS_tol_abs 1e-10\n\n", n_layers))
cat(sprintf("%-22s %10s %13s %13s %8s\n", "state", "Pi_pp",
            "C1 sum/layer", "C2 uniform", "C1/C2"))
res <- list()
for (st in states) {
  psi <- rep(st$ps, n_layers); h <- st$h
  p0 <- solve_at(h, psi); hr <- 1e-5 * p0; hp <- 1e-6
  hpp <- (R_at(h, psi, p0, p0 + hr) - R_at(h, psi, p0, p0 - hr)) / (2 * hr)
  per <- vapply(seq_len(n_layers), function(i) {
    a <- psi; a[i] <- a[i] + hp; b <- psi; b[i] <- b[i] - hp
    (R_at(h, a, p0, p0) - R_at(h, b, p0, p0)) / (2 * hp) }, 1)
  C1 <- sum(per)
  C2 <- (R_at(h, psi + hp, p0, p0) - R_at(h, psi - hp, p0, p0)) / (2 * hp)
  cat(sprintf("%-22s %10.4g %13.5g %13.5g %8.4f\n", st$tag, hpp, C1, C2, C1 / C2))
  res[[st$tag]] <- list(h = h, psi = psi, p0 = p0, hpp = hpp, C1 = C1, C2 = C2)
}

cat("\nC3  dp*/dpsi_unif from the whole solve, by step size\n")
cat(sprintf("%-22s %11s %11s %11s %11s\n", "state", "h=1e-7", "1e-6", "1e-5", "1e-4"))
for (st in states) {
  r <- res[[st$tag]]
  v <- vapply(c(1e-7, 1e-6, 1e-5, 1e-4), function(hh)
    (solve_at(r$h, r$psi + hh) - solve_at(r$h, r$psi - hh)) / (2 * hh), 1)
  cat(sprintf("%-22s %11.7f %11.7f %11.7f %11.7f\n", st$tag, v[1], v[2], v[3], v[4]))
  res[[st$tag]]$dps <- v[2]
}

cat("\nC4  dp*/dpsi_unif: whole solve vs the IFT from C1 and from C2\n")
cat(sprintf("%-22s %11s %11s %11s\n", "state", "solve", "IFT(C1)", "IFT(C2)"))
for (st in states) {
  r <- res[[st$tag]]
  cat(sprintf("%-22s %11.7f %11.7f %11.7f\n", st$tag, r$dps,
              -r$C1 / r$hpp, -r$C2 / r$hpp))
}
