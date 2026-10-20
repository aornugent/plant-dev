# plant-113 notes: every number and where it came from

Builds (all `-O2`, R CMD INSTALL --strip, sources exported with `git archive`
and deleted after each install; script `scratchpad/v2/build.sh`):

- **B93** = origin/PLANT-93 77e15141 (#94, this PR's base), odelia 0.7.3
  (traitecoevo/odelia@88cbff7), phylloptim 0.10.2 (edaffe8).
- **B97** = origin/PLANT-97 eb12399e (this PR's head), same odelia and
  phylloptim.

Libraries: `/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/v2/B93`, `.../v2/B97`
(phylloptim in `.../v2/phyllo`, needed at compile time only).

Rejected attempts come from a measurement probe, `scratchpad/v2/probe/rejections.cpp`
(loaded by `probe/load_probe.R`): compiled with `sourceCpp` against each
library's own plant/odelia headers, it reads `SCM::solver.get_n_rejections()`
(odelia's cumulative count of rejected attempts, both error-estimate and
domain rejections) through the R object's external pointer. Not part of any PR.

CPU is `proc.time()` user + system, one R process at a time, nothing else
of mine running; another agent built odelia/phylloptim at `nice 19` during
some runs.

Scripts and data are in `docs/prs/v2/figures/plant-113/`.

## Comment 1

| number | source |
|---|---|
| snippet outputs (base and branch) | `snippet.R`, run as `PLANT_LIB=<lib> Rscript -e "source('snippet.R', echo = TRUE)"` from the plant-dev root; logs `scratchpad/v2/out/snip113-B93.log`, `snip113-B97.log` |
| J 12.417261203 (base), 12.662188249 (branch); accepted 10 516 / 9266; rejected 2635 / 2033 | `wholegame-run.R B93|B97`, logs `out/wg113-B93.log`, `out/wg113-B97.log`; also row 1 of each in `offset-run.csv` |
| invaders x2, x1.2, x0.9 refused on base (`TF24 storage is negative`), run on branch (J' 1.86508e-21, 0.0690826, 57.1785) | `wholegame-run.R` |
| record: 14 965 days, mean 3.000 m/yr, 9.5% wet days, 2931 knots in (0, 40) | `record.R` output; `length(AK)` from `harness/long_drought.R` |
| record figure | `record.R` → `record.png`, `record.csv` |
| reference-gradient.tsv: 1400 rows → 1430 (30 new), 89 move by > 1e-3 of the largest |converged| for their regime and metric; by parameter theta 29, omega 27, a_bio 22; seasonal species 2 theta on leaf_area 308.94 → −1639.04 | `git show <commit>:tests/testthat/reference/reference-gradient.tsv` at 77e15141 and eb12399e, compared in R (inline script in the session; merge on regime/species/parameter/metric) |
| stochastic count 77 → 79 (77 at offset 0) | the diff of `test-stochastic-patch-runner.R` |
| file line counts | `git diff --numstat 77e15141 eb12399e` |

## Comment 2

| number | source |
|---|---|
| Cash-Karp: |R(−x)| ≤ 1 to x = 3.7343; stages non-negative to 2.1593 | `relax.R` (5th-order weights c1 c3 c4 c6 and GSL's tableau, as in odelia's `ode_step_rkck.hpp`) |
| 26 d and 15 d at o = 7 d | 3.73 × 7, 2.16 × 7 |
| seedling λ: median 9, 99th pct 476, max 811 /yr (3366 cohort-stops, height < 1 m, t ≤ 12) | `relax-run.R` (B97) → `relax-run.csv` |
| step sizes median 0.45 d, 90th pct 4.48 d | `offset-run.R synthetic 7` on B97, columns `median_step_d`, `p90_step_d` |
| 304 /yr | 3.7343 / (4.48/365) |
| cohort born 2.963 yr; P < 0 from t = 3.5573; r 0.472 there; r = 0.05 after 8.61 d (o = 0) and 21.44 d (o = 7); offset-7 integration vs run max |dr| 1.51e-05; peak relaxation 345 /yr (25.4 h) at o = 0, 45 /yr at 7 d | `cohort-run.R` (B97; stops every 6 h from 3.36 to 3.80 yr as zero-depth pulses) → `cohort-run.csv`; `cohort.R` → `cohort.png`, `cohort.csv` |
| offset sweep: all counts, J, invader outcomes | `offset-run.R <scenario> <offset|base> offset-run.csv`, run serially by `scratchpad/v2/queue.sh` (first pass) and `queue4.sh` (repeats); `offset.R` → `offset.png`, `offset.csv` |
| B97 offset 0 on the synthetic record: J 12.494, accepted 10 261, rejected 2572 | `offset-run.csv` |
| ln J moves at 7 d vs 0: seasonal +0.0695 (+7.2%), synthetic +0.0134, drought −0.0072, wet −0.0032, shaded −0.0029, clamped −0.0029 | `offset.csv` |
| invader x2 on the synthetic record: refused on base; density overflow at 0, 1, 3 d; runs at 7, 14, 28 d | `offset-run.csv`, column `invader_x2` |

## Detail cut from the PR text

What happens to a stage below empty, and to a step that ends there:

```
  odelia step (Cash-Karp, six stages)
    └─ TF24_Strategy::compute_rates, storage < 0 at a stage
         base:   util::stop_domain("TF24 storage is negative ...")
         branch: rates finite; numerator charge - (charge + drain) r > 0
    ├─ adaptive resident step: base, the throw rejects the attempt;
    │    branch, the error estimate rejects an inaccurate attempt and
    │    Patch::ode_state_valid() (non_negative_states(): storage) an end
    │    below empty; both retry smaller
    ├─ fixed-size step (advance_fixed): either refusal subdivides the interval
    └─ invasion: a recorded step cannot shrink, so a refusal stops it
```

| old | new |
|---|---|
| TF24 scientific_version 11, TF24f 11.1 | 12, 12.1 |
| `TF24_Strategy()$pars` | gains `storage_relaxation_offset` = 7/365 yr, a gradient column |
| `storage_domain_tol` | gone, with the stage check |
| J at 7 d against the base | synthetic record +2.0%; regimes wet −0.3%, drought −0.7%, seasonal +7.2%, shaded −0.3%, clamped −0.3% |
| `storage_relaxation_offset = 0` | v11's rates; a run where the old check fired steps differently (synthetic record: J 12.494 against the base's 12.417) |

Other references re-captured on the branch (from its diff): the
"offspring arrival" five-year values, TF24's seeded stochastic count
77 → 79 (77 at offset 0, tested), the model-version snapshot.
`reference-gradient.tsv`: 89 rows move (wet 8, drought 19, seasonal 28,
shaded 16, clamped 18; theta 29, omega 27, a_bio 22), largest relative
move 1.19 of scale (seasonal, species 2, theta, leaf_area, 308.9 → −1639.0),
drought's largest 0.63.

The cohort: production falls through zero over weeks, so at first λ is
small at either offset; at offset 0 the fastest the pool relaxes in the
40 days shown is 345 /yr (25 h), at 7 d 45 /yr. The 19.4 d of the
branch's NEWS entry, o ln(a_st3 a_dG2), assumes production drops at
once from r = a_st3; this cohort runs down in 8.6 d at offset 0, not
hours, because its production drifts down.

Full test suite on B97 (serial, installed package, `scratchpad/v2/runtests.R` over the PLANT-97 worktree's `tests/testthat` at the same commit): 5468 passed, 0 failed, 0 errors, 4 skipped. Log `scratchpad/v2/out/tests-B97.log`.

## Offset sweep, repeats

Every configuration ran three times (first pass in `queue.sh`, two more in
`queue4.sh`); counts and J are identical across repeats. CPU medians at 7 d
against 0: synthetic 43.445 / 47.025 s (−7.6%), wet 3.684 / 3.750, drought
0.821 / 0.934, seasonal 4.013 / 4.291, shaded 5.065 / 5.890, clamped 4.155 /
5.691 (−27%). Spread of the three runs: up to 18% above and 7% below their
median. Base (B93) medians: synthetic 46.757 s, wet 3.766, drought 0.911,
seasonal 4.342, shaded 5.835, clamped 5.511.
