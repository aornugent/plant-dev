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

`OBJECTIVES.md` holds them, and AGENTS.md loads it every session. They replace the four criteria and the consult's *Wanted* paragraph: converging dynamics come first, and the goals are gradients for residents and invaders on one fixed grid per rainfall record, within its transfer radius.

## Where things stand

**The root causes are pinned down, each against a control that could have refuted it** (*Done last session*):
- *`J`'s time error* was the pools' absolute tolerance near empty, amplified through mortality (`∂m/∂ln S` −0.276 against the formula's −0.278). Tying each pool's absolute part to its capacity, `σ_S = tol·(|S| + c·r₀·S_max(x_j))` with `r₀` = 0.05, makes `J` follow tol at 0.2–0.5·tol.
- *The gradient's error* is the positive part's switch at `P` = 0 on the steps across downward crossings. Splitting those steps removes it, and splitting as many dry steps of the same lengths, or the steps that hold only class switches, changes nothing. In a_dG2 the crossing steps that also hold a class switch carry three times the error per day, so there the two are not separated. Smoothing the switch to ε = 0.05·P_b changes the error without removing it: at that width it still sits inside a step.
- *Throws on pinned grids, and invaders that fail,* come from the pool's stage guard, not from positivity. With the guard off, the pool scale's grid (`c` = 1e-4, tol 1e-4) pinned at lma × 0.8 is within 1.1e-4 of its reference, and invaders from × 0.7 to × 1.2 run within about three times the base run's own error. On the pinned run, every step's end keeps its pools above zero.

**The rule that follows** is the fourth reply's, less the parts that act only away from θ₀: the pool scale (`c` = 1e-3); each step capped at `h_e` = 1 day from a member's predicted downward crossing to 12 days past its cluster's last (`CROSS_CAP`); and at 0.3 days for the 1.5 days after rain starts while a member's `P` is negative (`ONSET_CAP`), whose share of the gradient was not separated. Over seven tolerances within ±5% of 1e-4:
- `J`'s standard deviation is 4.8e-6, or 0.05·tol, against 1.2e-5 for the pool scale alone;
- the gradient's is 2.1e-4 in lma and 1.7e-4 in a_dG2, against 4.0e-4 and 7.0e-4, and a_dG2's median error falls from +1.1e-3 to −3.5e-4;
- it costs 5% more member evaluations, 5.65e6.

Splitting its capped steps in two cuts the gradient's errors 2.6× in lma and 1.5× in a_dG2, where first order gives 2×, and extrapolates to +5e-5 and −1.1e-4. So the two-point ladder is not yet shown to certify at this level.

**Nothing is built, and `OBJECTIVES.md` is unchanged.** The revision drafted for the user read as a procedure, with open numbers. The user wants the objectives back to at most four criteria, like the original four (an optimal node schedule, optimal ODE steps, convergence of `J` and stable gradients, where optimal means performant, accurate and stable), and guidance on precision budgets.

**These findings went back to the Oracle** as the consult's *Third follow-up, after your reply to the second follow-up*. It asks for the closest solver or controller precedent for the constraints that bind, for how to set the precision budgets, and for the objectives as at most four criteria. Its reply is awaited.

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

All on u108 with `harness/ark_prototype.R`, against `J*` = 12.6687135 and, for gradients, a pinned central difference on the pool scale's grid at 1e-6 with its crossing steps split 32 ways. That reference resolves 3e-5 in lma and 1.3e-4 in a_dG2: split 8, 16 and 32 ways it moves by that much. The older references, the pair at 1e-8 and 1e-7, are within 8e-5 of it.

**The fourth reply** (`oracle-response-solver-performance.md`) answers the consult's *Second follow-up*. It proposes rebuilding the grid at every iterate and pinning it only at the end, a cap on the crossing steps with a two-point ladder in the cap as the gradient's certificate, and setting the precision in θ first. Its claims, tested:
- *The gradient's error is on the downward crossing steps.* Confirmed. On the pair's grid at 1e-3, splitting the 185 downward crossing steps four ways takes lma's error from −6.1e-3 to +6.1e-4 and a_dG2's from −2.2e-2 to −4.2e-3. Splitting the 120 upward ones leaves them at −7.1e-3 and −2.3e-2.
- *The cap.* Confirmed, with the numbers in *Where things stand*. Its cost is +5% at 1 day and +16% at half a day; the reply predicted +16% at 1 day. It caps 16% of accepted steps at `h_e` and 5.5% after rain onsets, where the reply expected 3–6%.
- *The ladder as a certificate.* Not yet shown. At 1e-4 the capped grid's errors are −2.3e-4 (lma) and −3.5e-4 (a_dG2). An adaptive run capped at half a day gives −1.9e-4 and −2.5e-4, within one standard deviation of the draw. The same grid with its 2358 capped steps split in two gives −8.8e-5 and −2.3e-4, 2.6× and 1.5× smaller where first order gives 2×, and they extrapolate to +5e-5 and −1.1e-4.
- *The onset cap,* 0.3 days for the 1.5 days after rain starts while a member's `P` is negative. Every switch out of the lower end falls after the onset, a median 0.35 days after, and 97% of upward crossings within 1.5 days of it. The cap leaves the seven nudges at 3e-4 unchanged, standard deviation 3.1e-5 against 2.9e-5, where the reply predicted 7e-6 or less. The first kink factor's 6.8e-6 is still unexplained.
- *The references straddle crossings.* By 8e-5, not by the 2e-4 at which the earlier ladders levelled off.
- *The throw at lma × 0.8* is not the emptying's positivity limit. On a 9.5-day step at t = 3.48, members 7–10, the four youngest, have pools 32–46% full and `P` just below zero and falling; h·(−Ṡ/S) is 0.31–0.70 at the step's start. Cash–Karp's fifth stage takes them to r = −0.01 to −0.13: a downward crossing moved onto a long step.
- *The re-formed ratio on a moved grid is the chain's.* Refuted: at lma × 1.1, 104 of the 126 steps above 1.1 are set by a pool, and the soil's 22 sit at a median h|λ|/β of 0.43.
- Not tested: the gradient on moved grids, the creation ladder, `E_J`, and the chain margin, the pool clip and the per-panel moments' scale. Those three were left out of the rule because at θ₀ they act only on pinned runs away from θ₀, on invaders and on the creation ladder.

**The root causes, by removing each suspect.** Relative error in each gradient on the pair's grid at 1e-3 against the split-32 reference, with one set of steps split four ways. The class-switch steps are the 1e-6 run's switch times mapped onto this grid.

| steps split | steps, days | lma | a_dG2 |
|---|---|---|---|
| none | | −6.2e-3 | −2.2e-2 |
| dry, no crossing within three steps, matched in length to the downward crossing steps | 185, 1512 | −6.4e-3 | −2.2e-2 |
| a class switch into the lower end and no crossing; out of it | 28, 158; 8, 8 | −6.6e-3; −6.4e-3 | −2.2e-2; −2.2e-2 |
| upward crossing | 120, 106 | −7.2e-3 | −2.3e-2 |
| downward crossing, no class switch | 119, 974 | −7.1e-4 | −1.4e-2 |
| downward crossing with one | 66, 546 | −4.5e-3 | −9.1e-3 |
| all downward crossing | 185, 1520 | +5.4e-4 | −4.3e-3 |

At the rate the 66 crossing steps with a class switch remove a_dG2's error, 2.4e-5 a day, the 158 days of class-switch-only steps would remove 3.7e-3; they remove none. But those 66 steps carry three times the error per day of the 119 without, so in a_dG2 a class switch sharing a crossing's step is not separated from it.

- *The positive part widened* to ε = 0.05·P_b (the probe build's `TF24_PROD_EPS_REL`, which moves `J` by +3.9%), under the pool scale, against its own grid at 1e-6 with its crossing and class-switch steps split 16 ways. `J` follows tol as the model does, −0.39 to +0.21·tol, and its nudges at 3e-4 have standard deviation 2.7e-5, against 4.3e-5. From 1e-3 to 3e-5, lma's gradient error is −1.2e-3, +2.9e-4, +2.3e-4 and −1.4e-4 (the model: −1.7e-3, +2.0e-3, +4.5e-4, −7.6e-4), and a_dG2's is −5.7e-3, +2.9e-3, +2.1e-3 and +5.0e-4 (the model: +4.7e-3 and +9.1e-4 at 3e-4 and 1e-4). Its own 1e-6 grid moves 3.4e-4 in a_dG2 when split, against the model's 1.2e-4, and its 1e-4 grid pinned at lma × 0.8 still throws.
- *The guard off* (`TF24_DOMAIN_TOL=1e9`). The pinned × 0.8 run is +1.1e-4 from the full setting at 3e-5; its stages reach r = −0.133, where mortality is 14× its rate at empty. Invaders on a base run at 1e-3 (the solver's own rule, whose `J` moves 2.7e-4 without the guard's retries) are within −1.6e-3 to +4.8e-4 of the same invaders on a base run at 1e-6, from × 0.7 to × 1.2, against −5.1e-4 for the resident itself; × 1.5 and × 2 run too, with nil fitness. With the guard at −1e-4·S_max, × 1.1, 1.2 and 1.5 had failed.

## Done before

- **The second and third replies' tests** are §1 of the consult's two follow-ups: the pool scale, its refinements and nudges, `dJ/dθ` on the runs' own grids, the crossing splits and shifts, the four-component kink estimate, and the transfer of a pinned grid across lma.
- **Step 4 of the stepper** (`docs/archive/scope-imex-stepper.md` §7, step 4, *Result*): the driver reproduces Cash–Karp bit for bit; the held Cash–Karp's `J` error is Cash–Karp's (the kill line); ARK saves 9% of member evaluations at matched `J`, and its embedded estimate misses its long steps' soil error.
- **Steps 1–3 of the plan**, rebased onto #94, and the review of #96 and #97. Each issue, and the archived stepper scope's *Result* sections, record them. TF24 is v12, and throws fell 759 → 149.
- **Invaders with the storage pool** (archived stepper scope §3, *What invaders need beyond A*). Selection gradients work, and capping the step widens the range of invaders that run. With the stage guard off, invaders from lma × 0.7 to × 2 run (*Done last session*), so no pool update that is non-negative at every stage is needed.
- **The stepper's design** (archived stepper scope §4–§6), which step 4 killed. The Appendix holds the alternative it was chosen over.

## Next session

**1. Read the Oracle's reply to the third follow-up against these findings,** test its claims by their cheapest measurements, and restate `OBJECTIVES.md` with the user as at most four criteria with numbers.

**2. With the user's go-ahead, take the stage guard out of TF24,** in the branch that owns the pool (`PLANT-97`). Keep the refusal of a step whose end leaves a pool below zero, and count the stages that go below. Pass: invaders from lma × 0.7 to × 2 on u108 within about three times the base run's own error, measured against the same invaders on a base run at 1e-6, and residents unchanged wherever no stage went below.

**3. The creation axis,** the fourth reply's second measurement: the 108/215/429 ladder under the pool scale and the cap at 1e-4, with values and gradients.

**4. Clean up.** Fix each item in the branch that owns it, then `git rebase --update-refs` and push every moved branch with `--force-with-lease`. Candidates found so far:
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
- *Positivity binds before stability for an explicit pool, and only the stage guard minds:* a step between 2.16 and 3.73 of a pool's relaxation time is stable while its fourth stage is below empty, and a near-empty pool whose stage rates differ in sign goes below zero inside a short step too. The step's combination recovers: with the guard off, pinned runs and invaders keep the base run's error, and every step's end stays above zero.
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
