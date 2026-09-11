# plant

**Base** `traitecoevo/plant:develop` · **Head** `aornugent/plant:ad/V4-reverse-tf24`
**Needs** odelia `v0.5.0` and phylloptim `v0.9.0` tagged first

## Title

Differentiate a stand's census by trait

## Body

A leaf slightly cheaper to build shades its neighbours slightly more, so
they grow slightly less, so they shade it back slightly less. Fitting a
trait means asking what a century of that does to a stand summary, for
all forty-six TF24 traits at once. Differencing costs forty-six re-runs
and does not converge where a trait moves an event in the run.

`stand_gradient(scm)` returns that derivative exactly, from one run, as
`list(value, gradient, refusal, control)`. The model is templated on its
scalar: `Internals` becomes `Internals<double>` and `Individual::state`
returns `const value_type&`. `run_scm()` takes `record_trajectory` where
it took `use_ode_times`; `NodeSchedule` holds one row per instant, so
`$size` counts instants not introductions; `Interpolator` is gone and
`ResourceSpline` carries height, value and slope. TF24 numbers move:
`GSS_tol_abs` 1e-3 to 1e-1, `vulnerability_curve_ncontrol` 100 to 400.

Closes #

## First comment

### The quantity

A **census metric** reduces a stand to one scalar by integrating a per-plant
quantity over the size distribution. TF24 declares three — `leaf_area`,
`mass_above_ground`, `area_stem` (`tf24_strategy.h:649`). A **trait** is a
parameter of the strategy the plants follow; TF24 has 64 table entries of which
18 are declared `undifferentiable`, leaving 46 columns per species.

The product is `d(metric)/d(trait)` over a whole run. It describes the emergent
stand: a cheaper leaf shades its neighbours, they grow less, they shade it back
less, and the number carries all of it. Environmental feedback suppresses the
response to leaf mass per area about sevenfold and **reverses the sign** of the
response to seed mass. A per-plant calculation here does not give a worse answer,
it gives the wrong direction.

### The call

```r
p   <- scm_base_parameters("TF24")
p   <- add_strategies(p, trait_matrix(c(0.0825, 5.13), c("lma", "hmat")),
                      hyperpar = TF24_hyperpar, birth_rate = list(1.10))
scm <- run_scm(p, Environment("TF24"),
               Control(node_density_in_birth_date = TRUE),
               refine_schedule = TRUE, record_trajectory = TRUE)
g   <- stand_gradient(scm)
g$gradient["mass_above_ground", "1.lma"]
```

`gradient` is metrics by traits, columns `"1.lma"`, species-major in
`ad_parameters()` order. `refusal` is one slot per metric, `NULL` where it
answered. `control` is the five settings the gradient was taken at, so two
gradients compare only when taken alike.
`Control(node_density_in_birth_date = TRUE)` is required and defaults to `FALSE`.

### How it runs

```
   stand_gradient(scm)                          R/stand_gradient.R:102
        │  resolve names, refuse ones the model lacks
        ▼
   census_trait_gradient_tf24                   src/census_gradient.cpp:81
        │  the only place double becomes an active scalar for this product
        ▼
   SCM::census_trait_gradient                   scm.h:1011
        │
        ├─► census_state_and_trait_rows()       scm.h:893
        │      one recording at the final time, swept for two different things:
        │        state rows   d(metric)/d(final state)
        │        trait rows   d(metric)/d(trait), read directly
        │
        ├─► lambda STARTS at the trait rows                    scm.h:1080
        │
        ├─► solver.solve_adjoint(lambda, trait_adjoint)        odelia
        │      │
        │      ├─ 169 ranges over 3,378 recorded steps on the century fixture
        │      │
        │      ├─ at each introduction: apply_insertion recorded and swept,
        │      │    so a newborn's initial conditions contribute trait rows
        │      │
        │      └─ per step, last to first: re-record 6 stages at the active
        │           scalar → Patch::compute_rates → Species → Node
        │             → Individual → TF24_Strategy::solve_leaf
        │               → record_leaf_outputs()  reads phylloptim's supplied rows
        │
        └─► census_gradient{ gradient[][], why }
```

A century run is 3,378 steps and 20,268 rate evaluations, six per step because
every step is re-recorded whole. It places 2.3 million leaves.

### Two terms, and why the second one seeds

A census reads its traits twice over. The **trajectory term** is what the sweep
produces: `lma` changes growth, mortality and the light and water each plant
competes for, all the way along, so it changes the size distribution standing at
the end. The **allometric term** is what survives with that distribution held
identical — a cohort of a given height reads a different leaf area, because leaf
area is itself a function of the trait. No sweep produces that one.

It could be added after the walk finishes. It is used as the walk's starting
value instead, and `scm.h:1080` gives the reason: *"a term added last is a term
that can be left out, and a gradient missing it is a plausible number rather than
an error."*

### Why the model became a template

`Internals` holds the state, rates and auxiliaries a strategy reads and writes.
Once the sweep re-enters `compute_rates` at an active scalar, `Internals` must
exist at that scalar, and so must everything touching it: `Individual`, `Node`,
`Species`, `Patch`, `SCM`, the environment, the strategy. Twenty-three headers
transitively include `internals.h`, which is why this is one commit — any split
leaves between 3 and 17 headers that do not compile.

FF16 and K93 are **not** templated. They pin `using value_type = double` and
never instantiate the active path, so only TF24 pays the compile cost.

`Individual::state` now returns `const value_type&` and not `double`. Copying an
active scalar registers a tape slot, once per element per stage, for a value the
caller was about to assign anyway.

### The boundary is type-directed, and it is silent

The place a derivative stops is `write_iterator_scalar` (`util.h:147`):

```cpp
  if constexpr (std::floating_point<
                  typename std::iterator_traits<It>::value_type>) {
    *it++ = odelia::util::to_passive(value);   // derivative dropped here
  } else {
    *it++ = value;
  }
```

That is how the R boundary works and it is correct there. It is also the trap: a
`std::vector<double>` scratch buffer introduced anywhere on an active path zeroes
every derivative flowing through it, with no diagnostic and every number finite.
`TF24_Environment::resource_uptake` is already such a buffer. Review any new
container on the rate path for its `value_type`.

### Refusal takes the whole metric

A metric is a sum over cohorts, and a sum has no value when one term is
undefined. If any cohort's contribution has no derivative, the metric's whole row
is not-a-number with one stated reason, across every trait column.

The grain is not a choice. What failed is an intermediate of one recording
spanning six stages and every cohort in them, so no seed carries a component to
attribute it to. Refusing the affected columns and answering the rest reports a
partial sum as the sum.

A refusal does not always name a species: the field is `-1` where what failed
spans every cohort. And not-a-number propagates safely through arithmetic but not
through a reduction that drops it — `max(abs(g$gradient), na.rm = TRUE)` ignores
a refused metric silently. Check `refusal` before any `na.rm` reduction.

### One invariant a new strategy must honour

`establishment_failure_hazard = 750.0` (`internals.h:41`) is the cumulative
hazard a cohort is parked at when its establishment probability is exactly zero.
750 and not a round number because `exp(-x)` is exactly zero past 745.14, so
survival reads what `+Inf` would have given without the state itself being
infinite.

Every `mortality_dt` must test it **beside** `is_finite`, and all three do. Keyed
on finiteness alone, a finite hazard passes, the rate returns, and the cohort's
state moves again — so the run is no longer the one the failed establishment
produced. Nothing enforces this; it is positional.

### Why the coordinate is birth date

The size-density distribution can be carried in height or in birth date, and the
gradient refuses height (`scm.h:160-175`).

Reserve-gated growth lets a younger cohort overtake an older one. In height that
reorders the quadrature, so the abscissa is itself state and the weights carry a
derivative nothing supplies. In birth date it cannot happen: plants can change
their relative size but not their relative age. The two are different functions,
not two discretisations of one — one census metric's trait sensitivity changes
sign between them — so answering on height would be finite, plausible and wrong.

### How the sweep is refereed

Differencing cannot check it, because differencing is what it replaces, and near
a coincidence it does not converge: a step of one part in a million refined three
times read −9.63, +166, −10588 against a feature five hundredths of a micron
wide. Six instruments, each blind to something:

| reference | catches | blind to |
|---|---|---|
| forward tangent of the same recording | stage recursion, both reductions, accumulation across cohorts | reads the same supplied leaf rows the sweep does |
| full block Jacobian at one cohort | localises to output row × input column; the only exhaustive one | same supplied rows; one state, no trajectory |
| captured difference of whole runs | a wrong row, not just wrong assembly — shares no arithmetic | refuses on shaded and clamped regimes |
| RHS differenced against state | soil balance, drainage cascade, retention curve | records nothing, cannot reach the leaf rows |
| RHS differenced against prepared traits | most trait columns of the transpose | exactly zero on the 12 leaf-own traits and 8 birth-size parameters |
| model rebuilt from parameters | the leaf-own traits and the seed-height row | patch only, no trajectory |

Injected corruptions establish these would notice a defect. A suite reporting how
much margin each check had says nothing about whether it would fire.

A gradient over all traits costs about 2.9× a forward run of the same stand,
measured on the century fixture with the arms interleaved in one sitting.

### One hazard a user will meet

A gradient taken where the run crosses an unresolved event — a cohort reaching
`hmat` between two steps — is a derivative of the trajectory's step placement and
not of the model. One measured cell was 211 times the median of its grid. **Do
not average such a grid and do not form a covariance from one**, because a single
outlying cell dominates any second moment. Nudge the trait a fraction of a
percent and take the answer that is stable, or force a step at the crossing.
Nothing detects it for you.

### What has no row

Soil and atmospheric parameters, so "what if the soil were sandier" cannot be
asked of this. Crown shape, excluded because `0^η·log 0` has no value at the
defaults. And a trait row holds the hyperparameters fixed, so an `lma` row is
about threefold away from the trait an ecologist means by leaf mass per area.

### Reading order

1. `census.h`, `census_gradient.h` — 116 lines. What a metric is, what a refusal is.
2. `tf24_strategy.h:649` for the three metrics, `:224-310` for the trait table and its 18 `no_gradient` entries.
3. `scm.h:1011-1150` — `census_trait_gradient` end to end. The shortest complete path through the change.
4. `scm.h:893` — `census_state_and_trait_rows`, the source of both terms.
5. `tf24_strategy.h:2193` — `solve_leaf` and `record_leaf_outputs`, the seam with phylloptim.
6. `patch.h`, `species.h`, `node.h` last — mechanical once the above makes sense.

### What to check it against

| claim | where |
|---|---|
| A metric returns a number the sweep computed, or NaN with a stated reason; never a partial sum | `scm.h:1128-1145` |
| An exact zero in an answered row is the sweep's answer, not a gap | `scm.h:1141` |
| A parameter with no row cannot be asked for | `undifferentiable`, `tf24_strategy.h:224`, held by `static_assert(column_count + undifferentiable.size() == field_count)` at `:375` |
| The tape defines match odelia's exactly | `src/Makevars:16`. A mismatch is a storage-class conflict on a symbol whose mangled name does not change: it links cleanly and is undefined behaviour |
| The gradient is TF24's | `census_gradient.cpp` names `TF24_Strategy` throughout; FF16 and K93 declare no `census_metrics` |

### File inventory

| file | lines | what it is |
|---|---|---|
| `models/tf24_strategy.h` | +2400 | the strategy, templated; absorbs the deleted `.cpp` |
| `patch.h` | +1120 | the stand; `at_scalar`, `plant::tangent` |
| `scm.h` | +1002 | the solver and `census_trait_gradient` |
| `species.h` | +697 | per-species accumulation |
| `models/tf24_environment.h` | +524 | light and soil, templated |
| `census.h` | 59 | new — `census_metric<Strategy>`, `Censusable` |
| `census_gradient.h` | 57 | new — `census_gradient`, `refusal` |
| `clamp_sites.h` | 100 | new |
| `with_slope.h` | 38 | new — alias of odelia's |

Deleted: `adaptive_interpolator.{h,cpp}`, `optimize.h`, `tf24_strategy.cpp`,
`tf24f_strategy.cpp`. Five new R exports: `stand_gradient`, `stand_census`,
`stand_census_state_adjoint`, `stand_gradient_compare`, `gradient_control`.
