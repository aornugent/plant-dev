# Probes for report 13

Measurements behind
[`docs/reports/13-carried-state-invalidates-the-compression-term.md`](../docs/reports/13-carried-state-invalidates-the-compression-term.md).
Run from the `plant-dev` root with `plant` installed from
`claude/nsc-density-measurements-efiolz`. `lib.R` holds the shared helpers: a collecting
SCM whose per-step `Patch` and `Environment` can be interrogated, and `patch_operators()`,
which evaluates the candidate compression terms on one patch state. `40-lib.R` holds the
refinement loop for the `schedule_eps` sweep, checked against `SCM::refine_schedule` by
`41-validate.R`.

Numbering is the order the work was done, not the order of the report; two agents worked
concurrently, so a few numbers appear twice with distinct names. Output names in `out/` do
not always match the script that wrote them, so the tables give the mapping where it
matters.

## The result (§1)

| script | establishes |
|---|---|
| `01-baseline.R` | the three baselines, and the collected histories the rest reads |
| `13-arms.R` | forward runs of both coordinates; the default reproduces `develop` exactly |
| `14-refine.R` | midpoint refinement, so both arms see byte-identical schedules → `refine.rds` |
| `43-fixed-series.R` | the 141/281/561/1121 series and the Richardson limits → §1's table |
| `53-ht-k3.R` | the 1121-introduction point for the height arm |
| `22-decouple.R`, `23-decouple-l2.R` | the store integrated but read by nothing → §1's third test |

## Why the height coordinate fails (§2)

| script | establishes |
|---|---|
| `07-operators.R` | the three candidate transport terms on one patch state |
| `08-through-run.R` | the three through the whole run, and the gap-closing census → §2.1 |
| `09-window.R` | the recruitment window decomposition → `window-TF24.rds`, §2.2, Figures 4 and 6 |
| `16-eps.R` | the perturbation is resolved and still wrong → Appendix B |
| `36-boundary.R` | which quadrature `compute_competition` evaluates, and its closing trapezium |

## The derivation and the excluded alternatives (Appendices A, C, D)

| script | establishes |
|---|---|
| `03-conserve2.R` | conservation on interior intervals only → Appendix C |
| `04-driftrate.R` | drift rate against gap width: quadrature error on FF16, not on TF24 |
| `05-divergence.R` | the omitted term does **not** diverge at a growth stall |
| `06-analytic.R` | the closed form `(1 − G) f /(w · S_max)` → Appendix A |

## Where the error reaches demography (§4, §6.2)

| script | establishes |
|---|---|
| `17-stand.R` | stand structure under each coordinate → `stand.rds`, §4, Figure 5 |
| `27-excess.R` | the corrected arm's leaf-area convergence → `excess-scm.rds`, §6.2 |

## The individual-based comparison (Appendix E)

The chain that found the oracle's frozen environment, in the order it was walked:

| script | establishes |
|---|---|
| `37-perind.R` | the two solvers disagree per individual, not in aggregate |
| `41-open.R` | the SCM outgrows free growth in an open canopy — so it is the environment |
| `51-env.R` | the rates differ at an identical state under the two environments |
| `53-soiltraj.R` | the SCM's soil water recharges to 0.310613 and falls to 0.299220 |
| `52-wetibm.R` | supplying that soil water collapses a 12–16% gap to ≤1% |
| `32-trunc-validate.R` | truncating at age 3.5 reproduces the stored trajectories bit-for-bit |
| `35-regular.R` | regular arrivals remove recruitment stochasticity |
| `33-bigens.R`, `34-fit.R` | `excess(A) = b + c/A`: nonlinear averaging **refuted** |
| `55-interp.R` | the snapshot artefact, 16.3% at 4 m² against 0.015% at 128 m² |
| `56-oracle128.R` | the soil-corrected oracle → `56-oracle128.rds`, Figure 2 |
| `54-final-table.R` | Appendix E's table → `54-final.rds` |
| `39-storage-ic.R` | stochastic seedlings are born with an empty store |

## Cost, convergence and robustness (§6)

| script | establishes |
|---|---|
| `25-storage-bound.R` | the storage excursion is a step overshoot no tolerance removes → §6.1 |
| `26-stress.R` | the seasonal sweep, and the 66 cohort crossings → §6.3 and §2.1 |
| `24-refine-adaptive.R` | adaptive refinement completes in both coordinates → §6.4's table |
| `40-lib.R`, `41-validate.R` | the R refinement loop, and that it matches `SCM::refine_schedule` |
| `42-eps-sweep.R`, `44-ff16-control.R` | the `schedule_eps` Pareto sweep and its FF16/K93 controls |
| `46-criterion-scale.R`, `49-scale-analyse.R` | the criterion is affine-invariant, so no eps remapping exists |
| `50-stall.R` | bisection does not reduce the height arm's flagged errors → §6.4 |
| `47-analyse.R`, `48-report.R` | assembly → `48-report.rds`, §6.4 and Figure 1 |
| `28-timing.R`, `29-timing-l1.R` | fixed-schedule timings at 141 and 281 introductions → §6.5 |
| `55-timing.R` | wall clock at the adaptive operating points → `55-timing.rds`, §6.5 |
| `56-repro.R` | state survives `SCM::reset()`, asymmetrically → §6.6 |

## Figures

`30-figures.R` regenerates all six figures in `docs/reports/figures/` from collected
output. It runs no simulation and ends with 72 assertions against the report's own tables,
exiting non-zero if any value disagrees. `PLANT_FIG_FORMAT=png` forces PNG instead of SVG.

## Two conventions that matter

Refinement is by midpoint insertion into `node_schedule_times`, never
`refine_schedule = TRUE`, so both coordinates see byte-identical schedules at each level.
Timings are only meaningful on an idle machine — check `ps -eo cmd | grep -c '[e]xec/R'`
returns zero first; the repeat spread should be about 1% at a fixed schedule.

Large collected histories are gitignored (see `out/.gitignore`); rerun `01-baseline.R` to
regenerate them.
