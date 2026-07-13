# Consistent reverse-mode gradients through a stabilized transport term

A self-contained, domain-agnostic problem statement for outside input. No
knowledge of the originating application is assumed. The question is general to
differentiable programming through numerical schemes.

## Setup

We integrate a system of ordinary differential equations forward in time with an
explicit adaptive Runge–Kutta method. The state is a vector that grows over the
run (new components are appended at known times; think of a discretization whose
number of sample points increases). Among the equations is one **transport
term** of the following shape. For each sample point `i` there is a coordinate
`x_i(t)` and a companion quantity `n_i(t)`, coupled as

```
dx_i/dt = g(x_i, θ, S(t))                    (1)  advection velocity
dn_i/dt = -(∂g/∂x)(x_i, θ, S(t)) - m_i        (2)  transport / conservation
```

- `g` is a **smooth, closed-form** function of the coordinate `x`, a vector of
  scalar **parameters θ**, and a **shared field** `S(t)`.
- `S(t)` is a coupling field reconstructed at each step from all the sample
  points (a spline fit through `(x_i, something(n_i))`). Every point sees the
  same `S`, so the points interact. `∂g/∂x` in (2) is the spatial derivative of
  the velocity `g` with respect to the coordinate `x`, evaluated at that point.
- `g` contains a **regularized one-sided clamp**: the raw velocity is passed
  through `p(u) = ½(u + √(u² + ε_c²))`, a C∞ surrogate for `max(0, u)`. This is
  a genuine smooth function, but its second derivative has a peak of height
  `~1/ε_c` at `u = 0`. With `ε_c` small (bio-faithful), points that sit near the
  clamp corner experience a large but finite `∂²g/∂x²`.

`∂g/∂x` in (2) is **not** computed analytically in production. It is computed by
a one-sided finite difference in the coordinate direction with a small fixed
step `h ≈ 1e-6`:

```
(∂g/∂x)_stencil = ( g(x) − g(x − h) ) / h                (3)
```

## Goal

We want the gradient of a scalar functional `M` of the final state (e.g. a
weighted sum of the `n_i` and `x_i` at the end of the run) with respect to the
parameters θ, using **reverse-mode automatic differentiation** (a discrete
adjoint of the whole time integration). We run the solver with an AD scalar
type substituted for `double`; the forward pass tapes every operation and the
reverse pass returns `dM/dθ` for all parameters at once.

## The core difficulty

The finite-difference form (3) is **not** merely a lazy stand-in for the
analytic `∂g/∂x`. It is doing numerical-stabilization work: it is effectively
the **upwind** discretization of the advection term (2). We have verified that
substituting the **exact analytic** `∂g/∂x` into (2) makes the forward
integration **unstable** — the coupling field `S` runs out of bounds once the
points interact — unless the clamp is smoothed so aggressively (`ε_c` ~ 500×
larger) that the model's behaviour changes by several percent. The exact
(centred) spatial derivative is the wrong discretization for this hyperbolic
transport on a coarse, moving point set; the one-sided stencil is the stable
one. So **the stencil defines the solution we actually care about.**

Now consider the three ways to get the θ-gradient of `M`, and how each fails:

**Option 1 — differentiate the stencil on the tape (the true discrete adjoint).**
Let the AD type flow through (3). The reverse pass then differentiates (3) w.r.t.
θ, which is
```
d/dθ [ (g(x) − g(x−h)) / h ] = ( ∂g/∂θ(x) − ∂g/∂θ(x−h) ) / h .
```
This is the *consistent* gradient of the stencil-defined solution. But it is a
finite difference of `∂g/∂θ` over the tiny step `h ≈ 1e-6`, and near the
regularized clamp `∂²g/∂x∂θ` is `O(1/ε_c)`. The two effects together make this
quantity explode (observed ~`1e6`–`1e7` where the true gradient is `~10²`).
Empirically unusable.

**Option 2 — keep the stencil *value*, inject the exact analytic *derivative*.**
Compute `∂g/∂x` on the tape by forward-over-reverse (a tangent/forward-mode
seed in the `x` direction, carried on the outer reverse tape), which gives the
exact analytic spatial derivative and its exact θ-sensitivity, well-conditioned
and kink-free. Then *rebase* it onto the stencil value: return
`analytic − value(analytic) + stencil_value`, so the forward value equals the
stencil (stable trajectory) while the recorded derivative is the analytic one.
This is stable and well-conditioned, and it is **exact for a single point**
(where the transport term never feeds back into `M`). But for interacting
points it injects the derivative of the **centred** scheme onto a trajectory
produced by the **upwind** scheme: value and derivative come from *different*
discretizations, so the gradient is biased (observed ~1.5% consistent
under-estimate across all parameters — a real, bounded error, not noise).

**Option 3 — use the analytic term in the trajectory too.**
Consistent (value and derivative from the same scheme) and machine-precise, but
requires the analytic trajectory, which is unstable unless the clamp is
over-smoothed — i.e. it changes the modelled system.

## The question

Is there a way to obtain a **consistent** and **well-conditioned** reverse-mode
gradient of a functional of the **upwind-stabilized** solution — without
(a) destabilizing the forward integration, (b) forming an ill-conditioned
finite difference of the parameter-sensitivity, or (c) hand-writing second
derivatives per model?

Concretely, we are looking for guidance on any of:

1. **Adjoint/dual consistency of stabilized schemes.** Option 1 is the exact
   discrete adjoint, and the "blow-up" is a *conditioning* problem, not a
   correctness one. Is there a standard reformulation of the discrete adjoint of
   a one-sided/upwind stencil that avoids dividing a parameter-difference by the
   tiny step `h` — e.g. differentiating the stencil *symbolically* so the `1/h`
   cancels analytically, leaving a well-conditioned expression that still equals
   the discrete adjoint? (The stencil is `(g(x)−g(x−h))/h`; its exact θ-adjoint
   is `(g_θ(x)−g_θ(x−h))/h`, which *is* representable without a numerical
   difference if `g_θ` is available analytically via AD at both abscissae.)
   Does evaluating the stencil’s adjoint as *two exact tangent evaluations* (at
   `x` and `x−h`) rather than one finite difference of tangents fix the
   conditioning while preserving consistency?

2. **Choosing the differentiation step to match the scheme.** The step `h` in
   (3) is a *numerical-derivative* step (`1e-6`), decoupled from any physical
   grid spacing. Should the "upwind" character instead be expressed as a
   difference over the actual inter-point spacing (an `O(Δx)` grid stencil), so
   that its adjoint is naturally well-scaled? What is the right relationship
   between the stabilization step and the AD?

3. **Differentiable limiters / regularization that preserves the adjoint.**
   Is there a smoothing of the transport term (not the clamp — the *upwind
   difference itself*) that is simultaneously (i) stabilizing for the forward
   advection and (ii) has a bounded, well-conditioned adjoint at bio-faithful
   regularization? (Flux-limiter literature, entropy-stable schemes, etc.)

4. **Continuous vs discrete adjoint.** Would deriving the *continuous* adjoint
   PDE of the transport equation and then discretizing it (rather than
   differentiating the discrete scheme) give a better-conditioned, consistent
   gradient here? What are the consistency caveats (adjoint of the upwind scheme
   vs upwind of the adjoint)?

5. **Any established technique** for "differentiate through a numerically
   stabilized scheme" where naïve discrete adjoint is well-defined but
   ill-conditioned, and the continuous/analytic operator is unstable in the
   forward direction.

## Facts an answer can rely on

- `g` is closed-form and cheaply differentiable to any order by AD (forward,
  reverse, and nested forward-over-reverse are all available).
- The exact analytic `∂g/∂x` and its exact θ-sensitivity are available,
  well-conditioned, and kink-free (they cost one extra tangent sweep).
- Forward-pass values are bit-identical between the plain and AD runs; the issue
  is purely in the recorded derivative.
- The single-point case is exact under Option 2; the error appears only when
  points couple through the shared field `S`, and scales with that coupling.
- The step `h` in the stencil is fixed (`~1e-6`) and independent of the moving
  point spacing. The clamp regularization `ε_c` is a separate, tunable smoothing
  whose second derivative peaks at `1/ε_c`.
- Stability of the forward solve is non-negotiable; changing the modelled
  behaviour (over-smoothing) to buy differentiability is a last resort.
