## The tangent past the last knot carries the knot's rows

Past the last knot `k` the root table returns its last knot's tangent,
`G(k) + f(k) (psi − k)`, until that reaches G(inf). Both `k` and the
tangent's slope move with the traits, and the slope moves in a way
that removes `k` from the derivative: `f(k)` is the 1% conductivity
floor for every `b` and `c`, because `k` is defined as the suction
where the floor is reached. So in a trait θ,

    d/dθ [G(k) + f(k)(psi − k)] = ∂G/∂θ(k) + f(k) dk/dθ − f(k) dk/dθ
                                = ∂G/∂θ(k)

and `closed_form_integral` evaluates the trait partials at `k` in place
of `psi`; the `psi` row stays the table's slope. Past the cap the value
is G(inf) `= b Γ(1 + 1/c)`, with `∂/∂b = Γ(1 + 1/c)` and
`∂/∂c = −b c⁻² Γ(1 + 1/c) ψ₀(1 + 1/c)`, mapped onto `root_P50` and
`root_c` by `rows_in_P50` as every other row is. The conductivity table
past `k` is clamped to its last knot, the floor, so that read has no
row at all.

![G(psi) and its root_P50 row against psi from 4 to 10 MPa, with a central difference of the table overlaid and master's refused range shaded](FIG:phylloptim-21/root_integral.png)

At plant's TF24 root on 400 knots, the row matches a central
difference of the table read (`h = 1e-5` in `root_P50`) to 4.2e-11
absolute everywhere past the knot, and to 7.2e-7 relative between 0.5
and 6.85 MPa, where the table is a fit of the closed form. The row
steps from 0.9976 to 1.0193 where the tangent meets the cap at 7.39
MPa, because the value there switches from the tangent to G(inf). The
value is continuous across that point, and the row is the derivative on
each side of it. Master refused every row from 6.8928 MPa, the first
sample past the knot.

## A determined collar moves with both its bounds

At a determined point the solve sets the collar to `(wet + dry) / 2`
and optimises the stem with the collar held. `collar_at` now records
the solved collar against two inputs, the wet bound and the dry bound,
each at weight one half. `odelia::record_with_derivatives` keeps the
recorded value the solve's and carries only the rows, so the collar is
bit for bit the forward's. The dry bound is whichever limit closed the
interval: the continuity root, through `bound_at` as at a bound
optimum, or the root's own critical potential, through
`root_psi_crit_at`, which does not move with `psi_soil`. Where the
latter closes it the row along `psi_soil` halves, since only the wet
bound moves.

The stem sits where the held-collar optimisation left it. Where that
is `psi_crit`, `collar_coords_at` places the stem at `psi_crit_at(pars)`
and gives it no response to the collar. Placing it by continuity with
the draw, as at an interior collar, keeps its value and gives it the
rows of a stem that tracks the collar, which a held collar's stem does
not do. A stem optimum inside its interval would need the curvature of
the held-collar problem, which is not taken, so it is refused by name.

![Collar suction less soil suction for the two bounds and the collar against psi_soil, and the collar's psi_soil row against a central difference of the solve, with master's refused range shaded](FIG:phylloptim-21/collar_interval.png)

The sweep is one layer, `stem_P50` 3.4287 and `root_P50` 3.4 MPa
(`psi_crit` 5.9198, the root's critical potential 5.8703), at plant's
`GSS_tol_abs` 0.1 and 400 knots, from `psi_soil` 5.0 to 5.88 MPa in
steps of 0.004. The interval is narrower than 0.1 MPa from 5.328 MPa,
and master refused all 135 determined points. The leaf shuts down from
5.868 MPa. Against a central difference of the solve (`h = 1e-6`):

| region | points | largest abs(row − difference) |
|---|---|---|
| interior | 82 | 3.1e-5 |
| determined, dry bound the continuity root | 133 | 3.5e-3 (0.38% of the row) |
| determined, dry bound the root's limit | 2 | 4.9e-4 (row 0.5005, difference 0.5000) |

The determined error is the bounds' rows being taken at the midpoint,
up to `GSS_tol_abs / 2` from either bound, and it shrinks as the
interval closes. At the default 1e-3 of `test_leaf.cpp`'s two fixtures
the largest is 7.5e-5, on the collar's `root_P50` row (0.86320 against
0.86328); profit's `root_P50` row there reads −0.82908 against
−0.82915. Taking each bound's row at the bound would cost two more
supply evaluations per determined point.

The figure also shows a step in the forward collar that this branch
does not change: where the interval falls below `GSS_tol_abs`, between
5.324 and 5.328 MPa, the collar moves from the interior optimum to the
midpoint and drops by 0.0142 MPa. The row is the derivative on each
side of it.

## Why the bounds are refined first

The two bounds come from root-finds that stop at a 1e-4 bracket, and a
determined collar is their midpoint, so it carries their stopping
error, which is piecewise constant in the inputs. A central difference
of the solve divides that error by `2h`. On the sweep above, master's
difference of the determined collar along `psi_soil` differs from the
branch's by up to 1.5e-3. `polish_bracket_bound`, which already refined
a fixed bound to collar precision, now refines both bounds of a
collapsed interval before the midpoint is taken. A refined continuity
root that passes the root's own limit hands the dry end to that limit,
as the fixed-bound path does. This is the one change to forward
values: 90 of the 135 determined collars on the sweep move, by up to
7.6e-5 MPa.

## Cost

On the forward, two calls of `polish_bracket_bound` where an interval
has collapsed and none elsewhere. On the derivative path, one
`vulnerability_psi_max` (a `pow`) per closed-form read of either root
curve. Golden outputs regenerated on Linux (`test_golden --generate`,
`--generate-optima`, `test_primitives --generate`) are byte-identical
between master and this branch for all three files; the golden grid
has no determined point.

## Tests

- `test_root_rows_past_the_dry_end_match_the_table`: uptake's rows in
  `root_P50`, `root_c` and `psi_soil` against a central difference of
  the table at three (collar, soil) points past the knot and past the
  cap.
- `test_a_determined_collar_moves_with_its_bounds`: the collar's,
  profit's and uptake's rows against differences of the solve along
  `root_P50`, `stem_P50` and `psi_soil`, with a root-limit dry bound
  and with a continuity dry bound; the named refusal.
- `test_a_bisection_that_spends_its_budget_is_refused`.
- `test_transpose` adds both determined fixtures to the
  tangent-against-sweep identity.

Linux, g++ 13.3 at `-O2`, odelia 0.8.0: `test_leaf` 3018 checks,
`test_supplied_rows` 178, `test_transpose` 154, no failures. The
branch's `test_leaf.cpp` built against master's headers fails 17 of
2964 checks, each a refusal: 9 dry-end rows, 6 determined rows, the
named refusal and the bisection. The committed golden files are bit
exact on macOS/arm64, and on Linux `test_golden` reports differences
against them (operating points up to 2.5e-14 relative; the psi_stem
optima worst at ProfitMax's `hydraulic_cost_norm`); master's Linux
output is byte-identical to this branch's, so it reports the same. The byte
comparison above is the Linux check. R
testthat on the installed package with `NOT_CRAN=true`: 1524 pass, 0
fail, 1 skip, over 11 files.
