# The coupling-slope derivative: a no-simple-secant tradeoff

A sharpened statement of the open residual from component 1 of
`oracle-transport-adjoint.md`. Domain-agnostic; no application knowledge needed.
This is the live problem to take to the Oracle. (The earlier
`oracle-growing-state-adjoint.md` was a misdiagnosis and is retracted.)

## Setup (recap of the resolved part)

Reverse-mode AD gradient `dM/dθ` of a functional `M` of a coupled multi-body ODE
solve. Bodies couple only through a shared low-dimensional field `S`,
reconstructed each step from all bodies (a `k`-knot spline). A key rate term is
the **transport/coupling term** — the total spatial derivative of a body's
velocity `g`:

```
D  =  dg/dx  =  ∂g/∂x|_S  +  ∂g/∂S · (dS/dx)
```

The first part (fixed-field partial) is exact by forward-over-reverse. The
coupling part needs `dS/dx`, taken as a **secant** of the reconstructed field
(the robust value channel — component 1's resolution). That part is settled.

## The open residual, now pinned

The remaining question is the **θ-sensitivity of the coupling term**, which the
reverse sweep needs:

```
d/dθ [ ∂g/∂S · (dS/dx) ]  =  (d(∂g/∂S)/dθ)·(dS/dx)  +  (∂g/∂S)·( d(dS/dx)/dθ )
```

The last factor, **`d(dS/dx)/dθ`**, has no good treatment. It is computed as a
secant of the field's parameter-sensitivity, `(S_θ(x) − S_θ(x−h))/h`. Both ways
of handling it are wrong, in complementary ways:

- **Drop it** (treat `dS/dx` as a constant w.r.t. θ): the term
  `(∂g/∂S)·d(dS/dx)/dθ` vanishes — a **missing edge**.
- **Keep it, secant over the sub-grid step `h`** (`h ≪` the body/knot spacing
  `Δx`): the `eps≪Δx` **staircase** from component 1 — ill-conditioned.
- **Keep it, secant over a fixed larger step**: breaks both classes.

## The witness (measured)

Two parameter classes, one metric that integrates the coupling term (the density
transport, which reads `D`):

- **direct-effect** parameters: large `∂g/∂x|_S` contribution, small coupling
  correction.
- **coupling-only** parameters: their *entire* effect on the metric is the
  coupling term (a parameter that enters only through `S`; its analytic direct
  sensitivity is ~0 — a **null channel** that reads any dropped/spurious coupling
  term at full magnitude and sign).

Relative error of the reverse gradient vs a converged finite difference:

| treatment of `d(dS/dx)/dθ` | direct-effect params | coupling-only (null-channel) params |
|---|---|---|
| **drop** | ✓ 0.03–3.5% | ✗ **40–200×, wrong sign** |
| **keep, sub-grid `h`** | ✗ **~2.3× overshoot** | ✓ 5–7% |
| keep, fixed `Δx=0.5` | mixed | ✗ 40× |

The diagnostic that exposed it: a null-channel functional (a coupling-only
parameter whose true sensitivity is ~0). With `d(dS/dx)/dθ` dropped, the computed
gradient equals `0 − (dropped term)`, so it reads the dropped term directly:
observed **66** where the truth is **−0.32** on a single body (no multi-body
effects at all — this is a per-step property of the term, not an emergent one).

## Why it is a genuine tradeoff (the mechanism)

The staircase error in the secant `(S_θ(x) − S_θ(x−h))/h` **scales with how much
the parameter moves the query point `x` through the sub-grid window** — i.e. with
the parameter's own influence on the trajectory. So:

- a **direct-effect** parameter moves `x` strongly → large window straddling →
  the kept secant is **spuriously large** (2.3× overshoot), while dropping it
  costs almost nothing (the true coupling correction is a small fraction of its
  large direct signal);
- a **coupling-only** parameter barely moves `x` → the kept secant is **accurate**
  (5–7%), while dropping it removes its *entire* signal (40–200× wrong).

The same numerical object is thus simultaneously too-noisy-to-tape for one class
and essential-to-keep for the other. Detach and un-detach are the two horns; no
single secant step is correct for both.

## The question

How should `d(dS/dx)/dθ` be computed so it is **consistent** (not dropped) AND
**well-conditioned** (no staircase) for *both* parameter classes at once?

Specific angles:
1. **Grid-spacing secant, done right.** Component 1's standing candidate was a
   secant over the true point spacing `Δx` rather than the sub-grid `h`. A single
   fixed `Δx` failed (table row 3). Does it need the **true local knot/body
   spacing** (variable per evaluation), and if so what sets it — the field's own
   reconstruction resolution? Is there a principled `Δx(x)` that tiles and makes
   `d(dS/dx)/dθ` `O(1/Δx)`-conditioned for all θ simultaneously?
2. **Differentiable-derivative reconstruction.** Should `dS/dx` come from a
   reconstruction whose *derivative* converges (a smoothing spline with a
   roughness penalty tuned for slope accuracy; a Hermite fit of `(S, dS/dx)`
   jointly), so that `S_θ` and `dS/dx_θ` are both well-defined without a secant of
   a secant?
3. **Structured coupling intermediate.** Express the coupling through an explicit
   `k`-vector node (the field knots) with stored, dot-product-checkable partials
   `∂knot/∂(body state)` and `∂rate/∂knot`, so `d(dS/dx)/dθ` is assembled from
   well-conditioned analytic pieces rather than a difference of the field's
   parameter-sensitivity. (This is the standing `CouplingChannel` proposal; its
   *cost* rationale was measured illusory, but this correctness/testability
   rationale is new and may revive it.)
4. **Is dropping actually correct in a limit?** The dropped term's true
   contribution is genuinely tiny for direct-effect parameters and genuinely
   large for coupling-only ones. Is there a rigorous decomposition that keeps the
   term only where it is well-conditioned (the coupling-only directions) and drops
   it where it is both negligible and ill-conditioned (the direct directions) —
   without hand-classifying parameters?

## Tested: the channel split is right, but the current implementation can't realize it

The Oracle's partial-detach fix (freeze the query coordinate, keep the knot
values live — the data channel) was implemented and measured. It **half-worked**,
and the failure mode pins the fix to angle 3:

- Freezing the query coordinate everywhere it appears (the field read, the slope
  read, AND the nested directional-derivative's evaluation point and scratch
  state) while keeping `dEdh` live: **null channel → exact** (−0.32), and
  **coupling-only params good** (k_I 5.5%, b_2 7.3%). But **direct-effect params
  still overshoot** (b_0 ~40%, height_0 2.7×).
- The overshoot is **intrinsic to the current implementation shape**, not the
  query coordinate: `d(dS/dx)` is not taped directly — it is injected as the
  *forward tangent* of the coupling scalar inside a nested forward-over-reverse
  evaluation of `dg/dx`. That injection **conflates two knot-sensitivity
  channels**: the field *value* read `E(x)` already carries `Σ wᵢ·dcᵢ/dθ`, and the
  injected slope tangent re-carries `Σ aᵢ·dcᵢ/dθ`; the reverse sweep sums both,
  double-counting the knot sensitivity for parameters where `dcᵢ/dθ` is large
  (the direct-effect params). No detach/keep setting separates them per-parameter,
  because both channels ride the *same* injected object.

**Follow-up spike (the new blocker).** The clean channel split was then tested
directly: freeze the field-*value* knot channel (strip `E(x)`'s θ) and keep only
the query-frozen field-*slope* channel `Σaᵢ·dcᵢ/dθ` live. Result: null channel
exact (−0.32), coupling-only params good (k_I 4.5%, b_2 7.3%) — **but direct-effect
params STILL overshoot** (b_0 740 vs 319, 2.3×). So the overshoot is **not** the
value/slope double-count; the **query-frozen slope channel itself is
spurious-large for direct-effect parameters**. This **contradicts the analysis
above**, which predicted the data channel (`aᵢ ≈ wᵢ′`, O(1), query frozen) to be
well-conditioned for all θ. It is not: for a parameter with large `dcᵢ/dθ` (a
strong-growth trait that re-shades the whole stand), `Σaᵢ·dcᵢ/dθ` contributes
~130% where its true contribution is ~0.5%. **This is the open blocker** — why is
the query-frozen slope channel ill-conditioned for direct-effect parameters when
the channel analysis says it should be O(1)? No proposed structured node can be
specced until this is understood, because it would inherit the same overshoot.

**Implication for the fix (pending the blocker).** The clean channel split is only
expressible if the
coupling is taped as an **explicit structured object** (angle 3): the `k`-vector
of knot values `c` as the tape's only live coupling node, with the downstream read
as an explicit `∂(rate)/∂c = ` (frozen-weight) linear map — so `dS/dx`'s
θ-sensitivity flows *once*, through `dc/dθ`, with analytic weights, and the query
motion is structurally excluded (the interface accepts only `c`). The
forward-tangent injection cannot do this because value and slope share one
tangent-carrying scalar. So angle 3 is not merely *an* option — it is the
**required realization** of the channel split; angles 1–2 improve the value but
cannot fix the double-count.

## Falsified: the curvature-cancellation fix (measured, this round)

The Oracle's final resolution proposed that `d(dS/dx)/dθ` is a **material
(Lagrangian) derivative** whose two legs form an advective cancelling pair, and
that keeping the query-motion leg with the *analytic spline curvature* `S″` as a
frozen per-step coefficient would cancel the data-leg overshoot for direct-effect
parameters:

```
d(dS/dx)/dθ  =  Σᵢ wᵢ′(x̄)·dcᵢ/dθ   [data, live knots, frozen query]
             +  S″(x̄)·dx/dθ          [query-motion, S″ frozen, dx/dθ live]
```

This was implemented (odelia `basic_spline::deriv2`, an interpolator
`slope_with_query_motion` returning `deriv(x̄) + deriv2(x̄)·(u−x̄)`, wired through
ResourceSpline/K93_Environment, injected LIVE in `node.h`) and **measured
directly on a single cohort**. It does not work, and the leg measurement says why.

At the cohort's own height after seg1 (`h=4.925`, the cohort is the tallest so it
sits at the canopy top, `E=1.0`, `dE/dθ≈0` — unshaded):

| param | dh/dθ | slope value | data leg `Σwᵢ′·dcᵢ/dθ` | query-motion `S″·dh/dθ` |
|---|---|---|---|---|
| b_0 (direct) | 87.6 | 0.368 | **326.9** | **2.5e-7 ≈ 0** |
| k_I (coupling-only) | ~0 | 0.368 | 37.0 | ~0 |

The query-motion leg is **nine orders of magnitude too small** to cancel the data
leg: `S″(x̄) ≈ 2.8e-9`, whereas cancellation needs `S″ ≈ 326.9/87.6 ≈ 3.7`. The
light field is locally **near-piecewise-linear** at the read point (small
curvature), yet its *slope* is strongly parameter-sensitive (the self-shading
transition just below the cohort moves sharply with a growth trait). A near-linear
segment has `S″≈0` but a large `Σwᵢ′·dcᵢ/dθ`; the two are not tied, so the
advective identity `data = −S″·dx/dθ` simply does not hold for this field.

Census consequence (single cohort, forward-tangent AD vs central FD, confirming
this is a per-step property, not an emergent multi-cohort one):

| metric | b_0 | b_1 | k_I | 
|---|---|---|---|
| **height** (no dg/dh) | ✓ exact (6e-9) | ✓ exact (3e-9) | ✓ ~0 |
| **log_density** (reads dg/dh) | ✗ **−557 vs −48 (10.7×)** | ✗ **617 vs 62 (8.9×)** | ✓ −0.322 vs −0.320 |

Height (which integrates `g`, not `dg/dh`) is machine-exact for the direct params,
localising the entire error to `dg/dh`'s θ-sensitivity. Keeping the slope channel
live (data + query-motion) overshoots direct params ~10× on log_density; detaching
it (the committed state) is exact for direct params and drops the coupling-only
signal. **The tradeoff is intact and the curvature fix does not resolve it.**

The real discriminant is confirmed to be **dx/dθ** (does the parameter move the
query through the field): for k_I the data leg is genuine (dx/dθ≈0, nothing to
cancel), for b_0 it is spurious (dx/dθ large, but no curvature to cancel against).
The correct cancelling partner — if one exists — is **not** the analytic field
curvature. A plausible next hypothesis: the spurious data leg is the cohort's OWN
contribution to the field slope at its own height (self-shading read on the kink),
which a Lagrangian read that excludes the query cohort's self-contribution would
remove — but that is field-reconstruction surgery, not a per-step coefficient.

**Status: reverted to the committed detach.** deriv2 and the query-motion machinery
were removed (measured non-cancelling; would be dead code). Direct-effect census
params remain exact; coupling-only params (k_I, b_2, height_0) remain
bounded-wrong on coupling-integrating metrics — the documented interim.

## Facts an answer can rely on

- The fixed-field partial `∂g/∂x|_S` and the coupling *value* `dS/dx` (secant) are
  correct and settled; only `d(dS/dx)/dθ` is open.
- The error is a **per-step** property (single body, no multi-body coupling
  needed to see it) — it just needs a metric that reads the transport term `D`.
- Forward-mode JVP == reverse-mode VJP throughout: not a mode asymmetry; a
  genuinely dropped/ill-conditioned term identical in both.
- Null-channel readout: on a coupling-only parameter (true sensitivity ~0), the
  dropped term appears sign-flipped at full magnitude — the cleanest gate for any
  proposed fix.
- Forward VALUES are bit-identical under detach/un-detach; only the recorded
  derivative changes.
- The `k`-vector field has small `k` (~17) and its knot positions are frozen
  double (accepted); only the knot values carry θ.
