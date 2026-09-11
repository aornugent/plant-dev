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

### What the number means

A **census metric** reduces a whole stand to one scalar by integrating a
per-plant quantity over the size distribution. TF24 declares three: `leaf_area`,
`mass_above_ground`, `area_stem` (`tf24_strategy.h:649`). A **trait** is a
parameter of the strategy the plants follow — `lma`, `hmat`, `omega` and
forty-three others.

The product is `d(metric)/d(trait)` over a whole century-long run. It is a
derivative of the *emergent* stand, not of a plant in isolation: a cheaper leaf
shades its neighbours, which grow less, which shade it back less, and the number
carries all of that. The difference is not cosmetic — environmental feedback
suppresses the response to leaf mass per area about sevenfold and **reverses the
sign** of the response to seed mass. A per-plant calculation does not get a
worse answer here, it gets the wrong direction.

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

`gradient` is metrics by traits, columns `"1.lma"` — species-major, in
`ad_parameters()` order. `refusal` is one slot per metric, `NULL` where it
answered. `control` is the five settings the gradient was taken at, so two
gradients compare only when taken alike.
`Control(node_density_in_birth_date = TRUE)` is required and defaults to `FALSE`.

### How it runs

```
   stand_gradient(scm)                              R/stand_gradient.R:102
        │  resolve metric and trait names, refuse ones the model lacks
        ▼
   census_trait_gradient_tf24                       src/census_gradient.cpp:81
        │  THE ONLY PLACE double becomes an active scalar for this product
        ▼
   SCM::census_trait_gradient                       scm.h:1011
        │
        ├─► census_state_and_trait_rows()           scm.h:893
        │      ONE recording over the states and the traits at the final time,
        │      swept twice to give two different things:
        │
        │        state rows  ──┐   d(metric)/d(final state)
        │        trait rows  ──┤   d(metric)/d(trait), read DIRECTLY
        │                      │
        ├──────────────────────┘
        │
        ├─► lambda STARTS at the trait rows                      scm.h:1080
        │      not "runs, then adds them" — see below
        │
        ├─► solver.solve_adjoint(lambda, trait_adjoint)          odelia
        │      │
        │      └─► one range per state width, widest first
        │            │  narrowing across each introduction
        │            │
        │            └─► per step, last to first:
        │                  re-record 6 stages at the active scalar
        │                     └─► Patch::compute_rates
        │                           └─► Species → Node → Individual
        │                                 └─► TF24_Strategy::solve_leaf
        │                                       └─► record_leaf_outputs()
        │                                             reads phylloptim's
        │                                             SUPPLIED rows
        │
        └─► census_gradient{ gradient[][], why }
```

**Two terms, and the second one seeds rather than follows.** A census reads the
traits twice over. The *trajectory term* is what the sweep produces: `lma`
changes growth, mortality and the light and water each plant competes for, all
the way along, so it changes the size distribution standing at the end. The
*allometric term* is what survives with that distribution held identical — a
cohort of a given height reads a different leaf area, because leaf area is itself
a function of the trait. No sweep produces that one.

It could have been added after the walk. It is used as the walk's starting value
instead, and `scm.h:1080` says why: *"a term added last is a term that can be
left out, and a gradient missing it is a plausible number rather than an error."*

**The sweep re-enters the forward model.** `Patch::compute_rates` runs twice per
step over the whole descent — once in plain `double` going forward, once at the
active scalar coming back. Everything below it in the call chain is therefore
compiled at both scalars, which is what forced the templating.

### Why the model had to become a template

`Internals` holds the state, rates and auxiliary values a strategy reads and
writes. Once the sweep re-enters `compute_rates` at an active scalar, `Internals`
must exist at that scalar too — and so must everything that touches it. That is
`Individual`, `Node`, `Species`, `Patch`, `SCM`, the environment, and the
strategy itself. The commit is one commit because the model is one graph: any
split leaves between 3 and 17 headers that do not compile.

Two details a strategy author needs. `Individual::state` now returns
`const value_type&` rather than `double` — by reference deliberately, because
copying an active scalar registers a tape slot. And FF16 and K93 are **not**
templated: they pin `using value_type = double` and never instantiate the active
path, so only TF24 pays the compile cost.

### Refusal, and why it takes the whole metric

A metric is a sum over cohorts, and a sum has no value when one term is
undefined. So if any cohort's contribution has no derivative, the whole metric's
row is not-a-number with one stated reason, across every trait column.

That grain is forced rather than chosen. What failed is an intermediate of one
recording spanning six stages and every cohort in them, so no seed carries a
component to attribute it to. Refusing the affected columns and answering the
rest would report a partial sum as the sum.

Two things a caller must know. A refusal does not always name a species — the
field is `-1` where what failed spans every cohort, so handle it rather than
indexing with it. And not-a-number propagates safely through arithmetic but not
through a reduction that drops it: `max(abs(g$gradient), na.rm = TRUE)` ignores a
refused metric silently. Check `refusal` before any `na.rm` reduction.

### Why the coordinate is birth date

The size-density distribution can be carried in height or in birth date, and the
gradient refuses height rather than answering it (`scm.h:160-175`).

Reserve-gated growth lets a younger cohort overtake an older one. In height that
reorders the quadrature, so the abscissa is itself state and the weights carry a
derivative nothing supplies. In birth date it cannot happen: plants can change
their relative size but not their relative age. The two are different functions
rather than two discretisations of one — one census metric's trait sensitivity
changes sign between them — so answering on height would be finite, plausible and
wrong.

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

Injected corruptions establish these would notice a defect; a suite reporting how
much margin each check had says nothing about whether it would fire.

A gradient over all traits costs about 2.9× a forward run of the same stand,
measured on the century fixture with the arms interleaved in one sitting.

### Reading order

1. `census.h`, `census_gradient.h` — 116 lines. What a metric is, what a refusal is.
2. `tf24_strategy.h:649` for the three metrics, `:224-310` for the trait table and its 18 `no_gradient` entries.
3. `scm.h:1011-1150` — `census_trait_gradient` end to end. The shortest complete path through the change.
4. `scm.h:893` — `census_state_and_trait_rows`, where both terms come from.
5. `tf24_strategy.h:2193` — `solve_leaf` and `record_leaf_outputs`, the seam with phylloptim.
6. `patch.h`, `species.h`, `node.h` last — mechanical once the above makes sense.

### What to check it against

| claim | where |
|---|---|
| A metric returns a number the sweep computed, or NaN with a stated reason — never a partial sum | `scm.h:1128-1145` |
| An exact zero in an answered row is the sweep's answer, not a gap | `scm.h:1141` |
| A parameter with no row cannot be asked for | `undifferentiable`, `tf24_strategy.h:224`, held by `static_assert(column_count + undifferentiable.size() == field_count)` at `:375` |
| The tape defines match odelia's exactly | `src/Makevars:16`. A mismatch is a storage-class conflict on a symbol whose mangled name does not change — it links cleanly and is undefined behaviour |
| The gradient is TF24's | `census_gradient.cpp` names `TF24_Strategy` throughout; FF16 and K93 declare no `census_metrics` |

### Out of scope, stated so nobody assumes otherwise

Soil and atmospheric parameters have no rows, so "what if the soil were sandier"
cannot be asked of this. Crown shape has none. A trait row holds the
hyperparameters fixed, so an `lma` row differs by about threefold from the trait
an ecologist means by leaf mass per area. And a sensitivity is not a
physiological effect — that is the one the number cannot warn you about.

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
