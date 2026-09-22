# Schedule refinement vs time integration on TF24

Every cell of the plan completed. Nothing failed, nothing hit the per-cell budget,
and no code was changed.

## Headline

The two error sources do not compare the same way under the two forcings, and the
reason is that **under pulsed forcing at `ode_tol = 1e-4` nothing is converged, so
nothing separates.**

- **Constant rainfall 3.0.** The schedule is the dominant error by 3.5 to 4.5 orders
  of magnitude: the default 88-node schedule carries ~1.0% (height) / ~0.24%
  (birth-date) against an ODE time error of 3.7e-6 / 6.6e-8 over 1e-4 -> 1e-6 —
  **2700x** and **36000x** larger respectively.
  And **at the default `schedule_eps = 2e-2` refinement never fires at all** — the
  largest per-node error is 0.0099, half the threshold — so on this problem every
  "unrefined" number in the workspace was already its "refined" number.
- **Semi-arid pulsed at `ode_tol = 1e-4`.** Refinement moves the answer -65%
  (height) / +57% (birth-date), a uniform halving of the schedule moves it -34%
  (height) and +5% then a further -65% (birth-date), and the tolerance sweep moves
  it +16% / +78%. All of them are tens of
  percent, in every direction, and the refinement trajectory swings over a factor
  of 3-5 while reporting `converged = TRUE`.
- **Semi-arid pulsed at `ode_tol = 1e-5` or tighter.** The schedule shift collapses
  to **-0.17% / -0.22% (height)** and **-0.14% (birth-date)**, with flat
  trajectories. So the huge numbers at 1e-4 are the time error being re-rolled each
  time an introduction time lands on a different rain pulse — not schedule error.
- **The prior 57% survives refinement.** On its own scenario the gap J(1e-4) vs
  J(1e-6) goes from -56.8% unrefined to **-46.2%** with both sides refined.
  Refinement removes about a fifth of it; the rest is genuine time error.
- **Cost** is ~7-10 full model runs (the refinement loop converged in 7-10
  iterations everywhere), for +10% nodes and +1-5% ODE steps in the final run.
- **`schedule_eps = 2e-2` is too loose** under constant forcing: it leaves ~1%
  (height) / ~0.24% (birth-date) on the table against an ODE error of ~1e-6.
  `eps = 1e-3` costs 127 / 117 nodes and 3 runs and lands within 0.13% / 0.05% of a
  349-node uniform grid.

## Method

TF24, one strategy at `lma = 0.0825`, `max_patch_lifetime = 5`, `-O2` build
(`cd plant && make`; the `.so` was already current and nothing recompiled), serial,
`TESTTHAT_PARALLEL=false`. Environment and semi-arid rainfall generator taken
verbatim from `probe7_rain.R`; constant forcing is `rainfall = 3.0`. The functional
is `sum(scm$offspring_production)`. The default schedule is 88 nodes
(`node_schedule_times_default(5)`).

**No code was changed.** `plant` and `odelia` working trees are clean at
`claude/trusting-curie-4i9n3l` (`5321593a` / `be3e2cb`), so the `make test-cpp` /
fast-sweep guard did not apply and was not run.

Scripts, all in this scratchpad:

| file | what |
|---|---|
| `sched_common.R` | environment, SCM construction, per-cell census |
| `sched_refine.R` | the refinement loop driven one iteration at a time from R |
| `sched_cell.R` | job runner for the crossed grid (`sched_<job>.rds` / `.log`) |
| `sched_fg57.R` | the fixed-grid spike's own "semi-arid pulsed" scenario |
| `sched_uniform.R` | global bisection of the schedule, no error signal |
| `sched_report.R` | RDS -> the tables below (`sched_all.rds`) |

### How refinement is reached

`run_scm(p, env, ctrl, refine_schedule = TRUE)` exists and works
(`plant/R/scm_support.R:79`, used by `plant/R/benchmark.R:25`); it calls
`scm$refine_schedule()`, the C++ loop at `plant/inst/include/plant/scm.h:774`. The
task's description is accurate. Two findings around it:

1. **`control$schedule_verbose` is a dead field.** Declared
   (`plant/inst/include/plant/control.h:85`), defaulted (`plant/src/control.cpp:51`),
   serialised through `RcppR6_post.hpp`, pinned by the `model-version` snapshot and
   asserted in `tests/testthat/test-control.R:29` — and **read by nothing**.
   `refine_schedule()` prints nothing at any setting, so the refinement trajectory
   is not observable from the C++ entry point.
2. **The loop was therefore re-driven from R**, one iteration at a time
   (`sched_refine.R`), mirroring `SCM::refine_schedule()`: run, flag nodes whose
   `refinement_error_by_node` exceeds `schedule_eps`, bisect the interval *below*
   each flagged node, install, repeat. One mechanical difference: the R setter
   `scm$set_node_schedule_times()` refuses while the finished patch still holds
   nodes (`"Cannot set schedule without resetting first"`, `scm.h:924`), so the loop
   calls `scm$reset()` first — which `run()` does anyway.

   **Verified identical to the C++ path** on `semiarid / tol 1e-4 / height`:
   `scm$refine_schedule()` gives `2.02571e-11`, 97 nodes, 1052 steps; the R loop
   gives `2.0257103e-11`, 97 nodes, 1052 steps.

`scm$ode_step_attempts` is present and works; it reports
`accepted / accepted_at_minimum / rejected_inaccurate / rejected_thrown /
rejected_refused`. `accepted_at_minimum` and `rejected_refused` were 0 in every
cell measured here.

### Two caveats about `refine_schedule()`

- The loop runs *first* and bisects *after*. If it exits by exhausting
  `schedule_nsteps` rather than by converging, the schedule it installs (and writes
  into `parameters$node_schedule_times`) was **never run** — the offspring number
  left on the object came from the run one bisection coarser. On this problem every
  cell converged by the error test within 10 iterations, well inside
  `schedule_nsteps = 20`, so this never bit; the tables below still report the last
  *completed run* alongside the installed node count, and they agree everywhere.
- During refinement `parameters.node_schedule_times` is left stale (it is written
  only at the end), so `reset()` feeds `patch.set_introduction_times()` the original
  default schedule on every iteration. That copy is read only by the
  replay/reshape path, not by a forward run, which is why the C++ loop and the
  R-driven loop (which keeps it in sync) agree bit for bit. Worth knowing before
  anyone replays a run taken during refinement.

## Q1 — how big is the schedule error relative to the time error?

### The 2x2x3 grid, `schedule_eps = 2e-2` (default)

`steps` is `length(scm$ode_step_sizes)` (includes t=0, hence `accepted` + 1).

| forcing | coord | ode_tol | schedule | offspring | nodes | steps | accepted | rej inacc | rej thrown | iters | wall |
|---|---|---|---|---|---|---|---|---|---|---|---|
| constant | height | 1e-4 | unrefined | 9.46765e-07 | 88 | 531 | 530 | 97 | 27 | — | 7.9 s |
| constant | height | 1e-4 | refined | 9.46765e-07 | 88 | 531 | 530 | 97 | 27 | 1 | 7.1 s |
| constant | height | 1e-5 | unrefined | 9.46749e-07 | 88 | 615 | 614 | 281 | 9 | — | 10.4 s |
| constant | height | 1e-5 | refined | 9.46749e-07 | 88 | 615 | 614 | 281 | 9 | 1 | 10.8 s |
| constant | height | 1e-6 | unrefined | 9.46769e-07 | 88 | 790 | 789 | 386 | 5 | — | 13.7 s |
| constant | height | 1e-6 | refined | 9.46769e-07 | 88 | 790 | 789 | 386 | 5 | 1 | 14.0 s |
| constant | birth-date | 1e-4 | unrefined | 7.05485e-05 | 88 | 563 | 562 | 64 | 1 | — | 3.6 s |
| constant | birth-date | 1e-4 | refined | 7.05485e-05 | 88 | 563 | 562 | 64 | 1 | 1 | 3.7 s |
| constant | birth-date | 1e-5 | unrefined | 7.05485e-05 | 88 | 606 | 605 | 118 | 0 | — | 4.1 s |
| constant | birth-date | 1e-5 | refined | 7.05485e-05 | 88 | 606 | 605 | 118 | 0 | 1 | 5.8 s |
| constant | birth-date | 1e-6 | unrefined | 7.05485e-05 | 88 | 661 | 660 | 125 | 0 | — | 4.6 s |
| constant | birth-date | 1e-6 | refined | 7.05485e-05 | 88 | 661 | 660 | 125 | 0 | 1 | 9.8 s |
| semiarid | height | 1e-4 | unrefined | 5.84021e-11 | 88 | 1018 | 1017 | 292 | 104 | — | 15.4 s |
| semiarid | height | 1e-4 | refined | **2.02571e-11** | 97 | 1052 | 1051 | 278 | 125 | 7 | 141.0 s |
| semiarid | height | 1e-5 | unrefined | 6.62032e-11 | 88 | 1427 | 1426 | 468 | 86 | — | 19.9 s |
| semiarid | height | 1e-5 | refined | 6.60926e-11 | 97 | 1456 | 1455 | 472 | 107 | 7 | 173.9 s |
| semiarid | height | 1e-6 | unrefined | 6.77035e-11 | 88 | 2121 | 2120 | 907 | 51 | — | 32.2 s |
| semiarid | height | 1e-6 | refined | 6.75556e-11 | 97 | 2127 | 2126 | 948 | 55 | 7 | 231.0 s |
| semiarid | birth-date | 1e-4 | unrefined | 1.81347e-09 | 88 | 939 | 938 | 258 | 109 | — | 6.7 s |
| semiarid | birth-date | 1e-4 | refined | **2.85221e-09** | 97 | 987 | 986 | 263 | 153 | 7 | 51.0 s |
| semiarid | birth-date | 1e-5 | unrefined | 1.66763e-09 | 88 | 1313 | 1312 | 428 | 81 | — | 10.2 s |
| semiarid | birth-date | 1e-5 | refined | 2.07733e-09 | 97 | 1353 | 1352 | 428 | 125 | 7 | 102.3 s |
| semiarid | birth-date | 1e-6 | unrefined | 3.22357e-09 | 88 | 1933 | 1932 | 693 | 57 | — | 14.8 s |
| semiarid | birth-date | 1e-6 | refined | 3.21899e-09 | 97 | 1945 | 1944 | 652 | 75 | 7 | 137.8 s |

### The two errors side by side

| forcing | coord | schedule shift at fixed tol (unref -> ref) | time shift at fixed schedule (1e-4 -> 1e-6) |
|---|---|---|---|
| constant | height | **0** at every tol (refinement never fires) | +3.71e-06 |
| constant | birth-date | **0** at every tol (refinement never fires) | +6.64e-08 |
| semiarid | height | 1e-4 **-65.3%**; 1e-5 -0.167%; 1e-6 -0.218% | unrefined +15.9%; refined +233% |
| semiarid | birth-date | 1e-4 **+57.3%**; 1e-5 +24.6%; 1e-6 -0.142% | unrefined +77.8%; refined +12.9% |

The "refined +233%" in the height row is not a time-error measurement: it is the
`ode_tol = 1e-4` refined cell (2.03e-11) being an outlier against 6.61e-11 and
6.76e-11 at 1e-5 and 1e-6. The refined 1e-5 -> 1e-6 step is +2.2%.

### The node grid on its own: uniform bisection

Because the default `schedule_eps` leaves the constant-forcing schedule untouched,
the error signal cannot measure the constant-forcing schedule error at all. A
uniform bisection of every interval can (`sched_uniform.R`, `ode_tol = 1e-4`, no
error signal involved):

| forcing | coord | 88 nodes | 175 nodes | 349 nodes | steps 88 -> 349 |
|---|---|---|---|---|---|
| constant | height | 9.46765e-07 | 9.54368e-07 | 9.56346e-07 | 531 -> 763 |
| constant | birth-date | 7.05485e-05 | 7.06855e-05 | 7.07198e-05 | 563 -> 749 |
| semiarid | height | 5.84021e-11 | 3.85013e-11 | 3.93519e-11 | 1018 -> 1280 |
| semiarid | birth-date | 1.81347e-09 | 1.90504e-09 | 6.65285e-10 | 939 -> 1239 |

The constant-forcing sequences are monotone with increments falling ~4x per halving
(height 7.60e-9 then 1.98e-9; birth-date 1.370e-8 then 3.43e-9) — clean
second-order convergence in node spacing. So the default 88-node schedule carries

- **1.00% error (height)** against a time error of 3.71e-6 — **2700x larger**;
- **0.242% error (birth-date)** against 6.64e-8 — **36000x larger**.

The pulsed rows do not converge at all: the first halving moves height -34.1% and
birth-date +5.0%; the second moves height a further +2.2% but birth-date -65.1%. At `ode_tol = 1e-4` under pulsed forcing *no* grid refinement, adaptive or
uniform, produces a settled number.

### Verdict on Q1

- **Constant forcing:** the schedule error dominates by 2700x (height) / 36000x
  (birth-date), and it is entirely invisible at the default `schedule_eps` because refinement
  declines to do anything. `ode_tol = 1e-4` is already far tighter than it needs to
  be relative to the node grid the default schedule provides.
- **Pulsed forcing at `ode_tol = 1e-4`:** the two errors are not separable, and the
  57-65% that refinement appears to expose is mostly the time error. At
  `ode_tol = 1e-5` or tighter the schedule shift under adaptive refinement is
  0.14-0.22% in **both** coordinates, i.e. an order of magnitude *below* the
  residual time error there (+2 to +13% from 1e-5 to 1e-6).
- The practical reading is **the reverse of the two regimes**: benign forcing wants
  a tighter schedule, not a tighter tolerance; pulsed forcing wants a tighter
  tolerance first, and only then is a schedule measurement meaningful.

## Q1b — the 57%, on its own scenario

The 57% came from the fixed-grid spike's `"semi-arid pulsed"` scenario in
`fg_common.R` (five traits at `THETA0`, a 6-year rain series), **not** from
`probe7_rain.R`'s tiled 400-day series. Both were measured.

Reproduced exactly on the spike's setup: `J(1e-4) = 4.60484e-12` at 842 steps and
`J(1e-6) = 1.06562e-11` at 1750 steps, against the recorded `4.605e-12 / 842` and
`1.066e-11 / 1750`. The gap is 56.8%.

On `probe7`'s pulsed series the same sweep gives +15.9% (height) and +77.8%
(birth-date). The magnitude is scenario- and coordinate-specific; what is common is
that pulsed forcing at `ode_tol = 1e-4` is not time-converged by tens of percent.

Refined against unrefined on the spike's own scenario (`schedule_eps = 2e-2`; every
cell converged by the error test):

| coord | ode_tol | schedule | offspring | nodes | steps | iters |
|---|---|---|---|---|---|---|
| height | 1e-4 | unrefined | 4.60484e-12 | 88 | 842 | — |
| height | 1e-4 | refined | 5.37978e-12 | 99 | 874 | 8 |
| height | 1e-6 | unrefined | 1.06562e-11 | 88 | 1750 | — |
| height | 1e-6 | refined | 1.00019e-11 | 98 | 1780 | 8 |
| birth-date | 1e-4 | unrefined | 1.22326e-10 | 88 | 735 | — |
| birth-date | 1e-4 | refined | 1.45775e-10 | 101 | 807 | 9 |
| birth-date | 1e-6 | unrefined | 5.39496e-10 | 88 | 1507 | — |
| birth-date | 1e-6 | refined | 5.09082e-10 | 100 | 1523 | 8 |

**The 57% survives refinement.** Taking the tol-1e-6 answer as reference:

| coord | gap J(1e-4) vs J(1e-6), unrefined | same, both refined |
|---|---|---|
| height | **-56.8%** (the recorded 57%) | **-46.2%** |
| birth-date | -77.3% | -71.4% |

The *schedule* shift at fixed tolerance on this scenario is +16.8% / -6.1% (height,
1e-4 / 1e-6) and +19.2% / -5.6% (birth-date) — real, but a fraction of the time
error. **The earlier reading was right: it was the tolerance, not the schedule.**

The height / 1e-6 trajectory is the well-behaved one — 1.0656, 0.7874, 1.0011,
1.0013, 1.0011, 1.0012, 1.0011, 1.0002 (x1e-11): one excursion at iteration 1, then
flat to 0.1% for six iterations. The birth-date / 1e-4 trajectory on the same
scenario swings over a factor of 4 (1.22, 3.20, 4.73, 2.88, 1.46, 4.98, 4.97, 4.91,
1.46, x1e-10).

## Q2 — does refinement converge, and does the coordinate change that?

### Trajectories, probe7 pulsed forcing, `eps = 2e-2`

Height coordinate (offspring, x1e-11):

| iter | nodes | tol 1e-4 | tol 1e-5 | tol 1e-6 |
|---|---|---|---|---|
| 0 | 88 | 5.84021 | 6.62032 | 6.77035 |
| 1 | 91 | 5.85687 | 6.26281 | 6.83875 |
| 2 | 93 | 1.96616 | 6.76152 | 6.75352 |
| 3 | 94 | 4.22109 | 6.76187 | 6.75507 |
| 4 | 95 | 4.22738 | 6.76126 | 6.75526 |
| 5 | 96 | 3.84954 | 6.76146 | 6.75681 |
| 6 | 97 | 2.02571 | 6.60926 | 6.75556 |
| spread | | **3.0x** | 1.08x | **1.013x** |

Birth-date coordinate (offspring, x1e-9):

| iter | nodes | tol 1e-4 | tol 1e-5 | tol 1e-6 |
|---|---|---|---|---|
| 0 | 88 | 1.81347 | 1.66763 | 3.22357 |
| 1 | 90/91 | 1.42442 | 2.00628 | 3.16752 |
| 2 | 92/93 | 0.665996 | 0.829144 | 3.21796 |
| 3 | 94 | 1.90070 | 1.16352 | 3.23946 |
| 4 | 95 | 1.17500 | 1.81868 | 3.18110 |
| 5 | 96 | 1.07617 | 0.810109 | 3.15412 |
| 6 | 97 | 2.85221 | 2.07733 | 3.21899 |
| spread | | **4.3x** | **2.5x** | **1.027x** |

Under constant forcing at `eps = 2e-2` there is no trajectory: iteration 0 flags
nothing (max per-node error 0.0099 vs threshold 0.02) and the loop stops.

### Two things the trajectories say

1. **`converged = TRUE` is not convergence of the answer.** Every cell above
   stopped because the error signal fell under `eps`, in 7 iterations, never
   hitting `schedule_nsteps`. At `ode_tol = 1e-4` it did so with the functional
   still moving by a factor of 3-4 between iterations.
2. **The error signal is not monotone under pulsed forcing.** In height / 1e-4 the
   `maxerr` goes 0.0630, 0.0798, 0.1232, 0.0921, 0.0920, 0.0895, 0.0167 — bisecting
   an interval *raises* the reported error twice before it collapses below threshold
   in a single step. The signal is sampled at introduction times, so moving an
   introduction moves which rain pulse it lands on.

### Coordinate comparison

- At `ode_tol = 1e-4` **neither coordinate settles.** Birth-date is if anything
  worse (4.3x vs 3.0x spread) and ends 57% *above* its unrefined value while height
  ends 65% below.
- At `ode_tol = 1e-5` height settles (1.08x spread, final answer 0.17% from
  unrefined) and birth-date still does not (2.5x, +24.6%).
- At `ode_tol = 1e-6` **both settle**: height to a 1.3% band (-0.22% from
  unrefined), birth-date to a 2.7% band (-0.14%).
- Under constant forcing both converge cleanly and monotonically in the `eps` sweep
  (Q4), with birth-date the better-behaved by ~4x on the uniform grid (0.24% vs
  1.0% error at 88 nodes).

### Verdict on Q2

Refinement's *loop* converges everywhere — 7 to 10 iterations, always by the error
test, never by `nsteps`, in every cell measured. Refinement's *answer* converges
under constant forcing, and under pulsed forcing only once `ode_tol` is 1e-5
(height) or 1e-6 (birth-date) or tighter.

The prior observation — height drifts, birth-date converges — **does not reproduce
on TF24.** If anything it is the other way round on the probe7 pulsed series: the
height coordinate settles one tolerance decade earlier. What is true in both
coordinates is that at `ode_tol = 1e-4` the drift is real and large, and that it is
a time-error artefact rather than a coordinate property. Where the coordinate does
matter clearly is the *size* of the node-grid error under benign forcing, where
birth-date is ~4x better.

## Q3 — what does refinement cost?

At `eps = 2e-2`:

| forcing | coord / tol | iters | nodes | steps unref -> ref | wall unref -> ref |
|---|---|---|---|---|---|
| constant | height, any tol | 1 (no bisection) | 88 | unchanged | ~1.0x |
| constant | birth-date, any tol | 1 (no bisection) | 88 | unchanged | ~1.0x |
| semiarid | height 1e-4 | 7 | 88 -> 97 (+10%) | 1018 -> 1052 (+3.3%) | 15.4 -> 141.0 s (9.2x) |
| semiarid | height 1e-5 | 7 | 88 -> 97 | 1427 -> 1456 (+2.0%) | 19.9 -> 173.9 s (8.7x) |
| semiarid | height 1e-6 | 7 | 88 -> 97 | 2121 -> 2127 (+0.3%) | 32.2 -> 231.0 s (7.2x) |
| semiarid | birth-date 1e-4 | 7 | 88 -> 97 | 939 -> 987 (+5.1%) | 6.7 -> 51.0 s (7.6x) |
| semiarid | birth-date 1e-5 | 7 | 88 -> 97 | 1313 -> 1353 (+3.0%) | 10.2 -> 102.3 s (10.0x) |
| semiarid | birth-date 1e-6 | 7 | 88 -> 97 | 1933 -> 1945 (+0.6%) | 14.8 -> 137.8 s (9.3x) |

**The cost is the re-runs, not the nodes.** Seven iterations is seven full model
runs; the final run is only 0.3-5% more expensive than the unrefined one, because
9 extra nodes out of 88 barely move the ODE step count. So wall time is
approximately (iterations) x (one run) — 7-10x here, and up to 20x if a problem
runs to `schedule_nsteps`. Under constant forcing at the default `eps` the cost is
exactly one run, which is why refinement looks free there: it is free because it
does nothing.

Refinement does not make the integration harder. The step-attempt census stays in
the same band (height 1e-4: 292 inaccurate / 104 thrown unrefined vs 278 / 125
refined; birth-date 1e-6: 693 / 57 vs 652 / 75).

**Wall times are contended and should be read as ratios only, +/-30%.** Up to seven
R processes shared 4 cores; the `semiarid / 1e-4 / height` refined cell that reads
141.0 s here took 94.9 s when run alone. Node counts, step counts and functionals
are exact.

## Q4 — `schedule_eps` sensitivity

Both coordinates are reported; "best" depends on the forcing. All at
`ode_tol = 1e-4`.

| forcing | coord | eps | nodes | iters | offspring | vs eps=2e-2 | vs 349-node uniform |
|---|---|---|---|---|---|---|---|
| constant | height | 2e-2 | 88 | 1 | 9.46765e-07 | — | -1.00% |
| constant | height | 5e-3 | 94 | 2 | 9.51766e-07 | +0.53% | -0.48% |
| constant | height | 1e-3 | 127 | 3 | 9.55109e-07 | +0.88% | **-0.13%** |
| constant | birth-date | 2e-2 | 88 | 1 | 7.05485e-05 | — | -0.242% |
| constant | birth-date | 5e-3 | 92 | 2 | 7.05552e-05 | +0.0095% | -0.233% |
| constant | birth-date | 1e-3 | 117 | 3 | 7.06843e-05 | +0.192% | **-0.050%** |
| semiarid | height | 2e-2 | 97 | 7 | 2.02571e-11 | — | (no reference) |
| semiarid | height | 5e-3 | 109 | 8 | 5.82514e-11 | +188% | |
| semiarid | height | 1e-3 | 147 | 10 | 6.44058e-11 | +218% | |
| semiarid | birth-date | 2e-2 | 97 | 7 | 2.85221e-09 | — | (no reference) |
| semiarid | birth-date | 5e-3 | 110 | 7 | 4.08326e-10 | -86% | |
| semiarid | birth-date | 1e-3 | 156 | 7 | 1.99176e-09 | -30% | |

**Constant forcing: yes, the default 2e-2 is leaving real error on the table.** The
sequences are monotone and converging, and by the uniform-grid reference the
default schedule sits 1.00% (height) / 0.242% (birth-date) low, against an ODE time
error of 3.7e-6 / 6.6e-8. `eps = 1e-3` closes that to 0.13% / 0.050% for 127 / 117
nodes and three model runs, and it costs almost nothing in ODE steps (531 -> 554,
563 -> 563). Adaptive placement is efficient — 127 nodes gets within 0.13% of what
349 uniform nodes give.

A defensible default would be `schedule_eps` around 1e-3 when `ode_tol` is 1e-4;
2e-2 is loose enough that it is a no-op on a benign TF24 stand, which makes the
whole mechanism silently inactive.

**Pulsed forcing: the `eps` sweep does not converge** in either coordinate at
`ode_tol = 1e-4`. Height goes 2.03e-11 -> 5.83e-11 -> 6.44e-11 (trending toward the
5.8-6.8e-11 band that everything else in that cell occupies, with the `eps = 2e-2`
answer the outlier); birth-date goes 2.85e-9 -> 4.08e-10 -> 1.99e-9, a 7x range
with no trend. Both `eps = 1e-3` trajectories still swing by a factor of 2-5
between iterations. Tightening `schedule_eps` under pulsed forcing without first
tightening `ode_tol` buys nothing.

## What was not measured, and what not to trust

- **Not measured: a jointly converged reference under pulsed forcing** (tight
  `ode_tol` *and* a dense schedule). The uniform-bisection runs are all at
  `ode_tol = 1e-4`, so under pulsed forcing they bound the node error at that
  tolerance only — they are not a reference for the true value. Every pulsed
  "error" quoted here is a *difference between two unconverged answers*, which is
  why the same quantity reads -65% one way and +57% the other.
- **Not measured: `schedule_eps` sweep at tighter `ode_tol`.** The Q4 sweep was run
  at `ode_tol = 1e-4` as specified. Given that the pulsed cells only settle at 1e-5
  / 1e-6, an `eps` sweep at 1e-6 under pulsed forcing is the obvious follow-up and
  was not run.
- **Not trusted: relative moves on a near-extinct stand.** At `lma = 0.0825`,
  lifetime 5, the functional is 1e-11 to 1e-5 depending on cell. Large relative
  moves on a number that small may not matter downstream; `spike-fixed-grid.md`
  flagged the same extinction caveat for the pulsed scenario. The constant-forcing
  numbers (1e-7 / 1e-5) are the more trustworthy ones.
- **Not trusted: wall times to better than ~30%** (contention, see Q3). Counts and
  functionals are exact.
- **`refinement_error_by_node` is not a bound on the error in the functional.**
  Cells report `converged = TRUE` at `maxerr < eps` with the functional still moving
  by a factor of 3-5 between iterations. Its value as a stopping rule rests on a
  correlation with the quantity of interest that does not hold under pulsed forcing.
