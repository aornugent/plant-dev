# An accuracy-limited coupled IVP with a functional target

A self-contained problem statement. No application domain is assumed; everything
is stated as mathematics. We want to integrate this system faster, or to a
better-conditioned derivative, without losing accuracy in a scalar functional of
the solution — and we want to know which of those is actually available.

## 1. The system

State `y(t) = (x, u)` on `[0, T]`, evolving by `y' = f(y, t; θ)` with a parameter
vector `θ ∈ ℝ^k`, `k ≈ 17`. Integrated by an adaptive embedded explicit
Runge–Kutta method (Cash–Karp 4/5) under a standard local-error controller.

### 1.1 The small block

`u ∈ ℝ^L`, `L ≤ 5`:

```
u̇_ℓ = b_ℓ(u, t) + T_ℓ(u) − a_ℓ(x, u),      ℓ = 1 … L
```

- `b_ℓ` contains a diagonal power-law loss `−κ_ℓ u_ℓ^q`, exponent `q ≈ 16`, and a
  time-inhomogeneity that is piecewise-smooth with kinks on a **known** grid
  (impulsive, mostly zero, occasionally large).
- `T_ℓ` is a one-way bidiagonal transfer `T_ℓ = κ_{ℓ−1} u_{ℓ−1}^q`.
- A lower bound `u_ℓ > u_min`. Approaching it, a quantity read off `u` diverges
  like `u^{−p}`, `p ≈ 6.6`.

### 1.2 The large block

`x` holds `M` members, `M ≈ 50 … 800`. Member `j` carries an ordered scalar
coordinate `ξ_j`, a positive weight `ρ_j`, and O(1) further per-member states.
It is a discretised measure transported along characteristics,
`μ_t = Σ_j ρ_j δ_{ξ_j}`, with

```
ξ̇_j            = g(ξ_j, u, p_j)
d(log ρ_j)/dt  = − ∂g/∂ξ |_{ξ_j} − m(ξ_j, u, p_j)
```

New members are inserted on a schedule the caller controls; members are never
removed, but `ρ_j → 0` is an absorbing state that many members reach.

### 1.3 The coupling and the inner problem

Each member carries a scalar control `p_j`, defined as the solution of an inner
scalar problem `σ(p; ξ_j, u) = 0` — a safeguarded root of a stationarity/
feasibility condition (not an interior extremum; the operating point sits on an
active constraint whose defining equation is `σ`). The coupling into the small
block is a weighted sum over all members:

```
a_ℓ(x, u) = Σ_{j=1}^{M} ρ_j c_ℓ(ξ_j, u, p_j),     ℓ = 1 … L
```

### 1.4 The output

A scalar functional, itself a moment of the measure:

```
J = Σ_j w_j φ(ξ_j, …)
```

The derivative `dJ/dθ` is required, by reverse-mode automatic differentiation
over the whole trajectory.

## 2. Measured properties

All of the following are measured on the system as integrated.

**(P1) Two timescales, and the fast one self-regulates.** The `u` block relaxes
on `1/|λ| ≈ 0.003` (`|λ| ≈ 240–470`); the `x` block moves on an O(1) scale — a
separation near 300×. Scaling the loss coefficient `κ` by 3000× raises `|λ|` by
only ~2×: `u` falls until `κ u^q` collapses (the loss is self-limiting in its own
state). A stiffness sweep in `κ` is therefore not informative about the step-size
constraint.

**(P2) The right-hand side is a deterministic, smooth function of the state.**
Repeated evaluations of `f` at a fixed `(y, t)` are bit-identical. The finite-
difference derivative of `a_ℓ` with respect to `u` converges to a finite limit as
the step shrinks (no noise floor). The inner root `p_j` is obtained
deterministically; across the population, in the regimes of interest, every
member lands in a single smooth branch of `σ` (no active-set changes), so `a_ℓ`
and its derivatives are smooth in `(ξ, u)`.

**(P3) The step is accuracy-limited, not stability-limited.** Tightening the
tolerance raises the accepted-step count while `J` is unchanged to many digits.
The product `h·|λ|` depends on the forcing regime — at the explicit stability
boundary (~3.5) under smooth forcing, an order of magnitude or more below it
under impulsive forcing — and does not track `κ` (P1). Under the impulsive
forcing of interest the binding constraint is local truncation error.

**(P4) The controller spends its budget on vanishing components.** The local
error norm scales each component by `atol + |y_i|·rtol`. A member whose weight
`ρ_j` has decayed toward zero — contributing negligibly to `J` — is still held to
`atol` in absolute terms. With `rtol` fixed, tightening `atol` from 1e-4 to 1e-8
raises the accepted-step count 689 → 1244 while `J` moves by 3e-6 (reference-
limited). The extra steps buy accuracy only in components the functional does not
weight.

**(P5) The coupling is O(M)-expensive but low-dimensionally parameterised.** Each
term of `a_ℓ` needs one inner root solve; the member loop is ~86% of an `f`
evaluation and scales linearly in `M`. But `c_ℓ` depends on member `j` only
through `(ξ_j, u) ∈ ℝ^{1+L}`, `L ≤ 5`, and (P2) lands in a single smooth branch
across the population.

**(P6) The forcing kinks are known in advance.** The breakpoints of the
piecewise-smooth time-inhomogeneity in `b` are a known grid; steps can be aligned
to them.

**(P7) The functional has a boundary discontinuity.** `J` is a moment of the
measure; a member reaching the absorbing state `ρ_j → 0` removes its
contribution. The reverse-mode derivative captures the interior sensitivity but
not the jump at a boundary crossing, so `dJ/dθ` across a crossing is not matched
by a finite difference straddling it.

**(P8) The representation carries pointwise density along characteristics.** The
weight equation differentiates the velocity field (`∂g/∂ξ`), so `log ρ_j` grows
without bound where characteristics converge, while the measure `μ_t` itself
remains well defined.

## 3. Questions

1. **Error control for a functional target.** The step is accuracy-limited (P3)
   and the quantity of interest is the moment `J`, not the state, while the state
   carries components that vanish and that `J` does not weight (P4). What is the
   principled local-error control here — component-wise absolute floors at each
   state's noise level, an adjoint/functional-weighted norm, a seminorm that
   zeroes quadrature-only channels — and what does each cost inside a standard
   embedded RK controller? What is the failure mode (e.g. a vanishing component
   whose error later transports into a `J`-sensitive one)?

2. **An o(M) coupling.** Given P5 — `a_ℓ` is a `ρ`-weighted sum of a smooth
   kernel `c(ξ, u)` sampled at `M` members, the member entering only through a
   `(1+L)`-dimensional argument and a single branch — is there a factorization
   making the per-evaluation coupling `o(M)` at usable accuracy in `J`, while
   (a) integrating the (skewed) weights `ρ_j` exactly, so no member loses its
   adjoint channel, and (b) preserving reverse-mode derivatives with respect to
   `θ`? A separated form `a_ℓ ≈ Σ_r β_{ℓr}(u)·G_r`, `G_r = Σ_j ρ_j T_r(ξ_j)`
   (exact moments, zero inner solves) is one candidate; is it the right one, and
   what controls its error and its `θ`-derivative?

3. **The representation.** Given P8, is pointwise density along characteristics
   the wrong dependent variable? Is the conserved-mass form (integrated mass per
   member; a finite-volume statement of the same transport) the right one, and
   what does the change cost for the moment `J` and for reverse-mode
   differentiability?

4. **Well-posedness of the functional.** Is `J` differentiable in `θ` near the
   absorbing boundary (P7)? If not, is the remedy a declared mollification of the
   boundary's entry into `J` with a budgeted bias, a reformulation that never
   thresholds a member's existence, or is the non-differentiability structural (a
   bifurcation) and to be respected rather than smoothed?

5. **The integrator.** For an accuracy-limited, expensive-RHS, moderately-sized
   IVP with a smooth deterministic right-hand side (P2), known forcing kinks
   (P6), and a reverse-mode requirement — what integrator minimises cost at fixed
   `J`-accuracy? Consider method order; alignment of steps to the kink grid and
   its effect on the observed order; and whether a well-tuned adaptive explicit
   RK is already at the frontier for this structure, with the reason.

6. Which of the properties in §2 is **load-bearing** for each answer, and which
   is incidental? What has not been asked?

## 4. Constraints an answer can rely on

- The forcing kink grid is known in advance; steps can be aligned to it.
- `L ≤ 5`; dense linear algebra on the `u` block is free.
- `ξ_j` and `ρ_j` are components of `y`, so a sum over all `M` members of
  already-known state costs arithmetic but zero inner solves.
- The full-`M` coupling is evaluated at every accepted step, so a realized-error
  meter against any reduced model of `a` is free.
- Reverse-mode AD is required. Anything recorded and replayed must be smooth on
  the tape; a per-step data-dependent branch on an active value is not
  acceptable.
- The model's formulation may be changed, not only the solver, if the change is
  declared and its effect on `J` is budgeted.
