# Scope: an implicit–explicit stepper for TF24

The stepper is an additive Runge–Kutta pair, ARK4(3)6L[2]SA:
- **implicit:** the soil chain's drainage and inflow and, in a second phase, each member's storage pool;
- **explicit:** everything else, with the member loop evaluated once per stage.

This note covers:
- why this differs from the IMEX the multirate branch built;
- what it should save;
- what could stop it;
- what to build in odelia and plant, and in what order.

**Recommendation.** Build it soil first.
- The soil alone buys about three quarters of the measured bound on `u429`, and needs no change inside the member loop.
- The pools come second, after a census of how often their stage values would go negative (§4.1).
- Before any C++, a prototype driven from R measures the step counts and `J`'s response to tolerance (§6, phase 0).

## 1. What the multirate branch built, and what has changed

| | the multirate branch's IMEX | this stepper |
|---|---|---|
| method | RODAS4, linearly implicit, on the soil block | ARK4(3)6L[2]SA, with the implicit stages solved to round-off |
| Jacobian | the soil block's 9 columns, differenced through the full rate evaluation (member loop and leaf search included) | none through the members; the soil's closed form and one scalar per pool, used only to converge Newton |
| member-loop evaluations per step | 19 | 6 (five stages and the end), as Cash–Karp |
| linear algebra | a dense `N × N` LU (`N = 3443` at 429 members) | five scalar roots per stage, and one per pool |
| accuracy | effective order ~2: `J` off by 3.6e-2 at tol 1e-4 | independent of the Newton Jacobian |
| cost | 20–50× Cash–Karp, growing with tighter tolerance | within 0.5% of Cash–Karp per step |
| adjoint | none | implicit-function rows at each root, inside the existing sweep |

Why the branch's accuracy collapsed:
- A Rosenbrock method's order conditions assume the exact Jacobian.
- The branch's Jacobian was differenced through a bracketing search, which is smooth only to its bracket width.
- A DIRK stage that is solved, not linearised, has no such dependence. Newton's Jacobian changes how fast the root converges, not where it lands.

The target has changed as well:
- **Stops at the 2931 active knots.** Every step now lies inside one cubic span of the forcing.
- **The establishment window, `τ_g = 0.05`.** The gate's ramps are 18–40 days wide, not 0.06 days.
- **The pool's charge-and-drain form** (plant `745dd600`, August 2026). The branch ran the drain gated by `S/(S + 1e-3·S_max)`, whose fixed point relaxed in under an hour.
- **The steps are stability-limited.** The branch assumed they were accuracy-limited, measured on a surrogate run without stops. On the operating run:
  - the median error ratio is 0.03 (T1);
  - 24% of accepted steps sit at ≥ 0.8 of the soil's stability boundary (T3);
  - the pool guard throws 1150 times (T4).
- **The uptake coupling is small here.** Near the dry bound the branch measured it at 50–291× the soil's own Jacobian. Across 100 sampled states of the operating run, its diagonal is a median 0.08 yr⁻¹ and at most 111 yr⁻¹. That limits the explicit part only at steps longer than about 14 days (§4.3).

## 2. The method

**The pair.** Kennedy & Carpenter (2003), ARK4(3)6L[2]SA, with the coefficients as SUNDIALS ARKODE ships them (`ARK436L2SA_ERK_6_3_4` and `ARK436L2SA_DIRK_6_3_4`). The order conditions of the combined method were checked to order 4, and those of the embedded method to order 3; both hold to 1e-16 (`ark_tableau.R`).

| property | ARK4(3)6L[2]SA | Cash–Karp 5(4) |
|---|---|---|
| order / embedded | 4 / 3 | 5 / 4 |
| rate evaluations per accepted step | 6: five stages, then the end, handed on as the next step's first stage | 6 |
| explicit part's real stability boundary | 4.23 | 3.73 |
| implicit part | L-stable and stiffly accurate: `R(−∞) = 0` | — |
| embedded method as `hλ → −∞` | `R̂ = −0.15`, not L-stable (§4.2) | — |
| widest gap between stage abscissae | 0.332 h | 0.3 h |
| weights shared by both parts | yes, so the water budget closes exactly | — |

The stops stay. The widest abscissa gap is about the same as Cash–Karp's, so an event narrower than a third of a step is still stepped over.

**The split.**
- *Implicit, `F_I`:* each layer's drainage and inflow, `(in_ℓ − K(u_ℓ))/Δz`. In the pool phase, also each pool's whole rate.
- *Explicit, `F_E = F − F_I`:* everything else. That includes:
  - uptake `a`;
  - the members;
  - `E`;
  - the accumulators;
  - the `θ_res` guard, which acts on the total rate.

  Defining `F_E` as the difference leaves the model's right-hand side exactly as it is today.

**A stage.**
1. Form `Z_i = y_n + h Σ_{j<i} (a^E_ij F_E(Y_j) + a^I_ij F_I(Y_j))`.
2. Solve `Y_i = Z_i + hγ F_I(Y_i)`, with `γ = 1/4`.
3. Evaluate the rates once at `Y_i`.

The stepper never reads `Y_i` back: the later stages and the step's end need only `F` and `F_I`.

**The soil's stage solve** is five scalar roots, top layer first.
- Layer `ℓ` solves `u − Z_ℓ − (hγ/Δz)(in_ℓ − K(u)) = 0`, with `in_ℓ = K(u_{ℓ−1})` from the layer already solved. Layer 1's inflow is the rain times the saturation-excess factor of `u_1`.
- `K` is non-decreasing and layer 1's inflow is non-increasing in `u_1`, so each residual is strictly increasing. Each root is unique, and a safeguarded Newton brackets it.
- The solve reads only the soil and the rain at the stage time, never a member.
- It costs a few thousand instructions per stage, under 0.1% of a rate evaluation at 216 members.

**The pool's stage solve is exact; nothing needs lagging.** The handover left open whether the pool's coefficients would have to be taken from an earlier stage.
- *Net production does not read the pool.* The leaf solve computes `P` before the pool is read (`tf24_strategy.h:1913–1978`). Storage is first read at line 1978, and feeds only:
  - the growth gate;
  - the charge and the drain;
  - mortality.
- *So each member's evaluation can be split in three:*
  1. run its leaf solve;
  2. solve its pool root, `S − Z − hγ [P₊(1 − G(r))(1 − r) − (P₊ − P) r] = 0` with `r = S/S_max`;
  3. evaluate the storage-dependent tail at the solved `S`.
- *The root is unique.* On `[0, S_max]` every term of the pool rate's derivative is ≤ 0, so the residual is strictly increasing.
- *It is the ARK stage itself, not a linearly implicit (W-type) variant.* It costs a few hundred instructions per member per stage, about 0.3%.
- *TF24f shares TF24's pool.*

**The adjoint.**
- *One recording per step*, as `Step::step_adjoint` takes one:
  - the first stage re-derived at `y_n`;
  - stages 2–6 with their recorded leaf operating points loaded;
  - the step's end.
- *Each root enters the tape through odelia's `implicit_value`.* The residual is taped once at the root and `∂F/∂y` is supplied in closed form. The tape then performs the transposed triangular solve (pools after soil), so odelia needs no hand-written transpose.
- *The roots are recomputed in the sweep from the same doubles.* A deterministic Newton from the same inputs returns the same bits, so the recording keeps its six-row shape and its size.
- *H4 holds:* the iterations run at double, off the tape.
- *The sweep costs as much per step as today's*, plus a few scalar statements per stage.

## 3. What it should save

These are offline bounds from the recorded runs at tol 1e-3. They assume:
- no rejected attempt except where the row keeps the throws;
- error scaling as `h⁵`;
- the stiff components setting no accuracy limit of their own;
- today's schedule entries, with one rate evaluation per entry.

Both-modes rows are `perf-step-controller.md` §7 (T8). The soil-only rows are this scope's recomputation from the same data (`soil_only_ideal.R`). Each member's pool keeps its stability limit, capped at `0.8 × 4.23/λ_pool` (the ARK's explicit boundary), and its throws are kept.

| member evaluations saved | `u429` | `d108` |
|---|---|---|
| measured | 1.934e7 | 7.601e6 |
| soil implicit, today's growth law (walked) | 26.6% | 31.1% |
| soil implicit, legs filled to their local limits | 39.2% | 44.1% |
| both modes implicit, today's growth law | 36.6% | 35.0% |
| both modes implicit, legs filled | 51.2% | 48.7% |
| floor: one step per leg | 73.7% | 73.3% |

- On `u429` the pools add about 12 points: 7.8 of stability credit and 4.3 of throws. On `d108` they add about 5.
- The pool cap binds at 31% of `u429`'s accepted steps and 11% of `d108`'s.
- *As speed-ups* (1/(1 − saved)):
  - the soil alone: 1.4–1.5× fewer member evaluations with today's controller, and 1.6–1.8× with one that reaches the local limits;
  - both modes: up to 2.0×.
- *Against the Oracle.* Its 2.5–4× needs steps near one per leg, which is controller work (phase 4), not the IMEX.

The IMEX leaves three costs untouched:
- the cost of a member evaluation, where the warm-started leaf solve is the lever;
- the schedule, where exact masses are;
- the 18 points of T8 not due to the stiff modes: rejections after rain knots, steps short for other reasons, and the second evaluation at each entry.

## 4. What could stop it

**4.1 Pool stages can go negative away from the quasi-steady state.**
- *Stage 2 is a trapezium half-step.* For a stiff mode, each stage's deviation from the mode's quasi-steady state `S_eq` is `R_i(hλ)` times the deviation at the step's start:

| stage | negative past `hλ` | at `hλ = 10` | at `hλ = 100` | as `hλ → ∞` |
|---|---|---|---|---|
| 2 | 4.0 | −0.43 | −0.92 | −1.00 |
| 3 | 6.6 | −0.18 | −0.69 | −0.77 |
| 4 | 4.1 | −0.18 | −0.12 | −0.08 |
| 5 | 3.1 | −0.17 | −0.16 | −0.16 |
| step end | never | | | 0 |

  This is structural. Any ESDIRK of stage order 2 has `c₂ = 2γ`, and its second stage reflects the deviation.
- *At the quasi-steady state it is harmless.* The deviation is only the previous step's lag, and the throw cycle of T4, which is an explicit instability, goes.
- *Away from it, a stage goes below the guard.* That happens where a pool sits above its `S_eq` by more than about 1–6× `S_eq` and `hλ > 3.1`. That is `h` above:
  - 0.8 days for the newest member's pool at `λ = 1444`;
  - 6 days at the `u429` median of 188.
- *The expected cases:*
  - a member created at `0.8·S_max` whose production is negative, so that its `S_eq` is near zero;
  - production turning negative under a filled pool.
- *What decides it:* the census in phase 0.3.
- *Two remedies, if the census says it matters:*
  - read `r` through `max(r, 0)` in mortality, so a negative stage value is finite arithmetic and only a committed one is refused. This is a declared change outside the model's domain. It also changes Cash–Karp runs wherever they throw today.
  - keep the throw and its retry at `0.2h`, which then happens once per creation transient, not per cycle.

**4.2 The embedded estimate does not damp stiff components.**
- `R̂(−∞) = −0.15`, so a component displaced from its quasi-steady state reports about 0.15 of its displacement as error. `R − R̂` is 0.032, 0.125 and 0.15 at `hλ = 10`, 100 and 1e4.
- *The fix.* Filter the estimate through `(I − hγ J_I)^{-1}`. That is the soil's closed-form bidiagonal and one scalar per pool, and it takes the three figures to 0.009, 0.005 and 6e-5.
- *Whether it is needed:* the component setting the step size (`error_index`) in the phase 0.4 prototype.

**4.3 The explicit part keeps a boundary of 4.23.**
- Uptake is the remainder most likely to reach it. Its diagonal is at most 111 yr⁻¹ over the 100 sampled `u429` states (median 0.08), so it binds only past 14-day steps. The pools bind first while they stay explicit.
- The sample may miss the driest states. Phase 0.2 repeats the reading there.

**4.4 Kinks inside the implicit part.**
- `K`'s clamp at `θ_s` and the saturation-excess switch make the soil residual piecewise smooth, but it stays monotone. A bracketed Newton handles that.
- The implicit-function row is one-sided at a kink, as the explicit rates' derivatives are today.
- The `θ_res` guard stays in `F`, so `F_E` inherits its discontinuity: the sliding mode the Oracle counts as part of the floor.

**4.5 Order 4 over 5.** Steps are not accuracy-limited today (T1). A third-order estimate also grows the step faster at small ratios. Phase 0.4 measures the net effect.

**4.6 The invasion pass.** Invaders stand in the resident's recorded field, which will then hold the solved stage soil.
- An invader must not solve the soil.
- An invader's own pools are implicit like any member's.
- The invader must run with the resident's method, because the recorded fields are indexed by stage.

## 5. What to build

**odelia.** This changes the header core, so it is cross-package.
- `ode_step_ark.hpp`, holding `ArkStep`:
  - the tableau;
  - `step`, which carries `F` and `F_I` from the step's end;
  - `step_adjoint`, a mirror of `Step::step_adjoint`;
  - `order() = 4`.

  It is a class of its own, as `RodasStep` is, so Cash–Karp's blessed arithmetic, and with it FF16's bit-identity, is not touched. Its stages are additive and each carries a solve, so it is not a near-copy of `Step`.
- `Method::ark`, and the dispatch in `SolverInternal`.
  - The carried rates become a pair: a rejected attempt leaves the System at a stage state, so `F_I(y_n)` is carried beside `dydt_in` rather than read back.
  - `set_state_from_system` reads both.
- The System side, as a concept with `if constexpr`. Proposed members:
  - `set_ode_state(it, time, h_gamma)`, which loads the stage's `Z` and solves the implicit components in place;
  - `ode_implicit_rates(it)`.

  A System without them has no implicit part, and the ARK is then its explicit half.
- Optionally, `ode_implicit_solve(rhs, h_gamma)` for the filter of §4.2.
- Tests, including the standalone C++ build:
  - a split van der Pol, on the stiff runner the RODAS tests already compile, reaching order 4 on a non-stiff parameter and staying stable at a stiff one;
  - agreement with the explicit half on Lorenz;
  - a bit-identical forward replay;
  - the adjoint against a forward tangent.

**plant.**
- `Control` gains an `ode_method` key, with its `RcppR6_classes.yml` entry and regeneration. The SCM and the gradient's forward solvers take the key (`scm.h:548`, `1344`, `1391`).
- `Patch` forwards the stage load: the environment first, then the member loop.
- `TF24_Environment`:
  - its rates split into drainage and inflow on one side and uptake on the other;
  - the stage solve;
  - `implicit_value` rows at an active scalar.
- `TF24_Strategy` (TF24f included):
  - the pool root between net production and the storage tail, with its rows;
  - its implicit rate.
- FF16 and K93 need nothing.
- Tests:
  - a tier-1 file on a short fixture;
  - the FF16 bit-identity guard, which the default `rkck` must keep.

**Size and build.** About 1000 lines across both packages, tests included; the adjoint adds about 150 of them.
- plant compiles against odelia's installed headers, so odelia goes into a private library.
- A header change in plant is about a 15-minute rebuild.

## 6. Order of work

**Phase 0: measure before building (scripts only).**
- *0.1 How much the soil alone buys.* Done: §3.
- *0.2 The explicit remainder at the dry extremes.* Five directional differences of the rates give `−(∂a/∂u)/Δz` at the 20 driest recorded states, to set against `4.23/h` at the §3 local limits.
- *0.3 The pool census.* At each accepted step's start, for each member, compute:
  - `S_eq` from `P` and `S_max`;
  - the deviation `S − S_eq`;
  - `λ`.

  Then count the stages that §4.1's table puts below `−1e-8·S_max` at the §3 local-limit steps, and say which are creations.
- *0.4 An ARK driver in R, with the soil implicit and the pools explicit.*
  - *How it runs:* `patch$derivs` supplies the rates, `introduce_new_node` makes the creations, and the soil's roots and `F_I` are computed in R.
  - *Validation first:* the same driver with Cash–Karp's tableau must reproduce the SCM's `u429` run bit for bit (the `ctl_rk.R` replay already does per attempt).
  - *Then measured*, over tol 1e-2 … 1e-4 on `u429` and `d108`:
    - steps, and attempts by cause;
    - the component setting each step;
    - `J`'s spread and whether it is monotone;
    - T6's crossing counts.

  At about 4 ms per rate evaluation, a run is a few minutes.
- *Gate to phase 1:* at least 30% fewer member evaluations than Cash–Karp at matched `J`, and no new dominant rejection cause.

**Phase 1: the stepper in C++, soil implicit, forward only.**
- *Pass:*
  - phase 0.4's counts reproduced;
  - the odelia tests;
  - FF16's references unchanged.

**Phase 2: the adjoint.**
- *Pass:*
  - the sweep agrees with a forward tangent to the 2e-8 of today's check;
  - three members' values agree with pinned differences, as in A4;
  - the sweep's cost per step is within 10% of Cash–Karp's.
- *Also re-measure:* whether the sweep still refuses at tol 1e-2 and 3e-3 (T9). Those refusals were stage states past a series' domain.

**Phase 3: the pools implicit**, if phase 0.3 allows it.
- *Pass:*
  - zero throws;
  - the §3 gain of 10–12 points on `u429`.

**Phase 4: controller, then the handover's tests 3 and 4.**
- *Controller changes:*
  - the filter of §4.2, if phase 0.4 shows stiff components setting the step;
  - one evaluation per entry, and none at a zero-size knot;
  - the first step after a wet knot.
- *Then:*
  - the pinned ARK across tolerance: `J` monotone, with a spread ≪ 1e-4;
  - the graded schedule across the 11 points of `perf-across-theta.md`.

## Sources

- **Scripts**, in `$SP/imex/` (the scratchpad):
  - `ark_tableau.R`: the order conditions and stability functions;
  - `ark_stage_zeros.R`: where the stage values change sign;
  - `soil_only_ideal.R`: the soil-only bound, logs `soil_only_{u429,d108}.log`, built from `perf/controller/ctl_ideal.R`.
- **Measurement notes:**
  - `perf-step-controller.md` §4 and §7;
  - `perf-rhs-profile.md` §3–4, the branch record and what exists for implicit integration.
- **The consult:** T1–T9 and R1–R4 of `oracle-consultation-solver-performance.md`.
- **The uptake coupling:** `perf/controller/out/eig_u429_base.rds` (`soil_uptake_max`).
