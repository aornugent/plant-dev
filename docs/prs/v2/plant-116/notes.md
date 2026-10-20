# plant-116 notes: every number and where it came from

Builds (`-O2`, `R CMD INSTALL --strip`, sources from `git archive`, deleted
after each install; `scratchpad/v2/build.sh`), phylloptim 0.10.2 (edaffe8):

- **B105** = origin/PLANT-105 762ad2fc (#115, this PR's base), odelia 0.8.1
  from ODELIA-55 (bfa32cf).
- **B95** = origin/PLANT-95 6ba51da1 (this PR's head), odelia 0.8.2 from
  ODELIA-56 (6c62da2).

Libraries `/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/v2/B105` and `.../v2/B95`.
Scripts and data: `docs/prs/v2/figures/plant-116/`. The stand is
`fixture.R`, a copy of `fitness_stand_parameters()`,
`fitness_stand_environment()` and the control of
`tests/testthat/test-tf24-fitness-gradient.R` at 6ba51da1.

CPU is `proc.time()` user + system, one R process at a time.

| number | source |
|---|---|
| Newton output in the snippet (b from 10 to 21.49367148 in seven runs) and the invader at lma x0.9 (`lma_factor`, through `TF24_hyperpar`): R0' 8.978231, d R0'/d lma −2543.109, d R0'/d hmat −4.490476 | `wholegame-run.R` via `source(echo = TRUE)` on B95; log `scratchpad/v2/out/wg116.log` |
| base: `Unknown metric: 1.offspring_production`; two invaders `Incorrect length input; expected 2, received 1`; x0.9 alone R0' 7.216445 (B105) against 8.978231 (B95) | `base-run.R` on B105 and B95; logs `out/base116-B105.log`, `out/base116-B95.log` |
| Newton per run at ode_tol 1e-6 and 1e-4; b* 21.49367145 (1e-6), 21.49386854 (1e-4); last ratios 0.020, 0.020, 0.018; at 1e-4 the residual sits between 1.2e-10 and 6.9e-10 from run 7 | `newton-run.R <tol>` → `newton.csv`; `newton.R` → `newton.png` |
| at b*: d ln J/d ln b swept −0.741537, pinned-step difference −0.741544, adaptive difference −0.760361 (2.5%); predicted contraction 0.011 | `slope-run.R` (B95), log `out/slope116.log` |
| landscape: lma alone scaled (every other parameter the resident's), 0.5 to 2, 41 log-spaced points plus 0.95-1.10 by 0.0025; resident J 21.4936714535 and its own-invader ln R0' 5.63e-11 on both builds, 246 steps | `landscape-run.R` on B95 (`GRADIENT=1`) and B105 → `landscape.csv`; `landscape.R` → `landscape.png` |
| ln R0' gain from the own leaf: 0.018 to 0.599 below the resident's lma; largest 1.654 at x1.028 | `landscape.R` output |
| sweep against central difference (step 1e-4 in ln lma), d ln R0'/d ln lma: x0.6 −3.433668/−3.433626; x0.8 −5.935217/−5.935164; x0.95 −14.224283/−14.224378; x1.0 −122.476/−116.899 (4.8%); x1.02 −352.458/−351.677 (2.2e-3); x1.05 −192.2188/−192.2152; x1.25 −51.9319/−51.9313; x1.6 −32.9989/−32.9993 | `landscape.csv` columns `dlnR0_dlnlma`, `central_difference` |
| invasion with its sweep: 1.2-1.3 s CPU | `landscape.csv` column `cpu_s` at the gradient points |
| an earlier landscape built with `fitness_stand_parameters(1, x)`, i.e. through `TF24_hyperpar`, read the sweep 1.3-2x off the curve: the curve then moves every trait the map ties to lma, the column only lma | `scratchpad/v2/out/landscape-hyperpar.csv` |
| `reference-gradient.tsv` unchanged by this PR (identical at 762ad2fc and 6ba51da1) | `git diff` |
| file line counts | `git diff --numstat 762ad2fc 6ba51da1` |

Full test suite on B95 (serial, installed package, `scratchpad/v2/runtests.R` over the PLANT-95 worktree's `tests/testthat` at the same commit): 5569 passed, 0 failed, 0 errors, 4 skipped. Log `scratchpad/v2/out/tests-B95.log`.
