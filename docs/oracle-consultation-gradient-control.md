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
the quadrature abscissae, fixed for all time. `s(t)` is a known record. `dJ/dθ`
is the quantity wanted, `θ ∈ ℝ^k`, `k ≈ 17`, by reverse-mode AD over the whole
trajectory.

The integration runs on two grids — creation times `𝒢_b` and step times `𝒢_t` —
and neither may depend on `θ`. Choosing them, with stated guarantees, is the
question. Everything below explains a part of it.

Every measurement here comes from one model configuration at one parameter
vector, on six forcing records. Where a number is a property of that fixture
rather than of the structure, it says so.

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
| `𝒢_b` creation times | the quadrature over `μ_t` | a dyadic generator, then error-driven bisection | ~10² |
| `𝒢_t` step times | the time integration | the controller above | ~10³ |
| `𝒢_f` record knots | the reconstruction of `s` | the input data's sampling rate | ~10³·² |

Roughly `21 : 6 : 1`.

`s(t)` is reconstructed by a monotone `C¹` interpolant, so `f''` jumps at knots
where `s ≠ 0` on at least one side. Over quiescent stretches the reconstruction
is identically zero and smooth, so the knots that matter form a computable
subset of `𝒢_f`.

The record is a mixture in time: quiescent stretches, stretches of many small
events, stretches of few large events, long absences. The local regime is a
deterministic function of the record, and the post-event relaxation rate follows
in closed form from the event size before the event arrives.

The refinement loop runs the model, flags nodes whose indicator exceeds a
threshold, bisects the interval below each flagged node, and repeats: 7–10 full
model evaluations, each schedule a strict superset of the last, insertion only.

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

## Measured

**(M1)** Over seven levels of `𝒢_b` from 12 to 697 members on one shared `𝒢_t`:
with 0% of member-instants on a constrained branch, `J` converges at 1.95–2.02
and `dJ/dθ` at ~1.8. With 14%, `J` holds ~1.87 and `dJ/dθ` falls to **~1.34**.

**(M2)** On the interior branch the control's placement is envelope-protected:
the stationarity condition removes its movement from the derivative. On a
constrained branch the control is the bound, and its movement enters at first
order — so those members carry a derivative error floored at the `1e-4` bracket
while interior members keep converging.

**(M3)** At one creation count: 0.04% error in a functional, 0.9–2.5% in one of
its derivatives, 30–250% in another, one of them sign-wrong. That derivative is
a sum of two opposing paths with elasticities `+0.783` and `−0.791`, so the
answer is 1% of either term and the condition number is ~100. The amplification
is exact: `err(total) = 100·err(direct) + 101·err(transported)` reproduces the
observed error at six levels across four orders of magnitude and three sign
changes. At the level where the sign is wrong, the reverse sweep matches central
differences of whole re-runs to five digits and a forward tangent to ten.

**(M4)** Central differences over `δ` from 1e-3 to 1e-9: an adaptive run gives
no plateau at any `δ` — non-monotone from the second point, four orders and a
sign error by 1e-9. A fixed grid gives a monotone three-decade plateau, floored
by the inner solve.

**(M5)** A step program captured at one creation level and replayed one level
finer is 18% wrong, with derivatives sign-flipped. Captured at the finest level
— which yields a bit-identical time grid at every level, the levels being nested
bisections — it is 11% wrong at the coarsest. The largest step per window is
within 1.5× of adaptive at every level. The union of every level's program
reproduces every adaptive answer to 1e-5, at 2.5–4.5× the steps.

**(M6)** A captured grid holds the full ±2× box in six parameters at a uniform
step-shrink factor of 2, and 58% of it at factor 1. Where a replay is wrong,
`h·|λ|` on the replayed trajectory is 1.7–3.2× above the adaptive run's. Across
forcing records there is zero transfer and shrinking does not recover it.

**(M7)** At the operating creation count the error is ~1% and one bisection
takes it to 0.27%, the size of the finite-difference scatter. M1's orders are
readable only because the grid was coarsened four halvings below the operating
point.

**(M8)** Under an intermittent record, adaptive and pinned time grids at the
same creation count are 142% apart, while refining the creation grid 8× moves
the answer 0.24%. Under a smooth record the ordering reverses: creation-grid
error 0.24% against a time error of `6.6e-8`.

**(M9)** Under a smooth record the forward solve's reconstruction error is
`−0.617%`, the output quadrature's own error `+0.359%`, and the reported total
`−0.259%` — both `O(Δb²)`, in a ratio of `−0.582 / −0.581 / −0.580` at
successive levels.

## Settled

Error shares between two grids of different order go in proportion to order,
from equal marginal error reduction per unit cost under power-law errors and
bilinear cost.

Raising the order of the output quadrature alone cuts its own term 148–258× and
makes the reported answer 2.4× worse, because M9's two terms cancel.

Multirate collapses into a linearly-implicit treatment of the chain: the
expensive coupling term is a function of the fast variable, so every micro-step
re-evaluates the member loop.

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
(b) M3's condition number is computable from quantities the sweep already forms.
Is it a sufficient a posteriori indicator, and what covers the cases where no
such decomposition is exposed? (c) Is there a principled reason to run a
refinement study downward from the operating point, and does that change what
the sequence certifies?

### 3. An error floor on a subpopulation

M2: part of the population carries a derivative error floored by an inner
tolerance no grid refinement reaches, and the floored fraction varies through
the record because the forcing drives it.

(a) Does a floored subpopulation produce a genuinely fractional convergence
order, or a plateau that a short sequence misreads as one — and what
distinguishes them? (b) How should convergence be stated and certified for a
quantity whose error is a converging part plus a floored part with a
time-varying mixing fraction? (c) The floor is an inner tolerance. What sets its
correct value relative to the discretisation error it must stay under?

### 4. What M5 is telling us

A bit-identical time grid gives an 11% different derivative when the creation
grid beneath it changes, with step size excluded as the explanation. Under H3,
changing the creation grid is four changes at once.

(a) What is the likely mechanism, and how would one separate the candidates —
the five trapezia, the coupling through a differently-resolved reconstruction,
the replay's reshape, a genuinely different trajectory? (b) Does a grid placed
from the record avoid it, or is the sensitivity structural? (c) Is the union of
levels' programs a legitimate instrument for a refinement study, or does it
answer a different question from any single level?

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

Which of H1–H5 and M1–M9 carries each answer, and which is incidental? What
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
