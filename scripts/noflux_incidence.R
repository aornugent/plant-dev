# How often does the collar operating point land on the zero-flux branch?
#
# set_leaf_states_rates_from_psi_stem's `psi_upstream >= psi_stem` branch sets
# transpiration_ = 0 exactly and pins ci_ at gamma_*umol_per_mol_to_Pa, where net
# assimilation is -R_d. The limit of the other branch as flux -> 0 is net
# assimilation 0. So the objective jumps by R_d at psi_stem == psi_upstream.
#
# That branch is inside the objective, not an exit from prepare_collar_solve, so
# report 2's branch census cannot see it. But both its signatures reach aux slots,
# so its incidence is observable from a production run with no instrumentation:
#
#   transpiration == 0                exactly, on that branch only
#   opt_psi_stem + opt_root_psi == 0   stem pinned to the collar (no gradient)
#
# The margin `opt_psi_stem + opt_root_psi` is the distance (MPa) from the corner,
# and its distribution is what decides whether the corner is on the production
# path at all.
#
#   Rscript scripts/noflux_incidence.R [life]

suppressMessages({ library(odelia); pkgload::load_all("plant", quiet = TRUE) })
life <- as.numeric(commandArgs(TRUE)[1]); if (is.na(life)) life <- 20

p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- life
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))

t0 <- Sys.time()
res <- run_scm(p, Environment("TF24"), Control(), collect = TRUE,
               refine_schedule = FALSE)
el <- as.numeric(Sys.time() - t0, "secs")

d <- as.data.frame(res$species)
d <- d[is.finite(d$transpiration) & is.finite(d$opt_psi_stem), ]
n <- nrow(d)
margin <- d$opt_psi_stem + d$opt_root_psi     # psi_stem - |collar|, -> 0 at the corner

cat(sprintf("life %.2f, %.1f s, %d cohort-time leaf records, %d steps\n\n",
            life, el, n, nrow(res$steps)))

cat("=== the zero-flux branch ===\n")
cat(sprintf("transpiration exactly 0          : %8d  (%.4f%%)\n",
            sum(d$transpiration == 0), 100 * mean(d$transpiration == 0)))
cat(sprintf("transpiration < 1e-12            : %8d  (%.4f%%)\n",
            sum(d$transpiration < 1e-12), 100 * mean(d$transpiration < 1e-12)))
cat(sprintf("stem pinned to collar (<1e-12)   : %8d  (%.4f%%)\n",
            sum(abs(margin) < 1e-12), 100 * mean(abs(margin) < 1e-12)))

cat("\n=== distance from the corner, psi_stem - |collar| (MPa) ===\n")
print(signif(quantile(margin, c(0, 1e-4, 1e-3, .01, .1, .5, .9, 1)), 4))
cat(sprintf("\nnegative margins (stem wetter than collar): %d\n", sum(margin < 0)))
cat(sprintf("margins below 1e-3 (GSS_tol_abs): %d  (%.4f%%)\n",
            sum(margin < 1e-3), 100 * mean(margin < 1e-3)))
cat(sprintf("margins below 1e-2: %d  (%.4f%%)\n",
            sum(margin < 1e-2), 100 * mean(margin < 1e-2)))

cat("\n=== uptake, for scale ===\n")
print(signif(quantile(d$E_up_, c(0, 1e-3, .01, .1, .5, .9, 1)), 4))
cat(sprintf("\nE_up_ exactly 0: %d;  E_up_ < 0 (redistribution): %d\n",
            sum(d$E_up_ == 0), sum(d$E_up_ < 0)))

cat("\n=== the growth gate (report 2 C1), for comparison ===\n")
g <- d$net_mass_production_dt
cat(sprintf("net_mass_production_dt <= 0: %d  (%.4f%%)\n", sum(g <= 0), 100 * mean(g <= 0)))
