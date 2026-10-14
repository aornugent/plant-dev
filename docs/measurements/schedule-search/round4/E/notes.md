# Agent E: what do we pay for, and what does it buy? (round 4, 14 October)

Scripts here; outputs under `scratchpad/dev/schedtest/E_out/`. `common.R` (knots and
run lookup), `steps.R` (what ended each accepted step), `bands.R` (rows by age band),
`cpufit.R` (real CPU against rows and steps), `adj_run_E.R` + `one_E.sh` (adj_run.R
with `KNOTS_UNTIL`, rain knots as step targets only before that age, and `TRAJ=1`,
each row's error component and ratio).

## Mined from the saved a09 runs (proper setting), before any run

- **Every rain knot ends a step** (972/974 on episodic, 2947/2951 on dry), and steps
  ending on a knot carry **41–56% of all rows** (episodic 27–29%). Their median size is
  exactly 1.00 d: knot to knot.
- In the late region the window weight loosens the tolerance up to 100×, but the steps
  do not grow: after t = 33 (weight 100) the median step is still 1.00 d on every
  daily-rain record, and knot-ended steps there are **11–15% of all rows** (t ≥ 25:
  29–34%). HMAX-ended steps are only 1–9% of rows. So the knots, not the tolerance,
  set the late steps: the window weight is largely inert where it is largest.
- Real CPU is rows: over 211 proper-setting val runs, CPU = 5.9e-4 s/row (model
  4.8e-4, real/model 1.15 median, tight), and steps carry no extra per-step cost.
  So rows saved are CPU saved one for one.

## Pre-registered (before E runs)

- E1 (forward, `TRAJ=1`, dry a09 committed schedule): knot-ended steps after t = 30
  have median error ratio under 0.02 (the controller would take ≥2.2× longer steps);
  in [10, 20) their median ratio is over 0.1.

**E1 (`E_tr_dry`, forward, 73 s): half holds.** The forward repeats `val_a09_c_dry` to
the row (5585 steps, 591475 rows) on lib19. Knot-ended steps by band, median error
ratio (room to grow 0.9 r^-1/5): [0,5) 0.0089 (2.3×), [5,10) 0.015 (2.1×), [10,20)
0.022 (1.9×), [20,25) 0.018 (2.0×), [25,30) 0.0058 (2.5×), [30,33) 0.0017 (3.2×),
[33,40) 0.00035 (4.4×). After 30 it holds; in [10,20) the median is 0.022, not over 0.1:
**the knots shorten steps everywhere, not only late.** The controller's own steps
(not on a knot, birth or HMAX) sit at a median ratio 0.17–0.20 before 30. The soil sets
56–79% of the knot-ended steps; node states set 77% of the controller's own.
(The design doc's "the knots stay step targets, which land steps rather than shorten
them" does not hold on dry at 1e-4.) Caveat: the room is an upper bound, since a step
across a knot also carries the forcing's kink.

Registered before the gradient runs on dry's a09 committed schedule (lib19, 1e-4):
- E2 (`E_k0_dry`, no knots as step targets): rows fall 20–45% (central 30%); every
  quantity moves under ε/3 from `val_a09_c_dry`, worst about 0.2ε; rejections rise.
- E3 (`E_k25_dry`, knots before 25 only): rows fall 15–22%; every quantity moves under
  0.1ε.

**E2 (`E_k0_dry`, no knots) fails, and the failure says what the knots buy.** Rows fall
to 0.734 (CPU 0.647), steps 5585 → 4473, but J falls from 1.191 to 0.984 (ln J −0.19,
7.6ε) and elasticities move up to 19ε (a_l1, TF24_cost_scale 18ε, a_dG2 −12ε).
Rejections rise from 983 to 2236 (and 10 thrown). This is not a step-size error that
tolerance controls: with ~1.8 d steps the Cash–Karp stages sample each one-day rain
hump of the cubic forcing at six points and the embedded estimate, built from the same
stages, cannot see what falls between them, so the water input is wrong (the dry stand
is water-limited, so J drops). The knots are the forcing's quadrature, not a step-size
choice: every step must lie in one span of the rain interpolant. (So the design doc's
claim is half right: they do shorten steps, about 2× by the error ratio, and they must.)

- E3 still worth one run: after 25 the tolerance weight is 2–100, so a wrong late water
  input reaches the quantities 2–100× less. Re-registered given E2: rows fall 15–22%;
  moves under 0.33ε (ε/3), central 0.15ε; if over ε/3, the knot line is closed.

**E3 (`E_k25_dry`, knots before 25 only) fails ε/3.** (A first attempt died in the sweep:
I edited `adj_run_E.R` while Rscript was still reading it; `one_E.sh` now runs a copy.)
Rows 0.812, CPU 0.759 (fwd 63/77 s, sweep 188/254 s), steps 5585 → 4910, ln J moves
0.054ε, but elasticities move up to 0.73ε (TF24_cost_scale −0.73, root_P50 +0.51 taking
its error to 0.98ε, a_r1 +0.48), rms 0.23ε. The late window weight (2–100) does not
shield the quantities from a water input the controller cannot see: the error is not a
tolerance error, so loosening the tolerance does not scale it. The knot line is closed.

- E4 (`E_k0f5_dry`, forward only, no knots, tolerance 1e-5): J stays under 1.10
  (against 1.191 with knots and 0.984 without at 1e-4), i.e. a tenfold tighter
  tolerance recovers under half the gap. If it holds, the controller is blind to the
  forcing between stages and a run without knot stops is silently wrong.
