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

**E4 holds (`E_k0f5_dry`).** Without knots at 1e-5: J 1.071, 8019 steps, 795872 rows
(1.35× the knotted 1e-4 run's rows), still 0.11 below the knotted 1.191. Tenfold
tighter recovers 42% of the gap (error ∝ tol^0.24, against the method's fifth order):
the embedded estimate is nearly blind to the forcing between stages. So knot stops are
not a cost but a large saving: no tolerance reaches their accuracy at their price.
**Hazard (report):** the stops live only in the harness (`pulse_rows(active_knots())`);
plant adds none itself, so any TF24 run on a daily rainfall driver without them is
silently wrong by ~17% in J on dry (7.6ε in ln J, 19ε in elasticities) at 1e-4.

## Second line: who sets the controller's own steps

From `E_k25_dry`'s trajectory (before 25, identical to a09's): the node states set most
steps that are neither knot, birth nor HMAX. **Mortality sets 14.6% of all rows**, and
the setter is almost always a newborn node (median age 21 d, born anywhere 4.6–27) at a
mortality of median 0.0016 (90% under 0.064). Mortality is −ln survival; under the
relative tolerance its level is 1e-4·m + 1e-8 ≈ 1.7e-7 for a newborn, against 3e-4 for
a node at m = 3: a newborn's survival is held ~1000× tighter, in the units J feels
(d ln J ∝ −w_i dm_i), than an established node's. States whose |y| < 1e-4 (absolute
level dominant) set only ~4% of rows (interval_establishment near 0, empty storage).

- E5 (`E_at2_dry`, ATOL 1e-2, i.e. absolute level 1e-6 against 1e-8; a09 dry committed
  schedule, gradient): rows fall 5–12% (central 8%); every quantity moves under 0.15ε
  from `val_a09_c_dry`.

**E5 holds (`E_at2_dry`).** ATOL 1e-2: rows 0.894, CPU 0.875 (fwd 65/77, sweep 225/254),
steps 5585 → 4928, rejections 983 → 737; max move 0.106ε (TF24_cost_scale, the
hydraulic direction tolerance moves), rms 0.033ε; worst error 0.84 (base 0.94). The rows
come off the controller's own steps (38.2% → 27.0% of base rows): storage-set 13.4 →
7.4, mortality-set 14.8 → 11.5, interval_establishment 3.1 → 1.4. Knot-ended rows do
not move. For comparison, tolerance 3e-4 (round 3) saved ~10% for a 0.32ε move on dry.
The tied tolerance (ATOL 1e-4) was set against near-empty pools under plant's default
absolute level (`grid-dynamics.md` §4–6); 1e-2 sits 100× looser than tied, 100× tighter
than the default.

Registered before the remaining four runs (ATOL 1e-2, a09's schedules, lib19, proper
setting):
- E6/E7 (`E_at2_c_ld-102`, `E_at2_f_ld-102`, the record where 3e-4 failed C3 on the
  hydraulic direction): each run's rows fall 7–14%; each quantity moves under 0.15ε from
  `val_a09p_*_ld-102`; scored as a09 scores it (commit, C1–C5), ld-102 passes and commits
  as a09p did.
- E8 (`E_at2_f_dry`): with `E_at2_dry`, dry passes C1–C5 and commits as a09 did, T
  within 0.86–0.92 of a09's.
- E9 (`E_at2n_dry`, ATOL 1e-2 at tolerance 1.05e-4): moves under ε/3 from `E_at2_dry`
  (reproducible), rms under 0.05ε.

## Results of E6–E9 (ATOL 1e-2)

| run | rows vs a09 | CPU vs a09 | max move | rms |
|---|---|---|---|---|
| dry c (`E_at2_dry`) | 0.894 | 0.875 | 0.106ε TF24_cost_scale | 0.033 |
| dry f (`E_at2_f_dry`) | 0.892 | 0.872 | **0.377ε stem_c** (TF24_cost_scale 0.345) | 0.092 |
| ld-102 c | 0.921 | 0.98 (load) | 0.024ε | 0.004 |
| ld-102 f | 0.914 | 0.97 (load) | 0.011ε | 0.004 |
| dry c at 1.05e-4 vs dry c (nudge) | 0.996 | — | 0.110ε TF24_cost_scale | 0.028 |

Scored as a09 scores (`score_E.R`, ALG a09_late):
- dry: coarse, worst 0.84, C1–C5 pass but **C3 at its limit (8/10)**, median read 0.84
  (a09 1.12); T 1109 against 1241 (−10.6%).
- ld-102: coarse, worst 0.46, pass (3/3), read 1.02 (a09p 1.01); T 1177 against 1281
  (−8.1%).

E6/E7 hold (ld-102 moves ≤0.024ε, rows −8%). E8 holds narrowly (passes, −10.6%) but
not by my E5 bound: the check run moves 0.38ε along the hydraulic direction (stem_c,
TF24_cost_scale, root_P50), unevenly from the committed run's 0.11ε, the signature that
failed 3e-4 on ld-102 in round 3. E9 holds (nudge 0.110ε max, rms 0.028; ε/3 is 0.33).
Real CPU on ld-102 fell less than rows because the machine's load differed between the
a09p runs and mine; across 211 runs rows track CPU tightly (cpufit.R).

Budget: 10 runs (one lost to the mid-run edit, rerun).
