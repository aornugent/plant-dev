## What changes, on a stand with daily rain

The example is one TF24 species (lma 0.32) on a synthetic 41-year
daily rainfall record, with 108 cohorts introduced over 40 years, on
the birth-date coordinate at `ode_tol` 1e-3. The record comes from
plant-dev's `harness/long_drought.R`: wet and dry days follow a
seasonal Markov chain, the depth of each wet day is drawn from a gamma
distribution, and years 8 to 10, 19 to 22 and 32 to 34 are scaled down
to between 0.28 and 0.55 of their depth to make three droughts
([figure of the record](FIG:plant-113/record.png)). The run stops at
each day with a zero-depth rainfall pulse.

The resident stand is run, and then an invader with twice the
resident's leaf mass per area is run on the resident's recorded steps.
On the base (#94):

```r
source("harness/long_drought.R")   # plant-dev: the record, its knots AK, stand_at()
times <- uniform_times(108)
ctrl <- Control(node_density_in_birth_date = TRUE,
                ode_tol_rel = 1e-3, ode_tol_abs = 1e-3)
p <- stand_at(times)
scm <- run_scm(p, mkenv(), ctrl,
               events = events(events_default(p), pulse_rows(AK)))
sum(scm$offspring_production)
#> [1] 12.41726
scm$run_mutant(stand_at(times, "lma", 2))
#> Error: TF24 storage is negative (-4.04284e-07 kg): the pool's flow does
#>   not leave [0, capacity], so this is a step that overshot the empty boundary
```

On this branch:

```r
sum(scm$offspring_production)
#> [1] 12.66219
scm$run_mutant(stand_at(times, "lma", 2))
sum(scm$offspring_production)
#> [1] 1.865084e-21
```

Invaders at 0.9 and 1.2 times the resident's leaf mass per area fail
the same way on the base and run on this branch. The resident takes
9266 steps instead of 10 516.

The figure follows one real seedling from this run through a dry
spell, from the day its net production turns negative. Without the
offset (orange) its reserve falls to the level at which the
low-reserve mortality term reaches 1/e of its maximum in 8.6 days;
with the 7-day offset (blue) it takes 21.4 days. The dots are the run;
the lines integrate the same seedling's pool from its recorded
production at each offset.

![One seedling's relative reserve after its production turns negative, with no offset and with the 7-day offset](FIG:plant-113/cohort.png)

## What changes for existing code

Every TF24 result changes, so the model version moves to 12 (TF24f to
12.1), and the references were re-captured. On plant's reference
regimes, J at 7 days differs from J without the offset by less than
1% except on the seasonal regime, where it rises 7.2%. In
`reference-gradient.tsv` 30 rows are new, for the new column, and 89
of 1400 move by more than 1e-3 of their scale, nearly all of them
derivatives with respect to `theta`, `omega` and `a_bio` on the
drought and seasonal regimes. `theta` sets the pool's capacity, and
seedlings on those regimes are where the offset matters. An offset of
zero gives v11's rates, but a run in which the old check fired still
takes different steps.

The change is in the storage block of `TF24_Strategy::compute_rates`
(`models/tf24_strategy.h`), where the deleted check and the new
divisor sit fifteen lines apart. The tests are in
`test-strategy-tf24.R` and `test-mutant.R`.
