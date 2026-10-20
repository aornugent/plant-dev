## What changes, on a stand where crowns cross

The example is one TF24 species on a synthetic 41-year daily rainfall
record, with 429 cohorts introduced over 40 years, on the birth-date
coordinate at `ode_tol` 1e-4. The record comes from plant-dev's
`harness/long_drought.R`: wet and dry days follow a seasonal Markov
chain, the depth of each wet day is drawn from a gamma distribution,
and three multi-year droughts are made by scaling down years 8 to 10,
19 to 22 and 32 to 34 ([figure of the record](FIG:plant-114/record.png)).

At the end of the run on the base (#113), five cohorts are taller than
the cohort introduced just before them:

```r
source("harness/long_drought.R")   # plant-dev: the record, its knots AK, stand_at()
ctrl <- Control(node_density_in_birth_date = TRUE,
                ode_tol_rel = 1e-4, ode_tol_abs = 1e-4)
p <- stand_at(uniform_times(429))
scm <- run_scm(p, mkenv(), ctrl,
               events = events(events_default(p), pulse_rows(AK)))
h <- scm$patch$species[[1]]$heights   # oldest cohort first
which(diff(h) > 0)
#> [1]  74 108 225 321 427
sprintf("%.17g", sum(scm$offspring_production))
#> [1] "12.746534371612489"
```

On this branch the same cohorts are out of order, and offspring
production differs only in the eleventh significant figure, because
the same terms are summed in a different order:

```r
#> [1]  74 108 225 321 427
#> [1] "12.746534371656043"
```

The figure shows the stand at the time of the widest crossing, 35.5
years into the run. The orange points are cohorts that stand taller
than the cohort born just before them; the widest pair differs by
1.17 mm.

![Cohort heights against birth date at the time of the widest crossing, with the out-of-order cohorts marked](FIG:plant-114/crossing.png)

The run takes the same 12 016 steps on both builds, and its forward
run takes 5.5% less CPU on this branch (comment 2 shows the timings).
With 108 cohorts introduced, 135 days apart, no crowns cross on this
record and nothing changes.

The change is in `Species::field_splits_nodes` (`species.h`), from
`scan_heights()` to the end of the loop over heights.
`test-canopy-methods.R` adds a stand with its tallest and shortest
cohorts' heights swapped, and checks the light at every height against
a sum over every crown, to 1e-14.
