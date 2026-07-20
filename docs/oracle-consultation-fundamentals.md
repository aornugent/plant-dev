# A coupled initial-value problem that resists approximation — a complete numerical characterisation

This is a self-contained description of one numerical system and everything we have measured about
its resistance to approximation. There is no prior context to recover and none is needed. No
application domain is given; a reader can reconstruct the full mathematical model, its
discretisation, and its measured behaviour from what follows, and could not guess the field it comes
from. Nothing here is a question and nothing proposes a remedy — it is a characterisation. Precision
and completeness are the point; where a fact has a number, the number is given.

Notation is fixed once and used throughout: `x` (a large block of `M` members), `u` (a small block
of `L` reservoirs), `p*` (an inner argmax), `a` and `s` (two coupling channels), `J` (a scalar
functional obtained by reverse-mode differentiation of the whole solve), `θ` (a small parameter
vector), `τ` (an inner-solve tolerance). The forward solve, the reverse gradient, and the many
approximations we have tried are all described against this notation.

---

## 1. The system

An initial-value problem `y' = f(y, t; θ)`, `y ∈ ℝ^N`, integrated on `[0, T]`. The state partitions
into two blocks with very different sizes and roles.

**The large block `x ∈ ℝ^M`.** `M` is not fixed: it starts small and **grows during the run**
(`M ≈ 50 … 800`) as new members are inserted on an adaptive schedule chosen to resolve `x(t)`. Each
member `x_j` is an independent low-dimensional sub-vector carrying an **ordered scalar coordinate
`ξ_j`** and a **non-negative scalar weight `ρ_j`**. The weight profile `ρ` is **highly skewed and
evolves**: most of the total weight concentrates in a few members while many members have `ρ_j → 0`
(and are eventually removed).

**The small block `u ∈ ℝ^L`, `L = 5`.** An **ordered chain of scalar reservoirs**. Reservoir `ℓ`
transfers one-way to reservoir `ℓ+1` only (no back-transfer, no cross-reservoir equilibration), and
each reservoir has a **near-singular self-loss** `loss_ℓ ∝ u_ℓ^{q}` with exponent **`q ≈ 16`**,
positivity-clamped at a floor `u_min`. An external forcing `b(t)` enters **only reservoir 1**; it is
piecewise-smooth with known feature times (a `C²` spline through those features, with `C⁰` kinks
available as an option).

**The coupling.**
```
p_j*      = argmax_p  P(p ; x_j, u, s(x))          (inner solve, one per member, every RHS eval)
ẋ_j       = g(x_j, u, s(x), p_j*)                                          j = 1 … M
a_ℓ(x,u)  = Σ_j ρ_j · c_ℓ(ξ_j, u, p_j*),   ℓ = 1 … L        channel 1 (x → u), O(M), expensive
u̇_ℓ       = b_ℓ(t) + T_ℓ(u) − a_ℓ(x, u)                                    reservoir balance
s(x)      = cheap scalar aggregate of the whole large block   channel 2 (x → x), flat in M
```

- **Channel 1, `a` (x → u).** A weight-weighted quadrature `∫ c(ξ, u, p(ξ)) ρ(ξ) dξ`. Each
  `c_ℓ(ξ_j, u, p_j*)` is a **byproduct of the same per-member inner solve** that yields `ẋ_j`, so a
  single evaluation of `a` costs the **full `O(M)` set of member solves**, and re-evaluating `a` at a
  new `u` (with `x` held) still re-runs all `M` solves. This is the dominant cost of `f`.
- **Channel 2, `s(x)` (x → x).** An all-to-all coupling among members through one cheap scalar; it
  carries **no `u`-dependence** and its cost is flat in `M`.
- **Timescale separation.** `u` is fast and forced; `x` is slow. The separation is `~10² … 10³`.

**The inner argmax `p_j*` — and its true local geometry.** `P(p ; ·)` is maximised over a feasible
interval `[a_j, b_j]` by a **fixed-tolerance derivative-free golden-section bracketing search** with
bracket-width stop `τ` (default `τ = 10⁻³`), returning the **midpoint of the final bracket** (width
`≤ τ`). The exact derivative `∂P/∂p` is available in closed form (implicit-function theorem +
forward-mode AD of the analytic objective). **The operating point is not an interior maximum.**
Traced finely at fixed state, `P(p)` is a flat shelf, then a **jump of fixed magnitude** at `p*`,
then a **smooth monotone decline** of finite slope (`∂P/∂p ≈ −8.8`, i.e. `O(1) ≠ 0`, at `p*`). `p*`
is the **corner** at the top of that jump — the last point on a surviving branch — sitting a small
fixed distance (`~1 %` of the feasible width) inside `[a_j, b_j]`. The jump is a **branch switch in a
nested inner root-find**: on one side of `p*` a sub-quantity's root ceases to exist and the solve
returns a fixed **fallback value** (a lower shelf); on the other side the productive branch is live.
So the object is an **active-constraint locus**, not a stationary point. Two further measured facts
about it: (i) the argmax *location* `p*(state)` is nonetheless **smooth in the state** (traced
against a state input it is linear to the `τ`-floor, slope `≈ −1.0004`, residual `≈ τ`); (ii) the
member solve first selects among a few feasibility branches (a switch-off exit, a zero-flux exit, a
degenerate-bracket exit, and the full search) — in practice **≥ 99.7 % of solves take the full
search**, the switch-off exits fire on **< 0.5 %**, and the **degenerate-bracket branch never fires
(0 occurrences)** across every sequence measured.

**A second nonlinearity, the switch-off threshold.** `c_ℓ(ξ, u, ·)` is smooth on one side of a
boundary in `(ξ, u)` and **identically zero** on the other (a member "switches off" and contributes
nothing to `a`). The switch-off test is a **reduction over the reservoir components a member can
access**: a member switches off only when a scalar `w(u) := max_ℓ (−m_ℓ(u_ℓ))` (the *least-extreme*
accessible reservoir, mapped through a monotone `m_ℓ`) crosses a fixed constant `w_crit` — i.e. only
when **every** accessible reservoir is past the boundary; one benign reservoir keeps the member on.
This surface is **nearly unreachable by construction** (see §5).

**The downstream functional and its gradient.** A scalar functional `J = Σ_j tw_j · φ(x_j)` (a
weight-weighted reduction over the members). Its gradient `dJ/dθ` w.r.t. a small parameter vector `θ`
is taken by **reverse-mode automatic differentiation over a tape of every Runge–Kutta stage of the
whole solve**, and is required to match a finite difference of the solver **as actually run**.

---

## 2. The discretisation and controller

- **Method.** A single adaptive embedded explicit Runge–Kutta pair, **Cash–Karp 4(5)**, with a
  local-error controller and a **single global step size** shared by both blocks. A run takes
  `10³ … 10⁵` accepted steps. There is no dense output.
- **Error norm.** Componentwise scaled error `r_i = |e_i| / (atol + rtol·(a_y|y_i| + a_dydt|h y'_i|))`,
  reduced by max over `i` to `rmax`. Standard relative-plus-absolute weighting.
- **Step controller.** An elementary (integral) controller with a **dead-band**: accept and hold the
  step while `0.5 ≤ rmax ≤ 1.1`; grow by up to `5×` when `rmax < 0.5`; reject and shrink when
  `rmax > 1.1`. A rejected step is undone and retried smaller (each retry re-runs the full `O(M)`
  member set).
- **Tolerances.** The outer tolerance at which `J` is converged is modest (see §3/§5). The inner
  argmax tolerance is `τ` (default `10⁻³`).

---

## 3. The correctness reference

"Truth" for the forward solution is the same integrator at a **tight tolerance** (self-convergence);
"truth" for the gradient is a **finite difference of the solver as run** (the operator whose gradient
we want is the discrete solve, not the continuous model). A subtlety that has bitten us: a finite
difference that **freezes the inner argmax** agrees with an adjoint that also freezes it while both
omit the same term — a faithful reference must **re-solve the inner problem at each perturbed state**.
Approximate schemes are judged in **`J`-units**, because (see §5) `J` amplifies coupling error about
tenfold; a scheme that is neutral on the trajectory can still move `J`.

---

## 4. What the system does under the reference integrator (measured)

- Converged `J` is reached at **modest tolerance and cost**; the method does not fail on accuracy.
- **`27–35 %` of step *attempts* are rejected** (rejection-bisection overhead), uniformly across
  very different forcing sequences.
- The rejected attempts are **systematically larger than the accepted steps** (median rejected/accepted
  step-size ratio **2.4–4.0×** across sequences): the controller proposes a step, it fails the error
  test, it shrinks and accepts.
- There is **no catastrophic mid-run step collapse**: the smallest steps occur at `t = 0` (the initial
  step); away from start-up the accepted-step distribution is healthy (`1`st-percentile `~10⁻³·T`,
  median `~10⁻⁵·T`), and a hard floor on the step is essentially never touched.
- `J` is **`~10×` hypersensitive** to coupling error, and shows a **`~23 %` spread between
  independently converged schemes at large `M`**.
- `J` can be a **step function of its inputs near certain thresholds**: on one forcing sequence,
  `J` flips between two values (`≈1.41×10⁻⁷` and `≈5.87×10⁻⁸`, a `2.4×` jump) **non-monotonically**
  as `τ` is varied, converging only once `τ ≤ 10⁻⁶`. The flip is one member crossing a
  survival/removal threshold in the full nonlinear trajectory (§1's switch-off / weight-collapse).

<!-- EXPERIMENT LEDGER (§5) and STRUCTURAL INVENTORY (§6) assembled next turn from the
     accumulated experiment record. -->
