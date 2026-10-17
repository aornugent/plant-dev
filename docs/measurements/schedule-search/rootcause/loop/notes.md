# E6+ and the schedule loop, built and run on the bank and the held-out cases

Subject: E6's committed layout with U's edge nodes before b = 10 (E6+), as a one-scale family;
its ladders on the ten bank cases and the eight held-out cases; and the schedule loop built as
an R driver (`harness/schedule/loop.R`) and run for real on all eighteen. Every prediction is
written here, with a probability, before the run or analysis it concerns. Scripts are in this
directory; outputs in `scratchpad/deep/rootcause/loop/` (`runs/`, `sched/`, `logs/`, `*.rds`).
**[m]** measured, **[i]** inferred.

## Summary (written last)

**E6+** (E6's committed layout plus U's edge nodes before b = 10, background scaled by s, every
inset and edge node fixed; guard: with edges off it is E6's committed schedule exactly) [m]:
- **Dearer and no more accurate.** s = 1 costs 1.32× (bank) / 1.29× (held-out) E6 committed's
  rows; its worst error is at or under E6's on 3 of 18; at E6's worst error it needs 1.19–1.48×
  E6's rows (median 1.37 / 1.30; U needed 1.15). Its s = 1.6 rung costs 1.06× E6 committed.
- **Pairs.** Fine pair 10/10 bank, 7/8 held-out, stress 0.91; coarse pair 7/10 and 7/8, stress 0.74
  / 0.88. The coarse pair still misreads on the dry records (dry 0.18, dry-p50 0.21, dry-flat C3,
  dry-lma125 1.74): the fixed 12-d inset after b = 10 holds an error the background does not move
  (order 0.8–1.0, cos 0.5 there). Order median 1.79 [0.79, 2.90]; outside span(d1, d2) ≤ 0.054.

**Route A, the E6+ loop, run for real** (`harness/schedule/loop.R` `schedule_loop`: start s = 1;
P5 picks the second run at 1.6 (slack) or 1/1.6; order-2 pair; the coarsest member under
0.85 with jitter and the map check; otherwise a run where the pair's constant meets 0.9·target):
bank T 11178 against E6's 9287 (×1.20), held-out 8009 against 7191 (×1.11); passes 8/10 + 8/8
(E6 10/10 + 7/8); coord stress 0.776 / 0.974 (E6 0.745 / 0.771); 2.06 runs per case, max 3;
coarsens on 3, refines on 2, stops at the start on 13; final within ×1.6 of the ladder's optimum
on 16 of 18. Fails C3 on dry and dry-p50 (the coarse pair's misread). Reserve: 0 saves 1.0% of
T, 0.3 costs 2.7%; pass counts do not change.

**The U–E6 gap** (coordinator's addition; dry, dry-flat, long-wet, by region with pinned map
replays) [m]: strip nodes carry 48–70% of every layout's rows. U spends +62k to +106k rows on
edge nodes and is 15–24k rows sparser in background, because `h5_sched` cuts the 12-d strips out of
each spell before rounding the count up (E6 counts the whole spell, then drops only strip nodes):
one node fewer in about one spell in six, mostly long spells; the range cap and merging are the
same. Accuracy goes two ways: the edge nodes remove E6's closing-inset cancellation (E6+, which has
E6's background, loses along M on dry: −0.54 against −0.30), and U's sparser background raises the
interiors' map error on all three (dry-flat I2 −0.22 against −0.13).

**Route B** (coordinator's addition: U's strips, one background scale per region F / I1 / I2 / I3 /
late, start U16, each run's node-drop map sets the next allocation by equal marginal error per row,
magnitude from successive runs; `allocation_loop`) [m]: T 9475 bank (×1.02 E6), 6598 held-out
(×0.92), 16072 over the 18 (×0.975 E6, ×0.84 route A); 2.1 runs; but it passes only 13 of 18 (C2/C3 on
dry, dry-p50, ld-102, dry-lma125; C3 wet-hmat125), its finals reach E6's committed worst error on 5
of 18 at a median 1.10× E6's rows, and its allocation is not E6's (it saves on I1 and I3 and spends
on I2 and late). Cause: the map ranks regions by ln J, and the elasticities' error on the dry records
(a leaf-hydraulic block along M, −0.99 on both of dry's runs) sits where ln J's does not, so the
allocation coarsens it and the pair sees only what moved. The map also misreads its own run at
U16 spacing (rms 0.19ε, dry −0.01 against −0.51), so the start's split is unreliable.

**The non-asymptotic flag** (map's ln J error against the pair's ln J estimate, 3 sd): on s = 1
runs the map reads the true ln J error to 0.03ε, but at 1.6 spacing it misses by up to 0.5ε, so the
flag fires mostly on coarse members where the map, not the pair, is wrong (pair nearer in 7 of 8
route A hits, 9 of 12 Route B hits). It blocked 2 route A answers, both unnecessarily (one extra
fine run on dry-flat), and 3 Route B answers, two rightly (dry run 1, true worst 1.04; episodic-lma
run 2, 1.10).

**Verdict** [i]. Neither loop reaches E6's accuracy per row on these layouts. Route A is honest
except on the dry records but pays 1.31× rows for its edge nodes; Route B is cheap but its ln J
map misplaces the elasticity error and it stops early with an under-read. A map-guided route would
need a per-region elasticity indicator (the dwr round's pinned coarse runs per region) rather than
ln J's, and a start fine enough for the map to read its own run.

**Predictions:** 41 registered, 22 held, 19 refuted (table at the end).

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
scale s (`loop_run.R` here: builds `ep_sched(cs, s)` and its drop set, reads the run of that exact
schedule from disk, and otherwise requests it; `drive.sh` alternates driver passes with `run.sh`
for the requested runs, so cases run in parallel lanes and each loop replays deterministically).
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

### X results: the U–E6 gap by region (`gap.R`, `gap.log`) [m]

The map replays (U10 on all three; E6 committed on dry-flat, long-wet) reproduce their saved runs'
J and 50 gradients `identical()` (checked on U10 dry; all exit 0). Rows are each node's accepted
steps alive; map in ε of ln J; "strips" = measured ln J error − map total.

| case | layout | rows (× E6) | strip nodes / rows | background F + I nodes / rows | map F | map I1 / I2 / I3 | strips | worst (q) | along M |
|---|---|---|---|---|---|---|---|---|---|
| dry | E6 | 389k (1.00) | 74 / 187k | 62 / 190k | +0.108 | −0.125 / −0.079 / −0.018 | −0.024 | 0.35 (a) | −0.30 |
| dry | U10 | 430k (1.10) | 88 / 249k | 55 / 172k | +0.108 | −0.147 / −0.084 / −0.027 | −0.060 | 0.42 (a_l1) | −0.51 |
| dry | E6+ | 509k (1.31) | 106 / 305k | 62 / 192k | +0.108 | −0.125 / −0.079 / −0.018 | −0.060 | 0.44 | −0.54 |
| dry-flat | E6 | 797k (1.00) | 146 / 560k | 42 / 224k | +0.187 | −0.033 / −0.130 / −0.002 | +0.035 | 0.58 (a) | −0.10 |
| dry-flat | U10 | 873k (1.10) | 156 / 666k | 37 / 200k | +0.184 | −0.037 / −0.219 / −0.002 | −0.008 | 0.70 (a) | −0.57 |
| dry-flat | E6+ | 1109k (1.39) | 199 / 870k | 42 / 226k | +0.187 | −0.033 / −0.130 / −0.002 | +0.023 | 0.60 (a) | −0.19 |
| long-wet | E6 | 457k (1.00) | 89 / 242k | 54 / 190k | +0.128 | −0.011 / −0.023 / −0.004 | −0.016 | 0.36 (a) | −0.02 |
| long-wet | U10 | 520k (1.14) | 111 / 337k | 48 / 175k | +0.127 | −0.019 / −0.021 / −0.005 | −0.052 | 0.41 (a) | −0.03 |
| long-wet | E6+ | 598k (1.31) | 122 / 381k | 54 / 192k | +0.128 | −0.011 / −0.023 / −0.004 | −0.027 | 0.36 (a) | −0.01 |

(Short-spell centres and late nodes, 3–21k rows, are left out of the columns.)

- **Where the rows go.** Strip nodes carry 48–70% of E6's rows. U adds one node per closing edge
  and per opening edge before 10 (+14 / +10 / +22 nodes net in the strips), +62k / +106k / +95k
  rows, and its background is 7 / 5 / 6 nodes and 18k / 24k / 15k rows sparser. U's extra cost is
  more than all strips (**X1 holds**).
- **Why U's background is sparser.** `h5_sched` places each spell's background over the stretch
  with the 12-d strips already cut out (before 10: o to c − 12 d; after: o + 12 d to c − 12 d) and
  rounds that shorter stretch's count up; E6's `build_graded` counts ceiling(∫ 1/h) over the whole
  spell and `inset_rule` then drops only the interior nodes that fall inside the strips. Cutting
  12–24 d out of a 150–330 d spell lowers ∫ 1/h by 0.1–0.3 intervals, so the ceiling loses a node in
  8 of 48 spells (dry), 6 of 93 (dry-flat), 10 of 51 (long-wet), mostly spells over 150 d (dry 7 of
  8). The range cap scales identically (s · cap, the same at s = 1) and both builders split at the
  same pilot edges, so neither the cap nor merging differs; the short-spell rule differs slightly
  (E6 2 centres on dry, U 1). **X2 refuted** (fewer on all three, but the deficit is in long spells).
- **Where the accuracy goes.** Two separate losses:
  1. *Edge nodes remove E6's closing-strip cancellation.* E6+ has E6's background (its map by
     region is E6's to three places) and still loses along M on dry (−0.54 against −0.30; worst
     0.44 against 0.35); on dry-flat and long-wet it loses little (−0.19, −0.01). This part is the
     price of strips whose own error is small and does not cancel by tuning.
  2. *U's sparser background.* The map's interior ln J error is larger on U on all three (dry
     0.258 against 0.221; dry-flat 0.259 against 0.166, the I2 era −0.219 against −0.130;
     long-wet 0.046 against 0.039; **X3 holds**). On dry-flat this is most of U's loss along M
     (U −0.57, E6+ −0.19).
  The founders' map is the same in all three layouts (same founders' nodes).
- E6+ worst on dry-flat 0.60 against E6's 0.58 (**X4 holds**, narrowly). The strips' remainder is
  under 0.1ε everywhere (−0.060 to +0.035; **X5 holds**).
- So E6's per-row advantage is (a) 16 fewer edge nodes' worth of rows per case and a tuned
  cancellation at the closing inset, and (b) a background one node denser in about one spell in
  six. Route B keeps U's strips (honest, small own error) and lets each case's map place the
  background, which addresses (b) and part of (a)'s rows, not the cancellation.

### Run order changed (coordinator, 11:15 UTC)

The user found the round slow. From 11:15: three runs at once plus at most one driver (run.sh's
gate at 4 R processes), Route B's remaining passes ahead of E6+'s remaining s = 1/1.6 rungs. The
ladder queue was stopped with 46 of 54 rungs done or running; the eight held-out fine rungs
(dry-lma125, flat-al1125, wet-lma08, wet-hmat125, epi-hmat08, epi-adG208, ld104-p50125,
ld107-adG2125) wait until Route B finishes, and route A (which needs them for its fine-side runs
and the ladder scores) is scored and written after. Nothing was lost in the container restart
reported at 09:08: every queue was still alive and every finished run has its `done 0` line.

### Route B results (`drive.sh B 0.15`, `score_rb.R`, `score_rb.log`, `loopB_0.15.rds`) [m]

38 runs (18 + 18 + 2), all exit 0; three passes of the driver. Run 1 reproduces the saved U16 J
and gradients `identical()` where checked (dry-flat, dry-p50; **B0 holds**). The allocation after
run 1 cut P by 1/1.6² on every case (P5's prediction at 1.6 was over 0.85 everywhere but
ld107-adG2125); it coarsened I1 and I3 (1.07–1.60), refined I2 (0.79–1.29) and L (0.30–1.0), and
set F at 0.92–1.6.

| case | runs | final scales F/I1/I2/I3/L | W final (E6 c) | est max | read | C1–C5 | rows / E6 c | T (E6) | W per iterate |
|---|---|---|---|---|---|---|---|---|---|
| episodic | 2 | 1.60/1.12/0.85/1.08/1.00 | 0.59 (0.30) | 0.58 | 0.66 | pass | 0.96 | 498 (614) | 1.56, 0.59 |
| dry | 2 | 1.27/1.28/0.87/1.39/0.30 | 0.73 (0.35) | 0.31 | −0.18 | **C2 C3** | 1.07 | 772 (832) | 1.04, 0.73 |
| long-wet | 2 | 0.92/1.60/0.98/1.49/0.52 | 0.36 (0.37) | 0.31 | 0.84 | pass | 1.11 | 942 (990) | 0.91, 0.36 |
| long-drought | 2 | 0.94/1.25/0.93/1.39/0.44 | 0.44 (0.37) | 0.36 | 0.90 | pass | 1.15 | 964 (964) | 1.04, 0.44 |
| episodic-lma | 3 | 0.77/1.05/0.54/0.30/0.36 | 0.41 (1.28) | 0.46 | 1.15 | pass | 1.57 | 741 (634) | 2.99, 1.10, 0.41 |
| dry-flat | 3 (answer 2) | 1.04/0.92/0.91/1.60/0.65 | 0.65 (0.58) | 0.59 | 0.88 | pass | 1.11 | 2155 (1683) | 1.74, 0.65, 0.28 |
| ld-102 | 2 | 0.92/1.60/1.11/1.52/0.77 | 0.54 (0.41) | 0.36 | 0.34 | **C2 C3** | 1.11 | 827 (857) | 0.97, 0.54 |
| ld-105 | 2 | 0.93/1.29/0.90/1.31/0.96 | 0.43 (0.32) | 0.39 | 0.70 | pass | 1.08 | 762 (821) | 0.98, 0.43 |
| dry-p50 | 2 | 1.31/1.30/0.86/1.44/0.30 | 0.74 (0.35) | 0.50 | −0.11 | **C2 C3** | 1.07 | 791 (854) | 1.22, 0.74 |
| wet-adG2 | 2 | 0.94/1.60/1.11/1.60/0.51 | 0.52 (0.44) | 0.43 | 0.87 | pass | 1.13 | 1023 (1038) | 1.25, 0.52 |
| dry-lma125 | 2 | 1.16/1.47/0.79/0.77/0.30 | 0.67 (0.71) | 0.38 | −0.16 | **C2 C3** | 1.20 | 685 (682) | 2.24, 0.67 |
| flat-al1125 | 2 | 0.99/1.07/0.97/1.52/0.60 | 0.77 (0.71) | 0.72 | 0.95 | pass | 1.05 | 1338 (1434) | 1.98, 0.77 |
| wet-lma08 | 2 | 0.93/1.60/1.29/1.54/0.46 | 0.49 (0.53) | 0.47 | 0.62 | pass | 1.15 | 1197 (1185) | 1.14, 0.49 |
| wet-hmat125 | 2 | 0.97/1.60/0.93/1.15/0.68 | 0.81 (0.71) | 0.60 | 0.57 | **C3** | 1.11 | 936 (976) | 1.77, 0.81 |
| epi-hmat08 | 2 | 1.60/1.07/0.86/1.60/0.94 | 0.39 (0.21) | 0.36 | 0.93 | pass | 0.93 | 507 (643) | 0.98, 0.39 |
| epi-adG208 | 2 | 1.60/1.11/0.85/1.06/0.99 | 0.61 (0.39) | 0.60 | 0.41 | pass | 0.95 | 485 (612) | 1.62, 0.61 |
| ld104-p50125 | 2 | 0.97/1.24/0.91/1.02/0.30 | 0.35 (0.26) | 0.32 | 0.80 | pass | 1.11 | 790 (848) | 0.90, 0.35 |
| ld107-adG2125 | 2 (answer 1) | 1.60 everywhere (U16) | 0.61 (0.24) | 0.38 | 0.69 | pass | 0.85 | 660 (811) | 0.61, 0.36 |

- **Bank**: T 9475 against E6's 9287 (×1.020); 7 of 10 pass; 2.2 runs (max 3). **Held-out**: T 6598
  against 7191 (×0.917); 6 of 8 pass; 2.0 runs. Over the 18: 13 pass (E6 as built 17).
- **It does not reach E6's accuracy per row.** The final run's rows are 1.08–1.11× E6 committed's
  (median), and its worst error is at or under E6 committed's on 5 of 18 (long-wet, episodic-lma,
  dry-flat at run 3, dry-lma125, wet-lma08), typically 1.1–2× E6's. It stops as soon as its own
  estimate is under 0.85, and that estimate under-reads where it fails.
- **Why it fails on dry, dry-p50, dry-lma125, ld-102.** The worst error is a leaf-and-hydraulic
  block (a_l1 +0.73, a −0.71, curv −0.70, k_I −0.67 on dry) that barely moves from run 1 to run 2:
  along M −0.99 on both runs on dry, −1.31 / −1.25 on dry-p50, −0.90 / −0.81 on dry-lma125. The
  allocation, driven by ln J's map, coarsened I1 (1.28–1.47) and I3, the eras where U's interior
  hydraulic error lives, and refined I2 and L, where ln J's error is; the pair then sees only the
  moved part and reads 0.1–0.4 of the error with the wrong sign on the worst quantity. This is the
  dwr round's warning made real: ln J's signed split by region does not carry the elasticities'
  (median |cos| 0.58 there), and the map ranks regions for ln J only.
- **The map at the coarse start does not read its own ln J error.** On U16 the map's total is off
  the true ln J error by rms 0.19ε over the Route B runs (dry: map −0.01, true −0.51; dry-p50 −0.03
  against −0.52; ld104 +0.01 against −0.31), against 0.03ε on E6+'s s = 1 runs. So the region
  split Route B starts from is itself unreliable at U16 spacing (the dwr round's 7% figure was for
  E6's inset coarse run, whose strips scale). The non-asymptotic flag fired 12 times (10 on run 1);
  the pair's ln J estimate was nearer the true ln J error than the map in 9 of the 12. It blocked
  an answer the other checks accepted 3 times: dry run 1 (true worst 1.04: a right block),
  episodic-lma run 2 (true 1.10: right), dry-flat run 2 (true 0.65: an unneeded third run, after
  which run 2 answered on the new pair).
- **Allocation against E6's.** Final background nodes per region against E6 committed's: founders
  13–24 against 16–24, I1 5–16 against 9–19, I2 8–40 against 14–20, I3 1–40 against 3–15. F and I1
  are both within 30% of E6's on 3 of 18. s_F < s_I1 on 12 of 18. Route B does not land on an
  E6-like allocation: it spends on I2 and late and saves on I1, which is the opposite of where the
  elasticities' error sits on the dry records.

| # | prediction | P | result |
|---|---|---|---|
| B0 | run 1 reproduces h5_U16 identically | 90% | holds (dry-flat, dry-p50 checked) |
| B1 | final rows ≤ E6 c on ≥ 9 of 18 | 40% | refuted (4) |
| B2 | bank T ≤ 9287 | 45% | refuted (9475) |
| B2′ | T ≤ route A's on each set | 55% | scored with route A below |
| B3 | ≥ 15 of 18 pass | 55% | refuted (13) |
| B4 | runs mean ≤ 2.6, max ≤ 4 | 55% | holds (2.11, 3) |
| B5 | an iterate ≤ E6's worst within 3 runs on ≥ 9 of 18 | 45% | refuted (5) |
| B6 | s_F < s_I1 on ≥ 12 of 18 | 55% | holds (12) |
| B7 | F and I1 nodes within 30% of E6's on ≥ 12 | 40% | refuted (3) |

### A results: E6+ ladders (`score_lad.R`, `score_lad.log`, `score_lad.rds`) [m]

54 rungs, all exit 0 (A12 holds). Coarse pair = (s 1.6, 1), fine pair = (1, 1/1.6), each estimating
the s = 1 rung's error in the spacing-ratio form; stress = share of 1000 draws passing (coord).

| case | order (cos) | coarse: read, C1–C5, stress | fine: read, C1–C5, stress | E6 pair stress | W at 1.6 / 1 / 1/1.6 (E6 c) | rows s=1 / E6 c | rows at E6's worst (× E6 c) | unseen coarse / fine / outside span | s* (0.85) |
|---|---|---|---|---|---|---|---|---|---|
| episodic | 1.93 (0.77) | 0.81, pass, 1.00 | 1.12, pass, 0.92 | 0.96 | 1.41 / 0.34 / 0.11 (0.30) | 1.16 | 1.21 | 0.105 / 0.033 / 0.022 | 1.35 |
| dry | 0.79 (0.53) | 0.18, **C3**, 0.00 | 0.91, pass, 0.90 | 0.35 | 1.02 / 0.44 / 0.28 (0.35) | 1.31 | 1.48 | 0.189 / 0.067 / 0.053 | 1.45 |
| long-wet | 1.88 (0.99) | 0.94, pass, 1.00 | 1.00, pass, 0.99 | 0.98 | 0.90 / 0.37 / 0.14 (0.37) | 1.31 | 1.31 | 0.011 / 0.018 / 0.010 | 1.56 |
| long-drought | 1.13 (0.97) | 0.65, pass, 1.00 | 0.94, pass, 0.99 | 0.96 | 0.80 / 0.40 / 0.16 (0.37) | 1.34 | 1.37 | 0.053 / 0.017 / 0.015 | 1.67 |
| episodic-lma | 1.64 (1.00) | 0.85, flags (W 1.32), 1.00 | 1.00, flags, 1.00 | 0.97 | 3.07 / 1.32 / 0.58 (1.28) | 1.17 | 1.19 | 0.114 / 0.102 / 0.051 | 0.78 |
| dry-flat | 2.35 (0.82) | 1.11, **C3**, 0.42 | 0.89, pass, 0.56 | 0.18 | 1.66 / 0.60 / 0.29 (0.58) | 1.39 | 1.41 | 0.097 / 0.066 / 0.054 | 1.17 |
| ld-102 | 1.58 (0.98) | 0.87, pass, 1.00 | 0.97, pass, 0.88 | 0.91 | 0.98 / 0.42 / 0.18 (0.41) | 1.36 | 1.37 | 0.031 / 0.032 / 0.024 | 1.48 |
| ld-105 | 1.97 (0.96) | 0.96, pass, 1.00 | 0.91, pass, 0.96 | 0.87 | 0.93 / 0.36 / 0.14 (0.32) | 1.29 | 1.33 | 0.032 / 0.031 / 0.019 | 1.53 |
| dry-p50 | 0.98 (0.50) | 0.21, **C3**, 0.00 | 0.98, pass, 0.97 | 0.29 | 1.03 / 0.44 / 0.18 (0.35) | 1.30 | 1.39 | 0.186 / 0.041 / 0.025 | 1.44 |
| wet-adG2 | 2.55 (0.95) | 1.07, pass, 1.00 | 0.91, pass, 0.99 | 0.95 | 1.21 / 0.46 / 0.20 (0.44) | 1.36 | 1.37 | 0.035 / 0.020 / 0.010 | 1.35 |
| dry-lma125 | 2.46 (0.87) | 1.74, **C3**, 0.01 | 1.46, **C5**, 0.91 | 0.00 | 2.19 / 0.76 / 0.20 (0.71) | 1.29 | 1.31 | 0.298 / 0.128 / 0.047 | 1.05 |
| flat-al1125 | 2.07 (0.98) | 0.92, pass, 1.00 | 0.92, pass, 1.00 | 0.77 | 1.92 / 0.73 / 0.32 (0.71) | 1.34 | 1.35 | 0.050 / 0.030 / 0.015 | 1.08 |
| wet-lma08 | 1.76 (0.99) | 0.92, pass, 1.00 | 0.98, pass, 0.93 | 0.97 | 1.20 / 0.49 / 0.19 (0.53) | 1.41 | 1.39 | 0.021 / 0.020 / 0.015 | 1.34 |
| wet-hmat125 | 1.59 (0.97) | 0.95, pass, 1.00 | 1.00, pass, 0.66 | 0.76 | 1.76 / 0.73 / 0.27 (0.71) | 1.32 | 1.33 | 0.024 / 0.053 / 0.011 | 1.09 |
| epi-hmat08 | 2.90 (0.97) | 1.28, pass, 1.00 | 0.77, pass, 1.00 | 0.88 | 0.74 / 0.25 / 0.13 (0.21) | 1.15 | 1.29 | 0.017 / 0.021 / 0.010 | 1.70 |
| epi-adG208 | 1.47 (0.82) | 0.83, pass, 1.00 | 1.17, pass, 0.84 | 0.96 | 1.37 / 0.44 / 0.16 (0.39) | 1.14 | 1.20 | 0.067 / 0.062 / 0.042 | 1.31 |
| ld104-p50125 | 0.83 (0.93) | 0.68, pass, 1.00 | 1.06, pass, 0.96 | 0.91 | 0.58 / 0.26 / 0.09 (0.26) | 1.24 | 1.25 | 0.044 / 0.016 / 0.012 | 2.02 |
| ld107-adG2125 | 1.82 (0.94) | 0.95, pass, 1.00 | 0.91, pass, 0.99 | 0.94 | 0.60 / 0.24 / 0.11 (0.24) | 1.24 | 1.23 | 0.026 / 0.015 / 0.006 | 1.91 |

- **E6+ costs more than E6 and is no more accurate.** s = 1 has 1.32× (bank) / 1.29× (held-out) E6
  committed's rows, and its worst error is at or under E6's on 3 of 18. At E6's worst error it
  needs 1.19–1.48× E6's rows (median 1.37 bank, 1.30 held-out); U needed 1.10–1.23× (median 1.15)
  on the bank. The edge nodes are early, so each costs nearly a full run's steps, and on dry they
  also remove the closing-inset cancellation (X above).
- **Its coarse pair still misreads on the dry records** (dry 0.18, dry-p50 0.21, dry-flat C3,
  dry-lma125 1.74): before 10 the edges are nodes, but after 10 E6's fixed inset stays, and the
  error there does not move with the background (order 0.79 / 0.98 on dry / dry-p50, cos 0.5).
  Coarse pair: 7/10 bank, 7/8 held-out; stress 0.742 bank (U 0.914), 0.876 held-out. Fine pair:
  10/10 and 7/8 (dry-lma125 over-reads to C5), stress 0.915 / 0.911, above E6's pair (0.742 /
  0.774).
- Order: median 1.79 [0.79, 2.90]; cos ≥ 0.85 on 13 of 18. What neither pair sees, outside
  span(d1, d2), is ≤ 0.054 everywhere (rms).
- The coarse rung is not cheap: 1.06× E6 committed's rows (median) — the fixed nodes hold its cost.
- The map on s = 1 runs reads the true ln J error to rms 0.029ε (max 0.060); on the 1.6 rungs it
  misses by up to 0.45ε (rms over all rungs 0.11ε).
- The ladder's optimum s* (worst = 0.85): median 1.44 bank, 1.32 held-out; only episodic-lma
  (0.78) needs finer than s = 1.

### L results: route A, the E6+ loop, for real (`drive.sh A`, `score_loop.R`, `score_loop_0.15.log`, `loopA_*.rds`) [m]

Every run the loop asked for was already on disk (its second runs are ladder rungs, and every
third run it took was s/1.6 after a map disagreement, which is again a rung), so the real loop
added no runs; the drivers replayed from the stored runs.

| | bank: route A | E6 as built | held-out: route A | E6 as built |
|---|---|---|---|---|
| T (rows model) | 11178 (×1.204) | 9287 | 8009 (×1.114) | 7191 |
| C1–C5 on the real runs | 8/10 (dry, dry-p50: C3) | 10/10 | 8/8 | 7/8 |
| stress, coord / jit | 0.776 / 0.797 | 0.745 / 0.868 | 0.974 / 0.997 | 0.771 / 0.837 |
| runs mean (max) | 2.10 (3) | 2 | 2.00 (2) | 2 |
| final coarser / at start / finer | 1 / 8 / 1 | — | 2 / 5 / 1 | — |
| final within ×1.6 of s* | 10/10 | — | 6/8 | — |
| worst final error, median (max) | 0.45 (0.80) over the 18 | | | |

- The start predicted slack on 16 of 18 (P5), so the second run was the coarse rung; it was the
  answer on 3 (long-drought, ld104-p50125, ld107-adG2125). The fine rung answered on episodic-lma
  and dry-lma125 (predicted over). Everywhere else s = 1 answered on the coarse pair's estimate.
- It fails C3 on dry and dry-p50 for the reason above (the coarse pair's read 0.17 / 0.21), and
  under stress there (0.20, 0.12) and on dry-flat (0.61). On the held-out set it is more robust
  than E6 (0.974 against 0.771 under coord stress), largely because E6 fails dry-lma125 in every
  draw.
- **The non-asymptotic flag** fired on 8 members over 7 cases, 6 of them coarse members at 1.6 where
  the map, not the pair, was wrong (the map reads the 1.6 rungs badly). The pair's ln J estimate
  was nearer the true ln J error in 7 of the 8. It blocked an answer twice, both unnecessarily:
  dry-flat s = 1 (true worst 0.60; one extra fine run, T 2712 against 1683) and epi-hmat08 s = 1.6
  (true 0.74; it answered at s = 1 instead).
- **Reserve** (route A, all 18; stress T in brackets): 0 → T 19004 (−1.0%; bank −1.6%, held 0),
  coarser on 6 of 18, pass 16/18, stress 0.771 / 0.969; 0.15 → 19187, pass 16/18; 0.3 → 19702
  (+2.7%; bank 0, held +6.4%), pass 16/18, stress 0.781 / 0.974. The reserve moves few decisions
  because the E6+ rungs sit far from 0.85 on either side.

### Route A against Route B against E6 (all 18, T in the rows model)

| | E6 as built | route A (E6+ loop) | Route B (map-guided from U16) |
|---|---|---|---|
| T, bank / held-out | 9287 / 7191 | 11178 / 8009 | 9475 / 6598 |
| T, all 18 | 16478 | 19186 (×1.16) | 16072 (×0.975) |
| pass C1–C5 | 17/18 | 16/18 | 13/18 |
| worst final error, median (max) | 0.38 (0.71) | 0.45 (0.80) | 0.56 (0.81) |
| runs mean | 2 | 2.06 | 2.11 |
| final rows / E6 committed, median | 1 | 1.31 | 1.10 |

Route B is 15–18% cheaper than route A (**B2′ holds**) and 2.5% cheaper than E6, but it is the least
honest of the three (C2/C3 fails on four dry-type cases), and its finals are on average less
accurate than E6's committed runs at more rows. Neither loop reaches E6's accuracy per row.

## All predictions scored

| # | P | result |
|---|---|---|
| G1 build reproduces libS identically | 85% | holds |
| G2 map within 0.05ε of the dwr figure | 80% | holds (−0.1234 both) |
| A1 median order in [1.5, 2.5] | 55% | holds (1.79) |
| A2 coarse pair ≥ 8/10 bank and ≥ 6/8 held-out | 50% | refuted (7/10, 7/8) |
| A3 fine pair ≥ 9/10 and ≥ 7/8 | 55% | holds (10/10, 7/8) |
| A4 E6+ worst ≤ E6's on ≥ 11 of 18 | 50% | refuted (3) |
| A5 rows ratio in [1.10, 1.25] | 65% | refuted (1.32 / 1.29) |
| A6 ≤ 1.10× E6's rows at matched worst on half | 40% | refuted (min 1.19) |
| A7 coarse stress ≥ 0.90 over the 18 | 50% | refuted (0.80) |
| A8 dry-lma125 coarse pair misreads | 60% | holds (1.74, C3) |
| A9 cos ≥ 0.85 on ≥ 14 of 18 | 60% | refuted (13) |
| A10 outside span ≤ 0.06 on ≥ 14 | 50% | holds (18) |
| A11 s = 1.6 rows / E6 c median in [0.85, 1.05] | 60% | refuted (1.06) |
| A12 no run throws | 90% | holds (all 104 runs exit 0) |
| L1 bank T in [0.85, 1.00] × E6 | 50% | refuted (1.20) |
| L1′ held-out T ≤ E6's | 50% | refuted (1.11) |
| L2 ≥ 9/10 and ≥ 7/8 pass | 55% | refuted (8/10, 8/8) |
| L3 more stress passes than E6 on both sets | 70% | holds (0.776 vs 0.745; 0.974 vs 0.771) |
| L4 runs mean ≤ 2.3, max ≤ 3 | 60% | holds |
| L5 coarser on ≥ 3 of 18 | 45% | holds (3) |
| L6 finer on ≤ 3 of 18 | 70% | holds (2) |
| L7 within ×1.6 of s* on ≥ 14 | 60% | holds (16) |
| F1 flag alone on ≤ 3 cases | 55% | holds (2) |
| F2 map − true ln J rms ≤ 0.1ε at s = 1 | 50% | holds (0.029) |
| F3 where it fires, the pair is further off than the map | 55% | refuted (1 of 8) |
| R1 reserve 0: bank T −3% or more | 40% | refuted (−1.6%) |
| R2 reserve 0.3: bank T +5% or more | 45% | refuted (0%) |
| X1 U's strips carry more than its extra rows | 75% | holds |
| X2 U's background deficit mostly in spells < 150 d | 65% | refuted |
| X3 U's interior map larger on ≥ 2 of 3 | 60% | holds (3/3) |
| X4 dry-flat E6+ worse than E6 | 60% | holds (0.60 vs 0.58) |
| X5 strips' remainder < 0.1ε | 50% | holds |
| B0–B7 | | B0, B2′, B4, B6 hold; B1, B2, B3, B5, B7 refuted (table above) |

**41 registered: 22 held, 19 refuted** (G 2/2, A 5/12, L/F/R 7/13, X 4/5, B 4/9).

Outputs kept: `runs/` (104 gradient runs, 62 MB: ladders `ep*`, Route B `rb_*`, map replays `g*`),
`score_lad.rds`, `score_loop_*.rds`, `score_rb_0.15.rds`, `loopA_*.rds`, `loopB_0.15.rds`, logs.
The scratch build (`loop/build`) is deleted.
