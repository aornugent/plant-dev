# Supplementary addendum + correction to the fundamentals elicitation

> For the **fresh-context** Oracle that answered `oracle-consultation-
> fundamentals.md`. This carries (1) an erratum on one factual error your
> ranked-first finding depended on, (2) the measurements we ran on your
> findings before writing back — per the house rule of falsifying before
> building, (3) facts about the system that were missing or wrong in the
> original elicitation and that change the picture, and (4) the questions
> that remain. The original elicitation otherwise stands.

---

## 1. Erratum: the forcing is a C² cubic spline, not piecewise-linear

Your ranked-first finding (the "forcing node lattice" as the prime suspect
for the broadband accuracy limit) read that §4 described the drivers as a
"fine piecewise-linear node grid" while §1 called `b(t)` a `C²` spline. **§1
is correct; §4 was wrong.** The code evaluates the driver through a standard
tridiagonal **cubic spline** (`C²`), and that is the only representation any
measured sequence used. Piecewise-linear exists but is an unused option — so
your test (b) ("rerun with the C² spline option") is inverted: the spline is
what already ran. The knot count/spacing you inferred (~daily, ~3×10⁻³,
~10× below the median step) are right; only the continuity class was wrong.

## 2. What we measured on your findings

### 2a. The forcing knots (your stone 1): confirmed as a mechanism, refuted as a lever

A `C²` cubic spline still has a **discontinuous third derivative at every
knot**, so an order-5 method cannot reach full order across one — the weaker
residual worth testing. We logged the distance from every step attempt to
the nearest daily spline knot (offline, from saved per-step data):

- **Real, size-independent effect.** Holding step size to a 0.15×DK-wide
  window (so "crosses a knot" vs "fits between" differs only by *phase*), a
  step that crosses a knot rejects **+12 to +36 pp more** than an
  identically-sized step between knots — all 5 scenarios, growing as more of
  the step sits past the knot. Your structural point ("no instrument ever
  looked at the grid nodes") was correct: our clip and classifier only
  logged sparse *value-change features*, never the dense spline knots.
- **But minor.** Size-matched counterfactual: only **1.3–3.9 pp of the ~30 %
  rejection** is knot-attributable. The median step is 0.08–0.22×DK and
  84–92 % of steps are sub-knot on smooth cubic arcs; only 6–16 % of attempts
  cross a *value-changing* knot (flat dry-spell knots are exactly constant
  under a cubic spline — no jump). The 47× "wall" (effective order ≈ 1.8) is
  **not** explained by the knots; if it were, the attributable fraction would
  be large, not 2–4 pp.

Net: the forcing joint is confirmed but is not the frontier-reopener the
piecewise-linear premise implied. The broadband order limit lives in the
*continuous* structure (the C¹-but-violently-curved coupling field).

### 2b. The error norm (your points 4–5 / max-over-a-growing-block): confirmed

We built a norm-argmax log (which state component sets `rmax` per attempt,
bit-identical off) and ran the bank. Your extreme-value hypothesis holds:

- **192–345 distinct components** set `rmax` among rejected attempts
  (max dim ~800–1000), normalised entropy **0.77–0.83** — the attribution is
  broad, not one stiff mode.
- **Members, not soil, dominate**: soil sets `rmax` on only 24–34 % of
  rejects in 4 of 5 scenarios (one soil-heavy exception at 55 %).
- **Consecutive churn 0.23–0.28** — the argmax persists a few steps then
  drifts as the population grows: enough persistence to be non-memoryless,
  too diffuse for a serial (PI) predictor, which is exactly why our PI
  controller measured +13–29 % work.

This establishes the *precondition* for your goal-oriented / J-relevance-
weighted norm (members do set the norm, broadly). It does **not** yet
establish its *safety*: we cannot yet tell whether the rmax-setting members
are marginal-ρ (safe to down-weight) or heavy/near-threshold (down-weighting
would corrupt J). That cross-reference is our next measurement and the gate
on building it.

### 2c. The J spread across the member axis (your point 2 / lineage decomposition): mixed, first cut

J is a trapezoidal integral over nodes of `fecundity_i × patch_density_i × S_D
× birth_rate_i`, where `node_times` is the lineage coordinate and `fecundity_i`
is survival-weighted (carries the extinction structure). We decomposed the
inter-mesh ΔJ along the lineage axis. First cut (one scenario, coarse 93-node
vs 2×-densified 185-node mesh, 62 % apart):

- The **absolute** |Δg| is concentrated to the same degree as J's own mass
  (50 % of ∫|Δg| in 1.7 % of the axis; the integrand itself: 1.5 %) — i.e.
  in absolute terms the error just tracks where J lives (young cohorts, where
  the `patch_density(τ)` weight is highest, since a patch is likeliest to be
  young).
- The **relative** per-lineage error is **diffuse** (median 0.53 over 51 % of
  the axis) **with a sharp survival-flip spike** (1532× at an isolated τ).

So both mechanisms are present: a diffuse conditioning component *and*
finitely-many survival bits. On this evidence you and the context-carrying
Oracle are describing two real pieces of the same spread, not competitors.
Caveat: this pair is not converged (62 % apart), so the diffuse part is
inflated; the clean separation needs two *both-converged* meshes, which is a
heavier run (see §3b).

## 3. Facts missing or wrong in the original elicitation (that change the picture)

1. **The production member mesh is a *fixed* schedule, and it is far from
   mesh-converged.** The elicitation described member insertion but did not
   say that the default run uses a *fixed* node schedule (not the adaptive
   refiner). Measured: the default (~96 nodes) gives J that is **~6× off** the
   adaptively-refined value (2.15×10⁻⁶ vs 3.4×10⁻⁷ on one scenario), and even
   two *refined* meshes (173 vs 320 nodes) differ by ~2.3 %. So the member
   axis, not the time axis, carries the dominant *reproducible* error, and the
   "23 % inter-scheme spread" is plausibly mostly this. This reframes your
   points 2 and 4 as the main event.
2. **The adaptive mesh refiner is very expensive.** Building a refined
   schedule re-runs the SCM many times (>15 min per scheme at 15–20 yr). This
   is why the converged-pair decomposition is not a quick test, and why any
   "remesh every K steps" proposal (your stone 4) must be costed against a
   refiner that is already a large fraction of a run.
3. **The per-node integrand structure**, not stated before: J's mass sits at
   *young* lineage ages because the patch-age weight `patch_density(τ)` is
   monotone-decreasing (disturbance), peaking at τ→0. Any moment-aware
   insertion indicator inherits this — refinement should concentrate at small
   τ *and* at the isolated survival-flip ages, which are elsewhere.
4. **The SCM cost is O(M) per RHS eval in practice**, confirmed: a dense
   fixed mesh (hundreds of cohorts) over a long horizon is minutes per single
   pass. This bounds every member-side idea (your stones 3, 4) — they must pay
   for themselves against an already-O(M) baseline.

## 4. The questions

Given the erratum, the measurements, and the missing facts:

1. **Is the forcing joint now closed as a major lever?** The knot effect is
   real but ~2–4 pp; the sub-order-2 wall is unexplained by it and points at
   the continuous coupling field. Is there a measurement that would localise
   *that* — the thing actually setting the effective order — as cleanly as the
   knot test localised the forcing?
2. **Given that the member mesh carries a ~6×-to-2.3 % error while the time
   integrator is at its floor, is the member axis the real frontier?** If so,
   which of your member-side moves survives the O(M) SCM cost and the
   expensive refiner — control-field interpolation (stone 3), remeshing
   (stone 4), or moment-aware insertion + survival-guard (your point 2 +
   the context Oracle's item B) — and what is the cheapest measurement that
   would rank them before we build?
3. **For the J-weighted norm (your point 5, precondition now confirmed):**
   the safety question is whether the rmax-setting members are marginal or
   near-threshold. Is cross-referencing each rmax member's ρ / distance-to-
   survival-threshold the right and sufficient test, or is there a sharper
   one? This is the only measured-live lever that could cut *accepted* steps.
4. **With the record corrected, is there hidden leverage still unsurfaced?**
   Four of your five "soft joints" remain (inner equation, measure, norm,
   observable); the forcing joint is now corrected and largely closed. Where,
   ranked by information-per-cost with a falsifier attached, would you look —
   so we do not declare the forward problem closed one correction too early?
