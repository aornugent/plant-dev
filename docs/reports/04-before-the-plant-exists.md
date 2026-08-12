# Before the plant exists: parameterisation, construction, and the inflow boundary

Three things happen outside a cohort's rate path, and each decides derivatives that
no tape records: a **parameterisation** maps the inputs a question is asked in onto
the parameters the model carries; **construction** derives a strategy's dependent
quantities once, in plain arithmetic; and an **introduction** builds a plant out of
those results. All three sit upstream of the recorded step, so a derivative lost in
any of them is lost silently, and every instrument that differentiates the model
inherits the loss rather than measuring it.

Report 01 decomposes the sweep and takes the cohort as its unit. This report is
about what is settled before that unit exists. The two touch at one point — report
01 §2.3 rules that preparation must not run inside the block, on cost grounds — and
this report states what that ruling costs in derivatives and what has to be true for
it to be safe.

Its referee is the mathematics plus the objective. Where it disagrees with the code,
one of them is wrong and the disagreement is the finding.

---

## 1. What a row is, and what it is not

A gradient column is the derivative of a census with respect to **one carried
parameter, holding every other carried parameter fixed.** That is a complete
definition and it is narrower than what a reader wants from it.

It is narrower because a model is usually presented in fewer numbers than it
carries. A derivation sits above the carried set: a measured trait fixes several
carried parameters at once, a spectrum axis moves a group together, a fitted vector
is smaller than the set it determines. Where such a derivation is in force, the
column and the question are different objects:

$$\nabla_\phi \mathcal{C} = J^{\!\top}\nabla_\varphi \mathcal{C}, \qquad J = \frac{\partial\Phi}{\partial\phi}$$

with `Φ` the derivation and `φ` the carried set. Report 07 §3 develops `J` as an
adapter and defers it. What belongs here is the part that is not deferrable: **until
`J` exists, a column is a statement about the carried parameter and must not be read
as a statement about the quantity it is named after.**

The leaf economics spectrum is the instance that makes this concrete rather than
pedantic. Leaf mass per area fixes leaf lifespan and maintenance respiration as well
as construction cost — that coupling *is* the spectrum, and it is among the
best-established relationships in plant ecology. A column taken with lifespan and
respiration held fixed describes a leaf that is heavier per unit area and no
longer-lived, which no leaf is. Measured on the leaf-area census at four years,
the two answers differ by a factor of **3.2**, same sign: the carried-parameter
column is the larger, because the trait's own compensations are absent from it.

**Two rules follow, and the second is the one that can be enforced.**

Report 06 §7 makes the first: a sensitivity to a derived quantity taken with its
own derivation held fixed answers a counterfactual no plant can undergo. That
report reaches it through the vulnerability curve; leaf mass per area is the same
shape and a larger instance.

The second is an invariant on instruments rather than on interfaces. **Any
perturbation that claims to referee a column must move exactly one carried
parameter.** A reference that perturbs the input a derivation reads moves several,
and then it is measuring a directional derivative while the column is a basis
vector. Both are finite, plausible and the same sign. The check is one comparison of
the carried set before and against after, it costs nothing, and it fails loudly
where the alternative fails silently.

---

## 2. Construction: what is derived once is derived without derivatives

A strategy's dependent quantities are resolved once, before any trajectory, and
report 01 §2.3 is right that they must be: the derivation runs a root-find and
builds interpolators, and doing that per cohort per stage is millions of each. The
consequence is that **construction happens in plain arithmetic, and an active
strategy receives its results rather than recomputing them.**

Anything received that way has a derivative of exactly zero, on every
differentiated path at once. That is the shape this whole corpus fears — an exact
zero is indistinguishable from a channel the model does not have — and here it
arises from a decision that is otherwise correct.

Three derived quantities matter, and they are not in the same position:

| quantity | why it is derived | what its zero costs |
|---|---|---|
| the crown constant | one closed-form line in the crown shape | nothing today: the crown shape carries no row (report 06 §11) |
| the seed's leaf area | the allometry evaluated at the seed height | §3 |
| the seed height | an implicit condition, solved numerically | §4 |

**The distinction that decides tractability is declaration, not difficulty.** A
quantity declared at the active scalar and merely *given* a passive value can be
recovered by deriving it where the parameters are live. A quantity declared `double`
cannot be recovered at all without changing its type. The crown constant and the
seed's leaf area are the first kind; the seed height is the second.

### 2.1 Where a derived quantity is re-formed decides whether it carries anything

This is the requirement that is easiest to satisfy incorrectly, and satisfying it
incorrectly produces no error and no change in any number.

The parameters become differentiable inputs at a definite moment: when they are
seeded. A derived quantity re-formed **before** that moment reads their values and
returns a constant, exactly as copying it would. A derived quantity re-formed
**after** it carries the chain.

So "derive it instead of copying it" is not sufficient guidance. The derivation must
sit inside the recording, downstream of the seeding — and the natural place to put
it, the point where the active strategy is built from the plain one, is upstream of
the seeding and therefore the one place it does not work. The failure is total and
silent: the row stays exactly zero, the value is unchanged, and every check that
compares the two differentiated paths agrees, because both were built the same way.

**The test is not that the quantity is derived, but that its row is non-zero.**

### 2.2 A derived input the receiver cannot check

Report 02 §4 item 7 states the general form: where a boundary takes a quantity the
caller computed rather than the thing it was computed from, the convention is shared
and only the caller can see it. Construction is that hazard one level up. The
recorded step receives the seed's quantities as numbers, and nothing in it can tell
whether they were derived at the current parameters or at some earlier ones. The
assertion belongs where the derivation's inputs are still visible.

---

## 3. The seed's leaf area

The allometry gives leaf area from height, and the seed's leaf area is that
expression at the seed height. **The two allometric constants are the only carried
parameters with a non-zero partial here at fixed height**; every other parameter
reaches leaf area through height alone, and height at the seed is a separate matter
(§4).

So this channel is narrow — two columns — and it is not small in principle: the
seed's leaf area sets the scale in the establishment probability's threshold and
enters the production evaluated at birth size, so it reaches the census through the
inflow boundary rather than through any cohort's rates.

Measured, on the leaf-area census at four tenths of a year: recovering it moves
the two allometric constants by about **0.3 percent** and moves nothing else at all.
That is the correct order for a channel that acts once per introduction against a
census dominated by accumulated growth, and it is three orders below the
discrepancy of §4 — which is the point of reporting it. **A channel can be real,
correctly derived, and still not be the explanation for the thing it was recovered
to explain.**

---

## 4. The seed height, which is the material one

The seed height solves an implicit condition: the height at which a plant's live
mass equals the seed mass. Its inputs are the parameters that set leaf, sapwood,
bark and root mass — eight of them.

### 4.1 The condition, not the search

A bracketing search for this height is affine in its bracket and blind to the
residual's values, so recording the search returns the derivative of the **bracket**
rather than of the height at which the condition holds. That is report 02 §1's
ruling — a search is not a definition — applied to construction instead of to the
leaf's operating point, and it has the same remedy: differentiate the condition.

With `F(h; \varphi) = \text{mass}_{\text{live}}(h;\varphi) - \omega`, the implicit
function theorem gives

$$\frac{\partial h_0}{\partial\varphi} = -\left(\frac{\partial F}{\partial h}\right)^{-1}\frac{\partial F}{\partial\varphi}$$

which needs one derivative of the residual and one divide, both of which the forward
model already has. There is no accuracy-versus-cost trade here, and the same
construction serves the seed's leaf area, which depends on the height it returns.

### 4.2 What imposing it to zero costs, measured

Setting this derivative to zero is a claim about the model: **that every species
begins at the same size whatever its traits.** Seed size and establishment size are
themselves traits and covary with the leaf and wood economics being differentiated,
so the claim is false, and what remains is how false.

Priced against a reference that rebuilds the strategy from its parameters — the only
instrument that does not inherit the imposition — on the leaf-area census at four
tenths of a year:

| carried parameter | column / rebuild | seed-height slope |
|---|---|---|
| leaf mass per area | 0.885 | −0.54 |
| wood density | 0.901 | — |
| the sapwood constant | 0.895 | — |
| the first allometric constant | **2.18** | +0.067 |
| the second allometric constant | **2.73** | −3.12 |

Three readings, and the third is the one that matters.

**The parameters that reach birth size only through the height cluster tightly**, at
0.885 to 0.901 — a common channel worth about eleven percent at this run length,
falling as accumulated biomass comes to dominate the census. It reaches about one
and a half percent by four years.

**The two allometric constants do not join that cluster**, and they are on the other
side of one. They carry the seed's leaf area as well as the height, and the second
of them moves the seed height about six times more than leaf mass per area does.

**The discrepancy is present with a single cohort and is flat in time.** It is
therefore not demographic: it does not need an introduction, it does not accumulate,
and it will not be found by any check that varies the stand. That is what makes a
rebuilding reference the only instrument for it, and what makes its size — a factor
of two to three on two columns — the largest known error in the gradient.

### 4.3 Only one instrument can see it

A forward tangent imposes the same equation the sweep does, so the two agree here
for free and the agreement reads as a pass. This is report 08 §1.1's requirement in
its sharpest form: **the question to ask of a reference is not only which code it
traverses but which of the object's declarations it inherits.** A declared zero
needs a reference that does not declare it, and a whole-run difference over a
rebuilt strategy is that reference.

Its cost is two model runs per column and its validity is per-fixture rather than
assumed — at production a relative step in leaf mass per area moves a mature stand
between alive and identically zero — so it is a shortlist instrument, and the
shortlist is the eight parameters this section is about.

---

## 5. The introduction

The inflow boundary builds a plant from §2's results, and it is the one place in the
model where a plant's whole physiology is evaluated outside the cohort loop.

**Three channels reach the census from here**, and report 05 §10 enumerates them:
the density the boundary condition sets, the initial reserve — a parameter times the
storage capacity, so how well a seedling is provisioned is a real establishment
strategy and enters nowhere else — and the seed height of §4.

**The map is checkable and the check is strong.** The introduction is a function
from the pre-introduction state and the parameters to the widened state, and it can
be formed entirely and compared forward against reverse. A map verified that way
carries no first-order error.

**What a verified map does not cover is its application.** Recording the boundary
condition at an active scalar and taking one vector–Jacobian product delivers the
state rows and the parameter rows together, which is the right construction; but
which output adjoints seed it, and how the incoming adjoint is narrowed across the
widening, are separate decisions that the map's own Jacobian says nothing about.
Report 01 §5 states the narrowing requirements; the seeding is the weaker link,
because an accumulator written and never consumed is indistinguishable by
inspection from a channel that was forgotten.

**And one observation here is not explained.** On a single-species stand carrying
two cohorts, the two allometric constants disagree between the two differentiated
paths by about `1.3e-04` **one step after the first introduction** — essentially the
whole of the disagreement, present immediately rather than accumulated — while the
extinction coefficient at the same point is seven orders smaller. Beyond that onset
the disagreement grows with run length and saturates, and that growth is *not*
specific to these columns: the extinction coefficient's own residual grows by a
factor of forty over the same range, from round-off to round-off.

So the onset and the growth are different phenomena, and only the onset is a defect.
It is localised to the introduction and to the two parameters that read the
allometry at fixed height, and **no mechanism for it is established.** Stated here
because the localisation is worth recording and the explanation is not yet available
to be recorded.

---

## 6. How this is resolved

Two of the three subjects have a construction; the third has a measurement and no
mechanism, and the order below follows that difference rather than the order of the
sections above.

### 6.1 The seed's quantities: supply the derivative, do not change the type

The obvious route is to declare the seed height at the active scalar and solve its
condition there. **It is the wrong route, for two independent reasons.** Preparation
is refused at an active scalar deliberately — it runs a root-find and builds
interpolators, and report 01 §2.3 is right that this must not recur per cohort per
stage. And the seed height is read by an interface that must return plain values, so
widening its type propagates outward for no gain.

The right construction is the one the leaf already uses. Compute the derivative in
plain arithmetic from the residual, then **graft** it:

$$\tilde h_0 = h_0 + \sum_i \left(\frac{\partial h_0}{\partial\varphi_i}\right)\big(\varphi_i - \mathrm{passive}(\varphi_i)\big), \qquad \frac{\partial h_0}{\partial\varphi} = -\left(\frac{\partial F}{\partial h}\right)^{-1}\frac{\partial F}{\partial\varphi}$$

with `F` the residual of §4.1. Report 05 §8 gives this construction and its three
preconditions: the value is exactly `h_0` because every bracket vanishes, the
recorded derivative is the supplied one, and it serves a forward tangent and a
reverse sweep alike. It costs one derivative of live mass in each of the eight
directions, one in the height, and eight divides — all of which the forward model
already has, since live mass is the sum whose root defines the height.

Three things this settles at once:

**It puts the derivation where the parameters are live.** The graft is formed inside
the recording, so §2.1's requirement is met by construction rather than by care. This
is the whole reason to prefer it over re-deriving the quantity: a re-derivation has
to be *placed* correctly and a graft cannot be placed incorrectly — outside a
recording every bracket is zero and the expression collapses to the value it already
had.

**The seed's leaf area follows and must not be done separately.** Once the height
carries its derivative, the allometry evaluated at `\tilde h_0` picks up both the
direct partial of §3 and the height's own chain. Recovering the leaf area alone,
against a height still held fixed, produces a quantity that is neither the derivative
at fixed height nor the total — the two channels of §4.2's split, mixed. **They are
one change.**

**The finiteness test belongs on the partials, before they meet the brackets.** A
non-finite supplied partial poisons the *value*, not only the adjoint, because
`NaN × 0` is not a number, and there is nowhere downstream to catch it (report 05
§8).

The crown constant is the same class and waits: it is recoverable the same way and
has no consumer, because the crown shape carries no row.

### 6.2 The parameterisation: assert the invariant, defer the map

`J` stays deferred on report 07 §3's terms — it is a post-multiplication and cannot
be validated before the gradient it post-multiplies. What does not wait is §1's
invariant, because it costs one comparison and it is what keeps a reference honest:
**any perturbation refereeing a column must move exactly one carried parameter**, and
one that moves several must refuse rather than return a number.

That is enough to make the columns' meaning stated rather than assumed. Naming which
carried parameters a derivation fixes is a reporting change, not a machinery one, and
belongs beside the columns.

### 6.3 The introduction: instrument before deciding

§5's onset has a localisation and no mechanism, so the next step is measurement and
not a change. Two things distinguish the candidates, and neither has been run:

**Introduction count against duration.** The onset is measured at one introduction
and its growth at a fixed schedule stretched in time. If the total scales with the
number of introductions, a production schedule's error is set by the schedule; if
with duration, by run length. These predict different things at a hundred years and
the experiment is one sweep over schedules at fixed lifetime.

**The seeding of the boundary condition's own product.** The boundary node
accumulates more adjoints than the vector–Jacobian product consumes. Reading the code
suggests the unconsumed ones are redundant rather than dropped, because the trait
rows are delivered elsewhere first — but that is an argument, and §5's onset is
exactly what such an argument would fail to see. **Switch each unconsumed accumulator
into the seed and require the residual to move or the row to be provably redundant.**

Only then is there a defect to fix, or an exclusion to record.

### 6.4 Order, and what counts as resolved

**§6.1 first**, because it is the material one — a factor of two to three on two
columns and about ten per cent on six more, at every stand age — and because it is
understood well enough to build. **§6.2's invariant beside it**, since it is an
assertion rather than a construction. **§6.3 last**, because it is small, not
understood, and its diagnosis may change what a fix would even be.

The acceptance criterion for §6.1 is not that a test passes. It is that the split of
§4.2 collapses: the eight parameters must come to agree with a rebuilding reference
to that reference's own step-stability, with **no group standing apart from the
others**, and the two allometric constants in particular must stop being a separate
population. A partial improvement that leaves them separate means a channel is still
missing, and §7's third falsifier is where to look.

---

## 7. What this asks of a strategy author

**1. Say which of your parameters are derived from which.** A derivation among
carried parameters is invisible in the parameter list and changes what every column
means. It belongs stated at the boundary, and until it is expressible as a map, the
columns must be read as carried-parameter rows and labelled as such.

**2. Derive a quantity where its inputs are live, not where it is convenient.**
Re-forming a derived quantity upstream of the point at which the parameters become
differentiable inputs produces a constant, silently, and changes no number (§2.1).

**3. Expose the residual of an implicit derived quantity, never the search.** This
is report 02 §1's rule, and construction is where it is most easily forgotten
because the search runs once and looks like setup rather than like model.

**4. A declared zero is a claim about the model and needs a number beside it.** Not
a justification — a measurement, from an instrument that does not share the
declaration, quoted with the run length it was taken at.

**5. Enumerate the boundary's channels from the equations, not from the code path.**
The initial reserve is the instance: it is a real establishment strategy, it reaches
the census through no other route, and it was missed by an enumeration that declared
itself complete.

---

## 8. What would falsify this

- **The seed height's derivative is not recoverable from its residual.** If the live
  mass is not monotone in height over the bracket, or its derivative vanishes at the
  root, the implicit-function route fails and §4.1 needs a different construction.

- **The cluster in §4.2 is not one channel.** Three parameters agreeing to two
  percent is the evidence that the height is a common channel and the allometric pair
  carries something extra. Widen the shortlist to all eight: if the remaining five
  scatter, the reading is wrong and the two groups are not what §4 says they are.

- **The allometric pair's excess is not the seed's leaf area.** Recovering that
  channel moves them by 0.3 percent against a discrepancy of over a hundred, so
  most of their excess is unaccounted for even granting §3. Either the seed
  height's own channel is far larger for these two than the cluster suggests, or a
  third channel exists at the boundary.

- **The introduction onset scales with introduction count.** §5's onset is measured
  at one introduction and its growth at fixed schedule. If it is per-introduction,
  a production run's total is set by the schedule rather than by duration, and the
  extrapolations from short fixtures are wrong in the other direction.

- **A row recovered by deriving a quantity at live parameters reads exactly zero.**
  Then the derivation is upstream of the seeding and §2.1's requirement has been
  satisfied in form only.
