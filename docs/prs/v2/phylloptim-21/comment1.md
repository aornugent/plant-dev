## What changes, on plant's root curve

The derivative path is C++ only; plant reaches it through
`Leaf::supply_draw_at`, `Leaf::collar_at` and `Leaf::outputs_at`
evaluated at an active scalar. `leaf_cpp.R` in plant-dev
(`docs/prs/v2/figures/phylloptim-21/`) compiles two small Rcpp
functions that make exactly those calls, using plant's TF24 root curve
(`root_P50` 3.4 MPa, `root_c` 2.680147), plant's 400-knot tables and
plant's `GSS_tol_abs` of 0.1.

The first function reads the root vulnerability integral G at a soil
water potential psi, its derivative with respect to `root_P50`, and a
central difference of the table in `root_P50`. The curve's last knot
is at 6.89 MPa, so the second and third points lie past it. On this
branch:

```r
G_derivative(psi = c(6.5, 7.0, 8.0), P50 = 3.4, c = 2.680147, resolution = 400,
             h = 1e-5)[, c("psi", "G", "deriv", "fd")]
#>   psi        G     deriv        fd
#> 1 6.5 3.455171 0.9789163 0.9789163
#> 2 7.0 3.461860 0.9976058 0.9976058
#> 3 8.0 3.465780 1.0193471 1.0193471
```

On master (0.10.3) the same calls return the same values, but the
derivative is refused past the knot:

```r
#>   psi        G     deriv        fd
#> 1 6.5 3.455171 0.9789163 0.9789163
#> 2 7.0 3.461860        NA 0.9976058
#> 3 8.0 3.465780        NA 1.0193471
```

The second function solves a one-layer leaf (`stem_P50` 3.4287) at
two soil water potentials and returns the collar water potential, its
derivative with respect to the soil water potential, and a central
difference of the solve. At 5.2 MPa the range of feasible collar
potentials is 0.13 MPa wide; at 5.6 MPa it is 0.05 MPa wide, narrower
than `GSS_tol_abs`, so the solve holds the collar at the middle of the
range.

```r
collar_derivative(psi_soil = c(5.2, 5.6), stem_P50 = 3.4287, root_P50 = 3.4,
                  GSS_tol_abs = 0.1, resolution = 400,
                  h = 1e-6)[, c("psi_soil", "kind", "collar", "deriv", "fd")]
#>   psi_soil       kind   collar     deriv        fd
#> 1      5.2   interior 5.286730 0.8843193 0.8843112
#> 2      5.6 determined 5.629575 0.9135894 0.9149395
```

On master the derivative at 5.6 MPa is `NA`, refused with
`Leaf::collar_at: no operating point to place at one that is
determined`. The script is `whole_game.R`, built against phylloptim
4026aad and master d216a17, both with odelia 0.8.0.

## What changes for existing code

The only values that change are those of a collar whose range has
closed: refining both ends of the range moves it by up to 7.6e-5 MPa
on the sweep in comment 2. The golden outputs have no such collar,
and regenerated on Linux they are byte-identical to master's. A stem
conductance of 1e-30 now solves where it was refused as
`stem_curve_domain`, so `test-conditions.R` now reaches its infeasible
case by limiting the continuity root-find to three iterations.

plant pins `phylloptim (== 0.10.2)`. Taking these derivatives needs
`LinkingTo: phylloptim (== 0.10.4)`, with odelia at 0.8 or later,
since phylloptim 0.10.3 requires odelia 0.8.0.

Read `closed_form_integral` in `closed_form_rows.hpp` first, then the
`Determined` case of `collar_at` and the start of `collar_coords_at`
in `leaf_model.hpp`, then the branch of `find_root_collar_psi` that
refines a closed range.
