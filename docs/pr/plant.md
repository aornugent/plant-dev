# plant

**Base** `traitecoevo/plant:develop` · **Head** `aornugent/plant:ad/V4-reverse-tf24`
**Needs** odelia `v0.5.0` and phylloptim `v0.9.0` tagged first

## Title

Differentiate a stand's census by trait

## Body

A leaf that is slightly cheaper to build shades its neighbours slightly
more, so they grow slightly less, so they shade it back slightly less.
Fitting a trait to data means asking what a century of that feedback
does to a summary of the stand, for every trait at once: a TF24 species
carries forty-six of them, so differencing means forty-six re-runs, and
where a small change moves an event in the run it does not converge at
all.

A census metric now reports its exact derivative with respect to every
trait from a single run. The answer describes the emergent stand rather
than a plant in isolation, and the difference is not small: feedback
suppresses the response to leaf mass per area about sevenfold and
reverses the sign of the response to seed mass. Two contributions are
summed, because a census reads the traits directly as well as through
the size distribution they produced, and a metric returns either a
number or not-a-number carrying a stated reason for refusing.

Closes #

## First comment

### What a caller gets

`stand_gradient(scm, metrics = NULL, traits = NULL)` returns four entries.
`gradient` is the metrics-by-traits matrix, columns named `"1.lma"` for species
one's leaf mass per area. `refusal` holds one slot per metric, `NULL` where the
metric answered. `value` is the metrics themselves and `control` the settings
the gradient was taken at, so two gradients can be compared only when they were
taken alike.

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

### The two terms

A census metric integrates a per-plant quantity over the size distribution, and
a trait reaches the answer by two routes.

The **trajectory term** is the one a sweep produces: moving `lma` changes
growth, mortality and the light and water each plant competes for, all the way
along, and so changes the size distribution standing at the end.

The **allometric term** is what remains with the size distribution held
identical: a cohort of a given height reads a different leaf area, because leaf
area is itself a function of the trait. No sweep produces this, so it seeds the
walk rather than being added at the end — a term added last is a term that can
be left out, and a gradient missing it is a plausible number rather than an
error.

### Why the coordinate is birth date

The size-density distribution is carried in birth date, and the gradient
refuses the height coordinate rather than answering it.

Reserve-gated growth lets a younger cohort overtake an older one. In height
that reorders the quadrature, so the abscissa is state and the quadrature
weights carry a derivative nothing supplies. In birth date it cannot: plants
can change their relative size but not their relative age. The two coordinates
are different functions rather than two discretisations of one — one census
metric's trait sensitivity changes sign between them — so answering on the
height coordinate would be finite, plausible and wrong.

### Refusal is metric-level, and that is forced

A census metric is a sum over cohorts. A sum has no defined value when one term
is undefined, so a single leaf with no derivative makes every metric
not-a-number across every trait column. The grain is not chosen: the row that
could not be supplied is an intermediate of a recording spanning six stages and
every cohort in them, so no seed carries a component to attribute it to.

Refusing the affected columns and answering the rest would describe a quantity
that does not exist — a partial sum reported as the sum.

Two things a caller should know. A refusal does not always name a location: the
`species` field is `-1` where what failed spans every cohort, so a caller must
handle that rather than indexing with it. And not-a-number propagates through
arithmetic safely, except through a reduction that drops it —
`max(abs(g$gradient), na.rm = TRUE)` ignores a refused metric entirely. Check
`refusal` before any reduction taking `na.rm`.

### How the sweep is checked

The claim is that the reverse sweep computes the exact transpose of the forward
run. A finite difference cannot check it, because differencing is the thing the
sweep replaces — and near a coincidence it does not converge: refining a step
of one part in a million across three refinements gave −9.63, +166, −10588
against a feature five hundredths of a micron wide.

Six instruments, none sufficient alone:

| reference | catches | blind to |
|---|---|---|
| forward-mode tangent of the same recording | the assembly: stage recursion, both reductions, accumulation across cohorts | reads the same supplied leaf rows the sweep does |
| full block Jacobian at one cohort, both directions | localises to output row by input column; the only exhaustive referee | same supplied rows; one state, no trajectory |
| captured difference of whole runs | a wrong row, not only wrong assembly — shares no arithmetic | refuses on shaded and clamped regimes |
| the right-hand side differenced against state | the soil balance, drainage cascade, retention curve | records nothing, so cannot reach the leaf rows |
| the right-hand side differenced against prepared traits | most trait columns of the transpose | exactly zero on the leaf's own traits and on birth size |
| the model rebuilt from its parameters | the leaf-own traits and the seed-height row | patch only, no trajectory |

Injected corruptions establish that these notice a defect. A suite that reports
how much margin each check had says nothing about whether it would have fired.

### What the gradient does not answer

Soil and atmospheric parameters have no rows, so "what if the soil were
sandier" and "what if it were hotter" cannot be asked of it. Crown shape has
none either. A trait row holds the hyperparameters fixed, so an `lma` row is
not the trait an ecologist means by leaf mass per area — the two differ by
about threefold — and a sensitivity is not a physiological effect, which is a
mistake the number cannot warn you about.

The reverse pass is TF24's. FF16 and K93 declare no census metrics.

### Cost

A gradient with respect to every trait costs about 2.9 times a forward run of
the same stand, measured on the century fixture with the two arms interleaved
in one sitting. `docs/perf/` in the development superproject carries the
breakdown and the method.

### Two numerical primitives removed

`adaptive_interpolator` and `optimize` were this package's own copies of a
refining interpolant and a golden-section search. odelia carries both. A model
keeping its own copy of a numerical primitive inherits the library's problem
twice over: the copies drift, and only one of them is differentiable.
