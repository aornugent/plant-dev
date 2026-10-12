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
