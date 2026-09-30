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

## Scope

The work is heuristics for node introductions and ODE steps that make TF24's resident and invader gradients stable, on the birth-date coordinate and realistic rainfall. The user's four criteria are an optimal node schedule, optimal ODE steps, convergence of `J`, and stable gradients, where optimal means performant, accurate and stable.

- `OBJECTIVES.md`, which AGENTS.md loads every session, still says the gradients "drive gradient-based calibration". Calibration is not the scope. It was one advanced use in July's AD design (`docs/ad-infrastructure-design.md`, removed at `beeb251`), and these sessions made it the purpose, first in the consult's statement and then in `OBJECTIVES.md`, both drafted here. The edit is the user's to make.
- So the consult asks throughout about gradients for a calibration, and the Oracle's fifth reply sets precision budgets from a calibration's data, as a Cramér–Rao width from the fit's Hessian `H`. That recipe does not apply. A next consult states the scope above.

## State of play

**There is no resolution.** Nothing is built, no target for "stable gradients" is set, and the node schedule has not been measured this session. Everything below is on the driver, on one record (u108, 108 nodes), at θ₀.

**Settled, each against a control that could have refuted it:**
- *`J` converges on the time axis.* Tying each pool's absolute tolerance to its capacity (`POOL_FLOOR`, `σ_S = tol·(|S| + c·r₀·S_max)`) makes `J` follow tol at 0.2–0.5·tol. The cause was near-empty pools, whose relative errors mortality amplifies (`∂m/∂ln S` −0.276, against the −0.278 predicted).
- *The gradient's error sits on the steps across downward crossings of `P` = 0.* Splitting those steps removes it. Splitting as many dry steps of the same lengths, or the steps that hold only class switches, changes nothing. In a_dG2, the crossing steps that also hold a class switch carry three times the error per day, so there the two are not separated.
- *Pinned grids and invaders are stopped by the pool's stage guard, not by positivity.* With the guard off:
  - lma × 0.8 pinned runs within 1.1e-4 of its reference;
  - invaders from × 0.7 to × 2 run; up to × 1.2, where `J′` is not negligible, it is within about three times the base run's own error;
  - every step's end keeps its pools above zero.
- *`J`'s systematic error of −0.2 to −0.3·tol* comes from the mortality rate evaluated at stages that overshoot on the first emptying steps. Capping each pool's motion per step (`TRANSIT`) removes it.

**Measured around tol 1e-4,** over seven tolerances within ±5%, as median and standard deviation. Gradients are relative errors in `dJ/d ln θ`. The reference is the pool scale's 1e-6 grid with its crossing steps split 32 ways, which resolves 3e-5 in lma and 1.3e-4 in a_dG2.

| ODE-step rule | `J/J* − 1` | lma | a_dG2 | member evaluations |
|---|---|---|---|---|
| the pool scale alone | −4.0e-5, 1.2e-5 | −1e-6, 4.0e-4 | +1.1e-3, 7.0e-4 | 5.38e6 |
| + crossing steps capped at 1 day (`CROSS_CAP`, 12-day tail, `ONSET_CAP`) | −3.1e-5, 4.8e-6 | +1.3e-4, 2.1e-4 | −3.5e-4, 1.7e-4 | 5.65e6 |
| those grids with the crossing correction (`KINK_FIX`) | −2.7e-5, 2.3e-6 | −2.0e-4, 9.2e-5 | −2.0e-4, 1.9e-4 | the same, and one evaluation per crossing step |
| the cap alone: no tail, onset cap or guard | −2.1e-5, 6.7e-6 | +1.3e-4, 2.2e-4 | +1.4e-4, 2.4e-4 | 5.48e6 |
| + each pool's motion per step ≤ 0.5·r₀ (`TRANSIT`) | −7e-7, 6.1e-6 | −4.2e-5, 4.6e-4 | +3.4e-4, 4.8e-4 | 6.25e6 |
| + ≤ 0.25·r₀ | +5.0e-6, 2.3e-6 | +4.4e-4, 1.0e-4 | +2.9e-4, 3.6e-4 | 7.70e6 |

- The crossing cap is the one ODE-step heuristic that improves the gradients cheaply. It halves lma's draw and quarters a_dG2's, for 5% more member evaluations.
- The crossing correction halves lma's and `J`'s draw on the capped grids, and leaves a_dG2's. The Oracle predicted it would take the draw to about 1e-5.
- The transit cap removes `J`'s bias and leaves the gradients' errors as large or larger, for 14–41% more member evaluations.

**Open:**
- *A target for "stable gradients".* Every rule above leaves gradient errors of 1–4e-4 and a draw of 1–2e-4, and there is no number to judge that against.
- *a_dG2's residual,* about 2e-4. Neither the correction nor the transit cap moves it. The leading candidate is the class switches that share its crossing steps, and its reference is itself unresolved below 1.3e-4.
- *The node schedule.* The 108/215/429 ladder has not been run under the pool scale, so the schedule's share of `J`'s and the gradients' error is unknown.
- *Invader gradients.* `g′` at θ′ = θ has not been measured under any rule; only `J′` has.
- *Gradients on moved grids,* and any record but u108.

## What exists

- *In plant and odelia,* #94–#97 (*Branches*), and nothing since.
- *In `harness/ark_prototype.R`,* options on the driver. With none set, it reproduces the solver bit for bit.
  - Step rules: `POOL_FLOOR` (the pool scale), `CROSS_CAP` and `CROSS_TAIL` (the crossing cap), `ONSET_CAP` and `ONSET_SPAN`, `TRANSIT`, `KINK_FIX`, `KINK_EST` and `CROSS_RESTART`. `KINK_FIX` reads each crossing from `P`'s stage values and skips members whose `P` moves less than 100ε across the step.
  - On replays: `PROGRAM`, `THETA` with `THETA_REL`, `SPLIT` with `SPLIT_ROWS`, `CROSS_LOG` and `CLASS_LOG`.
  - A pinned step that raises names the pools it emptied, and a replay tallies the components that set error ratios above 1.1.
- *The consult,* `docs/oracle-consultation-solver-performance.md`: the statement and three follow-ups. The Oracle's fifth reply is `docs/oracle-response-solver-performance.md`, with the four earlier replies in that file's history. Each follow-up's §1 records the tests of the reply before it; the fifth reply's are in the table above.

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

## Done before

- **Step 4 of the stepper** (`docs/archive/scope-imex-stepper.md` §7, step 4, *Result*): the driver reproduces Cash–Karp bit for bit; the held Cash–Karp's `J` error is Cash–Karp's (the kill line); ARK saves 9% of member evaluations at matched `J`, and its embedded estimate misses its long steps' soil error.
- **Steps 1–3 of the plan**, rebased onto #94, and the review of #96 and #97. Each issue, and the archived stepper scope's *Result* sections, record them. TF24 is v12, and throws fell 759 → 149.
- **Invaders with the storage pool** (archived stepper scope §3, *What invaders need beyond A*). Selection gradients work, and capping the step widens the range of invaders that run. With the stage guard off, invaders from lma × 0.7 to × 2 run, so no pool update that is non-negative at every stage is needed.
- **The stepper's design** (archived stepper scope §4–§6), which step 4 killed. The Appendix holds the alternative it was chosen over.
- **The two scopes are archived** in `docs/archive/`. Steps 1–3 of their plan are [#96](https://github.com/aornugent/plant/issues/96), [#97](https://github.com/aornugent/plant/issues/97) and [#95](https://github.com/aornugent/plant/issues/95), rebased onto #94. #97's model change is accepted, and the code review covered #96 and #97.

## Next session

**1. Set the target for "stable gradients" with the user,** in the scope's own terms: for residents and invaders, how large a gradient error, and how large a draw between nearby settings, is acceptable. Then restate `OBJECTIVES.md` as the four criteria with those numbers, and without calibration.

**2. The node schedule.** Run the 108/215/429 ladder under the pool scale and the crossing cap at 1e-4, with `J` and both gradients. Half the scope has not been measured.

**3. Invader gradients.** Measure `g′` at θ′ = θ on the base grid under the pool scale and the cap, with its draw, against the same on a 1e-6 base.

**4. With the user's go-ahead, take the stage guard out of TF24,** in the branch that owns the pool (`PLANT-97`). Keep the refusal of a step whose end leaves a pool below zero, and count the stages that go below.
- Pass: invaders from lma × 0.7 to × 2 on u108 run, and wherever `J′` is not negligible it is within about three times the base run's own error, measured against the same invaders on a base run at 1e-6.
- Residents are unchanged wherever no stage went below.

**5. a_dG2's residual, only if the target needs it.** Split the class-switch steps on the capped grids with the correction on, and build a reference with its class-switch steps split too.

**6. Clean up.** Fix each item in the branch that owns it, then `git rebase --update-refs` and push every moved branch with `--force-with-lease`. Candidates found so far:
- odelia's `test-implicit-value.R` has 5 errors: its snippet passes a braced list to a `std::span` parameter, which this compiler refuses.
- `test-mutant.R`'s "mutant method works" fails on FF16's ten-mutant panels, which are pinned to `develop`.
- `TF24_Strategy::assign_from` copies `storage_gate_width` and `storage_prod_eps` but not `storage_domain_tol` (`tf24_strategy.h:1208`).
- Test comments that record history or stale numbers:
  - "offspring arrival" in `test-strategy-tf24.R`;
  - the seeded-baseline narrative in `test-stochastic-patch-runner.R`;
  - the `k_acclim` offspring table in `test-strategy-tf24f.R`.

  TF24's `scientific_version` log is history by design; whether it stays is the user's call.
- `NodeSchedule` keeps the pinned steps and their R interface (#95, *Kept*).

## Traps

- *A slot's choices are a sequence:* TF24's leaf points are read in order, so only a full evaluation may read a full evaluation's slot.
- *A replayed input must be exact:* TF24's leaf solve turns a one-ulp difference upstream into 1e-9.
- *Two clocks:* a step's `at_state` ran at `fl(t + h)` from the row below (`at_state_time`); after an entry the solver keeps the recorded time, and the System's clock must agree to 2 ulp.
- *An invasion's recording pass re-runs the run*, and reproduces it only while nothing between the two calls changes the SCM.
- *`lma`'s pinned difference has a floor near 1e-5*, on residents too.
- *Positivity binds before stability for an explicit pool, and only the stage guard minds:* a step between 2.16 and 3.73 of a pool's relaxation time is stable while its fourth stage is below empty, and a near-empty pool whose stage rates differ in sign goes below zero inside a short step too. The step's combination recovers: with the guard off, pinned runs and invaders stay within about three times the base run's error, and every step's end stays above zero.
- *A TF24 run at the default tolerance carries its own time error*, about 0.1% on the five-year stands, where the offset lengthens its steps. Compare against a run integrated to 1e-6, as TF24f's convergence test does.
- *A zero pulse is not an entry*, even at an introduction's time: `entries()`, `size`, the walks and `event_log` never see it. `get_events()` returns it before the entry at its time, and `program()` adds it to a grid only.
- *A correction put on the tape must be zero in value:* the implicit stage is `Y* − M·(G − to_passive(G))`. `Y* − M·G(Y*)` moves the stage by Newton's residual, and the sweep would no longer repeat the run's values.
- *A switch in the rates is invisible to the error estimate:* TF24's positive part of net production turns growth, reproduction and the pool's charge off within seconds of model time. A Cash–Karp step across it reports about a third of its error.
- *A pool's absolute tolerance must scale with its capacity:* under the shared `tol·(|S| + 1)` in kg, a near-empty pool's relative error does not follow the tolerance, and mortality turns it into survival error (`∂m/∂ln S` ≈ −0.28 over a dry stretch). `J`'s error travels through the oldest members' survival, so compare a run's mortality and pools, not only its offspring integrals.
- *The pool's kink is a difference of slopes:* its rate has slope (1 − G)(1 − r) in `P` above zero and r below, so the jump at `P` = 0 is their difference, which vanishes near r = 0.2. The second reply's `0.73 + r` holds only near empty, and `harness/ark_prototype.R`'s `KINK_EST` used `(1 − G)(1 − r) + r` until it was corrected.
- *One `J` is one draw:* moving tol by 3% moves plain Cash–Karp's `J` error by 2e-4. Compare treatments by their channels (`harness/error_channels.R`) or by nearby tolerances, not by one run's `J`.
- *Retaking an interval from the reference's state measures its local error only:* the survival error arrives with the state, created at an earlier refill.
- *The reference for u108 is `J*` = 12.6687135*, from Cash–Karp at 1e-8. The run at 1e-6 is 6.1e-6 low.
- *R reads a script as it runs:* editing the driver while runs use it corrupts their last lines. Run from a snapshot; `run` in `$DEV/ark/ev_ladder.sh` copies one.
- *The soil has no fast mode to take implicitly:* drainage goes as `θ^16.14`, so after rain a layer's relaxation rate is about one over the time since the rain. ARK's longer steps there are inaccurate, and on one its embedded estimate put the top layer's error at a fifteenth of its size.
- *A lambda returning an active product needs `-> value_type`:* a deduced return type hands back an expression template over dead operands, and the value comes out right while the derivative reads freed memory.
- *A crossing step often holds class switches too:* on the pair's grid at 1e-3, all but 28 of the steps with a switch into the lower end, and all but 8 of those with one out of it, hold some member's crossing. Split them apart before blaming either.
- *A switch smoothed within a step is still a kink to the integrator:* the positive part at ε = 0.05·P_b moves `J` by 3.9%, and leaves `J`'s draw and a_dG2's error in place; lma's errors fall 2–7× but do not follow tol.
- *A split reference stops converging near its resolution:* split 8, 16 and 32 ways, the pool scale's 1e-6 grid moves by 3e-5 in lma and 1.3e-4 in a_dG2.
- *`queue.sh` needs absolute paths:* `ev_ladder.sh`, which it sources, changes into the repository, so a relative job file is not found and the queue ends at once.
- *A crossing correction needs the crossing from the stages, and a sharp switch:* from the step's ends the crossing's place misses by a tenth of the step, where the kernel changes sign; and a member whose `P` moves less than about 100ε across the step has no kink at the step's scale, so a point-kink correction overcorrects it by orders of magnitude.

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
- The probe build, for the driver's `CLASS_EVENTS` and `CLASS_LOG`, a wider positive part (`TF24_PROD_EPS`, `TF24_PROD_EPS_REL`) and a settable stage guard (`TF24_DOMAIN_TOL`), is `harness/tf24_probe.patch` applied to v12t: `git -C plant worktree add --detach $DEV/v12probe v12-targets`, `git -C $DEV/v12probe apply "$PWD/harness/tf24_probe.patch"` from the plant-dev root, installed with odelia05 and phylloptim09. It puts the leaf's operating-point class in the thirteenth auxiliary. With the default environment it reproduces v12t bit for bit.
- The v12 build with zero pulses as step targets, which `harness/ark_prototype.R` runs on, merges the two, one at a time: `git -C plant worktree add -b v12-targets $DEV/v12t origin/PLANT-95`, `git -C $DEV/v12t merge origin/PLANT-96` (a fast-forward), then `git -C $DEV/v12t merge origin/PLANT-97`, keeping both `NEWS.md` entries in the one conflict. Install odelia05, phylloptim09 and `$DEV/v12t` into a library of their own, as above.

**Tests** run from `$DEV/stack` with `TESTTHAT_PARALLEL=false`, by AGENTS.md's tiers: `testthat::test_file("tests/testthat/test-mutant.R", package = "plant", load_package = "installed")` after `library(odelia)`. odelia's run from `$DEV/odelia05` with `test_dir("tests/testthat", package = "odelia", load_package = "installed")`.

**Baselines on `PLANT-95`:** `test-mutant.R` 41 pass and 2 fail; the full serial suite 4651 pass and the same 2 fail, in 9.1 min; odelia 325 pass. On `PLANT-96` the suite passes 4667 and on `PLANT-97` 4664, each failing the same 2, in 9.7 and 7.4 min run side by side. On `offspring-adjoint` the suite passes 4628 and fails the same 2, in 9.5 min.

**Known failures, older than #95:**
- `test-mutant.R`'s "mutant method works" fails on FF16's ten-mutant panels, which are pinned to `develop`.
- odelia's `test-implicit-value.R` has 5 errors: its snippet passes a braced list to a `std::span` parameter, which this compiler refuses.
