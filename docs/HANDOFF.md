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
the plant developer experience is pain-free.**

## Standing disciplines (the point of the project, not side-constraints — never drop these)
- **DX is the objective, measured as concept count.** The win is code a plant
  developer can hold in working memory and reason about — *dead-simple boundaries*,
  not clever machinery. An abstraction earns its place ONLY by *reducing* net
  complexity; a named object that merely relocates complexity (a wrapper, a concept,
  a layer with one witness) makes DX **worse**. Too many named objects is itself the
  failure mode. When in doubt, the floor — reuse + deletion — wins; add a name only
  when it removes a *class* of bugs, and only with a second real witness.
- **odelia and plant are co-designed.** DX spans both repos: when a plant pain points
  at a missing/weak odelia primitive, fix it *in odelia* rather than papering over it
  in plant. Both are on the same branch; edit odelia headers → reinstall odelia →
  rebuild plant, kept in lockstep (see context-rebuild step 5).
- **Use the `system-design` and `code-review` skills for anything structural** — not
  once, but as the regular working rhythm: `system-design` *before* introducing any
  abstraction/layer/boundary (it searches for the design that does the least), and
  `code-review` over every non-trivial diff (it reopens each decision and makes the
  diff justify a new name against a removed bug class). The AGENTS style guides apply.

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
  and re-run `run_scm` (adaptive stepping) at ±δ, central difference. Verify it in
  **double, at R level**, before trusting any C++/AD number — this is what refuted two
  successive over-confident root-cause claims this session. Sweep δ for the plateau.
- **The correct frozen replay is the RESOLVED schedule — L0 `node_schedule_times` AND
  L1 `ode_times` from `run_scm(refine_schedule=TRUE)` — i.e. what
  `run_scm(use_ode_times=TRUE)` replays.** On that schedule, frozen FD == adaptive FD
  (no schedule sensitivity). `r_ode_times()` alone is the correct L1 *source* but is
  NOT sufficient: pinning only L1 onto the **default (unrefined) L0** is inconsistent
  and gives a derivative-wrong (though value-correct) trajectory — that was the real
  flaw in the old drivers, not the `step_history` vs `r_ode_times()` choice per se.
  `patch.step_history` (the `save_RK45_cache`/`run_mutant` L3 legacy) is still deferred;
  don't use it for a resident gradient.
- **AD `≠` FD on the IDENTICAL resolved schedule is a real derivative bug, not a
  schedule/replay artifact.** If forward AD == reverse AD yet both `≠` a δ-independent
  FD, the *code* computes a wrong analytic derivative (a dropped `to_passive` term FD
  sees through) — hunt it in the model code, not the replay. (This is FF16's current
  open bug; see PART 2.)
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

_Last updated: 2026-07-19 (FF16 diagnosis corrected: no schedule sensitivity; open
reverse-AD dropped-derivative bug in coupled growth)._

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
  light (double path within tol, all double suites green). Its R0 gradient is **still not
  correct** — the cause is now precisely characterised (below): a genuine reverse-AD
  dropped-derivative bug in FF16's coupled self-shading growth, NOT schedule sensitivity
  and NOT a replay-grid choice.
- **Trees:** clean. Superrepo HEAD `b2a8879` (plant submodule at `7f159f3d`); odelia
  `67793a5`, installed and synced.

## The corrected finding (2026-07-19; supersedes the earlier "r_ode_times fixes it" claim)
Two facts, both measured this session; the PRIOR handoff claim that pinning
`r_ode_times()` yields `+4.2` was **REFUTED** and is retired.

1. **There is NO schedule sensitivity.** Ground truth (adaptive `run_scm` FD) is
   `d(offspring)/d(lma) = +4.2` (life 50, stable plateau). A *frozen* replay on the
   **RESOLVED** schedule — both L0 `node_schedule_times` **and** L1 `ode_times` from
   `run_scm(refine_schedule=TRUE)`, i.e. what `run_scm(use_ode_times=TRUE)` replays —
   also gives `+4.24` **in double** (`scratchpad`/R-level, no AD). So frozen == adaptive
   when the replay uses the resolved schedule. The old drivers were wrong because they
   pinned **only L1** onto the **default (unrefined) L0** — an inconsistent schedule
   giving a value-correct but derivative-wrong trajectory. (`r_ode_times()` alone is the
   correct L1 *source* but is NOT sufficient; you need the resolved L0 too.)
2. **A real reverse-AD dropped-derivative bug remains, schedule-independent.** On the
   IDENTICAL resolved schedule, reverse AD `≠` the finite difference: e.g. metric=2
   (pure growth, sum of heights), life 40, AD `−6299` vs resolved-FD `−1630`; life 25,
   AD `+4902` vs FD `−3424`. Key properties: **δ-independent** (FD flat under a
   3e-2→3e-5 step sweep, so NOT a kink — a genuinely dropped smooth derivative);
   **forward AD == reverse AD** yet both `≠` FD (so it is a structural derivative error
   in the *code*, not a tape/adjoint-accumulation bug); reproduces on **pure growth**
   (so NOT reproduction/census, NOT field-at-0); **`freeze_query` irrelevant** (NOT the
   field's query-height channel). It lives in FF16's coupled **self-shading light →
   growth feedback** (single-plant fixed-light is exact; the bug needs the coupling).
   **Per-cohort localisation** (`ff16_cohort_height_tangents`, forward-mode
   `d(height_i)/d(lma)` vs per-cohort FD): FD is smooth and coherent across cohorts
   (tallest ≈ −8.6 uniformly), but **every** cohort's AD tangent is wrong, worst in the
   understory (|gap| in the shortest 25% ≈ 10875 vs tallest 25% ≈ 273) — even the
   emergent, near-unshaded tallest cohort is off (AD −1.4 vs FD −8.6). So it is a
   **broad, systematic mis-propagation through the shared coupled field**, not a single
   localised term. **Tested and RULED OUT:** birth-height / `prepare_strategy` staleness
   (re-running `prepare_strategy()` in `Patch::reset()` — mirroring IndividualRunner —
   did NOT close the gap; reverted). Still open.
   The code computes an analytically wrong derivative that FD catches by perturbation —
   i.e. a `to_passive`/dropped-term somewhere on the light-feedback → growth path that
   was not found by inspection (checked: field rank boundary = `Q(1)=0` so zero; source
   cumulative weights are active; `initial_height_` is active; crown-integral bound is
   the active focal height; `canopy_top` is only the unused spline cap).
- **Tape memory:** reverse AD fits to ~life 40; **life 50 crashes** (out of memory on
  the finer schedule). Full-lifetime needs checkpointing at the node-introduction
  boundary (vendored `XAD::CheckpointCallback`, deferred).
- **K93 unaffected** — smooth closed-form rates, no coupled-growth branch; all three
  (AD / resolved-FD / adaptive-FD) agree, all gates green.

## The design (system-design skill; Tier 2; floor wins — committed in build-plan)
Still valid and orthogonal to the adjoint bug above (the bug is in FF16's rate/field
code, not the driver plumbing): make adding a gradient map onto the run workflow —
a run-shaped gradient entry (C++ `SCM` method + R `run_scm` mode) that owns
adaptive-**refine**-record → resolved-schedule replay and takes a functional, so a
caller can neither hand in a schedule nor pick the wrong (default-L0) one. Mostly
reuse + deletion: `run_scm(refine_schedule + use_ode_times)` already does the correct
record→replay. Retire `save_RK45_cache`/`step_history` off the resident path (mutant L3
only). NOTE: this entry would have structurally prevented the whole default-L0 saga.

## CONCRETE NEXT STEPS (in order; the user directs the build)
1. **Find + fix the FF16 reverse-AD dropped-derivative bug (THE blocker for a correct
   FF16 gradient).** δ-independent, fwd==rev, pure-growth, coupling-only,
   `freeze_query`-irrelevant, and per-cohort **broad + understory-worst** (see the
   corrected finding). RULED OUT: schedule, replay grid, query channel, static field
   read, birth-height/`prepare_strategy` staleness. Best remaining leads, in order:
   (a) **Verify the active replay actually recomputes the field each step** — does
   `advance_fixed` drive `Patch::set_ode_state(it, time)` (the recompute overload,
   `has_recorded_field()==false`) at every step/stage, or is the field computed once at
   `reset()` and reused with a stale derivative? A field whose VALUE updates but whose
   DERIVATIVE is severed after step 0 would give exactly this broad, understory-worst
   pattern with an exact value. Instrument `d(A(z))/d(lma)` (forward tangent) at a fixed
   height across steps. (b) **`ff16_cohort_height_tangents`** already localises per
   cohort; extend it to dump the tangent of the light each cohort reads mid-run to find
   the step where the tangent dies. (c) Un-freeze `ff16_feedback_probe` on a coupled
   2–3-cohort state (it froze the field, so it missed this). The `freeze_field` knob
   confirms the feedback channel is large and wrongly computed.
2. **Build the run-shaped gradient entry (R2 / DX, committed design).** SCM method + R
   `run_scm` mode owning refine→resolved-replay + a functional; fold the standalone
   `k93_scm_census_driver.cpp` / `ff16_scm_gradient_driver.cpp` into it. Orthogonal to
   step 1 but prevents the default-L0 class of bug structurally.
3. **Re-gate the FF16 R0 test** (currently `expect_failure` on AD≠FD at life 40, value
   exact): once step 1 lands, flip to a real `expect_equal` against the resolved-schedule
   FD (== adaptive). Also route the K93 driver through the resolved schedule for symmetry
   (K93 already correct, but should not depend on the default-L0 path).
4. **Retire the legacy replay path (R4).** `save_RK45_cache`/`step_history` off the
   resident/gradient path (mutant L3 only).
5. **Then P2b finish** (FF16 multivariate census LAI/biomass/basal-area), **P2c** (TF24),
   **P2d** (TF24f). NOTE: TF24 (P2c) shares FF16's coupled-feedback structure, so the
   step-1 fix likely matters there too.

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
