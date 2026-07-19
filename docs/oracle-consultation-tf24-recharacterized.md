# Oracle consultation — the TF24 SCM, re-characterised on the real evolving system

*This supersedes five prior rounds (`oracle-consultation-multirate-update`, `-response`,
`-followon`, `-followon-response`, `-collocation`, `-collocation-response`, `-verdict`). Those
rounds reasoned about an abstract IVP with a "small fast block u" and a "large slow block x", and
validated a decomposition on **frozen-cohort windows**. We have since built the decomposition on the
**real, fully-evolving system** and measured it; the measurements move the binding constraints to a
different block than every prior round assumed. This document deliberately gives the **complete,
concrete system** (not an abstraction) and the **measurements**, and then asks — openly — where the
leverage is. **We are not proposing a solution: please derive one from the system, and reject the
multirate/decomposition frame outright if the data warrant.***

---

## Part A — The real system (complete and concrete)

### A.1 What it computes, and why speed and reverse-mode stability matter

`plant` is a demographic vegetation model. One "patch" integrates a coupled ODE from t=0 to a horizon
T under a prescribed, kinked **rainfall time series**, for one or several plant species. Two objects
are coupled:

- a **size-structured population model** — an SCM ("characteristic solver method") for the
  McKendrick–von Foerster renewal PDE: a mesh of **cohorts** advected along growth trajectories, with
  a recruitment boundary and a death/transport term for density;
- a **5-layer soil-water model (TF24)** driven by the rainfall and drawn down by the plants.

Two downstream uses set the goals. **(1) Forward speed:** the patch is run very many times (community
assembly, calibration, sensitivity); target scenarios are long (**~70 yr**), dynamic (multi-year
drought + monsoonal bursts), and multi-species. **(2) Reverse-mode stability:** we take
**reverse-mode gradients** of a scalar functional `J` (net offspring production, and calibration
losses built on it) w.r.t. traits/parameters `θ`, via an operator-overloading AD tape (XAD) that
records the integration; the gradient must stay trustworthy over those same long, dynamic scenarios.
Both goals are relative to **the accuracy the science needs** — the tolerance at which `J` and
`dJ/dθ` are converged — not the tightest tolerance the integrator can reach.

### A.2 State layout

The ODE state `y ∈ ℝ^N` is `[ cohorts (per species) | soil ]`:

- **Cohort block, M cohorts (per species).** Each cohort is one node of the SCM characteristic mesh,
  carrying `(height, log_density, cumulative_offspring, …)` = strategy state + 2. **M grows over a
  run:** cohorts are **introduced on an adaptive schedule** (new recruits enter at the bottom size
  boundary) and the mesh is refined until each cohort's contribution to competition/output is within
  `schedule_eps`. Realistic stands reach **M ≈ 50–800** (per species). The cohort size coordinate is
  ordered; **`log_density` is highly skewed on evolved stands** — mass concentrates in a few cohorts,
  and many cohorts have `log_density → −∞` (density → 0) yet remain in the mesh to resolve the
  trajectory.
- **Soil block, L = 5 (+4).** 5 soil-water contents `θ_i` (one per layer), plus 4 **cumulative-flux
  auxiliaries** that are pure diagnostics (they integrate outgoing fluxes; nothing reads them back),
  so the dynamically-coupled fast block is **L = 5**.

### A.3 Dynamics and the two couplings

There are **two distinct couplings**, on different timescales and cost classes. Prior rounds modelled
only the first.

**(i) Cohort → soil (the expensive, state-dependent coupling): root-water uptake.**
```
dθ_i/dt = ( infiltration_i(t) − drainage_i(θ) − uptake_i(cohorts, θ) ) / dz_i
drainage_i(θ) = K_sat (θ_i/θ_sat)^(2 n_ψ+3),  exponent ≈ 16.1   (K_sat=163, n_ψ=6.57)
ψ_i(θ)        = a_ψ (θ_i/θ_sat)^(−n_ψ),        exponent ≈ −6.57  (diverges as θ→θ_res; clamped at 1000)
uptake_i(cohorts, θ) = (1/area) Σ_{j=1}^{M} density_j · consumption_i(cohort_j, θ)
```
Everything in the soil rate except `uptake` is O(1) per layer and cheap; drainage/matric *look* stiff
(exp≈16, near-singular at the dry end) but are measured **not** to be the step-limiter (Part B).
`consumption_i(cohort_j, θ)` — the transpiration cohort j pulls from layer i — is a **per-cohort
hydraulic + carbon-optimisation solve**: given ψ(θ), solve leaf/stem water balance along a hydraulic
vulnerability curve, and find the **root-collar potential maximising carbon profit**,
`p_j* = argmax_p profit(p; cohort_j, θ)`. The argmax is a **deliberately fixed-iteration
golden-section search** (chosen over Brent so `p_j*` is a *smooth, fixed-iteration* function of its
inputs, because the demographic gradient differentiates through it). So `uptake` is an **O(M) sum of
expensive per-cohort argmax solves**, depending on the live soil state θ.

**A boundary in (cohort, θ) space — leaf shutdown.** When soil dries enough that stem potential would
cross `ψ_crit`, the leaf **shuts down**: transpiration and `consumption_i` drop to zero
(`E_up_ = 0`). Which cohorts are shut down depends on both the cohort (taller/older cohorts hit it
first) and θ — a moving, non-smooth **interior boundary in the cohort–soil product space**. It is
crossed repeatedly during drought as layers dry and re-wet.

**(ii) Cohort → cohort (the cheap, size-only coupling): light competition.** Cohorts shade one
another: a cohort's carbon assimilation depends on the light it receives, which is set by the leaf
area of all taller cohorts — a **light field** `compute_competition(height)`, an integral over the
cohort size distribution. This aggregate is **cheap** (a size integral, no per-cohort physiology
re-solve) and is **frozen once per macro leg** in the decomposition (rebuilt when the cohorts move).
It is a second all-to-all cohort coupling, but through a low-dimensional summary, not θ.

**Cohort rates (the O(M) cost).**
```
dheight_j/dt      = growth(cohort_j, θ, light_field, p_j*)
dlog_density_j/dt = −mortality(cohort_j, …) − ∂growth/∂height        (MvF transport term)
dcohort_offspring_j/dt = fecundity(cohort_j, …)
```
Each cohort rate needs the **same expensive per-cohort physiology solve** that produced `p_j*` and the
uptake. **95–100% of one full RHS evaluation is the M cohort solves.** New cohorts enter at the
recruitment boundary; `∂growth/∂height` is the density-transport term (its evaluation is where the
solution can develop sharp features as fast growers pull away).

### A.4 Timescales and events

- **Soil θ:** responds to rainfall pulses on a **days** scale; fastest at the wet end (large
  `|drainage'|`) and near θ_res.
- **Cohorts:** heights/densities evolve over **years**; the stand matures over decades.
- **Sub-day events:** the per-cohort argmax is non-smooth in θ; cohort introductions and mesh
  refinements are schedule events; leaf-shutdown boundary crossings are θ-driven. These isolated
  non-smoothnesses (not the smooth stiff drainage) are what force the controller to h ~ 1e-9 yr
  (~0.03 s) at scattered points.

### A.5 Measured cost and convergence structure (neutral facts)

- **Per-RHS cost is O(M)** (the cohort solves); the soil rate and the light field are negligible by
  comparison.
- **Wall time scales ~M^1.4** with node volume: at τ=1e-6, N=81 → 25 s / ~13.1k RHS evals;
  N=324 → 183 s / ~23.9k evals. (RHS-eval count grows ~M^0.4; per-eval cost O(M).)
- **`J` converges at modest tolerance:** bit-stable offspring by τ≈1e-5–1e-6; tightening to 1e-8 buys
  no change in `J` and only hits a near-kink "wall" (cleared by shrinking h_min — a resolution limit,
  not a stability limit) at ~47× the cost.
- **`J` is ~10× hypersensitive:** a coupling/soil error of x% appears as ~10x% in `J`, with ~23%
  spread between independently-converged schemes at large M. Approximate schemes must be validated in
  **J-units**, not θ-units.
- **AD tape:** reverse mode is record→replay (an adaptive double pass fixes the step schedule; an
  active pass replays it), so **adjoint cost tracks accepted steps**; the per-cohort physiology and
  the argmax are on the forward tape (via the envelope-FD leaf seam, A.6).

### A.6 The AD design (a hard constraint on what is differentiable)

On the reverse-mode branch `Patch<T,E>` is templated on the strategy scalar, **but by explicit design
the embedded `Leaf` hydraulic model stays `double` and TF24 has *no* `rebind<U>()`.** The leaf's
θ/parameter sensitivity reaches the tape via a `supplied_derivative` **seam computed by finite
differences at *fixed* collar-ψ**, which the **envelope theorem** makes first-order exact (at the
argmax, d(profit)/dp\* = 0, so the argmax's own motion contributes nothing to first order — this
avoids differentiating through the golden-section search). **Consequence:** a full forward-AD Jacobian
of the RHS (what a Rosenbrock/RODAS method needs) **cannot be formed on TF24** — the leaf is
deliberately not an AD citizen; finite-difference or envelope-FD are the only routes to `∂uptake/∂θ`.

### A.7 The scenarios that stress the system

- **Rainfall:** an AR(1) log-annual multiplier drives a seasonal wet/dry two-state Markov process
  with gamma-distributed daily intensities — realistic multi-year droughts and monsoonal bursts, with
  kinks at every rain event. Semi-arid and monsoon variants give near-identical step counts
  (~13k at τ=1e-6): storm intensity is not the discriminating stressor.
- **Horizon:** target ~70 yr (mature, deep-mesh stands most of the run).
- **Multi-species:** several species, each with its own cohort mesh, sharing the soil (via uptake)
  and the light field (via competition) — M multiplies across species.

---

## Part B — What is now MEASURED on the real evolving system (vs previously assumed)

All numbers below are on the **real coupled `Solver<Patch<TF24,TF24_Environment>>`**, evolving
cohorts, realistic drought rainfall — **not** a surrogate, **not** a frozen-cohort window.

1. **The step is accuracy-limited, not stability-limited — now proven on the coupled patch.** We
   built a single-step **IMEX**: implicit (RODAS4 + finite-difference Jacobian restricted to the 5
   soil states) on the soil block, explicit on the cohorts. On a 3-yr drought:
   | tol | rkck evals / wall | IMEX evals / wall | IMEX vs rkck |
   |---|---|---|---|
   | 1e-4 | 4 629 / 8 s | 100 557 / 452 s | 21.7× more evals, correct (off.rel 3.6e-2) |
   | 1e-5 | 8 859 / 15 s | 462 641 / 2180 s | 52.2× more evals, correct (off.rel 1.7e-3) |
   IMEX is *accurate* but takes **more, smaller** steps, and the deficit **grows** as tolerance
   tightens (21.7×→52.2×). Making the soil block implicit bought **negative** step enlargement
   (~8–20× more accepted steps; only ~2.5× is Jacobian-FD inflation). This **refutes the hypothesis
   that soil stiffness limits the step.** (Prior rounds' "accuracy collapse localised to u near
   u_min" was measured on a hydrology-only/surrogate system.)

2. **The accuracy wall is in the cohort layer, not the soil chart.** A reformulation of the soil state
   variable (log-depletion chart ζ = ln(θ−θ_res)) was **neutral**: full-resolution multirate is
   already ~24% off plain RK on an evolved stand **before any coupling reduction**, and that error is
   intrinsic to under-resolving the **cohort** layer on the macro grid. A soil-side change cannot move
   a cohort-layer error.

3. **Collocation over cohorts degrades badly on evolved stands.** Reducing the uptake sum to m nodes
   by subsampling the evolved cohort set: **m=20 → ~296%, m=40 → ~116%** error on a 15-yr evolved
   stand — vs <0.5% at m≈15–20 on a frozen snapshot / prescribed set. The evolved density measure is
   skewed and the integrand develops interior kinks (the leaf-shutdown boundary), so subsampling
   misses the mass. *(A round-4 proposal — integrate the density exactly over all M, reduce only the
   smooth integrand — was never built or tested on real evolved stands.)*

4. **The O(M) cohort solves are irreducible for the cohort rates.** The cohort rates `ẋ_j` require all
   M per-cohort physiology solves regardless of how the soil is advanced.

5. **The multirate partition works mechanically but does not win.** MRI-GARK cuts *slow* (cohort-leg)
   evaluations ~7.6×, but each fast (soil) micro-step re-pays the O(M) uptake, so on the real system
   MRI is **slower** than global RK unless the uptake is made cheap — and the cheapening (collocation)
   is what fails on evolved stands (item 3).

6. **Global explicit RK reaches converged `J` cheaply** and only fails ~3 decades past `J`-convergence
   at a near-kink wall (resolution, not stability). At the accuracy the science needs, global RK is
   already near-optimal on step count.

---

## Part C — The corrected constraint characterisation (the crux)

Combining B.1–B.6 with A, the binding constraints are **both in the cohort block**, which every prior
scheme treated as the block to *freeze and take big steps on*:

- **Cost:** 95–100% of every RHS eval is the M cohort physiology solves, needed for `ẋ_j` regardless
  of the integrator (B.4). The soil block the whole program targeted is cheap.
- **Accuracy / step count:** the step is set by the cohort layer — the per-cohort argmax
  non-smoothness in θ, cohort-introduction/refinement events, and leaf-shutdown boundary crossings —
  **not** by soil stiffness (B.1, B.2); implicit-on-soil makes it *worse* (B.1).
- **Reducibility on the target regime:** the coupling-cheapening that would help (collocation over
  cohorts) **fails on the evolved, skewed cohort distribution** (B.3) — exactly the regime the 70-yr
  multi-species target lives in.
- **All prior validation (E1–E4) was on frozen-cohort windows**, where the coupling *is* a smooth
  m-quadrature and the cohort layer contributes no step-limiting events. That is where the program
  works, and it is not the target regime.

So the fast/slow **state** split is genuine (5 soil vs M cohorts; days vs years), but the program's
lever (sub-cycle the small block, freeze the large one) is aimed at the cheap, well-behaved block,
while cost and accuracy both live in the block it freezes.

---

## Part D — Questions

We deliberately propose no scheme. From Parts A–C:

1. **Is there any integration/decomposition strategy that beats global explicit RK at converged `J`
   on the *evolving* system — or is the honest verdict that the integrator is not the lever?** If a
   strategy can win, name it, the **block it acts on**, and the property of the real system (Part A)
   it exploits that we have missed.
2. **Was the fast/slow axis assigned to the wrong block?** The program sub-cycled the cheap soil block
   and froze the expensive cohort block. Given that all M cohort solves are needed per step anyway
   (B.4), is any gain on the **cohort** side even possible — or does the O(M)-solve floor foreclose
   it?
3. **The cohort-layer step limit (B.1, A.4):** is it dominated by *removable* non-smoothness (the
   argmax kink, introduction/refinement events, shutdown-boundary crossings) or by *genuine* fast
   solution structure any same-order method must resolve? What cheap measurement separates these on
   the real system?
4. **Two couplings, two characters:** cohort→soil uptake is O(M), state-dependent in θ, and carries
   the shutdown boundary; cohort→cohort competition is a cheap size-only aggregate. Does exploiting
   their difference change anything — or is the light coupling a red herring for cost/accuracy?
5. **`J`'s 10× amplification with the cohort-layer wall and skewed density:** does the combination
   forbid *any* approximate-cohort scheme on the gradient path, or is there a form whose `J`-error
   stays within budget on evolved stands?
6. **Which measured fact in Part B is load-bearing for the verdict, and which is incidental?**
7. **What are we missing?** A structural simplification, a hidden cost, or an assumption in our
   framing (e.g. that the cohort mesh must be resolved to the current `schedule_eps`, that `J` must be
   taken as given rather than reformulated to be less sensitive, that the leaf must remain a non-AD
   `double` seam, that a single global step size is required) that the data quietly contradict.

---

## Part E — Facts an answer can rely on, and cheap discriminating experiments

**Rely on:** global RK reaches converged `J` at modest tolerance and cost; the M cohort solves are
required for `ẋ_j` regardless of scheme; implicit-on-soil is measured 20–50× worse; collocation on
evolved stands is measured 25–279% off; a full-M coupling *and* light-field evaluation is available
free at every macro-stage boundary (the frozen cohort block is present); the leaf is deliberately a
`double` FD seam (no forward-AD Jacobian on TF24); `J` amplifies coupling error ~10×; the reverse-mode
adjoint cost tracks accepted steps.

**Cheap experiments available before building anything:**
- **On recorded evolved stands**, measure the accepted-step **count** for global RK with cohort
  introductions/refinements event-aligned vs not, and with the argmax replaced by the already-existing
  TF24f *tracked* collar-ψ control — does the step count fall? (Isolates removable non-smoothness from
  genuine structure.)
- **On a saved evolved mature state**, compare uptake reconstructions (any candidate the Oracle
  names) against the full-M aggregate, errors propagated to a `J`-proxy — no solver code.
- **Profile the per-cohort physiology kernel** with the θ-independent setup cached — what constant
  factor is actually available on the O(M) floor?
