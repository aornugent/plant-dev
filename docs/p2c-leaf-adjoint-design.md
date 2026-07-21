# P2c — the TF24 leaf adjoint (design)

_System-design search, 2026-07-20. Records the decision so the next session starts
from the map, not a blank page. Companion: `build-plan.md` P2c; `ad-touchpoint-audit.md`
(TF24 Certificate A); plant#60 (the corner)._

## The problem in one paragraph
TF24's growth rate reads a leaf whose operating point is found by a 3-deep nested
double solve — outer golden-section max of profit over collar potential `p*` → mid
`find_psi_stem_from_psi_root` inversion → inner `psi_stem_to_ci` uniroot (the
ci/assimilation branch). The whole `Leaf` (`leaf_model.cpp`, 1490 lines) is `double`;
the only reverse-tape path is an FD `supplied_derivative` seam that central-differences
`leaf_profit_at_fixed_collar` at frozen `p*`. In the soil-coupled patch the operating
point sits on a **fold** of the inner ci root-find (plant#60: profit jumps ~1.5 at `p*`,
`∂P/∂p ≈ −8.8 ≠ 0`); the seam finite-differences across that jump, giving partials
≈ jump/step ≈ 1e6 that accumulate through the SCM reverse sweep to ~1e25–1e32. The
single-plant gate0 (fixed environment, away from the corner) is green — the blow-up is
corner-specific, not a leaf-algebra error.

## Triage: 3
Module boundary (the leaf adjoint), expensive to reverse, external consumer (plant#60),
requirements arrived as solution-verbs. Full procedure + framing moves.

## Requirements ledger
- **R1** — TF24 resident reverse gradient is finite and correct: reverse-AD matches the
  re-optimising FD (E4) on every nonzero-fd leaf to ~1e-3 rel, at a real soil-coupled
  patch. Today ~1e25–1e32 vs O(1–1e5).
- **R2** — the gradient carries the plant#60 term: at the fold, `dp*/dstate` flows, so
  the value/growth channel is first-order right. The O(1) E4 gap closes to the FD floor.
- **R3** — DX: net concept count drops. Deletes ~300 lines of hand-adjoint (the FD seam +
  `leaf_profit_at_fixed_collar` + `dprofit_droot_collar_psi` +
  `dsoil_consumption_dpsi_collar_perlayer`). New names must retire more than they add.
- **R4** — no regression: double path bit-identical; per-`compute_rates` leaf cost
  ~unchanged (called per node per step — many cheap solves).

**Scarce resource:** tape cleanliness under a non-smooth inner solve. The operating point
is on a branch-death fold; any derivative mechanism that lets the iteration *or* a finite
difference evaluate across that fold produces the blow-up. The scarce thing is a
derivative path that never evaluates across the corner.

## Candidates
- **A [first thought] full templating** (brute force): `Leaf<S>` end-to-end, solvers in
  `S`. Rejected — the golden-section/uniroot comparisons branch on active values, so the
  fold branch-switch lands on the tape and the blow-up returns by another route; plus a
  huge per-solve tape (fails R4).
- **B evaluate-at-converged-point + IFT nodes** (move #2, record→replay): leaf solver
  stays `double`; `S` is carried only by the closed-form output map and by each solved
  root as an `implicit_value` node reading active inputs. Pays R1+R2 (fold node carries
  `dp*/dstate`; no FD, no iteration on tape) and R3. **Winner.**
- **C soil-active, leaf via corrected seam** (move #1, weaken): keeps the seam with
  analytic partials. Rejected — seam survives, per-input hand-partials survive (fails R3).

## The commitment
**The leaf solver runs in `double`; `S` is carried only by the closed-form output map and
by each solved root registered as an `implicit_value` node — so no iteration and no finite
difference ever evaluates across the fold.**

**Kept true by structure:** `util::golden_section_max` and `util::uniroot_smooth` are
declared on `double` (double lambdas → double). An active scalar cannot pass through them —
the iteration physically cannot reach the tape. The only `S`-typed entry points are the
templated output functions and the `Equation` handed to `implicit_value`. Taping the
iteration is inexpressible without changing solver signatures.

## Kill question
Assumption whose falsity kills B: the fold locus `p*(state)` is smooth. #60 measured it
linear to the τ-floor, slope −1.0004, residual ≈ τ — the objective is non-smooth at the
corner but the locus is smooth, the exact well-posedness condition for the bordered-fold
IFT. **Survives.**

## The primitives (swept 2026-07-20 — all exist, no odelia change needed)
- `implicit_value<S>(double y_star, Equation&& F)` — `F(S y)` reads active inputs from
  scope; returns `y*` bit-identical, `dy*/dp = −(dF/dp)/(dF/dy)`; `dF/dy` is a **double
  central difference at `y*`**. Fit for N_ci, N_psistem.
- `register_implicit<S>(F, solve, p, denom_sign)` — explicit active-pointer vector;
  forward-diffs F per input, asserts `dF/dy` sign, injects via `supplied_derivative`.
  First-order only.
- `incomplete_gamma<S>(a, x)` — P1c; the vulnerability integral's `S` closed form.

## Two refinements the sweep forced
1. **The fold breaks a naïve `implicit_value`.** Its denominator is `dF/dy` by FD at `y*`;
   at the fold `dF/dci → 0` by definition, so `implicit_value` on the ci-residual with
   `y=ci` divides by ~0 and the blow-up returns. **N_p\* must be `implicit_value` on the
   branch-death condition `g(p*) = ∂F/∂ci = 0`**, whose denominator `dg/dp*` is regular
   (−1.0004). This needs `g = ∂F/∂ci` as an `S` closed-form.
2. **The reset-timing contract, with a TF24 twist.** `rebind_from` widens `field_ptrs()`
   params but leaves precomputed state for `prepare_strategy()` to rebuild post-seed
   (`patch.h:310` `reset()`), else parameter-derived precompute severs. FF16 keeps that
   precompute in the templated strategy. **TF24's lives in the double `Leaf`**
   (`set_physiology`, the `transpiration_from_psi` / `root_vuln_integral_from_psi`
   splines), which by the commitment stays double — so `prepare_strategy` cannot re-derive
   it in `S`. Therefore **any seeded param reaching the operating point through a spline —
   the vulnerability curve via `root_b`/`root_c`; the transpiration relation via
   `b`/`c`/`K_s` — must be re-expressed analytically in `S`** in the output map/residuals
   (this is what `incomplete_gamma` is for). The double splines survive only as the
   value-path fast lookup; the active path never reads them for a seeded-param derivative.

## The step-4 fork (decided)
`N_p*` is built as a **regime-detector fold node on the existing golden-section solver**:
the double solve returns `p*` clamped to the feasible interval `[bound_a, bound_b]` from
`prepare_collar_solve`. **`p*` interior ⇒ stationarity IFT (`∂profit/∂p*=0`); `p*` on the
boundary (`= bound_b`, the branch-death edge) ⇒ the fold IFT `g(p*)=∂F/∂ci=0`.** Whether
`p*` sits at a bound is the structural form of #60's "branch-indicator". Not taking #60's
Newton-on-`g` reformulation now (that is the Kill condition below — it would retire the
detector).

## What survives deletion
- `implicit_value` nodes **N_ci, N_psistem, N_p\*** → R1/R2: each solved root's derivative.
- the `S`-templated output map (assim/cost/profit/stom-cond + `incomplete_gamma` uptake) →
  R1: outputs consumed by `net_mass_production_dt` must depend on active inputs.
- the **feasible-interval regime detector** (interior vs `bound_b`) → R2: selects
  stationarity- vs fold-IFT. The one genuinely new concept; earns its place as the
  structural #60 branch-indicator.
- everything in the seam → **deleted** (R3).

## What this settles
- No `Leaf<active>` instantiation ever exists; the 1490-line solver is never templated.
- The blow-up state (FD across the fold) cannot occur — no FD, no active iteration.
- TF24f reuses the same nodes (its tracked-`q` `G` is the same `dp*/dstate`) — no parallel
  machinery.

## What this makes hard
- A new leaf output that isn't a closed form of the converged roots needs its own node.
- Deep-crown (multi-`single_solve`) shading stays `util::stop`-ped (as today); B doesn't
  wire it.
- A higher-codimension corner (two branches dying at once) breaks the single-fold node —
  no witness today; would need a third detector case.

## Kill condition
If the inner ci solve is reformulated so the operating point becomes a genuine interior
optimum (#60's bonus: Newton-on-`g`, retiring the branch switch), the fold node collapses
to plain stationarity and the regime detector becomes dead weight — hands to an
"all-interior" variant.

## Worklist (ordering: 0 → 1 → 2/3/4 → 5 → 6 → 7)
0. **env-soil-config double→active crossing** (task #24) — else the `scm_jacobian` R5
   assert trips on any TF24 gradient.
1. **`S`-template the leaf output map** — assim (colimited/rubisco/electron/electron_transport/
   arrhenius), `hydraulic_cost_TF`, `profit_psi_stem_TF`, `stom_cond_CO2`, and the soil
   uptake as an `incomplete_gamma<S>` closed form. Replace param-dependent spline
   *relations* with `S` closed-forms (Refinement 2). The bulk of the work; FF16/K93
   already exercised the mechanics.
2. **N_ci** — `implicit_value` on the ci residual (`assim_minus_stom_cond_CO2 = 0`).
3. **N_psistem** — `implicit_value` on the transpiration inversion
   (`transpiration(psi_stem) − E(collar) = 0`).
4. **N_p\*** — regime-detected: interior ⇒ `∂profit/∂p*=0`; on `bound_b` ⇒ bordered-fold
   `g(p*)=∂F/∂ci=0`, `dp*/dstate = −g_state/g_p`. The hard core; `g` is an `S` closed-form
   of `∂F/∂ci`.
5. **soil active coupled state** — the `psi_soil` the leaf reads is the active soil ODE
   state; the `∂/∂ψ_soil` channel flows through N_p\* + the output map.
6. **delete** the FD seam + `leaf_profit_at_fixed_collar` + `dprofit_droot_collar_psi` +
   `dsoil_consumption_dpsi_collar_perlayer` (R3).
7. **gate** — rebuild Certificate B for TF24 (`scratchpad/tf24_cert.R`, driver committed):
   all leaves intact, E4 gap closed. Then P2d (TF24f) reuses N_p\*.

---

# Addendum — the environment as a differentiation source (step 0, expanded)

Step 0 was originally scoped as a passive config crossing (fix the R5 assert). It is
expanded here: the environment becomes a **differentiation source** — its physical soil
params and its soil-water ODE state become seedable AD inputs.

## The shape (Pólya, two witnesses: strategy + environment)
The environment is made differentiable by the *same* mechanism a strategy already uses —
not a new concept. The `double`/passive-env special case dies.
- **Promote the four rate-path physical soil params to `S`** — `soil_moist_sat`, `K_sat`,
  `a_infil`, `b_infil` — in an `ENV_AD_FIELDS` X-macro with `field_ptrs()` (mirrors
  `TF24_AD_FIELDS`). `a_psi`/`n_psi` are skipped (marked "not currently used", not on the
  rate path — no witness). `soil_number_of_depths` stays passive (discretization, never a
  gradient). `depth` stays passive for now (moving-mesh derivative — **plant#64**).
- **`Environment::ad_parameters()`** → the promoted params; **`Environment::ad_initial_state()`**
  → the soil-water state handles (first `soil_number_of_depths` entries of `vars.states`).
- **`Patch::ad_parameters()`** = `[species₀..speciesₙ params, env params]`;
  **`Patch::ad_initial_state()`** = `[env soil-state layers]` (replaces the `{}` stub).
- **Crossing:** `rebind_from` widens the promoted params (`double`→`S`, via `field_ptrs`);
  `copy_config_from` crosses `soil_number_of_depths` + the grid (`z`/`z_mid`/`dz`) + `depth`
  as passive config.

## The one new invariant — the flat index contract
`DifferentiationTargets` column order (AUTODIFF: params-then-ics) becomes, for a Patch:
`params = [species params…, env params…]`, `ics = [env soil-state layers…]`. Documented at
`Patch::ad_parameters`/`ad_initial_state` so a name→index resolver cannot transpose columns
silently. This is the only genuinely new concept the addendum adds; it is the composition
rule for two param sources, held by the concatenation order in one place.

## Why this fits the commitment
It reuses `PLANT_DIFFERENTIABLE` / `rebind_strategy_fields` / `field_ptrs` wholesale — the
env stops being a special case, a net concept reduction. The soil state is already `S` and
already in the SCM ODE system (`ode_size = node_ode_size + environment.ode_size()`), so the
IC path is exposing existing state as seedable, not new integration.

## Verify
Soil-state IC gradient and the soil-param gradients vs a re-optimising FD on a real
transpiring patch (same E4 discipline as the leaf) — but this is only meaningful once the
leaf adjoint (steps 1–6) lands, since the reverse pass still routes through the leaf FD
seam and blows up. What step 0 *can* verify now (and does), independent of the leaf:

- **Composition** — `Patch::ad_parameters()` = 58 (52 strategy + 6 env), `ad_initial_state()`
  = 5 soil layers. ✓
- **Crossing correctness** — the crossed active env is **bit-identical** to a fresh default
  env in every config member (all six params, per-layer soil water, `n_layers`, residual). ✓
- **R5** — `scm_gradient` for TF24 targeting an env param no longer trips the R5 assert
  (the crossed active value reproduces the double reference); tested at short lifetime so
  the reverse tape fits (the gradient value is still garbage — the leaf seam, steps 1–6). ✓
- **No regression** — FF16/K93 entry gradient + census-vector tests stay green after the
  shared `SCM::rebind_from` / base `Environment_` / `Patch::ad_parameters` changes. ✓

(An earlier "0.17% crossing discrepancy" was a flawed reference — a fresh SCM pinning only
L1 onto the *unrefined* L0 — not a crossing bug; the direct config comparison settled it.)
