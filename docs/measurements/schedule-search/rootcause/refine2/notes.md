# The refine loop, built: reject and refine on five cases

`harness/schedule/refine.R` (`refine_schedule`), driven per case by `refine_case.R`, each
run by `refine_run.R` on libS at 1e-4 with round 5's setting. The loop's first run (forward,
100 even nodes) gives the spell edges, T(t)'s ages and the offspring curve; the grading's
width is t_r from the parameters. Pass 1 is a run plus its pinned replay with every other
interior node removed; a rejected pass doubles every count (nested), so the rejected run is
the next run's estimate, e = (Q_coarse − Q_fine)/(4^k − 1). Bound = |e|/0.82 + 0.33 (replay)
or + 0.16 (doubled pair); stop when every bound is under 1 (eps units).

Started at scale 0.5 (167 nodes on dry, against 230 at scale 1) so that pass 1 is coarse
enough to reject. Scored afterwards against the reference ladders (`refine/lib.R`), which
the loop never sees.

## Smoke test (dry, first run only)

First run 28.5 s CPU (0.09 of a G5 run). Ages 3.54 / 17.24 / 24.97 y against round 5's
borrowed 17.45 / 25.30. Scale 1 builds 230 nodes (round 5's G5: 232). Replay nodes are a
subset of level 0's and level 0's of level 1's.

## Pre-registration 17 (before any loop run)

| | prediction | confidence |
|---|---|---|
| P1 | pass 1's worst true error is 0.5–1.5ε on every case, and at least 3 of 5 cases reject at pass 1 | 60% |
| P2 | no accepted run has a true error over ε in any quantity | 85% |
| P3 | every quantity's bound covers its true error at every pass | 75% |
| P4 | every rejected case accepts at pass 2, with worst true error ≤ 0.5ε | 70% |
| P5 | the doubled pair's estimate reads 0.7–1.3 of the error (median over quantities with error > 0.1ε) | 65% |
| P6 | a rejected case costs at most 1.6× round 5's run plus replay | 50% |
| P7 | nothing throws | 90% |

## R20. The loop on five cases from scale 0.5 (`score.R`) [m]

All 30 runs exit 0. Every case rejects pass 1 and accepts pass 2 (level 1, every count
doubled); the pass-2 estimate comes from the rejected run, with no replay.

| case | pass 1: nodes / worst error / worst bound | pass 2: nodes / worst error / worst bound | pass-2 read (median) | CPU total / round 5's run + replay |
|---|---|---|---|---|
| dry | 167 / 1.10 / 1.15 | 286 / 0.27 / 0.50 | 0.84 | 834 s / 478 s = 1.74 |
| long-wet | 152 / 1.01 / 1.32 | 257 / 0.26 / 0.47 | 0.98 | 872 / 524 = 1.66 |
| episodic-lma | 127 / 1.68 / 2.01 | 228 / 0.45 / 0.67 | 0.91 | 448 / 278 = 1.61 |
| dry-flat | 201 / 1.81 / 1.65 | 320 / 0.44 / 0.72 | 1.03 | 1606 / 1027 = 1.56 |
| epi-adG208 | 131 / 1.63 / 1.69 | 232 / 0.66 / 0.55 | 0.45 | 502 / 290 = 1.73 |

- **No false accept.** Every accepted run is within ε in every quantity (worst 0.66ε).
- **Coverage.** At pass 2 the bound covers 46–47 of 47 quantities: dry misses one by 0.004ε;
  epi-adG208 misses a_l1, 0.66ε against a bound of 0.55. At pass 1 dry-flat's replay bound
  misses 6 of 47 (by up to 0.53ε, one estimate of the wrong sign); the pass was rejected anyway.
- **The extrapolated answer** Q − e at pass 2 has worst error 0.02–0.34ε, against 0.26–0.66ε
  for Q.
- **Cost.** The first run is 24–60 s (3–4% of the total). Starting at half scale and doubling
  costs 1.56–1.74× round 5's scale-1 run plus replay, which passed every case at pass 1: a
  reject is the price of starting too coarse. Doubling still beats rescaling by √: a 1.5×
  run that is not nested needs its own replay (≈ 1.5 + 0.9 against 2.0 run units).
- **epi-adG208's under-read.** The reference is sound (a_l1 moves 0.41ε between its two
  rungs). A level-2 run (434 nodes, 460 s) gives a_l1 1.625 → 0.661 → 0.152: from level 0 to 1
  the error fell 2.5×, from 1 to 2 4.3×, and the (level 1, level 2) pair estimates 0.17 against
  0.15 true. Level 0 at scale 0.5 was short of the square law for a_l1. Spell ends are not the
  cause: level 1's own ends sit within 2.5 d of the breakpoints, as on dry.

Scored: P1 fails as worded (3 cases over 1.5ε) but every case rejected; P2 holds; P3 fails
(epi-adG208 a_l1 at pass 2; dry-flat at pass 1); P4 fails on epi-adG208 (0.66 > 0.5); P5 holds
on 4 of 5 (epi-adG208 0.45); P6 fails (1.56–1.74); P7 holds.

## R21. Why epi-adG208's pass-2 pair under-read a_l1 (systematic debugging) [m]

Three hypotheses, each tested with pinned replays or one forward run, each refuted:

1. **Spell ends misplaced by the first run.** Forward runs of level 1 with the establishment
   record: its ends sit within 2.5 d of the breakpoints (median 0.01 d; dry: 2.2 d, median
   0.07 d). Not the cause.
2. **Short spells off the square law** (one interval to two). Pinned replays of levels 1 and 2
   with only the short spells reverted: their part of a_l1's difference falls 0.420 → 0.132
   (×3.2 per doubling, near the law). The rest falls 0.545 → 0.376 (×1.45). Not the cause.
3. **Step dependence in the unpinned pair.** Level 0's nodes on level 1's steps: a_l1 moves
   0.088ε; the schedule part of the difference is 1.05 of 0.97. Not the cause. Step changes
   alone move other quantities by up to 0.19ε (rms 0.034 on dry), which enters the pair's
   estimate divided by 3.

What holds: a_l1's error is 1.625 → 0.661 → 0.152 over levels 0, 1, 2, so from level 1 on it is
on the square law (×4.3, and the level-1/level-2 pair estimates 0.17 against 0.15), and level 0
at scale 0.5 is not. The replay (level −1) under-reads at pass 1 in the same proportion, so
every estimate built from level 0 is consistently low and no internal comparison flags it.
Which spells carry the slow part is not located (six region-mixed replays per level would).
Round 5's scale-1 layout read 0.82–1.17 on all five cases, this one included.

## Pre-registration 18 (before the canonical runs)

The loop now runs in memory (`stand_run`; no runner script, no files): a first run on dry
reproduces the old runner's J, steps, establishment record and T(t) bit for bit, also when the
environment object is reused. Canonical configuration: scale 1, first-run inputs, the loop as
reviewed (pair allowance 0.19, level cap 4, `rooting_depth_max` left out).

| | prediction | confidence |
|---|---|---|
| P8 | every case accepts at pass 1 (level 0, run + replay) | 80% |
| P9 | every accepted run's true error is within ε in all 47 quantities, worst ≤ 0.6ε | 85% |
| P10 | the bound covers every quantity's true error on every case | 70% |
| P11 | the replay's read (median over quantities with error > 0.2ε) is 0.75–1.2 on every case | 70% |
| P12 | total CPU (first run + run + replay) is within 15% of round 5's run + replay, case by case | 70% |
| P13 | nothing fails | 95% |

## R22. The canonical configuration on five cases (scale 1, in memory; `score_s1.R`) [m]

| case | nodes | worst error | worst bound | covered | read (median / lowest) | CPU: first + run + replay | / round 5's run + replay |
|---|---|---|---|---|---|---|---|
| dry | 230 | 0.33 (a_l1) | 0.75 | 47/47 | 1.09 / 0.41 | 35 + 343 + 211 = 589 s | 1.23 |
| long-wet | 220 | 0.31 (a) | 0.66 | 47/47 | 0.87 / 0.87 | 40 + 389 + 227 = 655 s | 1.25 |
| episodic-lma | 205 | 0.57 (TF24_cost_scale) | 0.998 | 47/47 | 0.96 / 0.85 | 26 + 220 + 118 = 364 s | 1.31 |
| dry-flat | 267 | 0.55 (a) | 0.87 | 47/47 | 0.87 / 0.77 | 65 + 671 + 409 = 1146 s | 1.12 |
| epi-adG208 | 194 | 0.54 (a_l1) | 0.73 | 47/47 | 0.61 / 0.61 | 28 + 222 + 127 = 377 s | 1.30 |

- Every case accepts at pass 1, within ε in all 47 quantities (worst 0.31–0.57ε), and every
  quantity's bound covers its true error with at least 0.19ε to spare.
- episodic-lma accepts at a worst bound of 0.998: one more pass would have doubled its cost.
- CPU is 1.12–1.31× round 5's run plus replay. The first run is 4–6% of it; the run and replay
  themselves cost 1.07–1.29× round 5's, with three processes sharing the cores in both rounds; not
  separated further.

Scored: P8, P9, P10, P13 hold; P11 fails on epi-adG208 (read 0.61, against 0.75–1.2); P12 fails
on four of five (1.23–1.31, against within 15%).

## Pre-registration 19 (before the canonical loops without the spread)

libNS: origin PLANT-110 with PLANT-108 reverted (clean revert of its five commits), phylloptim
pinned to 0.9.3; otherwise libS. The user dropped the spread; these runs re-measure the bound's
constants (0.82, 0.33ε, 0.19ε) on the build that will ship. Same five cases, scale 1, in memory.

| | prediction | confidence |
|---|---|---|
| P14 | every case accepts at pass 1 | 50% |
| P15 | every accepted run is within ε in all 47 quantities | 85% |
| P16 | the bound (with 0.82) covers every quantity's true error on every case | 60% |
| P17 | the replay's read (median over quantities with error > 0.2ε) is ≥ 0.82 on every case | 35% |
| P18 | each case's CPU is at most libS's canonical CPU (the spread cost 2–6% of a sweep) | 70% |

## R23. The canonical loops without the spread (libNS; `score_ns.R`) [m]

| case | nodes | worst error | worst bound | covered | read (median / lowest) | with the spread: worst error / read |
|---|---|---|---|---|---|---|
| dry | 230 | 0.36 (a_l1) | 0.74 | 47/47 | 0.62 / 0.30 | 0.33 / 1.09 |
| long-wet | 220 | 0.20 (a_l1) | 0.57 | 47/47 | no quantity over 0.2ε | 0.31 / 0.87 |
| episodic-lma | 205 | 0.53 (lma) | 0.96 | 47/47 | 0.95 / 0.83 | 0.57 / 0.96 |
| dry-flat | 263 | 0.31 (TF24_cost_scale) | 0.54 | 47/47 | 0.65 / 0.47 | 0.55 / 0.87 |
| epi-adG208 | 194 | 0.52 (a_l1) | 0.71 | 47/47 | 0.61 / 0.61 | 0.54 / 0.61 |

- **Accuracy:** every case accepts at pass 1, within ε in all 47 quantities. The worst errors are
  equal or smaller without the spread: 0.20–0.53ε, against 0.31–0.57ε.
- **Coverage:** the bound with the old constants (0.82, 0.33ε) still covers every quantity on every
  case, with at least 0.18ε to spare.
- **The read:** the replay now reads less of the error on three cases (medians 0.61–0.65), so 0.82
  is no longer the lowest per-case median. The bound holds through its fixed term, as R20 found per
  quantity on libS. Re-deriving the ratio as the lowest median (0.61) would push episodic-lma's
  bound to about 1.19 and force a second pass there.
- **CPU:** not comparable. These runs shared the cores with up to six other jobs: three
  investigations, plus three agents building and testing plant.

Scored: P14, P15, P16 hold; P17 fails (dry 0.62, dry-flat 0.65, epi-adG208 0.61); P18 untestable
under the load.

## Pre-registration 20 (the loop as decided: corrected answer, no tolerance term, no splits; scale 0.7)

The user's decisions:
- the loop reports the corrected answer run − e and stops on 0.5|e| + u, with u = 0.22ε after a
  replay and 0.08ε after a doubled pair; the tolerance's own error moves to the step controller;
- the splits are dropped (`ode_split_sign_changes` off).

dry-flat and episodic-lma run on libNS at scale 1 and at scale 0.7: the two cases whose estimates
were least trustworthy at coarse scale (dry-flat's replay had the wrong sign at half scale).

| | prediction | confidence |
|---|---|---|
| P19 | all four loops accept at pass 1 | 70% |
| P20 | the corrected answer's worst true error is ≤ 0.3ε on all four | 65% |
| P21 | the bound covers every quantity's true error on all four | 75% |
| P22 | scale 0.7 costs 0.75–0.90 of scale 1, case by case | 70% |
| P23 | splits off moves the uncorrected run by at most 0.1ε from R23's splits-on run at scale 1 | 60% |
