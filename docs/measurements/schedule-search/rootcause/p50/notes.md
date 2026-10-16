# Where the residual root_P50 error lives (systematic debugging)

Subject: on TF24's committed schedule (E6 / val_insk_c: a09 with each edge node inset 12 d,
libS, 1e-4), once the closing-edge strips are resolved (the closing round's `res`), a
hydraulic error remains elsewhere in the layout: on dry root_P50 −0.64ε, omega +0.42,
TF24_cost_scale +0.39, stem_c −0.39; on dry-flat root_P50 −0.63. Where does it live, by
what mechanism, and is it second order in spacing.

Method: `.claude/skills/systematic-debugging/SKILL.md`. Every prediction is written here
before its run or analysis. Every run uses the E6 committed setting (`adj_run_nk.R` on
`adjmap/libS`, KNOTS=0, TOL 1e-4, one_nk.sh's environment, `run.sh` here), two at a time
at most. Errors are in each quantity's ε against the lib19-class reference
(`rootcause/common.R`); "along M" is the projection on P's unit direction M (a_l1 −0.44,
root_P50 −0.41, storage_relaxation_offset +0.35, omega +0.29, root_c +0.24,
TF24_cost_scale −0.23, stem_c −0.21, ...). Scripts are in this directory; outputs in
`scratchpad/deep/rootcause/p50/` (`runs/`, `sched/`, `logs/`, `*.log`). **[m]** measured,
**[i]** inferred.

## Summary

(written last)

## R0. What the saved runs already say (no new run)

Inputs: the founders' bisection on the committed layout (`founders/runs/fbis_*`, libS,
founders' error F = −4/3 × (fbis − c)), the closing round's res (region C = −(res − c)),
e_c and e_res. If regions add, the error outside founders and closing strips is
rest = e_c − F − C = e_res − F.

Already seen before registering (from `founders/q1_committed.log`, top four of F only):
dry F's largest are stem_c −0.26, curv_fact_elec_trans, k_I, a −0.21 (so |F root_P50| <
0.21 on dry); dry-flat's largest a −0.36 (so |F root_P50| < 0.32); dry-p50's stem_c −0.24.

### Pre-registration R0

- **R0a.** F's root_P50 on dry lies in [−0.21, 0]: the founders carry at most a third of
  e_res's −0.64 — 55%. Same on dry-flat (F root_P50 in [−0.21, 0]) — 45%.
- **R0b.** F carries most of e_res's stem_c and TF24_cost_scale on dry: F stem_c −0.26 is
  seen; F TF24_cost_scale ≥ +0.15 (cost traits sit on the + side of dry's carbon-balance
  axis) — 55%.
- **R0c.** rest = e_res − F keeps root_P50 ≤ −0.40 on both dry and dry-flat, with omega of
  the opposite sign (≥ +0.2 on dry) — 55%.
- **R0d.** long-wet's rest root_P50 is small (|·| ≤ 0.15) — 60%.

### R0 results (`r0_saved.R`, `r0_saved.log`) [m]

| case | | along M | ln J | root_P50 | omega | TF24_cost_scale | stem_c | a_l1 | sro | root_c | a |
|---|---|---|---|---|---|---|---|---|---|---|---|
| dry | e_c | −0.30 | −0.15 | −0.31 | +0.16 | +0.28 | −0.23 | +0.25 | −0.01 | +0.14 | −0.35 |
| dry | founders F (on c) | −0.15 | +0.10 | −0.04 | +0.01 | +0.09 | −0.26 | −0.04 | +0.12 | +0.01 | −0.21 |
| dry | closing C | −0.28 | −0.07 | +0.34 | −0.27 | −0.12 | +0.17 | +0.06 | −0.02 | −0.17 | −0.03 |
| dry | e_res | −0.02 | −0.08 | −0.64 | +0.42 | +0.39 | −0.39 | +0.19 | +0.01 | +0.31 | −0.32 |
| dry | **rest = e_res − F** | +0.13 | **−0.18** | **−0.60** | **+0.41** | +0.31 | −0.13 | +0.24 | −0.11 | +0.30 | −0.11 |
| dry-flat | rest | +0.12 | −0.10 | **−0.59** | +0.23 | +0.23 | −0.03 | +0.29 | +0.03 | +0.24 | −0.17 |
| dry-p50 | rest | −0.08 | −0.24 | **−0.37** | +0.41 | +0.19 | +0.06 | +0.37 | −0.08 | +0.10 | −0.12 |
| long-wet | rest | +0.04 | −0.03 | −0.11 | +0.08 | +0.00 | −0.03 | +0.12 | +0.00 | +0.06 | −0.01 |

(rest rms: dry 0.156, dry-flat 0.132, dry-p50 0.140, long-wet 0.033.) The check run at
1.6× finer spacing with the 7.5-d inset (val_ins75_f) has root_P50 −0.02 (dry), −0.14
(dry-flat): the error falls with spacing.

- **R0a holds** on both: the founders carry root_P50 −0.04 (dry and dry-flat). The
  founders' part of e_res is stem_c (−0.26 of −0.39) and the leaf group; not root_P50 or
  omega.
- **R0b refuted** for TF24_cost_scale (+0.09 < 0.15); stem_c holds.
- **R0c holds**: rest root_P50 −0.60 (dry), −0.59 (dry-flat), omega +0.41 (dry). R0d holds
  (long-wet −0.11).
- So the error lives outside the founders and outside the resolved closing strips, and is
  off M: root_P50 −, omega +, root_c +, TF24_cost_scale +, a_l1 +, ln J −0.18. In a09's
  class location (error-structure §2) the "interior and late" class carried ln J −0.20 and
  ~0 along M [i: the same signature].

## R1. Region bisection on top of res (dry)

Regions on res's own nodes (`mk_reg.R`; boundaries at existing nodes so they are disjoint):
- **Os + O1 (O)**: each opening edge o in (b1, 25) whose spell res did not resolve whole:
  the gap interval that holds the strip [o, o + 12 d] (re-noded at o and the strip cut in
  k) and the spell's first interval [o + 12 d, x2] (median 62 d) cut in k. 25 strips.
- **I**: spell interiors, from x2 to the closing region (c − 36 d), each interval cut in k
  (dry: 43 intervals, median ~70 d); by era Ia (b1, 10), Ib [10, 17), Ic [17, 25).
- **L**: from the last opening edge's inset node (23.92) on: 13 intervals, median 401 d.
- **B**: the b1 closing edge, which res did not resolve (`closing_regions` starts after
  b1), resolved with res's offsets.
- **F2**: the founders' intervals bisected on res (founders on the same base, for
  additivity).

Runs: I4 (+129 nodes), O4 (+172), L4 (+39), B (+11), F2 (+17). Region error read as
−16/15 × (X4 − res) for k = 4 (second order assumed; a k = 2 rung of the carrying region
tests that), −(B − res), −4/3 × (F2 − res).

### Pre-registration R1 (before any R1 run)

- **R1a.** The spell interiors I carry most of rest's root_P50: I's root_P50 in
  [−0.60, −0.25] — 45%.
- **R1b.** The opening strips O carry it instead: O's root_P50 in [−0.60, −0.25] — 25%.
- **R1c.** Late L is small: |root_P50| ≤ 0.10 — 75%.
- **R1d.** The b1 strip B errs like the other closing strips: root_P50 > 0, ≤ 0.2 — 50%.
- **R1e.** Additivity: O + I + L + B + F2 gives e_res's root_P50 (−0.64) within ±0.15 —
  55%; the vector sum within rms 0.06 of e_res — 40% (the reference's own error and six
  runs' jitter, 0.024 each, enter).
- **R1f.** The carrying region's error is mostly off M (|along M| ≤ 0.2 while root_P50
  ≥ 0.3 in size) — 60%.

### R1 results, first two runs (`r1_score.R dry`) [m]

| region (run, nodes) | along M | ln J | root_P50 | omega | TF24_cost_scale | stem_c | a_l1 | root_c | a | rms |
|---|---|---|---|---|---|---|---|---|---|---|
| e_res (533) | −0.02 | −0.08 | −0.64 | +0.42 | +0.39 | −0.39 | +0.19 | +0.31 | −0.32 | 0.209 |
| **I interiors (I4, 662)** | +0.02 | **−0.22** | **−0.51** | **+0.31** | +0.22 | −0.11 | **+0.42** | +0.22 | −0.15 | 0.140 |
| O opening strips + first interval (O4, 705) | +0.07 | +0.04 | −0.18 | +0.10 | +0.13 | −0.02 | −0.07 | +0.09 | −0.02 | 0.049 |
| sum O + I | +0.09 | −0.19 | −0.69 | +0.41 | +0.35 | −0.13 | +0.35 | +0.31 | −0.17 | 0.171 |
| e_res − (O + I) | −0.11 | +0.11 | +0.05 | +0.01 | +0.05 | −0.26 | −0.16 | −0.01 | −0.15 | 0.103 |

The spell interiors carry 80% of the root_P50 error and all of ln J's; the opening side
a quarter. What is left after O + I (stem_c −0.26, a −0.15, ln J +0.11) is the founders'
signature (F on c: stem_c −0.26, a −0.21, ln J +0.10). L4, B and F2 are running.

## R2. The interiors: era, order, records

Runs: dry Ia4 / Ib4 / Ic4 (eras (b1, 10), [10, 17), [17, 25)); dry I2 and I8 (with res and
I4 a nested four-rung ladder in the interiors alone, intervals ~70 / 35 / 18 / 9 d);
dry-flat I4, O4, I2; long-wet I4, O4.

### Pre-registration R2 (before any R2 run)

- **R2a (era).** The three eras add to I4 within rms 0.05, and no single era carries more
  than 60% of I's root_P50 (the error is spread over the record, not one spell) — 50%.
- **R2b (order).** On dry, the interiors are clean second order: (res − I2)/(I2 − I4) and
  (I2 − I4)/(I4 − I8) along root_P50 both within [3, 5.5], and the same per quantity
  (projected ratio, cos(move1, move2) ≥ 0.9) — 55%. Reason [i]: interiors hold no edge;
  their intervals (~70 d) are past the closing-edge curvature scale (20–45 d) but the
  interior integrand is wet-season, smoother.
- **R2c (dry-flat).** dry-flat's root_P50 is split differently: interiors carry less than
  half of its −0.59 (its interiors are fewer and shorter: 26 intervals, median 39–51 d,
  against dry's 43 at ~70 d), the opening side more (O ≤ −0.25) — 45%.
- **R2d (long-wet).** long-wet's interiors carry |root_P50| ≤ 0.15 — 65%.
