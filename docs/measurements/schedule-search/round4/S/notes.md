# Agent S, round 4: every step that spans a knot substeps the soil

aornugent/plant#111, built as candidate C of `../R/design.md` on the branches
that own the soil subsystem: odelia `ODELIA-55` and plant `PLANT-105`, with
`PLANT-106..110` rebased onto it. Local, not pushed. Library `libS` (lib19 +
`ODELIA-55` + the rebased `PLANT-110`). Outputs in
`scratchpad/dev/schedtest/S_out/`.

Scripts:
- `toy.R`: odelia's store toy under pulses of inflow, every share and tolerance;
- `fixture.R`: plant's daily-rain test stand and the seasonal replay fixture;
- `capture_seasonal.R`, `splice_seasonal.py`: the ladder's seasonal reference,
  captured alone and spliced into `reference-gradient.tsv`;
- `sweep.R`: plant's full serial sweep under `load_all`, per file;
- `adj_run_S.R`, `one_S.sh`: adj_run.R and one.sh with `KNOTS=0`, on libS;
- `../R/gate.R`, `../R/cmp.R`, `../R/knot_split.R` for the readings (with
  `PLANT_LIB` set to libS for the gate).

## The change

Against agent R's prototype (candidate A), one rule differs: a step whose first
attempt spans a knot of the subsystem's forcing substeps the subsystem, whatever
the System says of its coupling, instead of ending at the knot.

- odelia: `drivers::Function::knots(from, to)` and `Drivers::knots`;
  `HasSubsystem::subsystem_knots(from, to)`; `choose_substeps` adds the knots'
  fractions to its stops; `prepare_subsystem(…, step_end)` substeps where the
  System reports weak coupling or where `(time, min(time + h, time_max))` holds
  a knot. The decision is held across retries, as before.
- plant: `TF24Environment::rainfall_knots`, required by `HasSoil`;
  `Patch::subsystem_knots`.

*Why held, and why it is structural.* A retry only shrinks the step, so its
interval is inside the first attempt's. A step decided coupled has no knot in
its first attempt, so none in any retry: no accepted step that takes the soil
with the rest spans a knot. A step decided substepped stays substepped when a
retry shrinks it below the knot; that costs nothing in exactness (it is a
substepped step like any other) and keeps one decision per step.

*How it meets the share.* The share (`subsystem_weakly_coupled`, the plants'
uptake against the soil's flows) still decides the steps that span no knot. A
knot overrides it, so on a step where the plants draw hard the soil is
substepped all the same. The coupling's error on such a step is formed and
judged exactly as on any substepped step: the larger of the passes' gap and the
stage inputs' defect against the line, at the tightest tolerance factor outside
the soil (the members' ×1 against the soil's ×10 under `control_tf24`). Where
it is large the controller shortens the step, in place of the knot ending it.
It is of lower order than Cash–Karp's (`design-soil-alone.md`), so where it
binds, steps shrink faster with the tolerance than the main error would ask;
the risk is cost at tight tolerances, not a silent error, since it is in the
norm. At the share 0 (Control's default) a run on a variable record now
substeps every step that spans a knot: the share no longer means "never
substep", only "never substep for coupling's sake".

*What stays as it was.* A run whose forcing has no knots (constant rain), or
whose knots are all step ends (given as stops), is bit for bit. A caller's grid
(`step_to`, `advance_fixed`) never substeps, as before, and spans knots coupled;
method `rodas` never substeps either.

## Pre-registered (before any real run)

Base: the knot-stopping lib19/lib18 runs, `val_a09_c_<case>` (dry, long-wet,
episodic; lib18, which R found bit for bit with lib19 on dry) and
`val_a09p_c_long-drought` (lib19, SHARE 0.1 SPLIT 1). Tolerance 1e-4, a09's
committed schedules.

From `../R/knot_split.R` on the bases: knot-ending steps hold 56.3% (dry),
47.7% (long-wet), 28.0% (episodic) and 49.6% (long drought) of rows; of those
rows, 59.6%, 82.4%, 77.8% and 77.6% were already on substepped steps. R's
candidate A left 1056 (dry) and 484 (long-wet) knot stops, 98% of them coupled.

S0, dry with the knots still stops (`S_stop_dry`, FORWARD=1, libS). Predict: J,
times, sizes and substep ends bit for bit with `val_a09_c_dry`.

S1–S4, `KNOTS=0`, gradient: dry (`S_free_dry`), long-wet (`S_free_long-wet`),
episodic (`S_free_episodic`), long drought (`S_free_long-drought`, SHARE 0.1
SPLIT 1). Predict:
- *knot stops:* knot-ending steps fall to chance (≤ 5% of steps); every knot is
  a step end or a substep end;
- *cost against the base:* rows −25% to −40% on dry (A: −21%), −28% to −38% on
  long-wet (A: −26%), −10% to −25% on episodic, −20% to −40% on long drought;
  the sweep CPU falls more than rows and the forward less (as in R);
- *against A* (dry, long-wet): rows lower than A's by 3–15%; the steps that
  were A's coupled knot stops now substep, and the coupling's error does not
  bind them more often than the knot did;
- *accuracy:* every quantity within ε/3 of the base, rms ≤ 0.1ε, `ln J` within
  0.05ε; neither run refuses;
- *gate:* Σ|RK5 − exact| over the rain's integration intervals ≤ 1e-6 over the
  whole run (bases ~1e-11 to 1e-10).

Kill: rows fall by less than A's on dry or long-wet, a quantity moves more than
ε/3, the gate fails, or a run throws.

## Interruptions

- *Disk full (04:59).* The root filesystem reached 179 MB free (it serves
  ~37 GB however large `df` says it is). The PLANT-105 full sweep died in
  `test-gradient-ladder-*` and a build at the re-bless commit failed. 2.4 GB of
  `/tmp/Rtmp*` from before the 04:24 boot (dead processes) were removed; both
  were redone (the sweep is rerun below).
- *Container restart (~05:16).* Killed: the run queue during
  `S_free_long-wet`'s sweep (its forward was saved, the gradient was not), and
  the monitors. Intact: the git state of every branch, libS (odelia and the
  rebased PLANT-110 installed whole before the queue), `S_stop_dry` and
  `S_free_dry`. `S_free_long-wet` is redone from the start, then episodic and
  long drought.

## Results

Readings: `report_S.sh` (cmp.R, gate.R, knot_split.R per case), output in
`S_out/report_S.txt`. CPU is one run each on a machine shared with another
agent's runs (load ~2 of 4 cores); rows are the cost model, CPU is indicative.

### S0: the knots as stops change nothing

`S_stop_dry` (libS, knots given as stops, forward) against `val_a09_c_dry`: J
1.19094930713355, the 5585 times, sizes, substep ends and input slopes all
identical. **Holds.**

### S1–S4: no knot stops

| | dry | long-wet | episodic | long drought |
|---|---|---|---|---|
| steps, base → free | 5584 → 4631 (0.829) | 6638 → 5394 (0.813) | 3804 → 3606 (0.948) | 6360 → 5210 (0.819) |
| rows | 0.758 | 0.731 | 0.900 | 0.746 |
| forward CPU | 0.81 | 0.97 | 1.12 | 1.03 |
| sweep CPU | 0.55 | 0.65 | 0.78 | 0.75 |
| knot-ending steps | 4 (chance) | 3 | 2 | 5 |
| steps substepped | 50.6% → 62.5% | 70.1% → 73.4% | 63.2% → 68.2% | 66.4% → 70.4% |
| largest move | 0.228ε (stem_c) | 0.023ε | 0.102ε (a_l1) | 0.056ε (stem_c) |
| rms move, `ln J` | 0.053ε, −0.004ε | 0.007ε, −0.0004ε | 0.034ε, −0.010ε | 0.014ε, −0.004ε |
| against the case's reference, max (base / free) | 0.937 / 0.896ε | 0.499 / 0.489ε | 0.755 / 0.653ε | 0.567 / 0.564ε |
| gate, Σ\|RK5 − exact\| (base / free) | 1.06e-11 / 1.03e-11 | 1.29e-10 / 1.28e-10 | 8.85e-11 / 8.65e-11 | 7.65e-11 / 7.66e-11 |

Every knot lies inside a main step and is a substep end; no run refused or threw.

Against agent R's candidate A (knots stop the coupled steps), same lib family:

| | dry | long-wet |
|---|---|---|
| steps A → C | 4692 → 4631 (0.987) | 5276 → 5394 (1.022) |
| rows | 0.963 | 0.992 |
| largest move, C against A | 0.328ε (TF24_cost_scale) | 0.033ε |

*Against the predictions:*
- knot stops fall to chance, every knot a step or substep end: **holds**;
- rows: dry −24.2% (predicted −25 to −40%) **misses, just low**; long-wet
  −26.9% (−28 to −38%) **misses, just low**; episodic −10.0% (−10 to −25%)
  **holds, at the edge**; long drought −25.4% (−20 to −40%) **holds**;
- against A, rows lower by 3–15%: dry 3.7% **holds, at the edge**; long-wet
  0.8% **misses** (and 2% more steps);
- sweep CPU falls more than rows: **holds** everywhere; forward CPU less:
  **holds**, and on episodic and long drought it does not fall at all;
- accuracy (≤ ε/3, rms ≤ 0.1ε, `ln J` ≤ 0.05ε): **holds** on all four;
- gate ≤ 1e-6: **holds** (the free runs equal their bases to 1e-12).

The kill conditions do not fire: rows are below A's on both records it has, no
quantity moves past 0.23ε, the gate holds, nothing throws.

## Reading

- *What C buys over A is small.* A's 1056 (dry) and 484 (long-wet) coupled
  knot stops did not become long steps when they substep instead: dry lost 61
  steps and long-wet gained 118. Those steps are where the plants draw hard on
  the soil, and their length is set by the plants or by the coupling's error,
  not by the knot. The point of C is structural: one rule (a step that spans a
  knot substeps the soil) makes every run right without stops, at the share 0
  as well, with the rows of A or slightly fewer.
- *Long drought now gets the saving* (−25% rows): run with SHARE 0.1 it has
  substepped steps across knots, which A left only where the share allowed.
- *The forward falls less than rows; the sweep more.* As in R's runs. Not
  traced: one shared-machine run each, and the base runs were timed on another
  day. Rows are the measure here.
- *The fixture's warning does not show at 1e-4.* All four free runs are as
  close to the case's reference as their bases, or closer.

## Found on the way, and decided

- *`test-scm.R`'s substepped share needs no change.* Under A it fell to 0.46
  (coupled steps ended at each of the sine's 601 knots). Under C those steps
  substep instead, and the share rises to 0.952 (> 0.5). The test is unchanged.
- *The ladder's seasonal reference could not be recaptured on its old
  instrument.* `ladder_run_difference_pair` pins the base run's times alone, a
  grid that `step_to` takes with the soil coupled. Once the base substeps (every
  seasonal step spans one of the sine's 200 knots), the pinned runs step the
  soil coupled at the base's long steps, past its stability, and the census
  collapsed to ~1e-9 without a refusal (the hazard `design-soil-alone.md` names
  for a times-only replay). Where the base substepped, the helper now pins its
  whole program (times, sizes, input slopes, substep ends), as the sweep
  differentiates it; the other four regimes substep nothing and difference as
  before. Recaptured on `PLANT-105` (seasonal moves up to 0.035 of a metric's
  scale, 2.theta's leaf_area; the sweep then agrees to 6.2e-7) and again inside
  the rebase on `PLANT-108`'s re-bless commit, which captures the whole file on
  the spread (seasonal moves up to 0.121 there; the sweep agrees to 6.5e-7).
- *The water-balance sums do not close without the knot stops.*
  `sum_rainfall`, `sum_infiltration`, `sum_drainage` and
  `sum_resource_depletion` are main-step states read at the stages; on a step
  that spans a knot the soil takes the rain between stages and they do not. On
  `S_free_dry` the main steps' quadrature of the rain is 15.61 against 16.11
  (−3.1%; episodic −0.01%). `test-tf24-water-budget.R` ("rainfall driver is
  floored at zero", every control point a knot) failed by 2.8e-5 of 0.99; it now
  stops at each knot (in the change commit), and NEWS says a run whose budget
  must close keeps the stops. The cure is to integrate the sums with the soil
  (make them part of the subsystem, with their inputs); that moves every
  substepped run, G1's port parity included, so it is left as a follow-up.
- *The toy at the share 0* (`toy.R`): the free run's error falls with the
  tolerance (9.4e-4, 1.8e-5, 3.8e-6 at 1e-4, 1e-5, 1e-6 in absolute terms, on
  a population that grows to 242), 4–24× the stopped run's but within the
  tolerance relative to the state.

## What the harness must change (plant-dev, not committed here)

- `harness/long_drought.R`: `run_J(stops = AK)` defaults to the knots; drop
  them (`stops = numeric(0)`), keeping `pulse_rows` for a ladder's shared grid.
  `active_knots()` stays for the readings (`gate.R`, `knot_split.R`).
- Every `events(events_default(p), pulse_rows(sort(unique(active_knots(…)))))`
  becomes `events(events_default(p))`: `run_record.R:117`, `regnans_solvers.R`,
  `equilibrium_replay.R`, `curvature.R`, `replay_timing.R`, `invader_nodes.R`,
  `pilot_window.R`, `crown_eta.R`, `invader_window.R`, `v12_steps.R`,
  `walk_identity.R`, `equilibrium.R`, `layer_heights.R`, `first_panel.R`, and
  the scratch `adjmap/adj_run.R` (as `adj_run_S.R`'s `KNOTS=0`).
- *Pins must carry the soil's records.* Without the knot stops a run at the
  share 0 substeps every step across a knot, so a program pinned by times and
  sizes alone (`equilibrium_replay.R`, `curvature.R`, `invader_window.R`,
  `run_record.R`) is refused by the setter; pin `ode_soil_input_slopes` and
  `ode_soil_substep_ends` with them, as `adj_run.R`'s `PIN` does. A pin of times
  alone (`step_to`) takes those steps coupled, past the soil's stability.
- A reading of the water-balance sums needs the stops kept (above).
