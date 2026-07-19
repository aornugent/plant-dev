# Handoff — odelia AD engine × plant SCM gradients

This document is the entry point for any new session. It has two parts: an
**authoritative header** (persistent — how to rebuild context correctly, and the
hard-won rules that must not be relearned), and a **state + next-steps** section
(rewritten each session).

---

# PART 1 — AUTHORITATIVE HEADER (persistent; do not delete or weaken)

## What this project is
Build a reverse-mode automatic-differentiation engine, **`odelia`**, that computes
exact trait/parameter gradients of the **`plant`** size- and trait-structured
forest model's emergent SCM outputs (census metrics — LAI / biomass / basal area —
and R0 / offspring). The v2 objective *in lights*: **improve odelia's primitives so
the plant developer experience is pain-free** — abstractions that *reduce*
complexity, not named objects for their own sake. Use the `system-design` and
`code-review` skills for anything structural; the AGENTS style guides apply.

## Repos, branches, layout (verify at session start — numbers below drift)
- **Superrepo:** `/home/user/plant-dev` — holds `docs/`, the `plant` submodule, and
  `odelia/`. Branch: `claude/odelia-ad-tape-reverse-496fuf`.
- **plant:** git submodule. Branch `claude/odelia-ad-tape-reverse-496fuf`; base is
  `develop` (merge-base `96941d3b`). Header-only C++ in `inst/include/plant/`; the
  SCM is the runnable.
- **odelia:** `/home/user/plant-dev/odelia`. Branch `claude/odelia-ad-tape-reverse-496fuf`;
  **default branch is `master`** (merge-base `c9ae31b`). Header-only C++ in
  `inst/include/odelia/`. plant `LinkingTo` it.
- **Git discipline:** develop only on `claude/odelia-ad-tape-reverse-496fuf` (both
  repos). Commit in plant → bump the superrepo submodule pointer → push both. Commit
  trailers required (`Co-Authored-By` + `Claude-Session`). The model id must NOT
  appear in commits/code/artifacts (chat only). Never push to `traitecoevo/*`.

## HOW TO REBUILD CONTEXT FROM SCRATCH (do this in order, every fresh session)
1. **Read `odelia/AUTODIFF.md` FIRST.** It is the authoritative account of the AD
   workflow: the two orthogonal axes (Replay L1/L2/L3 × Functional), ownership (the
   **Solver owns the schedule L1**; the System owns its background L2/L3), the System
   contract, and **the one way to get it wrong** (populating the L3 field-value cache
   silently drops a background's feedback derivative). Internalize the invariant:
   **`recorded_steps()` is the SINGLE source of the replay grid, so it "can't go
   inconsistent," guarded by one forgot-to-record check.**
2. **Read `odelia/AGENTS.md` and `plant/agents.md`** (dev workflow, style, build/test).
3. **Read `docs/design.md`, `docs/build-plan.md`, `docs/odelia-index.md`** (the
   what/why, the phased plan, and the authoritative concept set / names).
4. **Diff odelia against `master`, NOT develop.** odelia's default is `master`; the
   AD engine is a large branch (~28 commits), **NOT merged**. Diffing the wrong base
   hides the entire engine and wasted a session:
   `git -C odelia diff --stat $(git -C odelia merge-base HEAD master) HEAD`.
   Diff plant against its base: `git -C plant diff --stat $(git -C plant merge-base HEAD origin/develop) HEAD`.
5. **VERIFY the installed odelia == the odelia branch HEAD before touching plant.**
   plant compiles against the **installed** odelia headers
   (`system.file("include", package="odelia")`), not the submodule tree. Check:
   `diff -q "$(Rscript -e 'cat(system.file("include",package="odelia"))')/odelia/gradient.hpp odelia/inst/include/odelia/gradient.hpp`.
   If you edit odelia headers, **reinstall odelia** (`cd odelia && make compile` or
   `R CMD INSTALL .`) then rebuild plant — keep them in lockstep (co-designing DX
   spans both repos).

## RULES THAT MUST NOT BE RELEARNED (each cost real time this session)
- **The correctness reference is the fully-adaptive real-model FD** — perturb a trait
  and re-run `run_scm` (adaptive stepping) at ±δ, central difference. A
  **pinned-schedule FD is NOT the truth**; treating it as truth sent a multi-turn
  chase after phantom "schedule sensitivity" and "detached edges." K93 gradients are
  FD-correct (all three of AD / pinned-FD / adaptive-FD agree). When AD disagrees with
  a pinned-FD, suspect the *replay grid*, not the model.
- **The replay grid has ONE legitimate source: `SCM::r_ode_times()` (== `solver.times()`
  == odelia's `recorded_steps()`).** `patch.step_history` (populated by the
  `save_RK45_cache` Control flag) is the SEPARATE **`run_mutant` L3 legacy** record and
  is **deferred** — never use it for a resident gradient replay. Pinning `step_history`
  gave a 60× wrong gradient (−255/+442); pinning `r_ode_times()` gives the correct one.
- **A "wrong gradient" is a schedule/replay bug until proven otherwise.** Before
  hypothesizing model or field bugs: (a) confirm the replay grid is `r_ode_times()`;
  (b) compare against the adaptive `run_scm` FD; (c) isolate with a single-step probe.
  The separable field, K93, and FF16's per-step `compute_rates` are all proven correct.
- **Build/verify tax (plant):** header-only changes do NOT recompile via a plain
  `R CMD INSTALL` (it reuses stale `src/*.o`). After editing plant headers:
  `rm -f plant/src/*.o plant/src/*.so && R CMD INSTALL plant --no-multiarch --no-docs`
  (~3 min). Gradient/driver tests are `sourceCpp` files linking the compiled
  plant+odelia `.so` (`-isystem<plant_inc> -I<odelia_inc> -I<BH_inc>`); run with
  `NOT_CRAN=true TESTTHAT_PARALLEL=false`. Use `pkgload::load_all` (not devtools).
  **Run Rscript from `/home/user/plant-dev`** — a `cd plant` in a prior Bash command
  leaves the shell there and `load_all("plant")` then fails ("no package called
  'plant'"); pass an explicit `cd /home/user/plant-dev &&`.
- **Commit messages via heredoc `-F -`** (inner double-quotes in `-m` break the shell).
- **Don't over-conclude.** This session flipped between "detached edge" and "no
  detached edge" before the real cause (bad replay grid) surfaced. State findings as
  *what was measured*, verify the premise before building on it, and prefer a cheap
  decisive probe over another confident hypothesis.

## The AD workflow in one paragraph (so you can sanity-check any gradient)
Run the SCM **adaptively once** — this discovers and records the step schedule
(`solver.times()` / `recorded_steps()`, the L1 grid) and any adaptive background's node
positions. Then, for the gradient: lift the System to the active (AD) scalar via
`rebind`, seed the chosen inputs (`ad_parameters()`/`ad_initial_state()`), and **replay
on the recorded L1 grid** (`advance_fixed`), reducing the replayed run through a
**functional** (a pure reduction: reads state, returns scalar(s)). One reverse sweep
(`xad::computeJacobian`) yields the whole gradient; only `double` crosses back to R.
For a resident (self-shading) gradient the background's L3 value cache stays **empty**
so the field is recomputed at the active scalar and its feedback derivative flows.

---

# PART 2 — CURRENT STATE & NEXT STEPS (rewrite each session)

_Last updated: 2026-07-19._

## Where things stand
- **odelia engine:** the full documented AD surface is on the branch (28 commits ahead
  of master), installed and **synced** (installed headers byte-identical to HEAD
  `67793a5`): gradient driver (`compute_jacobian`/`gradient`/`jvp`), `separable_field`,
  `implicit_node`, `incomplete_gamma`, `decide`/value-guards, `mass_transport`,
  `supplied_derivative`, RODAS, Solver L1 record/replay. No odelia work is pending for
  the immediate task.
- **plant P2a (K93):** DONE and correct. K93 reads its deep-crown light from the exact
  `separable_field`; census and offspring/R0 gradients match the adaptive FD; the
  redundant light spline is dropped on the K93 path. All K93 double suites green.
- **plant P2b (FF16):** the exact `separable_field` is integrated for FF16's deep-crown
  light (double path within tol, all double suites green). Its R0 gradient is **not yet
  gated correct** — but the cause is now fully understood (below), not a model bug.
- **Trees:** clean. plant HEAD `57e27619`, superrepo HEAD `ab17a51`, odelia HEAD
  `67793a5`. plant is 69 commits ahead of base; odelia 28.

## The resolved finding (the whole FF16 saga, in one place)
The FF16 R0 "wrong gradient" (reverse AD `+442`, a pinned-FD `−255`, while the real
adaptive gradient is `+4.2`) was **NOT** schedule sensitivity, **NOT** a detached edge,
**NOT** a field/model bug. Proven this session:
- Single FF16 plant in fixed light: `d(growth)/d(lma)` is **exact** (AD == FD, 6 digits).
- One `compute_rates` + field assembly on a frozen state: **exact** (AD == FD);
  `d(light)/d(lma)` through the frozen field is exactly 0. The `separable_field` read is
  proven exact by `test-ad-ff16-field-crown.R`.
- The real gradient (adaptive `run_scm` FD) is `+4.2`, and a pinned FD that replays on
  the **correct** grid (`r_ode_times()`, what `run_scm(use_ode_times=TRUE)` uses) also
  gives `+4.2` and tracks the adaptive R0 curve to ~1e-5.
**Root cause:** the standalone gradient drivers pinned `patch.step_history` (the
`save_RK45_cache`/`run_mutant` L3 legacy record) as the replay grid instead of
`r_ode_times()`. Plant's SCM broke odelia's single-source-of-the-replay-grid invariant
by having two sources; the driver picked the wrong one. See `docs/build-plan.md`
(CD-G "ROOT CAUSE" + "DESIGN" blocks) for the full write-up.

## The design (system-design skill; Tier 2; floor wins — committed in build-plan)
Restore odelia's single-source invariant **inside plant**, and make adding a gradient
map onto the run workflow:
- **Commitment:** the resident replay grid is produced ONLY by the adaptive run
  (`r_ode_times()` / `solver.times()`); a caller cannot express a replay grid, so cannot
  express a wrong one.
- **A run-shaped gradient entry** (a C++ `SCM` method + an R `run_scm` mode) that owns
  adaptive-record → single-source replay and takes a functional — so no standalone
  driver and no hand-set schedule.
- **Retire** `save_RK45_cache`/`step_history`/`environment_history` off the
  resident/gradient path (deferred mutant L3 only).
It is mostly **reuse + deletion**, not a new abstraction: the correct record→replay
already exists and works (`run_scm(use_ode_times)`).

## CONCRETE NEXT STEPS (in order; the user directs the build)
1. **Prove the diagnosis end-to-end (cheapest, highest-confidence).** In
   `plant/tests/testthat/ff16_scm_gradient_driver.cpp` and `k93_scm_census_driver.cpp`,
   replace the replay grid `scm.get_system_ref().step_history` with `scm.r_ode_times()`
   (== `solver.times()`) in `pin_replay`. Rebuild, run the FF16 R0 driver, and confirm
   `d(R0)/d(lma) ≈ +4.2` (matching the adaptive `run_scm` FD) and that K93 gradients are
   unchanged. This is a ~2-line change per driver and settles the whole saga.
2. **Re-gate the FF16 R0 test against the adaptive FD.** Replace the `expect_failure`
   known-gap assertion in `test-ad-ff16-scm-gradient.R` with a real `expect_equal`
   against the adaptive `run_scm` FD (`+4.2`); retire the pinned-FD-as-truth framing.
   (K93's tests already gate against the correct value.)
3. **Build the run-shaped gradient entry (R2 / DX).** Design + implement the SCM/R
   `run_scm`-mode gradient entry per the committed design; fold the standalone
   `k93_scm_census_driver.cpp` / `ff16_scm_gradient_driver.cpp` into it (they become
   "define a functional"). Cross-package: touches plant, possibly a thin odelia helper.
4. **Retire the legacy replay path (R4).** Remove `save_RK45_cache`/`step_history` from
   the resident/gradient path (keep only for the deferred mutant L3); make the
   mutant-only records unreachable from resident gradients so the bad replay is
   structurally inexpressible.
5. **Resume the phased port.** Then P2b finish (FF16 multivariate census: LAI/biomass/
   basal-area), P2c (TF24 — leaf IFT via `register_implicit` + `incomplete_gamma` + soil
   coupling), P2d (TF24f). See `docs/build-plan.md` Phase 2.

## Key files
- Design/plan: `docs/build-plan.md` (phased plan + the CD-G root-cause/design log),
  `docs/design.md`, `docs/odelia-index.md`, `odelia/AUTODIFF.md`.
- odelia engine: `odelia/inst/include/odelia/{gradient,ode_solver,separable_field,
  implicit_node,incomplete_gamma,mass_transport,decide}.hpp`.
- plant SCM/AD: `plant/inst/include/plant/{scm,patch,node,species}.h`,
  `plant/inst/include/plant/models/{ff16,k93}_{strategy,environment}.h`,
  `plant/inst/include/plant/{canopy_shape,competition_field?}.h` (note:
  `competition_field.h` was a reverted experiment — the field lives inline in the
  environments).
- Gradient drivers/tests (to be folded away): `plant/tests/testthat/{k93_scm_census_driver,
  ff16_scm_gradient_driver}.cpp` + their `test-ad-*.R`; isolation probes
  `ff16_single_rate_probe.cpp`, `ff16_feedback_probe.cpp`, `field_crown_probe.cpp`.
