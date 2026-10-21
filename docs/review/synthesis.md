# What we have built, seen from the other side

This synthesises three reviews written for it:
- `regnans.md`: regnans at `61746b0`, its roadmap, and its issues and PRs;
- `literature.md`: about 150 verified references, with a novelty verdict;
- `theory.md`: adaptive dynamics, coexistence theory and eco-evolutionary
  optimality (EEO), derived for this model, with a section on costates.

It also draws on the measurements in `../measurements/regnans-roadtest/rootcause/`.
Claims marked *derived* are ours and have been checked by no one else; *measured*
claims cite a run.

## 1. The shift

**Where we have been standing.** We have treated the adjoint as a faster way to
get the derivatives an existing workflow takes by finite differences. That
workflow is the one regnans implements and the literature uses:
- simulate a resident, then perturb and re-simulate;
- one trait, or two, at a time.

Judged that way, the adjoint is a speed-up. It loses at one trait (2.7 forwards
against 1.24) and pays from two or three. That is how the roadtest priced it, and
how regnans's open PR #87 priced it on FF16 at 21–32 times a run.

**The other side.** The model is a differentiable map:

> traits θ and climate c → the field E (light at each height and patch age, soil
> water in each layer) → fitness.

Its derivatives are not approximations to a theory; they are the theory's
objects, computed exactly through a mechanistic model.

- **The reverse sweep's adjoint is reproductive value** (*derived*, `theory.md`
  F.2).
  - For an invader in a held field, the adjoint of each cohort's state is
    survivorship times the gradient of reproductive value with respect to that
    state.
  - The adjoint of cumulative hazard is Hamilton's force of selection.
  - What life-history theory writes down for linear, time-invariant models, the
    sweep computes for a nonlinear, size-structured, climate-forced one.
- **The selection gradient is a generalised Caswell formula** (*derived*, F.1):
  `g = (1/R′) ∫∫ n(s,a) ∇ₓV · ∂G/∂θ′ da ds`. That is the density of
  individuals, times their marginal reproductive value, times how the trait
  changes their rates, summed over birth date s and patch age a.
  - It is exact, because a rare invader is linear in its own density.
  - It is also an attribution of selection by when, where in the life cycle, and
    through which resource.
- **Two sweeps split selection into advantage and the commons** (*derived*,
  identities I1–I5).
  - The field-held derivative is the selection gradient g.
  - The field-responding derivative F_θ is how a monoculture's own seed output
    changes.
  - Their difference is the externality: what an individual's trait takes from
    its neighbours through the field.
  - *Measured* on long drought, for lma: −23.8 held against −5.9 responding along
    the trade-off, and −37.1 against −9.96 alone. Three quarters of a rare
    individual's gain from lower lma is taken from its neighbours.
- **Selection is the invader's sensitivity to the field, times how the
  equilibrium field moves** (I5): `g = −⟨φ_E, dE*/dθ⟩`.
  - This is Meszéna's regulating-variable framework, and the
    Metz–Mylius–Diekmann pessimisation argument, in a form the machinery can
    evaluate.
  - The same sensitivity functions are what coexistence theory needs: mutual
    invasibility requires non-collinear sensitivities to the field.

So adaptive dynamics, coexistence theory, EEO and life-history optimal control
are four descriptions of one feedback loop: a resident makes a field, and fitness
is evaluated in it. The machinery computes that loop's derivatives directly. The
outputs that matter are not "a faster gradient" but these:
- the all-trait selection vector;
- the commons vector;
- reproductive-value maps over size, age and patch age;
- the field sensitivities;
- the time-resolved attribution of selection.

## 2. What this makes computable, and what it costs

Ranked by ecological significance (`theory.md` E.1, with costs from
`rootcause/` and status checked in the code):

| | what | cost (forwards at b*) | status |
|---|---|---|---|
| 1 | the selection gradient for all ~50 traits at once, and with mutational covariance the direction of evolution | 2.7, against about 60 by differences | built: an invader at θ′ = θ and its sweep |
| 2 | the commons vector, F_θ − g, per trait: how far the ESS sits from what is best for the stand | +2.3 (one resident sweep) | built |
| 3 | where and when selection acts: g broken down by birth date, patch age, state, and light against water | within the same sweeps | the adjoints are computed but not exposed |
| 4 | the sensitivity of J, b* and invasion fitness to each day's rainfall | one further pass, first order | not built (the field hook is a spike; the two-stage adjoint is designed only) |
| 5 | coexistence structure: each species' sensitivity to the field and impact on it | sweeps per species | partly built |
| 6 | singular strategies in many traits and their classification, at O(k) sweeps instead of O(k²) runs | chords of sweeps; equilibrium followed along its curve | pieces built; the loop is not |
| 7 | tests of EEO criteria (profit maximisation, a derived Cowan–Farquhar λ) against costate prices | from exposed costates | not built |
| 8 | coexistence-theory decomposition | first-order terms only | derivation only |

The equilibrium is no longer the scarce resource. The gradient moves only
3.4 × |ln J − ln b| (*measured*, E5). The curve's direction comes from the
resident sweep. So following b* along an evolutionary path costs one run per
step (`rootcause/` §7).

## 3. Novelty (`literature.md`)

- **All-trait selection gradients for a mechanistic forest model:** novel.
  - Prior work stops at 2–3 traits: Falster et al. 2017 PNAS (2 traits); Plant-FATE
    (2, by finite differences); Lichstein et al. 2024 (2-D grid search);
    Dybzinski et al. and Farrior et al. (2–3, analytically).
  - Trait-flexible vegetation models carry 5–15 traits but compute no
    gradients: JeDi, LPJmL-FIT, aDGVM2.
  - CCDAS used adjoints of about 57 parameters, but of carbon fluxes, not
    fitness.
- **ESS analysis under daily-resolved variable climate with shared soil
  water:** partly novel.
  - ESS analyses under variable rainfall exist, but in simplified models
    (Farrior et al. 2015; Lu et al. 2020), as 2-D brute-force searches (Lichstein
    et al. 2024), or with soil water read from a file (Plant-FATE).
  - None does singular-strategy classification in a size-structured model with a
    dynamic shared water store under multi-decadal daily records.
- **Adjoints for selection gradients:** novel as a computation, not as a concept.
  The costate is reproductive value in analytic adaptive dynamics (Parvinen,
  Heino & Dieckmann 2013; Metz, Staňková & Johansson 2016). No one has computed
  it numerically through an ecological simulation.
- **Differentiating through a nested inner optimum** (the leaf) and an outer
  game: novel. Plant-FATE has the structure but differentiates neither level.
- **Attributing selection to times or droughts via adjoints:** novel in ecology.
  - The precedents are stochastic elasticities (Haridas & Tuljapurkar; Horvitz et
    al. on hurricanes), statistical climate-window methods, and adjoint
    attribution in sea-ice and ocean science.
  - The attribution is linear: it measures sensitivity at an event, not the
    effect of removing it.

Questions the literature flags as open, which this machinery answers directly
(`literature.md`, open questions):
1. Are high-dimensional singular strategies convergence-stable? Leimar and
   Débarre et al. predict this becomes rare as the dimension grows; no
   mechanistic test exists.
2. How many directions favour branching?
3. Where does optimality disagree with the ESS? That is the commons vector, in 50
   traits; Lichstein et al. measured it in 2-D.
4. Is Falster et al.'s evolved near-neutrality a low-curvature subspace?
5. Does rainfall variability add or remove branching directions, at a fixed mean?
6. Which droughts drive selection on which traits? Siepielski et al. 2017 found
   that precipitation drives selection, but not the mechanism.
7. How much, and in which signs, does selection vary between records of one
   climate?
8. Can the model serve as ground truth for Lande–Arnold regressions?

## 4. regnans (`regnans.md`)

regnans is further along than `../design-workflows.md` records:
- It already has the k-dimensional canonical equation with a full mutational
  covariance, coalitions, a six-way classifier, continuation, and coexistence
  boundaries (#84).
- Its README: "designed around the exact derivatives that `plant` is gaining
  through automatic differentiation."
- Its roadmap's Tier B names "10–48 TF24 traits co-evolving" and "`dx*/dp` for
  every model parameter in one adjoint sweep".

Where it stands against this:
- **The premise to correct.** Open PR #87 keeps plant's exact gradients opt-in.
  It warns that the AD columns are "optimistic by an order of magnitude", citing
  FF16 sweeps at 21–32 times a run (traitecoevo/plant#677). TF24's sweep
  measures 2.05–2.9 forwards. The two have not been compared on the same footing.
- **The entry point, which has the algebra but not the plumbing.** Open PR #89
  (issue #88) adds `derivative_control(resident_jacobian = "implicit")`, with
  `dn*/dx = −S_n⁻¹ S_x` and `dg/dx = G_x + G_n dn*/dx`. These are the predictor
  (I4) and the convergence-Jacobian shortcut.
  - They are used only for the convergence Jacobian: in classification, and in
    the canonical equation's stiff solver. They are not used to step the birth
    rate along a path.
  - The blocks come from central differences in `fixed_environment_jacobian()`:
    2m(k + 1) runs at given traits and densities, each with 2k mutants for G.
    Its comment names it as where a differentiating harness "would supply these
    blocks instead"; no such connector exists.
  - The default stays `"stencil"`.
  - What our loop still needs from regnans:
    - a sweep-fed connector: S_x and S_n from one resident sweep, and G_x and
      G_n from chords of invader sweeps;
    - the predictor used in the evolutionary step;
    - a TF24 bridge;
    - a tolerance on F set by the gradient's sensitivity.
- **The planned but unbuilt joint eco-evolutionary Newton** on (n, x) is the
  loop that follows the curve.
- **The gaps:**
  - a TF24 bridge (environment, events, given introductions, the equilibrium's
    recording kept);
  - an all-parameter gradient connector;
  - a way to state mutational covariance over 50 hyperparameterised traits;
  - matrix-free solvers for many traits;
  - per-trait scales;
  - handling of jumps.
  - Nothing in regnans names climate.

## 5. Limits, plainly

- **Non-smooth points.** On constant rain the landscape jumps at the resident
  (`rootcause/` §8), and leaf regime switches put corners in the inner optimum.
  The gradient does not exist at such points.
- **Climate is tied to patch age.** Every patch replays the same record from
  disturbance, so variation is along succession. There is no between-year,
  between-patch variation and so no temporal storage effect. The cheapest change
  that adds one is independent records per patch, with fitness as the mean of R′
  over records at a common b (`theory.md` D.3).
- **First order only.** Field and climate attributions are linear. Relative
  nonlinearity and the storage effect are second-order and need chords.
- **Accuracy.** Gradients converge in the introductions differently from ln J
  (E2), and the absolute tolerance's effect on gradients is unmeasured.
- **One record is one realisation.** Fitness theory asks for averages over
  records, as the eight-seed ε does.

## 6. First studies, cheapest first

1. **The all-trait selection vector and the commons vector** on the six smooth
   climates at their b*. About 5 forwards per climate, all built today. This
   answers open question 3 in 50 traits, and gives a direct test of any
   optimisation principle: the angle between g and F_θ.
2. **The same vectors across the eight weather records of long drought:**
   fluctuating selection between records (open question 7).
3. **Expose the costates:** reproductive-value maps, and selection attributed by
   birth date, patch age and channel (light against water), on dry and episodic
   records. This is engineering on tapes that already exist.
4. **regnans #89 fed by sweeps,** then the joint Newton. A singular strategy in
   lma, then in two traits, classified.
5. **The field hook, then the two-stage adjoint:** fitness sensitivity to each
   day's rainfall (open question 6).
