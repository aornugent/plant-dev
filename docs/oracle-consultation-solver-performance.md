# Time integration of a forced chain and a growing ensemble: accuracy in `J`, and its cost

## The problem

A system of ODEs is integrated over a horizon `T = 40` against a known scalar forcing
record `s(t) ≥ 0`. The state is:
- a five-component chain `v`, driven by the forcing, with five accumulators beside it;
- an ensemble of members created at fixed times `b_j`, nine components each.

Members interact only through two fields that sum over the ensemble. The functional `J`
is a weighted sum of each member's accumulated output at `T`. `dJ/dθ`, for `θ` of about
twenty constants of the members' rates, comes from a reverse sweep that is exact for the
discretised model, and drives a gradient-based calibration of `θ`.

The integration is an adaptive explicit Runge–Kutta pair. It lands on every creation
time and on every one of the record's 2931 active knots, which are its only stops.

The cost is member evaluations. At every rate evaluation each member solves a nested
scalar root-finding problem, and the member loop is about 90% of the evaluation's cost.

Two things are observed:
- the error in `J` does not follow the tolerance: from `tol = 1e-2` to `1e-4` it takes
  either sign, up to `2.5e-3` relative, and stays within `1e-4` only from `tol = 1e-5`;
- the chain's components attain the error ratio's maximum on about 90% of accepted
  steps, whose median ratio is 0.044.

Wanted: `J` to a relative accuracy of about `1e-4` at the least cost, with an error that
follows the tolerance, and `dJ/dθ` from the sweep converging with it. The creation times
are held fixed throughout; how many members, and where, is not part of this question.

What follows gives the full model, its discretisation, a list of structural features, the
measurements and the facts an answer can rely on. The questions are at the end and are
open.

`δ = T/14 600` is the record's sampling interval, and short times are given in `δ`.
Rates are per unit time, where `T` is 40 units.

## The model

**The chain.**
```
v̇_ℓ  = in_ℓ − k·clamp(v_ℓ, 0, 1)^q − a_ℓ                   ℓ = 1…5,  k = 1.27e3,  q = 16.14
in_1 = s(t) · max(0, 1 − v_1^8),        in_ℓ = k·clamp(v_{ℓ−1}, 0, 1)^q
```
- A component at or below `v_res = 0.0234` has its rate set to `max(0, ·)`.
- Members read the chain only through `φ_ℓ = min(φ_max, c_φ·max(v_ℓ, v_res)^−6.57)`.
- Five accumulators take rates from `s`, `in_1`, `k·v_5^q` and `Σ a_ℓ`, one is
  constant, and none feeds back.

**The forcing.** `s(t)` is a shape-preserving `C¹` Hermite interpolant of control points
at spacing `δ`.
- It is identically zero over quiescent stretches, which are most of the record.
- It contains three long stretches of low forcing, near `t ∈ [7, 10]`, `[18, 22]` and
  `[31, 34]`.
- Its 2931 active knots are the points where the interpolant's second derivative jumps.

**The members.** Member `j` carries its coordinate `x`, a cumulative loss `m`, an output
integral `Y`, two smooth accumulations `V₁, V₂`, a bounded pool `S`, its accumulated
output `F`, and two panel moments `I, N`. At each rate evaluation:
```
p_j   = argmax over p ∈ [p_lo, p_hi] of R(p; x_j, φ, Φ)          the inner problem
P_j   = P(p_j; x_j, φ, Φ)                                        a scalar net rate
c_ℓj  = C_ℓ(p_j; x_j, φ)                                         its draw on v_ℓ
P⁺    = ½ (P + √(P² + ε²))                                       ε = 1e-4
r     = S / S_max(x),        G(r) = 1 / (1 + e^{−(r − 0.1)/0.1})
g     = P⁺ · G(r)
ẋ     = g · (1 − f(x)) · κ(x)
Ẏ     = g · f(x) / ν,        f(x) = 1 / (1 + e^{50 (1 − x)})
V̇₁, V̇₂  smooth functions of x alone
Ṡ     = [c (1 − r) − d r] / (1 + λ_S τ_s),   c = P⁺(1 − G),  d = P⁺ − P,  λ_S = (c + d)/S_max
ṁ     = μ(r) = μ₀ + μ₁ e^{−r/r₀},            μ₀ = 0.01,  μ₁ = 5.5,  r₀ = 0.05
Ḟ     = e^{−m} · (σ(t)/σ(b_j)) · Ẏ
```
- `κ`, `S_max` and `ν` are smooth and positive, and `τ_s = 7δ`. The coordinate is scaled
  so that the output switches on at `x = 1`.
- Around the members' sign changes of `P` (T4), `|P|` at the step ends has median 7.9
  and 10–90% range 0.0085–42.
- The pool's rate is `c ≥ 0` at `r = 0` and `−d ≤ 0` at `r = 1`. A guard throws where
  `S < −1e-8·S_max`.
- A member's density is `n_j = e^{−m_j}`. Its loss rate is parked at zero once `m`
  reaches a ceiling where the density is nil.
- `σ` is a smooth known function.

**Creation.** A member is created at `b_j` in a fixed creation state: `x = x_0`,
`S = 0.8·S_max(x_0)`, and the rest zero. The member that would be created now, at `b = t`,
is evaluated at every rate evaluation in the current fields and is not carried as a
state. Its net rate `P_new(t)` sets the creation probability
```
ρ_c(t) = ẽ(P_new(t)),     ẽ(P) = 1/(1 + (a₀/P)²) for P > 0, else 0      (C¹ at P = 0)
```
and only the newest member's two moments move:
```
İ_M = ρ_c(t),      Ṅ_M = (t − b_M) · ρ_c(t)
```

**The weights.** A panel `[b_k, b_{k+1}]` of width `Δ_k` holds `I_k = ∫ ρ_c dt` and
`N_k = ∫ (t − b_k) ρ_c dt`, which stop moving once the next member is created.
- Its hat-function shares are `I_k − N_k/Δ_k` to the member at `b_k` and `N_k/Δ_k` to the
  one at `b_{k+1}`. A member's weight `w_j` is the sum of its two shares.
- The newest panel is open, with `Δ_M = t − b_M`. It gives the newest member
  `I_M − N_M/Δ_M`, and the member at `b = t` the rest, `w_new = N_M/Δ_M`.

**The fields and the functional.**
```
a_ℓ  = Σ_j w_j n_j c_ℓj + w_new c_ℓ,new
Φ(z) = Σ_j w_j n_j A(z; x_j) + w_new A(z; x_new)
J    = c_J · Σ_j w_j π(b_j) F_j(T)                                   c_J = 0.25
```
- `Φ` is held as a cubic Hermite interpolant in `z/x_top` on 65 fixed knots, `x_top`
  being the largest coordinate. It is rebuilt at every rate evaluation from the exact sum
  and its slope at the knots.
- Each member contributes `A(z; x_j)` to `Φ`, and reads `Φ` on `[0, x_j]`.
- `π(b)` is a smooth known function.

**The inner problem.**
- `p_j` maximises a scalar objective on an interval, found by nested root-finding:
  - an outer bracketing root-find (TOMS748) on the objective's derivative, about 11
    evaluations;
  - two inner scalar root-finds in each of those evaluations, about 6 iterations each;
  - about 50 evaluations per solve of an auxiliary function of `φ_1 … φ_5`.
- The solution is interior in 85% of solves, at the interval's lower end in 15%, and in
  one of two terminal classes in under 0.2%. `p_j` is `C⁰` across the switches between
  classes.
- A clamp on a derived quantity inside the problem binds in most solves.
- Every solve starts cold, so the rates are deterministic functions of the state and time,
  repeated bit for bit. The innermost root-find stops at `1e-10` relative.

## The discretisation

**The stops.** The step sequence lands exactly on each of the 2931 active knots and each
of the 108 creation times, and on `T`.
- At a knot nothing happens: no state changes, and the rates and the step proposal carry
  across.
- At a creation the state grows by nine components, the rates are evaluated once at the
  wider state, and the proposal carries across.
- A stop at each knot keeps every step inside one cubic span of `s`. A stop costs no rate
  evaluation of its own, but it ends the step that reaches it.
- There are 3039 legs between stops: 73.5% are one `δ` long, and 10% are longer than
  `13δ`.

**The pair.** Cash–Karp 5(4), propagating the fifth-order solution. Each attempt
evaluates five stages and then the rates at its end, before the error test. An accepted
step's end rates are the next step's first stage. So an attempt costs six rate
evaluations, or the stages up to one that throws.

**The controller.**
- Error ratio: `ρ = max_i |est_i| / (tol·|y_i| + tol)` over every component, chain,
  accumulators and members alike. `est` is the embedded difference, and `y` the state at
  the attempt's end.
- Reject when `ρ > 1.1`: `h ← h·max(0.2, 0.9 ρ^{−1/5})`.
- Accept when `0.5 ≤ ρ ≤ 1.1`, with `h` unchanged.
- Accept when `ρ < 0.5`: `h ← h·clamp(0.9 ρ^{−1/6}, 1, 5)`.
- A stage that throws, or an end state the model refuses, retries at `0.2h`.
- A step clipped to reach a stop lands on it exactly. Accepted, it leaves the carried
  proposal as it was; rejected, it retries at the size its own `ρ` gives.
- `h_max = 5`, `h_min = 1e-6`, and the first step is `1e-6`.

**Cost** is member evaluations: the sum over rate evaluations of the members held.
- A member evaluation costs 15–20 µs. At 54 members the member loop is 91% of a rate
  evaluation's instructions, and the inner problem 85%; the chain's rates given `a` cost
  `1.4e3` instructions. These shares were profiled on an earlier version with the same
  inner problem.
- The reference run creates 108 members uniformly over `[0, 39.63]`, and holds 54 on
  average.

**The reverse sweep.**
- It runs over a recording of the forward run: one row per accepted step, holding the
  inner problem's solutions at each of the step's six evaluations.
- It reuses those solutions rather than solving again, and differentiates through them by
  the implicit-function theorem, along the branch each evaluation took.
- It is exact for the discretised model. The creation times and the step sizes are
  constants within one gradient.

## Structural features

Any of these may be load-bearing or incidental; which ones, is not known.
- The chain is one-way. Its loss term has exponent 16.14 and is clamped at `v = 1`, where
  the inflow also switches, and there is a floor at `v_res`.
- With `a` held, the chain's Jacobian is lower bidiagonal with diagonal `−q k v^{q−1}`:
  `2.05e4` at `v = 1`, a relaxation time of `0.018δ`, falling as `v^15.1`.
- The forcing is `C¹` with second-derivative jumps at its knots, and every knot is a stop.
- Members read the chain only through `φ`, which is floored and capped, and each other
  only through the two fields.
- The inner problem runs for every member at every rate evaluation. It has three solution
  classes, `C⁰` switches between them, and a clamp that binds in most solves.
- The flux `g` to a member's coordinate and output passes through `P⁺`. `P⁺` is smooth,
  with curvature `1/(2ε)` at `P = 0`, where `ε = 1e-4` against a `|P|` of `1e-2`–`1e2`.
- The pool filters `P` with a relaxation time of `S_max/(c + d)` plus `τ_s`. Its rate is
  bounded in sign at both bounds, and a guard throws below zero.
- The output is `g·f(x)`, and `f` is a logistic in the coordinate with scale `0.02`.
- The creation probability is `C¹` at `P_new = 0`.
- The creation weights are exact panel moments of `ρ_c`, and the newest panel is open.
- Members are never removed.
- The controller uses a max-norm over every component, a dead band of `[0.5, 1.1]` and a
  growth clamp of 5. A clipped step keeps the proposal, and a throw retries at `0.2h`.
- The sweep reuses the inner problem's recorded solutions, and the grid is a constant
  within one gradient.

## Measured

Unless stated, every measurement is on the reference run (108 members) at
`tol = 1e-3`. Relative errors in `J` are against T2's run at `tol = 1e-6`,
`J_ref = 12.668637`.

Every run below was made by one driver outside the solver. With the solver's own rule it
reproduces the solver's every attempt bit for bit: `J`, the attempt tallies, and each
step's time, size, error ratio and binding component. T5–T7 change one rule in it.

**(T1) What sets the step.**
- 9312 accepted steps, 1910 attempts rejected for accuracy and 149 thrown. That is
  `3.70e6` member evaluations, 18% of them on rejected attempts.
- The median accepted step's error ratio is 0.044, and 9.4% reach 0.5.
- The component attaining the error ratio's maximum is a chain component on **90.5%** of
  accepted steps (89.1% with 429 members), a member component on 9.5%, the pool among them
  on 2.7%, and an accumulator on none.
- At each accepted step's start, `h·|λ_chain|/β` is at least 0.5 on 55.3%, 0.8 on 29.5%
  and 1 on 13.3%. `β = 3.7343596` is the pair's real stability boundary.
- The median error ratio is 0.014, 0.077, 0.21, 0.25 and 0.013 across the bands below
  0.5, 0.5–0.8, 0.8–1, 1–1.2 and above 1.2 of `h·|λ_chain|/β`.
- The steps' 10/50/90/99% and largest sizes are 0.115, 0.454, 4.41, 15.6 and `33.9δ`.
- Legs one `δ` long hold 15.3% of the time and 64% of the accepted steps' member
  evaluations, at 2.66 accepted steps each. Longer legs take 4.18 each.
- 32.6% of accepted steps end at a stop, and 32.3% of legs are taken in one step.
- Accepted steps grow as `tol^−0.10`: 8018 at `1e-2`, 16 185 at `1e-5`.
- *After the forcing stops.* For `v̇ = −k v^q` alone the relaxation rate is exactly
  `q/((q−1)(t − t₀))`, with `t₀` set by `v` when the forcing stops. Along the run, the top
  component's `λ` times the time since the forcing was last non-zero has median 0.78 over
  the `60δ` after. `λ` is 0.36 per `δ` at `2–5δ` after, and 0.036 per `δ` at `10–20δ`.

**(T2) Tolerance does not control `J`'s time error.**

| `tol` | 1e-2 | 3e-3 | 1e-3 | 3e-4 | 1e-4 | 3e-5 | 1e-5 | 1e-6 |
|---|---|---|---|---|---|---|---|---|
| `J/J_ref − 1` | −2.1e-4 | +2.5e-3 | −2.4e-4 | +1.0e-3 | +8.2e-4 | +2.2e-4 | +3.8e-5 | 0 |
| accepted steps | 8018 | 8543 | 9312 | 10 428 | 11 813 | 13 833 | 16 185 | 23 188 |
| member evaluations | 3.42e6 | 3.52e6 | 3.70e6 | 4.07e6 | 4.64e6 | 5.48e6 | 6.41e6 | 9.17e6 |
| thrown | 288 | 193 | 149 | 102 | 51 | 22 | 15 | 4 |

With 429 members, against its own run at `1e-6` (12.737409), `tol = 1e-2 … 1e-4` gives
+6.1e-4, +9.7e-4, +4.9e-4, +1.1e-3 and +8.1e-4.

**(T3) Where the error accrues.** At `tol = 1e-4`, against T2's run at `1e-6`:
- `J`'s error is **+8.7e-4 from the members' `F`**, and −5.4e-5 from the weights.
- Weighting each member's `F` error by its final weight in `J`, the error accrued by
  `t = 12`, 15, 20 and 40 is `3e-7`, `1.2e-4`, `7.7e-4` and `8.7e-4`.
- It accrues mostly in legs `20–93δ` long in quiescent stretches, where the run takes
  about a third of the `1e-6` run's steps.
- Members created before `b = 3.5` hold 93% of `J`, and carry the error.

**(T4) The steps that carry it.** The ten legs of largest increment were re-integrated at
`tol = 1e-4` from the `1e-6` run's state at each leg's start. Each step was then retaken
from its own start at `tol = 1e-9`, which gives its true error.

| steps | number | true error over twice the estimate | median true ÷ estimate | share of the `F` error |
|---|---|---|---|---|
| across which some member's `P` changes sign | 15 | 14 | 4.6 | 81% |
| the rest | 94 | 4 | 0.45 | 19% |

- *One of them.* A `5.5δ` step at `t = 15.49` had an estimate of 1.09 and a true error of
  3.46 tolerance weights, in one member's `Y`. Along it, that member's `P` falls from
  +1.6 to −0.2 in `0.7δ`, and its `Ẏ` from 1.3 to `1e-8`.
- *The width of the turn.* `2ε/|dP/dt|` is `5.4e-5δ` at the median crossing, and
  `0.035δ` at the 90th percentile. `|dP/dt|` there has median `1.35e3`.
- *How often.* A run at `1e-4` meets 9220 sign changes of `P`, 4601 of them downward, by
  107 members: a median of 85 per member. Counting crossings within `0.25δ` of each other
  as one, they are 921 events, and 3241 within `0.05δ`. 362 of its 11 813 steps straddle
  at least one.
- The crossings fall in every quiescent stretch. `J`'s error accrues over `t = 12–20`, as
  the members that hold `J` pass `x = 1` and their output switches on: the first at
  `t = 14.3`, the tenth at 21.9.

**(T5) Refusing long steps across a crossing of `P`.** A step is refused and retried at
half its size when it is longer than a cap `h_c` and some member's `P − P_c` has a
different sign at its end from its start. Nothing else changes.

With `P_c = 0` and `h_c = 0.05δ`:

| `tol` | 1e-3 | 3e-4 | 1e-4 | 3e-5 | 1e-5 | 1e-6 |
|---|---|---|---|---|---|---|
| `J/J_ref − 1` | −3.0e-4 | −9.7e-5 | −1.1e-5 | +1.2e-5 | +5.9e-6 | +1.2e-5 |
| against its own `1e-6` | −3.1e-4 | −1.1e-4 | −2.3e-5 | +5e-7 | −5.8e-6 | 0 |
| accepted steps | 17 929 | 19 029 | 20 308 | 22 094 | 24 170 | 30 589 |
| member evaluations | 1.51e7 | 1.54e7 | 1.59e7 | 1.63e7 | 1.68e7 | 1.88e7 |

The crossing value and the cap varied, against `J_ref`:

| `P_c`, `h_c` | `tol = 3e-4` | `tol = 1e-4` | member evaluations at `1e-4` | refused attempts at `1e-4` |
|---|---|---|---|---|
| none (T2) | +1.0e-3 | +8.2e-4 | 4.64e6 | — |
| 0, `0.05δ` | −9.7e-5 | −1.1e-5 | 1.59e7 | 21 581 |
| 0, `0.5δ` | −1.5e-4 | −8.9e-5 | 6.27e6 | 3182 |
| 3, `0.05δ` | −3.6e-5 | −2.0e-4 | 1.22e7 | 13 623 |
| 10, `0.05δ` | +2.7e-4 | +3.0e-4 | 1.22e7 | 13 173 |

**(T6) Holding the chain inside the pair's stability boundary.** Each step starts at
`h ≤ 0.8β/|λ_chain|`, from the chain's diagonal at the step's start. Nothing else changes.

| `tol` | 1e-2 | 3e-3 | 1e-3 | 3e-4 | 1e-4 | 3e-5 | 1e-5 |
|---|---|---|---|---|---|---|---|
| `J/J_ref − 1` | −4.6e-4 | +7.8e-4 | −7.7e-4 | +1.0e-3 | +8.0e-4 | +2.5e-4 | +4.3e-5 |
| accepted steps | 9328 | 9499 | 9962 | 10 865 | 12 087 | 13 952 | 16 210 |

- Every step starts at or below `0.8β`. At `1e-4`, 0.4% end beyond `β`.
- It removes 46–76% of the accuracy rejections at `1e-2 … 1e-3` (573 against 2348 at
  `1e-2`), and leaves the member evaluations within 4% of T2's.
- Rate evaluations at chain states beyond the loss clamp fall by about half: 1113 against
  2541 at `1e-3`.

**(T7) The chain's loss and inflow taken implicitly.** ARK4(3)6L[2]SA: Kennedy and
Carpenter's six-stage additive pair.
- Its implicit part is `in_ℓ − k·clamp(v_ℓ, 0, 1)^q` on the chain, the clamp and the
  inflow switch included. Its explicit part is everything else: `a`, the members, the
  accumulators, and the floor at `v_res`, which acts on the full rate.
- Each stage solves the chain's `Y = Z + hγ F_I(Y)` by Newton, with the exact bidiagonal
  Jacobian, halving a Newton step until the residual falls. The members are evaluated once
  per stage at the solved chain state.
- The error estimate is the pair's embedded difference, in the same norm and controller,
  with `ρ^{−1/4}` and `ρ^{−1/5}`.

| `tol` | 1e-2 | 3e-3 | 1e-3 | 3e-4 | 1e-4 | 3e-5 | 1e-5 | 1e-6 |
|---|---|---|---|---|---|---|---|---|
| `J/J_ref − 1` | −0.41 | −0.19 | −7.6e-2 | −1.0e-2 | −4.9e-4 | +8.4e-4 | +2.7e-5 | −6.8e-5 |
| accepted steps | 3759 | 4261 | 5610 | 7307 | 9200 | 11 760 | 14 790 | 24 085 |
| member evaluations | 1.30e6 | 1.51e6 | 2.09e6 | 2.80e6 | 3.58e6 | 4.64e6 | 5.84e6 | 9.53e6 |
| thrown | 405 | 221 | 161 | 103 | 68 | 37 | 43 | 40 |

- The chain still attains the error ratio's maximum on 87–89% of accepted steps.
- No Newton solve fails in `3e4`–`1.5e5` stage solves: 3.7–4.5 iterations each, at most 21.
  From `1e-3` down no rate evaluation is at a chain state beyond the loss clamp or the
  inflow switch.
- It is within `1e-4` of `J_ref` only from `tol = 1e-5`, where it takes 9% fewer member
  evaluations than T2. At `1e-3` it takes 43% fewer, at a `J` 7.6% low.
- *Its estimate.* Retaken from its own state, its `11.2δ` step at `t = 4.75`, at the start
  of a quiescent stretch with `h|λ_chain| = 5.6β`, has a true error in `v_1` of 11.5
  tolerance weights against an estimate of 0.75. In `v_4` it is 6.9 against 0.03. The step
  leaves `v_1` 0.033 too low, and every member's `F` increment 0.5–0.8% too low.
- 96% of its deficit at `1e-3` is in the members created before `b = 3.5`.
- *Against an earlier prediction.* An earlier analysis attributed the error that the
  tolerance does not control to stages taken near the chain's stability boundary, which
  T6 tests directly. It predicted that this pair, with the pools implicit as well, would
  make `J` monotone over `tol = 1e-2 … 1e-4` with a spread well under `1e-4`, and remove
  the rejections and the throws. It counted the members' switches as a floor that would
  remain. Here the pools were explicit, and under this pair they set 3.4–4.7% of the
  steps. `J` is monotone over that range, with a spread of 0.41, and not monotone below it.

**(T8) The stops.**
- Without the stops at the knots, `J` is **−68%**: 7860 accepted steps, 2975 rejected for
  accuracy and 558 thrown.
- A cap of `h ≤ 5δ` in their place gives −0.70%.
- The pair's abscissae `{0, 0.2, 0.3, 0.6, 1, 0.875}·h` step over forcing events narrower
  than `0.3h`, and its estimate does not see them.

**(T9) Rejections and throws.**
- At `1e-3`, 18% of attempts are rejected: 1910 for accuracy and 149 by a throw.
- Every throw is the pool guard.
  - Two thirds are at steps above `15δ` (median `17.5δ`), where a stage of an emptying
    pool with a relaxation time near `τ_s` goes negative. For `y' = −y/τ` the pair's
    fourth stage goes negative past `h = 2.16τ`, and the step loses stability past
    `3.73τ`.
  - The rest are shorter steps in which a near-empty pool's stage rates differ in sign.

**(T10) Decompositions tried before.** Measured on earlier versions of this model and on
test fixtures, not the reference run.

| decomposition | measured |
|---|---|
| multirate infinitesimal step, chain fast, members slow | each fast evaluation re-runs the member loop; ~10 micro-steps per macro step; 6–25× the cost of the single-rate pair at converged `J` |
| the same, with the chain's loss integrated in closed form inside the fast step, on another fixture | more micro-steps (103 against 58 per macro step), 0.6× the speed |
| the fast coupling from `n_f ≪ M` members | `n_f = 20`: 14% `J` error at `M = 352`; `n_f = 40`: 2.4% at 2× the cost |
| the coupling held, linearised or tabulated over a macro step | held: an error plateau of 0.1; linearised: up to 440% error in `a` as `v` falls |
| fast chain against an affine coupling `a(v₀) + D(v − v₀)`, `D = ∂a/∂v` exact | constant forcing: 40× fewer member sweeps; periodic forcing: 3.8× at a `J` error of `3.5e-3`, 1.0× at `≤ 4e-4` |
| a Rosenbrock step for the chain, its Jacobian differenced through the full rates and factorised at full size | 19 member-loop evaluations and a dense full-size factorisation per step; 20–50× slower |
| an implicit pool inside the member loop (a four-stage ESDIRK) | an emptying pool's stages go negative past `hλ = 3.1`, against the explicit pair's 2.16 |

## Facts an answer can rely on

**(H1) Within one gradient the grid is a constant.** A step size or a stop that moves with
`θ` makes the reported derivative that of a different function at each point. Between
gradients the grid may change, and the step sizes are chosen per run.

**(H2) The sweep follows the branches the run took.** Each evaluation is differentiated
along the branch it took at each clamp, switch and solution class. A step size or a stop
decided during the run is a constant of the recording, by H1.

**(H3) The recording's shape.** One row per accepted step and one per creation. A step's
row holds its six evaluations, each with the inner problem's solutions, and the sweep
repeats each evaluation where it ran. An implicit stage needs its solve on the recording,
as recorded arithmetic or as implicit-function rows.

**(H4) The sweep's cost** is about 2.5 forward runs, and scales with the same count of
member evaluations.

**Free:**
- *Advance knowledge.* The forcing record and every creation time are known before the
  run.
- *Stops.* A stop can be put at any time.
- *Readings.* Every rate evaluation also returns, at no cost, each member's `P` and its
  inner problem's solution class, `P_new`, and the chain's diagonal.
- *Interpolation.* A step's start and end states and rates are at hand, so a cubic
  Hermite interpolant over it costs nothing. The pair has no continuous extension of its
  own.
- *The chain's rates given `a`* are a separate function.
- *The members' `∂a_ℓ/∂v_k`* is available as forward tangents, at about twice a member
  evaluation per direction.
- *A test bed.* The driver of the measurements reproduces the solver bit for bit and takes
  any stepping rule, so a proposed rule can be measured before it is built.
- *Reformulation.* The model may change if the change is declared and its effect on `J`
  and `dJ/dθ` is measured.

## Questions

1. Is what T2–T8 measure a known class of problem, and what are its standard treatments?
   Which of the structural features is load-bearing for `J`'s time error, and which for
   the cost?

2. What should the integration between stops be, so that `J`'s time error follows the
   tolerance? At what cost in member evaluations, and what can it then guarantee about
   `J`'s error?

3. The chain attains most steps' error-ratio maximum, and relaxes at a rate that falls
   with its own state (T1, T7). What is the least number of member evaluations at which
   `J` can be held to about `1e-4`, and what treatment of the chain and of the members
   attains it? Can the difference between the chain's time scales and the members' be
   exploited, and how?

4. Under that treatment, what must hold for `dJ/dθ` from the sweep to converge with `J`,
   given H1–H3?

We may be looking at this through the wrong variable. An answer that rejects the framing,
and says which object should be treated in its place, is welcome.
