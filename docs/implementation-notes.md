# Implementation notes

What was built, at what commit, against which build, and what each number moved. The plan
([`build-plan.md`](build-plan.md)) and the prerequisite list
([`tf24-correctness.md`](tf24-correctness.md)) say what to do and carry a commit tag per item; this
file is where a landed change's evidence lives. A claim enters either of those documents only as a
pointer to an entry here or to a commit, so no number is restated in two places.

Numerical changes are recorded as they land and re-blessed together at the end of the phase, so a
failing baseline assertion is expected between here and there and is not a defect.


## The standing lessons, and where their evidence is

This file is append-only and long because it is the one home for a number: nothing else
restates a measurement, so nothing else can disagree with one. But most of it is evidence for
work that has landed, which a reader needs only when auditing a past claim. **These are the
entries that change how the next piece of work is done.** One line each, pointing at the section
that carries the measurement.

*Building and measuring*

- `pkgbuild::compile_dll()` appends `-O0` after your flags, so pass `debug = FALSE` and check a
  compile line ends at `-O2`. The same tree at `-O0` differs by 0.145% in offspring. — *The build, pinned*
- `rm -f src/*.o src/*.so` before every build: R's make does not track header dependencies and
  the core is header-inline, so a header edit otherwise fails to compile in. — *The build, pinned*
- Absolute times belong to the machine; only same-session ratios transfer. — *The build, pinned*
- **A mid-write `.so` loads and returns plausible wrong numbers.** Verify in a worktree nothing
  else is building in. — *A mid-write `.so`*
- **An install can silently not take.** Verify by grepping the installed header, never the log. — *Still owed at the close of this phase*
- A bare `testthat::test_file` gives no package namespace and can report `FAIL 0 | PASS 0` at
  **exit 0**. Use `test_dir(dir, package =, load_package = "installed")`. — *A stated gate command*
- A plant base paired with the wrong odelia bit three times in one phase; confirm the pairing
  compiles before sending work. — *A base paired with the wrong odelia*
- Gate cost depends on how many packets are running: 90 s idle, about 7 minutes under a wave. — *The cost of a gate*
- **Ranking configurations at a short lifetime does not predict which is hardest at production.** — *five spikes*
- A composite forward-value change below about 0.15% in offspring needs a mechanism, not a
  before-and-after pair. — *The whole phase, merged*

*Getting a derivative wrong*

- **Exactly zero is this design's worst failure mode**, because it reads as an answer. Thirteen
  leaf parameters and eleven registered-but-unread ones each produce one. — *Thirteen registered parameters*, *What the audit fixed*
- Register a tape's inputs **before** `newRecording()`, or the adjoints are silently zero. — *Registering a tape's inputs*
- Never a deduced return type on anything returning an active value. A grep found three `-> double`
  lambdas that no `double` build could ever have caught. — *A grep found three lambdas*
- `fl(fl(t + h) − t) ≠ h`: a step size is not recoverable by differencing recorded times. — *Two items Phase 1 gained*
- **The stage is not a pure function of `(y, t)`** — it is not even idempotent, differing at 92 of
  753 components when `derivs` is called twice. — *The trajectory store*, *The spikes*
- Two like-typed positional arguments of unrelated meaning shipped a regression once, silently. — *A two-argument signature*

*Reading this corpus*

- **A gate recorded here is not necessarily a gate in the tree.** One `static_assert` was credited
  to a packet and had never landed. — *Corrections to what was recorded here*
- Severity, and sometimes sign, is probe-dependent: one defect read as `1e-23` on one probe and
  `+0.28%` on another. — *`reset()` restores the soil state*

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
- **P0.6's establishment gate was recorded as decided and is not.** `scripts/establishment_gate.R`
  measured the closed arm against the open arm's median and read the two as one scale; the switch
  census measured the same construct's smallest magnitude and read it as a numerical zero. Both are
  properties of one distribution spanning four to five orders, and `tf24-correctness.md` P0.6 now
  states it that way. The decision is the owner's and open.
- **The crown density's ground limit is a branch, not a reformulation.** The rewrite over
  `u^(eta-1)` reached the same value but needed a second chain family and moved two models this phase
  was not changing. Chains supply values, not derivatives, so they were never the route to a valid
  gradient.
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
| `p0/phase-0`, first assembly | `42.180107697778624` | 5 092 | +0.0948% |
| `p0/phase-0`, with the density rewritten | `42.383720683840139` | 5 067 | +0.5779% |
| **`p0/phase-0`** | **`42.176246845059751`** | **5 105** | **+0.0856%** |

**Three assemblies of the same eight fixes gave +0.0948%, +0.5779% and +0.0856%.** The middle one
rewrote the crown density over `u^(eta-1)` and derived `u^eta` from it, which rounds differently; the
last takes the density's ground limit by a branch and leaves develop's arithmetic alone. No equation
differs between them. **That is the clearest evidence here for how little a composite figure means on
its own** — rounding choices with no modelling content moved offspring further than re-seating the
leaf's uptake did, and in both directions.

**The final assembly is also the smallest change.** `canopy_shape.h` is 17 insertions and 6 deletions
against develop, against 61 and 57 for the middle one. The rewrite had needed a second family of
multiplication chains to supply `u^(eta-1)`, and those chains are a value optimisation: a chain
carries no exponent term, so its derivative with respect to the exponent is structurally absent
rather than merely imprecise. Chains are what a gradient path routes *around*, so building more of
them was solving a problem this phase does not have — Phase 0 has no active scalar at all. What the
density needed was one branch at the crown base.

Four individually positive shifts summing to about +1.9% compose to +0.0856%. **The reading is not
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
| FF16 offspring | `56.279389293267506` (214 steps) | `56.281303050101073` (216 steps) | +0.0034% |
| K93 offspring | `0.0089044234001279098` (108 steps) | `0.0089044267831322674` (108 steps) | +0.000038% |

**Both move only through the introduction fix now**, because develop's shared canopy arithmetic is
untouched. Under the middle assembly they also moved through the profile, which was avoidable
exposure on two models this phase was not meant to change.

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

**A two-argument signature of one type is its own hazard, and it bit once.** `CanopyShape::q` takes
`(z_over_height, z)` — two `double`s whose meanings are unrelated, the second being divided by. The
density rewrite had changed the second to a reciprocal height; reverting the header left FF16's two
call sites passing the old meaning, which compiled silently and sent FF16's offspring to exactly
zero. What caught it was the FF16 whole-lifetime check, which exists only because P0.9 is
family-wide: all three TF24 gates passed, because TF24 reaches the profile through `q_from_height`
and never the raw two-argument form. This is the same class as the fraction-against-position
distinction the design already guards — a meaning the type system cannot hold — and it is now
measured rather than anticipated.

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
pairs, **bitwise equal to `2/h` at all five heights** at `eta = 1` (`5.810659655137` at
`height_0`), and exactly zero at every higher exponent. That constant was recorded as `1/h` in two documents and is wrong; the agent's
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

---

# Phase 1

Nothing in Phase 1 computes a gradient. Its product is that the model *can* carry an active
scalar, that the plumbing no longer names `double`, and that a run's trajectory is stored.

## Ground truth, re-measured at the start of the phase

Reference forward run, plant `7b05b55e`, the pinned build, 0 occurrences of `-O0` in the log:

    offspring 42.176246845059751    5 105 accepted steps

Reproduces the figure the phase is planned against. Re-taken a second time later in an
isolated worktree, for the reason under *A mid-write `.so`* below.

odelia suite at `854a8e18`, installed and with the package attached: **257 pass, 0 fail, 0
error, 2 skip.** Both skips are `test-rodas.R`, `deSolve` being absent in this container.

Legacy typedef occurrences in plant: **45**, not the plan's 26 — that is a count of
signatures, and most are declared in-class and defined out of it.

## The odelia surface

One integration branch off `854a8e18`. Each merge was checked by reading the merged tree for
every change rather than trusting the auto-merge, then built once and gated.

| tree | pass | fail |
|---|---|---|
| `854a8e18` | 257 | 0 |
| the concept and the range helpers | 264 | 0 |
| `vector_jacobian_product` | 268 | 0 |
| `step_adjoint` | 275 | 0 |
| `implicit_value` and the interpolant | 291 | 0 |
| the typedef deletion, step sizes, the forward-derivative helper | **320** | **0** |

320 is exactly 264 + 4 + 11 + 27 + 7 + 7, so no packet's tests were lost or double-counted
across the merges, and nothing that passed before fails.

What each item is gated on, since a suite count says only that nothing broke:

- **`vector_jacobian_product`** against a central finite difference of the same block, and
  the recording size identical whether one output adjoint is seeded or three.
- **`step_adjoint`** against a finite difference of one step on the Lorenz system: worst
  relative disagreement `2.639e-11` at `eps = 1e-4`, degrading to `1.957e-07` at `1e-7` —
  roundoff dominating, which is the expected signature and the reason the number is quoted
  with its epsilon. `lambda_out` was deliberately not a unit vector, so the gate fails if the
  transpose is dropped.
- **`implicit_value`'s** IFT denominator measured rather than changed: `2.627e-06`,
  `2.628e-08`, `2.617e-10` at verifying `eps` of `1e-3`, `1e-4`, `1e-5`. Clean `eps²` decay
  over two decades places the residual in the *verifying* difference, so the node's own error
  is below `2.6e-10` and the denominator stays. Agrees with report 02 §7.2 by a different
  route.
- **The interpolant's `set_nodes`/`set_data` split** reproducing the all-at-once build
  **bitwise**, including the load-bearing case: a second `set_data` reusing the layout the
  first wrote. And the active-position read against a difference in the query position,
  `2.956e-10` on uniform knots and `6.209e-09` on irregular ones, with an explicit assertion
  that the adjoint is **not** zero — the failure the graft exists to prevent.
- **`to_passive`** keeps `ode_util.hpp` free of XAD by resolving `value(x)` through
  argument-dependent lookup, where the earlier branch added the include and gave that gate
  up. It also recurses, so a nested `FReal<AReal<double>>` strips to `double` where a single
  `xad::value` stops one layer short.
- **The forward-derivative helper** empties `grep -r 'xad::' plant/inst plant/src` (exit 1,
  from five lines), with plant bit-identical and `A_prime`/`C_prime` equal to the
  hand-written values to the last bit.

## plant's plumbing, at `S = double`

45 occurrences to 0 across the nine headers, `value_type` added to the elements, and the
missing `#include <plant/individual.h>` added to `node.h`. **Bit-identical at every commit**
— `42.176246845059751` at 5 105 — verified independently in a detached worktree at each
commit SHA. Fourteen suites unchanged.

## What the plan did not predict

**Constraining the range helpers breaks plant one step earlier than deleting the typedefs
does.** The plan records that the typedefs cannot go until plant stops naming them. It does
not record that adding `requires OdeElement<...>` to the helpers breaks plant on its own,
with the typedefs still present: `OdeElement` requires `typename E::value_type` and plant's
elements declared none. **56 occurrences of `no type named 'value_type'`**, in `Node`,
`Species`, `StochasticNode` and `StochasticSpecies`. So the ordering constraint is that
`value_type` must land on the elements before the helpers may be constrained. Found by a
packet's own baseline, which stopped without making an edit and reported the compiler output.
Two consequences: the concept commit is not independently gateable against plant, and the
plumbing sweep's bit-identity gate necessarily spans an odelia change too, because no build
exists in which base plant and the constrained helpers coexist.

**`OdeElement` over-requires, and the plan's own text says so.** It demands `ode_aux` of
every element; `StochasticSpecies` has none and is never walked by the `ode_aux` helper. The
plan intends the concept to constrain "the iterator type and nothing else — a missing member
already reports itself". As written it requires presence. Taken here: `SpeciesBase` gains a
four-line `ode_aux` in the form of the `ode_state`/`ode_rates` above it, numerically inert,
with all three stochastic suites unchanged. **Owed:** constrain each helper on the member it
calls, which would also drop the `value_type` requirement, since each helper already has its
iterator deduced from the caller. Not taken, because it would put two landed, gated commits
back in flight for a change with no numerical content. Its tax, stated so it is not
rediscovered: every future element must implement all four members even if one helper walks
it.

**The phase's one sanctioned numerical shift moves no assertion.** The plan singles out the
environment becoming an aux element as the one non-bit-identical item and asks it to state in
advance which assertions move. Predicted in writing, then measured, and the two agreed on
every row: `TF24_Environment::aux_size()` is 5, `Patch<TF24,TF24_Env>$ode_aux` widens from
`11·n` to `11·n + 5` at 0, 1 and 2 nodes, FF16 and K93 unchanged at `3·n` and `2·n`, and
offspring and steps unmoved. Nothing reads the environment's aux — `grep -rn 'ode_aux'
tests/testthat/` is empty and no environment declares it in the yml — so nothing was
regenerated and nothing re-blessed. **So the whole of Phase 1 is bit-identical**, which is
stronger than planned. The consequence is that the publication landed unguarded, so it now
carries a test asserting the five slots sum to the soil's own cumulative-uptake accumulator
(`0.46671037559317002`, equal to 17 digits) and that the deepest layer is **negative** —
uptake is signed. A width assertion alone would pass over five zeros, which is the defect
class this work has been removing elsewhere.

**The stage-state rebuild was not bit-identical to the step it rebuilds.** Caught in review,
not by a gate. `step()` writes each stage as `y + h*(b₁k₁ + b₂k₂ + …)`; the first
`step_adjoint` accumulated `s += h*bₘkₘ` term by term. Same value to rounding, different in
the last bits from stage 3 on. Invisible to a finite-difference gate at `2.6e-11`, and it
matters because the rebuild *is* the linearisation point and a later task will want a reverse
traversal to reproduce the forward pass exactly. Fixed to `step()`'s own association and gated
on **bitwise** equality of all six stage states, observed through a System that records the
state it is handed rather than by editing `step()`. The gate was shown to bite: restoring the
old arithmetic fails stages 5 and 6. Its limit, reported rather than hidden — stages 3 and 4
land on the same double at the chosen state, so two of the four non-trivial stages are
exercised.

**Registering a tape's inputs after `newRecording()` gives silently zero adjoints.** Cost one
packet its first attempt. `registerInputs` first, then `newRecording()`. Worth recording
because it is a silent wrong-gradient trap and because a second packet independently used the
correct order, so two arrived at it from opposite directions.

**A stated gate command can measure the harness rather than the tree.** A bare
`testthat::test_file()` or `test_dir()` gives the tests no package namespace, so the odelia
helper's internals are out of scope. Depending on the file this reports spurious errors — 9 of
them, and 28 at the baseline — or, worse, `FAIL 0 | PASS 0` at **exit status 0**, which is a
false pass. Three packets hit it independently. The namespace-bearing form is
`testthat::test_dir(dir, package = "odelia", load_package = "installed")`.

**A mid-write `.so` loads, and returns plausible wrong numbers.** Two concurrent builds in one
worktree left `src/*.so` half-written, and loading it gave **`offspring 42.366121223872653` at
5 042 steps** against the true `42.176246845059751` at 5 105 — a shift with the size and
character of a real result. Hit twice, both times because the orchestrator ran a verification
build in a worktree where an agent was still active. The plan's rule is one worktree per
packet; what this adds is that **the orchestrator's own verification needs its own worktree** —
a detached checkout at the commit SHA. Standing rule: if a number moves unexpectedly,
`rm -f src/*.o src/*.so`, rebuild clean, and re-measure before believing or reporting it.

## Two items Phase 1 gained, both forced by a gate failing honestly

The trajectory store's gate — the replayed final state bit-identical to the forward run —
could not be met, for two independent reasons, and the packet stopped rather than weaken it.

**The plan contradicts itself on what a trajectory record is.** P1.4 settles the record as
`{ double time; std::vector<double> state; }`; §2.8 says the solver records `(t, h, y)`.
`r_ode_times()` carries `t` alone, and the step size is **not recoverable from it**: the
stepper advances `time += step_size` and records `t_i = fl(t_{i-1} + h_i)`, while a replay
recovers `time_max - time`. `fl(fl(t + h) − t)` is not `h` — the addition rounds to `ulp(t)`
and the subtraction cannot recover the discarded bits. At `t ≈ 100`, `ulp(t) ≈ 1.4e-14`
against `h ≈ 0.02` whose `ulp(h) ≈ 3.5e-18`. Measured: replaying the **exact** recorded grid
gives offspring `42.235505201883193` against `42.176246845059751` — 0.14%, the same order and
the same mechanism as this tree's `-O0`/`-O2` gap; and one interior grid time changed by one
ulp perturbs **1 051 of 1 137** state components.

Resolved as a design decision: **the record carries the step size, and odelia records it.**
The decisive reason is not the gate but the consumer — the reverse pass rebuilds each step's
six stage states by re-running the step, and cannot re-run a step without its size. Having
just made that rebuild bit-exact, feeding it an `h` wrong in its last bits discards what that
cost. And "no separate times vector" forbids a *parallel* array that can drift from the
states; a step size stored beside its own state cannot disagree with it. Landed: the solver
records `(time reached, size taken)` as one container of pairs, so the length invariant holds
by construction; the initial time's size is NaN, which the step-size-driven replay *requires*
as its first element, as the analogue of the existing "first time equals the current time"
check. **Gated bitwise:** a replay over the recorded step sizes reproduces the adaptive run in
all components, and the same trajectory through the time-driven replay differs in 3 of 3,
worst `2.92388e-12`.

**`reset()` leaves the previous run's soil in the environment.** A forward-model defect with
no AD in it. `Patch::reset()` calls `environment.clear()`, which calls `clear_environment()`,
which for TF24 is `light_availability.clear();` and never touches `vars.states` — the five
soil moisture states and the four cumulative-flux accumulators. Measured: after a production
run, `reset()` leaves `ode_state` bitwise identical to the final state, soil at `3.106059e-01`
where a fresh run starts at `0.214`, and a second `run()` reports offspring
`6.6462981636817595e-23` against `42.176246845059751`. **It is reachable:** `refine_schedule()`
calls `run()` in a loop and `run()` begins with `reset()`, so every refinement iteration after
the first computes its error signal against a run that started from depleted soil, and the
schedule is chosen on that. `run_scm`'s default is `refine_schedule = FALSE`, which is why
nothing measured in this project has exercised it, but it is the documented replacement for
the former `build_schedule`. TF24-only in effect and family-wide in the code, since
`FF16_Environment::ode_size()` and K93's are 0 against TF24's 9. It belongs in
`tf24-correctness.md` as a prerequisite in its own right.

## Owed

- Constrain each range helper on the member it calls, instead of one `OdeElement` requiring
  all four.
- `vector_jacobian_product` constructs a tape per call. The caller-owned adjoint buffer exists
  because the primitive is called of order 3.9 M times; a whole `Tape` per call is a larger
  allocation than the vector that avoids. Correctness is unaffected and Phase 1 computes no
  gradient, so this is recorded rather than changed — the first thing to measure when the
  sweep's cost is taken.
- `step_adjoint` re-records a `Replayable` System's stages, because it refills `k1..k6` by
  calling `step()`, which calls `record_stage()`. Compiles away for a non-`Replayable` System,
  which is the tested path. Live the moment anything on plant's side becomes `Replayable`.
- `step_adjoint` guards on `has_rebind_from`, a SFINAE detection struct, where the style rules
  ask for a concept. It reused the existing struct rather than writing a parallel one, which
  was right inside its allowlist; the struct is owed a conversion now that the codebase is
  C++20.
- `recorded_steps()` returns times, and now reads like it returns step sizes.
- `Solver::step_sizes()` and the step-size-driven replay are C++-only; no R bindings.
- The `implicit_value` measurement over the eight parameters `height_seed` carries. Not
  reachable from an odelia packet — the primitive was measured on a scalar equation instead,
  which establishes that the probe scale is not limiting at that conditioning and not at
  `height_seed`'s.

## TF24 templated

Five code commits plus the documentation commit, on the plumbing branch. **Bit-identical at
every commit** — `offspring 42.176246845059751` at 5 105 — and re-verified independently at
the branch tip in a detached worktree, 0 occurrences of `-O0`. Fifteen suites unchanged,
including the family tripwire: `test-strategy-ff16.R`'s three "offspring arrival" failures and
its `pandoc_available()` error identical **character for character** before and after, not
merely equal in count. FF16 and K93 whole-lifetime runs unchanged.

`Control`, `ExtrinsicDrivers` and `Leaf` stay `double` by design. `src/tf24_strategy.cpp` and
`src/tf24f_strategy.cpp` are deleted, their definitions moving into the headers as template
definitions; no dead files.

**The `pow` split landed at both sites.** On `double` the multiplication chains; on an active
`S`, `std::pow` under `if constexpr`, guarded by `to_passive(u) <= 0` because the `eta`
derivative `u^eta · log(u)` is `0 · (−inf)` there. Both the canopy profile and
`TF24_Strategy::Q`'s root-mass distribution, the latter being the site the crown-base branch
does not reach.

### The commit order the plan specifies is not buildable

The plan puts the RcppR6 yml and its regeneration in a commit of their own, after the
templating. That cannot work: once a class is a template, `plant::Internals` as a type name is
ill-formed, so the generated `RcppR6.cpp`/`RcppExports.cpp` stop compiling in the **same**
commit that templates it. A `= double` default does not rescue it — a default makes
`Internals<>` legal, not `Internals`. So the yml edits and regeneration land in the commits that
require them, and the task is five code commits rather than six. Buildability wins, because
"bit-identical before the next" means nothing if a commit does not build. Regeneration was
verified a no-op both at the baseline and on the committed tree (`RcppR6 up to date`, clean
`git status`), which is what says the generated files match the yml rather than having been
hand-edited.

### `plant::Environment` is half-templated, and that is the seam

`TF24_Environment<S>` derives from the untemplated `Environment`, whose `Internals<double> vars`
**is** the soil water state. So the light profile carries `S` while the entire soil water
balance — `compute_rates`, `soil_K_from_soil_theta`, `psi_from_soil_moist`,
`soil_moist_from_psi` — stays `double`. At `S = double` this is bit-identical and invisible; at
an active `S` the soil side carries no derivative. Not widened here, because templating
`Environment` reaches FF16's and K93's environments too. **A decision is owed before anything
differentiates through the soil.** Note that report 00 §7 classifies the soil channels as free
or closed-form — `dθ/dφ` because moisture is ODE state, `dψ_i/dθ_i` because it is analytic — so
the seam may be intended rather than accidental; that reconciliation has not been done and
should not be assumed.

### Two more `pow` sites carry the same latent NaN derivative, unguarded

Found by reading, not by a gate, and deliberately left alone since the task was told to guard
exactly two:

- **`CanopyShape::Qp`** — `std::pow(1 − sqrt(x), eta_inverse_)`, whose `eta_inverse_`
  derivative is `0^k · log 0` at `x = 1`. FF16-only.
- **The three TF24 soil curves**, exponents `n_psi` and `2·n_psi + 3`, bases reaching 0.
  Unreachable while the environment seam above stands.

**Neither `eta` (through `Qp`) nor `n_psi` may be registered as a differentiation target until
it has the guard** — the same argument that put the guard on `Q` here. A NaN of this shape makes
exactly one trait's gradient NaN while every other stays finite and plausible.

### A grep found three lambdas that would have silently passivated an active value

`resource_spline.h:41` had no return type at all, and three lambdas in `tf24_strategy.h` and
`tf24_environment.h` were declared `-> double`, which at an active `S` would have converted the
value to a passive one and dropped its derivative — silently, with no compile error and no
number moving. **This is the finding that most justifies the static review**, because no
bit-identity gate at `S = double` could ever see it. All now declare `-> S`.

One deduced lambda remains, `optimise_at` in `tf24_strategy.h`, which returns `void` — its body
sets physiology and solves, with no `return`. Not a violation, since it returns no value; worth
`-> void` the next time the file is opened, because a future editor adding a `return` there
creates the hazard.

### Style sweep: every hit is a pre-existing line the diff moved

Fourteen issue tags and a banner appear as additions because commit 2 deletes an 825-line
source file and moves its definitions into the header. The arithmetic closes exactly: **7 in
the base header plus 8 in the base source equals 15 in the tip header.** None is new. And
`grep -rn 'xad::'` returns five lines in `src/leaf_model.cpp` on this branch, which is branch
topology rather than a regression — the forward-derivative helper that empties it lives on a
sibling branch, and no commit here touches that file. **The grep must be re-checked on the
merged plant tree**, where both are present.

## Trait registration

`ad_parameters()` and `ad_parameter_names()` on `TF24_Strategy<S>`, **55 of the 59 fields the
yml declares for `TF24_Pars`**, in the yml's declaration order. Bit-identical:
`offspring 42.176246845059751` at 5 105. Name-and-index agreement checked for **every** one of
the 55, not a sample: writing a unique value through `ad_parameters()[i]` changes exactly one
wrapped field and it is the one `ad_parameter_names()[i]` denotes, so no index reaches a
neighbour. The read-back path is the yml-generated `Rcpp::wrap`, so the yml is the authority on
which field a name means rather than a second list.

**Excluded, four, each with its reason:** `eta` (reaches the unguarded `CanopyShape::Qp`),
`root_depth_shape_eta` (guarded at `Q`, excluded on instruction), and `vcmax_25`/`jmax_25` (the
cache key below). `n_psi` turned out not to be a `TF24_Pars` member at all — it lives on
`TF24_Environment`, so there was nothing to exclude here and it cannot be registered from this
surface.

### Thirteen registered parameters will read as exactly zero, and that is the design

The finding that matters most here, and it was reported rather than discovered later.
`prepare_strategy()` passes the leaf's parameters into `Leaf` **by value**, and `Leaf` is
deliberately `double`. So an active `p_50`, `K_s`, `c`, `b`, `psi_crit`, `beta2`, `g1_TF24`,
`a`, `curv_fact_elec_trans`, `curv_fact_colim`, `root_c`, `root_b` or `root_psi_crit` is
flattened at that boundary and its gradient reads **exactly zero** — not wrong, zero.

That is what the design intends: report 02's thesis is that `Leaf` stays `double` and the tape
gets one node whose local Jacobian is *supplied*, so these parameters' derivatives are meant to
arrive through that Jacobian rather than through taping. **But nothing yet supplies it**, so the
zeros are real until Phase 3. Recorded loudly because exactly-zero is the failure mode this
whole design exists to prevent, and anyone who runs a gradient before that Jacobian exists will
see thirteen zeros and have no way to tell design from defect. Not measured — measuring it needs
a gradient, which Phase 1 does not compute.

Same boundary is the second, independent reason `vcmax_25` and `jmax_25` stay unregistered:
`Leaf::photo_temp_cached_` is keyed on `(leaf_temp_, atm_o2_kpa_)` while caching `vcmax_`,
`jmax_`, `gamma_`, `ko_`, `kc_`, `R_d_` and `km_` — a proper subset of the dependencies — but
even with the key fixed, the `double` `Leaf` severs the channel first. Extending the key also
reaches `src/leaf_model.cpp`, beyond the one allowlisted header, which was the stated stop
condition. Both readings reported, neither taken.

### The accessors are not generated, and could not be

The plan asks for names and pointers "from the RcppR6 yml, no macro list". Literal generation is
not reachable: RcppR6's templates live inside the installed package, outside the repository, and
generated output could only ever name `TF24_Strategy<double>` rather than the template. What
landed instead is the list in the header with **a test that verifies it elementwise against the
yml's declaration order**, so the two cannot silently disagree — no X-macro, no second name
list, no stored count. Weaker than generation, and guarded. Making it literal needs either a
repo-local generator or a change to RcppR6's templates, which is new scope.

Also: `TF24_Strategy` is a yml `list:` class, so it has no `methods:` slot and the accessors are
not R-visible. Consistent with active types staying C++-internal, and the reason the yml was not
touched and nothing regenerated.

**Not independently re-verified by the orchestrator.** Two inline accessors and a test cannot
move a number, and the composite figure on the merged plant tree covers this transitively and
more strongly. Stated rather than implied.

## The active build

**The class bodies instantiate; the member bodies do not.** This is the packet's product, and a
long list is the finding rather than a failure — the alternative was for the next phase to meet
all of it at once.

    static_assert(sizeof(plant::TF24_Strategy<active_scalar>) > 0);   // clean, no diagnostics
    static_assert(sizeof(plant::TF24_Environment<active_scalar>) > 0);
    static_assert(sizeof(plant::CanopyShape<active_scalar>) > 0);

**41 errors at 33 distinct sites, in six groups.** The reference run stays
`42.176246845059751` at 5 105, and `plant.so` is byte-for-byte the same size across the builds
either side of the one change made.

**A — `std::`-qualified math on an active argument: 12 sites, and this is the largest
obstruction.** `std::pow/max/min/sqrt/exp` are constrained to arithmetic types; XAD's overloads
are found only by argument-dependent lookup. Sites include `TF24_Pars`' own default member
initialisers (`b`, `psi_crit`, `root_psi_crit`), the light floor's `std::max`, the storage
block's `std::min`/`std::exp`/`std::sqrt`, and `CanopyShape`'s two `std::pow` calls.

**I predicted the environment seam would be the largest obstruction and I was wrong.** It is one
funnel, not a diffuse problem: `Internals<S>` keeps `consumption_rates` and
`set_consumption_rate(int, double)` deliberately `double`, so the single place `S` must be
dropped is the plant's water draw, and everything downstream of it —
`compute_rates`, `soil_K_from_soil_theta`, `psi_from_soil_moist`, `soil_moist_from_psi` — never
sees an active value and never errored. `Internals<S>`'s `states`, `rates`, `auxs` and
`set_aux()` instantiate without complaint.

**B — the `double` state and aux boundary: 12 sites.** The consumption-rate funnel above, the
DeepCrown branch's `std::vector<double>` accumulators, and `util::is_finite(double)`.

**C — `quadrature::QK` is not templated: 3 sites.** `integrate` takes `double` limits and
returns `double`; the integrand is already generic, the limits and the result are not.

**D — `util::uniroot` refuses `height_seed()`'s active brackets: 1 site, and this is the design
working.** The residual lambda is declared `-> S`, so the bracket's derivative cannot leak out
and the call simply refuses rather than silently collapsing. Left exactly as it is.

**E — the `Leaf` boundary is precisely where the design says, and it is cleanly enumerable.**
Two shapes only: the traits going in (the constructor, where 13 of 19 arguments are now active,
and `set_physiology`) and the outputs coming back (`leaf.profit_`, `transpiration_`, `E_up_`,
`opt_psi_stem_`, `root_collar_psi_`, `stom_cond_CO2_`, `assim_colimited_`,
`soil_consumption_[a]`). A supplied local Jacobian across that interface looks tractable.

**`Control` and `ExtrinsicDrivers` produced no errors at all**, which is worth knowing: a
`double` promotes into an expression template freely, so the boundary only bites where a
`double` must be *written* or a `double` parameter *matched*. That is a sharper rule than "these
stay double".

**F — a real inconsistency introduced when the profile was templated.**
`basic_interpolator<S>` carries `S` *values* on a `double` *abscissa* — `eval(double)`,
`operator()(double)` — and `TF24_Environment::compute_environment` is consistent with that, its
lambda being `[&](double height) -> S`. But `ResourceSpline<S>::get_value_at_height` is declared
to take `S height`, which the interpolant cannot accept. **So a differentiable *height* is not
reachable through the light spline at all — only a differentiable light value.** Closing it means
either templating the abscissa in odelia or narrowing the accessor to `double`, which is a
decision about whether height is ever an active input. Related to, but not the same as, the
recorded hazard that reading the field at a fraction rather than a position makes `d/d(height)`
exactly zero.

### The deduced-return-type trap is not set anywhere in TF24

Audited by the first thing ever to instantiate these templates, which is stronger than
inspection. All five value-returning lambdas declare their scalar return type; the one that
deduces returns `void`. So the hazard that cost a session to find earlier is absent here.

### One line changed, and why it is not a design choice

`std::pow(u, eta_x)` to unqualified `pow` inside `TF24_Strategy::Q`'s
`if constexpr (!is_same_v<S, double>)` branch. That branch is discarded for `S = double` so it
cannot reach production codegen, and the sibling `double` branch two lines up already writes
unqualified `pow` — a typo in code that had never been compiled. Bit-identity held and the `.so`
size is unchanged.

**Two readings on the other eleven, reported rather than taken:** requalifying to unqualified
calls changes overload resolution for the `double` instantiation too, so bit-identity would have
to be re-earned by measurement rather than argument; adding `using std::pow;` or a plant-side
generic wrapper is safer for `double` but is a new mechanism and a decision about where plant
keeps its generic math. And **`std::max`/`std::min` are not a requalification at all** — they are
homogeneous templates, so even with ADL the literal must first be promoted to `S`. That is a
change with a shape.

### Also found

`CanopyShape::pow_eta_general` is instantiated even at TF24's default `eta = 12`, because taking
the address of a static member function in the unselected branch instantiates it
unconditionally. And odelia has **no namespace-scope alias for the adjoint active scalar** — it
appears only inside function bodies or as a class member, so reaching it without plant spelling
`xad::` required naming a full `Solver` instantiation. An `odelia::ode::active_scalar` alias is
owed.

## `reset()` restores the soil state

`TF24_Environment` snapshots the soil state whenever `set_soil_water_state` sets it, and
`clear_environment()` restores it alongside clearing the light profile. `environment.h` needed no
base-class hook.

**The gate was shown to bite before the fix, on the base tree:**

    run 1 offspring 42.176246845059751  steps 5105
    run 2 offspring 42.296696440471194  steps 5062     offspring identical: FALSE
    after run + reset : 0.284128746037276 … 81.215239676534338
    freshly built     : 0.214 0.214 0.214 0.214 0.214 0 0 0 0

and after: run 2 identical to run 1 at `42.176246845059751` / 5 105, and the post-reset state
bitwise equal to a freshly built one. The reference forward run is unmoved, which is the
safety property — this restores an initial condition rather than changing one.

**A correction to how this defect was first characterised.** The figure recorded earlier,
offspring `6.6462981636817595e-23` on a second run, came from a different probe. Measured here,
constructing the `SCM` directly at `max_patch_lifetime = 105.32`, the second run reports
`42.296696440471194` — because on this configuration the carried-over soil is *wetter* than a
fresh start (0.284 against 0.214), so the second run does slightly **better** rather than
collapsing. Same defect, opposite-looking symptom. **Its magnitude and even its sign are
probe-dependent**, which is worth knowing before anyone quotes a severity for it.

### The snapshot is required, and restoring the constructed default would be wrong

Two readings were available: re-run whatever initialises the state at construction, or snapshot
it. Settled on the code. The constructor's last line is the only initialiser —
`set_soil_water_state(std::vector<double>(soil_number_of_depths, soil_moist_sat*0.5))` — so
re-running it *would* reproduce the default. It is still wrong, because `set_soil_water_state`
is part of the R interface and is exercised: a test sets a one-layer soil to `0.1` and hands that
environment to `run_scm`, and `scenario_eval.R` uses it too. Recomputing the default at
`reset()` would overwrite the caller's choice and move the **first** run's initial condition,
which is precisely what this packet forbade. `set_soil_parameters` makes it worse, since it
reallocates the state to zeros.

So the snapshot is not storing what can be derived — the starting moisture is a caller's choice,
not a function of the parameters. It is taken at the one place that sets soil states and reset
at the one place that resizes, so it cannot drift.

### The refine-schedule shift moved the other way from the prediction

At `schedule_nsteps = 2`, `max_patch_lifetime = 105.32`:

| | offspring | ode steps | schedule size |
|---|---|---|---|
| before | `54.700442966301416` | 5 715 | 168 |
| after | `54.881000377659738` | 5 756 | 167 |

Predicted in advance to move *downward*, on the reasoning that the base tree's second run starts
from wetter soil and so overstates offspring. It moved **upward**, by +0.18. Recorded as
measured, not reconciled: the refinement also changed the schedule (168 to 167 nodes), and the
schedule's effect on offspring is larger than the soil's, so only the *fact* of movement is
predictable from the carried soil, not its direction. Nothing re-blessed.

## The cost of a gate depends on how many packets are running

The operational finding of the phase, and it invalidates the costing in several of its own
packets. **A production TF24 lifetime is about 90 s on an idle box and about 7 minutes on this
one while a wave of packets is building** — roughly 5×. Every gate in this phase was costed
against the 90 s figure, so a gate stated as "three minutes" ran twenty, and the un-capped
refine-schedule gate consumed 50 minutes at full CPU before being killed.

Fan-out multiplies per-packet cost: eight packets on four cores do not each run at the isolated
rate, so **a wave's wall clock is not the sum of its packets' measured costs**, and a gate must
be costed for the contended case. This is the same figure the build is pinned against for a
different reason — absolute times belong to the machine, and here they belong to the machine's
current load as well.

## The phase, merged

One integration branch per repository. Every merge was checked by **reading the merged tree**
for each change rather than trusting the auto-merge, then built once and gated.

    odelia  p1/odelia-integration  e10ab19    320 pass, 0 fail, 0 error, 2 skip
    plant   p1/phase-1             1204d332

**The composite figure is the baseline figure.**

| | offspring | accepted steps |
|---|---|---|
| plant `7b05b55e`, before the phase | `42.176246845059751` | 5 105 |
| **`p1/phase-1`, the whole phase merged** | **`42.176246845059751`** | **5 105** |

Bit-identical, at the pinned build, 0 occurrences of `-O0`. **The entire phase moves no
number** — including the environment's aux widening, which the plan had singled out as its one
sanctioned shift. There is nothing to re-bless.

The family tripwire on the merged tree, which is what caught a silent regression in the previous
phase and is the reason it is taken here rather than at the end:

| | offspring | accepted steps |
|---|---|---|
| FF16 | `19.825535760483262` | 209 |
| K93 | `0.030546712014675573` | 240 |

Both unmoved, despite `CanopyShape` being shared across the family and templated in this phase.

**`grep -rn 'xad::' inst src` in plant returns nothing on the merged tree**, which is the first
tree on which it could: the five occurrences lived in `src/leaf_model.cpp` and the helper that
replaces them was developed on a sibling branch, so every branch in isolation still showed them.
The design's rule that plant never names `xad::` holds only as a property of the merged tree, and
that is where it is now verified.

**One merge conflict, resolved by hand, and gated before it was believed.**
`inst/include/plant/models/tf24_environment.h`: the templating branch changed
`Internals(...)` to `Internals<double>(...)` in `set_soil_number_of_depths`, and the reset branch
added the soil snapshot on the following line. Both sides kept. Because that is a hand edit by the
orchestrator, it was held to the same standard as a packet — the composite bit-identity figure
above is its gate.

### Still owed at the close of this phase

**The trajectory store is the one Phase 1 deliverable outstanding**, and it is not in the merged
tree. Its two prerequisites now exist — the recorded step sizes and the soil-state restore — so
what remains is to write the store against them and pass its gate. The design is settled and
recorded above: the record carries the step size, and the replay is driven by the recorded step
sizes rather than by differencing times.

Whoever picks it up should branch from **`p1/phase-1`** (`1204d332`) and install odelia from
**`p1/odelia-integration`** (`e10ab19`). Two environment errors cost the first two attempts and
are worth not repeating:

- **`p1/env-reset` is the wrong base**, even though it carries the soil fix, because it is
  branched from before the plumbing sweep and so still names `odelia::ode::const_iterator` in 45
  places — which the merged odelia deletes. 68 compile errors, all of that one shape.
  `p1/phase-1` carries both prerequisites.
- **An install can silently not take.** A library was found carrying an odelia with **zero**
  step-size accessors while its source worktree had 34, so the packet's whole mechanism was
  absent from the tree being built against. Verify an install by grepping the *installed* header
  for the symbol you need, not by reading the install log.

### A base paired with the wrong odelia bit three times in this phase

Worth stating as a class, because it is the same mistake in three costumes and every instance was
the orchestrator's:

1. A plant worktree at `7b05b55e` paired with an odelia carrying the constrained range helpers —
   56 `no type named 'value_type'` errors, because plant's elements had none yet.
2. The plumbing sweep's own baseline, which had to be taken against the pre-concept site odelia
   because no build exists in which base plant and the constrained helpers coexist.
3. A plant branch predating the plumbing sweep paired with an odelia that had deleted the legacy
   typedefs — the 68 errors above.

**The check that would have caught all three takes seconds:** before sending a packet, confirm
that its plant base and its odelia actually compile together, or state explicitly which
incompatibility the packet is expected to hit and why that is acceptable. A packet's environment
is part of its specification, and an unbuildable pairing spends an agent's whole first cycle
before anything begins.

## The trajectory store, and why three attempts failed first

**The store is recorded during the adaptive run, not by replaying it.** `Patch` satisfies odelia's
`Replayable` concept so that `SolverInternal::step`'s existing `record_ode_step(system)` hook fires
on the accepted branch; `record_ode_step()` is the only member that does anything, while
`record_stage(int)` and `replay_step()` are empty and `has_recorded_field()` returns `false`. The
record is `ode_step_record { double time; double step_size; std::vector<double> state; }`.

Verified independently at the branch tip in a detached worktree, production TF24, pinned build,
0 occurrences of `-O0`:

    forward run                             offspring 42.176246845059751   5 105 steps
    records                                 5 105, equal to the accepted step count
    stored final state vs the forward run   bitwise identical, 0 of 1 137 components differ
    first step size                         NaN, from the solver
    t_i == t_{i-1} + h_i                    bitwise at every step
    recorded times vs r_ode_times()         bitwise identical
    two stores from one SCM                 bitwise identical

`test-mutant.R` byte-identical before and after — the same two pre-existing fixture errors at the
same two locations — which is the gate that says satisfying the concept changed no behaviour.

### Why a replay cannot reproduce the adaptive run, which the plan says it can

**The stage is not a pure function of `(y, t)`.** `Species::compute_rates` ends by writing
`new_node.compute_initial_conditions(...)` on **every** call, and `Species::compute_competition`
closes its descending trapezium on `new_node.height()` and its competition — so the light field
reads a boundary node whose density was written by the *previous* evaluation. Report 01 §3 sets this
out and calls it one stage of Picard: the per-stage computation is a function of
`(y, t, boundary density carried from the previous evaluation)`.

A **rejected** step attempt runs `stepper_step`, hence `derivs`, hence `compute_rates` — so it
writes that carried scalar while producing no accepted step. A replay makes no rejected attempts, so
it arrives at every accepted step with a different carried density.

**This falsifies a claim in `build-plan.md` P1.4:** *"A sequential replay reproduces develop's lagged
boundary density for free, because it visits the stages in the same order the forward run did."* It
does not — it skips every rejected attempt. The plan then asserts P1.4's own gate is unaffected by
the lag, and that assertion is what three packets were built on.

Measured, production TF24, before the remedy:

| | offspring | deviation | components differing |
|---|---|---|---|
| forward, adaptive | `42.176246845059751` | — | — |
| replay over recorded **times** | `42.235505201883193` | 0.1405% | 1 118 of 1 137 |
| replay over recorded **step sizes** | `42.403558838695034` | 0.539% | 1 118 of 1 137 |

**The true `h` makes it worse, and that is the tell.** A more faithful step size lands at the same
state with a *less* faithful carried scalar, so nothing cancels. The step-size mechanism itself is
sound: it reproduced the recorded time grid bitwise and satisfied `t_i == t_{i-1} + h_i` bitwise at
every one of 5 105 steps. Two separable effects, and the plan only knew about the smaller one.

Localisation, which is what identified the cause: absent in short runs (FF16 and K93 at 17 accepted
steps are bit-identical), present on FF16 at production lifetime as well as TF24, and **sudden
rather than accumulating** — on a short TF24 schedule it appears within the first introduction
interval, 515 of 569 components at once, which is a rejection rather than drift.

The codebase already half-knew. `test-scm.R` carried a comment saying a pinned run "does not
actually produce *exactly* the same output, which is very surprising", guessing at the step-size
difference — the smaller of the two effects. Its assertion passed only because `control_accurate()`
at 14 introductions leaves almost every step interval-final, and it excluded TF24. That test is now
re-scoped: determinism is the load-bearing assertion, and TF24 is included rather than excluded.

### What this means for Phase 3, and it is a prerequisite rather than an optimisation

§2.8's reverse pass rebuilds each step's stage states by re-running the step from `(t, h, y)`. **It
inherits the same problem**: re-running re-derives the carried boundary density rather than
restoring it, so the rebuilt stage states will not be the forward pass's while the field reads
`new_node`. `(t, h, y)` is necessary and **not sufficient** for the reverse pass — the carried
density, one scalar per species per step, is a fourth thing it needs and the record does not hold.
P2.7 closes the lag, so **P2.7 is a prerequisite for the reverse pass**, not a numerical refinement
to schedule at leisure.

### Owed

- **`Replayable` is now the wrong name.** Its only real implementor records and never replays:
  `replay_step()` is empty and `has_recorded_field()` is permanently `false`. `Recordable` is the
  rename. An odelia change, recorded rather than taken.
- `Patch`'s implicit copy constructor copies the store once per recorded run — about 46 MB at
  production — where `patch = solver.get_system_ref()` runs at the end of a run. A known cost, not
  a defect.
- `record_ode_step` also fires from `step_to`/`step_by`, so a recorded run down the pinned path
  would record too. Nothing sets `record_steps` on that path today.

## The phase, merged and closed

    odelia  p1/odelia-integration    322 pass, 0 fail, 0 error, 2 skip
    plant   p1/phase-1

| | offspring | accepted steps |
|---|---|---|
| plant `7b05b55e`, before the phase | `42.176246845059751` | 5 105 |
| **`p1/phase-1`, everything merged** | **`42.176246845059751`** | **5 105** |
| FF16 | `19.825535760483262` | 209 |
| K93 | `0.030546712014675573` | 240 |

**Bit-identical, and the whole phase moves no number.** Nothing to re-bless — including the
environment's aux widening, which the plan had singled out as its one sanctioned shift and which
moves no assertion at all.

---

# The Phase 1 audit, and five spikes against the Phase 2 design

Read against the build plan, the style guides and reports 00–04 and 07. Nine findings were
fixed on `p1/audit-fixes` in both repositories; the rest became build-plan corrections or
`aornugent/plant#67`. Then five spikes tested the design ideas the audit suggested. **Four of
the five ideas died, which is what the spikes were for.**

## What the audit fixed

odelia, 327 pass (from 322): each range helper is constrained on the one member it calls
rather than on the element, so an element whose state moves through another scalar's iterator
is rejected at the call — the case `OdeElement` was introduced for and could not see, because
it checked the element against an iterator over its own `value_type` rather than the one the
helper threads. `implicit_value`'s `denom_sign` is gone (nothing but its own test declared a
sign; a zero denominator is the failure whichever sign was expected). `step_adjoint` restores
the System to the step's start state, having walked it to the last stage state.

plant, bit-identical at `42.176246845059751` / 5 105: `set_ode_aux` on `Individual`, `Node`,
`SpeciesBase` and `Patch`, so the aux transfer has a read direction as well as a write one;
the environment's published buffer sized by the count that decides its width; the `Replayable`
assertion the notes had credited but the tree did not carry; and eleven registered
differentiation targets removed because no equation reads them.

**A registered parameter no equation reads is a gradient row that is exactly zero.** The test
that now says so perturbs each registered parameter and requires some output to move, over
four states — a seedling, a mature plant, a shaded one whose carbon is negative, and one in
soil dry enough to pin the collar. It needs all four: a fresh individual holds no storage, so
the reserve gate and storage-dependent mortality cannot move; recruitment decay is a rate
against patch age, so at time zero it cannot move. An earlier version of the probe reported
four live parameters as dead for those reasons. `p_50` is the interesting one: its only reader
is `TF24_Pars`' own default initialisers for `c` and `b`, so it is consumed at construction and
a value set afterwards reaches nothing.

## The spikes

**The stage is not idempotent, and the reordering makes it exact.** `derivs(y, t)` twice in a
row differs at **92 of 753 components** on the production end state. Forming the boundary
density in a field that excludes its own interval, then adding the interval back, takes that to
**0 of 753**. One further Picard step then moves the ground light by at most **9.912e-08**
relative over 66 290 field builds, so the fixed point is converged; the shift against the lag is
at most **1.464e-06** relative, two orders inside the boundary term's own 3.495e-04
contribution, and 0 of 66 290 builds exceed the 3.5e-04 bound report 01 §3.1 predicts. It costs
one extra field build per stage — the same as the planned Picard step, not O(1) as first
claimed, because the density reads a field rather than a value. Composes with report 04's
stencil, which wants exactly the more-current boundary neighbour it supplies. Preserved on
plant `spike/boundary-acyclic`.

**There are two path dependences, not one, and the second is the light spline's knot grid.**
`ResourceSpline::rescale_spline` reuses the previous build's knot positions, so the grid is
inherited from the history of field builds rather than derived from the current state. That is
a residual impurity of ~4.8e-08 which the reordering cannot touch; with rescaling disabled the
reordered stage is **bit-exactly pure across FF16, K93 and TF24**. So a reproducible rebuild
needs fixed knot fractions *and* one of the boundary treatments — neither alone is sufficient,
and a pinned replay stayed at 1118 of 1137 components differing after the reordering.

**Trajectory storage, measured where it grows fastest.** Accepted steps and final ODE width:
one species at the default driver 5 104 / 1 137; two species 3 676 / 2 265; the hardest
committed rainfall sequence found (S05) 8 415 / 1 137. The two dials partly cancel — doubling
the width dropped the step count 28% — so the trajectory runs **33 to 60 MB** and a per-stage
store would be **198 to 360 MB**. Mean width over steps is 0.746 of the final width and
cumulative storage is near-uniform in step index, so a uniform checkpoint interval in steps
would be near-optimal and one in time badly wrong. Two species against S05 did not finish
inside ten minutes and is unmeasured.

**Ranking configurations at a short lifetime does not predict which is hardest.** S07 was the
maximum at `max_patch_lifetime = 10` and the minimum of three at production; S06 was
mid-ranked and nearly doubled it. A cheap probe can tell you how to drive a scenario and not
which scenario to drive. Wall clock tracks step count, so a gate costed on the default driver
is about half price on the rainfall banks.

## What the spikes killed

**Storing the six stage states instead of rebuilding them.** The collar operating point is
nowhere in the ODE state — it is the output of a search — and the soil positivity guard's
condition needs the summed per-layer uptake, which is also not state and can only be produced
by solving every cohort's leaf. The rebuild is not the memory-cheap option; it is the only
thing that manufactures two quantities the state does not contain. §2.9's one-line rejection
was right for a better reason than it gave.

**Deleting the dead mutant replay path.** `has_recorded_field()` and the index-addressed
`set_ode_state` overload *are* the mutant mechanism. RKCK evaluates two stages at the same
timestamp — `ah[3] = 1` and `dydt_out` at `t + h` — so a stage cannot be addressed by time and
index addressing is structurally required for any per-stage frozen field. Their cost to the
resident pass is one always-false branch. The two retired commits on the old AD branch show the
whole failure was a name mismatch: `cache_ode_step` → `record_ode_step`, bodies unchanged, and
`test-mutant.R` went from 2 errors to 19 passing.

**One boundary primitive across all three scales.** Two spikes refused the leaf independently.
Its output arity is state-dependent through `max_soil_layer`, its input list is not derivable
(one entry was already found dead that way), and its adjoint is a factorisation — `2n + 1`
directions onto two shared scalars, one of them recovered by evaluating the residual again
during the sweep — rather than a range to scatter into. A primitive covering the ODE interface
and the cohort's environment reads compiles and costs eleven names against six loops deleted,
so it earns its place only if the cohort-read boundary is built on it.

**"Most of the 41 active-build errors are off the gradient path."** Inverted. `b` and
`psi_crit` are leaf parameters P3.3 must differentiate, `CanopyShape`'s `pow` is `eta`'s field
channel, the twelve-site consumption funnel is the water channel itself, and `QK` is the crown
integral whose frozen query M1 measured as exactly zero. Only one group of six is the leaf
boundary. And staying `double` is precisely what makes report 02's C2 and C3 invisible to a
compiler, so an error count measures nothing about exposure in either direction.

## What no task covers

**A gated cohort next to an ungated one — and the premise is false.** This was recorded as
"TF24's growth gate is hard and un-smoothed, because `smooth_positive` appears at two sites in
FF16, two in K93, none in TF24". **Corrected against the tree in Phase 2:** `smooth_positive`
exists at *no* site in plant's headers, and report 02 C1 attributes the four it names to the **AD
branch**, so a branch-specific fact was carried into a develop-tree conclusion by a grep that
found nothing. `TF24_Strategy::compute_rates` smooths the gate inline —
`Ppos = 0.5 * (P + sqrt(P * P + storage_prod_eps * storage_prod_eps))` at
`storage_prod_eps = 1e-4`, times a logistic reserve gate — which is what `#517` replaced the hard
`net > 0` cutoff with, and which report 00 §4.3 records. `test-node.R` states it in its own
comment while loosening a tolerance for it. TF24's one remaining hard `net > 0` gate is inside
`establishment_probability`, which is P0.6's and which sets the boundary node's density rather
than any cohort's `g`.

So there is no switch for two neighbours to sit on opposite sides of. What survives is the
quantitative question — the cohort-grid stencil divides a growth-rate difference by a spacing
whose measured minimum is 8.2095e-06 with 23.5% below 1e-4, and a large enough difference over
that divisor is an O(1e5) term develop's sub-grid probe cannot produce, because both of its
evaluations are the same cohort perturbed by 1e-6. **That is answered by M4's own census rather
than by a second run**, which is how the two Phase 2 pre-measurements became one.

**`node_gradient_eps` and `GSS_tol_abs` are coupled, and Phase 2 gives its tasks no order.**
Report 04 §5 records that develop's probe survives differencing a 1e-3-scale staircase at a
1e-6 step only because the comparison pattern is locally constant at the current bracket. P2.6
widens that bracket a hundredfold. Interleaved with P2.4, its bit-identity gate is asserted
against a moving leaf and M4 stops being attributable.

**Aux has two owners.** §2.9 co-opts aux slots as the operating-point transfer while report 02
§3.3 notes that a functional reading `E_up_` through aux would give the block a seventh output
row. Same shape as every defect this project has found: a quantity written by one place and
read by another under an assumption neither states.

**The invasion case reconciles with the resident design, and neither document says so.**
`AUTODIFF.md`'s L3 mechanism is generic: with recorded background values populated, the System
reads them as `double` off the tape, so *that background's derivative is zero by construction*.
That is what "omit step (c)" means. Resident leaves L3 empty and the field's derivative flows;
invasion populates it and it does not. One data question, two workflows, no branch in the
adjoint code.

**The contraction family already exists in odelia, unnamed.** `implicit_value` takes its
partials from the implicit function theorem, `vector_jacobian_product` from a tape, and
`SuppliedDerivative` from the author's own mathematics. Three sources of partials for one idea,
which makes the leaf's supplied Jacobian an instance rather than a mechanism of its own.

**Two for the owner.** 91% of `rescale_spline`'s 193.2 µs per build is unattributed over 20 160
builds — 3.5 s of a 59.5 s run, with LTO tested and rejected as the cause — and it is a task
nowhere. And the establishment gate, where two documents each picked one end of one distribution and
reported it as settled. Reconciled in `tf24-correctness.md` P0.6 and now recorded there as open:
the closed arm spans four to five orders, real carbon deficit at the top and a numerical zero at
the bottom, so no single smoothing scale fits and the call is the owner's.

---

# Phase 2

Branch `p2/phase-2` off plant `p1/audit-fixes` (`076ae24f`), against odelia `p1/audit-fixes`
(`43c8561`) installed into its own library. **The site library held a pre-Phase-1 odelia with no
`hermite_interpolator.hpp` at all**, which is the install-verification rule earning itself again:
grep the artifact, never the log.

The reference run reproduces in this worktree at the pinned build — offspring
`42.176246845059751`, 5 105 accepted steps — which is also the proof that the transport census
below is inert when its environment variable is unset.

**A build here is about ten minutes, not the ~95 s recorded under "The build, pinned".** That
figure is not this machine, and the difference is the whole shape of a phase's budget: nine builds
is ninety minutes, not fifteen.

## The transport census: one run, two questions

`PLANT_TRANSPORT_CENSUS` accumulates moments and extremes over every (stage, node) record rather
than dumping rows, because a production lifetime is 3 785 061 of them. It answers M4's value half
and the gated-neighbour question together, which is why Phase 2's two pre-measurements became one
run.

| | |
|---|---|
| records | 3 785 061 |
| max \|cohort-grid stencil\| | **142.85** |
| records with \|stencil\| > 1e3 | **0** |
| records with \|stencil\| > 1e5 | **0** |
| max \|sub-grid probe\| | 1.51 |
| `dh == 0` | **141** |
| `dh < 1e-4` | 444 624 (11.7%) |
| M4: mean(cohort − sub-grid) | −0.0620 |
| M4: sd | 1.878 |
| M4: peak \|difference\| | 142.59 |

**The O(1e5) term does not occur.** The stencil peaks two to three orders below the figure the
corpus feared, and no record exceeds 1e3. The peak is the lowest cohort differencing against the
boundary node at height 0.3447 — essentially `height_0` — where the newborn grows at 0.0958 against
the established cohort's 0.0257 over a spacing of 4.9e-04. That is a real four-fold growth
difference, and its mechanism is the *smooth* reserve gate rather than a switch: a fresh boundary
node has reserves a depleted seedling does not. So the hazard exists in kind, is bounded at ~143,
and needs no smoothed clamp.

**`dh == 0` at exactly 141 records is report 04 §7.1's prediction confirmed per stage** — one
degenerate interval per introduction, where an output-time census could only infer it.

**The cohort spacing goes negative, at −0.0334 m, and M8 could not see it.** M8 scanned 10 011
neighbouring pairs over 142 output times and found none non-descending; the census sees every
stage. M8's own caveat named this gap. The tree already knows the state exists —
`Species::compute_competition_unordered` handles it, from `#571` — but **report 04 §7.2's stencil
pairs `nodes[i]` with `nodes[i+1]` and takes list order for height order**, so it would difference
a pair that is not adjacent in height. P2.4 needs a guard on non-descending pairs, not only on
`dh == 0`. Which pair crosses — the boundary pair or an interior one — is not yet attributed.

## P2.7 — the boundary density formed in a field that excludes its own interval

`f0338c06`. The field build is now A0 (state alone) → the boundary condition evaluated in A0 → A =
A0 plus the interval formed from it, so nothing reads a density carried from the previous
evaluation. The boundary node moves from `Species::compute_rates` to the field build, which also
takes it from two evaluations per stage to one.

**The gate, and it is the property the task exists to buy:** `derivs(y, t)` twice, bitwise.

    TF24  1137 components   0 differing
    FF16   686 components   0 differing
    K93    490 components   0 differing

against 92 of 753 before the reordering. Measured with `rescale_spline` still present, which
matters for what it does *not* establish — see the next entry.

Forward effect, at the pinned build:

| | offspring | steps | shift |
|---|---|---|---|
| before | `42.176246845059751` | 5 105 | — |
| TF24 | `42.249808414392021` | 5 071 | +0.174% |
| FF16 | `19.826401394339019` | 209 | +0.0044% |
| K93 | `0.030548077017350173` | 240 | +0.0045% |

**FF16 and K93 keep their exact step counts, so their +0.004% is the change itself; TF24's 0.174%
is mostly the controller re-rolling on 34 fewer steps.** That is Phase 0's lesson reused as an
attribution tool rather than relearned.

### Removing the second boundary-node evaluation was wrong, and the reason is worth keeping

The first version of this task also deleted `new_node.compute_initial_conditions` from
`Species::compute_rates`, on the argument that the field build had already evaluated the boundary
node and that one evaluation carries one adjoint where two carry two. **That argument is false, and
the test suite caught it as a silent wrong value rather than as a shifted one.**
`test-species.R`'s `sp$compute_competition(0)` returned **exactly 0.0** where it asserts a positive
leaf area, because a `Species` used without a `Patch` then has nothing to seed `new_node`'s
density: it stays at `log_density = -Inf`, `exp(-Inf) = 0`, and the reduction's closing trapezium
contributes nothing. 18 assertions in `test-species.R` and 2 in `test-patch.R`.

The two evaluations are **the same function at different arguments, not one function computed
twice.** The field build needs the boundary condition in A0, the field excluding the boundary
interval, because that is what makes the field a function of the state. An introduced node inherits
the boundary node as it stands after `compute_rates`, which is the boundary condition in A — the
field the patch actually experiences. Removing either one loses a distinct quantity. `#66`'s P0.11
lesson, that two evaluations of one function have two adjoints, does not apply where the arguments
differ.

Restored, and the spike's arrangement turns out to have been right for a reason it did not state.
The purity gate is unaffected: the field reads its boundary density before `compute_rates` runs, so
what `compute_rates` writes afterwards cannot reach it. The benefit of restoring it is also an
attribution one — P2.7 is now the reordering alone, so its forward shift belongs to the reordering
and to nothing else.

### Two assertions in `test-patch.R` are pinned to the old coupling, and the decision is the owner's

`test-patch.R`'s "Basics FF16" and "Basics TF24" build a standalone `Node`, seed it with
`compute_initial_conditions` in the patch's *current* environment, and assert `patch$ode_rates` is
**identical** to it. Under the reordering those two nodes are seeded in different fields — the
patch's in A0, the comparison node in A — so bitwise identity is no longer the right assertion. It
was pinned to the arrangement where `compute_rates` seeded the boundary node in the same field the
patch held.

The differing component is `offspring_produced_survival_weighted_dt`, at **4.469e-22 against
4.511e-22** for FF16 and **1.1188e-21 against 1.1206e-21** for TF24: about 1% relative on the
smallest rate a just-introduced cohort has, and the one most sensitive to *when* the node was
seeded, because `pr_patch_survival_at_birth` divides it and is fixed at seeding. Every other
component is identical.

**Two readings, and this is a design choice rather than a baseline, so it is not taken here.**

- *The test is pinned to the old coupling.* The replacement asserts equality up to the boundary
  interval's own contribution, which is bounded and measured, rather than bitwise identity between
  two nodes seeded in different fields. Same category as the two `test-node.R` assertions P2.4 must
  rewrite rather than relax.
- *An introduced node should inherit the condition in A, not A0*, because A is the field it will
  actually experience — in which case `introduce_new_node` should re-seed after the field is built,
  and the test is right as it stands.

Left failing and documented rather than re-blessed. Nothing downstream depends on which way it
goes at 1e-21.

**One thing owed, stated rather than papered over.** The light-field shift at the boundary node —
the bound the plan asks this task to be verified against, at most 3.5e-04 — was measured on
`spike/boundary-acyclic` with its environment-variable diagnostics, which this merge-ready version
drops. **I did not re-measure it on this tree, and say so rather than imply otherwise.** The purity
gate is measured here and is the stronger claim.

## The derivs-twice probe measures idempotence, not history independence

Worth separating because it decides what P2.1's gate can be. `rescale_spline`'s remap is
`x_new = x_old * height_max / height_max_old`, so **evaluating one state twice rescales by exactly
1**: the knot positions do not move and the probe cannot see the carried grid. The bitwise purity
above therefore establishes idempotence and says nothing about the field's dependence on the
history of previous builds, which is the property P2.1 removes and which only shows up when one
state is reached two ways. A gate that cannot distinguish "pure" from "rescaled by one" is not
P2.1's gate.

## Corrections to what was recorded here

- The `static_assert(Replayable<Patch<...>>)` this file credited to a Phase 1 packet **was not
  in the merged tree**; the only commits naming `Replayable` are on the retired AD branch. It
  is now in `SCM::store_trajectory`, where the dependency is.
- The **60× wrong-gradient figure has no source** — no commit, test or note records the
  measurement, and it appears only as a sentence repeated across documents. Treat as unverified.
