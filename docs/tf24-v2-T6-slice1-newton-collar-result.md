# T6 Slice 1 — Newton (safeguarded gradient root-find) collar operating point: SHIPPED

*2026-07-22. First C++ build of the T6 programme (`tf24-v2-T6-newton-uptake-BUILD-SPEC.md`
Slice 1). Replaces the golden-section search (GSS) in `Leaf::find_root_collar_psi` with a
safeguarded superlinear root-find on the existing exact analytic gradient. plant
`5a48347b`.*

## What changed

Control key `newton_collar_solve` (OFF by default). When ON, the profit-maximising
collar potential over the feasible interval `[bound_a, bound_b]` is found by root-finding
`dprofit_droot_collar_psi == 0` with `util::uniroot_smooth` (TOMS748), instead of GSS on
profit. Endpoint-sign safeguard: interior optimum = the sign-change root (gradient +ve at
`bound_a`, −ve at `bound_b`); when the gradient is one-signed across the bracket the maximum
is at the profit-increasing boundary, so clamp there. The solve is bracketed by the same
`prepare_collar_solve` interval, so it can never leave the feasible region.

**Design note (upward challenge to the spec's "Newton"):** the spec said "safeguarded
Newton". The wanted *outcome* — converge the interior optimum superlinearly from the
analytic gradient, safeguarded — is delivered by the existing TOMS748 wrapper (already
trusted for the two sibling leaf root-finds `psi_stem_to_ci` and `find_root_psi`, per the
history note in `uniroot.h`) with **zero new machinery**. A hand-rolled Newton would need a
second derivative we don't have analytically (→ FD noise through the gradient, the exact
failure mode the T6 spec warns against). TOMS748 on the analytic `g` needs only `g` evals
and stays inside the bracket. The flag keeps the "newton" name for consistency with the T6
programme vocabulary; the code comment states the accurate mechanism.

## Acceptance (spec §2 Slice 1, §3)

| criterion | result |
|---|---|
| **bit-identical OFF** | else-branch is the verbatim GSS call; `test-strategy-tf24.R`, `test-tf24-shutdown.R` green |
| **ON matches OFF (converged-J tol)** | max rel **6.8e-4** across intense_storms, whiplash, extended_drought, dry_to_wet — ≪ the ~2.3% two-refined-mesh gap |
| **fewer evals / faster** | intense_storms 12yr **111.0s → 92.3s = 1.20×** whole-solve (per-eval win larger; leaf solves are a fraction of total wall-clock) |
| **J(τ) flip gone** | the argmax is no longer quantized at `GSS_tol_abs` — the 6.8e-4 OFF/ON gap *is* that quantization being removed. A full τ-sweep confirmation is deferred to Slice 4, where mesh/τ convergence is the explicit subject (and where T3 says the dominant τ-sensitivity is field-shift, not this artifact). |

Per-scenario ON vs OFF offspring:

| scenario | OFF | ON | rel |
|---|---|---|---|
| intense_storms (12 yr) | 2.725233e-07 | 2.726975e-07 | 6.39e-4 |
| whiplash (12 yr) | 1.412017e-07 | 1.412461e-07 | 3.14e-4 |
| extended_drought (20 yr) | 1.391352e-06 | 1.391467e-06 | 8.21e-5 |
| dry_to_wet (12 yr) | 1.056882e-07 | 1.057604e-07 | 6.83e-4 |

## Why this is a standalone win

The gradient root-find is a per-eval improvement independent of the macro-step (Slices
3–4): it cuts the dominant O(M) leaf-solve cost today, and removes the GSS_tol_abs argmax
quantization. It is also the foundation the rest of T6 stands on — Slice 2 (analytic
∂a/∂u) reuses the same IFT-at-the-operating-point that this Newton root now lands on
exactly.

## Scripts
- `scripts/tf24-benchmarks/newton_collar_validate.R` — ON vs OFF offspring across the bank.
- `scripts/tf24-benchmarks/newton_collar_timing.R` — whole-solve wall-clock OFF vs ON.

## Next (Slice 2, per spec)
Analytic `∂a/∂u` as a member-loop byproduct, **offline-gated** against central differences
(must agree ~1e-4 incl. the dry tercile) BEFORE any macro-step wiring.
