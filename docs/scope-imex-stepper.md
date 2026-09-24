# Scope: an implicit–explicit stepper for TF24

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

| invader | replay on the resident's program |
|---|---|
| identical to the resident | runs, exact |
| resident and a mutant together | fails: `expected 2, received 1`, from loading the resident's operating points |
| lma × (1 + 1e-9), × (1 + 1e-6) | runs |
| lma × (1 + 1e-4) up to × 1.05 | fails: storage negative, a pool overshoot |
| lma × 0.99, × 0.95 | runs, but at the resident's operating points, so the result is not the invader's fitness |

- The mutant's own resident run completes at every one of these traits, so the failures belong to the replay.
- The suite tests only the identity (`test-mutant.R:153`), which (a) makes exact by construction.

**What an AD-compatible invader needs.**
- its own operating points, stored in its own recording;
- the resident's field in each row of that recording, as doubles. That makes the field exogenous with a zero derivative, which is what a selection gradient wants.
- stiff modes that are stable at the resident's steps.

With all three, the invader's selection gradient is the existing `solve_adjoint` over the invader's own recording. It needs no new sweep code.

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

**2.3 Forward replays that load rows.**
- *Only `run_mutant` uses one* (`scm.h:768`). Every other forward replay walks a program of sizes and solves (`scm.h:697`, `1350`, `1398`).
- *The change: every forward pass stores, and only the sweep loads.*
  - `advance_recorded(rec)` seeds each step's row from the recorded one, and the stages store into it.
  - The Patch stands in the field a row carries, whether it is storing or loading, and writes its own operating points beside it.
  - It copies that field, because a seeded row is the solver's scratch space, which moves on at every step.
- *What that buys:*
  - (a) is fixed;
  - multi-strategy invasions work;
  - the invader's recording can be swept;
  - `Step::step`'s two row constnesses collapse to one.

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
