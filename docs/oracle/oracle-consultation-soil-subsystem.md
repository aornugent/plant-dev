# Cheap forward and reverse-mode resolution of a near-singular sub-block in an adaptively-stepped ODE

A numerical-methods question. No application context is needed or given; the objects below are an
initial-value problem, its adaptive integrator, and a reverse-mode AD tape.

## Setup
An IVP `y' = f(y, t; θ)`, `y ∈ ℝ^N`, `N ≈ 10²–10³`, integrated on `t ∈ [0, T]` by an **adaptive
embedded explicit Runge–Kutta** method with the usual local-error step controller. `θ` is a small
parameter vector (`|θ| ≈ 5–20`). We compute **reverse-mode gradients** (operator-overloading AD tape)
of scalar functionals of the solution w.r.t. `θ`; the tape records every RK stage of every accepted
step, so the reverse sweep's cost scales with the accepted step count, same as the forward solve.
`10³–10⁵` steps per solve.

`y` splits into a large block `x ∈ ℝ^{N−L}` and a **small block `u ∈ ℝ^L`, `L ≤ 5`**, two-way coupled
through **low-rank** terms (`x`'s rates read `u`; `u`'s rate reads a low-rank aggregate of `x`). All
adaptivity is global: one step size for the whole state.

## The near-singularity in the small block
Each component `u_ℓ` is confined to `u_ℓ ≥ u_min`. The `u`-block RHS is **near-singular approaching
that bound**: the relevant partial `∂f_u/∂u` (and other quantities the coupling reads off `u`) varies
over **several orders of magnitude** across the feasible range — moderate away from the bound,
diverging as `u_ℓ → u_min` — and the map is effectively non-Lipschitz there (hence the clamp/projection
that keeps `u ≥ u_min`). The `u`-block also carries a time-dependent inhomogeneity with **closely
spaced kinks** (piecewise-smooth in `t`), which drives rapid excursions of `u` toward the bound.

## The measured phenomenon (the datum to reason from)
On representative runs the step controller's collapse — what dominates cost — is **accuracy-driven,
not stability-driven**, and is localised to `u`'s excursions toward the singular bound:
- The smallest steps occur where `u` is **near `u_min`** (the singular end), where the local relaxation
  rate `|∂f_u/∂u|` is **small** (slow). So the small steps are **not** the classical explicit-stability
  limit, which would bind where `|∂f_u/∂u|` is *large* (away from the bound). They are the controller
  keeping local truncation error bounded through a genuinely rapid, near-singular excursion.
- Quantitatively: `corr(log Δt, log d) = −0.91`, where `d = ‖u − u*‖/‖u‖` is the distance from the
  instantaneous algebraic balance `f_u = 0`. Every smallest-decile step has large `d` (up to ~25);
  ~90% of steps sit near balance (`d ≈ 0`) with large `Δt`; ~10% are the tiny-step near-singular
  excursions.
- **Two standard remedies are therefore ruled out, by measurement:** (i) a **quasi-steady-state**
  reduction of `u` (solve `f_u = 0` for `u*`, integrate `x` alone) is invalid in exactly the ~10% of
  steps that cost the most, since `u` is far from `u*` there; (ii) an **A-stable / implicit** stepper
  does **not** enlarge the steps, because the limit is accuracy on a real rapid feature of the
  solution, not stability of a fast mode decaying to a slow manifold. Please treat both as already
  refuted for this problem and reason past them.

## What we need
The near-singular excursions of the `u`-block resolved **cheaply in both the forward solve and the
taped reverse sweep**, without corrupting the trajectory or its gradient. The gradient must still
match a finite difference of the discrete solver as run.

## Facts an answer can rely on
- `L ≤ 5` (the hard block is tiny); the large block `x` is smooth and shares the global step size.
- The time-dependent inhomogeneity is recorded data (piecewise-smooth, kinked).
- A **reformulation is on the table**: a change of coordinates for the `u`-block, a regularisation of
  the near-singular RHS, or a change to how `u` is stepped relative to `x` — provided it keeps the
  forward solution and the reverse-mode gradient correct (a documented, controlled change of the
  discretisation is acceptable).
- The `−0.91` correlation and the accuracy-vs-stability diagnosis are trustworthy (instrumented).

## Questions (open; invite reframing)
1. **Is the cost intrinsic or a coordinate artifact?** Does the near-singular RHS as `u → u_min`, or
   the choice of `u` as the integrated variable, make the excursion needlessly hard to resolve — i.e.
   is there a **change of variables** (or a regularisation of the singularity) in which the same
   excursion is smooth and cheaply integrated, and whose inverse keeps the functionals and their
   reverse-mode gradient exact?
2. **Local treatment of the excursion.** Is there a per-step **analytic or asymptotic** treatment of
   the near-singular passage (an exponential integrator, a local closed-form over the kink, a
   boundary-layer expansion) that resolves it without many small steps **and** is differentiable in
   reverse mode?
3. **Multirate / sub-cycling.** Should the `L ≤ 5` block be **decoupled from the global step size** —
   sub-cycled with its own local error control — so its tiny-step excursions do not force the large
   block to small steps? If so, what is the **correct reverse-mode adjoint of a sub-cycled/multirate
   scheme**, and how does the two-way low-rank coupling constrain the interface?
4. **Ranking.** Of the features — the near-singular RHS at the bound, the kinked time-dependence, the
   projection at `u_min`, the global shared step size, the two-way coupling — which is load-bearing
   for the cost and which is incidental?
5. A **cheap discriminating experiment** for whatever mechanism you judge most likely, before we build.
