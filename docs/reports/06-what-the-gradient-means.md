# What the gradient means: the ecology behind the derivatives

Written 2026-08-04. Companion to
[`05-reverse-mode-mathematics.md`](05-reverse-mode-mathematics.md), section for section.

Report 05 says what each derivative *is*. This says what each one *means*, and what it
would be wrong to conclude from it. The intended reader is an ecologist deciding whether
a number this machinery produces answers their question, and a developer deciding
whether a defect matters.

Its second purpose is to make the ecological content of the design falsifiable. Several
choices in report 05 are defensible mathematically and carry an ecological commitment
that is easier to argue about when stated in words.

---

## 1. What question the gradient answers

The model grows a patch of forest from bare ground: seeds arrive, individuals compete
for light and water, they grow and die, and the stand assembles itself. A **census** is
a summary of that stand at some age — its leaf area, its above-ground mass, its basal
area.

The gradient answers: **if one plant trait were slightly different, how would the stand
differ?** Not one plant — the whole assembled stand, including every consequence that
runs through competition. A leaf that is slightly cheaper to build shades its neighbours
slightly more, so they grow slightly less, so they shade it back slightly less, and the
stand that emerges is different in ways no single-plant calculation reaches.

That is why the derivative is worth this much machinery. The quantity is not
$\partial(\text{one plant's growth})/\partial(\text{trait})$, which is calculus on a
formula. It is the derivative of an **emergent** property through a hundred years of
feedback.

### Why 44 traits at once, and why that forces reverse mode

The traits are not a shortlist. They are the whole physiological parameterisation: leaf
economics, wood density, allocation, hydraulic vulnerability, photosynthetic capacity,
mortality and reserve dynamics. An ecologist asking "which traits does this outcome
depend on, and how strongly" wants all of them, ranked.

Getting that by re-running the model once per trait costs 44 runs. The adjoint costs
one run and one sweep, whatever the number of traits. **This is the whole reason the
project exists**, and it is why report 05 section 1 puts the choice of direction first.

The practical consequence is that the gradient is only useful if it is *complete*: a
ranked list of 44 sensitivities with four of them silently zero is worse than no list,
because the zeros read as "this trait does not matter" — which is exactly the kind of
conclusion an ecologist would publish.

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

**The coordinate choice is an ecological statement, not a numerical one.** A density in
height says "here is how many stems are this tall". A density in birth date says "here
is how many stems germinated then, and here is how tall they now are". The two describe
the same stand.

They differ in what can go wrong. In height, two cohorts can *cross*: a plant with more
reserves can overtake one that germinated earlier, so the size ordering stops matching
the age ordering, and the density has to be re-sorted. In birth date, germination order
is fixed once and for all and nothing can reorder it. Report 05 section 2 records this
as "the abscissa cannot invert". Ecologically it is the observation that **plants can
change their relative size but not their relative age.**

That is why the reverse-mode gradient is scoped to birth date. The height coordinate is
not wrong; it is a coordinate in which a legitimate biological event — the overtaking of
one cohort by another, which reserve-gated growth makes common — turns into a numerical
special case.

---

## 3. Why the model is a composition, and what that means for feedback

Report 05 section 3 writes the model as a chain: traits, then each plant's size, then
the shared environment, then each plant's physiology, then the rates.

The ecologically important feature is the *shape* of that chain. Two arrows point
differently:

- **Every plant reads the same environment.** The light profile and the soil water are
  shared. One arrow, many readers.
- **Every plant writes into that environment.** Its leaves shade, its roots draw water.
  Many writers, one sum.

Competition is exactly the second arrow. There is no direct plant-to-plant term
anywhere in the model — no plant knows about any other plant. They interact *only*
through their contributions to a shared field. This is what makes the model tractable
and it is what makes the adjoint tractable too: the reverse pass handles each plant
independently and then does one pass to redistribute the environment's sensitivity.

**A consequence worth stating plainly.** When the gradient tells you a trait matters,
part of that is the direct physiological effect and part is the competitive one, and the
machinery does not separate them. A trait that makes a plant grow faster in isolation
may show a small stand-level gradient because everything else grows faster too.
Interpreting a sensitivity as a physiological effect is a mistake the number cannot
warn you about.

---

## 4. What the solver's adjoint means, and the one thing it deliberately ignores

The forward model steps through time. The adjoint runs the same trajectory backwards,
carrying "how much does the final census care about this quantity, at this moment".

The ecological reading of report 05 section 4: **influence accumulates backwards along
the trajectory.** A trait acts on the stand at every instant, and the gradient is the
sum of those actions weighted by how much each one still mattered by the end. Early
actions matter through everything they set in motion; late actions matter directly.
That is the integral in report 05's equation (4.1).

### The step size is held fixed, and that is a modelling decision

The solver chooses its own time steps adaptively, taking small ones when the stand is
changing fast. Report 05 section 4 holds those step sizes constant on the reverse pass.

This is worth being explicit about, because it looks like an approximation and is not.
The step sizes are a property of the *numerical method*, not of the forest. Letting the
gradient flow through them would compute how the error controller responds to a trait
change, which is not an ecological quantity and would contaminate the answer with the
solver's internals. **Holding them is the choice that makes the gradient a derivative of
the model rather than of the program.**

### Cohorts appear during the run, and that is where seed production enters

New cohorts are introduced as the run proceeds — the model does not know in advance how
many it will need. Report 05 section 4.1 treats this as the state changing dimension.

Ecologically, each introduction is a germination event, and its size is
$n_{\text{new}} = \text{birth\_rate} \times \text{pr\_estab} / g$: how many seeds arrive,
what fraction establish, divided by how fast a seedling grows out of the smallest size
class. The division by growth rate is a bookkeeping consequence of carrying a density in **height**
rather than a count: a seedling that grows quickly spends less time being that tall, so it
contributes less to the density there. **On the birth-date coordinate that division is
absent** — nothing moves a plant along a germination-date axis — so on the coordinate the
gradient runs on, the boundary condition is simply the seed arrival times the establishment
probability.

This is a real path from traits to the census — one of the six section 8 lists, and that
list is the paths found so far rather than a closed set. A trait
affecting germination or establishment reaches the stand *here*, not through any plant's
physiology.

---

## 5. What one recorded step is

Report 05 section 5's unit is one plant's physiology evaluated once: it reads its own
size, the light and water available to it, and the traits, and it produces its growth,
its mortality, its seed output, and how much water it drew from each layer.

185 inputs and 12 outputs, of which **130 describe the light profile** — the numerical
face of the ecological fact that a plant's performance depends far more on the shape of the
canopy above it than on anything about itself.

**But the plant does not read 130 numbers; it reads one.** Its whole physiology is driven by
a single scalar — the light at its crown centre, or the leaf-area-weighted mean over its
crown, depending on the shading model. Everything the canopy does to a plant, it does
through that one number.

That is worth stating ecologically as well as numerically. **The model assumes a plant
responds to an average of the light it sits in, not to the profile.** A plant whose upper
leaves are in sun and lower leaves in deep shade is modelled as though all its leaves were
in the mean, which is not the same plant: photosynthesis saturates, so averaging the light
and then photosynthesising overestimates the gain relative to photosynthesising and then
averaging.

**That overestimate has been measured, and it is large: mean light overestimates lifetime
offspring production by a factor of 3.33, +233 percent** — 8.276245764 against 2.483491938 for
`deep-crown`. **Caveat:** measured at `max_patch_lifetime = 20`, one trait, one species, not
the production configuration, and the ratio may not be lifetime-invariant (`deep-crown` took
2 682 s even at lifetime 20). TF24 has a `deep-crown` mode that does it the other way round, one optimisation
per crown-depth point — **and that mode raises an error on the differentiated path.** So
the gradient is available only under the averaging assumption, and any conclusion drawn from
it inherits that assumption. This is a scope limit an ecologist should be told about, not a
numerical detail.

### Why the coordinate change halves the work

Report 05 section 5.1 is worth reading twice, because it is the one place where an
ecological choice buys a large numerical saving.

In the height coordinate, the density obeys
$\dot\ell = -\mu - \partial g/\partial h$. The second term says that where growth
accelerates with size, cohorts spread apart and the density thins; where growth
decelerates, they pile up. It is a real effect — the compression of the size distribution —
and computing it requires asking "how fast would this plant grow if it were slightly
taller", which means solving its entire physiology again at a displaced height.

**How many times again depends on a setting.** With `node_gradient_richardson` false, which
is the default, a one-sided difference reuses the rate already computed and costs **one**
extra solve. With Richardson extrapolation at its default depth of four it costs **eight**.

In the birth-date coordinate, $\dot\ell = -\mu$: **the density changes only because
plants die.** Nothing about growth appears, because germination dates do not spread
apart or pile up. The compression is still there in the model — it reappears when you
convert back to a distribution over height — but it is no longer something the rate
equation has to compute.

So the coordinate change removes one extra physiological solve per plant per step at the
default, and eight under Richardson. The ecology is unchanged; only the bookkeeping moves.
**An earlier form of this section said the work was halved**, which is right for the solve
count at the default and is not a statement about the recorded tape.

---

## 6. What the environment reductions mean

### 6.1 Light

Report 05's equation (6.1) in section 6.1 is the canopy. Read it right to left: each
cohort casts shade according to its leaf area $A_k$, distributed vertically by a shape
function $\tilde Q$ that says what fraction of that leaf sits above height $z$; the
shading is scaled by an extinction coefficient $k_I$; and the contributions are summed
over every cohort weighted by how many stems it represents.

The transposes, equations (6.2)–(6.5), answer the question "if the canopy at this height
mattered, who is responsible?" — and the answer has three parts: **how many** stems a
cohort has (7.2), **how tall** they are (7.3), and **what kind of plant** they are
(6.4)–(6.5).

**The third part is missing from the implementation, and the shape of the failure is worse
than a zero.** $k_I$ is how opaque a canopy of this species is — a light-capture strategy,
not a bookkeeping constant. The structure carrying the reverse pass through the canopy has
slots for size and number and none for a trait, so the reduction's contribution is lost.

**But $k_I$'s reported sensitivity is not zero.** It also appears inside each plant's own
physiology, as a self-shading coefficient on the radiation it absorbs, and that path is
differentiated correctly. So the number an ecologist reads is **real, plausible, and short
by the competitive half** — the part that says how much this species' opacity matters *to
its neighbours*. A zero at least looks suspicious. A number that is right in its
self-shading and silent about its shading of others looks like a finding.

**$\eta$ — the vertical distribution of leaf area, whether a crown is top-heavy or evenly
spread — is a different case: it has no row at all**, because it is not among the
differentiated parameters. It is excluded for a numerical reason (a derivative that is NaN
where a crown's relative height reaches zero), so closing the reduction's gap gives $\eta$
nothing until that exclusion is lifted. A well-studied axis of tree architecture is
currently not a question this machinery can be asked.

### 6.2 Water

The water aggregate of section 6.2's reading is the same shape: total draw from a soil layer is summed over
plants, and the soil responds by drying. The transpose asks which plants were
responsible for a layer mattering.

The defect recorded there is worth an ecological gloss. The forward model was taught to
handle cohorts in a jumbled size order; the reverse pass was not. On a stand where cohorts have
crossed — which happens whenever reserves let a younger plant overtake an older one — the
two disagree, and **the gradient is finite and wrong rather than absent**.

**And the coordinate choice does not rescue this.** The forward reduction was extended to
tolerate crossed heights *on the birth-date coordinate*, because germination order stays
monotone whatever the heights do. The adjoint's guard tests height order and knows nothing
about the coordinate. So on the coordinate the gradient is scoped to, the forward model runs
and the adjoint stops — and crossing is *more* common there, not less. An earlier form of
this section said the scope decision closed it. It does the opposite.

---

## 7. What the plant's decision means

This is the ecologically richest part of the design and it is worth understanding before
trusting anything downstream.

### The decision itself

A plant with leaves and roots faces a trade-off. Opening its stomata lets in CO₂ to
photosynthesise, and lets out water. Losing water pulls its internal water potential
more negative, and past a point the water columns in its xylem break — embolism — which
costs it conductive tissue it cannot cheaply replace.

So it chooses. Report 05's equation in section 7 is that choice:
$\Pi = A(c^{\mathrm{i}}) - \Theta$, gain minus hydraulic cost, maximised over how hard
the plant is willing to pull. Every TF24 plant solves this optimisation at every moment
of its life. **It is a model of behaviour, not a formula**, which is why the derivative
needs care.

### Why profit is free, and what that means biologically

Report 05 section 7.1's envelope theorem has a clean ecological reading. **At the
optimum, the plant is indifferent to small changes in its own decision** — that is what
being at a maximum means. So if the environment shifts slightly, the resulting change in
profit is entirely the direct effect of the environment; the plant's re-optimisation
contributes nothing to first order.

This is not a numerical trick. It is the statement that a well-adapted plant's
performance is insensitive to small errors in its own behaviour, and it is why the most
expensive part of the model — the optimisation — costs nothing to differentiate for the
quantity that matters most.

### Why water use is not free

The plant is indifferent about *profit*. It is not indifferent about *water*. Report 05
section 7.2's argmax sensitivity says: shift the environment, and the plant re-optimises,
and its water use changes as a result — and that change is a real effect on every other
plant sharing the soil.

So the expensive derivative is needed for exactly the quantity that mediates
competition. The design's economy is to notice that this channel is *one number wide*:
the plant makes a single scalar decision, so all its knock-on effects flow through that
one decision. Report 05 calls this rank one.

### The pinned plant, which is a real biological state

Sometimes the optimum is not interior: the plant would like to transpire less than zero,
or more than its hydraulics allow. Then it sits at a limit, and report 05 section 7.4
notes that the envelope theorem stops applying.

This is not an edge case to be tolerated. It is **drought**. A plant pinned at its
zero-uptake bound is a plant that has closed down; a plant pinned at its critical
potential is one operating at the edge of hydraulic failure. Both are states the model
exists to represent, and they are the states in which the derivative is structurally
different — the plant is no longer indifferent to its own behaviour, because it is not
choosing freely.

The practical implication: **any conclusion about drought sensitivity depends on the
pinned branch being right.** The bound's own derivative, `Leaf::bound_partials`, is
carrying the ecology in that regime.

### The bracket failure is a non-producing plant

Report 05 section 7.5 records that the CO₂ root-find loses its bracket when either
assimilation at saturation is negative or water flux is negative. Both describe a plant
that is not making a living: respiring more than it fixes, or unable to move water at
all. The forward model recognises those states and substitutes shut-down. The gradient
path does not, and raises instead.

So the defect is confined to the states where the answer is ecologically trivial — a
plant doing nothing — which is why it is a guard and not a derivation.

### The vulnerability curve

Report 05 section 7.6's integral is the hydraulic vulnerability curve: what fraction of
conductivity survives at a given water potential, integrated to give total flow. The
parameters $b$ and $c$ are the curve's position and steepness — $b$ near where half of
conductivity is lost, $c$ how abruptly. These are among the most-measured traits in
plant hydraulics and among the most ecologically interesting, because they set where a
species sits on the drought-tolerance spectrum.

**An earlier form of this section said these four entries are "not a derivative of
anything". That is false, and the correction matters for what to prioritise.** The code
already holds the interpolant's knot grid still across each parameter perturbation, so the
knot-count discontinuity that would have made them meaningless is defended against. Measured,
the held-grid difference reproduces the closed form to 5.1e-9, and held against moving
differs by at most 8 percent — not the 47 to 10,245 times recorded.

**So the hydraulic rows are approximately right, and the thing that makes them
uninterpretable is not arithmetic but the question.** Read on: the critical potential is
derived from the curve and registered beside it, so the reported sensitivity to curve
position holds fixed a quantity that cannot be held fixed. **That** is what makes a
drought-tolerance sensitivity untrustworthy today, and closed forms do not touch it. The mechanism is numerical — a lookup table whose number of entries changes when
the parameter moves — but the consequence is ecological: the answer to "how much does drought
tolerance matter here" is not merely imprecise, it is not a derivative of anything. Report 05
gives the closed forms that remove the table.

**And a second problem that closed forms do not touch, which is about the question rather
than the arithmetic.** The model derives the critical potential from the curve's position and
steepness — it is a property of the same curve, not an independent trait — and then registers
all three as differentiable parameters. So the reported sensitivity to curve position is
taken *with the critical potential held fixed*, which is not a perturbation any plant can
undergo.

A vulnerability curve has **two** degrees of freedom per organ, and that is what a
physiologist measures: where the curve sits and how sharply it falls. A gradient reporting
three numbers per organ for a two-parameter curve is over-parameterised, and the third
number answers a counterfactual that does not exist. The critical potential's sensitivity is
real, but it belongs *inside* the position and steepness rows, which is where someone reading
the output would look for it.

**This is now settled, and settled in the ecology's favour.** The model's own construction
ties the stem curve's steepness to its position by a fitted trade-off — so on one reading a
stem curve has only *one* degree of freedom, and the two organs would be described
inconsistently. The ruling is that the trade-off is a **default for choosing initial values,
not a constraint on the curve**: two species can share a $p_{50}$ and differ in how sharply
they lose conductivity, which is what the measurements show. So both organs get two numbers,
and the critical potential follows from them.

**What is *not* offered, and the reason is worth understanding.** $p_{50}$ — the potential at
which half of conductivity is lost, and the single most reported number in plant hydraulics —
is refused. Not because it does not matter, but because **setting it in this model changes
nothing**: the curve was built from it once, and afterwards the curve is what it is. A
sensitivity to $p_{50}$ would describe a model that re-derived the curve when you moved it,
and no such model is implemented. Asking for a curve's position is asking for $b$.

This is the clearest case in the model where the ecology dictates the output format rather
than merely interpreting it.

---

## 8. What the census means, and the four ways a trait reaches it

Report 05 section 9 splits the census gradient into two terms, and the split has a clean
reading.

A stand's leaf area changes with a trait for two reasons. **The stand is different** —
different plants, different sizes, different numbers, because the trait changed how they
grew and competed. And **the measurement is different** — the same plant, converted to
leaf area by a formula that itself contains the trait.

The first is the trajectory term and it is what the whole adjoint machinery computes.
The second is a one-line calculation at the final state. It is easy to forget precisely
because it is trivial, and forgetting it is silent: the answer stays finite and
plausible.

Report 05 section 10 enumerates the paths from a trait to the census. **An earlier form of
that section said there were four and that the list was complete. It was wrong, and the
correction matters ecologically.**

Six are known, and "six" is a count of paths found rather than a closed set. Four are the ones a reader would guess: the measurement formula, each
plant's physiology, germination, and the shared canopy. Two were missed:

- **The soil.** Water aggregates across plants exactly as light does, and the retention curve
  — how tightly a soil holds water at a given potential — reads parameters directly. So
  belowground traits reach the census by a route structurally identical to the canopy's, and
  it has the same missing accumulator. **Every ecological statement about $k_I$ and $\eta$
  reading zero applies to the soil parameters too**, and nobody had looked.
- **What a seed starts as.** The initial reserve is a trait times the storage capacity, so
  how much a seedling is provisioned reaches the census directly. That is a real
  establishment strategy and it was unlisted.

**The general lesson for anyone reading a sensitivity from this machinery.** A completeness
claim in a design document licenses a reader to stop looking, and this one was wrong by two
paths out of six. Treat the list as the routes found so far.

### One assumption is imposed rather than derived

Report 05 section 10.1 records that the seed's initial height is treated as independent
of the traits. Ecologically that says **every species starts at the same size regardless
of its traits**, which is false: seed size and seedling establishment size are traits,
and they covary with the leaf and wood economics the gradient is differentiating.

The measured consequence is about 3 per cent for leaf mass per area. What makes it worth
flagging beyond its size is that **neither available reference can detect it**: the
forward tangent makes the same assumption, and a re-run finite difference cannot be used
at production because the stand collapses discontinuously under a tiny trait
perturbation. So this is the one defect where "we cannot currently tell" is the honest
statement.

---

## 9. What would make this gradient trustworthy to an ecologist

Not a green test suite. Three things, in order:

1. **No zeros that are not real zeros.** A trait reading zero must be a trait the model
   genuinely does not use, and the boundary must refuse a trait it cannot answer for
   rather than returning zero. Right now $k_I$ and $\eta$ read zero because of a missing
   accumulator, and that is indistinguishable from an ecological finding.
2. **Agreement with an independent method on a case small enough to check by hand.** A
   forward tangent on a two-cohort stand, agreeing to solver tolerance, is worth more
   than any amount of internal consistency — because internal consistency is exactly
   what a transposed-wrongly reduction preserves.
3. **A stated domain.** Which coordinate, which traits have rows, which states are
   refused, and what the known biases are. A gradient with an honest domain is usable; a
   gradient that answers every question is not trustworthy.

The largest current risk is not any single defect in report 05's table. It is that
**every defect in that table produces a finite, plausible number** — wrong signs, wrong
magnitudes, silent zeros — and none of them produces an error. An ecologist reading the
output has no way to tell.
