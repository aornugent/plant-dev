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

## 1. Why the search must not be taped

The tempting approach — make the leaf scalar-templated so the tape records the search along with
everything else — is wrong twice over, and the first reason is decisive.

**It computes the wrong derivative.** Golden section shrinks its bracket by a fixed ratio per
iteration and returns the bracket's midpoint. The iteration count depends only on the bracket
width and the tolerance; the objective enters only through the comparison that picks which half to
keep. So **for a fixed comparison pattern the returned argmax is an exact affine function of the
bracket endpoints and independent of the objective's values.** A tape recording the search yields
the derivative of the bracket, not of the argmax. The objective's sensitivity is structurally
absent from it.

This has a corollary worth stating separately, because it is the thing a reader is most likely to
get backwards: golden section's argmax is **not** smooth in the plant's state either. It is a
staircase in the objective and affine in the bracket. What it gives is a comparison pattern that is
*locally constant*, so across a small perturbation the pattern usually does not change and the
argmax moves affinely with a bracket that itself moves smoothly. Anything downstream that
differences the growth rate in height is differencing that bracket-affine surrogate, not the true
optimum — which is why a probe distance and a search tolerance are coupled through a mechanism
nothing else records.

**It puts an active scalar somewhere it cannot safely go.** The leaf holds interpolators on fixed
grids, loose parameters and per-solve scratch with no boundary between them, caches keyed on exact
comparison, an integrator, a nested root-find and the search. Each is a separate correctness
question under an active scalar, and a mistake in any of them is a wrong gradient rather than a
compile error.

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

Two adjoints arrive — one scalar on profit, one per soil layer on uptake — and leave as
contributions to the soil potentials, the geometry and light inputs, and the traits.

### 3.1 Carbon is an envelope row

Profit is stationary in the operating point, so for every input `u`

```
contribution += λ_Π · ∂Π/∂u        at frozen p*
```

with no argmax derivative anywhere.

### 3.2 Water is not, and the layer rows collapse onto one scalar

Uptake consumes `p*`, so it carries the argmax's motion. Two properties make that cheap.

**The explicit part is sparse.** Each layer's flux reads its own layer's potential and the collar,
so the potential block is diagonal. Root mass enters through the resistance, whose vertical
component is a cumulative sum down the column, so that block is lower triangular. And
`∂E_i/∂area_leaf = −E_i/area_leaf` **exactly**, because leaf area is a single factor and the
resistances contain none — an internal identity rather than a model channel, since report 00's
fact 3 shows the factor cancels downstream.

**The argmax part is rank one, because the operating point is one scalar.** Every layer shares it,
so

```
s = Σ_i λ_{E,i} · ∂E_i/∂p          one number per cohort
m = − s / Π_pp                     one divide
contribution += m · ∇_u (∂Π/∂p)
```

The matrix `(∂E/∂p)(∂p*/∂u)` is never formed. Report 05 §7.2 derives this and §7.3 gives the
structure of the mixed second derivative, which is the one genuinely new object the design needs
and is rank two over the state directions.

### 3.3 The rank-one collapse is verified, independently

The identity a correct transpose must satisfy is `⟨v, J u⟩ = ⟨Jᵀ v, u⟩` for arbitrary `v` and `u`.
An implementation of exactly the construction above — the two scalars and the scaled row, with the
profit row's operating-point channel set to zero by the envelope theorem and the collar's set to
one because it *is* the operating point — satisfies that identity to **1.4e-14 over 294 operating
points**, five orders below the solve's own floor.

Two things follow that are worth more than the number. The identity is **the** check on this node,
because it needs no reference gradient and no differencing: it is a property the transpose either
has or does not. And the two constants in it are the whole of §2's first two facts, so an error in
the envelope reasoning shows up here rather than as a plausible wrong gradient downstream.

### 3.4 The bound case

The operating point is the argmax over an interval whose endpoints are themselves root-finds — the
potential at which total uptake vanishes, and the drier of the stem's and the root's critical
potentials. When the point is interior the bounds enter no row. When it is pinned, the bound's
derivative *is* the answer, and the endpoint conditions are what supply it.

This branch is exact where the interior branch is only as good as its linearisation point, which is
the opposite of what one might expect. Report 06 §7 states what it means: **a pinned plant is
drought**, and any conclusion about drought sensitivity depends on this branch being right.

### 3.5 The polish, which the envelope row requires

The envelope row is valid where the marginal profit is zero. A search stopped at a tolerance
returns a point where it is not, and that error enters the derivative through the point at which
the implicit function theorem is linearised. **The displacement moves profit at second order and
uptake at first order**, which is why the carbon row survives a loose search and the water rows do
not.

So the node requires the operating point to be polished to a stationary point before it is used as
a linearisation point, and the accuracy required is set by the derivative rather than by the value.
Tightening the search instead does not substitute for this: the argmax it returns is bracket-affine
(§1), so a tighter bracket moves the point without making it stationary.

Two consequences for the forward model. The search need only reach the polish's basin, so it can be
run loose and the polish paid for out of the evaluations the loose search no longer does. And the
polish needs an iteration cap sized against how often it is exhausted rather than against how often
it converges — a cap chosen at the wrong scale is invisible in the value and shows up as a
derivative that does not settle.

---

## 4. What the boundary must guarantee

The node is a contract between a passive solver and an active caller. Six requirements, each with
the failure it prevents.

**1. Only values cross, in both directions.** The caller hands doubles in and receives doubles and
derivative rows back. Nothing active enters the solver, and no tape is live inside it. This is what
lets the solver keep its caches, its exact comparisons and its searches without any of them
becoming a correctness question.

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
§3.3, and never against a difference of the step that consumes them.

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

**A guard that returns non-finite and falls back to a difference is a severance in disguise.**
Where the analytic route declines at a branch kink and a central difference stands in, the value is
unaffected and the derivative is quietly a different object. That is acceptable only as a recorded
decision with its incidence counted, and it must not sit inside a supplied row, which is precisely
where a numerical derivative of an active quantity should not be.

---

## 6. What this asks of a strategy author

The engine's contract does not change: a strategy computes rates and gets a gradient. But a
strategy containing an inner solve has obligations no compiler checks.

**1. Return the solution, expose the residual, never expose the search.** For a quantity defined
implicitly the differentiable object is the defining equation.

**2. Know which of your outputs are load-bearing.** Only outputs that reach rates need derivative
rows. Establishing that the leaf has two rather than seven turned a large problem into a small one.

**3. An objective at its own optimum is free; its other consumers are not.** The question to ask of
every output of an optimisation is whether it *is* the objective or merely reads the argument that
maximised it.

**4. A feasibility bound is part of the model, so its derivative is part of the answer.**

**5. Count your branches before designing around them,** and count them on a driver that reaches
the regime in question. Report 05 §7.0's five kinds are consecutive segments of one drydown, so a
census taken on a wet driver establishes nothing about a dry one.

**6. Say whether a switch is a kink you mean.** A zero derivative may be exactly what the model
means; the point is that it should be a recorded decision rather than an artefact of writing an
`if`.

---

## 7. What would falsify this

- **Profit is not always the objective at its own maximiser.** Any path that sets profit other
  than by evaluating the objective at the returned operating point breaks the envelope argument
  there. The shutdown exits are such paths, and they are case X in report 05 §7.0 rather than an
  interior optimum.
- **The transpose identity fails at a state the forward model reaches.** §3.3 establishes it over
  interior and pinned points; a fold, a collapsed feasibility window or a tracked operating point
  are where to look next.
- **The rank-one collapse is not the only route from the operating point into a layer's flux.** Then
  the single scalar `s` is incomplete and the whole cost argument changes.
- **The polish does not reach stationarity on the real objective.** The objective is a composition
  through the stem-potential inversion, so how many steps suffice is a property of that composition
  and not of the toy that motivated the polish.
- **The supplied rows disagree with the solver's own algebra.** This is the direct test and it needs
  no stand: evaluate one solve, form each row analytically, and compare. §4 item 3 says why it
  cannot be done any other way.
