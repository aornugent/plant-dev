# Two questions, both answerable from R against develop.
#
# 1. Is the production operating point a stationary interior maximum? Draw the
#    (area_leaf, psi_soil) pairs a production run actually visits and evaluate
#    develop's exact analytic gradient at the operating point it returns. Near
#    zero => stationary, and report 2's envelope argument holds on that path.
#
# 2. Where does the collar solve spend its forward time? Decomposable without
#    instrumentation, because two entry points share prepare_collar_solve:
#      find_root_collar_psi()      = prepare + golden section (~17 profit evals)
#      evaluate_root_collar_psi(x) = prepare + 1 profit eval
#    so the difference isolates the search, and the second isolates the setup.
#
#   Rscript scripts/production_stationarity.R

suppressMessages({ library(odelia); pkgload::load_all("plant", quiet = TRUE) })

mk <- function(gss) Leaf(
  vcmax_25 = 100, jmax_25 = 100 * 167, c = 2.04, b = 3, psi_crit = 5,
  root_c = 2.65, root_b = 1.29, root_psi_crit = 1.29 * (log(1 / 0.05))^(1 / 2.65),
  beta2 = 1, a = 0.3, curv_fact_elec_trans = 0.7, curv_fact_colim = 0.99,
  GSS_tol_abs = gss, vulnerability_curve_ncontrol = 100, ci_abs_tol = 1e-6,
  ci_niter = 1000, g1_TF24 = 46.32995, beta_R_H = 3.4e3, beta_R_V = 9.4e4)

set_phys <- function(l, psi, area_leaf, nlayer = 5, depth = 1.5) {
  th <- 0.000157; h <- 5
  l$set_physiology(area_leaf = area_leaf, mass_root_prop = rep(1/nlayer, nlayer),
                   rho = 608, a_bio = 0.0245, PPFD = 900,
                   psi_soil = rep(psi, nlayer),
                   soil_depth = depth * seq_len(nlayer) / nlayer,
                   leaf_specific_conductance_max = 1 * th / h, atm_vpd = 2, ca = 40,
                   sapwood_volume_per_leaf_area = th * h, leaf_temp = 25,
                   atm_o2_kpa = 21, atm_kpa = 101.3)
}

cat("=== 0. what the production run actually visits ===\n")
p0 <- scm_base_parameters("TF24", "TF24_Env"); p0$max_patch_lifetime <- 20
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
res <- run_scm(p, Environment("TF24"), Control(), collect = TRUE, refine_schedule = FALSE)
d <- as.data.frame(res$species); d <- d[is.finite(d$transpiration), ]
sm <- as.data.frame(res$env$soil_moist)
cat("area_leaf (competition_effect) quantiles:\n")
print(signif(quantile(d$competition_effect, c(0, .1, .5, .9, 1)), 4))
cat("soil moisture quantiles (theta):\n")
print(signif(quantile(sm[[ncol(sm)]], c(0, .1, .5, .9, 1), na.rm = TRUE), 4))

# retention curve, read from tf24_environment.h:
#   psi = a_psi * (theta/theta_sat)^(-n_psi) / 1e6   [MPa]
e <- Environment("TF24")
a_psi <- e$a_psi; n_psi <- e$n_psi; th_sat <- e$soil_moist_sat
cat(sprintf("a_psi %.1f  n_psi %.3f  theta_sat %.4f\n", a_psi, n_psi, th_sat))
psi_of <- function(th) a_psi * (th / th_sat)^(-n_psi) / 1e6
th_q <- quantile(sm[[ncol(sm)]], c(0.02, .25, .5, .75, .98), na.rm = TRUE)
psis <- psi_of(as.numeric(th_q))
cat("psi_soil over the run's theta range (MPa):\n")
print(setNames(signif(psis, 4), sprintf("th=%.4f", th_q)))

cat("\n=== 1. stationarity on the visited (area_leaf, psi_soil) grid ===\n")
cat("g = develop's exact dprofit/dp at the returned operating point.\n")
cat("|g| tiny against the pinned-regime scale (~10) means stationary.\n\n")
cat(sprintf("%9s %10s %9s %10s %12s %10s\n",
            "psi_soil", "area_leaf", "p*", "margin", "dprofit/dp", "transpir"))
areas <- as.numeric(quantile(d$competition_effect, c(0, .5, .9, 1)))
cat(sprintf("areas: %s\n\n", paste(signif(areas,4), collapse=", ")))
for (psi in as.numeric(psis)) for (ar in areas) {
  l <- mk(1e-10)
  ok <- tryCatch({ set_phys(l, psi, ar); l$find_root_collar_psi(); TRUE },
                 error = function(e) FALSE)
  if (!ok) { cat(sprintf("%9.4f %10.3e  <failed>\n", psi, ar)); next }
  pp <- -l$root_collar_psi_
  g  <- tryCatch(l$dprofit_droot_collar_psi(pp), error = function(e) NA_real_)
  cat(sprintf("%9.4f %10.3e %9.4f %10.4f %12.4g %10.3e\n",
              psi, ar, pp, l$opt_psi_stem_ - pp, g, l$transpiration_))
}

cat("\n=== 2. forward cost: setup versus search ===\n")
bench <- function(gss, psi, ar, n = 300) {
  l <- mk(gss); set_phys(l, psi, ar)
  l$find_root_collar_psi(); pstar <- -l$root_collar_psi_
  t_full <- system.time(for (i in seq_len(n)) l$find_root_collar_psi())[["elapsed"]] / n
  t_one  <- system.time(for (i in seq_len(n)) l$evaluate_root_collar_psi(pstar))[["elapsed"]] / n
  c(full = t_full * 1e6, prep_plus_1 = t_one * 1e6)
}
cat(sprintf("%9s %10s %12s %14s %12s %10s\n",
            "GSS_tol", "psi", "full (us)", "prep+1ev (us)", "search (us)", "search %"))
for (gss in c(1e-3, 1e-6, 1e-10)) for (psi in c(0.2, 1.0)) {
  b <- bench(gss, psi, 1.2e-4)
  srch <- b[["full"]] - b[["prep_plus_1"]]
  cat(sprintf("%9.0e %10.2f %12.2f %14.2f %12.2f %9.1f%%\n",
              gss, psi, b[["full"]], b[["prep_plus_1"]], srch,
              100 * srch / b[["full"]]))
}
