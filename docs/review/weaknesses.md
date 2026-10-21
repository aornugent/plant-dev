# Where the design is weakest, and why no one has done this

The case against the design, made as strongly as the evidence allows, then the
reasons the gap exists. Numbers are from `../measurements/regnans-roadtest/rootcause/`
(E1–E8) unless marked *estimated*.

## 1. The case against, strongest first

**1. Nothing about the outcome has been measured.**
- G_x, dx*/dc, the transpose solve, the Ritz classification and the transfer
  functions are all derived on paper. The first check, dθ*/dc by chords
  against re-solved roots (`formulation.md` §7), has not been run.
- The quantity everything rests on, the invader's g, is not under the
  scheduling guarantees. At 108 introductions it is 5.4 ε off while ln J is
  0.3 ε off (E2). Its smoothness across a grid's radius, which continuation
  needs, is untested.
- So the design is weakest exactly where it claims most.

**2. Size-asymmetric competition makes the landscape non-smooth, and that is
the regime the model exists for.**
- On constant rain ln R′ jumps by about 8 within 0.01% of `lma` (E8): the
  invader's cohort races the resident's for the canopy. Any record where one
  cohort dominates recruitment behaves the same way.
- The leaf's regime switches, the soil substeps and the positive part of net
  production are kinks inside every run (plant#112).
- Light breaks monotonicity, so alternative stable communities are generic
  (`lateral-games.md` §3). "The derivative of the outcome" is then a
  derivative along one branch, chosen by history.
- Adaptive dynamics assumes smooth fitness and small steps. One-sided light
  competition is where both fail first. A critic would say the machinery is
  exact where the model is least interesting, and silent or wrong where it is
  most.

**3. The headline domain is not built.**
- Rainfall today is indexed by patch age, so "variable climate" is variation
  along succession (`domain.md` §2). The claim "ESS under daily-resolved
  climate" is not well-posed in the code that exists.
- Structure B (independent weather per patch at a common b) needs an ensemble:
  ε was set from eight records, so every quantity costs about eight times
  more. Structure C needs sequence-space kernels that do not exist.

**4. The answer is set by the trade-offs, which are assumptions.**
- Fifty traits are not fifty free directions. The total derivative follows the
  hyperparameter trade-off (`stand_gradient`'s default), and the ESS sits
  where the trade-off's costs balance. Change the trade-off and the outcome
  moves, by an amount no measurement constrains.
- Exact derivatives of a model whose structural uncertainty is large buy
  precision the conclusions cannot use. ε itself is a tenth of the weather's
  spread across records; the trade-off's uncertainty is not in ε at all.
- The reply, that dx*/dc with respect to the trade-off constants says which
  assumptions matter, is real but makes the design a sensitivity analysis of
  assumptions, not a prediction.

**5. The cost may not close at the scale the applications need** (*estimated*).
- F ≈ 49 s on long drought at an absolute tolerance of 1e-4 (E7).
- A product G_x v by chords is two invader sweeps and a resident sweep, about
  5 F. Ten Krylov iterations and three Newton steps give about 150 F, two
  hours per root, per record. Eight records for B: about sixteen hours per
  climate point.
- Trait–climate slopes across sites, provenance surfaces and climate-tracking
  maps need tens to hundreds of climate points. That is CPU-months.
- Cheaper models (PPA, Plant-FATE) get analytic or 2-trait finite-difference
  answers in minutes.

**6. If H1 is true, the adjoint's advantage shrinks.**
- The adjoint wins when k is large: one sweep against k + 1 runs.
- If selection acts in two or three modes, finite differences along those
  modes cost three or four runs, comparable to a sweep. The adjoint is then
  needed to find the modes, and little after.
- H1 being true is the interesting result, and it weakens the case for the
  machinery that found it.

**7. Evolutionary equilibrium may be the wrong object for forests.**
- Trees live long and climate moves within a few generations. A stationary
  record's ESS is where evolution would go, not where forests are.
- Trait–climate slopes in data are mostly species turnover, not evolution
  within species. That is assembly from a regional pool, which the same G
  describes, but the mutational covariance M and the pool are not in the model.
- Data identify only the row space of dx*/dc (`novelty-revisited.md` §6), so
  calibrating fifty physiological constants from trait data is
  underdetermined.

**8. No result yet shows the realism changes an answer.**
- The case for TF24 over a tractable model is that hydraulics, size structure
  and shared water change conclusions. The one measured contrast that does is
  the commons gap for `lma` (−23.8 held against −5.9 total). The other
  striking result, the constant-rain race, is an artefact of missing variance.
- Without a conclusion a simpler model gets wrong, a reviewer will ask why the
  cost is worth paying.

**9. The stack is hard to maintain.**
- Reverse mode through an adaptive integrator with node insertions, a recorded
  field, an implicit inner optimum and kink handling, across three C++
  packages templated on the scalar type. Bit-identity guards and header-inline
  rebuilds make every change slow.
- The group that would maintain it is small. A design one person understands
  is a design with a bus factor of one.

## 2. Which are fatal

| weakness | fatal? | what settles it |
|---|---|---|
| 1, unmeasured | no, but it decides everything else | `formulation.md` §7 checks 1–2 |
| 2, non-smooth landscapes | in some regimes | the across-record spread of g, and how often one cohort dominates on realistic records; variance in the model where weather supplies none |
| 3, domain | no, but the headline waits on it | B with a few records |
| 4, trade-offs | scientifically, the largest risk | report dx*/dc in the trade-off constants beside every prediction |
| 5, cost | for maps, possibly | the five sweep issues, abs 1e-4, judging only the loop's targets (`scheduling-pareto.md` §5), records in parallel |
| 6, H1 shrinks the advantage | no: a result either way | — |
| 7, equilibrium | for prediction, partly | frame as assembly from a pool; use transient tracking (lag) for climate change |
| 8, realism unproven | the one a reviewer asks first | one conclusion a PPA-class model gets wrong, with the reason |
| 9, maintenance | slowly | the AGENTS.md rules, upstreamed small PRs |

## 3. Why no one has done this

**The prerequisites arrived separately and recently.**
- A cohort model that records the residents' field and evaluates invaders in
  it: plant since 2016.
- An operator-overloading AD tool for templated C++ that handles a long
  adaptive integration with checkpoints: XAD has been open source only since
  2022. Earth-system adjoints used source transformation (TAF), commercial and
  tied to Fortran.
- Implicit differentiation through an inner optimum as routine practice came
  from machine learning, around 2019–2022.
- The scalar templating of plant's core, the recording and the reverse sweep
  through node insertions are this project's own work.

**The communities that would each do part of it have no reason to do all of
it.**
- Adaptive-dynamics theorists use models they can solve analytically; a
  mechanistic model hides the mechanism they study.
- Vegetation and Earth-system modellers use optimality, which is cheap and
  calibrates well. Metz, Mylius & Diekmann (2008) tell them optimality is
  exact when feedback is one-dimensional, and they treat the rest as small.
- Demographic land models (LM3-PPA, BiomeE, ED) get ESS answers in two
  dimensions by grid search, which answers the questions papers ask.
- AD and adjoint specialists know event-driven, non-smooth systems are hard,
  and have no ecological question to pull them in.

**The payoff appears only past a threshold.** With one or two traits finite
differences are cheaper, simpler and good enough. The adjoint pays only for
many traits or many inputs, which no one asks for until the machinery exists
to answer them.

**The fear is justified.** Gradients through size-asymmetric competition jump
(E8). Anyone who tried and saw that would reasonably stop. Getting past it
needed the stability programme (OBJECTIVES) and the observation that variance,
not the solver, is what makes the landscape smooth.

**Data could not test the answer.** Fifty-trait predictions need trait data
on the same individuals across climates. TRY is sparse in exactly that way.
The testable outputs are low-dimensional: trait–climate slopes, transfer
functions, the plastic share of χ (Dong et al. 2020).

## 4. What the steelman says to do first

1. Run the outcome checks before any more design: dθ*/dc by chords against
   re-solved roots, and the preconditioned Krylov count for one, two and all
   traits.
2. Put g under the scheduling guarantees and test its smoothness across a
   radius.
3. Find one conclusion a tractable model gets wrong, and show why.
4. Report every prediction with its sensitivity to the trade-off constants.
