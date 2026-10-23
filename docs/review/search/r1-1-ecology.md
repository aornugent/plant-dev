# The thinning front: closed canopies hold their own regeneration at the compensation point

## 1. Headline

In a closed, self-thinning canopy, deaths from exhausted reserves hold the resident's own subordinate cohorts at whole-plant carbon balance. They dwell for decades on a curve in height × patch age, the *compensation front*, where a mortality that switches with reserves makes fitness an occupation functional of a near-zero net carbon flux. At that front, fitness in the held field is extremely sensitive to carbon: a step across the diagonal of the pairwise invasibility plot. In the field-responding stand the same sensitivity almost exactly cancels: the stand moves the front rather than the hazard. An R\*-type optimisation principle (minimise compensation light at the front) takes the place of smooth adaptive dynamics for carbon-balance traits.

## 2. The departure

Canonical adaptive dynamics assumes three things:
- invasion fitness is smooth near the resident, with O(1) derivatives;
- the small-mutation limit is the relevant regime;
- the environmental feedback is whatever it is, so its dimension is counted, not derived.

EEO assumes that traits maximise carbon gain in a representative environment, usually mean light.

All of these abstract away three pieces of ecology that TF24 contains together:
1. **Mortality that depends on carbon status through a reserve buffer.** In TF24, μ = d_I + a_dG1·exp(−a_dG2·r), with r = S/S_max (`tf24_strategy.h`, `mortality_storage_dependent_dt`).
2. **A reserve pool that charges when net production P > 0 and drains when P < 0,** with growth gated on reserves.
3. **One-sided, size-structured light competition with self-thinning inside each patch.**

Each piece is known on its own:
- growth-dependent mortality (Kobe et al. 1995; SORTIE);
- the whole-plant compensation point as the measure of shade tolerance (Givnish 1988; Lusk & Jorgensen 2013);
- non-structural carbohydrate storage as the basis of shade survival (Kobe 1997; Poorter & Kitajima 2007);
- the perfect-plasticity approximation's Ẑ\* as an R\* for light (Adams, Purves & Pacala 2007).

The theory walked past their *conjunction*, for a practical reason. The tractable forest models fix understorey vital rates as parameters. In the PPA, understorey growth and mortality are constants. Carbon balance therefore never reaches zero in them, and no front exists. Simulators that do have carbon balance have no derivatives, so the front shows up only as noise, jumps or non-convergence. It shows up that way in our own record:
- the jump of `theory.md` A.4: +7.40 / 0 / −39.85 within ±5% of lma;
- the leaf-table knife edge: d ln R′/d ln P ≈ 3.5e3–7.6e3 for the closed-stand identity invader, against 49–64 elsewhere;
- the thinned schedule shifting ln R′ by 1.0 on the closed stand, against about 0.5 on the open ones.

This note claims these are one phenomenon, and that it is ecological, not numerical.

## 3. The formulation

### 3.1 The reserve-mediated hazard

Let P_c(a) be cohort c's whole-plant net production. In TF24 the reserves relax towards a fixed point r\*(P), quickly relative to the dwell (see §9 for when this fails). From the storage rate in `tf24_strategy.h`, with x = P/ε and ε = `storage_prod_eps`, that fixed point solves

  (1 − G(r))(1 − r) = (√(x²+1) − x)² r,  G(r) = logistic((r − a_st2)/0.1).

The quasi-static hazard is μ̂(P) = μ(r\*(P)). Computed with TF24's defaults:

| x = P/ε | −5 | −2 | −1 | −0.5 | 0 | 0.5 | 1 | 2 | 10 |
|---|---|---|---|---|---|---|---|---|---|
| r\* | 0.007 | 0.035 | 0.085 | 0.136 | 0.205 | 0.277 | 0.336 | 0.418 | 0.641 |
| μ̂ (/yr) | 4.79 | 2.73 | 1.02 | 0.37 | 0.100 | 0.032 | 0.017 | 0.011 | 0.010 |

So μ̂ is a knife of width w ≈ ε in P:
- it spans two orders of magnitude, (d_I, a_dG1) = (0.01, 5.5)/yr, over |P| ≲ 2ε;
- its slope at zero is μ̂′(0) = −0.267/ε per year.

Biologically, the width should be the spread of P among the individuals of a cohort: crown position, sunflecks, microsite. A deterministic cohort has none, so in TF24 the width falls to a numerical regulariser.

### 3.2 The front

For strategy θ′ in a held field E, the **compensation front** is the zero set

  Γ(θ′; E) = { (h, a) : P(h, L̄(h, a), ψ(a); θ′) = 0 },

and ℓ_c(h; θ′) is the crown light at which a plant of height h breaks even. In a cohort's life, dwell on Γ is where P_c ≈ 0 for long periods. The cohort's survival there is exp(−∫ μ̂(P_c) da).

### 3.3 Lemma 1: the thinning front is critical, generically

Consider the subordinate layer of a self-thinning stand. To keep the leaf area above it consistent with the canopy's growth, its plants must die at a rate κ(a). Under Yoda's rule, N ∝ m^(−3/2) gives κ = (3/2) × the relative growth rate of mean mass, typically 0.02–0.3/yr.

In TF24 these deaths can only come from μ̂, which is monotone. So the layer's net production satisfies

  P_front(a) = μ̂⁻¹(κ(a)).

From the table, any κ in (0.017, 1.02)/yr puts |P_front| < ε. That is, **any thinning rate between background and starvation mortality puts the front within one knife width of zero carbon balance.** No fine-tuning is needed: the hazard's large dynamic range absorbs the stand's demand for deaths. The front is critical because thinning acts through carbon starvation.

Two consequences:
- **The front is self-generated.** The field at the base of the canopy is the light at which the resident's own subordinate plants just fail to break even: an R\* for light, made by deaths rather than by seed rain.
- **The equilibrium seed rain barely reaches it.** Adding seeds adds deaths at the front, not darkness at the front. This explains why F(ln b) on the closed stand is smooth with slope about −1.5 (`field-dimension-066`) while the held-field gain is in the thousands.

### 3.4 Lemma 2: the held-field gain (selection at the front)

Write ln R′ = ln Σ_c W_c and π_c = W_c/R′. Scale the invader's production by a factor P_g → P_g(1 + δ) in the held field. Then

  ∂ln R′/∂δ |_E = Σ_c π_c ∫ P_g,c(a) |μ̂′(P_c(a))| da + (smooth terms)
       ≈ f · D · P̄_g · 0.267/ε,

where:
- f is the front's share of R′ (the reproductive value that passes through Γ);
- D is the dwell on Γ;
- P̄_g is the mean production scale while on Γ.

In the sharp limit w → 0, the coarea formula gives the singular part exactly:

  ∂ln R′/∂δ |_E = a_dG1 Σ_c π_c Σ_crossings P_g / |Ṗ_c(a_k)|.

That is selection localised on level crossings and weighted by the dwell 1/|Ṗ|. It diverges where the cohort is tangent to Γ, and Lemma 1 says tangency is what thinning produces.

Cohort by cohort, the field adjoint that the cut zeroes is

  S(z, a) = Σ_c w_c λ_c(a) ∂rates/∂L̄ q(z | h_c(a)),

with λ_c the cohort's costate. Through λ_c, S inherits the factor D|μ̂′| on the front. **S is a ridge along Γ in height × patch age.**

### 3.5 Lemma 3: the commons cancels the gain (the field-responding derivative)

By (I2) of `process.md`,

  dF/dδ = ∂φ/∂δ|_E + ⟨S, ∂𝓔/∂δ⟩.

When every resident produces more, the canopy grows faster, κ changes smoothly, and the front moves to a new Γ with P_front = μ̂⁻¹(κ). The front cohorts' survival changes by

  −D μ̂′ · dP_front/dδ = −D μ̂′ · κ′/μ̂′ = −D κ′,

which is O(1). So

  ⟨S, ∂𝓔/∂δ⟩ = −∂φ/∂δ|_E + O(1).

**The commons term cancels the private gain to leading order.** Any carbon advantage held by the whole stand is converted into faster thinning and a darker front, not into survival. In `theory.md` C.3, F_θ/g ≈ 0.25 on long drought. On a front-dominated stand the prediction is F_P/g_P → O(ε): selection is almost pure displacement, as in an arms race between plants of one species.

### 3.6 Lemma 4: the pairwise invasibility plot near the diagonal

Let θ′ = θ + Δ, and let ΔP be the invader's production offset at the resident's front. Then

  s(θ′, θ) ≈ ΔA(Δ) + ln[(1 − f) + f · exp(−D(μ̂(ΔP) − κ))],

with ΔA the smooth (open-phase) part. Across ΔP = 0 this has a step of width ε/P̄_g in ln P, and the step is asymmetric:
- **upside:** at most J⁺ = ln[(1 − f) + f e^{D(κ − d_I)}];
- **downside:** as low as J⁻ = ln(1 − f), or −D(a_dG1 − κ) when f ≈ 1.

The bounded upside comes from the background mortality d_I; the unbounded downside from starvation. The A.4 measurement (+7.4 against −39.9) has this sign of asymmetry.

The canonical small-mutation analysis holds only for |Δ ln P| ≲ ε/P̄_g, about 1e-3. Beyond that, invasion is decided by the sign of ΔP at the front, that is, by

  sgn(ℓ_c(h_front; θ) − ℓ_c(h_front; θ′)).

### 3.7 Proposition: an optimisation principle appears

On a front-dominated stand, the feedback reaches fitness through one scalar per front: the front light L_front = ℓ_c(h_front; θ_res). Metz, Mylius & Diekmann (2008) require an effectively one-dimensional, monotone feedback, and this is one. By their criterion, evolution:
- minimises ℓ_c(h_front; θ), the whole-plant compensation light at the front height;
- **pessimises the field:** the evolved canopy makes the darkest front its own regeneration can survive.

Because the upside J⁺ is bounded, the exact ESS condition is threshold-penalised:
- for every θ′ with ℓ_c(θ′) < ℓ_c(θ\*): A(θ\*) − A(θ′) ≥ J⁺;
- every θ′ with ℓ_c(θ′) > ℓ_c(θ\*) fails at once.

When J⁺ exceeds the range of the smooth part, the ESS is **lexicographic**: minimise ℓ_c first, then maximise the open-phase payoff A among the minimisers. The singular point is then a **kink, not a root of g**. One-sided gradients bracket zero, so the ESS is pinned over a range of parameters, which is response conservation (`assembly-geometry.md` §4c) acting at the trait level.

### 3.8 Corollary: EEO, reweighted

The costate value of carbon, μ_C(h, a) = λ·∂G/∂P (`theory.md` F.4), carries the factor D|μ̂′| on Γ. A lifetime-fixed leaf trait is optimal when it maximises ∫ μ_C P(θ; env) over the life, which here is dominated by the front. So the evolved leaf is the minimiser of compensation light at L_front, not the maximiser of carbon gain at mean light. This formalises Givnish's (1988) whole-plant argument: the weight is reproductive value, and the place is a curve in height × patch age.

## 4. The ecology

**A new kind of niche: the recruitment mode.** A species regenerates either:
- **open:** early patch ages, P ≫ ε, ordinary sensitivity spread over the early field;
- **through a front:** a ridge of sensitivity on Γ, of very large magnitude.

These two sensitivities have nearly disjoint support, so in Meszéna's sense they are strongly independent regulating factors. The counts that follow:
- **at most one bank species per front;** two species on one front obey an R\* rule at resolution ε, and the lower ℓ_c wins;
- **robust coexistence of a bank recruiter with an open recruiter;**
- **further bank species only on distinct fronts:** fronts at different patch ages, where the canopy's thinning history gives different L_front.

This is a structural reason for the successional niche, which Falster et al. (2017) and Detto, Levine & Pacala (2022) obtain through allocation trade-offs. Here the dividing line is the sign of carbon balance at recruitment, not a trait axis.

**Explanations of things the canon cannot account for:**
- **Strong purifying selection, weak directional selection.** Shade tolerance is under strongly purifying selection (J⁻ large) but only weakly directional selection (J⁺ bounded). That predicts low within-species variance in whole-plant compensation point and conserved shade-tolerance rankings across sites: a ratchet.
- **Closed-canopy carbon is pinned by thinning, not set by productivity.** A uniform increase in production (CO₂ fertilisation, a wetter year) is converted into faster thinning with the front's light unchanged (Lemma 3). More growth then means more mortality, not more survivors. This parallels the growth–lifespan trade-offs reported in forest inventories (Brienen et al. 2020; unchecked here), and it is derived from carbon starvation rather than assumed.
- **Selection strength on shade tolerance is set by heterogeneity, not by mean light.** The gain scales as 1/w, with w the within-cohort spread of P. Gappy, sunfleck-rich understoreys should hold more coexisting shade-tolerant species. Uniformly dark ones should be dominated by one. Within-cohort variation (Clark 2010; Hart, Schreiber & Levine 2016) is then not noise around the theory: it sets the theory's resolution.

## 5. Why us

Each lemma is a statement about a difference the platform computes exactly.

- **Lemma 3 needs the field cut.**
  - The cut sweep gives ∂φ/∂δ|_E and the kept sweep gives dF/dδ, bit for bit on one tape. Their near-total cancellation is the prediction.
  - A forward simulator sees only F, which is ordinary, or an invader's ln R′, which jumps. It cannot show that one is the other minus a commons term.
  - A theorist with a toy has no front.
- **The front map needs costates.** λ_c(a) on the resident's tape *is* reproductive value. The ridge Γ, its dwell D and its share f can be read from the tape without a single perturbation. Finite differences fail here: the leaf-table probe at ±1e-5 gave an asymmetric 3.5e3 against 7.1e3.
- **The localisation of S needs the zeroed adjoints.** They are S itself, resolved over height × patch age × time.
- **The ε test needs exact derivatives.** `storage_prod_eps` can go on the tape as a parameter, so ∂ ln R′/∂ ln ε in one sweep separates artefact from ecology.
- **Certified discretisation.** The closed-stand schedule error (1.0 in ln R′ from thinning the invaders) is a front that is under-resolved in birth date. A per-quantity error estimate can say whether a front cohort's sign is resolved.
- **The model contains all three pieces of ecology at once:** reserves, carbon-balance mortality, and size × patch-age light competition. PPA models (Adams et al. 2007; Farrior et al. 2016; Detto et al. 2022) fix understorey rates, so their fronts cannot form.

## 6. Prior art and the delta

**Known:**
- growth-dependent juvenile mortality (Kobe et al. 1995; Pacala et al. 1996);
- the whole-plant compensation point as shade tolerance, rising with size (Givnish 1988; Lusk & Jorgensen 2013);
- storage as the mechanism of shade survival (Kobe 1997; Poorter & Kitajima 2007; Myers & Kitajima 2007);
- Ẑ\* as R\* for light (Adams, Purves & Pacala 2007);
- the dominance of suppressed understoreys, with near-zero growth (Farrior et al. 2016);
- successional niche coexistence (Pacala & Rees 1998; Falster et al. 2017; Detto, Levine & Pacala 2022);
- optimisation principles from one-dimensional feedback (Metz, Mylius & Diekmann 2008);
- branching under asymmetric competition (Kisdi 1999);
- the effects of individual variation on coexistence (Hart, Schreiber & Levine 2016).

**The delta, as far as I could find (searches were brief; check before leaning on this):**
1. Lemma 1: self-thinning through starvation mortality pins the subordinate layer within one knife width of zero balance, generically.
2. Lemma 3: the held-field gain and the commons term cancel.
3. The pairwise invasibility plot as an asymmetric step on the diagonal, which makes the small-mutation limit irrelevant for carbon traits.
4. The lexicographic or kinked ESS, and Metz–Mylius–Diekmann applied to the front light.
5. The costate reweighting of EEO onto Γ.

Adams et al. reach an R\* for light, but with fixed understorey rates and at the canopy-entry height. Here the R\* emerges from carbon balance, at the front, through deaths.

## 7. A worked case

**The toy.** One front cohort dwells D years at the resident's front, where P = 0, with production scale P_g = qε. It uses TF24's own reserve law (the table in §3.1), and f = 1.

- **Gain:** d ln w/d ln P_g = 0.267 D q.
  - D = 20, q = 100 gives 534; q = 1000 gives 5,340.
  - A sapling with about 0.5 m² of leaf at about 0.2 kg m⁻² yr⁻¹ has q ≈ 1000. With D = 10–30 the gain is 2.7e3–8e3, the same order as the measured 3.5e3–7.6e3.
- **The step (q = 100, D = 20):** Δ ln P of +0.001, +0.01 and +0.05 gives Δ ln w of +0.46, +1.67 and +1.81, saturating at J⁺ = D(μ̂(0) − d_I) = 1.8. Of −0.001, −0.01 and −0.05 it gives −0.62, −18.5 and −93.9, towards −D a_dG1 = −110. The asymmetry matches A.4 in sign.
- **Lemma 1's window:** κ ∈ (0.017, 1.02)/yr maps to |P_front| < ε.
- **Lemma 3 in the toy:** the stand's change is −D κ′ = O(1) per unit ln P_g, against the held-field 534–5,340.

**Checkable on TF24 without new code beyond the existing sweeps:**
1. **Halve `storage_prod_eps`.** The closed identity invader's gain should roughly double; the open stand's (about 49) should not move.
2. **Cut against kept sweep on the closed resident, in leaf production.** Expect g_P of order 10³ and F_P of order 1–10.
3. **The costate map μ_C(h, a)** should show a ridge on the zero set of P for resident cohorts.

## 8. What it opens

**Theory:**
- Adaptive dynamics with an asymmetric step on the diagonal: the canonical equation is replaced by a ratchet, and the outcome depends on mutation size.
- HJB with a discontinuous hazard for the mean-field game (`assembly-mfg.md`). V\* has a kink at P = 0, so the optimal policy is bang-bang: stall or grow, and the front is a free boundary of the game.
- Fronts as regulating factors, which gives a count of d from the canopy's thinning history.

**Computation, as the first step:** the three tests in §7, then a slice of the pairwise invasibility plot along a trait that moves ℓ_c, on the closed stand.

**Consequences for the worked material:**
- **The embedding.** φ ≈ a + ⟨S, y⟩ (`assembly-geometry.md` §4b) cannot be affine along the front-light direction. That explains why the held-out closed canopy fails, why its secants are strongly nonlinear, and why traits explain only 36% of the closed stand's mode-1 loadings, against 84% on the open stands. The prediction is that those loadings are a step function of Δℓ_c.
- **O1 against O3** (`process.md` §5). A resident's balance F_i^s is ordinary when computed from its own run (Lemma 3). Entries near the resident's traits (O3), and any approximation on the invader side (tables, thinned schedules), are amplified by the gain. Pricing near residents must be one-sided, and certificate margins should be judged against J⁺, not against ε alone.
- **The reference community.** The closed-canopy singular point in lma, rho and vcmax should be a kink at minimal ℓ_c, not a smooth root of g = 0.

**Ecological predictions:**
- The understorey light under closed monodominant stands matches the dominant species' whole-plant compensation point at the front height.
- The number of coexisting shade-tolerant species rises with understorey light heterogeneity at a fixed mean.
- In self-thinned stands, uniform fertilisation raises mortality and leaves understorey light unchanged.

## 9. Where it might break

- **f may be small.** If open-phase cohorts carry most of R′, the front is a side show, with ordinary gains.
- **The width in TF24 is ε, a numerical parameter.** The gain may be partly an artefact. The theory then says the model's closed-canopy fitness is set by a regulariser standing in for missing ecology (within-cohort variance), which is a finding in itself.
- **The quasi-static reserve assumption.** Near P ≈ ε, the relaxation time S_max/(charge + drain) can be years. r then integrates P, and the gain scales more like D²P_g/S_max: the same order, with a different form.
- **Steady thinning.** A real front moves with patch age, and κ varies.
- **No gap release inside a patch.** Disturbance resets the whole patch, so release comes only from self-thinning. Real gap dynamics would add a third recruitment mode.
- **Water as a second limiting factor.** If water co-limits at the front, the feedback is two-dimensional and Metz–Mylius–Diekmann no longer applies.
- **The A.4 jump predates the storage model.** That model had mortality spikes in deficit, so it supports the mechanism's shape, not the TF24 numbers.

**References** (from memory unless noted; check before citing):
- Adams, Purves & Pacala 2007, Proc. R. Soc. B 274: 3039 (confirmed by search);
- Brienen et al. 2020, Nat. Commun.;
- Clark 2010, Science;
- Detto, Levine & Pacala 2022, Ecol. Monogr. 92: e1500 (confirmed by search);
- Falster et al. 2017, PNAS;
- Farrior et al. 2016, Science 351: 155 (confirmed by search);
- Givnish 1988, Aust. J. Plant Physiol. 15: 63;
- Hart, Schreiber & Levine 2016, Ecol. Lett.;
- Kisdi 1999, Am. Nat.;
- Kobe 1997, Oikos;
- Kobe et al. 1995, Ecol. Appl.;
- Lusk & Jorgensen 2013, Funct. Ecol.;
- Metz, Mylius & Diekmann 2008, Evol. Ecol. Res.;
- Myers & Kitajima 2007, J. Ecol.;
- Poorter & Kitajima 2007, Ecology (found by search).

Sources:
- [Adams, Purves & Pacala 2007](https://collaborate.princeton.edu/en/publications/understanding-height-structured-competition-in-forests-is-there-a/)
- [Detto, Levine & Pacala 2022](https://collaborate.princeton.edu/en/publications/maintenance-of-high-diversity-in-mechanistic-forest-dynamics-mode/)
- [Farrior et al. 2016](https://repository.si.edu/items/f7a65a0e-c7b5-4b9d-b25b-e296fdbdfb7a)
- [Whole-plant compensation point (Waikato)](https://researchcommons.waikato.ac.nz/entities/publication/32b5c124-9190-401a-bbce-e4c03fcaedb0)
- [Poorter & Kitajima 2007](https://ibifbolivia.org.bo/wp-content/uploads/2022/09/2007-Poorter-Kitajima-Carbohydrate-storage-and-light-requirements-Ecology.pdf)

Files read: `/home/a/dev/plant-dev/.claude/worktrees/workflows/plant/inst/include/plant/models/tf24_strategy.h` (storage rate and mortality). The toy calculation is in `/tmp/front_toy.py`.