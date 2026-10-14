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
