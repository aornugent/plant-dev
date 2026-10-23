**Headline.** Under Beer–Lambert light, the matrix of light competition factors exactly into amounts and one matrix of probabilities, Π_ij = Pr(a leaf of j sits above a unit of i's light elasticity). When a species' fitness elasticity is spread over height the same way as its leaves, Π + Πᵀ = 11ᵀ. That is May and Leonard's degenerate case (α + β = 2) for any number of species and any crown shapes. So within one patch age, height stratification is a zero-sum game: total leaf area is regulated and composition is neutral or cyclic. All stabilisation by light then comes from two sources, both readable from the field cut: how species' leaf area differs across patch age (an exact Gram matrix), and how far each species' elasticity sits from its own leaves (an offset δ_i).

---

## 2. The departure

The canon treats one-sided light competition as an asymmetric kernel and asks whether self-limitation outweighs it. `assembly-geometry.md` §3 does the same: "a triangular kernel's symmetric part is indefinite unless self-limitation dominates", with crown depth (Horn) as the control. The forest literature (Adams, Purves & Pacala 2007; Kohyama 1993; Falster et al. 2017) gets coexistence, founder control or exclusion model by model.

Three things were missed:

1. **Beer–Lambert fixes the self-limitation exactly.** It is linear in log light and cumulative leaf area, so the kernel in log light is a Heaviside step. Self-shading is always exactly half of what a fully overtopping neighbour would cause. It is never "enough" or "not enough" by itself.
2. **The step function's symmetric part is the all-ones matrix,** since H(x) + H(−x) = 1. The symmetric (stabilising) part of light competition at one patch age is therefore rank one: everyone competes symmetrically for total leaf area. Height order lives entirely in the skew part.
3. **The canon never had the sensing profile.** The quantity that breaks the degeneracy is where each species' fitness reads the light, the elasticity density u_i(z, a) = δ ln R′_i / δ ln I(z, a), set against where its leaves are. Toy models assume the two coincide or never separate them; forward simulators cannot compute u as a function. The degeneracy was walked past because nobody could measure the one quantity that departs from it.

## 3. The formulation

**Notation.** Notation follows `process.md`, restricted to light. In a patch of age a:
- ln I(z, a) = −∫_z^∞ Σ_j ℓ_j(z′, a) dz′, where ℓ_j is species j's leaf area by height, extinction-weighted (k_I,j · n_c · a_c · q_c, summed over j's cohorts). In TF24 this is `compute_competition` = k_I · area_leaf · Q.
- The light part of the sensitivity, in log light: u_i(z, a) = I(z, a) · S_i^light(z, a). This is what the cut zeroes, times light.
- The amounts:
  - T_i(a) = ∫ u_i dz, the elasticity of species i's fitness to incoming radiation at age a. PPFD enters TF24 multiplicatively (`radiation_at`), so T_i(a) = ∂φ_i/∂ ln PPFD(a), apart from the light floor.
  - L_j(a) = ∫ ℓ_j dz, species j's extinction-weighted leaf area index.
- The shapes: U_i(a) ~ u_i/T_i and Z_j(a) ~ ℓ_j/L_j, read as distributions over height, assuming u ≥ 0.

**The direct kernel.** Raising ln b_j by δ scales j's densities by δ, with individual trajectories held. Then δ ln I(z, a) = −δ ∫_z^∞ ℓ_j(z′, a) dz′, and with A = −S·C as in `assembly-geometry.md`:

  A⁰_ij = ∫ da ∫∫ u_i(z, a) H(z′ − z) ℓ_j(z′, a) dz dz′ = ∫ da T_i(a) L_j(a) Π_ij(a),  
  Π_ij(a) = Pr(Z_j(a) > U_i(a)), the two drawn independently.  (1)

So at each age, A⁰(a) = D_T(a) Π(a) D_L(a): a Hadamard product of a rank-one amounts matrix and a tournament matrix of probabilities.

**Identity R (reflection), exact with no assumption beyond Beer–Lambert:**

  Π_ij(a) + Pr(Z_j(a) < U_i(a)) = 1.  (2)

What j does to i, plus what j would do with every height reflected, equals T_i L_j.

**Alignment.** Say species are aligned when U_i and Z_i have the same distribution. Then Pr(Z_j < U_i) = Π_ji and Π_ii = ½, so

  Π + Πᵀ = 11ᵀ.  (3)

This is a generalised tournament matrix (Moon & Pullman), and ½ on the diagonal with off-diagonal pairs summing to 1 is May and Leonard's α + β = 2.

**The right metric.** Take the per-leaf elasticity ρ_i = T_i/L_i and weight by W = diag(1/ρ_i). Then

  W A⁰(a) + A⁰(a)ᵀ W = D_L (Π + Πᵀ) D_L = L(a) L(a)ᵀ  (aligned).  (4)

Any positive diagonal rescaling of A carries over to Π, because D_T Π D_L is congruent to EΠ + ΠᵀE. So diagonal stability (Volterra–Lyapunov), which governs uniqueness and global stability, depends only on Π. The amounts wash out.

**Across patch ages.** Light acts only within a patch age, so A⁰ = ∫ da A⁰(a). If per-leaf elasticity separates, ρ_i(a) = ρ_i τ(a), then

  (W A⁰)_s = ½ ∫ τ(a) L(a) L(a)ᵀ da,  (5)

which is the Gram matrix of the species' leaf-area trajectories over succession. It is positive definite exactly when those trajectories are linearly independent. Height order contributes nothing to (5).

**Misalignment.** Write Π = Π^al + Δ, with diagonal offsets

  δ_i(a) = Pr(Z_i > U_i) − ½,

so δ_i > 0 when i's elasticity sits **below** its own leaves. Then

  (W A⁰)_s = ½ Gram_age + ∫ D_L(a) Δ_s(a) D_L(a) da.  (6)

**Theorem (two species, one age).** Positive diagonal, so diagonal stability ⇔ det Π > 0, and

  det Π = (½ + δ_1)(½ + δ_2) − Π_12 Π_21.

- Aligned: det Π = (Π_12 − ½)² ≥ 0. Two aligned species can never show founder control, whatever their crowns. Exclusion or coexistence is then a matter of feasibility only.
- Founder control needs (½ + δ_1)(½ + δ_2) < Π_12 Π_21 ≤ ¼. That requires negative offsets: elasticity above the foliage.

**n species, one age.** Aligned, xᵀΠx = ½(1ᵀx)² ≥ 0. Write Π = ½11ᵀ + K, with K skew. Then:
- the game is stable in Hofbauer and Sandholm's sense, but only weakly: strictly stable on the total, null-stable on composition;
- the Lotka–Volterra Lyapunov function V = Σ ρ_i⁻¹(N_i − N_i* ln N_i) satisfies dV/dt = −½(Σ ΔN_i)², so trajectories go to the total-leaf-area shell, and composition then follows K's conservative (Volterra–Kerner Hamiltonian) flow;
- a diagonal δ moves the composition eigenvalues off the imaginary axis: δ > 0 gives damped spirals (stable coexistence), δ < 0 gives heteroclinic dominance cycles.

**Feedback.** The full A, read from the kept sweep's β columns, is A⁰ + A^fb. The second term is shading that acts through changed growth: a causal series in patch age. A⁰ is the open-loop part, and the tape gives both, so the split is exact.

## 4. The ecology

1. **Height stratification is a zero-sum game.** Within a patch age with aligned sensing, light regulates one scalar, total leaf area, and leaves composition neutral (two species) or conservatively cyclic (three or more). This gives a mechanistic origin for Hubbell's zero-sum assumption in light-limited stands. It generalises Adams et al.'s (2007) finding that PPA species differing only in crown transmissivity are neutral: neutrality is the generic aligned state, not a special case.
2. **Light's regulating factors are patch ages, not heights.** By (5), light can stabilise at most rank[L_i(a)] species: the number of independent leaf-area time courses over succession. This is Meszéna's regulating-factor count with the factors named. It fits the measured making modes, which are age bands: understorey at ages 0–10, and 10–15 m at ages 10–20 (`spikes/field-dimension-066`).
3. **The offset δ is the stabilising trait, and it is not crown depth.** Within a crown it depends on photosynthetic physiology:
   - sun crowns, saturated at the top, have their elasticity in the mid or lower crown, so δ > 0 (stabilising);
   - shade crowns, light-limited throughout, have it at the top, so δ < 0;
   - TF24's mean-light model runs one optimisation at crown-mean light, so elasticity per crown is ∝ I(z)q(z) and δ = −0.156 for every crown;
   - in TF24, therefore, any positive δ must come from **between cohorts**: u_i weights cohorts by reproductive value times marginal production, λ_c ∂rate/∂L̄. Suppressed cohorts near compensation have huge λ-weighted elasticity on little leaf area (the d ln R′/d ln P ≈ 7.6e3 knife edge of `spikes/leaf-table`). They put U below Z and make δ positive.
   - Prediction: light-mediated self-limitation in TF24 is carried by advance regeneration. A species whose fitness lives below its foliage stabilises itself; an even-aged pioneer does not.
4. **Optimal acclimation erodes coexistence.** EEO's optimal within-canopy nitrogen or Vcmax profile (capacity tracking light; Field; Hirose & Werger; the P-model) makes P nearly linear in local light. Then u ∝ I·ℓ and δ < 0: the top-weighted mean-light case. The saturation that canopy optimality removes is what made δ positive. This is a sharp, untested crossover prediction joining the EEO and coexistence literatures.
5. **Priority effects need elasticity above foliage.** Two-species founder control on light requires δ_1, δ_2 < 0 enough to beat Π_12Π_21. The open-stand pair with det A = −0.055 (`field-dimension-066`) fits the mean-light model's negative offset. The closed pair's λ_min(A_s) = 0.104 should come from the age Gram, water and suppressed-cohort δ. All three are separable on the tape.
6. **Intransitivity can arise from size structure.** A species' leaf area within a patch is a mixture over cohorts, so it can be multimodal (a sapling bank plus a canopy layer). Distributions shaped like Efron's dice give a cyclic Π: rock–paper–scissors for light. Whether the cycle damps or runs to heteroclinic dominance is set by the sign of δ. Mixing transitive orders across patch ages can also give a majority cycle (Condorcet), though ordinary succession (pioneer, then mid, then late) stays transitive.

## 5. Why us

This needs u_i(z, a), each species' fitness elasticity resolved over height and patch age with reproductive value inside it. That is exactly the field adjoint the cut zeroes (P3 for residents, P6 for invaders), multiplied by I.

- **What the tape supplies:**
  - ℓ_j and T_i: T_i from a PPFD seed (P2/P5), or by integrating u;
  - the full A from P2's β columns, so A^fb = A − A⁰ is exact;
  - per-cohort costates, which split δ_i into within-crown and between-cohort parts.
- **A forward simulator** gets A by finite differences, a 2×2 number per pair. It cannot factor A into amounts and probabilities, cannot separate the age Gram from δ, and cannot say which cohorts carry δ.
- **A toy theorist** can do the algebra (it is short) but cannot evaluate δ for a size- and age-structured, water-coupled stand at ecological equilibrium. There δ is set by λ along trajectories that pass the compensation point.
- **Our extra handle is the exact identity (2).** It makes every term's sign checkable against the kept-sweep A, with no tolerance argument.

## 6. Prior art

| Work | What it has | The delta |
|---|---|---|
| May & Leonard (1975) | α + β = 2 as a degenerate neutral case | Shown here to be what Beer–Lambert gives under alignment, for any n and any profiles |
| Volterra (1931); Kerner (1964); Hofbauer & Sigmund (1998) | Conservative Lotka–Volterra; rank-one-plus-skew Lyapunov arguments | The general mathematics; the forest case is new |
| Moon & Pullman (1970) | Generalised tournament matrices (Π + Πᵀ = J) | The mathematics; no ecological derivation |
| Allesina & Levine (2011, PNAS) [verified] | Competition as a tournament network with RPS-type coexistence under several limiting factors; equilibria from game theory | Their pairwise outcomes are imposed; here Π is derived from radiative transfer and reproductive value, and the neutral knife edge with its perturbation (δ, age Gram) is explicit |
| Adams, Purves & Pacala (2007, Proc R Soc B 274:3039) [verified] | PPA height-structured light; the general case gives coexistence, founder control or exclusion; transmissivity-only differences give neutral dynamics; an R*-like Ẑ* in the hierarchical case | Closest. The delta: neutrality as the generic aligned state of Beer–Lambert, the founder-control criterion as an offset inequality, and the stabilising quantity as an elasticity–leaf offset |
| Kohyama (1993); Falster et al. (2017, PNAS) | Coexistence by stratification and by succession | (5) makes "succession, not stratification" an identity, under alignment |
| Hofbauer & Sandholm (2009) | Stable games | Used as is |
| Schwinning & Weiner (1998) | Size asymmetry | Context |
| Field (1983); Hirose & Werger (1987); Anten (2005) | Optimal nitrogen profiles; ESS against optimal LAI | The coexistence consequence in item 4 of §4 appears new |

I found nothing that derives the May–Leonard knife edge from Beer–Lambert or names δ. Apart from the two marked as verified, these references are from memory and unchecked.

## 7. A worked case

Checked numerically (R, `/tmp/lightk/check.R`).

- **Three aligned species with Efron-type profiles** (pairwise Π = 5/9, cyclic): Π + Πᵀ = 11ᵀ exactly. Eigenvalues are 1.5 and ±0.0962i, so composition is purely oscillatory.

  | δ | Eigenvalues | Lotka–Volterra outcome (N* = 1) |
  |---|---|---|
  | 0 | 1.5, ±0.0962i | V = Σ(N − ln N) stays at 3.06614 to 6 digits over t = 3000: conservative cycles at fixed total |
  | +0.05 | 1.55, 0.05 ± 0.096i | V → 3.00000, converges to coexistence |
  | −0.02 | 1.48, −0.02 ± 0.096i | V grows to 346, minimum densities reach 1e-139: heteroclinic dominance cycle |

- **Two species, two patch ages, opposite height order, aligned:** L = [[1, 0.2], [0.3, 1]] (species × age). A_s has eigenvalues 0.783 and 0.282 and equals ½·Gram exactly. Either age alone gives eigenvalues 0.545 and 0: rank one.
- **Offsets within one crown** (LAI 4, k = 0.5, P = I/(I + K)):

  | Crown-top light I₀/K | δ, depth-resolved crown | δ, mean-light model |
  |---|---|---|
  | 30 | +0.129 | −0.156 |
  | 10 | +0.087 | −0.156 |
  | 3 | +0.008 | −0.156 |
  | 1 | −0.070 | −0.156 |
  | 0.3 | −0.123 | −0.156 |

- **By hand, two separated species** (j entirely above i): Π = [[½ + δ₁, 1], [0, ½ + δ₂]]. It is triangular, hence diagonally stable for any δ > −½: no founder control without overlap. In the identity metric, λ_min(Π_s) ≥ 0 ⇔ (1 + 2δ₁)(1 + 2δ₂) ≥ 1.

## 8. What it opens

**First step, on recordings that exist.**
- For the closed-stand pair at equilibrium (`two-closed-31`), take u_i(z, a) from the cut and ℓ_j from the tape.
- Form T, L, Π(a), δ_i(a) and A⁰.
- Report three numbers: the age-Gram eigenvalues, the δ term in (6), and A − A⁰ (water plus feedback).
- Check the measured A = [[0.937, 0.621], [0.722, 0.645]] against the decomposition.
- Repeat on the open-stand pairs. The prediction is A⁰ near rank one with a negative δ term.

**Then:**
- Split δ_i by cohort using costates. The prediction is that suppressed, near-compensation cohorts carry the positive part.
- Sweep shading_model and a Vcmax-acclimation switch and watch the sign of δ. The deep-crown model needs the differentiable Leaf first: it currently stops for non-double scalars.

**Testable predictions:**
- (a) Pairs that share an age profile but differ in height cannot be stabilised by light: λ_min ≈ 0.
- (b) Light-mediated coexistence scales with the age Gram's λ_min.
- (c) Founder control appears only where δ < 0. In real canopies that means shade-dominated crowns or strongly acclimated leaves.
- (d) Across sites, stronger photosynthetic acclimation goes with lower light-mediated diversity.

**Links:**
- It refines `assembly-geometry.md` §3: crown depth matters only through δ.
- It gives §4 item 4 its basis: light's skew part is the top-down sweep, and its convex part is a projection in age space.
- It names the regulating factors behind the measured d.
- It reads the MFG corridors (`assembly-mfg.md`) as age bands.
- The O4 decomposition can report δ_i per observed species at a site.

## 9. Where it might break

- **Linear and local.** A is a derivative at a state, and (1) is exact only for the direct kernel; A^fb can be large on closed canopies.
- **u_i ≥ 0 is assumed.** Water coupling (more light, more transpiration) can make u negative at some heights. Π then becomes a signed measure, and (2) holds while (3) does not.
- **Horizontal homogeneity within a patch.** Real crowns gap and clump, which breaks the Heaviside form.
- **TF24 specifics:**
  - the light floor at 1e-4 severs elasticity in deep shade, so δ is biased there;
  - k_I appears in both shading and absorbed radiation;
  - with point-mass (PPA) crowns, ties make Π_ii ≠ ½.
- **The Gram form (5) assumes per-leaf elasticity separates as ρ_i τ(a).** Otherwise extra cross terms enter.
- **The metric.** Statements in the identity metric (λ_min(A_s)) and in the dynamic metric (diagonal stability) differ. Coexistence claims should use the second; the current spikes report the first.
- **Evolution may tune δ itself.** If δ is a trait under selection, the ESS may sit near δ = 0 and so near the neutral knife edge. That would be a further prediction, and also a reason the measured convexity margins are so small.