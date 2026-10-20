## What changes, on a small stand

The example is the stand in `test-tf24-fitness-gradient.R`: one TF24
species with a maturation height of 6 m, so that cohorts reproduce
within the stand's 6 years, 12 cohorts introduced, constant rain of
1 m/yr, on the birth-date coordinate at `ode_tol` 1e-6.

A resident is at its demographic equilibrium when it produces as many
seeds as it receives, J(b) = b for birth rate b. The loop below finds
that birth rate by Newton's method on ln J − ln b, taking the slope
from the gradient of offspring production with respect to the new
birth-rate column. It then introduces an invader with 0.9 times the
resident's leaf mass per area and differentiates the invader's
fitness, its net reproduction ratio R0′.

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

On the base the loop stops at its first `stand_gradient()` call with
`Unknown metric: 1.offspring_production`. This invader is built
through `TF24_hyperpar`, so changing its leaf mass per area also
changes the traits that the hyperparameters tie to it; the gradient's
columns hold every other parameter fixed.

The figure shows what the invader's own leaf changes. Each curve is
the fitness of invaders that differ from the resident only in leaf
mass per area, at the equilibrium found above. On the base (orange)
each invader carries the resident's leaf; on this branch (blue) it
optimises its own. Below the resident's leaf mass per area the
invader's own leaf raises ln R0′ by up to 0.6, and the largest change,
1.7, is on the steep side just above it. The resident introduced as
its own invader is unchanged, with ln R0′ of 5.6e-11 on both builds.

![Invader fitness against its leaf mass per area as a multiple of the resident's, with the resident's leaf and with its own, and the gradient drawn as tangents](FIG:plant-116/landscape.png)

The orange segments are the gradient of ln R0′ from the invasion's
reverse sweep, drawn as tangents. Away from the resident it agrees
with a central difference of invasions to 2e-5 relative at six of the
eight points. On the steep side at 1.02 times the resident it agrees
to 2.2e-3, and at the resident itself, where the curve bends sharply,
the two differ by 4.8%.

## What changes for existing code

TF24's offspring production and net reproduction ratio are now stand
metrics, `S_D` is a gradient column, and a species at a constant birth
rate gains a `"<i>.birth_rate"` column, last in its block, so code
that indexes TF24's gradient columns by position should index them by
name. `stand_gradient()` on TF24 now returns the census and the two
fitness metrics by default. TF24 invaders' fitness values change.

The changes are in `SCM::run_mutant` (`scm.h`), the branch of
`Patch::store_solved` that reads a light environment already in the
copy (`patch.h`), and TF24's fitness declaration and birth-rate column
(`models/tf24_strategy.h`). The new tests are in
`test-tf24-fitness-gradient.R`.
