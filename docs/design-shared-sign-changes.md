# Where a System's rates are not smooth: step ends at shared sign changes

The design for aornugent/plant#112, worked under the system-design skill. It decides
how odelia handles a point inside a step where a System's rates are not smooth,
how that relates to the existing splits and rain knots, and to plant's `Events`
(node introductions, harvest, resource pulses, climate extremes).

Sources:
- `docs/measurements/kinks/inventory.md`: the 26 points in TF24, with their kind,
  reach and counts.
- `docs/measurements/schedule-search/round4/JT/notes.md`: parts 2–4, which measure the
  stop and the splits and model which sign changes matter.
- `docs/design-sign-changes.md`: §8 has the split's vocabulary and who owns what.
- odelia `ODELIA-55` (`cb4d262`): `SolverInternal::step`, `SplitsSignChanges`,
  `HasSubsystem`, `instruction`.
- plant `PLANT-110`: `leaf_solved_point`, `leaf_solved_points`, `TF24_Strategy::solve_leaf`.

Revised after a review against the principles and the record of what evaluations
solve for; the changes are listed under § Review.

## Status: on hold

`docs/measurements/deep-search-nonsmooth/first-principles.md` weighs what the switch
actually costs against the objectives' bars.
- It is sub-ε everywhere. Its only material cost is that the schedule's pair estimate
  must run at 1e-4 rather than 3e-4 (about +14% rows).
- So no odelia representation is built for it now.
- The census of rate jumps on accepted stages comes first.

## Status: superseded in part by a deep search

A deep search followed: four independent proposers and a judge. It is recorded in
`docs/measurements/deep-search-nonsmooth/` (`ledger.md`, `P1.md`–`P4.md`, `judge.md`).

**The judge's verdict.**
- On the brief as written, the floor wins: end the step at each cluster's first and last
  zero, and hold the ends in every later pass. This document's relocation is killed. A
  row end cannot follow its zero past its held neighbours, and τ = dt*/d ln θ was measured
  at 25–29 d.
- This document's `sign_readings {blocks, shared}` is kept as the declaration.

**The representation the search found:**

> A point located from the state is a time that moves with θ, where a rate read by some
> blocks changes form. It divides the integration of every block that reads that rate
> within the step, and every pass that integrates those blocks finds it again at its own
> θ. Rows end only where the controller chose or a schedule fixed.

- **Data structure.** It widens `split_block` from one node to the blocks that read the
  value. TF24's shared value divides the whole state at a cluster's first and last zero,
  which are the two real edges of the soil's sensitivity ramp.
- **What it removes:**
  - the retake;
  - the flags;
  - relocation;
  - the soil split as a separate case.

  What is left is two kinds of division: held (chosen or scheduled) and located (moved).
- **Estimated price:** rows +0; gradient run about +11–13.5%, against the floor's
  +15.5%; about 150 lines more than the floor.
- **When it replaces the floor.** It loses only because the brief's R2 asks for
  continuity rather than resolution at θ′. It replaces the floor if:
  - the user reads R2 as resolution at θ′;
  - the held-end measurement (`judge.md` §5) exceeds 0.006 at θ × 1.01;
  - jumps (J kinds) appear on accepted steps; or
  - cost is read as time.

**The measurement** (`docs/measurements/deep-search-nonsmooth/held-ends/`): **0.0247 rms
(max 0.078, `TF24_cost_scale`), 4× over 0.006.** The trigger is met: held ends do not
serve a 1% chord.
- The ends moved a median 0.12 d, with 90% under 0.48 d.
- Placing them at θ₀'s own roots adds only 0.0015 of noise.
- About 26 ends in the large clusters carry over half of it. The other ~430 alone still
  give 0.011.
- So the located division that moves with θ is the representation to build.

**The targeted rule** (`docs/measurements/deep-search-nonsmooth/lean/results.md`): divide
only rows that hold a shared zero, are longer than 0.25 d and start before b = 25.
- Measured on the stop build at θ₀: nudge 0.0027 at +3.6% rows, against 0.0020 at
  +12.8% for every cluster.
- On the division it is estimated at about +4% of a gradient run, with no extra rows and
  no retakes.
- The rule reads only a row's length and start time, so every pass divides the same rows.
- The division itself is not built or measured.

## Triage: 3

odelia's System concepts are the interface every plant model is written against. The
sweep's exactness depends on what a step end means.

## Requirements ledger

**R1. The tolerance is predictable for gradients.**
- *Quantity:* a ±5% nudge of the tolerance moves the elasticities by at most a third
  of the tolerance's own move from 1e-4 to 3e-4. On dry that move is 0.018 rms, so the
  nudge must be ≤ 0.006 rms, and ≤ ε/10 per trait at most.
- *Today, on dry under the sharp gate:* 0.048 rms (max 0.176) at 3e-4, and 0.02–0.03 at
  1e-4. Both exceed the move itself, so a looser companion run reads the jitter.
- *Challenged upward:* a third makes the pair's error estimate good to about ±⅓. The JT
  runs used bars of 0.03 and 0.01. Is a third the bar you want?

**R2. It costs no more than the tolerance it frees.**
- *Quantity:* rows ≤ +14% over the run without it at the same tolerance. At that limit,
  3e-4 costs no more than 1e-4, since 3e-4 runs 0.875 of 1e-4's rows.
- Rows are the cost: the sweep pays 3.56e-4 s per row and is about three quarters of a
  gradient run.

**R3. A model declares a point; it does not handle it.**
- *Quantity:* one member per kind of point, returning a value whose sign changes there.
- Detecting the point, locating it, recording it, replaying it and the sweep need no
  model code.

**R4. plant's `Events` keep their R interface and behaviour.**
- *Quantity:* 0 changes.

**R5. The sweep differentiates the run's own map.**
- *Quantity:* central differences of `ln J` on the run's pinned steps agree with the
  reverse-mode elasticity to within 0.01ε. The soil split's check gave 0.0027ε.

**R6. Walks follow the resident.**
- *Quantity:* 0 step ends that a walk locates for itself.
- An invader at zero density does not feed back on the soil, and its net production is
  C1 through its own leaf switch.

**R7. Jumps in the rates (inventory #13, #14, #19).**
- *Quantity:* unknown. Dry has 0. Long drought's counts (9138–18 715 Determined solves)
  predate phylloptim 0.9.3, which differentiates a Determined collar.
- *What hangs on it:* whether the sweep needs a term through the time of a step end.

**R8. The averaged gate's change of slope (inventory #9).**
- *Quantity:* out of scope. The averaged gate will not land.
- Nothing changes sign at this point. Under that gate, tolerance factors near the
  closing edges cleared it: 0.110 → 0.009 at +11.5% rows.

**Scarce resource:** step ends in the drying windows.
- On dry, the derivative error enters at 14 728 sign changes. They fall in only 234 of
  4786 steps, with a median of 51 per step: the soil drives the leaf's switch, so the
  stand switches together.
- Each step end costs a retake (about 12 evaluations) and adds rows to the sweep.
- So resolving a cluster must cost a fixed number of step ends, not one per sign change.

## The floor

**The floor:** tolerance factors ×0.1 within 15 d of each closing edge, using the
existing `state_tolerance_factors`, with plant setting the windows. It **fails R1**:
0.025 rms (max 0.11) against ≤ 0.006, at +8.6% rows. It also fails R3, because the
windows are plant code that reads the schedule, not the point.

**No tolerance meets R1 at a price R2 allows.** At 1e-4 the jitter is still 0.02–0.03.
That is larger than the whole move from 1e-4 to 3e-4.

## Candidates

**A [first thought]: modes held across a step.** Move 6 (one mechanism for N cases).
- *Mechanism:*
  - The System's rates carry a mode that holds across a step.
  - Guards (sign values) are located on the dense output.
  - Each guard carries an action: none, change mode, reset the state, or change its
    width.
  - odelia resolves each one by a split or a step end.
  - plant's `Events` become actions at guards of the form t − t_e.
- *Commitment:* every stage of a step evaluates one mode.
- *Pays for:*
  - R1, by step ends;
  - R4, by taking `Events` into one type;
  - it also makes a guard's location enter only at the method's order. That is the
    events reply's "branch-selected sub-steps".
- *Costs:*
  - four new names: mode, guard, action, reset;
  - every mode needs rates past its guard. That means phylloptim's interior optimum
    evaluated with the stem below psi_crit, which no current code defines;
  - `Events` move from plant's schedule into odelia, against R4;
  - no action triggered by the state exists. odelia's `instruction` comment already
    asserts that insertions are scheduled, not triggered.
- *Wins when:*
  - jumps dominate, and must be located only to the method's order; or
  - an action triggered by the state arrives, such as thinning when basal area crosses
    a bound.

**B: step ends at shared sign changes.** Move 3 (move the boundary): the solver resolves
what no block owns.
- *Mechanism:*
  - A System reports, beside its blocks' sign values, the sign values of rates that no
    block owns. For TF24 these are each node's leaf margin at the dry end (f_hi), and at
    the wet end (f_lo) once a record reaches it.
  - After a step is accepted, odelia finds their sign changes on the step just taken.
  - It ends the step just past the first sign change, and the next step just past the
    last.
  - A block's own sign changes stay with the split.
- *Commitment:* the solver, not the model, resolves a sign change in rates that no block
  owns, by where it ends steps.
- *Pays for (measured as JT's stop, part 2):*
  - R1: 0.0020 rms (max 0.007), at +12.8% rows and +11.5% steps;
  - R3: one member;
  - R4: `Events` are already step ends;
  - R6: walks take rows.
- *Costs:*
  - a second part to the sign readings, and one field on `instruction` (§ Review);
  - a retake per cut;
  - cuts that buy nothing: 243 of 530 fall in steps under 0.25 d, and 148 after b = 25,
    where nothing jitters.
- *Wins when:* shared sign changes cluster in time, one stand-wide cluster per drydown,
  so two step ends resolve a cluster.

**C: adjoint-selected step ends.** Move 2 (move the decision offline).
- *Mechanism:* as B, but a step ends only where the bound
  (θ/J/ε)·|λ_soil|·h·|ΔG|·0.2 exceeds ε/50. λ_soil comes from the pilot's sweep.
- *Commitment:* a step end is paid for only where the pilot's adjoint says the
  derivative error matters.
- *Pays for:*
  - R1, extrapolated: the top 30 of 221 switch steps hold 90% of the error;
  - R2, best of the three: about 30 cuts against 530.
- *Costs:*
  - odelia's step reads a pilot's adjoint, an input threaded from R that carries a
    model quantity (the soil's adjoint) into the solver;
  - ΔG needs the rates' θ-sensitivity, which the forward does not compute (JT took it
    by central differences);
  - the ranking was tested on one trait, and nothing is measured.
- *Wins when:* cuts dominate the cost, as on records with many more drydowns than dry,
  or at looser tolerances.

**Measured variants of B:**

| Variant | Nudge rms | Cost |
|---|---|---|
| Split the soil at the first and last shared sign change, instead of ending the step | 0.010 | +8.5% evaluations, rows unchanged |
| End the step only where it is longer than 0.5 d | 0.0081 | +7.1% rows |

**Winner: B.** The eliminations:
- *The floor* fails R1: 0.025 against 0.006.
- *A* fails R4, since it moves `Events` into odelia, and R3, since every mode needs rates
  past its guard. Its gain, locating a guard only to the method's order, is not needed
  at a point where the rate is continuous and only its derivative jumps (§ The design,
  step 3).
- *C* is unmeasured on R1, and its inputs (the soil's adjoint, ΔG) break R3. It is B's
  retrofit if B fails R2 on the bank.
- *The soil split* fails R1 (0.010), and so does *the 0.5-d threshold* (0.0081).

## The commitment

Every declared point where the rates are not smooth ends a step for everything that
reads those rates within the step. An end located at a zero follows the zero in every
pass that has it; an end the controller chose is held. The model only reports a value
whose sign changes there.

**Kept true by:**
- The System's side is a value, the `shared` part of its sign readings. There is no hook
  that sees the step, so a model cannot resolve a point itself.
- `SolverInternal::step` is the one place that ends steps: at the program's targets, at
  the subsystem's knots, and at shared sign changes.
- A row records that its end was located (`instruction::ends_at_sign_change`). A pinned
  replay locates that end again at its own θ; an invader's walk takes the recorded time;
  the sweep holds the end of the pass it differentiates, which that pass located.

**One semantics for every step end.** It replaces "event" for anything but plant's
actions:

| Point | Known before the run | What happens there | Ends a step for | Today |
|---|---|---|---|---|
| A scheduled time: node introduction, or plant's `Events` | yes | the System's map of the state | the whole state, as the program's target | `advance_adaptive` to each time |
| A knot of the subsystem's forcing (rain) | yes | its rates change form | the subsystem, whose substeps land on it | `subsystem_knots` |
| A sign change of a block's own rates (net production) | no | that block's rates change form | the block | the split |
| A sign change of shared rates (the leaf's switch) | no | every block's input changes form | the whole state | **this design** |

## Kill question

*Assumption whose falsity makes this unnecessary:* the derivative error enters where
shared rates change form inside a step.

**Verdict: survives.** On dry under the sharp gate, ending steps there takes the nudge
from 0.048 to 0.0020. Nothing else measured gets below 0.008: the soil split, the 0.5-d
threshold, the tolerance factors, or a tighter tolerance.

**Second assumption:** a cluster is resolved by its first and last sign change.
- It also survives, on the record measured. One step bracketing the cluster gave 0.0020.
- A piece per sign change, in the soil split, gave 0.018, no better than its bracket's
  0.010.
- See *What this makes hard* for wide clusters.

**Consistency check.** R2 allows +14%, and B costs +12.8%. The margin is 1.2 points on
the one record measured, so G4 below must measure it on the bank.

## What survives deletion

- `sign_readings {blocks, shared}`, the one reading per evaluation, replacing the bare
  vector `sign_values` fills today. Held by R3; it also replaces a second, parallel
  reading array.
- The located step end in `step()`. It adds no name: it is the step's target, landed on
  by the path that already lands on `time_max`. Held by R1.
- The attempt's last root, kept as the next step's target until reached. Held by R2,
  since a cut at every sign change costs about 51 per cluster.
- `instruction::ends_at_sign_change`. Held by R5 and *Continuous in the traits*: without
  it a pinned replay holds a located end as a chosen one (§ Review).
- `outcomes_.ended_at_sign_change`, a count per run. Held by the objectives' *Diagnosed*.

**Deleted:**
- modes, guards, actions and resets (A);
- the pilot's weight (C);
- the soil split, and the whole-state split (§ Review);
- f_lo, which changes sign on no record measured;
- the flag that remembered the previous step ended at a first sign change;
- a sweep term through the time of a step end, until R7 has a witness.

## What this settles

- No model code locates, records, replays or differentiates a sign change it reports as
  shared.
- `Events` stay plant's: a scheduled time with a map of the state. "Event" stays their
  word, and a sign change is never called one.
- An invader's walk never ends a step of its own. A pinned replay of the resident
  locates again only the ends the run located.
- The split stays the one resolution plant owns, for sign values of a block's own rates.
- Rain knots belong to `subsystem_knots`. The harness's zero-depth pulses at the knots
  have no role left (#274).
- The averaged gate's change of slope is not a sign change. If that gate lands, the tool
  is tolerance factors.

## What this makes hard

**Points not declared still carry jitter.** Without tangents there is no safety net.
- A declared value costs cuts in proportion to how often it changes sign. Declaring the
  root curve's dry end (#16: 17 937 capped reads on dry) would cost far more than the
  leaf's switch.
- *Cope:* declare a point when it is measured to move gradients. The inventory lists
  the candidates.

**Jumps.** The sweep holds a step end's time fixed.
- Where the rate is continuous, this is exact: the two steps' terms through the end
  time, f⁻ and −f⁺, cancel.
- At a jump it is off by Δf·dt_c/dθ.
- *Cope:* when a jump is declared, make the end time active in the sweep with odelia's
  `implicit_value`. It costs one residual per cut.

**Wide clusters.** The step between a cluster's first and last sign change spans the
cluster.
- On dry the cluster spans 0.44 d.
- A slow drydown leaves an error proportional to its span.
- *Cope:* end steps at every k-th sign change too, or take C's weight.

**The cost was measured on libD, which ends a step at every rain knot.**
- On libS steps are longer, so a cut buys more and the retake costs more.
- Unmeasured; G4 measures it.

**Rosenbrock has no dense output,** so it takes no stops, as it takes no splits.

**A pinned replay pays to locate again** every end the run located: cheap if G0's
readings suffice, a few evaluations per end if not.

## Kill condition

- An action triggered by the state, or jumps that dominate the gradients' error, hand
  off to A.
- The bank's rows exceeding R2 hands off to C.

## The design

**1. The reading** (`ode_interface.hpp`; `sign_values` changes its argument, it does
not gain a sibling):

```cpp
// A System's sign values after one evaluation: one per block, where that block's own
// rates change form and the System splits it; then the shared ones, where rates every
// block reads change form and the step ends.
struct sign_readings {
  std::vector<double> blocks;
  std::vector<double> shared;
};
```

`SplitsSignChanges` asks for `sign_values(sign_readings&)`. A System with nothing to
split leaves `blocks` empty; one with nothing shared leaves `shared` empty.

**2. Readings.**
- Read after every evaluation of the step: the start, the five stages and the end, into
  the arrays `sign_values` fills today, now of `sign_readings`.
- At an active scalar the System reports none.

**3. Locating the sign change and ending the step there.** This happens in
`SolverInternal::step`, after the error test accepts and before the split.
- For each shared value, `taken_step::sign_changes` finds its roots in the step.
- The earliest root over all values sets the retaken step's size, h·u plus a margin. The
  latest root, plus the margin, becomes the next step's target, held beside `time_max`
  and cleared when reached. A cluster then costs two step ends and no state outlives it.
- The margin keeps the end just past the zero. Then the end evaluation, which is also the
  next step's first stage, reads the new side.
- This matters because RKCK's stage at c = 1 has weight 0. So a step ending just past the
  zero carries an error of only jump × margin. A next step whose first stage, of weight
  37/378, read the old side would carry 0.1·h·jump.
- The retake is the final-step path: the step lands on its target, and
  `step_size_last` is unchanged, exactly as a schedule time is landed on. There is one
  retake per step.
- *Locating a root, first choice:* on the polynomial through the step's seven readings,
  with no evaluations. G0 decides whether that is accurate enough.
- *Fallback, only if G0 fails:* read the value at the dense state y(u), about 4 full
  evaluations per root, roughly +6.5% of the forward's evaluations on dry. These
  evaluations call `derivs` without a solved-values scope, so they store nothing in the
  row (§ Review).

**4. Recording, replays and the sweep.**
- `instruction` gains `bool ends_at_sign_change = false`, set on a row whose end was
  located.
- *A pinned replay* steps such a row to the zero of a shared sign value nearest the
  recorded end, located on its own step, plus the margin. The next row steps to its
  recorded time.
- *An invader's walk* steps it to the recorded time. The invader's own leaf switch
  reaches no soil, and its net production is C1 through it.
- *The sweep* holds the end of the pass it differentiates. For a kink this is exact to
  ΔG × margin: the end stage has weight 0, and the first stage after it holds the new
  arm, recorded and loaded as such.

**5. plant.**
- TF24 reports each node's f_hi in `shared`, and net production in `blocks` as today.
  phylloptim keeps f_hi per solve; it computes it on every solve today and discards it.
- NaN, where no collar solve ran, never counts as a sign change.

**6. Gates, registered before the build.**

Sequence: #274 first, so every gate runs on libS, and the unstopped nudge on libS is
measured before the build.

| # | What | Bar |
|---|---|---|
| G0 | Spike on JT's saved S1 data: roots of the polynomial through each step's seven readings, against the 400-point scan of the dense output | within 1e-3 of the step; if not, the fallback |
| G1 | Dry, sharp gate, 3e-4 against 2.85e-4, location as G0 chose | nudge rms ≤ 0.006; expected ≈ 0.002 |
| G2 | The cost | rows ≤ +14%; forward evaluations reported |
| G3 | Central differences on the stopped run's pinned steps | within 0.01ε |
| G4 | The ten-case bank on libS | no failures; cuts per record; the nudge on long drought and episodic; rows ≤ +14% |
| G5 | A System without the concept (FF16) | the same steps, bit for bit |
| G6 | Walks: the invader's nudge on dry | no worse than without stops |
| G7 | Pinned replays of the stopped run at θ(1 ± u), u = 1e-3, 1e-2, 1e-1, along `TF24_cost_scale` and `root_P50`, with relocation on and off; dt_c/dθ read off the relocated ends | relocation on: the gradient continuous in u, no jumps above 0.01ε; off: records how far the protection reaches |

## Review: the record, and the principles

A second pass, after the user asked whether storing and loading what evaluations solved
for interacts with the design, and for a critical review against the principles. The
draft had asserted "a stopped step is a row, nothing new" without reading the record.

**The record of what each evaluation solved for.** Read on ODELIA-55 and PLANT-110.
- Every evaluation stores each leaf's collar and the arm it was placed on
  (`leaf_solved_point {collar, kind}`). A forward pass stores; only the sweep loads; a
  walk searches again.
- A retaken step writes the same scratch row a rejected attempt does, so nothing from the
  first attempt reaches the row.
- Location evaluations at dense states must store nothing. Without a solved-values
  scope `leaf_solved_points` stores and loads nothing. With a row's slot they would append
  points past what the stages made, and the sweep's `load()` would refuse. They do add to
  `operating_point_counts`.
- A stopped step's end evaluation is the next step's first stage, and the sweep loads its
  arm. The margin puts it on the new arm. Without the margin the arm at the zero is
  whatever the leaf's search returned, and the sweep would load that.
- So at the run's own θ the record needs nothing new. The arm that candidate A wanted held
  across a step is already recorded per evaluation, and the sweep replays it.

**Found by that check: a located end held as a chosen one** (*Model the Domain*,
*Foundational Thinking*).
- The record already knows two kinds of boundary.
  - A row end is chosen by the controller or the grid. Replays and the sweep hold it,
    since moving it changes `J` only at the method's order.
  - A cut is located at a zero. Replays locate it again and the sweep moves it, since a
    held cut reads the zero off-centre with a stage's weight (`design-grid-controller.md`,
    "Why the cuts move and the steps do not").
- The draft made a located point into a row end, then held it as a chosen one.
  - At the run's θ that is right to ΔG × margin.
  - In a pinned replay at θ′ the zero moves by dt_c/dθ·Δθ while the end stays. Past the
    margin, which is minutes, the next step's first stage (weight 37/378) reads the old
    arm, and the error is 0.1·h·ΔG again.
  - That is the jitter this design removes, back on every analysis that replays the
    resident's grid away from θ₀: chords of gradients at u = 1e-2, regnans's convergence
    Jacobian at 1e-3, the resident within ±10%. The gradient on that grid also jumps
    wherever a zero crosses a stage, against *Continuous in the traits*.
  - dt_c/dθ is unmeasured; G7 measures it.
- *Revision:* a row records that its end was located, and each pass that has the zero
  locates it again (§ The design, 4). Each pass is then exact for its own program, as the
  split's passes are.
- *Not taken:* the whole-state split, which integrates every block in pieces inside the
  row, cut at the zeros. It keeps every row end a chosen one and needs no new field. But
  it needs pieces of the whole state in the sweep and in every invader's walk: more code
  for the same forward.

***Subtract Before You Add* and the *Laziness Protocol*.**
- *Sequence.* #274 comes first: drop the knot pulses and move the baseline to libS.
  - Every number in this design is from libD, where about half the steps end at a knot.
  - On libS steps are longer, so both the jitter and what the stop buys are larger.
  - R2's margin of 1.2 points may not hold there. The unstopped nudge on libS is the first
    measurement.
- *f_lo.* It changes sign 0 times on dry and on long drought. Declaring it is a
  speculative edge case, so it is dropped.
- *Location by evaluations.* It is a new evaluation path in `step()`, with the store hazard
  above. G0 can show the seven readings suffice, deleting the path before it is written.
- *The flag for the bracket.* It was state held across steps that a reader must keep in
  sync with what the previous step did. Replaced by the attempt's last root kept as a
  target, the same kind of thing as `time_max`.

***Minimize Reader Load* and *Foundational Thinking*.**
- *Two parallel reading arrays.* A second sign-value list would have duplicated
  `sign_values_in`, the per-stage `std::array<std::vector<double>, 6>` and
  `read_end_sign_values`, beside a second concept.
  - Instead there is one reading per evaluation, with two named parts.
  - Plant's split reads `blocks`; odelia's step reads `shared`.
  - There is no index convention between them, which JT's build had (f_hi at blocks
    n..2n−1).
- *"Reach".* The draft said a point ends a step for the part of the state its rates reach.
  - The leaf's switch changes only the soil's rates, yet the step ends for every node,
    because every node reads the soil's potential within the step.
  - What decides it is everything that reads the changed rates within a step. The soil
    split measured this: 0.010, because the nodes' own integration read the main step's
    soil.
  - The commitment is reworded.

**What the review leaves as it was:**
- the winner: steps end at shared sign changes, and odelia owns it;
- one value per point from the model;
- `Events` unchanged;
- the split for a block's own sign changes;
- ends held in the sweep, which is exact for kinks.
