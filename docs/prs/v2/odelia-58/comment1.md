## What changes, on a small example

`tests/standalone/r_free.cpp` has a System built to show the
difference. It integrates y' = r·y·s, where s is chosen at each rate
evaluation from the state: 1 while y is below 100 and 0.5 above it.
Each evaluation stores its choice of s with the step, so a replay can
reuse it.

A run at r = 2 is recorded. y stays below 100, so every evaluation
chose s = 1. The recorded steps are then replayed at r = 5 in two
ways: once reusing every recorded choice, and once storing the replay's
own choices with `advance_recorded(rec, true)`. A fresh run on the same
steps, which solves everything, gives the answer the second should
match. The full program is in plant-dev's
`docs/prs/v2/figures/odelia-58/whole_game.cpp`.

```cpp
Solver<Chooser<>> run(Chooser<>(2.0), OdeControl{});
run.set_keep_states(true);
run.reset();
run.advance_adaptive(std::vector<double>{0.0, 1.0});
const auto rec = run.recording();

Solver<Chooser<>> reuses(Chooser<>(5.0), OdeControl{});
reuses.set_keep_states(true);
reuses.reset();
reuses.advance_recorded(rec);

Solver<Chooser<>> stores(Chooser<>(5.0), OdeControl{});
stores.set_keep_states(true);
stores.reset();
stores.advance_recorded(rec, true);

Solver<Chooser<>> fresh(Chooser<>(5.0), OdeControl{});
fresh.advance_recorded(run.schedule());   // the same steps, no recorded values
```

```
y(1): reuses 148.412862315  stores 122.4403839  fresh run on the same steps 122.4403839
choices of s = 0.5: recorded 0  reuses 0  stores 12 of 144
dy(1)/dr from the sweep: reuses 148.41251  stores 117.7283
dy(1)/dr from central differences: reuses 148.41251  stores 117.7283
```

The replay that reuses the recorded choices keeps s = 1 throughout,
although y passes 100, and ends near e⁵. The replay that stores its
own choices switches to s = 0.5 once y passes 100 at t = 0.92, and
ends exactly where a fresh run on the same steps ends. Each replay's
reverse sweep gives the derivative of that replay, as the central
differences confirm. For plant's invader, the first is the fitness of
the invader at the resident's leaf, and the second at its own.

## What changes for existing code

Nothing. The new argument defaults to false, and `advance_recorded(rec)`
takes the same path as on 0.8.1. A System that stores no solved values
is never handed the copy.

| file | what |
|---|---|
| `ode_solver.hpp` | `advance_recorded`'s second argument, `store_copy` |
| `ode_solver_internal.hpp` | `step_by` and `stepper_step` pass it on; the copy, `row_copy_` |
| `tests/standalone/r_free.cpp` | `test_a_pass_on_copied_rows_stores_its_own_values`, under both explicit steppers |

The change is the first branch of `with_row` in
`SolverInternal::stepper_step`, nine lines.

This is odelia 0.8.2, stacked on #57 (0.8.1). aornugent/plant#116 uses
it for TF24's invaders.
