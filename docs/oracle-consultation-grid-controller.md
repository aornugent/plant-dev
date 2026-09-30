# Two grids for a forced chain and a growing ensemble, chosen so that the gradients are stable

## The problem

A system of ODEs is integrated over a horizon `T = 40` against a known scalar forcing
`s(t) ≥ 0`, one record from a family of such records. The state is:
- a five-component chain `v`, driven by the forcing, with five accumulators beside it;
- an ensemble of members created at times `b_j`, nine components each.

Members interact only through two fields that sum over the ensemble. The functional `J`
is a weighted sum of each member's accumulated output at `T`. For `θ`, about fifty
constants of the members' rates, `dJ/dθ` comes from a reverse sweep that is exact for
the discretised model.

A **probe run** reuses a recorded run. It integrates members of a second kind, with
constants `θ′` and created at the same times, along the recorded steps and in the
recorded fields. Its functional `J′(θ′)` and its gradient come the same way. At
`θ′ = θ`, `J′ = J`.

The discretisation is two grids:
- the **creation grid**, the times `b_j`;
- the **step grid**, the times the integrator steps to.

Both are chosen by rules before or during the run, and both are constants within one
gradient.

**Wanted:** rules that choose the two grids together, for any record in the family. The
records include constant, seasonal, wet, dry, episodic and long-dry-stretch forcing.
Under the rules:
- `ln J`, each elasticity `d ln J / d ln θ_k`, each second derivative `d² ln J / d(ln θ_k)²`,
  and their probe counterparts at and near `θ′ = θ`, are within `ε` of their converged
  values. `ε` is a tenth of each quantity's spread across records from one generator
  (below).
- Four tests hold:
  1. *Reproducible:* moving a setting by an amount that should not matter — `tol` by ±5%,
     or every creation time by a quarter of its spacing — moves each quantity by less
     than `ε/3`.
  2. *Continuous in the constants:* a grid built at `θ₀` serves every `θ` within a stated
     radius, and every probe of the run over a stated range of `θ′`, with each quantity
     changing smoothly on that one grid.
  3. *Predictable:* each quantity's error falls as a setting tightens, at a known order,
     so that a second, looser run estimates a run's error.
  4. *Nothing fails:* no run throws or stalls, for the base run or any probe, over the
     range.
- One grid serves each local analysis: `J′` over a range of `θ′` around a run, its
  gradient at `θ′ = θ`, its second derivative there, and base runs within ±10% of `θ₀`.
  Larger moves in `θ` build a new grid.
- The cost is the least that meets these, compared at matched error, not at matched
  settings. Where the dynamics offer structure, the rules use it. Where they offer none,
  the rules fall back to brute force (uniform creation times, plain error control), which
  must carry the same guarantee.
- Every run reports its error estimate, how far its `θ` is from the grid's `θ₀` against
  the grid's radius, and its failures.
- At equal performance the simpler scheme wins: the rules must be easy to reason about
  and to maintain.

What follows gives:
- the model and its discretisation;
- how the system and the controller behave over a run, in detail, because an answer can
  only use the dynamics it is shown;
- a list of structural features;
- the treatments measured;
- the facts an answer can rely on.

The questions are at the end and are open. We would rather know what is possible, and which formulation reaches it, than have
the present scheme tuned.

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
- Five accumulators take rates from `s`, `in_1`, `k·clamp(v_5, 0, 1)^q` and `Σ a_ℓ`. One
  is constant, and none feeds back.

**The forcing.** `s(t)` is a shape-preserving `C¹` Hermite interpolant of daily control
points at spacing `δ`. The records come from one generator:
- a two-state Markov chain of wet and dry days with a seasonal cycle in its transition
  probabilities;
- gamma-distributed depths on wet days;
- a multiplier per year, which puts in stretches of smaller, rarer pulses;
- rescaling to a set mean.

On the test instance's record:
- `s` is identically zero over quiescent stretches, which are most of the horizon;
- it is positive over 814 pulses, each `2–4δ` long, separated by gaps of median `8δ`,
  and 175 gaps are longer than `20δ`;
- near `t ∈ [7, 10]`, `[18, 22]` and `[31, 34]` its pulses are smaller and rarer;
- its 2931 active knots are the points where the interpolant's second derivative jumps.

**The members.** Member `j` carries:
- its coordinate `x`;
- a cumulative loss `m`;
- an output integral `Y`;
- two smooth accumulations `V₁, V₂`;
- a bounded pool `S`;
- its accumulated output `F`;
- two panel moments `I, N`.

At each rate evaluation:
```
p_j   = argmax over p ∈ [p_lo, p_hi] of R(p; x_j, φ, Φ)          the inner problem
P_j   = P(p_j; x_j, φ, Φ)                                        a scalar net rate
c_ℓj  = C_ℓ(p_j; x_j, φ)                                         its draw on v_ℓ
P⁺    = ½ (P + √(P² + ε_P²))                                     ε_P = 1e-4
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
- `S_max` grows with `x`. Along the run the pools' largest values are 4.6 in the
  earliest-created members and `2e-3` in the latest-created, in the units in which the
  state is integrated.
- **The pool's rate switches with the sign of `P`.** It is the filling term `u⁺(1 − r)`
  while `P > 0`, and the emptying term `−u⁻r` while `P < 0`, so it switches between them
  where `P` crosses zero.
  - It is `u⁺ ≥ 0` at `r = 0` and `−u⁻ ≤ 0` at `r = 1`, so the exact flow stays in
    `[0, S_max]`.
  - A stage may leave that range. `μ` is finite there, and a step whose end has `S < 0`
    is refused.
- `n_j = e^{−m_j}`. The loss rate is parked at zero once `m` reaches a ceiling where `n_j`
  is nil.
- `σ` is a smooth known function.

**Creation.** A member is created at `b_j` in a fixed creation state: `x = x_0`,
`S = 0.8·S_max(x_0)`, and the rest zero.
- The member that would be created now, at `b = t`, is evaluated at every rate evaluation
  in the current fields, and is not carried as a state.
- Its net rate `P_new(t)` sets the creation probability
  ```
  ρ_c(t) = ẽ(P_new(t)),     ẽ(P) = 1/(1 + (a₀/P)²) for P > 0, else 0      (C¹ at P = 0)
  ```
- Only the newest member's two moments move:
  ```
  İ_M = ρ_c(t),      Ṅ_M = (t − b_M) · ρ_c(t)
  ```

**The weights.** Member `j`'s panel `[b_j, b_{j+1}]`, of width `Δ_j`, holds
`I_j = ∫ ρ_c dt` and `N_j = ∫ (t − b_j) ρ_c dt`. These stop moving once member `j + 1` is
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
- The sums over members are quadratures over creation time: the creation grid is the
  quadrature's nodes.

**The inner problem.**
- `p_j` maximises a scalar objective on an interval, found by nested root-finding:
  - an outer bracketing root-find (TOMS748) on the objective's derivative, about 11
    evaluations;
  - two inner scalar root-finds in each of those evaluations, about 6 iterations each;
  - about 50 evaluations per solve of an auxiliary function of `φ_1 … φ_5`.
- `P` is the difference of two non-negative terms, `P = P_a − P_b`, and `P_b` grows with
  `x`. Along the run, `P` falls through zero in long quiescent stretches and rises back
  through it in the pulse that ends them.
- The solution is interior in 96.2% of member-states and at the interval's lower end in
  3.8%. `p_j` is `C⁰` across a switch between the two classes, so `P_j` and `c_ℓj` have a
  kink there.
- Every solve starts cold, so the rates are deterministic functions of the state and
  time, repeated bit for bit.

**The constants.** `θ` enters the members' rates. Two are used below:
- `θ_A` enters `P`, `κ` and `S_max` through several rates;
- `θ_B = 1/r₀` sets how steeply the loss rate rises as the pool empties.

## The discretisation

**The creation grid.** The test instance creates 108 members evenly spaced over
`[0, 39.63]`, and holds 54 on average.
- A refinement rule exists: it splits a panel where dropping a member would move `J` or
  `Φ` by more than a threshold, and repeats.
- A creation is a stop. The state grows by nine components, the rates are evaluated once
  at the wider state, and the step proposal carries across.

**The stops.** The step grid lands exactly on each of the 2931 active knots, each
creation time, and `T`.
- At a knot nothing happens: no state changes, and the rates and the step proposal carry
  across.
- A stop at each knot keeps every step inside one cubic span of `s`. A stop costs no rate
  evaluation of its own, but it ends the step that reaches it.
- There are 3039 legs between stops: 73.5% are one `δ` long, and 10% are longer than
  `13δ`.

**The pair.** Cash–Karp 5(4), propagating the fifth-order solution, with abscissae
`c_i ∈ {0, 0.2, 0.3, 0.6, 1, 0.875}`.
- Each attempt evaluates five stages and then the rates at its end, before the error
  test.
- An accepted step's end rates are the next step's first stage, so an attempt costs six
  rate evaluations.

**The controller.**
- *The error ratio* is `ρ = max_n |est_n| / σ_n` over every component `n`, with the
  error scale `σ_n = tol·|y_n| + 1e-4·tol` in the component's own units. `est` is the
  embedded difference, and `y` the state at the attempt's end.
- *Reject* when `ρ > 1.1`: `h ← h·max(0.2, 0.9 ρ^{−1/5})`.
- *Accept* when `0.5 ≤ ρ ≤ 1.1`, with `h` unchanged.
- *Accept and grow* when `ρ < 0.5`: `h ← h·clamp(0.9 ρ^{−1/6}, 1, 5)`.
- *An invalid attempt* (a stage that throws, or an end state the model refuses) retries
  at `0.2h`.
- A step clipped to reach a stop lands on it exactly. Accepted, it leaves the carried
  proposal as it was; rejected, it retries at the size its own `ρ` gives.
- `h_max = 5`, `h_min = 1e-6`, and the first step is `1e-6`.

**Cost** is member evaluations: the sum over rate evaluations of the members held.
- A member evaluation costs 15–20 µs.
- At 54 members the member loop is 91% of a rate evaluation's instructions, and the inner
  problem 85%.
- The chain's rates given `a` cost `1.4e3` instructions.

**The reverse sweep.**
- It runs over a recording of the forward run: one row per accepted step and one per
  creation. A step's row holds the inner problem's solutions at each of its six
  evaluations.
- It reuses those solutions rather than solving again, and differentiates through them
  by the implicit-function theorem, along the branch each evaluation took.
- It is exact for the discretised model. The creation times and the step sizes are
  constants within one gradient.
- It costs about 2.6 forward runs, and one sweep gives every column of `dJ/dθ`.

**Probes.** A probe run walks the recording's steps exactly, so it cannot shrink a step.
- Each evaluation uses the fields the row recorded. The probe's own members, and its own
  creation probability, are evaluated in them.
- Its sweep holds the fields fixed. That is why a probe's gradient at `θ′ = θ` differs
  from `dJ/dθ`, by up to a fifth: `dJ/dθ` includes the fields' response.

## How the system behaves

On the test instance at `θ₀`. The time-axis readings are along the run at `tol = 1e-6`
unless stated. The creation-axis readings (D6, D7) were taken on an earlier version of
the model, without `τ_s`, at `tol = 1e-3`, and are the only ones on that axis.

**(D0) The time scales,** in `δ`, where `T = 14 600δ`:

| what | scale |
|---|---|
| a pulse of `s` | `2–4δ` |
| a gap between pulses | median `8δ`; 175 longer than `20δ` |
| a quiescent stretch that holds downward crossings | median `46δ` |
| downward crossings after `s` stops | median `32δ`, a cluster spread over `6.3δ` |
| upward crossings after a pulse starts | median `0.64δ`, a cluster spread over `0.31δ` |
| the chain's relaxation at `v = 1` | `0.018δ` |
| the chain's relaxation after a pulse | about the time since the pulse |
| a pool's relaxation | `τ_s = 7δ` plus `S_max/(u⁺ + u⁻)` |
| `ρ_c`'s rises and falls (earlier version) | about `40δ` and `18δ` |
| the creation spacing | `135δ` |
| the width of `∂J/∂w_j`'s excursions over creation time (earlier version) | `37–180δ` |
| the accepted steps at `tol = 1e-4` | median `0.27δ`, 90th percentile `2.9δ`, at most `25δ` |

**(D1) The run's course.**
- Members are created every 0.37 units and never removed, and 54 are held on average.
- *On the earlier version at `tol = 1e-3`:*
  - the forcing's three long stretches of small, rare pulses are where the accepted
    steps are fewest, 156 per unit time there against up to 496 elsewhere;
  - creation stops where `P_new ≤ 0`, over 5.84 units of the horizon (14.6%) in 56
    spans, the first at `t = 3.56`;
  - `ρ_c`'s rises and falls at the ends of those spans are about `40δ` and `18δ` wide.

**(D2) The crossings of `P = 0`.**
- There are 9237 along the run at `tol = 1e-6` (9220 at `1e-4`), by 107 members. 4 of
  them are a member crossing again within `0.05δ`.
- They come in 196 clusters.
  - *98 downward,* one in each quiescent stretch that holds any; those stretches have
    median length `46δ`. A median 45 crossings each, spread over `6.3δ` (10–90%:
    `1.2`–`12δ`), a median `32δ` after `s` was last non-zero, with `|Ṗ|` median 616.
  - *98 upward,* in the pulse that ends each such stretch: spread over `0.31δ`, a median
    `0.64δ` after the pulse starts, with `|Ṗ|` median `9.3e3`.
- Members spend 9.1% of member-time with `|P| < 0.01`, and 16% with `|P| < 0.1`.

**(D3) The inner problem's class switches.** There are 7909 along the run, all between
the interior class and the lower end, their times resolved to a median `0.55δ`.
- *Into the lower end:* a median `6.6δ` after the member's last downward crossing of
  `P = 0` (10–90%: `3.4`–`12δ`), with `P < 0` just after it in 99%. 1.1% fall in the same
  step as a crossing by that member.
- *Out of it:* a median `0.26δ` before the member's next upward crossing (10–90%:
  `0.08`–`1.35δ`). 10.7% fall in the same step as that crossing.
- `P < 0` in 99.8% of the accepted member-states at the lower end.

**(D4) The pools.**
- They sit below 1% of their largest value for 30% of member-time. In the ten
  earliest-created members it is 19%, and their pools reach `3e-10`.
- *At the crossings, as `r = S/S_max`:*
  - downward, median 0.35, with 1% below 0.1;
  - upward, median 0.16, with 31% below 0.1 and 11% below 0.01.
- *The near-empty ones follow long quiescent stretches.* Measured from the member's
  previous downward crossing, the upward crossings' `r` has:
  - median 0.13–0.30 after stretches shorter than `50δ`, none below 0.01;
  - median 0.014 after `50–100δ`, with 4 of 12 below 0.01;
  - median 1.1e-3 after `100δ` or more, with all 6 below 0.01.
- *Their relaxation.* Before `τ_s`, a newly created member's pool relaxes at 300–1444 per
  unit time. With `τ_s` a draining pool relaxes at about `1/τ_s`. While a pool fills,
  `G`'s slope adds up to `6λ_S`, and the rate reaches `2.3/τ_s` at `r = 0.3`.
- *The pair against a relaxing pool.* For `y′ = −y/τ`, the pair's fourth stage goes
  negative past `h = 2.16τ`, while the step is stable, with a non-negative end, to
  `3.73τ`. At `τ = τ_s` that is `15δ` against `26δ`.
- *A near-empty pool whose stage rates differ in sign* goes below zero through the pair's
  negative stage coefficients, even on short steps.

**(D5) The chain.**
- While `s > 0`, `v_1` has median 0.85 (10–90%: 0.61–0.92), and `|λ_chain|` has median
  `1.85e3` (10–90%: 12 to `6.2e3`).
- For `v̇ = −k v^q` alone the relaxation rate is `q/((q−1)(t − t₀))`, `t₀` a virtual
  origin set by `v` when `s` stops. Along the run, `v_1`'s relaxation rate times the time
  since `s` was last non-zero has median 0.78 over the `60δ` after. So the chain has no
  fixed fast mode: after a pulse its rate is about one over the time since.
- *The members' draw* `|a_1|/(in_1 + k·clamp(v_1, 0, 1)^q)` has median 0.0098 (10–90%:
  0.002–0.062) while `s > 0`, and 1.09 (0.07 to `3.4e4`) while `s = 0`. For components
  2–5 it is below 0.005 while `s > 0`.
- Over a one-`δ` leg `a_1` varies by 0.17% of its largest value (median; 90%: 2.6%), and a
  quadratic fit in time leaves an rms residual of `2e-5` of it.

**(D6) Where `J` comes from, over creation time.** `w(b)`, `J`'s integrand over creation
time, from a run of 1713 uniform members:

| creation band | share of `J` | largest `w` | member cost / mean member | share of member evaluations | mean `|w″|/12` |
|---|---|---|---|---|---|
| [0, 0.5) | 0.506 | 16.9 | 1.95 | 0.025 | 0.59 |
| [0.5, 1) | 0.213 | 8.28 | 1.93 | 0.025 | 1.46 |
| [1, 3.56) | 0.162 | 3.30 | 1.86 | 0.119 | 0.22 |
| [3.56, 6) | 0.0125 | 0.142 | 1.72 | 0.107 | 0.76 |
| [6, 10) | 0.0931 | 1.28 | 1.56 | 0.156 | 1.74 |
| [10, 16) | 0.0119 | 0.0723 | 1.33 | 0.202 | 0.19 |
| [16, 22) | 0.00123 | 0.0094 | 1.05 | 0.158 | 0.022 |
| [22, 40] | 3.6e-5 | 6.2e-4 | 0.47 | 0.207 | 1.0e-4 |

- `w` falls from 16.9 at `b = 0` by about half every 0.35 units to `b ≈ 3.3`. Past the
  first span without creation its largest value is 1.28, at `b = 7.96`, after the first
  long stretch of small pulses.
- A member's cost is the accepted steps after its creation, so members created late cost
  little each and many together: those created after 16 carry 1.3e-3 of `J` and take 37%
  of the member evaluations.

**(D7) How the creation grid's error arises.**
- *Most of it is the fields'.* `J(215 members) − J(1713) = +1.38e-2` of `J`. 96% of it is
  the fields' response: at the same creation times, the members created before `b = 16`
  accumulate 1.1–2.7% more output under 215 members than under 1713. `J`'s own sum over
  creation times is the other 4%.
- *Filling one band at a time* with the 429-member grid's midpoints finds where it is
  bought:

  | band filled | members added | ΔJ | own sum | fields | Δ member evaluations | share of the 215 → 429 change |
  |---|---|---|---|---|---|---|
  | [0, 0.5) | 3 | −0.00514 | −0.00690 | +0.00175 | 32 027 | 3.0% |
  | [0.5, 1) | 2 | −0.00124 | −0.01443 | +0.01318 | 20 943 | 0.7% |
  | [1, 3.56) | 14 | −0.00191 | −0.01492 | +0.01302 | 143 412 | 1.1% |
  | [3.56, 6) | 13 | +0.00062 | −0.00088 | +0.00149 | 123 562 | −0.4% |
  | [6, 10) | 22 | −0.09551 | +0.03767 | −0.13320 | 188 749 | 55.4% |
  | [10, 16) | 32 | −0.07913 | +0.00687 | −0.08601 | 241 453 | 45.9% |
  | [16, 22) | 33 | +0.00456 | −0.00021 | +0.00477 | 199 175 | −2.6% |
  | [22, 40) | 95 | +0.00042 | −0.00000 | +0.00042 | 274 591 | −0.2% |

  - The fills add up to within 2.9% of the whole change.
  - `[6, 16)`, the members created after the first long stretch of small pulses, gives
    101% of the change for 35% of the added member evaluations. Those members carry 10.5%
    of `J`: the `J` they move is the fields', felt by the members created before them.
  - Over `[0, 3.56)`, where `J` lives, filling removes 0.037 of the own sum's error, and
    the fields give back 0.028.
- *The local term describes the own sum only where `w` is smooth.* Before `b = 3.56` the
  term `(H³/12)·w″`, summed over panels, is the own sum's error to 0.6–9% at 215 and 429
  members. Past it, the panel errors are one to two orders larger than the local term and
  cancel between panels. `ρ_c`'s rises and falls are not resolved by `34δ` panels.
- *Members created where `ρ_c = 0` still matter.* The 429-member grid without its 64
  members inside the spans without creation is −7.29e-2 in `J`. A panel that spans such a
  gap carries the creation at its edges across it, in the own sum and in the fields.

## How the controller behaves

Relative errors in `J` are against `J* = 12.6687135 ± 6e-7`, from the pair at
`tol = 1e-8`. The pair at `1e-6` is 6.1e-6 below it.

**(C1) What sets the step.**
- *With the shared absolute part, at `tol = 1e-3`:*
  - there are 9312 accepted steps, 1910 attempts rejected for accuracy and 149 thrown by
    a stage guard since removed: `3.70e6` member evaluations, 18% of them on rejected
    attempts;
  - the median accepted step's error ratio is 0.044;
  - a chain component attains the ratio's maximum on 90.5% of accepted steps, and a member
    component on 9.5%, the pool on 2.7%;
  - `h·|λ_chain|/β` at a step's start is at least 0.5 on 55.3% of steps and at least 1 on
    13.3%, where `β = 3.7343596` is the pair's real stability boundary;
  - legs one `δ` long hold 15.3% of the time and 64% of the accepted steps' member
    evaluations, at 2.66 accepted steps each, and longer legs take 4.18 each;
  - accepted steps grow as `tol^−0.10`: 8018 at `1e-2`, 16 185 at `1e-5`.
- *With the absolute part tied to `1e-4·tol`, at `tol = 1e-4`, without the guard:*
  - there are 14 838 accepted steps, 3386 attempts rejected for accuracy, none thrown and
    one end state refused;
  - a chain component attains the ratio's maximum on 84.4% of accepted steps, and a
    member component on 15.5%, the pool on 6.5%;
  - `h·|λ_chain|/β` is at least 0.5 on 28.4% of steps, at least 0.8 on 7.3% and above 1
    on 0.3%. The median error ratio is 0.11 below 0.5, 0.26 from 0.5 to 0.8, 0.03 from
    0.8 to 1, and 0.54 from 1 to 1.2;
  - the accepted steps are `0.085δ`, `0.27δ`, `2.9δ` and `8.9δ` at their 10th, 50th, 90th
    and 99th percentiles, and `25δ` at most;
  - 35.1% of them are in legs longer than `δ`, with median `1.53δ`, and those in one-`δ`
    legs have median `0.17δ`.

**(C2) The tolerance's control of `J`.**

| error scale | `1e-3` | `3e-4` | `1e-4` | `3e-5` | ±5% of `1e-4`: median, sd | cost at `1e-4` |
|---|---|---|---|---|---|---|
| `tol·|y| + tol` | −2.4e-4 | +1.0e-3 | +8.1e-4 | +2.1e-4 | +8.1e-4, range 2.0e-4 over three within ±3% | 4.64e6 member evaluations |
| `tol·|y| + 1e-4·tol` | −4.0e-4 | +3.3e-6 | +3.7e-5 | −1.2e-5 | +3.8e-5, 1.6e-5 | +28% attempts |
| `tol·(|S| + 1e-3·r₀·S_max)` for pools only | −4.6e-4 | −6.2e-5 | −5.2e-5 | −6.7e-6 | −4.0e-5, 1.2e-5 | 5.37e6 (+16%) |

- The shared part leaves near-empty pools without relative control. The loss rate
  amplifies their relative error: scaling one pool by `1 + 1e-3` at the start of a `135δ`
  quiescent stretch gives `∂m/∂ln S_start = −0.276`.
- The shared part's error at `1e-5` is +3.2e-5, for `6.41e6` member evaluations.

**(C3) Where `J`'s error travels,** against the run at `tol = 1e-7`, with the shared
absolute part. Over each interval between times both runs land on, `F_j` grows by
`∫ e^{−m_j}(σ/σ_b) Ẏ dt`.
- The loss part is `Σ_j w_j (e^{−Δm_j} − 1) ΔF_j`, with `Δm_j` the runs' difference in
  `m_j` averaged over the interval's two ends and `ΔF_j` the reference's increment of
  `F_j`.
- The output part is the rest of the difference in `F`, and the weights' part is `J`'s
  error less both.

| `tol` | `J`'s error | loss part | output part | weights' part |
|---|---|---|---|---|
| 1e-3 | −2.4e-4 | −1.67e-3 | +1.34e-3 | +8.5e-5 |
| 3e-4 | +1.04e-3 | +1.16e-3 | −9.4e-5 | −2.6e-5 |
| 1e-4 | +8.1e-4 | +4.8e-4 | +3.9e-4 | −5.2e-5 |
| 1e-5 | +3.2e-5 | +6.7e-5 | −3.1e-5 | −3.7e-6 |

- At `tol = 1e-4` the difference in `m` grows mostly between `t ≈ 3` and 14, in the three
  earliest-created members, over quiescent stretches in which their pools empty. It
  enters `F` from `t ≈ 14` to 20, as their output switches on.
- Over one `135δ` stretch the second member's pool falls from 0.068 to `7e-5`, with
  `P ≈ −15` throughout. Retaken at `tol = 1e-4` from the `1e-6` run's state at the
  stretch's start, the stretch adds `−3.5e-6` to the member's `m`, and no step's true
  error exceeds twice its estimate. The `1e-4` run's pool arrives at the stretch `1.7e-3`
  (relative) from the `1e-6` run's.
- With the per-member scale at `tol = 1e-4` the three parts are −2.1e-5, −3.1e-5 and
  −7e-7.

**(C4) The embedded estimate at a kink.** For this pair, a step across a slope jump of a
pure quadrature's integrand, at fraction `ϑ` of the step, errs by `h²·[jump]·K(ϑ)`, with
`K(ϑ) = Σ b_i (c_i − ϑ)₊ − (1 − ϑ)²/2`.
- The mean of `K` over `ϑ ∈ [0, 1]` is zero (the third-order condition), and its rms is
  0.005.
- The embedded difference responds with `K̂(ϑ) = Σ (b_i − b̂_i)(c_i − ϑ)₊`, and `|K|/|K̂|`
  has median 3.4 over `ϑ` (25–75%: 1.7–11).
- On the crossing steps of ten traced legs at `tol = 1e-4`, true error over estimate had
  median 4.6.
- The pool's own slope jump at a crossing is `(1 − G)(1 − r) − r` times `|Ṗ|`. It
  vanishes near `r = 0.2`.

**(C5) The step sequence moves `J` on its own.**
- Moving `tol` by 3% moves the shared-part run's `J` error by 2e-4.
- Moving every creation time by 1e-5 to 1e-4 moves `J` by about 6e-5 at `tol = 1e-3` (on
  the earlier version), because the steps land elsewhere. That is larger than the
  creation grid's own change from 857 to 1713 members.

**(C5b) One attempt can move a gradient by a fifth.** A small instance: two kinds of
member, each created at two times, a horizon of 2 units, a seasonal forcing, and the
default `tol = 1e-4` with the shared absolute part. Take one column of the gradient of
a sum over members of a smooth function of `x`:
- a run whose stage guard refused a single attempt gives −1271.8;
- the same run without the guard, which refuses nothing, gives −1638.7;
- at `tol = 1e-6` and `1e-7`, where no attempt is refused, both give −1565.9 and
  −1568.9.

Under a dry forcing the same comparison gives +1330.6 and +1300.4, against +1352.0 and
+1381.6. Each run's sweep agrees with a difference of whole runs on its own grid to
2.4e-4. The gradients at the default tolerance are draws of 4–19% on where the steps
land.

**(C6) The step grid away from `θ₀`,** on the earlier version at `tol = 1e-3`.
- `θ₀`'s steps, walked at 11 points over `θ_A × [0.7, 1.2]` and two other constants over
  `× [0.8, 1.25]`, kept `J` within 1.1e-3 of the adaptive run at each point.
- At `θ_A × 0.95` and `× 1.05`, each step's estimate was re-formed by retaking it from its
  recorded start. 39 and 83 of the 10 349 steps had an error ratio above 1.1, the largest
  6.6, against 1.10 at `θ₀`. Most were in the chain. The 99th percentile over the box was
  0.99–1.10, and the largest ratio at any point 6.3–12.3.
- *A walk forms no error ratio.* The embedded difference is computed and discarded, so
  nothing on a walked run, base or probe, reports that it is outside its grid's radius.
- *Across forcing records,* a step grid captured under one record was 40–100% wrong
  under another.
- *At `T = 5` under constant forcing,* over 64 points within `Δ = ln 2` in six constants:
  - with the captured steps subdivided to 1.5–2 times their number, 98–100% of the
    points were within `1e-4` of an adaptive run;
  - not subdivided, 58% were, and a point 10% from `θ₀` in one constant was off by tens
    of percent.

**(C7) The creation grid's refinement rule.** Starting from a default 108-member grid at thresholds
`2e-2`, `2e-3` and `2e-4`, it stops after 6, 8 and 11 runs at 178, 390 and 957 members.
`J` is then −1.32e-2, −2.31e-3 and −5.60e-4, for 7.3, 15.3 and `44.8e6` member
evaluations over its runs.
- Every split came from `Φ`'s term.
- 59% of the 1233 splits fell past `b = 16`, where filling moves `J` by less than C5's
  floor. 6% fell before 3.56, where `J` lives.

## Structural features

Any of these may be load-bearing or incidental; which ones, is not known.
- **The chain.**
  - It is one-way. Its loss term has exponent 16.14 and is clamped at `v = 1`, where the
    inflow also switches, and there is a floor at `v_floor`.
  - With `a` held, its Jacobian is lower bidiagonal. The diagonal is `−q k v^{q−1}`, and
    for `ℓ = 1` also `−8 s v_1^7`. That is `2.05e4` at `v = 1`, a relaxation time of
    `0.018δ`, and it falls as `v^15.1`.
- **The forcing.** It is `C¹` with second-derivative jumps at its knots, and every knot is
  a stop. It is known in advance and does not depend on `θ`.
- **The coupling.** Members read the chain only through `φ`, which is floored and capped,
  and read each other only through the two fields.
- **The inner problem.** It runs for every member at every rate evaluation. Its solution
  class switches, `C⁰`.
- **`P⁺`.** It is smooth, with curvature `1/(2ε_P)` at `P = 0`, where `ε_P = 1e-4`, against
  `|P|` values mostly between `1e-2` and `1e2`. The coordinate's rate, the output and both
  of the pool's terms pass through it.
- **The pool.**
  - It filters `P` with a relaxation time of `S_max/(u⁺ + u⁻)` plus `τ_s`.
  - It is bounded in sign at both bounds, empties over long quiescent stretches, and fills
    in pulses.
  - The loss rate reads it through `e^{−r/r₀}`.
- **The output** is `g·f(x)`, and `f` is a logistic in the coordinate with scale `0.02`.
- **Creation.** The creation probability is `C¹` at `P_new = 0`. The creation weights
  are exact panel moments of `ρ_c`, the newest panel is open, and members are never
  removed.
- **The controller** uses a max-norm over every component in its own units, a dead band
  of `[0.5, 1.1]`, and a cap of 5 on the step's increase.
- **The sweep** reuses the inner problem's recorded solutions, and the grids are constants
  within one gradient.
- **The probes** walk a recorded step grid in recorded fields.

## Treatments measured

On the test instance at `θ₀`, with relative errors in `J` against `J*`. Gradient errors are relative errors in `dJ/d ln θ`, whose
elasticities are about −5 for `θ_A` and 1 for `θ_B`. A driver outside the solver
reproduces the solver's every attempt bit for bit, and each rule below changed only the
driver.

**(M1) Where the gradients' error sits.** The reference is the per-pool scale's run (C2) at `1e-6`
with its crossing steps split 32 ways, which resolves 3e-5 in `θ_A` and 1.3e-4 in `θ_B`.
- The error sits on the steps across downward crossings of `P = 0`: splitting those
  steps removes it.
- Splitting as many other steps of the same lengths changes nothing, and so does
  splitting the steps that hold only class switches.
- For `θ_B`, crossing steps that also hold a class switch carry three times the error per
  unit time.
- On one step grid, a gradient taken where some member's crossing falls inside a step
  follows that step's length at first order. The pair's embedded estimate reports about
  a third of a crossing step's local error.

**(M2) Step rules,** over seven tolerances within ±5% of `1e-4`, under the per-pool scale:
median and standard deviation, and member evaluations.

| rule | `J` | `θ_A` | `θ_B` | member evaluations |
|---|---|---|---|---|
| none | −4.0e-5, 1.2e-5 | −1e-6, 4.0e-4 | +1.1e-3, 7.0e-4 | 5.38e6 |
| crossing steps capped at `δ`, a `12δ` tail after each, and steps capped at pulse onsets | −3.1e-5, 4.8e-6 | +1.3e-4, 2.1e-4 | −3.5e-4, 1.7e-4 | 5.65e6 |
| those grids with each crossing component corrected by `h²·Δ·K(ϑ)` | −2.7e-5, 2.3e-6 | −2.0e-4, 9.2e-5 | −2.0e-4, 1.9e-4 | the same, plus one evaluation per crossing step |
| the cap alone | −2.1e-5, 6.7e-6 | +1.3e-4, 2.2e-4 | +1.4e-4, 2.4e-4 | 5.48e6 |
| + each pool's motion per step ≤ `0.5·r₀·S_max` | −7e-7, 6.1e-6 | −4.2e-5, 4.6e-4 | +3.4e-4, 4.8e-4 | 6.25e6 |
| + ≤ `0.25·r₀·S_max` | +5.0e-6, 2.3e-6 | +4.4e-4, 1.0e-4 | +2.9e-4, 3.6e-4 | 7.70e6 |

- The correction subtracts `h²·Δ·K(ϑ)` from each kinked component, where
  `K(u) = Σ_i b_i (c_i − u)₊ − (1 − u)²/2` and `Δ` is the jump in the component's slope.
  `ϑ` is read from the stages that bracket the crossing. Members whose `P` moves less
  than `100 ε_P` across the step are skipped.
- An earlier reply predicted that the correction would take the gradients' spread to
  about 1e-5. Measured, it halves `θ_A`'s and leaves `θ_B`'s.

**(M3) The stage guard, and the probes.** An earlier version refused every stage with
`S < −1e-8·S_max`.
- Under it, at `tol = 1e-3`, probes at `θ_A` × 0.95, 0.97, 1.01, 1.03 and 1.05 fail, at
  stages 1e-10 below zero. Only × 0.99 runs.
- Without it, every probe from `θ_A` × 0.7 to × 2 runs, and every step's end keeps its
  pools non-negative.
- Their `J′` errors at `tol = 1e-3`, against the same probes on a base run at `1e-6`:

  | × 0.7 | × 0.8 | × 0.9 | × 1 | × 1.1 | × 1.2 |
  |---|---|---|---|---|---|
  | −1.6e-3 | −1.5e-3 | −1.4e-3 | −5.1e-4 | +4.8e-4 | +9.0e-5 |

  At × 1.5 and × 2, `J′` is 2.5e-8 and 2e-21.
- A base run at `θ_A` × 0.8, walked on the `θ₀` run's step grid, is within 1.1e-4 of its
  reference.
- Probe gradients have not been measured under any rule.

**(M4) Tried and not kept,** on the test instance unless stated.
- *Stepping onto each crossing.* Each accepted attempt across which some `P` changes sign
  is retaken to end just past the first crossing, found on the step's cubic Hermite
  interpolant. About 8600 crossings are located at each tolerance. `J` is +2.6e-4 at
  `1e-4` and +2.8e-4 at `3e-5`, for about three times the cost.
- *Re-integrating a crossing member on its own,* split at its crossing: +2.5e-4 at `1e-4`.
- *A wider `P⁺`* (`ε_P = 0.05·P_b`, a declared change of the model) moves `J` by 3.9%.
  - `J`'s spread and `θ_B`'s error remain.
  - `θ_A`'s errors fall two- to sevenfold, but do not follow `tol`.
- *Treating the chain implicitly.* An additive Runge–Kutta pair with the chain's loss
  and inflow implicit saves 9% of member evaluations at matched `J`, and its embedded
  estimate misses its long steps' chain error. The chain's stages do not carry `J`'s time
  error.
- *Earlier multirate and linearised couplings* cost 6–25× at converged `J`, or held error
  plateaus.
- *An implicit pool inside the member loop:* an emptying pool's stages go negative past
  `hλ = 3.1`, against the explicit pair's 2.16.

**(M5) Creation grids from one pilot,** on the earlier version at `tol = 1e-3`, against
an order-3 extrapolation of 429, 857 and 1713 uniform members.
- *Equidistribution.* Creation density `∝ (|w″|/12 / member cost)^(1/3)`, read off one
  run at 108 uniform members, reaches 1e-3 in `J` at 100 members. That is 2.8× cheaper
  than uniform, which first reaches it at 380.
  - Its error is not monotone in the count: +2.0e-2, +7.1e-4, +2.1e-3, −4.0e-3, −5.4e-4
    and −9.3e-5 at 60, 100, 150, 180, 220 and 320 members. The own sum's part stays within
    ±3e-3 at every count; the fields' part is what swings.
  - It stays under 1e-3 only from 220 members, 1.2× cheaper than uniform.
  - Read off a 215-member pilot instead, it is worse at the same counts.
- *Other designs* did not beat it at any target: a uniform grid with a thinned tail, a
  density from the forcing alone, and densities built from the band fills of D7.
- *Uniform grids are not monotone either:* +1.9e-3, +6.65e-3 and −8.7e-4 at 250, 320 and
  380 members.

**(M6) The creation grid away from `θ₀`,** on the earlier version. A grid of 180
creation times, placed at `θ₀` by the equidistribution of M5, holds across `θ_A`
× 0.7–1.2 and two other constants × 0.8–1.25 to 2.8e-3 in `J`. Rebuilt from each point's
own run by the same recipe, its error at `θ_A × 0.7` and `× 1.2` goes from +5.9e-5 and
−8.8e-4 to −2.2e-3 and −2.5e-3.

**(M7) Second derivatives on one grid.** Not measured. Take `J = y(1)` for
`y′ = max(0, θ − t)` under Euler:
- the discrete `dJ/dθ` is a staircase in `θ`, correct to within a step;
- its second derivative by differentiation of the discrete model is zero, where the true
  one is 1.

On one grid the system's gradient jumps each time, as `θ` moves, a member's crossing of
`P = 0` slides past a stage abscissa.

**(M8) The target.** Eight records from the generator, differing only in their daily
draws, each run on 108 uniform members at `tol = 1e-4` with the shared absolute part:
- `J` runs from 7.5 to 13.5, and `ln J` has sd 0.25, so `ε = 0.025`.
- For base runs the elasticities' sd is 0.19 for `θ_B`, and 0.87 for `θ_A`'s own column
  with its derived constants held. For probes at `θ′ = θ` they are 0.50 and 1.98. Over
  the fifty constants the sd runs from `5.6e-4` to 6, and ε is a tenth of each.
- On one record the setting is inside ε on both grids:
  - tightening `tol` to `1e-5` moves `ln J` by 0.3% of its sd, and each elasticity by at
    most 3.4%;
  - doubling the members to 215 moves `ln J` by 1.7%, and each elasticity by at most
    4.3%.
  - So the margin is about 30× on the step grid and 2.4–6× on the creation grid.
  - M1–M3's gradient errors are 50–200× below `θ_B`'s ε.
- On this climate, then, accuracy does not bind at these settings. What remains is how
  cheaply ε can be met on every record, how far one grid can be shared, and the second
  derivatives.

## Facts an answer can rely on

- **(H1) Within one gradient the grids are constants.** A step size or a creation time
  that moved with `θ` would make the reported derivative that of a different function at
  each point. Between gradients the grids may change.
- **(H2) The sweep follows the branches the run took.** Each evaluation is differentiated
  along the branch it took at each clamp, switch and solution class.
- **(H3) The recording** has one row per accepted step and one per creation. A step's row
  holds its six evaluations, each with the inner problem's solutions, and the sweep
  repeats each evaluation where it ran.
- **(H4) Probes replay the recording exactly.** They cannot change the step grid or the
  fields.

**Free:**
- *Advance knowledge.* The whole forcing record is known before the run, and it does not
  depend on `θ`.
- *Stops.* A stop can be put at any time.
- *Readings.* Every rate evaluation also computes, at no cost, each member's `P`, its
  inner problem's solution class, `S_max` and `P_new`, and the chain's diagonal.
- *Interpolation.* A step's start and end states and rates are at hand, so a cubic Hermite
  interpolant over it costs nothing.
- *The sweep's adjoints.* The sweep has `λ` at every row, so any adjoint-weighted
  quantity along the recording costs a pass it already makes.
- *A test bed.* The driver reproduces the solver bit for bit and takes any stepping rule,
  so a proposed rule can be measured before it is built.
- *Reformulation.* The model may change if the change is declared and its effect on `J`
  and the gradients is measured.

## Questions

1. **What is possible?** For this structure, what accuracy, stability and cost can rules
   for the two grids attain, against brute force? If there is a bound or a known result,
   which quantities set it?

2. **Is the difficulty intrinsic or representational?** It may lie in the switches of many
   members at scattered times, the kinks, the chain's stiffness, or the pool's emptying.
   Or it may be an artefact of a choice not yet questioned: the variables integrated, the
   quadrature over creation time, the pair, the error norm, or the order in which the two
   grids are chosen. If intrinsic, what is the precise obstruction? If representational,
   what is the minimal change, and what does it gain in accuracy, stability, cost or
   simplicity?

3. **Which formulation makes the four tests hold by construction** rather than by tuning,
   for both grids, for the base run and its probes? What should the per-run diagnostic
   measure?

4. **Precedent.** Is there a literature of discretisation or controller design for systems
   like this one, and which of its results carry here? That is: many members switching at
   scattered times, a stiff forced chain, quadrature over a growing ensemble, a reverse
   sweep available, and second runs that must share the first run's grid.

We may be looking at this through the wrong variable. An answer that rejects the framing,
and says which object should be treated in its place, is welcome. If one insight makes
the problem simple, lead with it.
