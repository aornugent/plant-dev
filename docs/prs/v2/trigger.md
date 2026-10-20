# When to substep a subsystem

ODELIA-55 (aornugent/odelia#57, a956c01) and PLANT-105 (aornugent/plant#115,
762ad2fc). Local branches, not pushed: odelia `trigger-odelia` (d663a2b, on
a956c01) and plant `trigger-plant` (8282d1ab, on 762ad2fc). Scripts, data and
the pre-registered predictions are in
`/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/trig/`
(`notes.md`, `toy/`, `plantrun/`). Counts only; plant was run under `nice -n 19`
beside another agent's runs.

## 1. The error estimate does not under-read

The toy's 50x is a comparison of an absolute error against a relative
tolerance. At K = 10 the population x ends at 531, and the solver's error
level for it is `tol (1 + |x|)` = 5.3e-4 at tol 1e-6. The substepped run's
error of 5.4e-5 is 1.0e-7 of x, inside the tolerance. Plain Cash-Karp ends
6e-7 from the reference because it carries the fifth-order solution and
estimates the fourth-order one's error. The substepped step carries the
solution whose error it estimates.

Per step, the estimate over-reads. On one substepped step at K = 10
(t = 0.408, h = 0.00243, 5 substeps), with the true local error found from
that step's recorded start against a 1e-13 run:

| component | estimate | true local error |
|---|---|---|
| w1 | 1.9e-6 (gap 1.9e-6, stage term 3.0e-7) | 2.8e-7 |
| w2 | 3.7e-6 | 6.6e-7 |
| x (Cash-Karp's own) | 4.4e-11 | 3.6e-8 |

Over all substepped steps the median of estimate / true is 6.2 for w1 at
K = 10, 7.0 at K = 100 and 1180 at K = 1e4. The gap is about h^3 u''/2 and the
corrector's chord error about h^3 u''/12, so the ratio of 6 is expected where
the store is not stiff. Where the store is stiff, its end depends only on
the inputs near t + h, which the chord gets right, so the error is near zero
and the gap reads it a thousand times too high.

One term is missing: the rest's error from reading the predictor's store at
its stages. Cash-Karp's estimate on x reads about 3e-4 of x's true local error
on substepped steps. It is small: 3.6e-8 against an error level of 6.7e-5
for x. Carried to t = 2, the substepped steps' store errors give -7.2e-5 of
x's final error and their x errors +1.9e-5.

In the solver's norm, estimate / true on the whole state is 5.4 to 320 on
substepped runs and 0.6 to 2.3 on plain ones (tol 1e-6, K = 10 to 1e4). The
global error over the tolerance is 0.27 at K = 10 and 0.006 at K = 1e4 on
substepped runs, and 0.35 to 1.55 on plain ones. No cheaper estimate is
needed to fix an under-read. A sharper one would let stiff steps grow: at
K = 1e3 to 1e5 the store's gap sets every substepped step.

## 2. Why it costs at small K

The substeps' tolerance has nothing to do with it. At K = 10 and K = 100 every
step takes only the five forced stops, and substep tolerances of 1e-6, 1e-9
and 1e-12 give the same steps and errors (360 steps at K = 10 and 437 at
K = 100, tol 1e-6). The tolerance does set the store's evaluations where the
store is stiff: at K = 1e4 and tol 1e-6 they are 49k, 137k and 496k.

The cost is the coupling's order and the trigger:

- The corrector is second order. Its gap over-reads by about 6, so at the
  same tolerance a substepped run takes more steps than plain where the
  store's own Cash-Karp error is small: at K = 10 and tol 1e-6, 360 steps
  against 225.
- On the toy, "weakly coupled" is no test of stiffness. At K = 10 it is true
  on 189 of 360 steps, the early steps where x is small. At K = 10 the store
  is inside Cash-Karp's stability limit: h * rho is 0.49 at the median of a
  plain run, against 3.9 at K >= 1e3.

## 3. The trigger

Candidates on the toy (to t = 2, K = 10 to 1e5, tol 1e-3 to 1e-10). Each arm
is at its fewest accepted steps within the target of a plain 1e-12 run.
Counts are from uninstrumented builds:

| K | plain | current (uptake 0.1) | S | C |
|---|---|---|---|---|
| | *max abs error <= 1e-6 (the PR's criterion)* | | | |
| 10 | 186 | 2468 | 186 | 186 |
| 32 | 262 | 5405 | 262 | 263 |
| 100 | 442 | 2057 | 368 | 370 |
| 316 | 502 | 311 | 494 | 594 |
| 1e3 | 611 | 42 | 22 | 33 |
| 1e4 | 1572 | 27 | 31 | 27 |
| 1e5 | 4759 | 26 | 34 | 16 |
| | *max \|error\| / (1 + \|y\|) <= 1e-8* | | | |
| 10 | 518 | 1256 | 518 | 518 |
| 100 | 671 | 4475 | 671 | 666 |
| 316 | 888 | 1050 | 494 | 750 |
| 1e3 | 1472 | 426 | 1472 | 1281 |
| 1e4 | 2728 | 77 | 82 | 80 |
| 1e5 | 5394 | 34 | 43 | 44 |

- **S**: substep where h * rho > 3.735. rho is the store's rates' change over
  its state's change, from the stage at t + h to the end of the step before.
  3.735 is where Cash-Karp's fifth-order solution stops being stable on the
  real axis, computed from the tableau. A step whose two states coincide
  keeps the last rho. Without that, a store with no uptake, where the
  predictor and corrector agree exactly, leaves substepping after every
  step: 602 steps against 22 at K = 1e4.
- **C** (recommended): S, or where on the step before Cash-Karp's error on
  the store set the step and the coupling error would not have. That
  coupling error is measured on a substepped step. On a plain step it is
  predicted as h/2 * |u(t + h) - u0 - h * slope|.
- Rejected: **L** (substep when the store set the last step's size) takes
  21 772 steps at K = 10, because the store sets the step there too. **N**
  (L to enter, more than 10 substeps to stay) takes 20 022. S with a
  threshold of 4.67 never enters at K >= 3e4 (936 steps against 29). At 3.0
  or 2.5 it costs up to 1.3x at K <= 316.

On plant (synthetic daily record, `harness/long_drought.R`, 108
introductions, tol 1e-4, gradient run). The reference is a run stopped at
every knot at tol 1e-5 (16 175 steps, 880 782 rows, ln J 2.539181). The
elasticities are the census metrics' `d ln M / d ln theta` over 47 traits:

| arm | steps | rows | substepped | ln J - ref | max \|dE\| | lma | a_dG2 |
|---|---|---|---|---|---|---|---|
| knot only (B105, 0) | 4793 | 237 971 | 2081 | -4.9e-5 | 0.043 | 0.0087 | 0.0016 |
| uptake 0.1 (B105) | 4101 | 209 737 | 3086 | +2.8e-5 | 0.024 | 0.0056 | 0.0024 |
| S | 4480 | 227 433 | 2148 | -1.7e-4 | 0.007 | 0.0013 | 0.0006 |
| S and uptake 0.1 | 4481 | 227 528 | 2149 | +5.3e-5 | 0.030 | 0.0050 | 0.0010 |
| **C** | **4039** | **206 287** | 2840 | -1.1e-4 | 0.048 | 0.0079 | 0.0008 |

Every arm is within eps/3 of the reference (0.008 in ln J). Nudging tol by
+-5% gives C 202 087 to 209 386 rows, ln J 2.538992 to 2.539360. For uptake
0.1 it gives 206 710 to 212 224 rows, ln J 2.539208 to 2.539396. S keeps only
37% of uptake 0.1's saving in rows. On this record, the gain is mostly on
steps inside the stability limit, where the soil's own Cash-Karp error sets
the step and the coupling error is smaller. C finds those steps without a
threshold.

Seasonal reference regime (tol 1e-4): knot only 586 steps and 47 438 rows,
uptake 0.1 583 and 47 251, S 586, C 583 and 47 251. ln J is within 6e-5 of a
1e-5 stopped run in every arm, and the elasticities are identical.

## 4. Recommendation

**odelia**: C replaces the System's `subsystem_weakly_coupled()`.
`OdeControl::substep_subsystem` (default true) turns off all but the knots'
substepping.

```cpp
// SolverInternal::substeps_subsystem
return spans_subsystem_knot(system, step_end) ||
  (method == Method::rkck && control.substep_subsystem &&
   (substepping_paid_ ||
    (step_end - time) * stepper.subsystem_stiffness > stepper.stability_limit));

// after an accepted step
substepping_paid_ = substepping_pays(system, u0, input_slope, step_size,
                                     substeps.has_value());

// substepping_pays: the step's error ratios, on the error levels the control uses
rest      = max over the rest of |yerr| / level
cash_karp = max over the subsystem of |Cash-Karp's error| / level
coupling  = max over the subsystem of |substepped ? yerr
                                      : h/2 (u(t+h) - u0 - h slope)| / level
return cash_karp > max(rest, coupling);
```

`Step::step` keeps three things from the step it takes: the subsystem's part
of the stage at t + h, the inputs there, and Cash-Karp's error on the
subsystem before the coupling error replaces it. After the sixth evaluation it
sets `subsystem_stiffness = |f_end - k_stage| / |y_end - y_stage|` over the
subsystem. `reset()` clears both measures. The input slope is now found on
every step, not only on substepped ones.

**plant**: `Control$ode_soil_substep` (bool, default `FALSE`) replaces
`ode_soil_substep_max_uptake` and maps to `OdeControl::substep_subsystem`.
Off, only steps across a knot substep, as with the uptake fraction at 0
today. `Patch::subsystem_weakly_coupled` and
`TF24_Environment::uptake_fraction_of_flows` are gone.

With the switch off, the build matches B105 bit for bit on the synthetic
record: ln J, the census and its gradient are identical. With it on, it gives
C's numbers above.

**Why plant keeps a switch.** I tried deleting the setting outright, with C
always on. Two tests then fail:

- The water budget no longer closes to 1e-12. Over three tests the relative
  residual is 9e-6 to 9e-5, because the flux sums ride the main step while
  the soil is substepped.
- The whole-run-difference referee fails in its drought, shaded and clamped
  regimes: 10 to 12 columns are past the reference's spread, the worst at
  0.017 to 0.061.

B105 with uptake 0.1 fails the same referee the same way (12, 11 and 12
columns, worst 0.022 to 0.039). Both failures come from substepping itself,
which the uptake fraction at 0 kept off by default. Turning it on by default
first needs the flux sums inside the subsystem: about 20 lines in
`tf24_environment.h` and `patch.h`, not done here. It also needs a ruling on
whether the referee's spread should hold a substepped run.

## Size, deletions, cost

- odelia headers +94 -15 (`ode_solver_internal.hpp` +49 -10, `ode_step_rkck.hpp`
  +38 -2, `ode_interface.hpp` +4 -3, `ode_control.hpp` +3); `test-substeps.R`
  +68 -93.
- plant +12 -33 outside tests; tests +23 -23.
- Deletes: `subsystem_weakly_coupled()` from `HasSubsystem`, the toy's
  `substep_below`, plant's `subsystem_weakly_coupled` and
  `uptake_fraction_of_flows` (23 lines), the tuned fraction, and one duplicated
  pulsed-inflow test.
- Adds one new toy test: a store with no uptake keeps substepping.
- Costs:
  - Each accepted step makes one more pass over the state for the error
    ratios, and every step copies the subsystem's stage, inputs and error.
  - Where plain and substepped steps are about equal (K = 316, abs criterion),
    C takes 594 steps against plain's 502, with 1.6x the whole-System
    evaluations.
  - At tight tolerances where the store does not set the plain step, C does
    not enter. At K = 1e3 and rel 1e-8 it takes 1281 steps against the current
    trigger's 426.
  - The coupling error is still second order, as it is under the current
    trigger.
- Tests: odelia `test-substeps.R` passes (35 expectations). odelia's whole
  suite run in one process gives two errors in `test-ode-solver.R`; that file
  passes run alone. Plant: the whole suite (90 files, 622 tests), run serially
  against the installed build with the switch at its default, has no failures.
