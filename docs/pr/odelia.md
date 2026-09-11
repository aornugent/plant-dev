# odelia

**Base** `traitecoevo/odelia:master` · **Head** `aornugent/odelia:ad/V4-reverse-tf24`
**Tag on merge** `v0.5.0` · **Blocks** phylloptim, then plant

Two comments, posted in order.

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

# Comment 1 — What this is and what it changes

## Terms

Four words carry most of the diff, and three of them have a consequence attached
that is easy to miss.

**Tape.** A linear log of arithmetic, appended to as a calculation runs. Reverse
mode walks it backwards. Everything hard about this change comes from the tape
being finite and a trajectory being long.

**Statement.** One tape entry: a single left-hand side covering a run of
operations. Tape cost is counted in statements, not in arithmetic, and the
distinction matters more than it sounds. `a = b*c + d*e + f*g` is one statement.
The same arithmetic written as three `a += ...` lines is three. A submodel that
hands over its derivative as a loop of `+=` therefore costs its consumer one
statement per row; written as a single expression it costs one statement no
matter how many rows there are. That difference is the entire reason
`implicit_node.hpp` exists.

**Seed and row.** A seed is the starting derivative handed to a backward walk,
one per output whose derivatives are wanted. A row is one output's derivatives
against a list of inputs. `adjoint_rows` is a batch of rows, because the
expensive part of a sweep is the traversal and several seeds can share it.

**Range.** Consecutive recorded steps over which the state vector's length does
not change. A System of fixed width has exactly one. plant gains a cohort's
worth of entries at every introduction, so its century fixture has 169.

## The call, and what it requires of the caller

```cpp
  solver.set_keep_states(true);
  solver.advance_adaptive(times);            // one step_record per accepted step
  solver.solve_adjoint(lambda,               // seeded at the final width
                       parameter_adjoint);
```

`advance_adaptive` is the existing adaptive loop and behaves as it did: six
Runge–Kutta–Cash–Karp stage evaluations, an embedded error estimate, accept or
shrink. The only change is that each accepted step appends a record, and only
when `set_keep_states(true)` asked for it.

`solve_adjoint` has four requirements and checks all of them at run time
(`adjoint.hpp:387-400`). `lambda` arrives seeded at the run's final state width
and is **replaced** as the walk narrows. `parameter_adjoint` arrives at one row
per seed, width equal to the parameter count, and **zeroed by the caller**,
because it accumulates with `+=` across ranges rather than being overwritten.
Those two must be different batches, and passing the same one twice is refused
explicitly: one is replaced and one accumulated, so aliasing them silently loses
whichever was written first.

The return value is the number of ranges swept.

## Control flow

```
  FORWARD                              REVERSE
  advance_adaptive(times)              solve_adjoint(lambda, param_adj)
    │                                    │
    ├─► step()                           ├─► range 169 … 1          widest first
    │     6 × ode_rates()                │     │
    │     error, accept or shrink        │     ├─► step k … 1       last to first
    │                                    │     │     ├─ load rec[k].state
    └─► push_step() ──► rec[k] ──────────┘     │     ├─ re-run 6 stages ───┐
                                               │     ├─ sweep × n_seed     │
                                               │     └─ Tape::clearAll()   │
                                               │                           │
                                               └─► at an introduction:     │
                                                     sweep apply_insertion │
                                                                           │
        System::ode_rates ◄────────────────────────────────────────────────┘
        runs twice per step: forward in double, again here at active_scalar
```

The edge at the bottom is the one to hold onto. The reverse pass does not read
cached rates; it re-runs the model. On plant's century fixture that is 3,378
steps and 20,268 rate evaluations, exactly six per step, because every step is
re-run whole. Anything cached between calls, or anything depending on the order
rates are computed in, will differ between the two passes unless something makes
it agree.

## What changes for an existing System

The trait-based contract becomes C++20 concepts. `needs_time`, `has_cache` and
`has_state_check` are replaced by `HasOdeTime`, `SolvesForValues`, `ChecksState`
and `Rebindable` (`ode_interface.hpp:101-263`). A System that only needs solving
is unaffected by most of this; a System entering a sweep must additionally
provide `rebind_from`, `ad_parameters`, `for_each_active` and
`set_recorded_state`, and one whose state grows mid-run must provide
`apply_insertion`.

`rebind()` becomes `rebind_from()`, and the target scalar is now a named template
parameter instead of a defaulted one. The reason is in the header: *"defaulting
it to the System's own scalar asks whether a System can rebind to the scalar it
already has, which is a different question"* (`:109`). The old form could be
satisfied by a System that could not actually lift itself.

On the R side, `Solver_fit()` and `Solver_set_target()` are gone along with
`ode_fit.hpp`, and all fifteen `Solver_*` bindings lose their `active` argument —
the passive and active Solver types have collapsed into one. Fitting is now a
C++-only activity, and `compute_gradient` has no drop-in replacement:
`vector_jacobian_product` plus `sweep.hpp` cover the same ground, with the loss
function and the optimiser loop becoming the caller's business.

## Files

| header | lines | holds |
|---|---|---|
| `adjoint.hpp` | 507 | `adjoint_rows`, `active_system`, `vector_jacobian_product`, `state_and_parameter_adjoints` |
| `implicit_node.hpp` | 397 | `record_with_derivatives`, `implicit_value`, `preaccumulate` |
| `sweep.hpp` | 94 | `state_at_range`, `program_from`; plant's `scm.h` consumes both |
| `tangent.hpp` | 75 | `tangent_scalar`, `seed_direction`, `derivative_along` |
| `with_slope.hpp` | 55 | `with_slope<T>` |

Rewritten: `interpolator.hpp` (+651, absorbs the spline), `ode_interface.hpp`
(+509, the contract above), `ode_solver.hpp` (+392, the recording and
`solve_adjoint`), `solver_interface.hpp` (−293 net, the Solver pair collapsing).
Deleted: `spline.hpp` (466), `ode_fit.hpp` (100). Neither was included by
phylloptim or plant, so the in-family migration cost is zero.

Read `tangent.hpp` and `with_slope.hpp` first — 119 lines and everything else
uses them. Then `ode_interface.hpp:196-222` for what a record holds,
`ode_solver_internal.hpp:269` for the one place records are written,
`adjoint.hpp:304` for the sweep primitive, and `ode_solver.hpp:336` for the loop
that drives it. `implicit_node.hpp` is independent of the solver and can be read
at any point.

---

# Comment 2 — How it works

## What a forward pass leaves behind

```
    step_record<System> : instruction
    ├── time        double         when this step started
    ├── step_size   double         h, as accepted
    ├── insertion   bool           did the state vector grow here
    ├── state[]     state_type     the full state the step began FROM
    └── solved[5]   solved_values  what five of the six stages solved for
```

Memory across a descent is `n_steps × (n_state + 5 × sizeof(solved))`. Stage
rates and the intermediate stage states are absent by choice: recomputing them
costs six model evaluations per step, holding them costs the whole trajectory,
and for a right-hand side this cheap relative to its own length the recomputation
wins easily.

`solved[5]` exists for the one class of value that is neither cheap to recompute
nor derivable from the state — anything a root-find produced inside a stage. For
plant that is a leaf's operating point, found by iteration, whose value depends
on where the iteration started. A later pass cannot re-derive it; it has to be
told.

The array is five long and not six, and the reason is a property of the stepper.
Runge–Kutta–Cash–Karp is first-same-as-last: the sixth rate evaluation of a step
happens at the state that step ends at, which is precisely the state the next
step begins from, so the next step reuses it as its own first stage. A sweep
therefore re-derives that evaluation from the state it was handed rather than
reading it from anywhere. Nothing stores it.

The consequence is structural rather than a convention someone has to remember: a
walk that jumps into the middle of a recording cannot trust that recording's
first stage, because the value it would need lives in the row below.

`step_record` inherits `instruction` rather than repeating its three fields. As
separate structs differing by one member, pairing a time out of one container
with a state out of another was a thing that compiled (`ode_interface.hpp:202`).

## What happens where the state vector grows

plant introduces cohorts on a schedule fixed before the run, and each
introduction lengthens the state vector by that cohort's entries. Because the
schedule is fixed rather than triggered by the state, the time at which an
introduction happens carries no derivative — which is what makes the widening a
linear map that can be transposed instead of a discontinuity that cannot.

Going forwards the vector only grows, so going backwards the sweep only narrows.
The obvious implementation of that narrowing is to drop lambda's extra entries.
That is not what happens. The System's own widening map is recorded and swept
like any other function (`ode_solver.hpp:376-386`):

```cpp
  // forward:  y_wide = apply_insertion(time, y_narrow)
  state_and_parameter_adjoints(widened, rec[at-1].state,
                               lambda,             // in:  adjoint at wide width
                               insert,             //      the map, as a lambda
                               narrowed,           // out: adjoint at narrow width
                               parameter_adjoint); //      accumulated here too
  lambda = std::move(narrowed);
```

Two things follow from treating the widening as an ordinary function. The map
runs at an active scalar with `parameter_adjoint` passed into it, so **a
newborn's initial conditions contribute parameter derivatives** — the steps are
not the only source of them, and a design that dropped entries would have lost
that channel silently. And the `active_system` built for the map is local and
dies with it, because applying the map is what widens the System: a recording
made at the narrow width cannot be swept at the wide one.

A caller can also request cuts at rows of its own choosing, for a partial sweep.
Cuts and introductions leave the descent in different places and the loop
distinguishes them. A cut is a row the sweep resumes **at**; an introduction is a
row it carries the adjoint **across**, so it resumes one row below, on the state
the map ran on (`:344-347`). A row that is both is treated as the introduction,
which keeps a cut free of a map.

Peak tape is one step's arithmetic at any run length. One tape is constructed for
the whole descent (`:335`) and cleared between recordings (`adjoint.hpp:324`), so
what accumulates across a descent is the trajectory in `step_record`s — cheap,
linear in steps — and never the arithmetic.

## Attaching a derivative computed somewhere else

Inside a stage, `ode_rates` may reach a quantity a solve found by iteration.
Recording the iterations would differentiate the solver: the answer becomes the
sensitivity of wherever that particular sequence of iterations stopped, which
depends on the starting guess and the tolerance. `record_with_derivatives(value,
rows, into)` (`implicit_node.hpp:71`) puts the number on the tape carrying rows
it was handed instead:

```
    out = value + Σ dᵢ · (xᵢ − to_passive(xᵢ))
                        └───────┬───────┘
                        exactly zero in value
```

`to_passive` strips every AD layer from a scalar, so each bracket is numerically
zero and the forward value is `value` alone, unchanged. The derivative is
whatever `dᵢ` says it is.

The whole sum is one statement. Written the obvious way, `out += d * (x -
to_passive(x))` in a loop over rows, it is `n` recorded assignments, and that is
exactly how a submodel's entire arithmetic ends up on its consumer's tape one
row at a time.

The size of that difference is worth putting a number on, because it decides the
design. Counted in statements walked — recording and sweeping cost the same
traversal — with `T` submodel statements, `k` seeds and `m` outputs:

| | walks per solve | at T=360, k=3, m=6 |
|---|---|---|
| recorded inline on the consumer's tape | `T + kT` | 1440 |
| preaccumulated by an inner tape | `T + mT + m + km` | 2544 |
| supplied, nothing recorded | `m + km` | 24 |

Preaccumulation is the middle option: record the submodel on a tape of its own,
sweep it `m` times to extract a dense derivative block, discard it. It loses here
because it spends six inner sweeps to save three outer ones, which is the general
rule — an inner tape pays only when the submodel has fewer outputs than the
consumer has seeds, and phylloptim's leaf has double.

Rows are checked for finiteness before any of them is recorded, and the report is
`[[nodiscard]]`. All-or-nothing is deliberate: a value carrying some of its rows
is a channel that has gone missing with every number still finite, which is worse
than carrying none. A consumer told the rows are absent can carry the value as a
constant and say so.

`implicit_value(y*, dFdy, F)` (`:165`) specialises the mechanism to a scalar
root. Given the root of `F(y, p) = 0` and the residual's slope in the unknown, it
records the residual to obtain its slopes in the parameters and yields
`dy*/dp = −(∂F/∂p)/(∂F/∂y)`.

## The two scalars, and why they are separate headers

`tangent_scalar<T>` carries a directional derivative forwards and touches no
tape. It lives in `tangent.hpp`, away from the reverse-mode machinery in
`adjoint.hpp`, so a consumer that wants only a directional derivative is never
handed a name for a tape it has no use for.

Nesting the two is a compile error (`tangent.hpp:36`). At an active inner scalar,
every operand copy inside an expression template becomes a recorded statement,
and because expression templates nest, the growth is superlinear in expression
depth. Three kernels costing 31 statements written flat cost 566 nested — 18
times as much for the same arithmetic. Refusing it at compile time rather than
documenting it is the difference between a build error and a run that is merely
slow for reasons nobody can see.

`with_slope<T>` pairs a value with its slope in one type. The alternative is two
arguments, and a consumer handed two arguments can pair a value and a slope taken
at different points, in different orders, or with respect to different
independent variables — and all three of those compile. It is also a shape
`visit_active` can open, which matters because `visit_active` dispatches on
`for_each_active`, then container, then pointer, and then **does nothing at all**
for an aggregate matching none of them (`ode_interface.hpp:66`). A bare pair of
scalars is exactly such an aggregate: it would contribute no rows, silently, with
every number still finite.

It cannot refuse the shape instead, and the header says why: from inside the
visitor, a class holding active values and a class holding none look the same,
and callers legitimately hand over both — FF16 and K93 hold `double` only and are
walked past on purpose. What reports a miss is `active_system::release`, which
counts the slots the walk never reached.

## Interpolation

`hermite_interpolator` absorbs the deleted spline. It is local cubic Hermite, C1
continuous, extending linearly past the end knots; the old one was a global
natural cubic, C2, extending quadratically. Knots are hit exactly and everything
between and beyond them differs. A caller supplying only values still gets an
interpolant, with Fritsch–Carlson limited slopes derived from the values.

Local for two reasons. A global fit spreads a local defect across the whole
curve: on the curve this library tabulates, the global solve converged at `h²`
where the same knots read as a Hermite converged at `h³·⁷`. And a global solve
makes every knot influence every span, which turns an adjoint that touches one
span into one that touches all of them — O(1) becomes O(K). Nothing in the family
read a second derivative, so C2 was buying nothing.
