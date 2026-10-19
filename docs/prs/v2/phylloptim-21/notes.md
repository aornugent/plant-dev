# phylloptim-21 notes: every number and where it came from

Measured 2026-10-19, under `nice -n 19`, at most two processes.

## Builds

`scratchpad` is
`/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad`.

- odelia master 1e0f0f0 (0.8.0) into `scratchpad/v2own/lib_od80`.
- phylloptim master d216a17 (0.10.3) into `lib_ph103` and PHYLLOPTIM-18
  4026aad (0.10.4) into `lib_ph104`, each
  `R_LIBS=lib_od80 R CMD INSTALL -l lib_ph10x <worktree>`.

## Whole game and figures

`figures/phylloptim-21/leaf_rows_cpp.R` defines `compile_leaf_rows()`,
which compiles `G_rows()` and `collar_rows()` with Rcpp against the
headers of the phylloptim in a given library. `whole_game.R` prints
comment 1's outputs:

```sh
Rscript whole_game.R scratchpad/v2own/lib_ph104 scratchpad/v2own/lib_od80   # branch
Rscript whole_game.R scratchpad/v2own/lib_ph103 scratchpad/v2own/lib_od80   # master
```

`leaf_rows.R <ph lib> <od lib> <label> <prefix>` runs the sweeps; the
two builds' outputs stacked are `root_integral.csv` and
`collar_interval.csv`; `root_integral.R` and `collar_interval.R` draw
the figures from them.

Configuration: root_P50 3.4, root_c 2.680147 (plant TF24's defaults in
`tf24_strategy.h`), 400 knots (plant's `vulnerability_curve_ncontrol`
on its branches), `GSS_tol_abs` 0.1 (plant's `control.cpp` on
PLANT-95). The leaf of `collar_rows()` is `test_leaf.cpp`'s: one layer
1 m deep, root carbon 1/0.05, PPFD 900, VPD 2, ca 40, 25 C, conductance
`K_s θ / h` with θ = 0.000157, h = 5, traits as its determined fixture
with stem_P50 3.4287.

| number | value | from |
|---|---|---|
| last knot | 6.891842 MPa | `root_integral.csv`, `dry_end` |
| G(inf) | 3.46578 | `G_inf` |
| tangent meets the cap | 7.39 MPa | `root_integral.R`, extrapolated from the tangent samples |
| master's first refused sample | 6.8928 | `root_integral.csv`, master, first non-empty `refused` |
| rows refused by master over 2 to 10 MPa | 64 of 64 samples past the knot | same |
| `(psi/b)^c` at 7 and 8 MPa | 4.80, 6.87 (bound 4.605170) | `(c(7, 8) / b)^c` with b = 3.4 / log(2)^(1/2.680147) |
| abs(row − difference) past the knot | 4.2e-11 at most | branch rows, psi > 6.9 |
| relative, 0.5 to 6.85 MPa | 7.2e-7 at most | branch rows |
| row either side of the cap | 0.9976058, 1.0193471 | psi 7.35, 7.40 |
| first determined `psi_soil` | 5.328 (5.324 interior) | `collar_interval.csv` |
| determined points | 135 (133 continuity, 2 root limit) | kind and `dry == root_psi_crit` |
| interior points | 82 | |
| shutdown from | 5.868 | |
| master refused | all 135 determined | `refused` on master |
| abs(row − difference), interior | 3.1e-5 | |
| determined, continuity dry bound | 3.5e-3; 0.38% relative | |
| determined, root-limit dry bound | 4.9e-4 (0.5004851 vs 0.5) | psi_soil 5.860 |
| collar step at the switch | −0.0142 MPa | collar at 5.328 less at 5.324 |
| master's difference vs branch's, determined | 1.5e-3 at most | `fd` columns |
| collars moved vs master | 90 of 135 determined, up to 7.64e-5 MPa; 0 elsewhere | `collar` columns |
| psi_crit, root's critical potential | 5.919835, 5.870283 | `psi_crit`, `root_psi_crit` |

Whole game numbers (branch): G 3.455171 / 3.461860 / 3.465780; rows
0.9789163 / 0.9976058 / 1.0193471, equal to their differences to the
digits printed; collar 5.286730 (interior, row 0.8843193, difference
0.8843112) and 5.629575 (determined, row 0.9135894, difference
0.9149395). Master: rows at 7 and 8 MPa and the determined row `NA`,
difference at 5.6 0.9149394.

## The 1e-30 conductance

```r
leaf_solve(psi_soil = 2.0, PPFD = 900, leaf_specific_conductance_max = 1e-30)
```

0.10.3: `[phylloptim:infeasible:stem_curve_domain] Leaf hydraulics: the
cumulative xylem conductivity integral G, INVERTED ...`. 0.10.4: solves,
`psi_stem` 2.005156.

## Tests

`scratchpad/v2own/checks/run.sh` and `run2.sh`; logs beside them.

- `make all` in `tests/cpp` (g++ 13.3, `-O2`, odelia 0.8.0 headers):
  `test_leaf` 3018 checks 0 failures, `test_supplied_rows` 178,
  `test_transpose` 154. `test_golden` then fails against the committed
  (macOS/arm64) goldens: operating points up to 2.54e-14 relative, psi
  stem optima 8156 mismatches over 5184 rows, worst at ProfitMax
  `hydraulic_cost_norm` (`p18_cpp.log`).
- Golden regeneration on Linux, master and branch
  (`test_golden --generate`, `--generate-optima`,
  `test_primitives --generate`): `operating_points.tsv`,
  `psi_stem_optima.tsv`, `primitives.tsv` byte-identical
  (`golden_cmp.txt`).
- The branch's `test_leaf.cpp` built with `PHYLLOPTIM_INC` at master:
  2964 checks, 17 failures (9 dry-end, 6 determined, the named refusal,
  the bisection) (`p18_on_master.log`).
- `test_a_determined_collar_moves_with_its_bounds` printout at the
  default `GSS_tol_abs` 1e-3: root limit along root_P50, collar 0.86320148
  against 0.86327687, profit −0.82907731 against −0.82914972.
- R: `NOT_CRAN=true`, `testthat::test_dir("tests/testthat",
  load_package = "installed")` against `lib_ph104`: 11 files, 1524
  pass, 0 fail, 1 skip (`p18_testthat.log`).

## Differences from the current PR text

- "a collapsed-interval collar moves by up to 2.8e-7 MPa": true of the
  test fixtures; at plant's `GSS_tol_abs` 0.1 and 400 knots, up to
  7.6e-5 MPa.
- "that costs 9e-5 relative on the collar row": at 1e-3; at plant's 0.1
  the row is up to 3.5e-3 (0.38%) from a difference of the solve.
- "The forward caps the integral past 7.31 MPa": 7.31 on 100 knots; 7.39
  on plant's 400.
- "`(ψ/b)^c` = 4.99, 4.80 and 259": these are `test_leaf.cpp`'s points
  (7.1, 31 and 7 MPa) and hold; the whole game's points give 4.80 and
  6.87.
- "Lines: +366/−42 over 9 files": `git diff --numstat` gives +383/−58
  over 10 files (headers +79/−15, tests +278/−38).
- "R testthat ... 1494 pass, 0 fail, 3 skips": 1524 pass, 0 fail, 1
  skip with `NOT_CRAN=true` today.
- The long-drought rows (2189 cap binds, 0.56ε and 0.45ε, 9.4% of CPU,
  6066 against 6699 s) are plant measurements on phylloptim 0.9.x and
  were not re-measured; the new text does not use them.
- README.md in `docs/prs/opened` lists the base as 0.10.4; the base is
  master at 0.10.3 and the branch is 0.10.4.
