# plant

**Base** `traitecoevo/plant:develop` · **Head** `aornugent/plant:ad/V4-reverse-tf24`
**Needs** odelia `v0.5.0` and phylloptim `v0.9.0` tagged first

Two comments, posted in order.

## Title

Differentiate a stand's census by trait

## Body

A leaf slightly cheaper to build shades its neighbours slightly more, so
they grow slightly less, so they shade it back slightly less. Fitting a
trait means asking what a century of that does to a stand summary, for
all forty-eight TF24 traits at once. Differencing costs forty-eight
re-runs and does not converge where a trait moves an event in the run.

`stand_gradient(scm)` returns that derivative exactly, from one run, as
`list(value, gradient, refusal, control)`. The model is templated on its
scalar: `Internals` becomes `Internals<double>` and `Individual::state`
returns `const value_type&`. `run_scm()` takes `record_trajectory` where
it took `use_ode_times`; `NodeSchedule` holds one row per instant, so
`$size` counts instants not introductions; `Interpolator` is gone and
`ResourceSpline` carries height, value and slope. TF24 numbers move:
`GSS_tol_abs` 1e-3 to 1e-1, `vulnerability_curve_ncontrol` 100 to 400.

Closes #

---

# Comment 1 — The whole thing, then its parts

## The whole thing

Run a stand, then ask how its census responds to every trait at once.

```r
p   <- scm_base_parameters("TF24")
p   <- add_strategies(p, trait_matrix(c(0.0825, 5.13), c("lma", "hmat")),
                      hyperpar = TF24_hyperpar, birth_rate = list(1.10))
scm <- run_scm(p, Environment("TF24"),
               Control(node_density_in_birth_date = TRUE),
               refine_schedule = TRUE, record_trajectory = TRUE)

g <- stand_gradient(scm)

dim(g$gradient)
#> [1]  3 48        three metrics by forty-eight trait columns, from one pass

g$gradient["mass_above_ground", "1.lma"]
#>                  d(mass above ground)/d(lma) for species 1, over the whole run
```

One run forward, one sweep back, and every cell is filled. Differencing would
cost forty-eight re-runs and would not converge where a trait moves an event.

Three things a caller must know before the rest makes sense.
`Control(node_density_in_birth_date = TRUE)` is required and defaults to `FALSE`.
`refusal` carries a stated reason where a metric has no derivative, and NaN
without a reason is a bug rather than an answer. And `control` records the five
settings the gradient was taken at, so `stand_gradient_compare()` can refuse two
gradients taken differently.

The number is a derivative of the emergent stand, not of a plant in isolation.
Environmental feedback suppresses the response to leaf mass per area about
sevenfold and reverses the sign of the response to seed mass — for seed mass, a
calculation holding the neighbours fixed gives the wrong direction.

## Terms

- **census metric** — a stand reduced to one scalar. TF24 declares three: `leaf_area`, `mass_above_ground`, `area_stem`.
- **row** — one output's derivatives against a list of inputs. phylloptim supplies the leaf's rows; the sweep never records its solve.
- **refusal** — a declared reason a metric has no derivative, carried beside NaN.
- **range** — consecutive recorded steps at constant state width. A new one begins at each introduction; the century fixture has 169.

Of TF24's 67 parameter-table entries, 19 are `undifferentiable`, leaving 48
columns per species. Columns are named `"1.lma"` — species-major, because two
species carrying the same trait need distinguishing and R's character indexing
would otherwise return species one's column for both.

## Control flow

```
  stand_gradient(scm)                         R/stand_gradient.R
    │  resolve names, refuse ones the model lacks
    ▼
  census_trait_gradient_tf24                  src/census_gradient.cpp
    │  the only place double becomes an active scalar
    ▼
  SCM::census_trait_gradient                  scm.h
    │
    ├─► census_state_and_trait_rows()
    │     one recording at the final time, swept for two things:
    │       state rows   d(metric)/d(final state)
    │       trait rows   d(metric)/d(trait), read directly
    │
    ├─► lambda STARTS at the trait rows
    │
    ├─► solver.solve_adjoint(...)             odelia
    │     │
    │     ├─► range N … 1                     widest first
    │     │     │
    │     │     ├─► step k … 1                last to first
    │     │     │     └─ re-run 6 stages at the active scalar
    │     │     │          └─ Patch::compute_rates
    │     │     │               └─ Species → Node → Individual
    │     │     │                    └─ TF24_Strategy::solve_leaf
    │     │     │                         └─ record_leaf_outputs()
    │     │     │                              reads phylloptim's supplied rows
    │     │     │
    │     │     └─► at an introduction: sweep apply_insertion,
    │     │              so a newborn's initial conditions carry trait rows
    │
    └─► census_gradient{ gradient[][], why }
```

Scale, for one worked case — a single species over about 105 years at the
package defaults: 169 cohort introductions, so 169 ranges; 3,400 accepted steps
and six rate evaluations in each; a few million leaf placements. Those counts
follow from the schedule and the step controller and will differ for any other
stand. **The ratio holds across the ones measured: a gradient over all traits
costs about 2.9 times a forward run of the same stand**, with the two arms
interleaved in one sitting.

## What changes for existing code

| old | new |
|---|---|
| `run_scm(..., use_ode_times, ...)` | `run_scm(..., record_trajectory, ...)` — same position, different meaning, so a positional caller gets the wrong flag |
| `Interpolator$new()` | gone; `ResourceSpline` carries height, value and slope |
| `sched$next_event` | `sched$next_introduction` |
| `sched$ode_times <- x` | `sched$set_ode_steps(times, sizes)` |
| `sched$size` | counts instants, not introductions |
| `Control$save_RK45_cache` | gone; `Control$gradient_curvature_floor` added |
| `patch$introduce_new_node(i)` | `patch$introduce_new_node(i, time)` |
| `plant::Internals` | `Internals<double>` |
| `Individual::state` returning `double` | returning `const value_type&` |
| `plant/adaptive_interpolator.h`, `optimize.h` | odelia's |

Forward numbers move for every TF24 run whether or not a gradient is taken:
`GSS_tol_abs` 1e-3 → 1e-1, `vulnerability_curve_ncontrol` 100 → 400. FF16 and
K93 go `scientific_version` 1 → 2 on the birth-date coordinate.

The gradient is TF24's. `census_gradient.cpp` names `TF24_Strategy` throughout
and `tf24_strategy.h` is the only file declaring `census_metrics`, so an FF16
stand handed to `stand_gradient()` fails in an `Rcpp::as` type error rather than
a model-level refusal.

## Files

| file | lines | what |
|---|---|---|
| `models/tf24_strategy.h` | +2533 | the strategy, templated; absorbs the deleted `.cpp` |
| `patch.h` | +1120 | the stand; `at_scalar`, `plant::tangent` |
| `scm.h` | +1004 | the solver and `census_trait_gradient` |
| `species.h` | +697 | per-species accumulation |
| `models/tf24_environment.h` | +524 | light and soil, templated |
| `census.h` | 59 | new — `census_metric<Strategy>`, `Censusable` |
| `census_gradient.h` | 59 | new — `census_gradient`, `refusal` |
| `clamp_sites.h` | 100 | new |
| `with_slope.h` | 38 | new — alias of odelia's |

Deleted: `adaptive_interpolator.{h,cpp}`, `optimize.h`, and four `src/` files —
`tf24_strategy.cpp`, `tf24f_strategy.cpp`, `tf24_node.cpp`, `tf24f_node.cpp`.
New R exports: `stand_gradient`, `stand_census`, `stand_census_state_adjoint`,
`stand_gradient_compare`, `gradient_control`.

Read `census.h` and `census_gradient.h` first — 118 lines, and they say what a
metric and a refusal are. Then `SCM::census_trait_gradient` end to end,
which is the shortest complete path through the change. Then
`census_state_and_trait_rows`, then `solve_leaf` and `record_leaf_outputs` for
the seam with phylloptim. `patch.h`, `species.h` and `node.h` are mechanical after that.

---

# Comment 2 — How it works

## Two terms, and why the second one seeds the walk

A census metric integrates a per-plant quantity over the size distribution, and a
trait reaches the answer by two routes.

The **trajectory term** is what the sweep produces. Changing `lma` changes growth
and mortality, and it changes the light and water every other plant is competing
for, all the way along the run — so it changes the size distribution standing at
the end. This is the term that needs a whole reverse pass.

The **allometric term** is what survives when that distribution is held
identical. A cohort of a given height reads a different leaf area under a
different `lma`, because leaf area is itself a function of the trait
in `area_leaf`. No sweep produces this; it comes from differentiating
the census expression directly. The boundary recruit node belongs here too — it
is the trapezium's lower grid point and is not ODE state.

Both come out of one recording at the final time, swept twice with different
seeds. The allometric term could then be added to the sweep's
answer at the end. It is used as the walk's starting value instead, and
`census_trait_gradient` gives the reason at the site: *"a term added last is a term that can be left
out, and a gradient missing it is a plausible number rather than an error."*
A missing trajectory term produces obvious nonsense; a missing allometric term
produces a number of the right order that is quietly wrong.

## Why the model became a template

`Internals` holds the state, rates and auxiliary values a strategy reads and
writes. The sweep re-enters `Patch::compute_rates` at an active scalar, so
`Internals` has to exist at that scalar — and so does everything that touches it:
`Individual`, `Node`, `Species`, `Patch`, `SCM`, the environment and the strategy
itself.

Twenty-three headers transitively include `internals.h`. That is why this arrives
as one commit: any split leaves between 3 and 17 headers that do not compile, and
a sequence of commits that do not build is worse to review than one that does.

FF16 and K93 are not templated. They pin `using value_type = double` and never
instantiate the active path, so only TF24 pays the compile cost — which is real,
since `tf24_strategy.h` grew from 771 lines to 2,886 by absorbing its `.cpp`, and
twelve of the twenty-five translation units now recompile it.

`Individual::state` returns `const value_type&` where it returned `double`.
Copying an active scalar registers a tape slot and records an operation, once per
element per stage, for a value the caller was about to assign anyway.

## Where a derivative stops, and how to lose one by accident

The boundary between the differentiated interior and the plain-`double` world is
`write_iterator_scalar`:

```cpp
  if constexpr (std::floating_point<
                  typename std::iterator_traits<It>::value_type>) {
    *it++ = odelia::util::to_passive(value);   // derivative dropped here
  } else {
    *it++ = value;
  }
```

At the R boundary this is exactly right: nothing in R holds an active scalar, so
there has to be one place where the derivative is deliberately discarded, and
keying it on the destination's type means the conversion cannot be forgotten.

It is also type-directed and completely silent, which makes it the easiest way to
lose a gradient in this codebase. A `std::vector<double>` scratch buffer
introduced anywhere on the rate path zeroes every derivative passing through it,
with no diagnostic and every number still finite.
`TF24_Environment::resource_uptake` is already such a buffer. Any new container
on an active path is worth checking for its `value_type` before anything else.

## Refusal takes the whole metric

A census metric is a sum over cohorts, and a sum has no defined value when one of
its terms is undefined. So if any cohort's contribution has no derivative, the
metric's whole row is NaN with one stated reason, across every trait column.

The grain is forced by where the failure occurs. What could not be supplied is an
intermediate of one recording that spans six stages and every cohort in them, so
no seed carries a component that could attribute it to a particular cohort or a
particular trait. Refusing the affected columns and answering the rest would
report a partial sum as though it were the sum.

The cost of that grain is high — one leaf without a derivative makes all three
metrics NaN across all 48 columns — which is a strong incentive to make
inadmissible points rare, and is most of what phylloptim's operating-point
machinery is for.

Two things follow for a caller. The `species` field of a refusal is one-based
where the refusal came from a particular species' strategy, and `-1` where what
failed spans every cohort, so reading it means handling `-1` and not indexing
with it. And NaN propagates safely through arithmetic but not through a reduction
that drops it: `max(abs(g$gradient), na.rm = TRUE)` ignores a refused metric
entirely and returns a confident number.

## The stem path integral is differentiated, its branch is not

The upstream merge brought TF24's height-resistance from stem anatomy, which
computes an effective path length

```
    L_eff = ∫ from L_tip to L_top  (L / L_tip)^(−beta) dL,     beta = 2·D_c + theta_c
```

and that integral takes a different closed form depending on whether `beta` is
zero, one, or neither. `stem_hydraulics.h` is templated on the scalar, so the
integral itself carries derivatives — but which closed form to use is read off
the **passive** value of `beta`. The backward pass therefore differentiates the
model at a fixed choice of branch, never the choice.

That is the same rule the coordinate follows, applied one level down: a branch
selector is piecewise constant in its inputs, so differentiating through one
manufactures a discontinuity the model does not have.

`D_c` and `L_tip` carry columns. `theta_c` is `undifferentiable` and the reason is not that a derivative is hard:
`prepare_strategy` throws on any non-zero value, so a column there would price
the hydraulic half of a trait the carbon budget does not yet follow.

## Why the coordinate is birth date

The size-density distribution can be carried in height or in birth date. The
gradient refuses height rather than answering it, in `require_birth_date_coordinate`.

Reserve-gated growth lets a younger cohort overtake an older one. In the height
coordinate that reorders the quadrature, which means the abscissa is itself a
state variable and the quadrature weights carry a derivative that nothing
supplies. In birth date it cannot happen: plants can change their relative size
but not their relative age, so the ordering is fixed for the whole run and the
weights are constants.

The two are different functions and not two discretisations of one — one census
metric's trait sensitivity changes sign between them — so a gradient taken on the
height coordinate would be finite, plausible and wrong, with nothing in the
arithmetic to complain.

## One invariant a new strategy must honour

`establishment_failure_hazard = 750.0` in `internals.h` is the cumulative
hazard a cohort is parked at when its establishment probability is exactly zero,
which happens in deep shade. Without it the hazard is `+Inf`, and an infinite
entry in an ODE state is worse than it sounds: the step-size controller scales
error by the magnitude of the state, so at an infinite state the ratio of error
to allowance is zero and that component cannot constrain the step however large
its rate.

750 and not a round number because `exp(-x)` is exactly zero past 745.14, so
survival and mortality probability read the numbers `+Inf` would have given them
while the state itself stays finite.

Every `mortality_dt` must test that ceiling **beside** `is_finite`, and all three
do. Keyed on finiteness alone a finite hazard passes the test, the rate returns,
and the cohort's state starts moving again — so the run is no longer the one the
failed establishment produced. Nothing enforces this; it is positional, and a new
strategy that tests finiteness alone will be wrong in a way no test currently
catches.

## How the sweep is refereed

The claim is that the reverse sweep is the exact transpose of the forward run. A
finite difference cannot check it, because differencing is the thing being
replaced — and near a coincidence it does not converge at all: refining a step of
one part in a million across three successive refinements produced −9.63, +166,
−10588 against a feature five hundredths of a micron wide.

Six instruments, none sufficient alone:

| reference | catches | blind to |
|---|---|---|
| forward tangent of the same recording | stage recursion, both reductions, accumulation across cohorts and species | reads the same supplied leaf rows the sweep does |
| full block Jacobian at one cohort | output row × input column; the only exhaustive referee | same supplied rows; one state, no trajectory |
| captured difference of whole runs | a wrong row, not just wrong assembly — shares no arithmetic with the sweep | refuses on shaded and clamped regimes |
| RHS differenced against state | soil balance, drainage cascade, the retention curve's own derivative | records nothing, so cannot reach the leaf rows at all |
| RHS differenced against prepared traits | most trait columns of the transpose | exactly zero on the 12 leaf-own traits and the 8 birth-size parameters |
| model rebuilt from its parameters | the leaf-own traits and the seed-height row | patch only, no trajectory |

Deliberately corrupted values were injected to establish that these checks notice
a defect when one is present. A suite that records how much margin each check had
says nothing about whether the check would have fired.

## One hazard a user will meet

A gradient taken where the run crosses an unresolved event — a cohort reaching
`hmat` between two steps, say — is a derivative of the trajectory's step
placement and not of the model. One measured cell was 211 times the median of its
grid.

**Do not average such a grid, and do not form a covariance from one.** A single
outlying cell of that size dominates any second moment, so the summary statistic
is reporting the step placement rather than the ecology. The remedy is to nudge
the trait a fraction of a percent and take the answer that is stable, or to
resolve the event by forcing a step at the crossing. Nothing in the API detects
it, so this is a thing to know rather than a thing to catch.

## What has no row

Soil and atmospheric parameters carry none, so "what if the soil were sandier",
and the same question about temperature or CO₂, cannot be asked of this gradient
at all. Crown shape carries none either, excluded because `0^η · log 0` has no
value at the defaults.

And a trait row holds the hyperparameters fixed. An `lma` row is therefore about
threefold away from the derivative with respect to the trait an ecologist means
by leaf mass per area, which drags leaf turnover and respiration along with it.
A sensitivity from this gradient is not a physiological effect, and the number
cannot warn you about the difference.
