# T6 Slice 3b-ii: OFFLINE MACRO-STEP FALSIFIER (R, no engine).
#
# THE decision gate for the multirate uptake arbitrage. Over a weekly window with
# cohorts FROZEN, sub-cycle the 5-layer soil two ways that differ ONLY in how the
# root-uptake coupling a is obtained:
#   TRUE: a(u) = stand resource_depletion recomputed at the current soil state u
#         (the O(M) cohort sum -- the expensive channel we want to avoid).
#   LIN : a(u) ~= a0 + J (u - u0), the Taylor refresh from the frozen-window
#         Jacobian J = assemble_duptake_jacobian() (Slice 3b-i) -- cheap.
# Everything else (rainfall infiltration, inter-layer drainage cascade, the split
# micro-stepper) is byte-identical between the two, so any divergence is PURELY the
# a-linearization error. This measures:
#   (1) the soil-trajectory + a error the refresh incurs over a real window,
#   (2) how often a 2nd-order trust monitor would demand re-expansion (per regime),
#   (3) the realised cohort-solve reduction (the speedup) that implies.
# It sets the trust rate and speedup BEFORE any engine code (Slice 3b-iii / 4).
options(pkg.build_extra_flags = FALSE)
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", export_all = TRUE, quiet = TRUE))
cat("loaded\n"); flush(stdout())
outdir <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# --- realistic frozen cohort distribution (as Slice 3b-i) ---------------------
p0 <- scm_base_parameters("TF24"); p0$max_patch_lifetime <- 30
ctrl <- control(); ctrl$compute_uptake_jacobian <- TRUE
ctrl$GSS_tol_abs <- 1e-12; ctrl$ci_abs_tol <- 1e-12
p1 <- add_strategies(p0, trait_matrix(0.0825, "lma"), hyperpar = TF24_hyperpar, birth_rate = list(20))
scm <- SCM("TF24", "TF24_Env")(p1, Environment("TF24"), ctrl); scm$run()
patch <- scm$patch
envs  <- patch$environment                        # configured env for soil rates
ns    <- envs$get_soil_number_of_depths()
es    <- envs$ode_size
y0    <- patch$ode_state; slow <- length(y0) - es; soil_idx <- slow + seq_len(ns)
t_now <- patch$time
cat(sprintf("patch: %d nodes, ns=%d, t=%.2f\n", patch$species[[1]]$size, ns, t_now)); flush(stdout())

# stand a(u): recompute the O(M) cohort sum at soil state u (cohorts frozen)
a_true <- function(u) { y <- y0; y[soil_idx] <- u; patch$set_ode_state(y, t_now)
  patch$compute_rates(); patch$resource_depletion()[seq_len(ns)] }
# frozen-window Jacobian at u0 (once per window)
jac_at <- function(u0) { y <- y0; y[soil_idx] <- u0; patch$set_ode_state(y, t_now)
  patch$compute_rates(); matrix(patch$assemble_duptake_jacobian(), ns, ns, byrow = TRUE) }

# split micro-step: flow(dt/2) . residual(dt) . flow(dt/2). `a_of` supplies the
# coupling at the mid state. Rainfall enters residual_rhs via the env driver/time.
micro_step <- function(u, a_of, dt) {
  u <- envs$r_analytic_partial_flow(u, dt / 2)
  a <- a_of(u)
  du <- envs$r_residual_rhs(u, a)
  u <- pmax(u + dt * du, 1e-4)
  envs$r_analytic_partial_flow(u, dt / 2)
}

WEEK <- 7 / 365

# ONE-EXPANSION diagnostic: linearize once at u0, never re-expand, and record the
# soil-traj / a error and (per tol) the first micro-step the linear model breaks
# trust. Isolates the raw linearization quality over a full window.
run_window_once <- function(u0, rain, nmicro, tol_grid) {
  envs$extrinsic_drivers_set_constant("rainfall", rain); envs$time <- t_now
  dt <- WEEK / nmicro
  J  <- jac_at(u0); a0 <- a_true(u0)
  a_lin <- function(u) as.numeric(a0 + J %*% (u - u0))
  uT <- u0; uL <- u0; max_utraj <- 0; max_aerr <- 0
  trip <- setNames(rep(NA_integer_, length(tol_grid)), sprintf("%.0e", tol_grid))
  aerrs <- numeric(nmicro); excs <- numeric(nmicro)   # for the cheap-monitor check
  for (m in seq_len(nmicro)) {
    uT <- micro_step(uT, a_true, dt)
    uL <- micro_step(uL, a_lin, dt)
    aerr <- max(abs(a_lin(uL) - a_true(uL))) / max(max(abs(a_true(uL))), 1e-30)
    max_aerr <- max(max_aerr, aerr)
    max_utraj <- max(max_utraj, max(abs(uL - uT)) / max(max(abs(uT)), 1e-30))
    aerrs[m] <- aerr; excs[m] <- max(abs(uL - u0))    # linf excursion from anchor
    for (j in seq_along(tol_grid)) if (is.na(trip[j]) && aerr > tol_grid[j]) trip[j] <- m
  }
  # cheap-monitor viability: the leading linearization error is ~ C*||du||^2, so a
  # squared-excursion threshold is a valid a-free trigger iff aerr rises monotonically
  # with the excursion. Report the excursion at the tol=1e-2 trip (if it clusters
  # across regimes, one threshold serves) and the aerr-vs-exc^2 correlation.
  exc_at_trip <- if (!is.na(trip["1e-02"])) excs[trip["1e-02"]] else NA_real_
  cor2 <- if (max_aerr > 0) suppressWarnings(cor(aerrs, excs^2)) else NA_real_
  list(u_traj_err = max_utraj, a_err = max_aerr, trip = trip,
       exc_at_trip = exc_at_trip, cor_aerr_exc2 = cor2)
}

# ADAPTIVE trust-monitored pass: re-linearize (one cohort sum for a0 + J) whenever
# the linear model's error would exceed `tol`, using an ORACLE trigger (the true
# error). This is the IDEAL re-expansion count -> a LOWER bound on cohort sums
# (an UPPER bound on speedup); a cheap 2nd-order monitor in the engine can only do
# as well or worse. Between re-expansions the coupling is the cheap Taylor refresh.
# n_cohort_sums = 1 (initial) + re-expansions; baseline = nmicro (recompute each step).
run_window_adaptive <- function(u0, rain, nmicro, tol) {
  envs$extrinsic_drivers_set_constant("rainfall", rain); envs$time <- t_now
  dt <- WEEK / nmicro
  anchor <- u0; J <- jac_at(u0); a0 <- a_true(u0); ncs <- 1L
  a_lin <- function(u) as.numeric(a0 + J %*% (u - anchor))
  uL <- u0; uT <- u0; max_utraj <- 0
  for (m in seq_len(nmicro)) {
    # oracle trust check BEFORE stepping: is the linear model still good at uL?
    aerr <- max(abs(a_lin(uL) - a_true(uL))) / max(max(abs(a_true(uL))), 1e-30)
    if (aerr > tol) { anchor <- uL; J <- jac_at(uL); a0 <- a_true(uL); ncs <- ncs + 1L
      a_lin <- function(u) as.numeric(a0 + J %*% (u - anchor)) }
    uL <- micro_step(uL, a_lin, dt)
    uT <- micro_step(uT, a_true, dt)
    max_utraj <- max(max_utraj, max(abs(uL - uT)) / max(max(abs(uT)), 1e-30))
  }
  list(ncs = ncs, u_end_err = max(abs(uL - uT)) / max(max(abs(uT)), 1e-30),
       u_traj_err = max_utraj)
}

# --- regime bank: {wet, mid, dry} x {drought, drizzle, storm} -----------------
theta_sat <- envs$soil_moist_sat
soils <- list(wet = rep(0.80*theta_sat, ns), mid = rep(0.50*theta_sat, ns), dry = rep(0.30*theta_sat, ns))
rains <- c(drought = 0, drizzle = 2, storm = 40)   # rainfall driver units (m/yr-ish)
tol_grid <- c(1e-4, 1e-3, 1e-2, 1e-1)
NMICRO <- 40

op_tol <- 1e-2   # per-window a-error budget (leaves headroom under the ~10x
                 # demographic feedback -> ~1e-1 offspring, refined in Slice 4)
cat(sprintf("\nweekly window (%.4f yr), %d micro-steps; single-expansion diagnostic + adaptive @ tol=%.0e\n\n",
            WEEK, NMICRO, op_tol)); flush(stdout())
cat(sprintf("%-6s %-8s | %-9s %-9s | %-10s | %-8s %-9s | %s\n",
            "soil","rain","u_err1","a_err1","1st re-exp @ tol","adapt:cs","cs/nmicro","adapt u_end_err"))
cat(strrep("-", 104), "\n")
rows <- list()
for (sn in names(soils)) for (rn in names(rains)) {
  d <- run_window_once(soils[[sn]], rains[[rn]], NMICRO, tol_grid)
  a <- run_window_adaptive(soils[[sn]], rains[[rn]], NMICRO, op_tol)
  tripstr <- paste(sprintf("%s:%s", sub("e-0","e-",names(d$trip)),
                           ifelse(is.na(d$trip), "--", as.character(d$trip))), collapse=" ")
  speed <- NMICRO / a$ncs
  cat(sprintf("%-6s %-8s | %-9.2e %-9.2e | %-10s | %-8s %-9s | %.2e\n",
              sn, rn, d$u_traj_err, d$a_err, tripstr,
              sprintf("%d", a$ncs), sprintf("%d/%d(%.1fx)", a$ncs, NMICRO, speed), a$u_end_err))
  rows[[paste(sn,rn)]] <- list(soil=sn, rain=rn, u_err1=d$u_traj_err, a_err1=d$a_err,
                               trip=d$trip, adapt_cs=a$ncs, adapt_u_end_err=a$u_end_err, speed=speed,
                               exc_at_trip=d$exc_at_trip, cor2=d$cor_aerr_exc2)
}
# cheap-monitor viability across regimes
cat("\n  cheap a-free trust monitor viability (leading error ~ C*||du||^2):\n")
et <- sapply(rows, function(x) x$exc_at_trip); c2 <- sapply(rows, function(x) x$cor2)
cat(sprintf("    excursion ||du||_inf at the tol=1e-2 trip: med=%.2e range=[%.2e, %.2e]\n",
            median(et, na.rm=TRUE), min(et, na.rm=TRUE), max(et, na.rm=TRUE)))
cat(sprintf("    corr(a_err, ||du||^2) across window steps: med=%.3f min=%.3f\n",
            median(c2, na.rm=TRUE), min(c2, na.rm=TRUE)))
cat("    (tight excursion cluster + high corr => a fixed ||du|| threshold reproduces\n")
cat("     the oracle re-expansion rate without any true-a probe -- feasible for 3b-iii.)\n")
cat(sprintf("\n  cs = cohort-sums per window under an ORACLE trust monitor (ideal lower bound;\n"))
cat(sprintf("  baseline = %d, one per micro-step). speed = %d/cs. A cheap 2nd-order monitor\n", NMICRO, NMICRO))
cat("  in the engine can only match or trail this. cs~nmicro => arbitrage DEAD (collapses to\n")
cat("  global RK, the MRI-ancestor failure); cs<<nmicro => real cohort-solve reduction.\n")
saveRDS(rows, file.path(outdir, "macrostep_falsifier.rds"))
cat("\nALLDONE\n")
