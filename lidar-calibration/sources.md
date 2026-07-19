# Sources — annotated bibliography (bootstrap for further literature search)

Salvaged from the deep-research run (`wf_427601ce-c90`) so subsequent literature work starts from **titles +
URLs + DOIs**, not bare identifiers (which were awkward to work with). Grouped as the run found them.
Verification status per claim: **[CONFIRMED]** survived a 3-vote adversarial check · **[UNVERIFIED]**
extracted from a primary source but the run was cut off before voting · **[REFUTED]** adversarially killed —
do not carry. Sources without a quoted claim below still list a `claims extracted` count — the source is
worth reading; the thematic findings are digested in `literature.md`.

Two anchors were later read in full and **verified verbatim** (see `foundation.md`): Eckes-Shephard et al.
2025 (`10.1111/nph.70643`) and Chambers et al. 2013 (`10.1073/pnas.1202894110`).

---

Provenance: deep-research run `wf_427601ce-c90` — 23 primary sources, 112 extracted claims, 14 adversarially confirmed (+3 refuted, 8 unverified when the run was cut off). Raw journals preserved (see foot).

### 1. Bolker & Pacala (1999), Spatial Moment Equations for Plant Competition: Understanding Spatial Strategies and the Advantages of Short Dispersal (American Naturalist 153:575-602)
- URL: https://www.journals.uchicago.edu/doi/10.1086/303199
- DOI: 10.1086/303199
- quality: primary · claims extracted: 5
- [CONFIRMED] Characterizing spatial competitive dynamics in a fully spatial stochastic plant model requires tracking not only mean densities (the first moment / mean-field state) but also the spatial covariance (second moment) of the competing populations — i.e., the first
   > "We use moment equations, equations for the mean densities and spatial covariance of competing plant populations, to characterize these strategies in a fully spatial stochastic model."
- [CONFIRMED] The mean-plus-covariance moment equations predict endogenous spatial pattern formation (self-generated spatial structure arising from the dynamics), a phenomenon a non-spatial mean-field first-moment model cannot represent; the second moment is what carries th
   > "The moment equations predict endogenous spatial pattern formation and the efficacy of spatial strategies under different conditions."

### 2. Murrell, Dieckmann & Law (2004), On moment closures for population dynamics in continuous space (Journal of Theoretical Biology 229:421-432)
- URL: https://user.iiasa.ac.at/~dieckman/reprints/MurrellEtal2004.pdf
- quality: primary · claims extracted: 5
- [CONFIRMED] The dynamics of the first spatial moment (mean density) are NOT closed: they contain flux terms depending on the second moment (pair density / spatial covariance C(xi)). The mean-field/logistic equation is recovered only by imposing the closure C(xi)=N^2. Henc
   > "The dynamics of the first spatial moment (average over space of population density) turn out to have flux terms involving the second moment (a spatial covariance or pair density; see Section 2.1). ..."
- [CONFIRMED] Even a second-order (order-two) closure is fundamentally limited: truncating the moment hierarchy at order two necessarily fails to approximate spatial structures that carry significant information in higher-order moments, and the authors explicitly warn that 
   > "truncation of the moment hierarchy at order two necessarily limits the types of spatial structure that can be successfully approximated. Spatial structures with significant amounts of information in s"

### 3. Black & McKane (2012), Stochastic formulation of ecological models and their applications (Trends in Ecology & Evolution 27:337-345)
- URL: https://www.researchgate.net/publication/221692207_Stochastic_formulation_of_ecological_models_and_their_applications
- quality: primary · claims extracted: 4
- [CONFIRMED] Demographic/stochastic effects can be important in parameter ranges and systems where they were previously assumed negligible, implying the deterministic mean-field (population-level, first-moment) description can fail to capture the behavior of finite stochas
   > "We discuss recent work that highlights the importance of stochastic effects for parameter ranges and systems where it was previously thought that such effects would be negligible."

### 4. Ovaskainen & Cornell (2006), Space and stochasticity in population dynamics (PNAS 103:12781-12786)
- URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC1568924/
- quality: primary · claims extracted: 5
- [CONFIRMED] A rigorous perturbation/series expansion in the interaction range yields corrections to the mean-field model that become exact in the long-interaction-range limit (L to infinity), with an a priori known error of order O(L^(-(n+1)d)) for an nth-order approximat
   > "The major advantage of the perturbative approach is that it becomes exact at the limit L → ∞, and that we know a priori that the error behaves as 𝒪(L^(−(n+1)d)), where n is the order of the approximat"
- [REFUTED] Mean-field models systematically overestimate equilibrium and transient population density relative to the spatial stochastic realization, because spatial aggregation raises the LOCAL density (and hence density-dependent mortality) experienced by a randomly ch

### 5. Fröhlich et al. (2016), Inference for Stochastic Chemical Kinetics Using Moment Equations and System Size Expansion (PLoS Computational Biology 12:e1005030)
- URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC4957800/
- quality: primary · claims extracted: 5
- [CONFIRMED] In the low-copy-number / small-system-size regime, deterministic macroscopic (mean-field, RRE) and even mesoscopic moment/system-size-expansion descriptions depart from the true stochastic process and produce large parameter-estimation errors — i.e., mean-fiel
   > "For small volumes, meso- and macroscopic descriptions depart from the underlying process resulting in large estimation errors"
- [CONFIRMED] Using second-order / realization structure (a mesoscopic moment or system-size-expansion description) rather than the mean-field description can render a parameter STRUCTURALLY identifiable that is non-identifiable under the deterministic macroscopic model — e
   > "one parameter that was not structurally identifiable when using a macroscopic description becomes structurally identifiable when using a mesoscopic description"

### 6. Komorowski et al. (2011), Sensitivity, robustness and identifiability in stochastic chemical kinetics models (PNAS 108:8645-8650; arXiv:1104.1274)
- URL: https://arxiv.org/pdf/1104.1274
- quality: primary · claims extracted: 5
- [CONFIRMED] A mean-field (deterministic, first-moment-only) model identifies strictly fewer parameters than a stochastic model that retains second-order structure. In the gene-expression example (observing protein only), the deterministic model identifies just 1 of 4 para
   > "For TS data we have four identifiable parameters whereas time-point measurements provide enough information to estimate only two parameters. ... As one might expect in the deterministic model only one"
- [CONFIRMED] There exist explicit parameter directions that leave the mean (macroscopic trajectory) exactly unchanged but change the variance, so they are structurally non-identifiable from a mean-field model yet identifiable once fluctuations are modeled. Concretely, pert
   > "The means of RNA and protein concentrations are not affected by this perturbation, whereas the protein variance does change (see formulae (33-37) in SI). ... The FIM for the stationary distribution of"

### 7. Moorcroft, Hurtt & Pacala (2001), A Method for Scaling Vegetation Dynamics: The Ecosystem Demography Model (ED), Ecological Monographs
- URL: https://esajournals.onlinelibrary.wiley.com/doi/abs/10.1890/0012-9615(2001)071%5B0557:AMFSVD%5D2.0.CO;2
- DOI: 10.1890/0012-9615(2001)071%5B0557:AMFSVD%5D2.0.CO;2
- quality: primary · claims extracted: 5
- [CONFIRMED] The Ecosystem Demography (ED) model's deterministic size- and age-structured (SAS) system of PDEs is explicitly constructed as the FIRST MOMENT (ensemble mean) of an underlying stochastic individual-based gap model, valid in the limit of a large number of gap 
   > "The key to scaling such a model is the recognition that the ensemble average used for stand or landscape-level predictions is, in the limit of a large number of runs, the first moment of the stochasti"
- [CONFIRMED] The mean-field closure is obtained by Taylor-expanding the nonlinear per-capita growth and mortality functions about the age-conditional MEAN resource level and discarding all second- and higher-order terms, then evaluating demographic rates at the mean resour
   > "The SAS approximation is obtained by Taylor expanding the expressions inside the brackets on the right-hand side of Eq. 2 about the size- and gap age-specific conditional ensemble means, neglecting se"

### 8. Falster et al. (2016), plant: A package for modelling forest trait ecology and evolution, Methods in Ecology and Evolution
- URL: https://besjournals.onlinelibrary.wiley.com/doi/full/10.1111/2041-210X.12525
- DOI: 10.1111/2041-210X.12525
- quality: primary · claims extracted: 5
- [UNVERIFIED] plant offers TWO solution modes for within-patch size-structured dynamics — a stochastic finite-patch mode (generates discrete seed-arrival events and simulates a finite population) and a deterministic mode — and the deterministic mode IS the mean-field limit:
- [UNVERIFIED] plant computes landscape/metapopulation-level quantities (total leaf area, biomass, productivity, size distributions) by AVERAGING single-patch trajectories over the patch-age frequency distribution P(a), under an island-model assumption of an infinite number 

### 9. Levin & Paine (1974), Disturbance, Patch Formation, and Community Structure, PNAS
- URL: https://www.pnas.org/doi/10.1073/pnas.71.7.2744
- DOI: 10.1073/pnas.71.7.2744
- quality: primary · claims extracted: 4
- [UNVERIFIED] Localized disturbance generates a landscape mosaic whose statistical description is a predictable frequency distribution of renewed patches over both size and age (colonization stage) — the foundational structured-population object (a patch age/size distributi
- [UNVERIFIED] Aggregate community/landscape-level pattern can be reconstructed by combining the local within-patch biology with the patch age/size distribution — i.e., the overall spatial pattern of the system is expressible as an ensemble aggregate over the distribution of

### 10. Chambers et al. (2013), The steady-state mosaic of disturbance and succession across an old-growth Central Amazon forest landscape, PNAS
- URL: https://www.pnas.org/doi/10.1073/pnas.1202894110
- DOI: 10.1073/pnas.1202894110
- quality: primary · claims extracted: 5
- [UNVERIFIED] Old-growth forest is a mosaic of patches in different successional stages in which the fraction of the landscape in any given successional state stays approximately constant over large temporal and spatial scales — the operational definition of a shifting-mosa
- [UNVERIFIED] The spatial scale over which the mosaic steady state emerges (the effective decorrelation length / patch scale) is set by the disturbance-event size distribution, the disturbance return frequency, and the subsequent recovery/succession processes — i.e. the dis

### 11. Kohyama & Takada (2005), Scaling up from shifting-gap mosaic to geographic distribution in the modeling of forest dynamics, Ecological Research
- URL: https://esj-journals.onlinelibrary.wiley.com/doi/10.1007/s11284-005-0046-9
- DOI: 10.1007/s11284-005-0046-9
- quality: primary · claims extracted: 4

### 12. Eckes-Shephard et al. (2025), Demography, dynamics and data: building confidence for simulating changes in the world's forests, New Phytologist
- URL: https://nph.onlinelibrary.wiley.com/doi/10.1111/nph.70643
- DOI: 10.1111/nph.70643
- quality: primary · claims extracted: 5

### 13. Wood (2010), Statistical inference for noisy nonlinear ecological dynamic systems (Nature) — origin of synthetic likelihood
- URL: https://www.nature.com/articles/nature09319
- quality: primary · claims extracted: 5

### 14. Cranmer, Brehmer & Louppe (2020), The frontier of simulation-based inference (PNAS)
- URL: https://www.pnas.org/doi/10.1073/pnas.1912789117
- DOI: 10.1073/pnas.1912789117
- quality: primary · claims extracted: 5

### 15. Grimm et al. (2005), Pattern-Oriented Modeling of Agent-Based Complex Systems: Lessons from Ecology (Science)
- URL: https://www.science.org/doi/10.1126/science.1116681
- DOI: 10.1126/science.1116681
- quality: primary · claims extracted: 5

### 16. van der Vaart et al. (2015), Calibration and evaluation of individual-based models using Approximate Bayesian Computation (Ecological Modelling)
- URL: https://www.sciencedirect.com/science/article/pii/S0304380015002173
- quality: primary · claims extracted: 5

### 17. A critical review of common pitfalls and guidelines to effectively infer parameters of agent-based models using Approximate Bayesian Computation (Environmental Modelling & Software, 2023)
- URL: https://www.sciencedirect.com/science/article/abs/pii/S1364815223002918
- quality: primary · claims extracted: 5

### 18. Ma et al. (2023) — Spatial heterogeneity of global forest aboveground carbon stocks and fluxes constrained by spaceborne lidar data and mechanistic modeling (Global Change Biology 29:3378–3394)
- URL: https://research.fs.usda.gov/treesearch/66090
- quality: primary · claims extracted: 5

### 19. Hancock et al. (2019) — The GEDI Simulator: A Large-Footprint Waveform Lidar Simulator for Calibration and Validation of Spaceborne Missions (Earth and Space Science)
- URL: https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2018EA000506
- DOI: 10.1029/2018EA000506
- quality: primary · claims extracted: 5

### 20. DART 3D Radiative Transfer Modeling Applied to RAMI Forests – Part 2: Lidar Waveform Simulation and Canopy Structure Analysis (Journal of Remote Sensing)
- URL: https://spj.science.org/doi/10.34133/remotesensing.0737
- DOI: 10.34133/remotesensing.0737
- quality: primary · claims extracted: 5

### 21. Which demographic processes control competitive equilibria? Bayesian calibration of a size-structured forest population model
- URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC10318622/
- quality: primary · claims extracted: 5

### 22. Identification of key parameters controlling demographically structured vegetation dynamics in a land surface model: CLM4.5(FATES)
- URL: https://gmd.copernicus.org/articles/12/4133/2019/
- quality: primary · claims extracted: 5

### 23. The Impact of Disturbance on Tree Size Distributions in the United States (Eichenwald et al. 2025, Global Ecology and Biogeography)
- URL: https://onlinelibrary.wiley.com/doi/10.1111/geb.70102
- DOI: 10.1111/geb.70102
- quality: primary · claims extracted: 5

---

## Provenance / re-extraction

The raw research journals are **session-ephemeral** (they live under the container's transcript dir and do
not persist), so *this file and `literature.md` are the durable salvage*. While a session is live they can be
re-parsed for the full 112 claims (incl. the Thread 3–5 fetch claims not attributed above):

- `…/subagents/workflows/wf_427601ce-c90/journal.jsonl` — one JSON object per line; `type=="result"` entries
  hold search results (`result.results[]`: url/title/snippet), fetch claims (`result.claims[]`: claim/quote),
  and verify votes (`result.refuted`, `result.evidence`).
- the original run result — `result.sources[]` (23 urls), `result.confirmed/refuted/unverified[]`
  (claim/source/quote/vote).

Extraction recipe: iterate `type=="result"` lines; build `url → {title, snippet}` from search entries and
`url → [claims]` from fetch/verify entries; join on url.
