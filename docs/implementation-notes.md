# Implementation notes

What was built, at what commit, against which build, and what each number moved. The plan
([`build-plan.md`](build-plan.md)) and the prerequisite list
([`tf24-correctness.md`](tf24-correctness.md)) say what to do and carry a commit tag per item; this
file is where a landed change's evidence lives. A claim enters either of those documents only as a
pointer to an entry here or to a commit, so no number is restated in two places.

Numerical changes are recorded as they land and re-blessed together at the end of the phase, so a
failing baseline assertion is expected between here and there and is not a defect.

---

## The build, pinned

Every gate in this phase is taken at one build, and a value gate that does not name its flags
measures the compiler: the same tree at `-O0` takes 5 095 accepted steps and reports offspring
`4.220134475942768e+01` against `-O2`'s 5 055 and `4.214017357509567e+01` — 0.79% and 0.145% apart,
from the adaptive controller amplifying last-bit differences in arithmetic association.

```sh
rm -f src/*.o src/*.so
R_MAKEVARS_USER=/home/user/p0/Makevars-O2 Rscript -e 'pkgbuild::compile_dll(".", debug = FALSE)'
```

with `/home/user/p0/Makevars-O2` holding `CXX20FLAGS = -O2 -DNDEBUG -g0`.

Three things about this that cost time to establish:

- **`debug = FALSE` is required.** `pkgbuild::compile_dll()` appends `-UNDEBUG -g -O0` *after* any
  user flags, so the last `-O` wins and a Makevars asking for `-O2` is silently overridden.
- **R's make does not track header dependencies.** The strategy and environment core is
  header-inline, so an edit under `inst/include/plant/` changes no `.cpp` timestamp and will not be
  compiled in. Deleting the objects first is not hygiene, it is correctness.
- **A full build is about 95 s** on four cores, which is what makes per-task worktrees affordable.
  The 25 minutes an earlier note records is not this machine.

Absolute times belong to the machine and only same-session ratios transfer: the same tree at `-O2`
has run a production lifetime in 89.9 s, 102.9 s and 86.1 s, every one reproducing the same
offspring value and the same step count.

## The reference forward run

```r
library(odelia); pkgload::load_all(<tree>)
p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- 105.32           # on the base parameters, before add_strategies
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
scm <- run_scm(p, Environment("TF24"), Control(), collect = FALSE, refine_schedule = FALSE)
```

One species, five soil layers, the default driver. develop `141dc8df` gives offspring
`42.14017357509567` at 5 055 accepted steps. `max_patch_lifetime` is set before `add_strategies`
because that call builds the node schedule.

## Where the work lands

Phase 0 is branched from plant **`origin/develop` (`141dc8df`)**, which is the baseline the plan is
written against, and not from the submodule's checked-out `26c49c76`. That commit is the earlier AD
branch — 108 files and +7 273/−5 042 against develop — and the plan treats it as reference to be
taken from selectively rather than as a base: none of the names it contributes exists at the
baseline, so all of the engine work is new code written against a design. `26c49c76` remains on the
fork as `claude/odelia-ad-tape-reverse-496fuf`, so nothing is lost by moving the superproject's
pointer onto a develop-based branch.

One worktree per task, each built independently, so a task's before-and-after numbers are taken in
one session on one tree:

| branch | items |
|---|---|
| `p0/leaf-purity` | P0.1, P0.2 |
| `p0/soil-vectors` | P0.3, P0.4 |
| `p0/leaf-permutation` | P0.10's probe |
| `p0/switch-inventory` | P0.5's probes |
| `p0/canopy-shape` | P0.7, P0.12 |
| `p0/boundary-reduction` | P0.8 |
| `p0/introduction-rates` | P0.9 |
| `p0/boundary-establishment` | P0.11 |

## Decisions taken during implementation

Recorded here because each closes a choice the plan left open, and the plan's own text is not
edited to track them.

- **P0.12 adopts `CanopyShape`** rather than keeping `pow` with a `u <= 0` guard alone. The
  bit-identical route was the alternative; the shift is accepted and re-blessed with the rest.
- **P0.4 sizes by an explicit `n_resources()`** on `Environment` rather than by shrinking the
  vector at the call site, so the count has one source of truth.

---

## Landed

Each entry carries the commit, the gates as run, and the forward shift.

### P0.10 — the shared leaf's purity, executed

`scripts/leaf_permutation.R`, commit `3b34dcf`. Probe only; no model code changed, so no shift.

A census of 10 153 production `(height, psi_soil, radiation)` states solved on one `Leaf` in six
orders, with eleven outputs compared per state. **The harness check passes: it reproduces both
published incidences to the digit, by two independent routes** — 3 430 of 10 153 (33.78%) records
have `max_soil_layer < 5`, and 3 430 states' outputs move under reordering; 2 612 (25.73%) leave
three layers of five, and 2 612 is also the `cons3` column of the worst permutation. The 33.78% is
therefore a count of states whose *outputs* changed, not a geometry table read off the rooting depth.

**Only P0.1's carrier is reachable.** `soil_consumption_` layers 3, 4 and 5 move. Layers 1 and 2
never do, and `profit_`, `E_up_`, `transpiration_`, `opt_psi_stem_`, `root_collar_psi_` and
`stom_cond_CO2_` are bit-identical at all 10 153 states in all five permutations. So no carrier
becomes a P0 row of its own, and the cohort is the unit report 01 §5 says it is once P0.1 lands.

**Exposure is not contamination, and the gap is worth keeping.** On the production order alone only
**743 records (7.32%)** hold a nonzero value in an unwritten layer, and 272 (2.68%) hold three
— the rest of the 33.78% is the early run, where nothing deep-rooted enough to write layers 3 to 5
has solved yet, so the inherited value is still the constructor's zero. `shortest first`, the one
order in which every shallow state precedes every deep one, also reports 743. **A single order
cannot measure this**: it separates 743 from 3 430 only by reordering, which is the argument for
this probe's existence rather than a re-run.

Two of the four enumerated carriers stay unexecuted, and that is a limit rather than a pass.
`photo_temp_cached_`'s key `(leaf_temp, atm_o2_kpa)` is constant over a run, so no reordering of
these states can move it — a census varying leaf temperature or O2 is needed, and both parameters it
caches are differentiation targets. `psi_soil_cache_` lives on the environment rather than the leaf
and is not read on this path.

Census degeneracies, both stated in the probe's header: `psi_soil` comes from recorded soil moisture
at the 142 output times rather than per stage, and radiation is reconstructed with linear
interpolation where the run evaluates a spline. Neither touches the permutation comparison, since
both enter every order equally.

### P0.5 — the switch inventory, measured

`scripts/demographic_switches.R` with `/home/user/p0/p0.5-instrumentation.patch`, commit `3b34dcf`.
Counters behind `PLANT_SWITCH_PROBE`; the patch is not committed to the model. Rows integrated into
`tf24-correctness.md` P0.5.

**Three results correct what was recorded**, and each was checked against the code rather than taken
from the report:

- **`node.h:144-150` is dead: 0 of 3 758 283 calls.** The guard tests
  `!is_finite(survival_individual)`, and `exp(-mortality)` underflows to exactly `0.0`, which is
  finite. Only a NaN mortality could fire it. The zeroing the row was credited with is real — 327 of
  10 153 records (3.22%), 6 nodes at every output time from `t = 7` — but it happens through the
  underflow one line above, so the live severance is the `exp` and not the branch.
- **`node.h:177`'s closed arm is never taken**: `g > 0` on all 35 133 calls, minimum 0.0953 m/yr. The
  `-Inf` that reaches the guard below comes from the numerator.
- **The root vulnerability domain edge is the tightest zero in the inventory, at 1.15x.** Largest
  magnitude presented to the splines 5.919880 MPa against a last knot at 6.822923, 0 of
  1 162 082 517 layer evaluations beyond it. Every other zero here is comfortable — 27x
  `GSS_tol_abs` on the shutdown exits, 15.6x on the soil positivity guard, five times the stand's
  optical depth on the light floor. And the near-edge magnitude is a collar root-find *iterate*
  rather than a state: `|opt_root_psi|` peaks at 2.36 MPa, so an output-time census overstates the
  margin by 2.5x. The sign-error path is narrower than the summary implied — `root_vuln_from_psi`,
  the spline that extrapolates negative, is read only in the equal-potentials branch (1.30% of
  evaluations), which already carries an `f_ri <= 0` stop, while the general branch (98.70%) reads
  the cumulative-integral spline whose linear extrapolation is positive. So beyond the edge that
  branch gives a wrong conductance rather than a wrong-sign flux, and what is owed is a domain
  assertion rather than a second sign guard.

**`species.h:220` is the row with no scale at all.** `f_h1 > 0` decides the boundary node's
trapezium arm at values down to **2.714503e-11**, on 74 060 of 3 075 900 field queries (2.41%). The
term it switches on does not vanish with `f_h1`, because `f_h0` is the boundary node's own
competition and does not go with it. Against `storage_prod_eps = 1e-4` sized against a median `|P|`
of 7.3e-2, this construct has no scale — it is a discontinuity in the resident state located where
the comparison is deciding on rounding.

`mortality_dt`'s `is_finite` guard is the largest live severance found: 371 702 of 7 516 566 calls
(4.95%) return an exact `0.0`. 327 records hold `mortality = Inf` outright, so the set is not near a
threshold a mollifier could smooth.

**One denominator to read carefully.** `compute_initial_conditions` runs **35 133 times against 141
introductions** — once per species per stage, sitting beside 35 274 `compute_environment` calls. So
the boundary node is re-evaluated every stage, which is the same fact P0.11 removes a duplicate leaf
solve from, and any figure over that denominator is per stage rather than per introduction.
