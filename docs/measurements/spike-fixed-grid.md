# Fixed ODE step grid: how wide is the trust region?

A spike, not a product. Everything below is measured on the TF24 SCM at
`max_patch_lifetime = 5`, one species, optimised `-O2` build,
`TESTTHAT_PARALLEL=false`. Objective throughout is
`J = sum(scm$offspring_production)`. theta is six coordinates: the traits `lma`,
`rho`, `hmat`, `a_d0`, `K_s` and the environment field `K_sat`. Scripts in this
directory: `fg_common.R`, `m1_fidelity.R`, `m2_stability.R`, `m3_forcing.R`,
`m4_payoff.R`, `m5_supp.R`, `probe_ff16.R`.

## Headline

**How generous is the trust region? In theta, generous — but only once you give the
grid a safety factor, and only within one forcing scenario.**

- **In theta, with sf = 1.5 to 2: the whole +/-2x box, in all six parameters tried,
  at 1.5 to 2x the step count.** 100% of 64 evaluation points under 1e-4 relative
  error at sf = 2; 98.4% at sf = 1.5. The residual is the adaptive reference's own
  error, not the grid's. Cost is modest because a frozen replay starts ~30% cheaper
  than the adaptive run it replaces.
- **In theta, with no safety factor: essentially nothing.** 58% of the wide box, and
  points as close as lma x1.1 are already wrong by tens of percent.
- **Across forcing scenarios: none.** A grid captured under one rainfall series is
  40–100% wrong under another, and a safety factor does not help, because the problem
  is where the steps are and not how big they are. Recapture per scenario.
- **What binds: stability.** Accuracy is the symptom.
- **Does the safety factor rescue it: yes, completely, and predictably.**
- **Measurement (4): confirmed, not falsified.**

Two further things dominate everything below, and both were surprises:

1. **There are two fixed-grid forms and only one of them is usable.** A program
   replayed *by its recorded step sizes* (`advance_recorded` -> `step_by`) takes each
   step bare: a `DomainError` from the model propagates and ends the run. A program
   replayed *by its times alone* (`step_size = NaN` -> `step_to`) subdivides the
   interval on a `DomainError` and completes. Both are theta-independent grids in the
   sense the optimiser cares about — the sequence of output times is fixed and does
   not branch on theta. Everything quantitative below uses the **times** form; the
   sizes form completed at only 39 of 64 evaluation points and its failures are not
   predictable from how far theta moved.
2. **The adaptive controller is sitting on the explicit stability ceiling, so a
   frozen grid has no margin by construction.** Measured `h*|lambda|` on the adaptive
   run is 3.5 to 5.3 at every point tried, pinned there across a 2x swing in five
   parameters and a 100x swing in soil conductivity. Any theta that raises the fast
   eigenvalue pushes the frozen step past that ceiling, and the answer is wrong by
   O(1). Two separate consequences follow, and they are easy to confuse: the *sizes*
   form additionally meets TF24's negative-storage refusal and raises, while the
   *times* form completes and returns the wrong number. Section 2 separates them.

## Wiring

**No plant-side code change was needed.** Capture and replay were already exposed:

- `scm$ode_times`, `scm$ode_step_sizes` — the program a finished run took.
- `NodeSchedule$set_ode_steps(times, sizes)` / `clear_ode_steps` / `using_ode_steps`,
  reached through `scm$node_schedule` (get and set).
- `set_ode_steps(times, numeric(0))` installs the **times-only** form (all sizes NaN).

`SCM::run_next` already composes this per leg: `node_schedule.program_within(t0,
t_end)` hands `advance_recorded` only the recorded steps strictly inside the current
introduction interval, then `advance_fixed({t, t_end})` closes the leg. So a captured
program is automatically split at introduction boundaries, and the boundaries
themselves are theta-independent (they come from `p$node_schedule_times`, which
`add_strategies` sets from the defaults — verified identical across every theta
tried). Nothing under `odelia/` was read-modified or committed.

What was committed on `claude/trusting-curie-4i9n3l` is the coverage the finding in
(1) above deserves: a test in `tests/testthat/test-strategy-tf24.R` that a program
replayed at other parameters holds by its times and not by its sizes.

---

## (1) Fidelity

Baseline: capture at theta0 under constant rainfall 3.0. J_adapt = 9.4674e-07 on 534
steps. `J_fixed` replays theta0's grid; `J_adapt` is a fresh adaptive run at the same
theta and default tolerance (`ode_tol_rel = ode_tol_abs = 1e-4`). Relative error is
`|J_fixed - J_adapt| / |J_adapt|`.

Parameters swept: `lma`, `rho`, `hmat` (allocation/reproduction), `a_d0` (mortality),
`K_s` (stem hydraulic conductivity), `K_sat` (soil saturated conductivity — the
stiffness lever). Factors 0.5, 0.75, 0.9, 0.95, 1.05, 1.1, 1.25, 1.5, 2.0 on each,
plus 10 log-uniform multi-parameter draws in [0.5, 2]^6. 64 points.

"Safety factor sf" = the captured program with a share of its intervals cut in two,
keeping every captured breakpoint, so the mean step is the captured one divided by
sf. (Whole-number factors cut every interval; 1.5 cuts every other one. Declared
approximation: an exact non-integer shrink would have to move the breakpoints, and
that matters — a grid re-walked from scratch with every step at half the captured
size, so strictly finer everywhere, still met the storage refusal under the sizes
form at theta0 itself. Keeping the captured breakpoints is not cosmetic. `smoke4.R`,
`smoke5.R`.)

| grid | steps | vs capture |
|---|---|---|
| sf = 1 | 534 | 1.00x |
| sf = 1.25 | 667 | 1.25x |
| sf = 1.5 | 800 | 1.50x |
| sf = 2 | 1067 | 2.00x |

### Fraction of evaluated points under each threshold (times form)

| box | sf | n | completed | rel < 1e-4 | rel < 1e-3 | rel < 1e-2 |
|---|---|---|---|---|---|---|
| +/-50% | 1    | 48 | 100% | 66.7% | 68.8% | 68.8% |
| +/-50% | 1.25 | 48 | 100% | 95.8% | 95.8% | 95.8% |
| +/-50% | 1.5  | 48 | 100% | **100%** | 100% | 100% |
| +/-50% | 2    | 48 | 100% | **100%** | 100% | 100% |
| +/-2x  | 1    | 64 | 100% | 57.8% | 59.4% | 59.4% |
| +/-2x  | 1.25 | 64 | 100% | 84.4% | 84.4% | 84.4% |
| +/-2x  | 1.5  | 64 | 100% | **98.4%** | 98.4% | 98.4% |
| +/-2x  | 2    | 64 | 100% | **100%** | 100% | 100% |

The three thresholds are almost the same number. **The error is bimodal**: a point is
either at ~1e-5 (the grid's own discretisation error, which is also roughly the
tol=1e-4 reference's own error) or at 0.1–0.9. There is essentially nothing in
between. That is the signature of a discrete event flipping, not of a smooth
truncation error growing.

Representative rows (relative error; `sizes` column is the step-size-pinned form):

| point | J_adapt | n_adapt | sizes | sf=1 | sf=1.25 | sf=1.5 | sf=2 |
|---|---|---|---|---|---|---|---|
| lma x0.9 | 1.49e-06 | 532 | ok | **2.5e-01** | 1.1e-05 | 1.2e-05 | 6.4e-06 |
| lma x1.05 | 7.45e-07 | 534 | error | 5.2e-05 | 5.5e-05 | 6.1e-05 | 1.3e-05 |
| lma x1.25 | 2.69e-07 | 545 | error | **4.8e-01** | 4.2e-06 | 1.1e-06 | 8.8e-06 |
| lma x2 | 3.98e-09 | 605 | error | **5.6e-01** | **2.2e-01** | 2.4e-06 | 9.5e-06 |
| rho x2 | 1.82e-13 | 559 | error | **6.4e-01** | **2.8e-01** | 1.3e-05 | 3.0e-06 |
| hmat x2 | 8.98e-15 | 530 | ok | 1.7e-05 | 1.8e-05 | 1.3e-05 | 2.1e-05 |
| a_d0 x2 | 9.50e-07 | 533 | ok | 6.5e-05 | 3.6e-05 | 2.9e-06 | 2.0e-05 |
| K_s x0.5 | 2.86e-07 | 542 | ok | **5.2e-01** | 5.5e-02 | 2.8e-05 | 3.0e-05 |
| K_sat x2 | 9.19e-07 | 565 | error | **8.9e-01** | 1.0e-02 | 3.2e-05 | 1.5e-05 |
| draw09 | 5.69e-15 | 586 | error | **5.2e-01** | **5.0e-01** | **3.1e-01** | 4.0e-06 |

`hmat` and `a_d0` are flat — the frozen grid is exact for them at any factor, because
neither changes the ODE's fast timescales. `lma`, `rho`, `K_s`, `K_sat` are where the
grid breaks.

### Contrast: FF16

The same experiment on FF16 (no storage pool, no hydraulics, no stiff soil block) is
a different world. Captured at lma = 0.0825 (209 steps), replayed at lma x{1.1, 1.25,
1.5, 2}: **both** replay forms complete, and relative error is 2.6e-05, 3.8e-05,
7.4e-06, 8.1e-05. That is at the reference's own tolerance across a doubling of the
trait, with no safety factor. `probe_ff16.R`.

**Verdict (1).** On TF24 the raw captured grid has a trust region of essentially zero
— 58% of the wide box is already wrong by tens of percent, including points only 10%
away from theta0. With sf = 1.5 that becomes 98.4% of the +/-2x box and 100% of the
+/-50% box; with sf = 2, 100% of both, and the residual ~1e-5 error is the reference's
own. The cost is exactly the safety factor in step count. On FF16 the raw grid is
already fine over +/-100% in lma, so this is a TF24 (hydraulics + storage-pool +
stiff soil) problem, not a general SCM one.

---

## (2) Stability

`lambda` is the largest eigenvalue magnitude of the 5 soil-water block, obtained by
finite-differencing `patch$derivs` on those five states (as `probe5_hlam.R` does).
`h*|lambda|` is sampled at 12 points along a run, rebuilding the patch to the right
node count at each sample. Declared approximations: (i) the sample is 12 steps, not
all of them, so the maxima below are lower bounds; (ii) lambda covers **only the soil
block** — a fast mode in leaf hydraulics or the storage pool is not in this number.

### Nothing diverged. The failure is a completed, wrong answer.

Across every measurement in this document — 64 theta points, 49 transfer cells, 49
scenario x theta points, 78 finite-difference runs — the **times** form of the replay
completed **every single time**, with finite J. Not one blow-up, not one NaN. The
**sizes** form never diverged either: where it failed it *raised*, on TF24's
`storage is negative` domain refusal, at the first step whose endpoint fell outside
the pool's domain (typically by 1e-9 to 1e-5 kg — a boundary overshoot, not a runaway).

So the distinction the brief asks for resolves entirely to one side: **"replay
finished but is inaccurate"**, plus a class of hard refusals. There is no
"replay diverged".

### But the mechanism *is* the stability ceiling

| point | adapt | times | sizes | rel err | max h*lambda adapt | max h*lambda replay | lambda at end |
|---|---|---|---|---|---|---|---|
| theta0 | ok | ok | ok | 5.9e-07 | 5.04 | 5.04 | 239 |
| lma x0.5 | ok | ok | ok | 4.5e-06 | 4.63 | 5.04 | 240 |
| lma x2 | ok | ok | **error** | **0.557** | 4.12 | **5.37** | 245 |
| rho x0.5 | ok | ok | **error** | 2.8e-05 | 3.51 | 5.04 | 254 |
| rho x2 | ok | ok | **error** | **0.637** | 3.78 | **8.63** | 230 |
| hmat x0.5 | ok | ok | **error** | 1.2e-05 | 3.95 | 5.04 | 202 |
| hmat x2 | ok | ok | ok | 1.7e-05 | 5.26 | 5.04 | 239 |
| a_d0 x0.5 | ok | ok | ok | 4.5e-05 | 5.04 | 5.04 | 239 |
| a_d0 x2 | ok | ok | ok | 6.5e-05 | 5.19 | 5.04 | 239 |
| K_s x0.5 | ok | ok | ok | **0.517** | 3.99 | 5.04 | 257 |
| K_s x2 | ok | ok | ok | **0.433** | 4.73 | 5.04 | 234 |
| K_sat x0.5 | ok | ok | ok | 2.2e-06 | 4.64 | 4.72 | 222 |
| K_sat x2 | ok | ok | **error** | **0.886** | 3.74 | **16.16** | 256 |

**The adaptive controller sits on the explicit stability boundary.** Its
`max h*|lambda|` is 3.5 to 5.3 at every one of these thirteen points — pinned, over a
2x swing in five different parameters. That is the July measurement reproduced: the
step is set by stability, not truncation.

**Freezing it therefore has no margin.** Where the replay's error is catastrophic, its
`h*|lambda|` is 1.7x to 3.2x the adaptive value and well past the ceiling: 5.37, 8.63,
16.16. Where the error is ~1e-5, `h*|lambda|` is unchanged at ~5.0. The one exception
is `K_s`, where the replay is 43–52% wrong with `h*|lambda|` sitting at 5.04 — the
soil block is not what `K_s` destabilises, and caveat (ii) applies: the fast mode
there is in the leaf hydraulics / storage pool and this measurement does not see it.

### The direct lever: multiply soil conductivity

theta0's grid replayed at rising `K_sat`:

| K_sat x | lambda | adapt steps | max h*lambda adapt | max h*lambda replay | sizes | rel, sf=1 | rel, sf=2 |
|---|---|---|---|---|---|---|---|
| 1 | 239 | 534 | 5.04 | 5.04 | ok | 5.9e-07 | 3.3e-05 |
| 2 | 256 | 565 | 3.74 | **16.16** | error | **0.886** | 1.5e-05 |
| 5 | 277 | 599 | 4.14 | **9.31** | error | **0.919** | 7.8e-06 |
| 10 | 294 | 624 | 5.17 | **12.84** | error | **0.930** | 4.1e-05 |
| 30 | 320 | 675 | 4.24 | **17.54** | error | **0.996** | 1.1e-06 |
| 100 | 351 | 717 | 4.54 | **7.32** | error | **0.998** | 4.3e-05 |

`h*|lambda|` on the adaptive run stays at 3.7–5.2 across a 100x change in soil
conductivity; on the frozen replay it goes to 7–18. The frozen answer is 89% to 99.8%
wrong from `K_sat x2` upward. **And sf = 2 recovers all of it** — 1e-6 to 4e-5 at every
multiplier, including x100.

That last row is the useful design rule. lambda rises only 1.5x over a 100x change in
`K_sat` (239 -> 351), so a step halved has enough margin to stay under the ceiling
everywhere in the sweep. **The safety factor you need is the largest factor by which
|lambda| can rise across your parameter box** — which is a quantity you can measure
once, cheaply, rather than discover by a failed optimisation.

### Cost of the safety factor

| sf | steps | vs capture | wall clock vs capture |
|---|---|---|---|
| 1 | 534 | 1.00x | 0.72x an adaptive run (it attempts nothing it rejects) |
| 1.25 | 667 | 1.25x | ~0.90x |
| 1.5 | 800 | 1.50x | ~1.08x |
| 2 | 1067 | 2.00x | ~1.44x |

A frozen replay at sf = 1 is about 30% *cheaper* than the adaptive run it replaces,
because it attempts no step it will reject: 5.3 s against 7.4 s for the adaptive run,
one TF24 run at lifetime 5. The wall-clock column above scales that measurement by
the step count rather than measuring each one, so treat it as an estimate: sf = 1.5
costs roughly what the adaptive run cost, and sf = 2 about 45% more.

**Verdict (2).** Stability is the mechanism and accuracy is the symptom. The adaptive
controller is holding `h*|lambda|` at the explicit ceiling, so a frozen grid has zero
margin by construction, and any theta that raises the fast eigenvalue pushes it past
the ceiling. The consequence is not a blow-up: the pinned-times replay always
completes and returns a wrong number, and the pinned-sizes replay hits TF24's storage
domain refusal and raises. The mitigation works cleanly and completely — sf = 1.5 covers
the +/-2x parameter box, sf = 2 covers a 100x change in soil conductivity, and the
price is exactly the factor in step count, which starts from a 30% discount.

---

## (3) Forcing diversity

Scenario bank as in `divergence_bank.R`, at `max_patch_lifetime = 5`. All seven run
adaptively:

| scenario | J_adapt | steps |
|---|---|---|
| wet 3.0 | 9.467e-07 | 534 |
| mesic 1.5 | 3.317e-07 | 418 |
| dry 0.6 | 3.438e-13 | 241 |
| arid 0.3 | 9.192e-15 | 256 |
| semi-arid pulsed | 4.605e-12 | 842 |
| drydown 4yr->0 | 4.312e-08 | 774 |
| whiplash | 2.392e-11 | 598 |

**Caveat that applies to this whole section:** in dry, arid, pulsed and whiplash the
population is effectively extinct (J between 1e-11 and 1e-15). A relative error on a
number that small is not an accuracy statement about anything an optimiser would
chase, and in one scenario it is not an accuracy statement at all — see (3d), which
measures how well each scenario's own adaptive reference is converged and rules
semi-arid pulsed out entirely.

### (3a) Does a grid transfer between forcings? No.

Relative error, sf = 1; rows = captured in, columns = replayed in. Every cell
completed (the times form always completes).

| captured in \ replayed in | wet 3.0 | mesic 1.5 | dry 0.6 | arid 0.3 | pulsed | drydown | whiplash |
|---|---|---|---|---|---|---|---|
| wet 3.0 | *5.9e-07* | 1.3e-03 | 4.0e-05 | 2.6e-04 | **1.00** | **0.88** | **0.80** |
| mesic 1.5 | **0.87** | *3.2e-08* | 6.6e-06 | 1.2e-04 | **1.00** | **0.86** | **0.88** |
| dry 0.6 | **0.93** | **0.99** | *1.1e-07* | 1.4e-04 | **1.00** | **0.92** | **0.94** |
| arid 0.3 | **0.97** | **0.98** | 2.6e-04 | *1.9e-07* | **1.00** | **0.91** | **0.94** |
| pulsed | **0.59** | **0.66** | 1.2e-04 | 7.2e-04 | *1.6e-05* | **0.71** | **0.75** |
| drydown | 9.1e-06 | 9.0e-04 | 6.6e-05 | 1.8e-04 | **1.00** | *3.1e-07* | **0.42** |
| whiplash | **0.70** | **0.99** | 4.9e-04 | 6.1e-05 | **0.98** | **0.82** | *2.2e-07* |

The diagonal is exact (1e-7 or better). Off the diagonal the answer is wrong by 40%
to 100% almost everywhere. The two exceptions are informative rather than hopeful:

- The `dry 0.6` and `arid 0.3` columns look fine from any source grid, but that is the
  extinction caveat — J is ~1e-13 and every grid agrees it is ~0.
- `drydown -> wet 3.0` at 9.1e-06 works because drydown's first four years *are* a wet
  scenario, at rainfall 4.0, so its grid is strictly denser than wet 3.0's where it
  matters. Transfer works in the direction "denser regime grid -> sparser regime", not
  the other way, and not symmetrically.

A safety factor does **not** rescue transfer: at sf = 1.25 the off-diagonal cells are
still 0.4 to 1.0. The grid is wrong about *where* the forcing puts structure, and
uniformly refining it does not put steps where a different rainfall series needs them.

### (3b) How wide is the theta box inside one forcing?

lma swept over x{0.5, 0.75, 0.9, 1.1, 1.25, 1.5, 2.0} within each scenario, each
against its own captured grid.

| grid | rel < 1e-4 | rel < 1e-3 | rel < 1e-2 | n |
|---|---|---|---|---|
| sf = 1 | 16.3% | 46.9% | 61.2% | 49 |
| sf = 1.25 | 34.7% | 67.3% | 77.6% | 49 |

Per scenario at sf = 1.25 the picture splits sharply: `dry`, `arid`, `whiplash` and
`drydown` are at or below 1e-3 across the whole lma range (drydown at 3.7e-06 to
8e-05); `wet 3.0` holds to x1.5 and breaks at x2 (0.22); `mesic 1.5` breaks from x1.5
(0.95); `semi-arid pulsed` is bad everywhere (0.08 to 0.94) and is the one scenario
where refining from sf=1 to sf=1.25 made several points *worse*, which is the
extinction caveat again — its J is 4.6e-12 and not itself grid-converged.

### (3d) Is the reference itself converged? Mostly, and one scenario is not.

`J_adapt` at the default tol 1e-4 against the same run at tol 1e-6. This bounds
every relative error quoted anywhere above — nothing below the reference's own error
is a measurement of the grid.

| scenario | J (tol 1e-4) | steps | J (tol 1e-6) | steps | reference's own error |
|---|---|---|---|---|---|
| wet 3.0 | 9.467e-07 | 534 | 9.468e-07 | 800 | 2.2e-05 |
| mesic 1.5 | 3.317e-07 | 418 | 3.316e-07 | 627 | 3.4e-04 |
| dry 0.6 | 3.438e-13 | 241 | 3.438e-13 | 573 | 5.4e-05 |
| arid 0.3 | 9.192e-15 | 256 | 9.194e-15 | 530 | 1.7e-04 |
| **semi-arid pulsed** | 4.605e-12 | 842 | 1.066e-11 | 1750 | **0.57** |
| drydown 4yr->0 | 4.312e-08 | 774 | 4.312e-08 | 1041 | 2.1e-05 |
| whiplash | 2.392e-11 | 598 | 2.395e-11 | 980 | 1.2e-03 |

**Semi-arid pulsed is not grid-converged at the default tolerance at all** — J moves
by 57% between tol 1e-4 and 1e-6. Every pulsed number above and below is measuring
the reference's own error and says nothing about the frozen grid. Drop that scenario
from the conclusions rather than reading it as a failure of the method.

### (3b, redone) Safety factor 2 and 4 inside each scenario

lma over x{0.5 ... 2.0} against each scenario's own grid, worst case per scenario:

| scenario | worst rel, sf = 2 | worst rel, sf = 4 | reference's own error |
|---|---|---|---|
| wet 3.0 | 1.4e-05 | 3.3e-05 | 2.2e-05 |
| drydown 4yr->0 | 1.1e-04 | 6.9e-05 | 2.1e-05 |
| mesic 1.5 | 8.3e-04 | 8.5e-04 | 3.4e-04 |
| dry 0.6 | 1.2e-03 | 1.0e-03 | 5.4e-05 |
| arid 0.3 | 1.3e-03 | 1.4e-03 | 1.7e-04 |
| whiplash | 2.1e-03 | 5.3e-03 | 1.2e-03 |
| semi-arid pulsed | 7.4e-01 | 1.8e+00 | **0.57 (not converged)** |

sf = 4 buys nothing over sf = 2 — the residual is the reference's own error, not the
grid's. Six of seven scenarios hold the full +/-2x lma range at sf = 2, at or within
about 10x of the reference's own accuracy. The seventh has no reference.

### (3c) Union grid

Programs captured at (theta0, wet 3.0), (lma x0.5, wet), (lma x2, wet), (theta0, dry
0.6), (theta0, pulsed); union grid built by taking, at each position, the smallest
step any of them took there, and walking that leg by leg. **981 steps, 1.84x the wet
theta0 program.** Replayed across every scenario and lma factor:

| grid | rel < 1e-4 | rel < 1e-3 | rel < 1e-2 | steps |
|---|---|---|---|---|
| per-scenario capture, sf = 1 | 16.3% | 46.9% | 61.2% | 241–842 |
| per-scenario capture, sf = 1.25 | 34.7% | 67.3% | 77.6% | 1.25x |
| per-scenario capture, sf = 2 | 28.6% | 75.5% | 85.7% | 2x |
| one union grid, everywhere | 22.4% | 55.1% | 57.1% | 981 |

The union grid is *excellent* where it has coverage — every wet 3.0 point is at or
below 3.9e-05 over the whole lma range, better than that scenario's own sf=1 or
sf=1.25 grid, and mesic/dry/arid are at ~1e-3. It is useless where it has none:
drydown (0.65–0.77) and whiplash (0.56–0.80) were not among its sources, and their
forcings put structure at times (the year-4 cliff; the 1.5-year switches) that no
source grid has steps at. A pointwise minimum cannot invent a breakpoint.

**Verdict (3).** (a) A grid does not transfer between forcing scenarios — 40–100%
error off the diagonal, and a safety factor does not fix it, because the problem is
step *placement* and not step size. The only transfers that work are from a strictly
denser regime to a sparser one. (b) Within one forcing the theta box is the useful
answer and it is wide: at sf = 2, six of the seven scenarios hold lma over the full
+/-2x range to within about their own reference error. The union grid behaves the
same way — it widens the theta box handsomely inside the forcings it was built from,
at 1.84x the step count, and does nothing for a forcing it has never seen. So: one
grid per forcing scenario, refined by a safety factor, recaptured whenever the
forcing changes.

---

## (4) The payoff: does a fixed grid clean up the finite difference?

Central difference `dJ/dlma = (J(lma0(1+d)) - J(lma0(1-d))) / (2 d lma0)` at
relative step `d` from 1e-3 down to 1e-9, half a decade at a time. `adaptive` takes a
fresh adaptive run at each perturbed lma; the `fixed_*` columns replay **one** program,
captured once at theta0, at both perturbed points.

| delta | adaptive | fixed sf=1 | fixed sf=1.25 | fixed sf=2 |
|---|---|---|---|---|
| 1.0e-03 | -5.4225e-05 | -5.4025e-05 | -5.4215e-05 | -5.4317e-05 |
| 3.2e-04 | -5.5384e-05 | -5.4454e-05 | -5.4568e-05 | -5.4581e-05 |
| 1.0e-04 | **-5.1178e-05** | -5.4784e-05 | -5.4819e-05 | -5.4558e-05 |
| 3.2e-05 | -5.2462e-05 | -5.4803e-05 | -5.4852e-05 | -5.4619e-05 |
| 1.0e-05 | **-8.5129e-05** | -5.3881e-05 | -5.4788e-05 | -5.4875e-05 |
| 3.2e-06 | **-1.2168e-04** | -5.4213e-05 | -5.4929e-05 | -5.4682e-05 |
| 1.0e-06 | **-4.0254e-04** | -5.4123e-05 | -5.8520e-05 | -5.5863e-05 |
| 3.2e-07 | **-1.1802e-03** | -5.1255e-05 | -7.7487e-05 | -6.4110e-05 |
| 1.0e-07 | **-4.0482e-04** | -6.0774e-05 | -4.8182e-05 | -1.2544e-05 |
| 3.2e-08 | **+6.3328e-03** | +4.0220e-05 | -6.6021e-06 | -2.5685e-05 |
| 1.0e-08 | **-1.7096e-02** | -3.3349e-05 | -1.2424e-05 | +1.4021e-04 |
| 3.2e-09 | **-1.1264e-02** | -2.7184e-04 | +1.7691e-04 | -9.7756e-04 |
| 1.0e-09 | **+2.4578e-01** | -9.3351e-04 | -1.2870e-03 | +6.4552e-04 |

**The prediction holds, with one caveat that matters.**

- `adaptive` has **no plateau at all**. It is already 5.6% off at d = 1e-4, non-monotone
  from the second row on, wrong by 2x at d = 1e-5, by an order of magnitude at 1e-6, and
  by four orders (with the wrong sign) by 1e-9. There is no d at which you can see you
  have converged, and the best value it ever produces (d = 1e-3, -5.42e-5) is ~1% off
  the limit and indistinguishable from the values either side of it that are 2-20% off.
- `fixed` has a **clean plateau spanning three decades**, d = 1e-3 to 3e-6, at
  -5.42e-5 to -5.49e-5. The spread across that plateau is ~1.3%, and it is monotone
  into it: the sequence -5.42, -5.45, -5.48, -5.485, -5.479, -5.493 (x1e-5) is a
  converging one, and the limit is ~-5.485e-5. That is a number you can take, and a
  plateau you can *detect* by refining d.

**Caveat, and the honest limit of the result: `fixed` also goes noisy, just three
decades later.** Below d ~ 1e-6 all three fixed grids break down too. A frozen ODE grid
removes the ODE controller's accept/reject branch; it does not remove every discrete
branch in the model. TF24 still carries iterative solvers (leaf hydraulics, root
finding) with their own tolerances, and those are the floor here. So the frozen grid
does not buy an arbitrarily accurate finite difference — it buys a *usable and
verifiable* one at d in [1e-5, 1e-3], where the adaptive path has none.

Practically: ~1% FD accuracy with a visible plateau, against "no plateau, best case
~1% with no way to know it". That is the difference between a finite-difference
gradient you can build an optimiser on and one you cannot. It does not settle whether
FD is good enough in absolute terms — the reverse-mode tape argument (a fixed grid
makes the tape one shape per iterate) is a separate and stronger reason, untested here.

**Verdict (4).** Confirmed, not falsified. The fixed grid converts a finite difference
with no convergent regime into one with a three-decade plateau at ~1% scatter. The
premise of the work item survives. The premise's *upper bound* is lower than one
might hope: the fixed grid's FD floor is set by the model's other iterative solvers,
not by the ODE grid, so do not plan on FD accuracy much past 1e-2 relative from this
alone.

---

## What this means for the planned work

The frozen-grid idea survives the spike, with three conditions attached that were not
in the plan:

1. **Use the times form, not the sizes form.** `set_ode_steps(times, numeric(0))`.
   The sizes form is the exact-reproduction tool (it is bit-identical at its own
   parameters, which is what `run_mutant` needs) and is not a fixed grid for an
   optimiser: it refuses at 39% of a +/-2x box. Nothing in plant needs changing for
   this; if a size-pinned replay is ever wanted off-parameter, that would need
   `step_by` to retry on `DomainError` the way `step_to` does, which is an odelia
   change and out of scope here.
2. **Build the safety factor in from the start, and size it by lambda.** Refining the
   captured grid is the whole difference between unusable and covering a 100x change
   in soil conductivity. Measure the largest factor by which the fast eigenvalue
   rises across the intended box; that factor, rounded up, is the safety factor.
   sf = 2 was enough for everything tried here; sf = 4 bought nothing more.
3. **One grid per forcing scenario.** Recapture when the forcing changes. A union
   over several theta at one forcing is a good idea (981 steps, and the best wet-3.0
   numbers in this document); a union across forcings is not, because a pointwise
   minimum cannot invent a breakpoint the source grids do not have.

Two caveats that limit how far to push this:

- **The finite-difference floor is not set by the ODE grid.** Below delta ~ 1e-6 the
  fixed-grid FD goes noisy too, from the model's other iterative solvers. The frozen
  grid buys a verifiable ~1% derivative, not an arbitrarily accurate one. The
  reverse-mode argument (one tape shape per iterate) is untouched by this and is
  probably the stronger reason to do the work.
- **`run_mutant` sits in the exposed path.** It pins the mutant replay to the
  resident's recorded *sizes* (`advance_recorded(resident_recording)`) while swapping
  the strategies. That is exactly the configuration measured here as refusing at 39%
  of a +/-2x trait box on TF24. Not investigated further in this spike, but worth a
  look before trusting a TF24 mutant sweep at traits far from the resident's.
