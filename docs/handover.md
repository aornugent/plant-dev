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

**The root cause of `J`'s time error is the pools' error control near empty** (*Done last session*). At the end of a drought a member's pool is nearly empty. When rain takes its net production back above zero the pool starts to refill, and its rate switches from drain to charge at that crossing.
- The step across the switch misintegrates the refill, and the error estimate sees about a third of it.
- Near empty, the pool's tolerance weight `tol·(|S| + 1)` is absolute in kg, so its relative error is percents and does not follow the tolerance.
- Mortality is steepest in the pool's fill there, and `J` depends on the oldest members' survival.

Tightening only the pools' weights 100× makes `J`'s error fall with the tolerance, to 1.2e-5 at tol 1e-4, for 19% more member evaluations and with no event handling. Tightening their absolute part alone cuts the error about ten-fold at 3e-4 and 1e-4.

**The Oracle's reply is tested, and its treatments of the switch fail.** Stepping onto the crossings, alone or with the leaf's class switches, and re-integrating the crossing member both converge 2.5–3e-4 from the true `J`, at up to 3.6× the cost. Nothing explains that offset yet. Widening the switch moves `J` 3.9% and does not make it follow the tolerance.

**Step 4 of the stepper killed it** (`scope-imex-stepper.md` §7, step 4, *Result*): the soil's stiffness was the wrong target. It does not carry `J`'s error, and the soil is stiff only while rain forces it.

**Next session: the Oracle again, then the design.** `oracle-consultation-solver-performance.md` is rewritten around these findings (*Next session*, 1). Nothing is to be built until a solver design follows from the reply.

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

All on u108 with `harness/ark_prototype.R`, against `J*` = 12.6687135 (Cash–Karp at 1e-8). The consult's T0–T17 hold the numbers.

**The true `J`.** Cash–Karp at 1e-7 is 4.5e-8 from `J*`, and T5's refusal with a 0.005-day cap at 1e-7 is 6.3e-7. The old reference, Cash–Karp at 1e-6, is −6.1e-6, so the step-4 conclusions stand.

**The Oracle's reply, tested** (`oracle-response-solver-performance.md`).
- Its data claims:
  - It predicted about 900 clusters of crossings, one just after each rain. There are 196: 98 in long dry spells, a median 32 days after the rain, each spread over 6 days; and 98 at the rains that end them, spread over 0.3 days.
  - Re-crossings are 4 of 9220, so plain event location applies.
  - The leaf's class switches (7909, Interior ↔ BoundaryCrit) do not coincide with the crossings.
  - While rain falls the members' draw is 1% of the top layer's fluxes, and it varies by 0.2% over a day.
- Its first test, stepping onto the crossings at `P` = −η:
  - `J` converges 2.6–2.8e-4 from `J*` at 1.3e7 member evaluations, against its prediction of T5's errors at 8e6.
  - 95% of its throws are the attempt after a located crossing, at the carried proposal. Starting that step at 0.05 days leaves 6.4e-5 and 36 throws.
  - With the class switches located too: +6.6e-6 at 3e-4 and +1.4e-4 at 1e-4, at 1.7e7.
- Its (B), refusing within clusters, is killed by the clusters' spans without a run.
- Its (C), re-integrating the crossing member on its own: +2.5e-4 at 1e-4, for 3% more cost.
- The model route of the last handover: a positive part widened to 5% of each member's costs moves `J` 3.9%, and at 1e-3…1e-4 its error is a steady +8e-4 against its own converged value.

**The root cause**, traced back by the `systematic-debugging` skill with no fix attempted.
- `J`'s error splits into a survival part (from each member's cumulative mortality) and an output part, of comparable size: +5.0e-4 and +3.7e-4 at 1e-4.
- The survival part is created in the oldest members' mortality in the dry spells of t = 3–14. It is carried in by their pools' state: a pool that arrives 1.7e-3 off, retaken from the reference, adds only −3.5e-6.
- The pools pick up relative errors of 1–2.5% at the refills after rain.
- Near-empty refilling pools keep a 90th-percentile relative error of 3.3e-3, 3.2e-3 and 2.0e-3 at tol 1e-3, 3e-4 and 1e-4. Pools over half full follow the tolerance.
- One weight changed: the pools' weights ×0.01 gives −3.6e-4, +1.2e-4, +1.2e-5 and +1.0e-5 at 1e-3 … 3e-5, for 5.53e6 member evaluations at 1e-4. Their absolute part alone gives +1.3e-4 and +7.8e-5 at 3e-4 and 1e-4.
- The kink kernel: a Cash–Karp step across a kink errs by `h²·[jump]·K(θ)`, and `K` has zero mean over the kink's position. Its ratio to the embedded estimate has a median of 3.4 over that position, as against the 4.6 measured on crossing steps.
- The last session's picture was that the offspring integral's own kink error carries `J`'s error. The prediction built from it has the wrong sign at 1e-3 and a twentieth of the size at 3e-4.

## Done before

- **Step 4 of the stepper** (stepper scope §7, step 4, *Result*): the driver reproduces Cash–Karp bit for bit; the held Cash–Karp's `J` error is Cash–Karp's (the kill line); ARK saves 9% of member evaluations at matched `J`, and its embedded estimate misses its long steps' soil error. The first trace of `J`'s error to the steps across the switch is there too; the session above refines it.
- **Steps 1–3 of the plan**, rebased onto #94, and the review of #96 and #97. Each issue, and the stepper scope's *Result* sections, record them. TF24 is v12, and throws fell 759 → 149.
- **Invaders with the storage pool** (stepper scope §3, *What invaders need beyond A*). Selection gradients work, and capping the step widens the range of invaders that run. A pool update that is non-negative at any step is deferred until invaders beyond ±5% are needed.
- **The stepper's design** (stepper scope §4–§6), which step 4 killed. The Appendix holds the alternative it was chosen over.

## Next session

**1. The Oracle.** The statement is `oracle-consultation-solver-performance.md`, rewritten by `oracle-consultation-guide.md` around the root cause: the true `J`, the channels, the pools near empty, the one-weight test, and the earlier reply's treatments measured and refuted, with open questions. The unexplained offset of the treatments that step onto the switch is asked about as such (question 3). Record the reply verbatim beside it, as `oracle-response-solver-performance.md` (keep the current one as `…-bbba8d1.md`). Then reduce each claim to the smallest driver run that confirms or kills it.

**2. The solver design**, after the Oracle, under the `system-design` skill: the error control that makes `J` follow the tolerance, then the cost (the rain legs hold 64% of member evaluations). Nothing is built before it.
- The requirement is that the error in `J` follows the tolerance at the least cost. `J` to 1e-4 is 6.41e6 member evaluations today (Cash–Karp at 1e-5, not following the tolerance), and 5.53e6 with the pools' weights ×0.01.
- The tool is `harness/ark_prototype.R` (`TOL_POOL`, `TOL_POOL_ABS`, `EVENTS`, `LOCAL`), with `harness/error_channels.R` for where an error travels.

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
| 7 | The stepper (stepper §7, steps 4–6) | killed at step 4, its prototype; `J`'s time error traced to the pools' error control near empty (*Done last session*) |
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
- *A switch in the rates is invisible to the error estimate:* TF24's positive part of net production turns growth, reproduction and the pool's charge off within seconds of model time. A Cash–Karp step across it reports about a third of its error.
- *A near-empty pool's error is uncontrolled:* its tolerance weight `tol·(|S| + 1)` is absolute in kg, and mortality is steepest in the pool's fill there. `J`'s error travels through the oldest members' survival, so compare a run's mortality and pools, not only its offspring integrals.
- *Retaking an interval from the reference's state measures its local error only:* the survival error arrives with the state, created at an earlier refill.
- *The reference for u108 is `J*` = 12.6687135*, from Cash–Karp at 1e-8. The run at 1e-6 is 6.1e-6 low.
- *R reads a script as it runs:* editing the driver while runs use it corrupts their last lines. Run from a snapshot; `run` in `$DEV/ark/ev_ladder.sh` copies one.
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
- The probe build, for the driver's `CLASS_EVENTS` and a wider positive part (`TF24_PROD_EPS`, `TF24_PROD_EPS_REL`), is `harness/tf24_probe.patch` applied to v12t: `git -C plant worktree add --detach $DEV/v12probe v12-targets`, `git -C $DEV/v12probe apply "$PWD/harness/tf24_probe.patch"` from the plant-dev root, installed with odelia05 and phylloptim09. It puts the leaf's operating-point class in the thirteenth auxiliary. With the default environment it reproduces v12t bit for bit.
- The v12 build with zero pulses as step targets, which `harness/ark_prototype.R` runs on, merges the two, one at a time: `git -C plant worktree add -b v12-targets $DEV/v12t origin/PLANT-95`, `git -C $DEV/v12t merge origin/PLANT-96` (a fast-forward), then `git -C $DEV/v12t merge origin/PLANT-97`, keeping both `NEWS.md` entries in the one conflict. Install odelia05, phylloptim09 and `$DEV/v12t` into a library of their own, as above.

**Tests** run from `$DEV/stack` with `TESTTHAT_PARALLEL=false`, by AGENTS.md's tiers: `testthat::test_file("tests/testthat/test-mutant.R", package = "plant", load_package = "installed")` after `library(odelia)`. odelia's run from `$DEV/odelia05` with `test_dir("tests/testthat", package = "odelia", load_package = "installed")`.

**Baselines on `PLANT-95`:** `test-mutant.R` 41 pass and 2 fail; the full serial suite 4651 pass and the same 2 fail, in 9.1 min; odelia 325 pass. On `PLANT-96` the suite passes 4667 and on `PLANT-97` 4664, each failing the same 2, in 9.7 and 7.4 min run side by side. On `offspring-adjoint` the suite passes 4628 and fails the same 2, in 9.5 min.

**Known failures, older than #95:**
- `test-mutant.R`'s "mutant method works" fails on FF16's ten-mutant panels, which are pinned to `develop`.
- odelia's `test-implicit-value.R` has 5 errors: its snippet passes a braced list to a `std::span` parameter, which this compiler refuses.
