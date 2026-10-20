## What changes, on a small example

`tests/testthat/test-substeps.R` builds a System that shows the
problem at small scale. A population grows slowly while drawing water
from two soil layers, a seasonal source fills the top layer, and water
drains from one layer to the next at a rate set by K. When K is large
the layers are stiff: their water level responds within a tiny
fraction of the time the population takes to change.

At K = 10 000, integrating to t = 2 at a tolerance of 1e-6, plain
Cash-Karp takes 1700 steps. Almost all of them are short because of
the water layers, not the population. When the System names the two
layers as its fast part, the same run takes 77 steps and ends closer
to an accurate reference: 9.4e-9 from it, against 1.8e-6 for the
plain run.

The figure shows one of those 77 steps. It is 38 times longer than
the steps plain Cash-Karp can take at that point. Taken as a plain
step, it would drive the first layer's water to −2e10. With this
change, the whole System is evaluated at the six usual points, and the
water layers are integrated across the step in 134 short substeps, so
they follow the accurate solution.

![One step of the example, 38 times longer than plain Cash-Karp's, with the six evaluations of the whole System and the 134 substeps of the water layers](FIG:odelia-57/one_step.png)

Substeps only pay where the fast part is stiff. When the layers are
not stiff, a plain step is cheaper, so the solver substeps only where
the fast part is what keeps the step short. Up to K = 100 it takes the
same steps as plain Cash-Karp. From K = 1000 up it takes 16 to 33
steps, where plain Cash-Karp takes 600 to 4800. An earlier version of
this branch substepped whenever the population drew little water from
the layers, whether or not they were stiff, and the figure shows how
much that cost at small K.

![Accepted steps against the drainage rate K for plain Cash-Karp, the earlier version, and this change](FIG:odelia-57/steps_vs_stiffness.png)

In plant, TF24 names its soil as its fast part (aornugent/plant#115).
A 40-year stand on daily rainfall then no longer needs to stop at
every day: it takes 0.41 times as many steps, and computing its
gradient takes 0.35 times as long.

## How a System takes part

A System names its fast part with four member functions, and the
concept `HasSubsystem` checks that it has them:

```cpp
state_range subsystem() const;
void subsystem_inputs(std::vector<T>& u) const;
void subsystem_rates(double t, const std::vector<T>& y,
                     const std::vector<T>& u, std::vector<T>& dydt) const;
std::vector<double> subsystem_knots(double from, double to) const;
```

`subsystem()` says which components of the state form the fast part.
`subsystem_inputs()` gives the one input per component that the fast
part reads from the rest of the state, and `subsystem_rates()` gives
the fast part's rates for a given state and given inputs. The solver
calls `subsystem_rates()` many times per step, so it should be cheap.
`subsystem_knots(from, to)` lists the times between `from` and `to`
where the fast part's forcing switches from one cubic to the next. A
System without forcing returns none, and a driver in odelia lists its
own with `drivers::Function::knots()`.

The substepped step itself is `take_substepped_step` in
`ode_step_rkck.hpp`, and the decision to substep is at the top of
`SolverInternal::step` in `ode_solver_internal.hpp`.

This is odelia 0.8.1, and #58 is stacked on it. One commit lets GCC 13
build `tests/standalone`: it crashed compiling a list of instructions
built from a `const double` local, and the local is now `constexpr`.
