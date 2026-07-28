# A light interpolant that carries its own slope

**Terminology.** `plant::Node` is a cohort, so this report says **knot** for a point
of an interpolant and reserves *node* for plant's meaning. `A(z)` is total projected
leaf area above height `z` per patch area — the optical depth — and `L(z) = exp(-A(z))`
is light availability, which is what `ResourceSpline` stores.

---

## 1. The proposal

A plant's crown occupies heights `0` to `H`, and `H` is a differentiable state. So
every quantity TF24 aggregates over a crown is an integral whose **domain moves when a
trait changes**, and the sensitivity of such an integral needs the integrand's
derivative along the direction the domain moves. For a light-dependent integrand that
means the vertical light gradient, `dL/dz`.

This is not a deep-crown problem. `quadrature::QK` maps its fixed rule affinely onto
the integration bounds, so every abscissa is `z = u_k * H` for fixed `u_k`, and all
three shading models therefore read the light field at heights proportional to the
plant's own:

```
CrownCentre  L(H * eta_c)
MeanLight    integral over [0, H] of  max(L(z), 1e-4) * q(z, H) dz      (TF24's default)
DeepCrown    one leaf solve per abscissa of [0, H]
```

Writing the mean-light case with `z = u H`:

    Phi(H) = H * integral over u in [0,1] of  L(u H) * q(u H, H) du

`d(Phi)/dH` has three parts. The explicit `H` in `q` and the outer factor are closed
form. For deep-crown there is also the leaf's sensitivity to its radiation input,
`d(profit_)/d(radiation)`, which the leaf's supplied local Jacobian provides (report 2).
The remaining part is `d/dH L(u H) = L'(u H) * u`, and **`L'` is the one quantity plant
cannot currently supply.**

`ResourceSpline` holds a cubic fitted to `L` values with an adaptive knot set refined
against a tolerance on the value. It exposes no slope accessor on the production path,
and a slope taken from it would not be pinned to anything: the knot set is chosen to
satisfy a value tolerance, so the fitting polynomial's derivative is whatever the fit
produced. Worse, `A(z)` is **C1 but not C2**, with a curvature break at every cohort
top — 141 of them at production — and a refiner chasing value error clusters knots near
those breaks rather than landing on them (section 3).

**The proposal, in three parts:**

**1. Compute `dA/dz` exactly. It is already in plant.** Every strategy declares the
leaf-area density `q(z, height)` next to the cumulative form, and differentiating the
cumulative form gives

    d/dz [ k_I * a * (1 - (z/H)^eta)^2 ]  =  -k_I * a * q(z, H)

exactly (section 4). So `dA/dz` is a second reduction over cohorts of the same shape as
`Patch::compute_competition`, using a function both mean-light and deep-crown already
call. No new mathematics, no separable-field algebra, no per-eta condition — each
cohort contributes with its own `pars.eta` and a sum is a sum.

**2. Put the knots at the cohort tops**, so the curvature breaks fall on knot
boundaries and every span's target is genuinely smooth.

**3. Interpolate with a cubic Hermite carrying a value and a slope at each knot**, so
`slope(u)` is the exact derivative of what `eval(u)` returns and neither is a by-product
of a fit.

**Measured.** Doing 2 and 3 gives the textbook convergence rates — **O(h^4)** on the
value and **O(h^3)** on the slope, ratios of 16.0 and 8.0 under subdivision — which is
the direct evidence that the breaks are resolved. The value-fitted cubic on the same
knots does not converge on the slope at all: 1.21e-03, 1.13e-03, 2.95e-04 over the same
refinement. At 565 knots the Hermite slope is **100x** better and the margin widens.
**That is the case:** not that the fitted slope is unusable at its current density, but
that slope accuracy is *purchasable with knots* in one scheme and not in the other, and
a quantity you cannot refine cannot be given an error budget.

**A third benefit, which is what report 1 depends on.** A C2 fit enforces
second-derivative continuity through a band solve over all knots, so one light read
depends on **every** knot value and its adjoint is a transposed band solve of
run-dependent width. A Hermite span depends on exactly **two** knots. Verified on a
live tape: `d(eval)/d(knot_2)` is 0.55 for a query in a span touching knot 2 and
**exactly 0** two spans away.

**Cost, and this is the weak point.** Query cost is fine: at matched knot count the
Hermite is 6% faster per value and 2.6x faster when value and slope are both wanted. The
build is the problem. Measured on a production TF24 run, the light interpolant is rebuilt
**20 304 times** — once per Runge-Kutta stage, not once per accepted step — costing
**3.92 s of a 59.5 s run, 6.6%**. Production takes the `rescale` path (20 160 calls)
rather than the adaptive `construct` (144 calls), and rescale re-evaluates the
competition kernel at each of its **65** knots. The Hermite needs **142** knots and two
reductions per knot, so on kernel-evaluation count the build is roughly **2.8x** more
expensive, projecting to **+11.8%** on the forward run (section 5.5).

That is above what a forward-path change should cost, and it is the open issue in this
proposal. Section 5.5 sets out what is and is not yet counted.

**This is the only one of the three proposals that changes forward-model numbers**, at
roughly the fitting tolerance, so baselines need re-blessing. It is also the only one
that delivers something on its own without the other two.

---

## 2. State at develop

`TF24_Environment::compute_environment` fits the interpolant to light availability:

```cpp
auto f_light_availability = [&](double height) -> double
  { return exp(-f_compute_competition(height)); };
light_availability.compute_environment(f_light_availability, height_max, rescale);
```

`light_availability` is a `ResourceSpline` constructed with
`(tol = 1e-4, nbase = 17, max_depth = 16, rescale_usually = true)`. It holds an
`odelia::interpolator::Interpolator` built by `interpolator::AdaptiveInterpolator`,
which bisects intervals until the fitted **value** meets `tol`. The read is

```cpp
double get_value_at_height(double height, double cap) const {
  return height <= cap ? std::max(0.0, spline(height)) : 1.0;
}
```

The `std::max(0.0, ...)` guards a real defect, documented in place: the cubic can
undershoot below zero between knots — notably the K93 light interpolant at high `k_I` —
which is non-physical for a resource availability.

Three properties follow, and together they are the case for changing it:

- **No slope accessor exists on the production path.** `odelia`'s `Interpolator` has a
  `deriv`, but nothing in develop calls it for the light field.
- **A slope from this construct is unpinned.** The knot set satisfies a value
  tolerance; the derivative is not constrained by it, not measured, and not bounded by
  `tol`.
- **The target is not smooth at the knot scale.** Section 3.

---

## 3. Why the value is easy and the slope is not

From `TF24_Strategy::compute_competition`, the optical depth is

    A(z) = sum over species, over cohorts of
             density_j * k_I * a_j * (1 - (z/H_j)^eta)^2 / area      for z <= H_j, else 0

Each cohort's contribution and its first derivative both vanish as `z -> H_j`: with
`u = z/H_j` the term is `(1-u^eta)^2`, and near `u = 1` we have `(1 - u^eta) ~ eta(1-u)`,
so the term is O((1-u)^2) and its `z`-derivative is O(1-u). The **second** derivative
does not vanish. Therefore:

> **`A(z)` is C1 but not C2, with a curvature break at every distinct cohort height** —
> 141 of them at production.

That single fact explains the asymmetry. A cubic fitted to values converges at O(h^4),
and its derivative at O(h^3), *on a span where the target is smooth*. An adaptive
refiner chasing value error places knots where the value error is worst, which is near
the breaks: it clusters around them rather than landing on them. The value survives
because a C1 function is well approximated in value by a smooth interpolant. The slope
does not, and refining further does not help, because each new knot still sits inside a
span containing a curvature jump.

Hence the two design consequences in section 1: knots **at** the cohort heights, and a
slope **supplied** rather than inferred.

---

## 4. The vertical gradient, in closed form

Every strategy already declares the leaf-area density alongside the cumulative form:

```cpp
double TF24_Strategy::compute_competition(double z, double area_leaf_,
                                          double height_inverse) const {
  const double u = z * height_inverse;
  if (u > 1.0) return 0.0;
  const double tmp = 1.0 - pow(u, pars.eta);
  return pars.k_I * area_leaf_ * tmp * tmp;
}

double TF24_Strategy::q(double z, double height) const {
  const double tmp = pow(z / height, pars.eta);
  return 2 * pars.eta * (1 - tmp) * tmp / z;
}
```

Differentiating the first with respect to `z`, with `u = z/H`:

    d/dz [ k_I a (1-u^eta)^2 ]  =  k_I a * 2 (1-u^eta) * ( -eta u^(eta-1) / H )
                                =  -k_I a * 2 eta (1-u^eta) u^eta / z
                                =  -k_I a * q(z, H)

using `u^(eta-1)/H = u^eta/(uH) = u^eta/z`. So **`q(z, H)` is exactly the negative
vertical derivative of the competition kernel** — already declared, already called by
both mean-light and deep-crown, already correct for every strategy.

The field's vertical derivative is therefore a second reduction of the same shape as
`Patch::compute_competition`:

```
Patch::compute_competition_slope(z)
  = - sum over species, over cohorts of  density_j * k_I * a_j * q(z, H_j) / area
```

and `dL/dz = -L(z) * dA/dz`. The two reductions share `pow(z/H_j, eta)`, which
dominates both, so they should be formed in one pass; section 5.5 quantifies the cost
of not doing so.

---

## 5. The interpolant, and what it measures

`odelia/inst/include/odelia/hermite_interpolator.hpp`:

```cpp
template <typename S> class hermite_interpolator {
  void init(const std::vector<double>& x, const std::vector<S>& y,
                                         const std::vector<S>& dydx);
  S    eval(double u) const;              // value
  S    operator()(double u) const;
  S    slope(double u) const;             // the exact derivative of eval's polynomial
  void value_and_slope(double u, S& value, S& dydu) const;   // one lookup, one span load
  double min() const;  double max() const;  std::size_t size() const;
  const std::vector<double>& knots() const;  void clear();
};
```

Knot positions are `double`; values and slopes carry the working scalar `S`. The surface
mirrors `basic_interpolator` so `ResourceSpline` can hold one in place of the other,
with a slope vector added at `init`. (odelia's older value-fitted `Interpolator` spells
the same operation `deriv`; this type uses `slope` throughout for consistency with
`value_and_slope`.)

On span `[x_k, x_{k+1}]` with `h = x_{k+1} - x_k` and `t = (u - x_k)/h`, the Hermite
basis is rearranged into a cubic in `t` and stored per span as one contiguous record
`{x0, inv_h, y0, c1, c2, c3}`, so a query touches a single cache line. Outside the knot
range the end slope is extended linearly, which keeps the read C1 across the boundary
rather than letting a cubic diverge — and removes the need for the undershoot guard of
section 2, since a Hermite interpolant between two non-negative knots with the correct
end slopes does not undershoot the way a C2 fit does.

### 5.1 Exactness and locality

| check | result |
|---|---|
| a cubic target reproduced, value | 2.84e-14 max absolute |
| a cubic target reproduced, slope | 1.42e-14 max absolute |
| `d(eval)/d(knot_2)`, query in a span touching knot 2 | 0.55 |
| `d(eval)/d(knot_2)`, query two spans away | **exactly 0** |

The last two are the locality claim, verified on a live XAD tape with the knot value
registered as an input rather than argued from the basis functions.

### 5.2 Accuracy against the real profile

Harness `scratchpad/interp_probe.cpp` at `-O2`. Target `L(z) = exp(-A(z))` over 141
cohorts with `eta = 12`, heights distributed as an SCM produces them, probed at 20 001
points chosen to avoid the knots — where every scheme is pinned and none can be
distinguished.

Errors are normalised to the largest value the quantity takes over the domain. This is
deliberate: `dL/dz` passes through zero at the canopy top and wherever crown
contributions cancel, so a **pointwise** relative error is unbounded there and its mean
and maximum report the reference magnitude rather than the interpolant. A global
normalisation is the meaningful measure for a quantity entering a chain rule.

| knots | scheme | value (mean) | slope (mean) | slope (max) |
|---|---|---|---|---|
| 142 | Hermite at cohort tops | **6.57e-06** | **1.89e-04** | **2.46e-03** |
| 73 | value-fitted cubic, adaptive at `tol = 1e-4` | 1.04e-05 | 4.29e-04 | 1.73e-02 |
| 142 | value-fitted cubic, same knots as the Hermite | 3.05e-05 | 1.21e-03 | 6.64e-02 |

At its production configuration the fitted interpolant settles on 73 knots with a mean
slope error of 4.3e-04 and a maximum of 1.7e-02. The Hermite is better on every column,
but at a single knot density the margin is a factor of two to seven — not, on its own,
a compelling argument.

### 5.3 Convergence — the argument

Subdividing each cohort-top span uniformly:

| knots | Hermite value | Hermite slope | fitted cubic slope, same knots |
|---|---|---|---|
| 142 | 6.57e-06 | 1.89e-04 | 1.21e-03 |
| 283 | 4.09e-07 | 2.35e-05 | 1.13e-03 |
| 565 | 2.56e-08 | 2.94e-06 | 2.95e-04 |

Hermite ratios: **16.0 and 16.0** on the value, which is O(h^4); **8.0 and 8.0** on the
slope, which is O(h^3). Those are the textbook rates, and obtaining them *is* the
evidence that the breaks are resolved — a scheme smoothing over curvature jumps cannot
achieve them.

The fitted cubic on the same knots goes 1.21e-03, 1.13e-03, 2.95e-04: essentially flat,
then erratic. At 565 knots the Hermite slope is 100x better and the margin widens with
refinement.

At `eta = 4` every scheme improves and the ordering is unchanged (Hermite slope
6.82e-05 at 142 knots against the fitted 7.48e-04), so the conclusion is not an
artefact of TF24's sharp default canopy shape.

### 5.4 Query cost

4 000 000 queries in the access pattern of a crown integral — abscissae inside each
cohort's crown in turn — best of seven runs:

| scheme | knots | value | value + slope |
|---|---|---|---|
| value-fitted cubic | 73–81 | 19.5 ns | 33.4 ns |
| value-fitted cubic | 142 | 42.2 ns | 78.0 ns |
| **Hermite** | 142 | **39.0 ns** | **29.7 ns** |

At matched knot count the Hermite is 6% faster for a value and **2.6x faster** when
both are wanted, because `value_and_slope` shares one knot lookup and one span load.
The interpolant is not slower; a larger knot set is. Going from 73–81 to 142 knots costs
roughly 2x on value-only queries, and that cost is real and not tunable — the knot set
is determined by the stand.

### 5.5 Build cost — measured on plant, and unfavourable

The interpolant is rebuilt inside every `Patch::set_ode_state`. That is called at every
Runge-Kutta **stage**, not once per accepted step, which was worth measuring rather than
assuming. Instrumenting `ResourceSpline::compute_environment` on a production TF24 run
(`max_patch_lifetime = 105.32`, 2 829 accepted steps, 59.5 s):

| path | calls | total | per call | knots |
|---|---|---|---|---|
| `construct_spline` (adaptive refinement) | 144 | 0.021 s | 143.0 us | — |
| `rescale_spline` (reuse the knot set, re-evaluate) | **20 160** | **3.895 s** | 193.2 us | 65 |
| both | 20 304 | **3.916 s = 6.6% of the run** | | |

Three things follow, and the first two were wrong in an earlier version of this report.

**The multiplier is 7.13, not 1.** 20 160 rescales against 2 829 accepted steps: the
field is rebuilt per stage because it depends on state, and state changes per stage.
Any per-build cost is multiplied by that.

**Production takes the `rescale` path, 140 times more often than `construct`.** The 144
`construct` calls come from `introduce_new_node`, which passes `rescale = false`; the
20 160 rescales come from `set_ode_state`, which passes `true`. So the baseline to beat
is `rescale`, not the adaptive build.

**`rescale` is not cheap, and it is the closest analogue to a Hermite build.** It
re-evaluates the competition kernel at each of its 65 knots and then runs the band solve
in `initialise()`. The Hermite build evaluates two reductions — `A` and `dA/dz`, sharing
their `pow(z/H_j, eta)` if fused — at **142** knots, and needs no band solve. Counting
kernel evaluations as the dominant term: 142 knots at roughly 1.3x the per-knot
arithmetic against 65 knots at 1.0x gives about **2.8x**, projecting

    59.5 s  -  3.916 s  +  3.916 s x 2.8  ~=  66.5 s      = +11.8%    (projected)

**What is not yet counted, in both directions.** Against the Hermite: nothing — the 2.8x
already assumes the fused reduction. In its favour: it does no band solve, no
`clear()` and `add_point` loop with reallocation, and no adaptive refinement; and 65
knots is the *final* count, so the average over the run is lower and the true rescale
baseline may be cheaper than 193.2 us implies at small stand sizes. Those are real
savings that the kernel-evaluation count ignores, and they are why this is a projection
rather than a measurement.

**The honest position: the query side is settled and favourable, the build side is not,
and 142 knots against 65 is the driver.** The knot count is not tunable — the knots are
the cohort tops, which is what buys the convergence in section 5.3 — so closing this gap
means either measuring the omitted savings and finding them larger than they look, or
accepting a forward-path cost of several percent, or finding a formulation that needs
fewer knots. It should be measured properly, by wiring a Hermite build into
`ResourceSpline` alongside the existing one and timing both on the same run, before the
proposal is accepted.

Two things are removed from the build side in exchange and are not counted above: the
adaptive refinement loop disappears entirely — the knot set is the cohort heights, known
without searching — and with it `spline_tol`, `spline_nbase` and `spline_max_depth` cease
to influence any gradient.

---

## 6. Constraints

**C1. Knot positions must be passive, and that drops a channel.** Cohort heights are
ODE state carrying derivatives, so knot positions are `to_passive(H_j)`. A cohort's
height then enters `A` through the physics — its amplitude and its `(1-(z/H_j)^eta)`
shape, both carried — and through the knot position, which is dropped. Dropping the
second is correct: moving a knot changes the interpolant, not the interpolated
function, and it is the same treatment plant already gives adaptive knot sets. The size
of what is dropped was measured in the coupled system of report 1 at **8.7e-04,
independent of the finite-difference step** — so real, not noise — at a coarse 20 knots.
It should shrink with knot density; that convergence was not measured and should be, at
production counts.

**C2. Knot count roughly doubles**, 142 against 73–81. That is the 2x on value-only
queries in section 5.4, and it is set by the stand rather than by a tolerance.

**C3. Cohorts converging in height.** Knots at cohort tops means spans can narrow as
cohorts converge, and a span far below the domain scale makes the Hermite coefficients
a difference of near-equal numbers divided by that span. This was expected to be the
scheme's weak point. **It was measured and did not occur**: minimum span 3.7e-02 over a
full coupled run. A merge tolerance relative to the domain is implemented as cheap
insurance, not as a fix for an observed problem.

**C4. Numbers move and baselines need re-blessing.** Replacing an interpolant fitted to
`tol = 1e-4` with one exact at 142 knots changes light values at approximately that
order. `test-strategy-tf24.R`, `test-canopy-methods.R` and the FF16 references under
`tests/testthat/FF16_reference/` are affected.

**C5. `rescale_usually` has no analogue, and it is the production path.** Measured:
20 160 rescales against 144 constructs on a production run (section 5.5).
`rescale_spline` reuses the existing knot set — rescaled affinely to the new
`height_max` — and re-evaluates. With knots at cohort heights the knot set changes
whenever a cohort grows, so there is nothing to reuse and every build is a full build.
This is the largest open cost in the proposal: +11.8% projected against a measured 6.6%
current cost, driven by 142 knots against 65.

**C6. `pow(0, eta)` is a live hazard at the ground knot.** `d/d(eta) 0^eta =
0^eta log(0)`, which is NaN. `A(0)` and `dA/dz(0)` are the natural first knot, and
`Patch::compute_competition(0.0)` is already called on the production path by
`Node::compute_competition`. In the coupled system of report 1 this produced a NaN
gradient for exactly one trait while every other trait stayed finite and plausible. At
`z = 0` the cohort contributes its full amplitude with `u = 0` and no `pow` is needed,
so the fix is a guard rather than a reformulation.

**C7. The `1e-4` light floor.** `compute_average_light_environment` clamps light to
`max(get_environment_at_height(z), 0.0001)`, with a comment recording that the original
rationale was never written down. That clamp is a derivative severance wherever it
binds: on the clamped side `dL/dz` is zero. Its incidence should be counted, since a
deeply shaded understorey is exactly where it would bind and exactly where a census
metric has weight.

---

## 7. What this asks of a Strategy author

A Strategy that aggregates anything over a spatial extent it controls — a crown, a
rooting depth, a canopy layer — has obligations the engine cannot check. Stated as
guidance, each rule with the construct that motivates it:

**1. If you integrate over your own size, you need the integrand's slope.** This is the
whole of section 1. It is easy to miss because the value is correct and only the
derivative is wrong, and it applies to any aggregation with a state-dependent domain —
TF24's root mass distribution over soil layers has exactly the same shape, with
`rooting_depth = min(height, 1.5)` as the moving bound.

**2. If you declare a cumulative form, declare its density too — and check they
agree.** `compute_competition` and `q` are an exact derivative pair, which is what
makes section 4 free. A strategy that declared only the cumulative form would force its
slope to be approximated; one that declared both without checking could have them drift
apart silently, since nothing currently ties them.

**3. Know where your field is non-smooth, and put knots there.** The breaks in `A(z)`
are at the cohort tops, which are ODE state — so the knot set is data, not a tuning
choice. A refiner chasing a value tolerance will not find them (section 3).

**4. Value and slope must come from one construct.** Two constructs — a fitted value and
a separately computed slope — agree nowhere except by accident, and the disagreement is
invisible in the value. This is what `value_and_slope` on a Hermite basis guarantees
structurally.

**5. Positions are structure; values carry derivatives.** Knot positions, quadrature
abscissae and cohort orderings are decided on passive values and are `double` by type.
Only the values at those positions carry `S`. Breaking this — sorting on an active key,
or letting a knot *count* depend on an active value — makes the recorded computation
state-dependent.

**6. A clamp is a derivative severance; say whether you mean it.** C7's `1e-4` floor and
the `std::max(0.0, spline(height))` undershoot guard both zero a derivative on one side.
Sometimes that is the model. Sometimes it is papering over an interpolant that
undershoots, which is a different problem with a different fix.

---

## 8. Implementation order

1. **Add `Patch::compute_competition_slope(z)`** — section 4's reduction, fused with
   `compute_competition` so `pow(z/H_j, eta)` is computed once. Verify against a tight
   central difference of `compute_competition`, covering both the eta-specialised
   multiply chains in `CanopyShape` and the general `std::pow` path.
2. **Guard `z = 0`** per C6, in `compute_competition` and the new reduction.
3. **Hold a `hermite_interpolator` inside `ResourceSpline`** beside the existing one,
   built on the cohort heights from the two reductions, and add
   `get_value_and_slope_at_height`. Keep the fitted interpolant initially so the two can
   be compared on live runs.
4. **Measure C1's convergence** — the knot-position channel against knot density at
   production width. This decides whether cohort-top knots suffice or spans need
   subdividing.
5. **Time the Hermite build against `rescale_spline` on one production run**, both
   wired into `ResourceSpline`. Section 5.5's +11.8% is a projection from kernel-evaluation
   counts and it is the number that decides whether this proposal is affordable.
6. **Switch the read**, re-bless the baselines, confirm the forward benchmark is within
   the accepted band.
7. **Then** wire the slope into the crown integral's height channel, which is where the
   gradient benefit is realised.

Steps 1, 2 and 4 need no AD and no gradient run. Step 1 alone is worth having: an exact
`dA/dz` is a legitimate diagnostic of the light field independent of any derivative
work.

---

## 9. What would falsify this

- **The `q` identity does not hold numerically.** Compare `-k_I * a * q(z, H)` against a
  tight central difference of `compute_competition(z, ...)` across `eta` in
  {1, 2, 4, 8, 10, 12} and a general non-integer `eta`. The specialised multiply chains
  and the `std::pow` path must agree; if they do not, the slope inherits the
  discrepancy.
- **The Hermite does not converge at production density.** Section 5.3 used a synthetic
  stand. Repeat it on knot sets and amplitudes taken from a real
  `Patch::compute_environment` call at `max_patch_lifetime = 105.32`. Loss of the O(h^3)
  rate means the breaks are not where section 3 says they are.
- **The knot-position channel does not shrink with knot density.** Then C1 is a floor
  rather than a discretisation error, and the passive-position treatment needs
  revisiting.
- **The build cost exceeds the forward-performance budget.** Section 5.5 projects
  +11.8% from a kernel-evaluation count. Settle it by wiring a Hermite build into
  `ResourceSpline` beside the existing one and timing both on one production run. If the
  omitted savings — no band solve, no refinement loop, no reallocating knot append — do
  not bring it under a few percent, the proposal needs a formulation with fewer knots
  and section 5.3's convergence argument has to be re-made at that density.
