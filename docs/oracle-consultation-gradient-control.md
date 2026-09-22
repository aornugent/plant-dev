# Control algorithms with guarantees for a gradient on a shared grid

A self-contained problem. No application domain is assumed. The target is not a
value but a **derivative**, computed by reverse-mode AD; the forcing is a known,
inhomogeneous record; and the discretisation must be **shared** across parameter
values. We want algorithms whose behaviour is provable rather than tuned.

Sections 1–3 characterise the system, the integrator and the grids in full;
§4 gives the constraints any algorithm must respect and §5 what has been
measured; §6 lists what is already settled. The questions in §7 are narrow.

## 1. The system

State `y(t) = (u, v, x)` on `[0, T]`, evolving by `y' = f(y, t; θ)`,
`θ ∈ ℝ^k`, `k ≈ 17`.

### 1.1 The small block and its accumulators

`u ∈ ℝ^L`, `L ≤ 5`, a one-way chain:

```
u̇_ℓ = s(t)·[ℓ=1] − κ_ℓ u_ℓ^q + κ_{ℓ−1} u_{ℓ−1}^q − a_ℓ(x, u),   q ≈ 16
```

- The loss is diagonal and the transfer strictly one-way, so `u_1` receives the
  forcing and `u_L` terminates the chain. The Jacobian of the chain is
  bidiagonal and analytic: diagonal `−qκ_ℓ u_ℓ^{q−1}`, subdiagonal
  `+qκ_{ℓ−1} u_{ℓ−1}^{q−1}`.
- A lower bound `u_ℓ > u_min`; approaching it, a quantity read off `u` diverges
  like `u^{−p}`, `p ≈ 6.6`.
- `u` relaxes on `1/|λ| ≈ 0.003` against an O(1) scale for `x` — a separation
  near 300×. The block **self-regulates**: scaling `κ` by 3000× raises `|λ|` by
  only 2.0×, by 100× only 1.5×, because `u` falls until `κu^q` collapses. A
  stiffness sweep in `κ` is therefore uninformative about the step constraint.

`v ∈ ℝ^L` are pure accumulators: `v̇_ℓ` is a flux already computed for `u̇`,
nothing reads them, and they enter no functional. They are `L` of the `2L`
small-block states and **never** attain the error norm's maximum.

### 1.2 The large block and its coordinate

`x` holds `M` members, `M` growing to ~10² over `[0,T]`. Member `j` is created
at time `b_j` and carries a position `ξ_j(t)`, a weight `ρ_j(t) > 0`, and six
further per-member states — **eight components each**, so `x` is ~10³
components against the small block's `2L = 10`. It is a measure transported
along characteristics, `μ_t = Σ_j ρ_j δ_{ξ_j}`, with `ξ̇_j = g(ξ_j, u, p_j)`.

The creation times `b_j` are the **characteristic labels**, and the quadrature
over `μ_t` is taken on that axis. Two coordinates exist:

- the **label coordinate**, abscissa `b_j`: fixed for all time, the map from
  creation schedule to quadrature abscissa is the identity, the grid never
  folds, and the weight equation is `d(log ρ_j)/dt = −m(ξ_j, u, p_j)`;
- a **transported coordinate**, abscissa `−ξ_j(t)`: moves with the flow, folds
  wherever two members coincide in `ξ` — exactly where the pointwise density is
  undefined — and its weight equation carries `−∂g/∂ξ` as well.

Only the label coordinate is used here, for three reasons that are properties of
the implementation rather than preferences. Reverse mode **refuses** the
transported coordinate: there the weights' own sensitivity channel is dropped
and nothing supplies it. The label coordinate removes two data-dependent
branches on active values that the transported one requires. And it removes the
`∂g/∂ξ` term entirely — which in the transported coordinate is evaluated by a
**one-sided finite difference at `1e-6`**, costing one extra rate evaluation per
member per stage and imposing a first-order error floor on the weight equation.

One per-member state is inequality-constrained, `z_j ≥ 0`. See M5: the boundary
is strictly inflowing and is never reached.

### 1.3 The inner problem

Each member carries a scalar `p_j` obtained by solving a **constrained scalar
optimisation** in `(ξ_j, u)`. Its solution is classified into an interior
stationary point, one of **three distinct active-constraint boundaries**, two
terminal states, or two failure states. So `p = P(ξ, u)` is piecewise-smooth
with switching surfaces in `(ξ, u)`, `C⁰` across them; which piece is active
varies by member and evolves through the record.

Its numerical structure matters and is layered:

- the interior root is **convergence-tested to `1e-12` relative**, with a
  data-dependent iteration count;
- but it runs on a **401-knot tabulation** of an underlying curve (uniform in
  the control, `C¹` cubic Hermite with exact values and slopes per knot), so the
  `1e-12` measures convergence to the interpolant, not to the curve. The
  interpolant's own displacement of the root is ~`1e-8`. This is self-consistent
  — the derivative rows are deliberately taken on the same table, so the
  tabulated model *is* the model — but the tabulation's **second** derivative,
  which the adjoint divides by, converges only at `O(h²)` (~`1e-5`) and is
  discontinuous at all 401 knots;
- the **boundaries** of the feasible interval are found by a bracketing
  root-find with a hard-coded stopping tolerance used as *both* absolute and
  relative, giving a bracket of order `1e-4` in the control's units; the value
  returned is the bracket midpoint;
- a second hard-coded tolerance, `1e-3`, classifies any member whose bracket is
  narrower than it into a terminal state.

So the switching surfaces are resolved to ~`1e-3`, against the `1e-12` of the
interior root.

### 1.4 The coupling, and five trapezia

The coupling into the small block is a weighted sum over members,
`a_ℓ(x, u) = Σ_j ρ_j c_ℓ(ξ_j, u, p_j)`. Members reach one another **only**
through this coupling.

The reductions that form it, and the functional that reads the result, are
**five separate trapezium rules over the same node abscissae**: the coupling
reduction exists in two forms that must stay bit-consistent with one another, a
consumption reduction, a census reduction, and the output functional. All are
`O(Δb²)`. The error indicator that drives the creation-grid refinement is itself
the drop-one-point Richardson estimate of that same trapezium, so the rule and
its error estimator are the same object.

Cost is dominated by the member loop: ~86% of an `f` evaluation, `O(M)`, one
inner solve per member. The small block is ~14%.

### 1.5 The output

`J` is a space–time moment of the measure, accumulated **as an ODE state per
member** (so its time accumulation is inside the Runge–Kutta pair, at the pair's
order) and assembled across members by the trapezium of §1.4 at the end.

**`dJ/dθ` is the quantity of interest**, by reverse-mode AD over the whole
trajectory.

## 2. The integrator and its controller, exactly as configured

**Method.** Embedded explicit Runge–Kutta, Cash–Karp 5(4), first-same-as-last by
construction: an accepted step costs five stage evaluations plus one at the
endpoint, which the next step takes as its `k₁`. The endpoint evaluation is
formed **before** the error test and discarded on rejection, so an accuracy
rejection costs six — a full step, not five.

**Error weight.** Per component,

```
D_i = rtol·( a_y·|y_i| + a_dydt·|h·ẏ_i| ) + atol ,     r_i = |e_i| / D_i
```

Configured `atol = rtol = 1e-4`, `a_y = 1`, `a_dydt = 0`. The
derivative-weighted term exists and is switched off. **`atol` and `rtol` are
scalars — there is no per-component floor.**

**Norm.** The **max** norm, `r_max = max_i r_i`, scanned in index order and
broken at the first non-finite ratio, which is treated as a validity rejection.

**Response — three zones with a dead band.** With `S = 0.9`, `ord = 5`:

| zone | action |
|---|---|
| `r_max > 1.1` | reject; `h ← h · max(0.2, S·r_max^{−1/ord})` |
| `0.5 ≤ r_max ≤ 1.1` | accept; **`h` unchanged** |
| `r_max < 0.5` | accept; `h ← h · clamp(S·r_max^{−1/(ord+1)}, 1, 5)` |

The acceptance threshold is **1.1, not 1**. The dead band spans a 17% range in
`h`. The shrink and growth exponents **differ**, `1/ord` against `1/(ord+1)`.
There is no memory: `h_{n+1}` depends only on `r_max` at step `n`.

**The floor accepts.** If the computed shrink is not smaller than the current
step (already at `h_min`), no shrink is reported and the inaccurate step is
committed. Measured: this never fires.

**Validity rejection is a separate path**, `h ← max(0.2·h, h_min)`,
unconditional and always reported as a shrink, triggered by a domain throw from
inside a stage or by a post-step state the system refuses — the latter
overriding an `accept` verdict. Measured: the post-step path never fires,
because what it would refuse is caught a stage earlier by the throw.

**Retry loop.** Unbounded, no attempt cap. On a shrink the state and time are
restored and the step is retried.

**Fragmentation.** Integration is not one sweep. It is split into ~10² legs by
the creation times, which lie on a dyadic geometric grid `Δ = 2^⌊log₂(0.2 t)⌋`
clamped to `[1e-5, 2]` — leg lengths spanning five orders of magnitude, with
**55% of legs shorter than one relaxation time of the small block**, together
spanning 0.43% of the horizon. At the configured tolerance this is **~6 accepted
steps per leg**. The final step of each leg is clipped to land on the boundary
and deliberately does not update the carried step size, so controller history
survives the boundary.

**Limits.** `h_init = h_min = 1e-6` (they are equal), `h_max = 5 = T`.

**Census of step attempts**, over whole runs:

| outcome | smooth forcing | intermittent forcing |
|---|---|---|
| accepted | 530 | 1017 |
| accuracy rejection | 97 | 292 |
| domain rejection (thrown) | 27 | 104 |
| post-step refusal | 0 | 0 |
| accepted at the floor | 0 | 0 |
| **rejections / attempts** | **19.0%** | **28.0%** |
| **rate evaluations on rejected attempts** | **17.3%** | **26.9%** |

Every throw comes from the one inequality-constrained per-member state; the
small block's own guard never fired.

**Which component sets the step.** Histogrammed over every accepted step:

| binding component | smooth | intermittent |
|---|---|---|
| `u_L`, the chain terminus | **77.4%** | 12.9% |
| `u_1 … u_{L−1}` | 6.6% | **56.3%** |
| the `L` accumulators | **0%** | **0%** |
| all member states | 16.0% | 30.8% |

Under smooth sustained forcing `h·|λ|` is **3.5–5.3, pinned** across 13 wide-box
parameter endpoints and a 100× sweep of `κ` — the explicit stability boundary.
Under intermittent forcing it sits an order of magnitude below, and the binding
load moves onto the component the forcing enters and onto the members.

The inequality-constrained per-member state is **invisible to this test**: its
magnitude is ~0.7 of `atol` at creation and ~`2e-5` of its own capacity once
grown, so its weight is the absolute floor alone. Its excursions are caught only
by the domain guard, outside the error test.

## 3. The grids and the forcing

Three grids, all on `[0,T]`, chosen by three unrelated mechanisms:

| grid | discretises | chosen by | count |
|---|---|---|---|
| `𝒢_b` creation times | the quadrature over `μ_t` (identically, on the label axis) | a dyadic heuristic, then error-driven bisection | ~10² |
| `𝒢_t` step times | the time integration | the controller above, reactively | ~10³ |
| `𝒢_f` forcing knots | the reconstruction of `s(t)` | the sampling rate of the input data | ~10³·² |

Roughly `21 : 6 : 1`. **The step grid is coarser than the forcing grid it is
meant to resolve.**

`s(t)` is reconstructed from data on a uniform grid by a monotone `C¹`
interpolant, so `f''` jumps at knots — but **only where `s ≠ 0` on at least one
side**. Over quiescent stretches the reconstruction is exactly zero and
perfectly smooth, so the set of knots that matter is a strict, computable subset
of `𝒢_f`.

**The record is a mixture in time**: quiescent stretches, stretches of many
small events, stretches of few large events, long absences. The local regime is
a deterministic function of the record, and the post-event relaxation rate is
available in closed form from the event size before the event arrives.

The creation-grid refinement loop runs the model, flags nodes whose error
exceeds a threshold, bisects the interval below each flagged node, and repeats —
so its cost is 7–10 full model evaluations, and each iteration's schedule is a
strict superset of the last. It can only insert, never remove.

## 4. Hard constraints any algorithm must respect

Properties of the implementation, verified in source.

**(H1) Neither grid may depend on `θ`.** The step size is a passive `double` in
the adjoint: the controller is not differentiated. A gradient taken through an
adaptive run is therefore the exact gradient of *the model discretised on that
particular grid*, not of the adaptive procedure as a function of `θ`. Likewise a
creation time depending on `θ` would contribute an adjoint term that is not
computed. A `θ`-adaptive choice does not merely roughen `J_h(θ)` — it makes the
reported derivative answer a different question.

**(H2) `𝒢_b ⊂ 𝒢_t`, structurally.** The state dimension grows at each creation,
the solver reallocates, and the integrator refuses to place its clock anywhere
but a recorded step boundary. The realised step grid is
`{supplied} ∪ {creations} ∪ {events} ∪ {T}`; a supplied grid cannot omit one.

**(H3) The creation grid carries four roles at once**: the state dimension, the
quadrature abscissa, the adjoint's range count, and the index by which a
recorded trajectory is reshaped for replay — matched on exact equality. One
vector, four consumers.

**(H4) No data-dependent branch on an active value may enter the tape.**

**(H5) The available L-stable stepper carries no adjoint**, and is not reachable
from the calling layer at all. An implicit treatment of the chain is new work,
not a configuration change.

## 5. What is measured

**(M1) The derivative converges at the value's order where the population is on
the interior branch, and half an order slower where it is not.** Over seven
levels of `𝒢_b` from 12 to 697 members on one shared `𝒢_t`: with 0% of
member-instants on a constrained branch, `J` gives 1.95–2.02 and `dJ/dθ` ~1.8;
with 14%, `J` gives ~1.87 and `dJ/dθ` **~1.34**.

**(M2) A mechanism for M1 that is not discretisation.** Per §1.3 the constrained
branches' locations are frozen at `~1e-4` by an inner tolerance. On the interior
branch the control's placement is **envelope-protected** — the stationarity
condition removes its movement from the derivative. On a constrained branch
there is no envelope: the control *is* the bound and its movement enters at
first order. So constrained members carry a derivative error floored at `1e-4`
that no refinement of any grid reaches, while interior members keep converging.

**(M3) A converged value does not imply a converged derivative, and the gap is
conditioning.** At one creation count: 0.04% error in a functional, 0.9–2.5% in
one of its derivatives, 30–250% in another, one of them **sign-wrong**.
Diagnosed: that derivative is the sum of two opposing paths with elasticities
`+0.783` and `−0.791`, so the answer is 1% of either term and the condition
number is ~100. The amplification is exact —
`err(total) = 100·err(direct) + 101·err(transported)` reproduces the observed
error at six levels across four orders of magnitude and three sign changes. The
differentiation is *not* at fault: at the level where the sign is wrong, the
reverse sweep matches central differences of whole re-runs to five digits and a
forward tangent to ten.

**(M4) Only a fixed grid yields a usable derivative at all.** Central
differences over `δ` from 1e-3 to 1e-9: an adaptive run has **no plateau at any
`δ`** — non-monotone from the second point, four orders and a sign error by
1e-9. A fixed grid gives a clean monotone three-decade plateau, bottoming out at
the inner solve's floor rather than the grid's.

**(M5) The inequality boundary is strictly inflowing; what looks like a boundary
problem is stiffness.** Traced from the rate: `ż|_{z=0} > 0` strictly — the
inflow survives at zero and the outflow carries `z` as an exact linear factor.
The exact flow never reaches the boundary. Near it the dynamics are
`c − (c+d)·z/z_max`: an attracting fixed point at a strictly positive value with
timescale `z_max/(c+d)`, where under stress `d` is large and the timescale
short. An explicit step longer than that overshoots the fixed point past zero,
and every domain rejection is that overshoot. **There is no arrival**, and
therefore no `(f⁻ − f⁺)·dt_e/dθ` term from this source. Rescaling the state to
O(1) would make it visible to the error test but tighten it by five to six
orders, and the local eigenvalue is invariant under change of variable, so the
stiffness would be unchanged.

**(M6) A step program does not transfer across creation-grid levels.** Captured
at one level and replayed one level finer: 18% wrong, derivatives sign-flipped.
Captured at the *finest* level — which yields a **literally identical** time grid
at every level, the levels being nested bisections — still 11% wrong at the
coarsest. Largest step per window within 1.5× of adaptive at every level, so
step *size* is not the explanation. The union of every level's program
reproduces every adaptive answer to 1e-5, at 2.5–4.5× the steps.

**(M7) Across `θ`, a captured grid holds a wide box but no change of record.**
The full ±2× box in six parameters holds at a uniform step-shrink factor of 2;
58% of it at factor 1. Where the replay is wrong, `h·|λ|` on the replayed
trajectory is 1.7–3.2× above the adaptive run's. Across forcing realisations,
zero transfer, and shrinking does not help — the failure is step *placement*.

**(M8) Resolving the derivative requires coarsening, not only refining.** At the
operating creation count the error is ~1% and one bisection takes it to 0.27%,
which is the size of the finite-difference scatter. No order is estimable from
refinement alone; M1's orders are readable only because the grid was coarsened
four halvings below the operating point.

**(M9) At the operating tolerance the time grid, not the creation grid,
dominates under intermittent forcing.** Same creation count, adaptive versus
pinned: 142% apart, while refining the creation grid 8× moves the answer 0.24%.
Under smooth forcing the ordering reverses: the creation-grid error is 0.24%
against a time error of `6.6e-8`.

**(M10) The reported error is the residual of a cancellation.** Under a smooth
record the forward solve's reconstruction error is `−0.617%`, the output
quadrature's own error `+0.359%`, and the reported total `−0.259%` — both
`O(Δb²)`, ratio `−0.582 / −0.581 / −0.580` at successive levels. The mechanism
is §1.4: the reconstruction and the functional use the same rule on the same
grid.

## 6. What is already settled

- Error shares between two grids of different order should be **proportional to
  order**, not equidistributed — from equal marginal error reduction per unit
  cost under power-law errors and bilinear cost.
- Raising the order of the output quadrature *alone* is wrong: per M10 it
  removes one side of a cancellation and makes the reported answer 2.4× worse,
  while cutting the quadrature term itself 148–258×.
- Multirate collapses into a linearly-implicit treatment of the chain, because
  the expensive coupling term is itself a function of the fast variable, so
  every micro-step would re-evaluate the member loop.
- The step controller's max norm is telling the truth: the binding ranking is a
  tight cluster, and removing every member component from the norm changes the
  accepted step count by under 1%.

## 7. Questions

### 7.1 A grid construction with provable properties

Given a known record (§3), the hard constraints (H1–H3), and a target accuracy
in `dJ/dθ`: what is the **minimal well-understood construction** of `𝒢_t` and
`𝒢_b` whose properties can be stated in advance rather than measured after?

The guarantees that would be useful, in order: that the realised grid contains
every structurally required stop (H2) by construction rather than by check; that
its local density is set by a quantity computable from the record before the run;
that it is `θ`-independent by construction (H1); and that its error in `dJ/dθ`
is bounded by a computable quantity. Which of those four are achievable
together, and which is the first to give way?

### 7.2 Refinement that certifies a derivative

M3 and M8: the usual instruments mislead. A creation count that converges a
functional to 0.04% can leave a derivative 20–60× worse or sign-wrong; and the
operating point is too close to the noise floor for a refinement sequence to
yield an order at all without coarsening below it.

(a) What is the correct stopping rule for a refinement whose target is a
derivative? (b) M3's condition number — the ratio of a component path to the
total — is computable from quantities the sweep already forms. Is that a
sufficient a posteriori indicator, and what covers the cases where no such
decomposition is exposed? (c) Is there a principled reason to run a refinement
study *downward* from the operating point, as M8 forced, and does that change
what the sequence certifies?

### 7.3 An error floor on a subpopulation

M2: part of the population carries a derivative error floored by an inner
tolerance that no grid refinement reaches, and the floored fraction varies
through the record because it is driven by the forcing.

(a) Does a floored subpopulation produce a genuinely fractional convergence
order, or a plateau that a short sequence misreads as one — and what
distinguishes them? (b) What is the honest way to state, and to certify,
convergence of a quantity whose error is the sum of a converging part and a
floored part with a time-varying mixing fraction? (c) Given the floor is an
inner tolerance rather than a grid, what sets its correct value relative to the
discretisation error it must not dominate?

### 7.4 What M6 is telling us

A time grid that is *identical* — same times, to the bit — gives an 11%
different derivative when the creation grid beneath it changes. Step size is
excluded as the explanation. Under H3 the creation grid is also the state
dimension, the quadrature abscissa and the reshape index, so "changing the
creation grid" is not one change.

(a) What is the likely mechanism, and how would one distinguish the candidates
(the quadrature of §1.4; the changed coupling through a differently-resolved
reconstruction; the replay's reshape; a genuinely different trajectory)?
(b) Does a *designed* grid — placed from the record rather than captured from a
run — avoid it, or is the sensitivity structural? (c) Is the union of levels'
programs a legitimate instrument for a refinement study, or does it answer a
different question from any single level?

### 7.5 One grid across parameters, with a certificate

M4 and M7: a shared fixed grid is the only thing that yields a usable
derivative, it holds a wide parameter box under a uniform safety factor, and it
does not survive a change of record.

(a) What certificate should accompany a shared grid, given that the quantity to
certify is a derivative and the usual adjoint-weighted residual bounds the
*value*? Is a second-order object required, or is there a cheaper sufficient
condition? (b) What is the principled trigger for recapture inside an
optimisation, and can a trust region in `θ` be *proved* rather than measured?
(c) Since the record is fixed throughout a calibration, is "one designed grid
per record, recaptured on certificate failure" simply correct — and does a
designed grid have a provably wider validity region than a captured one?

### 7.6

Which of H1–H5 and M1–M10 is load-bearing for each answer, and which incidental?
What guarantee is available here that we have not asked for? And which of the
four in 7.1 would you sacrifice first?

## 8. What is free

- The forcing record is known in full in advance, and so is every creation time.
- A step boundary can be forced at any time, with no member attached, by an
  existing mechanism.
- The error norm's derivative-weighted term (`a_dydt`) is wired end to end and
  set to zero. It is the one knob that most directly changes *which* component
  sets the step size.
- Instrumentation naming the component that set each step's size, and the
  outcome of every step attempt, exists and is unread.
- Per-member-population creation grids are supported independently.
- `L ≤ 5`; dense linear algebra on the chain is free, its Jacobian analytic and
  bidiagonal.
- The choice of grid is off the tape: it may depend on anything, including
  quantities from a previous solve — subject only to H1.
- The formulation may change if the change is declared and its effect on
  `dJ/dθ` is budgeted.
