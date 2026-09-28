# Handover

**Next, in order: steps 1 and 2 of the plan.** [#95](https://github.com/aornugent/plant/issues/95), exact invader replay, is done, and the stack is rebased onto #94; #95's design is `scope-imex-stepper.md` "§2.3, extended".

The user's five principles apply (Laziness Protocol, Subtract Before You Add, Minimize Reader Load, Foundational Thinking, Model the Domain); ask for their text if the session lacks it. AGENTS.md's code style applies to every comment.

## Branches

On `aornugent/plant`, over `develop`'s `95256cf3`:

| branch | head | what | on | odelia |
|---|---|---|---|---|
| `PLANT-93` (PR #94, open) | `bae2dd9a` | exact counts; 1 commit | `develop` | `be3e2cb` |
| `offspring-adjoint` (#91) | `5a37615e` | the reverse sweep, TF24 v11; 14 commits | `PLANT-93` | `be3e2cb` |
| `PLANT-95` (#95) | `25e21a70` | exact invader replay; 5 commits | `offspring-adjoint` | `a05f5c2` |

- odelia 0.5.0 is `claude/trusting-curie-4i9n3l` and phylloptim 0.9.0 is `378b083`, both unreleased. A branch builds only against its own odelia.
- No PR is open for `offspring-adjoint` or `PLANT-95`; opening them is the user's call.
- `plant-dev`'s pointers (plant `6613dd24`, odelia `be3e2cb`) stay until #94 merges; odelia's moves with plant's.

**The rebase onto #94 is done.** The heads before it were `bb1d8a8a` and `cb9d4f2b`.
- #94 is ported into the templated model in `61af9238`, and `5a37615e` follows it through the suite: `make_initial_state()` takes birth dates, the fixtures seat a density through survival, the references form the weights, and the whole-run reference is recaptured.
- On the birth-date coordinate a node's density is its birth rate times its survival, and its weight comes from the interval states. So the boundary node reaches the census only through the newest interval's moment, and the field reaches recruitment through the carbon a recruit makes.
- The height coordinate is bit-identical across the rebase. FF16's birth-date offspring production moved 17.1720 → 17.1406, as #94 moves develop's.

## 1. Step 1: stops become step targets

Stepper scope §2.1. A stop is an entry that introduces and changes nothing, such as a zero-size pulse at each of a forcing's 2931 active knots.
- Each entry costs a map (`Patch::apply_insertion`), an insertion row and a full evaluation (`set_state_from_system`); #95 removed the evaluation in `introduce_nodes`. A stop needs none of the three: it becomes a time `advance_adaptive` lands on.
- Saves an evaluation and a sweep range per stop. *Pass:* `J`, the step sequence and the gradient unchanged to round-off.
- ⚠️ *Walks consume the schedule entry by entry.* `SCM::apply_entry` checks each insertion row against `node_schedule.next()`, and `NodeSchedule::program()` makes a row per entry, so a stop must leave both.

## 2. Step 2: the pool's relaxation floor

Stepper scope §3, option A, decided: `Ṡ = [c(1 − r) − d·r] / (1 + λ·τ_s)` with `τ_s` = 7 days, about five lines in `TF24_Strategy::compute_rates` and one parameter.
- A declared model change: measure `J` and `dJ/dθ`, as the establishment window's was (+1.26% in `J`).
- It should let invaders from `lma` × 1.001 run; they fail today with `TF24 storage is negative`.
- Option B, implicit pools, stays on file if A moves `J` too far.

The plan is `scope-schedule-controller.md` §6:

| step | what | state |
|---|---|---|
| 1 | Stops become step targets (stepper §2.1) | next |
| 2 | The pool's relaxation floor (stepper §3, option A) | decided |
| 3 | Forward passes store their own rows (stepper §2.3) | done, #95 |
| 4 | Exact counts (controller §1) | PR #94, open; the stack is on it |
| 5–8 | Error maps, schedule controller, tableau stepper, time controller | not started |

## Traps

- *A slot's choices are a sequence:* TF24's leaf points are read in order, so only a full evaluation may read a full evaluation's slot.
- *A replayed input must be exact:* TF24's leaf solve turns a one-ulp difference upstream into 1e-9.
- *Two clocks:* a step's `at_state` ran at `fl(t + h)` from the row below (`at_state_time`); after an entry the solver keeps the recorded time, and the System's clock must agree to 2 ulp.
- *An invasion's recording pass re-runs the run*, and reproduces it only while nothing between the two calls changes the SCM.
- *`lma`'s pinned difference has a floor near 1e-5*, on residents too.
- *A lambda returning an active product needs `-> value_type`:* a deduced return type hands back an expression template over dead operands, and the value comes out right while the derivative reads freed memory.

## Setup

**Session start** (AGENTS.md): `git submodule update --init --recursive`, and `add_repo` for `aornugent/odelia`, `aornugent/plant` and `aornugent/phylloptim`.

**A private library**, with `DEV` under the scratchpad:

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

- odelia builds in 26 s and plant in about 3 min. After an odelia edit, reinstall plant with `--preclean`: it compiles odelia's headers and does not track them.
- A new value exposed to R needs an entry in `inst/RcppR6_classes.yml` and `RcppR6::RcppR6()` before the rebuild.
- `offspring-adjoint` builds the same way, into a second library, against odelia `be3e2cb`.

**Tests** run from `$DEV/stack` with `TESTTHAT_PARALLEL=false`, by AGENTS.md's tiers: `testthat::test_file("tests/testthat/test-mutant.R", package = "plant", load_package = "installed")` after `library(odelia)`. odelia's run from `$DEV/odelia05` with `test_dir("tests/testthat", package = "odelia", load_package = "installed")`.

**Baselines on `PLANT-95`:** `test-mutant.R` 41 pass and 2 fail; the full serial suite 4651 pass and the same 2 fail, in 9.1 min; odelia 325 pass. On `offspring-adjoint` the suite passes 4628 and fails the same 2, in 9.5 min.

**Known failures, older than #95:**
- `test-mutant.R`'s "mutant method works" fails on FF16's ten-mutant panels, which are pinned to `develop`.
- odelia's `test-implicit-value.R` has 5 errors: its snippet passes a braced list to a `std::span` parameter, which this compiler refuses.
