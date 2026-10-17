# E6+ and the schedule loop, built and run on the bank and the held-out cases

Subject: E6's committed layout with U's edge nodes before b = 10 (E6+), as a one-scale family;
its ladders on the ten bank cases and the eight held-out cases; and the schedule loop built as
an R driver (`harness/schedule/loop.R`) and run for real on all eighteen. Every prediction is
written here, with a probability, before the run or analysis it concerns. Scripts are in this
directory; outputs in `scratchpad/deep/rootcause/loop/` (`runs/`, `sched/`, `logs/`, `*.rds`).
**[m]** measured, **[i]** inferred.

## Summary (written last)

(pending)

## Setup

- **E6+** (`lib.R` `ep_sched(cs, s)`): a09's graded build at s·h with the builder's range cap
  scaled by s, late edges (b > 25) left out, E6's 12-d inset on every edge before 25 (never
  scaled), plus a node at every closing edge before 10 and at every opening edge before 10
  whose gap before and spell after are both at least 2 d (U's rule). E6's c − 12 d and
  o + 12 d inset nodes stay. Only the background spacing scales with s.
- **Guard** (`mk_sched.R`) [m]: with edge nodes off, `ep_sched(cs, 1)` is `identical()` to E6's
  committed schedule on all eighteen cases (the bank's `insc_`, the held-out round's `c_`), and
  `ep_sched(cs, 1.6)` to the H1 round's `insx12_` on the four cases saved.
- Node counts, s = 1.6 / 1 / 1/1.6, against E6 committed (schedule only, seen before the
  predictions below) [m]:

| case | E6+ | E6 c | edges before 10 (nodes added) |
|---|---|---|---|
| episodic | 118 / 151 / 214 | 135 | 17 (16) |
| dry | 145 / 181 / 231 | 149 | 33 (32) |
| long-wet | 155 / 190 / 240 | 157 | 37 (33) |
| long-drought | 162 / 192 / 247 | 155 | 39 (37) |
| episodic-lma | 101 / 135 / 192 | 120 | 15 (15) |
| dry-flat | 222 / 244 / 283 | 191 | 57 (53) |
| ld-102 | 149 / 180 / 234 | 143 | 38 (37) |
| ld-105 | 138 / 174 / 223 | 146 | 28 (28) |
| dry-p50 | 150 / 185 / 236 | 153 | 33 (32) |
| wet-adG2 | 166 / 197 / 247 | 158 | 41 (39) |
| dry-lma125 | 130 / 167 / 215 | 139 | 31 (28) |
| flat-al1125 | 190 / 215 / 253 | 173 | 45 (42) |
| wet-lma08 | 184 / 215 / 268 | 169 | 47 (46) |
| wet-hmat125 | 155 / 188 / 239 | 155 | 37 (33) |
| epi-hmat08 | 123 / 159 / 226 | 143 | 17 (16) |
| epi-adG208 | 115 / 148 / 213 | 134 | 15 (14) |
| ld104-p50125 | 134 / 167 / 219 | 142 | 26 (25) |
| ld107-adG2125 | 127 / 159 / 209 | 135 | 24 (24) |

  The fixed nodes (insets, edges) are a large share: E6+ at s = 1.6 has as many nodes as E6
  committed on most cases, more on dry-flat, flat-al1125, wet-lma08, wet-adG2 and long-drought.
- **Runs** (`run.sh`): `dwr/adj_run_dwr.R` in MODE=map on a scratch build of libS's exact
  source (`summing/build/src0`, `git archive 07f7c256`) plus `dwr/node_drop.patch`, odelia and
  phylloptim from `summing/build/lib0` (= libS), at the E6 committed setting (no knot stops,
  TOL 1e-4, ATOL 1e-4, WEIGHT_SOIL 10, WEIGHT_MAX 100, HMAX 15, SHARE 0.1, SPLIT 1, the record's
  weight). The sweep also returns the node-drop map for the dwr round's virtual coarsening
  (`lib.R` `drop_set`: every other node between kept ones; edge nodes and their neighbours
  kept), so every run carries its own ln J error estimate (`map_lnJ`: Σ over regions of
  (own + field)/3).
- **Truth**: the bank's lib19-class references (`proxies/lad.rds`, as every earlier round);
  the held-out round's u215 → u429 references (`heldout/score857.rds`: flat-al1125 on its
  three-rung u429 → u857 reference). 47 quantities (ln J and 46 resident elasticities), errors
  in each quantity's ε (`docs/measurements/eps-spread.md`).
- **E6 as built**: the bank's `val_insk_c` / `val_ins75_f` (T 9287 on ten, rows model), the
  held-out round's `e6_c` / `e6_f` (T 7191 on eight).

## Pre-registration G (before the build's guard run)

| # | prediction | P |
|---|---|---|
| G1 | The scratch build in MODE=map, unpinned, on E6's committed dry schedule reproduces `val_insk_c_dry`'s J and all 50 trait gradients `identical()` | 85% |
| G2 | Its map gives dry's committed ln J error within 0.05ε of the dwr round's map figure on the same schedule (Σ regions, dwr `score_c_dry`: −0.123ε) | 80% |

## Pre-registration A: the E6+ ladders (before any E6+ run)

Scoring (`score_lad.R`): d1 = Q(1.6) − Q(1), d2 = Q(1) − Q(1/1.6), in ε. Pooled order
log(‖d1‖/‖d2‖)/log 1.6 in the spacing ratio (the loop's form); per-quantity order median over
quantities with |d2| > 0.05; cos(d1, d2). The coarse pair estimates the s = 1 rung's error as
d1/(1.6² − 1), the fine pair as d2·1.6²/(1.6² − 1); read = median est/err over |err| > 0.2;
C1–C5 by `crit` (round4/F). Stress (1000 draws per case, coord: miss N(0, 0.025²) per
quantity shared by the case's runs + N(0, 0.04²) per run; jit: N(0, 0.02²) + 0.09·z along M
per run): protocol "commit s = 1 when every |est| < 1, else commit s = 1/1.6 with the fine
pair's estimate of it", for each pair. Rows against E6 committed; rows at E6 committed's
worst error (log worst error against log rows along E6+'s rungs). What neither pair sees:
rms(err − est) per pair and the part of the s = 1 error outside span(d1, d2). The per-case
optimum s*: where log worst error, interpolated in log s along the rungs, meets the target
0.85 (extended past the end rungs at the end segment's slope).

Priors [m]: U (bank) pooled order (a09 shrink) median 1.69 [1.02, 2.91], coarse pair 9/10,
fine 10/10, U10 rows 1.11× E6 committed, worse than E6 per row; E6's coarse pair at 19.2-d
inset misreads (H1); E6 committed W 0.30–0.58 bank (1.28 episodic-lma), 0.21–0.71 held-out.

| # | prediction | P |
|---|---|---|
| A1 | Median pooled order (spacing ratio) over the 18 cases in [1.5, 2.5] | 55% |
| A2 | Coarse pair passes C1–C5 on the real runs on ≥ 8 of 10 bank and ≥ 6 of 8 held-out (a case whose s = 1 error is over ε counts as passing when the pair flags it, some \|est\| ≥ 1) | 50% |
| A3 | Fine pair passes on ≥ 9 of 10 bank and ≥ 7 of 8 held-out (same counting) | 55% |
| A4 | E6+'s s = 1 worst error ≤ E6 committed's on ≥ 11 of 18 | 50% |
| A5 | Rows, E6+ s = 1 over E6 committed, summed over the 18, in [1.10, 1.25] | 65% |
| A6 | At E6 committed's worst error E6+ needs ≤ 1.10× E6's rows on at least half the cases where a bracket exists | 40% |
| A7 | Coarse-pair protocol passes ≥ 90% of case-draws (coord) over the 18 | 50% |
| A8 | dry-lma125's coarse pair misreads (C3 fails or read outside [0.5, 2]) | 60% |
| A9 | cos(d1, d2) ≥ 0.85 on ≥ 14 of 18 | 60% |
| A10 | Outside span(d1, d2) rms ≤ 0.06 on ≥ 14 of 18 | 50% |
| A11 | E6+ s = 1.6 rows over E6 committed rows: median over the 18 in [0.85, 1.05] | 60% |
| A12 | No run throws or refuses | 90% |

## The loop as built (`harness/schedule/loop.R`, registered before any loop run)

`schedule_loop(run, eps, sel_scale, reserve)`; `run(s)` returns the gradient run of E6+ at
scale s (`loop_run.R` here: builds `ep_sched(cs, s)` and its drop set, runs it through
`run.sh` unless a run of that exact schedule is on disk, and reads q, rows and the map).
1. Run s = 1. Predicted worst error = sel_scale · S_el (S_el = rms(elasticity/ε)); sel_scale is
   P5's constant (W_c / S_el on E6's bank ladder, geometric mean, leave-one-case-out on the
   bank, all ten for held-out cases: 0.0039–0.0043). Under the target (1 − reserve), the
   second run is at s = 1.6, otherwise at 1/1.6. (With either, the finer member answers when
   the coarse one cannot; coarsening is the cheaper way to estimate the start's own error, so
   only a predicted failure of the start sends the loop finer.)
2. The pair's estimate, order 2 in the spacing ratio R: finer member (Q_coarse − Q_fine)/(R² − 1),
   coarser member R² times that.
3. The answer is the coarsest member with every |est| < target, amplified jitter (0.09·R²/(R² − 1)
   coarse, 0.09/(R² − 1) fine) under 1/3, and, the **non-asymptotic flag**, its own map's ln J
   error within 3 sd of the pair's ln J estimate (sd² = 0.02² for the map + 2·(0.02·amp)² for
   the pair).
4. Otherwise a third run: at the spacing where the finest pair's constant gives 0.9·target
   (clipped to 1.25–2× finer than the finest run), or 1.6× finer than the finest if a map
   disagreed; it pairs with the finest run so far; back to 3. At most 4 runs; at the cap the
   finest run answers, marked.
- Scored: C1–C5 on the final (err against the truth, est = the loop's estimate); T = Σ cost(runs)
  + 2·cost(final), rows model; stress (1000 draws per case, both noise models above, the map
  perturbed by N(0, 0.02²) per run): the whole loop re-decided on perturbed values, with any
  spacing not run read from the stored runs (linear in s² between the two nearest, end
  segments extended, plus jitter scaled as b_loop's meas mode); E6 as built under the same
  draws (`heldout/score.R`'s rule). Resident reserve 0.15; 0 and 0.3 for sensitivity.

## Pre-registration L (before any loop run; written with A)

| # | prediction | P |
|---|---|---|
| L1 | Bank: the loop's real T in [0.85, 1.00] × E6's 9287 | 50% |
| L1′ | Held-out: the loop's real T ≤ E6's 7191 | 50% |
| L2 | The loop passes C1–C5 on ≥ 9 of 10 bank and ≥ 7 of 8 held-out | 55% |
| L3 | Under coord stress the loop passes more case-draws than E6 as built, on both sets | 70% |
| L4 | Gradient runs per case: mean ≤ 2.3, max ≤ 3 | 60% |
| L5 | The final spacing is coarser than s = 1 on ≥ 3 of 18 | 45% |
| L6 | The final spacing is finer than s = 1 on ≤ 3 of 18 | 70% |
| L7 | The final s is within a factor 1.6 of the ladder's s* on ≥ 14 of 18 | 60% |
| F1 | The map flag fires (some member fails on it alone) on ≤ 3 of 18 cases | 55% |
| F2 | rms over the 18 s = 1 runs of (map − true ln J error) ≤ 0.1ε | 50% |
| F3 | Where the flag fires, the pair's ln J estimate is further from the true ln J error than the map is | 55% |
| R1 | Reserve 0 against 0.15: bank T falls by ≥ 3% | 40% |
| R2 | Reserve 0.3 against 0.15: bank T rises by ≥ 5% | 45% |

## Results, in run order

### G. The scratch build (`guard.R`) [m]

`loop/build/lib` = `summing/build/src0/plant` (libS's exact source) + `dwr/node_drop.patch`
(applies cleanly; the patched tree equals the dwr round's `dwr/build/src` file for file), built
08:32–08:37 UTC with R's default `-O2`, odelia and phylloptim linked from `summing/build/lib0`.
On E6's committed dry schedule, unpinned, MODE=map with the dwr drop set (39 drops: F 8, I 25,
L 6, as the dwr round's c):
- J 1.19606594214158, 4543 steps, step times, the 50 trait gradients and the elasticities all
  `identical()` to `val_insk_c_dry`. **G1 holds.**
- The map: F +0.108, I −0.221, L −0.009, all −0.1234ε, equal to the dwr round's figure to four
  places. **G2 holds.**
- Cost: forward 62 s, plain sweep 150 s, map sweep 166 s (×1.105 of the plain sweep, +7.5% of
  the whole gradient run).
- First E6+ rows seen while the ladders ran (before any scoring): dry s = 1 has 508643 rows,
  1.31× E6 committed's 389409 (the added nodes are early, so they live through most steps).

## Added by the coordinator mid-round: where U falls behind E6, and Route B

The coordinator's point: U fell short of E6 on accuracy per row because of placement, not
because iterating is bad; a loop with good diagnostics should reach an E6-like layout from a
cheap start. Two parts: (X) find the U–E6 gap by region from saved runs, before building
anything; (B) Route B, a map-guided refinement from a coarse start, run on the same 18 cases.

### Pre-registration X (before `gap.R` is run; the map replays are pinned to the saved runs)

Method (`gap.R`): on dry, dry-flat and long-wet, E6 committed (`val_insk_c`), U10 (`u/runs/h5_U10`)
and E6+ at s = 1 by region: founders F (b < b1), interiors I1 (b1–10), I2 (10–17), I3 (17–25),
opening strips (o and o + 12 d nodes), closing strips (c − 12 d and c nodes), short-spell centres,
late (≥ 25). Per region: nodes; rows (each node's accepted steps alive); the a09 proxy's share
(w·h³ of the intervals whose midpoint lies there); the node-drop map's ln J error (pinned map
replays on the scratch build: U10 on all three, E6 committed on dry-flat and long-wet; dry's is the
guard run), with the strips' share taken as the measured ln J error less the map's total (strips
plus jitter). Then spell by spell before 25: background nodes (outside both 12-d strips).
Already seen before writing (the E6+ s = 1 rows and error on dry and long-wet, above): E6+ is 1.31×
E6's rows on both, worst 0.44 against 0.35 on dry and 0.36 against 0.36 on long-wet.

| # | prediction | P |
|---|---|---|
| X1 | On all three, U10's strip nodes (both kinds) carry more extra rows over E6 than U10's total extra: its background rows are fewer than E6's | 75% |
| X2 | U10's background before 25 has fewer nodes than E6's on all three, most of the deficit in spells under 150 d | 65% |
| X3 | The map's interior ln J error (I1 + I2 + I3) is larger in magnitude on U10 than on E6 on ≥ 2 of 3 | 60% |
| X4 | dry-flat: E6+ s = 1 worst error above E6 committed's | 60% |
| X5 | The strips' remainder (measured ln J error − map total) is under 0.1ε in magnitude on every layout × case with a map | 50% |

### Route B as built (`harness/schedule/loop.R` `allocation_loop`; registered before any Route B run)

Seen before registering (the schedule half of `gap.R`, no map columns yet): strip nodes
(edges and the 12-d insets) carry most of every layout's rows (E6 dry 187k of 389k; dry-flat 560k
of 797k); U10's background is sparser than E6's by one node in 8 of 48 spells on dry, 6 of 93 on
dry-flat and 10 of 51 on long-wet, mostly in spells over 150 d; on dry E6+ (E6's background plus
edge nodes) has E6's map by region to the third place but a worse hydraulic error (along M −0.54
against −0.30). Route B is therefore built on U's strips (the cheaper honest set: edge nodes and
c − 12 d before 10, E6's inset after), with its background placed per case:

- **Layout** (`lib.R` `rb_sched(cs, sv)`): `h5_sched(cs, s(b), "node1", tcut = 10)` with s(b) one
  scale per region, F (b < b1), I1 (b1–10), I2 (10–17), I3 (17–25), L (≥ 25), applied to a09's
  spacing and range cap; strips fixed. `h5/lib.R` now accepts s as a function of b (numeric s
  unchanged). Guard [m]: with one scale it reproduces U16 / U10 / U06 `identical()` on all ten
  bank cases.
- **Run 1**: every region at 1.6 (U16).
- **Each run's map** gives region constants k_g = |map_g| / s_g² (floor 0.005ε), so a layout's
  error proxy is P = Σ k_g s_g².
- **Next layout**: minimise Σ R_g s_g / s_g′ (R_g the region's background rows on the run) subject
  to P = P_next: equal marginal error per row, s_g ∝ (R_g s_g / k_g)^(1/3), clipped to [0.3, 1.6],
  rounded to 0.001. P_next after run 1 = P_1 × clip(0.9·target / (P5's predicted worst error at
  1.6), 1/4, 1/1.6²); after a pair, the P where the pair's constant (d / (P_a − P_b) per quantity)
  meets 0.9·target, clipped to [P_b/4, P_b/1.5]; P_b/1.6² when a map disagreed.
- **Estimate** (k from the finer member's map): finer member d·P_b/(P_a − P_b), coarser
  d·P_a/(P_a − P_b). Answer, noise check and map flag as in the main loop (route A). At most 5
  runs. Reserve 0.15.
- Scored as route A: C1–C5 on the final, T = Σ runs + 2·final (rows model), runs, and per
  iteration the true worst error against E6 committed's, so the iteration and rows at which
  Route B first matches E6's committed accuracy are read off; the final per-region node counts
  against E6's (`node_class`). No stress replay for Route B (its layouts are not one-parameter,
  so unrun layouts cannot be interpolated).

### Pre-registration B

| # | prediction | P |
|---|---|---|
| B0 | The bank's run 1 on the scratch build (unpinned) reproduces the saved `h5_U16` J `identical()` | 90% |
| B1 | Route B's final rows ≤ E6 committed's on ≥ 9 of 18 | 40% |
| B2 | Bank: Route B's T ≤ E6's 9287 | 45% |
| B2′ | Route B's T ≤ route A's T on each set | 55% |
| B3 | Route B passes C1–C5 on ≥ 15 of 18 | 55% |
| B4 | Runs per case: mean ≤ 2.6, max ≤ 4 | 55% |
| B5 | Some iterate is at or under E6 committed's worst error within 3 runs on ≥ 9 of 18 | 45% |
| B6 | The final founders' scale is finer than the I1 scale (s_F < s_I1) on ≥ 12 of 18 | 55% |
| B7 | Final background nodes within ±30% of E6's in both F and I1 on ≥ 12 of 18 | 40% |

