# A cheap gradient of a first moment, with the forward solve held fixed

For the same respondents. Domain-agnostic; no application knowledge assumed. This
sharpens the previous statement with the essential model structure and adds one hard
constraint that changes the game: **the forward solve is fixed — its computed values
must stay bit-for-bit what they are today.** We are not asking how to re-pose the model;
we are asking whether the *gradient* can be obtained cheaply and correctly given that the
forward is immovable, by exploiting a property of the functional we have not leaned on:
it is a first moment.

---

## 1. The system, completely

A linear transport (conservation) law over a scalar coordinate `x`, with nonlocal
coupling and a boundary influx, solved by the method of characteristics:

```
∂ₜ n(x,t) + ∂ₓ[ g(x, S; θ)·n ] = − r(x, S; θ)·n ,     x > x_b
```

- `n(x,t)` a density over `x`; `θ` the parameter vector. `g` velocity (advects `x`
  upward), `r` loss rate; both smooth closed-form in the local coordinate, `θ`, and a
  shared field `S`.
- **Coupling field**, a pointwise nonlinear map of a one-sided aggregate:

```
S(z,t) = ψ( A(z,t); θ ),   ψ = exp
A(z,t) = ∫_{x ≥ z} κ(z, x; θ)·n(x,t) dx          (ONE-SIDED cumulative aggregate)
```

  Only mass at `x ≥ z` contributes at `z`; `κ` is a smooth, one-signed kernel vanishing
  as `x → z⁺`. By Leibniz, `∂ₓA(z) = −κ(z,z)n(z) − ∫_{x≥z}∂ₓκ·n dx` — a boundary term at
  `x=z` plus a smooth interior part.

- **Reconstruction.** `A` is evaluated at `k` fixed knot positions (`k ≈ 17`, positions
  frozen; only values carry `θ`); the aggregate at each knot is a quadrature over the
  live characteristics; `S` is a spline through `ψ(A(z_m))`, rebuilt each step.

- **Discretization.** Characteristics `xᵢ(t)` solve `dxᵢ/dt = g(xᵢ, S(xᵢ))`. Each carries
  a **log-density** `ℓᵢ` with `dℓᵢ/dt = −(∂ₓg(xᵢ,S) + r)`; the term `∂ₓg` is the
  **compression** (spatial derivative of the velocity), read from a finite-difference
  secant of the reconstruction. New characteristics enter at `x_b` on a fixed schedule;
  the set grows. An adaptive pass records the schedule; the differentiated pass replays
  it fixed (so the schedule is `θ`-independent).

- **Non-crossing (a structural gift).** All characteristics obey the same scalar ODE, so
  by uniqueness their spatial order is invariant for all time. The one-sided membership
  sets `{j : xⱼ ≥ xᵢ}` are therefore **constant**; the aggregate is a prefix sum over a
  fixed order.

- **A conserved quantity.** Along the flow, `mᵢ = e^{ℓᵢ}·Δxᵢ` (density × local spacing)
  obeys `dmᵢ/dt = −r·mᵢ` — the compression of `n` and the stretching of `Δx` cancel. The
  discrete model carries `∂ₓg` **twice**: explicitly in `ℓ`'s ODE, and implicitly in the
  spacings/quadrature weights. The two are individually `O(1/Δx)`-large and cancel only
  in `m`.

## 2. The functional is a first moment — and moments are transport-free

The quantities we differentiate are **first moments**: `M = ∫ φ(x)·n(x,T) dx` (and
time-integrated variants). Integrating the PDE by parts,

```
dM/dt = ∫ φ[−∂ₓ(gn) − rn] dx = ∫ (φ'·g − φ·r)·n dx + boundary flux
```

— **`∂ₓg` does not appear.** The compression term is absent from the physics the moment
measures; it is present in the *computation* only because the state variable is a
pointwise density whose ODE carries it. Every downstream use of `n` in this system is a
moment of exactly this kind (the aggregate `A` is itself a moment, against
`κ(z,·)·1[·≥z]`).

## 3. The pathology (measured)

Reverse-mode AD of `M` is internally consistent (forward-JVP = reverse-VJP to machine
precision) and bit-identical in value, yet disagrees with a converged finite difference
of the model-as-run by an `O(1)` factor on any moment that reads the compression, and the
disagreement does not shrink with FD step. The cause is now understood: the reverse sweep
must differentiate `∂ₓg`, which is one member of the cancelling pair in §1, and the two
members are discretized by **different operators** (a reconstruction secant in `ℓ`'s ODE;
the actual spacing evolution in the weights), so their individually-`O(1)` sensitivities
do not cancel on the tape — they compound. No pointwise treatment of the compression's
`θ`-derivative reconciles it; only a full self-consistent finite-difference rebuild
(advance *and* rebuild the field with sources at their moved positions) exhibits the
cancellation, because it lives in the forward map, split across two state variables.

## 4. The constraint, and the challenge

**Constraint:** the forward solve is fixed. Its trajectory and its computed `M(θ)` must
remain exactly as they are — the stabilized compression stencil, the log-density state,
the reconstruction, all unchanged. (Re-posing the state variable is off the table for
this question; assume we must live with the model as written.)

**Lever:** the functional is a first moment, and §2 says its sensitivity is transport-
free in the continuum. The reverse sweep is currently spending all its difficulty
computing the `θ`-derivative of a term that the answer does not, in the limit, contain.

**Challenge:** obtain `dM/dθ` **cheaply** (reverse-mode, `O(1)` forward solves, not
`O(|θ|)`) and **well-conditioned**, by exploiting the moment structure so that the
ill-conditioned compression derivative is never the object differentiated — while the
forward pass is untouched. Concretely we want to understand:

1. Can the reverse computation of a first moment be **restructured to inherit the
   transport-free form** of §2 — differentiating `∫(φ'g − φr)n` rather than propagating
   adjoints back through the `∂ₓg` in `ℓ`'s ODE — even though the forward produced `M`
   through the density state? Is there an adjoint for the moment that bypasses the
   compression entirely?

2. If such a gradient exists, **which function's derivative is it?** The exact discrete
   adjoint of the fixed forward includes the (ill-conditioned, artifact-laden)
   compression contribution; a transport-free adjoint computes the sensitivity of the
   continuum moment. Characterize the discrepancy: is it exactly the discretization
   artifact of the two mismatched `∂ₓg` copies (in which case the transport-free gradient
   is *more* correct than the exact discrete adjoint, and the FD-of-the-model reference
   is the wrong yardstick), or does it discard something real?

3. Does the structure offer the cut-through? Specifically —
   - the **conserved product** `mᵢ = e^{ℓᵢ}Δxᵢ`: on the tape, `d(mᵢ)/dθ` should have the
     two `∂ₓg` copies cancel; can the moment's adjoint be assembled from `d(mᵢ)/dθ`
     (both factors already on the tape) so the cancellation is realized in reverse even
     though the forward carried the factors separately — and does the operator mismatch
     of §3 survive into `d(mᵢ)/dθ` or vanish there?
   - the **one-sided, fixed-membership** aggregate (§1): prefix sums over a constant
     order give every reader its exact coupling quantity with no membership ever
     flipping; does this let the coupling's `θ`-sensitivity be formed without any slope
     read?
   - the **Leibniz boundary term** `−κ(z,z)n(z)`: is the entire self-referential
     difficulty localized in this one edge term, and can it be handled as an explicit
     value while the smooth interior part is differentiated cleanly?

4. Is a **value-preserving derivative substitution** legitimate here — the forward emits
   the stabilized stencil value (trajectory unchanged), while the reverse rule for that
   one term is replaced by whatever the transport-free / conservation-consistent identity
   dictates — and if so, what is the precise rule, and in what sense does the resulting
   gradient remain the gradient of the model that was actually run?

## 5. What an answer may rely on

- The forward values are fixed and correct; only the gradient computation is open.
- The functional is a first moment; the aggregate is a moment; nothing consumes the
  density other than as a moment (no per-location rate reads the pointwise density).
- Forward-JVP = reverse-VJP throughout (any proposed reverse rule must hold in both
  modes).
- Characteristics do not cross: spatial order and one-sided memberships are constant.
- `ψ = exp`; the reconstruction is low-rank (`k ≈ 17`) with frozen knot positions; the
  schedule is frozen by record/replay.
- The conserved product `e^{ℓ}·Δx` obeys a loss-only ODE; the compression appears twice
  and cancels only in that product.

The one-line question: **given an immovable forward solve whose difficult term cancels
out of the very functional we want, can reverse mode be made to see that cancellation —
cheaply, and without re-deriving the model?**
