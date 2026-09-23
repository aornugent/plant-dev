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

The integration runs on two grids — creation times `𝒢_b` and step times `𝒢_t` —
and neither may depend on `θ`. Choosing them, with stated guarantees, is the
question. Everything below explains a part of it.

The horizon is `T = 40`, where the trait vector used below gives `J = 12.078` and
the default birth rate makes `J` the net reproduction ratio directly, so the
stand is twelve times self-replacing. An earlier fixture at `T = 5` put a trait
vector at `J = 1e-10`, ten orders of magnitude short of replacing itself, and
several of its readings turned out to be properties of that horizon; where a
measurement below is still at `T = 5`, it says so.

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

Every number below is at `T = 40` on the record described above, at a trait
vector giving `J = 12.078` on a converged grid. M7 and M10 were taken at `T = 5`,
where `J` is 1e-10 and the stand is ten orders of magnitude short of
self-replacing, and have not been repeated; each says so.

**(M1) The functional is smooth in `θ`.** Scanned over 25 trait values spanning
±3% on a creation grid held fixed, aligned, one decade loose of the shipped
tolerance, `J` departs from a smooth quintic by **0.031% rms and 0.070% peak**
once one point of the 25 is set aside. That point is time integration: it sits
0.442% below the chord of its neighbours there, 0.005% at the shipped tolerance
and 0.001% one decade tighter. Lag-1 autocorrelation of the
residual is 0.09. The inner problem's classification holds across the scan — the
non-interior share spans 0.195 points, moves at most 0.099 points between
adjacent trait values, and correlates with the residual at −0.03. At `T = 5` the
same scan gave 0.107% rms, **two step discontinuities of 0.3–0.4%**, lag-1
autocorrelation 0.60, and a classification swinging 0.671 points between trait
values 0.25% apart. Near extinction `J` is a step function in `θ`; at a viable
stand it is not.

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
effect. At `T = 5`, with 412 knots in five years, the near-miss held to 2.6%
against the knots' 0.21% — a 13-fold gap that does not survive the longer record.

It is not order reduction, and it is not a flip. Unaligned, the error is signed
and monotone: `−69.4, −56.5, −35.4%` across three decades of tolerance, reaching
−22% at a fourth with 61% more steps than the aligned run needs. One extra forced
stop **anywhere** in the run, over 16 placements tried, moves the functional
across 6.871 to 9.890 — a factor of 1.44 — and all sixteen land 18% to 43% below
the converged value. A stop after `t = 23.7` moves `J` by under 0.5%; one at
`t = 4.05` moves it 26.7%. The sensitivity sits where the creations are dense. At
`T = 5` the same perturbation spanned a factor of three and straddled the
converged value in both directions: 2931 mis-integrations over 40 years
accumulate into a bias where 412 over five years averaged into a spread.

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
and one active-constraint branch, occupied 4–13%, are genuinely visited. At
`T = 5` a pinned step program took it to exactly zero at every creation level
over 28 million solves. The share does not track the functional: a five-day step
cap carries the **highest** share measured anywhere, 0.424%, while landing `J`
within 0.10% of converged. Placement drives both, and they are separate
consequences of it.

**(M5) The conditioning of a derivative is a property of the operating point.**
One census metric reads its density trait through two paths that oppose at a
short horizon. At `T = 5` their elasticities are
`+0.783` and `−0.770`, the total is 1% of either, the condition number
`|direct| / |total|` is 63 at the operating creation count, and the reported
derivative carries the **wrong sign** until one bisection later. At `T = 40` the
elasticities are **`+0.159` and `+0.539`** — the same sign — the total `+0.699`
exceeds either, and the condition number is **0.2**. Across patch lifetimes 5,
10, 20 and 40 it reads 10.3, 3.7, 0.6, 0.2, the transported path changing sign
between 10 and 20. `T = 5` is the zero crossing of this derivative in patch
lifetime. The amplification itself is exact wherever it applies:
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
over its best two decades. Below `d = 1e-5` it breaks down. At `T = 5` this
instrument had **no plateau at any `d`** from 1e-3 to 1e-9 at the shipped
tolerance, and two further decades of ODE tolerance bought one 1.5 decades wide,
flat to 0.63%. The plateau here appears a decade *looser* than the tolerance that
had none. What sets its 1.6–4.6% floor, and whether tightening narrows it, is not
measured.

**(M7) The derivative's convergence is not settled by differencing.** Measured at
`T = 5`; not repeated. Two independent ladders on aligned grids disagree. One
finds the value at ~1.9 and the derivative **not estimable** — level-to-level
spread 21%, the sequence reversing at four of six steps. The other reports a
persistent gap of 0.44–0.56 whose per-window values are 1.08/2.06 and 1.76/1.17,
and states that the design cannot separate an asymptotic order difference from a
coarse-end constant. **The adjoint, which forms no difference, gives derivative
orders of 1.29–1.91 against values at 1.31–1.94.**

**(M8) The operating creation count sits in the wrong place for a refinement
study.** At `T = 5` it sits above the noise floor: the error is ~1% there, one
bisection takes it to 0.27% — the size of the difference scatter — and orders are
readable only four halvings below. At `T = 40` it sits below convergence instead.
One census metric and its density derivative over 28 / 55 / 108 / 215 members
read 48.50, 51.21, 48.17, 46.68 and `5.719e-02`, `5.718e-02`, `5.529e-02`,
`5.244e-02`: the last doubling moves the value 3.1% and the derivative 5.2%, and
neither sequence is monotone through the first two levels.

**(M9) A program captured at the finer creation level transfers; one captured at
the coarser does not.** Captured at one level and replayed one level finer,
`J` is **−11.0%** wrong, and H2 says why: the captured program lacks the finer
level's 107 extra creation times, so they are inserted and the realised grid
takes 107 forced stops the record did not ask for — the step count is exactly 107
above the captured program's. Captured at the finer level and replayed at the
coarser, which yields a bit-identical time grid because the levels are nested
bisections, `J` is **−0.019%** on a smooth record and +0.112% on an aligned
intermittent one; the same time grid at the two creation counts then differs by
0.52%, which is what M11's second-order creation-grid sequence predicts for that
bisection. At `T = 5` those two arms read 18% and **11%**, the coarse-captured
one's derivatives came out sign-flipped, the largest step per window was within
1.5× of adaptive at every level, and the union of every level's program
reproduced every adaptive answer to 1e-5 at 2.5–4.5× the steps. Derivatives, the
union program and levels beyond two were not re-measured at `T = 40`.

**(M10) Across `θ`, a captured grid holds a wide box.** Measured at `T = 5`; not
repeated. The full ±2× box in six parameters holds at a uniform step-shrink
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
`J` by 0.0000% at two creation counts. At `T = 5` the same decomposition gave
`−0.617%` and `+0.359%` for a total of `−0.259%`, in a ratio of
`−0.582 / −0.581 / −0.580` at successive levels, and a higher-order output rule
made the answer 2.4× worse.

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

## Settled

Error shares between two grids of different order go in proportion to order,
from equal marginal error reduction per unit cost under power-law errors and
bilinear cost.

Raising the order of the output quadrature alone cuts its own term 148–258×.
Whether that helps turns on the sign of the creation-count term beside it: at
`T = 5` the two cancelled and the substitution made the reported answer 2.4×
worse; at `T = 40` they reinforce and it makes it 1.26× better (M11).

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

### 2. Certifying a converged derivative

M6 gives a difference plateau three and a half decades wide, flat to 1.6% over
its best two. M8 puts the operating creation count below convergence, the last
doubling moving the value 3.1% and the derivative 5.2%, with neither sequence
monotone through the first two levels. M11 has `J` converging at second order
with alternating sign. The creation grid's own indicator is the drop-one-point
Richardson estimate of the trapezium at a threshold of `2e-2` against the time
integration's `1e-4`; where it fires, it reports convergence while `J` still moves
by factors of 3.0–4.3 across iterations, and it is not monotone under bisection.

(a) What is the correct stopping rule for a refinement targeting a derivative?

(b) Under H3 the creation grid is the quadrature abscissa, the state dimension,
the adjoint's range count and the replay index at once, so one bisection changes
four things together. What instrument separates the quadrature's contribution
from the rest, and is the creation grid better treated as an adaptive quadrature
with the state dimension following from it?

(c) The sweep already forms `|direct|/|total|` and discards it. Is that a
sufficient a posteriori indicator of a derivative's conditioning, and what covers
a metric exposing no such decomposition?

### 3. One grid across parameters and across records

A grid that does not move with `θ` is what H1 requires and what yields a usable
derivative. A captured one holds a ±2× box in six parameters at a uniform shrink
factor of 2 and transfers not at all across records (M10, at `T = 5`). A grid
designed from the record has a different claim to make, and both caps in question
1 are computable for a whole parameter box from one reference run's flux
partition.

(a) What certificate should accompany a shared grid when the quantity certified
is a derivative, given that the usual adjoint-weighted residual bounds the value?
Is a second-order object required, or is a cheaper sufficient condition
available?

(b) Does computing the caps over a parameter box make the trust region in `θ`
statable in advance, and what does that miss?

(c) The record is fixed through a calibration and changes between them. Is one
designed grid per record, recaptured on certificate failure, the whole answer,
and does a designed grid have a provably wider validity region than a captured
one?

## Free

The record is known in full before the run, and so is every creation time. A
step boundary can be forced at any time with no member attached. The error
norm's derivative-weighted term is wired end to end and set to zero.
Instrumentation naming the component that set each step's size, and the outcome
of every step attempt, exists and is unread. Creation grids are supported
per-population independently. Dense linear algebra on the chain is free and its
Jacobian analytic.

`h_max` is a live control and reaches the quantity that matters. The
instrumentation naming the binding component is overwritten by the retry, so it
reports the accepted attempt and not the rejected one.

The choice of grid is off the tape: it may depend on anything, including
quantities from a previous solve, subject to H1. The formulation may change if
the change is declared and its effect on `dJ/dθ` budgeted.
