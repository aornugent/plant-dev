# Endogenous prices: eco-evolutionary optimality as the Hamiltonian of adaptive dynamics

## 1. Headline

Every EEO rule in vegetation science maximises the same thing at each instant: Pontryagin's Hamiltonian, with the costates frozen into exogenous "unit costs". That covers profit maximisation, least-cost, Cowan–Farquhar's λ, the P-model's β and TF24's own λ_o. The invader's costates in the community's field are the evolutionarily correct prices, and the field cut is exactly the operator that sets to zero the price of every consequence passing through a shared resource. What we get from this is concrete. EEO cost parameters become outputs of the community, resolved by height × patch age × time. Each parameter splits into a private part, a commons part, and a part weighted by privacy (relatedness). And the error of any fixed-price EEO rule splits exactly into an RV-weighted bias, which is selection on the parameter, and an RV-weighted variance, which is the value of plasticity.

## 2. The departure

**The canonical assumption being dropped: EEO prices are parameters.**
- **The EEO models fix the exchange rates.** Cowan–Farquhar fixes λ = ∂A/∂E. The P-model and least-cost fix β, the ratio of carboxylation to transpiration costs. Profit maximisation fixes a hydraulic cost scale. TF24 carries `TF24_cost_scale` and `TF24_floor_lambda_o` (`plant/inst/include/plant/models/tf24_strategy.h`, around line 130).
- **Prices are then fitted to flux data,** or argued from first principles, and taken as constant in time, size and competitive context.
- **The EEO literature knows the prices are "really" costates.** Mäkelä et al. 1996 and Manzoni et al. 2013 read λ as the costate of soil water in single-plant optimal control. Bloom, Chapin & Mooney 1985 gave the economic analogy.
- **But it has had no way to compute costates of a plant living in a structured, competitive, weather-forced community.** So it stops at "λ should depend on soil water and rain statistics".

**AD's side of the gap:**
- **Metz, Staňková & Johansson (2016)** proved that g = 0 in state-variable life-history models is Pontryagin's local maximum principle. That is the bridge in a given environment.
- **AD then treats the Hamiltonian as a proof device,** not an observable. Nobody turns it around and uses the invader's costates to price the inner optimisations that vegetation models nest inside their demography.

**Why it was walked past:**
- To make the bridge operational you need three things together:
  1. costates of a mechanistic, size- and patch-age-structured community;
  2. a clean separation of private consequences from field-mediated ones;
  3. an inner EEO module that is itself differentiable.
- Toy models have only (2); forward simulators (ED2, LPJ, CLM with the P-model) have none of them.
- TF24 is unusual because it nests a genuine EEO solve (the profit-maximising leaf) inside demography, on a tape.

## 3. The formulation

**Notation.** Notation is that of `docs/review/process.md` where it applies.
- Cohort c of the invader θ′ has:
  - weight w_c (introduction quadrature × patch-age density);
  - state x_c(t) ∈ ℝ⁴ (height, heartwood area, heartwood mass, storage);
  - survival ℓ_c = e^{−M_c};
  - local environment e_c(t) = e(x_c, t; E): crown-mean light L̄ and ψ by layer, plus climate.
- At each rate evaluation an inner control u_c(t) is chosen. In TF24 this is the root-collar potential, or equivalently stomatal aperture.
- The rates are ẋ = f(x, u, e), mortality μ(x, u, e) and fecundity r(x, u, e). Then

  R′ = Σ_c w_c ∫ ℓ_c r dt,   φ = ln R′.

### 3.1 Costates are on the tape

The value of an individual is v_c(t) = ℓ_c(t)⁻¹ ∫_t^∞ ℓ_c r ds (expected future seeds). Its state costate is λ_c = ∂v_c/∂x. Seed the sweep with R′. Then the adjoints the tape holds are:
- w_c on the fecundity accumulator;
- −w_c ℓ_c v_c on cumulative mortality;
- w_c ℓ_c λ_c on x_c.

So v and λ are read off adjoints that P6 (invader) or P3 (cut) already computes. The Hamiltonian is

  𝓗(x, u, e; λ, v) = r + λ·f − v μ,

with the costate equation −(d/dt)(ℓλ) = ℓ ∂_x𝓗. For any perturbation of the control,

  δφ/δu_c(t) = (w_c ℓ_c(t)/R′) ∂_u𝓗.     (1)

This is the local maximum principle in held-field form (Metz et al. 2016).

### 3.2 EEO as a frozen-price Hamiltonian

**The structure of the inner choice.** Suppose u acts on the plant through two channels:
- production P(u), the carbon currency;
- K side effects q_k(u). Each is a "good" with a sign convention: water retained, conductance kept, and so on.

**The EEO inner problem** is

  u* = argmax_u π(u; p),  π = P(u) + Σ_k p_k q_k(u),

with p fixed. Define:
- the value of production now: λ_P := ∂𝓗/∂P;
- the value of each side effect: λ_{q_k} := ∂𝓗/∂q_k.

**Definition (endogenous price).** p*_k(c, t) := λ_{q_k}/λ_P.

Substituting the inner first-order condition P′ = −Σ p_k q_k′ gives

  ∂_u𝓗 |_{u*} = λ_P Σ_k (p*_k − p_k) q_k′(u*).     (2)

**Result 1 (myopia is exact iff prices match).** A frozen-price inner optimisation is fitness-optimal at (c, t) iff p = p*(c, t) on the span of q′. EEO is Pontryagin with the costate ratios held constant. Every EEO "unit cost" therefore names a ratio of reproductive values.

### 3.3 The field cut is the price operator

**Kept and cut prices.** For a resident i, the kept sweep (P2) gives each cohort's control an extra channel: its contribution to the field. Write μ_i^E for the kept adjoint at field nodes. Then the kept Hamiltonian is

  𝓗̃ = 𝓗 + ⟨μ_i^E, ∂E/∂u_c⟩.

So a side effect q_k^E that acts on the plant only through the shared field gets two prices:
- kept: p̃*_k = ⟨μ_i^E, ∂E/∂q_k⟩/λ_P;
- cut: p*_k = 0.

The cut zeroes exactly those adjoints (`field-cut.md` §2). Define the **commons price** as Δp_k := p̃*_k − p*_k.

**Result 2 (shared consequences have zero ESS price).** In the rare-invader limit, which is the definition of invasion fitness, every consequence of a control that acts only through the shared field has zero evolutionarily correct price. Its cooperative price is the kept costate ratio. One recording and two sweeps give both, for every cohort, state, age and day.

**Result 2′ (privacy interpolation).** Suppose a fraction s of the field change a focal individual makes falls on carriers of its type. That covers local competition, clonality, exclusive root zones, and monodominance at the scale of competition. The Taylor–Frank direct-fitness gradient is then

  g(s) = g + s (F_θ − g),  p(s) = p*_cut + s Δp.     (3)

Kept and cut are its two endpoints, and process.md's commons F_θ − g is the price of privacy.

### 3.4 Fixed prices, bias and variance

**The selection gradient on a fixed price.** Let p be a heritable constant, a trait, while p*(c, t) varies along lives and weather. From (1) and (2), in the scalar case,

  g_p = R′⁻¹ Σ_c ∫ W_c(t) (p*_c(t) − p) dt,  W_c = w_c ℓ_c λ_P ∂q*/∂p ≥ 0,     (4)

with ∂q*/∂p = (q′)²/(−π_uu) ≥ 0 for concave π.

**Result 3.** The held-field best price is p̄ = ⟨p*⟩_W, the average of the endogenous price weighted by reproductive value and responsiveness. At an ESS this is the price in the corridor field E*. Under frequency dependence it is the invader's p*, not the stand's.

**The regret.** To second order, the held-field fitness that perfect plasticity would gain, the "Hamiltonian regret", is

  Δφ_plastic = (2R′)⁻¹ Σ_c ∫ W (p* − p)² dt = ½ 𝒲 [ (p̄ − p)² + Var_W(p*) ],     (5)

with 𝒲 = ΣW/R′. The first term is (g_p)²/(2·curvature), selection on the parameter. The second term remains at the optimum: it is the irreducible cost of a fixed-price rule. Its density ρ_c(t) = ½ W_c (p*_c − p̄)² says where in height × patch age × time optimality with fixed parameters fails.

## 4. The ecology

**1. EEO and frequency dependence are reconciled by a price rule, not a new model.**
- The EEO component of a vegetation model is right exactly when its prices are the invader's costate ratios, averaged with weights W along the life.
- Frequency dependence enters only through E* in λ and W.
- That is the content of `field-cut.md` §9.4–9.5. The slaved traits w*(u; E) are price-matching conditions, ⟨p*⟩_W = p, along the corridor u.

**2. Water saving under competition is an index of privacy, not of climate.**
- Result 2 recovers, as one case of a general operator, the known toy result: Cowan–Farquhar saving is not evolutionarily stable under shared water (Cowan 1986; Wolf, Anderegg & Pacala 2016; Farrior et al. 2015).
- The new part is (3). An observed marginal water cost estimates privacy:

  ŝ = λ_obs / Δp_water,

  where Δp_water is the kept costate of soil water per unit of carbon value at the site. The kept sweep on the history row computes it (O10). No equilibrium is needed.
- Predictions:
  - ŝ should be high for isolated shrubs with exclusive root volumes and in monodominant or clonal stands;
  - ŝ should be near zero in dense mixed stands;
  - Medlyn's g1 ∝ √λ should therefore covary with stand structure after climate is removed (compare Lin et al. 2015).

**3. EEO traits are set by the life stage that carries the weight, not the one that is measured.**
- p̄ is weighted by W = w ℓ λ_P ∂q*/∂p.
- Under a closed canopy, λ_P is enormous in suppressed juveniles: carbon is precious near compensation, as the measured d ln R′/d ln P ≈ 7.6e3 shows.
- So the evolutionarily stable leaf price is set by saplings at the gap transition. Eddy-covariance and leaf-gas-exchange calibrations measure adults.
- Prediction: calibrated EEO prices are biased in a known direction. The bias is computable as the difference between the adult-weighted and the W-weighted mean of p*.

**4. Plasticity is selected where the price varies, not where the environment varies.**
- By (5), selection for a plastic price is ½ 𝒲 Var_W(p*).
- Environmental variance that does not move the costate ratio, or that falls where W is small, buys no plasticity.
- Prediction: acclimation and ontogenetic shifts in a trait should track the RV-weighted variance of its endogenous price across the record. LMA and stomatal sensitivity rising with height would be price trajectories, not adaptations to the adult's environment.

**5. The commons of every trait at once.**
- Δp is the tragedy of the commons priced in reproductive value, available for every EEO price simultaneously: water, leaf area and shading, rooting.
- The difference between the group-optimal and the ESS operating point (Anten 2005; Schieving & Poorter 1999; Zea-Cabrera et al. 2006) becomes a field over (h, a, t) instead of a scalar.

**6. A diagnostic for the break-even sensitivity.**
- The elasticity d ln R′/d ln P = R′⁻¹ Σ ∫ w ℓ λ_P P dt has a density.
- λ_P decomposes into channels: storage charge, growth, fecundity, and reserve-driven mortality (−v ∂μ/∂r, with a_dG2 = 20).
- Two possible readings:
  - if the 7.6e3 is carried by a few cohorts in the mortality channel near empty storage, it is a structural cliff of the reserve-mortality law;
  - if it is spread across long suppression, it is a genuine compounding of carbon prices.
- One kept sweep decides between them.

## 5. Why us

- **Costates per cohort, state and age** (§3.1). These are the adjoints of the fecundity accumulator, cumulative mortality and the states on P3 and P6. Toy models have them analytically only for one or two states. IPMs and simulators have no adjoint.
- **Endogenous prices are ratios of adjoints already on the tape.** In TF24 the leaf's outputs `leaf_profit_` and `leaf_soil_consumption_[j]` are tape nodes (`tf24_strategy.h`, around lines 1826–1842). The ratio adj(soil_consumption_j)/adj(profit) at a rate evaluation is p*_water,j(c, t). Nobody else's inner EEO sits on a tape.
- **The cut and kept sweeps give the private and commons prices** bit for bit from one recording. This is the s = 0 and s = 1 pair of (3), with nothing finite-differenced.
- **A differentiable inner optimum.** The leaf's profit is "built by the envelope theorem", and the collar's move is carried implicitly. So ∂q*/∂p, and with it W, comes from the same sweep.
- **Real weather and history rows.** p*(c, t) varies by drought and by day, and is defined on observed sites without equilibrium. That is exactly where flux-calibrated EEO parameters live, so we can confront fitted prices with computed ones.

## 6. Prior art and the exact delta

| Work | What it established | What it leaves for us |
|---|---|---|
| Metz, Staňková & Johansson 2016 (*J. Math. Biol.* 72: 1125) | g = 0 ⇔ marginal-value principle ⇔ Pontryagin, in a given environment | No inner EEO sub-model priced by it, no split of private from field-mediated consequences, no regret decomposition, no computation in a mechanistic community |
| Iwasa & Roughgarden 1984; Mäkelä et al. 1996; Manzoni et al. 2013; Buckley, Sack & Farquhar 2017 | Allocation and stomatal prices as costates, single plant, analytic | Single plant only: no competition, no community field |
| Cowan 1986; Wolf, Anderegg & Pacala 2016; Farrior et al. 2015; Dybzinski et al. 2011 | Carbon maximisation is the ESS under shared water; ESS allocation in PPA models | Result 2 for water is known qualitatively. New: the general operator, the privacy estimand ŝ, and the life-stage weighting |
| Feichtinger et al. 2011 (*Demographic Research*) | Reproductive value as a shadow price in age-structured control | No community or EEO application |
| Taylor & Frank 1996 | Direct-fitness gradients with relatedness | Not previously identified with the kept and cut sweeps |
| Plant-FATE (Joshi, Dieckmann, Prentice et al.) | EEO acclimation (P-hydro) inside a trait-size-structured demographic model, with trait evolution | The closest system. Its EEO costs are exogenous; they are not derived from, or checked against, the community's costates |
| Harrison et al. 2021; Franklin et al. 2020 | Reviews calling for EEO in land models | Name the cost-parameter problem without this resolution |

**Delta.** Results 1–3 and equation (5) as a single theory of EEO parameters:
- endogenous, RV-weighted prices;
- the cut as the price operator;
- the privacy interpolation;
- the bias–variance split of EEO regret;
- the stage-weighting bias of calibration.

All of it is computable in a mechanistic forest model. I found nothing that does this. The Pontryagin link and the water toy are known.

## 7. Worked cases

### (a) Shared water, by hand

**Setup.** N plants share a pool NW over two periods, with A(E) = a√E. The focal plant takes e₁ now and gets (NW − e₁ − (N−1)E₁)/N later.

**Results.**
- The first-order condition is A′(e₁) = (1/N) A′(E₂).
- At symmetry, √E₁ = N√E₂, so

  E₁ = N²W/(1+N²).

  - N = 1: E₁ = W/2, the Cowan–Farquhar constant λ.
  - N → ∞: E₁ → W.
- Endogenous price: λ_ESS = A′(E₁).
- Kept (s = 1) costate of the pool: A′(E₂).
- Their ratio is √(E₂/E₁) = 1/N = s: equation (3) with p*_cut = 0.
- Fitness per plant is a√W (N+1)/√(1+N²). The commons costs 1 − 1/√2 ≈ 29% as N → ∞.

### (b) Bias and variance, by hand

**Setup.** π = −κu²/2 + p u, so u* = p/κ. In season t the true Hamiltonian is W_t(−κu²/2 + p*_t u).

**Results.**
- Fitness ∝ Σ_t W_t (p p*_t − p²/2)/κ, maximised at p = Σ W_t p*_t / Σ W_t.
- Regret is (2κ)⁻¹ Σ W_t (p*_t − p)², which is (5) exactly, not only to second order.

### (c) A sharp, checkable statement on TF24 itself

**The claim.** TF24's leaf maximises profit, and P = profit + λ_o E is the carbon kept (`net_mass_production_dt`, comment at line 151). At λ_o = 0:
- ∂P/∂u = 0 at the interior optimum;
- ∂P/∂λ_o at fixed u = −E + E = 0.

So dP/dλ_o = 0 at every rate evaluation of every cohort. The aperture's only other consequence, soil consumption by layer, enters the soil water field and nothing private. Hence:
- **g_{λ_o} = 0 at λ_o = 0, for every θ, every field and every record,** to the solve's tolerance, wherever the operating point is interior;
- **H_{λ_oλ_o} < 0,** since P(u*(λ_o)) ≤ P(u*(0)). So λ_o = 0 is a held-field maximum in every field, an optimisation-principle direction in the sense of Metz, Mylius & Diekmann 2008;
- **dF_i/dλ_o from the kept sweep is generally nonzero,** and equals ⟨S_i, ∂𝓔/∂λ_o⟩: the commons price of the floor.

**What this answers.** The code asks "is TF24 missing a price of water?". In the mean field, no: zero is the ESS. A nonzero λ_o needs privacy (s > 0) or a private water state.

**The check costs one P6 sweep and one P2 sweep at the field-dimension stand.** A failure would locate a private channel the analysis missed.

## 8. What it opens

**First steps, in order:**
1. **Case (c):** g_{λ_o} from the cut against dF/dλ_o from the kept sweep, on the long-drought and closed stands of `spikes/field-dimension-066/`.
2. **Price fields.** Read adj(soil_consumption_j)/adj(profit) and the state costates per cohort and step from one kept sweep and one cut sweep. Map p*_water(h, a, t) and the commons Δp on a drought record.
3. **The break-even diagnosis** (§4.6): the λ_P channel decomposition on the closed canopy.
4. **A private water state** (plant capacitance, or a per-individual rhizosphere pool) in a toy and then TF24f. Test Result 3: does the evolved λ_o equal ⟨λ_capacitance/λ_P⟩_W?
5. **Site calibration** (O5) of λ_o or cost_scale on history rows, then ŝ = λ̂_o/Δp_water per site. Regress ŝ on stand density and on the dominant species' share of basal area.

**Links to the existing documents:**
- O4's EEO-inefficiency bracket A(σ) − a(θ) is the integrated bias term of (5) for the slaved traits.
- `assembly-mfg.md` §4.1's "relaxation gap" of the flexible policy is, to first order, ½ 𝒲 Var_W(p*). Computing it with the exact model tells whether the dynamic-programming bound will be tight before building it.
- O10's rain prices are field-node adjoints. This idea is their counterpart at the control nodes.

**Testable predictions:**
- an observed marginal water cost scales with privacy (ŝ), not with aridity alone;
- calibrated EEO prices are biased toward adult values in the sign set by p̄_W − p̄_adult;
- plasticity scales with Var_W(p*);
- λ_o = 0 is convergence stable in TF24, by J = H + G dE*/dθ as in O8.

## 9. Where it might break

- **Interior optima.** Equation (2) needs an interior inner solve and a smooth π. At bracket bounds or in the refusal states (`operating_point_kind`), the envelope fails, and so do prices.
- **A local principle only.** The Hamiltonian may be non-concave in u under hydraulic cliffs, so global plastic gains can exceed (5).
- **The rare-invader mean field (s = 0) is a modelling choice,** and Result 2 inherits it. Equation (3) is first order and needs a spatial model to justify s beyond a heuristic.
- **The kept costate is not only conspecific.** For F_i, μ^E includes other species' responses, so Δp is the commons for species i, not for the stand.
- **History rows have a finite horizon.** Costates near the end of the record are truncated, so prices there need a terminal value (for example v from a regime run).
- **Separability.** The split into P and q_k assumes every control-dependent consequence is either production, a named private good, or field-mediated. Leaf temperature, or a cost on Θ~ that is not realised carbon, would add a channel.
- **Numerics.** Prices are ratios of adjoints, so a cohort with λ_P ≈ 0 (dead or doomed) gives unstable p*. The weights W suppress it, but maps should show p* only where W is non-negligible. The closed canopy's extreme sensitivity may also turn the regret density into noise unless the schedule is certified for these quantities.

**Sources:**
- [Metz, Staňková & Johansson 2016, PMC4751216](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4751216/) (and [IIASA IR-12-054](https://pure.iiasa.ac.at/10221/1/IR-12-054.pdf))
- [Wolf, Anderegg & Pacala 2016, PNAS (PMC5135368)](https://pmc.ncbi.nlm.nih.gov/articles/PMC5135368)
- [Manzoni et al. 2013](https://nicholas.duke.edu/people/faculty/katul/AWR_Manzoni_2013.pdf)
- [Manzoni et al. 2011](https://collaborate.princeton.edu/en/publications/optimizing-stomatal-conductance-for-maximum-carbon-gain-under-wat/)
- [Buckley, Sack & Farquhar 2017](https://researchportalplus.anu.edu.au/en/publications/optimal-plant-water-economy/)
- [Feichtinger et al. 2011, Demographic Research](https://www.demographic-research.org/volumes/vol24/28)
- [Farrior et al. 2015 (listing)](https://slevin.princeton.edu/publications/contributor/farrior-caroline)
- [Plant-FATE project](https://iiasa.ac.at/projects/plant-fate) and [IIASA model page](https://iiasa.ac.at/models-tools-data/plantfate)
- [Harrison et al. 2021, EEO in land-surface models](https://gotriple.eu/documents/10670%2F1.96uusf)

Several other references are cited from memory and are unchecked: Cowan 1986; Iwasa & Roughgarden 1984; Mäkelä et al. 1996; Taylor & Frank 1996; Anten 2005; Schieving & Poorter 1999; Zea-Cabrera et al. 2006; Bloom, Chapin & Mooney 1985; Lin et al. 2015; Dybzinski et al. 2011.

**Files read:**
- `/home/a/dev/plant-dev/.claude/worktrees/workflows/docs/review/process.md`
- `/home/a/dev/plant-dev/.claude/worktrees/workflows/docs/review/assembly-geometry.md`
- `/home/a/dev/plant-dev/.claude/worktrees/workflows/docs/review/assembly-mfg.md`
- `/home/a/dev/plant-dev/.claude/worktrees/workflows/docs/review/field-cut.md`
- `/home/a/dev/plant-dev/.claude/worktrees/workflows/spikes/field-dimension-066/README.md`
- `/home/a/dev/plant-dev/.claude/worktrees/workflows/plant/inst/include/plant/models/tf24_strategy.h`