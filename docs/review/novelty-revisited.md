# The literature, revisited from the outcome

`literature.md` §7 judged five claims, (a)–(e). All five are about computing
derivatives of **fitness**: many traits at once, under daily climate, by
adjoint, through an inner optimum, resolved in time. `formulation.md` moved the
object to the **outcome** of evolution, the root x*(c) of G(x; c) = 0, and its
derivatives. Read from there, the earlier review missed two things:
- literatures whose central quantity is a derivative of an evolved outcome,
  which this machinery computes and which they estimate, assume or fit;
- uses of objects already computed, that have names elsewhere.

*Derived* means ours and checked by no one; *judgement* is marked. References
were checked against Crossref.

## 1. Literatures whose central quantity we compute

Each row is a field whose key number is an object in `formulation.md`. None
was in `literature.md`.

| field | their quantity | ours |
|---|---|---|
| ESS comparative statics | how the ESS moves with the environment, which depends on where density dependence acts (Abrams 1993; Mylius & Diekmann 1995) | dθ*/dc, with the feedback carried by light and water rather than assumed |
| functional biogeography | slopes of community trait means on climate (Wright et al. 2005) | dθ*/dc, for every trait and climate input |
| EEO in land models | climate response of the leaf's operating point, e.g. χ = cᵢ/cₐ (Prentice et al. 2014; Harrison et al. 2021) | the plastic part (inner optimum at fixed θ) plus the evolved part (through θ*) |
| moving optimum and rescue | the optimum's slope B, plasticity b, width of selection ω, r_max (Chevin, Lande & Mace 2010; Kopp & Matuszewski 2014) | B = dθ*/dc; b from the inner optimum; ω from the invader Hessian; F gives growth |
| provenance trials | transfer functions: a source's performance against climatic transfer distance (Wang, O'Neill & Aitken 2010); climate-adjusted provenancing (Prober et al. 2015); local adaptation (Leimu & Fischer 2008) | θ*(c_source) as an invader in the recording of c_site |
| Darwinian agriculture | individual selection against stand yield: the communal ideotype (Donald 1968; Denison, Kiers & West 2003; Anten & Vermeulen 2016) | g (field held) against the gradient of a stand metric (field responding) |
| fire ecology | the interval squeeze: fire intervals shorter than maturation remove obligate seeders (Enright et al. 2015; Bowman et al. 2014, for alpine ash) | dx*/d(mean fire interval), and the fold where a species is lost |
| function-valued traits | Pontryagin conditions for schedules (Dieckmann, Heino & Parvinen 2006); reproductive allocation schedules (Wenk & Falster 2015) | the functional gradient δ ln R′/δa(h), at the cost of any trait |
| trait-flexible vegetation models | trait diversity buffers forest loss under drying, by simulation (Sakschewski et al. 2016) | dy/dc = ∂y/∂c + ∂y/∂x · dx*/dc for an ecosystem output y: the traits-fixed and evolved parts, exactly |

Four of these deserve a sentence each on why the match is exact, not loose.

**Comparative statics resolves Mylius & Diekmann's warning.**
- Their point: whether, say, higher mortality favours earlier maturation
  depends on which vital rates the density dependence acts on. Analyses in toy
  models therefore had to assume it.
- Here the feedback is the model's light and water, so dθ*/dc carries it
  without assumption. The held and responding columns (I2) say how much of the
  answer comes from the feedback: for `lma` on long drought, most of it
  (−23.8 held against −5.9 total).

**Provenance transfer functions are second-order objects in G** (*derived*).
- The strategy evolved at c_t is a singular point there: ln R′ = 0 and g = 0.
- A source evolved at c_s sits at Δθ = θ*(c_s) − θ*(c_t) ≈ (dθ*/dc) Δc.
- So ln R′ ≈ ½ Δcᵀ (dθ*/dc)ᵀ H (dθ*/dc) Δc, with H the invader Hessian: the
  transfer function's curvature, the home-site advantage per unit of climatic
  distance.
- Exact runs need no new code: an invader reads any recording. The quadratic
  form is the check, and the run is the answer far from c_t.
- Transplants of a few plants into a native stand are rare invaders in a fixed
  field, which is exactly what an invader run is.

**Tracking a moving climate needs only G's objects and M** (*derived*, linear).
- The canonical equation dθ/dt = M g, near a singular point that moves with
  c(t), has g ≈ S (θ − θ*). Its steady lag behind a point moving at
  v = (dθ*/dc) ċ is −(M S)⁻¹ v.
- The cost of the lag is ½ lagᵀ H lag in the invader's fitness, and F at the
  lagged traits in the population's balance. The rate ċ at which F reaches the
  fold is the critical rate of climate change.
- Chevin, Lande & Mace (2010) give the same structure with B, b, ω and r_max as
  free parameters. Here every one except M is computed.

**The communal ideotype is the commons vector, in a stand metric.**
- Donald's (1968) ideotype is a weak competitor that yields more as a crop.
  Breeders select individuals in mixed progeny trials, which rewards
  competitive ability, not stand yield.
- `stand_gradient` already differentiates census metrics with the field
  responding: `leaf_area`, `mass_above_ground` and `area_stem`
  (`tf24_strategy.h`, `census_metrics()`). The invader's g is the field-held
  gradient of individual fitness.
- The direction in trait space between them is where breeding for plantations
  should go against natural selection, in every trait at once.

## 2. What we have and have not named

1. **The shared recording is common random numbers.** Comparing two
   strategies on one recorded field removes the variance of the weather from
   the difference. That is why the pulse-driven post found differences
   converge 5–14 times faster than levels (`domain.md` §2). A sweep's gradient
   is the limit of such a difference. Calling it CRN connects it to simulation
   optimisation, where its variance reduction is understood.
2. **The recording is an exact common garden.** `frontier.md` §4.1 named it as
   counterfactuals. Its other names are reciprocal transplant, provenance
   trial and common-garden experiment, which are the field data most directly
   comparable to the model (§1).
3. **The invader Hessian is Lande & Arnold's γ, exact.** It is the width of
   stabilising selection, the ω of moving-optimum theory, and the curvature of
   the provenance transfer function. One object, three literatures.
4. **dθ*/dc is the most-measured quantity in trait ecology.** Trait–climate
   slopes are the bulk of functional biogeography. A model that outputs them
   directly can be calibrated to them: one transpose solve per slope, then one
   climate sweep pair (`formulation.md` §3).
5. **The fire interval is already a cheap input** (*derived*, to check).
   - The disturbance regime enters plant only as a weighting: each node's
     patch density and survival at its birth (`patch.h`, `set_birth_state`,
     `introduce_new_node`) and patch survival in the fecundity accumulation.
     The patch's dynamics do not depend on it.
   - So with the field held, d ln R′/d(interval) is a reweighting of recorded
     quantities: no run. The responding part goes through F_{ln b}.
   - It is a double today. Putting the Weibull parameters on the tape, or
     differentiating the weighting by hand, is a small change.

## 3. Simple extensions, ranked by interest over cost

| extension | what it adds | new code | depends on |
|---|---|---|---|
| trait–climate slopes as the primary output, calibrated to observed slopes | prediction and calibration on the most-measured quantity | none | `formulation.md` §7 check 1 |
| provenance transfer functions | climate-adjusted provenancing for restoration, with a mechanistic transfer function | none | recordings at two or three climates |
| ideotype against ESS | a breeding direction for plantations, in every trait | none | census-metric gradients (built) and g |
| fire interval as an input | the interval squeeze as a fold in (fire interval, rainfall) | small: the weighting's derivative | check 5 above |
| tracking capacity | lag and critical rate of climate change | small, in R | S, dθ*/dc, H; an input M |
| reproductive allocation as a function of height | function-valued trait, Pontryagin condition checked numerically | small: spline coefficients replace `hmat`, `a_f1`, `a_f2` | none |
| plastic and evolved parts of χ | a test of EEO models' plastic predictions | small: χ as a census metric | dθ*/dc |
| ecosystem outputs' climate sensitivity, partitioned | how much evolution and assembly buffer biomass loss under drying | none beyond the solve | a transpose solve per output |

**The pattern** (*judgement*). The highest-value extensions need no new
machinery: they are new readings of dθ*/dc, of H, and of recordings. What they
need is the first check in `formulation.md` §7, dθ*/dc by chords against
re-solved roots, which every row depends on.

**One combined application** (*judgement*). An obligate seeder under fire and
drying, which is the harness's namesake's situation:
- the fold in (fire interval, rainfall) where it is lost;
- how far evolution moves that fold, through the evolved part of dy/dc;
- the transfer function for seed sourcing ahead of the climate.
It uses only the rows above that need little or no code, and it is a question
land managers in south-eastern Australia ask now.

## 4. How the earlier verdicts change

- **(c) adjoint selection gradients:** still novel as a computation. The
  framing should move from "the gradient of fitness by adjoint" to "the
  derivatives of an evolved outcome", which the theory has only analytically
  in toy models (§1, comparative statics).
- **(b) ESS under daily climate:** unchanged, with the domain of `domain.md`
  §2: climate structures B and C, not climate indexed by patch age.
- **New candidates**, each checked in §5:
  - (f) comparative statics of an evolved community in a mechanistic model;
  - (g) calibration of physiology through the evolved outcome;
  - (h) the plastic and evolved partition of a trait's climate response;
  - (i) the solver's spectrum as the ecological classification.

## 5. Verdicts on the new claims

Pending the novelty search.

## References

- Abrams, P.A. (1993). Does increased mortality favor the evolution of more
  rapid senescence? *Evolution* 47: 877–887. doi:10.2307/2410191
- Anten, N.P.R. & Vermeulen, P.J. (2016). Tragedies and crops: understanding
  natural selection to improve cropping systems. *Trends Ecol. Evol.* 31:
  429–439. doi:10.1016/j.tree.2016.02.010
- Bowman, D.M.J.S., Murphy, B.P., Neyland, D.L.J., Williamson, G.J. & Prior,
  L.D. (2014). Abrupt fire regime change may cause landscape-wide loss of
  mature obligate seeder forests. *Global Change Biol.* 20: 1008–1015.
  doi:10.1111/gcb.12433
- Chevin, L.-M., Lande, R. & Mace, G.M. (2010). Adaptation, plasticity, and
  extinction in a changing environment: towards a predictive theory. *PLoS
  Biol.* 8: e1000357. doi:10.1371/journal.pbio.1000357
- Denison, R.F., Kiers, E.T. & West, S.A. (2003). Darwinian agriculture: when
  can humans find solutions beyond the reach of natural selection? *Q. Rev.
  Biol.* 78: 145–168. doi:10.1086/374951
- Dieckmann, U., Heino, M. & Parvinen, K. (2006). The adaptive dynamics of
  function-valued traits. *J. Theor. Biol.* 241: 370–389.
  doi:10.1016/j.jtbi.2005.12.002
- Donald, C.M. (1968). The breeding of crop ideotypes. *Euphytica* 17:
  385–403. doi:10.1007/BF00056241
- Enright, N.J., Fontaine, J.B., Bowman, D.M.J.S., Bradstock, R.A. &
  Williams, R.J. (2015). Interval squeeze: altered fire regimes and
  demographic responses interact to threaten woody species persistence as
  climate changes. *Front. Ecol. Environ.* 13: 265–272. doi:10.1890/140231
- Harrison, S.P. et al. (2021). Eco-evolutionary optimality as a means to
  improve vegetation and land-surface models. *New Phytol.* 231: 2125–2141.
  doi:10.1111/nph.17558
- Kopp, M. & Matuszewski, S. (2014; online 2013). Rapid evolution of
  quantitative traits: theoretical perspectives. *Evol. Appl.* 7: 169–191.
  doi:10.1111/eva.12127
- Leimu, R. & Fischer, M. (2008). A meta-analysis of local adaptation in
  plants. *PLoS ONE* 3: e4010. doi:10.1371/journal.pone.0004010
- Mylius, S.D. & Diekmann, O. (1995). On evolutionarily stable life histories,
  optimization and the need to be specific about density dependence. *Oikos*
  74: 218–224. doi:10.2307/3545651
- Prentice, I.C., Dong, N., Gleason, S.M., Maire, V. & Wright, I.J. (2014;
  online 2013). Balancing the costs of carbon gain and water transport:
  testing a new theoretical framework for plant functional ecology. *Ecol.
  Lett.* 17: 82–91. doi:10.1111/ele.12211
- Prober, S.M. et al. (2015). Climate-adjusted provenancing: a strategy for
  climate-resilient ecological restoration. *Front. Ecol. Evol.* 3: 65.
  doi:10.3389/fevo.2015.00065
- Sakschewski, B. et al. (2016). Resilience of Amazon forests emerges from
  plant trait diversity. *Nature Clim. Change* 6: 1032–1036.
  doi:10.1038/nclimate3109
- Wang, T., O'Neill, G.A. & Aitken, S.N. (2010). Integrating environmental and
  genetic effects to predict responses of tree populations to climate. *Ecol.
  Appl.* 20: 153–163. doi:10.1890/08-2257.1
- Wenk, E.H. & Falster, D.S. (2015). Quantifying and understanding
  reproductive allocation schedules in plants. *Ecol. Evol.* 5: 5521–5538.
  doi:10.1002/ece3.1802
- Wright, I.J. et al. (2005). Modulation of leaf economic traits and trait
  relationships by climate. *Global Ecol. Biogeogr.* 14: 411–421.
  doi:10.1111/j.1466-822x.2005.00172.x
