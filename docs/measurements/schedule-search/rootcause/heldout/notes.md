# Held-out trait × climate cases: E6 as built against fresh references

Subject: how TF24's E6 schedule rule, tuned on the ten-case bank, carries to eight trait ×
climate combinations it never saw: its committed run's error against ε, whether its check
run reads that error (C1–C5, also under stress draws), and its cost. References built here
serve later as the truth for the schedule loop once it exists. Every prediction is written
here before the run or analysis it concerns. Scripts are in this directory; outputs in
`scratchpad/deep/rootcause/heldout/` (`runs/`, `logs/`, `sched/`, `queue.out`, `*.log`).
**[m]** measured, **[i]** inferred.

## Summary (written last)

(pending)

## Scope

The coordinator narrowed the round before any run: the held-out set, references with their
convergence checks, and E6 as built (committed run and its check run) on each combination,
scored with C1–C5 and stress draws, with each committed run's distance from ε. The coarse
s = 1.6 rungs, the H5 rungs and the loop policies (B–D) are deferred; their plan is at the end.

## The held-out set

The bank: episodic, dry, long-wet, long-drought (seed 31), episodic-lma (lma ×1.25),
dry-flat, ld-102, ld-105, dry-p50 (root_P50 ×1.2), wet-adG2 (a_dG2 ×1.25). No combination
below is in it; four of the five traits moved here were never moved in the bank (hmat, a_l1)
or never on these records (lma on dry and long-wet, a_dG2 on episodic and long drought,
root_P50 on long drought), and two long-drought weather seeds (104, 107) were never run by
the schedule rounds.

| case | record | seed | move | direction of J [i, from the bank references' elasticities] | why |
|---|---|---|---|---|---|
| dry-lma125 | dry | 31 | lma ×1.25 | down, steeply: ln J ≈ 0.18 − 2.9 or lower | near extinction on the driest record; lma is the trait whose move broke episodic's grid |
| flat-al1125 | dry-flat | 31 | a_l1 ×1.25 | up, ≈ +0.8 | a growth (leaf-area) trait never moved; the season-free dry record |
| wet-lma08 | long-wet | 31 | lma ×0.8 | up, ≈ +1.8 | lma in the other direction, on the wettest record |
| wet-hmat125 | long-wet | 31 | hmat ×1.25 | down, ≈ −1.8 | a growth (size at maturity) trait never moved |
| epi-hmat08 | episodic | 31 | hmat ×0.8 | up, ≈ +2.6 | hmat in the other direction, on the episodic record |
| epi-adG208 | episodic | 31 | a_dG2 ×0.8 | down, ≈ −0.3 | the drydown trait in the other direction from wet-adG2 |
| ld104-p50125 | long-drought | 104 | root_P50 ×1.25 | down, ≈ −0.1 | a hydraulic move on an unseen weather seed (the driest of the eight ε seeds) |
| ld107-adG2125 | long-drought | 107 | a_dG2 ×1.25 | up, ≈ +0.2 | the drydown trait on another unseen seed (the one that sits with seed 31) |

Two dry, two wet, two episodic, two long drought; four raise J and four lower it; one near
extinction; moves of ×0.8 or ×1.25 as the bank's (×1.2–1.25). Each long-drought seed uses
long drought's weight file, as ld-102 and ld-105 do; dry-flat uses dry's.

## Methods

- **Pilots.** `harness/run_record.R` on lib_109, forward only, 54 uniform nodes, 3e-5, the
  record's weight, HMAX 15, splits and soil share on (the bank's held-out pilots, except that
  ld-102/ld-105's pilots ran without splits; every record now runs with splits).
- **E6's schedules** (`mk_sched.R`): a09's graded build from the pilot (BG 90), late edges
  (b > 25) left out, each edge node inset 12 d → committed c; a09's check fill at h/1.6,
  edge nodes inset 7.5 d → check f. Guard: the same code reproduces the bank's saved `insc_`
  and `ins75f_` schedules on dry and episodic-lma to 1e-12.
- **E6's runs**: `adj_run_nk.R` on libS, KNOTS=0, TOL 1e-4, ATOL 1e-4, WEIGHT_SOIL 10,
  WEIGHT_MAX 100, HMAX 15, SHARE 0.1, SPLIT 1, gradient on — the bank's `val_insk_c` /
  `val_ins75_f` setting with TIMES from `mk_sched.R`.
- **References**: `adj_run_nk.R` on adjmap/lib (the lib19 class), knots as stops, TOL 3e-5,
  uniform 215 and 429 nodes, the same weights, splits and share, gradient on; the answer is
  u429 + (u429 − u215)/3 (`extrap`), as every held-out bank reference (`ref_<case>_u215/u429`,
  one_nk.sh's environment). **Convergence check**: the reference's own move,
  (u429 − u215)/3 per quantity in ε; a reference is accepted when its largest own move is
  under 0.15ε (the bank's references move at most ~0.11ε).
- **Scoring** (as `round4/AG/lib.R` score_pair and `proxies/b_loop.R`): 47 quantities
  (ln J and 46 resident elasticities; rooting_depth_max set aside), errors in each
  quantity's resident ε. E6 commits c when every |d/(1 − s)| < 1, d = Q_c − Q_f, s the a09
  shrink proxy(f)/proxy(c) from the case's pilot; then the estimate is d/(1 − s), otherwise
  it commits f with estimate d·s/(1 − s). C1 every |err| ≤ 1; C2 est > 0.25 where |err| >
  0.5; C3 sign right and within ×2 on quantities with max(|err|, |est|) > 1/3, at most
  max(1, 20%) misses; C5 every |est| ≤ 1; C4 nothing throws or refuses. T = cost(c) +
  cost(f) + 2·cost(committed), rows model run_cost (113e-6 s per row, ×4.27 with the
  gradient).
- **Stress draws** (200 per case, both noise models of `proxies/b_loop.R`): E6's decision
  and estimate are made on perturbed values; C1 and the reads are judged on the truth.
  *coord*: + N(0, 0.025²) per quantity shared by the case's two runs + N(0, 0.04²) per run;
  *jit*: + N(0, 0.020²) per quantity + 0.09·z along the hydraulic direction M, per run.
- **Distance from ε**: the committed run's worst |err| W_c (and rms). On the square law
  [i] W_c·1.6² is what the s = 1.6 rung would carry, so W_c ≤ 0.39 says E6's start is at
  least one 1.6 step finer than this case needs, and W_c > 1 says it is too coarse.

## Pre-registration 1 (before any run)

Bank numbers the predictions lean on [m]: E6's committed W 0.30–0.58 on nine cases and 1.28
on episodic-lma (the one fine commit), median ≈ 0.37; per-case T 614–1683 (median ≈ 860);
under stress E6 passes 72.5% (coord) / 87% (jit) of case-draws, its failures C3 on dry,
dry-flat and dry-p50; the moved round's committed-grid errors grew ×1.5–3.9 with a 20–25%
move in a_dG2 or lma.

| # | prediction | probability |
|---|---|---|
| V1 | Every run (8 pilots, 16 E6 runs, 16 reference runs) finishes with finite gradients: nothing throws or refuses | 80% |
| V2 | Every reference converges: largest own move (u429 − u215)/3 under 0.15ε on all eight | 65% |
| V3 | E6 as built (the real runs, no stress) passes C1–C5 on at least 6 of 8 | 65% |
| V4 | Median committed W over the eight in 0.3–0.6 (the bank's band) | 55% |
| V5 | At least one case has committed W > 1 (E6 must commit its check run there) | 50% |
| V6 | The near-extinction case dry-lma125 has the largest committed W of the eight | 45% |
| V7 | On at least 5 of 8, W_c ≤ 0.39: the square law puts the s = 1.6 rung within ε, so E6's start is finer than the case needs | 55% |
| V8 | Median read of E6's estimate (d/(1 − s) against e_c, over \|e_c\| > 0.2) pooled over cases in 0.8–1.25 | 65% |
| V9 | Under stress, E6 passes at most 85% of case-draws (coord), i.e. no better on held-out cases than on the bank's 72.5%–87% | 60% |
| V10 | Per-case T within ×0.6–1.6 of the bank's median (860) on all eight | 65% |
| V11 | The cases that raise J (dense stands) cost more than those that lower it: median T of the four up-moves above the four down-moves | 60% |

## Deferred: the loop on these cases (plan, not run)

Deferred by the coordinator until the loop is built; the references here are its truth.

1. **Rungs.** On each of the eight cases add the s = 1.6 coarse rung of E6's family
   (a09 spacing ×1.6, cap ×1.6, inset 19.2 d; `../h1_mkcoarse.R`'s builder pointed at
   `cases.R`), and H5's rungs at s = 2, 1.6, 1 once H5's rule is settled
   (`../h5/lib.R` h5_sched). Each rung is one `adj_run_nk.R` run in the E6 committed
   setting (`run.sh`'s `e6()` with another schedule): 8 + 24 runs, about 3–5 min each.
2. **Policies, scored offline on the ladders with the loop rules of `../synthesis.md`**
   (judge the last run; e_k = (Q_{k−1} − Q_k)/(R² − 1); T = Σ cost + 2·cost(last); stress
   draws as `score.R`'s, decisions on perturbed values; amplified jitter 0.09/(R² − 1) under
   ε/3 along M; k ≤ 4):
   (A) E6 as is (scored here); (B) from E6's committed start, refine by 1.6 when the pair's
   estimate exceeds ε·(1 − reserve), coarsen by 1.6 (H5 rungs only) when it is under
   ε·(1 − reserve)/1.6²; (C) a cheap start at s = 2.0 refining by 1.6; (D) E6 committed with
   one coarsening step when its estimate is under ε/2.56 (H5 only).
3. **Per case and policy report:** T (rows model), iterations, wasted cost, the final s
   against the oracle optimum (the coarsest rung meeting ε·(1 − reserve) against the
   reference), C1–C5 pass rate under stress, worst final error, estimate read; across cases,
   how often the start already sits at the optimum and whether iterating beats a good start.
4. **Then the real loop**, once built, on the same eight cases with these references, scored
   by `score.R`'s C1–C5 and stress code; the reserve taken from `../moved/notes.md`
   (0.11–0.44 at ±10% depending on the trait) unless the loop estimates at the analysis's
   worst θ.
