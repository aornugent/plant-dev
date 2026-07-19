# TF24 event-sizing results (Oracle "E1") across the canonical benchmark bank

Real coupled `Solver<Patch<TF24,TF24_Environment>>`, single species (except
`multispecies`), rkck at `ode_tol_rel = ode_tol_abs = 1e-6` (converged-J
tolerance). Adaptive-controller step log (`odelia` `step_diag`) records every
attempt (start time, trial size, accepted/rejected). "Small" = accepted steps in
the smallest decile of step size. Event attribution is by proximity (≤ 1 day) to
a known event surface. Reproduce: `Rscript scripts/tf24-benchmarks/event_sizing.R`.

## Summary

| scenario | ok | accepted | rejected | **reject frac** | **min h / T** | small@kink | small unattr | rej unattr | wall (s) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| dry_to_wet | ✓ | 15 035 | 6 705 | **0.308** | 4.0e-8 | 0.04 | **0.96** | 0.84 | 316 |
| long_horizon | ✓ | 60 926 | 22 812 | **0.272** | 1.4e-8 | 0.31 | **0.69** | 0.77 | 1 339 |
| extended_drought | ✓ | 14 301 | 5 928 | **0.293** | 3.3e-8 | 0.02 | **0.98** | 0.87 | 273 |
| intense_storms | ✓ | 9 377 | 3 864 | **0.292** | 5.0e-8 | 0.03 | **0.97** | 0.87 | 177 |
| multispecies | ✗ | 3 660 | 1 943 | **0.347** | 2.5e-8 | 0.00 | **1.00** | 0.96 | — |
| whiplash | ✓ | 10 331 | 4 039 | **0.281** | 4.2e-8 | 0.18 | **0.82** | 0.76 | 191 |

`multispecies` (4 species) **fails with a non-finite state** — a genuine solver
instability, at the highest reject fraction (0.35). The others complete.

## What the numbers say

1. **Rejection overhead is large and uniform: ~27–35% of all step attempts are
   rejected** and retried smaller. This is the "localization overhead" — the
   controller finding non-smoothness by rejection bisection, each probe paying a
   full O(M) RHS. Roughly one in three RHS evaluations is thrown away.

2. **The step collapses to ~1e-8·T at scattered points** (min h ≈ 1.4e-8–5.0e-8
   of the horizon). Not smooth fast motion — isolated non-smoothness.

3. **Forcing kinks (rain events) explain only a minority of the collapse**
   (2–31% of small steps), and the share tracks rain frequency: highest in
   `long_horizon` (0.31) and `whiplash` (0.18), near-zero in the very dry
   `extended_drought` (0.02). So the small steps cluster **in dry gaps, away from
   rain** — the opposite of a forcing-driven collapse.

4. **Member insertions explain ~0** — because the SCM already places node
   introductions on `advance_adaptive` boundaries. One event class the Oracle
   flagged as removable is **already handled**.

5. **70–98% of the collapse is unattributed to the a-priori surfaces** and sits
   in dry periods → it is dominated by the **state-dependent crossings** the
   analysis predicted: the leaf-shutdown boundary (ψ_stem → ψ_crit), the argmax
   bound, and the soil clamp (θ → θ_res / matric near-singularity). These are the
   dry-end non-smoothnesses. Distinguishing "state-dependent event" from "genuine
   intrinsic fast structure" within this residual is the **open measurement** (the
   Oracle's E3: prototype event functions for the heavy members + bound flips and
   see whether the step count falls).

## Caveats

- Attribution tolerance is 1 day; the kink share is if anything **over**-counted
  (rain days are common), so "kinks are a minority" is robust.
- The residual is not yet split into state-events vs intrinsic — that needs
  per-step state-surface distances (shutdown margin `ψ_crit − ψ_stem`, clamp
  margin `θ − θ_res`) or the E3 prototype. It is the next measurement.
- `min h` is floored by the controller `h_min` (1e-6 yr here); the 1e-8·T figure
  is `min h / T`, not the controller floor.
