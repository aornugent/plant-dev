# Oracle response — step-size control for a bimodal, cluster-limited coupled IVP

The measurements settle the norm question and relocate the problem. The step is bound by the ten-component block through two mechanisms — stability on `u_L` under sustained forcing, truncation on the `u_1 … u_{L−1}` cascade under impulses — and neither is a norm problem (C4, C6). What is left is (i) the method, because no controller can move an explicit pair past its stability boundary; (ii) smoothness the integrator is currently asked to supply by trial and error — the `C¹` forcing knots, the `C⁰` switching surfaces, the pool arrivals, the insertion jumps; and (iii) feedforward from a schedule that is known in advance but is today discovered by rejection. C11, C13 and C18 say the frozen grid fails through exactly (i) and (ii).

## 4.1 The norm

(a) No. Under a max norm the gain from reweighting any set `S` is `(r_(1) / max_{i∉S} r_i)^{1/5}` per accuracy-limited step, and C6's flatness says that gap is ≈1: the small block sits second at nearly the same ratio. RMS or a 1-norm changes the number by dilution, not structure: with `c_eff = Σ_i (r_i/r_max)²` effective binding components out of `N ≈ 724`, `r_RMS = r_max √(c_eff/N)` and the step grows by `(N/c_eff)^{1/10} ≈ 1.4–1.6×` — which is a `√(N/c_eff) ≈ 6–12×` loosening of the tolerance on the actual binding component wearing a norm's clothes. Under stability pinning it buys nothing at all, since the estimate of an amplified mode is not a power of `h`. Given C14, a leak on `u` is the wrong direction. Keep the max norm; it is telling the truth.

(b) Yes. Log the full ratio vector `r_n` (or its top twenty entries) at every accepted step, once. Any candidate weighting is a function of `r_n` alone, so its counterfactual per-step value `r_{w,n}` and the implied step `h_n (r_{max,n}/r_{w,n})^{1/5}` follow with no integration; the predicted count is `Σ_n (r_{w,n}/r_{max,n})^{1/5}` over accuracy-limited steps, masking steps with `h_n·ρ(J_u) > ~2`, where the estimate is amplification rather than truncation and no norm can move it. The scalar summaries are the gap `r_(1)/r_(2)` (its distribution bounds every reweighting) and `c_eff`. The prediction is first-order — it ignores trajectory feedback — which makes it accurate exactly when the gain is small, i.e. when you need it.

(c) Zero measurable gain, and still worth doing: it is the correct seminorm, costs nothing, and takes the accumulators out of the validity scan, where a non-finite `v` would falsely reject. The cluster is the whole story.

(d) It changes, in the direction of tightening. A correction to what I said last round: a perturbation of `u_1` does not decay, it is redistributed down the chain, and leaves the system only at the terminus. Under sustained forcing that exit is fast and `λ_u` is discounted by ≈`τ` — but the step is stability-pinned there anyway. Under impulsive forcing the excess persists through the drawdown and is taken up, so `λ_{u_1}` is O(1) and an adjoint-weighted norm holds `u_1` at least as tightly as now. That is consistent with C14: the correct norm says the current control is too loose for `J`, not too tight.

## 4.2 Regime-adaptive control

(a) `h_n·ρ(J_u)` with `ρ(J_u) = max_ℓ qκ_ℓ u_ℓ^{q−1}` (plus the diagonal of `∂a/∂u` if you have it): `L` multiplications on state you already hold, no evaluation. Threshold ≈2, with hysteresis (enter above 3, leave below 2). C4's 77% on `u_L` is this quantity being dominated by the terminus, which has the largest `κ`, hence the smallest quasi-steady `u` and the largest rate `q·flux/u`.

(b) In the stability regime the optimal controller is not to be explicit: the block has an analytic bidiagonal Jacobian, a partitioned (IMEX or Rosenbrock) stage on it is a 5×5 solve, and its adjoint a 5×5 transposed solve. Staying explicit, the known answer is a damped filter plus a hard cap `h ≤ β·3.5/ρ(J_u)`, `β ≈ 0.85`, so the boundary is computed rather than found by rejection. In the accuracy regime, a PI with feedforward resets at impulses (4.3c). Do not switch laws; compose them, `h_{n+1} = min(h_filter, h_cap)`, with anti-windup (feed the `h` actually used back into the filter state). A saturation is not a competing dynamic law, so there is nothing to chatter. If you insist on two laws, hysteresis 2/3 on `hρ` and a two-step dwell suffice; the switching signal is a smooth function of `u` and does not itself chatter.

(c) Yes: schedule the regime. At each impulse onset `u_1 → (s/κ_1)^{1/q}`, so the post-onset rate `|λ_1| ≈ qκ_1^{1/q}s^{1−1/q}` is known before the impulse arrives and gives the first step directly. Detection then only backstops the state-driven events — switching migrations and `u_L` stiffening.

## 4.3 The controller as a digital filter

(a) In Söderlind's frame, `log err_n = k·log h_n + log φ_n` with `k = 5`, and the controller is a linear filter on `log h` driven by the disturbance `log φ`. Deadbeat has no attenuation: every fluctuation of `φ` becomes a fluctuation of `h`, and at the stability boundary `φ` oscillates — that is the sawtooth and the rejections. The decisive factor here is the pinning (wants a low-gain, damped filter), then the cost asymmetry: a rejection costs 0.83 of a step *plus* the too-small step that follows it, ≈1.5–2 step-equivalents, so a filter running ~5–10% under the deadbeat step and rejecting on <2% of steps beats deadbeat rejecting on 10%. Impulse transients are where filtering hurts (slow response to a real jump in `φ`), but they are scheduled, so you reset rather than pay. PI42 (`β₁, β₂ = 0.6, −0.2`, divided by `k`) as the accuracy law, the cap as saturation; H211b (`β₁ = β₂ = α₂ = 1/4`) only if you remain explicit at the boundary and cannot compute the cap. Separately: the Cash–Karp pair carries embedded solutions of orders 1–3 after stages 2–4, designed for abandoning an attempt early when the right-hand side varies rapidly. Using them cuts a rejection at a kink or event from 5 evaluations to 2–3.

(b) A smooth limiter (`ratio ← 1 + κ·arctan((ratio−1)/κ)`, `κ ≈ 1–2`) in place of the clamps and the dead band; accept at `r ≤ 1` — the 1.1 is a 10% error leak bought for a few percent fewer rejections, which a damped filter no longer needs; safety factor `S ≈ 0.9` folded into the tolerance; no growth on the step after a rejection.

(c) Formulate the filter as an estimate of the error function, `φ̂ = err/h⁵`, filtered, with `h_{n+1} = (tol/φ̂)^{1/5}`. Then a clipped step still yields a valid `φ̂` (clipping never corrupts history); at an insertion, `φ̂` for the `u` block persists and is carried while the new member's `φ` is unknown, so you carry and cap by feedforward (4.5a); at an impulse onset the memory is disinformation, so reset `φ̂` to the value predicted from `|λ_1|` above, not to `h_min`. At an offset let the filter grow at its own pace — 5× per step covers a 300× rate collapse in four steps — or feed forward the drawdown rate.

(d) No universal proof: with a max norm, a change of binding identity is a jump in `φ`, and no short filter beats deadbeat against a jump process it cannot predict. The structural fix makes the identity change a selection instead of a disturbance: run the filter per component or block (`u_1 … u_L` individually, members as one) and take `h_{n+1} = min_i h_i`. Each filter tracks a smooth `φ_i`; the switch only changes which minimum is active. Ten scalar filters, and it coincides with the max norm at deadbeat.

## 4.4 The response law

(a) 5 is right: the estimate is the lower-order solution's error, `O(h⁵)`, so the exponent is `1/(p̂+1) = 1/5`. In log space the closed-loop pole for exponent `1/k_c` against an `h^k` error model is `1 − k/k_c`: 5 gives 0 (deadbeat), 4 gives −0.25 (alternating overshoot in `h`, more rejections), your growth branch's 6 gives +1/6 (a sluggish lag — an accidental, undesigned PI). The exponent shows in the *dynamics* of the `h` sequence, not in the tolerance-response slope, which is fixed by the estimator's order and the problem's smoothness. C14's slopes have other causes (4.12b, stability).

(b) In `h` the band `[0.5, 1.1]` is `2.2^{1/5} = 17%` wide, so its direct cost is ~8% more steps than tracking the top. Its real costs: it hides the `err`–`h` slope (with `h` constant you cannot estimate the local order, 4.11b); it makes the accepted sequence depend on where the band was entered, part of C12's roughness; and with ~6 steps per leg the controller often never leaves the band inside a leg. It buys crude damping at the stability boundary, which a filter does properly.

(c) A fudge. The legitimate asymmetries — rejection cost, no growth after a rejection — are a safety factor and a one-step memory, both filter features, not exponents.

(d) Never silently. Hitting `1e-6` at `tol = 1e-4` on a problem whose fastest smooth scale is `3e-3` means a non-smooth event (order-1/2 local behaviour, where shrinking helps only linearly), not a hard problem; each floor-accept marks where the model is hybrid. Report the count and the committed error `Σ(r−1)·D`; put `h_min` near round-off or a budget, far below `h_init`; and remove the causes (4.6, 4.7, 4.12) so the floor is never touched.

## 4.5 A frequently restarted integration

(a) Carry the error-function estimate — it describes the `u` block, which binds and persists — but recompute `k₁`: the endpoint evaluation from the previous leg was made on the system *without* the new member and is stale as the new leg's first stage; verify this is done. Then cap the first step by feedforward, `h ≤ β·min_ℓ (u_ℓ − u_min)/|u̇_ℓ|` from the recomputed derivative, plus the stability cap. That is "carry with a computed derating" and targets the documented failure directly. A blanket reset to `h_min` would cost ~7 growth steps × 88 legs, most of the run.

(b) Clipping is right; excluding it is the crude version of the `φ̂` formulation, which needs no exclusion. Plan the remainder evenly: `n = ceil((t_end − t)/h_pred)`, `h = (t_end − t)/n`, recomputed each step — never a sliver, which at six evaluations costs a full step for nothing.

(c) With ~6 steps per leg the controller spends a third of every leg in its own transient. That argues for changing the schedule you own — no leg shorter than a few `τ ≈ 1e-2`; a `1e-5` leg is 300× shorter than the fastest dynamics and nothing in it needs resolving, so merge early insertions — for a fixed count (one or two steps) in legs shorter than ~10`τ` with adaptivity only in longer ones, and structurally for a precomputed schedule, since the leg boundaries are `θ`-independent and any captured grid inherits them; C13's finding that the breakpoints are load-bearing is partly this.

(d) Yes: early legs sit below `τ` (step = leg, no control); late legs span ~170`τ` and several impulses (full control). "Six per leg" averages two populations.

## 4.6 Constraint violation as a control signal

(a) Neither fixed nor unconditional. Before the step, `z_j/|ż_j|` from `k₁` gives every member's time to the boundary at the current rate; cap `h` at 0.9 of the minimum — a first-order event alignment costing arithmetic and no failed attempt, at most 88 extra step boundaries. After a violation, interpolate the crossing (cubic Hermite from `y_n, f_n, y_{n+1}, f_{n+1}`; you compute the endpoint derivative anyway) and retry once at `0.9·θ*·h`, the fraction-to-the-boundary rule. Hundreds of 0.2× rejections at five evaluations each, followed by steps 5× too small, is plausibly 10–25% of the run.

(b) Rejection is the wrong mechanism: it is event location by trial, and its placements are what make the accepted grid `θ`-jagged (C11 "placement not size", C13's 39%). Rank by what the drain does at zero. If it vanishes at least linearly, arrival is asymptotic and the overshoot is an integrator artifact: change variable to `log z` (or `z^{1−α}` for a drain `∝ z^α`) — unconstrained, zero bias, smooth tape. If it is finite at zero (finite-time arrival, a genuine switch to resting), reformulate to a smooth complementarity, e.g. `drain·z/(z+ε)`: bias `O(ε)` near arrival, propagated to `J` through `λ_z` and budgetable; choose `ε` so the new rate `c/ε` does not exceed the `ρ(J_u)` you already pay for, and no new step constraint appears; if you want it stiffer than that, take the per-member scalar implicitly (closed form, AD-clean). Projection is a branch with `O(h·drain)` bias per arrival; a barrier makes an attracting boundary repelling, which is the wrong model. One more reason to reformulate rather than locate: at an arrival `ż` jumps, so the exact sensitivity jumps by `(f⁻ − f⁺)·dt_e/dθ`, a term a frozen-step adjoint with the event pinned to a grid point does not contain. C12's frozen plateau shows AD and FD agree *on the pinned model*; it does not show either equals the model with moving arrivals.

(c) Sound only inside a window: `ε·z_max` above the step's round-off (`~10² ε_mach z_max`, else it refuses noise, as you saw) and at or below what the error test allows near zero, `atol` (else the guard admits violations the accuracy control would reject) — so `ε ∈ [1e-13, atol/z_max]` — and `f` must be evaluable at the admitted slightly negative `z`. After (b) the guard disappears.

(d) A validity rejection should change `h` by the predicted fraction and set a one-step no-growth flag; it must not enter the filter's error memory, since no valid estimate exists for it. The override of an accept verdict is correct as a safety net, and every override is a symptom to count: its rate is the meter of how hybrid the model still is.

## 4.7 Switching surfaces without event detection

(a) `f` is continuous with a derivative jump along the trajectory, so `y''` jumps: a straddling step has local error `O(h²)·[y'']` whatever the pair's order. The estimator sees `O(h²)`, the controller shrinks as if it were `O(h⁵)`, so error falls only as `r^{−2/5}` per rejection: from `r = 100` that is five rejections (25 evaluations ≈ 4 steps), an accepted small step, then growth over ~4 steps — often followed by a second cascade when the next step straddles the same kink. Per population-wide crossing ~6–10 step-equivalents. For a single light member the jump is `∝ ρ_j c'` and sits under `tol`: the step is accepted at second order and nobody is told. C9 says which happens where — five regimes thrash a few times, two thrash continually.

(b) Event location *is* available, and for this switch it is compatible with reverse mode. The event time only decides where a step ends, a controller decision off the tape; the tape sees a fixed `h` and one branch per stage. The term a frozen-`h` discrete adjoint misses is `(f⁺ − f⁻)·dt_e/dθ`, and for a `C⁰` switch `f⁺ = f⁻`, so the adjoint is first-order correct without it. The substitute, if you don't want location: a smoothed complementarity of the active-set condition with width tied to the stiffness budget, or pricing it — crossings from the branch census × ~8 steps.

(c) Yes. Because the population crosses together, the switching function is essentially a function of `u`. Evaluate `P`'s *classification* at a handful of fixed sentinel `ξ` nodes (five inner solves per step against `M = 88`); a change between step start and end flags a crossing; locate it on the pair's dense output in `u` (arithmetic on 10 components) and end the step there. The 28–31% who cross individually are invisible this way; for them, accept the silent second-order step if light, or smooth.

## 4.8 Frozen versus adaptive, and the hybrid

(a) Partly. C11's own diagnostic says the failure is stability: where the replay is wrong, `h|λ|` on the replayed trajectory is 1.7–3.2× (to 17.5) above the adaptive run's ≈5. `s = 1.5` covers the parametric rise of `|λ|` (C2) and leaves 1.6%; the residual is phase shift — at `θ ≠ θ₀` the stiff phases move in time and a large captured step meets a stiff state. The rule generalises as `s ≥ max over the box and over time of |λ|(θ,t)/|λ|(θ₀,t)`, shifts included. The economical version is not a global `s` (+45%) but a min-envelope: the pointwise-in-time minimum of the adaptive sequences at the box's corners, which you already ran. The decisive version is C18: remove the stability constraint from the `u` block and the frozen grid's failure mode disappears — the non-stiff variant replays at `s = 1` to `1e-5` over ±100%.

(b) Trigger on two certificates computed during the replay itself. Stability: `max_n h_n·ρ(J_u(y_n)) ≤ c` — free, and a hard guard for the mode that actually fails. Accuracy: `Σ_n λ_nᵀ e_n`, with `e_n` the embedded difference (a linear combination of stages you already form; the 30% saving is rejections, not the estimate — reinstate it as a passive meter) and `λ_n` from the reverse pass of the same replay. It is the right certificate because the frozen grid is what makes `λ_n` well-defined; it is first-order, so the stability check must gate it. Recapture when either fails or the optimizer leaves the certified box, and set `s` from the certificate rather than globally.

(c) One grid per forcing realisation is simply correct: the grid encodes impulse-driven placement and the forcing is fixed during calibration. Transfer matters only for ensemble forcing; if ever wanted, a grid *designed* from the breakpoint schedule and the predicted post-impulse rates transfers by construction, at the price of missing state-driven events.

(d) Three designs. Freeze per optimization iteration — capture at the iterate, use it for the gradient and the whole line search, recapture at the accepted point, gated by (b); this is what a consistent optimizer needs and it is cheap. A smooth step law with fixed counts — per leg a `θ`-independent number of steps placed by a smooth monitor of `(t, u)`, e.g. geometric refinement after each impulse with a ratio that is a smooth function of `ρ(J_u)` at the leg start; `h` is then an active, smooth quantity on the tape, which is fine, and there is no accept/reject at all, so it lives on the certificate. And removing the stability limit, after which the first design needs no `s`.

## 4.9 Failure handling without a controller

A fixed-grid integrator should have no failure path: if a domain guard can fire, the model is not yet in a form a fixed grid can integrate. In order: change of variable where the boundary is asymptotic (`w = log(u − u_min)` for the small block — the `u^{−p}` divergence becomes smooth in `w`, zero bias, and no explicit overshoot can cross; `log z` for pools with a linear drain); smooth complementarity where arrival is finite-time (`O(ε)`, 4.6b); implicit treatment of the stiff block (zero bias, removes the overshoot mechanism, adjoint a 5×5 solve); subdivision only as a diagnostic — it is a branch and `J_h` jumps at its granularity, likely part of C12's 1.3% scatter; projection (branch plus `O(h·drain)` bias); bare (fails at 39%).

## 4.10 Joint tolerance allocation

(a) In units of `J`: the measure error at `M = 88` is ≈`1.3e-4` relative; the inner floor is invisible to `J` (a `1e-12√N` random-walk perturbation) and visible only to FD (`δ_in/δθ`, C12's `1e-6`) and reproducibility; so the time-integration budget should be ⅓–½ of the measure error, certified by `Σλᵀe`. That presupposes the asymptotic regime, and C14 says you are not in it — at `tol = 1e-4` the time error is O(1). Fix the mechanisms first; meanwhile tightening is cheap at the measured slopes (`1e-4 → 1e-8` is ~4.6× steps), so run at `1e-6`–`1e-7` now. A calibration that needs `1e-6` in `J` needs `M ≈ 800`.

(b) Yes: `k = 3` Newton iterations from a warm start (the previous stage's `p_j`, a smooth function of state) converge below round-off within a branch, and `P_k` is then a smooth function with no count branch and no noise floor. Controller: unchanged except the FD plateau extends to round-off. Tape: fixed size; differentiate through the three iterations by plain AD — with exact convergence IFT and plain AD agree, with a fixed count plain AD is the consistent one. `J`: bias at round-off for warm starts; cold starts (insertions, branch changes) get a larger fixed count, and insertions are at known times so that is not a branch. What it does not remove: the classification among the eight outcomes — a `C⁰` branch, acceptable by 4.7b — and the safeguard's fallback, which fires only at crossings and cold starts.

(c) No. A tolerance schedule is a count schedule in disguise. The one coupling — inner residual `≪ tol·D/h` — is met by `1e-8`; fix the count and drop the tolerance.

## 4.11 Operating outside the asymptotic regime

(a) Outside the power law the exponent is wrong: at kinks (`r ∝ h²`) the controller under-shrinks and cascades; at the boundary (`r` not a function of `h`) it oscillates. It should trust a priori indicators over the estimator — the cap from `ρ(J_u)`, the knot/impulse/insertion schedule — and, where it must react, shrink with an exponent estimated from the last two steps, `k̂ = log(err_n/err_{n−1}) / log(h_n/h_{n−1})`, floored at 2; and prefer ending a step at a known or detected discontinuity to shrinking through it.

(b) Cheaply, from three free signals: `h·ρ(J_u) > 2`; `k̂ ≪ 5`, which needs `h` to vary — the dead band prevents it; and the schedule, since a step containing a jumping knot, an impulse onset or an insertion is non-asymptotic by construction.

(c) Both, split as follows. No controller promises `J`; the local-error contract is the caller's to translate. But this controller also breaks its *local* contract silently — floor-accepts, the 1.1 leak, estimates that measure amplification at the cap — and that is a defect. The deliverable is a certificate: counts of floor-accepts and validity overrides, fraction of steps at the cap, and the adjoint global-error estimate, cheap since you already run reverse passes. Only then can the caller select a tolerance; today nothing tells them `1e-4` is unconverged.

## 4.12 Alignment when the kink grid is finer than the step

(a) Align only to knots with a nonzero jump — under mostly-zero forcing that is impulse onsets, offsets and the knots inside impulses, a sparse set. Under sustained forcing every knot jumps and the grid is finer than the step; there the choice is between aligning (≤2.6× more steps but full order, after which `tol` can be loosened to the one-step-per-knot floor) and reconstructing at higher continuity so nothing needs aligning. The reconstruction is already a modelling choice with an arbitrary continuity class; a `C⁴` one is not more biased than a `C¹` one, so reconstruct.

(b) A jump in `f''` along the trajectory is a jump in `y'''`, and the straddling step's local error is `O(h³)` regardless of order. If every step straddles a knot the method is globally second order and steps scale as `tol^{−1/3}`: C14's local slope of −0.345 is that signature, −0.064 is the stability-pinned one, and −0.167 is the mixture. Confirm for free: `v_1 = ∫s` is one of your accumulators — compare `v_1(T)` with the exact integral of the reconstruction. An input-mass error is permanent (it is water in the chain), and a percent-level discrepancy at `tol = 1e-4` is where much of the 57% plausibly lives.

(c) Positivity of the rate (hard: negative forcing drives `u` toward `u_min`); exactness of the total (hard: input mass persists); per-cell integrals (hard if the data are cell totals); continuity `C⁴` (for the 5(4) pair a jump in the fifth derivative costs nothing, in the fourth one order). Two constructions: a monotone quintic spline of the primitive (all four exactly, but shape-preserving high-order splines on impulsive data are delicate), or the piecewise-constant rate convolved with a smooth compact kernel of width one cell (positivity and total exact, `C^∞`, per-cell mass moved by `O(w·Δs)`, declared). Either is a function of `t` alone and costs the tape nothing.

## 4.13 Load-bearing, incidental, unasked

| § | load-bearing | incidental |
|---|---|---|
| 4.1 | C4, C5, C6 (the cluster), C14 (direction) | C1, C15, C17 |
| 4.2 | C3, C4, C2 (what `ρ(J_u)` is), C1 | C5–C9 |
| 4.3 | C3 (pinning), the 5:6 cost ratio, C4 (identity switching), known schedule | C11–C13 |
| 4.4 | the law as configured; C14 for what the slope is *not* | C1–C10 |
| 4.5 | leg structure, C1 (`τ` against leg length), C13 (breakpoints) | C15, C16 |
| 4.6 | §1.3(i), C13, C11 (placement) | C4–C6 |
| 4.7 | C9, C10, C8, the tape rule | C1–C3 |
| 4.8 | C11, C12, C13, C18, C2 | C15, C16 |
| 4.9 | C13, C11, the reformulation allowance | — |
| 4.10 | C7, C12, C15, C14 | C1–C6 |
| 4.11 | C14, C3, C16 | — |
| 4.12 | C16, C14, C8 | C15 |

Not asked, in the order I would act:

1. **The method.** With 77% of sustained-forcing steps bound by `u_L` at the stability boundary, no controller change moves that regime by more than tens of percent; an implicit stage on the five-component block moves it by `3.5/|λ| →` `x`-limited, plausibly an order of magnitude, and by C18 it is also what makes a frozen grid robust. The adjoint is a 5×5 transposed solve per stage — work, but small work.
2. **The 57%** (C14) has a decomposition, each term with a free counter: the forcing quadrature via `v_1`, floor-accepts, validity overrides, switching cascades. Knowing which dominates decides between 4.6, 4.7 and 4.12.
3. **The stale `k₁`** across insertion boundaries, if it is reused.
4. **The insertion schedule**: legs below `τ` are pure overhead and are yours to remove.
5. **The pool arrival's sensitivity term** (4.6b): the frozen-grid AD/FD agreement is consistency with a pinned event, not correctness against the model; only a smooth reformulation makes `dJ/dθ` correct as well as consistent.
6. **Cash–Karp's low-order embeddings** for early abandonment, the cheapest available cut to rejection cost.
7. **Last round's collocation lever** is now bounded by `M = 88` and by C9's branch co-occurrence: ~5× on the loop in single-branch regimes, nothing where branches mix.
8. **Certificates as outputs**: the stability check and `Σλᵀe` are nearly free and are the only way the caller can ever choose a tolerance on evidence.
