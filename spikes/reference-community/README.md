# A TF24 evolutionarily stable reference strategy

The first evolutionarily singular TF24 strategy solved and classified in more than one
trait. It is the reference that later methods should reproduce: a mean-field-game
predictor, or the lean assembly route (`docs/review/assembly-report.md`).

**Result.**
- **One singular strategy in (lma, hmat, vcmax_25), and it is an ESS.**
  - It is a CSS: H ≺ 0 and J + Jᵀ ≺ 0, with every eigenvalue 40× or more its error.
  - The two regimes meet at almost the same point: lma 0.028, vcmax_25 112, hmat 9–10 m,
    ln b* ≈ 6.0.
- **It is not a branching point, so no coalition was assembled.** Pricing in its field
  finds no invader with ln R′ > 0 over a ±0.2 cube in ln trait, with axis points out
  to ±0.4.
- **Wood density has no singular strategy at TF24's default trade-offs.** Its g grew
  from −38 to −230 over 0.7 in ln rho. So rho is held at 608, and evolves no further.
- **The node schedule must resolve the start of the patch before g means anything.**
  On the uniform 108-node schedule, the cut's g at the resident is 50–80× the smooth
  selection gradient (§ Schedule).

## The reference

Both are a single TF24 resident at its demographic equilibrium with g = 0. Traits not
listed are at TF24's defaults: rho 608, K_s 0.3358, rooting_depth_max 1.5.

| | **closed** (long-wet record) | **seasonal** (open start) |
|---|---|---|
| start | field-dimension-066 closed resident: lma 0.1177, ln b 3.595 | lma 0.32, ln b 1.713 |
| lma [kg m⁻²] | **0.027802** | **0.028318** |
| hmat [m] | **10.1142** | **9.2642** |
| vcmax_25 | **112.530** | **112.169** |
| ln b* (b*) | **6.000187** (403.5) | **5.979322** (395.2) |
| F = ln R | +1.37e-4 | −6.4e-5 |
| g (per ln lma, hmat, vcmax) | (+1.8e-3, +5.2e-4, +3.1e-4) | (−3e-4, −1.3e-3, −2.9e-3) |
| ∂F/∂ln b | −1.225 | −1.242 |
| ln-trait shift from start | (−1.44323, −0.49521, +0.15887) | (−2.42483, −0.58300, +0.15566) |

Exact values, with F_θ, the schedule's times and everything below, are in
`reference_long-wet.rds` and `reference_seasonal.rds`.

**The setting** (`common.R`):
- TF24, lifetime 40, on the birth-date coordinate;
- `ode_tol_rel` 1e-4 and `ode_tol_abs` 1e-8;
- rainfall from `harness/long_drought.R`'s `long-wet` or `seasonal` record;
- the default `TF24_hyperpar`. Every gradient is per unit ln trait, along that trade-off.

### Classification (central differences, h = 0.01 in ln trait)

| | closed, at the root (step 14) | closed, step 10 (0.055 away in ln hmat) | seasonal, step 12 (0.025 away) |
|---|---|---|---|
| eig H (sym) | −27.0, −30.7, −105.1 | −27.8, −31.7, −108.9 | −17.3, −24.6, −67.1 |
| ‖H − Hᵀ‖/‖H + Hᵀ‖ | 2.7e-4 | 1.3e-4 | 1.1e-4 |
| eig J | −108.8, −27.1, −18.2 | −112.5, −28.8, −21.4 | −69.0, −18.2, −14.7 |
| eig J + Jᵀ | −35.0, −55.6, −217.5 | −40.1, −60.2, −225.1 | −28.5, −37.2, −138.0 |
| verdict | ESS, CSS | ESS, CSS | ESS, CSS |

How the matrices were taken:
- **H** is held-field. Two invaders at x* ± h e_i replay the root's recorded field
  (`run_mutant` on the full schedule), and each gets its own gradient sweep.
  - Its diagonal agrees with second differences of ln R′ to 0.3%.
  - The landscape is quadratic here: central differences at h = 1e-3, 1e-2 and 3e-2 agree
    to 1% (`probes/probe_fd2_closed3b_3_*`).
- **J** follows the equilibrium.
  - Each recording is at x* ± h e_i, with ln b on the tangent
    ln b* − F_lnb⁻¹(F + F_θ δx). Its residual F is ≤ 4.7e-4, and that error cancels in the
    central difference.
  - **M = J − H is small except in the hmat column** (+6.6 and +12.0 in the closed case).
    A taller hmat makes a field that favours a taller hmat, but not enough to make it
    disruptive.
- **Every eigenvalue is 40× or more its error.** The error is the g noise floor below
  (≤ 5e-3) over 2h, about 0.25; the smallest eigenvalue is 14.7. The verdict is not
  marginal.

### Pricing

45 invaders in each root's field: a 3³ grid at ±0.2 in each ln trait, and axis points at
±0.05, ±0.1 and ±0.4.

| | largest ln R′ | the resident's own (= F) | nearest others |
|---|---|---|---|
| closed | +1.4e-4 | +1.4e-4 | −0.031 (hmat −0.05), −0.034 (lma ±0.05) |
| seasonal | −6.4e-5 | −6.4e-5 | −0.021 (lma −0.05), −0.022 (lma +0.05) |

- In both, the largest ln R′ is the resident's own.
- Each root's five pricing recordings were bit-identical: F was the same in all five.
- The results are in `price_closed3b.rds` and `price_seasonal3b.rds`.

### Tolerances and certification

- **The stop:** max|g| < 0.01 and |F| at its noise floor. Both roots end below the g floor.
  - |F| < 1e-6 cannot be reached at this ODE tolerance. Newton's last step moved F
    from −1.6e-4 to +1.4e-4 by a 9e-4 move in ln b, against a predicted 0.
- **The noise floor at the root.** A 1e-6 move in ln b moves F by up to 9e-5 and g by
  3–5e-3. Halving the tolerance moves F by 2–9e-5 and g by 1–5e-3.
- **The schedule is certified by one recording per root on 216 uniform + 40 early
  introductions** (256).
  - **Closed:** F moves by +7.7e-4 and g by (+0.021, +0.003, +0.118).
  - **Seasonal:** F moves by +2.0e-3 and g by (+0.026, −0.017, +0.101).
  - Through J⁻¹, either moves the root by about 1e-3 in each ln trait and 1–2e-3 in ln b.
  - The vcmax shifts (0.10–0.12) are just above that trait's invader ε (0.09,
    `harness/schedule/data/eps.csv`). The others are well inside.
  - So the reference's traits are good to about 1e-3 in ln trait. Its g = 0 holds to about
    0.1 on the finer schedule.

## Schedule

**Held through every solve:** 108 uniform introductions (40/108 apart), plus 40 inside the
first interval at geometric ratio 2^¼, from 3.6e-4 yr. That is 148 introductions:
`EARLY=40 EARLY_RATIO=1.1892071150` in `common.R`.

**Why.** The invader's selection gradient on the uniform schedule is wrong at the resident
(`probe_fd.R`, `probe_where.R`, `probe_nodes.R`):
- **The cut's g at the closed start was −1568 per ln lma.** The invader replay gives the
  same number, but finite differences of ln R′ fall from −753 to −113 to −32 at h = 1e-3,
  1e-2 and 5e-2. Fitting s + c/h gives a step of about ±1 in ln R′ at θ′ = θ, over a width
  of about 1e-3.
  - rho and vcmax show it as well. hmat, which does not change seedling growth, does not.
- **All of it is node 1,** the cohort born at t = 0 into the bare patch. Its R per seed is
  154.6 at θ, 351.8 at lma −0.1% and 8.1 at +0.1%.
  - At b ≈ 36, the first 0.37 yr of recruits is lumped into one crown (η = 12) at the top
    of the canopy.
  - An invader introduced with it either tops it or sits under it.
- **Uniform refinement converges slowly.** The slope at θ′ = θ was −1107, −1568, −118 and
  −20 at 54, 108, 216 and 432 introductions. The level moved too: F was −0.04, 0, +0.12
  and +0.20 at the start's ln b.
- **Grading the first interval removes the step.** At the start, x = 0 and ln b 3.595:

| early grading | introductions | F | g (lma, hmat, vcmax) |
|---|---|---|---|
| none (uniform) | 108 | −8.5e-5 | −1568, −6.3, +957 |
| +8, ratio 2 | 116 | +0.1640 | −20.23, −6.491, +13.435 |
| +20, ratio √2 | 128 | +0.1692 | −18.58, −6.513, +12.489 |
| **+40, ratio 2^¼** | **148** | **+0.1696** | **−18.29, −6.505, +12.317** |
| +80, ratio 2^⅛ | 188 | +0.1696 | −18.25, −6.506, +12.290 |
| 216 uniform + 40 | 256 | +0.1834 | −17.81, −6.482, +12.352 |

- **Grading 2 is not enough.** Grading 2 alone (+8 to +16 nodes, checked against each other
  at two points) hides the problem: it removes the step but stays 11% off in g_lma.
  Densifying inside the ~0.05 yr layer is what converges. The coordinator's break-even
  study found the same layer independently.
- **The cut is exact for the model it is given.** On the graded schedule the cut's g matches
  finite differences of the invader's ln R′ to 4–5 digits, at the start and at the root.

**Effect on earlier numbers:**
- field-dimension-066's ln b* = 3.595 is the uniform schedule's equilibrium only. With
  the start resolved, F there is +0.17, so ln b* is about 3.71 at the old traits.
- Its "invader at the resident's traits, thinned schedule, off by 1.00 (closed)" is this
  step.
- On the open seasonal stand at its uniform ln b*, the bias is small (F −0.003).

## The solve

**One-shot** (`one_shot.R`), as in `field-cut.md` §3. Each step is one recording, which
gives F, ∂F/∂ln b, F_θ (kept sweep) and g (cut sweep):
- **Traits:** Broyden on g, restarted to steepest ascent if a step would go against
  selection. The trust region is a cap in ln trait (0.1, raised to 0.2 or 0.3 later),
  halved when g reverses and grows.
- **ln b:** the predicted Newton step.

Then **chord-Newton** (`polish.R`) with the measured J, which Broyden had not learnt.

**Closed** (`solve_history.rds$closed3b`, after `closed3` on the coarse grading):
- **Steps 1–6 (cap 0.1):** lma ran down at the cap, with g_lma falling 1.5–1.9 per step.
  - ln b rose from 3.6 to 5.2 as leaves got cheaper.
  - The predicted ln b step kept |F| ≤ 0.025 throughout.
- **Steps 7–11 (cap 0.2):** Broyden took an uncapped step at 8. By step 10, g was
  (+0.22, −1.13, −0.06).
  - Broyden's hmat curvature was off by about 7×. It moved hmat 0.007 against g = −1.13.
- **Steps 12–14:** chord-Newton with J from step 10. max|g| went 0.97 → 0.094 → 0.0135 →
  0.0018.

**Seasonal** (`seasonal3` on the coarse grading, then `seasonal3b`):
- Steps 1–14 ran at a cap of 0.1, then 0.2 and 0.3. lma fell 2.4 in ln before
  g_lma turned at step 12.
- Then chord-Newton with J from step 12 (steps 15–16).

**What failed or was wasted:**
- **rho** (`closed-rho4`, 8 recordings). At TF24's defaults, B_dI2 = B_hks2 = B_ks2 = 0,
  so wood density costs only respiration per mass (∝ 1/rho). That is constant per volume.
  - g_rho went −38, −54, −67, −79, −107, −135, −196, −230 as ln rho fell by 0.7, with
    b* rising 4-fold.
  - There is no interior singular rho. The "interior optimum" in field-dimension-066 was
    the held-field invader optimum within its ±0.4 pool.
- **Schedule reruns.** 5 closed and 7 seasonal recordings were on the ratio-2 grading before
  its 11% error was found. Their traits were kept as the start of the regraded solve.
- **Broyden over three traits** learned lma well and hmat badly. Its restarts and caps cost
  about 4 recordings per regime against a Newton finish with J.
- **A logging bug in `one_shot.R`** overwrote the per-step log in `state.rds`. It is fixed
  now, and every recording was saved as `step_NNN.rds` regardless.
- **No pair.** Both strategies are ESS, so the split, the regularised ln b step, the
  coexistence checks and the pair's pricing were not run.

## Cost

Measured on a shared 16-core machine at load 4–24. Wall time is per process.

| phase | what | recordings (run + kept + cut sweep) | invaders | wall |
|---|---|---|---|---|
| diagnosis | uniform probes, node scaling, first-node location, grading, landscape checks | 9 + 7 resident-only runs | 119 replays without sweep, 1 with | ~1.3 h in 1–4 lanes |
| rho attempt | one-shot, 4 traits (failed: runaway) | 8 | — | 34 min |
| schedule rerun | closed and seasonal on ratio-2 grading | 5 + 7 | — | 22 + 23 min (parallel) |
| schedule check | 5 gradings at the start, 1 certification per root | 4 + 2 | — | 6–16 min each |
| **closed master** | **one-shot 11 + chord-Newton 3** | **14** | — | **117 min serial** |
| seasonal master | one-shot 14 + chord-Newton 2 | 16 | — | 106 min serial |
| classification | per root: 3 recordings with 2 swept invaders (H), 6 on the tangent (J), 2 for noise | 11 × 3 roots | 6 swept per root | 25 min wall each (~150–170 process-min) |
| pricing | 5 recordings, each replaying 9 invaders | 5 per root | 45 per root | 15 min wall |

One recording on 148 introductions took 2.0 min of run and 4.5 min of kept + cut sweep
unloaded (13.7–14.8 k ODE steps), or 3 + 7 min at load 16–24. An invader replay took
about 40 s, and its gradient sweep about 2 min.

## Files

- `common.R`: the stand, the schedule (`NODES`, `EARLY`, `EARLY_RATIO`), `record()` (one
  recording: F, F_lnb, F_θ, g, per ln trait through the trade-off), and `invade()`
  (invaders in a recorded field, with optional gradient). The kept and cut rows come from
  `census_backend()$trait_gradient` with `fix_field_in_last_sweep(TRUE)`.
  `stand_gradient()` cannot be used: it indexes rows by metric name, so a duplicated
  kept + cut metric collapses.
- `one_shot.R`, `polish.R`: the solve. `classify.R`: H, J and noise at a step.
  `price_mono.R`: pricing. `sched_check.R`: one recording on a given schedule.
  `summarize.R` writes `reference_<record>.rds` and `solve_history.rds`.
- `probe*.R` and `probes/`: the schedule diagnosis.
- Per-run files are in `/home/a/.claude/jobs/9d586e52/tmp/refcomm/runs/<run>/`.
- **Stack:**
  - plant `field-cut-066` 23998b54;
  - odelia `field-cut-066` 2d617c2;
  - phylloptim ef75769.

  All are installed -O2 in `/home/a/.claude/jobs/9d586e52/tmp/refcomm/rlib`.
