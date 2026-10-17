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

## Pre-registration 2 (after three cases were scored, before any third reference rung)

Three references moved more than expected on their own [m, interim]: largest
(u429 − u215)/3 is 0.13ε (dry-lma125), 0.18ε (flat-al1125, `a`) and 0.28ε (wet-lma08,
`a_l1`), against a 0.15ε acceptance line. A two-rung reference whose own move is that size
can be off by a comparable amount if the order is not 2. So every case whose own move
exceeds 0.15ε gets a third rung, u857 (same recipe, 857 uniform nodes), and its reference
is re-read as u429 → u857; the order is read from the two moves (p = log2(|m1|/|m2|) on
quantities whose u215 → u429 move exceeds 0.3ε).

| # | prediction | probability |
|---|---|---|
| R1 | On every such case, the u429 → u857 reference agrees with the u215 → u429 one within 0.15ε on every quantity | 55% |
| R2 | The pooled order of the reference ladder on those cases is in 1.6–2.4 | 70% |
| R3 | No case's E6 verdict (C1–C5 pass or fail, real runs) changes when it is scored against the u429 → u857 reference | 80% |

Added before their runs (compute freed by the coordinator): u857 also for dry-lma125 and
epi-adG208, whose own moves (0.13ε, 0.14ε) sit just under the line. R1–R3 are scored on the
three cases over the line (flat-al1125, wet-lma08, wet-hmat125, the last over it at 0.30ε);
the two extra cases are reported beside them.

## Results 1: pilots, schedules, E6 and the two-rung references (`run.sh`, `mk_sched.R`, `score.R`; `score.log`, `score_tab.csv`) [m]

**Guards.** `mk_sched.R` reproduces the bank's saved committed and check schedules on dry and
episodic-lma exactly (max difference 0). `score.R` puts the bank's stored E6 pairs through the
same code and gets T 9287 and 10/10, as `proxies/notes.md`; its stress draws give the bank
73.8% (coord) and 86.8% (jit) of case-draws, against 72.5% and 87% there (other seeds).

**Pilots and schedules.** All eight pilots finished (15–32 s). J from the pilots: dry-lma125
0.011 (near extinction, ln J −4.5), flat-al1125 6.7, wet-lma08 80, wet-hmat125 1.07,
epi-hmat08 13.2, epi-adG208 1.40, ld104-p50125 6.96, ld107-adG2125 15.9. Committed / check
nodes 134–173 / 200–245 (ratio 1.36–1.53, as the bank's), a09 shrink s 0.26–0.51 (bank
0.38–0.45 typical).

**Every run finished** (8 pilots, 16 E6 runs, 16 reference runs): no refusal, every gradient
finite. E6 runs 3–7 min each, references 5–16 min.

| case | ln J | nodes c/f | s | ref own move max (q) | W_c (q) | rms_c | W_f | commit | C1–C5 | C3 | read | corr | T | stress coord / jit |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| dry-lma125 | −4.48 | 139/204 | 0.41 | 0.13 (storage_relaxation_offset) | 0.71 (a_l1) | 0.26 | 0.48 | c | **FAIL C3** | 14/23 | 1.45 | 0.81 | 682 | 0.00 / 0.005 |
| flat-al1125 | 1.85 | 173/235 | 0.42 | 0.18 (a) | 0.68 (a) | 0.31 | 0.32 | c | pass | 18/18 | 0.94 | 0.98 | 1434 | 0.97 / 0.99 |
| wet-lma08 | 4.25 | 169/245 | 0.26 | 0.28 (a_l1) | 0.53 (a_l1) | 0.16 | 0.20 | c | pass | 3/3 | 0.79 | 0.98 | 1185 | 0.97 / 0.99 |
| wet-hmat125 | −0.05 | 155/231 | 0.43 | 0.30 (a) | 0.71 (a) | 0.21 | 0.31 | c | pass | 6/6 | 1.02 | 0.99 | 976 | 0.74 / 0.975 |
| epi-hmat08 | 2.59 | 143/215 | 0.51 | 0.08 (a_l1) | 0.21 (a_l1) | 0.06 | 0.14 | c | pass | 0/0 | 0.62 | 0.95 | 643 | 0.865 / 0.97 |
| epi-adG208 | 0.37 | 134/205 | 0.33 | 0.14 (a_l1) | 0.39 (root_P50) | 0.14 | 0.19 | c | pass | 2/2 | 0.96 | 0.95 | 612 | 0.96 / 1.00 |
| ld104-p50125 | 1.92 | 142/209 | 0.43 | 0.07 (vcmax_25) | 0.26 (a_l1) | 0.09 | 0.09 | c | pass | 0/0 | 1.12 | 0.98 | 848 | 0.885 / 0.995 |
| ld107-adG2125 | 2.74 | 135/200 | 0.41 | 0.08 (a_l1) | 0.24 (a) | 0.10 | 0.13 | c | pass | 0/0 | 0.84 | 0.96 | 811 | 0.95 / 0.99 |
| **held-out** | | | | 0.07–0.30 | median **0.46** [0.21–0.71] | | | 8 c | **7/8** | | 0.95 | | 7191 (median 829) | **0.79 / 0.86** |
| bank (same code) | | | | ≤ ~0.11 | median 0.37 [0.30–1.28] | | | 9 c, 1 f | 10/10 | | 0.99 | | 9287 (median 856) | 0.74 / 0.87 |

(read = median of d/(1 − s) over e_c on quantities with |e_c| > 0.2; T in the rows model.)

- **Distance from ε.** Every committed run is inside ε (W_c 0.21–0.71) and E6 commits c on all
  eight. On the square law [i] the spacing that would just meet ε is s* = W_c^(−1/2) =
  1.19–2.21 times E6's committed spacing: three cases (epi-hmat08, ld104, ld107; W_c ≤ 0.26)
  could take the s = 1.6 rung or coarser, epi-adG208 sits on the line (0.390 > 0.39), and four
  (dry-lma125, flat, wet-lma08, wet-hmat125; W_c 0.53–0.71) are within one 1.6 step of ε at
  s* 1.19–1.38. None needs refinement. The held-out cases sit closer to ε than the bank's
  nine ordinary cases (median 0.46 against 0.37): the general start carries, with less slack.
- **The one failure** is the near-extinction case: E6's estimate over-reads (read 1.45) and
  misses ×2 or the sign on 9 of 23 quantities over ε/3. It is conservative (C1, C2, C5 hold;
  every estimate ≤ 0.79), but C3 fails on the real runs and in 99.5–100% of stress draws.
  Its check run is far more accurate than the a09 shrink says: the per-quantity structure
  (e.g. k_s e_c −0.48, e_f −0.05, estimate −0.72) says the check's error is about a tenth of
  the committed run's where s predicts 0.41, so d/(1 − s) overstates. Analysed below.
- **Under stress** E6 passes 79% (coord) / 86% (jit) of case-draws, about the bank's 74% / 87%;
  every failure is C3, never C1. Apart from dry-lma125, wet-hmat125 (74% coord), epi-hmat08
  (87%) and ld104 (89%) lose draws: quantities near ε/3 whose estimate the 2.3× amplified
  noise pushes out of ×2, the bank's dry-family failure mode.
- **References.** Three two-rung references move more than the 0.15ε line on their own
  (flat-al1125 0.18, wet-lma08 0.28, wet-hmat125 0.30), all on leaf quantities (a, a_l1),
  where the reference also carries the committed run's largest error (wet-hmat125: e_c of
  `a` −0.71 of which 0.30 is the extrapolation). Third rungs are in Results 2.
- **Cost.** T 612–1434 (rows model). The four cases that raise J cost a median 998 against
  765 for the four that lower it; flat-al1125 (dry-flat's dense season-free stand, as the
  bank's dry-flat 1683) is the only one outside ×0.6–1.6 of the bank's median.
