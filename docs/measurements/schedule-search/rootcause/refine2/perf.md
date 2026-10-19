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

### F. The first run at a looser tolerance (`first_tol.R`, libNS) [m]

| case | tol | steps | CPU | nodes / replay nodes | spell edges | t50, t90 moved |
|---|---|---|---|---|---|---|
| episodic-lma | 1e-4 | 3338 | 34.1 s | 205 / 117 | 72 | |
| | 3e-4 | 2529 | 25.9 s | 204 / 116 | 70 | +0.6 d, +5.5 d |
| | 1e-3 | 1936 | 20.6 s | 204 / 116 | 68 | +1.3 d, +2.1 d |
| dry | 1e-4 | 4412 | 44.5 s | 230 / 152 | 140 | |
| | 3e-4 | 3226 | 34.0 s | 230 / 152 | 142 | +0.5 d, +6.1 d; nodes move up to 10 d (median spacing 46 d) |
| | 1e-3 | 2339 | 23.5 s | 228 / 150 | 136 | +5.7 d, −1.2 d |

The first run is 4–8% of a refinement; at 1e-3 it costs 40–47% less, about 2–3% of the whole,
and the schedule changes in structure (spell edges appear and vanish, node counts change). F1
fails on the node counts. Not worth it: the saving is small and the schedule it builds would
need re-scoring.

### W. A warm-started collar search (`ws/`, `ws_check.R`, callgrind on the cut) [m]

- **W0 holds.** Hint off, the prototype gives libNS's J, steps and every elasticity
  bit for bit (six-year cut, `identical()`).
- **The roots agree to round-off.** With the steps held (the hinted run replays the unhinted
  run's steps), J agrees to 8e-15 and the elasticities to 4e-11 relative, and the operating
  point kinds are counted the same (25 281 interior, 3 320 at the soil bound). Unpinned, the
  controller turns those last-bit differences into different steps (641 → 635–647 on the cut),
  so J moves by 1e-4 relative there: a hinted run is a different-steps run, with R21's
  step-change noise (up to 0.19ε, rms 0.034ε on dry) and not round-off.
- **Counts (callgrind, six-year cut, forward and sweep):**

| hint width w | collar searches | marginal evaluations each | toms748 iterations each | forward instructions a row | whole cut |
|---|---|---|---|---|---|
| off | 44 473 | 12.9 | 9.8 | 1.670 M | 26.79 G |
| 1e-5 | 43 020 | 14.2 | 9.6 | 1.747 M (+4.6%) | 26.88 G |
| 1e-3 | 43 704 | 10.4 | 6.7 | 1.458 M (−12.7%) | 25.57 G |
| 1e-2 | 44 005 | 9.8 | 6.4 | 1.419 M (−15.0%) | 25.42 G (−5.1%) |

  W1 fails: from a bracket around the last root, toms748 still takes 6.4 iterations, because it
  stops at 4 ulp; the hint saves three iterations and pays two end evaluations. Too narrow a
  bracket (1e-5) misses and falls back, costing more than nothing.
- **Full runs (`chain_ws.sh`, `ws_score.R`):** episodic-lma, R22's level 0 and replay in one
  process, w = 1e-2, arms off, on, on, off (23:13–23:50, load 3–6):

| arm | level 0 fwd / sweep (s) | replay fwd / sweep (s) | total | steps |
|---|---|---|---|---|
| off | 83.4 / 171.1 | 37.7 / 100.6 | 392.9 | 3645 |
| on | 72.3 / 165.4 | 31.3 / 104.7 | 373.7 | 3676 |
| on | 68.7 / 164.2 | 30.6 / 90.7 | 354.3 | 3676 |
| off | 82.3 / 174.9 | 35.0 / 94.6 | 386.8 | 3645 |

  The forward costs 0.851 of the unhinted (pairs 0.856, 0.847), the sweep is unchanged (0.97,
  pairs 0.99 and 0.95), and run + replay costs **0.934** (pairs 0.951, 0.916). The hinted runs'
  quantities move from the unhinted by 0.037ε at worst at level 0 (a_l1; rms 0.009) and 0.052ε
  in the replay, and the replay's estimate e by 0.007ε at worst: the step-change noise, a fifth
  of R21's. W2 fails (forward −15%, not −25 to −40%; total −6.6%, not −9 to −14%); W3 fails as
  worded (0.05ε, not 0.01ε), for the reason above.

### R. The roots solved to a relative 1e-10 instead of 4 ulp (`ws2/`, `root_tolerance.patch`) [m]

Every toms748 root in the leaf stops at `within_roundoff`, 4 ulp. A second prototype makes
that tolerance settable (`PLANT_ROOT_RELTOL`, 6 lines in phylloptim's `uniroot.hpp`; unset =
today), built with W into its own library. Not pre-registered as a prediction; measured on the
cut by callgrind, and with the steps held for what it does to the numbers.

| six-year cut | forward instructions a row | marginal evaluations a search | with the steps held: J, worst elasticity moved | kinds |
|---|---|---|---|---|
| today | 1.670 M | 12.9 | | |
| W (w = 1e-2) | 1.419 M (−15.0%) | 9.8 | 8e-15, 4e-11 relative | same |
| R 1e-10 | 1.554 M (−7.0%) | 11.7 | 2e-11, 4e-9 absolute | same |
| W + R 1e-10 | 1.268 M (−24.0%) | 8.3 | 2e-11, 4e-9 absolute | same |
| W + R 1e-8 | 1.220 M (−26.9%) | 8.1 | 9e-9, **2.3e-3 absolute** | **differ** |

The sweep's instructions a row do not move (3.30–3.34 M in every arm). At 1e-8 the
elasticities move by up to 0.2ε with the steps held and operating points change kind, so the
leaf's bounds and the implicit derivatives need more than eight digits of the root; 1e-10
moves nothing measurable and is the setting tested on full runs below.

Pre-registration 3 (written while the full runs below were running, before reading any):

| | prediction | confidence |
|---|---|---|
| R1 | W + R 1e-10 costs 0.75–0.82 of today's forward on full runs, 0.90–0.93 of run + replay | 55% |
| R2 | its quantities move from today's by under 0.06ε (the step-change noise W showed) | 70% |

Full runs (`chain_ws2.sh`), episodic-lma, W (w = 1e-2) + R 1e-10, arms off, on, on, off
(00:00–01:00, load 3.5–5):

| arm | level 0 fwd / sweep (s) | replay fwd / sweep (s) | total | steps |
|---|---|---|---|---|
| off | 79.4 / 168.8 | 35.7 / 98.8 | 382.7 | 3645 |
| on | 65.2 / 168.6 | 27.5 / 98.7 | 360.1 | 3656 |
| on | 65.3 / 168.9 | 26.6 / 98.3 | 359.1 | 3656 |
| off | 85.8 / 163.2 | 37.0 / 102.5 | 388.7 | 3645 |

- The forward costs **0.776** of today's (pairs 0.806, 0.748), the sweep 1.002 (pairs 0.999,
  1.005), run + replay **0.932** (pairs 0.941, 0.924). R1 holds on the forward and narrowly misses
  on the total (0.932 against 0.90–0.93).
- The quantities move by up to 0.133ε (TF24_cost_scale; rms 0.059) at level 0 and 0.100ε in the
  replay, but the replay's estimate e by 0.011ε at worst: the replay is pinned to level 0's steps,
  so the step change is common to both and cancels in e. R2 fails (0.13ε against 0.06ε). With
  the steps held the same change moves nothing beyond 4e-9 (above), so this is the controller's
  step-change noise, within R21's 0.19ε, and not the roots.
- W's own full-run sweep ratio (0.97) was noise: the sweep does not move under either prototype,
  so W alone is worth about 1 − 0.36 × 0.15 ≈ 0.95 of a run + replay and W + R about 0.92–0.93.
