# The field adjoints as the node schedule's error map

A spike on the question the archived controller scope left open
(`docs/archive/scope-schedule-controller.md`, §2): can the sweep's adjoints of
the field report where the node error is made, by source panel, time and
channel? It ran on long drought, seed 31, at `3e-5` under the tied tolerance, on
plant 7dbd87c3 with `field-adjoint-map/field_probe.patch`.

## Verdict

- **The map works when it is built on the held run by dropping every other node.**
  Contracting the field adjoints with each panel's field defect, taken from the
  run's own nodes, predicts `J`'s field part at 1.000×, 0.991× and 0.996× of the
  measured value on uniform 108 → 215, 215 → 429 and graded G1 → G2.
  - Per group of refined panels it is within 0.97–1.11× (`logs/plain_u108_*`).
  - It predicts the invader's `lma` elasticity's field part at 0.986× on
    108 → 215 and 0.94× on G1 → G2. The G1 → G2 gap is within the ±1e-6
    difference's noise of 0.004–0.007.
- **It does not work as virtual cohorts interpolated into the coarser run.** The
  totals come out at 1.10×, 1.18× and 0.63×, and the top panel at 2.9×.
  Linear interpolation drops the state's own curvature in birth date, and at the
  layer's top that term sets the sign.
- **The adjoints are never the weak part.** The weak part is knowing the state
  of the cohort a finer grid would add.
- **The cost is +12% of a sweep:** 362 s against 322 s on u108, with no extra
  memory. It needs plant only; odelia is unchanged. With every probe at zero,
  the forward runs and the 50-column gradient are bit-identical to the
  references.

## What the map shows

| move | field part, measured | predicted | light | soil |
|---|---|---|---|---|
| `J`, 108 → 215 | +1.973% | +1.974% | −0.17 | +2.14 |
| `J`, 215 → 429 | +0.473% | +0.469% | −0.02 | +0.49 |
| `J`, G1 → G2 | +0.959% | +0.955% | −0.55 | +1.50 |
| invader `lma`, 108 → 215 | +0.380 | +0.375 | +0.45 | −0.08 |
| invader `lma`, G1 → G2 | +0.034 | +0.032 | | |

- **`J`'s field part is water, not shade.** The coarser hats over-count the
  stand's water use, and that lowers their members' net reproduction. Light
  from the top two panels as sources gives +0.42 on 108 → 215. Measured at the
  receivers, light moves u108's top nodes by −0.4%.
- **The invader's field part is light.** It neither shades nor drinks, so its
  error is the field it reads, and mostly the canopy's light.
- **When:** nothing before t = 3; it accrues over t = 5–20.
- **Where it is sourced:**
  - On 108 → 215, births in 0.5–1 give +1.11 and births in 3.75–20 give +0.76.
  - On G1 → G2, births before 1 give +0.07 and births in 3.75–20 give +0.77.
    Grading leaves the error in the 108-spaced cohorts after the gap.
- **The old estimate's 0.04–0.05× was the establishment gate.** On the plant
  before exact counts, births into a shut gate made steps in the integrand
  between nodes, which no estimate from nodal values sees (`old/`). Exact counts
  removed that cause.

## How

- One coefficient per panel and time band, zero in the forward, scales a
  passive defect added to the field: light at its knots (value and slope) and
  the soil's depletion per layer.
- The sweep already accumulates every registered parameter's adjoint, so each
  coefficient's adjoint, ∂J/∂ε = Σ λ_C·δC, is the map.
- The drop defect of panel p is the field of the finer run's node inside p, at
  its own state and weight, against the coarser hats' share of it.
- The patch adds 387 lines. A drop-only version is about 120.

## What would falsify it

- a record where the drop map misses the companion's field part by more than
  about 20%, or where refining its highest-ranked panels does not move `J` as
  predicted;
- a move off the square law (wet's graded ratio is 2.75): the map still gives
  the move, but a third of it is no longer the run's error;
- a feature narrower than the run's spacing, such as the constant record's
  front;
- a spacing where adding one node is not a small perturbation (u54);
- for the invader, a cliff at θ′ = θ.

## Files

`field-adjoint-map/`:
- `field_probe.patch`: the probe, against plant 7dbd87c3.
- `probe_run.R` with `probe_setup.R` and `job.sh`: the sweep, perturbation,
  plain and drop runs.
- `invader_drop.R`: the invader's field part.
- `summary.R` and `compare_invader.R`: every number above, printed in
  `summary.log` and `invader.log`.
- The rest are the per-panel test (`make_sched.R`, `compare_partial.R`), the
  state diagnostics (`defect_*.R`) and the old estimate's analysis (`old/`).
- `logs/`: each run's log.

The scripts ran from a scratch directory, `A` in each. That directory held
plant-dev's `harness/`, copies of the committed runs they name in `ref/`, and
plant 7dbd87c3 with the patch built in `lib/` and, with the drop mode, `lib2/`.
