# Handover

**The next session finishes [aornugent/plant#95](https://github.com/aornugent/plant/issues/95): an invader must be an exact replay of the recorded run, events included (R6).** Read in this order:
- this page;
- `scope-imex-stepper.md` §1, §2.3 and "§2.3, extended", which hold the design and why the first version of it gave way;
- #95, which holds the measurements.

The user's five principles apply: Laziness Protocol, Subtract Before You Add, Minimize Reader Load, Foundational Thinking and Model the Domain. Ask for their text if the session does not include it. AGENTS.md's code style applies to every comment.

## Finish #95

**Done and pushed.** Plant is `de4809fe` on `PLANT-95`, one commit on `offspring-adjoint`; odelia is `29205f0`, one commit on `claude/trusting-curie-4i9n3l`.
- Every forward pass stores its own rows, and only the sweep loads.
- Invaders solve for their own leaf operating points.
- Several invaders can invade together.
- An invader's recording can be swept, and its sweep agrees with a pinned difference to 1e-10.
- Resident runs and resident sweeps are bit-identical to the base.

**In progress: R6.** At every schedule entry an invader must apply the same events, in the same order, before the same introductions, and its evaluations after an entry must use the field after the entry. The identical invader on `test-mutant.R`'s TF24 fixture, log fitness against the resident's:

| schedule | log gap |
|---|---|
| no events | −7.1e-15 |
| a resource pulse of 0.05 at t = 2.5 | −1.2e-7 |
| a 50% harvest at t = 3.5 | +0.69 |
| a lethal climate extreme at t = 3.5 | +1.34 |

- *Cause 1.* The walk's insertion map, `Patch::apply_insertion`, applies an entry's introductions but not its events; only `run_next` applies events (`scm.h`, `apply_event` loop).
- *Cause 2.* After an entry the invader uses the field recorded at the step's end, which is the field before the entry's events.
- *The tangent referee* walks a program through the same map, so it misses events too. With a 50% harvest the run's leaf area is 0.413, and the tangent pass reaches 0.798.
- *The sweep* transposes the map without its events. A resident's sweep agrees with a pinned difference to 2.2e-10 in `k_I` except where a harvest meets an introduction, where it agrees only to 2.0e-6: the run's new cohort takes its inflow after the harvest, and the sweep's map before it.

**The design** (stepper scope, "§2.3, extended", which holds the reasons).
- *A trajectory is a vector of rows, and a row is the only handle on a recorded state.* `step_record.solved` becomes `{stages[5], at_state}`. `at_state` is the evaluation at the row's state: a step's end, the rates after an entry, or the start.
- *Every evaluation at a recorded state is addressed to its row's slot* and repeats the evaluation that wrote it: the same solves, in the same order, at the same time.
  - This covers each step's first rates in the sweep, `be_at_step`, the census seed, the difference reference, and the load before the transposed map.
  - Partial loads go: `set_state_and_boundary`, and `set_recorded_state`, which odelia replaces with `reshape_to` and then an evaluation.
- *The inflow rule (decided):* a cohort introduced at an entry takes the inflow value the patch holds before the entry's events. `apply_event`'s field rebuild goes.
- *One map:* the Patch holds `node_schedule`'s entries, and `apply_insertion(t)` applies an entry's events and then its introductions. `run_next`, the walks and the sweep use it.
- *The field is an input:*
  - a slot that holds one is evaluated in it in every pass;
  - otherwise the evaluation builds its own, and `keep_field` stores it;
  - it is `std::shared_ptr<const recorded_field>`, null for none;
  - the Patch keeps the open slot as `storing` or `loading`.
- *No capability concepts:* declaring `solved_values` is the opt-in, and `SolvesForValues` and `KeepsSolvedChoices` go.
- *One walk over rows* serves the invasion, the tangent referee, the replay from a range and pinned runs. A pinned run walks rows built from the schedule's entries and `Parameters$ode_times`, with a map that also records events and history (Q2, agreed).
- *The invasion:*
  - an SCM is an invasion once `resident_recording` is set, and `run()` then repeats it, so `invade()` and the step-end table go;
  - `run_mutant` builds the invaders' schedule from the resident's events and `p`'s introductions;
  - the recording pass is an ordinary run with `keep_field`.

**Plan, in order.** Plant's first commit builds against odelia `29205f0`; the rest build against odelia's new head.
1. *plant: the inflow rule.* Delete `apply_event`'s rebuild, then measure residents at an entry where a harvest meets an introduction.
2. *odelia: rows.*
   - `solved_row {stages, at_state}`. `derivs` always takes a slot, and `solved_scope` forwards only for a System that declares `solved_values`.
   - One walk (NaN sizes step to their time; an optional insertion map). Delete `program_from` and `state_at_range`.
   - `set_state_from_system` evaluates into the last row's `at_state` at the solver's time, and `push_insertion` comes first.
   - `be_at_step` = `reshape_to` plus that row's evaluation.
   - `step_adjoint` takes the row below. The transposed map is the row below's evaluation followed by `apply_insertion(t)`.
3. *plant: one map, addressed evaluations.*
   - The Patch holds the schedule's entries and `apply_insertion(t)`; `storing`/`loading`; the shared field.
   - The census seed and the difference reference take the final row.
   - Delete the table, `invade()`, `set_state_and_boundary`, `set_recorded_state`, `set_introduction_times`, `KeepsSolvedChoices` and `reset()`'s clears.
   - The invasion lifecycle, the invaders' schedule, and the recording pass unpinned.
4. *plant: pinned runs walk rows.* Delete `program_within`, `NodeSchedule`'s pinned steps and `run_next`'s pinned branch.
5. *Tests and measurements*, landing with the commits they cover.

**Pass.**
- The identical invader is bit for bit exact:
  - with no events;
  - under a pulse, a harvest and a climate extreme;
  - at an entry where a harvest meets an introduction.
- An invader's sweep across a harvest agrees with a pinned difference and with its tangent.
- A resident's sweep across a harvest at an introduction agrees with a pinned difference. It is 2.0e-6 on `de4809fe`.
- FF16's references and resident runs are bit-identical, except at entries where events meet introductions. Resident sweeps are too, or the difference is measured and explained.
- A run pinned by `Parameters$ode_times` is unchanged.
- odelia has tests of the walk and of the addressed evaluations that fail on `29205f0`.

**Traps.**
- *A slot's choices are a sequence.* TF24's leaf points are read in order, so only a full evaluation may read a full evaluation's slot.
- *Two clocks.*
  - A step's end is evaluated at `fl(t + h)`, and a clamped step records the interval's end.
  - After an entry the solver used to read the System's clock.
  - They differed in none of 918 steps over five stands. Derive a step's `at_state` time from the row below, and evaluate after an entry at the recorded time.
- *Placement against search.* A resident's sweep now places its first rates' operating points instead of searching for them. The leaf solve takes its bracket from the state, so the numbers should hold; verify.
- *The recording pass re-runs the resident*, so it must reproduce the first run bit for bit. It does when nothing between the two calls changes the SCM.
- *Pairing.* `offspring-adjoint` and `establishment-window` at their heads need odelia `be3e2cb`.
- *Pre-existing gaps, outside R6:*
  - `lma`'s pinned difference has a floor near 1e-5, on residents too;
  - invaders fail from `lma` x 1.001 with `TF24 storage is negative` (step 2 of the plan).

**Measurements, as runnable code.** Run from `$DEV/stack` with `R_LIBS` set. The first prints the table above, the second the tangent check.

```r
library(odelia); library(plant)
fixture <- function() {
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- 6
  p <- add_strategies(p, trait_matrix(0, "TF24_floor_lambda_o"), hyperpar = TF24_hyperpar, birth_rate = 1)
  full <- p$node_schedule_times[[1]]
  p$node_schedule_times <- list(full[round(seq(1, length(full), length.out = 20))])
  env <- Environment("TF24")
  env$set_soil_water_state(rep(0.428 * 0.5, env$get_soil_number_of_depths()))
  env$extrinsic_drivers_set_constant("rainfall", 1)
  list(p = p, env = env)
}
gap <- function(ev) {
  f <- fixture()
  e <- if (is.null(ev)) events_default(f$p) else events(events_default(f$p), ev)
  scm <- run_scm(f$p, env = f$env, ctrl = Control(), events = e)
  r <- scm$net_reproduction_ratios; scm$run_mutant(f$p); log(scm$net_reproduction_ratios) - log(r)
}
sapply(list(NULL, rainfall_pulse(time = 2.5, depth = 0.05), harvest(time = 3.5, fraction = 0.5),
            climate_extreme(time = 3.5, intensity = 5, threshold = 1, sensitivity = 20)), gap)

source("tests/testthat/helper-gradient-ladder.R")
p <- ladder_parameters("fast"); p$node_schedule_times <- list(c(0, 0.63))
scm <- run_scm(p, Environment("TF24"), ladder_control(),
               events = events(events_default(p), harvest(time = 1, fraction = 0.5)))
n <- length(plant:::census_trait_names_tf24(scm))
rbind(run = stand_census(scm),
      tangent = get("ladder_trajectory_tangent_tf24", asNamespace("plant"))(scm, rep(0, n))$value)
```

## After #95

1. **Rebase `offspring-adjoint` and `PLANT-95` onto #94** (exact counts, `PLANT-93` at `bae2dd9a`, an open PR against the fork's `develop`). The stack's templated code needs #94's birth-date layout in these places:
   - the interval states added to `for_each_active`;
   - `Node::ode_size()` and `ode_names()` made members, with `patch.h`'s `node_type::ode_size()` calls changed to use each node's own;
   - the weights visitor, at the active scalar;
   - the birth-date branches in `compute_competition_and_slope`, `field_splits`, `reduce_competition`, `closes_on`, `consumption_rate`, `census_integral` and `net_reproduction_ratio`;
   - `compute_initial_conditions` and `compute_node_rates` setting the interval rates to zero;
   - `r_get_state` and the yml.
2. **Decide whether #92 is still needed**, by two measurements on `harness/long_drought.R`:
   - `J` at `tol = 1e-3` against `1e-4`;
   - fixed-grid `dJ/dlma` across the three grids #92 used.
3. **Steps 1 and 2 of the plan:** stops as step targets, then the pool's relaxation floor.

The whole plan is `scope-schedule-controller.md` §6:

| step | what | state |
|---|---|---|
| 1 | Stops become step targets (stepper scope §2.1) | not started |
| 2 | The pool's relaxation floor `τ_s` (stepper scope §3, option A) | decided, not implemented |
| 3 | Forward passes store their own rows (stepper scope §2.3) | #95; open for R6 |
| 4 | Exact counts (controller scope §1) | PR #94, open |
| 5–8 | Error maps, schedule controller, tableau stepper, time controller | not started |

## Branches and pointers

- *The stack*, on `aornugent/plant`, is over `develop`'s `95256cf3`:
  - `offspring-adjoint`, #91, ends at `bb1d8a8a`; it is the reverse sweep, with TF24 v11;
  - `establishment-window`, #92, ends at `6613dd24`; TF24 v12 adds the establishment window.
- *`PLANT-95`* is on `offspring-adjoint`. No PR is open for it. Whether to open one against `offspring-adjoint`, or carry it into the rebase, is the user's call.
- *odelia and phylloptim.* The stack links odelia 0.5.0 (`claude/trusting-curie-4i9n3l`) and phylloptim 0.9.0 (`378b083` on `ad/reverse-mode`). Neither is released; upstream has 0.4.0 and 0.8.1.
- *`plant-dev`'s pointers* record plant `6613dd24` and odelia `be3e2cb`, which is a pair that builds. Do not bump the plant pointer until #94 merges, and move odelia's only with it.

## Setup

**1. Session start** (AGENTS.md):
- run `git submodule update --init --recursive`;
- call `add_repo` for `aornugent/odelia`, `aornugent/plant` and `aornugent/phylloptim`.

**2. A private library.** `DEV` is any directory under the scratchpad.

```bash
mkdir -p $DEV/lib_stack
git -C odelia     fetch origin claude/trusting-curie-4i9n3l
git -C odelia     worktree add --detach $DEV/odelia05 origin/claude/trusting-curie-4i9n3l
git -C phylloptim worktree add --detach $DEV/phylloptim09 378b083
git -C plant      fetch origin PLANT-95
git -C plant      worktree add -b PLANT-95 $DEV/stack origin/PLANT-95
export R_LIBS=$DEV/lib_stack MAKEFLAGS=-j4
for pkg in odelia05 phylloptim09 stack; do
  R CMD INSTALL --no-docs --library=$DEV/lib_stack $DEV/$pkg > $DEV/install_$pkg.log 2>&1 || { echo "FAILED $pkg"; break; }
done
```

- *Build times:* odelia takes 26 s and plant 3 min 16 s.
- *After an odelia edit,* reinstall odelia and then plant with `--preclean`. Plant compiles odelia's headers into itself, and the build does not track header dependencies.
- *A new value exposed to R* needs an entry in `inst/RcppR6_classes.yml` and `RcppR6::RcppR6()` in the plant tree, before the rebuild.
- *A base build to compare against:* install `bb1d8a8a` with odelia `be3e2cb` into a second library, in the same way.

**3. Tests**, from `$DEV/stack`, with `R_LIBS` and `TESTTHAT_PARALLEL=false` set:

```r
library(odelia)
testthat::test_file("tests/testthat/test-mutant.R", package = "plant", load_package = "installed")
```

Choose files by AGENTS.md's tiers. odelia's tests run from `$DEV/odelia05`, with `test_dir("tests/testthat", package = "odelia", load_package = "installed")`.

**Baselines on `PLANT-95`:**
- `test-mutant.R`: 28 pass and 2 fail, in 27 s.
- The full serial suite: 4626 pass and the same 2 fail, in 12.5 min.

**Known failures, which predate #95:**
- `test-mutant.R`'s "mutant method works" fails on FF16's ten-mutant panels. They are pinned to `develop`, which replayed invasions by the resident's times.
- odelia's `test-implicit-value.R` has 5 errors: its snippet passes a braced list to a `std::span` parameter, which this compiler refuses.

**Reverse-mode cost.** Timing results are in #95: a resident sweep is 0–4% cheaper after #95, and an invader's sweep is 7–52% cheaper than a resident's.
