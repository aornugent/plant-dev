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

### R-D. Potential / mixed-form state near the dry bound — a coordinate, not a rewrite

- **Mechanism.** Matric potential `ψ` is the variable the plant actually senses and the natural driving
  variable for water flow (Richards-equation practice is often ψ-based or mixed θ–ψ).
- **Current representation.** The state is θ; `ψ(θ)` diverges at the dry end, concentrating all the
  difficulty there.
- **Reformulation.** For the near-bound passage, integrate in a **desingularising coordinate** `w = φ(θ)`
  (a bounded transform, e.g. potential-based) so the approach to `θ_res` is gentle.
- **Preserves.** The retention-curve physics.
- **Caveat (measured, H0 λ-spread).** The tempting version of this — recasting the whole coupling around a
  single **shared "price of water"** `φ(θ)` (the H0/tariff collapse) — is **not licensed**: the shadow
  price of water `λ_j = (∂P_j/∂θ)/(∂E_j/∂θ)` is **member-specific**, varying 2–4× across cohorts
  (monotone in height/light; `eH0_lambda_spread.R`). So `φ` is a legitimate *coordinate for the near-bound
  passage*, but **not** a global model rewrite. Secondary, optional.

### R-X. What NOT to do — the priced/tariff rewrite (H0)

For completeness: the elegant option that would delete the per-cohort control entirely — posing the
soil–plant coupling as a shared stock-dependent tariff so the fast system becomes a gradient flow — was
tested and is **dead for TF24**. The fed-back quantity is a **primal water flux**, not the carbon
objective's marginal, and the per-cohort shadow price is member-specific (2–4× spread). See
[`oracle-consultation-h0-response.md`]. It remains a **coupling-design rule for future models**: a member
model *posed* so the fed-back flux is the objective's own marginal would collapse by construction.

---

## 4. How they compose — two stiffnesses, two mechanistic rewrites

The measurement in §2 scopes the reformulations precisely, because the two stiffness sources are
**separable** (drainage is diagonal; uptake is the coupling):

```
  wet drainage spike   ──►  R-A  (exact recession)              : removes it exactly, + clamp, + analytic touchdown
  dry uptake floor     ──►  R-C  (smooth water-stress shut-off) : softens the dominant near-singularity, fixes the adjoint
                        +   R-B  (finite acclimation / TF24f)   : better-posed control at the bound, tape-clean
                        +   implicit/Rosenbrock-W micro-stepper : still required for the uptake floor (R-A does NOT retire it)
                        +   R-D  (desingularised coord)         : optional, near-bound passage only
```

Each rewrite makes the model **more** physically faithful: an exact recession curve instead of a
clamped explicit drainage step; a finite stomatal acclimation rate instead of instantaneous
optimisation; a gradual wilting response instead of a hard moisture clamp. The numerical artifacts
(positivity clamp, `ψ` ceiling, argmax kink, drainage stability limit) are replaced by the smooth
biological processes they were standing in for.

---

## 5. Honest bottom line

- **R-A (exact drainage recession) is worth doing** — it exactly removes the wet-regime spike, deletes a
  numerical clamp, and yields analytic drainage events — **but it is not the main prize.** Measured: it
  does not retire the implicit micro-stepper, because the dominant stiffness is elsewhere.
- **The dominant, persistent stiffness is the root water-stress coupling near the dry bound**, and the
  reformulations that address it — **R-C (smooth stress shut-off)** and **R-B (finite acclimation,
  TF24f)** — are the load-bearing ones. They are also the two that most improve the *ecological* fidelity
  of the model, since the current code represents both processes as hard switches.
- **The priced/tariff rewrite (R-X) is measured-dead** for TF24; don't pursue it, but design future
  member couplings toward the marginal-coupled form if the science allows.

The reformulation with "the same mechanistic ecological interpretability and better computational
characteristics" is therefore not a single change but a **matched pair**: integrate the drainage
recession exactly, and represent water stress and stomatal acclimation as the smooth, finite-rate
biological processes they are — retiring the numerical switches that currently stand in for them.
