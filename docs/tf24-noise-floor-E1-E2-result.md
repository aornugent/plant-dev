# Oracle noise-floor hypothesis — E1/E2 test result

*Triage of `docs/oracle-consultation-intrinsic-characterisation-response.md`
(2026-07-20) under consult-guide §7: reduce every claim to the cheapest
falsifiable test, run it before building. The Oracle proposed its own tests
E1/E2/E3; we ran E1 and E2. Scripts: `scripts/tf24-benchmarks/noise_floor_E1.R`
(+ `_E1b_peak.R`), `noise_floor_E2.R`. Data: `results/noise_floor_E1*.rds`,
`results/noise_floor_E2_bank.csv`. Zero production changes — `GSS_tol_abs` is a
`control()`/ctor field.*

## The claim

The fixed-tolerance golden-section argmax `p* = argmax profit(collar_psi)`
(`Leaf::find_root_collar_psi`, `util::golden_section_max`, `GSS_tol_abs=1e-3`)
carries a resolution floor `ε_p ~ (b−a)·φ⁻ⁿ ≈ GSS_tol_abs`. The Oracle argued
this puts a **tolerance-independent noise floor** into the RHS, that the embedded
RKCK controller bisects against it, and that this — not any event — produces the
27–35 % rejection waste and the min-h wall. Proposed fix **F1**: replace the
search with a Newton polish on `∂P/∂p = 0` behind an implicit-function node.

## Verdict

**Mechanism CONFIRMED at the source (E1), REFUTED at the solver level (E2).**
The floor is real and scales exactly as predicted, but it is *not* what drives
the rejection fraction or the min-h wall. The proposed fix F1 is additionally
**not well-posed**, because the optimum is a **corner, not a smooth interior
max**. A separate, genuine finding fell out: the floor corrupts **offspring/J**
in bifurcation-prone scenarios.

## E1 — leaf-level: the floor exists and scales as predicted (P1, P2 ✓; P3 ✗)

Sweep one soil-moisture input finely; measure each output's deviation from a
near-exact reference run (`GSS_tol_abs=1e-8`) vs `GSS_tol_abs ∈ {1e-3, 2.1e-5,
4.5e-7}`. Log-log slope of floor vs tol:

| quantity | slope | prediction | result |
|---|---|---|---|
| argmax (`root_collar`) | **1.10** | P1: ~1 (`ε_p ~ tol`) | ✓ confirmed |
| `assim` (non-stationary → growth g) | **1.01** | P2: ~1, O(ε) | ✓ confirmed |
| `profit` (stationary objective) | **1.06** | P3: ~2, O(ε²) envelope | ✗ **refuted** |

P1/P2 are the load-bearing solver claims: the argmax and the RHS ingredients it
feeds carry an O(ε) floor set by `GSS_tol_abs`. **Confirmed.** But P3 — the
envelope asymmetry the Oracle called "the sharpest tell" — fails: the objective
is O(ε), not O(ε²).

## E1b — why P3 fails: the optimum is a CORNER, not a smooth max

Mapping the objective `g(p)` finely across its peak (`evaluate_root_collar_psi`)
at a fixed state shows an asymmetric peak: a near-vertical left wall (a jump of
~1.5, "slope" +500→+5e4 as the offset shrinks) meeting a gently-sloping smooth
right branch (slope −8.8, constant). The argmax is the **corner** at the top of
the wall — the left end of a monotone-decreasing smooth branch, ~0.01 MPa above
the wet feasible boundary `bound_a = −root_zero_E`. Confirmed across wet→dry
regimes (`corner_bank.R`): cliff-left when wet, a flat-left/steep-right kink when
drier — never a smooth interior stationary point.

Consequences:
- **Explains E1's profit slope-1 exactly.** No stationary point ⇒
  `profit(p̂) − profit(p*) ≈ (−8.8)·(p̂−p*) = O(ε)`. The envelope theorem never
  applied.
- **F1 is not well-posed.** There is no interior point where `∂P/∂p = 0`, and
  `P_pp` is undefined at the corner, so "Newton on `∂P/∂p=0` + IFT node on
  `P_pp`" has no root to find and no valid adjoint denominator. Any inner-solve
  fix must **locate the corner** via its smooth defining (constraint-activation)
  condition, not a stationarity condition.
- Two facts the consult didn't have: an **exact analytic gradient**
  `Leaf::dprofit_droot_collar_psi` already exists (IFT + forward-AD, not the
  envelope-FD the Oracle assumed); and `profit_at_collar_psi` **clamps** the
  target into `[bound_a, bound_b]` (#530), degrading to a one-sided difference at
  the boundary.

## E2 — solver-level: the floor does NOT drive the rejections (the decisive test)

The Oracle's own E2: rerun the bank at tightened `GSS_tol_abs`, same outer
tol=1e-6. Prediction: reject fraction collapses, min-h rises, J unchanged. If
invariant → "the mechanism is refuted." Full bank, 12 yr, `GSS_tol` 1e-3 vs 1e-6:

| scenario | reject @1e-3 | reject @1e-6 | min-h (both) |
|---|---|---|---|
| intense_storms | 0.286 | 0.298 | 3.65e-4 d |
| extended_drought | 0.277 | 0.273 | 3.65e-4 d |
| whiplash | 0.281 | 0.278 | 3.65e-4 d |
| dry_to_wet | 0.307 | 0.304 | 3.65e-4 d |
| long_horizon | 0.205 | 0.204 | 3.65e-4 d |

**Reject fraction is invariant to a 1000× inner-resolution change in every
scenario.** By the Oracle's own criterion, the noise-floor mechanism is
**refuted at the solver level.**

The min-h "wall" is a **config artifact**: `3.65e-4 d = 1e-6 yr = exactly
`control$ode_step_size_min`` (`control.cpp:52`; clamp at `ode_control.hpp:94`),
identical in all runs. The "resolution limit, not stability limit" the Oracle
recalled from two rounds ago is neither — it is a hard-coded `hmin`.

Why the source floor doesn't reach the controller: it is a *deterministic*
function of state (same y → same f), so its systematic contribution largely
cancels in the embedded difference `y5 − y4` across stages; and empirically,
driving the floor below the outer tol (GSS=1e-6) changes nothing. The 27–35 %
rejection is genuine adaptive-controller behaviour on the coupled system, not
bisection against the inner floor.

## New finding — the floor corrupts J at survival thresholds (accuracy, not speed)

E2 flagged whiplash offspring changing 2.4× between `GSS_tol` 1e-3 and 1e-6.
Convergence sweep (`whiplashJ`, 12 yr, outer tol=1e-6):

| GSS_tol | offspring |
|---|---|
| 1e-3 (production default) | 1.412e-7 |
| 1e-4 | 5.90e-8 |
| 1e-5 | 1.413e-7 |
| 1e-6 | 5.871e-8 |
| 1e-8 | 5.868e-8 |

Non-monotone, converging to ≈5.87e-8 only for `GSS_tol ≤ 1e-6`. The production
default **1e-3 gives a 2.4× wrong J** in whiplash. This is a **survival-threshold
bifurcation**: a marginal cohort's fate flips with the sub-1e-3 argmax floor —
the "J is ~10× hypersensitive" phenomenon made concrete. You cannot tighten your
way out reliably (non-monotone); the corner-floor jitters a discrete survival
decision. This is an **accuracy (J) cost**, orthogonal to the (refuted) speed
claim, and it is the one place the inner search demonstrably matters.

## What this means for the build

- **Do NOT build F1 as posed** (Newton on `∂P/∂p=0` + IFT node) — ill-posed at a
  corner, and E2 shows it would not cut the rejection waste anyway.
- **The 27–35 % rejection / min-h wall is not the inner search.** It is intrinsic
  adaptive-controller behaviour plus a config `hmin`. Raising `ode_step_size_min`
  scrutiny or the controller's accept logic is a separate question; the inner
  search is not the lever for speed.
- **The live lever is J accuracy at survival thresholds.** Two candidate
  directions, both to be scoped with system-design before any build:
  1. **Smooth the corner** so outputs are C¹ in state and the survival boundary
     is crossed smoothly (a model-representation change — the corner is a real
     constraint-activation kink, not numerical noise). This is the only thing
     that removes the *non-monotone* J jitter.
  2. **Converge the inner search where J is bifurcation-sensitive** — a corner
     locator (root-find on the constraint-activation condition to machine
     precision, with an IFT node on that condition, not on stationarity). Gives
     exact `p*` and a clean adjoint; discharges the §6.6 gradient concern on the
     *constraint* equation. Cost per RHS is a few evals; E2 says it buys no speed,
     but it buys J correctness in whiplash-class runs.
- **E3 (noise-aware controller) is moot** — there is no controller-visible floor
  to be aware of (E2).

## Files

- `scripts/tf24-benchmarks/noise_floor_E1.R` — leaf floor vs `GSS_tol_abs` (P1/P2/P3).
- `scripts/tf24-benchmarks/noise_floor_E1b_peak.R` — objective peak geometry (corner).
- `scripts/tf24-benchmarks/noise_floor_E2.R` — full-bank reject-fraction vs `GSS_tol_abs`.
- `results/noise_floor_E1*.rds`, `results/noise_floor_E2_bank.csv`.
