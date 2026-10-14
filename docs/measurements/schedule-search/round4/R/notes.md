# Agent R, round 4: the soil's substeps land on the rain's knots

Design: `design.md`. Branches `RAIN-SUBSTEPS` (odelia on f19f7de, plant on
fa9afe76), local, not pushed. Library `libR` (lib19 + both branches). Outputs in
`scratchpad/dev/schedtest/R_out/`.

Scripts:
- `knot_split.R`: which knot-ending steps substepped the soil (saved runs only);
- `adj_run_r.R`, `one_r.sh`: adj_run.R and one.sh with `KNOTS=0` (no knot stops),
  on libR;
- `gate.R`: G's quadrature gate over the intervals that integrate the rain (the
  substeps on a substepped row, the step on a coupled one), and G's main-step
  reading beside it;
- `cmp.R`: cost and each quantity's move in ε (`anyscore.R` `quantities()`,
  `eps_vec()`), and each run against the case's reference.

## Before any run

`knot_split.R` on a09's committed runs (lib18):

| run | knot-ending steps | of rows | substepped among them (rows) |
|---|---|---|---|
| dry | 2955 (52.9%) | 56.3% | 61.9% (59.6%) |
| long-wet | 2955 (44.5%) | 47.7% | 83.5% (82.4%) |
| long drought (SHARE off) | 2936 (26.4%) | 28.0% | 0% |

So the change can reach about 34% of dry's rows and 39% of long-wet's, and none
of long drought's in its current setting.

`gate.R` on G's runs (dry, committed schedule, lib18):

| run | rain intervals, Σ\|RK5 − exact\| (whole run) | main steps, Σ\|RK5 − exact\| (25.2–39.5) |
|---|---|---|
| base (knots) | 1.1e-11 | 0.000 |
| G1 (no knots after 25) | 0.61 | 2.41 (G's number) |

So in G1 the substeps had already taken most of the rain that the main steps
missed, but 0.61 of 16.1 units was still misplaced: on coupled rows, and by
substeps that spanned knots.

The toy (odelia `test-substeps.R`, store under pulses of inflow at `1e-4`):

| store | stopped at knots | no stops, before | no stops, after |
|---|---|---|---|
| slow (K = 10) | 5.3e-5 | 2.0e-3 | 9.7e-7 |
| stiff (K = 1e4) | 1.2e-4 | 4.2e-3 | 4.2e-3 |

**The stiff store is the design's limit.** It passes each pulse through as a
spike in its level, and the population, which reads the level only at its own
stages, misses the spike however exactly the store is integrated. The change
fixes the rain's integral. It cannot fix a subsystem state that the rest reads
as a bump narrower than the step. Whether TF24's soil holds rain as a rise (the
slow store) or passes it through (the stiff one) is what the dry run decides.

## Pre-registered (before R1)

R0: dry, a09's committed schedule (`jobs_a09.txt` line 3: TOL 1e-4), libR, knots
as stops (`R_base_dry`). Predict: J, times and sizes bit for bit with lib19 on
the same setting (`R_l19_dry`, forward only), since every knot is a step end and
nothing lands inside a step.

R1: as R0 with `KNOTS=0` (`R_free_dry`), gradient. Predict:
- *cost:* knot-ending steps fall to the coupled share, about 38% of R0's (about
  1100 of 2955); steps −20 to −35%, rows −15 to −30%; forward and sweep CPU
  follow rows to ±5% of the rows model;
- *gate:* Σ|RK5 − exact| over the rain intervals ≤ 1e-6 over the whole run
  (R0 about 1e-11). The main-step reading is large and does not apply;
- *accuracy:* every quantity within ε/3 of R0, rms ≤ 0.1ε, `ln J` within 0.05ε.

Kill: rows fall less than 10%, any quantity moves more than ε/3, or the gate
fails.

R2/R3, if R1 passes: long-wet, the same pair (`R_base_long-wet`,
`R_free_long-wet`). Predict rows −20 to −35% and the same accuracy bounds.

## Found building it, before R1 (plant's test fixture; predictions above unchanged)

A two-year stand under 15% wet days (`test-scm.R`, "TF24 takes a daily rain
record…"; `R_out/plant_resid.R`), J against a coupled run stopped at every knot
at `1e-7`:

| tol | stopped at knots: steps, error | no stops, substepped: steps, error |
|---|---|---|
| 1e-4 | 405, +1.3e-6 | 397, −3.1e-4 |
| 1e-5 | 457, −3.5e-6 | 617, −3.7e-6 |
| 1e-6 | 674, −2.7e-7 | 912, −1.0e-7 |

Before the change the no-stop run at `1e-4` was −6.0e-4 off and its substeps
missed every knot. Coupled at `1e-4` it was −2.2e-3 off, and is now within 2e-5
of the stopped run in the same 490 steps.

- *The rain is now taken and the error is predictable:* it falls with the
  tolerance at about second order. The estimate sees it, so this is not G's
  blind spot.
- *But the stops were also what kept the plants' steps cheap:* without them the
  run needs more steps for the same error. At matched error (about 3e-6) the
  stopped run takes 405 steps at `1e-4` and the free run 617 at `1e-5`.
  A plausible reason: the soil, the integral of a C1 cubic, has its higher
  derivatives jump at every knot, and the plants read it through steep
  potentials. A step across a knot loses the plants' order, and the controller
  has to find each onset by rejection. If R1 shows the same, the knots are
  load-bearing for the plants' steps as well as for the rain's quadrature, and
  this change buys exactness without stops but not rows.

## Results

### R0: the base is unchanged

`R_base_dry` (libR, knots as stops) and `R_l19_dry` (lib19, forward) agree bit for
bit in J, times, sizes and substep ends: J 1.19094930713355, 5585 times, as
lib18's `val_a09_c_dry`. **R0 holds.**

### R1: dry without the knot stops

| | R0 (knots) | R1 (no stops) | ratio |
|---|---|---|---|
| steps | 5584 | 4692 | 0.840 |
| rows | 591 475 | 465 945 | 0.788 |
| forward CPU | 70.6 s | 62.9 s | 0.891 |
| sweep CPU | 235.9 s | 159.2 s | 0.675 |
| knot-ending steps | 2955 (56.3% of rows) | 1056 (26.5% of rows), 97.9% of them coupled | |
| steps before age 25 / after | 4108 / 1476 | 3746 / 946 | |
| median step before 25 / after | 1.00 d / 1.00 d | 1.68 d / 4.17 d | |

- *Accuracy:* no quantity moves more than 0.156ε (TF24_cost_scale; then a_l1
  −0.119, a_r1 +0.081); rms 0.046ε; `ln J` +0.007ε; none of 47 past ε/3.
  Against the case's reference, R0 is max 0.937ε, rms 0.302ε, and R1 max 0.819ε,
  rms 0.266ε. Neither run refused.
- *Gate:* Σ|RK5 − exact| over the rain's integration intervals is 1.06e-11 in
  both, over the whole run and over ages 25.2–39.5 (6.0e-12). Read on the main
  steps, as G read it, R1 is 3.41: 1900 of 2951 knots lie inside a step, and
  their rain is taken by the substeps.
- *Against the predictions:*
  - knot stops fall to 1056, the coupled share (predicted about 1100): **holds**;
  - steps −16.0% (predicted −20 to −35%): **misses, low**;
  - rows −21.2% (predicted −15 to −30%): **holds**;
  - the sweep follows rows better than predicted (−32.5%). The forward's −10.9%
    is under the rows model's −20%, on a shared machine;
  - accuracy (≤ ε/3, rms ≤ 0.1ε, `ln J` ≤ 0.05ε): **holds**;
  - gate (≤ 1e-6): **holds**.

  The fixture's warning (more steps at matched error) does not show on dry at
  the setting's tolerance: R1 is no further from the reference than R0. Compared
  with G1, which dropped every knot after 25 and took 801 late steps but moved
  TF24_cost_scale 0.73ε: R1 keeps 946 late steps (the coupled knots stay) and
  moves it 0.16ε.

### R2, R3: long-wet

`R_base_long-wet` is bit for bit with lib18's `val_a09_c_long-wet` (J, times,
elasticities).

| | R2 (knots) | R3 (no stops) | ratio |
|---|---|---|---|
| steps | 6638 | 5276 | 0.795 |
| rows | 690 873 | 509 400 | 0.737 |
| forward CPU | 89.2 s | 73.6 s | 0.824 |
| sweep CPU | 261.8 s | 168.9 s | 0.645 |
| knot-ending steps | 2955 (47.7% of rows) | 484 (11.2% of rows), 98.6% coupled | |

- *Accuracy:* max move 0.011ε (a_l1), rms 0.004ε, `ln J` +0.002ε. Against the
  reference, R2 is max 0.499ε, rms 0.130ε, and R3 max 0.506ε, rms 0.129ε.
- *Gate:* 1.27e-10 against R2's 1.29e-10 (201 units of rain); on the main steps,
  as G read it, R3 would be 41.1. 2470 of 2951 knots lie inside a step.
- *Against the predictions:* rows −26.3% (predicted −20 to −35%), accuracy and
  gate **hold**.

## Reading

- The change does what the design says: on both records every unit of rain is
  integrated exactly with the knot stops gone wherever the soil is substepped.
  The stops that remain are the coupled steps' (1056 on dry, 484 on long-wet),
  which candidate C would reach.
- The fixture's warning (the free run needing more steps at matched error) is a
  young-stand, tight-tolerance effect that dry and long-wet at the a09 setting
  do not show: both free runs are as close to the reference as their bases.
  It is the first thing to recheck at other tolerances (`3e-4`) and on episodic.
- Long drought is untouched in its current setting (SHARE off): its knots all
  stay as coupled stops, now placed by plant rather than by the harness.
- Cost model: the sweep fell more than rows (0.675, 0.645 against 0.788, 0.737),
  the forward less (0.891, 0.824). Merged steps are longer, and substeps are
  cheap in the forward but taped in the sweep. One run each; the machine is
  shared.

## Suites

- *odelia* (libR, serial): all pass but `test-implicit-value.R`'s five, which
  fail to compile identically on lib19 (pre-existing). `test-substeps.R`'s two
  new tests fail on lib19 and pass on libR.
- *plant* (libR, full serial, 11 min): the new test passes, the FF16 guard
  passes, and four expectations fail:
  - `test-mutant.R` "mutant method works" (2): identical on lib19, pre-existing
    (`design-soil-alone.md` notes it on `PLANT-104`);
  - `test-gradient-ladder-whole-run-difference.R`, seasonal regime: 15 columns
    past the captured reference's spread (worst theta, 0.135). It passes on
    lib19. That regime runs at Control's defaults (share 0, so every step
    coupled) on a sine driver given at 200 points over 2 years. Every coupled
    step now ends at each control point, so the forward map moved and the
    captured finite difference is of the old map. The reference is data and is
    not recaptured here;
  - `test-scm.R` "A run that substepped the soil replays…": substepped share
    0.46 against > 0.5. Same cause: its 601-point seasonal sine now stops the
    coupled steps every 1.8 days.

  Both are the cost the design names, "a smooth series given densely pays for
  its knots", and they settle that the knot rule cannot be every non-flat
  control point for every driver if R6 is to hold for callers that pass no
  stops. Cures, in order of size: (a) TF24 reports the rain's knots only where
  a span is flat at zero on one side, i.e. where rain starts or stops (to be
  measured: on daily records with consecutive wet days this drops knots between
  wet days); (b) the stops for coupled steps are asked for by Control (a
  default-off value), substeps always land; (c) recapture the reference and
  accept the move as the aliasing fix it is on intermittent records.
