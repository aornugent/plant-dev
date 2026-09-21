# An accuracy-limited coupled IVP: what is left after stiffness is ruled out?

This is a self-contained problem statement. No prior context is assumed, and no
application domain is involved — everything below is stated as mathematics.

## 0. Orientation

We integrate a coupled initial value problem with an adaptive embedded explicit
Runge–Kutta method. The integration is expensive and we have spent a long time
trying to make it cheaper. Every structural remedy we tried has been refuted by
measurement, and the reason is always the same: **the step size is set by local
truncation error, not by stability**, so every lever that removes stiffness
removes a constraint that was not binding.

We are now unsure whether anything beats the plain global solver here, and we
would rather be told that than be handed a refinement of a scheme we have
already measured as slower. If the correct answer is "the global adaptive
explicit method is optimal for this structure", say so and say why. If there is
a class of method or a reformulation we have not seen, name it and name the
property of our system it exploits.

## 1. The system

State `y(t) ∈ ℝ^N` on `[0,T]`, `y' = f(y, t; θ)`, with a parameter vector
`θ ∈ ℝ^k`, `k ≈ 17`.

The state partitions into two blocks, `y = (x, u)`.

### 1.1 The small block

`u ∈ ℝ^L` with `L ≤ 5`, obeying

```
u̇_ℓ = b_ℓ(u, t) + T_ℓ(u) − a_ℓ(x, u),    ℓ = 1..L
```

- `b_ℓ` contains a **diagonal power-law self-loss**, `b_ℓ ⊃ −κ_ℓ u_ℓ^q` with
  exponent `q ≈ 16`. This term alone has a closed-form flow,
  `u(t) = [u_0^{1−q} + (q−1)κt]^{−1/(q−1)}`, verified against a tight reference
  to ~1e-13, and positivity-preserving by construction.
- `b` also contains a **time-inhomogeneity that is piecewise-smooth with kinks**
  on a known grid (impulsive, mostly zero, occasionally large).
- `T_ℓ` is a one-way bidiagonal transfer, `T_ℓ = κ_{ℓ−1} u_{ℓ−1}^q`.
- There is a lower bound `u_min` with `u_ℓ > u_min`. Approaching it, a secondary
  quantity read off `u` diverges like `u^{−p}`, `p ≈ 6.6`, spanning ~15 orders of
  magnitude over a ~1.5-order range of `u`.

### 1.2 The large block

`x ∈ ℝ^M`, `M ≈ 50–800`. It is a **discretised measure carried along
characteristics**: `μ_t = Σ_j ρ_j δ_{ξ_j}`, where `ξ_j` is an ordered scalar
coordinate and `ρ_j` a positive weight. Both `ξ_j` and `ρ_j` are components of
`y`, advanced by the dynamics:

```
ξ̇_j    = g(ξ_j, u, p_j)
d(log ρ_j)/dt = − ∂g/∂ξ |_{ξ_j} − m(ξ_j, u, p_j)
```

Note the weight equation differentiates the velocity field in the member
coordinate. New members are inserted on a schedule the caller controls; members
are never removed, but `ρ_j → 0` is an absorbing state that many reach.

### 1.3 The coupling

Each member carries a scalar control `p_j` obtained from an **inner
optimisation** over a bounded interval, solved per member per evaluation. The
coupling into the small block is a weighted sum over all members:

```
a_ℓ(x, u) = Σ_{j=1}^{M} ρ_j c_ℓ(ξ_j, u, p_j)
```

Three properties matter:

1. `a` is **expensive**: each term requires the inner solve. The member loop is
   95–100% of the cost of one evaluation of `f`, and scales with `M`.
2. `a` is **genuinely non-separable in `u`**: `∂a_ℓ/∂u_k` is dense and of the
   same order as the diagonal. Near the bound, `‖∂a/∂u‖` reaches **50–291×** the
   retained part of the small block's restoring stiffness.
3. The inner problem is **not an interior optimum**. Mapping the objective `P(p)`
   finely across its operating point shows a flat shelf, a jump of fixed size,
   then a smooth monotone decline at slope `∂P/∂p ≈ −8.8 ≠ 0`. The "argmax" is
   the last point on a surviving branch — an active-constraint locus, not a
   stationary point. Envelope-theorem arguments therefore do not apply to it, and
   we believe an adjoint built on assumed stationarity is wrong at first order.

### 1.4 The output

A scalar functional, itself a moment of the same measure:

```
J = Σ_j w_j φ(x_j)
```

and we want `dJ/dθ` by reverse-mode AD over the whole trajectory.

## 2. What we measure

All figures are from the coupled system as actually integrated, not a surrogate,
unless stated.

**The step is accuracy-limited, not stability-limited.**

- Tolerance response: `d log(N_steps) / d log(tol) = −0.167` over `tol` from
  1e-4 to 1e-8 (a 5th-order accuracy-limited method predicts −0.20). Steps go
  530 → 2612.
- Removing the stiff self-loss **exactly** (the closed-form flow of §1.1, Strang
  composed) does not reduce the step count at any macro step size tested,
  spanning 1–60× the forcing period. The step count is not set by that term.
- Under smooth forcing, `h·|λ|` sits at ~3.5, i.e. at the explicit real-axis
  stability boundary. Under kinked forcing, median `h·|λ| = 0.097` with 82% of
  steps a decade or more below the boundary. **The forcing regime, not the
  stiffness, decides where the step sits relative to the stability limit.**

**The stiffness coefficient is self-regulating, which makes stiffness sweeps
misleading.** Raising `κ` by 3000× raises the operating-point `|λ|` by only
**2.0×**, because the state falls until `u^q` collapses the loss back. Step
count rises 68% over that range. Any experiment that varies `κ` and observes
"flat step count" is therefore weak evidence about stability-limitation; we made
this mistake for some time.

**The controller is at its floor.** The minimum step size is reached in every run
we have instrumented, across every forcing regime and tolerance. Steps at the
floor are force-accepted with error above tolerance.

**The functional is pathologically sensitive.**

- A 0.8% perturbation of `a` produces ≈9% error in `J` — ~10× amplification —
  and the amplification **diverges** as a collapse regime is approached, so there
  is no finite conversion factor between state-error and `J`-error.
- Two independently converged schemes disagree by **23%** on `J` at `M = 352`.
- There is a **deterministic jitter floor of ~2.7e-3** in `J` as a function of
  step size, which makes the observed convergence order unmeasurable.
- Holding the mean forcing fixed and raising its amplitude, `J` falls
  44.90 → 35.11 → 0.774 → 0.0251 — a 45× drop over one amplitude step. The
  trajectory converges (≤5.5e-4) while this moment of it does not.
- Two evaluations of `a` at bitwise-identical `(x, u)` have been observed to
  differ by **2.45e-2**, growing with forcing amplitude; and a floating-point
  reassociation of one sum, `w(c₁+c₂) → wc₁ + wc₂`, moved a failure time by 3.07
  units of horizon, reproducibly.

## 3. What we have ruled out, and the evidence that killed it

We list these so they are not re-proposed. Each was measured, not assumed. If you
believe one was killed by a bad experiment, say which and why — that is a useful
answer.

| Candidate | Measured outcome |
|---|---|
| Global implicit (Rosenbrock / L-stable) | No stability limit is binding, so steps do not enlarge; ~1.5× *more* steps and ~5× slower per step. Dense Jacobian is O(N³) once the blocks are coupled — ~470× slower than explicit at N=205. |
| Multirate: macro-step `x`, sub-cycle `u` | **6–25× more expensive** than the global solver at converged `J`-accuracy. `n_micro ≈ 10` accuracy-driven micro-steps per macro step, each re-paying the O(M) coupling ⇒ ~13× more member solves than the global solver, which touches all M once per accepted step. |
| Exact-flow removal of the stiff self-loop | Slower than the plain adaptive inner at every macro step size (see §2). |
| Zeroth-order hold / periodic refresh of `a` | Structural plateau independent of refresh rate: holding `a` deletes `−∂a/∂u` from the fast Jacobian, so the subsystem relaxes to a displaced balance. Error floors at O(0.1). |
| Affine model `a ≈ a₀ + G(u−u₀)` refreshed on a trust monitor | Escapes the plateau — certified, error ~1/R in refresh rate `R` with no floor. But the cost advantage **evaporates exactly where the accuracy becomes acceptable**: 3.8× fewer coupling evaluations at 3.5e-3 error, ~1.0× (no saving) by the time error reaches 4e-4. |
| Member reduction, `m ≪ M` | On a smooth synthetic measure, `m ≈ 15–20` reconstructs `a` to <0.5%. On the **evolved** measure the same estimator is ~10² worse (38% at m=20), because `ρ` is skewed and the `ξ_j` are placed to resolve `x`, not the coupling integrand. Subsampling the measure also zeroes the adjoints of dropped members. |
| Locating threshold events | The candidate events are structurally unreachable in the regimes of interest; known kinks explain only 4–31% of small steps; member insertions explain ~0. |
| A noise floor from the fixed-iteration inner search | Confirmed at the source (the argmax does carry a resolution floor) but **refuted at the controller**: a 1000× reduction of the inner tolerance leaves the rejection fraction unchanged (≈0.20–0.31 either way). |

One diagnostic we have *not* run, and suspect: the error norm uses relative
scaling, and both `u_ℓ → u_min` and `ρ_j → 0` are vanishing components. They may
be demanding absolute accuracy on quantities `J` cannot feel.

## 4. The question we are actually stuck on

When the step size is set by local truncation error, the classical toolkit is
about stability, and none of it applies. What remains, in principle, is:

- **spend the accuracy budget better** — the error is presumably not uniformly
  distributed over components or over time, and we are resolving things the
  functional does not see;
- **change what is being resolved** — a different representation of the measure,
  or of the near-bound coordinate, so that the same accuracy costs less;
- **change what is being asked** — `J` as posed may not be an observable with a
  well-defined derivative near the collapse regime, in which case no solver work
  is worth anything until that is fixed.

We do not know how to rank these, and we may be missing a fourth.

## 5. Questions

1. Given an accuracy-limited adaptive explicit integration of a system with this
   structure, **is there any method class that reduces cost at fixed accuracy in
   the functional?** If the honest answer is that the global adaptive explicit
   method is at the frontier for this structure, we would like that stated
   plainly with the reason.

2. The cost is `n_micro × O(M)` for any scheme that sub-cycles `u`, and `O(M)`
   once per accepted step for the global scheme. Is there a factorization that
   makes the per-evaluation coupling genuinely `o(M)` **at functional-usable
   accuracy**, on a member set whose coordinates are placed to resolve `x` rather
   than the coupling integrand — given that the measure's weights are skewed and
   that dropping members destroys their adjoint channel?

3. **Is the error norm the actual lever?** Under relative-error scaling, `u → u_min`
   and `ρ_j → 0` demand tight absolute accuracy on vanishing quantities. What is
   the principled way to weight a local error estimate when the quantity of
   interest is a *moment* of the state rather than the state, and the moment
   amplifies state error ~10×? Is there an established construction for a
   functional-aware or goal-oriented error norm inside a standard embedded RK
   controller, and what does it cost?

4. **Is the representation wrong?** The weight equation differentiates the
   velocity field, so `log ρ` grows without bound wherever characteristics
   converge, while the *measure* remains perfectly well defined. Does that make
   pointwise density along characteristics the wrong dependent variable, and is
   the move a conservative / mass-based (finite-volume) representation? If so,
   what breaks for a moment readout and for reverse-mode differentiability?

5. **Is the functional the wrong object?** `J` is a step function of its inputs
   near the absorbing boundary `ρ → 0`: the adjoint computes a branch slope while
   a finite difference straddling the flip measures a jump, so "the gradient
   matches a finite difference of the solver as run" is unsatisfiable there by any
   method. Is the right move to mollify the boundary's entry into `J` with a
   declared width, to reformulate `J` so it never thresholds a member's
   existence, or is the non-convergence telling us something structural that
   should be respected rather than smoothed?

6. Which of the measured facts in §2 is **load-bearing** for your answer, and
   which is incidental? We do not know which of them matters and would rather you
   ranked them than took our ordering.

7. What have we not asked?

## 6. Constraints an answer can rely on

- The forcing kink grid is known in advance and steps can be aligned to it.
- `L ≤ 5`. Dense linear algebra on the small block is free.
- `ξ_j` and `ρ_j` are components of `y`, so any sum over all `M` members of
  already-known state costs arithmetic but **zero** inner solves.
- The full-`M` coupling is evaluated anyway at every accepted step, so a
  realized-error meter against any reduced model is free.
- Reverse-mode AD is a hard requirement on whatever is adopted; anything that
  must be recorded and replayed must be smooth on the tape, and a per-step
  data-dependent branch on an active value is not acceptable.
- We can change the model's formulation, not only the solver, if the change is
  declared and its effect on `J` is budgeted.
