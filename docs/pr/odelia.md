# odelia

**Base** `traitecoevo/odelia:master` · **Head** `aornugent/odelia:ad/V4-reverse-tf24`
**Tag on merge** `v0.5.0` · **Blocks** phylloptim, then plant

Four comments, posted in order.

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

# Comment 1 — Orientation

## Terms

Specific to reverse mode, and used throughout the diff.

- **tape** — a linear log of arithmetic, appended as a calculation runs, walked backwards for derivatives.
- **statement** — one tape entry: a single left-hand side over a run of operations. Tape cost is statements, not operations. `a = b*c + d*e` is one; two assignments are two.
- **recording** — what sits on the tape between clears. Here, exactly one solver step.
- **seed** — the starting derivative for a backward walk. One per output.
- **row** — one output's derivatives against a list of inputs. `adjoint_rows` is a batch.
- **sweep** — one backward walk of a recording from one seed.
- **range** — consecutive recorded steps at constant state width. A System that grows mid-run has several.

## The call

```cpp
  solver.set_keep_states(true);
  solver.advance_adaptive(times);            // one step_record per accepted step
  solver.solve_adjoint(lambda,               // seeded at the final width; replaced
                       parameter_adjoint);   // one row per seed; accumulates
```

`advance_adaptive` is the existing adaptive loop, unchanged. `solve_adjoint`
walks the records in reverse, re-running each step's six stages at an active
scalar, sweeping once per seed, clearing the tape between steps.

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

3,378 steps and 20,268 rate evaluations on plant's century fixture — six per
step, because every step is re-run whole.

## Files

| header | lines | holds |
|---|---|---|
| `adjoint.hpp` | 507 | `adjoint_rows`, `active_system`, `vector_jacobian_product`, `state_and_parameter_adjoints` |
| `implicit_node.hpp` | 397 | `record_with_derivatives`, `implicit_value`, `preaccumulate` |
| `sweep.hpp` | 94 | `state_at_range`, `program_from`; plant's `scm.h` consumes both |
| `tangent.hpp` | 75 | `tangent_scalar`, `seed_direction`, `derivative_along` |
| `with_slope.hpp` | 44 | `with_slope<T>` |

Rewritten: `interpolator.hpp` (+640, absorbs the spline), `ode_interface.hpp`
(+496, the System contract becomes concepts), `ode_solver.hpp` (+392),
`solver_interface.hpp` (−293 net, the passive/active pair collapses to one).
Deleted: `spline.hpp`, `ode_fit.hpp`; neither was included by phylloptim or plant.

Read `tangent.hpp` and `with_slope.hpp` first, then `ode_interface.hpp:196-222`,
`ode_solver_internal.hpp:269`, `adjoint.hpp:304`, `ode_solver.hpp:336`.
`implicit_node.hpp` is independent of the solver.

---

# Comment 2 — Mechanism

## The record

```
    step_record<System> : instruction
    ├── time        double         when this step started
    ├── step_size   double         h, as accepted
    ├── insertion   bool           did the state vector grow here
    ├── state[]     state_type     the full state the step began FROM
    └── solved[5]   solved_values  what five of the six stages solved for
```

Memory is `n_steps × (n_state + 5 × sizeof(solved))`. Stage rates and four of
the five intermediate stage states go unstored: recomputing costs six model
evaluations per step, holding costs the trajectory.

`solved[5]` covers the one thing neither cheap to recompute nor derivable from
the state — a root-find's output inside a stage, which for plant is a leaf's
operating point.

Five, not six: the sixth rate evaluation is at the state the step ends at, and
first-same-as-last hands it to the next step as its own first rates. A sweep
re-derives it. So a walk cannot trust the first stage of a recording it jumped
into, and that is the layout rather than a convention.

`step_record` inherits `instruction`. As separate structs differing by one
member, pairing a time from one container with a state from another compiled
(`ode_interface.hpp:202`).

## Narrowing across an introduction

Not a projection — lambda's extra entries are not dropped. The System's widening
map is recorded and swept like any other function (`ode_solver.hpp:376-386`):

```cpp
  // forward:  y_wide = apply_insertion(time, y_narrow)
  state_and_parameter_adjoints(widened, rec[at-1].state,
                               lambda,             // in:  adjoint at wide width
                               insert,             //      the map, as a lambda
                               narrowed,           // out: adjoint at narrow width
                               parameter_adjoint); //      accumulated here too
  lambda = std::move(narrowed);
```

Two consequences. `parameter_adjoint` is passed in, so a newborn's initial
conditions contribute parameter derivatives, not only the steps. And the
`active_system` is local and dies with it: applying the map is what widens the
System, so a recording made at the narrow width cannot be swept at the wide one.

Caller-requested cuts resume **at** a row; introductions carry the adjoint
**across** one, resuming below it on the state the map ran on (`:344-347`).

Peak tape is one step at any run length: one tape for the descent (`:335`),
cleared between recordings (`adjoint.hpp:324`).

## Attaching a derivative computed elsewhere

`record_with_derivatives(value, rows, into)` (`implicit_node.hpp:71`):

```
    out = value + Σ dᵢ · (xᵢ − to_passive(xᵢ))
                        └───────┬───────┘
                        exactly zero in value
```

`to_passive` strips every AD layer, so the forward value is `value` alone and the
derivative is whatever `dᵢ` says. One statement whatever the row count. The
obvious loop, `out += d * (x - to_passive(x))`, is `n` recorded assignments —
which is how a submodel's whole arithmetic reaches its consumer's tape.

`implicit_value(y*, dFdy, F)` (`:165`) specialises it to a scalar root: given
`F(y*, p) = 0` and `∂F/∂y`, it records the residual for `∂F/∂p` and yields
`dy*/dp = −(∂F/∂p)/(∂F/∂y)`.

## Interpolation

`hermite_interpolator` is local cubic Hermite, C1, linear past the end knots.
The old spline was global natural cubic, C2, quadratic past the end. Knots hit
exactly; everything between and beyond moves. Values-only callers get
Fritsch–Carlson limited slopes.

Local because a global fit spreads a local defect — `h²` convergence against
`h³·⁷` for the same knots read as a Hermite — and because every knot influencing
every span turns an O(1) adjoint into an O(K) one.

---

# Comment 3 — Contract and failure modes

## What `solve_adjoint` requires

Checked at run time (`adjoint.hpp:387-400`):

- `set_keep_states(true)` before the run.
- `parameter_adjoint` at one row per seed, width = parameter count, **zeroed by the caller**; it accumulates with `+=`.
- `lambda` seeded at the final state width.
- state and parameter adjoints as different batches — one is replaced, one accumulated, so aliasing is refused.

## Silent failure modes

**`visit_active` skips what it cannot open** (`ode_interface.hpp:66`). It tries
`for_each_active`, then container, then pointer, then does nothing. A shape
carrying rows and missing the member contributes none, with every number finite.
This is why `with_slope` is a type and not two arguments.

**A tangent above an adjoint is a compile error** (`tangent.hpp:36`). Each
operand copy inside an expression template becomes a statement at an active inner
scalar; growth is superlinear in depth. Three kernels: 31 statements flat, 566
nested.

## Claims to test

| claim | where |
|---|---|
| Peak tape is one step at any run length | `adjoint.hpp:324`, `:417`; `ode_solver.hpp:335` |
| A segmented sweep equals a whole one bit for bit | the two overloads, `:287` and `:397` |
| A recording cannot end at an introduction | `:309` — carried across, so nothing below to resume on |
| Width restored on every exit including a throw | `restore_on_exit`, `:318-330` |
| One statement per attachment | asserted, `tests/standalone/r_free.cpp:507` |
| Every row checked before any is recorded | `implicit_node.hpp:79` |

The last is all-or-nothing by design. A value carrying some of its rows is a
channel gone missing with every number still finite; told the rows are absent, a
consumer can carry the value as a constant and say so. Hence `[[nodiscard]]`.

## Migration

A System entering a sweep adds `rebind_from`, `ad_parameters`, `for_each_active`
and `set_recorded_state`; one that grows adds `apply_insertion`.

`rebind()` → `rebind_from()`, target scalar named and not defaulted: *"defaulting
it to the System's own scalar asks whether a System can rebind to the scalar it
already has, which is a different question"* (`ode_interface.hpp:109`).

`needs_time` / `has_cache` / `has_state_check` become the concepts `HasOdeTime`,
`SolvesForValues`, `ChecksState`, `Rebindable` (`:101-263`).

R loses `Solver_fit()`, `Solver_set_target()`, and `active` on all fifteen
`Solver_*` bindings. `compute_gradient` has no drop-in;
`vector_jacobian_product` plus `sweep.hpp` replace it, with the loss and
optimiser loop becoming the caller's.

---

# Comment 4 — Cost

Supplying a submodel's derivative block instead of recording it is the
first-class case in JAX (`custom_root`, `custom_vjp`), ADOL-C (`ext_diff_fct`),
CoDiPack (`ExternalFunctionHelper`), dco/c++ and Tapenade. Naumann names two
variants: preaccumulation sweeps an inner tape `min(n, m)` times; the Symbolic
Adjoint pattern uses the implicit function theorem and sweeps nothing. This is
the second.

Statements walked per solve, with `T` submodel statements, `k` seeds, `m` outputs:

| | walks | at T=360, k=3, m=6 |
|---|---|---|
| recorded inline | `T + kT` | 1440 |
| preaccumulated | `T + mT + m + km` | 2544 |
| supplied | `m + km` | 24 |

Preaccumulation loses when the submodel has more outputs than the consumer has
seeds. phylloptim's leaf has double.

Measured and rejected:

| | |
|---|---|
| a forward direction on top of a reverse tape | 31 statements flat, 566 nested |
| one traversal serving several outputs | 1.15× slower to 0.97× faster; scatter cancels the shared traversal |
| a dense block for all six leaf outputs | six sweeps at 39 µs against three walks at 34 |
| moving the tape instead of shrinking it | recording costs 16× sweeping |
| a private tape per solved submodel | constructing one reserves 192 MiB |

Seven probes under `tests/standalone/`, one translation unit each, no R. Reading
the AD library's source did not settle what its statement and slot counters count
across nested recordings.
