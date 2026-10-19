## The whole thing

The System is the one `tests/testthat/test-substeps.R` defines: a
population `x` drawing on a two-layer store `(w1, w2)` that a seasonal
source fills and drainage `K w²` carries from layer to layer. The
store's rates read the population only through its uptake from each
layer, `c x w1` and `c x w2`, and at `K = 1e4` the store is stiff. Its
`subsystem()` is the store; it reports itself weakly coupled where the
uptake is under a tenth (`substep_below = 0.1`) of the water moving
through it, which at these parameters is every step.

From an odelia checkout of this branch, with it installed:

```r
library(odelia)
testthat::source_test_helpers("tests/testthat", env = globalenv())
toy <- parse("tests/testthat/test-substeps.R")
for (e in toy[1:4]) eval(e)  # the System, its compiler, its parameters
compile_substep_interface()

pars <- store_pars  # a = 1, m = 0.8, K = 1e4, s0 = 200, c = 0.3
y0 <- store_y       # x = 1, w1 = 0.5, w2 = 0.5
reference <- store_plain_run(1e-12, 2.0, pars, y0)
plain <- store_plain_run(1e-6, 2.0, pars, y0)
substepped <- store_run(0.1, 1e-6, 2.0, pars, y0)

c(plain = plain$steps, substepped = substepped$steps)
#>      plain substepped
#>       1700         77
c(plain = max(abs(plain$y - reference$y)),
  substepped = max(abs(substepped$y - reference$y)))
#>        plain   substepped
#> 1.772702e-06 9.378705e-09
substepped$substeps / substepped$substepped
#> [1] 81.46753
```

`store_plain_run` is the same System with no subsystem, so it takes
plain Cash–Karp steps; `store_run` names the store as the subsystem.
At tolerance 1e-6 to `t = 2` the substepped run takes 77 steps against
1700 and lands closer to the reference, and each of its steps
integrates the store in 81 substeps on average. Counting rate
evaluations on the same two runs (`toy_module.R` beside the figures),
the whole System is evaluated 518 times against 12 188, and the store's
own rates 136 836 times. The rest of this comment and the next explain
those numbers.

## Terms

- **subsystem**: a range of a System's state (`state_range`) whose
  rates read the rest only through one input per component. The
  System supplies those inputs (`subsystem_inputs`), the subsystem's
  rates under given inputs (`subsystem_rates`), the knots of its
  forcing (`subsystem_knots`) and whether it is weakly coupled now
  (`subsystem_weakly_coupled`). The concept is `HasSubsystem`.
- **knot**: a time where the subsystem's forcing changes from one
  cubic to the next. `drivers::Function::knots(from, to)` lists a
  driver's, leaving out those between two constant spans.
- **substeps**: Cash–Karp steps on the subsystem alone, inside one step
  of the whole System, as fractions of that step (`subsystem_substeps`:
  `ends`, and the `input_slope` they were chosen under).
- **predictor** and **corrector**: the two passes over those substeps.
  The predictor holds the inputs on a line extrapolated from the step's
  start along the input slope, and gives the subsystem at each stage
  time. The corrector holds them on the line from the start's inputs
  to those the stage at `t + h` produced, and gives the step's end.

## Control flow

```
  SolverInternal::step                          ode_solver_internal.hpp
    │  substeps_subsystem(system, t + h)
    │    a knot of the forcing in (t, t + h), or the System reports
    │    the subsystem weakly coupled; held across retries
    │  input slope = (u0 − u at the last adaptive step's start) / its size
    │
    ├─► every attempt (h shrinks on a rejection)
    │     Step::choose_substeps                 ode_step_rkck.hpp
    │       Cash–Karp on the subsystem alone, relative tol 1e-9,
    │       stopping at 1/5, 3/10, 3/5, 7/8, 1 and every knot
    │     Step::step(..., substeps, u0)
    │       take_substepped_step
    │         predictor over the substeps  ──► subsystem at each stage time
    │         stages 1..5: the rest from the tableau, the subsystem from
    │                      the predictor; each stage's inputs kept
    │         corrector over the same substeps ──► subsystem at t + h
    │         error = max(|corrector − predictor|,
    │                     stage inputs off the corrector's line)
    │       sixth evaluation at the end, as before
    │
    └─► accepted: push_step({t + h, h, substeps}); keep u0 and h

  advance_recorded / step_by(row)       no choose_substeps: row.subsystem
                                        is taken as recorded
  solve_adjoint → step_adjoint(..., row.subsystem)
                                        take_substepped_step again, at
                                        the active scalar
```

Only the run chooses substeps. Every other pass, a replay of the
program, of a recording, at another scalar, or the sweep, takes the
recorded `ends` and `input_slope` into the same `take_substepped_step`.

## What changes for existing code

| old | new |
|---|---|
| `instruction{time, step_size, insertion}` | gains `subsystem`, defaulted to empty |
| `SolverInternal::step_by(system, step_size, reached, replay)` | `step_by(system, row, replay)` |
| `SolverInternal::push_step(system, time, step_size, subdivided)` | `push_step(system, instruction, subdivided)` |
| `Step::step(..., dydt_out)` | two trailing defaulted arguments, `substeps` and `inputs` |
| `Step<System>::ah[]`, defined out of line | `static constexpr`, beside `stage_fractions` |
| `stage_state_fixed`, `step_end` over the state's `size` | over the argument's own length, so they serve a subsystem |

A System that does not satisfy `HasSubsystem` takes none of the new
paths: each is behind `if constexpr (HasSubsystem<System>)`. One that
does but never substeps steps as the plain System does; the test "with
substep_below at zero, every step is the plain System's" checks the step
count and the final state bit for bit. A System that does
satisfy it is refused two things it could do on 0.8.0: `step_to` over
an interval where a step would substep, and a recorded row without
substeps across a knot; `"rodas"` and `"dopri"` refuse a row that
carries substeps.

## Files

| file | lines | what |
|---|---|---|
| `ode_step_rkck.hpp` | +364 −36 | `choose_substeps`, `take_substepped_step`, `integrate_substeps`, `take_substep`; `step_error` split from `step` |
| `ode_solver_internal.hpp` | +151 −31 | the decision in `step`, the input slope (`last_inputs_`), the two refusals, `step_by` taking a row |
| `ode_interface.hpp` | +37 | `subsystem_substeps`, `instruction::subsystem`, `state_range`, `HasSubsystem` |
| `drivers.hpp` | +34 | `Function::knots`, `Drivers::knots` |
| `ode_solver.hpp` | +4 −3 | the program and recording replays hand `step_by` the row |
| `tests/testthat/test-substeps.R` | +581 | the toy and ten tests |
| `tests/standalone/r_free.cpp` | +2 −1 | a `constexpr` NaN for GCC 13 (bfa32cf) |

Read `HasSubsystem` and `subsystem_substeps` in `ode_interface.hpp`
first. Then the block in `SolverInternal::step` that decides whether a
step substeps and takes its input slope, then `take_substepped_step`,
which is the whole mechanism, then `choose_substeps`. `step_by` and
`step_adjoint` show the same function taking recorded substeps.

The second commit, bfa32cf, is a build fix. With `instruction` now
holding a `std::optional` of a struct of vectors, GCC 13.3 stops with an
internal compiler error (`gimplify_var_or_parm_decl`) compiling
`test_carried_k1_keeps_its_own_instant` in `tests/standalone/r_free.cpp`,
which builds a braced list of `instruction`s that reads a `const double`
local. Declaring that local `constexpr` compiles. On master (1e0f0f0)
and at bfa32cf, `g++ 13.3 -std=c++20 -O0 -c r_free.cpp` compiles; at
b707d21 it crashes. Clang compiles all three.

This is odelia 0.8.1. #58 (0.8.2) is stacked on it, and plant's TF24
soil PR (aornugent/plant#115) links it.
