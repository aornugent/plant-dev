# Oracle consultation — the TF24 SCM, re-characterised on the real evolving system

*This supersedes five prior rounds (`oracle-consultation-multirate-update`, `-response`,
`-followon`, `-followon-response`, `-collocation`, `-collocation-response`, `-verdict`). Those
rounds reasoned about an abstract IVP with a "small fast block u" and a "large slow block x", and
validated a decomposition on **frozen-cohort windows**. We have since built the decomposition on the
**real, fully-evolving system** and measured it. The measurements move the binding constraints to a
different block than every prior round assumed. This document gives the **complete, concrete system**
(not an abstraction) so that any proposal is a genuine target, states what is now **measured vs
previously assumed**, and asks where — if anywhere — the leverage actually is. **Please feel free to
reject the multirate/decomposition frame entirely; the data may warrant it.***

---

## Part A — The real system (complete and concrete)

### A.1 What it computes and why speed/stability matter

`plant` is a demographic vegetation model. The object we integrate is a **size-structured population
model (an SCM — "characteristic solver method" for the McKendrick–von Foerster PDE)** coupled to a
**5-layer soil-water model (TF24)**. A single run ("patch") integrates an ODE from t=0 to a horizon T
(target scenarios: **~70 years**), under a prescribed, kinked **rainfall time series**, for **one or
several plant species**.

Two downstream uses set the goals:
1. **Forward speed.** The patch is run many times (assembly, calibration, sensitivity). Target
   scenarios are long (70 yr), dynamic (realistic multi-year drought + monsoonal bursts), and
   multi-species. Runs currently cost tens to hundreds of seconds each and the count is large.
2. **Reverse-mode stability.** We take **reverse-mode gradients** of a scalar functional
   `J` (net offspring production, and calibration losses built on it) w.r.t. traits/parameters `θ`,
   via an operator-overloading AD tape (XAD) that records the integration. The gradient must be
   trustworthy over the same long/dynamic/multi-species scenarios (no drift, no blow-up).

"Faster/stabler" is only meaningful **at the accuracy the science needs** — the tolerance at which
`J` and `dJ/dθ` are converged, **not** the tightest tolerance the integrator can be pushed to.

### A.2 State layout

The ODE state `y ∈ ℝ^N` is `[ cohorts (slow, "x") | soil (fast, "u") ]`:

- **Cohort block `x` (the "slow"/large block), M cohorts.** Each cohort is one node of the SCM
  characteristic mesh, carrying `(height, log_density, cumulative_offspring, …)` — strategy state +2.
  M grows over a run: cohorts are **introduced on an adaptive schedule** (new recruits at the
  bottom boundary) and the mesh is refined to resolve `x(t)`. **M ≈ 50–800** for realistic stands.
  The cohort coordinate (height/size) is ordered; `log_density` is the demographic weight and is
  **highly skewed on evolved stands** (mass concentrates in a few cohorts; many cohorts have
  `log_density → −∞`, i.e. density → 0).
- **Soil block `u` (the "fast"/small block), L = 5 + 4.** 5 soil-water contents `θ_i` (one per
  layer) plus 4 **cumulative-flux auxiliary diagnostics** (decoupled: they integrate fluxes, nothing
  reads them back). So the dynamically-coupled fast block is **L = 5**.

### A.3 Dynamics

**Soil (fast, cheap, closed-form except for the coupling):**
```
dθ_i/dt = ( water_in_i(t) − drainage_i(θ) − uptake_i(x, θ) ) / dz_i
drainage_i(θ) = K_sat · (θ_i/θ_sat)^(2 n_ψ + 3),   2 n_ψ+3 ≈ 16.1   (K_sat=163, n_ψ=6.57)
matric potential ψ_i(θ) = a_ψ (θ_i/θ_sat)^(−n_ψ),  exponent ≈ −6.57  (diverges as θ→0; clamped at 1000)
```
`water_in` is infiltration from the (kinked) rainfall series cascading through layers. Drainage and
matric potential *look* stiff (exp ≈ 16, near-singular at the dry end) but soften-tests show they are
**not** the step-limiter (see B). Everything here except `uptake` is O(1) per layer and cheap.

**Uptake — the coupling `a` (this is the expensive, state-dependent object):**
```
uptake_i(x, θ) = (1/area) · Σ_{j=1}^{M} density_j · consumption_i(cohort_j, θ)
```
`consumption_i(cohort_j, θ)` is the transpiration cohort j draws from layer i. Computing it is a
**per-cohort hydraulic + carbon-optimisation solve**: given the soil potentials ψ(θ), solve leaf
water balance and find the **root-collar potential that maximises carbon profit** —
`p_j* = argmax_p profit(p; cohort_j, θ)`, a **deliberately fixed-iteration golden-section search**
(chosen over Brent because the demographic growth-rate gradient differentiates through `p_j*`, which
therefore must be a *smooth, fixed-iteration* function of its inputs). So `uptake` is an **O(M) sum
of expensive per-cohort argmax solves**, and it depends on the live soil state θ.

**Cohorts (slow, expensive, O(M)):**
```
dheight_j/dt   = growth(cohort_j, θ, light_field(x), p_j*)
dlog_density_j/dt = −mortality(cohort_j, …) − (growth-gradient transport term ∂g/∂height)
dcohort_offspring_j/dt = fecundity(cohort_j, …)
```
Each cohort rate needs the **same expensive per-cohort physiology solve** that produced `p_j*` and
the uptake. **95–100% of one full RHS evaluation is the M cohort solves.** The cohorts also read a
**light field** (a cheap aggregate of the whole cohort block; frozen per macro leg in the
decomposition). Total forward cost ≈ (accepted steps) × O(M).

### A.4 The AD / gradient design (a hard constraint on what's differentiable)

On the reverse-mode branch (`claude/odelia-ad-tape-reverse-496fuf`), `Patch<T,E>` is templated on the
strategy scalar, **but by explicit design (4.3) the embedded `Leaf` hydraulic model stays `double`
and TF24 has *no* `rebind<U>()`**: the leaf's θ/parameter sensitivity reaches the tape via a
`supplied_derivative` **seam computed by finite differences at *fixed* collar-ψ**, which the
**envelope theorem** makes first-order exact (at the argmax, d(profit)/dp\* = 0, so the argmax's
motion contributes nothing to first order — this sidesteps differentiating through the golden-section
search). **Consequence:** a full forward-AD Jacobian of the RHS (what a Rosenbrock/RODAS method
needs) **cannot be formed on TF24** — the leaf is deliberately not an AD citizen. Finite differences
or envelope-FD are the only routes to `∂uptake/∂θ`.

---

## Part B — What is now MEASURED on the real evolving system (vs previously assumed)

All numbers below are on the **real coupled `Solver<Patch<TF24,TF24_Environment>>`**, evolving
cohorts, realistic drought rainfall — **not** a surrogate and **not** a frozen-cohort window.

1. **The step is accuracy-limited, not stability-limited — now proven on the coupled patch, not a
   surrogate.** We built a single-step **IMEX** method: implicit (RODAS4 + finite-difference
   Jacobian restricted to the 5 soil states) on the soil block, explicit on the cohorts. Result on a
   3-yr drought:
   | tol | rkck rhs-evals / wall | IMEX rhs-evals / wall | IMEX vs rkck |
   |---|---|---|---|
   | 1e-4 | 4 629 / 8 s | 100 557 / 452 s | 21.7× more evals, correct (off.rel 3.6e-2) |
   | 1e-5 | 8 859 / 15 s | 462 641 / 2180 s | 52.2× more evals, correct (off.rel 1.7e-3) |
   IMEX is *accurate* but **takes more, smaller steps**, and the deficit **grows** as tolerance
   tightens (21.7×→52.2×). Making the soil block implicit bought **negative** step enlargement. The
   ~20–50× is ~8–20× more accepted steps (only ~2.5× is Jacobian FD inflation). **Directly refutes
   the hypothesis that soil stiffness limits the step.** (Prior rounds' "accuracy-driven collapse
   localised to u near u_min" was measured on a hydrology-only/surrogate system; on the coupled
   system the step-limiting non-smoothness is in the **cohort layer** — the per-cohort argmax
   (non-smooth in θ) and cohort-introduction/clamp transients need h~1e-9 yr at isolated points.)

2. **The accuracy wall is in the cohort layer, not the soil chart.** A reformulation of the soil
   state variable (log-depletion chart ζ = ln(θ−θ_res)) was **neutral**: full-resolution multirate
   is already ~24% off plain RK on an evolved stand **before any coupling reduction**, and that error
   is intrinsic to under-resolving the **cohort** layer on the macro grid. A soil-side change cannot
   move a cohort-layer error.

3. **Collocation over cohorts degrades badly on evolved stands** (confirming Probe C at full scale).
   Reducing the uptake sum to m nodes by subsampling the evolved cohort set: **m=20 → ~296% error,
   m=40 → ~116%** on a 15-yr evolved stand (vs <0.5% at m≈15–20 on a frozen snapshot / prescribed
   set). The evolved density measure is skewed and the integrand develops interior kinks
   (layer-shutdown branch boundaries), so subsampling misses the mass. *(The Oracle's round-4 fix —
   integrate the measure ρ exactly over all M, reduce only the smooth integrand c — was **proposed
   but never built or tested on real evolved stands**; see D.)*

4. **The O(M) cohort solves are irreducible for the cohort rates.** The cohort rates `ẋ_j` require
   all M per-cohort physiology solves regardless of how the soil is advanced — a floor every prior
   round acknowledged. Coupling-reduction (collocation) only cheapens the *soil sub-cycle's*
   per-micro-step cost, a fraction of the total.

5. **The multirate partition works mechanically but doesn't win.** MRI-GARK cuts *slow* (cohort-leg)
   evaluations ~7.6×, but each fast (soil) micro-step re-pays the O(M) uptake, so on the real system
   MRI is **slower** than global RK unless the uptake is made cheap — and the only way to make it
   cheap (collocation) is what fails on evolved stands (item 3).

6. **`J` is ~10× hypersensitive** (Probe D, unchanged): a coupling/soil error of x% shows up as ~10x%
   in `J`, with ~23% spread between independently-converged schemes at large M. Any approximate
   coupling must be validated in **J-units**, not θ-units.

7. **Global explicit RK reaches converged `J` cheaply** and only fails at tolerances ~3 decades
   *past* `J`-convergence (a near-kink wall cleared by shrinking h_min, i.e. resolution not
   stability). At the accuracy the science needs, global RK is already near-optimal on step count.

---

## Part C — The corrected constraint characterisation (the crux)

Combining B.1–B.7, the binding constraints are **both in the cohort ("slow"/x) block**, which every
prior scheme treated as the block to *freeze and take big steps on*:

- **Cost:** 95–100% of every RHS eval is the M cohort physiology solves, needed for `ẋ_j`
  irrespective of the integrator (B.4). The soil ("fast"/u) block the whole program targeted is
  cheap.
- **Accuracy / step count:** the step is set by the cohort layer — the per-cohort argmax
  non-smoothness in θ, cohort-introduction/clamp transients, and layer-shutdown boundaries — **not**
  by soil stiffness (B.1, B.2). Implicit-on-soil makes it *worse* (B.1).
- **Reducibility:** the one lever that would cheapen the cohort contribution to the soil coupling
  (collocation) **fails on the evolved cohort distribution** (B.3), which is precisely the regime the
  70-yr multi-species target lives in.
- **All prior validation (E1–E4) was on frozen-cohort windows**, where the coupling *is* a smooth
  m-quadrature and the cohort layer contributes no step-limiting events. That is the regime where the
  program works — and it is not the target regime.

So: the fast/slow *state* split is genuine (5 soil vs M cohorts, timescales days vs years), but the
multirate lever (sub-cycle the small block, freeze the large one) is aimed at the cheap,
well-behaved block, while cost and accuracy both live in the block it freezes.

---

## Part D — Where might the leverage be? (candidate levers + what kills each)

We are not asking "make the built decomposition faster." We are asking: **given C, is there any
lever that beats global explicit RK at converged `J` on the real evolving system — and if so, which
block does it act on?** Candidates we can see, each with its own kill:

- **L-A. Measure/integrand split for the coupling** (Oracle round 4, untested on real evolved
  stands): integrate the skewed density ρ *exactly* over all M (O(M) arithmetic, **zero** solves),
  reduce only the smooth integrand `c(ξ,θ)` to m nodes; peel the heavy-mass cohorts; split at
  shutdown boundaries; anchor with a free full-M evaluation per macro stage. *Kills it:* even if it
  restores coupling accuracy, it only cheapens the soil sub-cycle — the irreducible O(M) `ẋ_j` floor
  (B.4) and the cohort-layer step limit (B.2) are untouched, so it cannot beat global RK on the total.
- **L-B. Reduce the M cohort solves themselves** (the Oracle's flagged-but-unrecommended "o(M) macro
  floor": collocate the cohort *trajectories*, not just the coupling). *Kills it:* the evolved cohort
  distribution defeats quadrature (B.3), and cohort introduction/refinement is schedule-driven and
  event-like — the same non-smoothness that limits the step (B.1).
- **L-C. Remove the cohort-layer non-smoothness** (event-handle cohort introduction; replace the
  per-cohort argmax with the TF24f *tracked* collar-ψ control `dq/dt = k·d(profit)/dψ` so the
  control is a smooth differential state, not an argmax; smooth the layer-shutdown boundary). This
  attacks the actual step-limiter (B.1). *Kills it:* if the step count is set by genuine solution
  structure (real fast excursions), smoothing the control won't enlarge steps — only removes
  spurious kinks; needs measurement.
- **L-D. Constant-factor RHS reduction** (batched/SoA per-cohort physiology; cache the θ-independent
  per-cohort setup — measured cacheable per leg — so only the θ-dependent evaluate re-runs). No
  asymptotic change; every method pays the O(M) equally, so this helps all of them uniformly. *Kills
  it:* it's not a decomposition/integrator win at all — it concedes the integrator is not the lever
  and just makes each eval cheaper.
- **L-E. Reject the frame:** global explicit RK is already near-optimal at converged `J` (B.7), the
  cost is irreducible O(M) per step (B.4), and the only real win is L-D. If the data say this, say it.

---

## Part E — Questions

1. **Given C (cost and accuracy both in the frozen block; soil implicit makes steps worse; coupling
   collocation fails on evolved stands), is there any decomposition/integration strategy that beats
   global explicit RK at converged `J` on the *evolving* system — or is the honest verdict that the
   integrator is not the lever and only constant-factor RHS reduction (L-D) remains?** If a
   decomposition can win, name it **and the block it acts on**, and the property of the real system
   (Part A) it exploits that we have missed.
2. **Was the fast/slow axis assigned to the wrong block?** The program sub-cycled the cheap soil
   block and froze the expensive cohort block. Is there a *different* exploitation of the same state
   structure — e.g. taking large implicit/exponential steps on the **cohort** demography while the
   soil rides along explicitly — that respects "all M cohort solves are needed per step anyway"? Or
   does the O(M)-solve floor make any cohort-side integrator gain impossible?
3. **The cohort-layer step limit (B.1):** is it dominated by *removable* non-smoothness (argmax kink,
   introduction/clamp transients → attack with L-C event-handling / tracked control) or by *genuine*
   fast solution structure that any method of the same order must resolve? What cheap measurement
   separates these on the real system?
4. **`J`'s 10× amplification with the cohort-layer wall:** does the combination forbid *any*
   approximate-cohort scheme on the gradient path (L-A/L-B), or is there a defect-corrected /
   anchored form whose `J`-error stays within budget on evolved stands?
5. **Which measured fact in Part B is load-bearing for the verdict, and which is incidental?**
6. **What are we missing?** A structural simplification, a hidden cost, or an assumption in our
   framing (e.g. that the cohort mesh must be resolved to the current schedule tolerance, that `J`
   must be taken as given rather than reformulated to be less sensitive, that the leaf must remain a
   non-AD `double` seam) that the data quietly contradict?

---

## Part F — Facts an answer can rely on / cheap discriminating experiments

**Rely on:** global RK reaches converged `J` at modest tolerance and cost; the M cohort solves are
required for `ẋ_j` regardless of scheme; implicit-on-soil is measured 20–50× worse; collocation on
evolved stands is measured 25–279% off; a full-M coupling/light-field evaluation is available free at
every macro-stage boundary (the frozen cohort block is present); the leaf is deliberately a `double`
FD seam (no forward-AD Jacobian on TF24); `J` amplifies coupling error ~10×.

**Cheap experiments we can run before building anything:**
- **F1 (separates E3):** on recorded evolved stands, measure the accepted-step **count** for global
  RK with cohort introductions **event-aligned** vs not, and with the argmax replaced by the TF24f
  tracked control (already implemented) — does the step count fall? (Isolates removable kink from
  genuine structure.)
- **F2 (tests L-A offline):** on a saved *evolved* mature state, compare uptake reconstruction:
  naive m-subsample vs measure/integrand split (exact ρ-moments + m-node smooth integrand, heavy-atom
  peel, boundary split), errors propagated to a `J`-proxy — does the 25–279% collapse toward the
  frozen-snapshot <0.5%? No solver code.
- **F3 (bounds L-D):** profile the batched/SoA cohort-physiology kernel with the θ-independent setup
  cached per leg — what constant factor is actually available on the O(M) floor?
