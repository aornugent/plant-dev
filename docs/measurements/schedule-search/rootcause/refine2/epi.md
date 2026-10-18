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
