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

## Summary (written last)

**Where (dry).** Region bisection on top of res, five disjoint regions whose errors add to
e_res within rms 0.039 (root_P50 −0.72 against −0.64) [m]:

| region (dry) | root_P50 | omega | TF24_cost_scale | a_l1 | ln J |
|---|---|---|---|---|---|
| **spell interiors after b1** (from the spell's first interval to c − 36 d) | **−0.51** | +0.31 | +0.22 | +0.42 | −0.22 |
| of which b1–10 / 10–17 / 17–25 | −0.38 / −0.12 / −0.02 | | | | |
| opening strips [o, o + 12 d] (read on the gap chord) | −0.14 | +0.09 | +0.01 | −0.11 | +0.06 |
| spell's first interval after the opening inset | −0.05 | +0.01 | +0.05 | +0.00 | −0.02 |
| founders [0, b1) | −0.09 | +0.01 | +0.16 | −0.04 | +0.10 |
| b1 closing edge; late (b > 23.9) | +0.03; +0.03 | | | | |

dry-flat (−0.63): interiors −0.27, opening side −0.11, founders −0.05, late −0.04, b1 edge
0.00, unplaced −0.16 (every other quantity closes, rms 0.035). long-wet: interiors −0.06,
opening side −0.06 (jitter-sized). The founders' window does not hold the root_P50 error
(−0.04 to −0.09); it holds stem_c, a and a_l1.

**Mechanism [m, with the channel i].**
1. It is a field error, not an interpolation of fate: the interiors' ln J error is field
   −0.251, interpolation +0.036; their root_P50 error is 89% field (pinned finite
   differences: interpolation part −0.056 of −0.505).
2. The integrand is the interior cohorts' leaf area (and with it their resource use) as a
   function of birth date. Inside a wet spell a later birth is a smaller delayed copy
   (ln size −2.2 / −1.0 / −0.5 per year of birth at t = 8 / 15 / 22 y) but has had less time
   to die and met its first drought with fuller reserves (ln survival +0.5 to +0.2 per
   year, curvature +2 to +4 per y²). The product is convex, so the 60–100 d interior hats
   over-read the understory's leaf area by 0.5–1.1% of it (3–4% in years 4–6).
3. The over-counted understory lowers every cohort's fate by about the same fraction
   (dry: founders −0.0061 in ln nrr, born b1–10 −0.0071). The founders hold 84% of J, so
   they carry 80% of the field part. They lose it as extra mortality (+0.0067, 86% of it
   accrued in drydowns), entering drydowns with 0.07–0.28% less storage and growing
   6e-4 m less at 10–15 y; their seed output does not fall.
4. The soil layers agree between the coarse and fine runs to 1e-5 and cumulative uptake
   differs by 0.01%, so the founders' carbon shortfall is more likely light at their lower
   crowns than water [i]. libS has no node drop, so the channel is not separated.
5. Why hydraulic traits and why dry: ln J's part is small (−0.22ε); its trait derivative
   is large where the founders' survival of drydowns sets J, because the field moves
   exactly that (reserve-driven mortality, a_dG2 = 20). The traits that set drydown
   survival (root_P50, root_c, TF24_cost_scale, seed mass omega) and the one that sets the
   understory's leaf area per height (a_l1) take the error. On dry every cohort's fate
   moves −1.4 per unit ln root_P50; the founders' fate shift falls from dry (−0.0061) to
   dry-flat (−0.0020) to long-wet (−0.0012), and the interiors' root_P50 error with it
   (−0.51, −0.27, −0.06). dry-flat's interiors are also shorter (39–51 d against ~70 d).
   Within dry, 73% sits in the cohorts born b1–10: they are the understory during the
   founders' reproductive years.

**Order [m].** The interiors are clean second order on dry: halving them twice (≈70 → 35
→ 18 d) moves root_P50 +0.39 then +0.08 (ratio 4.77; omega 4.15, a_l1 4.39, ln J 4.29,
rms 4.65; projected 4.46; cos(move1, move2) 0.96), and Richardson from either pair gives
the same region error to 0.01–0.03. dry-flat the same (ratio 4.35 root_P50, rms 3.89,
projected 3.70, cos 0.95; Richardson from either pair −0.27). Both second moves are at
or under the jitter floor in rms (0.023, 0.013) but keep the first move's direction.

**What it implies [i].** The interiors are the founders' case one level down: an h²
hat error in birth date of a smooth, edge-free profile, carried by the field into the
founders' survival. So:
- a check that refines the spell interiors by the same ratio reads them on the square law,
  and a coarser/finer pair predicts them;
- Simpson weights over pairs of equal interior intervals, on every sum over nodes (J,
  light, uptake), i.e. `founders/simpson.patch` extended from [0, b1) to each spell's
  interior between its inset nodes, removes the leading term; the ladder's h⁴ content is
  under the jitter floor (the second halving moved root_P50 +0.08 against the square
  law's +0.10). Simpson in the founders' window alone removes only the founders' −0.09.
- The committed run's small root_P50 error (−0.31) is a balance: closing strips +0.34 (no
  power law), interiors −0.51 (h²), opening strips −0.14 (fixed 12-d strip, order not
  measured), founders −0.09 (h²). Fixing the interiors and founders alone would leave about
  +0.2 to +0.3 from the closing strips [i]. The three must change together (interiors and
  founders by Simpson or h², closing strips by H5's fixed node at c − 12 d).

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

### R3 results, part 1: the pinned finite differences (`m4_fd.R dry`) [m]

- **Guard (R3c) holds**: the pinned pair's d ln J / d ln root_P50 −1.32493 against I4's
  adjoint −1.32505 (ratio 0.9999).
- **R3a holds: the interiors' root_P50 error is field.** The interpolation part (res's
  hats on I4's fates, I4's field) contributes −0.056ε of the region's −0.505ε (11%); the
  field part (with establishment, which is 0 in ln J) −0.449ε (89%). ln J: interpolation
  +0.036, field −0.251 (`m1_split.R`).
- Per-cohort d ln nrr / d ln root_P50 (median): founders −1.37, born b1–10 −0.82, 10–17
  −1.59, 17–25 −1.10, after 25 −0.33: every cohort's fate is strongly root_P50-dependent
  on dry.

### R3 results, part 2: the soil and the cohorts' final state (`m5_soil.R`, `m6_state.R`) [m]

- **R3b refuted.** res's top five soil layers are not drier than I4's on drydown days:
  on the driest 2% of I4's days res − I4 is +3e-4 in layers 1–3 (+0.2% of the layer's
  water, res slightly wetter); over all days the top layer differs by +3e-5. By era the
  mean differences are ±1e-3 with no consistent sign. (Wet-day differences of −3e-3 to
  −1.6e-2 sit on rain pulses, where two runs' different step times make the interpolated
  layer jump; not read.)
- **The founders' fate falls through their own mortality, not their output** (res − I4 at
  res's nodes, medians): founders d ln nrr −0.0061, mortality integral +0.0067, ln
  lifetime seed output +0.0008, height +0.0002 m; cohorts born b1–10 likewise (−0.0071,
  +0.0067, +0.0011). So res's founders grow and reproduce marginally *more* and die
  marginally *more*. Light cannot give that (less light would cut growth and output) [i];
  a drier soil would show in the layers, and does not in the top five.
- So the channel is still open. The reading in R3's exploratory part ("the over-counted
  understory dries the soil") is not supported by the top five layers.

### Pre-registration R3d (before the founders' trajectory runs, `jobs3.txt`)

Runs: res and I4 forward with the founders' (b < b1) height, mortality integral and
storage at every recorded step, and all ten environment states (soil layers).
- **R3d.** The founders' extra mortality in res (+0.0067) accrues in the drydown pulses:
  ≥ 60% of it accrues on days when the founders' mortality rate is above its 90th
  percentile — 55%.
- **R3e.** In those pulses res's founders hold less storage than I4's (median relative
  storage difference < 0) — 55%; and the deeper soil layers (6–10) are drier on res on
  those days — 35%.

### R2 results, dry-flat (`r2_dryflat.log`) [m]

| region (run, nodes) | rms | along M | ln J | root_P50 | omega | TF24_cost_scale | stem_c | a_l1 | root_c | a |
|---|---|---|---|---|---|---|---|---|---|---|
| e_res (880) | 0.196 | +0.10 | +0.09 | −0.63 | +0.21 | +0.24 | −0.19 | −0.04 | +0.25 | −0.53 |
| I interiors (I4, 958) | 0.069 | +0.09 | −0.09 | **−0.27** | +0.11 | +0.06 | −0.01 | +0.12 | +0.11 | −0.11 |
| O opening side (O4, 1183) | 0.026 | +0.04 | −0.00 | −0.11 | +0.07 | +0.03 | −0.03 | +0.04 | +0.06 | −0.01 |
| e_res − (O + I) | 0.147 | −0.03 | +0.18 | −0.25 | +0.02 | +0.15 | −0.15 | −0.20 | +0.08 | −0.42 |

- ln J's interior error is again all field (−0.089 = field −0.089, interpolation +0.002),
  and the founders (97% of dry-flat's J) carry all of it.
- The interiors carry 43% of dry-flat's root_P50 (−0.27 of −0.63), the opening side 17%.
  **R2c: holds in its first part** (interiors under half); its second (O ≤ −0.25) is
  refuted (−0.11).
- −0.25 is left, with the founders' signature in the other quantities (a −0.42, a_l1
  −0.20, ln J +0.18; the founders on c: a −0.36, a_l1 −0.33, ln J +0.19, root_P50 −0.04).
  So −0.2 of root_P50 is not yet placed on dry-flat; F2, B and L4 on dry-flat are queued.
- Process note: the dry I8 rung was dropped (I2 → I4 already sits at the jitter floor, so
  I4 → I8, ~4× smaller, could not be read); killing it stopped that queue, so the
  remaining jobs moved to `jobs3.txt`.

### Pre-registration R2e (before dry-flat's F2, B and L4)

- **R2e.** dry-flat's founders on res (F2) carry root_P50 in [−0.10, 0] — 60%.
- **R2f.** dry-flat's b1 edge (B) carries |root_P50| ≥ 0.10 — 30%.
- **R2g.** dry-flat's late region (L4: one interval 24.8–36.0 y quadrisected) carries
  |root_P50| ≥ 0.10 — 30%.
- **R2h.** F2 + B + O + I + L gives dry-flat's e_res root_P50 (−0.63) within ±0.15 — 50%.
  If it does not, the gap is within the reference's own extrapolation step on dry-flat
  (|u429 − u215|/3 in root_P50 ≥ the gap) — 40%.

### R2 results, long-wet (`r2_longwet.log`) [m]

Interiors (I4, 719 nodes): rms 0.022 (the jitter floor), root_P50 −0.06, ln J −0.04
(field −0.050, interpolation +0.016); the founders carry −0.040 of the field part, with a
fate shift of −0.0012 in ln nrr (dry −0.0061, dry-flat −0.0020). **R2d holds.**

### R3 results, part 3: the founders' trajectories (`m7_founders.R`, `m8_drydown.R`) [m]

- res's founders end with +0.0068 more mortality (J-weighted), as at res's nodes. It
  accrues across 5–30 y (+0.0010, +0.0028, +0.0017, +0.0011, +0.0015 per 5-y era), not in
  one era. Their height is lower than I4's by 1–8e-4 m over 5–30 y (they grow marginally
  less) and ends +2e-4 m higher among survivors.
- **R3d and R3e cannot be read on this run**: the trajectory was thinned to 1200 rows
  (≈ 12 d apart), so daily increments of the mortality difference are dominated by the
  two runs' different pulse timing (the "share on pulse days" comes out −52), and drydown
  timing (lag res − I4 at the top layer crossing 0.17 / 0.15 / 0.14: −0.20 / +0.06 /
  +0.20 d, mixed sign) is below the record's resolution. On the founders' pulse days the
  top layer reads 1.6e-3 lower on res (1.1% of 0.139) and 1.9e-4 higher in the 10 days
  before; at this resolution that is not evidence either way.
- Reading so far [i]: the field part moves every cohort's fate by a similar fraction
  (founders −0.0061, born b1–10 −0.0071, 17–25 −0.0099). Light from an over-counted
  understory would fall on the understory and much less on the founders' crowns above it;
  a shared soil pool reaches everyone alike. The founders lose fate through extra
  mortality, which in TF24 is reserve-driven (a_dG1·exp(−a_dG2·r)) and comes in drydown
  pulses. So the soil channel is the likely one; not yet measured on libS (libS has no
  node drop, and the lib build that has it is not libS).

### Pre-registration R3f (before the full-resolution founders' trajectories, `jobs4.txt`)

Runs: as R3d with every recorded step kept (NKEEP all).
- **R3f.** During drydowns (I4's top layer falling and below 0.17), res's top layer is
  lower than I4's on average, and the founders' extra mortality accrues mostly (≥ 60%) in
  those drydown periods — 50%.

### Pre-registration R1g (before the opening side is split, `jobs4.txt`)

The opening side O (dry: root_P50 −0.18) lumps the strip [o, o + 12 d] (read on the gap's
chord) and the spell's first interval [o + 12 d, x2] (median 62 d, an interior interval in
all but name). Runs Os4 (strip only) and Ofirst4 (first interval only).
- **R1g.** The first interval carries at least two thirds of O's root_P50, and its error is
  field in ln J like the interiors' — 60%.

### R3 results, part 4: full-resolution founders' trajectories (`m7_founders.R dry trajG`, `m8_drydown.R`, `m9_when.R`) [m]

Every recorded step kept (res 5643 rows, I4 5921), founders' state and all ten
environment states (five soil layers, then cumulative rainfall, infiltration, drainage,
root uptake, runoff).
- **The soil is the same on both runs.** At the 1078 step times the two runs share, the
  top layer differs by median 0, mean −1.4e-5 (water content ~0.14–0.26); on the founders'
  mortality-pulse days all five layers differ by under 1e-5; drydowns cross 0.17 / 0.15 /
  0.14 at the same time to within 0.01–0.04 d in 10–30 y (`m8_drydownG_dry.log`). res's
  cumulative root uptake is higher by 1.8e-4 / 2.2e-4 / 3.5e-4 m at 15 / 20 / 25 y (0.01%
  of the total) and its drainage lower: the over-counted understory takes a little more
  water, and the soil gives it from drainage, not from storage in the layers.
- Cumulative *rainfall* differs between the two runs at the same time (−0.012 m at 10 y,
  −0.07 at 25 y, +0.27 at 30 y): with the rain's knots not stops (KNOTS=0), each step
  integrates the rain over its own placement, so the input itself carries step jitter.
  This is part of the jitter floor; it does not scale with the interior spacing.
- **The founders' extra mortality accrues in drydowns**: of +0.0066 (4–25 y), +0.0057
  (86%) on drying days (I4's top layer below 0.17 and falling; 35% of the time), +0.0015
  on wet days (top layer ≥ 0.20). The founders hold 0.07% less storage than I4's over
  10–15 y (0.28% less on pulse days) and are 6e-4 m shorter at 10–15 y; height and
  storage increments split by soil class are dominated by step-placement noise (±4e-3
  between classes) and are not read.
- **R3f: half holds.** The extra mortality accrues in drydowns (86% ≥ 60%); the top layer
  is not lower on res in drydowns (+3e-5).
- Reading [i]: the field part reaches the founders as a small carbon shortfall (lower
  reserves, slightly slower growth during the race) that turns into mortality when
  drydowns drain reserves (TF24's mortality is a_dG1·exp(−a_dG2·r), a_dG2 = 20). Since the
  soil layers agree to 1e-5, the shortfall is more likely light at the founders' lower
  crowns from the over-counted understory than water. Not separated on libS: libS has no
  node drop (the lib build that has it is not libS; not used, per the round's rule).

### R2e results: dry-flat closed, long-wet's opening side (`r1_score_dryflat.log`, `r2_longwet.log`) [m]

| dry-flat region | rms | ln J | root_P50 | omega | TF24_cost_scale | a_l1 | a |
|---|---|---|---|---|---|---|---|
| F founders on res (F2, ×4/3) | 0.142 | +0.19 | −0.05 | −0.02 | +0.05 | −0.30 | −0.37 |
| B b1 edge | 0.005 | +0.00 | −0.00 | +0.00 | −0.01 | +0.00 | +0.01 |
| O opening side | 0.026 | −0.00 | −0.11 | +0.07 | +0.03 | +0.04 | −0.01 |
| I interiors | 0.069 | −0.09 | −0.27 | +0.11 | +0.06 | +0.12 | −0.11 |
| L late (24.8–36.6) | 0.018 | −0.02 | −0.04 | −0.00 | +0.03 | +0.03 | −0.02 |
| sum | 0.176 | +0.09 | −0.47 | +0.17 | +0.16 | −0.11 | −0.50 |
| e_res − sum | **0.035** | +0.00 | **−0.16** | +0.04 | +0.08 | +0.07 | −0.03 |

- R2e holds (F2 −0.05); R2f refuted (B −0.00); R2g refuted (L −0.04).
- **R2h refuted narrowly** on both counts: the sum misses root_P50 by −0.16 (registered
  ±0.15), and the reference's own extrapolation step on dry-flat is 0.10 in root_P50
  (|u429 − u215|/3), under the gap. Every other quantity closes (rms 0.035). Five region
  reads, each with one run's jitter (×16/15 or ×4/3), sum to an expected spread of about
  0.1 in one quantity [i]; res's own residual in dry-flat's 92 resolved closing regions
  (checked by res2x on dry only) is the other candidate. −0.16 is left unplaced.
- **dry-flat's root_P50 −0.63 is, in order**: interiors −0.27, opening side −0.11,
  founders −0.05, late −0.04, b1 edge 0.00, unplaced −0.16.
- long-wet: opening side −0.06, interiors −0.06 (each rms 0.02, the jitter floor).

### R1g results: the opening side split (`r1g_dry.log`) [m]

| dry | rms | along M | ln J (field / interp) | root_P50 | omega | TF24_cost_scale | a_l1 |
|---|---|---|---|---|---|---|---|
| Os: strip [o, o + 12 d] on the gap chord (Os4, 633) | 0.036 | +0.17 | +0.06 (+0.072 / −0.012) | **−0.14** | +0.09 | +0.01 | −0.11 |
| Ofirst: first interval [o + 12 d, x2] (Ofirst4, 605) | 0.019 | −0.01 | −0.02 (−0.027 / +0.006) | −0.05 | +0.01 | +0.05 | +0.00 |
| Os + Ofirst | | +0.16 | +0.04 | −0.19 | +0.10 | +0.06 | −0.11 |
| O (O4, both at once) | 0.049 | +0.07 | +0.04 | −0.18 | +0.10 | +0.13 | −0.07 |

- The two parts add to O (root_P50 −0.19 against −0.18). **R1g refuted**: the opening
  strip, not the first interval, carries the opening side's root_P50 (−0.14 of −0.18).
  Its ln J error is field too (+0.072), of the opposite sign to the interiors'.

### R2 results, dry-flat ladder (`r2_ladder_dryflat.log`; not separately registered) [m]

res → I2 moves root_P50 +0.21, I2 → I4 +0.05: ratio 4.35 (ln J 3.27, a_l1 2.87, omega 6.75 on
small numbers), rms 3.89, projected 3.70, cos 0.95. Richardson from res→I2 and res→I4 gives
the same region error (root_P50 −0.27 both). The second move's rms (0.013) is under the
jitter floor; the ratio is read from its direction (cos 0.95) [i].

## Predictions scored

| # | prediction | P | result |
|---|---|---|---|
| R0a | founders' root_P50 in [−0.21, 0] on dry | 55% | holds (−0.04) |
| R0a′ | same on dry-flat | 45% | holds (−0.04) |
| R0b | founders' TF24_cost_scale ≥ +0.15 on dry | 55% | refuted (+0.09; stem_c −0.26 holds) |
| R0c | rest root_P50 ≤ −0.40 on dry and dry-flat, omega ≥ +0.2 on dry | 55% | holds (−0.60, −0.59; +0.41) |
| R0d | long-wet rest \|root_P50\| ≤ 0.15 | 60% | holds (−0.11) |
| R1a | interiors' root_P50 in [−0.60, −0.25] | 45% | holds (−0.51) |
| R1b | opening side's root_P50 in [−0.60, −0.25] | 25% | refuted (−0.18) |
| R1c | late \|root_P50\| ≤ 0.10 | 75% | holds (+0.03) |
| R1d | b1 edge root_P50 > 0, ≤ 0.2 | 50% | holds (+0.03) |
| R1e | regions add to e_res's root_P50 within ±0.15 | 55% | holds (−0.72 against −0.64) |
| R1e′ | vector sum within rms 0.06 | 40% | holds (0.039) |
| R1f | carrying region off M (\|M\| ≤ 0.2) | 60% | holds (+0.02) |
| R1g | first interval carries ≥ 2/3 of the opening side | 60% | refuted (the strip carries −0.14 of −0.18) |
| R2a | eras add (rms ≤ 0.05) and no era > 60% | 50% | refuted (add within 0.010; b1–10 holds 73%) |
| R2b | interiors second order on dry, ratios in [3, 5.5], cos ≥ 0.9 | 55% | holds on the measurable pair (4.77 root_P50, 4.65 rms, cos 0.96); the I4 → I8 step was dropped (below the jitter floor) |
| R2c | dry-flat interiors < half and opening ≤ −0.25 | 45% | refuted (first part holds, −0.27; opening −0.11) |
| R2d | long-wet interiors \|root_P50\| ≤ 0.15 | 65% | holds (−0.06) |
| R2e | dry-flat founders' root_P50 in [−0.10, 0] | 60% | holds (−0.05) |
| R2f | dry-flat b1 edge \|root_P50\| ≥ 0.10 | 30% | refuted (−0.00) |
| R2g | dry-flat late \|root_P50\| ≥ 0.10 | 30% | refuted (−0.04) |
| R2h | dry-flat regions add within ±0.15 | 50% | refuted narrowly (gap −0.16) |
| R2h′ | gap within the reference's extrapolation step | 40% | refuted (step 0.10) |
| R3a | interpolation part < 1/3 of the interiors' root_P50 | 65% | holds (11%) |
| R3b | res's top soil drier in drydowns | 60% | refuted (no difference above 1e-5) |
| R3c | pinned pair reproduces the adjoint within 2% | 80% | holds (0.9999) |
| R3d, R3e | founders' extra mortality on pulse days; storage and deep soil there | 55%, 55%/35% | not readable on the thinned run; replaced by R3f |
| R3f | res's top layer lower in drydowns, and ≥ 60% of the extra mortality there | 50% | half: mortality 86% in drydowns; soil not lower |

Exploratory analyses run before registration (process error, not scored): `m1_split.R`,
`m2_who.R`, `m3_traj.R`, `m3b_shape.R`, `m6_state.R`.

Runs: 27 completed, all exit 0 (I8 on dry started and was dropped), at most two of this round's at a time except two
windows (four at once for about a minute at 20:40, and for about ten minutes after a queue
exited early at 23:39; both caught and cut back to two). Region refinements: dry I4, O4,
L4, B, F2, I2, Ia4, Ib4, Ic4, Os4, Ofirst4; dry-flat I4, O4, L4, B, F2, I2; long-wet I4,
O4. Pinned finite differences 2; forward trajectories 6 (traj, trajF, trajG on res and I4).
