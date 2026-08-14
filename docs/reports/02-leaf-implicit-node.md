# The leaf as a single differentiable node

Everywhere else in TF24 a rate is a closed-form function of state and traits. In the leaf it is
not: the plant **chooses** its operating point, maximising carbon profit over the root-collar
water potential within a feasibility interval the soil sets. Differentiating a choice is a
different problem from differentiating an expression, and it has to be treated as one.

This report states the treatment: **the leaf is one node on the tape, and its local Jacobian is
supplied rather than recorded.** Report 00 §4.2 gives the forward solve;
[`05-reverse-mode-mathematics.md`](05-reverse-mode-mathematics.md) §7 gives the algebra of the
derivatives; report 00 §6 says where each row goes. What is here is why the node has this shape,
and what a boundary carrying it must guarantee.

---

## 1. Solve the condition; do not search the objective

The tempting approach — make the leaf scalar-templated so the tape records a maximisation along
with everything else — fails, and the reason runs deeper than "a tape would record the wrong
thing."

**A comparison search does not determine the argmax well enough to differentiate, by any route.**
Golden section shrinks its bracket by a fixed ratio per iteration and returns the midpoint. The
iteration count depends only on the bracket width and the tolerance; the objective enters only
through the comparison that picks which half to keep. So for a fixed comparison pattern the
returned argmax is an exact affine function of the bracket endpoints and **independent of the
objective's values** — a tape recording it yields the derivative of the bracket.

The instinct that this is nonetheless safe, because the comparison pattern is locally constant and
so the argmax moves affinely with a bracket that itself moves smoothly, **is false and has been
measured false.** Terminating on bracket *width* resolves the argmax only to the tolerance, and the
residual offset inside that width wanders discontinuously as the comparison sequence flips. Across
eleven steps in one trait the search returns **six distinct answers**, with a tread the width of
the tolerance. The argmax is piecewise constant at fine scales, and the consequence for a
derivative taken through it is the pair of failures this design most fears: **exactly zero**, or —
for traits reaching the hydraulic path — **smooth, plausible and sign-inverted.** Measured on one
vulnerability-curve parameter, the search returned `−2.6e-03` where the true derivative is
`+2.6e-04`: wrong sign, wrong magnitude, and nothing about the number to suggest either. A
photosynthetic trait came back 52 percent low by the same mechanism.

**A staircase announces itself; a smooth wrong sign does not.** That asymmetry is why the tread
being small is no comfort — the coarse failure is the detectable one.

**So the operating point is obtained by solving its own first-order condition, `∂Π/∂p = 0`.** That
resolves it to solver precision rather than to a bracket width, and the improvement is not
marginal: second differences in a trait are smoother by about three orders of magnitude. **It is
also cheaper** — roughly a quarter faster per solve, because a superlinear root-find reaches a
tolerance many orders tighter in fewer evaluations than a ratio-shrinking search needs for a loose
one. There is no accuracy-versus-cost trade here to reason about; the correct construction is the
fast one.

This is §6's first rule applied to the leaf's own operating point rather than to something
downstream of it. **A search is not a definition.** The differentiable object is the condition the
answer satisfies, and where that condition is available — as it is here, in closed form, and needed
by the forward model anyway — searching the objective instead discards it.

**A second, independent reason keeps the leaf passive.** It holds interpolators on fixed grids,
loose parameters and per-solve scratch with no boundary between them, caches keyed on exact
comparison, an integrator and a nested root-find. Each is a separate correctness question under an
active scalar, and a mistake in any of them is a wrong gradient rather than a compile error.

**So the leaf stays passive, and the tape gets one node.** Nothing inside it is differentiated; the
node relates its inputs to its outputs and the tape sees a small dense block.

---

## 2. The four facts that make the node cheap

- **Profit is the objective evaluated at its own maximiser.** By the envelope theorem its
  derivative is the partial derivative at *fixed* operating point — the argmax's motion contributes
  nothing. This is the entire carbon channel: assimilation, net mass production, all four growth
  rates, the mortality argument. **No argmax derivative is needed for any of it.**
- **Per-layer uptake is a different matter.** It is set as a side effect *at* the operating point,
  so it consumes the argmax rather than being the objective, and the envelope theorem says nothing
  about it. Here the argmax's motion is genuinely required, and the implicit function theorem
  applied to the stationarity condition supplies it.
- **At a bound both are simpler.** When the operating point is pinned to a feasibility bound, it
  *is* the bound, so its derivative is the bound's derivative — analytic, and exact. The profit row
  then reappears in the adjoint, because the envelope theorem has failed at a boundary; that is not
  an inconsistency between the branches but the theorem's own scope.
- **The selector between them is not a comparison on the residual.** Report 05 §7.0 gives five
  kinds of point and requires a decision tree on what *defines* each one. The reason is sharp: the
  marginal-profit function returns a hard sentinel zero in a no-flow or infeasible state, and no
  residual test can distinguish that from stationarity. A state so classified is recorded as an
  interior optimum, its curvature reads zero from the same sentinel, and the argmax multiplier
  divides by an exact zero with a generically non-zero numerator.

---

## 3. The node

The node has a set of outputs, an adjoint arrives on each, and they leave as contributions to the
soil potentials, the geometry and light inputs, and the traits.

### 3.0 The output set is a design choice, and it is where a boundary silently under-serves

Which quantities the node treats as outputs is not given by the physics. It is chosen, and **two
consumers want different sets.** A calibration fits a leaf against gas-exchange observations, so its
outputs are the measured ones — assimilation, stomatal conductance, stem potential, the operating
point, profit. **A stand adjoint wants none of those except profit, and wants one the other does not:
per-layer uptake**, because that is the only thing a cohort writes into the shared soil (report 00
§2).

The two sets overlap in exactly one entry. So a leaf boundary built for either consumer serves the
other with a set that looks complete, returns finite numbers for everything it does list, and is
missing the channel the other one is about. **Nothing detects this**: the absent output has no
column, so it cannot read as a wrong number, and a caller that never asks for it never learns it is
not there.

The rule that follows is the one this whole report is an instance of: **enumerate the outputs from
the consumer's equations, not from what the solver happens to expose.** For a stand adjoint the
enumeration is report 00 §4.2's two kinds, and profit is the one they share.

### 3.1 Carbon is an envelope row

Profit is stationary in the operating point, so for every input `u`

```
contribution += λ_Π · ∂Π/∂u        at frozen p*
```

with no argmax derivative anywhere.

### 3.2 The rank-one scalar is the operating point itself

Everything not stationary in `p` carries the operating point's motion, and they all carry the *same*
motion, because `p` is one number. So the collapse is best written over the outputs rather than over
the soil layers:

```
s = Σ_j v_j · ∂y_j/∂p               one number, whatever the output set is
m = − s / Π_pp                      one divide
contribution += Σ_j v_j · ∂y_j/∂u|_p  +  m · ∇_u (∂Π/∂p)
```

Two channels in that sum are fixed by the mathematics rather than computed, and getting either wrong
is silent. **Profit's `p`-channel is exactly zero** — that is §3.1, the envelope theorem — and **the
operating point's own `p`-channel is exactly one**, because it *is* `p`. Everything else contributes
its ordinary partial.

Written this way the economy is visible: the matrix `(∂y/∂p)(∂p*/∂u)` is never formed, and the cost
drops from outputs × parameters to outputs + parameters. Report 05 §7.2 derives it; §7.3 gives the
structure of the mixed second derivative `∇_u(∂Π/∂p)`, the one genuinely new object the design
needs.

**Exposing the operating point as an output is what makes this composable.** A consumer that needs
uptake rows and one that needs conductance rows then contract through the same scalar, and neither
needs its own version of the argmax machinery.

### 3.3 The explicit part of the water channel is sparse, and one of its terms has left the model

Per-layer uptake reads its own layer's potential and the collar, so `∂E_i/∂ψ_j` is **diagonal — and
that is the whole soil Jacobian of the supply, not its diagonal part.** It is not the collar
conductance negated, either: the two endpoints sit at different points on a non-linear vulnerability
curve, so the integral terms do not cancel. That is report 00's fact 2 again — differences and
absolutes — and it means a boundary offering one of the two cannot be assumed to offer the other.

**And `∂E_i/∂area_leaf = −E_i/area_leaf` exactly** — leaf area is a single factor and the
resistances contain none. Report 00's fact 3 shows the factor then cancels downstream, so this is an
internal identity rather than a model channel.

That identity has a consequence worth its own line, because it is the reason the row can vanish
without anyone noticing. **A resistance network is homogeneous of degree −1 in the root carbon it is
built from**, so scaling carbon by `1/A` scales the resistances by exactly `A`. A boundary can
therefore take *resistances per unit leaf area* and never mention leaf area at all — which is the
right factoring, since which root-architecture model is in force is not the leaf's business. But
then **leaf area is a convention on both sides of an interface that cannot check it**: a caller
handing over resistances built from absolute carbon gets a silently wrong uptake rather than an
error, because five vectors of positive numbers look the same either way. §4 item 7 states the
general form.

### 3.4 The rank-one collapse is verified, independently

The identity a correct transpose must satisfy is `⟨v, J u⟩ = ⟨Jᵀ v, u⟩` for arbitrary `v` and `u`.
An implementation of exactly the construction above — the two scalars and the scaled row, with the
profit row's operating-point channel set to zero by the envelope theorem and the collar's set to
one because it *is* the operating point — satisfies that identity to **1.4e-14 over 294 operating
points**, five orders below the solve's own floor.

Two things follow that are worth more than the number. The identity is **the** check on this node,
because it needs no reference gradient and no differencing: it is a property the transpose either
has or does not. And the two constants in it are the whole of §2's first two facts, so an error in
the envelope reasoning shows up here rather than as a plausible wrong gradient downstream.

### 3.5 The bound case

The operating point is the argmax over an interval whose endpoints are themselves root-finds — the
potential at which total uptake vanishes, and the drier of the stem's and the root's critical
potentials. When the point is interior the bounds enter no row. When it is pinned, the bound's
derivative *is* the answer, and the endpoint conditions are what supply it.

This branch is exact where the interior branch is only as good as its linearisation point, which is
the opposite of what one might expect. Report 06 §7 states what it means: **a pinned plant is
drought**, and any conclusion about drought sensitivity depends on this branch being right.

### 3.6 What the first-order solve has to guard

Why the accuracy matters at all is worth stating, because it is what makes §1 a correctness argument
rather than a tidiness one. **A displacement of the operating point moves profit at second order and
uptake at first order.** So the carbon row survives an imprecise operating point and the water rows
do not — and the water rows are the ones that carry the competition.

Solving the condition rather than searching the objective removes that exposure at the root, and it
retires the intermediate construction that a search forces: a maximise-then-correct step, in which
the search is run loose and its answer polished onto the condition afterwards. That works, and it is
strictly worse than not having the search — an extra tolerance to size, an iteration cap whose
exhaustion is invisible in the value, and two failure modes where the direct solve has one.

Three things the solve does have to guard, and each is a property of the problem rather than of any
solver.

**One endpoint of the bracket is infeasible by construction, and it returns a sentinel.** The wet
bound is the collar potential at which uptake is exactly zero — which is precisely where the stem
potential meets the collar and the marginal-profit function takes its no-flow exit, returning a hard
zero that is not a derivative. **So a bracketing method is handed a sentinel at one end, always, and
a solver that trusts it reports the zero-transpiration point as the optimum.** Measured, that is a
profit of −1.90 returned against 2.52 at the true optimum. The infeasible sliver is narrow — under
`1e-6` of the bracket — so stepping inside it is cheap; the point is that it must be stepped over
rather than evaluated. Report 05 §7.0 states the sentinel hazard for *classification*; this is the
same sentinel one level down, corrupting the forward answer.

**Profit is discontinuous across that same boundary**, not merely steep: below the feasibility edge
the algebra runs on a negative conductance and returns a plausible number, and the jump across the
edge has been measured at 1.44 in profit. So the bound must not be *returned* either — a pinned
operating point sits just inside the boundary, not on it.

**And the two pin tests are not exhaustive; the leftover case is a failure, not a third pin.** If
profit is falling away from *both* ends into the interval, the interior stationary point is a
**minimum** and the maximum is at one of the bounds — but the gradients cannot say which. Attributing
it to whichever bound the test order happens to reach first returns a finite, plausible, wrong answer
with a genuinely non-zero gradient pointing the wrong way. It must refuse. That is case **N** of
report 05 §7.0, and the profits rather than the gradients are what identify it if an answer is
wanted.

**One kink is real and belongs to the problem.** Where a state crosses between interior and pinned,
the operating point has a genuine kink in trait space. No solver removes it — a search has it too —
and it sits where a calibration is most likely to wander.

---

## 4. What the boundary must guarantee

The node is a contract between a passive solver and an active caller. Six requirements, each with
the failure it prevents.

**1. Only values cross, in both directions.** The caller hands doubles in and receives doubles and
derivative rows back. Nothing active enters the solver, and no tape is live inside it. This is what
lets the solver keep its caches, its exact comparisons and its inner solves without any of them
becoming a correctness question.

Note what this does *not* forbid. The solver may differentiate itself internally by any means it
likes — forward-mode on its own kernels, analytic spline derivatives, the implicit function theorem
at an inner root-find — and for a handful of inputs forward mode is the right choice there, being
tape-free and header-only. **The node is what composes a forward-differentiated solver into a
reverse sweep**, and the reason that works is precisely that the sweep never enters the solver. A
boundary is a scalar-type boundary, not an AD-mode boundary.

**2. The rows are grafted, not recomputed.** The recorded expression is
`value + Σ_i partial_i · (u_i − passive(u_i))`, which is **exactly** the value — every bracket is
zero — and carries the supplied derivative. Report 05 §8 gives the three preconditions and the one
that is easiest to miss: **a non-finite supplied partial corrupts the value, not only the adjoint**,
because `NaN × 0` is not a number. The finiteness test therefore belongs on the partials before
they meet the brackets; there is nowhere downstream to put one.

**3. A finite difference of the node cannot referee its own rows.** Property 2 makes the block's
forward value independent of a grafted input, so differencing the block returns identically zero on
exactly the columns a supplied row occupies — whether the row is right, wrong, or absent. Supplied
derivatives must be checked against the solver's own algebra, or against the transpose identity of
§3.4, and never against a difference of the step that consumes them.

**4. The input list must be derivable, not maintained.** A list assembled by reading a function
signature becomes silently incomplete when the signature grows, and the failure is a trait column
that reads **exactly zero** — this design's worst shape, because a zero reads as an answer. The
same hazard applies one level up: a caller that assembles its graft vector from a subset of the
declared inputs discards every row outside that subset, with no signal.

**5. Every exit sets the whole operating point.** An early exit that writes some outputs and leaves
others holding the previous solve's values is a cross-cohort channel, because the solver is shared
across every plant of a species. Report 00 §7 item 5 is the structural form of this.

**6. The classification is reported by the branch taken.** Not inferred afterwards from a residual,
for §2's reason. And it must be reset at the top of each solve, because a branch that declines to
write it leaves the previous plant's classification — a plausible answer about a different plant.

**7. A derived input cannot be checked by the side that receives it.** Whenever a boundary takes a
quantity the caller computed rather than the thing it was computed from — resistances instead of
root carbon, a conductance instead of a height, a per-unit-area quantity instead of an absolute one
— the convention is now shared and only one side can see it. The receiving side gets numbers that
are well-typed, positive and plausible under either convention, so **no check on that side can
exist.** This is the right factoring and it is worth doing; what it obliges is that the convention is
stated at the boundary and asserted on the *caller's* side, where the inputs to the derivation are
still visible. §3.3's leaf-area homogeneity is the instance that motivates it.

**8. Two channels of different shape must not share a loop.** The rows out of this node are not one
family. A soil row is a scalar price times a supply derivative; a light row has no supply derivative
to multiply at all, because at a fixed operating point radiation moves no water — it is a direct
partial of the assimilation kernel, closed by the inner root-find's own implicit-function term. A
single generic loop over "environment inputs" forces one shape into the other's, and the failure is
not a wrong number but an index: one channel ends up addressed through a container sized for the
other. **Where two rows have different derivations, give them different entry points**, and let the
caller pay the small cost of knowing which is which.

---

## 5. Two rulings that are easy to get backwards

**Differentiate the model being evaluated, not the model it approximates.** Where the forward
solve reads a tabulated curve, the derivative that belongs on the tape is the *table's*, not the
closed form the table approximates. A closed form is the more accurate derivative of a different
function, and substituting it introduces a systematic disagreement — measured at parts in a
thousand for the vulnerability integral — that no invariant on the gradient can attribute. The
closed forms are still worth having, and report 05 §7.6 derives them; what they are for is
replacing the *table*, in the forward model, as one change with one re-blessing. They are not a
drop-in for its derivative.

**A non-finite return is a legitimate answer; a silent substitution for one is not.** Where the
analytic route genuinely has no row — a branch kink, an equal-potentials boundary — returning
non-finite and *documenting that as the contract*, so the caller knows to difference or to refuse,
is the honest design and it composes: the decision is made where the information is. What is not
acceptable is the same non-finite quietly replaced by a difference *inside* a supplied row, because
then the value is unaffected, the derivative is quietly a different object, and no caller can see
which of the two it received.

The two are one line apart in code and opposite in kind. The test is whether the caller can tell:
**a sentinel that reaches the caller is an interface; a sentinel absorbed before it does is a
severance.** And a row refused for one layer should refuse the call, not the layer — a vector with
one meaningless entry among finite ones is the worst of the three outcomes.

---

## 6. What this asks of a strategy author

The engine's contract does not change: a strategy computes rates and gets a gradient. But a strategy
containing an inner solve has obligations no compiler checks. The first four are the sections above
restated as instructions, because what a *model author* needs is not what an *interface* needs; the
last two appear only here.

**1. Return the solution, expose the residual, never expose the search** (§1). For a quantity defined
implicitly the differentiable object is the defining equation, and a search is not a definition.

**2. Enumerate your outputs from the consumer's equations, not from what the solver exposes** (§3.0)
— and put the implicit quantity itself among them (§3.2), so every consumer that is not the objective
contracts through one scalar instead of carrying its own copy of the argmax machinery.

**3. An objective at its own optimum is free; its other consumers are not** (§2). Ask of every output
whether it *is* the objective or merely reads the argument that maximised it.

**4. A feasibility bound is part of the model, so its derivative is part of the answer** (§3.5).

**5. Count your branches before designing around them — on a driver that reaches the regime in
question.** Report 05 §7.0's five kinds are consecutive segments of one drydown, so a census taken on
a wet driver establishes nothing about a dry one, and a corner reported as unreachable is usually a
corner nobody drove at.

**6. Say whether a switch is a kink you mean.** A zero derivative may be exactly what the model
intends; the point is that it should be a recorded decision rather than an artefact of writing an
`if`. **This is the corpus's canonical statement of that rule**, and reports 01 and 03 point here
rather than restating it.

---

## 7. What would falsify this

- **Profit is not always the objective at its own maximiser.** Any path that sets profit other
  than by evaluating the objective at the returned operating point breaks the envelope argument
  there. The shutdown exits are such paths, and they are case X in report 05 §7.0 rather than an
  interior optimum.
- **The transpose identity fails at a state the forward model reaches.** §3.4 establishes it over
  interior and pinned points; a fold, a collapsed feasibility window or a tracked operating point
  are where to look next.
- **The rank-one collapse is not the only route from the operating point into a layer's flux.** Then
  the single scalar `s` is incomplete and the whole cost argument changes.
- **The first-order condition has more than one root in the feasible interval.** §1's construction
  assumes the marginal profit crosses zero once. A second crossing is a second stationary point, and
  a bracketing solver returns whichever one its bracket contains — silently, and with a perfectly
  correct envelope row at a point that is not the maximum. Report 05 §7.0's fold analysis is where to
  look, since the curvature that would admit a second root is the curvature that would admit a fold.
- **The supplied rows disagree with the solver's own algebra.** This is the direct test and it needs
  no stand: evaluate one solve, form each row analytically, and compare. §4 item 3 says why it
  cannot be done any other way.
- **A stand adjoint can be built without per-layer uptake rows.** §3.0 rests on the claim that the
  soil coupling needs them, because per-layer draw is what a cohort writes into the shared state. If
  the soil's own adjoint can be closed through the *total* instead, the output sets are not disjoint
  after all and the section's warning is about nothing. Report 00 §2's rank argument is where to
  check: the coupling is a vector per layer, not a scalar, and the positivity guard makes the layers
  behave differently from one another.
