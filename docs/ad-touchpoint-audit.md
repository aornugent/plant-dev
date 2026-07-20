# AD touch-point audit of the plant model surface

_Date: 2026-07-20. Scope: every place the `double`→`S` AD templating (vs pre-AD
`develop`, merge-base `96941d3b`) could drop, sever, or non-smooth a derivative,
across FF16 + the shared model surface (node, species, individual, internals,
patch, environment, resource_spline, qk, canopy_shape, gradient, scm, strategy,
util) + the other strategies (K93, TF24, TF24f) for comparison._

## The one-paragraph finding

The plant AD surface is **overwhelmingly correct** — nearly every `to_passive`
is a genuine position/count/diagnostic/gauge, and the density-transport,
field-assembly, reconstruction, seed, and quadrature paths all carry the
derivative end-to-end (confirmed by frozen-config probes: RHS Jacobian AD==FD to
1e-9). The FF16 gradient defects are **not** plumbing bugs — they are a small,
enumerable set of **non-smooth model expressions** and **passive
constants-that-are-actually-traits**. **K93 is exact because it already fixed all
three FF16 hazard classes**; FF16 fixed none. The remediation is to adopt the
idiomatic odelia primitives K93/TF24 already use.

## Classification legend

- **CORRECT** — dropped derivative is genuinely zero (replay/mesh position, integer
  count/order, diagnostic, provable gauge/cancellation).
- **SEVERED** — a real trait/state derivative is silently zeroed while the value
  still depends on it (a bug; AD=0 or constant where FD≠0).
- **KINK** — non-smooth model expression; AD gives a correct one-sided/subgradient
  that disagrees with two-sided FD (clean δ-independent plateau).

## CONFIRMED DEFECTS (FF16)

| # | site | class | evidence | fix | exemplar |
|---|---|---|---|---|---|
| 1 | `ff16_strategy.h:300-326` growth+fecundity+heartwood `net_mass_production_dt_ > 0 ? rate : 0` | **KINK** | a_l1 tangent ratio 0.46 (metric=2); FD is a clean δ-plateau; shading-driven (birth-rate sweep); mortality (smooth, both branches) is exact | `odelia::util::smooth_positive(net, r)` gating the rate | **K93 `k93_strategy.h:253`** already does exactly this for its growth |
| 2 | `ff16_strategy.h:670-675` establishment `net > 0 ? 1/(tmp²+1)·decay : 0` | **KINK** | same clamp class, establishment path | `smooth_positive` | K93 has no clamp (establishment ≡ 1.0) |
| 3 | `ff16_strategy.h:748` `canopy_shape.initialise(to_passive(pars.eta))` | **SEVERED** | **eta AD=0 vs FD=0.0051 (offspring) / −18.5 (growth)** — fully severed; `eta ∈ FF16_AD_FIELDS` | lift eta into a scalar-templated `CanopyShape` (carry active eta through Q / query & source factors) | — (also latent in **K93 `k93_strategy.h:282`**) |
| 4 | `ff16_strategy.h:665-671` (+769-771) establishment uses passive `height_0` (`height_seed()` root) | **SEVERED** | establishment d/d(a_l1) AD=0 vs FD=-1.3e-4; small (cancels against g in the seed) | consume the IFT-lifted `initial_height()` (as growth does) instead of the raw double root | FF16 `lift_birth_height` (verified) / TF24 `lift_birth_height` |
| 5 | `ff16_strategy.h` birth-size channel: `omega` (∈AD_FIELDS) flows through `height_seed()`→ passive `height_0`/`area_leaf_0` | **SEVERED (Certificate B)** | **omega AD=0 vs FD=2.3e5** (metric=2) — fully dead | IFT-lift the birth *size* wrt every trait (esp. omega) and consume the lifted value in `area_leaf_0` + establishment, not the raw `height_seed()` double | same IFT family as item 4 |
| 6 | K93 `k_I` growth channel severed | **SEVERED (Certificate B)** | k_I AD 9.5e-12 vs FD 6.9e-8 (K93 metric=2) — small but structurally dead | trace k_I's growth path (likely a passive in cumulative_basal_area / canopy); lift | — |
| — | FF16 `a_l2` (leaf-area exponent) | **PARTIAL (0.46/1.20)** | rides the same growth clamp as a_l1 | fixed by item 1 (`smooth_positive`) | K93 smooth_positive |

Items 1–2 are the a_l1 gradient gap. Item 3 is a distinct, fully-severed eta
gradient. Item 4 is real but small.

## LATENT (correct today; break on an untargeted trait/regime)

| site | class | when it bites | fix |
|---|---|---|---|
| `node.h:253` birth log-density `g>0 ? log(birth·estab/g) : log(0)` | KINK+positivity | near g→0 (stalled seed); inactive for a healthy seed | `smooth_positive(g, r)` in guard/denominator |
| `species.h:253` boundary-node inclusion `size()==1 \|\| f_h1>0` | KINK | a boundary cohort's shading crosses 0 | investigate; smooth or drop the branch |
| `tf24_environment.h:244,276,295,306` runoff / drying-layer / conductivity / retention floors | KINK/SEVERED | under drought (θ at residual) | `smooth_positive` on each floor |
| `tf24_strategy.h:271` `max(light_openness, 1e-4)` | KINK | deep shade | `smooth_positive` |
| `tf24_strategy.h:260` + `leaf_model.h` leaf soil-coupling seam | **SEVERED (filed: plant#60)** | envelope-FD at fixed collar-ψ differentiates the **non-stationary co-output** `soil_consumption_`/`E_up_`, dropping `(∂c/∂p)·(∂p*/∂ψ_soil)` (~10× coupling error); can evade a frozen-p* FD | add the dropped term: `∂p*/∂ψ_soil = −P_{p,ψ}/P_{pp}` (IFT on exact `dprofit_droot_collar_psi`) + one `∂c/∂p` eval. **Verify with a re-optimising FD on a real patch**, not frozen-p*. |
| `resource_spline.h:107` `max(0, spline(·))` (#253) | KINK (benign) | spline-path read only (FF16 uses the exact field) | `smooth_positive` if a spline-path gradient is ever taken |

## DX / co-design (value-correct, but a smell)

- **`qk.h` → an `odelia` quadrature primitive.** Functionally value- AND
  derivative-correct (returns the active accumulator; abscissae are affine in the
  active bounds; every `to_passive` is confined to the diagnostic abs/error
  machinery). But it hand-threads `to_passive` at ~14 sites — plant model code
  should never do that. Move the fixed Gauss-Kronrod rule into
  `odelia::quadrature`, separating the differentiated accumulator from the passive
  error-estimate internally. Invariant to preserve on migration: return stays
  active, nodes stay affine in the active bounds.
- **`util::clamp` (`util.h:197`)** is a two-sided-kink primitive; any rate-path use
  on an active quantity needs `smooth_positive` / a smooth clamp instead. Audit
  callers.

## The pattern (the actual deliverable)

Provide idiomatic odelia primitives for every realistic model expression so
stable gradients are the default, not a per-site craft:

1. **Positive parts / clamps** (`x>0 ? f : 0`, `max(0,·)`, floors) →
   `odelia::util::smooth_positive(x, r)` (C∞, already exists). **K93 is the
   in-repo exemplar** (growth + mortality). This is the single highest-value
   change: it closes the FF16 a_l1 gap.
2. **Birth heights / root-solves** solved in double → IFT injection
   (`odelia/implicit_node.hpp`); consume the *lifted* value everywhere (FF16's
   establishment currently doesn't). Exemplars: FF16/TF24 `lift_birth_height`.
3. **Params passivized into helper objects** (`canopy_shape.initialise(to_passive(eta))`)
   → make the helper scalar-templated so the trait's derivative flows. Affects eta
   in FF16 and K93.
4. **Quadrature / interpolation** → odelia primitives that keep the accumulator
   active and confine `to_passive` to diagnostics (qk migration).
5. Genuinely-passive (positions, counts, sort order, replay grid, diagnostics)
   stay passive — the audit confirms these are correct and must not be "fixed".

## Graph-grounding / un-registered-node audit (the "not-yet-on-the-graph" risk)

A gradient-vs-FD sweep only checks leaves *already* registered in `AD_FIELDS`. It
is blind to a node that was never wired onto the graph: a parameter/intermediary/
state left as plain `double`. Two grades, found by a type-flow trace (Pars vs
`AD_FIELDS` registration diff + a scan for `double`-typed members/helper classes on
rate paths):

**Grade 1 — grounding class/intermediary (severs every leaf flowing *through* it):**

| node | scope | severs | fix |
|---|---|---|---|
| `CanopyShape` (un-templated: `double eta_`, `eta_c_`, `eta_inverse_`; methods template only the *query* `Z z`) | FF16, K93, TF24 (strategy + env) | **eta** (verified AD=0 vs FD≠0) — query-height derivative flows, parameter derivative grounded | template `CanopyShape` on `S` for its eta state (one fix, all three strategies) |
| `Leaf` (`leaf_model.h`, un-templated double hydraulics) | TF24, TF24f | soil-coupling co-output derivative (plant#60): reinjected via `supplied_derivative`, but the envelope-FD drops `(∂c/∂p)(∂p*/∂ψ)` | add the dropped IFT term at the seam |
| `height_0`, `height_0_inverse` (double members) | FF16 | establishment's birth-height channel (d(height_0)/d(trait) missing) | consume the IFT-lifted `initial_height()` |

**Grade 2 — un-registered scalar leaf (`double` coefficient: its *own* gradient is
absent, but `double × active` still propagates other leaves, so it doesn't sever —
except where it sits inside the double `Leaf`):**

| node | scope | note |
|---|---|---|
| `root_c` (2.680147), `root_b` (3.898245), `root_psi_crit` (derived) | TF24 | hydraulic vulnerability curve; live *inside* the double Leaf → influence rides the plant#60 seam |
| `beta_R_H` (3.4e2), `beta_R_V` (9.4e3) | TF24 | respiration coefficients hardcoded as members, not in `AD_FIELDS`/`Pars` |
| `k_acclim` (1.0) | TF24f | acclimation rate hardcoded double |

Registration completeness (Pars vs `AD_FIELDS`): FF16 32/32, K93 11/11, TF24 51/51
`Pars` members are all `S` and all registered — the gaps above are the
non-`Pars` hardcoded doubles and the un-templated helper classes, not the `Pars`
structs. Genuine numerical controls (`newton_tol_abs`, `GSS_tol_abs`, `ci_niter`,
`vulnerability_curve_ncontrol`, `psi_fd_step`) are correctly `double`.

**Detection method to institutionalise:** (a) Pars-vs-`AD_FIELDS` diff per strategy;
(b) grep every strategy/env/helper class for `double`-typed data members and flag
any on a rate path; (c) a full-`AD_FIELDS` gradient-vs-reoptimising-FD sweep to
catch severed *registered* leaves (eta-class). Grade-1 grounding classes are the
priority — they silently zero *other* traits' gradients, not just their own.

## Certificate B — empirical per-leaf verification (full AD_FIELDS vs FD)

Reverse-AD gradient over EVERY registered leaf vs a per-field pinned-schedule
central FD, at a real life=40 patch. This is the completeness proof file-reading
cannot give — and it caught two severances the reading missed (`omega`, K93 `k_I`).
Driver: `plant/tests/testthat/ad_certificate.cpp` (`ff16_allfield`/`k93_allfield`);
harness `scratchpad/certificate.R`. Classes: intact (AD==FD≠0) | zero (both 0,
structural) | SEVERED (AD=0, FD≠0) | PARTIAL (both ≠0, ratio off).

**FF16** (32 leaves; metric=2 growth, the most sensitive):
- **SEVERED:** `omega` (AD 0 vs FD 2.34e5 — seed mass, dead via the `height_seed()`
  double root-solve → `height_0`/`area_leaf_0`), `eta` (AD 0 vs FD −18.5 — CanopyShape).
- **PARTIAL:** `a_l1` (0.46), `a_l2` (1.20) — the growth/fecundity clamp.
- 26 intact, 2 structural-zero (`a_f3`, `S_D` — don't reach the growth trajectory).
- metric=0 (offspring): 28 intact, 1 SEVERED, 3 PARTIAL (fecundity clamp adds a_l1).

**K93** (11 leaves):
- **SEVERED:** `eta` (CanopyShape, both metrics); `k_I` on growth (AD 9.5e-12 vs FD
  6.9e-8 — light-extinction coefficient, small magnitude but structurally dead).
- 9 intact (metric=0); recruitment traits `d_0/d_1/S_D` structural-zero on growth.

Newly-found vs the reading audit: **`omega` (FF16)** and **`k_I` (K93)** — both dead
via a double intermediary the static scan flagged but did not connect to a specific
registered leaf. This is why B is required, not optional.

**TF24** (52 leaves, life=10, growth metric, R-hyperpar-resolved params injected,
reoptimising FD): **reverse-AD is numerically broken** — AD values are ~1e25–1e32
while the (sane) FD is O(1–1e5). The double SCM runs fine (FD sane); the active
reverse pass blows up ~30 orders of magnitude. So TF24 cannot be certified per-leaf
yet — its reverse gradient is *non-functional*, not merely missing the plant#60
term. Clean reads: `omega` SEVERED (AD=0, same birth-size root-solve as FF16); 12
structural zeros (a_p1/a_p2/a_f3/S_D/p_50/beta1/nmass_*/dmass_dN/var_sapwood — don't
reach growth at this config). **Action: TF24 reverse-AD needs debugging before a
per-leaf certificate is meaningful** (candidates: the Leaf `supplied_derivative`
seam partials, reverse over the stiff soil ODEs, or a tape/rebind issue). This is a
distinct, larger workstream than the FF16/K93 remediation; TF24 gradient work
(P2c/P2d) is downstream and plant#60 is filed.

Regime caveat: B exercises only pathways active at this state/metric; regime-specific
severances (TF24 drought clamps) are covered by the static census (Certificate A),
not B. Completeness = A (finite grounding-site enumeration, regime-independent) ∧ B
(per-registered-leaf verification for exercised regimes). **B is now: FF16 ✓, K93 ✓,
TF24 ✗ (reverse-AD blown up — must be fixed before it can be certified).**

## Strategy-agnostic engine sweep (odelia AD core + plant lower-level)

Verified clean; the only actionable items are one API foot-gun and the confirmed
knob location.

- **odelia AD engine** (`gradient`/`directional_derivative`/`implicit_node`/
  `supplied_derivative`/`ode_interface`/`ode_solver*`): no severed/kink. L3
  silent-drop cannot originate here (odelia owns no `values_history`; it only
  queries `has_recorded_field()` and recomputes at the active scalar when empty).
  Adaptive stepping is compiled out of the active pass (replay via `step_to`, never
  `step()`/`adjust_step_size`). `register_implicit` injects the full IFT term
  `−(∂F/∂p)/(∂F/∂y)`, not an envelope shortcut.
  - **FOOT-GUN — `supplied_derivative()`** accepts any value + any partials with no
    stationarity/co-output guard. Safe via `register_implicit` (partials IFT-derived
    from a residual), but the raw entry invites the plant#60 shape (a non-stationary
    co-output at a frozen argmax). Guard: keep it internal / debug-FD-check the
    supplied partial against `F` at registration.
- **plant lower-level agnostic** (`individual_runner`/`leaf_model`/`control`/
  base `strategy`/`gradient.h`/`RcppR6_post`): clean.
  - `node.h:319` FD-abscissa strip is **severed-by-design** (McKendrick upwind
    stencil; dead on the mass chart for FF16/K93). Resolves the gradient.h
    call-site question: the abscissa is a pure eval coordinate on purpose.
  - **`ff16_production_kernel.h` absorbed (commit 56b1d149) as pure arithmetic — no
    clamp/positivity migrated into `ff16_strategy`.** The `:300` clamp is original.
  - **plant#60 fix seam present:** `leaf_model.h` exposes
    `dsoil_consumption_dpsi_collar_perlayer` (per-layer `∂c/∂p`) +
    `dprofit_droot_collar_psi` (exact IFT `∂p*/∂ψ`) → the dropped
    `(∂c/∂p)(∂p*/∂ψ)` term is now constructible.
  - **`smooth_positive` corner-radius knob:** add an `FF16_Strategy` member mirroring
    K93's `static constexpr double growth_eps = 1e-4` (`k93_strategy.h:94`), applied
    by wrapping the `:300` branch in `util::smooth_positive(net, r)`. (Runtime-tunable
    variant: a `double` in `control.h` after `node_gradient_eps`, threaded through
    `RcppR6_post` wrap/as.)

## What is verified CORRECT (do not touch)

Density-transport (dλ/dt = −mortality), `reconstruct_densities` /
`seed_newborn_log_mass` (active heights + `cohort_spacing`), the separable
competition field assembly + read (source weights active; `heights_d`/`z` passive
is a correct count/position, boundary source contributes Q(1)≈0), `qk` value+bound
derivative, `lift_birth_height` IFT, the scm active-run gating (adaptive stepping
compiled out for active scalars → fixed replay), the FF16 consumption trapezium
(which actually *repairs* a pre-AD double-only severance).

## Remediation priority

1. **smooth_positive the FF16 clamps** (items 1, 2) — closes the a_l1 gap; K93
   pattern; re-baselines FF16 demography (expect a small snapshot shift).
2. **lift eta into CanopyShape** (item 3) — fixes a fully-severed eta gradient in
   FF16 *and* K93; structural (scalar-templated CanopyShape) → system-design first.
3. **establishment consumes lifted initial_height** (item 4) — small, local.
4. **qk → odelia quadrature primitive** (DX) — no numeric change; removes the smell.
5. TF24 drought/leaf-boundary items — before any TF24 gradient work.

Each model change (1–3) shifts FF16/K93 demography values slightly and needs the
snapshots re-blessed; smooth_positive's corner radius `r` is the accuracy knob
(smaller r → closer to the hard model, sharper kink).
