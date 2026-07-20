# TF24 solver baseline — the numbers to beat

**Canonical baseline: global explicit RK (`ode_method="rkck"`), `ode_tol_rel =
ode_tol_abs = 1e-6`** (the converged-J tolerance; see the recharacterization doc
for the convergence evidence — J is bit-stable by ~1e-5–1e-6, and 1e-8 only hits a
resolution wall at 47× cost). Measured on the real coupled
`Solver<Patch<TF24,TF24_Environment>>` over the canonical bank
(`scripts/tf24-benchmarks/data/*.rds`), single species except `multispecies`.

Any candidate integrator (event-aware RK, etc.) must:
1. **Match accuracy in J-units:** reproduce the baseline `offspring` per scenario to
   within the J-tolerance (J amplifies coupling error ~10×, so hold offspring rel.
   error ≲ 1e-2, ideally ≲ 1e-3). Accuracy is non-negotiable; speed at wrong J is
   meaningless.
2. **Beat cost:** fewer accepted steps and (the real target) a lower **reject
   fraction** and wall time. The baseline wastes ~27–35% of attempts on rejection
   bisection — that is the headroom.
3. **Fix the failure:** `multispecies` currently **fails non-finite** — a candidate
   must make it *complete* (the multi-block correctness item), not just be faster.

## Baseline (rkck, tol 1e-6) — recorded 2026-07-19

| scenario | horizon (yr) | offspring (J ref) | accepted | rejected | **reject frac** | RHS evals | wall (s) | status |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| dry_to_wet | 25 | 1.910e-05 | 15 035 | 6 705 | 0.308 | 130 443 | 316 | ok |
| long_horizon | 70 | 2.341e-03 | 60 926 | 22 812 | 0.272 | 502 431 | 1 339 | ok |
| extended_drought | 30 | 3.242e-06 | 14 301 | 5 928 | 0.293 | 121 377 | 273 | ok |
| intense_storms | 20 | 1.281e-05 | 9 377 | 3 864 | 0.292 | 79 449 | 177 | ok |
| multispecies | 40 | — | 3 660 | 1 943 | 0.347 | — | — | **FAILS: non-finite** |
| whiplash | 24 | 2.476e-06 | 10 331 | 4 039 | 0.281 | 86 223 | 191 | ok |

`min h / T ≈ 1.4e-8–5.0e-8` across all (scattered collapse). Attribution and full
methodology in `RESULTS.md`. `offspring` is `sum(offspring_production)`.

## Cached artifacts (the data behind the numbers — do not regenerate to compare)

- `data/*.rds` — the six rainfall sequences (+ `_manifest.rds`). Regenerable via
  `generate_bank.R` but **committed so comparisons use identical inputs**.
- `results/event_sizing_summary.{csv,rds}` — the table above + attribution columns.
- `results/<scenario>_summary.rds` — per-scenario rows.
- `results/multispecies_steplog.rds` — the full step-attempt log at the non-finite
  failure (the Q3 diagnostic: h growing → H1/overflow, not stiffness).
- Timings are wall-clock at `-O2` (`options(pkg.build_extra_flags=FALSE)` +
  `pkgload::load_all`); treat wall as ±20% machine-dependent, but accepted/rejected
  step counts and RHS-eval counts are **deterministic** and are the primary
  cost metric.

## How to re-measure a candidate

`Rscript scripts/tf24-benchmarks/event_sizing.R` runs the bank with the step log;
point it at the candidate `ode_method` and compare offspring (accuracy) + reject
fraction / accepted steps / RHS evals (cost) against this table. Keep this file as
the frozen reference; append candidate rows below with date + method, never
overwrite the baseline.
