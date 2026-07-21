# T3 — common-field ΔJ decomposition: the mesh non-convergence is 100% FIELD-SHIFT (protocol), not survivor-flips (item B)

*2026-07-21. v2 Oracle response, claim 3 — the decisive fork after T5a killed the
granularity story. Decompose the mesh N→(denser) J-movement on a common frozen field:
`J_NN` (N members on N's field, sanity), `J_2NonN` (denser members on N's field),
`J_2Nsc` (denser, self-consistent). quadrature = `J_2NonN−J_NN` (placement at fixed
field), fieldshift = `J_2Nsc−J_2NonN` (κ-amplified feedback). Survivor-flips would show
as a localized spike in the per-lineage |Δg|; feedback shows as diffuse.
Script: `scripts/tf24-benchmarks/common_field_decomp.R`. Frozen-field probe is
trustworthy here because T5a showed max weight fraction ~1.6% (probe error O(that)).*

## Result — both sequences: ~0% quadrature, 100% field-shift, diffuse

| sequence | N→denser | J_N | J_denser(sc) | quadrature | field-shift | spike? (top-3-bin) | at small τ_ins |
|---|---|---|---|---|---|---|---|
| intense_storms (12 yr) | 94→140 | 2.73e-7 | 8.54e-8 | 6.3e-10 (~0%) | −1.88e-7 (100%) | 0.03 (no) | 0.94 |
| whiplash (16 yr) | 96→148 | 2.10e-6 | 3.28e-7 | 2.1e-9 (~0%) | −1.77e-6 (100%) | 0.02 (no) | 0.78 |

Sanity: `J_NN` reproduces `J_N` to relgap 1e-9 (intense) / 1e-5 (whiplash) — the
frozen-field probe is exact; the machinery is sound.

## Reading — the fork is resolved

- **Placement/quadrature of J is already converged at the production mesh.** Putting a
  ~1.5× denser measure on the *same frozen field* changes J by ~0% (6e-10, 2e-9). The
  J-moment `∫φ dμ` does not need a finer measure.
- **The entire mesh non-convergence is field-shift:** the denser mesh produces a
  different coupling field `a*(t)`, and (amplified ~10× by feedback, κ from 9b) that
  shifts J by 69–84%. **100% of ΔJ** on both sequences.
- **It is diffuse, not a survivor-flip.** The per-lineage |Δg| is spread (top-3-of-4000
  bins carry only 2–3%), concentrated at small τ_ins where J's mass sits — **not** a
  localized spike at a dying lineage. **The 9c 1532× spike was in a low-g lineage's
  *relative* error, invisible in absolute J** — real, but J-negligible.

## Consequences (this closes the forward-convergence question)

1. **Item B (model-side J mollification) is NOT the blocker.** The survival-boundary
   discontinuity does not drive the mesh non-convergence — field-shift does. The rung-2
   verdict ("intrinsic discontinuity → must mollify J model-side") is **overturned**:
   the problem is numerical (field convergence), not a model defect.
2. **To converge J, converge the field `a* = ∫c dμ`.** J's own integrand is converged;
   the field (a c-weighted moment of the same measure) converges more slowly / is more
   feedback-sensitive. The production default mesh is far from field-converged (a 1.5×
   refinement still moves the field enough to drop J ~70–84%) — this is the mechanism
   behind rung-2's "default schedule badly placed."
3. **Why the g-mass placement indicator anti-correlated (rung 2 / 9c).** It targeted
   J's integrand `g`, which is *already converged*; the error lives in the **field**.
   The correct indicator targets the field's convergence, weighted through the feedback
   resolvent `(I−T′)⁻¹` — exactly the Oracle's claim-1 proposal, and T1's dominant modes
   are those resolvent weights.
4. **T4's time-arbitrage is orthogonal and still live** (member block over-resolved in
   *time*; this is about the *measure* resolving the field).

## The coherent picture (T1 + T5a + T3)

- **T1:** the field `a*` is well-conditioned; the continuum J exists and is stable.
- **T5a:** the measure refines cleanly (max weight fraction ~1.6%, ∝1/M); no heavy atom.
- **T3:** the mesh non-convergence is 100% field-shift (feedback), diffuse, at small
  τ_ins — not placement, not survivor-flips.

**So 9c/rung-2 non-convergence is a protocol problem in the coupling field, fixable in
numerics: resolve `a*` (a field/resolvent-weighted member mesh), not J's integrand and
not the model. Item B is off the critical path.** The concession condition is fully
falsified (spectrum not near +1; measure not granularity-limited; non-convergence is
feedback-field, not intrinsic).

## Caveats

- Two sequences (intense_storms, whiplash); the snap-to-ode-grid made "2N" ~1.5×
  (140/148 vs 94/96) — still a clean denser-vs-coarse comparison, but not exactly 2×.
- Field-shift is measured N→1.5N once; it should *shrink* as the mesh converges (T1).
  A multi-level field-shift sequence (N→2N→4N) would confirm the field-convergence rate
  and let a Richardson read on `a*` (not run here).
