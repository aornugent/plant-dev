# PLANT-95: a TF24 species' fitness, differentiable as a resident and as an invader (with ODELIA-53)

Branches: plant `PLANT-95` (28b96d3b), two commits on `PLANT-97` (b23b2d67), which it needs
for invaders beyond about lma ×1.0001; odelia `ODELIA-53` (f77da53), one commit on master
(1e0f0f0). Merge order: odelia, then PLANT-97, then this. Review notes:
`docs/prs/PLANT-95-review.md`.

- **Version clash to settle at merge.** ODELIA-53 and ODELIA-55 (under PLANT-105) both bump odelia
  0.8.0 → 0.8.1. Whichever lands second takes 0.8.2 and its plant PR's `LinkingTo` follows.
- **Shared commit.** plant's first commit, "Link odelia 0.8.1 and keep GSL's step-size rule", is
  PLANT-105's fd02255d cherry-picked unchanged. If PLANT-105 lands first, it drops out in a rebase.

Like PLANT-97's, the description is two short paragraphs, and the measurements go in the first
comment.

## Description

`run_mutant()` placed every TF24 invader's leaf at the resident's recorded root-collar water
potential (`tf24_strategy.h`, `solve_leaf` → `replay_operating_point`). So the fitness it
reported for another trait was the resident's leaf on the invader's body, and two invaders
together failed with `expected 2, received 1`. The replay now walks the recording seeded
(odelia 0.8.1, `advance_recorded(rec, true)`). Each rate evaluation stands in the resident's
field, which `Patch::store_solved` finds already in the row. The invaders solve and record
their own operating points, and a sweep of the invasion loads them. `run_mutant()` also
refuses two things its replay would skip without saying so: a resident run with a harvest or
climate extreme, and an invader introduced where the resident introduced nothing.

TF24 sets `differentiable_fitness`, as FF16 does since #658. `"<i>.net_reproduction_ratio"`
and `"<i>.offspring_production"` are stand metrics, and `S_D` is a column because the fitness
reads it. A species at a constant birth rate has a `"<i>.birth_rate"` column, as FF16's has.
Newton's method on `d ln J/d b` therefore finds the resident's equilibrium birth rate, where
an invader is then differentiated. No resident number moves.

Closes #95

## First comment: the case

### The problem, in the model's terms
- An invader of a TF24 stand should optimise its own leaf in the resident's light and soil
  water. Upstream's invasion replay loads the resident's recorded operating point at every rate
  evaluation instead (residual-A.md, item 2). The leaf solve is TF24's one inner choice, so the
  reported `R0'` is neither the invader's fitness nor its gradient.
- TF24 declares no fitness, so `stand_gradient()` gives its census only
  (`test-tf24-mutant-gradient.R` said so).
- The replay maps each insertion row through `Patch::apply_insertion`, which introduces nodes
  and does nothing else:
  - a harvest or climate extreme never reaches the invader. On the archived stack an identical
    invader read `ln J′ − ln J` = +0.69 under a 50% harvest and +1.3 under a lethal extreme
    (residual-A.md);
  - an invader introduced at a time the resident did not use is never introduced.

### The mechanism
- **odelia** (+32/−9 in headers). `advance_recorded(rec, true)` copies each recorded row and
  hands the stages the copy to store into. The const-row walk, which loads, stays the default for
  the pinned referees. The copy lives on the solver until the next step, so the field a patch
  stood in stays readable at an insertion between rows, as a recorded row's does.
- **plant** (+82/−24 in headers).
  - `Patch::store_solved` stands in a field the row already holds.
  - `run_mutant` walks seeded, and refuses events and stray introductions before it overwrites
    anything.
  - TF24 gains the fitness flag, the S_D column and FF16's birth-rate column, line for line.

### Measured gain
All measured here, on the refreshed base (PLANT-97's build, odelia 0.7.3) against this branch
(odelia 0.8.1). The fixture is the new test's stand: TF24, 6 yr, hmat 6, 12 introductions,
`ode_tol` 1e-6, resident at birth rate 10. Scripts and logs: `docs/prs/PLANT-95/`
(`invaders.R`, `newton.R`, and `ld.R` for long drought).

| invader on the fixture | resident's leaf (base) | own leaf (this PR) | `ln R0′` moves |
|---|---|---|---|
| lma ×1 (identical) | 5.59643556916463 | 5.59643556916463 | −6.7e-16 from the resident (base −2.2e-16) |
| lma ×0.7 | 77.58 | 86.10 | +0.10 |
| lma ×0.9 | 22.14 | 26.32 | **+0.17** |
| lma ×1.1 | 0.0426 | 0.0900 | **+0.75** |
| lma ×2 | 1.450e-17 | 1.552e-17 | +0.07 |
| ×1 and ×0.9 together | refused: `expected 2, received 1` | 5.59643556916463, 26.3161466980631 | ×0.9 bit-identical to alone |

- The resident's `R0` is bit-identical on both builds (5.59643556916463). So is the 40-year
  long-drought resident (`J` 13.762607917, 9 262 steps, as PLANT-97 quotes). Its invaders run
  on both builds, and x0.7 now runs too:

  | long drought, invader on the resident's steps | PLANT-97 (resident's leaf) | this PR (own leaf) |
  |---|---|---|
  | lma ×0.9 | 61.0044 | 59.4899 |
  | lma ×1.2 | 0.0763684 | 0.0876754 |
  | lma ×0.7 | fails: leaf solve (`stem_curve_domain`) | 464.342 |

  - An earlier draft quoted `J` 13.276378401 and an invasion refused below empty. That run had
    `PLANT_LIB` unset, so the harness loaded the plant-dev submodule, not either build
    (`docs/prs/ld-invasion-debug.md`). `ld.R` now refuses a plant without the offset.
- **The fitness gradient, resident** (`test-tf24-fitness-gradient.R`). Both rows were checked
  against a pinned central difference over 14 columns, each row on its own scale.
  - Every column but lma and omega is within 1e-4 at a step of 1e-4. Measured: a_f1 2e-8, k_I
    3.8e-6, a_d0 1.3e-6, hmat 1.8e-5.
  - lma and omega set the seed height, whose root tolerance the difference reads. omega's error
    is 2.5e-2 at a step of 1e-5 and 7.8e-4 at 1e-3, so the two are held to 5e-3 at 1e-3.
  - S_D's column is the value over S_D, to 1e-12.
- **Equilibrium, the user's requirement.** Newton in `ln b` on `ln J − ln b`, starting from
  b = 10 and taking its slope from the birth-rate column:

  | run | b | `ln J − ln b` |
  |---|---|---|
  | 1 | 10 | 1.7 |
  | 2 | 30.70 | −0.47 |
  | 3 | 21.61 | −9.5e-3 |
  | 4 | 21.48 | 3.1e-4 |
  | 5 | 21.485 | 9.2e-7 |
  | 6 | 21.48496 | 2.0e-9 |

  - That is six runs and 12 s, with `d ln J/d ln b` = −0.7545 at b*.
  - Convergence is quadratic only once the step error is below the slope's. At the default
    `ode_tol` 1e-4 the adaptive map's own slope differs from the swept one by 5–10% (sweep
    −1.0997 against a pinned difference of −1.0997, and adaptive differences of −0.99 to
    −1.05). Newton then contracts by about 0.05 a run, and 1e-8 takes eight runs.
  - At b* the identical invader's `R0′ − 1` is 2.0e-9.
- **The invader's gradient at b*, against a central difference of invasions** (M2, step 1e-4):

  | invader | `R0′` | lma | hmat | k_I |
  |---|---|---|---|---|
  | ×0.9 | 8.98 | 1.2e-5 | 4.8e-8 | 3.0e-6 |
  | ×1.1 | 2.65e-7 | 8.2e-5 | 2.4e-6 | 4.1e-5 |

  At ×1.1 the errors fall as the square of the step, so they are the difference's truncation.
  A walk with its sweep takes 1.4–1.6 s.

### What it costs
- **Lines:** odelia +32/−9 in headers, +67 in its standalone test. plant +82/−24 in headers,
  and +248/−24 in tests (one new file of 159 lines).
- **Runtime:** a seeded walk copies each row once more when it keeps states, which upstream's
  recorded replay already did. It copies each row into the solver when it keeps none, a
  vector copy per step. Resident runs are unchanged.
- **References moved:** none. `reference-gradient.tsv` is untouched. The whole-run rung
  declares S_D uncaptured: its census column is zero by construction.
- **Interface:**
  - TF24 carries one more column per constant-birth-rate species;
  - `stand_gradient()` on TF24 defaults to five rows per species (the census and the fitness
    pair);
  - `stand_census_state_adjoint()` gains the fitness rows;
  - TF24 invaders' fitness changes.

### How it is tested
- **plant, full serial sweep on an installed `-O2` build** (odelia 0.8.1, phylloptim 0.10.2):
  5527 passed, 0 failed, 0 errors, 4 skipped, across all files. Two comment-only edits to
  `tf24_strategy.h` came after the build.
- **New and changed plant tests:**
  - `test-tf24-fitness-gradient.R`: names, the referee, Newton, the invader at b*;
  - `test-tf24-mutant-gradient.R`: two invaders, alone and together, plus the invader's fitness
    gradient against a difference;
  - `test-mutant.R`: both refusals;
  - `test-census.R` G6 and five ladder files read the census rows where they classify census
    zeros. S_D is declared zero in every rate, and the birth rate outside the cohort block.
- **odelia:** the standalone core check (`make -C tests/standalone`) passes, with the new
  seeded-walk test under both explicit steppers. That test checks four things:
  - the walk equals the program replay bit for bit;
  - each of a step's six evaluations is handed the run's row first;
  - its recording holds its own choices;
  - its sweep matches a central difference to 1e-8.

  `test-step-record.R`, `test-step-adjoint-recording.R` and `test-ode-solver.R` pass.

### What a reviewer should check
1. `Patch::store_solved` now also reads: it stands in a field the seeded row already holds.
   Check that no unseeded walk hands it a row with `field.kept` set. Every stepper clears its
   scratch row before an attempt that is not a replay.
2. `seeded_row_`'s lifetime in odelia. The patch's `loaded_field` points into it from one step
   to the next, and on to an insertion between them. After the walk it points into the SCM's
   solver, as it pointed into `resident_recording` before.
3. The introduction refusal compares exactly (`util::identical`) against the recording's
   insertion rows, as `introduced_at` does. A resumed resident's invader passes
   (`test-tf24-mutant-gradient.R`).
4. The birth-rate column is FF16's code repeated in TF24. Hoisting it into `Strategy` would move
   FF16 too, so it is left for a follow-up (review Q1).
