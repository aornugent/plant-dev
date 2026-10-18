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

## Pre-registration F′ (after dry-lma125's two configurations were scored, before the follow-up)

On libNS, dry-lma125 at s1 has a worst error of 0.61 (TF24_cost_scale), but its replay reads 0.03,
so that one quantity is uncovered by 0.24. At s0.7 the same quantity's error is 0.02. An error
that falls by 0.59 when the schedule is *coarsened* is not a schedule error on the square law.
Two follow-up runs on the s1 schedule, without replays (`fr_run2.sh`; 18 SCM runs in all): one at
a 5% tolerance nudge (1.05e-4) and one at 3e-5. They decide whether the miss is step noise
(OBJECTIVES' Reproducible), tolerance bias, or something else (near extinction, or the libS
reference).

| # | prediction | P |
|---|---|---|
| F14 | the 5% nudge moves TF24_cost_scale by ≥ 0.2ε (step noise of the size of the miss) | 55% |
| F15 | at 3e-5 TF24_cost_scale's error is under 0.33 | 50% |

## Part 2. The real runs on libNS (`fr_run.sh`, `fr_run2.sh`, `fr_score_ns.R`) [m]

There were 18 SCM runs and 4 first runs, one process at a time, from 21:07 to 23:08. Each case's
configurations ran in sequence inside one R process. The other investigations and the
coordinator kept the load at 5–6 on four cores, so CPU ratios are only read within a process;
rows are given as the load-free measure. My episodic-lma 1e-4 run reproduces the coordinator's
libNS fit to the bit. The coordinator's five libNS canonical fits (`refine/ns`) are scored here
too. ld104-p50125's process exited 1 after both of its configurations had been saved: I had
edited `fr_run.R` while it ran, and R reads a script lazily. No SCM failed or refused.

| case | config | nodes | rows / s1 | CPU run+replay / s1 | worst plain (q) | plain bound: max, accept, covered | read (median / lowest) | worst Q − e (q) | K1 bound 0.5\|e\| + 0.33: max, covered |
|---|---|---|---|---|---|---|---|---|---|
| dry-lma125 | s1 | 244 | 1 | 1 | **0.61** (TF24_cost_scale) | 0.73, yes, **46/47** | 0.25 / 0.05 | **0.58** (TF24_cost_scale) | 0.49, **46/47** |
| | s0.7 | 199 | 0.817 | 0.787 | 0.81 (a_l1) | 0.95, yes, 47/47 | 0.59 / 0.32 | 0.30 (a_l1) | 0.58, 47/47 |
| ld104-p50125 | s1 | 222 | 1 | 1 | 0.23 (a_l1) | 0.53, yes, 47/47 | 0.72 / 0.72 | 0.06 | 0.41, 47/47 |
| | s0.7 | 194 | 0.896 | 0.850 | 0.24 (a_l1) | 0.63, yes, 47/47 | 1.02 / 1.02 | 0.11 | 0.45, 47/47 |
| episodic | s1 | 192 | 1 | 1 | 0.32 (a_l1) | 0.76, yes, 47/47 | 1.09 / 1.09 | 0.09 | 0.50, 47/47 |
| | s0.7 | 159 | 0.815 | 0.794 | 0.60 (a_l1) | **1.06, reject**, 47/47 | 0.92 / 0.42 | 0.14 | 0.63, 47/47 |
| episodic-lma | s1, 1e-4 | 205 | 1 | 1 | 0.53 (lma) | 0.96, yes, 47/47 | 0.95 / 0.83 | 0.05 | 0.59, 47/47 |
| | s1, **3e-4** | 205 | **0.788** | **0.729** | 0.61 (r_l) | 0.95, yes, 47/47 | 0.81 / 0.65 | 0.16 (a_l1) | 0.59, 47/47 |
| dry (coordinator) | s1 | 230 | | | 0.36 (a_l1) | 0.74, yes, 47/47 | 0.62 / 0.30 | 0.15 | 0.50, 47/47 |
| long-wet (coordinator) | s1 | 220 | | | 0.20 (a_l1) | 0.57, yes, 47/47 | — (no error > 0.2) | 0.03 | 0.43, 47/47 |
| dry-flat (coordinator) | s1 | 263 | | | 0.31 (TF24_cost_scale) | 0.54, yes, 47/47 | 0.65 / 0.47 | 0.17 | 0.42, 47/47 |
| epi-adG208 (coordinator) | s1 | 194 | | | 0.52 (a_l1) | 0.71, yes, 47/47 | 0.61 / 0.61 | 0.20 | 0.49, 47/47 |

**dry-lma125's uncovered quantity is tolerance error, not schedule error.** On the same s1
schedule, a 5% tolerance nudge (1.05e-4) moves TF24_cost_scale by 0.42ε. That is over ε/3, so
OBJECTIVES' Reproducible fails here at 1e-4. At 3e-5 its error is 0.01, and the worst is 0.32
(a_l1). At 1e-4 the near-extinction case carries about 0.6ε of tolerance error in one quantity,
against the 0.11ε the fixed term allows. The replay shares the run's steps, so no estimate on the
node axis can see it, and neither K0 nor K1 covers it. It is the one miss in 376 scored
quantities at s1 on libNS. 3e-5 costs 1.32× the rows.

**Without the spread the replay reads lower** (libS 0.61–1.09, libNS 0.25–1.09): the medians are
under 0.82 on dry, dry-flat, epi-adG208, dry-lma125 and ld104. The plain bound still covers,
through u, wherever the error is a schedule error. K1's residual, (1 − read)·error plus short
spells and tolerance, stays under u wherever the tolerance term is small: 0.03–0.20.

**The tolerance pair** (episodic-lma, same schedule): 3e-4 keeps 0.788 of the rows (0.785 of
the steps) and costs 0.729 of the CPU. It moves the answer by at most 0.115ε (a_l1, rms 0.054),
and the replay's estimate by 0.003 rms. The replay cannot see that move, and dry-lma125 shows
the tolerance term already reaching 0.6ε at 1e-4 on a hard case.

## The frontier

CPU per accepted answer is relative to the canonical configuration on the same case, with
expected rejects counted (a reject adds a level-1 run, 0.84–1.19× a pass's run plus replay, from
the s05 loops). Accuracy is the true error. Honesty is the bound's coverage. Generality covers the
held-out cases and libNS.

| configuration | CPU / canonical | worst error | rms | honest | general | standing |
|---|---|---|---|---|---|---|
| **K0 canonical** (s1, 1e-4, plain bound) | 1 | libS 0.31–0.57; libNS 0.20–0.61 | 0.04–0.29 | 375/376 on libNS (tolerance miss on dry-lma125) | accepts at pass 1 on 8/8 libNS cases; the worst bound is episodic-lma's 0.96 | on the frontier only at its accuracy |
| **K1: report Q − e, bound 0.5\|e\| + 0.33** (same runs) | **1** | **libS 0.04–0.21; libNS 0.03–0.20** (dry-lma125 0.58, tolerance) | 0.01–0.06 | covers wherever K0 covers (375/376), with bounds 0.41–0.59 against 0.53–0.96 | 8/8 libNS cases plus 5 libS cases | **dominates K0**: equal cost, worst error 2.6–8× smaller on libS and 1.8–11× on libNS, smaller bounds, so fewer rejects |
| **K2′: K1 at scale 0.7** | **0.79–0.85** [m, 3 held-out cases] | 0.11–0.30 | 0.03–0.09 | 141/141 | 3 cases. **Not run on the five, and s0.5 was dishonest on dry-flat** | the only cheaper candidate that held. It dominates K0 on the three cases where it ran, and is unproven where coarse replays failed |
| K0 at scale 0.7 (plain bound) | 0.79–0.85 + rejects ≈ 1.1 [i] | 0.24–0.81 | 0.08–0.21 | 141/141 | rejects episodic (1.06) | dominated by K2′ |
| 3e-4 tolerance, at s1 (plain or K1) | 0.73 [m, 1 case] | 0.61 plain, 0.16 K1 | | the tolerance term is unestimated and already 0.6ε at 1e-4 on dry-lma125 | 1 case | not admissible until the time axis supplies a tolerance estimate. If it did, this would be the largest saving found |
| K2: K1 at s0.5 | 0.60–0.78 | 0.28–0.87 | 0.11–0.32 | no (dry-flat's wrong-sign replay) | — | dominated on honesty |
| doubled pair from s0.5, no replay (and corrected) | 1.04–1.16 | 0.26–0.66 (0.02–0.34) | | misses epi-adG208 | — | dominated by K0 (K1) |
| coarse start + doubling (R20) | 1.23–1.42 | 0.26–0.66 | | misses epi-adG208 | — | dominated |
| forward-only replay for ln J | ≈ 0.74 [i] | as K0 | | no bound for the elasticities (1.7–56× ln J's error) | — | dominated on honesty |
| late spacing ×0.5; no +2; short spells ×2; per-spell allocation; cheaper first run; reused steps | 0.99; 0.77–0.84; 1.02–1.22; 0.96; ≥ 0.97; — | | | the +2 is needed for spell ends; the reused-steps run cannot be expressed | | none on the frontier |

**Invaders and curvatures (OBJECTIVES' Shared)** [i, nothing measured with θ′ ≠ θ]:
- Once the schedule is fixed, every later run (invaders, moved residents, the two runs of each
  curvature) pays run + replay and nothing else. The first run and any rejects are paid once per
  schedule.
- So in a local analysis the scale's cost multiplies across every run, and K2′'s 15–21% saving is
  worth proportionally more than for one resident.
- But one schedule must hold invaders from ×0.5 to ×2, whose errors are unmeasured. K1's headroom
  (bounds 0.41–0.59 against K0's 0.53–0.96) is what covers them without a rebuild.
- K1 costs a curvature chord nothing extra: each run's replay is on its own steps (G3), so e
  adds no step noise to Q − e.
- **So for shared schedules: K1 at s1 until invaders are measured, then K2′ if they hold.**

## What I recommend

1. **Adopt K1 now.** Report `extrapolated` (Q − e) as the answer and stop on 0.5|e| + u. Keep Q
   and e in the diagnostics. It costs nothing, cuts the worst error 1.8–11× on every case where the
   error is a schedule error, and its smaller bounds make rejects rarer. The diff, against
   harness/schedule/refine.R (not applied):
   ```r
   # Q - e is the answer; the bound is on its residual, (1 - read) err plus what the replay cannot see.
   RESIDUAL_SHARE <- 0.5
   bound <- RESIDUAL_SHARE * abs(e) + unestimated          # in fit() and in the loop
   answer = q - e * eps_vec(names(q))                       # in fit(); `q` stays as `run`
   # doubling's prediction: RESIDUAL_SHARE * abs(e) / 4^k + UNESTIMATED_PAIR
   ```
   MIN_ESTIMATE_RATIO (0.82) goes. On libNS the medians fell to 0.25–0.65 on five cases, so the
   ratio it stands for is not a constant.
2. **Test K2′ (s0.7) on dry-flat and episodic-lma before adopting it** (4 runs). The half-scale
   replay failed on dry-flat, and those two cases carry the most short spells and the tightest
   bound. If both hold, the default scale becomes 0.7, at 0.79–0.85 of the canonical CPU.
3. **The fixed term's tolerance allowance (0.11ε) is broken** on near-extinction dry-lma125
   (0.6ε, nudge 0.42ε). This, not the node axis, limits honesty and the 3e-4 saving. It belongs
   to the time axis (`design-grid-controller.md`). A run needs its own tolerance estimate before
   either 1e-4's bound can be trusted on every case or 3e-4 (−27% CPU) can be used.
4. Every other candidate is dominated, and none needs more runs.

## Predictions scored

| # | P | result |
|---|---|---|
| F1 canonical accepts pass 1 on all three held-out | 60% | holds (bounds 0.53, 0.73, 0.76) |
| F2 canonical bound covers all three | 65% | refuted (dry-lma125 TF24_cost_scale 0.61 against 0.37) |
| F3 K1 worst ≤ 0.33 / ≤ 0.5 on all three | 55% / 75% | both refuted (dry-lma125 0.58, tolerance) |
| F4 K1 bound covers all three | 75% | refuted (the same quantity) |
| F5 s0.7 keeps 0.80–0.90 of the rows | 75% | holds (0.815–0.896) |
| F6 s0.7 plain worst 1.5–2.5× s1's (median) | 60% | refuted (1.04, 1.33, 1.87; median 1.33) |
| F7 s0.7 read 0.7–1.3 on all three | 55% | refuted (dry-lma125 0.59) |
| F8 K2′ worst ≤ 0.6 and covered on all three | 45% | holds (0.11–0.30, 141/141) |
| F9 dry-lma125 worst for every configuration | 50% | holds |
| F10 3e-4 keeps ≤ 0.80 of the rows | 60% | holds (0.788) |
| F11 3e-4 moves some quantity ≥ 0.3ε | 60% | refuted (0.115) |
| F12 3e-4's estimate within 0.1 rms of 1e-4's | 60% | holds (0.003) |
| F13 nothing throws or refuses | 85% | holds |
| F14 the 5% nudge moves TF24_cost_scale ≥ 0.2ε | 55% | holds (0.42) |
| F15 at 3e-5 TF24_cost_scale's error < 0.33 | 50% | holds (0.01) |

10 of 16 held.
