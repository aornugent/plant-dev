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
- **RUN ODELIA'S SUITE WITH `cd odelia && make test`. Nothing else is a gate.** Sessions 20
  and 21 both reported large numbers of odelia "loader errors" (10, then 30). **Both were
  invocation artifacts and odelia is green: `make test` gives 0 fail / 467 pass / 3 skip.**
  The two traps, and they fail in opposite directions:
  - `testthat::test_dir()` **does not attach the package**, so every exported object reads as
    missing (`object 'LorenzSystem' not found`, `could not find function Canopy_new`). Looks
    like 30 broken tests; means nothing.
  - `testthat::test_local()` / `pkgload::load_all()` **silently skips the entire AD
    workflow** — the tests self-skip with "native-pointer lifecycle unstable under
    load_all", by design, because `AGENTS.md` requires odelia be loaded with `library()`
    from a real install (plant resolves odelia's compiled XAD `Tape` symbols in `.onLoad`).
    Looks green at 312 pass; the AD engine was never exercised.
  So a red count from `test_dir` and a green one from `test_local` are both meaningless.
  `AGENTS.md` → *Local Development* says this; read it before quoting any odelia count.
- **`testthat` also caps failures at 10 and prints the cap as if it were the total** — use
  `testthat::set_max_fails(Inf)` before quoting any count. And baseline by *rebuilding* the
  stashed tree, not by stashing source alone (installed headers do not revert).
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

## Before reading the corpus: [`v3-evidence-triage.md`](./v3-evidence-triage.md)
24 design docs, deepenings and Oracle consults exist and they are **not clean signal** —
some were superseded by refutations, some were always estimate dressed as measurement. That
document is the triage rule (**for every number, ask what would change it**), three worked
examples from session 21 where the casual version of "verify first" passed a wrong claim, and
a **marked reading list for the L2 question**. Read it before the archive.

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
- **Crown preaccumulation was measured and retired (§6e).** The estimate said 2.7× and
  "closes FF16"; the measurement says **1.49×** (66% of the crown tape is the light-field
  read, which that boundary leaves behind) and FF16 stays OOM at `life=105`. The best
  boundary measures **3.7×**. Consequence: **C's ceiling is ~3× (FF16) / ~5× (TF24)**, so
  leanness alone reaches production lifetime for neither strategy.
- **Known open:** the tf24f collar 2.9e-4 residual (#32), the SCM FD gate (#27), and
  TF24 at `life=4` still OOMs — now with no leanness route that closes it.

---

# SIGNPOSTS — what to do next, in order

### ✗ 1. RETIRED BY MEASUREMENT — FF16 crown preaccumulation (task #36)
**Do not build this. It was measured and it does not pay.** Session 21 ran the
precondition check this signpost asked for, and it refuted both of §6d's numbers. Read
**`v3-reverse-memory-design.md` §6e** — the probe is committed at
`docs/reference/crown-preaccum-probe.{cpp,R}` and re-runs in seconds.
- **The precondition is false.** With the competition field assembled — the production
  rate path — FF16's crown does **not** read `get_value_at_height_frozen_query`; it reads
  `step_light(exp(-field_optical_depth(z)))`, which passes the **active** query height
  into `shading_query_factors`. Harmless to correctness, but it is why the read is
  expensive.
- **The field read is 66% of the crown tape, not 29%.** So boundary A is capped at
  **1.49×** (not 2.7×), which leaves FF16 OOM at `life=105`. Boundary D — field read
  inside the block, the 63 cumulative source weights declared — measures **3.7×** (not
  12×), and 67 partials for a scalar output is that shape's information floor.
- **The bar was wrong too:** both boundaries reassociate, so `d_h` (A) and `d_eta` (D)
  move at 1.6e-14 / 2.1e-15 while every other channel stays bit-identical.
  **Ask for round-off across all channels, not bit-identity.**
- **The real reason not to land it:** `preaccumulate`'s "an omitted channel is
  unreachable" guarantee **does not hold here**. FF16's integrand is a member lambda, so
  `pars.a_p1`, `pars.a_p2` and `canopy_shape.eta_` are reachable through `this` whether
  declared or not. 1.49× does not buy a call site whose input list is hand-enumerated.

### ⏸ 2. THE DECISION THIS OPENS (needs the owner)
§6e's arithmetic reprices **C as a whole**: with 3.7× rather than 12× from the crown,
C's ceiling is **~3× for FF16 and ~5× for TF24**, so **leanness alone reaches production
lifetime for neither strategy.** The choice is therefore no longer "A now, B later" but:
- **take the step-local adjoint (signpost 6) as the route**, whose trigger has widened to
  include FF16 — it is now FF16's only path to `life = 105.32`; or
- **take boundary D anyway** for its 3.7×, accepting the `ad_field_values()`-shaped
  contract member (an R3 `system-design` decision — do not slip it in) plus the
  hand-enumerated trait list.
Signpost 3's two levers are unaffected and pay either way.

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
`test-ad-tf24-scm-gradient.R:85`. **Blocked until memory allows `life≥4`** — via signpost 3, or
signpost 6; **not** signpost 1, which §6e retired. Read `oracle/oracle-response-inner-argmax-adjoint.md` **before** designing the
FD: tight-τ frozen-schedule reference, never a loose-τ swept plateau.

### ▶ 6. IN PROGRESS — task #35, the step-local adjoint
**Step (1) of three is DONE and pushed** (session 21): the replay hook is now indexed,
`replay_step(k)`, so a backward pass is expressible and neither System infers its
position. **Step (2) was settled and then RETRACTED and re-settled — read §3c and §3d, not §3b.**
§3b chose the event segment as the unit on a measured 1.10–1.34 ODE steps per segment. That
ratio is a property of **one schedule choice, and it is known to be a poor one**: the
multirate work found TF24's transient rainfall dynamics take very many global RK steps on
the default schedule, and that a *less dense uniform* grid refined at cohort introductions
does better. Under that schedule a segment holds many steps and §3b's margin evaporates.

**The design that replaces it (§3c/§3d):** L0 (cohort introductions) becomes the **fourth
recorded layer**, beside the schedule (L1), node positions (L2) and field values (L3). One
new indexed hook, `replay_structure(k)`, joins `replay_step(k)`; a unit is "apply the
structural change recorded at `t_k`, then integrate one ODE step". Load-bearing measured
fact: **every introduction time already lies on the resolved ODE grid** (93/93 and 108/108
for FF16 at life 10 and 40), so L0 marks *which L1 steps carry a change* rather than being a
second timeline. Peak tape is one ODE step whatever `refine_schedule` does, so no scheduling
policy is encoded — a coarse uniform grid, clustered introductions, a multirate stepper and
multiple species all need no contract change. `unit_count()` and the segment concept are
deleted; `run()` is still derived from the loop.

**Two method corrections worth keeping.** (a) **plant is the anchor; the toys lead odelia's
design.** §3a used `soil_leaf::Runner`'s three hardcoded segments as "the witness" fixing the
contract — that inverts it. `soil_leaf` and `growing_resize` both mirror plant's *hand-rolled*
interleave, so under §3d both should be **re-expressed to replay their introductions through
the hook**, giving it two cheap witnesses before plant is touched. (b) L0 and L1 are **replay,
not AD** — resolved by `refine_schedule`, then frozen.

**Step (3), in order:** re-express the two toys onto `replay_structure(k)`; price the
unconditional post-hook state re-sync on a System that never grows; then plant's
`run_next_impl` interleave becomes a recording plus the shared loop; **verify the existing
gradient is bit-identical from the loop re-expression alone, before any adjoint driver
exists**; then the driver. Five open checks are listed at the end of §3d — `refine_schedule`
staying the sole decider of L0, the `complete()`/resume branch, `run_mutant`'s
`environment_history`, multi-species lists, and the re-sync price.

### ✓ 7. RESOLVED, not owed: odelia is green
Sessions 20 and 21 both mis-reported odelia's suite as broken (10, then 30 "loader errors").
**`cd odelia && make test` → 0 fail / 467 pass / 3 skip**, AD workflow included. See the
Part 1 rule above for the two invocation traps that produced the false counts. One real fix
came out of it: the `here` package was genuinely missing and every example test's path
resolution needs it — installed. It was not the cause.

### ▶ 8. Also live: plant's `test-mutant` 8 failures are pre-existing drift
Measured identical (same numeric values, e.g. 0.09177 vs an expected 0.09125) against a
fully rebuilt baseline. Not caused by session 21. They are seed-rain expectations that
predate this branch's model changes; nobody has re-blessed them. Note the **full plant
suite OOMs the box**, so it cannot be used as a gate — verify against the focused set
session 21 used (`test-mutant`, `test-control`, `test-ad-k93-scm-gradient`,
`test-scm-gradient-entry`, `test-scm-support`, `test-initial-state`, `test-ode-euler`).

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
