# When there is no derivative, and how the answer says so

## The problem this solves

Some points of the model have no derivative at all. A leaf at a hydraulic
shutdown, a cohort that failed to establish, a constrained optimum sitting exactly
on its bound — at each of these the quantity being differentiated is either
undefined or defined by a different formula on each side.

An automatic-differentiation library does not know that. Handed such a point it
will return a number, and the number will be plausible. So the contract has to be
established by the code around it rather than inherited from the library, and it
is this:

> **A number this gradient returns is either one the sweep computed, or it is
> not-a-number accompanied by a declared refusal.**

Both halves matter, and the second is the one that took work. A refusal that
produces not-a-number is easy. Making every not-a-number produce a refusal means
finding every route by which a non-finite value can reach the answer without
anything having declared it, and closing each one.

## Why refusal is metric-level

A census metric is a sum over cohorts. A sum has no defined value when one of its
terms is undefined, so if any cohort's contribution has no derivative then the
metric's derivative does not exist — not "exists but is unreliable", and not
"exists for the other cohorts".

**So a refused metric's whole row is not-a-number, and one reason serves the whole
row.** The alternative a reader expects — refuse the individual trait columns that
are affected and answer the rest — describes a quantity that does not exist. It
would report a partial sum as though it were the sum.

The practical consequence is that refusal is expensive in coverage: a single leaf
with no derivative makes all three metrics not-a-number across every trait column.
That is the correct answer and it is also a strong incentive to make the
inadmissible points rare, which is what most of `phylloptim`'s operating-point
machinery is for.

## What a caller sees

`stand_gradient()` returns a list of four entries. `gradient` is the
metrics-by-traits matrix. `refusal` has one entry per metric, holding the reason
and where it was found, or `NULL` where the metric answered. `value` is the metrics
themselves and `control` is the settings the gradient was taken at.

`stand_gradient_refused(g)` reduces `refusal` to one logical per metric.

⚠️ **A refusal does not always name a location.** The `species` field of a refusal
is one-based where the refusal came from a particular species' strategy, and −1
where what failed was an intermediate of one recording spanning every cohort in
every stage. The reverse walk's own refusal, below, is of the second kind. A
caller reading `species` must handle −1 rather than indexing with it.

⚠️ **A caller can reach `gradient` without reading `refusal`.** Not-a-number
propagates through arithmetic, so most ways of using a refused row give
not-a-number and are safe. The exception is a reduction that drops missing values:
`max(abs(g$gradient), na.rm = TRUE)` silently ignores a refused metric entirely.
Check `refusal` before any reduction that takes `na.rm`.

## The mechanisms, and why there are several

One question — is there a derivative here — is answered in seven ways across the
three packages. That is more than one, and the reason is that they are partitioned
by who has to read them rather than by what they mean.

| package | mechanism | who reads it |
|---|---|---|
| `phylloptim` | the `Status` enumeration, reported to R as a string | a caller asking about one leaf directly |
| `phylloptim` | not-a-number sentinels in a returned row | the row's immediate consumer, which is `plant` |
| `phylloptim` | an exact `0.0` sentinel at a no-flow point | the same, and see the warning below |
| `phylloptim` | a thrown exception | a caller that asked for a point that cannot be formed |
| `odelia` | `record_report`, carrying whether the block was whole and which input failed | the code attaching a supplied block to a tape |
| `odelia` | `AdjointRangeError` from the reverse walk | `plant`'s orchestrator, by type |
| `plant` | `refusal`, holding a reason and a species, recorded on the strategy | R, through `census_trait_gradient` |

⚠️ **An exact `0.0` is indistinguishable from a stationary point, and that is the
one sentinel with no signal of its own.** The marginal profit returns a hard zero
on the shut-down and reversed-gradient exits. A stationarity test formed as the
residual over the curvature reads that as stationary, and the curvature taken off
the same sentinel confirms it. So the classification must come from the branch the
solve took, never from the numbers it returned.

**The incidence of a classification is not recoverable from a refusal.** A refusal
message names the first point that was not interior and says nothing about how
many followed it or what kinds they were, because the classification is
overwritten by the next plant. `TF24_Strategy::solve_leaf` therefore keeps a
tally of operating-point kinds alongside the refusal, and that tally is the only
route to an incidence. It is counted there rather than in `record_leaf_outputs`,
which runs only on the active path: a tally kept there would miss the whole
forward pass, which is where all but one of the placements happen.

## The two routes that had to be closed

Both produced a not-a-number with nothing declared, and both were found by asking
where a non-finite value could enter without passing a check.

**A cohort that fails to establish.** `compute_initial_conditions` sets a
recruit's cumulative mortality to the negative logarithm of its establishment
probability. Where that probability is exactly zero — deep shade — the logarithm
is negative infinity and the hazard is positive infinity. Every reader of the
hazard is guarded, so the forward model is correct and silent; but the recorded
trajectory it hands the reverse walk carries an entry no derivative can attach to.

⚠️ **Never put a non-finite number in an ordinary-differential-equation state.**
`Patch::check_finite_ode_state` examines the cohort density and the environment's
own states, and does not look at the six slots a strategy declares or the node's
two extras — so an infinity in one of those propagates unremarked. An infinite
state entry also buys silence from the step-size controller: the error level is
proportional to the magnitude of the state, so at an infinite state the ratio of
error to allowance is zero and **that component cannot constrain the step however
large its rate**.

The fix is a finite sentinel. `establishment_failure_hazard` is a cumulative
hazard past which survival is exactly zero in double precision, so a cohort held
there is dead with probability one, its rate parked, and its state still a number.
Parking the rate has to be explicit, because a finite state no longer buys the
controller's silence: every `mortality_dt` tests the ceiling beside finiteness,
and `Node::compute_rates` holds the log-density rate at zero for a cohort with no
density. Without that second guard the density drifts off its floor — the
exponential of the sentinel is exactly zero, but integrating a positive rate up
from it reaches a representable number again.

**An intermediate of the reverse walk leaving the representable range.** The walk
is a product of per-step Jacobians and has no error control of its own, so it can
pass far outside the range of the answer it returns and come back. Measured on a
stand whose gradient is of order one thousand, the largest intermediate reaches
`4.99978e+281` and is back to `3.69e+46` one range later. That stand answers
correctly. A stand whose intermediate is larger by twenty-six orders does not, and
the overflow arrives at the caller as a not-a-number indistinguishable from one
the last step made.

⚠️ **So the walk checks every entry for finiteness at every step and raises
`AdjointRangeError` at the first failure.** It cannot wait and report at the end:
by then an overflow three thousand steps back is indistinguishable from a
non-finite value the final step produced, and the caller polling for a declared
refusal would find none. `plant` catches it by type and refuses every metric with
no species named.

⚠️ **This refusal is a shipped limitation rather than a repair.** Two of the five
census drivers in the test suite refuse for this reason, and the arithmetic they
refuse on is not wrong — it merely passes through a magnitude a double cannot
hold. Rescaling the walk per range would let them answer. `test-gradient-parity.R`
pins the set of drivers that refuse, and pins it in both directions, so the
limitation cannot widen or narrow without a test failing.

## Where the boundary between refusing and answering sits

A refusal is something the model declares, in words it chose. Anything else that
comes out of a gradient call is a fault, and the two must not be conflated —
particularly in test scaffolding, where treating both as a skip turns a broken
sweep into a quiet suite rather than a red one. Measured: a deliberately wrong
narrowing step made one tier skip six times and fail none.
