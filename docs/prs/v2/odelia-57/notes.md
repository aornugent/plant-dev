# odelia-57 notes: every number and where it came from

Measured 2026-10-19 on this machine, run under `nice -n 19`, at most two
processes at a time. Counts only; no timings.

## Builds

- odelia ODELIA-55 at bfa32cf (0.8.1), worktree
  `scratchpad/v2own/od_55`, installed into `scratchpad/v2own/lib_od81`
  with `R CMD INSTALL --no-test-load -l lib_od81 od_55` (MAKEFLAGS=-j1),
  build objects removed afterwards.
- odelia master at 1e0f0f0 (0.8.0) into `lib_od80` the same way.

`scratchpad` is
`/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad`.

## Comment 1, the whole game

Script `figures/odelia-57/whole_game.R`, run from `od_55` with
`R_LIBS=../lib_od81 Rscript -e 'source("<path>/whole_game.R", echo = TRUE)'`:

| number | value |
|---|---|
| plain steps, tol 1e-6, t = 2 | 1700 |
| substepped steps | 77 |
| plain max abs error vs plain at 1e-12 | 1.772702e-06 |
| substepped max abs error | 9.378705e-09 |
| substeps per substepped step | 81.46753 |

Rate-evaluation counts, `counted_run()` in
`figures/odelia-57/toy_module.R` (the test's System with counters added
by text substitution), printed by `figures/odelia-57/counts.R`:

| run | steps | whole-System evaluations | store's own evaluations |
|---|---|---|---|
| plain, tol 1e-6 | 1700 | 12 188 | 0 |
| substepped, share 0.1, tol 1e-6 | 77 | 518 | 136 836 |

## GCC 13

`scratchpad/v2own/gcc/run.sh`: `git archive` of `inst/include` and
`tests/standalone/r_free.cpp` at each commit, then
`g++ -std=c++20 -O0 -w -I../../inst/include -c -o /dev/null r_free.cpp`
(g++ 13.3.0, Ubuntu 13.3.0-6ubuntu2~24.04.1):

| commit | result |
|---|---|
| 1e0f0f0 (master) | exit 0 |
| b707d21 | `r_free.cpp:1452:1: internal compiler error: in gimplify_var_or_parm_decl, at gimplify.cc:3059` |
| bfa32cf | exit 0 |

The current PR comment says the internal compiler error happens on
master too. It does not: master compiles.

`tests/standalone` at bfa32cf, `make CXX=clang++`: `all checks passed`
(`scratchpad/v2own/checks/o55_standalone.log`).

## Figure one_step

`figures/odelia-57/one_step.R` (data `one_step.csv`), run from `od_55`
with `R_LIBS=../lib_od81`. Step 54 of the substepped run at tol 1e-6
(the step starting nearest t = 1), replayed alone from its recorded
start with a log of every rate call.

| number | value |
|---|---|
| step start, size | t = 1.01907, h = 0.0444549 |
| plain Cash–Karp step size near there (median of steps within ±0.05) | 0.00117033 |
| ratio | 38 |
| substeps | 134; sizes 0.00064 to 0.0080 of the step, mean 0.0075 |
| predictor end w1 (stage at t + h) | 0.154483013935 |
| corrector end w1 | 0.154483083219 |
| reference end w1 (plain, 1e-12) | 0.154483082945 |
| plain Cash–Karp at this h: w1 at stages 3/5, 1, 7/8; end | 0.244, −21.3, −12 498; −2.0e10 |

## Figure steps_vs_stiffness

`figures/odelia-57/steps_vs_stiffness.R` (data `steps_vs_stiffness.csv`,
the matched selection `steps_vs_stiffness_matched.csv`). K in
10^seq(1, 5, 0.5); each arm at tol 10^seq(-3, -10, -0.5); reference plain
at 1e-12; the matched point is the fewest steps with max abs error
<= 1e-6.

The table in comment 2 is `steps_vs_stiffness_matched.csv` (K = 10,
100, 316, 1e3, 1e4, 1e5). The orders (error against step count, fitted
over tol 1e-6 to 1e-10) and the errors at tol 1e-6 come from
`steps_vs_stiffness.csv` with:

```r
d <- read.csv("steps_vs_stiffness.csv")
do.call(rbind, lapply(split(d, list(d$K, d$arm)), function(x) {
  x <- x[x$tol <= 1e-6, ]
  data.frame(K = x$K[1], arm = x$arm[1],
             err_at_1e6 = x$error[abs(log10(x$tol) + 6) < 1e-9],
             order = -coef(lm(log(error) ~ log(steps), x))[2])
}))
```

substepped order 1.74 to 2.63 over all K; plain 5.72 to 6.13 for K up
to 1e3 (7.2 to 9.9 above, where its steps are set by stability). Error
at tol 1e-6: K = 1e4 substepped 9.38e-9; K = 10 substepped 5.38e-5,
plain 6.07e-7.

Store evaluations against whole-System evaluations, substepped, matched:
171 771 / 14 918 = 11.5 at K = 10 to 275 784 / 170 = 1622 at K = 1e5.

## Tests

`testthat::test_file("tests/testthat/test-substeps.R")` from `od_55`
against `lib_od81`: ten tests, no failures
(`scratchpad/v2own/checks/o55_substeps.log`). The full R suite was not
re-run; the current comment's "729 pass and 2 errors" is not repeated.

## Not carried over from the current PR text

- The plant table (15 376 / 7 313 / 6 370 steps on the 40-year stand,
  the elasticities, 0.45x and 0.37x) is plant's measurement and was
  not re-measured here; comment 1 points at aornugent/plant#115.
- "Headers +580/−71": `git diff --numstat origin/master origin/ODELIA-55`
  gives +590/−71 over the five headers.
- "links this branch's head (`b707d21`)": the head is bfa32cf; the
  headers are the same at both.
