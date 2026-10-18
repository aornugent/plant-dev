# Where the refinement's time goes, and why the loop ran slower than round 5

Scripts in `perf/` beside this note; outputs in the scratchpad's `refine2perf/`. CPU is
user + system seconds of the R process (`proc.time()`); µs a row divides by the run's rows
(accepted steps × nodes alive at each step's start, the boundary node with them). One SCM
process of mine at a time; A and B interleaved under the same load and repeated.

## Part 1. The slowdown

### What the saved runs already say (before any new run)

Per-row CPU of runs that each had their own Rscript (round 5, 04:21–04:44, three lanes plus a
map run; the half-scale runs, 06:23–06:50, five cases started together on four cores):

| | forward µs a row (run / replay) | sweep µs a row (run / replay) |
|---|---|---|
| round 5, G5 / G5o | 140–172 / 97–114 | 318–351 / 314–336 |
| half scale, level 0 / replay / level 1 | 162–202 / 107–119 / 149–169 | 344–368 / 329–361 / 340–368 |

The half-scale runs were separate processes, yet their sweep cost 3–10% more a row than round
5's. Whatever slowed them was not in-memory running.

### Pre-registration 1 (before the A/B)

H1: in-memory running (a first run, then level 0 and its replay in one R process) is slower a
row than each run in its own process. H2: the excess is load, the schedules' rows and steps,
or both, and in-process state costs nothing measurable.

| | prediction | confidence |
|---|---|---|
| Q1 | on R22's node times, the loop's level 0 and replay reproduce a fresh process's J, steps and elasticities bit for bit | 90% |
| Q2 | the loop's level 0 and replay cost within 3% a row (forward and sweep each) of fresh processes, interleaved under the same load | 70% |
| Q3 | R22's runs have 1–6% more rows than round 5's G5/G5o, case by case | 50% |
| Q4 | the unexplained remainder of R22's 1.07–1.29× is load: the same runs now, under the coordinator's load, cost within 10% of round 5's a row | 50% |
