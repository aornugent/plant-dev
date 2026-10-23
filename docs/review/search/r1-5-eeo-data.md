# The field of adaptation: one field, read through four clocks

## 1. Headline

Measured invader fitness in TF24 is close to affine in a field of low rank. Under that condition, each level of adaptation is a best response to a d-vector of field coordinates. The levels are the leaf's operating point, which species are present, and each species' traits. They differ only in the memory kernel over which they average the field's history. EEO, community assembly and adaptive dynamics then become one optimality condition read at different clocks. A site's weather record, its composition, each species' traits and its leaf physiology are four independent estimates of that field, and they agree only at equilibrium. The differences between them separate ecological lag, evolutionary lag, constraint and model error. Each comparison needs S, G and the costates on the site's real record.

## 2. The departure

The canon has three framings, and none of them takes this route.

- **EEO** optimises traits against the *exogenous* environment (PAR, VPD, CO₂, soil water from climate), with free "price" parameters fitted globally (the P-model's β, Cowan–Farquhar λ).
- **Adaptive dynamics** says the environment is made by the community. Selection is frequency-dependent, and statements hold at equilibrium (Metz–Geritz; Meszéna et al. 2006).
- **Observation-side ecology** measures disequilibrium as a one-dimensional climate index: the climatic debt from community temperature indices (Bertrand et al. 2011, 2016), and composition lag (Svenning & Sandel 2013).

The repo's own process inherits the equilibrium restriction. `process.md` §5 says: "history rows have no equilibrium, so O6–O8 are regime-only".

The departure has two parts.

1. **Equilibrium conditions are not dropped on history rows.** They hold *exactly at a kernel-averaged field* whenever sensing is affine. So the static geometry (𝒩, Ψ, the frontier A(σ)) applies to lagged, fluctuating, real communities. What changes is which field it applies to.
2. **The field is the object to estimate, not the traits.** It is estimated four times, from four data streams with four clocks.

Why this was walked past:
- Theorists have no realistic S(θ) and no affinity measurement, so the averaging condition stayed a curiosity of linear Lotka–Volterra models.
- Empiricists have no mechanistic map from traits to field coordinates, so "disequilibrium" collapsed onto temperature.
- EEO never needed the field to be endogenous, because it fitted the prices.

## 3. The formulation

**Setting.** The notation is `process.md`'s.
- The field is y ∈ ℝᵈ, in shared modes. The exogenous drivers are x(t): VPD, temperature and CO₂, which enter physiology directly.
- **The affine-sensing hypothesis** (measured: 98.7–99.7% of invader variance in 2–4 modes; second differences small on open stands):

  φ(θ; y, x) = a(θ, x) + ⟨S(θ, x), y⟩ + ρ,  |ρ| ≤ ε_aff.  (1)

- Differentiating in θ:

  g(θ; y) = g₀(θ) + G(θ) y,  G = ∂S/∂θ ∈ ℝ^{k×d}  (the G of `process.md`, on modes).  (2)

### 3.1 Selection splits into a field-free part and a field-reading part

Take any u ∈ null(Gᵀ), a trait direction that does not move the niche σ = S(θ). Then

  uᵀ g(θ; y) = uᵀ g₀(θ)  for every field y.  (3)

**Proposition 1 (partial optimisation principle).**
- In the k − d niche-preserving directions, selection is frequency-independent. It is the same at every site, in every community, at every date.
- Its potential is the baseline a(θ) restricted to the fibre S(θ) = σ. That is the frontier A(σ) of `assembly-geometry.md` §4b, now as a gradient condition.
- In the remaining d directions, no environment-free objective exists. Optimisation needs d prices, and those prices are the field.

This refines Metz, Mylius & Diekmann (2008). Their "optimisation principle iff the feedback is one-dimensional" is the case d = 1 applied to the whole trait space. For any d, a principle holds exactly on the fibres of the niche map, and frequency dependence lives on the d-dimensional quotient.

*EEO holds, and maximises a(θ), in k − d directions. It is wrong only in d.*

### 3.2 The field of adaptation

**Definition.** For a species with traits θ_i, the field of adaptation is the field to which θ_i is a best response:

  ŷ_i = −G_i⁺ g₀(θ_i),  where G_i⁺ = (G_iᵀG_i)⁻¹G_iᵀ.  (4)

It cannot be read from g₀ directly, but by (2), one sweep at any site s where the species lives gives it:

  ŷ_i = y_s − G_i⁺ g_is.  (5)

This yields three exact tests, none needing equilibrium:

| test | equation | number of conditions |
|---|---|---|
| (T1) rationalisability | uᵀ g_is = 0 for u ∈ null(G_iᵀ): θ_i is a best response to *some* field | k − d |
| (T2) site invariance | ŷ_i from (5) is the same at every site of the species | d(n_sites − 1) |
| (T3) consistency with persistence | a(θ_i) + ⟨S_i, ŷ_i⟩ ≈ 0 | 1 |

If T1 holds but ŷ_i ≠ y_s, the species is a best response to a field that is not the one it now lives in. That is lag or migration load, and its direction in field space is ŷ_i − y_s.

This is inverse optimisation (Ahuja & Orlin 2001), solved in closed form because sensing is affine.

### 3.3 The averaging lemma: the static conditions hold at time-averaged fields

By (I1), every species, rare or common, grows at φ(θ_i; E) per generation. Over generations γ = 1…Γ, the log density telescopes:

  ln N_i(Γ) − ln N_i(0) = Σ_γ φ_i(y_γ) = Γ [a_i + ⟨S_i, ȳ⟩] + Σ_γ ρ_iγ,  ȳ = Γ⁻¹ Σ_γ y_γ.  (6)

**Proposition 2.** If log densities stay in a band of width B, then:
- every persisting species satisfies |a_i + ⟨S_i, ȳ⟩| ≤ B/Γ + ε_aff;
- every pool species j with initial log rarity ℓ_j satisfies a_j + ⟨S_j, ȳ⟩ ≤ ℓ_j/Γ + ε_aff.

So ȳ ∈ 𝒩, supported by the residents, up to O(1/Γ + ε_aff). The supply may fluctuate and the making map may be nonlinear (Beer–Lambert).
- **The nonlinearity of making** decides *which* ȳ is reached. It does not touch the conditions on it.
- **Fluctuations enter in only two ways:**
  - a Jensen term, ½ tr(∂²_yy φ · Cov y), which is Chesson's relative nonlinearity (scale transition);
  - when x modulates S, a term Σ_γ ⟨S_i(x_γ) − S̄_i, y_γ − ȳ⟩, which is the storage effect.
- **Both are computable on the tape.** The cut gives S over (height × patch age × time). Forward-over-reverse on the held field gives ∂²_yy φ.

Equation (6) is also the replicator–Hedge identity: relative abundance is proportional to p_i(0) exp(Γa_i + ⟨S_i, Y⟩), with Y = Γȳ. That is Shipley's maximum-entropy model (CATS), with the prior p(0), the features (a_i, S_i) and the multipliers Y. It is also a latent-factor joint species distribution model with **fixed, mechanistic loadings S_i and latent site factor Y_s**. The JSDM debate over whether latent factors are "interactions or missing environment" (Blanchet et al. 2020) has an answer here: they are the community-made field, and the model predicts their loadings from traits.

**Traits.** Under the canonical equation dθ_i/dτ = k_i M g(θ_i; y(τ)), linearised about a best response, the deviation follows a matrix low-pass filter:

  δθ_i(t) = ∫ e^{k_i M H_i (t−τ)} k_i M G_i δy(τ) dτ.  (7)

At stationarity, ŷ_i is the kernel-weighted average of y over the trait's memory. Time weights are equal per generation where fluctuations are faster than a sweep. Space weights are offspring production times reproductive value (the source–sink weighting of Holt & Gaines 1992 and Kawecki 1995), and the costates supply those weights.

### 3.4 Four clocks, four estimates of one field

| estimate | data | clock (kernel) | how computed |
|---|---|---|---|
| y_rec(t) | the site's weather record + the observed community | none (current) | P1 resident run, projected on modes |
| y_bal | presence and absence (composition) | ecological: relaxation at λ_min(A_s), generations since arrival | solve a_i + ⟨S_i, y⟩ = 0 over the residents (m ≥ d), with a_j + ⟨S_j, y⟩ < 0 for absentees |
| ŷ_i | each species' traits | evolutionary: e^{kMH t} | (5): P3 sweep plus G from d mode-seeded sweeps or P7 |
| y_leaf | acclimated physiology (χ, stomatal sensitivity, leaf water potential) | instantaneous | the inner leaf optimisation's prices; costate ratio λ_W/μ_C (`theory.md` F.4) |

**The diagnostic ladder:**
- y_rec ≈ y_bal ≈ ŷ_i: equilibrium, read at the field level.
- y_bal ≠ y_rec, with the gap aligned with the trend in the record's field: ecological lag (climatic debt, as a d-vector in mechanistic modes rather than a temperature).
- ŷ_i ≠ y_bal with T1 satisfied: evolutionary lag or migration load. Its direction says which field mode moved, and (7) predicts its size from the record's y(t) history.
- T1 violated: a missing constraint or trade-off (the shadow price sits in null(Gᵀ) and is site-invariant) or model error. Site invariance separates the two: constraint is shared across sites, model error is not structured.
- ŷ_i outside the convex hull of every field the species has met in the record: adapted to a field that predates the record.

The sharpened residual is

  g_is = g₀(θ_i) + G_i y_s.

Regress each species' gradients across its sites on the site fields:
- the slope must equal the model's G_i, which is a parameter-free check;
- the intercept is the constraint;
- the scatter is model error.

This replaces the qualitative four-readings table of `site-selection.md` §2.

## 4. The ecology

- **When EEO works, and what it optimises.** EEO is exact in the k − d niche-preserving directions, where it maximises baseline fitness a. TF24's leaf satisfies Pontryagin with one currency (`theory.md` F.4), so the leaf level is a special case.
  - EEO's fitted price parameters are field coordinates.
  - The empirical finding that the P-model's β must vary with soil moisture (Lavergne et al. 2020; Stocker et al. 2020) is EEO discovering, in effect, an empirical ŷ along the water mode.
  - **Prediction:** at equal climate, a denser or taller stand shifts the prices, because the field is made by the community, and they lag the climate.
- **Why climate explains little of trait variation.** Climate explains about 18% of the main leaf-economics axis (Wright et al. 2005). Exogenous drivers move traits along the null(Gᵀ)-weighted directions. Coexisting species differ along the d endogenous directions, the best-response tangents H⁻¹G. By response conservation, supply moves traits in only d − m directions.
  - **Prediction:** the climate-unexplained, within-site component of trait variation lies in span(H⁻¹G), and the climate-explained component outside it. Both subspaces are computed, not fitted.
- **Fluctuation-dependent coexistence is narrowed.** Under affine sensing, variable weather creates coexistence only through the Jensen and S(x)-covariance terms. H2 ("variability raises the dimension") then predicts *which* of the two carries it, and the tape measures both.
- **Climatic debt becomes a vector, and the slow species are predictable.** The communities that track their field slowest are the weakly stabilised ones (relaxation ~ 1/λ_min(A_s)). So the regime of flat crowns and light limitation (`assembly-geometry.md` §3) should carry the longest compositional memory.
- **Sink populations show up within a site.** Co-occurring species with different ŷ_i are adapted to different fields. The spread of ŷ within a site marks source–sink structure (mass effects): the species far from y_s should track immigration rather than local fitness.

## 5. Why us

- **The field cut** gives S_i for every observed species as a function over height × patch age × soil layer × time, projected on modes, in one sweep. A forward modeller needs d perturbation runs per species, and cannot perturb the field while holding everything else.
- **G** comes from d mode-seeded sweeps or P7. It is a second-order mixed derivative, which finite differences cannot deliver across many traits.
- **The real weather record** gives y_rec(t) over the site's history, which the kernels in (7) filter. Toy models have no record.
- **The costates** give the reproductive-value weights for the spatial and temporal kernels, and λ_W/μ_C for y_leaf.
- **Certified discretisation** turns the ladder's differences into decisions: a gap counts only when it exceeds ε in fitness units.
- **The measured affinity and low rank** are the hypothesis Propositions 1–2 need. They are checked on TF24, not assumed.

## 6. Prior art (searched; the delta is stated)

| prior work | what it has | what is new here |
|---|---|---|
| Chesson (1994, 2000); scale transition (Chesson et al. 2005) | linear, additive growth gives fluctuation-independent coexistence | Proposition 2 is this, in substance. New: applying it to lifetime fitness in a mechanistic field, the mechanistic split of the two correction terms, and using it to license equilibrium geometry on history rows |
| Time averages of Lotka–Volterra and replicator dynamics (Hofbauer & Sigmund 1998); persistence (Schreiber, Benaïm & Atchadé 2011); replicator = multiplicative weights, no-regret, coarse correlated equilibria (Hofbauer, Sorin & Viossat 2009; Mertikopoulos et al. 2018) | the mathematics of time-averaged conditions | the mathematics is known; the use is new |
| Shipley et al. (2006) CATS; JSDMs (Warton et al. 2015; Ovaskainen et al. 2017; Blanchet et al. 2020) | log-linear abundance models with fitted multipliers or loadings | loadings predicted from traits, and factors read as the made field. I found no prior source doing this |
| MacArthur duality (Marsland, Cui & Mehta 2020) | the projection | already used in the repo |
| Rohr & Loeuille (2022) | optimisation conflicts with niche differentiation | consistent with Proposition 1; that paper has no fibre-wise principle and no data test |
| Moving-optimum lag (Lynch & Lande 1993; Lande & Shannon 1996); source–sink niche evolution (Holt & Gaines 1992; Kawecki 1995) | the trait filter (7) and the spatial weighting, in phenotype space | (7) and the weighting in field space, with mechanistic G |
| Climatic debt (Bertrand et al. 2011, 2016) | one-dimensional composition lag | a d-vector, separated from evolutionary lag |
| Inverse optimisation (Ahuja & Orlin 2001); revealed preference (Afriat 1967; Varian 1984) | the inverse step in general | the closed form (5) under affine sensing |

**Honest summary.** Each ingredient exists. I found no work that does the following: treats the field as the common latent of EEO, assembly and evolution; estimates it independently from weather, composition, traits and physiology; and reads lag at each clock from the differences. I also found none of the gradient-level, field-free test of EEO (T1). This was not an exhaustive search.

## 7. Worked cases

**(a) Lag from a direct driver; none from supply** (d = k = 1).
- Model: φ = θy − θ²/2 − α, with making y = K − Nθ. Then g = y − θ, G = 1, and ŷ = θ.
- Balance gives y_bal(θ) = (θ²/2 + α)/θ, which does not depend on K. **A supply trend moves only N: zero selection and zero lag** (response conservation, m = d).
- Let the cost α (respiration, temperature) ramp at rate v. The ESS is θ* = √(2α).
- With the canonical equation dθ/dt = k(y_bal − θ), linearisation gives a relaxation rate of exactly k, so the steady lag is Δθ = v/(kθ*). The residual g = y_rec − ŷ equals that lag.
- Numerically (α₀ = 0.5, v = 0.002, k = 0.05, t = 400), the simulation gives lag 0.02499 against 0.02481 predicted, and g = 0.0252.
- The ladder reads y_rec = y_bal = 1.6127 and ŷ = 1.5875: an ecological equilibrium and an evolutionary lag of 0.025 along the only mode.

**(b) Averaging under fluctuating supply and nonlinear making** (d = 2, 19 strategies).
- Model: S(θ) = (cos πθ/2, sin πθ/2), a = −1. Supply fluctuates with sd about 1.1 per resource, periods 37 and 23 plus noise. The field is clipped at zero, so making is nonlinear.
- Over 4,000 generations, ȳ = (0.704, 0.717). |ȳ| = 1.005 against the static boundary |y| = 1.
- At ȳ, max φ = 0.005, which is O(B/Γ).
- Residents sit at θ ≈ 0.45–0.55, and the best response to ȳ is 0.506.
- The fluctuations created no coexistence beyond the static prediction, as Proposition 2 says for affine sensing.
- Script: `/tmp/fa/toy.R`.

**(c) The field-free test by hand** (k = 3, d = 1).
- Model: S = θ₁, and a = −θ₁²/2 − (θ₂ − θ₁)²/2 − (θ₃ − 2)²/2 − α.
- Then null(Gᵀ) = span(e₂, e₃), and the field-free gradient is (θ₁ − θ₂, 2 − θ₃).
- An observed θ = (1.2, 1.0, 2.3) fails T1 with (0.2, −0.3) at *every* site. Its ŷ = θ₁ − (θ₂ − θ₁) = 1.4 is site-invariant.

## 8. What it opens

**Immediate test with existing runs.**
- The lma-0.32 resident is identical on long drought and seasonal (`spikes/field-dimension-066/`).
- Compute ŷ from (5) on both stands, with g from P3 and G on the 3-mode basis from mode-seeded sweeps. T2 says they must agree to within ε_aff.
- The closed stand, with different traits and new field directions, is the stress case.

**First theoretical step.**
- Bound ε_aff's effect on ŷ: δŷ ≤ ‖G⁺‖ ‖∂_θ ρ‖. This needs ∂²_yy φ by forward-over-reverse on the held field.
- Derive the kernel for composition from the linearised making map and A_s.

**First empirical step.** Three sites along one rainfall gradient, with AusTraits for lma, wood density, height and seed mass (k_m = 4 measured traits). With d ≈ 3:
- one overidentifying T1 condition per species;
- T2 across sites;
- the ladder per site.

**Links.**
- It extends O4: the Fenchel–Young gap is the integrated version of ŷ_i − y_s.
- It supplies site-invariant targets for O5. Calibrating c to make T2 hold avoids the circularity of g = 0 noted in `site-selection.md` §7.
- It moves the equilibrium geometry (O6–O8) onto history rows at ȳ.

**Testable predictions.**
- Trait-variance subspaces align with H⁻¹G.
- EEO prices respond to stand density at fixed climate.
- Compositional lag scales with 1/λ_min(A_s).
- In lagging communities, ŷ moves away from y_rec along the modes the record's trend moved.

## 9. Where it might break

- **Affinity on closed canopies.** Second differences of 0.35–0.56 there mean ρ is not small. Large field excursions (gap formation) need a second-order Jensen correction or a moving linearisation.
- **A shared modal basis across sites.** The closed canopy has field directions that open stands never visit, so ŷ can be outside the basis. Use the anchor atlas basis and report the residual outside it.
- **Conditioning of G.** Near-neutral hydraulic traits make G small, so ŷ is ill-posed in those directions. T1 then becomes trivially satisfied rather than informative.
- **Break-even hypersensitivity.** d ln R′/d ln P up to about 7,600 makes S and g₀ huge near break-even. That is good for identifying y_bal (species as sharp sensors) and bad for ŷ if a and G are both dominated by one hypersensitive cohort.
- **Plasticity.** Observed traits are partly acclimated, so the "trait clock" mixes plastic and heritable parts. Leaf-level traits belong in y_leaf, not ŷ.
- **Generations against the record.** Trees get one to three generations per record, so Γ is small and the B/Γ band in Proposition 2 is wide. Space, through many patches and sites, must substitute for time, with weights from reproductive value.
- **Unmeasured traits at defaults** confine every test to the measured subspace. Identification needs rank(G restricted to measured traits) = d.