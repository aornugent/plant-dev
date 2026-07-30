#   Rscript scripts/aux_round_trip.R
#
# M7, the leaf half. Is the leaf's operating point sufficient aux? The reverse
# pass rebuilds each stage's state, restores the aux, and re-evaluates the
# cohort block; that is only exact if every leaf output is a function of
# (set_physiology inputs, stored operating point) and of nothing else the
# forward solve left behind. Three questions:
#
#   A1  restore on the SAME leaf after an intervening solve at another state:
#       is every output bit-identical to the original solve?
#   A2  restore on a FRESH leaf: same test with no carried caches at all. A1
#       passing while A2 fails would mean a cache holds information the aux
#       does not, and set_ode_aux would be insufficient.
#   A3  is one output-setting evaluation at the stored point enough, or does
#       the golden-section search leave the leaf somewhere its own final
#       evaluation did not? evaluate_root_collar_psi(p*) is compared against
#       find_root_collar_psi() at the same state.
#
# CONFIGURATION. plant develop 141dc8df, odelia 854a8e18, built -O2 -DNDEBUG via
# pkgbuild::compile_dll(debug = FALSE). TF24_Strategy() defaults, 5 soil layers
# over 1.5 m, radiation 0.5*1800, atm_vpd 1, ca 40, leaf_temp 25, o2 21, atm
# 100.5, integrator (21, 1e-3), GSS_tol_abs 1e-3 (production). States and the
# set_physiology assembly are identical to scripts/leaf_bundle.R so the numbers
# compose. Ten outputs are compared: profit_, opt_psi_stem_, root_collar_psi_,
# ci_, stom_cond_CO2_, assim_colimited_, transpiration_, hydraulic_cost_, E_up_,
# and the five soil_consumption_ entries.
#
# The soil half is at the foot of the file and costs a production run (125 s here):
#   A4  the positivity guard's inputs, and its incidence. rate_i reads state(i),
#       state(i-1) through the drainage cascade, rainfall(time) and
#       resource_depletion[i] -- so the fired set is a function of the stage state,
#       the per-layer uptake and time, and of no other member. What decides whether
#       the sweep's zeroed rows are ever exercised is how close theta gets to
#       soil_moist_residual.
#
# RESULTS.
#   A1  bit-identical at 9 of 9 states: restoring set_physiology's inputs and
#       calling evaluate_root_collar_psi at the stored operating point reproduces all
#       14 outputs exactly after an intervening solve elsewhere.
#   A3  bit-identical at 9 of 9. One evaluation at the stored point lands where the
#       golden-section search left the leaf, so the sweep pays one evaluation and not
#       a search -- the 1 us against 10.2 us the cost section prices.
#   A2  bit-identical at 8 of 9. The exception is the seedling at psi_soil 2.0 MPa,
#       where 3 of 14 differ: soil_consumption_ layers 3-5, worst relative
#       difference 1.0 (6.256e-06, 2.428e-06, 6.394e-07 against zero). This is P0.1
#       by a third route, and its direction is the informative part -- the FRESH leaf
#       is right and the carried one is wrong. A leaf that solved a taller cohort
#       first leaves layers 3-5 written; the seedling roots to 0.4 m, so
#       max_soil_layer is 2 and E_from_Soil_to_Root_Collar never touches them. Any
#       one of the eight deeper-rooted prior states is enough on its own.
#       So the aux carry is sufficient once P0.1 lands, and NOT before: today the
#       leaf's outputs are a function of the previous cohort's solve as well as of
#       its own inputs and operating point.
#   A4  minimum theta over the run 0.1563 against soil_moist_residual 1e-2, a factor
#       of 15.6. So the guard fires nowhere at the default driver and the zeroed rows
#       are correct-but-unexercised here. Measured at 142 output times, not per
#       stage; a stage between two output times is not observed, which at this margin
#       is an inference rather than a measurement.

suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE)
})

n_layers   <- 5L
s <- TF24_Strategy(); p <- s$pars
soil_depth <- (1:n_layers) * (1.5 / n_layers)
eta_c      <- 1 - 2 / (1 + p$eta) + 1 / (1 + 2 * p$eta)
root_scale <- 83.26 * 0.5

new_leaf <- function(gss_tol = 1e-3, vcmax = p$vcmax_25) {
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

phys <- function(l, height, psi_soil) {
  l$set_physiology(area_leaf_of(height), root_prop(height), p$rho, p$a_bio,
                   0.5 * 1800, psi_soil, soil_depth,
                   p$K_s * p$theta / (height * eta_c),
                   1, 40, p$theta * height * eta_c, 25, 21, 100.5)
}

outputs <- function(l) {
  c(profit = l$profit_, opt_psi_stem = l$opt_psi_stem_,
    root_collar_psi = l$root_collar_psi_, ci = l$ci_,
    stom_cond_CO2 = l$stom_cond_CO2_, assim = l$assim_colimited_,
    transpiration = l$transpiration_, hydraulic_cost = l$hydraulic_cost_,
    E_up = l$E_up_, setNames(l$soil_consumption_, paste0("cons", 1:n_layers)))
}

# The worst relative difference over the compared outputs, and how many of them
# are not bit-identical.
compare <- function(a, b) {
  d <- abs(a - b); scale <- pmax(abs(a), abs(b))
  rel <- ifelse(scale > 0, d / scale, 0)
  list(n_diff = sum(d != 0), worst = max(rel), where = names(a)[which.max(rel)])
}

states <- list(
  list(h = 0.4,  ps = 0.05, tag = "seedling, wet"),
  list(h = 2.0,  ps = 0.05, tag = "sapling, wet"),
  list(h = 2.0,  ps = 0.17, tag = "sapling, driver's dry end"),
  list(h = 8.0,  ps = 0.17, tag = "tree, driver's dry end"),
  list(h = 17.9, ps = 0.17, tag = "canopy max, driver's dry end"),
  list(h = 8.0,  ps = 0.50, tag = "tree, beyond the driver"),
  list(h = 8.0,  ps = 3.00, tag = "tree, drought"),
  list(h = 2.0,  ps = 5.00, tag = "sapling, past psi_crit"),
  list(h = 0.4,  ps = 2.00, tag = "seedling, drought"))

# The intervening solve: a state as far from each probe state as the corpus goes.
other <- list(h = 0.4, ps = 0.50)

cat("develop build, 5 soil layers, TF24_Strategy() defaults, GSS_tol_abs 1e-3\n")
cat("14 outputs per state; n_diff counts those not bit-identical.\n\n")
cat(sprintf("%-28s %6s %6s %6s %11s %11s %11s\n", "state",
            "A1 nd", "A2 nd", "A3 nd", "A1 worst", "A2 worst", "A3 worst"))

l <- new_leaf()
for (st in states) {
  psi <- rep(st$ps, n_layers)

  phys(l, st$h, psi); l$find_root_collar_psi()
  ref <- outputs(l); pstar <- -l$root_collar_psi_

  # A3: one evaluation at the stored point, no intervening solve.
  l$evaluate_root_collar_psi(pstar); a3 <- compare(ref, outputs(l))

  # A1: displace the leaf entirely, then restore inputs and aux.
  phys(l, other$h, rep(other$ps, n_layers)); l$find_root_collar_psi()
  phys(l, st$h, psi); l$evaluate_root_collar_psi(pstar)
  a1 <- compare(ref, outputs(l))

  # A2: no carried caches at all.
  l2 <- new_leaf(); phys(l2, st$h, psi); l2$evaluate_root_collar_psi(pstar)
  a2 <- compare(ref, outputs(l2))

  cat(sprintf("%-28s %6d %6d %6d %11.3e %11.3e %11.3e\n", st$tag,
              a1$n_diff, a2$n_diff, a3$n_diff, a1$worst, a2$worst, a3$worst))
  if (max(a1$worst, a2$worst, a3$worst) > 0)
    cat(sprintf("%-28s worst at: A1 %s  A2 %s  A3 %s\n", "",
                a1$where, a2$where, a3$where))
}

## ---- A4  the soil guard's inputs and incidence ----------------------------
# One production run. Its cost is the reason this sits at the end.
p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- 105.32
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
r <- run_scm(p, Environment("TF24"), Control(), collect = TRUE, refine_schedule = FALSE)

theta_r <- 1e-2
sm <- r$env$soil_moist
cat(sprintf("\nA4  theta over %d records at %d output times\n",
            nrow(sm), length(unique(sm$step))))
cat(sprintf("    min %.6f   soil_moist_residual %.0e   margin %.1fx\n",
            min(sm$soil_moist), theta_r, min(sm$soil_moist) / theta_r))
cat(sprintf("    records at or below the residual: %d\n", sum(sm$soil_moist <= theta_r)))
