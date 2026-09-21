# Step-size control for a bimodal, cluster-limited coupled IVP

A self-contained problem statement. No application domain is assumed. The
system, the integrator and its controller are specified in §1–§2; §3 is a
measured characterisation of how the controller actually behaves on it; §4 asks
what the controller should be instead.

## 1. The system

State `y(t) = (u, v, x)` on `[0, T]`, evolving by `y' = f(y, t; θ)` with
`θ ∈ ℝ^k`, `k ≈ 17`.

### 1.1 The small block

`u ∈ ℝ^L`, `L ≤ 5`, a one-way chain:

```
u̇_ℓ = s_ℓ(t)·[ℓ=1] − κ_ℓ u_ℓ^q + κ_{ℓ−1} u_{ℓ−1}^q − a_ℓ(x, u),   ℓ = 1 … L
```

- `q ≈ 16`. The loss is diagonal and the transfer `κ_{ℓ−1} u_{ℓ−1}^q` is
  strictly one-way, so `u_1` receives the forcing and `u_L` terminates the chain.
- `s_ℓ(t)` is piecewise-smooth with breakpoints on a **known** grid: mostly
  zero, occasionally large.
- A lower bound `u_ℓ > u_min`; approaching it, a quantity read off `u` diverges
  like `u^{−p}`, `p ≈ 6.6`.

### 1.2 The accumulators

`v ∈ ℝ^L`, with `v̇_ℓ` a flux already computed for `u̇`. These are pure
quadrature: nothing reads them, and they enter no functional.

### 1.3 The large block

`x` holds `M` members, `M ≈ 50 … 800`, each carrying an ordered scalar `ξ_j`,
a positive weight `ρ_j`, and O(1) further states. It is a discretised measure
transported along characteristics, `μ_t = Σ_j ρ_j δ_{ξ_j}`:

```
ξ̇_j           = g(ξ_j, u, p_j)
d(log ρ_j)/dt = − ∂g/∂ξ |_{ξ_j} − m(ξ_j, u, p_j)
```

Members are inserted on a schedule the caller controls and are never removed;
`ρ_j → 0` is absorbing and many members reach it.

### 1.4 Coupling, inner problem, output

Each member carries a scalar `p_j` defined as the solution of an inner scalar
problem `σ(p; ξ_j, u) = 0` — a safeguarded root of a feasibility condition on an
active constraint. The coupling is a weighted sum,
`a_ℓ(x, u) = Σ_j ρ_j c_ℓ(ξ_j, u, p_j)`. The output is a moment of the measure,
`J = Σ_j w_j φ(ξ_j, …)`. `dJ/dθ` is required by reverse-mode AD over the whole
trajectory.

## 2. The integrator and controller as configured

- Embedded explicit Runge–Kutta, Cash–Karp 5(4).
- Per-component weighted error ratio `r_i = |e_i| / (atol + rtol·|y_i|)`.
- **Acceptance on the max norm**: accept when `r_max = max_i r_i ≤ 1`.
- **Elementary (deadbeat I) controller**, no memory:
  `h_{n+1} = h_n · S · r_max^{−1/5}`. A rejection costs a full step.
- Integration restarts at every member-insertion time, so those are already step
  boundaries.
- Forcing breakpoints are **not** step boundaries.
- `s_ℓ(t)` is reconstructed from data on a uniform grid by a monotone `C¹`
  interpolant, so `f''` jumps at every knot.
- A Rosenbrock RODAS4(3) stepper exists in the same solver but carries no
  adjoint.
- The accepted step sequence is recorded and replayed on the reverse pass, so
  the controller is already off the tape: the norm may depend on anything
  without affecting differentiability.

## 3. Measured characterisation

### 3.1 Timescales

**(C1)** `u` relaxes on `1/|λ| ≈ 0.003` (`|λ| ≈ 240–470`); `x` moves on an O(1)
scale — separation ≈ 300×.

**(C2) The fast block self-regulates.** Scaling `κ` by 3000× raises `|λ|` by
2.0×; by 100×, 1.5×. `u` falls until `κu^q` collapses. A stiffness sweep in `κ`
is uninformative about the step constraint.

### 3.2 What limits the step, and it is not one thing

**(C3) The limitation is bimodal in the forcing regime.**

| forcing | `h·|λ|` | limited by |
|---|---|---|
| sustained, smooth | **3.5 – 5.3**, pinned across 13 wide-box parameter endpoints and a 100× `κ` sweep | the explicit stability boundary |
| impulsive | an order of magnitude below | local truncation error |

**(C4) Which component attains `r_max`**, histogrammed over every accepted step:

| binding component | sustained (530 steps) | impulsive (1017 steps) |
|---|---|---|
| `u_L` (chain terminus) | **77.4%** | 12.9% |
| `u_1 … u_{L−1}` | 6.6% | **56.3%** |
| the `L` accumulators `v` | **0%** | **0%** |
| all member states | 16.0% | 30.8% |
| — of which `log ρ_j` | 82% of those | 65% of those |

Sustained forcing concentrates the load on the single terminal state of the
chain; impulsive forcing moves it onto the component the forcing enters
(`u_1`: 2.1% → 21.5%) and spreads it across the chain.

**(C5) Low-weight members are not the binding population.** Member-binding steps
by the binding member's weight decile: the lowest decile takes 22.4%
(sustained) / 36.7% (impulsive) of member-binding steps — i.e. **3.6% / 11.3%
of all steps**. Under impulsive forcing the *newest, highest-weight* member
takes 45.7% of the member share.

**(C6) The binding ranking is a tight cluster, and this bounds every
reweighting scheme.** Removing **every** member component from the norm entirely
changes the accepted-step count by **0.2%** (sustained) and **0.9%**
(impulsive). The result is flat in the threshold: dropping 1% of member-steps
and dropping 100% of them agree to within one or two steps. Under the max norm
the small block sits immediately behind the binding member at nearly the same
ratio, so `h ∝ r_max^{−1/5}` has nothing to work with. Measured upper bound on
any member-side reweighting: **< 1% of accepted steps**.

### 3.3 The inner problem

**(C7)** The root is obtained by a **convergence-tested** iteration to relative
tolerance `1e-12`. The iteration count is data-dependent. It is therefore a
branch, and a noise floor in `f` at ≈`1e-12`.

**(C8)** Repeated evaluations of `f` at fixed `(y, t)` are bit-identical, and the
finite-difference derivative of `a_ℓ` in `u` converges to a finite limit. Across
the population, in the regimes of interest, every member lands in a single
smooth branch of `σ`. In two extreme forcing regimes two branches co-occur at
one instant, in 28% and 31% of members respectively.

### 3.4 Freezing the step sequence

**(C9) Trust region of a frozen grid.** Capture the accepted sequence at `θ_0`,
then replay it with no error control at other `θ`, shrinking every captured step
by a factor `s`:

| `s` | fraction of 64 evaluation points within 1e-4 relative in `J` |
|---|---|
| 1 | **57.8%** |
| 1.25 | 84% |
| 1.5 | 98.4% |
| 2 | **100%** (residual is the adaptive reference's own error) |
| 4 | no improvement over `s = 2` |

At `s = 2` this covers the full **±2× box in all six swept parameters**. At
`s = 1`, points as close as a 10% change in one parameter are wrong by tens of
percent.

- **Zero transfer across forcing realisations**: 40–100% error off the diagonal
  of a 7×7 transfer matrix, and `s` does not help — the failure is step
  *placement*, not step size.
- **Nothing ever diverged** in ~700 runs. The failure mode is "completes, with a
  finite, wrong `J`".
- Where a replay is badly wrong, `h·|λ|` on the replayed trajectory is 1.7–3.2×
  higher than on the adaptive run (up to 17.5); where it is right, `h·|λ|` is
  unchanged at ≈5.
- Cost: a frozen replay at `s = 1` is ~30% **cheaper** than the adaptive run it
  replaces (no error estimate, no rejections). So `s = 1.5` ≈ break-even and
  `s = 2` ≈ +45%.

**(C10) Sensitivity by finite difference.** Central FD of `dJ/dθ_1`, `δ` from
`1e-3` to `1e-9`:

- **adaptive: no plateau at any `δ`.** 5.6% error at `1e-4`, non-monotone from
  the second point, factor-2 error at `1e-5`, four orders and a sign error by
  `1e-9`. The best value is not identifiable from the sequence.
- **frozen: a monotone three-decade plateau** (`1e-3` → `3e-6`), 1.3% scatter,
  identifiable limit.
- The frozen sequence degrades below `δ ≈ 1e-6`, at the inner-solve noise floor
  (C7) — not at the grid.

**(C11) A hard-failure mode of controller-free stepping.** Two fixed-grid forms
exist. One takes each step bare: a domain violation inside a stage propagates
and kills the run, refusing at 25 of 64 parameter points, unpredictably (a +5%
change fails where a −50% change succeeds). The other subdivides on a violation
and always completes. Keeping the *captured breakpoints* is load-bearing: a grid
re-walked from scratch at strictly half the captured step everywhere still
refused at `θ_0` itself.

### 3.5 Where the operating point sits

**(C12) The default operating point is not in the asymptotic regime.** Under
impulsive forcing `J` moves **57%** between tolerance `1e-4` and `1e-6`. Under
sustained forcing `d log(steps)/d log(tol) = −0.167` over `1e-4 … 1e-8`, with
local slopes ranging `−0.064 … −0.345`, against `−0.20` for a clean fifth-order
response.

**(C13) Balance of errors.** The measure's discretisation error is `O(Δξ²)`,
roughly `(1/M)²` relative: ≈`1e-6` at `M = 800`, ≈`4e-4` at `M = 50`. Time is
routinely resolved far finer than `ξ`.

**(C14) Forcing geometry.** `f''` jumps on a known uniform grid whose spacing is
**finer** than the mean accepted step by a factor 1.5–2.6. Aligning to every
knot therefore imposes a floor of one step per knot rather than removing a
penalty.

**(C15) Cost structure.** The member loop is ~86% of an `f` evaluation and is
`O(M)`. The member enters the inner root only through `(ξ_j, u) ∈ ℝ^{1+L}`.

**(C16) A non-stiff instance of the same code path shows none of this.** A
variant of the same model family with no stiff small block replays correctly on
the raw captured grid (`s = 1`) to `2.6e-5 … 8.1e-5` over a ±100% parameter
change, under both replay forms.

## 4. Questions

### 4.1 The norm

C6 says a max norm over a tightly clustered ranking makes subset reweighting
worthless — not marginal, worthless. (a) Is the correct response to abandon the
max norm? Under a weighted 1-norm or RMS, does the cluster bound relax, and at
what cost in reliability? (b) Is there an a priori diagnostic — an "effective
number of binding components" computable from one instrumented run — that
predicts the gain available from any proposed norm before it is implemented?
(c) Given C4, the `L` accumulator channels are provably quadrature-only and
provably never bind: is a seminorm that zeroes them worth anything, or is the
cluster the entire story? (d) Does the answer change when the goal is not the
state but the functional `J`, i.e. when the natural weights are the discrete
adjoints `λ_n = ∂J/∂y_n`?

### 4.2 Regime-adaptive control

Behaviour is bimodal (C3), and the binding component moves with the regime (C4).
(a) What is the cheapest reliable **online** detector of which regime the
integration is in? (b) What controller is optimal in each, and is a *switched*
step-size controller stable — what hysteresis or dwell-time condition is
required to stop it chattering at a regime boundary? (c) Does the answer change
given that the impulse times are known in advance, so the regime schedule is
largely predictable rather than discovered?

### 4.3 The controller as a digital filter

The current law is the memoryless deadbeat `h_{n+1} = h_n S r^{−1/5}`. The
measured setting: `h·|λ|` pinned at the stability boundary under sustained
forcing (C3); a known impulse grid; an expensive `f` (C15); a rejection costing
a full step. (a) Which controller from the digital-filter family (PI,
predictive, H211b, PI42, …) is optimal here, and what determines the answer —
the stability-boundary pinning, the impulse-induced transients, or the cost
asymmetry between a rejection and a too-small step? (b) What limiter and safety-
factor policy follows? (c) How should a controller *with memory* be reset at a
known impulse or an insertion boundary, where the step-size history is not
informative about what comes next? (d) Is there a controller that is provably
better than deadbeat when the binding component changes identity from step to
step, as C4 shows it does?

### 4.4 Frozen versus adaptive, and the hybrid

Given C9 and C10. (a) Is "shrink by the largest factor by which `|λ|` can rise
across the parameter box" the right safety-factor rule? The measurement is that
`|λ|` rises 1.5× over a 100× change in `κ` and `s = 2` suffices — is the margin
between 1.5 and 2 explicable, and does the rule generalise? (b) What is the
principled trigger for re-capturing the grid inside an optimisation loop, and is
`Σ_n λ_nᵀ e_n` from the reverse pass the right certificate given that the frozen
grid is exactly what makes that reverse pass well-defined? (c) Zero transfer
across forcing realisations (C9) is reported as a limitation; since the forcing
is fixed throughout a calibration, is one grid per forcing realisation simply
correct, or is there a reason to want transfer? (d) Is there a middle design
that keeps adaptivity while removing the `θ`-dependence of the accepted
sequence — freezing only within a finite-difference pair, or a controller whose
accept/reject decision is a smooth function of the state rather than a
threshold?

### 4.5 Failure handling without a controller

C11: one controller-free form propagates a domain violation as a hard failure at
39% of a parameter box; the other subdivides and always completes, but a
subdivision is itself a data-dependent branch — the very thing freezing the grid
was meant to eliminate. What is the right design for a fixed-grid integrator's
failure handling such that it stays `θ`-smooth and still survives a domain
violation? Is a projection, a smoothed barrier, or a reformulation that cannot
violate the domain the correct answer, and what does each cost in bias?

### 4.6 Joint tolerance allocation

Three tolerances interact: the controller's `(atol, rtol)`; the inner root's
(`1e-12`, convergence-tested, C7); and the measure's discretisation, `O(1/M²)`
(C13). Measured: the FD plateau bottoms out at the inner floor, not the grid
(C10). (a) What is the principled joint allocation? (b) Should the inner solve
be a **fixed-iteration-count** Newton — smooth and branch-free, but a slightly
different function than the exact root — and what does that change for the
controller, for the tape, and for `J`? (c) Is there a reason to make the inner
tolerance a function of the current step's accepted error rather than a
constant?

### 4.7 Operating outside the asymptotic regime

C12: at the tolerance the system is normally run at, `J` is not converged, and
the step-count response to tolerance is not the asymptotic power law. Classical
step-size control theory assumes the asymptotic regime. (a) How should a
controller behave outside it? (b) Can it detect that it is outside it cheaply
and online? (c) Is a controller that silently returns a non-converged answer at
the user's requested tolerance a defect to fix in the controller, or strictly a
tolerance-selection problem for the caller?

### 4.8 Alignment when the kink grid is finer than the step

C14: `f''` jumps on a known grid finer than the mean step. (a) What is the right
policy — align anyway and loosen the tolerance to pay for it, coarsen the
forcing reconstruction with a budgeted bias, or reconstruct at higher continuity
so there is nothing to align to? (b) What is the actual order loss from a `C¹`
kink (a jump in `f''`, not in `f`) inside a step of a 5(4) pair, and how much of
C12's departure from the asymptotic power law can it explain? (c) If the
reconstruction is changed, what is the right constraint to impose — monotonicity
of the primitive, positivity of the rate, exact preservation of the integral
over each cell?

### 4.9

Which of C1–C16 is **load-bearing** for each answer and which is incidental?
What has not been asked?

## 5. Constraints an answer can rely on

- The controller is already off the tape: the accepted sequence is recorded and
  replayed, so the acceptance rule may depend on anything, including quantities
  from a previous solve.
- Reverse-mode AD is required. Anything on the tape must be smooth; a per-step
  data-dependent branch on an active value is not acceptable.
- `L ≤ 5`; dense linear algebra on the `u` block is free, and its Jacobian is
  analytic (bidiagonal, diagonal `−qκ_ℓ u_ℓ^{q−1}`).
- A sum over all `M` members of already-known state costs arithmetic but zero
  inner solves.
- The full-`M` coupling is evaluated at every accepted step, so a realized-error
  meter against any reduced model is free.
- The forcing breakpoint grid is known in advance, as are the insertion times.
- An L-stable Rosenbrock stepper is available but has no adjoint; adding one is
  work, not wiring.
- The model's formulation may be changed, not only the solver, if the change is
  declared and its effect on `J` is budgeted.
