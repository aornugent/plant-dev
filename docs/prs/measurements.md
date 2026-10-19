# Measurements for the residual

Three of the measurements `residual.md` waits on (the splits are dropped). Each prediction was
written here before its runs started. One SCM process at a time; the machine also carried
another session's two `refine_case.R` processes, so CPU seconds are read beside step and row
counts, which do not depend on load, and the A/B timings are interleaved. Scripts and outputs
are under `scratchpad/meas/` (`/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/meas/`).

## M1: the tolerance factors and their bound, on the substepped soil

**Question.** Do the factors still save at least 15% of a gradient run at under ε/3 drift, now
that the soil is substepped?

**Setup.** libNS (the archived stack with the soil substeps and the factors; odelia 0.5.0, so
GSL's max-norm rule, not upstream's Hairer default). Three canonical cases, each on its schedule
refined on libNS (`scratchpad/refine/ns/CASE.rds`, `nodes_of(fit$schedule, fit$level)`):
`episodic-lma` (205 nodes), `dry` (230), `long-wet` (220). One gradient run per arm
(`harness/schedule/refine.R`'s `stand_run`, census gradient of offspring production):
- *factors*: the canonical control of `refine_case.R`: tol 1e-4, abs 1e-8, soil ×10, rule A's
  `ode_tol_factor_times/values`, bound 100, share 0.1, 15-day cap;
- *none*: the same with no factor (soil 1, no schedule, bound ∞);
- *ref*: none at tol 1e-5, abs 1e-9, the same schedule.

Drift is |q − q_ref| / ε per quantity (ln J and the elasticities `quantities()` keeps, ε from
`eps_vec`). The saving is 1 − factors/none in rows (accepted steps × nodes alive at each step's
start) and in CPU of the gradient run (forward + sweep).

**Command.** `PLANT_LIB=$SP/dev/ns/libNS nice -n 10 Rscript $SP/meas/m1.R CASE ARM $SP/meas/m1/CASE_ARM.rds`,
in the order factors, none, ref per case, then a second factors/none pair on `episodic-lma`
in the order none, factors for an interleaved CPU check.

**Prediction** (written before any run):
- rows saved 25% (range 15–35%) on each case: the time schedule still removes most of the steps
  after t ≈ 25, while the soil factor buys less than it did with coupled soil, since the
  substeps already take the soil's stiff stretches off the outer step;
- CPU saved within 5 points of the rows saving;
- worst drift of *factors* from *ref* under 0.2ε, and of *none* under 0.15ε; the factors add
  at most 0.1ε to any quantity's distance;
- verdict LAND if every case saves ≥ 15% with every quantity under ε/3.

## M3: the first invasion on refreshed develop

**Question.** Is walking a recorded run instead of repeating it (PLANT-99) still worth landing?
On develop, `run_mutant`'s first call re-runs the resident pinned to its own steps to record
its field (`scm.h:1049`), even after a run that kept its states; a second call reuses that
recording.

**Setup.** `scratchpad/dev/land/PLANT-93/lib-dev`: plant develop bd09645d (the source tree
`dev-src` is byte-identical to `git archive bd09645d` outside build outputs), odelia 0.7.3,
phylloptim 0.10.2. The long-drought stand of `harness/long_drought.R` (lma 0.32, uniform 108
introductions, tol 1e-4, abs 1e-8, knot stops, coupled soil: develop's way), run with its
states kept as a gradient run keeps them; then two identical invasions at lma × 0.95, states
kept. The first run (`SWEEPS=1`) adds one census sweep for each role, so the share can be read
against a both-roles gradient run (forward + resident sweep + first invasion + invader sweep);
a second process repeats forward and both invasions without sweeps for the timing.

**Command.** `PLANT_LIB=$SP/dev/land/PLANT-93/lib-dev [SWEEPS=1] nice -n 10 Rscript $SP/meas/m3.R $SP/meas/m3/run_N.rds`.

**Prediction** (written before any run):
- the first invasion costs 2.0–2.4× the second (§3 measured 2.24, PLANT-98 2.16), the
  difference being about 0.9× the forward;
- PLANT-99 would save that difference: 40–55% of the first invasion;
- as a share of a both-roles gradient run, 8–12%: borderline against residual-A's 10% bar;
- the invader's `J` is identical across both invasions.

## The replay noise on phylloptim 0.10

**Question.** Does upstream's leaf solve still carry the ~1e-8 replay noise in `ln J` that
PHYLLOPTIM-17 took to roundoff, and does anything other than a finite-difference test see it?

**Setup.** The same develop library and stand as M3 (no states kept), run once adaptively,
then replayed on its own steps (`p$ode_times`, `p$ode_step_sizes`) at
lma · (1 + k·1e-12), k = −8…8, lma set after the hyperparameterisation, as in
`grid-dynamics.md` §18's `tight.R`. Noise is the rms of `ln J` off a line in k, and the rms of
neighbouring changes less their mean.

**Command.** `PLANT_LIB=$SP/dev/land/PLANT-93/lib-dev nice -n 10 Rscript $SP/meas/noise.R $SP/meas/noise`;
`Rscript $SP/meas/noise_report.R $SP/meas/noise`.

**Prediction** (written before any run):
- the noise stays near the 0.9.x level, rms 3e-9 to 3e-8 (most likely ~1e-8), not 1e-14:
  0.10 only polishes a pinned bracket bound, while ci stops at 1e-10, and the newborn's height
  (plant's own root-find, PLANT-100's 631bbab3, not upstream) still stops at its tolerance;
- ε in `ln J` is 0.025, so the noise is about 1e-6 ε; the only reading it reaches is a
  second difference of `ln J` at a relative step under about 4e-4 (noise·√6/r² against a third
  of lma's curvature ε, 1.17), far below the 1e-2 the curvature work uses;
- verdict DROP unless a consumer reading below 1e-8 other than a finite-difference test is
  found.

## M1 results

Runs 04:05–05:30, one at a time (`scratchpad/meas/m1/queue.log`, `m1_report.R`). Rows and steps
do not depend on load; CPU is the gradient run (forward + sweep).

| case | arm | steps | rows | CPU (fwd + sweep) | ln J |
|---|---|---|---|---|---|
| episodic-lma | factors | 3 641 | 393 739 | 197 s (62 + 136); repeat 183 s | −3.46088461 |
| | none | 4 295 | 524 859 | 267 s (91 + 176); repeat 255 s | −3.46064210 |
| | ref 1e-5 | 7 602 | 959 277 | 452 s | −3.46072641 |
| dry | factors | 4 804 | 618 707 | 269 s (86 + 183) | 0.18032241 |
| | none | 5 953 | 874 218 | 419 s (129 + 290) | 0.18019382 |
| | ref 1e-5 | 11 098 | 1 683 015 | 809 s | 0.18022728 |
| long-wet | factors | 5 468 | 681 128 | 351 s (121 + 231) | 2.91682634 |
| | none | 6 819 | 965 980 | 473 s (161 + 312) | 2.91683695 |
| | ref 1e-5 | 13 134 | 1 919 536 | 966 s | 2.91677556 |

| case | rows saved | steps saved | CPU saved | worst \|factors − ref\| | worst \|none − ref\| | worst \|factors − none\| | added distance, worst |
|---|---|---|---|---|---|---|---|
| episodic-lma | 25.0% | 15.2% | 25.9% (repeat, none first: 28.2%) | 0.096ε (storage_relaxation_offset) | 0.114ε (TF24_cost_scale) | 0.166ε | 0.075ε |
| dry | 29.2% | 19.3% | 35.7% | 0.161ε (storage_relaxation_offset) | 0.321ε (a_l1) | 0.479ε (a_l1) | 0.090ε |
| long-wet | 29.5% | 19.8% | 25.7% | 0.052ε (a_dG1) | 0.059ε (a_l1) | 0.047ε | 0.023ε |

`ln J` moves by at most 0.01ε between any two arms. No quantity of the 47 is over ε/3 from the
reference in either arm on any case.

**Against the prediction.** Rows saved 25–30%, inside 15–35%; CPU within 5 points of rows
except dry's single pair (+6.5 points, under load). Drift held: factors at most 0.16ε (predicted
under 0.2ε), adding at most 0.09ε (predicted 0.1ε). One miss: *none* reached 0.32ε on dry's
`a_l1` (predicted under 0.15ε), and the factors bring it to 0.16ε, so dry's 0.48ε gap between
the two arms is the unfactored run's own tolerance error, not the factors'.

**Verdict: LAND** (plant B + odelia B0). The factors save a quarter to a third of a gradient
run on the substepped soil, at no cost in accuracy against a 1e-5 reference. Caveats for the
PR: libNS is odelia 0.5.0, GSL's max-norm rule; upstream now defaults to Hairer's RMS norm, so
B0 must be re-timed on one case under that rule (the factors scale `D0` in both). The soil
factor and the time schedule were not separated here.

## M3 results

Two processes, 05:30 and 06:03, each alone beside a lightly loaded machine (load 1.0–2.0);
`scratchpad/meas/m3/run_{1,2}.{rds,log}`.

| run | forward | resident sweep (`leaf_area`) | first invasion | invader sweep | second invasion | first − second |
|---|---|---|---|---|---|---|
| 1 (`SWEEPS=1`) | 80.6 s | 266 s | 85.7 s | 228 s | 18.2 s | 67.5 s |
| 2 | 81.0 s | — | 86.3 s | — | 18.3 s | 68.0 s |

- The stand takes 15 376 steps (853 990 rows), as PLANT-105.md's develop row; the first
  invasion's pinned re-run takes the same 15 376.
- The invader's `J` (28.2661426030344) is bit-identical across the two invasions.
- The re-run costs 0.84× the forward, as `scm.h` says (a pinned run rejects nothing).

**Against the prediction.** The first invasion costs 4.7× the second, not 2.0–2.4×: on odelia
0.7 the walk of a recording is cheap (18 s, 0.23× the forward, against 91 s and 0.79× in §3),
so the re-run is 79% of the first invasion (predicted 40–55%). The difference is 0.84× the
forward (predicted about 0.9×). As a share of a both-roles gradient run (forward + one sweep per
role + first invasion, 661 s) it is 10.2%, inside the predicted 8–12%. `J` identical, as
predicted.

**Verdict: DROP.** The saving survives in seconds (68 s, as against 161 s on PLANT-98's coupled base)
and is larger as a share of the first invasion, but it is paid once per resident:
- 10.2% of a gradient run with exactly one invader, right at residual-A's 10% bar;
- about 2.4% across a ten-invader landscape around one resident (OBJECTIVES' local analysis);
- 41% of forward + first invasion, which is the number to quote if it is ever offered.
Against that, PLANT-99 holds about 7.4 kB a step more after a recorded forward, about 114 MB
on this stand's 15 376 steps, and upstream's comment already accepts one pass per resident.
Offer it only if a single-invader workflow turns out to dominate.

## Replay noise results

`scratchpad/meas/noise/` (`noise.log`, `k±N.rds`, `base.rds`), 05:41–06:03, alone.

- The adaptive run: `ln J` 2.593360009752596, 15 376 steps, 80.7 s. Each replay lands on those
  steps exactly, takes 66–67 s and, at k = 0, lies 1.8e-13 from the adaptive run.
- Slope −7.339e-12 per 1e-12 of lma (the partial elasticity −7.34).
- **Noise: rms 4.0e-13 off the line (max 7.4e-13); neighbouring changes less their mean, rms
  5.2e-13.** On 0.9.x it was 2.7e-8 (`tight.log`); with every root at roundoff 1.1e-14 and
  8.5e-15.

**Against the prediction.** Missed by five orders: predicted 3e-9 to 3e-8, measured 4e-13.
Between 0.9.x and develop with 0.10, nearly all of it has gone. The most likely cause is 0.10's
polished pinned bound, but this probe does not trace it, and the newborn's height still stops
at its tolerance on develop. What remains is about 40 times roundoff's floor, 2e-11 ε in `ln J`.

**Who can see it.** A second difference of `ln J` in ln lma has error √6 · 4e-13 / r². That
stays under a third of lma's curvature ε (0.39) for any r above 1.6e-6, while the curvature work
uses r ≥ 1e-2. A central difference against a sweep reads 4e-13/h in an elasticity, which is
under 1e-6 for h ≥ 1e-6. No gate reads `ln J` below 1e-12. Only a finite-difference test with
h under about 1e-9 would see it.

**Verdict: DROP** 6b6f152 (and with it the newborn's height to roundoff, 631bbab3). The rms is
under the 1e-12 bar residual-B set. Keep `polish_bracket_bound` as it is. PHYLLOPTIM-19's
finite-difference check at the determined fixtures still has to pass on 0.10's bounds, as
residual-B says.
