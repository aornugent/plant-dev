# T6 rung #4 -- OBSERVED ORDER of the composed mri_uptake scheme in the macro leg H.
#
# Why: the kutta3-vs-forward-Euler comparison (1.8e-4 vs 12% at a weekly leg)
# conflates ORDER with CONSTANT. If the composed scheme is actually capped at 2nd
# order -- by the Strang split (commutator involves the huge kappa') or by the
# per-leg affine-anchor error -- then a 2-stage slow advance (mri_heun, already in
# odelia) buys the same accuracy at 2 member sweeps/leg instead of 3, i.e. a third
# off the irreducible per-leg cost floor. If it is genuinely 3rd order, we now know
# what the third sweep buys.
#
# Regime: the SURVIVABLE DYNAMIC regime (seasonal drive about the sustaining mean),
# where the readout is well-conditioned (J ~ 35) and the rkck reference survives --
# NOT the stress bank, where J is non-convergent for every method and an order
# measurement would be meaningless (see the #550 investigation).
#
# Two independent order estimates, because each has a distinct failure mode:
#   (a) vs the converged rkck reference -- contaminated if the reference has its
#       own residual error, and vulnerable to sign changes (fortuitous cancellation
#       at one H reads as anomalously high accuracy).
#   (b) successive differences |J(H) - J(H/2)| ~ C H^p -- reference-free, immune to
#       a constant offset in the reference, and the more trustworthy slope.
options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia)
  pkgload::load_all("/home/user/plant-dev/plant", export_all = TRUE, quiet = TRUE)
})
cat("loaded\n"); flush(stdout())

outdir <- "scripts/tf24-benchmarks/results/slice4_bank"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
LIFE <- 40; BIRTH <- 20; MEAN <- 1; AMP <- 0.3

base_ctrl <- function() { c <- control(); c$GSS_tol_abs <- 1e-12; c$ci_abs_tol <- 1e-12; c }
mri_ctrl <- function(days) { c <- base_ctrl()
  c$ode_method <- "mri_uptake"; c$compute_uptake_jacobian <- TRUE; c$n_collocation_nodes <- 0
  c$mri_uptake_tol <- 1e-2; c$mri_uptake_nmicro <- 40; c$ode_step_size_max <- days / 365; c }

run <- function(ctrl) {
  cfg <- list(traits = c(lma = 0.0825), env = list(),
              driver = list(rainfall_mean = MEAN, rainfall_amp_frac = AMP))
  s <- build_scenario(cfg, max_patch_lifetime = LIFE, ctrl = ctrl, birth_rate = BIRTH)
  mri_coupling_evals_reset()
  el <- system.time(J <- tryCatch(sum(run_scm(s$p, s$env, s$ctrl)$offspring_production),
                                  error = function(e) NA_real_))[["elapsed"]]
  list(J = J, coupling = mri_coupling_evals_get(), t = el)
}

cat(sprintf("survivable dynamic regime: mean=%.0f amp=%.1f life=%.0f birth=%.0f\n\n",
            MEAN, AMP, LIFE, BIRTH))
ref <- run(base_ctrl())
cat(sprintf("rkck reference: J = %.9g  (%.0fs)\n\n", ref$J, ref$t)); flush(stdout())

DAYS <- c(14, 7, 3.5, 1.75, 0.875)
res <- list()
cat(sprintf("%-8s %-16s %-11s %-10s %s\n", "H (d)", "J", "|J-J_ref|", "coupling", "t(s)"))
for (d in DAYS) {
  r <- run(mri_ctrl(d)); res[[as.character(d)]] <- r
  cat(sprintf("%-8.3f %-16.9g %-11.3e %-10.0f %.0f\n",
              d, r$J, abs(r$J - ref$J), r$coupling, r$t)); flush(stdout())
}

J <- sapply(res, `[[`, "J"); H <- DAYS
err <- abs(J - ref$J)
fit <- function(x, y) { k <- y > 0 & is.finite(y)
  if (sum(k) < 2) NA_real_ else unname(coef(lm(log(y[k]) ~ log(x[k])))[2]) }

cat(sprintf("\n(a) order vs reference          : p = %.2f\n", fit(H, err)))
# (b) successive differences: |J(H_i) - J(H_{i+1})| ~ C H_i^p  (reference-free)
dif <- abs(diff(J)); Hd <- H[-length(H)]
cat(sprintf("(b) order from successive diffs : p = %.2f   [diffs: %s]\n",
            fit(Hd, dif), paste(sprintf("%.2e", dif), collapse = " ")))
cat("\nReading: p ~ 3 => the 3rd stage buys real order, keep 3 sweeps/leg.\n")
cat("         p ~ 2 => capped by the Strang split or the affine anchor; a 2-stage\n")
cat("                  slow advance (mri_heun) should hold the same accuracy at\n")
cat("                  2 sweeps/leg -- a third off the per-leg floor. Verify by rebuild.\n")
saveRDS(list(ref = ref, res = res, days = DAYS), file.path(outdir, "order_sweep.rds"))
cat("ALLDONE\n")
