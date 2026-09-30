# Oracle response: the second follow-up

Reply to the *Second follow-up, after your reply to the follow-up* in
`oracle-consultation-solver-performance.md` as it stood at `2d70763`, continuing the same
session, captured verbatim. Earlier replies are in this file's git history. What was
tested against it is in `docs/handover.md`.

---

**What §1 settles.** The gradient's error is not spread over the run: it sits in the 305 steps (3% of the pair's) across which some member's `P` changes sign, almost entirely the downward ones on 3.5–17δ quiescent steps, and it falls in proportion to their length: `θ_B` goes `2.2e-2 → 9.4e-3 → 4.5e-3 → 9.6e-4` for 0–23% added steps. The step length at the downward crossings is the gradient's knob, and it is nearly free. `J`'s value transfers far better than I predicted (within `7e-5` to ±20% in `θ_A`), because its kink error is `h²` and random-signed, while the gradient's is `h` and, on a moved grid, coherent. Those two facts change the design: gradients should be rebuilt, not transferred, and their accuracy certified by a ladder in the crossing step, not in `tol`.

## 1. The objectives

Keep goals 3, 4 and 5 as written. Change the rest:

- **(a)** Keep for `J` on `tol` (measured: `0.2–0.5·tol`). For gradients, replace `tol` by `h_e`, the step across the downward crossings; §1's split table is already that ladder. On the creation axis, replace "converges" by "its bias is bounded once per series" (below).
- **(b)** Drop as a design criterion. The draw is the kink random walk; it is made small by `h_e` and measured once, for `J` and for the gradient. It has never been measured for the gradient, which is the next measurement.
- **(c)** Keep only for probes, and only in the two forms probes need: `J′` over `Δ` (value transfers; the check is clips and excursions) and `g′` at `θ′ = θ` (on its own base grid, no transfer). Drop "gradients transfer within `Δ`" for the calibration: a downward crossing moves `17δ` per unit `ln θ_A` (90th percentile `40δ`), so a zone that keeps the gradient's `O(h_e)` term small at ±5% must be ±2δ around every cluster, and at ±20% it is not affordable. Rebuild instead; a rebuild costs 20% more than a pinned run.
- **Goal 1.** Drop "on a fixed grid" during descent. Keep both accuracy conditions. Carter's 0.3 is met by a factor of 100 at every measured setting; what binds is `|H⁻¹·δg|`, so the precision wanted in `θ` is the master budget and should be set first; the gradient budget follows from it through `H` (the optimiser's own estimate after a few iterations), `h_e` from the ladder, and `tol` last from what `L`'s value needs.
- **Goal 2.** "One grid per series" becomes "one base grid per probe set". The calibration rebuilds at every iterate and pins only at the end, to certify.
- **Add.** A reference standard for the driver: the current references straddle crossings too, which is why `θ_A`'s ladder floors at `2e-4` and `θ_B`'s resolution is unknown. A reference is the per-member grid at `1e-6` with its crossing steps split 16×.

## 2. The goal, rethought

**What the two uses need.** The calibration needs a gradient field accurate enough for descent everywhere it goes, and at the end an optimum whose distance from the true one, `|H⁻¹·δg|`, is bounded. The root search needs `g′(θ)` at `θ′ = θ` with bounded bias, `J′` over a range of `θ′` on one grid for curvature, and a bound on the root's location, `δg′/(dg′/dθ)`. Neither needs `J` to follow `tol` per se, a transfer radius for gradients, or a single `L_h` during descent: inexact-gradient theory covers descent, and exact gradients of one fixed function are needed only where the iterates stop moving.

**What is true of the problem, and what each fact forces.**
- The vector field is C⁰ at `P = 0` and at the class switches, and those events cluster (196 clusters) and move with `θ`. This forces a second time knob, `h_e`, and it makes it cheap: capping the step inside a window around each cluster touches 3–6% of steps. It also forces the certificate's form: a two-point ladder in `h_e`, first order, Richardson-extrapolable.
- The hazard amplifies `ln S`. This forces the per-member relative scale, which is in place and measured.
- The chain is stiff in pulses and the pool's explicit emptying has a positivity limit near `hλ_S ≈ 2`; both limits move with `θ`. On a rebuilt grid this costs nothing; on a pinned grid it forces margins at build (`0.8β/|λ|`, free; `hλ_S ≤ 1` on emptying steps, few) and a positivity fallback for the pool.
- The sweep is exact for the discretised model. This forces nothing about fixed grids; it says the gradient on any grid is that grid's, so its error is the grid's kink term, which `h_e` controls wherever the grid was built.
- Members couple only through the fields. This is what makes probes legitimate and cheap, and it says `g′` at `θ′ = θ` inherits the base grid's `h_e` exactly.
- Creation is a product-integration quadrature in `b`. It converges as spacing² only if `πF(T; b)` is smooth at the spacing; whether it is has never been measured with the time draw removed. A fixed schedule per series makes `L_h` smooth in `θ` regardless; its bias on `θ*` is bounded once by the ladder's gradients.

**The design.** Five parts.
1. *One rule* `R(tol, h_e)`: stops at knots and creations; the per-member pool scale and the same form for the panel moments, `tol·(|I_j| + ρ̄_c·Δ_j)`; the chain margin; a cap `h ≤ h_e` from the first predicted crossing of a cluster (from `P_j` and `Ṗ_j` at the step's start, free) to `12δ` past its last, which also covers the switches into the lower end, and `h ≤ 0.3δ` over the `1.5δ` before a predicted upward crossing, which covers the switches out of it; a stage clip of the pool at zero with a counter, in place of the throw. Cost at `h_e = 1δ`: about +16% over the per-member scale, so `~6.4e6` per forward run at `tol = 1e-4`.
2. *Gradients*: the sweep on `R`'s own grid at every iterate. When the optimiser's step falls below the gradient draw's `θ`-equivalent, pin the last grid and converge on it; the pinned run is the probe code path, not a second mechanism.
3. *Certificates*: `J` by the `tol`-ladder once per series; the gradient by the `h_e`-ladder (a second grid at `h_e/2`, one forward and one sweep) once per series and once at the final `θ`, giving the bias and the extrapolated gradient; `|H⁻¹·δg|` from it. Per run, the adaptive rule's own acceptance is the check; if `L` has functionals not yet analysed, `E_L = Σ_n λ_{n+1}ᵀ·le_n` in the sweep is one dot product per row and reports `L`'s time error.
4. *Probes* on the base grid: `g′` at `θ′ = θ` certified by the same ladder; `J′` over `Δ` with the clip counter and the pool's own re-formed ratio as the check; `Δ` is whatever the clip permits (±5% today with the relaxed guard; beyond ±10% the pool needs an unconditionally positive step, an integrating-factor or modified-Patankar update of that one component, a declared change with cheap rows).
5. *Creation schedule* fixed per series, placed once; the 108/215/429 ladder with values and sweep gradients at `θ₀` bounds its bias; if it does not converge, the discrete ensemble is the model and the bias is reported, not chased.

**What I would refuse to build.** Event location with retakes (3× cost, and it puts corners in `J_h(θ)` that the sweep cannot follow). Adjoint-weighted control. Transfer zones sized to an optimiser excursion nobody knows. Per-`θ` creation schedules. More analytic kink factors (the four-component one changed nothing). An implicit or sub-cycled chain, until a cost budget says `6e6` per run is too much.

## 3. Root causes, ranked

1. *Structural.* C⁰ events under an RK step: `O(h_e²)` in `J`, `O(h_e)` in `dJ/dθ`, coherent when the grid is moved. Treated by the cap; certified by the ladder. Not removable by `tol`.
2. *Structural.* `θ`-dependent stability and positivity limits of the explicit pair on pinned grids. Margins for ±20%; the pool step beyond. The throw at `× 0.8` is this: a stage below `−1e-4·S_max` is a real overshoot, an emptying step past `hλ_S ≈ 2` or a moved near-empty onset on a coarse step. Detail to record: the component and `hλ_S` at `t = 3.48`.
3. *Structural, unmeasured.* The creation axis. One ladder decides whether it converges; either outcome is handled by part 5.
4. *Detail.* The references. Fix: crossing steps split 16× on the per-member grid at `1e-6`.
5. *Detail.* The re-formed ratio as a check. It is unweighted and, at 90% of maxima at `θ₀`, the chain's; at `θ ≠ θ₀` chain steps near `hλ = β` give embedded differences that reflect the two stability polynomials, not an error that propagates. Fix: record the component; for the chain use `hλ/β`; for members use the pool's ratio. Better: do not pin base runs, so the check is not needed.
6. *Detail.* The first factor's steadiness. The class switch out of the lower end sits `0.26δ` before the upward crossing, inside its step, and kinks the pool's emptying rate by `r·|ΔṖ|`; the first factor over-refines exactly those steps (`r ≈ 0.2`, where the corrected factor vanishes) and catches it by accident. Fix: the `0.3δ` cap over the `1.5δ` before predicted upward crossings. Test: the seven nudges at `3e-4` with the corrected factor plus that cap; predicted standard deviation `≤ 7e-6`.
7. *Detail.* Crossings shift at twice my estimate, and `θ_B` shifts them with no explicit path: the motion is through the state (`n → a → chain → φ`). Consequence only for zone sizing, which the design drops; use measured shifts per constant where windows are needed.
8. *Detail.* The moments' absolute part couples the axes at loose `tol`. Fix: the per-panel scale in part 1.
9. *Set aside.* T12's anomaly; the four-component estimate.

## 4. The next measurement

The gradient's draw under `R` with the cap, since it decides whether rebuilding at every iterate is sufficient or pinning must carry the end game. Seven tolerances within ±5% of `1e-4`, each run adaptively with `h_e = 1δ`; the sweep's gradient (or pinned central differences) in `θ_A` and `θ_B` on each, against the split-16 reference; report median error and standard deviation, and add one run at `h_e = 0.5δ` so the same set tests the ladder as a certificate. If the standard deviation is below the gradient budget that the wanted `θ`-precision implies, the design is part 1–3 with no transfer machinery at all; if it is near `1e-3`, pin earlier and certify. The second measurement, if that one passes, is the creation ladder with the per-member scale.

**The reformulation.** The gradient's accuracy was being asked of the tolerance, and it is a property of a few hundred steps, the ones on which the downward crossings sit. Give those steps their own knob, certify it by a two-point ladder, rebuild grids freely, pin only to certify and to probe, and set the precision in `θ` f irst, because every other budget descends from it.
