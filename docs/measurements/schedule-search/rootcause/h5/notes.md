# H5: a layout whose error is one second-order term (systematic debugging)

Subject: TF24's node layout on the birth-date coordinate. H5 (from `../synthesis.md` and
`../closing/notes.md`): each closing edge c a node plus a fixed node at c − 12 d; only the
stretches between fixed nodes scale with one spacing scale s; then the error is clean
second order in s and a pair of runs predicts it.

Method: `.claude/skills/systematic-debugging/SKILL.md`; every prediction is written here
before the run or analysis it concerns. Every run uses the E6 committed setting
(`adj_run_nk.R` on `adjmap/libS`, KNOTS=0, TOL 1e-4, one_nk.sh's environment; `run.sh` here).
Errors are in each quantity's ε against the lib19-class reference (`../common.R`); "along M"
is the projection on P's unit hydraulic direction. Scripts are in this directory; outputs in
`scratchpad/deep/rootcause/h5/` (`runs/`, `sched/`, `logs/`, `*.log`, `summary.rds`).
**[m]** measured, **[i]** inferred.

## Summary (written last)

(pending)

## The layout as built (`lib.R`, `h5_sched`)

a09's graded build (`build_graded`, BG 90) at spacing s·h, with the builder's range cap
scaled by s too (as H1 did), late edges (b > 25) left out as `a09_late` does. Every edge
before 25 is treated by a rule that does not depend on s:
- closing edge c: a node at c and a node at c − 12 d;
- opening edge o: either `inset` (no node at o, a node at o + d_o) or `node` (a node at o,
  unless the gap before it or the spell after it is under 2 d, and a node at o + 12 d);
- only the stretch between those nodes is placed by the graded measure at s·h (founders
  [0, b1 − 12 d], spell interiors, and each spell's remaining stretch);
- a spell too short for its strips (stretch under 2 d) keeps its edge nodes and, if longer
  than 13 d, one node at its centre (inset mode: c − min(12 d, L/2)).

Guard [m]: `h5_sched(cs, 1, "raw", close = FALSE)` reproduces a09's committed build exactly
on all ten cases (`guard.R`). The rungs are not nested: a ratio of 1.6 cannot nest, and
each stretch's count is ceil(∫ 1/(s·h)). What all rungs share exactly is the fixed nodes
(edges, c − 12 d, and o + 12 d in `node` mode).

Node counts [m, schedule only] (`guard.R`), s = 1.6 / 1 / 1/1.6:

| case | E6 committed | H5, opening `node` | H5, opening inset 12 d | proxy shrink x→c, c→f (node) |
|---|---|---|---|---|
| episodic | 135 | 159 / 187 / 240 | 129 / 157 / 210 | 0.47, 0.35 |
| dry | 149 | 194 / 225 / 274 | 147 / 178 / 227 | 0.43, 0.41 |
| long-wet | 157 | 214 / 245 / 286 | 169 / 200 / 241 | 0.43, 0.43 |
| long-drought | 155 | 217 / 245 / 292 | 169 / 197 / 244 | 0.42, 0.43 |
| episodic-lma | 120 | 129 / 158 / 211 | 107 / 136 / 189 | 0.44, 0.40 |
| dry-flat | 191 | 313 / 330 / 365 | 231 / 248 / 283 | 0.42, 0.40 |
| ld-102 | 143 | 195 / 220 / 268 | 152 / 177 / 225 | 0.47, 0.38 |
| ld-105 | 146 | 183 / 215 / 262 | 143 / 175 / 222 | 0.42, 0.42 |
| dry-p50 | 153 | 200 / 230 / 281 | 152 / 182 / 233 | 0.43, 0.40 |
| wet-adG2 | 158 | 224 / 252 / 294 | 174 / 202 / 244 | 0.43, 0.43 |

The fixed nodes are most of the count: x/c is 0.86 on dry in `node` mode (0.83 inset), and
the `node` committed rung has as many nodes as E6's check (dry 225 against 219). (1/r² =
0.39.)

## O. The opening edge first

The opening strip [o, o + 12 d] under the inset rule is read on the gap interval's chord,
which under H5 runs from the closing node c to o + 12 d. On dry it carried root_P50 −0.14
(`../p50/notes.md`, R1g, on res). Two questions: is its error a power law in the inset d_o
(then d_o = 12·s rides with the h² term at no extra node), and what does fate do across an
opening edge.

Runs (`mk_open.R dry`), all at s = 1 with H5's closing treatment:
- oin24 / oin12 / oin6: opening inset 24 / 12 / 6 d (172 / 178 / 184 nodes);
- ores: the opening side resolved: a node at o, the strip at 3 d, every spell under 26 d at
  ≤ 3 d (373 nodes); e(d) = Q(oin_d) − Q(ores);
- omap / omapp: fate maps across the 22 opening edges after b1 with a gap > 8 d before and a
  spell > 40 d after (gap probes at o − 6, −3, −1 d; nodes at o + 0 … 36 d), forward only,
  base and root_P50 × 1.02 (552 nodes).

### Pre-registration O (before any O run)

- **O1a (fate's shape).** ln nrr is smooth across the opening strip: on most mapped edges
  its curvature over [o, o + 12 d] is within 2× of that over [o + 12, o + 36 d] — 50%.
- **O1b (continuity).** The gap probes continue the spell-side curve: the slope's jump at o
  is smaller than the slope itself on most edges — 60%.
- **O1c (sensitivity turn).** The root_P50 sensitivity s(b) = d ln nrr / d ln root_P50 has a
  local extremum inside [o, o + 12 d] on most mapped edges (a turn like the closing side's
  at c − 10 d) — 35%.
- **O2a (size).** e(12) root_P50 in [−0.25, −0.05] — 60%.
- **O2b (power law).** ⟨e24, e12⟩/|e12|² in [2.6, 6] (law 4) with cos(e24, e12) ≥ 0.8 — 45%.
- **O2c (floor).** e(6) rms ≤ 0.03 — 70%.
- **O2d (fixed strip too big).** max |e(12)| over quantities ≥ 0.1 (ε/10) — 55%.

Decision registered with them: if O2b holds and e(6) is consistent with it (its projection
on e12 within 0.25·e12 ± the jitter), the opening inset scales with s (d_o = 12·s);
otherwise the opening edge gets the closing side's treatment (`node` mode: o and o + 12 d
fixed).

### O2 results: the opening-inset ladder on dry (`score_open.R dry`, `open_dry.rds`) [m]

| run | nodes | rows | err vs ref: rms / max / along M / root_P50 | e(d) = Q − Q(ores): rms / max / along M / ln J / top |
|---|---|---|---|---|
| oin24 | 172 | 224 | 0.193 / 0.57 / −0.14 / −0.57 | 0.151 / 0.48 / +0.45 / +0.215 / root_P50 −0.48, omega +0.38, a_l1 −0.36, a_dG2 −0.26 |
| oin12 | 178 | 233 | 0.148 / 0.44 / −0.42 / −0.13 | 0.045 / 0.19 / +0.17 / +0.065 / stem_c −0.19, a_l1 −0.14, omega +0.09, TF24_cost_scale −0.07 |
| oin6 | 184 | 241 | 0.153 / 0.47 / −0.44 / −0.01 | 0.047 / 0.21 / +0.15 / +0.011 / stem_c −0.21, TF24_cost_scale −0.17, a_l1 −0.11, root_P50 +0.08 |
| ores | 373 | 480 | 0.160 / 0.58 / −0.59 / −0.08 | — |

- e24 on e12: projected 2.34 (law 4), cos 0.71, rms ratio 3.32. e6 on e12: projected 0.67
  (law 0.25), cos 0.64, rms ratio 1.04. The moves themselves are consistent: d1 = oin24 −
  oin12 on d2 = oin12 − oin6 projected 2.94 (law 4), cos 0.94.
- So the opening side's error is a d-dependent part (order ≈ 1.6 by the moves, log 2.94 /
  log 2) plus a part that does not shrink with d: e(6) is as large as e(12) (rms 0.047 vs
  0.045), with stem_c −0.19 / −0.21 and TF24_cost_scale in both. One run's jitter is ≈ 0.024
  rms, so 0.034 of each e(d) is jitter; the shared stem_c −0.2 is ~3× that per quantity [i].
  What ores changes beyond the strip (a node at o; spells under 26 d at 3 d) holds it [i].
- **Scored:** O2a refuted narrowly (root_P50 −0.04; the strip's root_P50 error under H5's
  closing nodes is a quarter of the p50 round's −0.14 on res). O2b refuted (2.34, cos 0.71).
  O2c refuted (0.047). O2d holds (max 0.19, stem_c).
- **Decision (as registered): not a power law → the opening edge gets the closing side's
  treatment, rule N** (o a node and o + 12 d fixed). Scaling the opening inset with s
  (rule S) would carry an offset of rms ≈ 0.045, max ≈ 0.2 that no pair sees, plus a part of
  order ≈ 1.6. The fate maps (O1) are read below before the ladder is scored.

## L. The ladder, rule N, first three cases

Runs (`mk_ladder.R N ...`): N16 / N10 / N06 (s = 1.6, 1, 1/1.6) on dry, dry-p50, long-wet;
N10r on dry (every fixed strip [c − 12, c] and [o, o + 12 d] cut at 3 d: the fixed strips'
own error, −(N10r − N10), no order assumed); N10@jit on dry (tolerance 1.05e-4: the jitter
floor under H5). Scoring (`score_ladder.R`): d1 = x − c, d2 = c − f; order against the
proxy's shrink (p solves (Px^q − Pc^q)/(Pc^q − Pf^q) = ratio, p = 2q), pooled and per
quantity (quantities with |d1| > 0.1 and |d2| > 0.05); the coarse pair's estimate
d1/(1/s_x − 1) and the fine pair's d2/(1 − s_f) of the committed rung's error; C1–C5 by
`crit` for each.

### Pre-registration L (before any ladder run)

- **L1 (order, pooled).** p_pool within [1.6, 2.4] on each of the three cases — 50%; on at
  least two — 70%.
- **L2 (direction).** cos(d1, d2) ≥ 0.85 on each of the three — 55%.
- **L3 (worst quantity).** At least 80% of the quantities with readable moves have
  per-quantity order in [1, 3], on each case — 45%.
- **L4 (H1 retest).** The coarse pair's median read (|err| > 0.2) lies in [0.7, 1.4] on all
  three — 50%; the coarse pair passes C1–C5 on at least two of three — 50%; the fine pair
  passes on all three — 60%.
- **L5 (what no pair sees).** rms(err_c − est_fine) ≤ 0.08 on each case — 45%.
- **L6 (size).** The committed rung's worst error is at most E6 committed's on at least two
  of three — 60%.
- **L7 (fixed strips).** On dry, max |N10r − N10| < 0.1 (ε/10) — 50%; rms ≤ 0.04 — 60%.
- **L8 (jitter).** N10@jit − N10 on dry: rms 0.015–0.04 and |along M| ≤ 0.12 — 65%.
- **L9 (cost).** N10's rows ≥ 1.3 × E6 committed's on all three — 75%.

### O1 results: fate across opening edges on dry (`score_omap.R dry`, `omap_dry.rds`; 22 edges) [m]

- **Fate has a corner at the opening edge.** ln nrr is continuous through o (o − 3 d and o
  agree to 1e-3) but its slope changes sign there on all 22 edges: median +0.51e-3 /d on
  the gap side (a recruit born closer to the rain's return waits through less drought) and
  −2.18e-3 /d just after o (inside the wet spell a later birth is a smaller, later copy);
  −2.56e-3 /d over the strip.
- **The gate opens at once**: establishment at o + 0.5 d is already 1.00 of the spell's
  mean (median; one edge 0.86). No ramp, unlike the closing side's 1–2 d.
- Fate's curvature is concentrated in the strip: |k| over [o, o + 12 d] median 3.2× that
  over [o + 12, o + 36 d] (median −0.24e-4 /d² against ≈ 0).
- **The root_P50 sensitivity has no turn at openings**: s(b) = d ln nrr / d ln root_P50
  is flat through the strip (median −1.639 / −1.641 / −1.640 / −1.633 at o − 3, o, o + 12,
  o + 36 d); its slope keeps its sign from [0, 6] to [6, 12] d on 22/22 edges. The closing
  side's 10-d turn has no opening counterpart.
- **Scored:** O1a refuted (9/22 within 2×); O1b refuted (0/22: the jump exceeds the slope on
  every edge, a corner); O1c refuted (0/22).
- Reading [i]: the inset rule reads [o, o + d] on the chord from the closing side's node to
  o + d, so the chord spans fate's corner at o; the chord's slope is set by the gap and the
  closing side, not by d, and the strip's error carries that lever (a d-dependent part
  plus what the gap sets, as O2 measured). A node at o puts the corner on a node and leaves
  the strip [o, o + 12 d] a hat interval over smooth (if curved) fate. That is what rule N
  does; the mechanism agrees with the decision O2 made.

## W, V. Added mid-round (coordinator): an s = 2.0 rung, and where H5's extra rows come from

### V0. Where the extra nodes are (`decomp.R`; schedule only) [m]

Nodes at s = 1 by kind (closing edge c; c − 12 d; opening edge o; o + 12 d; other nodes
before 25; nodes after 25):

| case | layout | n | c | c − 12 | o | o + 12 | other < 25 | ≥ 25 |
|---|---|---|---|---|---|---|---|---|
| dry | E6 committed | 149 | 0 | 28 | 0 | 28 | 82 | 11 |
| dry | N | 224 | 48 | 28 | 46 | 28 | 63 | 11 |
| dry | N1 (o a node, no o + 12) | 200 | 48 | 37 | 46 | 0 | 58 | 11 |
| dry | C (opening inset 12 d fixed = oin12) | 178 | 48 | 30 | 0 | 28 | 61 | 11 |
| dry | N, E6's inset from b = 17 | 192 | 32 | 28 | 30 | 28 | 63 | 11 |
| dry | N1, E6's inset from b = 17 | 176 | 32 | 34 | 30 | 9 | 60 | 11 |
| long-wet | E6 / N / N1 / C | 157 / 245 / 205 / 200 | 0 / 51 / 51 / 51 | 42 / 42 / 48 / 46 | 0 / 45 / 45 / 0 | 42 / 42 / 0 / 42 | 63 / 55 / 51 / 51 | 10 |
| episodic-lma | E6 / N / N1 / C | 120 / 158 / 140 / 136 | 0 / 22 / 22 / 22 | 22 | 0 / 22 / 22 / 0 | 22 / 22 / 0 / 22 | 66 / 60 / 64 / 60 | 10 |
| dry-flat | E6 / N / N1 / C | 191 / 328 / 280 / 248 | 0 / 93 / 93 / 93 | 54 / 53 / 66 / 55 | 0 / 80 / 80 / 0 | 54 / 53 / 0 / 53 | 81 / 47 / 39 / 45 | 2 |

- **H5's extra nodes are the edge nodes, all of them.** E6's inset nodes are H5's c − 12 d
  and o + 12 d nodes already; H5 adds one node per closing edge (dry +48) and one per
  opening edge (+46), and its background is *sparser* than E6's (63 against 82 other
  nodes before 25 on dry), because the strips are taken out of the graded stretch. The
  fixed node at c − 12 d costs nothing over E6; it is E6's inset node.
- After b = 25 H5 has no fixed nodes (late edges are left out, as in E6); the nearest
  saving of that kind is to give the edges from b = 17 E6's inset (one node each), which
  drops 32 nodes on dry (the era 17–25 carried 4% of the interiors' root_P50, p50 R2a).
- Widest open interval (d) in rule N, s = 2 / 1.6 / 1 / 1/1.6: before b = 20: dry 198 / 160 /
  103 / 65, long-wet 211 / 169 / 106 / 65, episodic-lma 224 / 168 / 112 / 69, dry-flat 217 /
  174 / 109 / 70; in 20–25 up to 227 / 227 / 179 / 126 (dry), 462 / 308 / 231 / 168
  (episodic-lma). After 25 the late intervals are E6's (a09_late), scaled.

### Pre-registration W and V (before any of their runs)

Runs: N20 (s = 2.0) on dry, long-wet, episodic-lma; on dry the ladders N1 (s = 1.6 / 1 /
1/1.6), N1 from b = 17 with E6's inset after (kind T, same s), and C (opening inset fixed
12 d; s = 1 is oin12, so s = 1.6 and 1/1.6 added). "Matched error" is read by
interpolating log worst error (and log rms) against log rows along each layout's rungs, at
E6 committed's worst (dry 0.35) and rms (0.159).
- **W1.** The pooled order from s = 2.0 / 1.6 / 1 lies in [1.6, 2.4] on all three cases —
  35%; on at least two — 55%. The 2.0/1 pair's median read in [0.7, 1.4] on all three — 45%.
  A run refuses (throws) — 10%.
- **V1.** N1's ladder is clean (pooled p in [1.6, 2.4], cos ≥ 0.85) — 55%; its committed
  worst error is within ±20% of N's (0.60) — 50%; at matched worst error it needs ≤ 0.9× N's
  rows — 55%.
- **V2.** T (N1 from b = 17) is clean by the same test — 45%; the part no pair sees,
  rms(err_c − est_fine), is ≤ 0.06 — 50%; at matched worst error ≤ 0.85× N's rows — 50%.
- **V3.** C's moves are clean (p in band, cos ≥ 0.85) — 55%, but its unseen part is larger
  than N's by ≥ 0.02 rms (the fixed opening strip, O2) — 55%.
- **V4.** At matched worst error (E6's 0.35), every H5 variant needs more rows than E6's
  committed run — 80%.

### Pre-registration L′ (dry-flat and episodic-lma, before their runs)

- **L′1.** Pooled p in [1.6, 2.4] and cos ≥ 0.85 on both — 40% (dry-flat has 93 closing
  edges and the shortest spells; episodic-lma's error is mostly the founders').
- **L′2.** The coarse pair passes C1–C5 on both — 45%; the fine pair on both — 55%.
- **L′3.** episodic-lma's committed rung worst error > 1 (E6's committed erred 1.28 there) —
  55%.

### L results, first three cases (`score_ladder.R N dry dry-p50 long-wet`, JIT = N10@jit; `ladder_N_dry+dry-p50+long-wet.rds`) [m]

| | dry | dry-p50 | long-wet |
|---|---|---|---|
| nodes x / c / f (E6 c / f) | 193 / 224 / 273 (149 / 219) | 196 / 226 / 277 (153 / 222) | 214 / 245 / 286 (157 / 234) |
| rows x / c / f (E6 c / f) | 248 / 290 / 360 (188 / 269) | 254 / 297 / 367 (193 / 274) | 314 / 359 / 424 (220 / 328) |
| CPU s x / c / f (E6 c / f) | 267 / 312 / 388 (223 / 344) | 277 / 321 / 398 (221 / 352) | 357 / 393 / 457 (259 / 419) |
| committed worst (quantity) / rms / along M | 0.60 (a_l1) / 0.170 / −0.65 | 0.72 (a_l1) / 0.207 / −1.01 | 0.41 (a) / 0.107 / −0.05 |
| E6 committed worst / rms | 0.35 / 0.159 | 0.35 / 0.141 | 0.36 / 0.093 |
| worst x / f | 1.46 / 0.16 | 1.66 / 0.28 | 0.92 / 0.18 |
| proxy shrink s_x, s_f; law d1/d2 | 0.433, 0.414; 2.23 | 0.433, 0.404; 2.20 | 0.428, 0.434; 2.37 |
| measured d1/d2 (projected), meas/law | 1.85, 0.83 | 1.77, 0.81 | 2.14, 0.90 |
| **pooled order** p (nominal, r = 1.6) | **1.56** (1.31) | **1.50** (1.22) | **1.76** (1.61) |
| **cos(d1, d2)** | **0.92** | **0.98** | **0.99** |
| per-quantity order: n, median [10–90%], share in [1, 3] | 17, 2.12 [1.27, 3.31], 59% | 24, 1.58 [1.01, 2.03], 88% | 12, 1.83 [1.70, 2.00], 100% |
| lowest / highest per-quantity order | hmat 0.87 / r_r 3.49 | TF24_cost_scale 0.10 / root_P50 2.50 | R_d_25 1.61 / sro 2.03 |
| **coarse pair** (x, c): read, corr, C3, C1–C5 | **1.02**, 0.96, 4/4, pass | **0.94**, 0.97, 5/5, pass | **0.94**, 0.97, 1/1, pass |
| **fine pair** (c, f): read, corr, C3, C1–C5 | 0.96, 0.95, 4/4, pass | 1.21, 0.99, 7/7, pass | 1.01, 0.97, 1/1, pass |
| E6 pair (for reference): pass, read | pass, 1.06 | pass, 1.15 | pass, 0.97 |
| unseen rms(err_c − est), coarse / fine (max) | 0.048 / 0.062 (0.16 / 0.27) | 0.049 / 0.052 (0.18 / 0.12) | 0.028 / 0.028 (0.09 / 0.12) |
| estimate's jitter noise, coarse / fine (rms) | 0.017 / 0.039 | 0.017 / 0.038 | 0.017 / 0.040 |

- **The pairs read the committed error, both of them**: per-quantity reads of the coarse
  pair on dry 0.80–1.19 (TF24_cost_scale 0.80, lma 1.19), dry-p50 0.90–1.19 except
  TF24_cost_scale 0.43 (C3 counts it inside the allowance), long-wet 0.92–1.03. H1's
  failure (dry 0.10, dry-p50 0.37) is gone: the coarse pair now reads as well as the
  finer one, and its estimate is ~2× quieter (0.017 against 0.039 rms from jitter).
- **But the order is not 2.** Pooled against the proxy's shrink, 1.50–1.76; measured
  d1/d2 is 0.81–0.90 of the square law's. The direction is stable (cos 0.92–0.99), so the
  error is one term, of order ≈ 1.5–1.8. On dry the pooled order is pulled down by a_l1
  (order 1.3; d1 0.86, d2 0.51), the M direction; the other quantities sit near 2 (median
  2.12). Order 1.5 against an assumed 2 makes the pairs under-read by ×0.67 (coarse) and
  ×0.83 (fine) in the model, which the reads (0.94–1.21) do not show [i]: the reads are
  set against the reference, whose own error and the unseen part (rms 0.03–0.06) enter.
- **The committed rung is less accurate than E6's** on all three (worst 0.60 / 0.72 / 0.41
  against 0.35 / 0.35 / 0.36). The extra error is along M on the dry records (−0.65, −1.01
  against E6's −0.30, −0.42): the closing edge node brings back the edge-node bias (A1)
  that E6's 12-d inset cancelled, now as a term that shrinks with s instead of a balance.

### L7–L8: fixed strips and jitter on dry (`score_strips.R dry`) [m]

- **Fixed strips' own error**, −(N10r − N10), every [c − 12, c] and [o, o + 12 d] cut at 3 d
  (392 nodes): rms 0.015, max 0.059 (stem_c +0.06, root_P50 −0.05), along M 0.00, ln J
  −0.011; hydraulic rms 0.033, leaf 0.005. **Under ε/10 in every quantity**, and under one
  run's jitter in rms.
- **Jitter floor under H5**, N10@jit (tolerance 1.05e-4) − N10: rms 0.023, max 0.08
  (TF24_cost_scale +0.08, a_st1 −0.06, a_dG2 −0.05), along M −0.06; leaf 0.011, hydraulic
  0.025. As E6's (0.024, +0.09).

### L scored

| # | prediction | P | result |
|---|---|---|---|
| L1 | pooled p in [1.6, 2.4] on each of three | 50% | refuted (1.56, 1.50, 1.76) |
| L1′ | on at least two | 70% | refuted (one) |
| L2 | cos ≥ 0.85 on each | 55% | holds (0.92, 0.98, 0.99) |
| L3 | ≥ 80% of readable quantities with order in [1, 3], each case | 45% | refuted (dry 59%; dry-p50 88%, long-wet 100%) |
| L4 | coarse read in [0.7, 1.4] on all three | 50% | holds (1.02, 0.94, 0.94) |
| L4′ | coarse pair passes C1–C5 on ≥ 2 of 3 | 50% | holds (3/3) |
| L4″ | fine pair passes on all three | 60% | holds |
| L5 | unseen rms ≤ 0.08 each | 45% | holds (0.062, 0.052, 0.028) |
| L6 | committed worst ≤ E6's on ≥ 2 of 3 | 60% | refuted (0/3) |
| L7 | fixed strips max < 0.1 | 50% | holds (0.059) |
| L7′ | fixed strips rms ≤ 0.04 | 60% | holds (0.015) |
| L8 | jitter rms 0.015–0.04, \|M\| ≤ 0.12 | 65% | holds (0.023, −0.06) |
| L9 | N10 rows ≥ 1.3 × E6 committed on all three | 75% | holds (1.54, 1.54, 1.63) |

## B. The ten-case bank at s = 1 and 1.6, rule N

H5 holds in part on the first three cases: the pairs read the committed error (both, all
C1–C5 passes, one stable direction), but the order is 1.5–1.8, not 2. The operational
claim (a pair predicts the error) holds, so the bank is run as step 4 asks: N10 and N16 on
the five cases not yet run (episodic, long-drought, ld-102, ld-105, wet-adG2), with dry-flat
and episodic-lma from the L′ queue. Scored as H1 scored its companion: the coarse pair's
estimate d1/(1/s_x − 1) against the committed rung's true error, C1–C5 by `crit`.

### Pre-registration B (before the bank's new runs)

- **B1.** The coarse pair passes C1–C5 on at least 9 of 10 cases (H1 8/10, E6 10/10) — 55%.
- **B2.** Median of the case reads in [0.8, 1.25] — 70%; no case read under 0.6 — 60%.
- **B3.** Rows: N10 over E6 committed 1.4–1.7 summed over the ten — 70%.
- **B4.** N10's worst error exceeds E6 committed's on at least 7 of 10 — 60%.

### V results on dry: variants and cost at matched error (`score_ladder.R M|T|C dry`, `score_var.R dry`, `var_dry.rds`) [m]

| layout (dry) | nodes x / c / f | rows x / c / f | worst x / c / f | rms c | along M c | pooled p | cos | per-q order median [min, max] | coarse pair read, C1–C5, unseen | fine pair read, C1–C5, unseen |
|---|---|---|---|---|---|---|---|---|---|---|
| N (o + o + 12) | 193 / 224 / 273 | 248 / 290 / 360 | 1.46 / 0.60 / 0.16 | 0.170 | −0.65 | 1.56 | 0.92 | 2.12 [0.87, 3.49] | 1.02, pass, 0.048 | 0.96, pass, 0.062 |
| M (o only) | 166 / 200 / 250 | 214 / 258 / 327 | 1.35 / 0.55 / 0.26 | 0.162 | −0.56 | 1.46 | 0.89 | 1.61 [0.59, 2.48] | 0.95, pass, 0.050 | 1.11, pass, 0.065 |
| T (M; E6 inset from b = 17) | 143 / 176 / 226 | 194 / 237 / 304 | 1.30 / 0.54 / 0.22 | 0.166 | −0.58 | 1.44 | 0.92 | 1.49 [0.23, 3.82] | 0.92, pass, 0.048 | 1.14, pass, 0.062 |
| C (opening inset 12 d fixed) | 147 / 178 / 227 | 192 / 233 / 302 | 1.31 / 0.44 / 0.17 | 0.148 | −0.42 | 1.48 | 0.76 | 2.63 [0.76, 4.19] | 1.22, pass, 0.090 | 0.88, pass, 0.096 |
| E6 (committed / check) | 149 / 219 | 188 / 269 | 0.35 / 0.26 | 0.159 | −0.30 | — | — | — | — | E6 pair pass, read 1.06 |

Rows needed to reach E6 committed's worst error (0.35) and rms (0.159), interpolated in log
error against log rows between bracketing rungs:

| layout | rows at worst 0.35 (× E6 committed) | rows at rms 0.159 (×) |
|---|---|---|
| N | 318 (1.69) | 295 (1.57) |
| M | 298 (1.59) | 260 (1.38) |
| T | 268 (1.43) | 240 (1.28) |
| C | 248 (1.32) | 230 (1.22) |

- **Where H5's extra rows come from:** the edge nodes, one per closing and one per opening
  edge (V0); the fixed c − 12 d node is E6's inset node and costs nothing; the background is
  sparser than E6's. Rows follow nodes (N/E6 rows 1.54 for nodes 1.50).
- **Dropping o + 12 d (M)** keeps the pairs' reads and C1–C5 and saves 11% of rows at
  s = 1 (6% at matched worst error, 12% at matched rms). Fate's corner is at o (O1), so the
  node at o is the one that matters.
- **E6's inset from b = 17 (T)** saves another 8% at s = 1 (rows 237): at matched worst
  error 0.84× N's rows, with the same reads (0.92 / 1.14), C1–C5 on both pairs and the same
  unseen part (0.048 / 0.062). The late strips' fixed error is too small to see on dry.
- **The opening inset (C)** is cheapest (0.78× N's rows at matched worst error) and most
  accurate per row, but its moves are not one term (cos 0.76, per-quantity order up to 4.2)
  and the part no pair sees grows to 0.090 / 0.096 (N 0.048 / 0.062): the fixed opening
  strip's offset (O2: rms 0.045, stem_c −0.2) enters every rung alike.
- **No H5 variant matches E6's committed error per row** (1.22–1.69×). E6's committed run is
  accurate for its rows because its inset cancels the edge-node bias along M (closing
  round); H5's layouts carry that bias as a term that shrinks with s (along M −0.65 → −0.30
  from s = 1 to 1/1.6 for N) instead.
- No variant reaches order 2 either: pooled 1.44–1.56 on dry for all four.

| # | prediction | P | result |
|---|---|---|---|
| V1 | M clean (p in [1.6, 2.4], cos ≥ 0.85) | 55% | refuted (p 1.46; cos 0.89) |
| V1′ | M's committed worst within ±20% of N's | 50% | holds (0.55 vs 0.60) |
| V1″ | M ≤ 0.9× N's rows at matched worst error | 55% | refuted (0.94; at matched rms 0.88) |
| V2 | T clean | 45% | refuted (p 1.44; cos 0.92) |
| V2′ | T's unseen rms ≤ 0.06 | 50% | refuted narrowly (fine pair 0.062; coarse 0.048) |
| V2″ | T ≤ 0.85× N's rows at matched worst error | 50% | holds (0.84) |
| V3 | C's moves clean | 55% | refuted (cos 0.76) |
| V3′ | C's unseen part ≥ N's + 0.02 | 55% | holds (+0.042 / +0.034) |
| V4 | every H5 variant needs more rows than E6 at E6's worst error | 80% | holds (1.32–1.69×) |

### Pre-registration U (one more variant, before its runs)

U: M with E6's inset from b = 10 (dry 155 nodes at s = 1). The p50 round put 73% of the
interiors' root_P50 in the era b1–10, so edges after 10 may carry little.
- **U1.** U's pairs both pass C1–C5 with reads in [0.7, 1.4] — 55%.
- **U2.** U's unseen part (fine pair) ≤ 0.08 — 50%.
- **U3.** At matched worst error U needs ≤ 0.9× T's rows — 40%.

### W results: the s = 2.0 rung (`score_ladder.R` RUNGS=20,16,10; `score_w.R`) [m]

| case | nodes s = 2 / 1.6 / 1 | rows | worst error s = 2 / 1.6 / 1 | shrink P1.6/P2 | pooled p (2.0/1.6/1) | cos | along M of the moves 2→1.6, 1.6→1 | (2.0, 1.6) pair on s = 1.6's error | wide pair (2.0, 1) on s = 1's error: read, corr, C1–C5, unseen |
|---|---|---|---|---|---|---|---|---|---|
| dry | 184 / 193 / 224 | 234 / 248 / 290 | 1.89 / 1.46 / 0.60 | 0.713 | 1.95 | 0.82 | −0.13, −0.88 | read 1.13, C3 17/24 fail, unseen 0.27 | 1.06, 0.95, pass, 0.054 |
| long-wet | 210 / 214 / 245 | 306 / 314 / 359 | 1.38 / 0.92 / 0.41 | 0.694 | 2.95 | 0.90 | +0.34, +0.01 | read 1.33, C3 9/14 fail, unseen 0.17 | 1.02, 0.95, pass, 0.040 |
| episodic-lma | 117 / 129 / 158 | 108 / 121 / 151 | 5.30 / 2.95 / 1.53 | 0.588 | 2.90 | 0.99 | +3.21, +1.65 | read 1.15, C3 37/40, C1/C5 trip (err > 1) | 0.86, 1.00, C1/C5 trip (err 1.53), unseen 0.12 |

- **No run refused**: all 57 runs of the round exited 0, including every s = 2.0 rung.
- **s = 2.0 is barely coarser than 1.6 in nodes** (dry 184 against 193): the edge nodes and
  fixed nodes do not scale, and most stretches already have one or two intervals at 1.6.
  What s = 2.0 changes is the widest intervals: 198 / 211 / 224 d before b = 20 (160 / 169 /
  168 d at 1.6), and 462 d in 20–25 on episodic-lma.
- **The step 2.0 → 1.6 leaves the square law**, differently per case: on dry the error along
  M stops growing (−0.13 where the law wants about −0.6: the edge-node bias saturates once
  the spell's last stretch is ~200 d), on long-wet it grows faster than the law (order ≈ 3,
  M +0.34), on episodic-lma the whole error grows at order ≈ 2.9. So the (2.0, 1.6) pair
  misreads (C3 fails on dry and long-wet; unseen 0.17–0.27).
- **The wide pair (2.0, 1) still reads s = 1's error** (reads 1.06 / 1.02 / 0.86, corr
  0.95–1.00): its move is dominated by the 1.6 → 1 part, where the law holds roughly. A loop
  that starts at 2.0 and pairs it with the next rung (1.25) is not tested here [i].
- **Widest interval at which the law holds (rule N)**: up to the s = 1.6 rungs, widest
  intervals 160–169 d before b = 20 (and 227–308 d in 20–25), with order 1.5–1.8 and reads
  0.94–1.02 on dry, dry-p50, long-wet; at 198–224 d (s = 2.0) it fails on all three. On
  episodic-lma it does not hold even below 160 d (next section).

### L′ results, episodic-lma (`score_ladder.R N episodic-lma`) [m]

| | episodic-lma |
|---|---|
| nodes / rows x, c, f (E6 c / f) | 129 / 158 / 211, rows 121 / 151 / 207 (E6 120 / 182, rows 112 / 174) |
| committed worst / rms / along M (E6 c) | 1.53 (r_l) / 0.819 / +2.00 (1.28 / 0.678) |
| worst x / f | 2.95 / 0.49 |
| pooled p (1.6/1/0.625), meas/law, cos | **0.92**, 0.63, **1.00** |
| per-quantity order median [min, max] | 0.92 [0.16 root_P50, 3.14 a_l1] (41 readable) |
| coarse pair: read, C3, C1–C5, unseen | 0.72, 31/31, C1 and C5 trip (err > 1), 0.229 |
| fine pair: read, C3, C1–C5, unseen | 1.16, 32/32, C1 and C5 trip, 0.133 |

- One direction (cos 1.00), but the error falls slower than h² from s = 1 to 1/1.6 (order
  0.9) while from 2.0 to 1.6 it falls at order 2.9: the error as a function of s bends,
  steep at the coarse end and flat at the fine end. A part that does not shrink with s
  (fixed strips, or the reference) is the simplest reading [i]; it is ~0.13–0.23 rms by the
  unseen part. Both pairs flag the committed run (C5 trips because the estimate rightly
  exceeds ε), so under the commit rule the case goes to the finer run, as E6 and H1 did.

| # | prediction | P | result |
|---|---|---|---|
| W1 | pooled p (2.0/1.6/1) in [1.6, 2.4] on all three | 35% | refuted (1.95, 2.95, 2.90) |
| W1′ | on at least two | 55% | refuted (dry only, and there cos 0.82) |
| W1″ | (2.0, 1) pair read in [0.7, 1.4] on all three | 45% | holds (1.06, 1.02, 0.86) |
| W1‴ | a run refuses | 10% | did not happen |
| L′3 | episodic-lma committed worst > 1 | 55% | holds (1.53) |

### Pre-registration E (one diagnostic run, before it)

N10r on episodic-lma (fixed strips at 3 d), to test whether the part that does not shrink
there is the fixed strips. **E1.** max |N10r − N10| on episodic-lma ≥ 0.1 (the strips are
part of the offset) — 35%; rms ≥ 0.1 (they are most of it) — 15%.
**E2.** N10r on dry-flat too (93 closing edges, the most strips): max |N10r − N10| ≥ 0.1 —
40%.

### L′ results, dry-flat (`score_ladder.R N dry-flat`) [m]

| | dry-flat |
|---|---|
| nodes / rows x, c, f (E6 c / f) | 311 / 328 / 363, rows 625 / 668 / 752 (E6 191 / 258, rows 384 / 530) |
| committed worst / rms / along M (E6 c) | 0.80 (a) / 0.248 / −0.83 (0.58 / 0.184) |
| pooled p, meas/law, cos | **1.35**, 0.75, 0.89 |
| per-quantity order median [min, max] | 1.93 [0.10 a_l1, 2.76 a_y] |
| coarse pair | read 0.80, **C2 fails** (a_l1 err 0.62, est 0.14; root_P50 err −0.22, est −0.06), C3 5/6, unseen 0.111 |
| fine pair | read 0.92, C1–C5 pass, C3 6/6, unseen 0.056 |

- dry-flat's rows are 1.74× E6's at s = 1 (its 93 closing and 80 opening edge nodes).
- a_l1, the M direction, barely moves from s = 1.6 to 1 (d1 0.19, d2 0.34: order 0.1 on the
  coarse step), so the coarse pair misses it.

### Why the order stays under 2: stretches that do not refine (`stretch.R`; schedule only) [m]

Intervals in each spell's scaled stretch [o + 12, c − 12 d] (spells ≥ 26 d after b1), rule N:

| case | spells | median intervals s = 2 / 1.6 / 1 / 1/1.6 | stretches of one interval | same count 1.6 vs 1 | 1 vs 1/1.6 | 2 vs 1.6 |
|---|---|---|---|---|---|---|
| dry | 28 | 1.5 / 2 / 2.5 / 4 | 14 / 8 / 7 / 6 | 13 | 6 | 21 |
| dry-p50 | 29 | 1 / 2 / 2 / 4 | 15 / 9 / 8 / 7 | 14 | 7 | 22 |
| long-wet | 42 | 1 / 1 / 1 / 1 | 32 / 30 / 27 / 23 | 29 | 25 | 40 |
| dry-flat | 53 | 1 / 1 / 1 / 1 | 50 / 48 / 41 / 35 | 43 | 37 | 49 |
| episodic-lma | 22 | 1 / 2 / 2 / 4 | 12 / 9 / 6 / 5 | 9 | 7 | 14 |

- A stretch's count is ceil(∫ 1/(s·h)), so a spell whose stretch is shorter than one
  interval keeps one interval at every s: its whole layout (o, o + 12, c − 12, c and one
  interval) is fixed, and its error is shared by both runs of a pair. Half of dry's spells
  and 80% of dry-flat's do not refine from s = 1.6 to 1; on dry-flat the error along M sits
  in exactly those spells' closing edges [i], so a_l1 does not move on the coarse step. The
  s = 2.0 rung adds almost nothing for the same reason (21 of 28 dry stretches unchanged).
- So "fixed" in practice is not only the 12-d strips (which err rms 0.015 on dry): it is
  every short spell. The proxy counts those intervals as unchanged, but weights them by the
  pilot's offspring, not by where the M error lives, so the pooled order falls to 1.35–1.56
  where short spells carry the edge-node bias, and stays near 2 on the founders and long
  interiors (per-quantity medians 1.6–2.1) [i].

### U results (`score_ladder.R U dry`, `score_var.R dry`) [m]

| layout (dry) | nodes x / c / f | rows x / c / f | worst x / c / f | pooled p | cos | coarse pair | fine pair | rows at E6's worst / rms |
|---|---|---|---|---|---|---|---|---|
| U (o a node; E6's inset from b = 10) | 124 / 155 / 205 | 168 / 207 / 275 | 1.04 / 0.42 / 0.11 | 1.20 | 0.94 | read 0.91, pass, unseen 0.047 | read 1.21, pass, unseen 0.071 | 216 (1.15×) / 209 (1.11×) |

- **The cheapest variant that keeps both pairs honest on dry is U**: 1.10× E6's committed rows
  at s = 1, 1.15× at matched worst error (N 1.69×), both pairs pass C1–C5 with C3 4/4 and
  5/5. Its pooled order is lower still (1.20): more of the layout is E6's fixed inset, whose
  error the pair does not see but which is small on dry (unseen 0.047 / 0.071, N's 0.048 /
  0.062).

| # | prediction | P | result |
|---|---|---|---|
| U1 | U's pairs both pass with reads in [0.7, 1.4] | 55% | holds (0.91, 1.21) |
| U2 | U's unseen part (fine) ≤ 0.08 | 50% | holds (0.071) |
| U3 | U ≤ 0.9× T's rows at matched worst error | 40% | holds (216 / 268 = 0.81) |

### Pre-registration U′ (U on dry-flat, before its runs)

- **U4.** On dry-flat U's coarse pair passes C1–C5 — 40%; its fine pair passes — 55%; at
  s = 1 its rows are ≤ 1.3× E6's committed (N: 1.74×) — 60%.
