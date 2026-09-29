# Scope: an implicit–explicit stepper for TF24

**Status (September 2026):** §2.1, §2.3 with its extension to events (R6), and §3's option A are implemented, as aornugent/plant#96, #95 and #97. A's model change is accepted. §4–§6 are the stepper's design, decided September 2026 against the Appendix's alternative, and §7's step 4 killed it: the soil's stages do not carry `J`'s time error, and ARK saves 9% of member evaluations at matched `J` (§7, step 4, *Result*). The steps across the members' switch from growth to drawing down their reserves carry it. Steps 5 and 6 are not built. Exact counts are aornugent/plant#94. See `handover.md`.

The design step 4 tested:
- **One stepper in odelia, driven by a tableau.** Cash–Karp and ARK4(3)6L[2]SA are two tableaus of it.
- **A System may declare a small stiff block:** which components it is, and their rates as a function of that block and the time alone.
  - odelia solves each stage's block by a damped Newton, takes its Jacobian from those rates at a tangent scalar, and puts the root on the sweep's tape.
  - TF24's block is the soil's drainage and infiltration.
  - The plant developer writes those rates and nothing else (§5).
- **Three removals came first.** Together they also give invaders a working, differentiable path.
- **The pool's fast mode goes in the model, not the solver.** A week is added to its relaxation time (§3, decided), because it breaks invaders whatever the stepper.

## 1. How an invader stands in the resident's field

**What exists.** `run_mutant` makes two passes (`scm.h:735`).
1. *The recording pass* re-runs the resident, pinned to its own program, with `keep_field` on (`patch.h:388`). Each rate evaluation records its field in its row (`recorded_field`, `patch.h:65`):
   - the light interpolant;
   - the environment's state, which is the soil;
   - the time.

   There are six rows per step, one per rate evaluation.
2. *The replay* walks that recording with the invader's strategies.
   - `advance_recorded(rec)` (`ode_solver.hpp:219`) steps at each recorded size and hands every stage its row as `const`, so the evaluation loads it (`patch.h:361`).
   - Loading installs the field: `compute_environment` takes the recorded light and soil in place of its own (`patch.h:1064–1090`).
   - An insertion between rows reads the last field installed.

**What goes wrong for TF24.**
- **(a) The invader places the resident's leaf operating points.**
  - The row also carries the resident's leaf operating points, and `load_solved` hands them to the invader's strategies.
  - `solve_leaf` then evaluates the invader's leaf at the resident's collar instead of solving (`tf24_strategy.h:2445`). phylloptim's `replay_operating_point` evaluates at the point it is given; it does not re-solve.
- **(b) The invader cannot shrink a step.**
  - The field exists only at the resident's stages, so the invader is pinned to them.
  - The resident's accepted steps sit at its pools' explicit stability boundary; that is the throw cycle of T4.
  - An invader whose pool is slightly stiffer overshoots.

Measured on `test-mutant.R`'s TF24 fixture (lifetime 6, 20 introductions, constant rain):

| invader | replay on the resident's program | after §2.3 |
|---|---|---|
| identical to the resident | runs, exact | runs, exact (log gap −7e-15) |
| resident and a mutant together | fails: `expected 2, received 1`, from loading the resident's operating points | runs; the mutant's fitness is bit-identical to its fitness invading alone |
| lma × (1 + 1e-9), × (1 + 1e-6) | runs | runs |
| lma × (1 + 1e-4) | fails: storage negative, a pool overshoot | runs |
| lma × 1.001 up to × 1.05 | fails: storage negative | fails: storage negative, (b) |
| lma × 0.99, × 0.95 | runs, but at the resident's operating points, so the result is not the invader's fitness | runs, at its own operating points |

- The mutant's own resident run completes at every one of these traits, so the failures belong to the replay.
- Before §2.3 the suite tested only the identity (`test-mutant.R:153`), which (a) makes exact by construction.

**What an AD-compatible invader needs.**
- its own operating points, stored in its own recording;
- the resident's field in each row of that recording, as doubles. That makes the field exogenous with a zero derivative, which is what a selection gradient wants.
- stiff modes that are stable at the resident's steps.

With all three, the invader's selection gradient is the existing `solve_adjoint` over the invader's own recording, with no new sweep code. The sweep also evaluates where no row applies, so the invader needs the field there too (§2.3).

## 2. Remove first

In this order. Each change is smaller than what it removes. Each keeps a resident's results the same to round-off; 2.3 changes an invader's, which are wrong today.

**2.1 Stops become step targets, not events.**
- *Today:* each of the 2931 active knots is a zero-size pulse. At each one, `run_next` (`scm.h:655–664`):
  1. applies the pulse;
  2. calls `introduce_nodes`, which runs `compute_rates` (`patch.h:1214`);
  3. calls `set_state_from_system`, which runs the member loop again;
  4. calls `push_insertion`, which adds a row to the recording.
- *A stop needs none of that.* `Solver::advance_adaptive` already lands on every time in the list it is given, and carries the rates and the step proposal across (`ode_solver.hpp:92`).
- *The change:*
  - an entry that introduces nothing and changes nothing becomes a target of `advance_adaptive`, and nothing else happens at it;
  - `compute_rates()` goes from `introduce_nodes`, because the solver recomputes the rates when it reads them (`patch.h:1506`).
- *Saves:*
  - two member-loop evaluations per knot and one per introduction, about 7% of the forward run's member evaluations (T7, T8);
  - 2931 insertion rows. Each is a sweep range today, with its own rebind of the patch and its own transposed identity map.
- *Expected:* `J`, the step sequence and the gradient unchanged to round-off, because a rate evaluation is a function of `(y, t)` alone (`patch.h:1042`).

*Result* (plant `855f64ee`, aornugent/plant#96). Every pass line holds.
- `NodeSchedule` holds every resource pulse of zero amount apart from its entries, including one at an introduction's time. `SCM::advance_to` makes their times targets of `advance_adaptive` and ends a forward-Euler span at each. A pinned grid gains them as targets, and a recording keeps its own steps.
- On `test-mutant.R`'s TF24 fixture with 500 zero pulses, `J`, the step sequence and the census gradient are bit-identical on both coordinates.
  - This is measured, not guaranteed: a step that lands on a zero pulse carries across rates evaluated at `t + h`, which can be one ulp from the pulse's time.
  - Rate evaluations fall 3705 → 3205, and a run's time by 12%.
  - Recording rows fall 1049 → 549, and a sweep's time 7.06 → 3.49 s.
- #95 had already removed the evaluation in `introduce_nodes`: the run's path applies an entry through `apply_insertion`, which does not evaluate. This removes the other.
  - At `u429`'s ~9e4 member evaluations, that is about 3%, and the two together are the expected ~7%.
- `refine_schedule` samples a node's competition error at the end of its introduction's interval, which now runs to the next introduction rather than to the next zero pulse.
  - This is arithmetic; the stand was not rerun.
- *Still entries:* a harvest of nothing, and a climate extreme below its threshold.

**2.2 RODAS stays** (decided September 2026).
- It keeps its own stepper beside the tableau stepper of §4, and the two share `ode_linalg.hpp`'s LU.
- So `Method` has three values: `rkck` and `ark` are tableaus of one stepper, and `rodas` is RODAS.

**2.3 Forward passes store; only the sweep loads** (implemented September 2026; aornugent/plant#95).

*Only `run_mutant` replays rows* (`scm.h:768`). Every other forward replay walks a program of sizes and solves (`scm.h:697`, `1350`, `1398`).

*Triage: tier 2.* The change is in odelia's walk and the Patch's field handling. Recordings live in memory for one call, so no stored format changes.

*Requirements.*
- R1: the identical invader stays exact. Its log gap is 4e-15 on the TF24 fixture today.
- R2: a resident and a mutant together run. Today they fail with `expected 2, received 1`.
- R3: an invader's sweep agrees with a pinned difference of its fitness. Today it cannot be asked for: the replay keeps no states and records no insertion rows, and `store_trajectory()` re-runs the invaders as residents.
- R4: residents are unchanged: the FF16 references bit for bit, and TF24's forward runs and sweeps.
- R5: a replay keeps states only when a gradient is asked for (`record_trajectory`).

*The scarce resource: evaluations that no row covers.* On the fixture (311 steps, 20 introductions) the sweep makes 1866 rate evaluations. 331 of them fall outside any row: each step's first rates, which the sweep re-derives, and each introduction's map. The forward replay makes 40 such evaluations: each introduction's map and the rates after it.

*The floor is the plan as first written:* seed the rows, and keep the last row's field on the Patch between rows. It fails R3 on those 331 evaluations, because the sweep walks backward and the field left on the Patch belongs to another instant.
- A fresh rebind holds no field, so the top range's first rates use the invader's own field without any error.
- Positioning the patch for the first introduction's transpose then fails the Patch's time check.

*Candidates.*
- **A** (first thought): the floor. It fails R3 at 331 of 1866 evaluations.
- **B**, address every evaluation in odelia.
  - The mechanism: the sweep's first rates load the row below's last slot, and an introduction records its map's evaluation in its own row.
  - It pays for R3, but every row's last slot must then be a full evaluation at its state. The rates after an introduction become a full `derivs`, which moves TF24 residents (R4), and `run_next`'s `introduce_nodes` and the sweep's `apply_insertion` must become one map.
  - It wins when a second exogenous input appears beside the field, or after 2.1 has made the insertion path one.
- **C**, seeded rows plus the recorded field at each step's end, in plant.
  - The mechanism: an evaluation uses its row's field. Every evaluation outside a row is at the end of a recorded step (the first rates, the introductions' maps, the sweep's positioning), so it uses the field recorded there.
  - It pays for R3 with one Patch member, built per invasion from the recording, at the cost of one copy of one field per step.
  - It is bad at an evaluation between recorded instants.
  - It wins when the field is the only exogenous input and every evaluation outside a row is at a step's end, which is the case today.
- **D**, the invader as a species of zero weight in the resident's own run, so no field is recorded at all.
  - It costs a species kind that the reductions skip, which is a runtime flag, and one resident run per invader.
  - It wins when invaders are few and each needs its own steps.

*Winner: C.* A fails R3, B breaks R4, and D adds a species kind and a resident run per invader.

*Superseded in part (§2.3, extended):* events give one instant two fields, which C's table cannot hold. B's cost (two insertion maps) is then removed by making them one map, and B wins.

*The commitment: a forward pass always stores, and only the sweep loads.* It is kept by `Step::step` taking only a mutable row. The one `const` row left in odelia is `step_adjoint`'s.

*Kill question:* would the design be unneeded if invaders' recordings never had to be swept? That would drop R3, but selection gradients are what the invader path is for (§1). The design survives.

*What each part is there for.*
- The per-evaluation row field serves R1 and R2: it is what the stages use.
- `field_slot` and `keep_field` exist because the recording pass writes fields and a gradient recording must not.
- The table of step-end fields serves R3.
- `SCM::invade()` serves R3: `store_trajectory()` repeats an invasion rather than running its invaders as residents.
- The replay recording its insertion rows serves R3: the sweep narrows the patch at those rows.
- *Deleted:*
  - the field kept between rows, with its lifetime warning;
  - the copy of the field;
  - `Step::step`'s `const`-row form;
  - `reshape_to`'s evaluation, which `set_recorded_state` repeats straight after, and which would look the field up at a stale time.

*Price.*
- An evaluation at an instant where the recorded run ended no step (dense output, an event inside a step) finds no field and raises an error.
- An invader still cannot take its own steps ((b); §3).
- The table holds one field per step, about a sixth of the fields the recording holds.

*Kill condition:* an invader needs its field between recorded instants, on its own steps or for dense output. Then the field becomes an interpolant in time, which is a different model, or B.

*The design.*
- **odelia.**
  - `Step::step` takes `solved_row&`.
  - `step_by` and `stepper_step` take `const solved_row* seed`. The scratch row starts as a copy of it, or empty without one, and RODAS refuses one.
  - `advance_recorded(rec)` seeds each step with its row.
  - Both `advance_recorded` overloads record the insertion rows they apply.
- **plant `Patch`.**
  - `store_solved`: an evaluation whose row holds a field uses that field; otherwise, with `keep_field`, it writes its own into the row. `load_solved` uses the row's field, and `end_solved` clears both.
  - `step_end_fields`, shared and `const`, holds the field at each step's end, and none at the start.
  - `compute_environment` uses the row's field, else the table's entry at `environment.time`, raising an error when there is no entry, else builds its own.
  - `reset()` clears the table, and the rebind copies it.
  - `reshape_to` no longer evaluates.
- **plant `SCM`.**
  - `run_mutant` records (unchanged), installs the invaders, and calls `invade()`.
  - `invade()` keeps states when `record_trajectory` is set, resets, builds the table from the recording, and walks the recording.
  - `store_trajectory()` calls `invade()` again on an invaded SCM.

*Tests, landing with the change.*
- plant, `test-mutant.R`:
  - the TF24 identity, unchanged;
  - a resident and a mutant under TF24, where the copy of the resident has the resident's fitness and the mutant has the fitness it has when invading alone;
  - on the birth-date coordinate, `census_trait_gradient_tf24` over an invader's recording against a central difference of its census, where each side of the difference is a replay of the same recording.
- odelia: a seeded replay stores its own values beside what it was seeded with, and its recording has the rows of the run it replays, insertions included.

**2.3, extended: an invader is an exact replay** (September 2026).

*R6: an invader is an exact replay of the recorded run.* At every schedule entry it applies the same events, in the same order, before the same introductions. Its evaluations after an entry use the field after the entry. Otherwise invasion fitness means nothing.

*Measured on `de4809fe`:* the identical invader on the TF24 fixture, its log fitness against the resident's.

| schedule | log gap |
|---|---|
| no events | −7.1e-15 |
| a resource pulse of 0.05 at t = 2.5 | −1.2e-7 |
| a 50% harvest at t = 3.5 | +0.69 |
| a lethal climate extreme at t = 3.5 | +1.34 |

*Two causes:*
- The walk's insertion map, `Patch::apply_insertion`, applies an entry's introductions but not its events; `run_next` applies both (`scm.h:661`). So no invader cohort is ever harvested or killed by an extreme.
- The field recorded at a step's end is the field before the entry's events, and an invader's first rates after the entry use it. With events one instant has two fields, and §2.3's table, keyed by time, cannot hold both.

*The same split elsewhere:*
- *The tangent referee* walks a program through the same map, so it integrates a run without its events. On the one-species ladder stand with a 50% harvest, the run's leaf area is 0.413 and the tangent pass reaches 0.798, the value without the harvest.
- *The sweep* transposes the map without the events. Measured on residents against a difference pinned to the run's times (one-species ladder stand, `k_I`):
  - with no event, with a pulse, or with a harvest where nothing is introduced: 2.2e-10;
  - with a harvest at an introduction's instant: 2.0e-6. The run's new cohort takes its inflow value after the harvest, and the sweep's map takes it before;
  - with a pulse into a saturated layer, whose increment the state sets: 6.3e-9.

*The inflow rule (decided September 2026).* At an entry that applies events and introduces cohorts, a new cohort takes the inflow value the patch holds before the entry's events.
- Harvests and climate extremes no longer rebuild the field; pulses never did.
- Residents move only at such entries. On the TF24 ladder stand with three cohorts and a 50% harvest, the new cohort's log density moves by 6.4e-4.
- Without the rule an invader cannot reproduce the resident there. It evaluates the inflow only in a recorded, closed field, and no row holds the resident's post-event field.

*The data structure.* A trajectory is a vector of rows, and a row is the only handle on a recorded state.
- A row is a `step_record`: the time, a step's size or an entry, the state, and `solved = {stages[5], at_state}`. `at_state` is the evaluation at the row's state: a step's end, the rates after an entry, or the run's first rates.
- Every evaluation at a recorded state is addressed to a slot of the row that holds that state. It repeats the evaluation that wrote the slot: the same solves, in the same order, at the same time.
  - A step's `at_state` ran at `fl(t + h)` from the row below; every other slot ran at its row's time.
  - So a partial load (the field and the inflow value without the rates) cannot be addressed, and every load becomes a full evaluation.
- A slot's field is an input, not a choice. A slot that holds a field is evaluated in it, in every pass. Otherwise the evaluation builds its own field, and a pass with `keep_field` stores it in the slot. The field is a shared pointer, null where there is none.
- The Patch applies the schedule's own entries. `apply_insertion(t)` applies the entry's events in schedule order, then pushes one node per species it introduces. `run_next`, every walk and the sweep use it; the sweep evaluates the row below first.

*What follows.*
- One walk over rows of any System whose slots have the same type, seeding each slot from its row. It serves the invasion, the tangent referee, the replay from a range and pinned runs.
- A pinned run's rows are built from the schedule's entries and `Parameters$ode_times`, and its map also records events and history.
- After an entry the solver evaluates at the recorded time. It used to read the System's clock, which differs from the recorded time only where `fl(t + h)` differs from a clamped step's end: none of 918 steps over five stands.
- An SCM is an invasion once `invaded_run` is set. `run()` then repeats the invasion, so `store_trajectory()` needs no branch.
- `run_mutant` builds the invaders' schedule from the resident's events and `p`'s introductions. Its recording pass is an ordinary run with `keep_field`, because rows commit only accepted attempts.

*Deleted:*
- odelia: `SolvesForValues` and its branches, since declaring `solved_values` is the opt-in; the second `advance_recorded`; `program_from`; `state_at_range`.
- plant:
  - `KeepsSolvedChoices`, `recorded_field::kept`, `set_state_and_boundary` and `set_recorded_state` (odelia calls `reshape_to` and then evaluates);
  - the step-end table and its four names, `invade()` and `set_introduction_times`;
  - the field builds in `apply_event` and, on the run's path, in `introduce_nodes`;
  - `program_within` and `run_next`'s pinned branch;
  - the field record in heights (`interpolators_state`);
  - `Patch::reset()`'s per-evaluation clears.

*Kept:*
- `solved_values`;
- `solved_scope` with `store_solved`, `load_solved` and `end_solved`: an evaluation spans the load and the rates, and TF24's leaf solves sit four calls down;
- `keep_field`: a field is about 200 doubles, six per step;
- `reshape_to`;
- the sweep's ranges.

*Pass:*
- The identical invader recovers the resident's fitness bit for bit:
  - with no events;
  - under each of the three;
  - at an entry where a harvest meets an introduction.
- An invader's sweep across a harvest agrees with a pinned difference and with its tangent.
- A resident's sweep across a harvest at an introduction agrees with a pinned difference.
- FF16's references and resident runs are bit-identical, except at entries where events meet introductions. Resident sweeps are too, or the difference is measured and explained.
- A run pinned by `Parameters$ode_times` is unchanged.

*Result* (plant `15fe136f`, odelia `a05f5c2`). Every pass line holds.
- The identical invader has the run's fitness bit for bit in all five cases, and its event log is the run's.
- An invader's sweep across a harvest at an introduction agrees with a difference of invasions to 7e-10, and with its tangent to 1e-15.
- A resident's sweep across a harvest at an introduction agrees with a pinned difference to 1.9e-10 in `k_I`, against 2.0e-6 on `de4809fe`.
- The tangent referee under a harvest reaches the run's census exactly.
- Resident runs, resident sweeps, FF16's references and pinned runs are bit-identical to `de4809fe`, except at entries where an event meets an introduction, which the inflow rule moves.
- *A third cause, found in the build.* The recorded field went through heights, and `u_k·top/top` and `(m/top)·top` can each land an ulp off. TF24's leaf solve amplified one such ulp, in a crown's mean light, to 5e-9 in a log density. The field is now recorded as the interpolant holds it: the knot values, the slopes and the canopy top. TF24's cohort reads use the same pair.
- *Kept, against the plan:* `NodeSchedule`'s pinned steps and their R interface. The events path installs `p$ode_times` there as a grid and drops the sizes, so moving the steps onto the parameters needs a flag or a change in what such a run does. A pinned run is still one walk, of `NodeSchedule::program()`.
- *Refused now:* an invader introduced where the run introduced nothing, which used to be skipped; and forward Euler for an invasion, before anything is recorded.

**2.4 An invader's environment state** is integrated and then overwritten at every stage by the field it stands in.
- It is harmless, so it stays for now.
- A later subtraction could give an invader no environment state at all.

## 3. The pool is a modelling decision first

**The facts.**
- A seedling's pool relaxes in hours: `λ = (charge + drain)/S_max` reaches 1444 yr⁻¹ (T3), against daily forcing.
- Integrated explicitly, it costs the throw cycle and the stability credit: 12 of the 51 points of `u429`'s bound (§6).
- It breaks invaders, (b) above, with any stepper, because an invader cannot shrink the resident's steps.

**Option A, the model: add `τ_s` to the pool's relaxation time.**
- The rate becomes `Ṡ = [c(1 − r) − d·r] / (1 + λ·τ_s)`.
- *What stays:* the equilibrium and both bounds. At `r = 0` the rate is ≥ 0 and at `r = 1` it is ≤ 0, as now.
- *Who is affected:* only members with `λτ_s` near 1 or above, which is the newest few.
- *What it buys:* the flow's relaxation rate becomes `λ/(1 + λτ_s) ≤ 1/τ_s`, and the gate's slope adds to it (*Result*). At `τ_s = 7` days, explicit steps up to about 26 days are stable, for residents and invaders alike.
- *Cost:* about five lines in `TF24_Strategy::compute_rates` and one parameter. It is declared, and its effect on `J` and `dJ/dθ` measured, as the window's was (+1.26% in `J`).

**Option B, the solver: make the pools implicit inside the member loop.**
- *It can be exact.* Net production never reads the pool (`tf24_strategy.h:1913–1978`), so each member's pool root can be solved between its leaf solve and the storage tail.
- *It costs two things:*
  - the stage coefficient has to reach the strategy;
  - positivity. The ESDIRK's second stage is a trapezium half-step, so a stiff mode's stage value reflects its displacement from its quasi-steady state:

| stage | negative past `hλ` | as `hλ → ∞` |
|---|---|---|
| 2 | 4.0 | −1.00 |
| 3 | 6.6 | −0.77 |
| 4 | 4.1 | −0.08 |
| 5 | 3.1 | −0.16 |

- *Who is exposed:* a pool above its quasi-steady state goes negative mid-step, for example a member created at `0.8·S_max` with negative production. A resident retries that step; an invader pinned to the resident's steps cannot.

**Decided: A** (September 2026). It is implemented, and its moves in `J` and `dJ/dθ` are accepted.

**B is not pursued.** Its implicit stages take a draining pool below zero past `hλ` = 3.1 (stage 5 above; stage 2 at 4.0). For a seedling at `λ` = 188–1444 yr⁻¹ that is a step of 0.8–6 days, against at least 15 days for every pool under A. So B would not let invaders run, and its one gain is keeping v11's model. It would also need the tableau stepper (§4) and the stage coefficient passed down to the strategy.

*Result* (plant `b4b5febf`, aornugent/plant#97). The table's invaders run, and the moves in `J` and `dJ/dθ` are accepted. Throws fall by 80%; they are not eliminated.
- `storage_relaxation_offset` = 7 days is one TF24 parameter with a gradient column, and a negative value is refused. At 0 the model is v11's bit for bit. TF24 is v12.
- The rate is `[c(1 − r) − d·r]/(1 + λτ_s)` with `λ = (c + d)/S_max`, to 9 digits at every sampled state.

| long-drought stand, birth date | v11 | v12 |
|---|---|---|
| `J`, 108 / 215 / 429 uniform nodes | 12.4167 / 12.4212 / 12.4069 | 12.6656 / 12.7421 / 12.7436 (+2.0 / +2.6 / +2.7%) |
| `dJ/dlma`, 108 nodes: adjoint (pinned central, `d` = 1e-4) | −168.556 (−168.462) | −195.988 (−195.975) |
| `dJ/dτ_s`, 108 nodes | | −22.074 (−22.072) |
| accepted steps, 108 nodes | 10 513 | 9312 |
| attempts rejected for accuracy / thrown | 1874 / 759 | 1910 / 149 |

- *The table's mutants (§1).* On the fixture's height coordinate, `lma` × 1.001 to × 1.05 now run on the resident's program, and × 1.2 still overshoots. On birth date all run, × 1.2 included. The fixture's throws fall 54 → 7 on height and 9 → 1 on birth date.
- *Positivity binds before stability.* For `y' = −y/T`, Cash–Karp's fourth stage goes negative past `h = 2.16T`, and the step loses stability past `3.73T`. At `T = τ_s` that is 15 days against 26.
  - Two thirds of the 149 throws are at steps above 15 days (median 17.5 days).
  - The other 50 are shorter steps in which a near-empty pool's rate changes sign, and the method's negative stage coefficients carry that into a negative stage.
  - Zero throws is out of reach for a pool integrated by the tableau (below), and B does not reach it either.
- *The gate's slope.* A draining seedling's relaxation, `−∂Ṡ/∂S`, falls 380 → 55 yr⁻¹ against `1/τ_s` = 52. While a pool fills, the gate's slope adds up to 6λ, and the rate reaches 2.3/τ_s at `r` = 0.3.
- *Elsewhere `J` moves* −3.3% and −4.6% on the five-year birth-date pins. On the height pins it moves −24%, where the compression term amplifies any change to the pool (`test-strategy-tf24.R`, "offspring arrival").
- *Also moved:* the whole-run gradient reference, TF24's seeded stochastic count (77 → 79) and the model-version snapshot.
  - TF24f approaches TF24 monotonically only against a TF24 converged in time. At the default tolerance TF24's own error, about 0.1% on its longer steps, exceeds the lag at `k_acclim` = 100.

*What invaders need beyond A* (measured on v12). An invader walks the resident's accepted steps and cannot shrink one, so every stage of those steps must keep the invader's pool non-negative.
- *Selection gradients need nothing more.* They are taken on the identical invader, which is exact, and near neighbours run: `lma` × 1.01 on the long-drought stand, and × 0.95 to × 1.05 on the fixture.
- *Capping the resident's step* (`ode_step_size_max`) extends the range, at a cost in steps. On the long-drought stand (108 nodes):

| cap | accepted steps | throws | invaders that run |
|---|---|---|---|
| none | 9313 | 149 | none of × 0.9, 1.1, 1.2, 1.5 |
| 14 days | 9329 | 98 | × 0.9 and × 1.01; not × 1.1 |
| 7 days | 9683 | 15 | × 0.8 and × 1.1; not × 0.5, 1.2, 1.5, 2 |
| 3.5 days | 10 977 | 5 | × 0.8 to × 1.5; not × 0.5 or × 2 |

- On the fixture, a 14-day cap runs every invader from × 0.5 to × 3 on both coordinates, at 17% more steps, and the resident throws nothing.
- *What a cap cannot remove.* With the 3.5-day cap, × 0.5 fails on a 1-day step and × 2 on a 0.37-day step, where linear relaxation cannot overshoot (`h/T` ≤ 0.14). A near-empty pool whose stage rates differ in sign goes below zero through the tableau's negative coefficients, at any step length.
- *What would remove it:* a pool update that is non-negative at every step.
  - No Runge–Kutta method above first order is (Bolley–Crouzeix), so the tableau cannot supply one.
  - One candidate: each stage relaxes the pool exactly toward its quasi-steady state, `charge/(charge + drain)` of capacity, with the charge and the drain held from the evaluation before. The stage value then lies between the pool and that state, inside `[0, S_max]`.
  - Applied to resident and invader alike, it keeps the identical invader exact.
  - It is a question for §4's stepper, which already treats components differently. Untested.
- *Not a fix:* carrying the pool as `log r`. It is positive by construction, but an explicit step that refills a near-empty pool multiplies it by `exp(hλS*/S)`.
- *The caps also show `J`'s time error on long steps.* `J` is 12.6784 and 12.6798 under the 3.5- and 7-day caps, and 12.6656 uncapped: about 0.1%.

## 4. One stepper, two tableaus, a declared stiff block

**What sets the step on v12** (Cash–Karp, u108, tol 1e-3 unless stated; `harness/v12_steps.R`).
- The soil binds 90.5% of accepted steps: 89.1% on u429, against 75.7% on v11's u429. The pools bind 2.7%, and throw on 1.6% of attempts.
- 29.5% of accepted steps sit at `h|λ_soil| ≥ 0.8β` and 13.3% beyond `β`.
  - The median error ratio rises 0.014 → 0.077 → 0.21 → 0.25 across the bands below 0.5β, 0.5–0.8β, 0.8–1β and 1–1.2β.
  - Past 1.2β it falls to 0.013, where drainage sits on its quasi-steady state.
- `J`'s time error does not follow the tolerance:

| tol | 1e-2 | 3e-3 | 1e-3 | 3e-4 | 1e-4 | 3e-5 | 1e-5 |
|---|---|---|---|---|---|---|---|
| `J` relative to tol 1e-6's (12.668637) | −2.1e-4 | +2.5e-3 | −2.4e-4 | +1.0e-3 | +8.2e-4 | +2.2e-4 | +3.8e-5 |
| accepted steps | 8018 | 8543 | 9312 | 10 428 | 11 813 | 13 833 | 16 185 |

  - `J` stays within 1e-4 of the reference only from tol 1e-5, at 74% more steps than at 1e-3. The steps grow as `tol^−0.10`.
  - On u429, tol 1e-2 … 1e-4 give 12.7452, 12.7497, 12.7436, 12.7518 and 12.7478: non-monotone, a spread of 6.4e-4.

**The stepper.** `Step` becomes tableau-driven.
- *Cash–Karp as data, and bit-identical.* Sums run over nonzero coefficients in ascending stage, with `h` applied after the sum. A one-term row is applied as `(a·h)·k`, the rounding the FF16 references were blessed on (`Step::stage_state`). The hand-written sums, the static constants and the stage-0 arms go.
- *ARK4(3)6L[2]SA as data.* The coefficients are SUNDIALS' `ARK436L2SA`, whose order conditions `harness/ark436.R` checks to 1e-16. Its explicit and implicit parts share `b` and `b̂`, so a step's end and its estimate are sums over full rates, as Cash–Karp's are.
- *`Method` chooses the tableau:* `rkck`, `ark`, and `rodas`, which stays a stepper of its own (§2.2).
- The recording keeps six rows per step, five stages and the end, under both tableaus.

**The stiff block.** A System may declare two members, checked as a concept with `if constexpr`:

```cpp
// Which components are stiff, and their stiff rates as a function of those
// components and the time alone.
std::pair<std::size_t, std::size_t> stiff_block() const;  // offset, size
template <class U>
void stiff_rates(const U* y, double time, U* rate) const;
```

- The rates read nothing active. odelia instantiates them at `tangent_scalar<double>`, so rates that read an active member do not compile.
- A System without the members integrates with the tableau's explicit part.

**Each stage, forward.** odelia:
1. forms `Z_i = y + h Σ_j a^E_ij k_j`, and on the block adds `h Σ_j (a^I_ij − a^E_ij) k^I_j`;
2. solves the block's `Y = Z + hγ F_I(Y, t_i)` by Newton at double, from `Y = Z`:
   - the Jacobian is `stiff_rates` at `tangent_scalar<double>`, one pass per block component;
   - the linear solve is `ode_linalg.hpp`'s LU;
   - a Newton step is halved until the residual falls, which keeps it from cycling at drainage's kink at saturation;
   - a solve that does not converge raises `DomainError`, and the step is retried smaller, as a throw is today;
3. evaluates the full rates once at `Y`: the one member loop;
4. takes `k^I_i = F_I(Y, t_i)`.
- The first stage is explicit, and its `k^I` is `F_I` at `y`.

**The sweep.** The same stage template, at the adjoint scalar.
- Newton runs again in double from the tape's values of `Z`, so the roots are the run's, bit for bit.
- The block enters the tape as `Y = Y* − M·(G − to_passive(G))`:
  - `G = Y* − Z − hγ F_I(Y*, t)` is taped at the root, and `M = (I − hγJ)⁻¹` is passive;
  - the correction's value is exactly zero, so the sweep repeats the run's stage values bit for bit. `Y* − M·G(Y*)` would not: `G(Y*)` is Newton's residual;
  - its derivative is `M·(dZ + hγ dF_I)`, the implicit function theorem's.
- The same line is the stage at double and at a tangent scalar. Nothing beyond it is recorded.

**For TF24, the block is the soil's five layers**, with `F_I,ℓ = (in_ℓ − K(θ_ℓ))/Δz`, where `in_1` is the infiltration and `in_ℓ = K(θ_{ℓ−1})`.
- It reads only the soil, the rain and coefficients typed `double`.
- Uptake, the members, `E` and the accumulators stay explicit. So does the `θ_res` guard, which acts on the full rate.

| property | ARK4(3)6L[2]SA | Cash–Karp 5(4) |
|---|---|---|
| order / embedded | 4 / 3 | 5 / 4 |
| rate evaluations per step | 6 | 6 |
| explicit part's real stability boundary | 4.23 | 3.73 |
| implicit part | L-stable and stiffly accurate | — |
| embedded method as `hλ → −∞` | `R̂ = −0.15` | — |
| widest gap between abscissae (the stops stay) | 0.332 h | 0.3 h |

**Against the multirate branch's IMEX:**

| | the branch's IMEX | this stepper |
|---|---|---|
| method | RODAS4 on the soil | the stepper above |
| Jacobian | the soil's, differenced through the full rate evaluation | none through the members |
| member-loop evaluations per step | 19 | 6 |
| linear algebra | a dense `N × N` LU, `N = 3443` | a 5 × 5 LU |
| accuracy | effective order ~2, because its Jacobian was noisy | independent of Newton's Jacobian |
| cost | 20–50× Cash–Karp | Cash–Karp's |

**Risks.**
- *The embedded estimate is not L-stable* (`R̂(−∞) = −0.15`). If step 4 shows the soil setting the step after rain knots, filter the block's estimate through `(I − hγJ)⁻¹`; the Jacobian is at hand.
- *The explicit part's boundary is 4.23.* Uptake is at most 111 yr⁻¹ over 100 sampled states, so it binds only past 14-day steps.
- *The pools stay explicit, and positivity limits them before stability does.* ARK's explicit stage 2 takes a decaying mode below zero past `h = 2.0T` (`harness/ark436.R`). A draining pool's `T` is about 7 days under §3's A, so it limits the step at about 14 days.
  - Dry-leg steps (median 2.1 days under Cash–Karp) lengthen once the soil no longer limits them. So throws may return there, and an invader walking the resident's longer steps overshoots sooner.
  - Cope: `ode_step_size_max` near 14 days for TF24.
- *Newton at the soil's kinks.* The damping and the step's rejection cover it; step 4 counts the failures.
- *Order 4 over 5.* The steps are not accuracy-limited (T1).

## 5. What a plant developer writes

The stiff block is the only new thing, and it is physics: which components are stiff, and their stiff rates.

- `TF24_Environment`: `stiff_block()` and `stiff_rates`, the drainage and infiltration moved out of `compute_rates`. `compute_rates` calls `stiff_rates` and subtracts the uptake, so the fluxes are written once, and the clamp tallies stay in `compute_rates`.

```cpp
// The soil's drainage and infiltration, which relax the layers in minutes;
// taken implicitly at each stage. Uptake stays in compute_rates.
std::pair<size_t, size_t> stiff_block() const { return {0, soil_number_of_depths}; }

template <class U>
void stiff_rates(const U* theta, double time, U* rate) const {
  U inflow = rainfall(time) * infiltrated_fraction(theta[0]);
  for (size_t i = 0; i < soil_number_of_depths; ++i) {
    const U outflow = conductivity(theta[i], i);
    rate[i] = (inflow - outflow) / dz[i];
    inflow = outflow;
  }
}
```

- `Patch`: forwards both, present only where the environment declares them, and adds its species' width to the offset.
- `Control`: `ode_method`.
- Nothing for invaders. An invader's soil is replaced by the field it stands in at every evaluation (`Patch::compute_environment`), so its own block solve is harmless (§2.4).
- *When to declare a block:* a cheap part of the rates relaxes much faster than the steps the model needs, and reads only its own components and the time.

**The implementation is reviewed against this section and the handover's principles**, with the `code-review` skill, at steps 5 and 6.
- The developer writes rates and two declarations: no stage equation, slope, bracket, input list or return-type rule.
- The comparison is the Appendix, which puts those in the developer's code.

## 6. What it should save

Upper bounds on u108 at tol 1e-3 (`harness/soil_bound.R`), against Cash–Karp with zero pulses as step targets: 9312 accepted steps and about 3.7e6 member evaluations, 18% of them on rejected attempts.

| | accepted steps | member evaluations saved |
|---|---|---|
| the soil's stability limit removed, legs filled | 6148 | 41–46% |
| legs filled, with no stability credit | 8538 | 18–25% |
| Cash–Karp held at `h\|λ_soil\|` ≤ 0.8β / 0.5β | +30% / +69% | — |

- *Method.* Each accepted step is re-taken in R with the solver's arithmetic, which reproduces its error ratio at all 9312.
  - Its ratio is recomputed without the soil layers at `h|λ|` ≥ 0.5β, and each leg is filled with `⌈Σh/a⌉` steps at the local limit `a`.
  - It assumes no rejected attempt. The lower figures keep 40% of the inaccurate ones, their forcing-driven share on v11. The pools stay in the norm.
- *The stability credit itself is 21 points*, as on v11.
- *At matched `J` the gate compares against Cash–Karp at tol 1e-5*, where its error first stays within 1e-4: about 6.4e6 member evaluations on u108.
- The v11 bounds (T8, `soil_only_ideal.R`) are superseded.
- The cost per member evaluation is untouched. There, the warm-started leaf solve is the lever.

## 7. Order of work

`scope-schedule-controller.md` §6 interleaves these steps with exact counts and the controller; this is the stepper's own sequence.

1. **Stops as targets (plant).** Done, aornugent/plant#96.
   - *Pass:* `J`, the steps and the gradient unchanged to round-off; about 7% fewer member evaluations; fewer sweep ranges and less sweep time.
2. **Seeded rows (odelia and plant).** Done, aornugent/plant#95.
   - *Pass:*
     - the identity invader is still exact;
     - a resident-and-mutant invasion runs;
     - an invader's sweep agrees with a pinned difference of its fitness.
     - the identical invader is exact under each kind of event (R6, §2.3 extended).
3. **The pool (plant): option A.** Done, aornugent/plant#97. The moves in `J` and `dJ/dθ` are stated and accepted, and the table's mutants run. Throws fell 759 → 149, not to zero (§3, *Result*).
   - *Pass for A:* the moves in `J` and `dJ/dθ` stated; zero throws; the table's mutants run on the resident's program.
4. **A prototype driven from R** (plant-dev harness), on v12 with zero pulses as step targets.
   - One driver walks the SCM's schedule with odelia's controller law, in three configurations:
     1. Cash–Karp, which must reproduce the SCM's run bit for bit on u108;
     2. Cash–Karp held at `h|λ_soil|` ≤ 0.8β, which tests whether the soil's stages carry `J`'s time error;
     3. ARK4(3)6L[2]SA, with the soil's block solved by §4's damped Newton.
   - *Pass:*
     - Cash–Karp reproduced bit for bit;
     - ARK's `J` error decreases with tol over 1e-2 … 1e-4, and is within 1e-4 of the 1e-6 reference at 1e-4;
     - at the first tolerance from which each method stays within 1e-4 of the reference, ARK uses at least 30% fewer member evaluations;
     - ARK throws no more than Cash–Karp at the same tolerance, and its stages' clamp crossings (T6) fall to their floor;
     - its Newton failures are counted.
   - *Kill:* if the held Cash–Karp still does not converge in tol, or ARK's `J` does not follow it, the soil's stages are not the cause. Stop, and look at the pools' gate slope and the members' switches.

   *Result* (`harness/ark_prototype.R`, u108). The kill line holds.
   - Cash–Karp is reproduced bit for bit. `J` and every attempt tally equal the SCM's at all eight tolerances, and at 1e-3 so does every step's time, size, error ratio and binding component.
   - The held Cash–Karp does not converge in tol, and from 3e-4 down its `J` error is Cash–Karp's. Every held step starts at or below 0.8β; at 1e-4, 0.4% end beyond β.
   - ARK's `J` error falls with tol from 1e-2 to 1e-4, but is −4.9e-4 at 1e-4 and +8.4e-4 at 3e-5. It stays within 1e-4 only from 1e-5, where Cash–Karp does too, and there it saves 9% of member evaluations.
   - ARK throws more than Cash–Karp at every tolerance, 161 against 149 at 1e-3 and 40 against 4 at 1e-6. Its stages cross no soil clamp from 1e-3 down. No Newton solve fails: 3.7–4.5 iterations each, at most 21.

   | tol | 1e-2 | 3e-3 | 1e-3 | 3e-4 | 1e-4 | 3e-5 | 1e-5 | 1e-6 |
   |---|---|---|---|---|---|---|---|---|
   | `J` relative to Cash–Karp's at 1e-6: Cash–Karp | −2.1e-4 | +2.5e-3 | −2.4e-4 | +1.0e-3 | +8.2e-4 | +2.2e-4 | +3.8e-5 | 0 |
   | held | −4.6e-4 | +7.8e-4 | −7.7e-4 | +1.0e-3 | +8.0e-4 | +2.5e-4 | +4.3e-5 | |
   | ARK | −0.41 | −0.19 | −7.6e-2 | −1.0e-2 | −4.9e-4 | +8.4e-4 | +2.7e-5 | −6.8e-5 |
   | member evaluations (1e6): Cash–Karp | 3.42 | 3.52 | 3.70 | 4.07 | 4.64 | 5.48 | 6.41 | 9.17 |
   | ARK | 1.30 | 1.51 | 2.09 | 2.80 | 3.58 | 4.64 | 5.84 | 9.53 |

   *Why the soil's block does not pay.*
   - A layer relaxes as fast as it changes. Drainage goes as `θ^16.14`, so a layer's rate falls with its moisture, and after rain it is about one over the time since the rain: along the reference, `λ` times that time has median 0.78 over the first two months. A step as long as the time since rain is at `hλ` ≈ 1, and taking the layer implicitly does not lengthen it.
   - ARK's embedded estimate misses the layers' error on longer steps. Retaken from its own state, its 11.2-day step at t = 4.75 (`h|λ|` = 5.6β) has the top layer's error at 11.5 times the tolerance against an estimate of 0.75, and the fourth layer's at 6.9 against 0.03. That step drains the top layer 0.014 too far, and every member's offspring increment falls 0.6–0.8%.
   - §4's cope for the estimate, filtering it through `(I − hγJ)⁻¹`, would shrink it: here it is too small, not too large.
   - §6's bound assumed the soil sets no accuracy limit of its own. At 1e-3 ARK uses 43% fewer member evaluations than Cash–Karp, at a `J` 7.6% low.

   *What carries `J`'s time error: the steps across which a member's net production changes sign* (`harness/j_error_trace.R`, and the driver's `SWITCH_DAYS`).
   - The error is in the members' offspring integrals, +8.7e-4 of +8.2e-4 at 1e-4. It accrues from t = 12 to 20, in the dry legs between rains, and mostly in members born before year 3.5, who hold 93% of `J`.
   - As the soil dries, a member's net production `P` falls through zero, and rises back after rain: 9220 sign changes in a 1e-4 run, or 921 events counting those within a quarter-day as one.
   - TF24 grows and reproduces on `P`'s smooth positive part, `½(P + √(P² + ε²))`, with `ε` = 1e-4 against a `P` of tens. So growth, fecundity and the storage flow's slope turn within about 5 s of model time at the median crossing.
   - Cash–Karp's error estimate misses the error of a step across that turn. In the ten intervals where the offspring error grows most, 14 of the 15 steps across a sign change have a true error over twice their estimate (median 4.6 times), against 4% of the 94 others, and they carry 81% of the offspring error.
   - Refusing a step longer than 0.05 days across a sign change makes `J` follow the tolerance: −3.1e-4, −1.1e-4, −2.3e-5, +5e-7 and −5.8e-6 at 1e-3 … 1e-5, against its own 1e-6 (12.668784, 1.2e-5 above Cash–Karp's).
   - Refusing the same steps where `P` crosses 3 instead does not: −4.8e-5 at 3e-4 and −2.1e-4 at 1e-4.
   - The refusal halves a step until it is short, which costs four times the member evaluations. It locates the cause; it is not the fix.
5. **The tableau stepper and the stiff block (odelia).** Not built: step 4 killed the stepper. Cash–Karp's constants and hand-written sums become its tableau first.
   - *Pass:*
     - Cash–Karp bit-identical: odelia's snapshots and the FF16 references;
     - ARK at order 4 on a smooth problem, and stable on the stiff van der Pol runner the RODAS tests use, with its stiff component declared;
     - tangent and adjoint agree on an ARK run with a block;
     - the review of §5.
6. **TF24's wiring (plant).** Not built.
   - *Pass:*
     - on u108 and u429, ARK's `J` error decreases with tol over 1e-2 … 1e-4, and is within 1e-4 of Cash–Karp's 1e-6 reference at 1e-4;
     - the sweep agrees with a pinned central difference;
     - the identical invader is exact, and `lma` × 0.95 … × 1.05 run on the fixture;
     - FF16, and TF24 under Cash–Karp, are unchanged;
     - the review of §5.
   - TF24's default becomes `ark` once this holds, as a declared change: `J` moves toward its time-converged value.
   - The pass once also asked for zero throws. That cannot hold while the pools are integrated by the tableau (§3, *What invaders need beyond A*).

## Appendix: the System solves its own stage

The alternative §4 was chosen over, kept as the comparison its implementation is reviewed against (§5).

- *The design.* odelia's ARK hands the block `(z, hγ, t)` to the System's `stiff_stage`, which returns the stage values and their implicit rates. odelia holds no Newton, Jacobian or correction of its own.
- *For TF24.* The soil is a one-way chain whose fluxes are monotone, so it would solve layer by layer, in the order water flows. Each layer's root lies between `z` and the explicit predictor `z + c·f(z)`, and a scalar primitive puts it on the tape.

```cpp
void stiff_stage(const S* z, double hgamma, double time, S* theta, S* rate) const {
  const double rain = rainfall(time);
  S inflow = 0.0;
  for (size_t i = 0; i < soil_number_of_depths; ++i) {
    auto net = [&, i](const auto& th, const auto& in) -> std::decay_t<decltype(th)> {
      return ((i == 0 ? rain * infiltrated_fraction(th) : in) - conductivity(th, i)) / dz[i];
    };
    theta[i] = odelia::implicit_stage<S>(z[i], hgamma, net, inflow);
    rate[i] = net(theta[i], inflow);
    inflow = conductivity(theta[i], i);
  }
}
```

- *What it asks of the developer:* the stage equation, the flow order, that a layer's rate does not increase with its own moisture, every active value it reads passed in, and a declared return type on a generic lambda, since a deduced one returns an expression over dead temporaries.
- *Size:* about 30 lines in odelia and 25 in plant, against §4's 60–80 and 10. Both are estimates.
- *Bad at:* any block that is not a one-way chain.
- *Good at:* it cannot fail to converge, since every root is bracketed.
- *Why it lost:* it puts numerical method in a scientist's code, for about the same total code (§5).
- *When to reopen it:* §4's implementation grows past twice its estimate, or its Newton fails on more than a few percent of stages.

## Sources

- **Scripts:**
  - `harness/ark436.R`: the tableaus' order conditions, stability boundaries and stage positivity, which §3's and §4's tables quote;
  - `harness/long_drought.R`: the 40-year stand of §3's *Result* and §4;
  - `harness/v12_steps.R`: what sets the step on v12, and the tolerance ladder (§4);
  - `harness/soil_bound.R`: §6's bounds;
  - `harness/ark_prototype.R`: §7's step 4, the three configurations over the tolerance ladder;
  - `harness/j_error_trace.R`: where `J`'s time error accrues, and the steps across a sign change of net production;
  - §1's table is now `test-mutant.R`.
- **Measurement notes:**
  - `perf-step-controller.md` §4 and §7;
  - `perf-rhs-profile.md` §3–4.
- **The consult:** T1–T9 of `oracle-consultation-solver-performance.md`.
