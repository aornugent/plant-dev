# A coupled transport solve and one ill-behaved gradient term: a complete description

For the same two respondents. Domain-agnostic; no application knowledge assumed. The
scope is narrow — one term's reverse-mode sensitivity misbehaves — but the intent of
this document is the opposite of narrow: to describe the whole system *completely*, so
that a feature we have not thought to interrogate can be recognised as load-bearing.
We have a strong suspicion we are missing something structural. Nothing below is a
proposed fix; it is all description and measurement.

---

## 1. The continuous model

A linear transport (conservation) law over a scalar coordinate `x`, with nonlocal
coupling and a boundary influx:

```
∂ₜ n(x,t) + ∂ₓ[ g(x, S; θ) · n ] = − r(x, S; θ) · n ,     x > x_b
influx boundary condition at x = x_b (new mass enters at the low end)
```

- `n(x,t)` is a density over `x`; `θ` is the parameter vector we differentiate w.r.t.
- `g` is the **velocity** (advects `x` upward), `r` a **loss rate**. Both are smooth
  closed-form functions of the local coordinate, the parameters, and a shared field.
- `S(·,t)` is a **coupling field** through which all mass interacts (there is no
  pairwise interaction). It is a pointwise nonlinear map of an **aggregate**:

```
S(z,t) = ψ( A(z,t) ; θ ) ,   ψ = exp
A(z,t) = ∫_{x ≥ z} κ(z, x; θ) · n(x,t) dx        (a ONE-SIDED cumulative aggregate)
```

  Only mass at coordinates `x ≥ z` contributes to the field at `z`. `κ` is a smooth,
  one-signed kernel that vanishes as `x → z⁺` at the boundary of its support.

- **Self-consistency:** `n` generates `A` generates `S`, and the dynamics of every
  parcel of `n` read `S` at that parcel's own coordinate. Every location is thus both
  a source of the field and a reader of it.

We want the reverse-mode AD gradient `dM/dθ` of a functional of the solution. The
functionals of interest are **moments**: `M = ∫ φ(x) · n(x,T) dx`.

## 2. The discretization (exactly as run)

- **Method of characteristics.** Parcels `xᵢ(t)` solve `dxᵢ/dt = g(xᵢ, S(xᵢ))`. New
  characteristics are introduced at `x_b` on a schedule of times; the number of live
  characteristics (and the state-vector dimension) **grows during the integration**.
- **Density variable.** Each characteristic carries a **log-density** `ℓᵢ`, evolved by
  `dℓᵢ/dt = −( ∂ₓg(xᵢ, S) + r(xᵢ, S) )`. The term `∂ₓg` is the spatial derivative of
  the velocity along the coordinate — the **compression/transport term**. (This is the
  representation actually used; it is stated here as a fact of the implementation, not
  as a necessity.)
- **Field reconstruction.** `A` is evaluated at `k` **fixed** knot positions `z_m`
  (`k ≈ 17`; positions are frozen doubles, only the values carry `θ`). The aggregate at
  each knot is a quadrature over the live characteristics (trapezoid in `x`, so each
  characteristic enters with a weight set by its spacing to its neighbours). `S` is a
  cubic spline through `ψ(A(z_m))`, rebuilt every step.
- **The two reads.** A characteristic's rates read the field as a **value** `S(xᵢ)`
  (inside `g` and `r`) and the compression term reads its **slope** `∂ₓS(xᵢ)` (inside
  `∂ₓg`, via the chain rule `∂ₓg = ∂ₓg|_S + ∂g/∂S · ∂ₓS`). The slope is taken as a
  finite-difference secant of the reconstruction.
- **Non-smooth primitives** in the rates (a positivity clamp on the velocity) are
  replaced by a smooth surrogate (softplus-type, width `ε`), so the rate path is
  differentiable.
- **Record/replay.** An adaptive pass in plain arithmetic records the step schedule and
  the introduction times; the differentiated pass replays that schedule fixed. So the
  schedule is `θ`-independent by construction.

## 3. The gradient task and the one hard term

Reverse-mode AD (AD scalar for `double`, tape the replayed solve, one reverse sweep)
returns `dM/dθ`. Almost everything differentiates transparently and correctly. The
fixed-field partial `∂ₓg|_S` and the field **value** read `S(xᵢ)` (with its
`θ`-sensitivity through the knots) are settled and faithful.

The single open object is the **`θ`-sensitivity of the compression term**,
`d(∂ₓg)/dθ`, which requires `d(∂ₓS(xᵢ))/dθ` — the sensitivity of the field *slope* read
at a characteristic's own moving coordinate. Because that coordinate is a source of the
field, this term carries a self-interaction: the characteristic responds to the slope
of a field it itself shapes.

## 4. What is measured (data, not interpretation)

Correctness reference: a converged central finite difference of the model exactly as
run (same replayed schedule). Test uses a small ensemble (`N = 2`) and two parameter
classes that stress the term oppositely:

- **trajectory-moving** parameters — strongly move a characteristic's own path;
- **coupling-only** parameters — whole effect is through the field; a **null-channel**
  parameter has true sensitivity ≈ 0 on a functional and so reads any spurious term at
  full magnitude and sign.

Firm findings:

1. **It is a derivative-rule inconsistency, not a numerical one.** Forward values are
   bit-identical to the plain solve; forward-mode JVP equals reverse-mode VJP to machine
   precision; yet the reverse gradient disagrees with the converged FD by an `O(1)`
   factor on moments that read the compression term, and the disagreement does not
   shrink with FD step. (JVP=VJP certifies both modes linearize the *same* taped
   operator; it does not certify that operator is the derivative of the map that
   produced the value.)

2. **Every pointwise treatment of the slope's `θ`-sensitivity is right for one class and
   wrong for the other.** Representative behaviour (relative error vs FD):

   | treatment of `d(∂ₓS)/dθ` | trajectory-movers | coupling-only (null-channel) |
   |---|---|---|
   | drop it (freeze the query, no slope-θ) | ✓ ~0.2% | ✗ 189×, wrong sign |
   | keep it, query frozen | ✗ 2.3× | ✓ ~5% |
   | keep it, query un-frozen (one construction) | ✗ 3.4× | ✓ **machine-exact** |
   | remove the reader's own contribution at the knots, re-reconstruct | ✓ ~1% | ✗ 94% low |

3. **The self-interaction's two halves add; they do not cancel.** Decompose the slope's
   `θ`-sensitivity into a *source-motion* piece (the reader's own contribution to the
   field moving as `θ` moves it) and a *query-motion* piece (the reader riding over its
   own imprint as it moves). Standard adjoint reasoning predicts these cancel to a small
   residual. Measured, they have the **same sign** and compound (the "query frozen 2.3×"
   → "query un-frozen 3.4×" step is the query-motion piece adding to, not cancelling,
   the source-motion piece). The two pieces cancel **only** under a full self-consistent
   finite-difference rebuild (advance the characteristic *and* rebuild the field with the
   source at its new coordinate) — i.e. the cancellation is a property of the forward map
   that no pointwise on-tape construction we have tried reproduces.

4. **The same tape quantity is spurious for one class and essential for the other.** The
   reader's own contribution to the field, kept, over-attributes a trajectory-mover's
   gradient (2.3×) but *is* the entire correct signal for a coupling-only parameter.
   Removing it (row 4) fixes the movers and destroys the coupling-only parameters. At
   this ensemble size the reader's self-share of the local aggregate is `O(1)`; it is
   expected to scale down with ensemble size.

## 5. Structural features of the formulation (any of which may be load-bearing)

Listed with equal weight and without advocacy — some may be essential, some incidental,
some free to change. We do not know which.

- The aggregate is **one-sided** (`∫_{x ≥ z}`): a location's own contribution to the
  field is supported entirely on one side of it.
- The pointwise map is `ψ = exp` (sources superpose in `A`, not in `S`).
- The density is carried as a **transported log-density** whose ODE contains `∂ₓg`;
  the compression term exists because of this state choice. The same moments are, in
  principle, expressible from other book-keeping (characteristic spacing / a conserved
  per-characteristic weight), in which `∂ₓg` need not appear in the state.
- The field is **low-rank** (`k ≈ 17`) and its knot positions are **frozen**; only knot
  values carry `θ`.
- The slope is read by a **secant** of the reconstruction (not the analytic spline
  derivative); the value and slope currently come from constructions that are not
  guaranteed identical.
- The characteristic reads the field at its **own** coordinate, and the read direction
  (which side of the source the secant straddles) is a free choice.
- The set of characteristics **grows** mid-solve; the schedule is frozen.
- The functionals are **moments** (linear in `n`); whether any needed quantity is a
  non-moment (pointwise density, a density-dependent rate) is a property of the model we
  can state case by case.
- The correctness reference is FD of the **model as run** (finite ensemble, this
  discretization) — not of any continuum limit.

## 6. The question

We are fairly sure we are looking at the problem through the wrong variable or the wrong
boundary, because the term that misbehaves (`d(∂ₓS)/dθ`) is internally consistent (JVP =
VJP), faithful in value, and yet unreconcilable with the model's own finite difference by
a single pointwise rule — and the cancellation that *would* reconcile it lives in the
forward map, not in the object we are differentiating.

So, deliberately open:

1. **Which of the structural features in §5 is load-bearing** for whether this gradient
   can be made simultaneously faithful (matches FD of the model as run) and
   well-conditioned for both parameter classes — and is the difficulty *intrinsic* to a
   self-consistent field read at a moving source, or an *artifact* of a representational
   choice (the density variable, the read side, the value/slope construction, the
   one-sidedness) that we have not questioned?

2. If the difficulty is representational, **what is the minimal change of variables or of
   the differentiated quantity** that removes it — and what does that change cost or
   forbid elsewhere?

3. If it is intrinsic, **what is the precise obstruction** (a statement of the form "no
   pointwise linearization of a one-sided self-consistent slope read can match the
   self-consistent forward difference, because …"), so we can stop looking for a local
   fix and price the non-local one?
