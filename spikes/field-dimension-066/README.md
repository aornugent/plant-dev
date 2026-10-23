# Field dimension, on the odelia 0.9.0 stack

**Caveat (24 Oct), from `spikes/break-even/`:** the closed-stand results use a uniform
108-introduction schedule, which does not resolve a boundary layer in birth date about 0.05
yr wide at the start of the patch.
- The t = 0 node holds 63% of R.
- Resolving the start moves pool fitness on the closed stand by O(1), and leaves the resident
  off equilibrium (F ≈ +0.17 at this ln b\*).
- So the closed-stand spectrum and its d ≈ 4–5 are limited by the schedule, especially in
  directions near the resident.

The open stands are less affected (their identity gain moved from 49 to 61), but were not
re-measured.

A re-measurement of d, the rank of how invader fitness responds to the field changes a
TF24 resident can make (`docs/review/field-cut.md` §9). It continues the pilot in
`spikes/field-dimension/` (on the `workflows` worktree): same stand, same seven
perturbations, but every invader is **replayed in the resident's recorded field**
instead of riding along in the resident run.

**Result.**
- **The noise floor fell 100–250×.** The step-sequence jitter (a 1e-6 move in ln b) fell
  from 0.12 / 0.05 rms in ln R′ to 3e-4 / 6e-4. A halved tolerance moves ln R′ by 4e-4
  instead of 0.2–0.5. The singular-value floor is now 1–3e-4 of σ₁, against 0.1–0.2.
- **Every one of the seven singular values clears the jitter floor in every regime**, so d
  above jitter is 7, which is all this design can show. The jitter floor no longer limits
  d; the spectrum's shape and a systematic error do.
- **The systematic error is the invaders' thinned schedule.** Invaders enter at every
  third introduction. That shifts each ln R′ by 0.1–1 and each ΔΦ entry by 6% rms. On the
  open stands its top singular value is 6% of σ₁, about the size of σ₂. A full-schedule
  sub-pool keeps σ₁–σ₃ and their 3-dimensional subspace, and moves σ₄–σ₇ by up to 2.5×.
- **Open stands (long drought, seasonal): one dominant mode, two at 4–5%, then a gap.**
  Relative σ is 1, 0.055, 0.034, 0.021, … On the full schedule (8 invaders) it is 1,
  0.043, 0.041, then 0.0055: a 7.5× gap after σ₃. So d ≈ 3, with one mode carrying
  almost everything.
- **Closed canopy (wetter record, lma 0.32·e⁻¹ = 0.118): much richer.** Ground light is
  0.38 (patch-weighted), against 0.65 on the open stands. Relative σ is 1, 0.17, 0.13,
  0.11, 0.10, 0.047, 0.023, so five modes sit above 10%. A full-schedule sub-pool
  reproduces this spectrum to 5%, so d ≈ 4–5 here. The secants are strongly nonlinear,
  though: second difference / slope·δ is 0.35–0.56, and 1.24 for vcmax.
- **Two species: monotone (convex) on the closed stand, marginal on the open one.**
  - On the closed stand a pair reached a joint equilibrium (|F| < 0.005). There
    λ(A_s) = (1.48, 0.104), so A_s is positive definite with λ_min/λ_max = 0.07. The
    skew ratio is 0.048 and det A = +0.157.
  - On the open stand neither of two pairs has a nearby equilibrium. At mixed states A is
    near rank one and λ_min(A_s) is slightly negative: −0.033 and −0.008 against
    λ_max 1.8 and 1.6.

## What was run

- **Build.** odelia 0.9.0 (8b7b934), phylloptim 0.11.0 (ef75769), plant `ODELIA-66`
  (00cf3a99), installed with `-O2` into a private library
  (`/home/a/.claude/jobs/9d586e52/rlib-d066`).
- **Stand.** TF24, lifetime 40, 108 uniform introductions held in every run, birth-date
  coordinate, `ode_tol_rel` 1e-4, `ode_tol_abs` 1e-8. Resident traits: lma 0.32 and the
  rest at TF24 defaults (rho 608, hmat 16.6, K_s 1, rooting_depth_max 1.5, vcmax_25 96),
  as in the pilot.
- **Rainfall knots.** This plant substeps the soil across every step that spans a knot of
  the rain (33a5bddf). Zero-depth pulses at all 2931 active knots pin the steps to the
  knots: on long drought they reproduce ln R′ to 1e-5, at 2.2× the cost (14.4k steps
  against 5.7k). So the main runs do not pulse.
- **Equilibrium.** A quadratic through three resident-only runs, ±0.2 in ln b. On this
  stack b* is about 100 times the pilot's, and F(ln b) is smooth and near linear (slope
  −1.5 to −1.8):

  | case | record | resident | ln b* | b* | F at base |
  |---|---|---|---|---|---|
  | long-drought | long drought | lma 0.32 | 1.539 | 4.66 | 4e-5 |
  | seasonal | seasonal | lma 0.32 | 1.713 | 5.55 | −6e-5 |
  | closed | long-wet (mean 5, no droughts) | lma 0.32·e⁻¹ = 0.118 | 3.595 | 36.4 | 7e-5 |

- **Perturbations.** ±0.2 in ln b and in each of six traits (lma, rho, hmat, K_s,
  rooting_depth_max, vcmax_25), as central differences per unit ln: 7 columns.
- **Pool.** 48 invaders: the resident's own traits, plus a 47-point Latin hypercube in
  ln-trait over ±0.4 in all six traits. Each enters at every third introduction (36).
  `scm$run_mutant(pool)` replays them in the resident's recorded field: the resident is
  run once more, pinned to its own steps, then every invader takes those steps and reads
  the field at each rate evaluation.
- **Noise runs.** `null_b` (ln b + 1e-6) and `base_tol` (tolerance halved).
- **Making side.** As in the pilot: canopy openness on a 0–30 m grid and soil moisture in
  5 layers, at the 109 introduction times, rows weighted by √(patch density · Δt).
- **Cost.** A resident run takes 64 s (open) or 75 s (closed). A run with the pool takes
  13–15 min (open) or 14–21 min (closed); about 12 of those minutes are the replay of
  48 × 36 invader cohorts. Each invader cohort solves its own TF24 leaf, so the replay is
  not cheap per invader (about 15 s each), but it is now separate from the resident and
  shares its steps. 17 runs per case on 4–5 workers took about 70 min.

## Noise

| | null_b rms ln R′ | tol rms ln R′ | floor (jitter) | floor (jitter + tol) | σ₁ | floor / σ₁ |
|---|---|---|---|---|---|---|
| pilot long drought | 0.12 | 0.23 | 6.2 | 9.4 | 27.8 | 0.22 |
| pilot seasonal | 0.05 | 0.51 | 2.7 | 19.1 | 30.0 | 0.09 |
| long drought | 2.7e-4 | 4.1e-4 | 0.025 | 0.029 | 204 | 1.2e-4 |
| seasonal | 6.3e-4 | 4.4e-4 | 0.058 | 0.048 | 205 | 2.8e-4 |
| closed | 3.7e-4 | 2.9e-4 | 0.034 | 0.028 | 112 | 3.0e-4 |

- The floor is computed as in the pilot: the 95% quantile of the top σ of noise matrices
  built from the observed error vectors.
- On the resident's own F the null move is 1e-4 and the tolerance move 1e-4 or less.
- The tolerance move is no longer a level bias. It is as large as the jitter, so the
  level is converged to about 4e-4 at this schedule.
- The remaining error that matters is the invaders' quadrature (below), not run-to-run
  noise.

## Sensing: ΔΦ (48 invaders × 7 perturbations)

| case | σ₁ | σ₂ | σ₃ | σ₄ | σ₅ | σ₆ | σ₇ |
|---|---|---|---|---|---|---|---|
| long drought | 204 | 11.3 | 6.83 | 4.32 | 2.66 | 1.32 | 1.07 |
| relative | 1 | 0.055 | 0.034 | 0.021 | 0.013 | 0.0065 | 0.0053 |
| seasonal | 205 | 9.68 | 8.34 | 3.48 | 2.69 | 1.39 | 1.15 |
| relative | 1 | 0.047 | 0.041 | 0.017 | 0.013 | 0.0068 | 0.0056 |
| closed | 112 | 19.4 | 14.8 | 12.4 | 11.5 | 5.26 | 2.52 |
| relative | 1 | 0.173 | 0.132 | 0.111 | 0.103 | 0.047 | 0.023 |

Other views:
- **Each column scaled to unit norm:** 1, 0.20, 0.16, 0.07 (long drought); 1, 0.22, 0.17,
  0.065 (seasonal); 1, 0.44, 0.31, 0.23, 0.18 (closed).
- **Centred over the pool:** σ₁ falls to 0.54, 0.56 and 0.47 of the raw σ₁; the rest
  barely move. Half of mode 1 is a uniform shift of every invader.
- **Linearity** (second difference / slope·δ by column; order lnb, lma, rho, hmat, K_s,
  rooting_depth_max, vcmax_25):
  - open stands: 0.02, 0.12, 0.10, 0.61, 0.19, 0.08, 0.88;
  - closed: 0.55, 0.48, 0.56, 0.35, 0.47, 0.04, 1.24.

  δ = 0.2 is a secant, not a derivative, for hmat and vcmax everywhere, and for nearly
  every input on the closed stand. With this noise floor, δ = 0.05 would be affordable.

**d estimates.**

| case | rel > 0.1 | rel > 0.03 | rel > 0.01 | above jitter floor | above the quadrature error |
|---|---|---|---|---|---|
| long drought | 1 | 3 | 5 | 7 | 1 by Weyl's bound; 3 empirically |
| seasonal | 1 | 3 | 5 | 7 | 1 by Weyl's bound; 3 empirically (gap after σ₃) |
| closed | 5 | 6 | 7 | 7 | 4–5: thinning moves σ by < 5%; 3.6× gap after σ₄ on 8 invaders |

## The thinned invader schedule

Invaders enter at every third of the resident's 108 introductions, as in the pilot. An
invader at the resident's traits on the full schedule reproduces the resident's ln R
exactly (−5.808143e-05 both). On the thinned schedule it is off by 0.48 (long drought),
0.52 (seasonal) and 1.00 (closed). To see what the thinning does to ΔΦ, the pool's first
8 members were replayed on all 108 introductions, in all 17 runs of a case
(`<case>-full`):

| seasonal, 8 × 7 | σ₁ | σ₂ | σ₃ | σ₄ | σ₅ | σ₆ | σ₇ |
|---|---|---|---|---|---|---|---|
| thinned, relative | 1 | 0.053 | 0.037 | 0.0077 | 0.0067 | 0.0018 | 0.0006 |
| full, relative | 1 | 0.043 | 0.041 | 0.0055 | 0.0027 | 0.0015 | 0.0006 |
| σ(thinned − full) / σ₁ | 0.059 | 0.017 | 0.011 | 0.0044 | 0.0009 | 0.0005 | 0.0002 |

- ΔΦ entries move by 6% rms (4–15% by column). The level shifts by 0.1–0.85.
- The leading left vector agrees to 2.8°, and the 3-dimensional leading subspace to 16°.
  σ₂ and σ₃ are near-degenerate on both schedules, so the individual mode-2 vector
  rotates freely (59°); their span does not.
- On the full schedule, null_b moves ln R′ by 9e-5 rms.
- So on the open stands σ₂ and σ₃ (about 4%) are real on both schedules, and there is a
  ~7× gap to σ₄. The 48-pool's σ₄–σ₇ (2% down to 0.5%) sit inside the thinning error.

| closed, 8 × 7 | σ₁ | σ₂ | σ₃ | σ₄ | σ₅ | σ₆ | σ₇ |
|---|---|---|---|---|---|---|---|
| thinned, relative | 1 | 0.162 | 0.120 | 0.099 | 0.028 | 0.014 | 0.0097 |
| full, relative | 1 | 0.155 | 0.122 | 0.100 | 0.028 | 0.015 | 0.0094 |
| σ(thinned − full) / σ₁ | 0.070 | 0.020 | 0.015 | 0.0059 | 0.0031 | 0.0021 | 0.0017 |

- On the closed stand the thinning shifts levels by 0.56–1.05 and entries by 7% rms.
- The spectrum is unchanged to 5%. The leading 1–4-dimensional subspaces agree to
  3–12°.
- On the full schedule, null_b moves ln R′ by 2.9e-4 rms.
- So the closed stand's richer spectrum is not a quadrature artefact. On 8 invaders it
  shows four modes at 10% or more, then a 3.6× gap. The 48-pool resolves a fifth at 10%,
  which 8 rows cannot.

## Leading modes (`modes.R`)

Perturbation weights are V's rows (lnb, lma, rho, hmat, K_s, rooting_depth_max,
vcmax_25), and pool weights are U's.

**Open stands (both records alike).**
- **Mode 1 is the shading-intensity mode, as in the pilot.**
  - Perturbation weights: lma −0.91, rho −0.31, vcmax_25 +0.25; ln b only +0.09.
  - A resident with cheaper leaves and wood and faster photosynthesis lowers every
    invader's fitness.
  - Pool weights all have one sign. They correlate −0.86 with invader lma and +0.72 with
    base ln R′.
- **Modes 2–3 (4–5%) are a degenerate pair spanning three resident axes:**
  - wood density against photosynthetic capacity (long drought, mode 2: rho −0.67,
    vcmax +0.58, lma +0.39);
  - rooting depth (long drought, mode 3: rooting_depth_max −0.95);
  - on seasonal, the same three mixed with hmat (mode 2: hmat +0.51, vcmax −0.58,
    rooting_depth_max −0.48).

  Their pool weights correlate with invader vcmax_25 (±0.57) and lma (±0.45). Trait
  regressions explain 50% of u₂ and 25–30% of u₃.
- **Making side.** σ_light relative is 1, 0.16, 0.11, 0.08, 0.05, 0.03, 0.02. σ_water is
  1, 0.24, 0.11, 0.07, 0.02.
  - Every light column is 600–12000× the null move and every water column 35–4500×, so
    the made field is full rank above noise.
  - Light mode 1 is the understorey (0–10 m) of patches aged 0–10, driven by lma (+0.78),
    rho (+0.47) and vcmax (−0.41).
  - Light mode 2 adds patches aged 10–20 at 10–15 m and loads on ln b and rho.
  - Water mode 1 is the top layer in patches aged 0–5, driven by lma.
  - The stand is denser than the pilot's (b* 4.7 against 0.02). Ground light is 0.46 at
    age 5, 0.78 at 10, 0.62 at 20 and 0.72 at 30, and 0.65 patch-weighted.

**Closed canopy.**
- **Mode 1:** rho −0.73, lma −0.63, vcmax +0.18. Still shading intensity, now led by wood
  density. Pool weights all one sign, but traits explain only 36% of them (84% on the
  open stands).
- **Mode 2 (17%):** vcmax_25 alone (+0.95).
- **Mode 3 (13%):** ln b −0.46, lma +0.46, rho −0.53, K_s +0.50: density against
  leaf/water economy.
- **Mode 4 (11%):** rooting_depth_max (−0.72), with K_s (−0.38) and hmat (−0.34).
- **Making side.** σ_light relative is 1, 0.28, 0.18, 0.17, 0.10, 0.10, 0.02; σ_water is
  1, 0.63, 0.15, 0.11, 0.06.
  - Light mode 1 is the 2–10 m layer at ages 0–10 (rho −0.89).
  - Light mode 2 is the 5–15 m layer at ages 10–30 (vcmax, hmat, rooting depth).
  - Water mode 2 is now 63% of mode 1: water carries a second independent direction.
  - Ground light is 0.25 at age 5, 0.44 at 10, 0.29 at 20 and 0.53 at 30; 0.38
    patch-weighted, with a minimum of 0.094.

## Two species (`two_species.R`)

A_ij = −∂F_i/∂ln b_j with F_i = ln R_i, by central differences (h = 0.1) in each ln b_j,
from resident-only runs. Species 1 is the case's resident. On this stack's noise (4–6e-4
in F), an entry carries about 0.003–0.004 of error.

**Closed stand (long-wet record, resident lma 0.118): a joint equilibrium.**
- Species 2 is pool #31 relative to the closed resident: lma −0.14, rho +0.01, hmat +0.24,
  K_s +0.40, rooting_depth_max −0.29, vcmax +0.19 in ln. It is near neutral as an invader
  there (ln R′ ≈ 0.03 after the thinning offset).
- A at the mixed state ln b = (3, 3) was [[0.624, 0.841], [0.410, 1.170]], with
  λ(A_s) = (1.58, 0.214), skew ratio 0.19 and F = (−0.87, −1.08). Its linear prediction
  of the root, (2.71, 2.17), started a Newton that converged in 3 iterations.

| | ln b | F | A | λ(A_s) | skew ratio | det A | ground light |
|---|---|---|---|---|---|---|---|
| equilibrium | (3.021, 1.826) | (−0.0023, −0.0042) | [[0.937, 0.621], [0.722, 0.645]] | 1.478, 0.104 | 0.048 | +0.157 | 0.41 |

- A_s is positive definite: each species limits itself more than the pair limit each
  other on average (Chesson's stabilisation is positive).
- λ_min is 30× the entry error. The skew part is small (5%): impact and sensitivity are
  nearly aligned for this pair, in a field where light competition dominates.
- λ_min/λ_max = 0.07: convex, but weakly; predicted densities respond to error through
  A⁻¹, so dN*/dp is about 14× worse conditioned than a well-separated pair.

**Open stand (seasonal record, resident lma 0.32): no equilibrium nearby.**

| pair (species 2 as ln-shifts) | ln b | F | A | λ(A_s) | skew ratio | det A |
|---|---|---|---|---|---|---|
| pool #38: lma −0.27, rho +0.17, hmat −0.30, K_s −0.12, rdm −0.12, vcmax +0.12 | (1.71, 0) | (−1.06, 3.97) | [[1.091, 0.957], [0.561, 0.516]] | 1.615, −0.008 | 0.173 | +0.026 |
| pool #31: lma −0.14, rho +0.01, hmat +0.24, K_s +0.40, rdm −0.29, vcmax +0.19 | (1.5, 0.5) | (−0.94, −0.42) | [[0.872, 0.994], [0.853, 0.909]] | 1.814, −0.033 | 0.055 | −0.055 |

The skew ratio is ‖A − Aᵀ‖_F / ‖A + Aᵀ‖_F.

- **Neither pair has a joint equilibrium nearby.** Newton on F = 0 walked away in both.
  - Pair #38: species 2 gains 5 in F over species 1 everywhere tried.
  - Pair #31: F₁ − F₂ stays at −0.5 over 1.2 units of composition change, while it
    responds to composition by only 0.02–0.09 per unit.
  - The resident is far from evolutionarily singular: the pool's fitness gradient is −36
    per ln lma. Near-equal types then differ in fitness at first order, which composition
    cannot offset. A coexisting pair would have to start near a singular strategy.
- **A is close to rank one.** Its smallest singular value is 1–2% of its largest, the
  sensing spectrum's one dominant mode seen from the making side. The two species load on
  one field direction.
- **λ_min(A_s) is slightly negative for both pairs.**
  - −0.033 for pair #31 is about 8× the entry error. With det A < 0, no positive diagonal
    rescaling (per density instead of per ln b) makes A_s semidefinite, so this is
    scale-free.
  - −0.008 for pair #38 is at about 2× the error, and det A > 0, so its sign depends on
    the scaling.
- **Reading:** on the open stand the convexity modulus is about zero against σ₁. Assembly
  sits at the boundary between monotone and not, because the field is effectively one
  mode and the strategies in play differ along it. This is a mixed-state measurement, not
  at equilibrium. Read it as the size of the effect, not its sign.
- **The contrast fits the spectra.** The closed stand has four or five sensing modes
  above 10%. A pair that differs in height, conductance, rooting depth and vcmax can load
  on different ones there, and λ_min(A_s) is clearly positive. The open stand's fitness
  sees one mode, so A collapses to rank one.

## Trust

- **High.** The noise floor (100–250× lower). The one dominant sensing mode and its
  meaning (shading intensity, lma/rho/vcmax) on the open stands. The open stands'
  spectrum decay to σ₃ (it holds on both schedules and both records).
- **Moderate.**
  - The open stands' gap after σ₃ (8 invaders on the full schedule only).
  - The closed stand's richer spectrum: five modes above 10%, and it survives the
    full-schedule check. But the secants are nonlinear at δ = 0.2, so the values are
    those of finite moves.
  - The identity of modes 2–3: they are near-degenerate, so only their span is
    determined.
- **Moderate.** The closed-stand pair's positive-definite A_s at a converged equilibrium.
  λ_min is 30× its error, but this is one pair, at h = 0.1, and A moved substantially
  between the mixed state and the equilibrium.
- **Low.** The sign of λ_min(A_s) on the open stand: mixed states, not equilibria, and
  λ_min is a few times the entry error. Its size, about 1–2% of λ_max, is the robust part.
- **Design limits.**
  - Seven perturbation columns cap d at 7.
  - The invaders' thinned schedule is now the dominant error. A full schedule costs 3×
    in replay (about 15 s per invader per 36 cohorts).
  - Field-direction probes (an adjoint, or perturbing light in one height and age band)
    would excite modes the trait moves miss.

## Files

- `field_dimension.R`: stages `eq` and `runs` (environment `REGIME`, `CASE`,
  `RES_SHIFT`, `WORKERS`, `INV_EVERY`, `INV_N`). Per-run RDS files are in
  `/home/a/.claude/jobs/9d586e52/tmp/d066/runs/<case>/`.
- `fit.R <case>`: sensing and making matrices, floors, SVDs →
  `field_dimension_<case>.rds`.
- `modes.R <case>`: where the leading modes sit.
- `quadrature_check.R <case>`: thinned against full invader schedule →
  `quadrature_check_<case>.rds`.
- `two_species.R`: Newton for a joint equilibrium (`NEWTON=1`), or A at given ln b
  (`NEWTON=0`) → `two_species_<case>.rds`. `two-seasonal` is pair #38 and
  `two-seasonal-31` is pair #31 on the seasonal record. `two-closed-31` is the closed
  stand's equilibrium, and `two-closed-31-mixed` is the same pair at (3, 3).
