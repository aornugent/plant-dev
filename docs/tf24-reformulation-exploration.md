# Reformulating TF24 without losing the ecology: where the numerical trouble lives, and the mechanistic rewrites that fix it

*What a TF24 reformulation with the **same mechanistic ecological meaning** but **better numerical
stability and performance** actually looks like. Grounded in the real soil-water/plant-water physics
(`plant/inst/include/plant/models/tf24_environment.h`, `tf24_strategy.h`), the multirate study, and two
new measurements run for this exploration (`scripts/tf24-multirate/r1_split_payoff.R`,
`eH0_lambda_spread.R`). Companion to [`tf24-reformulations-evaluation.md`] (the R1–R5 triage) and the H0
thread ([`oracle-consultation-h0-response.md`]).*

The one-line finding: **the stiffness that makes TF24 expensive is not one thing but two, and they come
from two different ecological processes.** Each admits a reformulation that is *more* physically
faithful, not less — the numerical pain points are exactly the places where the current code replaces a
gradual biological process with a hard mathematical switch. Fix the representation to match the biology
and the numerics improve as a side effect.

---

## 1. The TF24 water cycle, as ecology

TF24 couples a **soil-water balance** to **plant water use**. Stripped to the mechanism, water moves
through four processes, each with a direct ecological meaning and a specific mathematical representation
in the code:

| # | Ecological process | What it means | TF24 representation |
|---|---|---|---|
| 1 | **Infiltration** | Rain enters the topsoil; when the surface is already wet, more of it runs off (saturation-excess runoff) | `infil = rain(t)·max(0, 1 − a·(θ₀/θ_sat)^b)`, into layer 0 |
| 2 | **Gravitational drainage** | Water percolates down under gravity; wet soil drains fast, dry soil barely at all | `K(θ) = K_sat·(θ/θ_sat)^{2n+3}`, exponent ≈ **16**; drains layer `i`, feeds layer `i+1` (a downward cascade) |
| 3 | **Root water uptake** | Plants transpire, drawing water from each layer; uptake collapses as the soil dries toward the wilting point | `uptake_i = Σ_cohort` transpiration, driven by the soil→leaf hydraulic path; shuts off near residual moisture `θ_res` |
| 4 | **Matric retention** | How tightly the soil holds water: nearly free when wet, effectively unavailable when dry | `ψ(θ) = a_ψ·(θ/θ_sat)^{−n_ψ}`, exponent ≈ **−6.57**; **diverges** as `θ → 0` |

The state is volumetric moisture `θ_i` per layer (a bucket model, 5 layers), and the balance is

```
dθ_i/dt = ( water_in_i − K(θ_i) − uptake_i ) / dz_i .
```

Two of these processes carry **large exponents** — drainage `^16`, retention `^−6.57` — and those two
exponents are the whole numerical story.

---

## 2. Where the stiffness comes from — two processes, two regimes (measured)

`scripts/tf24-multirate/r1_split_payoff.R` decomposes the soil Jacobian's spectral radius along real
θ-trajectories from a seeded stand under two climates, separating the **hydrology** part
(infiltration + drainage + cascade) from the **root-uptake** part.

**Semiarid stand (soil spends most of its time dry):**

| t (d) | min θ | \|J_full\| | \|J_hydro\| | uptake/hydro | drainage dK/dθ |
|--:|--:|--:|--:|--:|--:|
| 0.25 | 0.130 | 93.5 | 11.5 | 8× | 11.5 |
| 1.00 | 0.127 | 65.6 | 1.3 | 50× | 1.3 |
| 1.50 | 0.126 | 54.6 | 0.59 | **92×** | 0.59 |
| 2.50 | 0.125 | 48.5 | 0.17 | **291×** | 0.17 |

**Wet stand (soil cycles through saturation and dry surface pockets):**

| t (d) | min θ | \|J_full\| | \|J_hydro\| | \|J_remainder\| after exact drainage | drainage dK/dθ |
|--:|--:|--:|--:|--:|--:|
| 0.25 | 0.086 (dry pocket) | 598 | 10.4 | 598 | 10.4 |
| 0.66 | 0.291 (wet) | 4545 | 4545 | **110** | 4653 |
| 1.36 | 0.350 (wet) | 1146 | 1146 | **139** | 1007 |
| 1.54 | 0.359 (wet) | 1700 | 1700 | 250 | 1449 |

Two clean regimes fall out:

- **Drainage stiffness (wet regime).** When a layer nears saturation, the `^16` conductivity switches on
  explosively — `dK/dθ` reaches **~4600/day**. This is the rapid post-storm **recession**: a wetted soil
  shedding water downward. Here hydrology *is* the stiffness (`uptake/hydro ≈ 1`).
- **Root water-stress stiffness (dry regime).** As a layer approaches `θ_res`, the `^−6.57` retention
  curve makes matric potential diverge, so the plant's uptake becomes hypersensitive to tiny changes in
  θ — the uptake Jacobian dominates hydrology by **8×–291×**. This is the near-singular **water-stress
  shut-off**.

**The load-bearing, and somewhat surprising, result:** in a *real transpiring stand* the **uptake-stress
stiffness is the persistent floor**, not drainage. It dominates throughout the semiarid run, and it
appears as dry surface pockets even in the wet run (the θ=0.086 row: `|J|`=598, almost all uptake). The
drainage stiffness is a large but **episodic spike** riding on top of that floor. This refines — and in
part refutes — the earlier premise that "drainage is the dominant wet-end stiffness": it is dominant only
in a fully wet soil with no active water stress, which a real stand rarely is.

---

## 3. The reformulations — each fixes one mechanism, and makes it more faithful

The pattern across all of them: **the numerical pain points are hard switches standing in for gradual
biology.** The positivity clamp stands in for a smooth wilting response; instantaneous profit
maximisation stands in for finite-rate stomatal adjustment; the θ-state stands in for the potential the
plant actually senses. Replace each switch with the biology it approximates and the stiffness/
non-smoothness eases.

### R-A. Exact gravitational-drainage recession — for the wet spike

- **Mechanism.** Gravitational drainage (Clapp–Hornberger / Darcy): the classic soil-water **recession
  curve**.
- **Current representation & why it hurts.** `θ̇ = −K(θ)/dz` is stepped explicitly. The `^16` slope forces
  a tiny, stability-limited step whenever the soil is wet, and a **positivity clamp** guards against the
  explicit step overshooting into `θ < 0` (a purely numerical artifact, issues #485/#549).
- **Reformulation.** The diagonal drainage ODE `θ̇ = −c·θ^{p}` has a **closed-form flow**
  `θ(t) = [θ₀^{1−p} + (p−1)c·t]^{−1/(p−1)}`. Integrate it **exactly** and Strang-split it from the gentle
  cascade + infiltration + uptake. Confirmed to ~1e-13 vs a tight RK reference (`r1_drainage_flow_check.R`).
- **Preserves.** The physics *exactly* — this is not an approximation, it is the analytic solution of the
  same equation. The recession curve is if anything the more recognisable ecological object.
- **Buys (measured).** Removes the drainage stiffness where it bites (7–41× locally in wet layers);
  removes the positivity clamp from the drainage substep (the exact recession cannot overshoot negative);
  makes the touchdown to `θ_res` an **analytic event** (a closed-form root, so its timing and adjoint are
  closed forms rather than a dense-output root-find).
- **What it does NOT buy (measured — the honest limit).** It does **not** make the remainder non-stiff and
  does **not** retire the implicit micro-stepper. After removing drainage, the uptake-stress floor
  remains: an explicit remainder step is unstable well before the drainage limit is relaxed (wet
  end-to-end: the explicit-remainder split blows up at step H=0.02 because the uptake pockets need
  h≲5e-3; semiarid: R1 barely helps because drainage was already subdominant). **R-A is worth doing, but
  it is a wet-regime optimisation, not a silver bullet.**

### R-B. Finite-rate stomatal/hydraulic acclimation (TF24f) — for the dry floor, part 1

- **Mechanism.** Stomatal and hydraulic adjustment to water status. Instantaneous profit-maximising
  optimisation is an *idealisation*; real stomata and root/stem hydraulics track the optimum with a
  finite response time.
- **Current representation & why it hurts.** Base TF24 re-solves `argmax_q profit(q)` (collar water
  potential) every evaluation by a golden-section search. Near the dry bound the optimum `q*(θ)` is nearly
  non-smooth in θ, the search is expensive, and it is awkward for the reverse-mode tape.
- **Reformulation.** Carry the collar potential as a **state relaxing toward its optimum**,
  `dq/dt = k·∂profit/∂q` (TF24f, already implemented). `k → ∞` recovers the TF24 optimum exactly.
- **Preserves.** The optimal-stomatal target, plus a physically-defensible **acclimation timescale** `k`
  — arguably better ecology than instantaneous re-optimisation.
- **Buys (measured, E2–E4).** No argmax in the fast loop; the relaxation is **smoother and better-posed
  than the instantaneous optimum exactly at the dry bound** where the argmax nearly kinks; the reverse-mode
  adjoint is clean (tracked state, not an argmax node). Reproduces the re-optimised soil trajectory to
  <1e-3 at k≈20, no plateau.

### R-C. Smooth water-stress downregulation — for the dry floor, part 2 (the load-bearing one)

- **Mechanism.** Water-stress response: as the soil dries toward the wilting point, roots and stomata
  down-regulate water extraction **gradually** — there is no moisture at which uptake discontinuously
  switches off.
- **Current representation & why it hurts.** The dry end is handled by a **hard positivity clamp** plus a
  ceiling on `ψ` (`soil_psi_max_`), because the `^−6.57` retention curve returns `ψ ~ 1e8` MPa as
  `θ → θ_res` and drives the leaf hydraulic solve non-finite. This hard switch is (i) the source of the
  dominant uptake stiffness (§2), and (ii) a **moving, θ-dependent non-differentiability** that breaks the
  reverse-mode adjoint — measured: a hard moving regime-boundary degrades adjoint-vs-FD by 5–6 orders
  (`e4_bias_test.R`, the "B3 footgun").
- **Reformulation.** Replace the clamp with a **smooth stress function** that down-regulates uptake over a
  *declared moisture scale* as `θ → θ_res` (a soil-moisture stress factor multiplying uptake, or a smooth
  cap on the effective `ψ`). This is standard in ecohydrology (a β(θ) water-stress function).
- **Preserves.** The water-stress mechanism — *more* realistically than a discontinuous cut-off.
- **Buys (measured).** Restores high-order quadrature over cohorts and a differentiable adjoint
  (~1e-9, B3 cure); removes the near-singularity's non-smoothness; and directly softens the **dominant**
  (uptake) stiffness that R-A cannot touch. This is the reformulation that addresses the persistent floor,
  and it is the one the multirate design already flagged as a **prerequisite**, not an optimisation.

### R-D. Log-depletion (log-scarcity) state near the dry bound — the load-bearing dry-floor reformulation

*This is the biggest measured result of the exploration, from a second Oracle consultation and the
`t1_osgood_chart.R` (Osgood) test. See [`oracle-consultation-reformulation-response.md`].*

- **Mechanism.** Matric potential `ψ = a_ψ·(θ/θ_sat)^{−n_ψ}` (`n_ψ≈6.57`) is the variable the plant
  actually senses and the natural driving variable for soil water (Richards-equation practice is ψ-based or
  mixed θ–ψ). Water stress is roughly **linear in log-scarcity** `ln ψ` — how many folds of tension from
  saturation.
- **Current representation & why it hurts — three symptoms of one cause.** The state is θ, and everything
  bad happens as θ → θ_res through the composition `uptake ∘ ψ(θ)`: (i) **stiffness** — the uptake feedback
  diverges as `∂a/∂θ ~ δ^{γ−1}` with **measured `γ−1 ≈ −6.56 ≈ −n_ψ`** (the divergence exponent *is* the
  retention exponent); (ii) **singularity + catastrophic float range** — `θ^{−6.57}` spans ~15 orders over
  a 1.5-order θ-range, so significand is lost before the tape sees it, which is *why* the `ψ` ceiling exists;
  (iii) **non-differentiability** — the positivity clamp at θ_res plus the `ψ` ceiling. The Oracle's
  decomposition (and T1) show these are **one mechanism** — scarcity-driven uptake shutting off steeply —
  wearing three hats of different status: the stiffness is **intrinsic** (a residence time; no coordinate
  removes it), but the singularity and clamp are **artifacts of the θ-chart**.
- **A correctness bug this exposed (measured, T1).** As currently coded, uptake does **not** shut off at the
  wilting point — the `ψ` ceiling (`soil_psi_max_=1e3`) **floors it at a constant** (≈6% of peak) with
  `∂uptake/∂θ = 0` for all θ < ≈0.11. So the **reverse-mode gradient through uptake is silently zero across
  the entire drought regime** — a latent AD-correctness defect exactly where drought response matters.
- **Reformulation.** Integrate the soil block in the **log-depletion coordinate** `ζ = ln(θ − θ_res)`
  (equivalently log-scarcity `ln ψ`, since `γ−1 = −q`), with the water-stress shutoff smoothed (R-C) so
  uptake vanishes at the wilting point. `ζ' = (r − K − a)/(d·e^ζ)` — every process becomes its **per-stock
  rate**, the natural per-capita form.
- **Preserves.** The retention-curve physics and term-by-term interpretability — arguably *improves* the
  ecological reading (log-scarcity is the axis on which tension and stress are linear).
- **Buys (measured/derived).** Deletes the positivity clamp (a finite step in ζ cannot cross a bound at
  −∞ → positivity is structural); deletes the `ψ` ceiling and its **dead gradient channel** (fixing the
  correctness bug); **restores floating-point conditioning** (ζ spans O(10) vs θ^{−6.57}'s ~15 orders);
  bounds the coupling slope (`∂a/∂ζ ≈ γ·a`). The T1 Osgood test confirms the regime: with the shutoff
  fixed, the sink → drainage `~θ^{16} → 0`, the bound is **unreachable** ("Case A"), and the log chart is
  exactly right; as-coded it is a degenerate reachable case held up only by the floor artifact.
- **What it does NOT remove.** The intrinsic residence-time stiffness in the **stress transition**
  (θ≈0.11–0.16), measured real-spectrum (eigenvalues −86.9…−0.42, no imaginary parts) — handed to the
  `L≤5` Rosenbrock solve, exactly as the committed design does. The chart makes that solve well-conditioned
  and smooth; it does not (and cannot) make the stiffness go away.
- **Why not a global "price of water" rewrite (measured, H0 λ-spread).** The tempting version — recasting
  the *coupling* around a single shared price `φ(θ)` — is **not licensed**: `λ_j = (∂P_j/∂θ)/(∂E_j/∂θ)` is
  member-specific, 2–4× across cohorts (`eH0_lambda_spread.R`). So the log-scarcity coordinate is the right
  **state chart for the soil block**, but the coupling stays per-member; do not collapse it.

### R-X. What NOT to do — the priced/tariff rewrite (H0)

For completeness: the elegant option that would delete the per-cohort control entirely — posing the
soil–plant coupling as a shared stock-dependent tariff so the fast system becomes a gradient flow — was
tested and is **dead for TF24**. The fed-back quantity is a **primal water flux**, not the carbon
objective's marginal, and the per-cohort shadow price is member-specific (2–4× spread). See
[`oracle-consultation-h0-response.md`]. It remains a **coupling-design rule for future models**: a member
model *posed* so the fed-back flux is the objective's own marginal would collapse by construction.

---

## 3½. Ecological reading of the T1 finding: the dead zone is the hydraulic-failure threshold

The near-bound "dead zone" is not an obscure numerical corner — it sits exactly on the most ecologically
consequential event in the model. Probing the frozen stand as the soil dries
(`scripts/tf24-multirate/t1b_hydraulic_threshold.R`):

| θ | soil tension `ψ_soil` | cohort operating point `q` | uptake |
|--:|--:|--:|--:|
| 0.20 | 0.26 MPa | −1.42 | responsive |
| 0.16 | 1.14 | −2.08 | responsive |
| 0.13 | 4.47 | −4.81 | responsive, declining |
| 0.115 | 10.0 | **−5.92 (pinned)** | dead / NA |
| 0.10 | 25 | −5.92 | dead |
| 0.06 | 719 | −5.92 | dead |

At θ≈0.11–0.13 the soil tension (4–10 MPa) reaches the cohorts' **hydraulic critical potential** — `q`
pins at ≈ −5.9 MPa, the leaf/root `psi_crit`, the potential at which the xylem loses conductance to
runaway embolism. TF24 is a **plant-hydraulic drought-mortality model**; hydraulic failure is the event it
exists to resolve. The numerical dead zone and the biological failure threshold are the *same point*.

**What the current representation does at that event — and why it is ecologically wrong.** Instead of
transpiration declining smoothly to zero as the vulnerability curve loses conductance (stomata closing,
embolism spreading), the optimiser **pins the operating point at the critical potential** and the leaf
solve leaves its domain, so uptake freezes at a constant (or NA) with **zero sensitivity to further
drying**. Two distinct failures:
1. **No down-regulation.** A plant past its hydraulic limit is modelled as continuing to draw water at a
   fixed rate rather than shutting down — the opposite of drought physiology.
2. **No drought sensitivity (a correctness defect).** The reverse-mode gradient of water use with respect
   to soil moisture — and, through the hydraulic traits, with respect to `θ`-parameters — is **identically
   zero across the entire drought regime**. For a model whose purpose is *trait-gradients of drought
   performance*, the gradient is dead exactly where the science is.

**Why "Case A" is the ecologically correct regime.** Roots cannot extract water past the point of
hydraulic failure; transpiration → 0 there, so drying by root uptake **self-limits** and the wilting point
is an **asymptote, not a wall**. The Osgood Case A (bound unreachable) is precisely this statement. The
current model's degenerate "Case B by artifact" — a constant floor draining the soil to `θ_res` in finite
time — asserts the opposite: plants draining soil *past hydraulic death*. Case A is not a numerical
convenience; it is the correct ecology, and the reformulation restores it.

**Mechanistic suitability of the reformulation.**
- **The mechanism is already in the model.** TF24 carries a hydraulic vulnerability curve (`root_c`,
  `root_b`, `root_psi_crit`; leaf `b`, `c`, `psi_crit`). R-C adds no physiology — it lets the existing
  vulnerability curve run **smoothly to zero** instead of being truncated by the optimiser's domain edge
  and the `ψ`-ceiling. The "declared smoothing scale" is not a fudge factor; it *is* the width of the
  vulnerability curve — an ecological parameter (species water-use strategy, isohydric ↔ anisohydric)
  already fit from hydraulic-trait data.
- **The coordinate matches the physiology.** Plants sense and respond to water *potential*, and hydraulic
  risk is ~sigmoidal in `ψ` / linear in log-tension. Integrating the soil block in log-scarcity
  `ζ = ln(θ − θ_res) ≈ ln ψ` represents it in the variable the vulnerability curve, stomatal response, and
  mortality risk are actually written in — the physiological analogue of the recession-curve reading for
  drainage (R-A). Term-by-term meaning is preserved; each process becomes a per-stock rate.
- **One genuine subtlety.** Runaway embolism is physically fairly abrupt (a cavitation cascade), so a real
  steep nonlinearity does exist at `psi_crit`. But it is smooth and finite on the log-`ψ` axis, not a
  discontinuity — the log chart resolves it with bounded slope where the hard clamp caricatures it as a
  wall. And because the failure threshold is species/cohort-specific (consistent with the measured 2–4×
  member spread in the value of water, R-X), the smoothing must be **per-strategy** — which is how plant
  already parameterises hydraulics, not a single global soil constant.

Net: the reformulation is not merely numerically better — it makes TF24 represent *its own central
process*, drought-driven hydraulic failure, as the smooth, trait-controlled decline it is, and restores
the drought-response gradient the model exists to compute.

## 4. How they compose — two stiffnesses, two mechanistic rewrites

The measurement in §2 scopes the reformulations precisely, because the two stiffness sources are
**separable** (drainage is diagonal; uptake is the coupling):

```
  wet drainage spike   ──►  R-A  (exact recession)              : removes it exactly, + clamp, + analytic touchdown
  dry uptake floor     ──►  R-C  (smooth water-stress shut-off) : uptake -> 0 at wilting; fixes the adjoint AND
                                                                  removes the psi-ceiling dead-gradient bug; -> Case A
                        +   R-D  (log-depletion chart zeta)     : the state reformulation -- deletes clamp + psi ceiling
                                                                  + significand loss; log-scarcity is the natural axis
                        +   R-B  (finite acclimation / TF24f)   : better-posed control at the bound, tape-clean
                        +   implicit/Rosenbrock-W micro-stepper : still required for the residence-time stiffness in the
                                                                  stress transition (real spectrum; R-A/R-D don't remove it)
```

R-C and R-D are **mutually reinforcing**: the smooth shutoff is what puts the system in Case A (bound
unreachable), and the log-depletion chart is what makes Case A clean (structural positivity, no clamp, no
ceiling, honest floating point). Neither alone is enough; together they replace every hard numerical switch
near the bound with the smooth biology it stood in for, and fix a latent gradient-correctness bug in the
bargain.

Each rewrite makes the model **more** physically faithful: an exact recession curve instead of a
clamped explicit drainage step; a finite stomatal acclimation rate instead of instantaneous
optimisation; a gradual wilting response instead of a hard moisture clamp. The numerical artifacts
(positivity clamp, `ψ` ceiling, argmax kink, drainage stability limit) are replaced by the smooth
biological processes they were standing in for.

---

## 4½. Verification probes — stress-testing the chart before the build (V1–V3)

Three cases T2/T3 did not exercise (`t5_chart_stress.R`, `t6_realpatch_logchart.R`). None uncovered a
design-breaker; two sharpen the plan.

- **V1 — differential depletion (a near-floor layer under a saturated one).** Handled. A thin layer at the
  bound directly beneath saturation rewets fast in ζ (`dζ/dt~200`) and needs smaller steps there — a
  **local, transient** cost the adaptive ζ-relative controller absorbs, not a blow-up. (An initial alarm of
  `dζ/dt~2e5` was traced to a mm/m unit bug in the probe, not the chart.)
- **V2 — fast rewetting from the floor + a rainfall kink.** The log chart *singularizes rewetting* in
  principle (`dζ/dt = inflow/e^ζ`), but with physical units the rates are moderate (`~5–7/day` rewetting
  from θ=0.03) and ζ+Rosenbrock converges cleanly; θ-chart is comparably easy. Only a layer within ~1e-3 of
  the bound driven by strong inflow is stiff in ζ — rare (Case A keeps layers off the bound), and handled by
  adaptivity. The rainfall kink must still be a **mandatory breakpoint** (schedule-aligned steps), the
  already-known "two clocks" rule; box storms at ROS2 were forgiving, but the discipline stands.
- **V3 — the real TF24 patch soil block in the log chart.** (a) R-D composes with the *real* coupling: a
  **~20× step cut** on responsive drying (80 vs 1600 steps). (b) Decisively, the **real per-layer uptake is
  smooth in ζ from θ=0.20→0.13 then goes dead flat** (`∂uptake/∂ζ = 0`, pinned at 2.56e-4) below θ≈0.12 —
  the production `psi_crit` pin, now visible in the log coordinate. **The chart cannot smooth what the
  coupling zeroed**, and that pin-kink at θ≈0.12 caps R-D's accuracy on the raw patch at ~1% (vs 1e-4 for the
  smooth model in T2). This confirms on the real system what T1 found: **R-C (the C++ smooth shutoff) is a
  prerequisite for R-D**, not an independent nicety — they must land together.

Net: the reformulation survives the stress cases; the one firm build-ordering consequence is that the
smooth vulnerability shutoff (R-C, in `plant`'s C++) must precede or accompany the chart change (R-D).

## 5. Honest bottom line

- **R-A (exact drainage recession) is worth doing** — it exactly removes the wet-regime spike, deletes a
  numerical clamp, and yields analytic drainage events — **but it is not the main prize.** Measured: it
  does not retire the implicit micro-stepper, because the dominant stiffness is elsewhere.
- **The dominant, persistent stiffness is the root water-stress coupling near the dry bound**, and the
  reformulations that address it — **R-C (smooth stress shut-off)** + **R-D (log-depletion chart)** +
  **R-B (finite acclimation, TF24f)** — are the load-bearing ones. But note the sharpening from the Osgood
  test: the *stiffness itself is intrinsic* (a residence time; no chart removes it — it goes to the implicit
  solve), while the *singularity, the clamp, and the significand loss are artifacts of the θ-chart* that
  R-D deletes. These are also the changes that most improve the *ecological* fidelity of the model, since the
  current code represents water stress, stomatal adjustment, and depletion as hard switches / a bad
  coordinate.
- **R-D exposed a correctness bug, not just a performance one:** the ψ-ceiling floors uptake with a **dead
  reverse-mode gradient across the whole drought regime** (θ < ≈0.11). The reformulation fixes the gradients
  the model exists to produce.
- **The priced/tariff rewrite (R-X) is measured-dead** for TF24; don't pursue it, but design future
  member couplings toward the marginal-coupled form if the science allows.

The reformulation with "the same mechanistic ecological interpretability and better computational
characteristics" is therefore not a single change but a **matched set**: integrate the drainage recession
exactly (R-A); represent water stress and stomatal acclimation as the smooth, finite-rate biological
processes they are (R-C, R-B); and **carry the soil state in log-scarcity** (R-D) — the axis on which the
plant's tension response is linear — so the clamp, the ceiling, the singular slopes, and the significand
loss simply cease to exist. Each change makes the model *more* physically faithful; the numerical pain was
the model telling us it was posed in the wrong variables.

**Validated end-to-end (T2, T3).** A windowed prototype confirms the forward and reverse behaviour
(`t2_logchart_prototype.R`, `t3_chart_ad.cpp`; see [`oracle-consultation-reformulation-response.md`]): the
log-depletion chart + smooth shutoff reproduces the reference trajectory with **zero clamp activations**
(positivity structural) and a **40× step cut** in the stiff water-stress transition, and its reverse-mode
adjoint **matches FD-as-run to ~1e-7** (eps-limited, no kink) with the telescoped `D=Σd_iθ_i` conservation
invariant intact. The intrinsic residence-time stiffness remains and goes to the `L≤5` implicit solve, as
the committed multirate design already provides. What remains is the production build: pose the soil block
in `ζ`, let the existing hydraulic vulnerability curve run smoothly to zero (removing the ψ-ceiling floor
and its dead gradient), and step it with the `L≤5` Rosenbrock — the same micro-stepper, now in the honest
coordinate.
