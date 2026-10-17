# Moved θ on the θ₀ grid: the reserve a stopping target needs

Subject: how much error a TF24 node schedule built at θ₀ carries at a moved θ on the same
grid, so that a schedule loop stopping at ε·(1 − reserve) at θ₀ keeps the whole local
analysis within ε. Every prediction is written here before the run or analysis it
concerns. Scripts are in this directory; outputs in `scratchpad/deep/rootcause/moved/`.
**[m]** measured, **[i]** inferred (a ratio law, an interpolation, a reading).

## Summary

Three moved cases were run on their parent's E6 committed grid (libS, no knot stops, 1e-4,
gradient on; guards G1–G3 hold) and scored against their own references [m]:

| moved case (move) | W on parent grid | W on own grid | parent's W on its grid | growth W_mp/W_pp | reserve r = 1 − 1/growth | rebuild effect W_mp/W_mm |
|---|---|---|---|---|---|---|
| dry-p50 (root_P50 × 1.2) | 0.28 (rms 0.124) | 0.35 (0.141) | 0.35 (0.159) | 0.81 | 0 (rms 0) | 0.81 |
| wet-adG2 (a_dG2 × 1.25) | 0.55 (0.150) | 0.44 (0.123) | 0.36 (0.093) | 1.51 | 0.34 (rms 0.38) | 1.25 |
| episodic-lma (lma × 1.25) | 1.17 (0.575) | 1.28 (0.678) | 0.30 (0.129) | 3.90 | 0.74 (rms 0.78) | 0.91 |

- **The reserve comes from the trait, not from a stale grid.** Rebuilding the grid at the
  moved θ with the same rule changes W by ×0.81–1.25, and cos(e_mp, e_mm) is 0.99 on
  wet-adG2 and episodic-lma: the moved error is the same vector on either grid. What
  grows is the error constant K(θ) itself. So a loop cannot buy the reserve back by
  rebuilding; it has to hold it, or refine for the worst θ in the analysis.
- **Measured reserves [m]** at moves of 20–25% (outside the resident's ±10%, inside the
  invaders' ×0.5–×2): 0, 0.34, 0.74, matching the near-layout reading (0.2–0.75) in
  shape. On a power law in θ [i, one move per case]: at the resident's ±10%, 0.11
  (root_P50 −10%), 0.16 (a_dG2 +10%), 0.44 (lma +10%), each in one direction only.
  episodic-lma is a near-extinction move (J 1.98 → 0.031), so its law is the least safe.
- **Estimate transfer: the parent's estimate reads θ₀'s error, not the moved one's.** Its
  read of e_mp is about 1/growth: E6's check reads 1.38 (dry-p50, C3 4/5), 0.64 (wet-adG2,
  C3 2/2), 0.15 (episodic-lma, C3 0/30, C1 fails); the x–c pair 0.21, 0.64, −0.03. It
  transfers where K does not move (dry-p50; the check only, as on dry itself), under-reads
  by the growth where it does, and loses the direction on the lma move (cos(e_mp, e_pp)
  0.67). A loop needs either the reserve or one estimate taken at the analysis's worst θ.
- **Grid-to-grid jitter** between two near grids at one θ is rms 0.035–0.145 (dry-p50 0.082,
  cos 0.82), the same size as the whole trait effect on dry (rms 0.116).
- **No single gradient run predicts the growth** (Results 3). S_el, the unnormalised
  sensitivity scale and the median elasticity ratio all read 1.00 / 0.98 / 2.4–2.9
  against growth 0.81 / 1.51 / 3.90: they flag the large lma move (as a lower bound) and
  miss the a_dG2 growth entirely. For invaders S_el runs the wrong way (Results 4). A
  fixed reserve stays; S_el well above 1 can only raise it.
- **Invaders at lma ×0.5 and ×2 on dry's grid** (Results 4): all within ε, all at or
  under the resident's own worst error (W 0.33 and 0.07 in invader ε against the
  resident's 0.35), so against the θ₀ estimate they need no reserve; against the θ′ = θ
  invader the ×0.5 one grows ×1.79 in root_P50 alone. ln J′ errors are ≤ 0.004 in
  absolute terms, 0.0006 at J′ ≈ 7e-23. The resident's check covers them in size
  (W read 1.5–7.4) but not per quantity.
- **Limits:** one scoring step (`score_inv.R`, about 30 s) was started while 4 other R
  processes ran, one over the limit; every run respected it.

## Data and definitions (read before predicting)

- **Cases.** Each moved case is its parent's record with one trait moved by TRAIT_REL
  (`harness/schedule/lattice.R` CASES/HELDOUT, `rootcause/h1_run.sh`):
  dry-p50 = dry with root_P50 × 1.2; wet-adG2 = long-wet with a_dG2 × 1.25;
  episodic-lma = episodic with lma × 1.25 (0.32 → 0.40; ln 1.25 = 0.22, the "22%" of the
  proxies note). The weight file is the parent's in every case.
- **Runs.** `adj_run_nk.R`, libS, KNOTS=0, TOL 1e-4, ATOL 1e-4, WEIGHT_SOIL 10, the
  parent's weight, WEIGHT_MAX 100, HMAX 15, SHARE 0.1, SPLIT 1, gradient on: the E6
  committed setting, with TIMES = the parent's `val_insk_c_<parent>` node times and
  TRAIT_REL = the moved case's. Named `mv_<moved>_on_<parent>`.
- **Errors** in ε (resident ε, `eps_vec`), 47 quantities (ln J and 46 elasticities),
  against the moved case's own lib19-class reference (`rootcause/common.R`, via
  `proxies/lad.rds`). W = worst |err|, rms over the 47, along M = err · M_unit (the
  hydraulic direction).
- **Three errors per case.** e_mp: moved θ on the parent grid (new); e_mm: moved θ on its
  own committed grid (`val_insk_c_<moved>`, saved); e_pp: parent θ₀ on the parent grid
  (`val_insk_c_<parent>`, saved).
- **Reserve.** A loop stopping at θ₀ when W(θ₀) = 1 − r keeps W(moved) ≤ 1 if the moved
  error scales with the θ₀ error under refinement (same h² law). With g = W_mp / W_pp,
  r = max(0, 1 − 1/g). Read on W and on rms. The grid-rebuild effect proper is
  W_mp / W_mm.
- **Estimate transfer.** The parent's estimates of its own committed error, from saved
  runs: the x–c pair, est_x = (e_x − e_c)/(1/s_c − 1), s_c = proxy(c)/proxy(x); and E6's
  check, est_f = (e_c − e_f)/(1 − s_f), s_f = proxy(f)/proxy(c) (proxies from the parent's
  pilot, `a09_late.R`). They are used unchanged as estimates of e_mp. Read = median
  est/err over |err| > 0.2; corr; C3 (sign and ×2 on every quantity with
  max(|err|, |est|) > 1/3, at most max(1, 20%) misses); W read = max|est| / W_mp.
- **Guards.** (G1) the TIMES file equals the parent's committed node times bit for bit;
  (G2) each new run's recorded setting equals the moved case's committed run's except
  TIMES; (G3) one forward-only rerun of a saved committed run (episodic-lma on its own
  grid, the cheapest) reproduces its J bit for bit, so library and runner are unchanged.

## Pre-registration 1 (before any run)

Saved numbers the predictions lean on [m]: W_pp dry 0.35, long-wet 0.36, episodic 0.30;
W_mm dry-p50 0.35, wet-adG2 0.44, episodic-lma 1.28 (rms 0.141, 0.123, 0.678). The
parent grids have 149, 157, 135 nodes against the moved grids' 153, 158, 120.

| # | prediction | probability |
|---|---|---|
| R1 | G1–G3 hold: TIMES identical, settings identical but TIMES, J of the forward rerun bit-identical | 95% |
| R2 | dry-p50 on dry's grid: W_mp within ×1.3 of W_mm (0.27–0.46), so the implied reserve against dry's 0.35 is ≤ 0.25 | 70% |
| R3 | wet-adG2 on long-wet's grid: W_mp in 0.34–0.57 (within ×1.3 of W_mm), reserve against long-wet's 0.36 in 0–0.4 | 65% |
| R4 | episodic-lma on episodic's grid: W_mp ≥ 0.8, so the reserve against episodic's 0.30 is ≥ 0.6 | 70% |
| R5 | episodic-lma on episodic's denser grid (135 nodes against its own 120): W_mp < W_mm = 1.28 | 50% |
| R6 | cos(e_mp, e_mm) ≥ 0.85 for dry-p50 and wet-adG2 (the error is set by the trait and the record more than by which of two near grids is used) | 65% |
| R7 | The parent's E6-check estimate transfers on dry-p50 and wet-adG2 (read in 0.5–2 and C3 passes), not on episodic-lma (read < 0.5, under-reading) | 55% |
| R8 | The parent's x–c estimate transfers on wet-adG2 (read 0.5–2), not on dry-p50 (dry's own x–c read is 0.10) nor on episodic-lma | 60% |
| R9 | Rows of each new run within ±10% of the parent's committed rows (same nodes; the step count moves little with one trait) | 70% |

## Results 1 (`run.sh`, `score.R`; `scratchpad/deep/rootcause/moved/score.log`) [m]

Guards: G1 the three TIMES files equal the parents' committed node times bit for bit; G2
each run's setting equals the moved case's committed run's but TIMES; G3 the forward rerun
of episodic-lma on its own grid gives J 0.0312817366740029, bit-identical, same 3332
steps. Runs took 2–4 min each (forward 42–82 s, sweep 92–164 s); rows ×0.94–1.03 of the
parent's.

| | dry-p50 on dry | wet-adG2 on long-wet | episodic-lma on episodic |
|---|---|---|---|
| nodes (own grid) | 149 (153) | 157 (158) | 135 (120) |
| e_mp: W (quantity), rms, along M, ln J | 0.28 (a), 0.124, −0.10, −0.16 | 0.55 (a), 0.150, −0.01, +0.10 | 1.17 (TF24_cost_scale), 0.575, +1.49, −0.29 |
| e_mm: own grid | 0.35 (a), 0.141, −0.42, −0.16 | 0.44 (a), 0.123, +0.06, +0.13 | 1.28 (r_l), 0.678, +1.97, −0.25 |
| e_pp: parent | 0.35 (a), 0.159, −0.30, −0.15 | 0.36 (a), 0.093, −0.02, +0.08 | 0.30 (a_l1), 0.129, +0.18, −0.23 |
| growth W (rms) → reserve W (rms) | 0.81 (0.78) → 0 (0) | 1.51 (1.61) → 0.34 (0.38) | 3.90 (4.46) → 0.74 (0.78) |
| rebuild effect W_mp/W_mm (rms) | 0.81 (0.88) | 1.25 (1.22) | 0.91 (0.85) |
| cos(e_mp, e_mm), rms diff | 0.82, 0.082 | 0.99, 0.035 | 0.99, 0.145 |
| cos(e_mp, e_pp), rms diff | 0.69, 0.116 | 0.93, 0.072 | 0.67, 0.498 |
| parent's check → e_pp: read, corr, C3 | 1.06, 0.84, 4/5 | 0.97, 0.98, 1/1 | 1.09, 0.99, 2/2 |
| parent's check → e_mp: read, corr, C3, W read | 1.38, 0.80, 4/5, 1.85 | 0.64, 0.95, 2/2, 0.64 | 0.15, 0.65, 0/30, 0.32 |
| parent's x–c → e_pp | 0.10, 0.01, 0/2 | 0.95, 0.88, 1/1 | 0.80, 0.69, 1/2 |
| parent's x–c → e_mp | 0.21, 0.42, 0/1 | 0.64, 0.91, 2/2 | −0.03, 0.00, 0/30 |
| moved case's own check → e_mm | 1.15, 0.94, 3/4 | 0.89, 0.99, 1/1 | 1.18, 1.00, 31/31 |

- On wet-adG2 the same leaf quantities lead on all three runs (a, curv_fact_elec_trans,
  k_I, jmax_25), each about ×1.5 larger at the moved θ; the estimates keep the parent's
  size (a: est −0.35 against err −0.55). On episodic-lma the moved error is a new
  pattern (TF24_cost_scale, r_l, vcmax_25, a_r1, lma, K_s all near ±1, parent's under
  0.25) that the parent's estimates do not contain.
- On dry-p50 the moved run on dry's grid is more accurate than on its own (0.28 against
  0.35): the trait effect is smaller than the jitter between two near grids.
- Power-law reading [i] (post hoc, not a prediction), K ∝ θ^k from the one move:
  k = −1.16 (root_P50), 1.85 (a_dG2), 6.10 (lma); at ±10% growth 1.13 / 1.19 / 1.79 in the
  growing direction, so reserves 0.11 / 0.16 / 0.44 for the resident's range.

## Invader plan (approved and run as below; Results 4)

Invaders at lma ×0.5 and ×2 on dry's E6 committed grid, plus the θ′ = θ invader as the
baseline whose error plays the role of e_pp.

- **Runner.** A copy of `adj_run_nk.R` with one addition: with INVADER_GRADIENTS=1, after
  each `scm$run_mutant(moved(p, inv))` take `census_trait_gradient_tf24(scm,
  "offspring_production")` and store J′, gradient and elasticity per invader (as
  `harness/run_record.R` does). FORWARD=1 skips the stand's sweep; INVADERS_REL =
  `lma=-0.5,lma=1,lma=0` (×0.5, ×2, θ′ = θ). One process.
- **References.** `harness/run_record.R` at the dry reference's setting (u215_dry /
  u429_dry: TOL 3e-5, ATOL 1e-4, SPLIT 1, SHARE 0.1, knots as stops), NODES 215 and 429,
  INVADERS_REL=`lma=-0.5,lma=1` (lma alone; see below), INVADER_GRADIENTS=1, STAND_GRADIENT=0, HMAX=15 (already in the reference's command); extrapolated
  on the square law as every reference is. Its built-in θ′ = θ invader doubles as a guard
  against the saved u215_dry / u429_dry invader (elasticity lma −35.48 / −35.52), so the
  baseline needs no new reference.
- **Scoring.** Invader ε from `eps.csv` (role invader: ln J 0.025, lma 0.198, a_dG2 0.050,
  ...). Reserve for invaders = 1 − W(θ′ = θ)/W(θ′) on the same grid; also whether the
  resident's check estimate reads the invaders' errors.
- **Cost [i]** (on the saved phase times: walk ≈ 0.88 of the stand's forward, walk
  gradient ≈ 0.78 of the stand's sweep): on the grid 70 + 3 × (62 + 119) ≈ 610 s; u215
  97 + 3 × (85 + 263) ≈ 1140 s; u429 237 + 3 × (174 + 553) ≈ 2420 s. About 70 min in one
  process, three outputs of about 1 MB.
- **Risks.** (1) The ×2 walk on dry failed in the sign-changes bank (density overflow at
  year 35.5 after a 26.9-day step, past the ×2 invader's 26.1-day stability limit); E6's
  HMAX 15 should prevent it on the grid, and HMAX 15 is added to the references for the
  same reason — the guard on the θ′ = θ invader checks this does not move the reference.
  (2) J′ at ×2 is about 1e-21 on the other records (ln J′ ≈ −48): its ln J′ and
  elasticities are defined but come from a few early nodes, and ε set at θ′ = θ may not
  be the right yardstick there. (3) Invader errors at ×0.5 (J′ ≈ 790 on dry) may be set
  by where the grid puts nodes for a much more fecund strategy.

### Pre-registration 2 (for the invader run, if approved)

| # | prediction | probability |
|---|---|---|
| I1 | All three walks and their gradients finish on dry's grid and at u215 and u429 (with HMAX 15) | 80% |
| I2 | The reference's θ′ = θ invader matches the saved u215_dry / u429_dry invader within ε/10 on every quantity | 75% |
| I3 | The invader at lma ×0.5 on dry's grid has W(θ′)/W(θ′ = θ) ≥ 1.5 (reserve ≥ 0.33) | 55% |
| I4 | The invader at lma ×2 has W(θ′)/W(θ′ = θ) ≥ 2 (reserve ≥ 0.5) or fails its walk | 60% |
| I5 | The resident's E6 check estimate reads the ×0.5 invader's error with median read outside 0.5–2 | 60% |
| I6 | The S_el ratio (invader at θ′ against the θ′ = θ invader, both on dry's grid) is within ×1.5 of the W growth for both invaders | 30% |
| I7 | At lma ×2 the absolute ln J′ error on dry's grid exceeds 0.025 (the ε set at θ′ = θ) | 60% |

Approved by the main session as written (added at approval, before any invader run: I6, I7,
and ln J′ errors reported in absolute terms too). Runs: `run_inv.sh` (`adj_run_inv.R` on
dry's grid; `harness/run_record.R` on lib_109 for the references, the u215_dry / u429_dry
command of `node-rule/ladder.sh` plus the invaders). Guards: the grid run's stand J equals
`val_insk_c_dry`'s and its θ′ = θ invader's J′ equals the stand's J bit for bit; each
reference's stand J and θ′ = θ invader equal u215_dry's / u429_dry's.
The invaders move lma alone (×0.5, ×2; INVADERS_REL `lma=-0.5,lma=1` on both the grid and
the references), as every trait-moved case here does; the sign-changes bank's J′ ≈ 1e-21
was the invader moved through the hyperparameterisation (INVADERS), a different strategy.

### Pre-registration 3 (before the diagnostic check; `diag.R`, offline on saved runs)

Question: does a quantity a use computes anyway, from one gradient run at the moved θ on
the shared grid, predict the growth W_mp/W_pp (measured 0.81, 1.51, 3.90)? If so, each use
can rescale θ₀'s estimate for free and the loop needs no fixed reserve. Candidates, each a
ratio of the moved run on the parent grid to the parent's committed run:
- **S_el** = rms(E_q/ε_q) over the 46 elasticities;
- **S_raw** = rms(E_q), the unnormalised ln J sensitivities;
- **S_med** = median over q of |E_mq|/|E_pq|;
- **per quantity**: the parent's check estimate rescaled, est_q · |E_mq/E_pq| (the relative
  error of each elasticity held across θ), read against e_mp.
Extra points: the three own-grid rung pairs (x, c, f) of each parent/moved pair, W growth
against the same ratios from those runs (9 points; grids differ, so noisier).

| # | prediction | probability |
|---|---|---|
| D1 | S_el ratio within ×1.5 of the measured W growth on all three cases | 35% |
| D2 | S_el ratio orders the three growths correctly (dry-p50 < wet-adG2 < episodic-lma) | 60% |
| D3 | The per-quantity rescaled check reads e_mp at median 0.5–2 and passes C3 on both wet-adG2 and episodic-lma | 30% |
| D4 | On the 9 own-grid rung pairs, cor(log S_el ratio, log W growth) ≥ 0.7 | 45% |

### Results 3 (`diag.R`, `diag.log`) [m]

| case | W growth (rms) | S_el | S_raw | S_med | J ratio | check read of e_mp: plain → per-quantity rescale | C3 rescaled | W read: plain / × S_el |
|---|---|---|---|---|---|---|---|---|
| dry-p50 | 0.81 (0.78) | 1.00 | 1.00 | 1.00 | 0.83 | 1.38 → 1.30 | 3/3 pass | 1.85 / 1.86 |
| wet-adG2 | 1.51 (1.61) | 0.98 | 0.99 | 0.99 | 1.25 | 0.64 → 0.69 | 2/2 pass | 0.64 / 0.63 |
| episodic-lma | 3.90 (4.46) | 2.47 | 2.85 | 2.42 | 0.016 | 0.15 → 0.36 | 10/32 FAIL | 0.32 / 0.78 |

- **No single-run ratio reproduces the growth.** The three candidates agree with each
  other (they are the same signal) and see only the lma move: 2.4–2.9 against 3.90, and
  per quantity the errors grow ×5–20 where the elasticities grow ×2.5–3.6 (r_l: E ×3.3,
  error −0.11 → −1.09). On wet-adG2 the error grows ×1.5 with no change in any
  elasticity's scale (0.98–0.99): the a_dG2 move changes how hard the leaf quantities are
  to integrate, not their size.
- The 9 own-grid rung pairs give cor(log ratio, log growth) 0.93 for each candidate, but
  that is two clusters (episodic-lma at 2.5 against 2.7–4.4; the rest at 1.0 against
  0.74–1.41); within the six non-lma rungs the ratio is flat while growth runs 0.74–1.41.
- Rescaling the parent's estimate by S_el brings episodic-lma's W read from 0.32 to 0.78,
  but not its pattern (C3 still fails), and does nothing for wet-adG2.
- So a use's own gradient run can flag a large move (S_el well above 1 means the θ₀
  estimate is too small, by at least that factor), but it cannot replace the reserve: a
  growth of ×1.5 passed with S_el = 0.98. Post hoc only: S_el^1.5 = 3.88 on episodic-lma;
  one point does not fix an exponent.

### Results 4: invaders on dry's grid (`run_inv.sh`, `adj_run_inv.R`, `score_inv.R`; `score_inv.log`) [m]

Guards: the grid run's stand J equals `val_insk_c_dry`'s bit for bit and its θ′ = θ
invader's J′ equals the stand's J bit for bit; both references reproduce u215_dry's and
u429_dry's stand J and θ′ = θ invader elasticities bit for bit; no walk or sweep failed
(HMAX 15 throughout). Cost: grid 526 s (stand 64 s; each walk 38–44 s + sweep 104–113 s),
u215 1041 s, u429 2125 s; 62 min in all against 70 planned.

Errors in invader ε (`eps.csv`, role invader; ≥ 0.01), against u215/u429 extrapolated:

| invader (lma alone) | J′ (ref) | ln J′ error, absolute (ε) | W (quantity) | rms | ref's own (u429 − u215)/3, W | growth vs θ′ = θ → reserve | W / resident's W (0.35) | S_el ratio | resident check: read, W read |
|---|---|---|---|---|---|---|---|---|---|
| θ′ = θ | 1.196 (1.200) | −0.0037 (−0.15) | 0.18 (root_P50) | 0.087 | 0.10 | 1 | 0.53 | 1 | —, 2.67 |
| × 0.5 | 6212 (6223) | −0.0017 (−0.07) | 0.33 (root_P50) | 0.068 | 0.03 | 1.79 → 0.44 | 0.94 | 0.38 | −1.26 (one quantity), 1.49 |
| × 2 | 6.66e-23 (6.66e-23) | +0.0006 (+0.02) | 0.07 (r_l) | 0.026 | 0.03 | 0.36 → 0 | 0.19 | 4.93 | —, 7.37 |

- **Every invader is within ε on the resident's committed grid, and none is worse than the
  resident** (W 0.07–0.33 in invader ε against the resident's 0.35 in its own). Counted
  against the resident's error, which is what a loop at θ₀ estimates, the lma invaders
  on dry need no reserve. Counted against the θ′ = θ invader, the ×0.5 invader grows
  ×1.79 (reserve 0.44), all of it in one quantity (root_P50: −0.18 → +0.33, ε 0.012);
  its rms falls (0.087 → 0.068).
- **ln J′ in absolute terms** is accurate everywhere: |error| ≤ 0.0037 (under ε/6), and
  at ×2 (J′ ≈ 7e-23, ln J′ ≈ −51) it is 0.0006. Near extinction the invader is easy for
  the grid; ε at θ′ = θ is not too strict there.
- **The θ′ = θ invader's error is partly the reference's own**: its reference moves 0.10
  ε between u215 and u429 (root_P50), against an error of 0.18. The moved invaders'
  references are tighter (0.03).
- **The resident's estimate does not read the invaders per quantity** (×0.5: cos of the
  errors with θ′ = θ's −0.32, corr with the resident's estimate −0.68), but in size it
  covers them (W read 1.49–7.37): the resident's check over-states the invaders' worst
  error on dry.
- **S_el fails for invaders, inversely**: 0.38 where the error grows ×1.79, 4.93 where it
  shrinks to ×0.36. [i] S_el follows the size of the elasticities, which tracks J′
  (largest at ×2, J′ ≈ 7e-23), not how hard the run is to integrate.

## Predictions scored

| # | P | outcome |
|---|---|---|
| R1 | 95% | confirmed (G1–G3 hold) |
| R2 | 70% | confirmed (W 0.28, reserve 0) |
| R3 | 65% | confirmed (W 0.55, reserve 0.34) |
| R4 | 70% | confirmed (W 1.17, reserve 0.74) |
| R5 | 50% | confirmed (1.17 < 1.28) |
| R6 | 65% | refuted (dry-p50 0.82; wet-adG2 0.99) |
| R7 | 55% | confirmed (1.38 and 0.64, C3 passes; episodic-lma 0.15) |
| R8 | 60% | confirmed (wet-adG2 0.64; dry-p50 0.21; episodic-lma −0.03) |
| R9 | 70% | confirmed (×0.94–1.03) |

| D1 | 35% | refuted (×1.54 off on wet-adG2, ×1.58 on episodic-lma) |
| D2 | 60% | refuted (dry-p50 1.00 above wet-adG2 0.98) |
| D3 | 30% | refuted (episodic-lma C3 10/32) |
| D4 | 45% | confirmed as registered (0.93), but by two clusters, not a trend |

| I1 | 80% | confirmed (no failures, HMAX 15) |
| I2 | 75% | confirmed (bit-identical) |
| I3 | 55% | confirmed (×1.79, all root_P50) |
| I4 | 60% | refuted (×0.36; the ×2 invader is the easiest) |
| I5 | 60% | confirmed as registered (read −1.26), but on one quantity over 0.2 |
| I6 | 30% | refuted (S_el ratio 0.38 and 4.93 against growth 1.79 and 0.36) |
| I7 | 60% | refuted (0.0006 absolute) |

R: 8 confirmed (mean P 66%), 1 refuted (65%). D: 1 confirmed (45%), 3 refuted (mean 42%).
I: 4 confirmed (mean P 68%), 3 refuted (mean 50%). The registrations were close to the near-layout
reading, so they tested little beyond it; the finding they did not anticipate is that the
rebuild effect is near 1 (the reserve is K(θ), not staleness).
