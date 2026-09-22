# Control algorithms with guarantees for a gradient on a shared grid

## The whole thing

```
u̇_ℓ          = s(t)·[ℓ=1] − κ_ℓ u_ℓ^q + κ_{ℓ−1} u_{ℓ−1}^q − a_ℓ(x,u)    ℓ = 1…L,  L ≤ 5,  q ≈ 16
ξ̇_j          = g(ξ_j, u, p_j)                                            j = 1…M,  M ~ 10²
d(log ρ_j)/dt = −m(ξ_j, u, p_j)
σ(p_j; ξ_j, u) = 0                                                        inner, constrained
a_ℓ(x,u)      = Σ_j ρ_j c_ℓ(ξ_j, u, p_j)
J             = Σ_j w_j φ_j                                               w from the trapezium on b
```

Member `j` is created at time `b_j`. The `b_j` are the characteristic labels and
the quadrature abscissae, fixed for all time. `φ_j` is the member's accumulated
moment, itself an ODE state. `w_j` is the trapezium weight on `b` times a second
known record sampled at `b_j`, so the creation grid enters `J` as abscissae and
as sample points. `s(t)` is a known record. `dJ/dθ` is the quantity wanted,
`θ ∈ ℝ^k`, `k ≈ 17`, by reverse-mode AD over the whole trajectory.

The integration runs on two grids — creation times `𝒢_b` and step times `𝒢_t` —
and neither may depend on `θ`. Choosing them, with stated guarantees, is the
question. Everything below explains a part of it.

Measurements come from two horizons, flagged **[short]** and **[long]**. At
`T = 5` the functional is ~1e-10 and the population is close to extinction; that
horizon carries most of the detail below. At `T = 40` the functional is 5.25,
five times self-replacing. The same parameter vector gives 1e-10 at the short
horizon and 43 at the long one, so where the two disagree the long one
governs.

## The system

`u` is a one-way chain: the loss is diagonal, the transfer strictly one-way, so
`u_1` receives the forcing and `u_L` terminates the chain. Its Jacobian is
bidiagonal and analytic — diagonal `−qκ_ℓ u_ℓ^{q−1}`, subdiagonal
`+qκ_{ℓ−1} u_{ℓ−1}^{q−1}`. A lower bound `u_ℓ > u_min` applies; approaching it,
a quantity read off `u` diverges like `u^{−p}`, `p ≈ 6.6`.

The chain relaxes on `1/|λ| ≈ 0.003` against an O(1) scale for `x`, a separation
near 300×. It self-regulates: scaling `κ` by 3000× raises `|λ|` by 2.0×, by 100×
raises it 1.5×, because `u` falls until `κu^q` collapses.

Alongside `u` sit `L` accumulators, `v̇_ℓ` a flux already computed for `u̇`. They
enter no functional and nothing reads them.

`M` starts at zero and grows monotonically over `[0,T]`; members are never
removed. `ρ_j → 0` is absorbing and many members reach it, `log ρ_j` arriving at
`−∞` as a state the system then carries. A new member's initial conditions are
computed from the state at its creation time, so each creation contributes its
own path to `dJ/dθ` alongside the steps.

Each member carries eight components — `ξ_j`, `ρ_j`, and six further states — so
`x` is ~10³ components against the chain's `2L = 10`. One per-member state `z_j`
is bounded below by zero, and `ż|_{z=0} > 0` strictly: the inflow survives at
zero and the outflow carries `z` as an exact linear factor. Near the bound the
dynamics are `c − (c+d)·z/z_max`, an attracting fixed point at a strictly
positive value with timescale `z_max/(c+d)`. Under stress `d` is large and that
timescale short.

Members reach one another only through `a_ℓ`.

### The inner problem

`p_j` solves a constrained scalar optimisation in `(ξ_j, u)`, classified into an
interior stationary point, one of three active-constraint boundaries, two
terminal states or two failure states. `P(ξ, u)` is piecewise-smooth with
switching surfaces in `(ξ, u)`, `C⁰` across them, and which piece is active
evolves through the record.

Its tolerances are layered. The interior root is convergence-tested to `1e-12`
relative, on a 401-knot tabulation of the underlying curve — uniform in the
control, `C¹` cubic Hermite with exact values and slopes per knot. The
tabulation displaces the root by ~`1e-8`. Its derivative rows are taken on the
same table, so the tabulated curve is the model; its second derivative, which
the adjoint divides by, converges at `O(h²)` ≈ `1e-5` and is discontinuous at
every knot. The feasible interval's boundaries come from a bracketing root-find
whose stopping tolerance is hard-coded and used as both absolute and relative,
giving a bracket of order `1e-4` in the control's units and returning the
midpoint. A second hard-coded tolerance, `1e-3`, classifies any member whose
bracket is narrower into a terminal state.

The switching surfaces are therefore resolved to `1e-3`.

### Five trapezia

`a_ℓ` is assembled by reductions over the node abscissae, and the functional
reads the result the same way. There are five trapezium rules on that grid: the
coupling reduction in two forms that must stay bit-consistent, a consumption
reduction, a census reduction, and `J` itself. All are `O(Δb²)`. The error
indicator driving creation-grid refinement is the drop-one-point Richardson
estimate of that same trapezium.

`J`'s time accumulation is an ODE state per member, so it integrates inside the
Runge–Kutta pair at the pair's order; the trapezium assembles across members at
the end.

The member loop is ~86% of an `f` evaluation, `O(M)`, one inner solve each.

## The integrator as configured

Cash–Karp 5(4), first-same-as-last: an accepted step costs five stage
evaluations plus one at the endpoint, which the next step takes as its `k₁`. The
endpoint evaluation is formed before the error test and discarded on rejection,
so an accuracy rejection costs six.

Per component, `D_i = rtol·(a_y·|y_i| + a_dydt·|h·ẏ_i|) + atol`, `r_i = |e_i|/D_i`,
with `atol = rtol = 1e-4`, `a_y = 1`, `a_dydt = 0`. Both tolerances are scalars.
Acceptance is on the max norm, scanned in index order, broken at the first
non-finite ratio.

With `S = 0.9` and `ord = 5`:

| zone | action |
|---|---|
| `r_max > 1.1` | reject; `h ← h · max(0.2, S·r_max^{−1/ord})` |
| `0.5 ≤ r_max ≤ 1.1` | accept; `h` unchanged |
| `r_max < 0.5` | accept; `h ← h · clamp(S·r_max^{−1/(ord+1)}, 1, 5)` |

`h_{n+1}` depends only on `r_max` at step `n`. Acceptance is at 1.1. The dead
band spans 17% in `h`. Shrink and growth carry different exponents. At `h_min`
the shrink is not applied and the step is committed; measured, this never fires.

A domain throw from inside a stage takes a separate path, `h ← max(0.2h, h_min)`,
always reported as a shrink. A post-step state refusal overrides an accept
verdict; measured, it never fires, because what it would refuse is caught a
stage earlier. The retry loop is unbounded.

No step is aligned to a switching-surface crossing or to a knot of the record.
The only forced stops are creations and scheduled events; there is no event
detection.

Integration is split into ~10² legs by the creation times, which lie on a dyadic
grid `Δ = 2^⌊log₂(0.2 t)⌋` clamped to `[1e-5, 2]`. Leg lengths span five orders
of magnitude; 55% of legs are shorter than one chain relaxation time and
together span 0.43% of the horizon. The configured tolerance gives ~6 accepted
steps per leg. The final step of each leg is clipped to the boundary and does
not update the carried step size. `h_init = h_min = 1e-6`, `h_max = 5 = T`.

Step attempts over whole runs:

| outcome | smooth record | intermittent record |
|---|---|---|
| accepted | 530 | 1017 |
| accuracy rejection | 97 | 292 |
| domain rejection (thrown) | 27 | 104 |
| post-step refusal | 0 | 0 |
| committed at `h_min` | 0 | 0 |
| rejections / attempts | 19.0% | 28.0% |
| rate evaluations on rejected attempts | 17.3% | 26.9% |

Every throw comes from `z_j` overshooting its fixed point past zero.

Which component attains `r_max`, over every accepted step:

| component | smooth | intermittent |
|---|---|---|
| `u_L`, chain terminus | 77.4% | 12.9% |
| `u_1 … u_{L−1}` | 6.6% | 56.3% |
| the `L` accumulators | 0% | 0% |
| member states | 16.0% | 30.8% |

Under a smooth record `h·|λ|` holds at 3.5–5.3 across 13 wide-box parameter
endpoints and a 100× sweep of `κ` — the explicit stability boundary. Under an
intermittent record it sits an order of magnitude below it.

`z_j` sits at ~0.7 of `atol` at creation and ~`2e-5` of its own capacity once
grown, so its weight in the norm is the absolute floor alone and its excursions
reach the domain guard without passing the error test.

## The grids and the record

| grid | discretises | chosen by | count |
|---|---|---|---|
| `𝒢_b` creation times | the quadrature over `μ_t` | a dyadic generator, then error-driven bisection | 88 |
| `𝒢_t` step times | the time integration | the controller above | 530 smooth, 1725 intermittent |
| `𝒢_f` record knots | the reconstruction of `s` | the input data's sampling rate | 1824 |

`s(t)` is reconstructed by a monotone `C¹` interpolant, so `f''` jumps at knots
where `s ≠ 0` on at least one side. Over quiescent stretches the reconstruction
is identically zero and smooth, so the knots that matter form a computable
subset of `𝒢_f`: on the intermittent record, **412 active knots** against 1824
in range. That is 0.24 active knots per accepted step, and 22.6% of accepted
steps contain one. Every active knot falls strictly inside a step.

The record is a mixture in time: quiescent stretches, stretches of many small
events, stretches of few large events, long absences. The local regime is a
deterministic function of the record, and the post-event relaxation rate follows
in closed form from the event size before the event arrives.

The refinement loop runs the model, flags nodes whose indicator exceeds a
threshold, bisects the interval below each flagged node, and repeats: 7–10 full
model evaluations, each schedule a strict superset of the last, insertion only.

Its threshold is `2e-2`, against the time integration's `1e-4`. On a smooth
record the largest indicator reaches 0.0099, so refinement never fires and the
refined grid equals the unrefined one. Where it does fire, its stopping rule
reports convergence while `J` is still moving by a factor of 3.0–4.3 across
iterations, and the indicator is not monotone under bisection — over seven
refinements it rises twice before falling.

## Constraints

**(H1)** The step size is a passive `double` in the adjoint; the controller is
not differentiated. A gradient taken through an adaptive run is the exact
gradient of the model discretised on that grid. A creation time depending on `θ`
contributes an adjoint term that is not computed. So a `θ`-adaptive choice makes
the reported derivative answer a different question.

**(H2)** `𝒢_b ⊂ 𝒢_t` structurally: the state dimension grows at each creation,
the solver reallocates, and the integrator places its clock only at a recorded
step boundary. The realised grid is `{supplied} ∪ {creations} ∪ {events} ∪ {T}`.

**(H3)** The creation grid carries four roles at once — the state dimension, the
quadrature abscissa, the adjoint's range count, and the index by which a
recorded trajectory is reshaped for replay — matched on exact equality.

**(H4)** No data-dependent branch on an active value may enter the tape.

**(H5)** The available L-stable stepper carries no adjoint and is unreachable
from the calling layer. An implicit treatment of the chain is new work.

**(H6)** The reverse sweep consumes a recording of the forward run and re-derives
`k₁` at each step's own start state, rebuilding stage states from re-derived
rates. It therefore evaluates `f` at states the forward pass never visited. The
recording is not self-describing: the creation schedule is the source of truth,
and a recorded time's member count is re-derived from it by matching on exact
equality.

## Measured

**(M1) The functional is a step function in `θ`.** [short] Scanned over 25 trait
values spanning ±3%, `J` departs from a smooth cubic by 0.107% rms and 0.267%
peak, with two visible **step discontinuities of 0.3–0.4%** (lag-1
autocorrelation 0.46, so not round-off). The steps sit where the inner problem's
classification reorganises — the non-interior share jumping 0.4–0.5 points
between trait values 0.25% apart. It is not the time tolerance: the same scan
ten times looser gives 0.103%. Differentiating it accounts for the observed
gradient error: from `dlnJ/dln θ = −2.88` and `dε/dln θ ≈ 0.09` the predicted
error is 3.1% against 2.7–3.4% measured — one step, differentiated.

**(M2) Step placement dominates, and tolerance barely matters.** [short] Forcing
a step boundary at each of the record's 412 active knots collapses a **140%**
gap to **−0.057%**. Two controls separate the mechanism: 412 stops placed in
quiescent spans, where the reconstruction is identically zero, reach the right
answer at one tolerance and fail by **+92.6%** at another; the same 412 knots
shifted a quarter of a cell hold everywhere to 2.6%. So placing stops *within
event stretches* removes most of it and landing *on the breakpoints* removes the
residual.

It is not order reduction. Unaligned, the error across three decades of
tolerance is `+117.7, +64.8, +121.1, +132.4, +140.4%` — flat and non-monotone —
then falls 300× in a single half-decade. One extra forced stop **anywhere** in
the run, over 16 placements tried, moves the functional across `6.2e-11` to
`1.85e-10`, straddling the converged value in both directions.

**(M3) At a realistic horizon the placement error does not wash out.** [long] At
the short horizon it was a coarse-grid pathology: +140% at 88 members, 0.5% at
175. At eight times the horizon it is **−35.4 / −16.9 / −39.9%** at 108 / 215 /
429 members, and −22% at a tolerance ten times tighter with 61% more steps than
the aligned run needs. Aligned, the functional holds to **0.29% across four
decades of tolerance** and is right at the loosest.

**(M4) A state-clamping branch is an artefact of placement.** [long] One
terminal branch of the inner problem clamps state; the others move it
continuously. Unaligned its share is 0.40% and **does not respond to tolerance
across three decades** — it passes a convergence test by sitting still. Aligned
it falls to 0.015–0.027% and keeps falling; on a pinned step program it is
**exactly zero at every level over 28 million solves**. Under a 41-year record
whose forcing fails for three multi-year spans, the residue is 0.002%, scales
with member creations, and concentrates in the first years — tracking creation
density, not the forcing. Two
further terminal branches are exactly zero everywhere. Only the interior branch
and one active-constraint branch, occupied 4–13%, are genuinely visited.

**(M5) A converged value does not imply a converged derivative, and the gap is
conditioning.** [short] At one creation count: 0.04% error in a functional,
0.9–2.5% in one of its derivatives, 30–250% in another, one of them
**sign-wrong**. That derivative is a sum of two opposing paths with elasticities
`+0.783` and `−0.791`, so the answer is 1% of either term and the condition
number is ~100. The amplification is exact:
`err(total) = 100·err(direct) + 101·err(transported)` reproduces the observed
error at six levels across four orders of magnitude and three sign changes. The
differentiation is not at fault — at the level where the sign is wrong, the
reverse sweep matches central differences of whole re-runs to five digits and a
forward tangent to ten.

**(M6) The finite-difference plateau is a property of the instrument.** [short]
At the operating tolerance, aligned, there is **no plateau at any `δ`** from
1e-3 to 1e-9. Two decades tighter a plateau **1.5 decades wide** appears, flat to
0.63%, with the difference scaling linearly in `δ` across exactly that range; a
pinned program gives one decade, and the two agree to 0.06%.

**(M7) The derivative's convergence is not settled by differencing.** [short] Two
independent ladders on aligned grids disagree. One finds the value at ~1.9 and
the derivative **not estimable** — level-to-level spread 21%, the sequence
reversing at four of six steps. The other reports a persistent gap of 0.44–0.56
whose per-window values are 1.08/2.06 and 1.76/1.17, and states that the design
cannot separate an asymptotic order difference from a coarse-end constant. **The
adjoint, which forms no difference, gives derivative orders of 1.29–1.91 against
values at 1.31–1.94.**

**(M8) Resolving anything about the derivative requires coarsening.** [short] At
the operating creation count the error is ~1% and one bisection takes it to
0.27%, the size of the difference scatter. Orders are readable only four
halvings below the operating point.

**(M9) A step program does not transfer across creation-grid levels.** [short]
Captured at one level and replayed one level finer: 18% wrong, derivatives
sign-flipped. Captured at the finest level — which yields a bit-identical time
grid at every level, the levels being nested bisections — still 11% wrong at the
coarsest. The largest step per window is within 1.5× of adaptive at every level.
The union of every level's program reproduces every adaptive answer to 1e-5, at
2.5–4.5× the steps.

**(M10) Across `θ`, a captured grid holds a wide box.** [short] The full ±2× box
in six parameters holds at a uniform step-shrink factor of 2, and 58% of it at
factor 1. Where a replay is wrong, `h·|λ|` on the replayed trajectory is 1.7–3.2×
above the adaptive run's. Across forcing records there is zero transfer.

**(M11) The reported error is the residual of a cancellation.** [short] Under a
smooth record the forward solve's reconstruction error is `−0.617%`, the output
quadrature's own error `+0.359%`, the reported total `−0.259%` — both `O(Δb²)`,
in a ratio of `−0.582 / −0.581 / −0.580` at successive levels. The mechanism is
§1.4: the reconstruction and the functional use the same rule on the same grid.

## Settled

Error shares between two grids of different order go in proportion to order,
from equal marginal error reduction per unit cost under power-law errors and
bilinear cost.

Raising the order of the output quadrature alone cuts its own term 148–258× and
makes the reported answer 2.4× worse, because M11's two terms cancel.

Multirate collapses into a linearly-implicit treatment of the chain: the
expensive coupling term is a function of the fast variable, so every micro-step
re-evaluates the member loop. An additive split that keeps the member loop
explicit and evaluated once per stage is a different proposition and is not
excluded.

The max norm is reporting honestly. The binding ranking is a tight cluster, and
removing every member component from the norm changes the accepted step count by
under 1%.

## Questions

### 1. A grid construction with provable properties

Given the record, H1–H3, and a target accuracy in `dJ/dθ`: what is the minimal
well-understood construction of `𝒢_t` and `𝒢_b` whose properties can be stated
in advance?

Four guarantees would be useful — that the realised grid contains every
structurally required stop by construction; that its local density follows from
a quantity computable from the record before the run; that it is `θ`-independent
by construction; and that its error in `dJ/dθ` is bounded by a computable
quantity. Which are achievable together, and which gives way first?

### 2. Refinement that certifies a derivative

M3 and M7: a creation count that converges a functional to 0.04% can leave a
derivative 20–60× worse or sign-wrong, and the operating point sits too close to
the noise floor for a refinement sequence to yield an order without coarsening
below it.

(a) What is the correct stopping rule for a refinement targeting a derivative?
(b) M5's condition number is computable from quantities the sweep already forms.
Is it a sufficient a posteriori indicator, and what covers the cases where no
such decomposition is exposed? (c) Is there a principled reason to run a
refinement study downward from the operating point, and does that change what
the sequence certifies?

### 3. An objective that is a step function in `θ`

M1: `J` is piecewise smooth with 0.3–0.4% steps wherever a discrete
classification of the inner problem reorganises, and differentiating those steps
accounts for ~98% of the observed finite-difference gradient error. The adjoint
is exact for each piece. M4 says the worst-behaved branch — the one that clamps
state — is an artefact of step placement and reaches exactly zero on a
well-placed grid, but one genuinely occupied active-constraint branch remains.

(a) What is the right treatment: smoothing the classification with a declared
width, locating the crossing and stepping to it, or accepting the steps and
choosing an optimiser that tolerates them? (b) A smoothed switch of width `w`
puts a feature of scale `w` into the right-hand side, which the integrator must
then resolve, so `w` is pulled small by the bias budget and large by the step
size. What sets it? (c) What can be guaranteed to an optimiser given an
objective that is smooth almost everywhere, carries dense jumps of known scale,
and has an exact gradient for each piece? (d) Is there a formulation in which the
classification never becomes discrete — the feasible interval collapsing
smoothly in place of a threshold — and what does that cost?

### 4. What M9 is telling us

A bit-identical time grid gives an 11% different derivative when the creation
grid beneath it changes, with step size excluded as the explanation. Under H3,
changing the creation grid is four changes at once. M2 shows the same system is
extraordinarily sensitive to *where* steps fall — one extra stop anywhere moves
the functional by a factor of three — which may make M9 a special case of that
and not a separate phenomenon.

(a) Are M2 and M9 one mechanism or two? If one, the cure for both is a grid
placed from the record rather than captured from a run; if two, what
distinguishes them? (b) How would one separate the remaining candidates — the
five trapezia of §1.4, the coupling through a differently-resolved
reconstruction, H6's re-derivation of stage states at a different member count?
(c) Is the union of levels' programs a legitimate instrument for a refinement
study, or does it answer a different question from any single level?

### 5. One grid across parameters, with a certificate

M4 and M6: a shared fixed grid is what yields a usable derivative, it holds a
wide parameter box under a uniform safety factor, and it does not survive a
change of record.

(a) What certificate should accompany a shared grid, given the quantity to
certify is a derivative and the usual adjoint-weighted residual bounds the
value? Is a second-order object required, or is a cheaper sufficient condition
available? (b) What triggers recapture inside an optimisation, and can a trust
region in `θ` be proved? (c) The record is fixed throughout a calibration. Is
one designed grid per record, recaptured on certificate failure, the whole
answer — and does a designed grid have a provably wider validity region than a
captured one?

### 6.

Which of H1–H6 and M1–M11 carries each answer, and which is incidental? What
guarantee is available that we have not asked for? Which of the four in question
1 would you sacrifice first?

## Free

The record is known in full before the run, and so is every creation time. A
step boundary can be forced at any time with no member attached. The error
norm's derivative-weighted term is wired end to end and set to zero.
Instrumentation naming the component that set each step's size, and the outcome
of every step attempt, exists and is unread. Creation grids are supported
per-population independently. Dense linear algebra on the chain is free and its
Jacobian analytic.

The choice of grid is off the tape: it may depend on anything, including
quantities from a previous solve, subject to H1. The formulation may change if
the change is declared and its effect on `dJ/dθ` budgeted.
