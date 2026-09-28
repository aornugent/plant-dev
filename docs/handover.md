# Handover

**[aornugent/plant#95](https://github.com/aornugent/plant/issues/95) is done: an invader is an exact replay of the recorded run, events included (R6). The next session starts at *After #95*.** Read in this order:
- this page;
- `scope-imex-stepper.md` "§2.3, extended", which holds the design and its result;
- #95, which holds the measurements.

The user's five principles apply: Laziness Protocol, Subtract Before You Add, Minimize Reader Load, Foundational Thinking and Model the Domain. Ask for their text if the session does not include it. AGENTS.md's code style applies to every comment.

## #95, done and pushed

Plant is `15fe136f` on `PLANT-95`, four commits on `offspring-adjoint`; odelia is `a05f5c2` on `claude/trusting-curie-4i9n3l`, two commits on `be3e2cb`.
- plant `de4809fe`: invaders are evaluated in the recorded field and solve for their own leaf operating points, several can invade together, and an invader's recording can be swept.
- plant `5be46742`: a node introduced at an event's instant takes the inflow from before the event.
- plant `e035cfc0`: one map per schedule entry (`Patch::apply_insertion(t)`, its events then its introductions), every evaluation at a recorded state repeating the one its row recorded, the field recorded as the interpolant holds it, and an SCM that is an invasion once `invaded_run` is set.
- plant `15fe136f`: a pinned run is one walk of `NodeSchedule::program()`.
- odelia `29205f0` stores each forward pass's own rows; `a05f5c2` makes rows the only trajectory (`solved_row {stages[5], at_state}`), with one walk and every evaluation addressed.

**Result.** Every pass line of the design holds.
- The identical invader on `test-mutant.R`'s TF24 fixture has the run's fitness bit for bit: with no events, under a pulse, a harvest and a climate extreme, and at an entry where a harvest meets an introduction. Its event log is the run's.
- An invader's sweep across a harvest at an introduction agrees with a difference of invasions to 7e-10, and with its tangent to 1e-15.
- A resident's sweep across a harvest at an introduction agrees with a pinned difference to 1.9e-10 in `k_I`, against 2.0e-6 on `de4809fe`.
- The tangent referee under a harvest reaches the run's census exactly; it used to reach a leaf area of 0.798 against the run's 0.413.
- Resident runs, resident sweeps, FF16's references and pinned runs are bit-identical to `de4809fe`, except at entries where an event meets an introduction.
- Runs, invasion walks and sweeps cost what they did, within 5%.

**Where the build departed from the plan.**
- *A third cause.* The recorded field went through heights, and `u_k·top/top` and `(m/top)·top` can each land an ulp off. TF24's leaf solve amplified one such ulp, in a crown's mean light, to 5e-9 in a log density. The record is now the interpolant's own data: knot values, slopes and the canopy top (`ResourceSpline::knot_data`). TF24's cohort reads use the same pair.
- *Kept:* `NodeSchedule`'s pinned steps and their R interface. The events path installs `p$ode_times` there as a grid and drops the sizes, so moving the steps onto the parameters needs a flag or a change in what such a run does.
- *Refused now:* an invader introduced where the run introduced nothing, which used to be skipped; forward Euler for an invasion, before anything is recorded; a recorded step without a size; and, as before, a System whose clock moved between legs.

**Traps.**
- *A slot's choices are a sequence.* TF24's leaf points are read in order, so only a full evaluation may read a full evaluation's slot.
- *A replayed input must be the one the evaluation read, to every digit.* TF24's leaf solve turns a one-ulp difference anywhere upstream into 1e-9, so a field rebuilt through any arithmetic is a different field.
- *Two clocks.* A step's `at_state` ran at `fl(t + h)` from the row below (`at_state_time`). After an entry the solver keeps the recorded time, and the System's clock must agree with it to 2 ulp.
- *The recording pass re-runs the run*, so it must reproduce the first run bit for bit. It does when nothing between the two calls changes the SCM.
- *Pairing.* `offspring-adjoint` and `establishment-window` at their heads need odelia `be3e2cb`, and `PLANT-95` needs `a05f5c2`; neither builds against the other's odelia.
- *Pre-existing gaps, outside R6:*
  - `lma`'s pinned difference has a floor near 1e-5, on residents too;
  - invaders fail from `lma` x 1.001 with `TF24 storage is negative`, and run at x 1.0001, 0.99 and 0.95 (step 2 of the plan).

**Measurements, as runnable code.** Run from `$DEV/stack` with `R_LIBS` set. The first prints `TRUE` for each schedule, the second the tangent check.

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
exact <- function(ev) {
  f <- fixture()
  e <- if (is.null(ev)) events_default(f$p) else events(events_default(f$p), ev)
  scm <- run_scm(f$p, env = f$env, ctrl = Control(), events = e)
  r <- scm$net_reproduction_ratios; scm$run_mutant(f$p); identical(scm$net_reproduction_ratios, r)
}
at_intro <- fixture()$p$node_schedule_times[[1]][19]
sapply(list(NULL, rainfall_pulse(time = 2.5, depth = 0.05), harvest(time = 3.5, fraction = 0.5),
            climate_extreme(time = 3.5, intensity = 5, threshold = 1, sensitivity = 20),
            harvest(time = at_intro, fraction = 0.5)), exact)

source("tests/testthat/helper-gradient-ladder.R")
p <- ladder_parameters("fast"); p$node_schedule_times <- list(c(0, 0.63))
scm <- run_scm(p, Environment("TF24"), ladder_control(),
               events = events(events_default(p), harvest(time = 1, fraction = 0.5)))
n <- length(plant:::census_trait_names_tf24(scm))
rbind(run = stand_census(scm),
      tangent = get("ladder_trajectory_tangent_tf24", asNamespace("plant"))(scm, rep(0, n))$value)
```

## After #95

1. **Rebase `offspring-adjoint` and `PLANT-95` (four commits) onto #94** (exact counts, `PLANT-93` at `bae2dd9a`, an open PR against the fork's `develop`). The stack's templated code needs #94's birth-date layout in these places:
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
| 3 | Forward passes store their own rows (stepper scope §2.3) | #95, done, R6 included |
| 4 | Exact counts (controller scope §1) | PR #94, open |
| 5–8 | Error maps, schedule controller, tableau stepper, time controller | not started |

## Branches and pointers

- *The stack*, on `aornugent/plant`, is over `develop`'s `95256cf3`:
  - `offspring-adjoint`, #91, ends at `bb1d8a8a`; it is the reverse sweep, with TF24 v11;
  - `establishment-window`, #92, ends at `6613dd24`; TF24 v12 adds the establishment window.
- *`PLANT-95`* ends at `15fe136f`, four commits on `offspring-adjoint`. No PR is open for it. Whether to open one against `offspring-adjoint`, or carry it into the rebase, is the user's call.
- *odelia and phylloptim.* `PLANT-95` links odelia 0.5.0 (`a05f5c2` on `claude/trusting-curie-4i9n3l`) and phylloptim 0.9.0 (`378b083` on `ad/reverse-mode`). Neither is released; upstream has 0.4.0 and 0.8.1.
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
- `test-mutant.R`: 40 pass and 2 fail, in 21 s.
- The full serial suite: 4642 pass and the same 2 fail, with no errors and 9 skipped, in 8.9 min.
- odelia's suite: 325 pass, and `test-implicit-value.R`'s 5 errors.

**Known failures, which predate #95:**
- `test-mutant.R`'s "mutant method works" fails on FF16's ten-mutant panels. They are pinned to `develop`, which replayed invasions by the resident's times.
- odelia's `test-implicit-value.R` has 5 errors: its snippet passes a braced list to a `std::span` parameter, which this compiler refuses.

**Reverse-mode cost.** Timing results are in #95: a resident sweep is 0–4% cheaper after #95, and an invader's sweep is 7–52% cheaper than a resident's. R6 leaves runs, invasion walks and sweeps within 5% of that.
