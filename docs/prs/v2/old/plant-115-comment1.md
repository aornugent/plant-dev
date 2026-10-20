# The whole thing

A TF24 stand on daily rain no longer needs a stop at every knot. One
stand on a synthetic 41-year daily rainfall record, run with a
zero-depth pulse at each of its 2931 knots and without. On the base
(#114):

```r
source("harness/long_drought.R")   # plant-dev: the record, its knots AK, stand_at()
ctrl <- Control(node_density_in_birth_date = TRUE,
                ode_tol_rel = 1e-4, ode_tol_abs = 1e-4)
p <- stand_at(uniform_times(108))
stopped <- run_scm(p, mkenv(), ctrl,      # a zero-depth pulse at each knot
                   events = events(events_default(p), pulse_rows(AK)))
free <- run_scm(p, mkenv(), ctrl)         # no stops
c(stopped = sum(stopped$offspring_production), free = sum(free$offspring_production))
#>   stopped      free
#> 12.677287  9.361588
c(stopped = length(stopped$ode_times), free = length(free$ode_times)) - 1
#> stopped    free
#>   11791   10729
```

On this branch:

```r
c(stopped = sum(stopped$offspring_production), free = sum(free$offspring_production))
#>  stopped     free
#> 12.67729 12.66866
c(stopped = length(stopped$ode_times), free = length(free$ode_times)) - 1
#> stopped    free
#>   11791    4793
```

The stopped run is the same on both builds, bit for bit. Without stops
the base reads the rain only at its stages and loses 26% of J; this
branch lands within 0.07% of the stopped run, and against a run at
`ode_tol` 1e-7 it is the closer of the two.

The record comes from plant-dev's `harness/long_drought.R`: wet days
from a seasonal Markov chain, gamma-distributed depths, and years 8-10,
19-22 and 32-34 scaled down to between 0.28 and 0.55 of their depth
([figure](FIG:plant-115/record.png)). The model reads it through a
cubic with a knot each day. The stand is one species at lma 0.32, 108
introductions over 40 years, birth date, `ode_tol` 1e-4.

![The cost of substepping the soil relative to knot stops: steps, rate evaluations, rows, forward and gradient CPU](FIG:plant-115/soil-cost.png)

```
  odelia step from t, size h                          (odelia 0.8.1)
    a rain knot in (t, t+h)?  (Patch::subsystem_knots)
      no  → the six stages of the whole state, as before
      yes → the soil alone in Cash-Karp substeps, ending on every
            stage time and every knot; the plants take the six stages
            and read the soil there; the step records its substeps,
            which replays, invasions and the reverse sweep take as recorded
```

| file | lines | what |
|---|---|---|
| `patch.h` | +42 | the soil as odelia's subsystem: `subsystem`, `subsystem_knots`, `subsystem_inputs`, `subsystem_rates` |
| `models/tf24_environment.h` | +95 −80 | `layer_rates`, the soil's rates under a given uptake, shared with `compute_rates`; `rainfall_knots` |
| `scm.h`, `node_schedule.h` | +49 −19 | each step's substeps out of a run and into replays; sizes without them refused across a knot |
| `tests/testthat/test-scm.R` | +202 −8 | the daily record without stops against the stopped run; replay bit for bit; the sweep against a tangent and central differences |

Read `Patch::subsystem` to `Patch::subsystem_rates` first: that is the
whole of what plant tells odelia about its soil.
