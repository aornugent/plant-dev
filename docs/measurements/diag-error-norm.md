# Error-norm diagnostics on the TF24 adaptive solver

Fixture (both diagnostics): `scm_base_parameters("TF24")`, one strategy
(`lma = 0.0825`), `max_patch_lifetime = 5`, default `control()`, RKCK 4(5),
`tol_abs = tol_rel = 1e-8`, `a_y = 1`, `a_dydt = 0`. Two forcings:

* **constant** — `extrinsic_drivers_set_constant("rainfall", 3.0)`
* **semiarid** — the pulsed daily series from `probe7_rain.R` (seed 24), tiled
  across the patch lifetime.

Build: `odelia` installed from source, `plant` compiled with `make compile`
(`-O2`), run serially with `TESTTHAT_PARALLEL="false"`.

## State layout

At each accepted step the patch state is

```
[ node 0 | node 1 | ... | node n-1 | environment ]
```

Each node block is **8** entries — 6 individual states, then
`offspring_produced_survival_weighted`, then `log_density`. The environment
block is **10**: the 5 soil-moisture layers followed by 5 cumulative-flux
accumulators (rainfall, infiltration, deep drainage, root uptake, pulse runoff).
The prompt's "5 soil-water states" are the 5 moisture layers; the 5
accumulators sit beside them and are reported separately below. Runs reach 88
nodes, so the environment is 10 of ~714 components at the end.

## Instrumentation

`OdeControl::adjust_step_size` already reduces `err_i = |yerr_i| / (tol_abs +
tol_rel*|y_i|)` with an infinity norm; it now also keeps the index attaining
that max and the ratio, and `push_step` copies both onto the step's recorded
row (`step_record::error_index` / `error_ratio`). A step that forms no error
estimate (`step_to`, `step_by`, `step_euler`) names no component. `plant`
surfaces the two fields on each `scm$store_trajectory()` row, so they are
carried by the row that already carries that step's time, size and state — no
second container to mispair. Committed to `odelia` as
`2e172e3 Record which component set each step's size`, with coverage in
`tests/standalone/r_free.cpp`.

Cost: two numbers per accepted step on a record that already exists, and one
index assignment inside the loop that was already computing the max. Reading
them needs `record_trajectory`, which is off by default.

The `plant` side is seven lines in `inst/include/plant/scm.h`
(`r_store_trajectory`) and is **left uncommitted in the working tree**: `plant`
is on a detached HEAD at `origin/ad/reverse-mode`, and the commit asked for was
`odelia`'s. Both packages are built from these sources as the diagnostics left
them.

## Diagnostic A — which component binds the step

`diagA_binding.R`. Every accepted step of a full run, classified by the
component that attained the max.

| binding component | constant (530 steps) | semiarid (1017 steps) |
|---|---|---|
| soil moisture layer 1 | 11 (2.1%) | 219 (21.5%) |
| soil moisture layer 2 | 9 (1.7%) | 169 (16.6%) |
| soil moisture layer 3 | 4 (0.8%) | 106 (10.4%) |
| soil moisture layer 4 | 11 (2.1%) | 79 (7.8%) |
| soil moisture layer 5 | **410 (77.4%)** | 131 (12.9%) |
| the 5 flux accumulators | 0 | 0 |
| **all member states** | **85 (16.0%)** | **313 (30.8%)** |
| *of which* `log_density` | 70 (82.4% of member steps) | 202 (64.5%) |
| *of which* individual states | 15 (17.6%) | 111 (35.5%) |

Member-binding steps, by where the binding node's density sits among the nodes
present at that step (decile 1 = lowest density, 10 = highest):

| decile | constant | semiarid |
|---|---|---|
| 1 (lowest density) | 19 (22.4%) | 115 (36.7%) |
| 2–9 | 56 (65.9%) | 52 (16.6%) |
| 10 (highest density) | 7 (8.2%) | 143 (45.7%) |
| single-node steps | 3 | 3 |

Binding-node `log_density` runs from the −750 floor (a numerically extinct
cohort) to ≈ 0. Node log densities over the whole run: 1.9% of node-steps
(constant) and 1.0% (semiarid) are below −100, i.e. extinct; the 5th percentile
is −8.3 (constant) and −3.5 (semiarid).

**Verdict (A).** The small block binds. Under constant rainfall the deepest
soil-moisture layer alone sets 77% of all steps and the moisture block sets
84%; members set 16%. Under pulsed rainfall the impulses spread the load across
all five moisture layers — layer 1 (the layer the pulse lands in) rises from 2%
to 22% and the deepest layer falls from 77% to 13% — and the moisture block
still sets 69% of steps against the members' 31%. The flux accumulators never
bind. Within the member share it is mostly `log_density`, and the binding node
is drawn from both tails: the lowest-density decile takes 22% (constant) and
37% (semiarid) of member-binding steps, so vanishing members do bind, but they
account for only 3.6% and 11.3% of *all* steps. The newest, highest-density
node takes another 46% of the member share under pulsed forcing.

## Diagnostic B — upper bound on member-side reweighting

Same fixture, with the components of every node whose `log_density` is below a
threshold dropped from the error norm entirely (not merely loosened). `1e9`
drops **every** node component, which is the ceiling on any member-side
reweighting whatsoever. Wall time is the faster of two runs in a fresh process
per cell; the functional is `sum(scm$offspring_production)`.

**constant rainfall**

| vanishing defined as | node-steps dropped | accepted steps | Δ steps | wall (s) | offspring |
|---|---|---|---|---|---|
| — (baseline) | 0% | 530 | — | 6.80 | 9.467652e-07 |
| `log_density < -100` | 1.9% | 528 | −0.4% | 6.67 | 9.467678e-07 |
| `log_density < -5` | 7.8% | 528 | −0.4% | 7.33 | 9.467678e-07 |
| `log_density < -2` | 12.0% | 527 | −0.6% | 7.07 | 9.467989e-07 |
| **every node component** | 100% | **529** | **−0.2%** | 7.01 | 9.467970e-07 |

**semiarid (pulsed) rainfall**

| vanishing defined as | node-steps dropped | accepted steps | Δ steps | wall (s) | offspring |
|---|---|---|---|---|---|
| — (baseline) | 0% | 1017 | — | 13.95 | 5.840208e-11 |
| `log_density < -100` | 1.0% | 1006 | −1.1% | 13.94 | 3.731609e-11 |
| `log_density < -5` | 1.0% | 1006 | −1.1% | 13.60 | 3.731609e-11 |
| `log_density < -2` | 39.9% | 1007 | −1.0% | 13.44 | 3.771573e-11 |
| **every node component** | 100% | **1008** | **−0.9%** | 14.10 | 2.790985e-11 |

The mask was checked to bite: with every node component dropped, 100% of
measured steps are named as bound by the environment block (84% / 69% in the
baselines), and the functional moves, so the norm really did change.

**Verdict (B).** Member-side reweighting of the error norm buys essentially
nothing. Removing *every* member state from the norm — an upper bound no
reweighting scheme can beat — changes the accepted step count by 0.2% under
constant rainfall and 0.9% under pulsed rainfall, and the result is flat in the
threshold: dropping 1% of node-steps and dropping 100% of them give the same
answer to within a step or two. The reason is visible in the norm's shape: it
is an infinity norm, and when the binding member is removed the soil block is
immediately behind it at nearly the same ratio, so the fifth-root step-size
response `h ∝ rmax^(-1/5)` has almost nothing to work with. Wall time is
unchanged within noise, and the modified runs additionally pay for the mask, so
the step count is the number to trust, not the seconds. The functional does
move (up to 2.1× under pulsed forcing) because these integrations are
deliberately wrong — that is the price of the bound, not a result.

Sensitivity is therefore visible and flat across all three thresholds plus the
ceiling: **the gain available from any member-side reweighting is under 1% of
steps.** Anything that is going to shorten this run has to act on the
soil-moisture block.

## Guard runs

* `odelia` standalone core (`make test-cpp`): all checks pass, including the
  ten new ones covering the recorded binding component.
* `odelia` R suite: 315 pass, 5 fail — all in `test-implicit-value.R`, all
  `Rcpp::sourceCpp` failing to build the snippet. Pre-existing: the same five
  fail with the change stashed.
* `plant` fast sweep, 39 of 42 files: no failures.
* `plant` heavy files: `test-strategy-tf24.R` 80 pass, `test-strategy-tf24f.R`
  58 pass, `test-mutant.R` 2 fail / 22 pass. Those two failures are
  pre-existing: `odelia` was rolled back to the parent commit, both packages
  rebuilt, and `test-mutant.R` fails identically (the deviations are ~2e-5
  relative against recorded references, where a change that alters no
  arithmetic would give bit identity).

## Files

* `diagA_binding.R` — Diagnostic A (writes `diagA.rds`)
* `densprofile.R` — node log-density distribution, which fixes B's thresholds
* `diagB_cell.R`, `diagB_bound.sh` — Diagnostic B (writes `diagB.csv`)
* `diagB_verify.R` — checks the skip mask actually removes the members
* `smoke_errnorm.R` — the new fields reach R
* `diagB-skip-mask.patch`, `apply_B_patch.py` — the temporary B modification
  (`OdeControl::skip` + `Patch::ode_error_skip`), applied, measured and
  reverted. Not committed: it is experimental scaffolding for a bound, not a
  diagnostic worth keeping.
