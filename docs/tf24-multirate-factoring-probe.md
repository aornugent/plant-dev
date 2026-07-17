# Coupling-factoring (#1) — scrappy probe findings

*Lean R-level probes against the real `plant` TF24 patch, before locking the #2 in-solver
design. Scripts: `scripts/tf24-multirate/factor_probe{,2,3}.R`.*

Goal of #1: split the expensive patch RHS into a **slow** piece (freeze across the macro step)
and a **fast, cheap** piece (run in the soil sub-cycle). Three probes, three findings — the
first two overturn the assumption the plan was built on.

## Probe 1 — where is the cost? (`factor_probe.R`)

Full `patch$derivs` = `compute_environment()` (light-field scan) + `compute_rates()` (per-cohort
physiology → `resource_depletion` → soil balance). Timed separately vs cohort count:

| ncoh | derivs (ms) | compute_environment | compute_rates |
|--:|--:|--:|--:|
| 5  | 0.18 | 30% | 94% |
| 20 | 0.56 | 11% | 95% |
| 80 | 1.99 | 2%  | ~100% |

**The light-field scan is cheap and ~flat; the per-cohort physiology dominates and scales with N.**
This overturns the plan's premise: **freezing the light field saves almost nothing.** The expensive
piece *is* the per-cohort leaf/hydraulic solve — and that solve is exactly the θ-dependent uptake we
wanted to run cheaply in the sub-cycle. So the seam cannot be "freeze light / recompute rates."

## Probe 2 — is uptake(θ) locally linear? (`factor_probe2.R`)

Build a per-macro linearization `U(θ) ≈ U₀ + J·(θ−θ₀)` with the full 5×5 Jacobian (J is mostly
diagonal: diag ~0.93, max off-diag 0.088). Test against true uptake over a day's drying:

| test θ | rel err |
|---|--:|
| uniform −0.02 | 1% |
| uniform −0.05 | 15% |
| top layer −0.08 | **440%** |
| graded (top drier) | **370%** |

**A per-macro linearization fails** for realistic drying — uptake(θ) is strongly nonlinear
(stress-shutdown thresholds, layer switch-off — the "hard events" from the gap analysis).

## Probe 3 — a cheap separable nonlinear surrogate? (`factor_probe3.R`)

Per-layer nonlinear response curves `Uᵢ(θᵢ)` (others held at θ₀), 8 points/layer = 40 physiology
evals/macro:

| test θ | abs err | rel err |
|---|--:|--:|
| uniform −0.05 | 0.033 | 7% |
| top layer −0.08 | 0.064 | 69% |
| graded | 0.066 | 61% |
| graded ×2 | 0.76 | 12% |

**Still fails.** Drying one layer changes the *others'* uptake (nonlinear cross-coupling), which a
separable model misses. Even 40 evals/macro leaves abs errors ~0.06–0.76.

## Conclusion — what this means for #2

**No cheap parametric surrogate of uptake(θ) is viable.** The cohort→soil coupling is a genuinely
coupled, nonlinear, non-separable function of the full soil-moisture vector, computed by the
per-cohort hydraulic solve — which is the dominant cost. The plan's "aggregate surrogate, freeze the
light field" route is dead for real TF24.

The remaining levers for #2 (in rough priority):

1. **Warm-start the per-cohort hydraulic solves across soil sub-steps.** The collar-potential root
   and cᵢ co-limitation solves are *iterative*; between soil sub-steps θ changes little, so seeding
   each solve from the previous sub-step's solution should cut it to 1–2 iterations — making an
   *exact* uptake refresh cheap without any surrogate. This is the most promising route and preserves
   correctness. **Next probe:** instrument the leaf-solve iteration counts in C++ under warm vs cold
   start (R-level can't see solve iterations).
2. **Stiff soil sub-stepper** (implicit/Rosenbrock on the 5 soil states) to cut the *number* of soil
   sub-steps, hence the number of (necessarily θ-tracking) coupling refreshes. Reduces the fast-side
   demand rather than the per-refresh cost.
3. **Reconsider the win altogether.** If uptake must be re-evaluated ~every soil sub-step and it
   dominates cost, multi-rate offers little for TF24 as structured — unless (1) lands. The honest
   framing: the multi-rate benefit hinges on making the *exact* physiology refresh cheap
   (warm-start), not on approximating it away.

Design-level takeaway: **lock #2 around a warm-started exact uptake refresh, not a surrogate.**
