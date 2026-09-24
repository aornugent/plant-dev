# Performance at fixed accuracy on a nested grid

## The problem

A system of ODEs is integrated over a horizon `T = 40` against a known scalar forcing
record `s(t) ≥ 0`. The state is:
- a five-component chain `u`, driven by the forcing;
- an ensemble of members created at times `b_j`, eight components each.

Members interact only through two fields, both assembled from the ensemble by
trapezia over the creation times. The functional `J` is a trapezium over the creation
times of each member's accumulated output. `dJ/dθ`, for `θ` of about twenty
components, comes from a reverse sweep that is exact for the discretised model, and
drives a gradient-based calibration of `θ` against data.

The discretisation is one nested grid. The creation times are the abscissae of every
trapezium, and forced stops of an adaptive explicit Runge–Kutta integration. That
integration also stops at each of the record's 2931 active knots.

The cost is member evaluations. At every rate evaluation each member solves a nested
scalar root-finding problem: `1.1e5` instructions, 20 µs, ~99% of the rate
evaluation. A run whose creation schedule is `1.3e-4` from converged in `J` takes
`1.9e7` member evaluations.

Wanted, for a given forcing record:
- that count cut at fixed accuracy in `J` and `dJ/dθ`;
- a construction of the creation schedule that is fast to find and lean to run;
- a discretisation that serves an optimisation across `θ`, with a certificate that
  says when it stops serving.

What follows gives the full model, its discretisation, a list of structural features,
the measurements and the facts an answer can rely on; the questions are at the end
and are open. The creation schedule and the step sequence may not be the right
objects to adapt, and the difficulty may lie in a representational choice not yet
questioned: an answer that says so is wanted.

Time is in the horizon's units. `δ = 1/365` is the record's sampling interval, and
short times are given in `δ`. Rates are per unit time.

## The model

```
u̇_ℓ          = (in_ℓ − K(u_ℓ) − a_ℓ) / Δz                           ℓ = 1…5
in_1         = s(t) · max(0, 1 − (u_1/θ_s)^8),    in_ℓ = K(u_{ℓ−1})
K(u)         = K_s · (clamp(u, 0, θ_s)/θ_s)^q                          q = 16.14
ξ̇_j          = G(ξ_j, ψ(u), Φ, p_j)                                  ξ_j ∈ ℝ⁶
d(log n_j)/dt = −μ(ξ_j, ψ(u), Φ, p_j)
Ḟ_j          = e^{−m_j} · φ(ξ_j, ψ(u), Φ, p_j)                        accumulated output
p_j          = argmax over x ∈ [x_lo, x_hi] of R(x; ξ_j, ψ(u), Φ)       the inner problem
Ė            = (γ(P) − E) / τ_g,    γ(P) = P²/(A² + P²) for P > 0, else 0
n_j(b_j)     = β(b_j) · E(b_j),     m_j(b_j) = −log E(b_j)
a_ℓ          = Σ_j ω_j n_j c_ℓ(ξ_j, ψ(u), p_j)                          trapezium over b
Φ(z)         = Σ_j ω_j n_j A_j(z)                                    trapezium over b
J            = Σ_j ω_j β(b_j) π(b_j) S_D F_j(T)                      trapezium over b
```

**The chain.**
- Constants: `Δz = 0.3`, `K_s = 163.04`, `θ_s = 0.428`.
- A component at or below `θ_res = 0.01` has its rate set to `max(0, ·)`.
- Members read the chain only through `ψ_ℓ = ψ(u_ℓ)`, a power law in `u` capped at a
  maximum and computed once per state.
- Five accumulators beside the chain take rates from `u` and `a` and feed nothing
  back.

**The forcing.** `s(t)` is a shape-preserving `C¹` Hermite reconstruction of 14 599
control points at spacing `δ`.
- It is identically zero over quiescent stretches.
- It contains three long stretches of low forcing, near `t ∈ [7, 10]`, `[18, 22]`
  and `[31, 34]`.
- Its 2931 active knots are the points where the reconstruction's second derivative
  jumps.

**The members.**
- Each carries `ξ_j ∈ ℝ⁶`, `log n_j` and `F_j`. The six components of `ξ_j` are:
  - a coordinate over which the field `Φ` is read;
  - `m_j`, a cumulative loss with `ṁ_j = μ`;
  - an output integral;
  - two auxiliary accumulations;
  - a bounded pool `S_j`.
- The pool follows `Ṡ = c·(1 − S/S_max) − d·S/S_max`. Its attracting fixed point lies
  strictly inside `(0, S_max)`, with timescale `S_max/(c + d)`. A guard throws on
  `S < −1e-8·S_max`.
- The fields `a` and `Φ` are trapezia over creation time. At each time `t` they are
  closed by a member at `b = t` with density `β(t)E(t)`, evaluated at every rate
  evaluation and not carried as an ODE state. `Φ` is rebuilt at every rate
  evaluation; each member contributes `A_j(z)` to it and reads it over its own range
  of the coordinate.
- Members are never removed. The state grows by eight components per creation: 3443
  at 429 members, against the chain's ten (five components and five accumulators).

**The inner problem.**
- `p_j` maximises a scalar objective on an interval. It is found by nested
  root-finding:
  - an outer bracketing root-find (TOMS748) on the objective's derivative, about 11
    evaluations;
  - two inner scalar root-finds in each of those evaluations, about 6 iterations
    each;
  - about 50 evaluations per solve of a supply function of `ψ_1 … ψ_5`.
- The solution is interior in 85% of solves, at the interval's lower end in 15%,
  and in one of two terminal classes in under 0.2%.
- `p_j` is `C⁰` across the switches between classes.
- A clamp on a derived member quantity binds in most solves.

**The gate.**
- `E` is one scalar state: `γ(P)` filtered over `τ_g = 0.05`, started at its
  equilibrium. `P` is a scalar function of the state, evaluated for a member at its
  creation state, and `A` is a constant.
- `γ` opens over `40δ` (10–90%, median) once the forcing resumes, and closes over
  `18δ`.
- `P ≤ 0` on 56 bands spanning 14.7% of the horizon, the first at `b = 3.56`. Inside
  a band `γ = 0`, and `E` decays over `τ_g`.

**The functional.**
- `β ≡ 1` and `π(b)` are known records, and `S_D = 0.25`.
- At the reference `θ0`, `J∞ = 12.5734`.
- The largest log-sensitivities `θ/J · ∂J/∂θ` are:
  - `+51` for a component at 0.99 with an upper bound of 1;
  - `−7.8` for `θ_2`;
  - `−7.1` for `θ_1`'s own column, and `−4.2` for `θ_1` as mapped to four
    parameters;
  - `+6.5` for `θ_3`;
  - `+5.5` and `−5.1` for the next two.

## The discretisation

**One nested grid.**
- The creation times `𝒢_b` are the abscissae of the trapezia for `a`, `Φ` and `J`.
  They are also forced stops: the state dimension grows at each.
- The step times contain `𝒢_b` and `𝒦`, the 2931 active knots.
- A stop at each knot puts every step inside one cubic span of `s`, and makes the
  forcing's integral exact to `3.2e-12`.
- A knot is entered as an impulse of zero size and changes no state.
- At 429 members there are 3358 legs between consecutive entries. Half are one `δ`
  long (knots at consecutive control points within a stretch of active forcing), and
  10% are longer than `13δ`.

**The pair.** Cash–Karp 5(4), first-same-as-last. An accepted step costs six rate
evaluations. A rejected one costs six, or fewer if a stage throws: the stages up to
the one that throws.

**The controller.**
- Error ratio: `r = max_i |e_i| / (rtol·|y_i| + atol)`, with `rtol = atol = 1e-3`
  at the operating point.
- Reject when `r > 1.1`: `h ← h·max(0.2, 0.9 r^{−1/5})`.
- Accept when `0.5 ≤ r ≤ 1.1`, with `h` unchanged.
- Accept when `r < 0.5`: `h ← h·clamp(0.9 r^{−1/6}, 1, 5)`.
- A throw from a stage retries at `0.2h`.
- A step clipped to reach an entry does not update the carried proposal.
- `h_max = 5` and `h_min = 1e-6`.

**At every entry the rates are evaluated twice on the same state**, once by the
creation and once by the solver's restart. Each leg restarts the step sequence.

**Cost** is member evaluations: the sum over rate evaluations of the members held.
- An evaluation with `M` members costs about `1.12e5·M + 3e5` instructions.
- The member loop is 91% of it at 54 members, and ~99% at the operating run's mean
  of 216.
- The chain's rates given `a` cost `1.4e3` instructions.

**The creation schedule as shipped.**
- *The default generator* is dyadic, `Δ = 2^⌊log₂(0.2 t)⌋` clamped to
  `[1e-5, 2]`: 108 members, 44 of them below `b = 0.01`. It was built for a
  quadrature over a different coordinate, the members' first component, along which
  early members spread apart quickly.
- *The refinement loop:*
  1. Run the model.
  2. Compute, per member, a drop-one trapezium error on two terms:
     - a coupling term: the profile of `Φ`, sampled at each creation and normalised
       by the field's total;
     - an output term: `J`'s integrand.
  3. Flag each member whose larger term exceeds `ε_s = 2e-2`.
  4. Insert a member at the midpoint of the interval below each flagged one.
  5. Repeat.

  It only inserts.

**The reverse sweep.**
- It runs over a recording of the forward run, one row per accepted step, and
  differentiates the recorded steps with the inner problem's recorded solutions held.
- It is exact for the discretised model: `2.1e-8` against a forward tangent over 22
  parameters.
- A creation time or step size that depends on `θ` contributes a term that is not
  computed. So within one gradient the grid is a constant.

## Structural features

Any of these may be load-bearing or incidental; which ones, is not known.
- The grid is nested: creation times are abscissae and stops at once. The state
  dimension grows at each creation, and each entry restarts the step sequence and
  evaluates the rates twice.
- 2931 knots of the forcing are stops, and half of the legs between entries are one
  sampling interval long.
- The chain is one-way, with a loss term of exponent 16.14 clamped at an upper
  bound, an inflow switch at that bound, and a floor at a lower bound.
- Members read the chain through a capped power-law transform, and each other only
  through two trapezium fields.
- The inner problem runs at every member at every rate evaluation: nested
  root-finding, three solution classes, `C⁰` switches, and a clamp that binds in most
  solves.
- Each member has a bounded pool with an attracting fixed point inside its bounds.
  On the newest member its value sits far below `atol`.
- The gate is a first-order filter of a function that is zero on bands fixed by the
  record. Members are created inside those bands.
- Members are never removed. Their densities span eight decades below the peak.
- `J` reads per-member accumulated output through a trapezium whose last panel ends
  at the last creation. The fields close at `b = t`.
- The controller uses a max-norm, a dead band of `[0.5, 1.1]` and a growth clamp of
  5. A clipped step does not update the proposal, and a throw retries at `0.2h`.
- The sweep holds the inner problem's recorded solutions fixed. The grid is a
  constant within one gradient.
- The bands' edges are fixed by the record and barely move with `θ`, while `J` moves
  14× across the region the calibration visits.

## Measured

Unless stated, every measurement is at `θ0`, `rtol = atol = 1e-3`, with a stop at
every active knot. Two schedules recur: `u429`, 429 members uniform over
`b ∈ [0, 39.63]`; and `d108`, the default. Relative errors are against `J∞`.

Counts are the cost measure: accepted steps, attempts and member evaluations. `Σ M`
is the sum over accepted steps of the members alive.

**The correctness references.**
- `J∞ = 12.5734` is the order-3 extrapolation of uniform schedules of 429, 857 and
  1713 members (12.575093, 12.573626, 12.573447).
- The reference `dJ/dθ_1 = −172.52 ± 0.03` is the pinned central difference at
  `d = 1e-3` on three different grids of ~860 members, held fixed across `θ_1`; the
  three agree to 0.03%.

### The time integration

Every rejected attempt was recovered exactly, by replaying each run's steps outside
the solver bit-identically. The recovered counts equal the solver's own tallies on
every run replayed.

**(T1) The step is not limited by accuracy.**
- The median accepted step carries an error ratio of **0.030** (`u429`) and 0.040
  (`d108`), against the acceptance bound of 1.1. 8–10% of steps reach 0.5.
- From `tol = 1e-2` to `1e-4`, accepted steps scale as `tol^−0.065` and member
  evaluations as `tol^−0.049`. Two decades of tightening cost **+27%**, where an
  accuracy-limited fifth-order step scales as `tol^−0.2`.
- The median step is `0.56δ`, the 90th percentile `3.2δ`.

| `u429` | `t < 3.5` | active-forcing stretches | the three low-forcing stretches | all |
|---|---|---|---|---|
| accepted steps per unit time | 303 | 303 | 204 | 281 |
| members held, mean | 18 | 240 | 224 | 216 |
| median step | `0.39δ` | `0.49δ` | `1.00δ` | `0.56δ` |
| median error ratio | 0.056 | 0.034 | 0.013 | 0.030 |

**(T2) What shortens the step.**
- *Stops.* 30% of accepted steps are clipped to reach a knot or a creation, to a
  median **0.33** of the controller's proposal (quartiles 0.15–0.59). The 3358 legs
  take 3.35 accepted steps on average, and 32% are taken in one.
- *The chain's loss term at its stability boundary* (T3).
- *A cycle of throws on the newest member's pool* (T4).
- *Rejections*, which shorten the steps after them (T4).

The component attaining the error ratio's maximum is:
- a chain component on **75.7%** of accepted steps, `u_5` alone on 31%;
- a member component on 22.8%, mostly the newest member's cumulative loss;
- `E` on 1.5%.

The accumulators never bind at `atol ≥ 1e-4`.

**(T3) Two stiff modes, both local.**
- *The chain.* With `a` held, the chain's Jacobian is lower bidiagonal, with
  diagonal `−q·K_s·(u_ℓ/θ_s)^q/(u_ℓ·Δz)`. That is **`2.05e4` at `u = θ_s`**, a
  relaxation time of `0.018δ`, falling as `u^15.1`.
- *The coupling* `a` adds a median `1.4e-4` of that diagonal. It dominates only in
  components near `θ_res`, which never carry the dominant mode.
- *The pool.* The second mode is a member's pool relaxation, at 150–1444. It
  belongs to the newest member at 84% of steps and to one of the newest three at
  100%.
- *The whole system.* At 100 sampled states, the exact Jacobian's dominant
  eigenvalue is the larger of those two, to 0.92–1.0002.

| `u429` | value |
|---|---|
| chain `|λ|max`: 25 / 50 / 75 / 90% / max | 70 / 725 / 3197 / 7392 / 28 300 |
| `h·|λ|chain/β`: 25 / 50 / 75 / 90% / max | 0.065 / 0.44 / 0.78 / 1.01 / 1.91 |
| accepted steps at `h·|λ|chain ≥ 0.8β` / above `β` | 23.7% / 10.3% |
| controller-ended steps at `≥ 0.8β` | 31.4% |
| sampled controller-ended steps at `≥ 0.8β`, whole system | 34% |

`β = 3.7343596` is the fifth-order increment's real stability boundary. The median
error ratio rises with `h·|λ|/β`: 0.007 below 0.5, 0.072 at 0.5–0.8, 0.20 at 0.8–1.0,
and 0.28 at 1.0–1.2.

**(T4) One attempt in five is rejected, one rejection in three by a throw.**

| | `u429` | `d108` |
|---|---|---|
| attempts | 14 280 | 12 360 |
| rejected for accuracy / thrown | 1891 / 1150 | 1916 / 528 |
| rejected share of attempts / of member evaluations | 21.3% / 17.0% | 19.8% / 16.9% |

*Accuracy rejections.*
- A chain component rejects 1858 of the 1891.
- 59% are attempted at `h·|λ|chain ≥ 0.8β`.
- The rest cluster on the first step after a knot at which the forcing is non-zero:
  **47 rejected attempts per 100 such steps**, against 27 after a knot where it is
  zero and 23 mid-leg.

*Throws.*
- Every throw is the pool guard. In 79% it is the newest member's pool: a member aged
  a median 0.047, holding a median `5.3e-8`, below `atol/100` at every accepted step
  of the run.
- The pool's weight in the error norm is therefore `atol` alone: a 100% error in it
  contributes a ratio of `5e-5`.
- The cycle:
  1. The proposal grows while the ratio stays small, past that pool's stability
     boundary (a median `1.69β` at the throwing attempt).
  2. A stage at `0.6h` or `h` then drives the pool negative.
  3. The retry at exactly `0.2h` is accepted, and the growth repeats.
- Successive throws in a leg are 1–3 accepted steps apart: 4.3 per leg, over 268
  legs.

**(T5) Tolerance does not control `J`'s time-integration error.** On `u429`:

| `tol` | `J` | against `1e-4` | accepted | rejected (thrown) | member evaluations |
|---|---|---|---|---|---|
| `1e-2` | 12.577170485 | +1.66e-4 | 9 991 | 25.6% (1740) | 1.775e7 |
| `3e-3` | 12.576132363 | +8.4e-5 | 10 527 | 24.3% (1388) | 1.866e7 |
| `1e-3` | 12.575093099 | +1.3e-6 | 11 239 | 21.3% (1150) | 1.934e7 |
| `3e-4` | 12.572169221 | −2.31e-4 | 12 240 | 18.7% (772) | 2.054e7 |
| `1e-4` | 12.575076980 | 0 | 13 463 | 18.2% (508) | 2.247e7 |

- The spread is **4.0e-4 relative**, not monotone, and 3.1× the creation schedule's
  own error at 429 members (`1.3e-4`).
- Holding `rtol = 1e-3` and sweeping `atol` over `1e-5 … 1e-2` spreads `J` by
  5.3e-4, also not monotone.
- The differences accrue over `t ∈ [12, 25]`, as changes of either sign up to
  `1.5e-4` per unit time. They are carried by members created before `b = 3.5`
  (88% of `J`) and at `b = 7–10` (8.8%).
- On `d108`, `J` moves monotonically: +0.21%, +0.14% and −0.11% at `1e-2`, `3e-3` and
  `1e-4`, against `1e-3`.

**(T6) Step placement moves `J` as much as a decade of tolerance.**
- Adding 428 zero-size stops at the creation times the next uniform level would add
  — step placement changes, members do not — moves `J` by **+1.65e-4**. That is what
  `1e-3 → 1e-2` moves it.
- The difference accrues over `t ∈ [12, 23]`. At the knots, which both runs land on,
  `u` differs by up to `2.7e-3` and member log densities by up to 0.015.
- At any `tol ≤ 3e-3`, no accepted step ends with `u_1` past the inflow switch. Stages
  cross it inside the steps, and cross the chain's clamps:

| stage evaluations beyond | `tol 1e-2` | `3e-3` | `1e-3` | `3e-4` | `1e-4` |
|---|---|---|---|---|---|
| the inflow switch at `u_1 = θ_s` | 2998 | 1650 | 935 | 563 | 322 |
| the loss term's clamp to `[0, θ_s]` | 16 410 | — | 3894 | — | 1215 |
| the floor `θ_res` | 3760 | — | 962 | — | 292 |

The inner problem's terminal classes move the same way. Over the forward run they
fall 5.4× and 83× from `1e-2` to `1e-4`, and the added zero-size stops alone cut
them 9.3% and 5.4%.

**(T7) The stops.**
- Without them `J` is **−22.3%**, the deficit accruing from `t = 12`. The tableau's
  abscissae `{0, 0.2, 0.3, 0.6, 1, 0.875}·h` step over forcing events narrower than
  `0.3h`, and the embedded estimate vanishes on them.
- A cap of `h ≤ 5δ` in place of the stops gives −0.45%.
- The stops add 866 accepted steps against the unstopped run and remove 631
  attempts: rejections fall from 30.4% to 21.3%.
- Each of the 3358 entries costs two rate evaluations, 7.5% of all member
  evaluations.

**(T8) A bound on what an integration free of the two stiff modes' stability limits
could save.**
- *Method.* An offline bound from the recorded runs at `tol = 1e-3`, keeping the
  accuracy limit and every entry.
  - Each accepted step was re-taken, and its error ratio recomputed without the chain
    components and members at `h·|λ| ≥ 0.5β`.
  - Its local limit is `h·max(1, min(5, 0.9 r^{−1/5}))`, floored at `h` because every
    measured step was admissible.
  - Each leg is filled with `⌈∫dt/limit⌉` steps.
- *Assumptions.* No rejections and no throws; the same members per leg; error
  scaling as `h⁵`; the stiff components imposing no accuracy limit of their own; no
  added cost per evaluation.

| `u429` | accepted steps | member evaluations saved |
|---|---|---|
| measured | 11 239 | — |
| stiff components out, walking the controller's own law (×5 growth, the proposal carried across clips) | 8 887 | 32.8% |
| **stiff components out, legs filled** | **6 722** | **47.5%**, or 51.2% with one evaluation per entry |
| one step per leg, the floor the stops set | 3 358 | 69.9%, or 73.7% |

- *Where the filled 51.2% comes from:*
  - 30.5 points are accepted steps, 21.3 of them from the stability credit;
  - 17.0 points are rejections: 4.3 throws, 7.5 accuracy rejections at `≥ 0.8β`,
    and 5.2 on first steps after a knot with non-zero forcing;
  - 3.8 points are the second evaluation at each entry.
- **33.1 points are attributable to the two stiff modes, and 18.2 are not.**
- *By leg.* Legs one `δ` long hold 15% of the time and 59% of the cost, and would
  save 43% of it, half in accuracy rejections. Longer legs would save 63%, mostly
  stability credit and throws.
- With no evaluation at a knot, where a zero-size impulse changes no state, the
  filled bound is 54.5%.

**(T9) The gradient against the time grid.**
- On `d108`, from `tol = 1e-3` to `1e-4`, `dJ/dθ_1` by the sweep moves −158.593 →
  −158.898 (+0.19%), while `J` moves −0.11%. `∂J/∂τ_g` moves −4.5%.
- At `1e-2` and `3e-3` the sweep refuses: a stage state lies past the domain of a
  series used by the inner problem's derivative (27 222 against a domain edge of
  4.6).

### The rate evaluation

**(R1) The member loop is the cost, and inside it the inner problem.** Instruction
counts under callgrind, on the operating run truncated to `t ≤ 5` (54 members):

| part | share |
|---|---|
| member rates | 90.97% |
| · the inner problem | 84.90% |
| · a per-member quadrature over `Φ` | 2.25% |
| the closing member at `b = t`, and `E` (two inner solves per evaluation) | 6.51% |
| building `Φ` | 1.46% |
| the coupling sums `a_ℓ` | 0.41% |
| the chain's rates | 0.04% |
| solver arithmetic and the controller | 0.25% |

- An evaluation with `M` members costs `≈ 1.12e5·M + 3e5` instructions, so the member
  loop is ~99% at the operating run's mean of 216.
- A member evaluation is **20.2 µs** on a quiet core. It is 47 k instructions where
  46% of solves end at the interval's lower end, and 107–109 k elsewhere.
- Inside the inner problem, the supply function takes 28% of every instruction the
  run executes.
- A member's cost does not depend on its density.

**(R2) No member is dead, but most are sparse.** Members are never removed, and
every one is evaluated in full.
- No member of the operating run falls below `10^−8.39` of the peak member density at
  any step, so no evaluation goes to a member of zero weight.
- 41.0% of accepted-step member evaluations go to members below `1e-3` of the peak,
  and 3.9% to members below `1e-6`.
- The share below `1e-3` rises from 0 over `t < 5` to 63.6% over `t > 35`.

| creation band | `[0, 3)` | `[3, 10)` | `[10, 20)` | `[20, 30)` | `[30, 40]` |
|---|---|---|---|---|---|
| share of member evaluations | 14.6% | 28.5% | 31.2% | 19.0% | 6.8% |

**(R3) Where multirate decompositions spent their evaluations.** Measured on other
code versions and fixtures, not the operating run:

| decomposition | measured |
|---|---|
| multirate infinitesimal step, chain fast, members slow | each fast evaluation re-runs the member loop; ~10 micro-steps per macro step; 6–25× the cost of the single-rate pair at converged `J` |
| the chain's loss integrated in closed form inside the fast step | more micro-steps (103 against 58 per macro step), 0.6× the speed |
| the fast coupling from `m ≪ M` members | `m = 20`: 14% `J` error at `M = 352`; `m = 40`: 2.4% at 2× the cost |
| the coupling held, linearised or tabulated over a macro step | held: an error plateau of 0.1; linearised: up to 440% error in `a` as `u` falls |
| fast chain against an affine coupling `a₀ + G(u − u₀)`, `G = ∂a/∂u` exact | constant forcing: 40× fewer member sweeps; periodic forcing: 3.8× at a `J` error of `3.5e-3`, 1.0× at `≤ 4e-4` |
| a Rosenbrock step on the chain block, its Jacobian differenced through the full rates | 19 member-loop evaluations and a dense full-size factorisation per step; 20–50× slower |

None of these kept the member loop explicit, evaluated once per stage, with the
chain implicit.

**(R4) What exists for implicit integration.**
- *A Rosenbrock stepper*, RODAS4(3), exists in the integration library. It has a
  forward-mode AD Jacobian (one tangent rate evaluation per state column, so 3443 at
  429 members) and a dense LU.
  - The model's driver cannot select it.
  - It has no adjoint. Its stage recurrence would need `Wᵀ` solves, second
    derivatives of the rates through the member loop along the stage vectors, and a
    per-stage record of the inner problem's solutions, which the recording's
    six-evaluation shape does not hold.
- *The chain's Jacobian* is closed-form (T3), and formed nowhere.
- *The chain's rates given `a`* are a separate function, 1.4 k instructions, and
  setting the chain's state alone is a copy.
- *`∂a_ℓ/∂u_k`* is, per member, a rank-one term through the inner problem's
  solution plus a diagonal: a dense 5×5 summed over members. It is available only as
  forward tangents, at 1.96× a member evaluation per direction.
- *Non-smooth points.* The chain's rate is non-smooth at `θ_res`, at the loss
  clamp, at `ψ`'s floor and cap, and at the inflow switch.
- *Knots.* A knot is a state jump of zero size at a leg start, and every leg
  restarts the step sequence.

### The creation schedule

Relative errors in this section are against `J∞ = 12.573422`, the order-3
extrapolation of uniform 429, 857 and 1713.

**(S1) Step placement sets a floor under the schedule's error.**
- Moving every member of `u429` except the first by `1e-5`, `3e-5` or `1e-4`
  changes `J` by +6.5e-5, −5.9e-5 and −6.2e-5 of itself: **sd 6.0e-5** over four
  runs, range 1.27e-4.
- The trapezium's own share of those moves is 6e-7 to 6e-6. The rest is the
  controller placing its steps elsewhere once the creation stops move (T6).
- At `tol = 1e-3` a schedule error below about `1e-4` cannot be attributed to the
  schedule, and `J∞` is not determined below it.

**(S2) Where `J` sits and where the cost sits are different places.**

| creation band | share of `J` | member cost / mean member | share of `Σ M` |
|---|---|---|---|
| `[0, 1)` | 0.719 | 1.93–1.95 | 0.05 |
| `[1, 3.56)` | 0.162 | 1.86 | 0.12 |
| `[3.56, 6)` | 0.0125 | 1.72 | 0.11 |
| `[6, 10)` | 0.0931 | 1.56 | 0.16 |
| `[10, 16)` | 0.0119 | 1.33 | 0.20 |
| `[16, 22)` | 0.0012 | 1.05 | 0.16 |
| `[22, 40]` | 3.6e-5 | 0.47 | 0.21 |

- `J`'s integrand `w(b)` falls from 16.9 at `b = 0` by half every 0.35.
- Past the first band its largest value is 1.28, at `b = 7.96`: members created as
  the first low-forcing stretch ends.
- A member created at `b = 0` costs 1.98× the mean member at every uniform count
  from 108 to 1713.

**(S3) The error is the response through the coupling, not `J`'s own trapezium.**
- Uniform 215 reads `+1.38e-2`. Split at each of its nodes into two parts — the
  trapezium's error on the converged run's integrand, and the change in the
  integrand itself — **96% is the response through the coupling**. Under the coarser
  schedule, members created before `b = 16` have 1.1–2.7% more accumulated output.
- Where `w` is smooth, before `b = 3.56`, the trapezium's local term
  `(Δb³/12)·w''` predicts the trapezium's own error to 0.6–9%.
- Over `[3.56, 16)` the panel errors are one to two orders larger than the local
  term, and cancel between panels. At a spacing of `34δ` the gate's openings (`40δ`)
  and closings (`18δ`) are not resolved.

**(S4) Accuracy is bought in `[6, 16)`.** `u429`'s midpoints were added to uniform
215 one creation band at a time. The fills sum to within 2.9% of the whole
215 → 429 change:

| band filled | members added | `ΔJ` | trapezium | coupling response | added `Σ M` | share of the 215 → 429 change |
|---|---|---|---|---|---|---|
| `[0, 3.56)` | 19 | −0.0083 | −0.0363 | +0.0280 | 196 382 | 4.8% |
| `[3.56, 6)` | 13 | +0.0006 | −0.0009 | +0.0015 | 123 562 | −0.4% |
| **`[6, 10)`** | 22 | **−0.0955** | +0.0377 | −0.1332 | 188 749 | **55.4%** |
| **`[10, 16)`** | 32 | **−0.0791** | +0.0069 | −0.0860 | 241 453 | **45.9%** |
| `[16, 40)` | 128 | +0.0050 | −0.0002 | +0.0052 | 473 766 | −2.8% |

- The members created in `[6, 16)` carry 10.5% of `J`. The `J` they move belongs to
  the members created before them, and moves through the coupling.
- Removing `u429`'s 64 members strictly inside the 56 bands, where `γ = 0` but `E`
  decays over `τ_g`, reads **−7.29e-2**.
- Thinning uniform 215's members past `b = 22` to one per 2 time units moves `J` by
  −1.48e-3. Those members carry 3.6e-5 of it.

**(S5) The refinement loop.** From the default schedule:

| `ε_s` | runs | members | relative error | `Σ M`, last run | `Σ M`, all runs |
|---|---|---|---|---|---|
| 2e-2 | 6 | 178 | −1.32e-2 | 1 392 441 | 7 316 788 |
| 2e-3 | 8 | 390 | −2.31e-3 | 2 671 747 | 15 342 593 |
| 2e-4 | 11 | 957 | −5.60e-4 | 6 392 986 | 44 798 127 |
| 2e-2, from uniform 108 | 4 | 140 | +1.17e-2 | 800 876 | 2 863 276 |

- *Which term flags.* Read term by term, every flag in every loop is the coupling
  term's. The output term exceeded the threshold at 146 flagged members, always
  beside the coupling term and never alone.
- *Where the flags fall.* 59% of the 1233 flags fall past `b = 16`, where the fills of
  S4 move `J` by less than S1's floor; 32% in `[6, 16)`; 6% before 3.56.
- *The indicator and `J`.* The indicator falls at every bisection, and `J` does not
  follow it.
  - At `2e-2` the loop passes within 4.7e-3 of `J∞` at its third run, and stops at
    −1.32e-2.
  - At `2e-3` it passes −2.6e-4 at its fifth run, and stops at −2.31e-3.
- *What it keeps.* The 44 default members below `b = 0.01` stay in every final
  schedule.

**(S6) Fixed designs, and what finding them costs.** Each was built at `θ0`, then run
on its own adaptive steps.

| design | members | relative error | trapezium / coupling response | `Σ M` |
|---|---|---|---|---|
| uniform | 250 / 320 / 380 / 429 / 857 | +1.9e-3 / +6.65e-3 / −8.7e-4 / +1.33e-4 / +1.6e-5 | — | 1.39 / 1.79 / 2.14 / 2.43 / 5.03 M |
| cost-weighted from one uniform-108 pilot: density `∝ (|w''|/12 / member cost)^{1/3}` | 60 / 100 / 150 / 180 / 220 / 320 | +2.0e-2 / +7.1e-4 / +2.1e-3 / −4.0e-3 / −5.4e-4 / −9.3e-5 | trapezium within ±3e-3 throughout; response +2.3e-2 / −1.8e-3 / +2.2e-3 / −3.6e-3 / −8.4e-4 / −5e-6 | 0.43 / 0.76 / 1.19 / 1.44 / 1.76 / 2.63 M |
| the same from a uniform-215 pilot | 100 / 220 | −6.6e-3 / −2.4e-3 | | 0.75 / 1.74 M |
| uniform to `b = 22`, one member per 2 time units after | 150 / 220 / 320 | −9.0e-3 / −2.9e-3 / −9.0e-4 | | 1.06 / 1.59 / 2.35 M |
| from the forcing record alone: a run with no members, its `u_1` averaged over `30δ`, per unit member cost (that run's gate is flat, 0.9978–0.9979) | 150 / 320 | +1.7e-2 / −1.8e-2 | | 0.68 / 1.50 M |
| halved spacing on `[6, 16)` from the fills, graded after | 150–240 | −3.1e-3 to −1.8e-3 | | 1.01–1.65 M |

| target | least `Σ M`, any design | least `Σ M` from which every larger run of the design stays under | uniform |
|---|---|---|---|
| 1e-2 | 0.76 M (cost-weighted 100) | 0.76 M | 1.39 M (250) |
| 1e-3 | 0.76 M (cost-weighted 100) | **1.76 M** (cost-weighted 220) | **2.14 M** (380) |
| 1e-4 | 2.63 M (cost-weighted 320), inside S1's floor | — | 5.03 M (857), inside the floor |

- *Cancellation.* Every design's error in the 0.7–1.8 M range is a trapezium term and
  a response term of `±(1–8)e-3`. Their signs follow where members fall relative to
  the gate's openings and closings, and no design's error is monotone in the member
  count.
- *Cost of finding.* The cost-weighted design costs one pilot run (0.58 M) to find.
  Found and used once, it costs 2.34 M at its first count that stays under `1e-3`,
  against 2.14 M for uniform 380.
- *The loop's cost.* The refinement loop at `2e-3` costs 12.7 M to find a schedule
  that ends at −2.3e-3.

**(S7) The schedule sets `M`; the steps barely move.**
- Along the uniform ladder, accepted steps are `10 732 + 0.95 × members`. Creations
  end 1.0% (108 members) to 14% (1713) of steps; the knots end 24–30%.
- Over 57 runs of 100–440 members, steps range ±6.3% while `Σ M` ranges 5.7×.
- At equal count, a schedule with fewer late members takes fewer steps. A member
  costs 1–2 steps where it joins members at `34–68δ` spacing, and up to 15 where it
  falls in a gap of 1–2 time units.

### Across `θ`

A discretisation built at `θ0`, read at other `θ`.
- *Axes.* Three: `θ_1` (a component mapped to four model parameters), and `θ_2` and
  `θ_3`, the two of largest log-sensitivity after the one at its bound.
- *Points.* Eleven: `θ_1 × {0.7, 0.85, 0.95, 1.05, 1.15, 1.2}`,
  `θ_2 × {0.8, 1.1}`, `θ_3 × {0.9, 1.25}`, and `θ0`.
- *Range of `J`.* It spans 3.68–52.1 over them. At `θ_1 × 1.35`, `θ_2 × 1.25` or
  `θ_3 × 0.8`, `J < 1`, outside the region the calibration uses.
- *What is held.* The creation schedules are held fixed. The steps are adaptive at
  each `θ` unless pinned.

**(Θ1) The reference is not uniformly good.** Uniform 429 against uniform 857:
+1.2e-4 at `θ0`, **−1.70e-3 at `θ_1 × 0.7`**, and −6.8e-4 at `θ_1 × 1.2`. Below
about `1e-3`, errors away from `θ0` are resolved only at those three points.

**(Θ2) A lean creation schedule fixed at `θ0` holds across the box.** `lean180` is a
cost-weighted design, density `∝ (|w''|/c)^{1/3}` with `c(b)` the accepted steps
after `b`, read off `θ0`'s uniform-857 run. The `cw108` designs are S6's.

| schedule | `e/J` at `θ_1 × 0.7` / `θ0` / `θ_1 × 1.2`, against 857 | gradient error, lower / upper half of the `θ_1` axis | `|e|/J`, all 11 points, against 429 |
|---|---|---|---|
| `d108` | −9.33e-2 / −3.63e-2 / −2.25e-3 | **−12.1% / −5.0%** | up to 1.2e-1 |
| uniform 215 | +1.25e-2 / +1.38e-2 / +1.82e-2 | +1.19% / +1.20% | 1.9e-3 – 1.9e-2 |
| uniform 429 | −1.70e-3 / +1.17e-4 / −6.79e-4 | −0.26% / +0.04% | (the reference) |
| **lean180** | **+5.9e-5 / −8.5e-4 / −8.8e-4** | **+0.05% / −0.08%** | ≤ 2.8e-3 |
| cw108_100 | −2.14e-3 / +7.0e-4 / +4.70e-3 | −0.35% / −0.10% | ≤ 5.4e-3 |
| cw108_220 | −2.13e-3 / −5.6e-4 / −3.7e-4 | −0.29% / −0.06% | ≤ 1.04e-3 |

- *The gradient error* is the secant of `e` over the secant of `J` across each half
  of the `θ_1` axis: what an optimiser differencing that schedule would see. `J`
  falls 10.5× along the axis.
- *On the `θ_3` axis* `d108`'s gradient error reaches **+21.8%**. Every lean
  schedule's stays at or under 0.61%, the reference's own resolution.
- *`d108`'s error* doubles by `θ_1 × 0.7`, passes through zero, and reaches +12% at
  `θ_3 × 1.25`.

**(Θ3) Rebuilding the recipe at `θ` is worse than keeping `θ0`'s.** The same recipe
was rebuilt from `θ`'s own pilot at the same member count. It moves members a median
0.5–0.9, and reads, against 857:

| | fixed at `θ0` | rebuilt at `θ` |
|---|---|---|
| `lean180`, `θ_1 × 0.7` / `× 1.2` | +5.9e-5 / −8.8e-4 | −2.19e-3 / −2.45e-3 |
| `cw108_100`, `θ_1 × 0.7` / `× 1.2` | −2.14e-3 / +4.70e-3 | −7.76e-3 / +7.42e-3 |

**(Θ4) The bands' edges are the record's.**
- The edges of the bands — stretches where `w` sits a decade below its running
  maximum — move by at most **0.089** across the box. That is less than one
  `u429` spacing (0.093); the median shifts are 0.001–0.015.
- What moves is the weight `w` puts on and around them. The creation time by which
  99% of `J` is created moves by −1.22 to +2.31, and `w/J` moves a total-variation
  distance of 0.02–0.14.
- At `θ_3 × 1.25` the regime changes: 2 of `θ0`'s 9 bands remain deep enough to
  count, and the reference takes 53% more steps.

**(Θ5) A pinned step program keeps `J` but not its error control.** `lean180` was run
at each `θ` with its steps pinned to `θ0`'s 10 349 step times.
- `J` is within **1.1e-3** of the adaptive run at every point, no run fails, and the
  pinned run is 15% cheaper, having no rejected attempts.
- A pinned step forms no error estimate: the embedded difference is computed and
  never weighted, and the controller is not called.
- The ratio was therefore re-formed outside the solver. Validated on `θ0`'s adaptive
  run, it matches to a median relative difference of `1.9e-8`, with the same largest
  ratio, 1.0976.

| point | `(J_pinned − J_adaptive)/J` | largest error ratio | steps over 1.1 | steps whose stages leave the model's domain |
|---|---|---|---|---|
| `θ0` | +9.3e-7 | 1.10 | 0 | 0 |
| `θ_1 × 0.95` / `× 1.05` | −1.7e-4 / +4.9e-4 | 6.65 / 6.62 | 39 / 83 | 24 / 58 |
| `θ_1 × 0.7` / `× 1.2` | −2.0e-5 / +8.4e-4 | 9.03 / 11.0 | 94 / 93 | 49 / 145 |
| `θ_3 × 1.25` | −1.07e-3 | 12.3 | 88 | 317 |

- Five percent from `θ0` the program is already 6× over tolerance, mostly in the
  chain and in `E`.
- A step with a stage outside the domain (a negative pool, T4) is subdivided inside
  the pinned interval without record, so the realised grid differs from the pinned
  one.

**(Θ6) No cheap metric computed on the fixed grid tracks the error within a lean
schedule.** Spearman correlation against `|e|/J` over the 11 points:

| metric | `d108` | uniform 215 | lean180 | cw108_100 | pooled over schedules |
|---|---|---|---|---|---|
| Richardson, `(J_half − J)/3`, with `J_half` on every other member (one more run) | 0.96 | 0.21 | 0.77 | 0.38 (6× high) | **0.87**, median ratio 0.98 |
| the refinement indicator's maximum | 0.94 | −0.75 | 0.09 | −0.80 | −0.33, ratio 221 |
| the pinned program's largest ratio | | | −0.05 | | |
| total-variation movement of `w/J` | −0.07 | 0.09 | 0.17 | 0.46 | 0.00 |

- *Richardson* ranks schedules by their error, and fails inside the leanest one: its
  every-other-member half is 2.9% off while the full schedule sits in a
  cancellation. Against the change `|e(θ) − e(θ0)|` it reads 0.08–0.28 per schedule.
- *The refinement indicator's maximum* sits on `lean180` at the member before its
  widest gap (13.85), at 200–800× `|e|/J`.
- *The movement of `w/J`* tracks the change `|e − e(θ0)|` (0.84 on `lean180`), not
  `|e|` itself.

### The reverse sweep

**(A1) The sweep of `J` costs 2.5–2.7 forward runs.** It is seeded on `J` alone and
runs on the recorded forward run.

| schedule | uniform 108 | 215 | 429 | 857 | `d108` |
|---|---|---|---|---|---|
| sweep ÷ a plain forward run, CPU | 2.66 | 2.55 | 2.55 | 2.51 | 2.59 |
| recording, MiB | 109 | 213 | 427 | 880 | 174 |
| peak memory, MiB | 297 | 458 | 781 | 1423 | 365 |

- Recording costs nothing in CPU: a recorded forward run takes 0.96–0.99× a plain
  one.
- The recording is 184–198 bytes per live member per step, three times its eight
  state entries. Each step also keeps six inner-problem solutions per member, which
  the sweep replays in place of re-solving.
- A member evaluation costs 53–62 µs in the sweep, against 16–18 µs forward. The
  sweep replays accepted steps only.
- Seeding all four rows of the functional's family costs 1.42× the sweep of `J`
  alone.

**(A2) The gradient converges more slowly than `J`.**

| schedule | `J − J∞` | `dJ/dθ_1` by the sweep | against −172.52 ± 0.03 |
|---|---|---|---|
| uniform 108 | +0.70298 | −182.203 | −9.683 |
| uniform 215 | +0.17411 | −168.108 | +4.412 |
| uniform 429 | +0.00169 | −171.452 | +1.068 |
| uniform 857 | +0.00023 | −172.588 | −0.068 |
| `d108` | −0.45617 | −158.593 | +13.927 |

- From 108 to 857 members the gradient's error falls 142×, changing sign on the way;
  `J`'s falls 3100×.
- At 429 members the gradient is 0.62% off, where `J` is 0.013%.
- The five columns of largest log-sensitivity move together, 5.0–5.5% off at 108.
  By 429 four are within 0.12%; `θ_1`'s own column is still 0.41% off.

**(A3) On one grid, the sweep and a secant are different derivatives.**
- On uniform 215, with the steps pinned to the recorded ones, the pinned central
  differences are:
  - −174.017 at `d = 1e-3`;
  - −167.271 at `d = 1e-4`, from one-sided differences of −170.064 and −164.478
    (second difference `+5.6e4`).
- The sweep reads −168.108, 3.4% from the first.
- The sweep holds the inner problem's recorded solutions fixed; the secant crosses
  changes in them. On that run the clamp on a derived member quantity binds in
  8.5 M of 9.6 M inner solves, and 1.4 M solves end at the interval's lower end.

**(A4) The value of a new member.**
- Define `v_k` as `J`'s sensitivity to the logarithm of member `k`'s creation flux.
  It has two parts:
  - the direct share `d_k = ω_k f_k`;
  - `λ_k`, the adjoint of the member's log density just after creation. This is the
    coupling channel only, since `J` reads per-member output.
- On `u429`:

| creation band | members | `Σ d` | `Σ λ` (coupling) | `Σ v` | `λ ÷ d` |
|---|---|---|---|---|---|
| `[0, 0.5)` | 6 | 6.371 | −6.048 | +0.323 | −0.95 |
| `[0.5, 1)` | 5 | 2.588 | −2.582 | +0.006 | −1.00 |
| `[1, 5)` | 43 | 2.231 | −2.883 | −0.653 | −1.29 |
| `[5, 10)` | 54 | 1.221 | −5.207 | −3.986 | −4.27 |
| `[10, 20)` | 108 | 0.163 | −2.320 | −2.157 | −14.2 |
| `[20, 39.63]` | 213 | 0.002 | −0.137 | −0.135 | −68 |
| all | 429 | 12.575 = `J` | −19.177 | −6.601 | −1.52 |

- *Sign.* Only the 8 members created before `b = 0.65` have positive value. One more
  member created at any later time lowers `J`.
- *Per unit creation time*, `g = v/ω`:
  - is +1.20 at `b = 0`;
  - crosses zero at `b = 0.74`;
  - swings to −3.05 at `b = 7.96`, the member created as the first long low-forcing
    stretch ends.
- *Checks.* The values agree with pinned finite differences at three members to
  `1.9e-4`, `1.6e-4` and `1.8e-5`, and with a forward tangent to `1.5e-5`.
- *How they are read.* A 207-line addition to the sweep runs it one range at a time,
  at 1.006–1.045× its cost.

**(A5) The first-order formula holds with an accurate `g`, and fails from a coarse
schedule's own members.** The schedule enters only through trapezia over `b`. So, to
first order, `J_h − J∞ = Σ_k ω_k g(b_k) − ∫ g(b) db`: the trapezium defect of
`g = f + c`, where `f` is the direct output and `c` the coupling effect, both per
unit creation time.

Its assumptions:
- the members' trajectories are exact;
- first order in the quadrature error;
- a member's coupling weight equals its `J` weight throughout, although over its
  first interval it is a ramp;
- when read from nodal values, `g` is smooth at the grid's spacing.

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

- *Where the error sits.* On uniform 108 the predicted error sits in `b = 5–10`
  (+0.413, of which the coupling +0.575 and `f` −0.162) and in `b = 10–20` (+0.186).
- *Why a schedule's own members fail.* `g`'s excursions in the low-forcing stretches
  span 0.1–0.5, against spacings of 0.37 and 0.19 at 108 and 215 members.

**(A6) Refining where each indicator points.** `m` panels of uniform 108 were
bisected, starting from `J − J∞ = +0.703`, each set of panels chosen by one
indicator:

| `m` | the schedule's own `g`-defect | `u429`'s `g`-defect | the refinement loop's indicator | `f` alone |
|---|---|---|---|---|
| 10 | +0.566 | **+0.227** | +0.401 | +0.677 |
| 25 | **+0.071** | +0.186 | +0.204 | +0.213 |
| 50 | +0.177 | +0.172 | **+0.153** | +0.180 |

- No indicator wins at every `m`. `u429`'s `g` predicts each refinement's change in
  `J` to 5–25%.
- On `d108`, whose panels past `b = 5` are 1–2 wide, the response is not additive,
  and the first-order prediction fails for most panel sets. A member there stands
  for 1–2 time units of members whose coupling effect reaches −4 per unit time.
- *Cost of the estimate.* A recorded forward run plus the sweep: 3.6–3.7 plain
  forward runs. Beyond the sweep an optimiser computes anyway, it costs 0.6–4.5% of
  that sweep.
- *Richardson* costs half a forward run. It reads the error to 1.3% at 215 members,
  34× high at 429, and 0.93× at 857.

## Facts an answer can rely on

**(H1) Within one gradient the grid is a constant.** The sweep differentiates the
recorded steps and the inner problem's recorded solutions (A3). A creation time or a
step size that moves with `θ` makes the reported derivative the derivative of a
different function at each point. Between gradients the grid may change. The step
sizes between entries are chosen per run by the controller.

**(H2) `𝒢_b ⊂ 𝒢_t` structurally.** The state dimension grows at each creation, the
solver reallocates, and every entry restarts the step sequence.

**(H3) The creation grid carries four roles at once:** the state dimension, the
abscissae, the sweep's range count, and the index by which a recording is reshaped
for replay. They are matched on exact equality.

**(H4)** No data-dependent branch on an active value may enter the tape.

**(H5) One integration method is reachable from the model: the explicit pair.** The
recording holds six rate evaluations per step, with the inner problem's solution at
each. An implicit stage needs its solve on the tape, as recorded arithmetic or as
implicit-function rows.

**(H6) The sweep's use of the recording.** It re-derives each step's first stage at
the step's start, and replays the other five from the recording (A1).

**Settled:**
- *The stops.* A stop at each active knot is the minimal set that keeps every step
  inside one cubic span of the forcing (T7).
- *The gate's filter is part of the model*, and moves `J` by +1.26%. With `γ` read
  unfiltered at creation:
  - its opening ramps are `0.06δ` wide and no feasible schedule resolves them;
  - uniform schedules do not converge;
  - grids held across `θ` carry a 2–4% derivative bias.

  Filtered, uniform schedules converge, and grids held across `θ` agree on `dJ/dθ`
  to 0.03%.
- *Cost.* Member evaluations are the cost (R1), and no member has zero weight (R2).
- *The sweep* is exact to the grid it runs on.

**Free:**
- *Advance knowledge.* The forcing record is known in full before the run, and so is
  every creation time.
- *Stops.* A stop can be forced at any time with no member attached. A zero-size
  impulse changes no state, so the rates carried from the step before it are valid
  after it.
- *The chain's Jacobian* is closed-form.
- *The chain's rates given `a`* are a separate function, and setting its state alone
  is a copy.
- *The pool.* Each member's pool mode is a scalar diagonal.
- *`∂a_ℓ/∂u_k`* is available as forward tangents.
- *Test members.* Existing machinery integrates zero-density test members against
  the fields a finished run recorded, on that run's step program. That gives `f(b)`
  at any creation time, at a member's cost per member.
- *The fields' adjoint* (`a` and `Φ`) exists inside the sweep, and is not exposed.
- *The value of a new member (A4)* is returned at every creation by a 207-line
  addition to the sweep.
- *The recording* names, per accepted step, the component that set its size and
  its error ratio. A replay outside the solver reproduces the solver's attempts bit
  for bit, rejected ones included.
- *Construction.* The grid is chosen off the tape and may use anything, including
  previous solves and previous iterates, subject to H1.
- *Reformulation.* The model may change if the change is declared and its effect on
  `J` and `dJ/dθ` is measured.

## Questions

1. At fixed accuracy in `J` and `dJ/dθ`, what sets the cost of this computation, and
   which of the structural features is load-bearing? Is the difficulty intrinsic to
   the structure, or an artifact of a representational choice not yet questioned —
   the time integration, the creation schedule, the member representation, the
   controller or the error norm? If intrinsic, state the precise obstruction. If
   representational, state the minimal change and its cost.

2. What should the time integration between stops be, given T1–T9 and R1–R4, and
   what can it guarantee about `J`'s time error? What produces the time error that
   tolerance does not control (T5, T6)?

3. What should the creation schedule be, and how should it be found — fast to find,
   lean to run — given S1–S7 and A4–A6? What error bound can it carry, given S1's
   floor and S6's cancellations?

4. How should one discretisation serve an optimisation across `θ` (Θ1–Θ6, A2, A3)?
   What is fixed and what adapts, what certifies it away from `θ0`, and what
   relative accuracy in `dJ/dθ` does a gradient-based optimiser need here?

5. What part, if any, should the reverse sweep and what it computes play in the
   answers to 2–4 (A1–A6)?

We may be looking at this through the wrong variable. An answer that rejects the
framing, and says which object should be adapted in its place, is welcome.
