# One object behind six questions

This continues `synthesis.md`. It asks how six things meet at the frontier:
- reproductive value;
- selection pinned to times;
- evolutionary stability under daily-resolved climate;
- the tragedy of the commons;
- the derivatives of the EEO loop;
- all-trait selection gradients.

It then asks which representations, structures and algorithms they make
unreasonably useful.

*Established* results are cited (`theory.md`, `literature.md`). *Derived* means
ours and checked by no one else. *Hypothesis* means a claim this machinery could
test and has not.

## 0. The instruments came first

The scheduling work (`../../OBJECTIVES.md`) asked for `ln J`, every elasticity
and every curvature (chords of sweeps) to be accurate, reproducible under nudges,
continuous in the traits, predictable and never failing. That is the programme
that turns derivatives into measurements one can reason from, rather than
numbers that move with the controller's choices.

In Kuhn's account a shift needs instruments that make the anomalies visible
before the new frame can be seen. Here the instruments are:
- stable elasticities and chords;
- invaders read on a recorded field;
- exact adjoints through an inner optimum.

What the programme has not yet covered is the invader's side: the field-held
gradient `g`, and the field sensitivities below. On long drought, `g` converges
in the introductions more slowly than `ln J` (`../measurements/regnans-roadtest/rootcause/`
E2). Extending the same guarantees to these quantities is the next step for the
instruments.

## 1. Anomalies the current frame does not absorb

These are what make the old frame visibly insufficient, rather than merely slow.

1. **Cost does not grow with the number of traits.** A sweep costs the same for
   one trait or fifty. The theory and tools are organised one trait at a time:
   PIPs, one-dimensional classification, Lande–Arnold on a few measured traits.
   The natural unit of analysis has become the whole trait vector, and the
   theory has no habits for it.
2. **Most of an individual's selective advantage is taken from its neighbours.**
   For `lma` on long drought, the field-held gradient is −23.8 and the stand's
   own response is −5.9 (*measured*). Optimality principles that maximise an
   objective for a fixed environment, or for a stand, point in different
   directions from invasion fitness. One trait cannot show the angle between
   them; fifty can.
3. **The landscape can have no gradient at the resident.** On constant rain,
   `ln R′` jumps by about 8 within ±0.01% of `lma` (*measured*). Smooth adaptive
   dynamics fails exactly where competition is most size-asymmetric.
4. **"Variable climate" here is succession.** Each patch replays the record from
   disturbance, so rainfall variation is variation along patch age (*derived*,
   `theory.md` D.2). Time and succession are one axis in this model.

## 2. The object: the field as the coordinate system

Every result in `theory.md` passes through the field:

> E = (light L(z, a) at each height and patch age, soil water W_ℓ(a) in each
> layer at each patch age).

The field is what residents make and what every individual responds to. It is
finite (knots × layers × evaluation times) and recorded. Two vectors in it
describe any strategy θ:

- **Its sensitivity S(θ) = δ ln R′(θ; E)/δE.** For each field element, this is
  the marginal effect on fitness of a little more light or water there, then.
  - By `theory.md` F.2 it is a reproductive-value-weighted integral:
    `S(z, a) = (1/R′) ∫ p(s) σ_s λ_s(a) · ∂G/∂E(z, a) ds`.
  - So S is the shadow price of each resource at each moment, for that strategy.
  - One reverse pass gives all of it (*derived*). The hook that exposes it is a
    spike patch, not merged.
- **Its impact I(θ) = ∂E*/∂(its abundance or traits).** This is how its presence
  moves the field. It comes from a resident sweep or tangent with the field as
  output, and is not built.

In these coordinates (*derived*; first order where stated):

| question | in field coordinates |
|---|---|
| invasion fitness of θ′ in a field E near E₀ | `φ(θ′, E₀) + ⟨S(θ′), E − E₀⟩` (first order) |
| selection gradient | `g = −⟨S, dE*/dθ⟩` (exact, I5): the strategy's prices, applied to how the equilibrium field moves |
| tragedy of the commons | `Φ = F_θ − g = ⟨S, ∂E/∂θ⟩` (exact, I2): its own effect on the field, valued at its own prices |
| robust coexistence | sensitivities linearly independent and impacts suitably aligned (Meszéna et al. 2006) |
| how many species can coexist | at most the effective dimension of the field (Levin 1970; Meszéna et al. 2006) |
| where and when selection acts | the integrand of `g` over birth date, patch age and state; or `S` itself over (z, ℓ, a) |
| whether an EEO criterion is evolutionarily stable | whether its implicit prices equal the invader's costate prices (`theory.md` F.4) |

## 3. How the six meet

- **Reproductive value and selection pinned in time are one object.** The
  adjoint is read along an individual's life to give reproductive value, and
  along the climate record to give the time-resolved selection gradient or the
  shadow price of water on each day. One reverse pass gives both readings.
- **The commons is the gap between two adjoints.**
  - The resident's adjoint is the invader's plus the externality of each state on
    everyone else (`theory.md` F.3).
  - So the tragedy of the commons is resolved by state, by patch age and by
    climate event. That shows *when* and *through which resource* competition
    pushes evolution away from what is best for the stand: height growth at
    canopy closure, or water use at the onset of a drought.
- **EEO's criteria become statements about those prices.**
  - TF24's leaf maximises instantaneous profit at every evaluation. For a rare
    invader, that satisfies Pontryagin's condition, because the control enters
    fitness only through net production (*derived*, F.4).
  - So the leaf behaves as a selfish optimiser. The stand's prices from the
    resident adjoint define the cooperative one, and their ratio gives a
    Cowan–Farquhar λ for water derived from fitness.
  - The envelope theorem gives a sharp internal test (*derived*, C.4). Freezing
    the leaf's operating point must leave the invader's `g` unchanged. It may
    change the stand's `F_θ`, through soil uptake.
- **All-trait selection passes through the same field.**
  - Each trait's gradient is `g_k = −Σ_f S_f · (dE*_f/dθ_k)`, a sum over field
    elements f. This is an exact attribution of selection on every trait to
    field channels (*derived* from I5).
  - Stacked over traits it is a trait × field matrix. Its rank is at most the
    field's effective dimension.
  - Its leading singular vectors are the few field directions through which all
    traits are selected: the selection modes.
- **Climate variability adds coordinates, not necessarily dimensions.**
  - Daily rainfall makes water on each day a separate field coordinate. It
    becomes a separate limiting factor only if strategies' sensitivities to water
    at different times are not collinear: if they differ in rooting depth,
    storage or timing.
  - The second-order effects of variability, where relative nonlinearity
    (Jensen's inequality) enters, are the curvature of `φ` in E times the
    variance of E, which chords give.
- **Evolutionary stability in many traits is curvature in many directions.**
  The invader Hessian's spectrum gives the branching directions. The
  convergence Jacobian's symmetric part gives the strong-stability test (Leimar
  2009).

Two hypotheses follow, each testable with one matrix:
- **H1, trait syndromes as field modes.** Plant traits covary along a few axes:
  the leaf economics spectrum (Wright et al. 2004), and the two-dimensional global
  spectrum of form and function (Díaz et al. 2016). If the field's effective
  dimension is small, selection on fifty traits is confined to a few directions,
  and trait covariation is the image of the dominant field modes. Test: the
  singular spectrum of the trait × field selection matrix, and the angles between
  its leading vectors and those spectra.
- **H2, variability raises niche dimension.** At equal mean rainfall, seasonal
  and episodic records raise the effective rank of S over trait space relative to
  constant or smoothed rain. So they admit more coexisting species and more
  branching directions, and mean-climate models undercount niche dimensions.
  Test: the singular spectra of S over a sample of strategies, on records of one
  mean and different variability.

## 4. Representations, structures and algorithms that are unreasonably useful

Each is useful beyond the problem it was built for, because the domain's
quantities factor through it.

1. **The field as an explicit, editable input.** *Built:* invaders read it, and
   never differentiate it.
   - Any strategy can be evaluated in any field: a recorded one, one with a
     drought removed, light averaged over patch ages, another community's field.
   - Counterfactuals become runs, not approximations. The counterfactual growth
     rates that expanded coexistence theory needs (Ellner, Snyder & Adler 2019)
     are exact invader runs in synthetic fields.
   - The same input carries invasion screening, coexistence decomposition and
     "what if this drought had not happened".
2. **The adjoint as a price.** *Computed inside every sweep, not exposed.*
   - Reproductive-value maps over size × patch age, time-resolved selection, and
     shadow prices of light and water, all from one reverse pass.
   - The same quantity is the gradient, the attribution, and the test of EEO
     criteria.
3. **Each strategy as two vectors (S, I) in field space.** *Not built.*
   - With a library of `(φ(θ, E₀), S(θ))` over many strategies, one invader run
     and one reverse pass each, the first-order invasion fitness of every strategy
     in every nearby community is an inner product.
   - Assembly, invasibility screening and limiting similarity become linear
     algebra. Exact runs are reserved for the candidates that matter.
4. **Spectral structure, computed without forming the matrix.** *Not built.*
   - Randomised SVD and Lanczos need only products with S and its transpose.
     Adjoint and tangent passes supply those.
   - They give the field's effective dimension, the selection modes, and the
     invader Hessian's leading curvature directions, with dozens of passes, not
     thousands.
   - These quantities bound coexistence and branching, and test H1 and H2.
5. **The equilibrium as a manifold to follow.** *The algebra is in regnans PR
   #89 and `rootcause/` §7; the loop is not built.*
   - b* is followed along evolutionary paths by a predictor from one resident
     sweep.
   - Folds (loss of viability) and branching points become events detected along
     curves, which regnans's boundary continuation (#84) already does for
     parameters.
6. **Ensembles of records.** *Built in the harness.*
   - Fitness is the mean of R′ over records at a common b (`theory.md` D.3).
   - The spread of g across records is fluctuating selection.
   - Independent records per patch would add the between-patch climate variation
     a storage effect needs.

## 5. Where it breaks

- **Jumps and corners.** The constant-rain jump, and the leaf's regime switches
  in the inner optimum. There, one-sided limits or event-aware treatment replace
  derivatives.
- **Linear response is first order.** Field-space predictions hold near E₀;
  exact runs check them.
- **The field is large:** thousands of coordinates. Its usefulness rests on its
  effective dimension being small, which is H1 and H2's question.
- **Climate is tied to patch age** (§1.4).
- **Accuracy:** the scheduling guarantees do not yet cover `g` or `S`.

## 6. The experiment that would show what lies on the other side

- **Compute S for about twenty strategies** spanning trait space, on long drought,
  episodic and a smoothed-rain record of the same mean. Take the singular
  spectra.
  - If the effective dimension is small and rises with variability, H1 and H2
    hold. Trait ecology then reduces to geometry in a small space of field modes,
    and the frontier questions become questions about that space.
  - If it is large, the field framing still organises the theory, but not the
    computation.
- **This needs the field hook merged:** a spike exists, at +12% of a sweep.
- **The cheapest precursors need no new code:** the all-trait `g` and `F_θ`
  vectors on the six smooth climates, and `g` across the eight records of long
  drought (`synthesis.md` §6).
