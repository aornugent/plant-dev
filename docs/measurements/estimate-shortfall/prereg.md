# A cheap start and an elasticity guard (registered before the runs)

Where L0's error sits (where.R, fine.R): births in years 0-2 earn 75-90% of J,
and L0 has 3 nodes there (0, 0.74, 1.48). The founders' window, up to the first
closing at 3.0-3.7 yr, carries 70-95% of the L0 -> L1 move on episodic, dry,
long-wet and episodic lma x1.25; elsewhere the moves fall near four-fold.

Start rule s16: L0 plus 16 even nodes over [0, b1), b1 the first closing in the
first pass's creation record (+15 nodes on each case).

Loop: refine.R as round 2, plus GUARD=2: stop only when sum|e|/3 < eps/2, ln J
moved < eps/4 and every resident elasticity moved < eps/4 since the last pass;
at most 6 passes after the first.

Cases: episodic, dry, long-wet at theta0; episodic lma x1.25.

Predictions:
1. The final pass is within eps on >= 95% of resident quantities (recruitment_decay
   excluded), including lma x1.25.
2. Its rows are below round 2's final rows (833k, 1471k, 1660k, and lma x1.25's
   L2 1086k), counting only the final pass.
3. sum(e)/3 is within a factor 2 of the final ln J error.
4. The summed rows of all passes are below uniform L2's rows.

Also reported: what round 2's passes would have done under the guard (guardcheck.R:
it would have continued on every case, with moves of 0.29-0.56 eps on the theta0
cases already within eps), and what a guard of eps/2 would have done.

## Added before any result: the default's shape in the founders' window

node_schedule_times_default concentrates nodes early on the same principle (nodes
where J is earned), but grades them geometrically toward b = 0 (60 of its 108
nodes before 0.1 yr, 85 before 3 yr). Start rule dft: L0 plus the default's nodes
over [0, b1). Same loop, on episodic and dry. The comparison with s16 asks whether
the founders' window needs grading toward birth or only even resolution.
Prediction: dft reaches eps in no fewer passes than s16 and with more rows.

## Round 3b (registered after s16's first passes, before its own runs)

s16's first passes under-report (episodic: estimate -0.94 eps against -2.04; lma x1.25:
-0.04 against -1.47). predchk2.R splits the map's prediction for the bisected
panels against the measured move: the own part is predicted within 10% on every
case; the field part only where late births are 0.37 yr apart (round 2's L1:
+0.0135 vs +0.0136 episodic, +0.0073 vs +0.0075 dry). With L0's 0.74 yr late
spacing it is 2.5-8.6x too small (s16 episodic +0.0167 vs +0.042; lma x1.25
+0.0021 vs +0.018). The fate in the founders' window is smooth (dense scans,
nodes every 1/128 yr: near-exponential in b, decay length about 0.75 yr).

Start rule u108e: 108 even introductions less closed-gap nodes, plus the first
pass's edges (the same 54-node first pass). Same loop (GUARD=2, KMAX=6).
Cases: episodic, dry, long-wet at theta0; episodic lma x1.25.
Predictions: as round 3's 1-4; and pass 0's sum(e)/3 within a factor 2 of its
ln J error.

## Root-cause test: seasonal structure in birth date (registered before the runs)

Findings so far (rc/): the map predicts C - P to 1%; 4/3 (P - B) equals the error
to 1-5% (bisection honest); (C - P)/(P - B) is 1.3-2.1, not 4. The deficit is in
late panels spanning 160-400 days, mostly through soil. In the most-missed panel
(7.985-8.519) E depends on where a single node sits (-0.042 at 8.10 to +0.008 at
8.37, crossing zero), identically at a tenth of the tolerance; fate and early size
are smooth, with one corner at the dry-break pulse (adding 44 such onsets moved
the error by 0.001 eps). The record is seasonal (amp 0.8, wet peak mid-January).
Hypothesis: uptake trajectories depend on season of birth, a one-year period in
birth date; u108's 0.37 yr spacing samples it 2.7x a year (pre-asymptotic),
its coarsening 1.35x (aliased).
Test: P3s = pass 3 with open intervals born in [3.7, 20] split to <= 1/16 yr.
Prediction: (Cs - P3s)/(P3s - Bs) within [3, 5] and (Cs - P3s)/3 within 30% of
4/3 (P3s - Bs).
