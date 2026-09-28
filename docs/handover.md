# Handover

**Next, in order: rebase the stack onto #94, then steps 1 and 2 of the plan.** [aornugent/plant#95](https://github.com/aornugent/plant/issues/95) is done: an invader is an exact replay of the recorded run, events included. #95 holds its measurements, and `scope-imex-stepper.md` "§2.3, extended" its design.

The user's five principles apply: Laziness Protocol, Subtract Before You Add, Minimize Reader Load, Foundational Thinking and Model the Domain. Ask for their text if the session does not include it. AGENTS.md's code style applies to every comment.

## Branches

On `aornugent/plant`, over `develop`'s `95256cf3`:

| branch | head | what | on | odelia |
|---|---|---|---|---|
| `PLANT-93` (PR #94, open) | `bae2dd9a` | exact counts; 1 commit | `develop` | `be3e2cb` |
| `offspring-adjoint` (#91) | `bb1d8a8a` | the reverse sweep, TF24 v11; 13 commits | `develop` | `be3e2cb` |
| `PLANT-95` (#95) | `15fe136f` | exact invader replay; 4 commits | `offspring-adjoint` | `a05f5c2` |
| `establishment-window` (#92) | `6613dd24` | TF24 v12's establishment window; 2 commits | `offspring-adjoint` | `be3e2cb` |

- odelia 0.5.0 is `claude/trusting-curie-4i9n3l`, and phylloptim 0.9.0 is `378b083` on `ad/reverse-mode`. Neither is released; upstream has 0.4.0 and 0.8.1.
- A branch builds only against its own odelia: `a05f5c2` removed what `be3e2cb`'s callers use.
- No PR is open for `PLANT-95`. Whether to open one against `offspring-adjoint`, or carry it into the rebase, is the user's call.
- `plant-dev`'s pointers record plant `6613dd24` and odelia `be3e2cb`. Do not bump plant's until #94 merges, and move odelia's only with it.

## 1. Rebase onto #94

`git rebase --update-refs --onto origin/PLANT-93 origin/develop PLANT-95` moves `offspring-adjoint`'s 13 commits and `PLANT-95`'s 4 onto #94. Then force-push each moved branch with `--force-with-lease`.
- *Where both sides change:* `node.h`, `patch.h`, `scm.h`, `species.h`, `inst/RcppR6_classes.yml`, `NEWS.md`, `test-density-coordinate.R` and `test-node.R`. Regenerate `R/RcppR6.R`, `src/RcppR6.cpp` and the RcppExports rather than merging them.
- *Where the stack's templated code needs #94's birth-date layout:*
  - the interval states added to `for_each_active`;
  - `Node::ode_size()` and `ode_names()` made members, with `patch.h`'s `node_type::ode_size()` calls changed to use each node's own;
  - the weights visitor, at the active scalar;
  - the birth-date branches in `compute_competition_and_slope`, `field_splits`, `reduce_competition`, `closes_on`, `consumption_rate`, `census_integral` and `net_reproduction_ratio`;
  - `compute_initial_conditions` and `compute_node_rates` setting the interval rates to zero;
  - `r_get_state` and the yml.
- *#92 moves only if it is still needed.* Two measurements on `harness/long_drought.R` decide it: `J` at `tol = 1e-3` against `1e-4`, and fixed-grid `dJ/dlma` across the three grids #92 used.
- *Pass.* #94 moves results on the birth-date coordinate, so the stack's numbers there move with it. What must not move:
  - the identities: the check below prints five `TRUE`s, then one more;
  - each sweep's agreement with its pinned difference, at the tolerances its tests use;
  - FF16's references, which are on the height coordinate;
  - the full serial suite, at the baselines under *Setup*.

```r
# From $DEV/stack, with R_LIBS set: the identical invader under each schedule, then
# the tangent referee under a harvest.
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
identical(unname(stand_census(scm)),
          unname(get("ladder_trajectory_tangent_tf24", asNamespace("plant"))(scm, rep(0, n))$value))
```

## 2. Step 1: stops become step targets

Stepper scope §2.1. A stop is an entry that introduces nothing and changes nothing, such as the zero-size pulses at a forcing's 2931 active knots.
- *Today* each entry is one map (`Patch::apply_insertion`), an insertion row (`push_insertion`) and one full evaluation (`set_state_from_system`). #95 removed the second evaluation §2.1 counts, the one in `introduce_nodes`.
- *A stop needs none of the three.* It becomes a time `advance_adaptive` lands on, which carries the rates and the step proposal across it.
- *Saves* one evaluation per stop, and a sweep range per stop, each with its own rebind and transposed identity map.
- *Pass:* `J`, the step sequence and the gradient unchanged to round-off, because a rate evaluation is a function of `(y, t)` alone.
- ⚠️ *A walk consumes the schedule entry by entry.* `SCM::apply_entry` checks each insertion row against `node_schedule.next()`, and `NodeSchedule::program()` makes an insertion row for every entry. A stop that stops being an insertion must leave both, or every walk refuses at the next entry.

## 3. Step 2: the pool's relaxation floor

Stepper scope §3, option A, decided. Floor the storage pool's relaxation time at `τ_s`, as the establishment window floors the gate's.
- *The rate* becomes `Ṡ = [c(1 − r) − d·r] / (1 + λ·τ_s)`, with `τ_s` = 7 days: about five lines in `TF24_Strategy::compute_rates`, and one parameter.
- *It is a declared model change.* Measure its effect on `J` and `dJ/dθ`, as the window's was (+1.26% in `J`).
- *It should let today's failing invaders run.* From `lma` × 1.001 they fail with `TF24 storage is negative`, and they run at × 1.0001, 0.99 and 0.95.
- Option B, implicit pools, stays on file in case A moves `J` by more than is acceptable.

The whole plan is `scope-schedule-controller.md` §6:

| step | what | state |
|---|---|---|
| 1 | Stops become step targets (stepper scope §2.1) | next, after the rebase |
| 2 | The pool's relaxation floor `τ_s` (stepper scope §3, option A) | decided, not implemented |
| 3 | Forward passes store their own rows (stepper scope §2.3) | done, #95 |
| 4 | Exact counts (controller scope §1) | PR #94, open |
| 5–8 | Error maps, schedule controller, tableau stepper, time controller | not started |

## Traps

- *A slot's choices are a sequence.* TF24's leaf points are read in order, so only a full evaluation may read a full evaluation's slot.
- *A replayed input must be the one the evaluation read, to every digit.* TF24's leaf solve turns a one-ulp difference anywhere upstream into 1e-9, so a field rebuilt through any arithmetic is a different field.
- *Two clocks.* A step's `at_state` ran at `fl(t + h)` from the row below (`at_state_time`). After an entry the solver keeps the recorded time, and the System's clock must agree with it to 2 ulp.
- *An invasion's recording pass re-runs the run*, so it must reproduce the first run bit for bit. It does when nothing between the two calls changes the SCM.
- *`lma`'s pinned difference has a floor near 1e-5*, on residents too.

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

- *Build times:* odelia takes 26 s and plant about 3 min.
- *After an odelia edit,* reinstall odelia and then plant with `--preclean`. Plant compiles odelia's headers into itself, and the build does not track header dependencies.
- *A new value exposed to R* needs an entry in `inst/RcppR6_classes.yml` and `RcppR6::RcppR6()` in the plant tree, before the rebuild.
- *A base to compare against:* before rebasing, install `15fe136f` with odelia `a05f5c2` into a second library, in the same way.

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
