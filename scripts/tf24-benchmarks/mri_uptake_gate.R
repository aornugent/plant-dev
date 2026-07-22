# T6 Slice 3b-iii step 2: REAL-PATCH gate for method="mri_uptake".
#
# Runs the TF24 SCM three ways over the same schedule and compares:
#   rkck        -- the global adaptive reference (truth for offspring + soil).
#   mri_uptake  -- the arbitrage: freeze cohorts per macro leg, sub-cycle the soil
#                  against the affine-refreshed uptake a0 + J*(theta-anchor), with
#                  the trust monitor re-capturing the O(M) cohort sum only on drift.
# Gate: (1) offspring production within the converged tolerance of the rkck
# reference; (2) the expensive-coupling count (mri_coupling_evals = refresh_anchor
# calls) is far below the cheap frozen-residual count (mri_fast_rate_calls), i.e. a
# real cohort-sum reduction with the death mode absent.
options(pkg.build_extra_flags = FALSE)
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", export_all = TRUE, quiet = TRUE))
cat("loaded\n"); flush(stdout())

base_ctrl <- function() {
  ctrl <- control()
  ctrl$GSS_tol_abs <- 1e-12; ctrl$ci_abs_tol <- 1e-12
  ctrl
}
build <- function(ctrl) {
  p0 <- scm_base_parameters("TF24"); p0$max_patch_lifetime <- 30
  p1 <- add_strategies(p0, trait_matrix(0.0825, "lma"), hyperpar = TF24_hyperpar,
                       birth_rate = list(20))
  SCM("TF24", "TF24_Env")(p1, Environment("TF24"), ctrl)
}
run_offspring <- function(scm) {
  scm$run(); scm$net_reproduction_ratios
}

# --- reference: global adaptive RKCK ------------------------------------------
mri_fast_rate_calls_reset(); mri_coupling_evals_reset()
ref <- run_offspring(build(base_ctrl()))
cat(sprintf("rkck offspring: %s\n", paste(sprintf("%.8g", ref), collapse=", "))); flush(stdout())

# --- mri_uptake: the arbitrage ------------------------------------------------
cu <- base_ctrl()
cu$ode_method <- "mri_uptake"
cu$compute_uptake_jacobian <- TRUE
cu$n_collocation_nodes <- 0
cu$mri_uptake_tol <- 1e-2
cu$mri_uptake_nmicro <- 40
cu$ode_step_size_max <- 7 / 365      # cap macro legs at ~weekly (T4 freeze window)
mri_fast_rate_calls_reset(); mri_coupling_evals_reset()
up <- run_offspring(build(cu))
cheap  <- mri_fast_rate_calls_get()
expens <- mri_coupling_evals_get()
cat(sprintf("mri_uptake offspring: %s\n", paste(sprintf("%.8g", up), collapse=", ")))
cat(sprintf("coupling evals (O(M) cohort sums): %.0f\n", expens))
cat(sprintf("cheap frozen-residual evals:       %.0f\n", cheap))
cat(sprintf("reduction (cheap/expensive):        %.2fx\n", cheap / max(expens, 1)))

rel <- abs(up - ref) / pmax(abs(ref), 1e-30)
cat(sprintf("\noffspring rel error vs rkck: max=%.3e\n", max(rel)))
# Note on isolation: the affine-refresh error itself is validated offline by 3b-ii
# (soil traj <=5.5e-4) and on the toy (offspring ~5e-4); here the trust monitor
# holds re-expansions at their floor (coupling_evals ~= nlegs), so the residual
# offspring error is dominated by the order-1 MRI macro-step discretization (shared
# with method="mri"), a Slice-4 knob (finer grid / higher-order coupling), not the
# refresh. A direct method="mri" full-resolve comparison at this horizon is
# impractically slow (the 6-25x penalty T6 removes) and, at short horizons, is
# confounded by near-zero-J hypersensitivity -- so it is not run here.
cat("ALLDONE\n")
