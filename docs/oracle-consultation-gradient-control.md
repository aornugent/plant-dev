# Control algorithms with guarantees for a gradient on a shared grid

## The whole thing

A Cash–Karp 5(4) pair integrating a known daily rainfall record over forty years
delivers 114.566 of the record's 120.267 — **4.74% of the water missing** — and
reports an error of exactly zero on every step that loses it.

The reason is in the tableau. One state accumulates the forcing alone, `v̇ = s(t)`,
so a step on it is a pure quadrature. The fifth-order increment reads `s` at
`{0, 0.3, 0.6, 0.875}·h`; the embedded difference reads it at
`{0, 0.3, 0.6, 0.875, 1}·h` and vanishes identically on any integrand of degree
three or below. The widest gap between those abscissae is `0.3h`. An event
narrower than `0.3h` falls between all of them, the increment misses the water,
the difference of two quadratures that both missed it is zero, and the controller
reads zero as a perfect step and grows `h` fivefold. Seventy accepted steps of
11 319 carry 100.05% of the deficit; 58 deliver exactly zero while their interval
holds up to 0.345 of water. Because the infiltration term reads the same
abscissae, the water is absent from the physics, not only from the record.

Error control cannot reach this. `errlevel` is the denominator of a ratio whose
numerator is a true zero, so neither tolerance nor the derivative-weighted term
touches it: four decades of tightening leave 0.94% of the water missing at
23 656 steps, twice what a grid that samples the record needs. Two things do
reach it. A cap on `h` — an event of width `w` is sampled once `0.3h < w`, and
capping `h` at five days on an otherwise untouched grid recovers the water to
`+0.002%` and the functional to 0.10%. Or a forced stop at each of the record's
2931 active breakpoints, which recovers the integral to `3.2e-12` relative.

The other grid fails differently, for a related reason. `J` is a trapezium over
birth dates, and a newborn whose net production is non-positive at creation
establishes with probability exactly zero and contributes nothing. So the
integrand carries jumps at birth dates the record decides — failure bands 23 days
to six months wide, tracking the rain in the month before birth. Refining the
count does not converge it: over 108, 215, 429 and 857 nodes `J` reads 12.053,
12.089, 13.032, 12.843, successive differences `+0.036`, `+0.943`, `−0.188`, the
second **26×** the first and the third **−0.20×** the second. There is no `h^p`
to fit and no level is a reference.

Both grids are placed by rules that read the clock. The record decides where the
forcing must be sampled and where the integrand jumps.

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
as sample points. `s(t)` is the record above. `dJ/dθ` is the quantity wanted,
`θ ∈ ℝ^k`, `k ≈ 17`, by reverse-mode AD over the whole trajectory.

`dJ/dθ` drives a gradient-based calibration: the optimiser takes descent steps
in `θ` against data, so the requirement on the derivative is whatever makes those
steps reliable, and a relative bound on it would serve where an absolute one is
unavailable.

The integration runs on two grids — creation times `𝒢_b` and step times `𝒢_t`.
Neither may depend on `θ`, because the adjoint differentiates the model as
discretised and the controller is outside the tape (H1): a grid that moves with
`θ` makes the reported derivative the exact derivative of a different function at
each point. So the grids are chosen once, before the optimisation, and must hold
over every `θ` it visits. Constructing them with stated guarantees is the
question. Everything below explains a part of it.

The horizon is `T = 40`. The trait vector used throughout gives `J = 12.078`, and
the default birth rate makes `J` the net reproduction ratio directly, so the
stand is twelve times self-replacing. Two measurements below come from a
near-extinct operating point at `J = 1e-10` and say so.

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
estimate of that same trapezium, taken on two of those functions and maxed
against one threshold. The two do not share an abscissa: the competition term
reads whichever abscissa the density coordinate selects, and the reproduction
term and `J` read the creation times unconditionally. In the birth-date setting
they coincide; in the other they are estimates over different variables, with `J`
on the second.

`J`'s time accumulation is an ODE state per member, so it integrates inside the
Runge–Kutta pair at the pair's order; the trapezium assembles across members at
the end.

The member loop is ~86% of an `f` evaluation, `O(M)`, one inner solve each.
`M` grows monotonically and members are never removed, so a run costs
`Σ over steps of M(t)` — 956 923 member evaluations at the operating point.
A creation early in the horizon sits in every subsequent step's loop: one at
`b ≈ 0` costs **367×** a forced stop at the same time, one at `b = 38` costs 5×.
The 44 creations below `b = 0.01` span 0.025% of the horizon and carry **45.5%**
of the total for **1.35%** of `J`; thinning them to every tenth leaves 54 nodes,
runs **2.09× faster**, and moves `J` by `+0.0032%`.

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
grid `Δ = 2^⌊log₂(0.2 t)⌋` clamped to `[1e-5, 2]`. Leg lengths span 1e-5 to 2,
five orders of magnitude; 44% of legs are shorter than one chain relaxation time
and together span 0.049% of the horizon, while the clamp makes the rest uniform.
The configured tolerance gives ~37 accepted steps per leg on a smooth record and
~105 on an intermittent one. The final step of each leg is clipped to the
boundary and does not update the carried step size. `h_init = h_min = 1e-6`,
`h_max = T`.

Step attempts over whole runs:

| outcome | smooth record | intermittent record |
|---|---|---|
| accepted | 3972 | 11 319 |
| accuracy rejection | 296 | 3471 |
| domain rejection (thrown) | 415 | 1069 |
| post-step refusal | 0 | 0 |
| committed at `h_min` | 0 | 0 |
| rejections / attempts | 15.2% | 28.6% |
| rate evaluations on rejected attempts | 8.4% | 24.4% |

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
| `𝒢_b` creation times | the quadrature over `μ_t` | a dyadic generator, then error-driven bisection | 108 |
| `𝒢_t` step times | the time integration | the controller above | 3972 smooth, 11 319 intermittent |
| `𝒢_f` record knots | the reconstruction of `s` | the input data's sampling rate | 14 599 |

`s(t)` is reconstructed by a shape-preserving `C¹` Hermite interpolant with a
Fritsch–Carlson limiter, a turning-point rule and flat-pair pinning. Over 972 726
evaluations it never leaves the range of the two control values bounding its span
by more than `1.4e-14`, and its integral matches the control points to `3.5e-12`
relative. It does not overshoot, it never evaluates negative on a non-negative
series, and the model's floor on `s` is dead with respect to the physics. `f''`
jumps at knots where `s ≠ 0` on at least one side, and integrating across one of
those costs nothing measurable: every step lying inside a single span is exact to
`2.6e-12`, because the estimator vanishes identically on a cubic.

Over quiescent stretches the reconstruction is identically zero, so the knots that
matter form a computable subset of `𝒢_f`: **2931 active knots** against 14 599 in
range, 0.26 per accepted step, 23.6% of accepted steps containing one. The
narrowest feature is a single wet day flanked by dry ones, two days wide at the
base, which puts the sampling bound at `h < 2/0.3 = 6.67` days. All of the lost
water is on steps crossing a daily control point; in an aligned run not one of
the 3444 steps spanning several control points carries any water at all
(`2.4e-18`), because every non-zero span is then bounded by two forced stops and
every water-carrying step lies inside one cubic.

The record is a mixture in time: quiescent stretches, stretches of many small
events, stretches of few large events, long absences. The local regime is a
deterministic function of the record, and the post-event relaxation rate follows
in closed form from the event size before the event arrives.

The refinement loop runs the model, flags nodes whose indicator exceeds a
threshold, bisects the interval below each flagged node, and repeats: 7–10 full
model evaluations, each schedule a strict superset of the last, insertion only.

Its threshold is `2e-2`, against the time integration's `1e-4`. On this record it
fires — the largest indicator reaches 0.31627 and 17 of 108 nodes are flagged —
and converges in seven iterations at 206 creations, `J = 12.6308272`, eight model
evaluations over 1417 s. Across those iterations the indicator falls 16× while
`J` moves `+0.368, +6.230, −0.713, −0.300, −0.707, +0.001, −0.000 %`, wandering
6% and ending 4.8% above where it started. The indicator is not monotone under
bisection, rising twice over seven refinements, and that survives pinning the
time grid exactly. On a smooth record the largest indicator reaches 0.0099 and
the refined grid equals the unrefined one.

Where it flags is not where the error is. All 17 flags fall at `b ≥ 6`, which is
the right region — the drop-one error on `J` totals 17.27% of `J` at 108 nodes
with 14.2% of it on four nodes at `b = 7, 8, 9, 10` — but the competition term
sets the maximum on 106 of 106 nodes and the reproduction term on none, nine of
the 17 sit at `b ≥ 16` where a node is worth under 0.2% of `J`, and the last two
iterations spend 399 s of the 1417 bisecting `b = 29.75`, worth `9e-10` of `J`.
Meanwhile 76 of the 108 nodes sit at `b < 1`, carrying 2.05% of the error.

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

Every number below is at `T = 40` on the record described above, at a trait
vector giving `J = 12.078` on a converged grid. M7 and M10 come from the
near-extinct operating point at `J = 1e-10` and say so.

**(M1) The functional is smooth in `θ`.** Scanned over 25 trait values spanning
±3% on a creation grid held fixed, aligned, one decade loose of the shipped
tolerance, `J` departs from a smooth quintic by **0.031% rms and 0.070% peak**
once one point of the 25 is set aside. That point is time integration: it sits
0.442% below the chord of its neighbours there, 0.005% at the shipped tolerance
and 0.001% one decade tighter. Lag-1 autocorrelation of the
residual is 0.09. The inner problem's classification holds across the scan — the
non-interior share spans 0.195 points, moves at most 0.099 points between
adjacent trait values, and correlates with the residual at −0.03. Smoothness is a
property of the operating point: at `J = 1e-10` the same scan reads 0.107% rms
with **two step discontinuities of 0.3–0.4%**, lag-1 autocorrelation 0.60, and a
classification swinging 0.671 points between trait values 0.25% apart.

**(M2) Step placement decides the answer, and the event stretch is the unit that
matters.** Forcing a step boundary at each of the record's 2931 active knots
moves `J` from 7.805 to 12.087 at the shipped tolerance — **−35.4% to +0.08%**
against the converged 12.0780. Two controls carrying the same 2931 stops
separate the mechanism. Stops
placed in quiescent spans, where the reconstruction is identically zero, take
9264 steps at a tolerance two decades loose and land **37.9% low**, against the
aligned arm's 8683 steps and +0.3%; across three decades that arm reads −37.9%,
−14.5%, +0.04%, while its state-clamping share holds at 0.490, 0.420, 0.392% and
the aligned arm's falls to 0.025%. Its right answer at the third tolerance is an
endpoint coincidence over a trajectory that disagrees. The same 2931 knots
shifted a quarter or half a day hold everywhere to **0.32%**, which the knots
themselves match at 0.31%. Landing inside an event stretch is the whole of the
effect.

The error is signed and monotone in tolerance, which excludes order reduction.
Unaligned it reads `−69.4, −56.5, −35.4%` across three decades of tolerance, reaching
−22% at a fourth with 61% more steps than the aligned run needs. One extra forced
stop **anywhere** in the run, over 16 placements tried, moves the functional
across 6.871 to 9.890 — a factor of 1.44 — and all sixteen land 18% to 43% below
the converged value. A stop after `t = 23.7` moves `J` by under 0.5%; one at
`t = 4.05` moves it 26.7%. The sensitivity sits where the creations are dense.
The one-sidedness follows from M12: a missed event is never a doubled one, so
2931 opportunities to drop water over forty years accumulate as bias.

**(M3) The placement error survives creation-grid refinement.** Unaligned against
aligned at the same creation count and the same tolerance: **−35.4 / −16.9 /
−39.9%** at 108 / 215 / 429 members. The gap halves from 108 to 215 and returns
to worse than it started at 429. Aligned, the functional holds to **0.29% across
four decades of tolerance** and is right at the loosest, at 9931 steps against
the unaligned run's 15 961 two decades tighter.

**(M4) A state-clamping branch is an artefact of placement.** One terminal branch
of the inner problem clamps state; the others move it continuously. Unaligned its
share is 0.38% and **does not respond to tolerance across three decades** —
0.357, 0.379, 0.362% — so it passes a convergence test by sitting still. Aligned
it falls to 0.025% and keeps falling: 0.081, 0.025, 0.0061, 0.0032, **0.0020%**
over four decades, while the solve count triples. The residue that survives
scales with member creations at four to five solves each and concentrates in the
first years — tracking creation density, not the forcing. The driest year in the
record carries 3 occurrences in 89 061 solves and one drought year none. Two
further terminal branches are exactly zero everywhere. Only the interior branch
and one active-constraint branch, occupied 4–13%, are genuinely visited. A
pinned step program takes it to exactly zero at every creation level over 28
million solves. The share does not track the functional: a five-day step
cap carries the **highest** share measured anywhere, 0.424%, while landing `J`
within 0.10% of converged. Placement drives both, and they are separate
consequences of it.

**(M5) The conditioning of a derivative is a property of the operating point.**
One census metric reads its density trait through two paths. Here their
elasticities are **`+0.159` and `+0.539`** — the same sign — the total `+0.699`
exceeds either, and the condition number `|direct| / |total|` is **0.2**. At a
horizon eight times shorter the two paths oppose: elasticities `+0.783` and
`−0.770`, a total 1% of either, a condition number of 63, and a reported
derivative carrying the **wrong sign** until one bisection later. Across
horizons 5, 10, 20 and 40 the condition number reads 10.3, 3.7, 0.6, 0.2, the
transported path changing sign between 10 and 20, so the short horizon sits on
this derivative's zero crossing. The amplification is exact wherever it
applies:
`err(total) = (|direct|/|total|)·err(direct) + (|swept|/|total|)·err(swept)`
reproduced the observed error at six creation counts across four orders of
magnitude and three sign changes, and the differentiation was never at fault —
at the level where the sign was wrong, the reverse sweep matched central
differences of whole re-runs to five digits and a forward tangent to ten.

**(M6) A finite-difference plateau exists one decade loose of the shipped
tolerance.** Aligned, at the tolerance where M3's four-decade hold begins, the
central difference reads

```
d      3e-2    1e-2    5e-3   2.5e-3   1e-3   3.16e-4  1e-4   3.16e-5  1e-5    1e-6    1e-7
dJ/dθ -158.66 -156.63 -154.05 -156.11 -151.65 -153.40 -154.12 -153.25 -151.67 -143.45 -187.79
```

— a plateau **three and a half decades wide, flat to 5.3%**, or to 4.6% with the
one pair that contains M1's time-integration point set aside, and flat to 1.6%
over its best two decades. Below `d = 1e-5` it breaks down. At `J = 1e-10` the
same instrument finds **no plateau at any `d`** from 1e-3 to 1e-9 at this
tolerance, and needs two further decades of ODE tolerance to produce one 1.5
decades wide. What sets the 1.6–4.6% floor here, and whether tightening narrows
it, is not measured.

**(M7) The derivative's convergence is not settled by differencing.** Measured at
the near-extinct operating point. Two independent ladders on aligned grids disagree. One
finds the value at ~1.9 and the derivative **not estimable** — level-to-level
spread 21%, the sequence reversing at four of six steps. The other reports a
persistent gap of 0.44–0.56 whose per-window values are 1.08/2.06 and 1.76/1.17,
and states that the design cannot separate an asymptotic order difference from a
coarse-end constant. **The adjoint, which forms no difference, gives derivative
orders of 1.29–1.91 against values at 1.31–1.94.**

**(M8) A census metric and its derivative are still moving at the operating
creation count.** Over 28 / 55 / 108 / 215 members they read 48.50, 51.21, 48.17,
46.68 and `5.719e-02`, `5.718e-02`, `5.529e-02`, `5.244e-02`: the last doubling
moves the value 3.1% and the derivative 5.2%, and neither sequence is monotone
through the first two levels. M16 gives the reason the non-monotonicity is not a
transient to be refined away.

**(M9) A program captured at the finer creation level transfers; one captured at
the coarser does not.** Captured at one level and replayed one level finer, `J`
is **−11.0%** wrong on a smooth record, and H2 says why: the captured program
lacks the finer level's 107 extra creation times, so they are inserted and the
realised grid takes 107 forced stops the record did not ask for — the step count
is exactly 107 above the captured program's. On an aligned intermittent record
the same design reads +0.025%. Captured at the finer level and replayed at the
coarser, which yields a bit-identical time grid because the levels are nested
bisections, `J` is **−0.019%** on a smooth record and +0.112% on an aligned
intermittent one; the same time grid at the two creation counts then differs by
0.52%, which is what M11's second-order creation-grid sequence predicts for that
bisection. The largest step per window is within 1.5× of adaptive at every level,
and the union of every level's program reproduces every adaptive answer to 1e-5
at 2.5–4.5× the steps. Derivatives, the union program and levels beyond two are
not measured here.

**(M10) Across `θ`, a captured grid holds a wide box.** Measured at the
near-extinct operating point. The full ±2× box in six parameters holds at a uniform step-shrink
factor of 2, and 58% of it at factor 1. Where a replay is wrong, `h·|λ|` on the
replayed trajectory is 1.7–3.2× above the adaptive run's. Across forcing records
there is zero transfer.

**(M11) The two `O(Δb²)` terms reinforce.** Under a smooth record the reported
error at the operating creation count is **−0.420%**, of which the forward
solve's creation-count error is **−0.334%** and the output trapezium's own error
on the same samples **−0.086%**: same sign, so the total exceeds either. Raising
the output rule's order alone takes the answer from −0.420% to −0.334%, **1.26×
better**. `J` converges at second order with alternating sign — level-to-level
changes `+1.4445, −0.2958, +0.0725`, `log₂` ratios 2.29 and 2.03 — so the
creation-count term reads −0.334%, +0.054%, −0.030% and no ratio between the two
terms is stable. Time integration is not involved: a decade of tolerance moves
`J` by 0.0000% at two creation counts. The sign of the pairing is a property of
the operating point: at `J = 1e-10` the two terms read `−0.617%` and `+0.359%`
for a total of `−0.259%`, held a ratio of `−0.582 / −0.581 / −0.580` at
successive levels, and a higher-order output rule made the answer 2.4× worse.

**(M12) The estimate vanishes on anything the stages resolve, and on anything
they miss.** One state accumulates the forcing alone, so a step on it is a pure
quadrature and the order conditions are readable directly. The fifth-order
increment reads `s` at `{0, 0.3, 0.6, 0.875}·h` and is exact to degree four. The
embedded difference reads `{0, 0.3, 0.6, 0.875, 1}·h` and returns `−1.0e-17` on a
cubic against `−6.8e-04` on a quartic — identically zero on degree three and
below. The widest gap between its abscissae is `0.3h`. So a reported zero has two
causes the controller cannot separate: the integrand was a cubic, and every
abscissa read zero while the interval held an event. Its response to a zero ratio
is to grow `h` by the clamp's maximum of five. Of the 70 steps carrying the
deficit the median size is 14 days, **89% begin after seven or more consecutive
dry days** (median 18, maximum 127), and the largest reported error ratio among
them is 1.071 against a tolerable 1.1.

**(M13) The threshold sits where the tableau puts it.** Capping `h` on the
unaligned grid, with no events and no knots: 30 days gives `−5.88%` of the water
and `J = 7.349`; 10 days `−2.30%` and `8.285`; **5 days `+0.0020%` and `12.099`**,
0.10% from the aligned answer; 2 days `−0.0037%` and `12.051`. A two-day feature
is guaranteed sampled once `h < 2/0.3 = 6.67` days, and the recovery appears
between the 10-day and 5-day caps. Restoring the water by any means restores the
functional. The same controller and tableau in isolation on `y' = s(t)`, at the
model's own control values, reads `−90%` to `−98.5%` across seven decades of
tolerance and does not improve monotonically; forced to the breakpoints it is
exact to `4e-12` with **zero rejections** at every tolerance.

**(M14) Rejections are not the channel.** A step holding an active knot is
rejected with probability 0.423 against 0.305 for one that does not — a ratio of
1.38, where a concentration would be the signature of a resolution failure at the
knots. Median distance from step start to the nearest active knot is 0.380 days
on rejected steps and 0.368 on accepted ones. Alignment cuts rejections from
4540 to 2603, 28.6% to 17.6%, and leaves the rest. Only **12.9% of the 70
water-losing steps** were preceded by any rejection, against 33.3% of steps
generally. The steps that lose the water are the quiet ones.

**(M15) The integrand is discontinuous, and the jumps are the record.**
`J = trapezium(b, w)` with `w` the member's survival-weighted offspring times a
patch density read at `b`. A newborn whose net production rate is non-positive at
creation is given establishment probability **exactly zero** and stamped with a
sentinel: log density `≈ −745` against `−9` at its neighbours, `w = 0` exactly,
leaf-area contribution 0 exactly. So `w(b)` is a positive O(0.1–1.5) envelope
times the indicator of a record-determined set. At 1/16-year creations over
`[5, 11]`, 23 of 103 nodes sit at the floor, in ten runs of 1 to 8 nodes; the
widest spans `b ∈ [7.375, 7.8125]`, inside a drought, with zero rain in the
preceding month at seven of its eight nodes. Across one band `w` reads 0.326,
0.388, **0 for half a year**, then **1.561**, 1.437, 1.317 — it jumps to its
largest value on the far side and decays at 8% per sixteenth-year. Rain in the 30
days before birth has median **0.00** at failures against **59.88** at survivors
(Wilcoxon `p = 6.5e-8`); at 90 days, 55 against 230 (`p = 4.6e-5`); at 180 days
the two are indistinguishable (`p = 0.27`). The soil state at the instant is what
the model reads, so this is association and not a window rule — but the
boundaries are computable before the run, because establishment probability is
pointwise in the environment.

**(M16) The creation ladder turns.** At `ode_tol = 1e-3`, 108 / 215 / 429 / 857
nodes give `J` = 12.0526222, 12.0888310, 13.0315024, 12.8432659 over 9931 /
10 174 / 10 816 / 11 351 steps. The successive differences are `+0.0362088`,
`+0.9426714`, `−0.1882365`: the second **26.0×** the first, the third
**−0.1997×** the second. A convergent trapezium sequence holds a ratio near
`2^{−p}`, so there is no `h^p` here and Richardson has nothing to work on. `J`
across the last three levels spans **7.80%**, with 429 the outlier. Tolerance is
not the cause: the same ladder a decade tighter reads 12.0873665, 12.1083840,
13.0342392, and the tolerance channel shrinks from `+0.288%` at 108 nodes to
`+0.021%` at 429. This is what a trapezium does over an integrand with jumps —
the error at a level depends on how that level's nodes straddle the bands of
M15, which does not vary smoothly with `h` under nested bisection. M11's ladder
is the control: under a smooth record, where no member fails to establish and
`w` carries no jumps, the same quadrature on the same coordinate converges at
second order with `log₂` ratios of 2.29 and 2.03.

**(M17) Placement decides the answer, and the integrand moves with the nodes.**
205 nodes at 1/16-year over `[5, 11]` with the default elsewhere give
`J = 12.606`; 215 uniformly bisected nodes give 12.089 — **4.3% apart at the same
count** — and the concentrated schedule agrees with the refinement loop's own
converged 206-node answer to **0.20%**. The node set also changes the function
being integrated: on one fixed time grid the abscissa channel is **`+6.19%`** and
the integrand's own dependence on the node set **`−12.76%`**, opposite signs with
the second larger and the product exact. Scored against a monotone interpolant of
429 samples at the current placement's own 6.19%, a graded mesh reaches it in
**17 nodes** and 15 uniform nodes on `[0, 12]` — 99.5% of `J` — clear it; at a
fixed 108 nodes, uniform placement is 18× and graded 48× better than the dyadic
generator. That scores the placement, and `w` is not a fixed function of `b`.

**(M18) Step insertion is not the mechanism.** Under H2 each schedule bisection
also inserts forced stops, so the two channels arrive together. Four instruments
separate them and put step insertion at **1–2%**. Capturing a step program at the
finest of a nested 108 / 215 / 429 ladder and replaying it at the coarser levels,
which gives a bit-identical time grid, leaves the creation channel at `+0.258%`
then `+7.669%` against the adaptive arm's `+0.300%` and `+7.798%`. The same
replay across the refinement loop's own eight levels reproduces every move. The
indicator on a pinned grid moves under 0.3% and changes **no** flag decision, and
its non-monotone rise survives. And 17 zero-depth stops placed at exactly the
midpoints the loop's first pass would insert move `J` by `+0.0050%`, against that
pass's `+0.368%`.

## Settled

Error shares between two grids of different order go in proportion to order,
from equal marginal error reduction per unit cost under power-law errors and
bilinear cost. M16 removes the premise on the creation side: its error follows no
power law, so the allocation has nothing to allocate between.

Raising the order of the output quadrature alone cuts its own term 148–258×.
Whether that helps turns on the sign of the creation-count term beside it. Here
the two reinforce and the substitution improves the answer 1.26×; where they
cancel it makes it 2.4× worse (M11). Both readings assume the integrand is
smooth between nodes, which M15 denies at the bands: a rule of any order
straddling a jump is `O(1)` in the jump.

Multirate collapses into a linearly-implicit treatment of the chain: the
expensive coupling term is a function of the fast variable, so every micro-step
re-evaluates the member loop. An additive split that keeps the member loop
explicit and evaluated once per stage is a different proposition and is not
excluded.

The max norm ranks honestly among the components whose error it can form. The
binding ranking is a tight cluster, and removing every member component from the
norm changes the accepted step count by under 1%. The forcing accumulator is
outside that: its error term is an exact zero on what the stages resolve and on
what they miss alike, so it binds none of the 11 319 accepted steps in either
arm, and no reweighting of the norm can give it weight.

## Questions

### 1. A step rule that samples a known record

The record is known in full before the run, and two caps on `h(t)` follow from it
with no solve. The sampling cap is `h < w(t)/0.3`, with `w` the local feature
width. The stability cap is `h ≤ β/(m·Λ(t))`, where `Λ` envelopes `|λ|` over the
record and an event of size `s` sets the chain's post-onset relaxation
`|λ_1| ≈ q·κ_1^{1/q}·s^{1−1/q}` before the event arrives.

(a) Is a grid built from the pointwise minimum of those two caps the right
object, and what does it guarantee about `dJ/dθ`?

(b) The blindness in M12 is structural to embedded pairs: the estimate is a
difference of two quadratures on shared abscissae, so it cannot see what neither
samples, and what it returns is an exact zero. What is the established treatment
for a right-hand side carrying a known exogenous forcing — a defect estimator
sampling off the stage abscissae, dense output checked against a finer rule, a
cap of the kind above, forced stops at the breakpoints? Which of them carries a
guarantee, and of what?

(c) A cap and a stop at each of the 2931 active breakpoints both recover the
functional to 0.1%. Is there a rule that places the fewest stops for a stated
sampling guarantee, and does it survive a record whose feature widths span orders
of magnitude?

(d) The forcing could instead be delivered as a sequence of instantaneous
impulses at the wet days, 1387 of them, which removes the quadrature entirely.
That changes the model: the existing impulse path bypasses a saturation-excess
partition that the continuous path applies, delivers at a higher peak, and
carries no error estimate. Is a formulation in which a known forcing enters as
measure rather than as rate the right move here, and what is the standard
treatment of its error?

### 2. A mesh for an integrand with record-located jumps

`J` is a trapezium over birth dates whose integrand is a positive envelope times
the indicator of a set the record determines (M15). Refining the count does not
converge it (M16), and the node set changes the integrand as well as the
abscissae (M17). Under H3 that node set is simultaneously the state dimension,
the adjoint's range count and the replay index, and under H2 every node is a
forced step boundary. Nodes are not free: cost is `Σ over steps of M(t)`, so an
early node is paid for across the whole remaining horizon and one at `b ≈ 0`
costs 367× a stop at the same time.

The construction in place is a clock-only generator, `Δ = 2^⌊log₂(0.2t)⌋`
clamped, which cannot see a drought; a monitor normalised by stand leaf area,
where leaf area is O(1) at `b = 30` and `w` is `1.3e-10`; and a threshold on an
absolute-value sum of signed local errors, reading 17.27% of `J` where `J` is
right to 0.08%.

(a) The jump locations are computable before the run. What is the right
construction for a mesh over an integrand with known discontinuities, given that
the integrand also depends on the mesh? Equidistribution under a monitor function
is the obvious family — which monitor, and what does it then guarantee?

(b) Does placing nodes at the jumps restore an order, and which? With the bands
resolved, is the remaining integrand smooth enough for a higher-order rule to pay
(M11 says it pays 1.26× where the integrand is treated as smooth)?

(c) The self-dependence is a fixed point: the mesh sets the canopy, the canopy
decides which cohorts establish, and that decides the integrand. M17 measures the
two channels at `+6.19%` and `−12.76%`. Does a mesh like this have to be iterated
to consistency, and what is known about the convergence of such a scheme?

(d) Cost scales with a node's remaining horizon. Does a cost-weighted
equidistribution have a clean form, and does weighting change the mesh a monitor
alone would choose?

### 3. A converged answer, and a derivative an optimiser can use

M16 leaves no reference: the creation sequence turns, so no level certifies
another and there is nothing to extrapolate. M8 has a census metric and its
derivative still moving 3.1% and 5.2% at the operating count. M6 gives a
difference plateau three and a half decades wide, flat to 1.6% over its best two.

The objective's jumps move with `θ`. M15's bands are where a newborn's net
production crosses zero, a condition reading the trait vector as well as the
record, so the set on which `w` vanishes moves as `θ` moves. The adjoint
differentiates the model at a fixed discretisation (H1) and carries no term for a
boundary whose location depends on `θ`. A cohort crossing into or out of
establishment between two trait values changes `J` by a finite amount the sweep
does not see.

(a) Is that omitted term the right reading, and what is the standard treatment —
a transport or shape-derivative term added to the adjoint, a smoothed
establishment of declared width, or a reformulation in which the probability
collapses continuously? A smoothed switch of width `ε` puts a feature of scale
`ε` into the integrand, which the mesh must then resolve, so `ε` is pulled small
by the bias budget and large by the node count. What sets it?

(b) With no convergent sequence, what certifies an answer? Is an a posteriori
bound available that does not assume a power law in the mesh?

(c) `dJ/dθ` drives descent steps. What relative accuracy suffices for a descent
method to make progress, and what does that requirement imply for (a) and (b)?

### 4. One grid across parameters and across records

A grid that does not move with `θ` is what H1 requires and what yields a usable
derivative. A captured one holds a ±2× box in six parameters at a uniform shrink
factor of 2 and transfers not at all across records (M10). Both caps in question
1 are computable for a whole parameter box from one reference run's flux
partition. The jump locations of question 2 are not: they move with `θ`.

(a) What certificate should accompany a shared grid when the quantity certified
is a derivative, given that the usual adjoint-weighted residual bounds the value?
Is a second-order object required, or is a cheaper sufficient condition
available?

(b) A grid fixed across `θ` must hold jump locations fixed while the true ones
move. Is that the dominant term in the trust region, and does it have a
computable bound over a parameter box?

(c) The record is fixed through a calibration and changes between them. Is one
designed grid per record, recaptured on certificate failure, the whole answer?

## Free

The record is known in full before the run, and so is every creation time. A
step boundary can be forced at any time with no member attached. The error
norm's derivative-weighted term is wired end to end and set to zero.
Instrumentation naming the component that set each step's size, and the outcome
of every step attempt, exists and is unread. Creation grids are supported
per-population independently. Dense linear algebra on the chain is free and its
Jacobian analytic.

The establishment boundaries are computable before the run from the record and
the trait vector, by the same pointwise function the model evaluates at a
creation. `h_max` is a live control and reaches the quantity that matters. The
instrumentation naming the binding component is overwritten by the retry, so it
reports the accepted attempt and not the rejected one.

The choice of grid is off the tape: it may depend on anything, including
quantities from a previous solve, subject to H1. The formulation may change if
the change is declared and its effect on `dJ/dθ` budgeted.
