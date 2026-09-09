# The leaf's derivative, and why it is supplied rather than recorded

## What the leaf model does

`phylloptim` answers one question about one leaf: given the light reaching it and
the water potentials of the soil layers its roots occupy, at what stem water
potential does the leaf operate?

The answer is a trade-off. Opening stomata wider admits more carbon dioxide and so
assimilates more carbon, but it also draws more water through the stem, and the
stem's conductivity falls as its water potential drops. The leaf is taken to sit
where the marginal carbon gain equals the marginal water cost. Finding that point
means solving for a root of the marginal-profit function, and `phylloptim` does so
iteratively, in plain `double`.

`plant` calls this once per cohort inside every stage of every Runge–Kutta step.

## Why recording the solve would be wrong

The obvious way to differentiate through an iterative solve is to record it: put
the trait on the tape, run the root-find with the tape active, and let the reverse
walk carry a derivative back through every iteration.

**That differentiates the solver rather than the model.** The recorded derivative
is the sensitivity of "wherever this particular sequence of iterations happened to
stop" to the trait, which depends on the starting guess, the convergence tolerance
and the iteration count. It converges to the right answer as the tolerance
tightens, but it is not the right answer at any finite tolerance, and its error is
a property of the solver's settings rather than of the model.

There is also a cost argument, and it points the same way. The leaf's solve is
about 360 tape statements. Recorded inline it contributes those statements to the
stand's tape once for the recording and once per seed swept, which at three seeds
is 1440 statement-walks per solved leaf. Supplying the derivative instead costs 24.
[`reverse-mode.md`](reverse-mode.md) gives the full comparison, including the
middle option of an inner tape, which loses here because the leaf has more outputs
than the stand has seeds.

## What replaces it

The implicit function theorem. If the operating point `p*` is defined by a
residual `F(p*, θ) = 0` for traits `θ`, then differentiating that identity gives

```
dp*/dθ  =  −(∂F/∂p)⁻¹ ∂F/∂θ
```

evaluated at the converged point. Both partial derivatives are of the residual,
which is a closed form, so both are available without recording anything the
solver did. **The derivative is then exact at the converged point, and its only
error is the residual's own distance from zero.** Measured on this model, the term
attributable to the solve's tolerance is 1.6 parts in a thousand million million
of the answer.

`odelia` provides the attachment as a primitive rather than leaving it to each
model. `record_with_derivatives(value, rows, into)` puts a number on the caller's
tape carrying rows it was handed, and `implicit_value` is the theorem itself for a
scalar root: it supplies the residual's slope in the unknown and records the
residual to obtain its slope in the parameters.

⚠️ **The attachment records one tape statement whatever the row count, and that is
not incidental.** A tape statement is one left-hand side over a run of operations,
so `n` rows are `n` operations under one statement. Writing the same sum out as
`out += d * (x - to_passive(x))` costs `n` recorded assignments instead, which is
how a submodel's whole arithmetic ends up on a consumer's tape.

⚠️ **Every row is checked before any is recorded.** A value carrying some of its
rows is a channel that has gone missing with every number still finite, which is
worse than no rows at all: a consumer told the rows are absent can carry the value
as a constant and say so.

## What the theorem needs, and what it cannot have

The theorem applies where the residual is differentiable and its slope in the
unknown is invertible. Both conditions fail at identifiable points, and the design
turns each failure into a refusal rather than a number.

**The slope in the unknown must not be zero, and must not be too small.** The
slope is the curvature of the profit function at its optimum. Where the profit
curve is nearly flat the inverse is nearly unbounded, and a row computed from it is
a large number with no information in it. A floor on the curvature refuses such a
point. The floor moves no forward number at all and still decides which rows
exist, which is why it is one of the settings a gradient records alongside its
answer.

**The point must be an interior optimum, or the residual must be the one that
actually pins it.** A leaf whose optimum would lie outside the feasible range of
stem potentials sits on a bound instead, and there the condition defining the point
is not stationarity of profit but the bound itself. `phylloptim` records which
branch the solve exited by, as an `OperatingPointKind`, and the row is formed from
the residual that branch selected.

⚠️ **The classification comes from the exit taken, never from the numbers
returned.** The marginal profit returns an exact `0.0` on the shut-down and
reversed-gradient exits, and a bare zero is indistinguishable from a stationary
point: a stationarity test formed as the residual over the curvature reads it as
stationary, and the curvature taken off the same sentinel agrees.
[`refusal.md`](refusal.md) covers this and the other sentinels.

## One formula, four residuals

The kind selects which residual, not which formula. The uniform statement is
Fiacco's, and it needs no branch:

```
dΠ*/du  =  ∂Π̂/∂u |_p  −  Σⱼ μⱼ ∂cⱼ/∂u |_p
```

At an interior optimum every multiplier `μⱼ` is zero and this collapses to the
envelope theorem — differentiate the objective holding the optimum fixed, which is
the omission the value path already makes. At a bound the multiplier is precisely
the correction the envelope theorem does not give.

Four residuals cover the model: the interior stationarity condition, the wet
bound's uptake balance, the dry stem's continuity root at its critical potential,
and the root's own critical potential. That is what the collar's own accessor
already dispatches on.

**The total profit row is rank one in the transpiration column at every kind, and
this is a theorem rather than a measurement.** The concentration's residual reads
the flux and the photosynthetic traits and nothing else, so the whole carbon side
is a one-dimensional function of total transpiration. Probing the rank measures it
at between 2.7 and 9.9 parts in a thousand million million.

## What is deliberately not built

The design supplies rows for the operating point and records the residual for the
rest. **A fully analytic block, supplying every row with no recording anywhere, is
available in principle and is not built.** Three reasons, in order of weight, and
each is a reason a future attempt would hit again.

**It needs eight closed forms that do not exist.** The interior slope in the traits
wants four mixed second partial derivatives of the assimilation kernel and four of
the cost. Each is refereeable, but each is a new thing a reader must hold, and the
supply side's 187 statements stay recorded either way — so the walk count falls
from 1440 to about 772 rather than to 24. Most of the prize is already taken.

**The referee does not cover it.** The transpose identity reaches four of the
operating-point kinds, and the forward-mode tangent cannot help: it runs the same
supplied numbers through the same attachment, so a wrong row makes both routes
wrong identically. That is the "two analytic routes agreeing" trap in
[`reverse-mode.md`](reverse-mode.md). **Coverage rather than algebra is the binding
constraint.**

**One supplied number is already wrong.** The marginal profit returns its `0.0`
sentinel at the shade-death exit, where the true value is −1.3137. Any design that
takes the interior slope from there inherits that error, so the sentinel has to be
fixed before the block is worth building.

## The one thing that must always hold

**A row `phylloptim` hands over describes the point `plant` is about to record,
and not a neighbouring one.** The leaf is a stateful object: solving moves its
operating point, and several paths out of a solve leave it somewhere other than
where the caller expects.

This is held structurally where it can be. Reading the outputs and the rows happens
in one call, because the function that restores a point also tags it as prescribed,
and a replay dispatching on the kind then has no condition to place a prescribed
point at. Splitting that into two calls is the mistake, and it costs a throw in a
caller that never asked for a collar.

⚠️ **It is held by convention where it cannot be held structurally: every path out
of the solve writes its own rates.** A function that drives the model to a
neighbouring point to difference something has to put the point back before
anything else is read off that leaf.
