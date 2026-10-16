# Summing over nodes in birth date by pairs of intervals (Simpson-type), TF24 and FF16

Subject: replace plant's per-interval hat weights (trapezium in birth date) by weights from
piecewise-quadratic interpolation over consecutive pairs of intervals, and measure what it
does to TF24's schedule error (all regions, not only the founders) and to FF16. Process:
`.claude/skills/systematic-debugging/SKILL.md`; every prediction is written here before the
run or analysis it concerns. Scripts and the patch are in this directory; outputs in
`scratchpad/deep/rootcause/summing/` (`runs/`, `sched/`, `logs/`, `*.log`, small `*.rds`).
Every number is marked **[m]** (measured) or **[i]** (inferred: a derivation, fit or reading).

## Summary

(written last)

## Step 0. A build that reproduces libS

### What libS was built from (read before predicting)

- `adjmap/libS/plant` was installed at 05:05:56 UTC on 14 October (its DESCRIPTION's
  `Built`). Its installed headers (`libS/plant/include`) equal
  `dev/schedtest/S_src/plant_stack/inst/include` file for file (`diff -r`: no difference)
  [m]. `S_src/plant_stack` is at `PLANT-110` `07f7c256` with one local change, DESCRIPTION's
  `LinkingTo: phylloptim (== 0.9.3)` (libS's DESCRIPTION says the same) [m].
- `docs/measurements/kinks/jump-census/results2.md` records that the libS build was of
  `208c0a88`, which differs from `07f7c256` only in `NEWS.md` and a test file, and that a
  build of `07f7c256` (with odelia and phylloptim copied from libS) replayed saved libS runs
  with relative difference 0 [m, from that record].
- The founders' round built `S_src/plant` (`213b7a3b`, a different branch). Its
  `species.h` lacks the commits that spread each birth-date interval's leaf area over eight
  crowns (`for_each_interval_crown`); there the light was built from the node weights
  [m, diff]. That is why libF did not reproduce libS (S0 there). It also means: in libS the
  light does **not** go through `for_each_establishment_weight`; only J, uptake
  (`consumption_rate`), the census and the diagnostics do.

Plan: `git archive 07f7c256` of `S_src/plant_stack` plus its DESCRIPTION change, into
`summing/build/src0/plant`; installed (`-O2`, R's default flags, as libS) into a new
`summing/build/lib0` with odelia and phylloptim copied from libS. Guard runs: the E6 committed
setting (libS, no knot stops, 1e-4) on `val_insk_c`'s schedules for dry and episodic-lma,
forward J and the 50 elasticities against the saved `adjmap/runs/val_insk_c_*`.

### Pre-registration 0

| # | prediction | probability |
|---|---|---|
| R0 | lib0 reproduces the saved libS J and all elasticities `identical()` (relative difference 0) on both guard cases | 90% |

### Result 0 (`guard.R`, `run.sh jobs_g0.txt`)

lib0 (`summing/build/lib0`, built 20:47–20:53 UTC from `git archive 07f7c256` + the
DESCRIPTION change, R's default `-O2`, odelia/phylloptim copied from libS) on the
`insc` schedules [m]:
- dry: J 1.19606594214158, `identical()` to `val_insk_c_dry`; 4543 steps, step times,
  node weights and all 50 elasticities `identical()`.
- episodic-lma: J 0.0312817366740029, the same, 3332 steps.

**R0 confirmed.** lib0 is libS. The patched build `lib1` is built from the same tree with
only `species.h` changed (`pairs.patch`).

## Step 1. The rule, generalised

### Derivation

Per pair of intervals [b0, b1], [b1, b2] (widths h1, h2, H = h1 + h2) holding establishment
E (the exact interval integrals, as plant tracks them), the hat weights (each interval's
exact establishment split by its first moment) are kept and corrected by E/H times the
difference between composite Simpson's weights for unequal widths and the hat weights, both
for a uniform density:
- Simpson on [b0, b2] through three points: ∫f ≈ (H/6)[(2 − h2/h1) f0 + H²/(h1 h2) f1 +
  (2 − h1/h2) f2] (exact on quadratics);
- hats for a uniform density: h1/2, H/2, h2/2;
- correction per unit E: c0 = (2 − h2/h1)/6 − h1/(2H), c1 = H²/(6 h1 h2) − 1/2,
  c2 = (2 − h1/h2)/6 − h2/(2H). They sum to zero (each pair's establishment is kept) and
  Σ c_k b_k = 0 (the first moment is kept). With h1 = h2: (−1/12, +1/6, −1/12), the founders'
  patch.
- Pairs run from node 0 over the introduced nodes (a pair is formed once its far node is
  introduced; the interval to the boundary node and an odd trailing interval keep the hats).
- Error per pair with a non-uniform density E(b) = E_c + E′(b − b_c): the uniform-scaled
  correction misses E′·∫(b − b_c)(I₂f − I₁f) db. For h1 = h2 the integrand is odd about the
  pair's centre and this term vanishes; for h1 ≠ h2 it is O(E′ h⁴ f″) per pair [i].
  Composite Simpson with unequal widths is in any case exact only to quadratics, so
  unequal pairs are third order globally, equal pairs fourth [i].
- Negative weights: Simpson's end weight H/6·(2 − h2/h1) is negative when h2 > 2 h1, so a
  node at the join of a short and a long interval can carry a negative weight [i].

### The patch (`pairs.patch`, on the exact libS source; scratch build `lib1`)

- `PLANT_SIMPSON` (read once): unset or `off` runs the original loop untouched; `all` corrects
  every complete pair; `lo:hi[,lo:hi]` corrects the pairs lying inside one of these windows
  (pairing is always from node 0, so a window run is the `all` run restricted).
  `founders` is the window `0:bF`, bF the inset node beside the pilot's first closing edge b1,
  taken from the schedule as the founders' round did (not derived from the gate in-run).
- It acts in `for_each_establishment_weight`: J, uptake (`consumption_rate`), the census and
  the per-node diagnostics. **In libS the light does not use it** (crowns spread over each
  interval); the patch adds each pair's correction to the light as a crown at the node's own
  top, leaf area = correction × the node's competition at height 0, so the light's total
  leaf area is the pair rule's. `PLANT_SIMPSON_LIGHT=0` leaves the light on the hats.

### Pre-registration W (before `weights_check.R`)

| # | prediction | probability |
|---|---|---|
| W1 | Uniform E, ten unequal widths: the rule's weights equal composite Simpson's for unequal widths to < 1e-12 | 97% |
| W2 | Uniform E: exact (relative error < 1e-10) on 1, b, b² with unequal widths but not on b³; with equal widths exact on b³ but not b⁴ | 95% |
| W3 | Toy f = exp(−b/0.6) over [0, 3.5] with E uniform, linear, exp(−b) and a gate (1 − b/3.6)²: on uniform grids (N 12 → 24 → 48) the rule's order is 3.6–4.4 for all four E, the hats' 1.9–2.1 | 80% |
| W4 | On graded grids (widths alternating 1:2) the rule's order is 2.6–3.4 | 70% |
| W5 | On graded grids with non-uniform E, the exact-moment quadratic rule (E's second moment from a linear density per interval) is at most 2× more accurate than the rule at N = 12 | 60% |
| W6 | (added before the run, with the moment form) Gap toy (spells 0.30 y, gaps 0.12 y, inset nodes 12 d inside each edge, fate × 0.1 for cohorts born in a gap): at the H2-like layout (a node mid-gap) the uniform form errs more than the hats while the moment form errs less | 65% |
| W7 | Gap toy with smooth fate: both forms beat the hats at both layouts | 60% |

Added to the patch before any run of it: `PLANT_SIMPSON_FORM=moment`, the pair's weights as
∫E·L_k (L_k the quadratic Lagrange basis on the pair's three nodes), each interval's second
moment of E estimated from the linear density that matches its tracked establishment and
first moment, m2 ≈ h·M − h²·E/6 (exact for a linear density; clamped to [M²/E, h·M]). Reason
[i]: on a gap interval the establishment sits in the two 12-d strips at its ends, far from
uniform, and the uniform form would move E/6 of a pair's weight onto a mid-gap node (H2), or
mis-share it between the two inset nodes (L); ∫E·L_k gives a mid-gap node almost nothing.
The default form is `uniform` (the founders' patch generalised).

### Result W (`weights_check.R`, `weights_check.log`) [m]

- W1 **confirmed**: uniform E, ten unequal widths (ratios to 3.0): the rule equals
  composite Simpson for unequal widths to 1.1e-16.
- W2 **confirmed**: unequal widths exact on 1, b, b² (≤ 2e-16), not on b³ (1.9e-4); equal
  widths exact on b³, not b⁴ (6.7e-5).
- W3 **confirmed**: uniform grids, N 12 → 24 → 48, the rule's orders 3.92–4.14 for all four
  densities (6 → 12: 3.71–4.38); the hats' 1.98–2.00.
- W4 **confirmed**: graded 1:2 grids, 12 → 24 → 48: 2.83–3.01 (6 → 12 on the exp and gate
  densities 2.50, 2.60: pre-asymptotic).
- W5 **confirmed**: graded grids, N = 12: the moment form is 1.5× (exp), 1.3× (gate) better
  and 1.2× worse (linear) than the uniform form. On uniform grids the two coincide.
- W6 **refuted**: with fate × 0.1 for gap-born cohorts, the H2-like layout (a node mid-gap)
  errs −2.3% with the hats, −4.7% uniform form, −4.4% moment form. The quadratic through a
  high–low–high triple dips below the hats at the strips; the moment form does not rescue a
  fate that jumps at the edge. Where fate is smooth through the gap the problem goes away
  (W7). The record says fate keeps rising into the gap (`closing/notes.md`, Q2: +0.22 at the
  edge, +0.30 10 d into the gap), so the smooth toy is the closer one [i].
- W7 **confirmed**: smooth fate, L-like: hats +3.1e-3, uniform −1.2e-3, moment −0.7e-3;
  H2-like: +8.7e-4, −5.6e-5, −1.8e-5.
- Negative weights (uniform E): a pair's end weight is negative once the far interval is more
  than twice the near one (ratio 3: −0.167 H; ratio 5: −0.50 H); one negative node in the
  L-like gap toy under either form.

## Step 2. TF24 evaluation

### Layouts (`mk_sched.R`, `mk_sched.log`) [m]

L = the committed `insc` schedule with its founders' nodes in [0, bF] replaced by 12 equal
intervals (for dry and episodic-lma, `identical()` to the founders' round's `ladT12`).
In every case **no node sits inside a gap**: each gap interval runs from the closing spell's
inset node (c − 12 d) to the next spell's inset node (a + 12 d), so one interval holds both
edge strips and the gap. Pairing from node 0 puts each gap interval either second in its
pair (K: [., c − 12 d, a + 12 d], beside the closing spell's last interval) or first (P:
[c − 12 d, a + 12 d, .], beside the opening spell's first interval):

| case | nodes L / H2 / H4 / C2 | pairs F / K / P / I / Z | K pairs with width ratio outside [½, 2] | P pairs outside |
|---|---|---|---|---|
| dry | 144 / 287 / 573 / 73 | 6 / 22 / 14 / 24 / 5 | 11 of 22 | 7 of 14 |
| episodic-lma | 113 / 225 / 449 / 57 | 6 / 6 / 16 / 23 / 5 | 1 of 6 | 2 of 16 |
| long-wet | 153 / 305 / 609 / 77 | 6 / 27 / 18 / 20 / 5 | 11 of 27 | 5 of 18 |
| dry-flat | 187 / 373 / 745 / 94 | 6 / 44 / 27 / 15 / 1 | 19 of 44 | 10 of 27 |

Interior pairs (I) all have ratios inside [½, 2]. So the "closing strips" and "opening
strips" are not separate intervals in this layout; the regions are scored by pair (K, P).
In H2 each pair is one L interval halved (equal widths); a gap interval's pair then has its
middle node mid-gap.

Settings: `off`; `founders` (window 0:bF, bF = the inset node beside b1, from the schedule);
`all`; `all` with `PLANT_SIMPSON_FORM=moment` (`allm`); `nogap` (the F, I and Z pairs only).

### Pre-registration E (before any lib1 run)

Expected sizes [i]: the founders' round's trapezium founders' error at 12 intervals (libF)
was 0.51 rms on dry and 1.11 on episodic-lma; the committed runs' non-founders' error ("rest")
0.115, 0.404, 0.041 (long-wet), 0.116 (dry-flat).

| # | prediction | probability |
|---|---|---|
| G1 | lib1 with `PLANT_SIMPSON` unset reproduces lib0 bit for bit (J, steps, weights, elasticities) on dry and episodic-lma | 95% |
| E1 | `founders` cuts L's rms error (against the nested reference) by ≥ 2.5× on dry and episodic-lma and ≥ 1.5× on long-wet and dry-flat | 65% |
| E2 | `all` (uniform form) errs more (rms) than `founders` on at least 2 of the 4 cases | 55% |
| E3 | `allm` errs less (rms) than `all` on at least 3 of 4 | 55% |
| E4 | On dry, `all` − `founders` along M has size ≥ 0.15 (the gap pairs move the hydraulic direction) | 55% |
| E5 | The nested reference (H2, H4 trapezium, Richardson) is within 0.10 rms of the independent lib19-class reference (`common.R` REF) on each case it is built for | 60% |
| E6 | H2 under `all` is within 0.08 rms of the nested reference on dry, episodic-lma and long-wet | 55% |
| E7 | Under `all` at L there are ≥ 5 negative node weights on each of dry, long-wet, dry-flat, and every negative weight sits in a K or P pair | 80% |
| E8 | Rows under `all` within ±5% of `off` on every case; forward cpu within +15% | 60% |
| E9 | `nogap` (F, I, Z pairs) errs within ±0.03 rms of `founders` on all four cases (interior pairs carry little error at L's spacing) | 60% |

Result G1 (`guard.R g1 g0`) [m]: lib1 with `PLANT_SIMPSON=off` gives J, steps, node weights and
all 50 elasticities `identical()` to lib0 on dry and episodic-lma. **G1 confirmed.** So lib1's
`off` is libS, and every comparison below is within one build.

## Step 3 pre-registration (FF16; before `ff16.R` is run)

`ff16.R`: the "offspring arrival" test's parameters (`scm_base_parameters("FF16")`, lma
0.0825, birth rate 20; and the two-species pair), birth-date coordinate, on the default
schedule S0, every other node of it (C), S0 halved (H) and halved again (HH); each under
`off` and `all` (lib1). Reference: Richardson of H and HH under `off`. Also the default
control (height coordinate). Then `test-strategy-ff16.R` and
`test-strategy-ff16-reference-comparison.R` against lib1 under `all`.

| # | prediction | probability |
|---|---|---|
| F1 | On the height coordinate (FF16's default control) `all` leaves J identical, one and two species: the patch is on the birth-date path only | 97% |
| F2 | Birth date, S0: `all` moves J by 1e-4 to 1e-2 relative | 70% |
| F3 | The move is toward the fine reference: \|J_all − J_ref\| < \|J_off − J_ref\| at S0 and at C (one species) | 65% |
| F4 | Under `all`, `test-strategy-ff16.R` fails only in "offspring arrival" (its birth-date expectations); `test-strategy-ff16-reference-comparison.R` passes | 75% |
| F5 | Every node's final height moves by < 1e-3 relative at S0 | 60% |

### Step 3 results, first part (`ff16.R`, `ff16_score.R`, `ff16_tests.R`; `ff16/ff16_score.log`, `ff16/tests.log`) [m]

One species, birth date; reference = Richardson (order 2) of H, HH under `off` = 17.22189
(off's own order over S0/H/HH 2.28; all's 2.70):

| schedule | nodes | off J (ln error) | all J (ln error) | all − off (ln) |
|---|---|---|---|---|
| C (every other node of S0) | 71 | **fails** (non-finite density at t = 47.6) | 22.1003 (+0.249) | — |
| S0 (default) | 141 | 18.01092 (+0.045) | 18.85011 (+0.090) | +0.0455 |
| H | 281 | 17.39217 (+0.0098) | 17.47004 (+0.0143) | +0.0045 |
| HH | 561 | 17.26446 (+0.0025) | 17.25809 (+0.0021) | −0.0004 |

- Two species (default schedules): J moves +5.9e-7 and +2.0e-4 relative.
- Height coordinate (FF16's default control): J `identical()` under `all`, one and two
  species. **F1 confirmed.**
- **F2 refuted**: the move at S0 is 4.6% (registered 1e-4 to 1e-2).
- **F3 refuted**: `all` moves away from the reference at S0 (+0.045 → +0.090) and H; toward it
  only at HH (0.0025 → 0.0021). At C `off` fails, so no comparison there.
- Where the move comes from (S0, by birth-date band; parts of J_off): weight part −3.9%,
  field part +8.5%. The field part sits in [3, 8): the node at b = 4.5 (FF16's second
  recruitment window: fate per recruit 0.15 at b = 2.25, 34.8 at 4.5, 3e-4 at 10) changes its
  own fate from 34.8 to 51.4 (+48%) under `all`. FF16's fate in birth date is spiky over
  twenty orders of magnitude (2e4 at b = 0, 1e-15 at b = 0.44, 35 at 4.5); the default schedule
  does not resolve that window, and the pair rule amplifies what it misses [i].
- **F5 refuted**: final heights move up to 4.0e-3 relative (median 5e-5).
- Tests under `all` (lib1, scratch tree): `test-strategy-ff16.R` fails 3 expectations, all
  in "offspring arrival" (its birth-date J and step pins); 0 failures under `off`.
  `test-strategy-ff16-reference-comparison.R` passes under both. **F4 confirmed.** To land,
  "offspring arrival"'s birth-date pins (one-species J 18.0109, `ode_times`, the
  two-species J) would be re-blessed; the height-coordinate pins elsewhere do not move.

| F6 | (registered before the run) With the light left on the hats (`PLANT_SIMPSON_LIGHT=0`) the field part of the S0 move shrinks by more than half | 60% |
| F7 | (registered before the run) Two species, against their own H/HH Richardson reference: `all` with the light on the hats errs less than `off` at the default schedule on both species | 55% |
| E10 | (registered before the runs, after F1–F7) TF24 at L: `all` with the light on the hats (`Lallnl`) differs from `all` by < 0.05 rms on every case (TF24's light is a minor channel) | 55% |
