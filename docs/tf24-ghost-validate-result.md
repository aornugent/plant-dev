# Ghost validation (ladder item 1) — result

*2026-07-21. Fresh Oracle's falsification ladder, rung 1: validate that the
zero-feedback "ghost" (plant's `run_mutant` replaying a probe against a
resident's cached `(u,s)(t)` field) is a faithful rare-invasion probe. Blocked
last session on the RK45-cache OOM at ~10–12 yr; unblocked here by slimming the
cache (plant `b2f70dfa`). Script: `scripts/tf24-benchmarks/ghost_validate.R`
(single probe) + the mass-fraction sweep below.*

## The infrastructure fix (prerequisite, shipped)

`save_RK45_cache` stored a **full `Environment` copy at every RK sub-step** —
including the light spline's adaptive **builder** (`AdaptiveInterpolator
spline_construction`) and the band-solve workspace (`m_upper`/`m_lower`), both
build-only state a replay never reads. That is what OOM'd past ~10 yr.

Fix (plant `b2f70dfa`): cache only the field a replay evaluates — the light
knots+values (`EnvStepRecord.light`, rebuilt via the existing
`r_init_interpolators`, a **bit-identical** reconstruction) and the environment
ODE state (soil θ + aux). Added `Environment::get_interpolators_state` (inverse
of `r_init_interpolators`) on the base + FF16/K93/TF24. Production untouched
(both cache hooks gated on `save_RK45_cache`, off when `ode_method != "mri"`);
`test-mutant.R` green.

**Memory (intense_storms):** the 12 yr ghost that previously OOM'd now peaks at
**1.14 GB** (was >15 GB); 3 yr 6.8 → 2.2 GB. Long-horizon and multispecies
ghosts are unblocked. Every cache-dependent number (resident J, ghost(A)
self-gap, ghost(B) J, frozen-field relJ) reproduces the full-copy cache to
every printed digit — the slim record is faithful, not merely plausible.

## The horizon matters: 3 yr is pre-reproductive

`J` vs horizon (single resident, no cache):

| years | 3 | 5 | 8 | 12 | 20 |
|---|---|---|---|---|---|
| J | 1.1e-15 | 4.1e-13 | 5.4e-10 | 2.7e-07 | 1.4e-05 |

3 yr sits at the numerical noise floor (pre-reproductive); `J` only reaches a
physically meaningful range at **≥12 yr**. So the short-horizon fallback fits
memory but is scientifically void — the validation must run at ≥12 yr, which is
exactly why the cache fix was needed.

## Item 1 validated: the ghost is an asymptotically exact invasion probe

The ghost measures **rare-invasion fitness** (a probe against the resident's
field with no feedback). Comparing it to a *co-resident* is only fair as the
probe → rare. Sweeping probe B's establishment (`birth_rate`) at 12 yr, B =
lma 0.09 vs resident lma 0.0825:

| `birth_rate` B | mass fraction | relJ | `J_realB / J_ghostB` |
|---|---|---|---|
| 1     | 0.388  | 63.4  | 0.016 |
| 0.1   | 0.060  | 0.424 | 0.70  |
| 0.01  | 0.0064 | 0.036 | 0.966 |
| 0.001 | 0.0006 | 0.003 | 0.997 |

The frozen-field error is **O(mass fraction) and →0 as ρ→0**, exactly the
Oracle's prediction. `J_realB → J_ghostB` as mass→0. The heavy-probe relJ=63
(mass fraction 0.39) is not a failure — it is outside the probe's regime
(superlinear feedback when the probe is a large perturbation). `J_ghostB` scales
exactly linearly in `birth_rate` (zero feedback), confirming the mechanism.

**Consequence:** the ghost is faithful precisely where the ladder uses it — the
marginal members (`ρ→0`) at the survival/insertion crossings (the 1532× spike in
the deltaJ decomposition) and rare invaders. It is a valid, ~1/M-cost passive
probe of the lineage axis on saved fields.

## What this unlocks (the rungs above, per the correction-response triage)

- **Rung 2** — goal-oriented member placement from a *single* solve
  (`g(τ_ins)` hierarchical-surplus indicator, ghost-densified where ambiguous)
  + a J certificate; replaces the >15-min refiner.
- **Rung 3** — certified survival crossings by ghost bisection in `τ_ins`;
  re-run the diffuse-vs-flip deltaJ decomposition on a both-converged pair.
- **Rung 5** — windowed waveform-relaxation contraction test (the architectural
  swing: removes the global max-norm and the O(M)-per-decision at once); the
  kill-or-fund test is one member sweep on saved fields.

Scripts: `scripts/tf24-benchmarks/ghost_validate.R` (single probe, 3/12 yr via
`GHOST_YEARS`), and the mass-fraction sweep (`ghost_massfrac.R`).
