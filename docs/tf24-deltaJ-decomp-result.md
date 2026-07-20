# Test 3 (first cut) — ΔJ lineage decomposition: mixed (diffuse + survival bits), and not yet definitive

> Item B / the fresh Oracle's lineage-decomposition experiment: is the
> inter-scheme J spread a handful of survival flips or diffuse conditioning
> across the member axis? Feasibility + first cut. Scripts:
> `scripts/tf24-benchmarks/deltaJ_lean.R` (+ `deltaJ_capture/analyze/fixed.R`).
> 2026-07-20.

## Feasibility: reachable, as pure post-processing

J for a species is a trapezoidal integral over nodes:
`J = Σ trapezium(node_times, fecundity × patch_density × S_D × birth_rate)`.
All three ingredients are R-exposed for TF24: `node_times` (**the lineage
coordinate** — each cohort's introduction age), `net_reproduction_ratio_by_node`
(= `fecundity()` = survival-weighted lifetime offspring, so it *carries the
extinction structure*), and `patch_densities`. So the decomposition is a pure
post-processing of a completed run — **no model change**. Confirmed working.

**Cost caveat that shaped the run.** Two obstacles made a clean converged-pair
comparison expensive: (i) `refine_schedule=TRUE` (the adaptive mesh builder)
re-runs the SCM many times — a single refined scheme took >15 min and a 20-yr
horizon hung; (ii) the SCM cost is O(M) per RHS eval, so a dense fixed mesh
(hundreds of cohorts) over a long horizon is minutes per run. The lean cut
below uses one scenario, 10 yr, and two modest fixed meshes.

## First cut: intense_storms, 10 yr, coarse (93 nodes) vs 2×-densified (185)

| quantity | value | reading |
|---|---|---|
| relative J spread A↔B | **0.623** | the two meshes disagree by 62% — neither converged; large member-axis error |
| axis_50 / _80 / _90 (abs \|Δg\|) | 0.017 / 0.039 / 0.056 | 50% of ∫\|Δg\| in 1.7% of the lineage axis, 90% in 5.6% |
| integrand g's own concentration | 0.015 / 0.034 / 0.049 | **\|Δg\| is concentrated to the same degree as J's mass** — the absolute error just tracks where J lives (young cohorts, highest patch-density weight) |
| cancel = \|∫Δg\|/∫\|Δg\| | 1.000 | one-signed (coarse mesh systematically under-resolves, no oscillation) |
| relative per-lineage error \|Δg\|/g | median **0.53**, >0.5 over **51%** of the axis | a genuinely **diffuse** component |
| max relative error | **1532× at τ = 1.62 yr** | a sharp **survival-flip** signature — a cohort essentially present in one mesh, gone in the other |

## Verdict: both mechanisms are present — the clean separation needs a converged pair

The first cut shows the inter-mesh spread is **not purely one or the other**:

- **A diffuse component** (median relative error 0.53 across half the lineage
  axis) — supports the ongoing Oracle's "23% is an honest conditioning floor."
- **Survival bits** (a 1532× relative spike at an isolated τ) — supports the
  fresh Oracle's "finitely many survival bits."

So on this evidence the two Oracles are describing two real pieces of the same
spread, not competing hypotheses.

**Why it is not yet definitive.** This compares a coarse (93) and a medium
(185) mesh that are 62% apart — *neither is converged*, so the large diffuse
component is inflated by the coarse mesh simply being under-resolved
everywhere. The fresh Oracle's test as designed wants **two both-converged
meshes** (e.g. the adaptively refined 173- vs 320-node pair, which differed by
only 2.3% in a probe): at convergence the diffuse part should shrink and reveal
whether the *residual* is dominated by the survival bits. That run is
compute-heavy (refine is very slow) and is the right next step — a dedicated
job, not a quick cut.

**Actionable regardless.** The decomposition machinery is built and cheap to
re-run on saved schemes. And the absolute-error finding already sharpens item
B's fix: because ΔJ mass sits where J's mass sits (young cohorts, τ small),
the fresh/ongoing "point the insertion at the moment" move (a ρ·|c| / φ·ρ
refinement indicator) is aimed correctly — but the 1532× isolated spike says a
pure smooth-refinement indicator will *miss* the survival-flip cohorts unless
it is paired with the survival-margin guard band both Oracles flagged. I.e.
the two proposed sub-moves (moment-aware insertion **and** mollify/guard the
survival threshold) are both needed; neither alone covers what this shows.
