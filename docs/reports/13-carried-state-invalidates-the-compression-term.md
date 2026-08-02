# A carried physiological state invalidates the standard compression term in cohort density transport

### Measured in the `plant` size-structured solver after a carbohydrate store was added to TF24

A solver that carries a population as a density over size must transport that density, and the
transport term needs the rate of change of growth with respect to size. The standard estimate
perturbs one individual's size and re-evaluates its rates. **That estimate stops computing the
required quantity — not approximately, but at all — as soon as growth depends on any state other
than size.**

The consequence here is an order of magnitude. Lifetime offspring production is 42.14 as the solver
computes it and 400.92 in a corrected coordinate, and only the corrected value converges under
schedule refinement. Leaf area during recruitment is up to 2.5 times too high. Decoupling the store
from growth **within TF24**, changing nothing else, removes 98% of the disagreement.

The error is invisible to every diagnostic a mature stand provides: after canopy closure the two
agree on leaf area to a ratio of 1.005 and on canopy height to 0.8%. It is removable without altering
a biological equation, by carrying the population as a density per unit **birth date** rather than per
unit height — a coordinate in which the transport term is mortality alone. Disabled, the solver is
bit-identical to the original.

---

## 1. The result

Four tests, each able to fail independently, none sharing an assumption with another.

| test | uncorrected | corrected |
|---|---|---|
| **Schedule refinement.** Offspring production at 141, 281 and 561 cohort introductions | 42.14, 54.80, 59.06 — moving +30.0% then +7.8% | 395.44, 399.09, 400.92 — moving +0.92% then +0.46% |
| **Step size.** Distance of the estimate from the required quantity, against its own variation across five decades of finite-difference step | 0.302 against 0.0055 — a factor of 55 | not applicable; no derivative is taken |
| **Coupling removed within TF24.** Relative gap between the two coordinates, store integrated but read by nothing, at the same three resolutions | 8.38, 6.28, 5.79 | 0.645, 0.357, 0.0966 |
| **Independent solver.** Leaf area at patch ages 2 to 3 against a 16-run individual-based ensemble that has no transport term | 2.69 to 2.95 times the mean; 3.8 to 5.8 standard deviations above | 1.14 to 1.21 times the mean; within 0.7 standard deviations |

The first says the uncorrected value is not converged and the corrected one is. The second says the
discrepancy is not a resolution error, so an analytic or automatically differentiated derivative
would not remove it. The third attributes the discrepancy to the carried state within a single
strategy. The fourth compares both against a solver that counts individuals and cannot prefer either.

**On the two strategies whose growth is a function of size, the two coordinates converge to each
other**, which is the check that this is a change of coordinate and not a change of model. The
relative gap falls by factors of 4.5 and 4.1 on K93 across successive halvings of the cohort spacing,
and by 2.4 and 3.6 on FF16 — approximately the second order that two second-order quadratures of one
integral should show. On TF24 it falls by 1.3 and then 1.1 and remains near 5.8.

## 2. Why the estimate fails

The expected explanation is that a store lets neighbouring cohorts differ physiologically, so one
individual cannot speak for the pair. That is not what produces the error.

Over the 405 interior cohort pairs at patch ages 1.5 to 3, the interval in which the two coordinates
diverge, neighbours are near-identical: median gap 2.44 mm, both growth rates 2.398 m yr⁻¹ to four
figures, and reserve fractions differing by a median of 1.1 × 10⁻⁵ against a fraction of 0.457 — at
most 4.3% in relative terms anywhere in the interval, and under 0.044% for three quarters of pairs.
At the same 405 pairs the single-individual estimate has median **−0.2312** and the required quantity
median **+0.0674**: opposite in sign, and 3.4 times larger in magnitude.

The cause is the direction in which the perturbation moves. TF24 gates growth on the reserve
**fraction** `r = S/S_max`, and capacity `S_max = a_st1 · mass_sapwood` increases with height. The
perturbation raises height while holding the absolute pool constant, which lowers `r` although no
carbon has moved. Along a trajectory the pool grows with capacity — which is what the measured
constancy of `r` between adjacent cohorts, two millimetres apart in height, states. **The
perturbation evaluates the growth rate at a combination of height and reserve fraction that no
individual in the stand occupies.**

The required quantity is the total derivative of growth with respect to height taken along a cohort's
own trajectory; the perturbation returns the partial derivative at fixed carbon. They differ by
`(∂g/∂S)(dS/dh)`, which for TF24 has the closed form `(1 − G) f / (w · S_max)` with `f = dS/dt`
(Appendix A). Substituting a perturbation that rescales the pool to hold `r` constant — one that moves
along the trajectory's own direction — recovers the required quantity to within 1–3%:

| patch age | pool held constant | fraction held constant | required |
|---|---|---|---|
| 0.5 – 1 | +0.198 | +0.7928 | +0.7877 |
| 1 – 2 | −0.221 | +0.2405 | +0.2390 |
| 2 – 3 | −0.209 | +0.0656 | +0.0634 |

That is a diagnostic, not a proposal: the two agree because `r` happens to be close to stationary
along trajectories at these parameters, which was measured rather than assumed and is not structural.

## 3. The correction

The transport term exists only to maintain a density in height, and the Jacobian it computes cancels
in both quantities the model forms from that density (Appendix A). Carrying the population as a
density per unit birth date removes the term instead of correcting it.

| | density in height | density in birth date |
|---|---|---|
| rate | `−dg/dh − mortality` | `−mortality` |
| at birth | `log(birth_rate · pr_estab / g)` | `log(birth_rate · pr_estab)` |
| light profile | trapezium over heights | trapezium over introduction times |
| soil draw | trapezium over heights | trapezium over introduction times |
| perturbation | one extra full rate evaluation per cohort per Runge-Kutta stage | not called |
| size distribution | an integrated ODE state | computed at report time |

No process moves an individual along the birth-date axis, so the transport term is mortality, which
is already an integrated state. The abscissa of both integrals becomes the introduction schedule,
which is known exactly rather than reconstructed from a derivative.

Implemented as `Control$node_density_in_birth_date`, default off, so both run from one build. With it
off, all three strategies reproduce the pre-change build bit-identically — `identical()` on the
offspring scalar, zero units in the last place — and the test suite passes: 2 363 assertions across
48 files, no failures, including the FF16 bit-identity reference comparison.

Three further consequences, each measured.

**The birth condition no longer divides by the growth rate.** `birth_rate · pr_estab / g` grows
without bound as a recruit's growth rate approaches zero, and the solver assigns zero density,
removing the recruit, when it is non-positive. At these parameters the recruit's growth rate never
reaches zero (minimum 0.0959, median 0.821 m yr⁻¹ over 140 introductions), so this is latent rather
than active. It still affects conditioning: the recruit's density spans a factor of 16.8 across the
run in height coordinates and 3.03 in birth-date coordinates, the latter being variation in
establishment probability alone.

**The state acquires an upper bound.** In birth-date coordinates `log density` is
`log(birth_rate · pr_estab)` minus an integral of mortality, so it cannot increase. Over all cohorts
and recorded times the maximum is +2.4168 in height coordinates and −0.0015 in birth-date
coordinates, the latter equal to the predicted bound. `Patch::check_finite_node_densities` aborts a
run when `log_density` exceeds 50; that guard cannot fire in birth-date coordinates.

**The size distribution becomes an output.** `n = ν/J` is evaluated when a run is reported rather
than integrated over a cohort's lifetime.

## 4. Where the discrepancy is generated

Recruits are seeded at `a_st3 = 0.8` of capacity and are small, so their capacity rises steeply with
height. The omitted term is largest among fresh recruits, and its absence inflates their density.
Density reaches demography only through the two integrals of Appendix A. Leaf area above ground level:

| patch age | uncorrected | corrected | ratio |
|---|---|---|---|
| 0.75 | 1.66 × 10⁻³ | 1.15 × 10⁻³ | 1.45 |
| 1.5 | 5.04 × 10⁻² | 2.49 × 10⁻² | 2.02 |
| 2.0 | 2.29 × 10⁻¹ | 9.74 × 10⁻² | 2.35 |
| 2.5 | 6.82 × 10⁻¹ | 2.71 × 10⁻¹ | 2.52 |
| 3.0 | 1.360 | 0.586 | 2.32 |
| 5.0 | 1.762 | 1.676 | 1.05 |

Beyond patch age 25 the two agree on leaf area to a mean ratio of 1.005 (range 0.977 to 1.038) and on
canopy height to a mean ratio of 0.993 (range 0.992 to 0.995). They do not agree on stem density: the
ratio there has mean 1.35 and ranges from 0.37 to 1.96, because stem density counts the suppressed
recruits whose density is misestimated and those individuals contribute almost nothing to either
integral. The error persists in the size distribution for the whole run and stops reaching demography
once the canopy closes, which is why no downstream diagnostic detected it.

## 5. Consequences

**No biological equation changes.** Storage dynamics, the reserve gate, reserve-dependent mortality
and the birth reserve fill are untouched. What changes is the coordinate the population is counted in.

That distinguishes the correction from the other repair available. Making the store an explicit
function of size and environment would restore the size-structured premise by construction and remove
the problem. It would also remove the modelled process: a store whose contents are determined by
current size cannot record a past drought. Stefaniak et al. (2026), named in the storage pull request
as the agreed calibration target, report that the variance of stress duration shifts community
composition more strongly than its mean — an effect size of ω² = 0.25, classified "large", on the
Slow-Risky strategy's basal area against "very small" for the mean at almost every level of
stochasticity — and define their four strategies by a utilisation rate and a switch time, both
properties of the pool's dynamics.

**The affected interval coincides with the process the store was added for.** Stefaniak et al.
attribute the Slow strategies' success to a "high carbon storage minimum, which facilitated the
survival of small saplings in the shade". Suppressed saplings are the tightly-spaced, slow-growing
part of the size distribution, where cohort gaps fall below 10⁻⁴ m and a density in height is worst
conditioned, and §4 locates the error among recruits. Their own model did not encounter this: they
ran an individual-based solver, which has no transport term.

**The condition is not specific to storage.** Any state the growth rate reads produces it. The
allometric calibration factor Stefaniak et al. require, because gating growth breaks the pipe-model
balance and each component mass becomes independent, would add four more. A repair that adds
`(∂g/∂x_k)(dx_k/dh)` explicitly must be extended once per carried state and re-derived whenever the
physiology changes. Removing the change of variables does not.

**A reported result needs re-measuring.** The storage pull request reports single-species reproduction
dropping "~9× (227 → 25)" and raised `TF24_Strategy::scientific_version` to 3 on that basis. The
post-storage figure is computed with the invalid term: on TF24 the two coordinates differ by a factor
of 6.8 at the finest resolution tested and only one of them is converged. The pre-storage figure
should be insensitive to the coordinate, since without the store nothing but height enters the growth
rate, as on FF16 and K93 where the two agree to 1.2 × 10⁻³ and 1.4 × 10⁻⁴. The magnitude of the
reported drop is therefore not established. Its sign is not addressed here: the pre- and post-storage
runs use different parameter sets, and no run was made at the pull request's configuration.

## 6. Five follow-through measurements

### 6.1 The storage state's excursion below zero is a step overshoot the tolerance cannot remove

TF24's storage state is intended to stay in `[0, S_max]`. It does not: the minimum recorded value is
−2.249 × 10⁻³, in 14.0% of recorded cohort-times, affecting 65 of 142 cohorts, first at patch age
3.5. The outflow is gated by `floor_gate = S/(S + 10⁻³ S_max)` with `S` clamped at zero on read, so
the continuous solution decays exponentially toward zero and never crosses it; any negative value is
a single overshooting step, after which the clamp pins the rate at exactly zero and the state stays
negative until `net_flux = P − growth_flux` turns positive.

Tightening the integrator's absolute tolerance tests that reading:

| `ode_tol_abs` | min `S` | fraction of cohort-times with `S < 0` | min `S/S_max` | offspring | runtime |
|---|---|---|---|---|---|
| 1 × 10⁻⁴ (default) | −2.249 × 10⁻³ | 0.1396 | −0.1014 | 42.1402 | 105 s |
| 1 × 10⁻⁶ | −2.766 × 10⁻⁶ | 0.1324 | −0.01718 | 42.3479 | 423 s |
| 1 × 10⁻⁸ | run aborts: "Cannot achieve the desired accuracy" | | | | |

**The depth confirms the diagnosis and the frequency refutes the remedy.** A hundredfold tighter
tolerance makes the excursion 813 times shallower in absolute terms, which is what a discrete
overshoot does. The fraction of cohort-times spent below zero barely moves, 13.96% to 13.24%,
because that is set by how often the pool is empty, not by the step. No reachable tolerance removes
the excursion: 10⁻⁸ does not converge at all, so 10⁻⁶ is the practical limit here.

The relative worst case improves only 5.9-fold against 813-fold in absolute terms, so the deepest
proportional violations sit where `S_max` is smallest — the recruits. And offspring production moves
42.1402 to 42.3479, so the uncorrected baseline is itself sensitive to the integrator tolerance at
the 0.5% level. This defect is independent of everything else in this report; the fix is to make the
rate restoring below zero rather than pinned, which requires reading the unclamped state.

### 6.2 The corrected solver's excess over the individual-based ensemble is not schedule resolution

Appendix E records that the corrected solver's leaf area sits 6% to 21% above the individual-based
ensemble mean at patch ages 1 to 3. The obvious candidate is that its birth-date quadrature is
under-resolved at the production schedule of 141 introductions. It is not.

Excess over the pooled 16-run ensemble mean, at three schedule resolutions:

| introductions | age 1 | 1.5 | 2 | 2.5 | 3 |
|---|---|---|---|---|---|
| 141 | +5.94% | +8.80% | +14.13% | +17.17% | +21.31% |
| 281 | +5.67% | +8.52% | +13.83% | +16.87% | +21.03% |
| 561 | +5.60% | +8.45% | +13.75% | +16.80% | +20.96% |
| Richardson limit | +5.58% | +8.42% | +13.73% | +16.77% | +20.94% |

Quartering the cohort spacing lowers leaf area by 0.29% to 0.33% and reduces the excess by about
0.35 percentage points. Schedule resolution accounts for 6.0%, 4.3%, 2.9%, 2.3% and 1.7% of the
excess at the five ages; **at least 94% of it survives complete refinement.**

The convergence is clean and bounds what is left: successive-difference ratios are 3.98 to 3.99 at
all five ages, an observed order of 1.99 to 2.00, so the birth-date trapezium on leaf area is second
order and already converged to within about 0.3% at 141 introductions. (Offspring production
converges first order in the same coordinate — §1's +0.92% then +0.46% — because it is a further
integral over patch age; the two quantities need not share an order.)

So the excess is real and is not a quadrature artefact. The remaining named candidate is that the
mean over stochastic replicates of a nonlinear functional is not the deterministic value, which
would not require the two to agree. That has not been tested, and the excess is recorded here as
unexplained rather than attributed.

### 6.3 Under a strong seasonal light cycle, cohorts do cross

Every result above is measured in a constant environment, where no cohort crossing occurs
(Appendix D). Twelve further runs add an annual sinusoidal cycle — in rainfall at amplitudes 0, 0.3,
0.7 and 1.0 as a fraction of the mean, and in incident light at 0.7 and 1.0, trough clamped at zero
— in both coordinate systems. All twelve completed; none failed.

**One cell of the twelve produces interior crossings.** Under a full-amplitude light cycle, the
height coordinate records 66 crossings among 10 011 interior pairs, with a minimum gap of
−0.00398 m. The other eleven cells record none. No cell produces a crossing at the inflow boundary.

The approach is visible in the gaps. In a constant environment the smallest interior gap is
8.21 × 10⁻⁶ m in height coordinates and 1.22 × 10⁻⁶ m in birth-date coordinates; under stress the
smallest positive gaps fall to 4.43 × 10⁻⁸, 4.84 × 10⁻⁸ and 5.55 × 10⁻⁸ m — two orders of magnitude
tighter — before the one cell that crosses.

**This is the condition for a density in height failing, observed.** It is also observed in a stand
that has almost ceased to exist: at full light amplitude offspring production is 1.04 × 10⁻⁴ in
height coordinates against 1.37 × 10⁻⁴ in birth-date coordinates, four orders below the
constant-environment values. The crossing is a demonstration that the requirement can fail in the
intended parameter envelope, not a claim that it governs any stand of interest here.

**The coordinate disagreement shrinks with stress, but only as the stand disappears.**

| forcing | height | birth-date | ratio |
|---|---|---|---|
| none | 42.1402 | 395.441 | 9.38 |
| rainfall, amplitude 0.3 | 40.2662 | 374.881 | 9.31 |
| rainfall, 0.7 | 0.166081 | 1.10160 | 6.63 |
| rainfall, 1.0 | 0.0181662 | 0.152653 | 8.40 |
| light, 0.7 | 2.07650 | 14.1408 | 6.81 |
| light, 1.0 | 1.04361 × 10⁻⁴ | 1.37174 × 10⁻⁴ | 1.31 |

The ratio holds near 9.3 through mild seasonality, sits between 6.6 and 8.4 at higher amplitude, and
collapses to 1.31 only where both solvers report near-extinction. Convergence toward agreement at
the last row is not evidence that the coordinates agree; it accompanies a four-order collapse in the
quantity being compared.

**The storage excursion of §6.1 improves under stress rather than worsening.** The most negative
value is in the constant environment (−2.249 × 10⁻³ in height coordinates); it rises to
−8.48 × 10⁻⁴ at rainfall amplitude 0.3 and becomes positive at rainfall 0.7 and 1.0 and at light
0.7. It returns negative only at full light amplitude, at −6.82 × 10⁻⁵, still some thirty times
smaller than the constant-environment baseline.

### 6.4 Adaptive schedule refinement works in the new coordinate; its cost advantage does not

`SCM::refine_schedule` flags cohorts whose integration error exceeds `schedule_eps` and bisects the
interval below them. It combines two error metrics. The reproduction one was already measured over
introduction times. The competition one was measured over the height grid, which is the wrong
abscissa once the competition integral is taken over introduction times, so it was measuring the
error of a quadrature it was not performing. It now uses `Species::quadrature_abscissae()`, whichever
abscissa the integral uses. `local_error_integration` takes absolute differences, so the height
branch's sign convention leaves it bit-identical, verified on FF16 and K93.

With that in place, adaptive refinement terminates normally in both coordinates for all three
strategies:

| arm | adaptive result | own fixed-schedule value at 561 | introductions | ODE steps |
|---|---|---|---|---|
| K93, height | 0.0305966 | 0.03056925 | 181 | 360 |
| K93, birth-date | 0.0306323 | 0.03057363 | 173 | 183 |
| FF16, height | 19.9888 | 20.01218 | 147 | 216 |
| FF16, birth-date | 20.0357 | 20.03607 | 157 | 225 |
| TF24, height | 60.3519 | 59.059 | 204 | 6 233 |
| TF24, birth-date | 401.317 | 400.9166 | 357 | 4 468 |

Three readings, one of them unfavourable.

**It works, including on TF24.** That was the open question, and both arms complete.

**In the corrected coordinate the adaptive result is close to the converged one.** TF24's birth-date
arm reaches 401.317 with 357 introductions against a fixed-schedule limit of 400.9166 — 0.10%. FF16's
reaches 20.0357 against 20.03607, 0.002%. The height arm's TF24 figure cannot be read as an error,
because its own fixed-schedule series is still climbing at 561 introductions; that adaptive placement
reaches 60.35 with 204 nodes where 561 evenly-inserted nodes reach only 59.06 is a point in favour of
adaptive refinement, not a measure of accuracy.

**The corrected coordinate asks for more nodes, not fewer.** On TF24 it refines to 357 introductions
against the height arm's 204 at the same `schedule_eps`, and on FF16 to 157 against 147; only on K93
does it ask for fewer, 173 against 181, and there it lands less accurately (0.19% from its limit
against 0.089%). The error criterion is evaluated over introduction times, and the default schedule
is far more uneven in time than in height, so more intervals are flagged. Any per-run saving from
deleting the perturbation (§6.5) is therefore not guaranteed to survive adaptive refinement. The two
arms were run at equal `schedule_eps` and reached different accuracies, so this is not a cost
comparison at matched accuracy; that experiment was not run.

### 6.5 The speed-up is 1.91x, not the sixfold once claimed

Earlier work in this project claimed that deleting the single-individual perturbation roughly halves
runtime, and elsewhere that it gives a sixfold wall-clock saving. Those timings were taken with other
work on the machine. Measured on an idle machine, three repeats per arm, TF24 at two schedule
resolutions:

| introductions | arm | median | repeats | accepted ODE steps |
|---|---|---|---|---|
| 141 | density in height | 105.0 s | 105.0, 103.8, 105.3 | 5 055 |
| 141 | density in birth date | 55.1 s | 55.0, 56.0, 55.1 | 4 013 |
| 281 | density in height | 259.6 s | 259.0, 262.2, 259.6 | 7 253 |
| 281 | density in birth date | 108.6 s | 108.2, 109.1, 108.6 | 4 646 |

**Speed-up 1.91x at 141 introductions and 2.39x at 281**, with a repeat-to-repeat spread near 1% at
both. The decomposition is the informative part:

| | 141 | 281 |
|---|---|---|
| from taking fewer accepted steps | 1.26x | 1.56x |
| from each step being cheaper | 1.51x | 1.53x |

The per-step factor is stable, as it should be: it is the deleted rate evaluation, one per cohort per
Runge-Kutta stage, which for TF24 includes a leaf hydraulic optimisation. It is 1.5 rather than 2
because the perturbed evaluation is not the whole cost of a step. The step-count factor grows with
resolution, because the term built from a `10⁻⁶` divisor costs the adaptive controller relatively
more as cohorts are packed closer together.

So "roughly halves the runtime" is close to right at the production schedule and conservative at
finer ones; "sixfold" is not supported. One qualification: §6.4 shows adaptive refinement asking for
more introductions in the corrected coordinate, so these are savings at a fixed schedule and not a
guaranteed end-to-end result.

## Appendix A. The transport term derived

Let individual state be `x`, evolving as `dx/dt = v(x, E(t))`, with height `h = x₁` and growth rate
`g = v₁`. Cohorts are introduced at scheduled times; individuals within a cohort share a birth state
and thereafter an environment, so they remain identical to each other, and `x(t; a)` is a well-defined
map from birth date to current state. The living population is supported on the one-dimensional curve
that map traces.

No process moves an individual between cohorts, so writing `ν(a,t)` for the number of individuals per
unit birth date,

```
dν/dt = -mortality × ν          along a cohort
```

is the complete population balance. Define `J(t;a) = ∂h(t;a)/∂a`. The density in height is the
push-forward of `ν`, that is `n = ν/J`, and differentiating `J` along a cohort,

```
dJ/dt       = ∂/∂a [ g(x(t;a), E(t)) ]  =  Σ_k (∂g/∂x_k)(∂x_k/∂a)

d(log J)/dt = [ Σ_k (∂g/∂x_k)(∂x_k/∂a) ] / (∂h/∂a)  =  dg/dh along the cohort curve
```

so `d(log n)/dt = −mortality − dg/dh|curve`. If `g` depends only on height and the environment the
total derivative equals the partial `∂g/∂h` and the distinction does not arise. Otherwise the two
differ by `Σ_{k≠1} (∂g/∂x_k)(dx_k/dh)` with each `dx_k/dh` taken along the curve.

**The Jacobian cancels.** `log_density` enters the computation in exactly two places: the trapezium
that builds the light profile (`node.h:235`, summed in `species.h`) and the stand's draw on each soil
layer (`node.h:98`). It is read elsewhere only by a finiteness guard and by R-facing accessors,
neither of which feeds a rate. Both computational uses are integrals of the size distribution against
a per-individual quantity `e`, and since `n dh = ν da`,

```
∫ n(h) e(h) dh  =  ∫ ν(a) e(a) da
```

exactly. The density in height carries no information the birth-date density does not, and neither
integral requires `J`. The two discretisations are not identical — a trapezium in height and one in
birth date are different quadratures of the same integral — and §1 measures that difference
converging away where the growth rate is a function of size.

Computing `J` is therefore not a place where a modelling decision is made: given the growth rates,
the transport term is determined. An error in it changes the answer, but a different choice of it is
not an available hypothesis.

**For TF24 specifically**, write `g = C(h) · P₊(h) · G(r)` with `P₊` the smooth positive part of net
production and `G` the logistic gate on the reserve fraction. Then `∂g/∂S = g (1 − G)/(w · S_max)`
with `w = storage_gate_width = 0.1`, and since `dS/dh = f/g` along a trajectory, the omitted term is
`(1 − G) f /(w · S_max)`. The growth rate cancels — so it does not diverge where growth stalls, which
is the first thing one expects of it. Across the whole run this closed form tracks the measured
disagreement with a Spearman rank correlation of 0.933; in cohorts growing below 10⁻⁸ m yr⁻¹ it
predicts exactly zero and the measured value is 1.1 × 10⁻¹¹.

## Appendix B. The estimate is resolved; it is the wrong quantity

`Node::growth_rate_gradient` copies the individual, changes its height by `node_gradient_eps = 1e-6`
in a one-sided backward difference, re-runs the complete rate calculation — for TF24 including the
leaf hydraulic optimisation — and differences the growth rates. Evaluated on one patch state at age 2,
where neighbouring cohorts are near-identical (§2) so the neighbour difference `C` is a sound estimate
of the total derivative:

| step size | estimate | change from the `1e-6` value | distance from `C` |
|---|---|---|---|
| `1e-3` | −0.269644 | 5.5 × 10⁻³ | 0.3015 |
| `1e-4` | −0.270122 | 5.5 × 10⁻⁴ | 0.3019 |
| `1e-5` | −0.270173 | 5.0 × 10⁻⁵ | 0.3020 |
| `1e-6` | −0.270178 | — | 0.3020 |
| `1e-7` | −0.270179 | 5.0 × 10⁻⁶ | 0.3020 |
| `1e-8` | −0.270178 | 5.2 × 10⁻⁶ | 0.3020 |

Converged to five decimal places across five decades. The distance from the total derivative is
0.302, which is 55 times its own variation across that range, and the total derivative's median
magnitude at that state is 0.0318. An analytic derivative, or one obtained by automatic
differentiation, would return this same value to machine precision.

In FF16 and K93 the growth rate is a function of height and the environment only. FF16 carries
heartwood as a state, but `FF16_Strategy::net_mass_production_dt` takes only the environment, height
and leaf area, and leaf area is a function of height, so heartwood does not feed back into growth. For
both strategies the partial and total derivatives coincide exactly.

## Appendix C. Measuring the disagreement without instrumentation

The number of individuals between two neighbouring cohorts can change only by mortality, and
mortality is an integrated state, so `log N + mortality` is constant along each cohort and
`N = density × gap` can be reconstructed from collected output. That drift is not independent
information: with `A` the single-individual estimate and `C` the neighbour difference,

```
d(log N)/dt = d(log n)/dt + d(log Δh)/dt = (−A − mortality) + C
```

so the drift over an interval is the time integral of `C − A`, plus the integrator's own error.
Interior intervals only; the lowest is bounded below by the fixed inflow boundary and genuinely gains
individuals.

| | summed drift | largest single cohort | pairs |
|---|---|---|---|
| TF24 | +245.8 | 158× | 9 555 |
| FF16 | +7.94 | 1.59× | 9 870 |
| K93 | +1.41 | 3.02× | 9 050 |

Totals cannot separate a discretisation error, which refines away, from an absent term, which does
not. Dividing by elapsed time and regressing the log drift rate on the log gap width does:

| | slope on log(gap) | R² |
|---|---|---|
| FF16 | +0.78 | 0.81 |
| K93 | +0.16 (magnitudes 10⁻⁹ to 10⁻³) | 0.01 |
| TF24 | −1.02 | 0.24 |

A quadrature error scales with the gap; FF16's does, and its magnitudes are three orders below
TF24's. TF24's slope is negative — its error is larger where cohorts are closer together. Regressing
on the growth rate instead gives slope +0.99 with R² = 0.94; fitting both, the growth-rate coefficient
is 1.04 and the gap-width coefficient falls to 0.16. The apparent gap dependence is a confound, since
small gaps occur where recruits grow fastest.

## Appendix D. Alternative explanations excluded

**Cohorts crossing in height — not the explanation here, though the condition can fail.** A carried
state makes it possible for two cohorts to reach the same height, at which point `J = 0` and a
density in height is undefined. That would invalidate the coordinate outright rather than merely
make its transport term hard to compute, so it has to be excluded before the rest of this report
stands. In the constant environment every result above is measured in, it does not occur: across 37
patch states and 3 459 interior pairs there are zero crossings; the minimum gap is 1.6 × 10⁻⁵ m,
with 14.2% of gaps below 10⁻⁴ m. 46% of interior pairs are closing at any instant; extrapolating
each linearly at frozen rates, the earliest crossing would be 4.05 years away and none is realised.
The height growth rate was non-negative at every one of 6 390 sampled cohort-times across the three
strategies and at a further 3 497 for TF24, with a TF24 minimum of +2.6 × 10⁻¹² m yr⁻¹.

**Under a strong seasonal light cycle it does occur** — 66 crossings among 10 011 interior pairs
(§6.3). So the height coordinate's requirement is not merely tight in the intended envelope, it can
be violated. That does not bear on §1 to §5, which are constant-environment results, and the
observed crossings are in a near-extinct stand; it is recorded because the requirement is one the
birth-date coordinate does not carry at all.

**Divergence of the omitted term at a growth stall.** `(∂g/∂S)(f/g)` appears to diverge as `g → 0`. It
does not: `∂g/∂S` carries a factor of `g` that cancels the `f/g` exactly (Appendix A). Measured, the
closed form is zero at stalls and the drift rate is 1.1 × 10⁻¹¹.

**The perturbation direction as a defect separate from the omitted term.** The three estimates in §2
are estimates of one operator, not two errors in sequence. Correcting the direction removes 86.7% of
the total absolute disagreement (`Σ|A−C| = 623.7`, `Σ|A−B| = 541`, `Σ|B−C| = 121`) without removing the
condition that produced it, because a fixed-fraction perturbation is still a partial derivative.

**Differencing neighbours as the repair.** `(g_upper − g_lower)/Δh` converges to the total derivative
and costs nothing, since both growth rates are already computed. But it converges only where the two
cohorts are close in state, not merely in size. At patch age 24 a cohort at 41.4 cm with an empty
store grows at 0.025 m yr⁻¹ directly above a recruit at 34.4 cm growing at 0.142 m yr⁻¹ — 5.6 times
faster, seven centimetres away. There the neighbour difference gives −1.670 and the single-individual
estimate −0.132, and neither is a derivative of anything. Such pairs are 1.1% of 2 645 interior pairs
at a ratio above two and 0.3% above five, and they are the suppressed sapling bank. Refining the
schedule does not help, because more introduction times do not make a recruit and its shaded
neighbour more alike. The neighbour difference also divides by a gap whose measured minimum is
1.6 × 10⁻⁵ m.

## Appendix E. The individual-based comparison

`plant` carries a stochastic finite-population solver in which individuals arrive and die as discrete
events. It tracks individuals, not a density, and has no transport term, so it cannot favour either
coordinate. Both solvers divide leaf area by patch area in `Patch::compute_competition`, so the
quantities are directly comparable. Protocol: Poisson arrivals at the same birth rate, establishment
as a Bernoulli draw on the same probability, three patch areas (4 m², 8 replicates; 16 m², 6; 64 m²,
2), run to the same patch lifetime. Its own schedule builder was not used, because it passes patch
area into the arrival function's `delta_t` argument; the probes construct the schedule directly
(Appendix F).

Leaf area above ground level, pooled over all 16 runs:

| patch age | mean | s.d. | uncorrected | ratio | z | corrected | ratio | z |
|---|---|---|---|---|---|---|---|---|
| 1.0 | 0.00361 | 0.00225 | 0.00628 | 1.74 | 1.2 | 0.00383 | 1.06 | 0.1 |
| 1.5 | 0.02286 | 0.01204 | 0.05035 | 2.20 | 2.3 | 0.02488 | 1.09 | 0.2 |
| 2.0 | 0.08532 | 0.03773 | 0.22926 | 2.69 | 3.8 | 0.09738 | 1.14 | 0.3 |
| 2.5 | 0.23143 | 0.08486 | 0.68229 | 2.95 | 5.3 | 0.27117 | 1.17 | 0.5 |
| 3.0 | 0.48279 | 0.15192 | 1.35999 | 2.82 | 5.8 | 0.58568 | 1.21 | 0.7 |

The ensemble mean varies by 12.8% at age 2 across a sixteenfold range of patch area, far less than the
2.7-fold discrepancy, so patch size is not the limiting factor; the largest patch carries 58, 112 and
177 individuals at ages 1, 2 and 3. Only two replicates were run at 64 m², so per-area standard
deviations there are not usable and the pooled ensemble is quoted. The comparison is not exact — the
solvers differ in finite population, discrete deaths and nonlinear averaging over replicates — so it
separates a 2.7-fold discrepancy from a 1.2-fold one. The corrected solver's residual 6% to 21%
excess is not schedule resolution and remains unexplained; see §6.2.

The individual-based solver cannot discriminate on the mature stand: after canopy closure its leaf
area agrees with both coordinates within its replicate spread, and its living stem density is too
variable to separate them, its own largest-patch value moving 7.2, 5.1, 5.0, 6.3 and 2.0 individuals
per m² across patch ages 20 to 100.

## Appendix F. Configuration, and defects found alongside

All results are measured on `plant` `develop` at commit `141dc8df`: single species, TF24 with
`lma = 0.1978791`, default `Environment` and `Control`, `max_patch_lifetime = 105.32`, 141 cohort
introductions, five soil layers, `refine_schedule = FALSE` unless stated, compiled `-O2 -DNDEBUG`.
Comparison runs use FF16 at `lma = 0.0825` and K93 at `b_0 = 0.059`. Refinement is by midpoint
insertion into the introduction schedule, so both coordinates see byte-identical schedules at each
level. Scripts and outputs are in [`probes/`](../../probes); the implementation is `plant` branch
`claude/nsc-density-measurements-efiolz`.

**A latent compilation defect, fixed here.** `SpeciesBase::control()` called
`strategy->get_control()`, which no strategy defines. The member had never been instantiated, so the
error had never been compiled.

**The stochastic schedule builder ignores patch area.** `stochastic_schedule()` passes `patch_area`
into `stochastic_arrival_times()`'s third positional argument, which is `delta_t`, so arrival rates
never scale with area and the binning interval is set to the area. Passing it by name is the fix, but
`test-stochastic-patch-runner.R` runs at `patch_area = 50` with seed-dependent expectations, so
correcting it makes that file roughly fifty times heavier and requires its parameters and baselines to
be revisited. Recorded and left unfixed.

**A height-ordering dependence remains in the competition loop, and it is now a live one.** The
density state no longer requires cohorts to stay ordered by height, but
`Species::compute_competition` keeps a height-ordered early exit (`if (h0 < height) break;`) and an
early return on `height_max()`. Out-of-order cohorts could therefore terminate the loop early and
drop contributions. No crossing occurs in the constant environment, but §6.3 finds 66 under a
full-amplitude seasonal light cycle, so this is a hazard that can be reached rather than a
theoretical one. The correction removes the ordering requirement for the state and not for that
loop, and closing it is outstanding work.

## References

Falster, D. S., FitzJohn, R. G., Brannstrom, A., Dieckmann, U., Westoby, M. (2016). plant: A package
for modelling forest trait ecology and evolution. *Methods in Ecology and Evolution* 7, 136-146.

Stefaniak, E. Z., Tissue, D. T., Falster, D. S., Medlyn, B. E. (2026). Greater variability in
environmental stress favours trees that prioritise storage of carbohydrate reserves over growth: a
modelling analysis. EGUsphere preprint, https://doi.org/10.5194/egusphere-2026-1474. Local copy:
[`docs/reference/stefaniak-et-al-2026-storage-strategies-egusphere-2026-1474.pdf`](../reference/stefaniak-et-al-2026-storage-strategies-egusphere-2026-1474.pdf)
(CC BY 4.0).
