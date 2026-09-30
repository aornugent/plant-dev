# Time integration of a forced chain and a growing ensemble: where the error in `J` comes from, and its cost

## The problem

A system of ODEs is integrated over a horizon `T = 40` against a known scalar forcing
`s(t) ≥ 0`. The state is:
- a five-component chain `v`, driven by the forcing, with five accumulators beside it;
- an ensemble of members created at fixed times `b_j`, nine components each.

Members interact only through two fields that sum over the ensemble. The functional `J`
is a weighted sum of each member's accumulated output at `T`. `dJ/dθ`, for `θ` of about
twenty constants of the members' rates, comes from a reverse sweep that is exact for the
discretised model, and drives a gradient-based calibration of `θ`.

The integration is an adaptive explicit Runge–Kutta pair. It lands on every creation
time and on every one of the forcing's 2931 active knots, which are its only stops.

The cost is member evaluations. At every rate evaluation each member solves a nested
scalar root-finding problem, and the member loop is about 90% of the evaluation's cost.

The error in `J` does not follow the tolerance. From `tol = 1e-2` to `1e-4` it takes either
sign, up to `2.5e-3` relative, and it is within `1e-4` only from `tol = 1e-5` (T2).

Wanted: `J` to a relative accuracy of about `1e-4` at the least cost, with its time error
predictable from one setting of the integration, across `θ`. Today that setting is the
tolerance, and by "follows the tolerance" we mean an error that falls roughly in
proportion to `tol` over `tol = 1e-3 … 1e-5`. `dJ/dθ` from the sweep must converge with `J`
(H1–H3); its convergence is not measured here. The creation times are held fixed; how
many members, and where, is not part of this question.

What follows gives the full model, its discretisation, a list of structural features, the
measurements and the facts an answer can rely on. The questions are at the end and are
open. An earlier version of this statement drew a reply whose proposals are measured
here (T12–T15).

`δ = T/14 600` is the forcing's sampling interval, and short times are given in `δ`.
Rates are per unit time, where `T` is 40 units.

## The model

**The chain.**
```
v̇_ℓ  = in_ℓ − k·clamp(v_ℓ, 0, 1)^q − a_ℓ                   ℓ = 1…5,  k = 1.27e3,  q = 16.14
in_1 = s(t) · max(0, 1 − v_1^8),        in_ℓ = k·clamp(v_{ℓ−1}, 0, 1)^q
```
- A component at or below `v_floor = 0.0234` has its rate set to `max(0, ·)`.
- Members read the chain only through `φ_ℓ = min(φ_max, c_φ·max(v_ℓ, v_floor)^−6.57)`.
- Five accumulators take rates from `s`, `in_1`, `k·clamp(v_5, 0, 1)^q` and `Σ a_ℓ`, one
  is constant, and none feeds back.

**The forcing.** `s(t)` is a shape-preserving `C¹` Hermite interpolant of control points
at spacing `δ`.
- It is identically zero over quiescent stretches, which are most of the horizon. It is
  positive over 814 pulses, each `2–4δ` long, separated by gaps of median `8δ`; 175 gaps
  are longer than `20δ`.
- Near `t ∈ [7, 10]`, `[18, 22]` and `[31, 34]` its pulses are smaller and rarer.
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
Ṡ     = [u⁺ (1 − r) − u⁻ r] / (1 + λ_S τ_s),   u⁺ = P⁺(1 − G),  u⁻ = P⁺ − P,  λ_S = (u⁺ + u⁻)/S_max
ṁ     = μ(r) = μ₀ + μ₁ e^{−r/r₀},              μ₀ = 0.01,  μ₁ = 5.5,  r₀ = 0.05
Ḟ     = e^{−m} · (σ(t)/σ(b_j)) · Ẏ
```
- `κ` and `S_max` are smooth positive functions of `x`, `ν` is a positive constant, and
  `τ_s = 7δ`. The coordinate is scaled so that the output switches on at `x = 1`.
- `S_max` grows with `x`. Along the run, the pools' largest values are 4.6 in the
  earliest-created members and `2e-3` in the latest-created, in the units in which the
  state is integrated.
- The pool's rate is the filling term `u⁺(1 − r)` while `P > 0` and the emptying term
  `−u⁻r` while `P < 0`, so it switches between them where `P` crosses zero. It is
  `u⁺ ≥ 0` at `r = 0` and `−u⁻ ≤ 0` at `r = 1`, and a guard throws where
  `S < −1e-8·S_max`.
- `n_j = e^{−m_j}`. The loss rate is parked at zero once `m` reaches a ceiling where `n_j`
  is nil.
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

**The weights.** Member `j`'s panel `[b_j, b_{j+1}]`, of width `Δ_j`, holds
`I_j = ∫ ρ_c dt` and `N_j = ∫ (t − b_j) ρ_c dt`, which stop moving once member `j + 1` is
created.
- Its hat-function shares are `I_j − N_j/Δ_j` to member `j` and `N_j/Δ_j` to member
  `j + 1`. A member's weight `w_j` is the sum of its two shares.
- The newest member `M`'s panel is open, with `Δ_M = t − b_M`. It gives member `M`
  `I_M − N_M/Δ_M`, and the member at `b = t` the rest, `w_new = N_M/Δ_M`.

**The fields and the functional.**
```
a_ℓ  = Σ_j w_j n_j c_ℓj + w_new c_ℓ,new
Φ(z) = Σ_j w_j n_j A(z; x_j) + w_new A(z; x_new)
J    = c_J · Σ_j w_j π(b_j) F_j(T)                                   c_J = 0.25
```
- `Φ` is held as a cubic Hermite interpolant in `z/x_max` on 65 fixed knots, `x_max` being
  the largest coordinate. It is rebuilt at every rate evaluation from the exact sum and
  its slope at the knots.
- Each member contributes `A(z; x_j)` to `Φ`, and reads `Φ` on `[0, x_j]`.
- `π(b)` is a smooth known function.

**The inner problem.**
- `p_j` maximises a scalar objective on an interval, found by nested root-finding:
  - an outer bracketing root-find (TOMS748) on the objective's derivative, about 11
    evaluations;
  - two inner scalar root-finds in each of those evaluations, about 6 iterations each;
  - about 50 evaluations per solve of an auxiliary function of `φ_1 … φ_5`.
- `P` is the difference of two non-negative terms, `P = P_a − P_b`, and `P_b` grows with
  `x`. Along the run, `P` falls through zero in long quiescent stretches and rises back
  through it in the pulse that ends them (T3).
- At the accepted states of the run at `tol = 1e-6` the solution is interior in 96.2% of
  member-states and at the interval's lower end in 3.8%; no other class occurs there.
  `p_j` is `C⁰` across a switch between classes, so `P_j` and `c_ℓj` have a kink there.
- A clamp on a derived quantity inside the problem binds in most solves. Its binding is
  not tallied, so how often it changes within a step is not known.
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

**The pair.** Cash–Karp 5(4), propagating the fifth-order solution, with abscissae
`c_i ∈ {0, 0.2, 0.3, 0.6, 1, 0.875}`. Each attempt evaluates five stages and then the rates
at its end, before the error test. An accepted step's end rates are the next step's first
stage. So an attempt costs six rate evaluations, or the stages up to one that throws.

**The controller.**
- Error ratio: `ρ = max_n |est_n| / σ_n` over every component `n`, chain, accumulators and
  members alike, with the error scale `σ_n = tol·|y_n| + tol` in the component's own units.
  `est` is the embedded difference, and `y` the state at the attempt's end.
- Reject when `ρ > 1.1`: `h ← h·max(0.2, 0.9 ρ^{−1/5})`.
- Accept when `0.5 ≤ ρ ≤ 1.1`, with `h` unchanged.
- Accept when `ρ < 0.5`: `h ← h·clamp(0.9 ρ^{−1/6}, 1, 5)`.
- A stage that throws, or an end state the model refuses, retries at `0.2h`. Every throw
  measured here is the pool's guard.
- A step clipped to reach a stop lands on it exactly. Accepted, it leaves the carried
  proposal as it was; rejected, it retries at the size its own `ρ` gives.
- `h_max = 5`, `h_min = 1e-6`, and the first step is `1e-6`.

**Cost** is member evaluations: the sum over rate evaluations of the members held.
- A member evaluation costs 15–20 µs. At 54 members the member loop is 91% of a rate
  evaluation's instructions, and the inner problem 85%; the chain's rates given `a` cost
  `1.4e3` instructions. These shares were profiled on a version with the same inner
  problem.
- The test instance creates 108 members evenly spaced over `[0, 39.63]`, and holds 54 on
  average.

**The reverse sweep.**
- It runs over a recording of the forward run: one row per accepted step and one per
  creation, a step's row holding the inner problem's solutions at each of its six
  evaluations.
- It reuses those solutions rather than solving again, and differentiates through them by
  the implicit-function theorem, along the branch each evaluation took.
- It is exact for the discretised model. The creation times and the step sizes are
  constants within one gradient.

## Structural features

Any of these may be load-bearing or incidental; which ones, is not known.
- The chain is one-way. Its loss term has exponent 16.14 and is clamped at `v = 1`, where
  the inflow also switches, and there is a floor at `v_floor`.
- With `a` held, the chain's Jacobian is lower bidiagonal. Its diagonal is `−q k v^{q−1}`,
  and for `ℓ = 1` also `−8 s v_1^7`: `2.05e4` at `v = 1`, a relaxation time of `0.018δ`,
  falling as `v^15.1`. `|λ_chain|` below is the largest diagonal magnitude.
- The forcing is `C¹` with second-derivative jumps at its knots, and every knot is a stop.
- Members read the chain only through `φ`, which is floored and capped, and each other
  only through the two fields.
- The inner problem runs for every member at every rate evaluation. Its solution class
  switches, `C⁰`, and a clamp inside it binds in most solves.
- `P⁺` is smooth, with curvature `1/(2ε)` at `P = 0`, where `ε = 1e-4` against `|P|` values
  mostly between `1e-2` and `1e2` (T15). The coordinate's rate, the output and both of the
  pool's terms pass through it.
- The pool filters `P` with a relaxation time of `S_max/(u⁺ + u⁻)` plus `τ_s`, is bounded
  in sign at both bounds, and a guard throws below zero. It empties over long quiescent
  stretches and fills in pulses.
- The output is `g·f(x)`, and `f` is a logistic in the coordinate with scale `0.02`.
- The creation probability is `C¹` at `P_new = 0`.
- The creation weights are exact panel moments of `ρ_c`, and the newest panel is open.
- Members are never removed.
- The controller uses a max-norm over every component in its own units, with the same
  absolute part `tol` in every error scale; a dead band of `[0.5, 1.1]`; and a cap of 5 on
  the step's increase. A clipped step keeps the proposal, and a throw retries at `0.2h`.
- The sweep reuses the inner problem's recorded solutions, and the grid is a constant
  within one gradient.

## Measured

Every run below except T17's is on the test instance, made by one driver outside the
solver. With the solver's own rule it reproduces the solver's every attempt bit for bit:
`J`, the attempt tallies, and each step's time, size, error ratio and binding component.
Each measurement changes the driver's rules as stated, or reads its runs. Relative errors
in `J` are against `J*` unless stated.

**(T0) The reference.** `J* = 12.6687135 ± 6e-7`, from the pair at `tol = 1e-8`. The pair at
`1e-7` is `−4.5e-8` from it, and T5's refusal with `P_c = 0` and `h_c = 0.005δ`, at
`tol = 1e-7`, is `+6.3e-7`.

**(T1) What sets the step** (at `tol = 1e-3`).
- 9312 accepted steps, 1910 attempts rejected for accuracy and 149 thrown: `3.70e6`
  member evaluations, 18% of them on rejected attempts.
- The median accepted step's error ratio is 0.044. A chain component attains the ratio's
  maximum on 90.5% of accepted steps, a member component on 9.5% (the pool on 2.7%).
- `h·|λ_chain|/β` at a step's start is at least 0.5 on 55.3% of steps and 1 on 13.3%;
  `β = 3.7343596` is the pair's real stability boundary.
- Legs one `δ` long hold 15.3% of the time and 64% of the accepted steps' member
  evaluations, at 2.66 accepted steps each. Longer legs take 4.18 each.
- Accepted steps grow as `tol^−0.10`: 8018 at `1e-2`, 16 185 at `1e-5`.
- While `s > 0`, `v_1` has median 0.85 (10–90%: 0.61–0.92), and `|λ_chain|` median
  `1.85e3` (10–90%: `12`–`6.2e3`).

**(T2) Tolerance does not control `J`'s time error.**

| `tol` | 1e-2 | 3e-3 | 1e-3 | 3e-4 | 1e-4 | 3e-5 | 1e-5 | 1e-6 |
|---|---|---|---|---|---|---|---|---|
| `J/J* − 1` | −2.1e-4 | +2.5e-3 | −2.4e-4 | +1.0e-3 | +8.1e-4 | +2.1e-4 | +3.2e-5 | −6.1e-6 |
| member evaluations | 3.42e6 | 3.52e6 | 3.70e6 | 4.07e6 | 4.64e6 | 5.48e6 | 6.41e6 | 9.17e6 |

**(T3) The crossings of `P = 0`.**
- 9237 along the run at `tol = 1e-6` (9220 at `1e-4`), by 107 members. Of the crossings, 4
  are a member crossing again within `0.05δ`.
- They come in 196 clusters. 98 are downward, one in each quiescent stretch that holds
  any (those stretches have median length `46δ`): median 45 crossings each, spread over
  `6.3δ` (10–90%: `1.2`–`12δ`), a median `32δ` after `s` was last non-zero, with `|Ṗ|`
  median 616. 98 are upward, in the pulse that ends each such stretch: spread over
  `0.31δ`, a median `0.64δ` after the pulse starts, with `|Ṗ|` median `9.3e3`.
- A straddled kink: for this pair, a step across a slope jump of a pure quadrature's
  integrand at fraction `ϑ` of the step errs by `h²·[jump]·K(ϑ)`, with
  `K(ϑ) = Σ b_i (c_i − ϑ)₊ − (1 − ϑ)²/2`. The mean of `K` over `ϑ ∈ [0, 1]` is zero (the
  third-order condition); its rms is 0.005. The embedded difference responds with
  `K̂(ϑ) = Σ (b_i − b̂_i)(c_i − ϑ)₊`, and `|K|/|K̂|` has median 3.4 over `ϑ` (25–75%:
  1.7–11). On the crossing steps of ten traced legs at `tol = 1e-4`, true error over
  estimate had median 4.6.
- Summing that error over every straddled crossing, for the output alone, with `ϑ` from
  `P` at the step's ends, predicts an output part (T6) of `+1.8e-4` at `tol = 1e-3` and
  `+5.4e-5` at `3e-4`. T6 measures `+1.34e-3` and `−9.4e-5`.

**(T4) The inner problem's class switches.** 7909 along the run at `tol = 1e-6`, all
between the interior class and the lower end, their times resolved to a median `0.55δ`.
- Into the lower end: a median `6.6δ` after the member's last downward crossing of
  `P = 0` (10–90%: `3.4`–`12δ`); `P < 0` just after it in 99%. 1.1% fall in the same step
  as a crossing by that member.
- Out of it: a median `0.26δ` before the member's next upward crossing (10–90%:
  `0.08`–`1.35δ`). 10.7% fall in the same step as that crossing.
- `P < 0` in 99.8% of the accepted member-states at the lower end.

**(T5) Refusing long steps across a crossing.** A step is refused and retried at half its
size when it is longer than `h_c` and some member's `P − P_c` has a different sign at its
end from its start. Nothing else changes.

| `P_c`, `h_c` | `tol = 1e-3` | `3e-4` | `1e-4` | `3e-5` | `1e-5` | member evaluations at `1e-4` |
|---|---|---|---|---|---|---|
| none (T2) | −2.4e-4 | +1.0e-3 | +8.1e-4 | +2.1e-4 | +3.2e-5 | 4.64e6 |
| 0, `0.05δ` | −3.1e-4 | −1.0e-4 | −1.7e-5 | +6.1e-6 | −2.2e-7 | 1.59e7 |
| 0, `0.5δ` | | −1.5e-4 | −9.5e-5 | | | 6.27e6 |
| 3, `0.05δ` | | −4.2e-5 | −2.0e-4 | | | 1.22e7 |
| 10, `0.05δ` | | +2.6e-4 | +2.9e-4 | | | 1.22e7 |

**(T6) Where `J`'s error travels,** against the run at `tol = 1e-7`. Over each interval
between times both runs land on, `F_j` grows by `∫ e^{−m_j}(σ/σ_b) Ẏ dt`. The loss part
is `Σ_j w_j (e^{−Δm_j} − 1) ΔF_j`, with `Δm_j` the runs' difference in `m_j` averaged over
the interval's two ends and `ΔF_j` the reference's increment of `F_j`. The output part is
the rest of the difference in `F`, and the weights' part is `J`'s error less both.

| `tol` | `J`'s error | loss part | output part | weights' part |
|---|---|---|---|---|
| 1e-3 | −2.4e-4 | −1.67e-3 | +1.34e-3 | +8.5e-5 |
| 3e-4 | +1.04e-3 | +1.16e-3 | −9.4e-5 | −2.6e-5 |
| 1e-4 | +8.1e-4 | +4.8e-4 | +3.9e-4 | −5.2e-5 |
| 1e-5 | +3.2e-5 | +6.7e-5 | −3.1e-5 | −3.7e-6 |

- At `tol = 1e-4` the difference in `m` grows mostly between `t ≈ 3` and 14, in the three
  earliest-created members, over quiescent stretches in which their pools empty. It
  enters `F` from `t ≈ 14` to 20, as their output switches on.
- Counting each interval's share as its change in the `m` difference times the output
  still to come, the largest shares are over such stretches. Over one `135δ` stretch the
  second member's pool falls from 0.068 to `7e-5`, with `P ≈ −15` throughout.
- Retaken at `tol = 1e-4` from the `1e-6` run's state at that stretch's start, the stretch
  adds `−3.5e-6` to the member's `m`, and no step's true error exceeds twice its estimate.
  The `1e-4` run's pool arrives at the stretch `1.7e-3` (relative) from the `1e-6` run's.
- The largest jumps in that relative difference, 1–2.5%, are over intervals just after
  the member's preceding upward crossings, with its pool at `0.006`–`0.008`.

**(T7) The pools.** They sit below 1% of their largest value for 30% of member-time, and
for 19% in the ten earliest-created members, whose pools reach `3e-10`. Their relative
error by tolerance, against the run at `1e-7`, in those ten members at the times both runs
land on:

| `tol` | 1e-3 | 3e-4 | 1e-4 | 1e-5 | 1e-6 |
|---|---|---|---|---|---|
| below 2% of its largest value, `P > 0`: median | 4.0e-4 | 5.2e-4 | 2.2e-4 | 1.1e-4 | 8.0e-6 |
| 90% | 3.3e-3 | 3.2e-3 | 2.0e-3 | 3.8e-4 | 3.8e-5 |
| above half its largest value: median | 9.0e-5 | 3.9e-5 | 2.7e-5 | 2.9e-6 | 4.5e-7 |
| 90% | 1.4e-3 | 3.2e-4 | 2.5e-4 | 2.1e-5 | 2.8e-6 |

**(T8) One error scale changed.** The pools' error scales multiplied by 0.01, or only
their absolute part, and nothing else.

| | `tol = 1e-3` | `3e-4` | `1e-4` | `3e-5` | member evaluations at `3e-4` / `1e-4` |
|---|---|---|---|---|---|
| unchanged (T2) | −2.4e-4 | +1.0e-3 | +8.1e-4 | +2.1e-4 | 4.07e6 / 4.64e6 |
| `0.01·(tol·S + tol)` | −3.6e-4 | +1.2e-4 | +1.2e-5 | +1.0e-5 | 4.75e6 / 5.53e6 |
| `tol·S + 0.01·tol` | | +1.3e-4 | +7.8e-5 | | 4.17e6 / 4.81e6 |

- With both parts scaled, at `1e-4`, 1202 of the 1561 added accepted steps end within
  `2δ` of a crossing of `P = 0`, and the pool attains the ratio's maximum on 22.5% of
  accepted steps.

**(T9) Holding the chain inside the pair's stability boundary.** Each step starts at
`h ≤ 0.8β/|λ_chain|`. `J/J* − 1` is −4.6e-4, +7.7e-4, −7.7e-4, +1.0e-3, +7.9e-4, +2.5e-4
and +3.7e-5 at `tol = 1e-2 … 1e-5`, with member evaluations within 4% of T2's.

**(T10) The chain's loss and inflow taken implicitly.** ARK4(3)6L[2]SA, its implicit part
`in_ℓ − k·clamp(v_ℓ, 0, 1)^q` on the chain, solved at each stage by a damped Newton with
the exact bidiagonal Jacobian; everything else explicit.
- `J/J* − 1` is −0.41, −0.19, −7.6e-2, −1.0e-2, −4.9e-4, +8.3e-4, +2.1e-5 and −7.4e-5 at
  `tol = 1e-2 … 1e-6`, for `1.30e6 … 9.53e6` member evaluations (`2.09e6` at `1e-3`,
  `5.84e6` at `1e-5`).
- At `tol = 1e-3`, retaken from its own state, its `11.2δ` step at the start of a
  quiescent stretch (`h|λ_chain| = 5.6β`) has a true error in `v_1` of 11.5 error scales
  against an estimate of 0.75.
- For `v̇ = −k v^q` alone the relaxation rate is `q/((q−1)(t − t₀))`, `t₀` a virtual origin
  set by `v` when `s` stops. Along the run, `v_1`'s relaxation rate times the time since
  `s` was last non-zero has median 0.78 over the `60δ` after.

**(T11) The chain's draw.** The ratio `|a_1|/(in_1 + k·clamp(v_1, 0, 1)^q)` has median
0.0098 (10–90%: 0.002–0.062) while `s > 0`, and 1.09 (0.07–3.4e4) while `s = 0`; for
components 2–5 it is below 0.005 while `s > 0`. Over a one-`δ` leg, `a_1` varies by 0.17%
of its largest value (median; 90%: 2.6%), and a quadratic fit in time leaves an rms
residual of `2e-5` of it.

**(T12) Stepping onto the crossings.** An accepted attempt across which some member's
`P` changes sign is retaken so that it ends where the first such member's `P` is `η` past
zero, `η = 1e-3`. The crossing is found by regula falsi on the step's cubic Hermite
interpolant, and a member ending within `3η` of zero counts as at the step's end. The
next step starts at the proposal the retaken step started with.

| | `tol = 1e-3` | `3e-4` | `1e-4` | `3e-5` | member evaluations at `1e-4`, plus the location's |
|---|---|---|---|---|---|
| as above | −2.2e-4 | +9.7e-5 | +2.6e-4 | +2.8e-4 | 1.33e7 + 1.75e6 |
| next step started at `0.05δ` | | | +6.4e-5 | | 1.25e7 + 9.6e5 |
| class switches located too, by bisection to `1e-5` | | +6.6e-6 | +1.4e-4 | | 1.75e7 + 6.1e6 |
| with T8's first change | | +2.4e-4 | +3.0e-4 | | 2.15e7 + 1.3e6 |

- About 8 600 crossings are located at each tolerance.
- At `1e-3`, 95% of the 2453 thrown attempts start where a located crossing ended a step,
  and 73% are at the carried proposal, whose median over them is `19δ`. With the next
  step started at `0.05δ`, 36 attempts throw at `1e-4`.
- Over one interval at `tol = 3e-5`, locating and discarding leaves the interval's steps
  and end state bit-identical to the pair's.
- Retaken at `tol = 3e-5` from the `1e-6` run's state, one `39δ` interval holding 39 located
  crossings differs from the same interval at `tol = 1e-9` by `1.5e-7` of `J` (each
  member's difference in `F` times its weight in `J`), where the pair alone differs by
  `5.6e-6`.

**(T13) Re-integrating a crossing member on its own.** After an accepted step across which
member `j`'s `P` changes sign, its nine components are re-integrated with two steps of
the pair, split at the crossing found as in T12, the rest of the state read from the
step's cubic Hermite interpolant; the end rates are re-evaluated.
- `J/J* − 1` is `+4.6e-4` at `tol = 3e-4` and `+2.5e-4` at `1e-4`, each for `1.5e5`
  single-member evaluations on top of T2's.

**(T14) Refusing only within a cluster.** Not run. The downward clusters span `629δ` in
all, so a cap of `0.05δ` from each cluster's first crossing to its last is about `1.3e4`
steps.

**(T15) A wider `P⁺`.** `ε_j = 0.05·P_b,j`, a declared change of the model. `J` moves by
`+3.9%`. Against its own run at `1e-6`, `J`'s error is `+7.4e-4`, `+1.0e-3`, `+8.4e-4`,
`+1.6e-5` and `+6.1e-5` at `tol = 1e-3 … 1e-5`, at T2's cost. In the unchanged model's run at
`1e-6`, members spend 9.1% of member-time with `|P| < 0.01` and 16% with `|P| < 0.1`.

**(T16) The stops** (at `tol = 1e-3`).
- Without the stops at the knots, `J` is `−68%`: 7860 accepted steps, 2975 rejected for
  accuracy and 558 thrown. A cap of `h ≤ 5δ` in their place gives `−0.70%`.
- The pair's abscissae step over forcing events narrower than `0.3h`, and its estimate
  does not see them.

**(T17) Decompositions tried before.** Measured on earlier versions of this model and on
test fixtures, not the test instance.

| decomposition | measured |
|---|---|
| multirate infinitesimal step, chain fast, members slow | each fast evaluation re-runs the member loop; ~10 micro-steps per macro step; 6–25× the cost of the single-rate pair at converged `J` |
| the same, with the chain's loss integrated in closed form inside the fast step, on another fixture | more micro-steps (103 against 58 per macro step), 0.6× the speed |
| the fast coupling from `n_f` members only | `n_f = 20` of 352: 14% `J` error; `n_f = 40`: 2.4% at 2× the cost |
| the coupling held or linearised over a macro step | held: an error plateau of 0.1; linearised: up to 440% error in `a` as `v` falls |
| fast chain against an affine coupling `a(v₀) + D(v − v₀)`, `D = ∂a/∂v` exact | constant forcing: 40× fewer member-loop evaluations; periodic forcing: 3.8× at a `J` error of `3.5e-3`, 1.0× at `≤ 4e-4` |
| a Rosenbrock step for the chain, its Jacobian differenced through the full rates and factorised at full size | 19 member-loop evaluations and a dense full-size factorisation per step; 20–50× slower |
| an implicit pool inside the member loop (a four-stage ESDIRK) | an emptying pool's stages go negative past `hλ = 3.1`, against the explicit pair's 2.16 |

**Against the earlier reply.**
- It predicted one cluster of crossings in the first `δ` or two after each pulse ends,
  about 900 in all. T3 finds 196, the downward ones a median `32δ` after `s` stops.
- It predicted that stepping onto the crossings would give T5's errors at about half
  T5's cost, `8e6` at `1e-4`. T12 gives `+2.6e-4` and `+2.8e-4` at `1e-4` and `3e-5`, at
  `1.5e7`–`2.3e7` with the location's evaluations.
- It predicted that re-integrating the crossing member alone needs no corrector unless a
  class switch coincides with the crossing. Few do (T4), and T13 is `+2.5e-4` at `1e-4`.
- It attributed `J`'s time error to the local errors of the steps across the crossings.
  T3's prediction of the output part from them is a seventh of T6's at `1e-3` and has the
  wrong sign at `3e-4`, and T6 finds a loss part as large as the output part.

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
- *Advance knowledge.* The forcing and every creation time are known before the run.
- *Stops.* A stop can be put at any time.
- *Readings.* Every rate evaluation also computes, at no cost, each member's `P`, its
  inner problem's solution class and `S_max`, `P_new`, and the chain's diagonal.
- *Interpolation.* A step's start and end states and rates are at hand, so a cubic
  Hermite interpolant over it costs nothing. The pair has no continuous extension of its
  own.
- *The chain's rates given `a`* are a separate function.
- *The members' `∂a/∂v`* is available as forward tangents, at about twice a member
  evaluation per direction.
- *A test bed.* The driver of the measurements reproduces the solver bit for bit and takes
  any stepping rule, so a proposed rule can be measured before it is built.
- *Reformulation.* The model may change if the change is declared and its effect on `J`
  and `dJ/dθ` is measured.

## Questions

1. What mechanism do the measurements identify for `J`'s time error, in standard terms?
   Is it a known class of problem, with standard treatments? Which structural features
   are load-bearing for it, and which are incidental?

2. What makes `J`'s time error predictable from one setting of the integration, across
   `θ`? At what cost in member evaluations, and what can it then guarantee about `J`'s
   error?

3. T5, T8, T12 and T13 treat the same run differently and give different `J` at the
   tolerances run. What accounts for the differences?

4. What is the least number of member evaluations at which `J` can be held to about
   `1e-4`, and what treatment attains it? The measured points include the pair at
   `tol = 1e-5` (`+3.2e-5`, `6.41e6`), T8 at `1e-4` (`+1.2e-5`, `5.53e6`) and T10 at `1e-5`
   (`+2.1e-5`, `5.84e6`).

We may be looking at this through the wrong variable. An answer that rejects the framing,
and says which object should be treated in its place, is welcome.

## Follow-up, after the reply

This continues the statement above and your reply to it, in the same notation. It has four parts: your proposals measured on the driver; `dJ/dθ` on pinned runs; what the gradients are for, and the precondition that follows; and what is known about that precondition. The questions are at the end.

Terms used throughout:
- **A rule** sets a run's knobs: `tol`, the error scales, the stops and the creation spacing. **A grid** is what one run of a rule records: its accepted steps, its stops and its creation times.
- **A pinned run** replays a grid: each step at its recorded size, ending at its recorded time, with no error test. It stops if a stage throws. §4 also cites an earlier form, the **end-times form**, which steps to each recorded end time and subdivides the interval where a stage throws.
- **Δ** is a relative half-width in every constant: `θ` is within `Δ` of `θ₀` when `|ln θ_k − ln θ₀,k| ≤ Δ` for each `k`.

### 1. Your reply, measured

On the test instance at its own `θ`, as `J/J* − 1`, with member evaluations in brackets. No crossings are located (T12) in any run here.

**The per-member scale.** `σ_S = tol·(|S| + c·r₀·S_max(x_j))`, with `r₀ = 0.05` held fixed in `σ_S`, and every other error scale unchanged. One run at each tolerance (the nudges below show their spread):

| `c` | `tol = 1e-3` | `3e-4` | `1e-4` | `3e-5` |
|---|---|---|---|---|
| `1e-3` | −4.6e-4 (4.08e6) | −6.2e-5 (4.64e6) | −5.2e-5 (5.37e6) | −6.7e-6 (6.41e6) |
| `1e-4` | | −6.1e-5 (4.66e6) | −2.4e-5 (5.40e6) | |

- At `tol = 3e-4` with `c = 1e-4`: 11 618 accepted steps, 2641 rejected for accuracy and 9 thrown, against the pair's 10 428, 2005 and 102. The pool attains the ratio's maximum on 23% of accepted steps, against 2.7%.
- For comparison near `1e-4` in `J`: the pair at `tol = 1e-5`, +3.2e-5 (6.41e6); T8's absolute part alone at `1e-4`, +7.8e-5 (4.81e6).
- `J`'s error at `tol = 1e-4` split as in T6 (loss part, output part, weights' part), against the run at `1e-7`: the pair +4.8e-4, +3.9e-4, −5.2e-5; T8 with both parts scaled +9.9e-5, −9.3e-5, +5.2e-6; the per-member scale with `c = 1e-3`, −2.1e-5, −3.1e-5, −7e-7.

**The amplifier.** T6's `135δ` stretch runs from `t = 7.41` to `7.78`. At its start the second member has `S = 0.068` of `S_max = 0.53` (`r_s = 0.128`) and `P = −14.8`, so `τ_pool = S_max/|P| + τ_s = 20δ`. Scaling that pool by `1 + 1e-3` there gives `∂m/∂ln S_start = −0.276`, against −0.278 from your formula. The relative change in `S` is carried through the stretch: 9.9e-4 of the 1e-3 remains at its end, where `S = 7.1e-5`.

**The two refinements,** each with `c = 1e-3`:
- *The kink-aware estimate.* On an attempt across which a member's `P` changes sign, its pool's estimate becomes the larger of the embedded difference and `h²·|(1 − G)(1 − r) − r|·(|P₁ − P₀|/h)·|K(ϑ)|`. Here `r` and `G` are taken at the step's start, `P₀` and `P₁` are the member's `P` at the step's ends, and `ϑ` comes from linear interpolation of `P`.
  - The factor is the jump in the pool rate's slope in `P`: `(1 − G)(1 − r)` above zero and `r` below.
  - Your `0.73 + r` agrees with it only near `r = 0`. At `r = 0.35` it is 3.6 times the jump, and near `r = 0.2`, where the jump vanishes, far more.
  - When such a pool sets the ratio, the step-size update uses the exponents for an error of order `h²`: `ρ^{−1/2}` on rejection and `ρ^{−1/3}` when the step is enlarged.
  - There is no factor for class switches.
- *The restart.* After an accepted step across which some member's `P` changes sign, the next step starts at no more than `0.1δ`.

| | `tol = 1e-3` | `3e-4` | `1e-4` | `3e-5` |
|---|---|---|---|---|
| the estimate | | −6.7e-5 (5.09e6) | −1.4e-5 (5.98e6) | |
| the restart | | −2.4e-5 (5.31e6) | −7.9e-5 (6.06e6) | |
| both | −1.5e-4 (5.10e6) | −7.7e-5 (5.77e6) | −2.7e-5 (6.58e6) | −3.4e-6 (7.75e6) |

We first ran the estimate with `(1 − G)(1 − r) + r`, extending your `0.73 + r`. With it, both refinements together gave −1.7e-4, −5.7e-5, −2.9e-5 and −3.9e-6, at about 1% more cost than with the corrected factor.

**Nudges.** `J/J* − 1` over seven tolerances within ±5% of `3e-4`, and three within ±3% of `1e-4`: the median, and the range from largest to smallest. Member evaluations are at the centres.

| | around `3e-4`: median | range | around `1e-4`: median | range | member evaluations |
|---|---|---|---|---|---|
| the pair | +8.1e-4 | 6.7e-4 | +8.1e-4 | 2.0e-4 | 4.07e6, 4.64e6 |
| per-member scale, `c = 1e-3` | −9.6e-5 | 1.1e-4 | −4.5e-5 | 2.3e-5 | 4.64e6, 5.37e6 |
| per-member scale, `c = 1e-4`, three tolerances | −1.0e-4 | 6.4e-5 | | | 4.66e6 |
| both refinements | −1.1e-4 | 7.0e-5 | −3.5e-5 | 1.1e-5 | 5.77e6, 6.58e6 |
| both, with the first factor | −5.7e-5 | 1.9e-5 | | | 5.84e6 |

- The per-member scale is within `1e-4` around `tol = 1e-4`. Around `3e-4` its median is at `1e-4`, and three of its seven runs are beyond it; the single run at `3e-4` in the first table is one of the seven.
- The first factor overstates the pool's own jump at the crossings' levels of `r`, 1.3 times at 0.35 and far more near 0.2, yet it gives the steadiest `J`. Its standard deviation over the seven is 6.8e-6, against 2.9e-5 with the corrected factor and 4.3e-5 for the scale alone.

**The pools at the crossings,** on the run at `tol = 1e-6`, as `r = S/S_max`, in the three earliest-created members over `t ∈ [3, 14]`, where T6 finds the difference in `m` grows:
- *Downward crossings* (88): `r` has median 0.35, and 1% are below 0.1.
- *Upward crossings* (88): `r` has median 0.16, 31% are below 0.1 and 11% below 0.01.
- *The near-empty ones follow long quiescent stretches.* Measured from the member's previous downward crossing:
  - after stretches shorter than `50δ`, the upward crossings' `r` has median 0.13–0.30, and none is below 0.01;
  - after `50–100δ`, median 0.014, and 4 of 12 are below 0.01;
  - after `100δ` or more, median 1.1e-3, and all 6 are below 0.01.
- *T6's stretch.* At the second member's next upward crossing, `18δ` after T6's stretch ends (`t = 7.83`), its `r` is 5e-5.
- Over all crossings by the ten earliest-created members the medians are nearly the same (0.35 and 0.17), and no downward crossing is below 0.01.

**`φ` and the class.** No `φ_ℓ` reaches `φ_max` in the quiescent stretches, because `v` stays above the value that caps it; so `P ≈ −15` over T6's stretch is not a capped `φ`. By T4, members are in the inner problem's lower-end class from a median `6.6δ` after their downward crossing to a median `0.26δ` before their upward one.

**The events.** T12 with T8's first change, at `tol = 1e-4`, split as in T6: loss part +2.7e-4, output part +6.0e-5, weights' part −3.4e-5. Against T8 alone the loss part rose by 1.7e-4 and the output part by 1.5e-4, so the extra error is in `m` and in `F`'s increments alike. Whether the retake and restart cause it is not tested.

**Not tested:** `E_J`; `ln S` as the pool's variable while `P < 0`; sub-cycling the chain in pulses; weighting the controller by the previous gradient's `λ`; skipping members whose `n_j` is nil; warm starts; and restarting at `h ≤ δ` at pulse ends (T10).

### 2. `dJ/dθ` on pinned runs

Two constants:
- `θ_A` enters only `P_b` and `κ(x)`, through four constants that are fixed functions of it;
- `θ_B = 1/r₀` in `μ`. The `r₀` in `σ_S` does not move with it.

For each, `dJ/d ln θ_k` is a central difference at `θ_k·(1 ± 1e-4)` between two pinned runs of one grid, the grid of the run at `θ`.

The references are the same difference on the pair's grids:
- for `θ_A`, at `tol = 1e-8` (−63.10). Its own error is not known: the grid at `1e-7` gives a difference 1.2e-4 from it, so entries below about 2e-4 are not resolved.
- for `θ_B`, at `1e-7` (13.37). No second reference was run, so its resolution is not known.

On a pinned run `J_h(θ)` is continuous, up to the inner root-finds' stopping rules. It is smooth except where some stage's branch (a clamp, the floor or the inner problem's class) changes with `θ`, and the sweep returns the gradient along the branches taken. On a smaller instance a pinned central difference agrees with the sweep to about 1e-5 in `θ_A`. These differences were not compared with the sweep.

Relative error in `dJ/d ln θ_A`:

| `tol` | the pair | per-member scale, `c = 1e-3` | with both refinements |
|---|---|---|---|
| 1e-3 | −6.1e-3 | −1.7e-3 | −9.7e-4 |
| 3e-4 | +2.3e-3 | +2.1e-3 | −1.3e-4 |
| 1e-4 | +1.2e-3 | +5.3e-4 | +7.1e-5 |
| 3e-5 | −2.3e-3 | −6.9e-4 | −3.7e-4 |
| 1e-5 | +8.4e-4 | | |

Relative error in `dJ/d ln θ_B`:
- the pair: −2.2e-2, +7.1e-4 and +6.1e-3 at `tol = 1e-3`, `1e-4` and `1e-5`;
- the per-member scale: +4.8e-3 and +9.9e-4 at `3e-4` and `1e-4`;
- with both refinements: −8.3e-4 and −1.3e-4 at `3e-4` and `1e-4`.

- At `tol = 1e-3`, where the pair's `J` is off by 2.4e-4, its gradient is off by 6.1e-3 in `θ_A` and 2.2e-2 in `θ_B`.
- Of the ladders with three or more tolerances, none falls monotonically in magnitude, and no order can be read from them. They neither confirm nor refute the `O(h)` you expected.
- Not measured: the creation times' share of the gradient's error, probes (§3), and any `θ` other than the one a grid was built at.

### 3. What the gradients are for

The statement asked for `J` to `1e-4` at the least cost, with its time error predictable across `θ`. That objective came from placing creation times to minimise `J`'s error in value. It is not what the gradients are for. This widens the question: the statement held the creation times fixed, and did not include probes.

**A calibration** minimises a smooth function `L` of `J` and other functionals of the same run over `θ`, from `L` and `∇L` at a sequence of `θ`.

**Probes.** A probe is the ensemble's equations with other constants `θ′`, integrated on a base run at `θ`:
- its members are created at the base run's creation times, with a creation probability from their own `P_new`;
- they solve their own inner problems against the field `Φ` and the chain's state `v`, recorded at every rate evaluation of the base run;
- they are integrated on the base run's steps and do not feed back into them;
- its functional `J′(θ′; θ)` is formed as `J` is.

What is wanted from probes: `g′(θ) = ∂J′/∂θ′` at `θ′ = θ`, from a sweep over the probe's recording, for a search for the `θ` at which it vanishes; and `J′` over a range of `θ′` around `θ`.
- At `θ′ = θ` a probe reproduces the base run's `J` to every digit.
- On the recorded fields a probe cannot shrink a step. It could on fields interpolated between the base run's stages, but then a probe at `θ′ = θ` would no longer reproduce the base run.
- A probe's own pass evaluates as many members as its base run, and one base run's recording serves any number of probes.
- The probe gradient's error has not been measured.

**The outcomes wanted.**
1. *For the calibration:* a function of `θ` whose gradient is the sweep's, and whose value moves by less than a stated amount when the grid changes between iterations.
   - Away from the optimum, `∇L` with relative error at most 0.3 in the Euclidean norm in `ln θ`. (Carter, SIAM J. Numer. Anal. 28, 1991; below 1 suffices for descent.)
   - Near it, the error in the optimum's location, `|H⁻¹·δg|`, below the precision wanted, where `H = ∇²L` and `δg` is the error in `∇L`.
2. *For probes on the base run's grid:* outcome 1's accuracy for `g′`, and `J`'s for `J′`, at every `θ′` within `Δ` of the base run's `θ`, with a check on every run that reports when they fall short. Near a root of `g′`, the error in the root's location is what to bound.
3. *Rules* for the steps, stops, creation times and error scales, each with a stated guarantee and a check that every run reports. Not an optimal rule.
4. *The same across a bank of forcing series,* not tuned on this one.
5. *Cost last,* as a budget per gradient and per probe, not a minimum.

**The precondition we now put first.** A rule must converge on each of two axes: the time axis, whose knob is `tol`, and the creation axis, whose knob is the spacing of the `b_j`.
- *(a) The error follows its knob.* Along a ladder, the error in `J`, `dJ/dθ` and `g′` falls roughly in proportion to `tol` on the time axis, and to the spacing squared on the creation axis, with a constant stable within about ×3.
- *(b) The error is not a draw.* Nudging the knob (`tol` within ±5%, or the creation times shifted by a quarter of a spacing) moves `J`, `dJ/dθ` and `g′` by at most a tenth of the error budgets the setting is chosen for.
- *(c) Its grids transfer.* A grid built at `θ₀`, pinned at any `θ` within `Δ` of `θ₀`, keeps `J` and `dJ/dθ` within the budgets its rule meets at `θ₀`. So does a probe at any `θ′` within `Δ` of `θ₀` on a base run at `θ₀`, for `J′` and `g′`. No stage trips the pool's guard.
  - A probe's error is against the same probe on a base run at `tol = 1e-8`.
  - The largest such `Δ` is the grid's **transfer radius**.

Two ways to meet outcome 1 sit at the ends of a range:
- *A grid rebuilt by the rule at every `θ`.* Its error stays controlled, but `J_h` jumps between iterations by (b)'s amount.
- *A grid fixed per forcing series.* `J_h` is one smooth function whose gradient is the sweep's, the recording has one shape at every `θ`, and no attempt is rejected. But its error away from `θ₀` is held only within its transfer radius.

Probes are forced to the second: they cannot adapt. Which end, or what lies between, suits the outcomes is part of the question.

We put the precondition first because what we built on an integration that fails (a) and (b) could not be judged. T10's stepper, for example, was compared at tolerances where `J` is a draw.

Not yet set:
- `Δ`; probes need about ±5% today;
- the precision wanted in `θ`;
- the bank of series;
- the cost budget.

Today `J` within `1e-4` costs about 5.4e6 member evaluations per forward run (the per-member scale at `tol = 1e-4`), and the sweep about 2.5 forward runs (H4).

### 4. What is known about the precondition

**(a) and (b) at the test instance's `θ`.**
- *Time.* With the per-member scale, `|J/J* − 1|` is 0.2–0.5·`tol` from `1e-3` to `3e-5`. The pair gives 0.24, 3.5, 8.1 and 7·`tol` at `1e-3`, `3e-4`, `1e-4` and `3e-5` (T2). The nudges are in §1.
- *Creation,* on another forcing series and an earlier version of the model, at `tol = 1e-4`. Every run stops at the union of the schedules' creation times and at every change in the forcing.
  - 108, 215, 215 shifted by half a spacing, and 429 members agree to 8e-4.
  - The time axis's draw on that series was not measured. On this instance at the same `tol` it is 8.1e-4 (T2), as large as that agreement, so these runs leave the creation error unresolved below about 8e-4.
  - With point samples of `ρ_c` in place of the exact moments, the half-spacing shift moved `J` by 3.6%, more than halving the spacing did.
- *The axes are coupled.* At `tol = 1e-3` the same schedules, and one of 857 members, spread over 1% with no trend in the count. There the moments' absolute part, `tol`, is about `I_M`'s increase over one step.

**(c) was measured only before the per-member scale, and never with a check.** The first three items are on earlier versions of the model, with `τ_s = 0`; the probes are on this model.
- *Across forcing series.* A grid captured under one series was 40–100% wrong under another, so a grid is per series.
- *Across `θ` at `T = 5`,* under constant forcing, over 64 points within `Δ = ln 2` in six constants, on the end-times form:
  - with the captured steps subdivided to 1.5–2 times their number, 98–100% of the points were within `1e-4` of an adaptive run;
  - not subdivided, 58% were, and a point 10% from `θ₀` in one constant was off by tens of percent;
  - as pinned runs instead, the grids failed at 25 of the 64 points on the pool's guard.
- *Across `θ` on this forcing,* with 180 creation times and `tol = 1e-3`, at 11 points: `θ_A` over `× [0.7, 1.2]` and two other constants over `× [0.8, 1.25]`.
  - *The creation times* were placed at `θ₀` with density `∝ (|q″|/n_s)^{1/3}`. Here `q_j` is member `j`'s share of `J` on a uniform run of 857 members, and `n_s(b)` is the number of steps after `b`.
  - Against uniform schedules of 857 members (at `θ₀`, `θ_A × 0.7` and `× 1.2`), they stayed within 8.8e-4 of `J`. Against 429 members at all 11 points, they stayed within 2.8e-3.
  - The secant of `J` from `θ₀` to each end of a constant's range was within 1e-3 of the reference's along `θ_A`, and within 6.1e-3 along the other two.
  - Rebuilt from each point's own run by the same recipe, their error at `θ_A × 0.7` and `× 1.2` went from +5.9e-5 and −8.8e-4 to −2.2e-3 and −2.5e-3. A second recipe's error went from −2.1e-3 and +4.7e-3 to −7.8e-3 and +7.4e-3.
  - *The steps.* `θ₀`'s grid, on the end-times form, kept `J` within 1.1e-3 of the adaptive run at each point.
  - At `θ_A × 0.95` and `× 1.05`, each step's estimate was re-formed by retaking it from its recorded start. 39 and 83 of the 10 349 steps had an error ratio above 1.1, the largest 6.6, against 1.10 at `θ₀`. Most were in the chain, and the 99th percentile over the box was 0.99–1.10.
  - Another 24 and 58 steps put a stage below the pool's guard, and the replay subdivided them without counting them.
- *Probes on this model,* with the base run on the pair's own rule and without the per-member scale, at `θ_A′/θ_A` = 0.95, 0.97, 0.99, 1.01, 1.03 and 1.05:
  - with the base run at `tol = 1e-3`, only 0.99 runs. The others fail on the pool's guard, 1e-10 to 1e-9 below zero;
  - with the base run at `tol = 1e-4`, all six run.
- *Probes further out,* on an earlier build whose base run is identical at `tol = 1e-3`:
  - uncapped, `θ_A′/θ_A` = 0.9, 1.1, 1.2 and 1.5 were tried, and all fail on the pool's guard;
  - capped, 0.5, 0.8, 1.1, 1.2, 1.5 and 2 were tried. With the base run's step capped at `7δ` (4% more accepted steps), 0.8 and 1.1 run, and 0.5, 1.2, 1.5 and 2 fail, at `t = 7.83` or `3.73`;
  - capped at `3.5δ` (18% more), 0.8 to 1.5 run. 0.5 fails at `t = 7.83` on a `1δ` step, and 2 at `t = 28.78` on a `0.37δ` step.
  - `t = 3.73` and `7.83` are upward crossings after long quiescent stretches, where the earliest members' pools are near empty: the second member's `r` is 7e-3 and 5e-5 there.
  - A near-empty pool whose stage rates differ in sign goes below zero through the pair's negative coefficients, even on short steps.
- *Positivity in general.* No Runge–Kutta method above first order keeps positivity for every positive linear system at every step length (Bolley–Crouzeix). Strong-stability-preserving explicit methods keep it under a step bound; the pair is not one.
- *A pinned run forms no error ratio.* The embedded difference is computed and discarded, so nothing on a pinned run, base or probe, reports that it is outside its grid's transfer radius.

### Questions

1. What do the corrections in §1 change in your account of where `J`'s time error is made, and of the gradient errors in §2? The corrections are the kink factor, the pools' levels at the crossings by stretch length, the class over the stretches, and the nudges.
2. What governs a grid's transfer radius on this model, for base runs and for probes? What do you expect (c) to show with and without the per-member scale? Where between a grid rebuilt at every `θ` and one fixed per forcing series do the outcomes point? What is the least change to how a grid is built or replayed that gives it a stated transfer radius, and at what cost?
3. What quantity, computed on a pinned run, reports that the run is outside its grid's transfer radius, for a base run and for a probe? With what guarantee, and at what cost? Does the same quantity bound the error in an optimum's or a root's location?
4. Are the precondition (a)–(c) and the outcomes above the right objects? Which rules for the steps, stops, creation times and error scales would deliver the outcomes, each with a guarantee and a check? What features of a forcing series would break them?

For each answer, name the cheapest measurement on the driver that would confirm or refute it. We may again be treating the wrong object. An answer that says so, and names the object to treat instead, is welcome.

## Second follow-up, after your reply to the follow-up

This continues the statement, the follow-up and your two replies, in the same notation. It has three parts: your reply to the follow-up, measured; our objectives as they stand, for your critique; and what we ask. H1–H4 and the free readings still hold. The model and its discretisation may still change if the change is declared and its effect measured.

### 1. Your reply, measured

All on the test instance.
- Gradients are central differences at `θ_k·(1 ± 1e-4)` on pinned runs of one grid, against the follow-up's §2 references. Their resolution is about 2e-4 for `θ_A` and unknown for `θ_B`.
- *The full setting* below is the per-member scale with `c = 1e-3`, the corrected pool-only kink estimate and the restart: the follow-up's "both" row.

**The gradient's error and the crossing steps.** On the pair's grid at `tol = 1e-3`, 305 of the 9312 steps have some member's `P` change sign across them. The downward ones are a median `8.6δ` long (10–90%: `3.5–17δ`), and the upward ones `1δ`. Only those steps were split into equal steps, the same steps at both `θ`:

| each crossing step split into | added steps | error in `dJ/d ln θ_A` | error in `dJ/d ln θ_B` |
|---|---|---|---|
| 1 | 0 | −6.1e-3 | −2.2e-2 |
| 2 | 3% | −2.6e-3 | −9.4e-3 |
| 4 | 10% | −2.5e-5 | −4.5e-3 |
| 8 | 23% | +1.6e-4 | −9.6e-4 |

On the per-member scale's grid at `tol = 1e-4` (`c = 1e-3`), 869 steps cross, the downward ones a median `2.9δ` long. Splitting them into 1, 2 and 4 (7% and 20% added steps) gives:
- `θ_B`: +9.9e-4, −1.9e-5 and +7.3e-5;
- `θ_A`: +5.3e-4, +2.1e-4 and +4.2e-4, which do not fall with the split and are within about three times the reference's resolution.

**Crossings move with `θ`.** The pair's grid at `1e-3` was pinned at `θ_k·(1 ± 1e-2)`. Each crossing time comes from linear interpolation of `P` across its step, and crossings are matched by member and direction within `20δ`. The shift is per unit `ln θ_k`, as a median with its 10–90% range:

| | `θ_A` | `θ_B` |
|---|---|---|
| downward crossings | `17δ` (`3.8–40δ`) | `8.5δ` (`2.3–19δ`) |
| upward crossings | `0.19δ` (`0.05–1.4δ`) | `0.05δ` (`0.004–0.7δ`) |

You estimated `9δ` and `0.6δ` for `θ_A`.

**The four-component kink estimate.** It raised four components on a crossing step, each against its own error scale:
- the pool, by `|(1 − G)(1 − r) − r|`;
- `x`, `Y` and `F`, by `|ẏ/P|`, read at whichever end of the step has `P > 0` (its start, on a downward crossing).

When one of these set the ratio, the step-size update used the exponents for an error of order `h²`. The restart and `c = 1e-3` were as before.

Over the seven nudges around `tol = 3e-4`, its standard deviation is 2.4e-5 (median error −7.9e-5), at 5.77e6 member evaluations. For comparison:
- the first factor: 6.8e-6, at 5.84e6;
- the full setting: 2.9e-5, at 5.77e6.

The added estimates set the ratio on 0.2% more accepted steps. At `3e-4` the run took 14 560 accepted steps, against 14 566 for the full setting and 14 696 for the first factor. So the prediction that it would match the first factor's steadiness fails, and that steadiness is unexplained.

**Transfer.** The per-member scale's grid with `c = 1e-4` at `tol = 1e-4` has 13 403 steps. It was pinned at `θ_A` times each factor below, and compared at each point with the full setting at `tol = 3e-5` (−3.4e-6 at `θ₀`). The re-formed ratio is the embedded difference over the rule's own scales, as the adaptive run forms it, without the analytic jumps on crossing steps that your check specifies. At `θ₀` its largest value is 1.10.

| `θ_A ×` | 0.8 | 0.9 | 0.95 | 1.05 | 1.1 | 1.2 |
|---|---|---|---|---|---|---|
| reference `J` | 28.74 | 19.68 | 15.99 | 9.68 | 7.06 | 3.21 |
| pinned, error in `J` | a stage throws at `t = 3.48` | +6.6e-5 | −1.4e-5 | −1.2e-5 | +5.2e-5 | −3.3e-5 |
| adaptive, same rule, error in `J` | −9.0e-5 | +3.3e-6 | −6.1e-6 | −2.2e-5 | +6.7e-6 | +2.5e-5 |
| pinned, largest re-formed ratio | | 65 | 55 | 38 | 33 | 27 |
| pinned, steps with that ratio above 1.1 | | 302 | 237 | 96 | 126 | 212 |

- On the pinned runs, the re-formed ratio exceeds 1.1 at every point while `J` stays within 7e-5. So as a check on `J` it trips long before `J` fails. Which component sets it was not recorded. The pools stay above zero at every completed point.
- At `× 0.8` the stage throws with the guard at `−1e-8·S_max` and at `−1e-4·S_max`.
- The gradient on these pinned grids was not measured.
- The pair's grid at `1e-3`, pinned at `θ_k·(1 ± 1e-2)`, already has a largest re-formed ratio of 6–8, on 10–22 steps.

**The guard.** With the guard relaxed to `S ≥ −1e-4·S_max`, probes were run on the pair's base run at `tol = 1e-3`.
- `θ_A′/θ_A` = 0.9, 0.95, 0.97, 0.99, 1.01, 1.03 and 1.05 all run. At `−1e-8·S_max`, only 0.99 ran of 0.95–1.05.
- 1.1, 1.2 and 1.5 still fail, below `−1e-4·S_max`.
- `J′` is 55.7, 28.1, 20.9, 15.1, 12.67 (at `θ′ = θ`), 10.6, 7.21 and 4.79 over 0.9–1.05. The local slope of `ln J′` in `ln θ′` drifts from −12.6 to −21.3 without a jump; at `θ′ = θ` it is −17.8, against −4.98 for `J` itself in `θ_A`. The error of these `J′` against a reference base run was not measured.
- The relaxed guard moves the base run's `J` by 1.4e-6, relative.

**Not measured:**
- your sum `Σ_e h_e·Δ_e·|K′|·|dt_e/dln θ_k|` against the follow-up's §2 magnitudes;
- the density of branch flips in `θ`;
- event zones on the adaptive rule;
- gradients on transferred grids, and the probes' errors;
- the class switch's kink in `a`;
- T12's variants;
- the creation ladder with the per-member scale;
- `E_J`.

### 2. Our objectives, as they stand

**Purpose.** The discretisation exists to give gradients from the sweep, on forcing series like this one, for two uses:
- a calibration that minimises `L(θ)`. How far it moves `θ` between rebuilds is not known;
- probes, for a search for roots of `g′` and for `J′` over a range of `θ′`.

The aim is rules for the steps, stops and creation times, each with a stated guarantee and a check on every run, not one optimal grid.

**First, the discretisation converges,** on each axis (time, whose knob is `tol`; creation, whose knob is the spacing) and on each series:
- *(a)* Along a ladder of the knob, the error in `J`, `dJ/dθ` and `g′` falls in proportion to `tol` and to the spacing squared, with a constant stable within about ×3.
- *(b)* Nudging the knob (`tol` within ±5%, or the creation times shifted by a quarter of a spacing) moves them by at most a tenth of the error budget the setting is chosen for.
- *(c)* A grid built at `θ₀`, pinned at any `θ` within `Δ` of `θ₀`, keeps `J` and the gradients within the budgets its rule meets at `θ₀`. So do probes within `Δ`, and nothing throws. The largest such `Δ` is the grid's transfer radius.

**Then the goals.** Goals 1 and 2 build in a design, a grid fixed per series; we list them as they stand, because whether they should is part of the question.
1. *Gradients on a fixed grid.* Away from an optimum, `∇L` with relative error at most 0.3 in the Euclidean norm in `ln θ`. Every gradient error measured so far is well inside that. Near an optimum, the error in its location, `|H⁻¹·δg|`, must be below the precision wanted.
2. *One grid per forcing series,* shared across `θ` and by probes within its transfer radius, which a check on every run reports.
   - At `θ′ = θ` the probe runs on its own base run's grid, so goal 1 applies.
   - Near a root of `g′`, bound the error in the root's location.
3. *Rules,* each with a guarantee (one of (a)–(c), measured across a bank of series) and a check.
4. *Across a bank of forcing series.*
5. *Cost last,* as a budget per gradient and per probe, not a minimum.

**Not yet set:**
- the error budgets: the statement's `1e-4` for `J` was set aside, and none is set for the gradients;
- the precision wanted in `θ`;
- `Δ` (probes need about ±5% today);
- the bank;
- the cost budget.

**What your reply suggested, not yet adopted:**
- (a) holds for `J` but not as stated for the gradients. The time axis has two knobs, `tol` and the step across the crossings `h_e`, and the gradients follow `h_e` alone.
- (b) is not a property to test but one to make small by construction, through `h_e`.
- (c) is the right object. With a grid fixed between rebuilds it is the only convergence question that matters, and the rebuilding rule's convergence is shown once per series by a ladder, not required of every run.
- A grid fixed per series, rebuilt when a check trips or the iterate leaves its region.
  - The check is the re-formed ratio with the analytic jumps, sign changes on steps longer than `h_e`, the pool's deepest excursion and the largest `hλ_chain/β`.
  - `E_J` is the sharper check.

### 3. What we ask

We want a solution that is elegant, simple and excellent: few parts, and guarantees that are strong and cheap to check. Several root causes may stand between here and such a solution. Details that can be fixed should be named and set aside, not allowed to steer the design.

1. **The objectives.** What should they be, for these two uses? Keep, drop, merge or add, including the fixed grid in goals 1 and 2, and your own suggestions above.
2. **The goal, rethought.**
   - From first principles: start from what the calibration and the root search need, and from what is true of the problem as posed. What should the discretisation be required to deliver?
   - Then follow what each of those requirements forces in turn.
   - What is the simplest design that meets them excellently, and what would you refuse to build?
3. **Root causes.** What stands between here and that design? Rank them, and say for each whether it is structural or a fixable detail. For a fixable detail, give the fix in a line.
   - Include what §1 leaves unexplained: the first factor's steadiness, crossings shifting at about twice your estimate, the re-formed ratio's failure as a check, and the throw at `θ_A × 0.8`.
4. **The next measurement.** Which single measurement on the driver would most sharpen the choice between the designs you consider?

We may be asking for the wrong thing. If a different goal, or a different formulation of the problem, would make the solution elegant and simple, say so.
