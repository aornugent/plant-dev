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

The reverse-mode gradient is taken by a record→replay tape over every RK stage; its cost tracks
accepted steps and is `O(1)` in the size of `θ`. The inner argmax is deliberately **not** an AD
citizen (fixed-iteration, for the smoothness the tape needs), so a full forward-mode Jacobian of `f`
cannot be formed; the coupling co-output's state-sensitivity is currently supplied to the tape by an
**envelope-theorem finite difference taken at fixed `p*`** (on the argument that `∂P/∂p = 0` at an
optimum). That argument is exact only for outputs stationary in `p`; the coupling co-output is **not**
stationary in `p`, and the operating point is in any case a corner where `∂P/∂p ≠ 0` (§1), so the
adjoint on that channel drops a first-order term `(∂c/∂p)(∂p*/∂state)`. This is a known open
correctness item, recorded here as a property of the system, not a target of this characterisation.

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

**The forcing sequences (six shapes, horizons `20–70` time units), described only by shape.** Each
drives `b(t)` into reservoir 1 through a fine piecewise-linear node grid (a few hundred nodes per time
unit): (1) a **monotone ramp**
of forcing amplitude, low→high, sweeping through a state boundary (25 units); (2) **intermittent
pulses with slow AR(1) low-frequency amplitude modulation** (70 units, the longest); (3) a **long
(~6-unit) near-zero-forcing interval** embedded mid-horizon, otherwise baseline pulses (30 units);
(4) **sparse high-amplitude pulses on a near-zero baseline** (20 units); (5) **alternating high/low
extremes every unit** (full-range excursions each cycle, 24 units); (6) the **multi-block variant** —
one small block `u` shared by several independent large blocks (higher effective `M`, more
simultaneous threshold crossings, 40 units). Frozen reference measurements:

| sequence shape | horizon | `J_ref` | accepted | reject frac | min h / T |
|---|---|---|---|---|---|
| monotone ramp | 25 | 1.910×10⁻⁵ | 15 035 | 0.308 | 4.0×10⁻⁸ |
| AR(1)-modulated pulses | 70 | 2.341×10⁻³ | 60 926 | 0.272 | 1.4×10⁻⁸ |
| long zero-forcing interval | 30 | 3.242×10⁻⁶ | 14 301 | 0.293 | 3.3×10⁻⁸ |
| sparse high pulses | 20 | 1.281×10⁻⁵ | 9 377 | 0.292 | 5.0×10⁻⁸ |
| alternating extremes | 24 | 2.476×10⁻⁶ | 10 331 | 0.281 | 4.2×10⁻⁸ |
| multi-block | 40 | — | 3 660 | 0.347 | 2.5×10⁻⁸ |

- The reject fraction (`0.27–0.35`) is **uniform across these very different shapes**. The reported
  `min h / T` equals the **initial step `10⁻⁶` divided by the horizon** in every row (`10⁻⁶/70 =
  1.4×10⁻⁸`, `10⁻⁶/20 = 5.0×10⁻⁸`, …) — i.e. the "small step" is the start-up step, not a mid-run
  event, confirming there is no mid-run collapse.
- **The multi-block sequence goes non-finite** (overflow) partway through, at a growing step size
  (`~0.25`-unit steps) — a large-step overshoot, not a small-step stall. It is the one sequence the
  reference integrator does not complete.
- Of the smallest-decile accepted steps, only `2–31 %` fall near a forcing feature; `69–100 %` do not.
  They cluster in low-forcing intervals, and (per §6f) co-locate with **no** loggable discrete surface.

## 5. Where the difficulty actually lives (measured)

- **The step size is accuracy-limited, not stability-limited.** Across a `3000×` sweep of the
  self-loss stiffness, `100 %` of steps run at `h·|λ_local| ≈ 10⁻³` (median `8×10⁻⁴`) — three to
  four decades **below** the explicit stability ceiling (`≈3.3`); `0 %` of steps are
  stability-limited. `corr(log Δt, log d) = −0.91`, where `d` is a distance-to-a-bound scalar.
- **The stiffness that does exist is in the coupling, not the reservoirs.** The reservoir self-loss
  has a large local Jacobian (`≈1400` at one end; closed-form exponents `2n+3 ≈ 16.14` collapsing to
  `0` at the far end, and a near-singular `−n ≈ −6.57` diverging at `u_min`), but softening these does
  **not** move the step-size wall. What does: `|J_full|` near `u_min` (a reservoir near its bound with
  members drawing against it) is **`50–291×` the reservoir-only Jacobian** — the amplifier is the
  **`u`-dependence of the coupling `a`**, which a reservoir-only stiffness analysis misses entirely.
- **The tight-tolerance "wall" is a localised non-smoothness, not stiffness.** At an outer tolerance
  ~3 decades tighter than the one at which `J` is already converged, the controller cannot meet
  tolerance. Softening the near-singular exponents does not clear it; **shrinking the minimum
  explicit step (`10⁻⁶ → 10⁻⁹`) does** (identical eval counts at `10⁻⁹` and `10⁻¹²`). The controller
  wants `h ≈ 10⁻⁹` at **isolated points** — the signature of a `C⁰`/`C¹` non-smoothness passing
  through the state (the inner-argmax corner of §1, member-insertion transients), not global stiffness.
- **Cost.** `95–100 %` of one `f`-evaluation is the `O(M)` member solves; `s(x)` is negligible. Per
  member (consistent units): `u`-dependent setup ≈ 11, one objective evaluation at given `p` ≈ 4.6, a
  full argmax ≈ 21; so evaluating `a` at given controls ≈ 15.6/member and re-optimising adds ≈ 16.
  The **setup is `u`-independent and cacheable once per macro interval** (flat in reservoir count and
  in bracket resolution). Whole-run cost scales `~M^{1.4}` (eval count `~M^{0.4}`, per-eval `O(M)`).
- **`J` is pathologically sensitive.** Two independently converged schemes disagree by **`~23 %` on
  `J`** at `M ≈ 350`; small coupling errors amplify **`~10×`** into `J`; the reverse-mode gradient is
  hypersensitive in proportion. Judge every scheme in `J`-units, not trajectory units.

## 6. The record of approximations tried, and their measured outcomes

Grouped by what each one attacks. Every entry is a mechanism, a measured result with numbers, and the
numerical reason it did or did not survive. The reference is always the global explicit RK at
converged tolerance.

### 6a. Baseline (the reference)
- **Global single-rate adaptive explicit RK.** One global step; touches all `M` members once per
  accepted step. Converged `J` at modest tolerance and cost (`J` bit-stable across a 100× tolerance
  band; the next 3 decades of tolerance cost `~47×` for no `J` change — the "wall"). Cost linear in
  `M` per step. **This is already near-optimal on step count at the accuracy `J` needs.**

### 6b. Exploiting stiffness (implicit / stabilised methods)
- **Global A-stable / implicit stepping, and quasi-steady-state elimination of `u`.** Retired **by
  measurement**: the collapse is accuracy-driven (§5), so there is no stability limit to relax and no
  fast transient to eliminate — an implicit method changes nothing about the step count.
- **Rosenbrock (RODAS4(3), L-stable, forward-AD Jacobian, dense LU).** On a reservoir-only surrogate:
  **`~1.5×` more steps, `~5×` slower** than explicit RK (no stability limit to exploit). On the
  coupled system: dense Jacobian is `O(M²)`, factorisation `O(M³)` → **`~470×` slower** at `M ≈ 205`,
  infeasible at `M ≈ 800`. It also **cannot run on the coupled system at all** without an AD-Jacobian
  rebind the carrier type lacks. (For calibration, the same method wins `~13×` on a genuinely
  stability-limited stiff test — confirming the method is fine and the *problem* is not
  stability-limited.)
- **Exact-flow split of the reservoir self-loss + Rosenbrock on the remainder.** **Slower than the
  plain adaptive inner at every macro step size**: the step count is accuracy-set, so removing the
  stiff self-loss changes nothing and the Rosenbrock Jacobian adds cost (`~1.7×` the full-`M`
  decomposition). Coarsening the macro step hits the macro method's order error: `3 %` `J`-error at
  `H = 5×` the forcing period, `80 %` at `H = 60×`.

### 6c. Multirate / operator-splitting / block decomposition
- **Held-coupling multirate / Lie–Trotter freeze** (sub-cycle `u` with `a` held piecewise-constant,
  refreshed `R` times per unit). Tracks truth only at `R ≈ 50/unit` (`~7×` the fast rate); below
  `R ≈ 20` it is qualitatively wrong. In stiff regimes it **plateaus at a fixed error `≈0.1–0.12`
  regardless of `R`** (naive per-unit freeze: `max|Δu| ≈ 0.26–0.38`). Reason: the true fast Jacobian
  is `∂b/∂u − ∂a/∂u`; freezing `a` **deletes the `∂a/∂u` restoring feedback**, so the sub-system
  relaxes to the wrong balance (or hits the clamp). The error is set by balance displacement, **not**
  refresh rate → no zeroth-order-hold schedule can work.
- **Per-macro linearisation of `a` in `u`** (`a ≈ a₀ + J(u−u₀)`, full `L×L`, `~90 %` diagonal,
  max off-diagonal/diagonal `≈0.09`): **`3–4×` relative error** once any component moves toward its
  bound. **Separable nonlinear tabulation** (`a_ℓ ≈ κ_ℓ(u_ℓ)`, others held): **absolute error
  `0.06–0.76`** on multi-component excursions. Both retired — the coupling's `u`-dependence is
  non-separable and its cross-response is first-order.
- **MRI-GARK multirate skeleton (forward + reverse).** Order-of-accuracy verified on a clean
  surrogate (coupling orders `1/2/2/3`; a 3rd-order coupling `156×` more accurate than Lie split at
  `1.44×` cost; reverse-mode adjoints matched a frozen-schedule finite difference to `2×10⁻⁹`,
  `48/48` cases). But **crossing a forcing feature within a macro step negates the high order** (a
  feature-aligned macro grid is a hard requirement), and — decisively — see the head-to-head below.
- **Full decomposition head-to-head on the real coupled system (the decisive result).** The fast
  sub-cycle needs `n_micro ≈ 10` accuracy-driven micro-steps per macro step, and the coupling `a`
  must be re-evaluated **inside** the fast loop → `~13×` more member solves than global. Measured:
  decomposition is **`6–25×` more expensive** than global at converged accuracy (`0.7–23 %`
  `J`-error). Reason: the surrogate that motivated multirate had a *cheap* large block; the real large
  block is the dominant `O(M)` cost, and multirate **re-pays that dominant cost more often**. Any
  scheme that puts the `O(M)` coupling inside a sub-cycle loses.

### 6d. Reducing the `O(M)` coupling cost directly
- **Member collocation / quadrature** (reconstruct `a` from `m ≪ M` members; the integrand
  `c(·, u)` is smooth). Converges `≈O(m⁻²)`; on a *prescribed, quadrature-friendly* member set
  `m ≈ 15–20` gives `<0.5 %` aggregate error (nominal `5–40×` cut). **Refuted on the evolved member
  set**: members are placed to resolve `x(t)`, not the coupling integrand, so at `M ≈ 350`, `m = 20`
  is `14 %` `J`-error at `≈` global cost, and `m = 40` is `2.4 %` `J`-error at `2×` global cost. The
  crossover only appears when the required `m` is a large fraction of `M`.
- **Warm-started inner solve / parameter continuation** (make the exact `a`-refresh cheap by warm
  Newton on `∂P/∂p`). The inner solve is deliberately fixed-iteration and derivative-free (so `p*` is
  a smooth fixed-iteration function of its inputs, for the tape) → **not warm-startable by design**;
  and warm Newton is **fragile** — over a realistic reservoir excursion it diverges toward the bound
  and leaves the objective's domain (`|p*_cold − p_warm| ≈ 0.6–0.9`, the control's own range). The
  economics are modest anyway: re-optimising vs evaluating at a given control is only `~4.5×`, since
  the `u`-independent setup is paid on every reservoir change.

### 6e. Removing the inner argmax (promote the control to state)
- **Tracked control** (replace each `p_j* = argmax` by a relaxed differential state
  `ṗ_j = k·∂P/∂p`). On a clean surrogate this matched the re-optimising reference to 4 decimals and
  tracked to `<10⁻³` even at low gain (`k = 5`; knee at `k ≈ 20`); the co-integrated
  `L + m`-dimensional fast subsystem was reverse-mode certified (adjoint = finite difference to
  `10⁻⁸` across `m ∈ {4…64}`, `k ∈ {1…1000}`). **But on the real system it fails at every gain
  tried (`k ∈ {1, 8, 64, 256}`) and the failure is non-monotonic in `k`:** the tracked control
  leaves the feasible domain during fast reservoir motion and the inner bracketing gets a
  non-bracketing interval. Reason (tied to §1's corner): the objective has **no interior stationary
  point** (`∂P/∂p ≈ −8.8 ≠ 0` at the operating point), so a gradient flow `ṗ = k·∂P/∂p` has **no
  fixed point** — it marches off the branch edge. It completes only at `k → 0` (no tracking) or with
  the exact argmax. This is a structural failure, not a tuning one.

### 6f. Locating and exploiting discrete structure
- **Event / step-to-event location.** An instrument logged, per accepted step, every candidate event
  margin (reservoir-bound clamps, the self-loss ceiling, the switch-off threshold, the argmax
  feasible-interval width) plus an integer branch signature from inside each member solve — all
  bit-identical to the un-instrumented run. Result across many sequences: the step collapse
  **does not co-locate with any event** (rejections within `±1` step of any branch/clamp flip:
  **median `2 %`**); the event surfaces **barely fire** (`≥99.7 %` of member solves take the smooth
  full-search branch; the degenerate-bracket surface fires **0 times**; clamps/forcing-excess fire
  never); the enrichment ratio `P(event-adjacent | hard) / P(event-adjacent | easy) ≈ 0.8–1.0` (no
  enrichment). **The collapse is broadband**, not a locatable set of discrete crossings.
- **Forcing-feature step clipping** (clip each trial step to the known forcing feature times so a step
  lands on a feature instead of discovering it by rejection). Bit-identical off; cost-neutral; a small
  reject reduction — but only `~2 %` of accepted steps land on forcing features, so the forcing kinks
  are a minor driver.

### 6g. Sharpening the inner solve (tolerance) and the step controller
- **Inner-tolerance sweep.** The fixed-tolerance argmax carries a resolution floor `ε_p ~ τ`; the
  argmax and the non-stationary coupling outputs inherit an `O(ε_p)` floor (measured log-log slopes
  `1.10` and `1.01` vs `τ`), and the objective value inherits `O(ε_p)` too (slope `1.06`, **not**
  `O(ε_p²)`, because the operating point is a corner, §1). **But tightening `τ` by `1000×` leaves the
  rejection fraction unchanged** (`0.20–0.31`, invariant) across every sequence, and the minimum step
  is the initial step regardless. So the inner floor is real at the source but **is not what sets the
  step size**. Its one measured consequence is on `J`: on one sequence `J` is non-monotone in `τ`
  (`2.4×` swing, converging only at `τ ≤ 10⁻⁶`) — a survival-threshold flip (§4).
- **Predictive (PI / Gustafsson) step controller** instead of the dead-band elementary controller.
  It **lowers the rejection fraction** (`0.28 → 0.24`, `0.28 → 0.19`) **but raises total work
  `13–29 %`** (more, smaller accepted steps), `J` unchanged. The elementary controller's dead-band
  "hot striding" (large steps, tolerate error to `1.1×` tolerance, `~30 %` overshoot-and-reject) does
  **less total `O(M)` work** than the PI controller's "cool" stepping. The rejections are the price of
  striding at the accuracy limit on a problem whose local error is unpredictable step-to-step; there
  is nothing for a predictor to predict.

### 6h. Implicit treatment of the small block alone (IMEX)
- **Linearly-implicit Rosenbrock (RODAS4) on `u` only**, Jacobian restricted to the `L×L` block and
  finite-differenced *through the full RHS* (hence through the member solves and the inner argmax),
  explicit on `x`. Accurate (`J`-error `3.6×10⁻²` at outer tol `10⁻⁴`, `1.7×10⁻³` at `10⁻⁵`) but
  **`20–50×` slower** than global explicit RK, and the deficit **grows with tighter tolerance**
  (`21.7× → 52.2×` from tol `10⁻⁴ → 10⁻⁵`). The growth is **order reduction**: an effective order `~2`
  vs the explicit `~5` predicts a per-decade step-ratio growth of `~2` (measured `52.2/21.7 = 2.4`),
  caused by feeding the implicit solver a Jacobian finite-differenced **through the fixed-iteration
  bracketing search**, whose output is smooth only to the bracket width (Jacobian noise `~δ/ε`). This
  retires implicit-`u` and, more generally, **any route that finite-differences a Jacobian through the
  member solves.**

### 6i. State reformulations / changes of variable
- **Log-depletion re-chart of the reservoirs** (`u ← ln(u − u_min)`, removing the near-singular
  self-loss from the coordinate). **`J` unchanged — neutral.** It removes the singularity from the
  chart but does not move the accuracy limit (consistent with §5: the self-loss singularity is not the
  step-limiter). Reverted.
- **Exact closed-form flow of the singular self-loss** (`u̇ = −c·u^{q}`, `q ≈ 16.14`, closed-form
  recession `u(t) = [u_0^{1−q} + (q−1)c·t]^{−1/(q−1)}`). Verified to match a tight RK of the isolated
  self-loss to `~10⁻¹³`, positivity-preserving by construction (removes the clamp, gives an analytic
  touch-down root). Its effect on the *coupled* solution is the exact-flow split already reported in
  §6b (slower than the plain adaptive inner, because the step count is accuracy-set, not self-loss-set).
- **Cheap parametric surrogates of the coupling `a(u)`** (to avoid re-running the `O(M)` solves when
  only `u` moves). A **per-macro linear surrogate** `a ≈ a₀ + J(u−u₀)` (full `L×L`, diagonal `~0.93`,
  max off-diagonal `≤0.088`): relative error `1 %` for a uniform small excursion, **`15 %`, `370 %`,
  `440 %`** as any one component moves toward its bound. A **separable nonlinear surrogate**
  `a_ℓ ≈ κ_ℓ(u_ℓ)` (others held, ~8 samples/reservoir): error `7 %` uniform, **`61 %`, `69 %`** on
  multi-component excursions (absolute `0.033–0.76`). Both fail for the same reason: moving one
  reservoir changes the others' coupling — the `u`-dependence is **non-separable with first-order
  cross-response**.
- **Reformulations checked and rejected on structural grounds** (the structure the method needs is
  absent): an additive-forcing change of variable `w = u − ∫b` (the forcing enters **multiplicatively**,
  not additively); a Sundman-style time reparametrisation to absorb the singular self-loss (pre-empted
  by the exact-flow recession); a dissipative / gradient-flow reformulation `u̇ = −∇Φ` (fails — `a` is a
  directed flux and the inter-reservoir transfer is directed transport, neither is a gradient);
  stabilised explicit families (RKC/ROCK, many cheap stages) — rejected because **each stage costs the
  full `O(M)` coupling**, so cheap stages are not cheap here.

### 6j. What no reformulation has removed
- The `~24 %` `J`-error of freezing the large block `x` across a macro step **at full coupling, before
  any approximation** — the single cleanest datum: the accuracy limit is in advancing `x`, and it is
  zeroth-order in `x`-motion, so no defect-correction on the *coupling* can touch it.
- The `~10×` amplification of coupling error into `J` (measured directly: a member-reduction giving
  `0.8 %` coupling error yields `~9 %` `J`-error), and the `~23 %` spread between independently
  converged schemes at large `M`. `J` is, in the words used at the time, "barely an observable."

## 7. Structural features (a flat inventory; any may be load-bearing or incidental)

The two coupling channels (`a`: x→u, `O(M)`, non-separably `u`-dependent, the dominant cost; `s(x)`:
x→x, cheap, `u`-independent); the inner argmax `p*` whose objective is an **active-constraint corner**
(a fixed-magnitude jump/branch-switch meeting a smooth `O(1)`-slope branch; `∂P/∂p ≠ 0` at the
operating point; no interior stationary point) whose *location* is nonetheless smooth in state; the
exact closed-form `∂P/∂p` (available; not used by the current gradient seam); the fixed-iteration
derivative-free bracketing that returns a bracket midpoint to width `τ`; the objective evaluator's
clamp of its argument into the feasible interval (a one-sided-difference hazard at the boundary); the
feasibility branches (switch-off / zero-flux / degenerate-bracket / full-search) of which only the
full search is materially exercised; the switch-off threshold keyed on the **least-extreme** accessible
reservoir (nearly unreachable — a benign terminal reservoir keeps members on); the near-singular
reservoir self-loss (`q ≈ 16`) with a positivity clamp (never engaged); the ordered one-way
inter-reservoir transfer (no back-transfer); the external forcing entering only reservoir 1,
piecewise-smooth with known feature times; the `~10²–10³` timescale separation between fast forced `u`
and slow `x`; the single global step size shared by both blocks; the growing member count
(`M ≈ 50→800`) inserted to resolve `x(t)` (not the coupling integrand); the highly skewed, evolving
weight profile `ρ` (mass in a few members, many `ρ_j → 0`); the all-`M` cost floor paid by every
scheme every RHS evaluation; the `~10×` amplification of coupling error into `J` and the `~23 %`
inter-scheme spread; the survival-threshold discontinuity of `J`; the reverse-mode tape over every RK
stage whose cost tracks accepted steps; the `~27–35 %` rejection fraction that co-locates with nothing
loggable and is invariant to inner tolerance and to controller choice; the accuracy-limited (not
stability-limited) step size sitting 3–4 decades below the explicit stability ceiling.

## 8. Facts an answer can rely on

- `95–100 %` of one RHS evaluation is the `O(M)` member solves; `ẋ_j` and the coupling `a` both
  require all `M`, however `u` is advanced. No forward-mode Jacobian of `f` exists on the carrier; the
  inner `∂P/∂p` is exact and cheap.
- The step size is accuracy-limited, not stability-limited (3–4 decades below the stability ceiling);
  softening the reservoir stiffness does not change the step count.
- The rejection fraction (`~30 %`) is invariant to a `1000×` inner-tolerance change and rises in
  total work under a predictive controller; the minimum step is the initial step (no mid-run collapse).
- The coupling `a` is non-separably `u`-dependent (linearisation `3–4×` off, tabulation `0.06–0.76`
  off, held-`a` plateaus at `~0.1`); putting `a` inside any sub-cycle costs `6–25×` global.
- Member reduction is accurate on a quadrature-friendly set (`<0.5 %` at `m ≈ 15–20`) but not on the
  evolved set (`14 %` at `m = 20`, `M ≈ 350`).
- `J` amplifies coupling error `~10×`; schemes must be judged in `J`-units; the reverse gradient must
  match a finite difference that **re-solves the inner problem** (freezing the argmax hides the error
  in both).
- The forward solution and the reverse gradient must both stay correct under any change; the reference
  integrator already reaches converged `J` at modest cost.
