# What the gradient means: the ecology behind the derivatives

Companion to [`05-reverse-mode-mathematics.md`](05-reverse-mode-mathematics.md), section for
section. Report 05 says what each derivative *is*. This says what each one *means*, and what it
would be wrong to conclude from it.

The intended reader is an ecologist deciding whether a number this machinery produces answers their
question, and a developer deciding whether a defect matters. Its second purpose is to make the
ecological content of the design falsifiable: several choices in report 05 are defensible
mathematically and carry an ecological commitment that is easier to argue about when stated in
words.

---

## 1. What question the gradient answers

The model grows a patch of forest from bare ground: seeds arrive, individuals compete for light and
water, they grow and die, and the stand assembles itself. A **census** is a summary of that stand
at some age — its leaf area, its above-ground mass, its basal area.

The gradient answers: **if one plant trait were slightly different, how would the stand differ?**
Not one plant — the whole assembled stand, including every consequence that runs through
competition. A leaf that is slightly cheaper to build shades its neighbours slightly more, so they
grow slightly less, so they shade it back slightly less, and the stand that emerges is different in
ways no single-plant calculation reaches.

That is why the derivative is worth this much machinery. The quantity is not
$\partial(\text{one plant's growth})/\partial(\text{trait})$, which is calculus on a formula. It is
the derivative of an **emergent** property through a hundred years of feedback.

### Why 44 traits at once, and why that forces reverse mode

The traits are not a shortlist. They are the whole physiological parameterisation: leaf economics,
wood density, allocation, hydraulic vulnerability, photosynthetic capacity, mortality and reserve
dynamics. An ecologist asking "which traits does this outcome depend on, and how strongly" wants
all of them, ranked.

Getting that by re-running the model once per trait costs 44 runs. The adjoint costs one run and one
sweep, whatever the number of traits. **This is the whole reason the project exists.**

The practical consequence is that the gradient is only useful if it is *complete*: a ranked list of
44 sensitivities with four of them silently zero is worse than no list, because the zeros read as
"this trait does not matter" — which is exactly the kind of conclusion an ecologist would publish.

---

## 2. What the state variables mean

| Report 05 | What it is ecologically |
|---|---|
| $h_k$ | the height of a cohort — every other size follows from it by allometry, so height *is* the size coordinate |
| $\ell_k = \log n_k$ | how many stems that cohort represents, per unit ground area, in logs because densities span orders of magnitude and go to near-zero without reaching it |
| $b_k$ | when that cohort germinated |
| $m^{\mathrm{hw}}_k, a^{\mathrm{hw}}_k$ | heartwood: wood that has stopped respiring. It accumulates and is never lost, which is why it is a state and not a function of size |
| $r_k$ | stored sugars. The buffer between carbon gain and growth, and what lets a shaded plant survive a bad year instead of dying in it |
| $\theta_j$ | how wet each soil layer is |

**The coordinate choice is an ecological statement, not a numerical one.** A density in height says
"here is how many stems are this tall". A density in birth date says "here is how many stems
germinated then, and here is how tall they now are". The two describe the same stand.

They differ in what can go wrong. In height, two cohorts can *cross*: a plant with more reserves can
overtake one that germinated earlier, so the size ordering stops matching the age ordering, and the
density has to be re-sorted. In birth date, germination order is fixed once and for all and nothing
can reorder it. Report 05 records this as "the abscissa cannot invert". Ecologically it is the
observation that **plants can change their relative size but not their relative age.**

That is why the reverse-mode gradient is scoped to birth date. The height coordinate is not wrong;
it is a coordinate in which a legitimate biological event — the overtaking of one cohort by another,
which reserve-gated growth makes common — turns into a numerical special case.

---

## 3. Why the model is a composition, and what that means for feedback

Report 05 writes the model as a chain: traits, then each plant's size, then the shared environment,
then each plant's physiology, then the rates.

The ecologically important feature is the *shape* of that chain. Two arrows point differently:

- **Every plant reads the same environment.** The light profile and the soil water are shared. One
  arrow, many readers.
- **Every plant writes into that environment.** Its leaves shade, its roots draw water. Many
  writers, one sum.

Competition is exactly the second arrow. There is no direct plant-to-plant term anywhere in the
model — no plant knows about any other plant. They interact *only* through their contributions to
shared fields. This is what makes the model tractable and it is what makes the adjoint tractable
too: the reverse pass handles each plant independently and then does one pass to redistribute the
environment's sensitivity.

**A consequence worth stating plainly.** When the gradient tells you a trait matters, part of that
is the direct physiological effect and part is the competitive one, and the machinery does not
separate them. A trait that makes a plant grow faster in isolation may show a small stand-level
gradient because everything else grows faster too. Interpreting a sensitivity as a physiological
effect is a mistake the number cannot warn you about. Section 9 describes the one object in this
machinery that does not have that problem.

**There are two shared fields and they are not symmetric.** Plants read the light field *before*
they decide anything, and write into the water field *as a consequence of* deciding. So the light
coupling is a competition for a resource already allocated, and the water coupling is a competition
mediated by behaviour. Section 7 is where that asymmetry becomes a second derivative.

---

## 4. What the solver's adjoint means, and the one thing it deliberately ignores

The forward model steps through time. The adjoint runs the same trajectory backwards, carrying "how
much does the final census care about this quantity, at this moment".

The ecological reading: **influence accumulates backwards along the trajectory.** A trait acts on
the stand at every instant, and the gradient is the sum of those actions weighted by how much each
one still mattered by the end. Early actions matter through everything they set in motion; late
actions matter directly.

### The step size is held fixed, and that is a modelling decision

The solver chooses its own time steps adaptively, taking small ones when the stand is changing
fast. Report 05 holds those step sizes constant on the reverse pass.

This is worth being explicit about, because it looks like an approximation and is not. The step
sizes are a property of the *numerical method*, not of the forest. Letting the gradient flow through
them would compute how the error controller responds to a trait change, which is not an ecological
quantity and would contaminate the answer with the solver's internals. **Holding them is the choice
that makes the gradient a derivative of the model rather than of the program.**

### Cohorts appear during the run, and that is where seed production enters

New cohorts are introduced as the run proceeds — the model does not know in advance how many it will
need. Ecologically, each introduction is a germination event, and its size is the seed arrival rate
times the fraction that establish, divided by how fast a seedling grows out of the smallest size
class.

That division is a bookkeeping consequence of carrying a density in **height** rather than a count:
a seedling that grows quickly spends less time being that tall, so it contributes less to the
density there. **On the birth-date coordinate the division is absent** — nothing moves a plant along
a germination-date axis — so on the coordinate the gradient runs on, the boundary condition is
simply seed arrival times establishment probability.

This is a real path from traits to the census, and one a reader would not guess from the
physiology. A trait affecting germination or establishment reaches the stand *here*, not through any
plant's carbon balance.

**A germination event also provisions the seedling**, and that is a second ecological channel at the
same boundary: the initial reserve is a trait times the storage capacity, so how well a seed is
stocked reaches the census directly. That is a real establishment strategy — the difference between
a species that scatters many cheap seeds and one that provisions a few — and it enters nowhere else.

---

## 5. What one recorded step is

Report 05's unit is one plant's physiology evaluated once: it reads its own size, the light and
water available to it, and the traits, and it produces its growth, its mortality, its seed output,
and how much water it drew from each layer.

Of its 185 inputs, **130 describe the light profile** — the numerical face of the ecological fact
that a plant's performance depends far more on the shape of the canopy above it than on anything
about itself.

**But the plant does not read 130 numbers; it reads one.** Its whole physiology is driven by a
single scalar — the light at its crown centre, or the leaf-area-weighted mean over its crown,
depending on the shading model. Everything the canopy does to a plant, it does through that one
number.

### The averaging assumption, and which plants it misrepresents

**The model assumes a plant responds to an average of the light it sits in, not to the profile.**
Photosynthesis saturates, so averaging the light and then photosynthesising overestimates gain
relative to photosynthesising and then averaging. The direction is unambiguous.

The picture that phrase invites — upper leaves in sun, lower leaves in deep shade — is **not this
model's crown.** At the default crown shape, 86.7 percent of a crown's leaf area sits in the top 20
percent of its height, and 99.95 percent above half its height. The crown is nearly a flat top. So
averaging is nearly exact for an emergent, whose whole leaf shell is in full sun, **and** nearly
exact for a fully suppressed plant, whose shell sits in one nearly uniform understorey light.

**The plants it misrepresents are the mid-canopy and gap-edge individuals**, whose leaf shell
straddles the top of the canopy below them. That is exactly the cohort whose fate decides whether a
stem reaches the canopy or dies suppressed, and the bias runs in the direction that matters:
averaging overestimates carbon, hence growth, hence height, hence escape.

**What has been measured is a demographic amplification, not the carbon bias.** Mean light gives
lifetime offspring production 3.33 times the deep-crown mode's — 8.28 against 2.48 — at a patch
lifetime of 20, one trait, one species. But offspring is a strongly non-linear functional of carbon:
it passes the establishment gate and then compounds for twenty years. So **3.33 is a stand-level
demographic amplification of a per-plant carbon bias that has never been measured**, at a
configuration that is not production, and the ratio may not be lifetime-invariant.

**So the honest disclosure is not "the objective is biased by 3.33 times".** It is that the
sensitivities are taken about an operating point that overestimates carbon for mid-canopy stems, by
an amount nobody has measured per plant — and **the only mode that would measure it has no
derivative**, so the gradient is available only under the averaging assumption. That is a scope
limit on the question rather than on the arithmetic, and it is measurable *forward*, at a handful of
states, which is affordable and has not been done.

### Why the coordinate change removes work

In the height coordinate, the density obeys $\dot\ell = -\mu - \partial g/\partial h$. The second
term says that where growth accelerates with size, cohorts spread apart and the density thins; where
growth decelerates, they pile up. It is a real effect — the compression of the size distribution —
and computing it requires asking "how fast would this plant grow if it were slightly taller", which
means solving its entire physiology again at a displaced height.

In the birth-date coordinate, $\dot\ell = -\mu$: **the density changes only because plants die.**
Nothing about growth appears, because germination dates do not spread apart or pile up. The
compression is still there in the model — it reappears when you convert back to a distribution over
height — but it is no longer something the rate equation has to compute.

So the coordinate change removes one extra physiological solve per plant per step, or eight if
Richardson extrapolation is on. The ecology is unchanged; only the bookkeeping moves.

### Two states of a plant have no gradient, and one of them is drought

**A plant in carbon deficit is frozen, not draining.** Once reserves go negative, the outflow gate
closes exactly, and the reserve sits where the overshoot left it with mortality pinned at maximum
until production turns positive again. Ecologically this is a plant that has spent its buffer and is
waiting to die or to be rescued — a real state. Mathematically it is an absorbing flat region, and
**every derivative out of the reserve vanishes there.**

Two things follow that matter for interpretation. The frozen set and the negative-production set are
**the same set**, forced by the algebra rather than by any driver — so a drought raises the frozen
fraction one-for-one, and **differentiating a drought is partly differentiating a flat region.** But
the plant does not go gradient-dark: growth flux still reads the reserve gate, which is bounded away
from zero, so height, fecundity and heartwood all keep a live channel. The expensive interior-case
derivatives are not wasted at a frozen cohort — they are the only live channel out of it.

**And the gate that produces this has replaced the model it was meant to smooth.** It is centred
near the bottom of the reserve range with a width of a tenth, which on a relative reserve in $[0,1]$
means its transition occupies **40 percent of the whole domain.** A plant with *empty* reserves
still grows at 27 percent of its production rate, and a plant with full reserves has a gate
derivative three orders of magnitude smaller than one in the band. So it is **not a hard switch
wearing a smooth coat but a mollifier wide enough to be the model** — and it damps the gradient
wherever reserves are high. The distribution of relative reserve across a real stand is the one
number this turns on, and it has never been reported.

**Establishment, by contrast, needs no smoothing and would be damaged by it.** The establishment
probability and its first derivative both go to zero as production goes to zero, so it is already
smooth at the threshold and the zero arm is its correct continuation. Its own transition scale is
narrower than any smoothing width used elsewhere in the model, so mollifying it would widen a
transition the model already resolves and change recruitment. What is true is that the region is
*stiff*: a marginal recruit's establishment probability is extremely sensitive to its carbon
balance. **The right answer for a recruit that cannot pay for itself is exactly zero**, and report
05 shows that is what the mathematics gives, provided the sensitivity is carried in stem number
rather than in its logarithm.

---

## 6. What the environment reductions mean

### 6.1 Light

Report 05's canopy equation reads right to left: each cohort casts shade according to its leaf area,
distributed vertically by a shape function saying what fraction of that leaf sits above a given
height; the shading is scaled by an extinction coefficient; and the contributions are summed over
every cohort weighted by how many stems it represents.

The transposes answer "if the canopy at this height mattered, who is responsible?" — and the answer
has three parts: **how many** stems a cohort has, **how tall** they are, and **what kind of plant**
they are.

**The third part is where the trait content of competition lives, and it is four parameters wide.**

- **The extinction coefficient** is how opaque a canopy of this species is — a light-capture
  strategy, not a bookkeeping constant.
- **The crown shape** is the vertical distribution of leaf area, whether a crown is top-heavy or
  evenly spread. A well-studied axis of tree architecture.
- **The two allometric constants** set how much leaf area a stem of a given height carries, which is
  how much shade it casts. They also reach the census by other routes, which makes them the subtle
  case: their rows are non-zero and incomplete rather than absent.

**The shape of a failure here is worse than a zero.** The extinction coefficient also appears inside
each plant's own physiology, as a self-shading coefficient on the radiation it absorbs, and that
path is differentiated correctly. So the number an ecologist reads is **real, plausible, and short
by the competitive half** — the part that says how much this species' opacity matters *to its
neighbours*. A zero at least looks suspicious. A number that is right in its self-shading and
silent about its shading of others looks like a finding.

**The crown shape is a different case: it has no row at all**, because it is not among the
differentiated parameters. It is excluded for a numerical reason — a derivative that is undefined
where a crown's relative height reaches zero — so closing the reduction's gap gives it nothing until
that exclusion is lifted. A well-studied axis of tree architecture is currently not a question this
machinery can be asked.

**And one hazard here is caused by the gradient's own user.** The light reaching the ground falls
exponentially in the extinction coefficient times leaf area index, and the model floors the light
away from zero. So a calibration or a trait search that walks the extinction coefficient upward
walks the canopy into the region where the floor binds and the row it is ascending goes to zero.
That is a closed loop between the answer and the question, and it has no analogue anywhere else in
the design.

### 6.2 Water

The water aggregate is the same shape: total draw from a soil layer is summed over plants, and the
soil responds by drying. The transpose asks which plants were responsible for a layer mattering.

**The soil's own parameters have no rows at all.** The retention curve's scale and exponent, the
saturated conductivity, the water contents at saturation and residual, and the infiltration
constants are properties of the environment rather than of any plant, so they sit in no parameter
list. The consequence is a question that cannot be asked: **"what if the soil were sandier."** The
vertical structure of the root coupling is in the same position, and so is the root's own critical
potential.

**Two facts about this soil change how a drought reads.**

The layers are **independent buckets** on the relevant timescale: conductivity at operating moisture
is about a thousandth of the rainfall forcing, so rain reaches the top layer only and drainage
between layers is negligible. **The only resupply a deep layer has is a plant pushing water into
it.** That makes hydraulic redistribution — roots moving water from wet layers to dry ones — a
normal feature of a layered root system in this model rather than an exotic case. And it means a
statistic formed on a plant's *total* uptake cannot see it: the ordinary condition is per-layer
negatives inside a positive total.

And the model's potential ceiling is **not a benign clamp but an unbounded plant-to-soil sink.**
Past a certain dryness, the root resistance saturates instead of diverging, so the flux grows
linearly in the layer's potential and runs the wrong way: the model rewets a very dry layer out of a
plant that has nothing to give. Its reachability is ordinary rather than extreme — a wet top layer
with a dry layer beneath it is the standard dry-season profile, and whole-plant shutdown is decided
on the *wettest* layer, so the plant stays alive while one of its layers is poisoned. **This is a
defect in the forest being modelled, not in its derivative**, and an ecologist reading a drought
sensitivity is reading a derivative of it.

**A crossed stand is where the reverse pass and the forward model part company.** The forward
reductions were taught to handle cohorts in a jumbled size order; a transpose that tests height
ordering was not. On a stand where cohorts have crossed — which happens whenever reserves let a
younger plant overtake an older one — the forward runs and the adjoint stops. And **the coordinate
choice does not rescue this: it inverts it.** The forward tolerance exists *because* germination
order stays monotone whatever the heights do, so on the coordinate the gradient is scoped to,
crossing is *more* common, not less.

---

## 7. What the plant's decision means

This is the ecologically richest part of the design and it is worth understanding before trusting
anything downstream.

### The decision itself

A plant with leaves and roots faces a trade-off. Opening its stomata lets in CO₂ to
photosynthesise, and lets out water. Losing water pulls its internal water potential more negative,
and past a point the water columns in its xylem break — embolism — which costs it conductive tissue
it cannot cheaply replace.

So it chooses: gain minus hydraulic cost, maximised over how hard the plant is willing to pull.
Every plant in this model solves that optimisation at every moment of its life. **It is a model of
behaviour, not a formula**, which is why the derivative needs care.

### Why profit is free, and what that means biologically

The envelope theorem has a clean ecological reading. **At the optimum, the plant is indifferent to
small changes in its own decision** — that is what being at a maximum means. So if the environment
shifts slightly, the resulting change in profit is entirely the direct effect of the environment;
the plant's re-optimisation contributes nothing to first order.

This is not a numerical trick. It is the statement that a well-adapted plant's performance is
insensitive to small errors in its own behaviour, and it is why the most expensive part of the model
costs nothing to differentiate for the quantity that matters most.

### Why water use is not free

The plant is indifferent about *profit*. It is not indifferent about *water*. Shift the
environment, and the plant re-optimises, and its water use changes as a result — and that change is
a real effect on every other plant sharing the soil.

So the expensive derivative is needed for exactly the quantity that mediates competition. The
design's economy is to notice that this channel is *one number wide*: the plant makes a single
scalar decision, so all its knock-on effects flow through that one decision.

### The repricing, and why it is the number the model turns on

Report 05 calls the mixed second derivative $\Pi_{pu}$ "the one genuinely new object". Here is what
it means.

The marginal profit $\partial\Pi/\partial p$ is **the plant's marginal water-for-carbon exchange
rate**: how much extra carbon it buys per unit of extra xylem tension it agrees to carry. At the
optimum that quantity is zero — the last unit of risk exactly pays for itself. This is the marginal
cost of water, and it is what every optimal-stomata theory since Cowan and Farquhar has been about.

$\Pi_{pu}$ is **the rate at which the environment reprices that exchange.** When the soil dries, or
the light above shifts, or a trait moves, by how much does the plant's marginal willingness to pay
in water change? Three readings, each a statement an ecologist would recognise.

**1. It is stomatal sensitivity, and it is where isohydry lives.** How far the operating point moves
is what a gas-exchange campaign measures. $\Pi_{pu}$ is *why* it moves: the response is the
repricing divided by the curvature of profit. A plant with strong repricing and flat profit swings
its stomata widely; one with weak repricing and sharp curvature holds its potential nearly constant.
**Isohydry against anisohydry is a statement about the ratio of the two.**

**2. It is acclimation.** In the variant where the collar potential is a state ascending the
marginal profit, the forcing on that state *is* the marginal profit, and the rate at which the
forcing changes when the environment changes *is* $\Pi_{pu}$. So it decides whether an acclimating
plant tracks the weather or lags it. In the base model, where the optimisation is instantaneous, the
same number is the implicit assumption that acclimation is infinitely fast.

**3. It is competition, and this is what makes it worth the code.** Plants interact only through two
shared fields. The water field is depleted by uptake, and uptake sits downstream of the plant's
decision. So the causal chain by which one plant's drinking changes another's behaviour is: my
uptake lowers the soil potential, which **reprices your exchange rate**, which moves your operating
point, which moves your uptake. **$\Pi_{pu}$ is the first link of the only belowground competitive
coupling this model has.** A stand where it is large is one where water competition is a behavioural
cascade; where it is small, plants draw down a common pool without responding to each other at all.
That is the difference between two qualitatively different forests, and it is one mixed second
derivative.

**And now the warning.** Water moves on *differences* of potential while tissue fails on
*absolutes*, so along the uniform drying direction the model is a near-symmetry: the true flux
response is a small residue on a channel amplified fifteen- to twenty-six-fold. $\Pi_{pu}$ along
that direction is therefore a **small difference of large quantities**, and the corpus's own rule is
that such a thing must be computed as itself rather than by subtraction. So the single number that
carries belowground competition is the one most exposed to being computed the one way that cannot
compute it — which is why report 05 treats it as a correctness item and not a cost item.

### The pinned plant, which is a real biological state

Sometimes the optimum is not interior: the plant would like to transpire less than zero, or more
than its hydraulics allow. Then it sits at a limit, and the envelope theorem stops applying.

This is not an edge case to be tolerated. It is **drought**. A plant pinned at its zero-uptake bound
has closed down; a plant pinned at its critical potential is operating at the edge of hydraulic
failure. Both are states the model exists to represent, and they are the states in which the
derivative is structurally different — the plant is no longer indifferent to its own behaviour,
because it is not choosing freely.

The practical implication: **any conclusion about drought sensitivity depends on the pinned branch
being right**, and the bound's own derivative is carrying the ecology in that regime.

### Some terminal states are not plants at all

The implementation distinguishes more cases than the biology does, and the distinction matters
because each one either is or is not a state of a forest.

- **A rejected search step** and **a non-negative curvature** are the solver reporting that it could
  not move. No plant is described. They are one case, not two, and attributing them to whichever
  bound is *nearer* returns the derivative of a bound the plant is not sitting on — a finite,
  plausible, wrong number. **They should refuse.**
- **An unresolved optimum** is a plant physiologically identical to the interior case whose
  optimisation was not converged to the tolerance the envelope theorem needs. This is the most common
  non-clean exit on a production run, and its error budget has never been set.
- **A trait-consistency failure** — the root's critical potential drier than the stem's — is not a
  soil state at all. It is a parameterisation in which root hydraulics fail before stem hydraulics,
  and **a gradient-driven trait search is exactly the thing that will walk into it.** It must refuse
  loudly, naming the inconsistency, or a sensitivity walk silently changes model. A rooting depth
  pushed past the soil column is the same kind of failure, and there the root mass silently
  vanishes.

**And one case is the same plant as a case already listed.** A plant whose gross assimilation cannot
cover its dark respiration, and a plant pinned at zero uptake, are the same plant approached from
opposite sides of one threshold: **there is no tension at which water pays for carbon.** Any
separation between them is control-flow history. Note this is the *shade* mortality regime rather
than a drought one, so it is governed by light and invisible to any rainfall sweep — and the
averaging assumption of section 5, which overestimates carbon gain, overestimates precisely the
quantity whose sign defines it. It is probably the most under-measured state in this model.

**These are not unrelated corners. They are consecutive segments of one drydown**, and a real
rainfall sequence traverses them in order: an interior optimum while the stand is wet, a pinned
optimum as it dries and grows tall, a substituted feasible point as the window closes, and a
shutdown once the window is gone. That is why incidence measured on a wet driver says nothing about
a dry one.

### One case is the best-conditioned in the model and reads as a corner

At the operating point of zero *total* uptake, the per-layer fluxes are individually non-zero and
sum to zero. That is **pure root-mediated redistribution** — a plant moving water between layers
without taking any up — and given that a deep layer's only resupply is a plant pushing water into
it, this is a real and important behaviour rather than a degenerate case. Its derivative exists in
closed form. Its relative accuracy under any differencing scheme is the worst in the model,
precisely because the output *is* the residue of a near-cancellation.

### The vulnerability curve, and the one parameter that is refused

The hydraulic vulnerability curve says what fraction of conductivity survives at a given water
potential. Its two parameters are position and steepness — where the curve sits, and how abruptly
conductivity is lost. These are among the most-measured traits in plant hydraulics and among the
most ecologically interesting, because they set where a species sits on the drought-tolerance
spectrum.

**A curve has two degrees of freedom per organ, and that is what a physiologist measures.** The
model derives the critical potential from position and steepness — it is a property of the same
curve, not an independent trait — and then registers all three as differentiable parameters. So a
reported sensitivity to curve position is taken *with the critical potential held fixed*, which is
not a perturbation any plant can undergo. A gradient reporting three numbers per organ for a
two-parameter curve is over-parameterised, and the third answers a counterfactual that does not
exist. The critical potential's sensitivity is real, but it belongs *inside* the position and
steepness rows, which is where someone reading the output would look for it.

**This is settled, and settled in the ecology's favour.** The model's construction also ties the
stem curve's steepness to its position by a fitted trade-off, which on one reading would leave a
stem curve with only *one* degree of freedom and describe the two organs inconsistently. The ruling
is that the trade-off is a **default for choosing initial values, not a constraint on the curve**:
two species can share a curve position and differ in how sharply they lose conductivity, which is
what the measurements show. So both organs get two numbers and the critical potential follows from
them.

**What is refused, and why the reason is worth understanding.** The potential at which half of
conductivity is lost — the single most reported number in plant hydraulics — is not offered. Not
because it does not matter, but because **setting it in this model changes nothing**: the curve is
built from it once, at construction, and afterwards the curve is what it is. A sensitivity to it
would describe a model that re-derived the curve when you moved it, and no such model is
implemented. Asking for a curve's position is asking for the position parameter itself.

This is the clearest case in the model where the ecology dictates the output format rather than
merely interpreting it. Report 07 §3 shows that the format is a small matrix, and that once it
exists a measured parameter can be offered whenever the model genuinely derives from it.

---

## 8. What the census means, and the routes a trait takes to reach it

A stand's leaf area changes with a trait for two reasons. **The stand is different** — different
plants, different sizes, different numbers, because the trait changed how they grew and competed.
And **the measurement is different** — the same plant, converted to leaf area by a formula that
itself contains the trait.

The first is the trajectory term and it is what the whole adjoint machinery computes. The second is
a one-line calculation at the final state. It is easy to forget precisely because it is trivial, and
forgetting it is silent: the answer stays finite and plausible.

**Six routes are known, and "six" is a count of routes found rather than a closed set.** Four are
the ones a reader would guess: the measurement formula, each plant's physiology, germination, and
the shared canopy. Two were missed by an enumeration that declared itself complete:

- **The soil.** Water aggregates across plants exactly as light does, and the retention curve reads
  parameters directly. So belowground traits reach the census by a route structurally identical to
  the canopy's, and it has the same missing accumulator. **Every ecological statement about the
  extinction coefficient and the crown shape applies to the soil parameters too.**
- **What a seed starts as.** The initial reserve is a trait times the storage capacity, so how much
  a seedling is provisioned reaches the census directly. That is a real establishment strategy and it
  was unlisted.

**The general lesson for anyone reading a sensitivity from this machinery.** A completeness claim in
a design document licenses a reader to stop looking, and this one was wrong by two routes out of
six. Treat the list as the routes found so far.

**And the census itself must be taken on a monotone grid.** A quadrature over a crossed size
distribution has neighbouring trapezia cancelling instead of accumulating, so leaf area,
above-ground mass and basal area can be wrong *before* any derivative is taken. The two field
reductions each guard this. The objective is the first link in the chain and the least guarded.

### One assumption is imposed rather than derived

The seed's initial height is treated as independent of the traits. Ecologically that says **every
species starts at the same size regardless of its traits**, which is false: seed size and seedling
establishment size are traits, and they covary with the leaf and wood economics the gradient is
differentiating. Eight parameters are affected, through both the establishment probability and the
density boundary condition.

The measured consequence is about 3 per cent for leaf mass per area. What makes it worth flagging
beyond its size is that **neither available reference can detect it**: the forward tangent makes the
same assumption, and a re-run finite difference cannot be used at production because the stand
collapses discontinuously under a tiny trait perturbation. So this is the one defect where "we
cannot currently tell" is the honest statement.

---

## 9. What the adjoint state means, and the question it answers that a trait gradient cannot

The reverse pass carries a sensitivity over the state, backwards, segment by segment. The trait
gradient is one contraction of it. The object itself is discarded at each segment boundary — and it
answers a different question, one an ecologist is more likely to ask.

Per cohort and per time, the adjoint state is:

- **how much the final census depends on how many stems** that cohort carries at that moment;
- **on how tall** they are;
- **on how much carbon they have stored.**

That is a **demographic influence function**: which part of the size distribution, at which point in
the stand's history, drives the outcome. Section 3 argues that a trait gradient mixes physiology
with competition and cannot separate them. The influence function does not have that problem,
because **it is a statement about the stand, not about a parameter.** No trait is involved, so
nothing needs disentangling.

### It answers questions about interventions, not only about description

A perturbation to the state at a time changes the census, to first order, by the inner product of
that perturbation with the adjoint state at that time — whatever the perturbation is. So:

- **Thinning.** Removing a fraction of stems from cohorts in a size class is a shift in their log
  densities. The census response is that shift times the summed density-adjoints of the class.
- **A disturbance at one age** — a planting, a defoliation, a drought year applied to reserves — is a
  state perturbation at a time, and each is one inner product.

**One recording therefore answers "what happens if I intervene, in this way, at this time" for every
size class and every year at once**, to first order. A finite difference pays a full re-run per
intervention per timing. Keeping the adjoint state costs storage and no computation.

**Limits, stated plainly.** It is first order, so it is a marginal analysis and says nothing about a
large intervention. The model is one patch under a disturbance regime, so "management" is a loose
reading. And it inherits every scope limit in this report — **an influence function built on a
biased operating point is wrong in exactly the way the gradient is wrong, and it is *more*
dangerous, because it looks like a description of the stand rather than a derivative and so invites
less scepticism.**

That last point is a sequencing constraint, not a caveat: the influence function should not be
exposed before the correctness items are closed.

---

## 10. What would make this gradient trustworthy to an ecologist

Not a green test suite. Three things, in order:

1. **No zeros that are not real zeros.** A trait reading zero must be a trait the model genuinely
   does not use, and the boundary must refuse a trait it cannot answer for rather than returning
   zero. An exact zero in this design is the signature of a missing accumulator and never of true
   insensitivity, which makes it indistinguishable from an ecological finding.
2. **Agreement with an independent method on a case small enough to check by hand.** A forward
   tangent on a two-cohort stand, agreeing to solver tolerance, is worth more than any amount of
   internal consistency — because internal consistency is exactly what a wrongly-transposed
   reduction preserves.
3. **A stated domain.** Which coordinate, which traits have rows, which states are refused, and what
   the known biases are. A gradient with an honest domain is usable; a gradient that answers every
   question is not trustworthy.

The largest current risk is not any single defect. It is that **every defect produces a finite,
plausible number** — wrong signs, wrong magnitudes, silent zeros — and none of them produces an
error. An ecologist reading the output has no way to tell.

---

## 11. The domain, stated — which is section 10's third condition, discharged

**Read this as the text that must accompany any number this machinery produces.** It is not a defect
list; the defects belong to the plan. It is what the answer is *about*.

### The coordinate

**The birth-date coordinate only.** The gradient must refuse the height coordinate at every entry
point, because there the reductions transpose one coordinate while the forward model integrates the
other, and the result is finite, plausible and wrong.

Two consequences an ecologist should know. The two coordinates are **different functions**, not two
discretisations of one — the leaf-area sensitivity to leaf mass per area differs by a quarter
between them, and the above-ground-mass sensitivity **changes sign**. And on the birth-date
coordinate the introduction schedule *is* the quadrature grid, so refining the schedule changes the
abscissa the resource integrals are taken over.

### Which traits have rows

| | traits | status |
|---|---|---|
| **complete** | most of the 44 registered parameters, through the recorded cohort step | the gradient is theirs |
| **short, and by a measured amount** | the extinction coefficient — live but 3.041 percent low, missing the field-build half of its own definition | a finite number wrong in a stated direction: more opacity shades neighbours more, so the missing channel is negative and the row is too large |
| **short, unmeasured** | the two allometric constants, and the crown shape once registered — the reduction's contribution is dropped | same shape as above, size unknown |
| **exactly zero by construction, undeclared** | eight parameters **through birth size** — leaf mass per area, seed mass fraction, both allometric constants, wood density, and the stem-area, root and bark constants | a real channel imposed to zero. Worth about 3 percent for leaf mass per area |
| **absent — no row anywhere, ever** | the root's critical potential; every soil parameter — saturated conductivity, the retention curve's scale and exponent, the saturation, residual and ceiling constants, the infiltration pair, **times the layer count** if per-layer; the root depth shape; the two root-allocation constants | **"What if the soil were sandier" cannot be asked.** Nor can the vertical structure of the root coupling |
| **refused by name** | eleven registered-looking parameters that reach no equation, and the half-loss potential, which the model reads once at construction | correct behaviour: a refusal, not a zero |
| **over-parameterised** | the vulnerability curves carry three registered numbers per organ for a two-degree-of-freedom curve | the third answers a counterfactual no plant can be subjected to |

### Which states are refused, and which are silently answered instead

The gradient is valid at an **interior stationary optimum** and at a **genuine bound**, where the
answer is a Lagrangian rather than a free envelope. It is **not** valid, and today is not refused,
at: a rejected search step or a non-concave point (neither is a plant); a non-finite residual; a
sentinel zero recorded as a converged optimum, where the curvature is exactly zero and the argmax
multiplier divides by it; the shutdown and zero-transpiration substitutions, which solve no
optimisation at all; a collapsed feasibility window; and the acclimating variant, whose operating
point is a tracked state rather than an argmax.

**Refusal is metric-level.** A refusal anywhere in one census metric's sweep makes that metric's
entire gradient undefined — a sum has no defined value with an undefined term, and no localisation
is available. The metrics are independent of one another.

### The biases, and their sizes where known

- **Mean-light averaging.** One physiology at the crown's mean light. Nearly exact for an emergent
  and for a fully suppressed plant; it misrepresents the **mid-canopy and gap-edge** stems whose
  leaf shell straddles the canopy below them — the cohort whose fate decides whether a stem escapes
  or dies suppressed. Direction certain, per-plant size unmeasured. The mode that would measure it
  has no derivative.
- **Birth size.** Imposed to zero; about 3 percent for leaf mass per area.
- **The extinction coefficient.** 3.041 percent, direction known.
- **The dominant's height.** The knot positions are passive, so the plant that sets every other
  plant's light has a height adjoint short by a term measured at about 87 percent of that adjoint —
  though whether it shrinks with knot density has never been checked.
- **The reserve gate.** A mollifier occupying 40 percent of the reserve's domain, damping the
  gradient at high reserves and admitting growth at empty ones. Direction and size both unstated,
  because the distribution of relative reserve across a stand has never been reported.
- **What no measurement covers at all.** **No plant in this corpus has ever been run in shade** —
  ground-level transmittance median 0.9997, an open woodland — **or in drought**: soil potential
  never drier than 0.17 MPa, which is the initial condition. Every incidence figure quoted anywhere
  is a property of that one driver.

### And the sentence that matters most, about drought

An ecologist asking about drought is asking about a **response**: what changes when the water runs
out. What this machinery computes in a drying stand is a derivative **holding the active set
fixed** — the bound active, the reserves frozen, the clamp engaged. That is a legitimate object, a
one-sided directional derivative on one stratum of a piecewise-smooth map, and it is a usable local
trait sensitivity *within* that stratum.

**But the drought response is precisely the stratum change.** So the composed drought gradient is
valid and it is the wrong instrument for the question, and the failure is one of **domain, not of
correctness**. The honest interface emits it **with its active set attached.**
