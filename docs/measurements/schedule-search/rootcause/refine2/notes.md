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
