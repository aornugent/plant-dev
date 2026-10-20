# The whole thing

On a stand whose crowns cross, the light build keeps its running total
instead of evaluating every crown at every knot. The stand: one TF24
species on a synthetic 41-year daily rainfall record (plant-dev's
`harness/long_drought.R`: wet days from a seasonal Markov chain, gamma
depths, three multi-year droughts; [figure](FIG:plant-114/record.png)),
429 introductions over 40 years,
birth date, `ode_tol` 1e-4, a zero-depth pulse at each of its 2931 rain
knots. On the base (#113):

```r
source("harness/long_drought.R")   # plant-dev: the record, its knots AK, stand_at()
ctrl <- Control(node_density_in_birth_date = TRUE,
                ode_tol_rel = 1e-4, ode_tol_abs = 1e-4)
p <- stand_at(uniform_times(429))
scm <- run_scm(p, mkenv(), ctrl,
               events = events(events_default(p), pulse_rows(AK)))
h <- scm$patch$species[[1]]$heights   # oldest cohort first
which(diff(h) > 0)                    # a cohort taller than the one born before it
#> [1]  74 108 225 321 427
sprintf("%.17g", sum(scm$offspring_production))
#> [1] "12.746534371612489"
```

On this branch:

```r
which(diff(h) > 0)
#> [1]  74 108 225 321 427
sprintf("%.17g", sum(scm$offspring_production))
#> [1] "12.746534371656043"
```

Five pairs of cohorts end the run out of height order, and J agrees to
3.4e-12 relative: the same terms summed in another order. The run takes
5.5% less CPU (comment 2). The widest crossing of the run, 1.17 mm at
t = 35.5 yr:

![Heights against birth date at the stop with the widest crossing, the out-of-order pairs marked](FIG:plant-114/crossing.png)

```
  field_splits_nodes(knots)                          species.h
    scan_heights(): heights fall along the node list?
      yes                 → running total in list order
      no, birth date      → running total in height order   [this PR]
      no, height coord.   → every crown at every knot
```

| file | lines | what |
|---|---|---|
| `species.h` | +24 −17 | `field_splits_nodes`: the gate, `order` and `at()` |
| `tests/testthat/test-canopy-methods.R` | +33 | tallest and shortest cohorts swapped; the light at every knot against Beer's law over every crown, to 1e-14 |

Read `Species::field_splits_nodes` from `scan_heights()` to the end of
the knot loop. `ascending_by_abscissa()` is unchanged; it already
served the height coordinate.
