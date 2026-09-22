# Higher-order quadrature for the fitness integral over cohorts

**Verdict.** The quadrature half of the claim is right and then some: on the
default 88 cohorts the trapezium carries **+0.359%** and a cubic spline on the
same samples leaves **-0.0014% to -0.0024%** — a **148-258x** cut, order 2 -> 4,
for no extra cohorts and no extra runs. The claim's conclusion does not follow.
That +0.359% is **not** the 0.24% the model is off by. It is one of two errors of
the same order: the cohort-count error in the forward solve is **-0.617%** under
benign forcing, and the trapezium's **+0.359%** cancels 58% of it. Remove the
trapezium and the reported fitness goes from **-0.249%** to **-0.617%** wrong —
**2.4x worse** — and stays 2.4x worse at every refinement level, because both
errors are second order in cohort spacing with a stable ratio. Under every mixed
rainfall record the cohort-count error is **-16% to -31%** and does not converge
at all, so the 0.359% is 1-2% of the error and irrelevant. The one change here
that does pay is not a rule at all: a cohort ladder with a fixed step ratio
instead of the dyadic doublings improves **everything** at once — the trapezium
by 12%, the spline by 35%, the cohort-count error by 14%, the reported fitness
from -0.259% to -0.219% — for one extra node and no formula change.

The kink hypothesis half-survives. Kinks are real and they are exactly as
localised in birth date as predicted — a handful of adjacent nodes, in the two
records with the most branch pressure (`t = 0.0200-0.0215` under sustained
aridity, `t = 0.0357-0.0376` under rapid wet-dry alternation), carrying 1.4-1.8%
of `J`. The spline does degrade there: **6x to 120x worse than the trapezium
inside the one default panel that holds the kink.** But that panel is 5.7-6.7% of
a panel-error budget already 170-190x below the trapezium's, so it never stops
helping. And **a piecewise rule does not recover it** — restarting the spline at
the kink is 0.5-2.2% *worse* than ignoring it, because short segments on a
five-nodes-per-rung ladder cost more than the kink does. Only a local fallback
(global spline, trapezium on the two panels touching the kink) wins, by 11-35%.
What actually limits the spline is not kinks but the **dyadic schedule's spacing
doublings**: 16 of 87 default panels begin at one, and they carry 54-71% of the
spline's residual error. Branch co-occurrence itself turns out to be across
**time**, not across **birth date** — every one of the 88 cohorts is on the same
branch at any instant, in every record, aridity included.

## What this measures, and what it does not

Everything below is post-processing. A run is taken to completion, the samples
the fitness integral is built from are read out of it, and the rules are applied
to **exactly those numbers**. Two consequences, one in each direction:

- For the **quadrature** term this is not an approximation of the model change,
  it is the model change. `Patch::net_reproduction_ratio_for_species`
  (`plant/inst/include/plant/patch.h:904`) forms
  `util::trapezium(times, net_prod_scaled)` from `node_times()` and
  `net_reproduction_ratio_by_node_weighted()`, both `std::vector<double>`; the
  integral is a pure output and feeds nothing in the forward solve (its only
  consumer beyond the R accessors is the normalising scale in
  `net_reproduction_ratio_errors`, `patch.h:955`). Applying a different rule to
  the same samples is what swapping the rule in that function would do.
- For the **cohort-count** term it establishes nothing new. That error lives in
  the forward solve and no output rule can touch it. It is measured here only to
  put the quadrature term in proportion — and that proportion is the finding.

The samples were reconstructed in R and checked against C++ to
2.2e-16 relative (`quad_verify.R`):
`net_reproduction_ratio_by_node * patch_densities * S_D * birth_rate(t)`,
integrated with the trapezium, reproduces `scm$offspring_production` exactly.

**On tiny objectives.** Four of the six records give `J` between 4.3e-11 and
7.5e-10 — a strategy ten orders below replacement. Relative error is still the
right measure there (an optimiser on `log J` sees nothing else) and it is
numerically sound: the samples carry full double precision and the three
reference rules agree to 2e-8 - 2e-7 relative on the dense grid. What is not
sound is treating any of these numbers as converged: the cohort count moves them
by tens of percent. So a 0.36% quadrature fix is meaningful only where the
solution is converged, which among these records is the two constant ones
alone.

## Method

TF24, one strategy at `lma = 0.0825`, `max_patch_lifetime = 5`,
`node_density_in_birth_date = TRUE` (height as a contrast), `ode_tol = 1e-6`,
`-O2` build, serial, `TESTTHAT_PARALLEL = false`. The functional is
`sum(scm$offspring_production)`. No code was changed.

**Schedules.** The default is `node_schedule_times_default(5)`: 88 nodes with
`dt = 2^floor(log2(0.2 t))` clamped to `[1e-5, 2]`, a dyadic ladder whose spacing
doubles every fifth node, from 1e-5 to 0.5. Level `k` bisects every interval `k`
times (175, 349, 697 nodes); level `-k` takes every `2^k`-th default node (44,
22). Every level is a subset of level 3, so one dense run can be subsampled onto
all of them **exactly**, which is what holds the integrand fixed while the rule
and the spacing vary. One further schedule, built the same way but with
`dt = max(1e-5, 0.1474 t)` — the same clamps and span, a fixed step ratio instead
of doublings, 89 nodes — is run as a control on the constant record.

**Cells.** Six records x four schedule levels in the birth-date coordinate, plus
`constant` and `wet-dry swing` in the height coordinate, plus the smooth-ladder
control, plus `constant` at `ode_tol = 1e-8`. Forty-three runs in all, from 4 s
(constant, 88 nodes) to 615 s (constant, height, 697 nodes).

**Forcing.** `probe7_rain.R`'s seasonal Markov chain with gamma amounts, extended
with a per-year multiplier (drought and wet years inside one record) and with
event structures that separate storms from drizzle at a comparable annual total
(`quad_forcing.R`). Six-year records:

| record | annual mm | wet days | event mean / p90 / max (mm) | top 10% of events carry | per-year totals |
|---|---|---|---|---|---|
| constant | 1095 | 100% | 3.0 flat | — | flat |
| constant dry | 584 | 100% | 1.6 flat | — | flat |
| mixed storm | 376 (65-811) | 5% | 20.0 / 47.2 / 302.9 | 51% | 303 65 811 85 728 264 |
| mixed drizzle | 389 (32-1098) | 16% | 6.9 / 13.2 / 28.4 | 25% | 294 32 1098 51 734 122 |
| wet-dry swing | 482 (6-1170) | 10% | 13.2 / 33.2 / 78.9 | 36% | 1170 14 935 6 763 6 |
| arid with storms | 73 (40-138) | 1% | 15.0 / 41.7 / 65.5 | 36% | 40 84 138 62 41 71 |

`mixed storm` and `mixed drizzle` are the matched pair: within 3% on annual
total, 3x apart on wet-day frequency and event size.

**Rules** (`quad_rules.R`), all on non-uniform abscissae. Any rule that builds a
local interpolant has that interpolant integrated with 5-point Gauss-Legendre,
exact through degree 9, so the number reported is the interpolant's own integral.

| rule | what |
|---|---|
| trapezium | the reference implementation |
| spline fmm / natural | `stats::splinefun`, cubic, global |
| spline monotone | `monoH.FC`, shape-preserving Hermite |
| local cubic / quintic | per panel, the polynomial through the `deg+1` nearest samples, integrated over that panel alone |
| NC quadratic / cubic | composite non-uniform Newton-Cotes: one polynomial per block of 2 or 3 panels |
| exponential | per panel, exact for an exponential: `h (y1-y0) / log(y1/y0)` |

Verified on a random non-uniform grid: every rule integrates its own degree
exactly, and the exponential rule is exact for `exp(-8x)`.

**Cross-check against the earlier schedule measurements.** The uniform-bisection
sequence reproduces: constant / birth-date 7.05485e-05, 7.06855e-05, 7.07198e-05
at 88 / 175 / 349 nodes against the recorded 7.05485e-05, 7.06855e-05,
7.07198e-05; constant / height 9.46769e-07, 9.54397e-07, 9.56361e-07 against
9.46765e-07, 9.54368e-07, 9.56346e-07 (the small height differences are
`ode_tol` 1e-6 here against 1e-4 there). The harness is measuring the same thing.

## The integrand

Read off a completed run, the fitness integrand is not a broad smooth hump. It is
a steep decay concentrated in the first 4% of the patch lifetime:

| | |
|---|---|
| `g(0)` | 2.06e-3 (the maximum) |
| 50% of `J` by | `t = 0.0234` (node 50 of 88) |
| 99.98% of `J` by | `t = 0.1875` (node 65) |
| last non-zero sample | `t = 3.0`, at 4.4e-25 |
| nodes 86-88 | exactly 0 |

The grid carries ~20 useful nodes across the decay, in rungs of five with the
spacing doubling between rungs. That is what sets the trapezium's error, and it
is also why the answer barely depends on the weather: the ladder is self-similar
(`h ~ 0.1-0.2 t`) and the integrand is scale-free over its support, so the
trapezium's **relative** error is a property of the schedule. Measured across
six records it varies by 0.3%: 0.3587%, 0.3590%, 0.3591%, 0.3592%, 0.3593%,
0.3596%.

## Q1 — how much error does the higher-order rule remove?

The integrand is held fixed: samples from the 697-node run, subsampled onto the
default 88 abscissae, integrated by each rule, against the reference formed on
all 697 (the three reference rules — `spline fmm`, `local quintic`, `NC cubic` —
agree there to 2e-8 - 2e-7 relative).

Relative error at the default 88 cohorts, birth-date coordinate:

| rule | constant | constant dry | mixed storm | mixed drizzle | wet-dry swing | arid with storms | reduction |
|---|---|---|---|---|---|---|---|
| **trapezium** | **+3.592e-3** | **+3.590e-3** | **+3.596e-3** | **+3.591e-3** | **+3.593e-3** | **+3.587e-3** | **1x** |
| spline fmm | -1.790e-5 | -1.806e-5 | -1.395e-5 | -2.426e-5 | -1.951e-5 | -2.112e-5 | **148-258x** |
| spline natural | -1.790e-5 | -1.806e-5 | -1.395e-5 | -2.426e-5 | -1.951e-5 | -2.112e-5 | 148-258x |
| local quintic | +2.767e-5 | +2.786e-5 | +2.614e-5 | +1.369e-5 | +1.855e-5 | +1.879e-5 | 129-262x |
| NC quadratic | -8.686e-5 | -9.073e-5 | -6.561e-5 | -5.372e-5 | -7.215e-5 | -6.460e-5 | 40-67x |
| spline monotone | +8.436e-5 | +8.374e-5 | +8.961e-5 | +8.113e-5 | +8.445e-5 | +8.157e-5 | 40-44x |
| NC cubic | +9.931e-5 | +1.003e-4 | +1.334e-4 | +1.336e-4 | +1.324e-4 | +1.364e-4 | 26-36x |
| local cubic | -1.465e-4 | -1.471e-4 | -1.536e-4 | -1.638e-4 | -1.608e-4 | -1.629e-4 | 22-25x |
| exponential | -7.105e-4 | -7.105e-4 | -5.847e-5 | -8.335e-5 | -3.903e-5 | -3.808e-5 | 5-94x |

So the claim's "roughly an order of magnitude" understates the quadrature result
by another order: a plain cubic spline is **148-258x** better, everywhere, and
the answer barely depends on the forcing. Order is not the whole story: the
local cubic runs at the same order 4 and reaches only 22-25x, so the **global**
interpolant is worth another factor of ~8 in the constant, not in the exponent.

The exponential panel rule is the interesting near-miss: second order like the
trapezium, but with a constant 5-94x smaller because the integrand really is
near-exponential over most of its support. It and `monoH.FC` are the two rules
here that cannot produce a negative panel — the exponential because it is a
positive multiple of the panel width, `monoH.FC` because it stays inside the data
range. Neither is competitive with the spline.

### Convergence order

log2 of successive `|error|` ratios down the nested family (22, 44, 88, 175,
349 nodes), constant forcing; the other records agree to within the same spread:

| rule | 22->44 | 44->88 | 88->175 | 175->349 | design order |
|---|---|---|---|---|---|
| trapezium | 1.91 | 1.96 | 2.00 | 2.00 | 2 |
| exponential | 1.91 | 1.91 | 1.99 | 2.00 | 2 |
| spline monotone | 2.02 | 1.58 | 2.43 | 2.75 | 3 |
| local cubic | 3.88 | 3.95 | 3.88 | 3.94 | 4 |
| spline fmm / natural | 5.38 | 3.18 | 3.92 | 4.30 | 4 |
| NC cubic | 4.21 | 4.75 | 3.58 | 3.89 | 4 |
| NC quadratic | 3.21 | 4.97 | 4.51 | 3.76 | 3-4 |
| local quintic | 7.08 | 5.31 | 5.63 | 4.74 | 6 |

The trapezium is at its design order to two decimals, so nothing in the
integrand is spoiling it. The spline and the local cubic run at 4; the local
quintic at 5-5.6 rather than 6, which is where the spacing doublings start to
cost. `spline monotone` runs at 1.6-2.8: shape preservation costs two orders,
which is the price of a rule that cannot overshoot.

## Q2 — but the model is not 0.36% wrong, and the trapezium is why

Establishing a reference the honest way needs the cohort schedule refined in the
**model**, not just in the rule. Running the nested schedules and reading each
level's own samples separates the two errors cleanly, because a rule with no
quadrature error left reports the solution alone:

- **cohort-count error** at level `k` = (spline on the level-`k` run) - reference
- **quadrature error** at level `k` = (trapezium on the dense run's integrand,
  subsampled to level `k`) - reference
- their sum is the trapezium on the level-`k` run, and it reproduces it to four
  digits at 175 and 349 cohorts and to 0.15% of the total at 88. The decomposition
  is measured, not fitted; the residual is the only approximation in it, and it is
  the one place post-processing shows: the quadrature term is measured on the
  dense run's integrand, and the coarse run's integrand is not quite the same
  function.

Constant rainfall, birth-date coordinate. The reference is the 697-node run
extrapolated one step further by the spline sequence (the extrapolated limit sits
+1.0e-4 from the 697-node number; the ratios 4.19, 5.01 say the sequence is
converging):

| cohorts | cohort-count error | quadrature error | trapezium total | spline total | quad / count |
|---|---|---|---|---|---|
| 88 (default) | **-0.6174%** | **+0.3592%** | **-0.2586%** | **-0.6174%** | **-0.582** |
| 175 | -0.1550% | +0.0901% | -0.0649% | -0.1550% | -0.581 |
| 349 | -0.0389% | +0.0225% | -0.0164% | -0.0389% | -0.580 |

Three things fall out.

1. **The measured 0.24% is a difference of two larger numbers.** The prior
   0.242% (birth-date, 88 nodes) reproduces here as -0.2486% against the
   697-node run's high-order integral and -0.2586% against the extrapolated
   limit. It is not the
   trapezium's error. It is a -0.617% cohort-count error with 58% of it cancelled
   by the trapezium's +0.359%.
2. **The cancellation is structural, not luck.** Both terms are second order in
   cohort spacing — the trapezium at 2.00 by construction, the cohort-count error
   at ratios 3.98, 3.98 after extrapolation — and their ratio is -0.582, -0.581,
   -0.580 across a 4x range of cohort counts. It does not wash out under
   refinement. A second benign record (`constant dry`, rainfall 1.6 rather than
   3.0, `J = 6.5e-05`) gives the same picture with a different constant:
   cohort-count -0.6283%, -0.1576%, -0.0396%; quadrature +0.3590%, +0.0900%,
   +0.0225%; ratio **-0.571, -0.571, -0.570**. The fraction cancelled is a
   property of the problem, stable under refinement, and close but not identical
   between records.
3. **So the spline makes the reported fitness worse, at every cohort count.**
   -0.2586% becomes -0.6174% at 88 cohorts, -0.0649% becomes -0.1550% at 175,
   -0.0164% becomes -0.0389% at 349. A uniform factor of 2.4.

The code points at the mechanism. Cohorts reach each other only through the
environment, and the environment is built from two reductions over the cohorts —
the light field from `compute_competition` and `resource_depletion` from
`consumption_rate` (`patch.h:1107-1133`, `patch.h:1185-1193`). **Both are trapezia over the
same nodes**:
`Species::reduce_competition`
(`plant/inst/include/plant/species.h:628-641`) accumulates
`(x0 - x1) * (at_x1 + fs0)` over the abscissae, closed by
`close_competition_and_slope` (`species.h:697`); `Species::consumption_rate`
(`species.h:789-834`) integrates per-cohort uptake over the same grid, closed
with the boundary node. Those are the terms in the forward solve that are second
order in cohort spacing, and they are what the cohort-count error is. Raising the
order of the output integral while leaving the reconstructions that fed it at
order 2 removes the part of the error that was compensating and keeps the part
that was not.

### The height coordinate separates the two terms cleanly

The fitness integral is over `node_times` in **both** coordinates —
`Patch::net_reproduction_ratio_for_species` reads `species[i].node_times()`
regardless of `node_density_in_birth_date`, which only sets the abscissa the
*density* is reconstructed on. So switching coordinates should leave the
quadrature term alone and move the cohort-count term. It does, exactly:

| constant rainfall, 88 cohorts | birth-date | height |
|---|---|---|
| quadrature error | +0.3592% | **+0.3528%** |
| cohort-count error | -0.6174% | **-1.4246%** |
| trapezium total | -0.2586% | **-1.0739%** |
| spline total | -0.6174% | -1.4246% |
| quad / count | -0.582 | **-0.248** |
| the same at 175 / 349 cohorts | -0.581 / -0.580 | -0.243 / -0.237 |

The quadrature terms agree to 1.8%; the cohort-count terms differ by 2.3x. That
is the "birth-date is 4x more accurate" observation restated with the two halves
separated: the coordinate buys nothing on the quadrature and 2.3x on the
reconstruction, and what the earlier work measured as 1.00% (height) against
0.24% (birth-date) is here -1.074% against -0.259%. It is also the cleanest
evidence for the mechanism: the coordinate changes the competition and
consumption abscissa and nothing else, and only the cohort-count term moves.

The cancellation is there too, at a different fraction and equally stable:
-0.248, -0.243, -0.237 over a 4x range of cohort counts. Replacing the trapezium
in the height coordinate takes -1.074% to -1.425% — 1.33x worse rather than 2.4x,
because less of that error was being cancelled.

The mixed-forcing picture is the same in height as in birth date. `wet-dry swing`
in the height coordinate gives quadrature +0.3593%, +0.0899%, +0.0225% —
indistinguishable from every other cell — against a cohort-count error of
-12.96% at 88 cohorts whose sequence does not converge cleanly (ratios 14.65,
2.86).

### Under mixed forcing there is nothing to improve

Same decomposition at 88 cohorts, `ode_tol = 1e-6`:

| record | cohort-count error | quadrature error | quad / count | does the count sequence converge? |
|---|---|---|---|---|
| constant | -0.617% | +0.359% | -0.582 | yes, ratios 4.19 / 5.01 |
| constant dry | -0.628% | +0.359% | -0.571 | yes, ratios 4.19 / 5.01 |
| mixed storm | -24.21% | +0.360% | -0.015 | no: -24.2%, -23.9%, +1.7% |
| mixed drizzle | -23.35% | +0.359% | -0.015 | no: -23.3%, -2.4%, -12.4% |
| wet-dry swing | -30.78% | +0.359% | -0.012 | no: -30.8%, -24.3%, +0.2% |
| arid with storms | -16.15% | +0.359% | -0.022 | no: -16.2%, -41.2%, +4.6% |

Under every mixed record the quadrature term is **1.2-2.2%** of the error, and
the term that carries the other 98% is not converging in cohort count at all —
the same non-convergence the earlier schedule work found under pulsed forcing.
Replacing the trapezium there changes the answer by 0.36% and leaves 16-31%
standing.

This is not a tolerance artefact. At `ode_tol = 1e-8` against `1e-6` the constant
cell moves by **2.0e-8** relative (7.05484916e-05 vs 7.05484902e-05), and the
whole decomposition repeats to four digits: cohort-count -0.6074%, quadrature
+0.3592%, trapezium total -0.2486%, ratio -0.5914. Five orders below the
quadrature error and seven below the cohort-count error. The time integration is
not what is in the way.

## Q3 — where the higher-order rule stops helping

### The branches co-occur in time, not in birth date

`census_operating_point_counts_tf24` over the whole run, plus a per-cohort
classification taken by clearing the tally, rating one cohort in the final
environment, and reading which branch it took (`quad_census.R`):

| record | run tally | every cohort at the final state | branch changes between adjacent birth dates |
|---|---|---|---|
| constant | interior 100.0% | interior (88 of 88) | 0 |
| mixed storm | interior 87.3%, boundary-crit 12.5%, shutdown 0.2% | interior (88 of 88) | 0 |
| mixed drizzle | interior 89.1%, boundary-crit 10.8%, shutdown 0.1% | interior (88 of 88) | 0 |
| wet-dry swing | interior 88.1%, boundary-crit 11.8%, shutdown 0.1% | interior (88 of 88) | 0 |
| arid with storms | **interior 70.0%, boundary-crit 29.9%** | boundary-crit (88 of 88) | 0 |

The sustained-aridity record reproduces the 28-31% co-occurrence the earlier work
reported, and the reading of it is the one that matters here: **the whole stand
moves between branches as the weather moves**, and at any instant every cohort is
on the same one. Co-occurrence is temporal. A kink in birth date needs adjacent
cohorts to diverge, which is a much rarer event — it takes a cohort's own
development crossing a branch at a moment the next cohort's does not.

### Kinks located

Smoothness test on the 697-node integrand: at each node compare the jump in
one-sided slope measured at spacing `h` with the same jump at `2h`. A curvature
term halves (ratio 2); a kink does not (ratio 1). Restricted to nodes carrying
more than 0.01% of `J`:

| record | median ratio | lowest ratio | nodes below 1.7 | weight they carry | where |
|---|---|---|---|---|---|
| constant | 2.00 | 1.70 | 0.2% | 0.01% | — |
| constant dry | 2.00 | 1.70 | 0.2% | 0.01% | — |
| mixed storm | 2.00 | 0.19 | 0.7% | 0.05% | `t = 0.00083` |
| mixed drizzle | 2.00 | 1.02 | 1.8% | 0.34% | `t = 0.0057 - 0.0060` |
| **wet-dry swing** | 2.00 | 1.36 | 1.0% | **1.38%** | **`t = 0.0357 - 0.0376`** |
| **arid with storms** | 2.00 | 0.52 | 1.5% | **1.81%** | **`t = 0.0200 - 0.0215`** |

So kinks exist and are localised to a handful of adjacent nodes, exactly as
hypothesised. The two records that carry any weight in them are the two with the
most branch pressure — sustained aridity (30% boundary-crit) and rapid wet-dry
alternation. The two constant records have nothing: their lowest ratio anywhere
is 1.70, which is curvature on a doubling grid, not a kink.

### The spline does degrade there, and it costs almost nothing

Per-panel error attribution on the default 88 abscissae, with the truth for each
panel taken from the dense samples inside it:

| record | default panels where the spline is worse than the trapezium | weight they carry | share of the spline's total panel error |
|---|---|---|---|
| constant | 13 of 87 | 0.000% | 0.0% |
| mixed storm | 5 of 87 | 0.000% | 0.0% |
| mixed drizzle | 7 of 87 | 0.000% | 0.1% |
| **wet-dry swing** | 8 of 87 | **2.75%** | **5.7%** |
| **arid with storms** | 8 of 87 | **3.34%** | **6.7%** |

In each of the two kinked records exactly one panel matters, and it is the one
containing the kink: `t = [0.0195, 0.0234]` under aridity (3.3% of `J`, spline
1.71e-6 against the trapezium's 3.00e-7 — **5.7x worse in that panel**) and
`t = [0.0352, 0.0391]` under the wet-dry swing (2.75% of `J`, spline 1.70e-6
against 1.41e-8 — **120x worse in that panel**). The local cubic does no better
(2.07e-6, 1.97e-6), so this is the kink and not the spline's globality. Every
other entry in that column is in the far tail (`t > 1.5`) where the samples are
`1e-20` and below and the "error" is ringing on numbers that contribute nothing.

Totalled, the kinks cost the spline 5.7-6.7% of a residual already 170-190x below
the trapezium's.

### Piecewise: restarting the rule never helps, falling back to the trapezium does

Two variants on the default 88 abscissae, with breakpoints at the nodes the dense
smoothness test flags:

| | trapezium | spline, global | piecewise spline, restarted at the kink | spline everywhere, trapezium on the two panels touching the kink |
|---|---|---|---|---|
| arid with storms | +3.587e-3 | -2.112e-5 | -2.122e-5 (**0.5% worse**) | **-1.871e-5 (11% better)** |
| wet-dry swing | +3.593e-3 | -1.951e-5 | -1.993e-5 (**2.2% worse**) | **+8.098e-6 (2.4x better)** |
| constant / constant dry / mixed storm | — | — | unchanged | unchanged |

and at finer cohort counts, where the kink is resolved rather than straddled:

| | 175 cohorts: spline -> hybrid | 349 cohorts: spline -> hybrid |
|---|---|---|
| arid with storms | -1.217e-6 -> -8.774e-7 (28% better) | -8.540e-8 -> -5.801e-8 (32% better) |
| wet-dry swing | -2.734e-6 -> -2.228e-6 (19% better) | -1.088e-7 -> -7.017e-8 (35% better) |

**Restarting the spline at a kink is worse than ignoring it**, in both records and
at every cohort count. A restart forces one-sided end conditions onto both new
segments, and on a ladder with five nodes per rung the segments are short enough
that the loss exceeds what the kink costs. Only the local fallback wins — keep
the global spline, and integrate the two panels that touch the kink with the
trapezium — and it wins by 11-35% (the wet-dry `L0` entry overshoots and changes
sign, so the 2.4x there is luck, not a bound).

So the answer to the question is: **yes, kinks are localised in birth date; yes,
the spline degrades at them, by 6x to 120x within the one panel that holds them;
and no, a piecewise high-order rule does not recover anything** — because the
smooth stretches were never what was limiting the spline, and breaking the rule
costs more than the kink does. The recoverable amount is 11-35% of an error that
is already two orders of magnitude below the rule being replaced.

One more thing the test says: **a detector that sees only the default 88 samples
cannot find these kinks.** Run on the coarse samples it flags 1 to 4 nodes in
every record including the two with no kink at all, and misses the real ones,
because at the default spacing a kink sits inside a panel rather than on a node.
Locating them took the 697-node run.

### What is limiting it: the dyadic spacing doublings

The default schedule doubles its spacing every fifth node. Sixteen of the 87
panels begin at a doubling. Those 16 carry 26.3% of `J` and:

| record | share of the spline's panel error | share of the trapezium's |
|---|---|---|
| constant | 59.4% | 39.8% |
| constant dry | 60.0% | 39.7% |
| mixed storm | 54.9% | 40.7% |
| mixed drizzle | 54.1% | 40.8% |
| wet-dry swing | 59.4% | 40.9% |
| arid with storms | 71.0% | 40.6% |

The trapezium does not care where the spacing changes — its 40% tracks the 26% of
weight those panels carry, plus the steeper integrand there. The spline does: it
loses 54-71% of its residual to 18% of the panels, purely because a cubic through
samples whose spacing jumps by 2 at one end is a worse cubic. That, not the
kinks, is where a higher-order rule stops paying on this grid — and it points at
a cheaper fix than changing the rule: a ladder that grows smoothly rather than in
doublings would let the same spline reach closer to its order-4 asymptote.

### Confirmed: a ladder without doublings gets more out of the same rules

The diagnosis is testable without touching a rule. `quad_smooth.R` builds a
schedule with the same clamps and the same span but a fixed step ratio —
`dt = max(1e-5, 0.1474 t)` instead of `dt = 2^floor(log2(0.2 t))` — giving 89
nodes against the default's 88 and **zero** panels with a spacing jump. Constant
rainfall, same four levels, same measurements:

| at 88-89 cohorts | dyadic ladder | smooth ladder |
|---|---|---|
| trapezium, quadrature error | +0.3592% | **+0.3154%** |
| spline fmm, quadrature error | -1.790e-5 (201x) | **-1.156e-5 (273x)** |
| local quintic, quadrature error | +2.767e-5 | **+1.565e-5** |
| local cubic, observed order | 3.88 / 3.95 | **4.01 / 4.01** |
| spline, observed order | 5.38 / 3.18 | **3.93 / 4.19** |
| local quintic, observed order | 7.08 / 5.31 | **5.97** (its design order) |
| spline residual in spacing-jump panels | 59.4% (16 panels) | **0% (no such panels)** |
| cohort-count error | -0.6174% | **-0.5336%** |
| trapezium total | -0.2586% | **-0.2187%** |
| quad / count | -0.582 | -0.591 |

Everything improves at once, for one extra node: the trapezium's own error falls
12%, the spline's 35%, the cohort-count error 14%, and the local rules snap to
their design orders (`local quintic` reaches 5.97 where the dyadic ladder held it
to 5.31). The cancellation survives unchanged at -0.59, so the smooth ladder does
not make the spline any more attractive — it makes **every** rule better,
including the one already in place. Reported fitness at the default cohort count
goes from -0.2586% to -0.2187% with no change to any formula.

## What changing it in the model would take

The post-processing result is convincing about quadrature and not about the
model, so this section is written for the case where the competition
reconstruction is raised to match — on its own, the change below is a regression.

**One call site.** `Patch<T,E>::net_reproduction_ratio_for_species`
(`plant/inst/include/plant/patch.h:904-913`) is the only place the fitness
integral is formed. It is reached by `Patch::offspring_production` (`patch.h:917`),
`Patch::net_reproduction_ratios` (`patch.h:932`) and
`SCM::r_net_reproduction_ratio_for_species` (`plant/inst/include/plant/scm.h:867`);
`Patch::total_offspring_production` (`patch.h:944`) sums it for one consumer only,
the normaliser in `net_reproduction_ratio_errors` (`patch.h:955`). Nothing in the
forward solve reads it.

**The weights can be constants on the tape — and today they are not on it at
all.** `Species::net_reproduction_ratio_by_node_weighted` (`species.h:754`) takes
`odelia::util::to_passive` on every sample and
`net_reproduction_ratio_for_species` returns `double` from
`std::vector<double>`, so this integral never reaches the tape; the adjoint
sweep differentiates census metrics (`Species::census_integral`, `species.h:838`)
instead. If it were lifted: introduction times are schedule constants, not state,
and every interpolatory rule here — a spline included, since spline
interpolation is a linear operator for fixed knots — is `J = sum(w_i g_i)` with
`w_i` a function of the abscissae alone. Verified on the default schedule: the
weight vector recovered by feeding the rule unit basis vectors reproduces the
rule bit for bit, `sum(w) = 4.5 = b - a`, no weight is negative, and
`max|w| / min(h)` is `6.3e4` for the spline against `5.0e4` for the trapezium —
no conditioning penalty. The weights are therefore passive, precomputable once
per schedule, and cost exactly what the trapezium's `(x_{i+1} - x_{i-1})/2`
costs.

**The refinement error signal is defined by the trapezium and would have to move
with it.** `util::local_error_integration` (`plant/src/util.cpp:76-99`) forms
`|trapezium over one wide panel - trapezium over its two halves| / scale` — a
Richardson estimate of the *trapezium's* local error. It drives
`net_reproduction_ratio_errors` and thence `SCM::refine_schedule`
(`scm.h:774`). Leave it and the loop refines against an error the model no longer
makes; every per-node number it reports would be 148-258x larger than the real
one, and it would keep bisecting where a spline is already exact. This is the
coupling most likely to be missed.

**The boundary is at the right end, and it is a sign hazard rather than a
magnitude one.** Unlike the competition and census integrals, which close with
the boundary node (`close_competition_and_slope`, `species.h:697`;
`census_integral`, `species.h:838`), the fitness grid is `nodes` alone —
`node_times()` and `net_reproduction_ratio_by_node_weighted()` both skip
`new_node` (`species.h:740-770`). So:

- The **left** end `t = 0` carries the integrand's maximum and takes a one-sided
  stencil, but the first five panels are `1e-5` wide and it costs nothing
  measurable.
- The **right** end runs to `t = 4.5` against a lifetime of 5, through a decay of
  twenty decades, with the last three samples exactly zero. A global spline rings
  there: measured, every panel beyond `t = 1.5` has the spline erring 10-100x
  more than the trapezium, on values of `1e-20`. `J` itself is safe — on the
  default schedule every one of the 88 spline weights is non-negative
  (`quad_weights.R`), so a non-negative integrand cannot produce a negative
  total, and `sum(w)` is `b - a` to machine precision. What rings is the
  **per-panel** decomposition, and that is exactly what
  `util::trapezium_vector` and `local_error_integration` consume. A
  higher-order rule therefore needs its panel decomposition defined
  deliberately, not inherited: a negative panel in the tail would be read by the
  refinement loop as an error to bisect against.
- Adding the boundary node to this grid would not help: its fecundity is zero by
  construction, so it only lengthens the zero tail.

**Tests that move.** `plant/tests/testthat/test-scm.R:281-295` reimplements the
trapezium in R and asserts equality with
`scm$net_reproduction_ratio_for_species(1)` and `scm$net_reproduction_ratios`, so
it has to be rewritten against whatever rule replaces it. Ten test files pin
`offspring_production` numerically — `test-strategy-ff16.R:224` at `tolerance
1e-4` and `:231` at `1e-5` are the tight ones, plus `test-tidy-outputs.R`,
`test-density-coordinate.R`, `test-canopy-methods.R`, `test-tf24-arid-corner.R`,
`test-strategy-tf24.R`, `test-scm-support.R`, `test-scenario-gateway.R` and the
`model-version` snapshot. A shift of the size measured here (0.36% on TF24; FF16
was not measured) breaks the two FF16 tolerances. `test-trapezium.R` covers the
helper itself and would stay as long as `util::trapezium` does.

**The change that would actually pay** is the other two trapezia.
`Species::reduce_competition` (`species.h:608-650`) with
`close_competition_and_slope` (`species.h:697-710`), and
`Species::consumption_rate` (`species.h:789-834`), reconstruct the stand from the
same nodes with the same rule, and they are what carries the -0.617%.
`abscissa_of` is passive in both coordinates (`species.h:326-330`), so a
higher-order rule there also keeps its weights off the tape. But these sit on the
hot path (one reduction per canopy height query per rate evaluation), they are
`value_type` rather than `double`, and they carry an early exit that is only
valid while heights fall, a boundary-node closure and a crossed-grid sort. That
is real work, and it is the prerequisite: a higher-order fitness integral shipped
before it makes every reported number 2.4x further from the truth.

## Verdict

| question | answer |
|---|---|
| how much error does the higher-order rule remove at 88 cohorts? | the **whole quadrature error**: +0.359% -> -0.0014% to -0.0024%, **148-258x**, in all six forcing records, for zero extra runs |
| observed convergence order? | trapezium **2.00**; cubic spline **3.2-4.3**; local cubic **3.9**; local quintic **4.7-5.6**; shape-preserving Hermite 1.6-2.8 |
| does it improve the model's answer? | **no.** at 88 cohorts the fitness is -0.259% wrong, of which -0.617% is cohort count and +0.359% is the trapezium cancelling 58% of it. the spline takes it to -0.617%, 2.4x worse, and by the same factor at 175 and 349 cohorts |
| under realistic mixed forcing? | irrelevant: the cohort-count error is -16% to -31% and does not converge, so quadrature is 1.2-2.2% of the error |
| where does it stop helping? | inside the one panel per record that holds a kink (6-120x worse there), which is 5.7-6.7% of its residual. what limits it in aggregate is the **dyadic spacing doublings** — 18% of panels, 54-71% of the spline's residual. on a ladder with a fixed step ratio and no doublings the spline improves 35% and the local rules reach their design orders |
| are there kinks in birth date? | yes: 4-6 adjacent nodes, in the two records with the most branch pressure, carrying 1.4-1.8% of `J`. inside the single default panel that holds one, the spline is 6x (aridity) to 120x (wet-dry swing) worse than the trapezium. branch co-occurrence itself is across **time**, not across birth date — all 88 cohorts share a branch at every instant, aridity included |
| does a piecewise rule recover the smooth stretches? | **no.** restarting the spline at a kink is 0.5-2.2% *worse* than ignoring it, in both kinked records and at every cohort count. only a local fallback (global spline, trapezium on the two panels touching the kink) wins, by 11-35% of an error already 170-190x below the trapezium's |

**What to do with this.** The trapezium in `patch.h:912` is not the dominant
error and should not be changed on its own. If the aim is a more accurate
`offspring_production`, the order of `Species::reduce_competition` is where the
error is; if the aim is a cheap improvement, a cohort ladder that grows smoothly
instead of in doublings is measured above to help every integral at once —
trapezium -12%, cohort count -14%, reported fitness -0.2586% to -0.2187% — for
one extra node and no formula change. And under any forcing
with real weather in it, neither matters until the cohort-count error converges —
which on four of the six records here, at `ode_tol = 1e-6`, it does not.

## Scripts

All in this scratchpad. **No code in `plant` or `odelia` was changed** — the
result argues against the change rather than for it — so both working trees are
clean at `claude/trusting-curie-4i9n3l` (`5321593a` / `be3e2cb`), there is
nothing to commit, and the `make test-cpp` / fast-sweep guard did not apply and
was not run.

| file | what |
|---|---|
| `quad_forcing.R` | the rainfall records: `gen_rain` with interannual multipliers and storm/drizzle event structure |
| `quad_rules.R` | the quadrature rules, all on non-uniform abscissae |
| `quad_rules_test.R` | exactness checks for each rule |
| `quad_common.R` | SCM construction, the nested schedule levels, one run -> its samples |
| `quad_verify.R` | the R reconstruction of the fitness integral against C++ |
| `quad_profile.R` | the integrand, node by node |
| `quad_runs.R` | the run jobs (`quad_<job>.rds` / `.log`) |
| `quad_analysis.R` | reference, rule x level table, panel attribution, smoothness test |
| `quad_report.R` | the four-section per-cell report (`quad_report.txt`) |
| `quad_summary.R` | the cross-record tables above |
| `quad_kink.R` | kinks, panel attribution, piecewise rules (`quad_kink.txt`) |
| `quad_census.R` | the operating-point census, per run and per cohort |
| `quad_weights.R` | the rules as weight vectors on a fixed set of abscissae |
| `quad_smooth.R` | the same measurements on a smoothly growing cohort ladder |
| `quad_height.R` | the height coordinate as a contrast |
