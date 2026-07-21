# T5a — the "emergent heavy atom" premise is FALSIFIED (the measure refines cleanly)

*2026-07-21. Premise check before building T5's split machinery. The v2 Oracle
response, claim 4, asserted the weight skewness is emergent — "max ρ_j stays ~0.3–0.4
at every mesh density," so τ_ins refinement adds light members but never splits the
heavy atoms, and splitting is the true convergence axis. Direct measurement:
run default N / 2N / 4N, read per-node weights.
Script: `scripts/tf24-benchmarks/emergent_skewness.R`.*

## Result — max weight fraction scales ∝ 1/M, and is tiny

**intense_storms (12 yr):**

| refinement | M | J | max ρ-fraction | max g-fraction | top-10 g |
|---|---|---|---|---|---|
| default N | 94 | 2.73e-7 | 0.012 | 0.016 | 0.159 |
| 2N | 187 | 8.22e-8 | 0.006 | 0.008 | 0.081 |
| 4N | 373 | 6.72e-8 | 0.003 | 0.004 | 0.040 |

The heaviest atom carries **~1.6%** of the J-mass at the default mesh — not ~40% — and
its fraction **halves each time the mesh doubles** (clean ∝1/M). The measure has **no
dominant atom**; τ_ins refinement **does** subdivide the mass.

## The Oracle conflated two different "weight fractions"

9a's "participant weight fraction = 0.388" was a **whole second species** `B` in a
two-strategy run `[A,B]` — B's share of *total* J across both strategies. Claim 4 read
that as a single **cohort**'s share *within* one species' measure. Those are ~25× apart:
the single-species measure here is spread across ~94 cohorts with max ~1.6%, not
dominated by one 40% atom.

## Consequences

1. **T5 (heavy-atom splitting) loses its premise.** There is nothing heavy to split;
   the τ_ins axis already subdivides the measure cleanly (max fraction ∝1/M). Do **not**
   build the measure-preserving cohort-split machinery — the falsifier killed it.
2. **The reconciliation's claim-4 leg is wrong**, but T1's leg stands. J's
   non-convergence is therefore **not** granularity. With the coupling field
   well-conditioned (T1) *and* the measure refining cleanly (T5a), the residual
   J-movement must be **field-shift (κ-amplified feedback)** and/or **survivor-flips**
   (members crossing the ρ→0 boundary differently at different mesh densities).
3. **This re-opens item B.** The survivor-flip is exactly the intrinsic
   survival-boundary discontinuity that rung 2 routed to item B. T1 does not protect J
   from it (T1 conditions the *field* `a*`, not the *moment across the boundary*).
4. **T3 (common-field ΔJ decomposition) is now the decisive remaining test** — it
   cleanly separates field-shift (protocol; placement/feedback) from survivor-flips
   (intrinsic; item B). That is the fork the whole line of work now turns on.

## Caveat / reading of J itself

J drops sharply coarse→2N (2.73e-7 → 8.22e-8, 3.3×) then only 18% 2N→4N
(8.22e-8 → 6.72e-8). Consistent with: the **default schedule is badly coarse**
(rung-2 DX finding stands) and J converges slowly toward a limit that exists (T1) —
with survivor-flip noise on top. Whether that residual noise is small (protocol) or
load-bearing (item B) is exactly what T3 measures.
