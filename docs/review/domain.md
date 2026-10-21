# Working back from H1 and H2 to the model's domain

`frontier.md` proposed field sensitivities S, ∂ ln R′/∂(field), as the object
behind H1 and H2. On reflection that was a symptom of a domain not yet right:
- the field has thousands of coordinates;
- any spectrum of S depends on a choice of bands and units;
- and S still needed impacts beside it to mean anything.

This note works back from the two hypotheses to the ecological theory they rest
on, and asks what the model's domain must represent for them to be well-posed.
The lateral search over adjacent fields is §5, written after two reviews report.

## 1. What H1 asks, stated in theory

H1 says trait syndromes are the image of a few directions through which
selection acts. In theory, that is a statement about **how many independent ways
the environment feeds back on fitness**: the number of regulating variables.
- *Established:* that number bounds how many strategies coexist robustly
  (Levin 1970; Meszéna, Gyllenberg, Pásztor & Metz 2006).
- *Established:* an evolutionary optimisation principle exists exactly when the
  feedback is effectively one-dimensional (Metz, Mylius & Diekmann 2008). EEO's
  practice of assuming a criterion that evolution maximises is therefore
  justified exactly where the feedback is one-dimensional, and approximate
  elsewhere.
- *Derived:* H1 generalises that condition. With a few dimensions, evolution
  behaves like optimisation in a few directions, and traits covary along them.

The invariant object is not the field: it is the feedback the field carries.
- Take how a strategy's presence changes the field (its impact), composed with
  how another strategy's fitness responds to that change (its sensitivity).
- The composition is the interaction kernel at the resident's equilibrium:
  **α(θ′, θ) = ∂ ln R′(θ′) / ∂(abundance of θ)**.
- This is Lotka–Volterra's α_ij, generalised to a mechanistic model and a
  continuum of strategies.
- It is basis-free: no bands, no units, no choice of field coordinates. The
  field is only how the interaction happens to be mediated.

The kernel is what each theory reads (*derived*, consistent with Meszéna et al.
2006 and Chesson 2000):

| theory | what it reads from α |
|---|---|
| H1, the number of limiting factors | the rank, or the singular spectrum, of α over trait space |
| coexistence | for a candidate set, α restricted to it: invertible, with the right signs; niche overlap α_ij/√(α_ii α_jj); stabilisation α_ii − α_ij (Chesson's terms, for the Lotka–Volterra case) |
| adaptive dynamics | branching from the kernel's curvature in θ′ − θ against the invader's own curvature: the Roughgarden and Dieckmann–Doebeli picture, generalised |
| EEO | whether α is effectively rank one, i.e. whether an optimisation principle exists, and along which criterion |
| the commons | the resident's α(θ, θ) times its abundance: what it takes from itself through the feedback |

**What the field sensitivities were standing in for.** S is the right half of
α. Computing it alone forces choices (bands, metrics) that α does not need. So
the field should stay where it is, inside the model as the mediator, recorded so
invaders can read it, and not become the coordinate system of the analysis.

**Computing α (*derived*, costs from E7 at absolute tolerance 1e-4, F ≈ 49 s).**
- One column, the resident itself as the competitor, is
  `∂ ln R′(θ′)/∂ ln b` for every invader θ′. It comes from two resident runs at
  b* e^{±δ}, with the invaders read on each. Its diagonal entry is F_{ln b}
  (−1.75 on long drought, measured).
- A column for another strategy θ needs θ present at a vanishing density in the
  resident run: a second species at birth rate ε, differenced or carried by a
  tangent.
- So an n × n kernel over n strategies costs about n perturbed resident runs and
  n² invader reads. At n = 10 that is about 10 F + 100 × 0.6 F ≈ 70 F, about an
  hour on one core.
- With the two-stage adjoint, each invader's whole row would come from one
  reverse pass through a resident run that carries the n strategies at zero
  density. That trades invader runs for a wider resident run.

## 1a. H1 unrolled: the loop is assembly, so the dimension should come from it

Unrolling the eco-evolutionary loop gives community assembly:
- evolve the residents to a singular coalition;
- find the strategy of greatest invasion fitness;
- add it and re-equilibrate;
- repeat.

regnans's assembler already does this (`assembler_control(evolve = ...)`,
`regnans.md`). The kernel α of §1 describes the result. Computing α separately,
at about an hour per iteration, would duplicate work the loop does anyway.

**The dimension is read from the loop's own outputs** (*derived and judgement*):
- **The assembled community is the measurement.** How many species accumulate
  before no invader has positive fitness, and the directions in trait space they
  span, are H1's quantities directly: the number of limiting factors, and the
  modes.
- **Every iteration already computes the gradients that span the modes.**
  - Each invader evaluation yields ∇_{θ′} ln R′ in every trait (an invader run
    and one sweep).
  - The span of the gradients gathered across iterations, with the curvature
    estimates a quasi-Newton search builds, is the subspace the landscape varies
    in.
- **That subspace makes the search cheap.**
  - Finding the best invader in 50 traits needs a gradient-based search: tens of
    invader evaluations, not a grid.
  - If H1 holds, later iterations can search within the subspace earlier ones
    found, and need fewer evaluations still.
  - So the loop measures H1 and, if H1 is true, gets cheaper because of it.
- **Per iteration** (costs at absolute tolerance 1e-4, F ≈ 49 s; E7):
  - the best-invader search: about 15–30 invader evaluations at 2.5 F each, so
    40–75 F;
  - re-equilibration: one resident sweep per species for the birth-rate
    Jacobian, about 2 F each, or secant runs;
  - evolving the coalition: following its equilibrium, about 2–6 F per step.
- **The invader evaluation is the cost to shrink:**
  - the five sweep issues (about 1.9 → 1.1 F);
  - introductions thinned to those carrying R′ (about 0.5×; `grid-dynamics.md`
    §14);
  - batching several invaders into one sweep, once that is checked to work on
    the #116 design.

## 2. What H2 asks, and the domain it needs

H2 says climate variability raises the number of limiting factors. The theory
of fluctuation-dependent coexistence (Chesson 2000; Ellner, Snyder & Adler 2019)
needs three things:
- species that respond differently to the environment;
- environment that covaries with competition;
- buffered growth.

In plant today (`tf24_environment.h`) rainfall is evaluated at the patch's own
time since disturbance, so every patch replays the same weather by age. That
folds climate into succession. H2 is not well-posed there: the one-clock answer
measures an artefact of indexing weather by patch age.

**The domain is already worked out for the semi-arid case** (Overstorey,
"How to calculate fitness in pulse-driven environments", under review as
overstorey PR #43).
- **The principle.** Fitness is a seed's expected lifetime output, averaged over
  the stationary distribution of the local states seeds land in (Metz &
  Gyllenberg 2001). Patch age is that state only in a forest reset by
  disturbance.
- **The state.** Under pulsed rain with no reset, the local state is soil water
  plus the stand in it. Climate is Westoby's (1980) distribution of "types of
  time": just wetted, staying wet, drying out.
- **The method.**
  - One long run in calendar time, under one realisation of the rain, with the
    residents settled to a stationary state.
  - Mutant nodes introduced at every germinating rain in a window after the
    burn-in, each running out its life.
  - Fitness is the mean of their lifetime outputs.
  - For annuals, the mean log of yearly multiplication. That is Cohen's
    germination problem and the storage effect, computed directly.
  - Landscape positions sharing one storm series give a matrix, whose largest
    eigenvalue is fitness.
- **Comparisons converge faster than levels.** On one shared rain series, the
  toy needs 5–14 times fewer years for a difference between strategies than for
  one strategy's fitness.

What this means for our machinery (*judgement*):
- **Invaders reading a recorded field are the method's natural form.** The long
  resident run is recorded once. Every mutant at every germinating rain reads its
  field, so the recording is the shared rain series made concrete.
- **A selection gradient from the sweep is the limit of a shared-series
  comparison:** an infinitesimal difference between strategies on the same rain.
  The post's variance result (comparisons are cheaper than levels) is therefore
  an argument for adjoint gradients over differences of separate runs.
- **What it needs from plant:**
  - the continuous patch runner the post names (introductions as it goes,
    starting from a saved state, history thinned);
  - a recording long enough to cover the window, so memory and thinning matter;
  - sweeps carried back through one lifetime per mutant cohort.
- **With disturbance as well,** the forest and the semi-arid cases combine: two
  clocks. Calendar time carries the weather, and patch age the succession, and
  the local state is (patch age, soil water, stand).

H2, posed in this domain: does the number of distinct types of time that
strategies partition rise with rainfall variability at a fixed mean?

## 3. The other domain fix: variance

Constant rain (E8) showed that without variance the stand is one even-aged
cohort, and a rare invader born at the same instant races it. ln R′ jumps by
about 8 across 0.01% of lma.
- In deterministic cohort models, variance in establishment timing, in seed
  arrival or within cohorts is what makes the fitness landscape and α smooth.
- Weather supplies it on most records and none on constant rain.
- A within-cohort or arrival spread makes it a property of the model, rather than
  of the weather.

## 4. What stays, and what changes

**Stays:**
- the forward recording;
- the reverse sweep, whose adjoint is reproductive value;
- invaders reading the recorded field;
- the equilibrium followed along its curve;
- adjoint rows as the dual of the recording.

**Changes:**
1. **The object of analysis** moves from the field to the interaction kernel α.
   The field stays internal.
2. **Time gets two clocks** before any claim about variability (H2), starting
   with offsets at a common b.
3. **Variance becomes part of the model** where weather does not supply it.
