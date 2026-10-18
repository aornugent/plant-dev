# Is the canonical configuration on the frontier of accuracy, honesty and cost?

The canonical configuration is scale 1 at 1e-4, with a replay at pass 1, doubling on a reject,
and the bound |e|/0.82 + 0.33ε. Below, alternative loop configurations and reformulations are
screened against it: offline on the saved runs first, then the most promising run for real on
libNS. Errors are in ε_q, against the reference ladders (`refine/lib.R`, `ref_ladder`), which the
loop never sees. **[m]** measured, **[i]** inferred. Scripts are beside this file (`fr_*.R`), and
outputs are in `scratchpad/frontier/`.

## Part 1. The offline screen (libS, five cases, saved runs) [m]

Sources: the canonical scale-1 fits (`refine/s1`), round 5's G5 / G5o / G5b (`evidence/r5/runs`), and
the half-scale loops' levels 0–2 with level 0's replay (`refine/s05`). Scripts: `fr_data.R`,
`fr_screen.R`, `fr_rows.R`, `fr_lnj.R` and `fr_tol.R`. CPU is relative to the canonical fit of the
same case: total CPU per accepted answer, first run included. Every libS run shared the cores
with two others.

| candidate | CPU / canonical | worst error | rms | honest? (bound covers) | verdict |
|---|---|---|---|---|---|
| **K0 canonical** (s1, replay, \|e\|/0.82 + 0.33) | 1 | 0.31–0.57 | 0.08–0.29 | 235/235, margin ≥ 0.19 | reference point |
| K0r round 5's G5 (same layout, borrowed ages) | 0.84–0.95 | 0.30–0.56 | 0.08–0.28 | 235/235 | the same configuration. The 5–16% CPU gap is load, not layout |
| **K1 corrected answer Q − e at s1** | 1 | **0.04–0.21** | **0.014–0.049** | the residual is ≤ 0.21 everywhere, under u = 0.33. A bound of 0.5\|e\| + 0.33 (max 0.47–0.60) covers 235/235 | dominates K0 on accuracy at equal cost |
| K2 corrected answer at s0.5 (run + replay) | 0.60–0.78 | 0.28–0.87 | 0.11–0.32 | **no**: dry-flat's half-scale replay has the wrong sign (read −1.0), 5 quantities uncovered by up to 0.52 | cheaper, not honest |
| K2p plain at s0.5 (R20's pass 1) | 0.60–0.78 | 1.0–1.8 | 0.27–0.88 | rejects all five | — |
| K3 doubled pair s0.5 → level 1, no replay | 1.04–1.16 | 0.26–0.66 | 0.07–0.23 | epi-adG208 a_l1 missed by 0.08 | dominated by K0 |
| K4 the same pair, corrected | 1.04–1.16 | 0.02–0.34 | 0.006–0.07 | 235/235 at 0.5\|e\| + 0.19 | dominated by K1 |
| Coarse start (s0.5) and doubling (R20 in full) | 1.23–1.42 | 0.26–0.66 | | epi-adG208 missed | dominated by K0 |
| Forward-only replay for ln J | ≈ 0.74 [i: the replay's sweep is 75% of it] | as K0 | | **no**: the largest elasticity error is 1.7–56× ln J's, so ln J's estimate bounds nothing else. ln J's own read at s0.5 is 0.33 on dry and the wrong sign on dry-flat | dominated on honesty |
| Late spacing ×0.5 | rows 0.994–0.996 | | | | nothing to gain: the late panel is 1.1–1.5% of rows |
| Drop the +2 intervals per spell | rows 0.77–0.84 | ≈ 0.79 on dry (round 2's B, uniform) | | the spell-end component unread (rounds 2–4) | dominated on accuracy |
| Short spells at 2 intervals (replay sees them, u → 0.11) | rows 1.02–1.22 | | | the short-spell term is estimated, not bounded | pays only if the scale can then fall more than 10–20% (see K2) |
| Per-spell allocation (candidate A) | 0.96 (measured before) | | | ln J's split misplaces the elasticities | a 4% tie, at a mechanism's cost |
| Cheaper first run | ≥ 0.97 [i: the first run is 5.7–7.3% of CPU] | | | | ceiling of 3% |
| Reuse the first run's steps | — | | | | not expressible: a pinned program replays a subset of its run's nodes, not a superset [code] |

Where the rows go in a canonical schedule (`fr_rows.R`, G5's steps): founders 11–21%, spell
interiors 38–64%, the spell-end node of each spell 14–25%, short spells 2–25%, and the late
panel 1%. **Scale is a weak lever:** the even-plus-two counts and one node per spell end do not
scale. Scale 0.7 keeps 0.80–0.90 of the rows, and scale 0.5 keeps 0.63–0.74, while the
density-limited error grows ×2 and ×4.

**Tolerance** (`fr_tol.R`, the refine round's same-schedule pairs on episodic-lma, libS): going
from 3e-5 to 1e-4 keeps 0.744–0.751 of the rows (a rows exponent of 0.24 in the tolerance), and
moves the quantities by up to 0.20ε (TF24_cost_scale, rms 0.04–0.06) on four of five schedules.
On that exponent 3e-4 keeps ≈ 0.77 of 1e-4's rows [i]. If the bias is linear in the tolerance,
it grows to ≈ 0.5–0.6ε on episodic-lma [i], more than the whole margin of the plain bound.

**Rejects** (the s05 loops): a rejected pass costs a level-1 run, 0.84–1.19× the pass's run plus
replay, so a reject roughly doubles a case's cost. On the canonical fits the worst bound is
0.66–0.998, with episodic-lma 0.002 under the stop. So on a wider bank the canonical
configuration's expected cost includes some rejects. Against K1's bound the same runs sit at
0.47–0.60.

### What the screen says
- No configuration on the saved data is cheaper than K0 and also honest. The cheap ones (K2,
  forward-only) lose honesty, and the honest ones (K3, K4, coarse start) cost more.
- **K1 is free and dominates K0 on accuracy**: the worst error falls 2.6–8×. Its residual is the
  part the replay cannot see (short spells, tolerance) plus (1 − read)·error, and on the five it
  sits inside the u that the canonical bound already carries.
- K1's headroom could be spent on a coarser scale, but the half scale is where the replay stops
  being honest. Between 0.5 and 1 nothing is measured, so that is the first real test.
- A looser tolerance saves about a quarter of the rows, but its bias is unestimated by
  construction (the replay shares the run's steps). It would need a measured term, as u does
  now. That is the second real test.

## Pre-registration F (before any libNS run of this investigation)

Runs (`fr_run.R`, libNS, one process, configurations in sequence inside it, the first run
shared). The held-out cases are three of the bank and held-out set that the canonical configuration
has never run on, each with a good reference: **dry-lma125** (near extinction, where every
earlier estimator misread; reference u429→u857, own move 0.04ε), **ld104-p50125** (a long-drought
record, the climate that sets ε; u215→u429, 0.07ε) and **episodic** (bank, base traits;
0.02ε). Each runs scale 1 and scale 0.7, each as run + replay at 1e-4. episodic-lma runs scale 1
at 1e-4 and 3e-4, each as run + replay, the 1e-4 pair as the interleaved timing baseline. That
makes 16 SCM runs plus 4 first runs. The extra one over the budget is the 1e-4 baseline, without
which the 3e-4 timing could not be read under the same load. References are libS extrapolations.
Lumped and spread limits agree within 0.084ε on grids that reach ε (`docs/stack-split.md`), which
is a floor on what these scores can resolve.

Corrected bound as registered: **0.5|e| + 0.33** (replay). "Accept" means every quantity's bound
is under 1.

| # | prediction | P |
|---|---|---|
| F1 | canonical (s1, plain bound) accepts at pass 1 on all three held-out cases | 60% |
| F2 | the canonical bound covers every quantity's true error on all three held-out cases | 65% |
| F3 | K1 (Q − e at s1): worst true error ≤ 0.33 on all three; ≤ 0.5 on all three | 55%; 75% |
| F4 | K1's bound (0.5\|e\| + 0.33) covers every quantity on all three | 75% |
| F5 | scale 0.7 keeps 0.80–0.90 of scale 1's rows on every case | 75% |
| F6 | at s0.7 the plain answer's worst error is 1.5–2.5× s1's (median over the three) | 60% |
| F7 | at s0.7 the replay reads 0.7–1.3 (median over quantities with \|err\| > 0.2) on all three | 55% |
| F8 | K2′ (Q − e at s0.7): worst ≤ 0.6 on all three and its bound covers every quantity | 45% |
| F9 | dry-lma125 is the worst case for every configuration (largest worst error at s1) | 50% |
| F10 | episodic-lma at 3e-4 keeps ≤ 0.80 of 1e-4's rows (same schedule) | 60% |
| F11 | episodic-lma: max \|Q(3e-4) − Q(1e-4)\| over quantities is ≥ 0.3ε | 60% |
| F12 | episodic-lma: the 3e-4 replay estimate is within 0.1ε (rms over quantities) of the 1e-4 one | 60% |
| F13 | nothing throws or refuses | 85% |

What would change the recommendation:
- If F3 and F4 hold, K1 replaces K0's answer at no cost.
- If F8 also holds with F5, scale 0.7 + K1 becomes a frontier point 10–20% cheaper.
- If F11 holds, 3e-4 is dominated: its bias must be carried in the fixed term, and that term
  then exceeds what the 23% saving buys back.
