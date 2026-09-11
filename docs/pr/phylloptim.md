# phylloptim

**Base** `traitecoevo/phylloptim:master` · **Head** `aornugent/phylloptim:ad/V4-reverse-tf24`
**Tag on merge** `v0.9.0` · **Needs** odelia `v0.5.0` tagged first

## Title

Supply exact derivative rows for the leaf solve

## Body

The leaf picks its operating point by searching for the root-collar
water potential that maximises photosynthetic gain net of hydraulic
risk. A package differentiating through this model had to record that
search and differentiate the recording, which differentiates the solver
rather than the model: what comes back is the sensitivity of wherever
this particular sequence of iterations happened to stop, and it depends
on the starting guess and the convergence tolerance.

The leaf now supplies the derivative of its operating point directly,
from the implicit function theorem applied at the converged point, so
the answer is exact there and its only error is the residual's own
distance from zero. Where no such derivative exists — the leaf has shut
down, the optimum sits on a bound, or the curvature there is too near
zero to invert — the leaf returns a refusal naming which, in place of a
number that would look plausible and be wrong. The model is templated
on its scalar type, so one body of source serves a plain solve, a
forward derivative and a reverse recording.

Closes #

## First comment

### What replaces the recording

If the operating point `p*` is defined by a residual `F(p*, θ) = 0` for traits
`θ`, differentiating that identity gives

```
dp*/dθ  =  −(∂F/∂p)⁻¹ ∂F/∂θ
```

evaluated at the converged point. Both partials are of the residual, which is a
closed form, so both are available without recording anything the solver did.
Measured on this model, the error attributable to the solve's tolerance is 1.6
parts in a thousand million million.

The cost argument points the same way. The leaf's solve is about 360 tape
statements; recorded inline it contributes those once for the recording and
once per seed swept, which at three seeds is 1440 statement-walks per solved
leaf. Supplying the derivative costs 24.

### One formula, four residuals

The operating point's kind selects which residual, not which formula. The
uniform statement is Fiacco's and needs no branch:

```
dΠ*/du  =  ∂Π̂/∂u |_p  −  Σⱼ μⱼ ∂cⱼ/∂u |_p
```

At an interior optimum every multiplier is zero and this collapses to the
envelope theorem. At a bound the multiplier is exactly the correction the
envelope theorem does not give. Four residuals cover the model: interior
stationarity, the wet bound's uptake balance, the dry stem's continuity root at
its critical potential, and the root's own critical potential.

### Classification comes from the exit, never from the numbers

The marginal profit returns an exact `0.0` on the shut-down and
reversed-gradient exits, and a bare zero is indistinguishable from a stationary
point. A stationarity test formed as the residual over the curvature reads the
sentinel as stationary, and the curvature taken off the same sentinel agrees —
so both diagnostics confirm each other and both are wrong.

The kind is therefore written by the branch the solve exited through, and is
reset to unclassified when a solve begins, so a forgotten branch reports
"unclassified" rather than the previous plant's answer.

### Why a difference cannot referee a supplied row

A finite difference of the calculation that consumes a supplied derivative
cannot check that derivative. The recorded expression is the value plus a sum
of partials multiplied by brackets that are each exactly zero, so the block's
forward value does not depend on a recorded input at all: differencing returns
identically zero on precisely the entries a supplied row occupies — whether the
row is right, wrong, or absent.

The rows are therefore checked against the model rebuilt from its parameters,
which re-runs preparation and traverses the forward solve rather than
short-circuiting it. That route reaches what a difference cannot.

### Why the two vulnerability curves share one implementation

Both curves are read from a pre-integrated table and differentiated from the
closed form. The split is deliberate: the value comes from the table because
the solve itself ran on the table, while the table's own slope is a property of
the fit rather than of the curve, and the two differ.

They share one implementation because writing the derivative twice invites a
specific failure. One copy picks up the chain rule through the shape parameter
and the other keeps a partial at fixed scale. The result is finite, plausible,
and wrong, and nothing in the output says so.

### What is deliberately not built

A fully analytic block, supplying every row with nothing recorded anywhere, is
available in principle and is not built. Three reasons, each one a future
attempt would hit again.

It needs eight closed forms that do not exist — four mixed second partials of
the assimilation kernel and four of the cost — while the supply side's 187
statements stay recorded either way, so the walk count falls from 1440 to about
772 rather than to 24. Most of the prize is already taken.

The referee does not cover it. The transpose identity reaches four operating-
point kinds, and a forward-mode tangent cannot help: it runs the same supplied
numbers through the same attachment, so a wrong row makes both routes wrong
identically. Coverage rather than algebra is the binding constraint.

### Multi-layer and single-potential roots

`roots` is the network: each soil layer has its own conductance and its own
share of uptake, coupled only through the shared collar potential, so the
collar's response is a plain sum of per-layer terms. `single_potential`
implements the same methods against one soil water potential, because every
model this one is compared against is formulated that way and comparing them
under a multi-layer network compares two things at once.

### The C++ suite builds without R

`tests/cpp/` compiles on a runner with no R installed. That is the only thing
that can demonstrate `inst/include/` is usable without R: a job with R present
compiles the same headers happily and cannot tell the difference.
