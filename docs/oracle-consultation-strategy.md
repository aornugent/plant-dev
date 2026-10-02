# A forced chain and a growing ensemble: where the computation goes, and a strategy built from it

## What we ask

We have measured where the computation of one run goes and why, component by
component, with one-variable tests. From that we have derived a strategy for the
integrator and its controller.

Our working hypothesis is this. A step and a controller can be made deterministic
enough that their behaviour follows the system's own dynamics, which we know.
Once that behaviour is characterised, one general controller can build accurate,
stable and cheap step and creation grids. It would work from what is known
before the run, the forcing and its knots, and from cheap probes that the
recording makes exact.

We would like four things from you, the third most:

1. Your reading of the strategy: is it sound, and where does it break first?
2. Your reading of the problems we cannot yet explain (the section of that name).
   They are where we think the hypothesis is weakest.
3. Whether we have missed a larger opportunity, including a reformulation under
   which parts of this stop mattering.
4. Prior art, in any field, for its parts and for the whole.

The strategy is ours and may be the wrong object. If the measurements point
somewhere else, say so; we would rather be told we are optimising the wrong thing
than have the strategy refined.

## The problem

A system of ODEs is integrated over a horizon `T = 40` against a known scalar
forcing `s(t) ≥ 0`, one record from a family of such records. The state is:
- a five-component chain `v`, driven by the forcing, with five accumulators;
- an ensemble of members created at times `b_j`, nine components each.

Members interact only through two fields that sum over the ensemble. The
functional `J` is a weighted sum of each member's accumulated output at `T`.
`dJ/dθ`, for about fifty constants `θ` of the members' rates, comes from a reverse
sweep that is exact for the discretised model.

A **probe run** reuses a recorded run. It integrates members of a second kind, with
constants `θ′`, created at the same times, along the recorded steps and in the
recorded fields. Its functional is `J′(θ′)`; at `θ′ = θ`, `J′ = J`.

The discretisation is two grids, both constants within one gradient: the
**creation grid**, the times `b_j`, and the **step grid**.

**What a run must deliver.**
- `ln J`, each elasticity `d ln J/d ln θ_k`, each second derivative, and their probe
  counterparts near `θ′ = θ` are within `ε` of their converged values. `ε` is a
  tenth of each quantity's spread across records from one generator: 0.025 in `ln J`.
- Four tests hold:
  - *reproducible:* `tol` moved by ±5%, or every creation time by a quarter
    spacing, moves each quantity by less than `ε/3`;
  - *continuous in the constants:* one grid serves `θ` within a radius and probes
    over a range of `θ′`, each quantity smooth on it;
  - *predictable:* each error falls with its setting at a known order;
  - *nothing fails.*
- One grid serves a local analysis: `J′` over `θ′ ∈ θ·[0.5, 2]`, its gradient and
  second derivative at `θ′ = θ`, and base runs within ±10% of `θ₀`.
- The least cost that meets all of this, compared at matched error.

`δ = T/14 600` is the forcing's sampling interval, and short times are in `δ`.

## The model

**The chain.**
```
v̇_ℓ  = in_ℓ − k·clamp(v_ℓ, 0, 1)^q − a_ℓ                   ℓ = 1…5,  k = 1.27e3,  q = 16.14
in_1 = s(t) · max(0, 1 − v_1^8),        in_ℓ = k·clamp(v_{ℓ−1}, 0, 1)^q
```
- A component at or below `v_floor = 0.0234` has its rate set to `max(0, ·)`.
- Members read the chain only through `φ_ℓ = min(φ_max, c_φ·max(v_ℓ, v_floor)^−6.57)`.
- The accumulators integrate `s`, `in_1`, the chain's outflow and `Σ a_ℓ`; none
  feeds back.
- The chain's Jacobian is lower bidiagonal; its diagonal is
  `−k q v_ℓ^{q−1}` (plus a term from `in_1` on the first component).

**The forcing.** `s(t)` is a shape-preserving `C¹` Hermite interpolant of control
points at spacing `δ`, from a generator of active and quiescent stretches with gamma
depths and a multiplier per year. On the test instance's record it is zero over
quiescent stretches, most of the horizon, and positive over 814 pulses of `2–4δ`;
its 2931 active knots are where the interpolant's second derivative jumps.

**The members.** Member `j` carries a coordinate `x`, a cumulative loss `m`, an
output integral `Y`, two smooth accumulations, a bounded pool `S`, its accumulated
output `F`, and two panel moments `I, N`. At each rate evaluation:
```
p_j   = argmax over p ∈ [p_lo, p_hi] of R(p; x_j, φ, Φ)          the inner problem
P_j   = P(p_j; x_j, φ, Φ)                                        a scalar net rate
c_ℓj  = C_ℓ(p_j; x_j, φ)                                         its draw on v_ℓ
P⁺    = ½ (P + √(P² + ε_P²))                                     ε_P = 1e-4
r     = S / S_max(x),        G(r) = 1 / (1 + e^{−(r − 0.1)/0.1})
g     = P⁺ · G(r)
ẋ     = g · (1 − f(x)) · κ(x),     Ẏ = g · f(x) / ν,     f(x) = 1/(1 + e^{50 (1 − x)})
Ṡ     = [u⁺ (1 − r) − u⁻ r] / (1 + λ_S τ_s),   u⁺ = P⁺(1 − G),  u⁻ = P⁺ − P
ṁ     = μ(r) = μ₀ + μ₁ e^{−r/r₀}
Ḟ     = e^{−m} · (σ(t)/σ(b_j)) · Ẏ
```
- `P` falls through zero in long quiescent stretches and rises back in the pulse
  that ends them. `P⁺` turns over `ε_P/|Ṗ|`, about `2e-7` time units.
- The pool's rate switches with the sign of `P`.
- `C_ℓ` given `p_j` is the auxiliary function the inner problem evaluates about 50
  times per solve. It costs about 1/140 of a solve: 734 instructions against
  104 640.
- `C_ℓ` depends on `p` through the gap between `p` and `φ_ℓ`.

**Creation.** A member is created at `b_j` in a fixed state. The member that would
be created now is evaluated at every rate evaluation in the current fields, and its
net rate sets the creation probability `ρ_c(t)`. Only the newest member's moments
move: `İ_M = ρ_c`, `Ṅ_M = (t − b_M) ρ_c`, which give each member its hat-function
weight `w_j`.

**The fields and the functional.**
```
a_ℓ  = Σ_j w_j n_j c_ℓj + w_new c_ℓ,new,          n_j = e^{−m_j}
Φ(z) = Σ_j w_j n_j A(z; x_j) + w_new A(z; x_new)
J    = c_J · Σ_j w_j π(b_j) F_j(T)
```
- `Φ` is a cubic Hermite interpolant in `z/x_max` on 65 knots, rebuilt at every
  evaluation. Each member contributes `A(z; x_j)` to it and reads it on `[0, x_j]`.
- `π(b)` is a smooth, decreasing known function. The sums over members are
  quadratures over creation time.

**The inner problem.** Nested root-finding, cold-started at every evaluation: an
outer bracketing root-find of about 11 evaluations, each with two inner scalar
root-finds. It is 85% of a member evaluation, and the rates are deterministic
functions of state and time, repeated bit for bit.

**The constants.** `θ_A` enters `P`, `κ` and `S_max`. A second, `θ_B`, shapes how
the loss rate responds to growth.

## The discretisation

- *The stops.* The step grid lands on every active knot, every creation time and
  `T`. Nothing happens at a knot, but a stop ends the step that reaches it.
- *The pair.* Cash–Karp 5(4), six rate evaluations an attempt, real stability
  boundary `β = 3.73`.
- *The controller.* `ρ = max_n |est_n|/σ_n` with `σ_n = tol·|y_n| + 1e-4·tol`.
  Reject when `ρ > 1.1` (`h ← h·max(0.2, 0.9ρ^{−1/5})`), and grow on acceptance
  by `clamp(0.9ρ^{−1/6}, 1, 5)`. A step clipped to a stop keeps the proposal it
  carried.
- *The cost* is member evaluations, the sum over rate evaluations of the members
  held; the chain's rates given `a` are negligible beside them.
- *The reverse sweep* runs over a recording of the forward run, one row per step
  holding the inner problem's solutions at each evaluation. It differentiates
  through them by the implicit-function theorem and costs about 2.6 forwards for
  every column.
- *Probes* walk the recording's steps exactly, in the recorded fields.

**The test instance:** one record, 108 creation times evenly spaced over
`[0, 39.63]`, `tol = 3e-5`.
- 17 684 accepted steps, 7.06e6 member evaluations, and `J` 1.26e-5 below
  `J*`, which is the pair at `tol = 1e-8`.
- A run with every gradient of both kinds costs about eight forwards: the base
  forward, its sweep, the probe's walk and its sweep.

## Where the computation goes

Each finding is a measurement on the test instance unless it says otherwise. The
refuted hypotheses are kept. We do not know which of these carries the most
weight.

**1. The chain sets the step grid on its own.**
- With `a ≡ 0`, the chain alone, under the same controller and stops, takes 16 447
  steps: 93% of the coupled run's.
- In the coupled run, 76% of steps start within `δ` of a knot. A pulse interval
  takes 5.6 steps; a quiescent interval 6.4, 3.6 of them in its first `δ`.
- The chain bounds 84–91% of accepted steps at every tolerance from `1e-2` to
  `1e-7`, and steps grow only as `tol^{−0.15}`.
- The controller rejects 40–51% of first attempts at knots where `s` starts, rises
  or falls: the carried proposal is too long. Seeding them from the last knot of
  the same kind removed those rejections but cost 7.9% more evaluations, because
  the seeds were too short and the steps had to grow back.
- The chain-alone grid predicts the coupled one. Steps per interval agree within
  one in 89% of intervals. The coupled run's first accepted step after each knot,
  over the chain alone's, has median 1.00 (10–90%: 0.87–1.3). Taken as the
  coupled run's first attempt, the chain's first step would pass at 96% of knots
  by the local error's fifth order, at a median 0.69 of the longest that would.
  The coupled run's own first accepted step, after its rejections, is 0.73.
  Run that way, first attempts at knots are rejected at 2–5%, against 6–58%.
  Rejections at knots fall from 1238 to 189 and member evaluations 3.5%.
- The chain alone costs `2·10⁻⁴` of a forward, and it tells which bound holds:
  4.9% of its steps start at `h|λ|/β ≥ 0.8` on the test record and 99.4% under
  constant forcing, against the coupled runs' 1.5% and 83%.

**2. The chain's cost is its answer to the pulses, not its decay between them.**
After a pulse a component decays as `v ∝ t^{−1/(q−1)}`, with its diagonal about one
over the time since. In `u_ℓ = v_ℓ^{1−q}`, where a component with nothing above it
decays linearly, the chain alone takes 20 275 steps. Quiescent intervals take 7%
fewer, pulse intervals 38% more. Refuted as the cost.

**3. Pulsed forcing gives no scale separation; constant forcing does.**
- On pulsed records `h|λ|/β` has median 0.27–0.45 on chain-bound steps in pulse
  intervals and 0.07–0.56 in quiescent ones, and a chain-bound step's error ratio
  has median 0.36 in pulse intervals. The chain relaxes about as fast as the
  forcing moves it.
- An additive pair with the chain implicit (ARK4(3)6L[2]SA, damped Newton on the
  chain's block) saved 9% at matched `J`, and its embedded estimate missed the
  chain's error on long steps.
- Under constant forcing the chain sits at a steady state that is stiff: 83% of
  steps start at `h|λ|/β ≥ 0.8`, and the controller rejects 16%. Held under 0.8β
  the rejections fall from 739 to 52 at the same cost. With the chain implicit,
  member evaluations fall 66%, `J` within 4e-7.
- Those rejections are the step-size law's. Our law never shrinks a step after
  accepting one, and its integral action grows each step past the stability
  limit, which is then cut back. On the chain alone under constant forcing it
  rejects 1009 attempts of 5895. A PI law, adding the previous ratio's term at
  `β = 0.04`, leaves 6, at 4898 steps against 4886 and a smaller error. Allowing
  a shrink alone leaves 760.
- On the test record the same PI law turns a third of the chain's rejections
  into accepted steps at the same attempts. That saves about 4% at matched error.
  1910–1960 rejections remain at every `tol` from `3e-5` to `1e-4`.
- Under constant forcing a uniform creation grid misses the creation window, which
  lies in the first 23δ. Those figures are on a grid graded to it.

**4. The members need about half the steps on their own.**
- With the chain and the accumulators taken out of `ρ`, the run takes 9176 steps
  and 4.14e6 member evaluations. Members bind 95% of them: 2.5 steps per pulse
  interval, 3.7 per quiescent one.
- But the explicit chain is then unstable: 21% of its steps start past `β`, and `J`
  falls 10.7%. So 9176 bounds the members' own demand from above.
- The chain sees the members only through `a_ℓ`, and `c_ℓj` given `p_j` is cheap.
  The expensive object is `p_j`.
- The partition that would use this fails (finding 9).

**5. The functional is earned in one window.** Write `R(t)` for the share of `J`'s
output still to come after `t`.
- On five records (four pulsed, and the constant record on its graded grid),
  `R(25)` is 3.4–6.1%, `R(30)` 0.48–0.83% and `R(35)` 0.04–0.08%. From 1% to 99% of
  `J` comes between `t = 11–14` and 28–29.
- Steps are spread evenly in time, but member evaluations are not: 59–61% fall
  after `t = 25` on the pulsed records, since members accumulate.
- Members created before `b = 3.6` hold 78–100% of `J`.
- A coarse pilot (54 creation times at `tol = 1e-3`) reads `R(t)` within 4%.
- `σ_n` ×100 on steps after `t = 25` saves 27% of member evaluations. `J` moves
  6e-6, and an elasticity in `θ_A` taken on each run's own steps moves 0.003ε.
  Under constant forcing it saves 3.5%, the chain there being stability-bound.
- Dropping three of every four creation times after `b = 25` saves 12% of
  member-steps. Every quantity of both kinds moves a median 0.005ε, at most 0.07ε;
  the 108-member grid's own error is a median 0.21ε.
- Dropping them after `b = 10` moves `J` 2.5%. Refuted: 2.3% of it arrives through
  the fields at members created before 3.6, though the dropped members hold 0.8% of
  `J`. A member's own share of `J` understates its weight, and `R(b)` bounds it.

**6. The crossings of `P = 0`.**
- 9235 per run, in 195 clusters. Downward clusters hold about 45 crossings over
  `6δ` in quiescent stretches; the upward ones sit within a pulse's first `δ`.
- Your earlier reading holds on the measurements. A step across a crossing errs by
  `h²Δ·K(ϑ)`, zero-mean in `J`. The gradient on one grid is first order in the
  crossing step and jumps when a crossing passes an abscissa. Its second derivative
  between jumps is off at zeroth order; a corrected chord over ±1e-2 recovers it.
  The tolerance was set at `1e-5`, 1.42× the steps of `1e-4`, because of the
  gradients' spread.
- Splitting each crossing member at its crossing was set aside at four times a
  replay. That cost was the harness's: each single-member evaluation evaluated every
  member. Counted per member, it adds 3.8%: 9229 members re-integrated in 167 256
  single-member evaluations, against 4.38e6.
- Refusing steps longer than `0.05δ` across a crossing, under a shared absolute
  error part where the pools' error is uncontrolled. The figures are `J − J*`, then
  member evaluations, at `tol = 1e-4`:
  - every member: −1.7e-5, at 3.4× the cost;
  - every member, but only on steps before `t = 25`: −2.4e-5, at 2.0×;
  - only members created before 3.6: +3.1e-4, at 1.28×. That removes 60% of the
    error.
  - So the window holds for crossings; the earliest members alone do not.

**7. The creation grid.**
- Where creation shuts is the members' doing. The member created now reads `v_1`
  alone, and `ρ_c` is near its maximum above `v_1 = 0.35` and zero at `0.23`. With
  `a ≡ 0`, `v_1` never falls that far, so the chain alone shuts creation nowhere.
  The run shuts it over 78 stretches, 7 of the 40 time units. That member
  evaluated with `Φ ≡ 0` on the run's own `v` finds 91% of that time: `a` shuts
  creation, and `Φ` adds the rest. A pilot at the run's `tol` with a quarter of
  the creation times finds 97%, at 0.24 of a forward's member-steps; at
  `tol = 1e-3` pilots find 91–92% and miss stretches of 3–6δ.
- On uniform grids two opposite errors sit at the creation window's top and
  shrink at different rates, so the probe's elasticities change sign under
  halving. Openings graded from `0.03` by 1.11 per panel put them on the square law.
- The faster of the two is `Φ`'s. Each member's term `A(z; x_j)` sits at its own
  `x_j`, and while the window's first members are more than a term's width apart
  in `x`, `Φ` and its slope in `z` are wrong at each of them. Spreading each
  panel's term over the `x` its creation interval spans, as 8 point terms per
  half panel, removes that error and leaves the other unchanged. Uniform halving
  then converges on the square law for every quantity of both kinds, median
  ratios 3.6–3.9, and the coarser rung reports the error at 0.93–1.09. A single
  spread rung is coarser, 0.7–3ε at 108, so the answer is the two-rung
  extrapolation: from 215 and 429, a median 0.009ε for the probe's quantities
  and 0.003ε for the base run's.
- Contracting the sweep's field adjoints with each panel's field defect, taken from
  the finer run's own members, predicts the field part of each move. On 108 → 215,
  215 → 429 and graded G1 → G2 it gives 1.000×, 0.991× and 0.996× for `J`, within
  0.97–1.11× per panel group. For the probe's `θ_A` elasticity it gives 0.986× and
  0.94×. It costs 12% more than a sweep.
- `J`'s field part is the chain's, through `a` and `φ`: +2.14% against `Φ`'s −0.17%
  on 108 → 215. The probe's is `Φ`'s: +0.45 against −0.08.
- A virtual member interpolated into the coarser run instead misses: 1.10×, 1.18×
  and 0.63×, and 2.9× at the window's top.

**8. Probes walk the base run's steps.** A probe feeds neither field and needs none
of the chain's steps, yet walks all 17 684. Its own demand is not measured; finding
4 suggests about half.

**9. The partition, tested: it fails our bar, and we know why.**
- *The test.* The members take their own steps under their own error control,
  with the chain and the accumulators out of their norm. Inside each member step
  the chain is sub-stepped by the same pair at its own `tol` and lands on the
  member stages' times, where the members read it. The bar, set before the runs:
  `|J − J*| ≤ 1.26e-5` on at most 4.94e6 member evaluations, or `3.66e-5` on
  4.16e6. These are the coupled run's errors at `tol` `3e-5` and `1e-4`, for 30%
  fewer evaluations.
- *The couplings.* The draw inside a member step comes from:
  - `p_j` held: `p_j`, `x_j` and the weights held at the step's start, `C_ℓ`
    exact in the chain's `v`;
  - exact: `p_j` re-solved at every chain stage, with the members held, or
    carried on their rates at the start;
  - corrections of the hold: refreshed at each member stage; extrapolated
    linearly in time; the chain's end corrected by the stages' quadrature of the
    draw each member stage evaluated, against the held draw; a corrector pass on
    the draw interpolated between the predictor's stages.
- *The frontier,* `J − J*` relative and member evaluations over the coupled run's
  at `3e-5`:

  | scheme | member `tol` | member steps | evaluations | `J − J*` |
  |---|---|---|---|---|
  | coupled | `1e-3` / `3e-4` / `1e-4` / `3e-5` | 11 001 / 12 759 / 14 845 / 17 684 | 0.62 / 0.72 / 0.84 / 1 | −4.0e-4 / +3.3e-6 / +3.7e-5 / −1.3e-5 |
  | `p_j` held | `3e-5` / `1e-6` | 6076 / 10 703 | 0.36 / 0.67 | +0.136 / +0.074 |
  | `p_j` held, on the coupled run's steps | | 17 684 | 0.82 | +0.111 |
  | exact, members held | `3e-5` | 6141 | 0.36, and 2.5 in the chain | +1.25e-2 |
  | exact, members carried | `3e-5` / `1e-5` | 6133 / 7163 | 0.36 / 0.42, and 2.5 / 2.9 in the chain | −3.0e-4 / −2.2e-4 |
  | extrapolated + end correction | `1e-4` / `3e-5` / `1e-5` / `3e-6` / `1e-6` | 5294 … 10 750 | 0.30 / 0.36 / 0.42 / 0.53 / 0.67 | +5.6e-4 / +1.1e-4 / −2.4e-4 / −3.4e-4 / −4.9e-4 |
  | corrector + end correction | `3e-5` / `1e-5` | 6121 / 7142 | 0.66 / 0.78 | −4.4e-5 / −1.4e-4 |

- *The hold is first order:* its error falls 1.8-fold for 1.76 times the steps.
  The nearest pass, the corrector with the end correction, is 22% cheaper than
  the coupled run at `1e-4` at 1.2 times its error, and its elasticity in
  `θ_A` on fixed steps is 0.05ε from the coupled run's. At errors near 5e-4,
  0.02ε, the extrapolated hold is twice as cheap as the coupled run at `1e-3`.
- *The error is in the chain's budget, `Σ_ℓ a_ℓ`.*
  - The hold draws 2.85% too little.
  - Correcting only the budget at each step's end removes 91% of `J`'s error.
    The rest is the members reading too high a `v` inside the step.
  - `J` amplifies the budget: scaling the coupled run's draw by 0.999 raises `J`
    by 0.22%.
- *It is in the quiescent stretches.*
  - Their steps carry 108% of the deficit, and pulse steps −8%, since a rising
    `v` makes the hold over-draw.
  - 49% of the deficit falls 10–30δ after a pulse and 32% later. 95% of it is in
    `v_1`.
  - At a member step's end the deficit is a median 0.5% on steps of 1–3δ, 2.2%
    on 3–10δ and 5.2% beyond.
- *The mechanism.* In a quiescent stretch `p_j` sits close to `φ_1`, so the draw
  is a small difference. Held while `φ_1` rises, the gap closes, where the inner
  problem would move `p_j` to keep drawing.
- *Two more facts.* The members created at 0 and 0.37 carry 94% of `J`'s excess.
  Refusing long member steps across crossings leaves the corrected couplings'
  residuals in place.
- *So the coupling is strongest exactly where the chain is slowest.* In a
  quiescent stretch the chain's motion is the members' own draw, through a `p_j`
  that moves to sustain it. Holding either side across a member step leaves a
  first-order error in the budget. A partition would have to move both `p_j` and
  the members within the step to high order, which is the coupled step.

## What we cannot yet explain

These are the measurements with no root cause, and the ones with a mechanism but
no cure. We list what each has ruled out.

**No root cause.**
- **The corrected partitions stall** (finding 9). Their error stops at 1e-4 to
  5e-4 and does not fall as the members' `tol` tightens. The extrapolated hold
  with the end correction moves from +1.1e-4 to −4.9e-4 between `3e-5` and
  `1e-6`; the corrector from −4.4e-5 to −1.4e-4 between `3e-5` and `1e-5`.
  - Ruled out: the chain's own `tol` (`1e-6` gives +1.2e-4 against +1.1e-4) and
    refusing long steps across crossings.
  - Exact coupling with the members carried on their start rates leaves −3.0e-4
    and −2.2e-4 at `3e-5` and `1e-5`.
  - In every variant the residual sits in the first two members.
- **The rejections that remain.** With the chain seeds, 2888 of 20 804 attempts
  are still rejected. 69% are within `δ` after a knot, not on it, and the chain
  bounds three quarters of those near knots. A rejected attempt is a median 1.47
  times the step then accepted from its start. On the chain
  alone a PI law leaves 1910–1960 rejections at every `tol` from `3e-5` to `1e-4`.
  We have not isolated what they are; seeds and PI together are untested.
- **The spread `Φ`'s sweep** (finding 7) ran 2.0×, 1.7× and 3.4× slower at 108,
  215 and 429 members, under varying load, and took twice the memory at 429.
  The forward and the probe cost what the lumped `Φ` costs per member-step.
  Ruled out: crossings of the members' coordinates, and the order of the
  members at the boundary.
- **Locating crossings on a cubic made `J` worse** (the events spike, interim).
  At `tol = 1e-4`, `J − J*` is +3.7e-5 plain, +1.6e-4 with crossings located on
  the member's cubic interpolant, and +4.0e-6 on a quintic. The spike since found
  crossing pairs, down and back up, inside one step, which a single cut missed;
  its runs with two cuts are in progress.
- **The implicit chain's error does not fall with its `tol`.** Under constant
  forcing it is +3.7e-7 at `3e-5` and −1.4e-6 at `1e-5`. On the test record its
  embedded estimate missed the chain's error on long steps.
- **A record with a higher mean forcing.** There the graded creation grid
  reaches the square law only past 494 members, against 125 on the test record.
  We have not looked for why.

**A mechanism, no cure yet.**
- **`J`'s error changes sign with `tol`:** −4.0e-4, +3.3e-6, +3.7e-5, −1.3e-5 and
  +5.2e-6 at `1e-3`, `3e-4`, `1e-4`, `3e-5` and `1e-5`. So at these levels a
  looser run cannot estimate a run's error. Your reading, the crossings' `h²Δ`
  errors of zero mean, fits the measurements of finding 6. Per-member events
  are its cure under test; the gradients' spread under `tol` nudges is the test
  that matters.
- **Grazing.** One crossing pair, down and back up within `0.004δ`, vanished
  under a 1e-4 change of `θ_A`. With events, the discrete `J` jumps there by the
  error its split removed.
- **The first members carry the errors.** The held partition's error, the
  corrected partitions' residual, the creation grid's field error and 78–100% of
  `J` all sit in the members created first. Every scheme's weakest point is where
  `J` is earned.

## A strategy built from these

Each part rests on a finding above. Part (c) of item 3 has been tested and fails
(finding 9); part (d) is being spiked as we write.

1. **Before the run.** Stops at the knots, as now. The chain alone (`a ≡ 0`,
   `2·10⁻⁴` of a forward) seeds each knot's first attempt and the shape of the
   step grid, and says whether item 3(b) is needed (findings 1 and 3).
2. **One coarse pilot,** at the run's `tol` with a quarter of the creation
   times. It gives `R(t)` and where creation shuts (findings 5 and 7).
3. **The step.**
   - (a) `σ_n` weighted by `R(t)`.
   - (b) The chain implicit only where `h|λ|/β` shows stability binding (finding 3).
   - (c) A partition, now tested and killed. The members took their own steps, and
     inside each the chain was sub-stepped at its own resolution, with
     `a_ℓ = Σ w n C_ℓ(p_j held from the member step's start; x_j, φ(v))`. The hold
     under-draws in quiescent stretches at first order (finding 9).
   - (d) Per-member events at crossings. Locate `t_c` on the member's interpolant,
     split that member's update there, and differentiate `t_c` through the sweep.
     That would let `tol` loosen from `1e-5` (finding 6).
   - (e) The inner problem started from the member's last solution, inside its
     bracket. The sweep differentiates at the solution whatever the start, and
     the recording holds the solutions, so replays need no re-solve. Untested;
     it is the largest share of the cost.
   - (f) A PI step-size law, with the chain's seeds at the knots (finding 3).
4. **The creation grid.** Graded openings at each window, or uniform halving with
   each panel's term spread in `Φ` and the two-rung extrapolation reported; in
   either case dropped to a quarter after the window closes, and refined where
   the field-adjoint map points (findings 5 and 7).
5. **Probes on their own steps**, against the recorded fields interpolated in time
   (finding 8).

**What it might buy,** each factor measured alone, not as a product:
- from the partition, nothing at our bar. It is 2× only at `J` errors near 5e-4,
  and its error does not converge there;
- up to 1.42× from `tol = 1e-4` in place of `1e-5`;
- 1.27× from the window in time, and 1.12× from the creation grid;
- 1.6× and more in the probes;
- 3.5% of member evaluations from the seeds, measured: they remove 85% of the
  rejections at knots;
- from a PI law, the constant forcing's 17% of attempts rejected, and about 4%
  on the test record, measured on the chain alone;
- 2–3× on the forwards' member evaluations from (e), your earlier estimate. The
  sweeps differentiate at recorded solutions and gain nothing from it.

**The spike still running: per-member events,** at their real cost and on the
gradients' spread under `tol` nudges. Its interim cost is 12.4% more member
evaluations, not 3.8%: locating, sub-steps and corrected step ends add up. Its
interim `J` lands 9–12× nearer `J*` with a quintic interpolant, at `3e-5` and
`1e-4`.

## Where we think it could break

- **The chain sets the step grid, and nothing yet lets the members off it.**
  With the partition killed, the members pay for every one of the chain's steps,
  93% of the coupled run's. Every partition we have tried has failed: holding
  `a` plateaued at 10–12% error, linearising `a` in `v` missed a drying
  component's draw by up to 440%, full coupling at every chain stage cost 13×,
  and holding `p_j` fails as finding 9 says.
- **Events and grazing.** A crossing pair that vanishes under a small change of
  `θ_A` takes its split with it, so events bring a jump of their own.
- **Probes on their own steps** need the fields between recorded instants. The
  sweep would treat that interpolant as data, and its error has no controller.
- **The warm start and reproducibility.** Started from the last solution, a
  rate depends on the order of evaluations at the inner solve's tolerance, and
  a rejected attempt changes the next start. A rerun stays bit for bit, since
  the order repeats; continuity in the constants rests on the inner tolerance
  sitting well under `tol`.
- **One record behind most of this.** On a record with a higher mean forcing
  the graded creation grid reaches the square law only past 494 members. The
  spread `Φ`'s ladders on the records with higher and lower mean forcing stop at
  215 members.

## Prior art we know of

Each part has a near relative. Tell us where we have the relation wrong, or
where a closer one exists.
- *The partition.* Multirate infinitesimal step methods (Wensch, Knoth and Galant
  2009; Sandu's MRI-GARK, 2019) integrate the fast block with the slow block's
  tendency held over each slow stage. We held the slow block's argmax `p_j` and
  recomputed the tendency through the cheap map, and it failed (finding 9). Our
  pilot with full coupling at every fast stage cost 13× the member evaluations.
  If these method classes have a form for a coupling strongest where the fast
  block is slowest, we have not found it.
- *The controller.* PI step-size control (Gustafsson, Lundh and Söderlind 1988;
  Söderlind 2002) damps the step's cycle at a stability limit. We have used it
  on the chain alone.
- *Events.* Sensitivities across the switching surfaces of hybrid systems
  (Galán, Feehery and Barton 1999) give the adjoint's jump at an event. For
  thousands of independent surfaces, the nearest form we know is each member
  updated on its own, as in asynchronous variational integrators (Lew, Marsden,
  Ortiz and West 2003).
- *The window.* Goal-oriented error control weights each local error by the
  functional's adjoint (Becker and Rannacher 2001; Cao and Petzold 2004). `R(t)`
  is that weight's crudest bound; a pilot's own sweep would give it per
  component.
- *The seeds.* Starting-step selection after a breakpoint (Gladwell, Shampine and
  Brankin 1987) costs evaluations of the whole system; the chain alone costs none
  of the members'.
- *The warm start.* Predictor–corrector continuation of a parametrised root
  (Allgower and Georg 1990) starts each solve from the last solution and its
  derivative. The sweep computes that derivative already, by the
  implicit-function theorem.
- *The whole.* Waveform relaxation (Lelarasmee, Ruehli and Sangiovanni-Vincentelli
  1982) integrates each subsystem over the horizon in the others' recorded
  outputs, and iterates. A probe is one such pass, at `θ′`.

## Facts an answer can rely on

- The forcing and its knots are known before the run.
- A recording holds every evaluation's inner solutions and fields. Replays and
  probes walk it bit for bit, and the inner problem is cold-started, so the rates
  are deterministic.
- The sweep differentiates the discretised model as run. Creation times and step
  sizes are constants within a gradient. Values on the tape must equal the
  forward's.
- The members' rates may not change; the chain's discretisation and the forcing's
  representation are part of the model, and a change to them is a change of model.
- Cost is member evaluations, the inner problem 85% of them; a run with every
  gradient is about eight forwards.
- The coupled run at `tol = 3e-5` is the reference for cost, and its `J` is 1.26e-5
  from `J*`, far inside `ε`. The gradients and their reproducibility are what bind.

## Questions

1. Is the strategy sound? Where does it break first? Which of our doubts is real,
   and what have we not listed?
2. The problems we cannot yet explain: for each, what is your reading, and what
   would you test first? In particular:
   - why the corrected partitions' error grows as the members' `tol` tightens;
   - what the rejections left after seeds and PI are;
   - why the spread `Φ` slows the sweep.

   With the partition killed, is there any way for the members to step at their
   own pace while the chain resolves the forcing?
3. Prior art, in any field:
   - a fast forced chain coupled to an ensemble through an expensive argmax whose
     output enters the chain through a cheap map;
   - events at many independent switching surfaces in a large ensemble;
   - a functional earned in a window known only from a pilot;
   - a step grid warm-started from a reduced model of its binding block.

   Where have these been solved, and at what cost?
4. What have we missed? Is there a reformulation under which the chain's
   resolution, the crossings or the creation grid stop mattering? Or one that
   organises the whole computation differently? For instance, around the probe
   landscape `J′(θ′)` rather than the base run, or around the family of records
   rather than one record. If we are optimising the wrong thing, tell us what
   the right thing is.
