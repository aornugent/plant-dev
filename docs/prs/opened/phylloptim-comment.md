### Where plant meets these cases
- **The root curve past its dry end.** In a long drought, Runge–Kutta stages inside accepted steps read the root integral past its last knot, though no accepted state passes 5.17 MPa. The forward caps the integral past 7.31 MPa (the cap binds 2189 times on one 40-year run at tolerance 1e-4); the derivative path had no cap and refused past the curve's P99, 6.89 MPa. The reverse sweep evaluates the same stage and refuses.
- **A collapsed collar interval.** At tolerance 3e-4 a stage reaches one, and every long-drought record's gradient was refused.
- **On 0.10.3,** this branch's `test_leaf.cpp` compiled against master's headers fails 17 checks, each a refusal: 9 dry-end rows (`(ψ/b)^c` = 4.99, 4.80 and 259 against the domain's 4.61), 6 collapsed-interval rows, the stem optimum's named refusal, and the bisection limit.

### What changes
- *Dry end* (`closed_form_rows.hpp`, `vulnerability.hpp`): past `vulnerability_psi_max` the trait rows are G's at the last knot on the tangent (the tangent's slope is f there, so the knot's own movement cancels), and G(inf)'s past the cap. The conductivity read has no row: there the curve is the floor for every trait.
- *Collapsed interval* (`leaf_model.hpp`): `collar_at` records the collar against the wet bound's row and the dry bound's (the continuity root or the root limit, whichever closed the interval), at weight 1/2 each, so the value stays the solve's. `collar_coords_at` places the stem at `psi_crit_at(pars)` with zero response to the collar. Placed by continuity instead, the stem kept its value but took the wrong rows: profit's row along `root_P50` read 0.053 where a difference of the solve gives −0.83.
- *Refined bounds:* the two bounds come from root-finds that stop at 1e-4. Left there, a central difference of the solve along `root_P50` read 0.014 against a row of −1.6e-6; refined, it reads −1.5e-6. Refinement runs only where the interval has collapsed.
- *Bisection limit:* boost's `bisect` reports the iterations it used and never more than the limit, so `it > max_iterations` could not fire on the Medlyn ci solve.

### Measured
ε below is a tenth of each quantity's spread across eight daily-weather seeds of one climate (0.025 in ln J).

| | before | after |
|---|---|---|
| long-drought gradients at tolerance 1e-4, two records | refused | run; worst quantity 0.56ε and 0.45ε from a 3e-5 reference |
| long-drought gradients at tolerance 3e-4 | every record refused | every record runs with finite gradients; forward values unchanged to the bit |
| what tolerance 3e-4 then saves plant's schedule search | — | 9.4% of CPU (6066 against 6699 s over five cases) |
| profit's row along `root_P50`, collapsed interval at the root limit | 0.053 (stem placed by continuity) | −0.8291; central difference of the solve −0.8291 |

The first three rows were measured with phylloptim 0.9.x on plant's development stack; this PR carries the same rows onto 0.10, where they were re-checked at the leaf level (the 17 refusals above).

### Cost
- Lines: +366/−42 over 9 files: headers +79/−15, tests +265/−22, NEWS, DESCRIPTION, the vignette.
- Runtime: nothing on the forward. On the derivative path, one `pow` per closed-form root-integral read to locate the dry end; two extra root-finds where an interval has collapsed.
- Values: the golden grid has no collapsed interval; the operating-point, psi_stem-optima and primitives outputs regenerated on Linux are byte-identical to master's. A collapsed-interval collar moves by up to 2.8e-7 MPa; a stem conductance of 1e-30 now solves where it was refused as `stem_curve_domain`, so `test_infeasible_is_a_distinct_failure` now limits the continuity root-find instead (`ci_niter = 3`).

### Tests
- `test_leaf`: the dry-end rows against the table's central difference at three (collar, soil) points; the collapsed interval's collar, profit and uptake rows against differences of the solve along `root_P50`, `stem_P50` and `psi_soil`, with a root-limit dry bound and with a continuity dry bound placed where the unrefined bound sat furthest from its root; the named refusal; a bisection that reaches its limit. `test_transpose` adds both collapsed-interval fixtures to the tangent-against-sweep identity.
- C++ suite on Linux against odelia 0.8.0: test_leaf 3018 checks, test_supplied_rows 178, test_transpose 154, 0 failures; golden and primitives pass.
- R testthat on the installed package: 1494 pass, 0 fail, 3 skips (CRAN and macOS-only).
- plant develop (bd09645d) against 0.10.4, phylloptim pin edited locally: `test-strategy-tf24.R` 80 pass, `test-strategy-tf24f.R` 58, the FF16 bit-identity checks 72; all other files 5264 pass, 0 fail, 11 skips. These show plant builds and its TF24 numbers hold, not that its tests reach the new rows.

### For review
1. `collar_at`'s collapsed case takes both bound rows at the midpoint, up to 5e-4 MPa from either bound; that costs 9e-5 relative on the collar row. Taking them at the bounds would need two more supply evaluations.
2. The refined continuity root is capped at the root's own limit, which then sets the dry bound, as on the fixed-bound path.

### For plant
plant pins `phylloptim (== 0.10.2)`. Taking these rows needs `LinkingTo: phylloptim (== 0.10.4)` with odelia at 0.8.x, since 0.10.3 raised its odelia floor to 0.8.0.

---
_Generated by [Claude Code](https://claude.ai/code)_
