# Three grids on one axis: choosing a discretisation for a functional

A self-contained problem statement. No application domain is assumed. The
system is a transported measure coupled to a small stiff block under a known
forcing; the output is one scalar. The forcing realisation is **fixed and known
in advance** — it is data, not a random draw, and it does not change between
runs. The question is how to choose the discretisation.

## 1. The system

State `y(t) = (u, v, x)` on `[0, T]`, integrated by an adaptive embedded
explicit Runge–Kutta pair (Cash–Karp 5(4)) under a max-norm local error test.

### 1.1 The small block

`u ∈ ℝ^L`, `L ≤ 5`, a one-way chain with a steep power-law loss:

```
u̇_ℓ = s(t)·[ℓ=1] − κ_ℓ u_ℓ^q + κ_{ℓ−1} u_{ℓ−1}^q − a_ℓ(x, u),   q ≈ 16
```

`v ∈ ℝ^L` are pure accumulators (`v̇_ℓ` is a flux already computed): nothing
reads them and they enter no functional. A lower bound `u_ℓ > u_min` applies.

### 1.2 The large block, and its label

`x` holds `M` members. Member `j` is created at time `b_j` and carries a
position `ξ_j(t)`, a weight `ρ_j(t) > 0`, and six further states — eight
components each. It is a measure transported along characteristics,
`μ_t = Σ_j ρ_j δ_{ξ_j}`, with `ξ̇_j = g(ξ_j, u, p_j)` and a weight equation.

The creation times `b_j` are the **characteristic labels**. Two coordinates are
available for the quadrature over `μ_t`:

- the **label coordinate**, abscissa `b_j`: fixed for all time, the map from
  creation schedule to quadrature abscissa is the **identity**, and the grid can
  never fold;
- the **transported coordinate**, abscissa `−ξ_j(t)`: moves with the flow, and
  folds wherever two members coincide in `ξ`, exactly where the pointwise
  density is undefined.

**Reverse-mode differentiation is available only on the label coordinate.** On
the transported coordinate the weights' own sensitivity channel is dropped and
nothing supplies it, so the adjoint refuses that coordinate rather than
answering on it.

### 1.3 Coupling, inner problem, output

Each member carries `p_j` solving an inner constrained scalar optimisation in
`(ξ_j, u)`, whose solution is piecewise-smooth with switching surfaces (an
interior stationary point and three active-constraint boundaries). The coupling
is `a_ℓ(x, u) = Σ_j ρ_j c_ℓ(ξ_j, u, p_j)`.

The output is a space–time moment of the measure — a scalar `J`, accumulated
over `[0, T]` and over members. `dJ/dθ` is required by reverse-mode AD over the
whole trajectory, `θ ∈ ℝ^k`, `k ≈ 17`.

## 2. Three grids, one axis

Every discretisation in this system is a grid on `[0, T]`, and the three are
chosen by three unrelated mechanisms:

| grid | what it discretises | how it is chosen now | count over `[0,T]` |
|---|---|---|---|
| `𝒢_b` — creation times | the quadrature over `μ_t` (on the label coordinate, identically) | a dyadic heuristic, then error-driven bisection | **88** |
| `𝒢_t` — step times | the time integration | an adaptive controller, per step, reactively | **530** (sustained) / 1017 (impulsive) |
| `𝒢_f` — forcing knots | the reconstruction of `s(t)` | the sampling rate of the input data | **1825** |

Roughly `21 : 6 : 1`. Note that the step grid is **coarser than the forcing
grid it is meant to resolve**.

Relations that hold now: `𝒢_b ⊂ 𝒢_t` (the integration restarts at every
creation time). `𝒢_f ⊄ 𝒢_t` — forcing knots are not step boundaries.
`s(t)` is reconstructed as a monotone `C¹` interpolant, so `f''` jumps at every
knot of `𝒢_f`.

## 3. Measured

**(D1) The two discretisation errors are three to five orders apart.** Under
smooth sustained forcing, measured against a uniform 349-node reference grid:

| | node-grid error at `M = 88` | time error over `tol` 1e-4 → 1e-6 |
|---|---|---|
| label coordinate | **0.242 %** | 6.6e-8 |
| transported coordinate | **1.00 %** | 3.7e-6 |

**(D2) The node grid's error tolerance is a silent no-op.** Its threshold is set
at 2e-2 against a time tolerance of 1e-4. Under sustained forcing the largest
per-node error indicator is 0.0099 — half the threshold — so refinement never
fires and the refined grid equals the unrefined grid exactly.

**(D3) Tightening it converges, monotonically, and is nearly free.**

| threshold | label coord | transported coord |
|---|---|---|
| 2e-2 | 88 nodes, 0.242 % | 88 nodes, 1.00 % |
| 5e-3 | 92 nodes, 0.233 % | 94 nodes, 0.48 % |
| 1e-3 | 117 nodes, **0.050 %** | 127 nodes, **0.13 %** |

Cost: three extra model runs, and the accepted step count moves 531 → 554.

**(D4) Under impulsive forcing the two grids are not separable at the operating
tolerance.** Changing `𝒢_b` at `tol = 1e-4` moves `J` by −65 % / +57 %
(coordinate-dependent), because moving a creation time changes which forcing
impulse a step lands on. The same change measured at `tol = 1e-5` and `1e-6`
moves `J` by −0.167 % and −0.218 %. The large numbers are time error re-rolled
by a change to the *other* grid.

**(D5) The node-grid error indicator is not a bound on the error in `J`.** It is
a delete-a-node quadrature difference. Its stopping rule fires while `J` is
still moving by a factor of 3.0–4.3 across refinement iterations at
`tol = 1e-4`, and the indicator is not monotone under bisection (it rises on two
of seven refinements before falling).

**(D6) Refinement costs re-runs, not nodes.** Seven to ten full model
evaluations (the loop re-runs before each bisection); the node count grows ~10 %
and the final run's step count by 0.3–5 %.

**(D7) The step controller rejects 19–28 % of attempts**, spending 17–27 % of
all right-hand-side evaluations on discarded work. About three quarters are
local-error rejections; one quarter are a per-member inequality constraint whose
boundary is attracting.

**(D8) Under sustained forcing 77 % of accepted steps are set by one component**
— the terminus of the `u` chain — at the explicit stability boundary,
`h·|λ| ≈ 3.5–5.3`, pinned across a 100× sweep of `κ` and across a ±2× parameter
box. Under impulsive forcing the load spreads across the chain and onto the
members.

**(D9) The cost of `f` is 86 % the member loop**, `O(M)`, one inner solve per
member. The small block is 14 %. So the majority of steps are forced by 14 % of
the work, to resolve 10 of ~714 components.

**(D10) A frozen step grid works over a wide parameter box but not across
forcing realisations.** Captured at `θ₀` and replayed with every step shrunk by
a factor `s`: `s = 2` holds the full ±2× box in six parameters to 1e-4; `s = 1`
holds 58 % of it. Across forcing realisations, zero transfer, and `s` does not
help — the failure is step *placement*. Replay costs ~30 % less than the
adaptive run it replaces.

**(D11) Only a fixed step grid gives a usable derivative.** Finite differences
of `J` in `θ` over `δ` from 1e-3 to 1e-9: the adaptive solver produces **no
plateau at any `δ`** (non-monotone from the second point, four orders and a sign
error by 1e-9); a frozen grid produces a clean monotone three-decade plateau
that bottoms out at the inner solve's noise floor, not the grid's.

**(D12) The forcing grid is finer than the step grid** by a factor 1.5–2.6, and
`f''` jumps at every one of its knots.

## 4. Questions

### 4.1 The joint design

For a **fixed, known forcing realisation**, what is the minimal well-understood
framework that chooses `𝒢_b`, `𝒢_t` and the reconstruction of `s` **together**,
to minimise the error in `J` at fixed cost? D1 and D4 say they cannot be chosen
independently: the errors differ by orders of magnitude, they converge at
different rates (`O(Δb²)` against `O(h⁵)`), they cost different amounts per unit
of error, and at the operating tolerance a change to one is reported as a change
in the other.

Is goal-oriented (dual-weighted-residual) adaptivity with a single adjoint the
right frame — one adjoint solve giving separate error contributions for the
quadrature grid, the time grid and the forcing reconstruction, then
equidistribution between them? If so, what does it require here that a
characteristic-method transport solver does not naturally provide, and what is
the honest cost? If not, what is the standard alternative for a coupled pair of
discretisations with one functional target?

Is equidistribution even the right principle when the two errors have different
convergence orders and different marginal costs, or should the split be set by
equalising *marginal error reduction per unit cost* instead?

### 4.2 Nesting

Should the three grids be nested, `𝒢_b ⊂ 𝒢_t ⊇ 𝒢_f`? `𝒢_b ⊂ 𝒢_t` already
holds. Making `𝒢_f ⊂ 𝒢_t` would end every step on a forcing knot, removing the
`C¹` kink from every step interior (D12) — at the price of a floor of one step
per knot, which is 1825 against a current 530. What is the right trade: align
and loosen the tolerance, coarsen the forcing reconstruction with a declared
bias, or reconstruct `s` at higher continuity so there is nothing to align to?

Does nesting buy anything else — a hierarchy for error estimation, a
Richardson/extrapolation structure, reuse across refinement levels?

### 4.3 The right indicator

D5: the node grid's indicator is a local quadrature difference, and its stopping
rule terminates while `J` is still moving. What is the correct indicator for a
quadrature grid whose purpose is a space–time functional — the adjoint-weighted
node residual, the change in `J` itself across refinement levels (free, since
refinement re-runs anyway, D6), or something else? What stopping rule actually
certifies a bound on `J`?

### 4.4 Does a designed discretisation put other methods on the frontier?

This is the question behind the rest. Take D8 and D9 together: the majority of
steps are set by a 10-component stiff block that is 14 % of the cost, while 86 %
of the cost is a slow expensive member loop that does not need those steps. That
is the textbook multirate configuration, with the cost asymmetry pointing the
right way — but it was previously set aside on the grounds that a cheaper `f`
would make it unnecessary.

(a) With the grids designed in advance rather than discovered by rejection, is
multirate now on the frontier, and in what minimal form — MRI-GARK, an
extrapolated multirate method, or something simpler? What is the order barrier
in practice, and what does the coupling `a_ℓ(x,u)` cost in accuracy when the
member block is held over a macro-step?

(b) Is the right split multirate (different step sizes) or IMEX/partitioned
(different treatment at one step size)? What decides, given the small block has
an analytic bidiagonal Jacobian and `L ≤ 5`, and given the stability constraint
is regime-dependent (D8)?

(c) What *else* becomes available once the grid is fixed and known in advance
that is not available under adaptive control — spectral deferred correction,
parallel-in-time, exponential or Lawson integrators for the stiff chain,
Richardson extrapolation on a nested hierarchy? Which of these are genuinely
well-understood for a system with switching surfaces and a reverse-mode
requirement, and which would be brittle here?

### 4.5 Reuse across parameters

D10 and D11: a frozen grid is what makes the derivative usable at all, holds a
±2× parameter box with a safety factor, and does not transfer across forcing
realisations. Given the forcing is fixed throughout a calibration, is "one
designed discretisation per forcing realisation, reused across `θ`" simply the
correct answer? If so, what certifies the reuse — and is a certificate computed
during the replay (a stability check plus an adjoint-weighted error sum) the
right instrument, or is something stronger needed?

Does a discretisation *designed* from the forcing schedule and the predicted
dynamics have a wider reuse region than one *captured* from an adaptive run at a
nominal `θ`, and is that difference structural or incidental?

### 4.6 What is load-bearing, and what has not been asked

Which of D1–D12 carries each answer, and which is incidental? Given the
constraint that the machinery must be minimal and well-understood rather than
custom, what is the smallest set of changes that gets the discretisation right,
and in what order? What has not been asked?

## 5. Constraints an answer can rely on

- The forcing realisation is fixed and known in full before the run; so are the
  creation times, whatever they are set to.
- Reverse-mode AD is required, and only the label coordinate supports it. A
  per-step data-dependent branch on an active value is not acceptable; the step
  sequence is recorded and replayed, so the *choice* of grid is off the tape.
- `L ≤ 5`; dense linear algebra on the small block is free, and its Jacobian is
  analytic and bidiagonal.
- A sum over all `M` members of already-known state costs arithmetic but no
  inner solves.
- An L-stable Rosenbrock stepper exists in the same solver but carries no
  adjoint; adding one is work, not wiring.
- The model's formulation may be changed — the reconstruction of `s`, the
  inequality constraint, the dependent variable of the weight equation — if the
  change is declared and its effect on `J` is budgeted.
- Cost is measured in right-hand-side evaluations; the member loop dominates
  them.
