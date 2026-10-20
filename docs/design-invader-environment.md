# Design: the environment an invader grows in

Status: a proposal, stress-tested against odelia `ODELIA-55` (8b7ff84) and plant
`PLANT-95` (1dcf7d7e). It replaces odelia#58, which is closed, and reshapes the
invader half of plant#116.

## The domain

A resident stand sets the light and the soil. An invader is too rare to change
either, so it grows in the residents' environment as it was. For the invader
that environment is an input, like rainfall: given, read and never
differentiated. The invader's own leaf operating points are not inputs. It
solves them, the run records them, and its reverse sweep reads them back.

## Where the complexity came from

Before odelia (plant before #456), the invader was a switch:

- the resident ran with `save_RK45_cache`, and the Patch copied its environment
  at each Runge-Kutta stage into `environment_history[step][stage]`;
- `run_mutant` set `use_cached_environment`, swapped in the invader's
  strategies and pinned the steps to the resident's;
- the stepper passed each stage's index to `derivs`, and the Patch found the
  step by its time and read `environment_history[step][index]`.

About 60 lines. Since then:

1. **odelia was taken out of plant (#456).** The stage index was a plant hook
   (`has_cache`), and the generic stepper dropped it.
2. **Adjoints (#648, #658).** The sweep revisits steps backwards, one at a time,
   so a "current step" found by time no longer exists: every evaluation must be
   told where it is. odelia had briefly addressed evaluations by
   `recorded_stage {step, stage}` (odelia 001528b), then replaced the address
   with rows of solved values that travel with each step, passed read-only or
   writable (odelia 36d5a55). The reason given: a System that keeps its own
   store, looked up by address, keeps a second copy of the run's recording,
   which must be kept in step with the first. That was right for solved values.
   But the solved row then became the only per-evaluation channel, so #648 put
   the residents' environment in it as `recorded_field`, and inputs and solved
   values were mixed.
3. **Introductions inside the step program, and resumed residents.** An
   introduction falls between rows, so it has no slot of its own. That brought
   `loaded_field` persisting through `end_solved`, introduction fields taken
   from `solved[5]`, `stand_in` and `resident_start_field`.
4. **TF24's leaf solve, recorded in the same row.** The invader inherited the
   resident's leaf operating points, matched by position. Upstream `develop`
   still runs a TF24 invader at the resident's collar potentials. odelia#58's
   copy-and-overwrite was the patch for that.
5. **The held environment (#661).** A second invader mode, with its own flags.

Only (2) is required by adjoints, and what it requires is smaller than what was
built: every evaluation, forward and in the sweep, must know which evaluation
of the run it is.

## The design

**odelia addresses every rate evaluation.** A System may declare
`begin_evaluation(evaluation)`, where `evaluation` is `{step, stage}`:
- `step` is the row the step writes;
- `stage` runs from 0 to 6 in tableau order: 0 for first rates derived afresh,
  1 to 5 for the stages after the first, and 6 for the evaluation at the step's
  end.

odelia calls it inside the scope `derivs` already opens, in a run, a replay and
a sweep alike, including first rates derived afresh. First rates carried from
the step before are not evaluated, so they are not addressed. A System that
does not declare it is never called. The solved row is unchanged.

**plant keeps the residents' environments beside the steps they index.** With
the switch on, a resident run writes the environment it computes at each
address into a table. `SCM` keeps the run's schedule and that table together,
as one object. A Patch reads its environment from one of three sources:
- **computed** from its own cohorts (a resident);
- **recorded**, read from the table by address (an invader);
- **held**, one environment for every evaluation (#661's fixed point).

Under recorded or held, the environment's own state (TF24's soil) has no rates.

**An invader run** is the existing `advance_recorded(resident_schedule)`: the
resident's steps, everything else solved afresh. It solves and records only its
own leaf values. Its sweep reads the same table at the same addresses.

Answering odelia 36d5a55's objection: the table is not a second copy of the run
being recorded. It is the resident's output, kept with the schedule it indexes
and read-only to every other run. The values a run solves still travel on its
rows.

## Stress test

| Case | Verdict |
|---|---|
| Stages of a step | The invader replays the resident's schedule row for row, insertions included, so every `{step, stage}` names the same evaluation in both runs. |
| First rates carried from the step before | Not evaluated, so nothing is read. |
| First rates derived afresh (run start, after an introduction, after a re-seed) | Addressed `{step, 0}` and recorded by the resident, so the invader reads the environment after the residents' own introduction. Today it reads the environment before it, which is a small error. This case needs odelia to address the sites that derive first rates. |
| The inflow evaluated at an introduction | The insertion map runs on the state the step below ended at, so the environment is exactly `{step − 1, 6}`. This is one plant rule, with no odelia call. |
| An introduction the invader does not share | odelia carries the invader's first rates across the no-op insertion, so the first stage reads the environment before the residents' newborns. The same happens today. **Open:** re-derive first rates after every insertion row, at one evaluation per resident introduction, to make this exact. |
| A pinned step refused and crossed in sub-steps | Addresses repeat at other times. The Patch keeps today's check that the recorded time equals the evaluation's time, and refuses. |
| Rejected attempts in the resident's adaptive run | A retry writes the same addresses, so the accepted attempt's values are what remain. |
| Cash-Karp against Dormand-Prince | A stage index means different things in the two tableaux. One check: the invader's method is the resident's. |
| The invader's reverse sweep | It reads the same table at the same addresses. The environment is plain doubles, so it carries no derivative: the rare-invader derivative, by construction. |
| Several invaders in one patch | The table holds no species, so the species-count coupling and upstream's leaf bug both go. |
| A resumed resident | The resumed run records `{1, 0}` itself, so `stand_in` and `resident_start_field` go. The TF24 refusal, which matched leaf points to cohorts by position, has no cause left. |
| The held environment (#661) | A source that ignores the address. Its flags collapse into the same member. |
| TF24w's private water | The table's entry is what the environment shows a newcomer, so the aggregates go in it. Today they would be recomputed from the invader's own columns. |
| Soil substeps on an invader run | The resident's schedule carries substeps for a soil the invader does not integrate. **Open:** drop them from the invader's schedule, or let them integrate zero rates. |
| Memory | Invader rows lose the copied environment, which is most of their size today. `SCM` keeps the resident's schedule and table, not its states and leaf rows. |
| Runtime | The table is written during the resident's own run, because its sweep never reads it. That removes the pinned replay `run_mutant` makes of every resident: 0.82 of a forward run each. |
| Forked invader batches | The table is read-only, so it is shared safely. |
| FF16 and K93 invaders | Same mechanism, with no leaf values. |
| A resident with harvests or extremes | Refused today, and still refused. Their environments would be recorded like any other, so the design does not make lifting the refusal harder. |

## What it deletes and what it adds

Deleted:
- odelia#58;
- from `patch_solved_values`: `field`, so solved rows hold solved values only;
- `loaded_field`, `field_fresh`, `field_slot`, `keep_field`, `stand_in`;
- `introduction_fields` and `set_introduction_fields`;
- `resident_start_field`;
- the `solved[5]` introduction lookup in the gradient;
- the TF24 resumed-resident refusal;
- the species-count check between rows;
- the held environment's separate flags;
- the pinned resident replay;
- the invader's own soil integration.

Added:
- in odelia, `evaluation {step, stage}` and one optional System member, called
  at the evaluation sites the steppers and the sweep already have, and at the
  sites that derive first rates;
- in plant, the environment table with the schedule it indexes, a three-way
  environment source on the Patch, and the switch that writes the table.

## Questions to settle

1. The switch's name. `save_RK45_cache` is the old name, and regnans still sets
   it.
2. Whether to make introductions the invader does not share exact
   (re-derive first rates after every insertion row) or keep today's
   approximation.
3. Whether to drop the substeps from the invader's schedule or integrate zero
   rates.
