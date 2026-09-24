# Oracle response: performance at fixed accuracy

Reply to `oracle-consultation-solver-performance.md`, captured verbatim. The tests it
proposes, and what to check before building on it, are in `docs/handover.md`.

---

Both grids are being adapted to compensate for two choices made *before* either grid, and most of the cost and all of the uncontrolled error trace to those two. Fix them and neither grid needs to adapt; what remains adaptive is the error *weighting*, which the sweep already computes.

**Choice 1 — one explicit pair for a stiff cheap subsystem and a slow expensive one.** The chain (1.4e3 instructions, closed-form bidiagonal Jacobian) and each new member's pool (a scalar) set the step through their stability boundaries; ~216 slow members (1.12e5 each) pay for it at every stage. The stages produced while walking that boundary are where the tolerance-blind part of `J`'s error comes from.

**Choice 2 — a member's weight is a point sample.** `ω_j β(b_j)E(b_j)` samples a creation density with 18δ/40δ ramps at 56 record-fixed places, and seedling survival behind them, at 34δ spacing. The loop is refining nodes to resolve a function whose panel integrals are available *exactly* from one accumulator along the run.

## 1. What sets the cost, what is load-bearing

Cost = rate evaluations × members held × cost per evaluation. At `u429`: ≈ 14 280 attempts × ~6 + 3358 × 2 ≈ 9.2e4 evaluations, × 216.

*Rate evaluations.* Not accuracy (T1: `tol^−0.065`, median ratio 0.03). They are set by the one-step-per-leg floor (3358), the chain's stability boundary (24% of steps at ≥0.8β, 10% beyond it — the median ratio rising with `h|λ|/β` is the signature), the pool guard's cycle (all 1150 throws), the rejections both cause (59% of accuracy rejections at ≥0.8β; the 47/100 after a knot where forcing starts is the same mode meeting a stale proposal on the top layer), and two evaluations per entry. T8 already attributes 33 of its 51 points to the two stiff modes, 17 to rejections, 3.8 to entries.

*Members held.* A schedule ~3× denser than the response needs (for the reason in choice 2), plus 41% of evaluations to members under 1e-3 of the peak. True dead weight (under 1e-6) is 3.9%; the rest is members a lean schedule would not create.

*Per evaluation.* 85% is a cold-started TOMS748 with two nested root-finds at every stage, for a solution that moves `O(h·rate)` between stages. Outside your count, but after the two fixes it is the largest wall-clock lever (warm-start from the previous stage; the tape sees only the solution, so H4 is untouched; 3–5× is plausible).

| feature | verdict |
|---|---|
| stiff chain and pool inside the explicit pair | representational; carries T3, T4, T8's 33 points, and T5/T6/T9 |
| stops at 2931 knots | intrinsic to stage-sampling a δ-resolved forcing; keep |
| double evaluation and restart at entries | representational; 3.8 points plus the after-knot rejections |
| point-sampled trapezia of `βE` | representational; carries S3–S6, Θ3, Θ6, A5, the filter's numerical necessity, the 429-member reference |
| creation stops inside an adaptive step sequence | representational for S1's floor: pin the program; the nesting (H2) is harmless once pinned |
| max-norm, dead band, ×5 growth, throw retry | symptoms; irrelevant after partitioning |
| `θ_res` floor, `K` clamp, inflow switch, `ψ` cap/floor, `C⁰` class switches, binding clamp | intrinsic — but every inflow-switch and clamp crossing today is numerical (no accepted step ends past `θ_s`); the genuine residue is the floor and the members' switches |
| never-removed members | minor |
| band edges fixed by the record while `w` moves 14× | intrinsic and helpful: why a fixed schedule survives across `θ` |

**Minimal changes and their cost.** (a) A six-stage 4(3) additive RK pair (Kennedy–Carpenter's ARK4(3)6L[2]SA is the natural candidate): implicit part = chain drainage/inflow terms and every pool, explicit part = everything else, including `a`, `Φ`, `ψ`-coupling and accumulators. Same six-evaluation stage shape, so the recording keeps its form (H6). Cost: a new stepper; five scalar implicit solutions per stage recorded as implicit-function rows (the chain is lower triangular, so each stage is five scalar monotone roots — `K` is non-decreasing — solved layer by layer); a transposed bidiagonal back-substitution and a scalar factor per pool in the sweep. No second derivatives and no Jacobian through the member loop: that was RODAS's problem, and it arises only when the Jacobian is part of the formula rather than of a converged solve. (b) Two accumulators, `∫βE db` and `∫b·βE db` over each panel, and product-integration weights in place of `ω_j n_j(b_j)`. A dozen lines in field assembly and `J`, active on the tape, differentiated for free; a declared reformulation with the same continuous limit.

**What is intrinsic.** With exact coupling at every stage, the count is bounded below by stages × Σ over legs of members alive ≈ 6 × 3358 × M̄ — with M̄ ≈ 100 on a certified 1e-3 schedule, ≈ 2e6, roughly 10× under the operating run. Below that, members must skip stages (asynchronous stepping with a coupling surrogate; R3 shows the surrogate must be affine in `ψ`, not `u`, and must hold `p_j`, not `a`) — a reformulation, and a tape redesign. Separately, the model's `C⁰` points make the discretised `J` piecewise smooth in `θ`: a crossing inside a step costs `O(h²)` regardless of tableau, and as `θ` moves the crossing across a stage node the derivative of `J_h` jumps. A3's second difference of 5.6e4 at `d = 1e-4` is that, not curvature. No grid removes it; a declared `C¹` blend of the switches does.

## 2. Time integration between stops

**What produces the uncontrolled error.** At `h|λ|` near `β` the accepted state stays within tolerance but the internal stages do not: chain stage values overshoot `θ_s`, the clamp and `θ_res` (T6's counts, T9's 27 222 against a domain edge of 4.6), and every member is evaluated at the capped or floored `ψ` of those states. The member's increment error per such stage is ~`b_i·h·O(φ)` ≈ 1e-4–3e-4 in components of size 1–10 — under `atol` — and the embedded difference weighs that stage at `|b_i − b̂_i|` ≈ 0.02–0.04 against the 0.1–0.4 the solution absorbs. So the error is committed in the expensive slow part, in the components that carry `J` (old cohorts' output over [12, 25]), invisible to the norm, and its size depends on which steps land at the boundary: placement, not tolerance. Hence 4e-4 non-monotone, 1.65e-4 from 428 zero-size stops, crossings falling 5–83× with `tol` while `J` wanders, and the S1 floor. The `θ_res` floor (a discontinuous right-hand side, a sliding mode) and the members' class switches add genuine `O(h)`–`O(h²)` crossings; those remain after the fix and are the floor.

**What it should be.** The ARK above; members evaluated once per stage at the implicitly advanced chain state; `a` explicit (its Jacobian share is 1.4e-4 of the chain's diagonal, so the explicit part is non-stiff). The pool's implicit stage is a division and preserves positivity, so the guard cycle disappears. One evaluation per entry (append the new member's rates to the last stage's) and the proposal carried across knots. Then pin the step program from a pilot: one step per leg during active forcing, the pilot's accepted steps elsewhere. Order 4 over 5 costs nothing here (T1). Expect T8's bound to be met from above: 3.4–6.7k steps, no rejections, no throws — 2.5–4× at fixed schedule.

**What it guarantees.** Once stages are physical, the embedded estimate is meaningful, and the sweep supplies the rest: `e_time(J) ≈ Σ_n λ_nᵀ est_n`, the adjoint-weighted sum of recorded local errors (Cao–Petzold). That is an a posteriori estimate, not a bound, and it is free. It also gives the right norm: weight each component by `|λ_i|` instead of `1/(rtol|y_i| + atol)`, so `u_5` stops setting 31% of steps and an old cohort's output error counts. The kink crossings are captured at reduced order with an unknown constant; that is what "floor" means here.

## 3. The creation schedule

**Diagnosis.** The 96% "response through the coupling" (S3) is the fields' quadrature error, not `J`'s: the fields at time `t` are made of recent cohorts, exactly where `E(b)` has band structure; `J` is made of cohorts from before the first band. One number settles it: removing the 64 in-band members reads −7.3e-2 because the panel that then spans a band assigns ~½·(band length) of mass where the true mass is ~`τ_g`. On `u429` itself each closing ramp is overweighted ~25% — a systematic mass bias whose sign per band follows node placement, which is S6's cancellation, Θ3's "rebuilding hurts", Θ6's blind indicators, and A5's failure. The filter was needed only because a point-sampled trapezium cannot converge on a 0.06δ ramp; with exact masses the mass created is `∫βγ(P)dt` whatever the ramp's width.

**The fix.** Members at unit density, panel masses from the two accumulators (integrated by the time stepper, whose steps of ≤3.2δ resolve the 18–40δ ramps; the schedule no longer has to), weights from the piecewise-linear basis: the hat at `b_j` receives `(M₁ − b_{j−1}M₀)/Δ` from the panel below and the complement from above. The closing member at `b = t` keeps its share from the partial panel's two moments. `J`'s weights use `∫πβE` likewise. If `G` or `μ` read `m_j` directly, initialise `m_j` at −log of the panel-mean `E` and still carry the mass in the weight. The remaining error is the interpolation error of the value-per-unit-mass function `T(b)` against the mass — `O(Δb²·T''·M₀)` per panel, smooth, asymptotic, Richardson-valid — and the gradient converges at `J`'s rate instead of 5× slower (A2), because `∂e/∂θ` is then `O(Δb²)` too.

**The design.** Fixed, from one pilot at `θ0`. Early, where `w` is smooth, the local trapezium term is already predictive (S3): with `w'' ≈ 3.9w` and `w` halving every 0.35, ~35 panels in [0, 3.56) reach 1e-3 and ~110 reach 1e-4; these are the members that cost 1.9× the mean, so they are the count that matters. In [3.56, 16), nodes at the record's rain-resumption dates that end deep bands (~9 at `θ0`), one node ~`τ_g` inside each, and spacing 0.15–0.25 between (g's excursions are 0.1–0.5 wide). Then ~0.5 to 22 and 1–2 after. Equivalently: quantiles of the pilot's cumulative creation mass, tightened early by `w''` and divided by the pilot's per-member cost. ~120–160 members, mean alive ~100. `d108`'s 44 members below `b = 0.01` are a ξ₁-quadrature legacy costing ~40% of its ΣM for nothing; its errors come from its 1–2-wide panels past `b = 5`.

**Finding it and bounding it.** One pilot (uniform ~200 with exact masses) plus one sweep with the A4 addition: ~4 pilot-runs, against the loop's 12.7 M to reach −2.3e-3. Retire the loop: every flag is the coupling term's, 59% fall past `b = 16` where fills move `J` less than S1's floor, and `J` does not follow the indicator. The bound: the product-integration defect of `T` on the pilot's `g` (a posteriori, per sweep) cross-checked by every-other-member Richardson at checkpoints; expect clean second order. It cannot be tighter than the time floor, which is why the integrator fix comes first. Today no bound below ~1e-4 exists and no monotone one at any level.

## 4. One discretisation across θ

**Fixed:** the schedule (record-graded at `θ0` — Θ2/Θ3 already show fixed beats rebuilt, and with exact masses the reason rebuilding hurt is gone), the stops, and the step program within an epoch. **Adapts, between gradients only:** re-pin the program when its certificate fails; re-grade only on a band-regime change (Θ4's `θ_3 × 1.25`, visible in the mass accumulator at the graded nodes). On either change, re-evaluate the incumbent on the new grid before the optimiser continues.

**Certificates, all cheap:** (i) the re-formed embedded ratio on the pinned program (Θ5's machinery) — after partitioning, its excursions in the chain vanish and what is left is `E` near band edges, fixable with a few δ-steps there; (ii) the adjoint-weighted time-error sum; (iii) the g-defect from the current sweep against the budget; (iv) the along-step consistency check `J(θ_{k+1}) − J(θ_k)` against the trapezoid of the two sweep gradients — the optimiser has all four numbers already.

**Accuracy needed.** For a single-output misfit a relative gradient error `ε` only rescales `∇M`; the stationary point is set by the value error: `δθ/θ ≈ e/S` with `S` the log-sensitivity (5–8), so `e = 1e-3` biases θ by ~2e-4 relative, below any data resolution. With several outputs the direction error is ~`ε` times the residual mix; `ε ≤ 1e-2` is ample and quasi-Newton tolerates ~0.1. What the optimiser actually needs is consistency (the sweep is exact for `J_h` on a fixed grid) and smoothness of `J_h` at its step scale — (iv) above. `d108` fails on all counts; `lean180` passes; the 3.4% sweep–secant gap on `u215` is the kink floor on that grid and is the number to re-measure on the new discretisation. If it stays above ~1e-2, the switches need smoothing; if not, the secant should be abandoned in favour of the sweep.

## 5. The sweep

It should be the source of every weight and none of the grids. Concretely: `λ` per component per step for the goal-oriented step program and the a posteriori time error; `g(b) = v/ω` at every creation for the schedule's grading and defect estimate (A5 holds once `g` is resolved and the ramps are exact; A6 shows `u429`'s `g` predicts refinements to 5–25% even now); the gradient itself, validated along the optimiser's own steps; and, off-tape, which members can be evaluated less often or retired. Not: driving insertion by the coupling indicator, or changing anything within a gradient (H1). Its cost scales with the same count as the forward run, so every saving above is a saving in the sweep.

## What to test first

1. Replay the recorded `u429` run, flag stages with `u_1 > θ_s`, `u < θ_res` or `ψ` at a bound, re-evaluate the members at the projected state, and sum the differences with adjoint weights. This should account for most of T5's 4e-4.
2. Exact masses on uniform 215 and 429, nothing else changed: the S3 split should invert, 215 should land near 1e-3, the 64 in-band members should become removable at ≪7e-2, and 429/857 should Richardson-extrapolate cleanly.
3. The pinned ARK at `θ0` over `tol = 1e-2 … 1e-4`: `J` monotone with a spread ≪1e-4, T6's crossing tables reduced to the genuine floor and class switches.
4. The graded ~140-member schedule on the pinned ARK across the 11 points: `|e|/J ≤ 1e-3`, secant-gradient error ≤ 0.1%, along-step consistency ≤ 1%.

If 1 and 2 come out as predicted, the remaining question is not which grid to adapt but how much of the residual is the model's own kinks — and that is a modelling decision, measurable by a declared `C¹` smoothing.
