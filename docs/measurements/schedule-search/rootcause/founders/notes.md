# The founders' window: root cause of its schedule error

Subject: the node-schedule error carried by the earliest cohorts, born from b = 0 to about
b1 (the pilot's first closing edge), TF24 on the birth-date coordinate. Process:
`.claude/skills/systematic-debugging/SKILL.md`, one hypothesis at a time, every prediction
written here before its run or analysis.

Scripts are in this directory. Outputs and logs are in
`scratchpad/deep/rootcause/founders/` (`<script>.log`, small `*.rds`, `runs/`).
Every number is marked **[m]** (measured) or **[i]** (inferred: a fit, a derivation or a
reading of measured numbers).

## Summary (written last; the sections below are in the order they were registered and run)

**Mechanism.**
1. A founder born at b is a delayed copy of the first: it reaches 1 m exactly b later;
   the race under the earlier founders then stretches the delay 1.2–2.4× by the time it
   reproduces [m].
2. Survival runs on the calendar for everyone: the patch's disturbance hazard (0.0121·t,
   0.28–0.34/y when the founders reproduce) plus the stand's drydown mortality pulses. Later
   reproduction is discounted: 61–84% of the fall in ln nrr; lifetime seed output 11–30%;
   the founder's own extra mortality 5–10% [m].
3. So ln nrr falls nearly linearly, an exponential in nrr with L = 0.4–0.8 y (S-shaped
   on the wet and long-drought records) [m].
4. Hats in birth date make two errors from this one shape [m]:
   - J's interpolation of nrr: (h²/12)·share·⟨g′² + g″⟩ (within 5% on all ten), coarse J high;
   - the stand's water uptake, a set of convex delayed copies while the founders race:
     the hats over-count it, the soil runs drier and the drydown clock bites harder.
5. That soil part is −6% to −25% of ln J's founders' error, but half of the elasticities'
   on dry and 75–95% on episodic-lma; light is minor and opposite [m].
6. The elasticities' error is h²·∂K/∂ln θ. Its direction is a carbon-balance axis, whose
   sign follows whether extra carbon lengthens L (dry: dg′/d ln a = +1.45) or shortens it
   (episodic-lma: −0.20; lma +4.9 against −2.1). It is not set by which resource the
   founders win: the soil carries the field part on both cases [m + i].

**Use.** Simpson's rule in birth date over the founders' window, on every sum over nodes
(diagnostic patch `simpson.patch`). With 12 founders' intervals it errs 0.052 / 0.027ε
rms on dry / episodic-lma, against the committed layer's 0.135 / 0.335 with 17 / 19
intervals. That is 5–7 fewer nodes (rows −6% / −9%) and an error at the run-to-run floor,
bounded from the pilot's L as (h/L)⁴, so nothing needs to read it. Two cases only.

**Scorecard.** 31 registered predictions (A3 withdrawn as an identity before its run):
15 confirmed, 3 partly (P1 4/5, A2 3/4, C2 1/2), 13 refuted (P1b, P4, P5, P6, C3, C4,
B1, D2, D3, E3, S0, S3, S5). The refutations that changed the course were these:
- B1: the elasticities' founders' error is not mostly interpolation;
- D2: soil, not light, on dry too;
- P5/P6: the founders are 44–94% of the committed run's error on nine of ten;
- S0: libF is not libS, so both arms of the ladder were moved onto libF.

## What the code does with a founder (read before predicting)

`S_src/plant/inst/include/plant/species.h` (the libS source), birth-date path:
- Each node j carries the fate of one recruit born at b_j (its survival and offspring,
  `nrr`). Each interval [b_j, b_j+1] carries its establishment exactly: the integral of
  pr_estab against the two hat functions of the interval (`interval_shares`), split into
  the node's weight w_j (`for_each_establishment_weight`).
- J = Σ_j w_j · nrr_j · (patch density, S_D, birth rate): the establishment is exact, the
  fate is the piecewise-linear interpolant of nrr(b) between nodes. The stand's light
  (competition) and water use (consumption) are the same weighted sums of the nodes'
  per-recruit leaf area and uptake.
- So the founders' error has two parts (as `docs/measurements/creation-grid.md` found on
  long drought): an *interpolation* part, ∫E·(I_h nrr − nrr) db ≈ −Σ h³/12·E·nrr″ per
  interval; and a *field* part, the stand's light and water built from the same hats,
  which changes every member's fate.
- The schedule does not move with θ, so a run's elasticity is the exact derivative of its
  own ln J: the founders' error in elasticity k is d(err ln J)/d ln θ_k. With
  err ln J ≈ K(θ)·h², the elasticities' founders' error is h²·∂K/∂ln θ: set by how the
  error constant moves with the traits, not by its size.

A first look at per-node fate (lattice f64 runs, before any prediction was scored):
ln nrr(b) over [0, b1) is not a straight line. Dry and episodic-lma are near-exponential
(slope −1.6 to −1.9/y early on dry, −1.25/y throughout on episodic-lma); long-wet and long
drought are S-shaped in ln nrr (slope steepening from −1.3 to −2.6/y over the first year,
then flattening); episodic's decline *accelerates* over its first two years (−0.8 → −1.5/y).
nrr″ = nrr·(g′² + g″), g = ln nrr, so g″ < 0 cancels part of g′².

## Q1. Reproduce and locate

### Pre-registration (written before q1_lattice.R and the bisection runs)

Lattice founders' axis: f ∈ {8, 16, 32, 64} even nodes over [0, b1) at l = 70 (training
five; lib, 3e-5); f ∈ {32, 64} only on the held-out five. Moves d(f→2f) in ε. Founders'
error at f taken as q_f − q_∞, q_∞ = q64 + (q64 − q32)/3.

| # | prediction | probability |
|---|---|---|
| P1 | Pooled order over 16→32→64 is 1.7–2.4 on each training case | 75% |
| P1b | Over 8→16→32 at least one of long-wet, long drought is below 1.6 (S-shaped fate pre-asymptotic at h = b1/8 ≈ 0.45 y) | 50% |
| P2 | Founders' error rms at f = 16 ≥ 0.25ε on dry, long-wet, long drought, episodic-lma; ≤ 0.15ε on episodic (its fate's g″ < 0 cancels g′²) | 55% |
| P3 | cos of founders' error vectors: dry vs long drought > 0.8; dry vs episodic-lma < −0.5 | 70% |
| P4 | ln J's founders' error at f = 16 is negative (coarse J low: the field part outweighs the interpolation part) on long drought and long-wet | 55% |

Committed schedules (val_insk_c, libS, no knot stops, 1e-4), each with every founders'
interval (hi ≤ the node at b1 − 12 d) bisected and nothing else changed; founders' error
taken as −4/3 × move:

| # | prediction | probability |
|---|---|---|
| P5 | The founders' share of val_insk_c's squared error is ≤ 25% on at least 7 of 10 cases | 60% |
| P6 | episodic-lma's founders' share is ≥ 40%, the largest of the ten | 50% |
| P7 | Founders' error rms ≤ 0.3ε on every case except episodic-lma | 65% |

### Results: the lattice (`q1_lattice.R`, `q1_lattice.log`)

| case | order 8-16-32 | order 16-32-64 | eF(16) rms | eF(16) max | eF(16) ln J | eF(8)/eF(16), eF(16)/eF(32) | largest at f = 16 |
|---|---|---|---|---|---|---|---|
| dry | 1.87 | 1.96 | 0.356 | 0.54 | +0.265 | 3.69, 3.87 | a, curv_fact_elec_trans, k_I −0.53; hmat +0.51; jmax_25 −0.50 |
| episodic | 2.41 | 1.21 (moves ≤ 0.023 rms: jitter) | 0.038 | 0.13 | −0.022 | 3.45, 2.39 | a_l1, TF24_cost_scale −0.13; omega +0.09 |
| episodic-lma | 1.87 | 1.79 | 0.738 | 1.61 | +0.172 | 3.64, 3.59 | a_l1 −1.61, lma −1.53, r_l −1.31, a_r1 +1.24, TF24_cost_scale −1.22 |
| long-wet | 2.00 | 1.95 | 0.289 | 0.87 | +0.275 | 3.94, 3.88 | a −0.87, a_l1 −0.72, curv_fact_elec_trans −0.64, a_dG2 +0.54 |
| long drought | 2.01 | 1.99 | 0.290 | 0.73 | +0.217 | 3.94, 3.56 | a −0.73, curv_fact_elec_trans −0.61, k_I, a_l1 −0.51 |

All [m]. Held-out (f 32 → 64 only), eF(32) rms 0.07–0.12, ln J +0.06 to +0.12 [m].

- **The founders' error is cleanly second order** wherever it is above jitter: pooled
  order 1.79–2.01 on both steps, cos(d1, d2) 0.98–1.00, per-quantity median order
  1.81–1.96 [m]. f = 8 (h = b1/8 ≈ 0.44 y) is already on the square law.
- **On the lattice's own (16, 70) point the founders are 73–103% of the squared error on
  four cases, 5% on episodic** [m] (projection 73%, −6%, 99%, 98%, 84%).
- **ln J's founders' error is positive** on all but episodic: the coarse J is high [m].
- **Two direction families** (cos of eF, f = 32, all ten) [m]:
  - *light-capture*: dry, long-wet, long drought, dry-flat, ld-105, wet-adG2, dry-p50
    (pairwise cos 0.42–0.98): a, curv_fact_elec_trans, k_I, jmax_25, a_l1 all negative.
  - *leaf cost*: episodic-lma, episodic, ld-102 (cos 0.57–0.78 with each other, −0.38 to
    −0.83 against the first family): a_l1, lma, r_l, TF24_cost_scale negative, a_r1 and
    along M positive.

Scored:
- P1 (order 1.7–2.4 over 16-32-64 on each training case): **4 of 5**; episodic's moves are
  at the jitter floor (0.012–0.023 rms) and read 1.21. As registered, refuted on episodic,
  for a reason that is not the founders' (nothing to measure).
- P1b (8-16-32 below 1.6 on long-wet or long drought): **refuted** (2.00, 2.01).
- P2 (≥ 0.25ε on dry, long-wet, long drought, episodic-lma; ≤ 0.15ε on episodic):
  **confirmed** (0.29–0.74; 0.038).
- P3 (cos dry/long drought > 0.8, dry/episodic-lma < −0.5): **confirmed** (0.93, −0.78).
- P4 (ln J's founders' error negative on long drought and long-wet): **refuted**: +0.22
  and +0.28. The interpolation part outweighs the field part in ln J on the lattice.

A second look at per-node state (lattice f64, dry) [m]: every founder ends at the same
height (17.87 → 17.78 m from b = 0 to b1) and the same mortality integral (18.75 →
18.70–18.98), and lifetime seed output (not survival-weighted) falls only 24%; but the
survival-weighted offspring `nrr` falls 108-fold (82 → 0.76). The founders' advantage is
in *when* they reproduce relative to when they die, not in how big they get.

## Q2. The mechanism

### Pre-registration A (before q2_shape.R): shape of fate, and ln J's two parts

Per-node data from the lattice f64 runs (all ten cases) and the nested f32 ⊂ f64 pair (the
f32 founders are every other f64 node; after b1 the two schedules are the same).
J's move splits exactly into an interpolation part (the coarse hats applied to the fine
run's fates: coarse weight = w_i + (w_i−1 + w_i+1)/2 of the fine hat integrals) and a
field part (Σ coarse weight × (coarse fate − fine fate) at the shared nodes).

| # | prediction | probability |
|---|---|---|
| A1 | On all ten, ln of lifetime seed output (unweighted `fecundity`) varies by < 0.5 over [0, b1) while ln nrr varies by > 2.5: the fall is in survival-weighted timing, not size | 70% |
| A2 | The interpolation part of the founders' ln J move is larger than the field part on dry, long-wet, long drought and episodic-lma, with the field part of opposite sign and \|field/interp\| in 0.1–0.7 | 60% |
| A3 | (withdrawn before the run: on a nested pair the interpolation part *is* Σ over dropped nodes of w·(mean of neighbours' nrr − own nrr), the discrete second difference, so the match is an identity, not a test) | — |
| A4 | episodic's small ln J error is a cancellation: its interpolation part is under a third of dry's relative to J (its g″ < 0 offsets g′²), not a field part cancelling a large interpolation part | 55% |

### Results A (`q2_shape.R`, `q2_shape.log`)

[m] Shape over [0, b1) (f64 runs): ln nrr falls 3.2–6.4 across the window on all ten,
while ln lifetime seed output falls 0.21–0.50, the mortality integral at the end moves
0.3–1.8 and the final height 0.06–0.16 m. Slope by fifths of the window: dry −1.76,
−1.72, −1.38, −1.22, −0.46/y; episodic −0.87, −1.03, −1.23, −1.51, +0.12 (accelerating);
episodic-lma −1.22, −1.24, −1.18, −1.10, −0.76 (near-exponential); long-wet −2.03,
−2.22, −1.28, −1.06, −0.79 (S-shaped). L (first fifth) 0.42–1.15 y; share of J earned
before b1 0.70–0.97.

ln J's founders' move f32 → f64, split exactly (the parts sum to the move within 0.003ε) [m]:

| case | move | establishment | field | interpolation | field/interp |
|---|---|---|---|---|---|
| dry | +0.050 | −0.000 | −0.015 | +0.062 | −0.24 |
| episodic | −0.004 | +0.000 | −0.017 | +0.014 | −1.23 |
| episodic-lma | +0.032 | −0.000 | −0.008 | +0.039 | −0.20 |
| long-wet | +0.052 | −0.000 | −0.003 | +0.054 | −0.06 |
| long drought | +0.041 | −0.000 | −0.007 | +0.046 | −0.15 |
| held-out five | +0.047 to +0.088 | 0 | −0.017 to +0.003 | +0.055 to +0.104 | −0.25 to +0.05 |

- A1 **confirmed** (9 of 10 strictly; dry-flat's seed output range is 0.50, on the line).
  The fall is in survival-weighted offspring, not size.
- A2 **refuted as registered, confirmed in substance**: interpolation is the larger part
  and the field part opposes it on all four, but long-wet's ratio (0.06) is under the
  registered 0.1–0.7.
- A4 **confirmed**: episodic's interpolation part per unit share of J is 0.27 of dry's
  (its accelerating fall, g″ < 0, offsets g′²); the field part then cancels most of what
  is left.

### Pre-registration C (before the trajectory runs, `traj_run.R`)

The f64 lattice schedule run forward on libS (1e-4, the E6 setting) for dry and
episodic-lma, keeping every founder's height, mortality integral, storage and offspring
over time. Working hypothesis H_race: a later founder is a delayed copy of an earlier one,
and the delay is amplified by the earlier founders' shade or water draw; fate falls
because a common, calendar-time mortality catches later founders earlier in their
reproduction, so L = 1/(ρ · dΔ/db), ρ the relative rate at which cumulative
(survival-weighted) offspring rises with age when the mortality falls, Δ(b) the delay.

| # | prediction | probability |
|---|---|---|
| C1 | At b ≈ b1/2, the node's age at 90% of its final height exceeds node 0's by more than 1.2·b (the delay is amplified) on both cases | 60% |
| C2 | 80% of every founder's mortality integral accrues within the same calendar windows (founders born across [0, b1) reach 50% of their final mortality integral within ±1 y of each other) on both cases | 55% |
| C3 | L predicted as 1/(ρ · dΔ/db) is within 30% of the measured L (first fifth of the window) on both cases | 40% |

### Pre-registration B (before the pinned finite-difference runs, `fd_run.sh`, `q2_fd.R`)

The elasticities' founders' error is the trait derivative of ln J's. ln J's founders' move
is 75–94% interpolation on the four large cases (A2 below). Does the same hold for the
derivative? Forward runs of the lattice f64 schedule on its own build (lib, 3e-5, rain
knots as stops), every step pinned to the stored lattice run (PIN), at θ·(1 ± 0.01) for
a, lma, a_l1 on dry and episodic-lma (12 runs, plus one unperturbed guard per case that
must reproduce the stored J). The interpolation part of the f32 → f64 move is computed on
each, and its central difference is compared with the lattice's own f32 → f64 move in
that elasticity (the stored gradient runs). The remainder is the field part's derivative.

| # | prediction | probability |
|---|---|---|
| B0 | The pinned unperturbed run reproduces the stored J to 1e-9 relative (guard) | 90% |
| B1 | The interpolation part's derivative reproduces the lattice move within 30% and with its sign on at least 5 of the 6 (case, trait) pairs | 50% |
| B2 | The sign flip between dry and episodic-lma (a: −0.54 against +0.71; lma: +0.47 against −1.53 at f = 16) is carried by the interpolation part, i.e. by how the trait moves the curvature of fate, on both traits | 55% |

### Results C on dry (`q2_traj.R dry`, `q2_traj_dry.log`), and C4 registered for episodic-lma

Dry, founders born every b1/64 (`traj_dry`, libS 1e-4) [m]:

| birth | t at 1 m | t at 10 m | delay at 10 m / b | t_rep (50% of own offspring) | M(t_rep) | ln seed output | ln nrr |
|---|---|---|---|---|---|---|---|
| 0 | 0.89 | 7.99 | — | 15.26 | 6.12 | 14.93 | 4.41 |
| 0.44 | 1.33 | 8.53 | 1.22 | 16.33 | 6.67 | 14.89 | 3.66 |
| 0.88 | 1.77 | 9.39 | 1.58 | 17.39 | 7.03 | 14.85 | 2.84 |
| 1.76 | 2.67 | 11.05 | 1.74 | 19.33 | 8.36 | 14.78 | 1.44 |
| 3.09 | 4.37 | 13.08 | 1.65 | 21.99 | 9.98 | 14.68 | −0.16 |

- **A later founder is a delayed copy whose delay grows with size** [m]: it reaches 1 m
  exactly b later (no competition among seedlings until b ≈ 2.2), 10 m 1.2–1.8 b later,
  and its own reproduction 2.4 b later (t_rep 15.3 → 22.0 over b 0 → 3.1).
- **The mortality clock is the calendar's** [m]: at fixed t every founder carries nearly
  the same mortality integral (t = 12: 5.03 → 5.64); founders reach 50% of their final
  mortality at 15.6–16.9 y and 90% at 26.8 y, all of them. Mortality comes in pulses at
  drydowns (years 3, 6, 11–12, 17, 20, 23, 25), when the top soil sits at 0.128 and
  storage drains to 0.
- **So fate falls because a delayed founder reproduces later on the same mortality
  clock** [m/i]: ln nrr falls 4.57 over b 0 → 3.09; M(t_rep) rises 3.86 and lifetime seed
  output falls only 0.25 [m]. ln nrr ≈ ln(seed output) − M(t_rep) + const holds to
  within 0.5 of the fall [m].
- C1 (delay at 90% height > 1.2 b at b ≈ b1/2): **confirmed on dry** (2.31 b at b = 1.76;
  1.74 b at 10 m).
- C2 (founders reach 50% of their final mortality within ±1 y): **confirmed on dry**
  (15.55–16.89).
- C3 (L = 1/(ρ·dΔ/db), ρ the rise rate of cumulative offspring where mortality falls):
  **refuted** on dry: ρ at the founders' 50% mortality is ~0.2–0.3/y, giving L ≈ 2 y
  against 0.57. The variable is the mortality rate, not the offspring's rise. A first
  version weighting founder 0's own mortality rate by its offspring gave 0.10/y and
  g′ −0.20 against −1.77: also wrong (C4 below replaces it).

**C4 (registered now, before the episodic-lma trajectory run; fitted on dry only):**
g′ ≈ −(dt_rep/db) · m(t_rep) + d ln(seed output)/db, with m(t_rep) the founders' mortality
rate across the delay, ΔM(t_rep)/Δt_rep. On dry over b 0 → 0.44: −2.43 × 0.51 − 0.09 =
−1.33 against −1.70 measured (78%) [i]. Prediction: on episodic-lma, the same formula
over its first fifth is within 30% of the measured g′ (−1.22/y). Probability 50%.

### Results: episodic-lma's trajectory; C4 scored; the exact split of the fall (`q2_traj.R`, `q2_decomp.R`)

episodic-lma (`traj_episodic-lma`, libS 1e-4) [m]: founders reach 1 m exactly b later; at 10 m
2.0 b, at 90% height 1.2–1.9 b later. Mortality again runs on the calendar (50% of the
final integral at 14.6–17.6 y, 90% at 26.5 y for all). C1 **confirmed** (1.46 b at 90%
height, b = 1.84); C2 **refuted as written** (50% at 14.6–17.6, a ±1.5 y spread; the 10%
and 90% points agree within 0.25 y).

C4 **refuted**: on episodic-lma, t_rep moves 1.21 per unit b and M(t_rep) barely moves
(8.30 → 8.31), so the formula gives g′ −0.11 against −1.22 measured. Its premise (that the
founders' own mortality integral at their reproduction carries the fall) was wrong on
both cases: reproduction (growth surplus) and the mortality pulses (reserves drained)
fall at *different* times, so a founder's survival-weighted mean of its own mortality
rate is small (0.07–0.10/y).

What does carry the fall: the offspring rate is seed rate × exp(−M) × P(t)/P(b), P the
patch's survival (Weibull, shape 2, mean interval 11.4 y: hazard 0.0121·t, 0.28–0.34/y
when the founders reproduce, t ≈ 23–28). Splitting ln nrr_j − ln nrr_0 exactly
(sums close to 0.01) [m]:

| case, b | Δ ln nrr | lifetime seed output | when it reproduces (on founder 0's survival, P included) | own extra mortality |
|---|---|---|---|---|
| dry, 0.44 | −0.75 | −0.07 | −0.63 | −0.04 |
| dry, 1.76 | −2.97 | −0.29 | −2.52 | −0.15 |
| dry, 3.09 | −4.57 | −0.51 | −3.83 | −0.24 |
| episodic-lma, 0.46 | −0.55 | −0.12 | −0.43 | −0.00 |
| episodic-lma, 1.85 | −2.26 | −0.58 | −1.56 | −0.13 |
| episodic-lma, 3.23 | −3.76 | −1.14 | −2.29 | −0.37 |

**The mechanism of the fall** [m for the split, i for the reading]:
- A later founder is a delayed copy: same seedling growth (1 m exactly b later), then the
  delay is amplified as it grows under the earlier founders (×1.2–2.3 by 10 m and by full
  height). Its reproduction lands later in calendar time.
- Survival falls along the calendar, for everyone at once: the patch's disturbance hazard
  (0.28–0.34/y at t ≈ 23–28) plus the stand's drydown mortality pulses. So the later
  reproduction is discounted: 84% of dry's fall and 61% of episodic-lma's.
- On episodic-lma a third of the fall (30%) is lifetime seed output: the delayed founder
  never catches up (expensive leaves); on dry only 11%.
- So ln nrr falls nearly linearly (an exponential in nrr) with g′ ≈ −(delay
  amplification) × (calendar hazard at reproduction) − (seed output's fall): 1.2–1.8/y,
  L = 0.4–0.8 y on the bank (`q2_shape.log`). Its curvature g″ comes from the
  amplification changing across the window and the reproduction era moving across pulses.
- The time scale is set by the patch's age structure and the race, not by the canopy's
  closure at one time: what matters is how much later in calendar time the founder
  reproduces, and how fast survival falls then.

### Results B: the elasticities' founders' error is not mostly interpolation (`q2_fd.R`, `q2_fd.log`)

Guards [m]: the pinned unperturbed runs reproduce the stored J and every node's nrr
exactly (relative difference 0.0e+00, both cases); the pinned central differences
reproduce the stored gradient-run elasticities to 3e-4–5e-4 relative. **B0 confirmed.**

f32 → f64 move in ε, and the share of it that is the interpolation part's derivative [m]:

| case | trait | move | interpolation part | field part (rest) | interp/move |
|---|---|---|---|---|---|
| dry | a | −0.11 | −0.07 | −0.04 | 0.62 |
| dry | lma | +0.09 | +0.04 | +0.05 | 0.49 |
| dry | a_l1 | −0.04 | −0.16 | +0.12 | 3.67 |
| episodic-lma | a | +0.16 | +0.01 | +0.15 | 0.06 |
| episodic-lma | lma | −0.32 | −0.08 | −0.23 | 0.26 |
| episodic-lma | a_l1 | −0.36 | −0.07 | −0.29 | 0.19 |

- **B1 refuted** (0 of 6 within 30%). The interpolation part has the move's sign on all
  six, but on episodic-lma it is 6–26% of it: **the elasticities' founders' error there is
  ~75–95% field part**, even though ln J's founders' move is 80% interpolation (A2). On
  dry the two parts are of similar size, and for a_l1 they cancel.
- **B2 technically confirmed, but moot:** the interpolation part flips sign between dry and
  episodic-lma on a and lma; so does the field part, which is the larger on episodic-lma.
- So the field part is small in ln J (6–25%) but its trait derivative is not: in ln J it is
  a small sum, and its relative sensitivity is large (episodic-lma lma: the field part's
  elasticity contribution over its ln J value ≈ 100 [i]).
- Fate's slope does respond to the traits [m]: on dry dg′(start)/d ln a = +1.45 (more
  quantum yield flattens the fall), on episodic-lma −0.20; d g′(start)/d ln lma = −2.1 on
  dry, +4.9 on episodic-lma.

Process note: one hypothesis failed (B1), so the field part needs its own root cause
before any design that fixes only the quadrature of J.

### Pre-registration D (before the drop runs, `fd2_run.sh`, `q2_field.R`): which resource carries the field part

The lattice's build (lib) carries plant's node drop: run the fine f64 schedule with every
f64 founder that f32 lacks dropped from the *field* only (MODE=drop1: its light and/or
uptake replaced by what the coarser hats would build, to first order), pinned to the
stored f64 steps. J(drop) − J(fine) is then the field part alone, with the fine
quadrature of fate; LIGHT=1,SOIL=0 and LIGHT=0,SOIL=1 give each channel. Central
differences at θ·(1 ± 0.01) give each channel's elasticity contribution (lma, a_l1).

| # | prediction | probability |
|---|---|---|
| D0 | Guard: the both-channel drop's ln J field part matches the nested split's field part (q2_shape: dry −0.015ε, episodic-lma −0.008ε per f32→f64 move) within 30%, and light + soil ≈ both within 20% | 70% |
| D1 | On episodic-lma the soil channel carries > 60% of the field part's contribution to the lma and a_l1 elasticities | 45% |
| D2 | On dry the light channel carries > 50% of the field part's contribution to lma and a_l1 | 45% |
| D3 | The channel split's elasticity contributions add up (light + soil) to the field part from B (move − interpolation) within 25% on all four (case, trait) pairs | 60% |

## Q3. What predicts the founders' error from the pilot

### Pre-registration E (before q3_predict.R)

Measured: the lattice founders' error at f = 32 (h = b1/32), all ten. Proxies at that
spacing from the pilot (54 uniform nodes, 5 of them before b1): the a09 J-normalised
weight Σ(nrr/J)^0.6·h³, and the founders' window rule Σ 0.055·g′²·nrr/J·h³
(`localised.md`).

| # | prediction | probability |
|---|---|---|
| E1 | The founders' rule predicts \|ln J's founders' error\| within ×1.5 on 8 of 10 (ln J's is mostly interpolation) | 55% |
| E2 | rms(elasticity error)/rule spreads more than 5× across the ten, with episodic-lma ≥ 2× the others' median (the record's ×2.7) | 65% |
| E3 | Dividing also by the case's elasticity scale (rms of its elasticities in ε, which any gradient run reports) at least halves the spread and brings episodic-lma within ×1.5 of the others' median | 40% |

### Results D: the field part is the soil's (`fd2_run.sh`, `q2_field.R`, `q2_field.log`)

[m] f32 → f64 founders' field part, ε:

| case | quantity | light | soil | both (drop) | field part from B (move − interpolation) |
|---|---|---|---|---|---|
| dry | ln J | +0.007 | −0.023 | −0.016 | −0.015 (nested split) |
| dry | lma | −0.010 | +0.046 | +0.035 | +0.05 |
| dry | a_l1 | −0.037 | +0.123 | +0.086 | +0.12 |
| episodic-lma | ln J | +0.003 | −0.012 | −0.009 | −0.008 |
| episodic-lma | lma | −0.003 | −0.146 | −0.149 | −0.23 |
| episodic-lma | a_l1 | −0.005 | −0.219 | −0.223 | −0.29 |

- D0 **confirmed**: the drop's ln J field part is the nested split's within 6% (dry) and
  14% (episodic-lma); light + soil = both to the last digit shown.
- D1 **confirmed**: on episodic-lma the soil carries 98% of the field part in lma and a_l1.
- D2 **refuted**: on dry too the soil carries it (light is a fifth to a third of the soil's
  size, of opposite sign).
- D3 **refuted as registered** (within 25%): the drop accounts for 65–77% of the field
  remainder on all four pairs, always with its sign. The drop is first order in the
  field and its dropped nodes' contributions are passive; the shortfall is consistent
  (0.65–0.77), not scattered [i].

**Reading [i].** The coarse founders' hats over-count the stand's water use: a later
founder is a delayed copy of an earlier one, so during the race its uptake is a smaller,
convex-in-b version of the earlier founders'; linear hats over it over-count, the soil
runs drier, the drydown mortality pulses (the calendar clock that sets L) bite harder,
and J falls. Light enters with the opposite sign and a fifth to a third of the size.
In ln J this field part is small (−6% to −25% of the interpolation part); in the
elasticities it is half the founders' error on dry and 75–95% on episodic-lma, because
the drydown mortality's response to soil water is steep and trait-sensitive.

### How the representation turns the shape into error (`q2_derive.R`, `q2_derive.log`)

Per founders' interval of width h with establishment E (nearly uniform before b1):
∫E·(I_h nrr − nrr) db = (h³/12)·E·nrr″ + O(h⁵), nrr″ = nrr·(g′² + g″). Summed and divided
by J:

  ln J's interpolation part = (h²/12) · share_F · ⟨g′² + g″⟩ ≈ (h/L)² · share_F · κ / 12,

share_F the founders' share of J (0.70–0.97), ⟨·⟩ the E·nrr-weighted mean over [0, b1),
κ = ⟨(g′² + g″)L²⟩ a shape factor (1 for a pure exponential).
- With ⟨g′² + g″⟩ from the f64 nodes the formula gives the measured f = 32 interpolation
  part within 5% on all ten [m] (ratio 0.95–1.02).
- With one L (the first fifth's), κ = 0.79–1.15 on the near-exponential cases (dry,
  dry-p50, ld-102, ld-105, episodic-lma, episodic) and 0.43–0.62 on the S-shaped ones
  (long-wet, wet-adG2, long drought, dry-flat), whose fall is steepest early and then
  flattens [m].
- The soil field part follows the same law in h: the stand's uptake over the founders'
  window is a set of delayed copies, convex in b while they race, and the hats over-count
  it by (h²/12)·∫E·u″ at every t. Its effect on J is small and of opposite sign (6–25%),
  its effect on the elasticities is not (D).
- The elasticities' founders' error is the trait derivative of both: h²·∂(K_interp +
  K_soil)/∂ln θ. It is second order with a fixed direction per case, because the
  schedule does not move with θ [m: lattice orders 1.8–2.0, cos(d1, d2) 0.98–1.00].

**Why the direction is case-specific [m + i].** On every case the founders' error lies
along a carbon-balance axis: gain traits (a, k_I, curv_fact_elec_trans, jmax_25,
vcmax_25) on one side, cost traits (lma, r_l, TF24_cost_scale, hmat) on the other (lattice
f = 16). On dry, long-wet, long drought (and the held-out dry/wet cases) gain traits carry
a negative error; on episodic-lma (and episodic, ld-102) a positive one. The sign is the
sign of ∂K/∂(carbon surplus): on dry more quantum yield *flattens* the fall
(dg′/d ln a = +1.45 at the window's start), on episodic-lma it steepens it slightly
(−0.20) and more lma steepens it strongly (+4.9 against −2.1 on dry). It is not set by
which resource the founders win: the field part is the soil's on both cases (D), and light
is minor on both. What differs is whether extra carbon shortens or lengthens the founders'
race-and-clock (L), and on episodic-lma the soil field part's steep trait response
dominates.

### Results E: what the pilot predicts (`q3_predict.R`, `q3_predict.log`)

[m], at f = 32 on all ten:

| case | rms eF | \|ln J eF\| | founders' rule (pilot) | ln J / rule | rms / rule | rms / (rule × elasticity scale) ×100 |
|---|---|---|---|---|---|---|
| episodic | 0.016 | 0.005 | 0.016 | 0.30 | 0.96 | 1.01 |
| dry | 0.092 | 0.066 | 0.072 | 0.93 | 1.28 | 0.96 |
| long-wet | 0.075 | 0.069 | 0.098 | 0.71 | 0.76 | 1.04 |
| long drought | 0.081 | 0.054 | 0.085 | 0.64 | 0.96 | 1.24 |
| episodic-lma | 0.206 | 0.043 | 0.044 | 0.98 | 4.71 | 2.01 |
| dry-flat | 0.118 | 0.118 | 0.138 | 0.86 | 0.85 | 0.69 |
| ld-102 | 0.078 | 0.079 | 0.071 | 1.11 | 1.10 | 1.22 |
| ld-105 | 0.069 | 0.063 | 0.071 | 0.89 | 0.96 | 1.03 |
| dry-p50 | 0.119 | 0.066 | 0.072 | 0.92 | 1.65 | 1.23 |
| wet-adG2 | 0.111 | 0.095 | 0.126 | 0.75 | 0.88 | 1.24 |

- E1 **confirmed**: the pilot's founders' rule reads ln J's founders' error within ×1.5
  on 8 of 10 (0.64–1.11; episodic 0.30, long drought 0.64 just outside).
- E2 **confirmed**: rms/rule spreads 6.2×; episodic-lma sits 4.9× above the others'
  median (2.0× under the a09 J-normalised proxy, the record's "founders' error per unit
  proxy 2×").
- E3 **refuted as registered**: dividing by the case's elasticity scale cuts the spread
  from 6.2× to 2.9× (halved), but episodic-lma stays 1.9× above the median.
- **Why the proxy under-reads episodic-lma [i from m]:** the proxy is an interpolation
  model of ln J, and it reads ln J (0.98 on episodic-lma). The elasticities' founders'
  error is a trait derivative, and on episodic-lma (i) its elasticities are 1.8× larger
  than the median case's (scale 235 against 72–134) and (ii) 75–95% of it is the soil
  field part (D), against about half on dry. Neither is visible to a forward pilot. rms
  per unit ln J error is 4.8 on episodic-lma, 1.0–1.8 on eight others (episodic 3.2, where
  ln J's founders' error is near zero).

## Q4. One way to use it: a higher-order rule in birth date over the founders' window

### The hypothesis (from the mechanism)

The founders' error is two hat-quadrature errors in birth date of smooth profiles over
[0, b1): the founders' fate nrr(b) (in J) and their water uptake u(b, t) (in the soil's
depletion). Both are delayed copies of a near-exponential, with no edge inside the window
(creation is open from 0 to b1). The hats' error is (h²/12)·∫E·f″; Simpson's rule on
pairs of equal intervals cancels that term, leaving O(h⁴). plant sums every census over
nodes with one set of weights (`for_each_establishment_weight`: J, uptake, light, census),
so one change to the weights carries all of them. With the establishment of a pair
E_pair (exact, from the two intervals' shares), the correction to the trapezium weights
is (−E_pair/12, +E_pair/6, −E_pair/12): exactly Simpson when E is uniform, conserving the
establishment always.

Disposable diagnostic patch (scratch copy of the libS source, `build/plant`, installed
to `build/libF`; `simpson.patch` here): the correction applies to complete pairs from
node 0 whose far node is introduced and born at or before PLANT_SIMPSON_UNTIL (environment
variable, read once), and whose two widths are equal. Unset, the code path is the
original.

### Pre-registration S (before the patch is built or any ladder run)

Ladder, dry and episodic-lma, the E6 committed setting (libS / libF, no knot stops, 1e-4):
the committed schedule (insc) with its founders' nodes in [0, bF] (bF the inset node
beside b1) replaced by f even intervals, nothing else changed. Trapezium (libS) at
f = 6, 12, 24, 48; Simpson (libF, PLANT_SIMPSON_UNTIL = bF) at f = 6, 12, 24. Founders'
error against q∞ = q48 + (q48 − q24)/3 of the trapezium ladder.

| # | prediction | probability |
|---|---|---|
| S0 | Guard: libF with the variable unset reproduces libS's forward J bit for bit on the same schedule | 85% |
| S1 | The trapezium ladder's founders' error falls 3.3–4.7× per halving of h (order 2) on both | 75% |
| S2 | Simpson's founders' error at f = 12 is ≤ 0.25× the trapezium's at f = 12 (rms) on both | 50% |
| S3 | Simpson's founders' error falls ≥ 8× per halving from f = 6 to 12 to 24 on both (order ≥ 3) | 40% |
| S4 | Simpson at f = 12 (12 founders' intervals) errs no more (rms) than the committed founders' layer (17–19 intervals: fbis, dry 0.135, episodic-lma 0.335) | 55% |
| S5 | Simpson's founders' worst error at f = 12 is ≤ 0.15ε on both, small enough that no check needs to read it | 45% |

**S0 refuted (guard caught it).** libF with the variable unset gives J 1.2026478788 on
dry's f = 12 schedule, libS 1.20706083069: −0.37% (−0.15ε in ln J) [m]. The working tree
in `S_src/plant` is not the exact source libS was installed from (its headers predate the
libS install and its last commits were made after it). So the trapezium arm was moved to
libF too (variable unset): both arms run on one build, and the founders' error is a
difference within it. The libS trapezium f = 12 run is kept aside in `runs_libS/`.

### Results: the committed schedules (`mk_fbis.R`, `run.sh fbis`, `q1_committed.R`, `q1_committed.log`)

val_insk_c (the 12-day inset committed run, libS, no knot stops, 1e-4) against the same
schedule with its 16–21 founders' intervals bisected; founders' error = −4/3 × move [m]:

| case | committed err rms (worst) | founders' rms (worst) | founders' ln J | share (projection) | \|F\|²/\|e\|² | rest rms (worst) | cos(F, lattice eF32) |
|---|---|---|---|---|---|---|---|
| episodic | 0.129 (0.30) | 0.030 (0.09) | −0.021 | 14% | 5% | 0.114 (0.32) | +0.29 |
| dry | 0.159 (0.35) | 0.135 (0.26) | +0.102 | 60% | 72% | 0.115 (0.29) | +0.97 |
| long-wet | 0.093 (0.36) | 0.093 (0.32) | +0.137 | 90% | 101% | 0.041 (0.18) | +0.97 |
| long drought | 0.111 (0.37) | 0.087 (0.21) | +0.103 | 59% | 62% | 0.074 (0.31) | +0.97 |
| episodic-lma | 0.678 (1.28) | 0.335 (0.70) | +0.082 | 44% | 24% | 0.404 (0.75) | +1.00 |
| dry-flat | 0.184 (0.58) | 0.141 (0.36) | +0.191 | 59% | 59% | 0.116 (0.40) | +0.98 |
| ld-102 | 0.145 (0.41) | 0.101 (0.33) | +0.149 | 62% | 49% | 0.071 (0.29) | +0.97 |
| ld-105 | 0.139 (0.32) | 0.131 (0.27) | +0.120 | 85% | 89% | 0.060 (0.22) | +0.98 |
| dry-p50 | 0.141 (0.35) | 0.144 (0.24) | +0.108 | 73% | 105% | 0.109 (0.35) | +0.83 |
| wet-adG2 | 0.123 (0.44) | 0.121 (0.36) | +0.181 | 94% | 97% | 0.036 (0.16) | +0.96 |

- **Once the inset removed the closing-edge bias, the founders are most of what is left:**
  44–94% of the committed run's squared error on nine of ten (episodic 14%) [m]. (The
  record's 32% / 6% for a09's dry run was before the inset, with the edge bias at 57–67%.)
- Its direction is the lattice's (cos 0.83–1.00 on nine; episodic's is at jitter size).
- In size it is small: rms 0.09–0.14ε and worst 0.21–0.36ε on nine cases; episodic-lma
  0.34 rms, worst 0.70ε (lma, a_l1), half of its committed worst of 1.28 [m].

Scored:
- P5 (founders ≤ 25% on ≥ 7 of 10): **refuted**, 1 of 10.
- P6 (episodic-lma ≥ 40% and the largest share): **refuted** (44%, but five cases are
  higher; it is the largest in absolute size).
- P7 (founders' rms ≤ 0.3ε except episodic-lma): **confirmed** (0.03–0.14).

### Results S: the ladder (`mk_ladder.R`, `lane_ladder.sh`, `q4_ladder.R`, `q4_ladder.log`)

Both arms on libF (trapezium: variable unset, which reproduces the guard run bit for bit;
Simpson: PLANT_SIMPSON_UNTIL = bF). Founders' error against q∞ = T48 + (T48 − T24)/3, ε [m]:

| case | rule | founders' intervals | nodes | rows | rms | worst | ln J |
|---|---|---|---|---|---|---|---|
| dry | trapezium | 6 | 138 | 338 282 | 1.770 | 2.71 | +1.21 |
| dry | trapezium | 12 | 144 | 363 772 | 0.509 | 0.76 | +0.32 |
| dry | trapezium | 24 | 156 | 421 469 | 0.127 | 0.22 | +0.08 |
| dry | trapezium | 48 | 180 | 525 767 | 0.032 | 0.05 | +0.02 |
| dry | **Simpson** | 6 | 138 | 338 134 | 0.592 | 0.94 | −0.06 |
| dry | **Simpson** | 12 | 144 | 366 525 | **0.052** | 0.22 | −0.01 |
| dry | **Simpson** | 24 | 156 | 417 231 | 0.012 | 0.04 | +0.00 |
| dry | committed layer (fbis) | 17 | 149 | 389 409 | 0.135 | 0.26 | +0.10 |
| episodic-lma | trapezium | 6 | 107 | 190 273 | 3.805 | 7.82 | +0.85 |
| episodic-lma | trapezium | 12 | 113 | 209 374 | 1.111 | 2.49 | +0.24 |
| episodic-lma | trapezium | 24 | 125 | 247 121 | 0.271 | 0.66 | +0.08 |
| episodic-lma | trapezium | 48 | 149 | 322 078 | 0.068 | 0.17 | +0.02 |
| episodic-lma | **Simpson** | 6 | 107 | 191 242 | 0.250 | 0.62 | +0.05 |
| episodic-lma | **Simpson** | 12 | 113 | 211 244 | **0.027** | 0.10 | −0.01 |
| episodic-lma | **Simpson** | 24 | 125 | 248 374 | 0.052 | 0.12 | +0.02 |
| episodic-lma | committed layer (fbis) | 19 | 120 | 233 106 | 0.335 | 0.70 | +0.08 |

Reference-free reads [m]: Simpson's own moves 6→12 rms 0.56 (dry), 0.25 (episodic-lma);
12→24 rms 0.045 and 0.053, cos(move1, move2) only 0.52 and 0.69: the second move is at
the run-to-run floor (non-nested runs at 1e-4, ~0.03–0.05ε). Simpson f = 12 against
trapezium f = 48: rms 0.047 and 0.069 (T48 itself errs 0.03 and 0.07).

- S1 **confirmed**: the trapezium shrinks 3.48, 4.02 (dry) and 3.43, 4.11 per halving.
- S2 **confirmed**: Simpson/trapezium at f = 12 is 0.10 (dry) and 0.02 (episodic-lma).
- S3 **refuted as registered**: 6 → 12 shrinks 11.3× and 9.1× (order 3.2–3.5), but 12 → 24
  reads 4.2× and 0.5×: by f = 12 Simpson's founders' error is already at the floor, so
  the second halving measures noise, not order.
- S4 **confirmed**: Simpson with 12 founders' intervals errs 0.052 / 0.027 rms against the
  committed layer's 0.135 / 0.335 with 17 / 19 intervals: 2.6× and 12× smaller for
  5 and 7 fewer nodes (rows −5.9% and −9.4% of the committed run).
- S5 **refuted on dry**: worst 0.22ε (TF24_cost_scale, the quantity whose derivative
  jitters at the leaf's arm switch, D1); 0.10ε on episodic-lma. Every main quantity is
  under 0.1ε on both (hmat, lma, r_l, a_l1 ≤ 0.07).
- To reach the same rms with the trapezium the founders' window needs f ≈ 40–48: rows
  +21% (dry, interpolated between f24 and f48) to +38% (episodic-lma at f48) over the
  committed run [i]. Simpson at f = 6 already beats the committed layer on episodic-lma
  (0.25 against 0.335, rows −18%) but not on dry (0.59).

**Predictability [i].** With Simpson the leading term is h⁴: ln J's interpolation part
becomes ≈ (h/L)⁴·share_F·κ₄/180, which the pilot's L bounds (f = 12, h ≈ 0.29–0.31 y:
0.015ε on dry, 0.004ε on episodic-lma), and the elasticities sit at most ~5× above ln J's
(E) — ≤ 0.07ε. Measured: 0.03–0.05 rms, at the jitter floor. So the founders' error stops
needing to be *read*: a pilot-sized bound covers it, and the check no longer has a
founders' share to misplace (the C1 concern of a shrink that differs by region goes away
with it, since a h⁴ term at the floor contributes nothing either run can see).

**Caveats.**
- Two cases. Simpson applies to every sum over nodes (J, uptake, light, census). The
  light channel is minor here; where crowns comb (sharp crowns, wide early gaps) light's
  profile in b is not smooth and Simpson gains less. Not tested on long-wet or constant
  rain.
- Pairs must be two equal intervals with no edge inside: true of the founders' window
  (creation open from 0 to b1), not of the spells.
- The patch is a diagnostic (an environment variable read once). In plant it would be a
  schedule-declared window in control, applied in `for_each_establishment_weight`, and
  needs FF16's bit-identity tests (it is off by default) and a gradient check.
- The check pair would no longer refine the founders by the same ratio as the rest; at
  the floor that does not matter, but a schedule using Simpson at f < 12 would need its
  founders' term handled as h⁴, not h².
