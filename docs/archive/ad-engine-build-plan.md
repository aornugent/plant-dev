# AD-engine build plan — from the v2 design to plant#52 feature-parity, and beyond

Companion to [`ad-engine-surface-design.md`](./ad-engine-surface-design.md) (the *what*/*why*). This
is the *how* and *in what order*: a phased, parallelizable sequence that re-reaches the current
plant#52 feature set (all four strategies reverse-mode + TF24 soil coupling) on the clean engine,
with the fixed-point layer and gradient-free multirate as separable tracks that the AD engine is
built to accommodate later.

## Standing constraints (hold on every landing)
- **Bit-identity guard.** Nothing lands that moves the `double` path: `test-strategy-ff16.R`
  (reference numbers), the K93 "offspring production unchanged" snapshots, `test-control.R`. A changed
  number = broken bit-identity; diff the FP order, not just the value. (Exception, documented: the
  mass chart's geometric-compression forward shift, ~0.2% on K93, opt-in for gradient runs.)
- **Each engine primitive ships its own verification before any plant consumer uses it** — the
  dot-product oracle `⟨Jv,u⟩=⟨v,Jᵀu⟩` (`compute_jvp`, odelia#40) for the scan; IFT-vs-FD for the
  implicit-node; Richardson-FD-vs-analytic for `γ`. This is the scarce resource (hand-written-adjoint
  correctness) defended structurally.
- **Verify the active path at Gate-0** (single leaf/individual, clean FD), never the noisy census
  metric — the load-bearing lesson from `ad-handover.md`.
- **The one cross-track contract:** the AD engine must be able to *tape the scheme as run* with a
  frozen, replayable control-flow schedule. Any parallel track (multirate) must keep its
  micro-schedule / event / pin decisions recordable in pass 1 and replayable in pass 2, or the engine
  cannot differentiate it later. This is the single interface the deferred/parallel tracks owe.

## Phase 0 — validate the two biggest bets (pure `double`, no build, no tape; do first)
Neither needs the engine; each kills-or-confirms the largest unproven claim in a regime.
- **F1 — the fixed-point route.** Bin one converged marched state to a profile `n(x)`; evaluate the
  Eulerian-profile BVP residual on it. Small residual ⇒ the Eulerian object matches the march ⇒ the
  whole fixed-point layer (Phase 3) is live; then solve the BVP cold and compare. Hours, R only.
- **E2 — the desingularizing coordinate.** Offline soil-block microscopy through recorded drawdown
  windows: original vs `z=Φ(u)` vs kink-split, matched accuracy; fit the singular exponent `a`
  (`log|ψ|` vs `log(θ−θ_res)`); **check whether `K(θ)` and `ψ(θ)` share one envelope** (if not, one
  chart only partly desingularizes). Pure R.
- **F2 (informative) — transient schedule-sensitivity size.** Base-θ-schedule FD vs re-adapted FD on a
  depletion-timing `θ`-component; sizes the dropped frozen-schedule term (the top transient risk).

Gate: F1 result decides whether Phase 3 is a BVP layer (route ii) or the renewal-map fallback (route
i); E2 decides the soil coordinate for the multirate track.

## Phase 1 — engine primitives (odelia); P1a–P1d are independent → parallel
Each is a standalone odelia addition with its own test, no plant dependency.

- **P1a — implicit-node primitive** *(load-bearing; de-risk first).* `register(residual F(y;p),
  double solver, outputs)`; forward solves at `double` (untaped); adjoint forms `∂F/∂y, ∂F/∂p` by
  `fwd<double>` over the templated residual, small dense solve, `incrementAdjoint`. Sign-definite
  denominator asserted at registration. **Verify on a toy** (a scalar monotone root and a 2×2 KKT):
  IFT adjoint vs FD to ~1e-10. This proves *reverse-through-inner-solve without nested tapes* — the
  odelia#36 sidestep. Interface note: leave a **registration slot for higher-order partials** (used
  only by Phase 3) so adding them later is additive, not a rewrite — but do **not** implement them now
  (no HVP until needed).
- **P1b — scan-coupling primitive.** Separable factors `{a_p(z), b_p(x)}` → descending suffix scans
  `B_p` → reads `A(xᵢ)=Σ_p a_p B_p` and `∂A/∂z=Σ_p a_p′ B_p`; reverse = mirrored prefix scans;
  **near-diagonal direct band** (threshold `δ`, default 0, + debug exactness check vs the unexpanded
  kernel — resolves the recombination-cancellation hazard). Neumaier summation. Verify: dot-product
  oracle on a toy ordered population; init-time `Σa_pb_p` vs a supplied direct `κ`.
- **P1c — `γ(s,x)` node.** Value + `∂/∂x` (elementary) + `∂/∂s` (series + digamma / continued-fraction
  large-`x`), FD-validated at init. `∂²/∂s²` deferred (Phase 3) but the node interface reserves it.
- **P1d — `value()` firewall + harness.** `decide(expr)` (predicate, replays recorded decision on pass
  2) and `diagnostic(expr)` (dead to the tape); raw `xad::value` grep-banned in model/numerics. Plus
  the reusable verification harness: frozen-schedule FD (T1), per-edge adjoint probes (T3), the
  dot-product oracle, the mass/moment conservation invariants as standing gradient tests.
- **P1e — canonical-state transport + charts-as-views (odelia; entangled with plant, start on the
  odelia side).** Engine-owned `(xᵢ, log mᵢ, u, accumulators)`; `StateView` charts
  (density/log-density/`S`/`A`/`∂A/∂z`) as taped bijections; the `(neighbour-secant ↔ log-mass)`
  `TransportGeometry` as a fixed pairing (not a policy object). Depends on geometric compression
  (already shipped, opt-in). This is what deletes compression from the model.

## Phase 2 — port plant onto the engine, bit-identity-guarded, in difficulty order
Sequential within plant; the critical path to #52 parity. Each strategy lands behind the guards above.

- **P2a — K93** (simplest: closed-form rates, separable kernel, **no inner solve**). Uses P1b + P1e.
  **Deletes** `node.h::growth_rate_gradient`'s active/rebind path (~70 lines: the `strategy_has_rebind`
  fork, the `FReal<value_type>` scratch build, the `field_ptrs` promotion, the `dE/dh` secant +
  θ-detach, the `dgdh − value(dgdh) + fd_value` splice) — replaced by: mass chart (compression *gone*
  from the rate) + scan (`A`, `∂A/∂z` exact). The `species.h` geometric-compression block becomes the
  chart's transport geometry. Gate: FF16 bit-identity + the K93 census-FD numbers in
  `ad-census-gradients.md` §7 (`b_0` 317.883, `b_1` −516.881, `cos(ad,fd)=1.0`).
- **P2b — FF16** (adds crown quadrature = sub-grid field reads). The separable field is closed-form at
  any `z`, so crown integrals read it directly + a breakpoint node for particle crossings — **no
  spline on the coupling path** (interpolator retained only for non-separable canopy modes,
  `FlatTopSoftBox`). Uses P1b + the breakpoint node (a P1a instance).
- **P2c — TF24** (the hard one; re-reaches the #52 soil coupling). The leaf inner solve becomes the
  **reduced-gradient `G(q)=dW/dq`** with `v,w` as P1a scalar-IFT nodes and `q*` a third; `γ` via P1c;
  soil coupling via `StateView.u()` + the aggregated sink `σ`. **Deletes** the tf24_strategy.cpp FD
  seam (~150 lines, the `supplied_derivative` inputs/partials/`shouldRecord` machinery, ~lines
  508–688 + `leaf_profit_at_fixed_collar` 731–808) and the hand-derived
  `leaf_model.cpp::dsoil_consumption_dpsi_collar_perlayer` (→ antiderivative-difference + breakpoint
  Leibniz, automatic). **Soil stays explicit on the recorded schedule** (multirate is the parallel
  track); implicit-`u` is the validation-gated fallback. Gate: `test-ad-gate0-tf24.R`,
  `test-ad-tf24-soil-coupling.R`, `test-ad-tf24f-collar-uptake.R` (all currently green — the parity
  target).
- **P2d — TF24f** (tracked-`q`). `q` becomes an ODE state with rate `k·G` reusing P2c's `G`; the
  acclimation. Completes #52 parity.

**Critical path to #52 parity:** F1/E2 (optional-but-cheap) → P1a + P1b + P1c + P1e → P2a → P2b →
P2c → P2d. Fastest visible progress: **P2a (K93 on the clean engine)** once P1b + P1e land.

## Parallel independent track — multirate soil, forward only (no gradients)
Pursue the soil performance fix (sub-cycle the ≤5-state soil block within the SCM step + kink-split at
recorded rainfall knots + the E2 desingularizing coordinate) as a **forward-model** improvement,
decoupled from the AD rebuild. Gated only on E2. **Interface contract (the cross-track owe):** keep
the micro-schedule, kink splits, and pin/event times **recorded in pass 1 and replayed frozen in pass
2**, so the AD engine (Phase 1/2 checkpointed record/replay) can tape-as-run and differentiate it
later with no new adjoint theory. If that contract holds, wiring gradients through multirate is a
later, mechanical step — nothing in Phases 1–2 forecloses it.

## Phase 3 — the fixed-point / equilibrium layer (secondary, deferred)
Gated on F1. The steady Eulerian-profile BVP (dim ~4+L) + IFT adjoint of the collocation residual +
the dominant-eigenvalue perturbation identity (one nested `adj⟨fwd⟩` sweep). Serves regnans'
selection gradients. **How Phases 1–2 accommodate it without rework:** the model surface is
representation-agnostic closed forms, so the BVP is a *second thin numerics layer over the same Layer
M*; it reuses the P1a implicit-node and P1c `γ` node; the only additions are the reserved higher-order
partials (`∂²γ/∂s²`, differentiated-IFT) — **additive registrations, not a primitive rewrite** (why
P1a/P1c reserve the slot). Validate against FD of the residual-solved equilibrium, never a re-march.

## Port map — what the new engine deletes/replaces in the current code
| current (plant#52) | fate | replacement |
|---|---|---|
| `node.h::growth_rate_gradient` active block (~70 ln) | **delete** | mass chart (compression vanishes) + scan `∂A/∂z` |
| `species.h` geometric-compression loop | **absorb** | the chart's `TransportGeometry` |
| `tf24_strategy.cpp` FD `supplied_derivative` seam (~150 ln) | **delete** | reduced-gradient `G(q)` via P1a nodes |
| `leaf_model.cpp::dsoil_consumption_dpsi_collar_perlayer` | **delete** | antiderivative-difference + breakpoint node |
| interpolator on the coupling path | **replace (separable) / retain (fallback)** | scan; interpolator kept for `FlatTopSoftBox` |
| 13 plant headers `#include <XAD/…>` | **reduce to one** | `<odelia/seam.hpp>` |
| scattered `to_passive` (77) | **replace where derivative-relevant** | `decide()`/`diagnostic()` firewall |
| `Solver::reserve_state` | **delete** | unused; growth correct via XAD slot indirection |

## Open before Phase 1 hardens
- ~~F1/E2 results (Phase 0)~~ **DONE 2026-07-16** — see [`phase0-results.md`](./phase0-results.md).
  F1: the Eulerian transport operator is faithful to the march (median residual 8.6e-6) and the
  steady profile is well-posed → **Phase 3 as route (ii) confirmed viable**. E2: the two soil
  envelopes do not share a shape (32 OOM) and every desingularizing chart *increased* cost
  (0.30–0.47×) → **drop the coordinate item; keep multirate sub-cycle + kink-split** (the latter cut
  rejections 1.85×).
- The `γ` `∂/∂s` implementation vs FD-fallback (P1c) — low-stakes, decide at build.
- Whether P2a's mass chart is adopted as the *default* for gradient runs or stays opt-in (re-baseline
  the K93 ~0.2% snapshots if default).
