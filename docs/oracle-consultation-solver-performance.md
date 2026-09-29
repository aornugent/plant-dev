# Time integration of a forced chain and a growing ensemble: where the error in `J` comes from, and its cost

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

The error in `J` does not follow the tolerance. From `tol = 1e-2` to `1e-4` it takes either
sign, up to `2.5e-3` relative, and it is within `1e-4` only from `tol = 1e-5` (T2).

Wanted: `J` to a relative accuracy of about `1e-4` at the least cost, with an error that
follows the tolerance, and `dJ/dθ` from the sweep converging with it. The creation times
are held fixed throughout; how many members, and where, is not part of this question.

What follows gives the full model, its discretisation, a list of structural features, the
measurements and the facts an answer can rely on. The questions are at the end and are
open. An earlier version of this statement drew a reply whose proposals are measured
here (T12–T16).

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
- It is identically zero over quiescent stretches, which are most of the record. It is
  positive over 814 pulses, each `2–4δ` long, separated by gaps of median `8δ`; 175 gaps
  are longer than `20δ`.
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
- `S_max` grows with `x`. Along the reference run the pools' largest values are 4.6 in the
  oldest members and 2e-3 in the youngest, in the units in which the state is integrated.
- The pool's rate is the charge `c(1 − r)` while `P > 0` and the drain `−d·r` while
  `P < 0`: it switches between them where `P` crosses zero. It is `c ≥ 0` at `r = 0` and
  `−d ≤ 0` at `r = 1`, and a guard throws where `S < −1e-8·S_max`.
- `μ` is steepest at an empty pool: `dμ/dr = −μ₁/r₀ = −110` at `r = 0`, and `−15` at
  `r = 0.1`.
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
- At the reference run's accepted states the solution is interior in 96.2% of
  member-states and at the interval's lower end in 3.8%; no other class occurs there.
  `p_j` is `C⁰` across a switch between classes, so `P_j` and `c_ℓj` have a kink there.
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
  accumulators and members alike, each in its own units. `est` is the embedded
  difference, and `y` the state at the attempt's end.
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
- The inner problem runs for every member at every rate evaluation. Its solution class
  switches, `C⁰`, and a clamp inside it binds in most solves.
- `P⁺` is smooth, with curvature `1/(2ε)` at `P = 0`, where `ε = 1e-4` against a `|P|` of
  `1e-2`–`1e2`. The coordinate's rate, the output and the pool's charge and drain all
  pass through it.
- The pool filters `P` with a relaxation time of `S_max/(c + d)` plus `τ_s`, is bounded in
  sign at both bounds, and a guard throws below zero. It empties over quiescent stretches
  and refills in pulses: the pools sit below 1% of their largest value for 30% of
  member-time (19% in the ten oldest members), and the oldest members' pools reach
  `3e-10`.
- The loss rate is a steep function of the pool's fill near empty, and `J` depends on
  the loss through `e^{−m}`.
- The output is `g·f(x)`, and `f` is a logistic in the coordinate with scale `0.02`.
- The creation probability is `C¹` at `P_new = 0`.
- The creation weights are exact panel moments of `ρ_c`, and the newest panel is open.
- Members are never removed.
- The controller uses a max-norm over every component in its own units, with the same
  absolute part `tol` for all of them; a dead band of `[0.5, 1.1]`; and a growth clamp
  of 5. A clipped step keeps the proposal, and a throw retries at `0.2h`.
- The sweep reuses the inner problem's recorded solutions, and the grid is a constant
  within one gradient.

## Measured

Every run below is on the reference run (108 members), made by one driver outside the
solver. With the solver's own rule it reproduces the solver's every attempt bit for bit:
`J`, the attempt tallies, and each step's time, size, error ratio and binding component.
Each measurement changes one rule in it, or reads one of its runs.

**(T0) The reference.** `J* = 12.6687135`, from the pair at `tol = 1e-8`. The pair at
`1e-7` is `4.5e-8` from it, and the refusal of T5 with `h_c = 0.005δ` at `tol = 1e-7` is
`6.3e-7`. Every relative error below is against `J*`. The previous version of this
statement used the pair's run at `1e-6`, which is `−6.1e-6` from `J*`.

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
- During pulses the top component sits at `v` median 0.85 (10–90%: 0.61–0.92), with
  `|λ|` median `1.85e3` (10–90%: `12`–`6.2e3`).

**(T2) Tolerance does not control `J`'s time error.**

| `tol` | 1e-2 | 3e-3 | 1e-3 | 3e-4 | 1e-4 | 3e-5 | 1e-5 | 1e-6 |
|---|---|---|---|---|---|---|---|---|
| `J/J* − 1` | −2.1e-4 | +2.5e-3 | −2.4e-4 | +1.0e-3 | +8.1e-4 | +2.1e-4 | +3.2e-5 | −6.1e-6 |
| member evaluations | 3.42e6 | 3.52e6 | 3.70e6 | 4.07e6 | 4.64e6 | 5.48e6 | 6.41e6 | 9.17e6 |

**(T3) The crossings of `P = 0`.**
- 9237 along the run at `1e-6` (9220 at `1e-4`), by 107 members; 4 of them are a member
  crossing again within `0.05δ`.
- They come in 196 clusters. 98 are downward, one in each quiescent stretch that holds
  any (those stretches have median length `46δ`): median 45 crossings each, spread over
  `6.3δ` (10–90%: `1.2`–`12δ`), at a median `32δ` after the forcing was last non-zero,
  with `|Ṗ|` median 616. 98 are upward, at the start of the pulse that ends each such
  stretch: spread over `0.31δ`, a median `0.64δ` after the pulse starts, with `|Ṗ|`
  median `9.3e3`.
- A straddled kink: for this pair, a step across a slope jump of a pure quadrature's
  integrand at fraction `θ` of the step errs by `h²·[jump]·K(θ)`, with
  `K(θ) = Σ b_i (c_i − θ)₊ − (1 − θ)²/2`. The mean of `K` over `θ ∈ [0, 1]` is zero (the
  third-order condition); its rms is 0.005. The embedded difference responds with
  `K̂(θ) = Σ (b_i − b̂_i)(c_i − θ)₊`, and `|K|/|K̂|` has median 3.4 over `θ` (25–75%:
  1.7–11). On the crossing steps of ten traced legs, true error over estimate had median
  4.6.
- Summing that error over every straddled crossing, for the output alone, with `θ` from
  `P` at the step's ends: `+1.8e-4` and `+5.4e-5` predicted for the runs at `1e-3` and
  `3e-4`, against `−2.4e-4` and `+1.0e-3` measured.

**(T4) The inner problem's class switches.** 7909 along the run at `1e-6`, all between
the interior class and the lower end.
- Into the lower end: median `5.1δ` after the member's downward crossing of `P = 0`
  (10–90%: `−4.3`–`9.3δ`). Out of it: `0.24δ` before its upward crossing (10–90%:
  `0.05`–`0.55δ`). Neither coincides with the crossing.
- `P < 0` in 99.8% of lower-end member-states.

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

**(T6) Where `J`'s error travels.** Over each interval between times both runs land on,
`F` grows by `e^{−m}` times its output's increment. So `J`'s error splits into a part
from the loss `m` (survival) and a part from the output, against the run at `1e-6`:

| `tol` | survival | output |
|---|---|---|
| 1e-3 | −1.6e-3 | +1.3e-3 |
| 3e-4 | +1.2e-3 | −1.1e-4 |
| 1e-4 | +5.0e-4 | +3.7e-4 |

- At `1e-4` the loss difference behind the survival part is created from `t ≈ 3` to 14,
  in the members created before `b = 1`, over quiescent stretches in which their pools
  empty; it enters `F` from `t ≈ 14` to 20, as their output switches on. (Each interval's
  share is its change in the loss difference times the offspring still to come.) Over one
  `135δ` stretch the second member's pool falls from 0.068 to `7e-5` with `P ≈ −15`
  throughout.
- Retaken from the reference's state at the stretch's start, the stretch adds `−3.5e-6` to
  that member's `m`, and no step's true error is over twice its estimate. The run's pool
  arrives at the stretch `1.7e-3` (relative) from the reference's.
- That difference is created at the preceding upward crossings, where the nearly empty
  pool starts to refill: `1`–`2.5%` relative at two of them, with the pool at
  `0.006`–`0.008`.

**(T7) The pools' relative error, by tolerance**, against the run at `1e-7`, in the ten
oldest members at the times both runs land on.

| `tol` | 1e-3 | 3e-4 | 1e-4 | 1e-5 | 1e-6 |
|---|---|---|---|---|---|
| below 2% of its largest value, `P > 0`: median | 4.0e-4 | 5.2e-4 | 2.2e-4 | 1.1e-4 | 8.0e-6 |
| 90% | 3.3e-3 | 3.2e-3 | 2.0e-3 | 3.8e-4 | 3.8e-5 |
| above half its largest value: median | 9.0e-5 | 3.9e-5 | 2.7e-5 | 2.9e-6 | 4.5e-7 |
| 90% | 1.4e-3 | 3.2e-4 | 2.5e-4 | 2.1e-5 | 2.8e-6 |

**(T8) One weight changed.** The pools' weights in the error ratio multiplied by 0.01, or
only their absolute part, and nothing else.

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
- Retaken from its own state, its `11.2δ` step at the start of a quiescent stretch
  (`h|λ_chain| = 5.6β`) has a true error in `v_1` of 11.5 tolerance weights against an
  estimate of 0.75.
- After the forcing stops, `v̇ = −k v^q` relaxes at exactly `q/((q−1)(t − t₀))`; along
  the run, the top component's `λ` times the time since the forcing was last non-zero has
  median 0.78 over the `60δ` after.

**(T11) The chain's draw.** `|a_1|` against `in_1 + k v_1^q`: median 0.0098 (10–90%:
0.002–0.062) while `s > 0`, and 1.09 (0.07–3.4e4) while `s = 0`; below 0.005 in the lower
components while `s > 0`. Over a one-`δ` leg, `a_1` varies by 0.17% of its size (median;
90%: 2.6%), and a quadratic in time leaves `2e-5` of it.

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
| with T8's weights (both parts `×0.01`) | | +2.4e-4 | +3.0e-4 | | 2.15e7 + 1.3e6 |

- About 8 600 crossings are located at each tolerance.
- At `1e-3`, 95% of the 2453 thrown attempts start where a located crossing ended a
  step, three quarters of them at the carried proposal (median `19δ`). With the next step
  started at `0.05δ`, 36 attempts throw at `1e-4`.
- Over one interval, located and discarded, the location's evaluations reproduce the
  pair's steps bit for bit.
- Retaken from the reference's state at `tol = 3e-5`, one `39δ` interval holding 39 located
  crossings is `1.5e-7` (J-weighted) from the same interval at `tol = 1e-9`, where the pair
  alone is `5.6e-6` from it.

**(T13) Re-integrating a crossing member on its own.** After an accepted step across which
member `j`'s `P` changes sign, its nine components are re-integrated with two steps of
the pair, split at the crossing found as in T12, the rest of the state read from the
step's cubic Hermite interpolant; the end rates are re-evaluated.
- `J/J* − 1` is `+4.6e-4` at `tol = 3e-4` and `+2.5e-4` at `1e-4`, for `1.5e5`
  single-member evaluations on top of T2's.

**(T14) Refusing only within a cluster.** Not run. The downward clusters span `629δ` in
all, so a cap of `0.05δ` from each cluster's first crossing to its last is about `1.3e4`
steps.

**(T15) A wider `P⁺`.** `ε_j` set to 0.05 times the magnitude of the negative terms of
member `j`'s `P`, a declared change of the model. `J` moves by `+3.9%`. Against its own
run at `1e-6`, `J`'s error is `+7.4e-4`, `+1.0e-3`, `+8.4e-4`, `+1.6e-5` and `+6.1e-5` at
`tol = 1e-3 … 1e-5`, at T2's cost. Members spend 9.1% of member-time with `|P| < 0.01`
and 16% with `|P| < 0.1`.

**(T16) The stops.**
- Without the stops at the knots, `J` is `−68%`: 7860 accepted steps, 2975 rejected for
  accuracy and 558 thrown. A cap of `h ≤ 5δ` in their place gives `−0.70%`.
- The pair's abscissae `{0, 0.2, 0.3, 0.6, 1, 0.875}·h` step over forcing events narrower
  than `0.3h`, and its estimate does not see them.

**(T17) Decompositions tried before.** Measured on earlier versions of this model and on
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

**Against the earlier reply.**
- It predicted one cluster of crossings in the first `δ` or two after each pulse ends,
  about 900 in all. T3 finds 196, the downward ones a median `32δ` after the forcing.
- It predicted that stepping onto the crossings would give T5's errors at about half
  T5's cost, `8e6` at `1e-4`. T12 converges to a `J` `2.6–3.0e-4` from `J*` at
  `1.3e7`–`2.2e7`.
- It predicted that re-integrating the crossing member alone needs no corrector unless a
  class switch coincides with the crossing. None does (T4), and T13 is `2.5e-4` from
  `J*` at `1e-4`.
- It attributed `J`'s time error to the local errors of the steps across the crossings.
  T3's prediction of the output's share of them has the wrong sign at `1e-3` and a
  twentieth of the size at `3e-4`. T6 finds a survival part as large as the output's,
  created where nearly empty pools refill (T6, T7).

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
- *Readings.* Every rate evaluation also returns, at no cost, each member's `P`, its
  inner problem's solution class and `S_max`, `P_new`, and the chain's diagonal.
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

1. What mechanism do the measurements identify for `J`'s time error, in standard terms?
   Is it a known class of problem, with standard treatments? Which structural features
   are load-bearing for it, and which are incidental?

2. What should the integration's error control measure so that `J`'s time error follows
   the tolerance, at the least cost in member evaluations? What can it then guarantee
   about `J`'s error?

3. Stepping onto the crossings (T12) and re-integrating the crossing member (T13) both
   converge to a `J` `2.5–3e-4` from `J*`, and T8's weights do not change that; refusing
   long steps across the crossings (T5) converges to `J*`. What mechanism would separate
   them?

4. With `J`'s time error following the tolerance, what is the least number of member
   evaluations at which `J` can be held to about `1e-4`, and what treatment of the chain,
   the members and their switches attains it?

5. Under that treatment, what must hold for `dJ/dθ` from the sweep to converge with `J`,
   given H1–H3?

We may be looking at this through the wrong variable. An answer that rejects the framing,
and says which object should be treated in its place, is welcome.
