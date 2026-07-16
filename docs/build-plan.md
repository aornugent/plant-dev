# The odelia AD engine — build plan

Companion to [`design.md`](./design.md) (the *what*/*why*). This is the *how* and *in what order*: a
phased, parallelizable sequence that re-reaches the current plant#52 feature set (all four strategies
reverse-mode + TF24 soil coupling) on the clean engine, then the fixed-point layer. Supersedes the
archived `ad-engine-build-plan.md`; folds in the delivery ladder, the risk gates, and the build/test
mechanics surfaced from the prototype docs.

## Two axes: phases (primitives → strategies) × the delivery ladder (subgraph difficulty)

Progress is fastest when the two axes are worked together. The **delivery ladder** orders the *Jacobian
rows* by which touch the hardest barrier:

- **Rung 1 — mutant invasion-fitness** (frozen resident field, **no `∂g/∂h`**): the easiest subgraph;
  ships first and in parallel with the transport work. This is the selection-gradient persona.
- **Rung 2 — resident R0 / trait sensitivity**: adds the self-shading coupling (the L3 recompute) and
  `birth_rate`; still no census density factor on the output.
- **Rung 3 — census metrics (LAI/biomass/basal-area)**: the **only** tier needing `∂g/∂h` robust (the
  mass chart). Last, and gated on PROTO-2.

## Standing constraints (hold on every landing)
- **Bit-identity guard.** Nothing lands that moves the `double` path: `test-strategy-ff16(-reference-comparison).R`, the K93 "offspring production unchanged" snapshots, `test-control.R` (pins the Control field set). A changed number = broken bit-identity; **diff the FP order, not just the value.** (Sanctioned exception: the mass chart's ~0.169% K93 shift, opt-in for gradient runs.)
- **Each engine primitive ships its own verification before any plant consumer uses it** — the dot-product oracle `⟨Jv,u⟩=⟨v,Jᵀu⟩` for the scan; IFT-vs-FD for the implicit-node; Richardson-FD-vs-analytic for `γ`. The scarce resource (hand-adjoint correctness) defended structurally.
- **Gate-0 is the oracle; the census metric is not.** Verify the active path at single-leaf/single-cohort clean FD (swept over δ). Never trust `compute_competition(0)` census FD (~%-noisy, fooled the prototype repeatedly).
- **UX-2 fixture gate.** Snapshot validated Jacobians to `tests/testthat/fixtures/gradient-baseline.rds` (two-tier tolerance). **Nothing merges without UX-2 green** — the AD-vs-AD regression net, distinct from Gate-0.
- **The one cross-track contract.** The engine must **tape the scheme as run** with a frozen, replayable control-flow schedule (L0–L2). Any parallel track (multirate) must keep its micro-schedule / event / pin decisions recordable in pass 1 and replayable in pass 2.
- **Build/test mechanics** (survival-critical — from `archive/ad-handover.md`): reinstall `odelia` after ANY odelia header edit (plant compiles against *installed* headers, not the submodule tree); `Sys.setenv(TESTTHAT_PARALLEL="false")`; build optimised once (`cd plant && make`, `-O2`) then `load_all` reuses the `.so`; regenerate RcppR6 only when adding/removing a registered field; on `undefined symbol`, `rm src/*.o src/*.so` and reinstall.

## Phase 0 — validate the biggest bets (pure `double`, no build) — **DONE**
See [`phase0-results.md`](./phase0-results.md). **F1** confirmed the fixed-point route (Eulerian
transport operator faithful to the march, residual 8.6e-6; steady profile well-posed). **E2** redirected
the soil track (drainage/potential envelopes don't share a shape — 32 OOM; the desingularizing chart
makes it *worse*, 0.30–0.47×; kink-split cuts rejections 1.85×). Two Gate-0 deepening checks: **A**
(mass-chart stability) passed (bounded at the default clamp, 0.169% shift); **B** (leaf early-exit C⁰)
**refuted** the continuity assumption (a true ~1.46 profit jump → an honesty-condition refuse point, not
a breakpoint).

**Remaining Phase-0-class de-risk (front-loaded):**
- **PROTO-2 — the rescope gate.** Confirm the full-scalar `run_mutant` replay captures the
  density→optimum cross-term for TF24 (the census tier). **A refutation rescopes TF24 census out of
  v1.** Front-load it before committing to Rung 3 for TF24.
- **GAP A — resize on the active tape.** Verify odelia's active replay against mid-run `resize()`
  (cohort introductions grow the state; new-cohort ICs are an active function of the integrated stand;
  co-timed multi-species introductions resize several blocks at once). The hazard that could invalidate
  "the SCM is the runnable." Cheap to probe; do before Phase 2.

## Phase 1 — engine primitives (odelia); P1a–P1d independent → parallel
Each a standalone odelia addition with its own test, no plant dependency.
- **P1a — implicit-node** *(load-bearing; de-risk first).* First-order reverse-through-solve via `fwd<double>` (no nested tapes). Verify on a scalar monotone root + a 2×2 KKT (IFT vs FD ~1e-10). Reserve a registration slot for higher-order partials (Phase 3) — additive, **not** implemented now.
- **P1b — scan-coupling.** Suffix/prefix scans; near-diagonal band `δ` (default 0 + debug exactness check vs `kernel_direct`); Neumaier. Verify: dot-product oracle + `Σ a_p b_p` vs supplied `κ`.
- **P1c — `γ(s,x)` node.** Value + `∂/∂x` + `∂/∂s`; `∂²/∂s²` reserved. FD-validated at init.
- **P1d — `value()` firewall + harness.** `decide`/`diagnostic`; raw `xad::value` grep-banned in Model/Numerics. The reusable harness: frozen-schedule FD, per-edge probes, the dot-product oracle, conservation invariants, the M1 "every seeded param has a partial" gate.
- **P1e — canonical-state + charts (entangled with plant; start odelia-side).** `(xᵢ, log mᵢ, u, accumulators)`; `StateView` charts as taped bijections; `TransportGeometry` = the fixed neighbour-secant ↔ log-mass pairing. Depends on geometric compression (shipped, opt-in). Deletes compression from the model.
- **P1f — `QK<S>` moving-node quadrature** (ODELIA-6): a scalar-templated fixed-rule quadrature consuming a recorded QAG subdivision — the L2 moving-node level a frozen-node replay drops. Needed for census-over-height.

Named odelia follow-ups to fold in (from `archive/ad-issues.md`): #22 interpolator unification, #23
history rows, #27 functional-as-pure-reduction + driver-owns-replay, #28 pare the demonstrator (retire
`live|frozen`), #25/#26 comments/tests. An odelia-native demonstrator (a shrink of FF16 resident light)
exercises L1/L2/L3 + reuse + the anti-staleness property against FD.

## Phase 2 — port plant onto the engine, bit-identity-guarded, in difficulty order
Sequential within plant; the critical path to #52 parity. Work each strategy up the delivery ladder
(mutant → resident → census).
- **P2a — K93** (simplest: closed-form rates, separable kernel, no inner solve). Uses P1b + P1e. Deletes `node.h::growth_rate_gradient`'s active block. Gate: FF16 bit-identity + the K93 census-FD targets (`b_0` 317.883, `b_1` −516.881, `cos=1.0`, §design 10).
- **P2b — FF16** (adds crown quadrature = sub-grid field reads). Separable field read directly + a breakpoint node for particle crossings; the moving-node `QK<S>` (P1f) for census-over-height. **PLANT-11:** fix the zero-height cohort NaN (`0·log(0)`) — establish `birth≥N` cohorts at `h0`; carries a test. **FF16 `∂g/∂h`:** port to `rebind` to inherit the shared geometric compression (the census tier).
- **P2c — TF24** (the hard one; re-reaches #52 soil coupling). Leaf inner solve → the reduced-gradient `G(q)` with N1/N3 as P1a scalar-IFT nodes; `γ` via P1c; soil via `StateView.u()`. Deletes the ~150-line FD seam + `dsoil_consumption_dpsi_collar_perlayer`. Soil stays explicit on the recorded schedule (multirate is the parallel track). Gate: `test-ad-gate0-tf24.R`, `test-ad-tf24-soil-coupling.R`, `test-ad-tf24f-collar-uptake.R` (all currently green — the parity target). **TF24 census tier gated on PROTO-2.**
- **P2d — TF24f** (tracked-`q`). `q` an ODE state, rate `k·G` reusing P2c's `G`. Completes #52 parity.

**PLANT-4a (the resident/invasion trap):** the resident gradient must **re-run `compute_environment` on
the recorded light-spline knots** with active cohorts (L3 recompute). Do **not** read the frozen field
(silently the invasion gradient) and do **not** build a `stand_*_stage_history`. **PLANT-10:**
`d(net_reproduction_ratio)/d(birth_rate)` for the `R0=1` Newton solve (depends on PLANT-4a; feeds Phase 3).

**Critical path to #52 parity:** (F1/E2 done) → P1a+P1b+P1c+P1e → P2a → P2b → P2c → P2d. Fastest visible
win: **P2a (K93) once P1b+P1e land**; in parallel, **Rung 1 mutant fitness** for FF16/TF24 needs no
`∂g/∂h` and can ship early.

## Parallel independent track — multirate soil, forward only (no gradients)
Sub-cycle the ≤5-state soil block within the SCM step + kink-split at recorded rainfall knots (E2:
1.85× fewer rejections) + the E2 desingularizing coordinate is **dropped** (E2 verdict: it makes it
worse). Gated only on E2 (done). **Interface contract:** keep the micro-schedule / kink-splits /
pin-times recorded in pass 1, replayed frozen in pass 2, so the AD engine can tape-as-run later with no
new adjoint theory. Adopt `tf24_stiffness_drift` as a standing **drift gate + runtime caveat** (stiffness
is bounded ~1e-4…1e-3, a runtime cost not an error — not a hard defer).

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
IC gradients beyond birth-rate (resume-vs-replay conflict); general HVP/Hessian (only the fixed-point
eigenvalue path); adaptive sub-stepping inside replay (gate with a clear error); leaf-level forward-mode
stays plant-local; the hyperpar trait→param total derivative. See `design.md` §11.

## Open before Phase 1 hardens
- PROTO-2 (TF24-census viability) and GAP A (active-tape resize) — front-loaded de-risk.
- The `γ` `∂/∂s` implementation vs FD-fallback (P1c) — low-stakes, decide at build.
- Whether the mass chart is the *default* for gradient runs or stays opt-in (re-baseline the K93 ~0.169% snapshots if default).
- Which of the four leaf early-exits produces the hydraulic-failure cliff (isolate before Phase 3).
