# How it works

## The divisor caps the pool's rate at 1/o

The pool's rate is the #609 flow, divided:

```
  dS/dt = (charge (1 - r) - drain r) / (1 + λ o),   λ = (charge + drain) / storage_max
```

with r = S / storage_max. The numerator is unchanged, so the pool's
equilibrium (where it is zero) and its sign at each bound (charge ≥ 0
at r = 0, −drain ≤ 0 at r = 1) are the v11 pool's. Near equilibrium the
pool relaxes at λ/(1 + λo), which is λ where λo is small and at most
1/o however large λ grows: 52 /yr at the default 7 d.

λ is set by the plant. In the synthetic record's stand (B97, offset
7 d), across every cohort under 1 m at each stop of its first 12 years,
λ has median 9 /yr, 99th percentile 476 /yr and maximum 811 /yr. An
explicit Cash-Karp step of size h is stable on a decaying mode while
h × rate ≤ 3.73, and its stages stay non-negative while h × rate ≤ 2.16
(both from the 5th-order tableau odelia steps with). That run's accepted
steps have median 0.45 d and 90th percentile 4.5 d, so its long steps
tolerate a rate of 304 /yr: above every λ at offset 7 d, below the
fastest seedlings' at offset 0. At o = 7 d any step up to 26 d is
stable on the pool, and any up to 15 d keeps its stages non-negative.

![The rate the pool relaxes at against its own rate, for offsets 0 to 28 d, with Cash-Karp's stability limit at the run's median and 90th-percentile step](FIG:plant-113/relax.png)

## What a week does to one seedling

The figure follows one real cohort, born at t = 2.96 yr, through the
dry spell in which its net production turns negative (t = 3.557). The
dots are the run's own storage state at offset 7 d, with a stop every
6 hours. The lines integrate the pool's rate above from the cohort's
recorded production and height, from the run's state, at 5-minute
steps; at 7 d the line reproduces the run to 1.5e-5 in r.

![One seedling's relative reserve after its production turns negative, at offsets 0 and 7 d](FIG:plant-113/cohort.png)

Production falls through zero gradually, over weeks, so at first the
drain and λ are small at either offset. At offset 0 the reserve falls
to 1/a_dG2 = 0.05, where low-reserve mortality reaches 1/e of its
maximum, 8.6 days after production turns negative; at 7 d it takes 21.4
days. The fastest the pool relaxes in those 40 days is 345 /yr (25
hours) at offset 0 and 45 /yr at 7 d. So for this cohort the offset
does not turn hours into weeks: it holds the reserve about two weeks
longer, and caps the stiffness the solver meets. The 19.4 d in this
branch's NEWS entry, o ln(a_st3 a_dG2), is the run-down when production
drops at once from r = a_st3; where it drifts down, as here, the time at
offset 0 is set by the drift.

## A stage below empty, without the check

A Cash-Karp stage is not a state the run commits to. At r < 0 the
numerator is charge − (charge + drain) r, at least charge and so
positive: the rates are finite and push the pool back up. The step's
error estimate then rejects an attempt whose stages wandered, as it
rejects any inaccurate attempt, and `Patch::ode_state_valid()` rejects
a step whose end leaves a pool below zero (`non_negative_states()` names
storage). Only a recorded step cannot be shrunk: an invasion that meets
a refused end stops there by name.

On the synthetic record's stand the base rejects 2635 attempts against
10 516 accepted steps; this branch rejects 2033 against 9266. With the
offset at 0 on this branch, 2572 against 10 261, and J = 12.494, 0.6%
above the base's 12.417: the same rates, stepped without the throw.

## What a week costs, and what it buys

Measured on B97 across offsets 0, 1, 3, 7, 14 and 28 d, on plant's
reference regimes (`ladder_reference_regimes()`: wet, rain 2.0 m/yr;
drought, 0.1; seasonal, 1 + sin 2πt; shaded and clamped, rain 2.0 at
k_I = 20 and 40) as 10-year one-species stands at the fixture's traits,
93 introductions and the default `ode_tol` 1e-4, and on the synthetic
record's stand above.

![Accepted steps, rejected steps, CPU and the change in ln J against the offset, on five regimes and the synthetic record](FIG:plant-113/offset.png)

{{OFFSETPROSE}}

| synthetic record, 108 introductions | base (#94) | offset 0 | 1 d | 3 d | 7 d | 14 d | 28 d |
|---|---|---|---|---|---|---|---|
| J | 12.417 | 12.494 | 12.547 | 12.658 | 12.662 | 12.355 | 13.126 |
| accepted steps | 10 516 | 10 261 | 9665 | 9425 | 9266 | 9119 | 8963 |
| rejected attempts | 2635 | 2572 | 2270 | 2118 | 2033 | 1983 | 1985 |
| invader lma x2 | refused (stage) | density overflows | overflows | overflows | runs | runs | runs |

J on the synthetic record is not monotone in the offset (14 d reads
2.4% below 7 d, 28 d 3.7% above): at `ode_tol` 1e-3 the run's own error
is of that order, so these differences mix the offset's effect with the
step sequence's. The regimes at `ode_tol` 1e-4 move monotonically.

Counts are deterministic. Rejected attempts were read from the solver's
own counter (`get_n_rejections()`) by a probe compiled against each
build's headers, which is not part of this branch. CPU is user + system
time of one process, one run at a time, {{CPUREPS}}.

7 days is the smallest offset in this sweep at which the x2 invader
runs on the synthetic record. At 7 and 14 d no stand but the seasonal
one moves ln J by more than 0.025; at 28 d three do. The seasonal
regime's J rises by 7.2% at 7 d, which is a change to the model's
answer and not to its accuracy; the version moves to 12 for it, and an
offset of 0 restores v11's rates.
