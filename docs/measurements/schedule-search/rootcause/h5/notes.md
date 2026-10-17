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
