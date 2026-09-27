# Handover

For the solver plan in `scope-schedule-controller.md` §6. Its step 3, [aornugent/plant#95](https://github.com/aornugent/plant/issues/95), is implemented and pushed; **Progress** at the end records it. Read in this order:
- this page, for the plan's state, the branches and the setup;
- `scope-imex-stepper.md` §1 and §2.3, the design of step 3;
- #95 itself, for its results.

The consult and its answer (`oracle-*.md`) are background for steps 5–8.

## The plan and where each step stands

| step | what | state |
|---|---|---|
| 1 | Stops become step targets (stepper scope §2.1) | not started |
| 2 | The pool's relaxation floor `τ_s` (stepper scope §3, option A) | decided, not implemented |
| 3 | Forward passes store their own rows; only the sweep loads (stepper scope §2.3) | **done, #95**: `PLANT-95` and odelia `29205f0`, no PR |
| 4 | Exact counts (controller scope §1) | [#94](https://github.com/aornugent/plant/pull/94), open against the fork's `develop` |
| 5 | The two error maps (controller scope §2) | not started |
| 6 | The schedule controller (controller scope §3) | not started |
| 7 | The tableau stepper, ARK and the stiff block (stepper scope §4–5) | not started |
| 8 | The time controller | not started |

Step 4 was taken out of order because it can land on `develop` without the stack.

## The branches

**The stack**, on `aornugent/plant`, over `develop`'s `95256cf3`:
- `offspring-adjoint`, #91, is 13 commits and ends at `bb1d8a8a`. It is the reverse sweep, with TF24 at v11, which includes the fixes from `ad/V4-reverse-tf24`.
- `establishment-window`, #92, adds 2 commits and ends at `6613dd24`. It averages TF24's establishment gate over a declared window (TF24 v12).
- It links odelia 0.5.0, which is `be3e2cb` on odelia's `claude/trusting-curie-4i9n3l`, and phylloptim 0.9.0, which is `378b083` on `ad/reverse-mode`. Neither is released: upstream has odelia v0.4.0 and phylloptim v0.8.1.

**Step 3:**
- plant: `PLANT-95` at `de4809fe`, one commit on `offspring-adjoint`. It does not need #92's window.
- odelia: `29205f0`, one commit on `claude/trusting-curie-4i9n3l`, the 0.5.0 branch.

**⚠️ The two must be built together.** `offspring-adjoint` and `establishment-window` at their heads need odelia `be3e2cb`. Built against `29205f0`, their invaders silently use their own field, because their Patch ignores the field in a row it stores into. `PLANT-95` needs `29205f0` or later.

**Exact counts:** `PLANT-93` at `bae2dd9a`, off `develop`, which is PR #94.

**`plant-dev` records `plant` at `6613dd24`**, the stack's head, and odelia at `be3e2cb`, which is a pair that builds. Do not bump the plant pointer until #94 merges, and move odelia's only with it.

## Next, in order

1. **Rebase `offspring-adjoint` and `PLANT-95` onto #94.** The stack's templated code needs the birth-date layout of #94 applied in these places:
   - the interval states added to `for_each_active`;
   - `Node::ode_size()` and `ode_names()` made members, and `patch.h`'s `node_type::ode_size()` calls (about lines 1657 and 1732) changed to use each node's own;
   - the weights visitor, at the active scalar;
   - the birth-date branches in `compute_competition_and_slope`, `field_splits`, `reduce_competition`, `closes_on`, `consumption_rate`, `census_integral` and `net_reproduction_ratio`;
   - `compute_initial_conditions` and `compute_node_rates` setting the interval rates to zero;
   - `r_get_state` and the yml.
2. **Decide whether #92 is still needed, by two measurements on `harness/long_drought.R`:**
   - `J` at `tol = 1e-3` against `1e-4`;
   - fixed-grid `dJ/dlma` across the three grids #92 used.
3. **Steps 1 and 2.** Stops as step targets; then the pool's relaxation floor, which is what still stops TF24 invaders from `lma` × 1.001 up (#95).

## Setup

A new container has none of this, so it is all written as commands.

**1. Session start** (AGENTS.md):
- run `git submodule update --init --recursive`;
- call `add_repo` for `aornugent/odelia`, `aornugent/plant` and `aornugent/phylloptim`.

**2. A private library for the stack.** The stack needs odelia 0.5.0 and phylloptim 0.9.0 built together, so build all three into a private library from worktrees. `DEV` is any directory under the scratchpad.

```bash
mkdir -p $DEV/lib_stack
git -C odelia     fetch origin claude/trusting-curie-4i9n3l
git -C odelia     worktree add --detach $DEV/odelia05 origin/claude/trusting-curie-4i9n3l
git -C phylloptim worktree add --detach $DEV/phylloptim09 378b083
git -C plant      fetch origin PLANT-95
git -C plant      worktree add -b PLANT-95 $DEV/stack origin/PLANT-95
export R_LIBS=$DEV/lib_stack MAKEFLAGS=-j3
for pkg in odelia05 phylloptim09 stack; do
  R CMD INSTALL --no-docs --library=$DEV/lib_stack $DEV/$pkg > $DEV/install_$pkg.log 2>&1 || { echo "FAILED $pkg"; break; }
done
```

- *Measured September 2026:* odelia 26 s, plant 3 min 16 s at `-j4`, with no compiler warnings.
- *Building `offspring-adjoint` or `establishment-window` at their heads* needs odelia `be3e2cb` in place of the branch head (see The branches).
- *Rebuilding plant after a C++ edit.* Add `--preclean`. The build does not track header dependencies, so without it an edit to a header links objects built against two versions of the same templates.
- *After an odelia edit,* reinstall odelia and then plant with `--preclean`: plant compiles odelia's headers into itself.
- *Exposing a new value to R* means an entry in `inst/RcppR6_classes.yml`, then `RcppR6::RcppR6()` in the plant tree, before the rebuild.

**3. Tests against the installed build.** Run from `$DEV/stack`, with `R_LIBS` and `TESTTHAT_PARALLEL=false` set:

```r
library(odelia)
testthat::test_file("tests/testthat/test-mutant.R", package = "plant",
                    load_package = "installed")
```

Choose files by the tiers in AGENTS.md. odelia's own tests run from `$DEV/odelia05` with `testthat::test_dir("tests/testthat", package = "odelia", load_package = "installed")`.

**Known failures, on the base and on `PLANT-95` alike:**
- *`test-mutant.R`*: 2 fail, both in "mutant method works", on FF16's ten-mutant invasions (for example 2.83187 against an expected 2.83174). The expected values were measured on `develop`, which pinned an invasion to the resident's times; the stack pins it to the resident's step sizes. #92's full-suite count names the same two.
- *odelia's `test-implicit-value.R`*: 5 errors. Its snippet passes a braced list to a `std::span` parameter, which this compiler refuses.

On `PLANT-95` the full serial suite has 4626 passes and those 2 failures, in 12.5 min; `test-mutant.R` alone has 28 passes, in 27 s.

**4. The fixture.** `harness/long_drought.R` in this repo is the lifetime-40 long-drought TF24 stand from #92. It generates its own record and knots and calls only exported functions, so it runs on `develop` and on the stack.
- *Loading plant.* Set `PLANT_LIB` to the private library to use the installed build. `PLANT_DIR` loads a source tree through `load_all` instead.
- *Running it.* `run_J(uniform_times(n))` returns `J`, the step count and the seconds.
- *Holding the time grid across a ladder.* Pass every rung the finest rung's creation times as `stops`.

## Exact counts (#94)

The PR is one commit, `bae2dd9a`. Its body and first comment hold the design, the demonstration and the measurements, and #93 is the problem statement written for upstream. It is waiting on review; after it merges, the user propagates it upstream and the stack rebases (Next, 2).

## Progress

**Step 3 (#95) is done**, as designed in stepper scope §2.3: plant `de4809fe` on `PLANT-95`, and odelia `29205f0`. #95 holds the results; in short:
- *The identical invader* still recovers the resident's fitness, to −7.1e-15 in log.
- *A resident and a mutant together run.* The mutant has exactly the fitness it has invading alone.
- *An invader's sweep agrees with a pinned difference of its census,* to 1e-10 for `hmat` and `k_I`, as a resident's does. `lma` has a floor near 1e-5, on residents too.
- *Residents, resident sweeps and FF16 invasions* are bit-identical to the base.
- *The pool overshoot* (stepper scope §1, (b)) now starts at `lma` × 1.001 rather than × 1.0001.
- *Limits:* an evaluation between recorded instants raises an error, so `census_trait_tangent` refuses an invaded SCM.

No PR is open for it. Stacked on #91, it would go against `offspring-adjoint`; the user decides whether to open one or to carry it into the rebase (Next, 1).
