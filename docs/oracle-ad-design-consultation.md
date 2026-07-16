# Optimal reverse-mode differentiation of a class of growing-dimension characteristic solvers — a design consultation

**What this is.** A self-contained description of a class of numerical systems and a
differentiation task, for an external reasoner with no access to the code and no prior
context. We are designing a **general-purpose reverse-mode automatic-differentiation layer**
that many such models plug into through a small interface: the model author expresses the
science, and the differentiation machinery — ideally reusable across models — supplies exact
parameter gradients. The consultation is about the **mathematics and numerics of that design**.

For each hard structural component below we want the *optimal implementation of its gradient
contribution* — optimal meaning correct against the model as actually run, performant and
optimisable, and as **general and composable** as the mathematics allows rather than a bespoke
per-model hand-treatment. Above the component level we
want to know whether a **reformulation** of the transported variables or the coupling
representation would dissolve several of these difficulties at once, and at what cost.

We are **not** asking you to reproduce a fix for any particular observed error — several
components already have working treatments. We want the design-level map: which components admit
a clean reusable formulation and what it is, which are irreducibly model-specific, how they
compose, and where a change of representation beats a kit of point techniques. Treat every
structural feature as possibly load-bearing or possibly incidental; feel free to reject the
framing or the choice of state variables.

**What we need (the outcomes that matter).** The gradient must be **correct** — agreeing with a
direct finite difference of the model as actually run. The machinery must be **performant and
optimisable** — usable inside an outer loop (optimization/inference) that requests many gradients,
and not degrading badly as the parameter count `|θ|` or the problem size `N` grows. It must be
**modular and maintainable** — the reusable differentiation machinery cleanly separated from each
model's science, so a model author writes equations, not derivative plumbing. And it should be
**composable** — the treatment of one component must not break another where they chain, and
ideally must survive a further (nested) derivative for second-order needs.

**Why reverse mode.** There are many differentiation inputs (the `|θ| ≈ 5–20` parameters, plus
initial conditions) and few scalar outputs (the reductions). Reverse-mode AD records the forward
computation on a *tape* and then sweeps backward, propagating adjoints, to yield the derivative of
one output with respect to *all* inputs in a single backward pass, at a cost of a small constant
multiple of one forward evaluation — the natural choice when inputs greatly outnumber outputs. We
build the tape by **operator overloading**: the same code runs with an "active" scalar type that
records each elementary operation as it executes. Forward (tangent) mode — carrying a directional
derivative alongside the value, no tape — is also available and is used mainly as an independent
check; differentiating the reverse sweep again (tangent-over-adjoint nesting) gives second
derivatives but is only partially supported. The engine is XAD. This is the setting an answer must
live in — though you may still argue that a different *formulation of the model* would make the
differentiation dramatically easier.

**The crux in one paragraph.** We must differentiate a numerical time-integration of a transport
equation, solved by tracking a growing set of moving points ("characteristics"), whose rates
contain (i) the **spatial derivative of a field that the population itself generates
self-consistently** — the term we return to repeatedly below and the one that has been hardest;
(ii) an embedded **optimization plus constraint solve** at every point; and (iii) a nonlocal,
low-rank coupling **rebuilt at every integration stage** — while doing it correctly, performantly,
and with machinery reusable across models. Several individual components have known treatments; the
open question is the *optimal* set of them, and whether a change of representation removes whole
classes of difficulty at once.

Nothing below is application-specific; the quantities are abstract.

---

## 1. The system

### 1.1 Continuum model

A conservation law is transported over a scalar coordinate `x` on `t ∈ [0, T]`, coupled to a
nonlocal field and to a small auxiliary subsystem:

```
∂ₜ n(x,t) + ∂ₓ[ g(x, S, u; θ) · n ] = − r(x, S, u; θ) · n ,        x > x_b
S(z,t) = Ψ( ∫_{x ≥ z} κ(z, x; θ) · n(x,t) dx )        (nonlocal, one-sided aggregate)
du/dt  = H( u, Q[n]; θ )                              (auxiliary subsystem, dim p_u ≈ 1–5)
```

- `n(x,t)`: a density over `x ≥ x_b`. `θ`: a parameter vector, `|θ| ≈ 5–20`.
- `g`: a velocity (advects mass in `x`); `r`: a nonnegative loss rate. Both are smooth closed
  forms of `x`, `S`, `u`, `θ` — **except** that one ingredient is the output of an inner solve
  (§1.4) and several ingredients are piecewise/clamped (§1.5).
- `S`: a scalar field over `x`, a pointwise-monotone map `Ψ` of a one-sided cumulative aggregate
  of `n` weighted by a kernel `κ`. `κ(z,x;θ)` is smooth, one-signed, defined for `x ≥ z`, and
  **vanishes on the diagonal** `κ(z,z)=0`. Only mass at `x ≥ z` enters the aggregate at `z`.
  The characteristics interact **only** through `S` (and through `u`) — there is no direct
  particle–particle term.
- `u`: a low-dimensional auxiliary state, driven by an aggregate functional `Q[n]` of the whole
  population and read back by `g`, `r`, and the inner solve. It can be stiff.

### 1.2 Discretization (method of characteristics)

The density is represented by `N(t)` characteristics with strictly increasing coordinates
`x₁ < … < x_N` and per-characteristic scalar **log-densities** `ℓᵢ = log(density carried)`:

```
dxᵢ/dt = g(xᵢ, Sᵢ, u; θ)                       Sᵢ = S(xᵢ)
dℓᵢ/dt = − ( Cᵢ + r(xᵢ, Sᵢ, u; θ) )            Cᵢ = ∂ₓ[ g(x, S(x); θ) ] at xᵢ
```

`Cᵢ` — the **compression** — is the spatial derivative of the velocity *evaluated along the
reconstructed field*: `Cᵢ = ∂ₓ[g(x, S(x); θ)]|_{xᵢ} = g_x + g_S · S′(x)` at `xᵢ`. It is unlike
every other ingredient of the rates for four reasons at once: (i) it is a derivative *with respect
to the spatial coordinate*, not with respect to a parameter, so it is a derivative the forward
model itself must compute; (ii) it is taken through the field `S`, which the whole population
generates self-consistently, so `S′` is a derivative of a nonlocal reconstruction; (iii) it is
evaluated at the characteristic's **own moving coordinate** `xᵢ`, which is itself a state that is
both a query into `S` and a source of `S`; and (iv) `S` is known only as a reconstruction, so `Cᵢ`
has no closed form and is presently taken as a **finite-difference secant** of the reconstructed
field about `xᵢ`. It is the only term in `dℓ/dt` that is not a plain pointwise rate.

The transported per-characteristic quantity is a **pointwise log-density** `ℓᵢ`; the mass carried
by characteristic `i`, `mᵢ = exp(ℓᵢ)·Δxᵢ`, is a derived quantity, **not** a state variable. The
inter-characteristic spacings `Δxᵢ` themselves evolve, `d(Δxᵢ)/dt = g(xᵢ) − g(x_{i+1})`, and they
are the weights of every reduction (§2).

### 1.3 The coupling field `S`, rebuilt every RK stage

At each Runge–Kutta stage the field is reconstructed from the whole population:

1. weights `wⱼ = exp(ℓⱼ)·Δxⱼ`, `Δxⱼ` the spacing between neighbours
   (`(x_{j+1}−x_{j−1})/2` interior; one-sided at the ends);
2. aggregates at `k ≈ 17` **fixed** knot positions `z_m`:
   `A_m = Σ_{j: xⱼ ≥ z_m} κ(z_m, xⱼ; θ)·wⱼ`;
3. samples `s_m = Ψ(A_m)` (e.g. `exp`);
4. coefficients `c = M⁻¹ s`, `M` the **fixed** `k×k` spline collocation matrix on the fixed
   knots;
5. reads `S(x) = B(x)ᵀ c`, `B(x)` the sparse basis row at query `x`; the compression stencil
   reads through the same reconstruction.

So the population couples through a **low-rank two-stage map** rebuilt each stage: a *gather* of
`N` states into `k ≈ 17` knot values, then a *scatter* of the `k` knots into each rate. Knot
positions and `M, B` are fixed; only the knot **values** carry state-dependence. Reads occur at
query points `xᵢ` that are themselves **evolving state**.

### 1.4 Embedded inner solves (one ingredient of the rates)

At each characteristic, one scalar ingredient of `g`/`r` — the **response** `ρᵢ` — is produced
by an inner optimization over a two-variable operating point `(q, v)`:

```
ρᵢ = J(q*, v*; xᵢ, Sᵢ, u; θ) ,
   q* = argmax_q J(q, v(q); … )         (an optimum: ∂J/∂q = 0 there)
   v*  solves  c(v, q; xᵢ, Sᵢ, u; θ) = 0   (an equality constraint: ∂J/∂v ≠ 0 there)
```

- Both the argmax and the constraint solve are **iterative**, with data-dependent iteration
  counts and no closed form. We do not want to record those iterations on the tape.
- `J`, `c`, and the maps building them are **piecewise** in some arguments (§1.5).
- **Two regimes** for the optimum:
  - **(a) solved** — `q` is driven to the optimum every evaluation (stationary, `∂J/∂q=0`);
  - **(b) tracked** — `q` is carried as an *extra ODE state* relaxing toward the optimum,
    `dq/dt = a·∂J/∂q`, so `ρᵢ` is evaluated at a **non-optimal** `q` (`∂J/∂q ≠ 0`).
- **A non-stationary co-output.** At the *same* operating point a second scalar `σᵢ` is computed
  (a flux quantity) that is **not** stationary in `q` — at the optimum `∂σ/∂q ≠ 0`. `σᵢ` feeds
  the auxiliary aggregate `Q[n]` (it is part of `u`'s drive). So the operating point produces one
  output whose sensitivity to `q` vanishes at the optimum and one whose sensitivity does not.

### 1.5 Piecewise / nonsmooth ingredients

Several ingredients of `g`, `r`, `H`, `J`, and `c` are piecewise or clamped: sign branches
`if(a>0)… else 0`; clamps `max(0,x)`, `min(x, x_max)`; and, notably, a scalar built from an
**integral whose active branch (integrand form and/or limits) switches at points that depend on
the state and on `u`**. Some of these sit on a rate that is later differentiated or integrated
in time.

### 1.6 Increase of dimension, and the two-pass structure

- **Insertions.** New characteristics enter at the boundary `x_b` on a schedule; `N(t)` grows
  from `O(1)` to `N ≈ 10²–10³`. A newborn's `ℓ` is set by a boundary-influx formula reading
  `S(x_b)`.
- **Two passes.** Pass 1 integrates adaptively in plain `double` and *records* a schedule:
  accepted step sizes, RK stage pattern, insertion times, and the adaptively-chosen node
  positions of the field reconstruction. Pass 2 replays that schedule **frozen** — no adaptive
  branching, no re-adaptation — and is the pass we differentiate. On the frozen trajectory the
  ordering `x₁ < … < x_N` holds (no crossings), so every membership set `{j: xⱼ ≥ z_m}` is stable
  data.

### 1.7 Sizes and symbols

`N ≈ 10²–10³`; `k ≈ 17`; RK stages `s = 2–7`; steps `10³–10⁵`; `p_u ≈ 1–5`; `|θ| ≈ 5–20`.

| symbol | meaning |
|---|---|
| `xᵢ, ℓᵢ` | characteristic coordinate; pointwise log-density (transported state) |
| `Δxᵢ, wⱼ` | spacing; quadrature weight `exp(ℓⱼ)·Δxⱼ` |
| `mᵢ` | mass `exp(ℓᵢ)·Δxᵢ` (derived, not a state) |
| `z_m, A_m, s_m` | fixed knot positions; aggregates; samples `Ψ(A_m)` |
| `M, c, B(x)` | fixed collocation matrix; coefficients; basis row at `x` |
| `Sᵢ, Cᵢ` | field read at `xᵢ`; compression `∂ₓ[g(x,S(x))]` at `xᵢ` |
| `κ, Ψ` | kernel (`κ(z,z)=0`, one-sided); sample map |
| `u, H, Q[n]` | auxiliary state; its rate; the population aggregate driving it |
| `ρ, σ, q, v, J, c` | inner response; non-stationary co-output; decision var; constrained var; objective; constraint |
| `θ` | parameters to differentiate w.r.t. |

---

## 2. The differentiation task and engine

Compute reverse-mode gradients of scalar reductions of the terminal (or time-integrated) state
w.r.t. `θ` and initial conditions.

- **Reductions.** Moments `M = Σᵢ φ(xᵢ(T))·exp(ℓᵢ(T))·Δxᵢ(T)` for various `φ`; time-integrated
  variants `∫₀ᵀ Σᵢ (…)·exp(ℓᵢ)·Δxᵢ dt`; and scalar functions of `u(T)`. Several functionals per
  solve. The reduction weights are the **spacings** `Δxᵢ`, themselves functions of the evolving
  coordinates.
- **Correctness reference.** Converged central finite difference of the *model as run*: replay
  the same frozen schedule at `θ ± ε eₚ` in `double`, central-difference, take the step plateau.
  This is what "correct" means for us — the gradient of the trajectory actually integrated.

(The reverse-mode engine, and why it fits many-input/few-output gradients, is described in the
preamble. We record pass 2 and sweep once per functional.)

---

## 3. Facts an answer can rely on

- The engine is a single reverse-mode operator-overloading tape (XAD); forward/tangent mode is
  available; tangent-over-adjoint nesting is possible but restricted. Treatments that keep the
  reverse sweep well-defined and, where possible, still nestable are preferred.
- **A reformulation is on the table.** Enabling differentiation currently keeps the forward
  trajectory bit-identical, which we like — but we will accept a *documented* change of the
  discretization or of the transported variables if it is the minimal change that makes the
  gradients correct and the machinery cleaner. Do not treat "forward unchanged" as inviolable.
- The schedule (steps, stages, insertions, node positions) is frozen from pass 1; its own
  `θ`-sensitivity is intentionally dropped (an accepted approximation, not a target).
- Ordering preserved; membership sets stable; `κ(z,z)=0`; knots, `M`, `B` fixed.
- We do **not** hand you a fixed cost model to satisfy. Reverse mode already gives a full gradient
  per output in one sweep; what we care about is that the *whole* scheme stays performant and
  optimisable as `|θ|` and `N` grow, and that its parts are modular enough to maintain — not that
  any component hit a particular flop count.

---

## 4. The hard components (flat; any may be load-bearing or incidental)

Each is a place where naive operator-overloading differentiation is inadequate or subtle. We give
the structure and the difficulty, not our treatment. They are unranked on purpose.

**C1 — The transport/compression term.** The compression `Cᵢ = ∂ₓg` (§1.2) is the subtlest
ingredient of the rates: a spatial derivative of the self-generated field, at the point's own
moving coordinate, with no closed form. Differentiating the discrete solver through this term is
where a naive tape most visibly fails: the resulting gradient is *internally consistent*
(forward-JVP = reverse-VJP to machine precision) and *value-exact* (bit-identical trajectory), yet
disagrees with the finite-difference reference by an `O(1)`, non-vanishing factor, concentrated in
parameters that reach the reduction **only through the coupling** (`κ`/`Ψ`). What is the correct
gradient contribution of this term?

**C2 — A rate that is itself a numerical derivative.** The compression is a finite-difference
secant. Differentiating a finite-difference stencil on the tape amplifies any nearby
nonsmoothness by `1/ε` (the stencil step). What is the right way to carry the gradient of a
quantity that is *defined as* a numerical derivative?

**C3 — A field read at a moving query.** `Sᵢ = B(xᵢ)ᵀc` is read at a query `xᵢ` that is evolving
state, so the tape carries a query-motion term `dS/dx·dx/dθ` through the reconstruction. On a
single read it is small; integrated over the trajectory it compounds (observed to grow from
negligible at short `T` to order-one at long `T`). When is this term genuine sensitivity and when
is it a discretization artifact that should not be differentiated?

**C4 — Inner optimum (envelope) with a non-stationary co-output.** The response `ρ` is stationary
in `q` at the optimum (envelope theorem applies — the optimizer's own sensitivity can be dropped),
but the co-output `σ` computed at the *same* operating point is **not** stationary in `q`, and `σ`
drives the auxiliary subsystem. A treatment that exploits stationarity for `ρ` drops a real term
for `σ`. What is the correct, cheap joint treatment of a stationary output and a non-stationary
co-output sharing one iterative operating-point solve, without taping the iterations?

**C5 — Inner equality constraint.** The second operating-point variable `v` solves `c(v,·)=0` with
`∂J/∂v ≠ 0` (a genuine constraint, not an optimum). Its gradient contribution is an
implicit-function-theorem object. How should the constraint channel and the optimum channel be
composed into the operating point's total sensitivity (a coupled KKT-like system), still without
differentiating the iterations?

**C6 — Optimum carried as tracked ODE state.** In regime (b) the optimum is not solved but tracked
as a relaxing state evaluated off-stationary, so `∂J/∂q ≠ 0` and the envelope simplification no
longer holds; the operating point's dependence must flow through the tracked state's own tape
history. What changes, mathematically, between differentiating a solved-to-optimum response and a
tracked-relaxing one?

**C7 — Piecewise integral with state-dependent branch points.** One ingredient is an integral whose
branch switches at thresholds that depend on the state and on `u`. A finite difference across such
a branch point averages two branch slopes and is systematically biased (observed to undershoot by
~3×). What is the correct derivative of such a piecewise integral, and how general can its handling
be made?

**C8 — Stiff auxiliary subsystem under frozen-schedule replay.** `u` is stiff, bidirectionally
coupled (population aggregate `Q[n]` drives it via the non-stationary `σ`; `u` feeds back into the
rates and the inner solve), with positivity/bounds enforced by clamps/resets. On the differentiated
pass it is replayed on the recorded explicit-method step schedule with no error control. Does
frozen-schedule replay of a stiff coupled subsystem threaten gradient correctness (vs merely
accuracy of the value), and what is the principled treatment?

**C9 — Growing dimension on a reverse tape.** State variables come into existence mid-integration
at the boundary. Does a variable-dimension state require special handling for reverse-mode
correctness, or is it incidental given a taped operator-overloading engine?

**C10 — Nonsmooth ingredients on differentiated rates.** Beyond C2/C7, several sign branches and
clamps sit on rates that are differentiated or integrated. Which need smooth surrogates for the
*derivative* to be well-defined (vs a subgradient sufficing), and is there a principled policy?

**C11 — Value-keyed memoization.** Some intermediate quantities are memoized keyed on their
computed value. Under AD a value-equal but derivative-different recomputation can be silently
skipped. What is the general rule for caches on a differentiated path?

**C12 — Diagnostics interleaved with differentiated arithmetic.** Internal adaptive numerics
(e.g. a quadrature error estimate) produce control decisions, not differentiated outputs, yet are
computed from the same active quantities in the same routines. What is the clean separation between
a value used to *decide* and a value that is *differentiated*?

---

## 5. What we're looking for

Design guidance, not a patch. In rough priority:

1. **A per-component map of the optimal treatment.** For each of C1–C12 (and anything we have
   mis-framed or missed): the mathematically optimal way to obtain its gradient contribution —
   correct against the model as run, performant and optimisable as `|θ|` and `N` grow, and stated
   generally enough to reuse across models rather than hand-authored per model. Where two treatments
   trade off (e.g. exactness vs performance vs composability vs how cleanly they separate from the
   model's science), name the trade.

2. **Unification vs a kit.** Are these facets of one underlying structural issue that a single
   reformulation dissolves — e.g. a change in the **transported variable** (what quantity the
   characteristics carry), in the **coupling representation** (how the population's influence on
   each rate is expressed), or in **where the derivative of a derived quantity is formed** — or are
   they genuinely independent problems each needing its own technique? If the former, state the
   reformulation, what it costs (state redefinition, boundary redefinition, loss of the
   bit-identical forward), and which components it removes. If the latter, give the shortest list
   of independent techniques that covers the class, and how they compose where components chain
   (an inner solve feeding the field feeding the compression feeding a moment).

3. **The division of labour.** Which of these treatments are *model-agnostic* (belong in a general
   differentiation engine that any such model reuses) and which are *irreducibly model-specific*
   (must be authored per model, ideally behind a small, hard-to-misuse seam)? This is the design
   question the whole consultation serves: what is the smallest, cleanest interface between the
   reusable machinery and the model's science?

4. **Composability with higher order.** Which treatments preserve the ability to take a further
   (nested) derivative of the gradient, and which foreclose it?

5. **A falsifiable check.** For any reformulation or treatment you judge best, a concrete cheap
   experiment that would confirm or kill it before we build — and what pass/fail would imply.
