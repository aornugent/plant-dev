# How it works

## Why a crown below a knot adds an exact zero

On the birth-date coordinate the light at height z is Beer's law on the
leaf area above z, summed over cohorts:

```
  A(z) = Σ_i  w_i · n_i · a_i(z),     a_i(z) = 0 for z ≥ h_i
```

with w_i the node's establishment weight, n_i its density and a_i the
leaf area of its crown above z, a polynomial in z/h_i for TF24's crown
shape. Because a_i is exactly zero above a crown's top, the sum at z is
the sum over the nodes taller than z. Sorted tallest first, those are a
prefix of the list, and a polynomial crown lets each term split into
moments that a running total accumulates once. The 65 knots of the
light spline ascend, so one pass over the nodes and one over the knots
serve the whole build. Before #94 a birth-date build summed a trapezium
over neighbouring nodes and could not be reordered; #94's per-node
weights are what make each term independent of its neighbours.

## When the list stops being tallest first

The node list is ordered by birth date, oldest first, and on most stands
that is tallest first. TF24's growth is gated by its reserves (#517): a
cohort with an empty pool stops growing while a younger cohort born into
better water keeps going, and with introductions days apart the younger
one passes it. On the synthetic record's stand with 429 introductions
(cohorts 34 days apart, `ode_tol` 1e-4), sampled at each of its 3358
stops (introductions and rain knots, where the run stops anyway, so the
steps are the run's own), the widest pair sits 1.17 mm out of order at
t = 35.46 yr: a cohort born at 29.72 yr standing above the one born 34
days before it, both near 5.47 m.

![Heights against birth date at the stop with the widest crossing, the out-of-order pair marked](FIG:plant-114/crossing.png)

The first pair crosses at t = 6.92 yr. From then on every stop has at
least one pair out of order, and pairs accumulate: 1 at t = 6.9, 2 at
10.0, 3 at 20.9, 4 at 29.8 and 5 at 39.6; the count never falls. That is
2747 of 3358 stops, 81.8%. On the base each of those builds took the
fallback: 65 knots times every crown, at all six stages of every step,
for the last 33 years of the run.

The same stand with 108 introductions (cohorts 135 days apart, `ode_tol`
1e-3) has no pair out of order at any of its 3039 stops: there, on this
record, the sort is never taken.

![The share of stops at which the heights are out of order, by year of the run](FIG:plant-114/share.png)

## What the sort costs and what it saves

{{PERFPROSE}}

![Forward CPU with and without the sort, five interleaved pairs, every run shown](FIG:plant-114/forward.png)

{{PERFTABLE}}
