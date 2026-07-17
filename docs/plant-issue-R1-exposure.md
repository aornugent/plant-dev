# READY-TO-FILE ISSUE for aornugent/plant (could not be filed from this session — out of scope)

*This is a standalone issue drafted for **aornugent/plant**. The session's GitHub scope is limited to
`aornugent/plant-dev` and `aornugent/odelia`, so it could not be created directly. File it verbatim on
aornugent/plant (or add the repo to a session and use the GitHub tools). Companion to
`docs/tf24-multirate-engine-port-spec.md` §6.*

---

**Title:** Expose TF24 soil RHS as {analytic drainage flow + residual coupling} for the multirate splitting inner-stepper (R1), plus the coupling-factoring seams

**Body:**

## Why

The odelia TF24 multirate engine (design consolidated in plant-dev `docs/tf24-multirate-engine-port-spec.md`; public synthesis at traitecoevo/odelia#38 → aornugent/odelia#43) needs plant to expose the TF24 soil coupling in a factored form. This issue captures those **plant-side exposures**. The headline is **R1** — split the soil RHS so the stiff, singular drainage term can be integrated *exactly* by a Strang-splitting inner stepper — because it is (a) the biggest single stability/performance win and (b) **independently valuable to single-rate soil integration**, so it can and should land on its own, ahead of the engine port.

None of this changes TF24 results: R1 is a numerically-exact reformulation of the same physics; the other seams are read-only factorings of the existing coupling.

## R1 (primary) — split the soil RHS; expose the analytic drainage flow

TF24 gravitational drainage is, per layer, a scalar power-law loss
`wout_ℓ = K(θ_ℓ) = K_sat·(θ_ℓ/θ_sat)^{2n_ψ+3}`, and the drainage-only ODE `θ̇ = −c·θ^p`
(`p = 2n_ψ+3 ≈ 16.14`, `c = K_sat/(dz·θ_sat^p)`) has a **closed-form, positivity-preserving flow**:

```
θ(t) = [ θ0^{1−p} + (p−1)·c·t ]^{−1/(p−1)}
```

Verified against a tight RK integration to ~1e-13 and positivity-preserving by construction (never < 0),
so it removes the explicit-stepping positivity clamp for the drainage term. **Requirements:**

1. Expose the soil RHS as two callable pieces (behind whatever `System`/`Environment` seam is cleanest):
   - `analytic_partial_flow(θ, Δt)` → the exact per-layer drainage recession above (the map, not just the rate).
   - `residual_rhs(θ, resource_depletion, t)` → the rest: infiltration (incl. saturation-excess runoff),
     the inter-layer cascade inflow `win_ℓ = wout_{ℓ−1}`, and root uptake. This is the (gentle,
     non-stiff) part the inner stepper actually steps.
2. Expose the **analytic touchdown time** to the residual bound `θ_res` from the recession (so the
   micro-stepper's contact event is a closed-form root rather than a dense-output root-find).
3. Keep the monolithic soil RHS as-is; the split must reproduce it. **Acceptance test:** a Strang-split
   soil integration matches the current monolithic soil solve across the 5 rainfall scenarios
   (drought→monsoon) to solver tolerance.

Standalone value: this alone removes the wet-end drainage stiffness from *any* soil integration (single-rate
included) and eliminates a non-differentiability, so it's worth landing before the multirate engine exists.

## Accompanying coupling-factoring seams (for the multirate engine)

4. **Factored coupling (`StateView.u()`-style):** per-layer uptake `c_ℓ(cohort, θ, control)` evaluable
   for an arbitrary cohort given the leg-frozen light field — the uptake at the `m` collocation cohorts,
   not only the full-N aggregate `resource_depletion`.
5. **Control derivatives:** TF24f already tracks the collar potential `q` (`dq/dt = k_acclim·dprofit`,
   exact IFT `dprofit_droot_collar_psi`) — reuse it. Additionally expose `∂²P/∂p²` (`P_pp`), needed for
   the control-block collapse and the linearly-implicit stage (closed-form via the same IFT).
6. **Per-cohort feasibility clamp of `q` as an event predicate.** Production `evaluate_root_collar_psi`
   already clamps `q` to the feasible interval (keeps `psi_stem < psi_crit`); expose that boundary as a
   predicate so the engine can treat it as an active event (a freely-evolving `q` otherwise leaves the
   leaf-solve domain at wet/dry extremes).
7. **Setup-cache seam (R5):** the θ-independent per-cohort setup (temperature/photosynthesis Arrhenius,
   electron transport at frozen PPFD) is already memoised; expose a "recompute only the θ-dependent
   soil-side part" entry so the sub-cycle pays only the cheap part per micro-step.
8. **Batched physiology kernel (R5, orthogonal perf):** the `m` per-cohort solves are data-parallel; an
   SoA/SIMD batch kernel (pass-1 in `double`) benefits every caller (SCM, mutant, multirate inner).
   Nice-to-have; independent.

## Scope / notes

- Items 1–3 (R1) are the priority and independently shippable. Items 4–8 are the coupling seams the
  engine consumes; they can follow.
- Design-side detail, measurements, and exact math are in plant-dev
  `docs/tf24-multirate-engine-port-spec.md` §6 and `docs/tf24-reformulations-evaluation.md` (R1 verified
  in `scripts/tf24-multirate/r1_drainage_flow_check.R`).
- We are designing the engine as if R1 will exist; this issue is the contract it will bind to.

---
_Filed from the multirate engine work; see plant-dev branch `claude/tf24-multi-rate-stepper-n5audm`._
