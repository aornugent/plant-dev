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
for a value a submodel solved for rather than computed. `spline.hpp`
becomes `hermite_interpolator`, which takes a slope alongside each knot
value; values move for a caller that has only knot values. `ode_fit.hpp`
and its `Solver_fit()` / `Solver_set_target()` bindings are removed, and
`Solver_*` no longer takes `active`.

Closes #

## First comment

Five new headers (1,117 lines), two deleted (`spline.hpp` 466, `ode_fit.hpp`
100), four substantially rewritten. The walkthrough below is the whole change;
the file table is at the end.

### How a run is recorded

`advance_adaptive(times)` is the ordinary adaptive loop and is unchanged in
shape: `step()` asks `SolverInternal` for one Runge–Kutta–Cash–Karp step — six
evaluations of `System::ode_rates`, an embedded error estimate, accept or
shrink. What is new is that on acceptance `push_step` (`ode_solver_internal.hpp:269`)
appends a row to a recording:

```
    step_record<System> : instruction
    ├── time        double        when this step started
    ├── step_size   double        h, as accepted
    ├── insertion   bool          did the state vector widen at this row
    ├── state[]     state_type    the FULL state the step began from
    └── solved[5]   solved_values what each of five stages solved for
```

It derives from `instruction` rather than repeating those first three fields.
Written as two structs differing by one member, pairing a time out of one
container with a state out of another was a thing that compiled (`:202`).

**Five stages, not six, and the reason is load-bearing.** The sixth rate
evaluation a step makes is at the state it *ends* at, and first-same-as-last
hands that to the next step as its own first rates. A sweep re-derives it at the
state it was handed rather than reading it, so there is no slot for it — which
makes *a walk cannot trust the first stage of a recording it jumped into* a
structural property rather than a warning someone has to remember.

What is deliberately absent is the six stage rates and five of the six stage
states. Those are cheap to recompute and expensive to hold. What cannot be
recomputed is anything a root-find produced inside a stage, and that is exactly
what `solved[5]` carries.

An introduction — plant widening its state vector by a cohort — is a row like
any other with `insertion` set, and its state is what the widening map produced.
So no row carries two states and nothing has to choose between them.

### How the sweep runs it backwards

```
   FORWARD                                  REVERSE
   ───────────────────────────              ──────────────────────────────────────
   advance_adaptive(times)                  solve_adjoint(lambda, param_adj)
     │                                        │
     └─► step()                               └─► for each RANGE, widest first
           │  6 × ode_rates()                       │    a range = consecutive steps
           │  error, accept/shrink                  │    over which the width is constant
           │                                        │
           └─► push_step() ──► rec[k]               ├─► narrow lambda across the
                                 │                  │    introduction, transposing
                                 │                  │    the map that widened it
                                 │                  │
                                 │                  └─► for each step, LAST to FIRST
                                 │                        │
                                 └──────────────────────► ├─ load rec[k].state
                                                          ├─ re-record all 6 stages
    ode_rates() runs a SECOND time here ◄─────────────────┤    at active_scalar
                                                          ├─ vector_jacobian_product:
                                                          │    sweep once per seed row
                                                          └─ Tape::clearAll()
```

A **range** is a run of steps over which the state vector's width does not
change. The sweep takes ranges widest-first because the trajectory only ever
widens going forward, so going backwards it only ever narrows — and each
narrowing is a linear map the sweep transposes rather than a discontinuity it
would have to handle.

Within a range the sweep walks steps in reverse. For each one it loads the
recorded state, re-records the whole six-stage step at an active scalar, and
hands that recording to `vector_jacobian_product` (`adjoint.hpp:304`), which
sweeps it once per seed row. Then `Tape::clearAll()`. **That call is what bounds
memory**: one tape is constructed for the whole descent (`ode_solver.hpp:335`)
and cleared between recordings, so peak tape is one step's arithmetic no matter
how long the run was.

The consequence to hold while reading: the re-recording **re-enters the forward
model**. `ode_rates` runs twice per step over the whole descent, once in plain
`double` on the way out and once at the active scalar on the way back. Anything
cached between calls, or anything that depends on the order rates are computed
in, differs between the two passes unless something makes it agree.

Two asymmetries in the outputs, both deliberate: `lambda` is **replaced** each
sweep, while `parameter_adjoint` **accumulates** with `+=` (`adjoint.hpp:447`),
so the caller zeroes it and the sweep adds into it across ranges.

### How a submodel's derivative gets onto the tape

The seam sits inside a stage. When `ode_rates` reaches a quantity that a solve
found rather than arithmetic computed, it does not put the solve on the tape.
`record_with_derivatives(value, rows, into)` (`implicit_node.hpp:71`) puts the
number there carrying rows it was handed:

```
    out = value + Σ dᵢ · (xᵢ − to_passive(xᵢ))
                        └──────┬──────┘
                          zero in value,
                          carries the derivative
```

Each bracket is exactly zero, so the forward value is `value` and nothing else;
the derivative is whatever `dᵢ` says. The whole sum is **one tape statement
whatever the row count**, because a statement is one left-hand side over a run
of operations. Written the obvious way as `out += d * (x - to_passive(x))` it
would be `n` recorded assignments — which is how a submodel's entire arithmetic
ends up on a consumer's tape.

Every row is checked for finiteness before any is recorded, and the return is
`[[nodiscard]]` (`:68`): a value carrying *some* of its rows is a channel that
has gone missing with every number still finite, which is worse than no rows at
all, because a consumer told the rows are absent can carry the value as a
constant and say so.

`implicit_value(y*, dFdy, F)` (`:165`) is the same mechanism specialised to a
scalar root: it supplies the residual's slope in the unknown and records the
residual to get its slopes in the parameters, giving `dy*/dp = −(∂F/∂p)/(∂F/∂y)`.

### The rest of the surface

`tangent.hpp` and `with_slope.hpp` are 119 lines between them and hold the
vocabulary the rest uses. `tangent_scalar<T>` is the tapeless forward scalar,
kept away from `adjoint.hpp` so a consumer wanting a directional derivative is
never handed a name for a tape it does not have. `with_slope<T>` is a value and
its slope as one type, because a consumer handed the two separately can pair
them across different points, different orders or different independent
variables, and all three compile.

`tangent.hpp:36` refuses a tangent nested above an adjoint at compile time. At an
active inner scalar every operand copy inside an expression template becomes a
recorded statement, and the growth is superlinear in expression depth: three
kernels costing 31 statements flat cost 566 nested.

`hermite_interpolator` absorbs the deleted spline. It is local cubic Hermite, C1,
linear past the end knots, against the old global natural cubic, C2, quadratic
past the end. Knots are hit exactly and everything between and beyond differs; a
caller with only values gets Fritsch–Carlson limited slopes. Local rather than
global because the global fit converged at `h²` where the same knots read as a
Hermite converged at `h³·⁷`, and because a global solve makes every knot
influence every span, turning an O(1) adjoint into an O(K) one.

### Reading order

1. `tangent.hpp`, `with_slope.hpp` — the vocabulary, 119 lines.
2. `ode_interface.hpp:196-222` — `instruction` and `step_record`. Everything the reverse pass may read.
3. `ode_solver_internal.hpp:269` — `push_step`, the only place a record is written.
4. `adjoint.hpp:304` — `vector_jacobian_product`.
5. `ode_solver.hpp:287` — `solve_adjoint` and the range loop over it.
6. `implicit_node.hpp` — independent of the solver; this is what phylloptim consumes.

### What to check it against

| claim | where |
|---|---|
| Peak tape is one step whatever the run length | `clearAll()` per recording, `adjoint.hpp:324`, `:417`; one tape for the descent, `ode_solver.hpp:335` |
| A segmented sweep equals a whole one bit for bit | the two `solve_adjoint` overloads, `:287` and `:397` |
| The System's width is restored on every exit including a throw | `restore_on_exit`, `ode_solver.hpp:318-330` |
| An attachment is one statement whatever the row count | asserted, `tests/standalone/r_free.cpp:507` |
| All rows are checked before any is recorded | `implicit_node.hpp:79` — on failure `into = value` and the report names the input |
| A tangent above an adjoint is a compile error | `tangent.hpp:36` |

Two things a System author must know. The contract became concepts —
`HasOdeTime`, `SolvesForValues`, `ChecksState`, `Rebindable`
(`ode_interface.hpp:101-263`) — and `rebind()` became `rebind_from()`, with the
target scalar named rather than defaulted because *"defaulting it to the
System's own scalar asks whether a System can rebind to the scalar it already
has, which is a different question"* (`:109`). And `visit_active` skips a shape
it cannot open **in silence** (`:66`), so anything carrying a derivative row must
declare `for_each_active` or contribute nothing with every number still finite.

### File inventory

| header | lines | holds |
|---|---|---|
| `adjoint.hpp` | 507 | `adjoint_rows`, `active_system`, `tape_scope`, `vector_jacobian_product`, `state_and_parameter_adjoints` |
| `implicit_node.hpp` | 397 | `record_with_derivatives`, `implicit_value`, `preaccumulate`, `record_report` |
| `sweep.hpp` | 94 | `state_at_range`, `program_from` — replay helpers; consumed by plant's `scm.h` |
| `tangent.hpp` | 75 | `tangent_scalar`, `seed_direction`, `derivative_along`, the nesting assert |
| `with_slope.hpp` | 44 | `with_slope<T>` |
| `interpolator.hpp` | +640 | absorbs the spline as `hermite_interpolator` |
| `ode_interface.hpp` | +496 | the System contract, now concepts |
| `ode_solver.hpp` | +392 | the recording and `solve_adjoint` |
| `solver_interface.hpp` | −293 net | the passive/active Solver pair collapses to one |

Nothing in phylloptim or plant included `spline.hpp` or `ode_fit.hpp`, so the
in-family migration cost is zero.
