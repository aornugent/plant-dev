# Oracle review rung #1: the REFRESH-SWEEP SLOPE test -- certify or kill the
# affine coupling's escape from the frozen-coupling refutation.
#
# The Oracle's verdict: the held-a (frozen, zeroth-order) coupling failed by a
# TRANSFER-FUNCTION error -- the fast Jacobian was missing -da/du (50-291x the
# retained stiffness near bounds), so the subsystem relaxed to a displaced balance:
# an O(1) structural error NO refresh rate can remove (a floor/plateau). The affine
# model carries -da/du EXACTLY at the anchor, so its error is pure Jacobian DRIFT
# within the excursion: local O(||du||^2), and -- accumulated over R equal sub-legs
# of a window, each of excursion ~||du||/R with error ~C(||du||/R)^2 -- GLOBALLY
# O(1/R). No plateau mechanism.
#
# Test (monitor OFF, forced fixed refresh rate R): re-anchor (recompute a0, J) every
# nmicro/R micro-steps; measure the soil-trajectory error vs the true-coupling
# trajectory (same Strang split for both, so the splitting error is common-mode and
# cancels -- the difference is PURELY the coupling-model error). Sweep R, fit the
# log-log slope.
#   slope ~ -1, no floor above ~machine/within-step O(dt^2)  => ESCAPE CERTIFIED.
#   any plateau (error flattens as R grows)                  => RE-ENTRY (like held-a).
options(pkg.build_extra_flags = FALSE)
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", export_all = TRUE, quiet = TRUE))
cat("loaded\n"); flush(stdout())
outdir <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# --- frozen cohort distribution (identical setup to macrostep_falsifier) ------
p0 <- scm_base_parameters("TF24"); p0$max_patch_lifetime <- 30
ctrl <- control(); ctrl$compute_uptake_jacobian <- TRUE
ctrl$GSS_tol_abs <- 1e-12; ctrl$ci_abs_tol <- 1e-12
p1 <- add_strategies(p0, trait_matrix(0.0825, "lma"), hyperpar = TF24_hyperpar, birth_rate = list(20))
scm <- SCM("TF24", "TF24_Env")(p1, Environment("TF24"), ctrl); scm$run()
patch <- scm$patch
envs  <- patch$environment
ns    <- envs$get_soil_number_of_depths()
es    <- envs$ode_size
y0    <- patch$ode_state; slow <- length(y0) - es; soil_idx <- slow + seq_len(ns)
t_now <- patch$time

a_true <- function(u) { y <- y0; y[soil_idx] <- u; patch$set_ode_state(y, t_now)
  patch$compute_rates(); patch$resource_depletion()[seq_len(ns)] }
jac_at <- function(u0) { y <- y0; y[soil_idx] <- u0; patch$set_ode_state(y, t_now)
  patch$compute_rates(); matrix(patch$assemble_duptake_jacobian(), ns, ns, byrow = TRUE) }
micro_step <- function(u, a_of, dt) {
  u <- envs$r_analytic_partial_flow(u, dt / 2)
  a <- a_of(u)
  du <- envs$r_residual_rhs(u, a)
  u <- pmax(u + dt * du, 1e-4)
  envs$r_analytic_partial_flow(u, dt / 2)
}
WEEK <- 7 / 365

# error at forced refresh rate R (re-anchor every nmicro/R steps; NO monitor)
sweep_error <- function(u0, rain, nmicro, R) {
  envs$extrinsic_drivers_set_constant("rainfall", rain); envs$time <- t_now
  dt <- WEEK / nmicro
  interval <- nmicro %/% R                       # micro-steps between forced re-anchors
  # true-coupling reference trajectory (a_true every step)
  uT <- u0
  # affine trajectory with forced re-anchoring
  uL <- u0; anchor <- u0; J <- jac_at(u0); a0 <- a_true(u0)
  a_lin <- function(u) as.numeric(a0 + J %*% (u - anchor))
  max_err <- 0
  for (m in seq_len(nmicro)) {
    if (m > 1 && ((m - 1) %% interval) == 0) {   # forced re-anchor at the boundary
      anchor <- uL; J <- jac_at(uL); a0 <- a_true(uL)
      a_lin <- function(u) as.numeric(a0 + J %*% (u - anchor))
    }
    uL <- micro_step(uL, a_lin, dt)
    uT <- micro_step(uT, a_true, dt)
    max_err <- max(max_err, max(abs(uL - uT)) / max(max(abs(uT)), 1e-30))
  }
  max_err
}

theta_sat <- envs$soil_moist_sat
soils <- list(wet = rep(0.80*theta_sat, ns), mid = rep(0.50*theta_sat, ns), dry = rep(0.30*theta_sat, ns))
rains <- c(drought = 0, drizzle = 2, storm = 40)
NMICRO <- 96                                   # divisible by every R below
R_GRID <- c(1, 2, 3, 4, 6, 8, 12, 16, 24, 32)  # refresh rate (anchors per window)

cat(sprintf("\nweekly window, %d micro-steps; refresh-rate sweep R = {%s}\n",
            NMICRO, paste(R_GRID, collapse=", ")))
cat("error(R) = max soil-traj error vs true-coupling traj (splitting error cancels)\n")
cat("slope = d log err / d log R over the cleanly-decreasing tail; PLATEAU => re-entry\n\n")
cat(sprintf("%-6s %-8s | %s | %-7s %s\n", "soil","rain",
            paste(sprintf("R=%-2d", R_GRID), collapse=" "), "slope", "verdict"))
cat(strrep("-", 120), "\n")

rows <- list()
for (sn in names(soils)) for (rn in names(rains)) {
  errs <- sapply(R_GRID, function(R) sweep_error(soils[[sn]], rains[[rn]], NMICRO, R))
  # fit slope on log-log; use the tail (drop R=1 which can be pre-asymptotic)
  lr <- log(R_GRID); le <- log(pmax(errs, 1e-300))
  keep <- errs > 1e-13                          # ignore rungs at the noise floor
  slope <- if (sum(keep) >= 2) coef(lm(le[keep] ~ lr[keep]))[2] else NA_real_
  # plateau test: does the error stop decreasing at the fine end? ratio of last two.
  tail_ratio <- errs[length(errs)] / max(errs[length(errs) - 1], 1e-300)
  verdict <- if (is.na(slope)) "floor(noise)" else
    if (slope < -0.75 && tail_ratio < 0.85) "ESCAPE (~1/R)" else
    if (slope > -0.4 || tail_ratio > 0.95)  "PLATEAU?? (re-entry)" else "partial"
  cat(sprintf("%-6s %-8s | %s | %-7.2f %s\n", sn, rn,
              paste(sprintf("%.1e", errs), collapse=" "), slope, verdict))
  flush(stdout())
  rows[[paste(sn,rn)]] <- list(soil=sn, rain=rn, R=R_GRID, errs=errs, slope=slope,
                               tail_ratio=tail_ratio, verdict=verdict)
}
saveRDS(rows, file.path(outdir, "refresh_sweep.rds"))
cat("\nInterpretation: a clean ~ -1 slope with the error still falling at the fine end\n")
cat("certifies the escape (drift-only, O(1/R), no structural floor). A plateau at any\n")
cat("regime -- especially dry+storm (mass switch-on / jumps) or the drawdown legs\n")
cat("(curvature ahead of the anchor near u_min) -- is the re-entry the Oracle warned of.\n")
cat("ALLDONE\n")
