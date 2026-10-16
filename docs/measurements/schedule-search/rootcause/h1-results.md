# H1 result: a coarser companion in place of the finer check

The test of H1 in `synthesis.md`, run as registered. The predictions are unchanged there.
Scripts are in this directory: `h1_mkcoarse.R` (schedules), `h1_run.sh` (runs),
`h1_score.R` (scoring) and `h1_ladder.R` (the three runs as a ladder), plus
`h1_mkx12.R` (one diagnostic). Run outputs and logs are in
`scratchpad/deep/rootcause/h1/` (`runs/`, `sched/`, `logs/`, `*.log`, `h1_score_*.rds`).
All numbers are measured unless marked [i].

## What was run

- **Schedule.** a09 builds its check from the committed spacing function `h` as
  `build_graded(p, h/R)`, R = 1.6 (BG = 90). The companion uses the same call the other
  way, `build_graded(p, R·h)`. The builder also caps every interval at its range
  (`cap_of`: b1/12 in the founders, 100 d before b = 20, 280 d after). The check never
  reaches that cap; the coarse direction would. So the cap was scaled by R as well, which
  makes every interval R × the committed one. Late edges (b > 25) are then left out as in
  `a09_late`, and P's `inset_rule` is applied with d = 12 × 1.6 = 19.2 d.
  - Guards: the same code reproduces a09's c and f schedules exactly (max diff < 1e-9),
    and `inset_rule(a09 c, 12)` reproduces the committed `insc_*` exactly.
  - With the cap left at the committed range, the build would keep 7–29 more nodes per
    case (`n_coarse_capped` in `h1_mkcoarse.log`).
- **Runs.** These are the E6 committed runs' settings with only `TIMES` changed:
  `adj_run_nk.R` on `adjmap/libS`, `KNOTS=0`, TOL 1e-4, the `one_nk.sh` environment, and
  each case's weight, seed and trait move as in `loc/jobs_insk.txt`. There were ten runs,
  four at a time, and all completed. `score_pair` on the ins75 pairs reproduces E6's
  table exactly (T 9287).
- **Scoring.** est = (Q_x − Q_c)/(1/s_c − 1), with s_c = proxy(c)/proxy(x) from
  `alg$proxy_err` on the lib19 pilot. Errors are measured against the lib19 references,
  in ε.
  - Decision: when every |est| < ε, the committed run is the answer. Otherwise the finer
    run follows, and the case is decided and scored as E6's pair. Its T then pays for all
    three runs.
  - T counts the committed run, the companion and two uses. It is computed both by the
    rows model (`run_cost`) and by CPU.

## Node counts

| case | committed | coarse companion | ratio | check (E6) | s_c | s_f (E6) |
|---|---|---|---|---|---|---|
| episodic | 135 | 101 | 0.75 | 204 | 0.48 | 0.35 |
| dry | 149 | 110 | 0.74 | 219 | 0.47 | 0.44 |
| long-wet | 157 | 117 | 0.75 | 234 | 0.44 | 0.41 |
| long drought | 155 | 118 | 0.76 | 227 | 0.49 | 0.44 |
| episodic-lma | 120 | 85 | 0.71 | 182 | 0.42 | 0.43 |
| dry-flat | 191 | 162 | 0.85 | 258 | 0.41 | 0.43 |
| ld-102 | 143 | 107 | 0.75 | 219 | 0.47 | 0.38 |
| ld-105 | 146 | 107 | 0.73 | 211 | 0.43 | 0.43 |
| dry-p50 | 153 | 113 | 0.74 | 222 | 0.47 | 0.44 |
| wet-adG2 | 158 | 118 | 0.75 | 235 | 0.44 | 0.42 |
| all ten | 1507 | 1138 | **0.755** | 2211 (1.47) | | |

The node count does not fall to 1/1.6 = 0.63. Edges stay nodes, one per edge (now inset),
whatever the spacing. They are most of the nodes, as the check's 1.47 rather than 1.6
shows from the other side.

## Per case

C1–C5 are for the companion's estimate against the committed run's true error. "Pass" is
the decision's outcome. Reads are the median est/err over |err| > 0.2.

| case | worst err | C1 C2 C3 C5 | C3 | pass | read (E6) | corr (E6) | rows x/c | T rows (E6) | T CPU (E6) |
|---|---|---|---|---|---|---|---|---|---|
| episodic | 0.30 | ✓ ✓ ✓ ✓ | 1/2 (a_l1 2.6) | yes | 0.80 (1.09) | 0.69 (0.99) | 0.71 | 504 (614) | 634 (759) |
| dry | 0.35 | ✓ ✓ **✗** ✓ | **0/2** (a, TF24_cost_scale) | **no** | **0.10** (1.06) | **0.01** (0.84) | 0.74 | 702 (832) | 860 (1014) |
| long-wet | 0.36 | ✓ ✓ ✓ ✓ | 1/1 | yes | 0.95 (0.97) | 0.88 (0.98) | 0.75 | 827 (990) | 998 (1198) |
| long drought | 0.37 | ✓ ✓ ✓ ✓ | 1/1 | yes | 0.82 (0.88) | 0.83 (0.96) | 0.76 | 818 (964) | 1067 (1243) |
| episodic-lma | 1.28 | ✗ ✓ ✓ ✗ | 29/30 | yes, after the finer run | 0.99 (1.18) | 1.00 (1.00) | 0.70 | 712 (634) | 892 (790) |
| dry-flat | 0.58 | ✓ ✓ ✓ ✓ | 4/5 (root_P50 0.48) | yes | 0.94 (0.83) | 0.95 (0.89) | 0.82 | 1467 (1683) | 1886 (2218) |
| ld-102 | 0.41 | ✓ ✓ ✓ ✓ | 1/1 | yes | 1.18 (1.00) | 0.98 (0.99) | 0.74 | 716 (857) | 894 (1065) |
| ld-105 | 0.32 | ✓ ✓ ✓ ✓ | 2/2 | yes | 1.17 (0.96) | 0.98 (0.98) | 0.74 | 692 (821) | 855 (1024) |
| dry-p50 | 0.35 | ✓ ✓ **✗** ✓ | **0/2** (a, TF24_cost_scale) | **no** | **0.37** (1.15) | **0.34** (0.94) | 0.73 | 721 (854) | 842 (1017) |
| wet-adG2 | 0.44 | ✓ ✓ ✓ ✓ | 3/4 (a_l1: err −0.09, est −0.39) | yes | 1.27 (0.89) | 0.95 (0.99) | 0.76 | 876 (1038) | 1066 (1220) |
| **all ten** | | | | **8/10** (E6 10/10) | | | **0.754** | **8035** (9287, −13.5%) | **9995** (11548, −13.4%) |

- **episodic-lma.** The committed run's error is over ε (1.28). The companion flags it
  (worst estimate 1.24, C5 trips) and reads it well (C3 29/30), so the finer run follows,
  as E6 also committed fine. Paying for all three runs there costs +12% on that case.
- **CPU.** The companion's CPU is 0.834 of the committed run's (per case 0.79–0.86),
  against 0.754 in rows.
  - The steps barely fall: for example, dry has 4382 steps against 4543, and ld-102 4656
    against 4778. So the per-step cost does not shrink with the node count.
  - The companions ran four at a time. E6's runs ran about two at a time, so part of the
    gap may be contention [i].

## Reads by quantity class

Medians of est/err over every case's quantities with |err| > 0.2, with the 10–90% range in
brackets:

| class | n | H1 companion | E6 finer check |
|---|---|---|---|
| all | 96 | 0.96 [0.22, 1.20] | 1.09 [0.85, 1.24] |
| leaf | 43 | 0.94 [0.11, 1.20] | 1.02 [0.85, 1.16] |
| hydraulic | 15 | 1.06 [0.56, 1.63] | 1.07 [0.59, 1.27] |
| ln J | 2 | 1.10 [1.05, 1.15] | 1.06 [0.93, 1.18] |
| other | 36 | 0.99 [0.50, 1.07] | 1.17 [0.99, 1.26] |

The median is fine. The tails are what fail: the leaf class's 10th percentile is 0.11,
against E6's 0.85. Hydraulic quantities, one at a time (H1 / E6):

| case | quantity | H1 | E6 |
|---|---|---|---|
| episodic | a_l1 | 2.57 | 1.20 |
| episodic | root_P50 | 1.38 | 1.25 |
| dry | a_l1 | 0.50 | −0.05 |
| dry | stem_c | 0.95 | 0.87 |
| dry | root_P50 | 0.65 | 1.70 |
| dry-flat | root_P50 | 0.48 | 1.17 |
| ld-102 | root_P50 | 0.77 | 0.82 |
| wet-adG2 | storage_relaxation_offset | 1.80 | 1.17 |
| episodic-lma (4) | | 1.06–1.15 | 0.89–1.27 |

The remaining hydraulic reads lie in 0.86–1.14.

## The predictions scored

| Prediction | P | Result |
|---|---|---|
| C1–C5 pass on at least 9 of 10 cases | 55% | **Fails: 8/10.** dry and dry-p50 fail C3, 0/2 each |
| Median read 0.8–1.25 | 60% | **Holds** as a median: pooled 0.96, and the median of case reads 0.95. Per-case reads run 0.10–1.27, and two cases fall outside 0.8–1.25 (dry 0.10, dry-p50 0.37) |
| Companion's measured cost ≤ 0.7 of the committed run | 75% | **Fails:** rows 0.754 (0.70–0.82), CPU 0.834 (0.79–0.86) |
| T on all ten at least 15% below 9287 (rows model) | 60% | **Fails:** 8035, −13.5% (CPU −13.4%). This T includes the two failing cases; it does not buy the 10/10 E6 has |
| *Refuted if* hydraulic reads fall under 0.5 or above 2 | | **Not met as stated, borderline.** The pooled hydraulic read is 1.06 [0.56, 1.63]. Two of 15 single reads lie outside the band (episodic a_l1 2.57, dry-flat root_P50 0.48), and neither costs its case a pass. The failures are elsewhere: on leaf and other quantities, by a mode the registration did not name (below) |

The r = 1.3 fallback was not run, because its trigger was not met. By the same build it
would keep 0.84 of the committed nodes (1261 of 1507) [m, schedule only]. So it would save
less still: by the rows arithmetic above, T would fall about 8% [i].

## Why dry and dry-p50 fail: the closing-edge component is not order 2 in the inset

`h1_ladder.R` treats coarse (x), committed (c) and check (f) as a ladder: d1 = x − c and
d2 = c − f. On the proxy's law, d1/d2 = (1/s_c − 1)/(1 − s_f).

- **Where the law holds.** On long-wet, long drought, episodic-lma, ld-102, ld-105 and
  wet-adG2, measured/law is 0.82–1.51 and cos(d1, d2) is 0.89–1.00.
- **Where it breaks.**
  - dry: measured/law 0.19, cos 0.28 (leaf 0.03, cos 0.09).
  - dry-p50: measured/law 0.13, cos 0.20.
- **The error along M (the closing-edge direction, `common.R`'s `M_unit`), x / c / f.**
  - dry: +0.29 / −0.30 / −0.39. The 19.2-d inset overshoots, and the closing-edge bias
    changes sign. That puts a +0.59 move along M into d1, and the move is not the
    committed run's error. M loads on a, curv_fact_elec_trans and k_I, so it cancels the
    leaf quantities' move (a: x −0.41, c −0.35, f −0.14). The companion reads their
    error at 0.0–0.2.
  - dry-p50: −0.30 / −0.42 / −0.24, a move along M of only +0.12. Here the leaf error
    itself grows too little from c to x: a goes x −0.51, c −0.35, f −0.12, so d1 is
    −0.16 where the law wants −0.45 (leaf measured/law 0.30, cos 0.81). The reads are
    about 0.4 on a, curv_fact_elec_trans and k_I. TF24_cost_scale changes sign from c to x
    (dry-p50: x −0.17, c +0.23; dry: x −0.14, c +0.28), so it is a miss
    on both cases.
- **Diagnostic (4 runs, `h1_mkx12.R`, TAG=insx12).** The same coarse spacing with the
  committed run's 12-d inset left unscaled. This is not a candidate rule (P showed a
  shared strip misreads); it separates the inset from the spacing. It fails too, and the
  other way along M:
  - along M, x is −0.45 (dry), −1.15 (dry-p50) and −1.24 (dry-flat), against c's −0.30,
    −0.42 and −0.10;
  - dry reads 0.31, and dry-flat fails C3 5/7 (root_P50 read −0.04);
  - dry-p50 passes, at a read of 0.77.
  - So neither inset distance makes the coarse run's closing-edge error a square-law
    continuation of the committed run's. On dry-type records the bias depends on the
    inset distance and the spell's shape, with a zero crossing between 12 and 19.2 d at
    coarse spacing [i].
- **Why the finer check is not hurt as much.** E6's check goes from 12 d to 7.5 d, and its
  moves along M are not clean either: dry −0.30 → −0.39 and dry-flat −0.10 → −0.34, both
  the wrong way. They are small beside the founders' move that the check reads, so E6
  still passes. On the coarse side, the moves along M reach 0.6 on dry (19.2 d) and 0.7–1.1
  on dry-p50 and dry-flat (12 d), as large as the whole committed error.

## Verdict

**H1 does not hold: the coarser companion cannot replace the finer check as specified.**
- It passes 8 of 10 cases against E6's 10. Its median read is right (0.96), but on dry and
  dry-p50 it reads the committed error at 0.10 and 0.37, with correlation 0.01 and 0.34.
- The cause is not the pre-asymptotic hydraulic mode that the registration guarded
  against; the hydraulic reads stay at 1.06 pooled. The cause is on the dry-type records.
  - The inset's closing-edge bias is not a smooth power of the spacing on the coarse
    side: at 19.2 d it changes sign on dry, and at 12 d it overshoots the other way.
  - On dry-p50 the leaf error grows at 0.3 of the square law from the committed spacing
    to the coarse one.
  - The coarse run is therefore outside the asymptotic range on exactly the records
    where the committed error is mostly the closing edges'.
- The saving is also smaller than expected. Edges keep the companion at 0.75 of the
  committed nodes (not 0.6), and its CPU at 0.83 of the committed run (steps barely fall).
  T drops only 13.5% (rows) or 13.4% (CPU), even though the two failing cases are
  counted.

A companion of this kind would need an edge treatment whose bias scales with the spacing
on both sides, or the closing-edge strip excluded from the Richardson pair. Until then the
finer check stays.
