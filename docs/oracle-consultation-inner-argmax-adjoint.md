# A reverse-mode gradient through a finite-tolerance inner argmax: the tape differentiates the ideal optimum, the finite-difference reference sees a bracket-tracking surrogate — which is the correct object, and how do we reconcile them?

A numerical-methods / algorithmic-differentiation problem. No application context is given or
needed; a reader should be able to reconstruct the full mathematics and could not guess the
domain. This statement is self-contained — assume none of the surrounding thread.

We are computing the exact gradient of a scalar output of a large simulation with respect to a
handful of parameters, by reverse-mode automatic differentiation (a tape). We have localised an
O(1) disagreement between the tape's gradient and a finite-difference reference to a single
sub-computation — an inner scalar optimisation solved to a fixed tolerance — and we have measured
enough to have refuted every "a term is wrong" explanation. What remains is not a coding bug but a
question about *what object the reverse-mode gradient should even be computing*, and how to make it
agree with the finite-difference correctness reference given a backward-compatibility constraint.
We lay out the system neutrally, bring the data (including the refutations), and ask you to
re-derive what is going on and where the leverage is.

---

## 1. The system

An initial-value problem `y' = f(y, t; θ)`, `y ∈ ℝ^N`, integrated on `[0, T]` by an **adaptive
embedded explicit Runge–Kutta** method with a local-error step controller (`10³–10⁵` accepted
steps). The state splits into:

- a **large block** `x ∈ ℝ^M` (`M ≈ 50–800`, growing as units are inserted on an adaptive
  schedule), each **unit** `x_j` a low-dimensional sub-vector carrying an ordered scalar coordinate
  and a non-negative scalar weight `ρ_j`;
- a **small shared block** `u ∈ ℝ^L`, `L = 5`, an ordered chain of coupled scalar accumulators.

Coupling (the part that matters here):

```
p_j*      = argmax_p  P(p ; x_j, u, s)          inner scalar solve, per unit j = 1..M
ẋ_j       = g(x_j, u, s, p_j*)
a_ℓ(x,u)  = Σ_j ρ_j · c_ℓ(x_j, u, p_j*),   ℓ = 1..L      (the units drive the shared block)
u̇_ℓ       = (external forcing) + (inter-accumulator transfer) − a_ℓ(x, u)
s(x)      = a cheap scalar aggregate of the whole large block
```

The **inner control** `p_j*` is a scalar maximiser of a smooth objective `P(p)` over a feasible
interval `[A_j, B_j]`. Both the unit's own rate `g` and its contribution `c_ℓ` to the shared block
depend on `p_j*`. So `p_j*` is an intermediate quantity that flows into everything downstream.

**How the inner solve is performed (load-bearing detail).** `p_j*` is found by a **fixed-tolerance
derivative-free bracketing search** (golden-section) on `P(p)` over `[A_j, B_j]`: it repeatedly
contracts the bracket by the golden ratio, stops when the bracket width falls below a fixed
absolute tolerance `τ` (default `τ = 10⁻³`), and **returns the midpoint of the final bracket**. The
returned point is therefore within `~τ` of the true argmax, but it is *not* the true argmax — it is
the midpoint of a bracket whose two endpoints are the original interval endpoints `A_j, B_j`
contracted by a **fixed sequence of golden-ratio steps** (the number of contractions is set by
`log((B_j − A_j)/τ)`, effectively constant under small perturbations). The exact first derivative
`∂P/∂p` is available in closed form and cheaply (analytic + one forward-AD pass), but is **not**
currently used for the solve.

**The output and its gradient.** A scalar functional `J = Σ_j w_j · φ(x_j)` (a weighted reduction
over the units at time `T`). We need `dJ/dθ` for a small `θ ∈ ℝ^k` by reverse mode: one adaptive
forward solve **records the step schedule**, then the run is **replayed on that frozen schedule**
with the parameters seeded active, and **one reverse sweep** yields the whole gradient.

**The correctness reference.** A central finite difference of the solver **as run** — perturb `θ`
by `±δ`, re-run on the **same frozen recorded schedule**, central difference, sweep `δ` for the
plateau. On this frozen schedule the finite difference is schedule-artifact-free; it is the ground
truth the tape must match. (Forward-tangent AD equals reverse-adjoint AD in our setup, so an
AD-vs-FD gap is a real analytic-derivative discrepancy, not a tape-consistency bug.)

**How the inner solve is represented on the tape (the object under scrutiny).** The bracketing
search is *not* recorded (it is derivative-free and iterative). Instead `p_j*` is lifted onto the
tape as an **implicit-function node**: its value is the number the off-tape search returned; its
derivative is supplied by the implicit-function theorem applied to the **stationarity condition of
the true optimum**,

```
  ∂P/∂p (p*; state) = 0   ⇒   dp*/dstate = − (∂²P/∂p∂state) / (∂²P/∂p²) = − P_ps / P_pp .
```

`P_pp` is obtained by a finite difference of the (exact) `∂P/∂p`; `P_ps` by reverse-AD through the
objective's assembly. So the node returns, for the derivative, **the sensitivity of the ideal
(fully-converged, exactly-stationary) optimum**, evaluated at the anchor point the search returned.

---

## 2. What we measured

At a representative operating point (one unit, one reverse sweep, mid-simulation), comparing the
node's ingredients directly against the true objective `P` and against the solver as run:

| quantity | node / assembled | true (direct on `P`) | ratio |
|---|---|---|---|
| `∂P/∂p` at the returned `p*` | — | `7.4·10⁻⁴` (≈ 0) | — |
| `∂P/∂state` at fixed `p`, at `p*−ε, p*, p*+ε` | 2.40034 / 2.25254 / 2.10849 | 2.40035 / 2.25254 / 2.10848 | **1.0000** |
| `P_ps = ∂²P/∂p∂state` | −5.23153 | −5.23178 | **1.0000** |
| `P_pp = ∂²P/∂p²` | −8.03061 | −8.02462 | **1.0007** |
| the state-transport intermediate's `∂/∂state`, two independent evaluation paths | 0.533935 | 0.533935 | **1.0000** |

So the objective is a **smooth interior maximum** here: `∂P/∂p ≈ 0` at `p*`, `∂²P/∂p² < 0` with
finite curvature, `p*` sits **well inside** `[A, B]` (`p* = 1.789`, interval `[0.290, 2.670]` —
far from both endpoints). Every second-derivative ingredient the node uses is exact. The node
therefore computes the **true optimum's sensitivity**

```
  dp*/dstate |_IFT = − P_ps / P_pp = 0.652 ,
```

confirmed three independent ways (the node; the closed-form `−P_ps/P_pp`; and a **tight** re-run of
the inner search — see below).

**But the finite-difference reference (solver as run) gives a different number.** Perturb the state
input, re-run the inner bracketing search at the production tolerance `τ = 10⁻³`, central
difference:

```
  dp*/dstate |_FD, τ=10⁻³ = 0.573      (14% smaller than the node's 0.652)
```

**The τ-sweep is decisive.** Re-running the inner search at successively tighter tolerance:

```
  dp*/dstate |_FD, τ=10⁻³  = 0.573      (production)
  dp*/dstate |_FD, τ=10⁻⁹  = 0.6517     → converges to the node's IFT value 0.652
```

So as the inner tolerance tightens, the finite difference of the solver-as-run **converges to the
node's ideal-optimum derivative**. The disagreement is entirely the **finite tolerance of the inner
search**, and its mechanism is explicit: the returned `p*` sits at a **fixed fraction of the
feasible interval**,

```
  p* ≈ A + γ·(B − A),   γ ≈ 0.63 ,
```

so its state-derivative is dominated by the **endpoints' motion**, not the true optimum's motion:

```
  dp*/dstate |_search ≈ dA/dstate + γ·(dB/dstate − dA/dstate)
                      = (−0.933) + 0.63·((−0.362) − (−0.933)) = −0.573    (matches the FD)
```

with the interval endpoints moving at `dA/dstate = −0.933`, `dB/dstate = −0.362` (both measured).
The true optimum moves at `0.652`; the loosely-bracketed surrogate moves at `0.573` because it
rides the bracket. Both numbers are internally consistent and reproducible; **neither is a bug**.
They are the derivatives of **two different objects**: the ideal argmax (what the IFT node
differentiates) versus the finite-tolerance bracket-midpoint (what the code actually computes and
what the finite-difference reference measures).

**Downstream consequence.** This 14% single-point discrepancy propagates through the coupled
reverse sweep: the assembled downstream sensitivity that uses `p*` comes out at **≈ 0.82×** the
finite-difference reference (a near-cancellation of two terms of opposite sign amplifies the
relative error), and it compounds over the trajectory through the shared-block feedback.

---

## 3. Refutations (mechanisms we ruled out, with numbers)

Every "a term is analytically wrong" hypothesis has been **measured and refuted**:

1. **"The mixed second partial `P_ps` is wrong."** Refuted — `P_ps` matches the true objective to
   `r = 1.0000` (table above). (This was a prior confident diagnosis of ours; the measurement
   killed it.)
2. **"The curvature / denominator `P_pp` is wrong."** Refuted — `P_pp` matches to `r = 1.0007`; and
   value-anchoring the node's inner finite difference to the *exact* `∂P/∂p` left the result
   unchanged, and a sweep of the node's own FD step gave the same answer at every step. Not a
   nested-finite-difference truncation.
3. **"The off-tape anchor is evaluated at an un-perturbed state, biasing the cross term."** Refuted
   — the objective's `∂P/∂state` at fixed `p` is exact at every `p` (three points, `r = 1.0000`),
   so the fixed-`p` state response is not biased.
4. **"Two evaluation paths for the state-transport intermediate (a cached fast path vs a general
   path) have different derivatives."** Refuted — identical to 6 significant figures (`r = 1.0000`).
5. **"The operating point is at a feasibility bound / an active-constraint corner (so the interior
   stationarity IFT is the wrong condition)."** Refuted **at this operating point** — `p*` is a
   genuine interior maximum, `∂P/∂p ≈ 7·10⁻⁴ ≈ 0`, `p*` far from both interval endpoints. (See the
   flat feature list §5 — in other regimes of the same system this is *not* true.)

The only surviving explanation is the inner-search **tolerance**, and the τ-sweep confirms it
directly: `FD(τ=10⁻⁹) → 0.652 =` the node.

---

## 4. Constraints an answer must respect

- **Backward compatibility.** The production forward solve must stay **bit-identical** unless a
  change is explicitly opted into (a flag). Any fix that alters the forward trajectory has to be
  gated; the default path cannot move.
- The **exact inner first derivative `∂P/∂p`** is available cheaply (closed form + one forward-AD
  pass). A safeguarded Newton/root-find on it, seeded from the current bracket, would cost a few
  evaluations versus the search's dozens.
- The correctness contract is literally **"the gradient must match a finite difference of the
  solver as run."** This is the crux: the solver *as run* uses the finite-tolerance search, so the
  contract, read literally, points at the surrogate's derivative (0.573), not the ideal optimum's
  (0.652).
- The coupled fixed point of the shared-block feedback is **well-conditioned** (the feedback
  resolvent `‖(I − T′)⁻¹‖ ≈ 5–22`, measured by Arnoldi; the loop amplifies a perturbation ~5–20×
  but there is no eigenvalue near the unit circle). So a correct per-unit fix is expected to
  **propagate cleanly** rather than being swamped.
- The inner solve was deliberately made a *fixed-iteration* search (rather than a root-find) on the
  belief that a fixed-tolerance search makes `p*` a **smooth** function of its inputs, which the
  reverse-mode tape then differentiates faithfully — a belief this measurement complicates.

---

## 5. Structural features — any may be load-bearing or incidental; we do not know which

The inner argmax solved by a fixed-tolerance derivative-free bracketing search returning a
bracket-midpoint; the **fixed fraction** `γ ≈ 0.63` at which the returned point sits inside the
feasible interval; the exact-and-cheap `∂P/∂p` that the solve does not use; the implicit-function
node built on the **interior stationarity** condition `∂P/∂p = 0`; the fact that at this operating
point the objective is a smooth interior maximum (`∂P/∂p ≈ 0`, finite negative curvature) but **at
other operating points of the same system it is an active-constraint corner** (a one-sided
wall/jump meeting a smooth monotone branch, `∂P/∂p ≠ 0` at the "argmax", no interior root — there
the argmax is the last point on a surviving branch and the same search returns the corner bracketed
to `τ`); the feasible-interval endpoints `A, B` that themselves move with state (`dA/dstate = −0.93`,
`dB/dstate = −0.36`) and whose motion the loose search inherits; the objective evaluator **clamps**
its argument into `[A, B]` (a perturbation past an endpoint collapses onto it, degrading a centred
difference to one-sided there); the exactness of every second-derivative ingredient of the ideal-
optimum IFT; the O(1) gap between the ideal-optimum derivative and the finite-tolerance surrogate's
derivative; the τ-monotone convergence of the surrogate to the ideal as `τ → 0`; the ~0.82×
downstream ratio from a sign-cancelling pair; the well-conditioned shared-block feedback resolvent
(`5–22`); the reverse tape recorded over a frozen schedule; the correctness reference being a finite
difference **of the solver as run**; the backward-compatibility (bit-identity) constraint on the
default forward path.

---

## 6. What we are asking

Given the complete structure (§1) and the measured behaviour (§2), with the refutations (§3):
**re-derive what is actually going on, and tell us where the leverage is. Reject our framing where
the numbers warrant.**

Concretely, the questions we cannot answer from inside our own frame:

1. **Which object should the reverse-mode gradient compute** — the sensitivity of the *ideal* inner
   optimum (the IFT limit, `τ → 0`, `0.652`), or the sensitivity of the *finite-tolerance surrogate
   actually evaluated* (`0.573`, what a finite difference of the code as run measures)? Our
   correctness contract ("match FD of the solver as run") reads as the latter, but the latter is
   the derivative of a bracket-tracking artifact that vanishes as the solver is made more accurate.
   Is the right move to **redefine the reference** (differentiate against a tight-tolerance run, and
   regard the tape's IFT value as the correct one), or to **make the tape reproduce the surrogate**?

2. **Is this O(1) disagreement intrinsic or representational?** Intrinsic: differentiating a
   finite-tolerance argmax is genuinely a different (and arguably ill-posed) object from
   differentiating the ideal argmax, and any AD scheme faces the choice. Representational: it is an
   artifact of *how the inner solve is done* (a bracket-fraction midpoint rather than a polished
   root), removable by changing the inner solve. If representational, what is the minimal change and
   its cost?

3. **Given the backward-compatibility constraint**, is the clean resolution to **polish the inner
   solve to a true locator** (a safeguarded Newton on the available exact `∂P/∂p = 0`, seeded from
   the bracket; `p*` then tracks the ideal optimum for *both* value and derivative; the value shift
   is `O(τ)` per solve but the forward trajectory is no longer bit-identical, so it must be
   opt-in), leaving the default path on the loose search and simply **accepting that the default
   path's tape is the derivative of its own surrogate**? Or is there a way to get the correct
   (ideal-optimum) gradient on the tape **without** moving the forward value — i.e. keep the loose
   value but supply the ideal derivative — and is that a legitimate thing to do (value and
   derivative then describe different operating points by `O(τ)`)?

4. **One mechanism for both regimes?** At some operating points the inner problem is a smooth
   interior maximum (this measurement); at others it is an active-constraint corner (`∂P/∂p ≠ 0`, no
   interior root — differentiating stationarity is then meaningless and the correct condition is the
   branch/fold that defines the corner). Is there a **single** locator/derivative construction that
   is correct across both — e.g. a locator on whichever condition is active (interior stationarity
   vs branch/fold), selected by a detector — or are these genuinely two nodes? What is the robust
   way to detect which regime a given solve is in?

Where a cheap discriminating measurement would localise any of this, name it and we will run it
before building anything (we have a free inner-tolerance knob and an offline attribution pipeline;
per our practice we falsify every proposed mechanism with the smallest experiment before any
refactor).
