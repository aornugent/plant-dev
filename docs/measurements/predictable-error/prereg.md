# Late-refined placed ladder (registered before the runs)

Hypothesis: the placed ladder pA -> pA2 -> pA4 (episodic) converges at about first
order because births after b = 16 are spaced 270-540 days. Their water use moves
ln J by 0.3 eps on pA2, and that move does not shrink under bisection (region
ratio 1.07). Everything born before b = 16 converges on the square law (ratios
3.4-5.8).

Test: pAL = pA's nodes before b = 16 plus nodes every 34 days from 16 to pA's
last node; pA2L and pA4L are its nested bisections. Episodic, setting nr, lib_109,
both roles' gradients.

Predictions:
1. ln J move ratio (pAL - pA2L) / (pA2L - pA4L) >= 3.3 (was 2.11).
2. Median ratio over the resident elasticities >= 3.0 (was 1.57); median over
   the invader's >= 3.0.
3. Against the reference u429 + (u857 - u429)/3, (Q_pAL - Q_pA2L)/3 estimates
   pA2L's error with median |est|/|err| in [0.6, 1.5] (was 0.52).
If 1-2 fail, the late spacing is not the cause of the lost order.

## Result, and the second registration (edges as nodes)

Late refinement removed the slow part: pAL/pA2L/pA4L errors 0.55/0.11/0.13 eps
(placed 0.89/0.31/0.14); median move 0.016 then 0.019 eps. The tolerance is not
the floor (a 5% nudge moves the median 0.001 eps). Region maps on pA2L/pA4L:
interior field ratio 4.21, own 3.37; the residue is in regions straddling a
creation-window edge (net +0.0044 -> -0.00003, terms changing sign).

Hypothesis: fate has a corner at each window edge (the closed gap's cohorts do
better the later they are born, up to the opening; each later arrival after it
does worse), and an interval that straddles an edge interpolates the counted
cohorts' fate from a node in the closed gap, with an error set by where the
edge falls inside the interval.

Test: L1e = pAL plus a node at every edge (rate crossing 0.01 in pA4L's creation
record, 0 < b < 40); L2e, L4e its nested bisections.
Predictions:
1. ln J move ratio (L1e - L2e)/(L2e - L4e) >= 3.0, and median resident elasticity
   move ratio >= 3.0, with <= 15% negative.
2. The (L1e, L2e) estimate of L2e's move to L4e, (Q1 - Q2)/3 against Q2 - Q4,
   has median ratio in [0.6, 1.5].
