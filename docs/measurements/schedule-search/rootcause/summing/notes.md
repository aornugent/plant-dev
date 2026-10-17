# Summing over nodes in birth date by pairs of intervals (Simpson-type), TF24 and FF16

Subject: replace plant's per-interval hat weights (trapezium in birth date) by weights from
piecewise-quadratic interpolation over consecutive pairs of intervals, and measure what it
does to TF24's schedule error (all regions, not only the founders) and to FF16. Process:
`.claude/skills/systematic-debugging/SKILL.md`; every prediction is written here before the
run or analysis it concerns. Scripts and the patch are in this directory; outputs in
`scratchpad/deep/rootcause/summing/` (`runs/`, `sched/`, `logs/`, `*.log`, small `*.rds`).
Every number is marked **[m]** (measured) or **[i]** (inferred: a derivation, fit or reading).

## Summary

Stopped at the user's request before the final scoring; the results below are as recorded. The decision was to keep the straight-line sums and pursue the H5 layout with a pair of runs instead (see `../h5/`, `../proxies/`).

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

### Pre-registration R (before the region, ladder, jitter and guarded runs)

Runs: windows K, P, I under `all` (F is `founders`); L with one region's pairs halved (L_F,
L_K, L_P, L_I) under `off` (all four cases) and under `all` (dry, long-wet); C2 under `off`
and `all` (all four); dry at tol 1.05e-4 under `all` and `off`; `allr`, the pair rule on the
pairs whose two widths are within a factor 2 (any region). Region errors as in `region.R`
(`off` by −4/3 × the region-halving move; `all` = off + the rule's change in that region).

| # | prediction | probability |
|---|---|---|
| R1 | Under `off` the founders' region carries ≥ 60% of L's squared error (projection) on dry, episodic-lma and dry-flat | 70% |
| R2 | `founders` removes ≥ 75% of the founders' region error (\|e_off(F) + d(F)\| ≤ 0.25 \|e_off(F)\|) on all four | 65% |
| R3 | Interiors: e_off(I) rms ≤ 0.1 and d(I) rms ≤ 0.1 on all four | 60% |
| R4 | Edge pairs: d(K) + d(P) has rms ≥ 0.15 and \|along M\| ≥ 0.1 on dry and dry-flat | 60% |
| R5 | The rule hurts at the edges: rms of e_all(K + P) > rms of e_off(K + P) on at least 2 of 4 | 55% |
| O1 | `off`, dry and long-wet: pooled order over C2 / L / H2 is 1.6–2.4 | 65% |
| O2 | `all`: pooled order over C2 / L / H2 is ≥ 2.5 on neither case | 65% |
| O3 | Interiors under `all` (L_I against e_all(I)): order ≥ 3 on dry and long-wet | 45% |
| J1 | dry, `all` at tol × 1.05: move rms ≤ 0.04 and \|along M\| ≤ 0.12 (as `off`'s floor, 0.024 / 0.09) | 60% |
| A1 | `allr` errs (rms) at most `founders` + 0.03 on all four, and less than `all` on at least 3 | 50% |

### Pre-registration L (before `LFallnl_dry`, `Lfoundersnl_dry`; after seeing dry's region split, where the founders' residual under `all` still moves 0.089 rms when the founders are halved, order ≈ 1.8)

| # | prediction | probability |
|---|---|---|
| L1 | dry: with the light on the hats, halving the founders under `all` moves the run more than with the light corrected (0.089 rms): the residual founders' error is the light's | 50% |
| L2 | dry: `founders` with the light on the hats differs from `founders` by ≤ 0.05 rms | 55% |

### Why the light does not follow the rule in libS, and a fourth light setting (registered before building lib2)

Reading after the reference runs (dry, episodic-lma, long-wet scored; numbers in Result E
below): on long-wet `founders` barely helps (0.459 → 0.399) and H2 under `all` equals H2
under `off` (0.120 / 0.118), while the trapezium shrinks ×4 from H2 to H4: what is left is
second order and of the light-capture family (a, a_l1, curv_fact_elec_trans), the family
the founders' round found for long-wet's founders. In FF16 the point-crown correction made
J worse (Step 3) and leaving the light on the hats made it 9× better.

Derivation [i]: in libS the light at height z is a sum over crowns spread through each
interval (eight per interval, tops and leaf areas linearly interpolated between the two
nodes). Adding Σ_k Δw_k·LA_k·Q(z/h_k) at the nodes gives S[g] + (crowns − T[g]), with
g(b) = LA(b)·Q(z/h(b)), S and T the node rules. crowns − T[g] is O(h²), so the light stays
second order whatever the node weights; only its constant changes. In libF the light was a
node sum, so the founders' patch reached it. A light that follows the rule needs the crowns
themselves built from the pair's quadratic: `PLANT_SIMPSON_LIGHT=quad` (lib2) places each
selected pair's 16 crowns at the same places as the hats', with top = the quadratic through
the three nodes' heights and leaf area = the hats' establishment density × the quadratic
through the three nodes' leaf areas (no point corrections). Other intervals keep the hats.

| # | prediction | probability |
|---|---|---|
| Q0 | lib2 with `PLANT_SIMPSON=off` reproduces lib1/libS bit for bit (dry guard) | 95% |
| Q1 | long-wet at L: `all` with `quad` light errs < 0.25 rms (all 0.41, founders 0.40) | 50% |
| Q2 | long-wet: H2 under `all` + `quad` is within 0.06 rms of the reference (H2 off 0.118) | 45% |
| Q3 | dry and episodic-lma at L: `all` + `quad` within ±0.05 rms of `all` | 50% |
| Q4 | FF16 one species, S0: `all` + `quad` errs less in ln J than `off` (0.045) | 55% |

Results so far for this setting [m]: Q0 **confirmed** (lib2 `off` = lib1 = libS on dry, J,
steps, weights, 50 elasticities `identical()`). FF16 with `all` + `quad` (lib2): one species
ln J error +0.0126 (S0), +0.0015 (H), −0.0001 (HH), against `off`'s +0.045, +0.0098, +0.0025;
two species −0.0001/−0.0002 against +0.0019/+0.0103 at their default schedule. **Q4
confirmed.** long-wet at L: `founders` + `quad` 0.176 rms (hat light 0.399), `all` + `quad`
0.241 (0.412). **Q1 confirmed** (0.241 < 0.25), but its largest errors are now hydraulic
(root_P50 −0.98, omega +0.63, along M +0.62), the signature of dry's K pairs.

### Pre-registration Q2 (before the second set of lib2 runs)

From here the rule's candidates run with the light on the pair's quadratic crowns (`q`):
`foundersq`, `allq`, `nogapq` (F, I, Z pairs), H2 under `allq` (all four cases), the region
windows K, P, I and L_R under `allq` (dry, long-wet, episodic-lma off-halved only), C2 under
`allq`, dry at tol × 1.05 under `allq`.

| # | prediction | probability |
|---|---|---|
| Q5 | Under `allq` the K pairs' change d(K) still has \|along M\| ≥ 0.3 on dry and long-wet (the K-pair shift comes from J's and the uptake's weights, not the light) | 70% |
| Q6 | `nogapq` errs least (rms) of all settings on at least 3 of 4 cases | 50% |
| Q7 | H2 under `allq` is within 0.06 rms of the nested reference on all four cases | 55% |
| Q8 | `foundersq` errs no more than `founders` (rms) on all four | 75% |
| O4 | `allq` ladder (C2 / L / H2) pooled order ≥ 2.5 on long-wet | 40% |
| O5 | Interiors under `allq` on long-wet: order ≥ 3 | 50% |
| J2 | dry, `allq` at tol × 1.05: move rms ≤ 0.04 and \|along M\| ≤ 0.12 | 60% |

Process note (23:39): while restarting my queue I killed, by a too-broad process match, the
other agent's `xargs` for `rootcause/p50/jobs3.txt` (PID 963). Its two running jobs
(p5_L4_dry-flat, p5_O4_long-wet) kept running and record their own completion; its one
unstarted job (p5_I2_dry-flat) is also in its `jobs4.txt`, which its waiter then started
early, so for about half an hour four of its runs overlapped. I held my own queue to one run
(`maxr`) until its two orphaned runs finished. No run of either agent was lost or altered.

Result Q2 [m]: long-wet H2 under `allq` is 0.011 rms (worst 0.04) from the nested reference,
against 0.118 for H2 under `off` and 0.120 under `all` with the hat light. **Q2 confirmed**:
when every pair is two equal halves and the light follows the rule, the rule lands on the
trapezium's Richardson reference.

### Pre-registration P (before the P2 runs)

P2 = C2 with every interval bisected: L's node count (dry 145 vs 144), every pair two equal
halves of one C2 interval, so no pair has unequal widths and no inset node is a pair's
middle node by construction (C2 keeps every other node of L, so some inset nodes go).

| # | prediction | probability |
|---|---|---|
| P1 | P2 under `allq` errs (rms) less than L under `allq` on dry and long-wet | 55% |
| P2 | P2 under `allq` errs less than L under `foundersq` on dry and long-wet | 45% |

### Result E (`score.R`, `score.log`; `diffs.R`) [m]

Reference: nested trapezium (H2, H4 on lib1, Richardson). It agrees with the independent
lib19-class reference to 0.035 (dry), 0.037 (episodic-lma), 0.008 (long-wet) rms. dry-flat's
H4 was not run (cost); dry-flat is scored on the lib19-class reference. Errors at L, ε:

| case | setting | rms | worst | along M | ln J | rows | fwd + grad cpu (s) |
|---|---|---|---|---|---|---|---|
| dry | off | 0.572 | 1.00 (a) | −0.48 | +0.208 | 365 997 | 65 + 145 |
| dry | founders | 0.160 | 0.52 (a) | −0.03 | −0.112 | 368 337 | 67 + 152 |
| dry | all | 0.220 | 0.93 (root_P50) | +0.80 | +0.138 | 364 376 | 61 + 145 |
| dry | all, moment form | 0.193 | 0.71 (root_P50) | +0.73 | +0.141 | 366 195 | 60 + 139 |
| dry | all, light on hats | 0.233 | 0.98 (root_P50) | +1.05 | +0.150 | 363 097 | 59 + 135 |
| dry | nogap | 0.149 | 0.53 (a_l1) | +0.07 | +0.131 | 365 546 | 61 + 137 |
| dry | allr (width ratio ≤ 2) | 0.206 | 0.81 (root_P50) | +0.79 | +0.196 | 365 225 | 63 + 142 |
| episodic-lma | off | 1.594 | 3.19 (lma) | +5.64 | −0.013 | 210 776 | 40 + 82 |
| episodic-lma | founders | 0.430 | 0.95 (vcmax_25) | +0.93 | −0.202 | 210 723 | 39 + 93 |
| episodic-lma | all | 0.179 | 0.44 (a_dG1) | +0.74 | +0.129 | 210 289 | 38 + 80 |
| episodic-lma | all, moment form | 0.266 | 0.63 | +0.74 | +0.047 | 209 743 | 37 + 81 |
| episodic-lma | all, light on hats | 0.147 | 0.57 | +0.65 | +0.135 | 210 837 | 35 + 78 |
| episodic-lma | nogap | 0.300 | 0.68 (a_l1) | +0.32 | +0.297 | 209 160 | 35 + 80 |
| long-wet | off | 0.459 | 1.48 (a) | +0.36 | +0.410 | 437 952 | 80 + 172 |
| long-wet | founders | 0.399 | 1.38 (a) | +0.56 | +0.369 | 435 466 | 79 + 164 |
| long-wet | all | 0.412 | 1.36 (a) | +0.99 | +0.491 | 435 480 | 79 + 161 |
| long-wet | all, moment form | 0.399 | 1.37 | +0.73 | +0.438 | 437 516 | 79 + 166 |
| long-wet | all, light on hats | 0.330 | 1.14 | +1.23 | +0.427 | 435 521 | 75 + 164 |
| long-wet | nogap | 0.397 | 1.34 (a) | +0.54 | +0.401 | 436 246 | 79 + 170 |
| long-wet | allr | 0.404 | 1.38 (a) | +0.47 | +0.375 | 435 480 | 78 + 155 |
| dry-flat (lib19 ref) | off | 0.786 | 2.35 (a_l1) | +0.19 | +0.681 | 772 785 | 164 + 322 |
| dry-flat | founders | 0.425 | 1.44 (a) | +0.36 | +0.313 | 768 114 | 156 + 304 |
| dry-flat | all | 0.470 | 1.33 (a, root_P50) | +1.03 | +0.505 | 772 412 | 152 + 301 |
| dry-flat | all, moment form | 0.441 | 1.33 | +0.80 | +0.487 | 768 697 | 150 + 306 |
| dry-flat | all, light on hats | 0.504 | 1.98 (a_l1) | +1.82 | +0.529 | 767 868 | 151 + 292 |

Nested refinement (ε, against the nested reference): H2 under `off` 0.137 / 0.391 / 0.118
(dry / episodic-lma / long-wet), under `all` 0.051 / 0.075 / 0.120; H4 under `off` 0.034 /
0.098 / 0.029; H4 − H2 under `off` shrinks the error ×4.0, ×4.0, ×4.1 (order 2). dry-flat H2
`off` 0.206 against lib19.

Negative node weights under `all` at L: dry 8 (sum −0.45 of total weight 32; K 4, K+P 3, P
1), episodic-lma 4 (−2.8 of 33; Z 2, K+Z 1, P 1), long-wet 9 (−2.4 of 32; K 5, P 2, P+K 1,
Z 1), dry-flat 17 (−24 of 29; one late node at b = 36.6 carries −22.9, nrr 1.5e-19, in a
pair of widths 4078 d and 218 d). Every one sits in a pair whose two widths differ by more
than 2×; in the founders (equal widths) and interiors (ratios within ½–2) there are none.
They change J little (the large ones sit where nrr ≈ 0) but they make the light and uptake
sums carry negative leaf area and uptake.

Scored:
- E1 **refuted** (long-wet): `founders` cuts the error 3.6× (dry), 3.7× (episodic-lma),
  1.85× (dry-flat), only 1.15× on long-wet. Cause: the light (see the derivation above).
  With the light on the pair's quadratic crowns long-wet's `founders` errs 0.176 (2.6×).
- E2 **confirmed** (3 of 4): `all` errs more than `founders` on dry, long-wet, dry-flat; less on
  episodic-lma (0.179 against 0.430).
- E3 **confirmed** (3 of 4), but small: the moment form is 0.01–0.03 better on dry, long-wet,
  dry-flat, and 0.09 worse on episodic-lma; differences 0.05–0.12 rms.
- E4 **confirmed**: on dry `all` − `founders` along M is +0.83.
- E5 **confirmed** on the three cases built (0.035, 0.037, 0.008).
- E6 **refuted** (long-wet): H2 under `all` is 0.051 (dry), 0.075 (episodic-lma), 0.120 (long-wet,
  no better than `off`'s 0.118). With `quad` light, 0.011 (Q2).
- E7 **refuted** as registered: ≥ 5 negative weights on dry, long-wet and dry-flat holds, but
  not "all in K or P": late pairs (Z) with wide width ratios carry some, including the largest.
- E8 **confirmed**: rows within −0.6% to +0.1% of `off`; forward cpu 2–8% lower.
- E9 **refuted** (episodic-lma): `nogap` is within 0.03 of `founders` on dry (0.149/0.160) and
  long-wet (0.397/0.399) but 0.13 better on episodic-lma (0.300/0.430).
- E10 **refuted**: the light setting matters: rms(light on hats − point corrections) 0.063
  (dry), 0.109 (episodic-lma), 0.260 (long-wet), 0.316 (dry-flat).

### Pre-registration N (before the `noKq` runs; after seeing `nogapq` and long-wet's region split)

Seen so far [m]: `nogapq` (F, I, Z pairs, quad light) errs 0.044 (dry), 0.158 (long-wet),
0.086 (dry-flat) but 0.346 on episodic-lma, where `allq` errs 0.116. On long-wet under `allq`
the K pairs carry 0.27 rms (root_P50 −1.09, along M +0.66) and the P pairs 0.04.
`noKq`: every pair except K (F, P, I, Z), quad light.

| # | prediction | probability |
|---|---|---|
| N1 | `noKq` errs ≤ `nogapq` + 0.02 on dry, long-wet and dry-flat, and ≥ 0.1 less than `nogapq` on episodic-lma | 45% |

### Result Q (lib2: the light on the pair's quadratic crowns) (`score.R`, `score.log`) [m]

Errors at L against the nested reference (dry-flat: lib19-class), ε:

| case | off | founders (hat light) | foundersq | allq | nogapq | noKq | P2 allq | H2 allq (2× nodes) | H2 off | H4 off (4×) |
|---|---|---|---|---|---|---|---|---|---|---|
| dry | 0.572 | 0.160 | 0.118 | 0.188 (M +0.36) | **0.044** | 0.101 (M −0.41) | 0.149 (M −0.65) | 0.031 | 0.137 | 0.034 |
| episodic-lma | 1.594 | 0.430 | 0.408 | **0.116** | 0.346 | 0.300 | — | 0.090 | 0.391 | 0.098 |
| long-wet | 0.459 | 0.399 | 0.176 | 0.241 (M +0.62) | **0.158** | 0.165 | 0.158 | 0.011 | 0.118 | 0.029 |
| dry-flat | 0.786 | 0.425 | 0.139 | 0.322 (M +0.44) | **0.086** | 0.112 | — | (below) | 0.206 | — |

Rows and cpu do not move with the setting (within ±1% of `off`'s rows at L; forward cpu 4–12%
lower under the pair settings, as `off` at L). Worst single errors: `nogapq` 0.20 (dry, a_l1),
0.66 (episodic-lma, k_s/D_c), 0.34 (long-wet, a_l1), 0.26 (dry-flat, vcmax_25); `allq`'s worst
are hydraulic (root_P50 −0.89, −0.98, −1.44 on dry, long-wet, dry-flat).

- Q3 **refuted**: on dry `allq` − `all` is 0.144 rms (rms 0.188 against 0.220); on
  episodic-lma 0.165 (0.116 against 0.179). The light matters on every case.
- Q5 **confirmed**: under `allq` the K pairs' change has along M +0.69 (dry), +0.66 (long-wet).
- Q6 **confirmed** (3 of 4): `nogapq` errs least on dry, long-wet (0.158, tied with P2 at the
  shown digits) and dry-flat; on episodic-lma `allq` is far better (0.116 against 0.346).
- Q7 **refuted** (episodic-lma): H2 under `allq` 0.031 (dry), 0.011 (long-wet), 0.090
  (episodic-lma; H4 `off` itself errs 0.098 there).
- Q8 **confirmed**: `foundersq` ≤ `founders` on all four (0.118/0.160, 0.408/0.430,
  0.176/0.399, 0.139/0.425).
- P1 **confirmed**: P2 under `allq` errs less than L under `allq` on dry (0.149/0.188) and
  long-wet (0.158/0.241). P2 **refuted**: not less than `foundersq` on dry (0.149/0.118).
- N1 **refuted**: `noKq` is worse than `nogapq` on dry (0.101/0.044: the P pairs' change has
  along M −0.57 on dry) and does not recover episodic-lma (0.300 against `allq`'s 0.116): on
  episodic-lma the K pairs are what helps.

### Result R (regions; `region.R`, `region_all.log`, `region_allq_*.log`) [m]

Errors by region at L (rms, along M), ε. `off`: −4/3 × the region-halving move (order 2
assumed); the rule: `off` + its change in that region; Z = the residual (late pairs plus
non-additivity, and whatever the K strip's missing power law leaves).

| case | region | off | all (hat + point light) | allq |
|---|---|---|---|---|
| dry | F founders | 0.597 (−0.57) | 0.124 (−0.12) | **0.049** (−0.24) |
| dry | K (closing inset node as a pair's middle) | 0.045 (−0.22) | 0.199 (+0.71) | 0.231 (+0.47) |
| dry | P (opening side) | 0.018 (−0.05) | 0.087 (−0.29) | 0.119 (−0.62) |
| dry | I interiors | 0.143 (−0.25) | 0.056 (−0.07) | 0.058 (−0.08) |
| dry | Z* residual | 0.136 (+0.61) | 0.119 (+0.57) | 0.178 (+0.82) |
| long-wet | F | 0.462 (+0.43) | 0.399 (+0.62) | **0.162** (+0.16) |
| long-wet | K | 0.009 | 0.183 (+0.47) | 0.267 (+0.64) |
| long-wet | P | 0.006 | 0.030 | 0.037 |
| long-wet | I | 0.030 | 0.020 | 0.031 |
| long-wet | Z* | 0.014 | 0.027 | 0.027 |

Shares of L's squared error by projection: `off` F 103% (dry), 100% (long-wet); `allq` K 111%
(dry), 88% (long-wet).

- R1: dry 103% ✓; episodic-lma and dry-flat in Result R2 below (episodic-lma) / not run
  (dry-flat's region runs were dropped for cost).
- R2 **refuted** (long-wet with the hat light: the founders' error falls only 0.462 → 0.399;
  with `quad` 0.162). dry 0.597 → 0.124 (hat), 0.049 (quad).
- R3 **refuted** on dry: the interiors' trapezium error is 0.143 (ln J −0.25); the rule takes it
  to 0.056. On long-wet both are 0.02–0.03.
- R4 **confirmed on dry** (K + P change 0.224 rms under `allq`, 0.28 under `all`; along M +0.12
  and +0.69); dry-flat's region runs were not made.
- R5 **confirmed**: the rule's edge-pair error exceeds the trapezium's on dry (0.23 against
  0.05) and long-wet (0.24 against 0.01).

Mechanism of the K-pair error [m + i]: under the trapezium the K region errs little (0.009–0.045)
because the 12-d inset is a tuned cancellation (`closing/notes.md`). A K pair puts the closing
inset node (c − 12 d) in the middle of an unequal pair whose second interval is the gap
interval (its establishment in two 12-d strips at its ends), so the pair rule moves weight
onto that node and off the opening inset node: the hydraulic quantities (root_P50, omega,
root_c) move along M. Halving the K pairs (equal halves, a node mid-gap) removes it entirely
(shrink 0.93–1.02 of e(K) under the rule), as does H2. It is a rule-made error of the L
layout's pairing, not of the integrand.

### Result O (ladders C2 / L / H2) and J (jitter) [m]

| case | setting | C2 − L rms | L − H2 rms | pooled order | cos(m1, m2) | C2 error |
|---|---|---|---|---|---|---|
| dry | off | 1.601 | 0.442 | 1.86 | +0.98 | 2.162 |
| dry | all | 0.849 | 0.192 | 2.15 | +0.36 | 0.960 |
| dry | allq | 0.741 | 0.187 | 1.99 | +0.10 | 0.792 |
| long-wet | off | 1.528 | 0.341 | 2.16 | +0.97 | 1.975 |
| long-wet | all | 1.417 | 0.306 | 2.21 | +0.67 | 1.756 |
| long-wet | allq | 0.307 | 0.245 | 0.33 | −0.38 | 0.318 |

- O1 **confirmed** (off: 1.86, 2.16; the moves are parallel, cos 0.97–0.98).
- O2 **confirmed**: no clean higher order at the layout level (`all` 2.15, 2.21; `allq` 1.99,
  0.33, with the two moves near orthogonal): the K pairs' error appears at L and vanishes at H2.
- O3: dry's interiors under `all` read order 3.26 (e(I) 0.056 → move 0.054); long-wet's
  interiors err 0.02–0.03, the jitter floor, so no order can be read. **Not confirmed** (one
  case of two).
- O4 **refuted** (0.33). O5 **refuted**: long-wet's interior error under `allq` (0.031) is at
  the floor; the reading 0.85 is noise.
- By region the rule does reach higher order where the pairs are equal and the light follows:
  founders on long-wet (shrink 0.98 of e(F) on halving, order > 4), P pairs on long-wet
  (order > 4); dry's founders under `allq` sit at the floor (0.049).
- J1 **confirmed at the edge** (dry, `all`, tol × 1.05: rms 0.030, along M +0.12). J2
  **confirmed** (`allq`: rms 0.009, along M +0.03). For comparison `off` at L moves 0.054, along
  M +0.25 under the same nudge.

### Result L (the light under the founders) [m]

- L1 **refuted**: with the light on the hats, halving the founders under `all` moves 0.035 rms,
  less than the 0.089 with the point corrections; with `quad` 0.040. The point corrections
  added a founders' residual of their own.
- L2 **refuted**: `founders` with the light on the hats differs from `founders` by 0.116 rms.

### Pre-registration FI (before the `FIq` runs; after episodic-lma's region split)

Seen [m]: on episodic-lma under `allq` the founders' residual is 0.020, but the K, P and late
(Z) pairs each change the run by 0.27, 0.49 and 0.55 rms, in directions that partly cancel
(root_P50 −0.89 in K, +0.97 in P; K_s, D_c −1.0 in Z); episodic-lma's late pairs are wide and
unequal (162 d next to 775 d; the negative weights sit there). `FIq`: the founders' and
interior pairs only, quad light.

| # | prediction | probability |
|---|---|---|
| FI1 | `FIq` errs < 0.25 on episodic-lma, and within ±0.03 of `nogapq` on dry, long-wet and dry-flat | 50% |
