# How a TF24 schedule's error is structured (phase 1: offline analysis of saved runs)

Question: how does a schedule's error in ln J and the resident elasticities (in ε) depend on
the schedule? What predicts it out of sample, so that a cheap in-run flag or stopping rule
could replace the second, finer gradient run? No new runs. Every number is marked
**[m]** (measured from stored runs) or **[i]** (inferred: a model fit, or a reading of
measured numbers).

Scripts are in this directory. Outputs and logs are in
`scratchpad/deep/rootcause/` (`<script>.log`, `*.rds`).

## Data, builds, references

- `inv.R` reads every saved stand run in 18 run directories: 1341 runs, 1040 of them with a
  gradient. `err.R` scores each run against the reference of its own build. `features.R`
  keeps one row per distinct (case, build, tolerance, setting, schedule): **692 runs**
  (lib19 class 632, libAG 26, libS without knots 34). The tolerances are 3e-5 (342 runs),
  1e-4 (281) and 3e-4 (58). Duplicate runs (identical schedule and setting) and the runs
  that make up a reference are dropped.
- **Quantities:** 47 of them, ln J plus 46 elasticities. This is anyscore's set: S_D, a_f3,
  recruitment_decay and rooting_depth_max are excluded. ε comes from `eps_vec`.
- **Builds compared like with like.**
  - **lib19 class.** `lib`, `lib18`, `lib19`, libS and libR with their knot stops are
    bit-identical on identical schedules [m]. Checked pairs: val_c5t vs
    val_probe_noedge25, fx_a04t vs val_a04t, val_a09h vs val_a09g, R_base vs val_a09_c.
    These runs are scored on the harness's lib19 references: `reference()` for the
    training five, and `ref_<case>_u215/u429` extrapolated for the held-out five.
  - **libS / libR without knots (S).** These are scored on the lib19 references too. On
    identical schedules S − lib19 is rms 0.003–0.028, max 0.106 (dry-p50) [m]
    (`q0_builds.R`). That is jitter-sized, so the shared reference is safe.
  - **libAG (averaged gate).** These are scored only on AG's own references (dry, long
    drought, episodic-lma). AG − lib19 on the same schedule is rms 0.66, max 2.7
    (root_P50) [m].
- **Excluded:**
  - E's knot-removed runs (E_k0, E_k25 and G_k25*).
  - The legacy-setting blow-ups (val_a10s, val_a10n1; up to 11662ε).
  - The `lumped*` studies, which used another build: d108_episodic differs.
  - Old runs that moved a trait without recording TRAIT_REL (m_p50*, m_lma125_dry/long-wet,
    estimate's ±lma/±a_dG2).
  - The controller variants (E_, G_, JT, R_, S_) are left out of the models.

## 1. Convergence

`q1_conv.R` works on 21 doubling ladders and 31 triples (h, h/2, h/4). It takes the moves
d1 and d2 between successive levels, so it needs no reference.

- **The order is 2, for every quantity and every case** [m]. On every ladder step whose
  first move exceeds ~0.2ε rms, the pooled order −log2(⟨d1,d2⟩/|d1|²) is 1.8–2.3. The one
  exception is long wet's lattice late axis (2.8, cos 0.47). That
  covers the lattice founders' axis on 5 cases, the uniform u108/215/429 ladders, the
  graded m_th0 and e_* ×1, ×2, ×4 ladders, ld_D u54→429 and AG u215→857. Across ladders,
  the median per-quantity order is 1.8–2.5 for all quantities with signal (ln J 2.0).
  Successive moves keep their direction: cos(d1, d2) is 0.97–1.00 on the founders' and
  graded ladders.
- **One exception: edge-anchored spells at coarse spacing** [m]. On the lattice late axis
  (l 140→70→35 d, edges as nodes), cos(d1, d2) is only 0.47–0.96. The hydraulic
  quantities' first-step order is 0.8 on dry and on episodic, against 2.2–2.4 for the
  rest; their second step is back near 1.9. On the real pairs (`q1_shrink.R`, 195 pairs)
  the shrink from committed to check, f on c, has a median of 0.42 [0.29, 0.51]. The
  proxy's s is 0.42, and measured/proxy is 1.05 [0.77, 1.24]. Hydraulic quantities shrink
  more slowly (0.47 [0.32, 0.65], and 0.66 under libAG); leaf quantities shrink faster
  (0.39 [0.26, 0.49]). One s is therefore right on average, but it under-reads hydraulic
  quantities and over-reads leaf quantities [i].
- Small-move ladders give p ≈ 0.9–1.4: the graded B/BD ladders on long drought and long
  wet, rms moves ≤0.12. There the moves are at the 3e-5 jitter floor [i].
- **Decomposition by birth-date band.** Source: G0 with one band bisected, on the training
  five at 3e-5, `q1_bands.R`; a band's error is taken as −4/3 × its move [m].

  | case | founders | b1–10 | 10–20 | ≥20, non-additivity and jitter |
  |---|---|---|---|---|
  | dry | 80% | 13% | 8% | 3% |
  | long drought | 87% | 10% | 2% | 1% |
  | long wet | 108% | 2% | 2% | 0% |
  | episodic-lma | 107% | 0% | 1% | 0% |
  | episodic | 10% | 12% | 54% | 5% |

  Shares are of G0's squared error. Bands overlap, so the shares need not sum to 100%.
  Founders and spells add: on the lattice the non-additivity is rms 0.005–0.075, against
  errors of 0.04–1.3 [m]. After b = 25 there is almost nothing. Keeping or dropping the
  late edges, or merging short gaps, moves the committed runs by rms 0.005–0.039 (0.07–0.09
  on episodic-lma) [m] (`q2_location.R` c).

## 2. Location

These runs differ in one region only; `q2_location.R`, all [m].

- **a09's committed dry run, one interval class bisected at a time** (X on lib19, AG on
  libAG). Shares are the projection of −4/3 × move on the run's error. The error along M is
  −1.81 on lib19 and −1.28 on libAG.

  | class | lib19 share | lib19 along M | libAG share | libAG along M |
  |---|---|---|---|---|
  | **before a closing edge (C)** | **57%** | −1.38 | **67%** | −1.09 |
  | founders (F) | 32% | −0.27 | 6% | — |
  | interior and late (I) | 12% | ~0 (ln J −0.20) | 6% | — |
  | after an opening edge (O) | −5% (wrong way, +0.18 M) | | −7% | |
  | one-interval spells (S) | −2% | | 5% | |
  | gaps (G) | 1%, rms 0.005 | | −2%, rms 0.044 | |

  The classes nearly add. The whole halving moves −1.70 along M on lib19, against −1.45
  for the sum of classes. The residual is rms 0.16, and six class runs' jitter (≈0.03
  each, ×4/3) accounts for about 0.1 of it [i].
- **Edge nodes moved** (P's runs, lib19, against a09 c). Each move is anti-correlated with
  a09's error, at corr −0.73 to −0.94:

  | move | worst (dry) | rms (dry) | where the move lies |
  |---|---|---|---|
  | a09 c | 0.94 | 0.302 | — |
  | in3 | 0.81 | — | along M |
  | in10 | 0.36 | 0.153 | entirely along M (off-M rms 0.000) |
  | 12 d inset (insc) | 0.34 | 0.155 | — |
  | mid | 0.60 | 0.152 | overshoots |
  | out10 | 0.90 | 0.338 | +0.15, against the error |

  The same holds on episodic, long drought and dry-flat.
- **Reading.** The committed error is two things [i]:
  - founders' interpolation error, whose direction depends on the case;
  - the closing-edge node bias, along a shared direction (M).

  Interior spells, gaps, opening edges and everything after 25 add little at a09's
  spacing.

## 3. Direction

`q3_direction.R`, `q3b_basis.R`.

- **Low-dimensional, but not one-dimensional** [m]. On committed-quality runs (lib19, 1e-4,
  rms ≤0.5, 216 runs) the first three principal components carry 72%, 17% and 6% of the
  squared error. Three components reach 90%. PC1 lies along M (cos 0.87): a_l1, a,
  curv_fact_elec_trans, k_I, storage_relaxation_offset, root_P50, omega. Within one case,
  PC1 carries 66–94%. Leave one case out: the other nine cases' top-3 components hold
  86–96% of the held-out case's squared error, but their top-1 holds only 18–89%.
- **Two physical directions behave differently** [m].
  - **The spells' move** (lattice l 140→70) points the same way in every case: cos
    0.81–0.92 across dry, episodic, episodic-lma and long drought, and 0.49–0.77 with long
    wet.
  - **The founders' move** depends on the case: cos runs from −0.71 (episodic-lma against
    dry) to 0.95 (dry against long drought).

  So the edge part of the error transfers across cases and the founders' part does not
  [i].
- **Share along M** [m]. Pooled, M carries 56% of the committed-quality squared error. By
  case: 0.70–0.75 for dry, dry-p50 and dry-flat; 0.42–0.49 for episodic and long drought;
  0.09–0.22 for long wet, wet-adG2, ld-102 and episodic-lma.
- **ln J's error predicts the M component, not the whole vector** [m].
  - corr(ln J error, along-M error) is +0.78 pooled, and 0.69–0.96 per case except
    wet-adG2 (0.18).
  - The slope (along-M per unit of ln J error, both in ε) is +4.4 to +9.2 per case.
  - Fitted out of sample, β·lnJ leaves 0.54 of an along-M rms of 0.97. It fails where M is
    small: episodic, wet-adG2, episodic-lma (residual/raw 1.15–1.8).
  - Spearman correlation between |ln J error| and rms is 0.77.
  - As an estimator of the whole vector (the check run forward-only, each quantity =
    β_q × ln J's estimated error, β_q fitted on the other nine cases) it reaches only corr
    0.59 and C3 on 22% of pairs (`q4_cheap.R`).

## 4. Predictability (leave-one-case-out)

**The bar: the check run's own estimate** (`q4_check.R`, 199 committed/check pairs, all ten
cases) [m].

- The estimate (c − f)/(1 − s) of the committed run's own error, rms est/err: median
  1.01 [10–90%: 0.86, 1.19].
- Median corr 0.97. C3 holds on 95% of pairs (lib19 98%, S 90%, libAG 4 of 8). C2 holds on
  98%.
- As a stopping rule (`q4_bound.R`, 178 committed runs), the estimated worst error over
  the true worst is 1.01 [0.84, 1.19]. It accepts 85% of runs, none of the accepted runs
  exceeds ε, and it accepts 94% of the runs that are truly within ε.

**A-priori predictors** (`q4_case.R`, `q4_model.R`, `q4_model2.R`):

- **a09's proxy as it is cannot be compared across cases** [m]. Its weight is the pilot's
  nrr^0.6 in absolute units. Per case, the error per unit of proxy varies 101× in the
  founders and 89× in the spells (lattice single-axis moves, 10 cases). Out of sample, log
  rms against the proxy has R² −0.39. It is fine inside one case, where only ratios are
  used (the shrink s).
- **Normalised by the pilot's J**, the weight becomes (nrr/J_pilot)^0.6 and the spread
  falls to 7.8× (founders) and 14.5× (spells; dry-flat alone is 7×–20× above the rest)
  [m]. The best single pilot predictor of the per-case factor is the pilot's ln nrr level
  in the spells (LOCO median ×1.4, max ×3.3). That is the same normalisation seen another
  way [i].
- **Variance-sum model.** rms² = a_F z_F² + a_S z_S² + a_L z_L² + floor(tol), where z are the
  normalised band proxies.

  | what is predicted | median factor | 90% | within ×2 | R² of log rms |
  |---|---|---|---|---|
  | all 631 runs | ×1.39 | ×2.5 | 82% | 0.62 |
  | committed runs only (135) | ×1.37 | ×1.84 | 92% | 0.93 |

  These figures are out of sample [m]. Biases by held-out case: episodic-lma is
  under-predicted ×2.7 (its founders' error per unit proxy is 2× the others'), dry-flat
  ×1.85 (edge-dense), the rest ×0.68–1.39. The fitted jitter floor is ≈0.03ε rms at 1e-4
  [i]. The edge-node term gets no weight because it is collinear with the spell proxy.
- **As a stopping rule it cannot replace the check** [m]. Covering 90% of committed worst
  errors needs a ×1.86 margin (bound/worst [1.01, 2.85]). The rule then accepts only 22% of
  the runs truly within ε, and 8% of the accepted runs exceed ε. Rescaling it by ln J from
  a forward-only check makes it worse (82% coverage, ×3.35 margin).

**In-run predictors.**

- **Edge-node curvature from the run's own per-node nrr.** It is strong within a case and
  weak across cases [m] (`q4_edge.R`). Within each case, along-M error correlates −0.66 to
  −0.97 with the edge-node curvature (episodic-lma −0.66). The a-priori edge term
  (Σ node-at-edge × h_end² × w) does the same, at −0.78 to −0.98. Out of sample, the best
  single predictor cuts along-M rms only from 0.82 (training mean) to 0.73.
- **Node quadrature over the whole run** (F's estimate): LOCO R² 0.13 together with the
  tolerance [m]. F had already found it anti-correlated with the error across the ten
  committed runs.

**Overfitting with ten cases.**

- The case-level screens are 10 points each, with one record per held-out case. The
  normalisation by J was chosen after seeing `q4_case.R`, so its LOCO numbers are
  optimistic [i]. It is a units argument, not a fitted shape, but treat ×1.4 as a lower
  bound on the true out-of-sample error.
- Within-case correlations come from runs that are variants of one another (nested,
  shifted), not independent draws.
- Only 8 libAG pairs exist, all on dry, long drought and episodic-lma.

## What looks strongest, and what it is good for

- **A-priori:** the J-normalised a09 proxy, as a sum of founders, spells and late error
  powers. Out of sample, its median factor is ×1.37 on committed runs (92% within ×2). It
  gives a magnitude but no sign and no per-quantity split. It misses the two
  structurally different cases: episodic-lma's founders (×2.7) and dry-flat's edges
  (×1.85). Good for: sizing a schedule before any gradient run, and as a guard that
  flags "expect worst > ε/2" (sensitivity 86%, specificity 72%). Not good enough to
  certify a committed run: certifying needs a per-quantity, signed reading, and the
  structure is three-dimensional with a case-specific founders direction.
- **In-run:** edge curvature from the run's own nodes. It tracks the dominant
  closing-edge component within a case (|corr| 0.66–0.97) but carries no cross-case
  scale, and it says nothing about the founders' part.
- **The check stays far ahead:** within ×1.2 per run, 95% C3. What would make a cheap check
  possible is a change to the structure, not a better predictor [i]:
  - Remove the closing-edge bias (P's inset): that removes the M part, most of the
    committed error on dry-type records.
  - Size the founders to their own order-2 error, which is case-specific in direction but
    clean in order.
  - What then remains is close to the jitter floor (0.03ε at 1e-4 on lib19; 0.11 under
    libAG, X's measurement), which no schedule predictor can read.
