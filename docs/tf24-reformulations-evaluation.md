# Evaluating the Oracle's reformulations (R1–R5) against TF24/plant

*My assessment of the Oracle's stability/performance reformulations, grounded in the real TF24 soil
physics and the measurements in this study. Verdict: **grab R1 and R5**; R2–R4 are less applicable to
TF24. R1 is a mechanistically-interpretable win that improves accuracy, stability, and performance of
the multirate stepper — orthogonal to the control-variable question but it composes cleanly.*

## R1 — split the fast flow, integrate the singular (drainage) part exactly. **GRAB — top pick.**

TF24's gravitational drainage is, per layer, `wout_ℓ = K(θ_ℓ) = K_sat·(θ_ℓ/θ_sat)^{2n_ψ+3}` — a **scalar
power-law loss** with exponent `p = 2n_ψ+3 ≈ 16.14`. The drainage-only ODE `θ̇ = −c·θ^p`
(`c = K_sat/(dz·θ_sat^p)`) has a **closed-form flow**
```
θ(t) = [ θ0^{1−p} + (p−1)·c·t ]^{−1/(p−1)}
```
Confirmed (`scripts/tf24-multirate/…`, R1 check): it matches a tight RK4 of the drainage ODE to **~1e-13**
and is **positivity-preserving by construction** (`θ→0⁺`, never negative). This is the classic soil-water
**recession curve** — mechanistically the analytic gravitational drainage, so the reformulation has clean
ecological underpinning, not just numerical convenience.

**Why it's the top pick for TF24 specifically:**
- The drainage is **the dominant wet-end stiffness** — the very term whose Jacobian forced the
  stability-limited / Rosenbrock-W micro-stepper in E2/E3 (`dK/dθ = p·K/θ` blows up as `θ→θ_sat`).
  Strang-splitting it out and integrating it **exactly** removes that stiffness with zero truncation;
  the micro-stepper then sees only the **gentle** part (infiltration source + inter-layer cascade +
  uptake coupling). Measure `‖∂a/∂u‖` on the remainder — it may be nonstiff enough that the coupling
  substep goes **explicit**, retiring Rosenbrock-W for the common case (keep it only for the near-bound
  passage).
- **It removes the positivity clamp on drainage** — the exact recession can't overshoot negative, so the
  clamp (a numerical artifact of explicit stepping that we had to guard in E2/E3, and a
  non-differentiability source) disappears from the drainage substep. The residual floor `θ_res` (where
  uptake shuts off) is a separate *physical* floor, handled in the uptake term.
- **Analytic touchdown.** If the exact recession reaches `θ_res`, the touchdown time is an explicit root
  of the closed form — event location and its Leibniz/adjoint term become taped closed forms, not
  dense-output root-finds.
- **Tape-minimal.** The drainage half-steps are closed-form compositions: no Jacobian, no linear solve.

**Structure caveat (handled):** TF24's `b` is *not* fully componentwise — layer `ℓ` receives the
drainage from above (`win_ℓ = wout_{ℓ−1}`), a bidiagonal downward cascade. But the **stiffness is
diagonal** (each `wout_ℓ` depends only on `θ_ℓ`), so this is exactly the Oracle's "exact flow of the
diagonal part": integrate the diagonal drainage loss exactly, and put the (gentle, non-stiff) cascade
inflow + infiltration + uptake in the coupling substep. The commutator `[drainage, cascade+uptake]` is
second-order and convergent — no held-`a` plateau mechanism (each substep carries its full `u`-dependence).

**Cost:** the drainage substep is closed-form and per-layer (L≤5) — negligible. The win is fewer micro
steps through wet episodes (the drainage was a large fraction of the controller's budget) and a simpler,
possibly-explicit coupling substep. **This is the single highest-value item on the reformulation menu for
TF24.**

## R5 — cost currency: batch the m coupling solves; reject stabilized-explicit. **GRAB (implementation).**

Confirmed by E1: the binding cost is **coupling RHS evaluations** — the per-cohort physiology solves
(95–100% of a patch RHS, scaling with the number of cohorts touched), not linear algebra (the `(L+m)`
dense solve is trivial) nor Jacobians (closed-form). Consequences we should bank:
- The `m` collocation-cohort solves are **data-parallel by construction** (identical operations, different
  cohort attributes) → **SoA layout + fixed-size SIMD batch kernel**. Pass-1 forward runs in plain
  `double`, so it vectorizes with zero AD friction.
- **Reject stabilized-explicit families (RKC/ROCK)** despite their tape-friendliness: they buy stability
  with *many cheap stages*, but our stages are *expensive* (each is `m` coupling solves). Low-stage
  Rosenbrock-W **or** R1-splitting (one coupling flow per step) is the frontier — which is exactly the
  direction we converged on.

## R2 — absorb kinked forcing by exact integration. **Limited for TF24 (R1 subsumes).**

R2 wants additive forcing `b = β(u) + q(t)`. In TF24 rainfall enters **multiplicatively**: `infil =
rain(t)·[1 − a_infil·(θ_0/θ_sat)^{b_infil}]` (saturation-excess runoff modulates the input). So the
additive change-of-variables `w = u − ∫q` doesn't apply in general. It *partially* applies in the
unsaturated regime (runoff factor ≈ 1 → `infil ≈ rain(t)`, additive to layer 0), but the whole point of
the term is the saturated regime where it isn't. Per the Oracle's own caveat, R1's exact substep flow
absorbs the forcing instead. **Defer.**

## R3 — Sundman-reparametrized micro clock. **Reduced payoff given R1; keep in pocket.**

R3's performance payoff (equidistribute fast excursions) is largely *pre-empted by R1* — once the
drainage recession is exact, the remaining fast content is gentle, so there's little left to
equidistribute. R3's subtler payoff — recovering the dropped **episode-timing** sensitivity in the
gradient — is smaller for TF24 than the generic case: episode timing here is set by **rainfall kinks**,
which are fixed in `t` and already kink-split (resolved), not by a smooth threshold crossing. **Defer**,
but keep it as the tool if the gradient-vs-θ validation ever shows a residual timing-sensitivity gap.

## R4 — dissipative / gradient structure. **Does not apply to TF24.**

R4 needs both `a = ∇_u V` (H0 — **fails**: the coupling is the water flux, not the carbon-profit gradient)
and `β(u) = −∇Φ(u)` (the drainage/infiltration cascade is a **downward transport**, not a symmetric
gradient flow). Both structure checks fail, so there is no energy/convex-splitting structure to exploit
here. **Defer** (revisit only if a future strategy is posed in the marginal-coupled form — see the H0
missive).

## Net

- **Grab R1** (exact drainage recession, Strang-split) — removes the wet-end stiffness *and* the
  positivity clamp, likely retires Rosenbrock-W for the common case, gives analytic touchdown events,
  and is the classic soil-water recession curve (interpretable). Composes with the multirate skeleton and
  the tracked-control fast subsystem without disturbing the tape contracts.
- **Grab R5** (batch the `m` coupling solves; reject RKC/ROCK) — banks the one measured cost currency.
- **Defer R2/R3/R4** — less applicable to TF24 (multiplicative forcing; R1 pre-empts R3; H0/gradient
  structure fail for R4).

Both grabs are orthogonal to whether the control is re-optimised (TF24) or tracked (TF24f), so they hold
for both models. **Measurement that gates R1's magnitude:** the commutator scale `‖[drainage, cascade+
uptake]‖` along recorded episodes vs the current micro truncation error — decides whether R1's step
enlargement is ~2× or ~20×; and `‖∂a/∂u‖` on the remainder — decides whether the coupling substep can go
explicit.
