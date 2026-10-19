# PLANT-93: exact establishment counts on the birth-date coordinate

Branch `PLANT-93` on aornugent/plant, one commit on `develop` (bd09645d); the head of aornugent/plant#94.
It re-ports bae2dd9a, which sat ten upstream merges back, onto the census gradient (#648, #657, #658),
the Hermite light field (#649), the retried birth-date stage (#662) and the continuous and long patches (#661, #676).

## PR body (plant's template: why, then what changed; becomes the squash message)

On the birth-date coordinate each cohort's density was seeded at `birth_rate * pr_estab` at its birth
date, and competition, uptake, the census and offspring production were trapezia through those
samples. TF24's establishment probability rises after rain and falls as the soil dries, within days,
while cohorts are weeks to months apart, so offspring production depended on where the introductions
fell as well as on how many there were.

On this coordinate a cohort's ODE state now carries the establishment probability integrated from its
birth date to the next cohort's, and that integral's first moment; only the newest cohort's pair grows.
Its density is the birth rate at its birth date times its survival, no longer a state. Every integral
over birth date weights each cohort by the establishment probability integrated against its hat
function (`Species$establishment_weights`), so only the smooth rest of each integrand is interpolated.
The height coordinate is bit-identical. `Species$log_densities_state` is removed, `make_initial_state()`
takes `birth_dates` on this coordinate, and `refine_schedule()` refuses it.

Closes #93

## First comment (measurements, cost, review notes)

### The problem, in the model's terms
A cohort stands for the seeds arriving in the interval around its birth date. Point sampling took the
establishment fraction of the whole interval from its value at one instant. Under TF24 that fraction
switches between near 0 and near 1 on the time scale of a wet spell, so moving the introductions moved
which spells were sampled, and with them J.

### The mechanism
- Two node states, `interval_establishment` E and `interval_establishment_moment` M: the integral of
  `pr_estab` over the node's interval and its first moment. Only the newest node's pair has a rate:
  the boundary node's `pr_estab`, and that times the time since the newest birth date.
- The interval splits between its two ends as a hat function does: M/width to the upper node, E − M/width
  to the lower. A node's weight is its two shares (`Species::establishment_weights`).
- The density is derived, `b(t_k)·exp(−mortality)`, and the hazard starts at zero. The birth rate is
  read from the strategy at the birth date on every load, so FF16's birth-rate gradient column (#658)
  keeps the density's channel.
- Weighted by these: the field split and its prefix build, competition, uptake, the census and its
  state adjoint, the fitness integral (window: weights over the window's intervals only), the snapshots'
  density, and the top layer's absorbed density and fitness weights. Retirement writes the hazard, since
  the density follows it; a newborn whose hazard rate is infinite is retired at birth, which is exact.

### Measured gain
| quantity | develop | PLANT-93 | source |
|---|---|---|---|
| quarter-spacing shift of 108 uniform introductions, long-drought TF24 stand, `ode_tol` 1e-4: Δln J | 0.1100 (**4.4ε**) | 0.0017 (**0.07ε**) | measured here, `harness/long_drought.R`, both runs stopping at the union of the two grids and the rain's knots |
| ln J at the unshifted grid | 2.5937 | 2.5201 | same runs |
| the same test on the archived stack | 1.45ε | 0.22ε | docs/design-schedule-building.md, "Exact counts stay" |
| 215 cohorts moved half a spacing (old base, 40-year droughts) | J moved 3.6% | four grids agree to 0.08% | bae2dd9a's NEWS entry (aornugent/plant#94) |

ε = 0.025 in ln J (OBJECTIVES; docs/measurements/eps-spread.md). The target is ε/3 for a quarter shift;
point samples miss it by 13×, exact counts meet it with 5× to spare.

### What it costs
- Runtime: steps 12 776 against 12 828 on the shift test (−0.4%). Wall time on the shared machine read
  114–138 s against 106–116 s, which this machine cannot resolve; the extra work is one weight vector
  per reduction, O(nodes).
- State: one more ODE state per node on this coordinate (two added, `log_density` removed).
- Lines: +496/−221 in the headers (node 181, species 395, patch 93, scm 43, individual 5 changed lines),
  +70/−29 in R, tests +1 879/−1 719 of which 2 664 are the recaptured reference.
- Interface (NEWS, breaking): `Species$log_densities_state` and the `log_density_state` row go;
  `Species$establishment_weights` is new; a node's `mortality`, `log_density` and
  `net_reproduction_ratio_by_node` are per seed that establishes on this coordinate;
  `make_initial_state(birth_dates =)`; `refine_schedule()` refuses this coordinate (its indicators are
  trapezia of node densities); a `fitness_window()` holding one cohort reads NaN here.
- References moved, all on the birth-date coordinate only, and why: the quadrature changed, not the model.
  - FF16 offspring production 17.1720 → 17.1406 (−0.18%; test-strategy-ff16, test-canopy-methods);
    two-species 12.04841/16.59391 → 12.04839/16.59379.
  - K93, which establishes every seed, 0.126524 → 0.126525: the two agree to the ODE tolerance
    (8e-6 at `ode_tol` 1e-4, 3e-8 at 1e-8), because only step selection differs.
  - The whole-run gradient reference (tests/testthat/reference/reference-gradient.tsv) is recaptured with
    `scripts/capture-reference-gradient.R`: drought, seasonal and clamped disagreed with the old one by
    up to 0.53 relative on `theta`; against the new one the worst column reads 1.8e-3 (drought).
  - Scenario gateway baseline re-blessed (opt-in test): S01 +15.9%, S02 +17.9%, S05 +3.5%, S06 +1.3%,
    S08 −3.4%, the rest under 0.08%; no `persists` flag changes. Recorded on Linux x86-64 (the previous
    one was macOS arm64).
  - Not re-blessed: `test_data/default_baseline.rds` is compared on macOS arm64 only, and its two
    birth-date cases (`ff16_birth_date_harvest`, `tf24`) move. A maintainer on that platform reruns
    `scripts/capture-default-baseline.R` from this branch.

### How it is tested
- Full serial sweep on an `-O2` build: see the report (all files, including the three heavy ones).
- New or rewritten checks: the node's state on each coordinate and its interval rates (test-node); the
  patch's state and rates with the interval rate equal to the boundary node's `pr_estab` (test-patch);
  the census against an R re-derivation from the interval states, and its state adjoint against
  Richardson differences on every state family including E and M (test-census G2–G6); the FF16 census
  by establishment weight (test-ff16-stand-gradient); the fitness window against the restricted weights
  (test-fitness-window, test-absorb); density conserved to 1e-13 at absorption (test-absorb); a held
  invader per arriving seed against the same cohort in the stand (test-run-mutant-held); the gradient
  ladder's fixtures and references written from the interval states (helper-gradient-ladder).
- Height coordinate: FF16, K93 and TF24 states and offspring production identical to develop.

### What a reviewer should check
1. `Node::set_ode_state`, `set_birth_state` and `retire` all derive the density through
   `set_birth_date_density`; nothing else on this coordinate reads `pr_estab` at a node.
2. `Species::compute_rates` sets the newest node's interval rate from the boundary node evaluated in the
   full field, after the nodes' own rates zero theirs.
3. The window branch of `Patch::fitness_integral` uses `establishment_weights(first, last)`, so a cohort
   outside the window enters neither the numerator nor the denominator (test "cohorts outside the window
   do not move the ratio" holds to 1e-12).
4. `fixed_point_fitness()` multiplies by the newborn's interval rate, which the held field keeps constant.
5. The review is in docs/prs/PLANT-93-review.md; its one open question is the NaN for a one-cohort window.
