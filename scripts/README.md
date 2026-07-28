# Rainfall transients, cherry-picked

Drivers built to stress TF24's soil solver. Brought here so the coupling work in
`docs/reports/05-soil-plant-coupling.md` can be measured against a driver that produces
wetting and drying **fronts**, rather than against a uniformly scaled-down constant
rainfall — which shifts the mean and collapses the stand instead of moving the collar
across its operating regimes.

## Provenance

| path | from |
|---|---|
| `tf24-benchmarks/data/*.rds`, `generate_bank.R`, `BASELINE.md` | plant-dev `claude/tf24-multi-rate-stepper-n5audm` |
| `tf24-multirate/data/rainfall_scenarios.csv`, `gen_rainfall.R` | plant-dev `claude/multirate-stepper-review-r6dpwn` |

Each `data/<name>.rds` is a list of `rain` (daily vector), `life` (years) and `desc`.
`_manifest.rds` names the six.

## What is in them

Measured on the files as checked in:

| scenario | life (yr) | days | mean/d | sd/d | max/d | dry days | longest dry run |
|---|---|---|---|---|---|---|---|
| `dry_to_wet` | 25 | 9 125 | 0.613 | 5.64 | 172 | 95.1% | 652 |
| `long_horizon` | 70 | 25 550 | 1.360 | 11.80 | 400 | 93.6% | 376 |
| `extended_drought` | 30 | 10 950 | 0.213 | 2.24 | 84 | 97.1% | **1 100** |
| `intense_storms` | 20 | 7 300 | 0.510 | 6.42 | 223 | **98.0%** | 360 |
| `multispecies` | 40 | 14 600 | 0.982 | 8.11 | 291 | 94.0% | 360 |
| `whiplash` | 24 | 8 760 | 0.908 | 8.21 | 289 | 95.5% | 377 |

The generator's five climate columns, for reference:

| | drought | dry | semiarid | wet | monsoon |
|---|---|---|---|---|---|
| mean/d | 0.030 | 0.079 | 0.863 | 1.640 | 0.606 |
| sd/d | 0.432 | 0.893 | 4.438 | 6.817 | 4.073 |
| dry days | 99.2% | 98.6% | 91.2% | 86.8% | 96.4% |

The shape that matters: **the mean is low and delivered in bursts.** Standard deviation is
6–9x the mean, 94–98% of days are dry, and dry runs reach one to three years. That is what
makes them useful here — a front moves the whole profile through the retention curve, so the
collar traverses its feasible interval repeatedly rather than sitting at one end.

## What they are good for, and what they are not

**Good for incidence and robustness.** Counting how often a discrete construct is reached is
a robust question on these traces, and they were built to reach constructs a benign driver
does not.

**Not good for accuracy.** Report 5 section 6 records why: every trace sits at offspring
1e-8 to 1e-13 by construction, where the functional is ill-conditioned for every method
while its own trajectory converges cleanly, and the same species and birth rate give
offspring ~1 under constant rainfall. An accuracy reference needs a regime where the
functional is O(1), which means the model's own seasonal driver at a sustaining mean with
amplitude dialled up — not these.
