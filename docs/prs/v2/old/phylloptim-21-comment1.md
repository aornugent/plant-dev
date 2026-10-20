## The whole thing

The leaf's derivative path is C++ only; plant drives it through
`Leaf::supply_draw_at`, `Leaf::collar_at` and `Leaf::outputs_at` at an
active scalar. `leaf_rows_cpp.R` (beside the figures) compiles two
small Rcpp functions against an installed phylloptim that call exactly
those, at plant's TF24 root curve (`root_P50` 3.4 MPa, `root_c`
2.680147), plant's 400-knot tables and plant's `GSS_tol_abs` of 0.1:

- `G_rows()` reads G(psi) from the root table and its `root_P50` row
  from `closed_form_integral`, the function `uptake_at` calls, beside a
  central difference of the table read in `root_P50`.
- `collar_rows()` solves a one-layer leaf (the drivers of
  `tests/cpp/test_leaf.cpp`, `stem_P50` 3.4287), then takes the
  collar's `psi_soil` row from `collar_at` on the tangent scalar,
  beside a central difference of the solved collar.

```r
compile_leaf_rows(ph_lib, od_lib)  # this branch, odelia 0.8.0

# The root integral either side of its last knot (6.89 MPa): the table's G,
# its root_P50 row, and a central difference of the table in root_P50.
G_rows(psi = c(6.5, 7.0, 8.0), P50 = 3.4, c = 2.680147, resolution = 400,
       h = 1e-5)[, c("psi", "G", "row", "fd")]
#>   psi        G       row        fd
#> 1 6.5 3.455171 0.9789163 0.9789163
#> 2 7.0 3.461860 0.9976058 0.9976058
#> 3 8.0 3.465780 1.0193471 1.0193471

# Collar intervals 0.13 and 0.05 MPa wide, the second narrower than
# GSS_tol_abs: the collar, its psi_soil row and a central difference of the solve.
collar_rows(psi_soil = c(5.2, 5.6), stem_P50 = 3.4287, root_P50 = 3.4,
            GSS_tol_abs = 0.1, resolution = 400,
            h = 1e-6)[, c("psi_soil", "kind", "collar", "row", "fd")]
#>   psi_soil       kind   collar       row        fd
#> 1      5.2   interior 5.286730 0.8843193 0.8843112
#> 2      5.6 determined 5.629575 0.9135894 0.9149395
```

The same calls compiled against master (0.10.3):

```r
#>   psi        G       row        fd
#> 1 6.5 3.455171 0.9789163 0.9789163
#> 2 7.0 3.461860        NA 0.9976058
#> 3 8.0 3.465780        NA 1.0193471
#>   psi_soil       kind   collar       row        fd
#> 1      5.2   interior 5.286730 0.8843193 0.8843112
#> 2      5.6 determined 5.629575        NA 0.9149394
```

Each `NA` is a refusal: `stem_curve_domain` from
`cumulative_vulnerability_integral_derivatives_at` at 7 and 8 MPa,
where `(psi/b)^c` is 4.80 and 6.87 against the series' bound of 4.61,
and `Leaf::collar_at: no operating point to place at one that is
determined` at 5.6 MPa. The forward values agree with master's to
the digits shown. Everything below explains a part of these two outputs. The
script is `whole_game.R`; both libraries were built from 4026aad and
d216a17 against odelia 0.8.0 (1e0f0f0).

## Terms

- **last knot**: `vulnerability_psi_max(b, c)`, where the root curve's
  tables stop and conductivity is down to its 1% floor; 6.8918 MPa for
  plant's TF24 root. Past it the integral table extends along its last
  knot's tangent, whose slope is that floor, until it reaches G(inf),
  where `root_vuln_integral_at` caps it: 7.39 MPa on 400 knots.
- **determined**: the existing `OperatingPointKind::Determined`, where
  the feasible collar interval `[wet bound, dry bound]` is no wider
  than `GSS_tol_abs`, so the solve holds the collar at the interval's
  midpoint and optimises only the stem. The dry bound is the continuity
  root or the root's own critical potential, whichever is wetter
  (`dry_bound_is_root_limit_` says which).

Nothing else is new as a name except
`cumulative_vulnerability_integral_limit_derivatives`, G(inf) with its
partials.

## Control flow

```
  plant's sweep, at an active scalar S
    │
    ├─► Leaf::supply_draw_at<S>                       leaf_model.hpp
    │     MultiLayerRoots::uptake_at<S>               roots.hpp
    │       closed_form_integral<S>(table G, table slope, psi, P50, c)
    │         psi ≤ last knot        G's rows at psi          (as before)
    │         past it, slope > 0     G's rows at the knot     (new)
    │         past it, slope = 0     G(inf)'s rows            (new)
    │       closed_form_curve<S>
    │         past the last knot     the table's value, no row (new)
    │
    ├─► Leaf::collar_at<K, S>                         switch on the kind
    │     interior, at a bound ...   as before
    │     Determined                                   (new)
    │       wet = bound_at(wet), dry = root_psi_crit_at or bound_at(dry)
    │       collar recorded at the solve's midpoint with rows
    │       0.5 * wet + 0.5 * dry
    │
    └─► Leaf::outputs_at → collar_coords_at
          Determined, stem at psi_crit: stem = psi_crit_at(pars), and
            no response to the collar                  (new)
          Determined, stem inside its interval: refused by name (new)

  forward, find_root_collar_psi, interval ≤ GSS_tol_abs:
    polish_bracket_bound on both bounds, then the midpoint  (changed)
```

## What changes for existing code

| | before | after |
|---|---|---|
| derivative path past the last knot | throws `stem_curve_domain` | rows of the table's tangent, then of G(inf) |
| `collar_at` at `determined` | throws | the mean of the two bounds' rows |
| `collar_coords_at` at `determined` | placed the stem by continuity | the stem at `psi_crit`; one inside its interval is refused |
| a determined collar's value | midpoint of the root-finds' bounds | midpoint of the bounds refined to collar precision |
| `leaf_solve(psi_soil = 2, PPFD = 900, leaf_specific_conductance_max = 1e-30)` | `stem_curve_domain` | solves, `psi_stem` 2.005156 |
| `uniroot()` when the bisection reaches its iteration limit | returned the bracket's midpoint | refuses, `root_find_iterations` |

The only forward values that move are determined collars. On the sweep
in the second figure (`psi_soil` 5.0 to 5.88 MPa in steps of 0.004),
90 of the 135 determined collars move, by up to 7.6e-5 MPa; no other
point moves. `test-conditions.R` reached an infeasible exit through the
1e-30 conductance; it now limits the continuity root-find to three
iterations instead (`ci_niter = 3`, code `collar_bracket`).

## Files

| file | lines | what |
|---|---|---|
| `closed_form_rows.hpp` | +10 −1 | the dry-end branches of `closed_form_integral` and `closed_form_curve` |
| `vulnerability.hpp` | +13 | `cumulative_vulnerability_integral_limit_derivatives` |
| `leaf_model.hpp` | +55 −13 | the polished bounds in `find_root_collar_psi`; `collar_at`'s `Determined` case; `collar_coords_at`'s stem |
| `uniroot.hpp` | +1 −1 | `>=` |
| `tests/cpp/test_leaf.cpp` | +215 −6 | `test_root_rows_past_the_dry_end_match_the_table`, `test_a_determined_collar_moves_with_its_bounds`, `test_a_bisection_that_spends_its_budget_is_refused` |
| `tests/cpp/test_transpose.cpp` | +50 −16 | both determined fixtures in the tangent-against-sweep identity |
| `tests/testthat/test-conditions.R` | +13 −16 | the reachable infeasible exit |
| `vignettes/derivative-surface.Rmd`, `NEWS.md`, `DESCRIPTION` | | 0.10.4 |

Read `closed_form_integral` first, ten lines with the comment that
says why the knot's rows serve the tangent. Then `collar_at`'s
`Determined` case and the block at the top of `collar_coords_at`, then
the collapsed-interval branch of `find_root_collar_psi` for the
polished bounds. The three commits follow that order and each builds.

plant pins `phylloptim (== 0.10.2)`. Taking these rows needs
`LinkingTo: phylloptim (== 0.10.4)` with odelia at 0.8.x, since 0.10.3
raised its odelia floor to 0.8.0.
