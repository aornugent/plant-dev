# R-D (log-depletion soil state) — ecological characterisation

**Reformulation:** integrate the TF24 soil layers in the log-depletion chart
`ζ = ln(θ − θ_res)` instead of raw volumetric water content `θ`.
**Branch / PR:** `PLANT-57` / plant#58 (issue plant#57), stacked on R-C (plant#56).
**Question this note answers:** what does R-D *do* ecologically — to the soil
water balance, to the plants that draw on it, and to the emergent demography —
and is that behaviour mechanistically faithful?

The headline, stated up front so the rest can be read as evidence:

> **R-D is an ecologically neutral re-discretisation.** It reproduces the same
> soil-moisture equilibria, the same plant water/carbon trajectories, and the
> same demographic outcomes as the raw-θ model, to within an adaptive-stepper
> re-discretisation tolerance (≤ ~1.5 % on meaningful offspring output). Its
> value is *numerical conditioning of the dry-end coupling and a correct
> residual-moisture asymptote*, not any change to the ecology. A separate,
> genuinely ecological change (the NSC storage pool, #554) is what altered the
> deep-drought outcomes on `develop`; R-D neither causes nor depends on it.

---

## 1. The soil chart and why the residual floor is unreachable

The soil water balance per layer is `dθ/dt = (inflow − K(θ) − uptake)/dz`, with
drainage conductivity

```
K(θ) = K_sat · (θ/θ_sat)^p ,   p = 2·n_ψ + 3 ≈ 16.14
```

That exponent is the whole story of the dry end. `K` collapses as a
sixteenth-power law:

| θ | K(θ) (mm/day) | ψ_soil (MPa) |
|------:|---------------:|-------------:|
| 0.428 (sat) | 1.6×10² | 0.002 |
| 0.214 (½ sat) | 2.3×10⁻³ | 0.17 |
| 0.150 | 7.3×10⁻⁶ | 1.75 |
| 0.120 | 2.0×10⁻⁷ | 7.6 |
| 0.080 | 2.9×10⁻¹⁰ | 108 (→ capped) |
| 0.050 | 1.5×10⁻¹³ | 1000 (cap) |
| 0.010 (θ_res) | 3.5×10⁻²⁴ | 1000 (cap) |

By θ ≈ 0.12 gravitational drainage is already ~10⁻⁷ mm/day — a bare soil column
started at half-saturation loses only ~0.015 over **ten years** of drainage
(θ 0.214 → 0.199). Drainage alone can never carry soil into the deep-dry band;
below ~0.12 the *only* thing that removes water is **root uptake**, and uptake
shuts off smoothly (R-C, plant#56; and the hydraulic vulnerability curve) as
ψ_soil saturates at its cap. So both loss terms vanish as θ → θ_res: the
residual moisture is an **asymptote reached in infinite time (Osgood), not a
floor hit in finite time.**

The log-depletion chart encodes exactly this: `θ = θ_res ↔ ζ = −∞`, unreachable
by a finite integration. The raw-θ chart had no such structure — it relied on a
positivity clamp, and the adaptive explicit stepper met the residual-time
stiffness of the uptake coupling as a conditioning failure (the "one cause,
three symptoms" the Oracle diagnosed: intrinsic stiffness, apparent
singularity, derived clamp — one wrong-asymptotics state wearing three hats).
R-D removes all three by construction.

**Ecological reading:** R-D asserts nothing new about the biology. It makes the
state variable carry the drainage/uptake system's *natural* asymptotics, so the
integrator sees a gentle field where the raw chart saw a stiff wall. The soil
never actually approaches θ_res in any run below (§3) — the fix is about the
*path* the solver takes to a benign equilibrium, not the equilibrium itself.

---

## 2. R-D vs raw θ: a faithful re-discretisation

Seven hydraulic scenarios (the plant#556 gateway set) run on both builds —
`develop` (raw θ) and `PLANT-57` (R-D), both carrying NSC #554 — at a 100-yr
patch lifetime.

| Scenario (traits / environment) | soil θ_min: develop → R-D | offspring: develop → R-D | Δ |
|---|---|---|---|
| S01 mesic / arid / shallow | 0.1846 → 0.1846 | 2.967×10⁻¹ → 2.961×10⁻¹ | 0.2 % |
| S02 mesic / arid / deep | 0.1396 → 0.1395 | 4.750×10⁻² → 4.819×10⁻² | 1.5 % |
| S03 xeric / wet / shallow | 0.2140 → 0.2140 | 6.490×10⁻¹³ → 6.490×10⁻¹³ | ~0 |
| S05 xeric / wet-extreme / shallow | 0.2140 → 0.2140 | 2.400×10⁻¹⁴ → 2.426×10⁻¹⁴ | ~1 % |
| S06 xeric / wet-extreme / deep | 0.1707 → 0.1706 | 3.796×10⁻¹⁴ → 3.791×10⁻¹⁴ | 0.1 % |
| S07 xeric / wet / moderate-seasonal | 0.2140 → 0.2140 | 2.928×10¹ → 2.930×10¹ | 0.06 % |
| S08 xeric / arid / seasonal | 0.1327 → 0.1330 | 2.040×10⁻¹⁵ → 2.245×10⁻¹⁵ | (noise) |

Soil equilibria match to ~10⁻³; meaningful offspring match to ≤ 1.5 %; the
sub-10⁻¹³ magnitudes agree at their own noise level. The strategy-level unit
suites (`test-strategy-tf24`, `-tf24f`, `test-scm`) pass **unchanged** under
R-D. This is the signature of a within-tolerance re-discretisation: same physics,
same outcomes, differences bounded by adaptive-stepper tolerances.

---

## 3. The emergent ecology (identical on both builds)

Because R-D is neutral, the biology below is the model's, not the recast's — but
characterising it was the point of the exercise, and R-D is what lets us watch
it run to completion at the dry end.

**Soil moisture equilibrates well above residual.** Across every scenario the
minimum layer moisture stabilises in 0.13–0.30 (ψ_soil 0.02–3.9 MPa). The global
minimum over all runs is θ = 0.133 (S08). Nothing comes within a factor of ten
of θ_res = 0.01. Soil settles into a dynamic balance of rainfall against
drainage-plus-uptake, and — per §1 — that balance sits far up the retention
curve.

**The carbon-starvation pathway (NSC #554) is the drought-death mechanism.**
Following S02 (mesic traits, arid environment, deep roots — the clearest drought
case):

| t (yr) | θ_min | ψ_soil | Σ NSC storage | max mortality (/yr) | min net production |
|------:|------:|-------:|--------------:|--------------------:|-------------------:|
| ~0 | 0.214 | 0.17 | ~10⁻⁶ | 0 | +2.8×10⁻⁴ |
| 4 | 0.150 | 1.71 | 0.106 | 2.7 | +2.5×10⁻⁴ |
| 30 | 0.181 | 0.50 | 5.7×10⁻³ | 48.7 | +2.6×10⁻⁴ |
| 66 | 0.187 | 0.41 | 5.3×10⁻³ | 118 | +2.7×10⁻⁴ |
| 100 | 0.159 | 1.21 | 4.1×10⁻³ | 185 | −8.7 |

Reserves charge early, then are drawn down under sustained water stress; as
relative reserves fall the reserves-based mortality (`mortality_storage_
dependent_dt`, #517/#554) climbs from 0 to ~185/yr and net production tips
negative. This is exactly the buffered carbon-deficit the NSC pool was designed
to bound (the #550 blow-up) — and it is the ecologically meaningful way for a
stand to decline, which the pre-#554 model could not represent (it crashed
instead).

**The gateway's binary classifier hides a persistence gradient.** The gateway
scores "success" as *total offspring > 0*. That threshold conflates two very
different ecological states:

- **Genuine persistence** — S01 (0.30), S02 (0.048), S07 (29.3). Real
  recruitment. S07 (xeric traits, wet, mild season) thrives as expected. S01/S02
  (mesic traits in "arid" environments) persist because the root-zone never gets
  dry enough to starve them: S01's shallow roots sit in a surface layer that
  stays at ψ ≈ 0.19 MPa; S02's deeper roots do dry the soil (ψ up to 1.7 MPa) and
  pay for it in reserves and fecundity, but still recruit.
- **Functional extinction, miscounted as success** — S03 (6×10⁻¹³), S05
  (2×10⁻¹⁴), S06 (4×10⁻¹⁴), S08 (2×10⁻¹⁵). Offspring at the numerical floor.
  Notably S05/S06 die with *wet* soil (θ ≈ 0.21–0.29, ψ ≈ 0.02–0.2 MPa): this is
  **not** a drought death but a trait–environment mismatch — xeric traits (low
  g₁, low K_s, high LMA/wood density) are unproductive in a wet stand
  (net production ~10⁻⁴ vs S07's ~3×10⁻⁴), so recruitment collapses toward zero.

---

## 4. What actually flipped the gateway scenarios (not R-D)

The plant#58 gateway run is red: six scenarios read `failure → success` vs the
recorded baseline. **This is a stale-baseline artifact, and it reproduces
identically on plain `develop` with no R-D present.** Timeline on `develop`:

```
#555  create scenario CSV
#556  gateway framework   ← scenario_baseline.rds recorded HERE
#554  NSC storage pool (reserve-gated growth, reserves-based mortality)
#558  layered soil parameter API
```

The baseline was frozen at #556, *before* NSC storage (#554) landed. In the
baseline these six scenarios are recorded as `crashed` (non-finite) — the
carbon-deficit blow-up (#550) with no reserve pool to buffer it. #554 added that
pool, which bounds the deficit and lets the runs complete; #558 refined the soil
layering. Both changed the scenario outcomes on `develop` months before R-D
existed. Running the gateway on `develop` today produces the *same six flips*.

So the correct attribution is:

- **The flips are a develop-level ecological improvement from NSC #554**, exposed
  by a baseline that predates it. They should be re-blessed against current
  `develop`, independently of R-D.
- **R-D changes none of them** — it reproduces develop's outcomes (§2). Its
  gateway diff vs develop is null.

(The earlier plant#58 PR description attributed the flips to R-D; that was
wrong and is corrected here and on the PR.)

---

## 5. Where R-D's benefit actually lives

If R-D doesn't change these outcomes, what is it for? A controlled soil-block
benchmark (`scripts/tf24-multirate/rd_rodas_bench.R`, real odelia solver, the
TF24-shaped block, stiffness swept via the vulnerability-shutoff steepness `sh`)
answers this more sharply than the gateway can — and the answer is more sobering
than earlier probes suggested. Accepted step counts [accuracy vs a tight
reference]:

| sh | θ+RKCK | θ+RODAS | ζ+RKCK | ζ+RODAS |
|---:|-------:|--------:|-------:|--------:|
| 60 | 32 [1e-7] | 26 [1e-10] | 33 [8e-8] | 29 [6e-11] |
| 250 | 80 [2e-6] | 28 [2e-12] | 83 [1e-7] | 30 [2e-13] |
| 1000 | 284 [4e-8] | 29 [4e-14] | 265 [4e-7] | 30 [2e-14] |
| 2000 | 580 [NA] | FAIL | 547 [NA] | FAIL |

Two conclusions, both against R-D having a *numerical* payoff:

- **The chart does not help the explicit stepper.** `ζ+RKCK ≈ θ+RKCK` at every
  stiffness (265 vs 284 at sh=1000) — the dry-end stiffness is intrinsic to the
  uptake coupling's timescale, not an artifact of the θ chart, so re-charting to
  ζ does not relieve it.
- **The chart does not help the implicit stepper either.** `ζ+RODAS ≈ θ+RODAS`
  (30 vs 29 at sh=1000), both flat ~30 across the whole range, both accurate,
  both failing together at sh=2000. The ~10× step win at stiffness is **RODAS
  being implicit, independent of the chart** — it is fully available on raw θ.
  (An earlier note attributed this conditioning to R-D; the θ+RODAS arm shows
  that was wrong.)

The reason the θ chart's positivity clamp does not degrade RODAS's Jacobian here
is that the **vulnerability shutoff keeps the flux floor-respecting**, so the
clamp branch never activates and the field is smooth on either chart. A floor
test makes the dependency explicit:

| | θ+RODAS | ζ+RODAS |
|---|---|---|
| flux **vanishes** at floor (shutoff on) | θ_min = 0.130 ✓ | θ_min = 0.130 ✓ |
| flux **violates** floor (shutoff off) | θ → −17.85 (nonphysical) | FAIL (NaN) |

When the flux genuinely wants θ < θ_res, **no chart saves you** — ζ blows up to
−∞/NaN and θ runs nonphysically negative. So the residual floor is held by the
*physiology* (uptake → 0 as ψ → ψ_crit), not by the chart. R-D is not a
substitute for the vulnerability shutoff.

What R-D uniquely provides is therefore narrow and non-numerical:

1. **Structural positivity** — `θ = θ_res + eᶻ > θ_res` by construction replaces
   the discontinuous residual-state clamp (which R-D removes). A cleaner,
   kink-free formulation — but on the shipped explicit path, and even paired with
   RODAS, it neither reduces cost nor changes any outcome versus the clamped θ
   chart.
2. **Correctness elegance** — the residual floor as a true Osgood asymptote
   rather than a projection.

Honestly stated: **R-D buys code-cleanliness and a structural guarantee, not
performance or robustness.** The real stiff-regime win belongs to an implicit
stepper (RODAS), which works on the existing θ chart; and the feasibility of the
dry end belongs to the vulnerability shutoff, which R-D cannot replace. That is
the reassurance behind its ecological neutrality (§2) — but it is also the reason
R-D should be justified as a foundational/clarity change, not sold on numerics.

---

## 6. Recommendations

1. **Re-bless the scenario baseline against current `develop`** (not as an R-D
   change). The six flips are the real, already-merged effect of NSC #554.
2. **Sharpen the gateway classifier.** `total offspring > 0` counts functional
   extinctions (S03/S05/S06/S08, offspring 10⁻¹³–10⁻¹⁵) as "success". An
   offspring-magnitude threshold (relative to a viable-recruitment scale) would
   restore S05/S06/S08 to `failure` — matching their qualitative expectation for
   the right reason — and isolate **S01/S02** as the genuine
   expectation-contradicting cases (mesic traits persisting in "arid"
   environments) that merit a scientific look: either the arid parameterisation
   is not root-zone-dry enough, or mesic traits are more drought-tolerant here
   than the scenario table assumes.
3. **Land R-D on its faithfulness + clarity argument** (§2, §5), decoupled from
   the gateway baseline question — and *not* on a numerical/performance claim,
   which the RODAS benchmark does not support. If the bar for merging a
   state-representation change is a demonstrable numerical or ecological benefit,
   R-D does not currently clear it on the shipped path; its case is structural
   positivity and correctness elegance ahead of a future implicit stepper. Worth
   an explicit maintainer decision.
4. **Keep the vulnerability shutoff; do not treat R-D as licence to remove it.**
   The floor test (§5) shows the physiological shutoff — not the chart — is what
   holds soil above θ_res. R-D correctly removes the non-mechanistic residual
   *state* clamp, but it cannot substitute for the shutoff.
