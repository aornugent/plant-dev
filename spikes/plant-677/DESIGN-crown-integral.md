# A crown integral of the light field, recorded once

Covers traitecoevo/plant#677 (FF16) and traitecoevo/plant#692 (TF24).

## Triage: 3

It changes odelia's public surface (`hermite_spline`, `tangent.hpp`), plant's
`ResourceSpline`, and the forward arithmetic of four crown integrals.

## Requirements ledger

- R1. A crown integral records about one statement per cohort, from 42 (FF16
  deep crown in #679 with the fold) or about 26 per point (TF24 mean light, by
  #692's count).
- R2. Forward values unchanged to rounding. *Challenged upward from
  "bit-identical"*: the folded form below moves FF16's
  `net_reproduction_ratio` by 7.7e-15 relative at lifetime 60. Every test that
  passed before still passes, including the 1e-12 default baselines, and the
  run takes the same 147 steps.
- R3. Gradients equal to the current ones to rounding.
- R4. No hand-written partials in model code. The integrand is written once.
- R5. Knot bookkeeping lives in odelia.
- R6. Every light-only crown integral uses it: FF16 deep crown, FF16 average
  light and TF24 mean light (#692). TF24's `assimilation`,
  `assimilation_leaf` and `compute_average_light_environment` had no callers
  and are deleted instead.
- R7. Cost per active crown no worse than the hand-written rows: about 7.0k
  instructions.

**Scarce resource:** places that must agree. Today a crown integral exists as
a forward `QK::integrate`, an active-only folded loop, and hand-derived
partials, and the three must agree by convention.

## The floor

Keep `assimilation_deep_crown_rows` and copy it to the three other sites. This
fails R4 (four sets of hand partials) and R5 (knot bookkeeping in plant four
times).

## Candidates

- **A** [first thought] **Teach `QK::integrate` to record**, given an
  integrand that returns `value_with_slope` in the field.
  - Commitment: the quadrature owns recording.
  - Pays for R1 and R6.
  - Costs: QK learns about splines and tapes. The `q(z/h, z)` per point stays,
    so the forward run is unchanged but rows still need the shape's partials
    in `height_inverse`.
  - Wins when the integration domain or rule is not fixed per strategy.
- **B** **The field integrates itself over a fixed unit crown.**
  `ResourceSpline::crown_integral(height, crown, phi, p...)` computes
  Σ_j w_j φ(E(h s_j), p...), with the rule from `QK::unit_rule` and the shape
  folded into `w_j`.
  - Commitment: a crown integral is a fixed-weight sum of a function of the
    light at fixed fractions of the height.
  - Pays for R1, R4, R5 and R6.
  - Costs: forward values move at rounding (R2, challenged); two new names in
    odelia and two in plant.
  - Wins when every crown integral is a function of light alone over the
    canopy shape. That holds at all three sites.
- **C** **A sparse-tangent scalar** carrying a gradient over tape slots,
  evaluated through the existing `QK::integrate`.
  - Commitment: local forward-mode over any inputs.
  - Pays for R1, R4 and R6 without changing forward arithmetic.
  - Costs: a new scalar type with sparse vector arithmetic, which
    re-implements AD; not R5's shape.
  - Wins when integrands read many fields or many inputs.

**Winner: B.**

- A keeps `q` per point, so its rows need `q`'s partials in `height_inverse`
  and `z` through a generic `CanopyShape`, which is more code. It also leaves
  the forward run doing 21 extra `q` evaluations per crown.
- C costs a new AD scalar, against AGENTS' rule against re-implementing XAD.

## The commitment

A crown integral is Σ_j w_j φ(E(h s_j), p...) on a fixed unit-crown rule. One
function evaluates it at every scalar. At an active scalar it records one
statement, whose knot rows come from each read's linear form and whose other
rows come from one forward tangent of φ per read.

Kept true by structure: the double path and the active path are the same loop
in `ResourceSpline::crown_integral`, reading through the same
`hermite_spline::read_linear`. The value cannot diverge, and φ is the only
model code.

## Kill question

Assumption whose falsity makes this unnecessary: that crown integrals are a
large share of the tape.

They are. Switching the crown rows off costs 19% at one metric and 31% at
five on FF16, and #692 measured the crown light quadrature at 60% of each TF24
member's tape before odelia#78. The design survives.

## What survives deletion

- `hermite_spline::linear_read` (exists), made total: end extension included,
  inputs named. R5: the read knows which knot data it is linear in.
- `odelia::value_and_partials(f, x...)` in `tangent.hpp`. R4: φ's partials
  without hand derivation.
- `crown_rule` (fractions and weights) with `CanopyShape::unit_crown(QK)`. R6:
  FF16 and TF24 build the same rule.
- `ResourceSpline::crown_integral`. R1 and R6: the one function.

## What this settles

- `FF16_Strategy::assimilation_deep_crown_rows` and its static scratch are
  deleted.
- The four crown integrals stop calling `QK::integrate`, and the forward run
  does 21 fewer `q` evaluations per crown.
- The fallback path for reads at the spline's end goes away, since the read is
  total.
- Value identity between the scalars becomes a property of one loop, not a
  convention.
- `FF16_Environment::get_environment_at_fraction` and TF24's three dead crown
  functions are deleted.
- Under mean light, TF24's radiation-site light floor no longer fires. The
  folded weights sum to exactly 1, so a mean of floored points cannot fall
  below the floor. Before, the unfolded sum of q came out one ulp below 1 at
  some heights (h = 1.7, 5, 13.37) and one ulp above at others (0.3, 22.1),
  and the count recorded that rounding. Two tests asserted it fired and now
  assert it does not; the crown-site count is unchanged.

## What this makes hard

An integrand that reads something besides the light, such as TF24's deep
crown with a leaf solve per point, does not fit. That site stays on
`QK::integrate` at double, as it is today.

Knot rows are not merged across reads in the same span. That is 4 rows per
read, against about 3.6 merged, so roughly 10% more operations on that one
statement. Merging belongs inside `linear_read` if it is ever worth it.

## Kill condition

A crown integral whose integrand depends on z directly, not only through the
light: for example a depth-dependent leaf trait. That hands off to candidate
A: integrate in z with the shape per point.

## The design

```
odelia  hermite_spline<S>::read_linear(u) -> linear_read
          { value, slope, inputs[4] (const S*), weight[4] }   any u; ends extend
        value_and_partials(f, x0, ..., xn) -> { value, partial[n+1] }
          f evaluated once at FReal<double, n+1>, lane i seeded on x_i

plant   struct crown_rule { std::vector<double> fraction, weight; };
        CanopyShape::unit_crown(const QK&) -> crown_rule
          w_j = QK unit weight_j * q(s_j, s_j)
        ResourceSpline<S>::crown_integral(height, crown, phi, p...) -> S
          for each j:  E = read at h * s_j  (1 above the top, 0 at the floor)
                       sum += w_j * phi(E, p...)
          active:      tangent of phi at (E, p...) gives dphi/dE and dphi/dp
                       rows: knots      w_j dphi/dE * read.weight
                             height     w_j dphi/dE * slope * s_j / top
                             top        -w_j dphi/dE * slope * u_j / top
                             p          w_j dphi/dp
                       one record_with_derivatives
```

Call sites:

```cpp
// FF16 deep crown
area_leaf * light.crown_integral(height, crown,
    [](const auto& E, const auto& p1, const auto& p2) {
      return ff16_assimilation_leaf(p1, p2, E); },
    pars.a_p1, pars.a_p2)
// FF16 average light
area_leaf * assimilation_leaf(light.crown_integral(height, crown, identity))
// TF24 mean light
radiation_at(light.crown_integral(height, crown, floored_light))
```

## Results

Built as plant 0016 on odelia 0013, measured against F2 (everything before).
Callgrind instructions, lifetime 60 FF16 unless stated:

| | F2 | crown_integral |
| --- | --- | --- |
| one active crown integral | 6,967 | 6,795 |
| FF16 gradient, one metric | 1,803.2M | 1,792.7M |
| FF16 gradient, five metrics | 2,694M | 2,709M |
| FF16 forward run | 369.7M | 229.9M |
| TF24 gradient, lifetime 2 | 18.90G | 15.41G |

Wall clock, medians of three interleaved rounds:

| | F2 | crown_integral |
| --- | --- | --- |
| FF16 forward run | 0.037 s | 0.024 s |
| FF16 gradient, one metric | 0.181 s | 0.197 s |
| FF16 gradient, five metrics | 0.252 s | 0.254 s |
| TF24 forward run, lifetime 2 | 0.90 s | 0.92 s |
| TF24 gradient, lifetime 2 | 2.29 s | 1.85 s |

The FF16 one-metric gradient is 5–9% slower on the wall in each round at
equal instruction counts. Not explained.

Agreement:

- FF16 gradients agree with B to 3.2e-13 relative.
- TF24 values move 1.2e-9 relative and gradients up to 8.2e-6 (median 4e-8)
  against F2. The forward run carries no rows, so this is the forward
  arithmetic, amplified by the tolerance-terminated leaf solve
  (`GSS_tol_abs` 0.1). A one-ulp change in lma on F2 alone moves values 4e-11
  and gradients up to 4.8e-7 (median 1.4e-9): the same ratio of gradient to
  value shift. The fold moves every mean light by about an ulp at every cohort
  and step.
- Suites: plant fails the same four tests as B; odelia has the same 12 errors
  as before, and its two new tests pass. `read_linear` returns the same value
  and slope as `eval` bit for bit, and its weights equal the tape's gradient
  to 1e-12.
