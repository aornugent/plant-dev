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

### R1 results, all five regions (`r1_score.R dry`; F2 pending at the time of writing) [m]

| region (run, nodes) | rms | along M | ln J | root_P50 | omega | TF24_cost_scale | stem_c | a_l1 | root_c | a |
|---|---|---|---|---|---|---|---|---|---|---|
| B: b1 closing edge (B, 544) | 0.018 | +0.06 | +0.01 | +0.03 | +0.01 | −0.06 | −0.01 | −0.03 | −0.00 | +0.03 |
| O: opening side (O4, 705) | 0.049 | +0.07 | +0.04 | −0.18 | +0.10 | +0.13 | −0.02 | −0.07 | +0.09 | −0.02 |
| **I: interiors (I4, 662)** | 0.140 | +0.02 | −0.22 | **−0.51** | +0.31 | +0.22 | −0.11 | +0.42 | +0.22 | −0.15 |
| L: late (L4, 572) | 0.023 | +0.02 | −0.01 | +0.03 | −0.02 | −0.06 | +0.03 | +0.00 | −0.01 | +0.02 |
| sum B + O + I + L | 0.153 | +0.17 | −0.19 | −0.63 | +0.39 | +0.24 | −0.11 | +0.32 | +0.30 | −0.13 |
| e_res − sum | 0.134 | −0.19 | +0.11 | −0.01 | +0.03 | +0.16 | −0.28 | −0.12 | +0.01 | −0.19 |

- B and L are at the jitter floor (rms 0.018, 0.023 against 0.024).
- **R1a holds** (I −0.51 ∈ [−0.60, −0.25]); **R1b refuted** (O −0.18); **R1c holds**
  (L +0.03); **R1d holds** narrowly (B +0.03, positive, small); **R1f holds** (I along M
  +0.02 with root_P50 −0.51: the error is off M).
- What remains after B + O + I + L (root_P50 −0.01, stem_c −0.28, a −0.19, ln J +0.11) is
  the founders' signature; F2 will close the sum.

### R1 results, closed with F2 (`r1_score_dry.log`) [m]

| | rms | along M | ln J | root_P50 | omega | TF24_cost_scale | stem_c | a_l1 | sro | root_c | a |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F: founders on res (F2, 550, ×4/3) | 0.132 | −0.16 | +0.10 | −0.09 | +0.01 | +0.16 | −0.18 | −0.04 | +0.11 | +0.02 | −0.21 |
| sum F + B + O + I + L | 0.215 | +0.01 | −0.09 | −0.72 | +0.40 | +0.40 | −0.29 | +0.28 | +0.12 | +0.32 | −0.34 |
| e_res | 0.209 | −0.02 | −0.08 | −0.64 | +0.42 | +0.39 | −0.39 | +0.19 | +0.01 | +0.31 | −0.32 |
| e_res − sum | **0.039** | −0.03 | +0.01 | +0.08 | +0.02 | −0.00 | −0.10 | −0.08 | −0.11 | −0.01 | +0.02 |

- **The regions add**: e_res − sum has rms 0.039 (five runs' jitter ≈ 0.024·√5 ≈ 0.05)
  and root_P50 +0.08. **R1e holds** on both counts (root_P50 within ±0.15; rms ≤ 0.06).
- **Where res's root_P50 −0.64 lives** [m]: interiors −0.51 (80%), opening side −0.18
  (28%), founders −0.09, b1 edge +0.03, late +0.03. omega likewise (+0.31 of +0.42 in the
  interiors), root_c (+0.22 of +0.31), a_l1 (+0.42). The founders carry stem_c, a and
  TF24_cost_scale +0.16; the interiors and founders split TF24_cost_scale.

## R3. Mechanism in the interiors (dry)

**Process note.** Three analyses of saved runs were run before a prediction was written
for them (an error of process; their numbers are reported as found, with no score):
`m1_split.R` (the nested split of I4 − res into establishment, field and interpolation
parts, the founders' q2_shape split generalised to any nesting), `m2_who.R` (whose fates
carry the field part) and `m3_traj.R` / `m3b_shape.R` on a forward trajectory run of the I4
schedule (`traj.R`: interior cohorts' height, mortality integral, and the top soil layer).

### Exploratory results (unregistered) [m]

- **ln J's interior error is all field**: −0.223ε = establishment −0.000 + field −0.251 +
  interpolation +0.036 (`m1_split.R dry I4`). The opening side: +0.035 = field +0.043,
  interpolation −0.006.
- **The field part lowers every cohort's fate by about the same fraction**: median
  ln nrr (res − I4) −0.006 for founders, −0.007 for cohorts born b1–10, −0.002 (10–17),
  −0.010 (17–25). The founders hold 84% of J, so they carry −0.203 of the −0.251; the
  interior cohorts themselves −0.049 (`m2_who.R`).
- **The interior cohorts' leaf area is convex in birth date inside each res interval, and
  res's hats over-count it.** Proxy x = h^(1/a_l2)·exp(−mortality) per recruit
  (a_l2 = 0.306): at t = 8 / 15 / 22 y, across one interior interval, ln(size) falls
  −2.2 / −1.0 / −0.5 per year of later birth (a later birth is a smaller, delayed copy)
  while ln(survival) rises +0.5 / +0.2 / +0.2 per year with curvature +3.7 / +1.8 / +1.9
  per y² (a later birth has had less time to die, and met its first drought with fuller
  reserves). The hat chord over-reads x by a median 1.1% / 0.8% / 0.5% of the
  interval's own leaf area (`m3b_shape.R`); summed over all interiors and weighted by
  establishment, the over-count is 0.7–4% of the interior cohorts' leaf area every year
  from 4 to 40 y, falling from 3–4% (years 4–6) to 0.7–0.9% (years 15–40) (`m3_traj.R`).
- Reading [i]: res's interior hats over-count the understory's leaf area and so its
  water uptake; the soil runs drier for everyone; the founders, whose crowns sit above
  the understory and so cannot be shaded by it, lose fate through the soil alone. This
  is the founders' soil field part (founders/notes D) one level down: there the founders'
  own uptake was over-counted; here the interior cohorts' uptake is.

### Pre-registration R3 (before the pinned finite differences and the res trajectory run)

Runs: the I4 schedule forward at root_P50 × (1 ± 0.01), each step pinned to the stored I4
run (PIN), so the interpolation part's root_P50 derivative is free of step jitter
(`m4_fd.R`); and the res schedule's forward trajectory (`traj.R`) for its soil.
- **R3a.** The interpolation part carries under a third of the interiors' root_P50 error
  (|d interp / d ln root_P50| ≤ 0.17ε against −0.51): the elasticity error, like ln J's,
  is field — 65%.
- **R3b.** res's soil is drier than I4's: the top layer's mean over drydown days (top
  layer below its 20th percentile on I4) is lower on res, and the difference is ≥ 3× its
  difference over wet days — 60%.
- **R3c.** The guard: the pinned run at root_P50 × 1 is not run; instead the central
  difference of ln J from the ± pair reproduces I4's own root_P50 elasticity within 2% —
  80%.

### R2 results, dry ladder (I8 pending) (`r2_ladder.R dry`) [m]

| move | rms | along M | ln J | root_P50 | omega | TF24_cost_scale | a_l1 | root_c |
|---|---|---|---|---|---|---|---|---|
| res → I2 (interior intervals halved, ~35 d) | 0.109 | +0.01 | +0.17 | +0.39 | −0.23 | −0.19 | −0.32 | −0.17 |
| I2 → I4 (~18 d) | 0.023 | −0.02 | +0.04 | +0.08 | −0.06 | −0.01 | −0.07 | −0.04 |
| ratio (law 4) | 4.65 | — | 4.29 | **4.77** | 4.15 | — | 4.39 | — |

Projected ratio ⟨d1, d2⟩/|d2|² 4.46, cos(d1, d2) 0.96. The region error by Richardson from
res→I2 (×4/3) and from res→I4 (×16/15) agree to 0.01–0.03 in every quantity (root_P50
−0.52 / −0.51, ln J −0.23 / −0.22). The second move's rms (0.023) is at the jitter floor,
but its direction is the first's (cos 0.96), so the ratio is read on signal [i].

### R2 results, dry eras (`r2_era_dry.log`) [m]

| era (run, nodes) | rms | along M | ln J | root_P50 | omega | TF24_cost_scale | a_l1 | root_c |
|---|---|---|---|---|---|---|---|---|
| Ia (b1, 10) (Ia4, 578; 15 intervals) | 0.119 | −0.06 | −0.14 | **−0.38** | +0.22 | +0.23 | +0.28 | +0.16 |
| Ib [10, 17) (Ib4, 581; 16 intervals) | 0.051 | +0.05 | −0.07 | −0.12 | +0.08 | +0.03 | +0.12 | +0.06 |
| Ic [17, 25) (Ic4, 569; 12 intervals) | 0.013 | +0.00 | −0.01 | −0.02 | +0.01 | +0.00 | +0.04 | +0.01 |
| Ia + Ib + Ic | 0.146 | −0.01 | −0.22 | −0.52 | +0.31 | +0.26 | +0.43 | +0.22 |
| I4 − (Ia + Ib + Ic) | 0.010 | +0.03 | +0.00 | +0.02 | +0.00 | −0.05 | −0.01 | −0.00 |

- The eras add to the whole within rms 0.010. **R2a: additivity holds; "no era above
  60%" is refuted**: the first era after b1 carries 73% of the interiors' root_P50 with a
  third of their intervals; the last era (17–25), with intervals as wide, carries 4%.
- The interval widths are alike across eras (median 68–72 d), so what falls 20× from Ia to
  Ic is the weight of an understory error, not its size per interval [i]: cohorts born
  b1–10 are the understory, already large (t = 8 y leaf-area proxy), during the founders'
  reproductive years (t ≈ 15–28), when the founders' fate is set; cohorts born after 17
  are still seedlings then.
