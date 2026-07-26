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

# PART 2 — CURRENT STATE + NEXT STEPS (rewritten session 20, 2026-07-26)

## READ THIS FIRST: the rule that cost session 19
**Never give a deduced return type to a function or lambda that returns an AD
value.** XAD operators return *expression templates* holding references to their
operands, so a deduced return type hands the caller references to temporaries and
by-value parameters destroyed on return; the caller materialises a dangling
expression, records reused stack bytes as a tape operand slot, and the reverse sweep
segfaults arbitrarily far from the cause. **valgrind cannot see it** — the storage is
stack, not heap.

    // BAD  -- returns a dangling expression template
    auto anchor = [](double v, S x) { return S(v) + (x - to_passive(x)); };
    // GOOD -- materialised while its operands are alive
    auto anchor = [](double v, const S& x) -> S { return graft_value<S>(v, x); };

Session 20 found a second live instance (`ff16_strategy.h:823`, FF16's birth-height
residual), so the `static_assert` on `implicit_value`'s residual has now earned itself
twice. **If you meet a garbage tape slot, suspect a dangling AD expression before
suspecting XAD.** Defences: `odelia::util::graft_value`, that `static_assert`,
`AGENTS.md` → "Never (code)", and `pstar_ode_reprex(graft=2)` reproducing it on demand.

**Corollary worth its own line:** that bug was invisible because
`skip_if_not(built, ...)` turns a **sourceCpp build failure into a skip**, so
`test-scm-gradient-entry.R` had silently stopped running 11 FD-verified assertions.
When a gradient test "passes", check it did not skip.

## The three documents that carry the current plan
1. **[`v3-reverse-memory-design.md`](./v3-reverse-memory-design.md)** — the memory
   profile (§1), the design search (§2–5), and the four follow-ups: preaccumulation as
   a primitive (§6b), the frozen-L2 idea checked and set aside (§6c), and **the FF16
   crown boundary decision (§6d)**.
2. **[`v3-step-local-adjoint.md`](./v3-step-local-adjoint.md)** — the deferred engine
   change, at implementation detail, with its trigger.
3. **[`v3-phase1-plan.md`](./v3-phase1-plan.md)** — Steps 3 and 4 of the TF24 wiring.

## Where we are
- **TF24 reverse gradient works.** Gate-0 FD-matches on all 7 channels; soil (3),
  light (6), tf24f collar-uptake (11) pass; the active run reproduces the double
  trajectory; the double path is bit-identical (`test-leaf` 214, tf24 46, tf24f 57).
- **The memory diagnosis was wrong and is now corrected.** It is a genuine kernel OOM,
  but **FF16 OOMs the same way at its own production lifetime** — never had a seam, has
  no leaf solve. Tape ∝ steps × cohorts for every strategy; K93 completes at
  `life=105.32` in 0.75 GB. Per cohort-step: K93 2.15 KB → FF16 42.5 KB (**the crown
  quadrature**) → TF24 79.7 KB (the leaf, only 1.9× more).
- **Two levers landed.** `incomplete_gamma` injects its partials instead of recording
  its series (TF24 4.445 → 3.236 GB at `life=1`, value and gradient unchanged);
  `odelia::preaccumulate` is built and toy-proven (1 127 → 7 recorded ops at 21 nodes,
  flat in node count, **gradient bit-identical** to the full tape, FD 5e-9).
- **Known open:** the tf24f collar 2.9e-4 residual (#32), the SCM FD gate (#27), and
  TF24 at `life=4` still OOMs.

---

# SIGNPOSTS — what to do next, in order

### ▶ 1. NOW: FF16 crown preaccumulation, **boundary A** — task #36
The largest lever available, and self-contained. Read
`v3-reverse-memory-design.md` §6d first. Read the 21 light values on the run tape,
preaccumulate the rest (inputs ≈ 48 against ~588 internals). Expect **~2.5× on FF16**:
9.02 GB at `life=40` → ~3.6 GB, and `life=105` **OOM → ~6 GB, which closes the FF16
memory line**.
- **Check the precondition first:** A assumes the crown reads through
  `get_value_at_height_frozen_query`, so `L_j` depends on knot *values*, not actively
  on `z_j`. Confirm for FF16's crown. If the query is active, `L_j` becomes a per-node
  input — the approach still holds, n just grows.
- **The bar is bit-identical, not within-tolerance.** Preaccumulation only moves bytes;
  a moved gradient is a bug. Verify with `test-ad-ff16-scm-gradient.R` +
  `test-scm-gradient-entry.R` (both FD-gated, both green — and confirm they *ran*),
  FF16 bit-identity, and `PLANT_TAPE_STATS=1` at life 4/10/40/105.32.

### ⏸ 2. DECISION POINT (needs the owner): boundary B
B reaches ~12× but requires **Environment to expose its active field values** as an
`ad_field_values()`-shaped contract member — new vocabulary on a shared interface,
coupling strategy code to how the environment stores its field. That is an R3 design
decision, so **run `system-design` and ask; do not slip it in.** Only needed for margin
and for TF24 — and §0 of `v3-step-local-adjoint.md` says leanness falls short for TF24
at production lifetime regardless.

### ▶ 3. THEN: the two remaining leanness levers — task #31
Both pure wins (less forward work as well as fewer bytes), both self-contained:
**(a)** make the interior p\* stationarity residual analytic instead of a central
difference of the full assembly — **2.7× on TF24's leaf**, no new vocabulary;
**(b)** expression fusion — `ops/stmt` is **1.40–1.63**, so named intermediate actives
are defeating XAD's expression templates and statements + derivatives are **40% of the
tape**. Worth ~1.3× everywhere, and it is a style rule that stops the regression
recurring.

### ▶ 4. THEN: Phase-1 correctness and deletions — tasks #32, #33, #34
**#32** the tf24f collar 2.9e-4 residual at ψ=2.5, **δ-independent from 1e-7 to 1e-3**,
so a real missing term — do **not** loosen the tolerance; the plan gives the
per-channel diagnostic and three ranked hypotheses, clamping first. **#33/#34** are
pure deletion (the proven-dead `seam_collar_*` hooks, `supplied_derivative.hpp`, 8
stale comments, residual accretion).

### ▶ 5. THE CLOSING GATE — task #27
FD-verify the full TF24/TF24f SCM gradient; the explicit `skip()` at
`test-ad-tf24-scm-gradient.R:85`. **Blocked until memory allows `life≥4`** (signposts 1
and 3). Read `oracle/oracle-response-inner-argmax-adjoint.md` **before** designing the
FD: tight-τ frozen-schedule reference, never a loose-τ swept plateau.

### ⏸ 6. DEFERRED, with a numeric trigger — task #35
The step-local adjoint (`v3-step-local-adjoint.md`). **Trigger: TF24 wanted at
`max_patch_lifetime` ≳ 40**, because leanness tops out at ~7.3× against the 15–45×
production needs. It makes peak memory independent of lifetime and **removes the
growing tape** rather than managing it. Its largest hidden cost: `least_squares` reads
`get_history_step`, so it does **not** survive unchanged — convert it as part of that
work, not after.

### ⚑ 7. Owner is taking this: odelia's 10 loader errors
`test-ad-{functional,jacobian,record-replay,tape-cache}.R` and `test-rodas.R` error out
(10 total) from a loader problem, not from session 20's changes — but my baseline check
was imperfect (stashing source does not revert installed headers), so treat
"pre-existing" as probable, not proven. Given signpost 0's corollary, these deserve a
look: same class of silence.

---

# PART 2 (ARCHIVE) — state as of session 17, 2026-07-24

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

## (SUPERSEDED — this was session 18's next task; Steps 1-2 are now done. Kept for the rationale only.) Wire TF24 onto the primitives
Session 18 revised the wiring plan after three investigations (code review, git
archaeology, the `leaf_output` design decision). **The executable sequence is now
[`v3-phase1-plan.md`](./v3-phase1-plan.md)** — read it, not the old 6-step list that
used to live here. What changed:

- **It is mostly DELETION, not addition.** Most primitives already landed:
  `assemble_leaf_from` (`tf24_strategy.cpp` 726+) is a run-tape-ready S assembler using
  `implicit_value` nodes; the `leaf_output` closed forms exist; census/soil/TF24f
  wiring is in. What's left is stripping the hand-adjoint seam + one duplication. Git
  archaeology found **no hidden-clean commit** to revert to (the assembler and the seam
  were born together in plant `1ebdebad`); forward deletion from HEAD beats a rewrite.
- **Revised sequence:** (1) delete the seam (local tape 555–715, `supplied_derivative`,
  `chain_sign`, snapshot, `PLANT_TAPE_STATS`), call `assemble_leaf_from` directly;
  (2) make `Leaf`'s output methods scalar-generic closed-form templates, **absorbing
  the `leaf_output` namespace** and collapsing the double/S formula duplication (the
  §-design decision, v3 §4.4a: no separate namespace — the leaf science lives once, in
  `Leaf`; splines kept only if `profile-plant` demands, behind the same method);
  (3) fold the TF24f tracked collar into `assemble_leaf_from` (retires `seam_collar_*` +
  the tf24f `psi_fd_step`); (4) delete residual accretion + FD-verify at SCM scale (#27).
- **Success (grep-able):** 0 seam tokens in `tf24_strategy.cpp`; 0 `namespace
  leaf_output`; 0 non-template `double Leaf::` output copies; `supplied_derivative.hpp`
  deleted from odelia (the seam was its only caller).
- **The DX bar** is vendored at `docs/reference/tf24-base-develop/` (pristine develop
  TF24) — minimal divergence from it is the objective (current drift +796; ~300 deletable).
- **Already toy-proven** (plant Gate-0s are confirmation, not discovery): the
  resistance-network `soil_uptake` incl. seeded `root_b/root_c`, the `E_column`
  bound-continuity residual, and the value-graft guard — `weibull_leaf` demos (E)/(F)/(G).

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
