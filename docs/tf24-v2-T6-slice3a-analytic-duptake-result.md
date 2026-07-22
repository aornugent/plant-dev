# T6 Slice 3a — two-branch analytic ∂(uptake)/∂(soil water) in C++: BUILT + VALIDATED

*2026-07-22. Implements the per-leaf uptake Jacobian the macro-step refresh needs, with the
two branches the Slice-2 gate showed were required. plant `Leaf::compute_duptake_dpsi_soil`.
Re-gated analytic-C++-vs-full-resolve-FD across the bank incl. the dry tercile.*

## What was built

`Leaf::compute_duptake_dpsi_soil()` fills `duptake_dpsi_soil_` (row-major i*n+k) with
d(soil_consumption_[i])/d(psi_soil_inverted_[k]) — the per-leaf uptake response to soil
water, in signed-potential space. Assumes `find_root_collar_psi` has run. Every partial is a
finite difference of a **closed-form** leaf function at the **fixed** operating point (no
re-solve, no FD through a search):

- **Common:** ∂c_i/∂P (collar) and the explicit ∂c_i/∂ψ_soil_i via FD of `E_from_Soil_to_Root_Collar`.
- **Operating-point response**, two branches keyed on the SAME endpoint-sign test Slice 1's
  Newton safeguard uses (g_a=dprofit(bound_a), g_b=dprofit(bound_b)):
  - **interior** (g_a>0 & g_b<0): IFT on the stationarity condition dprofit=0 →
    dP/dψ_k = g_k/g_P (FD of the analytic gradient `dprofit_droot_collar_psi`).
  - **boundary-pinned** (else): the operating point tracks the active feasible bound, so IFT
    on that bound's defining continuity condition — `E_column_zero==0` (pinned at bound_a) or
    `E_column(·,psi_crit)==0` (pinned at bound_b), dispatched by which g sign is active.

The integral cache (`root_vuln_integral_soil_`, keyed to the unperturbed soil) is disabled
during the probes and restored, along with the uptake outputs, at the end. Nothing on the
production path calls the method → production stays bit-identical (tf24 / shutdown / leaf
tests green).

## Re-gate: analytic C++ vs full operating-point re-solve FD

Script `scripts/tf24-benchmarks/duptake_analytic_regate.R`, 45 soil states, driest-layer
magnitude 0.2–4.6 MPa (ψ_crit=5), tol 1e-12.

| tercile | rel(max-entry) |
|---|---|
| ALL | med **4.2e-5**, p90 1.4e-4, max **6.1e-4** |
| DRY (driest mag > 3.13) | med **4.0e-5**, p90 2.0e-4, max 6.1e-4 |
| WET (driest mag ≤ 1.67) | med 5.4e-5, max 8.6e-5 |

The dry tercile — where the **interior-only** reconstruction was ~5% wrong (Slice-2 gate) —
is now at the FD floor. Worst case 6.1e-4 across all states. **Both branches validated.**

## The debugging that mattered (recorded so it isn't repeated)

- First cut (interior IFT only): dry-tercile median ~4.5e-2 — the Slice-2 finding, reproduced.
- Adding a boundary branch dispatched by a **residual threshold** (which of `E_column_zero`,
  `E_column` is ~0 at the operating point) fixed most states but left 3 boundary states at
  30–50% error — the threshold mis-selected.
- Fix: dispatch the boundary branch by the **g_a/g_b signs** (which constraint the optimiser
  made active), not by residual. This is the same information Slice 1 already computes, and it
  drove the worst case from 5.0e-1 → 6.1e-4. Lesson: key the derivative branch off the SAME
  test the solver used to choose the operating point, not a re-derived proxy.

## Caveats
- Per-leaf; the stand ρ-weighted ∂a/∂u follows by linearity over a frozen macro-step (T4),
  and the retention chain dψ/dθ = −n_ψ·ψ/θ is a known analytic diagonal factor — both wired
  in Slice 3b.
- The interior operating-point response uses FD of `dprofit_droot_collar_psi`, which contains
  inner root-finds (psi_stem_to_ci); the re-gate used tight inner tol (1e-12). The macro-step
  must run the inner solves tightly enough that this FD is clean (or the wet-window trust
  monitor absorbs the residual). Carried into Slice 3b/4.
- Interior↔boundary transitions are genuine derivative kinks (measure-zero); the macro-step
  trust monitor guards windows that straddle them.

## Next (Slice 3b)
Aggregate ρ-weighted per-cohort ∂a/∂ψ_soil + retention chain → stand ∂a/∂u (a Patch/SCM
byproduct in the member loop that already produces `a`), then the odelia macro/micro
integrator with the Taylor-refreshed uptake + trust monitor (toy-validated first per codesign).
