# Pi_pp: the curvature of carbon profit at the collar operating point.
#
# Report 06's reverse pass turns the five flux adjoints into one scalar and then
# divides by Pi_pp = d2(profit)/dp2. Nothing computes it; the value the design
# currently rests on (~ -1.1e5) is a ratio of two other measurements. Its failure
# mode is Pi_pp -> 0, a fold, where the one-line solve mu = -s/Pi_pp needs a
# bracketed fallback instead.
#
# Measured as a central difference of develop's own ANALYTIC first derivative
# (Leaf::dprofit_droot_collar_psi), not a second difference of the value -- one
# differencing step instead of two. Each point is reported at three step sizes so
# the number is the geometry rather than the step.
#
# DOMAIN. Swept over the whole feasible domain of the argmax, not the default
# driver's slice. The default driver holds soil moisture in [0.214, 0.311], i.e.
# psi_soil 0.015-0.17 MPa; the committed stress banks (scripts/tf24-benchmarks/
# data/*.rds: extended_drought, drydown, whiplash, ...) take it far drier. Rather
# than sample one bank, this sweeps psi_soil from the default's wet end down to
# the stem's psi_crit, beyond which every layer is drier than the stem can pull
# and prepare_collar_solve shuts the leaf down -- so there is no argmax to have
# curvature. That brackets anything any driver can reach.
#
# Three axes, because Pi_pp is a property of the operating point and the
# operating point moves with all three:
#   psi_soil     wet -> the shutdown boundary
#   height       seedling -> canopy tree (sets area_leaf and the stem conductance)
#   profile      uniform, and the wet-deep/dry-shallow gradients transients make
#
#   Rscript scripts/curvature_probe.R [n_layers]

suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE)
})
n_layers <- as.integer(commandArgs(TRUE)[1]); if (is.na(n_layers)) n_layers <- 5L

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

# Solve for p*, then difference the analytic gradient about it. Returns NA when
# the leaf shuts down (no argmax) or the gradient is unavailable.
curvature <- function(l, height, psi_soil, h_rel) {
  area_leaf <- (height / p$a_l1)^(1 / p$a_l2)
  ok <- tryCatch({
    l$set_physiology(area_leaf, root_prop(height), p$rho, p$a_bio, 0.5 * 1800,
                     psi_soil, soil_depth, p$K_s * p$theta / (height * eta_c),
                     1, 40, p$theta * height * eta_c, 25, 21, 100.5)
    l$find_root_collar_psi(); TRUE
  }, error = function(e) FALSE)
  if (!ok) return(list(pstar = NA, g = NA, hpp = NA))
  pstar <- -l$root_collar_psi_
  # the shutdown exits pin opt_psi_stem_ at psi_crit; no interior argmax there
  shut <- abs(l$opt_psi_stem_ - p$psi_crit) < 1e-12
  if (shut || !is.finite(pstar) || pstar <= 0) return(list(pstar = pstar, g = NA, hpp = NA))
  h <- h_rel * max(pstar, 1e-3)
  gp <- tryCatch(l$dprofit_droot_collar_psi(pstar + h), error = function(e) NA)
  gm <- tryCatch(l$dprofit_droot_collar_psi(pstar - h), error = function(e) NA)
  g0 <- tryCatch(l$dprofit_droot_collar_psi(pstar),     error = function(e) NA)
  l$evaluate_root_collar_psi(pstar)   # leave the leaf at its operating point
  list(pstar = pstar, g = g0, hpp = (gp - gm) / (2 * h))
}

heights  <- c(0.4, 2.0, 8.0, 17.9)          # seedling -> the production max (17.94 m)
psi_wet  <- c(0.015, 0.05, 0.17)            # the default driver's whole range
psi_dry  <- c(0.5, 1.0, 1.5, 1.75, 1.83)    # beyond it, up to psi_crit
psi_all  <- c(psi_wet, psi_dry)
steps    <- c(1e-3, 1e-4, 1e-5)

cat(sprintf("develop build, %d soil layers, GSS_tol_abs 1e-10 (geometry, not search)\n",
            n_layers))
cat(sprintf("stem psi_crit = %.6f MPa -- at or beyond this the leaf shuts down\n",
            p$psi_crit))
cat(sprintf("default driver reaches psi_soil %.3f-%.3f MPa; the stress banks go drier\n\n",
            min(psi_wet), max(psi_wet)))

l <- new_leaf(1e-10)
rows <- list()
cat("=== uniform profile ===\n")
cat(sprintf("%7s %8s %10s %12s %12s %12s %12s %9s\n",
            "height", "psi_s", "p*", "dPi/dp", "Pi_pp(1e-3)", "(1e-4)", "(1e-5)", "digits"))
for (hh in heights) for (ps in psi_all) {
  r <- lapply(steps, function(hr) curvature(l, hh, rep(ps, n_layers), hr))
  v <- vapply(r, function(x) x$hpp, 1)
  # how many leading digits the three steps agree on
  dg <- if (all(is.finite(v))) {
    sp <- max(abs(v)); rng <- max(v) - min(v)
    if (rng == 0) 16L else max(0L, as.integer(floor(-log10(rng / sp))))
  } else NA_integer_
  cat(sprintf("%7.2f %8.3f %10.5f %12.4g %12.5g %12.5g %12.5g %9s\n",
              hh, ps, r[[1]]$pstar, r[[1]]$g, v[1], v[2], v[3],
              ifelse(is.na(dg), "-", dg)))
  rows[[length(rows) + 1]] <- data.frame(profile = "uniform", height = hh, psi = ps,
                                         pstar = r[[1]]$pstar, g = r[[1]]$g,
                                         hpp = v[2], digits = dg)
}

cat("\n=== heterogeneous profiles (what a transient makes) ===\n")
cat(sprintf("%7s %-22s %10s %12s %12s %9s\n",
            "height", "profile", "p*", "dPi/dp", "Pi_pp(1e-4)", "digits"))
profiles <- list(
  "dry top / wet bottom" = seq(1.5, 0.05, length.out = n_layers),
  "wet top / dry bottom" = seq(0.05, 1.5, length.out = n_layers),
  "one wet layer, rest dry" = c(0.05, rep(1.6, n_layers - 1)),
  "one dry layer, rest wet" = c(1.8, rep(0.05, n_layers - 1)),
  "all near shutdown"      = rep(1.80, n_layers))
for (hh in heights) for (nm in names(profiles)) {
  r <- lapply(steps, function(hr) curvature(l, hh, profiles[[nm]], hr))
  v <- vapply(r, function(x) x$hpp, 1)
  dg <- if (all(is.finite(v))) {
    sp <- max(abs(v)); rng <- max(v) - min(v)
    if (rng == 0) 16L else max(0L, as.integer(floor(-log10(rng / sp))))
  } else NA_integer_
  cat(sprintf("%7.2f %-22s %10.5f %12.4g %12.5g %9s\n",
              hh, nm, r[[1]]$pstar, r[[1]]$g, v[2], ifelse(is.na(dg), "-", dg)))
  rows[[length(rows) + 1]] <- data.frame(profile = nm, height = hh, psi = NA,
                                         pstar = r[[1]]$pstar, g = r[[1]]$g,
                                         hpp = v[2], digits = dg)
}

d <- do.call(rbind, rows)
ok <- d[is.finite(d$hpp), ]
cat("\n=== verdict ===\n")
cat(sprintf("points swept                 : %d\n", nrow(d)))
cat(sprintf("interior argmax found        : %d  (%d shut down / unavailable)\n",
            nrow(ok), nrow(d) - nrow(ok)))
if (nrow(ok)) {
  cat(sprintf("Pi_pp sign                   : %d negative, %d positive, %d zero\n",
              sum(ok$hpp < 0), sum(ok$hpp > 0), sum(ok$hpp == 0)))
  cat(sprintf("|Pi_pp|  min / median / max  : %.4g / %.4g / %.4g\n",
              min(abs(ok$hpp)), median(abs(ok$hpp)), max(abs(ok$hpp))))
  w <- ok[which.min(abs(ok$hpp)), ]
  cat(sprintf("closest to a fold            : %s, height %.2f, psi %s -> Pi_pp = %.5g\n",
              w$profile, w$height, ifelse(is.na(w$psi), "-", sprintf("%.3f", w$psi)), w$hpp))
  cat(sprintf("the design's inferred value  : -1.1e5;  measured median %.4g\n",
              median(ok$hpp)))
  # the quantity the one-line solve actually needs to be bounded
  cat(sprintf("worst 1/|Pi_pp| (amplification of the flux adjoint) : %.4g\n",
              1 / min(abs(ok$hpp))))
}
saveRDS(d, "/tmp/curvature_probe.rds")

# The rows split into two regimes and they must not be pooled: where |dPi/dp| is
# at the solver's floor the point is a genuine stationary interior maximum and
# Pi_pp is the curvature report 06 divides by; where it is O(1) the point is
# PINNED at a bound, so the second derivative is a local slope change, not the
# denominator of a stationarity solve.
stat <- ok[abs(ok$g) < 1e-6, ]; pin <- ok[abs(ok$g) >= 1e-6, ]
cat("\n=== the two regimes, kept apart ===\n")
cat(sprintf("stationary (|dPi/dp| < 1e-6) : %2d of %d  -- Pi_pp %.4g .. %.4g, median %.4g\n",
            nrow(stat), nrow(ok), min(stat$hpp), max(stat$hpp), median(stat$hpp)))
cat(sprintf("pinned at a bound            : %2d of %d  -- |dPi/dp| %.4g .. %.4g\n",
            nrow(pin), nrow(ok), min(abs(pin$g)), max(abs(pin$g))))
if (nrow(pin)) {
  cat("pinned rows, by state:\n")
  for (i in seq_len(nrow(pin))) cat(sprintf("   %-22s height %5.2f  psi %-6s |dPi/dp| = %.4g\n",
      pin$profile[i], pin$height[i],
      ifelse(is.na(pin$psi[i]), "-", sprintf("%.3f", pin$psi[i])), abs(pin$g[i])))
  cat(sprintf("driest stationary state      : psi_soil %.3f MPa\n",
              max(stat$psi[!is.na(stat$psi)])))
}
