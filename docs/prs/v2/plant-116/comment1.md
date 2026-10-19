# The whole thing, then its parts

## The whole thing

A TF24 stand at its demographic equilibrium, found with its own gradient,
and an invader differentiated there. The stand is the one in
`test-tf24-fitness-gradient.R` (`fitness_stand_parameters()`): one
species with `hmat` lowered to 6 m so cohorts mature within its 6 years,
12 introductions, constant rain of 1 m/yr, the soil starting half full,
the birth-date coordinate.

```r
{{WG}}
```

Each pass of the loop is one resident run and one reverse sweep, and
the sweep's `"1.birth_rate"` column is dJ/db. At b* the stand makes as
many seeds as it is given, and an invader at the resident's traits
reads R0' = 1. The invader at lma x0.9 then takes the resident's
recorded steps, solves its own leaf at every stage, and its reverse
sweep returns d R0'/d lma and d R0'/d hmat from that one replay.

The rest explains a part of this.

## Terms

- **copied row**: a pass over the resident's recording that hands each
  step's stages a copy of the recorded row (`advance_recorded(rec,
  true)`, odelia 0.8.2). The row's field is read from it; the solved
  values the invaders produce are written into the copy, so the
  recording itself is never written.
- **field**: what a rate evaluation reads from the stand, kept per stage
  in a recorded row: the light spline and the environment's state (the
  soil water). An invader is too rare to change it.
- **operating point**: the root-collar water potential at which TF24's
  leaf solve settles, and the leaf outputs there. It is the one inner
  optimisation in TF24's rates.
- **birth-rate column**: a gradient column for a species run at a constant
  birth rate, last in its block, `"<i>.birth_rate"`.

## Control flow

```
  scm$run_mutant(p)                            scm.h, SCM::run_mutant
    │  refuse a harvest or climate extreme in the resident's events
    │  refuse an invader introduced where the resident introduced nothing
    │
    ├─► pass 1 (once per resident): replay the resident's own program,
    │     keeping the field at every stage in its row
    │
    └─► pass 2: solver.advance_recorded(resident_recording, true)
          │                                    odelia: a copy of each row
          ├─► stage i of a recorded step
          │     Patch::store_solved(copy)       patch.h
          │       copy.field.kept → read the resident's field from the row
          │     Patch::compute_rates
          │       └─ TF24_Strategy::solve_leaf  the invader's own leaf,
          │            stored into the copy      in the resident's light and soil
          │
          └─► stand_gradient(scm)              the invasion's reverse sweep
                reads each copy's leaf rows, so d R0'/d θ' is the
                derivative of the invader's own optimisation
```

Before this change pass 2 loaded the resident's operating point at each
stage (`solve_leaf` → `replay_operating_point`) and solved nothing.

## What changes for existing code

| old | new |
|---|---|
| TF24 invader fitness with the resident's leaf | with the invader's own leaf; every TF24 invader's `R0'` moves |
| two TF24 invaders in one `run_mutant()`: `Incorrect length input; expected 2, received 1` | runs; each invader's fitness is the one it has alone |
| `stand_fitness()` on TF24: `no differentiable fitness` | `"<i>.net_reproduction_ratio"`, `"<i>.offspring_production"` |
| `stand_gradient()` on TF24 defaults to the three census metrics | defaults to the census and the two fitness metrics per species |
| TF24 columns per constant-birth-rate species | one more, `"<i>.birth_rate"`, last in the block: index columns by name |
| `census_undifferentiable_tf24()` lists `S_D` | `S_D` is a column; its census column is zero by construction |
| `run_mutant()` after a run with a harvest or climate extreme | refused: the replay applies introductions only |
| `run_mutant()` with an introduction the resident did not make | refused: the replay would skip it |
| odelia 0.8.1 | 0.8.2 (`LinkingTo` and `Imports`) |

No resident number moves: on the stand above the resident's J at b* is
{{RESJ}} on both builds, and `reference-gradient.tsv` is untouched.

## Files

| file | lines | what |
|---|---|---|
| `models/tf24_strategy.h` | +41 −18 | `differentiable_fitness`, the birth-rate column, `S_D` off the undifferentiable list |
| `scm.h` | +34 −6 | `run_mutant`: the two refusals, `advance_recorded(rec, true)` |
| `patch.h` | +9 −1 | `store_solved` reads a field the copied row already holds |
| `tests/testthat/test-tf24-fitness-gradient.R` | +159 | new: names, the gradient against a pinned-step difference, Newton to b*, an invader at b* |
| `tests/testthat/test-tf24-mutant-gradient.R` | +33 −7 | two invaders alone and together; the fitness row against a difference |
| `tests/testthat/test-mutant.R` | +19 | both refusals |
| six gradient-ladder test files, `helper-gradient-ladder.R` | +37 −17 | read the census rows by name where TF24 now also has fitness rows |

Read `SCM::run_mutant` first, from the refusals to
`advance_recorded(resident_recording, true)`; then the `field.kept`
branch in `Patch::store_solved`, which is where the copied row changes
what a stage does. Then `ad_parameters()` and `birth_rate_at()` in
`tf24_strategy.h` for the column, and the Newton test in
`test-tf24-fitness-gradient.R`, which is the whole game above.
