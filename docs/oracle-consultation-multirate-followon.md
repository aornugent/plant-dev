# Follow-on: the cost structure we did not see before — what integration strategy does it imply?

A numerical-methods question. No application context is needed or given. This **follows two prior
rounds** on the same IVP; the settled facts from those rounds are restated inline so this stands alone.
Since then we have resolved the **internal cost structure** of the right-hand side, and it changes the
picture enough that we would rather you **re-derive the optimal strategy from the structure** than
refine any scheme proposed earlier. We may be decomposing along the wrong axis; please say so if the
data point that way.

## Settled from prior rounds (treat as established; do not re-litigate)

IVP `y' = f(y,t;θ)`, `y ∈ ℝ^N`, integrated on `[0,T]` by an **adaptive embedded explicit RK** with a
local-error controller; `10³–10⁵` accepted steps; one global step size for all of `y`. `y` splits into
a **large block `x ∈ ℝ^M`** (`M ≈ 50–800`) and a **small block `u ∈ ℝ^L`, `L ≤ 5`**, two-way coupled.
Downstream we take **reverse-mode gradients** (operator-overloading tape recording every RK stage) of
scalar functionals w.r.t. a small `θ`; the gradient must match a finite difference of the solver as run.

- The step-controller collapse is **accuracy-driven, not stability-driven**, localised to `u`'s
  excursions toward a lower bound `u_min` where `u`'s cheap closed-form part is near-singular
  (`∂/∂u` spans orders of magnitude, non-Lipschitz at the bound → a clamp) and where a **kinked,
  piecewise-smooth time-inhomogeneity** drives rapid excursions. (Measured: `corr(logΔt, logd)=−0.91`.)
- Consequently **quasi-steady-state reduction of `u`** and **A-stable/implicit stepping** are both ruled
  out as ways to enlarge the steps (measured); please reason past them as step-enlargers. (An implicit
  micro-integrator for the near-singular passage itself remains a separate, open option.)
- A prior round proposed resolving `u` by **sub-cycling the small block** with held/periodically-refreshed
  coupling; we measured that **held coupling integrates the wrong fast system** (the small block's true
  fast Jacobian includes the coupling's `u`-dependence) — it converges only if the coupling is refreshed
  at `u`'s own fast rate, and otherwise plateaus at a fixed error. So the coupling's `u`-dependence must
  live **inside** the fast dynamics; a frozen or low-order-in-`u` surrogate for it is refuted.

## The cost structure we have since resolved (the new information)

Write `f` to expose where the work is. `s(x)` is a **cheap** low-dimensional aggregate of the whole
large block (measured cost flat in `M`, negligible). Each member `j = 1..M` carries a **scalar control
`p_j`** fixed by an **inner maximization**:

```
p_j* = argmax_p  P(p ; x_j, u, s),      solved by a FIXED-ITERATION derivative-free bracketing search
ẋ_j  = g(x_j, u, s, p_j*)
a_ℓ(x,u) = Σ_{j=1}^M c_ℓ(x_j, u, p_j*),   ℓ = 1..L          (the coupling; a byproduct of the M solves)
u̇_ℓ = b_ℓ(u, t) − a_ℓ(x,u)
```

- The inner search is **deliberately fixed-iteration** (not Brent/Newton): its argmax must be a
  **smooth function of the inputs** because the downstream gradient differentiates through `p_j*`. A
  variable-iteration solver would make `p_j*` a non-smooth function of `(x_j,u,s)` and corrupt the
  gradient. `∂P/∂p` is available **exactly** (implicit-function theorem through the inner root that
  `P` itself contains).
- **Measured per-member cost decomposition** (arbitrary consistent units): a `u`-dependent per-member
  **setup** ≈ 11; **one objective evaluation** at a given `p` (setup already done) ≈ 4.6; the full
  **argmax** (setup + the bracketing search) ≈ 21. So evaluating the coupling `a` at a *given* set of
  controls costs ≈ setup + one objective ≈ (11+4.6); *optimising* the controls adds ≈ 16 more per member.
- The **coupling is a byproduct** of the member solves: there is no separate cheap route to `a(x,u)`,
  and `a` depends on the current `u`.

### Two measured probes (the payload — includes refutations of our own prior direction)

Truth = the global single-rate solver at tight tolerance. "Expensive unit" = one member solve.

**Probe A — is the inner solve warm-startable (does dense re-evaluation along a `u`-path get cheap)?**
Attempted a **Newton on the exact `∂P/∂p`** seeded from a neighbouring member's / previous step's `p*`.
It is **fragile**: over a realistic `u`-excursion (small steps in `u`) the Newton **diverges toward the
bound and leaves `P`'s domain of definition** (`|p*_cold − p_warm|` order the control's own range). The
fixed-iteration bracketing search is, by construction, **not** warm-startable (fixed cost regardless of
seed). Net: re-evaluating the coupling cheaply via warm-started *optimization* buys only ≈ argmax/eval
≈ **4.5×** per member, and the ≈11 `u`-dependent setup is paid on every `u`-change regardless.
(An alternative exists: promote each control `p_j` to a **slow integrated state**, relaxed toward its
argmax by the exact `∂P/∂p` — `ṗ_j = k·∂P/∂p` — and **evaluate** rather than optimise each step (≈4.6
vs 21). This trades a controlled tracking lag, set by `k`, for the argmax cost. Reverse-mode over a
tracked control is a differential state, not an argmax.)

**Probe B — how many members does the coupling need?** `a_ℓ(u) = Σ_j c_ℓ(x_j,u,p_j*)` is a
density-weighted sum over the (ordered, scalar) **member coordinate** `x`. Reconstructing it from
`m ≪ M` members and interpolating the smooth integrand `c(·,u)` converges **≈ O(m⁻²)** (trapezoidal):
`m ≈ 15–20` members reconstruct the full-`M` aggregate to **< 0.5 %** across the `u`-range (wet/mid),
and to ~0.5 % at the near-singular end of `u` (converging, a little slower — the integrand develops
interior kinks there as members cross regime boundaries). So `c(·,u)` is **smooth in the member
coordinate**, and the O(`M`) work in the coupling compresses to O(`m`), `m ≪ M`. The member solves for
the `ẋ_j` themselves are separate and not addressed by this.

## Structural features — any may be load-bearing or incidental; we do not know which

The near-singular closed-form part of `u` at `u_min`; the kinked time-inhomogeneity; the clamp at
`u_min`; the global shared step size; the two-way coupling; the coupling as an O(`M`) byproduct with no
cheap route; the inner **maximization per member** (fixed-iteration for gradient-smoothness); the exact
`∂P/∂p`; the **smoothness of `c` and of `p*` in the member coordinate**; the option to carry each `p_j`
as a slow tracked state; the smallness `L ≤ 5`; the large-block rates `ẋ_j` needing all `M` solves
irrespective of the coupling; the downstream reverse-mode tape whose cost tracks accepted steps.

## Facts an answer can rely on

- `a(x,u)` is only obtainable via the member solves; it is nonlinearly, non-separably `u`-dependent
  (a frozen/low-order-in-`u` surrogate is refuted above); but it is a **smooth quadrature** over the
  member coordinate (Probe B).
- `∂P/∂p` is exact and cheap; the inner argmax must present a smooth `p*` to the tape.
- The `ẋ_j` (large-block rates) require all `M` member solves regardless of how `u` is advanced — that
  cost is common to every scheme and is not the target.
- A documented, controlled change of discretisation is acceptable if the forward solution and the
  reverse-mode gradient stay correct.
- An implicit/Rosenbrock micro-integrator (small dense Jacobian) is available for any sub-block.

## Questions (open; please rank the features and reject the framing if the data warrant)

1. Given that advancing `u` requires the coupling `a(x,u)`, which is an **O(`M`) byproduct of the
   per-member argmax solves** and genuinely `u`-dependent, **is a fast/slow (small-block-multirate)
   decomposition still the right axis at all** — or does this cost structure (a smooth reduction over
   members + a per-member inner optimization + a tiny near-singular block) call for a **different
   factorization** of the work? Name the decomposition you would actually choose.
2. What **single integration strategy minimizes total forward + reverse cost** subject to the exact-
   gradient constraint? Choose freely: keep the global explicit stepper; treat a sub-block implicitly
   (IMEX / Rosenbrock); sub-cycle the small block; reduce the member count in the coupling; promote the
   per-member controls to tracked states; combine these; or something we have not listed.
3. Which measured fact is **load-bearing** for the achievable cost, and which is incidental?
4. **What are we missing?** Is there a structural simplification, a hidden cost, or an assumption in
   our framing that the data quietly contradict?
5. A **cheap discriminating experiment** for whatever strategy you judge best — before we build it.
