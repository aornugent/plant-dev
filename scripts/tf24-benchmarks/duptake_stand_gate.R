# T6 Slice 3b-i GATE: the STAND uptake Jacobian d(a_i)/d(theta_k)
# (Patch::assemble_duptake_jacobian, the density-weighted aggregation of the
# per-leaf Jacobian + retention chain) vs a central difference of the stand
# coupling aggregate a (Patch::resource_depletion) w.r.t. the soil ODE state.
#
# Unlike the Slice-3a re-gate (per-LEAF Jacobian on a single Leaf), this exercises
# the WHOLE aggregation over a realistic frozen cohort distribution: individual ->
# node (density) -> species (trapezium) -> patch (sum/area) + the retention chain
# folded in by the TF24 fill. Convention is clean here: both sides are in
# soil-moisture (theta) space, so no sign flip (cf. the inverted-potential leaf gate).
options(pkg.build_extra_flags = FALSE)
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", export_all = TRUE, quiet = TRUE))
cat("loaded\n"); flush(stdout())
outdir <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# --- build a realistic frozen cohort distribution via a short SCM run ----------
p0 <- scm_base_parameters("TF24")
p0$max_patch_lifetime <- 30
env  <- Environment("TF24")
ctrl <- control()
ctrl$compute_uptake_jacobian <- TRUE     # enable the gated per-cohort fill
# Tight inner tolerances so the full-resolve FD reference is clean (cf. Slice-3a:
# the operating-point re-solve contains inner root-finds; at default tol ~1e-6 the
# weakly-coupled off-diagonal response of the dominant layer-1 uptake is lost in
# solve noise). The analytic fill's own FD probes benefit too.
ctrl$GSS_tol_abs <- 1e-12
ctrl$ci_abs_tol  <- 1e-12
p1 <- add_strategies(p0, trait_matrix(0.0825, "lma"),
                     hyperpar = TF24_hyperpar, birth_rate = list(20))
scm <- SCM("TF24", "TF24_Env")(p1, env, ctrl)
scm$run()                                  # run to completion; grab the final patch
patch <- scm$patch
ncohort <- patch$size
cat(sprintf("built patch: %d cohorts at t=%.3f\n", ncohort, patch$time)); flush(stdout())

env_size <- env$ode_size
ns <- env$get_soil_number_of_depths()
y0 <- patch$ode_state
slow <- length(y0) - env_size            # cohort block length (soil at slow + [0..ns))
soil_idx <- slow + seq_len(ns)           # 1-based indices of the soil slots in y0
t_now <- patch$time
cat(sprintf("ode_size=%d slow=%d env_size=%d ns=%d soil-slot theta0=[%s]\n",
            length(y0), slow, env_size, ns,
            paste(sprintf("%.4f", y0[soil_idx]), collapse=", "))); flush(stdout())

# stand a at a prescribed soil-moisture vector theta (cohorts frozen at y0)
stand_a_soil <- function(theta) {
  y <- y0; y[soil_idx] <- theta
  patch$set_ode_state(y, t_now)
  patch$compute_rates()
  patch$resource_depletion()[seq_len(ns)]   # soil block of the aggregate
}

# analytic stand Jacobian at a prescribed theta
stand_jac_soil <- function(theta) {
  y <- y0; y[soil_idx] <- theta
  patch$set_ode_state(y, t_now)
  patch$compute_rates()
  matrix(patch$assemble_duptake_jacobian(), ns, ns, byrow = TRUE)  # d a_i / d theta_k
}

# Adaptive-h central difference per soil layer. The true coupling da/dtheta spans
# ~3 orders of magnitude across the moisture range (retention n_psi*psi/theta is
# huge near the dry limit, ~0 near saturation), so no single FD step clears the
# operating-point solve's noise floor in wet AND resolves the strong curvature in
# dry. For each column we sweep relative h over a grid and take the Richardson
# plateau: the h where central(h) and central(2h) agree best, extrapolated. That
# picks each column's own trust region and reports how well FD could resolve it
# (fd_floor = the residual plateau disagreement, an honest noise indicator).
HGRID <- c(1e-4, 3e-4, 1e-3, 3e-3, 1e-2, 3e-2, 1e-1)
cdiff <- function(theta, k, hrel) {
  hk <- hrel * max(1e-3, abs(theta[k]))
  tp <- theta; tp[k] <- theta[k] + hk
  tm <- theta; tm[k] <- theta[k] - hk
  (stand_a_soil(tp) - stand_a_soil(tm)) / (2 * hk)
}
fd_col_adaptive <- function(theta, k) {
  ds <- lapply(HGRID, function(h) cdiff(theta, k, h))
  # Richardson error between consecutive (2x) steps; pick the min-error pair.
  best_j <- 1; best_e <- Inf; best_v <- ds[[1]]
  for (j in seq_len(length(HGRID) - 1L)) {
    e <- max(abs(ds[[j]] - ds[[j + 1L]]))
    sc <- max(abs(ds[[j + 1L]]), 1e-30)
    if (e / sc < best_e) { best_e <- e / sc; best_j <- j; best_v <- ds[[j]] }
  }
  list(v = best_v, floor = best_e)
}
gate_state <- function(theta) {
  a0 <- stand_a_soil(theta)
  if (all(abs(a0) < 1e-30)) return(NULL)               # fully shut down
  D_an  <- stand_jac_soil(theta)
  D_ref <- matrix(0, ns, ns); fd_floor <- 0
  for (k in seq_len(ns)) {
    fc <- fd_col_adaptive(theta, k)
    D_ref[, k] <- fc$v; fd_floor <- max(fd_floor, fc$floor)
  }
  scale <- max(abs(D_ref)); if (scale <= 0) return(NULL)
  list(relmax = max(abs(D_an - D_ref)) / scale,
       relfro = sqrt(sum((D_an - D_ref)^2)) / sqrt(sum(D_ref^2)),
       scale  = scale, fd_floor = fd_floor,
       driest_theta = min(theta))
}

# --- sweep soil states wet -> dry (theta_sat ~ 0.453; drier = lower theta) -----
theta_sat <- env$soil_moist_sat
set.seed(1)
states <- list()
for (frac in seq(0.9, 0.12, length.out = 15)) {   # 0.9*sat (wet) -> 0.12*sat (dry)
  base <- frac * theta_sat
  for (rep in 1:3) {
    th <- pmax(0.02, base * runif(ns, 0.7, 1.0))   # driest layer ~ base
    states[[length(states) + 1]] <- sort(th, decreasing = TRUE)  # top layer wettest
  }
}
cat(sprintf("gating %d soil states, theta in [%.3f, %.3f] (theta_sat=%.3f)\n",
            length(states), 0.12*theta_sat, 0.9*theta_sat, theta_sat)); flush(stdout())

res <- Filter(Negate(is.null), lapply(states, gate_state))
relmax <- sapply(res, `[[`, "relmax"); relfro <- sapply(res, `[[`, "relfro")
driest <- sapply(res, `[[`, "driest_theta")
q <- quantile(driest, c(1/3, 2/3)); dry <- driest < q[1]; wet <- driest > q[2]
ssum <- function(v) sprintf("med=%.2e p90=%.2e max=%.2e", median(v), quantile(v, .9), max(v))
cat(sprintf("\n== STAND analytic da/dtheta vs central-diff of stand a  (%d states) ==\n", length(res)))
cat(sprintf("  rel(max-entry) ALL: %s\n", ssum(relmax)))
cat(sprintf("  rel(frobenius) ALL: %s\n", ssum(relfro)))
cat(sprintf("  rel(max-entry) DRY tercile (theta < %.3f): %s\n", q[1], ssum(relmax[dry])))
cat(sprintf("  rel(max-entry) WET tercile (theta > %.3f): %s\n", q[2], ssum(relmax[wet])))
fd_floor <- sapply(res, `[[`, "fd_floor"); scales <- sapply(res, `[[`, "scale")
cat(sprintf("\n  FD noise floor (Richardson plateau residual) ALL: %s\n", ssum(fd_floor)))
cat("  (relmax at or below fd_floor => limited by FD, not by the analytic Jacobian)\n")
# Rigorous subset: states where FD actually resolved the coupling (low plateau
# residual). This is the quantitative gate; noise-limited states can't judge D_an.
trust <- fd_floor < 1e-2
cat(sprintf("\n  == FD-TRUSTWORTHY states (fd_floor < 1e-2): %d / %d ==\n", sum(trust), length(res)))
if (any(trust)) cat(sprintf("    rel(max-entry): %s\n", ssum(relmax[trust])))
# Absolute view: error scaled by the GLOBAL coupling magnitude (dry-dominated),
# which is what the macro-step refresh actually cares about (wet coupling ~0).
gscale <- max(scales)
abserr <- sapply(res, function(r) max(abs(r$relmax * r$scale)))  # |D_an-D_ref| per state
cat(sprintf("\n  |D_an - D_ref| / global_scale (global_scale=%.3e): %s\n",
            gscale, ssum(abserr / gscale)))
ord <- order(-relmax)[seq_len(min(8, length(res)))]
cat("\n  worst 8 states (relmax, fd_floor, driest_theta, scale):\n")
for (j in ord) cat(sprintf("    rel=%.2e  fd_floor=%.2e  driest_theta=%.3f  scale=%.3e\n",
                           relmax[j], res[[j]]$fd_floor, res[[j]]$driest_theta, res[[j]]$scale))
saveRDS(list(relmax=relmax, relfro=relfro, driest=driest), file.path(outdir, "duptake_stand_gate.rds"))
cat("ALLDONE\n")
