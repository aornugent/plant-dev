# Taking the design apart: the residual, not the root

`weaknesses.md` found four objections that together say the design aims at the
wrong object:
- the evolved outcome is set by trade-offs that are assumptions (4);
- solving for it costs too much at the scale applications need (5);
- if selection has few modes, the adjoint's advantage shrinks (6);
- forests are not at evolutionary equilibrium (7).

This note takes the design apart, finds the trade-off they point to, and puts
it back together around one decision. Numbers are measured (E1–E8,
`../measurements/regnans-roadtest/rootcause/`) unless marked *estimated*.

## 1. What the machinery is strong and weak at

| strong: one run, one scalar, many inputs | weak: many runs, or second order |
|---|---|
| g in every trait from one invader sweep, at about 2.5 F (E7) | a root of G: Newton steps × Krylov iterations × about 5 F per product, about 150 F (*estimated*) |
| any trade-off applied after the sweep: `stand_gradient` adds each derived parameter's partial times the closed-form trade-off's derivative, with no model run | G_x and the invader Hessian: chords of sweeps, which cross the kinks and the races (E8) |
| a recorded field that any invader reads | continuation in c, and dx*/dc |
| the gradient in every climate input from one reverse pass | ensembles that multiply every root by the number of records |

The forward problem, "given the assumptions, where does evolution go", needs
the right-hand column: roots, G_x, second derivatives. That is where all four
objections bite:
- G_x is where the trade-offs enter the location of the root (4);
- the root is the cost (5);
- many cheap directions matter only if they are used many at a time (6);
- the root is the equilibrium (7).

## 2. The trade-off that was missed

**Evaluate the singular-strategy condition at observed communities, as a
residual, instead of solving for it.**
- An observed site supplies what the forward problem solves for: the species,
  their traits, their abundances. Its daily weather supplies the record.
- G(x_obs; c) is then a measurement, not an equation to solve. For each
  species, g is its invader's gradient in the community's recorded field, and
  F its demographic balance.
- **Where the residual is zero within ε**, it constrains the unknowns c: the
  trade-off slopes and the physiology. The data calibrate the assumptions,
  instead of the assumptions predicting the data.
- **Where it is not zero**, it says in which direction, and how strongly, a
  small variant of each species is favoured against the competitors actually
  present, under the site's climate. Evolutionary equilibrium is tested, not
  assumed (§2a).

## 2a. What the residual is, exactly

**What one site returns, per species i:**
1. **F_i = ln R′ at its own traits.** Balancing b sets it to about zero; a
   species that cannot be balanced at its observed traits is a direct
   disagreement between model and site.
2. **g_i, an elasticity per parameter:** d ln R′/d ln θ_k for a rare lineage of
   species i that differs by 1% in θ_k, growing in the light and water the
   observed community makes, under the record. One sweep gives every k.
   - In partials (`hyperpar = NULL`), each parameter moves alone.
   - Along a trade-off, g is Tᵀ g_partial, with T the trade-off's Jacobian.
     "Selection on `lma`" means selection on `lma` with whatever moves with it,
     so its value depends on T. That is why T is what the fit infers.
3. **Optionally, F_θ:** the same species' gradient when all of it changes and
   the field responds. g − F_θ is its commons vector.
4. **Optionally, attribution:** g split over patch age, size and time by the
   adjoint rows, and over the days of the record with climate on the tape.

**What "selection" means here.** g is the selection gradient of adaptive
dynamics: the canonical equation moves the mean trait at M g (Durinx, Metz &
Meszéna 2008). It is per generation of the lineage, and it applies to the
climate regime the record represents, not one year. Without M it gives the
direction and the strength of selection, not the rate of change.

**The scale, from the one number measured.** On long drought at the roadtest's
start (`lma` 0.32, TF24 defaults), g in `lma` along the trade-off is −23.8. A
variant with 1% lower `lma` has ln R′ higher by 0.24, R′ about 1.27. The
defaults are not an observed community, so this says only that they are far
from singular on that record. As a plausibility check (*judgement*):
- Field estimates of standardised linear selection gradients are mostly of
  order 0.1–0.2 per standard deviation (Kingsolver et al. 2001).
- A within-species spread in ln `lma` of 0.2 would turn −23.8 into about 5 per
  standard deviation.
- A residual that large at a real site would point to the trade-off or the
  model before it pointed to real selection.

**A nonzero residual has four readings, which one site cannot separate:**

| reading | its signature across sites |
|---|---|
| a wrong or missing trade-off | shared by every site: one T fits them all |
| disequilibrium: climate has moved, or the species arrived recently | aligned with each site's recent climate trend |
| constraint: little heritable variation in that direction | shared across a lineage's sites, whatever the climate |
| model error | none of the above |

So the residual is a structured decomposition, and the fit is the tool that
separates its parts.

**What is still assumed.**
- **Ecological balance, approximately.** b is balanced so that F ≈ 0. It need
  not be exact: on long drought a gradient read at |F| < 0.06 is within ε,
  because dg/d ln b = −6.0 (E5). A forest recovering from fire or harvest is
  outside this.
- **The record represents the climate regime.** It is replayed as the
  stationary climate the community lives in.

**Not assumed:** evolutionary equilibrium, the trade-off, and the mutational
covariance M.

**What it offers theorists** (*judgement*):
- **A quantitative test of the ESS hypothesis on real communities,** in every
  trait. Tests today compare the signs of trends, in one or two traits.
- **Trade-offs read from outcomes.** Theory knows evolutionary outcomes hinge
  on the trade-off's shape (de Mazancourt & Dieckmann 2004), and cannot
  measure it. Here the slopes that make observed communities singular are
  fitted, with a consistency test across sites. It is revealed preference for
  evolution.
- **Density dependence that is specified, not assumed** (Mylius & Diekmann
  1995): it is the model's light and water.
- **Nash against planner, decided by data.** Do observed traits satisfy g = 0,
  uninvadability, or F_θ = 0, the stand optimum? Each is one sweep, trait by
  trait. This tests whether nature follows an optimisation principle, which
  Metz, Mylius & Diekmann (2008) say exists only when the feedback is
  one-dimensional.
- **Selection separated from inheritance:** β without G, comparable with field
  estimates of selection.
- **The dimension of selection in real communities:** H1, with data.

**What it offers vegetation modellers** (*judgement*):
- **Trait data as a calibration constraint.** Traits are inputs to vegetation
  models today: parameters per functional type. Here AusTraits or TRY
  constrains the physiology through fitness, beside flux data.
- **The convenience of optimality, with competition.** Like the P-model, the
  condition is used algebraically and evolution is never simulated. Unlike it,
  the condition is uninvadability against competitors, which is the gap
  EEO's critics name (Lichstein et al. 2024; Harrison et al. 2021).
- **A cost they can run:** minutes to hours per site, with no evolutionary
  simulation.
- **A mismatch map:** where communities sit away from their singular traits,
  in which traits, and how strongly. Trait-flexible vegetation models need
  exactly this to say where traits will shift.
- **Structural diagnosis:** species that cannot balance, and residuals shared
  by every site, point at missing physiology.

**What it gives up:** the forward prediction of an evolved community in a
climate with no observed community. That is the price, and it is the right
one to pay first.

**Why it suits this machinery, and why others missed it.**
- The residual needs only the strong column: one invader sweep per species per
  site. G_x never appears, because x is observed, not solved for.
- **The residual is linear in the trade-off's slopes.** With the run held at
  the observed point, a trade-off's slopes enter g only through the chain rule
  applied after the sweep, which `stand_gradient` already does in closed form.
  So every slope hypothesis is tested against one sweep, and the slopes that
  make the observed traits singular come from linear least squares (*derived*).
- Theorists had gradients but no data-shaped model. Vegetation modellers had
  data-shaped models but no gradients in many traits, so the residual was out
  of reach and the forward search was the only route.
- EEO's successful models already make this move for physiology: the P-model
  uses the least-cost condition algebraically to predict χ from climate (Wang
  et al. 2017), and never simulates evolution. This is that move for
  competitive, whole-life fitness, which needs exactly the all-trait invasion
  gradient.
- Empirical economics made the same move for dynamic games. Solving the
  equilibrium inside estimation was too costly, so Hotz & Miller (1993) and
  Bajari, Benkard & Levin (2007) plug observed play into the optimality
  conditions instead. Bajari, Benkard & Levin forward-simulate the market under
  observed policies, then require that no deviation pays. Here: the resident
  run under observed traits, then invaders as the deviations.

## 3. Three candidates, each under a different move

**A, the current design [first thought]** (move 6: one system for every
question). Solve G(x; c) = 0, then differentiate.
- Pays for: prediction where no community is observed.
- Costs: Newton–Krylov, G_x, forward-over-reverse sweeps, continuation; about
  150 F per root per record (*estimated*).
- Wins when: trade-offs are known, the climate has no observed analogue, or
  the question is theoretical (H1 and H2 as statements about what evolution
  produces).

**B, the residual at observed sites** (moves 1 and 3: change the quantifier
from every climate to the observed ones; let the data supply the outcome).
- Pays for: 4, 5 and 7, and is indifferent to 6.
- Costs: a site object; trait data in the model's coordinates; a joint test of
  model and equilibrium.
- Wins when: observed traits and daily weather exist at many sites. In
  Australia they do: AusTraits (Falster et al. 2021) for traits, and gridded
  daily weather.

**C, demographic assimilation** (move 3 the other way: compare at the shortest
timescale the data offer). Fit the physiology to remeasured plots' growth and
mortality by size, over short runs.
- Pays for: physiology calibration, cheaply, with no fitness at all.
- Costs: says nothing about selection; needs plot remeasurement data.
- Wins when: the question is the physiology, not selection.

**The floor** is B's core with no new code: run a community at observed traits,
balance F, and read g with `stand_gradient(hyperpar = NULL)`. Every part of it
exists. B is the floor plus a site object and a least-squares fit.

**Winner: B.**
- A fails 5 by arithmetic: about 150 F per root, against about 11 F for B's
  per-species residual and its calibration gradient (§5).
- A needs 4 to be already solved, which B is the instrument for.
- C cannot answer the question asked, selection. It remains the route for
  physiology if B's fit fails (§7).

## 4. The decisions

1. **The unit of analysis is a site:** an observed community under its own
   daily weather. A hypothetical optimum is never the starting point.
2. **The singular-strategy condition is a residual, never a root.** No
   root-finder over traits is built. b is still balanced, one dimension per
   species, because F needs it.
3. **Trade-offs are hypotheses applied after the sweep, never built into the
   run.** The partials are what a site records. A trade-off is a matrix
   applied to them.
4. **First derivatives only.** Second order enters only as a sweep pair along
   one direction the data choose (§5), never as G_x.
5. **A nonzero residual is selection, not error,** until shown otherwise.
   Calibrate on sites whose climate has been stable. Read disequilibrium at
   sites whose climate has moved. Disequilibrium should align with the recent
   climate trend; model error should not.

**Kept true by structure.** The entry point takes an observed community and its
records and returns, per species, the residual and its gradient in c. There is
no function that searches traits for a root, so none can be called.

## 5. Arithmetic, and the consistency pass

**Per species, per site, per record** (*estimated* from E7, F ≈ 49 s at an
absolute tolerance of 1e-4):

| step | cost |
|---|---|
| the resident run at observed traits, b balanced by a secant in ln b | about 3–4 F |
| the invader run and its sweep: g in every trait | about 2.5 F |
| the calibration gradient: the c-gradient of ⟨w, g⟩ for the residual's direction w, from two invaders displaced along ±w (`formulation.md` §3) | about 5 F |
| total | about 11 F, 9 minutes |

**The consistency pass caught a contradiction.**
- Calibrating by iterating an optimiser over all sites multiplies the cost:
  100 sites × 8 records × 50 iterations × 11 F is about 440,000 F, or 6,000
  core-hours. That is the forward problem's cost by another route.
- What avoids it is the split between linear and nonlinear unknowns:
  - **Trade-off slopes are linear:** one pass over the sites, then least
    squares. No iteration.
  - **Physiology constants are not:** one Gauss–Newton step from the
    defaults, using the Jacobian of g in the measured directions (two
    displaced sweeps per measured direction), then one rerun at the fitted c
    to check. Iterate only where the check fails.
- With 5–10 measured directions, that is about 25–50 F per species per site
  per record. For 100 sites and 8 records, about 40,000 F, or 550 core-hours:
  a day on a 32-core machine.
- **The number of records per site is unknown.** It is set by the spread of g
  across records against the residual precision a fit needs.

**Against the objections.**
- 4: the trade-off becomes the fitted quantity. Its slopes cost nothing to
  vary.
- 5: about ten times cheaper per site than a root, with no iteration over
  trade-off hypotheses (*estimated*).
- 6: the cost per site does not depend on the number of traits or hypotheses.
  If H1 holds, it shows up as a low rank of the fitted Jacobian across sites.
- 7: equilibrium is tested, not assumed.
- 2 (non-smoothness): no second derivatives and no Newton through a race.
  Communities of several species on real weather carry more variance than a
  single cohort. Races are still possible: detect a cohort carrying most of R′
  and route that species to one-sided invader runs.

## 6. What survives deletion

| part | why it stays |
|---|---|
| the recorded field, invader runs | the residual |
| the sweep, g in every trait | the residual |
| b balance per species | F at observed traits |
| `hyperpar = NULL` partials and closed-form trade-off derivatives | decision 3 |
| displaced sweep pairs | the calibration gradient |
| records per site | fitness under the site's weather |

**Deleted from the plan:**
- Newton–Krylov, G_x, Ritz classification and deflation;
- forward-over-reverse sweeps;
- continuation in c;
- the interaction kernel α and field sensitivities S.

Climate inputs on the tape and adjoint rows are kept as optional, for
attributing a site's residual to its weather events.

## 7. What this makes hard, and when to switch back

**Bad at:**
- **Climates with no observed community.** Cope with A, locally, on B's
  calibrated c: B removes A's dependence on assumed trade-offs, so A becomes a
  short extrapolation instead of a prediction from first principles.
- **Separating model error from disequilibrium.** Cope by calibrating on
  sites with stable climate, and by the climate-trend signature (decision 5).
- **Traits the data do not measure.** AusTraits covers some of TF24's
  parameters well (`lma`, wood density, height, seed mass) and many not at all
  (hydraulic curves, allocation). The residual is read only in measured
  directions; unmeasured traits are defaults, or unknowns shared across sites.
- **Species the model cannot balance at their observed traits.** Report them:
  each is a direct statement that the model and the site disagree.

**Kill conditions:**
- Trade-offs become well constrained independently → A's forward prediction
  becomes trustworthy, and B shrinks to its validation.
- No shared c makes the residuals small at stable-climate sites → the model,
  not equilibrium, is wrong. C, demographic assimilation, takes over the
  physiology before B is tried again.

## 8. Where it starts

1. **Put g under the scheduling guarantees** (the next work item). It is now the
   whole product, not one input among many.
2. **One site by hand:** a few species at observed traits, on observed weather.
   Balance b, read g with `hyperpar = NULL`, and apply two trade-off slopes
   after the sweep. Check the linearity of decision 3 against a rerun built at
   the second slope.
3. **A handful of sites along one rainfall gradient:** fit one trade-off slope,
   and look at whether the residuals that remain line up with the climate
   trend.

## References

Kingsolver et al. 2001, Durinx, Metz & Meszéna 2008, Metz, Mylius & Diekmann
2008, Lichstein et al. 2024 and Harrison et al. 2021 are listed in
`literature.md`; Mylius & Diekmann 1995 in `novelty-revisited.md`.

- de Mazancourt, C. & Dieckmann, U. (2004). Trade-off geometries and
  frequency-dependent selection. *Am. Nat.* 164: 765–778. doi:10.1086/424762
- Bajari, P., Benkard, C.L. & Levin, J. (2007). Estimating dynamic models of
  imperfect competition. *Econometrica* 75: 1331–1370.
  doi:10.1111/j.1468-0262.2007.00796.x
- Falster, D. et al. (2021). AusTraits, a curated plant trait database for the
  Australian flora. *Sci. Data* 8: 254. doi:10.1038/s41597-021-01006-6
- Hotz, V.J. & Miller, R.A. (1993). Conditional choice probabilities and the
  estimation of dynamic models. *Rev. Econ. Stud.* 60: 497–529.
  doi:10.2307/2298122
- Wang, H. et al. (2017). Towards a universal model for carbon dioxide uptake
  by plants. *Nature Plants* 3: 734–741. doi:10.1038/s41477-017-0006-8
