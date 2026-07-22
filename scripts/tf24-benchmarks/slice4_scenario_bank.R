# T6 Slice 4 -- end-to-end scenario-bank acceptance for ode_method="mri_uptake".
#
# The real acceptance test: run the full TF24 scenario bank (dynamic rainfall:
# storms, whiplash, droughts, rewetting, a 70-yr horizon, a whole-profile
# drydown) with (a) the global adaptive RKCK reference and (b) the mri_uptake
# arbitrage, and compare offspring production + cohort-solve cost + wall-clock +
# the trust-monitor re-expansion rate.
#
# Reuses the established bank-runner collateral (classifier_capture.R's
# mkenv/mk/run_scm pattern, birth_rate=1, the mri_diag counters) so these
# numbers sit in the same regime as our prior bank work and are comparable.
#
# Acceptance (handoff Slice 4 step 4): offspring within the converged-J tol on
# EVERY scenario AND a net cohort-solve reduction (target 10-100x; 3b-ii oracle
# bound was 2.9x-40x per window). The trust monitor must not collapse to global
# RK (re-expansions ~= nmicro every leg = DEAD).
options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia)
  pkgload::load_all("/home/user/plant-dev/plant", export_all = TRUE, quiet = TRUE)
})
cat("loaded\n"); flush(stdout())

datadir <- "scripts/tf24-benchmarks/data"
outdir  <- "scripts/tf24-benchmarks/results/slice4_bank"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

NMICRO <- 40
LMA    <- 0.0825
# birth_rate=20 keeps every scenario in a healthy-J regime: with birth_rate=1 the
# harsher scenarios (intense_storms, drydown) barely reproduce (offspring ~1e-5),
# where relative offspring error is dominated by J hypersensitivity (hard-won
# lesson #4), not by the refresh -- exactly the confound Slice 4 must avoid. This
# matches the validated mri_uptake gate.
BIRTH  <- 20

# converged inner tol shared by both runs (offspring truth, not FD-noise-limited)
base_ctrl <- function() {
  ctrl <- control()
  ctrl$GSS_tol_abs <- 1e-12
  ctrl$ci_abs_tol  <- 1e-12
  ctrl
}
rkck_ctrl <- function() base_ctrl()      # ode_method="" == global adaptive rkck
mri_ctrl <- function() {
  ctrl <- base_ctrl()
  ctrl$ode_method            <- "mri_uptake"
  ctrl$compute_uptake_jacobian <- TRUE
  ctrl$n_collocation_nodes   <- 0
  ctrl$mri_uptake_tol        <- 1e-2
  ctrl$mri_uptake_nmicro     <- NMICRO
  ctrl$ode_step_size_max     <- 7 / 365    # cap macro legs at ~weekly (T4 window)
  ctrl
}

run_one <- function(nm) {
  b    <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  rain <- b$rain; nd <- length(rain); times <- (0:(nd - 1)) / 365
  life <- max(times)
  mkenv <- function() { e <- Environment("TF24")
    e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
  mk <- function() { p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- life
    add_strategies(p, trait_matrix(LMA, "lma"), hyperpar = TF24_hyperpar,
                   birth_rate = list(BIRTH)) }

  # each run wrapped so one crash (e.g. a non-finite under a violent storm) does
  # not kill the whole bank -- record which method failed as a Slice-4 finding.
  safe <- function(ctrl) {
    off <- NA_real_; err <- NULL
    t <- system.time(off <- tryCatch(sum(run_scm(mk(), mkenv(), ctrl)$offspring_production),
                                     error = function(e) { err <<- conditionMessage(e); NA_real_ }))[["elapsed"]]
    list(off = off, t = t, err = err)
  }

  # --- reference: global adaptive RKCK ----------------------------------------
  mri_fast_rate_calls_reset(); mri_coupling_evals_reset(); patch_rhs_calls_reset()
  R <- safe(rkck_ctrl()); off_ref <- R$off; t_ref <- R$t
  rhs_ref <- patch_rhs_calls_get()

  # --- mri_uptake: the arbitrage ----------------------------------------------
  mri_fast_rate_calls_reset(); mri_coupling_evals_reset(); patch_rhs_calls_reset()
  M <- safe(mri_ctrl()); off_mri <- M$off; t_mri <- M$t
  cheap  <- mri_fast_rate_calls_get()      # cheap frozen-residual micro-steps
  expens <- mri_coupling_evals_get()       # O(M) cohort sums (refresh_anchor)

  # re-expansion rate: each leg spends nmicro cheap steps => nlegs ~= cheap/nmicro,
  # each leg has 1 mandatory capture => reexpansions = expens - nlegs.
  nlegs  <- cheap / NMICRO
  reexp_rate <- if (nlegs > 0) expens / nlegs - 1 else NA_real_

  list(scenario = nm, desc = b$desc, life = life,
       offspring_rkck = off_ref, offspring_mri = off_mri,
       err_rkck = R$err, err_mri = M$err,
       rel = abs(off_mri - off_ref) / max(abs(off_ref), 1e-30),
       coupling_evals = expens, cheap_evals = cheap, rhs_rkck = rhs_ref,
       # cohort-solve reduction: rkck resolves the O(M) sum on every RHS eval;
       # mri_uptake only on refresh. Both are O(M) cohort sums, so this is the
       # apples-to-apples cohort-solve ratio.
       cohort_reduction = rhs_ref / max(expens, 1),
       micro_reduction  = cheap / max(expens, 1),
       reexp_rate = reexp_rate,
       t_rkck = t_ref, t_mri = t_mri, speedup = t_ref / max(t_mri, 1e-9))
}

scenarios <- c("intense_storms", "whiplash", "extended_drought",
               "dry_to_wet", "long_horizon", "drydown")
scenarios <- scenarios[file.exists(file.path(datadir, paste0(scenarios, ".rds")))]

rows <- list()
for (nm in scenarios) {
  r <- run_one(nm)
  rows[[nm]] <- r
  cat(sprintf(
    "%-17s life=%2.0f  off rkck=%.6g mri=%.6g  rel=%.2e | cohort-solves rkck=%.0f mri=%.0f (%.1fx)  reexp/leg=%.2f | t %.1f/%.1fs (%.1fx)%s\n",
    nm, r$life, r$offspring_rkck, r$offspring_mri, r$rel,
    r$rhs_rkck, r$coupling_evals, r$cohort_reduction, r$reexp_rate,
    r$t_rkck, r$t_mri, r$speedup,
    if (!is.null(r$err_rkck)) paste0("  [rkck ERR: ", r$err_rkck, "]") else
    if (!is.null(r$err_mri))  paste0("  [mri ERR: ",  r$err_mri,  "]") else ""))
  flush(stdout())
}

tab <- do.call(rbind, lapply(rows, function(r) data.frame(
  scenario = r$scenario, life = r$life,
  offspring_rkck = r$offspring_rkck, offspring_mri = r$offspring_mri, rel = r$rel,
  cohort_rkck = r$rhs_rkck, cohort_mri = r$coupling_evals,
  cohort_reduction = r$cohort_reduction, reexp_per_leg = r$reexp_rate,
  t_rkck = r$t_rkck, t_mri = r$t_mri, speedup = r$speedup)))
saveRDS(list(table = tab, rows = rows), file.path(outdir, "bank.rds"))
cat("\nsaved", file.path(outdir, "bank.rds"), "\n")
cat("ALLDONE\n")
