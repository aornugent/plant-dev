## How the offset limits the pool's rate

The pool's flow is

    dS/dt = (charge (1 − r) − drain r) / (1 + λ o)

where r is storage over capacity, λ = (charge + drain) / capacity is
the rate at which the pool relaxes on its own, and o is the offset.
The numerator is unchanged, so the equilibrium and the direction of
the flow at an empty or full pool are as before. The divisor changes
how fast the pool approaches equilibrium: λ / (1 + λ o) is close to λ
when λ is small, and never more than 1/o, 52 per year at 7 days.

![The rate the pool relaxes at against its own rate λ, for offsets from 0 to 28 days, with the stable limit of an explicit step at the run's median and 90th-percentile step lengths](FIG:plant-113/relax.png)

An explicit Cash-Karp step is stable when the step length times the
relaxation rate is below 3.73. On the stand above, seedlings under 1 m
tall reach λ of up to 811 per year, while the run's longer steps
(90th percentile 4.5 days) are stable only below 304 per year. With
the offset, no seedling's pool relaxes faster than 52 per year, so
those steps are stable.

## Why the stage check can go

When a stage's reserve is below empty, r is negative and the
numerator is at least the charge, so the flow is finite and points
back into the pool. The error estimate sees a large error and rejects
the step, as it rejects any inaccurate step, so the check is not
needed for an adaptive run. The end of each accepted step is still
checked by `Patch::ode_state_valid()`, which refuses a step that ends
below empty. Only a replay cannot shorten a step, and with the offset
the resident's steps are short enough for the invaders to take.

## What a week costs and buys

![Accepted steps, rejected steps, CPU and the change in ln J against the offset, on the synthetic record and plant's five reference regimes](FIG:plant-113/offset.png)

Each line is one stand at offsets from 0 to 28 days, relative to no
offset: the synthetic record's stand above, and plant's five reference
regimes as 10-year stands at `ode_tol` 1e-4. At 7 days every stand but
the wet one takes 5 to 25% fewer accepted steps, and CPU falls by 2 to
27% (7.6% on the synthetic record; the median of three runs). Longer
offsets save few further steps while J keeps moving, by up to 0.14 in
ln J at 28 days. On the synthetic record, the invader at twice the
resident's leaf mass per area fails at offsets of 0, 1 and 3 days and
runs from 7 days on.

Is 7 days acceptable as the default? It is a declared parameter, and
an offset of zero recovers v11's rates.
