# Handover

**Steps 1 and 2 of the plan are done**, as [#96](https://github.com/aornugent/plant/issues/96) and [#97](https://github.com/aornugent/plant/issues/97), side by side on [#95](https://github.com/aornugent/plant/issues/95). #95, exact invader replay, is done, and the stack is rebased onto #94. #95's design is `scope-imex-stepper.md` "§2.3, extended".

**Next, the user's call:** whether step 2's move in `J` and `dJ/dlma` stands (below), and then step 5 of the plan.

The user's five principles apply (Laziness Protocol, Subtract Before You Add, Minimize Reader Load, Foundational Thinking, Model the Domain); ask for their text if the session lacks it. AGENTS.md's code style applies to every comment.

## Branches

On `aornugent/plant`, over `develop`'s `95256cf3`:

| branch | head | what | on | odelia |
|---|---|---|---|---|
| `PLANT-93` (PR #94, open) | `bae2dd9a` | exact counts; 1 commit | `develop` | `be3e2cb` |
| `offspring-adjoint` (#91) | `5a37615e` | the reverse sweep, TF24 v11; 14 commits | `PLANT-93` | `be3e2cb` |
| `PLANT-95` (#95) | `25e21a70` | exact invader replay; 5 commits | `offspring-adjoint` | `a05f5c2` |
| `PLANT-96` (#96) | `33bb06bc` | stops as step targets; 1 commit | `PLANT-95` | `a05f5c2` |
| `PLANT-97` (#97) | `994d7aff` | the pool's relaxation floor, TF24 v12; 1 commit | `PLANT-95` | `a05f5c2` |

- odelia 0.5.0 is `claude/trusting-curie-4i9n3l` and phylloptim 0.9.0 is `378b083`, both unreleased. A branch builds only against its own odelia.
- No PR is open for `offspring-adjoint`, `PLANT-95`, `PLANT-96` or `PLANT-97`; opening them is the user's call. #96 and #97 are independent, and both edit the top of `NEWS.md`.
- `plant-dev`'s pointers (plant `6613dd24`, odelia `be3e2cb`) stay until #94 merges; odelia's moves with plant's.

**The rebase onto #94 is done.** The heads before it were `bb1d8a8a` and `cb9d4f2b`.
- #94 is ported into the templated model in `61af9238`, and `5a37615e` follows it through the suite: `make_initial_state()` takes birth dates, the fixtures seat a density through survival, the references form the weights, and the whole-run reference is recaptured.
- On the birth-date coordinate a node's density is its birth rate times its survival, and its weight comes from the interval states. So the boundary node reaches the census only through the newest interval's moment, and the field reaches recruitment through the carbon a recruit makes.
- The height coordinate is bit-identical across the rebase. FF16's birth-date offspring production moved 17.1720 → 17.1406, as #94 moves develop's.

**Step 1, stops as step targets, is done** as #96 (stepper scope §2.1, *Result*).
- `NodeSchedule` keeps apart, as a stop, an entry that introduces nothing and whose every action is a pulse of zero amount. `SCM::advance_to` lands on the stops.
- On the TF24 fixture with 500 stops, `J`, the steps and the gradient are bit-identical. Evaluations fall 3705 → 3205 and a sweep's time by half.

**Step 2, the pool's relaxation floor, is done** as #97 (stepper scope §3, *Result*).
- `storage_relaxation_floor`, 7 days, is added to the pool's own relaxation time. TF24 is v12, and a floor of zero is v11 bit for bit.
- On the long-drought stand `J` moves +2.0 / +2.6 / +2.7% at 108 / 215 / 429 nodes, and `dJ/dlma` moves −168.56 → −195.99. Both adjoints match pinned differences.
- The table's invaders run. Throws fall 759 → 149 but not to zero, because positivity binds before stability: Cash–Karp's fourth stage takes a draining pool below empty past `h = 2.16T`, 15 days at the floor.
- ⚠️ *Open for the user:* whether these moves stand, or option B (implicit pools) replaces A, as the plan allowed if A moved `J` too far.

The plan is `scope-schedule-controller.md` §6:

| step | what | state |
|---|---|---|
| 1 | Stops become step targets (stepper §2.1) | done, #96 |
| 2 | The pool's relaxation floor (stepper §3, option A) | done, #97; its moves await the user |
| 3 | Forward passes store their own rows (stepper §2.3) | done, #95 |
| 4 | Exact counts (controller §1) | PR #94, open; the stack is on it |
| 5–8 | Error maps, schedule controller, tableau stepper, time controller | not started |

## Traps

- *A slot's choices are a sequence:* TF24's leaf points are read in order, so only a full evaluation may read a full evaluation's slot.
- *A replayed input must be exact:* TF24's leaf solve turns a one-ulp difference upstream into 1e-9.
- *Two clocks:* a step's `at_state` ran at `fl(t + h)` from the row below (`at_state_time`); after an entry the solver keeps the recorded time, and the System's clock must agree to 2 ulp.
- *An invasion's recording pass re-runs the run*, and reproduces it only while nothing between the two calls changes the SCM.
- *`lma`'s pinned difference has a floor near 1e-5*, on residents too.
- *Positivity binds before stability for an explicit pool:* a step between 2.16 and 3.73 of a pool's relaxation time is stable, and its fourth stage is below empty.
- *A TF24 run at the default tolerance carries its own time error*, about 0.1% on the five-year stands, where the floor lengthens its steps. Compare against a run integrated to 1e-6, as TF24f's convergence test does.
- *A stop is not an entry:* `entries()`, `size`, the walks and `event_log` never see it. `get_events()` returns it, and `program()` adds it to a grid only.
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
- `offspring-adjoint` builds the same way, into a second library, against odelia `be3e2cb`. `PLANT-96` and `PLANT-97` build as `PLANT-95` does.

**Tests** run from `$DEV/stack` with `TESTTHAT_PARALLEL=false`, by AGENTS.md's tiers: `testthat::test_file("tests/testthat/test-mutant.R", package = "plant", load_package = "installed")` after `library(odelia)`. odelia's run from `$DEV/odelia05` with `test_dir("tests/testthat", package = "odelia", load_package = "installed")`.

**Baselines on `PLANT-95`:** `test-mutant.R` 41 pass and 2 fail; the full serial suite 4651 pass and the same 2 fail, in 9.1 min; odelia 325 pass. On `PLANT-96` the suite passes 4661 and fails the same 2, and on `PLANT-97` the same, in 6.8 min. On `offspring-adjoint` the suite passes 4628 and fails the same 2, in 9.5 min.

**Known failures, older than #95:**
- `test-mutant.R`'s "mutant method works" fails on FF16's ten-mutant panels, which are pinned to `develop`.
- odelia's `test-implicit-value.R` has 5 errors: its snippet passes a braced list to a `std::span` parameter, which this compiler refuses.
