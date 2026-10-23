# Where forest light coexistence comes from: a zero-sum tournament, broken by succession, regeneration and fluctuation

# Where light coexistence comes from in a Beer–Lambert forest: a likelihood-ratio law, its reflection case, and what it does to the acclimation prediction

## 1. Headline

In any field-mediated model, light competition has the exact form A_ij = ⟨u_i, O_j⟩. Here u_i is where species i's fitness reads light (the cut's zeroed adjoint × I) and O_j is the leaf area species j puts overhead. It follows that Chesson's niche overlap is a product of two likelihood-ratio expectations:

  ρ² = E_{Ũ₁}[Λ] · E_{Ũ₂}[1/Λ],  Λ = O₂/O₁ over (height × patch age).

Jensen's inequality then gives the rule: **two species stabilise each other by light only to the extent that each one's fitness is read where it, rather than its competitor, dominates the overhead.** Beer–Lambert's reflection identity is the aligned special case, ρ² = 1 − 4κ². Fronts, Kohyama's stratification, constant final yield and canopy acclimation all fall out as special cases.

Developing the brief gave three corrections to its premises:
- Stratification does stabilise. It does so at second order in height asymmetry, not zero order.
- The rank-one "zero-sum" statement holds only in one metric.
- The acclimation crossover has the opposite sign to the one proposed, and its switch point (k_N/k_L = ½) sits where real canopies are measured.

## 2. The departure

The sources (mathematics M1–M6, curator X1) measured stabilisation by λ_min of the symmetric part, either in the identity metric or in W = diag(1/ρ_i). Two things follow from that choice.
- **The quantity is not invariant.** A = D_T Π D_L, and A is defined per ln b. Diagonal rescalings (per density or per ln b) change λ_min(A_s) and the W-metric statement, but leave coexistence unchanged. For two species the invariant quantities are sgn det A and Chesson's ρ² = A₁₂A₂₁/(A₁₁A₂₂).
- **The rank-one result is real but was over-read.** In the W metric the symmetric part per age is ½LLᵀ (exact). That does not make composition neutral. The skew part rotates compositional deviations into the dissipated "total" direction: in Villani's term the dynamics are *hypocoercive*. Two aligned species with κ = Π₁₂ − ½ ≠ 0 have a strictly stable composition mode, with eigenvalue ½ − √(¼ − κ²) ≈ κ² (checked: κ = 0.05, 0.1 and 0.25 give 0.0025, 0.0101 and 0.067). Over 20,000 random aligned tournaments with n = 3–6 and random positive abundance scalings, no eigenvalue of DΠ had a negative real part. Aligned light never produces priority effects, and neutrality needs a symmetry, for example equal column sums in the cyclic Efron case.

So what was walked past is not "height cannot stabilise". It is the scale-free law that says *where* fitness is read relative to *whose* leaves are overhead. Toy theorists never had u. Forward simulators never had u as a function over height × age. EEO never asked where elasticity sits relative to competitors' leaves, only relative to light.

## 3. The formulation

**Setting.** Notation follows `process.md`. The direct impact of ln b_j on ln I(z, a) is −O_j(z, a), with O_j(z, a) = ∫_z^∞ ℓ_j(z′, a) dz′, j's extinction-weighted leaf area overhead. The sensing is u_i(z, a) = I · S_i^light(z, a). Then, exactly:

  A_ij = ⟨u_i, O_j⟩ = ∫∫ u_i O_j dz da.  (1)

With feedback, replace O_j by the realised overhead Õ_j = −∂ ln I/∂β_j, taken from the kept sweep. Every reshuffling of leaves enters ln I linearly, so (1) stays exact. Define ℓ̃_j = ∂Λ_total/∂β_j and M as the making operator (the resident leaf response to light history, causal in age). Then ℓ̃_j = (I + M H)⁻¹ ℓ_j: one common resolvent, lower-triangular in age. **Feedback lives entirely on the making side; sensing is untouched.**

**Theorem 1 (likelihood-ratio law).** Let Ũ_i ∝ u_i O_i (i's sensing tilted by its own overhead) and Λ = O₂/O₁. Then

  A₁₂/A₁₁ = E_{Ũ₁}[Λ],  A₂₁/A₂₂ = E_{Ũ₂}[1/Λ],  ρ² = E_{Ũ₁}[Λ] E_{Ũ₂}[Λ⁻¹].  (2)

*Proof:* divide (1). With water included, A = A^light + A^water. Each ratio becomes a mixture over field blocks b, Σ_b s_i^b E_{Ũ_i^b}[Λ^b], with s_i^b the share of i's self-limitation that passes through block b.

**Corollary 1 (Jensen).** If Ũ₁ = Ũ₂, then ρ ≥ 1, with equality iff Λ is constant on the support. Two species whose fitness is read at the same place are at best neutral and otherwise show founder control. This covers:
- a common front (X1): Π → 11ᵀ, R\* exclusion;
- identical crowns: Π = (½ + δ)11ᵀ, neutral whatever δ is;
- a one-mode field: A rank one.

**Corollary 2 (reflection: Beer–Lambert under alignment).** If u_i ∝ ℓ_i, then E_{Ũ₁}[Λ] = 2Π₁₂L₂/L₁ and E_{Ũ₂}[1/Λ] = 2Π₂₁L₁/L₂. Since Π₁₂ + Π₂₁ = 1:

  ρ² = 4Π₁₂Π₂₁ = 1 − 4κ²,  f₁/f₂ = (r₁T₂/r₂T₁)·√(Π₂₁/Π₁₂).  (3)

Self-shading is exactly the geometric mean of the two cross-shadings when κ = 0. Height asymmetry therefore stabilises at O(κ²), while the fitness difference it creates is O(κ) (½ ln(Π₁₂/Π₂₁) ≈ 2κ). The coexistence window, |ln f₁/f₂| < −½ ln(1 − 4κ²) ≈ 2κ², requires a trade-off (r₁T₂/r₂T₁) that cancels height's first-order advantage to second order. Full separation (κ → ½, ρ → 0) is the triangular, hierarchical community. There coexistence reduces to whether the short species can invade under the tall one's canopy.

**Corollary 3 (point sensing: fronts and bottlenecks).** If Ũ_i = δ_{x_i}, then ρ² = Λ(x₁)/Λ(x₂). Within one age, Λ = O₂/O₁ increases with height when species 2 is taller in likelihood-ratio order (a TP2 pair of leaf profiles). So:

  **coexistence ⇔ the taller species' fitness is read higher;** −ln ρ = ½ ln[Λ(x₂)/Λ(x₁)].

Discordant reading (the tall species regenerates from a floor bank and the short one is read mid-crown) gives founder control. A floor front under both canopies has Λ ≈ 1 and pulls ρ towards 1.

**Corollary 4 (age without separability).** Light acts within an age, so A_ij = ∫ T_i(a) L_j(a) Π_ij(a) da. For any number of species and any subset S, the Andréief/Cauchy–Binet identity gives

  det A_S = (1/k!) ∫ det[u_i(x_l)] · det[O_j(x_l)] dx₁…dx_k,  x = (z, a).  (4)

With separable elasticity, T_i = ρ_iτL_i, this is the Gram form M3. Without separability it is positive when the sensing kernel and the overhead kernel are **sign-regular in a common order**. A sufficient condition is that both are totally positive along one path in (z, a), which makes A a P-matrix and, by the oscillatory-matrix argument, D-stable. **The count of light-coexisting species is the longest chain of species whose sensing locations are ordered like their overhead dominance**, a Karlin-type total-positivity count rather than a rank. It is the continuous analogue of Tilman's criterion that each species consumes relatively more of the resource that limits it more.

**Proposition 5 (feedback: constant final yield removes the total mode).** In closed, self-thinning ages, total leaf area does not respond to seed rain (Kira, Ogawa & Shinozaki's constant final yield). Then Õ_j = O_j − p_j O_total with p_j = L_j/L_tot, so A(a)·1 = 0 exactly. The direction that Corollary 2's dissipation acts on, total leaf area, is annihilated. What remains is a lottery: for two aligned species the nonzero eigenvalue is (½ − Π₁₂)(L₁L₂/L_tot)(T₁ − T₂). Composition at closed ages is therefore stable iff **the taller species has the larger total light elasticity**. Checked: the example gives A·1 = 0 and eigenvalue −0.083 when T_tall < T_short. So the total-mode stabilisation measured by the age Gram comes only from ages before closure.

**Proposition 6 (fluctuation through the front).** Away from the front, φ is close to affine in the field, so the Jensen term ½tr(∂²φ Cov y) has O(1) coefficients. At a reserve-mediated front, φ ⊃ −D μ̂(P_front), and TF24's own reserve law gives μ̂″ ≈ 0.80/ε² per year at P = 0. The inflection is at P = −1.35ε, so μ̂ is convex across Lemma 1's whole thinning window.

The fluctuation contribution to A is rank one: A^fl = k cᵀ, where:
- k_i = ½D_i μ̂″ f_i is curvature × dwell × front share, about (P̄_g/ε)² times larger for a bank recruiter than for an open recruiter;
- c_j = ∂Var(P_front)/∂β_j.

It stabilises iff the front-curved species raises front-light variance per capita more than its competitor does (Chesson's relative nonlinearity, signed). Two robust effects come without any sign assumption, at σ = SD of the reserve-filtered front carbon balance:
- The front lifts to stay at the thinning rate κ: ΔP ≈ +1.0ε at σ = ε and +4.7ε at σ = 3ε (κ = 0.1/yr).
- The knife softens: the gain falls by 0.63× at σ = ε and 0.26× at σ = 3ε.

So fluctuation turns X1's R\* exclusion at a shared front into near-neutrality for bank species whose compensation points lie within about σ of each other.

## 4. The ecology

1. **Light niches are "where you are read, against whose leaves are overhead".** This is not crown depth (`assembly-geometry.md` §3) and not δ alone. The scale-free stabiliser is the concordance in Corollary 3: tall species must be demographically limited high (pole stage, canopy entry), short species low.
2. **Stratification stabilises, quadratically.** Nearly co-stratified species are quasi-neutral. Their compositional relaxation time is about 1/κ², and their coexistence window is 2κ² wide while their fitness gap is O(κ). This gives a mechanistic, quantitative version of Hubbell's near-neutrality in light-limited stands. It agrees with the empirical claim (Grady et al. 2020, BCI) that "competitive neutrality between size classes emerges above the sapling layer, where increasing access to light is counterbalanced by stronger self-shading". That is the reflection identity seen in data.
3. **Kohyama reconciled.** The brief asked whether Kohyama's coexistence is δ or A^fb. On this analysis it is neither, and it is not in conflict with M2. In Kohyama's model:
   - competition is through the basal area of larger trees, a Heaviside cumulative overhead O_j, so (1) to (3) apply exactly;
   - the forest-architecture hypothesis (a short species reproducing at small size, a tall one passing through the subcanopy) is the concordant ordering of Corollary 3, at κ → ½, which gives a near-triangular hierarchy;
   - his gap mosaic adds the age term (4).

   M2's "stratification is zero-sum" was the W-metric statement and does not contradict him. The secondary sources found say Kohyama's simulations point to a maximum-size against fecundity trade-off, which is (3)'s equalising requirement r₁T₂/r₂T₁ ≈ √(Π₁₂/Π₂₁). The primary papers were not read, so this reconciliation should be checked against them.
4. **Constant final yield is a coexistence law.** Self-thinning switches off light's dissipation of total leaf area in closed patches. There, coexistence by light requires the taller species to be more light-elastic. Advance regeneration with huge front elasticity on the short species reverses that sign. The prediction is that **closed patch ages destabilise a bank-recruiting understorey species against a taller canopy species, and stabilisation must come from pre-closure ages or from water.**
5. **Acclimation: the crossover exists but has the opposite sign to M6.** Take a depth-resolved crown with capacity V ∝ I^γ, where γ = k_N/k_L. In the saturated limit the per-leaf elasticity is ∝ I^{2γ−1}, which gives:
   - **γ = ½ is exactly alignment** (u ∝ ℓ);
   - the within-crown offset is δ(γ) = δ_c((2γ − 1)X), with δ_c(Y) = [1 − (1 + Y)e^{−Y}]/[Y(1 − e^{−Y})] − ½ ≈ −Y/12, so δ changes sign at γ\* ≈ 0.47–0.49 (X = 2, θ_top = 30–100).

   Two partly overlapping layers, though, are stabilised by *full* acclimation, because it lifts the tall species' sensing out of the band shared with the short species (Corollary 3). Sun crowns that are saturated at the top push the canopy species' fitness down into the subcanopy and erode coexistence. **EEO-optimal acclimation (γ = 1) promotes light coexistence. Observed canopies, with k_N/k_L commonly reported at about 0.3–0.6 (from memory, unchecked), sit at the aligned reference point γ = ½.** That is also where Anten's and Hikosaka's game-theoretic ESS gradients sit: shallower than optimal. Competition may hold canopies at alignment, the point where the reflection law is exact.
6. **TF24's crown-mean leaf is the γ = 1 crown,** with u ∝ qI and δ_c = −0.157 at X = 2. Within an age it is at the stabilising end. The open stand's ρ ≈ 1 must then come from Corollary 1 (sensing in common, one field mode), not from crown physiology.

## 5. Why us

- **u_i(z, a) as a function** is the cut's zeroed adjoint × I, one sweep per resident set. Without it, (2) cannot be evaluated; with only A, a 2×2 matrix with det ≥ 0 *always* fits an aligned tournament (§7). The decomposition is identifiable only from the tape.
- **Õ_j and the resolvent.** Kept-sweep β columns on ln I(z, a) give the realised overhead. Õ_j − O_j is the feedback, split exactly, and Proposition 5 is tested by ∂L_tot(a)/∂β_j along age.
- **Costates** split Ũ_i by cohort, so they show whether a species is read at its front, its pole stage or its crown.
- **Second-order sweeps** (P7, forward-over-reverse) give the k_i of Proposition 6, and ∂Var/∂β_j by a mode-seeded second sweep.
- **The ingredients come together:** reserve-mediated mortality (fronts), Beer–Lambert by height × age, water and real rain. PPA models fix understorey rates, so they have no fronts. Toy models have no u.

## 6. Prior art and the delta

| Work | What it has | Delta |
|---|---|---|
| Chesson 2000 (ρ, f) | the scale-free 2-species criterion | (2) evaluates it from sensing and overhead profiles; (3) gives it in closed form for Beer–Lambert |
| Tilman 1982; MacArthur/Levins | stability iff each species most impacts what most limits it | Corollaries 1 and 3 are the continuous height × age version; the Jensen bound and TP count appear new |
| May & Leonard 1975; Moon & Pullman 1970 | α + β = 2; generalised tournaments | Shown to be W-metric only; the true 2-species overlap is 1 − 4κ² |
| Adams, Purves & Pacala 2007 [verified] | PPA neutrality for transmissivity-only differences; founder control | κ = 0 gives ρ = 1 (Corollary 2); founder control ⇔ discordant reading (Corollary 3) |
| Nevai & Vance 2007, J. Math. Biol. [found by search] | canopy partitioning necessary for coexistence in a shading model | consistent: ρ < 1 needs κ ≠ 0 or concordant offsets |
| Kohyama 1993; Kohyama & Takada [content unverified] | one-sided, size-structured coexistence with gaps | identified as concordance plus the age term, not δ or feedback |
| Grady et al. 2020 bioRxiv [read abstract] | empirical neutrality across size classes from self-shading | the reflection identity predicts it, with its O(κ²) breaking term |
| Field 1983; Hirose & Werger 1987; Anten 2005; Hikosaka & Anten 2012 | optimal against ESS nitrogen gradients | γ = ½ as exact alignment; acclimation's sign on coexistence (new as far as I found) |
| Kira et al. 1953 | constant final yield | its role as the annihilator of light's dissipative mode (new as far as I found) |
| Karlin 1968; Villani 2009 | total positivity; hypocoercivity | applied to forest light; the mathematics is known |
| Chesson 1994 (relative nonlinearity) | fluctuation-dependent coexistence | located at the reserve front, with curvature amplified by (P̄_g/ε)² |

Honest note: (2) is a two-line rearrangement of A = ⟨u, O⟩. Its content lies in the corollaries and in having u at all. Searches were brief.

## 7. Worked cases

All checks are in `/tmp/lc/{a,b,c,d,e}.R`.

**(a) The measured closed pair.** A = [[0.937, 0.621], [0.722, 0.645]] gives:
- A₁₂/A₁₁ = 0.663 and A₂₁/A₂₂ = 1.119;
- ρ = 0.861, so −ln ρ = 0.149;
- det > 0, so the aligned tournament fits exactly, with Π₁₂ = 0.754 (κ = 0.254) and the u-weighted leaf ratio L₂/L₁ = 0.44, or the mirror solution Π₁₂ = 0.246 and L₂/L₁ = 1.35.

Species 2 has hmat +0.24, which favours the first. **Prediction:** from the tape, Pr(Z₂ > U₁) ≈ 0.75 and u-weighted L₂/L₁ ≈ 0.44 if light under alignment carries the whole of ρ. The shortfall from each number assigns the rest to water (s^w), offsets or feedback.

**(b) The open pairs.** Pair #31 has ρ = 1.034 and #38 has ρ = 0.977. Both are within about 3% of the Jensen bound ρ = 1, as Corollary 1 predicts for a field effectively of one mode. #31 needs equal offsets δ ≤ −0.017 if read as a tournament.

**(c) Fronts.** Crowns of depth 6 with tops at 20 and 14, and 90% of sensing at a front:

| front heights (tall, short) | det Π | reading |
|---|---|---|
| common, at 2 | 0.0024 | rank one (X1) |
| tall's at 9, inside the short crown | 0.153 | concordant |
| tall's at 15, above the short crown | 0.742 | concordant, nearly triangular |
| reversed: tall at 2, short at 9 | −0.140 | founder control |

**(d) Efron-type toy.** Leaves at heights (2, 4, 9), (1, 6, 8) and (3, 5, 7), cyclic with Pr = 5/9:

| sensing | composition eigenvalues | outcome |
|---|---|---|
| aligned | ±0.096i | neutral cycles |
| 30% on own sapling bank | real, ±0.038 | saddle, infeasible: the banks act as a near-common front |
| purely private offset +0.05 | 0.032 ± 0.062i | damped to (1, 1, 1) |
| private offset −0.02 | −0.0135 ± 0.065i | heteroclinic (min N 2e-98) |

Size-structured intransitivity exists, but sapling banks do not damp it, because they are not private.

**(e) Acclimation.** Two crowns of depth X = 2 offset by half a crown length, θ_top = 30:

| crown | ρ |
|---|---|
| sun crown (γ = 0) | 0.733 |
| γ = ½ | 0.661 |
| aligned reference | 0.661 |
| γ = 1 | 0.564 |

The pattern holds for X = 1–4 and θ_top = 3–300, except one low-saturation case (X = 4, θ_top = 3), where γ = 0 gives 0.615.

**(f) Reserve knife.** Using TF24's defaults: μ̂(0) = 0.10, μ̂′(0) = −0.263/ε, μ̂″(0) = 0.80/ε². At κ = 0.1/yr and σ = ε, the Jensen excess is 0.35/yr, which over a 20-year dwell is 7 in ln survival.

## 8. What it opens

**First computation, on `two-closed-31` as recorded:**
1. Form u_i(z, a) from the cut and O_j and Õ_j from the β columns.
2. Report E_{Ũ_i}[Λ] split by blocks (light at pre-closure ages, light at closed ages, water) against the measured 0.663 and 1.119.
3. Test 0.754 and 0.44 from §7(a).
4. Test Proposition 5: ∂L_tot(a)/∂β_j should go to about 0 after closure.

**Predictions:**
- Pairs that share an age profile and differ in height have 1 − ρ² = 4κ̄²; they are not unstabilisable, as M3 had it.
- Founder control by light ⇔ the taller species is read lower.
- Light-mediated diversity rises with k_N/k_L above ½ and falls below it in sun-saturated canopies.
- Understorey light under thinning stands in variable climates sits about one SD of reserve-filtered sapling carbon balance above the compensation point.
- Compositional memory ∝ 1/κ² for co-stratified pairs.

**Links:**
- This replaces the crown-depth paragraph of `assembly-geometry.md` §3.
- The "measure the regime" step (§4.1 there) should report ρ and sgn det rather than λ_min(A_s).
- (4) gives a TP count of species, alongside Meszéna's rank count.
- The ecology proposal's front enters as the point sensing of Corollary 3, and its Lemma 3 is Proposition 5 seen at the front.

## 9. Where it might break

- **Two species and linear.** (2) concerns ρ at a state. For n ≥ 3, (4) gives sufficiency only.
- **Signed quantities.** u < 0 (water coupling) or Õ < 0 (constant final yield) make Ũ a signed measure. The Jensen bound then fails, and (2) still holds but loses its sign guarantee.
- **Horizontal homogeneity.** Lateral light leaks shade (penumbra, gaps). It turns the Heaviside kernel into one with a finite penetration length, which adds a positive-definite term outside this theory.
- **The acclimation model is a sketch.** It uses a rectangular hyperbola, uses the envelope theorem for plastic V, has two uniform crowns, and has no non-photosynthetic costs. TF24 cannot test it until the depth-resolved, differentiable Leaf exists.
- **Proposition 5 assumes exact constant final yield.** TF24's 40-year patch mosaic mixes in open ages.
- **The fluctuation sign (c_b against c_o) is unknown.** The quasi-static reserve assumption fails when fluctuations are slower than reserve relaxation.
- **The fit in §7(a) is not a test.** Any 2×2 matrix with det ≥ 0 admits it; only the tape-side numbers test it.

Sources:
- [Kohyama 1993, J. Ecol. (catalogue)](https://www.library.sk/arl-sldk/sk/detail-sldk_un_cat-r025249-Sizestructured-tree-populations-in-gapdynamic-forestthe-forest-architecture-hypothesis-for-the-st)
- [ESA 2010 abstract on Kohyama's model](https://eco.confex.com/eco/2010/techprogram/P22293.HTM)
- [Kohyama lecture listing (Tiantong)](https://tiantong.ecnu.edu.cn/show/573)
- [Nevai & Vance 2007, J. Math. Biol.](https://link.springer.com/article/10.1007/s00285-007-0073-y)
- [Grady et al. 2020, bioRxiv](https://www.biorxiv.org/content/10.1101/2020.06.22.163659v1.full.pdf)
- [Canopy N acclimation and game theory (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC4246793)
- [Optimal canopy N against observed (CSIRO FP05319)](https://publish.csiro.au/FP/FP05319)