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
- **Each engine primitive ships its own verification before any plant consumer uses it** — the dot-product oracle `⟨Jv,u⟩=⟨v,Jᵀu⟩` for `separable_field`; IFT-vs-FD for the implicit-node; Richardson-FD-vs-analytic for `incomplete_gamma`. The scarce resource (hand-adjoint correctness) defended structurally.
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

**The front-loaded de-risk is now the odelia co-design ledger** (`design.md` §3). The load-bearing
*mechanism* (CD-A, the tape surviving mid-run resize) is **already verified** — so the front-loaded work
is the integration fixture CD-G (compose the confirmed pieces into the plant shape) + CD-B wiring, on the
clean-boundary axis the v2 emphasises:
- **CD-A — growing-dimension active replay** *(mechanism CONFIRMED — the remaining work is CD-G).* Does
  odelia's active tape survive a mid-`run()` `resize()`, taping-once across `[grow][resize][integrate]`?
  **Verified:** `test-ad-growing-resize.R` matches AD to closed-form (1e-8) and FD (1e-6) through
  post-resize cohorts, `reserve_state` on *and* off; the `AReal`-slot-index mechanism (odelia #6) makes
  the tape immune to the realloc move. So this is **not** an open architecture risk. What is left is the
  plant *composition* — CD-G — a new cohort's active ICs (`log_density=log(birth·estab/g)` reading the
  active stand), co-timed multi-species resize, the census over the growing set. **Exercise IC-seeding
  (ledger E) first on `IndividualRunner`** (fixed-dimension, clean single-plant), **then CD-G on
  K93-resident** (the cheapest full SCM: growing dim + L2 recompute + census, no leaf/quadrature).
- **CD-B — tape-from-`ode_rates` injection** is **resolved by the primitive design** (the model declares
  a residual; the odelia-owned implicit-node injects) — but the primitive must be *wired* so a plant rate
  path triggers it during replay without a model-held tape handle. Verify with P1a on a plant-shaped toy.
- **CD-G — the integration fixture:** growing dim × injected-derivative-in-replay × the emergent
  functional, FD-checked. The single test that certifies the whole SCM path; build it early, on K93.

## Phase 1 — engine primitives (odelia); P1a–P1e — **LANDED**
Each a standalone odelia addition with its own test, no plant dependency. All landed and verified on
`claude/odelia-ad-tape-reverse-496fuf` (each ships the dot-product oracle and/or an FD/analytic
self-check): **P1b** `separable_field`, **P1e** `cohort_spacing`/`log_density_rate`, **P1d**
`smooth_positive`/`is_finite` + `decide`/`diagnostic`, **P1a** `register_implicit`, **P1c**
`incomplete_gamma`. Two scoping refinements taken under the witness principle, recorded below:
- **P1a is scalar only.** Every Phase-2 inner solve (leaf `ci` root, collar optimum, birth height) is
  scalar; the dense/nested (KKT, tangent-over-adjoint) case has no witness until the fixed-point BVP
  (Phase 3), where it lands — an unsupported nested scalar type is a `static_assert`, not a silent path.
- **`decide` records in call order for a fixed replay schedule.** The commit-per-accepted-step wrapping
  that makes it exact across an *adaptive* recording pass (discarding rejected steps) belongs with the
  SCM System (P2a), like a recorded field's commit.

P1f (`QK<S>` templating) is plant-side and applies at P2b (see the ledger below).

**Reassessed order (2026-07-17): separable field first, not implicit-node.** The earlier "P1a first,
load-bearing, de-risk first" put the implicit-node at the front because the scary unknown was whether
the tape survives the growing-dimension resize / `ode_rates` injection. **That is now closed** (CD-A
verified — `test-ad-growing-resize.R`). So the front of Phase 1 optimises instead for the *shortest path
to one end-to-end verified resident gradient* — **K93 resident census**, the first visible win. K93 has
**no inner solve**, so P1a/P1c are not on its path (they are TF24 machinery, P2c). The K93 path is
**P1b (separable field) → P1e (mass transport) → P2a/CD-G**. Build order: **P1b, then P1e, then P1d (light,
structural), then P2a**; P1a+P1c land just before P2c, P1f with P2b. CD-B (tape-from-`ode_rates`) rides
P1a and is verified on a plant-shaped toy when P1a lands, not up front.

- **P1b — `separable_field`** *(first; the v2 core — **LANDED**).* Descending suffix scans build the field `A` and its query slope `∂A/∂z` from the separable factors; exact, non-adaptive. Verified: rank-3 separability, field/slope vs the direct O(N²) sum, and the dot-product oracle `⟨Jv,u⟩=⟨v,Jᵀu⟩` to machine precision (`odelia::separable_field`, `test-ad-separable-field.R`). *Deferred within P1b (noted):* the near-diagonal direct band `δ` and Neumaier compensation (robustness at high η), and the custom vectorised transpose (a tape-memory optimisation whose correctness target is the verified taped version).
- **P1a — `register_implicit`** *(**LANDED**).* First-order reverse-through-solve: `dy/dp = -(dF/dp)/(dF/dy)` by forward-differentiating the residual at the root, carried through double/forward/reverse, no nested tape; sign of `dF/dy` asserted; unsupported nested type a `static_assert`. **Scalar** (covers every Phase-2 solve); dense/nested reserved for Phase 3. Verified: reverse gradient vs analytic, IFT vs re-solve FD, the oracle (`test-ad-implicit-node.R`).
- **P1c — `incomplete_gamma`** *(**LANDED**; was "the γ node").* Lower incomplete gamma via the elementary everywhere-convergent series, so AD gives value + `∂/∂x` (the integrand/Leibniz endpoint) + `∂/∂a` (shape) off the same code — no hand digamma, no supplied-partial node. `∂²` reserved (Phase 3). Verified vs `pgamma`, the integrand, an FD, and the exact Weibull endpoint (`test-ad-incomplete-gamma.R`).
- **P1d — value guards** *(**LANDED**).* `smooth_positive(x,r)` (canonical, plant's own formula — bit-identical) + ADL `is_finite`; `decide`/`diagnostic` (`test-ad-value-guards.R`, `test-ad-decide.R`). The `xad::value`/`to_passive` grep ban switches on with the plant port (P2a). The harness (frozen-schedule FD, per-edge probes, dot-product oracle, M1 gate) is folded into each primitive's test.
- **P1e — mass transport** *(**LANDED**).* `cohort_spacing` + `log_density_rate`; `C = cohort_spacing(g)/cohort_spacing(x)` shares the reduction operator by construction, so the compression cancels in value *and* parameter derivative. Verified: the cancellation identity, the secant vs analytic `dg/dx`, the oracle (`test-ad-mass-transport.R`). Deletes the model transport term. *(No `StateView`/`TransportGeometry` nouns.)*
- **P1f — `QK<S>` fixed-rule quadrature** (Cluster 4): template `QK::integrate` on the scalar **and the
  bound type** — the nodes are a deterministic affine image of the bound, so an *active* bound (a census
  integrated over an active plant height) tapes exactly through the moving nodes; **differentiate
  through, no recorded positions**. The `double` path is the `S=double` instantiation. (Not L2 — L2 is
  the adaptive light spline only.) **This is the v1 treatment** (the prototype already templated `qk.h`);
  it **stays plant's `qk.h`** — *not* moved to odelia (generic fixed-rule quadrature, one witness; defer
  the lift to a 2nd consumer). Delete the forked `integrate_ad`/`deep_crown_replay` spikes; don't touch
  the dormant adaptive `QAG`.

Named odelia follow-ups to fold in (from `archive/ad-issues.md`): #22 interpolator unification (the
replayable interpolator owns its own knots — the clean L2), #23 history rows, #27
functional-as-pure-reduction + driver-owns-replay, **#28 (done) — the three-cache record/replay + retire
`live|frozen`** (the model this build plan follows), #25/#26 comments/tests. The odelia-native
demonstrator (a shrink of FF16 resident light) exercises L1/L2 recompute + the L3 read + reuse + the
anti-staleness property against FD.

## Existing engine pieces (audited — see [`odelia-5-existing-pieces.md`](./odelia-5-existing-pieces.md))
The generic AD surface (Solver, gradient driver, functionals, record/replay, IC seeding,
growing-dimension) already exists and mostly needs no change. The audit adds these to the plan so it is
comprehensive:
- **Solver/SCM seam (Phase 1) — no new concept** (odelia #6). The SCM keeps its self-segmenting `run()`
  (HAS-A `Solver`, owns the `[grow][resize][integrate]` loop); the gradient driver keeps duck-typing it.
  Document the ~5 required methods in a **call-site comment** on `compute_jacobian`; the growing-dimension
  guarantee is the existing `test-ad-growing-resize.R`. **No `Runnable` concept / `static_assert`** — a
  `concept` can't check the runtime resize guarantee, so it would add a name without removing a bug class.
  **Deferred cleanup (1 witness):** odelia `Solver` owns the introduction loop → the SCM becomes a plain
  System; retrofit trigger = a 2nd growing-dimension System.
- **Interpolator simplification (with P1b).** `separable_field` (P1b) takes the separable coupling field and the
  mass chart takes `dg/dh`, so the interpolator demotes to the **non-separable fallback only** — **delete**
  its coupling-era bandaids (the frozen active-query derivative, the geometric-compression entanglement);
  keep clean construct/record/replay. Do **not** lift QAG into odelia (no adaptive-quadrature witness —
  crown is fixed-rule `QK`, P1f).
- **Multi-metric census test (Phase 2, high).** Verify the multivariate case we need: a
  multi-metric/multi-variable/**multi-species** resident-census Jacobian (persona 1: LAI+biomass+basal-area
  vs LMA+wood-density), FD-free-checked by the `compute_jvp` dot-product oracle + Gate-0 FD.
- **IC gradient (sequenced after the resident core).** Rests on **plant#499 / `78bd39`** (seed an initial
  size distribution at patch age 0 — landed). Wire `Patch::ad_initial_state()` to the age-0 seeded node
  states + a test; the resume-from-mid-run case stays fenced (the `scm.h:231` replay conflict).
- **Evaluate-then-decide (med/low)** (odelia #6). *Checkpointing:* measure peak tape memory on the
  largest resident census; if it breaches the budget (v1's one-tape run fit 0.5–4 GB) checkpoint at the
  node-introduction boundary using the **vendored `XAD::CheckpointCallback`** (reuse, no new abstraction).
  *`reserve_state`:* the spike shows the resize is amortized-O(N) slot-index-preserving POD moves (the
  tape is immune), so **delete `reserve_state`** unless a profile surprises us (then keep-and-call).
  Neither on the critical path; net **0 new named concepts**.
- **Naming pass (low).** Prose: bare "driver" → "**gradient driver**" (`compute_*`), distinct from the
  Solver *driving* the stepper and from `ExtrinsicDrivers` (forcings); glossary line; audit the odelia demo
  systems' driver members.
- **L0/L1:** done (adaptive-record → fixed-replay); confirm the SCM `run()` interleaves L0 introductions
  with L1 `advance_fixed` on the active replay (a test assertion). L3 deferred.

## Phase 2 — port plant onto the engine, bit-identity-guarded, in difficulty order
Sequential within plant; the critical path to #52 parity. Each strategy is taken **resident-first** up
the ladder (single-metric → multi-variable census → `dR0/db`); the mutant (L3) path is the deferred add.

**Open — the plant base to port from is undecided.** #52 carries the v1 prototype; `develop` (or an
earlier commit) does not. Which we branch Phase 2 from is a later decision, so every plant anchor below
and in the Port map is **symbolic** (file / function name), resolved to line numbers only once the base
is chosen. Nothing here is applied until Phase 2 begins; odelia primitives land first.

**Plant port ledger (all Phase-1 primitives landed; here is the plant edit each enables — status
*enabled*, not yet *applied*).** The primitive exists and is verified in odelia; the plant change waits
for Phase 2:
- **`separable_field` (P1b).** Replaces `species.h::compute_competition`, the coupling-path interpolator
  read, and `get_environment_slope_at_height`; the strategy declares `{a_p,b_p}` + `kernel_direct`.
  Applies at P2a (K93) / P2b (FF16 crown).
- **mass transport (P1e).** Deletes `node.h::growth_rate_gradient`, absorbs the
  `node_geometric_compression` loop; reduction weights must read `cohort_spacing` (the shared operator).
  Applies at P2a.
- **`smooth_positive` / `is_finite` (P1d).** Plant `util::smooth_positive` magic radii → the canonical
  declared-radius form (**bit-identical formula**); double-only guard sites → ADL `is_finite`. Per strategy.
- **`decide` / `diagnostic` (P1d).** Value-branches (net-production sign, PPA layer index, `height_max`,
  leaf shut-down early-exits) → `decide`; dead `to_passive` reads → `diagnostic`. The commit-per-accepted-
  step wrapping (adaptive recording) and the `xad::value`/`to_passive` grep ban land wired into the SCM at P2a.
- **`register_implicit` (P1a), `incomplete_gamma` (P1c).** The TF24 leaf/soil deletions (FD seam, hand
  IFTs, hydraulic splines, `psi_soil_cache_`); apply at P2c. **`QK<S>` (P1f)** is plant's `qk.h`
  templating; applies at P2b.

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
  per-trait hand `∂profit/∂θ`, the prototype's AD-9 body of work, deleted). `incomplete_gamma` via P1c. **Soil is active
  coupled state** (the leaf reads the soil state directly), not a field: resident soil integrates on the multirate sub-cycle
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

**Critical path to #52 parity (reassessed):** (F1/E2 done; CD-A verified; **all Phase-1 primitives
landed**) → **[decide the plant base]** → **P2a/CD-G (K93 resident census — the first visible win +
integration fixture)** → **P2b (FF16, +P1f)** → **P2c (TF24, applies P1a+P1c)** → **P2d (TF24f)**.
IC-seeding on IndividualRunner sequences after P2a's resident core. **The next gate is the plant-base
decision** (#52 vs develop vs earlier), not any further odelia primitive.

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
implicit-node + P1c `incomplete_gamma`'s **reserved** higher-order partials (`∂²γ/∂s²`, differentiated-IFT) —
additive registrations, not a rewrite. TF24f adds one `q`-state pinned by `G=0`, contributing the
`k·dG/dq` relaxation eigenvalue. Serves regnans' selection gradients + the `R0=1` equilibrium. Validate
against FD of the residual-solved equilibrium, **never** a re-march. Honesty conditions: monitor the
spectral gap, the marginally-active pinned set, and the hydraulic-failure cliff — **refuse**, don't
average through.

## Port map — what the new engine deletes/replaces
Symbolic anchors (base commit TBD — see the Phase 2 note). Line counts are the #52-prototype's, indicative.
| current plant site | fate | replacement |
|---|---|---|
| `node.h::growth_rate_gradient` active block (~70 ln) | **delete** | mass chart (compression vanishes) + `separable_field` `∂A/∂z` |
| `species.h` geometric-compression loop | **absorb** | the mass transport rule |
| `tf24_strategy.cpp` FD `supplied_derivative` seam (~150 ln) + `leaf_profit_at_fixed_collar` | **delete** | reduced-gradient `G(q)` via P1a nodes (N1, N3) |
| `leaf_model.cpp::dprofit_droot_collar_psi` (hand IFT) | **delete** | falls out of N1+N3 |
| `leaf_model.cpp::dsoil_consumption_dpsi_collar_perlayer` + FD uptake partials | **delete** | `incomplete_gamma` antiderivative difference + breakpoint (Leibniz) |
| interpolator on the coupling path | **replace (separable) / retain (fallback)** | `separable_field`; interpolator kept for `FlatTopSoftBox` |
| `get_environment_slope_at_height` frozen surrogate | **delete** | exact `∂A/∂z` from `separable_field` |
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
- **CD-G** (the integration fixture: active ICs × multi-species resize × census over the growing set) —
  the remaining growing-dimension work now that CD-A's mechanism is verified; on K93-resident.
- The `incomplete_gamma` `∂/∂s` implementation vs FD-fallback (P1c) — low-stakes, decide at build.
- Whether the mass chart is the *default* for gradient runs or stays opt-in (re-baseline the K93 ~0.169% snapshots if default).
- Which of the four leaf early-exits produces the hydraulic-failure cliff (isolate before Phase 3).
- The `∂profit/∂(soil ψ)` channel wiring for resident TF24 (automatic via `u()`, but verify at Gate-0).
