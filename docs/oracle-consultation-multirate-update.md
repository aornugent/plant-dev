# Multirate resolution of a small fast block whose coupling term is expensive and non-separable

A numerical-methods question. No application context is needed or given. The objects are an
initial-value problem, its adaptive integrator, and (downstream) a reverse-mode AD tape.

**This updates an earlier consultation** on the same IVP,
which established — and we treat as settled — that the step-controller collapse is **accuracy-driven,
not stability-driven**, localised to a small block's near-singular excursions, so quasi-steady-state
reduction and A-stable/implicit stepping do **not** enlarge the steps. That consultation pointed
toward **multirate sub-cycling** of the small block. We built it and measured it. The new datum below
**partially refutes the naive form of that idea** and is the reason for this follow-up. Please reason
past the naive sub-cycle and past QSS/implicit as before.

## Setup

IVP `y' = f(y,t;θ)`, `y ∈ ℝ^N`, integrated on `[0,T]` by an adaptive embedded explicit RK with the
usual local-error controller; `10³–10⁵` accepted steps. `y` splits into a **large block `x ∈ ℝ^M`**
(`M ≈ 50–800`) and a **small block `u ∈ ℝ^L`, `L ≤ 5`**. One global step size for all of `y`.

The rates, written to expose the cost structure (this is the new information):

- **Large block.** `ẋ_j = φ(x_j, u, s(x))` for each `j = 1..M`. `s(x)` is a **cheap** low-dimensional
  aggregate of the whole `x`-block (an O(1)-sized summary; measured cost flat in `M`). Each `φ` is an
  **iterative solve** — a nested scalar root-find with an inner fixed-point — and it **reads `u`**.
  Evaluating all `M` of the `φ` is the **dominant cost of `f`** (measured: 95–100% of a full `f`
  evaluation, and O(`M`)).
- **Small block.** `u̇_ℓ = b_ℓ(u, t) − a_ℓ(x, u)`, `ℓ = 1..L`. `b` is **cheap closed-form**: it carries
  the near-singularity at the lower bound `u_ℓ → u_min` (the partial `∂b/∂u` varies over orders of
  magnitude, non-Lipschitz at the bound, hence a clamp) and a **kinked, piecewise-smooth
  time-inhomogeneity**. The coupling term `a(x,u) ∈ ℝ^L` is an **aggregate over the large block**,
  `a_ℓ = Σ_{j=1}^M c_ℓ(x_j, u)`, where each `c_ℓ(x_j, ·)` is a **byproduct of the very same iterative
  `φ`-solve** that produces `ẋ_j`. **Consequence: obtaining `a(x,u)` requires the expensive O(`M`)
  solve set; it is not separately cheap.** And `a` depends on the current `u`, so `a` at a new `u`
  (with `x` held) still requires re-running the `M` solves at that `u`.

Two-way coupling: `f_u` reads `a(x,u)` (expensive); `f_x` reads `u` and `s(x)`.

## Measured facts (the data to reason from)

Truth throughout = the global single-rate adaptive solver at tight tolerance; error = max deviation of
`u` on a fixed output grid; cost = count of **expensive evaluations** (one = one O(`M`) solve set that
yields `a` and/or `ẋ`), which is the machine-independent proxy.

1. **Cost localisation.** A full `f(y)` is dominated by the `M` iterative solves; `s(x)` (the cheap
   aggregate `f_x` reads) is flat in `M` and negligible. So **the thing `f_u` needs (`a`) is the
   expensive thing.** Freezing `s(x)` across a macro step saves ~nothing.
2. **`a(x, ·)` is strongly nonlinear and non-separable in `u`.** Refutations, `x` held fixed:
   - a per-macro **linearization** `a(x,u) ≈ a₀ + J(u−u₀)` (full `L×L` `J`; `J` is ~90% diagonal,
     max off-diagonal / diagonal ≈ 0.09) has **relative error 3–4×** over the `u`-excursion of a
     single macro interval once one component of `u` moves appreciably toward its bound.
   - a **separable nonlinear** tabulation `a_ℓ ≈ κ_ℓ(u_ℓ)` (each component's response curve, other
     components held; `~8L` expensive samples per macro) has **absolute error 0.06–0.76** on realistic
     multi-component excursions: moving one component of `u` changes the `a` of the *others*
     (nonlinear cross-response the separable form cannot represent).
3. **Naive sub-cycle with held coupling — the partial refutation.** Sub-cycle `u` alone over each macro
   interval with `a` held **piecewise-constant** and **refreshed exactly** (a full expensive solve)
   `R` times per unit time; `x` advanced on the coarse grid:
   - tracks truth to tight tolerance **only when `R` approaches the fast relaxation scale** (`R ≈ 50`
     per unit time, ≈ 7× the block's fast timescale). Below `R ≈ 20` it is qualitatively wrong.
   - at that `R`, expensive-evaluation count is **6–73× fewer** than the global solver (which spends
     `300–3600` expensive evals per unit time, all controller-forced by `u`); **but only the mildest
     regime reaches tight tolerance.** Stiffer regimes **plateau at a fixed error ≈ 0.1** no matter how
     large `R` — the piecewise-constant `a` between refreshes cannot follow `u`'s fast motion, and the
     sub-integrator locks onto the wrong balance.
   - the sub-integrator itself must respect the block's stiffness at the wet/large-`|∂b/∂u|` end and
     the clamp (a naive high-order adaptive stage straddles the clamp and locks a spurious state; a
     local-stability-limited step is needed). This is mechanical, not the core issue.
4. **The `M` solves are iterative and (untested) possibly warm-startable.** Between adjacent `u`-values
   in a sub-cycle `u` moves little; seeding each `φ`-solve from the previous sub-step's solution might
   collapse it to 1–2 iterations, making an **exact** `a`-refresh cheap without any surrogate. Not yet
   measured (needs instrumenting inner-iteration counts).
5. **An L-stable implicit/Rosenbrock stepper (small dense Jacobian) is available** for either block.
   Per the prior (settled) diagnosis it does not enlarge steps for the accuracy-limited `u`; it remains
   on the table for the sub-block or for `a`'s treatment.

## What we need

Advance `u` through its fast, near-singular, kinked excursions **without evaluating the expensive,
`u`-dependent, non-separable aggregate `a(x,u)` at `u`'s fast rate**, while `x` takes coarse steps —
and (downstream constraint) with a reverse-mode tape whose gradient still matches a finite difference
of the discrete solver as run. The naive multirate (hold `a`, refresh periodically) either costs as
much as the global solver (refresh at the fast rate) or plateaus at finite error (refresh coarsely).

## Facts an answer can rely on

- `L ≤ 5`. `x` is smooth on the coarse scale and can take large steps; the whole difficulty is `u`.
- `a(x,u)` is **only** obtainable via the O(`M`) iterative solve set; there is no separate cheap route
  to it, and it is nonlinearly, non-separably dependent on `u` (fact 2).
- The `φ`-solves are iterative with a natural warm-start (fact 4); changing their iteration seeding does
  not change the converged value, only the work.
- A controlled, documented change of discretisation is acceptable **if** the forward solution and the
  reverse-mode gradient stay correct (gradient = FD of the solver as run).
- Implicit/Rosenbrock on any sub-block is available (fact 5).

## Structural features — any may be load-bearing or incidental; we do not know which

The non-separable nonlinearity of `a` in `u`; the near-singular `b` at `u_min`; the kinked
time-inhomogeneity; the fact that `a` is an O(`M`) byproduct of `f_x` (no cheap route); the global
shared step size; the two-way coupling; the clamp/projection at `u_min`; the iterative (warm-startable)
inner solves.

## Questions (open; please rank features and feel free to reject the framing)

1. Given `a(x,u)` must move with `u` and has no cheap surrogate (fact 2), is the correct lever to make
   the **exact** `a`-refresh cheap (e.g. warm-started inner solves, fact 4) rather than to approximate
   `a` at all? If so, what is the reverse-mode consequence of warm-started iterative inner solves on the
   tape (is the adjoint of a fixed-point/root solve seed-independent, so warm-starting is free for the
   gradient)?
2. Is the plateau at coarse refresh (fact 3) intrinsic, or an artifact of holding `a`
   **piecewise-constant**? Is there a low-order-in-time **extrapolant of `a`** along the macro interval
   (predictor from the coarse `x`-step plus `u`'s own motion) that removes the plateau at modest refresh
   cadence — and what is its correct multirate adjoint?
3. Is the non-separability of `a(x,·)` in `u` intrinsic, or is there a coordinate/aggregate for the
   coupling in which `a` becomes low-rank or cheaply evaluable as `u` varies (`x` held), so the
   sub-cycle can carry a cheap **exact** model of it?
4. Which of the listed features is load-bearing for the **residual** cost-and-error (given the naive
   sub-cycle is measured), and which is incidental?
5. A cheap discriminating experiment for whatever mechanism you judge most likely — before we build.
