# Handover

For the session that tests the performance Oracle's answer. Read, in this order:
- `oracle-response-solver-performance.md`, the answer, verbatim;
- `oracle-consultation-solver-performance.md`, the statement it answers. Its T/R/S/Θ/A labels are the measurements the answer cites;
- `oracle-consultation-guide.md`, the rules for any further consult: domain-free, no candidate fixes, open questions, and test before acting.

## The answer in brief

Both grids are being bent to compensate for two earlier choices. Fix those, and neither grid needs to adapt; only the error weighting does, and the sweep already supplies it.

1. **One explicit pair integrates a stiff, cheap subsystem and a slow, expensive one.**
   - *The mechanism.* The chain (soil) and each new member's pool (storage) set the step through their stability limits, and the member loop pays at every stage. Stages walking that limit overshoot the chain's clamps and switches. Members evaluated there commit errors below `atol`, in the components that carry `J`. That is the tolerance-blind time error (T5, T6).
   - *The fix.* An additive RK pair, ARK4(3)6L[2]SA (Kennedy–Carpenter):
     - implicit: the chain's drainage and inflow, and every pool;
     - explicit: everything else, including `a` and `Φ`.
   - *Why it's cheap.* Same six stages, so the recording keeps its shape. The chain's stage solve is five monotone scalar roots, layer by layer, and each pool's is a division. The sweep needs a transposed bidiagonal solve and a scalar per pool, and no member Jacobian.
   - *With it.* One rate evaluation per entry; the proposal carried across knots; the step program pinned from a pilot.
   - *Predicted.* 3.4–6.7k steps, no rejections or throws: 2.5–4× at a fixed schedule.
2. **A member's weight is a point sample of `βE`.** Its ramps are 18–40δ wide at 56 places, sampled at 34δ.
   - *The fix.* Two accumulators per species, `M₀ = ∫βE` and `M₁ = ∫b·βE`. Members carry unit density, and product-integration (hat-basis) weights replace `ω_j n_j(b_j)`.
   - *The remaining error* is `O(Δb²·T''·M₀)`: smooth, valid for Richardson, and the gradient converges at `J`'s rate.
   - *The schedule* is fixed from one pilot at θ0, about 120–160 members:
     - ~35 panels in `[0, 3.56)`;
     - in `[3.56, 16)`, a node at each date that ends a deep band, one ~`τ_g` inside it, and spacing 0.15–0.25 between;
     - ~0.5 to `b = 22`, and 1–2 after.
   - Retire `refine_schedule`'s algorithm, not the idea of adapting: see "The requirement" below.

**Across θ.**
- *Fixed:* the schedule and the stops. The step program is pinned within an epoch.
- *Adapts:* re-pin the program when its certificate fails, and re-grade only when the bands change regime.
- *Certificates:*
  - the embedded ratio re-formed on the pinned program;
  - the adjoint-weighted time error `Σ λ_nᵀ est_n` (Cao–Petzold);
  - the `g`-defect;
  - along-step consistency: `J(θ_{k+1}) − J(θ_k)` against the trapezoid of the two sweep gradients.
- *Accuracy needed:* relative gradient error `ε ≤ 1e-2` is ample. Consistency matters more.

**Floors.**
- About `2e6` member evaluations, 10× under today, with exact coupling at every stage. Below that, members must skip stages, which means a tape redesign.
- The model's `C⁰` switches make `J_h` piecewise smooth in θ. The 3.4% sweep–secant gap (A3) is that floor. If it stays above ~1e-2 after the fixes, smoothing the switches is a modelling decision.

**Independent lever.** Warm-start the inner problem from the previous stage. The claim is 3–5× per member evaluation, with the tape unaffected.

## The requirement: one controller for every scenario

The user wants a control algorithm that is optimal for short and long horizons,
for constant, impulsive and composed rainfall, and across a wide range of traits.
A design for one fixture does not meet that.

**What generalises from the answer.** Each of these is independent of the record
and the traits:
- the implicit–explicit split: the stiffness is the soil's and the storage's
  physics, not the record's;
- exact establishment masses: the gate's ramps leave the cohort grid for any
  record;
- one evaluation per entry, and warm-started inner solves;
- error weights from the adjoint, which measure error in `J`'s units in any
  scenario.

**What does not.**
- The placement rules: band-ending dates, 0.15–0.25 spacing, the `b = 22` cut,
  "~35 panels early". They are read off this fixture, where early cohorts carry
  88% of `J`.
- "Re-grade only on a band-regime change".
- A step program pinned from one pilot without its certificate checked.
- The assumption that value per unit mass is smooth at a pilot's resolution. It is
  what failed at 0.04× (A5), and under impulsive records a newborn's value can jump
  across a storm.

**The general controller to build and test.** This is what replacing
`refine_schedule` means:
1. Take a pilot from the record's own feature scales, with exact masses.
2. Run one forward pass and one sweep, giving two error maps in `J`'s units: the
   adjoint-weighted local error per step, and the `g`-defect per panel.
3. Place members by equidistributing estimated error per unit cost, with
   coarsening. Balance the time and schedule budgets by their marginal cost.
4. Certify with those estimates, plus Richardson checkpoints.
5. In an optimisation, keep the discretisation while the certificate holds and
   rebuild when it fails.

This is asymptotically optimal to a constant factor for a given cost model, once
the pilot resolves the features. Below that regime optimality can only be
benchmarked.

**The benchmark comes before the design is called general.**
- *Records*, each recalibrated so the stand persists (`J` well above 1): constant,
  seasonal, intermittent Markov (`gen_rain_mix` in `tg/ld_common.R`), impulsive
  storms, long drought, wet–dry whiplash, and composed.
- *Horizons*: 5, 10, 40 and 100.
- *Traits*: a Latin hypercube within persistence, plus one near-extinct control to
  document the conditioning limit.
- *Measured in each*: the certified error against its target; the cost against the
  best brute-force schedule (uniform ladders and band fills); how often the
  certificate rebuilds along an optimisation path; and the failures.
- *Per-scenario risks*:
  - constant: a permanently stiff wet steady state;
  - impulsive: the one-step-per-leg floor;
  - long horizon: members accumulate, so retiring them with a bound is needed;
  - wide traits: regime changes and near-extinction.
- *Prior bank.* The multirate branch's six-scenario bank
  (`perf/profile/branchdocs/docs_tf24-v2-T6-slice4-scenario-bank-result.md`) left
  the stand near extinction on every trace, and crashed the explicit pair on three.
  Reuse its record shapes, not its calibration.
- *Then consult again.* Once the bank has data, a second Oracle consult framed
  around the family of records is worth sending (guide §6).

## Next: test before building

In this order. Each has a pass criterion; a fail is a result to report, not a reason to push on.

**0. Cheap and independent (any time; each changes `J` only at round-off or root tolerance).**
- *One rate evaluation per entry, and none at a zero-size knot.* That saves 3.8–7.5% of member evaluations.
  - Appending the new member's rates to the carried last stage is exact. The fields are continuous across a creation, because the closing member already sits at `b = t` with the same density.
  - Check that `J` and the sweep are unchanged.
- *Warm-starting the inner problem* (phylloptim's collar solve).
  - Measure instructions per solve on the 5-year callgrind cut (`perf-rhs-profile.md`), and the change in `J` (it should be at the root tolerance).
  - plant compiles phylloptim through its installed headers: build in a private R library, never the site one, while other builds run.

**1. The overshoot mechanism (claim 1's cause).** As proposed: replay `u429`, flag stages with `u_1 > θ_s`, `u < θ_res` or `ψ` at a bound, re-evaluate the members at the projected state, and weight the differences by the adjoint. Predicted to account for most of T5's `4e-4`.
- *Checked, and it matters.* `psi_from_soil_moist` (`tf24_environment.h:683`) already floors the chain at `θ_res` and caps `ψ`, and `K` is clamped already. So projection changes only the stages with `u_1 > θ_s` (935 at tol 1e-3).
- *The stronger form* replaces each stage's chain state with an accurate chain trajectory at the stage's time. The chain is cheap: integrate it finely with `a` held.
- *Adjoint weights* need `λ` at every accepted step. Extend `perf-adjoint-hook.patch` from introductions to every step (~300 MB at `u429`).
- *A cheaper discriminator.* Cap the explicit step at `c·β/|λ_chain|`, from the closed-form diagonal (T3). If T5's spread and T6's placement shift collapse, the mechanism holds, and the cap's cost is measured.

**2. Exact masses (claim 2)**, on uniform 215 and 429, nothing else changed. Build it on a plant branch off `6613dd24`:
- the two accumulators as ODE states beside `E`;
- panel moments read at the creations;
- hat weights in `Species::field_splits`, in `consumption_rate`, and in `J` (`net_reproduction_ratio`);
- members seeded at unit density;
- the closing member's share taken from the partial panel's moments.

*Checked, and it matters.* `E` enters `J` once today, through the new member's initial cumulative loss `m_j(b_j) = −log E` (`Node::seat_at_birth`; `survival_individual()` weights the output). It enters the fields once, through `n_j = βE`. With `J`'s weights carrying `∫πβE`, seed `m_j` at 0 or subtract its initial value in the survival factor. `E` must enter each exactly once.

*Pass:*
- S3's split inverts;
- uniform 215 lands within ~1e-3;
- removing the 64 in-band members moves `J` by ≪ 7e-2;
- 429 and 857 extrapolate at a clean order.

**3. The pinned ARK at θ0, over tol 1e-2 … 1e-4.** This is the big build: a new stepper in odelia, with implicit stages recorded as implicit-function rows and its adjoint, selectable from the SCM.

*Pass:* `J` monotone in tol with a spread ≪ 1e-4; T6's crossing counts down to the floor and the class switches; zero throws.

*Unsettled in the answer:*
- *Evaluating the pool's implicit part.* The pool's `c` and `d` come from the member evaluation, which runs once per stage, while an ARK evaluates its implicit part at the stage's own value. Either lag `c` and `d` within the stage — a W-type, linearly implicit variant whose order must be checked by a convergence study — or restructure.
- *Positivity.* The explicit sums inside ESDIRK stages can still drive the pool negative, so count throws.
- *odelia builds.* Changes to odelia need a private library install.

**4. The graded ~140-member schedule on the pinned ARK**, across `perf-across-theta.md`'s 11 points.

*Pass:* `|e|/J ≤ 1e-3`, secant-gradient error ≤ 0.1%, along-step consistency ≤ 1%.

If 1 and 2 pass, the question left is how much of the residual is the model's own kinks.

## For the user, not the session

- **The window.** The answer says `τ_g` was only a numerical necessity of point-sampled weights. With exact masses the instantaneous gate could converge in the schedule, but the accumulator's own time quadrature would then have to resolve 0.06δ ramps. Keep the window until tests 2 and 3 are in; then it is a modelling call.
- **Smoothing the switches** (`C¹`), if the kink floor stays above ~1e-2.
- **The domain leaked.** The answer names "rain-resumption dates" and "seedling survival": the Oracle inferred the domain from the structure alone, although the statement passes the scan.

## Code state

- **`plant-dev` records `plant` at `6613dd24`**, the head of `establishment-window`, stacked on `offspring-adjoint`: issues aornugent/plant#91 and #92, no PRs. The main `plant/` tree is detached there, with `plant-adj`'s `-O2` build copied in.
- **Full serial sweep:** 536 tests, 2 failures, both in `test-mutant.R` and identical on the base.
- **`perf-adjoint-hook.patch`** (207 lines, against `6613dd24`) reads the adjoint at every creation and is bit-identical on the default path. Apply it to a fresh branch; it is the starting point for test 1's per-step `λ`.
- **Scratchpad** (survives restarts; background jobs do not): `plant-adj`, `tg/plant-base` (`bb1d8a8a`), `perf/adjoint/plant` (the hook build), each agent's scripts in `perf/<name>/`, and the lean schedules in `perf/schedules/`.

## Established — do not re-derive

The consult holds the numbers. The ones the tests lean on:
- `J∞ = 12.5734`; the fixed-grid `dJ/dθ_1 = −172.52 ± 0.03`.
- `u429`: 11 239 accepted steps, 14 280 attempts (1891 rejected for accuracy, 1150 thrown), 1.934e7 member evaluations.
- T5: `J` spreads 4e-4 over tol. S1: the placement floor is 6e-5 sd.
- A member evaluation is 112 k instructions; the inner problem is 85% of it.
- The sweep of `J` costs 2.5–2.7 forward runs.

Harness: `tg/tg2_common.R`'s `run_J()`, and the controller agent's bit-identical step replay, `perf/controller/ctl_rk.R`.

## Build gotchas that cost time

- `make` → `compile_dll` loses the jobserver and builds `-j1`. Use `env MAKEFLAGS=-j3 Rscript -e 'pkgbuild::compile_dll(compile_attributes = FALSE, debug = FALSE)'`. A header change is ~15 minutes.
- `compile_dll` exits 0 having compiled nothing when the `.so` is newer than every source; use `force = TRUE`. plant compiles against phylloptim's and odelia's **installed** headers.
- A new TF24 parameter needs its `PLANT_TF24_AD_PARAMETER` entry, its `RcppR6_classes.yml` entries and `RcppR6::RcppR6()`.
- `pkill -f` on a pattern in your own command line kills your shell. A background wait must key on a sentinel line its script prints: R writes `1e-04` as `0.0001`.
- Several agents on four cores hit the account's usage limit. `SendMessage` to an agent's id resumes it from its transcript.
