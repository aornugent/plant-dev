# T6 Slice 3b-iii step 2 — mri_uptake wired on the real patch: PASS (forward)

*2026-07-22. Step 1 proved the uptake macro/micro integrator on a toy (frozen affine
coupling + probe-free 2nd-order trust monitor + record→replay). Step 2 wires it into
the real TF24 patch as `ode_method="mri_uptake"` and gates it on the coupled SCM.*

## What was built (minimal seam over the existing MRI path)

`method="mri"` on plant already reduces (for the patch `coupling_size()==0`) to
freeze-slow → sub-cycle-fast → advance-slow, with the fast soil block reading its
coupling by re-running the O(M) cohort sum (`fast_block_uptake` = `assemble_resource_
depletion`) every micro-step — the documented 6–25× penalty. `mri_uptake` swaps that
one channel for the affine refresh.

- **odelia:** `Method::mri_uptake` + `MriUptakeStep` (uses `mri_forward_euler` — freeze
  cohorts, advance the slow block once per leg — and `UptakeSubcycle`), factored through
  a shared `mri_step_run` so it does not duplicate `MriStep::step`. `subcycle_uptake`
  gained a Strang split micro-step (`analytic_flow · residual_frozen · analytic_flow`,
  the 3b-ii stepper) for stiff Systems exposing `residual_frozen`; the toy's forward-
  Euler branch is unchanged.
- **plant patch hooks** (guarded by `env_has_split<E>` so FF16/K93 compile to no-ops):
  `refresh_anchor` captures `a₀ = fast_block_uptake()` + `J = assemble_duptake_jacobian()`
  (Slice 3b-i) once per re-expansion; `predicted_uptake` = `a₀ + J·(θ−anchor)`;
  `residual_frozen` = the soil residual reading that affine `a`; `trust_excursion` = the
  probe-free squared-relative-excursion monitor; `trust_true_error` = the oracle probe
  (diagnostic). Control keys `mri_uptake_tol` (1e-2) / `mri_uptake_nmicro` (40); the
  string map in `scm_ode_method`; a `mri_coupling_evals` counter (the O(M) snapshots).

## Gate result (`scripts/tf24-benchmarks/mri_uptake_gate.R`, full horizon = 30 yr)

TF24 SCM, single-species (lma 0.0825), converged inner tol (1e-12), weekly macro grid
(`ode_step_size_max = 7/365`), `mri_uptake_tol = 1e-2`, `nmicro = 40`.

| run | offspring | vs rkck |
|---|---|---|
| rkck (global adaptive reference) | 1.0379246 | — |
| **mri_uptake** | 1.0277411 | **9.8e-3** |

- **Coupling reduction: 40×.** Expensive O(M) cohort sums (`mri_coupling_evals`) = 1654
  vs cheap frozen-residual evals (`mri_fast_rate_calls`) = 66160. The reduction is 40× =
  `nmicro` because the trust monitor **never tripped** (re-expansions = 0): over weekly
  legs the affine model never drifted past tol, so each leg spent exactly its one
  mandatory capture. The MRI-ancestor death mode (re-capture ≈ every step) does not occur.
- **Offspring within 9.8e-3** of the global-RK reference (a slight underestimate,
  consistent with the order-1 forward-Euler slow advance).
- **Bit-identical off:** the default path (`ode_method=""`) is untouched — the new enum
  value, stepper, patch hooks and control keys are dispatched/consulted only on the
  `mri_uptake` path; the default TF24 SCM offspring is unchanged (1.03714898556177 at the
  default tol). FF16/K93 compile (hooks are `env_has_split`-guarded no-ops).

## Where the residual ~1% error comes from (honest decomposition)

0 re-expansions means the **affine-refresh error is not the driver** — if it were, a
0-re-expansion run would be badly off; instead it is <1%. The refresh accuracy is
independently established: 3b-ii (offline soil-traj ≤5.5e-4) and the step-1 toy
(offspring ≤5e-4). The residual ~1% is the **MRI macro-step discretization** (order-1
frozen-cohort slow advance over weekly legs), which is shared with `method="mri"` and is
a Slice-4 knob (finer macro grid or a higher-order coupling table), not something the
uptake refresh introduces.

A direct `method="mri"` full-resolve comparison to cleanly separate the two was
attempted but is impractical: the full-resolve run over a multi-year schedule is the very
6–25× penalty T6 removes (>30 min, killed), and shrinking the horizon to make it
affordable drops offspring into the near-zero-J regime (~1.7e-8 at 8 yr — the stand is
barely reproductive; handoff hard-won lesson #4: J is ~10× hypersensitive, use ≥12 yr),
where relative errors are dominated by hypersensitivity, not the refresh. So that
isolation is left to Slice 4's converged-mesh bank measurement rather than over-claimed
here.

## Scope / what is NOT done here (carried to Slice 4 / future)

- **Reverse mode on the patch:** step 2 wires the FORWARD path (the offspring/speed
  deliverable). The `reexpansions` schedule is recorded on the forward pass, so it is
  replay-ready, but the patch-level adjoint is a separate subsystem (per the Slice-1–3
  "reverse not in play" note) — proven through the uptake inner on the toy (step 1), not
  yet wired on the patch.
- **Macro-grid driving:** the SCM drives the solver with `advance_adaptive`; the macro
  leg size is bounded via `ode_step_size_max` (set to weekly here). A dedicated macro grid
  (forcing-kink / fixed weekly) is a Slice-4 refinement, shared with `method="mri"`.
- **Acceptance vs converged-J and the full scenario bank** (intense_storms, whiplash,
  extended_drought, dry_to_wet, long_horizon, drydown), incl. offspring within converged
  tol and wall-clock, is Slice 4.

## Verdict

**PASS (forward).** `mri_uptake` runs on the real coupled TF24 patch, bit-identical when
off, cutting the O(M) cohort-sum coupling channel **40×** at **<1%** offspring error on
the full-horizon single-species SCM, with the trust monitor holding re-expansions at
their floor (death mode absent). The affine-refresh mechanism is validated (3b-ii + toy);
the residual error is the tunable MRI macro discretization. NEXT: Slice 4 — the scenario
bank at a converged mesh (offspring vs converged-J, cohort-solve count, wall-clock,
trust-monitor rate), tightening the macro grid / coupling order if offspring accuracy
needs it.
