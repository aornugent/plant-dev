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
