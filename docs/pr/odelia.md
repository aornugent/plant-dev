# odelia

**Base** `traitecoevo/odelia:master` · **Head** `aornugent/odelia:ad/V4-reverse-tf24`
**Tag on merge** `v0.5.0` · **Blocks** phylloptim, then plant

## Title

Differentiate a recorded run in reverse mode

## Body

Calibrating a model against data means asking how its solution moves
when a parameter moves, and forward-mode differentiation answers that
for one parameter per solve. Reverse mode answers it for all of them at
once, but it must first record every arithmetic operation the solve
performed, and a run of several thousand adaptive steps performs far
more of them than memory will hold.

The solver now stores its state at each accepted step and replays the
arithmetic of one step at a time while the derivative is taken, so the
record never grows past a single step and one solve yields the
derivative with respect to every parameter. A value a submodel solved
for rather than computed is lifted onto the record carrying a
derivative obtained by other means, which keeps an iterative solver's
own iterations out of the answer. The spline becomes an interpolator
that reads a slope alongside each knot value, so a caller holding
slopes gets a cubic Hermite rather than a fit through the values alone.
`spline.hpp` and `ode_fit.hpp` are removed.

Closes #

## First comment

### The rule the whole design follows

A value computed away from the tape divides into what moves and what selects.

What **moves** with the inputs — an argmax, a fixed point, a root — is lifted
onto the tape carrying a derivative obtained by other means. What **selects** —
an arm, a step size, a knot position, a schedule — is piecewise constant in the
inputs, stays a plain `double`, and the backward pass replays it rather than
deciding it again.

The reason is not cost. A selector's derivative is a sequence of zeros and
jumps, so differentiating through one manufactures a discontinuity the model
does not have. An argmax that shifts from one grid point to the next as a
parameter crosses a threshold has a true derivative of zero either side and
none at the crossing. So the backward pass differentiates the model at a fixed
decision, never the decision.

Everything else follows. The recorded step sizes and the knot positions are
selectors and are replayed; the state at each step, the knot values and their
slopes are movers and are lifted. Where a quantity is both, it becomes two
things — one `double` and one enumerator — rather than one type spanning both.

### This is a named pattern, not an invention

Solving a submodel in plain arithmetic and handing the outer tape a value
together with a block of derivatives obtained by other means is the first-class
use case of every automatic-differentiation framework we surveyed. In Python it
is JAX's `custom_root` and `custom_vjp` and PyTorch's `autograd.Function`; in
C++ it is ADOL-C's `ext_diff_fct`, CoDiPack's `ExternalFunctionHelper`,
dco/c++'s external adjoints and Tapenade's `_D`/`_B` convention.

Naumann names two variants. **Preaccumulation** obtains the derivative block by
sweeping an inner tape `min(n, m)` times for `n` inputs and `m` outputs. The
**Symbolic Adjoint** pattern obtains it from the implicit function theorem with
no sweeps at all. This is the second.

What decides between them is a ratio: `T / min(n, m)`, where `T` is the taped
statements the submodel would otherwise contribute. For the consumer that drove
this work the leaf's solve is 360 statements against 6 outputs, giving 60 —
the regime every source reports as a large win for supplying the block.

Counted in statements walked, since recording and sweeping cost the same
traversal, with `T` submodel statements, `k` seeds swept and `m` outputs:

| how the submodel's derivative is obtained | walks per solve | at T=360, k=3, m=6 |
|---|---|---|
| recorded inline on the consumer's tape | `T + kT` | 1440 |
| preaccumulated by an inner tape | `T + mT + m + km` | 2544 |
| supplied, nothing recorded | `m + km` | 24 |

Preaccumulation loses here because the submodel has more outputs than the
consumer has seeds: it spends six inner sweeps to save three outer ones.

### Why memory is bounded by one step and not by the run

Reverse-mode differentiation walks backwards through a record of the forward
calculation, so the record must exist before the derivative can be taken. A run
here is thousands of adaptive steps of six stages each — far more arithmetic
than can be held at once.

Storing the state at every accepted step and re-recording one step's arithmetic
at a time bounds what is held by a single step. Memory then grows with the
number of steps, which is cheap, rather than with the arithmetic, which is not.
The interval is one step because there is no cheaper checkpointing scheme for a
right-hand side this costly to evaluate.

### Why the forward and reverse scalars are separate headers

A consumer may want a directional derivative and no record at all, so the
forward-mode scalar lives in `tangent.hpp`, apart from the reverse-mode
machinery in `adjoint.hpp`, and such a consumer is never handed vocabulary for
a record it has no use for.

`tangent.hpp` also carries the one combination that is easy to reach for and
expensive to diagnose. A forward-mode scalar nested above a reverse-mode one
turns every copy of an operand into a recorded operation, and the cost grows
faster than the size of the expression: three kernels costing 31 statements
flat cost 566 nested. The header rejects that combination at compile time
rather than letting it run slowly.

### The interpolator

Local cubic Hermite rather than a global C2 solve. On the curve this library
tabulates, the global fit converged at `h^2` against `h^3.7` for the same knots
read as a Hermite — a global solve spreads a local defect — and it makes every
knot influence every span, which turns an O(1) adjoint into an O(K) one.
Nothing read a second derivative.

Values move. The old spline was global natural cubic, C2, with quadratic
extrapolation; the new one is local Hermite, C1, with linear end extension.
Knots are hit exactly and everything between and beyond differs. A caller with
only values gets Fritsch-Carlson limited slopes.

### Migration

Nothing in `phylloptim` or `plant` included `spline.hpp` or `ode_fit.hpp`, so
the migration burden across the family is zero. For an outside consumer:
`basic_spline::set_points/operator()/deriv` becomes
`hermite_interpolator::init(x, y, m)` with `eval` and `slope`, supplying slopes
or deriving them with `monotone_slopes(x, y)`. `compute_gradient` has no
drop-in; `vector_jacobian_product` plus `sweep.hpp` replace it, with the loss
and the optimiser loop becoming the caller's.

### Probes

Seven standalone programs under `tests/standalone/`, each a single translation
unit needing no R. Reading the automatic-differentiation library's source did
not settle what its operation and slot counters count across nested recordings,
and a probe settles such a question in about twenty lines.
