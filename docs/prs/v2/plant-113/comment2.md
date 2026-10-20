# How it works

## The divisor caps the pool's rate at 1/o

```
  dS/dt = (charge (1 - r) - drain r) / (1 + λ o),   λ = (charge + drain) / storage_max
```

The numerator is #609's flow, so the pool's equilibrium and its sign at
each bound are unchanged. Near equilibrium the pool relaxes at
λ/(1 + λo): λ where λ is small, never more than 1/o, which is 52 /yr at
7 d. In the synthetic record's stand, seedlings under 1 m reach λ of
811 /yr, while the run's longer steps (90th percentile 4.5 d) are
stable only below 304 /yr.

![The rate the pool relaxes at against its own rate, for offsets 0 to 28 days, against Cash-Karp's stability limit at the run's step sizes](FIG:plant-113/relax.png)

## A stage below empty needs no check

At r < 0 the numerator is charge − (charge + drain) r, at least the
charge, so a stage that overshoots has finite rates pointing back up.
The error estimate rejects that attempt like any inaccurate one, and
`Patch::ode_state_valid()` still refuses a step that ends below empty.
Only a recorded step cannot shrink, which is what stopped every
invasion on the base; with the offset, ends below empty are rare enough
that the invader at x2 runs.

## What a week costs

Each line is one stand at offsets from 0 to 28 days on this branch,
relative to offset 0: the synthetic record's stand, and plant's five
reference regimes (`ladder_reference_regimes()`) as 10-year stands at
`ode_tol` 1e-4.

![Accepted steps, rejected steps, CPU and the change in ln J against the offset](FIG:plant-113/offset.png)

{{OFFSETPROSE}}
