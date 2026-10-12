# Refinement with central coarsenings across the bank

`estimate-shortfall.md` traced the drop map's low estimate to the coarsening's geometry:
- dropping every other node on an edge-aligned grid merges lopsided panels;
- such a panel's move reads about 3l of its error, for a dropped node at fraction l of
  its panel.

This round's loop (`central/refine_h.R`) coarsens only to central nodes. Each pass runs
the map on B = bisect(G) and drops exactly G's midpoints. So e_i is the move of G's
interval i to its halves, and B's error is Σe/3. The loop stops when |Σe|/3 < ε/2 and
every resident elasticity moved less than ε/4. Otherwise it bisects the intervals of G
that carry 70% of Σ|e|, and the answer is the last B.

The prediction was registered before the runs (`central/prereg.md`).

## Starts

- **u108e:** 108 even introductions, less those born while establishment is shut, plus
  the first pass's edges.
- **dy (snapped dyadic):**
  - 16 nodes over the founders' window, 0.185-year spacing to year 10, 0.37 after;
  - each edge replaces any base node within half a spacing;
  - for episodic lma ×1.25, built from that setting's own first pass.
- **constant:** the front-graded start of `refinement.md`:
  - 54 even nodes, plus 16 over [0, front);
  - nodes every 1/512 day across the front, with spacing doubling outward.

Long drought runs at the `pf` setting.

## Results

Errors are in ε of each quantity, against the references of `refinement.md`.
"Worst" is the worst of 48 resident quantities, `recruitment_decay` excluded.

| record | start | pass | B nodes | rows | ln J error | estimate | worst |
|---|---|---|---|---|---|---|---|
| episodic | u108e | 0 | 347 | 843k | −0.192 | −0.185 | 0.41 |
| | | 1 | 377 | 973k | −0.086 | −0.073 | 0.22 |
| episodic | dy | 0 | 321 | 870k | −0.229 | −0.220 | 0.44 |
| | | 1 | 343 | 957k | −0.108 | −0.092 | 0.20 |
| dry | u108e | 0 | 457 | 1604k | −0.050 | −0.063 | 0.50 |
| | | 1 | 477 | 1736k | −0.096 | −0.103 | 0.35 |
| dry | dy | 0 | 415 | 1583k | −0.109 | −0.126 | 0.29 |
| | | 1 | 447 | 1779k | −0.066 | −0.080 | 0.24 |
| long-wet | dy | 0 | 409 | 1849k | +0.001 | +0.004 | 0.30 |
| | | 1 | 431 | 2007k | −0.022 | −0.021 | 0.11 |
| long drought | dy | 0 | 421 | 2998k | −0.035 | −0.031 | 0.28 |
| | | 1 | 449 | 3308k | −0.033 | −0.036 | 0.22 |
| episodic lma ×1.25 | dy | 0 | 293 | 750k | −0.169 | −0.169 | 0.53 |
| | | 2 | 391 | 1110k | −0.028 | −0.036 | 0.13 |
| constant | front-graded | 0 | 239 | 370k | −0.037 | +0.112 | 4.19 |
| | | 2 | 243 | 362k | −0.081 | −0.007 | 4.89 |
| | | 4 | 251 | 375k | −0.018 | −0.010 | 1.61 |
| | | 6 | 265 | 402k | −0.002 | −0.002 | 0.54 |

**Prediction 1** (each pass's Σe/3 within 30% of B's ln J error, or within 0.1ε when
the error is under 0.3ε) **holds on every pass of every record except constant's
passes 0 and 1.** It held on all five pulsed settings, where the estimate was within
0–26% of the error. Before, the estimate read 1/2 to 1/3 of it.

**Prediction 2** (the final B within ε on at least 95% of quantities) **holds
everywhere.** On every pulsed setting all 48 quantities were within ε from the first
pass.

**Prediction 3** (fewer rows than round 3) **fails.** The honest estimate runs on the
bisection, which costs twice the rows of the schedule it certifies. On episodic:
- this loop: 957–973k rows;
- round 3: 466–584k rows, but with estimates that read 1/2 to 1/3 of the error.

**The elasticity guard costs a pass on pulsed records.** Every pulsed case was within
ε, with an estimate under ε/2, at pass 0. The guard (elasticities moved under ε/4)
forced pass 1.

**Constant rain's first passes misread.**
- At passes 0 and 1 the estimate has the wrong sign (+0.112 against −0.037, +0.049
  against −0.113).
- The race traits' elasticities (a_l1, up to 6.7ε) need six passes.
- So the front-graded start is not in the asymptotic range at the bisection level near
  the front.

## A cheaper certificate: the map on G with central drops only

`central/mkcentral.R` drops, from G itself, only nodes that:
- are not edges;
- have both neighbours kept;
- sit at l in [0.35, 0.65] of their panel.

Truth is G's error per interval from the map on B (`censcore.R`).

| G | G's error | held by covered panels | estimate on covered panels | coverage of birth dates |
|---|---|---|---|---|
| episodic u108e, pass 1 | −0.291 | −0.230 | −0.242 | 63% |
| dry dy, pass 1 | −0.320 | −0.199 | −0.241 | 62% |

- The covered panels are honest (5% and 21%).
- The uncovered ones hold 21% and 38% of the error, and nothing reads it. These are
  intervals between two protected nodes or too lopsided to drop.

**Hybrid certificate** (`central/mkhybrid.R`, `hybscore.R`).
- H = G plus the midpoints of the uncovered intervals.
- Its coarsening drops G's central nodes and those midpoints, so every dropped node is
  central.
- The estimate is Σ e·g(l) over the central drops plus Σ e/3 over the midpoints.

| record (G from pass 1) | H nodes / G | H rows | B rows | H's error | estimate |
|---|---|---|---|---|---|
| episodic u108e | 1.50 | 695k | 973k | −0.260 | −0.257 |
| dry dy | 1.56 | 1316k | 1779k | −0.215 | −0.272 |
| long-wet dy | 1.61 | 1540k | 2007k | −0.026 | −0.013 |
| long drought dy | 1.63 | 2581k | 3308k | −0.073 | −0.078 |

- The estimate is honest on all four: within 1–26%, or within 0.013ε where the error
  is small.
- It costs 22–29% fewer rows than certifying with the bisection.

## Open

- The hybrid certificate inside the loop.
- Stopping without the elasticity guard when pass 0's estimate is under ε/2.
- Constant's front at the bisection level.
- Invaders: not yet scored on these schedules.
