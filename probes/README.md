# Probes for report 12

Run from the `plant-dev` root with `plant` installed from
`claude/nsc-density-measurements-efiolz`. `lib.R` holds the shared helpers: a
collecting SCM whose per-step `Patch` (and its `Environment`) can be
interrogated, and `patch_operators()`, which evaluates the three candidate
compression terms on one patch state.

| script | what it establishes |
|---|---|
| `01-baseline.R` | Baselines on `develop`, reproducing report 10's figures |
| `02-conserve.R` `03-conserve2.R` | Count conservation; the lowest interval is excluded because plants flow into it |
| `04-driftrate.R` | Drift per unit time against gap width: quadrature error on FF16, not on TF24 |
| `05-divergence.R` `06-analytic.R` | The omitted term's closed form, and that it does not diverge at a stall |
| `07-operators.R` `08-through-run.R` `09-window.R` | The three operators through the run, and the recruitment window |
| `12-oracle.R` | The individual-based solver as an external oracle |
| `13-arms.R` `14-refine.R` | Forward runs and refinement in both coordinates |
| `16-eps.R` | The probe is resolved; its error is not resolution |
| `17-stand.R` `18-adjudicate.R` | Stand structure, the birth boundary, and the oracle comparison |
| `40-lib.R` `41-validate.R` | Refinement loop re-driven from R (traced per iteration); checked bit-identical to `SCM::refine_schedule` |
| `42-eps-sweep.R` `44-ff16-control.R` | The `schedule_eps` accuracy/cost Pareto sweep, TF24 and the FF16/K93 controls |
| `43-fixed-series.R` `53-ht-k3.R` | Fixed-schedule convergence series (141 -> 1121) and the Richardson limits |
| `46-criterion-scale.R` `49-scale-analyse.R` | Both error metrics evaluated on the same state: the criterion's coordinate rescaling |
| `50-stall.R` | Which nodes stay flagged pass by pass; the height arm's error is not reducible by bisection |
| `48-report.R` | Assembles the Pareto tables, limits, node placement and matched-accuracy verdict |
| `55-timing.R` `56-repro.R` | Idle-machine wall clock at the operating points; run-to-run reproducibility |

Large collected histories are gitignored (see `out/.gitignore`); rerun
`01-baseline.R` to regenerate them.
