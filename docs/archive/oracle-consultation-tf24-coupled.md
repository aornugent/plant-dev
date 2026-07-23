# Reverse-mode gradients of a coupled multiscale optimization–transport system, at equilibrium — a design consultation

**What this is.** A self-contained description of a numerical system and a differentiation task, for
an external reasoner with no access to the code and no prior context. This is deliberately the
*whole* problem, not a narrowed sub-part: a transport of a population coupled to a shared field, in
which **each member's rates are the solution of a within-step constrained optimization** built from
special functions and piecewise maps, whose outputs couple **bidirectionally** to a **slow auxiliary
field**, and in one variant whose optimum is carried as a **slow relaxing state** — and where the
quantity ultimately wanted is a gradient **at a fixed point** the whole trajectory is iterated to.

We want the right way to structure the reverse-mode gradient of this object. **Please do not assume
any particular approach** — in particular do not assume the optimizer's sensitivity is injected by
the envelope theorem, that the optimum is tracked as a state, that the auxiliary field is replaced by
a quasi-steady equilibrium (measured invalid — §4), or that the gradient is of the *trajectory* at
all rather than of the *fixed point*. Treat every structural feature as possibly load-bearing or
incidental; we do not know which. We suspect we may be differentiating the wrong object, or through
the wrong variables — challenge the framing.

We use the XAD operator-overloading AD library (a single reverse-mode tape; forward/tangent mode and
limited nesting available). Nothing below is application-specific; the quantities are abstract.

---

## 1. The transport and its coupling field (the substrate)

A conservation law is transported over a scalar coordinate `x` on `t ∈ [0,T]` by the method of
characteristics: `N(t)` members with strictly increasing coordinates `xᵢ` and masses `mᵢ`
(`dmᵢ/dt = −rᵢ·mᵢ`; `N` grows by insertions at a boundary on a schedule). Members couple **only**
through a shared scalar field `S(z) = Ψ(A(z))`, `A(z) = Σ_{j: xⱼ≥z} κ(z,xⱼ;θ)·mⱼ`, a one-sided
low-rank aggregate (`κ` smooth, `κ(z,z)=0`, separable). The rates read `S` at member coordinates.
This substrate is well understood; it is here only because everything below couples through it.
Parameters `θ`, `|θ| ≈ 5–20`; `N ≈ 10²–10³`; steps `10³–10⁵`.

## 2. The within-step constrained optimization (the crux)

At **every member, every step**, one ingredient of the rates — call it the response `ρᵢ` and a
companion flux `σᵢ` — is the solution of a small optimization:

```
maximize over q :  W(q, v(q), w(q); xᵢ, Sᵢ, u; θ) = gain(v) − cost(q)
   subject to      b(v; q, xᵢ, Sᵢ; θ) = 0        (inner balance 1: a supply=demand root)
                   e(w; q, u; θ)       = 0        (inner balance 2: a transport root vs the field u)
   outputs         ρ = W(q*, v*, w*),   σ = flux(q*, v*, w*; u)
```

- `q` is a scalar decision variable (an operating point). The maximization is **iterative** (no
  closed form); `v` and `w` are each fixed by an **iterative** monotone root-find nested inside.
- `gain`, `cost`, `b`, `e` are built from **special functions** (a lower-incomplete-gamma antiderivative
  of a stretched-exponential `exp(−(·/b)^c)`) and **piecewise** maps (a per-segment integral whose
  active branch switches at a state-dependent threshold). Some enter through parameters we differentiate.
- The **inner balances are algebraic** (rational; the constraint clears to a low-degree polynomial),
  but the optimization+balances are solved iteratively for robustness, and we do not wish to record
  the iterations on the tape.
- **`ρ` is stationary in `q` at the optimum** (`∂W/∂q=0`); the **companion flux `σ` is not**
  (`∂σ/∂q ≠ 0` there). `σ` is the sink that drives the auxiliary field `u` (§3). So the same solve
  produces one output whose `q`-sensitivity vanishes at the optimum and one whose does not.
- The whole solve is currently done in plain `double` (its internal arithmetic is not carried on the
  AD scalar); its parameter sensitivity has to reach the gradient some other way.

## 3. The slow auxiliary field, coupled bidirectionally

A low-dimensional field `u ∈ ℝ^L` (`L ≈ 1–5`) evolves by `du_ℓ/dt = (s_ℓ − w_ℓ(u_ℓ) − Σᵢ σ_{ℓ,i})/τ_ℓ`
— a source, a state-dependent loss `w_ℓ(u) = W·(u/u_sat)^p` with **large exponent `p ≈ 16`**, and the
population-aggregated sink `σ` from §2. `u ≥ 0` (a reset). `u` feeds back into the §2 optimization
(it enters `e` and the constraint). So the per-member optimum and the shared slow field are
**mutually defined**, closed through `σ` (member → field) and `u` (field → member).

## 4. Two variants of the operating point, and a measured fact about the slow states

- **(a) solved:** `q` (and `v`, `w`) are re-solved to the optimum every step (stationary).
- **(b) tracked:** `q` is carried as an **extra slow ODE state** relaxing toward the optimum by
  gradient ascent, `dq/dt = k·∂W/∂q`, so `ρ`, `σ` are evaluated **off** the optimum (`∂W/∂q ≠ 0`).
  This adds a **third slow timescale** (operating-point relaxation) coupled to `u` and the transport.

**Measured (this is the important datum, and it refutes a natural assumption):** the slow field `u`
is *not* fast-equilibrating where it matters. Its relaxation time `∝ u^{1−p}` is short when `u` is
high but **diverges as `u` depletes**. On realistic runs `u` sits near its instantaneous equilibrium
~90% of the time, but the ~10% of steps that are genuine fast transients (depletion episodes) are
exactly where the explicit integrator is forced to its smallest steps — the step collapse is
**accuracy-driven** (following a real rapid transient near the singular boundary `u→0`), **not**
stability-driven, and is **anti-correlated** with equilibrium (`corr(log dt, log‖u−u*‖/u) = −0.91`;
every small-step is a far-from-equilibrium transient). So a quasi-steady-state closure of `u` is
invalid precisely in the episodes that dominate the cost, and an implicit stepper would *not* buy
larger steps there (the transient is real, must be resolved).

## 5. What the gradients are for — two regimes, both required

The reductions are differentiated in **two regimes, and we require both** — neither subsumes the
other:

- **Transient (non-steady-state):** several distribution moments of the population, evaluated along a
  **finite-horizon trajectory that has *not* settled**. The object is the gradient of the
  time-marched run. This is a **first-class requirement in its own right**, not merely a means to the
  steady state.
- **Fixed point:** the same system is also iterated to a **steady state** (a steady member
  distribution + steady `u`), where a scalar functional — the **growth rate of a small perturbation
  mode** about that state (a dominant-eigenvalue-type quantity) — is differentiated. The object is a
  gradient **through the fixed point**.

Many gradients of both kinds are requested in an outer loop.

## 6. The differentiation task and engine

Reverse-mode gradients (w.r.t. `θ` and initial conditions) of the §5 reductions. Engine: a single
reverse-mode operator-overloading tape (XAD); forward/tangent available; tangent-over-adjoint nesting
possible but limited. Correctness reference: converged finite difference of the model as run (for the
trajectory), or of the equilibrium (for the fixed-point reductions). Cost target: usable in the outer
loop (many gradients); flat in `|θ|` (reverse mode's premise).

## 7. Facts an answer can rely on
- Members keep their order (no crossings); the field aggregate is separable/low-rank; `κ(z,z)=0`.
- The inner balances are algebraic and monotone; the objective is smooth and concave in `q` over the
  feasible range.
- **A reformulation is on the table** — of the transported variable, the coupling representation, the
  operating-point treatment, or **what object is differentiated (trajectory vs equilibrium)** — if it
  is the minimal change that makes the gradient correct and the machinery clean. Do not treat "forward
  unchanged" or "differentiate the trajectory" as inviolable.
- The slow states (`u`, and the tracked `q`) are genuinely dynamic in their transients (§4), not
  fast-equilibrating.

## 8. Questions — open, and inviting reframing

1. **What is the right object to differentiate — in each of the two regimes (§5)?** The transient
   reductions require the gradient of a non-settled time-marched trajectory (a reverse sweep) — is
   that the right approach, or is there structure that simplifies it? *Separately*, for the
   fixed-point functional, is the correct target the adjoint of the *equilibrium residual* of the
   whole coupled system (members + inner optima + field), rather than differentiating a long
   time-march to steady state — and if so, does that subsume the per-step inner-solve differentiation
   there? Can one engine serve both regimes without a bespoke path for each? (The transient regime is
   required regardless, so an equilibrium-only reformulation does not suffice.)
2. **The within-step constrained optimization (§2).** What is the correct, cheap way to obtain the
   gradient contribution of `ρ` (stationary) *and* `σ` (non-stationary) from one iterative
   optimize-plus-two-roots solve, without differentiating the iterations — in both the solved and the
   tracked-as-state variants? How do the two variants differ, mathematically?
3. **The mutually-defined optimum and slow field (§3).** The optimum depends on `u` and `u` depends on
   the optimum's flux. Is this best seen as one coupled implicit system per step, or does the
   multiscale (fast optimum / slow field / slow tracked-`q` / slow transport) structure call for a
   different decomposition? Given §4 (the slow field is genuinely dynamic, not QSS-eliminable), what
   is the correct treatment of the slow states in the gradient?
4. **Special functions and piecewise maps (§2).** The objective/constraints contain a special function
   (incomplete-gamma-type) whose *shape parameter* is differentiated, and a piecewise integral with a
   state-dependent breakpoint. What is the principled treatment of each in the gradient?
5. **Ranking.** Of the features above — the nested within-step optimization, the bidirectional slow
   coupling, the tracked-optimum variant, the outer equilibrium, the special functions — which are
   load-bearing for the difficulty and which are incidental? Where would you expect the analytic
   gradient and a finite-difference reference to disagree, and why?
6. **A falsifiable check.** For whatever structure or reformulation you judge best, name a cheap
   experiment that would confirm or kill it before we build — we test first.
