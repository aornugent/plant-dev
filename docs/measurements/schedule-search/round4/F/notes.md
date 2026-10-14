# F: inverting the method (round 4)

Lens: the skeleton pilot -> committed run -> finer check run -> Richardson-like estimate ->
commit one. Scripts beside this file (`lib.R` loads a case's c/f pair, reference, eps, a09
shrink, CPU); outputs in `scratchpad/dev/schedtest/F_out/`.

## Pre-registrations (written before each computation or run)

- P1 (sanity): `lib.R` reproduces a09's ten decisions and 10/10 pass in the proper setting.
- P2 (assumption 9, rows model): real CPU / run_cost(rows) lies within ±15% on every a09
  run, and f/c in real CPU is within 0.05 of f/c in the model on every case.
- P3 (assumption 8, extrapolation): the extrapolated answer c - d/(1 - s) has worst
  |error| <= 0.35 eps on every case at 1e-4; at 3e-4 (a09h) <= 0.5 eps.

## Results so far

- **P1 holds.** `base.R`: a09 passes 10/10, T 12916 (training 5609); real-CPU T 14462.
- **P2 half holds.** Real CPU / rows model is 1.03–1.26 per run (dry-flat 1.24, long
  drought 1.04): the model understates the dry records by up to 20% against the
  long-drought ones. f/c agrees within 0.07. No decision moves on it; the rows model is
  fine for ranking within a case, less so for summing across records.
- **P3 holds.** Extrapolating each case's pair, c - d/(1 - s), leaves worst |error|
  0.03–0.34 eps at 1e-4 (coarse 0.43–1.29) and rms 0.011–0.127 (coarse 0.13–0.69); at
  3e-4 (a09h) worst 0.05–0.36. The estimate is good enough that the pair's own
  extrapolation is three times more accurate than either run.

## Inversion 1: the uses do the checking (dead)

If the analysis's three runs were collinear (theta0 - delta, theta0, theta0 + delta), the
middle on f and the ends on c, d = (c+ + c-)/2 - f0 would be the check for free (T = f + 2c,
-23%). Registered: the midpoint term (delta^2/2) q'' is under 0.1 eps at delta = 0.1.
`curv.R`, lma on episodic, from the references at lma x1 and x1.25 and the slope of the +-1%
map runs: **the term is 10 eps median, 34 eps max at delta = 0.1** (r_l, lma, a_r1); even at
+-1% the measured midpoint is 0.10 eps median. The quantities move ~110 eps median over
lma x1.25 (ln J by -4.15). Schedule error (under 1 eps) cannot be read against theta-variation
two orders larger. Refuted.

- P4 (assumption 1 + 8, own grids, offline): theta1's committed run corrected by theta0's
  extrapolation, c1 - d0/(1 - s0), has worst |error| <= 0.5 eps on the four root_P50/a_dG2
  directed pairs; the two lma x1.25 pairs exceed 1 eps.
- **P4 holds on three of four, fails on one; lma fails as predicted** (`transfer.R`).
  dry -> dry-p50 corrected worst 0.41 (raw 0.93), long-wet <-> wet-adG2 0.13 (raw 0.50–0.57),
  but dry-p50 -> dry 0.56 (storage_relaxation_offset, raw 0.94); episodic <-> lma x1.25
  1.17/1.43, worse than raw. Transferring a correction works where the estimate transfers
  (agent C's finding), no further.

## Inversion 2: does theta0's grid serve theta1 at all? (the use premise)

T = T_find + 2 T_use assumes the uses at nearby theta run theta0's committed schedule and
theta0's check diagnoses them. Nobody has run theta1 on theta0's grid: agent C's transfer
used theta1's own grid from theta1's own pilot. Edges move with the traits: of dry-p50's 154
edges (dry 140), 78 lie within 1e-3 y of a dry edge, 135 within 0.01 y, the farthest 67 d
away; long-wet -> wet-adG2 similar (max 277 d); episodic -> lma x1.25 only 35 of 68 within
0.01 y. On theta0's grid, theta1's new edges fall inside intervals.

Registered before run F_use_dryp50 (dry's a09 committed grid, root_P50 x1.2, TOL 1e-4, lib19):
- U1 (premise holds): every quantity within 0.15 eps of dry-p50's own-grid committed run, and
  dry's estimate d/(1 - s) passes C1–C5 as dry-p50's estimate.
- U1' (premise breaks): some quantity moves over 0.3 eps from the own-grid run.
- U2: CPU within 5% of dry-p50's own committed run (same node count class).

## Inversion 3: symmetry across seeds (dead, confirms agent C)

Committed errors across the three long-drought seeds correlate 0.13–0.76 (dry with long
drought 0.91, an accident of record); one seed's estimate read as another's reads a median
0.35, 0.75, 0.55, 0.10, 0.96, −0.03, and fails C2 or C3 on two of six pairs. A check is per
record.

## Where the binding error is (anatomy.R)

The same leaf quantities bind on every record: a_l1, a, curv_fact_elec_trans,
storage_relaxation_offset, vcmax_25 (lma x1.25: r_l, TF24_cost_scale). Of the 47
quantity-cases over 0.5 eps, 6 sit at the 0.01 eps floor: the floor is not what binds.
Only 8–26 of a committed schedule's ~110 open intervals are within 10% of the range cap;
edges are 37–81% of nodes.

## Inversion 4: the uses run a third schedule sized to the measured error (dead)

Registered: on the scorer (base a05_fill R 1.6 BG 90, T 8473, agent C's proxy for a09), letting
the uses run h * sqrt(TAU_USE / m) (m the largest estimate, coarse commits only), estimate
scaled by the proxy, saves 3–6% at TAU_USE 0.7 and stays 5/5. `resize.R`, `score_resize.R`:
**−0.4% at 0.7 (5/5), −0.9% at 0.85 (4/5).** The interior is a minority of rows and most
intervals that could widen are capped or bounded by edges. Refuted: a committed run cannot
be cheapened by spending its margin on spacing.

### F_use_dryp50 result: U1 holds, firmly; U2 holds

dry-p50's traits on dry's committed grid move every quantity at most **0.07 eps** (a_l1) from
dry-p50 on its own grid, rms 0.020: about the run-to-run jitter. Worst 0.86 against 0.93.
Dry's estimate read as this use's passes C1–C5 (correlation 0.94); the use corrected by it
errs at most 0.37. CPU 318 s against 339 (rows 0.99). The 14 edges theta1 adds and the 19 that
moved over 0.01 y (up to 67 d) cost nothing measurable. So the use premise holds at root_P50
x1.2, twice the objective's resident radius, and grid placement is not what moved
storage_relaxation_offset in agent C's dry-p50 -> dry transfer.

Registered before F_use_lma (episodic-lma's traits, lma x1.25, on episodic's committed grid;
b1 moves 3.05 -> 3.69, only 35 of 68 edges within 0.01 y):
- U3: every quantity within 0.15 eps of episodic-lma's own-grid committed run.
- U3': some quantity moves over 0.3 eps (the founders' window at theta1 runs past theta0's
  b1 on background spacing). I lean U3' (60%).
