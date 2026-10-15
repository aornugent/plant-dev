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
    block owns. For TF24 these are each node's leaf margin at the dry end (f_hi) and at
    the wet end (f_lo).
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
  - one concept and one member;
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

Every declared point where the rates are not smooth ends a step for the part of the
state its rates reach. The model only reports a value whose sign changes there.

**Kept true by:**
- The System's side is a value, `shared_sign_values(out)`. There is no hook that sees
  the step, so a model cannot resolve a point itself.
- `SolverInternal::step` is the one place that ends steps: at the program's targets, at
  the subsystem's knots, and at shared sign changes.
- Walks and the sweep take rows and never locate a step end.

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

- `EndsStepsAtSignChanges`, the concept, with its one member `shared_sign_values(out)`.
  Held by R3.
- The located step end in `step()`. It adds no name: it is the step's target, landed on
  by the path that already lands on `time_max`. Held by R1.
- Ending the next step at the cluster's last sign change: one flag. Held by R2, since a
  cut at every sign change costs about 51 per cluster.
- `outcomes_.ended_at_sign_change`, a count per run. Held by the objectives' *Diagnosed*.

**Deleted:**
- modes, guards, actions and resets (A);
- the pilot's weight (C);
- the soil split;
- a sweep term through the time of a step end, until R7 has a witness;
- any change to the recording, since a row is a row.

## What this settles

- No model code locates, records, replays or differentiates a sign change it reports as
  shared.
- `Events` stay plant's: a scheduled time with a map of the state. "Event" stays their
  word, and a sign change is never called one.
- A walk never ends a step of its own.
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

## Kill condition

- An action triggered by the state, or jumps that dominate the gradients' error, hand
  off to A.
- The bank's rows exceeding R2 hands off to C.

## The design

**1. The concept** (`ode_step.hpp`, beside `SplitsSignChanges`):

```cpp
// A System whose shared rates, which no block owns, change form where a value
// changes sign. odelia ends a step there.
template <typename System>
concept EndsStepsAtSignChanges =
  std::same_as<typename System::value_type, double> &&
  requires(const System& s, std::vector<double>& out) {
  { s.shared_sign_values(out) } -> std::same_as<void>;
};
```

**2. Readings.**
- The values are read after every evaluation of the step: the start, the five stages and
  the end, as `sign_values` are today.
- At an active scalar the System reports none.

**3. Locating the sign change and ending the step there.** This happens in
`SolverInternal::step`, after the error test accepts and before the split.
- For each value, `taken_step::sign_changes` reads the System's value at the dense state
  y(u).
- The earliest root over all values sets the retaken step's size, h·u plus a margin. If
  the step before it ended at a first sign change, the latest root sets it instead.
- The margin keeps the end just past the zero. Then the end evaluation, which is also the
  next step's first stage, reads the new side.
- This matters because RKCK's stage at c = 1 has weight 0. So a step ending just past the
  zero carries an error of only jump × margin. A next step whose first stage, of weight
  37/378, read the old side would carry 0.1·h·jump.
- The retake is the final-step path: the step lands on its target, and
  `step_size_last` is unchanged, exactly as a schedule time is landed on. There is one
  retake per step.
- *Estimated cost:* about 4 full evaluations per root, 530 roots on dry, about 2100
  evaluations, or +6.5% of the forward's evaluations. The forward is about a quarter of a
  gradient run.
- *An option if that shows:* locate on the polynomial through the step's seven readings,
  with no evaluations.

**4. Recording, replays and the sweep.**
- Nothing new: a stopped step is a row.
- The sweep holds its end time fixed, which is exact where the rate is continuous (see
  *What this makes hard*).

**5. plant.**
- TF24 reports each node's f_hi and f_lo. phylloptim keeps them per solve; it computes
  them on every solve today and discards them.
- NaN, where no collar solve ran, never counts as a sign change.

**6. Gates, registered before the build.**

| # | What | Bar |
|---|---|---|
| G1 | Dry, sharp gate, 3e-4 against 2.85e-4. Location is odelia's own, with full evaluations at dense states, not JT's per-node evaluation in the field | nudge rms ≤ 0.006; expected ≈ 0.002 |
| G2 | The cost | rows ≤ +14%; forward evaluations reported |
| G3 | Central differences on the stopped run's pinned steps | within 0.01ε |
| G4 | The ten-case bank on libS | no failures; cuts per record; the nudge on long drought and episodic; rows ≤ +14% |
| G5 | A System without the concept (FF16) | the same steps, bit for bit |
| G6 | Walks: the invader's nudge on dry | no worse than without stops |
