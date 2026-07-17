# Oracle response — multirate for a small fast block with expensive non-separable coupling

*Response to [`oracle-consultation-multirate-update.md`](./oracle-consultation-multirate-update.md).
Recorded verbatim (lightly reformatted). Dated 2026-07-17. Treat as a source of hypotheses to be
tested by measurement, not verdicts (per `oracle-consultation-guide.md` §7); the response itself
supplies the falsifiable experiments E1–E4 with kill criteria — run E1 first, it decides the rung.*

---

## Headline

The refuted piece is the **surrogate-in-`u`**, not the multirate frame. The datum that saves it: `a`
is a **byproduct of solves, not a function** — so evaluating it densely along the micro trajectory is a
**parameter-continuation** problem, and continuation's economics are what the naive sub-cycle lacked
(refreshing 10× more often costs ~1×, not 10×). The multirate skeleton (slowest-first legs,
kink-split micro-integration, two-level frozen schedule) survives intact; only *how the fast RHS
obtains `a`* changes.

## 1. What the plateau proves

The fast block's true Jacobian is `∂b/∂u − ∂a/∂u`. Holding `a` piecewise-constant integrates a
structurally different fast system (`b(u)=a_held` instead of `b(u)=a(x,u)`); the restoring feedback
`a`'s `u`-dependence supplies is deleted, so in stiff regimes the held system relaxes to the wrong
balance (or punches into the clamp and locks) within each refresh interval — an error set by the
balance displacement, **not** the refresh rate, hence R-independent. Consequences:
- **No zeroth-order-hold refresh schedule can work** in stiff regimes. `a`'s `u`-dependence must live
  **inside** the micro dynamics — exactly, or via a model ≥ first order in `u` with a validity horizon
  adapted to the excursion. The refutations killed *fixed-macro-horizon surrogates*; they cannot kill
  exact evaluation or short-horizon models.
- **The gradient inherits the plateau.** A tape of the held-`a` scheme is FD-consistent with a *wrong
  model*. Only fixing the forward scheme repairs it.

## 2. Reframing: "one expensive evaluation" is not atomic

The cost proxy (one unit = one O(M) solve set) is an artifact of **cold-starting**. Each `φ`-solve is
Newton-like on a smooth solution manifold `y*_j(x_j,u,s)`; along a continuous path in `u`, the next
evaluation costs the corrector work to track the manifold from the previous converged point — scales
with **path length since last evaluation, not number of points**.

Promote operating points to algebraic states; integrate each leg as a **semi-explicit index-1 DAE**:
```
u̇ = b(u,t) − Σⱼ C(yⱼ,xⱼ,u),   0 = F(yⱼ; xⱼ,u,s),  j=1..M (or m, below)
```
The DAE corrector, warm from the previous micro-step, **is** the warm-started refresh (fact 4) — 1–2
iterations if `u` moves little; better, the **IFT tangent `∂y*/∂u`** gives a first-order continuation
predictor `y_seed = y_prev + (∂y*/∂u)Δu` that typically pins the corrector at one iteration.
Warm-starting changes iteration count only, never the converged value → implicit-node adjoint untouched.

**Second compression — members, not just iterations.** `a_ℓ = Σⱼ c_ℓ(x_j,u)` is M evaluations of one
smooth function `c_ℓ(x,u)` of a scalar coordinate `x` at member positions. If `c(·,u)` is smooth in `x`
(piecewise, split at branch boundaries), **collocate**: solve only `m ≪ M` node problems (Chebyshev per
smooth piece) and reconstruct `a(u) ≈ Σₙ Wₙ c(x_n,u)`, `Wₙ = Σⱼ ℓₙ(xⱼ)·(member weight)`. Attacks the
O(M) factor; composes multiplicatively with continuation. Does **not** touch the macro stages, which
still need all M solves for the `ẋⱼ` (irreducible floor any scheme pays) — the compression is only for
the *extra* evaluations the sub-cycle needs, which is where the problem lived.

**Per-leg scheme:** leg start does the full M solve set (needed for the slow stage anyway) → `a₀`,
`y*_j`, node set, weights `Wₙ`, W-Jacobian `J_w = ∂b/∂u − Σₙ Wₙ[C_u + C_y(∂y*/∂u)]`. Micro loop
(kink-split, clamp via event roots, desingularized coord): tangent-predictor + 1–2 Newton correctors
per node (never taped), `a(u)=Σₙ Wₙ C(y_n,x_n,u)` (m implicit nodes on tape), **Rosenbrock-W** stage
with `J_w` (recorded passive; refreshed on a trust monitor). W-methods keep order with an approximate,
frozen `J_w` (≈90% diagonal per measurement) — licenses the cheap/passive Jacobian and handles the
wet-end stiffness.

**Cost arithmetic:** macro stages at the `x`-limited rate (~30–300 M-solve sets/unit — the irreducible
floor) + micro `a`-evals ≈ `300/unit × (m/M ≈ 1/20–1/40) × (warm/cold ≈ 0.1–0.3) ≈ 1–5`
M-solve-equivalents/unit → fast-rate coupling becomes a rounding error, and the micro rate can rise
arbitrarily during excursions at negligible marginal cost → **no plateau; exact-in-`u` every micro-step.**

## 3. Contingency rung (only if E1 kills warm-starting)

Short-horizon, refreshed-on-trust **Taylor models**: `a₀ + JΔu` (+`H` from 2nd-order IFT) from one
solve set + IFT tangents, with a **validity radius shrinking near `u_min`**, monitored for free against
the fresh exact value at each refresh, PI-controlled cadence. Right model class given the structure:
**nonlinear-diagonal-by-continuation + affine-cross** (not pure-affine, not pure-separable — the two
refuted classes). Rung 2 because it puts `J` (hence `∂y*/∂u`) on the tape (adjoint needs 2nd-order
residual partials; nesting needs 3rd) — real machinery and a partial foreclosure; the exact route needs
no new nodes.

## 4. Reverse-mode dossier

Implicit nodes unchanged; **stopping rule changes** — adjoints use only converged points, so
continuation seeding is invisible **iff termination is residual-based at gradient grade**. The byproduct
channel `c` is non-stationary in the operating point → gradient error first-order in the residual; set
`tol_grad` from a **gradient-vs-tolerance sweep, not the value sweep**. Passive-record rule (extends the
frozen-schedule contract): record in pass 1, replay as passive in pass 2 (FD injects same records) —
**passive:** warm-start seeds & iteration counts (≤tol), `J_w` (O(h^{p+1}) by W-property), collocation
node placement. **Must stay active:** converged operating points (IFT nodes), collocation weights `Wₙ`
(functions of `xⱼ`), clamp event sub-step lengths (scalar-IFT roots — freezing reinstates the C7-class
bias), and everything in `b` and `C`. Per-leg checkpoint = `(x,u)` + m node states + passive records
(few KB); the M-factor never appears on the tape at the micro rate. Rung 1 is nest-safe; rung 2 is the
nesting hazard.

## 5. Feature ranking

**Load-bearing:** (i) `a` as byproduct of warm-startable solves (dissolves the cost model — fact 4 is
the most consequential sentence); (ii) `∂a/∂u` as fast dynamics (the plateau's cause; zeroth-order holds
unfixable); (iii) smoothness of `c(·,u)` in the member coordinate (the M→m compression — one measurement
away). **Load-bearing negatively:** non-separable nonlinearity of `a` in `u` (demotes all `u`-surrogates
to contingency). **Incidental (settled mechanics):** kinked inhomogeneity (split steps), clamp (events),
near-singular `b` (desingularized coord / Rosenbrock micro-stepper), `s(x)` (cheap), shared global step
(removed by legs), u→x direction (exact at macro abscissae).

## 6. Experiments (with kill criteria)

- **E1 — Continuation economics (do first; decides the rung).** Instrument inner-iteration counts vs
  `‖Δu‖` along recorded excursion paths, seeding each solve from (a) the previous converged point and
  (b) the tangent predictor. Deliverable: iterations per unit path length. **Kill:** warm cost stays
  above ~⅓ of cold for micro-scale `Δu` (e.g. discrete branch-hopping) → rung 1 economics fail, promote
  the trust-region rung.
- **E2 — Member-coordinate smoothness.** Offline, at a few frozen `(u,s)`, evaluate `c(x,u)` on a dense
  `x`-grid; fit Chebyshev per smooth piece; measure `m` for target aggregate tolerance. **Kill:** `m→M`
  ⇒ drop collocation, keep continuation alone (still the decisive win).
- **E3 — Windowed prototype, values.** DAE/Rosenbrock-W micro-stepper with node-continuation aggregate
  vs tight-tolerance truth on recorded excursion windows; error vs micro tolerance. **Success:** monotone
  convergence, no plateau, ≤ a few M-solve-equivalents/unit beyond the macro floor; verify on exactly the
  stiff regimes that plateaued at 0.1.
- **E4 — Windowed prototype, gradients.** Tape one window; frozen-record FD vs adjoint; gradient-vs-
  `tol_grad` sweep through the `c`-channel; one θ-component moving excursion timing to size the dropped
  schedule sensitivity.

## One-line summary

You asked how to avoid evaluating `a` at `u`'s fast rate; the plateau proves you **must not** avoid it —
`a(u)` is part of the fast dynamics. What you avoid is paying **cold-start × M** for it: **continuation**
makes each fast-rate evaluation cost ~one corrector iteration, **collocation** makes it `m/M` of a solve
set, and both are exact in `u`, tape-clean, and leave the existing adjoint architecture untouched.

---

## Our reading / next action

- The response **converges** with our probe findings (surrogate-in-`u` dead) and **reframes** the way
  out: don't approximate `a`, make its *exact* evaluation cheap via continuation (warm-start) + member
  collocation. This maps to the real system as: **warm-start the per-cohort leaf/hydraulic solves across
  soil sub-steps**, and **collocate over cohorts** (solve `m ≪ N` representative cohorts, interpolate the
  rest) for the aggregate uptake.
- Per §7 of the guide, **E1 is the go/no-go and we run it before building.** Real-system E1: does the
  per-cohort hydraulic solve (collar-potential root + cᵢ co-limitation) collapse to ~1 corrector
  iteration when seeded from the previous soil-state's converged operating point, for micro-scale Δθ?
  Kill if warm cost > ⅓ cold.
- E2 maps to: is the per-cohort uptake `c(height, θ)` smooth enough in the cohort coordinate that
  `m ≪ N` collocation nodes reconstruct the aggregate? (One offline measurement.)

---

## E1/E2 measured (2026-07-17) — `scripts/tf24-multirate/e1_continuation.R`, `e1_cost_decomp.R`

The go/no-go, run before building. Two structural facts from the code change how E1 lands:

- The inner solve is `find_root_collar_psi` — a **deliberately fixed-iteration golden-section search**
  (the code comment: chosen over Brent *because* its argmax is a smooth, fixed-iteration function of
  inputs, which the demographic growth-rate gradient relies on). So it is **not** Newton-warm-startable
  by design.
- `TF24f` **already implements rung-1's "promote operating points to algebraic states"**: it tracks the
  collar potential `q` as an ODE state with `dq/dt = k·d(profit)/d(psi)` (exact IFT gradient
  `dprofit_droot_collar_psi`), and *evaluates* the leaf at the tracked `q` (`evaluate_root_collar_psi`)
  instead of re-optimising. `k_acclim → ∞` recovers the TF24 optimum.

**E1 — continuation economics (measured, single leaf, height 10 m).** Per-leaf cost (µs):
`set_physiology` 11.4 · evaluate-at-point (+prepare +1 profit) 4.6 · optimise (GSS) 21.1.
- Tracking the operating point (evaluate) vs re-optimising (GSS) saves the GSS cost: **~4.5× on the
  solve** (21→4.6 µs), **not** the order-of-magnitude the "cold-start × M" proxy implied.
- A θ-dependent per-cohort `set_physiology`/prepare (~11 µs) is paid **whenever θ moves**, and it
  dominates the cheap evaluate — so the sub-cycle's per-cohort floor is set by prepare, not the solve.
- A warm **Newton** on the exact `dprofit` is **fragile**: it diverges to the lower clamp and hits
  the vulnerability-curve interpolation domain edge over a realistic dry-down (dψ_soil = 0.25 MPa
  steps: |q\*−warm| ≈ 0.6–0.9). TF24f's gradient-**relaxation** is the robust form, at a tracking-lag
  (accuracy) cost governed by `k_acclim`.
- **Verdict:** rung-1 (warm-start / tracked-q) is a **real but modest ~4.5×** per-cohort win, capped
  by the θ-dependent prepare — a **measured refutation of the 10×+ continuation economics** the
  response assumed. This is the datum to feed back to the Oracle.

**E2 — collocation over cohorts (measured; the decisive lever).** `e2_collocation.R`. Represent the
same continuous size distribution at increasing cohort counts `m`, compute the aggregate per-layer
uptake (backed out of the real `patch$derivs`, full physiology), converge to a fine reference (`m=80`):

| θ | m=8 | m=12 | m=20 | m=40 |
|---|--:|--:|--:|--:|
| wet | 0.24% | 0.10% | 0.036% | 0.008% |
| mid | 0.34% | 0.14% | 0.044% | 0.006% |
| dry | 1.24% | 0.51% | 0.17% | 0.03% |

(rel. error vs the `m=80` aggregate.) Convergence is smooth and ≈O(`m⁻²`) — trapezoidal quadrature of a
**smooth** integrand — i.e. per-cohort uptake `c(x)` is smooth in the cohort coordinate. **m ≈ 15–20
cohorts reconstruct the aggregate to <0.5%.** For real stands (N ~ 100s–800s) that is a **5–40× cut in
expensive per-cohort solves** with sub-percent aggregate error — the decisive O(N)→O(m) lever E1 lacked.
The dry/near-singular regime converges slower (layer-shutdown branch boundaries → the response's "split
per smooth piece" / adaptive node placement there), but still cleanly.

**Combined verdict (E1 + E2).** The response's two compressions land in the *opposite* order to its
ranking: **collocation over cohorts is the dominant lever** (5–40×, measured), and warm-start/tracked-q
is the **secondary** one (~4.5×, capped by θ-dependent prepare). They compose (m collocation cohorts ×
cheaper-per-solve). Concrete #1/#2 seam: at each macro/leg, solve the full physiology once to fix the
light field and pick `m ≈ 15–20` collocation cohorts (more/adaptive in the dry regime); in the soil
sub-cycle, refresh the aggregate uptake by solving only those `m` cohorts (optionally tracked-`q` for a
further ~4.5×) and interpolating; step the ≤5 soil states with a Rosenbrock-W / RODAS micro-stepper for
the wet-end stiffness. This is exact-in-θ (no surrogate-in-`u`), so it dodges the plateau, and its tape
cost is `m` implicit nodes per micro-step (the N-factor never hits the tape).

**Net reading:** the surrogate-in-`u` is dead (confirmed); rung-1 works but is modest (~4.5×), not
transformative, because per-cohort prepare is θ-dependent and irreducible; the **M→m collocation over
cohorts is the more promising lever** and should be measured next. Rosenbrock-W on the ≤5 soil states
(RODAS available) remains the right micro-stepper for the wet-end stiffness independently of all this.
