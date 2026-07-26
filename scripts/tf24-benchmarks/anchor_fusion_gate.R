# P2 GATE -- the anchor-fusion change: slow_rates publishes the affine uptake
# anchor it has already computed, so the subcycle no longer re-sweeps the O(M)
# cohort sum at the same (x, u).
#
# THREE CHECKS, and note what the first one really is:
#
# 1. BIT-IDENTITY OF THE ANCHOR VALUES, for free, via the trust monitor. The
#    monitor re-captures when trust_excursion(u) > tol, and trust_excursion is the
#    squared relative excursion of the predicted uptake from the anchor's own a0.
#    At a subcycle's first micro-step u IS the anchor's theta, so if the published
#    anchor equals what refresh_anchor would have computed, the excursion is
#    exactly 0 and the monitor cannot trip. Any discrepancy -- even one ulp that
#    grew -- shows up as a nonzero re-capture count. So in the regimes measured to
#    have zero genuine re-expansions (amp 0 / 0.3 / 0.6: 4358 of 4358 captures were
#    duplicates), the post-change count must be EXACTLY 0. That is a stronger
#    statement than comparing printed offspring digits.
# 2. OFFSPRING UNCHANGED against the pre-change values recorded below.
# 3. PRODUCTION BIT-IDENTICAL with ode_method != "mri_uptake" (the standing
#    invariant): the TF24 default SCM offspring to the last bit.
#
# Cost is reported as MEMBER SWEEPS PER LEG, which is the quantity that actually
# scales with cohort count -- not as the cheap/expensive ratio, which becomes a
# division by ~zero once the duplicates are gone and stops being informative.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant", export_all=TRUE, quiet=TRUE)})
source("scripts/tf24-benchmarks/converged_control.R")
cat("loaded\n"); flush(stdout())

NMICRO <- 40; NSUB <- 2        # kutta3: 3 nodes -> 2 sub-intervals, 2 slow sweeps
LIFE <- 40; BIRTH <- 20; MEAN <- 1

# Pre-change reference (measured 2026-07-26, anchor_redundancy_probe.R, same build
# except for the publish). coupling = every capture; genuine = captures that were
# NOT subcycle-start duplicates.
PRE <- data.frame(
  amp      = c(0,     0.3,   0.6,    0.9),
  off      = c(45.13, 35.12, 0.658,  0.01847),
  coupling = c(4358,  4358,  4358,   5140),
  genuine  = c(0,     0,     0,      782)
)

run_amp <- function(amp) {
  cfg <- list(traits = c(lma = 0.0825), env = list(),
              driver = list(rainfall_mean = MEAN, rainfall_amp_frac = amp))
  ctrl <- mri_uptake_control(days = 7, tol = 1e-2, nmicro = NMICRO, ode_tol = 1e-5)
  s <- build_scenario(cfg, max_patch_lifetime = LIFE, ctrl = ctrl, birth_rate = BIRTH)
  mri_coupling_evals_reset(); mri_fast_rate_calls_reset()
  t <- system.time(off <- sum(run_scm(s$p, s$env, s$ctrl)$offspring_production))[["elapsed"]]
  legs <- mri_fast_rate_calls_get() / (NMICRO * NSUB)
  coup <- mri_coupling_evals_get()
  # A leg pays NSUB slow-stage sweeps plus whatever anchor captures remain.
  list(off = off, t = t, legs = legs, coup = coup,
       sweeps_per_leg = (NSUB * legs + coup) / max(legs, 1))
}

cat(sprintf("%-5s %10s %10s %9s %9s %10s %8s\n",
            "amp", "offspring", "pre-off", "coupling", "expected", "sweeps/leg", "t(s)"))
ok <- TRUE
for (i in seq_len(nrow(PRE))) {
  amp <- PRE$amp[i]
  r <- run_amp(amp)
  # Expected post-change captures = the genuine (non-duplicate) ones only.
  expected <- PRE$genuine[i]
  hit <- if (expected == 0) identical(r$coup, 0) else r$coup <= PRE$coupling[i]
  drift <- abs(r$off - PRE$off[i]) / max(abs(PRE$off[i]), 1e-30)
  if (!hit || drift > 1e-3) ok <- FALSE
  cat(sprintf("%-5.1f %10.6g %10.6g %9.0f %9.0f %10.2f %8.0f  %s\n",
              amp, r$off, PRE$off[i], r$coup, expected, r$sweeps_per_leg, r$t,
              if (hit && drift <= 1e-3) "ok" else "MISMATCH"))
  flush(stdout())
}

# (3) production bit-identical: the standing invariant.
p0 <- scm_base_parameters("TF24"); p0$max_patch_lifetime <- 30
p1 <- add_strategies(p0, trait_matrix(0.0825, "lma"), hyperpar = TF24_hyperpar,
                     birth_rate = list(1))
scm <- SCM("TF24", "TF24_Env")(p1, Environment("TF24"), control())
scm$run()
prod_off <- scm$net_reproduction_ratios
PROD_REF <- 1.03714898556177
cat(sprintf("\nproduction (rkck, default control): %.15g\n", prod_off))
cat(sprintf("bit-identical to pre-change ref:    %s\n",
            if (identical(prod_off, PROD_REF)) "YES" else "NO -- INVARIANT BROKEN"))
if (!identical(prod_off, PROD_REF)) ok <- FALSE

cat(sprintf("\nGATE: %s\n", if (ok) "PASS" else "FAIL"))
cat("ALLDONE\n")
