# Scope: an implicit–explicit stepper for TF24

**Status (September 2026):** §2.3 and its extension to events (R6) are implemented (aornugent/plant#95). The rest is parked. Exact counts are aornugent/plant#94. See `handover.md`.

The design in short:
- **One stepper in odelia, driven by a tableau.** Cash–Karp and ARK4(3)6L[2]SA are two tableaus of it.
- **A System may declare a small stiff block**, with its rates as a function of that block and the time alone. odelia then solves each stage's block, differentiates it, and puts it on the sweep's tape.
  - TF24's block is the soil's drainage and inflow.
  - The plant developer writes that one function and nothing else.
- **Three removals come first.** Together they also give invaders a working, differentiable path.
- **The pool's fast mode goes in the model, not the solver.** Its relaxation time is floored (§3, decided), because it breaks invaders whatever the stepper.

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

**Option A, the model: floor the pool's relaxation time at `τ_s`**, as the establishment window floors the gate's.
- The rate becomes `Ṡ = [c(1 − r) − d·r] / (1 + λ·τ_s)`.
- *What stays:* the equilibrium and both bounds. At `r = 0` the rate is ≥ 0 and at `r = 1` it is ≤ 0, as now.
- *Who is affected:* only members with `λτ_s` near 1 or above, which is the newest few.
- *What it buys:* the relaxation rate becomes `λ/(1 + λτ_s) ≤ 1/τ_s`. At `τ_s = 7` days, explicit steps up to about 26 days are stable, for residents and invaders alike.
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

**Decided: A** (September 2026). B stays on file in case A moves `J` by more than is acceptable.

## 4. One stepper, two tableaus, a declared stiff block

**The stepper.** `Step` becomes tableau-driven.
- *Cash–Karp as data, and bit-identical.* Sums run over nonzero coefficients in ascending stage, with `h` applied after the sum. A one-term row is applied as `(a·h)·k`, the rounding the FF16 references were blessed on (`ode_step.hpp:206–224`).
- *ARK4(3)6L[2]SA as data.* The coefficients are SUNDIALS' `ARK436L2SA`, with the order conditions checked to 1e-16.
- *`Method` chooses the tableau*, and `rodas` stays a stepper of its own (§2.2). The recording keeps six rows per step (five stages and the end) under both tableaus.

**The stiff block.** A System may declare these members, as a concept with `if constexpr`. The names are proposals.

```cpp
// The stiff part of the rates, as a function of the components it is stiff in
// and the time alone.
std::size_t stiff_offset() const;
std::size_t stiff_size() const;
template <class U>
void stiff_rates(std::span<const U> y, double time, std::span<U> out) const;
```

A System without them integrates with the tableau's explicit part.

**Each stage in the forward run.** odelia:
1. forms `Z`;
2. solves the block equation `Y_b = Z_b + hγ F_I(Y_b, t_i)` by Newton:
   - the Jacobian comes from forward-mode AD of `stiff_rates`, one tangent pass per block component;
   - the linear solves use `ode_linalg.hpp`'s dense LU;
3. evaluates the full rates once at `Y`, which is the one member loop;
4. takes `F_E = F − F_I`.

**The sweep.**
- It runs the same Newton in double from the tape's values of `Z_b`, so the roots are bit-identical.
- The block then enters the tape as `Y_b = Y* − M·G(Y*)`:
  - `M = (I − hγJ)⁻¹` is passive;
  - `G` is the residual, taped once at the root.

  This is the vector form of odelia's `implicit_value`.
- *What follows:*
  - the transposed solve happens on the tape;
  - nothing extra is recorded;
  - the same code runs at double, tangent and adjoint scalars, because `stiff_rates` reads nothing active.

**For TF24, the block is the soil's five layers**, with `F_I = (in_ℓ − K(u_ℓ))/Δz`.
- It reads only the soil, the rain and coefficients typed `double` (`tf24_environment.h:457–476`).
- Uptake, the members, `E` and the accumulators stay explicit.
- The `θ_res` guard stays in `F`.

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
- *The embedded estimate is not L-stable* (`R̂(−∞) = −0.15`). If the prototype shows the soil setting the step, filter the estimate through `(I − hγJ)⁻¹`; the Jacobian is already at hand.
- *The explicit part's boundary is 4.23.* Uptake is at most 111 yr⁻¹ over 100 sampled states, so it binds only past 14-day steps.
- *The soil's second stage reflects its displacement from the quasi-steady state.* The soil sits on that state except at the run's start.
- *Order 4 over 5.* The steps are not accuracy-limited (T1).

## 5. What a plant developer writes

- `TF24_Environment`:
  - `stiff_rates`, with the drainage and inflow moved out of `compute_rates`, which then calls it. It is pure: the clamp tallies stay in `compute_rates`.
  - `stiff_size`.
- `Patch`: `stiff_offset` and the forwarding, one line each, present only when the environment declares a block.
- `Control`: `ode_method`.
- Nothing for invaders. An invader's copy of the soil block is solved and then replaced by the field it stands in (`patch.h:1087`), as its explicit copy is today.

## 6. What it should save

These are offline bounds on the recorded runs at tol 1e-3, with one evaluation per entry. Removing the knots' remaining evaluation (2.1) adds about 3 points to each ARK row.

| member evaluations saved | `u429` | `d108` |
|---|---|---|
| stops as targets alone (2.1) | ~7% | ~7% |
| soil ARK, pools as today: today's growth law → legs filled | 27% → 39% | 31% → 44% |
| soil ARK, pools floored (§3, A): today's growth law → legs filled | 37% → 51% | 35% → 49% |
| the floor, one step per leg | 74% | 73% |

- The pool rows are the T8 bound with both stiff modes out. The soil rows are `soil_only_ideal.R`: the pools keep their stability limit and their throws.
- The cost per member evaluation is untouched. There, the warm-started leaf solve is the lever.

## 7. Order of work

`scope-schedule-controller.md` §6 interleaves these steps with exact counts and the controller; this is the stepper's own sequence.

1. **Stops as targets (plant).**
   - *Pass:* `J`, the steps and the gradient unchanged to round-off; about 7% fewer member evaluations; fewer sweep ranges and less sweep time.
2. **Seeded rows (odelia and plant).**
   - *Pass:*
     - the identity invader is still exact;
     - a resident-and-mutant invasion runs;
     - an invader's sweep agrees with a pinned difference of its fitness.
     - the identical invader is exact under each kind of event (R6, §2.3 extended).
3. **The pool (plant): option A, decided.**
   - *Pass for A:* the moves in `J` and `dJ/dθ` stated; zero throws; the table's mutants run on the resident's program.
4. **A prototype driven from R** of the soil ARK, on the new baseline.
   - The driver with Cash–Karp's tableau must first reproduce the SCM's run bit for bit.
   - *Gate:* at least 30% fewer member evaluations than today at matched `J`.
5. **The tableau stepper and the stiff block (odelia).**
   - *Pass:*
     - Cash–Karp bit-identical (the FF16 references and odelia's snapshots);
     - ARK at order 4, and stable, on the stiff van der Pol runner the RODAS tests already use;
     - tangent and adjoint agree.
6. **TF24's wiring (plant).**
   - *Pass:* the handover's test 3, the pinned ARK across tolerance.

## Sources

- **Scripts**, in `$SP/imex/`:
  - `mutant_rows.R` and `mutant_scan.R`: §1's table;
  - `ark_tableau.R` and `ark_stage_zeros.R`: the tableau's properties and §3's stage table;
  - `soil_only_ideal.R`: §6's soil rows, from `perf/controller/ctl_ideal.R`.
- **Measurement notes:**
  - `perf-step-controller.md` §4 and §7;
  - `perf-rhs-profile.md` §3–4.
- **The consult:** T1–T9 of `oracle-consultation-solver-performance.md`.
