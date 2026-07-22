# T6 Slice 4 -- PATH 1: self-convergence of mri_uptake on the real bank.
#
# The bank traces drive the stand to near-extinction (offspring ~1e-10) at every
# lma, and global-RK rkck crashes on half of them, so there is no external
# reference on the actual hard scenarios. Instead we validate mri_uptake by
# self-convergence: refine its own time-discretization toward a limit and show
# the production-setting answer is already converged.
#
# The accuracy argument is a two-part chain:
#   (a) the affine refresh MECHANISM is validated offline -- 3b-ii falsifier
#       (soil traj <=5.5e-4) + the step-1 toy (offspring <=5e-4);
#   (b) the TIME-discretization is converged -- THIS script.
# (a) says the coupling model is accurate; (b) says the macro/micro stepping is
# resolved; together the composite is trustworthy with no reference.
#
# Design: the cohort/demographic mesh is held FIXED across every rung (same
# n_collocation_nodes, same schedule), so the movement in offspring is purely the
# ODE/macro discretization -- NOT the demographic mesh. A separate cohort-mesh
# check (tighten schedule at the finest rung) confirms the mesh is not the
# bottleneck. Near-extinction does not confound self-convergence: this is ONE
# method approaching its OWN limit, not two methods differing (lesson #4 was
# about cross-method relative error).
options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia)
  pkgload::load_all("/home/user/plant-dev/plant", export_all = TRUE, quiet = TRUE)
})
cat("loaded\n"); flush(stdout())

datadir <- "scripts/tf24-benchmarks/data"
outdir  <- "scripts/tf24-benchmarks/results/slice4_bank"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
LMA <- 0.0825; BIRTH <- 20

# refinement ladder: primary axis = macro leg cap (step-2 pinned the order-1 macro
# slow-advance as the dominant error). The final rung ALSO tightens the trust
# monitor + micro count to prove neither is the limiter. Row 1 is the production
# operating point (matches slice4_scenario_bank.R and the validated gate).
RUNGS <- list(
  list(tag = "prod  (7d, tol1e-2, n40)",  step = 7   / 365, tol = 1e-2, nmicro = 40),
  list(tag = "half  (3.5d,tol1e-2, n40)", step = 3.5 / 365, tol = 1e-2, nmicro = 40),
  list(tag = "qtr   (1.75d,tol1e-2,n40)", step = 1.75/ 365, tol = 1e-2, nmicro = 40),
  list(tag = "fine  (1.75d,tol1e-3,n80)", step = 1.75/ 365, tol = 1e-3, nmicro = 80)
)

mri_ctrl <- function(rung) {
  ctrl <- control()
  ctrl$GSS_tol_abs <- 1e-12; ctrl$ci_abs_tol <- 1e-12
  ctrl$ode_method <- "mri_uptake"; ctrl$compute_uptake_jacobian <- TRUE
  ctrl$n_collocation_nodes <- 0
  ctrl$mri_uptake_tol <- rung$tol; ctrl$mri_uptake_nmicro <- rung$nmicro
  ctrl$ode_step_size_max <- rung$step
  ctrl
}

run_rung <- function(nm, rung) {
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- length(b$rain); times <- (0:(nd - 1)) / 365; life <- max(times)
  mkenv <- function() { e <- Environment("TF24")
    e$extrinsic_drivers_set_variable("rainfall", times, b$rain); e }
  mk <- function() { p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- life
    add_strategies(p, trait_matrix(LMA, "lma"), hyperpar = TF24_hyperpar,
                   birth_rate = list(BIRTH)) }
  mri_coupling_evals_reset()
  off <- tryCatch(sum(run_scm(mk(), mkenv(), mri_ctrl(rung))$offspring_production),
                  error = function(e) { attr(off, "err") <<- conditionMessage(e); NA_real_ })
  list(off = off, coupling = mri_coupling_evals_get())
}

# mri_uptake completes these five (intense_storms hits the cohort-interpolation
# ceiling -- a separate SCM limit, not the refresh).
scenarios <- c("whiplash", "extended_drought", "dry_to_wet", "long_horizon", "drydown")

rows <- list()
for (nm in scenarios) {
  cat(sprintf("\n== %s ==\n", nm)); flush(stdout())
  offs <- numeric(length(RUNGS)); coup <- numeric(length(RUNGS))
  for (i in seq_along(RUNGS)) {
    r <- run_rung(nm, RUNGS[[i]]); offs[i] <- r$off; coup[i] <- r$coupling
    cat(sprintf("  %-26s off=%.8g  coupling=%.0f\n", RUNGS[[i]]$tag, offs[i], coup[i]))
    flush(stdout())
  }
  fin <- offs[length(offs)]
  relconv <- abs(offs - fin) / max(abs(fin), 1e-30)   # each rung vs self-converged limit
  cat(sprintf("  --> production-vs-converged rel error: %.3e   (successive: %s)\n",
              relconv[1], paste(sprintf("%.2e", abs(diff(offs)) / max(abs(fin),1e-30)), collapse=" ")))
  rows[[nm]] <- list(scenario = nm, offs = offs, coupling = coup,
                     rung_tags = sapply(RUNGS, `[[`, "tag"),
                     prod_vs_conv = relconv[1], relconv = relconv)
}

saveRDS(rows, file.path(outdir, "selfconv.rds"))
cat("\nsaved", file.path(outdir, "selfconv.rds"), "\n")
cat("ALLDONE\n")
