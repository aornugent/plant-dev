# Supplementary addendum + correction to the fundamentals characterisation

> For the reader of `oracle-consultation-fundamentals.md`. Same notation
> throughout: `x` (large block of `M` members `x_j`, coordinate `ξ_j`, weight
> `ρ_j`), `u` (small block of `L=5` reservoirs), `p*` (inner argmax), `a`/`s`
> (coupling channels), `b(t)` (forcing into reservoir 1), `J = Σ_j tw_j·φ(x_j)`
> (the moment functional), `θ` (parameters), `τ` (inner-solve tolerance). No
> application domain; none is needed. This carries (1) one erratum, (2) the
> measurements we ran on the findings before writing back, (3) facts about the
> system that were missing or wrong in the original characterisation and that
> change the picture, and (4) the open questions.

---

## 1. Erratum: `b(t)` is a C² spline, not piecewise-linear

The characterisation was internally inconsistent about the forcing. §1 called
`b(t)` a `C²` spline; §4 described the measured sequences as driven through "a
fine piecewise-linear node grid." **§1 is correct.** `b(t)` is evaluated
through a conventional tridiagonal **cubic spline (`C²`)**, and that is the only
representation any measured sequence used; piecewise-linear exists but is an
unused option. The knot count/spacing stated (~a few hundred knots per time
unit, spacing `≈ 3×10⁻³`, ~10× below the median accepted step) are right; only
the continuity class was wrong. Consequently the specific "order-5 across a
`C¹` kink → local `O(h²)`" mechanism does not operate — there is no `b'` jump
at a knot.

## 2. Measurements run on the characterisation's open threads

### 2a. The forcing spline knots — real mechanism, minor lever

A `C²` cubic spline still has a **discontinuous third derivative at every
knot**, so an order-5 method cannot reach full order across one. We logged the
distance from every step attempt to the nearest spline knot (offline, from
saved per-step data, all five sequences):

- **Real, size-independent effect.** With step size held to a narrow window
  (so "crosses a knot" vs "fits between knots" differs only by phase, not
  size), a step that spans a knot is rejected **+12 to +36 pp more** than an
  identically-sized step between knots — consistent across all sequences,
  growing as more of the step lies past the knot. No prior instrument had
  looked at the knots (only at the sparse forcing-*feature* times).
- **But small.** Size-matched counterfactual: only **1.3–3.9 pp of the ~30 %
  rejection fraction** is knot-attributable. The median step is 0.08–0.22
  knot-spacings, 84–92 % of steps are sub-knot on smooth cubic arcs, and only
  6–16 % of attempts cross a knot where `b` is actually *changing* (a cubic
  spline through equal values is exactly constant — flat stretches contribute
  no third-derivative jump). The wall (`≈ 47×` cost per 3 decades of
  tolerance past converged `J`, i.e. effective order `≈ 1.8`) is **not**
  explained by the knots; if it were, the attributable fraction would be
  large, not 2–4 pp. The broadband order limit lives in the *continuous*
  structure — the Lipschitz-but-violently-curved coupling field.

### 2b. The error norm as a maximum over a growing block — confirmed

We instrumented the adaptive controller to record, per step attempt, **which
state component attains the max scaled error `rmax`** (bit-identical when off).
Across all sequences:

- **192–345 distinct components** attain `rmax` among rejected attempts (state
  dimension `N ≈ 800–1000`), normalised entropy **0.77–0.83** — the
  attribution is broad, not one stiff mode.
- **Members dominate over reservoirs.** The reservoir block `u` attains `rmax`
  on only 24–34 % of rejected attempts in four of five sequences (one
  reservoir-heavy exception at 55 %); the rest are attained by members `x_j`.
- **Consecutive churn 0.23–0.28** — the arg-max component persists a few steps
  then drifts as `M` grows: enough persistence to be non-memoryless, too
  diffuse for a serial (PI-type) predictor. This is exactly why the PI
  controller we tried cost +13–29 % work: there is no serial structure to
  exploit.

This confirms the *precondition* for the goal-oriented / `J`-relevance-weighted
error norm (members do set the norm, broadly). It does **not** yet establish
its *validity*: we cannot yet tell whether the `rmax`-attaining members have
small `ρ_j` (harmless to down-weight) or are near the `ρ → 0` absorbing boundary
(where down-weighting would corrupt `J`). That cross-reference is the next
measurement and the gate on building it.

### 2c. The `J` spread across the member axis — mixed, first cut

`J = Σ_j tw_j·φ(x_j)` is a weight-weighted reduction over members; the reduction
is a quadrature over the member **insertion coordinate** `τ_ins` (the ordered
time at which each member was inserted — the lineage axis), and `tw_j` carries
both the member weight and a monotone-decreasing **insertion-time envelope**
`w(τ_ins)`. We decomposed the difference in `J` between two insertion
*schedules* (two discretised measures) along `τ_ins`. First cut, one sequence,
a coarse schedule (`M≈93`) vs a 2×-denser one (`M≈185`), which disagree by
**62 %** in `J`:

- The **absolute** discrepancy `|Δg(τ_ins)|` is concentrated to the same degree
  as `J`'s own integrand (50 % of the mass in 1.7 % of the axis, vs 1.5 % for
  the integrand) — in absolute terms the error just tracks where `J`'s mass
  already sits (small `τ_ins`, where `w(τ_ins)` peaks).
- The **relative** discrepancy `|Δg|/g` is **diffuse** (median 0.53 over 51 %
  of the axis) **with a sharp spike** (`1532×` at one isolated `τ_ins`) — the
  signature of a member present in one measure and absorbed (`ρ_j → 0`) in the
  other, i.e. one crossing of the absorbing/insertion manifold.

So both mechanisms coexist: a **diffuse conditioning** component *and*
**finitely-many absorbing-boundary crossings**. Caveat: this pair is not
converged (62 % apart), so the diffuse part is inflated by the coarse schedule
being under-resolved everywhere. The clean separation wants two *both-*
converged measures (§3b) and is a heavier run.

## 3. Facts missing or wrong in the original characterisation

1. **The production run uses a *fixed* insertion schedule, and it is far from
   converged in the measure.** The characterisation described member insertion
   on "an adaptive schedule" but the default solve in fact runs a *fixed*
   schedule, not the adaptive refiner. Measured: the fixed default (`M≈96`)
   gives `J` **~6× from** the adaptively-refined value (`2.15×10⁻⁶` vs
   `3.4×10⁻⁷` on one sequence), and even two *refined* measures (`M=173` vs
   `320`) differ by `~2.3 %`. So the **member axis carries the dominant
   *repeatable* error**, plausibly most of the "23 % inter-scheme spread,"
   while the time integrator is at its floor. This reframes the measure/`J`
   threads as the main event rather than a side item.
2. **The adaptive schedule refiner is very expensive** — it re-runs the whole
   forward solve many times to place members (`> 15` min per refined schedule
   at moderate `T`). Any "remesh the measure every `K` steps" idea must be
   costed against a refiner that is already a large fraction of a solve.
3. **The `J` integrand structure**, not previously stated: `J`'s mass sits at
   *small* `τ_ins` because the insertion-time envelope `w(τ_ins)` is
   monotone-decreasing. Any moment-aware insertion indicator inherits this —
   refinement should concentrate at small `τ_ins` *and* separately at the
   isolated absorbing-boundary crossings, which lie elsewhere on the axis.
4. **The `O(M)` cost of `f` is realised in practice**: a dense fixed schedule
   (hundreds of members) over a long horizon is minutes per single forward
   pass. This bounds every member-side idea — each must pay for itself against
   an already-`O(M)` baseline.

## 4. Open questions

1. **Is the forcing joint now closed as a major lever?** The knot effect is
   real but `~2–4 pp`; the effective-order-`≈1.8` wall is unexplained by it and
   points at the continuous coupling field. Is there a measurement that would
   localise *that* — the thing actually setting the effective order — as
   cleanly as the knot test localised the forcing?
2. **Given that the measure carries a `~6×`-to-`2.3 %` error while the time
   integrator is at its floor, is the member/measure axis the real frontier?**
   If so, which member-side move survives the `O(M)` cost and the expensive
   refiner — interpolating the control field `p*(ξ)` across members while
   keeping all `M`; periodic remeshing of the measure onto structured nodes;
   or a moment-aware (`ρ·|c|`, `φ·ρ`) insertion indicator paired with an
   absorbing-boundary guard band — and what is the cheapest measurement that
   ranks them before we build?
3. **For the `J`-relevance-weighted error norm (precondition now confirmed):**
   the open question is whether the `rmax`-attaining members have small `ρ_j`
   or lie near the `ρ → 0` boundary. Is cross-referencing each `rmax` member's
   `ρ_j` / distance-to-absorbing-boundary the right and sufficient test? This
   is the only measured-live lever that could reduce *accepted* steps.
4. **With the record corrected, is there hidden leverage still unsurfaced?**
   Of the problem-statement joints that were never varied — the inner-solve
   equation, the measure representation, the error norm, the observable — and
   with the forcing joint now corrected and largely closed, where, ranked by
   information-per-cost with a falsifier attached, would you look next? We are
   trying not to declare the forward problem closed one correction too early.
