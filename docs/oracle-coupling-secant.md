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
