# Closing edges: why the strip's error is not second order in spacing (systematic debugging)

Subject: the node-schedule error just before closing establishment edges in TF24 on the
birth-date coordinate, under P's inset rule (each edge node 12 d into its spell). Method:
`.claude/skills/systematic-debugging/SKILL.md`, one hypothesis at a time, each prediction
written here before its run. Scripts are in this directory; run outputs and logs are in
`scratchpad/deep/rootcause/closing/` (`runs/`, `sched/`, `logs/`, `*.log`). Every run uses
the E6 committed setting (`adj_run_nk.R` on `adjmap/libS`, KNOTS=0, TOL 1e-4, one_nk.sh's
environment), two at a time at most. Errors are in each quantity's ε against the lib19-class
reference (`rootcause/common.R`); "along M" is the projection on P's unit direction.
**[m]** measured, **[i]** inferred.

## Starting point (saved runs, `q0_base.R`) [m]

| case | run | n | rms | worst | along M | off-M rms | ln J |
|---|---|---|---|---|---|---|---|
| dry | coarse x (19.2 d) | 110 | 0.216 | 0.53 | +0.29 | 0.212 | −0.24 |
| dry | coarse x, 12 d | 113 | 0.248 | 0.80 | −0.45 | 0.239 | −0.42 |
| dry | committed c (12 d) | 149 | 0.159 | 0.35 | −0.30 | 0.152 | −0.15 |
| dry | check f (7.5 d) | 219 | 0.090 | 0.26 | −0.39 | 0.069 | −0.08 |
| dry-p50 | x / x12 / c / f | 113/118/153/222 | 0.223/0.305/0.141/0.058 | | −0.30/−1.15/−0.42/−0.24 | | |
| dry-flat | x / x12 / c / f | 162/169/191/258 | 0.429/0.475/0.184/0.099 | | −0.26/−1.24/−0.10/−0.34 | | |
| long-wet | x / c / f | 117/157/234 | 0.233/0.093/0.040 | | +0.25/−0.02/−0.04 | | |

On every case the leaf group (a, curv_fact_elec_trans, k_I, jmax_25) carries the largest
single errors of c, with M's quantities next.

Committed anatomy (`lib.R closing_anatomy`) [m]: on dry the spells after b1 end in a last
interval of median 57 d (the long wet-season spells 55–109 d) before the 12-d inset node;
47 closing edges after b1, gaps median 25 d. dry-flat: 92 closing edges, spells median
42 d, last interval median 39 d. long-wet: 50 closing edges, last interval median 45 d.
So the spell-end interval is 3–9 times P's layer width (~10–20 d).

## Q1. Locate: how much of the committed error sits at the closing edges

Runs (`mk_q1.R`, `run.sh`), each a variant of the case's committed insk schedule:
- **bisC**: each spell's last interval before a closing edge (after b1, before 25; inside
  the spell) bisected. dry +27 nodes, dry-p50 +29, dry-flat +53, long-wet +41.
- **res**: each closing-edge region resolved: the last 36 d of each spell (all of it when
  shorter) re-noded at c − {36, 28, 21, 15.5, 11, 7.5, 4.5, 2, 0} d, plus c + 2 d, plus
  zero-weight gap probes at c + 5 and c + 10 d where the gap exceeds 25 d. Nodes: dry 533,
  dry-p50 544, dry-flat 880, long-wet 605. Short spells are resolved whole, so their
  opening sides move too.
- **res2x** (dry only): the same with every other offset, c − {36, 21, 11, 4.5, 0} d,
  342 nodes: a check on res's own residual (if second order there, res2x − res ≈ 3× res's
  residual).

The region's error in c is then −(res − c), with no order assumed; a bisection's error is
read the usual way, −4/3 × (bisC − c).

### Pre-registration Q1 (before any run)

- **Q1a.** On dry, the closing regions carry most of c's error along M: −(res − c) along M
  between −0.15 and −0.45 (c's own is −0.30) — 60%. Their share of c's squared error (by
  projection) 15–50% — 55%; the founders' leaf error keeps the rest.
- **Q1b.** dry-p50 as dry (along M −0.25 to −0.55, c −0.42) — 55%. dry-flat: share
  ≥ 30% (92 closing edges, short spells) — 50%. long-wet: share ≤ 25% and |along M| ≤ 0.1
  — 65%.
- **Q1c.** The bisection misreads the region: on dry, −4/3 × (bisC − c) along M lies
  outside [0.7, 1.4] × the region's error along M (−(res − c)) — 60%. Reason [i]: the
  spell-end interval is 3–9 layer widths wide, so its error is not in the asymptotic h²
  range, and the 12-d strip, which bisC does not touch, is a fixed part.
- **Q1d.** res2x − res along M is under 0.1 in size on dry (res converged to ≲ 0.03) —
  70%.

## Q2. Mechanism: the shape of fate near a closing edge

Phase-1 evidence so far (no new run):
- **The gate** (`tf24_strategy.h`, `establishment_probability`) [m, code]: a newborn
  establishes with pr = 1/(1 + (a_d0·A_seed/P)²) while its birth-size net production P > 0,
  else 0. The gate shuts where the soil has dried enough that P reaches 0, and pr falls to
  zero continuously (∝ P² near the shut) over the last days before it.
- **Pooling fates across saved runs fails late in the record** (`q2_pool.R`) [m]: past
  b ≈ 15 a run's late field moves its late cohorts' ln nrr by up to +1.2 (insx against
  insk, same births), so fates from different schedules cannot be pooled into one curve.
  Early edges pool cleanly; at b = 4.59 and 6.49 ln nrr rises steadily over the spell's
  last 50–70 d (6.49: −0.03 at −72 d, +0.07 at −36, +0.15 at −12, +0.22 at the edge, +0.30
  10 d into the gap), steepening toward and through the edge. One curve per run is needed:
  res gives it (one field, nodes 2–7 d apart near each edge).

The interval error, derived (own part only, the hat over exact counts) [i]: write the
inset node x_k = c − d, the spell's last interval [x_k − h, x_k] and the gap interval
[x_k, x_k + D] (D = gap + both insets), with g = the recruit's fate (times patch density)
expanded at x_k as g_k + g1·s + g2·s²/2, σ = the gap chord's slope (g(x_k + D) − g_k)/D, and
pr the establishment rate:

  E(h, d) = −pr·g2·h³/12  +  pr·[(g1 − σ)·d²/2 + g2·d³/6]  +  ramp terms
            (spell's last interval)   (strip [c − d, c], read on the gap chord)

The ramp terms come from pr falling to zero over the last ℓ days, which removes about
pr·(g1 − σ)·ℓ·d from the strip: a term linear in d. Consequences, if g is a polynomial on
the scale of h and d:
- edge node (d = 0): E = −pr·g2·h³/12 per edge (the end interval only);
- fixed d: a constant (the strip, A2) plus h³: no single power;
- d ∝ h: E ∝ h² in the strip, h³ in the end interval: clean second order, unless g's
  curvature scale (the layer, if any) or ℓ is not small beside h and d.
So the derivation predicts the scaled inset (H1's 19.2 d) would be second order on a
smooth fate; H1 saw it fail. Either fate is not smooth on the scale of h (a layer of
width w < h), or the ramp's linear term matters, or the field part dominates.

### Pre-registration Q2 (before the res runs are read)

- **Q2a (shape).** On dry's long spells (> 60 d), ln nrr's slope steepens toward the
  closing edge: the slope over [−11, −2] d exceeds that over [−36, −11] d by ≥ 1.5× (55%);
  a near-kink (the steepening confined to the last 2 d) — 15%; no steepening (fate locally
  linear on 36 d; the curvature is on the record's scale) — 30%.
- **Q2b (gap side).** The gap probes keep rising past the edge (slope over [0, +10] d
  positive on most long-gap edges), as P's +0.065 — 75%.
- **Q2c (ramp).** pr at c − 2 d is still ≥ 0.5 of its spell mean on most edges (the ramp
  ℓ is a day or two) — 65%.

### Q2 results, part 1: the shape (`q2_fate.R dry`, on cl_res_dry's forward run) [m]

- **Fate is smooth and convex through the closing edge, with no kink and no thin layer.**
  On dry's 24 long spells (> 60 d) the curvature of ln nrr is positive on 23 (k_far,
  over [−23.5, −6.5] d, median 0.91e-4 per day²) and grows toward and past the edge
  (k_edge over [−6.5, +5] d, median 2.5e-4, 1.84× k_far, n 12 with gap probes). The slope
  is continuous through c: e.g. b = 6.49, 1e-3/d: 4.0 over [−36, −11], 6.2 over [−11, −2],
  7.25 over [−2, 0], 8.0 over [0, +10]; b = 14.45: 1.4, 4.1, 5.8, 7.2.
- Two kinds of edge [m]. Before a long gap (> 30 d) fate rises and keeps rising into the
  gap (s_gap 4.6–8.0e-3/d); before a short gap (< 25 d) fate falls through the spell and
  flattens at the edge (13.67: −2.4 → −0.27 → +0.19). Both convex. The slope changes by
  its own size over about 20–45 d (slope / curvature), so fate's polynomial scale is
  20–45 d [i].
- **Q2a scored:** steepening ≥ 1.5× on the rising edges (4.59, 12.59, 14.45, 15.44, 17.52,
  18.46, 21.66, 22.63; 6.49 at 1.54) but not as a "near-kink" and not on the falling
  edges, where the slope flattens instead. The registered alternatives were wrong-shaped:
  the right statement is "convex everywhere, curvature rising toward the edge, scale
  20–45 d". Partly holds (the ≥ 1.5× steepening on rising edges); the near-kink (15%) is
  refuted; "no steepening" (30%) is refuted.
- **Q2b holds** [m]: on all 12 long-gap edges fate keeps rising past c (s_gap > 0).
- **Q2c holds** [m]: the pilot's pr at c − 2 d is median 0.74 of its spell mean, at
  c − 1 d 0.20, at c − 0.5 d 0.11: the ramp ℓ is 1–2 d.

Consequence for the derivation [i]: with fate convex on a 20–45 d scale, the spell's last
interval (committed 55–110 d on dry, 1.2–5× that scale) is pre-asymptotic: its error is
not −pr·g2·h³/12 with one g2, and changing h moves which part of the curving fate it spans.

### Pre-registration Q2d (physics; one forward run, `traj.R` on the fate map `mk_map.R dry`)

The fate map: committed insk dry with each long spell's last 120 d noded every 3 d (the
edge a node) and zero-weight probes every 5 d through the gap; 1172 nodes, forward only.
`traj.R` keeps the cohorts born within [c − 40, c + 12] d of four edges (6.49 and 14.45
rising, long gaps; 13.67 and 16.49 falling, short and mid gaps): height, mortality, storage,
offspring by age, and soil water by calendar day.
- **Q2d.** On the rising edges, at least 60% of the ln nrr gain from birth at c − 36 d to
  birth at c is already in survival (cumulative mortality) by 30 d after the gap ends: fate
  is set in the first dry season — 50%. Growth (a height difference that persists to
  reproduction) carrying most of it instead — 35%.
- **Q2e.** Cohorts born later in the spell end the gap with *more* storage relative to
  their size than those born 36 d earlier (they spent less of the drought respiring a
  grown seedling) — 45%.

### Q1 results, dry (`q1_score.R`) [m]

| | rms | along M | leaf rms | hyd rms | ln J | share of e_c² | top |
|---|---|---|---|---|---|---|---|
| e_c (committed) | 0.159 | −0.30 | 0.274 | 0.205 | −0.148 | | a −0.35, curv −0.33, k_I −0.32, root_P50 −0.31 |
| region −(res − c) | 0.085 | **−0.28** | 0.028 | 0.201 | −0.068 | **−23%** | root_P50 +0.34, omega −0.27, root_c −0.17, stem_c +0.17 |
| −4/3 (bisC − c) | 0.091 | −0.41 | 0.054 | 0.220 | −0.098 | −7% | root_P50 +0.40, omega −0.27, root_c −0.19, a_l1 +0.13 |
| e_res (res's own error) | 0.209 | −0.02 | 0.269 | 0.382 | −0.080 | | root_P50 −0.64, omega +0.42, TF24_cost_scale +0.39, stem_c −0.39 |

- The closing regions carry all of c's error along M (−0.28 of −0.30) and none of its leaf
  error (leaf rms 0.028 against 0.274). Q1a: along M holds; the share (registered 15–50%)
  is **refuted in sign**: −23%. The regions' error is anti-aligned with the rest of c's
  error (cos(region, e_c) −0.42): in root_P50, omega, root_c and TF24_cost_scale the
  closing regions cancel part of the rest of the schedule's error (resolving them takes
  root_P50 from −0.31 to −0.64).
- Q1c: −4/3 (bisC − c) along M is 1.46× the region's: outside [0.7, 1.4], so it holds as
  registered, but only just; per quantity the bisection reads the region well (cos 0.89;
  root_P50 0.40 against 0.34, omega −0.27 against −0.27). It misses stem_c (0.00 against
  0.17) and adds a_l1 (+0.13).
- Whether e_res's hydraulic error (root_P50 −0.64, stem_c −0.39, TF24_cost_scale +0.39) is
  real error elsewhere in the schedule or res's own (step jitter at the many new cohorts
  born on the drying edges; D1) is open until res2x.

### Q2 results, part 2: the physics (`q2_phys.R` on traj_map_dry, 1172 nodes, forward) [m]

Cohorts born at c − 36, −21, −12, −3, 0 d and gap probes c + 2, 7, 12 d, four edges.
- **Fate near a closing edge is the seedling's survival of the coming drought.** On the
  rising edge b = 6.49 (gap 65 d) ln nrr gains +0.171 from birth at c − 36 d to birth at c.
  Cumulative mortality: by c + 15 d 0.019 vs 0.003 (both small), by the gap's end 0.467 vs
  0.337, 30 d after it 0.532 vs 0.382, at 1 yr 1.010 vs 0.773. So 0.150 of the 0.171 (88%)
  is in survival by 30 d after the gap; height at 3 yr is *lower* for the early-born
  (2.32 vs 2.39). b = 14.45 (gap 75 d): ln nrr +0.08, mortality by gap + 30 d 0.583 vs
  0.422 (−0.16, the survival gain is twice the fate gain; the early-born keep a height
  lead, 0.343 vs 0.316 at the gap's end, which pays back part of it). **Q2d holds.**
- Why later-born survive the drought better [m + code]: mortality is
  d_I + a_dG1·exp(−a_dG2·r) with d_I 0.01, a_dG1 5.5 /yr, a_dG2 20, r the relative reserves;
  a newborn is seeded at r = a_st3 = 0.8, where the storage term is 6e-7 /yr. Hazard turns
  on only once reserves fall below r ≈ 0.15 (e-fold 0.05). As the soil dries (top layer
  0.25 → 0.14 over the spell's last 60 d at b = 6.49) the newborn's net production falls
  to zero, which is exactly where the gate shuts (the same birth-size production). An
  older seedling enters the drought having spent reserves under marginal production, so
  its hazard turns on earlier; a seedling born at the shut starts with r = 0.8 and must
  draw it down first. At c + 15 d later-born cohorts hold more storage despite being
  smaller (b = 6.49: 3.3e-8 at h 0.343 born c − 36 d; 4.5e-8 at h 0.314 born at c; 1.8e-7
  born c + 12 d), on all four edges. **Q2e holds at c + 15 d** (by the gap's end every
  cohort is near empty, 1–4e-8). In the gap the hazard reaches ≈ 2.9 /yr (fate slope
  8e-3 /d ⇒ r ≈ 0.03).
- So the slope of fate in birth date is the difference in drought hazard a later birth
  escapes, and its **curvature is how fast that advantage grows as birth nears the
  drought's onset: set by the reserve-depletion time under marginal production, tens of
  days** (slope/curvature 20–45 d, Q2 part 1). On short gaps (13.67, gap 14 d) the drought
  is too short to matter (mortality at 1 yr 0.755 vs 0.766) and the early-born's growth
  lead (height at 1 yr 0.768 vs 0.726) makes fate fall instead; convex there too.
- This is a property of the record and the seedling's reserve dynamics, smooth in b:
  not a near-kink at c, and not set by the gate's ramp (1–2 d).

### Q2 results, part 3: the derivation checked (`q2_model.R dry`) [m on the fate map, i for the reading]

The closing side's own error on 10 long-spell edges (those where the committed spell's
last interval lies inside the map; zone [p, c], p the node before the inset, Z median
74 d), computed by quadrature of pr·(G − G_lin) on the splined fate G = density·nrr:
- **The closed form fails where the interval spans the curved zone.** With one interval
  [p, c − d] and the gap chord, at d = 0 the formula gives −0.058 ε against the
  quadrature's −0.011; at d = 7.5 −0.041 vs −0.0064; they meet only for d ≥ 19 (d = 36:
  −0.0101 vs −0.0101). The h³ term uses g2 at c − d, but g2 there is 2–3× its mean over a
  74-d interval: h is past fate's curvature scale, so no single power of h describes it.
- **The own part is small**: ln J's own closing-side error is ≈ −0.005 ε at the
  committed layout, against the measured region's ln J −0.068 ε. The region's error is
  carried by the field (the strip cohorts' leaf area and water use, whose integrands in b
  share fate's drought-survival shape [i]) and by the elasticities' integrands, not by
  fate itself. The derivation therefore fixes the structure (which terms, which powers),
  not the size.
- The structure, as a ladder in the zone (own part, close side):
  - inset rule (d = 12r, end interval ≤ r·h_end), r = 1.6, 1, 1/1.6: x/c **1.07** (square
    law 2.56), c/f **2.96** (2.56);
  - the edge a node and [p, c] cut into n = 2, 3, 5 equal intervals: x/c **1.97** (2.25),
    c/f **2.88** (2.78).
  - the count-kept d-scan's move p(d)/p(10): 0.42 (3 d), 0.86 (7.5), 1.06 (12), 1.07 (15),
    0.98 (19.2), 0.15 (36): it saturates by 10–15 d as P's measured p(3) 0.25, p(10) 1
    along M did, then turns back as the strip's chord error grows.

### Q1 results, dry-p50 [m]

| | rms | along M | leaf rms | hyd rms | ln J | share | top |
|---|---|---|---|---|---|---|---|
| e_c | 0.141 | −0.42 | 0.267 | 0.118 | −0.158 | | a −0.35, curv −0.33, k_I −0.31, jmax_25 −0.27 |
| region −(res − c) | 0.104 | **−0.23** | 0.024 | 0.231 | −0.029 | **−12%** | omega −0.40, root_P50 +0.33, a_r1 +0.21, stem_c +0.20 |
| −4/3 (bisC − c) | 0.116 | −0.48 | 0.055 | 0.279 | −0.062 | +9% | omega −0.50, root_P50 +0.42, a_dG2 +0.18 |
| e_res | 0.188 | −0.19 | 0.272 | 0.280 | −0.129 | | omega +0.42, root_P50 −0.42, a_r1 −0.37, TF24_cost_scale +0.37 |

As dry: the regions carry a hydraulic error (no leaf part) that opposes the rest of the
schedule's (cos(region, e_c) −0.16; dry −0.42); the bisection reads its direction (cos
0.92) at 1.2–1.3× its size. Q1b (along M −0.25 to −0.55): −0.23, just outside — fails
narrowly. The two cases' e_res share a pattern (root_P50 −, omega +, a_r1 −,
TF24_cost_scale +): one schedule-level residual, not independent jitter [i].

### Pre-registration Q3 (before long-wet's and dry-flat's res are read)

- **Q3a.** long-wet's closing regions carry little: |along M| ≤ 0.1 and rms ≤ 0.05 — 60%.
- **Q3b.** long-wet's fate is flatter near its closing edges: median curvature k_far on
  long spells ≤ 0.5× dry's 0.91e-4 /d² — 55%. Reason [i]: its gaps are short (median 18 d
  before the edges after b1), so the drought-survival advantage of a late birth has little
  to build on, and its spells' last intervals are shorter (median 45 d).
- **Q3c.** dry-flat's regions carry a larger share than dry's (92 closing edges, short
  spells): region rms ≥ dry's 0.085 — 60%.

### Q3 results, part 1: long-wet against dry (`q1_score.R`, `q2_fate.R long-wet`, `q3_pattern.R`) [m]

| case | closing edges after b1 (long) | gap med (long spells) | establishment in last 36 d / 12 d | h_end med (long) | fate curvature k_far | region rms | region along M | region hyd rms |
|---|---|---|---|---|---|---|---|---|
| dry | 47 (24) | 26 d | 0.18 / 0.067 | 64 d | 0.91e-4 | 0.085 | −0.28 | 0.201 |
| dry-p50 | 50 (24) | 19 d | 0.18 / 0.067 | 65 d | — | 0.104 | −0.23 | 0.231 |
| long-wet | 50 (28) | 23 d | 0.25 / 0.084 | 61 d | **1.52e-4** | **0.019** | −0.10 | 0.038 |
| dry-flat | 92 (35) | 15 d | 0.38 / 0.148 | 53 d | — | (running) | | |
| wet-adG2, episodic, long drought | 53, 29, 52 | 24, 43, 17 d | 0.26, 0.15, 0.24 / 0.09, 0.04, 0.08 | 66, 66, 65 d | — | — | | |

long-wet: e_c rms 0.093, along M −0.02; region −(res − c) rms 0.019, along M −0.10,
ln J −0.027, share +3%; −4/3 (bisC − c) rms 0.024, along M −0.12. Fate: curvature positive
on 28 of 28 long spells, k_far 1.52e-4 (dry 0.91e-4), k_edge 2.66e-4.

- **Q3a holds** (|M| 0.10 at the bound, rms 0.019 ≤ 0.05).
- **Q3b refuted**: long-wet's fate curves *more* near its closing edges than dry's, and
  the geometry (gaps, spells, last-interval width, establishment near the edges) is
  alike or larger. So neither the edge's sharpness, the spell length, nor fate's curvature
  scale against the spacing separates the records. ln nrr's curvature is not what the
  region's error is made of (as the own-part computation already showed: 0.005 ε).
- The region's error lives in the hydraulic quantities on dry (hyd rms 0.20–0.23 against
  leaf 0.02–0.03) and is 5× smaller on long-wet. The quadrature integrand that matters is
  therefore the closing-edge cohorts' *sensitivity* to hydraulic traits, not their fate.

### Pre-registration Q3d (two forward finite differences per case on the fate maps)

H3: on dry the per-cohort sensitivity of fate to a hydraulic trait (d ln nrr_j / d ln
root_P50, field included) curves sharply over the last weeks before closing edges,
because there the drought-survival term (reserves → hazard) is what root_P50 acts on; on
long-wet it is small and flat there. Runs: the fate map schedule (spells' last 120 d at
3 d, the edge a node, gap probes) for dry and long-wet, base and root_P50 × 1.02, forward
only (`adj_run_nk.R`, FORWARD=1).
- **Q3d.** Over the last 36 d of long spells, the second difference of d ln nrr / d ln
  root_P50 in birth date (per day², median |·|) is ≥ 3× larger on dry than on long-wet —
  60%. And on dry it is concentrated near the edge (its median |curvature| over the last
  12 d ≥ 2× that over [−36, −12]) — 50%.

### Q1d result: res is converged in the regions [m]

res2x − res on dry: rms 0.022, along M +0.06, ln J −0.006 (stem_c +0.07 the largest);
−(res2x − c) along M −0.34 against res's −0.28. **Q1d holds.** The region error is solid
to ≈ 0.03, and e_res's hydraulic error (root_P50 −0.64, omega +0.42, TF24_cost_scale
+0.39, stem_c −0.39) is real error elsewhere in the committed layout (opening strips,
founders, interior), not jitter. So **c's small hydraulic error on dry is a cancellation
between regions**: the closing regions (+0.34 root_P50, −0.27 omega) against the rest
(−0.64, +0.42). Any ladder that scales the regions at different rates moves that balance;
this alone can turn a pair's read (H1) without either part being off its own law [i].

## Q4. Hypothesis and design

### The mechanism, as it stands [i from the measurements above]

1. The closing-edge cohorts' integrands (fate, their leaf area and water use, and their
   sensitivities to the hydraulic traits) are smooth and convex in birth date, curving on
   a 20–45 d scale that grows sharper toward the edge: a seedling born later in a drying
   spell starts the drought with full seed reserves and dies later in it.
2. The inset representation reads that curved stretch with two terms of opposite sign:
   the spell's last interval (55–110 d wide, 1.2–5× the curvature scale, so
   pre-asymptotic: no single power of h; the closed form misses by 5× at d = 0) and the
   12-d strip read on the gap's chord, whose lever is the gap length (set by the record,
   not the spacing). The strip term goes as d² × gap, the end term as h³ with g2 varying
   inside the interval; their sum crosses zero at the tuned inset and has no power law in
   either h or d (own-part ladder x/c 1.07 against 2.56).
3. On dry the regions' error is hydraulic and cancels part of the rest of the layout's
   hydraulic error (Q1, Q1d), so even small departures from a law flip a pair's read.

### H4 (registered before any Q4 run)

*The edge as a node, with the spell's last stretch [p, c] cut into N equal intervals, N
scaled inversely with the spacing, makes the closing-edge error clean second order.* No
recruit then lies on a gap chord (the gap interval holds only the gate's 1–2 d ramp
tail), so the strip term is gone; what remains is a composite hat quadrature over the
spell, which is second order once its intervals (Z/N: 37, 25, 15 d for N = 2, 3, 5 at
Z ≈ 74 d) sit near or under the curvature scale. The cost is N − 1 nodes per long-spell
closing edge over the inset (dry: 27 zones, committed rung +54 nodes, 149 → 203).

Test (`mk_q4.R`, strip only; everything outside the zones is the committed layout):
- proposed ladder edg2 / edg3 / edg5 (coarse 1.5×, committed, fine 1/1.67×);
- the inset rule's strip-only ladder: insx (19.2 d), the committed run (12 d), insf
  (7.5 d, last interval split at ≤ h_end/1.6);
- the zone reference resZ: the edge a node and [p, c] in 15 intervals (~5 d).
Each rung's zone error is Q(rung) − Q(resZ), in ε.

### Pre-registration Q4

- **Q4a (the law).** On both dry and dry-p50, the proposed ladder follows the square law
  along M: e(edg2)/e(edg3) within [1.6, 3.2] (law 2.25) and e(edg3)/e(edg5) within
  [2.0, 3.9] (law 2.78), with the three errors along M of one sign — 55%. Per quantity,
  the projected ratio ⟨e2, e3⟩/|e3|² within the same bands and cos(e2 − e3, e3 − e5)
  ≥ 0.8 — 45%.
- **Q4b (the inset fails at the strip alone).** The inset ladder's e(insx)/e(c) along M is
  under 1.6 or of opposite sign on at least one of the two cases — 65%.
- **Q4c (size).** edg3's zone error along M is at most 0.6 in size (the a09 edge node with
  one interval carried ≈ 1.2–1.8 along M on lib19) — 55%; at most the inset's own
  committed zone error in size — 30%.

### Q1 results, dry-flat, and the four cases together [m]

dry-flat: e_c rms 0.184, along M −0.10, root_P50 −0.44; region −(res − c) rms 0.054,
along M −0.20, hyd rms 0.124 (root_P50 +0.19, omega −0.18, a_dG2 +0.11, stem_c +0.10), ln J
−0.035, share −2%; e_res root_P50 −0.63. −4/3 (bisC − c): rms 0.074, along M −0.37
(root_P50 +0.25, omega −0.20, storage_relaxation_offset −0.18, a_l1 +0.14).

| case | e_c along M | region along M | region rms | region share of e_c² | bisC read: cos / projected ratio / M ratio |
|---|---|---|---|---|---|
| dry | −0.30 | −0.28 | 0.085 | −23% | 0.89 / 0.95 / 1.47 |
| dry-p50 | −0.42 | −0.23 | 0.104 | −12% | 0.92 / 1.03 / 2.05 |
| dry-flat | −0.10 | −0.20 | 0.054 | −2% | 0.89 / 1.22 / 1.89 |
| long-wet | −0.02 | −0.10 | 0.019 | +3% | 0.84 / 1.08 / 1.13 |

- **How much of the committed error sits in the closing-edge regions:** along M, most of
  it on dry (0.28 of 0.30) and dry-p50 (0.23 of 0.42), more than all of it on dry-flat
  (−0.20 of −0.10) and long-wet (−0.10 of −0.02); of the squared error, none (shares −23%
  to +3%). The regions' error is hydraulic (root_P50 +, omega −, root_c −, stem_c +) and
  opposes a larger hydraulic error elsewhere in the layout (root_P50 −0.42 to −0.64 after
  the regions are resolved, on all three dry-type records). The leaf error that dominates
  every committed run (a, curv_fact_elec_trans, k_I) is not at closing edges (region
  leaf rms 0.02–0.03).
- dry-flat's root_P50 −0.44, which A2 attributed to the 12-d strips, does not come from the
  closing strips: resolving them takes it to −0.63 [m]. The opening strips or another
  region carry it [i, not tested here].
- **Q1b** (dry-flat share ≥ 30%) **refuted**; long-wet (share ≤ 25%, |M| ≤ 0.1) holds.
  **Q3c** (dry-flat region rms ≥ dry's) **refuted** (0.054 against 0.085).
- **The bisection, refining the last interval with d fixed, reads the region per quantity
  (projected ratio 0.95–1.22, cos 0.84–0.92)**: refining toward finer spacing behaves
  close to the square law in the bulk hydraulic quantities, as the own-part ladder's c/f
  (2.96 against 2.56) did. Its M ratio (1.13–2.05) is inflated by a_l1 and
  storage_relaxation_offset, which the bisection moves and the region does not hold.

### Q3d result: the hydraulic sensitivity integrand (`q3_fd.R`, `q3_own.R`) [m]

s(b) = d ln nrr / d ln root_P50 per cohort (field included; forward difference at ×1.02 on
the fate maps, 3-d nodes over the last 120 d of long spells, the edge a node).
- **Its shape is a turn about 10 d before the edge**, on both records: dry b = 6.49:
  −0.116 at c − 36 d rising to −0.002 at c − 12, then falling to −0.067 at c and −0.207 at
  c + 12; b = 14.45: −0.817 → −0.682 at c − 9 → −0.713 at c → −0.835 at c + 12; long-wet
  b = 7.37: 1.49 → 1.645 at c − 9 → 1.61 at c → 1.48 at c + 12. Curvature is negative
  (concave) on most of the zone (mean sign −0.77 dry, −0.58 long-wet) and concentrated in
  the last 12 d (near/far 4.0 dry, 8.8 long-wet). Its scale is ~10–15 d: shorter than
  fate's own (20–45 d), and 4–7× shorter than the committed last interval.
- **Q3d (≥ 3× larger curvature on dry) refuted**: dry/long-wet 1.85× overall (far 3.1×,
  near 1.15×). The near-edge concentration on dry (≥ 2×) **holds** (4.0×).
- **The own part of the root_P50 elasticity's zone error does separate the records**:
  committed inset layout, summed over the zones the maps cover, dry +0.026 ε (10 zones),
  long-wet +0.002 ε (16 zones): 13×, against the measured region root_P50 +0.337 and
  +0.033 (10×). Same sign, same ratio; the own part is ≈ 10–20% of the size (the field
  carries the rest, in proportion) [i]. The difference is in the sensitivity's level and
  far-zone curvature times the recruits' weight: |s| 0.71–0.79 on dry against 0.35–0.38
  on long-wet, curvature 3× over [−36, −12] d.
- With the edge a node and [p, c] in 3 intervals the same own part is −0.002 (dry) and
  −0.004 (long-wet) ε: an order smaller than the inset's on dry [m, model].

**Q3 answer.** The geometry (edge sharpness: the gate ramp is 1–2 d on both; spell and gap
lengths; last-interval width) and fate's own curvature do not separate the records. What
separates them is how strongly the closing-edge cohorts' hydraulic sensitivity curves:
on dry the hydraulic traits set the drought survival of the last cohorts, so the
sensitivity integrand has a 10–15 d turn before the edge with 2× the level and 3× the
far-zone curvature of long-wet's. The inset's committed layout sits on the strip at 12 d,
right where that turn is; on long-wet the same layout errs 10× less in root_P50, so its
non-power-law part is too small to disturb a pair.
