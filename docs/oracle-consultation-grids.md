# Choosing the creation grid and the step grid of a field-coupled ensemble, for a functional and its derivatives

*Drafted at `42bb0d3`. Its questions were sent in the splits thread after
`oracle-consultation-splits.md`; the reply is `oracle-response-grids.md`.*

## What we ask

A run of the system below needs two grids: the times at which members are
created, and the steps. An algorithm must choose both so that a functional, its
gradients and its second derivatives meet the requirements below, on records of
the forcing it has not seen, at the least cost. Today one adaptive pass chooses
the steps under an error norm shaped by a cheap pilot, the creation times follow
a fixed rule, and a coarser companion run supplies the error estimate. Each
part was measured; the record is below.

We would like your reading of what the right algorithm is. In particular:
- today's passes (a pilot, the run, its sweep, its companion) hand each other
  almost nothing, and every evaluation of a local analysis repeats a full pass.
  Is there an organisation in which passes inform each other, and that reaches
  the requirements at lower cost? Or is one adaptive pass the right design, and
  the gains elsewhere?
- what a grid should hold so that the answers are regular functions of the
  constants on it. Second derivatives must come from the adjoint, as chords of
  reverse-mode gradients, so above all the gradient must be regular;
- whatever we have not thought to ask.

We suspect we may be looking at this through the wrong variable. If the
measurements point somewhere other than where we look, say so; we would rather
be redirected than have the present design refined.

## The problem

A system of ODEs is integrated over a horizon `T = 40` against a known scalar
forcing `s(t) ≥ 0`, one record from a family of such records. The state is:
- a five-component chain `v`, driven by the forcing, with five accumulators;
- an ensemble of members created at times `b_j`, nine components each.

Members interact only through two fields that sum over the ensemble. The
functional `J` is a weighted sum of each member's accumulated output at `T`.
Its gradient in about fifty constants `θ` of the members' rates comes from a
reverse sweep that is exact for the discretised model.

A **probe** reuses a recorded run. It integrates members of a second kind, with
constants `θ′`, created at the same times, along the recorded steps and in the
recorded fields. Its functional is `J′(θ′)`; at `θ′ = θ`, `J′ = J` to the last
bit.

`δ = T/14 600` is the forcing's sampling interval, and short times are in `δ`.

### The model

**The chain.**
```
v̇_ℓ  = in_ℓ − k·clamp(v_ℓ, 0, 1)^q − a_ℓ                   ℓ = 1…5,  k = 1.27e3,  q = 16.14
in_1 = s(t) · max(0, 1 − v_1^8),        in_ℓ = k·clamp(v_{ℓ−1}, 0, 1)^q
```
- A component at or below `v_floor = 0.0234` has its rate set to `max(0, ·)`.
- Members read the chain only through
  `φ_ℓ = min(φ_max, c_φ·max(v_ℓ, v_floor)^−6.57)`.
- The accumulators integrate `s`, `in_1`, the chain's outflow and `Σ a_ℓ`. None
  feeds back.
- After a pulse a component relaxes at a rate of about one over the time since
  the pulse; under constant forcing it sits at a stiff steady state.

**The forcing.** `s(t)` is a shape-preserving `C¹` Hermite interpolant of control
points at spacing `δ`. On a pulsed record it is zero over quiescent stretches,
most of the horizon, and positive over pulses of `2–4δ`. The test record has 814
pulses and 2931 knots where the interpolant's second derivative jumps. The
records come from generators with different means and patterns; one is
constant.

**The members.** Member `j` carries a coordinate `x`, a cumulative loss `m`, an
output integral `Y`, two smooth accumulations, a bounded pool `S`, its
accumulated output `F`, and two moments `I, N`. At each rate evaluation:
```
p_j   = argmax over p ∈ [p_lo, p_hi] of W(p; x_j, φ, Φ)          the inner problem
P_j   = P(p_j; x_j, φ, Φ)                                        a scalar net rate
c_ℓj  = C_ℓ(p_j; x_j, φ)                                         its draw on v_ℓ
P⁺    = ½ (P + √(P² + ε_P²))                                     ε_P = 1e-4
r     = S / S_max(x),        G(r) = 1 / (1 + e^{−(r − 0.1)/0.1})
g     = P⁺ · G(r)
ẋ     = g · (1 − f(x)) · κ(x),     Ẏ = g · f(x) / ν,     f(x) = 1/(1 + e^{50 (1 − x)})
Ṡ     = [u⁺ (1 − r) − u⁻ r] / (1 + λ_S τ_s),   u⁺ = P⁺(1 − G),  u⁻ = P⁺ − P
ṁ     = μ(r) = μ₀ + μ₁ e^{−r/r₀}
Ḟ     = e^{−m} · (ω(t)/ω(b_j)) · Ẏ                               ω a known positive function
```
- `P` falls through zero in quiescent stretches and rises back in the pulse that
  ends them. `P⁺` turns over `ε_P/|Ṗ|`, about `2e-7` time units, so on any step
  a sign change of `P` is a kink; the pool's rate switches with the sign of `P`
  there.
- The pools relax at `1/τ_eff` with `τ_eff ≥ τ_s = 7δ`.
- The inner problem's solution moves from the interior of its bracket to its
  lower end a median `0.26δ` before an upward sign change of `P`; that is a `C⁰`
  kink in `p_j`.

**Creation.** A member is created at `b_j` in a fixed state. The member that would
be created now is evaluated at every rate evaluation in the current fields, and its
net rate sets the creation rate `ρ_c(t)`. Only the newest member's moments move:
`İ_M = ρ_c`, `Ṅ_M = (t − b_M) ρ_c`, which give each member its hat-function
weight `w_j` in creation time.

**The fields and the functional.**
```
a_ℓ  = Σ_j w_j n_j c_ℓj + w_new c_ℓ,new,          n_j = e^{−m_j}
Φ(z) = Σ_j w_j n_j A(z; x_j) + w_new A(z; x_new)
J    = c_J · Σ_j w_j π(b_j) F_j(T)
```
- `Φ` is a cubic Hermite interpolant in `z/x_max`, `x_max` the largest member's
  `x`, on 65 fixed knots, rebuilt at every evaluation. Each member contributes
  `A(z; x_j)` to it and reads it on `[0, x_j]`.
- `π(b)` is a smooth, decreasing known function. The sums over members are
  quadratures in creation time.

**The inner problem.** Nested root-finding, cold-started at every evaluation: an
outer bracketing root-find of about 11 evaluations, each with two inner scalar
root-finds. It is 85% of a member evaluation. The rates are deterministic
functions of state and time, repeated bit for bit; a one-ulp change in the
inner problem's inputs moves its output by about 1e-9.

**The constants.** `θ_A` enters `P`, `κ` and `S_max`; `θ_B` enters the loss
rate. Neither is special.

### What a run must deliver

- `ln J`, each elasticity `d ln J / d ln θ_k`, and second derivatives of `ln J` in
  `ln θ`, for base runs and for probes, each within `ε` of its converged value.
  `ε` is a tenth of the quantity's spread across eight records from one
  generator: 0.025 in `ln J`; for `θ_A`'s elasticity 0.087 in a base run and 0.20
  in a probe, for `θ_B`'s 0.019 and 0.050; for `θ_A`'s second derivative 1.17 and
  3.8; never under 0.01 for an elasticity.
- Second derivatives come from the adjoint: a chord of two reverse-mode
  gradients at `θe^{±u}` gives a whole row, every elasticity's derivative in one
  constant, for two gradient runs. A second-order adjoint (forward over reverse)
  is out of scope. Differences of `ln J` serve only as a check. Stable,
  efficient curvature is a property we want of the solver, and so of the grids.
- Four tests:
  - *reproducible:* `tol` moved by ±5%, or every creation time by a quarter
    spacing, moves each quantity by less than `ε/3`;
  - *continuous in the constants:* on one grid, each quantity changes smoothly as
    `θ` or `θ′` moves within the grid's radius;
  - *predictable:* each error falls with each setting at that setting's order, so
    a second, looser run estimates a run's error;
  - *nothing fails* over the range of constants, for base runs and probes.
- *One grid serves a local analysis:* base runs within ±10% of the `θ₀` the grid
  was built at (0.095 in `ln θ`, about 0.39 of the base run's length scale
  `|g|/|g′|`), and probes over `θ′ ∈ θ·[0.5, 2]` (about four of the probe's length
  scales). A big move in `θ` builds a new grid. Where one grid's radius is shorter
  than the analysis, several grids or a finer one serve it.
- *Diagnosed:* every run reports its error estimate, how far its `θ` is from the
  grid's `θ₀` against the grid's radius, and its failures.
- *The least cost at those errors,* compared at matched error, on any record.
  Where the record offers no structure to exploit, the algorithm refines toward
  brute force, which carries the same guarantees.

Two workflows use the runs:
1. *Base-run gradients and second derivatives.* No constant is special; which
   second derivatives the work needs is open.
2. *Probe gradients for an optimiser,* tens per base run. The base run is first
   solved to an equilibrium (an input rate iterated until `J = 1`, several base
   runs), then probes are evaluated against its recording. A probe that reaches
   `J′ > 1` joins the base, which is solved again.

## How a run is computed today

**The grids.**
- *Stops.* The step grid lands on every knot of the forcing, every creation time
  and `T`. A stop ends the step that reaches it.
- *Creation times* are uniform, at 108, 215 or 429 over `[0, 39.63]`. Each half
  panel's contribution to `Φ` is spread as 8 point terms over the `x` its creation
  interval spans, rather than placed at the panel's own `x_j`. A run at `n` and
  one at `2n` give a two-rung extrapolation and the error estimate.
- *Steps* come from the pair and its controller below.

**The pair.** Cash–Karp 5(4), six evaluations an attempt, real stability boundary
3.73. With the end-of-step rate `f(y₁)`, evaluated on every attempt anyway, it
has a free order-4 continuous extension, which is the run's dense output.

**The controller.** `ρ = max_n |est_n|/σ_n`, with
`σ_n = W_n(t)·(tol·|y_n| + 1e-4·tol)`. Reject when `ρ > 1.1`
(`h ← h·max(0.2, 0.9ρ^{−1/5})`); on acceptance grow by `clamp(0.9ρ^{−1/6}, 1, 5)`.
The weights `W_n(t)`:
- the chain's components ×10;
- every state ×`1/clamp(R̂(t)/0.1, 0.01, 1)`, where `R̂(t)` is a pilot's share of
  `J` still to be earned after `t` (the largest over the base run and probes at
  the range's ends). It reaches 100 late in the run;
- each state's combined weight capped at 100;
- every step capped at `15δ`, which keeps a probe's pools inside the pair's
  stability region (unstable past `3.73τ_s = 26δ`).

The pilot is a run at 54 creation times and `tol = 1e-3`, 0.25–0.32 of a forward.
It reads `R(t)` within 10% wherever `R ≥ 1e-3`.

**Splits at sign changes.** After each accepted step, each member whose `P` has
opposite signs at the step's ends is cut once; a member whose `P` has the far
sign at a stage strictly inside the step, confirmed on the dense output, is cut
twice. The sign changes are located on the dense output by regula falsi. The
member alone is re-integrated over the pieces with the same tableau, reading the
chain and the other members from the dense output with its own components
spliced in, and the step's end is re-evaluated. Built in the forward; the sweep
through splits is not built, and gradients refuse a run that split.

**Prototyped and decided, not built.** Where the members' draw is under 10% of
the chain's budget at a step's start (62–67% of steps on pulsed records), the
chain is integrated alone at `1e-9` under a draw extrapolated from the last
step, corrected by a second pass under the straight line to the end draw, and
the gap between the two passes enters the norm at the members' weight. Its
inner steps are to be recorded and frozen for replays.

**Derivatives.** A recording holds every evaluation's inner solutions and fields.
The sweep walks it backwards, differentiating each inner root by one
implicit-function solve. Through a split, each cut time is to enter the sweep by
one implicit-function step at its located root; that part is designed, not
built. Second derivatives come from chords of gradients at `θe^{±u}` on the
grid frozen at `θ`. Probes walk the base run's recorded steps, with no error
control of their own.

**Cost.**
- Cost is rows first: a row is one member over one accepted step, and every
  forward, sweep and walk pays every row. A rejected attempt is paid once, by the
  forward alone.
- A run with every gradient of both kinds is about seven forwards: the base
  forward (1), its sweep (2.6), a probe's walk (0.8) and its sweep (2.6). In the
  optimiser's loop the base run is shared, and a probe costs its walk and sweep.
- The test instance is the test record at `tol = 3e-5` on 108 creation times,
  unweighted: 17 684 accepted steps, 962 505 rows, 7.06e6 member evaluations, and
  `J` 1.26e-5 below `J*`, which is the pair at `tol = 1e-8`.

## What we have measured

Each finding is on the test record unless it says otherwise. Refuted
hypotheses are kept.

### The mesh and where its cost goes

- *The grid is a mesh on the triangle of creation time `b` and time `t`.* A
  member is a vertical line from `(b_j, b_j)` to `T`, a step a horizontal line
  across every member created by then, a row one cell. Members accumulate, so
  late steps cost most: 59–61% of member evaluations fall after `t = 25`.
- *The functional is earned in one window.* From 1% to 99% of `J` is earned
  between `t ≈ 11–14` and 28–29 on five records; members created before 3.6 hold
  78–100% of it.
- *The error is a sum over cells* of each cell's local error weighted by the
  adjoint's reach into the quantity. At a fixed weighted error the fewest cells
  size each cell as `(w·C)^{−1/(p+1)}`: the sixth root of its weight along `t`,
  the cube root along `b`. A weight of 100 lengthens a step about 2× and widens a
  creation spacing about 4.6×.
  - Measured: every step after `t = 25` weighted ×100 cut steps from 17 684 to
    14 730 and member evaluations by 27%; the steps after 25 grew 1.8–2.0×.
  - Creation times after `b = 25` thinned fourfold moved every quantity at most
    0.07ε and saved 11.7% of member-steps. After `b = 10` they moved `J` by 2.5%:
    the dropped members held 0.8% of `J` but reached 2.3% through the fields.
- *The two axes price separately.* From 54 to 429 creation times the steps move
  only from 17 338 to 18 807. Steps go as `tol^{−0.15}`. Creation error goes as
  the square of the spacing under the spread rule (below). At the cheapest point
  the error budget would split about 2:5 between time and creation; today the
  time axis holds 1/2000 of `ε` in `J` while the creation axis sits at it.
- *Rejections cost little.* Taking each knot's first attempt from the chain
  alone's step, a PI step-size law, and a guard read from one step of the chain
  alone each cut the forward's rejections, which only the forward pays. Scored
  over a gradient run, whose sweeps pay every accepted row, they cost +5.8% (PI
  with those first attempts) and +0.2% (the guard).

### The time axis

- *The chain sets the steps.* Alone (`a ≡ 0`) it takes 16 447 steps, 93% of the
  coupled run's, and binds 83–91% of accepted steps at every `tol` from `1e-2` to
  `1e-7`. With the chain out of the norm the members alone need 9176 steps, but
  the explicit chain is then unstable. The chain alone costs `2·10⁻⁴` of a
  forward, and its step program matches the coupled one within a step in 89% of
  intervals. Used as a cap it caught 38% of the first-`δ` rejections and capped
  19% of accepted steps, a net cost of 0.2%.
- *Weights.* The chain ×10 saves 21% of a gradient run at `3e-5` and converges;
  ×30 and above do not, the saturated first component cycling at the explicit
  limit. The window's weight saves 21–28% of rows at ≤ 0.08ε. Together, with the
  cap of 100 and the `15δ` step cap, 31–34% on three pulsed records, every
  quantity within the bars. Without the cap of 100 a stage reached `φ_max`,
  outside the range where the members' rates have derivatives, and every
  gradient was refused: a weight frees a component's stages as well as its error.
- *The chain implicit* (ARK4(3)6L, explicit in the members): out of the norm it
  does not converge; judged by the chain alone integrated tightly against the
  recorded draw, it saves 42–55% at `3e-5` but misses the accuracy bar by a
  smooth fourth-order bias. At matched error the explicit setting wins on pulsed
  records; under constant forcing, where stability binds 83% of steps, the
  implicit chain saves 60–67%.
- *The multirate step* saves 41–45% of rows against the explicit setting at the
  same `tol`, 29–41% at matched error in `J`, every elasticity within 0.11ε. Its
  `J` error stops falling below `tol = 3e-5`, at about 0.001ε, since its 10%
  threshold does not tighten with `tol`. Judged at the chain's weight, its
  coupling error biased `J` 22 times the explicit setting's error.
- *An error outside every norm does not converge.* A partition that let the
  members take their own steps with the chain sub-stepped inside each drifted to
  a fixed bias as the members' `tol` tightened; its coupling error sat in no
  norm. In quiescent stretches the chain's motion is the members' own draw
  through an instantaneous argmax, an algebraic loop; held across a member step,
  either side makes a first-order error.

### The creation axis

- *Uniform creation times are unpredictable.* At each window's opening a profile
  that falls by `e` every `L` in creation time (`L` from 0.13 to 2.7 across
  records) makes two opposite quadrature errors whose difference changes sign
  with each halving; a companion reports 0.33–0.41 of the probe's error.
- *Spread contributions fix that.* With each half panel's term in `Φ` spread over
  its creation interval's `x`, uniform halving over 108, 215 and 429 runs on the
  square law (successive ratios 3.3–4.4) on two records, and the companion
  reports 0.95 and 0.98 of the true error. The two-rung extrapolation reaches
  0.09–0.17ε at 1.95–2.41M rows, its estimate covering 93–95% of quantities.
- *Graded openings,* refined by halving from `0.03` by 1.11 per panel, reach the
  square law on one record, and on the other only past 494 members; their companion
  reports 0.71 and 0.80 of the error, and their extrapolation takes 2.57–3.19M
  rows for 0.11–0.16ε, its estimate covering 64–78%.
- *The adjoint predicts the creation error.* Contracting the sweep's field
  adjoints with each panel's field defect, taken from the finer run's own members,
  predicts `J`'s move between rungs at 1.000×, 0.991× and 0.996×, and the probe's
  `θ_A` elasticity's at 0.986× and 0.94×, for 12% more than a sweep.
- *Under constant forcing* a front in the first 23δ of creation time separates
  members that earn `J` from members that earn almost none. A uniform pilot,
  which lumps them into its first member, reads `J` as 0.0008 against 289, and
  150 creation times converge only with the first window graded and creation
  times every `δ/16` at the front.
- *A probe has no field part:* its members only read the recorded fields, so its
  own creation times can be thinned by each one's share of `J′`. Spaced by that
  share to the power `−1/3`, a probe keeps 53–66% of its rows within 0.17ε of
  the full walk's `ln J′`. A thinned walk no longer repeats `J` at `θ′ = θ`.

### The sign changes and the splits

- *There are about 9230 per run at every `tol`,* each member changing sign about
  85 times over the horizon, in clusters: upward ones within a pulse's first
  `δ`, downward ones over a few `δ` in quiescent stretches. 726 of 14 845 steps
  at `tol = 1e-4` hold one.
- *Unsplit, a step across one errs by `h²Δ·K(ϑ)`,* `Δ` the jump in the rate's slope
  and `ϑ` the crossing's place in the step, with zero mean in `J`. `J`'s error
  then changes sign between tolerances, and under ±5% `tol` nudges the gradients
  move up to 1.65 of `ε/3` at `1e-4`; the sign changes are 70–85% of that
  spread.
- *Split,* `J`'s error at `1e-4` is +3.4e-6 against unsplit +3.6e-5, and in the
  prototype the gradients' nudge spread fell 3.4–6.4×. From `1e-3` to `3e-5` the split's error falls
  5.0×, 6.0× and 2.5×. Below `3e-5` an error both arms share stops it: at `1e-5`
  they carry +5.8e-6 and +5.3e-6, and the split at `1e-6` is still 1.05e-6 from
  `1e-7`. We have not traced that error.
- *The split's cost is fixed per split:* 0.5–0.7 ms per member step split, so
  +12.5% of the unsplit forward at `tol = 1e-3` and +7% at `3e-4` and `1e-4`,
  timed alone. 92% of it is single-member evaluations, each of which rebuilds
  both fields from every member and re-solves the inner problem of the member
  that would be created now (39% of the split's cost).
- *A cut needs a continuous extension near the step's order.* In a prototype that
  split on an interpolant through each step, a cubic through the ends made `J`
  worse (+1.6e-4 against +3.7e-5 unsplit), shrinking as `h⁴` when only the
  crossing steps were halved; a fifth-order one put `J` 9–12× nearer than
  unsplit, and the pair's order-4 extension, which the build uses, does as well.

### Regularity on a frozen grid

All on the test record at `tol = 1e-4` with 108 creation times. A frozen grid is
one recorded program, replayed at nearby constants.

**The gradient, unsplit.** Chords `(e(u) − e(−u))/2u` of `θ_A`'s elasticity `e`,
from reverse-mode gradients at `θ_A e^{±u}` on one unsplit grid, against the
converged second derivative −43.45 (its `ε` is 1.17):

| `u` | `1e-6` | `1e-5` | `1e-4` | `1e-3` | `1e-2` | `3e-2` |
|---|---|---|---|---|---|---|
| chord | −58.8 | −57.2 | −53.2 | −47.1 | −44.2 | −43.7 |

- On one unsplit grid the gradient is a staircase. It jumps wherever a sign
  change slides past a stage abscissa, and strays from a smooth curve by about
  1e-3 of itself in a base run and 3e-5 in a probe. Between jumps its slope is 15
  too steep (34%), which is what a short chord reads.
- A chord over ±1e-2 averages across the jumps, and with its `O(u²)` term removed
  it comes within 0.2ε, in both roles.

**Splits on a frozen grid.** The gradient through splits is not measured, since
the sweep through them is not built. What the splits do to `J` on a frozen grid
is measured, by the check: the second difference of `ln J` in `ln θ_A` at
`θ_A(1 ± r)`, each replay splitting anew.

| `r` | `1e-3` | `3e-3` | `1e-2` | `3e-2` |
|---|---|---|---|---|
| unsplit | −47.18 | −44.31 | −44.00 | −43.62 |
| split | −42.87 | −43.33 | −43.44 | −43.47 |

The `3e-3` column is from the prototype, on its fifth-order interpolant; it
agrees with the build within 0.02 at the other three.
- *From `r = 1e-2` up the split is stable:* under ±5% `tol` nudges it moves 0.05ε
  at `1e-2` and 0.002ε at `3e-2`; unsplit it moves 0.56ε and 0.10ε.
- *Below, a residue of 0.49ε at `1e-3`, from discontinuities of `J` in `θ`:*
  - On a fine grid of `r` between 0 and `1e-3`, `ln J` departs from a smooth curve
    by up to 1.1e-7 over intervals of 6.25e-5 in `r` (standard deviation 6.5e-8),
    in runs of one sign as well as single steps.
  - Bisected to brackets of 1e-9 in `r`: a sign change passing from one step to
    the next moves `ln J` by −0.85e-8 for one half of the passage; a pair of
    sign changes lost by the detection moves it by +0.74e-8 and −4.6e-8. About
    150 such changes fall within `r = ±1e-3`.
  - The pieces read the fields from the dense output and the unsplit step reads
    its stages, so the two disagree at each point where the split's structure
    changes.
  - *A floor under every run:* changing `θ_A` by 1e-12, where the smooth change
    is 8.3e-12, moves `ln J` by 1e-8 to 2e-8, unsplit and split alike, with the
    split's structure unchanged.
  - A difference of `ln J` divides all of this by `r²`, so the residue falls as
    `r⁻²`.
  - How much of it reaches a chord of gradients is not measured. Each gradient
    differentiates its own run's structure, so a jump in `J` does not enter a
    chord; the change in `J`'s slope across each structure change between the
    chord's ends does.
- *Two attempts to remove the discontinuities failed.* Correcting each split
  member's end so that a cut at a step's end reproduces the unsplit step left
  0.15ε, made `J` 6.7× less accurate, and made one lost pair's jump 13× larger
  (−6.2e-7). Adding to that correction a cut at every sign change the dense
  output shows on 32 points per step left 0.60ε, at 12× the forward's cost.
- *Freezing the split structure does not help the check either.* Splitting only
  the member steps split at `θ_A` itself, a sign change that moves to another
  step being integrated unsplit there, gives −42.79, −43.10, −43.58 and −43.49
  at the four `r` (the prototype).
- *Missed pairs are few.* The 32-point scan finds 6 or 7 pairs per run that the
  detection misses, nearly all in the first fifth of a step that starts at a
  knot where a pulse begins after three or more quiescent `δ`, where `P` falls to
  as low as −0.39. A pair straddling the knot is cut once in each step; when its
  first sign change passes the knot, both fall before the step's first interior
  stage and the pair is lost.
- *A grid's radius,* measured once: one unsplit grid of 108 creation times at
  `1e-4` holds every elasticity within `ε` for base runs over `θ_A` ×0.95–×1.1, but
  not at ×0.9. A probe's radius over ×0.5–×2 is measured on no record. Under
  constant forcing the members that earn 90% of `J′` are created before 2.2, 0.12
  and 0.012 time units at `θ_A` ×0.5, ×0.99 and ×1.01.

### Derivatives and their cost

- *Second derivatives* by chords of gradients cost about 68 forwards for five
  constants in both roles, against 7 for the gradients.
- *The sweep* costs 2.5–2.7 forwards: 0.83 as many member evaluations per row as
  a forward, each costing 3.26 times as much. Three changes to what it tapes would
  take 47–51% off; none changes a grid.
- *A probe already passes the nudge test unsplit* at `1e-4`: its largest move is
  0.32 of `ε/3`, and its gradient strays from a smooth curve by 3e-5 of itself,
  since its sweep holds the base run's fields fixed.

### Not yet tried

- Step weights per component and time read from a sweep's adjoint. The window's
  weight is a scalar bound on it, read from a pilot.
- Creation times placed by equidistributing an adjoint-weighted error estimate.
  The adjoint prediction above would supply the estimate; such a grid moves with
  `θ`.
- The inner problem started from a previous pass's recorded solution. It is 85%
  of a member evaluation and is cold-started today.

## Structural features, any of which may be load-bearing

We do not know which of these matter most.
- The knots, and so most of the step grid's horizontal structure, are known
  before the run; the chain alone predicts the coupled step program for
  `2·10⁻⁴` of a forward.
- The window in which `J` is earned, and the members that earn it, are known
  from a pilot for a quarter of a forward.
- The sign changes and the creation-front move with the constants; the knots and
  the window barely do. So does the split's structure: which member steps are
  cut, and how often.
- Every gradient run produces the adjoint of `J` with respect to every state at
  every step, and the field adjoints. Today they are used for the gradient only,
  and once, for the creation error's prediction.
- A recording makes every replay and probe exact, and replays are deterministic.
- Accepted rows are paid about seven times, rejected attempts once.
- Steps answer weakly to a weight (sixth root), creation spacing strongly (cube
  root).
- Members accumulate, so a creation time costs its whole remaining lifetime in
  rows, and the late part of the run, where little of `J` is earned, holds most
  of the rows.
- The inner problem is 85% of a member evaluation, cold-started, and amplifies an
  ulp in its inputs to 1e-9 in its output.
- The coupling between members and chain is an algebraic loop in quiescent
  stretches, where the chain is slow, and weak in pulses, where it is fast.
- A probe's members only read recorded fields; it has no field part, and its own
  creation times can be thinned freely except at `θ′ = θ`.
- The equilibrium base run of workflow 2 takes several base runs, each a full
  forward at a different input rate.

## Facts an answer can rely on

- The members' rates may not change. The chain's discretisation and the forcing's
  representation are part of the model.
- The sweep differentiates the discretised model as run. Creation times and step
  sizes are constants within a gradient, and values on the tape must equal the
  forward's. Anything that refines the integration, a split included, is part of
  the discretisation.
- A recording holds every evaluation's inner solutions and fields, and replays
  walk it bit for bit.
- The pair is Cash–Karp 5(4) with its free order-4 extension. The weighted norm,
  its caps and the splits in the forward are built; the multirate step and the
  spread creation rule are decided.
- Cost is rows first, then the sweep's cost per row, then the forward's, then
  rejections.
- Second derivatives come from the adjoint, as chords of reverse-mode gradients.
  A second-order adjoint is out of scope, and differences of `ln J` serve only as
  a check.

## Relatives we know of

Tell us where we have the relation wrong, or where a closer one exists.
- Goal-oriented error control and adaptivity weight each local error by the
  functional's adjoint, and refine by it in successive solves (Becker and
  Rannacher 2001; Cao and Petzold 2004). Our window's weight is that adjoint's
  crudest bound, read from a pilot.
- Richardson extrapolation and companion runs estimate an error from a second
  solve on a coarser grid.
- Waveform relaxation (Lelarasmee, Ruehli and Sangiovanni-Vincentelli 1982)
  integrates each subsystem over the horizon in the others' recorded outputs, and
  iterates. A probe is one such pass, at `θ′`.
- Continuation methods reuse a converged solution, and sometimes its mesh, as the
  start for a nearby parameter.

## Questions

1. **The algorithm.** Given these measurements, how should the creation times and
   the steps be chosen, for a base run and for the local analyses around it, to
   meet the requirements at least cost? Where is the scarce resource, and are we
   pricing it right?
2. **One pass or several.** Should the grids come from passes that inform each
   other, across the passes of one run, the rungs of a creation ladder, or the
   evaluations of one local analysis? If so, what should each pass hand the next,
   how many passes does it take, and what does it cost against one adaptive pass?
   How does such a scheme estimate its own error, and keep the four tests? If not,
   why not, and where are the gains instead?
3. **What a grid should hold.** Second derivatives come from chords of adjoint
   gradients. What must a grid, and the splits on it, hold so that the gradient
   is a regular function of the constants and a chord over a short interval is
   stable, given the discontinuities and the floor measured above? How far can
   one grid then serve, and how should a run know when it has left that radius?
4. **The two axes together.** The time axis today spends far less than its share
   of the error budget and the creation axis sits at it. Should one algorithm
   choose both, and by what reading?
5. **What have we missed?** Is there a formulation under which the step grid, the
   creation grid or the sign changes stop mattering, or one that organises the
   whole computation differently? If we are optimising the wrong thing, tell us
   what the right thing is.
