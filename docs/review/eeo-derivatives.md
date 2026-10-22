# Derivatives of the eco-evolutionary loop, in a mechanistic model

**The finding.** We have, possibly for the first time, the derivatives of the canonical
eco-evolutionary assembly loop for multitrait selection, in a mechanistic forest model,
under variable climate. A resident community makes a field of light and water. A rare
invader's fitness is read in that field. Selection, demography and the community's
response are all derivatives of that loop. TF24 in plant, with reverse-mode adjoints
through the whole run, computes the first-order ones exactly in every trait at once.

This note distils the reviews of 21 October 2026. *Measured* claims cite a run;
*derived* claims are ours and checked by no one else; *judgement* is marked. The full
reviews, with about 150 references checked against Crossref, are on the tag
`archive/trusting-curie` under `docs/review/`: `literature.md` (the novelty verdicts),
`synthesis.md`, `theory.md` (the derivations), `opportunity.md` and
`novelty-revisited.md` (what follows), and `weaknesses.md` (the case against). Measured
numbers are from `docs/measurements/regnans-roadtest/rootcause/` there (E1–E8).

## 1. The loop and its derivatives

Adaptive dynamics, coexistence theory, eco-evolutionary optimality (EEO) and life-history
optimal control describe one feedback loop: a resident makes a field E, and fitness is
evaluated in it (*derived*, `synthesis.md` §1). Its derivatives are the theory's own
objects:

- **The selection gradient g:** the invader's elasticities d ln R′/d ln θ′ at θ′ = θ, the
  field held. With a mutational covariance M, the canonical equation moves the mean trait
  at M g (Dieckmann & Law 1996; Durinx, Metz & Meszéna 2008).
- **The demographic balance F = ln J − ln b,** and its derivatives in the traits, F_θ (the
  field responding), and in the birth rate, F_{ln b}.
- **The commons vector F_θ − g:** what an individual's trait takes from its neighbours
  through the field, per trait. It is how far the ESS sits from what is best for the stand,
  the gap EEO's critics name.
- **The adjoint is reproductive value** (*derived*, `theory.md` F.2). For an invader in a
  held field, the adjoint of each cohort's state is survivorship times the gradient of
  reproductive value in that state; the adjoint of cumulative hazard is Hamilton's force of
  selection. So g is a generalised Caswell formula, the density of individuals times their
  marginal reproductive value times how the trait changes their rates, summed over birth
  date and patch age. It is exact, because a rare invader is linear in its own density.
- **Selection is the invader's sensitivity to the field times how the field moves:**
  g = −⟨φ_E, dE*/dθ⟩ (*derived*, I5). This is Meszéna's regulating variables, and the
  Metz–Mylius–Diekmann condition for when evolution optimises, in a form the machinery
  can evaluate.

## 2. What is built and measured

| | object | status | cost (forward runs at b*) |
|---|---|---|---|
| 1 | g in all ~50 traits at once | built: an invader at θ′ = θ and its sweep (plant#116) | 2.05–2.9, against about 60 by differences |
| 2 | g along the trade-off a trait was built along | built, the default (plant#118) | none extra: the chain rule after the sweep |
| 3 | F_θ, and so the commons vector | built: one resident sweep | +2.3 |
| 4 | through the leaf's inner optimum | built: implicit differentiation of the operating point at every rate evaluation | inside the sweep |
| 5 | under a 40-year daily rainfall record, with shared soil water | built (but see §4: the record is replayed from each patch's disturbance) | — |
| 6 | the equilibrium followed along a path | the gradient moves only 3.4 × \|ln J − ln b\| (E5), and dg/d ln b = −6.0; the resident sweep gives the curve's direction | about one run per step |

**The one striking measured result** (long drought, `lma` 0.32): g in `lma` is −23.8 along
the trade-off against F_θ of −5.9; −37.1 against −9.96 with `lma` alone. Three quarters of
a rare individual's gain from lower `lma` is taken from its neighbours. That is the
competitive over-investment Lichstein et al. (2024) measured in two dimensions, here in
every trait.

**Not built, only derived:** the second order. The Jacobian of the loop G_x, the invader
Hessian, singular strategies classified in many traits, and dx*/dc, the evolved community's
derivative in climate and physiology (§3). Also not exposed: the adjoints themselves, as
reproductive-value maps and selection attributed by time, patch age and channel, though the
tapes hold them.

## 3. What the literature has

Searches to 21 October 2026 (web, Crossref, Europe PMC, publisher abstracts, and the
Plant-FATE source). Absence of evidence is not proof of absence.

| claim | closest prior work | verdict |
|---|---|---|
| (a) selection gradients in all traits of a mechanistic forest model | Falster et al. 2017 (2 traits); Plant-FATE (Joshi et al. 2023 preprint: 2 traits, one-sided differences); Lichstein et al. 2024 (2-D grid search); Dybzinski et al. 2011 and Farrior et al. 2013 (2–3, analytically); CCDAS (Rayner et al. 2005: adjoints of ~57 parameters, but of carbon fluxes, not fitness); JeDi, aDGVM2, LPJmL-FIT (5–15 traits, no gradients) | **novel** |
| (b) ESS analysis under daily-resolved variable climate with shared soil water | Farrior et al. 2015 and Lu et al. 2020 (tractable models, stylised rainfall); Lichstein et al. 2024 (2-D search under scenarios); Plant-FATE (soil water read from a file) | **partly novel** |
| (c) adjoints for selection gradients | costates in analytic adaptive dynamics (Parvinen, Heino & Dieckmann 2013; Metz, Staňková & Johansson 2016); reproductive-value sensitivities in matrix demography (Caswell 2019) | **novel as a computation, not as a concept** |
| (d) differentiating through an inner physiological optimum and an outer game | Plant-FATE has the bilevel structure but differentiates neither level; Wolf, Anderegg & Pacala 2016 and Lu et al. 2020 analytically | **novel** |
| (e) attributing selection to times or droughts by adjoint | stochastic and habitat-specific elasticities (Tuljapurkar et al. 2003; Haridas & Tuljapurkar 2005; Horvitz et al. 2005); adjoint attribution in ocean and sea-ice models | **novel in ecology** (not built: §2) |

**How to state it** (`literature.md` §7, *judgement*):
- The concept is old. Reproductive value is the adjoint of the population state, and theory
  has used it since Fisher, via Pontryagin. The contribution is making that adjoint
  available numerically through a mechanistic, size-structured, climate-forced model.
- The cost argument is concrete. One-sided differences need n + 1 runs per gradient and n²
  for a Hessian, which is why prior work stops at two traits. A sweep gives every trait for
  a small constant multiple of one run.
- Through the inner optimum, the gradient includes the plastic response of the leaf's
  operating point to each trait. It is defined only where that optimum is unique;
  stomatal closure and hydraulic failure are kinks.

**Reframed from the outcome** (`novelty-revisited.md`). The derivatives of fitness are the
machinery. Its uses are the derivatives of the **evolved outcome**: the root x*(c) of the
loop's conditions G(x; c) = 0, with dx*/dc = −G_x⁻¹ G_c by the implicit function theorem.
Several fields have that as their central quantity and estimate, assume or fit it: ESS
comparative statics (Mylius & Diekmann 1995), trait–climate slopes in functional
biogeography, EEO's climate responses in land models (Harrison et al. 2021), moving-optimum
theory (Chevin, Lande & Mace 2010), provenance transfer functions. Verdicts on those uses
are mostly **partly novel**: the questions have precedent, which is the evidence of demand,
and what is new is answering them in a mechanistic model, in many traits and inputs, under
daily climate, by exact derivatives. **PSPManalysis** (de Roos) continues singular points
in physiologically structured models, with finite-difference Jacobians in constant
environments; it is the reference to cite and to benchmark against.

## 4. Where the claim is weakest

From `weaknesses.md`, strongest first:

1. **"Variable climate" is variation along succession.** Rainfall is indexed by patch age:
   every patch replays the same record from its disturbance. There is no variation between
   years across patches, and so no temporal storage effect. ESS analysis "under daily
   climate" is not yet well-posed in the code. The cheapest fix is independent records per
   patch at a common b (`theory.md` D.3), which needs an ensemble, about eight times the
   cost (`domain.md` §2, `lateral-econ-physics.md`: ecosystem demography's two clocks).
2. **The invader's g is not under the scheduling guarantees.** At 108 introductions it is
   5.4ε off while ln J is 0.3ε off (E2). `../schedule/refine.md` (Next) designs the fix.
3. **Size-asymmetric competition makes the landscape non-smooth.** On constant rain ln R′
   jumps by about 8 within 0.01% of `lma`: the invader's cohort races the resident's for the
   canopy (E8). Light breaks monotonicity, so several stable communities are generic, and a
   derivative of the outcome is along one branch.
4. **The outcome is set by the trade-offs, which are assumptions.** Fifty traits are not
   fifty free directions, and nothing measured constrains the trade-off.
5. **No result yet shows the realism changes an answer.** The commons gap is the one
   measured contrast. A reviewer will ask first for a conclusion a tractable (PPA-class)
   model gets wrong.

Objections 4 and 5 and the cost of the second order are what drive the reformulation in
`site-selection.md`.

## 5. What would make the claim stand

1. g under the scheduling guarantees, with its smoothness tested across nearby traits.
2. The all-trait selection vector and commons vector on the six smooth climates at their
   b*, about 5 forward runs per climate, all built. This answers in fifty traits the
   question Lichstein et al. answer in two: where optimality and the ESS disagree.
3. The same vectors across the eight records of one climate: fluctuating selection between
   records (Tuljapurkar 1990; Metz, Nisbet & Geritz 1992).
4. Climate that varies across patches (structure B), so "variable climate" means what a
   reader assumes.
5. For the outcome claims: dθ*/dc by the implicit function theorem against θ* re-solved at
   ±5% mean rainfall, `lma` alone on long drought and episodic; then against PSPManalysis.

## Open questions this answers directly

From `literature.md` §8: whether high-dimensional singular strategies are convergence
stable, which theory predicts becomes rare with dimension (Leimar 2009; Débarre, Nuismer &
Doebeli 2014) and no mechanistic model has tested; how many directions favour branching;
where optimality and the ESS disagree; whether evolved near-neutrality is a low-curvature
subspace; whether rainfall variability adds or removes branching directions at a fixed
mean; and which droughts drive selection on which traits (Siepielski et al. 2017 found that
precipitation drives selection, but not the mechanism).

## References

Each was resolved against Crossref in the original reviews unless marked.

- Caswell, H. (2019). *Sensitivity Analysis: Matrix Methods in Demography and Ecology.*
  Springer. doi:10.1007/978-3-030-10534-1
- Chevin, L.-M., Lande, R. & Mace, G.M. (2010). *PLoS Biol.* 8: e1000357.
  doi:10.1371/journal.pbio.1000357
- Débarre, F., Nuismer, S.L. & Doebeli, M. (2014). Multidimensional (co)evolutionary
  stability. *Am. Nat.* 184: 158–171. doi:10.1086/677137
- de Roos, A.M. PSPManalysis (R package; CRAN). No DOI.
- Dieckmann, U. & Law, R. (1996). *J. Math. Biol.* 34: 579–612. doi:10.1007/BF02409751
- Durinx, M., Metz, J.A.J. & Meszéna, G. (2008). *J. Math. Biol.* 56: 673–742.
  doi:10.1007/s00285-007-0134-2
- Dybzinski, R., Farrior, C., Wolf, A., Reich, P.B. & Pacala, S.W. (2011). *Am. Nat.* 177:
  153–166. doi:10.1086/657992
- Falster, D.S., Brännström, Å., Westoby, M. & Dieckmann, U. (2017). *PNAS* 114:
  E2719–E2728. doi:10.1073/pnas.1610206114
- Farrior, C.E., Dybzinski, R., Levin, S.A. & Pacala, S.W. (2013). *Am. Nat.* 181: 314–330.
  doi:10.1086/669153
- Farrior, C.E., Rodriguez-Iturbe, I., Dybzinski, R., Levin, S.A. & Pacala, S.W. (2015).
  *PNAS* 112: 7213–7218. doi:10.1073/pnas.1506262112
- Haridas, C.V. & Tuljapurkar, S. (2005). *Am. Nat.* 166: 481–495. doi:10.1086/444444
- Harrison, S.P. et al. (2021). *New Phytol.* 231: 2125–2141. doi:10.1111/nph.17558
- Horvitz, C.C., Tuljapurkar, S. & Pascarella, J.B. (2005). *Ecology* 86: 3312–3322.
  doi:10.1890/04-1187
- Joshi, J. et al. (2023). Plant-FATE. Preprint and code (IIASA; GitHub, branch
  `feature_evolution`, read 21 Oct 2026).
- Leimar, O. (2009). Multidimensional convergence stability. *Evol. Ecol. Res.* 11:
  191–208. No DOI.
- Lichstein, J.W. et al. (2024). *J. Ecol.* 112: 2522–2539. doi:10.1111/1365-2745.14416
- Lu, Y., Duursma, R.A., Farrior, C.E., Medlyn, B.E. & Feng, X. (2020). *New Phytol.* 225:
  1206–1217. doi:10.1111/nph.16207
- Metz, J.A.J., Mylius, S.D. & Diekmann, O. (2008). When does evolution optimize? *Evol.
  Ecol. Res.* 10: 629–654. No DOI.
- Metz, J.A.J., Nisbet, R.M. & Geritz, S.A.H. (1992). *Trends Ecol. Evol.* 7: 198–202.
  doi:10.1016/0169-5347(92)90073-K
- Metz, J.A.J., Staňková, K. & Johansson, J. (2016). *J. Math. Biol.* 72: 1125–1152.
  doi:10.1007/s00285-015-0938-4
- Mylius, S.D. & Diekmann, O. (1995). *Oikos* 74: 218–224. doi:10.2307/3545651
- Parvinen, K., Heino, M. & Dieckmann, U. (2013). *J. Math. Biol.* 67: 509–533.
  doi:10.1007/s00285-012-0549-2
- Rayner, P.J. et al. (2005). *Global Biogeochem. Cycles* 19: GB2026.
  doi:10.1029/2004GB002254
- Siepielski, A.M. et al. (2017). *Science* 355: 959–962. doi:10.1126/science.aag2773
- Tuljapurkar, S. (1990). *Population Dynamics in Variable Environments.* Springer.
  doi:10.1007/978-3-642-51652-8
- Tuljapurkar, S., Horvitz, C.C. & Pascarella, J.B. (2003). *Am. Nat.* 162: 489–502.
  doi:10.1086/378648
- Wolf, A., Anderegg, W.R.L. & Pacala, S.W. (2016). *PNAS* 113: E7222–E7230.
  doi:10.1073/pnas.1615144113
