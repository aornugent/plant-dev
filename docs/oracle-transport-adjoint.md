# Consistent, well-conditioned adjoint of a stabilized advection operator

A self-contained problem in differentiable numerical methods. No application
knowledge is assumed or needed.

> **CORRECTION (post-consultation).** A control experiment overturned this
> document's premise that "using the exact analytic operator makes the forward
> integration unstable" (Setup, option 3). It does **not**: computing the
> transport term through the live path with a vanishing step (down to 1e-10,
> one-sided *and* centred) is stable and matches production. The instability I
> had attributed to the analytic operator came from an implementation that
> **froze the coupling field `S`**, thereby dropping the `∂g/∂S · dS/dx` term —
> a different, incomplete derivative. So option 3 is **not** blocked by
> stability, and the true issue is narrower: how to record the θ-derivative of
> the transport term *including* the `dS/dx` coupling, where `dS/dx` must come
> from a consistent (secant-like) channel rather than the reconstruction's
> analytic tangent. The Oracle's conditioning analysis of the on-tape stencil
> derivative (options 1–2 below) remains valid and useful; the stability claim
> in option 3 does not. Kept for the record; see plant#39 for the corrected
> account.

## Setup

We solve a scalar conservation law of advection type by method of lines: a
density `n(x, t)` transported along a coordinate `x` with velocity `g`,

```
∂n/∂t + ∂/∂x ( g · n ) = source,        g = g(x, θ, S)
```

discretized on a set of points `x_i`. The velocity `g` is a **smooth,
closed-form** function of the coordinate `x`, a vector of scalar **parameters
θ**, and a **coupling field** `S` that is reconstructed at each step from the
whole solution — so the points interact and the system has feedback.

The transport requires the spatial derivative of the velocity,
`D = ∂g/∂x`, evaluated at each point. In the solver `D` is **not** the analytic
derivative; it is a **one-sided (upwind) finite difference** in `x` with a small
fixed step `h`:

```
D = ( g(x) − g(x − h) ) / h .
```

This one-sided form is a deliberate **stabilization**: using the exact analytic
`∂g/∂x` in this term makes the forward integration **unstable** (the coupled
solution blows up) on the grids we run. The upwind stencil is the stable
discretization and it *defines* the solution we compute.

`g` may contain a smooth but sharply-varying nonlinearity (a regularized
one-sided limiter, `p(u) = ½(u + √(u² + ε²))`, whose second derivative peaks at
`~1/ε`). This is not the source of the problem below — the trilemma is present
for smooth `g` — but it sharpens option 1.

## Goal

The reverse-mode AD gradient `dM/dθ` of a scalar functional `M` of the final
solution, i.e. a discrete adjoint of the whole solve. `g` is cheaply
differentiable by AD to any order (forward, reverse, nested).

## The trilemma

Every natural way to record the θ-sensitivity of the transport term fails:

1. **Discrete adjoint — differentiate the stencil on the tape.** Exact and
   *consistent* with the computed solution, but the recorded derivative is
   `(g_θ(x) − g_θ(x − h)) / h`: a finite difference of the parameter-sensitivity
   over the tiny fixed step `h`. It is ill-conditioned and, near the regularized
   nonlinearity (`g_θx ~ 1/ε`), explodes — observed `~10⁶`–`10⁷` where the true
   gradient is `~10²`.

2. **Inject the analytic derivative.** Keep the stencil *value* on the
   trajectory (stable) but record the exact analytic `∂g/∂x` and its exact
   θ-sensitivity (available, well-conditioned, kink-free, one extra tangent
   sweep). This is stable and well-conditioned, but the value comes from the
   **upwind** scheme and the derivative from the **centred** scheme: on the
   coupled/feedback solve the two disagree, so the gradient is **inconsistent** —
   a bounded systematic bias (~1.5%). Exact only in the uncoupled limit (a single
   point, where the term never feeds back).

3. **Use the analytic operator throughout.** Consistent and machine-precise,
   but it is exactly the forward-unstable choice — usable only if the
   regularization `ε` is loosened enough to change the modelled solution by
   several percent.

## The question

How to obtain a gradient that is **consistent** with the stabilized (upwind)
solution AND **well-conditioned**, without destabilizing the forward solve?

Specific angles we'd value a verdict on:

1. **Well-conditioned discrete adjoint.** Option 1 is the *correct* discrete
   adjoint; the blow-up is conditioning, not correctness. Its exact value is
   `(g_θ(x) − g_θ(x − h)) / h`, where both `g_θ(x)` and `g_θ(x − h)` are
   available **exactly** by AD (no differencing of `g` needed). Does evaluating
   the stencil's adjoint as the difference of **two exact tangent evaluations**,
   rather than as one finite-difference-of-tangents, remove the catastrophic
   cancellation while remaining the exact discrete adjoint? Or is the `1/h`
   amplification of a genuinely `O(h)` numerator fundamental here?

2. **Step scale.** `h` is a numerical-derivative step decoupled from the grid.
   Should the upwind difference instead be taken over the actual inter-point
   spacing `Δx` (a true grid stencil), so its adjoint is naturally `O(1)`-scaled?
   What is the right coupling between the stabilization step and the AD?

3. **Continuous vs discrete adjoint.** Would deriving the continuous adjoint of
   the advection equation and then discretizing it give a better-conditioned,
   consistent gradient — and what is the adjoint-consistency caveat (adjoint of
   the upwind scheme vs upwind of the adjoint)?

4. **Differentiable stabilization.** Is there a discretization of the transport
   operator that is simultaneously forward-stable and has a bounded,
   well-conditioned adjoint (flux limiters, entropy-stable / dual-consistent
   schemes)?

5. Any established technique for the general shape: *a stabilized discrete
   operator whose exact adjoint is well-defined but ill-conditioned, while the
   analytic operator it approximates is forward-unstable.*

## Facts an answer can rely on

- `g` is closed-form; exact `∂g/∂x` and `∂²g/∂x∂θ` are available and
  well-conditioned by AD.
- Forward values are identical between the plain and AD runs; the error is
  purely in the recorded derivative.
- The bias in option 2 vanishes without coupling and grows with the coupling
  strength — it is a scheme-consistency error, not noise.
- Forward stability is non-negotiable; loosening the regularization to buy
  differentiability changes the modelled solution and is a last resort.
- `h` is small and fixed, independent of the (possibly non-uniform, moving)
  point spacing.
