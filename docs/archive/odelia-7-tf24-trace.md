# odelia design #7 — the representation guarantee, and a full TF24/TF24f bounding trace

Answers three checks: (A) is "dg/dh engine-owned, a fixed pairing" still consistent with the Oracle's
"the model expresses in its natural representation, odelia gives correct gradients"? (B) a component-by-
component trace confirming **every** TF24/TF24f numerical piece is bounded by a named treatment; (C) the
QK re-examination + the tightenings the trace surfaced; (D) the settled separable-coupling name; (E) the
multi-metric census experiment (scope + why it is a Phase-2 gate, not a now-runnable pre-build check).

## A. The representation guarantee — still honored (the "fixed pairing" is *odelia's internal transport*, not a model constraint)

The Oracle's principle: **the model writes its rates in whichever representation is natural; odelia
returns correct gradients regardless of the chart it transports in.** The design honors this on three
levels, and "dg/dh is engine-owned, a fixed pairing" refers only to the middle one:

1. **The model writes natural rates** — `dx/dt = growth(x, A)`, `mortality`, `fecundity`. It does **not**
   write the density-transport term `dg/dh`; that is PDE *structure*, owned by odelia. (This is the
   tier-1 "PDE spec" of the Oracle's two-tier boundary.)
2. **odelia transports in one canonical chart** — log-mass (`dλ/dt = −r`), with the compression carried
   by the neighbour secant. This is the "fixed pairing, not a policy object": **odelia's internal
   transport is one fixed rule, invisible to the model.** It fixes *how odelia bookkeeps transport*, and
   constrains the model **not at all**.
3. **odelia reconstructs whatever representation the model/functional reads** — density `n`, log-density
   `ℓ`, mass, a moment, the field `A` — as an **exact taped read** from the canonical mass state (density
   `= exp(logmass)/spacing`, etc.). A density-dependent rate reads `n`; the census functional reads
   `n·Ψ`; both get the exact reconstruction. This is the Oracle's "representation as a **read-side
   view**," and it is the part I must keep explicit after dropping the `StateView` *noun*: **dropping the
   noun did not drop the reconstruction** — the reads survive as accessors (`A`, `A.at(z)`, and the
   reconstructed `n`). The engine, not the model, owns the mass↔density conversion.

**So: consistent.** The model's representation freedom is preserved by (1) natural rates + (3) exact
read-side reconstruction; "fixed pairing" is odelia's private transport choice. The **one** case where a
model wants to express transport non-canonically — a rate written *on* a chart variable (a source per
unit density; a bespoke conserved quantity) — is the tier-2 **opt-in escape hatch** (`register_chart_rate`:
the model declares the chart-variable rate, odelia supplies the pullback), first-class but rare, already
in `design.md` §"what this makes hard." **Retrofit/kill trigger:** if that escape hatch becomes common,
or a second transport chart is genuinely needed, the fixed pairing is promoted to a choice — the recorded
kill condition. *Action:* make the read-side reconstruction explicit in `design.md` (the `n`-from-mass
accessor is the tier-1 view), so the guarantee is stated, not implied.

## B. The full TF24/TF24f bounding trace (every numerical component → its treatment)

| Component (TF24/TF24f) | What it is | Treatment | Bounded by |
|---|---|---|---|
| **Canopy — DeepCrown** | assim integrated over crown vs the smooth light field | scan field `A` + crown integral | scan (#1) + QK (§C) |
| **Canopy — MeanLight** (TF24 default) | `∫ light·q` over crown → one leaf solve | scan-based mean + one solve | scan + QK + `register_implicit` (#2) |
| **Canopy — CrownCentre** | one leaf solve at `A(H·η_c)` | point read of `A` + one solve | scan + `register_implicit` |
| **Canopy — FlatTopSoftBox** | non-separable softbox competition | **interpolator fallback** for the field; CrownCentre-like assim | interpolator (retained, #1/#5) |
| **Canopy — PPA (smoothed)** | stepped light profile (layer floor) | layer index a `decide()` selector; smoothstep within a layer is C¹ | `decide` (#4) |
| **Canopy — FlatTopBox / PPA-hard** | hard step | **does not run** (dropped) | — |
| **Crown quadrature (QK)** | fixed-rule Gauss–Kronrod over crown depth | **scalar-templated, differentiate through the active bound** (§C) | P1f — *the v1 treatment*, not "nothing" |
| **Leaf `ci` root (`psi_stem_to_ci`, TOMS748)** | stomatal balance root | untaped double solve + IFT | `register_implicit` N1 (#2) |
| **Leaf continuity (`find_root_psi` / `E_column`, TOMS748)** | soil→collar supply = demand | closed-form spline composition (or a scalar root) | `register_implicit` / composition (#1/#2) |
| **Leaf collar optimum (`find_root_collar_psi`, golden-section)** | argmax profit over collar ψ | untaped double optimise + IFT (`dG/dq<0`) | `register_implicit` N3 (#2) |
| **`root_vuln_from_psi` spline** | `f_r=exp(−(|ψ|/b)^c)` (Weibull) | **elementary closed form — exact, no spline** | closed form |
| **`root_vuln_integral_from_psi` spline** | `∫₀^m f_r` (soil vulnerability) | **`incomplete_gamma`** (exact) | P1c (#3) |
| **`transpiration_from_psi` spline** | `∫ f_r` (stem transport — *"same technique," `:378`*) | **`incomplete_gamma`** (exact) — *same family as the soil integral* | P1c (§C tightening) |
| **`psi_from_transpiration` spline** | the **inverse** of the above (E→ψ_stem) | scalar monotone root of `incomplete_gamma` | `register_implicit` (§C) |
| **Leaf `QAG`** (`max_iter=1`) | fixed-rule (dormant adaptive) | stays `double`, off the taped graph | — (not lifted) |
| **`assim_colimited` (quartic)** | co-limitation of Rubisco/electron rates | scalar-generic closed form (already `assim_colimited_ad<T>`) | on-tape `S` (Kind C) |
| **`smooth_positive` clamps** (growth/mortality/net-prod) | smoothed `max(0,·)` | canonical `smooth_positive(x, r)`, declared radius | #4 |
| **shut-down early-exits** | feasibility branches (the hydraulic-failure jump) | `decide()` (recorded, one-sided); refuse at the crossing | #4 |
| **`psi_soil_cache_` (mutable exact-compare)** | memoised soil ψ | **deleted** (recompute; Q8 hazard) | #3/#4 |
| **TF24f tracked collar state** | `opt_root_psi_state`, rate `k·G` | `G` is the reduced gradient; the acclimation rate reuses it | `register_implicit` (#2) |
| **`dprofit_droot_collar_psi` (hand IFT)** | the acclimation gradient | **deleted** — falls out of `register_implicit` | #2 |

**No unbounded component.** Every TF24/TF24f numerical piece maps to one of: {scan, `incomplete_gamma`,
`register_implicit`, templated-QK (P1f), the firewall verbs, the retained interpolator fallback} — or is
`double`/off-graph (leaf QAG) or dropped (non-running canopy modes).

## C. The QK re-examination + the tightenings the trace surfaced

- **QK — you were right to push; my earlier phrasing was loose.** The fixed-rule crown quadrature *does*
  need AD work: **scalar-template `QK::integrate` on `S` + the bound type** so the crown integral tapes
  exactly through the active bound and the active integrand (nodes are a deterministic affine image of
  the bound — no recorded positions, differentiate *through*). This **is the v1 treatment** the prototype
  did (`qk.h` already `#include`s XAD), and it is P1f — *not* "nothing." What I said "little is gained
  from" is **moving QK into odelia**: it is generic fixed-rule quadrature with **one witness** (the crown
  integral), so it stays plant's `qk.h`, templated, until a second consumer justifies lifting it. Distinct
  from the **adaptive** QAG, which is dormant (`max_iter=1`) and genuinely off every graph — not lifted.
  So: **QK templated (P1f, real, done-in-v1); QAG not lifted (dormant); QK-to-odelia deferred (one witness).**
- **`incomplete_gamma` is the leaf-*transport* primitive, not just the soil one (tightening of #3).** The
  code says the stem transpiration integral uses "the same technique" as the root vulnerability integral,
  and both integrate the Weibull `f_r=exp(−(|ψ|/b)^c)` (`leaf_model.cpp:378,388`). So **all four leaf
  hydraulic splines collapse**: `root_vuln_from_psi` → elementary (exact); `root_vuln_integral` and
  `transpiration_from_psi` → `incomplete_gamma` (exact); `psi_from_transpiration` → the inverse, a scalar
  monotone `register_implicit` root. **No sampled-spline reconstruction remains on the leaf transport** —
  the leaf residual `register_implicit` forward-differentiates reads `incomplete_gamma`'s *exact*
  derivative (`f_r`), not a spline `.deriv()`, so the injected partials are exact (Oracle R2 satisfied on
  the leaf, not just the soil). *Fold into #3/deepening-1.*

## D. The separable-coupling declaration — settled name
The one genuinely new *model-facing* declaration (how the shading kernel separates). Settled:
```cpp
// the shading a source of size x casts at query height z, as SEPARATED factors:
//   competition(z, x) = Σ_p query_factor_p(z) · source_factor_p(x)
std::array<S,R> query_factors (double z) const;   // depend on the query height z
std::array<S,R> source_factors(S x)      const;   // depend on the source size x
S               competition_direct(double z, S x) const;  // un-separated, for the init self-check
```
`query_factors`/`source_factors` name the *roles* (which variable each half depends on), read cleanly to
a plant dev, and the `_direct` self-check keeps the separation honest. This replaces the mathy
`kernel_a`/`kernel_b` placeholder from #1. (A plant-native alias — `shade_by_height`/`shade_by_size` — is
acceptable if the plant authors prefer it; the roles are what matter.)

## E. The multi-metric census gradient — a Phase-2 gate, not a now-runnable experiment
It is the right test, but it is **not runnable at the plant#52 tip**: there is no `stand_gradient` entry
there (it is the "ADD" item); the single-metric census gradient was validated in the *prototype*
(`ad-census-gradients` numbers). So the multi-metric case is a **build-validation gate** (Rung-2 / P2a),
not a pre-build de-risk like F1/E2/Gate-0 (which rode the existing forward path). Two layers:
- **Generic (odelia, low risk):** `compute_jacobian` with `codomain=m` is XAD's record-once/m-sweeps —
  add a `codomain>1` correctness test to odelia's suite (dot-product oracle), independent of plant.
- **Plant-specific (the real gate):** a multi-metric (LAI+biomass+basal-area), multi-variable (`Ψ` over
  height + heartwood), **multi-species** (species-major columns, cross-species shading) resident-census
  Jacobian on K93/FF16, oracle-checked + Gate-0 FD. This lands with **P2a** (K93 resident census on the
  clean engine); it needs the scan + mass transport + the functional wired.

**Recommendation:** don't build a heavy driver now; define it as the P2a gate (above). If you want it
sooner, the cheapest path is a small `sourceCpp` driver like the gate0 ones against the prototype's
census machinery — say the word and I'll build it. Tape-memory measurement stays a later problem
(agreed).
