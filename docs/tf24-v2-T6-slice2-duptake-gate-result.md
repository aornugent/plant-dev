# T6 Slice 2 — analytic ∂(uptake)/∂(soil water) offline gate: CONDITIONAL GO (two-branch requirement found)

*2026-07-22. The offline gate the spec demands BEFORE any macro-step wiring. Pure R,
zero new C++ — reuses the Slice-1-exposed `dprofit_droot_collar_psi` +
`evaluate_root_collar_psi` + `find_root_collar_psi` + the `soil_consumption_` field.
Script: `scripts/tf24-benchmarks/duptake_ift_gate.R`.*

## What was tested

Over a macro-step cohorts are frozen, so the stand uptake Jacobian ∂a/∂u is the
ρ-weighted sum of per-leaf ∂c_i/∂ψ_soil_k (retention chain dψ/dθ = −n_ψ·ψ/θ is a
known analytic diagonal factor, validated separately by construction). The
load-bearing physics is the per-leaf Jacobian, whose hard part is the
**operating-point response**: c_i depends on soil water both explicitly and through
the collar operating point P*, which itself moves. The proposed cheap slope uses
the implicit function theorem on the interior stationarity condition
g(P*,ψ)=dprofit_droot_collar_psi=0:

  dP*/dψ_k = −(∂g/∂ψ_k)/(∂g/∂P*),  then
  ∂c_i/∂ψ_k = [∂c_i/∂ψ_k]_{P* fixed} + (∂c_i/∂P*)·dP*/dψ_k.

**Gate:** reconstruct ∂c_i/∂ψ_k this analytic-IFT way (operating point held fixed,
no re-solve) and compare to a finite difference of a FULL operating-point re-solve
(`find_root_collar_psi` at each perturbed soil). Central differences, solver tol
1e-12, near-optimal step h≈1e-4 (h_opt~tol^{1/3}); 45 soil states, driest-layer
magnitude 0.2–4.6 MPa (ψ_crit=5), split by wetness tercile.

## Result

| state class | count | full-Jacobian rel(max-entry) |
|---|---|---|
| **interior optimum** (stationarity residual < 1e-3) | 27/45 | med **4.3e-5**, p90 6.0e-5, max **8.6e-5** |
| **boundary-pinned** (residual ≥ 1e-3) | 18/45 | med **4.9e-2**, p90 8.6e-2, max **5.4e-1** |

- Wet tercile (all interior): rel(max) med 5.4e-5, max 8.6e-5.
- Dry tercile: rel(max) med 4.5e-2 — and it did **not** shrink when tol/​h were
  tightened (4.8e-2 → 4.5e-2), so it is a real error, not FD noise.
- **Spearman(error, interior-stationarity residual) = 0.71** — the error tracks
  whether the operating point is boundary-pinned, NOT dryness per se. Dryness just
  makes boundary-pinning more frequent (the feasible collar interval shrinks toward
  ψ_crit as the soil dries).

## Reading — interior IFT validated; the dry-limit failure is the active-constraint corner, and it is fixable

- **Where the collar optimum is interior, the analytic IFT slope is exact to
  ~1e-4** — better than the spec's target. The mechanism the whole speed arbitrage
  rests on (cheap operating-point response without re-solving) is sound.
- **Where the operating point is pinned to the feasible-interval boundary**
  (`bound_b` = the critical collar potential −root_crit/−root_psi_crit), dprofit ≠ 0
  there, so interior IFT is invalid. This is precisely the "active-constraint
  corner" the T6 spec flagged — now localized: it is the **collar-potential
  optimum**, not the inner stomatal argmax ∂P/∂p.
- **This is not the ancestors' death mode.** P2 already showed a(u) is smooth and
  most predictable near the dry limit (dry residual ~1%); that is consistent —
  boundary-tracking IS smooth, its slope simply comes from the boundary's response,
  not the interior IFT formula. The refresh is viable; the slope formula must switch.

## Consequence for Slice 3 (the two-branch ∂a/∂u — new, caught before building)

Slice 3's per-leaf ∂c_i/∂ψ_soil must be **two-branch**, keyed on the SAME
interior-vs-boundary test Slice 1 already computes (the endpoint-sign safeguard:
g_a>0 & g_b<0 ⇒ interior optimum):

1. **Interior optimum** → IFT on dprofit=0: ∂c_i/∂ψ_k = explicit + (∂c_i/∂P*)(−g_k/g_P).
   *Validated to 1e-4 here.*
2. **Boundary-pinned** → the operating point equals bound_b(ψ) (critical potential),
   so ∂c_i/∂ψ_k = explicit + (∂c_i/∂P*)·(d bound_b/dψ_k), where d bound_b/dψ_k is
   the IFT of the boundary's defining condition (the soil→collar continuity
   root_crit / root_psi_crit from `find_root_psi`). *To be implemented + gated the
   same way in Slice 3.*

The gate has done its job: it prevented shipping a refresh wrong on ~40% of states
(the dry ones), and it hands Slice 3 a precise, localized requirement instead of a
mystery. The interior branch — the bulk of the arbitrage's value in wet/moderate
windows (where soil water actually moves fast, per P2) — is proven.

## Caveats
- The gate is per-leaf (single cohort); the stand ρ-weighted sum follows by
  linearity over a frozen macro-step (the macro-step's defining assumption, T4).
- Both sides are finite-differenced (no closed-form partials in R); the interior
  result is at the FD floor (~5e-5), so the interior branch is validated as tightly
  as FD allows. The boundary error is 3 orders larger and tol/​h-independent → real.
- Fraction boundary-pinned (40% here) is over a deliberately dry-weighted state
  sample; the in-run fraction (how often a real cohort is boundary-pinned) is a
  Slice-3/4 measurement that sets how much the boundary branch matters.

## Next (Slice 3)
Build the two-branch analytic ∂a/∂u in C++ (interior IFT + boundary-response),
expose read-only, and re-run this gate against it (now analytic-vs-FD, not FD-vs-FD)
across the bank incl. the dry tercile. Only then wire the macro-step.
