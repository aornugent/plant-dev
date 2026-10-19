## The whole thing

The System is `Chooser` from `tests/standalone/r_free.cpp`: `y' = r y s`,
where each of a step's six evaluations chooses `s` from its own state (1
below `y = 100`, 0.5 above) and keeps the choice in the step's row. A
run at `r = 2` is recorded, then passed over at `r = 5`, once reading
the recorded rows and once storing its own.

```cpp
// A run at r = 2 stays below the threshold, so every stage chose s = 1.
Solver<Chooser<>> run(Chooser<>(2.0), OdeControl{});
run.set_keep_states(true);
run.reset();
run.advance_adaptive(std::vector<double>{0.0, 1.0});
const auto rec = run.recording();

// A pass over its steps at r = 5 that reads every recorded choice.
Solver<Chooser<>> reads(Chooser<>(5.0), OdeControl{});
reads.set_keep_states(true);
reads.reset();
reads.advance_recorded(rec);

// The same pass, storing what it solves into a copy of each row.
Solver<Chooser<>> stores(Chooser<>(5.0), OdeControl{});
stores.set_keep_states(true);
stores.reset();
stores.advance_recorded(rec, true);

// The run's steps at r = 5 with no rows at all.
Solver<Chooser<>> steps(Chooser<>(5.0), OdeControl{});
steps.advance_recorded(run.schedule());
```

```
steps 24, stage values per step 6
y(1): reads 148.412862315  stores 122.4403839  steps alone 122.4403839
stage values at s = 0.5: run 0  reads 0  stores 12
dy(1)/dr: reads 148.41251 (difference 148.41251)  stores 117.7283 (difference 117.7283)
```

The pass that reads keeps `s = 1` throughout and lands near `e^5`; its
recording holds the run's 144 choices. The pass that stores crosses
`y = 100` at `t = 0.92` and from there chooses `s = 0.5`: 12 of its
144 stage values differ from the recorded ones, it lands where the
run's steps land with no rows at all, bit for bit, and a sweep of its
own recording is the central difference of that pass. The program is
`tests/standalone/r_free.cpp`'s `Chooser` with a `main` that prints
these lines; built against this branch's headers and `src/Tape.cpp`.

## Terms

One argument is new. The second argument of `advance_recorded`, true,
makes each step's stages store into a copy of that step's recorded row
where they would otherwise read the row itself. Whether a System reads
or writes an entry is already decided by the row's constness
(`load_solved` for a `const` row, `store_solved` otherwise); the copy is
a row that is not `const`, holding the recorded values when the System
is handed it.

## Control flow

```
  advance_recorded(rec, true)                ode_solver.hpp
    │  for each recorded step k
    ▼
  SolverInternal::step_by(row k, &rec[k].solved, true)
    │
    ▼
  stepper_step                               ode_solver_internal.hpp
    │  copy = rec[k].solved                  one row, owned by the solver
    │
    ├─► Step::step(system, copy, ...)        six evaluations
    │     each: system.store_solved(copy[i])
    │           the System reads copy[i] (the recorded values)
    │           and writes its own over the entries it solves
    │
    └─► keep_states?  the step's record takes the copy
                        │
                        ▼
                      solve_adjoint later loads these rows,
                      the pass's own values
```

Without the argument, `step_by` hands `Step::step` the recorded row
itself, `const`, and every evaluation calls `load_solved` on it.

## What changes for existing code

Nothing. `advance_recorded(rec)` takes the same path it took on 0.8.1:
the flag defaults to false, and `step_by` and `stepper_step` take it as
a trailing defaulted argument. For a System that declares no
`solved_values` a row is six empty entries, so the argument copies
nothing and the System is never handed the row.

## Files

| file | lines | what |
|---|---|---|
| `ode_solver.hpp` | +8 −2 | `advance_recorded`'s second argument |
| `ode_solver_internal.hpp` | +21 −7 | `step_by` and `stepper_step` pass it on; the copy, a member of `SolverInternal` |
| `tests/standalone/r_free.cpp` | +66 −1 | `test_a_pass_on_copied_rows_stores_its_own_values`, under both explicit steppers |
| `NEWS.md`, `DESCRIPTION` | | 0.8.2 |

Read `stepper_step`'s `with_row` first: the new branch is nine lines
beside the two it sits between. Then `advance_recorded` for where the
argument enters, and the test for what a System sees: each of a step's
six evaluations is handed the recorded row before it stores.

Stacked on #57 (0.8.1, a subsystem integrated in substeps of its own);
this is 0.8.2. plant's TF24 invader PR (aornugent/plant#116) links this
branch.
