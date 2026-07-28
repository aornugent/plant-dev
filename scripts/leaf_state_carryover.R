# Does one leaf solve leave state that the next one reads?
#
# TF24 shares ONE Leaf object across every cohort of a species (through the
# Strategy shared_ptr), so any per-solve field that set_physiology does not
# fully rewrite is a channel from the previously-solved cohort into this one.
# Three claims are tested directly against a develop build:
#
#   1. soil_consumption_ layers at or beyond max_soil_layer are never written
#      by E_from_Soil_to_Root_Collar, and set_physiology only .resize()s the
#      vector (which leaves existing elements alone), so a shallow-rooted
#      cohort reports the previous cohort's deep-layer uptake as its own.
#   2. the find_root_collar_psi shut-down exits set profit_/opt_psi_stem_/
#      root_collar_psi_ but not soil_consumption_ or E_up_, so a shut-down
#      plant reports whatever the last solve or the last root-finder trial
#      point left there.
#   3. leaf dark respiration is subtracted twice on the production carbon
#      path: once as R_d_ inside assim_colimited (hence inside profit_) and
#      again as pars.r_l * mass_leaf in TF24_Strategy::respiration.
#
# Run from the plant-dev root.

library(odelia)
pkgload::load_all("/home/user/plant-develop", quiet = TRUE)

s <- TF24_Strategy()
p <- s$pars

new_leaf <- function() {
  l <- Leaf(p$vcmax_25, p$c, p$b, p$psi_crit,
            2.680147, 3.898245,
            3.898245 * log(1 / 0.05)^(1 / 2.680147),
            p$beta2, p$jmax_25, p$a,
            p$curv_fact_elec_trans, p$curv_fact_colim,
            1e-3, 100, 1e-6, 1000, p$g1_TF24, 3.4e2, 9.4e3)
  l$initialize_integrator(21L, 1e-3)
  l
}

n_layers    <- 5
soil_depth  <- (1:n_layers) * (1.5 / n_layers)
eta_c       <- 1 - 2 / (1 + p$eta) + 1 / (1 + 2 * p$eta)
root_scale  <- 83.26 * 0.5

# Per-layer root mass for a plant of a given height, reproducing
# net_mass_production_dt's loop exactly.
root_prop <- function(height) {
  rooting_depth <- min(height, 1.5)
  mass_root     <- p$a_r1 * (height / p$a_l1)^(1 / p$a_l2)
  scale         <- root_scale * mass_root
  out <- numeric(n_layers)
  prev_q <- 1
  for (a in seq_len(n_layers)) {
    if (prev_q == 0) break
    q <- if (soil_depth[a] > rooting_depth) 0 else
      (1 - (soil_depth[a] / rooting_depth)^p$root_depth_shape_eta)^2
    out[a] <- scale * (prev_q - q)
    prev_q <- q
  }
  out
}

solve_at <- function(l, height, psi_soil, radiation = 0.5 * 1800) {
  area_leaf <- (height / p$a_l1)^(1 / p$a_l2)
  l$set_physiology(area_leaf, root_prop(height), p$rho, p$a_bio, radiation,
                   psi_soil, soil_depth,
                   p$K_s * p$theta / (height * eta_c),   # leaf-specific k_max
                   1, 40, p$theta * height * eta_c, 25, 21, 100.5)
  l$find_root_collar_psi()
  list(height = height, area_leaf = area_leaf,
       max_soil_layer = l$max_soil_layer,
       soil_consumption = l$soil_consumption_,
       E_up = l$E_up_, profit = l$profit_,
       root_collar_psi = l$root_collar_psi_)
}

psi_wet <- rep(0.02, n_layers)

cat("================================================================\n")
cat("1. soil_consumption_ carry-over across cohorts on the NORMAL path\n")
cat("================================================================\n\n")

heights <- c(20.0, 0.4)   # a canopy tree, then a seedling -- the order
                          # Species::compute_rates uses (descending height)

l <- new_leaf()
res <- lapply(heights, function(h) solve_at(l, h, psi_wet))
for (r in res) {
  cat(sprintf("height %6.2f m  max_soil_layer %d  area_leaf %.4e\n",
              r$height, r$max_soil_layer, r$area_leaf))
  cat(sprintf("   soil_consumption_ = %s\n",
              paste(sprintf("%.6e", r$soil_consumption), collapse = "  ")))
}

# The same seedling solved on a FRESH leaf: the deep layers are then whatever
# the constructor left (0), which is what the seedling's own physics implies.
l2 <- new_leaf()
fresh <- solve_at(l2, heights[2], psi_wet)
cat(sprintf("\nsame seedling on a FRESH leaf (nothing solved before it):\n"))
cat(sprintf("   soil_consumption_ = %s\n",
            paste(sprintf("%.6e", fresh$soil_consumption), collapse = "  ")))

deep <- (fresh$max_soil_layer + 1):n_layers
cat(sprintf("\nlayers %s are beyond the seedling's rooting depth.\n",
            paste(deep, collapse = ",")))
cat(sprintf("   after the tree: %s\n",
            paste(sprintf("%.6e", res[[2]]$soil_consumption[deep]), collapse = " ")))
cat(sprintf("   on a fresh leaf: %s\n",
            paste(sprintf("%.6e", fresh$soil_consumption[deep]), collapse = " ")))
carry <- isTRUE(all.equal(res[[2]]$soil_consumption[deep],
                          res[[1]]$soil_consumption[deep]))
cat(sprintf("   identical to the TREE's deep layers: %s\n", carry))

# What the patch water balance actually receives: consumption_rate is
# soil_consumption_[i] * area_leaf * (unit conversion), so the spurious draw
# is the stale per-area rate times the seedling's own leaf area.
conv <- 60 * 60 * 12 * 365 / 1000 * 0.018015
spurious <- sum(res[[2]]$soil_consumption[deep]) * res[[2]]$area_leaf * conv
real     <- sum(res[[2]]$soil_consumption[-deep]) * res[[2]]$area_leaf * conv
cat(sprintf("\n   seedling's real draw (rooted layers)   %.6e m/yr\n", real))
cat(sprintf("   seedling's spurious draw (deep layers) %.6e m/yr  (%.1f%% of real)\n",
            spurious, 100 * spurious / real))

cat("\nOrder dependence: solve the seedling FIRST, then the tree, then the\n")
cat("seedling again -- a pure function of the cohort's own boundary would\n")
cat("give the same answer both times.\n\n")
l3 <- new_leaf()
a <- solve_at(l3, heights[2], psi_wet)
invisible(solve_at(l3, heights[1], psi_wet))
b <- solve_at(l3, heights[2], psi_wet)
cat(sprintf("   seedling, 1st time: %s\n",
            paste(sprintf("%.6e", a$soil_consumption), collapse = " ")))
cat(sprintf("   seedling, 2nd time: %s\n",
            paste(sprintf("%.6e", b$soil_consumption), collapse = " ")))
cat(sprintf("   bit-identical: %s\n",
            identical(a$soil_consumption, b$soil_consumption)))

cat("\n================================================================\n")
cat("2. the shut-down exits leave soil_consumption_ / E_up_ untouched\n")
cat("================================================================\n\n")

# psi_crit for the stem is ~ p$psi_crit MPa; a soil drier than that in every
# layer takes the first early exit (-wettest >= psi_crit), which never calls
# E_from_Soil_to_Root_Collar at all this solve.
psi_dry <- rep(p$psi_crit * 1.5, n_layers)

l4 <- new_leaf()
tree <- solve_at(l4, 20.0, psi_wet)
cat(sprintf("wet tree      E_up_ = %.6e  soil_consumption_[1] = %.6e\n",
            tree$E_up, tree$soil_consumption[1]))
shut <- solve_at(l4, 20.0, psi_dry)
cat(sprintf("then bone dry E_up_ = %.6e  soil_consumption_[1] = %.6e\n",
            shut$E_up, shut$soil_consumption[1]))
cat(sprintf("   profit_ = %.6f  (shut down: -R_d - cost(psi_crit))\n", shut$profit))
cat(sprintf("   E_up_ carried over from the wet solve: %s\n",
            identical(shut$E_up, tree$E_up)))
cat(sprintf("   soil_consumption_ carried over:        %s\n",
            identical(shut$soil_consumption, tree$soil_consumption)))
cat("\n   A shut-down plant transpires nothing, so both should be 0.\n")
cat("   What the patch water balance is handed instead is the previous\n")
cat("   cohort's uptake, scaled by THIS cohort's leaf area.\n")

# On a fresh leaf the same dry solve reports the constructor's zeros -- so the
# reported value depends entirely on what ran before it.
l5 <- new_leaf()
shut_fresh <- solve_at(l5, 20.0, psi_dry)
cat(sprintf("\n   same dry solve on a FRESH leaf: E_up_ = %.6e, consumption[1] = %.6e\n",
            shut_fresh$E_up, shut_fresh$soil_consumption[1]))

cat("\n================================================================\n")
cat("3. leaf dark respiration is subtracted twice\n")
cat("================================================================\n\n")

l6 <- new_leaf()
invisible(solve_at(l6, 20.0, psi_wet))
R_d <- l6$R_d_
cat(sprintf("R_d_ = vcmax_ * 0.015 = %.6f umol CO2 m^-2 leaf s^-1\n", R_d))
cat("assim_colimited() ends in '- R_d_', and profit_ = assim_colimited_ - cost,\n")
cat("so profit_ is NET assimilation. net_mass_production_dt then computes\n")
cat("   a_bio * a_y * (profit_ * area_leaf * 60*60*12*365/1e6 - respiration)\n")
cat("where respiration includes r_l * mass_leaf -- leaf dark respiration again.\n\n")

sec_per_yr <- 60 * 60 * 12 * 365
# both terms per m^2 of leaf area, in kg dry mass / yr
rd_term <- R_d * sec_per_yr / 1e6 * p$a_bio * p$a_y
rl_term <- p$r_l * p$lma * p$a_bio * p$a_y
cat(sprintf("   inside profit_ (R_d_):            %.6f kg dry mass / m2 leaf / yr\n", rd_term))
cat(sprintf("   again as r_l * mass_leaf:         %.6f kg dry mass / m2 leaf / yr\n", rl_term))
cat(sprintf("   leaf respiration counted:         %.3fx\n", (rd_term + rl_term) / rl_term))
cat(sprintf("   double-counted share of the pair: %.1f%%\n",
            100 * rd_term / (rd_term + rl_term)))
cat("\nFF16, which TF24 was scaffolded from, uses a GROSS light-response curve\n")
cat("(assimilation_leaf = a_p1 x/(x+a_p2)) where r_l is the only leaf\n")
cat("respiration. TF24 swapped in a Farquhar leaf returning NET assimilation\n")
cat("and kept r_l.\n")

cat("\n================================================================\n")
cat("4. profit_psi_stem_Sperry is exported and always NaN\n")
cat("================================================================\n\n")
cat(sprintf("lambda_ = %s (set to NA_REAL in setup_clean_leaf, assigned nowhere else)\n",
            format(l6$lambda_)))
cat(sprintf("profit_psi_stem_Sperry(2, 0.1) = %s\n",
            format(l6$profit_psi_stem_Sperry(2, 0.1))))
cat(sprintf("profit_psi_stem_TF(2, 0.1)     = %s\n",
            format(l6$profit_psi_stem_TF(2, 0.1))))
