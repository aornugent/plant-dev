# Recovering `a` = dR/dE_up: how cleanly does one layer identify it?
#
# The waist is dR/du = a*dE_up/du + b*d(dE_up/dr)/du. `b` is closed form in
# quantities R already computes (confirmed to 0.16-1.04%, scripts/leaf_waist3.R).
# `a` is the only coefficient needing second derivatives, and because the psi
# family is nearly rank one -- s2/s1 = 1.3e-05 to 2.0e-05 -- the b channel is a
# millionth of the psi response there. So for a single layer
#
#     a  ~=  (dR/dpsi_i) / (dE_up/dpsi_i)
#
# to about that accuracy. This measures the spread of that ratio across layers: if
# it is flat, one layer's pair of R evaluations recovers `a`, and the spread across
# layers is a free internal consistency check with n samples rather than one.
#
# CONFIGURATION as scripts/leaf_translation.R: develop @141dc8df,
# TF24_Strategy() defaults, 20 layers over 1.5 m, GSS_tol_abs 1e-10.
#
#   Rscript scripts/leaf_recover_a.R [n_layers]
#
# RESULTS, develop @141dc8df, 20 layers. Recovery is essentially exact.
#   a from a SINGLE layer, spread across all twenty:
#     sapling  -178520   spread 0.00129%
#     tree     -910767   spread 0.00036%
#     canopy   -2.52392e+06  spread 8.4e-05%
#   and -910767 reproduces scripts/leaf_waist3.R's joint-fit value exactly.
#
# So one layer's pair of R evaluations gives `a` to ~1e-05 relative, and running it
# on k layers is a free k-sample consistency check. DERIVE is feasible but needs
# A'', C'', P'', S'' -- two of them spline second derivatives requiring a new
# Interpolator accessor -- feeding two implicit second derivatives (ci_ss, ci_sci)
# through a ten-term chain rule, to save two function evaluations on a pass that
# only runs when a gradient is asked for. Recover.

suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE)
})
n_layers <- as.integer(commandArgs(TRUE)[1]); if (is.na(n_layers)) n_layers <- 20L
s0 <- TF24_Strategy(); p <- s0$pars
soil_depth <- (1:n_layers) * (1.5 / n_layers)
eta_c <- 1 - 2 / (1 + p$eta) + 1 / (1 + 2 * p$eta)
root_scale <- 83.26 * 0.5; root_b <- 3.898245; root_c <- 2.680147
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
R_at <- function(h, psi, p0) { phys(h, psi); invisible(l$evaluate_root_collar_psi(p0))
  tryCatch(l$dprofit_droot_collar_psi(p0), error = function(e) NA_real_) }
Eup_at <- function(h, psi, p0) { phys(h, psi); invisible(l$evaluate_root_collar_psi(p0))
  l$E_from_Soil_to_Root_Collar(-p0, -psi); l$E_up_ }

states <- list(list(h = 2.0, ps = 0.05, tag = "sapling, wet"),
               list(h = 8.0, ps = 0.17, tag = "tree, dry end"),
               list(h = 17.9, ps = 0.17, tag = "canopy max, dry end"))
cat(sprintf("develop build, %d layers, GSS_tol_abs 1e-10\n\n", n_layers))
cat(sprintf("%-22s %13s %13s %13s %11s %9s\n", "state", "a (layer 1)",
            "a (median)", "a (layer n)", "spread", "n used"))
for (st in states) {
  psi <- rep(st$ps, n_layers); h <- st$h
  p0 <- solve_at(h, psi); hp <- 1e-6
  ai <- vapply(seq_len(n_layers), function(i) {
    a <- psi; a[i] <- a[i] + hp; b <- psi; b[i] <- b[i] - hp
    dR <- (R_at(h, a, p0) - R_at(h, b, p0)) / (2 * hp)
    dE <- (Eup_at(h, a, p0) - Eup_at(h, b, p0)) / (2 * hp)
    dR / dE }, 1)
  ok <- ai[is.finite(ai)]
  cat(sprintf("%-22s %13.6g %13.6g %13.6g %10.3g%% %9d\n", st$tag, ai[1],
              median(ok), ai[n_layers],
              100 * (max(ok) - min(ok)) / abs(median(ok)), length(ok)))
}
