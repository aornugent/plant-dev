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
