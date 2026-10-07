# Design: the soil stepped on its own where the plants draw little

This maps item 5 of the spec's phase 3 (`design-grid-controller.md`) from the
driver into odelia and plant, under the system-design skill. On the driver it
is phase 1e (`grid-dynamics.md` §15):
- where the uptake at a step's start is under 10% of the soil's water budget,
  the soil is integrated on its own under an uptake extrapolated from the last
  step;
- a corrector integrates it again under the uptake the step found;
- the coupling's error enters the norm at the members' weight.

It lands on the split (`design-sign-changes.md` §8–§9) and must serve every pass
the split serves: the forward, a program's replay, an invader's walk and the
sweep. Three spikes settled its shape first (`measurements/soil-alone/`).

**In short.**
- *One commitment:* a step that takes the soil alone is a function of its own
  row. Its instruction holds every choice the run made for it: that it took the
  soil alone, the slope its predictor extrapolated, and its inner steps. Every
  pass but the adaptive forward reads them. So the sweep's one-row map is the
  step the run took. A replay at another θ also takes the run's inner steps:
  re-choosing them moved `ln J` by 2.5e-7 (Q3), against the split build's
  8.5e-15.
- *odelia steps the block and the System names it,* in four hooks: where the
  block is, whether this step takes it alone, what the rest hands it, and its
  rates under given inputs.
- *An invader's walk is untouched.* Its evaluations load the run's field, the
  soil included (`run_mutant`), so it never reads its own soil.
- *The split reads the soil from the inner steps* through the step's dense
  output: the block's components come from the predictor's samples at the five
  fractions. Plant's `sample_field` does not change.
- *From the spikes:*
  - the slope stays (S1 fails);
  - the end's uptake comes from the stage at t + h, so an attempt costs six
    evaluations (S2 passes);
  - ARK retires (S3 passes): under constant rain the variant built takes 0.98 of
    arkc's member evaluations.
- *What it buys* against bounded Cash–Karp at `3e-5`:

  | | long drought | episodic | constant |
  |---|---|---|---|
  | rows | −41% | −45% | −64% |
  | member evaluations | −43% | −45% | −64% |

  `J` stays inside the bound throughout.
- *Open:* `J`'s error stops falling below `3e-5`, at about 0.001ε, with or
  without the slope. Q3 read the floor as the share threshold's, held fixed as
  the tolerance tightens; that reading is untested. The user placed the
  threshold's tuning with the scheduling heuristics.

## Triage: 2 — the seams are visible but migratable

The seams are odelia's step and solver, and plant's patch and program. The
program gains two fields that R code carries, so every pinned-replay caller
sees them. Nothing is persisted outside a session.

## Requirements ledger

- **R1, the saving** (OBJECTIVES, *Performant*). S2 against bounded Cash–Karp
  (bnd) at `3e-5`:

  | | long drought | episodic | constant |
  |---|---|---|---|
  | rows | 373 188 against 637 131 | 229 703 against 415 759 | 179 002 against 498 368 |
  | member evaluations | −43.1% | −45.3% | −64.0% |

  At bnd's error in `J`, 41% and 29% of rows on long drought and episodic (Q3).
  The build keeps the driver's steps.
- **R2, accurate** (*Accurate*).
  - `J` stays within max(2|bnd's|, 0.01ε) = 2.524e-4. S2 gives +2.50e-5,
    +7.43e-5 and +6.9e-8.
  - Every elasticity stays within ε/3 of the `1e-5` reference, and within bnd's
    own distance plus 0.1ε. Q3 put mrw's within 0.11ε of the reference.
- **R3, the sweep differentiates the step taken.** The stand's gradient
  against central differences of the replayed program, at r = `1e-3`, lies
  within 2e-3 in an elasticity, as item 3's S4.
- **R4, smooth on one grid** (*Stable* 2). A replay at θ ≠ θ₀ moves `ln J` with
  noise at the leaf solve's level: 8.5e-15 rms on the split's build, against
  2.5e-7 with the inner steps re-chosen (Q3).
- **R5, with the split.** A split step reads the soil from the inner steps
  (the spec's item 5), and `J′ = J` to the bit at θ′ = θ.
- **R6, never fails** (*Stable* 4). Nothing throws over the trait range, for
  either role, under the 15-day cap.
- **R7, one soil mechanism.** ARK retires if the soil alone takes at most 1.2×
  arkc's member evaluations under constant rain (S3, registered). Measured:
  1.15× for mrw, 0.98× for S2.
- **R8, off by default.** With the share at 0 every run is bit for bit, the
  FF16 guard included (AGENTS.md).
- **R9, diagnosed** (the spec's R8). Each run reports its steps taken alone and
  their inner steps.
- **R10, predictable** (*Stable* 3): each knob's error falls at its order. *Not
  met by this item:*
  - S12's `J` error is +2.15e-5, +1.6e-8 and +2.31e-5 at `1e-4`, `3e-5` and
    `1e-5`;
  - mrw's in Q3 was +2.6e-5 and +2.7e-5 at `3e-5` and `1e-5`;
  - that is about 0.001ε, and it does not fall.

  *Challenged upward:* "I believe you want the controller to refine to brute
  force. The share threshold is the knob Q3 named for this floor, though that
  is untested. You placed its tuning with the scheduling heuristics. The build carries the threshold as
  a Control value, so tuning changes a number or a rule, not the structure.
  Does the deferral stand now that the floor is measured at 0.001ε?"

**Scarce resource: full rate evaluations.** A member's rates solve its leaf,
91% of an evaluation, while the soil's rates read five layers. So the soil's
own inner steps are nearly free. Where bounded Cash–Karp's step is set by the
soil, every outer step saved is a full evaluation saved in the forward and a
taped one in the sweep:
- under constant rain the soil binds 91.6% of its steps;
- on the pulsed records 34–75% of rows sit on weakly coupled, soil-bound steps
  (Q3's first question).

## The floor

The floor is the driver's step ported as it stands. The flag is recorded with
the step's size, as its replays had it, and the slope and the inner steps are
chosen afresh on every pass. It fails two lines:
- **R4:** a replay at θ re-chooses the inner steps, and `ln J` carries 2.5e-7
  of noise (Q3), against 8.5e-15. That is 3e7 times the split build's.
- **R3:** the slope reads the previous row's uptake, which a one-row sweep
  cannot carry. The sweep would hold the slope while the replays move it, so it
  would differentiate a map no pass ran.

Doing less fails R1: bounded Cash–Karp on the pulsed records and ARK under
constant rain. On long drought and episodic its rows are 1.71 and 1.81 times
S2's. It fails R7 too, with two mechanisms. Every candidate pays for R3 and R4.

## Candidates

- **A [first thought]: record, then replay** (move 2).
  - *Commitment:* a step taken alone is a function of its own row.
  - *How:* odelia's step takes the block alone. The adaptive forward chooses
    the flag, the slope and the inner steps and records them on the row's
    instruction; every other pass reads them.
  - *Pays for* R3 and R4 by the record, and R5 because the step's dense output
    serves the block from its own samples.
  - *Costs:* a concept of four hooks, two instruction fields, two program
    fields in plant and a Control value.
  - *Wins when* the inner steps are few enough to record (about 37 a step taken
    alone on long drought, 12 under constant rain), and the block alone is
    model-free numerics.
- **B: plant steps its soil, as it owns the split** (move 3).
  - *Commitment:* odelia's step knows nothing of a block.
  - *How:* odelia hands the System each stage before evaluating it, and the
    end before the error. Plant integrates the soil alone, keeps its inner
    steps in its solved values and writes the coupling's error.
  - *Pays for* R3–R5 the same way as A.
  - *Costs:* a second Cash–Karp loop with its controller in plant, a parallel
    near-copy that AGENTS.md forbids. It also needs six hooks into odelia's
    step (each stage's state, the end, the error, the dense output, the forward
    and the sweep's recording) against A's four.
  - *Wins when* the block alone needs the model's own numerics, an exact or
    implicit flow of the drainage, which odelia cannot hold.
- **C: compute the inner steps, record a count** (move 4).
  - *Commitment:* an inner pass is a function of one integer on the row.
  - *How:* the inner steps are uniform, 40m to a step so that every stop falls
    on a boundary, and only m and the slope are recorded.
  - *Pays for* R4 with a smaller record.
  - *Costs:* an inner method no spike measured, uniform steps sized by the
    worst transient, and a doubling search in the forward. The count, not a
    tolerance, then holds the inner error.
  - *Wins when* a program must stay flat numeric vectors, as a persisted format
    would demand.

**Winner: A.** Eliminations:
- *B* costs a second Cash–Karp in plant and two more hooks than A, for no
  ledger line that A misses. Its wins-when, the model's own inner numerics, was
  measured in July and lost. The exact-drainage inner took 103 evaluations a
  macro step against the adaptive inner's 58 (`perf-rhs-profile.md` §3.2).
- *C* replaces the measured inner method, adaptive at `1e-9` as in Q3 and S2,
  with an unmeasured one. It saves about 37 doubles a step taken alone, near
  1.5 MB a run on long drought, which no ledger line asks for.

## The commitment

A step that takes the soil alone is a function of its own row: its start state,
its recorded evaluations, and its instruction, which holds every choice the run
made for it.

Kept true by:
- odelia's `Step` takes the slope and the inner steps from the instruction it
  is handed, and holds no other row;
- only `SolverInternal::step`, the adaptive forward, keeps the previous step's
  inputs, and it writes the slope into the instruction before the step runs;
- the forward, a replay and the sweep's recording run one step body at their
  own scalar (commit 1 below), so none can read a choice the others do not.

## Kill question

*Assumption whose falsity makes this unnecessary:* where the plants draw little,
bounded Cash–Karp's steps are set by the soil, not by the members. If the
members set them, taking the soil alone lengthens no step.

*Verdict: survives.* The soil binds 91.6% of bnd's steps under constant rain.
On the pulsed records 34–75% of rows sit on weakly coupled, soil-bound steps,
where the members alone could step 4.7–7.2 times longer (§15). The rows fall
41%, 45% and 64%.

*Checked against itself:*
- The inner steps' cost: about 37 a step, each six soil rate evaluations, so
  about 220 a step taken alone. Each is five layers of a power law, against six
  full evaluations, each solving 108 leaves. That is well under 1%, which G6
  measures.
- The sweep's row: six taped evaluations, as for an ordinary step, plus the
  inner steps on the tape.

## What survives deletion

- `StepsBlockAlone`, odelia's concept: R1. Without it odelia cannot take the
  soil alone. Its four members:
  - `alone_block()`, where the block is: R1;
  - `steps_alone()`, the decision at a step's start, which needs the model's
    budget: R1 and R2 (Q3's threshold);
  - `alone_inputs(u)`, for the two lines and the defect: R1 and R2;
  - `alone_rates(t, y, u, out)`, at any scalar: R1, and R3 for the sweep.
- `instruction::alone_slope`: R3. S1 failed, so the slope stays, and is held.
- `instruction::alone_steps`: R4. A non-empty list is also the flag.
- `taken_step`'s block samples: R5.
- plant's `ode_soil_alone_share`: R1 and R8, with 0 for off.
- plant's `ode_alone_slopes` and `ode_alone_steps`, in Parameters: R4, so that
  a program replays the run's steps taken alone.
- plant's `SCM$ode_alone`: R9, derived from the program.

*Deleted:*
- ARK: `ArkStep`, its Newton and Jacobian, `Method::ark`, `HasStiffBlock`, and
  plant's `ode_method = "ark"` (R7, S3);
- the driver's extra evaluation at the end (S2);
- a separate flag on the row;
- a stored count of steps taken alone.

## What this settles

- No pass re-chooses anything a step taken alone chose. Replays are smooth on
  one grid at the leaf solve's level.
- The sweep needs no term across rows: the slope is a held input, like the
  step's size.
- Walks are untouched.
- The split's leaky row in §9 of `design-sign-changes.md` closes by structure:
  the step the concept names serves the whole state's dense output, the soil's
  from its inner steps.
- One soil mechanism serves every record, and ARK's branches are not merged.
- There is no Cash–Karp in plant and no Jacobian anywhere.

## What this makes hard

- *The floor in `J`* (R10): about 2.3e-5 of `J`, 0.001ε, that the tolerance
  does not move. The controller cannot refine to brute force until the floor is
  traced and closed. Q3 named the share threshold, held fixed as the tolerance
  tightens, but did not test it. *Cope:* a share of 0 is bounded Cash–Karp, at
  the saving's cost.
- *A program now carries four fields through R, not two.* A program copied
  without its new fields would replay a step taken alone as an ordinary one,
  past the soil's stability. *Cope:* every accessor writes the four together,
  and the setter refuses fields whose lengths disagree with the program's.
- *A System whose walk reads its own block* would step it past its stability
  limit on a row the run took alone. *Cope:* plant's walks load every field
  (`run_mutant`), which is what makes walks safe; a ⚠️ marks the site in odelia.
  A walk at another scalar refuses such a row, as it refuses a split one.
- *Inputs that turn sharply inside a step,* such as rain starting mid-step.
  *Cope:* the defect shortens the step, and the knots are step targets, so
  onsets fall at a step's ends.
- *Inputs the line would carry through zero.* *Cope:* the line stops at zero
  rather than change sign, since a flow's trend over one step does not justify
  reversing it. On TF24, whose uptake is a loss, that is the driver's clamp.

## Kill condition

- *Replays must re-decide which steps take the soil alone,* because the grid
  adapts to θ rather than being held per analysis. The recorded choices then go
  stale with θ, and the design hands off to the floor's re-choosing, at 2.5e-7
  of noise.
- *The block's inner numerics need the model,* an exact or implicit flow. The
  design hands off to B.

## The design

### Vocabulary

| word | what it is | in code |
|---|---|---|
| the block taken alone | the components a System can step without the rest; their rates read the rest only through inputs. TF24's soil layers | odelia `StepsBlockAlone`, `alone_block()` |
| inputs | what the rest of the state hands the block at an evaluation; TF24's uptake from each layer | `alone_inputs(u)` |
| a step taken alone | an outer step on which the block is integrated by inner steps under inputs on a line, while the rest takes Cash–Karp's step, reading the block from them | a row whose `alone_steps` is not empty |
| predictor | the block alone from the step's start, under the inputs extrapolated from the last step; it stops at every stage's time and every sample fraction | (a pass, no name) |
| corrector | the block alone again, under the line from the start's inputs to the stage's at t + h; the step keeps its end | (a pass, no name) |
| inner steps | either pass's Cash–Karp steps, recorded as where each ended, as fractions of the step | `alone_steps` |
| the coupling's error | the larger of the passes' gap at the end and the stage inputs' defect against the line, in the block's rates | the block's entries of `yerr` |
| the share | the uptake's share of the soil's water budget at a step's start; under the Control value the step takes the soil alone | `ode_soil_alone_share` |

### Who owns what

- *odelia owns the step taken alone:*
  - both passes, the stages reading the predictor, the stage at t + h's inputs,
    and the coupling's error;
  - choosing and recording the inner steps;
  - the slope from the previous accepted step, and the block's weight;
  - the dense output's block, and which passes read the record.
- *The System names the block:* where it is, whether a step takes it alone,
  its inputs, and its rates under given inputs.
- *plant:* TF24's soil as the block, the share, the Control value, the
  program's fields through R, and the counts.

### A step taken alone, in order

Once at the step's start, held across retries:
- the System says whether the step takes the block alone;
- odelia reads u0, the System's inputs;
- the slope is (u0 − u_prev)/h_prev from the previous accepted step. It is zero
  after an insertion and at a run's start, as on the driver.

Then each attempt:
1. *The predictor:* the block from y0 under u0 + (u1′ − u0)·s, where s is the
   fraction of the step and u1′ is u0 + h·slope, stopped at zero. It stops at
   the stages' fractions (1/5, 3/10, 3/5, 1, 7/8) and the sample fractions (¼,
   ½, ¾). Its inner steps run at `1e-9` relative and `1e-13` absolute, as on
   the driver.
2. *The stages:* Cash–Karp's five stage states, the block replaced by the
   predictor at each stage's fraction. The System's inputs are read after each
   stage's evaluation.
3. *u1* is the inputs at the stage at t + h (S2).
4. *The corrector:* the block from y0 under u0 + (u1 − u0)·s, to the end.
5. *The end:* Cash–Karp's end, the block replaced by the corrector's. It is
   evaluated as any step's end, so an attempt costs six evaluations.
6. *The error:*
   - the rest's is the embedded estimate;
   - the block's is the larger of |corrector − predictor| at the end and
     h Σᵢ bᵢ |f(tᵢ, θᵢ, uᵢ) − f(tᵢ, θᵢ, linᵢ)|, with f the block's rates, bᵢ
     the fifth-order weights and linᵢ the line's inputs at stage i;
   - the block's is judged at the smallest weight outside it. For TF24 that is
     the members' min(f, 100) against the soil's min(10f, 100), f being rule A's
     factor (Q3's members' weight).
7. *Accepted:* the slope and both passes' inner steps go onto the row's
   instruction, and u_prev and h_prev advance.

### What a row records

`instruction` gains one field, as built:

```cpp
struct alone_steps { std::vector<double> slope; std::vector<double> ends; };
struct instruction { double time; double step_size; bool insertion = false;
                     alone_steps alone{}; };
```

- A non-empty `slope` is the flag. `ends` are where the inner steps ended, as
  fractions of the step; both passes take the same ones (as built, below).
  Every stop is among them, written from the same constants.
- A `step_record` is an instruction, so the recording carries the field, and
  `schedule()` hands it to plant with the times and sizes.
- Long drought holds about 37 ends a step taken alone, and the constant record
  about 12, each step with 5 slopes.

### Each pass

| pass | on a row taken alone |
|---|---|
| the adaptive forward | decides, chooses the inner steps, records |
| a program's replay (`step_by` from an instruction) | the row's slope and inner steps; no error estimate |
| the stand's sweep | the same at the active scalar. u0 and u1 are active, read after the evaluations at the start and at t + h, so the corrector's dependence on the step's state is taped; the slope and the inner steps are held |
| an invader's walk | steps the block with the rest. Its evaluations load the run's field, soil included, so its own block is never read; its rows record no step taken alone, and its sweep follows them |
| a walk at another scalar | refuses the row, as it refuses a split one |
| a caller's grid (`step_to`) | never takes the block alone |

### The split

The split reads the whole state's dense output through `taken_step::dense_state`.
- *On a step taken alone* the block's components come from the quartic through
  the predictor's samples at the five fractions, which the predictor stops at;
  the rest come from Cash–Karp's extension. A split node then reads the soil
  that the unsplit members' stages read.
- *At u = 1 the predictor is not the step's end.* The pieces' last stage reads
  the soil that the stage at t + h read. The end evaluated again after the split
  reads the corrector's, as the step's own end does.
- *The sweep's `taken_step`* carries the active predictor's samples.

### The decision and its threshold

- *plant's share* is Σ|u| / Σ(|inflow| + |drainage| + |u|) over the layers, at
  the step's start, as the driver reads it.
- `steps_alone()` holds where the share is under `ode_soil_alone_share`. The
  default 0 is off. 0.1 is Q3's registered threshold and the TF24 setting's.
- Tuning it with the tolerance belongs to the scheduling heuristics (R10).

## The implementation map

### odelia: `ODELIA-55`, on `ODELIA-54`

| commit | what | gate |
|---|---|---|
| 1 | The step's forward and the sweep's recording become one body at any scalar (`take_step`), as `ArkStep`'s were. The forward stores its evaluations and sign values; the recording loads them. This subtracts the second copy of the stage loop, in `step_adjoint`'s `whole_step` | bit for bit: odelia's suite, plant's split tests and the FF16 guard |
| 2 | `StepsBlockAlone`, and `instruction::alone_slope` and `alone_steps` | compiles; nothing moves |
| 3 | The step taken alone, in `take_step`. Both passes integrate the recorded pieces through `integrate_pieces`, its pieces being the inner steps, with the block handed back at each stop. In the forward a chooser picks each piece at `1e-9` with the tableau's embedded estimate, and takes it through the same piece code, so a replay repeats it to the bit. The coupling's error is formed in the forward | the toy tests below |
| 4 | The solver: the decision, u0 and the slope at the step's start; the block's weight; the record onto the row in `push_step`; `step_by` from an instruction reads it; a walk steps the block with the rest, with a ⚠️ at the site; a walk at another scalar refuses the row; `step_adjoint` gets the row's instruction; `method = "rodas"` refuses a row taken alone | the toy tests below |
| 5 | `taken_step::dense_state` serves the block from the predictor's samples | a toy that splits a step taken alone |

- *Files:*
  - `ode_interface.hpp`: the concept and the instruction;
  - `ode_step.hpp`: `take_step`, the step taken alone and `taken_step`;
  - `ode_solver_internal.hpp`: the decision, the slope, the weight, the record
    and the passes;
  - `ode_solver.hpp`: `advance_recorded` hands `step_by` the instruction, and
    the sweep hands `step_adjoint` the row.
- *Tests:* `test-step-alone.R`, on `test-ark.R`'s store System, ported: a
  population drawing on a two-layer store with drainage K w², stiff where K is
  large. They check that:
  - with the share off, everything is bit for bit;
  - the forward agrees with a tight reference, in fewer steps than Cash–Karp
    where the store is stiff;
  - the program's replay is bit for bit, and a replay at a moved parameter
    takes the run's inner steps;
  - the sweep agrees with central differences of the replayed program;
  - the dense output's block is the predictor's samples at the five fractions;
  - the record holds one slope per block component, with every stop among the
    ends.

### plant: `PLANT-105`, on `PLANT-104`

The branch takes its issue's number when it is filed, 105 if nothing comes first.
It stacks on `PLANT-104` (aornugent/plant#104, `control_tf24()`), whose setting is
its baseline.

| commit | what | gate |
|---|---|---|
| 1 | TF24's soil rates at any scalar under given uptake: `conductivity` and `infiltration_excess` templated, and `alone_rates`, with the floor at the residual moisture. These come from `ark-soil`'s `stiff_rates` and `stiff_alone` | bit for bit |
| 2 | The patch satisfies `StepsBlockAlone` where its environment names its soil, a concept on E. It gives `alone_block()`, `alone_inputs()` (the uptake from each layer at the last evaluation), `alone_rates()`, and `steps_alone()` from the share and `ode_soil_alone_share` (Control, default 0) | off: bit for bit, the FF16 guard included |
| 3 | The program through R: `ode_alone_slopes` and `ode_alone_steps` in Parameters. `refine_schedule` and the run's accessors write them with `ode_times` and `ode_step_sizes`; `NodeSchedule`'s setter reads them and refuses lengths that disagree | the four fields round trip; the refusal fires |
| 4 | `SCM$ode_alone`: steps taken alone and inner steps, from the program | counts match the record |

- *Files:* `tf24_environment.h`, `patch.h`, `control.h` and `control.cpp`,
  `parameters.h`, `node_schedule.h` and `node_schedule.cpp`, `scm.h`, the
  RcppR6 Parameters fields, and `NEWS.md`.
- *Tests* in `test-scm.R`, for TF24 with the soil alone:
  - the program's replay is bit for bit;
  - `J′ = J` to the bit with splits on;
  - the error falls with the tolerance above `3e-5`, with the floor noted;
  - off, everything is bit for bit.

  `test-control.R` lists the new field.
- *Size, hand-written code, tests aside:* about 250 lines in odelia and 170 in
  plant. ARK's, which this replaces, was about 640 and 200.

### The driver, aligned (plant-dev)

`sa_harness.diff` gains the build's choices (the last three as built, below):
- the predictor stops at the sample fractions;
- the inner steps are taken in fractions of the step;
- the first inner rates are the step's own;
- the defect comes from the rates' difference;
- the corrector takes the predictor's inner steps;
- the inner steps are chosen by odelia's step control (`OdeControl`) at `1e-9`
  and `1e-13`: grown only under half the tolerance, by 0.9 r^(-1/6) up to 5,
  and shrunk by 0.9 r^(-1/5) down to 0.2, the size carried across stops, the
  first try reaching the first stop;
- a step's inner steps never go below the solver's smallest step.

The line already stops at zero. Its cost lies within 1% of S2's and its `J`
inside the bound, and it is the reference G1 compares plant against.

### ARK, retired

- odelia's `ark-step` (`f11e753`) and plant's `ark-soil` (`4dc59a40`) are not
  merged.
- Item 5 re-lands what it takes from them: the soil's rates at any scalar and
  the store toy.
- The handover marks them retired. Deleting the branches is the user's call
  (Q2).

## As built

*odelia `ODELIA-55`* (five commits on `ODELIA-54`, odelia#55): `b70259d` one
step body; `0e7009e` the concept and the record; `45a3156` the step taken alone;
`bed4c9c` the solver's part; `f156142` the predictor's samples at the System's
scalar. Departures from the map:
- *The forward chooses the inner steps, then takes the step as a replay does.*
  `Step::alone_ends` picks them, and the step runs the passes over the chosen
  list, so a step has one mode and the forward is a replay of its own record.
- *One list of inner steps serves both passes.* The corrector takes the
  predictor's, so the record holds one list and the gap between the passes is a
  difference of inputs alone.
- *Odelia's own step control chooses them*, rather than a second controller,
  floored at the solver's smallest step. A block that is not finite there throws
  `util::DomainError`, which the outer step rejects, so a failing block stops the
  run with its reason rather than looping. Both the floor and the comparison
  with the piece asked for were found by a toy that failed at every inner step.
- *The dense output's block* landed with the step (commit 3), not as a fifth
  commit; `integrate_pieces` gained the hook that keeps the block at each stop.
- *The step's error estimate is written once* (`step_error`), for the step and
  the inner steps.
- *Tests:* `test-step-alone.R`, 28 expectations. On the store toy the run takes
  27 to 771 steps where Cash–Karp takes 1 519 to 3 995 (tol `1e-4` to `1e-9`),
  as accurately; the sweep matches central differences of the replayed program
  to 7e-8; a walk at the tangent scalar refuses a row taken alone.

*plant `PLANT-105`* (three commits on `PLANT-104`, aornugent/plant#105):
- *`9b4b6658`:* the soil's rates at any scalar (`conductivity`,
  `infiltration_excess`, `alone_rates`), bit for bit.
- *`9f20f9ba`:* the patch's hooks behind a concept on the environment; the uptake
  held at the working scalar and handed back with the other active values;
  `ode_soil_alone_share`, default 0. `control_tf24()` does not set it, so it
  stays the coupled baseline (bnd) that G4 compares against.
- *`146d9862`:* the program through R. `set_ode_steps` takes the four fields
  together and refuses records whose count differs from the sizes', or a row with
  one of slope and inner steps. `program()` now replays each interval's last
  step by its record: a step to the end never takes the soil alone, so a
  pinned replay would have stepped the soil past its stability limit there.
- *No `SCM$ode_alone`:* the counts are `ode_alone_steps`' lengths (R9), so no
  accessor stores them twice.

*What the build's first runs showed* (`control_tf24`, splits on;
`measurements/soil-alone/plant/`, not registered gates):
- one year under wet constant rain (3 m/yr), where the soil binds bnd's steps:
  116 steps against 189 at `1e-4`, and `J`'s error falls with the tolerance
  (2.5e-6, 4.0e-7 and 2.4e-7 at `1e-4`, `3e-5` and `1e-5`) before flattening
  (R10);
- three years of seasonal rain, whose steps the nodes bind (178 of 208): no
  saving. The coupling error, judged at the members' weight and so ten times
  tighter than the soil's under `control_tf24`, binds 88 steps, and the run
  takes 211;
- at `1e-7` on three-year constant-rain stands the coupling error, of lower
  order than Cash–Karp's, binds most steps (700 of 841 at 1 m/yr, 612 of 792 at
  3), so the saving belongs to the loose tolerances the gates run at;
- the sweep of `lma` through steps taken alone matches central differences of
  the replayed program to 2e-11 without splits and 3e-8 with them
  (`sweep_dbg3.R`). Under seasonal light the split sweep lies 3.7e-3 from them
  with the soil coupled or alone (`sweep_dbg.R`): it evaluates a piece's
  time-dependent drivers at held times. That is `PLANT-103`'s, and open.
- the full serial suite passes but for "mutant method works", whose two
  expectations fail on `PLANT-104` with the same numbers.

## Gates

Each gate is registered in `measurements/soil-alone/` before the build's runs.
Every run uses bounded Cash–Karp's setting, `control_tf24()`: the tied
tolerance, the soil ×10 (the accumulators keep 1), weights bounded at 100 and
the 15-day cap. Rule A's window comes on top, with a share of 0.1.

| gate | what passes |
|---|---|
| G1, the port | plant against the aligned driver, splits off: the same accepted steps and steps taken alone, and `J` to the bit or within 1e-12, on long drought and episodic |
| G2, identity | the program's replay bit for bit; `J′ = J` to the bit at θ′ = θ, with splits on |
| G3, the sweep | `lma`'s elasticity against central differences of the replayed program at r = `1e-3`, within 2e-3. A replay's noise in `ln J` under a 1e-12 move of `lma` stays at the leaf solve's level, ≤ 1e-13, against 2.5e-7 re-chosen |
| G4, Q3's pass in plant | on long drought and episodic: rows and member evaluations below bnd's, `J` within 2.524e-4, and five traits' elasticities, by the adjoint and for both roles, within ε/3 of the `1e-5` reference and within bnd's own distance plus 0.1ε. Under constant rain, member evaluations at most 1.2× the driver's arkc's (1 228 821) |
| G5, the bank | §9's gates with the soil alone and splits on, under the cap, on the five records |
| G6, the cost | timed alone on one core, the forward and the sweep on long drought at `3e-5` against bnd's; the inner steps under 1% of a profile |
| G7, off | a share of 0: every run bit for bit, the FF16 guard and the split's tests included |

## Order

1. Item 7's setting, named once (`design-grid-controller.md`, item 7, step 1).
   It is this item's baseline, and the bank's G1 needs its cap on episodic and
   dry. *Built:* `control_tf24()` (aornugent/plant#104, `PLANT-104`
   `8ba5f7d0`).
2. `ODELIA-55`, then `PLANT-105`, then the driver aligned.
3. G1–G7.
4. Then item 7's pilot and item 6, in either order.

## Questions with defaults

*Settled:* the user took all three defaults (2026-10-07).

- *Q1, the program's R form.* Two list fields beside `ode_times` and
  `ode_step_sizes`, or one `ode_program` list replacing all four? *Default:* the
  two fields, with the setter's length check. Unanswered, the default becomes
  a finding in the build's review.
- *Q2, ARK's branches.* Deleted, or kept on the forks unmerged? *Default:* kept,
  marked retired in the handover.
- *Q3, R10's deferral.* Does it stand now that the floor is measured at
  0.001ε? *Default:* yes. The threshold's tuning stays with the scheduling
  heuristics, and the build carries it as a Control value.
