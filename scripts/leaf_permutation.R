#   Rscript scripts/leaf_permutation.R
#
# P0.10. Is the shared Leaf a function of what set_physiology was handed, and
# of nothing the previous solve left behind? Reading the object answers no for
# four members; this executes the question instead. A census of production
# (height, psi_soil, radiation) states is solved on one Leaf in the order the
# cohort loop uses, then in five other orders, and every leaf output is
# required to be bit-identical per state across all six. Four blocks:
#
#   B1  the census, and the layer geometry each state implies. A state whose
#       roots reach max_soil_layer < 5 has 5 - max_soil_layer layers that
#       E_from_Soil_to_Root_Collar does not write and set_physiology's resize
#       does not clear.
#   B2  permutation invariance of eleven outputs -- profit_, the five
#       soil_consumption_ entries, E_up_, transpiration_, opt_psi_stem_,
#       root_collar_psi_, stom_cond_CO2_ -- against the production order, per
#       state, counted per output.
#   B3  a single re-solve: state A, one other state, state A again, on the same
#       leaf, over one state per height stratum.
#   B4  20 m tree then 0.4 m seedling, the ordering with a known answer, and
#       the wettest psi_soil the census reaches against psi_crit, which decides
#       whether the shutdown exits are on this driver at all.
#
# The instrument needs no AD and runs on develop. It catches what re-running
# cannot: the forward pass is order-deterministic, so a state that reads its
# predecessor's leftovers reproduces exactly run after run, and only a
# reordering separates the two.
#
# CONFIGURATION. plant develop 141dc8df in the worktree
# /home/user/wt-leaf-permutation (branch p0/leaf-permutation), odelia 854a8e18
# installed, built -O2 -DNDEBUG -g0 via pkgbuild::compile_dll(debug = FALSE).
# Census run: scm_base_parameters("TF24", "TF24_Env"), max_patch_lifetime
# 105.32 set on the base parameters before add_strategies, one strategy at lma
# 0.1978791, Environment("TF24"), Control() defaults, refine_schedule = FALSE,
# collect = TRUE, 5 soil layers over 1.5 m. Leaf constructed as in
# scripts/aux_round_trip.R from TF24_Strategy() defaults, integrator (21,
# 1e-3), GSS_tol_abs 1e-3, and atm_vpd, ca, leaf_temp, atm_o2_kpa, atm_kpa
# read from Environment("TF24") so the states are the production ones.
#
# Two degeneracies of the census. psi_soil per layer is the recorded soil
# moisture through TF24_Environment$psi_from_soil_moist, at the 142 output
# times rather than per stage. Radiation is k_I * max(light, 1e-4) * PPFD with
# light linearly interpolated in the recorded light profile of that step at
# height * eta_c, where the run itself evaluates a spline -- so a state's
# radiation is near its production value, not equal to it. Both enter every
# order equally, so neither touches the permutation comparison; they bound how
# closely block B1's incidence tracks the production run's.
#
# RESULTS.
#   B1  10 153 records at 142 output times, heights 0.344 to 17.943 m,
#       descending within every step. 3 430 records (33.78%) have
#       max_soil_layer < 5 and so leave at least one layer unwritten by their
#       own solve; 2 612 of those (25.73%) have max_soil_layer 2 and leave
#       three of five. Those are P0.1's 33.78% and 25.73% exactly. A stricter
#       count on the production order alone -- the unwritten layer holds a
#       nonzero value rather than the constructor's zero -- is 743 records
#       (7.32%) and 272 (2.68%), the difference being the early steps where no
#       state deep-rooted enough to write layers 3 to 5 has run yet.
#   B2  eleven outputs, five permutations against the production order.
#       soil_consumption_ layers 3, 4 and 5 move; layers 1 and 2 and the other
#       six outputs are bit-identical at all 10 153 states in all five orders.
#       The worst order moves 3 430 states, 33.78%, and its per-layer counts
#       are 2 612 / 3 060 / 3 430 -- the layer-3 count is 25.73%. Reversing the
#       order and two random orders all reach 3 430; ordering tallest-first
#       reaches 3 424 and shortest-first only 743, which is the production
#       order's own stricter count and the reason a single order cannot
#       measure this. The only carrier this census reaches is the one P0.1
#       names, and it reaches none of the other six outputs.
#   B3  seven strata, one state each. Solving a state, then the tallest state,
#       then the state again reproduces all eleven outputs exactly at the four
#       strata whose roots reach layer 5, and differs in exactly the
#       5 - max_soil_layer unwritten layers at the three shallower ones.
#   B4  the 0.4 m seedling's layers 3 to 5 are bit-identical to the 20 m
#       tree's, 1.036619e-05 3.800049e-06 1.061755e-06, and zero on a fresh
#       leaf. Over the census the wettest layer reaches 0.0146 MPa and the
#       driest 1.3308 MPa against psi_crit 7.0855, and no output time has its
#       wettest layer at or past psi_crit, so P0.2's shutdown route has zero
#       incidence on this driver and none of these states takes it.
#
# What this census does not reach. photo_temp_cached_ is keyed on (leaf_temp,
# atm_o2_kpa), both constant over the run, so no reordering of these states can
# move it; a census that varied either would. psi_soil_cache_ lives on the
# environment rather than the leaf and is not read on this path.

suppressMessages({
  library(odelia); pkgload::load_all("/home/user/wt-leaf-permutation", quiet = TRUE)
})

n_layers <- 5L
s <- TF24_Strategy(); p <- s$pars
e <- Environment("TF24")
eta_c      <- 1 - 2 / (1 + p$eta) + 1 / (1 + 2 * p$eta)
root_scale <- 83.26 * 0.5
atm_vpd <- e$get_atm_vpd(); ca <- e$get_ca(); leaf_temp <- e$get_leaf_temp()
atm_o2  <- e$get_atm_o2_kpa(); atm_kpa <- e$get_atm_kpa()

new_leaf <- function() {
  l <- Leaf(p$vcmax_25, p$c, p$b, p$psi_crit, 2.680147, 3.898245,
            3.898245 * log(1 / 0.05)^(1 / 2.680147), p$beta2, p$jmax_25, p$a,
            p$curv_fact_elec_trans, p$curv_fact_colim,
            1e-3, 100, 1e-6, 1000, p$g1_TF24, 3.4e2, 9.4e3)
  l$initialize_integrator(21L, 1e-3); l
}

# Per-layer root mass, reproducing net_mass_production_dt's loop.
root_prop <- function(height, soil_depth) {
  rd <- min(height, max(soil_depth))
  scale <- root_scale * p$a_r1 * (height / p$a_l1)^(1 / p$a_l2)
  out <- numeric(length(soil_depth)); prev_q <- 1
  for (a in seq_along(soil_depth)) {
    if (prev_q == 0) break
    q <- if (soil_depth[a] > rd) 0 else
      (1 - (soil_depth[a] / rd)^p$root_depth_shape_eta)^2
    out[a] <- scale * (prev_q - q); prev_q <- q
  }
  out
}

solve_state <- function(l, height, psi_soil, radiation, soil_depth) {
  l$set_physiology((height / p$a_l1)^(1 / p$a_l2), root_prop(height, soil_depth),
                   p$rho, p$a_bio, radiation, psi_soil, soil_depth,
                   p$K_s * p$theta / (height * eta_c),
                   atm_vpd, ca, p$theta * height * eta_c,
                   leaf_temp, atm_o2, atm_kpa)
  l$find_root_collar_psi()
  c(profit = l$profit_,
    setNames(l$soil_consumption_, paste0("cons", seq_len(n_layers))),
    E_up = l$E_up_, transpiration = l$transpiration_,
    opt_psi_stem = l$opt_psi_stem_, root_collar_psi = l$root_collar_psi_,
    stom_cond_CO2 = l$stom_cond_CO2_)
}

# NaN in the same slot of both is agreement, not a difference.
differs <- function(a, b) !((a == b) | (is.na(a) & is.na(b)))

## ---- the census ------------------------------------------------------------

p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- 105.32
pp <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
r <- run_scm(pp, Environment("TF24"), Control(), collect = TRUE,
             refine_schedule = FALSE)

rec  <- r$species
soil_depth <- head(r$env$soil_depth$soil_depth, n_layers)
steps <- unique(rec$step)

# soil_moist is long over (step, layer) with no layer column, n_layers rows per
# output time in layer order.
sm  <- matrix(r$env$soil_moist$soil_moist, ncol = n_layers, byrow = TRUE)
smt <- unique(r$env$soil_moist$step)
psi_by_step <- t(apply(sm, 1, function(th) vapply(th, e$psi_from_soil_moist, 0)))
rownames(psi_by_step) <- smt

# Radiation as compute_rates assembles it, from the recorded light profile.
la <- r$env$light_availability
rad_of <- function(step, heights) {
  g <- la[la$step == step, ]
  light <- stats::approx(g$height, g$light_availability, heights * eta_c,
                         rule = 2)$y
  p$k_I * pmax(light, 1e-4) * e$get_PPFD()
}

census <- data.frame(step = rec$step, node = rec$node, height = rec$height,
                     radiation = NA_real_)
for (st in steps) {
  i <- census$step == st
  census$radiation[i] <- rad_of(st, census$height[i])
}
psi_row <- match(census$step, smt)

descending <- all(vapply(split(census$height, census$step),
                         function(h) all(diff(h) <= 0), TRUE))

l <- new_leaf()
msl <- vapply(census$height, function(h) {
  l$set_physiology((h / p$a_l1)^(1 / p$a_l2), root_prop(h, soil_depth), p$rho,
                   p$a_bio, 1, rep(0.05, n_layers), soil_depth,
                   p$K_s * p$theta / (h * eta_c), atm_vpd, ca,
                   p$theta * h * eta_c, leaf_temp, atm_o2, atm_kpa)
  l$max_soil_layer
}, 0L)

cat(sprintf("B1  %d records, %d output times, heights %.3f to %.3f m\n",
            nrow(census), length(steps), min(census$height), max(census$height)))
cat(sprintf("    heights descending within every step: %s\n", descending))
cat("    max_soil_layer  records\n")
for (k in sort(unique(msl)))
  cat(sprintf("    %14d  %6d  (%5.2f%%)\n", k, sum(msl == k),
              100 * sum(msl == k) / length(msl)))

## ---- B1/B2  solve the census in six orders ---------------------------------

solve_order <- function(ord) {
  l <- new_leaf()
  out <- matrix(NA_real_, nrow = nrow(census), ncol = 11)
  for (i in ord)
    out[i, ] <- solve_state(l, census$height[i], psi_by_step[psi_row[i], ],
                            census$radiation[i], soil_depth)
  out
}

production <- seq_len(nrow(census))
set.seed(20260730)
orders <- list(
  reversed          = rev(production),
  `shortest first`  = order(census$height),
  `tallest first`   = order(census$height, decreasing = TRUE),
  `random 1`        = sample(production),
  `random 2`        = sample(production))

ref <- solve_order(production)
onames <- names(solve_state(new_leaf(), 1, rep(0.05, n_layers), 900, soil_depth))
colnames(ref) <- onames

# The production order's own carry: layers past max_soil_layer holding a
# nonzero value this state's solve never wrote.
stale <- vapply(seq_len(nrow(census)), function(i) {
  if (msl[i] >= n_layers) 0L
  else sum(ref[i, 1 + ((msl[i] + 1):n_layers)] != 0)
}, 0L)
cat(sprintf("\n    unwritten layers holding a nonzero value, production order:"))
cat(sprintf(" >=1 at %d records (%.2f%%),", sum(stale >= 1), 100 * mean(stale >= 1)))
cat(sprintf(" 3 of 5 at %d (%.2f%%)\n", sum(stale == 3), 100 * mean(stale == 3)))

cat("\nB2  outputs not bit-identical to the production order, per output\n")
cat(sprintf("%-16s %8s", "order", "states"))
cat(sprintf(" %13s", onames), "\n", sep = "")
worst <- 0
for (nm in names(orders)) {
  o <- solve_order(orders[[nm]])
  d <- differs(ref, o)
  nst <- sum(rowSums(d) > 0); worst <- max(worst, nst)
  cat(sprintf("%-16s %8d", nm, nst))
  cat(sprintf(" %13d", colSums(d)), "\n", sep = "")
}
cat(sprintf("    worst order: %d of %d states (%.2f%%) move\n",
            worst, nrow(census), 100 * worst / nrow(census)))

## ---- B3  one re-solve after one other state --------------------------------

cat("\nB3  solve A, then B, then A: differences at the second A\n")
strata <- vapply(sort(unique(msl)), function(k) which(msl == k)[1], 0L)
strata <- c(strata, vapply(c(4, 8, 14), function(h)
  which.min(abs(census$height - h)), 0L))
other <- which.max(census$height)
cat(sprintf("%9s %6s %8s  %s\n", "height", "layers", "n_diff", "which"))
for (i in strata) {
  l <- new_leaf()
  a <- solve_state(l, census$height[i], psi_by_step[psi_row[i], ],
                   census$radiation[i], soil_depth)
  invisible(solve_state(l, census$height[other], psi_by_step[psi_row[other], ],
                        census$radiation[other], soil_depth))
  b <- solve_state(l, census$height[i], psi_by_step[psi_row[i], ],
                   census$radiation[i], soil_depth)
  d <- differs(a, b)
  cat(sprintf("%9.3f %6d %8d  %s\n", census$height[i], msl[i], sum(d),
              if (any(d)) paste(onames[d], collapse = " ") else "-"))
}

## ---- B4  the tree-then-seedling pair, and the shutdown threshold -----------

cat("\nB4  20 m tree then 0.4 m seedling on one leaf\n")
psi_wet <- psi_by_step[1, ]
rad <- p$k_I * 1 * e$get_PPFD()
l <- new_leaf()
tree <- solve_state(l, 20, psi_wet, rad, soil_depth)
seed <- solve_state(l, 0.4, psi_wet, rad, soil_depth)
fresh <- solve_state(new_leaf(), 0.4, psi_wet, rad, soil_depth)
deep <- 1 + 3:5
cat(sprintf("    tree     layers 3-5 %s\n",
            paste(sprintf("%.6e", tree[deep]), collapse = " ")))
cat(sprintf("    seedling layers 3-5 %s\n",
            paste(sprintf("%.6e", seed[deep]), collapse = " ")))
cat(sprintf("    fresh    layers 3-5 %s\n",
            paste(sprintf("%.6e", fresh[deep]), collapse = " ")))
cat(sprintf("    seedling bit-identical to the tree there: %s\n",
            identical(unname(seed[deep]), unname(tree[deep]))))

cat(sprintf("\n    census psi_soil: wettest layer %.4f MPa, driest %.4f MPa,",
            min(psi_by_step), max(psi_by_step)))
cat(sprintf(" psi_crit %.4f\n", p$psi_crit))
wettest <- apply(psi_by_step, 1, min)
cat(sprintf("    output times whose wettest layer is at or past psi_crit: %d of %d\n",
            sum(wettest >= p$psi_crit), length(wettest)))
