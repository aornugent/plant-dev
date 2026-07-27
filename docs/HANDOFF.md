# Handoff — odelia AD engine × plant SCM gradients

> **►► ENTRY POINT: [`README.md`](./README.md).** It gives the reading order — Part 1 of this file,
> then `v3-facts.md` (measured numbers with their re-run commands), then `v3-dead-ends.md` (refuted
> claims), then `v3-engine-design.md`. It also states where new writing goes: **append to the
> ledgers; open a new document only for a new decision.**
>
> **►► BEFORE YOU WRITE OR EDIT ANY DOC: [`DOC-DISCIPLINE.md`](./DOC-DISCIPLINE.md) — MUST be
> followed.** Handoff and compaction rules. One to-do list (`OPEN`, below); every status claim
> carries the command that reproduces it; a citation is code, so if you change the code you run the
> citation; refutations move to `v3-dead-ends.md` and are never inlined. It also gives the
> **compaction protocol** — on resuming, execute the runbook and prove what landed before writing
> more prose. Enforced by `./docs/check-docs.sh`, which every session runs before it ends.

This document holds two things: an **authoritative header** (Part 1 — how to rebuild
context correctly, and the hard-won rules that must not be relearned), and the
**current state with next steps**. The measured numbers and the refuted claims now
live in their own ledgers, per `README.md`, because they have different lifetimes
from this narrative.

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
  rebuild plant, kept in lockstep (the runbook's step 0 checks it).
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

## REBUILD CONTEXT: a runbook. Run each step; each has an expected result.

**Do not read prose to rebuild context — execute this.** Every prose claim of status is a lead to
reproduce, not a fact to inherit: sessions 15, 16, 19, 20, 21 and 22 each lost time to a stale
sentence, and two of them reported *proven* failure counts that were invocation artefacts. Steps 0-3
take about ten minutes, most of it waiting for a suite.

**Every command below was executed verbatim when this runbook was written, and produced the stated
result.** If one does not, that is the finding — fix the runbook, and say so.

### Step 0 — verify the workspace. Do this before reading anything.

```bash
cd /home/user/plant-dev
for r in . plant odelia; do printf "%-8s " "$r"; git -C $r branch --show-current; done
inc=$(Rscript -e 'cat(system.file("include", package="odelia"))')
diff -q "$inc/odelia/gradient.hpp" odelia/inst/include/odelia/gradient.hpp \
  && echo "ODELIA INSTALL IN SYNC"
```

**Expect:** all three on `claude/odelia-ad-tape-reverse-496fuf`, and `ODELIA INSTALL IN SYNC`.
**If out of sync:** `R CMD INSTALL /home/user/plant-dev/odelia --no-multiarch --no-docs`, then
`rm -f plant/src/*.o plant/src/*.so && R CMD INSTALL /home/user/plant-dev/plant --no-multiarch --no-docs`.
plant compiles against the **installed** odelia headers, not the submodule tree — this is why the
check exists.

### Step 1 — read exactly four documents, in this order. Nothing else.

| # | file | read it for |
|---|---|---|
| 1 | **this file, PART 1 only** (you are here) | the rules below |
| 2 | **`docs/v3-facts.md`** | every measured number, with the command that reproduces it |
| 3 | **`docs/v3-dead-ends.md`** | refuted claims — read before proposing any mechanism |
| 4 | **`docs/v3-engine-design.md`** | the current design: commitment, deletions, kill condition |

**Do NOT start from a narrative document.** Session 22 re-derived
`deepenings/deepening-6-light-coupling.md`'s conclusions by doing so. `docs/README.md` lists which
documents are narratives and says where new writing goes.

**`odelia/AUTODIFF.md` is the API authority** — read it when you touch the engine's surface, and note
that L2 is **not** a recording (an adaptive structure is rebuilt from plain values; see `v3-facts.md`
§4). Older prose describing "Replay L1/L2/L3" as three recorded layers is stale.

### Step 2 — verify the suites match what `v3-facts.md` claims.

```bash
cd odelia && make test          # expect: 0 fail / 535 pass / 5 skip
```

**The two packages need opposite invocations, and getting it wrong has produced false failure
counts in three separate sessions:**
- **odelia — `library()`, never `load_all`.** plant resolves odelia's compiled XAD `Tape` symbols in
  `.onLoad`, so odelia must be a real install. `test_dir()` does not attach the package (every
  exported name reads as missing); `test_local()` silently *skips the whole AD workflow*.
- **plant — `pkgload::load_all("plant")`, not `library(plant)`.** Many tests call internals
  (`Node`, `Parameters`, `trapezium` are not exported), so `library()` hides them.
- So the working combination is **install odelia, `load_all` plant**. And run
  `testthat::set_max_fails(Inf)` before quoting any count — testthat caps at 10 and prints the cap
  as the total.

Known-failing and **not** yours: `test-canopy-methods.R` (2 stale blessings), `test-mutant.R`
(8 stale seed-rain expectations), `test-strategy-ff16.R:248` (pandoc absent). The full plant suite
OOMs the box; use a focused set.

### Step 3 — re-run the one fact your task depends on.

Find the row in `v3-facts.md` your work rests on and run its command. That is the whole point of the
ledger carrying commands: a fact is re-verifiable rather than trusted. The probes live in
`docs/reference/` as `.cpp` + `.R` pairs.

**Run `Rscript` from `/home/user/plant-dev`.** A `cd plant` in a previous command leaves the shell
there and `load_all("plant")` then fails; pass an explicit `cd /home/user/plant-dev &&`.

### Step 4 — only now, and only if the task touches them, read further.

| if the task touches | read first |
|---|---|
| the TF24 leaf `p*` adjoint, or FD-verifying any TF24 gradient | **`oracle/oracle-response-inner-argmax-adjoint.md`** — mandatory. The FD is a δ/τ-indexed *family*, not one number |
| the light path | `deepenings/deepening-6-light-coupling.md` |
| the control flow or the memory profile | `v3-control-flow.md` |
| the `Replayable` concept | `v3-replayable-redesign.md` |
| the older corpus generally | `v3-evidence-triage.md` — **for every number, ask what would change it** |

**Diff against the right base.** odelia's default is `master`, not develop; the AD engine is a large
unmerged branch, and diffing the wrong base hides the whole engine:
```bash
git -C odelia diff --stat $(git -C odelia merge-base HEAD master) HEAD
git -C plant  diff --stat $(git -C plant  merge-base HEAD origin/develop) HEAD
```

## RULES THAT MUST NOT BE RELEARNED (each one cost a session, somewhere)
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
- **THE TWO PACKAGES NEED OPPOSITE INVOCATIONS. This is a trap in both directions.**
  - **odelia: `library()`, never `load_all()`** (above) — plant resolves odelia's compiled XAD
    `Tape` symbols in `.onLoad`, so odelia must be a real install. `load_all` silently skips
    the AD workflow.
  - **plant: `pkgload::load_all("plant")`, not `library(plant)`.** Many of plant's tests call
    **internal** functions — `Node`, `Parameters`, `trapezium` are NOT exported — so under
    `library(plant)` + `test_file()` they fail with `could not find function "Node"`. That is
    an invocation artifact, identical in kind to odelia's `test_dir` trap and just as
    meaningless. `load_all` exposes internals; `make test` works because `test_check()` runs
    tests with the package *namespace* as parent.
  - So the working combination is: **install odelia, `load_all` plant.** Session 22 hit the
    plant half of this and nearly recorded a green file as broken.
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

# PART 2 — CURRENT STATE + NEXT STEPS (rewritten session 22, 2026-07-27)

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

## START HERE: [`README.md`](./README.md) is the reading order

Four documents rebuild context, in order: **Part 1 of this file** (the rules below), then
[`v3-facts.md`](./v3-facts.md) (every measured number with its re-run command), then
[`v3-dead-ends.md`](./v3-dead-ends.md) (refuted claims — read before proposing a mechanism), then
[`v3-engine-design.md`](./v3-engine-design.md) (the current design).

**Session 22's per-session ledger has been folded into those three files** rather than left as a
fourth pile of prose. That is deliberate: facts, decisions and dead ends have different lifetimes, and
mixing them is why session 22 re-derived `deepening-6`'s conclusions and met four of its own
retractions inline. `README.md` also states where new writing goes — **append to the ledgers; open a
new document only for a new decision.**

### The state in six lines

- **The engine is five concepts** (Solver, System contract, Functional, `implicit_value`, and one
  rule: build structure on plain values, evaluate values at the active scalar). 697 lines and four
  primitives were deleted; odelia is 19 headers, green at 535 passes.
- **Memory is settled as a diagnosis:** cost is per-cohort-step × steps × cohorts, so only bounding
  the run helps. The step-local sweep is proven exact with peak flat in run length, at a flat 4.2×
  time. Proposed TF24 footprint **~110 MB** against a **~231 GB** whole-run tape.
- **The unit is the ODE step, not the event segment** — TF24 measures 18.43 steps/segment against
  FF16's 1.87, which fires the design's own kill condition.
- **`Replayable`'s structure role is dead**; the concept itself is opt-in and costs nothing unused.
- **The field is justified for all three strategies** — one shared rank-3 kernel, and the spline
  cannot carry `d(light)/dz` (227% mean error at production tolerance). **And the composition that
  had no witness now has one:** a field assembled over `implicit_value` source weights, coupled
  through one shared soil scalar, is FD-exact on every channel and matches an analytic identity at
  2.2e-16 — with a severance control proving the coupled channels come from the IFT partials alone.
- **ONE thing blocks a trustworthy TF24 gradient:** the `Leaf` is shared mutable state outside the
  replayed patch (`Individual` holds a Strategy *pointer*), so a TF24 segment re-run is not exact.
  The soil clamps turned out to be a *smaller* worry than they looked — three of the four are kinks,
  and the one real severance is **not visited at the default rainfall** (min θ is 18–21× θ_r). Its
  margin under a dried driver is the open question, not the clamps themselves.

### OPEN, in priority order

**This list is authoritative.** The task list mirrors it and carries the same IDs; where they
disagree, this list is right and the task wants updating. Nothing else in this file is a to-do list —
the SIGNPOSTS section that used to follow is gone, and why is recorded below.

1. **[#37] Own the `Leaf` per unit.** `Individual` holds a *pointer* to the Strategy, so a Patch copy shares
   one `Leaf` carrying per-solve state and four splines; a TF24 segment re-run inherits end-of-run
   leaf state (1.8e-13 → 1.3e-8, in `log_density`). Copy the Strategy per unit rather than auditing
   every cache — an audit is a convention that decays. **Then re-check the aux lag**, which is
   currently swamped by this.
2. ~~**Raise confidence on the leaf/soil coupling and its composition with the field.**~~
   **ANSWERED, and it is exact.** `test-ad-field-over-implicit.R` (52 assertions) assembles a
   `separable_field` over `implicit_value` source weights, with ONE shared soil-like scalar every
   source reads: all 5 channels FD-exact at 6.9e-11 - 3.3e-9, the `amp` channel matches an analytic
   identity at **2.2e-16** (so the field assembly is pinned independently of any FD), it holds over
   2 -> 40 sources and down to theta = 0.05, and severing the solve collapses **exactly** the coupled
   channels while leaving the others bit-identical. `v3-facts.md` section 3b. **Nothing further owed.**
3. **[#38] The soil clamps: one is a severance, and its margin is unmeasured.** Four non-smooth
   constructs, but only the drying guard `theta <= theta_r && rate < 0 -> rate = 0`
   (`tf24_environment.h:335`) is dangerous, and not because of smoothness: on its clamped side
   `d(rate)/d(theta)` **and** `d(rate)/d(resource_depletion)` are both zero, so the plant->soil uptake
   channel is **cut**, not kinked -- the a1-a4 class. The other three are kinks where a zero
   derivative is what the model means.
   **At the default rainfall no clamp is visited:** min theta is 18-21x theta_r, max theta 0.3106 vs
   theta_sat 0.428, min `runoff_factor` 0.9231, zero layer-steps at or near the guard
   (`Rscript docs/reference/soil-clamp-probe.R`). So the header's own claim that the floor is "well
   below any realistic operating moisture" holds for the default driver.
   **What is open:** the margin under a *dried* driver. TF24 is a water-limited model, so drought is a
   parameter regime a study visits, and if the guard fires there then a gradient taken across a
   rainfall gradient is silently severed. The probe takes a `rainfall` argument for exactly this
   sweep. **Do not smooth anything until the sweep says which regime fires it** -- smoothing an
   unvisited boundary is cost with no benefit, and `smooth_positive` is already used 3x in
   `ff16_strategy.h` and 0x here.
4. **[#35] Then build:** the step unit, restoring per node the ODE state, per-species counts and
   `pr_patch_survival_at_birth` (plus two more stamps only for R0). Interface in
   [`v3-control-flow.md`](./v3-control-flow.md); it needs no new plant surface beyond splitting
   `advance_fixed(e.times)` inside `run_next_impl`.
5. **Not on the critical path, and each has a detail worth not losing:**
   - **#32** — the tf24f collar 2.9e-4 residual at ψ=2.5 is **δ-independent from 1e-7 to 1e-3**, so it
     is a real missing term. Do *not* loosen the tolerance.
   - **#27** — the closing FD gate, the explicit `skip()` at `test-ad-tf24-scm-gradient.R:85`. Read
     `oracle/oracle-response-inner-argmax-adjoint.md` **before** designing the FD: tight-τ
     frozen-schedule reference, never a loose-τ swept plateau. Unblocked by item 4, not by leanness.
   - **#33, #34** — pure deletion, described in the tasks.
   - **Two stale blessings to re-bless, not debug.** `test-canopy-methods` `16.88946` (:179) and the
     soft-box/crown-centre difference (:116) were blessed 2026-06-25; the shading model changed
     2026-07-18/19/20. `test-mutant`'s 8 seed-rain expectations are pre-existing drift, measured
     identical against a fully rebuilt baseline (e.g. 0.09177 vs an expected 0.09125). **The full
     plant suite OOMs the box**, so gate on the focused set: `test-mutant`, `test-control`,
     `test-ad-k93-scm-gradient`, `test-scm-gradient-entry`, `test-scm-support`, `test-initial-state`,
     `test-ode-euler`.

## Before reading the corpus: [`v3-evidence-triage.md`](./v3-evidence-triage.md)
24 design docs, deepenings and Oracle consults exist and they are **not clean signal** —
some were superseded by refutations, some were always estimate dressed as measurement. That
document is the triage rule (**for every number, ask what would change it**), three worked
examples from session 21 where the casual version of "verify first" passed a wrong claim, and
a **marked reading list for the L2 question**. Read it before the archive.

## Superseded: the SIGNPOSTS list, and the "three documents that carry the current plan"

Both lived here until session 22 and both are **deleted, not moved** — they were the stale direction
that made a fresh session start from the wrong place. Recorded so the deletion is not undone:

- The **"three documents that carry the current plan"** named `v3-reverse-memory-design.md`,
  `v3-step-local-adjoint.md` and `v3-phase1-plan.md`. Those are now *narrative* — their numbers are in
  [`v3-facts.md`](./v3-facts.md), their wrong turns in [`v3-dead-ends.md`](./v3-dead-ends.md), and
  §6d of the first plus §3b of the second are refuted text. [`README.md`](./README.md) is the reading
  order; the plan is [`v3-engine-design.md`](./v3-engine-design.md) and
  [`v3-control-flow.md`](./v3-control-flow.md).
- **SIGNPOSTS 1–8** ordered eight next steps. Signpost 1 (crown preaccumulation) was already marked
  retired; 2 asked the owner to choose between leanness and the step-local sweep — **answered: the
  sweep**, since leanness tops out at ~3×/~5× against a required ~2600×; 3's two leanness levers are
  closed with #31 for the same reason; 6 described the *event segment* unit and a `replay_structure`
  hook, both superseded (TF24 measures 18.43 steps/segment, and `Replayable`'s structure role is
  dead). 4, 5, 8 and 8b survive as item 5 of OPEN above, with their details.
- Signpost 7 also carried a stale count (467 pass / 3 skip). Current: **535 pass / 5 skip**.

**The rule this enforces:** there is exactly one to-do list in this file, `OPEN` above. A second
ordered list is how direction goes stale — one gets updated and the other is what the next session
reads first.

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
