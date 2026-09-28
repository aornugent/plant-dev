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

**Open: R6.** At every schedule entry an invader must apply the same events, in the same order, before the same introductions, and its evaluations after an entry must use the field after the entry. The identical invader on `test-mutant.R`'s TF24 fixture, log fitness against the resident's:

| schedule | log gap |
|---|---|
| no events | −7.1e-15 |
| a resource pulse of 0.05 at t = 2.5 | −1.2e-7 |
| a 50% harvest at t = 3.5 | +0.69 |
| a lethal climate extreme at t = 3.5 | +1.34 |

- *Cause 1.* The walk's insertion map, `Patch::apply_insertion`, applies an entry's introductions but not its events; only `run_next` applies events (`scm.h`, `apply_event` loop).
- *Cause 2.* After an entry the invader uses the field recorded at the step's end, which is the field before the entry's events.
- *The tangent referee* walks a program through the same map, so it misses events too. With a 50% harvest the run's leaf area is 0.413, and the tangent pass reaches 0.798.
- *The sweep* transposes the map without its events. That is exact today only because every event shifts the state by an amount the state does not set.

**The design** (stepper scope, "§2.3, extended"). A schedule entry and an insertion row are one thing, a map applied at a scheduled instant, and they were built separately.
- **One insertion map.** The Patch applies the entry at an instant: its events in schedule order, then its introductions. The run, every walk and the sweep use it.
- **One program.** A pinned run walks the schedule's entries as insertion rows, with the pinned steps between them. `program_within` and `run_next`'s pinned branch go.
- **Every evaluation addressed.** A row's last slot is what the evaluation at the state that row holds solved for: a step's end, the first rates after an entry, or a run's first rates. The sweep's first rates and an entry's own evaluation load the row below's last slot. The step-end table (`Patch::step_end_fields`) goes, because with events one instant has two fields.
- **The agreed removals:** one walk over rows of any scalar, no `program_from`, and `Patch::reset()` without its two per-evaluation clears.

**Plan, one commit each, odelia first.**
1. *odelia: one walk.*
   - Merge the two `Solver::advance_recorded` overloads (`ode_solver.hpp`). They now differ only in the seed and in how a row with no size is handled.
   - Walk rows of any System whose solved row has the stepper's type, from a given row. The patch's row type is the same at every scalar.
   - Delete `program_from` (`sweep.hpp`). Plant's `census_trait_tangent` and `replay_initial_state` then walk the recording from row 0 and from `start`.
2. *odelia: address the first rates.*
   - `set_state_from_system` evaluates a `SolvesForValues` System through `derivs`, addressed to the last row's last slot, and a walk seeds it from the recorded row.
   - `step_adjoint`'s first rates and the insertion transpose's evaluation load the row below's last slot.
   - Push the insertion row before `set_state_from_system`: in `run_next` and in the walks.
3. *plant: one insertion map.*
   - The Patch holds the schedule's entries, in place of `set_introduction_times`, and applies the entry at `t`.
   - `apply_insertion` sets the state, then applies the entry. `run_next` applies the entry directly, because its state is already set.
   - `apply_event` must run at the active scalar.
4. *plant: one program.* `NodeSchedule` builds the pinned program: the entries as insertion rows, the pinned steps between them, and a step to each entry's time where no pinned step reaches it. `run()` walks it when pinned. Delete `program_within` and `run_next`'s pinned branch.
5. *plant: delete the step-end table.*
   - Remove `set_step_end_fields`, `step_end_field`, `uses_recorded_fields` and `invade()`'s table build.
   - `store_trajectory()` then needs another way to tell that the last run was an invasion. Choose the smallest, for example one member that `run()` and `invade()` set.
6. *plant:* the two clears in `Patch::reset()`.

**Pass.**
- The identical invader is bit for bit exact with no events, and under a pulse, a harvest and a climate extreme. Before the change these fail as in the table above.
- An invader's sweep across a harvest agrees with a pinned difference and with its tangent.
- FF16's references and resident runs are bit-identical. So are resident sweeps, or the difference is measured and explained.
- A run pinned by `Parameters$ode_times` is unchanged.
- odelia has a test of the merged walk and of the addressed first rates, which fails on `29205f0`.

**Traps found so far.**
- *The pushed node's inflow value.* The run pushes whatever inflow value the last evaluation left:
  - normally the step end's second value;
  - after a harvest or climate extreme, the first value in the post-event field, because the event rebuilds the field;
  - after a pulse, the pre-pulse value, because a pulse rebuilds nothing.

  The one map must reproduce this, not correct it, or residents move.
- *Two times at a step's end.* A step's end evaluation runs at `fl(t + h)`, while the row records the time the run reached. They can differ by one unit in the last place early in a run.
- *Placement against search.* The leaf solve takes its bracket from the state and does not start from its last answer. So placing a recorded point should reproduce the search bit for bit; verify this.
- *The recording pass* re-runs the resident pinned to its own program, so it rejects no step.
- *Pairing.* `offspring-adjoint` and `establishment-window` at their heads need odelia `be3e2cb`. Against `29205f0` their invaders silently use their own field.
- *Pre-existing gaps, outside R6:*
  - `lma`'s pinned difference has a floor near 1e-5, on residents too.
  - Invaders fail from `lma` × 1.001 with `TF24 storage is negative` (step 2 of the plan).

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
