### Merge order
Stacked on #115 (top of the chain #94 ← #113 ← #114 ← #115 ← this). Needs odelia 0.8.2 (aornugent/odelia#58, linked at `f49e357`), which carries 0.8.1. It needs the storage pool (#113): without it, an invader that takes the resident's steps fails beyond about lma ×1.0001.

### The problem, in the model's terms
- An invader of a TF24 stand should optimise its own leaf in the resident's light and soil water. develop's invasion read the resident's recorded leaf operating point at every rate evaluation instead. The leaf solve is TF24's one inner optimisation, so the reported `R0′` was neither the invader's fitness nor its gradient.
- TF24 declared no fitness, so `stand_gradient()` gave its census only.
- The invasion applied each recorded introduction and nothing else, so a harvest or climate extreme never reached the invader (an identical invader read `ln R0′ − ln R0` = +0.69 under a 50% harvest and +1.3 under a lethal extreme), and an invader introduced at a time the resident did not use was never introduced. Both are now refused by name.

### What changes
- **odelia** (aornugent/odelia#58): `advance_recorded(rec, true)` copies each recorded row and hands the stages the copy.
- **plant** (+82/−24 in headers):
  - `Patch::store_solved` keeps the light environment the copied row already holds instead of rebuilding it;
  - `run_mutant` steps through the recording with copied rows, and refuses events and unmatched introductions before it changes anything;
  - TF24 gains the fitness flag, the `S_D` column and FF16's birth-rate column, line for line.

### Measured
A 6-year TF24 stand (hmat 6, 12 introductions, `ode_tol` 1e-6, resident at birth rate 10), measured on develop + #113 (odelia 0.7.3) against that + this change, before the stack was rebased:

| invader | resident's leaf (before) | own leaf (this PR) | `ln R0′` moves |
|---|---|---|---|
| lma ×1 (identical) | 5.59643556916463 | 5.59643556916463 | −6.7e-16 from the resident |
| lma ×0.7 | 77.58 | 86.10 | +0.10 |
| lma ×0.9 | 22.14 | 26.32 | +0.17 |
| lma ×1.1 | 0.0426 | 0.0900 | +0.75 |
| lma ×2 | 1.450e-17 | 1.552e-17 | +0.07 |
| ×1 and ×0.9 together | refused: `expected 2, received 1` | 5.59643556916463 and 26.3161466980631 | ×0.9 bit-identical to alone |

- The resident's `R0` is bit-identical on both builds. So is the 40-year long-drought resident (`J` 13.762607917, 9 262 steps). Its invaders on the resident's steps:

  | long drought | storage pool only (resident's leaf) | this PR (own leaf) |
  |---|---|---|
  | lma ×0.9 | 61.0044 | 59.4899 |
  | lma ×1.2 | 0.0763684 | 0.0876754 |
  | lma ×0.7 | fails in the leaf solve (`stem_curve_domain`) | 464.342 |

- **The resident's fitness gradient** (`test-tf24-fitness-gradient.R`), against a central difference on the run's own steps over 14 columns: every column but lma and omega within 1e-4 at a step of 1e-4 (a_f1 2e-8, k_I 3.8e-6, a_d0 1.3e-6, hmat 1.8e-5). lma and omega set the seed height, whose root-find tolerance the difference reads, so they are held to 5e-3 at a step of 1e-3. `S_D`'s column is the value over `S_D`, to 1e-12.
- **The resident's equilibrium birth rate**, on the full stack. Newton in `ln b` on `ln J − ln b`, from b = 10, its slope from the birth-rate column: `ln J − ln b` runs 1.7, −0.47, −3.4e-3, 8.3e-5, −6.1e-6, −1.2e-7, −2.4e-9, so seven runs reach b* = 21.49, where the identical invader's `R0′` is 1 to 1e-8. The swept slope is right: `dJ/db` = −0.741537 against −0.741545 from a central difference on the run's own steps. Convergence is linear (about 0.02 a run), not quadratic, because a difference between adaptive runs reads −0.7604, 2.5% off: the step controller's choices move `J` with b. The test checks convergence below 1e-8 within eight runs, not a run count.
- **The invader's gradient at b*,** against a central difference of invasions (step 1e-4):

  | invader | `R0′` | lma | hmat | k_I |
  |---|---|---|---|---|
  | ×0.9 | 8.98 | 1.2e-5 | 4.8e-8 | 3.0e-6 |
  | ×1.1 | 2.65e-7 | 8.2e-5 | 2.4e-6 | 4.1e-5 |

  At ×1.1 the errors fall as the square of the step, so they are the difference's truncation. An invasion with its reverse sweep takes 1.4–1.6 s.

### What it costs
- Lines: plant +82/−24 in headers, tests +248/−24 (one new file of 159 lines).
- Runtime: resident runs are unchanged; an invasion copies each row once per step.
- References: none moved. `reference-gradient.tsv` is untouched; the whole-run check declares `S_D` not captured, since its census column is zero by construction.
- Interface: TF24 carries one more column per constant-birth-rate species; `stand_gradient()` on TF24 defaults to five rows per species (the census and the fitness pair); `stand_census_state_adjoint()` gains the fitness rows; TF24 invaders' fitness changes.

### Tests
- `test-tf24-fitness-gradient.R` (new): names, the central-difference check, Newton to b*, the invader at b*.
- `test-tf24-mutant-gradient.R`: two invaders, alone and together, and the invader's fitness gradient against a difference.
- `test-mutant.R`: both refusals.
- `test-census.R` and five finite-difference files read the census rows where they classify census zeros.
- Full serial suite on the full stack (#94 + #113 + #114 + #115 + this change), `-O2`, odelia 0.8.2: 5564 passed, 0 failed, 7 skipped (opt-in and report tests).
- `test-scm.R`: #115's substepped-soil test now checks the census and fitness rows together against the tangent replay and the central difference.

### For review
1. `Patch::store_solved` now also reads: it keeps a light environment the copied row already holds. No pass without copies may hand it a row with `field.kept` set; every stepper clears its scratch row before an attempt that is not a replay.
2. The patch's `loaded_field` points into odelia's `seeded_row_` from one step to the next, and to an insertion between them; after the invasion it points into the SCM's solver.
3. The introduction refusal compares exactly (`util::identical`) against the recording's insertion rows. A resumed resident's invader passes.
4. The birth-rate column is FF16's code repeated in TF24. Moving it into `Strategy` would touch FF16 too, so it is left for a follow-up.

---
_Generated by [Claude Code](https://claude.ai/code)_
