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

## Lateral probes (13 October), on c05_graded's committed schedule, dry and episodic
- tol 1e-4 and 3e-4 (the schedules' runs use 3e-5): predict every quantity moves under
  ε/3 from the 3e-5 run at 1e-4, with 20-35% fewer rows; at 3e-4 unknown.
- tail edges dropped (b > 20): predict every quantity moves under ε/4 (R(b) ≈ 0 there).
- the 10-20 band thinned to about 170 d: predict moves up to ε/2 in the late-binding
  quantities (a_l1, storage_relaxation_offset, root_P50), off the square law.

## Real runs of a04_proxy (R = 1.6, BG = 90), 13 October
Committed run at 90 d background; check refined by 1.6x everywhere, not nested;
estimate = move / (1 - s), s from the pilot's offspring^0.6 h^3 over both schedules.
Scored T 8384, 99/100 draws. Same ten cases as c05_graded. Predictions as R1-R4 above,
plus R5: the non-nested pair's real jitter keeps C3 on at least 9 of 10 cases (lesson 15
saw a non-nested pair fail C3 on real episodic runs).

## Probe results and the tolerance batch (13 October)
Probes on c05_graded's committed run (dry, episodic):
- tol 1e-4: CPU 0.84-0.88 of 3e-5, quantities move at most 0.06-0.11 eps (rms 0.02-0.03).
  Prediction held.
- tol 3e-4: dry moves up to 0.32 eps; episodic's elasticities came back NaN. Unusable.
- tail edges dropped: CPU 0.88-0.91, moves up to 0.27-0.34 eps (predicted under 1/4:
  failed); worst error fell (0.97 to 0.67, 0.74 to 0.61).
- 10-20 thinned to ~190 d: moves up to 0.77-0.91, worst error 1.65-1.74. The range holds.
So a04_proxy's ten cases now run at tol 1e-4 (the 3e-5 batch stopped after episodic).
Predictions: as R1-R5, with T on the training cases under 8000.

## Tail edges, where they stop mattering (13 October)
Dropping every edge after 20 moved 10-14 quantities by over 0.1 eps, almost all away from
the reference (rms error 0.31 -> 0.33 dry, 0.19 -> 0.22 episodic). Now after 25 and after
30, at tol 1e-4, against the tol 1e-4 base. Prediction: after 30 every quantity moves
under 0.1 eps; after 25 under 0.2.

## Root cause: long drought's sweep refuses at tol 1e-4 (13 October, systematic debugging)
Evidence so far: the throwing function serves both vulnerability curves; x = 256 is
31 MPa on the root curve (420 MPa on the stem curve, which its table would already
have refused). The forward root integral is capped past 7.31 MPa; the sweep's exact
path (closed_form_integral -> cumulative_vulnerability_integral_derivatives_at) has no
cap and refuses past the root curve's P99, 6.89 MPa. Recorded (accepted) states never
pass 5.17 MPa at either tolerance, but the soil moisture floor binds 842 times at 1e-4
against 483 at 3e-5, and the 1000 MPa ceiling 927 against 523: the dry evaluations sit
inside steps.
Hypothesis H1: at 1e-4 an accepted step's internal stage drives a rooted layer past
6.89 MPa; the forward caps the integral and accepts the step; the sweep replays the
stage and refuses. At 3e-5 the accepted steps' stages stay inside.
Test (pinned replay of the step sequence, tolerance swapped):
  A: 1e-4's steps replayed at tol 3e-5 -> H1 predicts the sweep refuses.
  B: 3e-5's steps replayed at tol 1e-4 -> H1 predicts the sweep passes.

## Fixed phylloptim (0.9.2, PHYLLOPTIM-18): long drought at 1e-4

Registered before the runs. The four refused a04t runs (long-drought and ld-105,
c and f schedules) rerun on a lib with the root curve differentiated past its
dry end.

- F1: no run refuses; every quantity is finite.
- F2: forward J is bit-identical to the refused run's (the fix touches only the
  derivative path).
- F3: each quantity sits within ε/3 of the same schedule's 3e-5 run, as the
  other eight cases did at 1e-4 (moves ≤ 0.11ε).

## c05_graded made cheaper (c5t): tolerance 1e-4, edges after 25 dropped

Registered before the runs. Both of c05_graded's schedules lose their edges after
b = 25 (14–35% of nodes, most on dry without season) and run at 1e-4 on the fixed lib.

- K1: all ten cases pass C1–C5 (the nested check does not depend on a model of where
  the error sits, unlike a04's).
- K2: commits as c05_graded did (coarse on nine, fine on lma ×1.25).
- K3: T falls 20–26% from c05_graded at 3e-5 (tolerance 12–16%, edges 6.5–10%),
  so the five training cases sum to 7100–7700 against a04t's 4478 on four.
- K4: the scorer's predicted errors miss the real ones by under 0.1ε rms; its rows
  model, fit at 3e-5, overpredicts by the tolerance's 0.81–0.87.

## a05_fill: the check bisects the wide intervals the ratio leaves alone

Registered before the runs. Root cause of a04's under-read on dry without season: its
ratio check refines that record's background least (band shrinks 0.41 / 0.59 / 0.53 /
0.33 against the founders' 0.41), and the pilot proxy puts 85% of the error in the
founders' window where a four-run fit puts about 25% (residual 0.012ε). a05 keeps a04's
committed schedule and bisects, in each gap the ratio gives no new node, the intervals
wider than half the target (+18 nodes on dry without season, +14 on dry).

- A1: dry without season reads within ×2 on C3 and passes C2; median estimate/error
  0.85–1.1 (a04: 0.69).
- A2: dry is unchanged in verdict (pass) and its median within 0.1 of a04's 1.14.
- A3: on the scorer, T rises about 1% (8473 vs 8384).

## Short shut gaps spanned by one interval (mkmerge.R)

Registered before the runs. Edges are 53–88% of a04's committed nodes, and 16–61 shut
gaps per case are under 10 d. On a04's committed schedule, both edges of each shut gap
under G days go (a node at the gap's centre only where the merged interval would pass
the range): G = 10 keeps 188/213 (dry), 254/356 (dry without season), 173/213 (long
drought); G = 30 keeps 159, 191, 156. Compared with the same schedule unmerged, same
tolerance (1e-4) and lib.

- M1 (G = 10): no quantity moves by more than 0.1ε; rows fall by about the share of
  nodes dropped, weighted to early ones.
- M2 (G = 30): no quantity moves by more than 0.3ε, and the worst error against the
  reference rises by under 0.2ε.
- Mechanism expected: births a few days apart meet the same stand, so one interval's
  interpolation across a short shut gap errs like any interval of its length.

### M1 failed on dry; the shut-gap centre nodes (registered before the runs)

G = 10 on dry moved stem_c by +0.23ε and TF24_cost_scale by +0.16ε (rows −12%). 7 of
its 16 merged gaps had a node put back at the gap's centre, inside the shut gap, which
is the known first-order error of interpolating counted cohorts from a node where
nothing establishes. Variant (KEEP=edge): the same merge, but the node put back is
the gap's later edge. Predicted: on dry no quantity moves by over 0.1ε.

Result: the keep-edge variant moves the same quantities by the same amounts (stem_c
+0.24, TF24_cost_scale +0.17), so the centre nodes were not the cause. Both moves are
away from the reference (stem_c −0.06 → +0.19, TF24_cost_scale 0.46 → 0.62). The G = 30
probes are dropped: G = 10 already costs about what coarsening the spacing by the same
12% would.

Results: M1 holds on dry without season (max move 0.12, rms 0.034, rows −28%) and fails
on dry. The survival-jump mechanism is refuted: |Δ ln offspring| across every short gap
is at most 0.03. A1 and A2 hold (dry without season passes, median 0.85; dry unchanged).

Long drought, G = 10: rows −19.5%, no quantity moves over 0.02ε. Dry is the exception.
Bisection of dry's 16 gaps (registered before the runs): merge only those centred
before 10 (3 gaps) and only those after (13). Expected: one half carries both moves.

Bisection result: the 3 gaps before 10 (at 5.40, 5.42 and 5.64, around a one-day spell
and between 24 and 35 d spells) carry stem_c +0.21 and TF24_cost_scale +0.15 for 6
nodes; the 13 after are running. Next half: the gap at 5.64 alone.

Bisection, last step: the gap at 5.64 alone moves nothing (max 0.03); the 13 after 10
move nothing (max 0.02, rows −7.6%). So both of dry's moves come from the pair at 5.403
and 5.416, which together remove every edge of a one-day open spell, in a region where
the pilot's offspring per founder is 25 times its median after b1. Rule registered
before the runs (SPELLS=1): merge short gaps, but an open spell whose gaps merge on both
sides keeps its start edge. Predicted: dry moves by under 0.05ε; dry without season stays
under 0.12ε with nearly all of its 28% saving.

Result, SPELLS=1 on dry: max move 0.10 (stem_c), rms 0.025, rows −10.8%. The registered
"under 0.05ε" fails: keeping the spell's start edge halves the move but does not remove it.

SPELLS=1 on dry without season: max move 0.04, rms 0.013, rows −24% (plain G = 10:
0.12, −28%). Registered before the runs: SPELLS=1 on long drought moves under 0.05ε;
SPELLS=2 (every spell keeps both edges) on dry moves under 0.05ε.

## a06: a05 without the edges a run does not need (mka06.R)

Registered before the runs. a05's two schedules, both trimmed alike: every edge after
b = 25 goes, and the edges of shut gaps under 10 d under the spell-keeping rule. The
committed schedules keep 53–84% of their nodes (dry without season 53%, episodic 81%).
Separate probes moved quantities by up to 0.08ε (late edges) and 0.10ε (merging); the
check trims the same edges, so it cannot see those errors.

- B1: at least nine of ten cases pass C1–C5 against the references.
- B2: T falls 20–30% from a05 at 1e-4, summed over the ten.
- B3: no case's worst error rises by more than 0.15ε over a05's.

## a07: a05 built on the trimmed edges (any/a07_trimmed.R)

a06 failed C2 on dry without season (stem_c: error 0.51, estimate 0.23); trimming itself
moved stem_c by only +0.05. The cause is the order: a06 trims both of a05's schedules
after building them, so in merged regions the check's ratio and bisection nodes were placed
for gaps that no longer exist, and the band shrinks spread again (0.41–0.51 flat on dry
without season, 0.30–0.51 on dry). a07 trims the pilot's edges first (none after 25, the
short-gap rule) and treats a merged gap and everything after 25 as open, then runs a05:
band shrinks 0.40–0.45 flat on both. Registered before the runs:

- A7-1: ten of ten pass C1–C5.
- A7-2: T within 5% of a06's on each case where a06 passes.

## a07's uniform under-read on long drought; a08 (registered before the runs)

a07 passes long drought but reads 0.65 of the error: every top quantity shrinks by about
0.6 in the check (0.58–0.65) against the proxy's 0.425, with band shrinks 0.39–0.44. A
shrink near 1/R = 0.625 is what a first-order error gives. Nodes inside shut periods are
ruled out (one on long drought). Hypothesis: after 25, where a07 counts everything as open,
intervals span several spells and interpolate across their edges, a first-order error.
a08 keeps the short-gap merge before the build but builds with the late edges and leaves
them out of both runs, as c5t and a06 did. Predicted: long drought reads 0.85–1.2 (median)
and passes; dry without season passes.

Result: a08 reads long drought at 0.66 (a07: 0.65), so the late region is not the cause;
the hypothesis is refuted. The committed errors of a06, a07 and a08 agree (a_l1 0.51,
0.54, 0.53); the checks differ. a06's check (a05's nodes, laid out spell by spell, then
trimmed) takes a_l1 from 0.51 to 0.23, a08's (laid out evenly across the merged spans)
from 0.53 to 0.34, with as many nodes in every band before 25. So a check built on merged
spans refines less of the error per node, and the proxy, which sees only spacing, cannot
tell: the under-read is uniform rather than located. Consistent with error rising toward
each spell's closing edge (`loc/spellpos.R`), not yet tested directly.

a08 on dry without season: pass (13/14), worst 0.97, T 1525 (a07: 1600); long drought T
2118 (a07: 2156). Registered before the other eight runs: ten of ten pass, T 2–5% below a07.
