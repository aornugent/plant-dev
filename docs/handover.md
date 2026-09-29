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

## Objectives

`OBJECTIVES.md` holds them, and AGENTS.md loads it every session. They replace the four criteria and the consult's *Wanted* paragraph: converging dynamics come first, and the goals are gradients for residents and invaders on one fixed grid per rainfall record.

## Where things stand

**The objectives were reset.** The stepper and the schedule controller were designed before the dynamics converged, and judged against a draw. `OBJECTIVES.md` puts convergence first: the error follows its knob, is not a draw, and the grid transfers across `θ` and to invaders.

**The time axis converges on u108 at θ₀, on the driver; nothing is built.** Each pool's absolute tolerance is tied to its capacity, `σ_S = tol·(|S| + c·r₀·S_max(x_j))`, with `c` = 1e-4 or 1e-3 and `r₀` = 0.05:
- `J` is within 1e-4 at tol 1e-4, at 5.4e6 member evaluations, 16% fewer than Cash–Karp at 1e-5. At tol 3e-4 (4.6e6) it sits at 1e-4: three of seven runs within ±5% of that tol are beyond it;
- `|J/J* − 1|` is 0.2–0.5·tol from 1e-3 to 3e-5, against Cash–Karp's 3–8·tol;
- nudging tol within ±5% of 3e-4 moves `J` over 1.1e-4 with the scale alone and 6.7e-4 with Cash–Karp. With the kink-aware estimate and the restart as well, it moves `J` over 7.0e-5, and over 1.9e-5 with the estimate's first, inflated factor (*Done last session*).

**The root cause, confirmed.** A relative pool error `ε` becomes a shift `−μ₁·τ_pool·(1 − e^{−r/r₀})·ε` in the member's cumulative mortality, measured at −0.276 against the formula's −0.278. Under the shared absolute tolerance, near-empty pools' relative errors do not follow the tolerance, and the step across the pool's switch at `P` = 0 hides about two thirds of its error from the estimate.

**At the θ a grid was built for, the gradient was never the problem.** On u108's own grids `dJ/dθ` is within 2.2% with plain Cash–Karp at every tolerance, and within 0.1% with the full pool setting, the scale with the kink-aware estimate and the restart (*Done last session*). The schedule's share, invaders and other θ are unmeasured.

**Whether a grid transfers is the open question** (objective (c)). It was measured only before the pool scale:
- θ₀'s steps replayed at ±5% in lma, before #97, were up to 6.6× out of tolerance and put stages below the pool's guard (`docs/measurements/perf-across-theta.md` §4);
- on u108 at v12, of invaders at lma × 0.95 to × 1.05 only × 0.99 runs on a resident at tol 1e-3, and all run at tol 1e-4. Under a 3.5-day cap at tol 1e-3, × 0.8 to × 1.5 run. The failures sit at the ends of long dry stretches, where the oldest pools are near empty (`docs/archive/scope-imex-stepper.md` §3);
- the node schedule transferred: 180 nodes built at θ₀ held within 8.8e-4 across lma.

**The Oracle has a follow-up**, the consult's *Follow-up, after the reply*. It reports the second reply's proposals measured, the gradients, the objectives and what is known of (c). Its reply is awaited.

**The two scopes are archived** in `docs/archive/`. Steps 1–3 of their plan are [#96](https://github.com/aornugent/plant/issues/96), [#97](https://github.com/aornugent/plant/issues/97) and [#95](https://github.com/aornugent/plant/issues/95), rebased onto #94. #97's model change is accepted, and the code review covered #96 and #97.

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

All on u108 with `harness/ark_prototype.R`, against `J*` = 12.6687135 (Cash–Karp at 1e-8). The consult's T0–T17 hold the numbers from before the second reply.

**The second reply, tested.**
- **Its setting works.** A pool's absolute part tied to its capacity (`POOL_FLOOR`) gives these `J` errors against `J*`, for tol 1e-3, 3e-4, 1e-4 and 3e-5:
  - `c` = 1e-3: −4.6e-4, −6.2e-5, −5.2e-5 and −6.7e-6, at 4.08e6, 4.64e6, 5.37e6 and 6.41e6 member evaluations;
  - `c` = 1e-4: −6.1e-5 at 3e-4 and −2.4e-5 at 1e-4.
- **Its refinements, with the kink factor corrected** to the difference of the pool rate's slopes (the traps):
  - the kink-aware pool estimate (`KINK_EST`) alone: −6.7e-5 at 3e-4 and −1.4e-5 at 1e-4, for about 10% more cost;
  - a 0.1-day restart after each crossing (`CROSS_RESTART`) alone: −2.4e-5 at 3e-4 and −7.9e-5 at 1e-4, for 13–14% more;
  - both: −1.5e-4, −7.7e-5, −2.7e-5 and −3.4e-6 from 1e-3 to 3e-5, for 22–25% more.
- **Nudges** (`$DEV/ark/nudge_table.R`): `J/J* − 1` over seven tolerances within ±5% of 3e-4. Cash–Karp has median +8.1e-4 and range 6.7e-4. The scale alone has −9.6e-5 and 1.1e-4. Both refinements have −1.1e-4 and 7.0e-5, and with the first, inflated kink factor −5.7e-5 and 1.9e-5. That factor overstates the pool's own jump at the crossings' `r`, yet it gives the steadiest `J`.
- **Its amplifier is confirmed.** Member 2's pool scaled by 1 + 1e-3 at the start of the 135-day stretch gives `∂m/∂ln S` = −0.276, against the formula's −0.278, and the relative change is carried through the stretch unchanged.
- **Its noise claim is confirmed.** Plain Cash–Karp at tol 9.7e-5, 1e-4 and 1.03e-4 is +6.2e-4, +8.1e-4 and +8.2e-4. Treatment differences below about 1e-4 are single draws unless checked by nudges (below).
- **Refuted.**
  - T8's +1.2e-5 at 1e-4 is a cancellation: loss part +9.9e-5, output part −9.3e-5.
  - The pools are not near empty at the crossings: the ten earliest members' pools are a median 35% full at downward crossings and 17% at upward ones.
  - `φ` never reaches its cap (below v = 0.133) in the dry stretches, so the flat `P` there is the leaf's lower-end class, not a capped `φ`.
- **Explained.** The events' offset is in the pools: events with T8 carry a loss part of +2.7e-4 at 1e-4, as the reply suspected of their retake and restart.
- **Untested.** The adjoint-weighted estimate `E_J = Σ λᵀ·le`, which needs the sweep; sub-cycling the chain in pulses, projected at 2–2.5e6.

**`dJ/dθ` on u108's own grids.** Each run's accepted steps are replayed (`PROGRAM`) with lma or a_dG2 × (1 ± 1e-4) (`THETA`, `THETA_REL`), as a central difference, against the same on Cash–Karp at 1e-8 (1e-7 for a_dG2). Relative error in `dJ/d ln lma`, whose reference is −63.10:

| tol | Cash–Karp | pool scale, `c` = 1e-3 | with the kink estimate and restart |
|---|---|---|---|
| 1e-3 | −6.1e-3 | −1.7e-3 | −9.7e-4 |
| 3e-4 | +2.3e-3 | +2.1e-3 | −1.3e-4 |
| 1e-4 | +1.2e-3 | +5.3e-4 | +7.1e-5 |
| 3e-5 | −2.3e-3 | −6.9e-4 | −3.7e-4 |
| 1e-5 | +8.4e-4 | | |

For a_dG2 (reference 13.37): Cash–Karp −2.2e-2, +7.1e-4 and +6.1e-3 at 1e-3, 1e-4 and 1e-5; the pool scale +4.8e-3 and +9.9e-4 at 3e-4 and 1e-4; with both refinements −8.3e-4 and −1.3e-4. No ladder is monotone, so no order can be read from them, and entries below about 2e-4 are within the reference's own difference from its neighbour at 1e-7.

**The objectives.** The four criteria were reworked with the user into `OBJECTIVES.md`. Why the grid is fixed came from the earlier consults: the sweep differentiates the discretised model and the controller is not differentiated, so an adaptive grid makes `J` jump in θ. The scopes were archived and the Oracle's follow-up written.

**The first reply's tests and the root cause**, from earlier in the session, are in the consult (T0–T17): the treatments that step onto the switch fail, the true `J`, the channel split, and the pools' errors near empty.

## Done before

- **Step 4 of the stepper** (`docs/archive/scope-imex-stepper.md` §7, step 4, *Result*): the driver reproduces Cash–Karp bit for bit; the held Cash–Karp's `J` error is Cash–Karp's (the kill line); ARK saves 9% of member evaluations at matched `J`, and its embedded estimate misses its long steps' soil error.
- **Steps 1–3 of the plan**, rebased onto #94, and the review of #96 and #97. Each issue, and the archived stepper scope's *Result* sections, record them. TF24 is v12, and throws fell 759 → 149.
- **Invaders with the storage pool** (archived stepper scope §3, *What invaders need beyond A*). Selection gradients work, and capping the step widens the range of invaders that run. A pool update that is non-negative at any step is deferred until invaders beyond ±5% are needed.
- **The stepper's design** (archived stepper scope §4–§6), which step 4 killed. The Appendix holds the alternative it was chosen over.

## Next session

**1. Test the Oracle's reply to the follow-up**, each claim by its cheapest measurement on the driver, before anything is built.

**2. Measure objective (c) on u108**, unless the reply redirects it.
- Replay θ₀'s grids (Cash–Karp at 1e-4; the pool scale and the full setting at 3e-4) with `PROGRAM` at lma and a_dG2 × {0.9, 0.95, 1.05, 1.1, 1.25}. Compare each against an adaptive run at that point with the full setting at 3e-5.
- Report `J`'s and `dJ/dθ`'s error, the error ratio re-formed on the replayed steps, the stages below the pool's guard, and the subdivision of θ₀'s steps that restores tolerance.
- The driver's replay reports no error ratio yet, and stops where a stage throws.
- Then invaders, which need the driver to replay a recorded field, and then a second record.
- The tools are `harness/ark_prototype.R` (`PROGRAM`, `THETA`, `THETA_REL`, `POOL_FLOOR`, `KINK_EST`, `CROSS_RESTART`) and `harness/error_channels.R`.

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

## Traps

- *A slot's choices are a sequence:* TF24's leaf points are read in order, so only a full evaluation may read a full evaluation's slot.
- *A replayed input must be exact:* TF24's leaf solve turns a one-ulp difference upstream into 1e-9.
- *Two clocks:* a step's `at_state` ran at `fl(t + h)` from the row below (`at_state_time`); after an entry the solver keeps the recorded time, and the System's clock must agree to 2 ulp.
- *An invasion's recording pass re-runs the run*, and reproduces it only while nothing between the two calls changes the SCM.
- *`lma`'s pinned difference has a floor near 1e-5*, on residents too.
- *Positivity binds before stability for an explicit pool:* a step between 2.16 and 3.73 of a pool's relaxation time is stable, and its fourth stage is below empty.
- *A step cap does not make every invader run:* a near-empty pool whose stage rates differ in sign goes below zero inside a short step too (archived stepper scope §3).
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
