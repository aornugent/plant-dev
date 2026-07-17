# Before we commit: hidden leverage (breadth) and optimal execution (depth)

A numerical-methods question, following three prior rounds on the same IVP (settled facts recapped so
this stands alone). We have converged on a design and **measured** every load-bearing claim. Before we
build it, two asks, in order:

1. **Breadth — is there structure or leverage we are not seeing?** A materially different decomposition,
   a change of variables, a low-rank/tensor structure, a way to make the difficulty disappear rather
   than manage it. We would rather discover a better object now than execute the current one well. If
   the data point at a reframe, say so.
2. **Depth — if the design is right, what is the *best-in-class* way to build it?** Which specific
   methods and references; the insights that separate an elegant, performant implementation from a
   naive one; the footguns and hidden complexities.

---

## The system (settled from prior rounds)

IVP `y' = f(y,t;θ)`, adaptive embedded explicit RK, `10³–10⁵` steps, one global step size; downstream
**reverse-mode gradients** (tape of the scheme-as-run must match a finite difference of the solver as
run). `y` splits into a large **member block** `x ∈ ℝ^M` (`M ≈ 50–800`, smooth) and a **small fast
block `u ∈ ℝ^L`, `L ≤ 5`**, two-way coupled. Settled: the step collapse is **accuracy-driven, not
stability-driven**, localised to `u`'s near-singular excursions toward a bound `u_min` (the cheap
closed-form part of `u̇` has `∂/∂u` spanning orders of magnitude there; kinked, piecewise-smooth time
inhomogeneity). Global implicit / QSS-reduction do **not** enlarge the steps.

The coupling has a specific structure, resolved and measured:
- Each member `j` carries a scalar **control** `p_j`, fixed by an inner **maximization**
  `p_j* = argmax_p P(p; x_j, u, s)` (`s(x)` = a cheap low-dim aggregate of the member block), solved by
  a **fixed-iteration derivative-free bracketing search** (fixed-iteration on purpose: the downstream
  gradient differentiates through `p_j*`, which must stay a smooth function of its inputs). `∂P/∂p` is
  available **exactly** (IFT through an inner root inside `P`).
- The coupling the fast block reads is an aggregate **byproduct** of these solves:
  `a_ℓ(x,u) = Σ_{j=1}^M c_ℓ(x_j, u, p_j*)`, `ℓ = 1..L`. `u̇ = b(u,t) − a(x,u)`.
- Cost of a full `f`: dominated (95–100%, O(`M`)) by the `M` inner solves; `s(x)` is negligible.

## The converged design (what we will build unless you redirect us)

Under a **multirate-infinitesimal (MRI-GARK) skeleton** — outer ERK on the member/slow block, each
stage-transition a short inner IVP on the fast block; **component partition**; macro grid aligned to
the forcing kinks — the **fast subsystem is `(u ∈ ℝ^L , {p̂_n}_{n=1..m})` with `m ≪ M`**:

```
micro RHS:  u̇   = b(u,t) − Σ_{n=1}^m W_n · c(x̂_n, u, p̂_n)          (coupling collocated over m members)
            p̂̇_n = k · ∂P/∂p(p̂_n; x̂_n, u, ŝ)                        (controls promoted to states; no argmax in the loop)
micro-stepper: Rosenbrock-W on the (L+m) system; per-member feasibility clamp as an active event
slow block:  x, s  held / on their slow interpolant across the macro step
reverse mode: two-level record→replay; argmax kept off the tape (init only); W_n active, node
              placement passive, W-Jacobian recorded passive
```

Two compressions make the *exact* coupling cheap: **(1) tracked controls** — promote each `p_j` from an
argmax to a differential state relaxed by the exact gradient (`k` = tracking bandwidth); **(2)
collocation** — evaluate the coupling at `m ≪ M` member nodes and reconstruct the aggregate.

## What we measured (the design is forced by these; all confirmed)

- **Timescale separation ~300×** between `u` and the slow block; `u` is genuinely the tiny fast block.
- **`u̇`'s cheap part factors exactly** given `a`; the whole difficulty is `a`.
- **`a` cannot be frozen or cheaply surrogated in `u`:** it is non-separable nonlinear in `u`
  (per-macro linearization: rel err 3–4×; separable nonlinear tabulation: abs err 0.06–0.76). Holding
  `a` piecewise-constant integrates the wrong fast system → **plateaus at fixed error** independent of
  refresh rate. `a` must be evaluated **exactly and continuously** in the sub-cycle.
- **Tracked controls work:** relaxed to steady state they reproduce the argmax value to machine
  precision; tracking a fast `u`-excursion, the fast-block trajectory matches the re-optimized (QSS)
  reference to **<1e-3 at `k=5`**, ~2e-4 at `k≈20` (knee), **no plateau**. Warm-starting the argmax
  instead is fragile (Newton diverges toward `u_min`). Feasibility clamping of `p̂` is required at the
  extremes (an active event).
- **The inner solve's setup is cacheable per leg** (its heavy part is `u`-independent and already
  memoized); only a small `u`-dependent evaluate + gradient (bounded by `L`) is paid per micro-step.
- **Collocation converges ≈O(m⁻²):** `m ≈ 15–20` nodes reconstruct the `M`-member aggregate to <0.5%
  (slower but clean at the near-singular end, where members cross interior regime boundaries).
- **Reverse mode is exact and robust:** adjoint = frozen-record FD to ~1e-8 across `k ∈ {1..1000}` and
  `m ∈ {4..64}`; the value-reductions (finite `k` lag, finite `m` quadrature) do **not** amplify in the
  gradient (adjoint exact for the scheme as run at every setting).

## Structural features — any may hide leverage or be incidental; we do not know which

The near-singular `b` at `u_min`; the kinked time inhomogeneity; the per-member inner **maximization**
with exact `∂P/∂p`; the fact that `p*` and `c` are **smooth in the member coordinate** (what makes
collocation work); the near-invariance of `p*` across members at fixed `(u,s)`; the coupling as an
O(`M`) byproduct; the two-way coupling with the fast block reading only an aggregate; the tracking-lag
knob `k`; the feasibility bound on `p̂`; the two-level record→replay; the fact that the *same* seam
(`u`-dependence of the coupling, exact `∂P/∂p`, member collocation) serves both forward and adjoint.

## Facts an answer can rely on

- `L ≤ 5`. The member block `x` is smooth and slow; the difficulty is `u` and its coupling `a`.
- `a` is only obtainable via the inner solves (no separate cheap route); non-separable in `u`; but a
  smooth quadrature over the member coordinate.
- `∂P/∂p` is exact and cheap; `∂²P/∂p²` and higher are closed-form (same IFT). The argmax must present a
  smooth `p*` to the tape.
- A documented, controlled change of discretisation is acceptable if forward solution and reverse-mode
  gradient stay correct.
- Implicit/Rosenbrock on any sub-block, and an exact per-solve IFT tangent `∂p*/∂u`, are available.

## Questions

**Breadth (answer first; reject our framing if warranted):**
1. Is `(fast/slow multirate) × (tracked controls) × (member collocation)` the right factorization, or is
   there a **deeper structure** — a change of variables that desingularizes `u→u_min`, a low-rank /
   separable / tensor structure in `a(x,u)` across `(member, layer, u)`, a slow-manifold or DAE view of
   the `(u, p̂)` system, or an exploitation of `p*`'s near-member-invariance — that makes the difficulty
   **disappear** rather than be managed? Name the object you would reach for.
2. Is anything about the two-level record→replay / the exact `∂P/∂p` / the collocation leaving
   **leverage unused** (e.g. a cheaper adjoint, an `m` far below 15–20, or exactness without the `k`-lag
   via an index-1 constraint with a cheap Schur complement instead of relaxation)?
3. Which listed feature is most likely to be **load-bearing leverage we are underusing**, and which is
   incidental?

**Depth (if the design stands):**
4. Best-in-class **method choices and references**: which multirate family/coupling table for a fast
   block that is accuracy- (not stability-) limited yet locally stiff at one bound; which **Rosenbrock-W
   / linearly-implicit** scheme for the `(L+m)` system and how to assemble/reuse its Jacobian cheaply
   under the W-property; the correct **event/root** treatment at the feasibility bound (desingularized
   coordinate vs clamp event) and its reverse-mode Leibniz term.
5. The **insights that separate elegant+performant from naive+brute-force** here — node placement and
   weight construction for the collocation (incl. splitting at the interior regime boundaries), `k`
   selection (fixed vs adaptive bandwidth) and its interaction with the micro-stepper's stiffness,
   setup-cache granularity, checkpoint granularity for the two-level adjoint.
6. **Footguns and hidden complexities** we have not surfaced — anything about the tracked-control lag,
   the collocation error, the argmax-off-tape contract, or the event handling that bites later.
7. A **cheap discriminating experiment** for the single highest-value item in (1)–(6), before we build.
