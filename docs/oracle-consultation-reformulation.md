# Is this initial-value problem posed in the right variables? Characterizing a small block's near-bound difficulty

A numerical-methods question. No application context is needed or given. The objects are an initial-value
problem, its adaptive integrator, and a downstream reverse-mode gradient. This follows earlier rounds on
the same IVP that settled how to *integrate* it efficiently; this round asks a **different** question —
whether the IVP is posed in the right variables — and we would rather you **re-derive that from the
structure** than refine any integration scheme. We may be carrying the wrong state; say so if the data
point that way. It stands alone; assume none of the prior thread.

## The system

IVP `y' = f(y,t;θ)`, `y ∈ ℝ^N`, on `[0,T]`, integrated by an adaptive embedded explicit RK with the usual
local-error controller (`10³–10⁵` accepted steps, one global step size). Downstream we take **reverse-mode
gradients** (an operator-overloading tape recording every stage) of scalar functionals of the trajectory
w.r.t. a small parameter vector `θ`; the gradient must match a finite difference of the discrete solver as
run.

`y` splits into a **large block** `x ∈ ℝ^M` (`M ≈ 50–800`), smooth and slow, and a **small block**
`u ∈ ℝ^L` (`L ≤ 5`) that carries all the difficulty. The two are two-way coupled. Each component of the
small block obeys a balance

```
u_i' = ( r_i − g(u_i) − a_i(x,u) ) / d_i ,     i = 1..L ,   d_i > 0 .
```

The ingredients, written to expose the structure:

- **Diagonal self-loss `g`.** `g(u_i) = κ·u_i^{p}`, a per-component, strictly diagonal loss with a **large
  exponent `p ≈ 16`**. Its slope `g'(u) = p·κ·u^{p−1}` ranges over many orders of magnitude across the
  reachable interval `[u_min, u_max]`: very large near `u_max`, negligible near `u_min`. Taken alone,
  `u_i' = −g(u_i)/d_i` has a **closed-form flow** (`u_i^{1−p}` affine in `t`) and is monotone toward
  `u_min`.
- **Cascade input `r`.** For `i>1`, `r_i = g(u_{i−1})` — each component's loss is the next component's
  input (a one-directional chain). For `i=1`, `r_1 = e(t)·max(0, 1 − α(u_1/u_max)^{β})`: an external,
  time-dependent input attenuated by the state of the first component, **piecewise-smooth in `t`** (kinked
  at the input's own breakpoints).
- **Coupling `a`.** `a_i(x,u) = Σ_{j=1}^{M} c_i(x_j, u)`: an aggregate, over the `M` members of the large
  block, of a per-member byproduct. Two facts: (i) it is **expensive** — each `c_i` is a byproduct of a
  per-member inner maximization (fixed-iteration, exact inner derivative available), so obtaining `a` is
  `O(M)` and dominates the cost of `f`; (ii) it depends on the small block's state through a second
  per-component map `φ(u_i) = B·u_i^{−q}`, **`q ≈ 6.6`, that DIVERGES as `u_i → u_min`**. Through `φ`, the
  coupling's own slope `∂a/∂u` grows without bound as any component approaches `u_min`.
- **Lower bound.** A hard **clamp** holds each `u_i` at or above `u_min` (`u_i` is not driven below it);
  `φ` is evaluated at a floor so it stays finite. The clamp is a non-smooth switch, and where it engages it
  also **moves through the member aggregate** as members cross the corresponding threshold in their own
  coordinate.

`θ` (differentiated w.r.t.) enters `g`, `φ`, `e`, and the per-member inner problem.

## What we measure (the data, including refutations of our own prior direction)

Truth = the same IVP at tight tolerance. We decomposed the **spectral radius of the small block's
Jacobian** along real trajectories, separating the closed-form self-terms (`g`, cascade, forcing) from
the coupling `a`.

1. **Two distinct stiff regimes, from two different terms.**
   - Near `u_max` the stiffness is `g'(u)` (the diagonal self-loss): up to `~10³–10⁴` in units of
     `1/time`. **Episodic** — only when a component is near the upper end.
   - Near `u_min` the stiffness is `∂a/∂u` (the coupling, through the diverging `φ`): it **dominates the
     self-loss stiffness by 8× to ~300×** as a component approaches the bound, and it is the **persistent
     floor** — present whenever any component is near `u_min`, which in typical trajectories is most of the
     time.
2. **Exact removal of the diagonal self-loss does NOT resolve the difficulty (refutation of our own
   earlier direction).** Because `g` is diagonal with a closed-form flow, one can integrate it exactly and
   split it off (confirmed exact to `~1e-13`). But subtracting it from the Jacobian leaves **≥99% of the
   spectral radius** in the prevailing near-`u_min` regime, and an explicit step on the remainder is
   unstable well before the self-loss limit is relaxed. The diagonal self-loss is **not** the operative
   difficulty except in the episodic near-`u_max` regime.
3. **The near-bound non-smoothness corrupts the gradient.** With the hard clamp/threshold, a moving
   regime boundary in the member aggregate makes the reverse-mode gradient disagree with a finite
   difference of the same scheme by **5–6 orders of magnitude**. Smoothing the switch at a declared scale
   restores agreement to `~1e-9`. The bound is thus not only a stiffness site but a **differentiability
   site**.
4. **Writing the coupling as the gradient of a single scalar field does NOT hold (refutation).** We tested
   whether the fed-back byproduct `a` equals the `u`-gradient of the per-member inner *value* (which would
   let the whole coupling be written as `∇_u` of one scalar field, removing the per-member control). It
   does not: the byproduct is a **primal output** of the inner problem, not its value's `u`-gradient, and
   the per-member sensitivity it would need to share is measured to vary **2–4× across members**
   (systematically, ordered by a member attribute). The coupling cannot be collapsed to one scalar field's
   gradient.
5. **Available handling (manages, does not remove).** An implicit/Rosenbrock sub-stepper (small dense
   Jacobian) is available for the small block; the per-member control can be carried as a slow **relaxing
   state** instead of re-maximized (smoother near `u_min`); the `O(M)` coupling can be reconstructed from
   `m ≪ M` members (its aggregate is a smooth quadrature over the member coordinate). These make the
   current scheme work; **none removes the near-`u_min` stiffness or singularity** — they manage it.

## Structural features — any may be load-bearing or incidental; we do not know which

The large exponent `p` in the diagonal self-loss; the diverging exponent `−q` in the coupling map `φ` at
`u_min`; the closed-form flow of the diagonal self-loss; the one-directional cascade between components;
the state-attenuated, kinked forcing into the first component; the balance form `u'=(in−out−coupling)/d`;
the two-way coupling; the coupling as an expensive `O(M)` member-aggregate byproduct; the near-singular
dependence of the coupling on `u`; the hard clamp at `u_min`; that `θ` enters `g`, `φ`, the forcing, and
the inner problem; the downstream reverse-mode tape whose cost tracks accepted steps and whose gradient
must match FD of the scheme as run.

## Facts an answer can rely on

- `L ≤ 5`; the large block is smooth and slow; the difficulty is the small block and its coupling.
- A documented, controlled change **of discretisation or of the state variables** is acceptable, provided
  the trajectory it produces and the reverse-mode gradient of the scheme-as-run stay correct
  (gradient = FD of the solver as run).
- `g` and `φ` are closed forms with closed-form derivatives to any order; the inner per-member problem
  presents an exact first derivative and its value is stationary at its optimum.
- The coupling `a` is only obtainable via the `O(M)` member solves; it is a smooth aggregate over the
  member coordinate; it is non-separably and near-singularly dependent on `u` near `u_min`.
- Implicit sub-stepping, exact flow of the diagonal self-loss, relaxing-state controls, and member
  reduction are available and interoperate with the tape.
- **Soft preference, not a hard constraint:** the model is a sum of additive terms, each corresponding to
  one independent, separately-meaningful process; a reformulation that **keeps that term-by-term
  correspondence** (each new term still maps to one original process) is more valuable to us than an
  opaque numerically-equivalent rewrite. But do not let this preference hide a better object — **if the
  right move dissolves that structure, say so.**

## Questions (open; please rank the features and reject the framing if the data warrant)

1. Near `u_min` the coupling's slope diverges through `φ(u)=u^{−q}`. Is this difficulty **intrinsic** to
   the dynamics near the bound, or an **artifact of the state variable `u`** — i.e., is there a change of
   the small-block coordinate (or of what the small block's state *is*) in which the approach to the bound
   is regular and the coupling's slope bounded, **without moving the difficulty elsewhere**? If intrinsic,
   state the precise obstruction; if representational, the minimal change and its cost — to the
   reverse-mode tape and to the term-by-term interpretability.
2. The bound is at once a **stiffness** site, a **singularity** site, and a **non-differentiability**
   (clamp) site. Are these one phenomenon or three? Is there a single reformulation of the near-bound
   behavior — a coordinate, a regularization, a boundary treatment — that addresses all three at once, and
   what is its correct reverse-mode adjoint?
3. Which listed feature is load-bearing for the near-`u_min` difficulty, and which is incidental? In
   particular, is the **balance form**, the **near-singular map `φ`**, or the **clamp** the true source?
4. **What are we missing?** Is there a structural simplification, a hidden invariant, or an assumption in
   our framing that the data quietly contradict?
5. A **cheap discriminating experiment** for whatever you judge most promising, before we build it.
