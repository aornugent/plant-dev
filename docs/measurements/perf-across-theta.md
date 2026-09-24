# A discretisation built at θ0, read across θ: TF24 fixture

**Configuration.** TF24 SCM, one species, `max_patch_lifetime = 40`,
`node_density_in_birth_date = TRUE`; forcing `long-drought`, aligned (a zero-depth
rainfall pulse at each of the 2931 active knots); `ode_tol_rel = ode_tol_abs = 1e-3`;
`establishment_window = 0.05`. `plant` at `6613dd24`, the built `-O2` worktree
`plant-adj`, loaded through `tg/tg2_common.R`; `plant-adj/src/plant.so` read
`2026-09-23 13:14:26.561414` before and after every batch.
`J = sum(scm$offspring_production)`. Reproduced first: default 108 `J = 12.117229796`
at 9917 steps (with and without the drop-one indicator), uniform 429
`J = 12.575093099` at 11 240 steps, both to every digit.

- **θ.** `lma` as a trait through the TF24 hyperparameterisation (it moves `lma`,
  `r_l`, `k_l`, `nmass_l`); `hmat` and `stem_P50` set directly on
  `p$strategies[[1]]$pars`. θ0: `lma = 0.32`, `hmat = 16.5958691`,
  `stem_P50 = 2.888726`.
- **Points (11).** θ0; `lma` × {0.7, 0.85, 0.95, 1.05, 1.15, 1.2}; `hmat` × {0.8, 1.1};
  `stem_P50` × {0.9, 1.25}. The requested ends `lma` × 1.35, `hmat` × 1.25 and
  `stem_P50` × 0.8 do not persist (§2) and were replaced by the narrower ones.
- **Reference.** `J_ref(θ)` = uniform 429 (`uniform_times(429)`) at each point, uniform
  857 at θ0 and the two `lma` ends. `e(θ) = J_fixed(θ) − J_ref(θ)`.
- **Schedules built at θ0**, node times held fixed across θ, time steps adaptive at each
  θ unless pinned:
  - `default 108`: `default_times(c(lma = 0.32))` (independent of `lma`);
  - `uniform 215`: `uniform_times(215)`;
  - `lean180`: the cost-weighted design built here (§3.1), 180 nodes. It was built
    because no hand-off existed when the runs started;
  - `cw108_100`, `cw108_220`: the schedule agent's hand-off in `perf/schedules/`,
    which arrived later. `cw108_100` is the leanest one at relative error ≈ 1e-3. Both
    were run at all 11 points.
- **Cost.** Accepted steps (`length(scm$ode_step_sizes)`), then CPU seconds of the R
  process (user + system). Four cores were shared by five agents, so wall seconds ran
  1.0–3.5× CPU and are not used.
- **Scripts.** All are in `perf/theta/`. Runs go through `th_common.R` (`run_T`: a copy
  of `run_J` that also sets the parameters, collects the drop-one indicator and keeps
  the recording), executed by `th_queue.R` from `queue*.txt`. Each run is saved as
  `out/<schedule>[_pin|_rec]@<point>.rds`. Tables come from `th_analyse.R` →
  `out/tables.rds` → `th_note_tables.R` (printed to `logs/note_tables.md`), plus
  `th_an_857.R`, `th_an_cor.R`, `th_an_pin2.R`, `th_an_ratio_check.R`,
  `th_an_drop1.R`, `th_elast.R`/`th_an_elast.R`, `th_design_explore.R`,
  `th_rebuild.R` and `th_rebuild_cw.R`. Logs are in `logs/`.

## The numbers

| | |
|---|---|
| **Parameters** | `hmat` (elasticity −7.84) and `stem_P50` (+6.47), from the adjoint on the default 108. `curv_fact_colim` (+51.3, value 0.99, bounded by 1) is excluded (§1). |
| **Persistence** | `J` < 1 on the default 108 at `lma` × 1.35 (0.820), `hmat` × 1.25 (0.540) and `stem_P50` × 0.8 (0.777). Over the box used, `J_ref` runs 3.68–52.1. |
| **The reference is not uniformly good** | uniform 429 against 857: **+1.2e-4 at θ0, −1.70e-3 at `lma` × 0.7, −6.8e-4 at `lma` × 1.2**. At the `lma` × 0.7 end its error is larger than the lean schedules' target of 1e-3. |
| **Fixed lean schedules hold** | `lean180` against 857: **−8.5e-4 / +5.9e-5 / −8.8e-4** at θ0 / `lma` × 0.7 / `lma` × 1.2. Against 429 at all 11 points: \|e\|/J ≤ 2.8e-3 (`lean180`), ≤ 5.4e-3 (`cw108_100`), ≤ 1.04e-3 (`cw108_220`). |
| **The default 108 does not hold** | e/J −3.6% at θ0, **−9.3% at `lma` × 0.7, +12.0% at `stem_P50` × 1.25**, −0.2% at `lma` × 1.2. It crosses zero inside the box. |
| **Gradient error** (secant of e over the secant of J, `lma`, against 857) | `lean180` +0.05% / −0.08%; `cw108_220` −0.29% / −0.06%; `cw108_100` −0.35% / −0.10%; uniform 215 +1.2% / +1.2%; default 108 **−12.1% / −5.0%**. The 429 reference's own is −0.26% / +0.04%. |
| **Rebuilt at θ is worse** | the same recipe rebuilt from θ's own run, against 857: `lean180` −2.2e-3 / −2.5e-3 against +5.9e-5 / −8.8e-4 fixed; `cw108_100` −7.8e-3 / +7.4e-3 against −2.1e-3 / +4.7e-3. |
| **Pinned θ0 step program** | J within **1.1e-3** of the adaptive run at every θ, and no run failed. **Its steps' error ratio, re-formed, is 6.3–12.3 at every θ ≠ θ0** (1.10 at θ0). 14–102 steps exceed 1.1, and 1–317 of 10 348 steps leave the model's domain at their pinned size. |
| **A pinned run forms no error estimate** | `error_ratio` is recorded as 0 and `error_index` as NA on every row. |
| **Metrics** | The Richardson estimate ranks \|e\|/J (Spearman 0.87 over four schedules pooled, median ratio 0.98), but not within `cw108_100` (0.38, 6× high). The drop-one maximum is set by the competition half at the node before the widest gap and does not track. The pinned ratio is a step, 1.1 → 6+. Dead-band edges move ≤ 0.09 yr. |

---

## 1. Parameters

The adjoint on the default 108 (`tg/out/adj_dyadic_108.rds`, every TF24 column,
`J = 12.117229796`), times the parameter's value at `lma = 0.32`, over `J`. Source:
`th_elast.R` → `elast.rds`, printed by `th_an_elast.R`.

| parameter | value | dJ/dθ | elasticity |
|---|---|---|---|
| `curv_fact_colim` | 0.99 | 627.394 | +51.259 |
| **`hmat`** | 16.5959 | −5.727 | **−7.844** |
| `lma` (column) | 0.32 | −269.02 | −7.104 |
| `r_l` | 287.853 | −0.297283 | −7.062 |
| **`stem_P50`** | 2.88873 | 27.1587 | **+6.475** |
| `vcmax_25` | 96 | 0.696523 | +5.518 |
| `rho` | 608 | −0.101113 | −5.073 |
| `a_y`, `a_bio` | 0.7, 0.0245 | 87.6198, 2503.42 | +5.062 each |
| `D_c` | 0.2 | 271.694 | +4.484 |
| `jmax_25` | 157.44 | 0.288172 | +3.744 |

- **Excluded.** `curv_fact_colim` is a co-limitation curvature at 0.99 with an upper
  bound of 1, so ×1.25 is outside its domain. `lma` and `r_l` belong to the `lma`
  trait, which moves them together. `S_D` (1.000) and `establishment_window` (+0.015)
  were excluded by the brief.
- **Chosen.** `hmat` and `stem_P50`, the next two by elasticity.
- **Set directly.** `stem_P50` is derived from `K_s` in the hyperparameterisation, so
  setting it directly moves `stem_P50` alone; `stem_c` stays at 2.04.
- **The `lma` trait**, chained through the hyperparameterisation: −4.19 on the default
  108 (−158.593 × 0.32 / 12.117; the chain is §6 of `tg/diag-establishment-window.md`). Along the box, `J_ref` falls from 38.59 to 3.68 over `lma` × 0.7 → 1.2, a mean
  elasticity of −4.4.

## 2. References and persistence

Uniform 429 at every point, uniform 857 at θ0 (`tg/out/fd_uniform_857.rds`) and the
two `lma` ends. Source: `th_analyse.R`, `th_note_tables.R`; persistence runs are
`default108@*` (`th_an_persist.R`).

| point | value | `J` uniform 429 | steps | CPU s | `J` uniform 857 | (J429 − J857)/J857 |
|---|---|---|---|---|---|---|
| θ0 | – | 12.5750931 | 11 240 | 314 | 12.5736263 | +1.17e-04 |
| `lma` × 0.7 | 0.224 | 38.5861400 | 10 864 | 301 | 38.6517096 | **−1.70e-03** |
| `lma` × 0.85 | 0.272 | 22.8941312 | 11 019 | 299 | – | – |
| `lma` × 0.95 | 0.304 | 15.4889484 | 11 154 | 307 | – | – |
| `lma` × 1.05 | 0.336 | 9.93625153 | 11 314 | 310 | – | – |
| `lma` × 1.15 | 0.368 | 5.41683483 | 11 539 | 320 | – | – |
| `lma` × 1.2 | 0.384 | 3.67786528 | 11 662 | 331 | 3.68036469 | **−6.79e-04** |
| `hmat` × 0.8 | 13.277 | 52.0871419 | 11 248 | 316 | – | – |
| `hmat` × 1.1 | 18.255 | 4.81491449 | 11 259 | 315 | – | – |
| `stem_P50` × 0.9 | 2.5999 | 5.07113163 | 11 157 | 313 | – | – |
| `stem_P50` × 1.25 | 3.6109 | 32.6854078 | **17 239** | 415 | – | – |

- **The reference's error grows away from θ0, and its sign flips.** It is +1.2e-4 at
  θ0, −1.70e-3 at `lma` × 0.7 (15× larger) and −6.8e-4 at `lma` × 1.2. At the interior
  points there is no 857, so an error of order 1e-3 in `J_ref` cannot be excluded
  there. Where §3 compares a lean schedule to 429, the difference is therefore at the
  reference's resolution. The three 857 points (§3.3) are the clean comparison.
- **`stem_P50` × 1.25 changes regime.** The reference takes 17 239 steps (+53%), and
  the dead bands mostly vanish: w(b) on the 429 nodes shows 2 of θ0's 9 (§5.4).
- **Persistence** on the default 108 at the requested ends: `lma` × 1.35 `J = 0.820`,
  `hmat` × 1.25 0.540, `stem_P50` × 0.8 0.777. The species does not replace itself
  there. The narrowed ends read 3.672 (`lma` × 1.2), 4.709 (`hmat` × 1.1) and 5.002
  (`stem_P50` × 0.9). The other ends read 35.0, 49.5 and 36.6.

## 3. Fixed schedules across θ

### 3.1 The lean design used

**`lean180`** was built from the θ0 uniform-857 run (`tg/out/fd_uniform_857.rds`)
(`th_design.R`, `th_design_explore.R`):

- **Density** ∝ (|w″|₅ / c)^(1/3). |w″| is the second difference of w on the 857 grid,
  averaged over 5 nodes; c(b) is the number of accepted steps after b. No floor.
- **Placement.** 180 nodes equidistribute that density over [0, 39.63]: 33 below
  b = 3, 82 in [3, 10), 59 in [10, 22), 6 at or after 22. The last interior node is at
  25.78, so the widest gap is 13.85 yr; the narrowest is 0.025 yr.
- **At θ0:** `J = 12.562906136` (−8.5e-4 against 857, −8.35e-4 against 12.5734) at
  10 349 steps and 186 CPU s. Uniform 429 costs 11 240 steps and 314 s.
- **Trials.** 120 nodes read +4.88e-3.

The hand-off schedules at θ0:

- **`cw108_100`** reads +7.1e-4 (10 332 steps, 106 CPU s). It is built from the
  uniform-108 pilot by the same density, floored at one node per 2 yr.
- **`cw108_220`** reads −5.4e-4 (10 544 steps, 228 s).

### 3.2 e/J_ref at every point

Source: `th_analyse.R` → `th_note_tables.R`.

| point | J_ref | default 108 | uniform 215 | lean180 | cw108_100 | cw108_220 |
|---|---|---|---|---|---|---|
| θ0 | 12.57509 | −3.64e-02 | +1.37e-02 | −9.69e-04 | +5.81e-04 | −6.72e-04 |
| `lma` × 0.7 | 38.58614 | −9.17e-02 | +1.42e-02 | +1.76e-03 | −4.47e-04 | −4.33e-04 |
| `lma` × 0.85 | 22.89413 | −6.80e-02 | +1.32e-02 | −1.20e-03 | −1.82e-03 | −7.51e-04 |
| `lma` × 0.95 | 15.48895 | −4.65e-02 | +1.33e-02 | −8.75e-04 | +1.98e-04 | −5.23e-04 |
| `lma` × 1.05 | 9.936252 | −2.79e-02 | +1.46e-02 | −7.64e-04 | +1.60e-03 | −6.84e-04 |
| `lma` × 1.15 | 5.416835 | −1.20e-02 | +1.77e-02 | −2.82e-04 | +3.78e-03 | −9.9e-07 |
| `lma` × 1.2 | 3.677865 | −1.57e-03 | +1.89e-02 | −1.99e-04 | +5.38e-03 | +3.07e-04 |
| `hmat` × 0.8 | 52.08714 | −4.93e-02 | +8.82e-03 | −2.96e-04 | −3.15e-04 | −1.73e-04 |
| `hmat` × 1.1 | 4.814914 | −2.20e-02 | +1.69e-02 | −1.23e-03 | +1.23e-03 | −6.41e-04 |
| `stem_P50` × 0.9 | 5.071132 | −1.37e-02 | +1.78e-02 | −8.26e-04 | +3.09e-03 | −3.68e-04 |
| `stem_P50` × 1.25 | 32.68541 | **+1.20e-01** | +1.85e-03 | +2.81e-03 | −3.50e-03 | +1.04e-03 |

Accepted steps at θ0 / range over θ (CPU s at θ0): uniform 429 11 240 / 10 864–17 239
(314); default 108 9917 / 9836–10 318 (132); uniform 215 10 921 / 10 581–13 886 (159);
`lean180` 10 349 / 10 134–13 048 (186); `cw108_100` 10 332 / 10 063–11 888 (106);
`cw108_220` 10 544 / 10 255–13 848 (228).

- **How |e| grows with distance.**
  - The **three lean schedules** show no growth that the reference can resolve.
    `lean180` ranges 2e-4 to 2.8e-3 of J with no trend along `lma`. Its value
    at `lma` × 0.7, +1.76e-3 against 429, is +5.9e-5 against 857 (§3.3).
  - **Uniform 215** holds 0.9–1.9e-2 except at `stem_P50` × 1.25 (1.9e-3).
  - **The default 108's error grows with distance from θ0 and changes sign.** It is
    −3.6e-2 at θ0 and −9.2e-2 at `lma` × 0.7, then passes through zero near
    `lma` × 1.2 and reaches +1.2e-1 at `stem_P50` × 1.25.
- **Is e smooth in θ.**
  - For the default 108 and uniform 215, e is monotone along `lma`. Its θ-dependence is
    far above the reference's resolution.
  - For the lean schedules, e(θ)/J moves non-monotonically at the 1e-3 level. That is
    the size of the reference's own error (§2) and of the time grid's contribution
    (pinned against adaptive up to 1.1e-3, §4). At this resolution the shape of a
    lean schedule's e(θ) is not measured.

### 3.3 Against uniform 857, at the three points that have it

Source: `th_an_857.R` (`logs/an_857.log`). The J857 secants are −271.647 over
`lma` 0.224 → 0.32 and −138.957 over 0.32 → 0.384.

| schedule | e/J at `lma` × 0.7 | at θ0 | at `lma` × 1.2 | gradient error, lower half | gradient error, upper half |
|---|---|---|---|---|---|
| default 108 | −9.33e-02 | −3.63e-02 | −2.25e-03 | **−12.1%** | **−5.0%** |
| uniform 215 | +1.25e-02 | +1.38e-02 | +1.82e-02 | +1.19% | +1.20% |
| uniform 429 | −1.70e-03 | +1.17e-04 | −6.79e-04 | −0.26% | +0.04% |
| **lean180** | **+5.91e-05** | **−8.53e-04** | **−8.78e-04** | **+0.05%** | **−0.08%** |
| cw108_100 | −2.14e-03 | +6.98e-04 | +4.70e-03 | −0.35% | −0.10% |
| cw108_220 | −2.13e-03 | −5.56e-04 | −3.73e-04 | −0.29% | −0.06% |

The gradient error is the secant of e over the secant of J: the relative error in
dJ/dlma an optimiser differencing that schedule would see over that half of the axis.

- **`lean180` stays within 8.8e-4 of J across the `lma` box**, with a gradient error of
  0.05–0.08%.
- **The hand-off schedules stay within their θ0 level on the upper half, and reach
  2.1e-3 at `lma` × 0.7.**
- **The default 108's gradient error is 5–12%.** At θ0 its fixed-grid pinned central
  difference, −158.76 against −172.52 (`tg/diag-establishment-window.md` §5), is −8.0%,
  between the two secants.
- **The secants on the other axes**, against 429 (`th_note_tables.R`, "secants"):
  - default 108: −5.3% / −4.5% on `hmat` and −5.2% / **+21.8%** on `stem_P50`;
  - uniform 215: +0.7% to +1.2%, and −0.56% on `stem_P50` up;
  - the lean schedules: ≤ 0.61% in magnitude, with the 429 reference's own error of
    the same order.

### 3.4 The same recipe rebuilt at θ

Each design was rebuilt from θ's own run, at the same node count:

- `lean180` from uniform 857 at θ, by `th_rebuild.R`. Median node shift 0.85–0.91 yr,
  largest 2.7 yr.
- `cw108_100` from uniform 108 at θ, by `th_rebuild_cw.R`, which carries a copy of the
  hand-off recipe. The copy rebuilds `cw108_100` from its own pilot to 0 yr. Median
  node shift 0.52–0.54 yr.

For uniform 215 and the default 108 the recipe does not depend on θ, so the rebuilt
schedule is the fixed one.

| schedule | point | e/J fixed (θ0 design) vs 857 | e/J rebuilt at θ vs 857 | steps fixed | steps rebuilt |
|---|---|---|---|---|---|
| lean180 | `lma` × 0.7 | +5.9e-05 | **−2.19e-03** | 10 134 | 10 222 |
| lean180 | `lma` × 1.2 | −8.8e-04 | **−2.45e-03** | 10 561 | 10 517 |
| cw108_100 | `lma` × 0.7 | −2.14e-03 | **−7.76e-03** | 10 063 | 10 133 |
| cw108_100 | `lma` × 1.2 | +4.70e-03 | **+7.42e-03** | 10 484 | 10 559 |

**Rebuilding at θ made the error larger at all four.** At a fixed node count the recipe
does not set the error. Which cancellations the node placement happens to produce does,
and the schedule agent notes this at θ0 as well: `cw108` is not monotone in the count.
Keeping θ0's design was at least as accurate as re-deriving it.

## 4. The time grid across θ

At each θ, `lean180` was run with `p$ode_times` set to its θ0 run's 10 349 step times
(`lean180_pin@*`). Each interval is then stepped to its recorded time by `step_to`.
The comparison is the same schedule on adaptive steps at θ. Source: `th_analyse.R`,
`th_an_pin2.R`.

**Does a pinned run form the embedded error estimate? No.**

- **In the code.** `step_to` and `step_by` call `forget_error_component()` and never
  call `adjust_step_size`. The Cash–Karp `yerr` is computed but never weighted.
  `ode_step_attempts` counts nothing on a pinned run.
- **In the record.** `store_trajectory()` on the pinned θ0 run records
  `error_ratio = 0` and `error_index = NA` on all 13 460 rows.
- **Re-formed.** The estimate was therefore re-formed step by step (`th_ratio.R`). Each
  recorded step is re-taken from its recorded start on a `Patch` built at θ, through
  `Patch$derivs`, with odelia's tableau and weighting (`a_y = 1`, `a_dydt = 0`).
- **Validation on the adaptive θ0 run** (`th_an_ratio_check.R`, 10 348 steps):
  - re-formed against recorded ratio: median relative difference 1.9e-8, 99th
    percentile 9.8e-3;
  - the same component in 99.87% of steps, and the largest ratio 1.097633 in both;
  - the re-formed end state matches the recorded one to 8.0e-12.

| point | J adaptive | (J pinned − J adaptive)/J | steps adaptive | steps pinned | CPU adaptive / pinned | steps invalid at their pinned size | largest ratio | steps > 1.1 | > 2 |
|---|---|---|---|---|---|---|---|---|---|
| θ0 | 12.5629061 | +9.3e-07 | 10 349 | 10 349 | 186 / 158 | 0 | 1.10 | 0 | 0 |
| `lma` × 0.7 | 38.6539958 | −2.0e-05 | 10 134 | 10 349 | 180 / 155 | 49 | 9.03 | 94 | 38 |
| `lma` × 0.85 | 22.8667104 | −1.43e-04 | 10 240 | 10 349 | 180 / 154 | 38 | 6.64 | 51 | 19 |
| `lma` × 0.95 | 15.4754009 | −1.72e-04 | 10 320 | 10 349 | 182 / 155 | 24 | 6.65 | 39 | 16 |
| `lma` × 1.05 | 9.92865546 | +4.87e-04 | 10 413 | 10 349 | 185 / 157 | 58 | 6.62 | 83 | 31 |
| `lma` × 1.15 | 5.41530511 | +8.1e-05 | 10 537 | 10 349 | 188 / 161 | 124 | 10.4 | 78 | 30 |
| `lma` × 1.2 | 3.67713343 | +8.39e-04 | 10 561 | 10 349 | 190 / 164 | 145 | 11.0 | 93 | 39 |
| `hmat` × 0.8 | 52.0717280 | −3.6e-05 | 10 360 | 10 349 | 186 / 157 | 13 | 6.50 | 49 | 23 |
| `hmat` × 1.1 | 4.80899030 | +1.5e-05 | 10 343 | 10 349 | 187 / 157 | 1 | 6.25 | 14 | 9 |
| `stem_P50` × 0.9 | 5.06694505 | −1.02e-04 | 10 294 | 10 349 | 187 / 159 | 28 | 7.85 | 102 | 36 |
| `stem_P50` × 1.25 | 32.7773961 | **−1.07e-03** | 13 048 | 10 349 | 214 / 229 | **317** | 12.3 | 88 | 36 |

The "> 1.1" column counts finite ratios. The invalid steps are counted separately:
they have no ratio at their pinned size.

- **J.** Every pinned run completed. J is within 2e-4 of the adaptive run at 6 of the
  10 points, and 4.9e-4, 8.4e-4 and 1.07e-3 at `lma` × 1.05, × 1.2 and `stem_P50` ×
  1.25. Those are the size of the lean schedule's own node error.
- **Cost.** The pinned program is 15% cheaper in CPU (no rejected attempts), except at
  `stem_P50` × 1.25, where it is 7% dearer.
- **Invalid steps.** At every θ ≠ θ0, 1–317 steps put a stage outside the model's domain
  at their pinned size ("TF24 storage is negative"). `step_to` subdivides such an
  interval silently, and nothing counts it. The first one sits at t = 0.57–23.6.
- **The error ratio.** **At `lma` × 0.95 and × 1.05, 5% from θ0, the largest re-formed
  ratio is already 6.6**. It is 6.3–12.3 over the whole box, against 1.10 at θ0.
  - Where: the largest ratio sits in the environment block (soil water) at 8 of the 10
    points and in the averaged gate `E` at `lma` × 0.7 and `stem_P50` × 1.25.
  - Which components: among steps over 1.1, 51–82% are in the environment and 10–40%
    in `E`, and the nodes take the rest.
  - How many: the 99th percentile stays at 0.99–1.10, so it is 0.1–1% of the steps.

## 5. Conditioning metrics

Each metric is computed on the fixed schedule at θ, from the same run or one more:

- **(a) Richardson.** (J_half − J)/3, where J_half is the same schedule with every other
  node dropped (`coarsen()`, one more run; for uniform 215 this is uniform 108). There
  is no half run for `cw108_220`.
- **(b) Drop-one.** `scm$collect_refinement_errors <- TRUE`; read the maximum of
  `refinement_error_by_node` and the sum of its reproduction half,
  `net_reproduction_ratio_errors`.
- **(c) The pinned θ0 program's largest ratio** (§4), for `lean180` only.
- **(d) Shape.** The movement of w(b)'s shape: the TV distance of w/J from θ0's on the
  same schedule, the shift of the 99% birth date, and the shift of the dead-band edges.

### 5.1 Per point, `lean180`

| point | \|e\|/J | (J_half − J)/3/J | drop-one max | drop-one repro sum | largest pinned ratio | TV to θ0 | b99 shift, yr | band-edge shift, yr |
|---|---|---|---|---|---|---|---|---|
| θ0 | 9.69e-04 | −3.03e-04 | 0.664 | 0.0145 | 1.10 | 0 | 0 | 0 |
| `lma` × 0.7 | 1.76e-03 | −1.28e-03 | 0.697 | 0.0281 | 9.03 | 0.112 | +2.23 | 0.089 |
| `lma` × 0.85 | 1.20e-03 | −6.26e-04 | 0.691 | 0.0207 | 6.64 | 0.056 | +1.58 | 0.067 |
| `lma` × 0.95 | 8.75e-04 | −2.78e-04 | 0.673 | 0.0166 | 6.65 | 0.022 | +0.46 | 0.027 |
| `lma` × 1.05 | 7.64e-04 | −2.34e-04 | 0.649 | 0.0136 | 6.62 | 0.030 | −0.43 | 0.027 |
| `lma` × 1.15 | 2.82e-04 | −3.1e-05 | 0.613 | 0.0117 | 10.4 | 0.101 | −1.01 | 0.026 |
| `lma` × 1.2 | 1.99e-04 | +3.02e-04 | 0.595 | 0.0105 | 11.0 | 0.111 | −1.22 | 0.033 |
| `hmat` × 0.8 | 2.96e-04 | −3.40e-04 | 0.704 | 0.0217 | 6.50 | 0.081 | +2.31 | 0.023 |
| `hmat` × 1.1 | 1.23e-03 | −3.72e-04 | 0.631 | 0.0134 | 6.25 | 0.086 | −0.92 | 0.011 |
| `stem_P50` × 0.9 | 8.26e-04 | −1.37e-04 | 0.639 | 0.0127 | 7.85 | 0.060 | −0.79 | 0.050 |
| `stem_P50` × 1.25 | 2.81e-03 | −2.39e-03 | 0.131 | 0.0304 | 12.3 | 0.136 | +1.86 | 0.019 |

The other schedules' rows are in `logs/note_tables.md`. Here |e| is against 429; §2
gives the caveat.

### 5.2 Correlations, on the relative scale

Metric/J against |e|/J, n = 11 per schedule. Source: `th_an_cor.R`, `logs/cor_rel.log`.
Spearman ρ; the ratio is the median of metric/(|e|/J).

| metric | default 108 | uniform 215 | lean180 | cw108_100 | cw108_220 | pooled (n) | pooled median ratio |
|---|---|---|---|---|---|---|---|
| (a) Richardson | **0.96** | 0.21 (log-Pearson 0.84) | **0.77** | 0.38 (ratio 6.2) | – | **0.87** (44) | 0.98 |
| (b) drop-one max | 0.94 | −0.75 | 0.09 | −0.80 | 0.32 | −0.33 (55) | 221 |
| (b) drop-one repro sum | 0.94 | −0.81 | 0.69 | −0.65 | 0.43 | 0.81 (55) | 15 |
| (c) largest pinned ratio | – | – | −0.05 | – | – | – | – |
| (d) TV of w/J to θ0 | −0.07 | 0.09 | 0.17 | 0.46 | −0.20 | 0.00 (55) | – |
| (d) band-edge shift | 0.06 | 0.23 | −0.06 | 0.08 | −0.15 | 0.00 (55) | – |

Against the change |e(θ) − e(θ0)|/J, n = 10:

- (a) Richardson: 0.08–0.28 per schedule, 0.78 pooled.
- (c) pinned ratio: 0.83 for `lean180`.
- (d) TV: 0.44–0.84 (`lean180` 0.84, default 108 0.78).
- (b) the drop-one maximum: −0.36 to −0.70.

### 5.3 What each metric reads

- **(a) Richardson** ranks schedules by their error across the box (pooled ρ 0.87,
  median ratio 0.98). Within a schedule it follows |e| for the default 108 and
  `lean180`.
  - It does not follow `cw108_100`, where it reads 6× high: its 51-node half is 2.9%
    off at θ0 while the schedule sits in a cancellation.
  - It does not track how e moves away from θ0 within a schedule.
- **(b) Drop-one.** The combined maximum is set by the competition half at every node
  but the two ends, on each schedule checked (`th_an_drop1.R`).
  - On `lean180` the maximum is the node before the 13.85-yr gap (b = 25.78: 0.66 at
    θ0), 200–800× |e|/J. On the default 108 it is b = 8 (0.31); on uniform 215 it is
    b = 0.19 (0.14).
  - Its θ-dependence follows w's magnitude near those nodes, not the schedule's error.
    The reproduction half's sum tracks |e| on the default 108 (0.94) and `lean180`
    (0.69), and runs against it on uniform 215 and `cw108_100`.
- **(c) The pinned ratio** jumps from 1.10 at θ0 to 6.25–12.3 at every other point,
  including the 5% ones. It says the step program has left its tolerance. It does not
  say how wrong J is: J stays within 1.1e-3 of the adaptive run (§4).
- **(d) Shape.** w(b)'s mass moves with θ: the 99% birth date moves by −1.22 to
  +2.31 yr, and the TV distance to θ0 is 0.02–0.14. The TV follows the change
  |e − e0| (0.44–0.84) but not |e|.

### 5.4 The dead bands: where the weather puts them

Dead bands are stretches after b = 3 where log₁₀ w sits more than one decade below its
running maximum over the preceding year. They are read on the uniform-429 nodes (spacing
0.0926 yr), with edges interpolated (`th_shape.R`, `th_analyse.R`); the second peak and
w(0)/J are read on `lean180`'s nodes. At θ0 there are 9,
opening at 3.65, 7.50, 9.96, 12.59, 14.58, 17.67, 18.50, 20.76 and 21.73 yr.

| point | bands | matched to θ0's | largest edge shift, yr | median edge shift, yr | second peak b (θ0 7.977) | w(0)/J |
|---|---|---|---|---|---|---|
| `lma` × 0.7 | 9 | 9 | 0.089 | 0.011 | 7.946 | 1.57 |
| `lma` × 0.85 | 9 | 9 | 0.067 | 0.007 | 7.946 | 1.45 |
| `lma` × 0.95 / × 1.05 | 9 / 9 | 9 / 9 | 0.027 / 0.027 | 0.003 / 0.002 | 7.977 | 1.33 / 1.42 |
| `lma` × 1.15 / × 1.2 | 9 / 10 | 8 / 8 | 0.026 / 0.033 | 0.003 / 0.005 | 7.946 | 1.67 / 1.75 |
| `hmat` × 0.8 / × 1.1 | 9 / 10 | 9 / 9 | 0.023 / 0.011 | 0.002 / 0.001 | 7.977 / 7.946 | 1.26 / 1.64 |
| `stem_P50` × 0.9 | 10 | 9 | 0.050 | 0.004 | 7.946 | 1.49 |
| `stem_P50` × 1.25 | **2** | 1 | 0.019 | 0.015 | **7.252** | 1.60 |

**Across the box the band edges move less than one reference node spacing** (≤ 0.089 yr
against 0.093). The gate's timing is the weather's. What moves is the weight w puts on
the bands and around them (b99, TV), and at `stem_P50` × 1.25 most bands are no longer
deep enough to count.

## 6. Against the expectations

- **"A schedule built at θ0 holds its accuracy over some neighbourhood."**
  - Held, for the three lean schedules, over the whole box measured (§3.2, §3.3), with
    a gradient error under 0.4% on the `lma` axis.
  - **Contradicted for the default 108**, whose error doubles by `lma` × 0.7 and flips
    to +12% at `stem_P50` × 1.25. Its gradient error is 5–22%.
- **"The gate's timing is mostly the weather's, so a lean schedule may transfer
  widely."**
  - The first half held: the band edges move ≤ 0.09 yr (§5.4).
  - The lean schedules transferred, but rebuilding at θ did not improve them (§3.4).
    At a fixed count their error is set by placement cancellations, not by how far w
    has moved.
- **"A pinned step program transfers across wide boxes."**
  - **Contradicted as a statement about the step program.** It is out of tolerance
    (largest ratio 6.3–12.3) at every θ ≠ θ0, including 5% from θ0.
  - It puts 1–317 stages outside the model's domain, and `step_to` repairs those
    silently.
  - It held for J: within 1.1e-3 at every point, and no run failed.
- **"The Richardson estimate tracks the error."**
  - Held across schedules (pooled ρ 0.87, median ratio 0.98), and within the default
    108 (0.96) and `lean180` (0.77).
  - **Contradicted within the leanest hand-off, `cw108_100`** (ρ 0.38, 6× high), and
    for the change of e away from θ0 within any schedule (ρ 0.08–0.28).
- **The reference was expected to be good to about 1e-4 across the box.** It is not:
  uniform 429 is 1.7e-3 off at `lma` × 0.7 (§2). Below about 1e-3, the lean
  schedules' errors are resolved only at the three 857 points.

---

## What was not reached

- **A reference good to 1e-4 at every point.** Uniform 857 exists only at θ0 and the two
  `lma` ends; `hmat`, `stem_P50` and the `lma` interior are referenced by 429 alone.
  Uniform 1713 was not run away from θ0, so 857's own error at the ends is unmeasured.
  This limits every lean-schedule number below about 1e-3 away from those three points,
  including the smoothness of e(θ) and the correlations in §5.2.
- **The `stem_P50` × 1.25 regime.** Why the step count rises 53% and most dead bands
  vanish was not taken apart. The reference there has no 857 check.
- **The lean recipe rebuilt at `hmat` or `stem_P50` points.** It was rebuilt only at the
  two `lma` ends, where 857 runs existed.
- **Richardson for `cw108_220`.** Its half-node runs were not made.
- **Gradient error from a fixed discretisation's adjoint.** The gradient errors here are
  secants of adaptive-step runs over 5–25% intervals. No pinned central difference or
  adjoint was taken at θ ≠ θ0.
- **The cost of the silent subdivisions** in pinned runs (1–317 intervals). Their
  sub-step counts are not recorded by `step_to`.
- **A combined trust-region rule.** A rule pairing a shape metric (TV, which tracks
  |e − e0|) with Richardson (which tracks |e| across schedules) was not formed or
  tested.
