# The odelia AD engine — build plan

Companion to [`design.md`](./design.md) (the *what*/*why*). This is the *how* and *in what order*: a
phased, parallelizable sequence that re-reaches the current plant#52 feature set (all four strategies
reverse-mode + TF24 soil coupling) on the clean engine, then the fixed-point layer. Supersedes the
archived `ad-engine-build-plan.md`; folds in the delivery ladder, the risk gates, and the build/test
mechanics surfaced from the prototype docs.

## Two axes: phases (primitives → strategies) × the delivery ladder (subgraph difficulty)

Progress is fastest when the two axes are worked together. The **delivery ladder is residents-first**
(the flip from the prototype's invasion-first — see `design.md` §2). It orders the *Jacobian rows* up the
resident subgraph; the mutant (L3, frozen field) path is the **deferred** additive variant, layered on
after the resident recording exists.

- **Rung 1 — resident single-metric sensitivity** (L2-recompute, self-shading; a single-state census
  weight): the primary path, minus the density-transport subtlety. Establishes the L2 recompute + the
  clean odelia/plant boundary.
- **Rung 2 — resident census, multi-variable + multi-species**: the weight `Ψ` reads the full cohort
  state; the functional is a vector of `m` reductions with species-major columns and cross-species
  shading terms. Adds the **`∂g/∂h` density-transport term** (the mass chart) — the only tier that needs
  it robust. This is the load-bearing target (`design.md` §8).
- **Rung 3 — `dR0/d(birth_rate)`** (the regnans equilibrium deliverable): the density-regulating feedback,
  on the resident self-shading path; then the fixed-point/selection layer (Phase 3).
- **Deferred rung — mutant invasion-fitness** (frozen L3 field, no `∂g/∂h`, no self-shading): the
  *cheapest* subgraph, but deferred per the current plan — it is an additive recorded-read variant, built
  once the resident recording and the L3 cache land. (It remains the selection-gradient persona's path.)

## Standing constraints (hold on every landing)
- **Bit-identity guard.** Nothing lands that moves the `double` path: `test-strategy-ff16(-reference-comparison).R`, the K93 "offspring production unchanged" snapshots, `test-control.R` (pins the Control field set). A changed number = broken bit-identity; **diff the FP order, not just the value.** (Sanctioned exception: the mass chart's ~0.169% K93 shift, opt-in for gradient runs.)
- **Each engine primitive ships its own verification before any plant consumer uses it** — the dot-product oracle `⟨Jv,u⟩=⟨v,Jᵀu⟩` for the scan; IFT-vs-FD for the implicit-node; Richardson-FD-vs-analytic for `γ`. The scarce resource (hand-adjoint correctness) defended structurally.
- **Gate-0 is the oracle; the census metric is not.** Verify the active path at single-leaf/single-cohort clean FD (swept over δ). Never trust `compute_competition(0)` census FD (~%-noisy, fooled the prototype repeatedly).
- **UX-2 fixture gate.** Snapshot validated Jacobians to `tests/testthat/fixtures/gradient-baseline.rds` (two-tier tolerance). **Nothing merges without UX-2 green** — the AD-vs-AD regression net, distinct from Gate-0.
- **The one cross-track contract.** The engine must **tape the scheme as run** with a frozen, replayable control-flow schedule (L0 cohort schedule, L1 steps, L2 knots). Any parallel track (multirate) must keep its micro-schedule / event / pin decisions recordable in pass 1 and replayable in pass 2.
- **Clean odelia/plant boundary (the v2 emphasis).** odelia owns the tape, the primitives, and record/replay across the growing dimension; plant supplies only scalar-generic closed forms + residual/kernel declarations. No model code reaches the tape (this is what makes the boundary cleaner than the prototype's in-model `supplied_derivative` seam). One templated body per read — **never** parallel `!is_same_v<double>` overloads.
- **Build/test mechanics** (survival-critical — from `archive/ad-handover.md`): reinstall `odelia` after ANY odelia header edit (plant compiles against *installed* headers, not the submodule tree); `Sys.setenv(TESTTHAT_PARALLEL="false")`; build optimised once (`cd plant && make`, `-O2`) then `load_all` reuses the `.so`; regenerate RcppR6 only when adding/removing a registered field; on `undefined symbol`, `rm src/*.o src/*.so` and reinstall.

## Phase 0 — validate the biggest bets (pure `double`, no build) — **DONE**
See [`phase0-results.md`](./phase0-results.md). **F1** confirmed the fixed-point route (Eulerian
transport operator faithful to the march, residual 8.6e-6; steady profile well-posed). **E2** redirected
the soil track (drainage/potential envelopes don't share a shape — 32 OOM; the desingularizing chart
makes it *worse*, 0.30–0.47×; kink-split cuts rejections 1.85×). Two Gate-0 deepening checks: **A**
(mass-chart stability) passed (bounded at the default clamp, 0.169% shift); **B** (leaf early-exit C⁰)
**refuted** the continuity assumption (a true ~1.46 profit jump → an honesty-condition refuse point, not
a breakpoint).

(PROTO-2 — the old "does the full-scalar replay capture the density→optimum cross-term" rescope gate —
is **resolved**; the density→optimum cross-term is captured, and the v2 work pursues clean odelia/plant
boundaries rather than re-proving it.)

**The front-loaded de-risk is now the odelia co-design ledger** (`design.md` §3 A/B/F/G) — the one
class of unknown that can move the architecture, on the clean-boundary axis the v2 emphasises:
- **CD-A — growing-dimension active replay** *(load-bearing).* Does odelia's active twin/tape survive a
  mid-`run()` `resize()`, taping-once across `[grow][resize][integrate]` segments, with a new cohort's
  active ICs (`log_density=log(birth·estab/g)` reading the active stand) captured? **De-risk cheapest on
  `IndividualRunner`** (fixed-dimension — no growing dim, the clean single-plant target; this is also
  where IC-seeding, ledger E, is exercised first) **→ then K93-resident** (the cheapest full SCM: growing
  dim + L2 recompute + a census functional, no leaf/quadrature). This is the empirical form of CD-F/CD-G.
- **CD-B — tape-from-`ode_rates` injection** is **resolved by the primitive design** (the model declares
  a residual; the odelia-owned implicit-node injects) — but the primitive must be *wired* so a plant rate
  path triggers it during replay without a model-held tape handle. Verify with P1a on a plant-shaped toy.
- **CD-G — the integration fixture:** growing dim × injected-derivative-in-replay × the emergent
  functional, FD-checked. The single test that certifies the whole SCM path; build it early, on K93.

## Phase 1 — engine primitives (odelia); P1a–P1d independent → parallel
Each a standalone odelia addition with its own test, no plant dependency.
- **P1a — implicit-node** *(load-bearing; de-risk first).* First-order reverse-through-solve via `fwd<double>` (no nested tapes). Verify on a scalar monotone root + a 2×2 KKT (IFT vs FD ~1e-10). Reserve a registration slot for higher-order partials (Phase 3) — additive, **not** implemented now.
- **P1b — scan-coupling.** Suffix/prefix scans; near-diagonal band `δ` (default 0 + debug exactness check vs `kernel_direct`); Neumaier. Verify: dot-product oracle + `Σ a_p b_p` vs supplied `κ`.
- **P1c — `γ(s,x)` node.** Value + `∂/∂x` + `∂/∂s`; `∂²/∂s²` reserved. FD-validated at init.
- **P1d — `value()` firewall + harness.** `decide`/`diagnostic`; raw `xad::value` grep-banned in Model/Numerics. The reusable harness: frozen-schedule FD, per-edge probes, the dot-product oracle, conservation invariants, the M1 "every seeded param has a partial" gate.
- **P1e — canonical-state + charts (entangled with plant; start odelia-side).** `(xᵢ, log mᵢ, u, accumulators)`; `StateView` charts as taped bijections; `TransportGeometry` = the fixed neighbour-secant ↔ log-mass pairing. Depends on geometric compression (shipped, opt-in). Deletes compression from the model.
- **P1f — `QK<S>` fixed-rule quadrature** (Cluster 4): template `QK::integrate` on the scalar **and the
  bound type** — the nodes are a deterministic affine image of the bound, so an *active* bound (a census
  integrated over an active plant height) tapes exactly through the moving nodes; **differentiate
  through, no recorded positions**. The `double` path is the `S=double` instantiation. (Not L2 — L2 is
  the adaptive light spline only.) Delete the forked `integrate_ad`/`deep_crown_replay` spikes.

Named odelia follow-ups to fold in (from `archive/ad-issues.md`): #22 interpolator unification (the
replayable interpolator owns its own knots — the clean L2), #23 history rows, #27
functional-as-pure-reduction + driver-owns-replay, **#28 (done) — the three-cache record/replay + retire
`live|frozen`** (the model this build plan follows), #25/#26 comments/tests. The odelia-native
demonstrator (a shrink of FF16 resident light) exercises L1/L2 recompute + the L3 read + reuse + the
anti-staleness property against FD.

## Phase 2 — port plant onto the engine, bit-identity-guarded, in difficulty order
Sequential within plant; the critical path to #52 parity. Each strategy is taken **resident-first** up
the ladder (single-metric → multi-variable census → `dR0/db`); the mutant (L3) path is the deferred add.
- **P2a — K93** (simplest: closed-form rates, separable kernel, no inner solve). Uses P1b + P1e. Also the
  **CD-A/CD-G de-risk vehicle** (cheapest full SCM: growing dim + L2 recompute + census). Deletes
  `node.h::growth_rate_gradient`'s active block. Gate: FF16 bit-identity + the K93 census-FD targets
  (`b_0` 317.883, `b_1` −516.881, `cos=1.0`, `design.md` §10).
- **P2b — FF16** (adds crown quadrature = sub-grid field reads via the fixed-rule `QK<S>`, P1f; a
  breakpoint node for particle crossings). **PLANT-11:** fix the zero-height cohort NaN (`0·log(0)`) —
  establish `birth≥N` cohorts at `h0`; carries a test. Port FF16's transport term to `rebind` to inherit
  the shared mass chart (the census tier).
- **P2c — TF24** (the hard one; re-reaches #52 soil coupling). Leaf **residual** (the already-templated
  `assim_colimited_ad`/`hydraulic_cost_ad`) drives the reduced-gradient `G(q)` via N1/N3 as P1a
  scalar-IFT nodes — the **leaf solver stays `double`**, the engine auto-differentiates the residual (no
  per-trait hand `∂profit/∂θ`, the prototype's AD-9 body of work, deleted). `γ` via P1c. **Soil is active
  coupled state** (`StateView.u()`), not a field: resident soil integrates on the multirate sub-cycle
  (its adjoint rides tape-as-run); the `∂profit/∂(soil ψ)` channel is automatic. Deletes the ~150-line FD
  seam + `dsoil_consumption_dpsi_collar_perlayer`. Gate: `test-ad-gate0-tf24.R`,
  `test-ad-tf24-soil-coupling.R`, `test-ad-tf24f-collar-uptake.R` (all currently green — the parity
  target). Long-horizon resident stiffness held by the drift gate + recorded sub-stepping (below).
- **P2d — TF24f** (tracked-`q`). `q` an ODE state, rate `k·G` reusing P2c's `G`. Completes #52 parity.

**PLANT-4a (the resident-recompute correctness point):** the resident gradient must **re-run
`compute_environment` on the recorded L2 light-spline knots** with active cohorts (L2 recompute, L3
empty). Do **not** read the frozen field (that is the mutant/L3 path — silently the invasion gradient,
missing self-shading) and do **not** build a `stand_*_stage_history`. **PLANT-10:**
`d(net_reproduction_ratio)/d(birth_rate)` for the `R0=1` Newton solve (Rung 3; depends on PLANT-4a; feeds
Phase 3). **IC gradients** (`Patch::ad_initial_state`, ledger E) land after P2a's resident core — sequence
them once the L2 recompute path is solid; remove the `scm.h:231` resume stub as the IC path lands.

**Critical path to #52 parity:** (F1/E2 done) → CD-A/CD-B de-risk on IndividualRunner → P1a+P1b+P1c+P1e →
P2a (also CD-A/CD-G on K93-resident) → P2b → P2c → P2d. Fastest visible win: **P2a (K93 resident census)
once P1b+P1e land and CD-A is green.**

## Multirate soil — OUT OF THIS PLAN (pursued independently)
The multirate sub-cycle for the ≤5-state soil block (E2: kink-split at recorded rainfall knots; the
desingularizing coordinate dropped) is **owned by the user and pursued independently** — it is not a
task in this plan and nothing here waits on it. The AD engine neither depends on nor blocks it: resident
TF24 soil coupling (odelia #3) is correct on the shared global step; multirate is a *forward performance*
lift. **The one contract, if it later lands:** keep the soil micro-schedule / kink-splits recorded in
pass 1 and replayed frozen in pass 2 (the "recorded adaptive sub-stepping" shape), so the AD engine can
tape-as-run it with no new adjoint theory. Until then, long-horizon resident-TF24 stiffness is held by
the `tf24_stiffness_drift` **drift gate + runtime caveat** (bounded ~1e-4…1e-3 — a runtime cost, gated,
not a wrong number).

## Phase 3 — the fixed-point / equilibrium layer (secondary, deferred)
Gated on F1 (passed). The steady Eulerian-profile BVP (dim ~4+L) + IFT adjoint of the collocation
residual + the dominant-eigenvalue perturbation identity (one nested `adj⟨fwd⟩` sweep). Reuses the P1a
implicit-node + P1c `γ` node's **reserved** higher-order partials (`∂²γ/∂s²`, differentiated-IFT) —
additive registrations, not a rewrite. TF24f adds one `q`-state pinned by `G=0`, contributing the
`k·dG/dq` relaxation eigenvalue. Serves regnans' selection gradients + the `R0=1` equilibrium. Validate
against FD of the residual-solved equilibrium, **never** a re-march. Honesty conditions: monitor the
spectral gap, the marginally-active pinned set, and the hydraulic-failure cliff — **refuse**, don't
average through.

## Port map — what the new engine deletes/replaces
| current (plant#52) | fate | replacement |
|---|---|---|
| `node.h::growth_rate_gradient` active block (~70 ln) | **delete** | mass chart (compression vanishes) + scan `∂A/∂z` |
| `species.h` geometric-compression loop | **absorb** | the chart's `TransportGeometry` |
| `tf24_strategy.cpp` FD `supplied_derivative` seam (~150 ln) + `leaf_profit_at_fixed_collar` | **delete** | reduced-gradient `G(q)` via P1a nodes (N1, N3) |
| `leaf_model.cpp::dprofit_droot_collar_psi` (hand IFT) | **delete** | falls out of N1+N3 |
| `leaf_model.cpp::dsoil_consumption_dpsi_collar_perlayer` + FD uptake partials | **delete** | γ-node antiderivative difference + breakpoint (Leibniz) |
| interpolator on the coupling path | **replace (separable) / retain (fallback)** | scan; interpolator kept for `FlatTopSoftBox` |
| `get_environment_slope_at_height` frozen surrogate | **delete** | exact `∂A/∂z` from the scan |
| 13 plant headers `#include <XAD/…>` | **reduce to one** | `<odelia/seam.hpp>` |
| scattered `to_passive` (77) | **replace where derivative-relevant** | `decide()`/`diagnostic()` firewall |
| `Solver::reserve_state` | **delete** | unused; growth correct via XAD slot indirection |

## Scope fences (do not silently re-scope in)
The introduction-schedule derivative `d(schedule)/dθ` (decided out — nuisance variable); general
HVP/Hessian (only the fixed-point eigenvalue path); Euler stepping and the stochastic engine
(non-differentiable); the hyperpar trait→param total derivative (v1 gives low-level partials);
leaf-level forward-mode stays plant-local. **In scope, sequenced:** IC gradients; resident TF24/TF24f
soil (via multirate). See `design.md` §11.

## Open before Phase 1 hardens
- **CD-A / CD-G** (growing-dimension active replay + the integration fixture) — the load-bearing
  de-risk, on IndividualRunner then K93-resident.
- The `γ` `∂/∂s` implementation vs FD-fallback (P1c) — low-stakes, decide at build.
- Whether the mass chart is the *default* for gradient runs or stays opt-in (re-baseline the K93 ~0.169% snapshots if default).
- Which of the four leaf early-exits produces the hydraulic-failure cliff (isolate before Phase 3).
- The `∂profit/∂(soil ψ)` channel wiring for resident TF24 (automatic via `u()`, but verify at Gate-0).
