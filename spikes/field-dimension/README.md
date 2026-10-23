# Field dimension, pilot

A first, rough estimate of d: the rank of how fitness across a pool of strategies
responds to the field changes a TF24 resident can make (`docs/review/field-cut.md` §9).
It is pilot quality: one resident, seven perturbations, 16 invaders, two rainfall records.

**Result.** Fitness sees **one strong field mode** on both records. One or two more sit
at 7–15% of it, at the noise floor. Above the floor, d is 1 on long drought and 2,
marginally, on seasonal. The field the resident *makes* has more structure: three or
four light directions are resolvable. Fitness collapses them mostly onto one.

## What was run

- **Build.** The installed `plant` 2.0.0.9002 (odelia as installed), public R API only.
  - This build's `SCM$run_mutant()` is a stub ("needs a recorded resident field … and
    nothing records one").
  - So the invaders ride inside each resident run at birth rate 1e-8 (negligible impact
    on the field). Each invader's `net_reproduction_ratios` entry is its R′.
  - This build has no `events()` or rainfall pulses, so steps are not pinned to the
    rainfall knots, unlike `harness/long_drought.R`'s `run_J`.
- **Stand.** TF24, lifetime 40, 108 uniform introductions (`uniform_times(108)`), birth-date
  coordinate, `ode_tol_rel` 1e-4, `ode_tol_abs` 1e-8. Resident traits: lma 0.32, all
  others at TF24 defaults (rho 608, hmat 16.6, K_s 1, rooting_depth_max 1.5,
  vcmax_25 96), all through `TF24_hyperpar`.
- **Equilibrium.** A quadratic through three resident-only runs in ln b:
  - long drought: ln b* = −3.97, where ln J − ln b = −0.009 in the base run;
  - seasonal (the long-drought record without its drought years): ln b* = −3.74, where
    ln J − ln b = −0.063.
  - On this build, b* is about 0.02. The b* ≈ 4.68 in `theory.md` came from the open
    stack with rainfall pulses, so the two builds differ a lot here.
  - On long drought, ln J − ln b is jagged in b (it is non-monotone between ln b = −4.2
    and −3.7), so this b* is only "near".
- **Perturbations.** ±0.2 in ln b and in each of six traits: lma, rho, hmat, K_s,
  rooting_depth_max, vcmax_25. Central differences per unit ln give 7 columns.
- **Pool.** 16 invaders: the resident's own traits, plus a 15-point Latin hypercube in
  ln(lma, rho, hmat, K_s, rooting_depth_max) over ±0.4. Each has 36 introductions (every
  third of the resident's). Base ln R′ spans −15.7 to +7.2.
  - Identity check: the invader at the resident's traits has ln R′ = 0.005 against the
    resident's −0.009. The 0.014 gap is the coarser schedule.
- **Noise runs.**
  - `null_b`: ln b moved by 1e-6. This measures step-sequence jitter, which is what
    differences at one tolerance carry.
  - `base_tol`: tolerance halved.
- **Field (making side).** From `scm$collect` snapshots (109, at the introduction
  times, identical across runs):
  - canopy openness on a 0–30 m grid (61 heights);
  - soil moisture in 5 layers.

  Rows are weighted by √(patch density · Δt).
- **Cost.**
  - Each pool run (resident plus 16 invaders, about 680 cohorts) took 20–35 min:
    26–35k steps, with 9 to 13 runs in parallel on 16 cores.
  - 17 runs per climate, two climates, about 2 h of wall time. Equilibrium runs took
    2–3 min each.
  - That is far over the brief's 50–80 s estimate, because the pool multiplies the
    cohort count about sixfold.

## Sensing: ΔΦ (16 invaders × 7 perturbations), d(ln R′)/d(ln input)

| | σ₁ | σ₂ | σ₃ | σ₄ | σ₅ | σ₆ | σ₇ |
|---|---|---|---|---|---|---|---|
| long drought | 27.8 | 4.22 | 1.68 | 0.76 | 0.48 | 0.38 | 0.17 |
| relative | 1 | 0.152 | 0.061 | 0.027 | 0.017 | 0.014 | 0.006 |
| seasonal | 30.0 | 2.78 | 2.11 | 0.80 | 0.62 | 0.39 | 0.20 |
| relative | 1 | 0.093 | 0.070 | 0.027 | 0.021 | 0.013 | 0.007 |

**Noise floors.** Each floor is the 95% quantile of the top σ of noise matrices built
from the observed error vectors.

| | jitter rms per entry | floor (jitter) | tol-shift rms | floor (jitter + tol) |
|---|---|---|---|---|
| long drought | 0.12 | 6.2 | 0.23 | 9.4 |
| seasonal | 0.05 | 2.7 | 0.51 | 19.1 |

- The halved tolerance moves ln R′ by about 0.5 on seasonal. That shift is mostly a
  common level bias, which cancels in differences at a fixed tolerance. The jitter floor
  is the relevant one; the jitter + tol floor is an upper bound.
- The long-drought noise is itself structured: the jitter and tol errors are 0.98
  correlated across the pool. A 1e-6 move in b shifts canopy openness by up to 0.14 at
  patch ages 25–35. Some part of the late-stand trajectory is chaotically sensitive to
  the step sequence.

**d estimates.**

| | rel > 1e-1 | rel > 1e-2 | rel > 1e-3 | above jitter floor | above upper floor |
|---|---|---|---|---|---|
| long drought | 2 | 6 | 7 | **1** | 1 |
| seasonal | 1 | 6 | 7 | **2** (σ₂ 2.78 vs 2.67) | 1 |

- The 1e-2 and 1e-3 thresholds sit far below the noise. Read them as "the matrix is full
  rank in noise", not as d = 6–7.
- Other views of the same matrices:
  - each column scaled to unit norm: relative σ 1, 0.53, 0.23 (long drought) and 1,
    0.23, 0.08 (seasonal);
  - centred over the pool (the uniform shift removed): 1, 0.22, 0.16 and 1, 0.29, 0.16.
- Linearity, as the second difference against slope·δ:
  - seasonal: 0.2–0.6 for most columns, 1.6 for rooting_depth_max;
  - long drought: 0.6–2 for most columns, 7.7 for hmat and 9.2 for rooting_depth_max.
    The long-drought hmat, rooting_depth_max and ln b columns are dominated by jitter.
  - Even ln b has the wrong sign at the resident: the identical invader gains on both
    sides.

## Leading modes

- **Sensing mode 1** (both climates) is a shading-intensity mode.
  - Perturbations: lma −0.75 and −0.67, vcmax_25 +0.57 and +0.45, rho −0.26, and on
    seasonal hmat −0.39.
  - In this sign, a resident that makes more leaf area (lower lma, higher vcmax) lowers
    every invader's fitness.
  - Pool weights all have one sign, 0.15–0.40. Every strategy responds the same way,
    with a 2.6-fold spread in strength.
- **Sensing mode 2,** below or at the floor:
  - long drought: the pool weights correlate with invader rho (r = −0.81);
  - seasonal: they correlate with lma (−0.64) and K_s (+0.49), and the perturbation
    weights load on hmat, K_s and rooting_depth_max.

  It hints at a wood-density / succession axis on one record and a height–water axis on
  the other. Not resolved.
- **Making side, light** (relative σ 1, 0.56–0.59, 0.24–0.29, 0.14–0.17, about 0.1).
  - The stand is short and open. Canopy openness stays above 0.8 at ground level, and the
    stand thins out after about age 25.
  - Mode 1 is light at 0–10 m in patch ages 5–20, the whole understorey of the mid-aged
    patch.
  - Mode 2 shifts that toward 5–15 m and ages 5–10 against 10–20, a height-by-age
    contrast. It is driven by lma and rho.
  - The light changes beat the null-move change (0.08–0.35 against 0.03–0.08 in
    weighted norm).
- **Making side, water** (relative σ 1, 0.87, 0.73… on long drought; 1, 0.65, 0.57… on
  seasonal).
  - Mode 1 sits in the shallow layer (0–0.3 m) at ages 5–20, driven by hmat and K_s.
  - The water responses are only 1.5–2× the null move, so the water spectrum is near
    noise and its flatness means little.

## Trust, and what a better measurement needs

- **The one dominant mode is robust.** It appears on both climates, sits 3–10× above
  every floor, and is near-linear on seasonal.
- **"d = 1 or 2" is a lower bound set by noise, not a measurement of the gap.**
  - σ₂/σ₁ is 0.09–0.15, at the floor.
  - Real second and third modes at the 5–10% level could hide there, and those are the
    ones that would allow coexistence or branching.
- **This stand is a weak test.** It is sparse, b* is about 0.02, and the canopy is open.
  A closed, competitive canopy (a wetter record, or a lower-lma resident) should have a
  richer light-by-height field. d may be larger there.
- **A better measurement needs:**
  1. A replay instead of co-running. A `run_mutant` build (the open stack) walks every
     invader through one recorded field. That removes the step-sequence jitter between
     invaders and cuts cost about sixfold, so a pool of 50–100 becomes cheap.
  2. Steps pinned to the rainfall knots (the open stack's `events`/pulses). The jitter
     comes from steps that straddle the daily forcing, which is worst on long drought.
  3. Tighter tolerance, or a refined node schedule. Halving the tolerance moves ln R′
     by 0.5, so the level is unconverged even where the differences are fine.
  4. Field perturbations along chosen field directions instead of trait moves:
     - light at one height band and age band;
     - water in one layer.

     With an adjoint (the §9 plan), those modes would probe sensitivity directly, and
     the trait moves would not have to excite them by accident.
  5. A denser pool along the candidate separating axes, plus a closed-canopy resident
     and a two-species resident.

## Files

- `field_dimension.R`: the stages `eq`, `runs` and `fit` (environment `STAGE`, `REGIME`,
  `WORKERS`). Per-run RDS files go to `/home/a/.claude/jobs/9d586e52/tmp/runs/<regime>/`.
- `modes.R`: where the leading modes sit (`Rscript modes.R <regime>`).
- `field_dimension_<regime>.rds`: the stand, the pool, ΔΦ, curvature, noise vectors,
  floors, SVDs, and the weighted light and water difference matrices with their SVDs.
