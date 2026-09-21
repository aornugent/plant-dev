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

`x` holds `M` members, each carrying an ordered scalar `ξ_j`, a positive weight
`ρ_j`, and six further per-member states — **eight components per member**. It
is a discretised measure transported along characteristics,
`μ_t = Σ_j ρ_j δ_{ξ_j}`:

```
ξ̇_j           = g(ξ_j, u, p_j)
d(log ρ_j)/dt = − ∂g/∂ξ |_{ξ_j} − m(ξ_j, u, p_j)
```

Members are inserted on a schedule and never removed. `M` grows to **88** over
the horizon used throughout §3, giving ~714 state components against the small
block's `2L = 10`.

Two structural facts about this block matter for the controller:

**(i) One per-member state is inequality-constrained, and its boundary is
attracting.** A scalar pool `z_j ≥ 0` drains toward zero under ordinary
dynamics; the constraint is enforced by *rejecting the step*, not by projection
or by a barrier in `f`. The guard compares against `−ε·z_max` rather than
against exact zero, because a member resting on the boundary is round-off-noisy
on its own scale and an exact comparison refuses nearly every attempt there.

**(ii) `log ρ_j` legitimately attains `−∞`** in floating point — the absorbing
state is reached, not approached. Because the error weight is
`rtol·|y_i| + atol`, such a component's weight is infinite and its error ratio
is identically zero, so a fully absorbed member drops out of the error norm with
no threshold and no special case.

### 1.4 Coupling, inner problem, output

Each member carries a scalar `p_j` obtained by solving an inner **constrained
scalar optimisation** in `(ξ_j, u)`. Its solution is classified into one of
several outcomes: an interior stationary point, **three distinct
active-constraint boundaries**, two terminal states, and two failure states. So
`p = P(ξ, u)` is piecewise-smooth with **switching surfaces in `(ξ, u)`**, `C⁰`
across them; which piece is active varies by member and evolves in time. The
solve is a safeguarded root of the relevant stationarity/feasibility condition,
**convergence-tested** to relative tolerance `1e-12` with a data-dependent
iteration count.

The coupling is a weighted sum, `a_ℓ(x, u) = Σ_j ρ_j c_ℓ(ξ_j, u, p_j)`. The
output is a moment of the measure, `J = Σ_j w_j φ(ξ_j, …)`. `dJ/dθ` is required
by reverse-mode AD over the whole trajectory.

## 2. The integrator and its controller, exactly as configured

**Method.** Embedded explicit Runge–Kutta, Cash–Karp 5(4), first-same-as-last by
construction: an accepted step costs **five stage evaluations plus one
evaluation at the endpoint**, which the next step takes as its `k₁`. `f` is
expensive (§3, C17).

The endpoint evaluation is formed **before** the error estimate is tested and is
discarded on rejection, so an accuracy rejection costs six — the same as an
accepted step, not five. Only a rejection that *throws* costs less, aborting at
the offending stage (measured mean 3.0–4.7, C19).

**Error weight.** Per component,

```
D_i = rtol·( a_y·|y_i| + a_dydt·|h·ẏ_i| ) + atol ,     r_i = |e_i| / D_i
```

Configured: `atol = rtol = 1e-4`, `a_y = 1`, `a_dydt = 0`. The
derivative-weighted term exists and is switched off.

**Norm.** The **max** norm, `r_max = max_i r_i`, scanned in index order and
**broken at the first non-finite ratio**, which is treated as a validity
rejection rather than folded into the maximum.

**Response — three zones, with a dead band.** With `S = 0.9` and `ord = 5`:

| zone | action |
|---|---|
| `r_max > 1.1` | reject; `h ← h · max(0.2, S·r_max^{−1/ord})` |
| `0.5 ≤ r_max ≤ 1.1` | accept; **`h` unchanged** |
| `r_max < 0.5` | accept; `h ← h · clamp(S·r_max^{−1/(ord+1)}, 1, 5)` |

Three things to note. The acceptance threshold is **1.1, not 1**. There is an
explicit dead band over `[0.5, 1.1]` in which the controller does nothing. The
shrink and growth exponents **differ** — `1/ord` against `1/(ord+1)` — and
`ord` is set to 5 carrying an inherited annotation questioning whether it should
be 4.

**The floor accepts.** If the computed shrink is not actually smaller than the
current step (already at `h_min`), no shrink is reported and **the inaccurate
step is committed**. This is deliberate and is documented as acceptable for
accuracy and never for validity. Measured: it never fires (C19).

**Validity rejection is a separate path** with its own rule, `h ← max(0.2·h,
h_min)`, always reported as a shrink even when it cannot decrease. It fires on
either of:

1. a stage throwing a domain error — the per-member pool of §1.3(i) going
   negative, or the small block going non-finite;
2. a completed step landing on a state the system refuses — **this overrides an
   `accept` verdict from the error estimate**.

Measured (C19): path 2 never fires, because what it would refuse is caught a
stage earlier by path 1; and every throw on path 1 is the per-member pool, never
the small block. Domain rejections are routine rather than exceptional — 4.1% of
attempts under sustained forcing, 7.4% under impulsive — and a controller-free
replay of a recorded step sequence meets one at 39% of the parameter points
tried (C13).

**Retry loop.** Unbounded; there is no attempt cap. On a shrink the state and
time are restored and the step is retried. The run fails only when the step is
at `h_min` and the state is still invalid.

**Fragmentation.** Integration is not one sweep. It is split into **88 legs** by
the insertion times, which lie on a dyadic geometric grid
`Δ = 2^⌊log₂(0.2 t)⌋` clamped to `[1e-5, 2]` — leg lengths spanning `1e-5` to
`0.5`. At the configured tolerance this is **~6 accepted steps per leg**. The
final step of each leg is clipped to land exactly on the boundary and
**deliberately does not update the carried step size**, so controller history
survives the boundary; but the carried size is then applied across a **discrete
change in the system** (a member is inserted), and a step size inherited across
that change is the documented cause of the small block leaving its bounds and
triggering the validity path above.

**Limits.** `h_init = h_min = 1e-6` (they are equal), `h_max = 5`, which is the
whole horizon.

**Alternative paths in the same solver.** A fixed-step forward Euler; a
Rosenbrock RODAS4(3) that carries no adjoint; and two controller-free replay
forms whose behaviour differs sharply (C13).

**Tape.** The accepted step sequence is recorded and replayed on the reverse
pass, so the controller is already off the tape: the acceptance rule may depend
on anything without affecting differentiability.

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

**(C8) The right-hand side is deterministic and smooth away from the switching
surfaces.** Repeated evaluations of `f` at fixed `(y, t)` are bit-identical, and
the finite-difference derivative of `a_ℓ` in `u` converges to a finite limit.

**(C9) Which branch of the inner problem is active is regime-dependent, and
mostly uniform across the population.** Censused over seven forcing regimes: in
five of them a single branch holds population-wide at every instant, even where
the whole population *migrates* from one branch to another over the run. In the
two most extreme regimes two branches co-occur at one instant, in 28% and 31% of
members. So the population crosses switching surfaces continually in time, but
usually together rather than member by member.

**(C10) There is no event detection.** Steps are not aligned to switching-surface
crossings, to the forcing breakpoints, or to anything but the insertion times.

### 3.4 Freezing the step sequence

**(C11) Trust region of a frozen grid.** Capture the accepted sequence at `θ_0`,
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

**(C12) Sensitivity by finite difference.** Central FD of `dJ/dθ_1`, `δ` from
`1e-3` to `1e-9`:

- **adaptive: no plateau at any `δ`.** 5.6% error at `1e-4`, non-monotone from
  the second point, factor-2 error at `1e-5`, four orders and a sign error by
  `1e-9`. The best value is not identifiable from the sequence.
- **frozen: a monotone three-decade plateau** (`1e-3` → `3e-6`), 1.3% scatter,
  identifiable limit.
- The frozen sequence degrades below `δ ≈ 1e-6`, at the inner-solve noise floor
  (C7) — not at the grid.

**(C13) A hard-failure mode of controller-free stepping.** Two fixed-grid forms
exist. One takes each step bare: a domain violation inside a stage propagates
and kills the run, refusing at 25 of 64 parameter points, unpredictably (a +5%
change fails where a −50% change succeeds). The other subdivides on a violation
and always completes. Keeping the *captured breakpoints* is load-bearing: a grid
re-walked from scratch at strictly half the captured step everywhere still
refused at `θ_0` itself.

### 3.5 Where the operating point sits

**(C14) The default operating point is not in the asymptotic regime.** Under
impulsive forcing `J` moves **57%** between tolerance `1e-4` and `1e-6`. Under
sustained forcing `d log(steps)/d log(tol) = −0.167` over `1e-4 … 1e-8`, with
local slopes ranging `−0.064 … −0.345`, against `−0.20` for a clean fifth-order
response.

**(C15) Balance of errors.** The measure's discretisation error is `O(Δξ²)`,
roughly `(1/M)²` relative: ≈`1e-6` at `M = 800`, ≈`4e-4` at `M = 50`. Time is
routinely resolved far finer than `ξ`.

**(C16) Forcing geometry.** `f''` jumps on a known uniform grid whose spacing is
**finer** than the mean accepted step by a factor 1.5–2.6. Aligning to every
knot therefore imposes a floor of one step per knot rather than removing a
penalty.

**(C17) Cost structure.** The member loop is ~86% of an `f` evaluation and is
`O(M)`. The member enters the inner root only through `(ξ_j, u) ∈ ℝ^{1+L}`.

**(C19) Census of step attempts by outcome**, over every attempt of a whole run:

| outcome | sustained | impulsive |
|---|---|---|
| accepted | 530 | 1017 |
| accuracy rejection | 97 | 292 |
| domain rejection (thrown) | 27 | 104 |
| domain rejection (state refused) | **0** | **0** |
| accepted at the floor | **0** | **0** |
| **rejections / attempts** | **19.0%** | **28.0%** |
| **rate evaluations on rejected attempts** | **17.3%** | **26.9%** |

Every throw comes from one site — the per-member inequality constraint of
§1.3(i), inside the member loop, per member per stage. The small block's own
guard never fired. Over a horizon 21× longer the rejection fraction is
comparable (19.3% sustained, 31.3% impulsive), so this is not an artefact of the
short horizon.

**(C18) A non-stiff instance of the same code path shows none of this.** A
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

The current law is memoryless: `h_{n+1}` depends only on `r_max` at step `n`,
through the three-zone rule of §2. The measured setting: `h·|λ|` pinned at the
stability boundary under sustained forcing (C3); a known impulse grid; an
expensive `f` (C17); and an accuracy rejection costing a **full** step's six
rate evaluations (§2), with deadbeat rejecting 19–28% of attempts and spending
17–27% of all rate evaluations on them (C19). (a) Which controller from the digital-filter family (PI,
predictive, H211b, PI42, …) is optimal here, and what determines the answer —
the stability-boundary pinning, the impulse-induced transients, or the cost
asymmetry between a rejection and a too-small step? (b) What limiter and safety-
factor policy follows? (c) How should a controller *with memory* be reset at a
known impulse or an insertion boundary, where the step-size history is not
informative about what comes next? (d) Is there a controller that is provably
better than deadbeat when the binding component changes identity from step to
step, as C4 shows it does?

### 4.4 The response law itself

The law in §2 is not the textbook elementary controller. It has an acceptance
threshold of 1.1 rather than 1; a dead band over `r_max ∈ [0.5, 1.1]` in which
`h` is left unchanged; different exponents for shrink (`1/ord`) and growth
(`1/(ord+1)`); hard clamps of 0.2 and 5; and a floor at which an inaccurate step
is committed rather than rejected. `ord` is 5 for a 5(4) pair whose error
estimate is `O(h⁵)`.

(a) Is `ord = 5` the right exponent for this estimator, or should it be 4? What
is the observable consequence of getting it wrong — is it visible in the
tolerance-response slope (C14)? (b) What does the dead band buy or cost? It
suppresses small oscillations in `h`, but it also prevents the controller from
tracking a slowly-drifting optimum, and with only ~6 steps per leg (C10, §2) it
may be most of the run. (c) Is the shrink/growth exponent asymmetry defensible,
or is it a conservative fudge that a proper filter (4.3) should replace? (d) Is
accepting an inaccurate step at `h_min` ever right, given `h_min = h_init = 1e-6`
— and should the failure instead be reported to the caller?

### 4.5 A frequently restarted integration

The integration is fragmented into 88 legs by the insertion schedule, leg
lengths spanning `1e-5` to `0.5` on a dyadic grid, ~6 accepted steps per leg
(§2). The last step of each leg is clipped to land on the boundary and does not
update the carried step size, so history survives; but the carried size is then
applied across a discrete change in the system, and that is the documented cause
of the small block leaving its bounds.

(a) How should a step-size controller — particularly one with memory (4.3) —
behave across a known discrete change in the system: carry its state, reset it,
or carry it with a declared derating? (b) Is clipping the final step to the leg
boundary and excluding it from the history the right treatment, or should the
controller instead plan the last two steps of a leg to land evenly? (c) With ~6
steps per leg, is per-leg adaptive control worth having at all, or does this
regime argue for a precomputed schedule (4.8) on structural grounds rather than
on the `θ`-smoothness grounds of C12? (d) Does the enormous spread of leg
lengths — five orders of magnitude — change the answer between early and late
legs?

### 4.6 Constraint violation as a control signal

One per-member state is inequality-constrained with an **attracting** boundary
(§1.3), and violations are handled by a validity rejection with its own law:
`h ← max(0.2h, h_min)`, unconditional, independent of how badly the constraint
was violated, and overriding an `accept` verdict from the error estimate. These
rejections are routine rather than exceptional (§2, C13).

(a) Is a fixed 0.2 contraction the right response to a constraint violation, or
should the step be cut by a *predicted* factor from the overshoot — a line
search to the boundary, as in an interior-point method? (b) Is rejection the
right mechanism at all for an attracting boundary that members are *supposed* to
reach and rest on, or should the constraint be reformulated (a projection, a
smooth barrier, a change of variable to an unconstrained coordinate such as
`log z`), and what does each cost in bias and in reverse-mode differentiability?
(c) The guard uses a relative slack `−ε·z_max` because an exact comparison
refuses nearly every attempt at the boundary — is a tolerance-based domain guard
inside an error-controlled integration sound, and how should `ε` relate to
`atol`/`rtol`? (d) What is the correct interaction between a validity rejection
and the error controller's own state — should a validity rejection be allowed to
update the accuracy controller's history at all?

### 4.7 Switching surfaces without event detection

`P(ξ, u)` is `C⁰` across active-set changes with switching surfaces in
`(ξ, u)` (§1.4). The population crosses them continually in time, usually
together rather than member by member (C9). There is no event detection (C10).

(a) What is the actual order reduction for an embedded RK pair stepping across a
`C⁰` kink in the right-hand side, and how does the controller behave there —
does it reject, thrash, or silently accept a low-order step? (b) Given that
reverse-mode AD forbids a data-dependent branch on an active value, is event
location available at all here, and if not what is the best substitute — a
smoothed complementarity form of the active-set condition with a declared width,
or accepting the order loss and pricing it? (c) Does the measured fact that the
population usually crosses *together* (C9) help — for example by making the
crossing detectable from the small block alone, which is only `2L = 10`
components?

### 4.8 Frozen versus adaptive, and the hybrid

Given C11 and C12. (a) Is "shrink by the largest factor by which `|λ|` can rise
across the parameter box" the right safety-factor rule? The measurement is that
`|λ|` rises 1.5× over a 100× change in `κ` and `s = 2` suffices — is the margin
between 1.5 and 2 explicable, and does the rule generalise? (b) What is the
principled trigger for re-capturing the grid inside an optimisation loop, and is
`Σ_n λ_nᵀ e_n` from the reverse pass the right certificate given that the frozen
grid is exactly what makes that reverse pass well-defined? (c) Zero transfer
across forcing realisations (C11) is reported as a limitation; since the forcing
is fixed throughout a calibration, is one grid per forcing realisation simply
correct, or is there a reason to want transfer? (d) Is there a middle design
that keeps adaptivity while removing the `θ`-dependence of the accepted
sequence — freezing only within a finite-difference pair, or a controller whose
accept/reject decision is a smooth function of the state rather than a
threshold?

### 4.9 Failure handling without a controller

C13: one controller-free form propagates a domain violation as a hard failure at
39% of a parameter box; the other subdivides and always completes, but a
subdivision is itself a data-dependent branch — the very thing freezing the grid
was meant to eliminate. What is the right design for a fixed-grid integrator's
failure handling such that it stays `θ`-smooth and still survives a domain
violation? Is a projection, a smoothed barrier, or a reformulation that cannot
violate the domain the correct answer, and what does each cost in bias?

### 4.10 Joint tolerance allocation

Three tolerances interact: the controller's `(atol, rtol)`; the inner root's
(`1e-12`, convergence-tested, C7); and the measure's discretisation, `O(1/M²)`
(C15). Measured: the FD plateau bottoms out at the inner floor, not the grid
(C12). (a) What is the principled joint allocation? (b) Should the inner solve
be a **fixed-iteration-count** Newton — smooth and branch-free, but a slightly
different function than the exact root — and what does that change for the
controller, for the tape, and for `J`? (c) Is there a reason to make the inner
tolerance a function of the current step's accepted error rather than a
constant?

### 4.11 Operating outside the asymptotic regime

C14: at the tolerance the system is normally run at, `J` is not converged, and
the step-count response to tolerance is not the asymptotic power law. Classical
step-size control theory assumes the asymptotic regime. (a) How should a
controller behave outside it? (b) Can it detect that it is outside it cheaply
and online? (c) Is a controller that silently returns a non-converged answer at
the user's requested tolerance a defect to fix in the controller, or strictly a
tolerance-selection problem for the caller?

### 4.12 Alignment when the kink grid is finer than the step

C16: `f''` jumps on a known grid finer than the mean step. (a) What is the right
policy — align anyway and loosen the tolerance to pay for it, coarsen the
forcing reconstruction with a budgeted bias, or reconstruct at higher continuity
so there is nothing to align to? (b) What is the actual order loss from a `C¹`
kink (a jump in `f''`, not in `f`) inside a step of a 5(4) pair, and how much of
C14's departure from the asymptotic power law can it explain? (c) If the
reconstruction is changed, what is the right constraint to impose — monotonicity
of the primitive, positivity of the rate, exact preservation of the integral
over each cell?

### 4.13

Which of C1–C18 is **load-bearing** for each answer and which is incidental?
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
  declared and its effect on `J` is budgeted. In particular the inequality
  constraint of §1.3(i) may be reformulated, and the dependent variable of the
  weight equation may be changed.
- The insertion schedule is the caller's: its times, their number and their
  spacing can all be changed, and the integration's leg structure with them.
- Every quantity the controller could condition on — the small block, the
  member weights, the forcing phase, the distance to a constraint boundary, an
  adjoint from a previous solve — is available at the point of the accept/reject
  decision at no additional evaluation cost.
