# What the leaf must supply, and why almost none of it is hard

The leaf is the one place in TF24 where a rate is not a closed-form function of state
and traits, so it is the one place a derivative is supplied rather than recorded.
Report 02 states why the node has that shape and what a boundary carrying it must
guarantee. This states **which derivatives the boundary actually needs**, input by
input, and what is missing.

It is written to be acted on. Where it says a quantity is exact, that is a claim about
the mathematics and it is checkable at one solved point. Where it says a quantity is
written but unreachable, that is a claim about the code and `grep` settles it.

---

## 1. Two channels leave the leaf, and only one of them is difficult

The boundary carries exactly two kinds of output, and they go to different places.

**Profit** is one number. It scales by leaf area into net production, and net
production drives every rate the demography has: height, fecundity, both heartwood
accumulators, the reserve, and mortality through the reserve.

**Per-layer uptake** is one number per soil layer. It is what a cohort writes into the
shared soil, and it is the whole of the water feedback.

Now apply the envelope theorem. Profit is the objective at its own maximiser, so

$$\frac{\mathrm{d}\Pi^\star}{\mathrm{d}u} \;=\; \frac{\partial\Pi}{\partial u}\bigg|_{p} ,$$

with the operating point's motion contributing nothing. Uptake is set *at* that point
rather than being it, so

$$\frac{\mathrm{d}E_i}{\mathrm{d}u} \;=\; \frac{\partial E_i}{\partial u}\bigg|_{p} \;+\; \frac{\partial E_i}{\partial p}\,\frac{\partial p^\star}{\partial u} .$$

**So the carbon channel needs no derivative of the operating point at all**, and the
water channel needs all of it — the condition's gradient, the curvature it is divided
by, the fold guard on that quotient, and the refusal where the quotient does not exist.

That is the single most useful fact about this boundary. **Every hard thing in it exists
for the water feedback and for nothing else.** Delete the feedback and the leaf becomes
a graft of held partials with no implicit function theorem anywhere. Keep it — and
report 06 says competition in this model is two-sided precisely because it is kept —
and the difficulty is exactly the price of keeping it.

### 1.1 The two channels are a derivation, and this is it

The section above *asserts* the output set. Report 02 §3.0 requires it to be **derived from the
consumer's equations**, and the difference is not pedantic: a set read off what a caller happens to
request is the same tunnel vision one level out, and it cannot distinguish a complete set from a
caller's oversight. So, consumer-inward.

**A census never reads the leaf.** The three metrics are leaf area, above-ground mass and stem area —
functions of height and of the traits. So report 05 (9.2)'s direct term has no leaf in it, and the leaf
enters the trait gradient through exactly one of that document's six paths: the recorded cohort step.

**That step has twelve outputs, and they read the leaf through two quantities.** Six rates, the density
rate, and one uptake per soil layer. Tracing each:

| output | what it reads the leaf through | why nothing else |
|---|---|---|
| the six rates, and the density rate | **profit**, and only profit | net production is assimilation minus respiration minus turnover; assimilation is profit times leaf area, and the other two are functions of the tissue masses |
| the $L$ per-layer uptakes | **per-layer uptake**, and only that | evapotranspiration is that layer's draw times leaf area |

**So the set is $\{\Pi, E_{1:L}\}$, derived.** That it coincides with what the one consumer asks for is
a check on the consumer, not the derivation — and it is what licenses the row layer to refuse the other
three outputs by name. The refusal is right *because of the enumeration*, and it would be wrong for any
consumer one of whose rates read a leaf output the enumeration does not name.

**One further leaf-fed quantity is live and it is easy to miss, because it is not one of the twelve.**
The establishment probability reads net production at the boundary node, so it reads profit — and
through it the density boundary condition of report 05 (4.2). Report 05 §6.2 names this as the place a
moisture dependence is most easily lost, since a boundary node taking its potentials from a cache has
no visible dependence on moisture at all. It is not lost here: the quantity is carried as an active
scalar precisely because it is a rate's *input* rather than a reading of one, and that is the one
distinction to preserve if that code is ever reorganised.

**And the state side is the reciprocal statement, which §3 half-makes.** A cohort's own height has **no
leaf input at all**. It reaches the leaf only through the maximum leaf-specific conductance and each
layer's root carbon per unit leaf area — both computed *actively* by the consumer and handed over as the
values the rows are recorded against — and through leaf area, which multiplies profit outside the leaf
entirely. That is report 05 §8's third precondition seen from the model's side: the supplied partials
are functionally independent **at this cut**, even though several are functions of height further
upstream, and choosing the cut there is what makes the graft's arithmetic valid. **The leaf never needs
a derivative in a cohort's state, and that is a property of where the cut was put rather than a
convenience.**

### 1.2 Three things this classification is silent about

None is a defect, and each is silent in the way report 04 warns about — an absence that reads like an
answer.

**The leaf reads six atmospheric quantities and only one of them has a row.** Radiation has one;
vapour-pressure deficit, ambient CO₂, leaf temperature, oxygen and atmospheric pressure have none, and
neither the environment nor the strategy offers a column for them. **That asymmetry is correct and the
reason is worth stating**: radiation is not merely a driver, it is what the shared light *field*
delivers, so a reduction transposes onto it and its row is what closes that transpose. The other five
are exogenous, shared with nothing, and returned as plain doubles — a type that cannot carry a
derivative, which is report 05 §6.1's own prescription rather than an oversight. So the census gradient
needs none of them. What cannot then be asked is the *other* question — "what if it were drier, or
hotter, or CO₂-richer" — and that is the same shape as report 05 §6.2's soil parameters, which it
records and this document did not.

**Seven leaf outputs are reported as diagnostics and carry structural zeros.** The stem potential, the
collar, transpiration, total uptake, profit, stomatal conductance and assimilation are written out for
inspection. At an active scalar each is assigned from a `double`, so the assignment is a legal widening
that drops the derivative — every one of them reads exactly zero on a tangent or a sweep. Their
consumers are R-facing and no census reads them, so nothing is wrong; what is missing is the
*declaration*, because report 04's rule is that an imposed zero is indistinguishable from a channel the
model does not have. **A consumer who censused one of these would get a clean zero.**

**Both critical potentials are derived defaults, so their columns and the curve parameters' columns
answer slightly different questions than they look like.** Each is set at construction from its own
curve's position and steepness; afterwards they are independent, so the gradient reports the curve
parameter's row at a **held** critical potential — a partial, where a reader who believes the
derivation would expect the total. Report 05 §7.6 states the test for exactly this ("does the
perturbation carry the derived quantity to where a rebuild would have put it") and applies it to a
grid; it applies unchanged to a parameter. The convention is the caller's to assert, by report 02 §4
item 7, and it is stated in neither place.

---

## 2. The solve has three implicit relations and the consumer needs one of them

Reading the solve from the outside in:

| level | what is solved | how | does the consumer need its derivative? |
|---|---|---|---|
| bounds | the wet bound $p_a$: total uptake vanishes | root-find on $E^{\mathrm{up}}(x)=0$ | only at a pin |
| bounds | the dry bound: the stem reaches its critical potential, or the root's own | root-find, or a registered constant | only at a pin |
| **L1** | the operating point $p^\star$ | root-find on $\partial\Pi/\partial p = 0$ | **yes — for uptake** |
| L2 | the stem potential $\sigma$ | **not a solve**: $\sigma = P\!\left(E^{\mathrm{up}}/\kappa + S_t(p)\right)$ | as a chain, not a theorem |
| L3 | intercellular CO₂ $c^{\mathrm{i}}$ | root-find on supply = demand | yes, but it is an *explicit algebraic* residual |

Two things follow and both are load-bearing.

**L2 is explicit.** The stem potential is a spline read of a sum, not a root-find. So the
transport is a chain rule, and it was differenced only because that chain was written
through the *inverted* table's slope — section 6, where taking it from the flux balance
instead removed the difference and the inverse's derivative together.

**L3's residual is algebraic and given in closed form.** So its implicit function theorem
can be applied twice as cheaply as once, which is what section 5 needs. The inner solve
is opaque in *value* and transparent in *structure*, and those are different things.

---

## 3. The census: twenty-six inputs, six routes

Every input crosses the boundary by exactly one of six routes. Which route it takes
decides what its row is, and the routes are not equally hard.

| route | inputs | count |
|---|---|---|
| **A — the waist** | the soil potentials, each layer's root carbon | 2L (10 at L=5) |
| **B — assimilation only** | radiation, `vcmax_25`, `jmax_25`, quantum yield, both curvature factors, `R_d_25` | 7 |
| **C — the hydraulic cost only** | `beta2`, the cost scale | 2 |
| **D — the stem transport curve** | maximum conductance, `stem_b`, `stem_c` | 3 |
| **E — the root transport curve** | `root_b`, `root_c` | 2 |
| **F — a bound and nothing else** | the stem's critical potential, the root's own | 2 |

Leaf area is **not** on that list, and its absence is a result rather than an omission.
Report 05 §7.3 counts $2L+1$ state directions, the third being leaf area — but root
carbon and the maximum conductance both arrive at this boundary already divided by it,
so leaf area's whole channel is the consumer's own multiplication of profit by area and
is *recorded*. The boundary sees $2L$, not $2L+1$.

### Route A — the waist, and the one thing that is genuinely missing

At a **fixed** operating point the soil state reaches the stem potential, the
intercellular concentration, assimilation, conductance and profit through **total uptake
alone**. This is measured, not assumed: moving two layers so that total uptake cancels
to first order shrinks every one of those outputs by five and a half orders while the
per-layer draws move at full first order. So the held block over route A is

$$\frac{\partial y_j}{\partial u}\bigg|_p \;=\; \underbrace{\frac{\partial y_j}{\partial E^{\mathrm{up}}}}_{\text{one number per output}} \cdot \underbrace{\frac{\partial E^{\mathrm{up}}}{\partial u}}_{\text{one vector, closed form}} ,$$

which is $n_{\text{output}} + n_{\text{input}}$ numbers where the block has their product.
**Per-layer uptake is the exception, and it is the informative one:** $E_i$ is what the
supply *produces* rather than something the leaf reads, so its row is the supply's own
Jacobian — diagonal in the potentials, lower-triangular in the layer carbons.

Route A's contribution to the **condition's** gradient was the last thing this document had
to settle, and the rest of this section is how it was settled.

**Say what the condition is first, because the rest follows from it.** The collar reaches
assimilation only by moving water and reaches the hydraulic cost only by moving the stem
potential, so

$$R \;=\; \frac{\partial A}{\partial E^{\mathrm{up}}}\,S \;-\; C'(\sigma)\,V ,$$

the carbon bought by the water an extra unit of collar pull draws, against the cost of the
extra tension that pull puts on the stem. At the optimum the two are equal and $R$ is zero,
which is TF24's first-order condition written in the two quantities the ecology weighs.
Verified away from the optimum, where the two are *not* equal and the identity has something
to say, it holds to $4\times10^{-7}$.

Four things move under a state direction, then — the flux, the flux's collar slope, the stem
potential and its collar slope — and the leaf supplies one coefficient for each:

$$\frac{\partial R}{\partial u} = \underbrace{\frac{\partial^2 A}{\partial E^2}S}_{\delta E}\;+\;\underbrace{\frac{\partial A}{\partial E}}_{\delta S}\;-\;\underbrace{C''(\sigma)V}_{\delta\sigma}\;-\;\underbrace{C'(\sigma)}_{\delta V}.$$

**That is the shape every input shares, and which pair of the four an input moves is the whole
classification.** Six physical routes; four shapes of row:

| shape | inputs | what the input supplies |
|---|---|---|
| moves the **flux** pair | A (10) + E (2) | $\delta E$, $\delta S$ — and the transport turns those into $\delta\sigma$, $\delta V$ |
| moves the **tension** pair at a frozen flux | D (3) | $\delta\sigma$, $\delta V$ — off the mass balance, with the carbon half identically zero |
| moves **neither** | B (7) + C (2) | a kernel partial, already written |
| moves **nothing** | F (2) | zero, by inactivity |

Read that table rather than the route list, because it is the shorter statement and it is the one
that decides the code. **Twelve inputs enter through the flux and reach everything else through the
transport; three enter the transport directly and cannot touch the flux; nine reach a kernel and no
water at all; two reach nothing.** The routes are the ecology's names for those four; the shapes are
what a row layer has to be able to say.

Written in the older pair the same statement is this, and it is the form the rank test sees:

$$R \;=\; G(\sigma)\,V \;+\; H(\sigma), \qquad V = \frac{\partial\sigma}{\partial p}, \quad G = \frac{\partial\Pi}{\partial\sigma}, \quad H = \frac{\partial A}{\partial c^{\mathrm{i}}}\cdot\frac{\partial c^{\mathrm{i}}}{\partial p}\bigg|_\sigma ,$$

so $\partial R/\partial V = G$ and $\partial R/\partial\sigma = G'V + H'$.

**Take those two in $(\sigma, V)$ and in no other pair.** The obvious alternative — total
uptake and its collar slope — is short by $H$, because transpiration is the stem
integral's *difference* between the stem potential and the collar, so the collar reaches
stomatal conductance directly as well as through $\sigma$. A row built on that pair is
still rank two, still reproduces every out-of-sample supply direction, and is wrong by
whatever $H'$ contributes. **The rank test cannot separate the two pairings.** What
separates them is whether the coefficient claimed to be closed form agrees with a
difference of the condition itself — and that is the check to run before anything is
built on either.

$\partial R/\partial V$ is free: it is the profit's stem-potential derivative, which the
forward solve forms anyway. $\partial R/\partial\sigma$ is the one new number.

**Built, and what is wrong with it is one number.** Take the differenced condition rows over
all $2L$ inputs and least-squares them onto the two supply vectors. That separates three
claims which a single comparison confounds: the residual tests the two vectors and the claim
that there are only two, the fitted scalars against the closed-form ones test the closed
forms, and the Gram's condition number says whether the fit could tell the two apart at all.

Measured at eight states, the residual is $10^{-9}$, the condition number is 14 to 37, and
$\partial R/\partial(\partial E^{\mathrm{up}}/\partial p)$ agrees with its fit to $10^{-9}$.
So the waist is two-dimensional, the two directions are *not* collinear — an earlier reading
of this boundary held that they were — the supply vectors are exact, and one scalar is
exact. **The remaining error is entirely $\partial R/\partial E^{\mathrm{up}}$**, and it is
$5\times10^{-6}$ to $5\times10^{-5}$ where everything around it is $10^{-9}$.

That scalar is the only one carrying $P''$, the second derivative of the *inverted* transport
table. So it is grid error, and it converges on the closed form rather than away from it —
$4.8\times10^{-4}$ at 400 knots, $4.6\times10^{-5}$ at 800, $4.5\times10^{-7}$ at 6400. On a
stand, measured on one build with only the dispatch changed, the water channel's worst
per-layer residual against a re-solved difference is $1.8\times10^{-4}$ reading against
$4.2\times10^{-7}$ differencing.

**And $P''$ should never have been reached for.** Section 6 is where that decision was taken
and section 6 was wrong: the fix is not a better tabulated derivative, it is not reading a
tabulated derivative at all. With $V$ taken from the flux balance the scalar above stops
carrying $P''$ and joins the rest — $3\times10^{-9}$ against the $5\times10^{-5}$ recorded
here. **The two paragraphs above are kept as the measurement that located it**, not as a
live defect: a grid-error reading that converged on the closed form is what said the row
was right and the route was wrong.

### Route B — assimilation only, and every row already written

At a fixed collar these inputs move nothing but assimilation: the stem potential, the
stomatal conductance and the hydraulic cost are all fixed, and the only thing that
responds is the intercellular concentration the residual places. So with
$g_{c^{\mathrm{i}}} = A'\,\mu + g_c/P$ and $K = (c_a - c^{\mathrm{i}})/(P g_{c^{\mathrm{i}}})$,

$$\frac{\partial c^{\mathrm{i}}}{\partial\theta} = -\frac{(\partial A/\partial\theta)\,\mu}{g_{c^{\mathrm{i}}}}, \qquad \frac{\partial\Pi}{\partial\theta}\bigg|_p = \frac{(\partial A/\partial\theta)\,g_c/P}{g_{c^{\mathrm{i}}}}, \qquad \frac{\partial R}{\partial\theta} = \frac{\partial A'}{\partial\theta}\,D\,K + A'\,D\,\frac{\partial K}{\partial\theta} ,$$

with $D$ the collar's route into the conductance, which carries no trait. **Their uptake
rows are exactly zero**: at a fixed collar a carbon-side trait moves no water.

Six traits, four seeded passes, because the family shares its intermediates — the
quantum yield, the electron-transport curvature and `jmax_25` reach assimilation only
through the electron transport, so one pass in that direction serves all three.
Dark respiration needs no pass at all: it is subtracted from the colimitation, so
$\partial A/\partial R_d$ is exactly $-1$ and the mixed second partial is exactly zero.

**All seven rows, held and condition, are already implemented.** Radiation's is
`Leaf::dprofit_dPPFD()`. The other six are `Leaf::photo_trait_rows()`, which obtains
$A''$ and the mixed partials by seeding the assimilation kernel twice under nested
forward mode. **Read at an interior point and at a pin**, once per request rather than
once per input, because the family shares its intermediates.

### Route C — the cost only

These two reach profit through the hydraulic cost and through nothing else: not the
concentration residual, not the supply, not the operating point at a frozen collar. With
$q = 1 - f(\sigma)$ and $C = \text{scale}\cdot q^{\beta}$,

$$\frac{\partial C}{\partial\,\text{scale}} = \frac{C}{\text{scale}}, \quad \frac{\partial C}{\partial\beta} = C\log q, \quad \frac{\partial C'}{\partial\,\text{scale}} = \frac{C'}{\text{scale}}, \quad \frac{\partial C'}{\partial\beta} = C'\left(\frac{1}{\beta} + \log q\right).$$

Uptake rows exactly zero, for route B's reason. **Both rows already implemented**, in
`Leaf::cost_trait_rows()`. **Read beside route B's**, off the same seating.

### Routes D and E — the two vulnerability curves

These change the transport at fixed uptake and fixed collar, so they move everything
downstream of $\sigma$. Each curve needs its value's derivative in each of its two
parameters, and the two parameters are not equally easy — but both are exact.

**Position is an identity.** The cumulative integral is homogeneous of degree one in
$(\psi, b)$, so Euler gives $b\,\partial G/\partial b = G(\psi) - \psi\,G'(\psi)$
identically, on the *tabulated* $G$ and $G'$ rather than on the continuum. No rebuild,
no difference. Implemented for both curves.

**Steepness is a series, not a measurement.** No rescaling of the base curve reproduces
the curve at a moved steepness, so the homogeneity route is genuinely unavailable — and
that is where this corpus previously concluded the grid must be rebuilt and the answer
differenced. **That conclusion was wrong.** Writing $a = 1/c$ and $x = (\psi/b)^c$, the
lower incomplete gamma's shape derivative

$$\frac{\partial\gamma}{\partial a} = \log(x)\,\gamma(a,x) + x^a e^{-x}\sum_{n\ge0}\left(-t_n\sum_{l=0}^{n}\frac{1}{a+l}\right)$$

comes out of the **same loop as the value**, for the cost of one extra accumulator, and
chains to the steepness through $\partial a/\partial c = -1/c^2$. It is implemented, it
is bounded — the grid ends where the vulnerability function reaches a fixed small
fraction, so $x = \log(1/\text{fraction})$ identically for every $b$ and every $c$, and
the series never meets the regime where its terms would overflow — and it is read in
**three** places: the stem's transport rows, the root curve's supply rows, and each bound's
row in either steepness. It was wired into nothing, by a comment that said so.

The maximum conductance is the easy member of route D: it enters as $E^{\mathrm{up}}/\kappa$
and its rows are elementary.

### Route F — slack, and that is the whole answer

Both critical potentials are read by a bound's residual and by nothing else. The flux
integrates the vulnerability curve up to the stem potential the plant is *operating* at,
not up to a critical potential, and the hydraulic cost does not read a critical potential
at all. So at an interior optimum the constraint is inactive, the whole row is exactly
zero, and it goes live at a pin where the bound's own row supplies it.

**Both, not one.** An earlier form of this reasoning granted slackness to the root's
critical potential alone and called the stem's a structural zero, on the ground that the
flux integrates the stem curve up to it. It does not.

**And a third state, which is what makes "slack" the right word rather than "zero".** At a
hydraulic shutdown the plant is operating *at* the stem's critical potential —
`set_shutdown_state` seats it there — so that input is not read by a bound's residual but by
the hydraulic cost itself, and its row is $-C'(\psi_{\text{crit}})$.

**Which is why "a shut collar" is not one state.** The other zero-flux kind seats both
potentials at the collar of zero uptake, and there the flux integrates up to *that* and the
critical potential is inactive again — so the same input is slack on one zero-flux branch and
the seat on the other. Three answers over four states, one input: inactive at an interior
optimum and at shade death, a bound's argument at a pin, the seat itself at a hydraulic
shutdown. **The seat is what decides, and it is a fact about the branch rather than a
comparison on the potentials** — which is why reading it off the recorded seating is what
makes the wrong answer inexpressible.

And a slack zero is not a structural zero: a structural zero claims the input reaches
nothing on any trajectory, where a slack zero says it goes live the moment the constraint
binds. Recording one as the other tells a reader the model has no answer where it has a
state-dependent one.

---

## 4. So the tally is this

At an interior point, by route:

| route | inputs | what the row is | against a difference |
|---|---|---|---|
| A — the waist | 10 | the leaf's coefficients on the flux times the supply's Jacobian | $10^{-9}$ |
| B — assimilation | 7 | the kernel's own partials, four seeded passes | $10^{-9}$ |
| C — the cost | 2 | the cost kernel's, elementary | $10^{-9}$ |
| D — stem transport | 3 | the cost alone: the flux is frozen | $10^{-9}$ |
| E — root transport | 2 | route A's, with the curve's supply derivative | $10^{-9}$ |
| F — the bounds | 2 | declared zero, by inactivity | exact |

And by branch, because the routes are the interior point's and the other two branches
answer differently:

| branch | how the 26 are answered | against a difference |
|---|---|---|
| interior | six routes above, every input read or declared | $10^{-9}$ |
| pinned | the same held partials; both bounds' rows carry the point, weighted by the step-in | $3\times10^{-9}$ at a wet pin, the difference's floor at a dry one |
| hydraulic shutdown | six from the cost at $\psi_{\text{crit}}$, twenty exact zeros | $5\times10^{-10}$, and the zeros exactly |
| shade death | the cost at the collar of zero uptake, plus the supply's own Jacobian, plus the wet bound's movement | $1\times10^{-6}$ |

**Four branches, not three**, and that is §12's first item: the two zero-flux kinds pay the same two
terms at two different potentials, and one of them reads the soil through its seat while the other
reads no soil at all.

**All twenty-six, on every branch a solve can land on, and none of them measured.** The
count this paragraph used to carry — eleven written, five needing one derivative order, ten
through the waist — was a snapshot of what was left, and the two tables above replace it.
What is worth keeping from it is which ten were the hard ones, because they are the ones
this document was wrong about. What made the last five reachable was not a
new derivation but section 6's correction: every one of them differentiates the flux
balance, and while the forward model took its collar response from the inverted table's
slope the two described different functions. With the model taking it from the balance too,
the transport's rows agree with a rebuilt difference to $10^{-9}$ — they had disagreed at
$1.5\times10^{-3}$, which was read as the closed form's error and was the model's.

**And the census is a census of the INTERIOR point until the same rows answer on the other
two branches.**
That distinction cost the constrained branch everything the tally claims: a pin is defined
by a bound rather than by stationarity, and because the held evaluation there could not be
*differenced* — $p^\star$ sits a step-in from the bound, so a step that moves the bound
carries it out of the perturbed interval — every input the bound moved was answered by
re-solving the whole model twice. Up to sixteen of them at five layers, thirty-two collar
solves, for rows already written.

The premise was about steps, and a closed form takes none. So the same held partial answers
at a pin, the bound's own row is what the condition's gradient carries, and the point's
movement is reported once instead of folded into every row. What that needed was two things:
each bound's row in both curve steepnesses, which the shape series already had, and a
**collar channel that exists at a pin at all** — §9's fifth bullet.

**A shut collar was worse, and simpler.** No condition defines that point, so nothing there
could be shown to leave it where it was and seventeen of twenty-six inputs re-solved — for
a profit that is two terms. Written out it is $-R_d - C(\psi_{\text{crit}})$ and nothing
else, so six inputs have a row and twenty have an exact zero, and the object supplying the
six had been written and left with no caller.

**And its own collar is not a row it has to answer for.** Nothing a shut leaf reports is a function of
its collar: profit reads the *stem* potential, which is a registered input there, and every flux is
written zero. Measured over 19,455 zero-flux points, profit is bit-for-bit $-R_d - C(\psi_{\text{stem}})$
at all of them. So the collar is a node nothing reads, and its row is needed only by a request naming the
collar as an output — a calibration's shape. Even then it is a unit vector: the seat is one of **two
registered inputs** at all 12,384 hydraulic shutdowns, and the third exit the classification's note names
is unreachable, at 0 of 12,384.

Two things fell out of writing it once rather than five times. The condition's whole
assimilation half is **identically zero** for a transport trait — the flux is frozen, and the
concentration is placed by the flux — which deletes eight quantities that had been carried
and cancelled. And routes A and E turn out to be one route: the root curve reaches the leaf
through total uptake exactly as a soil potential does, so what distinguishes them is one
closed form for that input's own supply derivative and nothing else.

---

## 5. The one requirement, stated per primitive

Report 02 §3.7 commits the design to one sentence: *every primitive the solve reads must
supply one derivative order more than the row layer consumes.* Here is what that means,
primitive by primitive, and it is short.

| primitive | value | first derivative | second derivative |
|---|---|---|---|
| stem cumulative integral $S_t$ | the tabulation | $f(\psi)$ — the integrand, elementary | $f'(\psi)$ — elementary |
| its inverse $P = S_t^{-1}$ | the tabulation | $1/f(\sigma)$ | $-S_t''/S_t'^{\,3}$, but see section 6 |
| $S_t$ in position | Euler's identity — exact | — | — |
| $S_t$ in steepness | the series' shape derivative | $\partial f/\partial c$ — elementary | — |
| root cumulative integral | the tabulation | $f_r(\psi)$ | $f_r'(\psi)$ |
| assimilation $A(c^{\mathrm{i}})$ | the kernel | one forward seed | **two nested seeds** |
| hydraulic cost $C(\sigma)$ | the kernel | one forward seed | **two nested seeds** |
| the concentration residual | a root-find in value | the theorem once | **the theorem twice** |
| total uptake $E^{\mathrm{up}}$ | a sum | closed form in every direction | the mixed partial, closed form |

**Every second derivative in that column is a derivative of an *integrand*, never of an
integral.** Differentiating a cumulative integral in its upper limit removes the
integral, so $S_t' = f$, $S_t'' = f'$, and the mixed partial in any curve parameter is
that parameter's partial of $f$ — and $f = \exp(-(\psi/b)^c)$ is elementary in all three
of its arguments. The tabulation is needed for the value and for the steepness row. For
nothing else.

So $\partial R/\partial\sigma = G'V + H'$ decomposes into things that are already
present or elementary:

$$G' = A''\left(\frac{\partial c^{\mathrm{i}}}{\partial\sigma}\right)^{\!2} + A'\,\frac{\partial^2 c^{\mathrm{i}}}{\partial\sigma^2} - C''(\sigma), \qquad H' = A''\,\frac{\partial c^{\mathrm{i}}}{\partial\sigma}\,\frac{\partial c^{\mathrm{i}}}{\partial p}\bigg|_\sigma + A'\,\frac{\partial^2 c^{\mathrm{i}}}{\partial\sigma\,\partial p} .$$

$A''$ is already obtained under nested forward mode for route B. $C''$ is one further
seed of a kernel already seeded. The concentration's second partials follow from applying
the theorem twice to an explicit algebraic residual whose own partials are
$\partial g_c/\partial\sigma = \text{const}\cdot\kappa f(\sigma)$ and
$\partial g_c/\partial p = -\text{const}\cdot\kappa f(p)$.

**Nothing in that derivation reads a table, a fit, a step size or a perturbation.**

---

## 6. Where the requirement binds — and it binds on a line that should not be there

$V = \partial\sigma/\partial p$ is computed as $P'(x)\left[\kappa^{-1}\partial E^{\mathrm{up}}/\partial p + f(p)\right]$,
so as written the design rests on $P'$ — the *inverse* transport curve's slope.

**It should rest on nothing of the kind.** The stem carries the flux the soil supplies,

$$\kappa\left(G(\sigma) - G(p)\right) \;=\; E^{\mathrm{up}}(p),$$

and that is an implicit relation like any other. Differentiating it in the collar gives

$$V \;=\; \frac{S/\kappa + f(p)}{f(\sigma)}, \qquad S = \frac{\partial E^{\mathrm{up}}}{\partial p},$$

with no inverse and no tabulated derivative in it — $f$ is the vulnerability curve itself,
elementary in $\psi$ and in both its parameters. One more derivative, in any state
direction, is elementary too:

$$\frac{\partial V}{\partial u} \;=\; \frac{1}{\kappa f(\sigma)}\frac{\partial S}{\partial u} \;-\; \frac{V f'(\sigma)}{f(\sigma)}\frac{\partial\sigma}{\partial u}.$$

**And that is the whole of the difference between a row that stands and one that does not.**
Reading $P'$ makes $V$ a *value of the interpolant*, so $\partial V/\partial u$ is the
interpolant's **second** derivative — a property of the fit, which no supplied first-order
data corrects. Taking $V$ from the balance makes $\partial V/\partial u$ elementary. Measured
against a difference of the $V$ it belongs to, at the same grid and the same states:
$5\times10^{-9}$ to $10^{-7}$ by the balance, against $3\times10^{-6}$ to $4\times10^{-5}$
by the slope. The two $V$'s themselves agree to $10^{-8}$, so this is a change of route and
not of answer.

So the tabulation is needed for $G$'s value, for the inverse's value, and for the steepness
row. **For no derivative at all** — which is what section 5's inventory said, and what
reading $P'$ quietly broke.



### What this section used to say, and the one part of it to keep

The inverse is built by handing the interpolator the cumulative integral's knot values as
abscissae and the potentials as ordinates. Two vectors. So its slope was **inferred from
neighbouring values**, and $P'$ and $1/f$ disagreed by parts in ten thousand — and the
repair taken was to supply $1/f(\psi)$ at each knot, which the same loop already forms.

**Keep that.** A $C^1$ interpolant through exact values and exact slopes has $O(h^4)$ error
in its *value*, and the inverse's value is $\sigma$, which everything reads. It also costs a
continuity class — a curvature break at every knot where a solved-slope system is $C^2$ —
and the one question that bears on was measured and answered: the argmax's second
differences in a trait stay at $3\times10^{-7}$, so smoothness of the argmax is the
constraint and the continuity class is not.

**But it was the wrong repair for the defect above, and it hid that defect one order down.**
With the slope supplied the first derivative agrees and the second still does not, because a
$C^1$ cubic's second derivative is not data — it is a difference of the data. Supplying the
curvature as well would close it, and that is unnecessary: with $V$ from the balance,
nothing reads either derivative of the inverse, and `stem_curve_integral_inverse_deriv`
loses its only caller.

## 7. What the boundary is, then

Once every row is a statement, the boundary is this and nothing more.

**The consumer solves the leaf once, in double, and asks for parts.** It hands over no
copy of the traits, because the leaf holds them; no driver set, because the leaf was
already given one; and no step size, because nothing is stepped. There is nothing to
perturb, so there is nothing to describe a perturbation with. The row layer's whole
signature is the leaf and the request:

```
Rows rows_at(Leaf& l, const RowRequest& r);
```

**Two arguments, and it does not solve.** A caller that has not solved gets a refusal
rather than a plausible number. The five arguments the row layer used to take are all
still needed — by a *different* entry point, `rows_differenced`, which is where a
perturbation lives now: it takes the traits and the drivers because an arm has to be
able to put the leaf back, and a step because an arm has to be placed. What separates
them is not a flag but an operation: **the read states what the model can state about
the state it is in, and names the rest.**

`const` is not yet on it, and the reason is one chain rather than this function.
`bound_row` probes collar potentials to place its own root-find and restores the
uptake state its probes moved, so the members it saves and restores have to become
`mutable` before the qualifier can go on. Nothing in the row layer writes the leaf on
its own account any more.

**Differencing forced three of the five, and the other two were forced by something this section used
to fold into differencing.** Re-solving is not "the same thing one step removed": the row layer
re-applied the traits and the drivers and solved again, unconditionally, on a leaf the consumer had
already solved. That is what made the leaf argument mutable and what made a trait copy and a driver
record necessary at all. What each argument took, and what removed it:

| argument | what forced it | what removed it |
|---|---|---|
| `Leaf&`, not `const Leaf&` | the row layer solved, and then seated the point so the recorded coefficients describe it | the solve now closes on the condition at the collar it returns — below. What is left is `bound_row`'s own save-and-restore |
| the trait copy | restoring base after a perturbation | moved to `rows_differenced` with the perturbations |
| the driver record | the same, **and, separately, reading the layer count and the layer carbons from it** rather than from the leaf, which holds the same network | the same, and the leaf now answers for both |
| the request | wanted | — |
| the settings | `step` for the perturbing routes, `collar` for the two differenced channels, and the curve's fast path because `apply` was called at all | the two channels are read; the routes moved |

**And three of those five were never this consumer's at all**, which is why they came off
together rather than one at a time. Report 02 §3.0 warns that a boundary built for one
consumer under-serves the other silently; it had already happened, in the direction nobody
checked. The five fixed outputs are a *calibration's* — assimilation, the stomatal
conductance, the stem potential, the collar, profit — and the two non-trait inputs are the
same consumer's, the conductance driver and the single path's series resistance. A stand
reads profit and the water each layer gave up. So:

| what looked unwritten | what it is | witness |
|---|---|---|
| a request naming assimilation or the stomatal conductance | the other consumer's outputs. The carbon readers report profit and the condition, so naming either sends every carbon-side input to a difference — which is correct, and belongs to the route that differences | the only consumer of the row layer names `profit` and the uptake block and nothing else |
| the single path's series resistance | the other consumer's input, and the other consumer's *supply*: the multi-layer path is the default and the only one a stand selects | zero callers of `set_supply_single` outside this package's own tests |
| the shut collar's own row | not an object. Nothing a shut leaf reports is a function of its collar: profit is bit-for-bit the two-term expression at the **stem** potential and every flux is written zero, so the collar is a node nothing reads | 19,455 zero-flux points, all bit-exact; and the seat is one of two **registered inputs** at all 12,384 hydraulic shutdowns |

**The third exit does not exist.** The classification's own note said a shut collar is seated
at three different potentials — the stem's critical one, the root's own, or the collar at
which the stem reaches critical — and the third is unreachable: the stem is drier than the
collar whenever flow is positive, so the collar at which the stem reaches critical is wetter
than the critical potential, and the test that would select it can only fire where the
previous exit has already fired. Measured: the searched dry bound is the seat at **0 of
12,384**. So a shut collar's row is the unit vector in one of two registered inputs, and what
is missing is a recorded bit, not a derivation — the pattern `dry_bound_arm_` already follows
for the same question one branch over.

**And the leaf argument has a reason of its own, which is measured and is not differencing.** A row is
read from coefficients the last marginal-profit evaluation recorded, and **the solve does not leave them
at the collar it returns.** `find_root_collar_psi` closes by placing the stem potential and the profit,
not by evaluating the condition at its answer; the search's last probe is what the recorded block
describes. At an interior point that probe *is* the answer, to round-off — so this looks settled. At a
**pin** the search evaluates the marginal profit at both ends and returns one of them, so the recorded
block describes **the other end of the feasible interval**: the stem potential's collar response reads
7.67 where the point's value is 1.46, and 6.74 where it is 1.67. **A factor of three to four, finite and
plausible, at every pinned point.**

So the row layer seats the point itself, and that write is the whole of what stops the qualifier. **The
two-argument form therefore has a precondition nobody has stated: the forward solve's last act must be
an evaluation of the condition at the collar it returns.** One evaluation, on a path that already makes
several — and invisible until now, because the majority branch is the one where it happens to be
correct.

**That precondition earns its keep twice, and the second time is worth more than the first.** It is what
makes a row a read rather than a re-seat. It is also what makes the point **restorable**: an evaluation
of the condition at a *recorded* collar leaves the coefficients seated exactly as a solve leaves them, so
a consumer sweeping a recorded trajectory can hand the point back instead of searching for it again. A
boundary whose solve closed elsewhere could not do that at all — the restored point would be seated at
whatever the last probe touched, which is the defect this precondition removes. §9 states what the leaf
must gain for it.

**And on the request a consumer actually makes, the five arguments are already doing nothing.** Measured
over 1296 operating points at two temperatures, asking for profit and the uptake block: **one solve per
point, no input re-solving anywhere, and no row refused.** Asking for *every* output instead: 522 of the
1296 re-solve, at worst 53 solves for one point. So the arguments survive for outputs the stand never
asks for — assimilation and the stomatal conductance, which the carbon readers do not report — and for
the shut collar's own row, which a request naming the collar reaches.

**Both of the remaining steps are gone and neither cost an accuracy.** The curvature's fallback
answered nowhere — over 392 interior points the closed form answers 392 — so it closes by refusing.
The collar channel's difference was kept **deliberately**, so this route ran the calibration route's
arithmetic and stayed a second implementation of it; taking it out was the decision this section named
and its price is measured below.

**And taking it out fixed something, which the decision did not predict.** The two channels were said
to agree at the solver floor. They do at an interior point — 1.6e-10 over 1,992 comparisons — and at a
pinned dry point, a hydraulic shutdown and a shade death they agree exactly. **At a wet pin they do
not: the top layer's own draw disagrees by up to 5.5 percent**, while every other channel there is at
the floor. That is the output report 05 §7.0 singles out — at the collar of zero *total* uptake the
per-layer draws are individually non-zero and sum to zero, so the emitted vector is the
symmetry-breaking residue and "its relative accuracy under any differencing scheme is the worst in the
model precisely because the output *is* the residue." The read is the closed form. **So the difference
was not a free second opinion at the one branch a drought puts a plant on.**

**What the swap did cost is the assembly identity, exactly as stated.** The parts assembled against the
calibration route's own composite agreed at 1e-12 while both ran the same arithmetic; they now agree at
**7e-05**, attained at an output the read does not state at all, through the assembly's own
cancellation. What replaces the identity is two tighter checks on the halves — the curvature against a
swept difference, and the collar channel at an interior point.

**A refusal is not an argument.** Where the energy-balance gate is on the closed forms do not describe
the branch, and saying so by name costs nothing from this signature. That distinction is what makes
the two-argument form a target rather than an aspiration: it asks that nothing be *measured*, not that
everything be *answered*.

**What comes back**, all passive doubles, is the outer product of report 05 §7.0 and
nothing else:

| field | shape | what it is |
|---|---|---|
| `kind` | one | the branch the solve took, never a reading of the numbers |
| `point` | one | $p^\star$ |
| `residual_slope` | one | $\Pi_{pp}$ at an interior point; the bound's own slope at a pin; 1 where nothing defines the point |
| `dresidual` | $n_{\text{input}}$ | the gradient of the condition that defines $p^\star$ |
| `dy_dp` | $n_{\text{output}}$ | each output's channel into the point |
| `held` | $n_{\text{output}} \times n_{\text{input}}$ | each output's row at a held point |
| a per-input feasibility report | $n_{\text{input}}$ | which rows exist, by name |

**Values are not returned.** They exist on the leaf, because nothing moved it. A `value`
field is a symptom of a row layer that re-solves, and it should disappear with the
re-solve.

**The quotient is not taken here.** Dividing `dresidual` by `residual_slope` is a property
of the implicit function theorem rather than of leaves, and at a pin it is the same
division on a different condition. The consumer forms one implicit node and grafts each
output against it — and an output the condition makes stationary records against its
inputs and **not** against the point, which is the envelope theorem written as an omitted
term rather than as one that has to come out to zero. That omission is what lets the
carbon channel survive a degeneracy that costs the water rows theirs.

### The passivation map, and the rule it obeys

The leaf carries double, so every input is passivated before it enters. There are five
sites and the count is not arbitrary:

| quantity | where it is passivated | forced by the leaf being double? |
|---|---|---|
| the fourteen traits | a trait copy handed to the row layer | **no — the leaf already holds them** |
| the $L$ soil potentials | the driver record | yes |
| radiation | the driver record | yes |
| the maximum conductance | the driver record | yes |
| the $L$ layer carbons | the value copy the architecture model reads | yes |

At $L=5$ that is $14+5+1+1+5 = 26$, which is $n_{\text{input}}$ exactly. That is not a
coincidence, and it is worth stating as an invariant:

> **The set of passivation sites on the leaf path and the set of grafted inputs are the
> same set.**

A passivation severs a row; a graft puts it back. If the two sets differ, either a row is
missing or a `to_passive` is accidental — and an accidental one is invisible, which is the
hazard class this whole boundary exists to manage. The sets match today, so this is a
guard that can be asserted rather than a repair that has to be made.

Two rules follow. **Passivate as late as possible**, so that no quantity is carried
passively through arithmetic that could have carried its derivative. And **passivate once
per quantity, in one place** — one driver record holding all four forced copies, rather
than four sites the row layer has to be told about separately.

The trait copy is the one that should not exist. It is passivated only so that a
perturbation loop can move it, and the leaf's own `set_traits` is the single place a trait
value belongs.

---

## 8. What the forward pass already hands the reverse

The trajectory is solved adaptively to fix the schedule, replayed at fixed steps to build
the tape, and swept backwards. The leaf is solved inside the replay, so **the rows are
computed forwards whatever else is true** — a grafted node needs its rows at record time.
The question is not how to defer them. It is what the forward solve has already produced
by the time they are wanted, and the answer is: nearly all of it.

**1. Every row is a function of the operating point the solve just left.** $A'$ and $A''$
at the intercellular concentration; $C'$ and $C''$ at the stem potential; $f$ and $f'$
there and at the collar; $P'$ and $P''$ at the transport coordinate; the supply's Jacobian
at the collar and the soil state. All of those are reads of state the leaf is holding.
**A row layer needs no model evaluation at all.** That is the architectural win stated as
a property of the forward pass rather than of the mathematics, and it is why the
evaluation count stops depending on the input count.

**2. The collar solve is a root-find on the condition, so the curvature is a by-product.**
$\Pi_{pp}$ is the slope of the marginal profit near $p^\star$, and the solve evaluated
that function at both bracket endpoints and at every iterate on its way in. Two
consequences, and the second is the valuable one.

**This section argued that the curvature's step should come from the bracket the solve
validated, and that is measured and wrong.** The argument was that a fixed step can land
outside the feasible interval, so a step chosen inside one the solve had already accepted
could not reach the marginal profit's hard zero. The premise fails: **the interval bounds
where the optimisation may look, not where the marginal profit is defined.** Approaching
the boundary where the interior regime ends, the room around the point shrinks
continuously to zero and the step's arms do land outside — and both still answer, because
the function is smooth there. The curvature differenced over the collar's own step and
over a step fitted inside the room agree to a ratio of exactly one, at seven such points.
Over 576 driver points, 308 of them interior, no arm lands outside at all and the worst
room-to-step ratio is 177.

So the fixed step is not improved on by the bracket, and the guard is not made unnecessary.
**The $8.4\times10^{4}$ figure belongs to a different experiment** — removing the sentinel test, which
protects against the marginal profit returning a hard zero where the collar is shut or the
concentration solve is infeasible. That is a property of the state, not of the step, and no
choice of step reaches it.

**But "the fixed step stands" is not what that measurement showed, and the fixed step does not.** What
was compared was two steps against each other; neither was compared against a step sweep. Over one,
the differenced curvature sits at $10^{-10}$ at $10^{-4}$, $10^{-5}$ and $10^{-7}$ and reaches
$5.6\times10^{-6}$ at $10^{-6}$ — **the step in use** — at the golden grid's worst interior point. That
is not a floor and not truncation; it is one step landing where a nested root-find changes its iterate
count, and a referee with a hole in it does not degrade, it is wrong at one place. The step survives
because `at` is pinned to it by a captured reference, and that is now the only argument for it. §12's
third item is why nothing else needs one.

And the residual at $p^\star$ is already in hand, so the difference is one further read
rather than three.

**And $\Pi_{pp}$ is analytic, which this section used to deny.** It said $\partial V/\partial p$
carries $P''$ and $\partial^2 E^{\mathrm{up}}/\partial p^2$ — "a *third* derivative order on the
transport and a supply derivative that does not exist" — and both halves are now false. $P''$ left
with §6: taking $V$ off the flux balance gives

$$\frac{\partial V}{\partial p} \;=\; \frac{\tfrac{1}{\kappa}\,\partial^2 E^{\mathrm{up}}/\partial p^2 \;+\; f'(p)}{f(\sigma)} \;-\; \frac{V^2 f'(\sigma)}{f(\sigma)},$$

with no inverse anywhere in it. And the supply's second collar derivative exists and is elementary:
each layer's flux is a numerator linear in the collar over a resistance built from the cumulative
integral's **span** over its **value**, so its collar derivative reads the integrand and one more
reads the integrand's own derivative. Nothing past $f'$ is needed, and $f$ is elementary in the
potential and in both curve parameters. **It is unwritten, not unavailable.**

**It is written.** §12's third item carries the expression and the measurement: the condition's own
second derivatives in $(\sigma, p)$, of which the mixed one is already formed for the condition's
stem-potential slope, plus $\partial V/\partial p$ above. Against a differenced curvature over 259
interior points of the golden grid it agrees to $1.5\times10^{-8}$, and no third derivative order
appears anywhere in it.

What it removed is not one thing. The interior branch's step size; the three marginal-profit
evaluations per node the difference cost, which are now **one** — and that one is the seating every
other row on this boundary is read at, so the re-seating that existed only because the difference left
the collar one step below the point went with it. What it did **not** remove is the sentinel guard: the
difference survives as the fallback where the closed form refuses, which is the energy-balance gate and
the compensation point. A refusal costs no argument; a fallback does, and §11 invariant 1 says so.

**3. The refusal decision belongs to the adaptive pass, not to the recording.** A refusal
has no localisation: a census metric's gradient is a sum, so a term missing anywhere leaves
the whole water channel undefined. That is implemented today as a latch discovered
mid-recording, which then selects between two recording branches. But the adaptive pass
runs the entire trajectory before any tape exists, and the operating-point kind is already
tallied per solve — so *"does any node land on a kind whose water rows do not exist?"* is
answerable **before recording starts**. Asked there it is a precondition on the run; asked
mid-tape it is a latch, and the two branches exist only because it is asked late.

**4. What the forward pass cannot help with, and it is worth saying.** Warm-starting the
replay's collar solve from the adaptive pass's answer would halve the forward leaf cost
and simplify nothing in the reverse, while putting bit-identity at risk. The two passes
solve the same leaf twice and that is the price of a fixed schedule.

---

## 9. What the leaf must gain for any of this to be stateable

Eight things, and each is small. They are listed as properties the submodel must have,
not as an order of work.

- **The stem potential's collar response, $V = \partial\sigma/\partial p$**, is formed
  inside the marginal-profit evaluation and thrown away. It is half of the waist and has
  to be reportable. **Done**, and free: the solve measures 6.30 µs against 6.33, and it
  agrees with a difference of the inverse transport at three operating points, a pinned
  one included.
- ~~**$\partial R/\partial\sigma$** — the one unbuilt object.~~ Built, and decomposed in
  section 5 as claimed: second derivatives of two kernels already seeded once and the inner
  theorem applied twice, agreeing with the pair solved from two state families to
  $5\times10^{-7}$. It was not the last thing missing — section 3 says what is.
- ~~**The row-layer reads must be `const`.**~~ They are, and the compiler is what says so
  rather than a convention. Two of them wrote a member on their way past — one re-seating
  total uptake, one storing the hydraulic cost through a wrapper whose kernel is pure — and
  both were reads of a number the leaf already held. With those gone, the only thing left
  stopping `const` was `transpiration`'s memo, which is a cache and is now `mutable`: the
  value is a function of its two arguments alone. **Every row reader is `const`**, so the
  read-that-moves-an-output hazard is inexpressible rather than avoided by care — which
  matters because one solver serves every plant of a species.
- ~~**The collar channel must be reportable, not differenced.**~~ Reported, and the difference is
  gone. $\partial y/\partial p$ at fixed traits is what every ordinary output's row is multiplied
  by, and it was a difference of the outputs across $p^\star$. That difference cannot be centred
  where the point sits within a step of its bound: over the golden grid's 42 pinned points it
  answers at 24, so eighteen constrained points had **no channel at all**. Read off the recorded
  state it answers at all 42 — and where both exist they agree at 1.6e-10 at an interior point and
  exactly at three of the four branches, but **not at a wet pin**, where the difference is out by
  5.5 percent in the top layer's draw. §11 invariant 8 has why the read is the one to keep.
- ~~**The feasible bracket must leave the solve**, so the curvature's step comes from it.~~
  Measured and refused: §8 has the numbers. A stored interval a later evaluation can move
  is the hazard class this boundary exists to manage, and with the step refused nothing
  reads it.
- **The inverse transport curve's slope must be supplied**, not inferred — section 6.
- **The solve must be able to hand back what it found, and take it back** — and in a form only it can
  produce. This is the leaf's half of report 09 §9, whose Kind B payload it is the only instance of, and
  it is an instance for the reason 09 §2 gives: the rows are supplied rather than recorded, so the value
  reaches no tape and restoring it changes nothing a transpose depends on. A consumer that sweeps a
  recorded trajectory re-establishes the *same state* at every stage,
  so the operating point it searches for is one the run has already found: bit for bit, because the
  recorded state is exact, the step sizes are recorded and the search is deterministic. What that needs
  is a token carrying the point, **the branch it was found on**, and the feasible bounds — the branch
  because a row is priced by it and it must be the branch *taken*, and the bounds because the row layer
  otherwise re-runs two root-finds the solve already ran.
  
  **A token rather than two loose numbers, for the reason the classification is read-only.** A settable
  branch is a way for a caller to disagree with the solve; a token the solve alone constructs is the
  same guarantee with the restore made expressible, and it keeps *imposing* a collar and *restoring* one
  two different operations.
  
  **And the restore is bit-identical because the two placements are one placement.** Evaluating at an
  imposed collar and closing a solve write the operating point, the stem potential and the profit by the
  **same three expressions in the same order**, so a restore at the solve's own answer places what the
  solve placed — and the clamp an imposed evaluation applies is a no-op there, because a returned point
  is strictly inside its bounds. What makes the *coefficients* agree as well is §7's precondition, that
  the solve close on the condition at the collar it returns: a restore evaluates that condition once at
  the recorded collar and is then seated exactly as a solve leaves it. **The precondition that makes a
  row a read is the same one that makes the restore possible**, and a boundary whose two placements had
  drifted apart could not be restored at all.
  
  It is offered only where a search happened. The four branches that exit before the search cost
  nothing to reach again, so the token declines them and the caller solves.
  
  **What it is worth is a share of a sweep rather than of a solve**: measured on a century-scale stand,
  the reverse pass's own collar search is **12 percent of a gradient**, priced identically to the forward
  pass's because this model is passive on both — so the whole of it is recomputation. Report 09 §9.6
  sizes the store at about 20 MB, and §9.4 carries the one indexing hazard, which is that a
  first-same-as-last carry puts the point a recording wants at the *previous* step's last stage.
- ~~**The solve must leave its coefficients at the collar it returns.**~~ It does. The condition is
  evaluated at that collar before the outputs are placed, so the coefficient block describes the point
  and the placement is still the last word on every value — bit-identical forward, and the rows the layer
  reads are bit-identical too. One marginal profit, a little under nine percent of a solve, and a
  gradient call pays nothing for it because it is the evaluation the row layer used to make itself.
- **The root integral's steepness derivative must be capped like every other reader of it**, and in the
  band between the grid and the cap it must refuse rather than throw — §12's seventh item.
- ~~**The supply's second collar derivative.**~~ Written, out of the same loop as the first with one
  more derivative of each moving part: the span is linear in the collar so its second derivative is
  zero, and the integral's is the integrand's own slope. Against a difference of the first over a step
  sweep, $2\times10^{-7}$ over fifteen states; exactly zero on the single-potential path, whose flux is
  linear in the difference over a constant resistance.
- ~~**The condition's slope in the COLLAR**, which is the profit's curvature.~~ Written, and it shares
  its second-order block with the condition's slope in the stem potential rather than repeating it —
  the mixed derivative one needs is the other's, by the symmetry of the second derivatives. The only
  coefficient neither shares is the concentration's second collar derivative, which is the same
  theorem at the other limit.
- ~~**Both vulnerability curves' steepness must reach the bounds.**~~ Reached. The wet bound
  is total uptake and the dry one adds the stem's own integral, so `root_c` enters both and
  `stem_c` the dry one; neither had an entry, and a pinned point differenced a rebuilt grid
  to get them. Both come off the same shape series the supply rows use, and agree with a
  difference across a genuine rebuild to $9\times10^{-7}$ and $10^{-5}$.
- ~~**The four analytic row functions that already exist must be reachable.**~~ All four
  are. Radiation's profit row, the six assimilation traits' rows and the two cost traits'
  rows are read at an interior point and at a pin; the hydraulic cost's own rows are read
  at a **shut** collar, where they are not a contribution to the profit row but the whole
  of it. `set_shutdown_state` seats the stem at $\psi_{\text{crit}}$ on every exit and
  writes every flux to zero, so

  $$\Pi \;=\; -R_d(T) \;-\; C(\psi_{\text{crit}};\,\text{stem}_b,\,\text{stem}_c,\,\beta_2,\,\text{scale})$$

  and that is the entire dependence. Six inputs appear in it and twenty do not.
  Differenced at 36 shut points: the six agree with the closed form to
  $5\times10^{-10}$, and the twenty the expression calls zero move the model by
  **exactly** zero — so the declaration and the model agree bit for bit rather than
  closely.

---

## 10. What does not go away, and one thing that cannot yet be deleted

Three things survive this design and are not debt.

**The fold guard.** The quotient still divides by the curvature, so a ceiling on the
amplification is still required — and it belongs at the **consumer**, because forming it
needs the output adjoints, which neither the row layer nor a primitive owning the quotient
has. What the supplier can form instead is a maximum over inputs carrying different units,
which is not a quantity a ceiling can be stated for.

**The classification.** Which kind of point the solve found decides which theory applies,
and it must be recorded by the branch taken rather than inferred from a residual: the
marginal profit returns a hard zero in a no-flow state, and no test on that number can
separate it from stationarity.

**Refusal itself.** A fold is real, and a row that does not exist must be refused by name
rather than returned as a plausible number.

And one honest limit. **The perturbation machinery cannot simply be deleted, because the
calibration route shares it.** That route is a second implementation of a reference
gradient and is required to reproduce it bit for bit, which means it differences — and it
reaches the driver record, the trait copy, the step rule, the perturbed-state application,
the held-collar evaluation and the whole-solve difference. Every one of those is therefore
shared, not the stand's alone.

So the change available is **decoupling, not deletion**: the calibration route keeps its
own differencing, and the row layer stops sharing a substrate with it. Line count barely
moves. What moves is that a correctness improvement to the stand's rows stops needing a
flag to keep it away from a frozen mirror — and a substrate that every new path must route
around is the thing that has already cost this corpus two reverted attempts.

---

## 11. What must be true when this is right

Nine invariants. Each says **met**, **unchecked**, or **open**, and an unchecked one is a claim about
the code that nothing in either suite tests.

**1. The row layer takes a leaf and a request, and nothing else.** **Met on the arity, open on the
qualifier.** `rows_at` takes two arguments and does not solve. Every row of the table this invariant
used to carry is closed, and they closed in three different ways rather than one:

| what read a step | how it closed |
|---|---|
| the curvature's **fallback** | **no witness** — over 392 interior points the closed form answers 392 — so it refuses instead. A refusal costs no argument where a fallback costs three |
| the collar channel at an interior point | **the decision was taken.** The read answers everywhere either does; the price is the assembly identity, 1e-12 to 7e-05, and what it bought was a 5.5 percent error removed at a wet pin |
| the supply at a collar that **meets a layer's potential** | §12's fourth item: genuinely 0/0, with the limit derived and no state reaching it |
| the single path's series resistance | **the other consumer's input, on the other consumer's supply.** The read declines it by name; the differencing entry answers it |
| a request naming assimilation or the stomatal conductance | **the other consumer's outputs.** The read declines the carbon-side inputs by name and the differencing entry answers them |
| the shut collar's own row | **not an object.** Nothing a shut leaf reports reads its collar, and the seat is one of two registered inputs at every one of 12,384 hydraulic shutdowns |
| **the base point itself re-solves** | closed: the solve now closes on the condition at the collar it returns. The row layer reads the pair off the leaf and the rows are bit-identical |

**So what the arity cost was, in the end, was not mathematics.** Three of the seven were the
calibration's output set and input list reaching into the stand's row layer — report 02 §3.0's hazard,
fired — one was a decision, one had no witness, one is derived and unreachable, and one was a
precondition on the forward solve. **No new derivation was needed for any of them.**

**What is left is the qualifier, and it is one chain.** `bound_row` probes collar potentials and
restores the uptake state its probes moved, so the members it saves and restores have to become
`mutable` before `const` can go on. That is mechanical and it is not this function's.

**2. A gradient call makes exactly one leaf solve per node per stage.** **Met for the request a consumer
makes, and the exception is nameable.** Neither entry point solves now; the consumer solves and the row
layer reads. Measured on the stand's own request — profit and the uptake block, twenty-six inputs — it is
**one solve** at an interior point and one at a pin, with nothing differenced. An **all-outputs** request
costs **two**: naming assimilation sends every carbon-side input to a difference, and a differenced row
has to put the leaf back before a consumer reads its values off it. That restore is the second solve, and
it is the price of the values living on the leaf rather than on the return.

**The evaluations inside the one solve moved by one, in the other direction.** The curvature's difference
cost three marginal-profit evaluations per node and the seating every row is read at cost a fourth; the
closed form left one. Closing the solve on the condition at its own answer adds that one back — measured
at **6.61 to 7.2 µs per solve, a little under nine percent** — and a gradient call pays nothing for it,
because it is the evaluation the row layer used to make itself. A forward-only run pays the nine percent,
and that is the stated price of the precondition.

**And the invariant one solve per node per stage still counts the wrong thing, which the next item is
about.** It counts solves *within a call*, and a stand's gradient makes the call **on a state the run
has already solved**: the recorded trajectory is swept by re-running the rates at every stage, so the
operating point is searched for a second time at a state where the answer is already known. Measured on
a century-scale stand, the reverse pass's own share of that search is **12 percent of a gradient**, and
the search is priced identically on both passes — the leaf is double either way — so the whole of it is
recomputation rather than a scalar's cost. **The invariant that would catch it is one *search* per state
rather than one *solve* per call**, and §9's restore is what makes the two the same number.

**3. Passivation sites and grafted inputs are the same set.** **Met, and asserting it found something.**
The count $14+5+1+1+5 = 26$ is a reader's arithmetic and is not the invariant; the invariant is that no
member of the set is **severed**, because an accidental `to_passive` is invisible — every row of that
input comes back exactly zero, indistinguishable from an input the model does not read. So the check is
that every input moves an output somewhere, which a slack zero survives and a severed one does not. Run at
the defaults it reported the root's own critical potential severed, and §12's fifth item is why it is not:
at those defaults that potential and the stem's are the **same number**, so the arm of the dry bound where
it binds is unreachable, and reaching it needs a plant whose root gives up before its stem. All twenty-six
move something once such a state is in the grid.

**4. All four analytic row readers are reached.** **Met.** Radiation's profit row, the six
assimilation traits', the two cost traits', and the hydraulic cost's own — the last at a shut collar,
where it is not a contribution to the profit row but the whole of it.

**5. No trait rebuilds a grid to obtain a row.** **Met.** Both curve steepnesses come off the
incomplete gamma's shape series: in the transport rows, in the supply rows, and in each bound's row.

**Met, to round-off.** Over 1600 knots the cumulative curve's slope is its integrand there to
$2.2\times10^{-16}$ and the inverse's is the reciprocal to the same, checked by rebuilding the knots from
the generator the builder uses — so the slopes are data rather than inferred, which is what the inverse's
fourth-order value error rests on, and the inverse's value is the stem potential that everything reads.
`setup_transpiration` supplies $1/f(\psi_i)$ at each knot from the same loop that forms the values, and
until now nothing outside that function named the supplied slope. The second-order half of this invariant
is **gone rather than open**: §6 removed the only consumer of either derivative of the inverse. Report 02
§3.7's inventory and report 05 §7.3b both still list those two derivatives as required, and neither is
wrong — the identities hold — but nothing reads them.

**7. Both critical potentials carry a slack zero at an interior optimum.** **Met, and it is three
answers over four states.** Inactive at an interior optimum; a bound's argument at a pin, where the
constraint's gradient goes live in `dresidual` and the held row stays zero; at a hydraulic shutdown the
stem's critical potential is **the seat itself**, so its row is $-C'(\psi_{\text{crit}})$ and it is not
slack at all; and **at shade death it is inactive again**, because the seat there is the collar of zero
uptake and the flux integrates up to that. The fourth state is the one this document had wrong: the row
read $-C'(\psi_{\text{crit}}) = -0.750$ where the model says exactly zero, because the two zero-flux
kinds were one flag. **Which state you are in is the seat, and the seat is a fact about the branch, not
a comparison on the potentials.**

**8. Every ordinary output has a collar channel wherever the point exists.** **Met, and the claim beside
it was wrong.** The channel is read off the seated state, because the difference cannot be centred where
the point sits within a step of its bound — 24 of the grid's 42 pinned points, measured.

**"Where both exist they agree at the solver floor" is true at three branches out of four.** Over 7,200
comparisons: interior 1.6e-10, pinned dry exactly 0, hydraulic shutdown exactly 0, shade death exactly 0
— and **pinned wet 5.5 percent**, all of it in the *top layer's own draw* while every other channel there
sits at 1.8e-09 or better. That is report 05 §7.0's near-cancelling output: at the collar of zero total
uptake the per-layer draws sum to zero, so the emitted vector is the symmetry-breaking residue and is the
worst-conditioned thing in the model to difference. **The read is the closed form and the difference was
the one carrying the error**, which inverts the reason §7 gave for keeping it.

**9. Every point either answers or refuses by name.** **Met for the kinds, open for one output.** A
shut-down or folded point refuses and the carbon channel survives it, because profit does not read
the point; a pin whose bound has no derivative refuses and the name says which bound. What does not
yet refuse cleanly is the shut collar's own row — §12.

### The classification, and the witness that settles it

Report 05 §7.0 requires the point's kind to be **a decision tree on what defines it, never a
comparison on the residual**, and `OperatingPointKind` is that tree. A second classification runs
beside it: `Status`, four values derived from the curvature's sign and the residual's size, which is
exactly the inference §7.0 forbids. It survives because the calibration route is refereed bit for bit
against a captured reference and cannot move.

**So the two are not a duplication to be merged but a decoupling with an expiry**, and the expiry is
the reference being re-blessed. Until then the rule is that `rows_at` reads the kind and never the
status, which it does.

**And §7.0's requirement now has a witness rather than an argument.** Over 1620 points the two never
disagree, so the merge is a deletion — but the agreement is not the numerical test working. At zero
radiation a shade-death point's residual is a **sentinel**, so its implied Newton step is exactly zero:
the interior side of a cut whose whole justification is that nothing lands there, with a finite,
large curvature beside it saying nothing. Thirty-eight such points read as stationary from the number
alone, and what catches every one of them is invariant 8's channel refusing to be centred on a bound —
an unrelated refusal doing the work the number is credited with. **A comparison on the residual cannot
separate these branches, and the reason it has not yet produced a wrong answer is a second mechanism.**

---

## 12. What is open, and what closes each

Six items were open, **all six are closed, and closing the sixth opened a seventh**. Closing them
corrected this document five times — never about the mathematics, which held throughout, but about the
size of two numbers, about what a single step can referee, about how many of three coincidences were
coincidences at all, about which of two classifications the agreement between them was evidence for,
and — the fifth — about **whose consumer's outputs the row layer was carrying arguments for.**

**The fifth correction is the one to read if only one is read.** Three of the seven things invariant 1
listed as unwritten were not objects at all: they were a *calibration's* output set and input list
reaching into a *stand's* row layer, which is report 02 §3.0's hazard fired in the direction nobody
checks. No derivation closed them. What closed them was asking, of each, which consumer's equations
name it.

### ~~1. Shade death is priced as a hydraulic shutdown, and it is a pin at the wet bound.~~ Closed.

**It is a pin at the wet bound with no carbon half**, and it now takes the pinned machinery. The two
zero-flux kinds were one flag in the row layer and they are not one point: a hydraulic shutdown holds
the stem at $\psi_{\text{crit}}$ and writes every flux to zero, so nothing it reads is a function of
the soil; shade death seats **both** potentials at the collar of zero uptake, so the cost is paid
there, $\psi_{\text{crit}}$ is inactive exactly as at an interior optimum, profit reads the soil
**through the bound**, and the per-layer draws are individually non-zero while summing to zero.

**The fixture is light, and the threshold is sharp** — 05 §7.0 was right that no moisture sweep finds
it. Bisected at the TF24 trait vector: the branch holds below **26.62 µmol at 25 °C** and below
**94.76 at 40 °C**, and above it the point is pinned wet. The two figures are **identical across soil
potentials of 0.5 to 4 MPa and across one to five layers** — the threshold is set by radiation and by
temperature through respiration, and by nothing else, which is the statement 05 §7.0 makes turned into
a number.

**And the golden grid misses it by five percent.** Its lowest radiation is 100, against a threshold of
94.76 at the grid's own upper temperature. So 576 points at two temperatures never reached a branch
that opens just below the corner of the box they cover — which is the sharpest form of report 02 §6's
rule available: *a corner reported as unreachable is usually a corner nobody drove at*, and here nobody
drove five percent further.

What was wrong, measured against a differenced solve at that fixture: three of the cost rows by **0.69
to 1.79 relative** — `stem_c` **sign-flipped** at −0.672 against +0.531, `cost_scale` at 0.89, `beta2`
at 0.70 — with `stem_b`'s wrong by the same construction and its referee refusing;
$\psi_{\text{crit}}$ reporting $-C'(\psi_{\text{crit}}) = -0.750$ where the model says exactly zero;
the slope the unit one that means *nothing defines this point*; and the objective's channel the model's
own **sentinel**, an exact 0.0 where the value is $-C'$ at the seat. All twenty-six inputs now assemble
to within $1.1\times10^{-6}$ of a differenced solve, none refused.

**One fact carried the whole correction**: which potential the leaf is seated at. Both kinds write it
to the same member, so the cost's rows are read there rather than at a named potential, and the one
bit that separates the kinds — *is the seat the stem's critical potential?* — decides both of the two
answers that differ. A hydraulic shutdown's soil block is exactly zero because its seat reads no soil;
shade death's is the supply's own, because its seat **is** a function of the soil.

**And the hydraulic shutdown gained twelve rows it should already have had.** §4's table claimed
"twenty exact zeros"; the code declared fourteen and re-solved the other twelve — the root curve's two
parameters and the $2L$ soil inputs, ten at five layers. They are exactly zero there for the reason the
eight carbon-side ones are: the seat is a registered potential, every flux is written zero, and nothing
left in profit reads the soil. Now declared. That is a report-versus-code disagreement §4 had been
asserting for as long as it has existed, and the count in it was the report's, not the code's.

### ~~2. A wet pin's point row omits the other bound's share.~~ Closed, and its size was misattributed.

**The missing term is real and it is now carried.** The solve returns the wet bound stepped a constant
fraction of the *bracket* inside it, so $p^\star = (1-\epsilon)b_a + \epsilon b_b$ with
$\epsilon = 10^{-6}$ measured exactly, and the point's row is that same weighting of the two bounds'
rows where it carried only $\partial b_a/\partial u$.

**What it buys is not an accuracy, it is three inputs.** The wet bound is total uptake, which no stem
property and no conductance enters, so their entries in its row are *exactly zero* — and the point
still moves with them, through the far bound's millionth. Against a differenced solve of the collar,
the maximum conductance's point row was **exactly 0 against 0.0120**, `stem_c`'s against
$-2.19\times10^{-7}$, $\psi_{\text{crit}}$'s against $1.30\times10^{-7}$. A millionth of a row can
be the whole of a row, and that is the case whenever the near bound has none.

**And the $3\times10^{-5}$ this section quoted was the referee's floor, not the row's error.** It
scales as $1/h$ — $3.08\times10^{-7}$, $3.08\times10^{-6}$, $3.08\times10^{-5}$ at steps of
$10^{-4}$, $10^{-5}$, $10^{-6}$ — which is a fixed offset in the numerator, `find_root_psi`'s own
tolerance divided by the step. **A weighting term cannot scale with the step**, so the number was
never evidence for the term it was attributed to. Over a sweep the wet bound's own soil row agrees
with the differenced bound to $2.2\times10^{-8}$ and the assembled point row with a differenced solve
to $3.3\times10^{-9}$, worst $1.4\times10^{-5}$ over the four inputs including the conductance.

So the contraction argument built on it — 05 (7.3d)'s ratio $C \approx 28$ applied to
$3\times10^{-5}$ to give a water row near $10^{-3}$ — **had no premise**. The mechanism is real; this
was not an instance of it. What remains true, and is why the item still mattered: **a pinned plant is
drought**, and three of its inputs were reporting that the collar does not move with them.

### ~~3. The curvature is differenced and is analytic.~~ Closed.

$\Pi_{pp}$ is a statement. Writing $G = \partial\Pi/\partial\sigma$ and
$H = \partial\Pi/\partial p|_\sigma$, so that the condition is $GV + H$,

$$\Pi_{pp} \;=\; \frac{\partial G}{\partial\sigma}V^2 \;+\; 2\frac{\partial G}{\partial p}V \;+\; \frac{\partial H}{\partial p} \;+\; G\,\frac{\partial V}{\partial p},$$

where $\partial G/\partial p$ **is** $\partial H/\partial\sigma$ by the symmetry of the second
derivatives, so the coefficient the condition's stem-potential slope already forms serves here too and
the only new one is $\partial H/\partial p$. That is the concentration's theorem applied twice in the
collar instead of in the stem potential, with the conductance's second collar derivative entering as
$-\text{const}\cdot\kappa f'(p)$ where its stem one enters as $+\text{const}\cdot\kappa f'(\sigma)$ —
the same expression at the other limit, because transpiration is the curve integrated *between* them.
$\partial V/\partial p$ is §8's, and $\partial^2 E^{\mathrm{up}}/\partial p^2$ came out of the
supply's own loop with one more derivative of each moving part: the span is linear in the collar so its
second derivative is zero, and the integral's is **the integrand's own slope**, elementary, not the
tabulation's curvature.

Measured against a differenced curvature over 259 interior points of the golden grid:
$1.5\times10^{-8}$. **No third derivative order appears** — the requirement in §5 held.

What it retired: the interior branch's step size; the three marginal-profit evaluations per node the
difference cost, now one, which is also the seating every row is read at; and the re-seating that
existed only because the difference left the collar one step below the point.

**What it did not retire is the sentinel guard**, and the guard is why: the difference survives as the
fallback where the closed form refuses, which is the energy-balance gate and the compensation point.
A refusal costs no argument, but a fallback does — see §11's invariant 1.

### ~~4. The supply refuses two coincidences that have derivatives.~~ Closed, and there were three of them.

**Two of the three were never coincidences for a derivative at all**, and removing them needed no
mathematics — only reading what actually vanishes.

| what the kernels refused at | what vanishes there | the derivative |
|---|---|---|
| the collar meets a layer's potential | the span **and** the integral over it | genuinely 0/0 — the limit below |
| the layer's flux is gravity-balanced | the **numerator**, and nothing else | $1/r_R$, agreeing with a difference to $2\times10^{-12}$ |
| a moving bound sits at atmospheric | **nothing** | the split's two parts have the same slope: the integrand is 1 below the surface and $f_r(0)=1$ above it |

All seven kernels opened with one test covering all three and returned a whole vector of
not-a-number if any layer met any of them. **Only the second is ever reached** — 30 of 540 operating
points, every one of them a one-layer shade death, because with a single layer the collar at which
total uptake vanishes *is* the collar at which its numerator does. That is what made a one-layer
shaded plant fall back to differencing the whole solve, and with the two false refusals gone **nothing
in the grid refuses a conductance**: the wet bound has a row at every layer count and item 1's rows are
analytic there instead of measured.

**The one that is 0/0 stays refused, and the reason is a count rather than a difficulty.** The mean
conductivity is the reciprocal of the cumulative integral's **divided difference** over the interval,
$Q = 1/D$ with $D = \int_0^1 f_r(p + t(s-p))\,\mathrm{d}t$ — which is what the value branch already
calls the layer's mean conductivity, and which makes every limit elementary:

$$D \to f_r,\quad D_s \to \tfrac{1}{2}f_r',\quad D_p \to \tfrac{1}{2}f_r',\quad D_{ss} \to \tfrac{1}{3}f_r'',\quad D_{sp} \to \tfrac{1}{6}f_r'',\quad D_{pp} \to \tfrac{1}{3}f_r''.$$

Verified: $Q \to 1/f_r$, $\partial Q/\partial s \to -f_r'/(2f_r^2)$, and the flux's collar derivative
to $5\times10^{-11}$ against the general branch approaching it; $f_r'' = f_r c x \psi^{-2}(cx - c + 1)$
with $x = (\psi/b)^c$, against a difference of $f_r'$ to $4\times10^{-11}$. **It is written down and not
written in**, because no state reaches it: zero of 540 points over one to five layers, radiations from
dark to full sun, and potentials from 0.5 to 7 MPa. Two of the seven kernels would also need a new
mixed derivative of the integrand, which is work with no measured consumer. *The derivation is here so
that supplying it is transcription rather than research the day a witness appears.*

**And one latent disagreement found on the way**, recorded because it is nobody's defect yet: the
value branch reads the integrand off the conductivity spline and the derivative branch off the
cumulative integral's own slope, which are two tabulations of the same function. They differ by
$4\times10^{-11}$, so the flux is discontinuous by that much at the meeting the value branch handles.

### ~~5. Three invariants are unchecked.~~ Closed. One loop apiece, and one of them found something.

**The solve count is counted rather than proxied.** The suite asserted that no *input* re-solves, which
is weaker — a route could solve twice for a reason no input explains. The leaf now tallies solves of the
operating point, and a whole request is **one solve for twenty-six inputs** at an interior point and one
at a pin. A shut point is excluded by construction: no condition defines it, so its rows are still a
difference of the solve.

**The supplied slope holds at every knot, exactly.** Over 1600 knots the cumulative curve's slope is its
integrand there to $2.2\times10^{-16}$ and the inverse's is the reciprocal to the same — round-off, so
the slopes really are data and not inferred. That is what the inverse's value error being fourth order
rests on, and the inverse's value is the stem potential, which everything reads.

**The passivation set fired, and it was the grid rather than the code.** The check is not the arithmetic
$14 + L + 1 + 1 + L = 26$, which a reader can do; it is that no member of the set is *severed*, because
a `to_passive` nobody grafted back is invisible — every row of that input comes back exactly zero,
which is indistinguishable from an input the model does not read. Run over a default-trait grid it
reported `root_psi_crit` severed.

It is not. **At this package's defaults $\psi_{\text{crit}}$ and the root's own critical potential are
the same number**, so the dry bound's `min` can never prefer the root's, and that input is slack at
every state a default-trait grid can reach — zero of 162. Its live row exists and is exactly $+1$,
being a registered constant, and reaching it needs a plant whose **root gives up before its stem**,
which is the configuration the dry bound's clamp exists for and which the consumer runs. With such a
state in the grid all twenty-six move something. **The same empty window that hid the clamp hid this**,
and it is 02 §6's rule for the third time in this section: a corner reported as unreachable is usually
a corner nobody drove at.

### ~~6. Two classifications describe one point.~~ Closed, by re-reading the question.

**There is no merge to wait for, and framing it as one was the error.** `Status` is the calibration
route's classification and `OperatingPointKind` is the branch tree; the two do not describe one point in
one consumer, they describe one point in **two consumers**, which is what §10's decoupling *means*.
`Status` occurs nowhere in the stand's path and nowhere in the row layer, and the calibration route is
refereed bit for bit against a captured reference — a freeze that includes its classification. So the
expiry is real and it gates nothing: what had to be true is that the row layer reads the kind and never
the status, and that is what it does.

**Which also disposes of the finding constructively.** The 38 night-time points that read as stationary
from the residual and the curvature alone are a defect of the *numerical* classification, refereed by the
reference that owns it. They were never the stand's exposure. What should become structural rather than
conventional is that the row layer cannot *name* `Status` — report 05 §6.1's rule applied to a field
instead of a scalar: where a quantity must not be reachable, the cheapest guarantee is that reaching it
cannot be expressed.

The measurement that settled it is below, and it stands.

### 7. The root integral's steepness derivative refuses where its value caps, and a deep dry layer reaches it.

**Open, and it is the one place a step still lives in this boundary.** Found while closing invariant 1,
so it is new rather than re-read.

Every reader of the root cumulative integral is capped at the closed-form limit report 05 §6.2 requires —
the value, its potential derivative, the integrand's own slope, and the curve's *position* derivative,
which stays right past the cap because the limit is homogeneous of degree one in the position. **The
steepness derivative was the one that was not**, and past the grid it did not refuse, it **threw**: the
incomplete gamma's shape series holds only on the domain the knots cover, and the assertion that guards
it reported the domain as unreachable.

**It is reachable, and 05 §6.2 says exactly how.** Whole-plant shutdown keys off the *wettest* layer, so
a wet top layer over a sufficiently dry one below is a live plant whose deepest layer is out past the
grid — the arrangement a drying profile produces. Measured at a five-layer profile straddling the stem's
critical potential, a shade-dead plant: the wet bound's row threw, and a throw is not a refusal. It took
the whole census metric's gradient rather than one row's.

Two thirds of it are now closed. Past the cap the integral **is** the limit, so the limit's own steepness
derivative is the answer and needs no series: with $a = 1/c$,

$$L = \frac{b}{c}\,\Gamma(a), \qquad \frac{\partial L}{\partial c} = -\frac{L}{c}\left(1 + a\,\psi_0(a)\right),$$

which is the same argument that makes the capped *potential* derivative zero, one parameter over. And
between the two domains the read now returns non-finite rather than throwing, so a caller differences a
genuine rebuild instead of losing the metric.

**What is left open is that band, and it is narrow rather than empty.** The grid stops one knot short of
$\psi_{\max}$ and the spline extrapolates past it with the slope at its last knot, so between
$\psi_{\max}$ and the potential where that straight line finally exceeds the limit the model's own
integral is a linear extrapolation — neither on the grid nor at the cap. Its steepness derivative is the
extrapolation's, and the pieces are available: the series at the last knot, where it holds; the
integrand's parameter partial, elementary; and the last knot's own motion in the steepness, which comes
off the knot generator. **That is a fourth object, it is closed-form, and it is the only remaining
consumer of a step in this boundary.** Until it is written, `rows_differenced` is what answers there.

**And the honest alternative is a forward-model change rather than a better row.** Report 05 §6.2 calls
the extrapolation past the grid the defect the cap exists to bound; capping at the last knot instead
would remove the band and cost a discontinuity of about 3e-03 in the integral's value, and replacing the
extrapolation with the true asymptote would remove both. Either is a re-blessing.

### ~~The two classifications, measured.~~

**Kept because the measurement stands and the reframing above rests on it.** The
merge was said to wait for the captured reference, which cannot move. What did not have to wait is the
question of what the two say about each other.

**They never disagree.** Over 1620 operating points at two temperatures the numerical `Status` is
exactly a projection of the branch the solve took:

| branch | status | points |
|---|---|---|
| interior | interior | 392 |
| pinned wet | pinned | 320 |
| pinned dry, root's continuity limit | pinned | 62 |
| shade death | pinned | 516 |
| hydraulic shutdown | no-gradient | 330 |

So the merge is a **deletion** rather than an investigation, and what the projection loses is nameable:
three branches map onto `pinned`, and one of the three is not an optimiser's pin at all while the other
two are bounds that are *different functions of the inputs*. A consumer holding the status cannot form a
bound row.

**But the agreement is not evidence that the numerical test works, and that is the finding.** Where
radiation is zero — night — gross assimilation is identically zero, the marginal profit at the seated
collar is a **sentinel** rather than a derivative, and the implied Newton step is therefore **exactly
zero**: the interior side of a cut whose entire justification is that no point lands there. The
curvature beside it is finite and large ($-2\times10^{4}$ to $-1\times10^{6}$), so nothing about the
pair says which branch this is. Measured: **38 constrained points read as stationary from the number
alone.**

What rescues them is not the classification. The collar channel cannot centre a difference on a point
that sits **on** its bound, so the composite is abandoned and the status is rewritten as pinned — a
second, unrelated refusal doing the work the number is credited with. None of the 38 takes the
composite.

**So `at`'s own note that the tolerance sits "in an empty band six orders wide" is wrong**, and it is
wrong in the direction that matters: the band is not empty, it contains a whole branch, and the branch
is night. The band is real for the *optimiser's* pins — interior points reach $6.5\times10^{-12}$ and
the mildest pin sits at $6\times10^{-3}$ — and it says nothing about the kind whose residual is not a
derivative. That is report 05 §7.0's requirement demonstrated with a witness rather than argued: **the
kind must be a decision tree on what defines the point, never a comparison on the residual.**

### The two measurement habits, which stopped being advice

Report 05 §8 says *a plateau must be found rather than assumed*. This section quoted two numbers taken
at one step and both were the step's, not the quantity's:

| quoted | at one step | over a sweep | what the single step was |
|---|---|---|---|
| the wet pin's point row | $3.08\times10^{-5}$ | $3.3\times10^{-9}$ | a root-find's tolerance over $h$, growing as $h$ shrinks |
| the closed-form curvature | $5.62\times10^{-6}$ | $1.5\times10^{-8}$ | one step landing where a nested root-find changes its iterate count |

The second is the sharper lesson, because it is not a floor. The differenced curvature sits at
$10^{-10}$ at steps of $10^{-4}$, $10^{-5}$ and $10^{-7}$ and **spikes to $5.6\times10^{-6}$ at
$10^{-6}$**, which is the step in use. A referee with a hole in it is worse than a noisy one: it does
not degrade, it lies at one place. **So a differenced referee here is a sweep, and its best agreement
is the answer.** Both checks are written that way now, and each reports what one step would have said
beside what the sweep does, so the gap stays visible.

And report 02 §6: *count your branches on a driver that reaches the regime in question.* **That rule
fired three times in this section, on three different drivers**, which is what makes it the section's
real conclusion rather than a caution:

| item | the regime nobody drove at | what it took |
|---|---|---|
| 1 | shade death | radiation below 26.6 µmol, where the grid's floor is 100 |
| 4 | the gravity balance | a **single** soil layer, where the collar of zero uptake is that balance |
| 5 | the root's own critical potential binding | a plant whose **root gives up before its stem**, which the defaults make impossible |

Each was reported as unreachable by a grid that could not reach it, and in each case the branch was one
parameter away. **The driver that matters is rarely the one already being swept** — two of these three
are not soil moisture, and the corpus's habit is to sweep soil moisture.

---

## 13. What would falsify this

- **The waist is not two-dimensional.** Recover the two coefficients from two state
  directions of different families and predict the rest; a residual growing with the
  number of predicted directions means a third intermediate. Note this passes for the
  *wrong* pairing too, so it establishes the rank and not the coordinates.
- **The pair is total uptake and its collar slope after all.** If a closed form written in
  those agrees with a difference of the condition, then $H$ does not contribute and this
  document's central correction is wrong.
- **Supplying the inverse's slope roughens what the solve climbs.** The argmax's smoothness
  in a trait is a measurement, and a curve with more curvature between knots, or a coarser
  grid, is where it would fail. The symptom would be trait derivatives degrading with no
  row having changed.
- **A third derivative order is needed.** This document claims one order past what the row
  layer consumes closes every row. Half-fired, and the surviving half is narrower now: one order
  closes every row *as an expression*, and section 6 records that supplying the first derivative does
  not make the second one the interpolant's — that took resolution, not a further order. **The
  curvature was the test case and it passed**: writing $\Pi_{pp}$ needs $A''$, $C''$, the
  concentration's theorem twice, the vulnerability curve's own slope at each of two potentials, and
  the supply's second collar derivative — and every one of those is a derivative of an integrand or of
  a kernel, never of an integral. A consumer that legitimately wants to differentiate the curvature
  makes the requirement a moving target rather than a property.
- **The carbon channel needs the operating point after all.** The envelope split in section
  1 is why eleven inputs are cheap and why profit survives a lost point. Any path that sets
  profit other than by evaluating the objective at the returned operating point breaks it,
  and the shut-down exits are such paths.
- ~~**The held rows are not free.**~~ Measured, on one build with only the dispatch
  changed, and the two halves finally separated: the held rows agree with the difference
  they replace to $10^{-9}$ at six states and the condition's row does not. What the two
  earlier attempts bundled together was an exact half and a half carrying the transport
  grid's error, and section 3 carries the separation.
- ~~**The curvature from the solve's bracket is worse than a fixed step.**~~ Fired, and
  it went the other way than either arm of this falsifier expected: the two steps give the
  same curvature to a ratio of one, because the interval never bounded the function. §8
  carries the correction.
- ~~**A pinned point is not its bound.**~~ **Fired, and then the size of it was found to be the
  referee's.** The solve returns the wet bound stepped a constant fraction of the *bracket* inside it,
  so $p^\star = (1-\epsilon)\,b_a + \epsilon\,b_b$ and its gradient carries an $\epsilon$-weighted
  share of the **other** bound's row, which the bound's own row does not have. That term is now
  carried, and what it is worth is not a small correction to a row but **three rows that were exactly
  zero**: the wet bound is total uptake, which no stem property and no conductance enters, so the
  maximum conductance's point row read 0 against a differenced 0.0120.

  The $3\times10^{-5}$ this entry reported as *"the size the weighting predicts"* was nothing of the
  kind. It scales as $1/h$, so it is `find_root_psi`'s own tolerance divided by the step, and a
  weighting term is independent of the step. Over a sweep the assembled point row agrees with a
  differenced solve to $3\times10^{-9}$. **A falsifier that fires at a predicted size is worth
  re-reading when the size is available at only one step** — this one fired for the right reason and
  the number offered as confirmation belonged to the instrument.
- ~~**The three unwritten objects have to be written.**~~ **Fired, and all three the same way.** A request
  naming assimilation or the stomatal conductance, the single path's series resistance, and a shut
  collar's own row are the *calibration's* outputs and inputs, not objects: the only consumer of the row
  layer names profit and the uptake block, `set_supply_single` has no caller outside this package's own
  tests, and nothing a shut leaf reports is a function of its collar. What each needed was a named
  refusal in the read and an entry point for the consumer that wants a difference. §7 has the
  measurements. **The next thing to suspect, when a boundary's arguments will not come off, is which
  consumer they belong to.**
- **A row that is read disagrees with the difference it replaced, and the read is wrong.** The two were
  claimed to agree at the solver floor, and at a wet pin they disagree by 5.5 percent in one layer's
  draw. This document reads that as the difference's error, on report 05 §7.0's grounds: the output is a
  near-cancelling residue. The reading is falsified if the read disagrees with something that is *not* a
  difference — the transpose identity of report 02 §3.4 is the instrument, since it needs no reference.
- **The unserved band past the root grid is wider than it looks, or is reached at an interior point.**
  §12's seventh item bounds it between the last knot and where the extrapolation crosses the limit, and
  observes it only at a shade death. An interior point in that band would mean a stand loses water rows
  at a state it is otherwise healthy in, which raises the item from an open row to a forward-model
  change.
- **A restored operating point is not bit-identical to the searched one.** The restore's whole claim is
  that the recorded state reproduces the search's answer exactly, which rests on the recorded state being
  exact, the step sizes being recorded, the tableau being shared and the search being deterministic. The
  check needs no reference: restore, then solve, and compare every output. A disagreement means the token
  is short of something the branch reads — and it also means the restore has become a warm start, which
  carries a tolerance and is refereed by nothing here.
- **A branch that exits before the search still costs enough to be worth restoring.** The token declines
  those four on the grounds that reaching them again is cheap. If a shut or shade-death exit turns out to
  carry real cost — the bound root-finds inside its own feasibility check are the candidate — then the
  decline is a saving left on the table rather than a simplification.
- **The tracked-collar variant cannot be expressed in this interface.** ~~It is instantiated
  at `double` only, so the check has never been able to fire.~~ **Fired.** A translation
  unit that instantiates it at an active scalar and is never run reports two errors and one
  silence, and the silence is the result. The collar is handed to a routine taking a plain
  `double`, twice, because the leaf underneath is a double-only model — those the compiler
  catches. What it does not catch is the profit gradient: the field is the active scalar and
  the function returns a `double`, so the assignment is a legal widening that drops the
  derivative, and the tracked state's rate then carries a **structural zero** for every
  trait reaching the collar. Finite, plausible, no diagnostic.

  So the easy case — a collar that needs no implicit solve, no stationarity condition and
  no curvature, whose derivative should arrive from the adjoint like any other state's —
  cannot be written here. That is the falsifier's own symptom, and what it indicts is not
  the variant: the boundary was carved around the argmax and cannot express a collar that
  is simply a state.
