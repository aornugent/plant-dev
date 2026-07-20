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
