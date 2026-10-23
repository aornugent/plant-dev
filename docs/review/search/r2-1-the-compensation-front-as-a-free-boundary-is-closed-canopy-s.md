# The compensation front as a free boundary: is closed-canopy selection set by ecology or by a regulariser?

# The founder window: the closed-canopy knife edge is a tie at the top of the canopy, and resolving it gives a tournament

## 1. Headline

The closed-canopy knife edge, d ln R′/d ln P ≈ 3.5e3–7.6e3, comes from neither the reserve regulariser ε nor an understorey compensation front. It sits entirely in the first node of the birth-date schedule. That node lumps 0.185 yr of seed rain into one block of identical plants at the top of the canopy, and the rare type is tied with that block. Resolve the first weeks after disturbance and the gain falls to 101, symmetric and linear. What remains is an ecological boundary layer in birth date, the *founder window*. It is about 13 days wide, it scales exactly with seed rain (W(s) = W₀ f(s√b), W₀ ∝ 1/b), and it carries about 40% of lifetime reproduction. Inside it, selection is a lottery and tournament on head start. The resolution of selection there is set by the spread of founders' arrival and size, which is the brief's "w", moved from carbon balance to rank.

## 2. The departure

Two canonical habits are dropped here.

1. **Adaptive dynamics and EEO treat the birth-date (patch-age) integral as smooth.** Invasion fitness is R′ = ∫ρ(s)W(s)ds, and cohort models (SCM, EBT) put quadrature nodes on it as if W varied on the scale of stand development. Each node is a set of plants with zero spread, which is a *tie*. Under one-sided light competition a tie at the canopy top is dynamically unstable. Forward simulators never see this, because the resident's own tie is symmetric: all its members thin together. Toy height games (Givnish; Iwasa, Cohen & Leon) assume a smooth or a step competition function. Neither had the boundary layer or its scaling.
2. **The front hypothesis put the sensitivity in near-zero carbon balance.** The measurements below place it in *rank at establishment*. The relevant "individual variation" is the spread of arrival and initial size among founders, not the spread of P around compensation.

## 3. The formulation, with measurements on TF24

These are measurements on the closed stand of `field-dimension-066` / `leaf-table`, with the build used there. Scripts and outputs are in `/tmp/front/`; the driver is `run_inv.R`. Leaf P was scaled by `PLANT_LEAF_PSCALE`.

### 3.1 Where the knife edge is

The identity invader was rerun, P scaled by 1 ± 1e-4 and 1 ± 1e-5, and ln R′ was split by node (`net_reproduction_ratio_by_node`).

- **Node 1 (introduced at patch age 0).** Δ ln W₁ = +0.56 / −1.30 at ±1e-4 and +0.097 / −0.110 at ±1e-5, a gain of 5.6e3–1.3e4. It is asymmetric.
- **All 35 other nodes.** Gains are 9–140, symmetric and linear. This includes the deeply suppressed cohorts born at ages 26–36, with W from 1e-6 to 1e-21 and starving for years. They have gains of 90–140, not thousands.

So the front hypothesis (E4, E5, E7 as stated) does not describe these runs: suppressed cohorts carry ordinary gains.

### 3.2 It is the schedule

The resident's first interval (0.37 yr) was split, keeping everything else fixed.

| first block of seed rain, B | B/τ_f | gain of node 1, held field | resident F |
|---|---|---|---|
| 0.185 yr (standard 108-node schedule) | 5.1 | 5.6e3 / 1.3e4 | −8.5e-5 |
| 0.093 yr (split ½) | 2.6 | 7.6e2 / 8.5e2 | 0.104 |
| 0.023 yr (split ⅛) | 0.64 | 45 / 45 | 0.120 |
| geometric refinement (4, 8, 12 levels) | ≪ 1 | – | 0.16453, 0.16460, 0.16455 |

On the geometric-8 schedule, with the invader on the same nodes, the identity invader reproduces F exactly (0.1646034). Its **resolved held-field gain is g_P = 100.4 (+1e-3), 101.2 (−1e-3) and 101 (±1e-4)**: linear, with no step.

The **kept (stand) derivative** F_P, with every resident's P scaled, is **11.0 (coarse) and 11.6 (resolved)**.

Consequences:
- The standard schedule mis-states the closed resident's balance by 0.165 in F, about 0.11 in ln b\* at dF/d ln b ≈ −1.43.
- The "1.0 shift from thinning the invader schedule" is the same artefact. On the resolved resident, the every-third invader gives ln R′ = 2.42 against a true 0.165.
- The open stand's window is wide (W halves at about 0.27 yr), and refinement moves its F by only 0.002. That explains the ordinary gain of 49 there.
- ε was never implicated. The regulariser is the node spacing at s = 0.

### 3.3 The founder window (resolved, closed stand)

Write s for arrival patch age and W(s) for lifetime reproduction per arrival.

| s (days) | 0 | 4.2 | 8.4 | 17 | 34 | 51 | 68 | 135 |
|---|---|---|---|---|---|---|---|---|
| W(s) | 988 | 844 | 652 | 195 | 18.8 | 3.5 | 1.24 | 0.099 |

The window contains 39% of R′ (inner mass 34.8 against 53.9 for the rest). Three resolved residents at b\*/2, b\* and 2b\* were then run:

- **Amplitude.** W₀·b = 34.4e3, 36.0e3, 37.8e3, an elasticity of −0.93: **W₀ ∝ 1/b**.
- **Width.** The fitted width is τ_f = 19.5, 13.2 and 9.6 days, and τ_f√b = 0.228, 0.219, 0.225: **τ_f ∝ b^(−1/2)**. W(s)/W₀ collapses onto s√b to within 1–5% over the core (s ≲ τ_f) and departs in the tail.
- **Inner mass.** R′_in ∝ W₀τ_f ∝ **b^(−3/2)**. The measured inner elasticity is −1.51; F's is −1.43.

**Reading the scaling (heuristic).**
- *Amplitude.* The first arrivals share a canopy whose final occupancy is fixed by self-thinning. Per-capita payoff is then canopy over arrivals, so W₀ ∝ 1/b. That is a lottery.
- *Width.* The cost of arriving s late is the leaf area of those ahead (∝ bs) times the light gradient across the height gap (∝ ḣ₀s). So −ln(W/W₀) is a function of bs², which gives the s√b collapse.

### 3.4 The tie lemma (why a node at s = 0 explodes)

Consider a block of identical plants with leaf area index L_B at the canopy top, and a rare type of relative height 1 + η inside it. For TF24's crown (Q = (1 − u^η)², η = 12), the crown-mean light obeys

  ∂ ln L̄/∂η |₀ = c·k·L_B,  c ≈ 4.2–4.7

(computed: 2.1, 4.4, 9.2 and 14.2 at kL_B = 0.5, 1, 2, 3).

- The upside is bounded: L̄ → 0.95–0.98 once the rare type is clear of the block.
- The downside is not: the rare type sinks into the block's foliage.

Linearising the height gap gives η̇ = γ(a)η + δψ(a), with

  γ = (ḣ/h)·(∂ ln G/∂ ln L̄)·c·k·L_B,

where G is growth. The held-field gain is therefore ∝ ∫ψ e^{∫γ}: **exponential in the tied mass**. The measured ln-gain against B/τ_f (8.9, 6.6, 3.8 at 5.1, 2.6, 0.64) is consistent with this.

The resident does not feel it, because the whole block moves together. That is the commons in pure form: the tie converts the population's contest into a scramble and the rare type's into a contest.

**With spread.** Give the block a spread w_s in arrival (or w_h = ḣ₀w_s in initial height). For w_s ≪ B ≲ τ_f the exponential is cut off, and the gradient on head start becomes a smoothed tournament derivative ∝ 1/w_s. The brief's E10 ("selection resolution set by individual variation") holds here, for rank at establishment.

### 3.5 Selection in the window is a boundary term

A trait that gives head start H (initial height, germination speed, seed mass) shifts effective arrival to s − H/ḣ₀. Then

  ∂R′/∂H = −(1/ḣ₀)∫ρW′ds = (1/ḣ₀)[ρ(0)W(0⁻) + ∫ρ′W ds].

With ρ flat near 0, **g_H = ρ₀W(0⁻)/(ḣ₀R′)**: a pure boundary term carried by the first arrivals. W(0⁻) is bounded, because a plant cannot see more than open light. On the resolved stand, ρ₀W₀/R′ ≈ 988/88.7 ≈ 11 per year of head start, about 0.03 in ln R′ per day.

The pairwise invasibility plot along H is smooth when founders have spread and a one-sided step when they are tied:
- the upside is J⁺ = ln(W_open-top/W₀);
- the downside is the window's flank.

This is E7's asymmetric step, relocated to synchronous recruitment.

### 3.6 Through the tournament matrix Π

In the window, both a species' elasticity and its leaves sit at the canopy top, so the species are aligned. Π_ij is the probability that j's head start beats i's, and Π + Πᵀ = 11ᵀ.

Since W₀ ∝ 1/(total arrivals), the inner layer is an exact lottery: **δ_i = 0 and the window stabilises nothing**. Coexistence must come from elsewhere:
- **Covariance across disturbance events.** If founding weather differs between patches, as with real daily records and disturbance dates, Chesson's storage effect acts on the founder lottery. Long-lived adults are the storage.
- **A trade-off between window and outer layer.** One species wins head start and another wins later, shade-tolerant arrival. This replaces X1's "fronts at distinct heights" with "window against outer layer".

### 3.7 What survives of the reserve-front theory, and how it changes

These are read from the resident's collected trajectories.

**Two reserve regimes.** The relaxation time is τ_r = S_max/(charge + drain) + 7 d, and at P ≈ 0 it is about S_max/ε. S_max = a_st1·m_sap(h) is:

| h (m) | 0.375 | 1 | 2 | 3 | 10 |
|---|---|---|---|---|---|
| S_max (kg) | 6.9e-7 | 4.5e-5 | 8.7e-4 | 4.9e-3 | 0.84 |

- Below about 1.5–2 m, reserves are quasi-static and the knife has width ε (E1's table applies).
- Above that, reserves integrate P: ln r = ln r₀ − ∫P₋/S_max. The hazard switches on when Φ = ∫|P|/S_max ≈ ln(a_dG2·r₀) ≈ 2. The width is ecological, S_max/T_deficit, and **ε drops out**.
- Seedlings are born at x = P/ε ≈ 1.4–4.4. ε (2.6 seed masses per year) does shape establishment, by adding up to ε/2 of storage-funded growth.

**Thinning is seasonal and borne by the canopy.** On the long-wet record every cohort swings between P ≈ +65 and −150 kg/yr (canopy trees). Dry phases drain r from about 0.35 to 0.02–0.15, with μ up to 3–5.5/yr. The founder cohort reaches M = 17.8 by age 40, of which d_I contributes 0.4, while thinning at d ln N/d ln A_leaf = −1.70. Lemma 1, transposed: self-thinning through starvation pins the *depth of the seasonal reserve crash* of the canopy, not the carbon balance of an understorey layer.

**Commons (Lemma 3, measured).** F_P/g_P = 11.6/101 = 0.115. About 89% of a private carbon advantage is displacement. The cancellation is strong but leaves an O(10%) residue, not O(ε).

## 4. The ecology

- **Fitness after stand-replacing disturbance is decided within weeks.** In a closed stand, arrivals in the first ~2 weeks carry ~40% of lifetime reproduction. Arrivals at 135 days have 1e-4 of the first arrival's W. Egler's initial floristic composition, and the "first regenerated dominate" pattern in boreal stands (Kulha et al. 2023), become a quantitative law: the window ∝ b^(−1/2), the founders' payoff ∝ 1/b, and the inner mass ∝ b^(−3/2).
- **Strong selection for disturbance-cued arrival.** Serotiny, fire-cued germination, soil seed banks and resprouting all move arrival to s = 0. A per-seed advantage of W₀/⟨W⟩ over uniform arrival is large: about 10² on rough uniform patch weights, to be redone with the patch-age density. This is the regnans case. *E. regnans* is an obligate seeder whose canopy seed falls just after fire, so its stands are a founder block.
- **Tied cohorts are an ecological reality where recruitment is synchronous** (post-fire seedfall, masting). There, the knife-edge regime of §3.4 is real. Selection on seedling head start scales as 1/w (within-cohort spread of emergence and size), with an asymmetric step: overtopping pays little, falling behind costs a lot. Prediction: obligate seeders with synchronous germination show stronger selection on emergence speed and seed mass, and lower within-population variance in them, than species with continuous recruitment. The instability also makes size bimodality in even-aged stands (Huston & DeAngelis; Weiner) an evolutionary pressure, not only a pattern.
- **The window is a lottery, so it does not stabilise.** Light-mediated coexistence in closed stands must come from the outer layer (later arrivals, shade tolerance), from age-band differences (the mathematics proposal's age Gram), or from variation in founding conditions across disturbances (storage effect).
- **Uniform production gains are mostly displacement** (F_P/g_P ≈ 0.12): CO₂ fertilisation of a self-thinning stand mostly reshuffles who wins.

## 5. Why us

1. **Per-node fitness and its exact response.** Every finding here came from decomposing ln R′ by birth date and perturbing one strategy's P in a held field. A forward simulator with a coarse cohort grid sees a "knife edge" and cannot tell an artefact from ecology. The per-node decomposition located it in one node in one run.
2. **The field cut.** Held against kept, 101 against 11.6 on one engine, gives the commons ratio exactly. On the tape, costates resolved by node would give the window's density of selection directly; the flank nodes at s ≈ 17 days carry gains of about 258, against about 60 at s = 0.
3. **Certified discretisation.** τ_f ∝ b^(−1/2) is predictable before running, so node schedules can be designed to resolve the window. Geometric refinement at 4 levels already gives F to 4 digits.
4. **Real weather records** make the window's founding conditions vary with disturbance date. That variation is the only route to stabilisation inside the lottery, and toy lottery models impose it rather than derive it.

## 6. Prior art and the delta

**Known:**
- Seed-size games with asymmetric seedling competition, steps, branching and continua of seed sizes (Geritz 1995; Rees & Westoby 1997; Geritz, van der Meijden & Metz 1999).
- Lottery competition and the storage effect (Chesson & Warner 1981).
- Priority effects and emergence timing (Fukami 2015; Mercer et al. 2011; van Steijn et al. 2026).
- First-regenerated dominance (Kulha et al. 2023).
- Size-asymmetric competition and bimodality (Weiner & Thomas 1986; Huston & DeAngelis 1987; Schwinning & Weiner 1998).
- Height games (Givnish 1982; Iwasa, Cohen & Leon 1985).
- The node refinement in `plant` itself (Falster et al. 2016).

**Delta, as far as I can tell (brief search; check before leaning on it):**
1. The inner/outer decomposition of invasion fitness in birth date. In a mechanistic canopy model, the inner layer's laws are W₀ ∝ 1/b, collapse onto s√b, and R′_in ∝ b^(−3/2).
2. The tie lemma: a zero-spread cohort node at the canopy top gives a held-field gain exponential in its mass, which explains a measured 1e4 gain as an artefact.
3. The head-start gradient as a boundary term.
4. The lottery identity δ = 0 for the window.
5. The measured commons ratio.

Geritz et al. impose a site-level step competition function. Here the step emerges from radiative transfer in a tie, and its width is derived.

## 7. Worked case (checkable, mostly already checked)

- **Tie arithmetic (computed).** For kL_B = 2, ∂ ln L̄/∂η = 9.2, and the upside saturates at L̄ = 0.953 from 0.432 (J⁺ ≈ 0.79 in ln L̄).
- **The schedule table of §3.2 (run).** Halving and then eighth-ing the first block takes the gain from 1e4 to 8e2 to 45.
- **Scaling (run).** τ_f√b is constant to ±2% across a 4× range of b.
- **Head-start gradient (predicted, uncomputed).** g_H ≈ 11/yr. A seedling-height mutant equivalent to one day's earlier emergence should gain about 0.03 in ln R′. Check with an invader whose initial height is raised by ḣ₀ × 1 day on the resolved schedule.
- **ε test (prediction, replacing E2's).** Halving `storage_prod_eps` will *not* double the closed gain. On the resolved schedule, |∂ ln R′/∂ ln ε| ≲ 1, concentrated in seedlings born into shade.

## 8. What it opens

**Immediate consequences:**
- Every closed-canopy number on the uniform 108-node schedule should be recomputed with refinement near s = 0. That covers the field-dimension spectra (closed mode-1 nonlinearity, the 36% trait loading and the held-out failure), A on two-closed-31, and the leaf-table verdict. At gain 101, the 524k table's bias of −3.9e-4 gives about −0.04, which is usable for screening.
- Pricing near residents need not be one-sided once the window is resolved.

**Theory:**
- An ESS on the arrival distribution, mixing uniform arrival and disturbance-cued arrival, as a game in s.
- The storage effect on the founder lottery under real records (workflows.md §2, phase-averaging over disturbance dates).
- An HJB view of the mean-field game, in which the window is a boundary layer of V\*.
- Founder spread w as a trait.

**Field predictions:**
- Inner-layer share and window width fall with seed rain as b^(−1/2).
- Synchronous-recruitment species are under stronger, purifying selection on emergence speed.
- Fertilisation of self-thinning stands raises mortality more than it raises survivorship.

## 9. Where it might break

- **One stand, one record, one build.** The s√b collapse is measured over a 4× range and holds in the core only, and its derivation is heuristic.
- **R′ normalisation of `by_node`.** The 39% inner share and the "~10²" serotiny ratio use trapezoid weights in birth date, not the patch-age density. The ratios between runs are robust; the absolute shares need the proper weights.
- **Deterministic arrival.** Real disturbance is patchy and seed arrival stochastic, which smears the window. The laws should then hold with τ_f replaced by max(τ_f, w_s).
- **Water.** On the long-wet record, thinning is seasonal drought starvation. On a light-only stand, the founders' thinning and hence W₀'s scaling may differ.
- **The kept sweep was a finite difference of a stand-wide PSCALE** (±1e-3), not the tape. It agrees on two schedules (11.0, 11.6).
- **ε is not exonerated everywhere.** Seedlings live at x ≈ 1–4. Establishment-dominated regimes (open, dry) may still feel it.

Sources:
- [Geritz, van der Meijden & Metz 1999 (IIASA record)](https://pure.iiasa.ac.at/5706)
- [Seed mass diversity and size-asymmetric competition (arXiv 1709.09391)](https://arxiv.org/pdf/1709.09391)
- [van Steijn et al., germination speed and priority effects (PMC12830169)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12830169/)
- [Kulha et al. 2023, boreal regeneration dominance (UTU record)](https://research.utu.fi/converis/portal/detail/Publication/180407325)
- [Mercer et al. 2011, sunflower emergence selection](https://excelsior.asc.ohio-state.edu/~asnowlab/Mercer et al _2011sunflower.pdf)

Other references are from memory and unchecked: Egler 1954; Chesson & Warner 1981; Fukami 2015; Weiner & Thomas 1986; Huston & DeAngelis 1987; Givnish 1982; Iwasa, Cohen & Leon 1985; Falster et al. 2016.

**Files:**
- Drivers: `/tmp/front/run_inv.R` (options `GEOM`, `FIRST_SPLIT`, `INV_ALL`, `LNB_SHIFT`), `/tmp/front/run_closed.R`, `/tmp/front/analyse.R`, `/tmp/front/lai.R`.
- Outputs: `/tmp/front/{inv_*,sp_*,geo_*,kept_*,held8_*,lot_*,open_*}.rds`.
- Code read: `plant/inst/include/plant/models/tf24_strategy.h` (storage at lines 2036–2104, mortality at 2704–2734, establishment at 2781–2793) and `ff16_strategy.h` line 1412.