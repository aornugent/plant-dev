# A light field that carries its own slope

**Terminology.** A cohort is a cohort; **knot** is a point of an interpolant. `A(z)` is total
projected leaf area above height `z` per patch area — the optical depth — and `L(z) = exp(−A(z))`
is light availability, which is what the field stores.

Every cohort reads the light field and every cohort builds it, so the field is the one object the
reverse pass transposes rather than sweeps. This report states what the field has to be for that
transpose to be local, exact and refinable — and what it costs when it is not.

Report 00 §2 is why the field is the coupling; report 05 §6.1 is the transpose and its sparsity.

---

## 1. The proposal

**1. Compute `dA/dz` exactly. It is already in the model.** Every strategy declares the leaf-area
density `q(z, h)` next to the cumulative shape function, and differentiating the cumulative form
gives

```
d/dz [ k_I · a · (1 − (z/h)^η)² ]  =  − k_I · a · q(z, h)
```

exactly. So the field's vertical gradient is a **second reduction over cohorts of the same shape as
the competition reduction**, using a function both supported shading models already call. No new
mathematics, no separable-field algebra, no per-`η` condition — each cohort contributes with its own
crown shape and a sum is a sum.

**2. Interpolate with a scheme that carries a value and a slope at each knot**, so the slope
accessor returns the exact derivative of what the value accessor returns, and neither is a
by-product of a fit.

The identity in part 1 is now checked in the forward model, and holds wherever a difference can
verify it. That matters more than it sounds: **the cumulative form and the density are an exact
derivative pair only as long as nobody edits one of them**, and nothing about declaring both ties
them together.

### Which strategies the identity covers

`q` is the exact negative vertical derivative of the **Yokozawa** kernel, which is what the algebra
above differentiates. A model that routes competition through a different profile — a box, a soft
box, a stepped plan-area profile — reaches the field by another path, and there `−k_I · a · q` is
the slope of a profile the field does not use. The identity is a property of the kernel, not of the
declaration, so **a strategy that declares both forms without checking them against each other can
have them drift apart silently, and the value will not show it.**

### What the reduction costs, and why it need not cost the product

Both reductions run over every cohort at every knot, so stated naively the field costs knots times
cohorts per stage. **Measured, that product is 62 to 88 percent of a right-hand side in the
carbon-only model, rising with stand size** — because the per-cohort physiology is linear in cohorts
and the field build is not. Where the physiology carries a water solve the same build is about a
sixth of the step, so *how much a knot costs is a property of the model it is built for*, and a
knot-count argument taken from one does not transfer to the other.

It need not be a product, and the reason is a property of the kernel rather than of any grid. The
Yokozawa profile is a polynomial in `u^η`:

```
(1 − u^η)²  =  1 − 2 u^η + u^(2η)
```

so every dependence on the query height is `z^η` or `z^(2η)` and every dependence on a cohort is
`c_k`, `c_k h_k^-η` or `c_k h_k^-2η`, where `c_k` collects the quadrature weight, the density and
the competition effect. Three running sums over cohorts ordered by height therefore give every knot
at once, and both the value and the slope come off the same three, which is what §3.2 asks for.

Two conditions, and both are load-bearing. **The sums must be carried already scaled by the height
they were last read at** — written unscaled, `h^-η` at `η = 12` spans nineteen orders over one
stand's heights and the sum annihilates its own small terms. And **the expansion is the kernel's
property, not the field's**: a profile that is not a polynomial in `u^η` reaches the field by the
per-height sum, which is the same statement as the identity's scope above.

---

## 2. Why the value is easy and the slope is not

The optical depth sums each cohort's contribution over `z ≤ h_j` and zero above. With `u = z/h_j`
the term is `(1 − u^η)²`, and near `u = 1` we have `(1 − u^η) ~ η(1 − u)`, so the term is `O((1−u)²)`
and its `z`-derivative is `O(1−u)`. The **second** derivative does not vanish. Therefore:

> **`A(z)` is C¹ but not C², with a curvature break at every distinct cohort height.**

That single fact explains the asymmetry. A cubic fitted to values converges at `O(h⁴)` and its
derivative at `O(h³)`, *on a span where the target is smooth*. A refiner chasing value error places
knots where the value error is worst, which is near the breaks: it clusters around them rather than
landing on them. The value survives, because a C¹ function is well approximated in value by a smooth
interpolant. The slope does not, and refining further does not help, because each new knot still
sits inside a span containing a curvature jump.

**The consequence is not that a fitted slope is unusable at its current density.** It is that slope
accuracy is *purchasable with knots* in one scheme and not in the other, and **a quantity you cannot
refine cannot be given an error budget.**

### Measured, and the purchasable claim does not survive

Both schemes at the same knots on real stands, so nothing but the interpolant differs — a
value-and-slope scheme reading `2n` exact numbers against a solved-slope cubic reading `n` and
inferring the rest:

| | value error | slope error | crown-mean a cohort reads |
|---|---|---|---|
| value+slope, gain over solved | 1.3–2.6× | 1.0–2.1× | nothing consistent |

**Neither slope converges.** Over an eightfold refinement the observed order is 0.7 to 1.6 against
the 3 a smooth span would give, for *both* schemes. The reason is this section's own fact taken to
its conclusion: a hundred cohorts across three hundred spans put a curvature break in roughly a
third of them, so exactness *at* the knots does not rescue the interior of a span that holds one.
Slope accuracy is therefore not purchasable with knots in **either** scheme on a stand the model
reaches, and the sentence above overstates the asymmetry.

**What that does and does not touch.** It is a statement about the interpolated slope *as a
function of height*. The transpose does not read that: it reads the slope **at the knots**, which is
exact by construction because it comes from the reduction rather than from a fit (§3.2). So §3's
requirements are unaffected, and what fails is only the claim that refinement buys a slope.

It also removes the accuracy argument for the scheme in the **forward** model, where the field is
read for its value and never asked for a slope (§5). A value gain of 1.3–2.6× at matched knots is
worth having and is not a case on its own; what the scheme buys forward is locality (§3.1), and what
it buys backwards is a transpose that is local and exact.

---

## 3. The three properties the transpose needs

### 3.1 Locality — and it depends on which interpolant, not on the word "spline"

A scheme carrying a value and a slope at each knot has genuinely local support: a query inside one
span reads exactly two knot values and two slopes, **four non-zeros**, and its adjoint is `O(1)` per
query.

An *interpolating* spline that solves a tridiagonal system for its slopes has **no local support at
all** — every knot value influences every query, decaying geometrically — so its adjoint is a
transposed band solve of run-dependent width. The distinction is not academic, because the model
contains both kinds: the vulnerability tabulation is the solved kind and the light field must not
be.

**Measured, by moving one knot value and asking how far the field responds:**

| | response reaches | in spans |
|---|---|---|
| value and slope at each knot | 0.098–0.099 m | **2.0** |
| slopes from a tridiagonal solve | 2.07 m | **41.4** |

At a young stand that 41 spans is **half the column**, and the figure is the same at maturity
because it is a property of the solve rather than of the stand. So one cohort's change moves a
solved field almost everywhere, and this is the sharpest statement of what the transpose would have
to carry.

**It is also the forward model's reason for the scheme**, which §2's measurement leaves as the only
one: a build can hand over a whole grid at once precisely because each span is determined by its own
two endpoints, where a solved scheme has to be given every value before it can answer anywhere. §1's
cost statement is what that enables.

Two qualifications, both load-bearing:

**The sparsity is a property of the recorded step's *field inputs*, not of the composed dependence
on cohort state.** Each supplied slope is itself a reduction over every cohort. Report 05 §6.1
states the claim at the boundary where it holds, and report 07 §1 exploits it there.

**The row's width is set by the quadrature rule, not by the canopy.** A crown integral under a fixed
`n`-point rule touches at most `n` spans, hence at most `n+1` values and `n+1` slopes. **The bound
does not grow with the stand or with the tree** — which is the fact that makes the coupling's cost
independent of stand size.

### 3.2 Value and slope must come from one construct

Two constructs — a fitted value and a separately computed slope — agree nowhere except by accident,
and the disagreement is invisible in the value.

This extends below the interface. If the slope is supplied by its own reduction over cohorts, that
reduction must **merge its terms in the same order as the value reduction**, or the two come from
sums differing in their last bits. That is the detached-derivative pattern this report exists to
remove, reintroduced at the level of floating-point association. Forming both in one pass is the
only arrangement in which the order is guaranteed identical, and it is also cheaper, because the
two share the expensive power.

### 3.3 The knot positions are structure, and the channel they drop must be bounded

Cohort heights are ODE state carrying derivatives, so knot positions are taken passively. Dropping
that channel is the right treatment — moving a knot changes the interpolant, not the interpolated
function — and it is what any adaptive knot set already gets.

**And the treatment is better than "acceptable", which an earlier reading of this section missed.**
Write the discretised rates as `f(y; x(y))` against the true rates `F(y)`, with `e` the
interpolation error:

```
df/dy  =  ∂F/∂y  +  ∂e/∂y  +  ∂e/∂x · ∂x/∂y
                    kept        dropped
```

Both of the last two terms are error *relative to the gradient wanted*. Taking positions passively
does not introduce an error; it declines to carry one. So a difference of the rates, which carries
both, is the **less** faithful of the two — and any comparison that treats it as the reference is
measuring the size of a discretisation term and not the correctness of a gradient.

What the dropped term costs is therefore not accuracy but two other things.

**A difference of the rates cannot referee the column it lands in.** Where positions are an affine
function of the tallest cohort's height, the chain from that height through every knot position into
every crown integral is re-formed at every stage, so sweep and difference disagree on that one
column by construction. Measured, the tallest cohort's height column sits three orders above every
other height column on that grid and falls to the difference's own floor when the positions are held.
That is a permanent hole in what a difference can check, and it is the honest reason to want
positions that do not move.

**The discretisation error is state-sensitive at the scale of the dropped term.** That is a
statement about the forward model rather than the gradient: the rates carry an artefact that moves
as the canopy moves, which reaches the step-size controller and the smoothness of any objective
built on the run.

**The channel shrinks, but only at first order, so refinement does not close it.** Measured against
the field's own error on one stand, holding the profile and moving only the grid:

| knots | dropped channel | field error | ratio |
|---|---|---|---|
| 33 | 2.5e-01 | 2.2e-03 | 113 |
| 129 | 5.8e-02 | 1.3e-04 | 437 |
| 1025 | 7.6e-03 | 1.6e-06 | 4698 |

The channel falls as `1/K` and the error as `K^-2.2`, so **refining a canopy-tied grid makes the
dropped term larger relative to the accuracy it is bought with.** The falsifier this section used to
name is therefore answered, and answered against the grid rather than against the treatment.

A **fixed absolute grid** is not what the objection above imagines. A grid of fixed *extent* would
indeed leave most knots above the canopy for decades, since the canopy grows by two orders of
magnitude over a run. A fixed *lattice* whose extent grows — positions at multiples of one spacing,
populated as far as the canopy reaches — has neither problem: the positions are constants of every
run, so the channel is identically zero rather than small, and knots above the canopy are exactly
inert because value and slope both vanish at `u = 1`. What it costs is knots, and §1's cost
statement is what decides whether that is a price worth paying.

---

## 4. What the field's own non-smoothness costs

**The value of the field is robust; its slope is what ceases to exist.** The competition profile is
continuous in its own arguments everywhere it is evaluated — at the crown-top cutoff, at the canopy
cap where leaf area is exactly zero, and at the ground knot for every crown shape. Each is a C¹ join
where value *and* slope vanish exactly, so dropping the branch indicator's derivative is **exact**
rather than an approximation.

The consequence for an interface: **a value accessor must keep working when a slope accessor
refuses.** Pairing them forces a forward model with no derivative problem to stop.

### The ground knot is the hazard, and it has two separate faults

**The density divides by height, so it is `0/0` at the crown base** — which is the field's lowest
sample point, at every height. That is a value defect with no AD involved, and it is fixed by taking
the limit there: zero above crown-shape exponent 1, and `2/h` at 1.

**And the shape function's derivative with respect to the crown shape is `0^η · log 0` at that same
knot**, which is not a number. In a coupled system this produced a NaN gradient for exactly one
trait while every other trait stayed finite and plausible. At `z = 0` the cohort contributes its
full amplitude with `u = 0` and no power is needed, so the fix is a guard rather than a
reformulation — and until it exists, the crown shape cannot be a differentiation target.

### The light floor and the monotonicity guard are one lever

The crown shape satisfies `Q(0) = 1` for every exponent, so **the field's minimum over its whole
domain is at the ground and equals `exp(−k_I · LAI)`.** A floor on the light therefore binds when
`k_I · LAI` exceeds the floor's log.

The interpolant's undershoot guard sits on the **same** lever: at the ground knot the slope is
exactly zero for exponents above 1, so the first span undershoots once the knot values fall far
enough — which cannot happen while the ground value is far above the floor, and can once it
approaches it.

**So both clamps fire under one parameter change, and `k_I` is a free parameter a gradient-driven
search will walk.** The crown shape is *not* a lever here: it reshapes the profile and leaves the
ground value untouched. Where either binds the severance is an **artefact and not the model**, since
the field is smooth there, so the honest action is to refuse the row with its incidence counted
rather than to return the clamped zero.

Report 06 §6.1 states what this means for a user: a calibration that walks `k_I` upward walks the
field into the region where the row it is ascending goes to zero. That is a closed loop between the
answer and the question, and it has no analogue elsewhere in the design.

---

## 5. One argument that is discharged, and why it is worth recording

An earlier form of this report was organised around a different claim: that a crown integral's
domain moves with the plant's height, so the reverse pass needs `dL/dz` to carry the moving bound,
and that the vertical gradient is the one quantity the model cannot supply.

**That is handled structurally rather than by any call site.** A quadrature rule that takes its
bounds as the active scalar and forms the centre and half-length on it puts the affine map on the
tape, so every abscissa carries it; and an interpolant read at an active position returns a value
and slope pair. The Leibniz boundary term is absorbed because the rule is **mapped rather than
truncated**, and the abscissae are strictly interior, so a crown integral touches neither the ground
singularity nor the canopy cap.

So nothing on the physiology path needs to ask the field for a slope. What survives is §3: the
slope must exist, be exact, be local, and come from the same construct as the value — because that
is what the *transpose* needs, not because a crown integral cannot be closed without it.

---

## 6. What this asks of a strategy author

**1. If you declare a cumulative form, declare its density too — and check they agree.** They are an
exact derivative pair, which is what makes §1 free. A strategy declaring only the cumulative form
forces its slope to be approximated; one declaring both without checking can have them drift apart
silently.

**2. Know where your field is non-smooth.** The breaks are at the cohort tops, which are ODE state,
so their location is data rather than a tuning choice. A refiner chasing a value tolerance will not
find them.

**3. Value and slope must come from one construct**, and if they come from two reductions, from one
merge order.

**4. Positions are structure; values carry derivatives.** Knot positions, quadrature abscissae and
cohort orderings are decided on passive values. Breaking this — sorting on an active key, or letting
a knot *count* depend on an active value — makes the recorded computation state-dependent.

**5. A clamp is a derivative severance, and the two reasons for one are different problems.**
Sometimes the severance is the model. Sometimes it is papering over an interpolant that undershoots,
which needs a different fix — and where the field is smooth underneath, the honest action is to
refuse the row with its incidence counted rather than return the clamped zero. Report 02 §6 carries
the general rule about meaning a kink.

**6. If you integrate over your own size, you need the integrand's slope** — or a quadrature that
carries its bounds actively (§5). The same shape appears wherever an aggregation has a
state-dependent domain, including the root mass distribution over soil layers.

---

## 7. What would falsify this

- **The `q` identity does not hold numerically.** Compare `−k_I · a · q(z, h)` against a tight
  central difference of the cumulative form across a range of crown-shape exponents, covering both
  the specialised multiplication chains and the general power path. If they disagree, the slope
  inherits it.
- **The knot-position channel does not shrink with knot density** (§3.3). *Answered: it shrinks at
  first order while the field's error falls at better than second, so on a canopy-tied grid it grows
  relative to the accuracy it is bought with. What that refutes is the grid, not the treatment —
  §3.3 gives the decomposition showing the dropped term is itself discretisation error.* What would
  still falsify the treatment is a **channel that survives on a grid of constants**, where
  `∂x/∂y` is identically zero: that would mean positions are reaching the field by some route other
  than the interpolant.
- **The reduction's cost is not the share §1 measures it to be**, on a configuration anyone runs.
  Then a knot is priced differently and the grid argument reopens on different numbers.
- **The scheme does not converge at production knot density.** Loss of the expected rate means the
  breaks are not where §2 says they are. *Answered, and the breaks are exactly where §2 says: the
  slope's observed order is 0.7 to 1.6 rather than 3, in both schemes, because a third of the spans
  hold a break. What that falsifies is the purchasable-with-knots claim rather than the location of
  the breaks — §2 carries the correction.* The value still converges, and a slope read **at** a knot
  is exact rather than fitted, so nothing §3 requires depends on the rate.
- **The light floor binds on a stand anyone runs.** Then the light coupling is mostly severed, and
  §4's refusal-with-incidence becomes the production path rather than a guard.
