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

_Last updated: 2026-07-20. This session: **landed FF16 on the transport-log-mass chart** (odelia
`ac6a988`, plant `c1b034ca`, superrepo `90f4908`). FF16 `geometric_transport` marker; the two-species
crash (coincident shaded seedlings → zero cohort spacing → NaN density reconstruction) fixed by odelia's
new **-inf zero-spacing convention** (a degenerate zero-width cohort → density 0, contributes 0). Tried a
competition-in-mass rewrite (system-design'd) but REVERTED it — it degraded K93's AD-vs-FD gradient 0.56%
(freezing spacing into λ vs recomputing it live); the lighter -inf convention keeps K93 exact. Result:
K93 gradient <1e-3 preserved, FF16 `d/d(k_l)` machine-exact, `d/d(lma)` ~0.4%, `d/d(a_l1)` a known
self-shading residual (task #10). Trees clean, installed==HEAD._

## ►► IMMEDIATE NEXT STEP (start here) ◄◄
**Pick up one of:** (a) **FF16 `a_l1` self-shading adjoint residual** (task #10) — `d/d(a_l1)` reverse-AD
0.0629 vs FD plateau 0.1007; both AD modes agree, FD disagrees; predates the chart work (present with
reconstruction competition where K93 was exact) so a distinct mechanism from the (now-reverted) K93
mass-gradient issue — investigate the self-shading feedback adjoint. (b) **FF16 multivariate census
gradient** (LAI/biomass/basal-area, task #5). (c) **run-shaped gradient entry** + retire
`save_RK45_cache`/`step_history` (tasks #3/#4).

**Known limitation carried forward:** the -inf convention handles *exact* zero spacing (coincident
heights). *Tiny-but-nonzero* centred spacing at a near-stall could still overflow an interior neighbour's
reconstructed density; the retrofit if ever observed is the competition-in-mass path (node-lumped
`Σ exp(λ)·kernel`, designed+prototyped this session, reverted for the K93 gradient cost).

## THE HEADLINE (read this first)
The FF16 gradient bug, the #550 density runaway, and the value/gradient tension are **one thing**: the
landed transport scheme carries **log-density ℓ** and computes the compression `C = ∂ₓg`. The fix — which
`design.md §88` ("the representation guarantee") ALREADY specifies and two independent Oracle consults
confirmed — is to transport **log-mass `λ = ℓ + log Δx`** instead: `dλ/dt = −r`, the compression cancels
identically (never computed), `λ` is monotone (no overflow), no numerical `∂ₓ` on the tape (no severance,
correct gradient). One scheme for all strategies. **This is P1e-λ; it is the current work.**

## What is SETTLED (with evidence)
- **FF16 R0 gradient root cause = the dropped density-transport derivative.** `Node::growth_rate_gradient`
  returns a bare `double` on the active pass (the FD-stencil compression's θ-derivative is *severed*); the
  competition field's source weight is density-weighted, so the missing derivative corrupts `d(field)/dθ`
  and every coupled gradient. Routing the transport derivative through odelia's mass chart made reverse AD
  match the adaptive FD (FF16 `d(offspring)/d(lma)` ratio **0.995–0.999**). This is the Oracle's **C1**
  verbatim (`oracle-ad-design-consultation.md`), and R1 (mass chart) is the fix.
- **NOT schedule sensitivity / NOT a replay-grid bug.** Earlier session claims ("r_ode_times fixes it →
  +4.2") were REFUTED by direct measurement (adaptive-FD ground truth = +4.2; frozen replay on the
  *resolved* schedule = +4.2 in double; the driver's r_ode_times replay gave +729). The correct frozen
  replay is the **resolved** schedule (L0 `node_schedule_times` + L1 `ode_times` from
  `run_scm(refine_schedule=TRUE)`) — no schedule sensitivity. That correction is committed in the FF16
  driver/test and the RULES section of PART 1.
- **#550 is the SAME underlying cause, not a similar symptom.** #550 (TF24, extreme-drought density
  runaway; closed by PR #552 which added ONLY the `Patch::check_finite_ode_state` guard, deferring the
  real fix to #551/#517) and the FF16 mass-chart overflow both hit the same guard, the same equation
  (`d(log_density)/dt = −∂ₓg − mortality` spiking → overflow), the same symptom. Reproduced #550 directly
  (`test-strategy-tf24.R` config). Difference is only discretisation+trigger: #550 = model-side steepness
  overwhelming the stable upwind stencil (deferred #551/#517); FF16-on-mass-chart = the centred scheme
  unstable at the `g=0` growth-shutoff where the upwind stencil is stable. **The log-mass chart removes it
  by construction** (`λ` monotone), for FF16; #550's model steepness stays #551/#517.
- **The landed P1e is only HALF the design.** `odelia::log_density_rate` transports `ℓ` and computes `C`
  (realises only the reduction-level cancellation). K93 is stable+gradient-correct on it ONLY because its
  growth is monotone (no stalls) — it is the benign case, **not** "the correct chart" (a correction I made
  this session: K93 uses the incorrect log-density chart, just non-pathologically).
- **Seed decision:** newborn mass seed = **option A** (reproduce birth density `λ₀ = ℓ₀ + log Δx₀`,
  minimal re-baseline). Option B (flux×interval, `m₀ = birth·estab·Δt_insert`, the Oracle's "natural"
  choice) filed as **aornugent/plant#59** for follow-up.

## P1e-λ BUILD STATE — LANDED for K93 (plant `c249689c`, odelia `f9d6ad8`, superrepo `a272a11`)
**The "Δx-consistency crux" was overstated and is now closed.** A double-level diagnostic on a real
141-node K93 patch (`scratchpad/dx_diag.R`) proved the two "different discretisations" are **one operator**:
the node-lumped trapezium weight equals `cohort_spacing` **exactly** on the interior (ratio 1.0000) and
differs only 2× at the two boundary nodes (half-gap vs full-gap → ~1.9% on the field integral); the
density→λ→density round-trip is an **exact identity** (ratio 1.000000). So the earlier ~8× was a *bug in
the reverted WIP*, not an inherent quadrature mismatch — and no quadrature needed relocating into odelia
(the `system-design` pass rejected an `odelia::reduce`/`Quadrature` object on concept-count; the winning
floor was "reductions consume mass `exp(λ)` directly, which the existing trapezium already is on the
interior").

**Chesterton's-fence result (verified; corrects an earlier mis-attribution).** The ~0.025% K93
re-baseline is **NOT** a boundary-spacing effect. `cohort_spacing`'s only live consumers are now the
chart's seed/view; `odelia::log_density_rate` (which used the full-gap boundary as the one-sided `C`
stencil) has no callers on the λ chart. Flipping the boundary full-gap↔half-gap leaves K93 offspring
**bit-identical** (`0.0754715463` either way): the boundary ½ is pure gauge — it cancels between seed
`λ=ℓ+log dx` and view `ℓ=λ−log dx`, and stays cancelled under evolution since `∫C = log(dx(t)/dx(0))`
independent of the ½. The re-baseline is the genuine truncation-error difference between two
discretisations of the same PDE (old: integrate `dℓ/dt=−C−loss`; λ: RK-integrate `dλ/dt=−loss` +
remesh-reproject at introductions) — it **cannot be nulled** without giving up the λ scheme's benefits
(FF16 stability + ungarbled gradient). Full-gap boundary kept as the correct one-sided `C` stencil for a
future old-chart revival.

**What landed:** K93 transports `λ = log_density + log(cohort_spacing)` with `dλ/dt = −mortality` (no
compression ever formed); `log_density`/`density` are a read-side view reconstructed at the top of
`Patch::compute_environment`. odelia gained `log_mass_from_log_density` / `log_density_from_log_mass`
beside `cohort_spacing`. Node gained `log_mass_` + `on_mass_chart()`; `compute_initial_conditions` seeds
`log_mass_=log_density` (lone dx=1 default); `Species::seed_newborn_log_mass` rebuilds λ from the density
view at every introduction (a remesh; exact round-trip for unchanged cells). **Results:** off-chart
strategies (FF16-default, TF24, flag off) **bit-identical**; K93 offspring re-baselined ~0.025% and the
snapshots re-blessed; **R0 gradient exact** (reverse AD vs pinned-schedule FD ratio
1.0000, value==value_double to 1e-10). Full regression sweep: 0 new failures (the 5 remaining — FF16 4,
TF24 1 — are pre-existing WIP staleness + a pandoc error, confirmed on the baseline build).

## CONCRETE NEXT STEPS (in order)
1. **Opt FF16 onto the chart (THE next task).** Add the `geometric_transport` marker to
   `FF16_Strategy` (as on K93) so `strategy_supports_geometric_transport<FF16>` is true; with
   `node_geometric_compression` on, FF16 then transports λ. Confirm (a) the #550-style overflow vanishes
   (`Σexp(λ)` bounded through the `g=0` growth-shutoff where the centred compression stencil was
   unstable), and (b) reverse AD == adaptive FD across the coupling params (the severed
   `growth_rate_gradient` derivative is gone — the whole point). **Watch:** FF16's `set_ode_state`/export
   slot becomes λ, and the newborn-seed remesh runs on FF16's schedule; re-baseline expected. Gate on the
   Oracle predictions (`oracle-response-transport-compression.md` §"Falsifiable predictions"). NOTE the 4
   pre-existing FF16 test failures are stale WIP expectations (offspring 16.889→16.902 etc.) unrelated to
   the chart — re-bless them together with the chart opt-in, don't chase them separately.
2. **Re-bless FF16 demography snapshots** once on the chart (K93 already re-blessed this session).
3. **R export/import/resume/`expand_state`:** the exported density slot is now `λ` for chart strategies
   (`ode_names` still labels it "log_density" — fix or document); reconstruct on import; audit
   `r_log_densities` (it reads the reconstructed view, so it's fine post-`compute_environment`). Re-gate
   the FF16 R0 gradient test against the adaptive FD (flip `expect_failure` → bare `expect_equal`).
4. **Then resume the port:** finish P2b (FF16 multivariate census), P2c (TF24 — shares the coupled
   feedback, so the chart likely matters there too), P2d (TF24f). The run-shaped gradient entry (map onto
   `run_scm`, retire `save_RK45_cache`/`step_history`) is the DX deliverable once gradients are correct.

## KEY DX ARTIFACT this session
`scratchpad/dx_diag.R` — the double-level proof that trapezium ≡ `cohort_spacing` (interior exact,
boundary 2×, round-trip identity). Rerun it if the quadrature question resurfaces; it settles the
"do we need a quadrature primitive in odelia?" question with numbers (answer: no).

## KEY DOCS (read for the full argument)
- `docs/oracle-consultation-transport-compression.md` — the standalone elicitation (domain-clean; the
  compression-term problem stated neutrally).
- `docs/oracle-response-transport-compression.md` — the Oracle's answer (transport log-mass; the identity;
  the 4 falsifiable predictions; the reformulation stated completely).
- `docs/oracle-consultation-index.md` §"Round 3" — C1/R1 confirmed + the value-stability limit = #550.
- `docs/build-plan.md` P1e-λ block — the touch-point map, the ordering constraint (`patch.h`
  reconstruction between state-load `:807` and `compute_environment` `:818`), and the Δx-consistency
  FINDING.
- `docs/design.md §88` — "the representation guarantee" (odelia transports one canonical log-mass chart;
  model expresses in log-density via read-side views; the design this whole session re-derived).

## KEY FILES (plant)
- `inst/include/plant/node.h` — the transported state (`log_density`→`log_mass_` on the chart);
  `compute_rates` (delete `growth_rate_gradient` from the geometric branch → `dλ/dt=−mortality`);
  `set/ode_state`; the density-view reconstruction; the newborn seed.
- `inst/include/plant/species.h` — `compute_rates` (delete the `log_density_rate` compression block);
  **`compute_competition` (the trapezium integral to rebuild on `cohort_spacing`)**; `reconstruct_densities`;
  `seed_newborn_log_mass`; `introduce_new_node`.
- `inst/include/plant/patch.h` — `compute_environment` (reconstruction pass at top, before the field);
  the `set_ode_state`→`compute_environment` ordering; `check_finite_ode_state` (#550 guard).
- odelia: `inst/include/odelia/mass_transport.hpp` (`cohort_spacing`, `log_density_rate` — the latter to
  retire once λ transport lands).
- FF16 gradient driver/test: `tests/testthat/ff16_scm_gradient_driver.cpp` + `test-ad-ff16-scm-gradient.R`
  (resolved-schedule replay; `expect_failure` gate to flip to `expect_equal` when the gradient is correct).
