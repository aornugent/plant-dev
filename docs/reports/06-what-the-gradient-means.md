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

**The size of that effect is not a rounding correction, and it is not even sign-preserving.**
Measured by taking the same trait gradient with the environmental response suppressed and then
restored: leaf mass per area is suppressed by a factor of about **7.4**, and the seed-mass trait
**changes sign**. So the feedback is not a modest damping of a physiological signal — for at least
one trait it is the whole of the answer, and a reader shown the frozen-environment number would draw
the opposite conclusion. This is the concrete reason the endogenous feedback is worth the machinery
rather than an assumption worth making.

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

**The plants it misrepresents are the ones just reaching the canopy top**, and the per-plant bias has
now been measured. Aggregating the leaf submodel over a crown exactly as the production path does, in
a 20 m canopy carrying 6 m² of leaf per m²:

| focal height | mean crown light | profit ratio, mean-light over deep-crown |
|---|---|---|
| 0.5 to 12 m | 0.0498–0.0500 | **1.0000** |
| 16 m | 0.0572 | 1.0020 |
| 18 m | 0.0898 | 1.0376 |
| **20 m** | 0.3166 | **1.2829** |
| 21 m | 0.5434 | 1.2745 |
| 25 m | 0.9332 | 1.0347 |
| 30 m | 0.9922 | 1.0038 |

**The bias is confined to a narrow band at the canopy top, and the reason is this section's own
observation about crown shape applied twice.** Because $\tilde Q$ is near 1 below four-fifths of
relative height, the light profile is nearly flat through the bottom three-fifths of the canopy — the
field is 0.0498 at the ground and 0.0504 at three-fifths of canopy height. **A plant is misrepresented
only where its own leaf band overlaps the canopy's gradient band**: its leaf sits in the top fifth of
*its* height, and the light gradient sits in the top fifth of *canopy* height. Those coincide exactly
once, for the cohort arriving at the canopy top.

So a suppressed plant sees a uniform light and its bias is under a tenth of a percent, and a
**well**-emergent plant is in full sun and its bias is under half a percent. **"Nearly exact for an
emergent" is true only of a well-emergent plant** — the plant that is *only just* emergent is the
worst case in the model, at 28 percent.

**The ecological conclusion survives and sharpens.** The biased cohort is still the one whose fate
decides whether a stem escapes or dies suppressed — it is *only* that cohort, which makes the bias
more targeted than a diffuse "mid-canopy" reading suggests, not less consequential.

**And the direction is now guaranteed rather than argued.** Profit is concave in absorbed radiation
across the whole openness range, with monotonically decreasing slope, so Jensen's inequality applies
to the TF24 value function itself and not merely to photosynthesis. Averaging overestimates.

**The stand-level ratio at the reference configuration is 1.206, not 3.33.** Offspring production is
445.37 under mean light, 369.31 under deep crown and 537.95 under crown centre. The earlier factor of
3.33 was measured at a configuration that is not the reference and **should not be carried forward.**
What survives is the structural claim, and it is now quantified: the stand-level ratio of 1.21 exceeds
the stand-average per-plant bias of about 1.00 to 1.03, because only canopy-top cohorts are biased —
**so the demographic amplification is real, and its magnitude is configuration-specific.**


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

**The profile drains, and drainage is where a deep layer's water comes from.** Rain enters at the
top and moves down the column explicitly, layer by layer. It is tempting to read the conductivity as
negligible and conclude that the layers are independent buckets fed only by roots — and that is an
artefact of evaluating conductivity at the half-saturated state the model is *initialised* in, which
it leaves within weeks. At the draining steady state the conductivity **is** the rainfall, by
definition of the steady state. Measured on a mature stand, drainage into the deepest layer exceeds
uptake from it by about five orders of magnitude.

So **hydraulic redistribution is not this model's normal condition.** It is real and it is
deliberately coded, and it happens on a small minority of steps, carries a vanishing share of total
uptake, and is absent altogether from wet and seasonal runs. Where it does occur it moves water
**downward**, into dry mid-profile layers, under gravity head. The picture it invites — deep roots
lifting water to a parched surface — is a different model's, and an ecological claim resting on it
does not hold here. What survives is narrower and is about instruments rather than plants: a
statistic formed on a plant's *total* uptake cannot see per-layer reversal at all, because signed
fluxes sum.

**And the model's potential ceiling is a clamp whose treatment has to be right.** Past a certain
dryness the root resistance can saturate rather than diverging, and then the flux grows linearly in
the layer's potential and runs the wrong way: the model rewets a very dry layer out of a plant that
has nothing to give. Its reachability is ordinary rather than extreme — a wet top layer over a dry
one is the standard dry-season profile, and whole-plant shutdown is decided on the *wettest* layer,
so the plant stays alive while one of its layers is poisoned. **That would be a defect in the forest
being modelled rather than in its derivative**, and an ecologist reading a drought sensitivity would
be reading a derivative of it. Report 05 §6.2 states what a correct treatment requires; the reason
it is worth stating is that every obvious guard passes.

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

### What re-optimisation does to the *shape* of a response, and why the sign matters

The repricing has a second use, and it answers a question an ecologist asks more often than the
first one. There are two curvatures of profit against an environmental variable, and they are
different questions:

- **with behaviour held still** — how profit bends as the soil dries, for a plant that does not
  adjust its stomata;
- **with the plant re-optimising** — how it bends for a plant that does.

They differ by exactly one term, report 05 §7.7's `B`, built from the two numbers the water channel
already needs. And `B` is **never negative**: re-optimisation is unconditionally convexifying, so a
plant that can adjust always has the less concave response. That is the value of behavioural
flexibility, written as a number.

**The reason to care about the sign rather than the size is Jensen's inequality.** A response that is
concave in a fluctuating driver means variability *lowers* the average outcome — a plant does worse
in a variable environment than in a constant one with the same mean. A convex response means the
opposite. So the curvature's sign decides whether environmental variability is a cost or a benefit to
a given plant, which is one of the oldest questions in the field.

**And the correction flips that sign over about a third of an ordinary moisture-by-humidity
envelope.** With behaviour frozen the response is concave and variability looks costly; once the
plant re-optimises it is convex and variability looks beneficial. **The two accounts disagree about
the direction of the effect, not its magnitude** — and the frozen one is the one a reader gets by
default, because it is what a curvature of the profit expression gives without the argmax term.

**One limit, and it is not a small one.** This is a curvature of one individual's *profit*, and
questions about selection are curvatures of *fitness*. Between them sit the demography, both
reductions, and the whole feedback — §3's warning applies here with more force than anywhere else,
because a curvature is a second-order quantity and the intervening map is not linear. §10 lists the
bridge as open.

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

**And the flexibility of the section above does not fade out as a plant approaches its limit — it
stops.** The convexifying correction is flat right up to the bound and then ceases to apply, because
a pinned plant is not choosing. So the ecological reading is a threshold rather than a gradual loss:
a plant retains the full benefit of being able to adjust until the moment it cannot adjust at all.
For anyone computing the quantity, that means the interior expression returns a large finite number
just past the point where it stopped meaning anything, which is the same failure shape as every
other case in this model — plausible, finite, wrong.

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
without taking any up. It is uncommon (§6.2), so the case matters for a different reason than
frequency: **it is the wet bound of the plant's own feasible interval**, so the model visits its
neighbourhood whenever a plant is close to giving up on water, and more than half of all pinned
operating points sit there. Its derivative exists in closed form, and its relative accuracy under any
differencing scheme is the worst in the model, precisely because the output *is* the residue of a
near-cancellation.

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

> **This holds for the stem and not for the root, and the asymmetry is deliberate.** The root's
> critical potential was made independently settable *on purpose*: the fitted default pins root
> shutoff too conservatively for taxa that operate below it, *Acacia aneura* among them. So a
> species may carry a root curve and a shutoff the curve does not predict, and **the root is a
> three-parameter organ.** The two organs are therefore asymmetric — the stem's critical potential
> follows from its curve, the root's does not — and the ecology decided it rather than the
> bookkeeping. Report 07 §3 carries the consequence for the output format: one derived relation to
> report, not two.

**This is settled for the stem, and settled in the ecology's favour.** The model's construction also ties the
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

**And the census itself must be taken on a monotone grid, which costs about 4 percent when it is
not.** A quadrature over a crossed size distribution has neighbouring trapezia cancelling instead of
accumulating, so leaf area, above-ground mass and basal area can be wrong *before* any derivative is
taken. Measured on a stand that inverts in more than half its steps while producing a healthy
offspring count: the leaf-area census differs by 3.95 percent between the as-ordered and the sorted
integration of one identical state.

**The two field reductions each guard this and they work** — the light profile stays monotone in
every step of the same run. **The census does not, and neither does the routine that integrates the
size distribution for a user's output.** So the objective is the least guarded link in the chain, and
it is the first: an ecologist reading a leaf-area trajectory is reading a number that carries this
error, with no derivative involved at all.

**And for the census the deeper fault is which axis it integrates over.** A census sums a density
against the gaps between neighbouring plants, so those gaps must be measured along the axis the
density is carried on. Where the stand is carried by germination date, gaps measured in *height*
answer a different question — and that is wrong on any stand, not only a crossed one. Fixing the axis
also removes the crossing problem, because germination dates cannot invert. Report 05 §9 states the
requirement and why the obvious remedy, sorting by height, is the wrong one here.


### The seed's own size follows from its traits

A seedling's height is not a constant of the model. It is the height at which its live mass equals
the seed mass, so every parameter setting leaf, sapwood, bark or root mass moves it. Treating it as
independent of the traits would say **every species starts at the same size regardless of its
traits**, which is false: seed size and establishment size are themselves traits, and they covary
with the leaf and wood economics the gradient is differentiating. Eight parameters reach the census
this way, through both the establishment probability and the density boundary condition.

**No differentiated reference can price this channel** — a forward tangent resolves the seed's height
the same way a sweep does, so if either declares it away the two agree for free and the agreement
reads as a pass. The instrument that can is one that *rebuilds* the species from its traits and runs
the model twice, inheriting the declaration from neither path. What follows is what it reported while
the channel was imposed to zero, which is the measurement of what that imposition cost.

What it reports is not one number but a split. For the traits that reach birth size only through the
seedling's **height**, the answer is a common effect of about ten per cent on a young stand, falling
to one or two per cent as the stand accumulates biomass and the seed stops dominating the census.
For the **two allometric constants** — the pair that sets how much leaf area a stem of a given height
carries — it is a factor of **two to three**, and for one of them it does not fall with stand age.
Those two also fix the seedling's leaf area directly, not only its height, so they lose two channels
where the others lose one.

**The reading that survives is about instruments, not about the size of an error.** A factor of two to
three sat on two columns, at every stand age, while every differentiated check agreed to round-off —
because the quantity was resolved before the traits were differentiable inputs and both paths received
the answer. The split itself was the diagnosis: parameters reaching birth size through the height
alone clustered, the two that also set the seedling's leaf area did not, and a channel that is one
quantity cannot be recovered a piece at a time. Solving the condition where the newborn's state is
written collapses the split, and the seed mass — which enters that condition and reaches these three
metrics through nothing else — goes from an exactly zero column to a live one.

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

### And one question this machinery does not answer

**The bridge from a leaf's profit to a stand's fitness is open, and it is not a pass-through.** The
optimisation reasoning in section 7 — the envelope theorem, the repricing, the convexifying
correction — is about one individual's carbon profit with respect to its own inputs. The conditions
an evolutionary argument wants are about *invasion fitness*, and between the two sit the demography,
both reductions and the whole feedback. Section 3's measurement is the warning made concrete: the
feedback suppresses one trait's sensitivity sevenfold and reverses another's sign, so a map that
carried curvature through unchanged would have to be linear in exactly the place this one is not.
**Nothing here licenses reading a profit curvature as a selection gradient**, and the work that
would license it has not been done.

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
| **complete** | most of the 44 registered parameters, through the recorded cohort step, and the extinction coefficient through the field build | the gradient is theirs. The extinction coefficient's field-build half is closed: it was 3.041 percent short and is now within a part in ten million of a tangent |
| **short, and by a measured amount** | the second allometric constant | the reduction's own rows are formed and correct and birth size now carries a row, so what is left is narrower than either defect that used to sit here: at four years it is **0.924** of a rebuilding reference, against 1.000 at four tenths of a year, and 2.6e-04 from a trajectory tangent. It grows with run length and the cause is not established. The first allometric constant reaches 1.000 at both ages |
| **correct as a registered row, and not the trait an ecologist means** | leaf mass per area, wood density, the accessory-cost trait, sapwood conductivity | a hyperparameter function derives *other registered parameters* from each of these — leaf mass per area sets leaf turnover and leaf dark respiration — and the row holds those fixed. That is a perturbation no leaf admits, because the coupling of leaf mass per area to lifespan and maintenance **is** the leaf economics spectrum. Measured on leaf mass per area at four years the two differ by a factor of **3.2**, same sign |
| **complete through birth size** | eight parameters **through the seed's own size** — leaf mass per area, seed mass fraction, both allometric constants, wood density, and the stem-area, root and bark constants | the seed's height solves its own condition where the newborn's state is written, so this channel carries a row. Against a rebuilding reference the eight agree to 0.999–1.000 at four tenths of a year, with no group standing apart; the imposition it replaced was worth 11 percent on a young stand for the six that reach birth size through the height alone, and a factor of **2.1 to 2.7** for the two that also set the seedling's leaf area. One residual survives at four years, and it is the second row of this table |
| **declared zero at an interior optimum** | the stem's and the root's critical potentials | correct, and not a missing row: they set the dry bound of a feasible interval the operating point is inside, so complementary slackness makes them zero there. They become live at a pinned point |
| **absent — no row anywhere, ever** | every soil parameter — saturated conductivity, the retention curve's scale and exponent, the saturation, residual and ceiling constants, the infiltration pair, **times the layer count** if per-layer; the root depth shape; the two root-allocation constants; the crown shape | **"What if the soil were sandier" cannot be asked.** Nor can the vertical structure of the root coupling. The crown shape is excluded for a numerical reason rather than a structural one — its derivative is `0^η · log 0` at the ground knot |
| **refused by name** | none; the set is empty | every trait the strategy declares as differentiable now carries a row. A trait that loses one belongs here rather than returning a zero |
| **over-parameterised, stem only** | the stem's vulnerability curve carries three registered numbers for a two-degree-of-freedom curve | the third answers a counterfactual no plant can be subjected to. **The root's third number is not this** — it is a genuine degree of freedom, and it now carries a row |

### Which states are refused, and which are silently answered instead

The gradient is valid at an **interior stationary optimum**, and that is now the only state it will
answer in. The leaf classifies its operating point by the branch taken and reports the kind; the
stand's boundary refuses anything that is not interior, naming it. So a rejected search step, a
non-concave point, a non-finite residual, the shutdown and zero-transpiration substitutions, a
collapsed feasibility window and a determined-but-not-optimal point all **refuse** rather than
returning a plausible number, and the sentinel zero that used to be recorded as a converged optimum
is classified by its own exit instead.

**What that buys is honesty, not coverage.** The pinned branch is where drought lives (§7), and
refusing it is not the same as answering it: a **genuine bound** is a state the gradient ought to
have and does not. So the refusal converts the corpus's worst failure shape into a stated absence,
and the absence is now the limit. The acclimating variant is in the same position — its operating
point is a tracked state rather than an argmax, and it is refused rather than answered.

**Refusal is metric-level.** A refusal anywhere in one census metric's sweep makes that metric's
entire gradient undefined — a sum has no defined value with an undefined term, and no localisation
is available. The metrics are independent of one another.

### The biases, and their sizes where known

- **Mean-light averaging.** One physiology at the crown's mean light. **Measured per plant**: under a
  tenth of a percent for a suppressed stem, under half a percent for a well-emergent one, and **28
  percent for the stem just arriving at the canopy top** — which is the cohort whose fate decides
  escape. The band is narrow because the light profile is nearly flat below four-fifths of canopy
  height. Direction guaranteed, because profit is concave in absorbed radiation. At the reference
  configuration the stand-level offspring ratio is **1.206**, and the earlier factor of 3.33 belongs
  to a configuration that is not the reference.

- **Birth size.** Derived from its condition, not imposed. Against a rebuilding reference the eight
  agree to 0.999–1.000 at four tenths of a year and the two allometric constants stop being a
  separate population. **Quote the run length beside any figure here**, because the channel's share of
  a census falls as accumulated biomass comes to dominate it, and take the trait on its own: a
  difference that rebuilds a species from a hyperparameterisation moves several registered parameters
  at once and prices a different question. What remains at four years is the second allometric
  constant, at 0.924, and the cause is not established — the inflow boundary's own dropped adjoints
  have since been consumed and account for 4e-5 of it.
- **The parameterisation.** A row is a derivative with respect to one registered parameter holding
  the others fixed. Where a hyperparameter function derives some of them from others, that is not
  the trait sensitivity it looks like — see the third row of the table above.
- **The dominant's height.** The knot positions are passive, so the plant that sets every other
  plant's light has a height adjoint short by a term measured at about 87 percent of that adjoint.
  Whether it shrinks with knot density is no longer open: built at 33, 65 and 129 knots the
  extinction coefficient's residual falls from 2.22e-10 to 4.58e-11, so the treatment converges and
  the term is a discretisation error rather than a floor.
- **The reserve gate.** A mollifier occupying 40 percent of the reserve's domain, damping the
  gradient at high reserves and admitting growth at empty ones. Direction and size both unstated,
  because the distribution of relative reserve across a stand has never been reported.
- **What no measurement covers.** **No plant in this corpus has been run in shade** — ground-level
  transmittance median 0.9997, an open woodland. **The drought half of this caveat is withdrawn:** the
  mature stand at the reference configuration settles at 1.4 to 2.4 MPa, which is past the potential
  where the leaf's optimum stops being interior. So the stand does visit the dry regime under its own
  dynamics, and an incidence figure taken on a wet *transient* says nothing about it.


### And the sentence that matters most, about drought

An ecologist asking about drought is asking about a **response**: what changes when the water runs
out. What this machinery computes in a drying stand is a derivative **holding the active set
fixed** — the bound active, the reserves frozen, the clamp engaged. That is a legitimate object, a
one-sided directional derivative on one stratum of a piecewise-smooth map, and it is a usable local
trait sensitivity *within* that stratum.

**But the drought response is precisely the stratum change.** So the composed drought gradient is
valid and it is the wrong instrument for the question, and the failure is one of **domain, not of
correctness**. The honest interface emits it **with its active set attached.**
