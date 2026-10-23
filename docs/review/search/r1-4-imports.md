# Sites as prices, niches as supplies: revealed preference, integrability and Le Chatelier for selection across a landscape

## 1. Headline

Economics found that optimisation can be tested without knowing the technology. Its empirical content lies in cross-sectional restrictions on pairs of prices and quantities: Afriat and Rockafellar's cyclical monotonicity, Slutsky and Hotelling symmetry, and Samuelson's Le Chatelier principle. Ecology never had those pairs, because neither coordinate is observable. With the field cut, we have both at every observed resident: the field y_s plays the price and the sensitivity σ_s = S(θ_s) plays the quantity. That turns those theorems into a family of tests and predictions. They need no trade-off function, no equilibrium and no fitness levels, and they see things that the local-adaptation contrasts used today cannot.

## 2. The departure

**The canonical tests are local, per population, and need levels.**
- Adaptive dynamics and EEO test optimality one population at a time. They ask whether g = 0 and H ≺ 0, or whether any invader has φ > 0.
- `site-selection.md` §3 carries this to a table T_js = φ(θ_j; E_s) and cites Afriat and Varian for the row test T_sj ≤ T_ss. That test is the weak axiom of profit maximisation (WAPM): it compares strategies' levels at one site.

**Three things were walked past.**
1. **Optimality across sites makes claims that need no levels.** The restrictions on how the best response varies across fields hold whatever the feasible set, so whatever the trade-off. They are invariant to every strategy's and every site's main effect. Levels are exactly what the break-even sensitivity makes fragile: d ln R′/d ln P reaches about 7.6e3.
2. **The best-response map must be a gradient.** Its Jacobian in the field is symmetric (reciprocity), and its symmetric part orders across adjustment margins (Le Chatelier). Neither is used anywhere in community ecology.
3. **Why nobody did this.** Revealed preference needs observed price–quantity pairs. Ecologists observe climate (which is supply, not price) and traits (which are not quantities). The realised field, light over height × patch age and water by layer through time, is not measured. What fitness reads in it, σ, is not observable at all without an adjoint through the whole life history. Toy-model theorists have σ but no real sites. Simulation modellers have sites but no σ.

The departure is from **testing optimality pointwise** to **testing it as a property of the whole map from sites to niches**. This replaces "is the community optimal?" with "is the observed assignment of niches to fields the gradient of a convex function?"

## 3. The formulation

Notation follows `process.md`. The objects are:
- sites s = 1…n, each with field E_s, written y_s ∈ ℝᵈ in the shared modes;
- the residents of each site, with traits θ_s and niche σ_s = S(θ_s);
- the transplant table T_js = φ(θ_j; E_s).

### 3.1 The assignment lemma: optimality implies no improving reassignment

**Assumption.** Each site's resident is a best response among the observed strategies in its own held field: T_ss ≥ T_js for every j.

**Lemma 1.** Under that assumption, for every permutation π of sites,

  Σ_s T_{s,π(s)} ≤ Σ_s T_{s,s}.

*Proof.* Take a cycle s₀ → s₁ → … → s₀. Optimality at s_{k+1} gives T_{s_k, s_{k+1}} ≤ T_{s_{k+1}, s_{k+1}}. Summing around the cycle gives Σ_k [T_{s_k, s_{k+1}} − T_{s_k, s_k}] ≤ 0. Every permutation is a product of cycles. ∎

**Properties.**
- **Invariance.** The cycle sums are unchanged by T_js → T_js + α_j + β_s.
  - α_j is any error in a strategy's absolute level (its intercept, a mis-set leaf constant).
  - β_s is any site effect (site quality, a mis-balanced b).
  - Both cancel exactly.
- **Duality.** By linear-programming duality (Kantorovich; the assignment game of Shapley and Shubik), the observed assignment is optimal iff there are potentials u_j and v_s with

    T_js ≤ u_j + v_s for every (j, s), with equality on the observed residents.

  The table is an additive "strategy quality + site value" surface. The interactions are non-positive off the observed assignment.
- **Effect size.** The largest positive mean cycle sum is the money-pump index (Echenique, Lee & Shum 2011). In ecology it is the fitness, in ln R′ per strategy, gained by rotating residents among sites.

**A hierarchy of tests on one table:**

| Test | Condition | Invariant to | Needs |
|---|---|---|---|
| WAPM / ESS against the pool (current) | T_js ≤ T_ss | site effects | strategy levels |
| Assignment optimality (new) | all cycles ≤ 0 | strategy and site effects | the table, or its first-order form |
| Sympatric–allopatric contrast | 2-cycles ≤ 0 | strategy and site effects | the table |

**Trade-off invariance.** Lemma 1 compares only observed strategies, which are feasible because they exist. So a misspecified trade-off cannot produce a positive cycle. Only these can:
- lag, or gene flow and migration load;
- mis-sensing: S or y wrong in the model;
- physiology that differs across sites.

This adds a separating test to the four readings of a residual in `site-selection.md` §2, whose first row is "wrong trade-off".

### 3.2 The first-order form needs only the cut

**The cycle sums at first order.** With the embedding φ ≈ a(θ) + ⟨S(θ), y⟩, the intercepts cancel around a cycle:

  Σ_k T_{s_k, s_{k+1}} − T_{s_k, s_k} ≈ Σ_k ⟨σ_{s_k}, y_{s_{k+1}} − y_{s_k}⟩.

- **Rockafellar's theorem.** The pairs (y_s, σ_s) lie in the graph of ∂Ψ for some convex Ψ iff these sums are ≤ 0 on every cycle.
- **Cost.** The test needs only y_s, from the resident run P1, and σ_s, the zeroed field adjoints of the cut sweep P3. Both come free with every site's recording. It needs no invader runs, no pricing and no b-balance.
- **The levels are optional.** Ψ(y_s) = F_s is not used. So the test holds on history rows, where there is no equilibrium. It tests "best response to the current field" separately from "demographic balance".

**Afriat's construction.**
- Write edge weights w_{st} = ⟨σ_s, y_s − y_t⟩. The test passes iff the complete graph has no negative cycle (Bellman–Ford, or Karp's minimum mean cycle).
- The shortest-path potentials v_s give the minimal rationalising convex function, Ψ̂(y) = max_s [v_s + ⟨σ_s, y − y_s⟩].
- They also give an empirical frontier, Â(σ_s) = v_s − ⟨σ_s, y_s⟩, up to one additive constant.

  Â is the EEO frontier A(σ) of `assembly-geometry.md` §4b, recovered from where strategies live rather than from physiology. In finite samples it is bounded by linear programs, not point-identified. The calibration residual a(θ_s) − Â(σ_s) constrains the shape of the frontier, not its level.

**A direction-only variant.** Suppose the break-even amplification acts at each site mainly as a positive scalar, σ_s = κ_s σ̃_s. Then use Afriat's inequalities with free multipliers, v_t ≤ v_s + λ_s⟨σ̃_s, y_t − y_s⟩ with λ_s > 0. This is equivalent to the generalised axiom of revealed preference (GARP) and uses only the directions of S.

### 3.3 What cycles see and pairs miss: the symmetric and skew parts

**Pairs see only the symmetric part.** Linearise the site-to-niche map, σ = M y with M = Σ + B (Σ symmetric, B skew). A 2-cycle sum is −⟨Δσ, Δy⟩ = −Δyᵀ Σ Δy. It sees Σ only. This is the sympatric–allopatric (SA) contrast.

**Longer cycles see the skew part.** For an n-cycle,

  Σ_k ⟨σ_k, y_{k+1} − y_k⟩ = −½ Σ_k ‖Δy_k‖²_Σ + Σ_k ⟨B y_k, y_{k+1}⟩.

In d = 2 with B = bJ, the second term is 2b × (signed area enclosed).

**Proposition (detectability of curl).**
- With Σ = sI and B = b s J, the map is √(1+b²) s times a rotation by arctan b.
- It passes every cycle of length n iff arctan b ≤ π/n.
- So a skew ratio b is invisible to every cycle shorter than π / arctan b.
- Pairs (n = 2) never see it.

This is the rotation result for n-cyclically monotone operators (Bartz, Bauschke, Borwein, Reich & Wang 2007), here given an ecological reading. It is checked numerically in §7.

**Integrability is reciprocity.** For smooth σ(y) = ∇Ψ(y),

  ∂σ_k/∂y_l = ∂σ_l/∂y_k,

which is the Slutsky, Hotelling and Onsager symmetry. With exact derivatives the model gives this matrix directly. At an interior optimum, the first-order condition is g = ∇a + Gy = 0, with G = ∂g/∂y = (∂S/∂θ)ᵀ. Then

  dθ*/dy = −H⁻¹G,  ∇²Ψ = dσ*/dy = −Gᵀ H⁻¹ G  (symmetric, ⪰ 0 when H ≺ 0).

So the model predicts both the symmetry and the matrix. Data estimate the matrix across sites. The skew part of the data's estimate is the departure.

### 3.4 Le Chatelier across adjustment margins

**Setup.** Let R ⊂ R′ be sets of free traits. The traits outside each set are fixed at their optimum for a reference field y₀. Define Ψ_R(y) = max_{θ_R} φ(θ; y).

**The ordering.** Then Ψ_R ≤ Ψ_{R′}, with equality at y₀. So Ψ_{R′} − Ψ_R has a minimum at y₀, which gives

  ∇²Ψ_R(y₀) ⪯ ∇²Ψ_{R′}(y₀)  (PSD order),

  −G_Rᵀ H_RR⁻¹ G_R ⪯ −Gᵀ H⁻¹ G  (the gap is a Schur complement).

**Without smoothness.** The second difference Ψ(y₀+h) + Ψ(y₀−h) − 2Ψ(y₀) is ordered in the same way for every h. This lets the top rung be the whole pool with turnover, Ψ_pool = max over species, kinks included.

**The ladder.** Three rungs are ordered:
- plastic: TF24's inner leaf optimisation, plus any acclimating traits;
- evolved within a species;
- turnover across the pool.

Each rung is ordered in niche coordinates along every field direction u. Equivalently, it is ordered on the selected trait index z_u = (Gu)ᵀθ, the trait combination that field direction u selects on.

**The contrast with supply coordinates.** Response conservation (`assembly-geometry.md` §4c) says rank ∂traits/∂supply = d − m: adding margins (species) reduces the response to supply. That is the anti-Le Chatelier effect of general equilibrium. Le Chatelier holds when prices are held (partial equilibrium) and can fail when they respond. In ecological terms:
- trait responses **to the realised field** grow with the number of margins;
- trait responses **to climate supply** shrink with richness.

### 3.5 The predictive corollary: assignment from marginals

**The theorem.** Take a landscape's distribution of fields μ(y) and a pool's abundance-weighted distribution of niches ν(σ). If assignment is optimal, it is the optimal-transport coupling for the surplus ⟨y, σ⟩, or for the exact surplus φ(θ; y). When μ is absolutely continuous, that coupling is unique and is the gradient of a convex function (Brenier 1991; McCann 1995; Gangbo & McCann 1996).

**Meaning.** Who lives where is determined by the two lists, without being told the pairing.

**The twist condition** needed for a unique map with a general surplus is injectivity of σ ↦ ∂_y φ. That is exactly that distinct strategies have distinct sensitivities, the sensitivity half of Meszéna et al.'s robust-coexistence condition.

**Finite selection or dispersal mixing** gives the entropic version, π_js ∝ u_j v_s exp(T_js/τ), solved by Sinkhorn iterations. It is Shipley's maximum-entropy CATS model with its multipliers identified as field coordinates. It brings the identification results of Choo & Siow (2006) and Galichon & Salanié.

## 4. The ecology

**1. Local adaptation is a matching problem, and current contrasts test only its pairs.**
- The SA contrast (Blanquart et al. 2013) was adopted because it removes site and population main effects. It is the 2-cycle condition.
- The full content of "each population best suits its own site" is that the home assignment is the maximum-weight matching of the transplant table (Hungarian algorithm). With d ≥ 2 environmental dimensions, a set of provenances can pass every pairwise contrast and still be improvable by rotating three or more.
- This bears directly on the restoration debate "is local best?", where local-versus-foreign and SA analyses disagree on the same data (Bucharova et al. 2017). Provenance planning is optimal transport.

**2. Reciprocity, a new falsifiable prediction.** At selection balance, how much more light-sensitive the favoured strategy becomes as soil dries equals how much more water-sensitive it becomes as the canopy opens. The model computes both sides (−GᵀH⁻¹G). Across sites the asymmetry is measurable.

**3. Curl diagnoses lag on loops in field space.**
- Joint shifts in field are often loops rather than lines: drought, then dieback (light up, water down), then recovery (canopy closes, water returns).
- A population tracking σ*(y) with lag τ around a loop of angular frequency ω sits at a phase lag φ_lag = arctan(ωτ). Its site-to-niche map has skew ratio tan φ_lag.
- Every pairwise test passes while φ_lag < 90°. Detecting the lag needs cycles of at least π/φ_lag sites or dates.
- So pairwise reciprocal transplants are structurally blind to rotational lag.

**4. Weak global trait–climate relations may be a coordinates problem.**
- Bruelheide et al. (2018) found weak relations between community traits and climate.
- Response conservation predicts flat trait–supply slopes in saturated communities. Le Chatelier predicts steep trait–field slopes, steepest at the turnover rung.
- Prediction: in diverse stands, community-weighted traits correlate more strongly with the measured realised field (understorey light, predawn water potential) than with rainfall. The gap grows with richness m.

**5. Within-species slopes are shallower than among-species slopes, by a theorem.**
- Le Chatelier gives plastic ⪯ intraspecific ⪯ turnover along every selected index. This is consistent with the dominance of turnover found by Siefert et al. (2015) and Lajoie & Vellend (2018).
- It also forbids any field direction in which within-species response exceeds among-species response at a common reference field. That is falsifiable.

**6. Separating the trade-off from everything else.** Cycle violations cannot come from a trade-off. Gradient residuals g_∥ can. Comparing the two attributes a disagreement to the trade-off or to the model's sensing and lag.

## 5. Why us

1. **σ_s at every observed resident, at every site, under its own weather, at no extra cost.**
   - It is the zeroed adjoints of the cut (P3), exact, in every field coordinate (height × patch age × layer × time) and in the exogenous drivers.
   - Including VPD, temperature and CO₂ as held coordinates of y makes the frontier A shared across sites. That is the condition Lemma 1 and Rockafellar need, and it costs nothing, since those adjoints are on the same tape.
   - Without reverse mode, σ over this field is a Jacobian of thousands of columns per resident per site.
2. **A low measured d (2–4 open, 4–5 closed).**
   - It makes y_s a short vector, so the cycle LP is small and the test has power.
   - d ≥ 2 is exactly where cycles carry more than pairs (curl needs d ≥ 2).
   - The shared modes put different records on one axis.
3. **G and H from P7**, for the model's −GᵀH⁻¹G, the reciprocity matrix and the Le Chatelier rungs (subsets of traits, and the leaf's inner optimisation as the plastic rung).
4. **History rows.** The test needs no equilibrium and no levels, and history rows have neither reliably.
5. **Certified discretisation.** Cycle sums are small differences of model outputs. P8's per-quantity errors on σ and y certify each cycle's sign, and the scheduler's ε sets which violations are real.
6. **Calibration.** The money-pump LP's value is a level-free loss L(c). Its gradient is the LP duals times dσ/dc and dy/dc: P7 for ∂S/∂c and P5 for the field term. That is O(1) sweeps per site (`process.md` §3.4).

## 6. Prior art and the delta

**Economics (all known; we import it).**
- Afriat (1967); Varian (1982, 1984: WAPM and nonparametric production analysis).
- Rockafellar (1966, 1970: cyclical monotonicity); Rochet (1987: implementability).
- Echenique, Lee & Shum (2011: money-pump index).
- Jerison & Jerison (1996): discrete antisymmetric revealed-preference cycles characterise Slutsky symmetry. This is the closest relative of §3.3.
- Bartz et al. (2007): rotations and n-cyclic monotonicity. Our proposition is their result.
- Samuelson (1947); Milgrom & Roberts (1996, global Le Chatelier).
- Brenier (1991); McCann (1995); Gangbo & McCann (1996); Chiappori, McCann & Nesheim (2010: hedonic equilibrium as optimal transport); Ekeland, Galichon & Henry (2010: optimal transport and the falsifiability of incompletely specified models); Choo & Siow (2006); Galichon (2016).

**Ecology and evolution.**
- Revealed preference has been tested on animal choice (Kagel, Battalio & Green 1995). Searches found nothing applying cyclical monotonicity, GARP or Slutsky symmetry to plant traits, communities or local adaptation.
- Optimal transport: Stock, Poisot & De Baets (2021) used entropic optimal transport for species-interaction networks. That is trait matching between two species sets, not a species-to-site assignment derived from fitness optimality.
- Le Chatelier:
  - Hatakeyama (2026, arXiv preprint) gives an "evolutionary Le Chatelier principle" for one population: plastic, then genetic change in the same direction.
  - Lajoie & Vellend (2018) partition plasticity, genetics and turnover empirically.
  - Neither orders the three rungs as a PSD inequality, and neither contrasts field coordinates with supply coordinates.
- Local adaptation: Kawecki & Ebert (2004); Blanquart et al. (2013). The SA contrast is the 2-cycle case. The generalisation to cycles and matchings appears new.
- In this repo, `site-selection.md` §3 already uses the WAPM-type row test with levels.

**The delta:**
- level-free, trade-off-free cycle tests computed from the cut alone;
- curl as a lag signature that pairwise designs cannot see, with its cycle-length threshold;
- reciprocity and the Le Chatelier ladder as model-computable, data-testable predictions;
- assignment from marginals.

The theorems are known. Their use in ecology, made possible by having σ and y, is, as far as I could find, new.

## 7. Worked cases

Numerical checks are in `/tmp/lat/check.R` (run with Rscript).

**(a) The curl threshold.** Take σ = (I + bJ)y with sites on a regular n-gon. The first failing n:

| b | first failing n | π/arctan b |
|---|---|---|
| 0.1 | 32 | 31.5 |
| 0.2 | 16 | 15.9 |
| 0.5 | 7 | 6.78 |
| 1.0 | 5 | 4.00 (n = 4 is exactly 0) |
| 1.8 | 3 | 2.95 |

Fifty random sites under b = 0.9 give a minimum pair contrast of +7e-4: every pair passes.

**(b) Lag on a loop.**
- Setup: τ dσ/dt = y − σ, with y on the unit circle, ω = 2π/10 and τ = 1.2.
- The fitted map is [[0.638, −0.480], [0.480, 0.638]]. Its skew ratio is 0.753, against ωτ = 0.754.
- The phase lag is 37°. Cycles of 5 or more points detect it; pairs never do.

**(c) Swap-stable but not optimal (three sites).**
- Let D_js = T_js − T_jj be strategy j's away-minus-home change.
- Take D₁₂ = D₂₃ = D₃₁ = +1 and D₂₁ = D₃₂ = D₁₃ = −1.5.
- Every pair sums to −0.5, so every SA contrast says "locally adapted".
- The forward 3-cycle sums to +3: rotating provenances 1→2→3→1 raises total ln R′ by 3.

**(d) Le Chatelier with two traits and one field direction.**
- Take H = −[[1, ρ], [ρ, 1]] and G = (1, 0)ᵀ: the field selects on trait 1 only, and the traits interact in fitness.
- Plastic or one-trait rung: ∇²Ψ = 1. Both traits evolving: 1/(1 − ρ²). At ρ = 0.7 the response is 1.96× larger, carried through a trait the field does not select on.
- 2000 random 6-trait, 3-field cases confirm −Gᵀ H⁻¹ G − (−G_Rᵀ H_RR⁻¹ G_R) ⪰ 0 for random subsets R.

## 8. What it opens

**Testable predictions:**
1. Reciprocity of niche responses across a 2-D (light × water) field gradient, with the model's −GᵀH⁻¹G as the null.
2. Trait–field correlations exceed trait–climate correlations, increasingly with richness.
3. In provenance trials with d ≥ 2 environmental axes, some will pass all SA contrasts and fail 3- or 4-cycles. The failures should align with sites whose recent field history traced a loop: drought, dieback, recovery.
4. Intraspecific slopes along each selected index z_u never exceed interspecific ones at a common reference field.

**First theoretical and computational steps, in order:**
1. **Curvature check of the first-order form.**
   - On `spikes/field-dimension-066/`, compute the cycle sums both from the exact 48 × 45 table and from ⟨σ, Δy⟩.
   - This measures how often the first-order form mis-signs a cycle, given the closed-canopy secant nonlinearity of 0.35–0.56.
   - Strictly, that table's 45 columns are perturbation secants about one resident stand, not separate sites with their own residents. So the step is to rebuild σ_s and y_s from the stored perturbation runs, not to read the sums directly off the table.
2. **The model's reciprocity matrix.** At the reference community (`spikes/reference-community/`), compute −GᵀH⁻¹G. Verify its symmetry against finite differences of σ*(y). This checks P7 and the envelope.
3. **The plastic rung.** Hold TF24's leaf state at its y₀ optimum and remeasure the curvature of φ in the field. Le Chatelier says the curvature drops. This also explains part of the measured convexity on the closed canopy as the leaf's inner maximisation.
4. **History-row assignment.** Over sites in the `site-selection.md` design, with exogenous drivers added to y:
   - run the negative-cycle detector and compute Afriat's Â;
   - compare Â with a(θ_s) as a shape-only calibration target;
   - fit the money-pump loss's gradient through P5 and P7.
5. **Theory.** Prove the field-coordinate versus supply-coordinate reversal in general: Le Chatelier holds for held fields, and response conservation holds for supply. In general-equilibrium language, which margins move which way. Links: `assembly-geometry.md` §4b–4c and `process.md` §3.3–3.4.

## 9. Where it might break

- **Best response at each site is the null hypothesis.** With gene flow, lag or recent arrival, violations are expected. Curl from gene flow along an advective dispersal axis and curl from temporal lag look alike, so curl names "not a gradient", not the cause.
- **Sensing must be right.** σ and y come from the model. A cycle violation can be model error in S or E, so the test is joint in the model's sensing and nature's optimality. It is free only of the trade-off and of levels.
- **The first-order form needs fitness near affine in y.** The closed canopy is strongly nonlinear, so there the exact table cycles are the test and ⟨σ, Δy⟩ is a screen.
- **A shared frontier across sites** needs every direct climate driver in y. Unmodelled site effects on physiology (soil nutrients, pathogens) enter as site-varying A and can create spurious cycles.
- **Several residents per site and abundance weights** need the Kantorovich (mass) form, not permutations. Ties within a site are harmless, because those residents share y.
- **Finite and noisy.** Long cycles add noise, and detecting a small curl b needs about π/b sites arranged around a loop, not along a line. Certified errors (P8) and permutation nulls are needed.
- **Brenier's uniqueness** needs a continuous field distribution and the twist condition. Real landscapes are finite, and near-neutral hydraulic traits make σ nearly degenerate in some directions, which weakens identification.
- **Le Chatelier is local and needs tangency at y₀.** It is an ordering at one reference field, not across arbitrary pairs of sites.
- **Only the LP duality is borrowed from the market analogy.** Strategies and sites do not transfer utility.

Sources:
- [Hatakeyama, Evolutionary Le Chatelier's Principle (arXiv 2607.20915)](https://arxiv.org/abs/2607.20915)
- [Lajoie & Vellend 2018, plasticity vs genetic differentiation in community trait responses](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5916269/)
- [Bucharova et al. 2017, "Are local plants the best for ecosystem restoration?"](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5743477/)
- [Revealed preference test for quasilinear preferences (cyclical monotonicity)](https://arxiv.org/pdf/2111.01248)
- [Stock, Poisot & De Baets 2021, optimal transportation for species interaction networks](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8093754/)
- [Jerison & Jerison 1996, discrete Slutsky symmetry (J. Econ. Theory, via IDEAS)](https://ideas.repec.org/a/spr/joecth/v8y1996i2p229-37.html)
- [Border, integrability notes (Hurwicz–Uzawa)](https://healy.econ.ohio-state.edu/kcb/Notes/Demand4-Integrability.pdf)

The other references are cited from memory and not checked: Afriat 1967, Varian 1982/1984, Rockafellar 1970, Rochet 1987, Echenique–Lee–Shum 2011, Bartz et al. 2007, Samuelson 1947, Milgrom & Roberts 1996, Brenier 1991, McCann 1995, Gangbo & McCann 1996, Chiappori–McCann–Nesheim 2010, Ekeland–Galichon–Henry 2010, Choo & Siow 2006, Galichon 2016, Kawecki & Ebert 2004, Blanquart et al. 2013, Kagel–Battalio–Green 1995, Siefert et al. 2015, Bruelheide et al. 2018, Shipley et al. 2006.