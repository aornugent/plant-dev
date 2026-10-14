# Agent G, round 4: let the data speak

Scope note (lead, mid-task): the reverse sweep's own per-row cost is deferred; do not
propose optimising the sweep itself.

## 1. Index (index.R)
988 saved runs over four directories, 744 with a gradient. Cost: forward CPU =
1.11e-4 s/row + 2.4e-3 s/step (R² 0.99); sweep = 3.56e-4 s/row + 2.6e-3 s/step
(sweep/forward median 3.0, range 2.35–3.79). Rows dominate both: a step costs about
22 rows of overhead in the forward, 7 in the sweep.

## 2. Errors side by side (errs.R, look1.R, look2.R)
450 gradient runs on the ten cases, error per quantity / eps against each case's reference.
- 234 val runs at 1e-4 (5 blown/NaN set aside). The binding quantities are few: a_l1 (p90
  0.87ε), a (0.57), storage_relaxation_offset (0.55), curv_fact_elec_trans (0.54), k_I,
  vcmax_25, jmax_25. 11 of 47 quantities never exceed ε/3 in any val run; ln J's max is
  0.39ε (it never binds, as known).
- Per case, the worst quantity is nearly always the same one: dry a_l1 24/25, long-wet
  `a` 22/22, wet-adG2 `a` 20/20, ld-105 `a` 23/24, episodic-lma vcmax_25 18/20.
- Within a case, the signed error vectors of 28–73 different schedules are one shape:
  the first singular direction carries 78–99% of the sum of squares, two carry 95–100%.
  Across cases two shapes recur: a light-response group (a, curv_fact_elec_trans, k_I,
  jmax_25 move together; cosine 0.81–0.95 among dry, ld-105, long-drought, long-wet,
  wet-adG2) and a_l1 (episodic, dry-p50, ld-102). So the schedule error is close to a
  scalar per case times a fixed direction.

## 3. Where steps and rows go (look3–look7.R)
- Rows ≈ Σ over accepted steps of the nodes alive (matches saved rows to 1%).
- **36–42% of every run's rows are spent after patch age 25, 20–28% after age 30**, on all
  ten cases (a09, committed and check), where patch survival is under 2.3% and 0.43%.
- **The rainfall knots set the late step count.** adj_run.R passes every active knot (a
  day bordering a rain day; 65–74/yr on dry, long-wet, long drought; 24/yr episodic) as a
  zero-depth pulse, so every knot ends a step. On dry the median step is exactly 1.00 d
  in every age band; after age 25, 65–83% of steps end on a knot, though the window
  weight has loosened the tolerance ×2–100 there. In the proper setting the knots are
  46–53% of steps and 50–56% of rows on dry, long-wet, long drought, dry-p50, ld-102/105
  (26–29% on episodic). After age 25, knot-ending steps hold 23–31% of all rows on the
  rain-frequent records (15% episodic), and 1-day knot-to-knot steps 17–27% (8%).
- Free (non-knot) steps answer to tolerance (3e-4: ×0.17–0.70 by band); knot steps do not.
  The constant record (no knots) at 3e-5 takes 31–43 steps/yr after 25 against dry's
  98–117 at 1e-4. design-grid-controller.md commits to "the knots stay step targets,
  which land steps rather than shorten them": on rain-frequent records consecutive daily
  knots do shorten them, to one day.
- Assumption 12 inverted for cost: long-wet costs more steps than dry (6638 vs 5584); cost
  follows rain frequency (knot density), not drought.

## Pre-registered (before G1)
G1: dry, a09's committed schedule, lib18 and TOL=1e-4 as val_a09_c_dry, knots kept only
before age 25 (KNOT_MAX=25). Predict: steps after 25 fall from ~1470 to ≤ 700; rows
−15 to −25%; every quantity within 0.15ε of val_a09_c_dry, ln J within 0.05ε.

G1 result: steps 5585 → 4910 (after 25: 1476 → 801), rows −18.8%, forward CPU −19%, sweep
−25% (machine load differs). Cost prediction holds. **Accuracy prediction fails:** moves
up to 0.73ε (TF24_cost_scale −0.73, root_P50 +0.51, a_r1 +0.48, a_l1 −0.31, a_st1 −0.31),
rms 0.23ε, ln J −0.05ε; no blow-up (max |el| 93.95 against 93.79). Against the reference
some errors shrink and some grow (root_P50 0.47 → 0.98). So the late region's accuracy
does reach the hydraulic/root elasticities, and with the window weight at ×100 there the
knots were what held it: the window weight was tuned on runs whose late steps the knots
pinned at one day.

G2 (pre-registered): as G1 with WEIGHT_MAX=10 (late tolerance at most ×10). Predict: if
the moves are the loose late tolerance, every quantity within 0.2ε of val_a09_c_dry and
rows −8 to −15%; if they are knot-straddling error the step control cannot see, moves
stay ≥ 0.4ε.

G2 result: rows −12.0%, steps after 25: 1476 → 1043. Prediction fails the other way:
tightening the late tolerance moved the answer MORE: ln J −0.40ε (J 1.18936 → 1.17923),
TF24_cost_scale −1.52ε, a_r1 +1.20, stem_P50 +1.03, r_r/r_l −0.98; rms 0.67ε. The
accepted steps before b = 24.90 are bit-identical to the base run, so the whole move
comes from integrating ages 24.9–40. The references (node_rule/ladder u215/u429, and the
held-out ref_* runs) use the same window weight (rule_A, WEIGHT_MAX=100), HMAX and knots,
so any bias of the late loose tolerance is shared by every run and every reference and no
check can see it.

G3 (pre-registered): base dry committed schedule with all knots and WEIGHT_MAX=10.
Predict: ln J within 0.1ε of G2 (the move is the late tolerance, not the knots), rows
+3 to +15% over base.

G3 result: with every knot kept, capping the late weight at 10 moves nothing (≤0.003ε,
rows +3.7%). So the late tolerance does not matter while the knots pin the steps, and
the moves of G1/G2 come from steps that straddle a knot: in G1 51% of late steps hold a
knot (1.39 on average), in G2 46%. **The error of a knot-straddling step is not seen by
the step control: tightening the tolerance ×10 made it larger (ln J −0.05 → −0.40ε,
TF24_cost_scale −0.73 → −1.52ε), not smaller.** The knots are load-bearing, not a
landing convenience.

G4/G5 (pre-registered, forward only, J): is the blind spot the splits? G4 = G2 with
SPLIT=0; G5 = G3 with SPLIT=0. If |ln J(G4) − ln J(G5)| < 0.1ε the splits' pieces (which
read the field from a quartic through five samples on the step's dense output, smooth
only inside a knot span) are the blind spot; if ≈0.4ε as with splits, it is elsewhere
(the soil's substeps or the main step).

G4/G5 result: without splits the move is −0.61ε in ln J (with splits −0.40ε). Not the
splits. G6/G7 (pre-registered, forward): the same pair with SHARE empty (no soil
substeps; the soil on the main step under its error estimate). If the move falls under
0.1ε, the soil's substeps are the blind spot (their inputs are extrapolated linearly
from the last step's slope and the substep error is not in the main step's estimate).
