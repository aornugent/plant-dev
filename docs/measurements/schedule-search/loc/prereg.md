# Pre-registration: one pass of map-ranked batch bisection (dry, episodic), 12 October

G0 from mkG0.R (edges; open gaps cut into an even number of equal intervals, at most
b1/16 before b1 and 80 d after). G0 runs with the map on, dropping every other node of
each gap (C0). Panel p's move m_p = own + field part of ln J(C0) - ln J(G0) at that
drop. G1 bisects both intervals of the fewest panels carrying s = 0.75 of sum |m_p|.
G1 runs with the map on, dropping G1's new midpoints.

Predictions, errors in each quantity's eps against the training references:
P1. ln J(G1) - ln J(G0) = sum over chosen panels of m_p / 4, within 20%.
P2. Quantities with |err(G0)| > 1/3: median |err(G1)| / |err(G0)| in [0.3, 0.6]
    (a quarter of the error left in chosen panels, plus the unchosen share).
P3. Each quantity's estimate for G1, (Q(G0) - Q(G1)) / 3, is within x2 of err(G1)
    for at least 80% of quantities with error or estimate over 1/3.
P4. rows(G1) <= 1.35 rows(G0); rows(G0) within 10% of lattice (16, 70)'s.
P5. Every quantity of G1 within eps on both records.
Falsified: P1 off by more than 20% means the map's ranking cannot be trusted for
placement; P2 above 0.6 means J's ranking misses the elasticities' error.

## rooting_depth_max (13 October)
Its error moves by 0.5 eps between schedules with the same founders' nodes on dry
(G0 +0.48, lattice (16, 70) -0.02), and not by the square law. Hypothesis: only cohorts
whose roots reach the cap carry this elasticity, so its integrand has a kink in birth
date where cohorts start or stop reaching the cap. Test: the elasticity's map on dry's
G0 from map runs at rooting_depth_max x(1 +- 0.02). Prediction if right: most of
sum|map| sits in a few panels around one or two birth dates, which move between records;
if wrong, it is spread like J's map.
Map result: 3 of 84 panels carry half of sum|map| (births 0.22, 0.66 and 8.04; the last
with J's map near zero), and the +-2% central difference of ln J (0.0247) differs from
the sweep's elasticity (0.0289) by 17%, 0.4 eps. Next: ln J on G0's own steps (pinned)
at rooting_depth_max x(1+u), u in {-2,-1,-0.5,-0.2,0.2,0.5,1,2}%. Prediction if J has a
kink in this trait near u = 0: one-sided slopes differ by more than 10% between u < 0
and u > 0 and agree within each side; if smooth curvature: slopes change linearly in u.

## Real runs of structure c05_graded (13 October)
The algorithm reads everything from the pilot: founders' first-mover layer at b1/24
until the pilot's offspring falls 10-fold, the quiet middle at b1/12, an 85 d background
widening with the pilot's offspring, up to the scorer's range; check = halve every
interval wider than half its target; commit the coarse run if 4/3 of the move is under
eps everywhere, else the fine run with a third of it. Scored (NOISE=2, rooting_depth_max
set aside) at T 9126, 40 of 40 draws. Real runs on the five training cases and five
held-out cases (dry without season, long drought seeds 102 and 105, dry root_P50 x1.2,
long-wet a_dG2 x1.25), against their extrapolated references. Predictions:
R1. Every committed answer within eps on every quantity but rooting_depth_max (C1).
R2. C2, C3 (one miss allowed under five) and C5 hold on at least 9 of 10 cases.
R3. On training cases each run's errors match the scorer's within 0.15 eps rms.
R4. Real cost (rows) within 10% of the scorer's rows model.
