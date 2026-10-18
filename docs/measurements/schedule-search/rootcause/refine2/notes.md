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
