# Leaner and faster than +13%: tests registered before the runs

The located division that moves with θ was priced at about +11–13.5% of a gradient run,
and the held stop measured +12.8% rows (about +15.5% time). Both pay at every switch
cluster, at the same tolerance as the run they are compared with. These tests ask
whether that price is real at matched error, and whether resolving fewer clusters keeps
the benefit.

They run on the stop build (libJTstop), as a proxy for the division. At θ₀ the stop and
the division integrate the same pieces, so their accuracy and count of resolved clusters
transfer; their costs differ by the retake.

Setup: dry record, sharp gate, inset committed schedule. Scores in ε per trait, using
`round4/JT/nudge.R`'s quantities.

## L1: matched error

*Question:* does resolving the clusters let a looser tolerance reach the accuracy of
today's unresolved 1e-4, at fewer rows?

*Runs:*
- a reference: stopped, at 3e-5 (or the tightest available run, if one exists on this
  schedule);
- stopped at 1e-3 and at 3e-4 (the latter exists: `JT8_ins_3e-4_stop`);
- unstopped at 1e-4 and at 3e-4.

*Measure:* each run's rms elasticity error against the reference, its rows, its steps and
its time. Also the stopped 1e-3's nudge (1e-3 against 9.5e-4), for R1 at that tolerance.

*Predicted:*
- stopped 1e-3's error ≤ unstopped 1e-4's, at ≤ 0.8 of its rows (50%);
- stopped 3e-4's error < unstopped 1e-4's, at ≤ 1.0 of its rows (65%).

## L2: resolve fewer clusters

The stop with a threshold on step length (`JT_STOP_HMIN`), and with no stops after
b = 25 (a time limit; a scratch build if the build has none).

*Runs:* the nudge pair at 3e-4 and 2.85e-4 for each of:
- HMIN 0.25 d;
- stops before b = 25 only;
- both together.

*Measure:* the nudge rms and max, rows, and the number of cuts.

*Predicted:*

| Variant | Nudge rms | Rows | Probability |
|---|---|---|---|
| HMIN 0.25 d | ≤ 0.006 | ≤ +9% | 50% |
| Before b = 25 only | ≤ 0.0025 | ≤ +9.5% | 70% |
| Both | ≤ 0.006 | ≤ +6% | 45% |

For reference, existing measurements:

| Variant | Nudge rms | Rows |
|---|---|---|
| All stops | 0.0020 | +12.8% |
| HMIN 0.5 d | 0.0081 | +7.1% |
| None | 0.048 | — |
