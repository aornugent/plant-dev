## What changes, on a stand with daily rain

The example is one TF24 species (lma 0.32) on a synthetic 41-year
daily rainfall record, with 108 cohorts introduced over 40 years, on
the birth-date coordinate at `ode_tol` 1e-4. The record comes from
plant-dev's `harness/long_drought.R`: wet and dry days follow a
seasonal Markov chain, the depth of each wet day is drawn from a gamma
distribution, and years 8 to 10, 19 to 22 and 32 to 34 are scaled down
to between 0.28 and 0.55 of their depth to make three droughts
([figure of the record](FIG:plant-115/record.png)). plant reads it
through a cubic with a knot at each day.

The stand is run twice, once with a zero-depth rainfall pulse at each
of the record's 2931 knots, which stops the solver there, and once
without. On the base (#114):

```r
source("harness/long_drought.R")   # plant-dev: the record, its knots AK, stand_at()
ctrl <- Control(node_density_in_birth_date = TRUE,
                ode_tol_rel = 1e-4, ode_tol_abs = 1e-4)
p <- stand_at(uniform_times(108))
stopped <- run_scm(p, mkenv(), ctrl,
                   events = events(events_default(p), pulse_rows(AK)))
free <- run_scm(p, mkenv(), ctrl)
c(stopped = sum(stopped$offspring_production), free = sum(free$offspring_production))
#>   stopped      free
#> 12.677287  9.361588
c(stopped = length(stopped$ode_times), free = length(free$ode_times)) - 1
#> stopped    free
#>   11791   10729
```

On this branch the same calls give:

```r
#>  stopped     free
#> 12.67729 12.66866
#> stopped    free
#>   11791    4793
```

The stopped run is the same on both builds, bit for bit. Without stops
the base loses 26% of J, because it reads the rain only at each step's
six evaluation times. With this change the run without stops lands
within 0.07% of the stopped run. Against a run stopped at every knot
at `ode_tol` 1e-7, it is also the more accurate of the two: its ln J
is 3.0e-6 away, where the stopped run at 1e-4 is 6.8e-4 away and the
base without stops is 0.30 away.

![Accepted steps, rate evaluations, recorded node-steps, and forward and gradient CPU, each relative to the run stopped at every knot](FIG:plant-115/soil-cost.png)

The run without stops takes 0.41 times as many steps, and a gradient
run takes 0.35 times as long (82 s against 232 s). The figure also
shows plant's seasonal reference regime, a 10-year stand whose rain
is 1 + sin(2πt) m/yr with knots 7.6 days apart. The base already
misses little rain there, and substeps save less: they take 0.69 times
the steps and 0.64 times the gradient CPU, but the solver rejects more
steps (424 against 91), so the plants' rates are evaluated 1.07 times
as often.

## What changes for existing code

A run that keeps its rainfall pulses is unchanged. A run on variable
rain without pulses now reads the rain between a step's evaluations,
so its results change; the seasonal regime's gradient references were
re-captured for that reason, and 12 of its rows moved by more than
1e-3 of their scale, the largest by 0.036.

A fixed step schedule must now carry each step's substeps.
`sched$set_ode_steps(times, sizes)` becomes
`sched$set_ode_steps(times, sizes, input_slopes, substep_ends)`, taking
a run's `ode_soil_input_slopes` and `ode_soil_substep_ends` beside its
`ode_times` and `ode_step_sizes`. A schedule of sizes without them is
refused at a step that crosses a knot, since replaying that step
without substeps would give a different answer.

The water-balance sums (`sum_rainfall`, `sum_infiltration`,
`sum_drainage`, `sum_resource_depletion`) are still accumulated at
each step's six evaluations, so on variable rain without pulses they
miss the rain the soil takes between them: 3.1% of the rain on the dry
reference regime. A run whose water budget must close exactly keeps
its pulses, as `test-tf24-water-budget.R` does.

Read `Patch::subsystem` through `Patch::subsystem_rates` first. Those
four functions are everything plant tells odelia about its soil.
