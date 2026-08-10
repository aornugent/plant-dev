# Where does the collar solve actually spend forward time, and what would a
# gradient-based locator cost?
#
# Three entry points share prepare_collar_solve, so the split is measurable from R:
#   find_root_collar_psi()          prepare + golden section
#   evaluate_root_collar_psi(x)     prepare + 1 profit eval
#   profit_at_collar_psi(x, a, b)   1 profit eval, no prepare   [if exposed]
# and dprofit_droot_collar_psi(x) prices the gradient a bracketing locator needs.
#
#   Rscript scripts/collar_cost_split.R

suppressMessages({ library(odelia); pkgload::load_all("plant", quiet = TRUE) })

mk <- function(gss) Leaf(
  vcmax_25 = 100, jmax_25 = 100 * 167, c = 2.04, b = 3, psi_crit = 5,
  root_c = 2.65, root_b = 1.29, root_psi_crit = 1.29 * (log(1 / 0.05))^(1 / 2.65),
  beta2 = 1, a = 0.3, curv_fact_elec_trans = 0.7, curv_fact_colim = 0.99,
  GSS_tol_abs = gss, vulnerability_curve_ncontrol = 100, ci_abs_tol = 1e-6,
  ci_niter = 1000, g1_TF24 = 46.32995, beta_R_H = 3.4e3, beta_R_V = 9.4e4)
set_phys <- function(l, psi, ar, nl = 5, dep = 1.5) {
  th <- 0.000157; h <- 5
  l$set_physiology(area_leaf = ar, mass_root_prop = rep(1/nl, nl), rho = 608,
    a_bio = 0.0245, PPFD = 900, psi_soil = rep(psi, nl),
    soil_depth = dep * seq_len(nl) / nl,
    leaf_specific_conductance_max = 1 * th / h, atm_vpd = 2, ca = 40,
    sapwood_volume_per_leaf_area = th * h, leaf_temp = 25, atm_o2_kpa = 21,
    atm_kpa = 101.3)
}
# median of repeated timings, so a stray GC does not set the number
tm <- function(f, n = 4000, reps = 7) {
  median(replicate(reps, system.time(for (i in seq_len(n)) f())[["elapsed"]])) / n * 1e6
}

cat(sprintf("%9s %7s %10s %10s %10s %10s %9s %9s\n",
            "GSS_tol", "psi", "solve", "prep+1ev", "search", "1 grad", "setup %", "n_iter"))
for (gss in c(1e-3, 1e-6, 1e-10)) for (psi in c(0.0165, 0.169, 1.0)) {
  l <- mk(gss); set_phys(l, psi, 1.209e-4)
  l$find_root_collar_psi(); ps <- -l$root_collar_psi_
  t_solve <- tm(function() l$find_root_collar_psi())
  t_prep1 <- tm(function() l$evaluate_root_collar_psi(ps))
  t_grad  <- tm(function() l$dprofit_droot_collar_psi(ps))
  search  <- t_solve - t_prep1
  # golden section iteration count from the bracket width it converged on
  cat(sprintf("%9.0e %7.4f %10.3f %10.3f %10.3f %10.3f %8.1f%% %9s\n",
              gss, psi, t_solve, t_prep1, search, t_grad,
              100 * t_prep1 / t_solve, "-"))
}

cat("\n=== what one profit eval costs, and hence what the setup costs ===\n")
cat("iterations of golden section for a bracket w and tol t: log(w/t)/log(1.618)\n")
for (gss in c(1e-3, 1e-6)) {
  l <- mk(gss); set_phys(l, 0.169, 1.209e-4)
  l$find_root_collar_psi(); ps <- -l$root_collar_psi_
  t_solve <- tm(function() l$find_root_collar_psi())
  t_prep1 <- tm(function() l$evaluate_root_collar_psi(ps))
  # bracket width is roughly psi_crit-scale; use the observed p* span as a proxy
  n_it <- log(0.8 / gss) / log(1.618) + 2
  ev   <- (t_solve - t_prep1) / (n_it - 1)
  cat(sprintf("tol %8.0e: est %5.1f evals, %6.3f us/eval, setup = %6.3f us (%.1f%% of solve)\n",
              gss, n_it, ev, t_prep1 - ev, 100 * (t_prep1 - ev) / t_solve))
}

cat("\n=== a gradient-based locator, priced ===\n")
l <- mk(1e-3); set_phys(l, 0.169, 1.209e-4); l$find_root_collar_psi()
ps <- -l$root_collar_psi_
t_grad <- tm(function() l$dprofit_droot_collar_psi(ps))
t_ev   <- tm(function() l$evaluate_root_collar_psi(ps))
cat(sprintf("1 gradient eval: %.3f us;  1 (prepare + profit eval): %.3f us;  ratio %.2f\n",
            t_grad, t_ev, t_grad / t_ev))
cat("A bracketing root-find on the gradient needs ~8 gradient evals plus the same\n")
cat("setup. Compare against golden section's ~15 profit evals plus the same setup.\n")
