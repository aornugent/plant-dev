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
