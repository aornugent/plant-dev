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

_Last updated: 2026-07-21 (session 10). **HEAD: plant `fa53480a`, super `13c50eb`, odelia `16cff79`
(unchanged). All clean, pushed.**_

_**►► SESSION 10 — step 7 certificate RE-OPENS b1: the TF24 leaf adjoint is NOT correct at
realistic patch lifetime. ◄◄** Session 9's "P2c COMPLETE through step 6 / b1 blow-up gone / every
leaf channel intact" claim was **verified only at life=1 and is FALSE at life ≥ 3.** The step-7
certificate (`scratchpad/tf24_cert.R`, now parallelised — see below) measured the reverse-AD
gradient vs the pinned-schedule central FD across patch lifetime:_

| life | ode_times | max\|ad\| | max\|fd\| | verdict |
|---|---|---|---|---|
| 1 | 128 | 5.23e5 | 5.26e5 | clean (32 intact, no BLOWN) |
| 2 | 165 | 5.35e5 | 6.88e5 | **clean** |
| 3 | 203 | **1.65e10** | 9.17e5 | blow-up begins |
| 4 | 361 | **2.56e14** | 1.15e6 | total blow-up (all channels BLOWN) |
| 10 | 1664 | — | — | reverse-AD run **OOMs** (>15 GB tape) |

_**Findings (all measured, cross-checked):** (1) the blow-up is **AD-only** — the FD/double path
stays sane and grows smoothly (5e5→1.15e6) throughout; per PART 1 that makes it a **real analytic
derivative bug**, not a schedule/replay artifact. (2) Onset is **sharp** between life=2 (clean) and
life=3 (1.65e10), then compounds to 2.56e14 at life=4 — the signature of **one near-singular node's
adjoint** appearing once the patch dries enough for a cohort's leaf to cross the interior↔bound
**fold**, then propagating to every seeded param through the coupled reverse sweep (all ratios
~1e8–1e9, uniform). This is **plant#60 / b1, not closed** — `assemble_leaf_from`'s interior p\* node
divides by `P_pp` (nested central-FD 2nd derivative of profit), which **→0 at the fold**; the
`|E_column|<1e-6` regime detector and the nested-FD denominators are not robust across the
transition. (3) Reproduced identically via the **monolithic** `tf24_allfield` (max\|ad\|=1.65e10 at
life=3), so it is NOT a driver-refactor artifact. (4) **life=10 OOMs** in the reverse-AD run: the
resident gradient records the whole SCM on one tape (~Σ steps × live cohorts × inputs); even with
`supplied_derivative`'s per-step economy it exceeds 15 GB by life=10 — a separate real scaling limit
(needs tape checkpointing / recompute-on-sweep, an odelia-level feature)._

_**Certificate optimisation LANDED (plant `fa53480a`):** split the `ad_certificate.cpp` `sweep()`
into a `do_ad` flag + explicit `fd_fields` subset, exposing `tf24_ad()` (one reverse sweep, all
fields) and `tf24_fd(fields)` (central FD for a subset). The FD reference — `2·N` independent pinned
SCM runs, the dominant cost — is now fanned across cores with `mclapply`; **verified bit-identical to
the monolithic result** (`max|split-mono| = 0`, AD and FD). FD dropped 88.7s→22.9s at life=1 (3.9× on
4 cores). `*_allfield` exports unchanged externally. `scratchpad/tf24_cert.R [life]` uses the parallel
path (life defaults to 10; use life≤2 for a clean run, 3–4 to see the blow-up)._

_**►► IMMEDIATE NEXT STEP: task #23 (plant#60 fold-IFT) — the leaf adjoint's p\* node must be made
robust across the interior↔bound fold.** The clean life≤2 result shows the physiology/output channels
are right; the failure is localised to the p\* pivot's derivative at the fold. Next diagnostic:
instrument `assemble_leaf_from` to log per-compute_rates the selected regime + the node denominators
(interior `P_pp`, bound `dF/dx`) at life=3, find the step where a denominator collapses, and design a
fold-robust node (the design's anticipated bordered/root-find formulation, or clamping/switching with
a wider detector band). This is a structural change — use `system-design` before building. P2d (TF24f)
is blocked behind it (shares the pivot). Step 7 is NOT passed; b1/#60 is RE-OPENED._

_**Localization so far (session 10, env-guarded freeze probes at life=4, since reverted):** the blow-up
is inside `assemble_leaf_from`'s final `assemble()` call, but is **NOT cleanly one node**. Freezing
the p\* pivot derivative made it WORSE (2.56e14 → 4.04e28); freezing `psistem_node` worse (→4.29e18);
freezing `soil_uptake` → NaN; freezing `ci_node` → crash. i.e. **freezing any single node destroys a
cancellation and makes the residual bigger** — the signature of a **near-singular COUPLED leaf
Jacobian** near the constraint boundary, where the assembly's *chain* of independent scalar IFT nodes
(`soil_uptake → psistem_node → ci_node`, each dividing by its own marginal derivative) is
ill-conditioned. Hypothesis (unconfirmed): the leaf operating point (ψ_stem, ci, E_up, p\* jointly) is
a coupled fixed point whose derivative wants ONE joint IFT over the full leaf Jacobian, not a chain of
scalar IFT nodes. **Decisive next probe (do this before any redesign): per-leaf-call adjoint-vs-FD
isolation** — extract a dry-regime leaf operating point from a life=4 run, compare the injected leaf
partials (d profit/d input, d uptake/d input) against a direct double FD of the leaf solve at that
point; matches ⇒ the fault is feedback amplification, mismatch ⇒ the assembly partial is wrong and the
mismatched input/output names the culprit. The freeze approach is a dead end (it breaks cancellations);
don't repeat it. `TF24_PSTAR_FROZEN`/`TF24_FREEZE_*` diagnostics were reverted (tree clean at
`fa53480a`; the installed `.so` may still carry them — rebuild before trusting a fresh run)._

_**►► ROOT CAUSE FOUND (session 10, `scratchpad/leaf_assemble_sweep.cpp`) — regime-aware ψ_stem. ◄◄**
A single-leaf isolation probe (reconstruct `assemble()`'s chain, seed `kmax`, compare its reverse-AD
derivative to a re-solve double FD of the real leaf, swept over soil water θ) pins it: the profit
derivative is **exact while soil is wet** (θ≥0.16, interior, ψ_stem<ψ_crit=7.085 → `ratio_profit`=1.0000),
then **degrades the moment ψ_stem reaches ψ_crit** (θ≤0.15: ratio 0.78→0.44→0.32→0.24). The mechanism is
in the ψ_stem intermediate: **in the bound regime the real leaf pins ψ_stem=ψ_crit (`d ψ_stem/d kmax≈0`),
but the assembly's `psistem_node` — which computes ψ_stem by inverting the flux balance
`transpiration(ψ_stem)=E_up` — returns a spurious ~1e6 derivative** (θ=0.15: chain `-209926` vs real
`0.065`). That wrong ψ_stem derivative flows into the per-layer soil-consumption partials, and the
soil-water feedback amplifies it over steps → the life≥3 SCM blow-up. **This matches the sharp onset:**
life≤2 stays wet (every leaf interior, `psistem_node` valid); life≥3 dries enough for the first cohort to
hit the bound, where the assembly's ψ_stem model is invalid. The "joint-IFT" hypothesis above is
SUPERSEDED — the interior chain is correct (certificate clean at life≤2); the bug is that `assemble()`
applies the interior ψ_stem relation in the **bound/shutdown** regimes too. **Fix (design next):
regime-aware ψ_stem in `assemble()`** — when the converged leaf is at the bound (ψ_stem==ψ_crit) or in
shutdown, anchor ψ_stem at ψ_crit (carrying only dψ_crit/dstate), recompute ci from that, and use the
shutdown profit formula (`-R_d - hydraulic_cost_TF(ψ_crit)`) where applicable — mirroring the double
leaf's regime branches, which the assembly currently collapses to the interior case. This is a contained
change to one function, not a rewrite. Validation: certificate must be clean at life=4 (and ≥). Also
resolves the `psi_crit` SEVERED footnote (same bound/shutdown channel)._

_**►► CORRECTED ROOT CAUSE (session 10, later) — it is the SOIL-WATER FEEDBACK channel, not the leaf
assembly. ◄◄** The regime-aware-ψ_stem fix above was **built and it was a NO-OP** (max|ad| byte-identical
2.56e14): the `|E_column|<1e-6` bound detector is **never true** in the life=4 run (0 bound calls / 495826
interior) — those bound-regime observations came from the FROZEN-p\* probe, a different path, so that
diagnosis (and the joint-IFT one) were over-read from a non-representative probe. Direct measurement on
the REAL active path settled it:_
_• Interior p\* node denominator `P_pp` is **healthy** (min|P_pp|≈2.5, never near 0) — not a vanishing
denominator._
_• The **injected leaf partials are bounded and sane** across all 495826 calls: `max|d profit/d input|=9421`,
`max|d uptake/d input|=3.03`. So the leaf assembly is NOT producing huge partials._
_• **Killing the soil-water feedback channel** (zeroing the injected partials w.r.t. the `psi_soil` STATE
inputs, `src==3`) drops `max|ad|` **2.56e14 → 3.05e5 (sane)**. Since the true `max|fd|`≈1.15e6 is ABOVE the
killed value, the soil feedback is a **legitimate** gradient channel that AD **over-amplifies ~1e8**._
_**Conclusion:** the leaf's soil-state coupling partials — `d(profit)/d(psi_soil)` and
`d(soil_consumption_L)/d(psi_soil)` injected via `supplied_derivative` — are **bounded but WRONG**, and the
soil-water ODE reverse sweep compounds the per-step error over the (dry, long) trajectory to 1e14. The bug
is in how `assemble_leaf_from` differentiates the leaf outputs w.r.t. the soil-water state (the coupled
re-optimisation response through `psi_soil`), NOT the p\* node, NOT the bound regime, NOT partial magnitude._
_**Decisive next probe:** extend `scratchpad/leaf_assemble_sweep.cpp` to seed a `psi_soil` layer (not `kmax`)
and compare the assembly's `d(uptake)/d(psi_soil)` + `d(profit)/d(psi_soil)` to a re-solve double leaf FD,
across θ — the mismatch (present even in the interior, since life≤2 is clean only because soil barely moves
there) names the exact wrong term. Then fix that term in `assemble_leaf_from`. All session-10 diagnostics
(regime restructure, `TF24_LOG_PPP`, `TF24_LOG_PART`, `TF24_KILL_SOILFB`) were reverted — tree clean at
`fa53480a` + the two doc commits; `scratchpad/leaf_assemble_sweep.cpp` kept as the probe. This is a
multi-session structural fix; b1/#60 remains OPEN._

_Session 7: **P2c steps 1–3 DONE + step 4 grounded.**
Landed the `S` leaf output map (`plant::leaf_output` in `leaf_model.h`), the **N_ci** and **N_psistem**
`implicit_value` nodes (both gate0-verified), and an empirical **p\* regime map** that de-risks step 4 before
coding. Session 6 scoped P2c and did step 0. The committed P2c shape (`docs/p2c-leaf-adjoint-design.md`) is
*evaluate-at-converged-point + IFT nodes*: the leaf solver stays `double`, `S` is carried only by a closed-form
output map and by each solved root as an `implicit_value` node (N_ci, N_psistem, N_p\*), with **N_p\* a
regime-detector fold node** on the plant#60 branch-death condition `{F=0, ∂F/∂ci=0}`. **b1 diagnosis:** the
~1e30 blow-up is the FD `supplied_derivative` seam finite-differencing across the plant#60 corner — b1 and #60
are one root cause, and P2c's exact IFT node removes both. **Steps 0–3 DONE; step 4 (N_p\*, the fold) is next
— START HERE.** Full detail in the **SESSION 7 block** below (then SESSION 6). Session 5 (P2b-5 census +
odelia#46) and sessions 3–4 (resident FF16+K93 + the run-shaped entry) are the foundation._

## WHAT SESSION 4 DID (the run-shaped gradient entry + odelia co-design) — foundation for session 5
All plant-side. Double path bit-identical; entry + AD gradient + double-path suites green (the one TF24
failure, `SCM cohort-density blow-up #550`, is pre-existing and unrelated — deferred #551/#517 steepness).

- **`plant/scm_gradient.h` — `scm_jacobian`/`scm_gradient` + `offspring_metric`/`census_metric` functionals.**
  The plant analogue of odelia's `jacobian_on_double` (plant's `SCM` is *not* an `ode::Solver` — it HAS-A one
  + node scheduling — so it can't use odelia's Solver-typed entry, but it delegates seed/tape/sweep to odelia's
  `compute_jacobian` and returns odelia's `{values, jacobian}` pair). Flow: build double SCM → `refine_schedule()`
  (discover the resolved L1) → `rebind_from<RevS>()` → `set_schedule(recorded_steps())` → `compute_jacobian`.
  A caller passes traits + target indices + a functional, never a schedule.
- **The odelia System `rebind_from<S2>()` contract is completed on the plant types** — this is *exactly*
  odelia's `has_rebind_from`/`active_solver` hook, not a plant invention. `Strategy::copy_config_from` (base,
  scalar-independent config) + the one-home `plant::rebind_strategy_fields` (config + `field_ptrs()` widen;
  precomputed state rebuilt by `prepare_strategy` — the reset-timing contract). `Parameters::rebind_from`,
  `SCM::rebind_from`. `PLANT_DIFFERENTIABLE(Strategy_)` (strategy.h) emits the two hooks every strategy needs
  identically (`rebind` alias + `rebind_from`); used by FF16/K93/TF24, TF24f hand-writes (extra acclimation
  config). **`field_ptrs()` is the one AD-field enumeration** feeding three consumers — `ad_parameters()`
  (which params to *seed*), `rebind_from` (config to *cross*), `field_names()` (R labels) — so it stays even
  under rebinding; seeding and config-copy are different jobs.
- **R5 is structural:** `scm_jacobian` asserts the active value reproduces a double-replay reference (a dropped
  config member shifts it O(1) → loud `util::stop`). This is what would trip if a TF24 gradient were attempted
  (its env soil config is set at construction, not Control-derived, so it does not cross yet — deferred with b1).
- **Resident replay unified to odelia's Solver contract (task #4, resident half).** `SCM::recorded_steps()`
  (== `solver.times()` == `r_ode_times()`, one body) is the SINGLE source of the resident replay grid;
  `SCM::set_schedule(steps)` is the handoff. `run()`'s segmenting loop and `run_mutant`'s `step_history`
  (L3, deferred) are UNTOUCHED — `step_history` stays reachable only via `run_mutant`, never a resident source.

**Tests:** `scm_gradient_driver.cpp` (takes traits + indices, NO schedule) + `test-scm-gradient-entry.R`
(the entry's self-refined schedule reproduces `run_scm(refine_schedule)`'s gradient — FF16 vs the certified
bespoke driver 1e-6; K93 vs the certificate AD 1e-6 — and the reoptimising/model FD).

## ►► IMMEDIATE NEXT STEP (start here) ◄◄
"Finishing Phase 2" = correct resident reverse-mode AD gradients for **TF24 and TF24f**. The plan is settled
and recorded: **`docs/p2c-leaf-adjoint-design.md`** (read it first — the design + the env addendum + the
step-0 and step-1 verification records). **Steps 0 (env diff-source) and 1 (`S` leaf output map) are DONE +
verified.** The next item is **step 2**:
1. ~~**Step 0** — env as a differentiation source.~~ DONE (session 6).
2. ~~**Step 1** — `S` leaf output map (`plant::leaf_output` in `leaf_model.h`).~~ DONE (session 7). Closed
   forms for assim/arrhenius/electron-transport, `hydraulic_cost_TF`, `transpiration`, `stom_cond_CO2`, and
   `soil_uptake`; the four hydraulic splines collapse to `odelia::incomplete_gamma` (`root_b`/`root_c` are NOT
   AD-seeded, so soil uptake carries `S` only via `psi_soil` + collar). Value-parity verified at the converged
   double point (~1e-15 spline-free algebra; ~1e-9 transpiration/uptake = the spline's own bias). Not on the
   rate path yet — the seam is untouched (deleted at step 6).
3. ~~**Step 2 — N_ci.**~~ DONE (session 7). `leaf_output::ci_node` — `implicit_value` on
   `g(ci)=A(ci)·umol_to_mol − gc·(ca−ci)·inv_atm=0`, denom `dg/dci>0`. Gate0: `dci/dvcmax_25`, `dci/dgc` vs
   central FD to ~1e-10.
4. ~~**Step 3 — N_psistem.**~~ DONE (session 7). `leaf_output::psistem_node` — `implicit_value` inverting
   `transpiration(ψ_stem,ψ_up)=E_up`, denom `k_max·exp(−(ψ_stem/b)^c)>0`. Gate0: `dψ_stem/dE_up`,
   `dψ_stem/dψ_up` vs central FD of the production spline inverse to ~1e-6 (spline precision).
5. **Step 4a — interior N_p\* node.** DONE (session 8). `implicit_value(p*, F)` with
   `F(p)=[profit_reduced(p+ε)−profit_reduced(p−ε)]/(2ε)`; `profit_reduced<T>` re-solves the double
   roots off-tape at `p±ε` and assembles the active outputs via `leaf_output` + N_psistem/N_ci, so
   XAD supplies `P_ps=∂²profit/∂p∂state` and `implicit_value`'s FD supplies `P_pp=∂²profit/∂p²` —
   returning `p*` carrying `−P_ps/P_pp=dp*/dstate`, **no hand-written second derivatives**.
   E4-verified two channels (`scratchpad/leaf_pstar_node.cpp`): k_max reld 1.4e-4/3.5e-4 (θ=.20/.30),
   vcmax matches to all digits. ε≈1e-2·(|p*|+1) is the nested-FD sweet spot. Design record:
   `docs/p2c-leaf-adjoint-design.md` "Step 4a". The node is validated in scratchpad only — its
   production home/signature (needs the double `Leaf`, unlike `ci_node`/`psistem_node`) is fixed by
   the step-5/6 wiring, so it is NOT yet in `leaf_model.h`.
6. **Step 4b — the bound-regime branch.** DONE (session 9, `scratchpad/leaf_pstar_bound_node.cpp`).
   `p* = −implicit_value(root_crit, F)`, `F(x)=soil_uptake(psi_soil,x,…)−transpiration(psi_crit,−x,k_max,b,c)`
   (the `E_column=0` continuity residual at the stem's vulnerability limit), assembled from the same
   `leaf_output` free functions as the double path. `implicit_value`'s inner FD gives `dF/dx`, XAD gives
   the exact `dF/dstate`; **no nested FD** (no second derivative here), cleaner than 4a. Enabling change
   (plant `70d7179c`): `leaf_output::soil_uptake` got explicit `<T>` on its
   `proportion_of_conductivity`/`cumulative_vuln` calls (unary-minus args are expression templates under
   an active scalar); `double` instantiation bit-identical, production untouched (`soil_uptake` isn't a
   production caller until step 6). E4-verified (perturb member, re-optimise at `GSS_tol_abs=1e-10`,
   central diff; θ=0.13/0.14/0.15 all clamped, `dist(p*,bound_b)≈3e-11`): **k_max reld 6.6e-7/1.2e-7/2.7e-7,
   psi_crit reld 2.4e-6/1.7e-6/2.8e-6** — the seeded-param channels the gradient needs, tighter than 4a's
   ~1e-4. Design record: `docs/p2c-leaf-adjoint-design.md` "Step 4b". Node validated in scratchpad only;
   the interior/bound branch selection (clamped-to-`bound_b` detector) and production home/signature are
   fixed by step-5/6 wiring. **►Steps 5–6 START HERE.**
   Context (the original fork framing) below. `find_root_collar_psi`
   golden-section-maximises profit over the collar potential `p*` on `[bound_a, bound_b]`
   (`prepare_collar_solve`). **`p*` interior ⇒ stationarity IFT `∂profit/∂p*=0`; `p*` on `bound_b` (the
   branch-death edge) ⇒ bordered-fold IFT `g(p*)=∂F/∂ci=0`, `dp*/dstate=−g_state/g_p`.** Whether `p*` sits at a
   bound is the structural #60 branch-indicator. `g=∂F/∂ci` must be an `S` closed-form. **Fold caveat:** a
   naïve `implicit_value` on the ci residual with `y=ci` divides by `dF/dci→0` at the fold — that's why N_p\*
   uses the bordered condition, NOT the plain ci residual. Verification: E4 (adjoint vs a re-optimising FD on
   a real transpiring patch, plant#60), not just an isolated node gate. N_ci/N_psistem feed it (ci and ψ_stem
   at the chosen p*). **The regime map is already grounded** (design doc "Step 4 grounding" +
   `scratchpad/leaf_pstar_regime.cpp`): the **interior stationarity regime dominates** the wet range, so build
   that node first (`G(p*)=dprofit/dp*=0`; `Leaf::dprofit_droot_collar_psi` already computes `G` in double and
   is the FD check), verify against the `dp*/dθ` E4 targets, THEN add the bordered-fold branch for the narrow
   BOUND band, selected by `|dprofit/dp*|<tol`. Then step 5–6: assemble N_p\*→N_psistem→N_ci→output map, wire
   into `net_mass_production_dt`, delete the seam.
5. **►Steps 5–6 — the p\* pivot assembly (START HERE — DESIGNED, not built).** Design committed
   (`docs/p2c-leaf-adjoint-design.md` "Steps 5–6 — design", Tier 3 `system-design`). **Key realisation:**
   the envelope theorem means `profit` doesn't need `dp*/dstate`, but every OTHER leaf output does
   (transpiration, `E_up`, per-layer `soil_consumption` read by `evapotranspiration_dt`, ψ_stem, ci) — so
   N_p\*'s job is to produce **p\* as ONE active scalar pivot** that flows into all outputs. Build a private
   templated method `TF24_Strategy::assemble_active_leaf_outputs` (replacing `leaf_profit_at_fixed_collar`),
   reading `pars`/`environment`/`leaf`: (a) active p\* pivot — TF24 interior ⇒ node 4a, TF24 bound ⇒ node 4b
   (clamped-to-`bound_b` detector), TF24f ⇒ the tracked collar state (no node); (b) recompute active
   physiology from active `pars` via the templated `leaf_output` helpers (peak_arrh_curve, electron_transport,
   …) — mirror `set_physiology` (`leaf_model.cpp:218-241`: vcmax_/jmax_/gamma_/km_/R_d_/electron_transport_)
   and `net_mass_production_dt` (`tf24_strategy.cpp:365-370`: k_max, sapwood volume from active pars/height);
   (c) anchor ψ_stem/ci at the double optimum via `psistem_node`/`ci_node`; (d) form
   `profit_s = assim_colimited(ci) − hydraulic_cost_TF(ψ_stem)` and
   `soil_consumption_active_[L] = soil_uptake(psi_soil, −p*, …)[L]`. Then **delete** the FD block
   (`tf24_strategy.cpp:509-690`), `leaf_profit_at_fixed_collar`, `dprofit_droot_collar_psi`,
   `dsoil_consumption_dpsi_collar_perlayer`, and the `supplied_derivative` include+usage — the active path
   makes them dead. Input channels to reproduce (from the FD seam, `shouldRecord`-gated): the ~15
   `TF24_AD_FIELDS`, `height`, `light_active` (self-shading openness), per-layer `psi_soil_S`, and TF24f's
   `seam_collar_psi_input()`. Deep-crown (`!single_solve`) active path stays a `util::stop` (unchanged scope).
   **Verify:** double bit-identity (FF16 + TF24 tripwires), then E4 (adjoint vs re-optimising FD on a real
   patch) across TF24 and TF24f. At step 6, also collapse the now-redundant spline-free algebra on `Leaf::` to
   delegate to `leaf_output::` (the ~1e-15 re-baseline is acceptable once the value path moves).
   The two pivots are validated in scratchpad (`leaf_pstar_node.cpp` 4a, `leaf_pstar_bound_node.cpp` 4b).
   **►CORRECTION (session 9, `docs/p2c-leaf-adjoint-design.md` "Steps 5–6 — CORRECTION"): the design
   above was incomplete.** `soil_uptake`'s `area_leaf` + root resistances (`r_R_H_min`, `r_R_V_sum`) are NOT
   fixed geometry — they carry the height/a_r1/a_l1/a_l2/root_depth_shape_eta channel via `mass_root_prop`
   (`leaf_model.cpp:261-284`, `tf24_strategy.cpp:378-393`). Passing them passive silently severs those
   gradients (the FD seam captures them by full-leaf-rebuild). So the assembly must ALSO actively recompute
   `eta_c(eta)`, `area_leaf(height,a_l1,a_l2)`, `mass_root_prop` (templated `CanopyShape::Q` — TF24's
   `Q(double,double,double)` at `tf24_strategy.cpp` needs an active sibling), and `r_R_H_min`/`r_R_V_sum`
   from active `mass_root_prop`, AND `leaf_output::soil_uptake` must be generalised so `area_leaf` + the two
   resistance vectors are active `T` (grav_head_z, beta_R_H/V, dz stay double). Value-anchor every output:
   `out = S(double_val) + (assembled − to_passive(assembled))`. Regime detector from the converged point (no
   re-solve): `is_bound = |E_column(root_collar_psi_, psi_soil_inverted_, psi_crit)| < tol` (save/restore
   `root_collar_psi_`+`E_up_`); in the bound regime `root_crit = root_collar_psi_`. Also generalise
   `electron_transport` (PPFD, curv → T) + `assim_colimited`/`ci_node` (curv → T) — they severed k_I/light and
   the seeded curv_fact_*. The full channel recipe is in the design doc CORRECTION section.
   **►►SECOND CORRECTION (session 9) — the run-tape blows memory; keep `supplied_derivative`.** The assembly
   was built exactly as above (saved: `scratchpad/assemble_active_leaf_outputs.saved.cpp`), compiles, is
   bit-identical on double, and gives correct per-call gradients — BUT wiring it onto the ambient run tape
   `std::bad_alloc`s even at life=1. The resident gradient records the WHOLE SCM run on one tape; the old
   `supplied_derivative` collapsed each step's leaf to O(#inputs) tape nodes on purpose, while the full active
   assembly records the whole leaf algebra + nested implicit_value inner-FDs per step (~100–1000× footprint).
   **The "delete supplied_derivative / assemble on the run tape" plan is NOT viable.** Corrected build: run
   the (correct) assembly on a **LOCAL per-call tape**, extract exact partials `d(profit)/d(input)` +
   `d(uptake_L)/d(input)`, inject via `supplied_derivative` onto the run tape — the old seam's shape with
   EXACT partials instead of FD. Needs the assembly parameterised to read local active inputs (a `pars`-copy
   or input-vector arg) not the member `pars`. `supplied_derivative` STAYS; `dprofit_droot_collar_psi` STAYS
   (TF24f uses it); only `leaf_profit_at_fixed_collar` + `dsoil_consumption_dpsi_collar_perlayer` go. Plant is
   at `70d7179c` — the WORKING FD seam is preserved (tf24 tests green); steps 5-6 not landed. See design doc
   "Steps 5–6 — SECOND CORRECTION".
6. **Step 7 — gate:** rebuild TF24 Certificate B (`scratchpad/tf24_cert.R`, driver `ad_certificate.cpp`
   `tf24_allfield` committed) — all leaves intact, E4 gap closed. Then **P2d (TF24f)** reuses N_p\*.

**b1 is diagnosed, not a separate track:** the ~1e30 blow-up IS the FD seam differencing across the plant#60
corner (`Leaf` is entirely `double`; the only reverse-tape path is that FD seam). P2c's exact IFT node removes
b1 and #60 together. plant#60 is IN SCOPE (the leaf adjoint is ours); its E4 verification (adjoint vs a
re-optimising FD on a real transpiring patch) is the correctness reference for steps 1–6.

## ►► SESSION 8 — P2c step 4a (the interior N_p\* node) designed + E4-verified ◄◄
HEADs unchanged plant-side (`efe624e4`); superrepo advances with docs only. **Step 4a is the
interior-stationarity collar-optimum node — the dominant regime per the grounding.**
- **`system-design`: implicit_value on a finite-differenced reduced profit.** `dp*/dstate=−P_ps/P_pp`.
  `implicit_value(p*, F)`, `F(p)=[profit_reduced(p+ε)−profit_reduced(p−ε)]/(2ε)`; `profit_reduced<T>`
  re-solves the double roots off-tape at `p±ε` then assembles the active outputs from the existing
  `leaf_output` map + N_psistem + N_ci. XAD gives the numerator `P_ps=∂²profit/∂p∂state` on the reverse
  tape; `implicit_value`'s own double FD gives the denominator `P_pp=∂²profit/∂p²`. **No hand-written
  second derivatives** — the derivative path reuses the one forward algebra and cannot drift from the
  double `Leaf`. Rejected: a hand-written closed-form `G` (drift-prone; and `dprofit_droot_collar_psi`'s
  internal forward-AD won't record state on the reverse tape) and an odelia `stationary_value` primitive
  (one witness only; TF24f reuses the *same* node — retrofit trigger = a second AD-path argmax).
- **E4-verified, two independent channels** (`scratchpad/leaf_pstar_node.cpp`, perturb the member +
  re-optimise `p*` at tightened `GSS_tol_abs=1e-10`, central diff): k_max node `10917`/`10360` vs FD
  `10918`/`10364` (θ=.20/.30, reld **1.4e-4 / 3.5e-4**); vcmax node `−0.00183` vs FD `−0.00183` (matches
  to all shown digits; its ~2–5e-3 *relative* is the FD floor on a near-zero-sensitivity channel).
  `dprofit/dp*≈−1e-7` confirms the interior regime. **ε≈1e-2·(|p*|+1)** is the nested-FD sweet spot
  (larger = `O(ε²)` truncation; smaller = roundoff, `implicit_value`'s inner 1e-6 amplifies `G`'s
  `~1e-15/ε` noise).
- **Interior only.** At a bound (`|dprofit/dp*|>tol`) `p*` is not stationary, so the stationarity IFT is
  wrong there — `dp*/dstate` follows `d(bound_b)/dstate`. Step 4b adds the bordered-fold branch gated by
  `|dprofit/dp*|<tol`. The node is validated in scratchpad only (not on any rate path, not in
  `leaf_model.h`); its production signature is fixed by the step-5/6 assembly.
- **Step 4b grounded — the BOUND band is a stem-critical root-find, not a bordered-fold**
  (`scratchpad/leaf_pstar_bound.cpp`). Two corrections to the design's assumptions: (1) in the
  bound band `p* = bound_b = −root_crit` **exactly** (p* tracks the moving bound), and `root_crit`
  solves `E_column(x, psi_soil, psi_crit)=0` (`find_root_psi(…,1)`) — the collar where the **stem
  hits `psi_crit`**. So the bound derivative `dp*/dstate = −d(root_crit)/dstate` is a **plain
  root-find IFT** (`implicit_value` on `E_column=0`, reusing `soil_uptake`+`cumulative_vuln`), NOT
  the anticipated bordered-fold `{F=0,∂F/∂ci=0}` — simpler. (2) The detector is "`p*` clamped to
  `bound_b`" (which `find_root_collar_psi` already determines), **not** `|dprofit/dp*|<tol`: at a
  tight golden section `dprofit/dp*≈4e-11≈0` in the bound band too (the earlier 0.9–4.3 was a loose-
  GSS artifact). `dp*/dθ` finite in the band (−252→−34), = `d(bound_b)/dθ` — the E4 target for 4b.

## ►► SESSION 7 — P2c steps 1–3 (S output map + N_ci + N_psistem) DONE + step 4 grounded ◄◄
Final HEAD plant `efe624e4`, superrepo `620e939`; odelia unchanged (`16cff79`). All plant-side. Steps 1–3
of P2c landed; step 4 (N_p\*, the fold) grounded and next. Gate/probe drivers in `scratchpad/` (gitignored):
`leaf_output_parity.cpp` (step 1), `leaf_ci_node.cpp` (step 2), `leaf_psistem_node.cpp` (step 3),
`leaf_pstar_regime.cpp` (step-4 grounding). **Build recipe reminder:** header edits force a near-full
recompile — `rm -f plant/src/*.o plant/src/*.so && R CMD INSTALL plant --no-multiarch --no-docs` (~3 min, run
from `/home/user/plant-dev` with an explicit `cd`); sourceCpp drivers use the
`PKG_CXXFLAGS`/`PKG_LIBS` bridge (see the driver-run one-liners in the scratchpad, or PART 1 build tax).
- **Step 2 — N_ci** (`leaf_output::ci_node`, `leaf_model.h`). `implicit_value` on the ci supply=demand
  residual; denom `dg/dci=A′·umol_to_mol+gc·inv_atm>0`. Gate0: `dci/dvcmax_25` (photosynthesis channel via A)
  and `dci/dgc` (stomatal-supply channel) vs central FD of the re-solved ci root to ~1e-10.
- **Step 3 — N_psistem** (`leaf_output::psistem_node`). `implicit_value` inverting
  `transpiration(ψ_stem,ψ_up)=E_up`; denom `k_max·exp(−(ψ_stem/b)^c)>0`. Gate0: `dψ_stem/dE_up`,
  `dψ_stem/dψ_up` vs central FD of the production spline inverse `Leaf::transpiration_to_psi_stem` to ~1e-6
  (spline precision); closed-form-vs-spline flux residual ~1e-13. **Bug fixed en route:** `cumulative_vuln`
  must call `odelia::incomplete_gamma<T>` explicitly — the two args are XAD expression templates at an active
  type, undeducible to one `S` (double has none, so it only surfaced at the reverse scalar). Value-identical
  at double.
- **Step 4 grounded — the p\* regime map** (`scratchpad/leaf_pstar_regime.cpp`; evidence recorded in the
  design doc's "Step 4 grounding" section). Soil-moisture sweep with detector `|dprofit_droot_collar_psi(p*)|`
  and E4 = re-optimising FD `dp*/dθ`: **interior stationarity dominates the wet range** (`dprofit/dp*≈0`,
  18/24 points — the gate0-green case); a **narrow BOUND/fold band at the dry transition** (θ≈0.12–0.15,
  `dprofit/dp*`=0.9–4.3, `dp*/dθ`≈−120 — the plant#60/b1 regime, but `dp*/dθ` is **finite**: the b1 blow-up was
  the seam differencing the profit *jump*, not a singular `dp*/dθ`); **shutdown below** (`decide()` early-exits).
  The `|dprofit/dp*|<tol` detector separates interior vs bound cleanly. The `dp*/dθ` column is the E4 target
  N_p\* must reproduce.
- **Nodes are off the rate path** (only the scratchpad drivers instantiate them at active types). The seam is
  untouched; steps 4–6 assemble N_p\*→N_psistem→N_ci→output map and wire+delete the seam at step 6.

## ►► SESSION 7 (earlier) — P2c step 1 (S leaf output map) DONE ◄◄
Final HEAD plant `27ca7bdd`, superrepo `a4e3e03`; odelia unchanged (`16cff79`). All plant-side.
- **`plant::leaf_output` — the `S` leaf output map (`leaf_model.h`, header-inline).** Scalar-generic closed
  forms of the leaf outputs, evaluated at the converged operating point: `arrh_curve`/`peak_arrh_curve`,
  `electron_transport`, `assim_colimited`, `proportion_of_conductivity`, `cumulative_vuln`, `transpiration`,
  `stom_cond_CO2`, `hydraulic_cost_TF`, `soil_uptake`. **The four hydraulic splines collapse to the exact
  Weibull antiderivative `odelia::incomplete_gamma`** (`transpiration = k_max·[Γ(ψ_stem)−Γ(ψ_up)]`,
  `Γ(m)=(b/c)·γ(1/c,(m/b)^c)`). Key simplification found this session: **`root_b`/`root_c` are NOT in
  `TF24_AD_FIELDS`** (fixed doubles), so `soil_uptake` carries `S` only through `psi_soil` (soil ODE state) and
  `P_x_r` (collar) — the root Weibull params stay passive. The commitment holds: the leaf solver stays double.
- **Home decision (user pref):** inline in the existing `leaf_model.h`, NOT a standalone `leaf_output_map.h` —
  one definition across both TUs, hot-path inline convention. The two forward-AD helpers
  (`assim_colimited_ad`/`hydraulic_cost_ad`) moved up out of `leaf_model.cpp`'s anonymous namespace into
  `leaf_output`; `dprofit_droot_collar_psi` now calls the migrated ones (`leaf_output::assim_colimited<AD>` /
  `hydraulic_cost_TF<AD>`).
- **Value-parity gate** (`scratchpad/leaf_output_parity.cpp`, gitignored): the `S` map at the converged double
  operating point reproduces `profit_`/`assim_colimited_`/`hydraulic_cost_`/`vcmax_`/`jmax_`/`electron_transport_`
  to ~1e-15 (spline-free algebra, bit-identical) and `transpiration_`/`stom_cond_CO2_`/`E_up_`/per-layer
  `soil_consumption_` to ~1e-9 (the ~100-knot spline's own interpolation bias — the closed form is exact, #468
  already seeded knots from it). Nothing on the rate path yet, so the double suites are bit-identical:
  regressions green (leaf 214, TF24 46, TF24f 57, FF16 53+17).
- **code-review: approve.** One deferred note: the spline-free algebra (`assim_colimited`/`hydraulic_cost_TF`)
  now lives on both `Leaf::` and `leaf_output::` — pre-existing duplication (the old anon-ns helpers were
  already the second copy), collapse deferred to step 6 (delegating `Leaf::` re-baselines the value path ~1e-15,
  which step-1's bit-identity constraint forbids but step 6 allows). The soil resistances pass as `double` (the
  `a_r1`/root-mass→uptake derivative is a step-5 scope boundary, correctly not carried yet).

## ►► SESSION 6 — P2c scoped + step 0 (env differentiation source) DONE ◄◄
Final HEAD plant `ac1eaecc`, superrepo `6556c8a`; odelia unchanged (`16cff79`). All plant-side.
- **P2c design (`docs/p2c-leaf-adjoint-design.md`).** System-design search over the TF24 leaf adjoint. The
  `Leaf` (`leaf_model.cpp`, 1490 lines) is entirely `double`; the only reverse-tape path is an FD
  `supplied_derivative` seam that central-differences leaf profit at frozen `p*`. **b1 root cause:** in the
  soil-coupled patch the operating point sits on the plant#60 **fold** (profit jumps ~1.5 at `p*`), so the
  seam FDs across a discontinuity → partials ≈ jump/step ≈ 1e6 → ~1e30 after the SCM reverse sweep. gate0
  (single plant, fixed env, away from the corner) is green — the blow-up is corner-specific. **Winner
  (committed):** *evaluate-at-converged-point + IFT nodes* — leaf solver stays `double`; `S` carried only by a
  closed-form output map + `implicit_value` nodes at each solved root; N_p\* a **regime-detector fold node**.
  Commitment kept true by structure: `golden_section_max`/`uniroot` are `double`-typed, so the iteration
  cannot reach the tape. Worklist steps 0–7 in the doc (see IMMEDIATE NEXT STEP).
- **plant#60 escalated + in scope.** Read the issue's 3 comments: the operating point is an active-constraint
  **corner** (`∂P/∂p≈−8.8≠0`, a ci-branch switch), so the frozen-p\* seam is O(1) wrong through the value
  channel too; the original `−P_{p,ψ}/P_{pp}` fix is invalid (P_pp undefined at a corner) — superseded by the
  IFT node on the fold `{F=0,∂F/∂r=0}` (two Oracles converged; locus smooth, slope −1.0004). E4 (adjoint vs a
  re-optimising FD on a real transpiring patch) is the correctness reference. The leaf adjoint is OURS on this
  branch, so #60's fix = P2c step 4. **plant#64 filed:** `depth` as an AD param needs a moving-mesh derivative
  (it sets the grid) — deferred; `depth` crosses as passive config for now.
- **P2c step 0 DONE + verified — the environment is a differentiation source.** Base `Environment_` gained the
  odelia System hooks (`ad_parameters`/`ad_initial_state`/`copy_config_from`; empty defaults for FF16/K93).
  TF24 env: the six rate-path soil params (`soil_moist_sat`, `K_sat`, `a_psi`, `n_psi`, `a_infil`, `b_infil`)
  promoted to `S` AD leaves (`TF24_ENV_AD_FIELDS`); `ad_initial_state` exposes the per-layer soil-water state
  as seedable ICs; `copy_config_from` crosses the passive soil geometry (guarded resize). `Patch::ad_parameters`
  composes `[species params, env params]` (58 = 52+6, a documented column-order contract); `ad_initial_state`
  returns the 5 soil layers. `SCM::rebind_from` crosses the env (config + param widening). **Verified:**
  composition correct; crossed env **bit-identical** to fresh in every config member; **R5 no longer trips for
  TF24** (short-life; gradient still garbage via the un-fixed leaf seam — expected, steps 1–6); FF16/K93 entry
  gradient + census regressions green. (`a_psi`/`n_psi` promoted after finding the "not currently used"
  comment stale — they ARE on the drainage/retention path. An earlier "0.17% crossing discrepancy" was a
  flawed reference — a fresh SCM pinning L1 onto unrefined L0 — not a bug.)
- **Diagnostic harness rebuilt:** `scratchpad/tf24_cert.R` (TF24 Certificate B; driver `ad_certificate.cpp`
  `tf24_allfield`/`tf24_field_names` committed) — its FD is the E4 re-optimising reference. `scratchpad/` is
  now gitignored (ephemeral). The `field_values` bridge: `unlist(add_strategies(scm_base_parameters("TF24"),
  trait_matrix(lma,"lma"),birth_rate=20)$strategies[[1]]$pars)[tf24_field_names()]`.

## ►► SESSION 5 — P2b-5 census + odelia#46 + #6 cleanup (DONE, LANDED) ◄◄
Final HEAD plant `33d2c982`, superrepo `b39cf09`; odelia unchanged (`16cff79`). All plant-side. (Landed across
plant `fe4f1f4c` field / `4a997898` census / `33d2c982` cleanup.)
- **odelia#46 CLOSED on the field path.** The competition field reconstructed a per-cohort density
  `exp(λ)/dx` that overflows at tiny-but-nonzero spacing near a growth stall. Both consumers
  (`Species::compute_competition`, `Patch::assemble_competition_field`) now consume bounded mass `exp(λ)`
  directly, formed as `(measure/dx)·exp(λ)·φ` — `measure/dx` is O(1), `exp(λ)` bounded, so `exp(λ)/dx` is
  never materialised. Value-identical to the old trapezium up to reassociation (no re-baseline; certified
  gradients unchanged). Coincident cohort (`dx==0`) contributes 0 (odelia's −inf convention, guarded
  explicitly — a missing guard gives `gap/0`→NaN, the one self-inflicted bug found and fixed). The refinement
  diagnostic + R views still read the density VIEW (intensive, legitimately huge near a stall — #550/#551
  territory, deliberately not touched).
- **`Species::census<Ψ>` is the design's §8 operator** — the mass-weighted reduction `Σ n_i·Ψ(individualᵢ)`;
  `compute_competition` is now expressed through it (the self-shading member, `Ψ = per-individual shade`, with
  the query-height cutoff). `Patch::census<Ψ>` sums per patch area. One home for the reduction idiom.
- **FF16 multivariate census gradient (P2b-5).** Three per-individual Ψ (leaf area→LAI, above-ground biomass,
  stem basal area) via the #266 `strategy->foo(vars)` pattern; `census_vector` codomain-3 functional →
  `scm_jacobian` (one adaptive recording, three reverse sweeps). Each metric's reverse-AD `d/d(lma)` matches a
  reoptimising adaptive-FD to ~1e-5. Test: `test-scm-gradient-entry.R` "FF16 census vector gradient".
- **Cleanup (#6, DONE).** Removed the dead `strategy_has_rebind` SFINAE trait (zero use sites; superseded by
  odelia's `has_rebind_from`/`rebind_or_self`) and the orphaned drivers `ff16_feedback_probe`,
  `ff16_single_rate_probe`, `field_crown_probe` (+ its build-broken test). **Kept** (by decision): the bespoke
  `ff16_scm_gradient_driver`/`ad_certificate` — they are the entry test's independent cross-check; retiring
  them would weaken it to a self-FD gate. **Deferred** (documented, not pulled forward): (a) profiling the
  per-call `cohort_spacing` alloc in `Species::census`; (b) the trivial `/area` echo between `Patch::census`
  and `compute_competition`. AD + regression suites green throughout.

**Deferred by explicit decision (do NOT pull forward without asking):**
- **R-facing `run_scm_gradient` shim** — R surface last; the DX (functional selection, name→index) is not yet
  settled and R is user-facing.
- **task #4 remainder** — `run_scm`'s R path still loads `parameters.ode_times` via `make_node_schedule` (a
  production self-describing path, not the gradient path); fold onto `set_schedule` when the R surface is
  revisited. `run_mutant`/L3 stays deferred (no L3 caching yet).
- **guard `odelia::supplied_derivative()`** (no stationarity check — engine-level plant#60 invitation).

**Odelia/plant AD primitives — use these, don't hand-roll:**
- **`SCM::recorded_steps()` / `set_schedule()`** — the resident replay contract (odelia's Solver vocabulary).
  A resident gradient replays `recorded_steps()`; never inject a grid another way.
- **`rebind_from<S2>()` / `PLANT_DIFFERENTIABLE`** — make a strategy differentiable; the mechanic lives once in
  `plant::rebind_strategy_fields`. A new strategy: write `AD_FIELDS` + `PLANT_DIFFERENTIABLE(Name_)`.
- **`Species::census<Ψ>` / `Patch::census<Ψ>`** — the mass-weighted population reduction `Σ n_i·Ψ(individualᵢ)`,
  consuming `exp(λ)` directly (overflow-free). A census metric = `census` of a per-individual Ψ;
  `compute_competition` is the self-shading member (Ψ = shade, with the query-height cutoff). Never reconstruct
  density on a field/reduction path. A codomain-m census is a functional returning m of these → `scm_jacobian`.
- `odelia::implicit_value<S>(y_star, F)` — value defined by `F(y;p)=0`, returned IFT-differentiable. FF16/TF24
  birth heights (replaced hand-rolled `lift_birth_height`).
- `odelia::util::diagnostic(x)` — intent-named `to_passive`: "derivative deliberately not taken." A bare
  `to_passive` on a rate path is the reviewable smell.
- **The reset-timing contract** (`odelia/AUTODIFF.md`): a differentiable System re-derives parameter-dependent
  precomputed state in `reset()` (post-seed) or that channel is severed. `Patch::reset()` re-preparing
  strategies is plant's instance; `rebind_from` leaves precompute to it by design.

After any model change: re-run `scratchpad/certificate.R` — changed leaves flip to intact, others unchanged.

**odelia#46 — CLOSED (session 5).** The competition FIELD no longer reconstructs `exp(λ)/dx`; it consumes
mass `exp(λ)` directly (`Species::census`/`compute_competition`, `Patch::assemble_competition_field`), so a
tiny-but-nonzero spacing near a stall can no longer overflow it. Value-identical (no re-baseline). The prior
"competition-in-mass" prototype was reverted for a K93 *gradient* cost because it used *full* `cohort_spacing`
at the boundary (a 2× re-weight); the landed fix keeps the ½ boundary (`measure/dx`), so it's exact. The
intensive density VIEW (refinement diagnostic, R accessors) can still be huge near a stall — that's the
model-side density runaway #550/#551, a separate track.

## ⤵ HISTORICAL BACKGROUND (sessions 1–3 — SUPERSEDED; the work described below has LANDED)
Everything from here down records how the transport-chart / FF16-gradient problem was diagnosed and solved
across earlier sessions. Retained for rationale and evidence, **NOT as current direction** — the live state
and next steps are the top of PART 2. In particular P1e-λ (log-mass transport), the **FF16 chart opt-in**,
and the FF16/K93 **resident gradients are all DONE and certified**; any "current work" / "THE next task" /
"CONCRETE NEXT STEPS" phrasing below is stale (those tasks are complete — see `build-plan.md` P2a/P2b).

### THE HEADLINE (the transport-chart fix — now landed for K93 and FF16)
The FF16 gradient bug, the #550 density runaway, and the value/gradient tension are **one thing**: the
old transport scheme carried **log-density ℓ** and computed the compression `C = ∂ₓg`. The fix — which
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
