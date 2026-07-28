# A light interpolant that carries its own slope

A proposal for supplying the vertical light gradient that
`d(assimilation)/d(own height)` requires, addressed to plant maintainers. It
concerns `ResourceSpline`, `Patch::compute_environment`, and one closed-form
identity already present in every strategy.

Numbers labelled **measured** were produced in this study, with the harness named.
Numbers labelled **projected** are arithmetic on measured quantities.

---

## 1. What plant needs and cannot currently supply

TF24's crown aggregation, in all three shading models, integrates a light-dependent
quantity over the crown of a plant whose height is a differentiable state:

```
CrownCentre  light_openness = get_environment_at_height(height * eta_c)
MeanLight    light_openness = integrate( max(get_environment_at_height(z), 1e-4) * q(z, height),
                                         0, height )            tf24_strategy.cpp:41, :462
DeepCrown    one leaf solve per Gauss-Kronrod abscissa of [0, height]
```

`quadrature::QK` maps its fixed rule affinely onto the integration bounds, so every
abscissa is `z = u_k * height` for fixed `u_k`. Substituting, the mean-light
aggregation is

    Phi(H) = H * integral over u in [0,1] of  L(u H) * q(u H, H) du

and differentiating with respect to the plant's own height H gives three terms:

1. the explicit `H` in `q(., H)` and the outer factor — closed form, `q` is analytic;
2. `d/dH L(u H) = L'(u H) * u` — **requires the vertical light gradient**;
3. for deep-crown only, the leaf's sensitivity to its radiation input, which is
   report 2's node.

Only term 2 is missing, and it is missing identically for crown-centre, mean-light
and deep-crown, because all three read the light field at heights proportional to
the plant's own. **One quantity, `dL/dz`, unblocks the height channel for every
shading model.** Nothing about the following is specific to deep-crown, and nothing
requires changing the default.

### 1.1 What develop's interpolant provides

`TF24_Environment::compute_environment` (`tf24_environment.h:355-366`) fits a spline
to light availability:

```cpp
auto f_light_availability = [&](double height) -> double
  { return exp(-f_compute_competition(height)); };
light_availability.compute_environment(f_light_availability, height_max, rescale);
```

`light_availability` is a `ResourceSpline` constructed with
`(tol = 1e-4, nbase = 17, max_depth = 16, rescale_usually = true)`
(`tf24_environment.h:46-51`). Internally it holds an
`odelia::interpolator::Interpolator` built by `interpolator::AdaptiveInterpolator`,
which bisects intervals until the fitted **value** meets `tol`. The read is

```cpp
double get_value_at_height(double height, double cap) const {
  return height <= cap ? std::max(0.0, spline(height)) : 1.0;
}
```

The `std::max(0.0, ...)` is documented as guarding a genuine defect: "the cubic
spline can undershoot below zero between knots (notably the K93 light spline at high
`k_I`), which is non-physical for a resource availability" (`resource_spline.h:81-87`).

Three properties follow, and together they are the case for changing it:

- **There is no slope accessor at all on the production path.** The interpolant
  exposes `eval`/`operator()`; a `deriv` exists on odelia's `Interpolator` but
  nothing in develop calls it for the light field.
- **A slope taken from this construct would not be pinned to anything.** The node
  set is chosen to satisfy a tolerance on the value. The derivative of the fitting
  polynomial is then whatever the fit produced — it is not constrained, not
  measured, and not bounded by `tol`.
- **The target is not smooth at the node scale.** See next section.

---

## 2. Why the value is easy and the slope is not

Write the total projected leaf area above height `z`, per patch area, as develop
computes it:

    A(z) = sum over species, over nodes of  density_j * k_I * a_j * (1 - (z/H_j)^eta)^2 / area
                                                                   for z <= H_j, else 0

from `TF24_Strategy::compute_competition(z, area_leaf_, height_inverse)`. Then
`L(z) = exp(-A(z))`.

Each cohort's contribution and its first derivative both vanish as `z -> H_j`:
with `u = z/H_j`, the term is `(1-u^eta)^2` and near `u = 1` we have
`(1 - u^eta) ~ eta (1-u)`, so the term is O((1-u)^2) and its `z`-derivative is
O(1-u). The **second** derivative does not vanish. So:

> **`A(z)` is C1 but not C2, with a curvature break at every distinct cohort
> height.** At production there are **141** of them.

That is the whole difficulty, and it explains the asymmetry cleanly. A cubic
interpolant fitted to values converges at O(h^4) on a smooth target and its
derivative at O(h^3) — but only where the target *is* smooth on the span. An
adaptive refiner chasing a value tolerance places nodes wherever the value error is
worst, which is near the breaks; it clusters around them rather than landing on
them. The value survives that because a C1 function is well approximated in value
by a smooth interpolant. The slope does not, and refining further does not fix it,
because each new node still sits inside a span containing a curvature jump.

Two design consequences:

- **Nodes should be placed at the cohort heights**, so the breaks fall on node
  boundaries and every span's target is genuinely smooth.
- **The slope should be supplied, not inferred**, so it is pinned to an exact value
  at every node rather than being a by-product of the fit.

---

## 3. The vertical gradient is a closed form plant already contains

Every strategy already defines the leaf-area density `q(z, height)` alongside the
cumulative form. For TF24 (`tf24_strategy.cpp`):

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

Differentiate the first with respect to `z`, with `u = z/H`:

    d/dz [ k_I a (1-u^eta)^2 ]  =  k_I a * 2 (1-u^eta) * ( -eta u^(eta-1) / H )
                                =  -k_I a * 2 eta (1-u^eta) u^eta / z
                                =  -k_I a * q(z, H)

using `u^(eta-1)/H = u^eta / (uH) = u^eta / z`. So:

> **`q(z, H)` is exactly the negative vertical derivative of the competition
> kernel.** The function needed for `dA/dz` is already declared, already used by
> both mean-light and deep-crown, and already correct for every strategy.

The field's vertical derivative is therefore a second reduction of exactly the same
shape as `Patch::compute_competition`:

```
Patch::compute_competition_slope(z)
  = - sum over species, over nodes of  density_j * k_I * a_j * q(z, H_j) / area
```

and `dL/dz = -L(z) * dA/dz`. No new mathematics, no separable-field algebra, no
change to the transported variable, and no per-eta condition: each cohort
contributes with its own `pars.eta` and a sum is a sum.

The two reductions share `pow(z/H_j, eta)`, which is the dominant cost in both, so
they should be formed in one pass. Section 6 quantifies what happens if they are
not.

---

## 4. The interpolant

`odelia/inst/include/odelia/hermite_interpolator.hpp` (written for this study).
A C1 piecewise cubic built from a value **and** a slope at each node:

```cpp
template <typename S> class hermite_interpolator {
  void init(const std::vector<double>& x, const std::vector<S>& y,
                                          const std::vector<S>& dydx);
  S    eval(double u) const;                 // value
  S    operator()(double u) const;
  S    deriv(double u) const;                // the exact derivative of eval's polynomial
  void eval_and_deriv(double u, S& value, S& slope) const;   // one lookup, one span load
  double min() const;  double max() const;  std::size_t size() const;  void clear();
};
```

Node positions are `double`; values and slopes carry the working scalar `S`. The
surface deliberately mirrors `basic_interpolator` so `ResourceSpline` can hold one
in place of the other with the addition of a slope vector at `init`.

On span `[x_k, x_{k+1}]` with `h = x_{k+1} - x_k` and `t = (u - x_k)/h`, the
coefficients are the standard Hermite basis rearranged into a cubic in `t`, stored
per span as one contiguous record `{x0, inv_h, y0, c1, c2, c3}` so a query touches a
single cache line. Outside the node range the end slope is extended linearly, which
keeps the read C1 across the boundary rather than letting a cubic diverge — and
removes the need for the `std::max(0.0, ...)` undershoot guard, since a Hermite
interpolant between two non-negative nodes with the correct end slopes does not
undershoot the way a C2 fit does.

Three properties matter, in ascending order of importance.

**Consistency.** `deriv(u)` is the exact derivative of the polynomial `eval(u)`
returns. There is no arrangement in which a caller can obtain a value and a slope
from different constructs.

**Breakpoint resolution.** With nodes at the cohort heights, every span's target is
smooth, so the classical convergence rates apply. Section 5 measures them.

**Locality — and this is the property that matters most for report 1.** A C2 spline
enforces second-derivative continuity through a tridiagonal solve over all nodes, so
the interpolated value at any point depends on **every** node value. A Hermite
interpolant's span depends only on its own two nodes. Consequences:

- The adjoint of a light read reaches exactly two nodes, not the whole node set, and
  costs O(1) rather than a transposed band solve of run-dependent width.
- Moving a node changes the interpolant only in the two spans touching it.
- Value and slope are both pinned at each node, so when a node crosses a query point
  and the bracketing pair changes, `eval` and `deriv` are **continuous** across the
  change. Under a C2 fit, changing the node set moves every coefficient and the
  interpolant jumps by the fitting tolerance — in a quantity a derivative flows
  through.

---

## 5. Measurements

Harness: `scratchpad/interp_probe.cpp`, compiled at `-O2` against odelia's headers.
The target is the real profile of section 2 — `L(z) = exp(-A(z))` over a stand of
141 cohorts with `eta = 12`, heights distributed as an SCM produces them (many
small, few tall) — probed at 20 001 points chosen to avoid the nodes, where every
scheme is pinned and no scheme can be distinguished.

Errors are normalised to the largest value the quantity takes over the domain. This
matters and is worth stating explicitly: `dL/dz` passes through zero at the canopy
top and wherever crown contributions cancel, so a **pointwise** relative error is
unbounded there and its mean and maximum report the reference magnitude rather than
the interpolant. A global normalisation is the meaningful measure for a quantity
entering a chain rule.

### 5.1 Exactness and locality

| check | result |
|---|---|
| a cubic target reproduced, value | 2.84e-14 max absolute |
| a cubic target reproduced, slope | 1.42e-14 max absolute |
| `d(eval)/d(node_2)`, query in a span touching node 2 | 0.55 |
| `d(eval)/d(node_2)`, query two spans away | **exactly 0** |

The last two rows are the locality claim, verified on a live XAD tape with the node
value registered as an input rather than argued from the basis functions.

### 5.2 Accuracy against the real profile

| nodes | scheme | value (mean) | slope (mean) | slope (max) |
|---|---|---|---|---|
| 142 | Hermite at cohort tops | **6.57e-06** | **1.89e-04** | **2.46e-03** |
| 73 | value-fitted cubic, adaptive at `tol = 1e-4` | 1.04e-05 | 4.29e-04 | 1.73e-02 |
| 142 | value-fitted cubic, same nodes as the Hermite | 3.05e-05 | 1.21e-03 | 6.64e-02 |

At its own production configuration the fitted spline settles on 73 nodes and gives
a mean slope error of 4.3e-04 and a maximum of 1.7e-02. The Hermite is better on
every column, but at a single node density the margin is a factor of two to seven —
not, on its own, a compelling argument.

### 5.3 Convergence — the argument

Subdividing each cohort-top span uniformly:

| nodes | Hermite value | Hermite slope | fitted cubic slope, same nodes |
|---|---|---|---|
| 142 | 6.57e-06 | 1.89e-04 | 1.21e-03 |
| 283 | 4.09e-07 | 2.35e-05 | 1.13e-03 |
| 565 | 2.56e-08 | 2.94e-06 | 2.95e-04 |

Hermite ratios: **16.0 and 16.0** on the value, which is O(h^4); **8.0 and 8.0** on
the slope, which is O(h^3). Those are the textbook rates, and obtaining them is the
direct evidence that the breakpoints are resolved — a scheme smoothing over
curvature jumps cannot achieve them.

The fitted cubic on the same nodes goes 1.21e-03, 1.13e-03, 2.95e-04: essentially
flat, then erratic. At 565 nodes the Hermite slope is **100x** better, and the
margin widens with refinement.

**This is the case.** Not that the fitted spline's slope is unusable at its current
density, but that slope accuracy is *purchasable with nodes* in one scheme and not
in the other. A quantity that cannot be refined cannot be given an error budget,
and `d(assimilation)/d(own height)` needs one.

At `eta = 4` every scheme improves and the ordering is unchanged (Hermite slope
6.82e-05 at 142 nodes against the fitted 7.48e-04), so the conclusion is not an
artefact of TF24's sharp default canopy shape.

### 5.4 Query cost

4 000 000 queries in the access pattern of a crown integral (abscissae inside each
cohort's crown in turn), best of seven runs:

| scheme | nodes | value | value + slope |
|---|---|---|---|
| value-fitted cubic | 73–81 | 20.3 ns | 35.2 ns |
| value-fitted cubic | 142 | 41.9 ns | 76.2 ns |
| **Hermite** | 142 | **39.4 ns** | **30.2 ns** |

At matched node count the Hermite is 6% faster for a value and **2.5x faster** when
both value and slope are wanted, because `eval_and_deriv` shares one node lookup
and one span load. The interpolant is not slower; a larger node set is. Going from
73–81 nodes to 142 costs roughly 2x on value-only queries and that cost is real.

An earlier version of this benchmark reported the Hermite at 2.1e-08 s for four
million queries, which was the optimiser deleting the loop because the checksum did
not escape. The numbers above keep it.

### 5.5 Build cost

The interpolant is rebuilt inside every `Patch::set_ode_state`, so build cost is
multiplied by the step count rather than amortised.

| | per step, 141 cohorts | projected over 2 829 steps |
|---|---|---|
| value-fitted, adaptive to `tol = 1e-4` | 82.3 us | 0.23 s |
| Hermite at cohort tops (142 nodes) | 446.6 us | 1.26 s |

Against a measured 53.1 s forward run that is **+1.9%** (projected). The ratio of
5.4x has an identified and untaken halving: the harness evaluates `A` and `dA/dz` in
two separate passes, each recomputing `pow(z/H_j, eta)`, and section 3 notes they
share it. A fused reduction should bring the build to roughly 2.7x and the run cost
to about **+0.7%**.

Two things are removed from the build side in exchange, and neither is counted above:
the adaptive refinement loop disappears entirely (the node set is the cohort
heights, known without searching), and with it `spline_tol`, `spline_nbase` and
`spline_max_depth` cease to influence any gradient.

---

## 6. Constraints

**C1. Node positions must be passive, and that drops a channel.** Cohort heights are
ODE state carrying derivatives, so the node positions are `to_passive(H_j)`. A
cohort's height then enters `A` through the physics (its amplitude and its
`(1-(z/H_j)^eta)` shape, both carried) and through the node position (dropped).
Dropping the second is correct — moving a node changes the interpolant, not the
interpolated function — and it is the same treatment plant already gives adaptive
node sets elsewhere. The size of what is dropped was measured in the coupled system
of report 1 at **8.7e-04, independent of the finite-difference step** (so real, not
noise), at a coarse 20 nodes. It should shrink with node density; that convergence
was not measured and should be, at production node counts.

**C2. Node count roughly doubles.** 142 at production against the 73–81 the adaptive
fit settles on. That is the 2x on value-only queries in section 5.4. It is not
tunable: the node set is determined by the stand.

**C3. Cohorts converging in height.** Nodes at cohort tops means spans can narrow as
cohorts converge. This was expected to be the scheme's weak point — a span far below
the domain scale makes the Hermite coefficients a difference of near-equal numbers
divided by that span. **It was measured and it did not occur**: minimum span 3.7e-02
over a full coupled run. A merge tolerance relative to the domain is cheap insurance
and is implemented, but it is insurance rather than a fix for an observed problem.

**C4. Numbers will move and baselines need re-blessing.** Replacing an interpolant
fitted to `tol = 1e-4` with an interpolant exact at 142 nodes changes light values at
approximately that order. `test-strategy-tf24.R`, `test-canopy-methods.R` and the
FF16 references under `tests/testthat/FF16_reference/` are affected. This is a
deliberate forward-model change, smaller in scope than either a change of transported
variable or a new field representation, but it is not zero.

**C5. `rescale_usually` has no analogue.** `ResourceSpline::compute_environment`
takes a `rescale` flag and, when `spline_rescale_usually` is set, calls
`rescale_spline` rather than rebuilding — a speed path that reuses the existing node
set with new values. With nodes at cohort heights the node set changes whenever a
cohort grows, so there is nothing to reuse. The 82.3 us figure in section 5.5 is a
full `construct`; if the rescale path dominates in production the comparison is less
favourable than stated and should be re-measured on a real run.

**C6. `pow(0, eta)` is a live hazard at the ground node.** `d/d(eta) 0^eta =
0^eta log(0)`, which is NaN. `A(0)` and `dA/dz(0)` are the natural first node, and
`Patch::compute_competition(0.0)` is already called on the production path by
`Node::compute_competition`. In the coupled system of report 1 this produced a NaN
gradient for exactly one trait while every other trait stayed finite and plausible.
Whether plant's active path reaches it should be checked; at `z = 0` the cohort
contributes its full amplitude with `u = 0` and no `pow` is needed, so the fix is a
guard rather than a reformulation.

**C7. The floor at `1e-4`.** `compute_average_light_environment` clamps light to
`max(get_environment_at_height(z), 0.0001)`, with a comment recording that the
original rationale was never written down. That clamp is a derivative severance
wherever it binds: on the clamped side `dL/dz` is zero. Its incidence should be
counted the way report 2 counts the leaf branches, since a deeply shaded understorey
is exactly where it would bind and exactly where a census metric has weight.

---

## 7. Implementation order

1. **Add `Patch::compute_competition_slope(z)`** — the reduction of section 3,
   fused with `compute_competition` so `pow(z/H_j, eta)` is computed once. Verify it
   against a tight central difference of `compute_competition`, including both the
   eta-specialised multiply chains in `CanopyShape` and the general `std::pow` path,
   since a discrepancy between those two would show up here first.
2. **Guard `z = 0`** per C6, in `compute_competition` and the new slope reduction.
3. **Hold a `hermite_interpolator` inside `ResourceSpline`** beside the existing
   spline, built on the cohort heights from the two reductions, and add
   `get_value_and_slope_at_height`. Keep the fitted spline in place initially so the
   two can be compared on live runs.
4. **Measure C1's convergence** — the node-position channel against node density at
   production width. This decides whether the cohort-top node set is sufficient or
   whether spans need subdividing.
5. **Re-measure build cost on a real run** (C5), with the rescale path in play.
6. **Switch the read**, re-bless the baselines, and confirm the forward benchmark is
   within the accepted band.
7. **Then** wire the slope into the crown integral's height channel, which is where
   the gradient benefit is actually realised.

Steps 1, 2 and 4 need no AD and no gradient run. Step 1 alone is worth having: an
exact `dA/dz` is a legitimate diagnostic of the light field independent of any
derivative work.

---

## 8. What would falsify this

- **The `q` identity does not hold numerically.** Compare
  `-k_I * area_leaf * q(z, H)` against a tight central difference of
  `compute_competition(z, ...)` across `eta` in {1, 2, 4, 8, 10, 12} and a general
  non-integer `eta`. The specialised multiply chains and the `std::pow` path must
  agree; if they do not, the slope inherits the discrepancy.
- **The Hermite does not converge at production density.** Section 5.3 used a
  synthetic stand. Repeat it on node sets and amplitudes taken from a real
  `Patch::compute_environment` call at `max_patch_lifetime = 105.32`. Loss of the
  O(h^3) rate means the breakpoints are not where this report says they are.
- **The node-position channel does not shrink with node density.** Then C1 is a
  floor rather than a discretisation error, and the passive-node-position treatment
  needs revisiting.
- **The build cost exceeds the forward-performance budget** once the rescale path
  (C5) and the fused reduction are both accounted for.

---

## 9. Relationship to the other reports

- **Report 1 (cohort-granular reverse sweep)** requires the locality of section 4:
  its per-step field adjoint is O(1) per light read with this interpolant and a
  transposed band solve over a run-dependent node set without it. Report 1's
  decomposition is correct either way; the cost is not comparable.
- **Report 2 (the leaf as a single differentiable node)** consumes the light value as
  its `radiation` input. The slope this report supplies is what allows the leaf's
  aggregation over a crown of trait-dependent extent to carry the height channel,
  which is the term all three shading models are currently missing.

Each report is independently landable. This one is the only one of the three that
changes forward-model numbers, and it is the only one that delivers a benefit
(an exact vertical light gradient, and the removal of three `Control` knobs from the
gradient's definition) without the other two.
