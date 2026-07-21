# Goal-oriented placement (ladder rung 2) — result: does not fund; the measure axis is a J-discontinuity, not a placement problem

*2026-07-21. Fresh Oracle's ladder, rung 2: replace the >15-min refiner with a
single-solve goal-oriented member placement + a J certificate. Run across the
bank's measure-stressing scenarios (survival crossings + boundary sweep + deep
mesh), not just the mild intense_storms. Scripts:
`scripts/tf24-benchmarks/goal_placement_{predict,test,converge}.R`.*

## Test 1 — does the single-solve surplus indicator predict the J-error? NO.

The Oracle's proposal: a hierarchical-surplus indicator (interpolation defect of
the per-slot J-contribution `g_j = nrr_j * density_j` against its lineage
neighbours) predicts where to refine, from one solve. Measured Spearman of that
indicator against the actual fixed->2x-refined error at each node:

| scenario | relAB (fixed vs 2x) | Spearman(surplus, error) | top-decile overlap | error @ small τ_ins |
|---|---|---|---|---|
| extended_drought | 0.343 | **-0.56** | 0.00 | 1.00 |
| dry_to_wet | 0.126 | **-0.84** | 0.00 | 1.00 |
| long_horizon | 0.030 | +0.66 | 0.40 | 1.00 |
| whiplash | 0.798 | **-0.86** | 0.00 | 1.00 |

The surplus is **anti-correlated** with the error on three of four scenarios: it
chases the small, wiggly *dying* members at large τ_ins (high `g`-curvature),
not the error. The Oracle assumed the surplus concentrates at small τ_ins "since
w(τ_ins) is inside g" — it does not. **But the error location is universal and
simple:** ~100% of the absolute J-error sits at small τ_ins, where J's mass is
(the monotone insertion-time envelope) — confirming the correction round's
"absolute error tracks where J's mass sits." So the correct indicator, if any,
is the J-mass `g` itself, not its curvature.

## Test 2 — does g-mass placement beat uniform? NOT ROBUSTLY.

Placing N nodes by the inverse-CDF of `|g|` (dense at small τ_ins), vs default
and uniform, error against a 4x-densified reference:

| scenario | N | err_default | err_unif | err_gmass |
|---|---|---|---|---|
| extended_drought | 98 | 0.335 | **0.119** | 0.156 |
| dry_to_wet | 98 | 0.473 | 0.214 | **0.116** |
| long_horizon | 103 | 0.164 | **0.013** | 0.352 |
| whiplash | 96 | 8.47 | 0.240 | **0.072** |

g-mass wins on the transient/boundary scenarios (dry_to_wet, whiplash) but loses
badly on the deep mesh (long_horizon 0.35 vs 0.013: concentrating at small τ_ins
starves the 70-yr evolved axis). Not a robust lever. The robust signal is that
**uniform beats the default schedule 3-35x everywhere** — the default is badly
placed (whiplash default 847% off). (Caveat: the reference is default-densified,
biased toward default/uniform node locations; hence test 3.)

## Test 3 — schedule-neutral convergence: J DOES NOT CONVERGE for any family.

Refine each family 1x -> 2x -> 4x; report J and successive relative change.

**long_horizon (30 yr, N=103):**
| family | J(N) | J(2N) | J(4N) | δ(2N,N) | δ(4N,2N) |
|---|---|---|---|---|---|
| default | 1.79e-3 | 1.85e-3 | 1.54e-3 | 0.029 | 0.199 |
| uniform | 1.52e-3 | 1.83e-3 | 1.63e-3 | 0.168 | 0.116 |
| g-mass | 2.08e-3 | 1.97e-3 | 1.49e-3 | 0.055 | 0.326 |

**whiplash (16 yr, N=96):**
| family | J(N) | J(2N) | J(4N) | δ(2N,N) | δ(4N,2N) |
|---|---|---|---|---|---|
| default | 2.10e-6 | 4.24e-7 | 2.22e-7 | 3.95 | 0.91 |
| uniform | 1.69e-7 | 1.64e-7 | 1.21e-7 | 0.030 | 0.355 |
| g-mass | 2.38e-7 | 1.90e-7 | 1.67e-7 | 0.248 | 0.140 |

**No family converges.** Successive deltas do not shrink monotonically (they
grow: long_horizon default 0.03->0.20, g-mass 0.06->0.33; whiplash uniform
0.03->0.36), and the three families land on **different** J at 4x (long_horizon
~9% apart, whiplash ~45% apart). This is the schedule-neutral confirmation of the
earlier Richardson finding (uniform densification non-asymptotic, p≈0.2).

## Verdict: goal-oriented placement does not fund

The measure-axis error is real and large (the default schedule is badly placed;
uniform is a cheap 3-35x partial improvement), **but it is not a placement-quality
problem.** J does not converge under node-count refinement for *any* placement —
because refining the mesh moves which marginal members cross the ρ→0 survival
threshold, so J jumps non-monotonically (the "J is a step function near survival
thresholds" / 1532x ΔJ-spike mechanism). **No placement indicator can certify a
limit that does not exist.** There is nothing to place *toward*.

This routes straight to the Oracles' **item B (both fundamentals responses): J's
geometry is intrinsic — a moment of a measure with an absorbing weight boundary
is piecewise-C¹, full stop.** The fix is model-side: mollify the survival entry
into J (a smooth window on the survival margin near removal, width budgeted
against the existing spread), making J continuous under both θ and mesh changes.
No amount of placement numerics substitutes for it. The measure-axis "6x
production error / 2.3% refined spread" is this discontinuity, not misplaced
quadrature.

## Actionable secondary finding (cheap, robust)

The production **default fixed schedule is badly placed** — up to ~10x off at its
own node count (whiplash), and uniform-in-time placement at the same count is
3-35x closer to a refined solve on every scenario. Switching the default to
uniform (or simply denser) is a cheap, robust partial improvement for a
scientist running production, even though it does not fully converge J. This is a
DX win independent of the (model-side) mollification question.

## What remains on the ladder

- **Rung 3 — certified survival crossings** via ghost bisection in τ_ins (the
  validated ghost locates the flips cheaply). Pair with the **rainfall-as-locator
  test**: drought windows in the known forcing should predict which lineage-age
  windows carry the survival crossings, giving a free bracket.
- **Item B — J mollification** is now the identified measure-axis requirement,
  but it is a model-side decision (the survival-margin window width) for the model
  owners, not a numerics task.
