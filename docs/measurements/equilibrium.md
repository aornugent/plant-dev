# The stand at its demographic equilibrium

**Why.** Every TF24 number measured before this was taken at a birth rate of 1,
where the long-drought stand's `J` is 12.67, about thirteen times what holds it
steady. regnans's analyses run the resident at `b*`, where `J(b*) = b*`, and
reach it by repeating the run. This measures what that costs, what a run at
`b*` is, and how regnans's own plant calls fare on this plant. Pre-registered
in `equilibrium/prereg.txt` before each run; the design it serves is
`docs/design-workflows.md`.

**Configuration.** Long drought, its own seed, 40 years, `lma = 0.32`, 108
uniform introductions held, steps adapting at `1e-4` with the absolute tolerance
tied (`ATOL=1e-4`), the birth-date coordinate, splits at sign changes on, a
zero-depth pulse at each active knot. Built from odelia `ODELIA-54` 373f5b9,
plant `PLANT-103` 4f45b702 and phylloptim `PHYLLOPTIM-17` (`lib_sw`). Each job
alone on the 4-core machine.

**Scripts.** `harness/equilibrium.R` by `equilibrium/run.sh`, read by
`equilibrium/analyze.R`; regnans's root-finders by `harness/regnans_solvers.R`
and the replay by `harness/equilibrium_replay.R`, both by
`equilibrium/run_solvers.sh`; the costs of the design's reference analysis by
`equilibrium/costs.R`; regnans's plant calls by `equilibrium/seam.R`. Logs
beside them.

## Key numbers

| | |
|---|---|
| **The equilibrium** | `b* = 4.6593190` on long drought, where `J(1) = 12.67` |
| **By a secant in `ln b`** | 6 runs from `b = 1` to `|ln J − ln b| = 5.4e-8` |
| **By iterating `b ← J(b)`** | 8 runs reach 0.35; it contracts by 0.76 a run, alternating in sign, so about 47 runs would reach 1e-5 |
| `d ln J / d ln b` at `b*` | −0.762, from the secant's last two runs |
| A forward at `b*` | 91 s adaptive, 14 972 steps, 10 841 node steps split (9 247 at `b = 1`) |
| The stand's sweep at `b*` | 261 s, 2.9 forwards |
| A walk, one invader | 70 s, 0.77 of a forward; five together 350 s, 5.0 walks |
| The invader's sweep | 200 s, 2.2 forwards; with its walk, 3.0 |
| `lma`'s elasticity at `b*` | stand −9.96 (−8.28 at `b = 1`); invader, the field held, −37.1 |
| `d ln b* / d ln lma` | −5.65, from the stand's elasticity and the secant's slope |
| A replay of `b*`'s own program | 74 s, 0.82 of the adaptive run, which attempted 18 433 steps for 14 972; `J` the same to the twelve digits printed |
| Moved 1% in `lma` | replay and adaptive agree to 1.4e-5 in `ln J` |
| The implicit function theorem's warm start | `|ln J − ln b|` 0.0025 at the moved birth rate, against 0.10 at `b*` held |
| The reference analysis, in forwards at `b*` | regnans's iteration 530; a secant 80; with the grid replayed 74; with sweeps for every gradient 85 (`costs.log`) |

## Against the predictions

- **P1 holds:** the secant reached `|f| < 1e-5` in 6 runs (at most 8 registered).
  Each run was 85–91 s, and `J(b)` on adaptive steps showed no noise down to
  5.4e-8.
- **P2 holds:** iteration's `|f|` fell 2.54, 1.84, 1.43, 1.06, 0.82, 0.61, 0.47,
  0.35, ratios 0.73–0.78, against the secant's slope's 0.76. At that rate it
  needs about 47 runs to `1e-5`, 7.8 times the secant's.
- **P3 holds:** a run at `b*` took 91 s against 86 s at `b = 1` (+6%), with 127
  more steps and 1 594 more node steps split.
- **P4 holds:** five invaders walked together cost 5.0 times one.
- **P5 fails:** the invader at the stand's own traits walked at a birth rate of
  1 has `J′ = 0.999924`, against `J(b*)/b* = 1.0000000538`: −7.6e-5, not within
  1e-6. The registered hypothesis for the gap, tested below, is that walks never
  split while the stand's run split 10 841 node steps.
- **P6 holds:** with `lma` moved 1% alone, `|ln J − ln b|` was 0.102 at `b*` held
  and 0.0025 at `b*` moved by `d ln b*/d ln lma = −5.65`, a fortieth.
- **P7 holds in part.** The stand's sweep costs 2.88 forwards (at most 4) and the
  invader's 2.86 walks (at most 3.5). The five-invader sweep could not be
  measured: it fails at once with `Incorrect length node_schedule_times`, while
  the one-invader sweep runs. The cause is below.
- **P10 holds:** the replay at `b*` cost 0.82 of the adaptive run (at most 0.85)
  and reproduced `J` to the twelve digits printed.
- **P11 holds:** at `lma` ×1.01 the replay's `ln J` and the adaptive run's differ
  by 1.4e-5, against 8.4e-4 registered.

## A sweep after a walk of several invaders

`stand_gradient` after `scm$run_mutant` with two or more invaders raises
`Incorrect length node_schedule_times`, reproduced on an 8-year stand in
seconds. The forward walk is right; the sweep never starts.
- *Where:* the sweep lifts the patch to the active scalar with
  `Patch::rebind_from`, which copies the patch's stored
  `parameters.node_schedule_times` beside strategies taken from its species.
  `Parameters::validate()` then refuses the pair.
- *Why they disagree:* `SCM::run_mutant` gives the patch the invaders'
  strategies (`Patch::overwrite_strategies`) but leaves the patch's stored
  parameters on the resident's, one schedule. With one invader for one resident
  the lengths happen to agree, which is why every sweep so far ran.
- *Since:* `61af9238`, "Carry the model at the caller's scalar", on `PLANT-95`.
  `develop` has neither the rebind nor the failure.
- *The fix at its source:* the patch takes the invaders' parameters whole, so
  its parameters and its species cannot disagree.
- *Checked:* `equilibrium/walked_patch_fix.patch` does that
  (`Patch::overwrite_parameters` in place of `overwrite_strategies`, its one
  caller `run_mutant`) and adds a test to `test-scm.R`. On a one-year stand one
  sweep of a two-invader walk gives each invader the gradient it gets walked
  alone, to 1e-12; on the build without it the same test raises the error. The
  five-invader sweep's cost at `b*`, P7's last clause, waits for the fix to land.

## The invader at the stand's own traits

- **P12 holds:** with splits off, the invader walked at a birth rate of 1 has
  `J′ = J(b*)/b*` to 6.7e-16 (0.999945976417 both). With them on the gap is
  −7.61e-5, as in P5: the stand split 10 841 node steps and the walk none, since
  a split's stages fall where no field was recorded. So P5's gap is the walk's
  unsplit error at the stand's own traits: 0.003ε of `ln J`.
- **P13 holds:** walked at a birth rate of 0, as regnans walks its mutants, the
  invader's `net_reproduction_ratios` equals the birth-rate-1 walk's `J′` exactly,
  split or not, and its offspring production is 0. regnans's convention reads
  `R′` correctly on this plant; a sweep of that walk's offspring production
  would be a sweep of zero.

## regnans's own root-finders

- **P8 fails:** regnans's `nleqslv` path, Broyden on `ln b` with its target
  `J/b − 1`, reached `|ln J − ln b| = 3.7e-7` in 12 runs, against the 10
  registered and the secant's 6 (`equilibrium/nleqslv.log`). Its first four runs
  sit at `b = 1`: regnans's check that the species is kept, nleqslv's own
  evaluation of the start, and a difference Jacobian whose step, 1.5e-8, moves
  `J` by 1e-7. Then its steps on `J/b − 1`, which is exponential in `ln b`, fall
  short from far away: `b` 1.83, 2.47, 3.37, 4.09, 4.52, 4.64, 4.6589, 4.65932.
- **P9 holds:** `dfsane` reached `|ln J − ln b| = 4.2e-8` in 12 runs (at most 15
  registered; `equilibrium/dfsane.log`). Its first two runs sit at `b = 1`, its
  first move goes the wrong way, to `b = 0.37`, and its second to `e`; from there
  it closes in. Both of regnans's root-finders take twice the secant's runs.
