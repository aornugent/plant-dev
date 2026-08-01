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

## P2.6 — the collar operating point polished to a stationary point

`831194bc` on `p2/p2-leafpolish`. Newton on `R = dprofit_droot_collar_psi` from the golden-section
answer, `dR_dcollar` a central difference of that analytic gradient, capped at five iterations.

| gate | required | measured |
|---|---|---|
| `\|R\|` at the returned point, 24 states | < 1e-07 | **worst 1.128e-13** |
| the polished point is bracket-independent | — | **worst 1.044e-09** between `GSS_tol_abs` 1e-3 and 1e-1, against bracket-driven displacements of 8.9e-03 |
| `test-leaf.r` | passes | 383 pass, 0 fail, from a 214-pass baseline |

**The pinned case needs no tolerance test, and trying to give it one broke the second gate.** A first
version skipped the polish when the search returned within `GSS_tol_abs` of a bracket end. That
criterion is itself tolerance-dependent: at `GSS_tol_abs = 1e-1` almost every state looks pinned, and
two states came back with `|R|` of 0.034 and 0.394. The committed version tests nothing — Newton
runs, and the bound case falls out of the guards that already have to be there (no room for the `±h`
probe, a step landing outside the bracket, or a measured curvature that is not negative). **That
absence is what makes the polished point tolerance-independent.**

**`R_tol = 1e-11` is below `R`'s own resolution, and the second gate is stated in the right currency
because of it.** Asserting agreement against the *achieved* residuals (~1e-15, so an allowance of
~1e-14) fails at 1.044e-09 while both residuals read ~1e-15: `R` is flat within its own evaluation
noise over that width, because the `ci` root-find inside it carries `ci_abs_tol = 1e-6`. So the gate
is stated against the residual the packet asks for — `2 × 1e-7 / 0.1723`, using `|Π_pp|`'s measured
floor — and the honest floor to quote is **~1e-9 in a potential of 0.2–0.6 MPa**. This is report 02
§7.2's plateau in a second place: tightening a tolerance past the resolution of the thing it bounds
buys nothing. The substance is unaffected — the flux error is first order in the displacement, so
1e-9 against the 8.8e-05 to 1.2e-03 unpolished residual is five to six orders of margin.

**The polish costs more than §8b budgeted, measured rather than projected.** Counted with a trace:
**7.25 `dprofit` evaluations** per solve at `GSS_tol_abs = 1e-3` (7 in 22 states, 10 in 2), 9.1 at
`1e-1`. At 3.5 µs each that is ~25 µs on a 10 µs solve, against §8b's "roughly +9 µs" and its "budget
it as up to +10% on the forward run". Seven is two Newton steps at three evaluations each plus the
closing check. **`dR_dcollar` is recomputed at every step; reusing it across the second step takes
the common case to five.** §8b names that reuse and this packet was not asked to do it, so it is
owed and it is the first thing to try if the forward benchmark refuses the change.

### Every production-like state sampled came back pinned, and that contradicts two documents

The gate's leaf is the test file's, with `root_b = 1.29`, `g1_TF24 = 46.3` and 10 kg of root mass;
it gives interior maxima at all 24 states. Assembled instead with `TF24_Strategy`'s own defaults —
`beta_R_H = 3.4e2`, `root_b = 3.898`, `root_c = 2.680`, `g1_TF24 = 7.5`, `a_r1 = 0.07` — **every
state tried across `psi_soil` 0.015 to 0.17 and heights 1, 5, 10 and 20 m is pinned at the wet
bound**, with `|R|` of 0.06 to 1.6, profit slightly negative and root hydraulic resistance
dominating.

Report 02 §4 measures **zero** pinned solves in 4 372 101 at the production driver, and
`build-plan.md` §8 records that no pinned state is inside the default driver's `psi_soil` range. If
the pinned regime is in fact the common case there, P3.2's shape changes: the bound branch stops
being insurance and becomes the path, and the envelope row's argmax machinery is not what most
solves need.

**Two readings, and neither is taken here.** Report 02's is an instrumented count on the real SCM
and the packet's is a hand-assembled `Leaf`, so the hand-assembly is the more likely error —
`PPFD = 900` passed as absorbed radiation is the prime suspect, since the model forms
`radiation = k_I · max(L, 1e-4) · PPFD` and both factors are below one. Against that: **nobody has
re-measured pinned incidence since P0.1, P0.2 and P0.12 changed what the leaf computes**, and report
02's count predates all three. The check is cheap and worth taking before P3.2 — instrument the
selector and run one production lifetime, which is the same shape as the transport census above.

**Why it could not be settled from R:** no `Leaf` is reachable from a `TF24_Strategy` or an
`Individual` through RcppR6, so a production state cannot be sampled without either instrumenting
C++ or adding a binding. That is the reason this is a question rather than a measurement, and it is
worth fixing on its own account.

## P2.2 — the competition profile's slope beside its value

`f3c0e088` on `p2/p2-slope`. One fused traversal at every level — `Species`, `Node`, `Individual`,
each strategy, and `CanopyShape::Q_and_q`, which forms `Q` and `q` from the single `u^eta` they
share. The `Species` reduction mirrors `compute_competition_impl` term for term: same descending
traversal, same early exit, same boundary trapezium, same `/2`.

| gate | measured |
|---|---|
| the identity against a tight central difference, `eta` ∈ {1,2,4,8,10,12} and 7.3 | worst relative error **3.7e-11 to 1.1e-10** — central-difference truncation, on both the specialised chains and the `std::pow` path |
| the fused value against `compute_competition`, bitwise | `identical()` **TRUE**, max \|diff\| 0, at every eta and on TF24 |
| `q(0, h)` and the slope at `z = 0` | finite for every `h` in 1e-8 … 1e6 and every eta; `2/h` at eta 1, 0 otherwise |

**The bitwise gate was given teeth, and the first attempt at them was invalid.** Reversing a
*two*-term sum cannot change the result, because floating-point addition is commutative — only the
association matters. With three species the check discriminates: the fused value equals `(a+b)+c`
and differs from `a+(b+c)` at 2 of 400 query heights, worst 7.1e-15. So the gate is a statement
about association, tested against a reassociation that is shown to move the double.

### `q` is not the derivative of the competition kernel for every shading model

Report 03 §4 concludes that `q` is "already declared, already called by both mean-light and
deep-crown, **already correct for every strategy**". It is not. FF16 and K93 accept
`flat-top-box` and `flat-top-soft-box`, which route competition through `leaf_area_above` — a hard
step and a smoothstep — rather than through the Yokozawa `Q`. For those two models `-k_I · a · q` is
the slope of a profile the field does not use. TF24 already rejects them, which is why the report's
claim held everywhere it was checked.

Taken here as a stop rather than a silent wrong slope: `Q_and_q` raises for the two box models,
with a test. **The alternative reading is to omit the guard and document the restriction**, and that
is the owner's if the eventual slope consumer only ever runs Yokozawa.

**A C++ hazard found on the way, worth keeping.** The first version of that guard identified the
shading model by comparing the stored function pointer against `&leaf_above_deep`. **The weak-symbol
addresses did not merge across translation units, so the comparison misfired.** A stored enum
replaced it. Function-pointer identity is not a reliable discriminator in a header-inline codebase
built without LTO — which is this one.

### Three test failures on `p2/phase-2` are the boundary reordering's, not this packet's

Established by stashing the packet's edits, rebuilding clean and re-running — the right method, and
it corrected the packet's own first answer, which came from reading `test_file(reporter="summary")`'s
return value and missing the failures buried in its `result` column.

| file | baseline | with P2.2 |
|---|---|---|
| `test-canopy-methods.R` | FAIL 1 / PASS 62 | FAIL 1 / PASS 87 |
| `test-patch.R` | FAIL 2 / PASS 160 | FAIL 2 / PASS 160 |

The `test-canopy-methods.R` failure is "deep-crown reproduces the baseline SCM result", **16.8990
against 16.8895** — a 0.056% shift from the boundary reordering, and a baseline for the phase's
re-blessing rather than a defect. The two `test-patch.R` failures are the 1e-21
`offspring_produced_survival_weighted_dt` difference recorded above. So P2.2 moves no number and
adds 25 assertions.

### Declared deviations

`inst/include/plant/individual.h` gained a seven-line forwarder, because `Individual::strategy` is
private and a per-strategy slope entry point is otherwise unreachable from `Node` — an omission in
the allowlist rather than a choice. And the RcppR6 yml and its four generated files carry
`r_compute_competition_and_slope`, returning `std::vector<double>`, so the bitwise property is a
standing test rather than a one-off probe. Both disclosed; six builds rather than one, also
disclosed.

**Owed, and it connects to a finding above.** The `!scan.decreasing` fallback was mirrored
structurally and by inspection but never exercised — every gate ran the ordered path. **The
transport census shows crossed heights do occur**, at a spacing of −0.0334 m, so that path is
reachable in production and is now the one part of this reduction with no measurement behind it.

## P2.1 — the light interpolant on a normalised coordinate

`aa3d2ee7`, `d4a9e338`, `931d9b4c` on `p2/p2-interp`. Knot fractions held for the run, uniform at 65,
and the rescale path deleted.

### The property the task buys, and it is measured decisively

**History independence, bitwise.** The same state reached two ways — the field as recorded during a
run, against a rebuild at that state — over 10 011 crown means at 142 states:

| | worst |
|---|---|
| base tree | 3.37e-04 |
| after step (3) | **0** — median 0, p95 0 |

**Knot positions run-constant**, and the gate was shown to fail before it passed:

| | knot count | builds on the uniform-65 fractions, bitwise |
|---|---|---|
| base | min 33, max 125, mean 58.1, **28 distinct counts** | 0 of 142 |
| step (1) | min 33, max 125, mean 58.2, 32 distinct | 0 of 142 |
| **step (3)** | **65 at every build, 1 distinct count** | **142 of 142** |

**My gate as written needed correcting, and the packet corrected it.** I asked for the *absolute*
position vector to be run-constant. It cannot be: `x_k = u_k · height_max` and `height_max` runs 0.34 m
to 17.9 m by design — report 03 §1b rejects a fixed absolute grid explicitly. The assertion that bites
is `x == u · height_max` bitwise against one fixed uniform `u`, which is the same claim in the right
coordinate.

The `derivs`-twice regression check is unchanged at all three models: 0 of 1137, 0 of 987, 0 of 530.

### Step (1) cannot be bit-identical, and the plan said it was

See the correction now in `build-plan.md` §P2.1. `u_k = x_k / height_max` is a rounding, so the rebuild
is `fl(fl(x/H₀) · H₁)` where `rescale_spline` computed `fl(x · fl(H₁/H₀))`. **572 of 8 256 positions
land 1–2 ulp apart**, and because the fitted cubic is still the evaluator at that step, those moves
change the *adaptive* knot count at 46 of 142 introductions and offspring by 4.6e-04. The packet
reported the gate failing rather than redefining it, which is the wanted behaviour: a 2-ulp position
move is a passing transcription check by every reading except the literal one.

### Step (2)'s shift, and the ambiguity resolved by reading M3's script

Recorded here as an open question for the owner. **It was not one — it was archaeology, and the answer
is in the script.** `scripts/m3_fixed_fractions.R` measures `|candidate - develop| / develop` in
crown-mean light (its own line: "crown-mean light: |candidate - develop| / develop, over every cohort
record"). **M3's 1.7e-03 is relative**, so P2.1's relative figure is the one to compare and its
absolute 4.94e-04 is beside the point.

10 011 crown means over 142 states: worst relative **2.04e-03** against M3's 1.7e-03, median
**2.62e-06** against 1.6e-06.

**That is not over a band, because M3 was never a band.** The script's own caveat: *"these are shifts
relative to develop — which is what re-blessing needs — and not accuracy against the true field."* M3
**predicted** the shift uniform-65 would produce, using a standalone R spline against develop's
recorded knot data. P2.1 **measured** it on the built implementation against `p2/phase-2`, which
already carries the boundary reordering. So a prediction and a measurement, taken against different
references, agreeing to 20%. The measurement is the one that counts and nothing is out of tolerance.

**The lesson is the ordinary one:** a figure quoted without its normalisation reads as either, and one
line of the script that produced it settles what a paragraph of argument could not.

Forward value after step (3): offspring **`42.63017390650149`** at 5 465 steps, bit-identical between
steps (2) and (3).

### A guard is lost, and it is the same box-model problem P2.2 found from the other side

`test-canopy-methods.R:128` asserts that `flat-top-box` **cannot** build a light environment, expecting
`run_scm` to raise "Interpolated function as refined as currently possible". With no adaptive refiner
there is nothing to stall, so a discontinuous profile is now sampled silently at 65 uniform knots and
the run completes. **That is a lost guard, not a moved number.** `Patch::compute_environment` still
catches `interpolator::refinement_failure` around a call that can no longer raise it, so the catch is
dead too.

Two packets reached the box models independently — P2.2 through `q` not being the kernel's derivative
for them, P2.1 through the refiner no longer rejecting them. **Neither model is TF24, which rejects
both; the exposure is FF16 and K93.** Worth one decision covering both rather than two.

### Owed

- The dead constructor arguments: `ResourceSpline(tol, nbase, max_depth, rescale_usually)` and
  `compute_environment`'s `rescale` now select nothing. Removing them reaches the RcppR6 yml,
  `patch.h` and `stochastic_patch.h`, none of which was in the allowlist.
- **My packet quoted a stale reference number** — `42.176246845059751` / 5 105, which is the *P1* base,
  where the tree it was given already carried the boundary reordering and stands at
  `42.249808414392021` / 5 071. The packet was told to stop if the reference did not reproduce; it
  diagnosed the discrepancy correctly, pinned its own baseline and continued, which was the right call.
  **A packet's reference must be taken on the packet's own base, and mine was not.**
- `test-patch.R:86` was not shown failing identically on the base tree, because the base `.so` had been
  overwritten; the pandoc failure at `test-strategy-ff16.R:238` is environmental.

## The phase so far, merged

*A snapshot taken with three items outstanding, kept because this file is append-only and the numbers
below were the ones gates were read against at the time. **Superseded by "Phase 2, closed"** — P2.3
landed, P2.5 is answered and P2.4 went out of scope, so neither the offspring value nor the failing-test
list here is the phase's.*

`p2/phase-2` carries P2.7, P2.6, P2.1 and P2.2. Built once at the pinned build, 0 occurrences of
`-O0`, and every gate below re-run in the orchestrator's own worktree rather than taken from a
packet's report.

**The keystone holds on the merged tree.** `derivs(y, t)` twice, bitwise: 0 of 1137 (TF24), 0 of 686
(FF16), 0 of 490 (K93).

| | offspring | steps | shift from the P1 base |
|---|---|---|---|
| plant `p1/audit-fixes` | `42.176246845059751` | 5 105 | — |
| P2.7 alone | `42.249808414392021` | 5 071 | +0.174% |
| P2.7 + P2.1 | `42.63017390650149` | 5 465 | +1.076% |
| **all four merged** | **`42.133087152116609`** | **4 730** | **−0.102%** |
| FF16 | `19.806714238717067` | 210 | −0.0949% |
| K93 | `0.030552896191851354` | 234 | +0.0203% |

**The composite is smaller in magnitude than P2.1 alone, and that is Phase 0's lesson reused rather
than relearned.** Four changes, three of which move a number, compose to −0.102% where one of them
alone moves +1.076%. Most of each individual figure is the adaptive controller re-rolling, not
biology, so the composite and the step counts are the robust quantities. The step count falls 7.3%,
which is the polish changing the trajectory rather than noise.

**The tripwire is clean:** all three models run to completion, none goes to zero, none blows up, and
the two simpler models move by 0.02% to 0.09%.

### The suite, and every failure accounted for

    test-leaf.r              383 pass   0 fail
    test-canopy-methods.R    181 pass   2 fail
    test-species.R           207 pass   0 fail
    test-patch.R             160 pass   2 fail
    test-node.R               74 pass   0 fail
    test-scm.R               122 pass   0 fail
    test-strategy-tf24.R      54 pass   0 fail
    test-strategy-ff16.R      49 pass   4 fail   1 error
    test-strategy-k93.R       21 pass   0 fail

Ten failures and one error, none unexplained:

- **Four in `test-strategy-ff16.R`** — pinned offspring and `ode_times` baselines, moved by 1.6e-05
  to 5.4e-04. Re-blessing.
- **One error in `test-strategy-ff16.R`** — `FF16_generate_stand_report` needs pandoc. Environmental.
- **One in `test-canopy-methods.R`** — the deep-crown baseline, 16.8990 → 16.8821. Re-blessing.
- **One in `test-canopy-methods.R`** — `flat-top-box cannot build a light environment`. **Not a
  re-blessing:** a lost guard, and the owner's, together with P2.2's box-model stop.
- **Two in `test-patch.R`** — the 1e-21 `offspring_produced_survival_weighted_dt` difference. **Not a
  re-blessing:** a design choice, recorded above with both readings.

**Nothing is re-blessed here.** The re-blessing is one pass over the whole phase, and the phase is not
complete: P2.3, P2.4 and P2.5 have not landed.

### What remains, with its prerequisites now measured

| | needs | state |
|---|---|---|
| **P2.3** the Hermite in `ResourceSpline` | P2.1 | landed, so unblocked. odelia's `hermite_interpolator` is complete, including the active-position graft |
| **P2.4** the transport stencil | P0.1, the gated-neighbour measurement | both done. `Species::growth_rate_gradient(i)` is in the tree with no caller; M4's value half is measured; **and it needs a guard on non-descending pairs**, which is new |
| **P2.5** attribute `rescale_spline`'s cost | P2.1 | landed. The 3.5 s share must be re-taken against a gate number, since 59.5 s is a pre-`#517` run |

## P2.5 — the forward cost, attributed per task

Each packet's worktree is one task on top of P2.7 and each still held its own `-O2` build, so the
attribution needed four **runs** and no rebuilds. Taken sequentially in one session on one machine, so
the ratios transfer and the seconds do not.

| tree | offspring | steps | seconds | **ms/step** |
|---|---|---|---|---|
| plant `p1/audit-fixes` | `42.176246845059751` | 5 105 | 116.2 | **22.8** |
| P2.7 | `42.249808414392021` | 5 071 | 123.3 | **24.3** |
| P2.7 + P2.2 | `42.249808414392021` | 5 071 | 113.5 | **22.4** |
| P2.7 + P2.1 | `42.63017390650149` | 5 465 | 118.2 | **21.6** |
| P2.7 + P2.6 | `42.571418227614053` | 4 634 | 159.7 | **34.5** |
| all four merged | `42.133087152116609` | 4 730 | 164.0 | **34.7** |

**Read per step, not per run**, because three of these change the accepted step count by up to 7%.

**P2.2 is free, and bit-identical — confirmed independently of its own packet.** Offspring is the same
17 digits as P2.7 at the same 5 071 steps, which is what "no caller on the rate path" predicts.

**P2.1 recovers time, which answers P2.5.** 24.3 → **21.6 ms/step, −11%**, and *faster than the P1
base* despite P2.7 having doubled the field build. Report 03 §5.5 measured the interpolant build at
6.6% of the run with 91% of each build unattributed; removing the adaptive refiner and the rescale
remap recovers more than that 6.6%, so part of the unattributed 175 µs was the refinement machinery.
**The share still wants re-taking against a single gate number** — the 3.5 s figure belongs to a
59.5 s pre-`#517` run — but the sign and rough size of P2.5's question are now answered: the time is
recovered, not lost.

**P2.6 is the whole of the phase's forward regression**, 24.3 → 34.5 ms/step, **+42%** against §8b's
"up to +10%".

### That regression is expected, and the reason is a packet boundary I drew

P2.6 has three steps and I authorised only the first. The plan's own argument is that the polish is
paid for by **loosening golden section to the Newton basin** — seventeen profit evaluations to reach
`GSS_tol_abs = 1e-3` against eight to reach `1e-1` — and my packet said "Do not loosen `GSS_tol_abs`
in this packet." So the +42% is the cost of step (1) carrying none of step (2)'s credit, exactly as
§8b predicts when it says the polish "is not free at these tolerances".

Two levers remain, both named in §8b and both unspent: the loosening, and reusing `dR_dcollar` across
the second Newton step (7 evaluations to 5). **Landing step (1) alone would put the phase 42% slower
per step, so it must not be re-blessed in this state** — which is also the argument for the plan's
insistence that Phase 2's four value-movers land together rather than one at a time.

### Both levers spent: the polish is now free

`45a83b8f`. `GSS_tol_abs` drops from `1e-3` to `1e-1`, and a Newton step after the first reuses the
derivative already held — it divides a step length, so a stale one changes the step taken and not the
point the steps converge to. A rejected step is retried once against a derivative taken at the current
point, and a fresh derivative still rejected is the bound case.

| arm | seconds | steps | ms/step |
|---|---|---|---|
| P2.6 step (1) alone | 158.0 | 4 730 | **33.40** |
| **both steps** | 116.4 | 4 854 | **23.98** |
| pre-P2.6 reference | — | — | 24.3 |

**23.98 against 24.3 — the polish now costs less than nothing**, before the plan's +10% tolerance is
touched. Evaluations per solve go 7.25 → 6.75 at the new default (5.17 at the old one), and the nine
profit evaluations the loosened search no longer does more than cover the two extra `dprofit` calls.

The gates hold at the new default: worst `|R|` **9.587e-09** against 1e-07 required, and the polished
point still bracket-independent at **1.044e-09** — the same figure as step (1), so the reuse moved
nothing. `test-leaf.r` 383 pass. Forward value `42.192676883315706` at 4 854 steps.

**The existing bracket-independence test gated the new default without being touched**, because it was
written against the residual rather than against whatever the default happened to be. That is the
difference between a test of a property and a test of a configuration.

**Two process notes disclosed by the packet.** The two arms were built in the opposite order to the
one planned — sources were edited while the "baseline" build was still compiling, so that object was
in fact the change arm — but both are clean full builds at `-O2` with no `-O0`, so the comparison
stands. And two comment-only edits may post-date the object they were compiled into. Worth recording
because the first is a real hazard: **editing a worktree while it is building silently relabels which
arm you measured.**

## P2.4 — out of scope, and why that is a conclusion rather than a deferral

**Decided: the transport stencil leaves this build.** It is a forward-model modelling question, raised
as `aornugent/plant#69`, and
[`reports/10-density-transport-and-carried-physiology.md`](reports/10-density-transport-and-carried-physiology.md)
is its single home — derivation, every measurement, the two smaller findings about the inflow boundary
node, and what deferring costs. Code, the four replacement tests and every probe are on plant
`transport/cohort-grid-stencil` (four commits off `p2/phase-2`). `build-plan.md` P2.4 keeps its
specification behind a banner; report 04 carries a correction to its conclusion and is otherwise not
edited. **Phase 2 is three value-movers, not four**, and P2.6 no longer waits on anything.

**Why out of scope rather than blocked.** The reverse pass differentiates whatever the forward model
does, and report 04 §5 records that differentiating develop's sub-grid probe at the active scalar is
bit-identical and yields the derivative of the discretisation actually solved. So the build proceeds
either way, and it should not hold a modelling decision hostage to its own schedule.

**The cost of deferring, and one item is load-bearing.** No 37%-per-step forward saving; the
conservation defect stays (3.4× on one cohort); a `1e-6` divisor stays on the gradient path. And
**P3.5's transport adjoint needs two block recordings per cohort per stage rather than one**, because
`log_density_dt` under the sub-grid probe reads `g` at the cohort's height *and* at `h - eps`, the
second being the output of a second evaluation of the block at a different input. `lambda_g` stops
being a closed-form seed. That is symmetric with the forward cost — two leaf solves for the same
reason — and §8b's record-and-sweep term should be budgeted at twice its stated value until it is
designed.

**What the diagnosis cost, and what it bought.** Two packets, four builds, about a dozen production
runs. It killed my own leading hypothesis (the boundary pair), confirmed report 04 §2.2 for the first
time, found that develop's blessed TF24 offspring is not converged, and turned a "10.3× is too big"
judgement into a mechanism. The detail below is kept as the evidence.

## The diagnosis: the transport stencil moves offspring by 10.3×

`03558de8`, `783ccc28`, `e820456e` on `p2/p2-stencil`. **Written, gated, and held out of
`p2/phase-2`.** Report 04 §8 lists "the forward-value change is larger than the model owner will
accept" as a falsifier of the whole change. This is that number.

| arm | offspring | steps | ms/step |
|---|---|---|---|
| baseline | `42.133087152116609` | 4 730 | 33.43 |
| step (2), two passes, still sub-grid | `42.133087152116609` | 4 730 | 33.15 |
| step (3), cohort grid | **`434.77155652828418`** | **1 248** | 21.40 |
| step (4), deletions | `434.77155652828418` | 1 248 | 21.07 |

**Step (2) is bit-identical**, which is what makes the rest attributable: the loop restructure moves
nothing, so the 10.3× belongs to the stencil and to nothing else.

**It is not an implementation error, and that was checked before it was reported.** Report 04 §2.1's
identity holds at all four model pairs — the hand-computed quotient `(g_i − g_{i+1})/(h_i − h_{i+1})`,
`log_density_dt + mortality_rate`, and `−d(log dh)/dt` from a short integration agree to every printed
digit. Sign, pairing and staggering are right.

**Why M4 did not predict it.** M4's mean(cohort − sub-grid) is −0.0620 with sd 1.878, which reads as a
modest perturbation. But the census also records **max |cohort| = 142.85 against max |sub-grid| =
1.51** — the tail is two orders larger than the body, and the tail is what drives the trajectory. A
mean and an sd were the wrong summary for a quantity whose effect is set by its extremes. The
per-step cost falls 37% as predicted, and the 6× wall clock is mostly the accepted step count falling
3.8×, which says the right-hand side became markedly less stiff once a `1e-6`-probe derivative left
it.

**The evidence that would adjudicate this was not taken, and it is named in the plan.** Report 04 §3
says baselines need re-blessing "alongside §2.2's conservation diagnostic, **which is the number worth
presenting with it**": log `sum_j N_j` against its analytic mortality loss under both stencils, where
a sub-grid probe should leak at `O(dh g'')` and the cohort grid should not. That diagnostic is the
forward-model argument for the change and it has never been run — it was not in this packet's gates,
which is my omission. Report 04 §8 also names a second unrun check: a K93 census gradient with the
transport term's derivative present and absent, K93 having no leaf and so no staircase — "that is the
number that should have been taken before any of it was designed".

**So the decision is the owner's and the phase does not carry it.** A 10.3× change in offspring
production is a different model, not a re-blessing. What is owed before it can be judged: §2.2's
conservation diagnostic under both stencils, and report 04 §8's K93 comparison.

### Diagnosis, part one: the conservation claim holds, and it does not explain the 10.3×

Both adjudicators report 04 names are now run. Two arms, `03558de8` (sub-grid, bit-identical to
baseline) and `e820456e` (cohort grid), each reproducing its recorded offspring exactly, both probes
pure R over `collect = TRUE` history so nothing was instrumented.

**Report 04 §2.2's claim is confirmed.** `log N_j(t) + mortality_j(t)` is constant if
`dN_j/dt = −mortality_j N_j`, and `mortality` is a state, so the check needs no rate instrumentation:

| | max \|step drift\| | cumulative | worst node violation |
|---|---|---|---|
| TF24 sub-grid | 5.983e-01 | **+3.992** | 1.223 |
| TF24 cohort grid | 3.706e-06 | **−2.97e-06** | 6.62e-05 |
| K93 sub-grid | 9.676e-02 | −0.135 | 0.811 |
| K93 cohort grid | 1.459e-05 | −6.91e-06 | 2.48e-04 |

The sub-grid probe carries a spurious source, growing monotonically through the run; the cohort
grid's residual is at integrator tolerance and does not accumulate. Six orders on TF24, four on K93.
**So the forward-model argument for the change now exists**, where before it was asserted. Worded to
§2.2's own caveat: this is about the *dynamics* of `N_j`, not about how well `sum_j N_j` estimates
the true total — the rectangle quadrature error is untouched by either arm.

**But it does not explain the 10.3×, and the second measurement is why.**

| model | offspring change | steps |
|---|---|---|
| K93 — no leaf, no staircase, no reserve gate | **+1.39%** | 234 → 169 |
| FF16 — a leaf, no hydraulic optimisation | **+16.4%** | 210 → 236 |
| TF24 | **+932%** | 4 730 → 1 248 |

The defect being removed is the same kind and roughly the same per-node size in both models — worst
node violation 1.22 against 0.81, a factor of 1.5, cumulative 3.99 against 0.135, a factor of 30. The
*response* differs by about 670×. **A 30× difference in the defect cannot produce a 670× difference in
the response linearly**, and the gradient across the three models tracks physiological complexity
rather than the size of the conservation defect. This is report 04 §8's own "that is the number that
should have been taken before any of it was designed", and it exonerates the discretisation while
leaving TF24 unexplained.

**The most striking number in the diagnosis, and it was nearly buried.** `sum_j N_j` — the stand
count — peaks at **176.5** at `t = 12` under the cohort grid against **0.107** under the sub-grid
probe. A four-order excursion in population, in exactly the window where §5 records interior spacings
down to 8.2e-06. An `O(dh)` rectangle estimate on a grid that tight is where an amplification would
live, so **a discretisation exact in the count's dynamics can still be badly resolved as a density
field**. That is the distinction the conservation diagnostic cannot see, by construction.

**Two readings survive and the measurements do not separate them.** Either the cohort grid is the
correct dynamics and TF24's trajectory was held down by a spurious sink — the 3.8× drop in accepted
steps supports a less stiff right-hand side — or 434.77 is a coarse-grid artefact of the transient.
**The grid-refinement study is what separates them**: refine the node schedule two or three times and
ask whether the arms converge toward each other or the cohort-grid arm converges toward 42. Running.

### Diagnosis, part two: the two stencils are different operators, not two resolutions of one

The decisive measurement, and it needed no build — the pre-P2.4 tree has **both** operators live, so
both were evaluated on the same end-of-run state:

| model | `cor(cohort, sub-grid)`, interior | disagreement |
|---|---|---|
| K93 — `g` a function of height alone | **0.9625** | ~6% |
| FF16 — weakly coupled heartwood | **0.9789** | ~9% |
| **TF24** | **0.0519** | **~54%, opposite sign over most of the grid** |

TF24's interior cohort-grid values sweep monotonically through zero (−0.031 to +0.039) while the
sub-grid values stay uniformly negative (−0.060 to −0.234). **On TF24 the two are statistically
unrelated.**

**The mechanism.** `(g_i − g_below)/dh` is exactly `d(log dh)/dt` — the identity test and the
conservation diagnostic both confirm it. But that equals `−∂g/∂h` **only when `g` is a function of
height alone.** For a multi-state individual the two-node difference is a *total* derivative along the
cohort grid, `∂g/∂h + Σ_k (∂g/∂s_k)(ds_k/dh)`, and in TF24 the second term dominates. The ordering
across three models tracks exactly how much non-height state `g` carries: K93 none, 1.4%; FF16 a
weakly-coupled heartwood, 16%; TF24 storage and a reserve gate, 932%.

**So report 04 §2.1's identity is right and its scope was never stated.** Nothing in the derivation is
wrong; what is missing is the condition under which `d(log dh)/dt` is the compression term of a density
in height. That condition holds for K93 and nearly for FF16, and fails for TF24 — the model the whole
build is for.

### The boundary pair is not the driver

Ruled out by experiment rather than by argument. Excluding it entirely — the lowest cohort takes the
compression of the one above — leaves offspring at **469.1**, still 11× the baseline, with only the step
count recovering (4 319 against 4 730).

It is nonetheless pathological, and the split census quantifies it: mean |stencil| **8.36** at the
boundary against **0.129** interior, max 161.7, and **all 153 guarded pairs**. But it is 1% of records,
and its peak has the same signature as the interior peak — `g` 0.030 against `g_below` 0.125 at
`dh` 1.6 cm, a four-fold growth difference between neighbours 1.6 cm apart. **The boundary pair is the
worst instance of the state-difference problem, not a separate one.**

### Where the divergence accumulates

Not gradual. Total density diverges at **each node introduction from `t ≈ 6`**, jumping about 10× within
`Δt ≈ 0.15` where the sub-grid arm decays smoothly through the same interval:

    new: t 5.9999 D 33.6 | 6.0094 D 35.2 | 6.0530 D 49.1 | 6.1998 D 192.4 | 6.3431 D 333.5
    old: t 5.9418 D 39.7 | 6.0155 D 38.8 | 6.0906 D 37.9 | 6.1665 D  37.1 | 6.3422 D  35.2

That is the recruitment window, and it is where the state discontinuity between a freshly seeded node
and a reserve-depleted neighbour is largest — the same explanation as the operator disagreement.

### Two readings, and they are a modelling question rather than a numerical one

**Neither is taken here.** They differ in what the SCM's density variable means.

- **The cohort grid is right and the sub-grid probe was wrong.** Individuals do not cross a
  characteristic, so the count between two cohorts is conserved up to mortality whatever else the
  cohorts carry, and `log n = log N − log dh` then forces the cohort-grid form. On this reading the
  conservation diagnostic is decisive — the sub-grid probe leaks +3.99 and the cohort grid does not —
  and TF24's density genuinely spikes because a fresh recruit really does grow 4.8× faster than a
  reserve-depleted neighbour, so the interval really does collapse.
- **The density is a density in height alone, so it needs the partial.** The compression term of a
  height-marginal density is `∂g/∂h` at fixed non-height state, and a neighbour difference cannot
  supply it for a multi-state individual. On this reading the replacement for the sub-grid probe should
  be an analytic or AD partial derivative of `g` in height — not a neighbour difference — and the
  1e-6 probe was a poor implementation of the right quantity rather than the wrong quantity.

**A refinement study cannot settle this if the two operators converge to different limits**, which is
what the decorrelation predicts: adjacent states grow more similar as the schedule is refined, but
`ds_k/dh` need not vanish. A plateau in the gap between arms would therefore be a positive result —
evidence that the disagreement is semantic. That study is running with this interpretation supplied.

**What is not in doubt:** fixing the lowest cohort's treatment will not recover the baseline, so the
`new_node` staggering fork is downstream of this decision rather than the cause of it.

### What the packet closed, and it was an open question here

A tally over one production run, 1 078 893 guarded pairs:

    zero-width       141, every one the boundary pair
    non-descending    12, every one the boundary pair, min dh -0.0273 m
    interior grid     never non-descending

So the 141 zero-width pairs are report 04 §7.1's one-per-introduction prediction, now attributed; and
**the negative spacing is the newborn crossing below `height_0`, never an interior crossing.** This
file recorded that attribution as open. 12 in 1.08 M, so the guard's reading does not affect the
forward number either way.

**The guard reading taken:** `dh == 0.0` became `!(dh > 0.0)`, treating a non-descending pair exactly
as a zero-width one, which also catches NaN. The alternative — re-pairing by sorted height — was
rejected on a good argument: it would change *which interval a node owns* discontinuously in time,
and that node's `log_density` was established as `N/dh` for the interval it has held since birth, so
the right-hand side would jump at a crossing.

### My packet contradicted the corpus, and the packet was right to stop

I instructed it to drop `Species::compute_rates`'s `birth_rate` parameter. Doing so requires removing
`new_node.compute_initial_conditions` from that function — **which this file records as wrong**, caught
as a silent wrong value by 18 assertions, and explicitly restored. The packet identified the conflict,
implemented the corpus's reading and reported both. I wrote that instruction from my own superseded
version of the code, which is the second time this phase a packet has caught a stale premise in its
own brief.

### Owed if it is ever taken up

- `transport_census.h` becomes unreferenced once the sub-grid probe goes; its caller was the census
  hook whose subject was that probe.
- `test-control.R` and `test-support.R` reference the four removed `node_gradient_*` fields
  (3 failures), and `_snaps/model-version.md` lists their names.
- `test-scm.R`'s profiling comment attributing 50.1% of runtime to `growth_rate_gradient()` is now
  wrong, and the benchmark above supersedes it.
- `test-patch.R:89` pins a hard-coded FF16 `ode_rates` vector ending `-0.78726`, the old sub-grid
  boundary value.
- The boundary node's `log_density_dt` is now `0.0` — a node with no interval below it has no
  transport term — and the §2.1 identity test had to be restricted to interior intervals because the
  boundary node sits at `height_0` permanently and is not a transported characteristic. **That is a
  real asymmetry in the staggering** and it deserves a decision of its own.

## P2.3 — the Hermite evaluator: the numerics pass, and it forces the box-model decision

Three commits on `p2/p2-hermite`. **Written, gated, and held out of `p2/phase-2`**, for one reason
that is not about its numerics.

| gate | result |
|---|---|
| convergence on a smooth target | value ratios **15.906, 15.969, 15.991**; slope **7.957, 7.986, 7.993** — O(h⁴) and O(h³) |
| the production rate, recorded beside it | mean-normalised orders **2.9 value, 1.9 slope**, so about `h^2.5`, matching M3 |
| `slope(u)` is the exact derivative of `eval(u)` | worst 3.221e-10 against a central difference — truncation |
| locality on a live tape | `d(eval)/d(knot_2)` is 0.5 in a span touching knot 2 and **exactly 0** two spans away |

The locality gate is the one the reverse pass rests on: a C2 fit makes one light read depend on every
knot through a band solve, and this makes it depend on two.

**Forward effect: offspring `42.179817344974609` at 4 798 steps, −0.030%, and ms/step regresses about
3%** (24.14 → 24.80 and 25.07 on two runs of the new arm; the base arm was timed once, so the last
point of that 3% has no variance estimate). Report 03 §5.4's "6% faster on value, 2.6× on the pair"
are *query-side* at matched knot count; what this adds is build-side, because the fused reduction runs
at all 65 knots at every stage. Inside the +10% band, and P2.4 would more than repay it.

**Five pinned assertions move, and every one moves *toward* its blessed value** — `test-strategy-ff16.R`'s
offspring 16.872 → 16.8846 against a blessed 16.88946, and similarly for the other four. None
re-blessed.

### The box models stop running, and that is the decision this phase kept deferring

`test-canopy-methods.R:108` asserts `flat-top-soft-box` **runs**. It now raises "Vertical canopy slope
is defined only for the smooth Yokozawa profile", because the field asks for a slope at every knot and
P2.2's `Q_and_q` refuses the box models. **A supported FF16/K93 shading model ceases to work.**

This is the same decision P2.1 and P2.2 each reached from their own side, now forced rather than
owed. Two readings, and the packet took neither:

- **The refusal stands and the box models are withdrawn.** What the code does today, and the direct
  consequence of P2.2's already-landed guard.
- **The field falls back to a value-only build for those models.** That means two evaluators live at
  once, which is a new mechanism and so a design choice.

Worth adding to the argument: a box profile is a *step*, so its slope is zero almost everywhere and
undefined at the step. A Hermite over it is not obviously the right object regardless, which is a
reason the first reading may be the honest one — but it withdraws a shipped capability from two
models, and that is the owner's to weigh.

### An odelia gap this exposed, and the R-API break that follows from it

`hermite_interpolator` exposes no accessor for its knot values or slopes. So `r_get_state()` reads the
data back through `value_and_slope(x_k, …)`: the value at a knot is exact, but the slope returns as
`fl(fl(m·h)·fl(1/h))` and can differ from the supplied `m` by an ulp. And `ResourceSpline$spline`
could not stay R-facing at all — RcppR6 needs a registered class, which would need `get_x`, `get_y`,
`eval` over a vector and `xy` on odelia's type. The field was replaced by a three-column `state`
matrix.

**So the R-API break is a consequence of the odelia gap, not of the Hermite.** The packet correctly
refused to change odelia, that being a cross-package change outside its allowlist. Adding those
accessors is the fix and it belongs to odelia.

`test-environment.R` loses four more assertions to the removed `spline<-` setter; the `#253` floor it
guarded is unchanged in `get_value_at_height` and simply no longer reachable by that route.

## The phase as it stands, gated on the merged tree

`p2/phase-2` = P2.7 + P2.1 + P2.2 + P2.6. One build at the pinned build, 0 occurrences of `-O0`,
every gate re-run in the orchestrator's own worktree.

    derivs(y, t) twice, bitwise:  TF24 0 of 1137   FF16 0 of 686   K93 0 of 490

| | offspring | steps | seconds | ms/step |
|---|---|---|---|---|
| plant `p1/audit-fixes` | `42.176246845059751` | 5 105 | 116.2 | **22.76** |
| **`p2/phase-2`** | **`42.192676883315706`** | **4 854** | 116.0 | **23.90** |
| FF16 | `19.806714238717067` | 210 | | |
| K93 | `0.030552896191851354` | 234 | | |

**Composite forward shift +0.039% on offspring**, FF16 −0.095%, K93 +0.020%. Four changes, three of
which move a number, composing to under a twentieth of a percent — the Phase 0 pattern again, and
below the 0.145% the controller re-rolls by, so the *step counts* are the robust part.

### A baseline I mislabelled, corrected

I reported P2.6's result as "23.98 ms/step against a 24.3 **pre-phase** baseline". **24.3 is P2.7's
figure, not the phase's baseline.** The pre-phase baseline is `p1/audit-fixes` at **22.76 ms/step**,
so the phase costs **+5.0% per step**, not a saving. It is inside the plan's +10% tolerance and the
polish is genuinely paid for relative to where it started — but "faster than baseline" was wrong, and
it is the same error this corpus keeps finding: a ratio quoted against the wrong arm. P2.4 would
repay it several times over if it is ever taken; P2.3 would add about 3%.

## Phase 2, closed

`p2/phase-2` = P2.7, P2.1, P2.2, P2.6 and P2.3, plus the soft-box slope. Fourteen commits off
`p1/audit-fixes`. P2.5 is answered as a measurement; **P2.4 is out of scope** with report 10 as its
home. One build at the pinned build, 0 occurrences of `-O0`, every gate re-run in the orchestrator's
own worktree.

    derivs(y, t) twice, bitwise:  TF24 0 of 1137   FF16 0 of 686   K93 0 of 490

| | offspring | steps | shift |
|---|---|---|---|
| `p1/audit-fixes` | `42.176246845059751` | 5 105 | — |
| **`p2/phase-2`** | **`42.179817344974609`** | **4 798** | **+0.0085%** |
| FF16 | `19.834058960443031` | 209 | +0.043% |
| K93 | `0.030538172107758225` | 240 | −0.028% |

**Six tasks, three of which move a forward number, composing to under a twentieth of a percent** —
and both simpler models keep their exact step counts, so their figures are the change itself rather
than the controller re-rolling.

Suite: **1 309 pass, 0 fail**, plus one environmental error (`FF16_generate_stand_report` needs
pandoc). Re-blessed: FF16's offspring and `ode_times`, the deep-crown baseline, `GSS_tol_abs`'s
default. Migrated rather than re-blessed: three tests whose subject stopped existing (below). Relaxed
with a reason: one 1e-21 assertion.

**On timing, less than I said earlier.** This session's wall clocks for comparable trees ran 97 s to
164 s depending on how many packets were building concurrently, so **absolute times are not comparable
across the session** and no phase-level ms/step is quotable from them. What is quotable is each
packet's own same-session ratio: P2.1 recovers 11% per step, P2.6 costs +42% at step (1) and −1% with
step (2), P2.3 costs about +3%, P2.2 is free.

### Two defects P2.3 shipped, and both were mine to catch

**It segfaulted R.** `ResourceSpline::clear()` emptied the interpolant, and every query reads its
bounds to decide whether a height is in domain — so `max()` read `x.back()` on an empty vector and
`get_environment_at_height` on a cleared environment crashed. The fitted spline tolerated it; a
Hermite does not. Clearing now restores the flat open field the constructor starts from, which is what
a cleared light environment means.

**And setting the light field from R had stopped being possible.** That went through
`env$light_availability$spline <- interpolator`, and the `spline` field cannot be an RcppR6 class once
the interpolant carries a slope per knot. `init_interpolators` is now exposed, taking heights, values
and slopes as one vector.

**Both were missed because `test-scm.R` and `test-environment.R` were not in the gate list I wrote**,
which named the strategy files, `test-patch.R` and `test-canopy-methods.R`. The packet reported the
`test-environment.R` failures faithfully and I read them as expected fallout from a declared interface
change. **A test that can no longer express its subject is not a moved baseline** — `spline$size`
returning NULL is a renamed accessor, `spline <- interpolator` erroring is a capability gone, and
telling them apart is the orchestrator's job.

**A third thing fell out of it: the old "manually set environment" test never set the environment.**
`light_availability` is a field, so reading it copies; the old test mutated the copy and then asserted
the copy against its own input, which passes whatever the environment holds. The migrated test does
the get-mutate-assign-back round trip and asserts on the environment.

### The box-model question dissolved rather than being decided

`flat-top-box` and `flat-top-soft-box` are both teaching devices and `canopy_shape.h` says so.
`flat-top-box` is *"a deliberately naive variant … the model does not run. See the vignette"* — its
test asserts it fails, so nothing was withdrawn and P2.3 only changes which error it raises.
`flat-top-soft-box` runs, and it is a cubic smoothstep: `d/dt` of `1 − t²(3 − 2t)` is `−6t(1 − t)`, so
`q = 6t(1 − t) / ((1 − lo) H)`, exact, vanishing at both ends of the transition. Implemented rather
than deferred — filing an issue for a one-liner while shipping a regression to a working model was the
wrong trade. **No capability withdrawn, no fallback mechanism, no runtime branch.**

### Owed

- **A newborn should probably inherit the boundary condition in the completed field**, not in the
  field that excludes the boundary interval. A recruiting cohort of density `n_b` does shade its own
  leaves over its crown, and unlike the field build itself this is not circular. That means re-seeding
  after the field build; the 1e-21 assertion above is what it would restore. Recorded rather than done,
  because it is a modelling change and a re-blessing pass is the wrong place for one.
- **`hermite_interpolator` has no accessor for its knot values or slopes**, so `r_get_state` reads them
  back through `value_and_slope` and a slope returns as `fl(fl(m·h)·fl(1/h))` — up to an ulp from what
  was supplied. Adding the accessors belongs to odelia and would also let `spline` be R-facing again.
- The dead `ResourceSpline` constructor arguments, which now select nothing.

## The close-out review, and what reading the diff found that the sweep did not

Run at `5fd351e9` as the phase's review pass: the reports re-read against the code, the merged diff
read in full, and `style-sweep.sh` over it.

**The keystone gate re-run in the phase's own worktree, no rebuild.** `derivs(y, t)` twice, bitwise:
**0 of 1137** (TF24), 0 of 987 (FF16), 0 of 705 (K93). TF24 reproduces `42.179817344974609` and K93
`0.030538172107758225` to the last bit against the closure above. *The FF16 arm of this check was
configured differently from the phase's — one strategy added on top of a base that already carries
one — so its offspring is not comparable and only its purity count is quoted.*

**The sweep's three hits are all candidates rather than violations**, as §7 says to expect. The `#253`
issue tag in `resource_spline.h` is pre-existing — 2 occurrences in the base, 2 in the tip, so the
phase added none and only reworded the line. `transport_census.h` is not a dead file: it is referenced
from `species.h`. The generated-file hits are the yml regeneration, disclosed by the packets.

**What reading the diff found instead, and the sweep structurally could not.** Three comments told the
reader to prefer a code path P2.1 deleted — two `NOTE: We should probably prefer to rescale when this
is called through the ode stepper` and one `probably worth just doing a rescale there?`. A comment that
was true when written and false after a deletion is invisible to every grep in the sweep, because
nothing about the line changed. Removed in `0abc7873`, comments only, token-identical.

**And one thing in the merged tree reads as P2.4 having landed.** `Species::growth_rate_gradient(i)` —
the cohort-grid stencil — and `transport_census.h` are both on `p2/phase-2`, because the census is M4's
instrument and the stencil is what it compares against. Neither is on the rate path: the census is
behind `PLANT_TRANSPORT_CENSUS` and the stencil's only caller is the census, which is why the reference
run reproduces exactly. But **the merged tree's guard is `dh == 0.0`, where the reading actually taken
on `transport/cohort-grid-stencil` is `!(dh > 0.0)`** so that a non-descending pair and a NaN are caught
too — so the two copies of the stencil differ, and the one in the shipped tree is the superseded one.
M4 is answered, so the census's subject is closed. Recorded in `build-plan.md`'s Phase 2 preamble and
left in place rather than removed, because removing it is a code change with a rebuild and a re-gate
after the phase was closed.

### Four reports carried claims Phase 2 settled, and none of them said so

Corrected at the head of each, with the evidence here. Reports 00 and 07 needed nothing — report 00
§4.3 records TF24's inline growth-gate smoothing correctly (it was this file and `ORCHESTRATOR.md` that
carried the false "hard and un-smoothed" premise, already corrected above), and report 07's floor
censuses were confirmed rather than moved.

- **Report 03 §4's "already correct for every strategy" was false**, and it is the one load-bearing
  error in the report the whole interpolant change rests on. `q` is the exact negative derivative of
  the *Yokozawa* kernel; FF16 and K93 also accept two box models that reach competition through
  `leaf_area_above`. Also superseded there: §5.5's unattributed 91% was never attributed but was
  *deleted*, C2 and C5 are void with `rescale_spline` gone, and §1b's bit-identity premise is
  arithmetically false.
- **Report 02 §4's zero pinned-solve count predates P0.1, P0.2 and P0.12** and is unverified against
  the leaf that now exists, while a Phase 2 probe at TF24's own defaults found every state pinned.
  P3.2's shape depends on which is right. §6.5's polish prediction was beaten (9.587e-09 against a
  forecast 1.6e-08..4.7e-07).
- **Report 01 §3.1's 3.5e-04 bound held** — 0 of 66 290 field builds exceed it — and both of its
  conclusions were right about the numerics. "The lag is not a defect to fix" was wrong about the
  consequence, and the mechanism that closed it is a reordering rather than the Picard step this corpus
  proposed.
- **Report 04** already carried its banner.

**The lesson, and it is about this corpus rather than this phase.** A report is corrected when its
*conclusion* is replaced — report 04 got a banner within the session that replaced it. What nothing
was catching is a report whose conclusion stands while a sub-claim inside it is falsified, because no
document is looking at it: the finding lands in this file, the plan gets its correction, and the report
keeps stating the false thing to whoever reads it next as the section that owns the mechanism.
**Reading the reports against the code is the pass that catches those, and it belongs at phase close
rather than at phase start.**

# Phase 3

Branch off plant `p2/phase-2` (`0abc7873`), against odelia `p1/audit-fixes` (`43c8561`) installed
into a per-packet library and verified by grepping the installed header. The reference run reproduces
in each worktree at the pinned build: offspring `42.179817344974609`, 4 798 `ode_times`.

## The active build, group A — the library math reached by name

`c0037d9a` on `p3/active-instantiation`. `std::pow`, `std::max`, `std::min`, `std::exp` and
`std::sqrt` are constrained to arithmetic types, so on an active scalar XAD's overloads are found only
by argument-dependent lookup. Ten sites, one cause, **three fix shapes** — which is one more than the
packet's brief predicted:

- a block-scope `using std::X;` plus an unqualified call, at seven member-body sites;
- `S(0.0001)` promoting a literal at the light floor, because `std::max`/`std::min` are *homogeneous*
  templates and ADL cannot rescue a mismatched pair;
- `TF24_Pars::power`, a static helper, at the three **default member initialisers** — an NSDMI has no
  block to put a `using` in. This is the only genuinely new construct in the diff.

| gate | required | measured |
|---|---|---|
| the probe's plant errors | group A gone | **34 → 24**, and the 6 libstdc++ consequence errors with them |
| `TF24_Strategy<double>` still instantiates | 0 errors | **0** |
| the gate bites | more errors when re-qualified | 24 → **26** on re-qualifying one `sqrt` |
| **bit-identity at the pinned build** | `42.179817344974609` / 4 798 | **exact**, 0 occurrences of `-O0` |

**The value gate was the orchestrator's to take and the packet said so.** With no build in its budget
the packet argued structurally — for `double` arguments there are no associated namespaces, so ADL
contributes no candidate and the overload set stays `{std::X}` — and flagged that `TF24_Pars::power`
moves the argument *types* at three sites and so wanted measuring. It does not move the value: measured
bit-identical. **A structural argument plus a measurement is the right division here**; the argument is
what made the measurement worth one build rather than a bisect.

**Two boundaries now refuse by name instead of through a wall of overload-resolution errors.** `Leaf`
carries `double` and wants a supplied local Jacobian; `height_seed` finds its root by iteration and must
be declared through its residual. Each is an `if constexpr` whose `double` branch is the original text
verbatim, so nothing reaches codegen that did not before, and each `static_assert` names the reason. A
reader meeting these now gets one sentence where they previously got forty lines about
`__gnu_cxx::__promote`.

### What the census implies for the phase's order, and it inverts one of the plan's dependencies

The packet flagged a tension between two of its own sections and was right; run down, it is bigger than
it looked. **Of the 24 remaining errors, five are on the block's own path** — and the block is what a
whole-`Patch` recording records.

| site | cause | on the block's path? |
|---|---|---|
| `:840` | `QK::integrate` takes `double` limits, returns `double` | **yes** — this is `compute_average_light_environment`, the mean-light path itself |
| `:1054` | the same, in `net_mass_production_dt` | **yes** |
| `:1023` | `optimise_at` → `Leaf::set_physiology` | **yes** |
| `:744` | the consumption-rate funnel's conversion | **yes** |
| `:1272` | `util::is_finite(double)` | **yes**, through `mortality_dt` |
| `:1406`, `:1456` | `height_seed`'s `uniroot`, the `Leaf` constructor | **no** — both are `prepare_strategy`, which the design forbids inside a block |
| 17 sites, `:1057`–`:1090` | DeepCrown's `std::vector<double>` accumulators | **no** — a shading model TF24 does not default to |

**So V1 is not available when the plan says it is.** V1 compares steps (a)–(d) against one whole-`Patch`
recording, P3.1 closes on V1, and the plan orders P3.1 before P3.2. But a recording cannot be taken
until the block instantiates, and the block does not instantiate until the leaf boundary exists in at
least some form. **The leaf boundary is P3.2's.**

The resolution is already in the plan and is not a new mechanism: **P3.2 step (1) is "the block with the
leaf held constant"**, and that held-constant form is exactly what makes the block instantiate — the
leaf's inputs converted to passive, the leaf solved in `double`, its outputs entering the tape as
constants. Its derivative is then zero by construction, which is *correct* for step (1) and is what V2
step (1) already asks for. So:

**the leaf seam in its held-constant form comes before P3.1, not after it** — and it is the one item on
the critical path that the plan places on the wrong side of its own verification. Nothing else moves:
P3.2's steps (2)–(5) then add the partials that make the seam carry a derivative.

`QK` templating joins it, since two of the five are the crown integral, and `build-plan.md` §3 already
lists `QK` templated as taken from the AD branch. Neither is a design question; both are prerequisites
that the task list does not name.

### Declared deviations, and what the brief got wrong

The packet reported three, and two are mine:

- **My document pointers were wrong.** `docs/implementation-notes.md` is at the *superproject* root, not
  inside the plant worktree, and `agents.md` is at the worktree root rather than under `plant/`. Cost the
  packet a few minutes of searching. **A packet works inside a worktree and the corpus lives above it**;
  cite absolute paths.
- **My §1 target was unreachable as written** — "the mean-light path instantiates" — because group D sits
  on that path and my own §3 ruled it out of scope. The packet identified the contradiction, implemented
  the reachable half and said so, which is the wanted behaviour. §3 was the section that was right.
- The "ten errors, one cause" framing undersold it at one cause with **three** fix shapes.

`TF24_Pars::power(base, exponent)` is two same-typed arguments of unrelated meaning, which the style
rules name as a silent-swap hazard. Accepted here — the argument order mirrors `pow` universally and
there are three call sites — but recorded, because that is how the corpus asks for it. Also recorded by
the packet: `pow_eta_general` still takes `eta` as an unguarded active exponent, so `pow_eta`'s `u <= 0`
guard does not protect a caller reaching the general form directly.

## The collar polish, censused over a production lifetime

`5b4316aa` on `p3/collar-census`. The measurement §11.4 asks for before P3.2, because report 02 §4's
zero pinned solves predates P0.1, P0.2 and P0.12 and a Phase 2 probe at TF24's own defaults disagreed
with it at every state. Gated on `PLANT_COLLAR_CENSUS`, moments and extremes rather than 7.35 M rows.
**Both arms re-run in the orchestrator's own session**, in the packet's worktree with nothing building
in it.

**Classified on the polish's own control flow, never on a distance to the bracket end** — that test is
tolerance-dependent and Phase 2 measured it reporting nearly every state as pinned at
`GSS_tol_abs = 1e-1`.

| class | production count | share | `\|R\|` max |
|---|---|---|---|
| interior — `\|R\| <= R_tol` | 1 402 905 | 19.1% | 9.9999e-12 |
| **pinned, all four causes** | **0** | **0.00%** | — |
| exhausted — five Newton steps taken | 5 950 425 | 80.9% | **1.0019e-06** |
| | **7 353 330** | | |

`max_patch_lifetime = 105.32`, rainfall 1, one species, `lma = 0.1978791`, five layers,
`GSS_tol_abs = 1e-3`, mean-light. `min_bracket` 1.3518. States: `psi_wet` 0.0137–0.1691, radiation
149–900, `area_leaf` 8.8e-05–49.40.

**The zero is a real zero, and the third gate is what makes it publishable.** A census reporting zero
is indistinguishable from a dead counter, so the same instrument was driven where pinning is known to
occur — `max_patch_lifetime = 20`, rainfall 0.05 — and returns **990 724 pinned of 1 333 130 (74.3%)**.
Without that arm the production zero would carry no information at all.

**So today's tree agrees with report 02, at 0 in 7.35 M against its 0 in 4.37 M**, and P3.2's shape
follows report 02: the interior envelope case is what production solves need, and the bound branch is
insurance. Report 02 §4's correction note can be settled.

### The packet killed my explanation of the contradiction, from the census

I proposed that the Phase 2 probe's `PPFD = 900` passed as *absorbed* radiation was the error, since
the model forms `radiation = k_I · max(L, 1e-4) · PPFD` and both factors are below one. **The census
rules that out:** production radiation reaches **exactly 900** with a mean of 359, so 900 is the bright
end of the production range rather than ten times it. Nor is soil potential the discriminator — the
probe's 0.015–0.17 is almost exactly production's 0.0137–0.1691, and production is interior across all
of it at radiation up to 900.

The axis that does separate them is **leaf area against root capacity**: production `area_leaf` runs to
49 m² with a mean of 17, and every pinned state in either arm sits below 0.56. A hand-assembled `Leaf`
gets whatever root mass an assumed height implies, where production co-varies root mass with leaf area
through the actual allocation — and "root hydraulic resistance dominating, profit slightly negative" is
the signature of too little root for the leaf area. So the hand-assembly is still the error and **the
mis-set input is the root side, not the radiation.** Consistent with the census rather than measured,
because confirming it needs the hand-assembly the packet was forbidden.

### A correction to P2.6's record, which this phase's measurement forces

**P2.6's gate — `|R|` below 1e-07 at every sampled state, measured worst 1.128e-13 and later 9.587e-09
— passes on its own sample and does not hold in production.** 80.9% of production solves exhaust five
Newton steps with `|R|` up to **1.0019e-06**, mean 2.4e-08. Same cause the notes already record from the
other side: `R_tol = 1e-11` is below `R`'s own resolution, because the `ci` root-find inside it carries
`ci_abs_tol = 1e-6`. What was wrong was the *scope* of the number, not the number — P2.6's 24 states
come from the test file's leaf (`root_b = 1.29`, `g1_TF24 = 46.3`, 10 kg of root mass), and that leaf
polishes three orders finer than the strategy's own defaults do.

Two consequences, and the first is the one that matters.

- **Budget the envelope row against `|R| ~ 1e-6`, not 1e-13.** With `|Π_pp| >= 0.1723` the displacement
  from the true stationary point is at most about **5.8e-06 MPa**, against 5e-05..2.8e-04 unpolished. So
  the polish still buys one and a half to two orders on the displacement, and on `R` itself two to three
  orders against the 8.8e-05..1.2e-03 it started from. **The "five to six orders of margin" recorded for
  P2.6 is overstated and is corrected here to two to three.** The envelope row remains valid at first
  order in the displacement; what changes is the tolerance a later gate may state.
- `pinned_step_outside` is a guard that exists only since P2.6, and it dominates the dry arm at 990 719
  against 4 for `bound_b`. So **report 02's "pinned at bound_b" column is not the same measurement as
  this one**, even where both read zero. Two zeros agreeing is weaker evidence than it looks.

**This is the third time a figure in this corpus has been quoted outside the configuration it was taken
in** — after the transport census's mean-versus-tail and the ratio quoted against P2.7's arm. The
pattern is specific enough to name: **a gate taken on a hand-assembled or test-fixture object is not a
statement about production**, and the two are worth separating in the wording every time.

### Declared deviations, and what the brief got wrong

Four, and three are mine:

- **My run and build caps were arithmetically wrong.** §8 said "one clean build" where a baseline of the
  untouched worktree plus an instrumented build is two; §4 said "two runs total, do not run more" and §5
  then mandated a third. The packet ran four runs and two builds, correctly, and reported the
  contradiction rather than silently obeying the cap. **Cost every gate, then count them again after
  adding the last one.**
- **`docs/` is not in the worktree**, the same error as the other packet in this wave. Cite absolute
  paths into the superproject.
- **`grep -c -- '-O0' log` exits 1 when the count is 0**, so the recipe's own success condition returns
  a failing shell status and the packet's first build read as failed when it had completed. Use
  `|| true`. This is in the build recipe every packet gets, so it is worth fixing at the source.
- `env$rainfall <- rain` is not the API; it is
  `env$extrinsic_drivers_set_constant("rainfall", rain)`.

**Not recorded: height.** `Leaf` never receives it — `set_physiology` takes `area_leaf` and
`sapwood_volume_per_leaf_area` — so the census records `area_leaf_`, which is monotone in height at
fixed trait. The same reachability gap the corpus already flags, now blocking instrumentation by state
as well as inspection from R.

## The record-and-sweep multiplier, measured — 8x, not 3 to 5

`odelia/scripts/vjp_cost.cpp`, an untracked probe stating its own configuration; no odelia header
touched. **Re-measured in the orchestrator's own session** and it reproduces, which matters here
because it is a timing and another build was running in both cases.

| size | arm D | arm R | R/D |
|---|---|---|---|
| 75 inputs, 17 knots, 10 quadrature points | 1.557 us | 23.637 us | 15.18 |
| **171 inputs, 65 knots, 40 points** | **4.516 us** | **47.900 us** | **10.61** |
| 561 inputs, 260 knots, 160 points | 16.038 us | 144.390 us | 9.00 |

Marginal, which strips the fixed cost: **8.20** small-to-mid and **8.37** mid-to-large.

**Two findings, and the second is worth more than the first.**

**The multiplier is flat in block size, so the budget's structural assumption was right** — the
recorded arithmetic costs a flat ~8x and the falling R/D is entirely a fixed per-call cost. But it is
flat at 8, not 3–5, and at the block's own size the applicable figure is 10.6. Re-costed with the two
recordings per (stage, cohort) that deferring P2.4 forces: **~670 s, so 5 to 6 forward runs rather than
2 to 3**, and the saving against 51 traits by central difference is **~17x** rather than 30–50x.
Decisive still; the stated total does not hold. `build-plan.md` §8b carries the table.

**Tape construction is 22% of the reverse term and hoisting it is the cheapest win on the budget.**
Construct-and-destroy alone is **10.44 us** against arm R's 47.9 us, and an empty record-seed-sweep at
171 inputs is 13.11 us — so registering, seeding and sweeping a trivial recording costs under 3 us on
top of the tape. `vector_jacobian_product` builds one per call, of order 3.9 M times. Reusing a tape
with `newRecording()`, which `compute_jacobian` already does, is ~**108 s** off a ~670 s gradient and
takes R/D at block size from 10.6 toward ~8.2. Phase 1 recorded the tape-per-call as "the first thing
to measure when the sweep's cost is taken" — it is measured, and it is now the first thing to fix.

**The recording-size invariant still holds**: 52 080 bytes with one output adjoint seeded and 52 080
with all eleven. So peak is 46 MB of trajectory plus ~52 kB, and the 2 GB gate has four orders of
headroom rather than three.

**Why the number is trustworthy, stated because a timing usually is not.** The arms are interleaved in
one loop, so contention moves numerator and denominator together — and the proof that this worked is
that two measurements taken under different loads agree to within a few percent. Arm D is defended
against dead-code elimination through a `volatile` sink, and its times scale 1 : 3.2 : 11.5 against a
quadrature count scaling 1 : 4 : 16, which is the independent check that the compiler did not delete
it. Built at `-O2 -DNDEBUG`; a `-O0` ratio would be biased rather than merely noisy, because the two
arms optimise very differently.

### What the packet could not do, and one thing it corrected in the brief

The block is a **stand-in**, not `Individual::compute_rates`: it matches the declared shape and uses the
real interpolant, but not the real arithmetic mix, so 8x is the multiplier for
power-law-plus-interpolant work rather than for that function. Arm D landed at 4.5 us against the 6 us
target, which biases R/D upward only through the fixed cost and leaves the marginal 8x untouched. And
the size sweep moves knots and quadrature points together, so the interpolant's share is not separated
from the quadrature's.

**My brief was wrong that R and Rcpp includes were probably unnecessary.** `gradient.hpp` reaches
`ode_util.hpp` and thence `RcppCommon.h`, so both include paths, `-lR`, an `Rcpp.h` include and
`src/Tape.cpp` are all mandatory — **XAD is not fully header-only**, because
`xad::Tape<double,1>::active_tape_` lives in that translation unit. Worth knowing before anyone else
tries to compile an odelia probe standalone. The packet also noticed that this corpus records the
recording-size invariant as "one adjoint versus three" in one place and "one versus eleven" in another;
both pass, and the two wordings should agree.

## The tape hoisted out of the product — and my predicted failure mode was the wrong one

odelia `2c3159c` on `p3/vjp-tape-reuse`. `vector_jacobian_product` takes the tape from its caller and
reuses it; the four-argument form is kept, constructing an **inactive** tape and delegating, so a
foreign active tape is still caught in one place. The stopping guarantee moves from "no tape is active"
to "the tape handed in is the active one", which is the ownership reading rather than a weakening.

**Re-verified in this session**: suite **330 pass, 0 fail, 0 error, 2 skip** from a fresh install into
my own library, verified by grepping the installed header; probe reproduced at mid **T/D 5.56**
against the packet's 5.47.

| mid size, 171 inputs | before | after |
|---|---|---|
| arm R — record and sweep | 47.9 us | — |
| arm T — the same on a reused tape | — | **26.1 us** |
| ratio against one `double` evaluation | 10.22 | **5.56** |
| marginal multiplier | 8.45 | **5.51** |

**The saving is about twice what I forecast, and the reason is instructive.** I predicted 10.6 to ~8.2
from the 10.1 us a tape costs to construct and destroy. Measured: 10.2 to 5.56, a **21.8 us** cut
against a **10.1 us** tape — so the hoisted cost is **2.2x the tape alone**. A fresh tape also grows its
containers to 52 kB from nothing on every call, where `clearAll()` empties the recording and keeps the
capacity. **The 21% tape-construction share was a floor, not the answer.**

Re-costed: the reverse term falls from ~496 s to **~260 s**, a gradient from ~670 s to **~430–460 s, so
3.7 to 4.0 forward runs**, and the saving against 51 traits by central difference rises to about
**26x**. The hoist alone is **~236 s**.

### The gate I specified would have passed a change that leaks

I told the packet that an unreset tape "silently accumulates the previous call's adjoints". **It does
not.** `newRecording()` clears the derivative flag, so `initDerivatives()` zero-fills and **the adjoints
stay correct**. The real fault is unbounded growth: destroying a registered input releases its
derivative slot only when the slot is the last one, and a `std::vector` is destroyed front to back, so
no slot is ever released. Measured on a standalone probe with `newRecording()` alone: memory
**276 → 332 → 388 → 444 → 500** and variable count **7 → 14 → 21 → 28 → 35** over five calls, **with
identical adjoints throughout**. Over 3.9 M calls that is the whole gradient's memory. `tape.clearAll()`
is the fix.

**So a gate 2 written the way I specified it — compare the adjoints of a reused tape against a single
call — passes on a change that leaks the entire budget.** What caught it is that the packet also
asserted the **recording size** is constant across reused calls, and its negative control shows the
sizes climbing 276, 324, 372, 420 with `clearAll()` removed. This is §0.6 again, from the inside: I
asked for a gate that could not distinguish "correct" from "correct and leaking", and the right
discriminator was a quantity I had not thought to name. **When a change is about reuse, assert the
resource, not only the answer.**

### Also from this packet

- **My baseline suite count was stale.** I said 322; it is **327**. Both figures are in this file — 322
  at Phase 1's close and 327 after the audit that followed it — and I quoted the earlier line. A
  packet-facing baseline must be the count at the tip it is given, not the count at a phase boundary.
- **The saving is demonstrated and not yet realised.** Nothing in odelia calls the primitive outside its
  tests, so **no consumer holds the reused tape yet**. Whoever writes the cohort loop must hold one tape
  across it; calling the four-argument form inside that loop restores the old cost **with no test
  complaining**. That is now the load-bearing note for P3.2, and it belongs in the packet that writes
  the loop.
- Not measured: whether a narrower reset than `clearAll()` — restoring to a stored position — is cheaper
  still. `clearAll()` is correct and gets the ratio to 5.5.
- A trap in that test file: the bodies live inside a single-quoted R string passed to `sourceCpp`, so an
  apostrophe in a C++ comment is a parse error before any test runs.

## The active build is larger than the census said, because the census was too narrow

**`Individual` holds `Internals<double> vars` (`individual.h:205`), not `Internals<S>`.** So the whole
per-cohort state surface is passive — `state(int) -> double`, `rate(int) -> double`,
`set_state(int, double)`, `compute_competition(double) -> double`, `consumption_rate(int) -> double` —
and instantiating `Individual` at an active scalar fails at **seven** sites, every one handing `vars` to
a strategy that wants `Internals<S>&`.

**This is Phase 1's group B, and it is not closed.** That census named "the `double` state and aux
boundary: 12 sites" and this is what it meant. What made it look closed is that Phase 1 read the funnel
as narrow — "the single place `S` must be dropped is the plant's water draw" — which is true of
`consumption_rates` and not of `vars` as a whole.

**Why my own census could not see it, which is the lesson worth more than the finding.**
`template class plant::TF24_Strategy<active_scalar>` **never instantiates `Individual`**, so the probe
that reported 34 errors and then 24 was structurally blind to the container holding the state the block
differentiates. I wrote §0.6's rule into a packet — *ask what would make the gate pass vacuously* — and
then shipped a gate that could not distinguish "correct" from "not instantiated". Measured by
instantiating `Node` instead, which pulls `Individual` in: seven more sites.

So the block's remaining surface is three tasks, not one:

| | what | reaches |
|---|---|---|
| 1 | `QK` carrying a scalar, `util::is_finite`, the consumption funnel, the leaf seam | `qk.h`, `util.h`, `internals.h`, `tf24_strategy.h` — in flight |
| 2 | **`Individual`'s state store carries `S`** | `individual.h`, and **33 call sites across six headers** — measured, below |
| 3 | the transport probe made scalar-generic | `node.h`, `individual.h`, and `gradient.h`'s generic helpers |

**Task 2's surface, measured rather than estimated**, so the packet can be costed: eleven accessors on
`Individual` return or take `double` (`state`, `rate`, `set_state`, `aux`, `consumption_rate`,
`compute_competition`, `compute_competition_and_slope`, in their name and index forms), and their callers
are **`node.h` 16, `species.h` 8, `stochastic_node.h` 3, `stochastic_species.h` 3, `patch.h` 2,
`stochastic_patch.h` 1 — 33 in total**. The three stochastic headers never carry an active scalar but
share the plumbing, so they are in the sweep for the same reason the plumbing sweep took them in Phase 1.

**One line must stay `double` and it is the seam that makes this safe:** `Internals<double>
r_internals() const` is the R boundary, and only `double` crosses it. So the change is
`Internals<S> vars` with `r_internals` converting, not `Internals<S>` all the way out.

**And the probe's severance is compile-caught rather than silent, which is the one piece of luck here.**
`Individual::growth_rate_given_height` appears in the failing instantiation chain at `individual.h:167`,
required from `Node::growth_rate_gradient` at `node.h:212` — so the passive transport path does not
quietly return a zero derivative, it fails to build. That is only true while the state store is
`double`; **once task 2 lands, the `-> double` lambda becomes a silent passivation rather than an
error**, so task 3 must land with task 2 and not after it. Recorded because the ordering is the whole
risk: the compiler is currently doing the work that the sweep's new check will have to do afterwards.

## P3.5's transport adjoint, designed — and the probe has no active path at all

The design §11.2 of `ORCHESTRATOR.md` puts before P3.2, because P3.2 freezes the block's boundary and
this decides how many times the block is evaluated. Read from the code rather than from the plan, and
the plan's premise does not hold.

**Report 04 §5 records that "differentiating develop's sub-grid probe at the active scalar is
bit-identical and yields the derivative of the discretisation actually solved". That is true of the
*scheme* and false of the *code*.** The probe is passive end to end, at three independent points:

| site | what it does |
|---|---|
| `Individual::growth_rate_given_height(double height, env) -> double` | takes the perturbed height as a **passive** `double`, so `d/dh` is structurally zero, and returns `double`, converting the active rate away |
| the lambda in `Node::growth_rate_gradient`, `node.h:211` | declared `[&] (double h) -> double` |
| every `util::gradient_fd*` and `gradient_richardson` overload | `double` in the parameter, the value and the return |

So there is no active path to differentiate. `log_density_dt = -growth_rate_gradient - mortality` would
carry **exactly zero** derivative through its transport term — the failure mode this design exists to
prevent, in the one channel report 10 already named as the load-bearing cost of deferring P2.4.

**What P3.5 needs, and the choice is bookkeeping rather than mathematics.** Either way the block is
evaluated twice per cohort per stage, which is report 10 §6's figure and is confirmed here:

- **Record both evaluations.** Make the probe scalar-generic — `growth_rate_given_height(S, env) -> S`,
  the lambda `-> S`, and a scalar-generic difference quotient — and let the tape record
  `(g(h) − g(h−eps))/eps` with both evaluations on it. `lambda_g` then reaches both automatically and
  step (a) needs no hand-written seed at all.
- **Seed it by hand.** Keep the probe `double` for the value and supply the transport term's adjoint as
  two seeds, `−lambda_ldd/eps` on the block at `h` and `+lambda_ldd/eps` on the block at `h−eps`. The
  second block still has to be recorded, so this buys no evaluations — only explicitness.

**Recommend the first**, because the second writes by hand a chain rule the tape already gets right, and
the corpus's own measured failure mode is a hand-written accumulation that is a fixed fraction of the
truth with the correct sign. What the first costs is that a `1/eps` amplification sits inside the tape
rather than in a seed, which is a conditioning fact and not a correctness one.

**The conditioning is inherited and is the same under either reading, and it is the number to watch.**
The derivative of the quotient with respect to a trait is
`(∂g(h)/∂θ − ∂g(h−eps)/∂θ)/eps` — two nearly-equal partials differenced and divided by `1e-6`. Report
10 §6 prices it at about **1e-10 of absolute error before any non-smoothness**, against a cohort-grid
divisor 3 470× larger at the median spacing. **So V3 must not be read as a check on the transport
channel's accuracy**: it verifies the tableau, and the transport term's conditioning is a property of
the discretisation the model carries, not of the adjoint. Gate the transport channel against a finite
difference *of the same quotient*, never against an analytic `dg/dh`.

**Not decided here:** whether making the probe scalar-generic reaches `util::gradient_fd`'s other
callers. It is generic numerics used beyond this path, so a scalar-generic version wants adding beside
the `double` one rather than replacing it, and that is a task-sized change rather than a line.

### The style sweep could not see this, and now can

`ORCHESTRATOR.md` §10 names the hazard — "beware `-> double` on a lambda in templated code, which
silently passivates" — and `style-sweep.sh` checked only for the *opposite* case, a lambda with **no**
declared return type. So an explicitly `double`-returning lambda in scalar-generic code read as
compliant, which is the more dangerous of the two because it looks deliberate. The sweep now greps for
`-> double` in added lines as well; confirmed to bite on `node.h:211` and one site in `individual.h`.
**A rule in a document that the sweep cannot check is a rule that is not enforced**, and the two lists
are worth diffing against each other once rather than discovering the gaps one at a time.

## Corrections to what was recorded here

- The `static_assert(Replayable<Patch<...>>)` this file credited to a Phase 1 packet **was not
  in the merged tree**; the only commits naming `Replayable` are on the retired AD branch. It
  is now in `SCM::store_trajectory`, where the dependency is.
- The **60× wrong-gradient figure has no source** — no commit, test or note records the
  measurement, and it appears only as a sentence repeated across documents. Treat as unverified.
