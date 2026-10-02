# The grid's cost and error: a debugging record

Which interactions of the system, the solver and the controller block a
predictable error, cost efficiency or inflate runtime, debugged from the runs
on disk with a few cheap probes. Long drought, seed 31, 108 uniform nodes,
Cash–Karp at `3e-5`, unless stated.

Each symptom below is reproduced first, then traced to the component that
produces it. A root cause is claimed only where a test of one variable confirmed
it. Refuted hypotheses are kept.

The scripts:
- `harness/step_program.R` reads saved SCM runs.
- `harness/ark_prototype.R` is the R driver that reproduces the SCM's Cash–Karp
  bit for bit, on v12 (`lib_v12t`). Its new options are `ATTEMPT_LOG`,
  `KNOT_SEED`, `TOL_SOIL`, `ATOL`, `LATE_FROM`, `REGIME`, `TIMES`, and
  `SWITCH_BORN` with `SWITCH_UNTIL`.
- `harness/attempts.R` reads the driver's attempt logs,
  `harness/crossings.R` its crossing logs and refusal runs, and
  `harness/soil_steps.R` what bounds its steps. `harness/soil_chain.R`
  integrates the soil chain alone, `harness/warm_start.R` sets its steps
  against the coupled run's, and `harness/chain_creation.R` finds where
  creation shuts.
- `harness/replay_timing.R` times the invader's replays on `PLANT-98`.
- `harness/j_window.R` reads `harness/layer_heights.R`'s every-node runs, and
  `harness/error_structure.R` the thinned schedules.
- The driver's outputs and logs are in `docs/measurements/grid-dynamics/`.

## The symptoms

| | symptom | root cause | state |
|---|---|---|---|
| 1 | steps: 17 683 on long drought, 3637 on the constant record (3951 on its resolved grid) | the soil's accuracy at the norm's tolerance through each rain-rate change | established; no cheap lever |
| 2 | 17.5–21% of attempts rejected | near knots, the controller probing the soil's new time scale; far from them, the members' sign changes and near-empty pools | established; the probing is cheaper than a seed |
| 3 | the invader's first replay costs about two forwards | `run_mutant` re-runs the resident to keep its field | established; fixed on `PLANT-99` |
| 4 | `J`'s time error does not follow the tolerance under plant's default absolute tolerance | near-empty pools, and steps across members' sign changes | established earlier; the pools fixed by the tied tolerance |
| 5 | gradients are a staircase in θ | sign changes sliding past the stages | established earlier |
| 6 | the invader's node error changes sign under halving on uniform nodes | two opposite errors at the layer's top that shrink at different rates | established; the field part is the soil's for `J` and light's for the invader |
| 7 | the constant record rejects 16% with no knots | the soil's stability bounds its steps, and the controller crosses the limit | established; the implicit soil pays there |
| 8 | on the pulsed records 59–61% of member-steps come after t = 25, where at most 6.1% of `J` is still to be earned | the tolerance and the spacing weight every time and node alike | established on long drought |
| 9 | the sign-change refusal costs 3.4× | it refuses after the window too | half established: limited to the window it keeps `J` for 43% less; limited to the cohort that earns `J` it does not |
| 10 | the soil binds 84–91% of the steps | the soil chain's own answer to each rain change, resolved at every member's leaf solve | established; the members alone need about half the steps |
| 11 | the per-member split that cures the gradients costs 4× | the driver evaluates every member to read one | established: 3.8% counted per member |

## 1. The steps

**Reproduced** (`step_program.R`):
- *Rain days hold 44% of the steps,* 5.6 each, rising with depth: 2.9, 4.0,
  5.9 and 9.6 steps by depth quartile.
- *Dry intervals hold the rest,* about 3.5 + 2.8 ln(length in days) each
  (R² 0.42).
- *The constant record takes 3637 steps,* against 9133 to 21 921 on the
  pulsed records. Its resolved grid takes 3951 (§7).
- *Nodes barely move it:* 17 338 to 18 807 steps from 54 to 429 nodes.
- *The tolerance moves it weakly:* steps go as tol^−0.15.

**Traced** (the driver's ladder, `ck_u108_*` logs):
- *The soil binds 84–91% of accepted steps* at every tolerance from `1e-2` to
  `1e-7`.
- *At `3e-5` those steps are accuracy-limited:* 8.4% of steps start within 0.8
  of the soil's explicit stability limit (1.5% under the tied tolerance),
  against 37% at `1e-2`.

**Hypothesis: the soil's accuracy is more than `J` needs.** The soil binds the
steps, and the stepper scope found its stages carry little of `J`'s time error.

**Test: the soil's tolerance weights ×10, alone.** Under the tied tolerance
(`ATOL=1e-4`). J* = 12.6687135, Cash–Karp at `1e-8`:

| tol | soil weight | accepted | member evaluations | `J − J*`, relative |
|---|---|---|---|---|
| `3e-5` | 1 | 17 684 | 7.06e6 | −1.26e-5 |
| `3e-5` | 10 | 13 937 | 5.70e6 | −2.39e-5 |
| `1e-5` | 1 | 21 106 | 8.42e6 | +0.52e-5 |
| `1e-5` | 10 | 16 385 | 6.69e6 | −1.23e-5 |

- *Refuted.* The looser soil adds 1–2e-5 to `J`'s error, as much as the error
  it had. At a matched error it saves about 5%: ×10 at `1e-5` against ×1 at
  `3e-5`.
- *The earlier reading came from plant's default absolute tolerance.* There the
  pools' uncontrolled error swamped the soil's, and one run's `J` is a draw of
  ±2e-4. Under that tolerance the same ×10 seemed free (`ck_u108_*_soil10` logs).
- *The driver's tied run matches today's SCM run:* 17 684 accepted steps against
  17 683.

**Root cause.** The steps are what the soil's accuracy costs through each
rain-rate change, and that accuracy reaches `J` in proportion. So the record
predicts the cost, but no weight on the soil buys accuracy cheaply. What
remains is the method's efficiency on the soil, or the tolerance itself: `J`'s
time error at `1e-4` is 3.7e-5, under 2e-3 of its ε.

## 2. The rejections

**Reproduced.** The SCM rejects 18–21% of attempts on every record and at every
node count (`step_program.R`); the driver rejects 17.5% (`attempts.R`).

**Traced** (one attempt log, `attempts.R` on `ck_u108_3e-5_v12t`):
- *Near knots, the soil rejects.* 85% of rejections start on a knot (40%) or
  within the day after one (45%), and the soil rejects 94% of these.
- *Between 1 and 10 days after a knot there are 32.*
- *In dry spells longer than 10 days, members and storage reject.* Members
  reject 266 there, storage 115 and the soil 2, at a rate of 25–27%.
- *By the change, first attempts at a knot are rejected* at 0.51 where rain
  starts, 0.51 where it falls, 0.39 where it rises and 0.07 where it stops.
- *A rejected first attempt at a knot is usually the whole day to the next
  knot* (median 1.0 day). The step accepted from there has a median of 0.31
  days.

**Hypothesis: the carried proposal.** At a rain-rate change, the controller's
first attempt is sized for the rain before it.

**Test: cap that attempt at the size last accepted after a knot of the same
kind** (`KNOT_SEED=1`), alone:
- *Rejections on knots fall from 1185 to 2.*
- *But accepted steps within a day of a knot rise from 7763 to 10 077,* and
  member evaluations by 7.9%.
- *`J` moves 3.8e-5,* within one run's draw at this tolerance.

**Root cause.** The mechanism holds, but it is not the inefficiency. The
rejected attempt is the controller's probe of the soil's new time scale, and a
cheap one: its estimate shrinks the step straight to the size the soil
accepts. A seed from the last knot of the same kind is too small, so the steps
must grow back. The cost is in the accepted steps (symptom 1). The far
rejections are where the time error's sources sit (symptom 4).

## 3. The invader's replay

**Reproduced.** On the uniform runs the invader phase takes 1.7–1.8× the stand's
forward (`step_program.R`).

**Traced.** `SCM::run_mutant`'s first call re-runs the resident with its field
kept, to record it (`scm.h`, `run_mutant`). It does so even when the stand was
just run with its trajectory recorded.

**Test** (`replay_timing.R`, uniform 108, tied tolerance at `3e-5`):
- the forward takes 114.8 s;
- the first replay 203.5 s;
- the second 91.0 s;
- the invader's `J` is identical in all three.

**Root cause, confirmed.** The first replay holds a second resident forward. It
is about 12% of a run with every gradient of both roles, and paid once per
resident, so it is small across a landscape of invaders.

**Fixed** on `PLANT-99` (aornugent/plant#99). A run that keeps its states also
keeps the field each evaluation built, where no evaluation reads it, and the
first invasion walks that.
- Under the same load, the first replay takes 139 s against 300 s on `PLANT-98`,
  and the walk itself is unchanged.
- `J`, the stand's gradient and an invader's at `lma` × 0.95 are bit-identical.
- A recorded forward holds 130 MB more after it, about 7.4 kB a step, and the
  peak over a forward and an invasion does not move.

## 4–6, established earlier

- *`J`'s time error* (`docs/archive/scope-imex-stepper.md` §7; the spec's step
  2(a)).
  - Near-empty pools refilling after a sign change carried a survival error as
    large as the offspring part, because their tolerance weight is absolute in
    kg. The tied tolerance fixes that: `J` within 0.46·tol from `1e-3` to
    `3e-5`.
  - The steps across members' sign changes remain. Cash–Karp's estimate
    under-reports them 4.6× (median), and every treatment tried costs 3–4×:
    refusal, split, and locate-and-step. §9 limits the refusal to the window.
- *The staircase* (the spec's step 5). The kinks bind curvatures (a chord over
  ±1e-2) and small differences (0.004–0.007 in the invader's `lma` elasticity
  at ±1e-6).
- *The step program's path dependence.* A one-ulp change in the absolute
  tolerance (`3e-9` against `1e-4 × 3e-5`) moves `J` by 4.7e-7 at `3e-5`.
- *The node error* (`docs/measurements/creation-grid.md`, *What sets the node
  error on long drought*). The field adjoint map splits its field part by
  channel: `J`'s is the soil's, the invader's light's
  (`docs/measurements/field-adjoint-map.md`). Whether a canopy that cannot comb
  removes the invader's is under test.

## 7. The constant record's rejections

**Reproduced.** On its resolved grid (`const_Gbf16`, 150 nodes; uniform nodes
lump the founders there) the SCM rejects 15.8% of attempts, 739 against 3951
accepted. The driver reproduces both counts and `J` to every printed digit.

**Traced** (`attempts.R` on the driver's attempt log, `ck_const_Gbf16_3e-5`):
- *The soil rejects 664 of the 739;* storage 25, members 48.
- *The soil binds 91% of the accepted steps,* and 83% of them start within 0.8
  of its explicit stability limit, 24% beyond it. On long drought under the tied
  tolerance it is 1.5%, and none beyond.
- *A rejected attempt is a median 1.23 times the size then accepted* from its
  start.
- *The tolerance barely moves the steps:* every weight ×100 after t = 25
  saves 1.7% of them (§8), against 17% on long drought.

**Hypothesis: on the constant record the soil's stability, not its accuracy,
bounds the step,** and the controller grows each step past the limit and is
rejected back. Constant rain holds the soil near a steady drainage, whose
fastest mode is stiff, with no rain change for the accuracy to follow.

**Test: the soil held under the limit (`METHOD=held`), and taken implicitly
(`METHOD=ark`),** each alone:

| method | tol | accepted | rejected or thrown | member evaluations | `J − J*`, relative |
|---|---|---|---|---|---|
| Cash–Karp | `3e-5` | 3951 | 739 | 3.76e6 | +6.1e-9 |
| | `1e-5` | 4111 | 840 | 3.96e6 | +1.0e-8 |
| held under 0.8 of the limit | `3e-5` | 4610 | 52 | 3.74e6 | −1.2e-8 |
| ARK, the soil implicit | `3e-5` | 1413 | 266 | 1.30e6 | +3.7e-7 |
| | `1e-5` | 1808 | 270 | 1.61e6 | −1.4e-6 |

J* = 289.2738962 is Cash–Karp at `1e-8` (6726 steps).

- *Held under the limit, the rejections fall from 739 to 52.* The steps are
  shorter and more, so the cost does not move.
- *Taken implicitly, the soil no longer bounds the step:* 64% fewer steps and
  66% fewer member evaluations at `3e-5`, with `J` within 4e-7, and 59% fewer at
  `1e-5`. Cash–Karp's error is far below what any objective needs, and
  tightening its tolerance threefold adds 4% to its steps.
- *ARK's error does not fall with its tolerance* (+3.7e-7, then −1.4e-6), as on
  long drought, where its embedded estimate missed the layers' error on long
  steps. Both are below 1e-4 of ε.

**Root cause, confirmed.** Constant rain holds the soil where its stiffness, not
its accuracy, bounds an explicit step. The controller grows each step past the
stability limit and is rejected back, and the step count is set by the limit,
not the tolerance. Here the implicit soil pays, as it did not on long drought,
whose steps are accuracy-bound (`docs/archive/scope-imex-stepper.md` §7, step 4).
A run tells which regime it is in from `h|λ_soil|/β` at its steps' starts: 83%
at 0.8 or more here, 1.5% on long drought.

## 8. The cost after `J` is earned

**Reproduced** (`j_window.R`, every node). R(t) is the share of `J` still to be
earned after t; the pulsed records are on uniform 108 at `3e-5`, the constant
record on its resolved grid, `const_Gbf16`.

| record | R(15) | R(20) | R(25) | R(30) | R(35) | member-steps after 25 | after 30 |
|---|---|---|---|---|---|---|---|
| long drought | 87% | 18% | 5.0% | 0.77% | 0.084% | 61% | 44% |
| long wet | 86% | 20% | 5.1% | 0.83% | 0.071% | 60% | 44% |
| dry | 85% | 22% | 6.1% | 0.72% | 0.058% | 60% | 43% |
| episodic | 90% | 25% | 6.0% | 0.48% | 0.039% | 59% | 39% |
| constant | 54% | 16% | 3.4% | 0.55% | 0.062% | 37% | 25% |

- *One window on every record.* From 1% to 99% of `J` is earned between
  t = 13.4–13.7 and 29.2–29.3 on the pulsed records, and between 10.8 and 28.5
  on the constant record.
- *The steps are spread evenly in time,* 34–38% after t = 25 on every record.
  Member-steps come later, since every node carries on to the end. The constant
  record's are earlier because its grid's nodes cluster at the founders' front.
- *Nodes born after 20 hold at most 2.4e-4 of `J`.* The cohort born before 3.6
  holds 78–100% of it.
- *A pilot gives R(t).* On long drought, uniform 54 at `1e-3` reads it within
  1–4% at t = 15–35. On the constant record a uniform pilot lumps the founders,
  as uniform grids do there, and reads `J` as 0.0008.

**Traced.** An error made at t, in a step or in a node born at t, changes `J`
only through what is earned after t, so R(t) bounds its weight. The controller
holds every state to one relative tolerance at every time, and the schedule
spaces nodes alike throughout.

**Hypothesis: the steps and nodes past the window cost `J` nothing measurable.**

**Test 1: every tolerance weight ×100 on steps that start after t = 25**, alone
(the driver's `LATE_FROM=25`, at `3e-5` under the tied tolerance):

| record | | accepted | member evaluations | `J − J*`, relative | `J`'s elasticity in the trait `lma`, frozen steps |
|---|---|---|---|---|---|
| long drought | baseline | 17 684 | 7.06e6 | −1.26e-5 | −4.98010 |
| | ×100 after 25 | 14 730 | 5.13e6 | −1.87e-5 | −4.98034 |
| constant | baseline | 3951 | 3.76e6 | +6.1e-9 | −4.40100 |
| | ×100 after 25 | 3883 | 3.63e6 | +4.7e-9 | −4.40100 |

- *Long drought:* member evaluations fall 27%. `J` moves 6e-6 and the
  elasticity 2.4e-4, 0.003 of the `lma` elasticity's ε as a scale.
- *Constant:* they fall 3.5%; `J` moves 1.4e-9 and the elasticity under 1e-5.
  Its steps are bound by the soil's stability, not its accuracy (§7), so a
  looser tolerance buys little.
- The elasticity moves `lma` as a trait, through TF24's hyperparameterisation,
  by central differences at 1e-5 on each run's own accepted steps. It is not
  the gradient's partial in `lma`.

**Test 2: nodes born after b = 10 thinned fourfold** (every fourth kept, 48
nodes; `error_structure.R`).
- `J` falls 2.5%. Refuted.
- Of the 2.6% move back to uniform, 2.3% is the field part at the first
  cohort's nodes: lumping the later cohorts changes the water and light seen by
  the cohort that earns `J`. Those later cohorts hold 0.8% of `J`.
- So a node's own share of `J` understates its weight. R(b) bounds it, and
  R(10) is all of `J`.

**Test 3: thinned fourfold after b = 25** (79 nodes).
- `J` moves −1.9e-4 relative, 0.008ε in `ln J`, and member-steps fall 11.7%.
- Every quantity of both roles outside the small four moves a median
  0.005–0.006ε, at most 0.07ε (the invader's `recruitment_decay`). Uniform
  108's own move to 215 nodes is a median 0.21–0.22ε.

**Root cause, confirmed on long drought.** The controller spends a third of its
steps after t = 25 on every record, and on the pulsed records three fifths of
its member-steps, where at most 6.1% of `J` is still to be earned. Weighted by R(t), those steps and the
nodes born there can be coarsened at no measurable cost: 27% of member
evaluations in time and 12% of member-steps in nodes.

**Caveats.**
- Tests 2 and 3 are on long drought; the window is measured on all five
  records.
- A shared grid's window must cover every invader in the analysis; one that
  reproduces later widens it. Not measured.
- R(t) bounds the weight. How far a tolerance or a spacing can be loosened is
  measured only by tests 1 and 3.
- Where stability binds the steps, as on the constant record, the time weight
  buys little.

## 9. Which crossings carry `J`'s time error

**Hypothesis: the crossings that carry `J`'s time error are the cohort's that
earns `J`,** born before 3.6, on steps before t = 25. Step 4 traced the error to
the offspring of members born before 3.5, accruing over t = 12–20
(`docs/archive/scope-imex-stepper.md` §7). On the tied baseline at `3e-5`
(`crossings.R` on its replay's `CROSS_LOG`) those crossings are 1212 of 9235,
and their clusters span 149 days against 654 for every member's. Capping steps
at 0.05 days across them is about 3000 steps, against 13 000.

**Test: step 4's refusal (`SWITCH_DAYS=0.05`) limited to those crossings
(`SWITCH_BORN=3.6`, `SWITCH_UNTIL=25`),** under plant's default absolute
tolerance as step 4 ran it. `J − J*` relative, member evaluations in brackets:

| refusal | `1e-3` | `3e-4` | `1e-4` |
|---|---|---|---|
| none | −2.4e-4 (3.70e6) | +1.04e-3 (4.07e6) | +8.1e-4 (4.64e6) |
| every member | −3.0e-4 (15.05e6) | −1.0e-4 (15.40e6) | −1.7e-5 (15.88e6) |
| born before 3.6, before t = 25 | −3.4e-4 (5.03e6) | −3.5e-5 (5.40e6) | +3.1e-4 (5.96e6) |
| every member, before t = 25 | | | −2.4e-5 (9.12e6) |
| born before 3.6, at every time | | | +3.2e-4 (6.60e6) |

- *Refuted as stated.* The cohort's crossings carry about 60% of `J`'s error at
  `1e-4`: limited to them, the refusal takes it from +8.1e-4 to +3.1e-4, where
  every member's takes it to −1.7e-5. Members born later carry the rest, though
  they hold 7% of `J`.
- *But the window holds for the crossings.* Limited to steps before t = 25, the
  refusal for every member keeps `J` (−2.4e-5 against −1.7e-5) for 43% fewer
  member evaluations, and the cohort's refusal at every time is the cohort's
  before t = 25 (+3.2e-4 against +3.1e-4).
- *This ran under plant's default absolute tolerance,* whose near-empty pools
  the tied tolerance fixes, so the later members' part may be their pools'.
  Under the tied tolerance `J` already follows the tolerance, and what the
  crossings still break is the gradients' continuity in θ, not measured here.

## 10. What sets the soil's steps

**Reproduced** (`soil_steps.R` on the tied baseline at `3e-5`):
- *Three quarters of the steps start within a day of a rain change.* A rain
  interval takes 5.6 steps; a dry interval 6.4, 3.6 of them in its first day.
- *Every layer binds,* and members and storage bind 28% of the dry intervals'
  steps.
- *Inside an interval, a soil-bound step's error ratio has median 0.36 on rain
  intervals and 0.085 in dry ones,* and the next step grows ×1.0 and ×1.2. On
  rain intervals the soil is at its accuracy; in dry ones the controller is
  still growing the step.

**Hypothesis 1: the soil's steps are its own answer to the forcing, not the
plants'.**
- *Test:* the chain alone, with no uptake (`soil_chain.R`): 16 447 accepted
  steps against 17 684 coupled.
- *Confirmed.* The plants add 7%.

**Hypothesis 2: the cost is drainage's power-law tail.** After rain a layer
drains as `θ ∝ t^{−1/(q−1)}`, and its rate falls as one over the time since the
rain.
- *Test:* the chain in `u = θ^{1−q}`, in which a layer draining with nothing
  above it moves linearly in time: 20 275 steps. Dry intervals take 7% fewer,
  rain intervals 38% more.
- *Refuted.* The cost is the answer on rain intervals, whose wetting fronts `u`
  sharpens.

**Stiffness and instability.**
- *On the pulsed records the soil relaxes about as fast as the forcing moves
  it:* `h|λ|/β` has median 0.27–0.45 on soil-bound rain steps and 0.07–0.56 on
  dry ones. With no scale to separate, an implicit soil buys no longer steps,
  which is why ARK did not pay on long drought (step 4).
- *Under constant rain the drainage is steady and stiff, and nothing moves:*
  stability binds, and ARK pays (§7).
- *Stepped at the members' pace, the explicit soil is unstable.* With the soil
  and the flux accumulators out of the error norm (`TOL_SOIL=1e6 TOL_ACC=1e6`),
  21% of steps start beyond its stability limit and `J` falls 10.7%.

**What the members need on their own.** In that run the members bind 95% of
9176 steps: 2.5 per rain interval and 3.7 per dry one, in 4.14e6 member
evaluations against 7.06e6. That bounds their demand from above, since the
unstable soil disturbs them.

**Root cause.** Five scalar equations, the soil chain answering each rain
change, set 93% of the steps. A monolithic step pays the members' leaf solves
at each of them, and the chain cannot step at the members' pace, where it is
unstable.

## 11. The crossings' cure, priced

- *The mechanism is the grid reply's* (`docs/oracle-response-grid-controller.md`).
  A node's crossing of zero net production is a kink at any step size. On one
  grid the gradient's error is first order in the crossing step's length, and
  the second derivative between the gradient's jumps is off at zeroth order.
- *Its cure was set aside at four times a plain replay:* split each crossing
  member's update at its crossing, and differentiate the crossing's time.
- *That cost is the driver's.* Each of the split's member evaluations calls
  `patch$derivs`, which evaluates every member. On the per-pool scale's grid at
  `1e-4` the split re-integrated 9229 members in 167 256 full evaluations, 18
  each with the crossing found to `|P| < 5e-11`. The replay's own 80 232
  evaluations held 4.38e6 member evaluations (`split_u108_1e-4_lma_±1e-4.log`).
- *Counted per member, the split adds 3.8%,* the reply's estimate of 4%. It
  needs plant to evaluate one member in a step's interpolated field, which it
  cannot do today.

## 12. What the chain alone tells the schedule

The chain alone costs 2.4e-4 of a forward: 19 372 attempts at 1.4 µs each in
C++, 27 ms against plant's 114.8 s (§3), on a loaded machine. In R it takes 6 s.
What it can set before the run (`warm_start.R` against the tied baseline at
`3e-5`, `chain_creation.R`):
- *The step program: yes.* A record's intervals take 5.61 steps each alone and
  6.03 coupled, correlation 0.76, and 89% of intervals differ by at most one
  step. The first accepted step after each knot, coupled over chain alone, has
  median 1.00 (10–90%: 0.87–1.3).
- *Each knot's first attempt: likely.* Taken as the coupled run's first attempt,
  the chain's first step would pass the error test at 96% of knots, by the
  local error's fifth order. Where it passes it is a median 0.69 of the longest
  step that would; the coupled run's own first accepted step, after its
  rejections, is 0.73. §2's seed from the last knot of the same kind was too
  short. The driver's test is open.
- *Which bound holds on the soil: yes.* The chain alone starts 4.9% of its steps
  at `h|λ|/β ≥ 0.8` on long drought and 99.4% under constant rain, against the
  coupled Cash–Karp runs' 1.5% and 83% (§7).
- *Where creation shuts: no.* A newborn in full light establishes with
  probability 0.99 when its top layer is at `θ ≥ 0.15`, and 0 at 0.1; its
  roots read that layer alone. Without uptake, long drought's top layer never
  dries that far, so the chain alone shuts creation nowhere.

**Where creation shuts.** The 429-node run has 78 gaps in creation, 6.96 of 40
years. A newborn in full light on the 108-node run's soil finds 71 of them and
91% of their time. The members' uptake makes the gaps, and their shade adds the
rest.

**What finds the gaps:** coarser runs' own creation records, against the
429-node run's. Cost is member-steps over the 108-node run's 1.18e6.

| run | cost | gaps | the gap time found | openings within a day |
|---|---|---|---|---|
| chain alone, newborn in full light | 2e-4 | 0 | 0 | none |
| 27 nodes at `1e-3` | 0.15 | 68 | 91% | 85% |
| 27 nodes at `3e-5` | 0.24 | 74 | 97% | 94% |
| 54 nodes at `1e-3` | 0.30 | 67 | 92% | 86% |
| 54 nodes at `3e-5` | 0.49 | 76 | 99% | 97% |
| 108 nodes at `3e-5` | 1 | 78 | 99% | 100% |

- *Tolerance matters more than nodes.* At `1e-3` the runs miss gaps of 3–6 days
  before t = 10 and put those openings 26–65 days out. At the run's tolerance,
  27 nodes place 94% of openings within a day.
- *Every coarse run misses one gap,* a quarter of a day at t = 6.08.

**Root cause.** Creation shuts where the newborn's top layer is dry or shaded.
The dryness is the members' uptake, and the chain alone sees the rain, not the
stand. A schedule probe for the creation grid must carry the members, and at
the run's tolerance a quarter of the forward's members places the windows.

## What the record supports, and what it does not

- *Supported: the record predicts the cost.* Steps per rain day follow its depth,
  dry intervals their length, and nodes and tolerance move it little.
- *Supported: the forcing sets which bound holds on the soil.* Pulsed rain keeps
  it accuracy-bound; constant rain makes it stability-bound, where the implicit
  soil pays (§7). A run reads which from `h|λ_soil|/β` at its steps' starts.
- *Not supported: a cheap accuracy lever in the forcing.* The soil's accuracy
  reaches `J` in proportion, and a naive seed from the record costs more than
  the controller's own probing.
- *Supported: one window of the goal, on every record, read by a pilot.* On
  long drought the steps and nodes after it can be coarsened at no measurable
  cost (§8), and the crossings after it carry none of `J`'s time error (§9).
- *Supported: the error's sources are the members' and the stand's, located by
  a run.* They are the sign changes, the near-empty pools, the layer's top and
  the fronts. The field adjoint map reports the node error's field part by
  source panel, time and channel for +12% of a sweep.
- *Not supported: the cohort that earns `J` as the only one whose crossings
  matter.* Later cohorts carry 40% of `J`'s time error at `1e-4` under plant's
  default tolerance (§9).
- *Supported: the soil chain sets the steps on its own* (§10). The members
  need about half of them.
- *Not supported: drainage's tail as the soil's cost.* Integrated where that
  tail is linear, the chain takes more steps.
- *Supported: per-member events are cheap,* 3.8% counted per member (§11).
- *Supported: the chain alone sets the step program, the knot seeds and the
  soil's bound before the run,* at 2.4e-4 of a forward (§12).
- *Not supported: the chain alone as a probe for the creation grid.* The members
  make the gaps; a pilot at the run's tolerance with a quarter of its nodes
  finds 97% of their time (§12).
- *One runtime defect is plain:* the invader's first replay repeats the
  resident's forward.

## Next probes, each one variable

- a partitioned step: the soil chain sub-stepped on its own, each member's
  per-layer uptake re-derived from its collar suction held over the members'
  step (phylloptim's `uptake_at`, about a thousandth of a leaf solve), and the
  members on their own steps. Does `J` hold at the members' 9176 steps?
- per-member events in plant, with one member evaluated in the step's
  interpolated field, on the gradients' spread under tolerance nudges;
- each knot's first attempt seeded from the chain alone's first accepted step
  there (§12), against §2's seed from the last knot of the same kind, which was
  too short;
- the tolerance scaled by 1/R(t) from a pilot, in place of §8's step at
  t = 25, on a second pulsed record;
- the invaders' windows at ×0.5 and ×2 of the resident, which bound a shared
  grid's;
- §9's window-limited refusal under the tied tolerance, on the gradients'
  continuity in θ;
- the gradients under the looser soil weight, by the driver's frozen-grid
  differences (`PROGRAM` with `THETA`), since §1's test is `J` only;
- the introductions moved by a quarter spacing, R2's other knob, on uniform 108
  and graded G1.
