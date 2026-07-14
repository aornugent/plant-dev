# A differentiable characteristic solver: forward parity, reverse gradients

For the same respondents. Domain-agnostic; no application knowledge assumed. We are not
looking for a patch to an existing gradient. We are looking for a method — possibly a
different one — that is at least as good as the current solver on the **forward** pass
and additionally yields correct parameter **gradients** on a reverse pass. Cost need not
match a finite-difference stencil; stability and performance comparable to the current
method suffice. The problem is well bounded; its structure is given in full below so a
breakthrough has everything it needs.

---

## 1. The system

A linear transport (conservation) law over a scalar coordinate `x`, nonlocally coupled,
with a boundary influx, solved by the method of characteristics:

```
∂ₜ n(x,t) + ∂ₓ[ g(x, S; θ)·n ] = − r(x, S; θ)·n ,     x > x_b
```

- `n(x,t)` a density over `x`; `θ` the parameters. `g` velocity (advects `x` upward),
  `r` loss rate; both smooth closed-form in the local coordinate, `θ`, and a shared
  field `S`.
- **Coupling field**, a pointwise nonlinear map of a one-sided aggregate:

```
S(z,t) = ψ( A(z,t); θ ),   ψ = exp
A(z,t) = ∫_{x ≥ z} κ(z, x; θ)·n(x,t) dx          (ONE-SIDED cumulative aggregate)
```

  Only mass at `x ≥ z` contributes at `z`; `κ` is smooth, one-signed, and vanishes as
  `x → z⁺`.
- **Discretization (the current method).** The distribution `n` is represented as a set
  of characteristics `xᵢ(t)`, each advected by `dxᵢ/dt = g(xᵢ, S(xᵢ))` and
  carrying a weight; new characteristics enter at `x_b` on a fixed schedule, so the set
  grows. The aggregate `A` is evaluated at `k` fixed knot positions (`k ≈ 17`) as a sum
  over characteristics and reconstructed to a spline `S`, rebuilt each step. Each
  characteristic also carries a **log-density** `ℓᵢ` obeying `dℓᵢ/dt = −(∂ₓg + r)`; the
  `∂ₓg` term (the compression, spatial derivative of the velocity) is read from a
  finite-difference secant of the reconstruction. An adaptive pass records the step and
  introduction schedule; a second pass replays it fixed.

## 2. Why the forward method is a characteristic method (and must stay diffusion-free)

This is the load-bearing forward requirement, and it constrains the solution space, so
it is stated before the gradient problem.

The coupling field is a **functional of the whole distribution, sharply sensitive to the
positions of mass, not merely its amount.** Concretely `A(z)` is a sum over
characteristics of `κ(z, xᵢ)·nᵢ`: the weight `nᵢ` (zeroth moment) says *how much* each
characteristic contributes; the **position `xᵢ` (first moment) says at which `z` it
contributes**, because `κ(z, xᵢ)` switches on only for `z` on one side of `xᵢ`. The
solution depends on **sharp features** of `S` — steep fronts at particular positions —
not on its average level; a downstream qualitative outcome hinges on a front being sharp
at a particular time.

The method of characteristics advects each position `xᵢ` **diffusion-free**: the front
stays sharp. A fixed-grid (Eulerian) scheme would introduce numerical diffusion that
rounds the front and can change the outcome qualitatively — so it is not an admissible
substitute here. **Diffusion-free advection of the first moment is a required property of
any forward method, not an incidental one.** (The zeroth-moment weight is comparatively
forgiving — it is integrated over — but the position is not.) The current method also
refines the characteristic set adaptively where positions move fastest, precisely to keep
this structure resolved.

Any proposed method must therefore preserve diffusion-free, sharp advection of the
characteristic positions; matching or improving on the current method's resolution,
stability, and cost is the bar.

## 3. The functional, and where reverse mode fails

The quantities differentiated are **first moments** `M = ∫ φ(x)·n(x,T) dx` (and
time-integrated variants); the aggregate `A` is itself a moment.

Reverse-mode AD of `M` through the current method is internally consistent (forward-JVP =
reverse-VJP to machine precision) and bit-identical in value, yet disagrees with a
converged finite difference of the model-as-run by an `O(1)` factor on any moment that
reads the compression `∂ₓg`, and the disagreement does not shrink with the FD step. The
reverse sweep must differentiate `∂ₓg`; this term is ill-conditioned to differentiate on
a fixed-knot reconstruction read at a moving, self-generated query, and no pointwise
treatment of its `θ`-derivative has been found faithful. The bulk of the reverse-mode
difficulty is concentrated entirely in this one term.

## 4. Facts about the system (stated flat; make of them what you will)

- The functional is a first moment; integrating the PDE by parts gives
  `dM/dt = ∫(φ'g − φr)n dx + boundary`, in which `∂ₓg` does not appear.
- Along a characteristic, `mᵢ = e^{ℓᵢ}·Δxᵢ` (weight × local spacing) obeys
  `dmᵢ/dt = −r·mᵢ`; the compression enters the discrete model twice — in `ℓ`'s ODE and in
  the spacings — and cancels in `mᵢ`. The two appearances are discretized by different
  operators.
- `∂ₓA(z) = −κ(z,z)n(z) − ∫_{x≥z}∂ₓκ·n dx`: a boundary term at `x=z` plus a smooth
  interior part.
- All characteristics obey the same scalar ODE, so their order is invariant and the
  one-sided membership sets `{j : xⱼ ≥ xᵢ}` are constant in time.
- `ψ = exp`; the reconstruction is low-rank (`k ≈ 17`) with frozen knot positions; the
  schedule is frozen by record/replay; forward-JVP equals reverse-VJP throughout.
- Nothing consumes `n` except as a moment (no per-location rate reads the pointwise
  density).

## 5. The challenge

Propose a method for this system — the state representation, the forward integrator, and
the reverse-mode gradient together — such that:

1. the **forward** pass matches or improves the current characteristic method: sharp,
   diffusion-free advection of the first moment; comparable stability, resolution, and
   performance; correct handling of the growing set;
2. the **reverse** pass yields **correct, well-conditioned** parameter gradients of the
   moment functionals — without the ill-conditioned compression derivative being the
   object it must differentiate;
3. and it is clear **which map the gradient is the derivative of**, and why that is the
   right one.

Cheapness is not required — a method that is more expensive than a finite-difference
stencil but stable, performant, and differentiable is entirely acceptable. We are asking
for the *right* method, not the smallest change to the current one; if the two coincide,
so much the better, and if they do not, say what the current method is missing.
