# What to fix before submitting

A gate on `docs/pr/`. The three branches carry work worth merging and, alongside
it, scaffolding, stale claims and red suites. A maintainer should receive the
first and none of the second.

**A, B, C and E are closed, and D's five queued tasks are executed.** What is left
is one maintainer action, one declined row and six nobody has ruled on. Nothing in
A–C or E is work; A1 stays as evidence for the one decision the whole of it turns
on.

Every entry is marked **[v]** where I reproduced it against the code myself, or
**[r]** where it is an agent's finding I have not independently run down. Treat
an **[r]** as a lead, not a fact: of the findings checked this round, several
were wrong in instructive ways — a symbol called dead had four consumers in
another repository, a "reverted" model version was upstream moving forward, and
a 105 MB library was our own `-g` build.

⚠️ **A [v] IS NOT A GUARANTEE EITHER, AND D'S EXECUTION IS THE EVIDENCE.** Three of
those five tasks were wrong about the thing they asked for, two of the three marked
[v]: binaries called unrun are run by three of four harnesses, a `make clean` called
incomplete is complete, and an export queued for deletion has five call sites. Two of
the three would have had somebody delete or rewrite working code. **What each [v]
reproduced was the SYMPTOM and not the claim around it** -- which is why every
verdict in D now carries the measurement rather than the reading.

---

## A. Blockers — all CLOSED **[v]**

Nothing here is work any longer. A1 is the last, and it is not a thing to fix:
every suite in it turns on one call, and until that call is made there is no
action but re-pinning, which is the thing the call exists to prevent. Its
evidence stays below because D's `A1` row is a decision and this is what the
decision is about.

### A1. ~~The red suites~~ — **NOT A BLOCKER, A DECISION: see D** **[v]**

⚠️ **Re-pinning any of these to make a run green is how a change to a model's
science gets waved through**, which is why they sit here as evidence rather than
as a task. Four of the six were genuine defects and are fixed. What is left is
`phylloptim`'s `test_golden` and `test-mutant.R`'s two ten-mutant panels, and
only the first is still a `scientific_version` answer.

| suite | how it fails |
|---|---|
| ~~`plant` `test-strategy-tf24.R` / `-tf24f.R`~~ **[v, fixed]** | **Not a version question at all: the templating commit reverted #619.** `a02588c1` transcribed `compute_rates` into the header from a copy predating `745dd600`, so the storage pool ran the clamped pre-v9 form while the file's own v9 note described the one that replaced it. That is why the scenario returned `82.0` where it pins `30.22`: those are the exact values #619 replaced, and this file's own comment records them. Restored in `27e1f57b`, and the suite is **80 pass, 0 fail, 0 skip** against develop's 75. `docs/pr/transcription.md` has the audit that says no third body was lost. |
| ~~`plant` `test-gradient-incidence.R` / `test-gradient-parity.R`~~ **[v, fixed]**, and a gradient defect found and fixed under it | **The fixtures are fixed and the reference earned its keep.** Every driver answers on the bounded pool; incidence **66 pass 0 fail**, parity **52 pass 0 fail**. The dry-pin band moved with the path integral's SHAPE rather than its level -- raising resistance uniformly takes the share to zero, while sweeping `D_c` at a held 1 m anchor takes it 0.90 -> 54.65 per cent as the shared soil column drops. ⚠️ **Refereeing `shaded` and `clamped` for the first time found a wrong gradient row, since fixed**: `ResourceSpline` laid its knots at `u_k * height_max` with the positions passivised, so the grid moved with the canopy top and the gradient carried only the values and slopes. Held against `u` instead, the state Jacobian against a plain-double difference goes `4.1e-06` -> `6.2e-10` at `k_I = 100` and the whole-run reference agrees on all five regimes at the strict floor. Forward model moves `6e-10` to `9e-09`, so no version bump. See `docs/pr/transcription.md`. |
| ~~`plant` `test-node.R`~~ **[v, fixed]** | **A red suite nothing had named, and it was ours.** 3 failures, one per model: `Node$ode_rates` reported **0** for the density rate where FF16 gives −0.787, TF24 −1.423 and K93 −0.0387. `compute_initial_conditions()` took the node's rates *before* seating its state, so the `density > 0` guard fired on the density a node being born has not got yet — `exp(-Inf)` — and the zero it wrote stood for the whole first evaluation. The offspring rate had the same shape through `survival_individual()`. The guard arrived in `a02588c1` on this branch, so develop never carried it. Fixed in `66941c0a`: both rates move to one `compute_node_rates()` that each caller reaches after the state it is responsible for exists, and the two copies of the guard become one. No trajectory moves — the whole-run rung holds at 13/13 against a reference captured before it, and the gradient suite is unchanged at 710 over nineteen files. |
| `plant` `test-mutant.R` (2) **[v, added]** | **Two panels, and the machinery under them is exact.** `run_mutant()` is restored and verified: a strategy replayed as an invader of itself returns the resident's own fitness to **1e-15** on FF16 and **1.5e-14** on TF24 (block 3, the #642/#643 case, against develop's own *"~1e-6 at best for TF24 … unexplained"*), and the eight-case identity sweep holds at 1e-11. What fails is the two ten-mutant panels, at 2-4e-4. ⚠️ **Demonstrated to be the model and not the replay.** Invasion fitness is what a strategy attains when vanishingly rare, so it has a referee that owes develop nothing: run the mutant endogenously at birth rate e and let e -> 0. The gap to THIS branch's replayed value falls 9.99x then 11.1x per decade — clean first order, which is what that limit must be — while the gap to develop's pin falls 29.5x, which is not a convergence rate. The limit is this branch's value; develop's pin is 1.4e-4 away from it. The same drift is already visible in the resident pins that pass (-2.2e-5 on one resident, +4.7e-5 and +7.0e-5 on three), amplified because invasion fitness is an off-equilibrium quantity. **Re-pinning accepts the same change to the model's science the other three suites do.** |
| ~~`plant` `_snaps/model-version.md`~~ **[v, fixed]** | Stale and self-contradictory: 62 parameters snapshotted against 64 declared, `vulnerability_curve_ncontrol` recorded as 100 where the code gives 400, `control.gradient_curvature_floor` absent, and TF24 names (`p_50`, `b`, `c`) the `.yml` no longer declares. Declared at `TF24@v11` in `84f6f85a` and accepted in `327b2bd3`; **23 pass, 0 fail, 0 skip**. The version note stands as written -- its three changes are the new `R_d_25`, the (P50, c) root reparameterisation and the vulnerability grid, none of which the storage fix touches. |
| `phylloptim` `tests/cpp/test_golden` | Exits 1. Run by `tests/cpp.R:108`, so `R CMD check` is red. |

`test_golden` fails three separate ways and they need separate answers:

- **Forty field comparisons**, all at 1e-16 to 4e-10 — fourteen below 1e-12,
  twenty-six between 1e-12 and 1e-6, none at or above 1e-3. This is the known
  cross-platform golden drift (files blessed on macOS/arm64, CI running Linux),
  not a behaviour change. Re-bless on a settled platform.
- **`psi_stem optima`: 10,692 mismatches over 5,184 rows, worst relative
  difference 1** at `fresh/ProfitMax/single … hydraulic_cost_norm` at 50 °C. A
  relative difference of one is structural. The test says what to do —
  *"regenerate with `make psi-stem-golden` and say what moved in the commit
  message"* — and nobody has.
- **"912 rows carry an unwritten field into their output."** The test reporting
  a defect rather than a mismatch. Unexplained.

### A2. ~~The branches are behind upstream~~ — RESOLVED **[v]**

All three submodules are now level with their upstream default branch (checked
`rev-list --count HEAD..upstream` = 0 on each). The TF24 conflict described below
was resolved in `39f576b`/`57585d9`/`dafa22c`. Kept for the record.


`plant` is three commits behind `develop`. The gap is not incidental:

| upstream commit | what it adds |
|---|---|
| `95256cf3` #617 | TF24 height-resistance from stem anatomy — `D_c`, `L_tip`, `theta_c`, `TF24_H_ANCHOR`, `TF24_K_s_from_whole_stem()`, `scientific_version` 9 → 10 |
| `8e49c58f` #645 | the `Tleaf` auxiliary |
| `dfb9cad6` #643 | `run_mutant()` for TF24, and the DESCRIPTION pins we have since redone |

None of this is a change we made — merge-base, ours and upstream agree that we
never touched `scientific_version`. But `tf24_strategy.h` went from 771 lines to
2,638 on this branch while upstream added eighteen references to parameters we
do not have. **Merge `develop` in and resolve that conflict as its own piece of
work, before writing final PR text.** A careless resolution silently reverts two
merged pull requests.

odelia is one commit behind (#58, the pinned-time step rejection, which is what
`v0.4.0` released) and phylloptim one (#135, the `Remotes` tag bump).

### A3. ~~Defects in the model's own use case~~ — CLOSED **[v]**

All ten answered. Two did not survive measurement and are corrected below
rather than implemented against. The rest are fixed in
`c09107d`/`0be413a`/`af0a620` (phylloptim), `078b6f9`/`ecefb4a` (odelia)
and `dafa22cf` (plant).


| | what | where |
|---|---|---|
| **[v]** | **The cross-package tape contract is broken in two of four build files.** `phylloptim/src/Makevars` defines neither `XAD_NO_THREADLOCAL` nor `XAD_USE_STRONG_INLINE` while compiling four translation units including `gradient.cpp`; `plant/src/Makevars.win` defines neither, and Windows is the one platform where `plant.dll` links `odelia.dll` at link time. The comment at `plant/src/Makevars:9` states the invariant in capitals — both must match odelia's exactly, because a mismatch is a storage-class conflict on a symbol whose mangled name does not change. It links cleanly, passes load, and corrupts or nulls every recorded derivative. | `phylloptim/src/Makevars`, `plant/src/Makevars.win` |
| **[v]** | An out-of-bounds read became an out-of-bounds **write**. `duptake_dpsi` sizes its scratch from `psi_soil.size()` and hands it to `uptake_impl`, which writes `soil_consumption[i]` to `max_soil_layer` — a count owned by the root network, not by the caller's soil vector. | `phylloptim/inst/include/phylloptim/roots.hpp:766` |
| **[v]** | Drought throws the wrong exception. `util::stop` past `(psi/b)^c > log(100)` — about 6.89 MPa at root defaults — where `roots.hpp:470` states in capitals that a layer drier than the grid is an ordinary state and plant's own ceiling is 1000 MPa. `util.hpp:66` says `stop_infeasible` exists so such a point costs one row and leaves a usable likelihood. As written a drought proposal fails the whole fit. | `phylloptim/inst/include/phylloptim/vulnerability.hpp:113` |
| **[v]** | The forward solve and its own derivative run different code. `uptake()` — the hot path, ~10³ calls per collar solve — calls the legacy `double` body; `uptake_at<T>` and `duptake_dpsi` call the templated one. They differ in kink handling and in whether a non-finite draw is refused. The commit argued for one walk; the diff swapped which pair is duplicated. | `roots.hpp:690` vs `:727` |
| **[v]** | The silent-skip detector is built and discarded. All five `implicit_value` call sites declare the `reached` out-parameter and none reads it. It exists precisely so a caller can check the walk against what it handed over; a member added to `PhotoCapacity`, `SupplyDraw` or `leaf_pars` and not visited yields plausible zero columns with nothing to notice by. | `phylloptim/inst/include/phylloptim/leaf_model.hpp:5715, 5751, 5988, 6003, 6044` |
| **[r]** | `preaccumulate` leaves stale adjoints on any pre-mark active its walk missed, and the consumer accumulates on top. Demonstrated by the agent as `du/dx = 18` against a true 24. The 5-argument `implicit_value` shares the gap. | `odelia/inst/include/odelia/implicit_node.hpp:374` |
| **[r]** | `const` defeats `visit_active`. Both rewinding forms take `const Inputs&...`; every `for_each_active` in the family is non-const. Measured at 0 scalars reached as const against 2 non-const — so `with_slope`, the type whose comment says it "LIVES HERE BECAUSE OF `for_each_active`", contributes no rows to either. | `implicit_node.hpp:223`, `with_slope.hpp:36` |
| **[v]** | `collar_at` is declared `const` and `const_cast`s itself to call a non-const member. | `leaf_model.hpp:6037` |
| **[v]** | `set_extrapolate` is not merely inert — the read was removed and the default flipped `true` → `false`. Three live phylloptim callers silently no-op, and an out-of-domain read that used to stop with a located error now extrapolates linearly. `vulnerability.hpp:265` still asserts both splines have extrapolation disabled. | `odelia/inst/include/odelia/interpolator.hpp:545, 554` |

### A4. ~~Five `R CMD check` WARNINGs, all new on this branch~~ — CLOSED **[v]**

Re-verified by the checkers rather than by reading: `tools::undoc`, `tools::codoc`
and `tools::checkDocFiles` all report clean on `plant` and `phylloptim`.
`-fno-stack-protector` has no live occurrence in either `src/Makevars` — plant's
carries a comment prohibiting it and saying why. No `tests/cpp` binary is tracked
in phylloptim's git, and `.Rbuildignore` now names each one `build:` makes.

phylloptim's `check-r-package` sets no `error-on`, and the action's default is
`"warning"` — so for that package a WARNING is a red leg. plant and odelia pin
`"error"`.

| check | package | finding |
|---|---|---|
| non-portable flags | odelia, plant | `-fno-stack-protector` in `PKG_CXXFLAGS` raises *Non-portable flags in variable 'PKG_CXXFLAGS'*. It is also inert on Linux (R puts `PKG_CXXFLAGS` before the distro `CXXFLAGS`, last wins) and live on macOS/clang, where R adds no hardening — so the one place it takes effect is the one place it removes protection. Drop it. |
| `tools::codoc` | phylloptim | `man/leaf_control.Rd:9` says `vulnerability_curve_ncontrol = 100`; the source moved to 400 this branch. |
| `tools::codoc` | plant | `man/run_scm.Rd` — a file this diff edits — documents `use_ode_times` and `ode_step_sizes`, which are gone, omits `record_trajectory`, and has three argument positions shifted. |
| `tools::undoc` | plant | `stand_gradient_refused` is exported with no `.Rd`. |
| `check_executables` | phylloptim | Four unstripped ELF binaries ship — see B. |

One roxygen run closes three of them; `gradient_control.Rd`, `stand_census.Rd`,
`stand_gradient.Rd` and `stand_census_state_adjoint.Rd` are stale in the same way
and come with it.

### A5. ~~The exactness claim has two open columns~~ — CLOSED **[v]**

**Not a gradient defect — the reference was measuring the solver.** It re-ran the
adaptive integrator independently on each side of its difference, so each side
chose its own ODE steps. Moving a parameter by one part in a million changes
which steps the error estimator accepts, and the census then lands a fixed ~2e-4
away however small the move was; divided by 2h that quotient grows as 1/h, and
all four of the capture's relative steps (1e-6 to 1e-3) sat under it. **On the
drought stand nothing resolved at all** — over its 86 readable columns the census
difference tracked the step at a slope of 0.65 at best, where a resolved
difference gives 1, against 83 of 85 above 0.5 on wet. `theta` and `omega` are
simply the two whose noise reading was large enough to trip a residual normalised
by the metric's largest column.

Two normalisations kept it quiet. The capture divided its convergence gap by the
**largest** of its four readings — on a 1/h series that is the finest step, the
noisiest — so 79 of drought's 86 columns kept a reading further from its
neighbour than from zero and reported a spread of between 0.03% and 34% for it.
And the rung divided its residual by the per-metric maximum over columns, so only
the biggest column could trip the tolerance at all.

Fixed by censusing both sides on one time grid — which is also the derivative the
sweep computes, rather than a quieter version of a different one: recorded step
sizes are selectors, replayed by the backward pass instead of decided again, so
an unpinned difference answers a different question. Pinned, the reading is flat
across four decades of step and lands on the sweep:

| | difference | sweep |
|---|---|---|
| drought `1.theta` mass_above_ground | −545.63 | −545.742 |
| drought `2.omega` mass_above_ground | 276.209 | 276.256 |
| seasonal `1.theta` area_stem | 0.379283 | 0.379277 |

The capture was re-taken and the rung is 13/13 with no skips: 270 answered
columns a regime, worst residual 1.1e-03 on drought, 7.6e-04 on seasonal,
6.3e-05 on wet. Seven columns the old capture never covered — `D_c`, `L_tip`,
`stem_P50`, `stem_c`, `root_P50`, `TF24_beta2`, `TF24_cost_scale` — are refereed
for the first time, because the generator now takes its column list from the same
expression the rung asserts against rather than from a patch's trait names. The
generator moved from this superproject into `plant/scripts/`, so the reference is
regenerable from the package a maintainer receives.

---

### A6. ~~Two test files error under `R CMD check --as-cran`~~ — FIXED **[v]**

**A red leg on every operating system, and nothing would have said so until the
pull request opened.** `test-gradient-ladder-whole-run-difference.R` and
`test-gradient-parity.R` both forked with
`mc.cores = max(1L, parallel::detectCores() - 1L)`. `R CMD check --as-cran` sets
`_R_CHECK_LIMIT_CORES_`, and `parallel::mclapply` then **errors** rather than
warning past two processes — measured directly: *"3 simultaneous processes
spawned"*. plant's workflow runs `--as-cran` with `error-on: '"error"'`, and a
GitHub runner has four cores, so `detectCores() - 1` is three.

The whole-run difference is the one reference that shares no arithmetic with the
sweep, so the rung that would have failed is the one carrying the strongest
claim. Invisible until submission because the workflow filters name the
long-lived branches only.

Fixed by one rule in one place — `plant_test_cores()` in `helper-plant.R` — rather
than a cap written into both files, because two files forking is how a third
comes to fork wrongly.

## B. ~~Remove before submitting~~ — CLOSED **[v]**

Nothing here is a blocker. ⚠️ **But "everything below is done" was wrong, and the
table now says what actually happened.** Three rows were resolved the OTHER way
— the probe binaries are `.Rbuildignore`d rather than deleted, `test-gradient-demo.R`
was live in the surface tier (and has since been removed on the author's call), and
the production-scale gate is implemented — and
two are questions about what the diff contains rather than removals, so they have
joined `plant/src/gradient_ladder.cpp` in D. Re-checked against the tree, not the
labels: five files this section called removed are still present, every one of
them on purpose.


Roughly 4,000 of the 33,640 added lines, with no loss of coverage.

| | what | lines | why |
|---|---|---|---|
| **[v]** | `odelia/tests/standalone/probe_*.cpp`, seven files | 2,034 | In no `all:` target and no workflow. `probe_nested_recording.cpp` alone is 1,023 lines. They are measurements; under `tests/` a maintainer reads them as checks. Move to `notes/` or `bench/`. |
| **[v→kept]** | `phylloptim/tests/cpp/probe_preaccumulation.cpp`, `probe_tape_regions.cpp` | 563 | **Resolved the other way, and the row should say so.** The finding was that the BINARIES ship: `.Rbuildignore` named only the five older ones. Both are now named (`^tests/cpp/probe_preaccumulation$`, `:60`), and `tests/cpp/Makefile` keeps them out of `all:` with the reason at `:123`. The sources stay, which is what a probe is for. |
| **[→D]** | `plant/src/gradient_ladder.cpp` | 1,071 | **Moved to D.** Not a removal: every option changes what the pull request contains. The finding holds and is sharper than written — the callers are 13 test files, not one helper. |
| **[v]** | `plant/tests/testthat/reference/reference-kinds.tsv` | 121 | Nothing reads it, and its generator `scripts/generate_reference_run.R` is deleted in the same diff, so it cannot be regenerated either. |
| **[v→REMOVED]** | `plant/tests/testthat/test-gradient-demo.R` | 116 | **Dropped from the diff on the author's call**, after D settled that a maintainer building the tarball never sees it (`.Rbuildignore` named the file itself) and only a reader of the diff does. The study it guarded stays: `overstorey_staging/TF24_gradient_tradeoffs.qmd` and `gradient_demo_helpers.R`, 385 lines, now with no guard — stated at the top of the helpers so the next reader is not surprised. `AGENTS.md` and `scripts/run-tests.sh` named it in the surface tier and no longer do. |
| **[v→kept]** | `plant/tests/testthat/test-gradient-ladder-production-scale.R` | 48 | **Kept, and the gate is real.** `PLANT_LADDER_SCALE` is read at `helper-gradient-ladder.R:519` and refuses with a message naming itself at `:528`. Still set by nothing in any repo, workflow or script — which is E-class (a skip that always fires), not a removal. |
| **[v]** | `plant/tests/probes/probe_tf24f_active.cpp` | 46 | A compile-time falsifier ("Never run. Instantiating it is the whole test") that no build compiles. `tests/` is not `.Rbuildignore`d, so it ships. Wire it into a build or drop it. |
| **[r]** | `helper-gradient-ladder.R` `ladder_injected()` / `PLANT_LADDER_INJECT` | — | Defined, never read. The fault-injection contract advertised at `:10` is unimplemented. |
| **[r→D]** | `phylloptim/.claude/CLAUDE.md` | 12 | **Does not ship** — `phylloptim/.Rbuildignore:13` is `^\.claude$`, as plant's `:3` is. What is left is whether it belongs in the DIFF, which is what the pull request contains and so is D's, beside `gradient_ladder.cpp`. |
| **[r→D]** | `plant/scripts/tf24-active-probe.cpp` | 67 | **Does not ship** — `plant/.Rbuildignore:11` is `^scripts$`. Verified unreferenced: the only mention of its own name anywhere is its own header comment. Same question as the row above, and same answer-holder. |
| **[r]** | `odelia` `compat_interpolator::add_point`, `get_x`, `get_y`, `r_eval`; `Solver::get_control()`, `get_history()` | ~26 | No consumer in any of the three trees. |
| **[v]** | `plant/.Rbuildignore:31` | — | `^inst/RcppR6*$` does not match `inst/RcppR6_classes.yml` — confirmed against R's own `grepl`. The 57,873-byte file ships and installs. Write `^inst/RcppR6_classes\.yml$`. |
| **[r]** | odelia ships `AGENTS.md`, `ARCHITECTURE.md`, `CLA.md`, `.claude/CLAUDE.md` | ~16 KB | plant and phylloptim ignore all four; odelia's `.Rbuildignore` has no such lines. |
| **[v]** | `phylloptim` `FixedCollarEval` | — | No consumer anywhere, tests included. `clamp_sites.hpp:37` cites a `profit_at_fixed_collar` that exists nowhere. |

Also **[r]**: the shim `compat_interpolator` / `basic_interpolator` / `Interpolator`
is documented as keeping phylloptim and plant compiling while they migrate, and
both migrate in these same pull requests. plant already uses
`hermite_interpolator` directly. Ship the migration or the shim, not both.

---

## C. ~~Correct before submitting~~ — CLOSED **[v]**

All three re-checked against the text rather than the labels: the greps that look
like open findings are matching the corrections.

### C1. ~~Comments and man pages that are false~~ — CLOSED **[v]**

All fourteen re-checked against the tree and fixed. One more was found while
landing the whole-run reference and is fixed with them:

| claim | where | what is true |
|---|---|---|
| `r_ode_times()` sends a reader to a `use_ode_times` flag on `NodeSchedule` | `plant/inst/include/plant/scm.h` | No such flag exists in any of the three trees — holding the times is what makes a schedule a replay. The line below it named `NodeSchedule` as where to set the sizes, where `run_scm()` reads both off the parameters. Fixed in `3059e44d`, which says instead what the two spellings differ in: times with sizes repeat a run exactly, times alone step TO each of them and leave the sub-steps free. |

The original fourteen, for the record, ordered by who is misled:

| claim | where | what is true |
|---|---|---|
| "a refusal … always names one [species]" | `plant/inst/include/plant/census_gradient.h:20` | The field defaults to `-1` and the `AdjointRangeError` path builds it with `-1`. `refusal.md:50` documents that case. A caller trusting the header indexes with `-1`. |
| "four `Control` entries", three times | `plant/man/gradient_control.Rd:5, 9, 17` | Five. And the fifth, `gradient_curvature_floor`, is documented 130 lines away as moving no forward number, while this page says each "moves the trajectory". A new man page with three false statements. |
| `vulnerability_curve_ncontrol = 100` | `phylloptim/man/leaf_control.Rd:9` | 400 this branch. The one real usage drift in either package. |
| "an exact zero is more often a slot nothing reached than a sensitivity the model means" | `plant/inst/include/plant/scm.h:201` | The same file, 940 lines later: "every column here carries a number the sweep computed, and an exact zero in one is the sweep's answer" (`:1141`). One file, two opposite claims. |
| "the cohort-height columns carry the trapezium weights" | `plant/man/stand_census_state_adjoint.Rd:17` | The source qualifies it — on the birth-date coordinate the weights are constants — and the man page drops the qualifier. The gradient path requires birth date. |
| "a tangent above an adjoint, which is how a curvature is taken" | `odelia/inst/include/odelia/ode_util.hpp:37` | That scalar no longer compiles (`tangent.hpp:36`), and a curvature is a tangent *of a tangent*. The measurement beside it describes a configuration the library now refuses. |
| "the knot loop … stops one step short of psi_max" | `phylloptim/.../roots.hpp:519` | `vulnerability.hpp:296` sets the final knot to `psi_max` exactly. The justification that follows is false, and `clamp_sites.hpp:31` repeats the stale 6.8229. |
| "Keeps main's phylloptim and plant compiling" | `odelia/.../interpolator.hpp:519` | plant names none of the three aliases; only phylloptim does. |
| "plant's resource_spline calls max() on a freshly constructed field" | `odelia/.../interpolator.hpp:536` | plant holds `hermite_interpolator`, whose `max()` is the unguarded `x.back()`. The guard justified here is on a class plant does not instantiate. |
| "plant reaches into `leaf.E_up_` (tf24_strategy.cpp:501-508)" | `phylloptim/.../roots.hpp:342` | That file is deleted in the sibling branch; the writeback is `tf24_strategy.h:2156`. |
| cites `leaf_predict()` | `phylloptim/.../gradient.hpp:886` | No such function in any of the three packages. |
| cites `stem_curve_closed_form_` | `phylloptim/.../leaf_model.hpp:1050` | No such member anywhere. |
| "This is the check plant makes at test-leaf.r:214" | `phylloptim/tests/cpp/test_leaf.cpp:262` | That line is a `set_physiology()` call; the check is at `:271`. |
| roxygen says `psi_crit` / `root_psi_crit` are live | `plant/R/stand_gradient.R:83` | Both are in `undifferentiable`; asking for them errors. |

`man/stand_gradient.Rd` and `man/run_scm.Rd` are stale — roxygen was not re-run.
`stand_gradient_refused` is exported with no `.Rd`, which `R CMD check` flags.

### C2. ~~The design docs have errors of their own~~ — CLOSED **[v]**

`reverse-mode.md` now says the orchestrator seeds the walk **with** the direct
term and that nothing classifies exact zeros; `refusal.md` now attributes the
tally to `TF24_Strategy::solve_leaf` and says why `record_leaf_outputs` would
miss the forward pass.

`docs/design/` lives in this superproject and ships in no pull request, so this
is not a blocker — but it is the document set we treat as authority.

- `reverse-mode.md:173` says the orchestrator "adds the direct term, classifies
  exact zeros". The code seeds *with* the direct term and says at `scm.h:1080`
  that adding it last is the mistake; nothing classifies exact zeros; the width
  restore is odelia's, the doc's own step 5.
- `refusal.md:88` attributes the operating-point tally to `record_leaf_outputs`.
  It is `++operating_point_counts[…]` in `TF24_Strategy::solve_leaf`
  (`tf24_strategy.h:2231`), and `record_leaf_outputs` runs only on the non-double
  path, so the doc's function would miss the whole forward pass.

The pull request drafts in this directory take both points from the code rather
than from the docs and are unaffected.

### C3. ~~The changelogs~~ — CLOSED **[v]**

odelia opens at 0.5.0, matching its DESCRIPTION, and the 0.2.2 promise the diff
falsified is gone. plant's sections are whole again and neither function that
does not exist is named. phylloptim carries the `ncontrol` default and retracts
both `n_pars` entries by name, leaving the originals standing as history.

- **odelia is not submittable.** DESCRIPTION declares 0.5.0; `NEWS.md` stops at
  0.3.1, and the `0.4.0` section was deleted rather than superseded. The entry
  the diff most contradicts — 0.2.2's promise that an out-of-domain interpolator
  read is refused with a located message — is left standing and is now false **[v]**.
- **plant is not submittable.** The file its own migration skill reads as a
  specification has a deleted `### New features` header, so ~160 lines of
  additive prose now sit inside `### Breaking changes`; an `### Added` inserted
  mid-entry at `:683` splitting the `node_density_in_birth_date` entry; an
  orphan paragraph at `:1335`; two documented functions that do not exist
  (`stand_gradient_unanswered()` **[v]**, `census_clear_operating_point_counts_tf24()`);
  refusal-kind strings that do not match the code; and no entry for `run_scm()`'s
  fifth positional argument changing meaning, the FF16/K93 `scientific_version`
  bumps, or the three `Control` default moves.
- **phylloptim is nearly submittable** — it needs the `ncontrol` default, a
  retraction of the 0.7.0/0.8.0 claims that `n_pars` is unchanged at 19, and the
  odelia floor.

---

## D. Decide

Judgement calls, not defects. Each wants an answer before the pull requests open.

### Decided, and executed

Answered and done 2026-09-17. Everything below this block is the evidence each
answer was given on; the rows carry their verdicts inline. Four were work and are
landed, one needed none, three were decided with nothing to do, one is a
maintainer's and one is declined, and six are still open and named at the end.

⚠️ **Three of the five rows were wrong about the thing they asked for, and the
measurement is in each verdict below.** Two of the three would have had somebody
delete or rewrite working code.

| # | what was asked | what it turned out to be | landed as |
|---|---|---|---|
| 1 | Run `test_supplied_rows` and `test_transpose` from the check leg. | ⚠️ **They are not unrun.** `make all` runs both and so does `cpp-tests.yml`, and `ctest` runs both through CMake; what missed them is `tests/cpp.R`, the `R CMD check` leg alone. `test_supplied_rows` joins it -- clean against the installed headers, 178 checks in 0.044 s. **`test_transpose` cannot and the reason is structural**: it records, so it needs the tape out of odelia's `src/Tape.cpp` (129 undefined references without it, `xad::Tape<double,1>::active_tape_` among them), and an installed odelia ships headers only. The one other route, linking the installed `odelia.so`, works here and drags `libR.so` and twenty transitive libraries in behind it, so it needs an R built `--enable-R-shlib`, which a consumer's need not be. `CMakeLists.txt:175` already states that exclusion as `if(EXISTS .../src/Tape.cpp)`; `cpp.R` states it now too. | `phylloptim` `9ed0ea2` |
| 2 | One ignore list matching what `build:` builds. | Both git-ignore lists moved into `tests/cpp/.gitignore`, beside the binaries, where the names are the Makefile's own. The phantom `test_leaf_gradient` is gone -- confirmed against `--diff-filter=A` over all branches that it has never existed. ⚠️ **`make clean` does NOT leave `probe_preaccumulation`**; the row was stale, `clean:` names all nine. And there is a THIRD list, `.Rbuildignore`, which was already complete and correct; the two now cross-reference. | `phylloptim` `13ed093` |
| 3 | Give `vulnerability_curve_ncontrol = 400` one source of truth. | One of the three spellings, `.leaf_control_defaults`, had **no consumer at all** -- `leaf_control()` restates its six values rather than reading them -- which is why it could drift with nothing to notice by. Deleted. The two left cannot be collapsed: RcppR6 binds only the 15-argument constructor, so R must pass the number and cannot read `Leaf::ncontrol_default`. What ties them is plant's `test-control.R`, with `expect_identical`, one repository away. ⚠️ **And the golden file does NOT catch a drift, which two comments and the NEWS entry all said it did**: measured on the golden grid's own driver rows, 400 -> 40 moves every field by 3.0e-06 and 400 -> 20 by 5.0e-06, against per-class tolerances of 1e-05 and 5e-03. That argument holds for a trait, which enters the answer, and not for a spline resolution, which refines it. All three corrected. | `phylloptim` `734e3aa` |
| 4 | Settle the query slope; make the code and the banner agree. | **The code was right and the banner was wrong**, so no code moved. The rule both functions follow: the query row is whichever the rest of the assembly already forms. dG/dpsi IS formed -- `stem_curve_integral_deriv` and `root_vuln_integral_deriv_at`, both read by the physics -- so a closed-form row there is a second value of it, measured at `dci/dcollar` 0.6913 against 0.6382. d*f*/dpsi is formed **nowhere**: `root_vuln_from_psi` is built with slopes and `.slope()` has no call site on it, every `.slope()` in the package being a dG/dpsi, and odelia's interpolator reads no second derivative at all (`interpolator.hpp:28`). So there is nothing for `closed_form_curve` to disagree with. The banner states that rule now, with the grep that decides which case a new function is in. | `phylloptim` `cdcab5f` |
| 5 | Referee `census_trait_tangent` or delete it -- "the one export in that family with NO consumer". | ⚠️ **NOTHING TO DO, AND THE ROW WAS WRONG.** `census_trait_tangent` is not an export: it is `scm.h:1222`'s C++ method under the `ladder_trajectory_tangent_tf24` export, which has **five** call sites -- `test-gradient-ladder-columns.R` x3, `-introductions.R` x2, through `ladder_trajectory_tangent()` in the helper. That is the same mistake the row beside it catches for `replay_initial_state`, made again one line later, and the paragraph that raised it credits this very export with pinning the knot-grid defect. Re-run to be sure the referee is live: `columns` is **51 pass, 0 fail**, every column agreeing with the forward tangent at 1e-12 to 7e-11 against a 3e-04 budget. | nothing |

### What `R CMD check` says about plant, run 2026-09-17

⚠️ **IT HAD NOT BEEN RUN ON THIS BRANCH SINCE THE HEADER WORK, AND IT WAS RED.**
Two of the three findings are this branch's and are fixed; the third is a NOTE and
is a decision. Run as `R CMD build` then `R CMD check` on the tarball -- checking
the source directory instead fails on a missing `Author`, because `Authors@R` is
resolved at build time, which is not a package defect.

| | what | verdict |
|---|---|---|
| **ERROR** | `test-leaf.r:652` probed the supply with ONE soil potential where BOTH layers are rooted, and `57585d9`'s layer guard refuses that. | **FIXED**, one argument. The guard is right: before it that call read `psi_soil` past its end, and `:654`'s `expect_equal(E_up_, sum(soil_consumption_)*0.018015)` was checking the result. ⚠️ **Latent for six days and invisible to every dev run**, because plant compiles against the INSTALLED phylloptim and the tree's `roots.hpp` had not reached it -- developer guide hazard 1, exactly. ⚠️ **And it is an ERROR, not a failure**, so it aborted `test_that("Basic functions")` at `:652` and everything to `:696` stopped running. The file is **382 pass, 0 fail, 0 skip** now. |
| **WARNING** | GNU extensions in `src/Makevars`. | **FIXED.** Appending to `PKG_CPPFLAGS` in a second line is a GNU make extension; develop has one plain assignment and this branch added a second. Same flags, one assignment, in plant's two Makevars and phylloptim's. ⚠️ **phylloptim's mattered more**: its `check-r-package` sets no `error-on`, so the action's default makes a WARNING a red leg there. `Makevars.win`'s remaining `$(shell)` is develop's and has no portable form -- it resolves odelia's DLL path. |
| **WARNING** | "checking R files for syntax errors". | **NOT A DEFECT.** The body is `OS reports request to set locale to "en_US.UTF-8" cannot be honored` -- this container has no such locale. No syntax error is reported. A runner with locales will not raise it. |
| **NOTE** | `Found 'stderr'` in `census_gradient.o` and `gradient_ladder.o`. | **A DECISION, AND IT IS odelia's.** Localised: the cause is `ode_solver.hpp:555`'s `ODELIA_ADJOINT_TRACE` diagnostic, not `ode_util.hpp:111`'s `warning()`. Those two objects are exactly the two carrying an adjoint sweep, and `RcppR6.o` -- which includes the `warning()` helper through `scm.h` -- has no `stderr` reference at all. The trace is dead unless `ODELIA_ADJOINT_TRACE=steps` is in the environment. ⚠️ `warning()` is nonetheless worth a look on its own terms: it has ONE caller in the family, `scm.h:506`, and odelia's own comment says such a caller "should raise it from their own R-facing code" -- which plant is. |

**Confirmed by a re-run after both fixes**: *checking for GNU extensions in
Makefiles ... OK*, and **FAIL 2 | SKIP 5 | PASS 4641** -- six checks more than the
red run, which are the ones after `test-leaf.r:652` that had stopped running. The
two failures are the catalogued `test-mutant.R` panels and nothing else.

The five skips are all environmental or opt-in, and none is in the ladder: the
`PLANT_RUN_SCENARIOS=1` gateway, `test-pm-leaf-demo.R` x2 for helpers that do not
ship, and `{ggridges}` and `{patchwork}` not installed here. A runner carrying the
full Suggests loses the last two.

Left standing: `Status: 1 ERROR, 1 WARNING, 1 NOTE` -- the ERROR is those two
`test-mutant.R` panels, the WARNING is the locale line above, and the NOTE is
odelia's.

⚠️ **Re-run once more after the `gradient_control` export changed its return type**,
because a signature change is exactly what a stale `RcppExports.cpp` hides:
identical, at **FAIL 2 | SKIP 5 | PASS 4641**, the same two `test-mutant.R` panels
and the same locale WARNING. The assertion count is unchanged on purpose -- the
census block traded two comparisons for two better ones, and `test-gradient-demo.R`
never ran on this leg to begin with.

### Not ours to do

⚠️ **The `test_golden` re-bless is a MAINTAINER ACTION, ON macOS/arm64, and
`phylloptim`'s pull request arrives with a red check until it happens.** Taking it
off the list above does not make it stop blocking; it reassigns it. The file is
bit-exact only on the platform that generated it, so regenerating anywhere else
silently moves which platform that is -- which is why this cannot be done from
here. What a maintainer would be blessing is measured under "The ones that block
a submission" further down: 222 mismatches over 576 operating points, 0.55% to
62% relative, in `assim`, `transpiration` and `gc` at `psi_soil = 4`. Two commits have already said this
surface moved and that the file re-blessed; neither re-bless landed, so the
regeneration wants a commit message saying what moved.

**The install cost is DECLINED.** `R CMD INSTALL` takes 163.8 s at `-j4` and the
object is 261 MB, of which `-g0` alone would remove 94%. Not worth the
`src/Makevars` surface on this pull request. The measurement stays in the row
below so nobody re-derives it.

### Decided with no work attached

| decision | answer | what it rests on |
|---|---|---|
| **Defer the forward-mode and replay family?** | **NO -- keep it. Forward mode is the referee.** | Three of the five are refereed against in the ladder: `census_trait_difference` by `switches`, `census_initial_state_tangent` by `first-range` and `introductions`, `census_initial_state_replay` by `introductions`. And `ladder_trajectory_tangent_tf24` is what showed the reverse sweep and a forward tangent agree to **1e-11** on the columns the knot grid was breaking, which is how that defect was pinned on the model rather than on the assembly. ⚠️ **Two names in this row are C++ implementations rather than exports, and each was read once as a contents question it never was.** `replay_initial_state` is `scm.h`'s body under the two `census_initial_state_*` exports (`:1327`, `:1353`). `census_trait_tangent` is `scm.h:1222`'s body under `ladder_trajectory_tangent_tf24` -- the export named earlier in this same sentence -- so the family is FOUR exports refereed four ways, not five with one orphan. |
| **phylloptim names the AD library eighteen times.** | **LEAVE IT.** | The rule that the library is named in odelia and nowhere else stands for plant, which names it once. phylloptim keeps its eighteen; amend the rule rather than the code. |
| **`leaf_model.hpp` runs thousands of lines public.** | **NEVERMIND -- it is inherited.** | Measured against the merge-base `0709be46`: upstream master already runs **1927 lines** before its first `private:`, and this branch takes it to **2553**. The structure is not this diff's, which is the test that was set for it. ⚠️ Recorded rather than dropped: the diff still adds 626 lines to that public run, so a narrower change -- making only this branch's own additions private -- is available if the 626 is ever thought worth it on its own. |

### Still open, and nobody has ruled on these

the net **+237 C++ and +62 R names** against a
brief of net deletion, and plant's own headers compiled with `-isystem` so ~95% of
the package is un-warned. ⚠️ **Four of the six are struck.** `test-gradient-demo.R`
and `gradient_control()` were ANSWERED and are done, in their rows above; the `[r]`
pair of dead assertions are both stale -- the files were restructured and one of
them records that very defect and its repair -- and `[r]` phylloptim not compiling
against odelia master is landing order rather than a decision. **Two are left**, and
both are the same question: what the pull request contains.

### The ones that block a submission

These are not style questions. ⚠️ **One of the four was retired by measurement
rather than decided** -- "the operating point moved" rested on a number that was
the reverted storage pool and not upstream's #617 -- and A1 shrank from four
suites to one by the same route. What is left is `phylloptim`'s `test_golden`,
which is a RE-BLESS AND NOT A DECISION, is the one thing standing between this
work and a green check leg, and is a MAINTAINER'S on macOS/arm64 rather than
anything this branch can do -- see "Not ours to do" above:

⚠️ **`phylloptim`'s `tests/cpp.R` exits 1 today.** Run with the comparison the
check leg uses -- `./test_golden --cross-platform`, not a bare `make`, which
compares bit-exact off the generating platform and reports 4320 round-off
mismatches over the real ones -- it is **222 mismatches over 576 operating
points** and 60 of 5184 `psi_stem` rows. They are not round-off: 0.55% to 62%
relative, median 7.6%, concentrated in `assim`, `transpiration` and `gc` at
`psi_soil = 4`, where the absolute values are 1e-12 to 1e-7 and the leaf is
nearly shut. Two commits said this surface had moved and that the file
re-blessed; neither re-bless landed. ⚠️ **Regenerating is not free here**: the
file is bit-exact only on the platform that generated it (macOS/arm64), so a
`make golden` run on Linux moves which platform that is.

| | decision | what is known |
|---|---|---|
| **A1** | **What `scientific_version` should say.** | **One suite still turns on it, not four.** `_snaps/model-version.md` is declared and accepted at `TF24@v11`. `test-strategy-tf24.R`'s scenario pins were never a version question: `a02588c1` reverted #619 while transcribing `compute_rates` into the header, and `27e1f57b` puts it back, so the pins the branch could not produce are the ones it produces. That leaves `phylloptim`'s `test_golden`, whose operating-point surface two commits say has moved and neither re-blessed. | ⚠️ **`test-mutant.R`'s two panels are not a version question either, and are the one thing measured against a referee outside develop**: the vanishing-density limit of this branch's own endogenous dynamics converges first-order onto this branch's replayed value rather than onto develop's pin. FF16 drift of 2-4e-4, unrelated to TF24. |
| **run_mutant** | ~~Restore it, or ship regressed against `develop`.~~ — **RESTORED**, and what is left is A1's. | `SCM::run_mutant` works again, on odelia's own store/load channel rather than the three solver hooks its rewrite deleted (`ode::cache` ×2, `ode::load`, `has_cache`, a second `derivs`). ⚠️ **The comment naming odelia's `ReplaysField` as the replacement had it backwards**: `9e84ef6` created it, `001528b` deleted it four days later for `recorded_stage{step,stage}`, and plant's comment was written twenty days after that. What `001528b` kept is the channel now used — a rate evaluation already records what its state does not determine, per (step, stage), and an invader's field is exactly that. odelia's change is **4 files, zero new public names**. <br><br>**Exact**: a strategy replayed as an invader of itself returns the resident's fitness to **1e-15**, with two, three, five or nine invaders present — which says nothing in the replay builds an invader's own field. **Cheap**: a replay costs 0.06 s against the 0.07 s resident run it stands in, so an assembly sweep pays once per resident. The record is knots+values+slopes plus the environment's ODE state, not whole environments — develop's form OOMs at 6.8 GB past ~10 yr and its fix (`b2f70dfa`) never reached develop. <br><br>**Left open, and it is A1's:** `test-mutant.R`'s two ten-mutant panels are pinned to develop's model. This branch's FF16 residents already differ — **2.7731596 vs 2.77322 (−2.2e-5)**, **+4.7e-5** on the three-resident stand — inside the 1e-4 the resident pins allow, amplified to 4e-4 by the panels. Re-pinning them accepts a change to the model's science. |
| ~~**the operating point moved**~~ | ~~Recalibrate the incidence and parity fixtures, or hold.~~ — **NOT A DECISION: the premise was wrong.** | This row read develop's #617 as taking the dry share from **0.51% to 92.36%** on `incidence_stand(0.25, 10)`, `seasonal` from answered to refused and `shaded` from reaching shade-death to not. Measured, 92.36% was the storage pool `a02588c1` reverted, not #617: with the pool bounded, `seasonal` answers, `shaded` reaches shade-death, and every driver's descent stays in range. #617's own contribution is **0.90% → 54.65%**, through its SHAPE and not its level — raising resistance uniformly takes the share to ZERO. So there was no ecological change to accept here; the fixtures are recalibrated and green, incidence **66/0** and parity **52/0**. ⚠️ What refereeing them DID find is a wrong gradient row, since fixed — see the A1 table and `docs/pr/transcription.md`. |

| lifetime | CPU | slowest regime | kinds | clamp sites | verdicts |
|---|---|---|---|---|---|
| 1 | 21 s | 5 s | 1 | 2 | three regimes answer that should refuse |
| 2 | 315 s | 153 s | 3 | 4 | `seasonal` answers |
| 3 | 451 s | 211 s | 5 | 7 | same as 5 |
| **4** | **592 s** | **260 s** | **5** | **9** | **same as 5** |
| 5 | 791 s | 311 s | 5 | 9 | — |

Lifetime 4 is the smallest that matches lifetime 5 on all three, and it is 25% of the CPU and 16% of the slowest regime cheaper. ⚠️ **This stays a decision, and the cost argument for it is gone.** `test-review.md` separates each file's per-STATE claims, which a constructed patch reaches in milliseconds, from its per-TRAJECTORY ones, which cannot be constructed -- and the incidence half of these two files is the second kind. What the measurement DID move is the schedule: thinning the introductions took parity from 343 s to 157 and incidence from 580 to 253 with every verdict, operating-point kind and clamp site unchanged, so the lifetime is now a question about the ecology alone rather than about the ecology and the bill together. ⚠️ **Not every driver thins.** parity's `seasonal` loses `determined` and `hydraulic-shutdown` at twenty introductions and keeps its whole schedule for that reason; the other four are identical on all three axes. ⚠️ **Lifetime 3 is the trap**: it matches on verdicts and kinds and loses `light_floor` and `light_floor_crown`, which is exactly what incidence's *"the light floor is counted on both paths"* exists to reach — a block that was 251 s of that file's 542 and is now 18 s of its 253, on a stand thinned to twenty introductions that still fires both sites on both paths. |
| **`gradient_ladder.cpp`** | ~~Ship 24 test-only entry points, split them out, or defer the suite~~ — **DECIDED.** | **28 `[[Rcpp::export]]`: 20 `ladder_`, 8 `census_`**, from 33 and 24 when this row was written. One question was put to each — can the quantity be had from the published R interface? `stand_gradient` returns one number per (metric, trait) over a whole run, so a Jacobian, an adjoint or a reference evaluated at one state has no route through it, and that is what earns a place. ⚠️ **Two failed and are deleted.** `ladder_field_knots_tf24` is `patch$environment$light_availability$state`, bit-identical in height and value on all six patch fixtures, and its one consumer never read the slope column where the two differ by 1.4e-17. `ladder_range_base_state_tf24` is the first record `store_trajectory()` keeps, or the introduction record that widened into it — bit-identical over 45 ranges on four stands, against an export whose own comment claimed *"a caller cannot read it off the trajectory."* Both are R helpers now, and the ladder is unchanged at 615 pass, 0 fail, 0 skip. ⚠️ **Two are published**, on the rule that the package already ships half of the same facility and the published half misleads alone. `census_clamp_counts_tf24` counts every solve the forward run made, and a caller asking whether a GRADIENT carries a severance reads it and gets the wrong answer — which is what `test-gradient-incidence.R` asserts — so `census_clamp_counts_differentiated_tf24` joins it. `gradient_control` publishes the curvature floor and `stand_gradient_compare` refuses two gradients taken at different ones, and nothing said how close a run came, so `census_curvature_margin_tf24` joins them. Both carry `NEWS.md` lines beside the five counters. ⚠️ **Twenty stay test-only** and eighteen of them on one argument: they are the forward and reverse maps at a point (the five block calls, the five right-hand-side calls, the introduction Jacobian), references taken at another scalar (the trajectory tangent, the initial-state tangent and its replay, the trait difference), or the boundary node's own row and count — which nothing downstream reports, and which `test-census.R` now shows is a live channel in the seed. Measured rather than assumed: `ladder_rhs_value_forward_tf24` is bit-identical to the published `patch$ode_rates` on four fixtures, which is that check's RESULT and not grounds to delete it, since the comparison needs both sides. The other two stay for reasons now at their sites: `ladder_census_trait_direct_tf24` is a reference half, where `stand_census_state_adjoint` is complete for what it claims and `stand_gradient` gives a caller the total, so publishing it would be speculative; `ladder_trait_names_tf24` is `census_trait_names_tf24` at the other concrete type, and RcppR6 generates a wrapper per type, so one function cannot take both a Patch and an SCM. ⚠️ **Unchanged**: a macro guard is unavailable because `Rcpp::compileAttributes()` rewrites `src/RcppExports.cpp` whole and unconditionally, and the install cost still puts a quarter of the build in this one file.

### The rest

| | question |
|---|---|
| **[v]** | **A third of every recorded invasion field is arithmetic, not data -- worth a method or not?** ⚠️ **Sharper since `9b7e1087`, not weaker.** The field is now held against `u = height / height_max` with the 65 knots FIXED at `u_k`, so a field is exactly `{height_max, values[65], slopes[65]}` = 131 doubles and the stored positions are redundant by construction rather than by argument -- they cannot differ between runs, because nothing moves them. The record still stores them, via the `r_init_interpolators` round-trip, at 195 doubles. Dropping them needs one method on `ResourceSpline` -- `set_profile(height_max, values, slopes)` -- to replace that load. ⚠️ **The byte figures want re-measuring**: the ~283 MB / ~90 MB here came off a fixture whose step count the storage fix has since cut by about twenty. The stronger argument was never the bytes: storing 65 positions that can never differ invites a reader to think they could, which is the mistake the knot grid itself made. |
| **[v]** | **What the new tests add to every `R CMD check` leg, on three operating systems.** `tests/testthat.R` is `test_check("plant")`, so all of it runs in the check -- the ladder runner is a developer convenience, not a gate. Re-measured 2026-09-17, per file: ladder **57 s**, `test-census.R` **1.8 s**, `test-mutant.R` **9.9 s**, `test-gradient-incidence.R` **41 s**, `test-gradient-parity.R` **16 s** -- **about 2 minutes** a leg, from 9 and from 31 and from roughly 55 before that. ⚠️ **The earlier 9-minute figure and the mechanism under it were both measured against a reverted storage pool.** That row said a patch lifetime buys a stiff regime and the cohort count is what it costs. There is no stiff regime: bounded, the same TF24 stand reads 206 to 407 accepted steps from patch lifetime 3 to 5 where it read 205 to 9576. The introduction count is still the lever and is now the whole of it, spanning 73x where the lifetime spans 2.4. |
| **[v]** | **Both are fixed.** `test-scm.R` was **1410 s**, of which **1402** was one block -- *"A second run on one SCM reproduces the first"* -- running TF24 twice at `max_patch_lifetime = 10`. It is lifetime 2 now and the file is **7.6 s** with no failures, its schedule deliberately unthinned because those 81 cohorts are what its final state comparison compares. What it guards is `#585`'s defect: `reset()` must reach `Environment::clear()`. `test-canopy-methods.R` was **1620 s** across three TF24 stands grown separately at lifetime 8; one memoised stand at lifetime 2 serves all three and the file is **6.0 s**, 191 checks. ⚠️ **Neither shortening is why the suite is cheap now.** Both were measured against the reverted storage pool, which was most of what made a long TF24 run expensive at all. |
| **[v→D, ANSWERED: removed]** | ~~**Does the diff carry `test-gradient-demo.R` (116 lines)?**~~ **No longer.** ⚠️ **It did not SKIP under `R CMD check` -- it was not in the tarball at all.** `.Rbuildignore` named the file itself, not just the `overstorey_staging/` helpers, so the built package's `tests/testthat/` had no such file and the check's own skip list named only `test-pm-leaf-demo.R`. In the developer loop it ran at **32 pass, 0 skip**. So the question was never what it runs but what the pull request CONTAINS, which is `gradient_ladder.cpp`'s question -- and the author's answer is that the test goes and the 385-line study it guarded stays. |
| **[r→D from B]** | **Does the diff carry `phylloptim/.claude/CLAUDE.md` (12 lines) and `plant/scripts/tf24-active-probe.cpp` (67)?** Neither ships — both paths are `.Rbuildignore`d — so this is not a check failure, it is whether a maintainer should read them. The probe is verified unreferenced: the only mention of its name anywhere is its own header comment. Same class as `gradient_ladder.cpp`: what the pull request contains. |
| **[v, DECIDED: leave]** | **phylloptim names the AD library eighteen times**, four of them raw `using AD = xad::fwd<double>::active_type`, which bypasses `tangent.hpp`'s guard against the 18× nested-tape blow-up. The project's stated rule is that the library is named in odelia and nowhere else. ~~Route them through `tangent_scalar` / `seed_direction` / `derivative_along`, or amend the rule.~~ — **Amend the rule.** plant names it once and keeps the rule; phylloptim keeps its eighteen. |
| **[v, DECIDED: nevermind]** | ~~**`leaf_model.hpp` runs 2,440 lines public before its first `private:`**~~ — **inherited, so not this diff's to fix.** Measured against the merge-base `0709be46`: upstream master already runs **1927 lines** public, and this branch takes it to **2553**. The test set for this row was whether the structure is ours; it is not. ⚠️ Recorded rather than dropped: the diff adds 626 lines to that run, and the invariant comment at `:181` that `private:` would enforce is still unenforced. |
| **[v]** | **Net +237 C++ names and +62 R names** across the three packages, against four real header deletions. The original brief was net deletion. |
| **[v]** | **plant's own headers are compiled as system headers.** `-isystem../inst/include/` sits in `PKG_CPPFLAGS` (`plant/src/Makevars:7`), after every `LinkingTo` include, so every warning in plant's own headers is suppressed. plant is ~95% headers, so the package is effectively un-warned on every toolchain including CRAN's `-Wall -pedantic`. |
| **[v, DECIDED: declined]** | **Install cost: debug info is the driver, not the optimisation level.** `R CMD INSTALL` takes 163.8 s wall at `-j4`, 443.6 s serial over 25 translation units; four of them — `RcppExports`, `gradient_ladder`, `RcppR6`, `census_gradient` — are 74% of that time and 86% of 261 MB of objects. Measured on the two heaviest, replicating: `-g0` alone removes **94%** of the object at either optimisation level and about a third of the compile time, while `-Os` alone removes only a third of the bytes. But `-g0 -Os` — half the time, 6% of the bytes — **cannot be expressed in `PKG_CXXFLAGS` at all**, for the same ordering reason as `-fno-stack-protector`. The routes that reach it are `R CMD INSTALL --strip` (105.99 MB to 7.38 MB) with per-target rules in `src/Makevars`, or `extern template` against the measured 2.8× duplication of `TF24_Strategy`. Removing `gradient_ladder.cpp` takes a quarter of the build with it. |
| **[v, DONE — task 2]** | ~~**Build artefacts are ignored in two files that disagree.**~~ All nine are in `tests/cpp/.gitignore` now, and the phantom `test_leaf_gradient` is gone. ⚠️ **Two of this row's claims did not survive**: `make clean` does NOT leave `probe_preaccumulation` -- `clean:` names all nine -- and there is a THIRD list, `.Rbuildignore`, which was already complete. The two surviving lists cross-reference each other. |
| ~~**[r]**~~ **[v, DECIDED: keep]** | ~~**Defer the forward-mode and replay family?**~~ — **No: forward mode is the referee.** The row named five and was wrong about two. `census_trait_difference`, `census_initial_state_tangent` and `census_initial_state_replay` are each refereed against in the ladder; `ladder_trajectory_tangent_tf24` is what showed the reverse sweep and a forward tangent agree to 1e-11 on the columns the knot grid was breaking. ⚠️ **And it named five where there are four.** `census_trait_tangent` and `replay_initial_state` are `scm.h` bodies rather than exports -- `:1222` under `ladder_trajectory_tangent_tf24`, and `:1327`/`:1353` under the two `census_initial_state_*` ones. The first was read as an orphan export and queued for deletion; it has five call sites across `columns` and `introductions`, and `columns` re-runs at 51 pass, 0 fail. |
| **[v, DONE]** | ~~**`gradient_control()` has a check that cannot fail.**~~ **Fixed on the author's call.** The five values were built in order in `scm.h:284` and the five names attached in order at `R/stand_gradient.R:49`, one file away, while `census_gradient.cpp:85` states the rule three lines above the export: *"a name is what crosses."* `scm.h` returns name-with-value now and the export hands it over named, so there is no second ordering to disagree with. ⚠️ **The test could not fail and now can, measured**: a value wired to the wrong `Control` field FAILS and a renamed entry FAILS, where both comparisons used to be a positionally-built list against itself. ⚠️ **What no test can see is the two 1e-3 entries swapped** -- equal numbers read the same -- which is why this was fixed at the source rather than answered with an assertion. |
| **[v, DONE — task 3]** | ~~**`vulnerability_curve_ncontrol = 400` is written in three places.**~~ Two now: the dead one, `.leaf_control_defaults`, had no consumer at all and is deleted. The rest cannot collapse -- RcppR6 binds only the 15-argument constructor -- and plant's `test-control.R` is the `expect_identical` that ties them. ⚠️ **The golden file was claimed to catch a drift here and does not**: 400 -> 40 moves every golden field by 3.0e-06 against a 1e-05 tolerance. Two comments and the NEWS entry corrected. |
| **[v, DONE — task 4]** | ~~**`closed_form_integral` and `closed_form_curve` take the query slope from different sources.**~~ **Deliberate, and the banner was the defect.** The query row is whichever the assembly already forms: dG/dpsi is formed and d*f*/dpsi is not -- `root_vuln_from_psi.slope()` has zero call sites, every `.slope()` in the package being a dG/dpsi, and the interpolator reads no second derivative. No code moved; the banner states the rule. |
| **[v, DONE — task 1]** | ~~**phylloptim ships two C++ test binaries that never run.**~~ ⚠️ **They run.** `make all`, `cpp-tests.yml` and `ctest` all run both; `tests/cpp.R` was the one leg missing them. `test_supplied_rows` joins it at 178 checks in 0.044 s. `test_transpose` cannot -- it needs odelia's `src/Tape.cpp`, which an installed odelia does not ship -- and `cpp.R` says so now, as `CMakeLists.txt:175` already did. |
| **[r]** | **phylloptim cannot compile against `traitecoevo/odelia` master** (`leaf_model.hpp:17` needs `odelia/with_slope.hpp`), which is what `cpp-tests.yml:54` checks out. Its CI is red until odelia lands and the workflow points at the tag. |
| ~~**[r]**~~ **[v, BOTH STALE]** | ~~**Two assertions that cannot fail.**~~ Neither survives a read of the files as they are. `test-gradient-ladder-sweep.R` contains no `expect_null` and no `blocked` at all; its first block asserts `expect_false(any(stand_gradient_refused(g)))` and `expect_gt(sum(is.finite(g$gradient)), 0)`, which is the non-vacuity the row wanted. And `declared-zero.R:161` is a `setdiff` over every column outside the birth-size set, guarded by `expect_gt(length(others), ...)` -- the written pair the row describes is gone, and the comment above it records that exact defect and its fix. ⚠️ **One thing the row did not name and is worth a look**: the loop at `:85` `next`s on a measured `spread > 1e-3`, and nothing counts how many parameters reached the assertion, so a reference that went out of domain on all of them would assert nothing and say so only in a `message()`. |

---

## E. ~~Escape hatches~~ — CLOSED **[v]**

**The ladder reports no skips.** Measured before and after, one process, `-O2`:

| | files | pass | fail | skip |
|---|---|---|---|---|
| before | 15 | 553 | 0 | **4** |
| after | 14 | 615 | 0 | **0** |

The nine failures this section used to sit beside are `test-gradient-incidence.R`
(6) and `test-gradient-parity.R` (3), which carry **no skips and no gate
machinery at all** — the one match for "skip" in either file is a comment about
an off-by-one window. They are A1's `scientific_version` decision and were never
E's.

### What the four skips were, and what replaced each

| was | now |
|---|---|
| `declared-zero:99` — an unconditional `skip()` at the END of a block whose assertions had already passed, discarding them | the skip's own text said every ratio reads 1.000 and 1e-04 would hold with an order of margin. Its objection was to a bound taken off the step ladder, because that reference's floor is measured as a gap between steps and reads the opposite of an error that rises as the step falls. A bound of **1e-02** makes no claim about convergence order and still rejects a dropped channel (0 or infinite), a sign flip (−1) and a row at a fixed fraction (0.5). Asserted. |
| `declared-zero:55` — `if (spread > 1e-3) skip(...)` immediately above `expect_lt(spread, 1e-3)`, so the assertion could not fail | the block is titled *"the whole-run difference is in its own domain on this fixture"*, and measurement says it is. The fixture is written and the step ladder is fixed, so the reference resolving is a property of the pair — and it ceasing to is the model having moved. The skip is gone; the assertion is live. |
| `sweep:27` — `skip_if(is.null(blocked))`, and `blocked` is always `NULL` | **deleted, and the requirement with it.** The block asserted that the water channel's absence must not block metrics it cannot reach. Four blocks later the file *measures* that a per-metric channel would spare nothing on TF24's census — every metric is a size moment but growth reads water — and the block above discharges independence unconditionally on an injected fixture. The comment at *"both output kinds answer at a shut point"* says so outright. A retired requirement kept alive behind a skip that could never not fire. |
| `production-scale` ×2 — `PLANT_LADDER_SCALE`, set by nothing | **file deleted.** Its first block asserted *"must not skip: that is the whole property being added here"* and then skipped. It recorded rather than asserted, so it was a note, not a check. Its one real statement — that heights stop being non-commensurate at length — now sits on the fixture below, where it is measured. The gap it stood for is in `NEWS.md` under Known issues. |

### The machinery under them was unreachable, not dormant **[v]**

⚠️ **`ladder_declared_refusals()` had two entries and neither could fire.**
`"does not record at an active scalar"` appears **nowhere but the whitelist** — not
in plant, odelia or phylloptim, and not as a string in `plant.so`.
`"size-density coordinate only"` is emitted at `scm.h:183` and is reachable only
from a stand built with `node_density_in_birth_date = FALSE`; one test builds one
and asserts on it with `expect_error` directly, bypassing the gates, while every
other fixture goes through `ladder_control()`, which pins the flag `TRUE`.

So `ladder_gradient_or_skip`, `ladder_block_or_skip`, `ladder_skip_if_refused` and
`ladder_sweep_blocked` — 30 call sites — guarded one condition no gated site could
produce and one nothing produces at all. The 25-line self-test that pinned their
behaviour checked only that the list was non-empty, so the dead string passed it.
All of it is deleted; a refusal now fails the file that asked for it.

`ladder_require_regime` (17 sites, 0 fires) **asserts** rather than skips. The
fixtures are written rather than reached, so leaving a regime is the model moving
under a fixture that did not — which is the one event the suite exists to report.

### E4 and E6

`test-gradient-ladder-identity.R` carries a finite-count guard on each of its
blocks. `identical(NaN, NaN)` is `TRUE` in R, and every bit-identity in that file
held against a gradient that was entirely not-a-number.

**E6 is half closed and the other half is written down.** Range count and run
length are confounded only in the DEFAULT schedule, which derives its introduction
count from the patch lifetime. Written introduction times separate them:
`ladder_stand_many_ranges()` puts **62 introductions, 62 ranges and 68 accepted
steps** in a run of under half a year, and the split identity holds there bit for
bit at 288 of 288 finite, in 3.2 s for both sweeps. Every other trajectory rung
runs at six ranges; the product runs at 169.

What that does not reach is the step count — 68 against ~3,400 — so nothing says
the step loop or the recording's footprint behaves at production length. That
half is a `NEWS.md` Known-issues entry rather than a switch nobody sets.

### Not this pull request's **[v]**

Most of what E5 listed is inherited, and touching it widens the diff into files
this branch edits for a mechanical rename:

- `test-ff16-ad-kernel.R`, `-deep-crown-ad.R`, `-resident-coupling-ad.R` arrived at
  `edbad184` (#540) with `is_pkgload_dll_plant()` already in place. This branch
  only renamed XAD spellings to odelia's.
- odelia's `test-dll-load.R` (#6), `test-rodas.R` (#35) and `helper-load-odelia.R`
  (#6) are on `upstream/master`, gates included.
- odelia's `test-vector-jacobian-product.R` **is** ours, and its skip stays: it
  fires only when a `sourceCpp` probe cannot link odelia's tape symbols, which
  happens in a `load_all("odelia")` session that `AGENTS.md` tells developers not
  to use, and it re-raises anything else. Measured: 8 pass, 0 skip with odelia
  installed. A skip on a reachable condition that names its cause is the honest
  form; the deleted ones were neither.
- `phylloptim/tests/cpp.R:44` exits 0 when the C++ suite could not run. Still
  open, and it is phylloptim's — it sits in D beside `test_transpose` and
  `test_supplied_rows`, which are outside `R CMD check` entirely.

### `test-gradient-demo.R` was misread here twice, and is now gone **[v]**

This section said the file skips on every leg because its helpers are absent. It
did not: `scripts/run-tests.sh` sets `NOT_CRAN=true` deliberately, so in the
developer loop it ran at **32 pass, 0 skip**. ⚠️ **Nor did it skip under `R CMD
check`**, which was the second reading -- `.Rbuildignore` named the file itself,
not only the `overstorey_staging/` helpers, so the tarball had no such file to
skip. D answered the question that left: a maintainer never saw it and only a
reader of the diff did. **The file is removed.** What it guarded stays in the
diff, unguarded, which is recorded at the head of `gradient_demo_helpers.R`.

### The instrumentation surface

`src/gradient_ladder.cpp` is **28 entry points**, down from 33. The two block name
lists are gone: every block matrix now carries its own `dimnames`, so a caller
cannot hold a name list and a matrix that disagree about which node the block was
formed at; `ladder_node_count_tf24` is gone because `Species$size` answers it from
R; and `ladder_field_knots_tf24` and `ladder_range_base_state_tf24` are gone
because the published interface already answers them — see D. The prefix
**partitions** them, which the file's own header used to flag as wrong: 20 are
`ladder_`, called from `tests/testthat/` and nowhere else, and the 8 spelled
`census_` are exactly the ones `NEWS.md` publishes with migration lines — the
five incidence counters, `census_trait_gradient_split_tf24`, and the two D
promoted because the published half of their facility misleads alone.

What is left is not excess, and none of it is dead: every entry point has a caller
in `tests/testthat/` or `scripts/`, re-checked by name after the test
restructuring and again after the two deletions. A transpose cannot be refereed from its composition:
`stand_gradient` returns one number per (metric, trait) over a whole run, and a
wrong row is wrong in both directions. The four references need to see the forward
and reverse maps at one point, and reference 4 exists because differencing a
*recorded* step returns exactly zero on precisely the columns a supplied row
occupies — right, wrong or absent.

---

## Not a problem, for the record

Claims checked this round that did not survive, so nobody re-opens them:

- **The 105 MB library.** 93% DWARF from our own `-O2 -g` profiling install.
  `size -d` gives 6.16 MB of text; `strip --strip-debug` gives 7.38 MB. An
  ordinary install ships about 7 MB. **[v]**
- **A TF24 model-version regression.** Merge-base, ours and upstream agree we
  never touched `scientific_version`; upstream moved forward. See A2. **[v]**
- **`sweep.hpp` and `rates_adjoint` as dead code.** Four call sites in
  `plant/inst/include/plant/scm.h` and one in `gradient_ladder.cpp`. odelia is a
  header library; single-repo dead-code analysis cannot see its consumers. **[v]**
- **A structural zero in `probe_tf24f_active.cpp`.** `dprofit_dpsi_` is
  templated, not narrowed, and the file is a deliberate compile-time falsifier. **[v]**
- **Refusal being coarser than documented.** `scm.h` and `refusal.md` agree
  exactly: all metrics go together because the failing row is an intermediate of
  a recording spanning every cohort and stage. **[v]**
- **`-Os` or `-g0` in Makevars as a build-size remedy.** Measured inert, for the
  same reason `-fno-stack-protector` is: R places `PKG_CXXFLAGS` before the
  distro's `CXXFLAGS`. Use `--strip` at install instead. **[v]**
- **A migration burden for `spline.hpp` / `ode_fit.hpp`.** Nothing in any of the
  three trees included either. **[v]**
