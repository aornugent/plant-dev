# P1 follow-on -- decompose the per-leg member sweeps, and count how many of the
# O(M) anchor captures are DUPLICATES of a slow-advance sweep.
#
# WHY. mri_macro_step (odelia mri.hpp) runs, per leg, for an n-node coupling:
#     F[0] = slow_rates(x0, u0)                      <- member sweep 1
#     freeze_slow(x0); subcycle -> refresh_anchor(u0) <- member sweep 2, at (x0,u0)
#     x0 -> x1
#     F[1] = slow_rates(x1, u1)                      <- member sweep 3
#     freeze_slow(x1); subcycle -> refresh_anchor(u1) <- member sweep 4, at (x1,u1)
# Sweeps 2 and 4 evaluate the member loop at exactly the state their immediately
# preceding slow_rates sweep just evaluated it at -- and slow_rates already
# computes both anchor quantities (a0 = assemble_resource_depletion, and, when
# compute_uptake_jacobian is on, the per-cohort Jacobian that
# assemble_duptake_jacobian merely aggregates). So they are pure duplicates.
#
# Anchors are captured at a subcycle's first micro-step only when the trust
# monitor trips; additional captures mid-subcycle are GENUINE (the state really
# moved). This script separates the two, because only the duplicates are free to
# remove:
#     legs        = fast_rate_calls / (nmicro * (n - 1))
#     subcycles   = legs * (n - 1)
#     duplicates <= subcycles           (one per subcycle start)
#     genuine     = coupling_evals - duplicates
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant", export_all=TRUE, quiet=TRUE)})
source("scripts/tf24-benchmarks/converged_control.R")
cat("loaded\n"); flush(stdout())

NMICRO <- 40; NSUB <- 2   # kutta3: n=3 nodes -> 2 sub-intervals, 2 slow sweeps
LIFE <- 40; BIRTH <- 20; MEAN <- 1

run_amp <- function(amp) {
  cfg <- list(traits = c(lma = 0.0825), env = list(),
              driver = list(rainfall_mean = MEAN, rainfall_amp_frac = amp))
  ctrl <- mri_uptake_control(days = 7, tol = 1e-2, nmicro = NMICRO, ode_tol = 1e-5)
  s <- build_scenario(cfg, max_patch_lifetime = LIFE, ctrl = ctrl, birth_rate = BIRTH)
  mri_coupling_evals_reset(); mri_fast_rate_calls_reset()
  t <- system.time(off <- sum(run_scm(s$p, s$env, s$ctrl)$offspring_production))[["elapsed"]]
  cheap <- mri_fast_rate_calls_get(); coup <- mri_coupling_evals_get()
  legs  <- cheap / (NMICRO * NSUB)
  subs  <- legs * NSUB
  dup   <- min(coup, subs)
  list(amp=amp, off=off, t=t, cheap=cheap, coup=coup, legs=legs,
       dup=dup, genuine=coup - dup)
}

cat(sprintf("%-5s %10s %8s %8s %8s %9s %9s %8s\n",
            "amp", "offspring", "legs", "coupling", "dupes", "genuine", "gen/leg", "dup%"))
for (amp in c(0, 0.3, 0.6, 0.9)) {
  r <- run_amp(amp)
  cat(sprintf("%-5.1f %10.4g %8.0f %8.0f %8.0f %9.0f %9.3f %7.1f%%\n",
              r$amp, r$off, r$legs, r$coup, r$dup, r$genuine,
              r$genuine / max(r$legs, 1), 100 * r$dup / max(r$coup, 1)))
  flush(stdout())
}
cat("ALLDONE\n")
