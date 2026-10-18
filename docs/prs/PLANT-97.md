# PLANT-97: a week on the storage pool's relaxation time, and its stage guard out

Branch `PLANT-97` on aornugent/plant, one commit on `develop` (bd09645d). It closes #97
and #98. **It changes TF24's model** (v11 -> v12, TF24f v11.1 -> v12.1). Review notes:
`docs/prs/PLANT-97-review.md`.

plant's PR template puts two short paragraphs in the description, which become the squash
commit, and the measurements in the first comment. Both are below.

## Description

A seedling's storage pool relaxes over `storage_max/(charge + drain)`, which is hours,
while the stepper takes steps of days. An explicit step overshoots the pool and the stage
check throws. The resident shrinks the step and retries it. An invader walks the
resident's steps, cannot shrink one, and fails. TF24 gains `storage_relaxation_offset`
(7 days, a gradient column), which is added to that time: the rate is divided by
`1 + (charge + drain) * offset / storage_max`. The equilibrium and the sign at each bound
are unchanged, and a negative offset is refused. Once a seedling's production turns
negative, its relative reserve now decays with e-fold time `offset`. Its reserves run down
over `offset * ln(a_st3 * a_dG2)` = 19.4 d instead of hours.

The stage check and `storage_domain_tol` are removed. A stage below empty keeps finite
rates, so the error estimate rejects the overshoot, and `non_negative_states()` still
refuses a step that ends below empty. TF24 results change. A zero offset gives v11's
rates, but a run where the old check fired still steps differently.

Closes #97, closes #98

## First comment: the case

### The problem, in the model's terms
- A seedling's pool relaxes at `lambda = (charge + drain)/S_max`, up to 1444 yr^-1
  (about 6 h), against daily forcing (`docs/archive/scope-imex-stepper.md` §3).
- On develop's 40-year long-drought stand (108 nodes, birth date, `ode_tol` 1e-3), the
  resident throws 993 stages below empty. An invader at `lma` x2 is refused at its first
  step (measured here, table below).

### The mechanism
- The flow's relaxation rate becomes `lambda/(1 + lambda*o) <= 1/o`. At `o` = 7 d,
  explicit (Cash–Karp) steps are stable to 3.73·o, about 26 d, and stay non-negative to
  2.16·o, about 15 d (scope-imex-stepper.md §3, *Result*).
- After `P < 0` a seedling has `drain/S_max` of order hours^-1, so `dr/dt ≈ -r/o`. Its
  reserves fall from `a_st3` to the hazard's e-fold point `1/a_dG2` in
  `t_r = o ln(a_st3 a_dG2) = 7 d × ln 16 = 19.4 d`, whatever its size. With `o = 0` that
  time is `S_max/drain`: hours, and set by size (`docs/measurements/schedule-search/
  rootcause/evidence/notes.md`, Round 5; review `stack/A-plant-93-101.md`).
- With the guard out, a stage below empty is just an overshoot. Its rates stay finite and
  point back into the domain, so the error estimate rejects it like any inaccurate step.
- One state reaches the domain check: the step's end, through `Patch::ode_state_valid()`.
  The adaptive stepper rejects a bad end, a pinned step subdivides, and a walk fails.

### Measured gain: re-measured on develop + this branch
`harness/long_drought.R` stand. One probe build counts thrown stages and refused step
ends; it is not part of the PR. Three runs, one at a time:

| long drought, 108 nodes, birth date, tol 1e-3 | v11 (offset 0, check on) | offset only (check on) | this PR |
|---|---|---|---|
| offspring production `J` | 13.348750 | 13.773991 (+3.19%) | 13.762608 (+3.10%) |
| accepted steps | 10 550 | 9 329 | 9 262 |
| thrown stages (resident) | 993 | 192 | 0 |
| step ends refused | 0 | 0 | 25 |
| wall time (shared cores) | 191 s | 169 s | 168 s |
| invader `lma` x2 on the resident's steps | refused at its first step | refused at its first step | runs (`J'` 1.9e-21) |
| invaders x0.9, x1.2 | — | — | run (`J'` 61.0, 0.076) |
| invader x0.7 | fails: leaf solve (`stem_curve_domain`) | same | same |

- x0.7 fails in phylloptim's leaf solve after walking most of the run, in all three
  builds. So that failure is not the pool's. On the archived stack x0.7 ran
  (`docs/assessment.md`, *(b) as measured*). That stack also had exact establishment and
  the invader-field changes, which develop lacks.
- On the test fixture's birth-date stand, invaders x0.7 and x2 run. At a zero offset x2
  overflows its density (new test, below).

### Cited from the archived stack (not re-measured)
Measured on archive/stack-2026-10-18/PLANT-97 and -98 (exact establishment, the earlier
stepper):
- `J` +2.0 / +2.6 / +2.7% at 108 / 215 / 429 nodes (12.4167 -> 12.6656 at 108).
- `dJ/dlma` -168.556 -> -195.988 by adjoint (pinned central difference -168.462 ->
  -195.975), and `dJ/do` -22.074.
- Thrown stages 759 -> 149 (scope-imex-stepper.md §3, *Result*), then 149 -> 0 with the
  guard out, and invaders x0.7 to x2 ran (`docs/assessment.md` *(b)*;
  `docs/handover.md` step 2(b)).

Why develop's numbers differ:
- Develop has point-sampled establishment and upstream's later stepper (odelia 0.7.3,
  #662), so its base `J` is 13.35 against 12.42, and it throws 993 stages against 759.
- The move in `J` is +3.1% here against +2.0%.
- `dJ/dlma` could not be re-measured: develop does not offer TF24's offspring production
  as a differentiable metric (#658, "TF24's metrics are unchanged").

### What it costs
- Model: +23/-26 lines in `tf24_strategy.h`, which add one parameter and delete the
  guard. Bindings: +5/-1, generated.
- Runtime: 12% less wall time on long drought (191 -> 168 s), with 12% fewer accepted
  steps.
- References moved, all re-blessed in this commit:
  - "offspring arrival", five-year pins. Height: 24.321 -> 18.598 (-23.5%) and 18.543 ->
    14.104 (-23.9%). Birth date: 219.27 -> 212.02 (-3.3%) and 34.588 -> 32.987 (-4.6%).
    The height coordinate's probe amplifies any change to the pool.
  - TF24's seeded stochastic count, 77 -> 79. At a zero offset it is 77, and that is now
    pinned.
  - The model-version snapshot (v12, v12.1, the new parameter).
  - `reference-gradient.tsv`, recaptured with `scripts/capture-reference-gradient.R`:
    - 30 new rows for the new column.
    - 91 of 1380 rows move by more than 1e-3 of their metric's scale.
    - The largest moves are `theta` and `omega` on `leaf_area` on the drought and
      seasonal stands, e.g. seasonal sp 2 `theta` 239.06 -> -1511.01. These stands'
      seedlings are where the divisor binds, and `theta` sets the storage capacity the
      divisor reads.
    - Every moved row's step ladder is converged (spread <= 1.1 on values of order
      1e3), and the whole-run rung passes against the sweep.
  - The capture script had called `census_metric_names_tf24()` without the run since
    #658. Its unused metric count is dropped (-1 line).
- TF24f's convergence check now compares against TF24 at `tol` 1e-6. At the default
  tolerance, TF24's own error (0.21%) exceeds TF24f's lag at `k_acclim` = 100 (0.04%).
  The gap table is re-measured.

### How it is tested
- New tests:
  - The divisor's form, to 1e-12 against a hand computation, with the offset binding
    (`own_rate * o > 5`).
  - The relaxation rate falls from about 380 to 55 yr^-1 against `1/o` = 52.
  - A negative offset is refused.
  - A stage below empty has finite rates that refill the pool.
  - Invaders x0.7 and x2 run on the run's steps; at a zero offset, x2 overflows.
- The relaxation-timescale and height-linear tests are posed at a zero offset, so they
  still test what they did.
- Full serial suite on this branch, built at `-O2` against odelia 0.7.3 and phylloptim
  0.10.2: see the commit. Results: 5455 passed, 0 failed (4 skips). The 1 error is
  `test-ff16-ad-kernel.R`, which errors the same way at develop: its `sourceCpp` build
  fails in this sandbox. FF16's bit-identity guards are green.

### What a reviewer should check
1. That 7 days is acceptable as the science default. It is a declared parameter, and
   `o = 0` recovers v11's rates. It sets `t_r` and every TF24 number.
2. That the step-end refusal in `Patch::ode_state_valid()` is enough without a stage check:
   - the adaptive path rejects;
   - a pinned step subdivides;
   - a walk fails by name.
3. The re-blessed whole-run reference rows on theta and omega (drought, seasonal). They
   are converged differences of the new model, not noise.
