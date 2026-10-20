# What it gives a System

A stiff store drained by a population, from `test-substeps.R`. Plain
Cash–Karp must step at the store's pace; with the store named as a
subsystem, the population takes steps 38 times longer and the store is
carried across each one in substeps of its own:

![One step of the toy: the store's first layer across a step 38 times plain Cash–Karp's, the six evaluations of the whole System, and the 134 substeps that carry the store](FIG:odelia-57/one_step.png)

To `t = 2` at tolerance 1e-6:

```
plain        1700 steps   error 1.8e-6
substepped     77 steps   error 9.4e-9
```

A System opts in by naming the range and saying how it reads the rest:

```cpp
state_range subsystem() const;                    // which components
void subsystem_inputs(std::vector<T>& u) const;   // one input per component
void subsystem_rates(double t, const std::vector<T>& y,
                     const std::vector<T>& u, std::vector<T>& dydt) const;
std::vector<double> subsystem_knots(double from, double to) const;
```

```
  SolverInternal::step
    knot in (t, t+h), or the subsystem holds the step back?
      no  → a Cash–Karp step, as before
      yes → the subsystem in substeps, the rest on its six stages;
            the row records the substeps
  replays and solve_adjoint → the row's substeps, as recorded
```

| file | what |
|---|---|
| `ode_step_rkck.hpp` | the substepped step |
| `ode_solver_internal.hpp` | when a step substeps; `step_by` takes the row |
| `ode_interface.hpp` | `HasSubsystem`, `instruction::subsystem` |
| `drivers.hpp` | `Function::knots` |
| `tests/testthat/test-substeps.R` | the toy and its tests |

Read `take_substepped_step` first; it is the whole mechanism.

This is odelia 0.8.1. #58 (0.8.2) is stacked on it, and
aornugent/plant#115 names TF24's soil as the subsystem. The second
commit lets GCC 13 build `tests/standalone`: it crashed compiling a
braced list of `instruction`s, which now hold a `std::optional`, from a
`const double` local; the local is now `constexpr`.
