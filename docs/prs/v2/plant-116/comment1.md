# The whole thing

A TF24 stand's equilibrium, found with its own gradient, and an invader
differentiated there. The stand is `test-tf24-fitness-gradient.R`'s:
one species with `hmat` 6 m so cohorts mature in its 6 years, 12
introductions, constant rain 1 m/yr, birth date.

```r
env  <- fitness_stand_environment()
ctrl <- Control(node_density_in_birth_date = TRUE,
                ode_tol_rel = 1e-6, ode_tol_abs = 1e-6)
b <- 10
repeat {
  scm <- run_scm(fitness_stand_parameters(b), env, ctrl, record_trajectory = TRUE)
  g <- stand_gradient(scm, metrics = "1.offspring_production", traits = "1.birth_rate")
  J <- g$value[[1]]
  cat(sprintf("b %-12.10g ln J - ln b %+.2e\n", b, log(J) - log(b)))
  if (abs(log(J) - log(b)) < 1e-8) break
  b <- exp(log(b) - (log(J) - log(b)) / (b * g$gradient[[1]] / J - 1))
}
#> b 10           ln J - ln b +1.72e+00
#> b 30.71890064  ln J - ln b -4.72e-01
#> b 21.53589225  ln J - ln b -3.40e-03
#> b 21.49272444  ln J - ln b +8.31e-05
#> b 21.49374797  ln J - ln b -6.08e-06
#> b 21.49367298  ln J - ln b -1.22e-07
#> b 21.49367148  ln J - ln b -2.44e-09

scm$run_mutant(fitness_stand_parameters(1, lma_factor = 0.9))
gi <- stand_gradient(scm, metrics = "1.net_reproduction_ratio",
                     traits = c("1.lma", "1.hmat"))
gi$value
#> 1.net_reproduction_ratio
#>                 8.978231
gi$gradient
#>                              1.lma    1.hmat
#> 1.net_reproduction_ratio -2543.109 -4.490476
```

The invader is built through `TF24_hyperpar`, so its lma x0.9 moves
the traits that map ties to lma; the gradient's columns hold every
other parameter fixed. On the base the loop's first `stand_gradient()` stops with
`Unknown metric: 1.offspring_production`, and two invaders in one
`run_mutant()` with `Incorrect length input; expected 2, received 1`.

Each invader now solves its own leaf in the resident's light and soil.
Across invaders that differ from the resident in lma alone:

![Invader fitness against the lma multiplier, with the resident's leaf (base) and the invader's own (this branch), and the sweep's slope drawn as tangents](FIG:plant-116/landscape.png)

On the base every invader carries the resident's operating point; with
its own leaf an invader below the resident's lma gains up to 0.6 in
ln R0', and the largest change, 1.7, sits on the steep side just above
it. The resident itself, as its own invader, is unchanged (ln R0' 5.6e-11
on both builds). The sweep's d ln R0'/d ln lma agrees with a central
difference of invasions (step 1e-4 in ln lma) to 2e-5 relative at six
of the eight points; on the cliff at x1.02 to 2.2e-3, and at the
resident itself, where the curve turns sharply, they differ by 4.8%.

| file | lines | what |
|---|---|---|
| `scm.h` | +34 −6 | `run_mutant`: two refusals, `advance_recorded(rec, true)` |
| `patch.h` | +9 −1 | `store_solved` reads the field a copied row already holds |
| `models/tf24_strategy.h` | +41 −18 | `differentiable_fitness`, the birth-rate column, `S_D` a column |
| `tests/testthat/test-tf24-fitness-gradient.R` | +159 | new: the gradient against pinned-step differences, Newton to b*, an invader at b* |
| `tests/testthat/test-tf24-mutant-gradient.R`, `test-mutant.R` | +52 −7 | two invaders alone and together; the refusals |

Read `SCM::run_mutant` from the refusals to
`advance_recorded(resident_recording, true)`, then the `field.kept`
branch of `Patch::store_solved`.
