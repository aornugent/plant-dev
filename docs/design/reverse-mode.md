# Reverse-mode gradients through a stand of plants

## What this computes

One quantity, and everything else in the three packages is either a way of asking
for it once or a way of checking the answer independently.

The `plant` package integrates a stand of plant cohorts forward through time. A
**cohort** is a group of individuals that were born at the same moment and are
therefore the same size, and the model carries a density for each one rather than
tracking individuals. At the end of a run the model reduces the stand to a handful
of scalars called **census metrics** — total leaf area, above-ground mass, and the
like — each of which is an integral of some per-plant quantity over the size
distribution. A **trait** is one of the parameters of the strategy the plants
follow, such as leaf mass per unit area.

The product is the derivative of every census metric with respect to every trait,
taken over the whole trajectory and computed exactly rather than by differencing.
In `plant` it is `SCM::census_trait_gradient`; in R it is `stand_gradient()`.

Exactly matters because the intended consumer is a parameter-fitting loop. A
finite difference is not merely less accurate here — near a coincidence it does
not converge at all. Refining a step of one part in a million across three
successive refinements produced the sequence −9.63, +166, −10588 against a
feature five hundredths of a micron wide.

## Why the shape is forced

Five properties of the model decide the design. None of them is a preference, and
each rules out the arrangement a reader would otherwise expect.

**The state vector grows during a run.** Cohorts are introduced on a schedule
fixed before the run starts, and each introduction widens the vector of ordinary
differential equation states by one cohort's eight entries. Because the schedule
is fixed rather than triggered by the state, the time at which an introduction
happens carries no derivative — which is what makes the widening a linear map
that can be transposed rather than a discontinuity that cannot.

**One evaluation of the right-hand side is expensive, and it is not a closed form
of the state.** Computing the rates for a stand runs the `phylloptim` leaf model
once per cohort, and that model finds a leaf's operating point by root-finding.
So a later pass cannot re-derive the rates from the state alone; it has to replay
the branch the root-find took.

**The root-find's derivative is supplied rather than recorded.** Recording an
iterative solver differentiates the solver's iterations, not the model it is
solving. The derivative comes from the implicit function theorem applied at the
converged point instead, which is the subject of
[`leaf-derivatives.md`](leaf-derivatives.md).

**Reverse mode over a trajectory needs the state at every accepted step.**
Reverse-mode automatic differentiation records a computation onto a **tape** — a
linear log of the arithmetic performed — and then walks that log backwards
accumulating derivatives. A whole trajectory is thousands of adaptive steps of six
stages each, which does not fit. The alternative to keeping the whole tape is
**checkpointing**: store the state at intervals and re-record the work between
checkpoints on demand. Here the interval is one step, because there is no cheaper
checkpointing scheme for a right-hand side this costly to evaluate.

**Only plain `double` crosses into R.** The active scalar types that carry
derivatives are created and destroyed inside one call. Nothing in R ever holds
one, so there is exactly one place where each conversion happens.

The first two facts say what a recorded step has to carry. The third says the leaf
model's derivative crosses a package boundary as data. The fourth makes the
recording the central object of the design. The fifth fixes where every conversion
sits.

## One rule underlies all five: replay a decision, lift a value

The five facts above are instances of a single split, and it is worth stating
directly because it decides where every new quantity belongs.

**A value computed away from the tape divides into what moves and what selects.**
What **moves** with the inputs — an argmax, a fixed point, a root — is lifted onto
the tape carrying a derivative obtained by other means. What **selects** — an arm,
a step size, a knot position, a schedule — is piecewise constant in the inputs. It
stays a plain `double`, and the backward pass **replays** it rather than deciding
it again.

The reason is not cost. **A selector's derivative is a sequence of zeros and
jumps, so differentiating through one manufactures a discontinuity the model does
not have.** An argmax that shifts from one grid point to the next as a trait
crosses a threshold has a true derivative of zero either side and no derivative at
the crossing; a step size chosen by an error estimator is not a model quantity at
all. So the backward pass differentiates the model **at a fixed decision, never
the decision**.

Read against the parts: the recorded step sizes, the introduction schedule, the
canopy's knot fractions and the leaf's operating-point kind are all selectors, and
all are replayed. The state at each step, the knot values and slopes, and the
leaf's collar are all movers, and all are lifted. Where a quantity is both, it is
two things — one `double` and one enumerator — rather than one class over both.

## This is a standard pattern, and it has a name

The arrangement above — solve a submodel in plain arithmetic, then hand the outer
tape a value together with a block of derivatives computed by other means — is
the first-class use case of every automatic-differentiation framework surveyed,
not a workaround for one.

In Python it is JAX's `custom_root` and `custom_vjp`, PyTorch's
`autograd.Function`, and the differentiable-optimisation layers built on them. In
C++ it is ADOL-C's `ext_diff_fct`, CoDiPack's `ExternalFunctionHelper`, dco/c++'s
external adjoints and Tapenade's `_D`/`_B` convention. Naumann names two variants:
**preaccumulation**, which obtains the local derivative block by sweeping an inner
tape `min(n, m)` times for `n` inputs and `m` outputs, and the **Symbolic Adjoint**
pattern, which obtains it from the implicit function theorem with no sweeps at
all. dco/c++'s own paper uses a Newton solve inside a larger taped computation as
its worked example and reports it 3.5 times faster on about thirty times less
tape.

**What decides between recording the submodel and supplying its block is a
ratio.** Preaccumulation trades `min(n, m)` inner sweeps against the `T` taped
statements the submodel would otherwise contribute, so the deciding quantity is
`T / min(n, m)`. Here the leaf's solve is 360 statements against 31 trait inputs
and 6 outputs, giving 60 — squarely in the regime every source reports as a large
win for supplying the block.

The unit that makes this concrete is a **statement walked**, since recording a
statement and sweeping it cost the same traversal. With `T` leaf statements, `k`
seeds swept from the stand and `m` leaf outputs:

| how the leaf's derivative is obtained | walks per solved leaf | at `T`=360, `k`=3, `m`=6 |
|---|---|---|
| recorded inline on the stand's tape | `T + kT` | 1440 |
| preaccumulated by an inner tape | `T + mT + m + km` | 2544 |
| supplied analytically, nothing recorded | `m + km` | 24 |

**Preaccumulation loses here because the leaf has more outputs than the stand has
seeds.** It spends six inner sweeps to save three outer ones. That is the whole
criterion: an inner tape pays for itself only where the submodel's output count is
below the outer seed count, and this leaf's is double it.

## The parts

Three packages, and the division between them follows the facts above rather than
any packaging convenience.

**`odelia`** owns the solver and everything that names the automatic-differentiation
library. The tape, the active scalar types, the reverse walk over a recording, and
the primitive that attaches a supplied derivative block to a tape all live here. A
model asked to help reset a tape would be a model carrying `odelia`'s problem.

**`phylloptim`** owns the leaf. It solves for the operating point in plain
arithmetic and returns, alongside the value, the rows of the derivative that the
implicit function theorem gives. It has no tape and reaches for no name of one.

**`plant`** owns the stand, the census, and the orchestration. It seeds the reverse
walk, adds the term the walk cannot produce, and converts to and from `double` at
the R boundary.

## The walk, forwards and back

Names and files are stable; line numbers are not, so none are given.

Forwards, the run being differentiated:

| | where | what happens |
|---|---|---|
| 1 | `SCM::run` | the adaptive pass. It records the states, times and step sizes it accepted, and the widening at each introduction. This is the only pass that chooses step sizes. |
| 2 | `Step::step` | one six-stage Runge–Kutta–Cash–Karp step, which reaches `Patch::compute_rates`, then each `Species`, then each `Node`, then `Individual::compute_rates`, then the strategy's own rate functions. |
| 3 | the strategy's rates | the leaf solve. `phylloptim` root-finds in plain `double`, off the tape. |
| 4 | `record_leaf_outputs` | reads the supplied derivative rows from `phylloptim` and records the solved point at the active scalar. This is the seam between "solved elsewhere" and "differentiable here". |
| 5 | the environment | the canopy's light profile and the soil's water states close the feedback from the stand back onto each plant. |

Backwards, the sweep that produces the gradient:

| | where | what happens |
|---|---|---|
| 1 | `stand_gradient` in R | resolve the metric and trait names asked for, refuse names the model does not carry, and assemble the answer. |
| 2 | `census_trait_gradient_tf24` | names in, an R list out. The only place `double` becomes an active scalar for this product. |
| 3 | `SCM::census_trait_gradient` | the orchestrator. It seeds the walk **with** the direct term, runs it, and assembles the answer. The direct term is the walk's starting value and not something added afterwards: `scm.h:1080` gives the reason, that a term added last is a term that can be left out. Nothing classifies exact zeros -- a parameter with no gradient is refused by name instead, so every column that exists carries a number the sweep computed. Restoring the state vector's width is step 5's, in odelia. |
| 4 | `SCM::census_state_and_trait_rows` | **the seed.** One recording over the states and the traits at the final time yields both the sensitivity of each metric to the final state, which is what the walk is seeded with, and the sensitivity of each metric to the traits it reads directly, which no walk produces. |
| 5 | `Solver::solve_adjoint` | one **range** per state-vector width, highest first, narrowing across each introduction. A range is a run of steps over which the width does not change. |
| 6 | `Step::step_adjoint` | one recording of a whole six-stage step, swept once per metric. Five of the six stage states are held by no record, so they are recomputed from the recorded state the step began at. |
| 7 | `vector_jacobian_product` | the record-once, sweep-many primitive. It re-enters the forward model at the active scalar. |
| 8 | `record_with_derivatives` and `implicit_value` | at step 4 of the forward walk, the leaf's rows are supplied rather than recorded. |

**The load-bearing consequence is that step 7 re-enters the forward model.** Steps
2 through 4 of the forward walk are therefore executed twice, once in plain
`double` and once at the active scalar, so every seam in the forward path is also
a seam in the sweep. A quantity that is cached, or that depends on the order rates
are computed in, will differ between the two passes unless something makes it
agree.

## What this design refuses, each with the measurement that refuses it

These are the alternatives a competent implementer reaches for. Each has been
measured and each loses. **Do not re-propose one without a measurement that
contradicts the figure given.**

| refused | why |
|---|---|
| **a tangent above the adjoint** — carrying a forward direction on top of a reverse tape, to get second derivatives cheaply | three kernels cost 31 tape statements at the working scalar and 566 nested, 18.3 times as much. The cost is superlinear in expression depth, so fusing a nested expression makes it worse rather than better: one fused nest measured 160 statements against 99 for the same arithmetic written flat. |
| **several metrics in one walk** — widening the derivative type so one traversal serves all three | between 1.15 times slower and 0.97 times faster, decided only by whether the derivative array still fits in cache at three times the size. The traversal is shared but the scatter into the array is three times the bytes, and the two cancel. |
| **a dense derivative block for all six leaf outputs** | six sweeps against three walks: 39 microseconds against 34. |
| **moving the tape rather than shrinking it** | recording costs sixteen times what sweeping costs, so where the tape lives argues about a sixteenth of the total. |
| **a private tape per solved leaf** | not blocked, but not affordable: constructing a tape reserves 192 MiB. A private tape has to be a member held for a whole run, and reusing one costs 0.14 microseconds a cycle — the cycle was never the expense. |
| **a finite difference as the referee near a coincidence** | a step of one part in a million straddles a feature 5.6 hundred-millionths wide; refined across three steps it read −9.63, +166, −10588 and never converged. |
| **two analytic routes agreeing, as evidence of correctness** | they shared a corrupted input and agreed on the wrong answer. Agreement is evidence only between routes that share no code. |

## Traps that mislead silently

Each of these produces a plausible number rather than an error, which is why they
are written down.

**A refusal is metric-level, so one bad leaf reaches everything.** A single
operating point with no derivative makes all three metrics not-a-number across
every trait column. [`refusal.md`](refusal.md) says why that is the right scope and
what a caller sees.

**`identical(NaN, NaN)` is TRUE in R.** Every bit-identity check on the century
fixture's gradient passed for as long as the fixture existed, against a gradient
that was entirely not-a-number. Count the finite entries and assert the count
before comparing values.

**`make` does not track headers under `inst/include`.** A test binary reported
up to date after a change to an `odelia` header is the previous binary. Delete it
rather than trusting the timestamp.

**A wall-clock delta below about three per cent is not evidence.** A same-source,
byte-identical comparison on the century fixture reproduced a two per cent gap
between two installed copies of the same tree. Verify a performance claim by a
counted quantity — tape statements, solved leaves, row counts, rate evaluations —
and treat a timing as a sanity check on the count.

**The high-water mark of slot allocation costs more than the live count.** The
library zero-fills the whole derivative array once per seed, and sizes it by the
highest slot number ever issued rather than by how many are currently in use. So a
recording's slot count costs something beyond its statement count.

## Checking the answer

The claim "this is the exact transpose of the forward run" cannot be checked by
finite differences, because differencing is the thing being replaced. It is
checked instead by references that share no code with the object under test:

- a **forward-mode tangent** of the same forward source, which is exact — no step
  size, no truncation — and traverses the forward reductions while touching none
  of the transposes under test. One seed gives one exact column of the Jacobian.
- the **whole Jacobian formed entry by entry** at one cohort, where the object is
  small enough to fit. A contraction against a seed returns one number, hides an
  error behind a small component, and localises to nothing when it fails.
- a **difference of the plain-`double` path**, which re-solves rather than
  replaying, and so carries the true derivative with none of the factorisation
  under test inside it.
- **injected corruptions**, which establish that the checks above would notice.
  A suite that records how much margin each check had says nothing about whether
  the check would have fired.

The tests carrying these live in `plant/tests/testthat/test-gradient-*.R` with
their shared fixtures in `helper-gradient-ladder.R`.
