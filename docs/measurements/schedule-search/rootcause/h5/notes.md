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
