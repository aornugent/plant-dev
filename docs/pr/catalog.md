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

### A1. Two test suites are red **[v]**

| suite | how it fails |
|---|---|
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

### A3. Defects in the model's own use case

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

### A5. The exactness claim has two open columns **[v]**

`theta` and `omega` disagree **in sign** with the only reference that shares no
arithmetic with the sweep — `mass_above_ground` reads 3407 against −1074, and
−1466 against +1487, where that reference resolved itself to 0.7–10%. The test
reporting it ends in a bare `skip()`. A pull request headed "computes the exact
derivative" cannot leave that behind a skip. Fix, or state it in the body.

`plant/tests/testthat/test-gradient-ladder-whole-run-difference.R:55-65, 179`

---

## B. Remove before submitting

Roughly 4,000 of the 33,640 added lines, with no loss of coverage.

| | what | lines | why |
|---|---|---|---|
| **[v]** | `odelia/tests/standalone/probe_*.cpp`, seven files | 2,034 | In no `all:` target and no workflow. `probe_nested_recording.cpp` alone is 1,023 lines. They are measurements; under `tests/` a maintainer reads them as checks. Move to `notes/` or `bench/`. |
| **[v]** | `phylloptim/tests/cpp/probe_preaccumulation.cpp`, `probe_tape_regions.cpp` | 563 | Same. And the binaries **do** ship: `.Rbuildignore:46-50` names only the five older ones, and building with all four new binaries present took the tarball from 1,277,427 to 2,500,921 bytes. `R CMD check`'s `check_executables()` warns on undeclared executables, which for phylloptim is a red leg. |
| **[v]** | `plant/src/gradient_ladder.cpp` | 1,071 | 34 `[[Rcpp::export]]` entry points, **not one called from `plant/R/`** — every caller is `helper-gradient-ladder.R`. 34 names on the compiled ABI, held up by the thing they check. Follow-up PR, or a test-only translation unit. |
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

### C1. Comments and man pages that are false **[v unless marked]**

Ordered by who is misled.

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
