# Root cause of root_P50's misread certificate (registered before the runs)

Symptom: on the hybrid schedule H, (C - H)/3 reads root_P50's resident elasticity error
with the wrong sign on episodic (+0.37 eps, estimate -0.10) and dry (+0.54, -0.37).
Evidence so far (ladders.R): eps is 0.0108; uniform ladders move erratically (dry
-0.0030, -0.0026; episodic +0.0033, -0.0004, -0.0004); the uniform and edge-aligned
references differ by 0.12-0.17 eps; C is not consistently farther from the reference
than H.

Hypotheses, each with its test:
H1 (closings). root_P50 acts when the soil is dry, where the stand's uptake shuts the
   windows; closings move with the grid (median 0.5 d), so the elasticity carries a
   term from the closings' shift that does not follow the square law.
   Test: central differences in root_P50 (+-2%) of ln J on C, H and bisect(H) for dry
   (forward runs); split each move of the elasticity (C -> H, H -> BH) by birth region
   (founders, within 10 days of a closing, other late births) with panel_moves.
   Prediction if H1: the closing regions carry most of the move and their ratio of
   successive moves is far from 4, while other regions are near 4.
H2 (reference). The references themselves are not converged for root_P50 to better
   than ~0.3 eps. Test: the spread of the finest schedules' values (edge ladder L2,
   bisection-loop passes, u429) against eps.
H3 (time error). root_P50's gradient is sensitive to the ODE tolerance. Test: H at a
   tenth of the tolerance (forward + gradient).

## Round 1 result, and round 2 (registered before its runs)

Round 1: the elasticity's moves alternate (C -> H +1.17 eps, H -> BH -0.31). H3 rejected
(a tenth of the tolerance moves it 0.034 eps). H1 rejected (births near closings carry
+0.23 and +0.02). The sign flip is in the field part acting on the founders (+0.77 then
-0.32); late births carry +0.43 of the coarse move and 0.004 of the bisection's.
Hypothesis H4: the coarse schedule's late spacing is outside the asymptotic range for
the field's sensitivity to root_P50; the founders' own spacing is not.
Test: partial coarsenings of H (central drops only among late births, b > 3.529, or only
among founders) and partial bisections (late only, founders only), each with +-2%
central differences.
Prediction if H4: the late-only coarsening's move is far from 4x the late-only bisection's
(or of opposite sign), and the founders-only pair is near 4.

## Round 2 result, and round 3 (registered before its runs)

H4 confirmed: late births carry the whole anomaly (coarsening +1.04 eps against bisection
-0.32, ratio -3.26); founders converge by the square law (+0.12 against +0.03, ratio 4.2);
the parts add up.
Round 3: is the bisected late spacing asymptotic? Halve the late intervals again
(BH2late). Prediction if the bisected level is asymptotic: the move BHlate -> BH2late is
-0.08 eps (a quarter of -0.32) within a factor 2.

## Round 3 result, and round 4 (registered before its runs)

The late-only ladder moves +1.04, -0.32, -0.15 eps (ratios -3.26, 2.12): first order even at
fine late spacing, which points to a kink in birth date. H1 refined (H1'): root_P50 sets
when uptake shuts each window; the closing nodes come from the first pass and sit about
half a day from the closings of H's own run, so the elasticity carries a corner's
derivative term, first order in the spacing.
Test: move each first-pass closing node of H to the nearest closing of H's own run and
repeat the late ladder (late-only coarsening, H, two late-only halvings), +-2% central
differences.
Prediction if H1': the realigned ladder's ratios are near 4 (within [2.5, 6]) and the
realigned H's move to its late halving is under half the original's (0.32 eps).

## Round 4 result, and round 5 (registered before its runs)

Realigning the closings to H's own run leaves the ladder unchanged (+1.06, -0.29, -0.18
eps; ratios -3.71, 1.63): H1' rejected.
H5 (moving corner): AD differentiates the quadrature with the nodes fixed. Where a trait
moves an edge, the trait derivative of fate jumps at the edge (fate itself has a
corner), so linear interpolation across it errs at first order in the spacing next to
the edge, wherever the node sits. root_P50 moves openings and closings through the soil
water at which a newborn's net production crosses zero.
Test: bisect only the late intervals touching an edge (once, Hea; twice, Hea2), or only
those touching none (Hna); +-2% central differences.
Predictions if H5: H -> Hea carries most of H -> BHlate (-0.32 eps); Hea -> Hea2 is about
half of H -> Hea (first order); H -> Hna is small (under a third of -0.32).

## Round 5 result, and round 6 (registered before its runs)

Round 5: H -> Hea -0.54 eps, Hea -> Hea2 -0.28 eps (ratio 1.93); H -> Hna +0.24 eps. H5
holds: the first-order part sits beside edges.
Finding before round 6 (side/side.R): on H's own +-2% runs, the node nearest each late
root sits on the shut side of it for 92 of 137 roots (+2%) and 123 of 136 (-2%). The
pilot's edge rule (the end of the last step above 0.01, or the start of the first)
lands past a closing's root and before an opening's. Round 4's realignment used the
same rule, so it moved nodes from one shut-side place to another.
H6: the first-order part comes from nodes on the shut side of a root lending their
fate, and its trait derivative from the other branch, to births on the open side. A
node inside the open window by a margin larger than the root's travel leaves the
corner where the count is near zero, and the square law returns.
Test: Ho = H with each edge node moved inside its window: a closing to 0.5 d before
the earlier start of the root's step in the two +-2% runs, an opening to 0.1 d after
the later end. Hoea and Hoea2 as Hea and Hea2 (bisect late intervals touching an edge
node, then those halves again). +-2% central differences.
Predictions if H6:
1. On Ho's own +-2% runs, at least 95% of late edge nodes are on the open side.
2. Ho -> Hoea and Hoea -> Hoea2 for root_P50 have a ratio in [2.5, 6], and
   |Ho -> Hoea| is under half of |H -> Hea| (0.27 eps).

## Round 6 result, and round 7 (registered before its runs)

Round 6 (score6.R): 122 of 123 edge nodes of Ho sit inside an open stretch on both of
Ho's +-2% runs (prediction 1 holds), yet the ladder is unchanged: Ho -> Hoea -> Hoea2
moves -0.461, -0.249 eps (ratio 1.85) against -0.536, -0.278 (1.93). Prediction 2
fails: H6 rejected. Which side of the root the node sits on is not the lever.
What stays: the first-order part sits in the intervals touching an edge (round 5).
H7: it sits in a layer of a few days beside the edge on the open side (the closing
ramp, 1.7-9 d, or fate's peak after an opening), narrow against the 30-70 d spacing,
so it converges at first order until the spacing reaches the layer.
Test: Ho plus graded nodes inside each window beside its edge node; closings (Hoc):
0.25, 0.5, 1, 2, 4, 8 d before; openings (Hoo): 0.1, 0.25, 0.5, 1, 2, 4, 8 d after;
each kept only inside its window. +-2% central differences.
Ho's ladder extrapolated at first order puts root_P50 at -1.3301 (Ho + 2 x (Hoea - Ho)).
Predictions if H7: Hoc or Hoo, or the two together, move root_P50 from Ho by at least
two thirds of that (-0.61 eps or beyond); the other moves it by under a third.

## Round 7 result, and round 8 (registered before its runs)

Round 7 (score7.R; collars classified by the nearer shut step, 51 closings and 72
openings). From Ho, root_P50 moves:
- Hoc (+293 nodes, up to 8 d before closings): -0.420 eps, ln J +0.078 eps;
- Hoo (+484 nodes, up to 8 d after openings): -0.023 eps, ln J +0.018 eps;
- Hoea (+244, edge-touching intervals bisected): -0.461 eps, ln J +0.383 eps.
The prediction (at least -0.61 eps, two thirds of Ho's first-order limit -0.92) fails
as registered. But openings carry none of it, and the layer before closings carries what
the first bisection does at a fifth of its effect on ln J.
H8: root_P50's first-order part lies in births before a closing, over a layer wider
than 8 d.
Test: Hocw, Hoc with nodes also at 12, 16, 24, 32 d before each closing; Hocd, Hoc with
nodes also at 0.125, 0.375, 0.75, 1.5, 3, 6 d (finer within 8 d). +-2% central
differences.
Predictions if H8: Hocw moves root_P50 from Hoc by at least -0.2 eps (towards the
limit, -0.50 eps from Hoc), and Hocd moves it under a third of Hocw's move.

## Round 8 result

From Hoc, Hocw moves root_P50 -0.272 eps (ln J +0.117) and Hocd +0.005 eps: H8 holds.
Hocw sits -0.692 eps from Ho against the first-order limit -0.922; Hoea2 (819 nodes)
sits at -0.710. On Hocw's +-2% runs, fate (nrr), its root_P50 derivative and
cumulative mortality are smooth in birth date over the 60 d before closings
(profile.R), so the part these nodes resolve acts through the stand's environment,
not through the fate of the births themselves.

## Round 9 (registered before its runs)

parts.R splits each grid's root_P50 elasticity into births' counts and fates, for
founders (b < 3.529) and late births, with J = k sum(w_i nrr_i) (k common to every run
within 0.05 eps). Along H's ladder the founders' fate carries the first-order move:
-0.465 then -0.215 eps (ratio 2.16); the late births' own counts and fates move by
under 0.07 eps. From Ho: Hoea -0.414, Hoea2 -0.611, Hoc -0.325, Hocw -0.540 eps in the
founders' fate. So the error enters through the environment the late births make, and
acts on the founders.
H9: it enters through the soil (not light), from late panels before closings.
Test: the field-adjoint map on Hoea with its coarsening Ho, at root_P50 +-2%; the
difference of the two maps over 0.04, divided by J, is each dropped node's field part
of the elasticity move Hoea -> Ho, by channel (light, soil) and by age band after birth.
Predictions if H9: the map's field total is within 30% of the measured founders'-fate
move (+0.414 eps); soil carries at least 80% of it; the panels within 32 d before a
closing carry most of it.

## Round 9 result, and round 10 (registered before its runs)

Round 9 (score9.R). On the map's build, el(Ho) - el(Hoea) measures +0.461 eps; the map
predicts +0.484 (own -0.046, field +0.530: light -0.055, soil +0.585). The soil part
acts 10-20 years after the dropped births (+0.496 of it). It is not concentrated before
closings (+0.15 within 32 d of one, +0.26 over 90 d away). It is concentrated in a few
panels with alternating signs: the dropped node at 12.033 alone carries +0.353, its
neighbours 12.403 and 11.305 -0.09 and -0.08. H9 holds for the channel (soil) and fails
for the place.
AD check: Hoea's AD elasticity is -1.258 at +2% and -1.409 at -2%; the central
difference (-1.325) is within 0.8 eps of their mean (-1.334). root_P50's curvature in
ln J is large (about 3.8), like lma's.
H10: cohorts born on either side of some birth date b* behave differently in the soil
years later (one side reaches a switch, the other does not), so the stand's uptake has
a kink in birth date at b*(t, theta). The quadrature of uptake is then second order in
J but first order in its theta derivative, as b* moves.
Test: a local ladder in Ho's two intervals around 12.033 ([11.845, 12.587], 137 and
134 d): L1 adds their midpoints, L2 quarters, L3 eighths, L4 sixteenths (8.5 d).
+-2% central differences.
Predictions if H10: (1) the moves L0 -> L1 -> L2 -> L3 -> L4 fall with ratios near 2,
not 4; (2) on L4 some per-node quantity at the run's end (cumulative mortality, height,
or its root_P50 derivative) changes slope sharply at a birth date in the window, and
the moves concentrate in the panels next to it.

## Round 10 result, and round 11 (registered before its runs)

Round 10 (score10.R): the local ladder around 12.03 moves root_P50 -0.239, -0.065,
-0.031, -0.010 eps (ratios 3.68, 2.07, 3.08); ln J +0.075, +0.018, +0.005, +0.001.
Near the square law; no kink: fate, height, mortality and their root_P50 derivatives
are smooth over 8.4-day nodes. H10 rejected. But the root_P50 derivative of fate
swings by +-0.1 within the 0.74 years shown.
period.R, on Hoea2: the late births' d ln nrr / d ln root_P50 has its dominant period
at 0.99 years, sd 0.29 about a level of -1.18. The dry record's rain is seasonal:
1.06 mm/d in the first month, 0.05 in the seventh.
H11: the trait derivative of late births' fate and uptake swings with their season of
birth. Late spacing of 0.37 years (under three nodes a year) under-samples that annual
cycle, so refinement is pre-asymptotic until the spacing is a small fraction of a
year. J's integrand swings far less, so J converges by the square law.
Test: one founders' grid (H's nodes before 3.529), then uniform late spacing of 0.37,
0.185, 0.0925 and 0.046 years, on dry and on dry-flat (the same record generator at
season amplitude 0). +-2% central differences.
Predictions if H11: on dry-flat the late ladder's ratios are within [2.5, 6] from the
first halving; on dry the first ratio is outside [2.5, 6] and the ratio reaches it
only once the spacing is 0.0925 years or finer.

## Round 11 result, and round 12 (registered before its runs)

Round 11 (score11.R), late-uniform ladders (0.37, 0.185, 0.0925, 0.046 y), no edge nodes:
- dry: root_P50 moves +0.850, -0.246, -0.058 eps (ratios -3.46, 4.21); ln J +0.073,
  +0.178, +0.050.
- dry-flat: +0.366, -0.378, -0.180 eps (ratios -0.97, 2.10); ln J +0.344, +0.210,
  +0.069.
H11 rejected: without its season the record converges no better.
Every ratio so far is of a total over all intervals, a sum of signed parts. H12: each
interval's part follows the square law once resolved, and the totals' ratios near 2
come from parts of opposite sign that reach the square law at different spacings.
Test: the field-adjoint map at +-2% on BHlate (coarsening H) and on BH2late
(coarsening BHlate), the all-late bisection ladder of round 3 (ratio 2.1). For each
late interval i of H: m1_i, the predicted move of dropping its midpoint; m2_i, the sum
for dropping its two quarter points.
Predictions if H12: (1) the map's totals match the measured moves (-0.32, -0.15 eps)
within 30%; (2) over intervals with |m1_i| above 0.02 eps, the median of m2_i / m1_i
is within [0.15, 0.35] (square law 0.25); (3) sum(m1) / sum(m2) is near 2 because
positive and negative parts differ in ratio, not because a typical interval's ratio
is 0.5.

## Round 12 result

Map totals -0.348 and -0.154 eps (measured -0.32, -0.15). Over the 17 intervals with
|m1| > 0.02 eps the median m2/m1 is 0.231 (quartiles 0.198, 0.260). Positive parts:
+0.566 then +0.070 (ratio 8.1); negative: -0.913 then -0.224 (ratio 4.1); sum |m1|
1.479 against |sum m1| 0.348. H12 holds. Intervals over 110 d: 4 of 15 off the square
law, carrying 0.81 of 1.48 eps of |m1|; 45-80 d: none of 10.
