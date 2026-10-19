# The whole thing, then its parts

## The whole thing

The stand that makes crowns cross: one TF24 species on a synthetic
41-year daily rainfall record (`harness/long_drought.R` in plant-dev,
described in #113), 108 introductions over 40 years, the birth-date
coordinate, `ode_tol` 1e-3, a stop at every rain knot. On the base
(#113):

```r
{{SNIP97}}
```

On this branch the same calls give:

```r
{{SNIP107}}
```

{{WHOLE}}

The rest explains a part of this.

## Terms

- **running total**: the per-moment prefix sums over the nodes,
  `prefix[i]`, taken once per light build. A knot reads the prefix of the
  nodes tall enough to reach it.
- **out of order**: a younger cohort taller than the one born before it,
  as `Species::scan_heights()` finds it in list order (oldest first),
  skipping retired cohorts when the top layer is on.

## Control flow

```
  Patch::compute_rates                         each of a step's six stages
    └─ compute_environment
         └─ the light spline at 65 knots, ascending in height
              └─ Species::field_splits(knots) → field_splits_nodes
                   scan_heights(): do heights fall along the node list?
                   │
                   ├─ yes ─────────────────► order = {}   (list order)
                   ├─ no, birth date ──────► order = ascending_by_abscissa()
                   │                          tallest first        [this PR]
                   │     prefix[i+1] = prefix[i] + 2 w[o] scale[o] mom[o]
                   │     each knot, lowest first: drop the nodes below it
                   │     from `reach`, read prefix[reach]
                   │
                   └─ no, height coordinate; or a crown not polynomial
                         ─► compute_competition_and_slope_split per knot:
                            every crown at every knot
```

Before this change the middle branch did not exist: a crossed list on
the birth-date coordinate took the last branch.

## What changes for existing code

Nothing in the interface. Where no crowns cross, `order` is empty, the
loop is the old loop index for index, and results are bit-identical.
Where crowns cross, each node's term is the same and only the order of
summation changes, so results move by rounding: {{ROUND}}. No reference
moves.

## Files

| file | lines | what |
|---|---|---|
| `species.h` | +24 −17 | `field_splits_nodes`: the gate, `order` and `at()` |
| `tests/testthat/test-canopy-methods.R` | +33 | new: a TF24 birth-date stand with its tallest and shortest cohorts swapped; the light at every knot against Beer's law summed over every crown |

Read `Species::field_splits_nodes` from the `scan_heights()` call to the
end of the knot loop: the gate, then `at()`, which is the only change to
the arithmetic. `ascending_by_abscissa()` is unchanged and already
served the height coordinate.
