# Phase 0 validation results (F1, E2) — run 2026-07-16

The two pre-build experiments from [`ad-engine-build-plan.md`](./ad-engine-build-plan.md)
§"Phase 0". Both are pure `double`, no tape, no engine. Scripts:
[`scripts/f1-eulerian-transport.R`](../scripts/f1-eulerian-transport.R),
[`scripts/e2-soil-microscopy.R`](../scripts/e2-soil-microscopy.R). Reproduce: `Rscript` each
from the `plant-dev` root (F1 needs `plant` built — `cd plant && make` once, then it loads via
`pkgload::load_all`).

## F1 — is the fixed-point (Eulerian steady-profile) route live? **YES.**

`node.h` transports log-density along each characteristic as `d(log n)/dt = -dg/dx - mu` — exactly
the characteristic form of the Eulerian PDE `d_t n + d_x(g n) + mu n = 0`. So the Eulerian *spatial*
operator is faithful to the march iff the analytic `dg/dx` the node uses matches a finite-difference
of the marched growth `g(x)` across the binned cohort profile. Ran a K93 SCM (106 cohorts,
`max_patch_lifetime=35.1`, `birth_rate=20`), took `heights` + `log_densities` + `ode_rates`, pulled
competition `B(x)` from plant's own interpolator.

- **Operator faithfulness: median relative residual `dg/dx`(FD-of-march) vs closed-form = 8.6e-6**
  (over 105 of 106 nodes; the lone outlier is the growth-zero crossing where the relative metric is
  undefined). The Eulerian object *matches the march*.
- **Transience:** `|d_t log n| ≈ |dg/dx|` (ratio 1.02) on the single-patch snapshot — a single patch
  is genuinely transient, confirming the steady state is a *separate cold solve*, not a marched
  endpoint (consistent with the design's "the Lagrangian has no fixed point").
- **Steady profile well-posed:** the cold steady density `n = S/g` (survival `S=exp(-∫mu/g)`) is
  finite, positive, and monotone-survival on the growth-positive support, with the expected
  *integrable pile-up* as `x → x_max` (the growth ceiling `g→0`). Route (ii) — differentiate the
  steady BVP built from the same closed forms — is well-posed.

**Verdict:** Phase 3 (the fixed-point / equilibrium layer) rests on a real object. The transport
operator the march already uses IS the Eulerian operator; the steady profile exists and is
well-behaved. Build it as route (ii) (BVP + IFT adjoint), not the renewal-map fallback (route i).
*Caveat:* a fully self-consistent equilibrium `B(x)` (the integro-differential fixed point) was not
solved here — that is Phase-3 work; F1 only had to confirm the operator faithfulness and steady
well-posedness, and it does.

## E2 — is the soil step-collapse a coordinate artifact fixable by one chart? **NO — multirate + kink-split, not a chart.**

Faithful 5-layer soil block (`K_sat=163.04`, `theta_sat=0.428`, `n_psi=6.57`, residual `1e-2`), the
real curves `K(theta)=K_sat(theta/theta_sat)^16.14` (drainage) and `psi=a_psi(theta/theta_sat)^-6.57`
(the potential read), a Dormand-Prince RK45 adaptive stepper, a "reader" state `x`= Σ psi (the N/L
amplifier in miniature).

- **The two singular envelopes do NOT share a shape.** `d psi/d theta ~ theta^-7.57` (diverges as
  `theta→0`) while `d K/d theta ~ theta^+15.14` (vanishes). Their ratio spans **32 orders of
  magnitude** across the feasible range. A single change of variables cannot desingularize both.
- **Every candidate desingularizing chart made it WORSE at matched accuracy.** Charts
  `w=(theta/theta_sat)^q` for `q ∈ {+6.57, +7.57, -6.57}` all *increased* accepted steps to
  **0.30–0.47×** (i.e. 2–3× more steps): a chart that linearises the divergent read blows up the
  drainage-driven state rate, and vice versa — the direct consequence of the non-shared envelopes.
- **Kink-splitting at recorded rainfall knots is a real, cheap win.** Restarting the step at each
  recorded knot cut *rejected* steps **1.85×** (412 → 223) at matched accuracy (functional agreement
  `|dx|` ~1e-7 relative).

**Verdict:** the desingularizing coordinate is NOT the soil lever for this block — demote it (do not
build the Sundman chart as the fix). The primary remedy stays **multirate sub-cycling** of the ≤5
soil states (decouple them from the global step), and **kink-split at recorded forcing knots** is
worth keeping as a cheap adjunct. This *sharpens* the build plan's soil track: chart out, multirate +
kink-split in.
*Caveat:* the toy did not reproduce the plant-measured `corr(log Δt, log d) = -0.91` (got ≈0) — the
5-layer toy pins layers at the residual bound rather than resolving a rich coupled excursion, so it is
a weaker reproduction of the *collapse* than the instrumented plant run. But the envelope/exponent
analysis is analytic (exact from the curves) and the chart comparison is a fair matched-accuracy test,
so the two verdicts stand independently of reproducing that correlation.

## Gate-0 deepening checks (2026-07-16) — the two obligations from the design deepening

Two cheap single-cohort / single-leaf checks flagged while deepening the engine design (see
`deepening-6-light-coupling.md` §5 and `deepening-2-4-5.md` #4).

### Check A — mass-chart forward stability (`scripts/gate0-a-masschart-stability.R`) — **PASS**
Toggling `node_geometric_compression` (the neighbour-secant path = the mass chart's `TransportGeometry`)
on a K93 SCM at the **default** clamp `growth_eps=1e-4` (not inflated):
- geometric path is **bounded and finite** — `max|log n| = 21.09` vs the FD stencil's `21.15`; stays
  bounded through lifetime 110 (143 cohorts, `max|log n|=29.5`).
- forward shift `offspring_production`: FD `0.075325` vs geometric `0.075453` = **0.169%** — matches the
  documented ~0.2% (R5).
- **Verdict:** the instability that forced the FD/upwind stencil (which needed the clamp inflated to
  ~5e-2 for the *exact-analytic-into-rate* path) **does not recur** when `∂ₓg` is carried by the
  neighbour secant. #6 §3's dg/dh resolution holds.

### Check B — leaf shut-down early-exits, C⁰? (`scripts/gate0-b-leaf-earlyexit.R`, driver
`plant/tests/testthat/gate0_b_leaf_earlyexit_driver.cpp`) — **FAIL (profit is discontinuous)**
Sweeping soil moisture across the shut-down transition and refining to `θ`-step `1e-7`:
- profit **jumps ≈1.46 in one step** — from a bit-identical shut-down floor `−8.3846` (`psi_stem` pinned
  at `psi_crit`) up to the first feasible optimum `−6.93`; the jump does **not** shrink with the step
  (a true discontinuity, not a sub-grid cliff).
- **Verdict (corrected):** the early-exits are `decide()` predicates *for the gradient* (each branch
  smooth, replayed, boundary measure-zero) **but a genuine hydraulic-failure discontinuity**, not a
  continuous kink — so **no breakpoint/Leibniz term applies**, and the boundary is an honesty-condition
  refuse point for the fixed-point/selection regime. My earlier "collapses continuously" assumption was
  refuted by measurement. `deepening-2-4-5.md` #4 updated.

## Net effect on the build plan
- **Phase 3 promoted from "gated" to "confirmed viable"** (F1) — route (ii), reusing the P1a
  implicit-node + P1c `γ` node with reserved higher-order partials.
- **Soil track sharpened** (E2): drop the desingularizing-coordinate item; keep multirate sub-cycle +
  kink-split. The `E2` open item in the build plan is now decided.
