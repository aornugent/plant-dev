# Final curation: a portfolio from the two-round search

## Summary for the research lead

The search's most important outcome is that it overturned its own leading hypothesis, using measurements on TF24.

- **Where the knife edge comes from.** The closed-canopy gain d ln R′/d ln P ≈ 3.5e3–7.6e3 comes from a *tie* in the first birth-date node of the uniform 108-node schedule. It does not come from the reserve regulariser ε or from an understorey compensation front.
- **What remains once that node is resolved:**
  - the held-field gain is g_P ≈ 101, linear and symmetric;
  - the kept (stand) derivative is F_P ≈ 11.6;
  - there is a real ecological boundary layer in birth date, the *founder window*, with scaling laws in seed rain.
- **Consequences for the rest of the portfolio:**
  - every closed-canopy number in the record is suspect until rerun on a refined schedule: F1, A on two-closed-31 and the leaf-table verdict;
  - the "front" mechanism, which three proposals leaned on, is demoted from explanation to hypothesis.

The ideas below are ranked as needles: novel, significant, and deliverable only with our advantages. I rank atomic ideas rather than the three documents, because the best material sits across them.

---

## 1. The ideas, ranked

### Rank 1. The founder window and the tie lemma

*Source: Developed 1.*

**What it is.** Invasion fitness integrates over birth date, R′ = ∫ρ(s)W(s)ds.
- **On closed stands, W(s) has a boundary layer at s = 0.** It is about 13 days wide and carries about 39% of R′. W(0) ≈ 988 falls to 0.1 by 135 days.
- **Three scaling laws in seed rain b,** measured over a 4× range:
  - amplitude W₀ ∝ 1/b (a lottery for a canopy whose final occupancy is fixed by self-thinning);
  - width τ_f ∝ b^(−1/2) (lateness costs leaf area ahead × height gap ∝ bs²), with collapse onto s√b in the core;
  - inner mass R′_in ∝ b^(−3/2).
- **The tie lemma.** A zero-spread cohort node at the canopy top gives a rare type a held-field gain that is exponential in the tied leaf mass. Its upside is bounded (open light) and its downside is not, because it sinks into the block's foliage. The resident never feels this, because its whole block moves together.
- **Selection on head start is a boundary term:** g_H = ρ₀W(0⁻)/(ḣ₀R′) ≈ 11 per year of head start on the resolved stand.

**What is genuinely new, against prior art.**
- **Known:**
  - seed-size games with asymmetric seedling competition (Geritz 1995; Rees & Westoby 1997; Geritz, van der Meijden & Metz 1999);
  - lottery competition and the storage effect (Chesson & Warner 1981), and a continuous size-structured lottery model for forest trees (Yuan & Chesson, ESA 2013/2015 abstracts and a 2014 dissertation; found by search, content not read);
  - priority effects and emergence timing (Fukami 2015; Mercer et al. 2011);
  - first-regenerated dominance (Kulha et al. 2023);
  - initial floristic composition (Egler 1954);
  - size bimodality (Huston & DeAngelis; Weiner).
- **Numerical prior art the search did not cite:** de Roos's Escalator Boxcar Train carries within-cohort variance and a boundary cohort for recruits (from memory). Zero-spread cohort nodes are a known approximation. What is not known is that, at the canopy top, the approximation is *dynamically unstable for the invader and invisible to the resident*.
- **New:**
  - the inner/outer decomposition of invasion fitness in birth date, derived from radiative transfer rather than an imposed step competition function;
  - the three scaling laws;
  - the tie lemma as the cause of a measured artefact of order 1e4;
  - the head-start gradient as a boundary term;
  - δ = 0 (exact lottery) for the window.

**What it explains or predicts.**
- It explains the A.4 jump (+7.40 / −39.85), the closed-against-open gain gap and the closed stand's sensitivity to schedule thinning. All three are one artefact.
- It reveals that the standard schedule mis-states closed F by 0.165, about 0.11 in ln b\*.
- **Ecological predictions:**
  - disturbance-cued arrival (serotiny, fire-cued germination, seed banks) is under strong selection;
  - obligate seeders with synchronous germination face purifying selection on emergence speed and seed mass that scales as 1/w (spread of emergence), with an asymmetric step;
  - window width and inner share fall as b^(−1/2).
- **A walked-past observation:** the resident's dF/d ln b ≈ −1.43, close to the window's −3/2. The closed equilibrium's density regulation is set by the founder lottery itself.

**Advantages it rests on.**
- Per-node decomposition of ln R′ with a held field. A coarse forward simulator sees a knife edge and cannot attribute it.
- Held against kept on one engine.
- Certified, designable node schedules: τ_f ∝ b^(−1/2) is known before the run.
- Per-node costates would give the density of selection inside the window directly.

**First step and test.**
1. Rerun the closed-canopy record (F1 spectra, two-closed-31's A, the leaf-table bias) on a schedule refined at s = 0. Report what survives.
2. Run the two predicted, uncomputed checks:
   - an invader whose initial height is raised by ḣ₀ × 1 day should gain about 0.03 in ln R′;
   - one tape sweep for ∂ ln R′/∂ ln ε should give |·| ≲ 1 on the resolved schedule.
3. The ecological test: give the founders an arrival spread w_s, either by a distributed seed pulse or EBT-style within-cohort variance. The laws should hold with τ_f replaced by max(τ_f, w_s), and the head-start gradient should scale as 1/w_s.

**Confidence.**
- **High** that the 7.6e3 is a schedule artefact (direct, controlled measurement).
- **Moderate** on the scaling laws: one stand, one record, heuristic derivation, and 39% uses trapezoid rather than patch-age weights.
- **Low-to-moderate** that the window has its *modelled width* in nature. Post-fire emergence in eucalypt forests spreads over months: a WA study found emergence peaking about 144 days after an autumn fire and none within 200 days of a spring fire. Real w_s ≫ 13 days is likely, so in nature it is the w_s-limited regime that matters.

### Rank 2. Closure turns light competition into a lottery

*A synthesis across Developed 1 §3.6 and §3.7, Developed 2 Proposition 5, and the measured commons ratio.*

**What it is.** Two independent routes reach the same statement: in closed, self-thinning patch ages, light regulates composition only as a lottery.
- **The founder window is an exact lottery,** since W₀ ∝ 1/(total arrivals), so δ = 0.
- **Constant final yield annihilates light's dissipative mode.** If total leaf area does not respond to seed rain (Kira, Ogawa & Shinozaki), then Õ_j = O_j − p_j O_tot and A(a)·1 = 0 exactly.
  - What remains has eigenvalue (½ − Π₁₂)(L₁L₂/L_tot)(T₁ − T₂).
  - Composition is stable iff the taller species has the larger total light elasticity.
- **The measured commons ratio F_P/g_P = 11.6/101 ≈ 0.115.** About 89% of a private carbon advantage is displacement.

Corollary: light-mediated coexistence in forests must come from one of three places:
- pre-closure ages (the age-Gram term, M3);
- water;
- variation in founding conditions across disturbance events, which is a storage effect on the founder lottery, with long-lived adults as the storage.

**What is new.**
- The lottery and storage-effect logic is Chesson's, and the size-structured lottery is Yuan & Chesson's.
- Constant final yield is from 1953.
- The search found no source that reads constant final yield as the annihilator of light's stabilising mode, or that derives the lottery from canopy mechanics in place of assuming it. The joint claim is new: closure removes a regulating dimension, so the Meszéna count drops at closure.

**What it predicts.**
- Closed patch ages *destabilise* a bank-recruiting understorey species against a taller canopy species.
- CO₂ or nutrient fertilisation of a self-thinning stand mostly reshuffles winners and raises mortality, rather than raising survivorship.
- Under real weather records, coexistence in closed stands should scale with the variance of founding conditions across disturbance dates.

**Advantages it rests on.**
- The kept sweep's β columns on ln I(z, a) give ∂L_tot(a)/∂β_j along age directly: Proposition 5's test.
- Held against kept gives the commons ratio exactly.
- Real daily records with disturbance-date phase averaging (workflows.md §2) make founding variation *derived*, not imposed. A toy lottery model has to assume it.

**First step and test.**
1. On the resolved closed stand, measure ∂L_tot(a)/∂β_j. It should go to about 0 after closure.
2. Compute the commons ratio on the tape rather than by finite difference of PSCALE.
3. Phase-average a two-species resolved stand over disturbance dates within the real record, and decompose the invasion growth rate into Chesson's storage-effect term.

**Confidence.**
- **Moderate.** The two derivations are independent and agree.
- Proposition 5 assumes exact constant final yield, and TF24's 40-year mosaic mixes in open ages.
- The storage-effect leg is untested.

### Rank 3. The sensing–overhead law: where light coexistence comes from

*Source: Developed 2, Theorem 1 and Corollaries 1–4.*

**What it is.**
- **The exact form.** Light competition is A_ij = ⟨u_i, O_j⟩: sensing u_i (the cut's zeroed adjoint × I) against overhead leaf area O_j, over height × patch age.
- **The niche overlap:** ρ² = E_{Ũ₁}[Λ] · E_{Ũ₂}[1/Λ], with Λ = O₂/O₁.
- **Corollaries:**
  - Jensen: species read at the same place are at best neutral, and otherwise in founder control.
  - The reflection case under alignment: ρ² = 1 − 4κ² (I re-derived this; it is exact). Stratification therefore stabilises at O(κ²) while it creates an O(κ) fitness difference, so near-co-stratified species are quasi-neutral with compositional memory of order 1/κ².
  - Point sensing: coexistence ⇔ the taller species' fitness is read higher.
  - A Cauchy–Binet / total-positivity count of light-coexisting species: the longest chain whose sensing locations are ordered like their overhead dominance. This is a TP count, not a rank.
- **No priority effects under aligned light.** Developed 2 states this from 20,000 random cases. A one-line proof exists:
  - suppose DΠx = λx;
  - then x\*Πx = λ x\*D⁻¹x;
  - and Re(x\*Πx) = ½|1ᵀx|² ≥ 0;
  - so Re λ ≥ 0.

  This should be stated as a lemma.

**What is new.**
- **Known:**
  - Chesson's ρ and f;
  - Tilman's and Leibold's impact/requirement vectors;
  - Letten, Ke & Fukami (2017), who link modern coexistence theory and contemporary niche theory through impact and sensitivity (title confirmed by search; content from memory);
  - Koffel, Daufresne & Klausmeier (2021), the impact/requirement niche;
  - Chesson (1990), MacArthur ρ as a Cauchy–Schwarz-type overlap;
  - May–Leonard α + β = 2;
  - Adams, Purves & Pacala (2007), PPA neutrality;
  - Nevai & Vance (2007), canopy partitioning;
  - Karlin's total positivity;
  - Villani's hypocoercivity.

  Developed 2's prior-art table omits Letten et al. and Koffel et al. They must be cited, because "ρ from sensing and impact" is their framework.
- **The delta:**
  - the continuous height × age form with *Beer–Lambert overhead*;
  - the reverse-Jensen bound when sensing coincides (Chesson 1990's Cauchy–Schwarz runs the other way when sensing is proportional to impact; here it is sensing coinciding *across species* that forces ρ ≥ 1);
  - the reflection law 1 − 4κ²;
  - the TP count;
  - the correction that M2's "stratification is zero-sum" was a metric artefact.
- **Kohyama reconciled:** as concordant ordering plus the age term. This rests on secondary sources, and the primary papers must be read.

**What it predicts.**
- Founder control by light ⇔ the taller species is read lower.
- Grady et al. (2020)'s empirical neutrality above the sapling layer is the reflection identity.
- Co-stratified pairs have 1 − ρ² = 4κ̄².

**Advantages it rests on.** u_i(z, a) as a *function* is identifiable only from the tape. From A alone, any 2 × 2 matrix with det ≥ 0 fits an aligned tournament, so the law is untestable without adjoints. This is the purest example of "a theorist has no u, a simulator has no u over (z, a)".

**First step and test.**
1. On a *resolved* closed pair (§7(a)'s A was measured on the uniform schedule and must be redone), form u_i from the cut and O_j and Õ_j from the β columns.
2. Report E_Ũ[Λ] by block: pre-closure light, closed light, water.
3. Check the predicted Pr(Z₂ > U₁) and the u-weighted L₂/L₁.

**Confidence.**
- **High** on the algebra (Theorem 1 is a rearrangement of an exact identity, and Corollary 2 is checked).
- **Moderate** on the TP count, which gives sufficiency only, for n ≥ 3.
- **Low** on the Kohyama reconciliation until the primary sources are read.

### Rank 4. The loop identity: evolvability from a looped transplant table

*Source: Developed 3, R3.*

**What it is.**
- **The identity.** Around any closed loop of field history, ∮⟨σ, dy⟩ = −∮gᵀθ̇ dt, which equals −∮gᵀkMg dt under the canonical equation. It is exact, needs no affine sensing, and was checked on a nonlinear toy to six digits.
- **Reading it from a table:**
  - a table arranged around the loop has a cycle sum that converges to the left side;
  - scored against history, it is a money pump of size ∫gᵀkMg.
- **Corollaries:**
  - pairwise contrasts are blind to round-loop lag;
  - flat loops make lag visible to pairs;
  - the optimal cycle length is n\* ≈ 3π/δ (I checked the arithmetic: 47 at δ = 0.2);
  - τ_eff = tr V / tr W generalises ωτ.

**What is new.**
- **Known:**
  - R3 itself is ∮dφ = 0 partitioned à la Fisher, which is trivial in form;
  - phase lag in periodic tracking (Lande & Shannon; Lynch & Lande);
  - time-shift and resurrection designs, which are pairwise in time;
  - Fussmann & Kopp (2023): transplant inference misleads under ongoing adaptation;
  - Afriat and cyclical monotonicity.
- **Unclaimed in the literature I could find:** using the integrated deterioration term as an *estimator* of evolvability along realised selection from a level-free table, with design rules for loop shape and length. A search found no application of Afriat or cyclical monotonicity to local-adaptation data.
- I could not verify the Blanquart & Gandon (2013) time-shift paper, which is the nearest prior art. Its decomposition must be checked before claiming the delta.

**What it predicts.** Provenance and resurrection tables with looped histories pass pairs and fail cycles of length ≥ π/δ. Conflicting "is local best?" verdicts (Bucharova et al. 2017) partly track whether site histories were loops or lines.

**Advantages it rests on.** g(t) along a history row (cut sweeps, no equilibrium) is needed to turn the table's scalar into kM projected on the selection path. A forward simulator has y(t) but no σ or g. A theorist has σ but no real y(t).

**First step and test.**
1. Simulate a recorded drought → dieback → recovery loop on TF24, with a canonical-equation tracker in LMA.
2. Verify the identity with the model's own g(t).
3. Then ask whether any existing resurrection series spans a closed field loop.

**Confidence.**
- **High** on the identity.
- **Moderate** on practicality. Detrending (a trend leaves a level-dependent boundary term), migration confounding and the noise cost of long cycles are serious.

### Rank 5. The field of adaptation as the frontier's multiplier, with a 2 × 2 Afriat diagnosis

*Source: Developed 3, R1, R2, R5 and R1′; it absorbs eeo-data's D2 and D4.*

**What it is.**
- **R1:** ŷ_i = y_s − G_i⁺g_is = −∇A(σ_i), the Lagrange multiplier of the niche constraint. The local inverse is the derivative of the global (Afriat) inverse. Checked to 1e-6.
- **Three scales of one integrability condition:**
  - cycles (global);
  - T1 and T2 (local);
  - symmetry of W = −GᵀH⁻¹G (infinitesimal).
- **The 2 × 2 diagnosis.** Running the cycle test on raw and on corrected graphs separates:
  - lag;
  - frontier or trade-off error;
  - sensing error.
- **Robustness:**
  - T2 is immune to a misspecified trade-off;
  - Kantorovich's theorem certifies ŷ, using cross-site G for the Lipschitz constant, and refuses where h > ½.

**What is new.** R1 is Hotelling and Roy transposed. The delta lies in:
- the raw-against-corrected diagnosis;
- trade-off invariance as the answer to site-selection.md's main weakness;
- Kantorovich certification;
- the front-induced rank-one collapse of G (R4), which is now conditional (see Caveats).

**What it predicts.**
- ŷ for one species is site-invariant across long drought and seasonal sites on open stands, inside the certified radius.
- Climatic debt splits into five vectors.

**Advantages it rests on.** σ at every resident from the cut, G from forward-over-reverse sweeps, and P8's certified e_g.

**First step and test.**
1. On the open-stand 3-mode basis, compute ŷ for the lma-0.32 resident at two sites.
2. Test T2 inside the Kantorovich radius.
3. Run a synthetic-truth recovery of the 2 × 2 diagnosis.

**Confidence.**
- **High** on the mathematics.
- **Moderate** on identifiability in TF24's closed regime, which needs the resolved schedule.

### Rank 6. Canopy acclimation and coexistence: where EEO meets coexistence theory

*Source: Developed 2 §4.5 and §7(e), reversing M6.*

**What it is.**
- With capacity V ∝ I^γ, γ = k_N/k_L, the per-leaf elasticity is ∝ I^(2γ−1). So γ = ½ is exact alignment.
- Full acclimation (γ = 1, the EEO optimum) lifts the tall species' sensing out of the shared band and *promotes* light coexistence. Sun-saturated crowns erode it.
- Observed canopies sit near γ ≈ 0.3–0.6 (from memory, unchecked), which is also where game-theoretic ESS nitrogen gradients sit (Anten; Hikosaka & Anten).

**What is new.** The optimal-against-ESS nitrogen literature exists. Its effect on *community coexistence*, and the identification of γ = ½ as the reflection point, appear new.

**Why it matters.** It is the cleanest bridge between EEO, which ignores frequency dependence, and coexistence theory. It also suggests that canopy-level competition may hold canopies at alignment.

**Advantages it rests on.** Only partly ours today. It needs a depth-resolved, differentiable leaf, which TF24 lacks: its crown-mean leaf is the γ = 1 case.

**First step.** Check the field range of k_N/k_L. Then, in a two-crown toy with an exact photosynthesis model, test whether ρ is monotone in γ across saturation regimes; one exception was found at X = 4, θ_top = 3.

**Confidence.** Low to moderate. The model is a sketch (rectangular hyperbola, uniform crowns), and M6's opposite sign shows how sensitive the conclusion is to assumptions.

### Rank 7. Endogenous prices: privacy, plasticity and stage bias

*Source: adjoint A1–A5, Developed 3 R6.*

**What it is.**
- **Prices from costates.** EEO's inner optimisation is Pontryagin with costate ratios frozen, so p\*_k = λ_{q_k}/λ_P.
- **Kept and cut as relatedness.** Kept and cut are relatedness 1 and 0 in a Taylor–Frank privacy interpolation.
- **Estimands:**
  - ŝ = (λ_obs − p\*_cut)/Δp, which reads, in mean field, as 1/N_eff: the number of individuals sharing a root zone;
  - fixed-price regret ½𝒲[(p̄ − p)² + Var_W(p\*)]. Plasticity is selected where the *costate ratio* varies, not where the environment varies;
  - stage bias: EEO prices calibrated on adults are biased toward ⟨p\*⟩_adult and away from ⟨p\*⟩_W.

**What is new.** Much of this is already in theory.md F.4 and C.4, and in Wolf, Anderegg & Pacala (2016), Metz, Staňková & Johansson (2016), and Gersani et al. (2001). The new parts are:
- the K-good form;
- kept and cut as relatedness endpoints;
- the 1/N_eff estimand;
- the regret decomposition.

**Advantages it rests on.** `leaf_profit_` and `leaf_soil_consumption_` are tape nodes, and the costate ratios at both sweeps are free.

**First step.** Run the λ_o test (g_{λ_o} = 0 at λ_o = 0 under the cut, dF/dλ_o ≠ 0 kept) on the long-drought stand. Then compute the stage-weight W by cohort.

**Confidence.** High on the algebra, moderate on ecological reach. The stage-bias claim previously relied on λ_P peaking at suppressed cohorts near the front. Since Developed 1 found ordinary gains there (90–140), the weight may instead concentrate in founders. Recompute it.

### Rank 8. The Le Chatelier reversal

*Source: imports I5, Developed 3 R7.*

**What it is.** The two coordinate systems give opposite orderings:
- **In field coordinates,** response curvature is ordered plastic ⪯ intraspecific ⪯ turnover (Schur complements).
- **In supply coordinates,** within-type trait response falls in rank (d − m) and in mean square as richness rises (response conservation).

So weak global CWM–climate relations (Bruelheide et al. 2018) are a coordinates effect, and should not hold against realised-field variables.

**What is new.** The pairing of Le Chatelier with response conservation, as a reversal. It holds in rank and in mean square only, not pointwise, and only with aligned impacts.

**Advantages it rests on.** The realised field y_s as a measurable covariate exists only through the platform.

**First step.** On assembled TF24 communities at 1 to d species, regress within-species traits on supply and on field. Predict opposite trends with m.

**Confidence.** Moderate. It holds in mean square and under orthogonal P_m only.

### Rank 9. Reserve-front ecology, transposed

*Source: ecology E1–E10 and Developed 2 Proposition 6, demoted by Developed 1 §3.7.*

**What survives.**
- **The knife's width is ecological for trees above about 2 m.** There, S_max dominates and ε drops out, giving width S_max/T_deficit.
- **Self-thinning through starvation pins the depth of the canopy's seasonal reserve crash** rather than an understorey carbon balance. Canopy trees swing between P ≈ +65 and −150 kg/yr, and μ reaches 3–5.5/yr in dry phases.
- **Proposition 6's convex μ̂** (μ̂″ ≈ 0.8/ε²) still gives a large Jensen term *wherever* a cohort sits near P = 0. Under fluctuation it lifts the front and softens the knife.
- **FF16's smooth carbon-balance hazard is a ready-made control experiment** (E3).

**Status.** The original claim, that the 7.6e3 is a front, is refuted for these runs. The transposed claim, that thinning pins reserve-crash depth, is new and unexplored.

**Confidence.** Low as a mechanism for closed-canopy selection. Moderate as a description of TF24's thinning.

---

## 2. Connections

**To the already-worked material.**

- **Projection and convexity (assembly-geometry).** A = ⟨u, O⟩ (rank 3) is the sensitivity–impact pairing whose symmetric part defines the convexity of the non-invadable set. "Stabilisation as convexity" becomes "stabilisation as likelihood-ratio concordance between sensing and overhead".
  - The reflection law says the aligned Beer–Lambert set is convex only to O(κ²).
  - Constant final yield (rank 2) makes a face of the set flat: a neutral direction, a kink of Ψ.
- **Response conservation.** Closure (rank 2) removes a regulating dimension, so d drops at closure and d − m drops with it. Rank 8 is response conservation's mirror in field coordinates. The TP count (rank 3) is a second species count alongside Meszéna's rank count, and the two need not agree.
- **The Legendre duality.** Rank 5's ŷ = −∇A(σ) is the duality made local. The Afriat potentials are discrete values of A, and the ŷ_i are its supergradients. Rank 4 is the duality's dynamic counterpart: off equilibrium, the cycle sum around a loop is the adaptation consumed rather than zero.
- **The mean-field game.** The founder window is a boundary layer of the value function V\* at s = 0, an HJB singular perturbation in birth date. The tie lemma is a reminder that the MFG's mean-field limit fails at a tie, where a rare type's best response is discontinuous. Every MFG of height competition needs individual noise (w) as a regulariser, and w is then an ecological parameter, not a numerical one.

**Among the new ideas.**

- **The founder window, the lottery and coexistence form one chain:**
  - the window is a lottery (rank 1);
  - closed ages are lotteries (rank 2);
  - stabilisation must come from the sensing–overhead concordance at pre-closure ages (rank 3), from water, or from founding variance;
  - founding variance under real records is a fourth "clock" for eeo-data, and it is where the two workflows (regime and history) meet.
- **The demoted front was the hinge of three proposals.** The front appeared as the mathematics proposal's positive δ, the adjoint's W weights and R4's rank-one G. In all three, the candidate replacement is the *founder block*. Each should be re-asked with "front" replaced by "window", and re-measured on the resolved schedule.
- **Head-start selection fits rank 3's corollary.** It is a boundary term at the top of the canopy, where species are aligned. The corollary (species read at the same place are at best neutral) then says head-start differences equalise or exclude, but never stabilise.

---

## 3. What the search walked past

**Promising fragments from round one that were not developed.**

- **I8, assembly as optimal transport.** The species-to-site assignment is the Brenier and McCann coupling of surplus φ(θ; y). Finite selection gives entropic Sinkhorn, which *is* CATS (community assembly by trait selection), with the multipliers identified as field coordinates. This could give CATS a mechanistic derivation: a large, ignored link.
- **A3, the value of plasticity.** Plasticity is selected where the costate ratio varies, not where the environment varies. This is a sharp, contrarian EEO claim, and one sweep tests it.
- **D5, the mechanistic JSDM.** The latent site factors are the community-made field, with loadings S_i predicted from traits. This connects directly to vegetation-plot data.
- **I6, reciprocity.** Light-sensitivity of the favoured strategy under drying equals water-sensitivity under opening. It is a cheap, falsifiable symmetry test.
- **E9 and X1, recruitment modes as independent regulating factors.** These need re-asking with founder recruitment against later recruitment.
- **A5, the channel decomposition of d ln R′/d ln P.** Developed 1 answered it by node rather than by channel. The channel split on the resolved stand still matters.

**New fragments from round two.**

- **Two new games:**
  - an ESS on the *arrival distribution* (uniform against disturbance-cued arrival);
  - founder spread w as an evolving trait, a bet-hedging against tournament trade-off.
- **What sets the closed equilibrium.** The resident's density elasticity (−1.43) is close to the window's −3/2, which suggests the founder lottery sets the closed equilibrium.
- **Non-smooth selection.** When selection is a boundary term or a one-sided step, the canonical equation's gradient is ill-defined. Clarke subdifferentials and kinked ESSs (E8's lexicographic ESS, relocated to the window) may be the right adaptive-dynamics objects, and the tape gives one-sided derivatives.

**Questions for a third round.**

1. Which closed-canopy results survive the resolved schedule? This is a measurement, but it gates everything else.
2. Does the founder window survive realistic emergence spread (w_s of months) and within-cohort variance? Do its laws then become w_s-laws?
3. Can the storage effect on the founder lottery under real records be derived and measured by phase-averaging over disturbance dates?
4. Can CATS be derived as entropic optimal transport with field multipliers (I8)?
5. Is there a theory of kinked and non-smooth eco-evolutionary dynamics for boundary-term selection?
6. Is the γ = ½ alignment a competitive ESS of canopy acclimation, and does it maximise neutrality?
7. What happens with lateral light (finite penetration length)? It adds a positive-definite term that breaks the reflection identity. Is that where real forests get stabilisation?

---

## 4. Caveats

- **The founder window:**
  - it was measured on one closed stand, one record and one build;
  - the scaling derivations are heuristic;
  - the 39% inner share and the "about 10²" serotiny ratio use trapezoid rather than patch-age weights;
  - the kept derivative was a finite difference;
  - the window's modelled width (about 13 days) is likely far below real emergence spread.
- **Closure as a lottery.** Proposition 5 assumes exact constant final yield. The storage-effect route is untested. The concordance of the two routes is my synthesis.
- **The sensing–overhead law:**
  - it is a two-species statement at a state;
  - the TP count gives sufficiency only;
  - signed u or Õ (water coupling, constant final yield) void the Jensen sign;
  - §7(a)'s fit is not a test, and its A came from the suspect uniform schedule;
  - the Kohyama reconciliation rests on secondary sources;
  - the prior-art table needs Letten et al. (2017) and Koffel et al. (2021).
- **Acclimation sign.** A conjecture from a sketch model, with one counter-case, and the field values of k_N/k_L are unchecked.
- **Developed 3:**
  - R3 needs closed loops and confounds migration with lag;
  - R4 (front-induced rank-one G) and its "explanation" of F1 are conditional, since F1 may itself be the schedule artefact;
  - the Le Chatelier reversal holds in mean square only;
  - ŝ = 1/N_eff is mean-field and first-order;
  - the novelty of R3 against Blanquart & Gandon (2013) is unverified.
- **Prices.** The stage-bias direction was argued from front-dominated λ_P and needs recomputation now that suppressed cohorts show ordinary gains.
- **Novelty checks.** The searches were brief. No application of Afriat or cyclical monotonicity to local adaptation was found. A size-structured lottery for forests exists (Yuan & Chesson) and must be read before claiming the window's lottery identity as new.

**Files referenced:**
- `/home/a/dev/plant-dev/.claude/worktrees/workflows/docs/review/{process,assembly-geometry,assembly-mfg,theory,site-selection}.md`
- `/home/a/dev/plant-dev/.claude/worktrees/workflows/spikes/{field-dimension-066,leaf-table,assembly-example}/README.md`
- `/home/a/dev/plant-dev/.claude/worktrees/workflows/plant/inst/include/plant/models/tf24_strategy.h`
- Round-two drivers and outputs: `/tmp/front/`, `/tmp/lc/`, `/tmp/inv/`

Sources:
- [Letten, Ke & Fukami 2017 (NTU record)](https://scholars.lib.ntu.edu.tw/handle/123456789/583055)
- [Koffel, Daufresne & Klausmeier 2021 (HAL)](https://hal.inrae.fr/hal-03282294)
- [Yuan & Chesson, ESA 2013 abstract](https://eco.confex.com/eco/2013/webprogram/Paper43031.html)
- [Yuan & Chesson, ESA 2015 abstract](https://eco.confex.com/eco/2015/webprogram/Paper53568.html)
- [Yuan 2014 dissertation (Arizona)](https://repository.arizona.edu/handle/10150/338881?show=full)
- [Mrad et al. 2020, constant final yield and self-thinning](https://www.frontiersin.org/articles/10.3389/ffgc.2020.00062/full)
- [Fussmann & Kopp 2023, transplants under ongoing adaptation](https://www.frontiersin.org/journals/ecology-and-evolution/articles/10.3389/fevo.2023.1151283/epub)
- [Revealed preference cycles survey (arXiv 2405.08459)](https://arxiv.org/pdf/2405.08459)
- [Emergence delays and fire seasonality in eucalypt forests (PMC10709666)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10709666/)
- [Smith, the dynamic regeneration niche (ANU preprint)](https://openresearch-repository.anu.edu.au/bitstream/1885/148295/2/Smith%20The%20dynamic%20regeneration%20niche%20DDI%20preprint.pdf)
- [Gandon et al. 2008, adaptation across time and space](https://mast.queensu.ca/~tday/pdf/GandonEtAl2008.pdf)