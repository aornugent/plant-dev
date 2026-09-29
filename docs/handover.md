# Handover

## Principles

The user's, verbatim. They apply to all work here.

### Laziness Protocol

Apply when refactoring, evaluating diff size, or tempted to add abstractions, layers, or signal threading. Bias toward deletion and the smallest change that solves the problem

Writing code is cheap for you, which makes over-engineering easy. Counter it by borrowing a human maintainer's fatigue. Aim for the most result with the least code and complexity.

- **Prefer deletion.** When asked to refactor or improve, look for removals before additions.
- **Maintain a flat call hierarchy.** Avoid deep call chains. A rich interface that hides substantial work is not a deep call chain. If answering a question requires tracing through more than 3 files or layers, flatten it.
- **Consolidate decisions.** Do not repeat the same choice in several places. Put it behind one source of truth and pass the result as a simple flag.
- **Minimize the diff.** Make the smallest change that solves the problem. Fewer lines beat "elegant" boilerplate.
- **Question the threading.** If a task asks you to pass a new signal through types, schemas, pipelines, or similar layers, stop and look for a more direct path.
- **Sweat the small leaks.** Remove tiny pass-throughs, representation leaks, and duplicated choices before they spread. Small leaks compound into permanent coordination costs.

**Prime directive:** If a human developer would find the code exhausting to maintain, it is a bad solution. Be lazy. Stay simple.

### Subtract Before You Add

Apply when sequencing an addition, refactor, or rewrite. Remove dead weight, redundant validators, and stub references first, then build on the simpler base.

When evolving a system, remove complexity first, then build. Deletion gives you a simpler base, which makes the next addition smaller and less brittle.

**Why:** Adding to a complex system compounds complexity. Removing first cuts the surface area, reveals the essential structure, and usually makes the next design obvious. Default to subtraction.

Make simplification a continual investment. Leave the design slightly simpler and more capable behind the same or smaller surface than you found it.

**The pattern:**
- Sequence removal before construction
- Cut before you polish (get to the minimum before investing in quality)
- Design for observed usage, not speculative edge cases
- No speculative validators, parsers, or guards beyond what the spec demands
- Out-of-spec features drag validators behind them. Persistence, retry-on-startup, and schema migration each need guards to defend their inputs.
- Simplify prompts (remove redundant instructions, excessive templates)
- When a reference has no novel content, delete it rather than leaving a stub

### Minimize Reader Load

Apply when reviewing or shaping code that's hard to trace. Count layers between question and answer, and hidden state in the reader's head; collapse one-caller wrappers and shrink mutable scope.

Maintainability is the work a reader must do to understand code. Track two axes:
1. **Layers to trace.** How many indirections sit between the question and the answer.
2. **State to hold.** How much hidden or mutable context the reader must keep in their head.

**Why:** Code is read far more than it is written. LOC, cyclomatic complexity, and "clean architecture" are proxies. Reader load is the thing that matters. The two axes are independent. A flat file with 50 globals can be as hard to reason about as a 6-layer adapter stack. Guard both. This is the human analog of Guard the Context Window: working memory is finite for readers too.

**The pattern:**
- **Collapse layers** that do not earn their keep: wrappers with one caller, adapters with no second implementation, indirection introduced for a future that never came. Inline them.
- **Make adjacent layers change the abstraction.** A layer that repeats the same methods and arguments adds reader load without compression. Collapse pass-through layers.
- **Demand interface compression.** A broad interface that hides little complexity makes readers learn both the surface and the implementation. Prefer boundaries that hide meaningful decisions.
- **Shrink state scope:** prefer pure functions (returns over mutations), locals over fields, fields over module state, and module state over globals. Derive instead of sync.
- **Name the invariant at the boundary,** not in every consumer, so the reader learns it once.
- Before adding a layer or a piece of state, ask: does this reduce reader load somewhere else by at least as much?

**The test:** Can a new reader answer "where does X come from?" and "what can change X?" in under 30 seconds? If not, cut layers or cut state.

### Foundational Thinking

Apply before writing logic: choosing core types and data structures, sequencing scaffold-vs-feature work, asking what concurrent actors share. Get the data structures right so downstream code becomes obvious

**Code-level decisions** protect simplicity. Over-engineering is often a premature decision that closes doors. The right foundational data structure keeps doors open.

**Data structures first.** Get the data shape right before writing logic. The right shape makes downstream code obvious. Define core types early, trace every access pattern, and choose structures that match the dominant paths. A data-structure change late is a rewrite. Early, it is often a one-line diff.

At code level, DRY the structure, not every line. Types and data models should converge. Three similar statements still beat a premature abstraction. Prefer explicit over clever. Test behavior and edge cases, not line counts.

**Concurrency corollary.** Before sharing state between actors, ask "what happens if another actor modifies this concurrently?" If not "nothing", isolate.

**Scaffold first.** If something helps every later phase, do it first. Ask "does every subsequent phase benefit from this existing?" CI, linting, test infrastructure, and shared types are scaffold. Sequence for option value: setup before features, tests before fixes. Keep commits small and single-purpose.

Each increment should land a coherent abstraction or deepen one that exists. Do not spread a new capability across callers as special-case coordination.

Subtraction comes before scaffolding: remove dead weight first, then lay foundations. 

### Model the Domain

Apply when writing stateful logic, or when code branches a lot or repeats a shape assumption across files. Encode the domain in a structure instead of scattered conditionals.

Encode the real domain in a data structure instead of scattering it across conditionals.

**Why:** Scattered booleans, repeated shape assumptions, and branching spread across files are accidental complexity. A structure that matches the domain makes invalid states unrepresentable and deletes branches. Choosing it at write time is cheap; recovering it later reads as a refactor and gets deferred.

**Reach for structures like these:**

- A state machine instead of scattered booleans, phases, or lifecycle checks.
- A typed object/model instead of loose parameters or repeated shape assumptions.
- A map, registry, lookup table, or discriminated union instead of branching spread across files.
- A reducer or command/event model instead of ad hoc state mutations.
- A module organized around one body of domain knowledge instead of a sequence such as load, validate, transform, and save. Execution order is not ownership.
- A small module boundary that gathers repeated behavior, ownership, or invariants.
- A queue, cache, index, graph/tree, or normalized collection where the data access pattern calls for it.
- Any other structure that fits. The list above covers the common cases only. When none fits, work out what the code must never allow and how the data gets read, then find the structure that encodes exactly that.

Do not force an abstraction. Prefer boring code if the current shape is already clear, local, and unlikely to grow. Be skeptical of an abstraction that adds indirection without removing branches, duplicated rules, invalid states, or lifecycle risk.

The tell that you skipped this is a new feature that grows an existing if/else chain by one more branch, or a second boolean that must stay in sync with the first. Temporal decomposition is another tell. Phase-named modules repeat the same domain rules across steps.

## Where things stand

**Next session, in order: step 4 of the stepper, a clean-up, then steps 5 and 6** (`scope-imex-stepper.md` §7). Step 4 is the prototype driven from R, and its pass and kill lines decide whether 5 and 6 are built.

The stepper's design is decided (stepper scope §4–§7): odelia solves a declared stiff block, and a System states only its stiff rates. Each step's implementation is reviewed against the principles above and the developer's experience (§5), with the scope's Appendix as the comparison.

Steps 1–3 of the plan are done: [#96](https://github.com/aornugent/plant/issues/96), [#97](https://github.com/aornugent/plant/issues/97) and [#95](https://github.com/aornugent/plant/issues/95), all rebased onto #94. #97's model change is accepted. The code review was scoped to #96 and #97, and is done; the rest of the stack was not reviewed under the `code-review` skill.

The principles above apply to all work, and AGENTS.md's code style to every comment.

## Branches

On `aornugent/plant`, over `develop`'s `95256cf3`:

| branch | head | what | on | odelia |
|---|---|---|---|---|
| `PLANT-93` (PR #94, open) | `bae2dd9a` | exact counts; 1 commit | `develop` | `be3e2cb` |
| `offspring-adjoint` (#91) | `5a37615e` | the reverse sweep, TF24 v11; 14 commits | `PLANT-93` | `be3e2cb` |
| `PLANT-95` (#95) | `25e21a70` | exact invader replay; 5 commits | `offspring-adjoint` | `a05f5c2` |
| `PLANT-96` (#96) | `855f64ee` | zero pulses as step targets; 1 commit | `PLANT-95` | `a05f5c2` |
| `PLANT-97` (#97) | `b4b5febf` | the pool's relaxation offset, TF24 v12; 1 commit | `PLANT-95` | `a05f5c2` |

- odelia 0.5.0 is `claude/trusting-curie-4i9n3l` and phylloptim 0.9.0 is `378b083`, both unreleased. A branch builds only against its own odelia.
- No PR is open for `offspring-adjoint`, `PLANT-95`, `PLANT-96` or `PLANT-97`; opening them is the user's call. #96 and #97 are independent, and both edit the top of `NEWS.md`.
- `plant-dev`'s pointers (plant `6613dd24`, odelia `be3e2cb`) stay until #94 merges; odelia's moves with plant's.

## Done last session

- **The rebase onto #94.** The height coordinate is bit-identical across it. On the birth-date coordinate a node's density is its birth rate times its survival, and the boundary node reaches the census only through the newest interval's moment.
- **Step 1, zero pulses as step targets** (#96; stepper scope §2.1, *Result*). `J`, the steps and the gradient are bit-identical, and a sweep takes half the time.
- **Step 2, the pool's relaxation offset** (#97; stepper scope §3, *Result*). TF24 is v12.
  - `J` moves +2.7% on the long-drought stand and `dJ/dlma` +16%, and both are accepted.
  - Throws fall 759 → 149. They are improved, not eliminated.
- **Option B**, implicit pools, is not pursued: its stages go negative past `hλ` = 3.1, which fixes neither invaders nor throws (stepper scope §3).
- **The review of #96 and #97**, under the `code-review` skill. Its findings are fixed in each branch's one commit, and the issues describe the result.
  - #96 held a zero pulse apart only when nothing else happened at its time. That partition went stale under `set_times` and `clear_times`, a recording gained the pulses' times, `max_time` could be set before the last one, and its resource was no longer checked. Every zero pulse is now held apart. `SCM$events` returns each before the entry at its time, and `reset` checks its resource.
  - #97's parameter is `storage_relaxation_offset`: it is added to the pool's relaxation time and does not bound it, since the gate's slope takes the rate to 2.3/`τ_s`. A negative offset is refused. The mutant test has its zero-offset control, and the stochastic count is pinned at zero offset.
  - Declared, not fixed: #96's bit-identity is measured, not guaranteed, and `refine_schedule` samples competition errors at introductions only (#96, *Limits*).
- **Invaders with the storage pool** (stepper scope §3, *What invaders need beyond A*).
  - Selection gradients work: the identical invader is exact, and near neighbours run.
  - Capping the resident's step widens the range: at 3.5 days, `lma` × 0.8 to × 1.5 run on the long-drought stand, at 18% more steps.
  - Every invader would need a pool update that is non-negative at any step. It is deferred until step 4 shows more throws under ARK, or invaders beyond ±5% are needed.
- **The stepper's design** (stepper scope §4–§7), on v12 measurements (`harness/v12_steps.R`, `harness/soil_bound.R`).
  - The soil binds 90.5% of Cash–Karp's steps on u108, 29.5% of them at 0.8β or more of its stability boundary. The pools bind 2.7%.
  - `J`'s time error does not follow the tolerance. Against tol 1e-6 it is −2.4e-4 at 1e-3, +1.0e-3 at 3e-4 and +8.2e-4 at 1e-4, and within 1e-4 only from 1e-5.
  - Removing the soil's stability limit saves at most 41–46% at tol 1e-3.
  - odelia owns the implicit numerics, so a developer writes only rates. The System-owned stage solve lost on the developer's experience, and is the scope's Appendix.

## Next session

**1. Step 4, the prototype driven from R** (stepper scope §7). A plant-dev harness; no package changes.
- The build runs v12 with zero pulses as step targets: `PLANT-96` and `PLANT-97` merged over `PLANT-95` in a local branch, not pushed (*Setup*).
- One driver walks the SCM's schedule with odelia's controller law, in three configurations: Cash–Karp, reproducing the SCM bit for bit first; Cash–Karp held at 0.8β of the soil's stability; ARK4(3)6L[2]SA with the damped block Newton.
- The reference is Cash–Karp at tol 1e-6: 12.668637 on u108, at 23 188 steps.
- The pass and kill lines are §7's.

**2. Clean up.** Fix each item in the branch that owns it, then `git rebase --update-refs` and push every moved branch with `--force-with-lease`. Candidates found so far:
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

**3. Steps 5 and 6**, if step 4 passes: odelia's tableau stepper and stiff block, then TF24's wiring. One issue each, in odelia and in plant, stacked, and each reviewed against the principles and §5.

The plan is `scope-schedule-controller.md` §6:

| step | what | state |
|---|---|---|
| 1 | Stops become step targets (stepper §2.1) | done, #96 |
| 2 | The pool's relaxation offset (stepper §3, option A) | done, #97; accepted; throws improved, not eliminated |
| 3 | Forward passes store their own rows (stepper §2.3) | done, #95 |
| 4 | Exact counts (controller §1) | PR #94, open; the stack is on it |
| 5–6 | Error maps, the schedule controller | not started |
| 7 | The stepper (stepper §7, steps 4–6) | designed (stepper §4–§7); step 4 next |
| 8 | The time controller | not started |

## Traps

- *A slot's choices are a sequence:* TF24's leaf points are read in order, so only a full evaluation may read a full evaluation's slot.
- *A replayed input must be exact:* TF24's leaf solve turns a one-ulp difference upstream into 1e-9.
- *Two clocks:* a step's `at_state` ran at `fl(t + h)` from the row below (`at_state_time`); after an entry the solver keeps the recorded time, and the System's clock must agree to 2 ulp.
- *An invasion's recording pass re-runs the run*, and reproduces it only while nothing between the two calls changes the SCM.
- *`lma`'s pinned difference has a floor near 1e-5*, on residents too.
- *Positivity binds before stability for an explicit pool:* a step between 2.16 and 3.73 of a pool's relaxation time is stable, and its fourth stage is below empty.
- *A step cap does not make every invader run:* a near-empty pool whose stage rates differ in sign goes below zero inside a short step too (stepper scope §3).
- *A TF24 run at the default tolerance carries its own time error*, about 0.1% on the five-year stands, where the offset lengthens its steps. Compare against a run integrated to 1e-6, as TF24f's convergence test does.
- *A zero pulse is not an entry*, even at an introduction's time: `entries()`, `size`, the walks and `event_log` never see it. `get_events()` returns it before the entry at its time, and `program()` adds it to a grid only.
- *A correction put on the tape must be zero in value:* the implicit stage is `Y* − M·(G − to_passive(G))`. `Y* − M·G(Y*)` moves the stage by Newton's residual, and the sweep would no longer repeat the run's values.
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
- Step 4's build merges the two: `git -C plant worktree add -b v12-targets $DEV/v12t origin/PLANT-95`, then `git -C $DEV/v12t merge origin/PLANT-96 origin/PLANT-97`, keeping both `NEWS.md` entries, and install it into its own library.

**Tests** run from `$DEV/stack` with `TESTTHAT_PARALLEL=false`, by AGENTS.md's tiers: `testthat::test_file("tests/testthat/test-mutant.R", package = "plant", load_package = "installed")` after `library(odelia)`. odelia's run from `$DEV/odelia05` with `test_dir("tests/testthat", package = "odelia", load_package = "installed")`.

**Baselines on `PLANT-95`:** `test-mutant.R` 41 pass and 2 fail; the full serial suite 4651 pass and the same 2 fail, in 9.1 min; odelia 325 pass. On `PLANT-96` the suite passes 4667 and on `PLANT-97` 4664, each failing the same 2, in 9.7 and 7.4 min run side by side. On `offspring-adjoint` the suite passes 4628 and fails the same 2, in 9.5 min.

**Known failures, older than #95:**
- `test-mutant.R`'s "mutant method works" fails on FF16's ten-mutant panels, which are pinned to `develop`.
- odelia's `test-implicit-value.R` has 5 errors: its snippet passes a braced list to a `std::span` parameter, which this compiler refuses.
