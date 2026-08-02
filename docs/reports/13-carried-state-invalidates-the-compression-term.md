# Carried physiological state invalidates the compression term in cohort density transport

### Diagnosis and correction in the `plant` size-structured solver

A non-structural carbohydrate store was added to `plant`'s TF24 strategy so that growth and mortality
respond to buffered carbon rather than to instantaneous production. Growth then depends on a state
other than size. This report shows that the solver's transport term for cohort density is invalid
under that condition, identifies the mechanism, measures the consequence, and presents a correction
that changes no biological equation.

All results are measured on `plant` `develop` at commit `141dc8df`: single species, TF24 with
`lma = 0.1978791`, default `Environment` and `Control`, `max_patch_lifetime = 105.32`, 141 cohort
introductions, five soil layers, `refine_schedule = FALSE`, compiled `-O2 -DNDEBUG`. Comparison runs
use FF16 at `lma = 0.0825` and K93 at `b_0 = 0.059`. Scripts and outputs are in
[`probes/`](../../probes); the implementation is `plant` branch
`claude/nsc-density-measurements-efiolz`.

---

## 1. Significance

Four statements, each supported by a measurement reported below.

**A published model change rests on an affected number.** The storage pull request reports that
single-species reproduction "drops ~9× (227 → 25)" and bumps `TF24_Strategy::scientific_version` to
3. The post-storage figure is computed with the invalid transport term. In the single-species
configuration measured here, correcting that term changes lifetime offspring production from 42.14
to 395.44 at the production cohort schedule and from 59.06 to 400.92 at four times that resolution —
a factor of 6.8 to 9.4, with only the corrected value converged. No run was made at the pull
request's configuration, so the size of the effect there is not known; what is established is that
the quantity it reports is sensitive to a term that is being computed incorrectly (§14).

**The failure condition is general, not particular.** It requires only that the growth rate read a
state other than size, and that the compression term be estimated by perturbing a single individual.
No unusual parameter values are involved. Any structured-population solver that carries a density in
size and estimates its compression by perturbing a single individual will compute the wrong quantity
as soon as a state other than size enters the growth rate (§4, §5, §6).

**The error does not show up in anything a mature stand feeds back to demography.** After patch age
25 the uncorrected and corrected solvers agree on leaf area to a mean ratio of 1.005 and on canopy
height to 0.8%. Their stem densities do not agree — the ratio ranges from 0.37 to 1.96 — because
stem density counts suppressed recruits, which is where the error persists and which contribute
almost nothing to either integral the model forms. The discrepancy remains in the size distribution
for the whole run; it stops reaching demography after about patch age 5 (§10).

**The correction is verifiable and changes no biology.** With the correction disabled the solver is
bit-identical to the original. On the two strategies whose growth is a function of size, the two
coordinate systems converge to each other under refinement at approximately second order. On TF24
they do not: the gap falls by factors of 1.3 and then 1.1 and remains near 5.8. Decoupling the store
from growth within TF24, changing nothing else, removes 92% of that gap and leaves a residual that
does refine away (§12, §12.1).

## 2. The premise, and what ended it

`plant` has been a size-structured model in a strict sense: an individual's rates were determined by
its height and its environment. Two individuals of the same height, in the same patch, at the same
time, were interchangeable.

That premise does not appear in any equation. It appears in the representation. When individuals of
a given size are interchangeable, a count of individuals per unit height is a complete description
of the population, and the model can carry that as its state.

A storage pool ends the premise. Two saplings of the same height, one with reserves and one
depleted, have different growth and mortality rates. An individual now carries part of its own
history, and a distribution over height alone no longer determines the population's future.

## 3. What the solver represents

The solver introduces **cohorts** at scheduled times. Individuals within a cohort share a birth
state and thereafter share an environment, so they remain identical to each other. A cohort is a
point moving through individual-state space, carrying a number of individuals.

No process moves an individual between cohorts. Individuals enter a cohort at birth and leave it
only by dying. Writing `ν(a,t)` for the number of individuals per unit birth date `a`,

```
dν/dt = -mortality × ν            along a cohort
```

and that is the complete population balance. It has no other term.

`plant` does not store `ν`. It stores `log_density`, a density per metre of height. Converting a
count into a density in height requires the local width, in height, of the cohort distribution.

## 4. What the transport term is required to be

Let individual state be `x`, evolving as `dx/dt = v(x, E(t))`, with height `h = x₁` and growth rate
`g = v₁`. Because birth state and environment are shared, `x(t; a)` is a well-defined map from birth
date to current state, and the living population is supported on the one-dimensional curve it
traces.

Define the Jacobian of the map from birth date to height,

```
J(t; a) = ∂h(t; a) / ∂a
```

The density in height is the push-forward of `ν` under that map: `n = ν / J`. Differentiating `J`
along a cohort and exchanging the order of differentiation,

```
dJ/dt      = ∂/∂a [ g(x(t;a), E(t)) ]  =  Σ_k (∂g/∂x_k)(∂x_k/∂a)

d(log J)/dt = [ Σ_k (∂g/∂x_k)(∂x_k/∂a) ] / (∂h/∂a)
            = dg/dh   evaluated along the cohort curve
```

so

```
d(log n)/dt = -mortality - dg/dh |along the cohort curve
```

**The transport term is the total derivative of the growth rate with respect to height, taken along
the cohort curve.** If `g` depends only on height and the environment, that total derivative equals
the partial derivative `∂g/∂h`, and the distinction does not arise. If `g` reads any other state,
the two differ by `Σ_{k≠1} (∂g/∂x_k)(dx_k/dh)`, where each `dx_k/dh` is taken along the curve.

### 4.1 The Jacobian cancels in every quantity the model forms

`log_density` enters the computation in exactly two places in `develop`: the trapezium that builds
the light profile (`node.h:235`, summed in `species.h`), and the stand's draw on each soil layer
(`node.h:98`). It is read elsewhere only by a finiteness guard and by R-facing accessors, neither of
which feeds a rate. Both computational uses are integrals of the size distribution against a
per-individual quantity `e`. Since `n dh = ν da`,

```
∫ n(h) e(h) dh  =  ∫ ν(a) e(a) da
```

exactly. The Jacobian enters `n` and cancels against the measure. The density in height carries no
information the birth-date density does not, and neither integral requires `J` to be known.

The two *discretisations* are not identical — a trapezium in height and a trapezium in birth date
are different quadratures of the same integral — and §12 measures that difference and shows it
converging away.

The consequence for interpretation is specific. Computing `J` is not where a modelling decision is
made: given the growth rates, the transport term is determined. An error in it changes the answer,
but a different choice of it is not an available ecological hypothesis.

## 5. What the solver computes instead

`Node::growth_rate_gradient` copies the individual, changes its height by `node_gradient_eps = 1e-6`
in a one-sided backward difference, re-runs the complete rate calculation — for TF24 including the
leaf hydraulic optimisation — and differences the growth rates. Every state other than height is
held at its current value.

In FF16 and K93 the height growth rate is a function of height and the environment only. FF16
carries heartwood as a state, but `FF16_Strategy::net_mass_production_dt` takes only the
environment, height and leaf area, and leaf area is itself a function of height, so heartwood does
not feed back into growth. For both strategies the total and partial derivatives coincide exactly,
and the finite difference converges to the required quantity as the step size falls.

## 6. The mechanism: the perturbation direction

The expected explanation for TF24 is that neighbouring cohorts can now differ physiologically, so a
single individual cannot represent the pair. That explanation is not what produces the error.

Measured over the 405 interior cohort pairs at patch ages 1.5 to 3, the interval in which the
uncorrected and corrected solvers diverge:

| quantity | value |
|---|---|
| gap between neighbouring cohorts | median 2.44 mm |
| growth rate, upper cohort | median 2.398 m yr⁻¹ |
| growth rate, lower cohort | median 2.398 m yr⁻¹ |
| ratio of the two | median 0.9999 |
| reserve fraction | median 0.457 |
| difference in reserve fraction between neighbours | median 1.1 × 10⁻⁵; 75th percentile 2.0 × 10⁻⁴; maximum 2.0 × 10⁻² |

Neighbouring cohorts in this interval are near-identical. Against a reserve fraction of 0.457, the
largest difference anywhere in the interval is 0.020, or 4.3% in relative terms; three quarters of
pairs differ by less than 0.044% in relative terms. Physiological divergence between neighbours is
not present here.

At the same 405 pairs, the single-individual perturbation has median **−0.2312** and the
neighbour-difference estimate of the total derivative has median **+0.0674**: opposite signs, with
the perturbation 3.4 times larger in magnitude. One pair, at patch age 2.25: heights 4.929 m and
4.926 m, both growing at 2.398 m yr⁻¹, both at reserve fraction 0.453; the perturbation returns
−0.2288, the neighbour difference +0.0365.

The cause is the direction in which the perturbation moves.

TF24 gates growth on the reserve **fraction** `r = S/S_max`, where capacity
`S_max = a_st1 · mass_sapwood` increases with sapwood mass and therefore with height. The
perturbation increases height while holding the absolute pool `S` constant, which reduces `r`
although no carbon has moved. Along an actual trajectory the pool grows with capacity: the measured
reserve-fraction difference between adjacent cohorts, which are the same cohort a short interval
apart, has median 1.1 × 10⁻⁵ while their heights differ by 2.44 mm.

The perturbation therefore evaluates the growth rate at a combination of height and reserve fraction
that the population does not occupy, and returns the slope in that direction. How much that matters
is set by the gate's width: §6.1 gives the relative sensitivity of growth to the reserve fraction as
`(1 − G)/w`, and with `storage_gate_width = 0.1` and the measured median `r = 0.457`, that is 0.27
per unit `r`. A wider gate would make the same misdirection cost less.

### 6.1 Confirmation

Write `g = C(h) · P₊(h) · G(r)`, with `P₊` the smooth positive part of net production and `G` the
logistic gate. Then

```
∂g/∂S = g (1 − G) / (w · S_max),        w = storage_gate_width = 0.1
```

and along a cohort's own path `dS/dh = f/g` with `f = dS/dt`, so the omitted term is

```
(∂g/∂S)(dS/dh) = (1 − G) · f / (w · S_max)
```

The growth rate cancels. Across the whole run this closed form tracks the measured disagreement with
a Spearman rank correlation of 0.933; in cohorts with growth below `10⁻⁸` m yr⁻¹ it predicts exactly
zero and the measured value is `1.1 × 10⁻¹¹`.

The direct test is stronger than the algebra. Add a third estimate, `B`, which perturbs height but
rescales the pool so that `r` is held constant — a perturbation along the direction trajectories
actually take. Writing `A` for the single-individual perturbation and `C` for the neighbour
difference, over 37 patch states and 3 459 interior pairs:

| patch age | `A` (pool held constant) | `B` (fraction held constant) | `C` (neighbour difference) |
|---|---|---|---|
| 0.5 – 1 | +0.198 | +0.7928 | +0.7877 |
| 1 – 2 | −0.221 | +0.2405 | +0.2390 |
| 2 – 3 | −0.209 | +0.0656 | +0.0634 |

`B` matches `C` to within 1–3%. Summed over all pairs, `Σ|A − C| = 623.7`, `Σ|A − B| = 541`,
`Σ|B − C| = 121`; the perturbation-direction term accounts for 86.7% of the total.

`B` is a diagnostic, not a proposal. It agrees with `C` because the reserve fraction happens to be
close to stationary along trajectories at these parameters. That is a property of this
parameterisation, not a structural guarantee, and it was measured here rather than assumed.

## 7. The error is not a resolution error

Before concluding that the quantity is wrong, its resolution must be excluded. The single-individual
perturbation was evaluated on one patch state at age 2 across five decades of step size. At that
patch age neighbouring cohorts are near-identical (§6), so the neighbour difference `C` is a sound
estimate of the total derivative there.

| step size | perturbation | change from the `1e-6` value | distance from `C` |
|---|---|---|---|
| `1e-3` | −0.269644 | 5.5 × 10⁻³ | 0.3015 |
| `1e-4` | −0.270122 | 5.5 × 10⁻⁴ | 0.3019 |
| `1e-5` | −0.270173 | 5.0 × 10⁻⁵ | 0.3020 |
| `1e-6` | −0.270178 | — | 0.3020 |
| `1e-7` | −0.270179 | 5.0 × 10⁻⁶ | 0.3020 |
| `1e-8` | −0.270178 | 5.2 × 10⁻⁶ | 0.3020 |

The perturbation is converged to five decimal places across the range. Its distance from the total
derivative is 0.302, which is 55 times its own variation across those five decades, and the total
derivative's own median magnitude at that state is 0.0318.

An analytic derivative, or one obtained by automatic differentiation, would return this same value
to machine precision. Improving the derivative's accuracy cannot address the discrepancy.

## 8. Measuring the disagreement without instrumentation

The number of individuals between two neighbouring cohorts can change only by mortality. Because
mortality is an integrated state in `plant`, `log N + mortality` is constant along each cohort, and
`N = density × gap` can be reconstructed from collected output. Differencing over recorded
intervals gives a drift.

That drift is not an independent quantity. With `n` the density, `Δh` the gap, `A` the perturbation
and `C` the neighbour difference,

```
d(log N)/dt = d(log n)/dt + d(log Δh)/dt = (−A − mortality) + C
```

so the drift is the time integral of `C − A` over the interval, plus the ODE integrator's own error.
Collected output therefore already contains the disagreement between the two estimates.

Interior intervals only; the lowest interval is bounded below by the fixed inflow boundary and
genuinely gains individuals, so it is excluded.

| | summed drift | largest single cohort | pairs |
|---|---|---|---|
| TF24 | +245.8 | 158× | 9 555 |
| FF16 | +7.94 | 1.59× | 9 870 |
| K93 | +1.41 | 3.02× | 9 050 |

FF16's and K93's drift is the discretisation error of a correct term, accumulated over 105 years;
the integrator's own contribution is not separately identified here.

Totals cannot distinguish a discretisation error, which refines away, from an absent term, which
does not. Dividing by elapsed time and regressing the log drift rate on the log gap width does:

| | slope on log(gap) | R² |
|---|---|---|
| FF16 | +0.78 | 0.81 |
| K93 | +0.16 (magnitudes 10⁻⁹ to 10⁻³) | 0.01 |
| TF24 | −1.02 | 0.24 |

A quadrature error scales with the gap. FF16's does, and its magnitudes are three orders smaller
than TF24's. TF24's slope is negative: its error is larger where cohorts are closer together, which
a quadrature error is not.

Regressing on the growth rate instead gives slope +0.99 with R² = 0.94. Fitting both together, the
growth-rate coefficient is 1.04 and the gap-width coefficient falls to 0.16 (R² = 0.94). The
apparent gap dependence is a confound: small gaps occur where recruits are growing fastest. TF24's
drift is proportional to the growth rate and close to independent of the discretisation.

## 9. Three alternative explanations, excluded

**Cohorts crossing in height.** A carried state makes it possible in principle for two cohorts to
reach the same height, at which point `J = 0` and a density in height is undefined. This does not
occur here. Across 37 patch states and 3 459 interior pairs there are zero crossings and the minimum
gap is 1.6 × 10⁻⁵ m, with 14.2% of gaps below 10⁻⁴ m. 46% of interior pairs are closing at any
instant; extrapolating each closing pair linearly at frozen rates, the earliest crossing would be
4.05 years away, and none is realised. The height growth rate was non-negative at every one of 6 390
sampled cohort-times across the three strategies, and at a further 3 497 for TF24, with a TF24
minimum of +2.6 × 10⁻¹² m yr⁻¹, so no individual shrinks and none can fall below the inflow
boundary.

**Divergence of the omitted term at a growth stall.** The omitted term is `(∂g/∂S)(f/g)`, which
appears to diverge as `g → 0`. It does not: `∂g/∂S` carries a factor of `g` that cancels the `f/g`
exactly (§6.1). In cohorts with growth below `10⁻⁸` m yr⁻¹ the closed form is exactly zero and the
measured drift rate is `1.1 × 10⁻¹¹`. The disagreement is concentrated in fast-growing cohorts.

**The perturbation-direction term as a defect separate from the omitted term.** `A`, `B` and `C` in
§6.1 are three estimates of one operator, not two errors in sequence. Correcting the perturbation
direction would remove most of the discrepancy at these parameters (86.7%) without removing the
condition that produced it, because `B` is a partial derivative and the transport term is a total
one.

## 10. Magnitude, and the channel it travels through

Recruits are seeded at `a_st3 = 0.8` of capacity and are small, so capacity rises steeply with
height for them. The omitted term is largest among fresh recruits, and its absence inflates their
density.

Density reaches demography only through the two integrals of §4.1. Leaf area above ground level,
uncorrected against corrected:

| patch age | uncorrected | corrected | ratio |
|---|---|---|---|
| 0.75 | 1.66 × 10⁻³ | 1.15 × 10⁻³ | 1.45 |
| 1.5 | 5.04 × 10⁻² | 2.49 × 10⁻² | 2.02 |
| 2.0 | 2.29 × 10⁻¹ | 9.74 × 10⁻² | 2.35 |
| 2.5 | 6.82 × 10⁻¹ | 2.71 × 10⁻¹ | 2.52 |
| 3.0 | 1.360 | 0.586 | 2.32 |
| 5.0 | 1.762 | 1.676 | 1.05 |
| beyond 25 | | | 1.005 (mean) |

The cohorts that form the canopy establish under up to 2.5 times the correct leaf area. Lifetime
offspring production is 42.14 uncorrected against 395.44 corrected at the production schedule.

Beyond patch age 25 the two solvers agree on leaf area to a mean ratio of 1.005 (range 0.977 to
1.038) and on canopy height to a mean ratio of 0.993 (range 0.992 to 0.995).

They do not agree on stem density: the ratio over the same interval has mean 1.35 and ranges from
0.37 to 1.96. Stem density counts every individual, including the suppressed recruits whose density
is misestimated, and those individuals contribute almost nothing to either integral of §4.1. So the
error persists in the size distribution for the whole run and stops propagating to demography once
the canopy closes. That is the reason it has not previously been detected: every quantity a mature
stand feeds back into growth and mortality is insensitive to it.

## 11. The correction

The transport term exists to maintain a density in height. §4.1 shows that neither integral the
model forms requires that density. Carrying the population as a density per unit birth date removes
the term rather than correcting it.

| | density in height | density in birth date |
|---|---|---|
| rate | `−dg/dh − mortality` | `−mortality` |
| at birth | `log(birth_rate · pr_estab / g)` | `log(birth_rate · pr_estab)` |
| light profile | trapezium over heights | trapezium over introduction times |
| soil draw | trapezium over heights | trapezium over introduction times |
| perturbation | one extra full rate evaluation per cohort per Runge-Kutta stage | not called |
| size distribution | an integrated ODE state | computed at report time |

No process moves an individual along the birth-date axis, so the transport term reduces to
mortality, which is already an integrated state. The abscissa of both integrals becomes the
introduction schedule, which is known exactly.

Implemented as `Control$node_density_in_birth_date`, default off, so both can be run from one build.

Three further consequences, each measured.

**The birth condition no longer divides by the growth rate.** `birth_rate · pr_estab / g` grows
without bound as the recruit's growth rate approaches zero, and `develop` assigns zero density,
removing the recruit, when it is non-positive. At these parameters the recruit's growth rate never
reaches zero (minimum 0.0959, median 0.821 m yr⁻¹ over 140 introductions), so this is a latent
rather than an active failure. It still affects conditioning: the recruit's density spans a factor
of 16.8 across the run in height coordinates and 3.03 in birth-date coordinates, the latter being
variation in establishment probability alone.

**The state acquires an upper bound.** In birth-date coordinates `log density` is
`log(birth_rate · pr_estab)` minus an integral of mortality, so it cannot increase. Measured over
all cohorts and all recorded times, the maximum `log_density` is +2.4168 in height coordinates and
−0.0015 in birth-date coordinates, the latter equal to the predicted bound.
`Patch::check_finite_node_densities` aborts a run when `log_density` exceeds 50; that guard cannot
fire in birth-date coordinates.

**The size distribution becomes an output.** `n = ν/J` is evaluated when a run is reported, not
integrated over a cohort's lifetime.

The correction also removes one full rate evaluation per cohort per Runge-Kutta stage, which for
TF24 includes a leaf hydraulic optimisation, and removes a term containing a `10⁻⁶` divisor from the
right-hand side. At 561 introductions the corrected solver takes 6 143 accepted ODE steps against
8 530, a 28% reduction. Wall-clock timings were not taken under controlled conditions and are not
reported.

## 12. Verification where the original solver is correct

The change must be shown to be a change of coordinates rather than a change of model. The test is to
run it on strategies whose growth is a function of size, where the original transport term is
correct and the two coordinate systems must therefore agree in the continuum, differing only by
quadrature.

Refining the introduction schedule by midpoint insertion, so both see byte-identical schedules at
each level:

| model | introductions | density in height | density in birth date | relative gap |
|---|---|---|---|---|
| **K93** | 141 | 0.03054665 | 0.03062749 | 2.65 × 10⁻³ |
| | 281 | 0.03056528 | 0.03058331 | 5.90 × 10⁻⁴ |
| | 561 | 0.03056925 | 0.03057363 | **1.43 × 10⁻⁴** |
| **FF16** | 141 | 19.8244 | 20.03188 | 1.05 × 10⁻² |
| | 281 | 19.94896 | 20.03524 | 4.33 × 10⁻³ |
| | 561 | 20.01218 | 20.03607 | **1.19 × 10⁻³** |
| **TF24** | 141 | 42.14017 | 395.4415 | 8.38 |
| | 281 | 54.79883 | 399.0849 | 6.28 |
| | 561 | 59.05900 | 400.9166 | **5.79** |

Three results.

**The two coordinate systems converge to each other.** On K93 the relative gap falls by factors of
4.5 and 4.1 for successive halvings of the cohort spacing, which is approximately second order and
is what two second-order quadratures of one integral should do. On FF16 it falls by factors of 2.4
and 3.6. This is the expected signature of a pure change of variables, and it is measured rather
than assumed.

**On TF24 the gap does not close.** It falls by factors of 1.3 and 1.1 and remains near 5.8, against
a factor of 20 over the same two refinements on K93. The two coordinate systems are not computing
the same integral there. §12.1 shows this is attributable to the store and not to TF24.

**Only one arm is converged.** The height coordinate moves +30.0% and then +7.8% on TF24 and is
still increasing; the birth-date coordinate moves +0.92% and then +0.46%, each increment
approximately half the last.

### 12.1 A control that changes only the coupling

Comparing TF24 with FF16 and K93 changes the strategy as well as the coupling. A control that
changes only the coupling is available within TF24. Setting the gate threshold `a_st2` to −10 puts
`G` within 10⁻⁴³ of 1 for every reserve fraction, so the pool is still charged, drained and
integrated but no longer enters the growth rate. Setting `a_dG1` to 0 removes the storage-dependent
mortality term, leaving mortality constant. Crossing the two gives four configurations, at the
production schedule of 141 introductions:

| growth reads reserves | mortality reads reserves | density in height | density in birth date | ratio |
|---|---|---|---|---|
| yes | yes (as shipped) | 42.1402 | 395.441 | 9.4 |
| yes | no | 0.04551 | 29.2839 | 643 |
| no | yes | 2.096 × 10⁻¹⁵ | 2.096 × 10⁻¹⁵ | 1.0003 |
| no | no | 19.8012 | 32.5773 | 1.65 |

The two coordinate systems disagree by a factor of 9 to 640 in both configurations where growth
reads the reserve fraction, and by 1.65 or less in both where it does not. Removing the store's
effect on mortality alone does not reduce the disagreement; removing its effect on growth does.

Two cells need qualification. In the third row the stand is effectively dead — with the gate
permanently open the pool never charges, reserves drain, and storage mortality saturates — so the
agreement there is measured on an almost empty patch and is weak evidence on its own. In the second
row the height coordinate has collapsed to 0.046, so the ratio is inflated by a near-zero
denominator; the absolute values are the informative part.

The fourth row is the control that matters: a live stand, the pool integrated, nothing reading it.
Its residual disagreement refines away, where the shipped configuration's does not:

| relative gap between coordinate systems | 141 introductions | 281 | 561 |
|---|---|---|---|
| as shipped | 8.38 | 6.28 | 5.79 |
| growth reads reserves, mortality does not | 642 | 509 | not run |
| store reads nothing | 0.645 | 0.357 | not run |

Both configurations in which growth reads the reserve fraction hold their disagreement under
refinement; the one in which it does not halves it.

This qualifies two statements above. TF24's height-coordinate arm converges slowly whether or not
the store is coupled — it moves +21.6% between the first two levels with the store decoupled against
+30.0% with it coupled — so slow convergence of that arm is a property of TF24's stand and not of
the store. And the two quadratures differ by 0.645 at production resolution for TF24 with the store
decoupled, against 1.05 × 10⁻² for FF16 on the same schedule, so TF24's size distribution is harder
for both coordinate systems. What the store adds is a component that does not refine away: it
accounts for 92% of the relative gap at 141 introductions and 94% at 281.

With the correction disabled, all three strategies reproduce the pre-change build bit-identically:
`identical()` returns `TRUE` on the offspring scalar, zero units in the last place. The test suite
passes: 2 363 assertions across 48 files, no failures, including the FF16 bit-identity reference
comparison and the per-model default-parameter drift guard.

## 13. Comparison with the individual-based solver

§7, §8 and §12 are arguments about the deterministic solver made using the deterministic solver.
`plant` also carries a stochastic, finite-population solver in which individuals arrive and die as
discrete events. It tracks individuals, not a density, and has no transport term of any kind, so it
cannot favour either coordinate system.

Both solvers divide leaf area by patch area in `Patch::compute_competition`, so the quantities are
directly comparable. Protocol: Poisson arrivals at the same birth rate, establishment as a Bernoulli
draw on the same probability, three patch areas (4 m², 8 replicates; 16 m², 6; 64 m², 2), run to the
same patch lifetime. The stochastic solver's own schedule builder was not used, because it passes
patch area into the arrival function's `delta_t` argument; the probes construct the schedule
directly (§15).

Leaf area above ground level, in the interval where the two coordinate systems differ, pooled over
all 16 stochastic runs:

| patch age | stochastic mean | s.d. | uncorrected | ratio | z | corrected | ratio | z |
|---|---|---|---|---|---|---|---|---|
| 1.0 | 0.00361 | 0.00225 | 0.00628 | 1.74 | 1.2 | 0.00383 | 1.06 | 0.1 |
| 1.5 | 0.02286 | 0.01204 | 0.05035 | 2.20 | 2.3 | 0.02488 | 1.09 | 0.2 |
| 2.0 | 0.08532 | 0.03773 | 0.22926 | 2.69 | 3.8 | 0.09738 | 1.14 | 0.3 |
| 2.5 | 0.23143 | 0.08486 | 0.68229 | 2.95 | 5.3 | 0.27117 | 1.17 | 0.5 |
| 3.0 | 0.48279 | 0.15192 | 1.35999 | 2.82 | 5.8 | 0.58568 | 1.21 | 0.7 |

At patch ages 2 to 3 the uncorrected solver lies 3.8 to 5.8 standard deviations above the stochastic
ensemble mean; the corrected solver lies within 0.7. The stochastic mean varies by 12.8% at age 2
across a sixteenfold range of patch area, far less than the 2.7-fold discrepancy, so patch size is
not the limiting factor; the largest patch carries 58, 112 and 177 individuals at ages 1, 2 and 3.

Two limits on what this establishes. Only two replicates were run at the largest patch area, so
per-area standard deviations at 64 m² are not usable and the pooled ensemble is quoted instead.
And the comparison is not exact: the two solvers differ in more than the transport term — finite
population, discrete deaths, and nonlinear averaging over replicates — so it distinguishes a
2.7-fold discrepancy from a 1.2-fold one but cannot resolve the corrected solver's residual 6% to
21% excess, which remains unexplained.

The stochastic solver cannot discriminate on the mature stand. After canopy closure its leaf area
agrees with both coordinate systems within its replicate spread, and its living stem density is too
variable to separate them: its own largest-patch value moves 7.2, 5.1, 5.0, 6.3 and 2.0 individuals
per m² across patch ages 20 to 100. This is §10's result seen independently.

## 14. Consequences for the storage model

**The correction changes no biological equation.** Storage dynamics, the reserve gate,
reserve-dependent mortality and the birth reserve fill are untouched. What changes is the coordinate
in which the population is counted.

That distinguishes it from the other available correction. Making the store an explicit function of
size and environment would restore the size-structured premise by construction, make the original
transport term correct, and remove the problem. It would also remove the modelled process: a store
whose contents are determined by current size cannot record a past drought. Stefaniak et al. (2026),
named in the storage pull request as the agreed calibration target, report that the variance of
stress duration shifts community composition more strongly than its mean — an effect size of
ω² = 0.25, classified "large", on the Slow-Risky strategy's basal area against "very small" for the
mean at almost every level of stochasticity — and define their four strategies by a utilisation rate
and a switch time, both properties of the pool's dynamics.

**The affected interval coincides with the process the store was added for.** Stefaniak et al.
attribute the Slow strategies' success to a "high carbon storage minimum, which facilitated the
survival of small saplings in the shade". Suppressed saplings are the tightly-spaced, slow-growing
part of the size distribution, where cohort gaps fall below 10⁻⁴ m and a density in height is worst
conditioned, and §10 locates the error among recruits.

Their own model did not encounter this: they ran an individual-based solver, at 100-year runs on
100 m² patches with individual trees and roughly three days per simulation. An individual-based
model has no transport term. The difficulty is specific to the deterministic solver's density
variable.

**The condition is not specific to storage.** Any state the growth rate reads produces it. TF24
reads a carbon pool. The allometric calibration factor Stefaniak et al. require, because gating
growth breaks the pipe-model balance and each component mass becomes independent, would add four
more. A correction that adds `(∂g/∂x_k)(dx_k/dh)` explicitly must be extended once per carried state
and re-derived whenever the physiology changes. Removing the change of variables does not.

**A reported result should be re-measured.** The storage pull request reports single-species
reproduction dropping "~9× (227 → 25)" and raised `TF24_Strategy::scientific_version` to 3 on that
basis. The post-storage figure is computed with the invalid term: on TF24 the two coordinate systems
differ by a factor of 6.8 at the finest resolution tested, and only one of them is converged. The
pre-storage figure should be insensitive to the coordinate system, since without the store nothing
but height enters the growth rate, as on FF16 and K93 where the two coordinates agree to 1.2 × 10⁻³
and 1.4 × 10⁻⁴; that has not been run directly, and §12.1 tests the equivalent by removing the
store's effect on growth rather than the store itself. The magnitude of the reported drop is
therefore not established. Its sign is not addressed here: the pre- and post-storage runs use
different parameter sets, and no run was made at the pull request's configuration.

## 15. Limitations and defects found alongside

**Baselines move.** Every TF24 baseline changes. FF16 and K93 change by 1.2 × 10⁻³ and 1.4 × 10⁻⁴,
small but above a bit-identity tripwire, so the FF16 reference comparison would need regenerating if
the coordinate became the default rather than an option.

**A height-ordering dependence remains in the competition loop.** The density state no longer
requires cohorts to stay ordered by height, but `Species::compute_competition` retains a
height-ordered early exit (`if (h0 < height) break;`) and an early return on `height_max()`. No
crossings occur in the runs measured (§9), so this is not currently active, but the claim that the
correction removes the ordering requirement holds for the state and not for that loop.

**Adaptive schedule refinement has not been re-derived.** `SCM::refine_schedule`'s error metric is
written against the height grid. The structure carries over to a birth-date abscissa; the work has
not been done, and all runs here use `refine_schedule = FALSE`.

**The §12.1 control was not taken to a third refinement level.** Both configurations were run at 141
and 281 introductions but not at 561, so the claim that the decoupled residual refines away rests on
one halving rather than two.

**Crossings were censused at one parameter set.** §9 covers a single trait value and a single
environment. The drought sweep that motivated the storage pool has not been instrumented, and no run
has been made against a seasonal stress regime of the kind Stefaniak et al. simulate.

**The corrected solver's 6% to 21% excess over the stochastic ensemble is unexplained** (§13). It has
not been attributed to a cause.

**The stochastic schedule builder ignores patch area.** `stochastic_schedule()` passes `patch_area`
into `stochastic_arrival_times()`'s third positional argument, which is `delta_t`, so arrival rates
never scale with area and the binning interval is set to the area. Passing it by name is the fix,
but `test-stochastic-patch-runner.R` runs at `patch_area = 50` with seed-dependent expectations, so
correcting it makes that file roughly fifty times heavier and requires its parameters and baselines
to be revisited. It is recorded and left unfixed; §13's probes build their own schedule.

**TF24's storage state leaves its intended range.** The minimum recorded value is −2.249 × 10⁻³, in
14.0% of recorded cohort-times, affecting 65 of 142 cohorts, first at patch age 3.5. The rate is
gated by `S/(S + 10⁻³ S_max)` to vanish as the pool empties, but a finite step from a small positive
value with a negative rate carries the state below zero, where the gate pins the rate at zero. The
rate calculation clamps on read, so the individual behaves as though the pool were exactly empty:
gate at its floor of 0.269, storage mortality at its bounded maximum. This is independent of
everything above.

**A latent compilation defect, fixed here.** `SpeciesBase::control()` called
`strategy->get_control()`, which no strategy defines. The member had never been instantiated, so the
error had never been compiled.

## 16. Summary

Adding a carbohydrate store made growth depend on a state other than size. The solver's transport
term for cohort density then requires the total derivative of growth with respect to height along a
cohort's trajectory, and the solver computes the partial derivative at fixed carbon instead. The two
differ by an O(1) term that does not vanish under refinement.

The error is not a resolution error: the finite difference is converged to five decimal places
across five decades of step size and still lies 55 times its own variation away from the required
quantity. It arises because the perturbation increases height while holding the carbon pool
constant, which reduces the reserve fraction, while along an actual trajectory the pool grows with
capacity and the fraction is nearly constant. The perturbation evaluates the growth rate at a state
the population does not occupy.

The consequence is up to 2.5 times the correct leaf area during recruitment, and lifetime offspring
production of 42.14 against 395.44, with only the corrected figure converged under refinement. After
canopy closure the two agree on leaf area and canopy height, and still disagree on stem density by
up to a factor of two, because the misestimated recruits contribute almost nothing to the integrals
the model forms.

The transport term exists only to maintain a density in height, and the Jacobian it computes cancels
in both integrals the model forms. Carrying the population as a density per unit birth date removes
the term. On the two strategies whose growth is a function of size, the two coordinate systems
converge to each other at approximately second order under refinement; on TF24 they do not.
Decoupling the store from growth within TF24, changing nothing else, removes 92% of the disagreement
and leaves a residual that refines away. An independent individual-based solver, which has no
transport term, places the corrected result within 0.7 standard deviations of its ensemble mean and
the uncorrected result 3.8 to 5.8 above.

## References

Falster, D. S., FitzJohn, R. G., Brannstrom, A., Dieckmann, U., Westoby, M. (2016). plant: A package
for modelling forest trait ecology and evolution. *Methods in Ecology and Evolution* 7, 136-146.

Stefaniak, E. Z., Tissue, D. T., Falster, D. S., Medlyn, B. E. (2026). Greater variability in
environmental stress favours trees that prioritise storage of carbohydrate reserves over growth: a
modelling analysis. EGUsphere preprint, https://doi.org/10.5194/egusphere-2026-1474. Local copy:
[`docs/reference/stefaniak-et-al-2026-storage-strategies-egusphere-2026-1474.pdf`](../reference/stefaniak-et-al-2026-storage-strategies-egusphere-2026-1474.pdf)
(CC BY 4.0).
