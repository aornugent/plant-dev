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

### P1-A. In memory against a fresh process, same node times, libS (`ab.R`, `chain1.sh`) [m]

episodic-lma on R22's level-0 schedule (205 nodes) and its replay (117). A: level 0 in one
Rscript, the replay in a second, pinned to the first's steps (round 5's structure). B: the
loop's sequence in one Rscript (first run, level 0, replay; `stand_run` from `refine.R`). Order
A, B, A, B, 21:00–21:38, load average 3.4 rising to 7.5 (the coordinator's two loops and two
other investigations' runs; all four cores busy, 3% stolen).

| | A rep 1 | B rep 1 | A rep 2 | B rep 2 | B / A (mean) |
|---|---|---|---|---|---|
| level 0 forward, µs a row | 217.1 | 231.1 | 229.5 | 217.3 | 1.004 |
| level 0 sweep, µs a row | 483.1 | 483.9 | 493.2 | 474.7 | 0.982 |
| replay forward, µs a row | 167.8 | 167.0 | 163.5 | 170.8 | 1.011 |
| replay sweep, µs a row | 492.0 | 514.2 | 476.9 | 484.6 | 1.030 |
| run + replay CPU, s | 426.2 | 436.8 | 430.6 | 421.9 | 1.002 (pairs +2.5%, −2.0%) |

- J, the step times and all 50 elasticities are identical (`identical()`) between A and B,
  level 0 and replay: 3661 steps, 394 258 and 227 432 rows. Q1 holds.
- Running in one process costs nothing measurable: +0.2% on run + replay, the pairs straddling
  zero by ±2.5%. Q2 holds. The resident set grows 125 → 474 MiB over B's three runs (C++ frees
  are not returned), with no effect on CPU.
- **The same fresh-process work now costs 1.40–1.53× round 5's a row** (forward 217–230 µs
  against 155; sweep 483–493 against 323), and 1.2–1.3× R22's own in-memory runs on these
  exact rows (R22: forward 181, sweep 378; replay 126 / 393). Identical library, node times,
  steps, code path and process structure: the per-row price moved with the machine's state
  alone, by more than R22's 1.07–1.29×.

### P1-B. R22's rows and price a row, all five cases (`ab.R fwd`) [m]

R22's level-0 schedules re-run forward only on libS (22:10–22:40, load 8–12) for their exact
steps and rows; the replay's rows follow from level 0's steps. R22's CPU from the saved fits.

| case | steps R22 / r5 | rows: run, replay (R22 against r5) | R22 µs a row: fwd / sweep / replay fwd / replay sweep | / round 5's | run + replay / r5, rows held |
|---|---|---|---|---|---|
| dry | 4838 / 4795 | −0.3%, −0.1% | 170 / 383 / 121 / 389 | 1.12 / 1.14 / 1.24 / 1.19 | 1.16 |
| long-wet | 5447 / 5449 | +1.7%, +1.9% | 186 / 382 / 126 / 362 | 1.13 / 1.18 / 1.17 / 1.12 | 1.15 |
| episodic-lma | 3661 / 3650 | +2.0%, +2.6% | 181 / 378 / 126 / 393 | 1.17 / 1.17 / 1.24 / 1.22 | 1.19 |
| dry-flat | 7149 / 7210 | −2.1%, −2.4% | 198 / 383 / 113 / 349 | 1.15 / 1.09 / 0.99 / 1.04 | 1.08 |
| epi-adG208 | 3764 / 3794 | −0.2%, +0.1% | 167 / 375 / 121 / 393 | 1.19 / 1.18 / 1.22 / 1.25 | 1.21 |

- The schedules are not the cause: rows differ by −2.4% to +2.6% (Q3 fails as worded: three
  cases have fewer rows, not more). Holding rows at R22's, the price a row alone is 1.08–1.21×
  round 5's.
- The three cases started first (11:38, beside each other) are 1.16–1.21×; dry-flat, run last
  beside long-wet, is 1.08×.
- The same separate-process forward on these rows costs 222–273 µs a row today (22:10–22:40),
  1.3–1.6× round 5's 140–172, at load averages from 7.6 to 12.

### P1-C. What the price a row follows (`probe.c`, `probe_loop.sh`) [m]

Per-row CPU of identical work is flat in the guest's load once all four cores are busy: level 0's
forward on episodic-lma cost 217, 231, 230, 217 µs at load averages 3.4, 5.9, 7.1, 7.3. A fixed
probe every two minutes (a dependent floating-point chain, and a pointer chase over 64 MiB) reads
the chain within 3% (0.735–0.758 s) while the chase moves 1.01–1.25 s between consecutive
minutes: the cores' speed holds, the memory system's latency does not. The sweep tapes about
33 KB a member evaluation and the leaf solves walk per-plant tables, so a run is exposed to
what shares the last-level cache and memory with it, inside the guest or outside it (3% stolen).

### Root cause of the slowdown

Not the loop's in-memory running. On identical node times, library and steps, running the first
run, level 0 and the replay in one R process costs the same as separate processes (+0.2%,
pairs ±2.5%), with identical numbers; the scm objects kept alive, R's heap and the 125 → 474 MiB
resident growth change nothing; `record_trajectory` is on in both, `store_trajectory` runs only in
the first run, the control and events are the same objects (identical J, steps and 50
elasticities). The schedules differ by ±2.5% in rows. What remains is the machine's price a
row, which moved 1.08–1.21× between round 5 (04:21) and R22 (11:38) and is 1.3–1.6× round 5's
today, with nothing in the process changed. A CPU second is not a fixed unit of work on this
host: comparisons across sessions need A and B interleaved, or a count that ignores the
machine (rows, member evaluations, or callgrind's instructions).

Scored: Q1 holds; Q2 holds; Q3 fails (rows −2.4% to +2.6%); Q4 fails as worded (today's runs
cost 1.3–1.6× round 5's a row, not within 10%), and what it was testing holds in a stronger
form: the machine's state moves the price by more than the 1.07–1.29× it was asked to explain.

## Part 2. Where a refinement's time goes on libNS

### The profile (`prof.R`, `prof.sh`) [m]

gperftools at 250 Hz over the loop's three runs on episodic-lma, libNS, R22's node times
(first run, level 0 with its sweep, replay with its sweep, one process): 118 573 samples, 474 s.
CPU: first run 36.8 s (8%), level 0 94.3 + 198.5 s (62%), replay 37.3 + 101.8 s (29%). The
sweep is 64% of the whole, the forward 36%. R outside the model (building the SCM, reading
records, `store_trajectory` and its decoding in R) is under 0.4%.

| where | samples | share of its phase | share of the loop |
|---|---|---|---|
| **forward** (`SCM::run`) | 42 432 | 100% | 35.8% |
| · the leaf solve (`find_root_collar_psi_for`) | 37 281 | 87.9% | 31.4% |
| · · its collar search (`maximise_profit_over_collar`) | 29 372 | 69.2% | 24.8% |
| · · its bounds (`prepare_collar_solve`) | 5 172 | 12.2% | 4.4% |
| · crown light quadrature | 981 | 2.3% | 0.8% |
| **sweep** (`solve_adjoint`) | 75 669 | 100% | 63.8% |
| · taping the six stages (`step_adjoint`'s recording) | 61 793 | 81.7% | 52.1% |
| · · crown light quadrature on the tape (`QK::integrate`) | 13 382 | 17.7% | 11.3% |
| · · collar coordinates on the tape (`collar_at`) | 11 298 | 14.9% | 9.5% |
| · · the operating point re-derived at double (`evaluate_root_collar_psi_for`) | 6 913 | 9.1% | 5.8% |
| · · the collar slope by central difference (`marginal_collar_slope`) | 6 676 | 8.8% | 5.6% |
| · · the split pieces (`split_as_recorded`) | 5 038 | 6.7% | 4.2% |
| · the reverse pass (`sweep_each_seed`) | 12 300 | 16.3% | 10.4% |

Call counts from callgrind on a six-year cut of the same case (`cg_cut.R`, `cg_calls.py`;
forward and sweep): 44 473 collar searches made 575 524 marginal evaluations, 11.8 each, of which
9.8 are toms748 iterations (436 416 bracket calls) and two are the bracket's ends. Every root
in the leaf is solved to round-off (`within_roundoff`, 4 ulp): the collar search from the full
feasible interval every time, the inner `psi_stem_to_ci` and `find_root_psi` roots in 7.0
iterations each. Nothing carries a root from one evaluation of a plant to the next.

### Pre-registration 2 (before the prototypes)

Two prototypes, the largest lever that is a few lines and the cheapest one. W: each forward
collar search first tries a narrow bracket (± `w` × the feasible width) around the collar the
same plant's solve found in the previous rate evaluation, and falls back to today's search when
that bracket does not straddle an interior root (`ws/`: 16 lines in phylloptim's
`maximise_profit_over_collar`, 30 in plant's `leaf_solved_points` and `solve_leaf`; `w` read
from `PLANT_HINT_WIDTH`, unset = off, so A and B are one binary). F: the first run at a looser
tolerance (R only).

| | prediction | confidence |
|---|---|---|
| W0 | with the hint off, the prototype reproduces libNS's J, steps and elasticities bit for bit | 90% |
| W1 | at w = 1e-3, marginal evaluations per collar search fall from 11.8 to 7 or fewer | 60% |
| W2 | the forward's CPU falls 25–40%, the loop's total 9–14% | 50% |
| W3 | ln J and every elasticity move by under 0.01ε (the roots agree to round-off either way) | 70% |
| F1 | the first run at 1e-3 costs 40–60% less, builds the same node counts, and moves no node by more than 5% of its spacing | 50% |
