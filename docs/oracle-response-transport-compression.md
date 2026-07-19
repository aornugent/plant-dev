# Oracle response — the compression term `Cᵢ = ∂ₓg` (received 2026-07-19)

Response to [`oracle-consultation-transport-compression.md`](./oracle-consultation-transport-compression.md).
**Verdict: reframe accepted — the two symptoms are one representational commitment (transporting pointwise
log-density `ℓ`), not a stability-vs-differentiability tension. Transport log-mass instead and the
troublesome term is identically zero.** Full response archived below; predictions to test before building.

## Headline
- **The value blow-up is genuine, not a numerical instability.** With `g = max(0, ĝ)`, a stalled region is
  an **absorbing interface**: flux `g·n` arrives and stops, mass accumulates as a growing atom, pointwise
  density `n` (hence `ℓ`) diverges *in the continuum, in exact arithmetic* — while the **mass** in any
  neighbourhood stays bounded. Signature matches ours exactly (moderate sustained `C`, no spike, no
  `Δx→0`): patient exponential growth of `ℓ` until `exp` overflows.
- **Scheme A is not stable by virtue — it is stable by blindness.** A one-sided sub-grid slope on the
  smooth side never sees the interface, so it *undercounts compression where compression is the physics*.
  A is a silent regularisation of the model; it overflows too, under extreme forcing, once the smooth-side
  slope alone is large. So the A/B dichotomy is **faithful vs regularised**, not stable vs unstable.
- **The gradient error is a severed tape, nothing deeper.** A's private `g(xᵢ±ε)` probes are passive, so
  `∂C/∂θ` (dominated by `g_S·S′`, the coupling channel) is never taped → the `O(1)`, δ-independent error
  concentrated in coupling-only parameters. JVP=VJP proves nothing (same recorded graph). B is correct
  only because it is built from neighbour values already active on the tape. **Engine rule: a rate defined
  as a numerical derivative must be computed from active quantities; any private numeric probe of an
  active field severs the tape.**
- **The hybrid failure is a theorem.** `value(A)+[B−passive(B)]` = derivative of trajectory B on the value
  of trajectory A; correct iff A≡B. The no-floor instance (0.2% value gap → sign-flipped gradient,
  −451.9 vs +139.9) shows **closeness of values does not imply closeness of gradients** in a nonlinearly
  self-coupled system. Corollary: even fixing A's severance yields the exact gradient of a *regularised*
  model.

## The conserved-content identity (the crux)
Under Scheme B, `Cᵢ = d(log Δxᵢ)/dt` term for term. Define per-point **log-mass** `λᵢ = ℓᵢ + log Δxᵢ`:
```
dλᵢ/dt = −(Cᵢ + rᵢ) + Cᵢ = −rᵢ ≤ 0
```
So log-mass is **monotone nonincreasing between insertions, pointwise, unconditionally** (stall or not).
B's overflow is an overflow of the *representation* (`exp(ℓ)`) of a perfectly bounded state — the atom is
a cluster of finite masses at shrinking spacings, representable in `(x, m)` forever, not in `(x, ℓ)` past
`ℓ≈709`.

**Flagged inconsistency in our instrumentation:** sustained `|C|≈25` ⟹ `log Δx` drifts at 25, so "ℓ up by
hundreds" and "spacings normal" cannot both hold for the same point under the identity. Either the
sustained-C window is short, or the identity is broken in code — prime suspects: the **one-sided end
formulas** and **insertion re-indexing** (a new point at `x_b` changes neighbours' `Δx` discontinuously
with no compensating `ℓ` change = a silent mass jump).

## The reformulation (minimal change, stated completely)
**State** `(xᵢ, λᵢ)`, `λᵢ = log mᵢ`. **Rates:**
```
dxᵢ/dt = g(xᵢ, Sᵢ, u; θ)     (unchanged)
dλᵢ/dt = −r(xᵢ, Sᵢ, u; θ)    (NO compression term — cancelled exactly)
```
**Coupling weights** `wⱼ = exp(λⱼ)` directly (no `Δx` on the tape for the field). **Compression** is not
computed anywhere — both schemes, the `ε` machinery, the stencil adjoints are **deleted**. Pointwise
density, if any output needs it, is the derived diagnostic `mᵢ/Δxᵢ` formed at consumption.
- **Value can never overflow** (any regime, floor or not, forced or not): `λ'=−r≤0`.
- **Gradient question evaporates**: no numerical `∂ₓ` on the tape, no severance, no `1/ε` near the kink,
  shorter tape. The floor `max(0,ĝ)` stays as an ordinary continuous kink on a pointwise rate; `g`
  continuous across `ĝ=0` ⟹ no first-order interface term (why B already matched the re-adapting FD to
  0.5–1% despite the frozen schedule — that band is the frozen-schedule approximation, not the kink).

**Costs (honest):** (i) value shifts by the A→B discrepancy (~0.2% no-floor; **larger locally near stalls
in floor-active instances, because that is where A was wrong** — frame as removing a regularisation
error). (ii) **Insertion needs one model decision**: a newborn gets a **mass** `m₀ = influx density ×
initial cell width` (natural: flux integrated over the inter-insertion interval, fixed by the frozen
schedule) instead of an `ℓ`. Only genuinely new modelling content. (iii) **Audit one reduction**: the
time-integral weighted by `exp(ℓᵢ)` *alone* (no `Δxᵢ`) is pointwise-density-weighted; if the continuum
object is `∫(…)·n dx` a `Δx` was dropped, if it is genuinely pointwise its value near stalls is dominated
by a diverging quantity and A's bounded answer is a blindness artifact. Either way it is presently
discretisation-inconsistent or physics-divergent.

## Fallbacks if the reformulation is refused (both strictly dominated)
1. Fix the severance: compute A's `±ε` probes through the active field (tape `∂C/∂θ`).
2. Better: kernel is low-rank separable with `κ(z,z)=0`, so `S′(z)` and `C=g_x+g_S·S′` are **closed form**
   (diagonal boundary term vanishes by the double zero) — removes stencil/`ε`/severance. **But** an
   analytic `C`, like A, still evaluates the smooth-branch slope, so the genuine `ℓ` divergence at stalls
   **persists** — confirming the overflow was never a discretisation instability.

## Q5 — where `∂C/∂θ` is genuine: **everywhere.** Including the query-motion `dS′/dx·dx/dθ` and the
coupling `g_S` component; the FD reference contains it. No legitimate "don't differentiate it" or
"differentiate a cousin" option (the hybrid proves it). The only artifact was the severed implementation.

## Falsifiable predictions (ordered by cost)
1. **λ-monotonicity audit (hours, logging only).** Under Scheme B, `ℓᵢ+log Δxᵢ` decreases at rate `rᵢ`
   between insertions, pointwise, even during blow-up. If it rises → identity broken in code; localise to
   step+index (expect insertion re-indexing or an end formula). Resolves the §2.1 instrumentation
   inconsistency.
2. **Tape A's probes actively (days).** Coupling gradient error collapses from `O(1)` (729 vs 4.2) to the
   B band (0.5–1%), residual outliers only for points whose stencil straddles `ĝ=0`. If not → a second
   severance (look at value-keyed caches on field reads).
3. **The reformulation (the real experiment).** Transport `(x, log m)`. Overflow vanishes identically in
   ALL regimes; reverse gradients match FD within the frozen-schedule band across all parameters
   (coupling-only included), both model instances, with no per-term compression treatment. Any residual
   overflow ⟹ insertion/end bookkeeping (pred. 1 finds it); any residual coupling-gradient miss ⟹ leak
   elsewhere in the `S` pipeline (caches, replayed-not-recomputed knot values).
4. **Blindness corroboration (cheap).** A overflows precisely when the upwind one-sided slope of `g` at
   pre-stall points becomes large; bounded when steepness lives only across the interface A never sees.

## Closing reframe
The tension is not "stability vs differentiability of `∂ₓg`." It is **faithfulness vs boundedness of the
pointwise-density representation at a genuine concentration** — and the gradient failure was never part of
that tension, just a taping bug in the same line. Move to mass and the tension has nothing to attach to:
the stable scheme and the differentiable scheme become the same scheme because the troublesome term is
identically zero.
