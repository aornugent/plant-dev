# Review: ODELIA-55 and PLANT-105, the soil substepped (Tier 2)

Self-review under `.claude/skills/code-review/` of odelia `ODELIA-55` (2 commits
on master 1e0f0f0) and plant `PLANT-105` (3 commits on develop bd09645d). The
bodies were written in this session, so the Cold Reader's predictions are a
lower bound on misses.

## Verdict: approve with changes (applied below)
## Triage: 2 — a feature with a new concept in odelia and four program fields in plant's R interface; no persisted format

## Ledger
Source: `design-soil-alone.md` (R1–R10), review B's fixes, the brief.
- R1 the saving: fewer rows where the plants draw little of the soil's water.
- R2 accurate: `J` and the elasticities within the bounds the design set.
- R3 the sweep differentiates the step taken; R4 a replay at θ ≠ θ₀ takes the
  run's substeps; R5 (the split) is out of scope here: no split on these bases.
- R6 never fails; R8 off by default (share 0) — amended: a step across a knot
  of the rain substeps whatever the share (review B kept this).
- Review B: fold renames; refuse a replay given times only; fix the control.h
  comment; collapse `HasSoil` if that removes code.
- Brief: nothing from the split, the window or the tolerance factors.

Design doc check: the commitment ("a step that substeps is a function of its
own row") is kept by structure: only `SolverInternal::step` calls
`choose_substeps`, and `step_by` and the sweep read only `row.subsystem`. Nouns
not on the doc's survives-deletion list: `spans_subsystem_knot` and the grid
refusal (review B's fix), `substep_field` (the doc's `alone_field` renamed once,
here, at birth). The doc's `instruction::alone_*` became one
`std::optional<subsystem_substeps>`; the doc's `StepsBlockAlone` is
`HasSubsystem` with a fifth member, `subsystem_knots`.

## Clean sheet
odelia: a concept naming the subsystem; a record on the instruction; a Step
path that integrates the subsystem over recorded substeps (predictor,
corrector, error); the forward choosing them; replays and the sweep reading
them. plant: the soil's rates under a given uptake through compute_rates' own
body; the patch naming the soil; one Control value; the record through R.
Gap: the diff adds the knot trigger (review B: kept, measured) and two
refusals (grid; sized row without substeps across a knot). Each is paid by a
ledger line (R6, review B).

## Prediction record
- `step_by(System&, const instruction&, replay)`: predicted "replays a recorded
  step, coupled"; actual: also refuses a row without substeps that spans a knot.
  Named in the comment above it. Kept: it is the one place that sees the row.
- `NodeSchedule::program_within(start, end)`: predicted the open interval
  (develop's contract); actual now `(start, end]`. Comment updated; the one
  caller (`integrate_to`) skips `advance_fixed` when the program reached `end`.
- `Patch::subsystem_rates`: predicted the environment's layer rates; actual
  zero under a held field. Comment states it.
- No other misses — checked 19 signatures.

## Decisions reopened
- D1: chose walks of a recording (rows loaded) to substep as recorded, over
  the archive's "a walk steps the subsystem with the rest". Settled by R4 and
  by the odelia toy (a recording replay repeats the run bit for bit). Cost:
  an invader's walk integrates its unread soil in substeps, ~1% of an
  evaluation (G6). Removes the archive's ⚠️ hazard and its tangent-walk
  refusal.
- D2: chose a refusal in `step_to` over substepping grid steps afresh.
  Settled by review B ("refuse"). Consequence: a coarse grid on variable rain
  is refused unless it holds the knots → Q1.
- D3: chose optional soil records in `set_ode_steps` (both empty, or one per
  size) over the archive's mandatory records. Settled by the develop callers:
  five FF16 tests and the documented `p$ode_times <- scm$ode_times;
  p$ode_step_sizes <- scm$ode_step_sizes` idiom broke under mandatory records.
  The loss of protection is covered at knots by odelia's refusal; a step
  substepped for coupling alone (share > 0) is not → Q2.
- D4: chose to keep `HasSoil` and five one-line forwarders over collapsing onto
  `HasSubsystem`. The subsystem's range is in the patch's coordinates
  (`ode_size() - environment.ode_size()`), the decision reads the patch's
  Control, and a held field zeroes the rates; an environment-level
  `HasSubsystem` would move the offset and the threshold into the environment
  and add code. Settled: collapsing removes none.
- D5: chose to keep plant on GSL's rule in `make_ode_control` over adopting
  odelia 0.8's Hairer default. Settled by the brief (no numbers move but the
  soil's); the FF16 guard is bit for bit under it.

## Change simulation
- The split (odelia 2 / plant 6) lands next: its dense output needs the
  predictor at the sample fractions. Edit sites: `stage_fractions` gains the
  sample fractions (or a second stop list), `take_substepped_step` keeps the
  samples, `taken_step::dense_state` reads them. One file, but it moves every
  substepped run's substep ends, so that PR re-blesses → leaky, planned; noted
  in the case.
- A second System with a subsystem: one-place (implement the five members).

## What must always be true
Every pass but the adaptive forward takes a substepped step from its row
alone. Kept true by: structure (`choose_substeps` has one caller;
`last_inputs_` is set only after an adaptive push and cleared by every other
push and every re-seed).

## Structural findings
1. (applied) The grid refusal alone left a sized replay without records
   silent. Makes a pinned replay of a substepped run that dropped its records
   step the soil past its stability limit without error. Fixed: `step_by`
   refuses a row without substeps that spans a knot (parameter-independent:
   the forward always substeps such a step under Cash–Karp). Tested in odelia
   and plant.
2. (not applied) `make_node_schedule`'s events path still turns a program into a
   grid (develop's behaviour). With records it would now be refused at a
   substepping step rather than collapse; the archive changed it to replay the
   program. Left as develop has it: changing it would alter FF16 replays given
   events, which no ledger line asks for. Noted for the reviewer.
3. (applied) A held field (`run_mutant_held`) zeroes the environment's rates,
   but a substepped step would have integrated the soil under its own rates.
   `Patch::subsystem_rates` returns zero there.

## Minor findings
- `run_mutant`'s recording pass calls `schedule()` four times through the R
  getters. Kept: one installer validates the four together.
- `instruction` grows from 24 bytes to about 80 for every run (the optional
  record). 7 000 steps cost ~0.4 MB. The comment on `prev_schedule` is updated.
- The water-balance sums read the main step's stages, so on a step that spans
  a knot they miss the rain the soil takes between stages (3.1% of dry's rain,
  round 4 S). Stated in NEWS and in `test-tf24-water-budget.R`, which keeps
  its stops.

## Questions with defaults
- Q1: should a grid step across a knot substep afresh instead of being
  refused? Default: refuse (review B). Unanswered, the default stands.
- Q2: should plant refuse sizes without records when the share is > 0?
  Default: no; NEWS says to carry the records then. Unanswered, this becomes
  a finding at the next review of `set_ode_steps`.

## Comment rules (AGENTS.md)
Every touched line checked: no issue tags, no process history, no banners, no
`frozen/mutant/live/resident` in new comments, none over two lines but the
two ⚠️ hazards (`test-tf24-water-budget.R`, `helper-gradient-ladder.R`).
Removed in the environment's refactor: the issue tags `#485/#549/#558` in the
comments `layer_rates` replaced.
