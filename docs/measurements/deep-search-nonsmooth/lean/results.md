# Leaner and faster than +13%: results

Tests registered in `prereg.md` (predictions unchanged). All numbers below are
**measured** unless marked otherwise. Dry record, sharp gate, inset committed schedule
(`P_out/sched/ins3c_dry.rds`), `adjmap/adj_run.R` at the node-rule ladders' setting,
gradient on every run. Scores in ε per trait with `round4/JT/nudge.R`'s quantities
(`harness/schedule/evaluate.R`: ln J plus 50 elasticities, S_D, a_f3,
recruitment_decay and establishment_window excluded).

- *Error*: rms over the elasticities of (run − reference)/ε; max and its trait; ln J's
  error separately.
- *Nudge*: rms over all quantities of (partner − run)/ε, as `nudge.R`.
- *Rows*: accepted steps × nodes alive (`rows_of`), relative to unstopped 1e-4
  (`L1_1e-4_none`, 513 845) and unstopped 3e-4 (run A, `P_ins3c_dry`, 454 494).
- *Time*: forward + sweep CPU seconds of one process. Up to three (at the end four) runs
  shared the 4-core machine, so times carry ±5–10% noise; rows are exact.

Scripts here: `run.sh` (one run), `lane_l1.sh`, `lane_rest.sh` (L2, L3), `gate.sh` (at
most three R processes machine-wide), `build_tmax.sh`, `l3_pins.R`, `score.R`, `bias.R`,
and the unregistered follow-ups `lane_x1.sh`, `lane_x2.sh`, `lane_x3.sh`. Outputs (rds,
logs, `score.out`, `score_ref2.85e-5.out`, the L3 pins) under
`scratchpad/deep/lean/`.

Reused existing runs (same schedule, same build family, gradient): A (`P_ins3c_dry`,
lib19, 3e-4) and B (`X_ins3c_2.85e-4_dry`), `JT8_ins_{3e-4,2.85e-4}_stop`,
`JT10_ins_{3e-4,2.85e-4}_h05`. No unstopped 1e-4 existed on this schedule
(`X_ins3c_f3_dry` is 3e-4 with a ×3 weight, not 1e-4), so it was run on libJTstop with
`JT_STOP` unset (no detection: the stop code is not entered).

## Reference

Stopped 3e-5 (`L1_ref_3e-5_stop`): 7466 steps, 697 712 rows (×1.54 A's), 386 s; under
the 25-min limit, so 3e-5 was used. Its own nudge (not registered; `X3_ref_2.85e-5_stop`)
is rms **0.0020** (max 0.0067, TF24_cost_scale), ten times under every error measured
below; scoring against the 2.85e-5 run instead changes no verdict
(`score_ref2.85e-5.out`).

## L1: matched error

| Run | tol | Error rms | max (trait) | ln J | Steps | Rows / u1e-4 | Rows / u3e-4 | Fwd + sweep s |
|---|---|---|---|---|---|---|---|---|
| reference, stopped | 3e-5 | 0 | — | 0 | 7466 | 1.358 | 1.535 | 102 + 284 |
| stopped | 1e-3 | **0.0469** | 0.200 (root_P50) | −0.0077 | 4917 | **0.927** | 1.048 | 67 + 215 |
| stopped (nudge) | 9.5e-4 | 0.0456 | 0.191 (root_P50) | −0.0069 | 4922 | 0.928 | 1.049 | 68 + 219 |
| stopped (JT8) | 3e-4 | **0.0205** | 0.046 (TF24_cost_scale) | 0.0041 | 5334 | **0.998** | 1.128 | 70 + 212 |
| stopped (JT8) | 2.85e-4 | 0.0189 | 0.042 | 0.0032 | 5396 | 1.013 | 1.145 | 66 + 205 |
| unstopped | 1e-4 | **0.0128** | 0.050 (stem_c) | −0.0008 | 5489 | 1 | 1.131 | 74 + 225 |
| unstopped (A) | 3e-4 | 0.0094 | 0.026 (TF24_cost_scale) | 0.0011 | 4786 | 0.884 | 1 | 70 + 243 |
| unstopped (B) | 2.85e-4 | 0.0428 | 0.150 (TF24_cost_scale) | 0.0023 | 4808 | 0.888 | 1.004 | 64 + 234 |

Stopped 1e-3's nudge (1e-3 → 9.5e-4): rms **0.0028**, max 0.0093 (root_P50), 519 / 515
cuts. R1 holds at that tolerance: the stop keeps the answer reproducible at 1e-3.

**Predictions**
- Stopped 1e-3's error ≤ unstopped 1e-4's at ≤ 0.8 of its rows (50%): **refuted** on both
  counts, error 0.047 against 0.013 (×3.7), rows 0.93.
- Stopped 3e-4's error < unstopped 1e-4's at ≤ 1.0 of its rows (65%): **refuted**. The
  rows hold (0.998), but the error does not (0.020 against 0.013).

What the stop leaves (`bias.R`): the stopped runs at 3e-4 and 2.85e-4, and every L2
variant at those tolerances, share one error vector (cosines 0.97–1.00, rms 0.019–0.023).
The stop takes out the jitter and leaves a reproducible error of about 0.02 at 3e-4.
That error does not shrink along one direction as the tolerance tightens. Stopped 1e-3's
error is orthogonal to stopped 3e-4's (cos −0.02), and the order between them is 0.69.
A and B straddle the reference (A 0.009, B 0.043). A's small error is luck, on a jitter
of 0.048. So at 3e-4 the error comes from the tolerance, not from the clusters, and
resolving the clusters does not let a looser tolerance buy accuracy.

## L2: resolve fewer clusters

Scratch build `libJTstopTmax` (`build_tmax.sh`): libJTstop's odelia and phylloptim
copied into a new lib dir, the copied `ode_solver_internal.hpp` given `JT_STOP_TMAX`
(yr; a step whose start `time_orig` is after it is never cut), and plant built from a
copy of `JT_src/plant_stop` (`JT_src/plant_stop_tmax`). libJTstop is untouched. Check:
with TMAX = 25 the 382 cuts before b = 25 at 3e-4 are line-for-line identical to JT8's
(same t0, h, u, mode), so the build takes libJTstop's steps until 25. HMIN 0.25 d =
0.000684932 yr.

| Variant | Nudge rms (3e-4 → 2.85e-4) | max (trait) | Rows vs A | Cuts (3e-4 / 2.85e-4) | Error at 3e-4 | Fwd + sweep s |
|---|---|---|---|---|---|---|
| all stops (JT8) | 0.0020 | 0.007 (a_dG1) | +12.8% | 530 / 577 | 0.0205 | 282 |
| HMIN 0.5 d (JT10) | 0.0081 | 0.038 (stem_c) | +7.1% | 241 / 239 | 0.0209 | 264 |
| **HMIN 0.25 d** | **0.0033** | 0.017 (stem_c) | **+8.5%** | 282 / 299 | 0.0195 | 285 |
| **before b = 25 only** | **0.0030** | 0.010 (TF24_cost_scale) | **+6.4%** | 382 / 380 | 0.0221 | 270 |
| **both** | **0.0027** | 0.015 (stem_c) | **+3.6%** | 187 / 194 | 0.0214 | 262 |
| none (A → B) | 0.048 | 0.176 (TF24_cost_scale) | — | 0 | 0.0094 / 0.043 | 313 |

**Predictions**
- HMIN 0.25 d: ≤ 0.006 and ≤ +9% (50%): **holds** (0.0033, +8.5%).
- Before b = 25 only: ≤ 0.0025 and ≤ +9.5% (70%): **refuted** on the nudge (0.0030); rows
  hold (+6.4%).
- Both: ≤ 0.006 and ≤ +6% (45%): **holds** (0.0027, +3.6%, 187 cuts).

The 148 cuts after b = 25 buy nothing measurable (0.0020 → 0.0030). The cuts on steps
shorter than 0.25 d cost about +4% of rows for 0.0013. Both together keep the full
stop's reproducibility at less than a third of its extra rows. They do not change the
error against the reference (0.021).

## L3: resolve only the clusters part 4's bound ranks highest

Rank (`l3_pins.R`): bound = (θ/J/ε)·|λ_soil|·h·|ΔG|·0.2 over A's 221 switch steps in
`P4_G_A.rds` (λ_soil and ΔG of the top soil row, as `p4G.R` stores them). This
reproduces part 4's shares of Σ|c_soil|: top 10 51%, top 30 90%, top 50 94%, by
|λ_soil| top 30 70%. Roots come from A's detection log (`P4_traj_A.err`, 14 728
JTROOT). The pins are A and B on their own steps, with step ends at each chosen step's
first and last root (A's), and the boundaries strictly between them dropped: mkstops.R
applied to every window at once. mkstops.R asserts that no dropped boundary ended a
substepped step. Here B had two such boundaries in b50 and l30, so the assertion was
relaxed. Those merged steps, and the pieces either side of each new end, replay without
soil substeps (mkstops.R's own rule for new pieces). Replays use JT_STOP unset.

| Selection | Ends added | B boundaries dropped | Steps that lost substeps (A / B) | Nudge rms A−B | max (trait) | Rows vs A | Error A / B |
|---|---|---|---|---|---|---|---|
| none (A, B adaptive) | 0 | — | — | 0.048 | 0.176 (TF24_cost_scale) | 1.000 | 0.009 / 0.043 |
| bound, k = 10 | 20 | 3 | 0 / 0 | **0.0218** | 0.077 (TF24_cost_scale) | 1.003 | 0.023 / 0.020 |
| bound, k = 30 | 59 | 8 | 0 / 0 | **0.0105** | 0.036 (a_dG1) | 1.009 | 0.015 / 0.019 |
| bound, k = 50 | 99 | 19 | 3 / 5 | **0.0077** | 0.035 (a_dG1) | 1.017 | 0.012 / 0.013 |
| \|λ_soil\|, k = 30 | 59 | 5 | 11 / 11 | **0.0146** | 0.046 (a_l1) | 1.008 | 0.015 / 0.008 |

(Pinned replays are cheaper in forward CPU than adaptive runs, about 55 s against 65–70
s, so L3 times are not comparable and are left out. Rows are comparable.)

**Predictions**
- k = 30 by the bound, ≤ 0.006 (55%): **refuted** (0.0105).
- k = 10, ≤ 0.02 (60%): **refuted**, narrowly (0.0218).
- k = 30 by |λ_soil| alone, ≤ 0.012 (50%): **refuted** (0.0146).

The ranking does select: the bound beats |λ_soil| at k = 30 (0.0105 against 0.0146), and
the nudge falls with k (0.048 → 0.022 → 0.0105 → 0.0077). But it falls more slowly than
the bound's share of Σ|c| says (90% of Σ|c| at k = 30 leaves 22% of the rms). The
selected brackets are far cheaper in rows than the stop (+0.9% at k = 30, +1.7% at
k = 50, against +3.6% for "both" at 0.0027). At equal reproducibility the stop variants
still win: k = 50 at 0.0077 is no better than HMIN 0.5 d (0.0081) and well short of
"both".

## Follow-ups (not registered): where the cheapest stable variant meets unstopped 1e-4's error

Run after L1–L3 to answer the closing question. Same setup.

| Run | tol | Error rms | Nudge rms (to −5%) | Rows / u1e-4 | Rows / u3e-4 | Fwd + sweep s | Cuts |
|---|---|---|---|---|---|---|---|
| both | 1.5e-4 | 0.0138 | **0.0061** (max 0.025 stem_c) | 0.985 | 1.113 | 284 | 206 |
| both | 1.425e-4 | 0.0146 | — | 0.996 | 1.126 | 283 | 207 |
| both | 1e-4 | 0.0101 | **0.0240** (max 0.088 a_l1) | 1.041 | 1.177 | 296 | 227 |
| both | 9.5e-5 | 0.0247 | — | 1.049 | 1.186 | 270 | 231 |
| all stops | 1e-4 | 0.0118 | **0.0250** (max 0.087 a_l1) | 1.135 | 1.284 | 326 | 709 |
| all stops | 9.5e-5 | 0.0257 | — | 1.149 | 1.299 | 328 | 745 |
| before b = 25 | 1e-4 | 0.0117 | **0.0248** (max 0.088 a_l1) | 1.076 | 1.216 | 308 | 547 |
| before b = 25 | 9.5e-5 | 0.0247 | — | 1.077 | 1.218 | 308 | 545 |
| unstopped | 1e-4 | 0.0128 | **0.0163** (max 0.068 stem_c) | 1 | 1.131 | 299 | 0 |
| unstopped | 9.5e-5 | 0.0104 | — | 1.007 | 1.138 | 274 | 0 |

At 1e-4 → 9.5e-5 all three stop variants move together by 0.024–0.025, largest in a_l1,
and land on the same answer at 9.5e-5 (errors 0.0247–0.0257). The carrier there is not
an arm switch, since the full stop does not remove it. Unstopped 1e-4 also fails the
nudge bar (0.016). This carrier was not located.

## The cheapest configuration that meets nudge ≤ 0.006 and error ≤ unstopped 1e-4's

None of the measured configurations meets both. Error-wise the bar is 0.0128, unstopped
1e-4's own error, and that run's nudge is 0.016. Every stopped variant at 3e-4 is
reproducible (nudge 0.0020–0.0033) but sits about 0.020 from the reference. The
cheapest is "both" (HMIN 0.25 d, no cut after b = 25) at +3.6% rows. Tightening "both"
reaches the bars together only around 1.5e-4: nudge 0.0061 and error 0.0138, both just
over, at 0.985 of unstopped 1e-4's rows and 284 s against 299 s. At 1e-4 a carrier the
stop does not reach puts every variant at a nudge of 0.024. So at matched error the
stop buys reproducibility, not rows. The best measured trade is "both" at about 1.5e-4,
at unstopped 1e-4's cost. Where accuracy at 0.02 is enough, "both" at 3e-4 gives a
nudge of 0.0027 at +3.6% rows over the unstopped 3e-4.
