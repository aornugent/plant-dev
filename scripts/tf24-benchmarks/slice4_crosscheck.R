# T6 Slice 4 -- PATH 2: external (rkck-referenced) accuracy cross-check on a
# survivable DYNAMIC regime.
#
# The bank stress-traces drive the stand to extinction at every lma AND every
# rainfall scale (measured), and rkck crashes on half of them -- so they give no
# well-posed reference-based accuracy number. This cross-check instead uses the
# model's own seasonal driver (build_scenario's rainfall_mean + rainfall_amp_frac)
# around the SUSTAINING mean (=1, the level at which the validated gate gives
# offspring ~1.03), dialing up seasonal amplitude to add real time-varying
# integrator stress while the stand stays alive (offspring O(1)). In that regime
# offspring is well-conditioned, so rel error vs the rkck reference is meaningful
# (no lesson-#4 hypersensitivity), and rkck survives -- giving mri_uptake an
# external accuracy anchor to complement the on-bank self-convergence (path 1).
options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia)
  pkgload::load_all("/home/user/plant-dev/plant", export_all = TRUE, quiet = TRUE)
})
cat("loaded\n"); flush(stdout())

outdir <- "scripts/tf24-benchmarks/results/slice4_bank"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
LIFE <- 40; BIRTH <- 20; MEAN <- 1

base_ctrl <- function() { c <- control(); c$GSS_tol_abs <- 1e-12; c$ci_abs_tol <- 1e-12; c }
mri_ctrl <- function() { c <- base_ctrl()
  c$ode_method <- "mri_uptake"; c$compute_uptake_jacobian <- TRUE; c$n_collocation_nodes <- 0
  c$mri_uptake_tol <- 1e-2; c$mri_uptake_nmicro <- 40; c$ode_step_size_max <- 7 / 365; c }

# amp_frac=0 is the constant-rainfall gate; higher = stronger seasonality (trough
# -> 0 at amp_frac=1, the extreme-seasonality case). Reuses build_scenario.
run_amp <- function(amp, ctrl_fn) {
  cfg <- list(traits = c(lma = 0.0825),
              env = list(),
              driver = list(rainfall_mean = MEAN, rainfall_amp_frac = amp))
  s <- build_scenario(cfg, max_patch_lifetime = LIFE, ctrl = ctrl_fn(), birth_rate = BIRTH)
  mri_coupling_evals_reset(); patch_rhs_calls_reset()
  t <- system.time(off <- tryCatch(sum(run_scm(s$p, s$env, s$ctrl)$offspring_production),
                                   error = function(e) NA_real_))[["elapsed"]]
  list(off = off, t = t, coupling = mri_coupling_evals_get(), rhs = patch_rhs_calls_get())
}

AMPS <- c(0, 0.3, 0.6, 0.9)
cat(sprintf("survivable dynamic cross-check: mean=%.0f, life=%.0f, birth=%.0f\n", MEAN, LIFE, BIRTH))
cat(sprintf("%-6s | %-13s %-13s | rel      | cohort rkck/mri (x) | t rkck/mri (x)\n",
            "amp", "rkck", "mri_uptake"))
rows <- list()
for (amp in AMPS) {
  R <- run_amp(amp, base_ctrl); M <- run_amp(amp, mri_ctrl)
  rel <- abs(M$off - R$off) / max(abs(R$off), 1e-30)
  cat(sprintf("%-6.1f | %-13.7g %-13.7g | %.2e | %6.0f/%-6.0f %.1fx | %.1f/%.1f %.1fx\n",
              amp, R$off, M$off, rel, R$rhs, M$coupling, R$rhs / max(M$coupling, 1),
              R$t, M$t, R$t / max(M$t, 1e-9)))
  flush(stdout())
  rows[[as.character(amp)]] <- list(amp = amp, off_rkck = R$off, off_mri = M$off, rel = rel,
                                    rhs_rkck = R$rhs, coupling_mri = M$coupling,
                                    t_rkck = R$t, t_mri = M$t)
}
saveRDS(rows, file.path(outdir, "crosscheck.rds"))
cat("\nsaved", file.path(outdir, "crosscheck.rds"), "\nALLDONE\n")
