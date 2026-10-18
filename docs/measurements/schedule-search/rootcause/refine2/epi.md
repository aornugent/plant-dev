# epi-adG208's low estimate: where the replay misses error

The case: the episodic record, a_dG2 ×0.8, t_r 17.8 d. On libS the replay's read at scale 1 is
0.61 (a_l1: error 0.54ε, estimate 0.33). At half scale, a_l1's error is 1.625, 0.661 and 0.152
over levels 0, 1 and 2 (R20, R21). R21 refuted three causes: spell ends, short spells and step
changes. Scripts are beside this file; runs are in `scratchpad/epi/runs`.

## What the saved runs already show (no new runs)

The level differences do not depend on the reference. Here D(1→0) is level 0 on level 1's steps
minus level 1 (pinned), D(0→−1) is level 0's replay minus level 0 (pinned), and D(2→1) is level 1
minus level 2 (not pinned; a_l1's step change is 0.09ε). All in ε.

| quantity | D(0→−1) | D(1→0) | D(2→1) | D(0→−1)/D(1→0) | D(1→0)/D(2→1) |
|---|---|---|---|---|---|
| a_l1 | 3.35 | 1.05 | 0.51 | 3.2 | 2.1 |
| lnJ | −1.20 | −0.44 | −0.13 | 2.8 | 3.5 |
| a | −0.77 | −0.28 | −0.105 | 2.8 | 2.7 |
| k_I | −0.67 | −0.23 | −0.095 | 2.9 | 2.4 |
| jmax_25 | −0.60 | −0.19 | −0.088 | 3.1 | 2.2 |
| k_s | −0.66 | −0.24 | −0.057 | 2.8 | 4.2 |
| storage_relaxation_offset | −0.45 | −0.38 | −0.16 | 1.2 | 2.4 |

- The anomaly is D(2→1), large against D(1→0): a_l1 falls ×2.1 from one doubling to the next,
  where the square law gives ×4. So level 2 still carries a part that falls slowly, or level 1
  carries a part that grew. The light and carbon group (a, k_I, jmax_25, curv_fact_elec_trans,
  lma, R_d_25) shares the ratio (2.0–2.7); the hydraulic group (k_s, r_s) and lnJ do not (3.5–4.2).
- At scale 1 (194 nodes) a_l1's error is 0.54ε, under half-scale level 1's 0.66ε with 232
  nodes: the error is not monotone in the count, as a component set by where nodes sit would be.
- The other cases at scale 1 read 1.0–1.3 for a_l1 except dry-flat (0.32 on an error of 0.16ε),
  and episodic-lma (the same record) reads 1.0–1.1 across the light group.
- epi-adG208's first run has b1 = 3.08 y and one long spell 3.81–5.93 y closed by a 2.3-d gap;
  episodic-lma's has b1 = 3.71 y and three spells there.

## Pre-registration E1 (region-mixed replays, libS, half scale)

Six regions, bounded inside gaps: A [0, 3.2] the first spell, B [3.2, 6.6] (the spell closed by
the 2.3-d gap at 5.928 y, and the spell after it), C [6.6, 12.6], D [12.6, 17.7], E [17.7, 24.5],
F [24.5, horizon]. Each replay is a saved run on its own steps with one region's panels at the
level below (`mixed.R`); D_R is the replay minus the run.

| | prediction | confidence |
|---|---|---|
| E1a | on level 1's steps, the six D_R(1→0) sum to D(1→0) within 0.05ε in every quantity | 85% |
| E1b | one region carries the slow part: its D_R(1→0)/D_R(2→1) for a_l1 is under 2.5 while every region with \|D_R(2→1)\| > 0.1ε elsewhere is 3–5 | 50% |
| E1c | that region is B | 35% |

## Step 1. The low read survives on libNS (`score_ns.R`, the coordinator's canonical fit) [m]

On libNS the case reads 0.607 (worst error a_l1 0.518ε, bound 0.713, 47/47 covered); libS read
0.61. The spread moves this case's answers by at most 0.029ε (rms 0.008) and its estimates by at
most 0.016ε, so the libS half-scale runs serve to locate the cause. (Dry's read on libNS falls to
0.62 from 1.09: the spread moves dry's light group by up to 0.12ε. Not this investigation's case.)

## E1. Region-mixed replays on level 1's steps (libS, half scale; `mixed.R`, `e1_score.R`) [m]

D_R(1→0) per region, ε; "full" is level 0 on level 1's steps minus level 1.

| quantity | A | B | C | D | E | F | sum | full |
|---|---|---|---|---|---|---|---|---|
| a_l1 | −0.09 | 0.10 | **0.55** | 0.20 | 0.25 | 0.06 | 1.06 | 1.05 |
| lnJ | −0.03 | −0.01 | −0.20 | −0.09 | −0.09 | −0.02 | −0.44 | −0.44 |
| a | 0.02 | 0.04 | **−0.20** | −0.08 | −0.06 | −0.01 | −0.28 | −0.28 |
| k_I | 0.03 | 0.05 | **−0.20** | −0.07 | −0.05 | 0.00 | −0.23 | −0.23 |
| jmax_25 | 0.04 | 0.06 | **−0.20** | −0.06 | −0.04 | 0.00 | −0.20 | −0.19 |
| lma | −0.07 | −0.07 | **0.20** | 0.06 | 0.02 | −0.01 | 0.12 | 0.12 |
| storage_relaxation_offset | −0.02 | −0.05 | −0.24 | −0.06 | −0.03 | 0.00 | −0.39 | −0.38 |
| k_s | −0.02 | −0.03 | 0.00 | −0.07 | −0.08 | −0.03 | −0.24 | −0.24 |
| TF24_cost_scale | −0.09 | −0.01 | 0.26 | 0.00 | −0.02 | −0.02 | 0.11 | 0.10 |

- E1a holds: the six sum to the full difference within 0.018ε in every quantity.
- C, 6.6–12.6 y, carries half of a_l1's difference and all of the light group's; the hydraulic
  group sits in D–F. A and B (the first spell, and the spell closed by the 2.3-d gap) carry
  little, of the opposite sign. E1c fails.
- Six replays, 290–300 s CPU each with the coordinator's two loops and the libNS build running.

## Pre-registration E2 (region-mixed replays on level 2's steps, C, D and E)

If C carries the part that falls slowly, D_C(2→1) is large against D_C(1→0) = 0.55.

| | prediction | confidence |
|---|---|---|
| E2a | a_l1's D_C(1→0)/D_C(2→1) is under 2.5 (D_C(2→1) > 0.22ε) | 55% |
| E2b | D and E are on the square law: D_R(1→0)/D_R(2→1) in 3–5 for a_l1 | 55% |
| E2c | A + B + F by difference (level 1 − level 2, not pinned, less C, D, E) is under 0.1ε for a_l1 | 60% |

## E2. Region-mixed replays on level 2's steps (C, D, E) [m]

a_l1, ε (pinned except the A + B + F row, which is level 1 − level 2 less C, D and E):

| region | D_R(1→0) | D_R(2→1) | ratio | light group (a) ratio | storage_relaxation_offset ratio |
|---|---|---|---|---|---|
| C 6.6–12.6 | 0.549 | 0.212 | **2.6** | 4.0 | 2.7 |
| D 12.6–17.7 | 0.197 | 0.102 | **1.9** | 11 | 2.8 |
| E 17.7–24.5 | 0.254 | 0.073 | 3.5 | 2.9 | 3.0 |
| A + B + F | 0.061 | 0.12 ± 0.09 (steps) | — | — | — |
| all | 1.052 | 0.508 | 2.1 | 2.7 | 2.4 |

- E2a holds (C 2.6, D_C(2→1) 0.21 against the 0.22 threshold: on the line); E2b half holds (E
  3.5; D 1.9); E2c fails narrowly (0.12, within the unpinned pair's step noise).
- The slow part of a_l1 sits in C and D, 6.6–17.7 y: if both fell ×4, D(2→1) would be 0.19ε
  lower. Within C the light group is on the square law (×4.0); a_l1 and the storage group are
  not. So the slow part is not the light field.
- Uniform ladders on the same record (episodic-lma, u215/u429/u857) put a_l1 on the square law
  (×4.7), so a_l1 is not slow by nature (`ladders.R`).
- The spell-end intervals are wider against t_r than on the cases that read well, but not
  far: the last interval of a spell is a median 1.63 t_r here, against 1.54 (dry), 1.31
  (long-wet), 1.19 (episodic-lma) and 0.99 (dry-flat) (`endgeom.R`, scale 1).

## Pre-registration E3 (which part of each spell in C and D)

H4: the slow part is each spell's last weeks, the rise over t_r before its end, which the
level-0 and level-1 intervals (27–60 d near an end, 1.5–3.4 t_r) do not resolve, so its error
falls slower than h² until the spacing is under t_r. Test: pinned replays of levels 1 and 2 with
only the last added node of each panel in C ∪ D removed (panels of four or more intervals at
the level below), and with only the first added node removed. The rest of C ∪ D (interiors and
the short spells) is C + D less the two.

| | prediction | confidence |
|---|---|---|
| E3a | the end replays' a_l1 ratio D(1→0)/D(2→1) is under 2.5, and they carry at least half of C ∪ D's excess over the square law (0.19ε) | 45% |
| E3b | the rest of C ∪ D falls by 3.2 or more | 45% |
| E3c | the opening replays are on the law (ratio 3–5) or under 0.05ε | 65% |

## E3. Spell ends and openings in C ∪ D (`zones.R`, `e3_score.R`) [m]

ε; "rest" is C + D less the end and opening replays (interiors and short spells).

| quantity | end 1→0 | end 2→1 | ratio | opening 1→0 / 2→1 | rest 1→0 | rest 2→1 | ratio |
|---|---|---|---|---|---|---|---|
| a_l1 | 0.220 | 0.047 | 4.7 | 0.022 / 0.008 | 0.504 | 0.260 | **1.9** |
| storage_relaxation_offset | −0.168 | −0.031 | 5.4 | 0.006 / 0.000 | −0.135 | −0.079 | **1.7** |
| a_dG1 | 0.055 | 0.010 | 5.3 | 0.001 / 0.002 | 0.034 | 0.051 | **0.66** |
| hmat | −0.035 | −0.004 | 8.3 | −0.011 / −0.003 | −0.065 | −0.028 | 2.3 |
| lnJ | −0.048 | −0.006 | 8.6 | −0.013 / 0.000 | −0.228 | −0.082 | 2.8 |
| a | −0.070 | −0.012 | 5.6 | −0.029 / 0.001 | −0.178 | −0.045 | 4.0 |

- H4 is refuted: the spell ends in C ∪ D fall ×4.7–5.4 (E3a fails). The openings carry almost
  nothing (E3c holds). The slow part is in the rest (E3b fails): a_l1 ×1.9, the storage offset
  ×1.7, and a_dG1 grows from one doubling to the next (×0.66).
- So the part off the law lies in the spells' interiors or in the short spells of 6.6–17.7 y.

## Pre-registration E4 (the short spells of C ∪ D)

Eight panels in C ∪ D hold one interval at half-scale level 0: 6.63–6.81, 6.87, 6.92–7.01,
7.30–7.65, 14.65–14.99, 16.23–16.56, 16.57–16.75 and 17.66 y (three of them, 120 d long, hold
four at scale 1). Pinned replays of levels 1 and 2 with only their added nodes removed. R21
found the short spells together on the law (×3.2), which would leave the interiors.

| | prediction | confidence |
|---|---|---|
| E4a | the short spells of C ∪ D fall ×3 or more in a_l1, so the interiors carry the slow part (ratio under 1.8) | 55% |
| E4b | a_dG1's growth (D(2→1) > D(1→0)) sits in the short spells | 40% |

## E4. The short spells of C ∪ D, and the interiors by difference [m]

a_l1 and the groups, ε. "Interior" is C + D less ends, openings and short spells: the added
nodes inside the long spells, which sit at equal shares of an ungraded density.

| quantity | short 1→0 | short 2→1 | ratio | interior 1→0 | interior 2→1 | ratio |
|---|---|---|---|---|---|---|
| a_l1 | 0.223 | 0.067 | 3.3 | 0.281 | 0.193 | **1.46** |
| lnJ | −0.111 | −0.032 | 3.4 | −0.117 | −0.049 | 2.4 |
| hmat | −0.038 | −0.011 | 3.4 | −0.028 | −0.017 | 1.65 |
| k_s | −0.020 | −0.001 | — | −0.022 | −0.012 | 1.9 |
| a (light group alike) | −0.120 | −0.033 | 3.6 | −0.059 | −0.012 | 5.0 |
| storage_relaxation_offset | −0.186 | −0.077 | 2.4 | 0.052 | −0.001 | — |
| a_dG1 | 0.072 | 0.048 | 1.5 | −0.038 | 0.003 | — |

- E4a holds: the short spells of C ∪ D are near the law in a_l1 (×3.3), and the interiors of
  the long spells carry its slow part: 0.281 → 0.193, ×1.46. If they fell ×4 a_l1's D(2→1)
  would be 0.12ε lower, two thirds of C ∪ D's excess. E4b holds only in part: a_dG1 and the
  storage offset are slow in the short spells (×1.5, ×2.4); their interior parts are near zero
  at level 2 and change sign.
- Height-linked quantities (a_l1, hmat) and lnJ are slow in the interiors; the light group is
  not (×5). Fifteen replays so far, beyond the ~10 budgeted: each split was needed to tell the
  remaining candidates apart.

## Pre-registration E5 (the a_l1 integrand along birth date)

Two forward runs on level 2's steps and nodes, one at a_l1 × 1.01: per node, Δ ln nrr / 0.01 is
the fate part of a_l1's integrand at 13–27 d spacing.

| | prediction | confidence |
|---|---|---|
| E5a | inside the long spells of C ∪ D the integrand has a feature narrower than level 1's spacing (a jump or kink: a second difference at least 5× its panel's median) | 50% |
| E5b | the integrand is smooth in A, E and the end zones (no such feature) | 60% |

## E5. a_l1's integrand along birth date (`epi_fd.R`, `epi_fd2.R`) [m]

The base forward run on level 2's steps reproduces level 2's J to ten digits. Per node, the
relative change of nrr with ln a_l1 (1% forward difference, pinned steps):

- Inside the long spells of C ∪ D it has single-node features against a smooth trend: a spike
  of +0.31 at 17.03 y (the panel's other second differences are ≤ 0.03), a −0.10 dip at
  13.21 y, a step of +0.05 at 10.62 y, and a wiggle over 13.91–14.06 y.
- nrr itself carries the 13.9–14.1 y feature (second differences of ln nrr +0.032, −0.019,
  −0.018, +0.020 on 27-d spacing, against a trend of ±0.005), and at the nodes level 1 and level
  2 share, ln nrr's second differences agree to 0.0004: the feature is in the cohorts' fate, not
  run-to-run noise. Level 2 moves ln nrr against level 1 by a smooth 0.013–0.022.
- Such features are not confined to C ∪ D: A's last weeks (2.95 y), B's interior (5.44 y) and
  21.8–23.7 y show them too. E5a holds; E5b fails. A one-node spike in a forward difference on
  pinned steps can also be a step artifact (a cohort's event moving off the pinned steps), so
  the spikes are weaker evidence than the nrr feature.
- Node-to-node roughness of ln nrr (|third difference| / |second difference|, level 1, long
  spells 6.6–17.7 y) is 0.87 here against 0.36–0.72 on the other four cases (`epi_rough.R`):
  the highest, but not by much.

## E6. The spell-end stretch fixed in place [m]

At level 2 the second-last added node of each panel also lies in level 1's last two intervals,
and E3 had left it in the interiors. Removing it alone on level 2's steps moves a_l1 by 0.014ε.
So the end stretch falls 0.220 → 0.061 (×3.6, on the law) and the interiors 0.281 → 0.179
(×1.57). E3's conclusion stands.

## Result

**Where the replay misses error.** a_l1's level differences (reference-free, pinned) split by
region and part of spell:

| stretch | D(1→0) | D(2→1) | ratio | excess over ×4 in D(2→1) |
|---|---|---|---|---|
| interiors of the long spells, 6.6–17.7 y | 0.281 | 0.179 | **1.6** | **0.11** |
| short spells, 6.6–17.7 y | 0.223 | 0.067 | 3.3 | 0.01 |
| spell ends and openings, 6.6–17.7 y | 0.242 | 0.069 | 3.5 | 0.01 |
| 17.7–24.5 y | 0.254 | 0.073 | 3.5 | 0.01 |
| A + B + F (unpinned difference) | 0.061 | 0.12 ± 0.09 | — | 0.10 ± 0.09 |
| all | 1.052 | 0.508 | 2.1 | 0.245 |

The replay divides each region's difference by 3, as if it fell ×4 per halving. In the
interiors of the long spells of 6.6–17.7 y, a_l1's part falls ×1.6, so the replay reads about a
third of it; lnJ and hmat are slow there too (×2.4, ×1.65), the light group is not (×5). The
spell ends, openings and short spells are on the law, and so are the case's own features: the
first spell (A) and the spell closed by the 2.3-d gap (B) carry 0.1ε of the difference between
them, and t_r sets only the end zones, which fall ×3.6.

**Why.** Those interiors sit at equal shares of an ungraded density (54–108 d at half-scale
level 0, 27–54 d at level 1). The cohorts' fate there has features 30–60 d wide (13.9–14.1 y in
nrr, and in a_l1's integrand), real and at fixed birth dates. While the spacing is comparable to
a feature, the error from it is set by where nodes fall around it and does not fall ×4 per
halving; the three half-scale levels and scale 1 (194 nodes, less error than level 1's 232) all
sit in that range. Partly established: the location and the rate are measured; that these
features cause the rate is supported but not isolated, and what makes them (where in the cohorts'
lives the fate turns) is not traced.

**The read on libNS is not this case's alone.** On libNS the reads are dry 0.62, dry-flat 0.65,
epi-adG208 0.61, episodic-lma 0.95 (long-wet has no quantity over 0.2ε): r_min = 0.82 no longer
holds on three of four. Every quantity is still covered (47/47, margin ≥ 0.18ε): the miss is
absorbed by u_q = 0.33, which was budgeted for the tolerance and the short spells, not for this.

## The fix

Smallest, on the estimate: **r_min from the libNS cases, 0.61** (`MIN_ESTIMATE_RATIO`; no other
change). The estimate then reads honest on all five libNS cases. Worst bounds on libNS at
u_q = 0.33 (`scratchpad/epi/rmin.R`): dry 0.74 → 0.88, long-wet 0.57 → 0.66, dry-flat 0.54 →
0.61, epi-adG208 0.71 → 0.85, episodic-lma 0.96 → **1.18**. Cost: episodic-lma rejects at pass 1
and runs level 1 (about +540 s on 453 s, 2.2× its CPU); the other three accept as before. On
libS the same change would also reject dry-flat (0.87 → 1.06).

Does it generalise? No. r_min is the lowest read of five cases, and the part it absorbs grows
with how much fate structure the long spells hold at the interior spacing, which the next record
or trait can raise. The general form takes the interiors' part at first order: split the replay
into two that partition the removed nodes (interior added nodes; ends, openings and short
spells), additive within 0.018ε here, and divide the interiors' difference by 1 instead of 3.
Here that reads a_l1 at 0.82 at half-scale level 1 (0.54 against 0.66). It assumes nothing about
the record, but costs a second replay on every pass 1 (about 0.6 run, +35% of run plus replay)
and raises the bound by two thirds of the interiors' difference where interiors are on the law;
neither the interiors' share nor the resulting rejections are measured on the other cases.

Not recommended: grading the interiors finer. Their part falls ×1.6 per doubling, so refining
there buys little error per node and does not make the estimate honest.

## Next test (if the cause is to be closed)

One region-mixed replay pair on dry or dry-flat (libNS reads 0.62, 0.65): interiors of the long
spells only, on levels 1 and 2 of a half-scale fit. If their interiors fall ×1.5–2 as here, the
under-read is general and the split estimate is the fix; if ×4, the low reads have another seat
and r_min is only absorbing it.

## Scored

E1a holds; E1b fails as worded (two regions, C ×2.6 and D ×1.9); E1c fails (B carries 0.10).
E2a holds on the line; E2b holds for E, fails for D; E2c fails narrowly (within step noise).
E3a fails (ends ×4.7, ×3.6 once fixed in place); E3b fails (the rest is slow); E3c holds. E4a
holds; E4b holds in part. E5a holds; E5b fails.

Cost: 16 pinned replays (six on level 1 at 290–310 s, ten on level 1 or 2 at 300–610 s CPU) and two
forward runs (146–149 s), one SCM process at a time, with the coordinator's two loops sharing
the four cores. Over the ~10 budgeted: E3, E4 and E6 each split the remaining candidates, and
E6 corrected E3's zone accounting.
