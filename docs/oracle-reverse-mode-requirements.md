# Reverse-mode gradients through a self-consistent coupling field

A domain-agnostic problem statement. No application knowledge is assumed.

---

## 1. The system

We integrate a parametrized ODE system forward in time. The state is a set of `N`
**characteristics** (points); point `i` carries a small fixed-width state vector,
including a coordinate `xᵢ(t)` that advects under a velocity `g`, and a transported
density `ℓᵢ(t)`:

```
dxᵢ/dt = g(xᵢ, S; θ)                       velocity
dℓᵢ/dt = −∂g/∂x (xᵢ, S; θ) − r(xᵢ, S; θ)   transport (compression) + a local rate
(+ a few bookkeeping integrals driven by g, r, and other local rates)
```

These are the characteristics of a first-order transport PDE; `−∂g/∂x` is the
compression term. `θ` is a parameter vector (`|θ| ≈ 5–20`). `N` is not fixed: new
points enter at a boundary on a schedule of times, so the state-vector dimension
**grows during the integration**.

## 2. The self-consistent coupling field

The points do **not** interact pairwise. They couple **only** through a shared field
`S(·, t)`, and the field is built from the points themselves. In full:

- **Aggregate.** At a coordinate `z`, an aggregate of all points' influence,
  `a(z) = Σⱼ κ(z, xⱼ, stateⱼ; θ)` — typically a one-sided sum/integral (only points
  on one side of `z` contribute).
- **Pointwise map.** A nonlinear map `s(z) = ψ(a(z); θ)` (e.g. an exponential).
- **Reconstruction.** `s` is **not** read directly. It is sampled on a fixed grid of
  `k` knots (`k ≈ 15–20`, knot positions fixed) and a `k`-knot interpolant `S` is
  built once per step. All reads that step go through `S`.
- **Read-back.** Point `i`'s rates use the interpolant's **value** `S(xᵢ)` and its
  **spatial slope** `∂S/∂x(xᵢ)`, evaluated at the point's own coordinate.

The self-consistency: the same set `{xⱼ}` supplies the sources of `S` (through `κ`)
**and** the query coordinates at which `S` is read. Every point is simultaneously a
**source** of the field and a **reader** of it, at a moving coordinate, through a
`k`-knot reconstruction that is rebuilt each step from the whole set.

There may eventually be more than one such field, at least one of which is not an
instantaneous functional of the points but carries its own ODE state (memory).

## 3. The objective and the requirement

We want the gradient `dM/dθ` of a scalar functional `M` of the terminal (or
time-integrated) state — a moment of the point distribution, or a survival-weighted
integral of a local rate.

The forward program computes `M_h(θ)`, a discretization of a modelled map `M(θ)`
(`h` denotes the internal resolution — step sizes, knot count, stencil steps).

**Requirement.** The gradient must be obtained by **reverse-mode automatic
differentiation** (one taped forward solve, one reverse sweep; the parameter count
makes per-parameter forward differentiation the wrong tool), and the outcomes must
be **correct in both directions**:

- **Forward:** `M_h(θ)` is the intended solution (given — the forward numerics are
  taken as correct).
- **Reverse:** `dM/dθ` is the derivative of the **modelled map** `M`, i.e. the
  resolution-independent derivative `∇M`, not merely a self-consistent adjoint of
  whatever the naive tape records for `∇M_h`.

That distinction is the whole difficulty: reverse-mode AD returns `∇M_h` exactly,
and for most of the program `∇M_h → ∇M`. The open question is whether it does so
through the self-consistent field read and the growing state, and if not, what the
correct reverse-mode treatment of those is.

## 4. The question

How should this workflow be differentiated in reverse mode so that `dM/dθ` equals
`∇M` — in particular, what is the correct reverse-mode adjoint of (a) the read of a
self-consistent field whose sources are the reading points themselves, at a moving
query, through a rebuilt low-rank reconstruction; and (b) the coordinate through
which the point set grows mid-integration?
