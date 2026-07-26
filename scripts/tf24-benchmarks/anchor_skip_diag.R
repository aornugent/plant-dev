# TEMPORARY diagnostic: how far is the anchor published by slow_rates from the
# anchor refresh_anchor would have computed by sweeping at the same (x, u)?
#
# Gate 2 showed the skip works mechanically (captures 0, 2 sweeps/leg, 1.5x
# wall-clock) but moved offspring by 1.5e-2 at amp=0.3 -- so the two are NOT the
# same values, contradicting the premise. This measures the discrepancy directly
# instead of reasoning about it further: with the diag on, a matched theta still
# sweeps, compares published vs swept (a0 and the Jacobian), and accumulates the
# max relative difference. The anchor actually used is left as the published one,
# so the trajectory is the same one gate 2 measured.
#
# Reading it:
#   ~1e-16      -> identical; the drift is elsewhere (look at WHEN the anchor is
#                  placed, not what it holds)
#   O(1e-3..1)  -> the published anchor is genuinely different, i.e. slow_rates
#                  and refresh_anchor do not evaluate the same thing at the same
#                  (x, u) -- the premise is wrong and the skip must be reverted
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant", export_all=TRUE, quiet=TRUE)})
source("scripts/tf24-benchmarks/converged_control.R")
cat("loaded\n"); flush(stdout())

for (amp in c(0, 0.3)) {
  cfg <- list(traits = c(lma = 0.0825), env = list(),
              driver = list(rainfall_mean = 1, rainfall_amp_frac = amp))
  ctrl <- mri_uptake_control(days = 7, tol = 1e-2, nmicro = 40, ode_tol = 1e-5)
  s <- build_scenario(cfg, max_patch_lifetime = 10, ctrl = ctrl, birth_rate = 20)
  anchor_skip_diag_reset(); anchor_skip_diag_set(TRUE)
  mri_coupling_evals_reset()
  off <- sum(run_scm(s$p, s$env, s$ctrl)$offspring_production)
  anchor_skip_diag_set(FALSE)
  cat(sprintf("amp=%.1f  offspring=%.8g  skips=%.0f  genuine_captures=%.0f  max_rel_diff=%.3e\n",
              amp, off, anchor_skip_checks_get(), mri_coupling_evals_get(),
              anchor_skip_max_reldiff_get()))
  flush(stdout())
}
cat("ALLDONE\n")
