# Re-characterizing the TF24 cost problem on the *real* coupled patch (not the surrogate)

*Measured on the real `Solver<Patch<TF24,TF24_Environment>>` SCM, semi-arid/monsoon variable
rainfall, with the `patch_rhs_calls` counter. Corrects the surrogate-based framing that drove the
multirate effort and every Oracle round.*

## Why the surrogate (#43, `tf24-rodas-multirate.md`) misled

#43 diagnosed the soil subsystem and a **linear-relaxation surrogate canopy** (`dx_k/dt = α_k(S̄−x_k)`,
coupling = a cheap mean of θ). Two things that surrogate abstracted away are exactly what governs the
real cost:

1. **The coupling is the expensive part, and it is state-dependent.** Real uptake
   `a_ℓ(θ) = Σ_j ρ_j c_ℓ(cohort_j, θ, p_j)` is an O(N) sum over per-cohort physiology solves (each a
   hydraulic solve + a root-collar-potential **argmax**), and it depends on θ. The surrogate's coupling
   was a free mean. → the multirate "cost flat in M" was an artifact of a free big block; the real fast
   sub-cycle re-pays the O(N) physiology every micro step (measured 6–25× slower than global RK).
2. **"Accuracy not stiffness" was measured soil-only.** It happens to hold on the coupled system too —
   but the real step-limiting feature is neither storm-front accuracy nor stiffness; see below.

## What actually stresses global RK (all measured on the real coupled patch)

- **Per-cohort physiology dominates (O(N) per RHS eval).** 95–100% of an RHS evaluation is the N cohort
  solves. Total cost ≈ (RHS evals) × O(N).
- **Node volume grows cost ~N^1.4.** RHS-eval count grows ~N^0.4 (81→324 cohorts: 13.1k→23.9k evals),
  per-eval cost is O(N); wall time 25s→183s (N=81→324) at τ=1e-6.
- **The tight-tolerance "wall" is a localized non-smoothness (kink), NOT stiffness.**
  - Softening the soil exponent n_ψ 6.57→4→2 (drainage exp 16→7; retention less singular) does **not**
    clear the τ=1e-8 wall → not the drainage/matric-potential stiffness or singularity.
  - Shrinking `h_min` 1e-6→1e-9 **clears** the wall (identical evals at 1e-9 and 1e-12) → a smaller
    *explicit* step suffices → resolution of a near-kink, **not** a stability limit.
  - The controller needs h ~1e-9 yr (~0.03 s) at isolated points: the signature of the per-cohort
    control **argmax** (`find_root_collar_psi`, non-smooth in θ) and/or cohort-introduction/clamp
    transients. Implicit and multirate are both irrelevant to a kink.
- **J converges by τ=1e-6** (offspring bit-stable 1e-6↔1e-8); tighter tol buys no J change and only hits
  the kink wall, at 47× the cost. So the wall is *past* the accuracy anyone needs.
- **RODAS cannot even run on the real patch** (`method='rodas' is not available` — it needs an AD
  Jacobian the double-only patch can't supply). So #43's "RODAS doesn't help" was *only* ever tested on
  the soil-only/surrogate system; the stiffness hypothesis was never testable on the coupled patch — and
  the proxy tests above say it isn't stiffness anyway.
- **Rainfall sequence** (semi-arid vs monsoon): near-identical step counts (~13k at τ=1e-6), both fine
  at 1e-6, both hit the kink wall at 1e-8. Storm intensity is not the discriminating stressor.

## Corrected verdict

The stepper is **not** the lever, and the reason is not the one the surrogate gave:
- No stiffness → RODAS/IMEX irrelevant (and unavailable).
- The step count is set by genuine structure + a J-irrelevant control kink → global explicit RK is
  already near-optimal on steps at the accuracy J needs (τ=1e-6, ~13k evals, 25s at N=81).
- The dominant, *reducible* cost is the **per-RHS O(N) cohort physiology**, which every ODE method pays
  equally. Multirate re-pays it more often; it cannot help.

**The real levers are on the RHS-evaluation cost, not the ODE integrator:** reduce the per-cohort
physiology cost (collocation — refuted on accuracy for the evolved distribution; setup-cache reuse of
the θ-dependent per-cohort prep; a batched/SoA physiology kernel) or reduce RHS-eval count by removing
the control kink (event-handle it, or replace the argmax with a smooth tracked control — the TF24f
variant). None of these is a decomposition of the ODE; the whole multirate framing was aimed at the
wrong object.
