# Oracle response — an accuracy-limited coupled IVP with a functional target

Short version: the largest speedup on the table is in the right-hand side, not the integrator — P5 and P2 together mean the inner root is a smooth one-dimensional function of `ξ` at fixed `u`, so it can be collocated at `R ≪ M` nodes once per `f` evaluation. Kink alignment is free and restores your order. A `J`-weighted (adjoint) error norm is the principled control and buys a bounded factor, roughly 3× on post-impulse steps, because it prices errors in the self-damping fast block at their true small value. A stiff treatment of the `u`-block pays only where that block is quasi-steady under sustained forcing. Method order is not a lever at tolerances where `J` is already converged. The better-conditioned derivative comes from three cheap reformulations — mass weights instead of density, no existence threshold, and a `θ`-independent step grid — not from the integrator.

## 1. Error control for a functional target

The quantity to bound is, to first order,

`ΔJ ≈ Σ_n λ_nᵀ e_n`, `λ_n = ∂J/∂y_n`,

where `e_n` is the local error at accepted step `n` and `λ_n` is the discrete adjoint — the cotangent of the state at step `n`, which your reverse pass already produces. `λ_n` includes the transport of an error committed at `t_n` into `J`-sensitive components later; that is what the adjoint is. Every norm is an approximation of this weighting.

A structural point first: the controller is already off the tape. Step acceptance is a branch on an active value, so you must already be replaying the frozen accepted sequence in the reverse pass. The norm may therefore depend on anything — `ρ_j`, `λ`, the forcing phase — without touching differentiability.

**(a) Component-wise floors.** A vector `atol_i` is a static proxy for `1/|λ_i|`. The principled floor for member `j`'s states scales like `ε_J / (ρ_j · |φ'(ξ_j)|)`, i.e. inversely with the member's weight. Cost inside the controller: none. Failure modes: it is blind to transport (in the density form `ρ_j` can regrow where characteristics converge, so a member written off can return with an inherited `ξ_j` error); and a loosely integrated `ξ_j` can wander out of the region where `σ` has a single branch, at which point the root solve, not `J`, fails. A loose sanity tier (say `1e-2` relative on every state) is mandatory alongside any aggressive floor.

**(b) Adjoint-weighted norm.** Accept the step if

`max( (T/(ε_J h_n)) Σ_i |λ_i(t_n)| |e_{n,i}| , RMS_i( e_{n,i} / (atol_loose + rtol_loose |y_i|) ) ) ≤ 1`.

The first term is error-per-unit-step in a weighted 1-norm, so the sum over steps is bounded by `ε_J` (using `|Σ λ_i e_i|` instead would be tighter but trusts cancellation). `λ(t)` comes from the previous optimization iterate's reverse pass at zero cost — store the cotangent at each accepted step (~1000 × 2500 doubles) and interpolate linearly in `t`; for a one-off solve it costs a forward–backward–forward triple. Stages and the step-size formula are unchanged; the only addition is one weighted sum per step.

What it does automatically, which no static norm does: during a post-impulse relaxation, a perturbation `δu` decays at rate `|λ|`, so its effect on `x` is `g_u δu τ` with `τ ≈ 1/|λ| ≈ 0.003`. Hence `λ_u ≈ τ · g_u · λ_ξ` during relaxation, and O(1) during the slow drawdown where nothing restores `u`. The adjoint discounts the fast variable by the timescale separation exactly where the transients are, and charges full price where errors persist. Likewise `λ_{ξ_j} ∝ ρ_j`, so dead members drop out of the norm without a threshold. The "vanishing component whose error later transports into a `J`-sensitive one" is handled to first order: `λ` at time `t` is precisely that transport.

Failure modes: (1) the null space — components with `λ_i ≈ 0` are uncontrolled, drift nonlinearly, and eventually invalidate the linearization behind `λ`; that is what the second tier is for. (2) Stale weights across a qualitative change (a P7 crossing, a forcing-regime change): the new reverse pass gives `Σ_n λ_n^{new}ᵀ e_n` for free as an a posteriori check, so a bad solve can be detected and redone. (3) With an L-stable method stepping over a transient, the embedded `e_n` does not see the missed transient's effect on `x` (both embedded orders land on the slow manifold), so `λᵀe` underestimates — see §5. With explicit RK, which resolves the transient, the estimate is reliable.

**(c) Seminorm zeroing quadrature-only channels.** Correct and free for channels that neither feed back into `f` nor enter `J`. Here almost everything feeds back through `a_ℓ`, so the static version has little to zero; the state-dependent version — "effectively quadrature-only once `ρ_j → 0`" — is (b).

Before implementing anything, two free diagnostics decide the matter: histogram which component attains the max of the error norm at each accepted step, and run once with dead members' tolerances set to infinity to get an upper bound on what any member-side reweighting can buy. If `u` components bind after impulses, the gain lives in §5, not here. Note also that an RMS norm over ~2500 components dilutes the few `u` components by `√N ≈ 50`, so the current norm under-controls `u` relative to the members; the weighted 1-norm removes that.

## 2. An o(M) coupling

Your candidate is right in spirit, but the accounting has to be checked: the 86% is the root loop, and `g` consumes `p_j` too. Factoring `a_ℓ` alone while still solving `p_j` per member for `g` saves nothing. The thing to collocate is the root itself. Since `σ(p; ξ, u) = 0` defines `p = P(ξ, u)`, a smooth function on the single branch (P2, via the implicit function theorem), collocate `P(·, u)` in `ξ` at `R` fixed nodes once per `f` evaluation. Then `g`, `m`, and `c_ℓ` are closed-form arithmetic per member, and `a_ℓ = Σ_j ρ_j c_ℓ(ξ_j, u, P_R(ξ_j,u))` costs `O(M)` flops with zero solves. Collapsing it further to `Σ_r β_{ℓr}(u) G_r` is a secondary saving.

Why "separated in `ξ`, exact in `u`" is the right shape: the `u` direction is `L`-dimensional and steep near `u_min` (`u^{−p}`), so any tensor surrogate in `u` is hopeless; the `ξ` direction is one-dimensional and analytic on the single branch, so Chebyshev interpolation converges geometrically. Practicalities that matter for the tape: use a fixed interval `[ξ_b, ξ_max]` known a priori (not `min_j ξ_j, max_j ξ_j`, which is a branch); evaluate via the Chebyshev series with Clenshaw recurrence rather than the barycentric formula, whose removable singularities at the nodes are a data-dependent branch; use `log ξ` if the kernels behave like powers near `ξ_b`. `R ≈ 16–32` typically gives `1e-8` or better for kernels with a modest Bernstein ellipse.

(a) The weights enter linearly and exactly; every member keeps its own `(ξ_j, ρ_j)` and its adjoint channel. In the density form the `ρ`-equation uses `∂_ξ` of the interpolant of `g`, which is analytic and costs no per-member IFT solve. Skewed weights are harmless: positive-weighted sums of bounded terms have no cancellation.

(b) The tape holds `R` node roots (each with its IFT adjoint) plus linear maps; there are no branches. `d/dθ` of the surrogate equals the surrogate of `d/dθ` up to the interpolation error of `∂c/∂θ` (same geometric rate) and the derivative-of-interpolant error in `ξ` (slower by an `R²` factor, still geometric).

Error control: `|a_ℓ − a_ℓ^R| ≤ (Σ_j ρ_j) · ‖c_ℓ(·,u) − I_R c_ℓ(·,u)‖_∞`, so the relative error is uniform in the member distribution and governed only by the kernel's analyticity radius in `ξ`, which shrinks near folds of `σ` and near the shut-off at `u_min`. Meter it by comparing the `R`- and `2R`-interpolants every `k`-th accepted step (`2R` extra roots, off-tape), not by the full `M` loop: with `M = 800`, `R = 20`, a full-`M` meter at every accepted step would cut the gain from ~40× on the loop to ~5×. Fix `R` offline; never adapt it on active data.

Realistic gain, by Amdahl on your numbers: the loop drops by `≈ M/R`, the whole `f` by roughly 2× at `M = 50` and 4–6× at `M = 800`, and the reverse pass and tape shrink by a similar factor. Failure modes: an active-set change at some `ξ*(u)` (P2 violated — the kernel acquires a kink, convergence becomes algebraic and the kink location is active), a singularity at `ξ_b` (variable change), and extra per-member states entering `σ` (then the manifold is not one-dimensional; on your statement the root sees only `(ξ_j, u)`).

## 3. The representation

Yes, pointwise density is the wrong dependent variable for this output. `d(log ρ)/dt = −∂g/∂ξ − m` carries the Jacobian of the flow map; the moments never need it, and it is exactly what diverges where the flow compresses. The finite-volume statement `N_j = ∫_cell n dξ`, `d(log N_j)/dt = −m(ξ_j, u, p_j)`, is the escalator-boxcar-train form.

A consistency check first. Two pairings are self-consistent: the density ODE with sums carrying quadrature weights `Δξ_j` built from neighbours (behaving like `1/ρ_j`), or the mass ODE with the weight alone, as you wrote the sums. If your sums carry no `Δξ_j`, dropping the `−∂g/∂ξ` term is the entire change.

Cost for `J`: `Σ_j N_j φ(ξ_j)` is a midpoint rule on transported cells, error `O(Σ_j N_j Δξ_j² φ'')`. It tightens exactly where the density form blows up (converging characteristics) and coarsens where they diverge — but that is set by the insertion schedule in either form. Place inserted members at the characteristic through the cell centre (half-interval offset) to keep second order; optionally carry a per-member width for monitoring, excluded from the error norm.

Cost for AD: the density form puts `∂g/∂ξ = g_ξ + g_p P_ξ` on the tape, so its adjoint needs second derivatives of `g` and `σ` — the most fragile objects in the code. The mass form needs first derivatives only. `log N_j` is bounded above by the inserted mass and decreases monotonically, so `|y| rtol` remains meaningful and `N_j → 0` is truly absorbing: no regrowth, which turns §1's discount of dead members and §4's smoothness argument from heuristics into facts.

## 4. Well-posedness of the functional

Separate two mismatches. The first is controller-induced: the accepted step sequence changes with `θ`, so the discrete `J_h(θ)` has jumps of `O(tol)` scattered densely in `θ`, and an FD with `δθ ~ 1e-6` sees O(1) derivative errors. Check the AD-vs-FD mismatch with a frozen step sequence; this is usually the dominant term and has nothing to do with P7.

For P7 itself: with bounded `m`, neither `ρ_j` nor `N_j` reaches zero in finite time, so the "absorbing state" is an implementation floor, and `J` is piecewise smooth with a jump wherever a member hits it. AD returns the derivative of the piece (correct almost everywhere); FD straddling the jump returns `jump/δθ`. Measure the jump: `O(floor · φ)` means a floor artifact; `O(Δξ_j ρ_j φ')` means the density form's quadrature is re-weighted when a node drops out; `O(1)` means a hard switch in the dynamics.

Remedy ranking: reformulate rather than mollify. Mass weights, no threshold, never remove — which costs nothing, since members are never removed anyway and a dead member costs `O(R)` flops under §2. Then `J` is `C^∞` in `θ` throughout the single-branch regime; there is no bifurcation to respect. Mollification is for the structural cases only: unbounded `m` (finite-time extinction — cap `m` smoothly with a budgeted bias), or a fold / active-set change in `σ` near `u_min`. A fold cannot be smoothed away, only replaced: under a no-branch tape the tools are a smoothed complementarity form of the constraint with declared width, or keeping `θ` away from it. The hybrid-systems route (event location plus adjoint jump conditions) is the "respect it" option, and it needs a branch you have excluded. Note an active-set change gives a `C⁰` kink in `P(ξ,u)`, milder than a jump.

## 5. The integrator

**Alignment (P6).** Stop at every grid point where the forcing changes and at every insertion time, evaluating the forcing one-sidedly. A kink inside a step gives local error `O(h · jump)` and the controller shrinks `h` to `tol/jump` then recovers over several rejections; the observed order in a tolerance sweep is 1–2. Aligned, you recover 5. Zero cost.

**Decompose the step count per impulse interval.** (i) The fast relaxation: stiff and accuracy-limited, `h|λ| ≈ tol_u^{1/5}` (`0.06` at `1e-6`), which is your "order of magnitude below the boundary". P1 says the rate `qκu^{q−1} = q·flux/u` collapses within a few `τ`. (ii) The drawdown: rate `≈ q·a_ℓ/u_ℓ`, moderate; `x`-limited or mildly stiff. (iii) Sustained forcing: quasi-steady at high flux, stiff throughout, stability-capped at `h|λ| ≈ 3.5`.

**Where each lever acts.** Phase (i) is cut by the adjoint norm (§1) up to the explicit cap: the implied `u` tolerance is ~`|λ|` times looser, so `~300^{1/5} ≈ 3×` fewer transient steps. Beyond the cap you need an L-stable treatment, and there the embedded estimator goes blind to the missed transient's effect on `x`, `≈ g_u Δu τ` per impulse — a bias you must budget by comparison against one resolved run. That is equivalent to declaring the fast block quasi-steady across impulses; with `τ ≈ 0.003` and tens of impulses it is plausibly `1e-3`-scale in `J`, which is a modelling decision, not a solver one. Phase (ii): nothing beyond a cheaper `f`. Phase (iii) and stiff drawdowns: IMEX or Rosenbrock on `b + T` only. The implicit stage is a lower-bidiagonal nonlinear system in `L ≤ 5` unknowns, solved by forward substitution with scalar Newton or by one linearized solve (Rosenbrock, which is AD-clean: no iteration count); analytic Jacobian diagonal `−qκ_ℓ u_ℓ^{q−1}`, subdiagonal `+qκ_{ℓ−1} u_{ℓ−1}^{q−1}`; add `∂a/∂u` (`L×L`, free via the collocated form) if the shut-off near `u_min` is steep; `a` and `x` explicit, e.g. a Kennedy–Carpenter ARK4(3) pair. Gain is the ratio `|λ| h_x / 3.5` on those phases.

**Order.** Steps scale as `tol^{−1/(p+1)}`; going from a 5(4) pair to an 8(5,3) pair halves the step count at `1e-6` while doubling the stage count — roughly 1×. It pays below `~1e-9`, only with alignment, and `J` is already converged well above that. Not a lever.

**Multirate.** Unnecessary once `f` is collocated. It is the fallback if the root cannot be collocated: freeze `G_r` over a macro-step, micro-step `u` on `Σ_r β_{ℓr}(u) G_r` at `R` solves per micro-step.

**Implicit stages and the tape.** Never tape a Newton loop with a convergence test; take the adjoint of the stage equation by the implicit function theorem, or use Rosenbrock stages, which are fixed linear solves.

**Frontier verdict.** Once aligned, explicit RK is at the frontier for the resolved-transient and drawdown phases: any method must resolve a transient at `h ~ tol_u^{1/5}/|λ|`, implicitness buys accuracy nothing, and order buys ~1× at your tolerances. It is off the frontier by the stability factor only in quasi-steady stiff phases, and its RHS cost is off by `~M/R` regardless of method.

## 6. Load-bearing versus incidental; what was not asked

| Question | Load-bearing | Incidental |
|---|---|---|
| 1 | P3 (accuracy-limited, else the norm is irrelevant), P4, P1's separation (sets the `u` discount), the frozen-tape requirement (norm is off-tape), the mass form (dead is permanent) | P5, P6; the `κ` sweep |
| 2 | P5 (argument is `(ξ,u)`), P2 (single branch ⇒ analytic in `ξ`), fixed nodes for the tape | P1, P3, P8 |
| 3 | P8; the quadrature-reweighting mechanism in P7; second derivatives on the tape | P1–P6 |
| 4 | P7, P2 (excludes structural folds), the mass form | P1, P3–P6 |
| 5 | P3, P6, P1 (which phases are stiff), P2 (smooth `f`, analytic Jacobians), no-branch tape (Rosenbrock/IFT) | order of `M`; `κ` sweep except as identification of the stiff term |

The `κ` sweep in P1 is informative in one way only: it identifies the stiff term as the loss and shows the stiffness is state-transient rather than parametric, so a sweep in forcing amplitude, not `κ`, probes the step constraint.

Not asked, and worth asking:

1. The `θ`-smoothness of the discretization. With P6 fixing impulse and insertion times, a `θ`-independent, kink-aligned step grid (geometric refinement after each impulse, designed from one adaptive run, verified by the adjoint estimate) makes `J_h(θ)` `C^∞`, AD equal to FD to rounding, and removes the last data-dependent decision in the pipeline. In an optimization loop this matters more than step optimality.
2. Whether the model needs the transient at all — the `O(τ)` question above decides the largest integration lever, and only the application can answer it.
3. The inner solve's own tolerance and iteration structure: a convergence-tested root is a noise floor in `f` and a branch on the tape; a fixed-count Newton is smooth but is a slightly different function than the exact root. P2's "no noise floor" suggests you already have one of the clean variants; say which.
4. A free global-error certificate: `Σ_n λ_nᵀ e_n` from each reverse pass estimates the actual `J` error of that solve.
5. Balance of errors: the cohort discretization of the measure is `O(Δξ²)`, roughly `(1/M)²` relative — `~1e-6` at `M = 800`, `~4e-4` at `M = 50`. At small `M` you are resolving time three orders of magnitude finer than `ξ`. Refine the insertion schedule and watch `J` before tightening anything else.
6. Conditioning of `dJ/dθ`: the IFT factor `1/σ_p` near a fold, and in the density form the adjoint's scale inherits the `log ρ` blow-up. Both disappear under §2–§3 in the single-branch regime.
7. Reverse-pass memory and checkpointing with ~1000 steps × 6 stages × `M` roots; collocation shrinks the tape by `~M/R` as a side effect.
