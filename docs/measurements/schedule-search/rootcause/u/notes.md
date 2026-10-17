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

(pending)

## Setup

- `../h5/lib.R` gained two arguments with defaults that change nothing (`n0 = 0`,
  `W = Inf`: a stretch at least W days wide gets at least ceiling(n0 / s) intervals) and
  records each placed stretch and its interval count (`attr(, "seg")`). Guard
  (`mk_sched.R`): U's six schedules on dry and dry-flat are reproduced exactly [m].
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
