# T6 — Newton-on-uptake + weekly macro-step: PRESCRIPTIVE BUILD SPEC

*2026-07-22. For a fresh session to execute. The diagnosis phase is closed and the
speed arbitrage has a GO (see `tf24-v2-P2-uptake-taylor-falsifier-result.md`). This
spec is prescriptive: follow it in order, honour the gates, do not skip the offline
validation before wiring. Read Part 1 of `tf24-solver-performance-HANDOFF.md` first
(codesign rules, bit-identical invariant, branch/commit rules).*

## 0. Goal and why now

**Goal (DX, not benchmark-chasing):** cut the cost of a TF24 forward solve by advancing
the O(M) cohort block on a **weekly macro-step** while the 5-layer soil-water column
sub-cycles on its fast clock, refreshing total water uptake `a` **cheaply** from soil
water instead of re-solving all M cohorts every fast step. Target: **10–100× fewer
cohort solves** (T4 headroom) at converged offspring production.

**Why this is now worth building (evidence, all this session):**
- **T4** (`tf24-v2-T4-filtered-field-result.md`): offspring is ≤3% sensitive to soil-water
  texture faster than ~2 days, +14% at weekly → the fast cohort re-solves are wasted.
- **P2** (`tf24-v2-P2-uptake-taylor-falsifier-result.md`): uptake IS a low-order function
  of soil water over weekly windows, and MOST predictable near the dry limit (dry-tercile
  quad residual ~1%). The way the old multirate/IMEX attempts died (dry-limit breakdown,
  noisy FD Jacobian) is **falsified**.
- **The analytic gradient already exists** (see §5): `LeafModel::dprofit_droot_collar_psi`
  is the exact IFT-based d(profit)/d(operating point). The hard part is done.

**Why the ancestors failed and this differs (do not repeat):**
- Warm Newton on `∂P/∂p = 0` failed — the argmax is an active-constraint corner with **no
  interior root**. T6 does NOT Newton the argmax; it Newtons the **branch-death /
  operating-point condition**, which HAS a real root, using the existing analytic gradient.
- IMEX RODAS failed — its Jacobian was **finite-differenced through the GSS bracketing**
  (noise ~δ/ε). T6 uses the **analytic** `dprofit_droot_collar_psi`, no FD through the
  search.
- MRI/decomposition was 6–25× slower — it put the O(M) coupling **inside** the fast
  sub-cycle. T6's whole point is the **cheap uptake refresh** so the O(M) sum is NOT
  re-run inside the sub-cycle.

## 1. The three pieces

**(A) Newton operating-point solve per cohort (replace GSS with Newton).** Replace the
golden-section search in `find_root_collar_psi` with a safeguarded Newton on
`dprofit_droot_collar_psi = 0` (interior optimum) with the existing shutdown/feasibility
early-exits as the bracket/fallback. Warm-start from the previous fast-step operating
point. Expected 2–3 evals/cohort vs GSS's ~10–15. Standalone this is already a per-eval
win (~32→~15–20 units) and removes the τ-floor (retires the 2.4× `J(τ)` flip as a solver
artifact). **This is the first shippable slice and its own bit-identical-off diagnostic.**

**(B) Analytic ∂(uptake)/∂(soil water) as a member-loop byproduct.** With Newton at the
operating point, the IFT gives ∂(operating point)/∂(soil water) and hence the analytic
`∂a_ℓ/∂u_k` (a 5×5 per cohort; summed with ρ_j over cohorts → the stand `∂a/∂u`). Compute
it in the same member loop that produces `a` (near-free). This is the slope the refresh
needs and the clean Jacobian IMEX never had.

**(C) Weekly macro-step with Taylor-refreshed uptake + trust monitor.** Over a macro-step
[t, t+H] (H ~ weekly, or adaptive): freeze cohorts; sub-cycle soil water on its fast
clock; at each fast sub-step refresh `a(u) ≈ a(u₀) + (∂a/∂u)(u−u₀)` (+ optional 2nd order);
a **trust monitor** re-expands (recompute the true O(M) `a` and reset u₀) when the step
leaves the trust region. P2 says re-expansion is needed mainly in **wet/high-swing**
windows (~⅓), rarely near the dry limit. Reuse the retired MRI scaffolding in `patch.h`
(`freeze_slow`, `fast_rates`, `fast_block_uptake`) — the missing piece it lacked was
exactly (B).

## 2. Build order (engine-first per codesign; each slice bit-identical-off + validated)

**Slice 1 — Newton operating-point solve (plant leaf model).**
- Implement safeguarded Newton in `LeafModel` using `profit_at_collar_psi` +
  `dprofit_droot_collar_psi`; keep GSS as fallback when Newton leaves the feasible
  interval or the shutdown exit fires. Add a `control` flag (default OFF → GSS path,
  bit-identical).
- **Validate:** `test-strategy-tf24.R`, `test-tf24-shutdown.R`, FF16 bit-identity guard
  (`test-strategy-ff16*.R`). With the flag ON, offspring must match GSS to converged
  tolerance across the bank; count evals/cohort (expect ↓). Confirm the `J(τ)` flip is
  gone (sweep τ; J flat).
- **Ship as its own PR** (per-eval win, independent of the macro-step). Acceptance:
  bit-identical OFF; ON matches within converged tol and is faster per eval.

**Slice 2 — analytic ∂a/∂u (plant).**
- Extend the Newton solve to return ∂(operating point)/∂(soil water) (IFT at the
  `psi_stem_to_ci` root-find — the same IFT `dprofit_droot_collar_psi` already uses),
  chain to `∂a_ℓ/∂u_k` per cohort; sum with ρ_j in `assemble_resource_depletion` to the
  stand 5×5 `∂a/∂u`. Expose read-only for validation.
- **Validate offline FIRST (gate):** compare analytic `∂a/∂u` to a central-difference of
  `a(u)` on saved fields (reuse `sweep_soil`/`overwrite_cached_soil`/`run_mutant` from the
  P2 machinery). Must agree to ~1e-4 rel across the bank, incl. the dry tercile. If it
  disagrees near the dry limit, stop — the refresh will be wrong exactly where it matters.

> **Slice 2 GATE RESULT (2026-07-22, `tf24-v2-T6-slice2-duptake-gate-result.md`): CONDITIONAL GO.**
> Interior-optimum IFT slope validated to ~1e-4. BUT the gate found interior IFT is
> WRONG (median ~5% err, tol/h-independent) exactly where the collar operating point is
> **boundary-pinned** (active constraint at the critical potential; Spearman 0.71 of error
> vs the interior-stationarity residual). So the Slice-2 ∂a/∂u must be **two-branch**, keyed
> on the SAME interior-vs-boundary test Slice 1's endpoint-sign safeguard already computes:
> (1) interior → IFT on dprofit=0 [validated]; (2) boundary-pinned → differentiate the active
> boundary bound_b(ψ) (IFT of the root_crit/root_psi_crit continuity condition in
> `find_root_psi`). Build BOTH in Slice 3's C++ ∂a/∂u and re-gate analytic-vs-FD before wiring.

**Slice 3 — macro-step scheme (odelia engine + plant hooks).**
- In odelia, add a macro/micro integrator that: freezes cohorts over H, sub-cycles the
  5-dim soil block with the Taylor-refreshed `a(u)` from Slice 2, and a trust monitor
  (2nd-order remainder estimate) that triggers a true-`a` re-expansion. Prototype/validate
  on a cheap toy first (codesign rule: engine capability proven on a toy before the real
  patch). Reuse `patch.h` `freeze_slow`/`fast_rates`.
- Add `ode_method="mri_uptake"` (or similar) gated OFF by default; production
  bit-identical when off.

**Slice 4 — wire + measure end-to-end (the real acceptance test).**
- Run the bank (intense_storms, whiplash, extended_drought, dry_to_wet, long_horizon,
  drydown) at a converged member mesh. Report, per scenario: offspring rel error vs the
  global-RK reference, cohort-solve count, wall-clock, and the trust-monitor re-expansion
  rate.

## 3. Acceptance criteria (the deliverable is judged on these)

1. **Bit-identical** when the feature is off (the standing invariant).
2. **Offspring accuracy:** within the converged-`J` tolerance of the global-RK reference on
   every bank scenario — this is the P2 caveat made concrete: the wet-window refresh error
   (8–19%) amplifies ~10× through feedback (T3), so end-to-end offspring MUST be measured,
   not assumed. If offspring drifts on wet/storm scenarios, tighten the trust monitor (more
   re-expansions) and re-measure — the knob trades speed for accuracy.
3. **Speed:** net cohort-solve reduction (target 10–100×; realised value = f(trust-monitor
   rate)). If re-expansion fires ~every fast step (P2 says it won't), the scheme collapses
   to global RK and is DEAD — same as the MRI ancestor. That is the kill condition.
4. **Gradient (out of scope for offspring, note only):** reverse mode is not in play here;
   do not gate on it.

## 4. Kill conditions / risks (know them before building)

- **Trust monitor fires constantly** → no speedup (collapses to global RK). P2 makes this
  unlikely (median weekly residual 5–9%, dry-limit ~1%), but Slice 4 measures it for real.
- **Analytic ∂a/∂u wrong near the dry limit** → Slice 2's offline gate catches it before
  any wiring. Do not skip that gate.
- **Wet-window offspring drift** → Slice 3/4; mitigated by the trust monitor; if
  irreducible, the arbitrage caps at "safe on dry/steady scenarios, falls back to global
  RK on storm-dominated ones" — still a partial DX win, report honestly.

## 5. File / function anchor map (verified this session)

- **Analytic gradient (the key existing asset):**
  `plant/inst/include/plant/leaf_model.h` — `dprofit_droot_collar_psi(opt_root_psi)`
  (exact IFT d(profit)/d(operating point)), `profit_at_collar_psi(target,…)`,
  `find_root_collar_psi()` (current GSS optimiser to replace with Newton),
  `prepare_collar_solve(…)` (soil-side caches, share across evals), the shutdown early-exit
  operating point (branch-death). Impl in `plant/src/leaf_model.cpp`.
- **Uptake aggregation (the O(M) sum → `a`):**
  `plant/inst/include/plant/models/tf24_environment.h` — `assemble_resource_depletion()`,
  `compute_rates(...)`; soil state = 5 layers + `aux_num=4` cumulative (so ODE/uptake
  vectors are length 9; physical soil = first 5). `soil_moist_residual=1e-2`,
  `soil_moist_sat=0.428`.
- **Macro/micro scaffolding (reuse):** `plant/inst/include/plant/patch.h` — `freeze_slow`,
  `fast_rates`, `fast_block_uptake`, `slow_rates`; odelia `mri.hpp`, `ode_solver_internal.hpp`.
- **Probe machinery for the offline gates (reuse):** SCM `set_record_uptake`,
  `run_mutant`, `sweep_soil`, `overwrite_cached_soil` (plant `0015c9fd`); the sweep in
  `scripts/tf24-benchmarks/{arnoldi_spectrum,uptake_taylor_falsifier}.R`.
- **Control surface:** `plant/inst/include/plant/control.h`, `src/control.cpp`,
  `inst/RcppR6_classes.yml`, `scm.h` (`scm_ode_method`).
- **Benchmark bank + reference cost:** `scripts/tf24-benchmarks/data/*.rds`; a 12-yr
  default solve ≈ 111 s, a 2× uniform ≈ 561 s (dense uniform is solver-expensive) — budget
  Slice-4 runs accordingly.

## 6. First action in the new session

1. Read Part 1 of the handoff + this spec + P2 + T4 results.
2. Confirm repo state (handoff Part 2 table) and rebuild plant if headers changed.
3. **Slice 1** (Newton operating-point solve), flag OFF by default, validate bit-identical,
   then ON vs GSS across the bank. Ship it. Then Slice 2's offline gate before anything
   else.
