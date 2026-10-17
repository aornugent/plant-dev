# U: layout U for TF24 schedules across the ten-case bank

Subject: layout U from the H5 round (`../h5/notes.md`, "Pre-registration U"): a09's graded
build at spacing s·h (range cap ×s), late edges (b > 25) left out; before b = 10 each
opening edge o is a node and each closing edge c is a node plus a fixed node at c − 12 d;
from b = 10 on, E6's 12-d inset (one node 12 d inside the spell, none at the edge); only
the stretches between fixed nodes scale with s. Built by `h5_sched(cs, s, "node1", tcut =
10)` (`../h5/lib.R`; `u_sched` in `lib.R` here).

Method: every prediction is written here, with a probability, before the run or analysis
it concerns. Every run uses the E6 committed setting (`adj_run_nk.R` on `adjmap/libS`,
KNOTS=0, TOL 1e-4; `run.sh` here, the H5 round's runner with this round's paths).
Errors are in each quantity's ε (`docs/measurements/eps-spread.md`, `eps_vec`) against the
lib19-class reference (`../common.R`); "along M" is the projection on P's unit hydraulic
direction. Scripts are in this directory; outputs in
`scratchpad/deep/rootcause/u/` (`runs/`, `sched/`, `logs/`, `*.rds`). dry's and dry-flat's
U runs are the H5 round's (linked into `runs/`). **[m]** measured, **[i]** inferred.

## Summary (written last)

**U across the bank (s = 1.6 / 1 / 1/1.6, all ten)** [m]:
- **Pairs.** The fine pair (U10, U06) reads the committed error on all ten (reads
  0.94–1.21; episodic-lma flags its error 1.51 and passes after the fine run); the coarse
  pair (U16, U10) on nine (reads 0.76–1.29), failing on episodic, where the coarse step
  falls at order ≈ 2.9 and it over-reads (1.40, C3 2/4). Under STRESS (coord) the coarse
  protocol passes 0.914 of case-draws (1.00 everywhere but episodic, 0.14), the fine one
  0.861 (dry-p50 0.39, dry 0.76, dry-flat 0.84), E6's own pair 0.744.
- **Order.** One direction per case (cos 0.91–1.00) but no common order: pooled 1.02
  (episodic-lma), 1.19–1.20 (dry-p50, dry), 1.52–2.18 (six cases), 2.51–2.91 (wet-adG2,
  episodic); median 1.69. What neither pair sees (outside span(d1, d2)) is rms 0.007–0.062.
- **Cost.** U10 has 1.11× E6 committed's rows (1.04–1.16), 0.77× E6's check; its worst
  error is above E6 committed's on all ten; at E6's worst error U needs 1.10–1.23× E6's rows
  (median 1.15).

**The short-spell issue** (dry, dry-flat; hybrid runs) [m]. 69% / 92% of the placed
stretches keep their count on at least one step (S*), holding 8% / 4% of the a09 proxy.
The stretches that refine on both steps move at order 1.75 / 2.05 (cos 0.95), so S*
carries 68% / all of U's deficit, 89% / 74% of that in the S* stretches ≥ 90 d wide. On dry
their coarse move opposes the rest (cos −0.72). **Fix V** (every stretch ≥ 90 d gets at
least ceiling(3/s) intervals, the smallest minimum that refines on both 1.6× steps)
restores the order (dry 1.20 → 2.21, dry-flat 1.52 → 1.72) but costs 5% / 8% more rows at
E6's worst error and makes dry's coarse pair over-read (1.23, C3 fails). Not adopted.

**Loops replayed on U's ladders** [m on stored rungs; i where interpolated]. Cheapest
feasible: r1 = 1.6, run 2 by P5, T = 0.959× E6's real T (both noises), two gradient runs on
every case-draw, all ten pass in 97.5% (coord) / 99.5% (jit) of draws, worst error 0.93.
On E6's own ladder the same family reaches ×0.856–0.877, but there dry and dry-p50 pass only
by C3's allowance. E6's protocol on U's ladder costs ×1.07 and passes all ten in 17% of
coord draws. The validity flag's interval check, recalibrated by the registered rule
(INT 159.5 d), separates nothing on U (false-valid 5.8% with it, 6.5% without; it rejects
80% of the cheapest loop's finals); U's misreads are not set by interval width.

**Is U fit to be the loop's layout?** As the layout of an honest last-run loop, yes, with
two limits [i]. It keeps both pairs honest on 9–10 of 10 at 1.11× E6's rows, and a loop on
it beats E6 by 4% with far better robustness under STRESS. But its error does not fall at
one order (1.0–2.9 across cases), so OBJECTIVES' "predictable" is not met: the loop's
spacing-ratio estimate under-reads where the order is low (dry-p50 0.64) and the coarse
pair over-reads where it is high (episodic); and the committed rung is less accurate per
row than E6's, which caps the saving. V shows the order can be restored, at a price in
rows and a new over-read; the next lever is where error lives per row, not stickiness.

**Predictions:** 37 registered, 26 held, 11 refuted.

## Setup

- `../h5/lib.R` gained two arguments with defaults that change nothing (`n0 = 0`,
  `W = Inf`: a stretch at least W days wide gets at least ceiling(n0 / s) intervals) and
  records each placed stretch and its interval count (`attr(, "seg")`). Guard
  (`mk_sched.R`): U's six schedules on dry and dry-flat are reproduced exactly [m]. It also
  reads its output directory from H5DIR when set, so the H5 round's scorers
  (`score_ladder.R`) run on this round's runs unchanged.
- Node counts, s = 1.6 / 1 / 1/1.6 (schedule only, seen before the predictions below) [m]:

| case | U | E6 committed |
|---|---|---|
| episodic | 108 / 137 / 189 | 135 |
| dry (H5 round) | 124 / 155 / 205 | 149 |
| long-wet | 138 / 169 / 213 | 157 |
| long-drought | 141 / 170 / 217 | 155 |
| episodic-lma | 93 / 122 / 176 | 120 |
| dry-flat (H5 round) | 174 / 195 / 227 | 191 |
| ld-102 | 132 / 157 / 208 | 143 |
| ld-105 | 120 / 152 / 199 | 146 |
| dry-p50 | 125 / 155 / 206 | 153 |
| wet-adG2 | 146 / 173 / 217 | 158 |

## B. U across the bank

Runs: U16 / U10 / U06 (s = 1.6, 1, 1/1.6) on the eight cases not yet run. Scoring
(`score_ladder.R U <cases>`, the H5 round's scorer, plus `score_u.R`): d1 = x − c,
d2 = c − f; pooled and per-quantity order against the a09 proxy's shrink; cos(d1, d2); the
coarse pair's estimate d1/(1/s_x − 1) and the fine pair's d2/(1 − s_f) of the committed
rung's error, read (median est/err over |err| > 0.2) and C1–C5 (`crit`) on the real runs;
the same under STRESS (decisions on perturbed values: truth + a miss N(0, 0.025²) per
quantity shared by a case's runs + N(0, 0.04²) per run; 1000 draws per case; C1 and the
reads judged against the truth), with the protocol "commit the committed rung when every
|est| < 1, else commit the fine rung with the fine pair's estimate of it", and E6's own
pair under the same draws; rows against E6 committed and check, and rows at E6
committed's worst and rms error (log–log interpolation along U's rungs); worst / rms /
along-M error per rung; what neither pair sees: err_c − est per pair (rms), and the part
of err_c outside span(d1, d2) (rms; no linear use of the two moves reaches it).

### Pre-registration B (before any of the eight cases' runs)

Priors: U on dry and dry-flat (H5 round): pooled order 1.20 / 1.52, cos 0.94 / 0.91,
coarse reads 0.91 / 1.02, fine 1.21 / 1.03, both pairs pass, committed worst 0.42 / 0.70
(E6 0.35 / 0.58), rows 1.10× E6 committed at s = 1, 1.15× / 1.13× at matched worst error.
Rule N over the bank: pooled order 1.35–1.76, episodic-lma 0.92 (cos 1.00), coarse pair
9/10.

| # | prediction | P |
|---|---|---|
| B1 | Pooled order (against the proxy's shrink) in [1.6, 2.4] on at least 4 of the 8 | 30% |
| B1′ | Median pooled order over the 8 in [1.1, 1.7] | 65% |
| B2 | cos(d1, d2) ≥ 0.85 on at least 7 of 8 | 60% |
| B3 | Per-quantity order median in [1.4, 2.2] on at least 6 of 8 | 50% |
| B4 | Coarse pair passes C1–C5 on the real runs on at least 7 of 8 (episodic-lma counted by the protocol: pass after the finer run) | 55% |
| B4′ | Fine pair passes on at least 7 of 8 (same counting) | 65% |
| B5 | Median of the 8 coarse case reads in [0.8, 1.25]; no read under 0.6 | 55% |
| B6 | Committed worst error ≤ E6 committed's on at least 4 of 8 | 35% |
| B7 | episodic-lma: committed worst > 1, and both pairs flag it (some \|est\| ≥ 1) | 55% |
| B8 | Rows U10 / E6 committed, summed over the 8, in [1.03, 1.15] | 70% |
| B8′ | At matched worst error (E6 committed's), U needs ≤ 1.25× E6's rows on at least 5 of the cases where a bracket exists | 50% |
| B9 | Unseen part of the fine pair, rms(err_c − est_f), ≤ 0.08 on at least 6 of 8 | 55% |
| B9′ | The part outside span(d1, d2) has rms ≤ 0.06 on at least 6 of 8 | 45% |
| B10 | STRESS (coord), all ten cases: U's coarse-pair protocol passes ≥ 90% of case-draws | 60% |
| B10′ | U's fine-pair protocol passes ≥ 80% of case-draws, and more than E6's pair under the same draws | 50% |
| B11 | No run throws | 90% |

## S. The short-spell issue (dry and dry-flat)

A stretch's interval count is ceiling(∫ 1/(s·h)), so a short stretch keeps the same count
from one rung to the next; its layout then does not move, and what it contributes to one
move is missing from the other.

**Measurement.** Per placed stretch (`attr(, "seg")` of `h5_sched`; founders, spell
stretches, interiors) the interval count at s = 1.6, 1, 1/1.6. S* = the stretches whose
count is the same on at least one of the two steps; R = the rest (they refine on both).
Two hybrid runs per case split each move into R's part and S*'s part:
- Uxh: U16 with every S* stretch laid out as in U10 (moves on the coarse step only in R);
- Ufh: U06 with every S* stretch laid out as in U10 (moves on the fine step only in R);
so d1 = (x − xh) + (xh − c) and d2 = (c − fh) + (fh − f), the second term of each the
R part. R's order is read against the proxy law (P_xh − P_c)/(P_c − P_fh); the share of U's
order deficit that S* carries is (p_R − p)/(2 − p).

### Pre-registration S (before the stretch counts and the hybrid runs)

| # | prediction | P |
|---|---|---|
| S1 | Share of placed stretches after b1 (founders excluded) in S*: ≥ 40% on dry and ≥ 70% on dry-flat | 65% |
| S2 | R's pooled order ≥ 1.7 on both cases | 45% |
| S2′ | S* carries at least half of U's order deficit, (p_R − p)/(2 − p) ≥ 0.5, on both | 45% |
| S3 | cos(R's d1, R's d2) ≥ 0.9 on both | 55% |
| S4 | On dry-flat, S*'s part of the coarse move along M, x − xh, is at least half of d1's along M | 40% |

Added before the hybrid runs (after the stretch counts, `mk_s.R`): Uxw / Ufw, the same
hybrids with only the S* stretches at least 90 d wide swapped, to see whether the wide
sticky stretches (1–2 intervals over 90–330 d) or the narrow ones carry S*'s part.

| # | prediction | P |
|---|---|---|
| S5 | The wide S* stretches carry at least 70% of S*'s share of the deficit, (p_Rw − p)/(p_R − p) ≥ 0.7, on both (only scored where p_R − p > 0.1) | 50% |

## L. The offline loop policies on U's real ladders

Replay (`../proxies/b_loop.R`, unchanged except that OUTDIR, TAG and the interval check's
threshold INT are now read from the environment, defaults as before): `build_lad.R U`
puts U's ten ladders (s = 1.6 / 1 / 1/1.6 as r) in lad.rds's shape; pass 1 is the full
grid (1673 policies) × 3 modes × 20 draws, pass 2 the proxies round's 84 survivors plus
U's own pass-1 front at 200 draws with every iterate's flag recorded; both noise models
(coord: the scorer's STRESS draw; jit: the measured jitter). "meas" is U's stored rungs
(interpolated in r² between them); clean and order use U's committed error × r^p. T is
in the rows model against **E6's real T, 9287** (the proxies round's guard), and against
E6's protocol replayed on U's own ladder (c → f; reported by the script as "E6 replay").

**Recalibrating the validity flag's interval check (D), rule set before the replay.** For
each case, the widest open interval before b = 20 of U16 (the coarsest rung) and whether
its x–c pair (spacing-ratio estimate, as the loop uses it) passes C1–C5 with a read in
[0.7, 1.4]. INT = the narrowest such interval among failing cases; if none fails, INT = the
widest U16 interval over the ten plus 1 d (the top of the evidence: pairs whose coarse run
is coarser than any measured are invalid). False-valid = P(C2 or C3 fails | valid),
false-invalid = P(invalid | C2 and C3 hold), per mode and noise, and on the final iterates
of the cheapest feasible loops.

### Pre-registration L (before the ladder file is built or any replay)

| # | prediction | P |
|---|---|---|
| L1 | meas / jit: the cheapest feasible loop on U (all ten pass in ≥ 95% of 200 draws) costs T in [0.90, 1.00] × E6's 9287 | 55% |
| L1′ | it costs more than the cheapest feasible loop on E6's own ladder (×0.856) | 80% |
| L2 | meas / coord: a feasible loop exists on U | 75% |
| L3 | the cheapest feasible loop (meas / jit) makes ≤ 2.2 gradient runs on average and never more than 3 | 70% |
| L4 | E6's protocol on U's ladder (U10 → U06) passes fewer case-draws under coord STRESS than U's best loop | 85% |
| D1 | The recalibrated INT is ≥ 150 d | 70% |
| D2 | With it, false-valid ≤ 5% in meas mode under both noises | 65% |
| D2′ | and false-invalid on the cheapest feasible loops' final iterates ≤ 30% (meas / jit) | 55% |

### S results: stretch counts and the hybrid split (`mk_s.R`, `score_s.R dry dry-flat`, `score_s.rds`) [m]

| | dry | dry-flat |
|---|---|---|
| placed stretches after b1 / in S* | 54 / 37 (69%) | 116 / 107 (92%) |
| same count 1.6 vs 1 / 1 vs 1/1.6 / both | 30 / 27 / 20 | 102 / 97 / 92 |
| median width, S* / R | 49 / 271 d | 42 / 151 d |
| S* share of the committed rung's a09 proxy | 0.083 | 0.044 |
| nodes x / c / f / xh / fh | 124 / 155 / 205 / 131 / 191 | 174 / 195 / 227 / 179 / 217 |
| proxy law d1/d2: all / R only | 2.11 / 2.54 | 2.52 / 2.52 |
| measured d1/d2 (projected): all / R | 1.51 / 2.29 | 2.04 / 2.58 |
| **pooled order: all / R** | **1.20 / 1.75** | **1.52 / 2.05** |
| **S*'s share of the deficit, (p_R − p)/(2 − p)** | **0.68** | **1.11** |
| cos(d1, d2): all / R | 0.94 / 0.95 | 0.91 / 0.95 |
| per-quantity order median: all / R | 1.33 / 1.72 | 1.99 / 2.18 |
| rms d1, its S* part / rms d2, its S* part | 0.195, 0.127 / 0.122, 0.037 | 0.298, 0.053 / 0.134, 0.056 |
| along M: d1, its S* part / d2, its S* part | −0.49, +0.26 / −0.31, +0.00 | −0.84, −0.19 / −0.41, −0.22 |
| cos(S* part, move): d1 / d2 | −0.72 / +0.06 | +0.65 / +0.75 |
| wide-only hybrids (dry): pooled order of R + narrow S*, share of S*'s part carried by the wide S* | 1.69, 0.89 | (running) |

- S* is most stretches but a small part of the proxy (4–8%), and it carries most of the
  order deficit: what refines on both steps (R) is near order 2 (1.75, 2.05; per quantity
  1.72, 2.18), one direction (cos 0.95). On dry-flat S* carries all of it.
- On dry the S* part of the coarse move runs against the move (cos −0.72, M +0.26 against
  d1's −0.49): the stretches that go from 1 to 2 intervals on the coarse step and then stop
  (1/2/2 at 286–329 d) carry an error of the opposite sign, so their refinement
  cancels part of the rest's move. 89% of S*'s share sits in the S* stretches ≥ 90 d wide.
- On dry-flat the S* part runs with the move (cos 0.65 / 0.75) and is as large on the fine
  step as on the coarse (0.053, 0.056 rms): it moves at order ≈ 0, a step that does not
  shrink with s.

| # | prediction | P | result |
|---|---|---|---|
| S1 | S* ≥ 40% (dry), ≥ 70% (dry-flat) | 65% | holds (69%, 92%) |
| S2 | R's pooled order ≥ 1.7 on both | 45% | holds (1.75, 2.05) |
| S2′ | S*'s share of the deficit ≥ 0.5 on both | 45% | holds (0.68, 1.11) |
| S3 | cos(R's d1, d2) ≥ 0.9 on both | 55% | holds (0.95, 0.95) |
| S4 | dry-flat: S*'s part of d1 along M ≥ half of d1's | 40% | refuted (−0.19 of −0.84) |

**The fix tested: V.** U, with every placed stretch at least W = 90 d wide given at least
ceiling(3/s) intervals (`h5_sched(..., n0 = 3, W = 90)`). ceiling(m/s) changes on both
ratio-1.6 steps only when the stretch's measure m (its count at s = 1 before rounding) is
at least 8/3, so 3 is the smallest minimum that makes every such stretch refine on every
step (2 / 3 / 5 intervals at s = 1.6 / 1 / 1/1.6). W = 90 d targets the wide sticky
stretches, which carry 89% of S*'s share on dry; narrower ones keep U's rule. Nodes
(schedule only) [m]: dry 135 / 175 / 251 (U 124 / 155 / 205), dry-flat 200 / 239 / 316
(U 174 / 195 / 227); S* after b1 falls from 37 to 21 (dry) and 107 to 84 (dry-flat); the
proxy law is 2.21 / 2.43.

### Pre-registration V (before the V runs)

"Matched error": rows at E6 committed's worst and rms error, interpolated in log error
against log rows along each layout's rungs (`score_var.R`'s rule), V against U.

| # | prediction | P |
|---|---|---|
| V1 | V's pooled order ≥ 1.6 on both | 50% |
| V2 | V's coarse and fine pairs both pass C1–C5 on both | 65% |
| V3 | cos(d1, d2) ≥ 0.9 on both | 60% |
| V4 | V10's rows ≥ 1.1× U10's on both | 75% |
| V5 | At matched worst error, V needs ≤ 1.05× U's rows on both | 45% |
| V5′ | At matched worst error, V needs fewer rows than U on at least one | 40% |
| V6 | V's coarse read in [0.85, 1.2] on both | 50% |

## Results

All 44 runs of the round (24 bank, 8 hybrid, 6 V, plus the H5 round's six U runs reused)
exited 0. Never more than two of this round's R processes ran at once (lanes held by
`.maxmine` in `run.sh`; analysis through `gate.sh`, which counts real R processes only:
the first gate counted shells whose command line named Rscript and blocked itself).

### B results: U across the bank (`score_u.R U`, `score_U_all.rds`; `../h5/score_ladder.R U` with H5DIR, `ladder_U_*.rds`) [m]

Coarse pair = (U16, U10), fine pair = (U10, U06), each estimating U10's error; "stress" =
share of 1000 draws in which the protocol passes C1–C5 (coord noise).

| case | pooled order (cos) | per-q order median | coarse: read, C1–C5, stress | fine: read, C1–C5, stress | E6 pair stress | committed worst (E6) / rms / along M | rows × E6 c / × E6 f | rows at E6's worst (× E6 c) | unseen coarse / fine / outside span |
|---|---|---|---|---|---|---|---|---|---|
| episodic | 2.91 (0.93) | 2.72 | 1.40, **C3 fails** (2/4), 0.14 | 1.04, pass, 0.97 | 0.96 | 0.43 a_l1 (0.30) / 0.133 / −0.05 | 1.04 / 0.69 | 1.14 | 0.144 / 0.050 / 0.043 |
| dry | 1.20 (0.94) | 1.33 | 0.91, pass, 1.00 | 1.21, pass, 0.76 | 0.33 | 0.42 a_l1 (0.35) / 0.163 / −0.51 | 1.10 / 0.77 | 1.15 | 0.047 / 0.071 / 0.040 |
| long-wet | 1.62 (0.94) | 1.64 | 0.91, pass, 1.00 | 1.06, pass, 0.98 | 0.97 | 0.41 a (0.36) / 0.109 / −0.03 | 1.14 / 0.77 | 1.17 | 0.036 / 0.010 / 0.007 |
| long-drought | 1.75 (0.95) | 1.98 | 0.98, pass, 1.00 | 1.02, pass, 0.92 | 0.95 | 0.45 a (0.37) / 0.142 / −0.36 | 1.16 / 0.82 | 1.23 | 0.052 / 0.022 / 0.022 |
| episodic-lma | 1.02 (1.00) | 1.02 | 0.76, flags (C1, C5 trip at err 1.51); passes after the fine run, 1.00 | 1.16, flags; passes after, 1.00 | 0.97 | 1.51 r_l (1.28) / 0.806 / +2.18 | 1.04 / 0.68 | 1.10 | 0.204 / 0.137 / 0.034 |
| dry-flat | 1.52 (0.91) | 1.99 | 1.02, pass, 1.00 | 1.03, pass, 0.84 | 0.19 | 0.70 a (0.58) / 0.214 / −0.57 | 1.10 / 0.79 | 1.13 | 0.065 / 0.047 / 0.030 |
| ld-102 | 2.12 (0.99) | 2.17 | 1.10, pass, 1.00 | 1.03, pass, 0.91 | 0.92 | 0.42 vcmax_25 (0.41) / 0.148 / +0.24 | 1.15 / 0.78 | 1.16 | 0.027 / 0.024 / 0.018 |
| ld-105 | 2.18 (0.94) | 2.34 | 1.19, pass, 1.00 | 0.94, pass, 0.88 | 0.89 | 0.35 a (0.32) / 0.148 / −0.10 | 1.10 / 0.77 | 1.13 | 0.040 / 0.035 / 0.025 |
| dry-p50 | 1.19 (0.97) | 1.25 | 0.80, pass, 1.00 | 1.11, pass, **0.39** | 0.31 | 0.56 a_l1 (0.35) / 0.174 / −0.75 | 1.08 / 0.76 | 1.23 | 0.065 / 0.083 / 0.062 |
| wet-adG2 | 2.51 (0.92) | 2.75 | 1.29, pass, 1.00 | 0.98, pass, 0.96 | 0.97 | 0.48 a (0.44) / 0.134 / +0.07 | 1.16 / 0.80 | 1.19 | 0.062 / 0.016 / 0.008 |
| **all ten** | median 1.69 [1.02, 2.91] | | **9/10** by the protocol; stress **0.914** of case-draws (jit 0.918) | **10/10**; stress **0.861** (jit 0.970) | **0.744** (jit 0.870) | worse than E6's on 10/10 | **1.114** / 0.771 (summed) | median 1.15 [1.10, 1.23] | |

- **One direction per case, but no common order.** cos(d1, d2) 0.91–1.00 everywhere; the
  pooled order runs from 1.0 (episodic-lma, the founders' soil-field error) and 1.2 (dry,
  dry-p50) to 2.5–2.9 (wet-adG2, episodic). Four cases sit in [1.6, 2.4] (long-wet,
  long-drought, ld-102, ld-105).
- **Where the order is over 2 the coarse pair over-reads.** episodic's coarse step falls at
  order ≈ 2.9 (a_l1 err 0.43, coarse estimate 0.95; k_I ×3.2), so C3 fails 2/4 and the
  coarse protocol passes only 14% of stress draws. Its U16 has the narrowest widest
  interval of the bank (151 d), so it is not interval width. Nor do the sticky stretches
  explain it by count: 12 refine on the fine step only and 1 on the coarse step only
  (`mk_s_bank.log`), which would shrink d1 against d2, not grow it, unless their errors
  oppose the rest's as on dry; not split here.
- **Where the order is under 2 the fine pair is fragile under STRESS**: dry-p50 0.39,
  dry 0.76, dry-flat 0.84 (the fine estimate d2/(1 − s_f) amplifies a run's noise ×1.7);
  E6's own pair is worse on exactly those cases (0.31, 0.33, 0.19). The coarse pair's
  estimate amplifies only ×0.8, so it is near 1.00 everywhere it reads.
- **Cost.** U10 has 1.11× E6 committed's rows over the ten (1.04–1.16) and its worst error
  is above E6 committed's on all ten; at E6's worst error U needs 1.10–1.23× E6's rows
  (median 1.15). In the rows model the coarse protocol on the real runs (U16, U10, commit
  U10 or go on to U06) costs 0.978× E6's T; the fine protocol 1.072×.
- What neither pair sees: outside span(d1, d2) rms 0.007–0.062 (max 0.19, dry-p50); the
  fine pair's own unseen part ≤ 0.083 except episodic-lma (0.137).

| # | prediction | P | result |
|---|---|---|---|
| B1 | pooled order in [1.6, 2.4] on ≥ 4 of 8 | 30% | holds (4: long-wet, long-drought, ld-102, ld-105) |
| B1′ | median pooled order over the 8 in [1.1, 1.7] | 65% | refuted (1.94) |
| B2 | cos ≥ 0.85 on ≥ 7 of 8 | 60% | holds (8/8, min 0.92) |
| B3 | per-quantity order median in [1.4, 2.2] on ≥ 6 of 8 | 50% | refuted (3 of 8) |
| B4 | coarse pair passes on ≥ 7 of 8 (protocol) | 55% | holds (7; episodic fails C3) |
| B4′ | fine pair passes on ≥ 7 of 8 | 65% | holds (8/8) |
| B5 | median coarse read in [0.8, 1.25], none under 0.6 | 55% | holds (1.04; min 0.76) |
| B6 | committed worst ≤ E6's on ≥ 4 of 8 | 35% | refuted (0 of 8) |
| B7 | episodic-lma worst > 1 and both pairs flag | 55% | holds (1.51; both flag) |
| B8 | rows U10 / E6 c over the 8 in [1.03, 1.15] | 70% | holds (1.12) |
| B8′ | ≤ 1.25× E6's rows at matched worst error on ≥ 5 | 50% | holds (8 of 8, 1.10–1.23) |
| B9 | fine unseen ≤ 0.08 on ≥ 6 of 8 | 55% | holds (6: dry-p50 0.083, episodic-lma 0.137 over) |
| B9′ | outside span ≤ 0.06 on ≥ 6 of 8 | 45% | holds (7; dry-p50 0.062) |
| B10 | coarse protocol ≥ 90% of case-draws under coord STRESS | 60% | holds (0.914) |
| B10′ | fine protocol ≥ 80% and above E6's | 50% | holds (0.861 against 0.744) |
| B11 | no run throws | 90% | holds |

**The short-spell issue across the bank (schedule only, `mk_s_bank.log`) [m].** S* is
55–85% of the placed stretches after b1 on every case and 3.5–25% of the committed rung's
a09 proxy (episodic 0.25, ld-102 0.17, long-drought 0.13, long-wet 0.12; ld-105 and
episodic-lma 0.035). The hybrid split was run on dry and dry-flat only (S results above):
there S* carries 68% and all of the deficit, the wide S* stretches (≥ 90 d) most of that
(89%, 74%).

### V results: the fix on dry and dry-flat (`score_u.R V`, `../h5/score_ladder.R V`, `score_V_dry+dry-flat.rds`) [m]

| | dry U | dry V | dry-flat U | dry-flat V |
|---|---|---|---|---|
| nodes x / c / f | 124 / 155 / 205 | 135 / 175 / 251 | 174 / 195 / 227 | 200 / 239 / 316 |
| rows c (× U10) | 207 | 219 (1.06) | 421 | 469 (1.11) |
| committed worst / rms / along M | 0.42 / 0.163 / −0.51 | 0.39 / 0.166 / −0.50 | 0.70 / 0.214 / −0.57 | 0.58 / 0.183 / −0.41 |
| **pooled order** (proxy law) | 1.20 (2.11) | **2.21** (2.21) | 1.52 (2.52) | **1.72** (2.43) |
| cos(d1, d2); per-q order median | 0.94; 1.33 | 0.93; 2.18 | 0.91; 1.99 | 0.94; 2.08 |
| coarse pair: read, C1–C5, stress | 0.91, pass, 1.00 | 1.23, **C3 fails** (6/8), 0.27 | 1.02, pass, 1.00 | 1.13, pass, 1.00 |
| fine pair: read, C1–C5, stress | 1.21, pass, 0.76 | 1.12, pass, 0.92 | 1.03, pass, 0.84 | 1.15, pass, 0.68 |
| **rows at E6's worst error** (× E6 c; V / U) | 1.148 | 1.204 (**1.049**) | 1.132 | 1.222 (**1.080**) |
| rows at E6's rms error (V / U) | 1.111 | 1.184 (1.065) | 1.126 | 1.219 (1.083) |

- **V restores the order on dry** (1.20 → 2.21, per quantity 1.33 → 2.18) and raises it on
  dry-flat (1.52 → 1.72), as the hybrid split said it would: the wide sticky stretches were
  the deficit.
- **It does not pay at matched error**: 5% (dry) and 8% (dry-flat) more rows at E6's worst
  error, 7–8% at its rms. The forced intervals sit where the a09 measure says little error
  lives (S* is 4–8% of the proxy), so they buy order, not accuracy per row.
- **And dry's coarse pair now over-reads** (1.23; a_l1 ×1.9, TF24_cost_scale ×2.4,
  root_P50 err −0.06 against est −0.37), failing C3 and 73% of stress draws: once the wide
  stretches refine on the coarse step, the coarse move is larger than the square law with
  the a09 shrink allows for (per quantity up to 5.4). The same over-read as U's episodic.

| # | prediction | P | result |
|---|---|---|---|
| V1 | V's pooled order ≥ 1.6 on both | 50% | holds (2.21, 1.72) |
| V2 | both pairs pass on both | 65% | refuted (dry's coarse pair fails C3) |
| V3 | cos ≥ 0.9 on both | 60% | holds (0.93, 0.94) |
| V4 | V10 rows ≥ 1.1× U10's on both | 75% | refuted (1.06, 1.11) |
| V5 | ≤ 1.05× U's rows at matched worst error on both | 45% | refuted (1.049, 1.080) |
| V5′ | fewer rows than U at matched worst error on at least one | 40% | refuted |
| V6 | V's coarse read in [0.85, 1.2] on both | 50% | refuted (1.23 on dry) |
| S5 | the wide S* carry ≥ 70% of S*'s share on both | 50% | holds (0.89, 0.74) |

### L results: the loop policies on U's ladders (`build_lad.R U`, `../proxies/b_loop.R` with LAD/OUTDIR/TAG/INT, `f_front_u.R`; pass 1 `b_loop_pass1_*_U.log`, pass 2 `b_loop_pass2_*_U.rds`, 124 policies × 200 draws; `f_front_u2.log`) [m on U's stored rungs; i where a run is interpolated between rungs]

| mode / noise | cheapest feasible policy on U | T | × E6 (9287) | all ten | case-draws | worst W / W95 | k mean / max | on E6's ladder (proxies round) |
|---|---|---|---|---|---|---|---|---|
| meas / jit | loop r1 1.6, run 2 by P5 (t2 0.4), τ 0.9 | 8909 | **0.959** | 0.995 | 1.00 | 0.93 / 0.89 | 2.0 / 2 | ×0.856 (x → c loop) |
| meas / coord | same, τ 1.0 | 8909 | **0.959** | 0.975 | 0.998 | 0.93 / 0.89 | 2.0 / 2 | ×0.877 |
| meas / jit | x → c, fixed R 1.6, τ 0.9 | 9209 | 0.992 | 0.995 | 1.00 | 0.70 / 0.70 | 2.2 / 4 | |
| meas / coord | E6's protocol on U's ladder (U10 → U06) | 9953 | 1.072 | 0.17 | 0.85 | 0.70 | 2 | E6 itself: all ten 0.005 |
| clean / jit (U's committed error × r²) | loop r1 2.0, P5 t2 0.55 | 8506 | 0.916 | 0.985 | 1.00 | 0.95 | 2.1 / 3 | ×0.754 |
| order / jit | loop r1 2.0, P5 t2 0.55, clip | 8967 | 0.966 | 0.95 | 0.995 | 0.97 | 2.2 / 3 | ×0.801 |

- **On U the loop saves 4% against E6** (meas, both noises), with two gradient runs on
  every case-draw, all ten passing in 97.5–99.5% of draws. On E6's own ladder the same
  family saves 12–14%, but there dry and dry-p50 pass only by C3's one-miss allowance (reads
  0.06, 0.29); on U their x–c reads are 0.73 and 0.64 in the loop's spacing-ratio form
  (`cal_int.R`), 0.91 and 0.80 in the a09-shrink form.
- The saving is small because U's committed rung costs 1.11× E6's: the final runs land at
  r = 0.80–1.20 (per case 1.00 0.84 1.18 1.14 0.80 0.90 1.05 1.02 0.84 1.20), mostly between
  U's rungs, where the replay interpolates the error linearly in r² [i]. The cheapest point
  runs close to ε (worst W 0.93).
- E6's protocol on U's ladder is dearer (×1.07) and fragile under coord STRESS (all ten in
  17% of draws): its fine estimate amplifies noise on dry, dry-p50, dry-flat.

**D, the validity flag, recalibrated on U (`cal_int.R`, `d_flag_u.R`, `d_flag_u.log`) [m on
replays].** U16's widest open interval before b = 20 is 151–174 d. Two x–c pairs fail the
rule's test: episodic-lma (C1/C5 trip, err 1.51; 168 d) and dry-p50 (read 0.64; 160 d), so
INT = 159.5 d, and only episodic's and ld-105's U16 (151, 157 d) pass the interval check.

| mode / noise | valid | false-valid | false-invalid | final iterates of the cheapest loop: valid, false-invalid | without the interval check: false-valid / false-invalid |
|---|---|---|---|---|---|
| meas / coord | 0.42 | 0.058 | 0.57 | 0.20, 0.80 | 0.065 / 0.067 |
| meas / jit | 0.44 | 0.019 | 0.55 | 0.20, 0.80 | 0.028 / 0.042 |
| clean / coord | 0.33 | 0.011 | 0.67 | 0.10, 0.90 | 0.005 / 0.040 |
| order / coord | 0.32 | 0.028 | 0.68 | 0.30, 0.70 | 0.017 / 0.169 |

- The recalibrated interval check buys almost no honesty (false-valid 5.8% against 6.5%
  without it, coord) and rejects 55–57% of the iterates that pass, 80% of the cheapest
  loop's finals. On U the misreads are not set by interval width (dry-p50 fails at 160 d
  while long-drought and dry-flat read well at 172–174 d, episodic over-reads at 151 d), so
  no interval threshold separates them. Without it, the noise, order and proxy checks are
  honest to 2.8–6.5% in meas mode.

| # | prediction | P | result |
|---|---|---|---|
| L1 | cheapest feasible loop (meas / jit) in [0.90, 1.00] × E6 | 55% | holds (0.959) |
| L1′ | dearer than the cheapest on E6's ladder (×0.856) | 80% | holds |
| L2 | a feasible loop exists in meas / coord | 75% | holds (0.959, all ten 0.975) |
| L3 | k mean ≤ 2.2, max ≤ 3 | 70% | holds (2.0, 2) |
| L4 | E6's protocol on U passes fewer case-draws (coord) than U's best loop | 85% | holds (0.85 against 0.998) |
| D1 | recalibrated INT ≥ 150 d | 70% | holds (159.5 d) |
| D2 | false-valid ≤ 5% in meas under both noises | 65% | refuted (coord 5.8%, jit 1.9%) |
| D2′ | false-invalid on the cheapest loop's finals ≤ 30% | 55% | refuted (80%) |

## summary.rds

`scratchpad/deep/rootcause/u/summary.rds` (`collect.R`; 44 gradient runs: U 30 including
the H5 round's six, hybrids Uxh / Ufh / Uxw / Ufw 8, V 6), the H5 round's schema with two
added layout columns, `n0` and `W` (V: 3, 90; others 0, Inf). Per-case scores:
`score_U_all.rds`, `score_V_dry+dry-flat.rds`, `score_s.rds`, `ladder_U_*.rds`,
`ladder_V_*.rds`; the replay: `lad_U.rds`, `b_loop_pass{1,2}_{coord,jit}_U.rds`,
`d_flags_pass2_{coord,jit}_U.rds`, `INT.txt`.

## All predictions scored

| section | registered | holds | refuted |
|---|---|---|---|
| B (bank) | 16 | 13 | 3 (B1′, B3, B6) |
| S (short spells) | 6 | 5 | 1 (S4) |
| V (fix) | 7 | 2 (V1, V3) | 5 |
| L (loop) | 5 | 5 | 0 |
| D (flag) | 3 | 1 (D1) | 2 |
| **all** | **37** | **26** | **11** |
