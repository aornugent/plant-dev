# Performance at fixed accuracy on a nested grid

## The whole thing

A stand of plants is integrated over forty years of a daily rainfall record on one
nested grid. Members — cohorts — are created at birth dates `b_j`. The birth dates
are the quadrature abscissae of every integral over the population, and forced
stops of a Cash–Karp 5(4) integration that also stops at each of the record's 2931
active knots. The functional is `J`, lifetime offspring production, a trapezium over
birth dates. `dJ/dθ` comes from a reverse sweep that is exact for the discretised
model, and drives a gradient-based calibration of `θ`, some twenty parameters.

The cost is member evaluations. At every rate evaluation each member solves a nested
root-finding problem for its stomatal operating point: 1.1e5 instructions, 20 µs.
That loop is ~99% of every rate evaluation. A run whose creation schedule is
`1.3e-4` from converged takes `1.9e7` member evaluations. What is wanted is that
count cut without losing accuracy in `J` or `dJ/dθ`, together with a construction of
the creation schedule that is fast to find and lean to run, for a given record and
across the `θ` an optimisation visits.

**The time step is not limited by accuracy.**
- The median accepted step carries 3% of its error allowance, and two decades of
  tolerance change the cost by 27%.
- The steps are set by three things:
  - the stops;
  - the explicit stability limit of two stiff modes: drainage of wet soil, `|λ|` up
    to `2.8e4` yr⁻¹, and the storage pool of the newest member, up to `1.4e3` yr⁻¹.
    Both are local, with cheap closed-form Jacobians;
  - a cycle in which that storage, far below `atol` and so invisible to the error
    norm, is driven negative by a stage and thrown.
- One attempt in five is rejected.
- By an offline bound, an integrator free of the two modes' stability limits would
  take up to 40% fewer steps and 33–51% fewer member evaluations.
- Tolerance also does not control `J`'s time error. `J` spreads `4e-4` across two
  decades of tolerance, not monotonically. A pure change of step placement moves it
  as much as a decade of tolerance does. Meanwhile stages overshoot into the soil's
  clamps and switches thousands of times per run.

**The creation schedule's error is the stand's, not `J`'s own quadrature.**
- At a coarse schedule, 96% of the error is every member's offspring responding to
  the competition integrals' quadrature.
- It is bought back by members created after the first drought, `b ∈ [6, 16)`,
  which carry 10.5% of `J`.
- The shipped refinement loop's indicator is a normalised drop-one error in leaf
  area. It puts 59% of its flags where refinement moves `J` by less than the
  step-placement floor, only inserts, and stops on a quantity `J` does not follow.
  At its tightest it reaches `5.6e-4` after eleven runs and `4.5e7` member
  evaluations.
- A first-order goal-oriented formula holds: `J`'s error is the trapezium defect of
  `g(b)`, the value of a newborn at `b` including its competition on everyone else.
  With `g` taken from a finer run it predicts coarse schedules' errors to 0.93–1.29×.
  Read off the coarse schedule's own members it fails (0.04×), because `g` swings over
  0.1–0.5 yr in the droughts.
- Every member created after `b = 0.65` lowers `J`.

**Across `θ`, the creation schedule transfers and the step program does not.**
- A lean schedule built at `θ0` holds ~`1e-3` over a box in which `J` varies 14×,
  with a gradient error under 0.1% along the leaf-mass axis.
- The dead bands' edges are the weather's and move under 0.09 yr across the box.
  Rebuilding the schedule at each `θ` makes it worse, because its error is set by
  where members fall against those fixed features.
- `θ0`'s step program pinned at other `θ` keeps `J` to `1.1e-3` but loses error
  control: it is 6× over tolerance 5% from `θ0`, and stages leave the model's domain.
- No cheap metric computed on the fixed grid tracks the error within a lean schedule.
- Step placement alone moves `J` by `6e-5` of itself (sd), a floor under any
  comparison of schedules at the operating tolerance.

The questions (at the end) ask for four things:
1. an integrator and controller that cut member evaluations at fixed accuracy;
2. a construction of the creation schedule to replace the refinement loop;
3. how one discretisation serves an optimisation across `θ`, and what certifies it;
4. what the adjoint should do in all of this.

## The system

```
u̇_ℓ          = (in_ℓ − K(u_ℓ) − a_ℓ) / Δz                          ℓ = 1…5 soil layers
in_1         = s(t) · max(0, 1 − (u_1/θ_s)^8),   in_ℓ = K(u_{ℓ−1})
K(u)         = K_sat · (clamp(u, 0, θ_s)/θ_s)^q                       q = 16.14
ξ̇_j          = G(ξ_j, u, L, p_j)                                     six states per member
d(log n_j)/dt = −μ(ξ_j, u, L, p_j)
Ḟ_j          = survival-weighted fecundity of member j
p_j          = argmax_ψ profit(ψ; ξ_j, u, L)                         the inner solve
Ė            = (γ(P_new) − E) / τ_g,   γ(P) = P²/(A² + P²) for P > 0, else 0
n_j(b_j)     = β(b_j) · E(b_j)
a_ℓ          = Σ_j ω_j n_j c_ℓ(ξ_j, u, p_j)                           trapezium over b
L(z)         = light at height z from Σ_j ω_j n_j A_j(z)              trapezium over b
J            = Σ_j ω_j β(b_j) π(b_j) S_D F_j(T)                      trapezium over b
```

**The soil.**
- Constants: `Δz = 0.3` m, `K_sat = 163.04` m yr⁻¹, `θ_s = 0.428`.
- A layer at or below `θ_res = 0.01` has its rate set to `max(0, ·)`.
- `s(t)` is the record's shape-preserving `C¹` Hermite reconstruction of daily
  values: 14 599 control points over the horizon, three multi-year droughts.
- Five accumulators beside the layers (rainfall, infiltration, deep drainage, total
  uptake, runoff) take their rates from `u` and `a`, and feed nothing back.
- Each member reads the soil only through the layers' water potentials `ψ_k(u_k)`,
  a power law capped at a maximum.

**The members.**
- Each carries six strategy states `ξ_j` (height, mortality, fecundity, heartwood
  area and mass, and a storage pool `S_j`), its log density, and `F_j`, its
  accumulated offspring.
- Members interact only through `a_ℓ` and `L`. Both are trapezia over birth date,
  closed at each time by a newborn at `b = t` whose density is `β(t)E(t)`.
- The light field is rebuilt at every rate evaluation.
- Members are never removed. The state grows by eight components per creation:
  3443 components at 429 members, against the soil's ten.

**The inner solve.**
- `p_j` is the root-collar water potential that maximises the member's profit. It is
  found by nested root-finding:
  - an outer TOMS748 root-find on the marginal profit, about 11 evaluations;
  - inside each of those, a root-find for leaf-internal CO₂ (about 6 iterations)
    and one for the stem potential;
  - about 50 evaluations of a five-layer water-supply function per solve.
- Its operating point is interior in 85% of solves and at the dry bound in 15%. The
  remaining terminal states (hydraulic shutdown, determined) are under 0.2%.
- `p_j` is `C⁰` across the switches between these classes.

**Establishment.**
- A member is created with density `β(b)E(b)`. `E` is the newborn's establishment
  gate `γ(P)` averaged over `τ_g = 0.05` yr, where `P` is a birth-size individual's
  net production in the current environment and `A` a fixed seed-scale constant.
- `E` is one state per species, started at its equilibrium.
- The gate opens over 40 days after rain (10–90%, median) and closes over 18 days as
  the soil dries.
- `P ≤ 0` holds in 56 dead bands spanning 14.7% of the horizon, the first at
  `b = 3.56`. Inside them `E` decays over the window.

**`J`.**
- `J` is offspring production, the net reproduction ratio at the default birth rate
  `β = 1`.
- `F_j(T)` is a per-capita survival-weighted offspring count, itself an ODE state.
  `π(b)` is the patch-age density at birth, and `S_D = 0.25` the dispersal survival.
- At the reference parameter vector `θ0` (leaf mass per area 0.32), `J∞ = 12.5734`:
  the stand replaces itself twelve times over.
- `θ` has ~20 components. The largest elasticities `θ/J · ∂J/∂θ` are:
  - `+51` for a co-limitation curvature at 0.99, bounded by 1;
  - `−7.8` for height at maturation;
  - `−7.1` for the leaf-mass-per-area column (`−4.2` for the trait, which also moves
    three leaf parameters);
  - `+6.5` for the stem's 50%-conductance potential;
  - `+5.5` for `V_cmax`;
  - `−5.1` for wood density.

## The discretisation

**One nested grid.**
- The creation times `𝒢_b` are the quadrature abscissae of `a_ℓ`, `L` and `J`, and
  forced stops of the integration: the state dimension grows at each.
- The step times contain `𝒢_b` and `𝒦`, the 2931 active knots of the record, where
  its reconstruction's second derivative jumps.
- A stop at each knot puts every step inside one cubic span of `s`, and makes the
  forcing's integral exact to `3.2e-12`.
- At 429 members there are 3358 legs between consecutive entries. Half are one day
  long (knots on consecutive wet days), and 10% are longer than 13 days.
- A knot is entered as a zero-depth rainfall pulse: it changes no state.

**The pair.** Cash–Karp 5(4), first-same-as-last. An accepted step costs six rate
evaluations. A rejected one costs six, or fewer if a stage throws: the stages up to
the one that throws.

**The controller.**
- Error ratio: `r = max_i |e_i| / (rtol·|y_i| + atol)`, with
  `rtol = atol = 1e-3` at the operating point.
- Reject when `r > 1.1`: `h ← h·max(0.2, 0.9 r^{−1/5})`.
- Accept when `0.5 ≤ r ≤ 1.1`, with `h` unchanged.
- Accept when `r < 0.5`: `h ← h·clamp(0.9 r^{−1/6}, 1, 5)`.
- A domain throw from a stage retries at `0.2h`.
- A step clipped to reach an entry does not update the carried proposal.
- `h_max = 5` yr and `h_min = 1e-6` yr.

**At every entry the rates are evaluated twice on the same state**, once by the
introduction and once by the solver's restart. Each leg restarts the step
sequence.

**Cost** is member evaluations: the sum over rate evaluations of the members held.
- An evaluation with `M` members costs about `1.12e5·M + 3e5` instructions.
- The member loop is 91% of it at 54 members, and ~99% at the operating run's mean
  of 216.
- The soil rates given `a` cost `1.4e3` instructions.

## The creation schedule as shipped

**The default generator** is dyadic, `Δ = 2^⌊log₂(0.2 t)⌋` clamped to `[1e-5, 2]`:
108 members, 44 of them below `b = 0.01`. It was designed for a quadrature in member
height, where early members spread apart quickly.

**The refinement loop:**
1. Run the model.
2. Compute, per member, a drop-one trapezium error on two terms:
   - a competition term: the leaf-area profile, sampled at each creation and
     normalised by the whole canopy;
   - a reproduction term: `J`'s integrand.
3. Flag each member whose larger term exceeds `schedule_eps = 2e-2`.
4. Insert a member at the midpoint of the interval below each flagged one.
5. Repeat, up to `schedule_nsteps` runs.

It only inserts.

## The adjoint

- `dJ/dθ` comes from a reverse sweep over a recording of the forward run, one row per
  accepted step. The sweep differentiates the recorded steps with the inner solve's
  recorded operating points held.
- It is exact for the discretised model: `2.1e-8` against a forward tangent over 22
  parameters.
- A creation time or step size that depends on `θ` contributes a term that is not
  computed. So within one gradient the grid is a constant.

## Measured

Unless stated, every measurement is at `θ0`, `rtol = atol = 1e-3`, with a stop at
every active knot. Two schedules recur: `u429`, 429 members uniform over
`b ∈ [0, 39.63]`; and `d108`, the default. Relative errors are against `J∞`. Counts
are the cost measure: accepted steps, attempts, and member evaluations; `Σ M` is
the sum over accepted steps of the members alive.

### The time grid

Every rejected attempt below was recovered exactly, by replaying each run's steps
outside the solver bit-identically; the recovered counts equal the solver's own
tallies on every run replayed.

**(T1) The step is not limited by accuracy.** The median accepted step carries
an error ratio of **0.030** (`u429`) and 0.040 (`d108`), against the acceptance
bound of 1.1; 8–10% of steps reach 0.5. From `tol = 1e-2` to `1e-4` accepted
steps scale as `tol^−0.065`, member evaluations as `tol^−0.049`: two decades of
tightening cost **+27%**, where an accuracy-limited fifth-order step scales as
`tol^−0.2`. The median step is 0.56 days, the 90th percentile 3.2 days.

| `u429` | first 3.5 yr | wet years | drought years | all |
|---|---|---|---|---|
| accepted steps per year | 303 | 303 | 204 | 281 |
| members held, mean | 18 | 240 | 224 | 216 |
| median step, days | 0.39 | 0.49 | 1.00 | 0.56 |
| median error ratio | 0.056 | 0.034 | 0.013 | 0.030 |

**(T2) Four things shorten the step.**
- *Stops.* 30% of accepted steps are clipped to reach a knot or a creation, to a
  median **0.33** of the controller's proposal (quartiles 0.15–0.59). The 3358
  legs between entries take 3.35 accepted steps on average; 32% are taken in
  one.
- *Soil drainage at its stability boundary* (T3).
- *A cycle of domain throws on the newest member's storage* (T4).
- *Rejections*, which cost the steps after them (T4).

The component attaining the error ratio's maximum is a soil layer at **75.7%** of
accepted steps (the deepest layer alone at 31%), a member state at 22.8% —
mostly the newest member's mortality — and `E` at 1.5%. The accumulators never
bind at `atol ≥ 1e-4`.

**(T3) Two stiff modes, both local.** The soil chain's Jacobian with `a` held is
lower bidiagonal, with diagonal `−q·K_sat·(u_ℓ/θ_s)^q/(u_ℓ·Δz)`: **`2.05e4` yr⁻¹
at saturation**, a relaxation time of 26 minutes, falling as `u^15.1`. The
uptake coupling adds a median `1.4e-4` of that diagonal, and dominates only in dry
layers, which never carry the dominant mode. The second mode is a member's
storage relaxation, `Ṡ = charge·(1 − S/S_max) − drain·S/S_max`, at 150–1444 yr⁻¹,
belonging to the newest member at 84% of steps and to one of the newest three at
100%. The exact Jacobian of the whole system, at 100 sampled states, has as its
dominant eigenvalue the larger of those two, to 0.92–1.0002.

| `u429` | value |
|---|---|
| soil `|λ|max`, yr⁻¹: 25 / 50 / 75 / 90% / max | 70 / 725 / 3197 / 7392 / 28 300 |
| `h·|λ|soil/β`: 25 / 50 / 75 / 90% / max | 0.065 / 0.44 / 0.78 / 1.01 / 1.91 |
| accepted steps at `h·|λ|soil ≥ 0.8β` / above `β` | 23.7% / 10.3% |
| controller-ended steps at `≥ 0.8β` | 31.4% |
| sampled controller-ended steps at `≥ 0.8β`, whole system | 34% |

`β = 3.7343596` is the fifth-order increment's real stability boundary. The
median error ratio rises with `h·|λ|/β`: 0.007 below 0.5, 0.072 at 0.5–0.8,
0.20 at 0.8–1.0 and 0.28 at 1.0–1.2.

**(T4) One attempt in five is rejected, one rejection in three by a throw.**

| | `u429` | `d108` |
|---|---|---|
| attempts | 14 280 | 12 360 |
| rejected for accuracy / thrown | 1891 / 1150 | 1916 / 528 |
| rejected share of attempts / of member evaluations | 21.3% / 17.0% | 19.8% / 16.9% |

- *Accuracy rejections* come from a soil layer in 1858 of 1891 cases. 59% are
  attempted at `h·|λ|soil ≥ 0.8β`. The rest cluster on the first step after a
  knot at which rain is falling: **47 rejected attempts per 100 such steps**,
  against 27 after a dry knot and 23 mid-leg.
- *Throws* all carry one message, a negative storage caught by the guard
  `S < −1e-8·S_max`. The storage is the newest member's in 79%, aged a median
  0.047 yr, holding a median `5.3e-8` kg — below `atol/100` at every accepted
  step of the run. Its weight in the error norm is therefore `atol` alone: a
  100% error in it contributes a ratio of `5e-5`. The proposal grows while the
  ratio stays small, past that member's storage stability boundary (median
  `1.69β` at the throwing attempt), until a stage at `0.6h` or `h` drives the
  storage negative. The retry at exactly `0.2h` is accepted, and the growth
  repeats: successive throws in a leg are 1–3 accepted steps apart, 4.3 per leg
  over 268 legs.

**(T5) Tolerance does not control `J`'s time-integration error.** On `u429`:

| `tol` | `J` | against `1e-4` | accepted | rejected (thrown) | member evaluations |
|---|---|---|---|---|---|
| `1e-2` | 12.577170485 | +1.66e-4 | 9 991 | 25.6% (1740) | 1.775e7 |
| `3e-3` | 12.576132363 | +8.4e-5 | 10 527 | 24.3% (1388) | 1.866e7 |
| `1e-3` | 12.575093099 | +1.3e-6 | 11 239 | 21.3% (1150) | 1.934e7 |
| `3e-4` | 12.572169221 | −2.31e-4 | 12 240 | 18.7% (772) | 2.054e7 |
| `1e-4` | 12.575076980 | 0 | 13 463 | 18.2% (508) | 2.247e7 |

The spread is **4.0e-4 relative**, not monotone, and 3.1× the creation
schedule's own error at 429 members (`1.3e-4`). Holding `rtol = 1e-3` and
sweeping `atol` over `1e-5 … 1e-2` spreads `J` by 5.3e-4, also not monotone. The
differences accrue over years 12–25, as yearly changes of either sign up to
`1.5e-4`, and are carried by members created before `b = 3.5` (88% of `J`) and
at `b = 7–10` (8.8%). On `d108` `J` moves monotonically, +0.21%, +0.14% and
−0.11% at `1e-2`, `3e-3` and `1e-4` against `1e-3`.

**(T6) Step placement moves `J` as much as a decade of tolerance.** Adding 428
zero-depth stops at the birth dates the next uniform level would add — step
placement changes, members do not — moves `J` by **+1.65e-4**, what `1e-3 → 1e-2`
moves it. The difference accrues over years 12–23. At the knots, which both runs
land on, soil moisture differs by up to `2.7e-3` and member log densities by up
to 0.015. No accepted step ends with the top layer past the saturation-excess
switch at any `tol ≤ 3e-3`, but stages cross it, and cross the soil
clamps, inside the steps:

| stage evaluations beyond | `tol 1e-2` | `3e-3` | `1e-3` | `3e-4` | `1e-4` |
|---|---|---|---|---|---|
| the saturation-excess switch | 2998 | 1650 | 935 | 563 | 322 |
| the conductivity clamp `[0, θ_s]` | 16 410 | — | 3894 | — | 1215 |
| the moisture floor `θ_res` | 3760 | — | 962 | — | 292 |

The inner solve's terminal classifications move the same way: over the forward
run, hydraulic-shutdown solves fall 5.4× and "determined" solves 83× from
`1e-2` to `1e-4`, and the added zero-depth stops alone cut them 9.3% and 5.4%.

**(T7) The stops.** Without them `J` is **−22.3%**, the deficit accruing from year
12: the tableau's abscissae `{0, 0.2, 0.3, 0.6, 1, 0.875}·h` step over rain
events narrower than `0.3h`, and the embedded estimate vanishes on them. A cap
`h ≤ 5` days in place of the stops leaves −0.45%. The stops add 866 accepted
steps against the unstopped run and remove 631 attempts, rejections falling from
30.4% to 21.3%. Each of the 3358 entries costs two rate evaluations, 7.5% of all
member evaluations.

**(T8) What an integrator free of the two stiff modes could save.** An offline
bound from the recorded runs at `tol = 1e-3`, keeping the accuracy limit and every
entry. Each accepted step was re-taken and its error ratio recomputed without the
soil layers and members at `h·|λ| ≥ 0.5β`; its local limit is `h·max(1, min(5,
0.9 r^{−1/5}))`, the floor at `h` because every measured step was admissible;
each leg is filled with `⌈∫dt/limit⌉` steps. No rejection, no throw, the same
members per leg, the error scaling as `h⁵`, the stiff components imposing no
accuracy limit of their own, and no added cost per evaluation.

| `u429` | accepted steps | member evaluations saved |
|---|---|---|
| measured | 11 239 | — |
| the stiff components out, the controller's own walk (×5 growth, proposal carried across clips) | 8 887 | 32.8% |
| **the stiff components out, filled** | **6 722** | **47.5%**; 51.2% with one evaluation per entry |
| one step per leg, the floor the stops set | 3 358 | 69.9%; 73.7% |

Of the filled estimate's 51.2%: 30.5 points are accepted steps (21.3 from the
stability credit), 17.0 rejections (4.3 throws, 7.5 accuracy rejections at
`≥ 0.8β`, 5.2 on first steps after rain) and 3.8 the second evaluation at each
entry. **33.1 points are attributable to the two stiff modes; 18.2 need no stiff
treatment.** Wet legs (daily knots) hold 15% of the time and 59% of the cost and
would save 43% of it, half in accuracy rejections; dry legs would save 63%,
mostly stability credit and throws. With no evaluation at a knot, where a
zero-depth pulse changes no state, the filled estimate saves 54.5%.

**(T9) The gradient against the time grid.** On `d108`, from `tol = 1e-3` to
`1e-4`, `dJ/dlma` by the adjoint moves −158.593 → −158.898 (+0.19%) while `J` moves
−0.11%; the window's column moves −4.5%. At `1e-2` and `3e-3` the adjoint refuses
every metric: a stage state lies past the domain of the stem vulnerability
curve's derivative series, `(ψ/b)^c = 27 222` against a domain edge of 4.6.

### The rate evaluation

**(R1) The member loop is the cost, and inside it the inner solve.** Instruction
counts under callgrind on a five-year cut of the operating run (54 members):

| part | share |
|---|---|
| member rates | 90.97% |
| · the inner solve | 84.90% |
| · the crown's light quadrature | 2.25% |
| the newborn (the boundary member and `E`: two inner solves per evaluation) | 6.51% |
| the light field | 1.46% |
| the uptake sums `a_ℓ` | 0.41% |
| soil rates | 0.04% |
| solver arithmetic and the controller | 0.25% |

An evaluation with `M` members costs `≈ 1.12e5·M + 3e5` instructions: the member
loop is ~99% at the operating run's mean of 216 members. A member evaluation is
**20.2 µs** on a quiet core; 47 k instructions where 46% of solves end at the dry
bound, 107–109 k elsewhere. Inside the inner solve, a five-layer supply function
takes 28% of every instruction the run executes. A member's cost does not depend
on its density.

**(R2) No member is dead, but most are sparse.** Members are never removed and
every one is evaluated in full. No member of the operating run falls below `10^−8.39` of the peak member density at any step, so
no evaluation goes to a member of zero weight; 41.0% of accepted-step member
evaluations go to members below `1e-3` of the peak and 3.9% below `1e-6`. The
share below `1e-3` rises from 0 in the first five years to 63.6% in the last
five.

| birth band (yr) | `[0, 3)` | `[3, 10)` | `[10, 20)` | `[20, 30)` | `[30, 40]` |
|---|---|---|---|---|---|
| share of member evaluations | 14.6% | 28.5% | 31.2% | 19.0% | 6.8% |

**(R3) Where the multirate attempts spent their evaluations.** Measured on other code
versions and fixtures, not the operating run:

| attempt | measured |
|---|---|
| multirate infinitesimal (MRI) step, soil fast, members slow | each fast evaluation re-runs the member loop; ~10 micro-steps per macro step; 6–25× the cost of the single-rate pair at converged `J` |
| exact drainage split inside the fast step | more micro-steps (103 against 58 per macro step), 0.6× the speed |
| the fast coupling from `m ≪ M` members | `m = 20`: 14% `J` error at `M = 352`; `m = 40`: 2.4% at 2× the cost |
| the coupling held, linearised or tabulated over a macro step | held: error plateau 0.1; linearised: up to 440% uptake error on a drying profile |
| fast soil against an affine coupling `a₀ + G(u − u₀)`, `G = ∂a/∂u` exact | constant rain: 40× fewer member sweeps; seasonal: 3.8× at `3.5e-3` `J` error, 1.0× at `≤ 4e-4` |
| IMEX: Rosenbrock on the soil block, Jacobian differenced through the full rates | 19 member-loop evaluations and a dense full-size factorisation per step; 20–50× slower |

No attempt kept the member loop explicit and evaluated once per stage with the
soil implicit.

**(R4) What exists for implicit integration.** A Rosenbrock stepper, RODAS4(3),
exists in the integration library with a forward-mode AD Jacobian (one tangent rate
evaluation per state column, 3443 at 429 members) and a dense LU; the model's
driver cannot select it, and it has no adjoint: its stage recurrence would need
`Wᵀ` solves, second derivatives of the rates through the member loop along the
stage vectors, and a per-stage record of the inner solves' operating points,
which the recording's six-evaluation shape does not hold. The soil chain's
Jacobian is closed-form (T3) and formed nowhere. The soil rates given `a` are a
separate function, 1.4 k instructions, and setting the soil state alone is a copy.
`∂a_ℓ/∂u_k` is, per member, a rank-one term through the inner solve's optimum plus
a diagonal — a dense 5×5 summed over members — available only as forward tangents
at 1.96× a member evaluation per direction. The soil rate is non-smooth at the
moisture floor, the conductivity clamp, the potential's floor and cap, and the
infiltration `max(0, ·)`. A knot is a state jump of zero size at a leg start, and
every leg restarts the step sequence.

### The creation schedule

Relative errors in this section are against `J∞ = 12.573422`, the order-3
extrapolation of uniform 429, 857 and 1713.

**(S1) Step placement sets a floor under the schedule's error.** Moving every
member of `u429` except the first by `1e-5`, `3e-5` or `1e-4` yr changes `J` by
+6.5e-5, −5.9e-5 and −6.2e-5 of itself: **sd 6.0e-5** over four runs, range
1.27e-4. The trapezium's own share of those moves is 6e-7 to 6e-6; the rest is the
controller placing its steps elsewhere once the creation stops move (T6). At
`tol = 1e-3` a schedule error below about `1e-4` is not attributable to the
schedule, and `J∞` is not established below it.

**(S2) Where `J` sits and where the cost sits are different places.**

| birth band | share of `J` | member cost / mean member | share of `Σ M` |
|---|---|---|---|
| `[0, 1)` | 0.719 | 1.93–1.95 | 0.05 |
| `[1, 3.56)` | 0.162 | 1.86 | 0.12 |
| `[3.56, 6)` | 0.0125 | 1.72 | 0.11 |
| `[6, 10)` | 0.0931 | 1.56 | 0.16 |
| `[10, 16)` | 0.0119 | 1.33 | 0.20 |
| `[16, 22)` | 0.0012 | 1.05 | 0.16 |
| `[22, 40]` | 3.6e-5 | 0.47 | 0.21 |

`w(b)` falls from 16.9 at `b = 0` by half every 0.35 yr. Past the first dead band
its largest value is 1.28, at `b = 7.96`: recruitment after the first drought. A
member created at `b = 0` costs 1.98× the mean member at every uniform count from
108 to 1713.

**(S3) The error is the stand's response, not `J`'s own trapezium.** Uniform 215
reads `+1.38e-2`. Split at each of its nodes into the trapezium's error on the
converged run's integrand and the change in the integrand itself, **96% is the
stand's response**: under the coarser schedule, members created before `b = 16`
have 1.1–2.7% more lifetime offspring. Where `w` is smooth, before `b = 3.56`, the
trapezium's local term `(Δb³/12)·w''` predicts the trapezium's own error to
0.6–9%. Past it, over `[3.56, 16)`, the panel errors are one to two orders larger
than the local term and cancel between panels: at 34-day spacing the gate's
openings (40 days, 10–90%) and closings (18 days) are not resolved.

**(S4) Accuracy is bought in `[6, 16)`.** Adding `u429`'s midpoints to uniform 215
one birth band at a time — the fills sum to within 2.9% of the whole 215 → 429
change:

| band filled | members added | `ΔJ` | trapezium | stand | added `Σ M` | share of the 215 → 429 change |
|---|---|---|---|---|---|---|
| `[0, 3.56)` | 19 | −0.0083 | −0.0363 | +0.0280 | 196 382 | 4.8% |
| `[3.56, 6)` | 13 | +0.0006 | −0.0009 | +0.0015 | 123 562 | −0.4% |
| **`[6, 10)`** | 22 | **−0.0955** | +0.0377 | −0.1332 | 188 749 | **55.4%** |
| **`[10, 16)`** | 32 | **−0.0791** | +0.0069 | −0.0860 | 241 453 | **45.9%** |
| `[16, 40)` | 128 | +0.0050 | −0.0002 | +0.0052 | 473 766 | −2.8% |

The members created in `[6, 16)` carry 10.5% of `J`; the `J` they move is that of
the members created before them, through competition. Removing `u429`'s 64
members strictly inside the 56 dead bands, where the gate is shut but `E` decays
over the window, reads **−7.29e-2**. Thinning uniform 215's members past `b = 22`
to one per 2 yr moves `J` by −1.48e-3, where those members carry 3.6e-5 of it.

**(S5) The refinement loop, on the averaged model.** From the default schedule:

| `schedule_eps` | runs | members | relative error | `Σ M`, last run | `Σ M`, all runs |
|---|---|---|---|---|---|
| 2e-2 | 6 | 178 | −1.32e-2 | 1 392 441 | 7 316 788 |
| 2e-3 | 8 | 390 | −2.31e-3 | 2 671 747 | 15 342 593 |
| 2e-4 | 11 | 957 | −5.60e-4 | 6 392 986 | 44 798 127 |
| 2e-2, from uniform 108 | 4 | 140 | +1.17e-2 | 800 876 | 2 863 276 |

Read term by term, every flag in every loop is the competition term's: the
reproduction term exceeded the threshold at 146 flagged members, always beside
the competition term, and never alone. 59% of the 1233 flags fall past `b = 16`,
where the fills of S4 move `J` by less than S1's floor; 32% in `[6, 16)`; 6% before
3.56. The indicator falls at every bisection, and `J` does not follow it: at
`2e-2` the loop passes within 4.7e-3 of `J∞` at its third run and stops at −1.32e-2;
at `2e-3` it passes −2.6e-4 at its fifth and stops at −2.31e-3. The 44 default
members below `b = 0.01` stay in every final schedule.

**(S6) Fixed designs, and what finding them costs.** Each built at the reference
parameter vector, then run on its own adaptive steps:

| design | members | relative error | trapezium / stand | `Σ M` |
|---|---|---|---|---|
| uniform | 250 / 320 / 380 / 429 / 857 | +1.9e-3 / +6.65e-3 / −8.7e-4 / +1.33e-4 / +1.6e-5 | — | 1.39 / 1.79 / 2.14 / 2.43 / 5.03 M |
| cost-weighted from one uniform-108 pilot: density ∝ `(|w''|/12 / member cost)^{1/3}` | 60 / 100 / 150 / 180 / 220 / 320 | +2.0e-2 / +7.1e-4 / +2.1e-3 / −4.0e-3 / −5.4e-4 / −9.3e-5 | trapezium within ±3e-3 throughout; stand +2.3e-2 / −1.8e-3 / +2.2e-3 / −3.6e-3 / −8.4e-4 / −5e-6 | 0.43 / 0.76 / 1.19 / 1.44 / 1.76 / 2.63 M |
| the same from a uniform-215 pilot | 100 / 220 | −6.6e-3 / −2.4e-3 | | 0.75 / 1.74 M |
| uniform to `b = 22`, one member per 2 yr after | 150 / 220 / 320 | −9.0e-3 / −2.9e-3 / −9.0e-4 | | 1.06 / 1.59 / 2.35 M |
| from the rainfall record alone: the empty patch's soil moisture per unit member cost (the empty patch's gate is flat, 0.9978–0.9979) | 150 / 320 | +1.7e-2 / −1.8e-2 | | 0.68 / 1.50 M |
| halved spacing on `[6, 16)` from the fills, graded tail | 150–240 | −3.1e-3 to −1.8e-3 | | 1.01–1.65 M |

| target | least `Σ M`, any design | least `Σ M` from which every larger run of the design stays under | uniform |
|---|---|---|---|
| 1e-2 | 0.76 M (cost-weighted 100) | 0.76 M | 1.39 M (250) |
| 1e-3 | 0.76 M (cost-weighted 100) | **1.76 M** (cost-weighted 220) | **2.14 M** (380) |
| 1e-4 | 2.63 M (cost-weighted 320), inside S1's floor | — | 5.03 M (857), inside the floor |

Every design's error in the 0.7–1.8 M range is a trapezium term and a stand term
of `±(1–8)e-3` whose signs follow where members fall relative to the gate's
openings and closings; none is monotone in the member count. The cost-weighted
design costs one pilot run (0.58 M) to find; found and used once it costs 2.34 M
at its first count that stays under `1e-3`, against 2.14 M for uniform 380. The
refinement loop at `2e-3` costs 12.7 M to find a schedule that ends at −2.3e-3.

**(S7) The schedule sets `M`; the steps barely move.** Along the uniform ladder
accepted steps are `10 732 + 0.95 × members`; creations end 1.0% (108 members) to
14% (1713) of steps, the rainfall stops 24–30%. Over 57 runs of 100–440 members
steps range ±6.3% while `Σ M` ranges 5.7×. At equal count a schedule with fewer
late members takes fewer steps: a member costs 1–2 steps where it joins members
at 34–68-day spacing and up to 15 where it falls in a 1–2 yr gap.

### Across the parameter vector

A discretisation built at the reference `θ0` read at other `θ`. Three axes: leaf
mass per area (a trait mapped to four parameters), height at maturation `hmat`,
and the stem's 50%-conductance potential `stem_P50`, the two parameters of
largest elasticity after one bounded at its limit. Eleven points:
`lma × {0.7, 0.85, 0.95, 1.05, 1.15, 1.2}`, `hmat × {0.8, 1.1}`,
`stem_P50 × {0.9, 1.25}` and `θ0`. `J` spans 3.68–52.1 over them; beyond
`lma × 1.35`, `hmat × 1.25` or `stem_P50 × 0.8` the species does not replace
itself (`J < 1`). The node schedules are held fixed; the steps are adaptive at
each `θ` unless pinned.

**(Θ1) The reference is not uniformly good.** Uniform 429 against uniform 857:
+1.2e-4 at `θ0`, **−1.70e-3 at `lma × 0.7`**, −6.8e-4 at `lma × 1.2`. Below about
`1e-3`, errors away from `θ0` are resolved only at those three points.

**(Θ2) A lean node schedule fixed at `θ0` holds across the box.** `lean180` is a
cost-weighted design (density `∝ (|w''|/c)^{1/3}`, `c(b)` the accepted steps after
`b`) read off `θ0`'s uniform-857 run; the `cw108` designs are S6's.

| schedule | `e/J` at `lma × 0.7` / `θ0` / `lma × 1.2`, against 857 | gradient error, lower / upper half of the `lma` axis | `|e|/J`, all 11 points, against 429 |
|---|---|---|---|
| default 108 | −9.33e-2 / −3.63e-2 / −2.25e-3 | **−12.1% / −5.0%** | up to 1.2e-1 |
| uniform 215 | +1.25e-2 / +1.38e-2 / +1.82e-2 | +1.19% / +1.20% | 1.9e-3 – 1.9e-2 |
| uniform 429 | −1.70e-3 / +1.17e-4 / −6.79e-4 | −0.26% / +0.04% | (the reference) |
| **lean180** | **+5.9e-5 / −8.5e-4 / −8.8e-4** | **+0.05% / −0.08%** | ≤ 2.8e-3 |
| cw108_100 | −2.14e-3 / +7.0e-4 / +4.70e-3 | −0.35% / −0.10% | ≤ 5.4e-3 |
| cw108_220 | −2.13e-3 / −5.6e-4 / −3.7e-4 | −0.29% / −0.06% | ≤ 1.04e-3 |

The gradient error is the secant of `e` over the secant of `J` across each half of
the `lma` axis — what an optimiser differencing that schedule would see; `J` falls
10.5× along it. On the `stem_P50` axis the default 108's reaches **+21.8%**, and
every lean schedule's stays at or under 0.61%, the reference's own resolution.
The default 108's error doubles by `lma × 0.7`, passes through zero and reaches
+12% at `stem_P50 × 1.25`.

**(Θ3) Rebuilding the recipe at `θ` is worse than keeping `θ0`'s.** The same recipe,
rebuilt from `θ`'s own pilot at the same member count, moves members a median
0.5–0.9 yr and reads, against 857:

| | fixed at `θ0` | rebuilt at `θ` |
|---|---|---|
| `lean180`, `lma × 0.7` / `× 1.2` | +5.9e-5 / −8.8e-4 | −2.19e-3 / −2.45e-3 |
| `cw108_100`, `lma × 0.7` / `× 1.2` | −2.14e-3 / +4.70e-3 | −7.76e-3 / +7.42e-3 |

**(Θ4) The gate's edges are the weather's.** The dead bands' edges — stretches
where `w` sits a decade below its running maximum — move by at most **0.089 yr**
across the box, less than one uniform-429 spacing (0.093), with median shifts of
0.001–0.015 yr. What moves is the weight `w` puts on and around them: the birth
date by which 99% of `J` is created moves −1.22 to +2.31 yr, and `w/J` moves a
total-variation distance of 0.02–0.14. At `stem_P50 × 1.25` the regime changes:
2 of `θ0`'s 9 bands remain deep enough to count, and the reference takes 53% more
steps.

**(Θ5) A pinned step program keeps `J` but not its error control.** `lean180` run
at each `θ` with its steps pinned to `θ0`'s 10 349 step times: `J` is within
**1.1e-3** of the adaptive run at every point, no run fails, and the pinned run is
15% cheaper (no rejected attempts). A pinned step forms no error estimate: the
embedded difference is computed and never weighted, and the controller is not
called. Re-formed outside the solver, and validated on `θ0`'s adaptive run
(median relative difference `1.9e-8`, the same largest ratio 1.0976):

| point | `(J_pinned − J_adaptive)/J` | largest error ratio | steps over 1.1 | steps whose stages leave the model's domain |
|---|---|---|---|---|
| `θ0` | +9.3e-7 | 1.10 | 0 | 0 |
| `lma × 0.95` / `× 1.05` | −1.7e-4 / +4.9e-4 | 6.65 / 6.62 | 39 / 83 | 24 / 58 |
| `lma × 0.7` / `× 1.2` | −2.0e-5 / +8.4e-4 | 9.03 / 11.0 | 94 / 93 | 49 / 145 |
| `stem_P50 × 1.25` | −1.07e-3 | 12.3 | 88 | 317 |

Five percent from `θ0` the program is already 6× over tolerance, mostly in the
soil water and in `E`. A step whose stage leaves the domain (a negative storage,
T4) is subdivided inside the pinned interval without record, so the realised
grid differs from the pinned one.

**(Θ6) No cheap metric computed on the fixed grid tracks the error within a lean
schedule.** Spearman correlation against `|e|/J` over the 11 points:

| metric | default 108 | uniform 215 | lean180 | cw108_100 | pooled over schedules |
|---|---|---|---|---|---|
| Richardson, `(J_half − J)/3`, `J_half` on every other member (one more run) | 0.96 | 0.21 | 0.77 | 0.38 (6× high) | **0.87**, median ratio 0.98 |
| the refinement indicator's maximum | 0.94 | −0.75 | 0.09 | −0.80 | −0.33, ratio 221 |
| the pinned program's largest ratio | | | −0.05 | | |
| total-variation movement of `w/J` | −0.07 | 0.09 | 0.17 | 0.46 | 0.00 |

Richardson ranks schedules by their error and fails inside the leanest one, whose
every-other-member half is 2.9% off while the full schedule sits in a
cancellation; against the change `|e(θ) − e(θ0)|` it reads 0.08–0.28 per
schedule. The refinement indicator's maximum sits, on `lean180`, at the member
before its widest gap (13.85 yr), 200–800× `|e|/J`. The movement of `w/J` tracks
the change `|e − e(θ0)|` (0.84 on `lean180`) and not `|e|`.

### The adjoint

**(A1) The sweep of `J` costs 2.5–2.7 forward runs.** It is seeded on `J` alone and
runs on the recorded forward run.

| schedule | uniform 108 | 215 | 429 | 857 | `d108` |
|---|---|---|---|---|---|
| sweep ÷ a plain forward run, CPU | 2.66 | 2.55 | 2.55 | 2.51 | 2.59 |
| recording, MiB | 109 | 213 | 427 | 880 | 174 |
| peak resident set, MiB | 297 | 458 | 781 | 1423 | 365 |

- **Recording** costs nothing in CPU: a recorded forward run takes 0.96–0.99× a
  plain one.
- **Size.** The recording is 184–198 bytes per live member per step, three times its
  eight state entries. Each step also keeps six operating points of the inner solve
  per member, which the sweep replays in place of re-solving.
- **Per member evaluation.** One costs 53–62 µs in the sweep, against 16–18 µs
  forward. The sweep replays accepted steps only.
- **All census rows.** Sweeping all four costs 1.42× the sweep of `J` alone.

**(A2) The gradient converges more slowly than `J`.** The reference, −172.52 ± 0.03,
is the pinned central difference on three different ~860-member grids held fixed
across leaf mass per area, which agree to 0.03%.

| schedule | `J − J∞` | `dJ/dlma` by adjoint | against the fixed-grid value −172.52 ± 0.03 |
|---|---|---|---|
| uniform 108 | +0.70298 | −182.203 | −9.683 |
| uniform 215 | +0.17411 | −168.108 | +4.412 |
| uniform 429 | +0.00169 | −171.452 | +1.068 |
| uniform 857 | +0.00023 | −172.588 | −0.068 |
| `d108` | −0.45617 | −158.593 | +13.927 |

- From 108 to 857 members the gradient's error falls 142×, changing sign; `J`'s
  falls 3100×.
- At 429 members the gradient is 0.62% off, where `J` is 0.013%.
- The five columns of largest elasticity move together, 5.0–5.5% off at 108. By 429
  four are within 0.12%; the leaf-mass column itself is still 0.41% off.

**(A3) On one grid, the adjoint and a secant are different derivatives.**
- On uniform 215, with the steps pinned to the recorded ones, the pinned central
  differences are:
  - −174.017 at `d = 1e-3`;
  - −167.271 at `d = 1e-4`, from one-sided differences of −170.064 and −164.478
    (second difference `+5.6e4`).
- The adjoint reads −168.108, 3.4% from the first.
- The adjoint differentiates the recorded steps with the inner solve's recorded
  operating points held. The secant crosses changes in them. On that run a clamp on
  rooting depth binds in 8.5 M of 9.6 M inner solves, and 1.4 M end at the dry bound.

**(A4) The value of a newborn.**
- Define `v_k`, `J`'s sensitivity to the logarithm of member `k`'s birth flux. It has
  two parts:
  - its direct share `d_k = ω_k f_k`;
  - `λ_k`, the adjoint of its log density just after creation. This is the
    competition channel only, since `J` reads per-capita offspring.
- On `u429`:

| birth band | members | `Σ d` | `Σ λ` (competition) | `Σ v` | `λ ÷ d` |
|---|---|---|---|---|---|
| `[0, 0.5)` | 6 | 6.371 | −6.048 | +0.323 | −0.95 |
| `[0.5, 1)` | 5 | 2.588 | −2.582 | +0.006 | −1.00 |
| `[1, 5)` | 43 | 2.231 | −2.883 | −0.653 | −1.29 |
| `[5, 10)` | 54 | 1.221 | −5.207 | −3.986 | −4.27 |
| `[10, 20)` | 108 | 0.163 | −2.320 | −2.157 | −14.2 |
| `[20, 39.63]` | 213 | 0.002 | −0.137 | −0.135 | −68 |
| all | 429 | 12.575 = `J` | −19.177 | −6.601 | −1.52 |

- Only the 8 members created before `b = 0.65` have positive value. One more newborn
  at any later date lowers `J`.
- Per unit birth date, `g = v/ω`:
  - `+1.20` at `b = 0`;
  - crosses zero at `b = 0.74`;
  - swings to `−3.05` at `b = 7.96`, the cohort established as the first multi-year
    drought ends.
- **Checks.** The values agree with pinned finite differences at three members to
  `1.9e-4`, `1.6e-4` and `1.8e-5`, and with a forward tangent to `1.5e-5`.
- **How they are read.** A 207-line hook runs the shipped sweep one range at a time,
  at 1.006–1.045× its cost.

**(A5) The first-order formula holds with an accurate `g`, and fails from a coarse
schedule's own members.** The schedule enters only through trapezia over `b`. So to
first order `J_h − J∞ = Σ_k ω_k g(b_k) − ∫ g(b) db`: the trapezium defect of
`g = f + c`, where `f` is the direct offspring and `c` the competition effect, both
per unit birth date. The assumptions:
- the characteristics are exact;
- the formula is first order in the quadrature error;
- a member's competition weight equals its `J` weight throughout, although over its
  first interval the weight is a ramp;
- read from nodal values, `g` is smooth at the grid's spacing.

| node set | actual `J_h − J_429` | predicted from `u429`'s `g` | from `f` alone |
|---|---|---|---|
| uniform 108 | +0.7013 | +0.6530 (0.93×) | −0.0234 |
| uniform 215 | +0.1724 | +0.1675 (0.97×) | −0.0084 |
| `d108` | −0.4579 | −0.5902 (1.29×) | +0.6551 |
| the 220-member cost-weighted design | −0.0085 | +0.0098 (wrong sign) | +0.0019 |

The same estimate read off each schedule's own members, `η`, as a fraction of the
true error `J_h − J∞`:

| schedule | uniform 108 | uniform 215 | uniform 429 | `d108` |
|---|---|---|---|---|
| `η ÷ true` | 0.041 | 0.048 | 1.38 | 0.40 |
| the same estimate on `f` alone | 0.32 | 0.29 | 7.2 | −0.15 |

- **Where the error sits.** On uniform 108 the predicted error sits in `b = 5–10`
  (+0.413, of which competition +0.575 and `f` −0.162) and in `b = 10–20` (+0.186).
- **Why own members fail.** `g`'s excursions in the drought years span 0.1–0.5 yr,
  against spacings of 0.37 and 0.19 yr at 108 and 215 members.

**(A6) Refining where each indicator points.** `m` panels of uniform 108 were
bisected, starting from `J − J∞ = +0.703`, each set chosen by one indicator:

| `m` | the schedule's own `g`-defect | `u429`'s `g`-defect | the refinement loop's indicator | `f` alone |
|---|---|---|---|---|
| 10 | +0.566 | **+0.227** | +0.401 | +0.677 |
| 25 | **+0.071** | +0.186 | +0.204 | +0.213 |
| 50 | +0.177 | +0.172 | **+0.153** | +0.180 |

- No indicator wins at every `m`.
- `u429`'s `g` predicts each refinement's change in `J` to 5–25%.
- **On `d108` the response is not additive.** Its panels past `b = 5` are 1–2 yr
  wide, and the first-order prediction fails for most panel sets. One member there
  stands for 1–2 yr of cohorts whose competition effect reaches −4 per yr.
- **What the estimate costs.** A recorded forward run plus the sweep: 3.6–3.7 plain
  forward runs. Beyond the sweep an optimiser computes anyway, it costs 0.6–4.5% of
  that sweep.
- **Richardson** costs half a forward run. It reads the error to 1.3% at 215 members,
  34× high at 429, and 0.93× at 857.

## Constraints

**(H1) Within one gradient the grid is a constant.** The sweep differentiates the
recorded steps and the inner solve's recorded operating points (A3). A creation time
or a step size that moves with `θ` makes the reported derivative the derivative of a
different function at each point. Between gradients the grid may change. The step
sizes between entries are chosen per run by the controller.

**(H2) `𝒢_b ⊂ 𝒢_t` structurally.** The state dimension grows at each creation, the
solver reallocates, and every entry restarts the step sequence.

**(H3) The creation grid carries four roles at once:** the state dimension, the
quadrature abscissae, the adjoint's range count, and the index by which a recording
is reshaped for replay. They are matched on exact equality.

**(H4)** No data-dependent branch on an active value may enter the tape.

**(H5) One integration method is reachable from the model: the explicit pair.**
- A Rosenbrock stepper exists with a dense LU and a forward-mode Jacobian. It cannot
  be selected and has no adjoint (R4).
- The recording holds six rate evaluations per step, with the inner solve's
  operating point at each.
- An implicit stage needs its solve on the tape, as recorded arithmetic or as
  implicit-function rows.

**(H6) The sweep's use of the recording.** It re-derives each step's first stage at
the step's start and replays the other five from the recording, which is ~190 bytes
per live member per step (A1).

## Settled

- **The stops.** A stop at each active knot is the minimal set that keeps every step
  inside one cubic span of the forcing. Without stops `J` is −22.3%, because the
  embedded estimate vanishes on events narrower than `0.3h`. A 5-day cap instead
  leaves −0.45% (T7).
- **The window is part of the model.** Establishment reads the gate averaged over
  `τ_g = 0.05` yr, and the window moves `J` by +1.26%.
  - With the gate read at the instant of creation, the opening ramps are 0.06 days
    wide and no feasible schedule resolves them. Uniform schedules then do not
    converge, and grids held across `θ` carry a 2–4% derivative bias.
  - Averaged, uniform schedules converge, and grids held across `θ` agree on `dJ/dθ`
    to 0.03%.
- **The member loop is the cost (R1).** Only fewer member evaluations reduce it. No
  member is dead (R2).
- **Multirate.** With the member loop inside the fast steps, multirate multiplies
  member evaluations. Linearising the coupling saves nothing at matched accuracy
  (R3). Treating the soil implicitly with the member loop evaluated once per stage is
  untried.
- **Tolerance.** The step is not accuracy-limited (T1), and tightening tolerance does
  not converge `J` (T5).
- **The schedule's error** at a coarse schedule is the stand's (S3). `J`'s own
  integrand is not an indicator for it (A5, A6).
- **Across `θ`.** A node schedule built at `θ0` transfers across the box measured
  (Θ2). A pinned step program keeps `J` but loses error control (Θ5).
- **The sweep** is exact to the grid it runs on.

## Questions

### 1. The integrator between the stops

The step is set by the stops, by two local stiff modes at their explicit stability
limit, and by a throw cycle on one of them. One attempt in five is rejected. The
member loop is 99% of every rate evaluation and reads the fast variable. Tolerance
does not control `J`'s time error (T1–T9, R1–R4).

(a) Which integrator removes the stability limits of T3's two modes while evaluating
the member loop once per stage? The candidates:
- an additive Runge–Kutta pair with the soil chain and each member's storage
  implicit;
- a Rosenbrock-W method on a block-diagonal approximation of the Jacobian: the soil's
  closed-form bidiagonal and each member's storage diagonal, with the uptake coupling
  left out at `1.4e-4` of the diagonal;
- an exponential or Patankar-type update of the stiff diagonals inside the explicit
  pair.

Which of these keeps an embedded error estimate, and its order, under an approximate
Jacobian? Which preserves the storage's positivity? Which admits a discrete adjoint
that fits H5's recording?

(b) T8 bounds the saving at 33–51% of member evaluations. 33 points of it come from
the two modes, and 18 from rejections after rain, other short steps and the second
evaluation at each entry. With the stops kept, daily in wet spells, what controller
realises that bound? In particular:
- a proposal that anticipates the next entry, where the current one is clipped to a
  third of itself;
- a starting step for the leg after a wet knot, whose first step is rejected 47
  times in 100.

(c) `J`'s time error moves by `2–4e-4` when only the step placement changes (T5, T6).
Meanwhile stages cross the soil's clamps and the saturation-excess switch hundreds
to thousands of times per run, and the inner solve's terminal classifications change
with them, while no accepted step ends beyond the switch.
- Is that the mechanism?
- Does an L-stable treatment of the stiff modes remove it?
- What guarantee on `J`'s time error does a controller admit on a right-hand side
  that is piecewise smooth in the state?

### 2. The creation schedule

The facts (S1–S7, A4–A6):
- The error is the stand's response through competition, concentrated where the
  value of a newborn swings; `J`'s own integrand does not see it.
- The shipped loop's indicator points elsewhere, only inserts, and stops on a
  quantity `J` does not follow.
- The goal-oriented formula holds with an accurate `g`, and fails from a coarse
  schedule's own members.
- At 0.7–1.8 M member evaluations every design's error is a cancellation of
  `±(1–8)e-3`, set by where members fall against the gate's openings and closings.
- Step placement sets a floor of `6e-5`.

(a) What construction reaches a stated accuracy in `J` in the fewest runs and the
least `Σ M`? Is a dual-weighted loop the replacement — the `g`-defect per panel set
against member cost, with coarsening? How should `g` be resolved where a coarse
schedule's members do not resolve it? `g` splits as `f + c`:
- `f`, at any birth date, is what the invader machinery computes against a recorded
  stand;
- `c` needs the environment's adjoint (Free).

(b) What error bound can the resulting schedule carry, allowing for S1's floor and
for the cancellations? Is a schedule that does not rely on cancellation available at
comparable cost?

(c) Members created after `b = 0.65` all lower `J`. Members created after `b = 16`
take 37% of `Σ M` while moving `J` only through the stand (S2, S4, A4). Is there a
principled coarser representation of late cohorts, with a bound?

### 3. One discretisation across `θ`

The facts (Θ1–Θ6, S1, T5, A2, A3):
- The node schedule built at `θ0` held over a box in which `J` varies 14×, and
  rebuilding it at each `θ` made it worse. The gate's edges are the weather's.
- The step program pinned at `θ0` loses error control within 5%.
- Adaptive steps make `J` carry `6e-5` to `4e-4` of step-placement noise.
- On one grid, the adjoint and a secant differ by 3.4% at 215 members.
- The gradient converges more slowly than `J`.

(a) With the node schedule fixed and the steps adaptive, what objective and gradient
should a trust-region optimiser use? Which inexact-gradient theory covers the three
parts here:
- a gradient that is exact for a frozen discretisation;
- a bias from the schedule that is smooth in `θ`;
- a noise from step placement that is not?

What relative accuracy in `dJ/dθ` suffices?

(b) What certifies the fixed schedule at `θ ≠ θ0`, when none of the cheap metrics
tested tracks its error (Θ6)? Is the goal-oriented estimate at the current iterate
the certificate, and how often must `g` be refreshed?

(c) What sets the gradient's slower convergence (A2)? Should the schedule be
designed against the gradient's error instead of `J`'s?

### 4. The adjoint's place

The sweep costs 2.5 forward runs and is computed at every iterate. The member values
and the environment's adjoint inside it cost 0.6–4.5% more (A1, A6).
- Across an optimisation, is adaptivity driven by the sweep cheaper than forward-only
  refinement: Richardson at half a run, or the shipped loop at 7–45 M member
  evaluations?
- What rebuild schedule does the trust region imply?
- At what member count does the recording (880 MiB at 857 members) need
  checkpointing?

## Free

- **The record and the grid are known in advance.** Every creation time is known
  before the run.
  - A stop can be forced at any time with no member attached.
  - A zero-depth stop changes no state, so the rates carried from the step before it
    are valid after it.
- **The stiff blocks are cheap to reach.**
  - The soil chain's Jacobian is closed-form.
  - The soil rates given `a` are a separate function (`1.4e3` instructions), and
    setting the soil state alone is a copy.
  - Each member's storage mode is a scalar diagonal.
  - `∂a_ℓ/∂u_k` is available as forward tangents through the member loop, at 1.96×
    a member evaluation per direction.
- **The direct value of a newborn at any birth date.** `run_mutant` integrates any
  strategy's members as zero-density invaders against the field a finished resident
  run stood in, on that run's step program. That gives `f(b)` at any birth date, at
  the resident's cost per member. The environment's adjoint exists inside the sweep
  and is not exposed.
- **The member values of A4.** A 207-line hook returns the adjoint at every creation,
  at 1.006–1.045× a sweep.
- **The step record.** For each accepted step, the recording names the component that
  set its size and gives its error ratio. A replay outside the solver reproduces the
  solver's attempts bit for bit, rejected ones included.
- **What may change.**
  - The choice of grid is off the tape and may use anything, including earlier solves
    and earlier iterates, subject to H1.
  - The formulation may change if the change is declared and its effect on `J` and
    `dJ/dθ` is measured, as the establishment window's was.
