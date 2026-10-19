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
