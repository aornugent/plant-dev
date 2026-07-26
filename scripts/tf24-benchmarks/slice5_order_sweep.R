# T6 rung #4 -- OBSERVED ORDER of the composed mri_uptake scheme in the macro leg H.
#
# ** REWRITTEN after hard-won lesson #7. ** The first version of this script
# compared against a reference whose OUTER ODE tolerance was left at its 1e-4
# default (only the inner-solve tolerances were tightened). That reference carried
# ~4e-3 of its own error -- larger than the quantity being measured -- so the
# sweep appeared to show a "bias floor" and gave meaningless slopes (0.56, 1.69).
# It was the reference that was off, not the scheme: at ode_tol=1e-5 the reference
# moves onto mri_uptake's own converged limit (~35.24). Tolerances now come from
# converged_control.R, which sets BOTH families.
#
# Why order matters: if the composed scheme is capped at 2nd order -- by the Strang
# commutator (which involves the huge kappa') or by the per-leg affine anchor --
# then a 2-stage slow advance (mri_heun, already in odelia) holds the same accuracy
# at 2 member sweeps/leg instead of 3, a third off the irreducible per-leg floor.
#
# Regime: the SURVIVABLE DYNAMIC regime (seasonal drive about the sustaining mean),
# where the readout is well-conditioned and the reference survives -- NOT the stress
# bank, where J is non-convergent for every method (see the #550 investigation).
#
# Two independent estimates, distinct failure modes:
#   (a) vs the converged reference -- interpretable ONLY if the reference is truly
#       converged (the lesson above), and vulnerable to sign changes: a fortuitous
#       cancellation at one H reads as anomalously high accuracy.
#   (b) successive differences |J(H) - J(H/2)| ~ C H^p -- reference-FREE, immune to
#       any constant offset in the reference, and the slope to trust.
options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia)
  pkgload::load_all("/home/user/plant-dev/plant", export_all = TRUE, quiet = TRUE)
})
source("scripts/tf24-benchmarks/converged_control.R")

outdir <- "scripts/tf24-benchmarks/results/slice4_bank"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
logf <- file.path(outdir, "order_sweep.log")
say <- function(...) { cat(sprintf(...), file = logf, append = TRUE); flush(stdout()) }
cat("", file = logf)

LIFE <- 40; BIRTH <- 20; MEAN <- 1; AMP <- 0.3

# Reference tolerance: 1e-5, NOT tighter. Each decade costs ~4-5x (1e-4: 112s,
# 1e-5: 508s, 1e-6: >2900s and timed out), and 1e-5 is already ~10x more accurate
# than the quantity being measured at the operating point: J(1e-4)=35.1148736 ->
# J(1e-5)=35.2448663 is a 3.7e-3 move, so 1e-5's own residual is ~4e-4 relative
# while mri_uptake's error at the 7-day leg is ~3.5e-3. Buying 1e-6 would only
# matter for resolving errors below ~1e-4 -- and the sweep below shows a ~1e-3
# JITTER floor in J w.r.t. H that makes anything finer unmeasurable anyway.
REF_ODE_TOL <- 1e-5

run <- function(ctrl) {
  cfg <- list(traits = c(lma = 0.0825), env = list(),
              driver = list(rainfall_mean = MEAN, rainfall_amp_frac = AMP))
  s <- build_scenario(cfg, max_patch_lifetime = LIFE, ctrl = ctrl, birth_rate = BIRTH)
  mri_coupling_evals_reset()
  el <- system.time(J <- tryCatch(sum(run_scm(s$p, s$env, s$ctrl)$offspring_production),
                                  error = function(e) NA_real_))[["elapsed"]]
  list(J = J, coupling = mri_coupling_evals_get(), t = el)
}

say("survivable dynamic regime: mean=%.0f amp=%.1f life=%.0f birth=%.0f\n", MEAN, AMP, LIFE, BIRTH)

# The converged reference is expensive; cache it so re-runs of the sweep are cheap.
reffile <- file.path(outdir, sprintf("reference_odetol%.0e.rds", REF_ODE_TOL))
if (file.exists(reffile)) {
  ref <- readRDS(reffile); say("reference (cached): J = %.9g\n\n", ref$J)
} else {
  ref <- run(converged_control(ode_tol = REF_ODE_TOL))
  saveRDS(ref, reffile)
  say("reference @ ode_tol=%.0e: J = %.9g  (%.0fs)\n\n", REF_ODE_TOL, ref$J, ref$t)
}

DAYS <- c(14, 7, 3.5, 1.75)
res <- list()
say("%-8s %-16s %-11s %-11s %-10s %s\n", "H (d)", "J", "|J-J_ref|", "rel", "coupling", "t(s)")
for (d in DAYS) {
  r <- run(mri_uptake_control(days = d)); res[[as.character(d)]] <- r
  say("%-8.3f %-16.9g %-11.3e %-11.3e %-10.0f %.0f\n",
      d, r$J, abs(r$J - ref$J), abs(r$J - ref$J) / abs(ref$J), r$coupling, r$t)
}

J <- sapply(res, `[[`, "J"); H <- DAYS; err <- abs(J - ref$J)
fit <- function(x, y) { k <- y > 0 & is.finite(y)
  if (sum(k) < 2) NA_real_ else unname(coef(lm(log(y[k]) ~ log(x[k])))[2]) }
dif <- abs(diff(J)); Hd <- H[-length(H)]
say("\n(a) order vs reference          : p = %.2f\n", fit(H, err))
say("(b) order from successive diffs : p = %.2f   [diffs: %s]   <- PRIMARY\n",
    fit(Hd, dif), paste(sprintf("%.2e", dif), collapse = " "))

# Asymptotic-regime check. In a clean convergence regime successive |dJ| shrink by
# a CONSTANT factor 2^p as H halves. Ratios that are non-monotone (or < 1) mean the
# scheme is NOT in an asymptotic regime over this H range and NO order exists to be
# measured -- the differences are dominated by a non-smooth dependence of J on H
# (leg boundaries aligning differently with the member-introduction schedule and
# the forcing, plus the adaptive ramp from ode_step_size_initial). Report the floor
# rather than fitting a slope through noise.
if (length(dif) >= 2) {
  rat <- dif[-length(dif)] / dif[-1]
  say("    successive-diff ratios (expect ~2^p, constant): %s\n",
      paste(sprintf("%.2f", rat), collapse = " "))
  if (any(rat < 1) || max(rat) / min(rat) > 4) {
    say("    => NOT an asymptotic regime: ratios are non-monotone/inconsistent.\n")
    say("       Jitter floor in J w.r.t. H ~ %.2e absolute (%.1e relative).\n",
        max(dif[-1]), max(dif[-1]) / abs(ref$J))
    say("       No order is extractable above this floor, at ANY reference quality;\n")
    say("       the 2-vs-3-sweep question cannot be settled by an H-sweep. Settle it\n")
    say("       instead by a DIRECT A/B: rebuild with mri_heun and compare J and cost\n")
    say("       at the fixed operating leg against kutta3.\n")
  } else {
    say("    => asymptotic. p ~ 3 => the 3rd stage buys real order (keep 3 sweeps/leg);\n")
    say("       p ~ 2 => capped by the Strang split or the affine anchor, so mri_heun\n")
    say("       should hold the accuracy at 2 sweeps/leg -- a third off the floor.\n")
  }
}
saveRDS(list(ref = ref, res = res, days = DAYS), file.path(outdir, "order_sweep.rds"))
say("ALLDONE\n")
