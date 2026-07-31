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
- **P0.6's establishment gate keeps its hard switch**, on the measurement in
  `scripts/establishment_gate.R`: its two arms are on one scale, so the sign test separates real
  carbon states and there is nothing to mollify. The measurement also rules out the obvious scale —
  `storage_prod_eps = 1e-4` is six times the open arm's median.
- **P0.6's respiration half is not taken**, and is left with the owner. It needs the
  parameterisation's provenance, which is not in the repository: whether `B_lf5`'s coefficient was
  fitted against a model that already netted out dark respiration. What was added is a narrower
  diagnosis of which component duplicates, and a caveat that the absolute figures on record are in
  inconsistent units.

---

## The whole phase, merged

`p0/phase-0` merges all eight items off `develop` `141dc8df`, with no conflicts — `tf24_strategy.cpp`
and `ff16_strategy.cpp` auto-merged despite three items touching each, and every change was checked
present afterwards rather than trusted. Built and gated in one session at the pinned build, 0
occurrences of `-O0` in the log.

**The composite forward shift is smaller than any single item's, and that is the number the
re-blessing needs.**

| | offspring production | accepted steps | shift |
|---|---|---|---|
| develop `141dc8df` | `42.140173575095666` | 5 055 | — |
| P0.1 alone | `42.198239148966778` | 5 065 | +0.138% |
| P0.9 alone | `42.263060914614329` | 5 060 | +0.2916% |
| P0.12 alone | `42.424434588327919` | 5 029 | +0.6746% |
| P0.8 alone | `42.474057288733817` | 5 077 | +0.7924% |
| **`p0/phase-0`** | **`42.180107697778624`** | **5 092** | **+0.0948%** |

Four individually positive shifts summing to about +1.9% compose to +0.0948%. **The reading is not
that biology cancels — it is that most of each individual figure is the adaptive controller
re-rolling.** Report 01 §2 measures 0.145% in offspring between two builds of one tree from
arithmetic association alone, so P0.1's +0.138% is *at* that scale, P0.9's is twice it, and the
composite is *below* it. What is robust is the composite and the step count; a per-item figure is
attributable only in the weaker sense that it was taken before and after in one worktree at one set
of flags. Any future item whose claimed effect is under about 0.15% in offspring needs a mechanism,
not just a pair of runs.

**The family-wide exposure is small.** At production lifetime, one species:

| | develop | `p0/phase-0` | shift |
|---|---|---|---|
| FF16 offspring | `56.279389293267506` (214 steps) | `56.281302989371063` (216 steps) | +0.0034% |
| K93 offspring | `0.0089044234001279098` (108 steps) | `0.0089044267831322674` (108 steps) | +0.000038% |

So the three `test-strategy-ff16.R` assertions that now fail do so on `testthat`'s default relative
tolerance of about 1.5e-08 against a movement of 3.4e-05, and on two exact integer step counts — not
on a large shift. `test-strategy-ff16-reference-comparison.R` still passes, because its own `1e-04`
tolerance absorbs it, which makes the hard-coded assertions the tripwire here rather than the
reference files.

**The suites on the merged tree: 1 007 assertions pass, 3 fail, and the 3 are the re-bless.**

| file | result |
|---|---|
| `test-strategy-tf24.R` 48, `test-strategy-tf24f.R` 57, `test-strategy-k93.R` 21 | pass |
| `test-canopy-methods.R` 63, `test-environment-TF24.R` 88, `test-environment.R` 21 | pass |
| `test-node.R` 74, `test-species.R` 174, `test-patch.R` 145, `test-scm.R` 89 | pass |
| `test-individual.R` 131, `test-initial-state.R` 27 | pass |
| `test-strategy-ff16-reference-comparison.R` 17 | pass |
| `test-strategy-ff16.R` | 50 pass, **3 fail in "offspring arrival"**, plus a pandoc error that is environmental |
| `test-mutant.R` | 2 errors, both the pre-existing "Run a resident first" fixture |

**No TF24 baseline moved**, despite the composite shift, because `test-strategy-tf24.R`'s assertions
are single-plant rather than whole-run — which is worth knowing before relying on that file as a
tripwire for a trajectory change. What is owed at the re-bless is three numbers in one FF16 file.

## Landed

Each entry carries the commit, the gates as run, and the forward shift.

### P0.12, P0.7 — TF24 on `CanopyShape`, and the density at the crown base

Branch `p0/canopy-shape`, five commits: `602d7481` (the member), `b04d4667` (the switch),
`b83405b1` (delete the duplicates), `973535ab` (one `eta_c`), `4ec45f6f` (P0.7's reformulation).

| | offspring production | accepted steps |
|---|---|---|
| develop `141dc8df` | `42.140173575095666` | 5 055 |
| the member added, nothing switched | `42.140173575095666` | 5 055 |
| switched to `CanopyShape` | `42.424434588327919` | 5 029 |
| duplicates deleted, `eta_c` shared | `42.424434588327919` | 5 029 |

**+0.6746% in offspring and −26 steps**, from a difference that is last-bits-only. Measured before
the switch over a production census of 15 087 (knot z, cohort height) pairs: at TF24's default
`eta = 12`, 1 144 pairs differ and **every difference is bounded by 4.440892e-16** — 2 ulp of 1.0.
`eta = 1` is exact, `eta = 2` differs at 6 pairs by 1 ulp, and the non-specialised etas are
bit-identical because both sides call `std::pow`. So the forward movement is the adaptive controller
amplifying 2 ulp into a different accepted grid, which is the mechanism report 01 §2 measures at
0.145%; this is 4.6x that.

**The speed claim was measured paired, which is the only way it could be.** Two builds cannot be
timed in one R process, so both `.so` files were kept and alternated A/B/A/B in one shell session
with sources untouched: **119.09 s against 112.05 s, 5.9% faster**, or 5.4% per step against the 26
fewer steps. Above the ~3% noise band only because the comparison is paired — the same worktree
showed 9% drift between sessions on a build that changes no hot-path arithmetic.

**`TF24_Strategy::Q` stays, and the gate asking for its deletion was wrong.** Its `eta_x` argument
exists because `src/tf24_strategy.cpp:423` calls it for the root mass distribution at
`root_depth_shape_eta = 0.2`. So `q`, `Qp` and the inlined duplicate go, `Q` remains with one `pow`
that is the root profile's, and no canopy `pow` survives. Giving the root distribution its own
`CanopyShape` would remove the last copy and is bit-identical by inspection — 0.2 dispatches to
`std::pow` either way — but it is a member for a purpose nothing specified, so it was raised rather
than taken.

**P0.7 was stopped on a real contradiction and then resolved.** `CanopyShape::q` took `(u, z)`, and
at the ground both are zero, so `h = z/u` is `0/0` and unrecoverable — meaning any treatment, guard or
reformulation, must change the signature and reach FF16's two call sites. The reformulation also moves
FF16's last bits, which that task was told not to do. Both readings were reported rather than one
being chosen: the right call, since the constraint had already been spent by P0.9 landing
family-wide, which the task could not know. Reading A was then directed, being what the plan
prescribes.

**Its arithmetic, checked rather than assumed.** `u_eta_m1 = u^(eta−1)`, `u_eta = u_eta_m1·u`, and
`2·eta·(1 − u^eta)·u^(eta−1)/h` equals `2·eta·(1 − u^eta)·u^eta/z` exactly, since
`u^eta/z = u^(eta−1)/h`. Gates on the merged tree: **`q(0, h)` finite at 35 of 35** (eta, height)
pairs, and the `eta = 1` limit is exactly `2/h` at all five heights — `5.8106596551` against
`2/0.344195`. That constant was recorded as `1/h` in two documents and is wrong; the agent's
arithmetic check found it, not a test, because nothing reads the field's slope yet.

**Below `eta = 1` the density genuinely diverges at the ground.** `0^(eta−1)` is `+inf` for
`eta < 1`, so the reformulation replaces a NaN with an infinity and is right to. Not reachable for the
canopy, where both models using it run `eta = 12`.

**The `q = −dQ/dz` identity survives the reformulation**, which was the gate that mattered most,
because that identity is what makes a later slope reduction free. Worst relative agreement by
position at `eta = 12`: **4.3e-12 at `u = 0.7`, 5.6e-11 at `u = 0.9`, 2.6e-08 at `u = 0.45`** —
and 6.4e-05 at `u = 0.2`, which is the **reference's** floor and not `q`'s. Two measurements
establish that rather than asserting it: halving `eps` makes the residual *worse*, by 6x to 20x,
which is roundoff's signature and the opposite of truncation's; and the worst point is where `Q` is
**flattest**, `Q ≈ 1 − 8e-09` at `u = 0.2` under `eta = 12`, so differencing two `Q` values near 1
loses almost every digit while `q` returns `8.94e-08` correctly. An earlier reading of this residual
attributed it to curvature near the crown top; that was wrong in both mechanism and location.

### P0.3, P0.4 — the retention inverse, and sizing by resource count

Branch `p0/soil-vectors`, commits `bb8d4496` (P0.3) and `38214b2b` (P0.4). **Both bit-identical**:
offspring `42.140173575095666` at 5 055 steps at the baseline and after each commit, which is the
strongest gate available here because it says slots 0 to 4 still do what they did.

P0.3's pre-edit round trip reproduces the recorded measurement exactly —
`theta 0.3000 -> psi 1.837887e-02 -> theta 2.456763e+00`, ratio 8.189 — and reads
`0.29999999999999999` after. The test is committed in `tests/testthat/test-environment-TF24.R` over
199 thetas at `tolerance = 1e-12`, plus the original tell as its own assertion: no recovered moisture
above saturation. It filters the region where `soil_psi_max_ = 1e3` clamps the forward curve, roughly
theta below 0.057, because the round trip cannot be an identity through a clamp.

**P0.4's gate is a count, not an argument.** A temporary probe in `Patch::compute_rates`, immediately
before `environment_ptr->compute_rates(resource_depletion)`, counted non-finite entries of the
accumulated vector on a real run: **exactly four per call, in 1 979 of 2 000 calls** under develop's
`ode_size()` sizing, and **0 of 6 000** under `n_resources()`. The 21 clean calls at the start are the
window where an empty or single-node species returns zero — which is P0.8's branch, seen from the
other side. The probe was reverted; the committed tree carries no `#ifdef`.

**The base-class default is 0, and the reasoning matters more than the value.** FF16 and K93 never
touch `Environment::vars`, so their `ode_size()` is already 0 and neither strategy calls
`set_consumption_rate`. Delegating `n_resources()` to `ode_size()` would give the same number today
and reproduce the exact conflation P0.4 exists to remove, so the base states the honest fact about an
environment that publishes no consumable resource and TF24 overrides with `soil_number_of_depths`. No
second count is stored or passed.

Not interface-visible: `n_resources()` has only C++ callers and `get_soil_number_of_depths()` already
exposes the count to R, so the yml is untouched and nothing was regenerated.

Noticed and not touched: `Patch::reset`'s `// resize to species count` comment is wrong — the reserve
is by resource count — and `compute_rates` `push_back`s into a vector only `clear()`ed at the end of
the previous call, so that `reserve` is decorative.

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
