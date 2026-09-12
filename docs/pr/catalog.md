# What to fix before submitting

A gate on `docs/pr/`. The three branches carry work worth merging and, alongside
it, scaffolding, stale claims and two red suites. A maintainer should receive
the first and none of the second.

Every entry is marked **[v]** where I reproduced it against the code myself, or
**[r]** where it is an agent's finding I have not independently run down. Treat
an **[r]** as a lead, not a fact: of the findings checked this round, several
were wrong in instructive ways — a symbol called dead had four consumers in
another repository, a "reverted" model version was upstream moving forward, and
a 105 MB library was our own `-g` build.

---

## A. Blockers

Nothing ships until these are closed.

### A1. The red suites **[v]**

| suite | how it fails |
|---|---|
| `plant` `test-strategy-tf24.R` / `-tf24f.R` **[v, added]** | **A third red suite, and it predates the merge.** 17 + 2 failures. Four were the `Defaults` fixtures pinning `root_b` as develop's literal and omitting `root_P50`, which this branch has carried since `e9ff23f6` — fixed in `95a88949`. The rest are pinned scenario values this branch no longer produces: `offspring arrival` pins 30.22207354 and the **pre-merge** tree returns **81.995393**, measured directly at `e9ff23f6`. Merged, the same scenario returns 56.4 with the path integral and 82.0 with it collapsed — so upstream's new "height-linear parameters reproduce the pre-path-integral results" recovers the pre-merge number to four figures and the merge is not the cause. This branch is ~2.3–2.7× develop on this scenario either way, and four storage-rate tests move with it. ⚠️ **These pins cannot be re-blessed without the same `scientific_version` decision A1 already needs** — re-pinning to make a run green is how a real change to a model's science gets waved through. |
| `plant` `test-gradient-incidence.R` (6) / `test-gradient-parity.R` (3) **[v, added]** | **The merge moved the leaf's operating point, and these fixtures assert where it lands.** Measured on `incidence_stand(0.25, 10)`, pre-merge `e9ff23f6` against the merged tree: interior placements 5,336,853 → 207,790, dry pins 27,271 → 2,510,686, **dry share 0.51% → 92.36%**, all on the continuity-root arm. The lifetime-10 stand that used to refuse for its descent's range now answers. In `parity`, `seasonal` moved from answered to refused (`left the representable range`) and the `shaded` driver stopped reaching `shade-death` at all. This is develop's #617 doing what its own comment predicts — lower resistance, faster transpiration, the shared soil column drawn down — reaching fixtures calibrated on the pre-#617 model. ⚠️ **Not a gradient defect:** every derivative referee is green, including phylloptim's transpose identity over all four operating-point kinds (147 checks, worst relative 5.1e-11). Recalibrating these fixtures accepts an ecological change and belongs with A1's `scientific_version` decision, not beside it. |
| ~~`plant` `test-node.R`~~ **[v, fixed]** | **A red suite nothing had named, and it was ours.** 3 failures, one per model: `Node$ode_rates` reported **0** for the density rate where FF16 gives −0.787, TF24 −1.423 and K93 −0.0387. `compute_initial_conditions()` took the node's rates *before* seating its state, so the `density > 0` guard fired on the density a node being born has not got yet — `exp(-Inf)` — and the zero it wrote stood for the whole first evaluation. The offspring rate had the same shape through `survival_individual()`. The guard arrived in `a02588c1` on this branch, so develop never carried it. Fixed in `66941c0a`: both rates move to one `compute_node_rates()` that each caller reaches after the state it is responsible for exists, and the two copies of the guard become one. No trajectory moves — the whole-run rung holds at 13/13 against a reference captured before it, and the gradient suite is unchanged at 710 over nineteen files. |
| `plant` `_snaps/model-version.md` | Stale and self-contradictory: 62 parameters snapshotted against 64 declared, `vulnerability_curve_ncontrol` recorded as 100 where the code gives 400, `control.gradient_curvature_floor` absent, and TF24 names (`p_50`, `b`, `c`) the `.yml` no longer declares. An untracked `model-version.new.md` holds the real surface. |
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

### A4. Five `R CMD check` WARNINGs, all new on this branch **[v]**

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

## B. ~~Remove before submitting~~ — CLOSED **[v]**

Everything below is done. `plant/src/gradient_ladder.cpp` is not a removal and
has moved to D: both of the options named for it change what the pull request
contains, which is the author's call rather than a tidy-up.


Roughly 4,000 of the 33,640 added lines, with no loss of coverage.

| | what | lines | why |
|---|---|---|---|
| **[v]** | `odelia/tests/standalone/probe_*.cpp`, seven files | 2,034 | In no `all:` target and no workflow. `probe_nested_recording.cpp` alone is 1,023 lines. They are measurements; under `tests/` a maintainer reads them as checks. Move to `notes/` or `bench/`. |
| **[v]** | `phylloptim/tests/cpp/probe_preaccumulation.cpp`, `probe_tape_regions.cpp` | 563 | Same. And the binaries **do** ship: `.Rbuildignore:46-50` names only the five older ones, and building with all four new binaries present took the tarball from 1,277,427 to 2,500,921 bytes. `R CMD check`'s `check_executables()` warns on undeclared executables, which for phylloptim is a red leg. |
| **[→D]** | `plant/src/gradient_ladder.cpp` | 1,071 | **Moved to D.** Not a removal: every option changes what the pull request contains. The finding holds and is sharper than written — the callers are 13 test files, not one helper. |
| **[v]** | `plant/tests/testthat/reference/reference-kinds.tsv` | 121 | Nothing reads it, and its generator `scripts/generate_reference_run.R` is deleted in the same diff, so it cannot be regenerated either. |
| **[v]** | `plant/tests/testthat/test-gradient-demo.R` | 116 | Gated on `overstorey_staging/`, which is `.Rbuildignore`d. `R CMD check` runs from the tarball, so all six tests skip on every CI leg. |
| **[v]** | `plant/tests/testthat/test-gradient-ladder-production-scale.R` | 48 | Both tests skip on `PLANT_LADDER_SCALE`, which nothing in any repo, workflow or script sets. Its own comment: *"a suite that skips where it is meant to scale reports green for not having run."* |
| **[v]** | `plant/tests/probes/probe_tf24f_active.cpp` | 46 | A compile-time falsifier ("Never run. Instantiating it is the whole test") that no build compiles. `tests/` is not `.Rbuildignore`d, so it ships. Wire it into a build or drop it. |
| **[r]** | `helper-gradient-ladder.R` `ladder_injected()` / `PLANT_LADDER_INJECT` | — | Defined, never read. The fault-injection contract advertised at `:10` is unimplemented. |
| **[r]** | `phylloptim/.claude/CLAUDE.md` | 12 | Agent-facing scratch in a public pull request. |
| **[r]** | `plant/scripts/tf24-active-probe.cpp` | 67 | "Nothing runs it for you." |
| **[r]** | `odelia` `compat_interpolator::add_point`, `get_x`, `get_y`, `r_eval`; `Solver::get_control()`, `get_history()` | ~26 | No consumer in any of the three trees. |
| **[v]** | `plant/.Rbuildignore:31` | — | `^inst/RcppR6*$` does not match `inst/RcppR6_classes.yml` — confirmed against R's own `grepl`. The 57,873-byte file ships and installs. Write `^inst/RcppR6_classes\.yml$`. |
| **[r]** | odelia ships `AGENTS.md`, `ARCHITECTURE.md`, `CLA.md`, `.claude/CLAUDE.md` | ~16 KB | plant and phylloptim ignore all four; odelia's `.Rbuildignore` has no such lines. |
| **[v]** | `phylloptim` `FixedCollarEval` | — | No consumer anywhere, tests included. `clamp_sites.hpp:37` cites a `profit_at_fixed_collar` that exists nowhere. |

Also **[r]**: the shim `compat_interpolator` / `basic_interpolator` / `Interpolator`
is documented as keeping phylloptim and plant compiling while they migrate, and
both migrate in these same pull requests. plant already uses
`hermite_interpolator` directly. Ship the migration or the shim, not both.

---

## C. Correct before submitting

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

### C2. The design docs have errors of their own **[v]**

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

### C3. The changelogs **[r, with [v] where noted]**

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

### The four that block a submission

These are not style questions. Three of them revert something upstream shipped or
accept a change to the model's science; the fourth decides what the pull request
contains. Nothing else in D does either.

| | decision | what is known |
|---|---|---|
| **A1** | **What `scientific_version` should say.** | Three suites turn on it, not two: `_snaps/model-version.md`, `phylloptim`'s `test_golden`, and `test-strategy-tf24.R`'s scenario pins. The pins are the sharpest statement — measured at `e9ff23f6`, the pre-merge tree returns **81.995393** where its own test pins **30.22207354**, so this branch has been ~2.7× develop on that scenario and nothing recorded it. Re-pinning any of the three accepts a change to the model's science, which is the one thing AGENTS.md says must be named rather than waved through. |
| **run_mutant** | **Restore it, or ship regressed against `develop`.** | `SCM::run_mutant` is a `stop()` here and works on develop, where #643 restored it for TF24. The recorder it needs was reached through solver hooks this branch's rewrite stopped calling; the replacement its own comment names, odelia's `ReplaysField`, **does not exist**. Recorded under plant's Known issues and skipped with the reason at the test, so nothing is silent — but it is a capability a maintainer just merged and would be receiving back broken. |
| **the operating point moved** | **Recalibrate the incidence and parity fixtures, or hold.** | develop's #617 took the dry share from **0.51% to 92.36%** on `incidence_stand(0.25, 10)`, `seasonal` from answered to refused, and `shaded` from reaching shade-death to not. Nine gradient-suite failures, none of them a derivative: every referee is green, including the transpose identity over all four operating-point kinds at 5.1e-11. Moving the fixtures accepts the ecology; leaving them accepts nine red. |
| **`gradient_ladder.cpp`** | **Ship 33 test-only entry points, split them out, or defer the suite.** | 1,071 lines and 33 `[[Rcpp::export]]` — not 34; one is inside a comment. **Not on the package's R interface:** none is in `NAMESPACE`, so all are reachable only as `plant:::`, and they are 23 of the 1,171 exports `RcppExports.cpp` already carries; `test_gradient_fd1`, `test_gradient_richardson` and `test_uniroot` are this package's existing precedent for a test-only export. ⚠️ **And five of them are not test-only at all** — `census_operating_point_counts_tf24`, `_names_tf24`, `census_clamp_counts_tf24`, `_names_tf24` and `census_clear_diagnostics_tf24` are published in `NEWS.md` under *Added* as the incidence-counter interface, which the `plant-update-interface` skill reads as a spec. They are the only route to "how often", and they are what diagnosed *the operating point moved* two rows up. So the decision covers ~28, not 34. ⚠️ **The reason a macro guard is unavailable is not that R compiles everything in `src/`** — it is that `Rcpp::compileAttributes()` rewrites `src/RcppExports.cpp` whole and unconditionally, so a guard here without a matching one there is an undefined symbol at link time, and a guard there is lost on the next regeneration. `gradient_ladder.cpp` says so at its head. Collapsing the families to shrink the surface was measured and is not worth it: the five block calls a test makes in a row cost **13 ms** together, so merging them saves nothing, and the census five cannot be merged without contradicting a published note. What remains true is the install cost — the measurement under *Install cost* below puts a quarter of the build in this one file.

### The rest

| | question |
|---|---|
| **[v]** | **phylloptim names the AD library eighteen times**, four of them raw `using AD = xad::fwd<double>::active_type`, which bypasses `tangent.hpp`'s guard against the 18× nested-tape blow-up. The project's stated rule is that the library is named in odelia and nowhere else. Route them through `tangent_scalar` / `seed_direction` / `derivative_along`, or amend the rule. plant names it once. |
| **[v]** | **`leaf_model.hpp` runs 2,440 lines public before its first `private:`**, exposing ~90 raw state fields including this branch's own additions, and an invariant comment at `:181` that `private:` would enforce. |
| **[v]** | **Net +237 C++ names and +62 R names** across the three packages, against four real header deletions. The original brief was net deletion. |
| **[v]** | **plant's own headers are compiled as system headers.** `-isystem../inst/include/` sits in `PKG_CPPFLAGS` (`plant/src/Makevars:7`), after every `LinkingTo` include, so every warning in plant's own headers is suppressed. plant is ~95% headers, so the package is effectively un-warned on every toolchain including CRAN's `-Wall -pedantic`. |
| **[v]** | **Install cost: debug info is the driver, not the optimisation level.** `R CMD INSTALL` takes 163.8 s wall at `-j4`, 443.6 s serial over 25 translation units; four of them — `RcppExports`, `gradient_ladder`, `RcppR6`, `census_gradient` — are 74% of that time and 86% of 261 MB of objects. Measured on the two heaviest, replicating: `-g0` alone removes **94%** of the object at either optimisation level and about a third of the compile time, while `-Os` alone removes only a third of the bytes. But `-g0 -Os` — half the time, 6% of the bytes — **cannot be expressed in `PKG_CXXFLAGS` at all**, for the same ordering reason as `-fno-stack-protector`. The routes that reach it are `R CMD INSTALL --strip` (105.99 MB to 7.38 MB) with per-target rules in `src/Makevars`, or `extern template` against the measured 2.8× duplication of `TF24_Strategy`. Removing `gradient_ladder.cpp` takes a quarter of the build with it. |
| **[v]** | **Build artefacts are ignored in two files that disagree.** `phylloptim/.gitignore:18` covers `tests/cpp/test_golden`; `tests/cpp/.gitignore` covers the probes and `test_transpose`/`test_supplied_rows`, names a `test_leaf_gradient` that has never existed in any of the three trees, and omits `test_leaf` and `test_primitives`. `make clean` leaves `probe_preaccumulation` behind. One list, in one file, matching what `build:` builds. |
| **[r]** | **Defer the forward-mode and replay family?** `census_trait_tangent`, `census_trait_difference`, `census_initial_state_tangent`, `census_initial_state_replay`, `replay_initial_state` — the reverse-mode gradient this PR ships calls none of them. |
| **[v]** | **`gradient_control()` has a check that cannot fail.** It returns five values positionally and R names them; `ci_abs_tol` and `gradient_curvature_floor` are both `1e-3` at defaults, so transposing them passes both assertions while `stand_gradient_compare()` refuses on the wrong pair. Return names beside the values. |
| **[r]** | **`vulnerability_curve_ncontrol = 400` is written in three places** — one C++ constant and two R literals — with only a cross-package test tying any two, and it compares plant's C++ value against phylloptim's R literal. |
| **[r]** | **`closed_form_integral` and `closed_form_curve` take the query slope from different sources**, and the file's banner says both do it identically. One agent called the asymmetry deliberate and measured; another called it a bug. Settle it. |
| **[v]** | **phylloptim ships two C++ test binaries that never run.** `test_supplied_rows` and `test_transpose` are in `Makefile` and `CMakeLists.txt` but not in `tests/cpp.R:108`. The file's own comment at `:46` demands a four-way sync; three of four were updated. `test_transpose` is 147 checks in 0.11 s — the best value in the three repos, and it does not run. |
| **[r]** | **phylloptim cannot compile against `traitecoevo/odelia` master** (`leaf_model.hpp:17` needs `odelia/with_slope.hpp`), which is what `cpp-tests.yml:54` checks out. Its CI is red until odelia lands and the workflow points at the tag. |
| **[r]** | **Two assertions that cannot fail** beyond the ones already known: `test-gradient-ladder-sweep.R:14` asserts `expect_null(blocked)` and `:27` skips on the exact complement; `test-gradient-ladder-declared-zero.R:161` loops over two names and `next`s on one that is in the list it filters against. |

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
