# Handover

**Next session, in order: a code review, a clean-up, then the design of the stepper**, steps 4–6 of `scope-imex-stepper.md` §7: the R-driven prototype of the soil ARK, odelia's tableau stepper and stiff block, and TF24's wiring.

Steps 1–3 of the plan are done: [#96](https://github.com/aornugent/plant/issues/96), [#97](https://github.com/aornugent/plant/issues/97) and [#95](https://github.com/aornugent/plant/issues/95), all rebased onto #94. #97's model change is accepted.

The user's five principles apply (Laziness Protocol, Subtract Before You Add, Minimize Reader Load, Foundational Thinking, Model the Domain). Their text is not in the repo; ask for it if the session lacks it. AGENTS.md's code style applies to every comment.

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

## Done last session

- **The rebase onto #94.** The height coordinate is bit-identical across it. On the birth-date coordinate a node's density is its birth rate times its survival, and the boundary node reaches the census only through the newest interval's moment.
- **Step 1, stops as step targets** (#96; stepper scope §2.1, *Result*). `J`, the steps and the gradient are bit-identical, and a sweep takes half the time.
- **Step 2, the pool's relaxation floor** (#97; stepper scope §3, *Result*). TF24 is v12.
  - `J` moves +2.7% on the long-drought stand and `dJ/dlma` +16%, and both are accepted.
  - Throws fall 759 → 149. They are improved, not eliminated.
- **Option B**, implicit pools, is not pursued: its stages go negative past `hλ` = 3.1, which fixes neither invaders nor throws (stepper scope §3).
- **Invaders with the storage pool** (stepper scope §3, *What invaders need beyond A*).
  - Selection gradients work: the identical invader is exact, and near neighbours run.
  - Capping the resident's step widens the range: at 3.5 days, `lma` × 0.8 to × 1.5 run on the long-drought stand, at 18% more steps.
  - Every invader would need a pool update that is non-negative at any step, which is a question for the stepper design.

## Next session

**1. Code review.** Review each branch's own diff over its base, in stack order, so that findings map to one issue each:

| diff | commits | size, excluding generated bindings and the reference |
|---|---|---|
| odelia `claude/trusting-curie-4i9n3l` over `master` | 12 | +9.2k / −3.0k in 71 files |
| `PLANT-93` over `develop` (PR #94) | 1 | +0.5k / −0.3k |
| `offspring-adjoint` over `PLANT-93` | 14 | +18.1k / −5.1k in 139 files |
| `PLANT-95` over `offspring-adjoint` | 5 | +0.6k / −0.6k |
| `PLANT-96` and `PLANT-97` over `PLANT-95` | 1 each | +0.1k each |

- Use plant-dev's `code-review` skill, against the five principles and AGENTS.md's style. `PLANT-95` was reviewed against the principles before the R6 work; `offspring-adjoint` and odelia's branch are the bulk.
- Fix each finding in the branch that owns it. Then `git rebase --update-refs` and push every moved branch with `--force-with-lease`.

**2. Clean up.** Candidates found so far:
- odelia's `test-implicit-value.R` has 5 errors: its snippet passes a braced list to a `std::span` parameter, which this compiler refuses.
- `test-mutant.R`'s "mutant method works" fails on FF16's ten-mutant panels, which are pinned to `develop`.
- `TF24_Strategy::assign_from` copies `storage_gate_width` and `storage_prod_eps` but not `storage_domain_tol` (`tf24_strategy.h:1208`).
- Test comments that record history or stale numbers:
  - "offspring arrival" in `test-strategy-tf24.R`;
  - the seeded-baseline narrative in `test-stochastic-patch-runner.R`;
  - the `k_acclim` offspring table in `test-strategy-tf24f.R`.

  TF24's `scientific_version` log is history by design; whether it stays is the user's call.
- `NodeSchedule` keeps the pinned steps and their R interface (#95, *Kept*).
- The scopes still carry superseded design, such as §2.3's first design beside its extension. Condense them to what is true now.

**3. Design of steps 4–6.** Run the `system-design` skill at tier 3, since odelia's stepper is a seam the adjoint sits behind. Inputs that changed since the scope was written:
- *The model is v12.* The pools are floored, so the soil chain is the stiff mode, and §6's savings bounds were taken on v11. Step 4 re-derives them.
- *Explicit pools are limited by positivity, not stability*: `h = 2.0T` under ARK's explicit part and `2.16T` under Cash–Karp, about 14–15 days at the floor (`harness/ark436.R`). Only 1% of the long-drought stand's steps are that long.
- *Zero throws is not reachable for a pool integrated by a tableau.* Step 6's old pass asked for it. Decide whether step 5 gives the pool an update of its own, which would also make invaders robust (stepper scope §3).
- *Invaders run on the resident's rows (#95).* The new stepper keeps six rows per step under both tableaus, with every evaluation addressed to a row.
- *The prototype can drive plant from R:* `Patch$derivs(y, t)`, `Patch$set_ode_state` and `Patch$introduce_new_node` exist.
- *`J` carries about 0.1% time error on long steps*: the 3.5- and 7-day caps agree to 1e-4, and the uncapped run differs by 1e-3. Step 4's gate compares at matched `J`.

The plan is `scope-schedule-controller.md` §6:

| step | what | state |
|---|---|---|
| 1 | Stops become step targets (stepper §2.1) | done, #96 |
| 2 | The pool's relaxation floor (stepper §3, option A) | done, #97; accepted; throws improved, not eliminated |
| 3 | Forward passes store their own rows (stepper §2.3) | done, #95 |
| 4 | Exact counts (controller §1) | PR #94, open; the stack is on it |
| 5–6 | Error maps, the schedule controller | not started |
| 7 | The stepper (stepper §7, steps 4–6) | designed next session |
| 8 | The time controller | not started |

## Traps

- *A slot's choices are a sequence:* TF24's leaf points are read in order, so only a full evaluation may read a full evaluation's slot.
- *A replayed input must be exact:* TF24's leaf solve turns a one-ulp difference upstream into 1e-9.
- *Two clocks:* a step's `at_state` ran at `fl(t + h)` from the row below (`at_state_time`); after an entry the solver keeps the recorded time, and the System's clock must agree to 2 ulp.
- *An invasion's recording pass re-runs the run*, and reproduces it only while nothing between the two calls changes the SCM.
- *`lma`'s pinned difference has a floor near 1e-5*, on residents too.
- *Positivity binds before stability for an explicit pool:* a step between 2.16 and 3.73 of a pool's relaxation time is stable, and its fourth stage is below empty.
- *A step cap does not make every invader run:* a near-empty pool whose stage rates differ in sign goes below zero inside a short step too (stepper scope §3).
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
