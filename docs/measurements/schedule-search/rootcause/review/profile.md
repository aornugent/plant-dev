# Where a refinement's time goes, and what the replay buys

From round 5's saved runs (`evidence/r5/runs`, libS, 1e-4, up to three R processes at once) and
the round 2–4 runs on dry, long-wet and episodic-lma. Script: `prof_r5.R`; the bound and
correction checks are inline R over `evidence/r5/score_r5.rds`. [m] unless marked.

## CPU by phase

| case | run: forward / sweep (s) | sweep share | replay: forward / sweep (s) | replay / run | E6 committed + check (s) |
|---|---|---|---|---|---|
| dry | 95 / 209 | 0.69 | 40 / 135 | 0.58 | 224 + 344 |
| long-wet | 111 / 218 | 0.66 | 49 / 147 | 0.60 | 260 + 419 |
| episodic-lma | 60 / 125 | 0.68 | 23 / 71 | 0.51 | 122 + 223 |
| dry-flat | 203 / 415 | 0.67 | 104 / 305 | 0.66 | 488 + 754 |
| epi-adG208 | 57 / 130 | 0.69 | 25 / 78 | 0.54 | 151 + 239 |

- The reverse sweep is 66–71% of a run and 75–77% of a replay. It costs 306–351 µs a row
  whatever the schedule; the forward costs 133–172 µs a row in a run and 97–114 in a pinned
  replay, which skips the controller's trial steps.
- So the replay's forward is 0.40–0.51 of the run's, but its sweep is 0.65–0.74, and the sweep
  sets its price.
- Run + replay is 0.82–0.88 of E6's committed run plus its check in CPU (0.92–1.10 in rows).
- The first run (forward only, about 100 nodes) was not run in round 5; at the forward's cost a
  row it is about 0.13 of a run [i].
- Not part of the algorithm: the short-spell bisection runs (G5b, 1.0–1.2 runs each) and the
  reference ladders exist only to score it.

## The bound behind R1

R1 is held by a bound per quantity, |e_q| / r_min + u_q < ε_q, with r_min = 0.82 and u_q = 0.33ε.

- r_min is the lowest *per-case median* ratio of estimate to error, not a per-quantity minimum.
  Per quantity (|error| > 0.2ε) the ratio runs 0.49–1.17: 0.49 on dry-flat, 0.71 on
  episodic-lma.
- The bound covered all 47 quantities on all five cases, with a margin of at least 0.24ε, but
  the additive 0.33ε does most of the covering: without it the relative term covers only 14–41
  of 47.
- Every error was small (worst 0.56ε), and one to three quantities per case exceeded 0.2ε, so
  the relative term has not been tested where it would matter. A first pass at 1.5ε with a ratio
  of 0.49 has bound 0.72/0.82 + 0.33 = 1.23ε, so it is not covered.

## The correction the replay already pays for

On the square law the run's error is about e_q, so Q − e_q is a better answer at no cost (one
Richardson step).

| layout | case | worst error: Q | worst error: Q − e | rms: Q → Q − e |
|---|---|---|---|---|
| graded (G5) | dry | 0.33 | 0.09 | 0.11 → 0.05 |
| | long-wet | 0.33 | 0.05 | 0.08 → 0.01 |
| | episodic-lma | 0.54 | 0.08 | 0.28 → 0.05 |
| | dry-flat | 0.56 | 0.14 | 0.16 → 0.05 |
| | epi-adG208 | 0.30 | 0.17 | 0.09 → 0.06 |
| graded, 3e-5 (Bga) | dry | 0.36 | 0.08 | 0.13 → 0.03 |
| uniform (B) | dry / long-wet / episodic-lma | 0.79 / 0.47 / 0.76 | 0.44 / 0.17 / 0.42 | |

- On the graded layout the correction cuts the worst error 2–7×; what remains is the short
  spells and the tolerance (worst |error − e − short| 0.06–0.22).
- On the uniform layout it leaves the order-1 component before spell ends (0.42–0.44).
- Matching the corrected answer's accuracy by adding nodes would take about √(0.5/0.12) ≈ 2×
  the nodes, about 2× the rows [i], against the replay's 0.51–0.66 of a run.
- No estimate of the corrected answer's own error exists from one replay; its residual is set by
  how far each quantity's ratio is from 1 (0.49–1.17), plus u_q.
