# Does hydraulic shutdown survive convergence under genuine drought?

TF24 SCM, one species, `max_patch_lifetime = 40`, `node_density_in_birth_date = TRUE`
throughout, optimised `-O2` build (`plant/src/plant.so`, already current),
`TESTTHAT_PARALLEL = false`, four runs at a time on four cores.
`J = sum(scm$offspring_production)`; the TF24 default birth rate is 1, so `J` is the
net reproduction ratio itself and `J = 1` is exactly self-replacing.

**No code under `plant/`, `odelia/` or `phylloptim/` was changed.** All four trees are
clean at `claude/trusting-curie-4i9n3l` (`plant 5321593a`, `odelia be3e2cb`), so the
`make test-cpp` / plant fast-sweep guard did not apply and nothing was committed or
pushed. Everything below is scripts in the scratchpad: `ld_common.R`, `ld_probe.R`,
`ld_recstats.R`, `ld_psicrit.R`, `ld_viable.R`, `ld_viable2.R`, `ld_align.R`,
`ld_alignshow.R`, `ld_ladder2.R`, `ld_tail.R`, `ld_floor.R`, `ld_window3.R` and
`ld_repro.R` (the build-change check), with `ld_assemble.sh` building this file
from the sections in `ld_head.md`, `ld_summary.md`, `ld_sec12.md`, `ld_sec3.md`,
`ld_sec4.md`, `ld_sec5.md`, `ld_sec6.md`, `ld_sec7.md`, `ld_sec8.md`.

**Build contention, and one interruption.** Two other agents were working in this
workspace throughout. `phylloptim/inst/include/phylloptim/leaf_model.hpp` and
`git status` on all four trees were checked before every measurement block.

- **11:47-12:09 (viable-stand sweep, alignment check, resolution ladder):** all
  trees clean at every check, the collar-bracket tolerance at its `1e-4` literal.
- **12:09:40:** another agent replaced that literal with a `getenv`-backed
  `collar_bracket_tol()` that returns `1e-4` when `PHYLLOPTIM_COLLAR_BRACKET_TOL`
  is unset, and **rebuilt `plant/src/plant.so` at 12:16:33** — during my ladder
  run. The ladder's parent process had loaded the previous `.so` at ~12:03 and
  `mclapply` workers are forks of it, so every ladder job ran against the
  pre-12:09 build. This is checkable rather than assumed: the ladder's
  `U / 1e-4 / 108` rung returned `J = 7.805230854` and 11 320 steps, the same to
  every digit as the alignment run taken before the edit.
- **12:32-12:36: I stopped and waited.** On finding the tree dirty I killed the
  two runs I had just launched rather than measure against an unknown build, and
  re-ran one ladder configuration on the new `.so` as a check. It reproduced
  **bit-for-bit**: `J = 5.2493301703454511` against the ladder's 5.24933017,
  8522 steps against 8522, 25 202 shutdowns against 25 202, with
  `PHYLLOPTIM_COLLAR_BRACKET_TOL` unset. The edit is numerically inert on the
  default path, so the remaining runs are comparable with the earlier ones.
- **By 12:46 the other agent had reverted**; the tolerance is the `1e-4` literal
  again and `phylloptim` is clean.

**No measurement in this document was taken against a modified tolerance**, and
the four-minute pause above is the only period I had to wait. What contention did
cost is wall-clock: the machine sat at load 7-12 on 4 cores, my workers ran at
27-56% CPU each, and every run took roughly two to four times its solo time.
Timings in the tables are wall-clock under that load and are not comparable with
the short-fixture timings; the numbers themselves are unaffected.

---

## The answer, in one table

| question | answer |
|---|---|
| **A viable stand at lifetime 40?** | Yes, easily. `lma = 0.32` gives `J = 5.25`; the whole range `lma` 0.05-0.32 is viable (`J` 77 down to 5.25) and extinction is between 0.45 and 0.60. The short fixture's own `lma = 0.0825` gives `J = 43` here. `J ~ 1e-10` was a property of `max_patch_lifetime = 5`, not of the trait. |
| **Does the record carry real drought?** | Yes. 41 years, 1095 mm/yr mean, three multi-year droughts (y8-10 at 374 mm/yr, y20-22 at 409, y32-34 at 453), driest single year 182 mm, longest dry run 191 days, 18 dry runs over 90 days, 9.5% wet days. |
| **Is any of the 2931 curvature jumps a step boundary?** | **None of 2931**, exactly as at lifetime 5. After alignment, all 2931, for 8% more steps. |
| **Does shutdown survive convergence?** | **No.** Aligned, the share falls 0.0808% -> 0.0253% -> 0.00606% -> 0.00319% -> **0.00203%** over `ode_tol` 1e-3 to 1e-7, still falling at the last rung; the count falls 6276 -> 2350 -> 745 -> 545 -> **504** while the denominator triples. |
| **What is the 0.002% that is left?** | A **birth transient**, not drought. It scales with cohort introductions (545 at 108 nodes, 819 at 215, same tolerance) rather than with time or solves — **four to five solves per introduction** — and tightening `ode_tol` ten-fold moves it 8%. A newborn's roots reach the surface layer only. |
| **Where does the residual fall?** | **Not in the droughts.** The driest year in the record (182 mm) has **3 shutdowns in 89 061 solves**; one drought year has **zero**; **41% of the run's total falls in the first four years**, which are wetter than median. Unaligned, it is flat at 0.33-0.43% across all five eight-year windows with no trace of the rainfall in it. |
| **The other non-interior branches** | `boundary-soil` and `shade-death` are **exactly zero in every run**. `boundary-root-crit` is 48 at worst, 8 aligned. `boundary-crit` -- the ordinary water-limited optimum -- carries 4-13% of solves everywhere and is the only non-interior branch that is genuinely occupied. |
| **Does the long horizon differ from the short one?** | **In `J`, yes, and it matters.** At lifetime 5 the unaligned error was a coarse-node pathology (+140% at 88 nodes, 0.5% at 175). At lifetime 40 it is signed and persistent: **-35%, -17%, -40% at 108, 215 and 429 cohorts**, and -22% at `ode_tol = 1e-5`. In the shutdown numbers, no: they match the short fixture to the third significant figure. |

**Verdict: smoothing the switch is free.** Under genuine multi-year drought, at
the modal test horizon, with a stand five times self-replacing, a converged
trajectory reaches `hydraulic-shutdown` on 0.002% of leaf solves; that residue
is a few solves per newborn cohort, it does not track the rainfall, and **99.5%
of what a shipped-tolerance unaligned run reports on that branch is step
placement** (0.00203% against 0.3793%).
Nothing in the ecology of this configuration is lost by never visiting it.

**With one limit on that.** The branch is nearly unreachable *here* because the
wettest soil layer never approaches `psi_crit` -- 1e-13 to 1e-19 MPa of suction
against a 5.87 MPa threshold, through a 182 mm year. 1.5 m of soil under
1095 mm/yr buffers this record. Whether a genuinely arid site reaches it is a
different measurement and this is not it.

**And one finding that was not the question.** Knot alignment is no longer
optional at this horizon. Unaligned, `J` is 17-40% low and does not converge
under four-fold cohort refinement or two decades of `ode_tol`. Aligned, it is
right to 0.3% at `ode_tol = 1e-3` with 9931 steps. Fewer steps in the right
places beats 61% more steps in the wrong ones.

---

## 1. A viable stand at a 40-year horizon

`max_patch_lifetime = 40`, `node_density_in_birth_date = TRUE`, forcing
`long-drought` (below), default cohort schedule (108 nodes), `ode_tol = 1e-3`,
adaptive, no extra stops. The TF24 default birth rate is 1, so
`sum(scm$offspring_production)` *is* the net reproduction ratio and `J = 1` is
exactly self-replacing (checked: `net_reproduction_ratios` returned the same
number as `J` at both probe points).

| `lma` | `J` | steps | shutdown share |
|---|---|---|---|
| 0.05 | 77.3 | 8489 | 0.427% |
| 0.0825 | 43.1 | 8383 | — |
| 0.12 | 42.6 | 8400 | 0.407% |
| 0.20 | 31.9 | 8608 | 0.412% |
| **0.32** | **5.25** | **8522** | **0.356%** |
| 0.45 | 0.104 | — | — |
| 0.60 | 9.26e-08 | — | — |

**Chosen: `lma = 0.32`, `J = 5.25`** — five times self-replacing, within the
brief's order of magnitude of 1, and not on the knife edge at `J = 1` (which
sits near `lma = 0.375`, where a discretisation error of the size being measured
would flip viability itself). Every `lma` from 0.05 to 0.32 gives a viable
stand; the extinction boundary is between 0.45 and 0.60. The short fixture's
`lma = 0.0825` is also viable here at `J = 43`.

**The precondition is met, and by a wide margin.** The short fixture's
`J ~ 1e-10` is not a property of the trait — the same `lma = 0.0825` gives
`J = 43` at this horizon. It is a property of `max_patch_lifetime = 5`: the
stand has no time to reproduce.

Also worth stating before anything else: **the shutdown share barely moves with
`lma`** — 0.427% at 0.05 down to 0.356% at 0.32, a 20% spread over a six-fold
change in leaf mass per area that takes the stand from 77x self-replacing to 5x.
Whatever sets it, it is not the trait.

## 2. The rainfall record

`probe7_rain.R`'s seasonal Markov-chain gamma generator with `ge_rain.R`'s
interannual multiplier, extended to 41 years (14 965 daily control points, one
year of headroom past the 40-year horizon). Occurrence is a seasonal two-state
Markov chain, a wet day's depth is gamma, and each year's depths are scaled by
that year's multiplier. The multipliers are ordinary years drawn on
`[0.85, 1.30]` with three multi-year droughts and four wet years written in.
Depths are then rescaled so the whole record means 3.0 mm/day.

| | |
|---|---|
| mean | 3.000 mm/day (1095 mm/yr) |
| wet-day fraction | **9.48%** |
| events (runs of consecutive wet days) | 830, mean 54.1 mm, largest 681 mm |
| top 10% of events carry | **41.1%** of all rain |
| longest dry run | **191 days** (year 8) |
| dry runs longer than 90 days | **18** |
| annual total: median / min / max | 999 / **182** (y10) / 2831 mm (y38) |

**Three multi-year droughts**, by three-year running mean against the 1095 mm/yr
record mean:

| years | 3-yr mean | vs median |
|---|---|---|
| **8-10** | **374 mm/yr** | 0.37x |
| **20-22** | **409 mm/yr** | 0.41x |
| **32-34** | **453 mm/yr** | 0.45x |

and six wet years — y5 (2166), y13 (2234), y23 (2073), y24 (1661), y29 (1587),
y37-38 (1646, 2831). Per-year totals, wet fractions and longest dry runs are in
`ld_recstats.R`'s output.

This is a seasonal, storm-dominated climate: 9.5% of days are wet, a tenth of
the events carry two fifths of the water, and every year has a dry season of
40-190 days. It is not a stationary drizzle.

## 3. Alignment

The active knots are the times where the rainfall interpolant's second
derivative jumps. `monotone_slopes` pins both slopes to zero across a pair of
zero control values, so a span between two zero days is identically zero and
meets its neighbour smoothly; a knot carries a jump iff at least one of
`y[k-1]`, `y[k]`, `y[k+1]` is non-zero. Over the 40-year run:

| | count |
|---|---|
| daily control points in `(0, 40)` | 14 599 |
| **active knots in `(0, 40)`** | **2931** (20.1% of the daily grid) |
| accepted steps, unaligned, `ode_tol = 1e-4`, 108 nodes | 11 320 |

**0.26 active knots per accepted step** — 3.9 accepted steps per active knot.
Essentially the same ratio as the short fixture's 0.24, so the long horizon does
not change the geometry of the problem: it scales it.

The identity check first, because everything rests on it:

| | `J` | steps |
|---|---|---|
| no events (`empty_events()`) | 7.805230854 | 11 320 |
| `events(events_default(p))` | 7.805230854 | 11 320 |

**Bit-identical** — same `J` to every digit, same step count. The event path and
the default path are the same run, so a zero-depth pulse added to
`events_default` changes only where the integrator stops.

Then the alignment itself, `ode_tol = 1e-4`, 108 nodes:

| | `J` | steps | knots inside a step | knots on a boundary | shutdown |
|---|---|---|---|---|---|
| unaligned | 7.805230854 | 11 320 | **2931** | **0** | **0.3793%** |
| + 2931 active knots | 12.08736655 | 12 226 | 0 | 2931 | 0.0253% |
| + all 14 599 daily knots | 12.08456952 | 21 348 | 0 | 2931 | 0.0092% |

**Not one of the 2931 active knots is a step boundary before the intervention**,
exactly as at lifetime 5. After it, all 2931 are, at a cost of 906 extra steps
(8%). The two aligned runs agree on `J` to **0.023%**; the unaligned one is
**-35.4%** away from them.

Counts, not just shares, because the two differ in what they say
(`ld_alignshow.R`):

| | leaf solves | shutdown **count** | shutdown share | `boundary-crit` | `determined` | domain refusals |
|---|---|---|---|---|---|---|
| unaligned | 9 211 980 | **34 937** | 0.3793% | 8.868% | 0.0290% | 1069 |
| + active knots | 9 303 920 | **2350** | 0.0253% | 6.154% | 0.0066% | 219 |
| + all daily knots | 16 807 300 | **1553** | 0.0092% | 10.232% | 0.0031% | **8** |

`boundary-soil` and `shade-death` are **exactly zero in every run** — neither
branch is reached at all at this horizon, under drought or otherwise.
`boundary-root-crit` goes 48 -> 8 -> 8.

Two things to carry forward:

- **The count falls, it does not merely get diluted.** From active-knot to
  all-daily alignment the solve count rises 1.81x while the shutdown count falls
  1.51x. A branch that is genuinely occupied over an interval of time is entered
  by *every* solve in that interval, so refining the grid multiplies its count by
  the same factor as the denominator. This one does the opposite.
- **The share is sample-weighted, so read counts beside it.** Adding stops
  changes *where in time* the solves are taken, which is why `boundary-crit`
  reads 6.15% with stops only in the rain events and 10.23% with stops on every
  day including the dry ones — the all-daily arm samples the dry stretches, where
  the constrained optimum lives, far more densely. The two arms nonetheless agree
  on `J` to 0.023%. Nothing about the trajectory changed; the sampling of it did.
- **The domain refusals track the shutdowns**: `rejected_thrown` goes
  1069 -> 219 -> 8 across the same three arms, alongside 34 937 -> 2350 -> 1553
  shutdowns.

The mechanism this suggests, and which the rest of the measurement tests: a step
that crosses a rain event without stopping in it mis-integrates the soil water
balance, drives a cohort into a spuriously dry state, the leaf shuts down, and
the carbon that cohort would have fixed is lost. That is the direction the error
runs -- the unaligned run's `J` is **35% LOW**, not high.

## 4. The headline: does shutdown survive convergence?

Three arms, all at `lma = 0.32` on `long-drought`: **U** unaligned, **A** with a
zero-depth pulse at each of the 2931 active knots, **D** with one at each of the
14 599 daily control points. `ode_tol` is swept at the default 108-node cohort
grid; the cohort grid is then refined by bisection at `ode_tol = 1e-4`
(`ld_ladder2.R`, `ld_tail.R`).

| arm | `ode_tol` | nodes | steps | `J` | leaf solves | **shutdown n** | **shutdown %** | `boundary-crit` % | `determined` % |
|---|---|---|---|---|---|---|---|---|---|
| U | 1e-3 | 108 | 8 522 | 5.2493 | 7.07e6 | 25 202 | **0.3565** | 13.489 | 0.1289 |
| U | 1e-4 | 108 | 11 320 | 7.8052 | 9.21e6 | 34 937 | **0.3793** | 8.868 | 0.0290 |
| U | 1e-5 | 108 | 15 961 | 9.3783 | 1.29e7 | 46 589 | **0.3621** | 6.722 | 0.0260 |
| U | 1e-4 | 215 | 11 593 | 10.0660 | 1.85e7 | 57 664 | **0.3118** | 9.365 | 0.0317 |
| U | 1e-4 | 429 | 12 298 | 7.8301 | 3.85e7 | 96 790 | **0.2513** | 11.631 | 0.0253 |
| **A** | 1e-3 | 108 | 9 931 | 12.0526 | 7.77e6 | 6 276 | **0.08078** | 9.345 | 0.1352 |
| **A** | 1e-4 | 108 | 12 226 | 12.0874 | 9.30e6 | 2 350 | **0.02526** | 6.154 | 0.00662 |
| **A** | 1e-5 | 108 | 16 391 | 12.0780 | 1.23e7 | 745 | **0.00606** | 4.660 | 0.000154 |
| **A** | 1e-6 | 108 | 23 116 | 12.0790 | 1.71e7 | 545 | **0.00319** | 4.096 | 0.000076 |
| **A** | 1e-7 | 108 | 33 704 | 12.07871 | 2.49e7 | 504 | **0.00203** | 3.860 | — |
| A | 1e-4 | 215 | 12 486 | 12.1084 | 1.87e7 | 3 959 | 0.02117 | 7.152 | 0.00648 |
| A | 1e-4 | 429 | 13 131 | 13.0342 | 3.89e7 | 7 050 | 0.01814 | 9.974 | 0.00519 |
| D | 1e-5 | 108 | 24 964 | 12.0780 | 1.94e7 | 743 | **0.00384** | 8.883 | 0.000098 |
| D | 1e-6 | 108 | 31 007 | 12.07876 | 2.37e7 | 550 | **0.00232** | 7.390 | — |

The last two rungs were run separately (`ld_tail.R`) once the first ladder made
clear the sequence had not flattened.

**`boundary-soil` and `shade-death` are exactly zero in every one of these runs.**
`boundary-root-crit` is 48 at worst and 8 in the aligned arms. So of the five
non-interior branches the brief asks about, only two are reached at all at this
horizon: `boundary-crit`, which is the ordinary water-limited operating point and
carries 4-13% of all solves everywhere, and `hydraulic-shutdown`.

### The answer

**The share converges to zero; the count converges to about 500.** Read the
aligned arm down the tolerance ladder:

| `ode_tol` | leaf solves | shutdown count | share |
|---|---|---|---|
| 1e-3 | 7.77e6 | 6276 | 0.0808% |
| 1e-4 | 9.30e6 | 2350 | 0.0253% |
| 1e-5 | 1.23e7 | 745 | 0.00606% |
| 1e-6 | 1.71e7 | 545 | 0.00319% |
| 1e-7 | 2.49e7 | **504** | **0.00203%** |

and the all-daily arm lands in the same place from a different grid: 743 at
`ode_tol = 1e-5`, **550** at 1e-6.

The share is still falling at the last rung and shows no sign of a floor. The
count is a different story: it falls 8.4-fold from `ode_tol` 1e-3 to 1e-5 and
then almost stops — 745, 545, 504 — while the denominator doubles over the same
three rungs. Two independently gridded runs, `A` at 1e-7 (2.49e7 solves) and `D`
at 1e-6 (2.37e7 solves), give 504 and 550.

**A flat count under a growing denominator is a fixed number of discrete events,
not an occupied interval.** A branch genuinely occupied over a stretch of time is
entered by *every* solve in that stretch, so refining the grid multiplies its
count by the same factor as the denominator. So the share goes to zero, and
underneath it sits a residue of roughly 500 solves — 0.002% — that time
refinement does not remove.

### What the residue is: about four solves per cohort introduction

Refining the cohort grid at the converged tolerance separates the two
possibilities (`ld_floor.R`):

| nodes | `ode_tol` | leaf solves | shutdown count | share | **count / introduction** |
|---|---|---|---|---|---|
| 108 | 1e-6 | 1.71e7 | 545 | 0.00319% | **5.05** |
| 215 | 1e-6 | 3.41e7 | 819 | 0.00240% | **3.81** |
| 108 | 1e-7 | 2.49e7 | 504 | 0.00203% | **4.67** |

Doubling the cohort grid at fixed tolerance doubles the solves and takes the
count from 545 to 819 — it **grows with the number of introductions**, not with
the number of solves and not with model time. Tightening the tolerance ten-fold
at fixed cohorts moves it 545 to 504, 8%. Across all three the residue is
**four to five leaf solves per cohort introduction**, and section 5 finds 41% of
it in the first four years, where the introductions are densest.

So the residue is a transient at birth: a newly introduced cohort is small, its
roots reach `min(height, rooting_depth_max)` — the surface layer alone — and for
a handful of solves it sees a column far drier than the five-layer minimum.
That is the model doing what it is written to do, and it is not what the caveat
was about. It is 0.002% of solves, it does not track the rainfall, and time-step
refinement does not remove it because it is not a time-step error.

The cohort arm makes the same point from the other side. **At fixed `ode_tol`,
refining the cohort grid multiplies the shutdown count almost exactly in step
with the solve count** — 2350 -> 3959 -> 7050 against solves 9.30e6 -> 1.87e7
-> 3.89e7 — so the share barely moves (0.0253% -> 0.0212% -> 0.0181%). Cohort
resolution does not remove shutdown; it just samples the same trajectory more
densely. **Only time-step resolution removes it.** That is exactly what you
would expect if the shutdowns are produced by where the steps land.

**On the unaligned arm the share does not move at all** — 0.3565%, 0.3793%,
0.3621% across three decades of `ode_tol`, and 0.31% / 0.25% under cohort
refinement. The count tracks the solve count throughout. Read on its own, the
unaligned arm looks exactly like a real branch by the scaling test. It is not:
its `J` is wrong by 22-40% at every one of those resolutions. The adaptive
controller never removes the error because its error estimator cannot see the
interpolant's curvature jump, so tightening the tolerance buys more steps in the
same wrong places.

### `J` says the same thing

The aligned arm is **converged at `ode_tol = 1e-3`**: 12.0526, 12.0874, 12.0780,
12.0790 across four decades — a spread of **0.29%**, and 0.03% from 1e-4 down.

The unaligned arm is **not converged anywhere in the range tested**: 5.2493,
7.8052, 9.3783 as the tolerance tightens by two decades, climbing toward the
aligned answer and still **22% below it** at `ode_tol = 1e-5` with 15 961 steps.
The aligned run at `ode_tol = 1e-3` uses **9 931 steps** and is right to 0.3%.
Fewer steps in the right places beats 61% more steps in the wrong places.

`D` (every daily knot, `ode_tol = 1e-5`) gives `J = 12.0780`, agreeing with `A`
at the same tolerance to **4e-6 relative**, so the aligned answer is the answer
and not an artefact of which knots were chosen.

## 5. Where in the record does it fall?

The tally is cumulative over a run, so it was read off runs cut at a sequence of
times with the same introductions, forcing and stops, and differenced
(`run_upto` in `ld_common.R`, `ld_window3.R`). Four-year windows over the whole
horizon, with each multi-year drought cut into single years so a drought year is
its own window. Aligned arm, `ode_tol = 1e-4`, 108 nodes — the configuration
whose `J` is converged to 0.03%. `psi-wet` is the wettest of the five soil
layers, in MPa of suction, read at the cut time.

| window (yr) | solves | **shutdown n** | **shutdown %** | `boundary-crit` % | rain mm/yr | `psi-wet` MPa | |
|---|---|---|---|---|---|---|---|
| 0-4 | 9.07e5 | **963** | **0.10612** | 3.469 | 1397 | 1.1e-13 | |
| 4-8 | 9.13e5 | 159 | 0.01742 | 11.374 | 1216 | 1.8e-15 | |
| **8-9** | 1.28e5 | 12 | 0.00938 | 0.229 | **366** | 1.4e-15 | DROUGHT |
| **9-10** | 8.91e4 | **3** | **0.00337** | 7.141 | **182** | 1.3e-15 | DROUGHT (driest year) |
| 10-11 | 2.19e5 | 19 | 0.00870 | 6.331 | 936 | 7.6e-16 | |
| 11-12 | 2.00e5 | 8 | 0.00401 | 4.227 | 895 | 4.7e-16 | |
| 12-16 | 9.97e5 | 121 | 0.01214 | 5.690 | 1283 | 5.2e-17 | |
| 16-20 | 8.32e5 | 159 | 0.01910 | 6.916 | 722 | 1.9e-17 | |
| **20-21** | 1.57e5 | **0** | **0.00000** | 15.244 | **390** | 1.7e-17 | DROUGHT |
| **21-22** | 2.06e5 | 11 | 0.00535 | 5.304 | **593** | 1.4e-17 | DROUGHT |
| 22-24 | 6.21e5 | 33 | 0.00531 | 1.765 | 1867 | 5.0e-18 | WET |
| 24-28 | 1.00e6 | 299 | 0.02991 | 7.029 | 1213 | 1.6e-18 | |
| 28-32 | 9.14e5 | 180 | 0.01970 | 6.467 | 1000 | 7.2e-19 | |
| **32-33** | 1.62e5 | 15 | 0.00924 | 8.570 | **397** | 6.7e-19 | DROUGHT |
| **33-34** | 1.74e5 | 113 | **0.06482** | 3.308 | **503** | 6.1e-19 | DROUGHT |
| 34-36 | 4.96e5 | 31 | 0.00625 | 11.239 | 987 | 4.2e-19 | |
| 36-40 | 1.29e6 | 224 | 0.01737 | 3.373 | 1651 | 1.5e-19 | WET |

And the unaligned arm, same tolerance, eight-year windows:

| window (yr) | solves | shutdown n | shutdown % | `boundary-crit` % | rain mm/yr |
|---|---|---|---|---|---|
| 0-8 | 1.81e6 | 7629 | 0.4205 | 9.957 | 1306 |
| 8-16 | 1.64e6 | 7018 | 0.4288 | 8.667 | **939** |
| 16-24 | 1.85e6 | 6426 | 0.3476 | 8.008 | 950 |
| 24-32 | 1.86e6 | 6126 | 0.3292 | 9.871 | 1107 |
| 32-40 | 2.05e6 | 7738 | 0.3772 | 7.933 | 1185 |

### The prediction fails, in the direction that says artefact

**Shutdown is not concentrated in drought years. It is, if anything,
anti-correlated with them.**

- **Year 10 is the driest year in the record — 182 mm, a sixth of the mean — and
  it has 3 shutdowns in 89 061 solves (0.0034%).** That is the second-lowest
  share of any window in the run.
- **Year 20-21, a drought year at 390 mm, has exactly zero.**
- The largest share anywhere is **0-4 years, at 0.106%** — a wetter-than-median
  stretch (1397 mm/yr), and the window where cohort introductions are densest.
  **963 of the run's 2350 shutdowns, 41%, fall in the first four years**, which
  are 10% of the horizon. That is the same place they fell at lifetime 5, where a
  third of the run's total landed in `[0, 0.5]`.
- Of the six drought windows, four (8-9, 9-10, 20-21, 21-22) are at or below the
  run's median window share, and a wet window (36-40, 1651 mm/yr) is above four
  of them. Only **33-34** (0.065%) is genuinely elevated, and it is one window
  out of six.

The unaligned arm says the same thing more bluntly: **0.42, 0.43, 0.35, 0.33,
0.38 percent across five eight-year windows** — flat to within a third, with no
trace of the rainfall in it. The eight-year window containing the driest three
years of the record (8-16, 939 mm/yr, containing years 8, 9 and 10) has the
*highest* share of all. A fixed per-solve rate, uniform in time, is what a
per-step failure looks like; it is not what drought looks like.

### Why the branch is nearly unreachable here

The first shutdown test is `wettest_soil_layer >= psi_crit`
(`leaf_model.hpp:3339`) — shutdown requires the **wettest** rooted layer to be
drier than the critical potential. For this strategy
`psi_crit = stem_b * log(1/0.05)^(1/stem_c)` is about **5.87 MPa**, which on the
soil retention curve is `theta` below roughly **0.125** of a saturated 0.428.

The wettest of the five layers never comes close: its suction reads **1e-13 MPa
at year 4 and 1e-19 MPa at year 40** — saturated, to within rounding, at every
cut time including the middle of every drought. A 1.5 m column under 1095 mm/yr
retains water at depth through a 182 mm year and a 191-day dry run, so the deep
layers buffer the whole drought and the branch is never entered from the soil
state.

**This is a statement about this site, not about the hydraulic model.** The
trigger reads the wettest *rooted* layer, and rooting depth is
`min(height, rooting_depth_max)`, so a newly introduced seedling roots in the
surface layer alone and sees a much drier column than these five-layer minima
suggest. That is consistent with where the residual shutdowns actually are —
concentrated at the start of the run, where every cohort is small and shallow —
and section 4 confirms it from the other direction: the residue that survives
time refinement scales with the **number of cohort introductions**, at four to
five solves each, not with model time.

## 6. Does the placement sensitivity persist at a long horizon?

**It does, and this is where the long horizon differs from the short one.**

At lifetime 5 the unaligned run was +140% from converged at 88 cohorts and
already within 0.5% at 175 — a coarse-node pathology that one bisection removed.
At lifetime 40, aligned against unaligned at the same cohort count and the same
`ode_tol = 1e-4`:

| nodes | unaligned `J` | aligned `J` | gap |
|---|---|---|---|
| 108 | 7.8052 | 12.0874 | **-35.4%** |
| 215 | 10.0660 | 12.1084 | **-16.9%** |
| 429 | 7.8301 | 13.0342 | **-39.9%** |

The gap does not close, and it is not monotone: it halves from 108 to 215 nodes
and then returns to worse than it started at 429. Doubling the cohort grid twice
— four times the cohorts, four times the solves, 7% more steps — leaves the
unaligned answer 40% low. Tightening `ode_tol` instead (108 nodes, 1e-3 to 1e-5)
takes it from 5.25 to 9.38 against the converged 12.08, still 22% low at 61%
more steps than the aligned run needs.

**So the short fixture's "it disappears at 175 nodes" does not generalise.** At
lifetime 5 the placement error was one draw from a spread that a finer grid
happened to land inside; over 40 years, with 2931 curvature jumps instead of 412,
the error is systematic, signed (the unaligned answer is always LOW) and does not
wash out. Refining what the adaptive controller *can* see does not fix an error
it *cannot* see.

## 7. Does the long horizon differ qualitatively from the short one?

Every measurement in this workspace before this one was taken at
`max_patch_lifetime = 5`, where `J ~ 1e-10` and the stand is ten orders of
magnitude short of self-replacing. Side by side, at `ode_tol = 1e-4` and the
default cohort grid:

| | lifetime 5, `lma = 0.0825`, `mixed-ordinary` | lifetime 40, `lma = 0.32`, `long-drought` |
|---|---|---|
| `J` (= net reproduction ratio) | 1.77e-10 | **12.09** aligned / 7.81 unaligned |
| record length | 5 yr, one dry run of 130 d | 41 yr, three multi-year droughts, longest dry run 191 d |
| daily control points in range | 1824 | 14 599 |
| active knots | 412 (22.6%) | 2931 (20.1%) |
| accepted steps, unaligned | 1725 | 11 320 |
| active knots per accepted step | 0.24 | **0.26** |
| active knots that are step boundaries, unaligned | **0 of 412** | **0 of 2931** |
| shutdown, unaligned | **0.401%** | **0.379%** |
| shutdown, active-knot aligned | 0.027% | **0.025%** |
| shutdown, all-daily aligned | 0.0084% | **0.0092%** |
| `boundary-soil`, `shade-death` | 0 | **0** |
| unaligned `J` error vs aligned | +140.6% | **-35.4%** |

**What is the same, and it is most of it.** The geometry scales rather than
changing: the same fraction of daily control points are active knots (20-23%),
the same number of active knots per accepted step (0.24 vs 0.26), none of them a
step boundary before the intervention and all of them after, and the same
shutdown shares to within 10% in all three alignment arms. The two branches that
are zero at lifetime 5 -- `boundary-soil` and `shade-death` -- are zero here too.
A record eight times longer with three multi-year droughts in it, and a stand
eleven orders of magnitude more productive, moves the shutdown numbers by less
than the third significant figure.

**What is different is `J`, and it is a large difference.** At lifetime 5 the
unaligned answer was +140% at 88 cohorts and within 0.5% at 175 -- a coarse-node
pathology that one bisection removed, and one draw from a spread of discrete
flips that straddled the converged value in both directions. At lifetime 40 the
error is one-sided (always LOW), it is 17-40% across a four-fold cohort
refinement without closing, and it is 22% low at `ode_tol = 1e-5`. Over 40 years
the run crosses 2931 curvature jumps instead of 412, and the individual flips no
longer average out into a spread you can land inside by accident: they accumulate
into a bias.

**And one thing is qualitatively new: the shutdown residual is not in the
droughts.** The short fixture could not ask this question -- at `J ~ 1e-10` no
plant is ever stressed and there is nothing to distinguish "no drought response"
from "no plants". Here there are plants, there is drought, and the answer is that
the driest year in the record produces 3 shutdowns in 89 061 solves.

## 8. What this settles, and what it does not

**The caveat does not hold. Shutdown is an artefact of step placement at this
horizon too, under a record with three multi-year droughts in it and a stand
five times self-replacing.** Three independent readings agree:

1. **The share does not converge to a nonzero value.** Aligned, it falls
   0.0808% -> 0.0253% -> 0.00606% -> 0.00319% -> 0.00203% over four decades of
   `ode_tol`, still falling at the last rung, while the raw count falls
   6276 -> 2350 -> 745 -> 545 -> 504 and the denominator triples.
2. **What is left is a birth transient, not a drought response.** The residue
   scales with the number of cohort introductions (545 at 108 nodes, 819 at 215,
   at `ode_tol = 1e-6`) and not with time or with solves: **four to five leaf
   solves per introduction**, consistent with a seedling whose roots reach only
   the surface layer. Tightening `ode_tol` ten-fold moves it 8%.
3. **It is in the wrong place in time.** The driest year in the record has 3 of
   89 061 solves on the branch and one drought year has none, while 41% of the
   run's total falls in the first four years, which are wetter than median and
   are where the introductions are densest.

**So smoothing the switch is free here** — nothing in the ecology of this
configuration is being lost by never visiting the branch, because the wettest
rooted layer never gets within orders of magnitude of `psi_crit`.

**But the reason it is free is worth stating as a limit rather than a result.**
The branch is unreachable at this site because 1.5 m of soil under 1095 mm/yr
buffers a 182 mm year. A genuinely arid site — a mean nearer 200-300 mm/yr, or a
shallower column — is a different question, and this measurement does not answer
it. What it does answer is the one that was asked: at the modal test horizon,
with a viable stand and real interannual drought, the branch is not where the
ecology is.

**The finding that is new, and that the short fixture did not show, is in `J`
rather than in shutdown.** At lifetime 5 the placement error was a coarse-node
pathology: +140% at 88 cohorts, within 0.5% at 175. At lifetime 40 it is
systematic, signed and does not wash out — the unaligned answer is 35%, 17% and
40% LOW at 108, 215 and 429 cohorts, and 22% low at `ode_tol = 1e-5` with 61%
more steps than the aligned run needs. **Knot alignment stops being a nicety at
this horizon and becomes the difference between a converged answer and a
40%-wrong one**, and it is cheap: 906 extra steps, 8%, and the answer is right
at `ode_tol = 1e-3`.

## What is missing

- **One record and one trait point.** `long-drought` at `lma = 0.32`. The `lma`
  sweep in section 1 shows the shutdown share is flat in the trait at
  `ode_tol = 1e-3` unaligned (0.36-0.43% over 0.05-0.32), but the ladder was not
  repeated at a second `lma`, and no second record was run at this horizon. A
  wetter control (`long-wet`, generated but not run) and — more useful — a truly
  arid one would say whether the branch is reachable at all in some regime.
- **No pinned-grid arm.** At lifetime 5 the reference was a replayed union
  program, which reached shutdown exactly zero. Here the reference is resolution
  refinement of the adaptive arm, which is what the brief asked for and is the
  cheaper instrument; the two are not the same construction, so "exactly zero"
  there and the residual here are not comparable at the last digit.
- **The 429-node number is not trustworthy and was not chased.** On the aligned
  arm at `ode_tol = 1e-4`, `J` reads 12.087 / 12.108 / 13.034 at 108 / 215 / 429
  nodes — a 7.8% jump at the last. At `ode_tol = 1e-6` the same 108 -> 215
  refinement moves `J` by only 0.21% (12.0790 -> 12.1039), so the 13.034 is
  probably a *time*-resolution failure at a cohort count that needs a tighter
  tolerance, not a converged quadrature value. It is used in section 6 only for
  the like-for-like aligned/unaligned gap at one cohort count, where both arms
  carry it. A 429-node run at `ode_tol = 1e-6` would settle it and was not run.
- **Soil state is sampled at window boundaries only**, which are arbitrary points
  in the seasonal cycle, so the reported wettest-layer suction is an upper bound
  on how dry the column gets between cuts. It is also the minimum over all five
  layers, not over the rooted ones, which is what the shutdown test actually
  reads.
- **The residual shutdowns are located in time but not in the cohort
  population.** Whether the 545 solves left at `ode_tol = 1e-6` are one shallow
  seedling for a long stretch or many cohorts for one step is the measurement
  that would close this, and `operating_point_counts` is a cumulative scalar per
  kind, so it cannot answer that without a new diagnostic.

