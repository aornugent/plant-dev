# The whole thing

An invader can now be run on the steps of a TF24 stand that lives
through a drought. A stand on a synthetic 41-year daily rainfall
record, then an invader at twice the resident's leaf mass per area.
On the base (#94):

```r
source("harness/long_drought.R")   # plant-dev: the record, its knots AK, stand_at()
times <- uniform_times(108)
ctrl <- Control(node_density_in_birth_date = TRUE,
                ode_tol_rel = 1e-3, ode_tol_abs = 1e-3)
p <- stand_at(times)                 # one TF24 species at lma 0.32
scm <- run_scm(p, mkenv(), ctrl,
               events = events(events_default(p), pulse_rows(AK)))
sum(scm$offspring_production)
#> [1] 12.41726
scm$run_mutant(stand_at(times, "lma", 2))   # an invader on the resident's steps
#> Error: TF24 storage is negative (-4.04284e-07 kg): the pool's flow does
#>   not leave [0, capacity], so this is a step that overshot the empty boundary
```

On this branch the same calls give:

```r
sum(scm$offspring_production)
#> [1] 12.66219
scm$run_mutant(stand_at(times, "lma", 2))
sum(scm$offspring_production)
#> [1] 1.865084e-21
```

The record comes from plant-dev's `harness/long_drought.R`: wet days
from a seasonal Markov chain, gamma-distributed depths, and years 8-10,
19-22 and 32-34 scaled down to between 0.28 and 0.55 of their depth
([figure](FIG:plant-113/record.png)). The stand is one species at lma
0.32, 108 introductions over 40 years, birth date, `ode_tol` 1e-3, with
a zero-depth pulse at each of the record's 2931 knots.

What changed is how fast a seedling's reserve can empty. One real
cohort from this run, through the dry spell in which its production
turns negative:

![One seedling's relative reserve after its production turns negative, at offsets 0 and 7 days](FIG:plant-113/cohort.png)

At offset 0 the pool follows its production down, relaxing as fast as
once a day; at the default 7 d it trails by about a week, and an
explicit step stays stable on it up to 26 days long. Comment 2 says
why that is enough for an invasion, and what it costs.

| file | lines | what |
|---|---|---|
| `models/tf24_strategy.h` | +23 −26 | `storage_relaxation_offset`, its column and divisor; the stage check removed |
| `tests/testthat/test-strategy-tf24.R` | +73 −24 | the divisor, the rate against 1/o, a stage below empty refills the pool |
| `tests/testthat/test-mutant.R` | +46 −6 | invaders x0.7 and x2 on a run's steps |
| `tests/testthat/reference/reference-gradient.tsv` | re-captured | 30 new rows; 89 of 1400 move by more than 1e-3 of their scale |

Read the storage block of `TF24_Strategy::compute_rates`, from
`const S storage` to `set_rate(state_idx_storage, ...)`: the deleted
check and the new divisor are fifteen lines apart.
