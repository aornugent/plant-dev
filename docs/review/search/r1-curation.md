# Round 1 curation

## How I read them

I read process.md, assembly-geometry.md, assembly-mfg.md, field-cut.md §9, site-selection.md §§1-3, workflows.md §2, theory.md (A.4, C.2-C.4, F) and the three spike READMEs. I checked the TF24 storage and mortality code (`tf24_strategy.h`, lines 1333-1337, 2036-2090 and 2701-2733) and FF16's mortality (`ff16_strategy.h`, line 1412). I recomputed the ecology proposal's r\*/μ̂ table, and it reproduces exactly. I also ran three brief literature searches.

Two findings from the code change how the proposals should be read:

- **The hazard's knife width in TF24 is an absolute AD smoother.** It is `storage_prod_eps = 1e-4`, in kg/yr per plant, and is documented as "smooths the positive-part of net production ... for AD-readiness". It does not scale with plant size.
- **FF16 has the same mechanism with an ecological width.** FF16 in the same package uses mortality a_dG1·exp(−a_dG2·productivity per leaf area), a smooth growth-dependent hazard whose width is set by an ecological parameter. So the "front" theory comes with a ready-made control experiment inside plant. It also means the claim that "simulators with carbon-balance mortality have no derivatives" is too strong for plant itself. The reserve-buffered *knife* is what is new to TF24.

Scores are 1-5, in the order insight / novelty / fit to our advantages / depth / significance.

---

## 1. Ecology: "The thinning front" (5 / 4 / 5 / 4 / 5)

**Strongest insight.** Lemma 1: self-thinning that runs through a reserve-switched hazard pins the subordinate layer within one knife width of zero carbon balance, generically. Any thinning rate κ ∈ (0.017, 1.02)/yr maps to |P| < ε. This one mechanism explains three anomalies in our own record:
- the A.4 jump (+7.40 / 0 / −39.85);
- the closed-stand gain of 3.5e3-7.6e3 against 49-64 elsewhere;
- the thinned schedule's larger error on the closed stand (1.0 against about 0.5).

The proposal then derives what follows:
- the coarea form of the gain, ∂ln R′/∂δ = a_dG1 Σ π_c Σ_k P_g/|Ṗ_c(a_k)|;
- the cut/kept cancellation (Lemma 3: the commons term ⟨S, ∂𝓔/∂δ⟩ = −∂φ/∂δ + O(1));
- an asymmetric step on the PIP diagonal (J⁺ bounded by d_I, J⁻ by a_dG1);
- a lexicographic, kinked ESS.

**Novelty.** The front's ingredients are known:
- Huisman & Weissing (1994) have the critical light intensity I_out\* in phytoplankton, the lowest-wins R\* for light. The proposal does not cite it, and its "minimise ℓ_c" principle is that rule moved into height × patch age.
- Adams, Purves & Pacala's Ẑ\*.
- Givnish's whole-plant compensation point.
- Carbon-balance mortality in ED (Moorcroft, Hurtt & Pacala 2001) and in FF16.

A brief search found nothing tying self-thinning to criticality at the compensation point (Reynolds & Ford's review explicitly calls for mechanistic mortality). What looks new:
- the generic pinning;
- the cancellation between held and responding derivatives;
- the PIP step and the lexicographic ESS;
- "selection's resolution is set by within-cohort variance w".

**Fit.** Excellent: every lemma is a difference between quantities the platform computes exactly.
- The cut against the kept sweep tests Lemma 3.
- The costates map the ridge Γ.
- `storage_prod_eps` on the tape gives ∂ln R′/∂ln ε in one sweep, which separates artefact from ecology.

**Depth.** Lemmas 1 and 3 are heuristic. They rest on three assumptions: thinning occurs only through μ̂, reserves are quasi-static, and κ is steady. The cancellation is argued to leading order, not proved. The toy calibration (gain 0.267·D·q, with q ≈ 1000 giving 2.7e3-8e3) matches the measured order. That match is suggestive, but q is set so that it matches.

**Significance.** Very high, either way the ε test comes out:
- **If ecological:** a new mechanism for shade-tolerance ESSs, a new recruitment-mode niche, and three sharp field predictions. Fertilisation raises mortality, not understorey light; understorey light equals the dominant species' compensation light; and diversity rises with light heterogeneity at a fixed mean.
- **If an artefact:** TF24's closed-canopy fitness is set by a numerical regulariser standing in for missing within-cohort variance. That governs O1, O3, O6 and O7, and every pricing and table method.

## 2. Mathematics: "Height stratification is zero-sum" (5 / 4 / 4 / 4 / 4)

**Strongest insight.** Under Beer-Lambert the direct light kernel in log light is a Heaviside step, so

  A⁰(a) = D_T(a) Π(a) D_L(a),  with Π_ij = Pr(Z_j > U_i).

Under alignment (each species' elasticity distributed in height like its own leaves), Π + Πᵀ = 11ᵀ for any number of species and any crown shapes. That is May-Leonard's α + β = 2.

- In the dynamic metric W = diag(1/ρ_i), the symmetric part of A⁰ at one age is L Lᵀ, rank one. Diagonal stability depends only on Π.
- Across patch ages, the symmetric part is ½ the Gram matrix of the species' leaf-area trajectories L_i(a). So light can stabilise at most rank[L_i(a)] species, and the regulating factors are patch ages, not heights.
- The departure from neutrality is the offset δ_i = Pr(Z_i > U_i) − ½. δ > 0 gives damped spirals; δ < 0 gives heteroclinic dominance and founder control.

The algebra is right: I checked the congruence D = D_L D_T⁻¹ and the triangular case.

**Novelty.** May-Leonard, Moon-Pullman tournaments and Volterra-Kerner conservative LV are known. Adams et al. (2007) found PPA species differing only in transmissivity to be neutral. Deriving the neutral knife edge from Beer-Lambert for general n, and naming δ as the stabilising quantity, appears new.

It must be reconciled with Kohyama's stratification theory (Kohyama 1993; Kohyama & Takada), which claims coexistence *from* stratification under one-sided competition. In this frame that coexistence would have to come from δ (recruitment below one's own canopy) or from the feedback term A^fb. Saying which, explicitly, would turn the reconciliation into a real result.

**Fit.** Good. It needs u_i(z, a), which is I × the cut's zeroed adjoints, and the kept sweep's β columns, which give A^fb = A − A⁰ exactly. The measured data fit:
- the open pairs are near rank one, with λ_min(A_s) ≈ 0;
- the closed pair has skew 0.048 and λ_min 0.104.

**Depth.** Rigorous for the direct, linearised kernel. The ρ_i τ(a) separability behind the Gram form is an assumption, and u ≥ 0 may fail with water coupling.

**Significance.** It names where forest light coexistence can come from: succession, and advance regeneration. The crossover prediction is sharp and untested: optimal Vcmax acclimation pushes δ negative and so erodes coexistence. That joins the EEO and coexistence literatures. It also refines assembly-geometry §3's crown-depth story: crown depth matters only through δ.

## 3. Adjoint: "Endogenous prices" (4 / 3 / 5 / 4 / 4)

**Strongest insight.** Two results:
- **Fixed-price regret** (5): Δφ_plastic = ½𝒲[(p̄ − p)² + Var_W(p\*)]. The bias term is selection on the price parameter. The variance term is the RV-weighted value of plasticity, which says plasticity is selected where the *costate ratio* varies, not where the environment varies.
- **Stage-weighting bias.** The ESS price is set by the cohorts where W = wℓλ_P ∂q\*/∂p is large. Under a closed canopy those are suppressed juveniles, so EEO prices calibrated on adults are biased in a computable direction.

**Novelty.** Moderate, and much of the core is already in this repo:
- theory.md F.4 already derives the ESS water price as zero, λ_W^stand from the costates, the stomatal commons, and the test ∂ln R′/∂λ_o = 0 at λ_o = 0;
- C.4 has the envelope argument.

So Results 1-2 and worked case (c) are restatements or generalisations. Also in the literature: Pontryagin as EEO (Metz, Staňková & Johansson 2016; Mäkelä; Manzoni), and the stomatal ESS under shared water (Wolf, Anderegg & Pacala 2016).

What is new:
- the general K-good form (2), p\* = λ_q/λ_P;
- the privacy interpolation (3), g(s) = g + s(F_θ − g), which reads kept and cut as relatedness 1 and 0. Kin-selection versions of root and water games exist (for example Gersani et al. 2001 on root over-proliferation), so the identification with the two sweeps is the delta;
- the regret decomposition;
- the estimand ŝ = λ_obs/Δp_water.

**Fit.** Excellent. The ratios adj(soil_consumption_j)/adj(profit) are tape nodes, and kept and cut give s = 1 and s = 0.

**Depth.** Clean. The worked case (a) shows ratio = 1/N = s.

**Significance.** It gives a principled answer to EEO's cost-parameter problem, and the λ_P channel decomposition diagnoses the knife edge, which complements proposal 1.

## 4. Imports: "Sites as prices" (4 / 5 / 4 / 4 / 4)

**Strongest insight.** Optimality across sites has level-free, trade-off-free content: cyclical monotonicity. The Rockafellar first-order form Σ⟨σ_k, y_{k+1} − y_k⟩ ≤ 0 needs only P1 and P3 per site: no invaders, no b-balance, no levels. Two consequences:
- **Curl.** Pairwise (sympatric-allopatric) contrasts see only the symmetric part of the site-to-niche map. A skew ratio b is invisible to cycles shorter than π/arctan b, and lag around a field loop produces exactly that curl (tan φ = ωτ, checked numerically).
- **Le Chatelier.** Plastic ⪯ intraspecific ⪯ turnover responses in field coordinates, against response conservation in supply coordinates. That contrast is a genuinely new theoretical claim.

**Novelty.** High within ecology. The search found nothing applying cyclical monotonicity to local adaptation or communities. The theorems themselves are imported:
- Afriat; Rockafellar; Echenique-Lee-Shum;
- Bartz et al. on rotations and n-cyclic monotonicity;
- Samuelson and Milgrom-Roberts on Le Chatelier;
- Brenier and McCann on optimal transport.

The 3-cycle example (c) applies to raw transplant tables *without our model*, a free contribution to the "is local best?" debate (Bucharova et al. 2017).

**Fit.** Good: σ_s and y_s are free byproducts of each site's recording, low d gives the test power, and P8 certifies cycle signs. Parts of it, though (the raw-table matching test), do not need our advantages.

**Depth.** Correct and carefully caveated. The direction-only GARP variant (σ = κ_s σ̃_s) is exactly the right tool for break-even amplification, a link the proposal half-makes.

**Significance.** It gives the site workflow its first test that is immune to the trade-off problem (site-selection.md §1) and to the fragility of levels. It also makes a falsifiable claim: field-coordinate trait slopes exceed climate slopes, increasingly with richness.

## 5. EEO-data: "One field, four clocks" (4 / 3 / 4 / 3 / 4)

**Strongest insight.** ŷ_i = y_s − G_i⁺ g_is, the "field of adaptation". It is a closed-form inverse optimisation under affine sensing, with three tests that need no equilibrium:
- **T1:** the gradient in null(G_iᵀ) is site-invariant;
- **T2:** ŷ_i is the same at every site of the species;
- **T3:** persistence.

Weather, composition, traits and leaf prices then become four estimates of one latent field, and the differences between them separate ecological lag, evolutionary lag, constraint and model error. The JSDM reading is fresh: latent site factors are the made field Y, with loadings S_i predicted from traits.

**Novelty.** Partial:
- Proposition 1 (an optimisation principle on fibres of S) largely restates field-cut §9.4-9.5 (slaved traits, J = H on null(M)) and O4's A(σ).
- Proposition 2 is Chesson's linear-additivity result together with LV and replicator time averages; the proposal says so honestly.
- The four-clock ladder, T1/T2 and the mechanistic JSDM loadings are new.

**Fit.** Good: S, G, costates and the real record.

**Depth.** Moderate. The averaging lemma needs B/Γ small, but trees get one to three generations per record. Affinity fails on closed canopies, exactly where the front lives.

**Significance.** It moves the equilibrium geometry onto history rows, makes climatic debt a d-vector, and gives O5 site-invariant calibration targets.

---

## Cross-cutting observations (for recombination)

1. **The front is the hidden hinge of three proposals.** Each of the following is the same object, the compensation front Γ:
   - the mathematics proposal's positive δ is carried by "suppressed cohorts near compensation";
   - the adjoint proposal's W is dominated by the same cohorts;
   - eeo-data's affinity fails where the front is.
2. **Tournament algebra on one front.** If two species' fronts sit at the same height below both canopies, then Π_ii → ½ + δ with δ → ½, and Π_ij → 1. So Π → 11ᵀ: rank one, the Huisman-Weissing exclusion. The ecology proposal's "one bank species per front" and the mathematics proposal's "δ stabilises" are then the same statement. A front offset stabilises only when it falls below one's own leaves but *not* below the competitor's. Coexistence needs fronts at different heights or patch ages, which is the age-Gram term. (This is my derivation, from the two proposals' own definitions.)
3. **A step in fitness gives a Jensen term.** Under variable rain, the step nonlinearity across Γ makes eeo-data's term ½tr(∂²φ·Cov y) large exactly on closed canopies. That is a candidate for fluctuation-dependent coexistence through carbon reserves, Chesson's "storage" in the literal sense.
4. **Imports and eeo-data are two halves of one site-level inverse-optimality theory:**
   - the cycle and curl tests are level-free but discrete;
   - ŷ_i is local and closed-form;
   - curl ∝ ωτ (imports) and ŷ_i − y_s (eeo-data) both measure lag;
   - adjoint's p\* supplies the fourth clock (leaf prices);
   - GARP with free multipliers absorbs front amplification.

Sources consulted:
- [Kohyama-related search](https://tiantong.ecnu.edu.cn/show/573), [ESJ abstract](https://esj.ne.jp/meeting/abst/55/P1-007.html)
- [Reynolds & Ford, self-thinning review](https://faculty.washington.edu/edford/Reynolds.htm)
- [Bucharova et al. 2017](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5743477/)
- [Frontiers 2023, adapting populations in transplants](https://www.frontiersin.org/journals/ecology-and-evolution/articles/10.3389/fevo.2023.1151283/pdf)

## Atoms

- **E1** [checked on a case (table recomputed from TF24 code; reproduces exactly)] The quasi-static reserve fixed point r*(P) solves (1−G(r))(1−r) = (√(x²+1)−x)² r with x = P/ε. So μ̂(P) is a knife of width about ε spanning 0.01 to 5.5/yr, with slope μ̂′(0) = −0.267/ε. *(from ecology; It makes TF24's hazard effectively a step in the sign of whole-plant carbon balance.)*
- **E2** [checked in code (tf24_strategy.h lines 1333-1337, 2044-2048)] The knife width ε is `storage_prod_eps = 1e-4`, an absolute AD smoothing constant in kg/yr per plant, documented as an AD-readiness regulariser. It does not scale with plant size, so a sapling producing 0.1 kg/yr has q ≈ 1000. *(from ecology + curator code read; The closed-canopy gain of 3.5e3-7.6e3 may be set by a numerical constant standing in for within-cohort variance. That governs every closed-canopy result.)*
- **E3** [checked in code (ff16_strategy.h line 1412)] FF16 in the same package has growth-dependent mortality a_dG1·exp(−a_dG2·productivity per leaf area): the same mechanism with no reserve buffer and an ecological width set by a_dG2. *(from curator (code read); It is a built-in control experiment: front theory predicts FF16's closed-canopy gain scales with a_dG2, not with any regulariser.)*
- **E4** [derived (heuristic: quasi-static reserves, steady κ)] Lemma 1, criticality of the thinning front. If subordinate deaths come only through μ̂, any thinning rate κ between background and starvation mortality puts the layer's net production at μ̂⁻¹(κ), within one knife width of zero, generically and without tuning. *(from ecology; The understorey is self-organised to the compensation point: an R* for light made by deaths, not by seed rain.)*
- **E5** [derived] Held-field gain localises on level crossings of P = 0 (coarea): ∂ln R′/∂δ = a_dG1 Σ_c π_c Σ_k P_g/|Ṗ_c(a_k)|. The field adjoint S is therefore a ridge along the front Γ in height × patch age, and diverges at tangency. *(from ecology; It predicts where in height × patch age the knife edge lives, readable from costates without perturbation.)*
- **E6** [conjectured (leading-order argument); testable with one cut sweep and one kept sweep] Lemma 3, commons cancellation. For a stand-wide carbon change, ⟨S, ∂𝓔/∂δ⟩ ≈ −∂φ/∂δ|_E + O(1): a uniform carbon advantage becomes faster thinning, not survival. Prediction: g_P of order 10³ against F_P of order 1-10 on the closed resident. *(from ecology; The resident's own balance stays smooth while invader fitness jumps, which explains why F(ln b) is smooth at slope −1.5 while the gain is in the thousands. Pricing near residents must be one-sided.)*
- **E7** [derived on a toy; sign consistent with an older measurement made before the storage model] Near the diagonal the PIP is an asymmetric step: the upside is bounded by J⁺ = ln[(1−f) + f·e^{D(κ−d_I)}] and the downside reaches −D(a_dG1 − κ). The small-mutation regime is only |Δln P| ≲ ε/P̄_g, about 1e-3. The sign matches A.4 (+7.4 against −39.9). *(from ecology; The canonical equation fails for carbon traits; evolution becomes a ratchet that depends on mutation size.)*
- **E8** [conjectured] On a front-dominated stand the feedback is one scalar per front (the front light). By Metz-Mylius-Diekmann, evolution minimises compensation light ℓ_c at the front height and pessimises the field. The ESS is lexicographic, a kink rather than a root of g. *(from ecology; The closed-canopy reference community in lma, rho and vcmax should be a kink. The singular-point machinery (g = 0, H, J) must handle one-sided gradients.)*
- **E9** [conjectured] Recruitment modes (open, or through a front) have nearly disjoint sensitivity support, so they are independent regulating factors. At most one bank species per front; robust coexistence of a bank recruiter with an open recruiter. *(from ecology; It gives a structural successional niche, divided by the sign of carbon balance at recruitment rather than by a trait axis.)*
- **E10** [conjectured] Selection on shade tolerance scales as 1/w, with w the within-cohort spread of P. Strong purifying selection with bounded directional selection predicts conserved shade-tolerance rankings and more shade-tolerant species under heterogeneous (sunfleck-rich) understoreys at a fixed mean light. *(from ecology; Individual variation sets the resolution of selection: a new ecological role for intraspecific variability.)*
- **E11** [known in the literature (from memory; Huisman & Weissing 1994 Ecology)] Minimising compensation light at the front is Huisman & Weissing's (1994) critical light intensity I_out* rule for phytoplankton, and the PPA's Ẑ*, moved into height × patch age with deaths in place of dilution. *(from curator (prior art); It anchors the front's R* claim. The novelty is the emergence through carbon-balance thinning and the cut/kept cancellation.)*
- **M1** [derived (algebra checked)] Under Beer-Lambert the direct light kernel factors as A⁰(a) = D_T(a) Π(a) D_L(a), with Π_ij = Pr(Z_j > U_i): T_i is total light elasticity, L_j is leaf area, U is the elasticity distribution in height and Z is the leaf distribution. Reflection identity: Π_ij + Pr(Z_j < U_i) = 1, exactly. *(from mathematics; It splits light competition into amounts and a tournament of probabilities, each readable from the cut.)*
- **M2** [derived; checked numerically on Efron-type profiles] Under alignment (U_i ~ Z_i), Π + Πᵀ = 11ᵀ with Π_ii = ½: May-Leonard's α + β = 2 for any n and any crown shapes. In the metric W = diag(1/ρ_i) the symmetric part is L Lᵀ, rank one. Light at one patch age regulates only total leaf area; composition is neutral (n = 2) or conservatively cyclic (n ≥ 3). *(from mathematics; Height stratification alone cannot stabilise: a mechanistic origin for zero-sum neutrality in light-limited stands.)*
- **M3** [derived; checked on a 2 × 2 example] Across patch ages, with separable per-leaf elasticity, (W A⁰)_s = ½∫τ(a) L(a) L(a)ᵀ da: the Gram matrix of the species' leaf-area trajectories over succession. Light can stabilise at most rank[L_i(a)] species. *(from mathematics; Light's regulating factors are patch ages, not heights; it fits the measured age-band modes.)*
- **M4** [derived; checked numerically] The offset δ_i = Pr(Z_i > U_i) − ½ is the stabilising trait. δ > 0 (elasticity below one's own leaves) gives damped coexistence; δ < 0 gives heteroclinic dominance and founder control. Two aligned species can never show founder control (det Π = (Π_12 − ½)² ≥ 0). *(from mathematics; Priority effects in forests require elasticity above the foliage. It is a sharp criterion, computable per species.)*
- **M5** [derived (within-crown value computed; the between-cohort claim is conjectured)] In TF24's mean-light model every crown has δ = −0.156, so any positive δ must come from between cohorts: suppressed cohorts with large λ-weighted elasticity on little leaf area put U below Z. *(from mathematics; Light self-limitation in TF24 would be carried by advance regeneration, which links directly to the front (E4).)*
- **M6** [conjectured (crossover prediction; untested)] Optimal acclimation (capacity tracking light) makes P nearly linear in local light, so u ∝ I·ℓ and δ < 0. Canopy optimality removes the saturation that made δ positive and so erodes light-mediated coexistence. *(from mathematics; It is a new, sharp bridge between EEO and coexistence theory, with a cross-site diversity prediction.)*
- **M7** [derived] The kept sweep's β columns give the full A, and A⁰ comes from u and ℓ, so the feedback part A^fb = A − A⁰ (shading through changed growth) separates exactly. *(from mathematics; It decomposes the measured closed-pair λ_min(A_s) = 0.104 into its sources: age Gram, δ, water and feedback.)*
- **X1** [conjectured (derived from the two proposals' definitions, unchecked on TF24)] If two species' fronts sit at a common height below both canopies, then δ_i → ½ and Π_ij → 1, so Π → 11ᵀ (rank one), which is exclusion by an R* rule. A front stabilises only when it lies below the species' own leaves but not below the competitor's. Coexistence needs fronts at different heights or patch ages. *(from curator (from M1-M4 + E4/E9); It reconciles 'one bank species per front' with 'δ > 0 stabilises', and turns both into one testable geometry.)*
- **M8** [known in the literature (2009 paper not located by search)] Kohyama's stratification theory (1993; Kohyama & Takada) claims coexistence from one-sided light competition in size-structured stands, which conflicts with M2's 'stratification is zero-sum'. *(from curator (prior art); The reconciliation (is Kohyama's coexistence δ or A^fb?) would be a publishable result in itself.)*
- **A1** [derived (single-plant forms known: Metz, Staňková & Johansson 2016; Mäkelä; Manzoni; theory.md F.4)] Any EEO inner optimisation max P(u) + Σ p_k q_k(u) is Pontryagin with costate ratios frozen. The endogenous price is p*_k = λ_{q_k}/λ_P, and ∂_u𝓗 = λ_P Σ(p*_k − p_k) q_k′. *(from adjoint; Every EEO cost parameter is a ratio of reproductive values, readable from TF24's tape at each rate evaluation.)*
- **A2** [derived (the water case is known qualitatively: Wolf, Anderegg & Pacala 2016; the ESS water price of zero is already in theory.md F.4)] The cut sets to zero the price of any consequence acting only through the shared field. Kept and cut are the endpoints of a privacy interpolation, g(s) = g + s(F_θ − g) and p(s) = p*_cut + sΔp, which is Taylor-Frank direct fitness with relatedness s. *(from adjoint; An observed marginal water cost estimates privacy, ŝ = λ_obs/Δp_water, a new site estimand needing no equilibrium.)*
- **A3** [derived (exact in the quadratic toy)] Fixed-price regret: Δφ_plastic = ½𝒲[(p̄ − p)² + Var_W(p*)], with W = wℓλ_P ∂q*/∂p. The bias term is selection on the parameter; the variance term is the irreducible value of plasticity. *(from adjoint; Plasticity is selected where the reproductive-value-weighted costate price varies, not where the environment varies: a testable reframing of plasticity theory.)*
- **A4** [conjectured] The ESS price p̄ is weighted by W, which is dominated where λ_P is huge: suppressed juveniles near compensation. EEO prices calibrated on adults (eddy covariance, gas exchange) are biased in a direction computable from the tape. *(from adjoint; It links EEO calibration error to the front (E4) and is falsifiable.)*
- **A5** [derived (diagnostic design)] The elasticity d ln R′/d ln P has a density with channels (storage charge, growth, fecundity, reserve mortality −v∂μ/∂r). One kept sweep says whether the 7.6e3 is carried by few cohorts in the mortality channel (a structural cliff) or spread across long suppression (compounding). *(from adjoint; It is the direct diagnostic for the front hypothesis, and complements the ε test.)*
- **A6** [derived in theory.md F.4; untested] At λ_o = 0, g_{λ_o} = 0 at interior operating points for every θ and field, while dF/dλ_o from the kept sweep is the commons price of the water floor. *(from adjoint (restating theory.md F.4); It is a cheap, sharp check that the cut is complete for the leaf's control channel.)*
- **I1** [derived (Afriat/Rockafellar; LP duality: Shapley-Shubik)] If each site's resident is the best response among observed strategies, every cycle sum Σ_k [T_{s_k,s_{k+1}} − T_{s_k,s_k}] ≤ 0. The sums are invariant to every strategy and site main effect (α_j + β_s), and no misspecified trade-off can create a violation. *(from imports; It is the first site test immune both to the trade-off problem and to break-even fragility of levels.)*
- **I2** [derived (Rockafellar 1966)] First-order form: Σ_k ⟨σ_k, y_{k+1} − y_k⟩ ≤ 0 on all cycles iff the pairs (y_s, σ_s) lie in the graph of ∂Ψ for a convex Ψ. It needs only P1 and P3 per site. Afriat potentials recover the frontier Â(σ) up to a constant, from where strategies live. *(from imports; Calibration of the frontier's shape without physiology or levels, valid on history rows.)*
- **I3** [checked on a case (numerical; Bartz et al. 2007 for the rotation result)] Pairwise sympatric-allopatric contrasts see only the symmetric part of the site-to-niche map. A skew (curl) ratio b is invisible to every cycle shorter than π/arctan b. Lag τ around a field loop at frequency ω gives skew ratio ωτ. *(from imports; Reciprocal transplants are structurally blind to rotational lag, as on drought, dieback and recovery loops; 3+-cycles detect it.)*
- **I4** [checked on a case (worked 3-site example)] A raw transplant table can pass every pairwise contrast and still fail a 3-cycle: a rotation of provenances improves total fitness. *(from imports; It applies to existing reciprocal-transplant and provenance data without our model: a free contribution to the 'is local best?' debate.)*
- **I5** [derived (Le Chatelier checked on random cases; the reversal is conjectured in general)] Le Chatelier ladder: in field coordinates the response curvature is ordered plastic ⪯ intraspecific ⪯ turnover (a Schur-complement gap). Response conservation says trait response to supply shrinks with richness, so the field-coordinate and supply-coordinate responses run in opposite directions. *(from imports; It predicts that trait-field correlations exceed trait-climate correlations, increasingly with richness, which may explain the weak global trait-climate relations.)*
- **I6** [derived] Reciprocity: the model predicts ∇²Ψ = −GᵀH⁻¹G, symmetric. How much more light-sensitive the favoured strategy becomes as soil dries equals how much more water-sensitive it becomes as the canopy opens. *(from imports; It is a parameter-free falsifiable prediction across 2-D field gradients, and a check of P7.)*
- **I7** [derived] Direction-only (GARP-type) variant: if break-even amplification scales σ_s by a positive κ_s, Afriat's inequalities with free multipliers use only the directions of S. *(from imports; It makes site tests robust to the front's gain (E5) without resolving it.)*
- **I8** [derived (Brenier, McCann, Gangbo; ecological use apparently new)] Assignment from marginals: optimal species-to-site assignment is the optimal-transport coupling for surplus φ(θ; y), unique under the twist condition (distinct strategies have distinct sensitivities: Meszéna's sensitivity half). Finite selection gives the entropic (Sinkhorn) form, which is CATS with multipliers identified as field coordinates. *(from imports; Who lives where is predicted from the landscape's field distribution and the pool's niche distribution alone.)*
- **D1** [derived (largely already in field-cut.md §9.4-9.5 and O4)] Under affine sensing, g = g₀(θ) + G(θ)y. Selection in null(Gᵀ) is field-independent (an optimisation principle on the fibres of S); frequency dependence lives only in the d-dimensional quotient. *(from eeo-data; EEO is exact in k − d directions and wrong only in d; it refines Metz-Mylius-Diekmann to any d.)*
- **D2** [derived; checked on a hand case] The field of adaptation ŷ_i = y_s − G_i⁺ g_is comes from one sweep at any site. Three tests need no equilibrium: T1 (gradient in null(G_iᵀ) vanishes), T2 (ŷ_i is site-invariant), T3 (persistence). *(from eeo-data; Closed-form inverse optimisation per species: a lag vector in mechanistic field modes.)*
- **D3** [known in substance (Chesson; LV time averages); toy checked] Averaging lemma: under affine sensing and bounded log densities, ȳ (the time-averaged field) satisfies the static non-invadability conditions to O(B/Γ + ε_aff). Fluctuations enter only through a Jensen term ½tr(∂²_yy φ Cov y) (relative nonlinearity) and an S(x)-covariance term (the storage effect). *(from eeo-data; It licenses equilibrium geometry on history rows. It also says fluctuation coexistence needs non-affine sensing, which the front (E7) supplies on closed canopies.)*
- **D4** [conjectured (framework)] Four clocks for one latent field: y_rec (weather and community now), y_bal (composition, ecological clock), ŷ_i (traits, evolutionary clock), y_leaf (acclimated physiology prices, instantaneous). Their pairwise gaps separate ecological lag, evolutionary lag, constraint and model error. *(from eeo-data; Climatic debt becomes a d-vector, separable from evolutionary lag.)*
- **D5** [derived] The relative-abundance identity p_i ∝ p_i(0) exp(Γa_i + ⟨S_i, Y⟩) is a latent-factor JSDM with mechanistic loadings S_i and latent site factor Y, the community-made field. *(from eeo-data; It answers the JSDM debate ('interactions or missing environment?'): latent factors are the made field, with loadings predicted from traits.)*
- **D6** [derived (moving-optimum theory, Lynch & Lande, moved to field space)] Linearised trait tracking is a matrix low-pass filter, δθ(t) = ∫exp(kMH(t−τ)) kMG δy(τ)dτ, with spatial weights from reproductive value (source-sink). *(from eeo-data; It predicts each species' lag direction and size from the record's field history; it pairs with the curl signature (I3).)*
- **F1** [measured (field-dimension-066)] Closed-canopy secants are strongly nonlinear (second difference / slope 0.35-0.56). Traits explain only 36% of closed mode-1 pool loadings, against 84% open. The open pairs' A is near rank one (λ_min(A_s) ≈ 0); the closed pair's λ_min(A_s) = 0.104 with skew 0.048. *(from spikes (measured); These are the data the front (E7: loadings are a step in Δℓ_c) and the tournament (M2-M3: rank one when L(a) profiles coincide) must explain.)*

## Development briefs

### The compensation front as a free boundary: is closed-canopy selection set by ecology or by a regulariser?

- Atoms: E1, E2, E3, E4, E5, E6, E7, E8, E10, E11, A4, A5, M5, X1
- Sources: ecology, adjoint, mathematics
- Question: Develop the thinning-front theory into a self-contained reduced model, and say exactly when the knife edge is ecological.

A size × patch-age stand with reserve-buffered, carbon-switched mortality and Beer-Lambert light. Replace TF24's absolute regulariser ε with an explicit within-cohort spread of production w: the hazard averaged over individual P ~ N(P_c, w²). Then ask:
1. Does self-thinning generically pin the subordinate layer to the compensation front (Lemma 1)?
2. How does the held-field gain scale with w, D and f?
3. Does the field-responding derivative cancel it (Lemma 3)?
4. What is the ESS structure (step PIP, lexicographic kink) as w moves from the regulariser scale to an ecological scale?
5. What does the front do to coexistence once read through the tournament matrix: when does a front give δ > 0 (self-limitation), and when does it give Π → 11ᵀ (exclusion by Huisman-Weissing's critical light)?
- Approach: 1. **Free-boundary formulation.** Write the subordinate layer as a free-boundary problem: the front Γ is where P(h, L̄(h, a)) = 0, and the thinning flux κ(a) is set by the canopy's growth. Derive P_front = μ̂_w⁻¹(κ) with the w-smoothed hazard, and show the window κ ∈ (d_I, a_dG1) maps to |P_front| ≲ w.
2. **Gain asymptotics.** Use the coarea formula. Then derive the cut/kept cancellation properly: linearise the front's displacement and show ⟨S, ∂𝓔/∂δ⟩ = −∂φ/∂δ|_E + O(1), stating the remainder.
3. **Coexistence through Π.** Map the result onto the mathematics proposal's Π: compute δ_i and Π_ij when U_i is concentrated on Γ_i. Derive the condition (fronts at distinct heights or patch ages) under which two bank recruiters coexist, and the claim that one open and one bank recruiter coexist robustly.
4. **EEO reweighted.** Use the adjoint proposal's λ_P channel decomposition: the evolved leaf is the minimiser of compensation light at the front, not the maximiser of mean carbon gain.
5. **Ground in the code.** The FF16 hazard a_dG1·exp(−a_dG2·P/area) is the smooth-w limit with an ecological width; TF24's `storage_prod_eps` = 1e-4 kg/yr is the singular limit. Predict quantitatively what three TF24 sweeps should show: ∂ln R′/∂ln ε, the cut against kept in leaf production, and the λ_P channel split.

**Hardest step:** Lemma 3's cancellation beyond leading order, with non-quasi-static reserves (when the relaxation time S_max/(charge + drain) is comparable to the dwell D).
- Compelling if: Any of three results would make this a genuine needle:
- **Universality.** A clean theorem: in any size-structured light model where thinning acts through carbon-balance mortality, the subordinate layer sits within O(w) of compensation, the held-field gain scales as D·f·P̄/w, and the stand derivative stays O(1). That would make 'selection resolution set by individual variation' universal.
- **A sharp prediction for the existing runs.** The ε-dependence on TF24 (halving ε doubles the closed gain and leaves the open gain at about 49), plus an FF16 contrast. That would show whether the 7.6e3 knife edge is ecology or artefact, which decides how O1, O3, O6 and O7 must be computed.
- **Fronts as a counted regulating factor.** Coexistence of bank recruiters requires distinct fronts, giving a count of light's regulating dimensions from the thinning history, with a field test: understorey light equals the dominant species' compensation light; fertilisation raises mortality, not understorey light.

### Where forest light coexistence comes from: a zero-sum tournament, broken by succession, regeneration and fluctuation

- Atoms: M1, M2, M3, M4, M5, M6, M7, M8, X1, E9, D3, F1, A3
- Sources: mathematics, ecology, eeo-data
- Question: Under Beer-Lambert, the direct light kernel at one patch age is a generalised tournament whose symmetric part is rank one when sensing is aligned (May-Leonard neutrality for any n). Then:
- What are all the sources of stabilisation in a size- and patch-age-structured forest, and how big is each on the measured TF24 pairs?
- How do they combine into a count of light-coexisting species?

Specifically:
1. Derive the full decomposition λ_min(A_s) = age-Gram + within-crown δ + between-cohort (front) δ + water + feedback (A^fb) + a fluctuation (Jensen) term from variable rain.
2. Reconcile it with Kohyama's stratification theory: is its coexistence δ or A^fb?
3. Turn the EEO-coexistence crossover (optimal acclimation drives δ < 0 and erodes coexistence) into a sharp, quantitative prediction.
- Approach: 1. **Extend the exact identity beyond the direct kernel.** Write A = A⁰ + A^fb, with A^fb as a causal series in patch age (shading through changed growth). Ask whether A^fb has a sign structure; for example, is it triangular in age, and so in the skew part only?
2. **Fronts.** Bring in the ecology proposal's front: model U_i as a mixture of a crown component and a front ridge. Derive δ_i and Π_ij in closed form for two species whose canopies and fronts sit at given heights and ages, which recovers 'one bank species per front' as Π → 11ᵀ.
3. **Fluctuation.** Use eeo-data's averaging lemma, but where sensing is not affine: the front's step makes ∂²φ/∂y² large along the front-light direction. So rain-driven fluctuation of the front light gives relative nonlinearity. Ask whether it adds a positive term to the symmetric part (fluctuation-dependent stabilisation), and with what scaling in Var(front light) and w.
4. **Check against measurements.** The open pairs' near-rank-one A should equal ½·Gram of nearly collinear L(a) profiles with δ < 0. The closed pair's 0.104 should split into the age Gram, a positive front δ, and water.
5. **Toy model.** Build a three-species toy with Efron-type multimodal profiles (sapling bank plus canopy) to show size-structured intransitivity, and decide whether it damps.

**Hardest step:** making the Gram form (5) hold without separable per-leaf elasticity ρ_i(a) = ρ_i τ(a), and handling u < 0 from water coupling (Π as a signed measure).
- Compelling if: The result would be a single, general statement: in Beer-Lambert forests, light alone is a zero-sum game within a patch age. Its stabilisation is exactly ½·Gram(leaf-area trajectories over succession) plus the elasticity offsets of advance regeneration, plus a fluctuation term that is nonzero only through the compensation front.

It becomes compelling if:
- the decomposition, computed from the cut and kept sweeps, reproduces the measured A on both stands;
- it predicts that pairs sharing an age profile cannot be stabilised by light;
- it yields the acclimation-erodes-diversity prediction with a magnitude.

That would replace the crown-depth story in assembly-geometry §3, and give a mechanistic origin for Hubbell's zero-sum assumption together with its precise breaking terms.

### Inverse optimality across a landscape: level-free, trade-off-free tests of selection, lag and price at observed sites

- Atoms: I1, I2, I3, I4, I5, I6, I7, I8, D2, D4, D5, D6, A1, A2, A3, A4, E6, F1
- Sources: imports, eeo-data, adjoint
- Question: Build the site-level theory that the history-row workflow lacks: what can be identified about selection, lag, constraint and EEO prices from observed communities at real sites under their own weather, without equilibrium, without a trade-off function, and without trusting fitness levels?

Unify four pieces:
- the global, discrete tests (cyclical monotonicity, curl, money-pump; imports);
- the local closed-form inverse (ŷ_i = y_s − G_i⁺g_is with T1/T2; eeo-data);
- endogenous leaf prices as the fourth, instantaneous clock (p* = λ_q/λ_P, privacy ŝ, the stage-weighting bias; adjoint);
- the Le Chatelier ladder against response conservation (field against supply coordinates).

State what each test identifies, what it is immune to, and how it behaves where sensing is non-affine (closed canopies, the compensation front).
- Approach: 1. **Unify the two inverses.** Show that ŷ_i is the local (differential) form of the Afriat potential, so that T2's site-invariance and the cycle conditions are the infinitesimal and global versions of one integrability condition. Curl in the site-to-niche map is then a skew part of −GᵀH⁻¹G estimated across sites. eeo-data's lag filter (D6) predicts its size, tan φ = ωτ, from the record's field loop.
2. **Robustness to amplification.** Use the GARP free-multiplier form (I7) to absorb the front's positive scalar amplification κ_s. Show which conclusions survive when S is dominated by one hypersensitive cohort.
3. **The price clock.** Make y_leaf concrete through the adjoint proposal's endogenous prices: the RV-weighted p̄ is what the leaf's fitted parameters estimate. The adult-against-W-weighted bias and the privacy estimand ŝ become extra rows of the diagnostic ladder.
4. **The Le Chatelier reversal.** Prove it in general: in held fields the response grows with margins (plastic ⪯ intraspecific ⪯ turnover); in supply coordinates it shrinks as rank d − m. State the joint prediction for trait-field against trait-climate slopes as a function of richness.
5. **What the existing data already answer.** Spell out what is testable on raw reciprocal-transplant and provenance tables without the model (3-cycles), and design the minimal set of sites, arranged around a field loop rather than along a line, that gives power to detect curl at a given lag.

**Hardest step:** identification when G is ill-conditioned (near-neutral hydraulic traits) and sensing is non-affine (closed canopies). It needs a statement of which directions remain identified and with what certified error (P8).
- Compelling if: A unified identification theorem would settle it: from one recording plus one cut sweep per site, the cycle, curl, T1/T2 and price tests jointly separate five things (trade-off misspecification, ecological lag, evolutionary lag as a direction in field modes, constraint, and model sensing error), each with a stated invariance.

It becomes compelling if it also delivers:
- at least one prediction checkable on existing data (provenance trials passing all pairwise contrasts but failing 3-cycles on looped field histories; or trait-field slopes exceeding trait-climate slopes, increasingly with richness);
- one on TF24 (reciprocity of −GᵀH⁻¹G; site-invariance of ŷ for the lma-0.32 resident across the long-drought and seasonal stands).

That would give site selection a foundation that does not depend on the trade-off or on balancing b, the two weaknesses site-selection.md §1 identifies.
