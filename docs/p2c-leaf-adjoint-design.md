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

---

# Step 1 sub-plan — the `S` leaf output map (grounded 2026-07-21)

Concretises worklist step 1 before the diff. Step 1 delivers the **pure `S` output
algebra** and its value-parity gate; it introduces **no IFT node** (steps 2–4) and
**does not yet delete the seam** (step 6). The double solver and the double `Leaf`
value path are untouched.

## Home
The **existing `leaf_model.h`** — templated free functions in a `plant::leaf_output`
namespace, header-inline (no new file; matches the hot-path inline convention,
agents.md §12). Rationale: the commitment keeps the 1490-line `Leaf` in `double`, so the
`S` algebra cannot live on it; free functions taking `(converged roots, active params,
active soil)` avoid a parallel `Leaf<S>` near-copy (AGENTS "no parallel near-copy"), and
placing them in the header (rather than in `tf24_strategy.cpp`) keeps **one** definition
visible to both consumers across TUs — the existing double path
(`leaf_model.cpp::dprofit_droot_collar_psi`) and the active output map
(`tf24_strategy.cpp::net_mass_production_dt`) — and lets TF24f (step 7 / P2d) reuse them.
The two already-templated helpers in `leaf_model.cpp`'s anonymous namespace
(`assim_colimited_ad`, `hydraulic_cost_ad`) **move up into `leaf_model.h`** so the one
definition serves both — no third copy.

## The closed-forms that replace the four splines (Refinement 2)
Verified against `leaf_model.cpp`:
- `proportion_of_conductivity(ψ) = exp(−(ψ/b)^c)` — already pointwise closed-form
  (`:1054`); no spline for the value, only for the *cumulative integral*.
- `Γ(m) ≡ ∫₀^m exp(−(s/b)^c) ds = (b/c)·γ_lower(1/c, (m/b)^c)` — the cumulative
  vulnerability integral (`build_cumulative_vulnerability_integral :1070`), which
  `transpiration_from_psi` / `root_vuln_integral_from_psi` spline. This **is**
  `odelia::incomplete_gamma<S>` (P1c); the double splines survive only as the value-path
  fast lookup.
- `transpiration(ψ_stem, ψ_up) = k_max·[Γ(ψ_stem) − Γ(ψ_up)]` (`:1146`) — a difference of
  two `incomplete_gamma<S>` evals; **no spline**.
- `psi_from_transpiration` (the **inverse** spline, `:1168`) — the one relation with no
  forward closed form. It becomes the **`N_psistem` implicit_value node** (step 3):
  invert `transpiration(ψ_stem) − E = 0` for `ψ_stem`, so no `S` inverse spline is needed.
- **`root_b`/`root_c` are NOT AD-seeded** (fixed doubles, `tf24_strategy.h:441`), so the
  soil-uptake `Γ` carries `S` only through `psi_soil` (soil ODE state) and `P_x_r`
  (collar, from `N_p*`); the root Weibull params stay `double` constants.

## The functions (all `template <class T>`, in `plant::leaf_output`)
Photosynthesis temp params carry `T` through the seeded `vcmax_25`/`jmax_25`:
- `arrh_curve(double Ea, T ref, double leaf_temp)`, `peak_arrh_curve(...)` — `vcmax_`,
  `jmax_`, `gamma_`, `km_`, `R_d_` (the latter three from `double` constants → stay
  `double`; `vcmax_`/`jmax_` become `T`).
- `electron_transport(T jmax, double a, double PPFD, double curv)` (`:1181`).
- `assim_colimited(T ci, T vcmax, T et, double gstar_Pa, T km_or_const, T R_d, double curv)`
  — migrated `assim_colimited_ad` (`:16`), widening the seeded args to `T`.

Hydraulic / conductance / cost:
- `weibull(T psi, T b, T c) = exp(−(psi/b)^c)`.
- `cumulative_vuln(T m, T b, T c) = incomplete_gamma<T>` form of `Γ(m)`.
- `transpiration(T psi_stem, T psi_up, T k_max, T b, T c)`.
- `stom_cond_CO2(T transpiration, double atm_kpa, double atm_vpd)` (`:1172`).
- `hydraulic_cost_TF(T psi_stem, T g1, T beta2, T b, T c)` — migrated `hydraulic_cost_ad`
  (`:24`), Weibull inline.
- `profit_TF(T assim, T cost) = assim − cost` (`:1341`).

Soil uptake (the general + two kink branches of `E_from_Soil_to_Root_Collar :399`) as one
`T` function over layers, mean conductivity from `cumulative_vuln` in the (double) root
params; carries `T` via `psi_soil[i]` and `P_x_r`. Produces `E_up_` (kg) and per-layer
`soil_consumption_` (mol), matching the existing unit split (`:543`).

## What step 1 wires (and what it defers)
Step 1 adds the header + a **value-parity gate only**. It does **not** replace the seam
yet: with the double roots `(ci*, ψ_stem*, p*)` from `find_root_collar_psi`, evaluate the
`S` output map at those roots cast to `S` (`to_passive` round-trip, no active seeds) and
assert it reproduces `leaf.profit_`, `leaf.E_up_`, `leaf.soil_consumption_[]`. This proves
the algebra is a faithful `S` transcription before any node carries a derivative. The
`implicit_value` nodes (steps 2–4) then feed *active* roots into the same functions; the
seam deletion is step 6.

## Verification checkpoints (double path stays bit-identical)
1. **Per-function unit parity (double):** each `leaf_output::f<double>(...)` equals the
   corresponding `Leaf::` method to ~1e-12 at a sampled operating point.
2. **`incomplete_gamma` vs the spline:** `cumulative_vuln<double>` equals
   `transpiration_from_psi.eval` / `root_vuln_integral_from_psi.eval` to the spline's own
   ~100-knot tolerance (the closed form is exact; any residual is the spline's bias, which
   #468 already reduced — this is where a tiny value shift, if any, appears and is bounded).
3. **Assembled value parity:** the `S` output map at the converged double roots reproduces
   `profit_` / `E_up_` / `soil_consumption_` (checkpoint above).
4. **No regression:** FF16/K93 + TF24 double-path suites unchanged (the header is not yet
   on any rate path).

Gate harness: extend `scratchpad/tf24_cert.R` with a `leaf_output_parity` driver reading
an operating-point `Leaf` and comparing. `code-review` over the diff before commit.

## Step 4 grounding — the p\* regime map (2026-07-21, `scratchpad/leaf_pstar_regime.cpp`)
An empirical soil-moisture sweep at the single-leaf operating point (regime detector =
`|Leaf::dprofit_droot_collar_psi(p*)|`; E4 = re-optimising FD `dp*/dtheta`) settles which
IFT regime N_p\* must handle, **before** writing it:
- **Wet (θ ≳ 0.16): interior optimum dominates** (18/24 points). `dprofit/dp* ≈ 0` (±1e-4),
  `p*` and `dp*/dθ` smooth (−40 → −0.03). Stationarity IFT: `G(p*)=dprofit/dp*=0`,
  `dp*/dstate = −(∂G/∂state)/(∂G/∂p*)`. This is the gate0-green case.
- **Transition (θ ≈ 0.12–0.15): BOUND** (3 points) — `p*` pinned at a feasible bound,
  `dprofit/dp*` = 0.9–4.3, `dp*/dθ` spikes to −117/−121/−46. **This is the plant#60 fold /
  b1 regime.** Crucially `dp*/dθ` is **finite** (−120) — the b1 ~1e30 blow-up was the FD
  seam differencing across the profit *jump*, NOT `dp*/dθ` being singular; the exact IFT
  node recovers the finite −120.
- **Dry (θ ≲ 0.11): shutdown** — `dprofit` NA, `dp*/dθ=0` (the `set_shutdown_state`
  early-exits, the continuous `decide()` cases gate0_b verified).
- **Detector works:** interior (`<1e-3`) vs bound (`>0.9`) separate cleanly, so
  `|dprofit/dp*| < tol` selects the regime. N_p\* = interior stationarity node in the common
  case + a bordered-fold branch for the BOUND band; the E4 targets are the `dp*/dθ` column.

## Step 4a — the interior N_p\* node: design + DONE (2026-07-21)
A `system-design` search settled *how* N_p\* computes `dp*/dstate` reverse-differentiably
in state for the interior-stationarity regime (the dominant case per the grounding).

**Decision — implicit_value on a finite-differenced reduced profit** (not a hand-written
reduced gradient). `dp*/dstate = −P_ps/P_pp` (mixed second derivatives). The node is
`implicit_value(p*, F)` with `F(p) = [profit_reduced(p+ε) − profit_reduced(p−ε)]/(2ε)`,
where `profit_reduced<T>(p)` re-solves the double roots off the tape at `p±ε` and assembles
the active outputs from the existing `leaf_output` map + the `N_psistem`/`N_ci` nodes:
- `psi_stem = psistem_node(psi_stem*(p), psi_up=p, E_up(p), k_max, b, c)`,
- `ci = ci_node(ci*(p), vcmax, et, …, gc(psi_stem,p), …)`,
- `profit = assim_colimited(ci,…) − hydraulic_cost_TF(psi_stem,…)`.

XAD then supplies the numerator `P_ps = ∂²profit/∂p∂state` on the reverse tape (the
state-derivative of `F`), and `implicit_value`'s own double central difference supplies the
denominator `P_pp = ∂²profit/∂p²` — so the node returns `p*` carrying `−P_ps/P_pp` with
**no hand-written second derivatives**. The commitment: the derivative path reuses the one
forward algebra (`leaf_output`) and cannot drift from the double `Leaf` (there is no second
calculus copy). Rejected: (a) a hand-written closed-form `G` (a second, drift-prone
transcription — and `dprofit_droot_collar_psi`'s internal forward-AD won't record state on
the reverse tape); (c) promoting to an odelia `stationary_value` primitive (one witness only
— TF24f reuses the *same* leaf node; retrofit trigger: a second argmax on the AD path).

**Only for the interior regime.** At a bound (`|dprofit/dp*|>tol`, the fold band) `p*` is not
stationary; `F(p*)≠0` and the stationarity IFT is wrong there — `dp*/dstate` follows the
bound, `d(bound_b)/dstate`. The `|dprofit/dp*|<tol` detector must route the bound band to the
separate bordered-fold branch (step 4b, still to build).

**Verified — `scratchpad/leaf_pstar_node.cpp` (gate0), two independent channels vs E4**
(perturb the member, re-optimise `p*` at a tightened golden section `GSS_tol_abs=1e-10`,
central difference):
- **k_max** (hydraulic / `psistem_node` channel): node `10917`/`10360` vs FD `10918`/`10364`
  at θ=0.20/0.30 — reld **1.4e-4 / 3.5e-4**.
- **vcmax** (photosynthesis / `ci_node` channel): node `−0.00183` vs FD `−0.00183` (matches to
  all shown digits; the ~2–5e-3 *relative* figure is the E4 FD floor on a near-zero-sensitivity
  channel, not node error).
- `dprofit/dp*≈−1e-7` at both θ confirms the interior regime (detector clean).
- **ε tuning:** the differencing step `ε≈1e-2·(|p*|+1)` is the nested-FD sweet spot — larger ε
  is `O(ε²)` truncation, smaller ε is roundoff (`implicit_value`'s inner 1e-6 amplifies `G`'s
  `~1e-15/ε` noise). At the sweet spot both channels plateau at ~1e-4.

## Step 4b grounding — the BOUND band is a stem-critical root-find, not a bordered-fold
`scratchpad/leaf_pstar_bound.cpp`, θ sweep 0.11–0.16 at a tightened golden section
(`GSS_tol_abs=1e-10`). Two corrections to the design's assumptions:

1. **The BOUND regime is `p* = bound_b = −root_crit` exactly** (`dist(p*, bound_b)=0` across
   θ≈0.125–0.155; `p*` tracks `bound_b` as it moves 6.39→3.08). `bound_b = max(−root_crit,
   −root_psi_crit)` and `−root_crit` is the active bound. **`root_crit` solves
   `E_column(x, psi_soil, psi_crit) = 0`** (`find_root_psi(…,1)`, `leaf_model.cpp:581`) — the
   collar potential at which the **stem reaches `psi_crit`** (its vulnerability limit, the
   branch-death edge). So the bound-regime derivative is `dp*/dstate = −d(root_crit)/dstate`,
   a **plain root-find IFT** — `implicit_value` on `E_column(·; psi_soil, psi_crit, k_max, b,
   c)=0` (`psi_crit` and the soil state are the active inputs) — **NOT** the bordered-fold
   `{F=0, ∂F/∂ci=0}` that Refinement 1 / the step-4 fork anticipated. `E_column`'s `S`
   closed form reuses `soil_uptake` + `cumulative_vuln`, both already in `leaf_output`. This
   is simpler than feared: no `g=∂F/∂ci` closed form is needed.
2. **The detector is "`p*` clamped to `bound_b`", not `|dprofit/dp*|<tol`.** With a tight
   golden section `dprofit/dp*(p*)≈4e-11≈0` *in the bound band too* (the earlier
   "0.9–4.3" figure was an artifact of the loose 1e-3 GSS evaluating the gradient short of
   the bound). The reliable, structural branch-indicator is whether the golden-section
   optimum sits on `bound_b` — which `find_root_collar_psi`/`prepare_collar_solve` already
   determine (`|p* − bound_b| ≤ GSS_tol` ⇒ bound regime; interior otherwise). `dp*/dθ` is
   large but finite in the band (−252 → −34), = `d(bound_b)/dθ`.

**Next: step 4b build** — the bound-regime node (`implicit_value` on `E_column=0` for
`root_crit`), selected by the clamped-to-`bound_b` detector; verify against E4 in the band
(the `dpstar_dtheta_E4` column, −252→−34). Then steps 5–6 (assemble
N_p\*→N_psistem→N_ci→output map into `net_mass_production_dt`, delete the seam). The
production node's home/signature (it needs the double `Leaf` for the off-tape solves + soil
caches, unlike the pure `ci_node`/`psistem_node`) is decided when wiring step 5–6.

## Step 1 — DONE (2026-07-21, plant `27ca7bdd`, superrepo `0ec8f5b`)
`plant::leaf_output` added header-inline to `leaf_model.h` (arrhenius / electron transport
/ colimited assim / Weibull conductivity + `cumulative_vuln` via `incomplete_gamma` /
transpiration / stom-cond / `hydraulic_cost_TF` / `soil_uptake`). The two forward-AD
helpers moved up from `leaf_model.cpp`'s anonymous namespace; `dprofit_droot_collar_psi`
calls the migrated ones. **Value parity** at the converged double operating point
(`scratchpad/leaf_output_parity.cpp`): profit / assim / cost / vcmax / jmax / et to
~1e-15 (spline-free algebra, bit-identical); transpiration / stom-cond / E_up / per-layer
uptake to ~1e-9 (the ~100-knot spline's own bias — the closed form is exact). Regressions
green: leaf 214, TF24 46, TF24f 57, FF16 53+17; double path bit-identical. Not yet on any
rate path. **code-review: approve** — one deferred note (the spline-free algebra now lives
both on `Leaf::` and in `leaf_output::`; pre-existing duplication, collapse deferred to
step 6 to preserve step-1 bit-identity). **Next: step 2 (N_ci `implicit_value`).**
