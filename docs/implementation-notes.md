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

### P0.9 — rates recomputed when nodes are introduced

Branch `p0/introduction-rates`, commit `49b03bb0`. One line — `compute_rates()` after
`compute_environment(false)` in `Patch::introduce_new_nodes`. `environment_ptr` confirmed to be
`&environment` there on both branches, set in `reset()` and through `set_initial_state()`, so no
`scm.h` or odelia change was needed.

**It reproduces the recorded measurement digit for digit**, which is the point of re-taking it:

| max abs \|Δrate\| at an introduction | before, median | before, max | after |
|---|---|---|---|
| pre-existing cohorts | 6.661e-09 | **5.884** | **0** |
| the newborn's own slots | 2.442e-09 | 0.9943 | 0 |
| environment | 8.314e-06 | 3.101e-03 | 0 |
| pre-existing, relative | 1.119e-08 | **1.2029e+02** | 0 |

Above 1% relative at **59 of 141**, above 10% at 56, **above 100% at 51** — then 0 of 141 on all
four measures, so a further recompute changes nothing at 141/141. Offspring
`42.140173575095666` -> `42.263060914614329` (+0.2916%), 5 055 -> 5 060 steps, both reproducing the
recorded values. All 141 introduction times remain on the ODE grid. Wall clock 122.37 s -> 119.56 s,
best of two, the difference negative and inside noise: 141 extra rate evaluations against about
30 000.

**This is the phase's first intended test failure, and it was left failing.**
`test-strategy-ff16.R` goes from 0 to 3 failures, all in "offspring arrival" — FF16's offspring,
its 100th ODE time and its accepted step count all move, because the fix is family-wide:

| | before | after |
|---|---|---|
| FF16, one species | 16.88946487 | 16.88950163 |
| FF16, two species | 11.99529321 / 16.47518975 | 11.99520444 / 16.47498818 |
| K93, one species | 0.07532605164 | 0.07532614595 |

`test-strategy-ff16-reference-comparison.R` and `test-strategy-k93.R` still pass — their numbers
moved too, but inside those files' own `1e-4` and `1e-5` tolerances, which is worth knowing: the
reference comparison is not the tripwire here, the hard-coded assertions in
`test-strategy-ff16.R` are. Nothing under `tests/testthat/FF16_reference/` was touched and nothing
was re-blessed.

**One hazard reported rather than changed**, and it belongs to Phase 4 rather than here: in a mutant
run `environment_ptr` can point into `environment_history` through `set_ode_state(it, index)`, so the
added `compute_rates()` would build against the last-loaded cached environment rather than
`environment`. It does not bite now — the mutant path's introductions are followed by
`set_ode_state(it, index)`, and both mutant tests fail identically before and after — but it is the
one place where the added line's environment is not `&environment`, and the invasion task reconnects
exactly that path.

### P0.8 — the water reduction starts at the boundary node

Branch `p0/boundary-reduction`, commit `f93e72be`, `inst/include/plant/species.h` only.
`Species::consumption_rate` takes `new_node` as its bottom endpoint, as
`compute_competition` already does, reusing the one `util::trapezium` call rather than growing a
second descending loop. `size() < 2` becomes `size() == 0`, which is the empty-species case and not a
replacement guard — a species is empty before its first introduction.

| | offspring production | accepted steps |
|---|---|---|
| develop `141dc8df` | `42.140173575095666` | 5 055 |
| P0.8 | `42.474057288733817` | 5 077 |

**+0.7924% in offspring, +22 accepted steps** — larger than the 0.70% one-cohort window, as expected,
because the omission also reached `pr_estab` and so every cohort's seeded boundary density.

**The gate that pins the endpoint is worth keeping.** A one-cohort species goes from exactly `0` to
`8.9885595436215663e-04`, so the branch is gone rather than unreached. Then: place the smallest cohort
*exactly at* `height_0`, and the boundary interval has zero width, so the total must be bit-identical
before and after **iff** the added endpoint is `new_node` at `height_0`. It is —
`0.0007131905804356113` both ways, 17 digits — and moving that cohort 0.05 m off the boundary does
change the value. That distinguishes the right endpoint from merely a lower one, which a
value-goes-up check cannot.

Ordering is safe and was checked rather than assumed: `Species::compute_rates` runs every node's
rates, then `new_node.compute_initial_conditions`, which computes the boundary node's own rates, and
`Patch::compute_rates` reads `consumption_rate` after that. So the boundary node's uptake is the
current stage's.

**FF16 and K93 do not move, and the reason is not that the header is unshared.** It is shared and
instantiated for both, but `FF16_Environment::ode_size()` and K93's are **0** against TF24's 9, and
`Patch::compute_rates` accumulates inside `for (i = 0; i < ode_size(); i++)` — so the loop body never
runs and `consumption_rate` is never called. The change is family-wide in the code and TF24-only in
the numbers. `test-mutant.R`'s two errors and `test-strategy-ff16.R`'s pandoc error were shown
pre-existing by a paired run on develop, byte-identical either side.

**One prediction came out backwards, and it is recorded as measured rather than as expected.**
Cumulative root uptake over the run goes *down*, 81.2293 to 81.1801 (−0.061%), and every soil layer
ends slightly wetter. The instantaneous uptake at a fixed state goes up — that is what the two gates
show — but over a run the extra draw is not additive: billing the recruits moves the light and soil
trajectory, and the stand settles transpiring marginally less in total. Which of the two channels
dominates, fewer or smaller cohorts against drier intermediate soil suppressing later uptake, is not
chased here.

Noticed and not touched: `Species::consumption_rate_by_node_rev` and `r_heights_rev` have no callers
outside `consumption_rate`, despite the `r_` prefix implying an R accessor.

### P0.11 — one evaluation at the boundary node

Branch `p0/boundary-establishment`, commit `60c0fc27`. **Bit-identical**, which was the gate:
`42.140173575095666` at 5 055 accepted steps both ways, and `pr_estab` at the boundary node equal to
all 17 digits. So the specification's premise holds — the two evaluations really were at identical
arguments.

Each strategy gains `establishment_probability(env, double)` holding the body plus a thin
`(env, const Internals&)` entry point reading its own aux slot, which is the pattern
`net_mass_production_dt(env, vars)` already uses in these headers. The one-argument
`establishment_probability(env)` still evaluates at `height_0` and is what R reaches, so its meaning
is unchanged — checked by asserting an `Individual` set to height 5 still returns the birth-size
value. No cache, no `mutable`.

**One fewer leaf solve per stage per species, counted:** 178.433413 to 177.433413 per stage, a total
difference of 13 809 on a life-20 run, which is the stage count exactly.

**A deviation from the file allowlist, reported rather than taken silently.** `individual.h` had to
gain a six-line forwarder, because `Individual::strategy` and `::vars` are both private and `node.h`
has no other route to the stored rate. The alternative, reading `individual.aux("net_mass_production_dt")`
from `node.h`, throws for K93, which does not declare that aux name.

FF16 shares the pattern exactly and is fixed the same way in the same commit. K93 does not — its
`establishment_probability` returns `1.0` and reads no carbon budget — so it gains only the overload,
because `node.h` is shared and the call must resolve for every strategy. TF24f inherits TF24's and
needed no edit; its ordering is safe because `compute_rates` assigns the tracked potential from the
seeded state before the establishment call, which its unchanged suite confirms.

Noticed and not touched: `stochastic_species.h:72` and `stochastic_patch.h:166` reach
`establishment_probability(env)` on a fresh `new_node` whose rates have not been computed, so they
must keep recomputing — correct as it stands, but the stochastic path still pays the birth-size solve
the SCM path no longer does.

### P0.1, P0.2 — the leaf's per-solve fields re-seated

Branch `p0/leaf-purity`, three commits: `ab15cc9f` (P0.1), `399b81ab` (P0.2), `866ae40a` (the stale
soil potentials inside the derivative). `src/leaf_model.cpp` and `inst/include/plant/leaf_model.h`
only.

**P0.1 is the whole forward shift, and P0.2 and the third commit are bit-identical.**

| | offspring production | accepted steps |
|---|---|---|
| develop `141dc8df` | `42.140173575095666` | 5 055 |
| P0.1 | `42.198239148966778` | 5 065 |
| P0.2 | `42.198239148966778` | 5 065 |
| the derivative's soil potentials | `42.198239148966778` | 5 065 |

**+0.138% in offspring and +10 accepted steps.** Worth noting that this sits just *below* the
0.145% two builds of one tree differ by, so the number is attributable only because it was taken
before and after in one worktree at one set of flags — which is the whole reason the build is pinned.
P0.2 reproducing to the last bit is the independent confirmation of its zero incidence at this
driver, and it makes the fix a free correctness assertion rather than a change.

Gates, all three failing before and passing after: a seedling's deep layers read zero on a leaf that
solved a tree first; `solve(seedling); solve(tree); solve(seedling)` bit-identical; a shut-down solve
reports zero uptake and matches a fresh leaf, where develop reports the previous solve's uptake
against a fresh leaf's `NA`. No test failed and **no baseline number moved**, including
`test-strategy-tf24.R`'s reference comparison and its E-conservation test — consistent with those
being single-plant states, where there is no previous cohort to inherit from. `test-strategy-ff16.R`
carries one pre-existing environmental error, `pandoc_available()` false in this container, which is
not a number.

**TF24f does not move, for a stated mechanical reason** rather than by luck: `TF24f_Strategy::solve_leaf`
calls the derivative immediately after `evaluate_root_collar_psi`, so `prepare_collar_solve` has
already seated the same vector from the same `psi_soil_` and the added refresh recomputes bit-identical
values. All 57 assertions pass at every commit.

The third commit is larger than "refresh what it reads": the loop that seats `psi_soil_inverted_` and
`root_vuln_integral_soil_` moved out of `prepare_collar_solve` into `Leaf::refresh_soil_potentials()`,
returning the wettest layer's potential, with the operation order preserved so the forward path is
unchanged. The derivative entry point now calls it too. Before, changing the soil and calling the
derivative directly gave `-2.685285` against a refreshed `10.072843` — a relative difference of 1,
not a drift, and the same character as the value recorded in P0.1 at a different probe state. The
refreshed value is bit-identical across the builds either side of the commit, which is the direct
evidence the refactor moves nothing.

**Two things this leaves owed.** The gate ran from a scratch copy of
`scripts/leaf_state_carryover.R`'s mechanism, because that probe hardcodes the develop worktree, so
the *derivative* staleness has no committed probe — `scripts/leaf_permutation.R` covers P0.1's own
mechanism and reproduces its incidence, but nothing asserts the refreshed-against-stale property, and
its only current protection is that the TF24f suite passes. And the derivative now costs
`max_soil_layer` spline evaluations per call it did not before, which is invisible on this path but
lands twice per solve once the collar polish calls it.

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
