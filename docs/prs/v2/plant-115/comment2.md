## What a long step misses

The figure shows one real step from the run without stops, 13.5 days
long, with six days of rain inside it. A Cash-Karp step evaluates the
model at six fixed fractions of its length, and on the base the soil
took its rain only at those six times. Weighted as the step's solution
weights them, they see 3.8% of the rain that falls during this step.

![One 13.5-day step: the rain over it, the plants' six evaluation times, and the soil's 60 substep ends, one on each day boundary](FIG:plant-115/step.png)

With this change the soil is integrated through the step in 60 short
substeps, and a substep ends on every day boundary, so the soil takes
each day's rain as the cubic gives it. The plants are still evaluated
at the six points, and at each one they read the soil's water from
the substeps. The soil reads the plants only through each layer's
water uptake, which odelia assumes changes linearly across the step
(aornugent/odelia#57 explains how the two are integrated together and
how the error is estimated).

## Substepping where the soil limits the step: an option

Steps that cross no day boundary are taken as before, unless
`Control$ode_soil_substep` is TRUE. With it on, odelia also substeps
the soil where the soil is what keeps the step short: where the step
is longer than plain Cash-Karp can take stably on the soil, or where
the soil's own error limited the previous step. On the stand above it
takes 4039 steps against 4793 and records 13% fewer node-steps, and ln J and
every census elasticity stay within a third of ε (0.025 in ln J) of a
run stopped at every knot at `ode_tol` 1e-5. On the seasonal regime
it changes nothing.

It is off by default because two existing checks assume the soil
moves with the step. The water-balance sums above are accumulated at
the step's evaluations, so with the option on the budget closes to
about 1e-5 relative instead of 1e-12. And the gradient references for
the drought, shaded and clamped regimes, whose rain is constant, would
move. Making it the default would mean accumulating those sums inside
the soil's substeps, about 20 lines, and re-capturing those
references.

Should it stay opt-in, or become the default, in this PR or in a
follow-up?
