# Hierarchical refinement with central coarsenings (registered before the runs)

Root cause of the plain estimate's shortfall: dropping every other node on a
non-uniform grid merges lopsided panels, whose coarsening reads about 3l of their
error (`docs/measurements/estimate-shortfall.md`). The map on B = bisect(G), dropping
G's midpoints, makes every dropped node central.

Loop (refine_h.R): each pass runs that map; B's estimate is sum(e)/3; stop when
|sum e|/3 < eps/2 and every resident elasticity moved < eps/4; otherwise bisect the
intervals of G carrying 70% of sum|e|. The answer is the last B.

Starts: u108e (108 even introductions less closed-gap nodes, plus the first pass's edges)
and dy (16 nodes over the founders' window, 0.185 yr to year 10, 0.37 yr after, edges
replacing base nodes within half a spacing). Records: episodic and dry.

Predictions:
1. Every pass's sum(e)/3 is within 30% of B's ln J error (or within 0.1 eps when the
   error is under 0.3 eps).
2. The final B is within eps on >= 95% of resident quantities.
3. The final B's rows are below round 3's final rows for the same record.

## Across the bank (registered before the runs)

The same loop and predictions 1-2 on: long-wet (dy start), long drought (dy start, pf
setting: no soil alone, no split), constant (the front-graded start of round 3: u54,
16 nodes over [0, front), nodes every 1/512 day over the front, doubling outward),
and episodic at lma x1.25 (dy start from its own first pass). References: long-wet
u215 + (u429 - u215)/3; long drought pf ld_D u215 + (u429 - u215)/3; constant cF2 +
(cF4 - cF2)/3; lma x1.25 its matrix ladder L1 + (L1 - L2)/3.

## The loop certified by the hybrid coarsening (registered before the runs)

refine_hyb.R: each pass runs the map on H (G plus midpoints where no central drop of G
reaches), stops when H's estimate is under eps/2 (no elasticity guard), else bisects
the intervals of G carrying 70% of |estimate|. Starts dy; records episodic, dry,
long-wet, long drought, episodic lma x1.25.
Predictions: every pass's estimate within 30% of H's ln J error (or 0.1 eps when the
error is under 0.3 eps); the final H within eps on >= 95% of resident quantities; the
final H's rows below the bisection loop's pass-0 rows on each record.

## Result of the hybrid loop, and an elasticity certificate (registered before the runs)

The hybrid loop's ln J estimate was within 0-5% on every pass, but at its ln J stop four of
five settings had elasticities over eps (worst 1.00-1.47; lma x1.25 10 of 48).
Test: every dropped node of H's coarsening C is central, so (C - H)/3 should estimate
each quantity's error. One forward + gradient run on C per pass-0 schedule.
Prediction: per quantity, (C - H)/3 within a factor 2 of H's error for >= 80% of the
quantities whose error exceeds eps/3; and every quantity over eps flagged (estimate
over eps/2).

## Constant: the default ladder plus a front rule (registered before the run)

dyc: node_schedule_times_default's early grading to 0.37 yr spacing, then 0.37 yr;
nodes every 1/512 day over the located front (-0.01 to +0.05 day); spacing graded by
x1.5 outward from the band until it meets the ladder (227 nodes). Same loop (refine_h.R).
Prediction: prediction 1 (estimate within 30% or 0.1 eps) holds from pass 0, and all
48 resident quantities are within eps in at most 3 passes (the front-graded start of
the last round needed 7).
