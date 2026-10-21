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

## 2. What H2 asks, and why the current domain cannot answer it

H2 says climate variability raises the number of limiting factors. The theory
of fluctuation-dependent coexistence (Chesson 2000; Ellner, Snyder & Adler 2019)
names what is needed for that:
- species respond differently to the environment;
- **the environment covaries with competition across patches or years;**
- and growth is buffered.

In plant today (checked in `tf24_environment.h`), rainfall is evaluated at the
patch's own time since disturbance. Every patch replays the same weather by age:
a drought at age 8 happens in every patch, at age 8.
- So climate is folded into succession. A drought becomes a fixed feature of the
  successional sequence, as deterministic as canopy closure.
- That can create a timing niche locked to patch age that no real forest has,
  overstating H2.
- And it cannot create the covariance between environment and competition across
  patches of different ages that a real, region-wide drought creates, which
  understates it.
- So H2 is not well-posed in the one-clock domain: its answer there measures an
  artefact of indexing weather by patch age.

**The domain H2 needs has two clocks** (*judgement*):
- calendar time t, which carries the weather and is shared by every patch;
- patch age a, which carries succession;
- a patch disturbed at τ experiences the rain of τ + a.

The resident's regional seed rain b(t) then varies in calendar time, and
invasion fitness is a long-run growth rate in that varying environment (Metz,
Nisbet & Geritz 1992). Two levels of approximation:
1. **Offsets at a common birth rate.** The resident's patches are run at n
   disturbance dates τ_i under one long calendar record, at a common b. Fitness
   is the mean of R′ over the offsets (`theory.md` D.3).
   - It costs n runs, each today's run with the record shifted.
   - It captures the drought hitting patches of all ages at once. It misses the
     variation of seed rain in time.
2. **A periodic regional equilibrium.** The record repeats with period P.
   - b(t) is periodic, solved as a fixed point in the space of seed-rain
     functions, with the per-time birth-rate columns of the sweeps as its
     Jacobian. Fitness is a periodic renewal R₀ (Bacaër & Guernaoui 2006).
   - It captures both effects, at n runs per Newton step.

The kernel α is the same object in either. H2 becomes: does α's rank, or its
spectrum, rise with variability at a fixed mean, in the two-clock domain?

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
