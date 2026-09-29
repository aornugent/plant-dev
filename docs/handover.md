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

**Step 4 of the stepper killed it** (`scope-imex-stepper.md` §7, step 4, *Result*). Holding Cash–Karp below the soil's stability limit leaves `J`'s time error as it was, and ARK with the soil implicit saves 9% of member evaluations at matched `J`. Steps 5 and 6 are not built.

**What carries `J`'s time error is found** (stepper scope §7, step 4, *Result*): the steps across which a member's net production changes sign. TF24 takes the positive part of net production with `ε` = 1e-4, so growth and reproduction switch off in seconds as a drying soil takes production below zero. Cash–Karp's error estimate misses a step across that switch by a factor of about 4, and `J` does not follow the tolerance. Keep such steps under 0.05 days and it does.

**Next session: the Oracle, then how to remove that error, then the clean-up.** `oracle-consultation-solver-performance.md` is rewritten around the time integration as it now stands, and asks whether this is a known class of problem with standard treatments (*Next session*, 1).

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

**Step 4 of the stepper** (stepper scope §7, step 4, *Result*), with `harness/ark_prototype.R`: one R driver through the SCM's schedule under odelia's controller law, over tol 1e-2 … 1e-6 on u108.
- Cash–Karp is reproduced bit for bit. That also checks stepper §4's tableau rule: sums over nonzero coefficients in ascending stage, `h` after the sum, and a one-term row as `(a·h)·k`.
- The held Cash–Karp's `J` error is Cash–Karp's from 3e-4 down: the kill line.
- ARK is within 1e-4 only from 1e-5, where it saves 9% of member evaluations. At 1e-3 it saves 43%, at a `J` 7.6% low.
- A layer's relaxation rate falls with its moisture, so after rain the soil relaxes as fast as it changes, and an implicit layer gains no step. ARK's embedded estimate misses the error of its longer steps there: 11.5 times the tolerance against 0.75 on one.
- ARK throws more than Cash–Karp at every tolerance, as stepper §4's risks expected of its longer steps.

**What carries `J`'s time error**, traced back from `J` (stepper scope §7, step 4, *Result*).
- `J` → the members' offspring integrals → the dry legs of t = 12–20 → the steps across which a member's net production changes sign → the positive part's kink at `ε` = 1e-4.
- The test: capping those steps at 0.05 days makes `J` follow the tolerance. The control, the same cap where production crosses 3, does not.

## Done before

- **Steps 1–3 of the plan**, rebased onto #94, and the review of #96 and #97. Each issue, and the stepper scope's *Result* sections, record them. TF24 is v12, and throws fell 759 → 149.
- **Invaders with the storage pool** (stepper scope §3, *What invaders need beyond A*). Selection gradients work, and capping the step widens the range of invaders that run. A pool update that is non-negative at any step is deferred until invaders beyond ±5% are needed.
- **The stepper's design** (stepper scope §4–§6), which step 4 killed. The Appendix holds the alternative it was chosen over.

## Next session

**1. The Oracle.** The statement is `oracle-consultation-solver-performance.md`, written by `oracle-consultation-guide.md`: the system's and the solver's dynamics, v12's measurements, the refutation of the earlier reply's first prediction, and open questions. The creation schedule and the optimisation across `θ` are left out. Record the reply verbatim beside it, then reduce each claim in it to the smallest run of `harness/ark_prototype.R` that confirms or kills it, before building anything (the guide, §7).

**2. Remove the switch's error.** Two routes, and the choice is the user's, after the Oracle.
- **The model.** Widen the positive part's smoothing to the scale of each member's production, so the switch takes as long as the steps. `ε` = 1.9 kg/yr would spread the median crossing over a day, but a fixed `ε` that wide adds `ε/2` of production to a seedling, so it would be relative. `J` and `dJ/dθ` move, as a declared model change.
- **The solver.** A System declares the functions whose sign changes switch its rates, here each member's `P`, and the stepper ends a step where one changes sign. A 1e-4 run meets 921 such events at a quarter-day window and 3241 at 0.05 days, against 11 813 steps.
- **What either buys.** With the switch resolved, Cash–Karp's `J` is 2.3e-5 from its converged value at tol 1e-4, where today it is within 1e-4 only from 1e-5. That is 4.64e6 member evaluations against 6.41e6, 28% fewer, before the events' cost. And the error maps and the time controller (controller scope §2, §6) need a `J` that follows the tolerance.
- **The tool.** `harness/ark_prototype.R` with `SWITCH_DAYS`, and `harness/j_error_trace.R`. The converged `J` on u108 is 12.668784361, from the capped run at 1e-6. Cash–Karp's own 1e-6 is 12.668636519, and u429's is 12.737409168.

**3. Clean up.** Fix each item in the branch that owns it, then `git rebase --update-refs` and push every moved branch with `--force-with-lease`. Candidates found so far:
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

The plan is `scope-schedule-controller.md` §6:

| step | what | state |
|---|---|---|
| 1 | Stops become step targets (stepper §2.1) | done, #96 |
| 2 | The pool's relaxation offset (stepper §3, option A) | done, #97; accepted; throws improved, not eliminated |
| 3 | Forward passes store their own rows (stepper §2.3) | done, #95 |
| 4 | Exact counts (controller §1) | PR #94, open; the stack is on it |
| 5–6 | Error maps, the schedule controller | not started |
| 7 | The stepper (stepper §7, steps 4–6) | killed at step 4, its prototype; `J`'s time error traced to the members' switch (stepper §7) |
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
- *A switch in the rates is invisible to the error estimate:* TF24's positive part of net production turns growth and reproduction off within seconds of model time. A Cash–Karp step across it reports about a quarter of its error, so a run's `J` does not follow its tolerance.
- *The soil has no fast mode to take implicitly:* drainage goes as `θ^16.14`, so after rain a layer's relaxation rate is about one over the time since the rain. ARK's longer steps there are inaccurate, and on one its embedded estimate put the top layer's error at a fifteenth of its size.
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
- The v12 build with zero pulses as step targets, which `harness/ark_prototype.R` runs on, merges the two, one at a time: `git -C plant worktree add -b v12-targets $DEV/v12t origin/PLANT-95`, `git -C $DEV/v12t merge origin/PLANT-96` (a fast-forward), then `git -C $DEV/v12t merge origin/PLANT-97`, keeping both `NEWS.md` entries in the one conflict. Install odelia05, phylloptim09 and `$DEV/v12t` into a library of their own, as above.

**Tests** run from `$DEV/stack` with `TESTTHAT_PARALLEL=false`, by AGENTS.md's tiers: `testthat::test_file("tests/testthat/test-mutant.R", package = "plant", load_package = "installed")` after `library(odelia)`. odelia's run from `$DEV/odelia05` with `test_dir("tests/testthat", package = "odelia", load_package = "installed")`.

**Baselines on `PLANT-95`:** `test-mutant.R` 41 pass and 2 fail; the full serial suite 4651 pass and the same 2 fail, in 9.1 min; odelia 325 pass. On `PLANT-96` the suite passes 4667 and on `PLANT-97` 4664, each failing the same 2, in 9.7 and 7.4 min run side by side. On `offspring-adjoint` the suite passes 4628 and fails the same 2, in 9.5 min.

**Known failures, older than #95:**
- `test-mutant.R`'s "mutant method works" fails on FF16's ten-mutant panels, which are pinned to `develop`.
- odelia's `test-implicit-value.R` has 5 errors: its snippet passes a braced list to a `std::span` parameter, which this compiler refuses.
