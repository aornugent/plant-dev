# odelia

**Base** `traitecoevo/odelia:master` · **Head** `aornugent/odelia:ad/V4-reverse-tf24`
**Tag on merge** `v0.5.0` · **Blocks** phylloptim, then plant

Four comments, posted in order when the pull request opens. A reviewer reads 1
before opening a file, 2 alongside the code, 3 while hunting, and 4 when they
want a number.

## Title

Differentiate a recorded run in reverse mode

## Body

Calibrating a model against data needs the derivative of a solved
trajectory with respect to every parameter. Forward mode costs one solve
per parameter. Reverse mode costs one solve for all of them, but it must
record every operation the solve performed first, and a run of several
thousand adaptive steps performs far more than memory holds.

`Solver::solve_adjoint()` computes that derivative. The forward pass
stores one `step_record` per accepted step; the reverse pass re-records
one step's arithmetic at a time, so the tape never grows past a single
step. `implicit_node.hpp` attaches a derivative obtained by other means,
for a value a submodel solved for instead of computing. `spline.hpp`
becomes `hermite_interpolator`, which takes a slope alongside each knot
value; values move for a caller that has only knot values. `ode_fit.hpp`
and its `Solver_fit()` / `Solver_set_target()` bindings are removed, and
`Solver_*` no longer takes `active`.

Closes #

---

# Comment 1 — What this does, and the words for it

## The problem

odelia solves ordinary differential equations. A user writes a **System** — a
type that can report its state, set its state, and compute rates — and hands it
to a `Solver`, which integrates it forward with adaptive step sizes.

Suppose the System has parameters, and you want to know how the solution at the
end of a run responds to each of them. Fitting a model to data is exactly this
question, asked repeatedly.

Two ways to answer it. **Forward mode** pushes one parameter's perturbation
through the whole calculation, so `p` parameters cost `p` solves. **Reverse
mode** walks the calculation backwards from the answer and picks up every
parameter on the way, so `p` parameters cost one solve — but it can only walk
backwards over arithmetic it has a record of, and that record is the problem this
change solves.

## Vocabulary

These words appear throughout the diff and most are not general C++ terms.

**Tape.** A linear log of arithmetic operations, appended to as a calculation
runs. Reverse mode walks it backwards.

**Statement.** One entry on the tape: a single left-hand side covering a run of
operations. Tape cost is counted in statements, not in arithmetic — this matters
later, because `a = b*c + d*e + f*g` is one statement and three separate
assignments are three.

**Recording.** Whatever is on the tape between one clear and the next. This
change makes a recording exactly one solver step.

**Seed.** The derivative you hand the backward walk to start it off. One seed per
output you want derivatives of.

**Row.** One output's derivatives with respect to a list of inputs — a row of the
Jacobian. `adjoint_rows` is a batch of them.

**Sweep.** One backward walk of a recording, from one seed.

**Adjoint** (reverse mode) carries `d(output)/d(this intermediate)` backwards.
**Tangent** (forward mode) carries `d(this intermediate)/d(input)` forwards.
They are separate scalar types here and separate headers.

**Range.** A run of consecutive recorded steps over which the state vector's
length does not change. A System whose state grows during a run — plant gains a
cohort — has several.

## The ordinary path

Nothing below is an exception case. This is what happens on a run that works.

```
  1.  solver.set_keep_states(true)          ask for the trajectory to be kept
  2.  solver.advance_adaptive(times)        integrate; one step_record per
                                            accepted step
  3.  build a seed                          one row per output whose derivative
                                            you want, as adjoint_rows
  4.  solver.solve_adjoint(lambda,          walk it backwards
                           parameter_adjoint)
  5.  read parameter_adjoint                one row per seed, one column per
                                            parameter
```

Step 2 is the ordinary adaptive loop and is unchanged: six Runge–Kutta–Cash–Karp
stage evaluations, an embedded error estimate, accept or shrink. What is new is
that each accepted step appends a `step_record`.

Step 4 walks those records in reverse. For each one it loads the stored state,
re-runs the step's six stages at an active scalar so the arithmetic lands on the
tape, sweeps that recording once per seed, then clears the tape. `lambda` is
replaced as it goes and holds the state adjoint; `parameter_adjoint` accumulates.

That is the whole design. One number to hold onto: on plant's century fixture the
descent is 3,378 steps and 20,268 rate evaluations, exactly six per step, because
every step is re-run whole.

## What a reviewer will see

Five new headers, 1,117 lines:

| header | lines | holds |
|---|---|---|
| `adjoint.hpp` | 507 | `adjoint_rows`, `active_system`, `vector_jacobian_product`, `state_and_parameter_adjoints` |
| `implicit_node.hpp` | 397 | `record_with_derivatives`, `implicit_value`, `preaccumulate` |
| `sweep.hpp` | 94 | `state_at_range`, `program_from`; plant's `scm.h` consumes these |
| `tangent.hpp` | 75 | `tangent_scalar`, `seed_direction`, `derivative_along` |
| `with_slope.hpp` | 44 | `with_slope<T>` |

Four rewritten: `interpolator.hpp` (+640, absorbs the deleted spline),
`ode_interface.hpp` (+496, the System contract becomes C++20 concepts),
`ode_solver.hpp` (+392, the recording and `solve_adjoint`), `solver_interface.hpp`
(−293 net, the passive/active Solver pair collapses to one).

Two deleted: `spline.hpp` (466), `ode_fit.hpp` (100). Nothing in phylloptim or
plant included either.

Suggested order: `tangent.hpp` and `with_slope.hpp` first (119 lines of
vocabulary), then `ode_interface.hpp:196-222` for what a record holds, then
`ode_solver_internal.hpp:269` for the one place a record is written, then
`adjoint.hpp:304` and `ode_solver.hpp:336` for the walk. `implicit_node.hpp` is
independent of the solver and can be read any time.

---

# Comment 2 — How the three interesting parts work

## What a forward pass leaves behind

Each accepted step appends one row:

```
    step_record<System> : instruction
    ├── time        double         when this step started
    ├── step_size   double         h, as accepted
    ├── insertion   bool           did the state vector grow at this row
    ├── state[]     state_type     the full state the step began FROM
    └── solved[5]   solved_values  what five of the six stages solved for
```

Memory across a descent is therefore `n_steps × (n_state + 5 × sizeof(solved))`.
The six stage rates and five of the six stage states are not stored: recomputing
them costs six model evaluations per step, holding them costs the whole
trajectory.

`solved[5]` exists for the one kind of value that is neither cheap to recompute
nor derivable from the state — anything a root-find produced inside a stage. In
plant's case that is a leaf's operating point, found by iteration.

The array is five long, not six. The sixth rate evaluation happens at the state
the step *ends* at, and first-same-as-last hands it to the next step as its own
first rates, so a sweep re-derives it from the state it was handed. Nothing
stores it. The consequence is a property of the layout: a walk cannot trust the
first stage of a recording it jumped into.

`step_record` inherits `instruction` so the two cannot drift apart. As separate
structs differing by one member, pairing a time out of one container with a state
out of another was a thing that compiled (`ode_interface.hpp:202`).

## What happens when the state vector grows

plant introduces cohorts on a schedule, and each introduction lengthens the state
vector. Going forwards the vector only grows, so going backwards the sweep only
narrows, and each narrowing is a boundary between ranges. The century fixture has
169 ranges over its 3,378 steps.

The narrowing is not a projection and lambda's extra entries are not dropped. The
System's own widening map is **recorded and swept like any other function**
(`ode_solver.hpp:376-386`):

```
   forward    y_wide = apply_insertion(time, y_narrow)

   reverse    state_and_parameter_adjoints(widened, rec[at-1].state,
                                           lambda,             adjoint at wide width
                                           insert,             the map, as a lambda
                                           narrowed,           adjoint at narrow width
                                           parameter_adjoint)  accumulated here too
              lambda = std::move(narrowed);
```

Two things follow. The map runs at an active scalar and `parameter_adjoint` is
passed into it, so a newborn's initial conditions contribute parameter
derivatives — not only the steps do. And the `active_system` built for it is
local and dies with it, because applying the map is what widens the System: a
recording made at the narrow width cannot be swept at the wide one.

A caller can also request cuts at rows of its own choosing, for a partial sweep.
Cuts and introductions resume in different places and the loop distinguishes
them: a cut is a row the sweep resumes **at**; an introduction is a row it
carries the adjoint **across**, so it resumes one row below, on the state the map
ran on (`:344-347`).

Peak tape is one step's arithmetic at any run length. One tape is constructed for
the whole descent (`:335`) and cleared between recordings (`adjoint.hpp:324`), so
what accumulates across a descent is the trajectory, never the arithmetic.

## How a value solved elsewhere gets a derivative

Inside a stage, `ode_rates` may reach a quantity that a solve found by iteration.
Recording the iterations would put the solver's own convergence into the answer,
so `record_with_derivatives(value, rows, into)` (`implicit_node.hpp:71`) puts the
number on the tape carrying rows it was handed instead:

```
    out = value + Σ dᵢ · (xᵢ − to_passive(xᵢ))
                        └───────┬───────┘
                        exactly zero in value;
                        carries the derivative
```

`to_passive` strips every AD layer from a scalar, so each bracket is numerically
zero and the forward value is `value` alone. The derivative is whatever `dᵢ`
says.

The whole sum is one statement, whatever the row count, because a statement is
one left-hand side over a run of operations. Written the obvious way as
`out += d * (x - to_passive(x))` in a loop it is `n` recorded assignments — which
is how a submodel's entire arithmetic ends up on its consumer's tape.

`implicit_value(y*, dFdy, F)` (`:165`) specialises this to a scalar root. Given
the root `y*` of `F(y, p) = 0` and the residual's slope in the unknown, it
records the residual to obtain its slopes in the parameters, giving
`dy*/dp = −(∂F/∂p)/(∂F/∂y)`.

## Scalars

`tangent_scalar<T>` is the forward scalar and touches no tape. It lives in
`tangent.hpp`, away from `adjoint.hpp`, so a consumer wanting a directional
derivative is never handed a name for a tape it has no use for.

`with_slope<T>` pairs a value with its slope in one type. Handed the two
separately, a consumer can pair them across different points, different orders or
different independent variables, and all three compile.

## Interpolation

`hermite_interpolator` absorbs the deleted spline: local cubic Hermite, C1,
linear past the end knots, against the old global natural cubic, C2, quadratic
past the end. Knots are hit exactly; everything between and beyond differs. A
caller supplying only values gets Fritsch–Carlson limited slopes.

Local, because a global fit spreads a local defect: on the curve this library
tabulates it converged at `h²` where the same knots read as a Hermite converged
at `h³·⁷`. A global solve also makes every knot influence every span, turning an
O(1) adjoint into an O(K) one. Nothing read a second derivative.

---

# Comment 3 — What to check, and what breaks

## The caller's obligations

`solve_adjoint` asks four things and checks all of them at run time:

- `set_keep_states(true)` before the run, or there is no recording to sweep.
- `parameter_adjoint` sized to at least one row per seed, width equal to the
  parameter count, and **zeroed by the caller** — it accumulates with `+=`
  (`adjoint.hpp:387-400`).
- `lambda` seeded at the run's final state width.
- `state_adjoint` and `parameter_adjoint` are different batches. One is replaced
  and one accumulated, so aliasing them is refused explicitly.

## Claims worth disbelieving

| claim | where |
|---|---|
| Peak tape is one step at any run length | `clearAll()` per recording, `adjoint.hpp:324`, `:417`; one tape per descent, `ode_solver.hpp:335` |
| A segmented sweep equals a whole one bit for bit | the two `solve_adjoint` overloads, `:287` and `:397` |
| A recording cannot end at an introduction | `:309`. An introduction is carried across, so there is no row below it to resume on |
| The System's width is restored on every exit including a throw | `restore_on_exit`, `:318-330` |
| An attachment is one statement whatever the row count | asserted, `tests/standalone/r_free.cpp:507` |
| Every row is checked before any is recorded | `implicit_node.hpp:79`. On failure `into = value` and the report names the input |

That last one is deliberate and worth stating positively: a value carrying *some*
of its rows is a channel that has gone missing with every number still finite. A
consumer told the rows are absent can carry the value as a constant and say so,
which is why the report is `[[nodiscard]]`.

## Silent failure modes

**`visit_active` skips a shape it cannot open, without complaint**
(`ode_interface.hpp:66`). It dispatches on `for_each_active`, then container, then
pointer, and falls off the end doing nothing for an aggregate matching none.
Anything carrying a derivative row must declare `for_each_active` or contribute
nothing, with every number still finite. This is why `with_slope` is a type and
not two arguments.

**A tangent nested above an adjoint is refused at compile time**
(`tangent.hpp:36`). At an active inner scalar every operand copy inside an
expression template becomes a recorded statement, and growth is superlinear in
expression depth: three kernels costing 31 statements flat cost 566 nested.

## Migration

A System entering a sweep must now provide `rebind_from`, `ad_parameters`,
`for_each_active` and `set_recorded_state`; a System whose width grows also needs
`apply_insertion`.

`rebind()` became `rebind_from()`, with the target scalar named and not
defaulted, because *"defaulting it to the System's own scalar asks whether a
System can rebind to the scalar it already has, which is a different question"*
(`ode_interface.hpp:109`).

The contract is now concepts — `HasOdeTime`, `SolvesForValues`, `ChecksState`,
`Rebindable` (`:101-263`) — replacing the old `needs_time` / `has_cache` /
`has_state_check` traits.

R loses `Solver_fit()`, `Solver_set_target()` and the `active` argument on all
fifteen `Solver_*` bindings. Fitting is C++-only now; `ode_fit.hpp`'s
`compute_gradient` has no drop-in, and `vector_jacobian_product` plus `sweep.hpp`
replace it with the loss and the optimiser loop becoming the caller's.

---

# Comment 4 — What it costs, and what was refused

## Why the derivative is supplied and not recorded

Solving a submodel in plain arithmetic and handing the outer tape a derivative
block obtained elsewhere is the first-class use case of every AD framework
surveyed: JAX's `custom_root` and `custom_vjp`, PyTorch's `autograd.Function`,
ADOL-C's `ext_diff_fct`, CoDiPack's `ExternalFunctionHelper`, dco/c++'s external
adjoints, Tapenade's `_D`/`_B`. Naumann names two variants — preaccumulation,
which sweeps an inner tape `min(n, m)` times, and the Symbolic Adjoint pattern,
which uses the implicit function theorem and sweeps nothing. This is the second.

Counted in statements walked, since recording and sweeping cost the same
traversal, with `T` submodel statements, `k` seeds and `m` outputs:

| | walks per solve | at T=360, k=3, m=6 |
|---|---|---|
| recorded inline | `T + kT` | 1440 |
| preaccumulated | `T + mT + m + km` | 2544 |
| supplied | `m + km` | 24 |

Preaccumulation loses whenever the submodel has more outputs than the consumer
has seeds. phylloptim's leaf has double, so it spends six inner sweeps to save
three outer ones.

## Alternatives measured and rejected

| refused | measurement |
|---|---|
| carrying a forward direction on top of a reverse tape, for cheap second derivatives | three kernels: 31 statements flat, 566 nested, 18.3× |
| widening the derivative type so one traversal serves several outputs | between 1.15× slower and 0.97× faster; the traversal is shared but the scatter is three times the bytes |
| a dense derivative block for all six leaf outputs | six sweeps against three walks: 39 µs against 34 |
| moving the tape instead of shrinking it | recording costs sixteen times what sweeping costs |
| a private tape per solved submodel | constructing a tape reserves 192 MiB |

## Probes

Seven standalone programs under `tests/standalone/`, one translation unit each,
no R. Reading the AD library's source did not settle what its statement and slot
counters count across nested recordings, and a probe settles such a question in
about twenty lines.
