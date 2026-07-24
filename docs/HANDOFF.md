# Handoff — odelia AD engine × plant SCM gradients

> **►► NEW ENTRY POINT (2026-07-23): read [`v3-north-star.md`](./v3-north-star.md) FIRST.**
> It is the guiding light — objective (DX=concept-count + coverage), the durable
> principles that survived all 16 sessions, the leaf decomposition that restores R1
> for TF24 (the seam is an accidental shortcut, not the design), and the ladder to
> completion. Then this handoff (Part 1 rules), then `design.md`. ~14 docs were
> archived to `archive/` in the v3 reorg; the canonical set is listed in
> `v3-north-star.md` §7.

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
**Docs are a lead, not an authority — verify before you build on them.** Every prose claim of status
("done", "won't compile", "wrong by X", "UNBUILT") is potentially stale: it was true when written and
the code has moved. Before acting on such a claim, reproduce it against the *current* code with the
cheapest decisive check (a compile probe, a single test run, a one-value FD). Session 16 found TWO stale
session-15 claims this way ("won't compile at node.h:347"; "the census methods are missing everywhere")
that were false against HEAD. The build-status matrix (`build-plan.md`) exists precisely so a claim is a
*test citation you can re-run*, not a sentence you trust — re-run the cell before you believe it.
1. **Read `odelia/AUTODIFF.md` FIRST.** It is the authoritative account of the AD
   workflow: the two orthogonal axes (Replay L1/L2/L3 × Functional), ownership (the
   **Solver owns the schedule L1**; the System owns its background L2/L3), the System
   contract, and **the one way to get it wrong** (populating the L3 field-value cache
   silently drops a background's feedback derivative). Internalize the invariant:
   **`recorded_steps()` is the SINGLE source of the replay grid, so it "can't go
   inconsistent," guarded by one forgot-to-record check.**
2. **Read `odelia/AGENTS.md` and `plant/agents.md`** (dev workflow, style, build/test).
3. **Read `docs/v3-north-star.md` FIRST** (the self-contained authority on the
   coupled system + design), then `docs/design.md` (detailed rationale) and the
   `docs/build-plan.md` build-status matrix (test-cited current status). (odelia-index.md, README.md, the odelia-N notes, and the oracle *statements* are archived; the concept set now lives in v3 §1.)
3b. **If the task touches an area with a prior Oracle consultation, READ that Oracle
   response BEFORE designing your approach — and follow its Decisive Experiments and
   contract, not an ad-hoc method.** Index: `docs/oracle/oracle-consultation-index.md`. The
   responses are `docs/oracle/oracle-response-*.md`. In particular, anything touching the TF24
   leaf `p*` adjoint or FD-verifying a TF24 gradient is governed by
   `docs/oracle/oracle-response-inner-argmax-adjoint.md` (the staircase; the δ/τ-indexed FD family;
   the tight-τ frozen anchor). Session 16 re-derived that response's findings the hard
   way *after* falling into the exact trap it documents (chasing a loose/under-stepped
   FD ratio) — because the response was not consulted at task start. Consulting it is not
   optional when its subject is in scope.
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
- **Treat docs as potentially stale; verify before building on a status claim.** (See the
  principle under "HOW TO REBUILD CONTEXT".) A "done / broken / wrong-by-X" sentence is a
  lead to reproduce, not a fact to inherit — the code has moved since it was written.
- **Consult the relevant Oracle response BEFORE choosing a verification/debugging method —
  and DO NOT trust an FD ratio until you have verified the FD reference itself.** This is the
  trap session 16 fell into (and session 12 before it): a TF24-SCM/leaf-adjoint FD is a
  **δ/τ-indexed family, not one number** (`docs/oracle/oracle-response-inner-argmax-adjoint.md`). A
  central FD is meaningless unless the step is in the valid window — **δ ~ τ^{1/3}, above the
  staircase/roundoff noise floor AND below the step that drives the SCM non-finite (#550)**.
  Too small (e.g. `d_rel=1e-5`) → pure noise (session 16's retracted "12×"); too large
  (`d_rel≳5e-2`) → non-finite. The correctness anchor is **AD vs FD on a frozen schedule at
  TIGHT inner tolerance (`GSS_tol_abs`), fixed δ in the window, to integrator tolerance**
  (the Oracle's Decisive Experiment 2) — NOT a loose-τ / small-δ swept plateau, which is the
  staircase artifact the Oracle says explicitly *not* to chase. Verify the reference, then
  the ratio.
- **The correctness reference is the fully-adaptive real-model FD** — perturb a trait
  and re-run `run_scm` (adaptive stepping) at ±δ, central difference. Verify it in
  **double, at R level**, before trusting any C++/AD number — this is what refuted two
  successive over-confident root-cause claims this session. Sweep δ for the plateau
  (in the valid window per the rule above — a "clean plateau" at tiny δ can be the artifact).
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



---

# PART 2 — CURRENT STATE + NEXT STEPS (rewritten session 17, 2026-07-24)

Per-session history for sessions 1–16 is in
[`archive/handoff-part2-sessions-1-16.md`](./archive/handoff-part2-sessions-1-16.md).
The design authority is [`v3-north-star.md`](./v3-north-star.md); the test-cited
status matrix is [`build-plan.md`](./build-plan.md). This section is the live state.

## Where we are: the whole TF24 primitive stack is proven STANDALONE (off the SCM)
Sessions 16–17 de-risked v3 by proving every hard piece on plant-free odelia
examples with FD-checked CI tests — so the plant wiring below is now the *first*
place any remaining unknown can appear. Do not re-litigate these; they are settled
and have durable witnesses:

- **`implicit_value` is the single IFT primitive** (odelia `implicit_node.hpp`).
  `register_implicit` was **deleted** (zero production callers); its `sign(∂F/∂y)`
  guard was ported onto `implicit_value` as the optional `expect` (`denom_sign::
  positive|negative|any`). Use `implicit_value` for every TF24 leaf node.
- **`weibull_leaf`** (odelia `inst/examples/weibull_leaf_interface.cpp`,
  `test-example-weibull-leaf.R`, 39 assertions) — the TF24 leaf miniature. Witnesses
  the **interior** `p*` optimum + envelope asymmetry, the **bound/fold** regime
  (branch-death `implicit_value`, `dW/dp≠0` so profit carries `dp*`), the **full
  3-deep nest** `p→ψ_stem→ci` (ψ_stem an inversion node), and the **tape-memory
  bound** (`weibull_leaf_tape_profile`: the solve-off-tape node path is ~1.6k ops
  per solve, *exactly independent* of solver iterations; a naive on-tape solve is
  ~26× larger and returns a wrong zero gradient — this is the OOM proof).
- **`soil_leaf`** (odelia `inst/examples/soil_leaf_interface.cpp`,
  `test-ad-soil-leaf.R`, 9 assertions) — the soil feedback witness. A per-layer
  soil-water ODE whose `ψ_soil(θ)` drives the leaf's `incomplete_gamma` uptake, which
  is the soil sink (the closed loop), integrated through the odelia Solver, with a
  `ci` `implicit_value` node **inside `ode_rates`** and a consumer introduced mid-run
  (the growing tape). Reverse `d(biomass)/d(kmax,c)` FD-matches to <1e-9; tape stays
  a few MB. The soil sub-cycle adjoint, node-in-rates, and resize path are correct
  *together*.

**Consequence: the design has no remaining unproven concept.** What is NOT yet
witnessed is only the *simultaneous* composition at full SCM scale (light field +
density transport + census + soil, over many cohort-steps on TF24) — that is an
integration checkpoint the plant wiring itself exercises, not a design gap.

## THE NEXT TASK: wire TF24 onto the primitives (v3 §9 Phase 1) — prescriptive
Goal: delete the TF24 hand-adjoint seam and make `tf24_strategy.cpp` call the same
primitives FF16/K93 use. **Success = `tf24_strategy.cpp` has 0 `xad::`/`tape`/
`supplied_derivative`/`chain_sign`/`snapshot` tokens (FF16/K93 have 0 today; TF24 has
32 tape + 10 supplied_deriv + 3 chain_sign + 3 snapshot).** Do the steps in order;
each is small and independently checkable at Gate-0 before moving on.

1. **Widen `leaf_output::soil_uptake` to `S root_b/root_c`** (`plant/inst/include/
   plant/leaf_model.h` ~line 193 — currently `double root_b/root_c`). The body and
   `cumulative_vuln<S>`/`transpiration<S>` are already S-templated; this signature is
   the *only* structural severance of the hydraulic channel (v3 §4.4). Then pass the
   active `p.root_b/p.root_c` in `assemble_leaf_from` (`tf24_strategy.cpp` ~810).
   Gate-0 check: `d(E_up)/d(root_c)` becomes nonzero and FD-matches (was structurally 0).
2. **N_ci** and **N_ψstem** as `implicit_value` nodes (v3 §4.1/§4.2), replacing the
   `psi_stem_to_ci` / `psi_from_transpiration` double reads on the active path. Both
   have sign-definite denominators — pass `denom_sign::positive` to the guard. Proven
   shape: `weibull_leaf`'s ci + stem nodes.
3. **N_p\*** on `implicit_value` (v3 §4.3): interior = stationarity residual (nested-FD
   denominator, proven adequate); bound = the regime-detected branch-death residual
   (regular denominator). Reuse `G(q)` for TF24f. Proven shape: `weibull_leaf`'s
   `pstar_node` (interior) + `pcrit_node` (bound).
4. **Per-layer uptake `E_i`** as the `incomplete_gamma` antiderivative-difference with
   Leibniz endpoint partials + layer-crossing breakpoints (v3 §5). Proven shape:
   `soil_leaf`'s per-layer uptake + `weibull_leaf_soil_demo`.
5. **Declare `using geometric_transport`** for TF24 (v3 §3.2) — one marker, like
   FF16/K93, or the census gradient silently drops the density-transport channel.
6. **DELETE the seam**: the local tape block (`tf24_strategy.cpp` ~615–676), the
   `supplied_derivative` marshalling (~700–710), `chain_sign`, the whole-leaf
   `snapshot`, `soil_consumption_active_`, the nested-FD `p*`, the
   `dsoil_consumption_dpsi_collar_perlayer` FD partials, and the `#include
   <odelia/supplied_derivative.hpp>` + `<chrono>` at the top. Keep
   `dprofit_droot_collar_psi` only if it stays useful as a double value-path/regime
   helper. Confirm the token count hits 0.

## Verification bar for the wiring (do not skip — this is where sessions burned)
- **Gate-0 first, not census FD.** Verify each new node at a single leaf/cohort with a
  clean δ-swept FD (the `weibull_leaf`/`soil_leaf` cert pattern), BEFORE the full SCM.
- **The TF24 SCM-metric FD is a δ/τ-indexed family, not one number** (Part 1 rules +
  `oracle/oracle-response-inner-argmax-adjoint.md`). The correctness anchor is AD vs FD
  on a **frozen resolved schedule at tight inner tolerance**, δ in the valid window —
  NOT a loose-τ swept plateau. Task #27 (FD-verify the full TF24 SCM gradient) is the
  closing gate and needs exactly this reference. Do NOT chase a loose-FD ratio.
- **Memory:** the per-leaf tape is proven bounded; after decomposition, take the one
  confirming measurement v3 §9 names — `incomplete_gamma` series × soil layers ×
  cohort-steps — via `PLANT_TAPE_STATS=1` (the hook is live in `scm_gradient.h` ~119,
  printing `mem_bytes/ops/stmts`). Compare the curve to FF16's.

## Build tax (repeated from Part 1 because it bites every session)
- Edit plant headers → `rm -f plant/src/*.o plant/src/*.so && R CMD INSTALL plant
  --no-multiarch --no-docs` (~3 min). Edit odelia headers → `R CMD INSTALL
  /home/user/plant-dev/odelia --no-multiarch --no-docs` first, THEN rebuild plant.
- Run `R CMD INSTALL` with an **absolute** package path (a stray `cd` leaves the shell
  in the package dir and "invalid package" results). `rm -rf /usr/local/lib/R/
  site-library/00LOCK-*` before installing if a prior install was interrupted.
- odelia example certs are `sourceCpp` files that link the installed `odelia.so`; they
  recompile in seconds with no plant rebuild. After editing an installed example, the
  tests load the **installed** copy — reinstall odelia to refresh it.
