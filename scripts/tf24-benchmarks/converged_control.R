# Shared tolerance helpers for TF24 accuracy work.
#
# ------------------------------------------------------------------------------
# WHY THIS FILE EXISTS (hard-won lesson, 2026-07-25 -- read before writing a gate)
# ------------------------------------------------------------------------------
# plant's Control carries TWO INDEPENDENT FAMILIES of tolerance, and setting one
# family to 1e-12 does NOT converge the run:
#
#   (A) INNER-SOLVE tolerances -- GSS_tol_abs, ci_abs_tol. These converge the
#       per-cohort physiology solve and the competition integral at a FIXED state.
#   (B) OUTER ODE tolerances   -- ode_tol_rel, ode_tol_abs. These converge the
#       TIME INTEGRATION of the whole coupled system. **DEFAULT 1e-4.**
#
# For an entire session we wrote `ctrl$GSS_tol_abs <- 1e-12; ctrl$ci_abs_tol <- 1e-12`
# and called the result "the converged reference". It was not: ode_tol_rel/abs sat
# at their 1e-4 default, so the reference carried ~4e-3 of its own time-integration
# error. Measured, in the survivable dynamic regime (mean=1, amp=0.3, life=40):
#
#     ode_tol = 1e-4 (the "reference")   J = 35.1148736
#     ode_tol = 1e-5                     J = 35.2448663      <- moved 3.7e-3
#     mri_uptake's own converged limit   J ~ 35.24
#
# i.e. the *reference* was the outlier, and the scheme under test agreed with the
# properly-converged answer. Every accuracy number measured that way was wrong --
# and wrong in the PESSIMISTIC direction, which is why it went unnoticed: the
# scheme looked worse than it was, so nothing appeared "too good to be true".
#
# THE RULE: an accuracy reference must converge BOTH families. Never hand-roll the
# tolerance block -- call converged_control() below, so the two families cannot
# drift apart again. If you need to know which family limits a result, sweep them
# SEPARATELY (inner_tol vs ode_tol) and report both.
#
# NOTE for multirate methods: ode_method="mri_uptake" reports yerr=0 (always
# accept), so ode_tol_rel/abs do NOT control it -- its accuracy is set by
# ode_step_size_max (the macro leg), mri_uptake_tol and mri_uptake_nmicro. That
# asymmetry is exactly why an under-converged reference silently mis-scored it.

# A control converged in BOTH tolerance families.
#   ode_tol   -- the outer time-integration tolerance (the one we forgot).
#                1e-6 is near-converged in the regimes tested; 1e-5 is ~1e-4 off;
#                the 1e-4 DEFAULT is unusable as a reference.
#   inner_tol -- the per-solve tolerance (GSS_tol_abs, ci_abs_tol).
converged_control <- function(ode_tol = 1e-6, inner_tol = 1e-12, ...) {
  ctrl <- control(...)
  ctrl$GSS_tol_abs <- inner_tol
  ctrl$ci_abs_tol  <- inner_tol
  ctrl$ode_tol_rel <- ode_tol
  ctrl$ode_tol_abs <- ode_tol
  ctrl
}

# The mri_uptake operating point, layered on a converged control. `ode_tol` is
# carried for the inner adaptive machinery but does NOT set this method's
# accuracy (see the note above) -- `days` (the macro leg) does.
mri_uptake_control <- function(days = 7, tol = 1e-2, nmicro = 40,
                               ode_tol = 1e-6, inner_tol = 1e-12) {
  ctrl <- converged_control(ode_tol = ode_tol, inner_tol = inner_tol)
  ctrl$ode_method              <- "mri_uptake"
  ctrl$compute_uptake_jacobian <- TRUE
  ctrl$n_collocation_nodes     <- 0
  ctrl$mri_uptake_tol          <- tol
  ctrl$mri_uptake_nmicro       <- nmicro
  ctrl$ode_step_size_max       <- days / 365
  ctrl
}
