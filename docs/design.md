# The odelia AD engine — design

Authoritative design for exact reverse-mode **trait/parameter gradients** of the `plant` SCM's emergent
outputs, built on a small general-purpose AD engine in `odelia` so `plant` strategies stay readable as
science. Supersedes and consolidates the prototype-era docs (now in [`archive/`](./archive/)) and the
v2 engine surface design. Full per-component derivations live in the `deepening-*.md` appendices; the
Phase-0 evidence is in [`phase0-results.md`](./phase0-results.md); the build order is in
[`build-plan.md`](./build-plan.md).

A validated prototype exists (traitecoevo/plant#553): it is the **specification and regression oracle**,
not the code that ships. This design reaches the same gradients with a small engine and a plant that
contains **zero tape-aware code**.

---

## 1. What is being differentiated, and for whom

The deliverable is a `double` Jacobian `d(metric)/d(parameter)`. Metrics are **emergent stand outputs**;
parameters are **low-level strategy fields + soil params + birth rate** (not ecological traits — see §9).

### Personas (the surface must serve each without exposing the tape)
1. **Forest ecologist — resident trait sensitivity.** `stand_gradient(scm, metrics, params, feedback="resident")` → doubles Jacobian *with* self-shading feedback. Only AD-aware line is `save_RK45_cache=TRUE`.
2. **Evolutionary ecologist — selection gradient.** `offspring_production_gradient(resident, params)` → invasion-fitness gradient of a rare mutant against a frozen resident canopy; locates singular strategies. Picks the workflow by choosing the function.
3. **Modeller calibrating — the hot loop.** `value_and_gradient(p)` returning both from **one** recording (shared tape); drives L-BFGS. Stresses the "no active handle in R" invariant hardest.
4. **plant developer — a new metric.** Adds a scalar-templated reduction + a name; `metrics="mean_height"` works with no tape/odelia change.
5. **odelia developer — a new ODE model.** Implements the System contract (`value_type`, `set_params`, `set_initial_state`, `rebind`) → gets the gradient driver free.
6. **Maintainer — trust.** The AD path returns doubles in the same shape as the FD path, so verification is a plain numeric compare.
7. **User who forgot the cache.** A clear, actionable error — never a crash or a wrong number.
8. **odelia developer — AD on adaptive numerics.** Two independent capabilities: node-position replay (required for AD, automatic, rides the call) vs value-freeze (an optional *variant* chosen by calling `run_mutant`, not a flag).

### Requirements ledger
- **R1 — a model reads as science.** A strategy writes only scalar-generic pointwise closed forms + declarations: **0** XAD tokens, **0** hand-written adjoints. (Today: ~13 headers include XAD; `node.h::growth_rate_gradient` ~70 ln; TF24 leaf seam ~150 ln — all deleted.)
- **R2 — one transport-gradient path for all strategies.** `dg/dh` needs no per-strategy AD. (Today correct only for K93.)
- **R3 — correct, performant, composable.** Match FD-of-the-model-as-run to its plateau; O(1) forward-equivalents per gradient; survive one nesting where the primitive allows. `|θ|≈5–20`, `N≈10²–10³`, steps `10³–10⁵`.
- **R4 — the soil subsystem resolvable performantly in forward *and* reverse under realistic forcing.** Multirate, not RODAS (E2: accuracy-driven, not stability-driven).
- **R5 — double path bit-identical, or one documented change.** The mass chart's neighbour-secant compression is the sole sanctioned deviation (~0.2% K93, opt-in for gradient runs; §6).
- **R6 — one engine, many models.** K93/FF16/TF24/TF24f now; regnans (a workflow over plant) served by the fixed-point layer.
- **R7 — gradients in both regimes.** Transient (finite-horizon moments, non-settled) **and** fixed point (demographic equilibrium / selection). Neither subsumes the other; the fixed point has no Lagrangian representation (N grows).

**Scarce resource:** *hand-written-adjoint correctness* — every place a human writes a reverse rule is a silent gradient-bug site (value-exact, passes every double test, wrong only in the gradient). The design is measured by how few exist (**two**: the scan transpose and the implicit-node IFT) and how each self-checks.

---

## 2. The two orthogonal axes (the organizing principle)

Most apparent complexity dissolves once two independent axes are separated:

- **Replay** — a property of the *system*: what adaptive constructions must be frozen so the run is
  differentiable (§4). The resident SCM needs L0·L1 + the exact-scan coupling field (L2 only for the
  non-separable fallback); a bare ODE needs only L1. The ecological **feedback choice** (resident vs
  mutant) is the recompute-active vs read-frozen (L3) switch.
- **Functional** — *what scalar* is differentiated (an emergent metric, or a likelihood), orthogonal to
  replay (§8).

Resident vs mutant is not two engines: **the Patch is already the odelia System, and `run_mutant` is
already the frozen-schedule replay.** The invasion gradient is the derivative *of an existing run*. No
`SCMSystem`, no `StrategyConcept`, no second AD stack — surgical changes to existing components. This
"no new abstractions" thesis is a standing constraint.

**Residents first (the delivery ladder's spine).** The *primary* workflow is the **resident census
gradient** (persona 1) — L2-recompute, self-shading, and the density-transport term — not invasion. The
mutant path (L3, frozen field) is the *additive* variant and is **deferred**: it is a recorded-`double`
read layered onto the resident recording, built after the resident path lands. This inverts the
prototype-era "invasion-first" ordering, which the touchpoint catalog's own correction (Part VI.0) and
odelia#28 retired: invasion-first forced a mixed-scalar frozen-`double` boundary *before* the System was
templated, generating most of both prototype attempts' debt. Templating uniformly and reaching the
resident L2 path first removes that boundary.

---

## 3. Architecture — one model layer, engine primitives, two numerics layers

Three layers (M/N/K): **Model** (author, scalar-generic, pure) · **Numerics** (engine, scalar-generic) ·
**Kernels** (engine, the only XAD-aware code).

**The commitment:** *a model contributes only scalar-generic pointwise closed forms and declarations;
every tape-aware operation — the coupling field and its spatial derivative, every inner solve, the
transported-state bookkeeping — is an engine-owned primitive with a machine-checked adjoint.* Kept true
by structure: the model TU (a) does not `#include <XAD/…>` (templated on opaque `S`, calls only
views/primitives) and (b) declares *rates, residuals, kernel factors*, never `d(chart-var)/dt` and never
a transpose. The three silent-bug classes — a hand stencil/adjoint on the tape, raw `xad::value`
arithmetic, wrong-chart compression — become **inexpressible in model code**.

### Engine primitives (Kernels — the only XAD-aware code)
1. **scan-coupling** (P1b) — separated kernel factors `{a_p(z), b_p(x)}` → descending suffix scans `B_p` → `A(x)=Σ a_p B_p` and `∂A/∂z=Σ a_p′ B_p`; reverse = mirrored prefix scans; Neumaier summation; a **near-diagonal direct band** `δ` for recombination cancellation. Init-time self-check `Σ a_p b_p == kernel_direct`; ships the dot-product test.
2. **implicit-node** (P1a) — `register(residual F(y;p), untaped double solver, outputs)`; adjoint forms `∂F/∂y, ∂F/∂p` by `fwd<double>` over the templated residual, small dense solve, `incrementAdjoint`. Sign-definite denominator asserted at registration. `fwd<double>` gives first-order reverse-through-solve **without nested tapes**. Instances: leaf `ci` root, leaf collar optimum `q*`, breakpoints, birth height, the BVP collocation residual.
3. **canonical-state + charts-as-views** (P1e) — engine-owned `(xᵢ, log mᵢ, u, accumulators)`; `StateView` charts (density / log-density / mass / `A` / `∂A/∂z` / `u`) as taped bijections; `TransportGeometry` = the fixed neighbour-secant ↔ log-mass pairing (a fixed pairing, **not** a policy object — promoted only on a second transport discretisation).
4. **γ(s,x) node** (P1c) — incomplete-gamma antiderivative: value + `∂/∂x` (elementary) + `∂/∂s` (series/digamma), FD-validated; `∂²/∂s²` reserved for the fixed-point path.
5. **stepper + tape lifecycle** — explicit RKCK (the reference Control); checkpointed record/replay (per-step sub-tape); vector adjoints; multirate sub-cycle for the soil block.
6. **`value()` firewall** (P1d) — `decide(expr)` (predicate, replays the recorded choice on pass 2) and `diagnostic(expr)` (dead to the tape). Raw `xad::value` grep-banned in Model + Numerics.
7. **verification harness** — the dot-product identity, frozen-schedule FD, per-edge probes, conservation invariants (§10).

### The activation rule (what goes on the tape)
> A quantity goes **active** iff it lies on the differentiable path from a seeded parameter to an
> emergent metric **and** is produced by taped arithmetic (the ODE state, and the algebra mapping
> state+background → rates). A quantity produced by **iteration, optimisation, or adaptive
> refinement** never goes active — it stays `double` and enters the tape, if at all, as (a) a
> **recorded value** (L2 knots / L3 background) or (b) an **injected analytic derivative** (an
> implicit-node output). Diagnostics, error estimates, schedule control, and R facades are off the
> graph.

So the active surface is small and nearly model-invariant: the demographic skeleton
`{height, mortality, fecundity, +extras, log_density, offspring}` + rates, plus a few lines of rate
arithmetic per model. The expensive, model-defining machinery (the ~1500-line leaf hydraulics, the soil
solver, every adaptive controller) stays `double` and touches the tape only through a recorded read or
an injected derivative. **This is the clean odelia/plant boundary** — most of plant needs no reverse
mode at all.

### Two numerics layers over the one model layer
- **Transient** (R7a): the time-marching reverse sweep — checkpoint per accepted step, re-record, sweep. No shortcut (trajectory unsettled).
- **Fixed point** (R7b, regnans): the Lagrangian has no fixed point (N grows), so differentiate the **steady Eulerian-profile BVP** (dim ~4+L: flux `F=g·n`, the three suffix-integral states `B_p`, sink-quadrature states, `L` algebraic steady-`u`), via the **IFT adjoint of the collocation residual** + a **dominant-eigenvalue perturbation identity** (one nested `adj⟨fwd⟩` sweep). F1 confirmed the Eulerian operator is faithful to the march (residual 8.6e-6) and the steady profile is well-posed.

### The odelia co-design boundary (what odelia must provide — the v2 emphasis)
odelia's AD surface was built for a **fixed-dimension, single-scalar, single-`advance_fixed`-replay**
Solver; the SCM is none of those. The clean-boundary contract makes odelia own the hard machinery so
plant supplies only closed forms + residual declarations. The load-bearing co-design items (catalog IX.4):

- **A — growing-dimension active replay** *(load-bearing, unverified).* The SCM is
  `[grow][resize][integrate]…`: cohorts introduced mid-run `resize()` the state, and a new cohort's ICs
  are an **active function of the already-integrated stand** (`log_density = log(birth·pr_estab/g)`
  reads the current, active environment). odelia's active twin is today built once around one
  `reset()+run()` with no introduction/resize hook. odelia must **tape-once across a self-segmenting
  `run()` that resizes**. *De-risk first on `IndividualRunner` (fixed-dimension) then K93-resident (the
  cheapest full SCM).*
- **B — tape reachable from `ode_rates`** for injected derivatives during replay. **Resolved by the
  engine-primitive design:** the model never touches the tape — it declares a residual/kernel and the
  odelia-owned implicit-node/scan primitive owns the injection. This is *why* the primitive boundary is
  cleaner than the prototype's `supplied_derivative`-from-inside-the-model seam.
- **F — the SCM as a self-segmenting runnable** (record-once around a `run()` that grows) — the empirical
  form of A.
- **G — an integration fixture**: growing dimension × injected-derivative-in-replay × the emergent
  functional. The missing de-risking test.
- **C/D** — multi-partial injected derivatives at `N>1`; whole-object L3 snapshots (deferred with L3).
  **E — IC seeding** is already supported+tested in odelia (§11).

The transient checkpointed record/replay and the multirate soil sub-cycle are odelia-owned steppers; the
model declares the stiff index set. A/F/G are the gates the build plan front-loads.

---

## 4. Record / replay — three generic caches, one data-presence switch

AD needs every adaptive construction frozen to its recorded placement: run once adaptively in `double`,
record where it landed, replay pinned on the active scalar. Per **[odelia#28](https://github.com/aornugent/odelia/issues/28)**
(closed) this is **three generic caches and no state-machine metaphor** — the earlier "L0–L3, four
freezes" framing was a headache that conflated levels; the clean model:

| Cache | What | Owner | Cadence | Status |
|---|---|---|---|---|
| **L1** | ODE step schedule | odelia `Solver` | per accepted step | done — driver replays `advance_fixed(recorded_steps())` |
| **L2** | recorded adaptive node positions | System, via the replayable interpolator | per step | **only the non-separable coupling fallback** (`FlatTopSoftBox`) + any other adaptive refiner; **not** the default coupling field (see below) |
| **L3** | per-stage recomputable field values | System | per RK stage | the **mutant** path: read recorded `double` by `(step,stage)`; **DEFERRED** |

Plus **L0** — the cohort introduction schedule (`scm`), frozen up front (`refine_schedule` runs once in
`double`); with introduction times constant, introductions grow the tape but **inject no discontinuity**.

**The default coupling field is exact, not L2** (odelia design #1). For the shared `CanopyShape` kernel
`κ(z,x)=m(x)(1−(z/x)^η)²` (K93/FF16/TF24 defaults) the field is a **closed-form separable sum** computed
by the **scan** — non-adaptive, so it needs **no recorded positions and no L2 record/replay at all**. The
resident coupling path is therefore L0+L1 + the exact scan; the interpolator/L2 survives only where the
kernel is genuinely non-separable. This retires the v1 clunk (a sampled adaptive spline over a
closed-form sum, with a frozen `∂A/∂z` — Oracle R2: "no sampled-field differencing at any tier").

**The one switch is data-presence, not a mode** (odelia#28): `has_recorded_field()` is a query.
- **Resident ⇒ L3 empty ⇒ recompute** the field active on the frozen L2 knots — a trait re-shades the
  stand. **This is the primary workflow and v1's target.**
- **Mutant ⇒ L3 populated ⇒ read** the recorded `double` background (derivative zero by construction) —
  the rare invader neither shades the resident nor itself. **Deferred** (per the current plan; L3 is the
  additive mutant cache, built after the resident path lands).

**A run reads a recomputed field *or* a frozen (L3) one, never both** (VIII.0). Resident recomputes the
field active (the scan for separable kernels — no recorded positions; the interpolator + L2 for the
non-separable fallback), no L3 read. Mutant = L0+L1+L3 (frozen read, no recompute). The resident's
`double` recording stores positions *and* values only so a *future* mutant can read them; the resident's
own gradient never reads L3. There
is no `live|frozen|replaying` state — only `recording` and the `has_recorded_field()` query; odelia grows
**no `Recording` noun** (the word is *field*), and the interpolator owns its own knots (odelia#22).

**Reconstruction is L2's job alone** (VII.0). The dangerous error the earlier docs flagged — reading a
frozen field where the resident must recompute — is now structural: freezing is *only* a recorded read,
so a dropped self-shading derivative is a missing-recording error (loud), not a plausible-wrong number
(silent).

**The crown quadrature is NOT a replay cache.** It is a **fixed-rule** `QK` (Cluster 4): nodes are a
deterministic affine image of the integration bound, so an *active* bound (a census integrated over an
active plant height) tapes exactly through the moving nodes — differentiate *through* it, no recorded
positions. Only *adaptive* placement (the light spline) is L2; the crown integral, the leaf's `QAG`
(`max_iter=1`, fixed), the leaf's four fixed-knot splines, and the extrinsic-driver splines are all
fixed-rule, off the recorded-position path.

---

## 5. Per-component treatment (summary; derivations in the appendices)

Each links to its deepening doc for the exact residuals, factors, and sign conditions.

- **K93/FF16 light coupling + dg/dh** → [`deepening-6`](./deepening-6-light-coupling.md). Rank-3
  separable `κ(z,x)=m(x)(1−(z/x)^η)²` (`m=`(π/4)x² for K93, `area_leaf(x)` for FF16/TF24); three suffix
  scans; C¹ double-diagonal zero makes the moving-query slope safe. **dg/dh** is deleted from the model
  rate by the transport-log-mass chart (`dλ/dt=−r`; `∂ₓg` carried by the neighbour secant =
  `TransportGeometry`); the exact `∂L/∂z` enters only where a rate reads the local light slope. Replaces
  the `compute_competition` trapezium (the resident self-shading cohort-integral) with the scan.
  **node.h scan:** the only transported state is `log_density`; the sole "number" is the offspring
  output accumulator; number appears implicitly at birth as `density=birth·estab/g` (flux/velocity) —
  so the mass chart is new machinery aligned with the existing boundary law.
- **TF24 leaf inner solve** → [`deepening-1`](./deepening-1-leaf-residuals.md). Two sign-definite scalar
  IFT nodes: **N1** stomatal `ci` root (denominator `A′·umol_to_mol + gc·inv_atm > 0`), **N3** collar
  optimum `q*` (denominator `dG/dq < 0`). Transport `ψ_stem` is a closed-form spline composition (not a
  solve). One reduced gradient `G(q)=dW/dq` serves solved (TF24) and tracked (TF24f). Deletes the
  ~150-line FD `supplied_derivative` seam + `dprofit_droot_collar_psi`.
- **Soil↔leaf coupling** → [`deepening-3`](./deepening-3-soil-coupling.md). **Soil moisture is integrated
  ODE state, not a background field** (VII.2): `TF24_Environment` carries `ode_size>0` (FF16/K93 carry 0),
  and the coupling is bidirectional *inside* the ODE — cohorts sum `consumption_rate` into
  `resource_depletion`, which evolves soil, which sets `ψ_soil`, which the leaf reads. So the AD treatment
  is **active state**, not L2/L3: **resident TF24** integrates soil actively coupled to the active cohorts
  (its adjoint rides tape-as-run — the multirate sub-cycle); **mutant TF24** reads soil *frozen* (it rides
  L3, deferred). `StateView.u()` is the state accessor; per-layer uptake `E_i` = an antiderivative
  difference of the `γ` node with Leibniz endpoints and breakpoint nodes at layer crossings. Deletes
  `dsoil_consumption_dpsi_collar_perlayer` and the per-layer FD partials; the same `E_i` serves the
  transient sink and the BVP steady-`u`. Resident soil adds a `∂profit/∂(soil ψ)` channel the mutant path
  never needs — automatic here (the leaf reads `u()` on the tape), where the prototype needed a new hand
  partial.
- **Crown quadrature / early-exits / TF24f** → [`deepening-2-4-5`](./deepening-2-4-5.md). Crown = Kind C
  quadrature-through (no breakpoints; `q` and `L` both C¹). Leaf shut-down early-exits = `decide()`
  predicates for the gradient, **but profit is genuinely discontinuous** across the boundary (Gate-0
  measured a ~1.46 jump at θ-step 1e-7) — a hydraulic-failure cliff, an honesty-condition refuse point,
  **not** a Leibniz breakpoint. TF24f tracked `q` = +1 BVP state pinned by `G=0` at steady state
  (profile identical to TF24) but adds a finite relaxation eigenvalue `k·dG/dq` to the spectrum.

### Other touchpoints the primitives must cover (from the catalog)
- **The net-production sign branch** — `if (net_production > 0) { growth/fecundity } else { zero all
  rates }` (`ff16_strategy.cpp:103`, `tf24_strategy.cpp:186`): a **genuine kink** a plant at the carbon
  compensation point sits on; the subgradient choice must be documented (the whole growth block switches
  off). This is the highest-traffic kink and is distinct from the K93 `smooth_positive` clamps.
- **aux slots carry derivatives** — `competition_effect=area_leaf(h)`, `height_inverse` are recomputed in
  `update_dependent_aux` and read in the rate path; they must be templated on `S` or the derivative
  drops silently. `aux_size` is runtime-varying (`collect_all_auxiliary` changes the layout) — must not
  break a fixed tape.
- **`height_max = max` over cohorts** sets the light-spline domain — a non-smooth max kink on the
  resident gradient; a `decide()` (the argmax is replayed).
- **Deliberately frozen allometry deps** — `r_l`, `r_b` hard-code `lma`, so `d(r_l)/d(lma)=0` by
  construction: a gradient-*interpretation* hazard, documented (§9), not a bug.
- **Mutable caches keyed by exact `double` compare** (`psi_soil_cache_`, `cached_driver_`, leaf
  operating-point caches) — a stale/tape-poison hazard under active types; the firewall's `decide()`
  replay is the containment.
- **Growing-dimension resize on the active tape** — `[grow][resize][integrate]` mid-replay, with
  new-cohort ICs an active function of the integrated stand and co-timed multi-species introductions
  resizing several blocks at once. **odelia's active replay is unverified against `resize()`** — a
  load-bearing co-design gap (the hazard that could invalidate "the SCM is the runnable"); a Phase-1
  verification item.
- **`ode_state`/`ode_rates` `<It>` seam** — the pervasive, model-agnostic templating cut (plant's own
  `<It>` seam, not odelia's).
- **Extrinsic climate drivers** (`PPFD, atm_vpd, ca, …`) are fixed input data, **not** targets; they are
  differentiable-in-principle (a future climate-sensitivity surface) with a `set_extrapolate(false)`
  clamp kink.

---

## 6. dg/dh, the mass chart, and the conservation pair (R2, R5)

The density-transport term `∂ₓg` is the historical clunk (K93-only, forward-over-reverse, a frozen
detached secant). Resolution: the **transport-log-mass chart** removes it from the rate. The pairing that
makes it exact — preserved verbatim from the archived census-gradient design:

- Pair the **explicit** `∂ₓg` in `dℓᵢ/dt` with the **implicit** `∂ₓg` in the quadrature-spacing
  evolution `d(Δxᵢ)/dt = g(xᵢ)−g(xᵢ₊₁)`. In conserved mass `mᵢ=e^{ℓᵢ}Δxᵢ`, `dmᵢ/dt=−r·mᵢ` — the
  compression cancels. **The subtlety:** the *primal* cancels regardless (values agree), but the
  *parameter-derivatives* cancel **only if the two discretisations are literally the same operator**.
- Exact stencil: `∂ₓg = (g(x_{i−1})−g(x_{i+1}))/(x_{i−1}−x_{i+1})`, interior centred / one-sided at
  boundaries, on the characteristics (Lagrangian, no Eulerian diffusion), cohorts ordered tallest-first
  (index-decreasing height ⇒ sign-correct). **Lone cohort (`n<2`): transport term left at zero**
  (transient, negligible census weight).
- **Fragility + retrofit:** the pair is a difference of two `O(1/Δx)` terms — one or two digits less
  precise, and silently re-breakable if the two discretisations ever drift apart. The design-optimal
  successor is the transport log-**number** `L`, `dL/dt=−r` (a single conserved state), the named
  retrofit if the pair degrades. **Rejected fix (do not retry):** injecting an analytic `∂ₓg` derivative
  onto a pristine FD-stencil value gives "the gradient of a *different* model" — no forward-pristine free
  lunch.
- **Gate-0 A confirmed** the geometric/mass-chart path is bounded at the default clamp (max|log n|=21.09
  vs FD 21.15; to 143 cohorts) with the documented **0.169%** offspring shift — so the instability that
  forced the FD stencil does not recur.

---

## 7. Inner solves and the injected-derivative seam

The complete inventory of genuine iterative inner solves in the plant family is **small**:
- **N1** leaf stomatal `ci` root, **N3** leaf collar optimum `q*` (both sign-definite scalar IFTs),
- **birth height** `lift_birth_height` (IFT at an existing root, one Newton step — not iterative on the gap),
- (regnans) the **BVP collocation** solve + the **demographic-equilibrium** fixed point.

Everything else — the light scan, the `ψ_stem` transport composition, the soil `E_i` antiderivative
difference, the crown quadrature — is closed-form / Leibniz / reduction, carrying **no** hand-written
adjoint. **Do not template the shed:** the leaf gas-exchange curves, soil curves, QAG, FD facades, and
`r_*` R-facing wrappers participate only through the implicit-node/`supplied_derivative` seam;
over-templating is the failure mode to avoid.

**Uptake is non-stationary in the collar** (hard-won): freezing the collar is correct for *profit* (the
envelope theorem gives `dprofit/dq*=0`) but drops `∂(uptake)/∂collar · dcollar/dθ`. Base TF24 re-optimises
per FD point (model-as-run); TF24f needs the **analytic per-layer `∂E/∂collar`** because
`E_from_Soil_to_Root_Collar` is piecewise per layer — a straight FD straddles the layer kinks and
undershoots ~3×. Under the new engine this is automatic (Leibniz endpoints + breakpoints, §5), replacing
the hand IFT.

---

## 8. The R boundary and the emergent functional (only doubles cross)

- **One exported entry point** `stand_gradient_cpp(SEXP scm, metrics, params, feedback, …)`: unwrap the
  RcppR6 pointer (no serialisation — read schedule/fields **by native pointer into the live Patch**; an
  `Rcpp::as<Environment>` round-trip is lossy for crown-sampled light and O(stand) slow), resolve
  **metric-name strings → an `EmergentFunctional`** in C++ (R cannot pass a C++ functional — only its
  *selection* crosses), **dispatch strategy/feedback via a table** (`<T,E>` → strategy tag → `switch`,
  never open-coded `if`s), call `compute_jacobian`, return a `double` matrix with dimnames
  (metrics × params) + the §9 caveat + the Control record.
- **`EmergentFunctional` is a pure reduction** (`codomain()` = metric count; reads native state → `vector<S>`; drives nothing). Metric → reduction map: **LAI / biomass / basal-area** via `Species::census<Ψ>`; **offspring / R0** via `net_reproduction_ratio_by_node_weighted` (`scalars=1`); **birth-rate** via §9. This map *is* the definition of what is differentiated.
- **Multi-variable, multi-metric census — get this right.** A census metric is `Σ_i n_i · Ψ(state_i)`, a
  density-weighted reduction where the weight `Ψ` reads the **full multivariate cohort state**
  (height, mortality, fecundity, area/mass_heartwood, …), not just height — so the reduction adjoint must
  flow into **every** state variable `Ψ` touches (and into `n_i` via the density path, §6). The functional
  is a **vector** of such reductions (`codomain = m`): one forward recording, **`m` reverse sweeps** (or
  one seeded VJP per output row). Two structural facts the reduction must honour: (a) it composes over the
  **growing cohort set** (the reduction ranges over a node count that changed mid-run — the sweep must
  cover every introduced cohort); (b) **multi-species** — `ad_parameters()` is species-major, columns are
  `(species, field)`, and a metric summed across species carries **cross-species terms through the shared
  light field** (seed species-2's trait and it moves species-1's cohorts via shading). A census that reads
  one state variable and one species is the easy case; the design targets the general one.
- **`compute_jacobian` contracts:** (a) **pass the codomain** (output count) or pay an extra full replay to size outputs; (b) **column order is a contract** — column `j` = `d(output)/d(leaf_j)` in System-consume (species-major) order, or columns transpose silently.
- **No `wrap`/`as` for active types, by policy** — forcing an explicit `xad::value()`/`derivative()` at the one extraction point keeps derivative loss visible; the active type has no `as` and must never get one (it would silently drop the derivative). This is *why* "only doubles cross R." The cache is anchored on the C++ `Solver` member, not an R handle (no R-visible active solver, not even a power-user hatch).

### Control and caching contract
- **A gradient is well-defined only at a fixed reference Control:** adaptive RKCK (**Euler is refused** — it doesn't populate the RK-stage cache), `save_RK45_cache=TRUE` (the single user-facing AD control — it records resolved step times + adaptive knot/quadrature-node positions, i.e. L1+L2), the per-strategy `shading_model`, and `schedule_eps`/`offspring_production_tol`/`GSS_tol_abs`/`ci_*` at run values. `stand_gradient` records the Control in its result.
- **Fingerprint / staleness guard:** the recording carries a parameter fingerprint; a re-invoked `stand_gradient` on perturbed params **errors loudly** rather than replaying a stale background (closes the optimiser / regnans-Newton hazard). The cache is ephemeral session state, opt-in, **not serialised** (a `saveRDS`'d SCM loses it), with three distinct loud errors: stale / missing-index / never-opted-in.

### birth_rate (first-class) and the equilibrium solve
`birth_rate` is an `ExtrinsicDrivers` value seeded at its **two read sites** — the cohort density IC
`log(birth_rate·pr_estab/g)` and the offspring-output scaling — **not** at an introduction-time scale
(which drops the offspring term). `d(metric)/d(birth_rate)` **flips sign** between the resident
canopy-feedback axis and the frozen identity `metric/birth_rate` — a modelling choice that can dominate
the response. `dR0/d(birth_rate)` drives the `R0=1` Newton solve for the demographic equilibrium (the
regnans deliverable), and depends on the resident-recompute (L2) path — `dR0/d(birth_rate)` *is* the
density-regulating feedback (denser cohorts → more shading → lower per-capita fitness), so it needs the
self-shading term the frozen/invasion version drops.

---

## 9. Differentiation-target semantics (state it, or it's misread)

The columns are partials w.r.t. **low-level `Pars`/soil fields** holding hyperpar-derived quantities
fixed — **not** the ecological total through `hyperpar()`'s fan-out (`lma→{k_l,r_l}`, `rho→{d_I,k_s,…}`,
`a_p1/a_p2` via a solar integral). Composing the hyperpar Jacobian is out of scope; the R help and the
result **must** say so, or `d(LAI)/d(lma)` is misread as a trait sensitivity. Seeding is single-sourced
by one X-macro (`field_ptrs`/`field_names` from one list, `static_assert`ed count). `DifferentiationTargets`
carries **no privileged params/IC split** — a trait-seed and an IC-seed are the same registered leaf.

---

## 10. Verification and the trust model

The whole point is a gradient that is *correct*, and the failure mode is silent (value-exact, wrong
gradient). The trust model, in priority order:
1. **The adjoint dot-product identity `⟨Jv,u⟩=⟨v,Jᵀu⟩`** (`compute_jvp`, odelia) — the primary
   machine-precision gate for every hand adjoint (scan transpose, implicit-node IFT). **Boundary:** it
   does **not** certify an injected `supplied_derivative` *value* — only that forward and reverse agree.
2. **Gate-0 — single leaf / single cohort, clean FD — is the trustworthy oracle.** It caught two real
   defects and validates to ~1e-5.
3. **Census `compute_competition(0)` FD is NOT trustworthy** — ~%-noisy, "fooled this session repeatedly"
   (single-δ sign flips, spurious ~1.2× gaps). Verify the active path at Gate-0, never the census metric.
4. **FD must be swept over δ** (two-sided, U-shaped diagnostic) — a metric hiding an inner solve
   contaminates a single-δ oracle. **Complex-step** is the independent check on smooth subgraphs.
5. **The `M1` gate:** every seeded parameter reaching a `supplied_derivative`/implicit-node site must
   have a partial — an *absent* partial is an implicit zero the slot-pair filter neither causes nor
   catches.
6. **The UX-2 regression fixture** (`gradient-baseline.rds`, two-tier tolerance): AD-vs-AD snapshot;
   nothing merges without it green.
7. **Standing invariants:** mass/moment conservation as gradient tests; the `tf24_stiffness_drift` gate.

### Regression witnesses (preserve verbatim)
- **K93 census, post-fix (targets):** `b_0` 317.883 (err 1.1e-9), `b_1` −516.881 (1.7e-9), `k_I` 2.045e-6
  (2.8e-4), `height_0` 4.09588 (2.7e-6); `cosine(ad,fd)=1.000000`.
- **Pre-fix bug signature (the shape to never regress to):** `b_0` AD 318.7 vs FD 319.4 (~0.2%); `k_I` AD
  **−27.1** vs FD **0.144** (wrong sign, ~190×); `cosine 0.970`.
- **Mass-chart forward shift:** offspring `0.075325 → 0.075453` (0.169%).
- **Named tests:** `test-ad-tf24f-collar-uptake.R` (guards the analytic per-layer `∂E/∂collar`, ~1e-10),
  `test-strategy-k93.R` "offspring production unchanged" snapshots, `test-control.R` (pins the Control
  field set), `test-strategy-ff16(-reference-comparison).R` (bit-identity tripwire),
  `tf24_stiffness_drift`, the forward-JVP vs reverse-VJP dot-product oracle.

---

## 11. Scope, known edges, and honesty conditions

**In scope (v1):** **resident** trait/parameter gradients for K93/FF16/TF24/TF24f (the primary target);
birth-rate; transient moments; **IC gradients**; the fixed-point/selection layer for regnans. **Resident
TF24/TF24f soil is architecturally in scope** — the design must accommodate soil as active coupled state
(the `resource_depletion` loop, the `∂profit/∂(soil ψ)` channel), so the architecture is not FF16-shaped;
only the long-horizon stiffness regime is gated (below). **Mutant/invasion (L3) is deferred** — the
additive frozen-field variant, built after the resident path.

- **IC gradients (in scope, sequenced later).** The seam is uniform (`DifferentiationTargets` doesn't
  privilege params vs ICs), and odelia supports+tests IC seeding (ledger E). The v1 target is the run's
  *own* initial state (the seeded initial size distribution + initial soil), seeded and run from `t0` —
  which needs no resume. The `scm.h:231` "resume-forbids-ode-time-replay" stub is a *different* workflow
  (resuming from an exported mid-trajectory state); lift it as the IC path lands. Sequenced after the
  resident core (build-plan), not deferred.

**Out of scope (documented so they aren't silently re-scoped in):**
- **The introduction-schedule derivative `d(schedule)/dθ`** — **decided out** (catalog XII.1): the
  refined schedule is a nuisance variable; the frozen-schedule gradient *is* the gradient. This retires
  the earlier "frozen-mesh R0 / size the dropped term" edge — no measurement is owed.
- **Second-order / HVP** — except the fixed-point eigenvalue path's low-dim `adj⟨fwd⟩` + `∂²γ/∂s²`. No
  general HVP; the implicit-node's `fwd<double>` is first-order only (kept nestable for a future retrofit).
- **Euler stepping** (a DGVM-compat mode incompatible with the RK-stage cache — a fact, not a choice);
  the stochastic engine (RNG, non-differentiable — a compile constraint only); **hyperpar total
  derivative** (v1 gives low-level-parameter partials, §9); leaf-level forward-mode stays plant-local.

**Known correctness edges (assessed on merit; some resolved by the current approach):**
- **The hydraulic-failure discontinuity** (§5) — **real** (Gate-0 measured it): a true profit jump at
  the leaf shut-down boundary. The gradient is a one-sided branch derivative (exact off the measure-zero
  boundary); the fixed-point/selection module must **refuse** at a crossing (like a spectral-gap
  closure), not average through. Kept.
- **Long-horizon resident-TF24/TF24f stiffness** — *reframed, not a limitation of scope*. The
  `log_density`↔canopy + plant↔soil coupling stiffens the fixed-schedule replay at long lifetimes. The
  **multirate soil sub-cycle** (E2's verdict, the forward track) is the resolution — its adjoint rides
  tape-as-run; the residual stiffness that multirate doesn't cover is held by **recorded adaptive
  sub-stepping** (an L1-refinement: record the adaptive sub-schedule, replay it fixed — an odelia
  co-design item) with a **double-replay-error drift gate** (`tf24_stiffness_drift`) meanwhile. So this is
  *engineered-down*, not deferred-as-stiff.
- **Zero-height cohort NaN trap** — **real**: `area_leaf=(h/a_l1)^(1/a_l2)` → `0·log(0)=NaN`;
  `pow(0, active)` NaNs the tangent (forward loudly, reverse latently). Fix: establish `birth ≥ N`
  cohorts at `h0`; guard `z==0`. Cheap, carries a test. Kept.
- **θ-parameterisation / link functions** — the core reports raw `dM/dθ` in natural coordinates;
  transformed-space calibration applies a boundary chain-rule (a workflow convention). Kept.

**The kink / guard / store manifest (Cluster 7 — a test gate, not code):** each AD-hostile site is
classified once — **kink** (subgradient, operating point can sit on it: the net-production sign branch,
K93 growth/mortality clamps, the resource-spline floor+cap, canopy box/softbox, PPA layer joins, TF24
soil floors, rooting-depth clamp, leaf `abs<1e-8`); **selector** (safe, branch on a passive value:
shading-model dispatch, PPA layer index, the NaN-survival squash); **guard** (needs an active-safe form
reading `value`, never throwing on an active intermediate: `check_finite_ode_state`,
`compute_competition`'s `is_finite`, the K93 interpolator-OOB stop); **store** (must be `S` or has unsafe
invalidation: the `aux` slots, `psi_soil_cache_`, `cached_driver_`, `height_max`). The output is a
reviewed manifest with a verdict per site, so no subgradient ships silently.

---

## 12. What deletes from plant (R1)

`node.h::growth_rate_gradient` (~70 ln), the TF24 `supplied_derivative` FD seam (~150 ln) +
`leaf_profit_at_fixed_collar`, `dprofit_droot_collar_psi`, `dsoil_consumption_dpsi_collar_perlayer`, the
per-layer FD uptake partials, `species.h`'s geometric-compression loop (absorbed into the chart), the
`get_environment_slope_at_height` frozen surrogate, the interpolator *on the coupling path*
(retained only for `FlatTopSoftBox`), the 13 XAD includes (→ one seam header), the scattered `to_passive`
(→ `decide`/`diagnostic`), `Solver::reserve_state`. Net: **zero tape-aware tokens in strategy files.**

## Kill question
The engine hard-codes the method-of-characteristics structure (ordered non-crossing particles, low-rank
separable kernel, mass-conserving transport). It holds for the four plant strategies (shared `CanopyShape`
kernel + SCM transport). **Uncertain for regnans** — if it is a generic stiff ODE rather than a
characteristic solver, only the engine-generic pieces serve it (implicit-node, tape lifecycle, firewall),
not the transport core. Verdict: survives for the plant family; the transport core's reuse beyond plant
is the open fork — but the implicit-node primitive (what regnans's fixed point needs) is exactly the
generic piece, so R4/R6 are served regardless.
