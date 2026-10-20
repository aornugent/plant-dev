# Design: the environment an invader grows in

Status: built. odelia `ODELIA-59` (0.9.0, on `ODELIA-55`) hands each rate
evaluation its slot; plant `PLANT-95` (#116) has the invaders read the field
by slot and time. It replaces odelia#58, which is closed.

## The domain

A resident stand sets the light and the soil water. An invader is too rare to
change either, so it grows in the residents' environment as it was: the light
profile, and the soil's ODE state, at each of the plants' rate evaluations.
plant calls the two together the *field*. For the invader the field is an
input, like rainfall: read, never solved, never differentiated. The invader's
own leaf operating points are solved: its run records them and its sweep
reads them back.

The invader mirrors the residents' run. It takes the same steps, its
introductions fall where theirs did, and it meets the same harvests and
climate extremes. Anything the residents' environment met (rain, a water
pulse) is already in the field it reads. This is for fitness landscapes and
coexistence, not for simulating turnover.

## Where the complexity came from

Before odelia (plant before #456) the invader was a switch:
- the resident ran with `save_RK45_cache`, and the Patch copied its environment
  at each Runge-Kutta stage into `environment_history[step][stage]`;
- `run_mutant` pinned the steps to the resident's, and the stepper passed each
  stage's index to `derivs`.

About 60 lines. Since then:

1. **odelia was taken out of plant (#456).** The stage index was a plant hook,
   and the generic stepper dropped it.
2. **Adjoints (#648, #658).** The sweep revisits steps backwards, one at a time,
   so every evaluation has to be told where it is. odelia briefly addressed
   evaluations as `{step, stage}` (odelia 001528b), then replaced the address
   with rows of solved values that travel with each step (odelia 36d5a55). That
   left the solved row as the only per-evaluation channel, so the field went
   into it, and the invader had to load the resident's row.
3. **Loading the resident's row brought the rest:**
   - the invader's leaf takes the resident's operating points, which upstream
     still does for TF24;
   - the copy-and-overwrite of odelia#58, to stop that;
   - the field persisting through `end_solved`, introduction fields taken from
     `solved[5]`, `stand_in` and `resident_start_field`, because an
     introduction has no slot of its own;
   - the pinned replay of every resident, because a resident's own sweep must
     not load the field back.

The root is (2): the invader *loaded* the resident's row, when all it needs is
to *read* one member of it.

## The data structure

A recorded run is its rows. Each row holds a step, the state that step reached
and one record per rate evaluation, in six slots: the five stages after the
first, then `end_slot`, the evaluation at the state the step ends at. A record
holds what that evaluation produced:
- `strategies`, each species' solved values (TF24's leaf operating points), which
  the run's own sweep loads back;
- `field`, the environment the evaluation computed, which a run keeps when it
  records its states, never loads back, and an invader reads.

Two states have no step behind them: the run's start, and the state after each
entry (an instant's actions and introductions). The SCM keeps the field at each
of those as the run reaches it (`entry_fields`), since no slot holds it.

The invaders read a scalar-free table built from the two, `invaded_run`: one
`field_row` per row, the step and its six fields, with the start's and each
entry's field in that row's end slot. It is built at the first invasion and
kept until the next `run()`.

## The interface

**odelia: each rate evaluation is handed its slot.** `store_solved(into, slot)`
and `load_solved(from, slot)`, called by the steppers in a run, a replay and a
sweep. Nothing else changes: the solved row, `end_solved`, and the two ways to
advance.

**plant: one pointer and one rule.** The Patch holds `field_run`, null except
in an invasion. With it set, `compute_environment` installs the field it finds
and builds none, and the environment's own rates are zero, so the invader
integrates no soil. The field is found by the evaluation's time:
- inside a step, in the evaluation's slot of the first step at or after the
  time (or the step before, where a stage's time rounds past its step's end);
- outside a step, where the patch is at a recorded state, in the end slot of
  the last row at the time, which is the state after any entry made there.

The time alone is ambiguous at both ends of a step: Cash-Karp's stage at t + h
and the step's end share a time, and so do a step's end and the entry after it.
The slot settles the first, and being inside a step or not settles the second.

`run_mutant(p)` is a run: the invaders' parameters, the table's steps as their
program, the residents' patch-wide harvests and extremes added to their
schedule, and `run_schedule()`. `run()` leaves an invasion: it drops the table
and runs the SCM's parameters on the schedule they make.

#661's held field is the same input with one field for every evaluation.

## Stress test

| Case | Verdict |
|---|---|
| Stages of a step | Found by slot and time. |
| First rates carried from the step before | Not evaluated. |
| First rates derived afresh (start, after an entry) | Outside a step: the start's or the entry's field, kept as the run reached it. |
| An introduction's inflow | Outside a step: the entry's field, after the entry's actions. |
| A harvest or climate extreme | Mirrored onto the invaders; the field after it is the entry's. One aimed at a single species is refused, since an invader is none of them. |
| A water pulse | In the field already; not applied to the invaders. |
| Rejected attempts in the residents' adaptive run | Each retry overwrites the same slots, so only the accepted step's records remain. |
| The invader's sweep | Reads the same fields. They are plain doubles, so they carry no derivative: the rare-invader derivative, by construction. |
| Several invaders in one patch | The fields hold no species, so there is no species-count coupling and no borrowed leaf values. |
| A resumed resident | The start's field is kept like an entry's, so the TF24 refusal goes. |
| A run that kept no field | Run again on its own steps, keeping one, at the first invasion. |
| A `run()` after an invasion | Runs the invaders as a community of their own; the next invasion reads that run. |
| Memory | Keeping the field costs 3.5 % of a recorded TF24 run's peak; the invaders' rows carry none. |
| Runtime | No pinned replay of the residents: the first invasion takes 0.28 s where it took 0.50 s. |

## The regnans workflow, with adjoints

1. **Equilibrium.** Solve `f(ln b) = ln J(b) − ln b = 0` on recorded runs. One
   sweep at a run gives `∂ln J/∂ln b` and `∂ln J/∂θ` for every trait at once.
   With k coexisting species, Newton's Jacobian `∂ln J_i/∂ln b_j` takes k
   sweeps, one per species' J.
2. **Cache.** The equilibrium run's recording is the cache: its fields become
   the invaders' table at the first invasion.
3. **Hill climb.** Each step runs invaders against the cache, then sweeps once
   for `∂ ln R′/∂θ′` over every trait. Invaders do not interact, so the trial
   points of a line search run together in one patch.
4. **Invasion.** Where `ln R′ > 0`, the invader joins the residents at a small
   birth rate and the community's equilibrium is solved again. A species whose
   `b*` falls below a threshold is excluded. The new equilibrium run is the
   next cache.

## What it deleted and what it added

Deleted:
- odelia#58's copy-and-overwrite pass;
- the pinned replay of the residents;
- `loaded_field`'s persistence, `field_fresh`, `stand_in`,
  `resident_start_field`, `introduction_fields` and the gradient's lookup of
  them;
- the TF24 resumed-resident refusal and the harvest refusal;
- the invader's soil integration.

Added:
- in odelia, the slot on `store_solved` and `load_solved`, and `end_slot`;
- in plant, `field_row`, the `field_run` pointer and its lookup, and the SCM's
  `entry_fields`, `invaded_run` and `invaded_actions`.
