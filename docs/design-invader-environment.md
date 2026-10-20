# Design: the environment an invader grows in

Status: a proposal, stress-tested against odelia `ODELIA-55` (8b7ff84) and plant
`PLANT-95` (1dcf7d7e). It replaces odelia#58, which is closed, and reshapes the
invader half of plant#116.

## The domain

A resident stand sets the light and the soil water. An invader is too rare to
change either, so it grows in the residents' environment as it was: the light
profile, and the soil's ODE state, at each of the plants' rate evaluations.
plant calls the two together the *field*. For the invader the field is an
input, like rainfall: read, never solved, never differentiated. The invader's
own leaf operating points are solved: its run records them and its reverse
sweep reads them back.

The invader mirrors the resident's run: the same steps and the same
introductions. Anything external to the stand, such as seed rain, harvest or
rainfall, has already shaped the field it reads. This is for fitness landscapes
and coexistence, not for simulating turnover.

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

The root is (2): the invader *loads* the resident's row, when all it needs is
to *read* one member of it.

## The data structure

A recorded run is its rows. Each row holds a step, the state that step reached
and one record for each of the step's rate evaluations. A record holds what
that evaluation produced:
- `strategies`, each species' solved values (TF24's leaf operating points), which
  the run's own sweep loads back;
- `field`, the environment the evaluation computed, which the run's own sweep
  never loads and an invader reads.

That is `patch_solved_values` as it stands. Nothing new is stored. What changes
is who reads what:

- **A resident** stores both members when it keeps its field. Its sweep loads
  `strategies` only, and recomputes its field from its state, as it must.
  Storing the field is therefore safe in any resident run, so the run that
  reaches equilibrium records it directly and the pinned replay goes.
- **An invader** holds a pointer to the resident's recording. At each evaluation
  it reads `resident[step].solved[stage].field`, in its run and in its sweep
  alike. It stores and loads its own `strategies` in its own rows, which carry
  no field.

## The interface

**odelia: each rate evaluation is told where it is.** A System may declare
`begin_evaluation(step, stage)`. odelia calls it at the start of every rate
evaluation inside a step, in a run, a replay and a sweep: `step` is the row the
step writes, and `stage` is the slot of that row's record (0 to 5). Unchanged:
the solved row, `store_solved`, `load_solved`, `end_solved`, and the two
existing ways to advance (a program solves everything; a recording loads what
was solved). An invader run is `advance_recorded(resident.schedule())`, which
already exists.

**plant: one pointer.** The Patch gains `const resident_recording* resident`,
null for a resident. `begin_evaluation` sets the field this evaluation reads to
`&(*resident)[step].solved[stage].field`. `compute_environment` installs that
field (light and soil state) when the pointer is set, and computes its own
otherwise. Under a read field the environment has no rates of its own, so the
invader integrates no soil and needs no substeps. The invader's schedule is the
resident's with the substeps dropped.

#661's held field is the same input with one field for every evaluation.

## Stress test

| Case | Verdict |
|---|---|
| Stages of a step | The invader replays the resident's schedule row for row, introductions included, so `{step, stage}` names the same evaluation in both runs. |
| First rates carried from the step before | Not evaluated. |
| First rates derived afresh (run start, after an introduction) | No slot of its own. It reads the last field recorded before it, as the invader does today. That is exact if an introduction leaves the field unchanged at its instant, which #116's bit-for-bit check at the resident's own traits suggests on the birth-date coordinate. The spike measures it. If it is not exact, these first rates get a slot (the end slot of the row before, which is empty for an introduction or the start). |
| The inflow at an introduction | The map runs on the state the step below ended at, so the field is that row's slot 5, exactly. |
| A pinned step crossed in sub-steps | The addresses repeat at other times. The existing check that the field's recorded time equals the evaluation's time refuses. |
| Rejected attempts in the resident's adaptive run | Each retry overwrites the same slots, so only the accepted step's records remain. |
| Cash-Karp against Dormand-Prince | Slots mean different things in the two tableaux. One check: the invader's stepper is the resident's. |
| The invader's sweep | It reads the same fields at the same addresses. They are plain doubles, so they carry no derivative: the rare-invader derivative, by construction. |
| Several invaders in one patch | The fields hold no species, so there is no species-count coupling and no borrowed leaf values. |
| A resumed resident | Its first step's slots hold its own fields, so `stand_in` and `resident_start_field` go, and so does the TF24 refusal. |
| TF24w private water | The newcomer's inputs (patch mean water, crown cover) go in the field. Today they would be recomputed from the invader's own columns. |
| Memory | The invader's rows lose the copied field, which is most of their size today. |
| Runtime | No pinned replay: 0.82 of a forward run saved per resident. |
| Forked invader batches | The resident's recording is read-only, so it is shared safely. |
| FF16 and K93 | The same, with no leaf values. |

## The regnans workflow, with adjoints

1. **Equilibrium.** Solve `f(ln b) = ln J(b) − ln b = 0` on runs that keep their
   field, so the last one is the cache.
   - One sweep at a run gives `∂ln J/∂ln b` (the birth-rate column) and
     `∂ln J/∂θ` for every trait at once.
   - Cold, the secant method wins: 6 runs from b = 1. The #116 Newton loop
     needed 7, each with a sweep of about 2.9 forward runs.
   - The adjoint pays at the warm start. The sweep at an equilibrium gives
     `d ln b*/dθ = −(∂ln J/∂θ)/(∂ln J/∂ln b − 1)` for every trait, so the next
     resident starts from a first-order prediction of its `b*`.
   - With k coexisting species, Newton's Jacobian `∂ln J_i/∂ln b_j` takes k
     sweeps: one per species' J.
2. **Cache.** Keep the equilibrium run's recording. Its fields are the cache.
3. **Hill climb.** Each step runs invaders against the cache, then sweeps once
   for `∂ ln R′/∂θ′` over every trait. Invaders do not interact, so the trial
   points of a line search run together in one patch.
4. **Invasion.** Where `ln R′ > 0`, the invader joins the residents at a small
   birth rate and the community's equilibrium is solved again, from the
   residents' `b*`. A species whose `b*` falls below a threshold is excluded.
   The new equilibrium run is the next cache, and the next invader starts.

## What it deletes and what it adds

Deleted:
- odelia#58;
- the pinned resident replay;
- `loaded_field`'s persistence, `field_fresh`, `stand_in`,
  `resident_start_field`;
- `introduction_fields` and the `solved[5]` lookup in the gradient;
- the species-count check between rows, and the TF24 resumed-resident refusal;
- the invader's soil integration.

Added:
- in odelia, one optional System member, `begin_evaluation(step, stage)`,
  called where the steppers and the sweep already hand a slot;
- in plant, the `resident` pointer and the branch in `compute_environment` that
  reads it.
