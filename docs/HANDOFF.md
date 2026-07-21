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

_Last updated: 2026-07-21 (session 7). **HEAD: plant `efe624e4`, superrepo `620e939`, odelia `16cff79`
(unchanged — all plant-side). All clean, pushed.** This session (7): **P2c steps 1–3 DONE + step 4 grounded.**
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
5. **►Step 4 — N_p\* (START HERE, the hard core).** The regime-detector fold node. `find_root_collar_psi`
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
5. **Steps 5–6 — soil active coupled state (mostly already `S`); delete the FD `supplied_derivative` seam** +
   `leaf_profit_at_fixed_collar` + `dprofit_droot_collar_psi` + `dsoil_consumption_dpsi_collar_perlayer`. At
   step 6, collapse the now-redundant spline-free algebra on `Leaf::` to delegate to `leaf_output::` (deferred
   from step 1 to preserve bit-identity; the ~1e-15 re-baseline is acceptable once the value path moves).
6. **Step 7 — gate:** rebuild TF24 Certificate B (`scratchpad/tf24_cert.R`, driver `ad_certificate.cpp`
   `tf24_allfield` committed) — all leaves intact, E4 gap closed. Then **P2d (TF24f)** reuses N_p\*.

**b1 is diagnosed, not a separate track:** the ~1e30 blow-up IS the FD seam differencing across the plant#60
corner (`Leaf` is entirely `double`; the only reverse-tape path is that FD seam). P2c's exact IFT node removes
b1 and #60 together. plant#60 is IN SCOPE (the leaf adjoint is ours); its E4 verification (adjoint vs a
re-optimising FD on a real transpiring patch) is the correctness reference for steps 1–6.

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
