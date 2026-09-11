# odelia

**Base** `traitecoevo/odelia:master` · **Head** `aornugent/odelia:ad/V4-reverse-tf24`
**Tag on merge** `v0.5.0` · **Blocks** phylloptim, then plant

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

## First comment

Five new headers (1,117 lines), two deleted, four rewritten. Three mechanisms
carry the change and the rest is plumbing, so this walks those three.

### What a forward pass leaves behind

`advance_adaptive(times)` is the same adaptive loop as before: `step()` asks for
one Runge–Kutta–Cash–Karp step, six evaluations of `System::ode_rates`, an
embedded error estimate, accept or shrink. On acceptance `push_step`
(`ode_solver_internal.hpp:269`) appends a row.

```
    step_record<System> : instruction
    ├── time        double         when this step started
    ├── step_size   double         h, as accepted
    ├── insertion   bool           did the state vector widen at this row
    ├── state[]     state_type     the full state the step began FROM
    └── solved[5]   solved_values  what five of the six stages solved for
```

`step_record` inherits `instruction` so the two cannot drift. Written as
separate structs differing by one member, pairing a time out of one container
with a state out of another was a thing that compiled (`:202`).

The array is five long because the sixth rate evaluation happens at the state
the step *ends* at, and first-same-as-last hands that to the next step as its own
first rates. A sweep re-derives it from the state it was handed. Nothing stores
it, so "a walk cannot trust the first stage of a recording it jumped into" is a
property of the layout and not a rule someone has to remember.

Six stage rates and five of the six stage states go unstored. Recomputing them
costs six model evaluations per step; holding them costs the whole trajectory.
A root-find's output is the one thing that is neither cheap to recompute nor
derivable from the state, which is what `solved[5]` is for.

On plant's century fixture a descent is 3,378 recorded steps and 20,268 rate
evaluations — exactly six per step, because every step is re-recorded whole.

### What narrowing across an introduction actually computes

This is the part the code comments describe correctly and briefly, and which is
worth spelling out because it is not the obvious implementation.

A **range** is a run of steps over which the state vector's width is constant.
plant's century fixture has 169 of them over its 3,378 steps: the schedule
introduces a cohort, the state vector gains that cohort's eight entries, and a
new range begins. Going backwards the sweep meets those boundaries in reverse,
so it only ever narrows.

The narrowing is not a projection, and lambda's extra entries are not dropped.
`apply_insertion` — the System's own map from the narrow state to the wide one —
is **recorded and swept like any other function** (`ode_solver.hpp:376-386`):

```
    forward:   y_wide = apply_insertion(time, y_narrow)
    reverse:   state_and_parameter_adjoints(widened, rec[at-1].state,
                                            lambda,        <- adjoint at wide width
                                            insert,        <- the map, as a lambda
                                            narrowed,      <- adjoint at narrow width
                                            parameter_adjoint)
    lambda = std::move(narrowed);
```

Two consequences. The map runs at the active scalar, so **a newborn's initial
conditions contribute trait derivatives** — `parameter_adjoint` is passed in and
accumulated here, not only inside the step sweeps. And the `active_system` built
for it is local and dies with it, because applying the map is what widens the
System: a recording made at the narrow width cannot be swept at the wide one.

A caller can also ask for cuts at rows of its own choosing. Cuts and
introductions resume in different places, which the loop distinguishes: a cut is
a row the sweep resumes **at**, an introduction is a row it carries the adjoint
**across**, so it resumes one row below, on the state the map ran on
(`ode_solver.hpp:344-347`). A row that is both is treated as the introduction.

Peak tape is one step's arithmetic at any run length. One tape is constructed for
the whole descent (`:335`) and `clearAll()` runs between recordings
(`adjoint.hpp:324`), so what accumulates across a descent is the trajectory in
`step_record`s, which is cheap, and never the arithmetic.

### How a submodel's derivative reaches the tape

Inside a stage, `ode_rates` may reach a quantity a solve found. Recording the
solve would put the solver's iterations into the answer, so
`record_with_derivatives(value, rows, into)` (`implicit_node.hpp:71`) puts the
number on the tape carrying rows it was handed:

```
    out = value + Σ dᵢ · (xᵢ − to_passive(xᵢ))
                        └───────┬───────┘
                        exactly zero in value;
                        carries the derivative
```

`to_passive` strips every AD layer, so each bracket is numerically zero and the
forward value is `value` alone. The derivative is whatever `dᵢ` says. The whole
sum is **one tape statement whatever the row count**, because a statement is one
left-hand side over a run of operations. Written the obvious way,
`out += d * (x - to_passive(x))` in a loop, it is `n` recorded assignments, which
is how a submodel's entire arithmetic ends up on its consumer's tape.

Every row is checked for finiteness before any is recorded, and the report is
`[[nodiscard]]`. A value carrying *some* of its rows is a channel that has gone
missing with every number still finite; a consumer told the rows are absent can
carry the value as a constant and say so.

`implicit_value(y*, dFdy, F)` (`:165`) specialises this to a scalar root. It
supplies the residual's slope in the unknown and records the residual to get its
slopes in the parameters, giving `dy*/dp = −(∂F/∂p)/(∂F/∂y)`.

### Scalars

`tangent_scalar<T>` is the tapeless forward scalar. It lives in `tangent.hpp`,
away from `adjoint.hpp`, so a consumer wanting a directional derivative is never
handed a name for a tape it has no use for.

`with_slope<T>` is a value and its slope as one type. Handed the two separately a
consumer can pair them across different points, different orders, or different
independent variables, and all three compile.

`tangent.hpp:36` makes a tangent nested above an adjoint a compile error. At an
active inner scalar every operand copy inside an expression template becomes a
recorded statement, and the growth is superlinear in expression depth: three
kernels costing 31 statements flat cost 566 nested.

### Interpolation

`hermite_interpolator` absorbs the deleted spline. It is local cubic Hermite, C1,
linear past the end knots; the old one was global natural cubic, C2, quadratic
past the end. Knots are hit exactly and everything between and beyond differs. A
caller supplying only values gets Fritsch–Carlson limited slopes.

Local, because a global fit spreads a local defect: on the curve this library
tabulates it converged at `h²` where the same knots read as a Hermite converged
at `h³·⁷`. A global solve also makes every knot influence every span, so an
adjoint that was O(1) becomes O(K). Nothing read a second derivative.

Nothing in phylloptim or plant included `spline.hpp` or `ode_fit.hpp`, so the
in-family migration cost is zero.

### Reading order

1. `tangent.hpp`, `with_slope.hpp` — 119 lines of vocabulary.
2. `ode_interface.hpp:196-222` — `instruction` and `step_record`. Everything the reverse pass may read.
3. `ode_solver_internal.hpp:269` — `push_step`, the only writer.
4. `adjoint.hpp:304` — `vector_jacobian_product`.
5. `ode_solver.hpp:336-392` — the range loop, including the narrowing above.
6. `implicit_node.hpp` — independent of the solver, and what phylloptim consumes.

### What to check it against

| claim | where |
|---|---|
| Peak tape is one step whatever the run length | `clearAll()` per recording, `adjoint.hpp:324`, `:417`; one tape per descent, `ode_solver.hpp:335` |
| A segmented sweep equals a whole one bit for bit | the two `solve_adjoint` overloads, `:287` and `:397` |
| A recording cannot end at an introduction | `:309` — an introduction is carried across, so there is no row below it to resume on |
| The System's width is restored on every exit including a throw | `restore_on_exit`, `:318-330` |
| An attachment is one statement whatever the row count | asserted, `tests/standalone/r_free.cpp:507` |
| All rows are checked before any is recorded | `implicit_node.hpp:79`; on failure `into = value` and the report names the input |

Two changes a System author must act on. The contract became concepts —
`HasOdeTime`, `SolvesForValues`, `ChecksState`, `Rebindable`
(`ode_interface.hpp:101-263`) — and `rebind()` became `rebind_from()`, with the
target scalar named and not defaulted, because "defaulting it to the System's own
scalar asks whether a System can rebind to the scalar it already has, which is a
different question" (`:109`). Separately, `visit_active` skips a shape it cannot
open in silence (`:66`), so anything carrying a derivative row must declare
`for_each_active` or contribute nothing with every number still finite.

### File inventory

| header | lines | holds |
|---|---|---|
| `adjoint.hpp` | 507 | `adjoint_rows`, `active_system`, `tape_scope`, `vector_jacobian_product`, `state_and_parameter_adjoints` |
| `implicit_node.hpp` | 397 | `record_with_derivatives`, `implicit_value`, `preaccumulate`, `record_report` |
| `sweep.hpp` | 94 | `state_at_range`, `program_from`; consumed by plant's `scm.h` |
| `tangent.hpp` | 75 | `tangent_scalar`, `seed_direction`, `derivative_along`, the nesting assert |
| `with_slope.hpp` | 44 | `with_slope<T>` |
| `interpolator.hpp` | +640 | absorbs the spline as `hermite_interpolator` |
| `ode_interface.hpp` | +496 | the System contract, now concepts |
| `ode_solver.hpp` | +392 | the recording and `solve_adjoint` |
| `solver_interface.hpp` | −293 net | the passive/active Solver pair collapses to one |

Deleted: `spline.hpp` (466), `ode_fit.hpp` (100).
