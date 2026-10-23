# Inverse optimality across a landscape: level-free, trade-off-free tests of selection, lag and price at observed sites

# Inverse optimality across a landscape: one integrability condition read at three scales, and the loop that measures evolvability

## 1. Headline

The field cut gives every observed resident a revealed (field, niche) pair. Each resident's selection gradient then turns that pair into a second one: the field it is adapted to, which turns out to be the Lagrange multiplier of the EEO frontier. These pairs satisfy one integrability condition at three scales:
- **globally,** cyclical monotonicity (Afriat);
- **locally,** a single field of adaptation per species (T1 and T2);
- **infinitesimally,** symmetry of −GᵀH⁻¹G (reciprocity).

The ways each scale fails separate trade-off error, lag, constraint, privacy and model sensing error. The sharpest result is an identity. Around any closed loop of field history, the level-free cycle sum equals minus the fitness that adaptation gained along the loop, ∫gᵀkMg dt. A transplant table arranged around a loop therefore measures evolvability along selection, which is the one quantity site selection has never been able to touch.

## 2. The departure

**The canonical tests are pointwise.** Adaptive dynamics and EEO test optimality one population at a time and in a known environment:
- g = 0, H ≺ 0;
- "no invader has φ > 0";
- EEO prices fitted as constants.

Site selection (`site-selection.md`) inherits this. Its two weaknesses follow:
- **The residual g_is is read through a trade-off T that is itself assumed** (§2, row 1 of the four readings).
- **Levels F_i need b-balancing,** which fails for weakly separated species (§7), and they are fragile where d ln R′/d ln P reaches about 7.6e3.

**The departure is to test optimality as a property of the whole map** from fields to niches across a landscape, and of its history:
- the cross-site (field, niche) pairs;
- the per-species field of adaptation;
- the leaf's prices.

All three are views of one convex-analytic object, the frontier A(σ) and its conjugate Ψ(y). The question changes from "is this population optimal?" to "is the observed field-to-niche correspondence the subgradient of one convex function, and if not, how does it fail?"

**Why this was walked past.**
- **Economists have the theorems** (Afriat, Rockafellar, Slutsky, Le Chatelier) but no ecology.
- **Ecologists have transplant tables** but neither coordinate of the pair: climate is supply, not field, and traits are not niches.
- **σ needs an adjoint through a whole competitive life history,** and ŷ needs G as well.
- **The loop identity needs both a field history and σ along it.** A forward simulator has the first, a toy theorist has the second, and only we have both.

## 3. The formulation

Notation is that of `process.md`:
- y ∈ ℝᵈ is the field on modes; σ = ∂_yφ is the niche (the cut's zeroed adjoints);
- g = ∂_θφ ∈ ℝᵏ; G = ∂g/∂y ∈ ℝ^{k×d}; H = ∂²_θθφ;
- W := −GᵀH⁻¹G;
- A(σ) = max{a(θ) : S(θ) = σ}, and Ψ(y) = max_σ [A(σ) + ⟨σ, y⟩].

### 3.1 R1. The field of adaptation is the frontier's multiplier

Take a species with traits θ_i, sensing φ = a(θ) + ⟨S(θ), y⟩ + ρ, and g(θ; y) = ∇a + Gy.

**R1.** Suppose T1 holds: ∇a(θ_i) ∈ range(G_i), equivalently θ_i is stationary on its fibre S = σ_i. Then

  ŷ_i := y_s − G_i⁺ g_is = −G_i⁺∇a(θ_i) = −μ_i = −∇A(σ_i),

where μ_i is the Lagrange multiplier of the niche constraint in the frontier problem.

*Proof.* The KKT conditions of max a s.t. S(θ) = σ are ∇a = Gμ, and ∇A(σ) = μ by the envelope theorem. The best-response condition ∇a + Gŷ = 0 gives ŷ = −μ. ∎

Checked to 1e-6 against a finite-difference ∇A in a k = 3, d = 2 toy (`/tmp/inv/check.R`).

**So the local inverse is the derivative of the global one.** The Afriat potentials of the cross-site data are discrete values of A (Â_s = v_s − ⟨σ_s, y_s⟩, `imports` §3.2). The ŷ_i are its supergradients, and both are values of the conjugate pair (A, Ψ). Three scales follow.

| scale | condition | data |
|---|---|---|
| global, discrete | Σ_k ⟨σ_k, y_{k+1} − y_k⟩ ≤ 0 on every cycle (Rockafellar) | (y, σ) pairs |
| local | T1: θ_i on the frontier, k − d conditions. T2: one ŷ_i per species, d(n_s − 1) conditions | one sweep plus G per site |
| infinitesimal | dσ/dy = W symmetric and ⪰ 0; dŷ/dσ = −∇²A = W⁻¹ (checked: W·(−∇²A) = I to 5 decimals) | P7, or regression across sites |

Curl, the skew part of the site-to-niche map estimated across sites, measures non-integrability. Any optimiser gives a symmetric map, whatever a, T, levels or b.

**R1′ (trade-off invariance).**
- **T2 is immune to the trade-off.** Under affine sensing, along any trade-off T with rank(TᵀG) = d, ŷ_T = −(TᵀG)⁺Tᵀg₀ for every site. A wrong T moves ŷ but leaves it site-invariant.
- **ŷ itself is immune to T when θ is rationalisable in the full trait space.** If g₀ + Gŷ = 0, every such T returns the same ŷ.
- Both were checked numerically: a wrong T gave an identical ŷ at two sites, and on the frontier wrong-T and full-trait ŷ agreed to 1e-5.

### 3.2 R2. Two Afriat graphs, a 2 × 2 diagnosis

Run the cycle test on two graphs:
- **raw:** nodes (y_s, σ_is), the field each resident lives in;
- **corrected:** nodes (ŷ_i, σ_i), the field each species is adapted to.

The corrected pairs lie on the graph of ∂Ψ exactly when the species share one concave frontier and each is a global, not merely local, best response to its own ŷ. Lag has been absorbed into ŷ.

| raw graph | corrected graph | reading |
|---|---|---|
| passes | passes | consistent: the frontier is common and fields are tracked |
| fails | passes | **lag or migration load**: the ŷ_i − y_s are not a gradient |
| passes | fails | **frontier or trade-off error**, or a local-but-not-global optimum (a species on a dent of A). The raw test is T-free, the corrected one is not |
| fails | fails | **sensing error**, or site-specific physiology (a frontier that varies by site) |

Coexisting residents at one site are several σ at one y. That is legal, because coexistence is a kink of Ψ. With abundance weights, the mass (Kantorovich) form of the test applies.

**Ecological balance is a separate, level-dependent axis.**
- If every site is balanced under a common frontier, the Afriat potentials can be taken equal (v_s ≡ 0). The test is then the pairwise ⟨σ_s, y_t − y_s⟩ ≤ 0 for all s, t.
- So "cycles pass but rows fail" means ecological imbalance across sites, not maladaptation.
- Ecological lag is invisible to every trait test (T1, T2, cycles), and that orthogonality is itself a check.

### 3.3 R3. The loop identity: the money pump is the adaptation consumed

Let the field and traits run along a closed trajectory over one period, (y(t), θ(t)), with y(P) = y(0) and θ(P) = θ(0). Because ∮dφ(θ; y) = 0 and dφ = gᵀdθ + ⟨σ, dy⟩,

  ∮ ⟨σ, dy⟩ = −∮ gᵀ θ̇ dt,  and under the canonical equation  = −∮ gᵀ kM g dt ≤ 0.   (R3)

- The identity is exact. It needs neither affine sensing nor linearisation, since σ is the instantaneous ∂_yφ that the cut returns.
- **Checked:** on a nonlinear toy with non-affine sensing, −4.01499 against −4.01499 (`/tmp/inv/lag.R`).
- The left side is Fisher's "deterioration of the environment" integrated around a cycle of the community-made field. The right side is the total partial increase in fitness due to selection.

**What the discrete table shows.** Sampled at n dates, the table cycle Σ_k [T_{k,k+1} − T_{k,k}] tends to the left side.
- **Along history** it is ≤ 0 and passes.
- **Against history** (each population scored in the previous date's field) it tends to +∫gᵀkMg: a money pump of exactly that size.
- On the toy, the against-history sums for n = 2, 3, 4, 6 and 12 dates are −1.25, −0.73, +0.59, +1.69 and +2.97, against a limit of 4.01. Pairs and 3-cycles pass; 4-cycles and longer detect the lag.

**Linear response.** With L = −kMH and transfer function T(iω) = Gᵀ(iω + L)⁻¹kMG, take the loop y = u cos ωt + v sin ωt and z = u − iv. Then

  ∮⟨σ, dy⟩ = π Im(z̄ᵀ T(iω) z) = −πω (uᵀVu + vᵀVv) + O(ω²),  V = Gᵀ(−H)⁻¹(kM)⁻¹(−H)⁻¹G ⪰ 0.

- This was checked against Parseval's −∫gᵀkMg to every digit (`/tmp/inv/linear.R`).
- For a round loop the fitted map is M̂ = Re T + (Im T)J. Its skew-to-symmetric ratio is b = ω·tr V / tr W, which generalises `imports`' ωτ (0.4125 against 0.4167 predicted).
- **The effective lag time τ_eff = tr V / tr W** is the M-weighted response time of the niche.

**Detectability.**
- On a round loop with rotation δ = arctan b, a cycle of n sites fails iff δ > π/n.
- The same threshold holds for the direction-only (GARP) form with arbitrary positive κ_s, checked at n = 6.
- With entry noise ε, the signal-to-noise ratio of the best cycle is maximised at **n\* ≈ 3π/δ**, three times the threshold (exact: 47 at δ = 0.2, 14 at δ = 0.64).
- The loop's radius must then satisfy ρ² ≈ (3z ε/(4πδ s))·√(6π/δ) for a z-sigma detection, so the required radius grows as δ^{−3/4}.
- **Flat loops make lag visible to pairs.** For an aspect ratio ε, pairs detect the lag iff tan δ > 2ε/(1 − ε²) (critical ε = 0.100 at δ = 0.2 and 0.331 at δ = 0.64, both checked).
- **"Pairs are blind to lag" is a property of round loops.** A back-and-forth (1-D) history makes a hysteresis that pairs see.

**Identification.** Given the model's g(t) along the record (cut sweeps on the history row), R3 identifies ∫gᵀkMg from a level-free table cycle. That is kM projected on the realised selection path, the evolvability that site selection explicitly does not assume. The four-clocks programme lacked any handle on kM. Here it comes from a loop.

### 3.4 R4. Amplification at the compensation front (closed canopies)

Write σ_s = κ_s σ̃_s with κ_s ≫ 1 near break-even.

1. **Cycle signs survive** in the GARP form: free multipliers λ_s > 0, the same threshold on symmetric designs, and Afriat's efficiency index in place of the money pump's size.
2. **ŷ is homogeneous of degree 0** in a common gain on g and G, so a uniform κ cancels.
3. **The gain is not uniform when the front moves with traits.** Then G = κ∂σ̃/∂θ + ∇κ σ̃ᵀ. When ∇κ dominates, G is near rank one, and the local inverse identifies a single scalar, ⟨σ̃, y⟩. That is the field at the strategy's own compensation front, a light-compensation index L\* in Tilman's sense, with the hyperplane {y : ⟨σ̃, y⟩ = c} unidentified.
4. **This predicts F1.** A pool whose members each read a δ-like σ at their own front location spans many modes (closed d ≈ 4–5). Each member, though, is near rank one locally, and its loadings are set by the front's position rather than smoothly by traits (36% explained, against 84% open).
5. **The two scales do opposite things on closed canopies.** Curl tests keep power across the pool, where d ≥ 2, while per-species ŷ collapses to an L\* test.

### 3.5 R5. Certified identification (the hardest step)

**The local inverse is one Newton step for g(θ_i; ·) = 0.** Kantorovich's theorem certifies it. With β = ‖G_s⁻¹‖, η = ‖G_s⁻¹g_s‖, L a Lipschitz constant of G in y, and h = βLη:
- **if h ≤ ½,** the true ŷ is within (1 − √(1 − 2h))/(βL) − η of the one-site estimate;
- **if h > ½,** no local claim is made, and the site falls back to exact table cycles.

**L comes free from the landscape:** ‖G_s − G_t‖/‖y_s − y_t‖ across sites. In a non-affine toy, the sites with h = 0.45 and 0.39 had errors of 0.19 and 0.13 inside bounds of 0.56 and 0.32. The sites with h = 3.2 and 1.8 (errors around 1.8) were correctly refused (`/tmp/inv/kant.R`).

**Directions.** Report ŷ in G's singular basis, with interval e_g/s_r per direction, where e_g is P8's certified error on g.
- **Field directions with s_r below e_g / tolerance are unidentified.** These are exactly the directions of Ψ's flat curvature, where no heritable variation reads that field mode.
- **Near-neutral hydraulic traits are the opposite case.** A direction u with Hu ≈ 0 and Gᵀu ≈ 0 changes neither g's field part nor σ, so ŷ is immune to neutral drift along it, and T1 is uninformative there. Ill-conditioned H hurts forward prediction (θ\* = −H⁻¹(…)), not the inverse, which never inverts H.

### 3.6 R6. The price rows

Using `adjoint`'s results (p\*_k = λ_{q_k}/λ_P; the cut zeroes the price of a purely shared good):

1. **A shared good's ESS price is zero in every field.** It is field-invariant, so it lies in a T1-type direction. A fitted λ_o ≠ 0 therefore cannot be lag. It is privacy, a private water channel, or error.
2. **Privacy.** ŝ = (λ_obs − p\*_cut)/Δp_s. Two-period toy with N sharers and privacy s: own share r = s + (1 − s)/N, cut price 1/N, kept price 1, so ŝ = s for every N and every supply W.
   - In the mean field, ŝ = 1/N_eff: **an observed marginal water price over the commons price gives the effective number of individuals sharing a root zone.**
   - The test is ŝ constant across a species' sites while Δp_s varies with stand density.
3. **TF24's cost_scale prices a private cost.** Θ̃ is "carbon actually forgone" (`tf24_strategy.h`, around line 150), so its p\* depends on the field. The fitted cost_scale imposes p̄_W(y) = p_fit: one hyperplane in y per price, with normal ∂p̄/∂y from P7. That is y_leaf made concrete.
4. **Stage bias.** Calibration on adults estimates ⟨p\*⟩_adult. The ESS value is ⟨p\*⟩_W, and W is largest where λ_P is huge, at the front. The predicted bias is ⟨p\*⟩_adult − ⟨p\*⟩_W, with its sign from the tape. On closed canopies, W, σ and ŷ all read the same front (R4).

### 3.7 R7. The Le Chatelier reversal

**Field coordinates.** Let rungs R ⊂ R′ each be maximised with the other traits held at their y₀ optimum. Then Ψ_R′ − Ψ_R ≥ 0, with equality at y₀, so

  Δ²_h Ψ_R(y₀) ≤ Δ²_h Ψ_R′(y₀) for every h.

- This holds for plastic ⊂ intraspecific ⊂ pool (max over species, kinks included).
- In the smooth case it reads W_R ⪯ W_R′, with the gap a Schur complement.
- It orders the response of each selected index z_u = (Gu)ᵀθ to the field along u.

**Supply coordinates.** Use the making map K = y + CN with residents balanced, so ⟨σ_j, dy⟩ = 0 for each resident j. Then

  dy = P_m dK,  P_m = I − C(ΣᵀC)⁻¹Σᵀ,  dσ_j/dK = W_j P_m,

where Σ = [σ_1 … σ_m] and C = [c_1 … c_m] are the residents' niches and per-capita impacts.

- Adding a species nests the faces: range(P_{m+1}) ⊂ range(P_m), and rank(P_m) = d − m.
- With aligned impacts (the convex regime) the P_m are orthogonal, so P_{m+1} ⪯ P_m and E‖W_jP_m dK‖² = σ_K² tr(W_j² P_m) decreases with m.
- **The ordering is in rank and in mean square, not pointwise.** A 3-D case with W anti-aligned across a face gives a larger response after a species is added.
- Trait margins raise W (Le Chatelier, field side). Species margins lower the rank of P_m (response conservation, supply side).
- **The community-weighted mean keeps an abundance channel,** dN = (ΣᵀC)⁻¹Σᵀ dK, of rank m. Within a saturated type the field is pinned while CWM moves, so the CWM–field slope is formally unbounded: the kink of Ψ.

## 4. The ecology

1. **"Is local best?" is a matching question, and its answer depends on the shape of history.**
   - Sympatric-allopatric contrasts are 2-cycles.
   - On a drought → dieback → recovery loop, a population lagging by phase δ passes every pair and every cycle shorter than π/δ.
   - Its rotation against history raises total ln R′ by exactly the fitness adaptation gained around the loop.
   - On back-and-forth histories, such as single droughts, the same lag shows as pairwise hysteresis.
   - So conflicting local-adaptation verdicts on the same data (Bucharova et al. 2017) may partly track whether site histories were loops or lines.
2. **Evolvability from a table.** Resurrection studies (Franks et al. 2007; Rauschkolb et al. 2022) and time-shift designs (Blanquart & Gandon 2013) compare dates pairwise. Scored around a closed field loop, R3 converts them into an estimate of ∫gᵀkMg: genetic variance along realised selection, in fitness units, with no levels.
3. **Climatic debt resolves into five vectors.** These are:
   - ecological imbalance (unequal Afriat potentials; levels only);
   - evolutionary lag (ŷ − y_s, aligned with the filtered record, curl on loops);
   - trade-off error (shared across species, T2 still holds);
   - constraint (a lineage-specific T1 residual, site- and time-invariant);
   - sensing error (T2 and reciprocity fail without structure).
4. **Closed forests are single-index communities per species but multi-index as pools.** Selection reads each strategy's compensation light. That is why closed-canopy loadings are poorly predicted by traits, and why adult-calibrated EEO prices should be most biased there.
5. **Water saving measures neighbourhood size.** Observed marginal water costs should scale with 1/N_eff (root-zone exclusivity, clonality, monodominance), not with aridity once Δp is removed.
6. **Weak trait–climate relations are a coordinates effect.** Within-species trait responses to resource supply vanish in mean square as richness approaches d. CWM responds through abundances. Trait–field responses are ordered plastic ≤ intraspecific ≤ turnover. Weak global CWM–climate fits (Bruelheide et al. 2018) are what this predicts for supply variables, and they should not hold for realised-field variables.

## 5. Why us

| result | advantage it needs |
|---|---|
| R1 and R2 | σ_is at every resident from the cut (P3) on real records; G from P7 or mode-seeded sweeps. Without reverse mode, σ over height × patch age × layer × time is thousands of runs |
| R3 | a field history y(t) and the cut's σ(t) and g(t) along it, on a history row with no equilibrium; costates for the reproductive-value weights |
| R4 | the front's κ and ∇κ, read from per-cohort costates (where λ_P concentrates) |
| R5 | P8's certified e_g; G at many sites for the Kantorovich L |
| R6 | the kept against cut costate ratios at leaf control nodes (`leaf_profit_` and `leaf_soil_consumption_` are tape nodes); an inner optimum that is differentiable |
| R7 | W on subsets of traits, including the leaf's inner solve as the plastic rung |

A theorist has W only in a toy. A modeller cannot hold the field while perturbing.

## 6. Prior art and the exact delta

- **Afriat (1967), Varian (1982), Rockafellar (1970), Bartz et al. (2007), Jerison & Jerison (1996).** The cycle tests, the rotation threshold and discrete Slutsky symmetry are known. Lagrange multipliers as shadow prices, and the envelope gradient of a value function, are textbook (R1 is Roy's identity and Hotelling's lemma, transposed).
- **Lande & Shannon (1996) and Lynch & Lande (1993):** the phase lag of tracking in a periodic environment.
- **Fisher's environmental deterioration** (Grafen 2020; Engen & Sæther 2024 note that it blocks inferring rates of response from the theorem). R3 is ∮dφ = 0 split by Fisher's partition. It is trivial in form; what is new is its use as an estimator, from a level-free table, of what the deterioration term usually hides.
- **Time-shift designs** (Gaba & Ebert 2009; Blanquart & Gandon 2013; Koskella & Parr 2015) are pairwise in time. **Resurrection studies** compare ancestors with descendants.
- **Kantorovich's theorem** is classical.

**Delta.** I found no source that does any of the following:
- treats the field of adaptation as the frontier's multiplier, linking the inverse forms;
- runs the raw and corrected Afriat graphs as a lag-against-frontier diagnosis;
- reads the money pump of a looped transplant or resurrection table as integrated selection power, with the 3π/δ design rule and the flat-loop hysteresis threshold;
- gives the front-induced rank-one collapse of G;
- certifies inverse optimality with Kantorovich using cross-site G;
- states the rank and mean-square form of the Le Chatelier reversal.

Searches for cyclical monotonicity in local-adaptation work returned only the sympatric-allopatric literature. The searches were not exhaustive.

## 7. Worked cases (all checked; scripts in `/tmp/inv/`)

| case | result | script |
|---|---|---|
| (a) ŷ = −∇A(σ) (k = 3, d = 2) | ŷ = (−0.084162, −0.163967) from the multiplier, from finite-difference −∇A, and from two sites (1, 2) and (−3, 0.5). W(−∇²A) = I | `check.R` |
| (b) trade-off invariance | wrong T: ŷ = (0.64525, −0.23393) at both sites (T2 holds) against (−0.474, −0.186) with T = I. On the frontier both give the true ŷ | `check.R` |
| (c) loop identity, nonlinear, non-affine | ∮⟨σ, dy⟩ = −∫gᵀkMg = −4.01499. Against-history cycles fail from n = 4 and approach +4.01 | `lag.R` |
| (d) linear lag | exact = Parseval at ω = 0.01, 0.1, 0.5; first order exact to 2e-5 at ω = 0.01; skew ratio 0.4125 against ω trV/trW = 0.4167. Flat-loop and GARP thresholds as stated. n\* = 47 and 14 = 3π/δ | `linear.R` |
| (e) Kantorovich | certified bounds hold where h ≤ ½; refusal where h > ½ | `kant.R` |
| (f) 3-cycle on a raw table | `imports` I4: D₁₂ = D₂₃ = D₃₁ = +1, reverse entries −1.5. Every pair passes; the 3-cycle sums to +3. By R3's threshold this is a rotation beyond 60° (b > 1.73) | — |

## 8. What it opens

**Predictions on TF24, at one recording and one cut sweep per stand (plus G).**
1. **λ_o.** g_{λ_o} = 0 at λ_o = 0 on long drought and closed (cut), while dF/dλ_o ≠ 0 (kept). That is R6.1 and `adjoint` case (c).
2. **Site-invariance of ŷ** for the lma-0.32 resident across long drought and seasonal, on the open-stand 3-mode basis, within the Kantorovich radius. h should be ≤ ½ there, since the open stands are near affine. On the closed stand, predict h > ½ and a near rank-one G aligned with the front.
3. **Reciprocity.** W at the reference community is symmetric to P8 tolerance.
4. **The plastic rung.** Freezing the leaf at its y₀ optimum lowers ∇²Ψ.

**Predictions on existing data.**
- Provenance and resurrection tables with looped histories pass pairs and fail cycles of length at least π/δ, against history.
- ŝ is invariant across sites of one species, and scales with root-zone exclusivity.
- Within-species trait–supply slopes fall in mean square with richness. CWM–supply slopes do not.

**First steps.**
1. Rebuild σ_s and y_s from `spikes/field-dimension-066/`'s perturbation runs, and measure how often the first-order cycle mis-signs against exact entries.
2. Simulate R3 on TF24: a recorded drought → dieback → recovery loop and a canonical-equation tracker in lma. Check the identity with the model's own g(t).
3. Synthetic-truth recovery of the 2 × 2 diagnosis (`site-selection.md` §7 step 3).

**Links.**
- R1 gives O4's EEO bracket its gradient.
- R2 replaces the four-readings table.
- R3 supplies the kM that O5 lacks.
- R6 is O10 at the control nodes.

## 9. Where it might break

- **Closed loops.** R3 needs θ periodic. A trend plus a loop leaves a boundary term φ(end) − φ(start), which is a level, so detrended loops or repeated cycles are needed.
- **A canonical-equation-type tracker.** With gene flow, θ̇ = kMg + migration, and the identity counts migration as "adaptation": curl from advection and curl from lag are confounded.
- **A common frontier across sites** needs every direct driver (VPD, temperature, CO₂) in y. Unmodelled soil or pathogen effects fail both graphs.
- **Non-concave A.** The corrected graph cannot tell a species on a local peak from trade-off error.
- **Small samples.** Afriat potentials are only bounded. Long cycles accumulate noise, so 3π/δ sites is costly for small δ.
- **Front dominance** can make G rank one everywhere on closed canopies, leaving only L\* identified.
- **The privacy interpolation is first order** (Taylor–Frank). The ŝ = 1/N_eff reading is mean-field.
- **The Le Chatelier reversal is local and in mean square.** It fails pointwise, and fails generally with misaligned impacts, where P_m is oblique.
- **Truncated costates** near the end of a history row bias prices there.

**Sources:**
- [Bucharova et al. 2017, "Are local plants the best for ecosystem restoration?"](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5743477/)
- [Koskella & Parr 2015, time-shift in the phyllosphere](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4528495/)
- [Gandon et al. 2008](https://mast.queensu.ca/~tday/pdf/GandonEtAl2008.pdf)
- [Grafen 2020, a completion of Fisher's fundamental theorem](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7820154/)
- [Engen & Sæther, Am. Nat. 2024 summary](https://www.amnat.org/an/newpapers/Nov-2024-Engen.html)
- [Rauschkolb et al. 2022, New Phytologist (resurrection, cites Franks 2007)](https://www.ufz.de/export/data/global/267215_Rauschkolb_2022_NewPhytologist.pdf)

Cited from memory and not checked: Afriat 1967, Varian 1982, Rockafellar 1970, Bartz et al. 2007, Jerison & Jerison 1996, Lande & Shannon 1996, Lynch & Lande 1993, Blanquart & Gandon 2013, Gaba & Ebert 2009, Franks et al. 2007, Bruelheide et al. 2018, Taylor & Frank 1996, Tilman 1982.

**Files:**
- scripts: `/tmp/inv/check.R`, `/tmp/inv/lag.R`, `/tmp/inv/linear.R`, `/tmp/inv/kant.R`
- read: `/home/a/dev/plant-dev/.claude/worktrees/workflows/docs/review/{process,site-selection,assembly-geometry}.md`, `/home/a/dev/plant-dev/.claude/worktrees/workflows/spikes/field-dimension-066/README.md`, `/home/a/dev/plant-dev/.claude/worktrees/workflows/plant/inst/include/plant/models/tf24_strategy.h`