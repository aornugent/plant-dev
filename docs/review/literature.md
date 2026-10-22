# Literature review: exact multi-trait selection gradients for a size-structured light-and-water forest model under variable climate

> Brought verbatim from `archive/trusting-curie` as the annotated bibliography behind
> `eeo-derivatives.md`. Searched to 21 October 2026; each entry's tag says how far its
> content was checked ([full], [abs], or [bg], from memory). §7(d) needs the correction in
> `eeo-derivatives.md` §3: for the invader's g, the leaf's plastic response drops out by the
> envelope theorem (`theory.md` C.4). Later verdicts on uses of the machinery are in
> `novelty-revisited.md` on the tag, distilled into `eeo-derivatives.md`.

Date of searches: 21 October 2026. Tools: web search, publisher and Europe PMC abstracts, the Crossref API (every DOI below was resolved against Crossref in this session unless marked otherwise), and one source-code inspection (Plant-FATE on GitHub).

## 0. The claim under review, and how this review is organised

The claim: plant's TF24 model (a cohort / characteristic-method SCM with height-structured light competition, a shared soil-water store, and a leaf model that solves an optimal stomatal/hydraulic operating point at every rate evaluation) can deliver, by reverse-mode AD through the whole simulation (including implicit differentiation of the inner optimisation), the exact gradient and Hessian information of invasion fitness with respect to all ~50 physiological and life-history traits at once. Rare invaders are evaluated in the resident's recorded environment (light profile and soil water at every time), under 40-year daily rainfall records (constant, seasonal, episodic, drought). This is to support multi-trait adaptive dynamics, singular-strategy finding and classification, and fitness landscapes under variable climate.

Sections 1-6 cover the six bodies of work. Section 7 gives the novelty verdict for (a)-(e). Section 8 lists open questions in the literature that this machinery could answer. Section 9 is the annotated reference list.

### Verification legend (used in Section 9)

- **[DOI✓]** Authors, year, title, venue and DOI confirmed against Crossref in this session.
- **[page✓]** No DOI exists or none was found; confirmed from the journal page, a repository record, or an indexed abstract.
- **[abs]** The content summary rests on the abstract, read in this session.
- **[full]** The content summary rests on the full text or source code, read in this session.
- **[bg]** The content summary comes from my prior knowledge of the paper. The bibliographic record was verified, but I did not re-read the content in this session.
- **[UNVERIFIED]** I could not confirm that the item exists or what it contains.

Throughout, **Fact:** marks what a source states. **Judgement:** marks my own assessment.

---

## 1. Multi-trait and high-dimensional selection and adaptive dynamics

**Quantitative genetics.** Lande (1979) gave the multivariate response to selection, Δz̄ = G β, where β is the vector of selection gradients (the gradient of log mean fitness with respect to mean phenotype). Lande & Arnold (1983) showed how to estimate β, and the quadratic (curvature) matrix γ, by multiple regression of relative fitness on several correlated traits. Fact: this is the standard empirical framework. Mitchell-Olds & Shaw (1987) identified collinearity and unmeasured traits that affect fitness as the main threats to inference. Kingsolver et al. (2001) and Svensson (2023) synthesise field estimates. Those estimates involve a handful of traits per study and have large sampling error, especially for γ. Walsh & Blows (2009) and Kirkpatrick (2009) argue that G has few dimensions with substantial variance, so whether selection can be answered depends on how β aligns with G's leading eigenvectors.

**Adaptive dynamics.** Metz, Nisbet & Geritz (1992) defined invasion fitness as the long-term exponential growth rate of a rare mutant in the environment set by the resident. Dieckmann & Law (1996) derived the canonical equation dθ/dt ∝ M(θ) ∂s(θ′,θ)/∂θ′|θ′=θ from individual-based stochastic processes, explicitly for multiple traits and coevolving species. Geritz et al. (1998) classified singular strategies in one dimension (ESS, convergence stability, branching) from the second derivatives of invasion fitness. Durinx, Metz & Meszéna (2008) extended the canonical equation to physiologically structured populations, the class TF24 belongs to. Brännström, Johansson & von Festenberg (2013) give a practical introduction.

**Multidimensional stability.** In more than one dimension:

- Leimar (2009) showed that convergence stability depends on the mutational covariance M. He distinguished *strong* convergence stability (stable for every M) and *absolute* convergence stability, and showed that most multidimensional equilibria do not meet the robust conditions.
- Débarre, Nuismer & Doebeli (2014) found that adding trait dimensions tends to destabilise equilibria through three effects: combinatorial, epistatic and genetic-correlation. Higher dimensionality also favours diversification.
- Ito & Sasaki (2016; preprint 2025) give conditions for evolutionary branching in multidimensional trait spaces and under multidimensional constraints.
- Vukics, Asbóth & Meszéna (2003) studied speciation in multidimensional trait space.

**High-dimensional phenotype spaces.**

- Doebeli & Ispolatov (2017) found that the diversity a community saturates at rises roughly exponentially with the dimension of phenotype space, and that coevolutionary dynamics in high dimension can be non-stationary.
- Svardal, Rueffler & Doebeli (2014) argue that organisms with more traits have more potential for diversification.
- Gavrilets (2004; 1997) developed "holey" adaptive landscapes. In very high dimension, nearly neutral networks connect high-fitness genotypes, which changes how speciation and adaptation proceed.

**What these did not do.**

- Fact: these theoretical studies use abstract fitness functions: Gaussian competition kernels, quadratic landscapes, random landscapes.
- Judgement: none computes the full multidimensional selection gradient, the Jacobian of the selection gradient, or the mutant Hessian from a mechanistic, resource-explicit simulation with tens of traits. Leimar's and Débarre et al.'s predictions about stability in high dimension have not been tested in a mechanistic ecological model with realistic trait dimensionality. I found no such test.

## 2. Invasion fitness and adaptive dynamics in fluctuating environments

**Fitness in variable environments.** Metz et al. (1992) defined fitness in general environments, including stochastic ones, as a dominant Lyapunov exponent. Tuljapurkar (1990) gave the theory of the stochastic growth rate λ_S of structured populations in random environments. Ferrière & Gatto (1995) and Rand, Wilson & McGlade (1994) formalised invasion exponents for populations on non-equilibrium (periodic, chaotic) attractors. Schreiber, Benaïm & Atchadé (2011) gave persistence criteria based on invasion growth rates in fluctuating environments.

**Sensitivities of stochastic growth rate.**

- Tuljapurkar, Horvitz & Pascarella (2003) defined stochastic elasticities, including elasticities to perturbations of the mean and of the variance of vital rates.
- Haridas & Tuljapurkar (2005) and Horvitz, Tuljapurkar & Pascarella (2005) introduced habitat-stage (environment-specific) elasticities. These attribute λ_S's sensitivity to particular environmental states, such as post-hurricane habitats.
- Caswell (2019) unifies matrix-calculus sensitivity analysis, including nonlinear and stochastic models.
- Judgement: these computations run a forward population vector together with a backward reproductive-value vector. The backward vector is the adjoint, so time- and state-resolved sensitivity already has a precedent in matrix demography. What has not been done is to apply it to a mechanistic, resource-competition vegetation model.

**ESS and evolution in stochastic environments, plants.**

- Cohen (1966), Slatkin (1974), Philippi & Seger (1989) and Childs, Metcalf & Rees (2010) develop and test bet-hedging theory.
- Sasaki & Ellner (1995) derived ESS phenotype distributions in random environments.
- Childs et al. (2004), Rees et al. (2004), Metcalf et al. (2008) and Rees & Ellner (2009) used stochastic integral projection models (IPMs) fitted to field data. With them they found ESS flowering thresholds in a variable, density-dependent environment and partitioned the effects of fluctuating selection. These are the most developed analyses of ESSs in a size-structured plant model under empirically variable environments.
- Fact: they use statistical vital-rate models with one or a few traits, not mechanistic resource competition. The environment is a year effect, not a daily weather record.

**Evolution of fluctuation-dependent coexistence.**

- Snyder & Adler (2011) found that a storage effect from variable germination evolves only when germination correlates positively with good years. Otherwise the species coevolve constant germination and the storage effect disappears.
- Abrams, Tucker & Gilbert (2013) and Miller & Klausmeier (2017) also analysed whether the storage effect is evolutionarily stable.
- Kremer & Klausmeier (2013, 2017) showed that fluctuation-dependent coexistence can arise by evolutionary branching. Fluctuating environments can also support several alternative evolutionarily stable communities, which they call limiting similarity in environmental preference.
- Yamamichi, Letten & Schreiber (2023) review eco-evolutionary maintenance of diversity in fluctuating environments.
- Grunert et al. (2021) and the reply by Best & Ashby (2021) discuss ESS characterisation in periodically fluctuating populations.
- Sun et al. (2020) applied function-valued adaptive dynamics to evolving reproduction periods in seasonal environments with a physiologically structured model.

**What these did not do.** Judgement: these analyses use low-dimensional traits (typically 1-2), stylised fluctuations (two-season, periodic, i.i.d. years), and unstructured or simply structured populations. I found none that does an adaptive-dynamics analysis, singular strategies included, for a size-structured forest model forced by observed or realistic multi-decadal daily rainfall.

## 3. Eco-evolutionary optimality (EEO) in vegetation, and how it treats competition

**EEO programme.**

- Franklin et al. (2020) argue for building vegetation models on natural selection, self-organisation and entropy maximisation. They show "models of natural selection acting on a few key traits" can generate realistic plant communities.
- Harrison et al. (2021) review EEO as parameter-sparse process representations for land-surface models. They note that EEO for community-level questions and the leaf economics spectrum remains an active research area.
- The P-model (Wang et al. 2017; Stocker et al. 2020) predicts photosynthetic acclimation and χ from optimality, as a light-use-efficiency GPP model.
- Prentice et al. (2014) introduced the least-cost hypothesis for carbon versus water transport.
- Joshi et al. (2022), with the P-hydro model, unify stomatal and biochemical acclimation through a profit-maximisation objective that includes hydraulic cost.
- Rogger et al. (2026, TREED) extend trait- and optimality-based eco-evolutionary vegetation modelling. I verified the record but did not read the content.

**Stomatal optimisation with hydraulics.**

- Cowan & Farquhar (1977) proposed the classical constant-λ water-use optimisation.
- Mäkelä, Berninger & Hari (1996) cast stomatal control during drought as an optimal-control problem. The marginal water cost then appears as a costate variable, which is an adjoint.
- Sperry et al. (2017) and Venturas et al. (2018) maximise instantaneous gain minus hydraulic risk (the "profit" model). Wolf, Anderegg & Pacala (2016), Anderegg et al. (2018), Eller et al. (2018, 2020) (SOX) and Sabot et al. (2020) develop, test and implement related hydraulic optimisation models in land-surface models.
- Fact (Wolf et al. 2016, abstract): the classical constant-λ theory "is not consistent with competition among plants for water". Carbon maximisation without pricing water yields an ESS.
- Lu et al. (2016) found optimal stomatal behaviour under stochastic rainfall. Lu et al. (2020) maximise expected carbon gain under stochastic rainfall "in a competitive environment", with hydraulic damage costs.
- Manzoni et al. (2014) derived optimal water-use strategies under stochastic rainfall. Vico et al. (2017) combined eco-hydrology with an eco-evolutionary (invasion) analysis of drought deciduousness under rainfall statistics.

**Game theory in forests.**

- Givnish (1982), Iwasa, Cohen & León (1985) and Falster & Westoby (2003) established height growth as an evolutionary game, so the ESS height differs from the height that maximises stand productivity.
- Dybzinski et al. (2011) derived analytically the ESS allocation to foliage, wood and fine roots for trees competing for light and nitrogen. They showed that ESS allocations do not maximise growth in monoculture.
- Farrior et al. (2013, 2015) extended this to water and light with rainfall timing. The 2015 paper uses a continuously varying, stochastic soil-moisture environment and finds that competition for water leads to over-investment in fine roots.
- Dybzinski, Farrior & Pacala (2015) and Weng et al. (2019) carry game-theoretic allocation into the LM3-PPA / BiomeE demographic land model.
- Gersani et al. (2001) and Zea-Cabrera et al. (2006) report "tragedy of the commons" outcomes in root and water competition. McNickle & Dybzinski (2013) review game theory in plant ecology.
- Fact (Lichstein et al. 2024, abstract): optimality and community-assembly approaches "are expected to converge only when optimality-based approaches identify competitively dominant strategies". They used LM3-PPA and BiomeE to find competitive versus maximising allocation strategies "in a two-dimensional trait space" under historical, wet, dry and novel-drought climate scenarios at 10 US sites. Competitive strategies over-invest in roots and leaves relative to maximising ones as water stress increases.

**How EEO treats competition.** Judgement: in most implemented EEO modules, the optimisation is per leaf or per plant against a fixed environment. The P-model and P-hydro optimise against imposed climate, and in profit-maximisation models soil water is an exogenous state. The ESS literature (Dybzinski, Farrior, Wolf, Lu, Lichstein) insists that optimisation is valid only when the environment feedback is accounted for. Metz, Mylius & Diekmann (2008) gave the general theory: an optimisation principle exists only for special forms of the eco-evolutionary feedback. A model that solves an inner, instantaneous optimum, nested inside an outer invasion analysis whose environment is the residents' shared light and water, has the structure these papers call for:

- Inner level: physiological optimality, the plastic response.
- Outer level: an ESS over fixed traits.

## 4. Size-structured forest models used for trait evolution

- **plant / SCM.** Falster et al. (2011) related four traits to stand properties (the FF16 basis). Falster et al. (2016) introduced the plant package: SCM (escalator-boxcar-train / characteristics; de Roos 1988; Brännström, Carlsson & Simpson 2013), invasion fitness and fitness landscapes.
- **Falster et al. (2017), PNAS** [full]. Fact: two traits evolve, LMA and height at maturation. Invasion fitness is log10 of the basic reproduction ratio, integrated over a Weibull patch-age distribution under a fixed disturbance interval. The paper describes no climate variability beyond patch disturbance. Assembly proceeds by mutation and immigration steps. The authors note that only two traits are modelled and suggest adding more.
- **Falster, Duursma & FitzJohn (2018)** and **Falster et al. (2021)** use the same model for growth trajectories and emergent competition kernels.
- **Plant-FATE** (Joshi et al. 2023 preprint; IIASA; GitHub) [full, from source code]. A trait-size-structured eco-evolutionary model that couples P-hydro (an inner optimisation) to a PSPM solver. Fact (source code, branch `feature_evolution`, inspected 21 Oct 2026):
  - Two evolvable traits: LMA and wood density.
  - Fitness gradients come from one-sided finite differences. The code adds one "probe" species per trait at θ + 0.001·scale and computes (r0_probe − r0_resident)/dx.
  - Traits are updated by a Lande-type step: Δθ = gradient × variance × dt.
  - Climate is a monthly met file (AmzFACE 2000-2015). Soil water potential is read from the file as a forcing, not computed from a shared water balance.
  - Judgement: Plant-FATE is the closest existing combination of an inner physiological optimum, size-structured light competition, observed variable climate and gradient-driven trait evolution. Its gradients are finite-difference, cover 2 traits, and include no water competition.
- **PPA family.** Strigul et al. (2008), Purves et al. (2008), Purves & Pacala (2008), Adams, Purves & Pacala (2007), Weng et al. (2015, 2017), Lichstein et al. (2024). These are tractable height-structured models that admit ESS analysis, analytic or by trait-grid search.
- **Kohyama (1993)** proposed the forest-architecture hypothesis in size-structured gap models. **Pacala & Rees (1998)** studied the successional niche. **Detto, Levine & Pacala (2022)** studied high diversity in mechanistic light-competition models. **Detto & Pacala (2024)** [full via PMC] ran simulation-based evolution (speciation plus drift) of one or two traits with no climate variability. **Levine, Levine & Pacala (2025)** [abs] built an analytically tractable water-and-light competition model with storms. Diversity there is maintained by "phenological division of the time between storms".
- **Trait-flexible / evolving DGVMs.**
  - aDGVM2 (Scheiter, Langan & Higgins 2013) [abs] uses "a genetic optimization algorithm" for trait inheritance. Langan et al. (2025) [abs] used it to show that hydraulic-trait diversity increases Amazon drought resistance.
  - JeDi-DGVM (Pavlick et al. 2013) [abs] uses 15 trait parameters per randomly generated strategy, with environmental filtering.
  - LPJmL-FIT (Sakschewski et al. 2015 [abs], 2016; Billing et al. 2024) uses five traits with leaf-economics trade-offs. Individuals are sampled uniformly at establishment.
  - Devresse et al. (2025) added quantitative-genetic evolution to a gap model. Fririon et al. (2024) used a demo-genetic drought model.
  - Judgement: these models carry many traits and realistic climate. Selection in them is emergent (filtering, inheritance with variation), and none computes invasion fitness or its derivatives.
- **Numerical adaptive dynamics for PSPMs.** de Roos's PSPManalysis (2021) [bg] does equilibrium continuation, including evolutionary singular points, for physiologically structured models in constant environments. Fritsch, Campillo & Ovaskainen (2017) give a numerical approach to invasion fitness and singular strategies for structured models.

## 5. Differentiable and adjoint models in ecology, evolution and Earth-system science

**Adjoints in land-surface and carbon-cycle data assimilation.**

- CCDAS (Rayner et al. 2005; Scholze et al. 2007; Kaminski et al. 2013) differentiated the BETHY biosphere model by source transformation with TAF (Giering & Kaminski 1998). It uses adjoint and Hessian code to estimate 57 parameters and their posterior uncertainties [bg; the 57-parameter figure comes from a secondary description seen in this session].
- adJULES (Raoult et al. 2016) is an adjoint of JULES for parameter optimisation.
- Zhu & Zhuang (2013, 2014) built an adjoint of the Terrestrial Ecosystem Model for parameter estimation and sensitivity ranking.
- Fact: all of these differentiate fluxes or misfit functions with respect to parameters. None differentiates a fitness measure.

**Differentiable vegetation and land models (2023-2026).**

- Aboelyazeed et al. (2023): differentiable FATES photosynthesis with neural-network parameterisation.
- Jiang et al. (2025): JAX-CanVeg, a differentiable multilayer canopy land-surface model.
- Fang et al. (2026): DifferLand, a JAX differentiable terrestrial biosphere model (DALEC-type), learns environment-trait relationships.
- Givi, Travelletti & Mermoud (2026, arXiv): TrunX, a JAX 3-PG.
- Shen et al. (2023) and Gelbrecht et al. (2023) review differentiable modelling for geosciences and Earth-system models.
- Judgement: none of these is demographic (cohort / size-structured with competition for light and water) and none addresses evolution.

**AD in ecology and evolution.**

- TMB (Kristensen et al. 2016) is widely used for AD-based likelihood fitting.
- Frank (2022) [abs] explains AD of ODE trajectories for fitting and uses the adaptive-landscape analogy, but does not compute selection gradients.
- PiecewiseInference.jl (Boussange) does AD-based inference for ecological ODEs. I verified only conference abstracts.
- DiffBreed (Hamazaki, Iwata & Tsuda 2025) uses AD to optimise breeding strategies, which is artificial selection, not invasion fitness.

**Analytic adjoints in evolutionary theory.**

- Function-valued adaptive dynamics: Dieckmann, Heino & Parvinen (2006); Parvinen, Dieckmann & Heino (2006); Parvinen, Heino & Dieckmann (2013). Metz, Staňková & Johansson (2016) show that singular strategies satisfy Pontryagin's maximum principle with environmental feedback. The costate is the reproductive-value-like adjoint.
- Iwasa & Roughgarden (1984) used optimal control for plant allocation.
- Judgement: the theory therefore already treats selection gradients as adjoint calculations. What it has not done is apply them numerically, by reverse-mode AD, to a large mechanistic simulation.

**AD theory used by the claim.** Griewank & Walther (2008) and Griewank & Walther (2000; Revolve checkpointing) cover the general theory. Christianson (1994) covers adjoints of fixed-point iterations, the basis for implicit differentiation of an inner solve. Cao et al. (2003) cover adjoints of DAEs. Blondel et al. (2022) cover modular implicit differentiation. Errico (1997) introduces adjoint models.

**Sensitivity analysis of demographic vegetation models.** Massoud et al. (2019) ran a global variance-based sensitivity analysis of CLM4.5(FATES) parameters. Fisher et al. (2018) review vegetation demographics in Earth-system models. Fact: these analyse model outputs, not fitness of rare types, and use sampling rather than derivatives.

**Adjoint attribution to forcing in time.** Kauker et al. (2009) attributed the 2007 Arctic sea-ice minimum to forcing in particular months using an adjoint. Heimbach et al. (2011) mapped the timescales and regions of sensitivity of Atlantic transport to surface forcing. Judgement: this is the closest methodological analogue to attributing selection to particular droughts. I found no use of it in ecology or evolution.

**Differentiable games.** Balduzzi et al. (2018) analysed gradient dynamics in n-player differentiable games through the game Jacobian. Judgement: this parallels convergence-stability analysis but is not used in ecology.

## 6. Coexistence under variable climate in trait-based forest models

- **Coexistence theory.** Chesson (1994, 2000, 2018) classifies fluctuation-dependent mechanisms: the storage effect and relative nonlinearity. Ellner, Snyder & Adler (2016) and Ellner et al. (2019) quantify them by simulation. Snyder & Chesson (2003) treat the spatial analogues.
- **Forests.** Kelly & Bowler (2002) and Usinowicz et al. (2017) find empirical signatures of temporal coexistence (storage effect) in forest trees, the latter along the latitudinal gradient. Successional-niche coexistence is covered by Pacala & Rees (1998), Kohyama (1993), Adams et al. (2007), Falster et al. (2017) and Detto et al. (2022). Levine et al. (2022, 2024, 2025) cover coexistence through competition for water and "competition for time" between storms.
- **Eco-evolutionary versions.** Snyder & Adler (2011), Abrams et al. (2013), Kremer & Klausmeier (2013, 2017) and Miller & Klausmeier (2017).
- **Empirical selection and climate.** Siepielski et al. (2017) found that precipitation explains global variation in the strength and direction of natural selection. Franks, Sim & Weis (2007) documented rapid evolution of flowering time after a drought. Statistical methods for finding the climate windows that drive demographic or selection responses include climwin (van de Pol et al. 2016) and functional linear models (Teller et al. 2016).
- **What is missing.** Judgement: the forest coexistence models that resolve light competition mechanistically have no climate variability (Falster 2017, Detto 2022). The models with storms or rainfall (Farrior 2013/2015, Levine 2025) are analytically tractable simplifications with few traits. The storage-effect evolution literature uses annual-plant lottery-type models. None decomposes coexistence or selection into fluctuation-dependent and fluctuation-independent parts in a size-structured light-and-water model forced by real weather.

---

## 7. Novelty assessment

Caveat for every verdict: searches covered major journals, bioRxiv/arXiv, Crossref and web search up to 21 Oct 2026. Absence of evidence is not proof of absence. Conference abstracts (EGU) and unpublished code, such as traitecoevo's regnans harness and the Plant-FATE belowground work, may contain partial overlaps.

### (a) Full multi-trait selection gradients for a mechanistic forest model

- **Closest prior work:**
  - Plant-FATE (Joshi et al. 2023 preprint; code): 2 traits, one-sided finite differences, size-structured, monthly forcing.
  - Falster et al. (2017): 2 traits, invasion fitness from the SCM, constant disturbance regime.
  - Lichstein et al. (2024): 2-D trait-grid search in LM3-PPA/BiomeE.
  - Dybzinski et al. (2011) and Farrior et al. (2013): analytic ESS for 2-3 allocation fractions.
  - CCDAS (Rayner et al. 2005): adjoint gradients and Hessians with respect to ~57 parameters, but of fluxes, not fitness.
  - JeDi, aDGVM2 and LPJmL-FIT: 5-15 traits, selection by filtering or inheritance, no gradients.
- **Gap:**
  - Fact: no published study found computes the gradient of invasion fitness with respect to more than about 2-3 traits of a mechanistic forest model.
  - Judgement: computing ~50 at once, plus curvature, would be new. The cost argument is concrete: one-sided finite differences need n+1 runs per gradient (and n² for a Hessian), which is why Plant-FATE and Falster et al. stop at 2. Reverse mode gives the whole gradient for a small constant multiple of one run. The local measurement reports a 50-column gradient at roughly one sweep plus overhead.

### (b) Adaptive dynamics / ESS under realistic, daily-resolved variable climate

- **Closest prior work:**
  - Lichstein et al. (2024): competitive strategies under historical and scenario climates at 10 sites. Demographic ESM model, 2 traits.
  - Farrior et al. (2015): ESS allocation under stochastic rainfall with continuously varying soil moisture. Tractable model.
  - Lu et al. (2020) and Vico et al. (2017): stomatal or phenological ESS under stochastic rainfall statistics.
  - Plant-FATE: observed monthly climate 2000-2015, soil water prescribed.
  - Childs et al. (2004) and Rees & Ellner (2009): ESS in empirical stochastic IPMs.
  - Kremer & Klausmeier (2013, 2017): stylised seasonal fluctuations.
- **Gap.** Judgement: partially novel. ESS analyses under variable rainfall exist, but only in tractable models with stylised (Poisson or two-season) forcing, or by brute-force search in 2-D trait space. I found no analysis of singular strategies with full stability classification for a size-structured model in which plants compete dynamically for a shared soil-water store under multi-decadal daily rainfall records. The open methodological point is the definition of invasion fitness on a finite record. Metz et al. (1992) and Tuljapurkar (1990) define fitness as a long-run (ergodic) growth rate. A 40-year record gives one realisation, so averaging over records or seeds is required. The project's use of eight seeds to set ε matches what the theory asks for.

### (c) Reverse-mode AD / adjoints for selection gradients or invasion-fitness sensitivities

- **Closest prior work:**
  - Analytic costate / Pontryagin methods in function-valued adaptive dynamics (Parvinen et al. 2013; Metz et al. 2016).
  - Reproductive-value (left-eigenvector) sensitivity formulas in matrix demography (Caswell 2019; Tuljapurkar et al. 2003).
  - Adjoint parameter estimation in land models (CCDAS, adJULES, TEM-adjoint).
  - AD for artificial selection (DiffBreed 2025).
  - AD for ODE fitting with an evolutionary analogy (Frank 2022).
- **Gap.** Fact: I found no study that uses reverse-mode AD or a numerical adjoint to compute selection gradients or invasion-fitness derivatives from an ecological simulation. Judgement: novel as a computation. The concept is not new: reproductive value is the adjoint of the population state, and theory has used this since Fisher via Pontryagin. The contribution should be framed as making that adjoint available numerically through a mechanistic model, not as a new definition of selection.

### (d) Physiological optimality (inner optimisation) combined with evolutionary game analysis (outer ESS), differentiated through both

- **Closest prior work:**
  - Plant-FATE: P-hydro inner optimum inside a finite-difference outer gradient. This is the same bilevel structure without derivatives through either level.
  - Wolf et al. (2016) and Lu et al. (2020): stomatal optimisation shown to be or chosen as an ESS, analytically.
  - Lichstein et al. (2024): optimality versus competitive strategies compared by simulation.
  - Mäkelä et al. (1996): an optimal-control (costate) inner problem.
  - Implicit differentiation is standard in AD and ML (Christianson 1994; Blondel et al. 2022) but not used in vegetation models.
- **Gap.** Judgement: novel. I found no vegetation or eco-evolutionary model that differentiates through an inner physiological optimisation, by the implicit function theorem, to get outer evolutionary gradients. A consequence that should be stated:
  - The gradient includes the plastic response of the operating point to each trait (the envelope-theorem term vanishes only for the inner objective, not for fitness).
  - The derivative is defined only where the inner optimum is unique and non-degenerate.
  - Corner solutions (stomatal closure, hydraulic failure) are kinks where the derivative jumps.

### (e) Attribution of selection to specific times or climatic events via adjoint sensitivities to the environment trajectory

- **Closest prior work:**
  - Environment- or habitat-specific stochastic elasticities (Tuljapurkar et al. 2003; Haridas & Tuljapurkar 2005; Horvitz et al. 2005, which covers hurricanes).
  - Partitioning fluctuating selection in Carlina (Rees et al. 2004).
  - Statistical climate-window methods (van de Pol et al. 2016; Teller et al. 2016).
  - Simulation decompositions of the storage effect (Ellner et al. 2016).
  - Adjoint attribution to forcing in ocean and sea-ice models (Kauker et al. 2009; Heimbach et al. 2011).
  - Empirical evidence that precipitation drives selection (Siepielski et al. 2017; Franks et al. 2007).
- **Gap.** Judgement: novel for ecology. Mathematically, a reverse-mode gradient is an integral over time of the adjoint state times the explicit partial derivative of the dynamics in θ. That integrand is a time-resolved decomposition of the selection gradient, available at no extra cost. Contracting the adjoint of the recorded field (light, soil water) with a perturbation of the field gives sensitivity to the environment trajectory. The local `field-adjoint-map` measurement shows this works numerically.
- **Caveats to state:**
  - The decomposition says where sensitivity enters, not what caused it. State carries memory, so a drought's effect can enter through later growth.
  - For invaders the field is a fixed input. Attributing the resident's selection to rainfall events requires differentiating the residents' run with respect to rainfall, which is a separate pass.
  - The decomposition is linear, so it describes small perturbations of an event, not removing it.

---

## 8. Open questions in the literature that this machinery could answer

1. **Are multidimensional singular strategies in a mechanistic model convergence stable, and robustly so?** Leimar (2009) and Débarre et al. (2014) predict that stability becomes rarer with dimension, and that strong (M-independent) convergence stability is the relevant criterion. The full Jacobian of the selection gradient at a singular point of TF24 tests this directly: check whether its symmetric part is negative definite. No mechanistic test exists.
2. **How many directions of disruptive selection does a realistic plant have?** Doebeli & Ispolatov (2017) and Svardal et al. (2014) predict that diversification potential rises with trait number. The number of positive eigenvalues of the invader Hessian at a singular point counts branching directions. The eigenvectors say which trait combinations they involve.
3. **When does optimality agree with the ESS, and how far apart are they?** Franklin et al. (2020), Harrison et al. (2021) and Lichstein et al. (2024) flag this as unresolved for EEO in land models. The difference between the gradient of monoculture performance (resident stand J, productivity or biomass) and the invasion selection gradient, across all traits, gives the "competitive over-investment" vector that Lichstein et al. measured in 2-D, now in 50-D.
4. **Is "evolved near-neutrality" a low-curvature subspace?** Falster et al. (2017) reported emergent near-neutral regions in 2-D. Near-zero eigenvalues of the Hessian identify near-neutral trait directions in the full space and say whether they persist under variable climate.
5. **Does rainfall variability create or destroy branching in a size-structured model?** The storage-effect evolution literature (Snyder & Adler 2011; Abrams et al. 2013; Miller & Klausmeier 2017; Kremer & Klausmeier 2013, 2017) gives contrasting answers in simple models. Levine et al. (2025) show storm-interval partitioning maintains diversity analytically. Comparing singular points and their Hessians across constant, seasonal, episodic and drought records with the same mean rainfall would test whether variability adds disruptive directions.
6. **Which droughts drive selection on which traits?** Siepielski et al. (2017) show that precipitation drives selection in the wild, but the mechanism is not identified. The time-resolved gradient integrand can show whether selection on, for example, hydraulic traits is concentrated in rare multi-year droughts or spread across ordinary dry seasons. That bears on bet-hedging (Childs et al. 2010) and on fluctuating selection.
7. **How variable is the selection gradient across realisations of one climate?** This is the stochastic-fitness question of Tuljapurkar (1990) and Metz et al. (1992) for a finite record. The across-seed spread of gradients, the basis of ε here, measures fluctuating selection between records and says whether the sign of selection on a trait is robust.
8. **Benchmarking selection-gradient estimators.** Lande-Arnold regression on observational data suffers from collinearity and omitted traits (Mitchell-Olds & Shaw 1987). A model with known exact β and γ over 50 correlated traits would let one test how regressions on a few measured traits mis-estimate selection. This holds only if the model is accepted as a test bed, not as truth.

---

## 9. Annotated reference list

Format: Authors (year). Title. *Venue* volume: pages. DOI or URL. [verification] Annotation.

### 9.1 Multi-trait selection and adaptive dynamics

- Lande, R. (1979). Quantitative genetic analysis of multivariate evolution, applied to brain:body size allometry. *Evolution* 33: 402-416. https://doi.org/10.1111/j.1558-5646.1979.tb04694.x [DOI✓, bg] The multivariate response Δz̄ = Gβ.
- Lande, R. & Arnold, S.J. (1983). The measurement of selection on correlated characters. *Evolution* 37: 1210-1226. https://doi.org/10.1111/j.1558-5646.1983.tb00236.x [DOI✓, bg] Regression estimates of β and γ.
- Mitchell-Olds, T. & Shaw, R.G. (1987). Regression analysis of natural selection: statistical inference and biological interpretation. *Evolution* 41: 1149-1161. https://doi.org/10.1111/j.1558-5646.1987.tb02457.x [DOI✓, bg] Collinearity and unmeasured traits.
- Kingsolver, J.G. et al. (2001). The strength of phenotypic selection in natural populations. *American Naturalist* 157: 245-261. https://doi.org/10.1086/319193 [DOI✓, bg] Meta-analysis of field gradients.
- Svensson, E.I. (2023). Phenotypic selection in natural populations: what have we learned in 40 years? *Evolution* 77: 1493-1504. https://doi.org/10.1093/evolut/qpad077 [DOI✓, bg] Recent synthesis.
- Walsh, B. & Blows, M.W. (2009). Abundant genetic variation + strong selection = multivariate genetic constraints. *Annu. Rev. Ecol. Evol. Syst.* 40: 41-59. https://doi.org/10.1146/annurev.ecolsys.110308.120232 [DOI✓, bg] Alignment of β with G.
- Kirkpatrick, M. (2009). Patterns of quantitative genetic variation in multiple dimensions. *Genetica* 136: 271-284. https://doi.org/10.1007/s10709-008-9302-6 [DOI✓, bg] Low effective dimensionality of G.
- Metz, J.A.J., Nisbet, R.M. & Geritz, S.A.H. (1992). How should we define 'fitness' for general ecological scenarios? *Trends Ecol. Evol.* 7: 198-202. https://doi.org/10.1016/0169-5347(92)90073-K [DOI✓, bg] Invasion fitness as a Lyapunov exponent.
- Dieckmann, U. & Law, R. (1996). The dynamical theory of coevolution: a derivation from stochastic ecological processes. *J. Math. Biol.* 34: 579-612. https://doi.org/10.1007/BF02409751 [DOI✓, abs] The canonical equation, multi-trait.
- Geritz, S.A.H., Kisdi, É., Meszéna, G. & Metz, J.A.J. (1998). Evolutionarily singular strategies and the adaptive growth and branching of the evolutionary tree. *Evol. Ecol.* 12: 35-57. https://doi.org/10.1023/A:1006554906681 [DOI✓, bg] One-dimensional classification of singular points.
- Durinx, M., Metz, J.A.J. & Meszéna, G. (2008; online 2007). Adaptive dynamics for physiologically structured population models. *J. Math. Biol.* 56: 673-742. https://doi.org/10.1007/s00285-007-0134-2 [DOI✓, bg] Canonical equation for PSPMs.
- Brännström, Å., Johansson, J. & von Festenberg, N. (2013). The hitchhiker's guide to adaptive dynamics. *Games* 4: 304-328. https://doi.org/10.3390/g4030304 [DOI✓, bg] Tutorial.
- Leimar, O. (2009). Multidimensional convergence stability. *Evolutionary Ecology Research* 11: 191-208. https://www.evolutionary-ecology.com/abstracts/v11/2433.html [page✓ via indexed abstract and citing papers; journal page returned HTTP 525 on direct fetch; no DOI] Strong and absolute convergence stability; most multidimensional equilibria are not robustly stable.
- Débarre, F., Nuismer, S.L. & Doebeli, M. (2014). Multidimensional (co)evolutionary stability. *American Naturalist* 184: 158-171. https://doi.org/10.1086/677137 [DOI✓, abs] Dimension destabilises equilibria.
- Ito, H.C. & Sasaki, A. (2016). Evolutionary branching under multi-dimensional evolutionary constraints. *J. Theor. Biol.* 407: 409-428. https://doi.org/10.1016/j.jtbi.2016.07.011 [DOI✓, bg]
- Ito, H.C. & Sasaki, A. (2025). Evolutionary branching points in multi-dimensional trait spaces. bioRxiv. https://doi.org/10.1101/2025.10.20.683593 [DOI✓; preprint; content not read]
- Vukics, A., Asbóth, J. & Meszéna, G. (2003). Speciation in multidimensional evolutionary space. *Phys. Rev. E* 68: 041903. https://doi.org/10.1103/PhysRevE.68.041903 [DOI✓, bg]
- Doebeli, M. & Ispolatov, I. (2017). Diversity and coevolutionary dynamics in high-dimensional phenotype spaces. *American Naturalist* 189: 105-120. https://doi.org/10.1086/689891 [DOI✓, abs] Saturating diversity grows with dimension.
- Svardal, H., Rueffler, C. & Doebeli, M. (2014). Organismal complexity and the potential for evolutionary diversification. *Evolution* 68: 3248-3259. https://doi.org/10.1111/evo.12492 [DOI✓, bg]
- Gavrilets, S. (2004). *Fitness Landscapes and the Origin of Species.* Princeton University Press. https://doi.org/10.1515/9780691187051 [DOI✓, bg] Holey landscapes. See also Gavrilets (1997) *TREE* 12: 307-312, https://doi.org/10.1016/S0169-5347(97)01098-7 [DOI✓].
- Rueffler, C., Van Dooren, T.J.M., Leimar, O. & Abrams, P.A. (2006). Disruptive selection and then what? *Trends Ecol. Evol.* 21: 238-245. https://doi.org/10.1016/j.tree.2006.03.003 [DOI✓, bg]

### 9.2 Fluctuating environments, bet-hedging, stochastic demography

- Tuljapurkar, S. (1990). *Population Dynamics in Variable Environments.* Lecture Notes in Biomathematics 85. Springer. https://doi.org/10.1007/978-3-642-51652-8 [DOI✓, bg]
- Rand, D.A., Wilson, H.B. & McGlade, J.M. (1994). Dynamics and evolution: evolutionarily stable attractors, invasion exponents and phenotype dynamics. *Phil. Trans. R. Soc. B* 343: 261-283. https://doi.org/10.1098/rstb.1994.0025 [DOI✓, bg]
- Ferrière, R. & Gatto, M. (1995). Lyapunov exponents and the mathematics of invasion in oscillatory or chaotic populations. *Theor. Popul. Biol.* 48: 126-171. https://doi.org/10.1006/tpbi.1995.1024 [DOI✓, bg]
- Schreiber, S.J., Benaïm, M. & Atchadé, K.A.S. (2011; online 2010). Persistence in fluctuating environments. *J. Math. Biol.* 62: 655-683. https://doi.org/10.1007/s00285-010-0349-5 [DOI✓, bg]
- Tuljapurkar, S., Horvitz, C.C. & Pascarella, J.B. (2003). The many growth rates and elasticities of populations in random environments. *American Naturalist* 162: 489-502. https://doi.org/10.1086/378648 [DOI✓, abs] Stochastic elasticities to means and variances.
- Haridas, C.V. & Tuljapurkar, S. (2005). Elasticities in variable environments: properties and implications. *American Naturalist* 166: 481-495. https://doi.org/10.1086/444444 [DOI✓, bg]
- Horvitz, C.C., Tuljapurkar, S. & Pascarella, J.B. (2005). Plant-animal interactions in random environments: habitat-stage elasticity, seed predators, and hurricanes. *Ecology* 86: 3312-3322. https://doi.org/10.1890/04-1187 [DOI✓, bg] Sensitivity attributed to environmental states.
- Caswell, H. (2019). *Sensitivity Analysis: Matrix Methods in Demography and Ecology.* Springer (open access). https://doi.org/10.1007/978-3-030-10534-1 [DOI✓, bg]
- Cohen, D. (1966). Optimizing reproduction in a randomly varying environment. *J. Theor. Biol.* 12: 119-129. https://doi.org/10.1016/0022-5193(66)90188-3 [DOI✓, bg]
- Slatkin, M. (1974). Hedging one's evolutionary bets. *Nature* 250: 704-705. https://doi.org/10.1038/250704b0 [DOI✓, bg]
- Philippi, T. & Seger, J. (1989). Hedging one's evolutionary bets, revisited. *Trends Ecol. Evol.* 4: 41-44. https://doi.org/10.1016/0169-5347(89)90138-9 [DOI✓, bg]
- Childs, D.Z., Metcalf, C.J.E. & Rees, M. (2010). Evolutionary bet-hedging in the real world: empirical evidence and challenges revealed by plants. *Proc. R. Soc. B* 277: 3055-3064. https://doi.org/10.1098/rspb.2010.0707 [DOI✓, bg]
- Sasaki, A. & Ellner, S. (1995). The evolutionarily stable phenotype distribution in a random environment. *Evolution* 49: 337-350. https://doi.org/10.1111/j.1558-5646.1995.tb02246.x [DOI✓, bg]
- Childs, D.Z., Rees, M., Rose, K.E., Grubb, P.J. & Ellner, S.P. (2004). Evolution of size-dependent flowering in a variable environment: construction and analysis of a stochastic integral projection model. *Proc. R. Soc. B* 271: 425-434. https://doi.org/10.1098/rspb.2003.2597 [DOI✓, bg]
- Rees, M., Childs, D.Z., Rose, K.E. & Grubb, P.J. (2004). Evolution of size-dependent flowering in a variable environment: partitioning the effects of fluctuating selection. *Proc. R. Soc. B* 271: 471-475. https://doi.org/10.1098/rspb.2003.2596 [DOI✓, bg] The closest precedent for attributing selection to environmental variation in a size-structured plant model.
- Metcalf, C.J.E. et al. (2008). Evolution of flowering decisions in a stochastic, density-dependent environment. *PNAS* 105: 10466-10470. https://doi.org/10.1073/pnas.0800777105 [DOI✓, bg]
- Rees, M. & Ellner, S.P. (2009). Integral projection models for populations in temporally varying environments. *Ecol. Monogr.* 79: 575-594. https://doi.org/10.1890/08-1474.1 [DOI✓, bg]
- Snyder, R.E. & Adler, P.B. (2011). Coexistence and coevolution in fluctuating environments: can the storage effect evolve? *American Naturalist* 178: E76-E84. https://doi.org/10.1086/661905 [DOI✓, abs]
- Abrams, P.A., Tucker, C.M. & Gilbert, B. (2013; online 2012). Evolution of the storage effect. *Evolution* 67: 315-327. https://doi.org/10.1111/j.1558-5646.2012.01756.x [DOI✓, bg]
- Miller, E.T. & Klausmeier, C.A. (2017; online 2016). Evolutionary stability of coexistence due to the storage effect in a two-season model. *Theor. Ecol.* 10: 91-103. https://doi.org/10.1007/s12080-016-0314-z [DOI✓, bg]
- Kremer, C.T. & Klausmeier, C.A. (2013). Coexistence in a variable environment: eco-evolutionary perspectives. *J. Theor. Biol.* 339: 14-25. https://doi.org/10.1016/j.jtbi.2013.05.005 [DOI✓, abs]
- Kremer, C.T. & Klausmeier, C.A. (2017). Species packing in eco-evolutionary models of seasonally fluctuating environments. *Ecology Letters* 20: 1158-1168. https://doi.org/10.1111/ele.12813 [DOI✓, abs]
- Yamamichi, M., Letten, A.D. & Schreiber, S.J. (2023). Eco-evolutionary maintenance of diversity in fluctuating environments. *Ecology Letters* 26 (S1). https://doi.org/10.1111/ele.14286 [DOI✓; content not read]
- Grunert, K., Holden, H., Jakobsen, E.R. & Stenseth, N.C. (2021). Evolutionarily stable strategies in stable and periodically fluctuating populations: the Rosenzweig-MacArthur predator-prey model. *PNAS* 118: e2017463118. https://doi.org/10.1073/pnas.2017463118 [DOI✓]. Reply: Best, A. & Ashby, B. (2021). *PNAS* 118: e2102001118. https://doi.org/10.1073/pnas.2102001118 [DOI✓]
- Sun, Z., Parvinen, K., Heino, M., Metz, J.A.J., de Roos, A.M. & Dieckmann, U. (2020). Evolution of reproduction periods in seasonal environments. *American Naturalist* 196: E88-E109. https://doi.org/10.1086/708274 [DOI✓; content not read]
- Metz, J.A.J., Mylius, S.D. & Diekmann, O. (2008). When does evolution optimize? *Evolutionary Ecology Research* 10: 629-654. https://pure.iiasa.ac.at/8558 [page✓; no DOI] An optimisation principle exists only for simple feedback structures.

### 9.3 Eco-evolutionary optimality, stomatal optimisation, plant games

- Franklin, O. et al. (2020). Organizing principles for vegetation dynamics. *Nature Plants* 6: 444-453. https://doi.org/10.1038/s41477-020-0655-x [DOI✓, abs]
- Harrison, S.P. et al. (2021). Eco-evolutionary optimality as a means to improve vegetation and land-surface models. *New Phytologist* 231: 2125-2141. https://doi.org/10.1111/nph.17558 [DOI✓, abs]
- Wang, H. et al. (2017). Towards a universal model for carbon dioxide uptake by plants. *Nature Plants* 3: 734-741. https://doi.org/10.1038/s41477-017-0006-8 [DOI✓, bg]
- Stocker, B.D. et al. (2020). P-model v1.0: an optimality-based light use efficiency model for simulating ecosystem gross primary production. *Geosci. Model Dev.* 13: 1545-1581. https://doi.org/10.5194/gmd-13-1545-2020 [DOI✓, bg]
- Prentice, I.C., Dong, N., Gleason, S.M., Maire, V. & Wright, I.J. (2014; online 2013). Balancing the costs of carbon gain and water transport. *Ecology Letters* 17: 82-91. https://doi.org/10.1111/ele.12211 [DOI✓, bg]
- Joshi, J. et al. (2022). Towards a unified theory of plant photosynthesis and hydraulics. *Nature Plants* 8: 1304-1316. https://doi.org/10.1038/s41477-022-01244-5 [DOI✓, abs] P-hydro.
- Rogger, J. et al. (2026). TREED (v1.0): a trait- and optimality-based eco-evolutionary vegetation model for the deep past and the present. *Geosci. Model Dev.* 19: 4931-4960. https://doi.org/10.5194/gmd-19-4931-2026 [DOI✓; content not read]
- Cowan, I.R. & Farquhar, G.D. (1977). Stomatal function in relation to leaf metabolism and environment. *Symp. Soc. Exp. Biol.* 31: 471-505. [page✓ via secondary bibliographic records; no DOI]
- Mäkelä, A., Berninger, F. & Hari, P. (1996). Optimal control of gas exchange during drought: theoretical analysis. *Annals of Botany* 77: 461-468. https://doi.org/10.1006/anbo.1996.0056 [DOI✓, bg] Costate formulation.
- Sperry, J.S. et al. (2017; online 2016). Predicting stomatal responses to the environment from the optimization of photosynthetic gain and hydraulic cost. *Plant Cell Environ.* 40: 816-830. https://doi.org/10.1111/pce.12852 [DOI✓, bg]
- Venturas, M.D. et al. (2018). A stomatal control model based on optimization of carbon gain versus hydraulic risk predicts aspen sapling responses to drought. *New Phytologist* 220: 836-850. https://doi.org/10.1111/nph.15333 [DOI✓, bg]
- Wolf, A., Anderegg, W.R.L. & Pacala, S.W. (2016). Optimal stomatal behavior with competition for water and risk of hydraulic impairment. *PNAS* 113: E7222-E7230. https://doi.org/10.1073/pnas.1615144113 [DOI✓, abs] Carbon maximisation is an ESS under water competition.
- Anderegg, W.R.L. et al. (2018). Woody plants optimise stomatal behaviour relative to hydraulic risk. *Ecology Letters* 21: 968-977. https://doi.org/10.1111/ele.12962 [DOI✓, bg]
- Eller, C.B. et al. (2018). Modelling tropical forest responses to drought and El Niño with a stomatal optimization model based on xylem hydraulics. *Phil. Trans. R. Soc. B* 373: 20170315. https://doi.org/10.1098/rstb.2017.0315 [DOI✓, bg]. Eller, C.B. et al. (2020). SOX improves land surface model simulation. *New Phytologist* 226: 1622-1637. https://doi.org/10.1111/nph.16419 [DOI✓, bg]
- Sabot, M.E.B. et al. (2020). Plant profit maximization improves predictions of European forest responses to drought. *New Phytologist* 226: 1638-1655. https://doi.org/10.1111/nph.16376 [DOI✓, bg]
- Lu, Y., Duursma, R.A. & Medlyn, B.E. (2016). Optimal stomatal behaviour under stochastic rainfall. *J. Theor. Biol.* 394: 160-171. https://doi.org/10.1016/j.jtbi.2016.01.003 [DOI✓, bg]
- Lu, Y., Duursma, R.A., Farrior, C.E., Medlyn, B.E. & Feng, X. (2020; online 2019). Optimal stomatal drought response shaped by competition for water and hydraulic risk can explain plant trait covariation. *New Phytologist* 225: 1206-1217. https://doi.org/10.1111/nph.16207 [DOI✓, abs]
- Manzoni, S., Vico, G., Katul, G., Palmroth, S. & Porporato, A. (2014). Optimal plant water-use strategies under stochastic rainfall. *Water Resour. Res.* 50: 5379-5394. https://doi.org/10.1002/2014WR015375 [DOI✓, bg]
- Vico, G., Dralle, D., Feng, X., Thompson, S. & Manzoni, S. (2017). How competitive is drought deciduousness in tropical forests? A combined eco-hydrological and eco-evolutionary approach. *Environ. Res. Lett.* 12: 065006. https://doi.org/10.1088/1748-9326/aa6f1b [DOI✓, bg]
- Givnish, T.J. (1982). On the adaptive significance of leaf height in forest herbs. *American Naturalist* 120: 353-381. https://doi.org/10.1086/283995 [DOI✓, bg]
- Iwasa, Y., Cohen, D. & León, J.A. (1985). Tree height and crown shape, as results of competitive games. *J. Theor. Biol.* 112: 279-297. https://doi.org/10.1016/S0022-5193(85)80288-5 [DOI✓, bg]
- Iwasa, Y. & Roughgarden, J. (1984). Shoot/root balance of plants: optimal growth of a system with many vegetative organs. *Theor. Popul. Biol.* 25: 78-105. https://doi.org/10.1016/0040-5809(84)90007-8 [DOI✓, bg] Optimal control with costates.
- Falster, D.S. & Westoby, M. (2003). Plant height and evolutionary games. *Trends Ecol. Evol.* 18: 337-343. https://doi.org/10.1016/S0169-5347(03)00061-2 [DOI✓, bg]
- Dybzinski, R., Farrior, C., Wolf, A., Reich, P.B. & Pacala, S.W. (2011). Evolutionarily stable strategy carbon allocation to foliage, wood, and fine roots in trees competing for light and nitrogen. *American Naturalist* 177: 153-166. https://doi.org/10.1086/657992 [DOI✓, abs]
- Farrior, C.E., Dybzinski, R., Levin, S.A. & Pacala, S.W. (2013). Competition for water and light in closed-canopy forests: a tractable model of carbon allocation with implications for carbon sinks. *American Naturalist* 181: 314-330. https://doi.org/10.1086/669153 [DOI✓, abs]
- Farrior, C.E., Rodriguez-Iturbe, I., Dybzinski, R., Levin, S.A. & Pacala, S.W. (2015). Decreased water limitation under elevated CO2 amplifies potential for forest carbon sink. *PNAS* 112: 7213-7218. https://doi.org/10.1073/pnas.1506262112 [DOI✓, abs] Game-theoretic allocation in a continuously varying soil-moisture environment.
- Dybzinski, R., Farrior, C.E. & Pacala, S.W. (2015). Increased forest carbon storage with increased atmospheric CO2 despite nitrogen limitation: a game-theoretic allocation model for trees in competition for nitrogen and light. *Global Change Biol.* 21: 1182-1196. https://doi.org/10.1111/gcb.12783 [DOI✓, bg]
- Weng, E., Dybzinski, R., Farrior, C.E. & Pacala, S.W. (2019). Competition alters predicted forest carbon cycle responses to nitrogen availability and elevated CO2. *Biogeosciences* 16: 4577-4599. https://doi.org/10.5194/bg-16-4577-2019 [DOI✓, bg]
- Lichstein, J.W. et al. (2024). Effects of water limitation and competition on tree carbon allocation in an Earth system modelling framework. *J. Ecol.* 112: 2522-2539. https://doi.org/10.1111/1365-2745.14416 [DOI✓, abs] Competitive versus maximising strategies in 2-D trait space under climate scenarios. Closest to (b) in a demographic ESM model.
- McNickle, G.G. & Dybzinski, R. (2013). Game theory and plant ecology. *Ecology Letters* 16: 545-555. https://doi.org/10.1111/ele.12071 [DOI✓, abs]
- Gersani, M., Brown, J.S., O'Brien, E.E., Maina, G.M. & Abramsky, Z. (2001). Tragedy of the commons as a result of root competition. *J. Ecol.* 89: 660-669. https://doi.org/10.1046/j.0022-0477.2001.00609.x [DOI✓, bg]
- Zea-Cabrera, E., Iwasa, Y., Levin, S. & Rodríguez-Iturbe, I. (2006). Tragedy of the commons in plant water use. *Water Resour. Res.* 42: W06D02. https://doi.org/10.1029/2005WR004514 [DOI✓, bg]

### 9.4 Size-structured forest models and trait evolution

- Falster, D.S., Brännström, Å., Dieckmann, U. & Westoby, M. (2011; online 2010). Influence of four major plant traits on average height, leaf-area cover, net primary productivity, and biomass density in single-species forests. *J. Ecol.* 99: 148-164. https://doi.org/10.1111/j.1365-2745.2010.01735.x [DOI✓, bg]
- Falster, D.S., FitzJohn, R.G., Brännström, Å., Dieckmann, U. & Westoby, M. (2016). plant: a package for modelling forest trait ecology and evolution. *Methods Ecol. Evol.* 7: 136-146. https://doi.org/10.1111/2041-210X.12525 [DOI✓, bg]
- Falster, D.S., Brännström, Å., Westoby, M. & Dieckmann, U. (2017). Multitrait successional forest dynamics enable diverse competitive coexistence. *PNAS* 114: E2719-E2728. https://doi.org/10.1073/pnas.1610206114 [DOI✓, full via PMC5380092] 2 traits, fixed disturbance regime, no climate variability.
- Falster, D.S., Duursma, R.A. & FitzJohn, R.G. (2018). How functional traits influence plant growth and shade tolerance across the life cycle. *PNAS* 115: E6789-E6798. https://doi.org/10.1073/pnas.1714044115 [DOI✓, bg]
- Falster, D.S., Kunstler, G., FitzJohn, R.G. & Westoby, M. (2021). Emergent shapes of trait-based competition functions from resource-based models: a Gaussian is not normal in plant communities. *American Naturalist* 198: 253-267. https://doi.org/10.1086/714868 [DOI✓, bg]
- de Roos, A.M. (1988). Numerical methods for structured population models: the escalator boxcar train. *Numer. Methods Partial Differ. Equ.* 4: 173-195. https://doi.org/10.1002/num.1690040303 [DOI✓, bg]
- Brännström, Å., Carlsson, L. & Simpson, D. (2013). On the convergence of the escalator boxcar train. *SIAM J. Numer. Anal.* 51: 3213-3231. https://doi.org/10.1137/120893215 [DOI✓, bg]
- de Roos, A.M. (2021; online 2020). PSPManalysis: steady-state and bifurcation analysis of physiologically structured population models. *Methods Ecol. Evol.* 12: 383-390. https://doi.org/10.1111/2041-210X.13527 [DOI✓, bg] Equilibrium-only, evolutionary singular points by continuation.
- Fritsch, C., Campillo, F. & Ovaskainen, O. (2017). A numerical approach to determine mutant invasion fitness and evolutionary singular strategies. *Theor. Popul. Biol.* 115: 89-99. https://doi.org/10.1016/j.tpb.2017.05.001 [DOI✓, abs via arXiv]
- Joshi, J., Hofhansl, F., Singh, S., Stocker, B.D., Brännström, Å., Franklin, O., ... Prentice, I.C. & Dieckmann, U. (2023). Competition for light can drive adverse species-composition shifts in the Amazon Forest under elevated CO2. bioRxiv. https://doi.org/10.1101/2023.07.03.547575 [DOI✓, abs via Crossref; no published version linked in Crossref metadata] Plant-FATE.
- Plant-FATE source code, branch `feature_evolution`. https://github.com/jaideep777/Plant-FATE [full: inspected `src/trait_evolution.tpp`, `src/plant.cpp`, `src/climate.cpp`, `tests/params/p.ini` on 21 Oct 2026] Evolves LMA and wood density. Forward finite difference fg_dx = 0.001 with probe species. Monthly met file with prescribed soil water potential.
- Strigul, N., Pristinski, D., Purves, D., Dushoff, J. & Pacala, S. (2008). Scaling from trees to forests: tractable macroscopic equations for forest dynamics. *Ecol. Monogr.* 78: 523-545. https://doi.org/10.1890/08-0082.1 [DOI✓, bg]
- Purves, D.W., Lichstein, J.W., Strigul, N. & Pacala, S.W. (2008). Predicting and understanding forest dynamics using a simple tractable model. *PNAS* 105: 17018-17022. https://doi.org/10.1073/pnas.0807754105 [DOI✓, bg]
- Purves, D. & Pacala, S. (2008). Predictive models of forest dynamics. *Science* 320: 1452-1453. https://doi.org/10.1126/science.1155359 [DOI✓, bg]
- Adams, T.P., Purves, D.W. & Pacala, S.W. (2007). Understanding height-structured competition in forests: is there an R* for light? *Proc. R. Soc. B* 274: 3039-3048. https://doi.org/10.1098/rspb.2007.0891 [DOI✓, bg]
- Weng, E.S. et al. (2015). Scaling from individual trees to forests in an Earth system modeling framework using a mathematically tractable model of height-structured competition. *Biogeosciences* 12: 2655-2694. https://doi.org/10.5194/bg-12-2655-2015 [DOI✓, bg]
- Weng, E., Farrior, C.E., Dybzinski, R. & Pacala, S.W. (2017; online 2016). Predicting vegetation type through physiological and environmental interactions with leaf traits. *Global Change Biol.* 23: 2482-2498. https://doi.org/10.1111/gcb.13542 [DOI✓, bg]
- Kohyama, T. (1993). Size-structured tree populations in gap-dynamic forest: the forest architecture hypothesis for the stable coexistence of species. *J. Ecol.* 81: 131-143. https://doi.org/10.2307/2261230 [DOI✓, bg]
- Pacala, S.W. & Rees, M. (1998). Models suggesting field experiments to test two hypotheses explaining successional diversity. *American Naturalist* 152: 729-737. https://doi.org/10.1086/286203 [DOI✓, bg]
- Detto, M., Levine, J.M. & Pacala, S.W. (2022). Maintenance of high diversity in mechanistic forest dynamics models of competition for light. *Ecol. Monogr.* 92: e1500. https://doi.org/10.1002/ecm.1500 [DOI✓, bg]
- Detto, M. & Pacala, S.W. (2024). Integrating conspecifics negative density dependence, successional and evolutionary dynamics: towards a theory of forest diversity. *Commun. Biol.* 7: 1572. https://doi.org/10.1038/s42003-024-07156-8 [page✓ via PMC11599592; full] One or two traits, simulated speciation and drift, no climate variability.
- Levine, J.I., Levine, J.M., Gibbs, T. & Pacala, S.W. (2022). Competition for water and species coexistence in phenologically structured annual plant communities. *Ecology Letters* 25: 1110-1125. https://doi.org/10.1111/ele.13990 [DOI✓, bg]
- Levine, J.I., Pacala, S.W. & Levine, J.M. (2024). Competition for time: evidence for an overlooked, diversity-maintaining competitive mechanism. *Ecology Letters* 27: e14422. https://doi.org/10.1111/ele.14422 [DOI✓, abs via search summary]
- Levine, J.I., Levine, J.M. & Pacala, S.W. (2025). Trait diversity in plant communities maintained by competition for water and light. *Ecol. Monogr.* 95: e70012. https://doi.org/10.1002/ecm.70012 [DOI✓, abs]
- Scheiter, S., Langan, L. & Higgins, S.I. (2013). Next-generation dynamic global vegetation models: learning from community ecology. *New Phytologist* 198: 957-969. https://doi.org/10.1111/nph.12210 [DOI✓, abs] aDGVM2 uses a genetic optimisation algorithm.
- Langan, L., Scheiter, S., Hickler, T. & Higgins, S.I. (2025). Amazon forest resistance to drought is increased by diversity in hydraulic traits. *Nature Communications* 16: 8246. https://doi.org/10.1038/s41467-025-63600-1 [DOI✓, abs]
- Pavlick, R., Drewry, D.T., Bohn, K., Reu, B. & Kleidon, A. (2013). The Jena Diversity-Dynamic Global Vegetation Model (JeDi-DGVM). *Biogeosciences* 10: 4137-4177. https://doi.org/10.5194/bg-10-4137-2013 [DOI✓, abs] 15 trait parameters per random strategy, filtering.
- Sakschewski, B. et al. (2015). Leaf and stem economics spectra drive diversity of functional plant traits in a dynamic global vegetation model. *Global Change Biol.* 21: 2711-2725. https://doi.org/10.1111/gcb.12870 [DOI✓, abs] LPJmL-FIT, 5 traits.
- Sakschewski, B. et al. (2016). Resilience of Amazon forests emerges from plant trait diversity. *Nature Climate Change* 6: 1032-1036. https://doi.org/10.1038/nclimate3109 [DOI✓, bg]
- Billing, M. et al. (2024). 'How to adapt forests?' Exploring the role of leaf trait diversity for long-term forest biomass under new climate normals. *Global Change Biol.* 30: e17258. https://doi.org/10.1111/gcb.17258 [DOI✓; content not read]
- Devresse, E. et al. (2025). Evolutionary rescue in a mixed beech-fir forest: insights from a quantitative-genetics approach in a process-based model. *Oikos* e11661. https://doi.org/10.1002/oik.11661 [DOI✓, abs via search summary]
- Fririon, V. et al. (2024). Can thinning foster forest genetic adaptation to drought? A demo-genetic modelling approach with disturbance regimes. *Evol. Appl.* 17: e70051. https://doi.org/10.1111/eva.70051 [DOI✓, abs via search summary]
- Fisher, R.A. et al. (2018; online 2017). Vegetation demographics in Earth System Models: a review of progress and priorities. *Global Change Biol.* 24: 35-54. https://doi.org/10.1111/gcb.13910 [DOI✓, bg]
- TF24 itself: no peer-reviewed or preprint description found. The plant README describes it as on `develop`, to be documented in an upcoming release. A citation in the TF24 source, "Stefaniak et al. 2026 (plantNSC)", could not be found [UNVERIFIED].

### 9.5 Adjoints, AD and differentiable models

- Errico, R.M. (1997). What is an adjoint model? *Bull. Amer. Meteor. Soc.* 78: 2577-2591. https://doi.org/10.1175/1520-0477(1997)078<2577:WIAAM>2.0.CO;2 [DOI✓, bg]
- Griewank, A. & Walther, A. (2008). *Evaluating Derivatives: Principles and Techniques of Algorithmic Differentiation*, 2nd ed. SIAM. https://doi.org/10.1137/1.9780898717761 [DOI✓, bg] Chapter 15 covers implicit and iterative differentiation.
- Griewank, A. & Walther, A. (2000). Algorithm 799: revolve. *ACM TOMS* 26: 19-45. https://doi.org/10.1145/347837.347846 [DOI✓, bg] Checkpointing.
- Christianson, B. (1994). Reverse accumulation and attractive fixed points. *Optim. Methods Softw.* 3: 311-326. https://doi.org/10.1080/10556789408805572 [DOI✓, bg]
- Cao, Y., Li, S., Petzold, L. & Serban, R. (2003). Adjoint sensitivity analysis for differential-algebraic equations. *SIAM J. Sci. Comput.* 24: 1076-1089. https://doi.org/10.1137/S1064827501380630 [DOI✓, bg]
- Blondel, M. et al. (2022). Efficient and modular implicit differentiation. *Advances in Neural Information Processing Systems* 35: 5230-5242. https://doi.org/10.52202/068431-0378 [DOI✓, bg]
- Giering, R. & Kaminski, T. (1998). Recipes for adjoint code construction. *ACM TOMS* 24: 437-474. https://doi.org/10.1145/293686.293695 [DOI✓, bg]
- Rayner, P.J., Scholze, M., Knorr, W., Kaminski, T., Giering, R. & Widmann, H. (2005). Two decades of terrestrial carbon fluxes from a carbon cycle data assimilation system (CCDAS). *Global Biogeochem. Cycles* 19: GB2026. https://doi.org/10.1029/2004GB002254 [DOI✓, bg]
- Scholze, M., Kaminski, T., Rayner, P., Knorr, W. & Giering, R. (2007). Propagating uncertainty through prognostic carbon cycle data assimilation system simulations. *J. Geophys. Res.* 112: D17305. https://doi.org/10.1029/2007JD008642 [DOI✓, bg]
- Kaminski, T. et al. (2013). The BETHY/JSBACH Carbon Cycle Data Assimilation System: experiences and challenges. *J. Geophys. Res. Biogeosci.* 118: 1414-1426. https://doi.org/10.1002/jgrg.20118 [DOI✓, abs via secondary]
- Raoult, N.M., Jupp, T.E., Cox, P.M. & Luke, C.M. (2016). Land-surface parameter optimisation using data assimilation techniques: the adJULES system V1.0. *Geosci. Model Dev.* 9: 2833-2852. https://doi.org/10.5194/gmd-9-2833-2016 [DOI✓, bg]
- Zhu, Q. & Zhuang, Q. (2014). Parameterization and sensitivity analysis of a process-based terrestrial ecosystem model using adjoint method. *J. Adv. Model. Earth Syst.* 6: 315-331. https://doi.org/10.1002/2013MS000241 [DOI✓, abs via search summary]
- Kauker, F. et al. (2009). Adjoint analysis of the 2007 all time Arctic sea-ice minimum. *Geophys. Res. Lett.* 36: L03707. https://doi.org/10.1029/2008GL036323 [DOI✓, bg] Adjoint attribution of a single extreme event to forcing by month.
- Heimbach, P. et al. (2011). Timescales and regions of the sensitivity of Atlantic meridional volume and heat transport: toward observing system design. *Deep-Sea Res. II* 58: 1858-1879. https://doi.org/10.1016/j.dsr2.2010.10.065 [DOI✓, bg]
- Aboelyazeed, D. et al. (2023). A differentiable, physics-informed ecosystem modeling and learning framework for large-scale inverse problems: demonstration with photosynthesis simulations. *Biogeosciences* 20: 2671-2692. https://doi.org/10.5194/bg-20-2671-2023 [DOI✓ via search, abs]
- Jiang, P. et al. (2025). JAX-CanVeg: a differentiable land surface model. *Water Resour. Res.* 61: e2024WR038116. https://doi.org/10.1029/2024WR038116 [DOI✓, bg]
- Fang, J., Bowman, K.W., Zhao, W., Lian, X. & Gentine, P. (2026). Differentiable land model reveals global environmental controls on latent ecological functions. *Nature Communications* 17: 6670. https://doi.org/10.1038/s41467-026-73395-4 [DOI✓, abs via search summary]
- Givi, G.M., Travelletti, C. & Mermoud, G. (2026). TrunX: a massively parallel, differentiable implementation of the 3-PG forest growth model in JAX. arXiv:2609.02557. https://arxiv.org/abs/2609.02557 [page✓, abs]
- Shen, C. et al. (2023). Differentiable modelling to unify machine learning and physical models for geosciences. *Nat. Rev. Earth Environ.* 4: 552-567. https://doi.org/10.1038/s43017-023-00450-9 [DOI✓, bg]
- Gelbrecht, M., White, A., Bathiany, S. & Boers, N. (2023). Differentiable programming for Earth system modeling. *Geosci. Model Dev.* 16: 3123-3135. https://doi.org/10.5194/gmd-16-3123-2023 [DOI✓ via search, abs]
- Kristensen, K., Nielsen, A., Berg, C.W., Skaug, H. & Bell, B.M. (2016). TMB: automatic differentiation and Laplace approximation. *J. Stat. Softw.* 70(5). https://doi.org/10.18637/jss.v070.i05 [DOI✓, bg]
- Frank, S.A. (2022). Automatic differentiation and the optimization of differential equation models in biology. *Front. Ecol. Evol.* 10: 1010278. https://doi.org/10.3389/fevo.2022.1010278 [DOI✓, abs]
- Hamazaki, K., Iwata, H. & Tsuda, K. (2025). DiffBreed: automatic differentiation enables efficient gradient-based optimization of breeding strategies. *Bioinformatics* 41: btaf586. https://doi.org/10.1093/bioinformatics/btaf586 [DOI✓, abs via search summary]
- Boussange, V. PiecewiseInference.jl. EGU23-5195 abstract, https://meetingorganizer.copernicus.org/EGU23/EGU23-5195.html, and a JuliaCon 2024 talk [page✓ for abstracts only; no journal paper verified]
- Massoud, E.C. et al. (2019). Identification of key parameters controlling demographically structured vegetation dynamics in a land surface model: CLM4.5(FATES). *Geosci. Model Dev.* 12: 4133-4164. https://doi.org/10.5194/gmd-12-4133-2019 [DOI✓, abs via search summary]
- Parvinen, K., Dieckmann, U. & Heino, M. (2006; online 2005). Function-valued adaptive dynamics and the calculus of variations. *J. Math. Biol.* 52: 1-26. https://doi.org/10.1007/s00285-005-0329-3 [DOI✓, bg]
- Dieckmann, U., Heino, M. & Parvinen, K. (2006). The adaptive dynamics of function-valued traits. *J. Theor. Biol.* 241: 370-389. https://doi.org/10.1016/j.jtbi.2005.12.002 [DOI✓, bg]
- Parvinen, K., Heino, M. & Dieckmann, U. (2013; online 2012). Function-valued adaptive dynamics and optimal control theory. *J. Math. Biol.* 67: 509-533. https://doi.org/10.1007/s00285-012-0549-2 [DOI✓, abs] Singular strategies satisfy Pontryagin's principle with environmental feedback.
- Metz, J.A.J., Staňková, K. & Johansson, J. (2016; online 2015). The canonical equation of adaptive dynamics for life histories: from fitness-returns to selection gradients and Pontryagin's maximum principle. *J. Math. Biol.* 72: 1125-1152. https://doi.org/10.1007/s00285-015-0938-4 [DOI✓, abs via search summary]
- Balduzzi, D. et al. (2018). The mechanics of n-player differentiable games. *Proc. 35th ICML*, PMLR 80: 354-363. https://proceedings.mlr.press/v80/balduzzi18a.html [page✓]

### 9.6 Coexistence theory and empirical selection under climate

- Chesson, P. (1994). Multispecies competition in variable environments. *Theor. Popul. Biol.* 45: 227-276. https://doi.org/10.1006/tpbi.1994.1013 [DOI✓, bg]
- Chesson, P. (2000). Mechanisms of maintenance of species diversity. *Annu. Rev. Ecol. Syst.* 31: 343-366. https://doi.org/10.1146/annurev.ecolsys.31.1.343 [DOI✓, bg]
- Chesson, P. (2018). Updates on mechanisms of maintenance of species diversity. *J. Ecol.* 106: 1773-1794. https://doi.org/10.1111/1365-2745.13035 [DOI✓, bg]
- Ellner, S.P., Snyder, R.E. & Adler, P.B. (2016). How to quantify the temporal storage effect using simulations instead of math. *Ecology Letters* 19: 1333-1342. https://doi.org/10.1111/ele.12672 [DOI✓, bg]
- Ellner, S.P., Snyder, R.E., Adler, P.B. & Hooker, G. (2019; online 2018). An expanded modern coexistence theory for empirical applications. *Ecology Letters* 22: 3-18. https://doi.org/10.1111/ele.13159 [DOI✓, bg]
- Snyder, R.E. & Chesson, P. (2003). Local dispersal can facilitate coexistence in the presence of permanent spatial heterogeneity. *Ecology Letters* 6: 301-309. https://doi.org/10.1046/j.1461-0248.2003.00434.x [DOI✓, bg]
- Kelly, C.K. & Bowler, M.G. (2002). Coexistence and relative abundance in forest trees. *Nature* 417: 437-440. https://doi.org/10.1038/417437a [DOI✓, bg]
- Usinowicz, J. et al. (2017). Temporal coexistence mechanisms contribute to the latitudinal gradient in forest diversity. *Nature* 550: 105-108. https://doi.org/10.1038/nature24038 [DOI✓, bg]
- Siepielski, A.M. et al. (2017). Precipitation drives global variation in natural selection. *Science* 355: 959-962. https://doi.org/10.1126/science.aag2773 [DOI✓, bg]. Comment and reply: https://doi.org/10.1126/science.aan5028 and https://doi.org/10.1126/science.aan5760 [DOI✓]
- Franks, S.J., Sim, S. & Weis, A.E. (2007). Rapid evolution of flowering time by an annual plant in response to a climate fluctuation. *PNAS* 104: 1278-1282. https://doi.org/10.1073/pnas.0608379104 [DOI✓, bg]
- van de Pol, M. et al. (2016). Identifying the best climatic predictors in ecology and evolution. *Methods Ecol. Evol.* 7: 1246-1257. https://doi.org/10.1111/2041-210X.12590 [DOI✓, bg]
- Teller, B.J., Adler, P.B., Edwards, C.B., Hooker, G. & Ellner, S.P. (2016). Linking demography with drivers: climate and competition. *Methods Ecol. Evol.* 7: 171-183. https://doi.org/10.1111/2041-210X.12486 [DOI✓, bg]

### Items considered and not used, or not verified

- Mazumdar, Ratliff & Sastry, "On gradient-based learning in continuous games": not verified (rate-limited lookup); omitted.
- "Stefaniak et al. 2026 (plantNSC)", cited in TF24 source comments: not found [UNVERIFIED].
- A Plant-FATE journal paper describing trait evolution methods: none found. Methods were taken from the source code.

Volume and page numbers for every DOI above were cross-checked against Crossref metadata in this session, and four mismatches were corrected. Where Crossref gives no page range (some PNAS and Wiley e-articles), the article number or the commonly cited range is given.
