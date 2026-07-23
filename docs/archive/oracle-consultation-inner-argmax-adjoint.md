# Reverse-mode gradients of a coupled multiscale IVP whose right-hand side contains a per-unit inner argmax solved to a fixed tolerance: a complete characterisation, seeking the structural read on accuracy × stability × correctness together

A numerical-methods / algorithmic-differentiation problem. No application context is given or
needed; a reader should be able to reconstruct the full mathematics from this document and could not
guess the domain. Self-contained — assume none of the surrounding thread.

We compute the exact gradient of a scalar output of a large coupled simulation with respect to a
handful of parameters, by reverse-mode automatic differentiation (a tape). Our own concern is
narrow — **is the reverse-mode gradient correct** (does it match a finite difference of the solver as
run) — but a long forward-side investigation of the *same* system has shown that its accuracy limit,
its step-controller behaviour, and our gradient discrepancy all appear to trace to **one object in
the right-hand side**: a per-unit inner argmax solved by a fixed-tolerance derivative-free search.
Rather than ask you to grade a candidate fix, we give the most complete, neutral characterisation of
the system and everything we have measured — forward and reverse — and ask you to **re-derive the
structure and tell us where the leverage is for getting accuracy, stability, and correctness at
once**. Reject our framing wherever the numbers warrant; we suspect the interesting move is one we
have not posed.

Refutations of our own prior hypotheses are stated bluntly with numbers, per good practice; please
update on them.

---

## 1. The system

An initial-value problem `y' = f(y, t; θ)`, `y ∈ ℝ^N`, integrated on `[0, T]` by an **adaptive
embedded explicit Runge–Kutta** method (Cash–Karp 4(5)) with a local-error step controller;
`10³–10⁵` accepted steps at a single global step size. The state splits into:

- a **large block** `x ∈ ℝ^M` (`M ≈ 50–800`, growing during the run as **units** are inserted on an
  adaptive schedule), each unit `x_j` a low-dimensional sub-vector carrying an ordered scalar
  coordinate `ξ_j` and a non-negative scalar weight `ρ_j` (the weight profile is skewed and evolves;
  many `ρ_j → 0` and those units are removed);
- a **small block** `u ∈ ℝ^L`, `L = 5`, an ordered chain of coupled scalar accumulators.

Coupling:

```
p_j*      = argmax_p  P(p ; x_j, u, s)          inner scalar solve, per unit j = 1..M
ẋ_j       = g(x_j, u, s, p_j*)
a_ℓ(x,u)  = Σ_j ρ_j · c_ℓ(ξ_j, u, p_j*),   ℓ = 1..L      (channel 1: x→u, weight-weighted quadrature, O(M))
u̇_ℓ       = b_ℓ(t) + T_ℓ(u) − a_ℓ(x, u)                  (small-block balance)
s(x)      = a cheap scalar aggregate of the whole large block   (channel 2: x→x, flat in M)
```

- **Channel 1 (`a`, x→u):** each `c_ℓ(ξ_j, u, p_j*)` is a byproduct of the same per-unit solve that
  yields `ẋ_j`, so obtaining `a` costs the full O(M) solve set; re-evaluating `a` at a new `u` (with
  `x` held) still re-runs the M solves.
- **Channel 2 (`s(x)`, x→x):** all-to-all among units through one cheap scalar; no `u`-dependence.
- **`b_ℓ(t)`:** external forcing into accumulator `ℓ=1` only (piecewise-smooth, with a C²-spline
  representation whose third derivative jumps at daily knots); `T_ℓ(u)` an ordered one-way transfer
  (`ℓ→ℓ+1`) plus a **near-singular self-loss** `∝ u_ℓ^{q}`, `q ≈ 16`, positivity-clamped at a floor
  `u_min`. Timescale separation `~10²–10³` between the fast forced `u` and the slow `x`.
- **The inner control `p_j*` is an argmax** of a scalar objective `P(p)` over a feasible interval
  `[A_j, B_j]`, solved by a **fixed-tolerance derivative-free bracketing search** (golden-section):
  contract the bracket by the golden ratio until its width falls below an absolute tolerance
  `τ = 10⁻³`, return the **midpoint of the final bracket**. It was chosen over Newton/Brent
  deliberately, on the belief that a fixed-tolerance search makes `p_j*` a **smooth** function of its
  inputs (a reverse tape differentiates through it). The exact first derivative `∂P/∂p` **is available
  in closed form** (analytic + one forward-AD pass); it is not used by the solve. The solve first
  selects a feasibility branch (a switch-off exit; a zero-flux exit; a degenerate-interval exit; the
  normal full search); instrumentation shows the full-search branch fires `≥ 99.7%` of the time and
  the degenerate-interval exit **never** fires.
- **A moving interior threshold in the integrand.** `c_ℓ(ξ, u, ·)` is smooth on one side of a
  boundary in `(ξ, u)` and **identically zero** on the other (the unit "switches off"). Measured to
  fire on `< 0.5%` of solves and to be nearly unreachable by construction.

**Output and gradient.** A scalar functional `J = Σ_j w_j · φ(x_j)` (a weighted reduction over the
units at `T`). We need `dJ/dθ`, `θ ∈ ℝ^k` small, by reverse mode: **one adaptive forward solve
records the step schedule; the run is replayed on that frozen schedule with parameters seeded active;
one reverse sweep** returns the whole gradient. Forward-tangent AD equals reverse-adjoint AD in our
setup, so an AD-vs-FD gap is a genuine analytic-derivative discrepancy, not a tape-consistency bug.

**Correctness reference.** Central finite difference of the solver **as run** — perturb `θ` by `±δ`,
re-run on the **same frozen recorded schedule**, central difference, sweep `δ` for the plateau. This
is the ground truth the tape must match. (Note the phrase "as run": the reference differentiates the
code including its finite-tolerance inner search, not an idealised model.)

---

## 2. The object where everything meets: the inner operating point `p_j*`

Three independent lines — a forward step-controller investigation, a forward accuracy audit, and our
reverse-mode gradient check — have each localised to `p_j*` and how it is represented. We give the
geometry first, because it is not uniform, then the three symptoms.

### 2.1 The geometry of `P(p)` is regime-dependent (both regimes measured)

- **Interior-optimum regime.** At many operating points `P(p)` is a **smooth concave maximum**:
  `∂P/∂p ≈ 0` at `p*` (measured `7·10⁻⁴`), `∂²P/∂p² < 0` with finite curvature, and `p*` sits **well
  inside** `[A, B]` (measured `p* = 1.789`, interval `[0.290, 2.670]`).
- **Corner regime.** At other operating points (drier/more-depleted `u`) `P(p)` is **not** a smooth
  maximum: a flat shelf, then a near-vertical wall (a jump of fixed magnitude), then a smooth
  **monotone-decreasing** branch of slope `≈ −8.8`. `p*` is the **corner** at the top of the wall —
  the last point on a surviving branch, sitting a small fixed distance inside `[A, B]`. There
  `∂P/∂p ≈ −8.8 ≠ 0`: **there is no interior stationary point.** The wall is a branch switch (an
  inner sub-solve of `P` loses its root / a feasibility branch engages).

So the same argmax is, depending on state, an **interior stationary optimum** or an
**active-constraint / branch-fold corner**. The feasible-interval endpoints `A, B` move with state
(measured `dA/dstate = −0.933`, `dB/dstate = −0.362`); the corner and the interior optimum both move
**smoothly** with state (the location `p*(state)` is linear to the `τ`-floor), even though `P`-vs-`p`
at fixed state has a corner in the corner regime.

### 2.2 Three ways `p_j*` has been represented on the tape (the correctness fork)

1. **Envelope finite-difference at fixed `p*`.** Differentiate the outputs `c, g` holding `p*` fixed,
   invoking `∂P/∂p* = 0` (stationarity) so that `p*`'s motion "contributes nothing to first order."
   This **drops the term `(∂c/∂p)·(∂p*/∂state)`**. Correct only if the operating point is a true
   stationary interior optimum; in the corner regime `∂P/∂p ≠ 0` and the dropped term is O(1).
2. **Interior-stationarity implicit-function node.** Lift `p*` as an implicit node on `∂P/∂p = 0`:
   value = the search's returned number, derivative `dp*/dstate = −(∂²P/∂p∂state)/(∂²P/∂p²) =
   −P_ps/P_pp`. This is the sensitivity of the **ideal fully-converged stationary optimum**. Correct
   in the interior regime; **ill-defined in the corner regime** (`∂P/∂p = 0` has no root there).
3. **Branch/fold implicit-function node.** Lift `p*` on the branch-switch condition that defines the
   corner (a bordered-fold system), derivative `∂p*/∂state = −g_state/g_p` for that condition.
   Correct in the corner regime; not the right condition in the interior regime.

We currently ship (2). The forward-side investigation had at various points used (1) and flagged its
dropped term as a suspected gradient bug.

### 2.3 The three symptoms of the fixed-tolerance search — one object, all of the trifecta

**(Correctness — our measurement, the interior regime.)** At an interior operating point, we compared
every ingredient of node (2) directly against the true objective `P` and against the solver as run:

| quantity | node / assembled | true (direct on `P`) | ratio |
|---|---|---|---|
| `∂P/∂p` at the returned `p*` | — | `7.4·10⁻⁴` (≈ 0) | — |
| `∂P/∂state` at fixed `p`, at `p*−ε, p*, p*+ε` | 2.40034 / 2.25254 / 2.10849 | 2.40035 / 2.25254 / 2.10848 | **1.0000** |
| `P_ps = ∂²P/∂p∂state` | −5.23153 | −5.23178 | **1.0000** |
| `P_pp = ∂²P/∂p²` | −8.03061 | −8.02462 | **1.0007** |
| a state-transport intermediate's `∂/∂state`, two independent evaluation paths | 0.533935 | 0.533935 | **1.0000** |

Every ingredient of the ideal-optimum node is **exact**. So node (2) computes the **true optimum's**
sensitivity, `dp*/dstate|_IFT = −P_ps/P_pp = 0.652`, confirmed three ways (the node; the closed form;
a **tight** re-run of the inner search, below). **But the finite-difference reference — the solver as
run at `τ=10⁻³` — gives `dp*/dstate = 0.573`, 14% smaller.** The τ-sweep is decisive:

```
  dp*/dstate |_FD, τ=10⁻³ = 0.573     (production)      dp*/dstate |_FD, τ=10⁻⁹ = 0.6517  → 0.652 (the node)
```

Mechanism: the search returns the midpoint of a bracket of width `τ` whose endpoints are `A, B`
contracted by a **fixed** golden-ratio sequence, so `p*` sits at a **fixed fraction** of the feasible
interval, `p* ≈ A + γ(B−A)`, `γ ≈ 0.63`, and its state-derivative is dominated by the **endpoints'
motion**, not the optimum's:

```
  dp*/dstate |_search ≈ dA/dstate + γ(dB/dstate − dA/dstate) = (−0.933) + 0.63((−0.362)−(−0.933)) = −0.573   (matches FD)
```

So node (2) (the ideal optimum, `0.652`) and the FD-of-code-as-run (the loose search's
bracket-tracking surrogate, `0.573`) differ O(1) **even at a smooth interior optimum**, and each is
internally consistent — they are the derivatives of **two different objects**. Downstream this 14%
single-point gap propagates through the coupled reverse sweep to `≈ 0.82×` the reference on the
affected channel (a sign-cancelling pair amplifies it) and compounds over the trajectory.

**(Accuracy — forward, measured earlier on this system.)** The same fixed-tolerance search makes the
functional `J` itself `τ`-dependent and **non-monotone**: on a stress sequence `J(τ=10⁻³)=1.41·10⁻⁷`,
`J(10⁻⁴)=5.90·10⁻⁸`, `J(10⁻⁵)=1.41·10⁻⁷`, `J(10⁻⁶)=5.87·10⁻⁸`, `J(10⁻⁸)=5.87·10⁻⁸` — converging only
for `τ ≤ 10⁻⁶`; the production default is **2.4× wrong**. The mechanism is a survival-threshold
bifurcation: the `O(τ)` corner-location error tips a marginal unit across the switch-off boundary in
the full nonlinear trajectory. On non-bifurcating sequences `J` is `τ`-insensitive.

**(Stability / cost — forward, measured earlier.)** The step controller collapses (`27–35%` of step
attempts rejected; scattered minimum steps `~10⁻⁸·T`; an `h_min` wall three decades past
`J`-convergence). Instrumentation refuted every "event surface" explanation (rejections co-locate
with branch/clamp flips at the `2%` level; the collapse is broadband, in quiet intervals). The
surviving mechanism: the fixed-iteration search injects a **deterministic sub-resolution ripple** of
relative size `~φ⁻ⁿ` into the RHS ingredients `c, g` (the non-stationary outputs feel it at
`O(τ)`; `P` itself hides it at `O(τ²)` where stationarity holds); the embedded error estimator
descends until `h⁵`-truncation meets this floor, then rejects/shrinks against noise it cannot
resolve. Tightening the inner tolerance is predicted to lift the whole collapse.

### 2.4 Refutations (mechanisms we ruled out, with numbers)

- **"The mixed partial `P_ps` is wrong."** Refuted — `r = 1.0000` (2.3). (A prior confident diagnosis
  of ours; killed by measurement.)
- **"The curvature `P_pp` is wrong / it is a nested-FD truncation."** Refuted — `r = 1.0007`;
  value-anchoring the node's inner FD to the exact `∂P/∂p` and sweeping its step both left the result
  unchanged.
- **"The off-tape anchor evaluated at un-perturbed state biases the cross term."** Refuted — `∂P/∂state`
  at fixed `p` is exact at every `p` (`r = 1.0000`).
- **"Two evaluation paths for the state-transport intermediate differ."** Refuted — identical to 6
  figures (`r = 1.0000`).
- **"The operating point is at a feasibility bound."** Refuted **in the interior regime** — `p*` is a
  genuine interior maximum far from both endpoints; but see 2.1: the **corner regime is real** at
  other states.
- **(Forward) "the step collapse is a removable event geography."** Refuted — enrichment lift `≈ 1`;
  the degenerate-interval branch fires 0 times; the switch-off threshold is nearly unreachable.
- **(Forward) "track the control as an ODE state `ṗ = k·∂P/∂p` to remove the argmax class."** Refuted
  — fails non-monotonically in the gain `k ∈ {1,8,64,256}`: an unprojected gradient flow leaves the
  feasible interval during fast `u`-motion.

So across three investigations the residual is not any single wrong term; it is the **fixed-tolerance
inner search** and how its finitely-resolved operating point is (a) fed forward and (b) differentiated.

### 2.5 Two facts that bound the solution space

- **The coupling fixed point is well-conditioned.** The self-consistency map `T: a → u → units → a`
  has, at its fixed point, `‖(I − T′)⁻¹‖ ≈ 5–22` (Arnoldi; spectral radius `≈ 7` but **no eigenvalue
  near +1**). The loop amplifies a perturbation `~5–20×` (this is the source of `J`'s `~10×`
  sensitivity and the `~23%` inter-scheme spread), but there is a **stable limiting answer** and a
  correct per-unit fix is expected to **propagate cleanly** rather than diverge.
- **The accuracy limit is in advancing the large block `x`, not the small block `u`.** Making `u`
  implicit costs *more* (21.7×→52.2× as tolerance tightens — order reduction from a FD-Jacobian taken
  through the search); re-charting `u` is neutral; freezing `x` while sub-cycling `u` exactly is
  already `24%` wrong in `J`. The leverage is on the `x`/operating-point side, which is where `p_j*`
  lives.

---

## 3. Constraints an answer must respect

- **Backward compatibility.** The production forward solve must stay **bit-identical** unless a change
  is explicitly opted into; the default path cannot move. A change that improves the operating point
  (and thus shifts `J` by `O(τ)`) is acceptable only behind a flag.
- The **exact inner first derivative `∂P/∂p`** is available cheaply (closed form + one forward-AD
  pass). A safeguarded root-find on it (interior regime) or on the branch-fold condition (corner
  regime), seeded from the current bracket, would cost a few evaluations versus the search's dozens.
- The correctness contract is literally **"the gradient must match a finite difference of the solver
  as run."** As run, the solver uses the finite-tolerance search — so the contract, read literally,
  points at the surrogate's derivative (`0.573`), not the ideal optimum's (`0.652`). This is the crux
  we cannot resolve from inside.
- The units are embarrassingly parallel per step; the all-`M` solve cost is a floor for every scheme.
  The bracket width is **not** a loosening knob: `c` is non-stationary in `p`, so `p*`-error enters
  `J` at first order × the `10×` amplification.
- A documented, controlled change of the discretisation, the inner solve, or the functional is
  acceptable **iff** the forward solution and the reverse-mode gradient both stay correct under it.

---

## 4. Structural features — any may be load-bearing or incidental; we do not know which

The inner argmax solved by a fixed-tolerance derivative-free bracketing search returning a
bracket-midpoint; the **fixed fraction** `γ ≈ 0.63` at which the returned point sits inside the
feasible interval; the exact-and-cheap `∂P/∂p` the solve does not use; the **regime-dependent geometry**
(smooth interior maximum at some states, active-constraint/branch-fold corner with `∂P/∂p ≠ 0` at
others); the three candidate tape representations of `p*` (envelope-FD-at-fixed-`p*`, dropping
`(∂c/∂p)(∂p*/∂state)`; interior-stationarity IFT; branch-fold IFT) and that the correct one **depends
on the regime**; the feasible-interval endpoints `A, B` that move with state and whose motion the loose
search inherits; the objective evaluator's **clamp** of its argument into `[A, B]` (a perturbation past
an endpoint collapses onto it, degrading a centred difference to one-sided); the value-vs-derivative
asymmetry (`P` errs `O(τ²)` where stationary, `c, g` err `O(τ)`); the deterministic sub-resolution
ripple the search injects into the RHS and its role as the forward step-controller's noise floor; the
`O(τ)` operating-point error that trips a survival-threshold bifurcation in `J` (`2.4×`, non-monotone
in `τ`); the reverse tape recorded over a frozen schedule and its correctness reference being a finite
difference **of the solver as run**; the near-singular self-loss `q ≈ 16` with a clamp that never
engages; the ordered one-way transfer; the C²-spline forcing with jumping third derivative at daily
knots; the skewed evolving weight profile `ρ`; the unit schedule placed to resolve `x(t)` rather than
the coupling quadrature `∫ c·ρ`; the all-`M` solve floor per RHS; the well-conditioned coupling
resolvent (`‖(I−T′)⁻¹‖ ≈ 5–22`) and the `~10×`/`~23%` functional conditioning it induces; the accuracy
limit residing in advancing `x`, not `u`; the backward-compatibility (bit-identity) constraint.

---

## 5. What we are asking

Given the complete structure (§1) and everything measured (§2), with the refutations (§2.4): **re-derive
what is actually going on and where the leverage is. Reject our variables where the numbers warrant —
we suspect we may be looking at the correctness question through the wrong one.**

The genuinely open questions, none of which we can answer from inside our own frame:

1. **What object should a reverse-mode gradient of a computation containing a finitely-solved inner
   operating point actually compute** — the sensitivity of the **ideal** operating point (the `τ→0`
   limit; what our implicit-function node returns), or the sensitivity of the **finite-tolerance
   surrogate actually evaluated** (what a finite difference of the code as run measures)? Our
   correctness contract names the latter, yet the latter is the derivative of a bracket-tracking
   artifact that *vanishes* as the solver is made more accurate. Is "match the FD of the code as run"
   simply the wrong contract for a computation with an inner iterative solve — and if so, what is the
   right correctness reference?

2. **Is there a single reformulation of the inner operating-point solve that discharges all three
   symptoms at once** — the forward step-controller noise floor, the `2.4×` non-monotone `J`
   dependence, and the O(1) reverse-mode gradient gap — since all three trace to the same fixed-
   tolerance search? Or are these genuinely separable, so that (for example) the forward value can
   stay on the cheap search while the gradient is taken with respect to something else?

3. **Can one construction be correct across both geometries** (smooth interior optimum *and*
   active-constraint corner), or are these intrinsically two different implicit objects requiring a
   regime detector? If a detector, what is the robust, differentiable way to decide which condition
   (`∂P/∂p = 0` vs the branch-fold) is active — given that the transition between regimes is itself a
   place the gradient must remain correct?

4. **Is the difficulty intrinsic or representational?** Intrinsic: differentiating a finite-tolerance
   argmax is a genuinely different (and perhaps ill-posed) object from differentiating the ideal
   argmax, and any AD scheme faces this. Representational: it is an artifact of *how* the inner solve
   is done and *how* its result enters the tape, removable by changing one or both. If
   representational, what is the minimal change, and how does the bit-identity constraint (production
   value frozen; gradient improved) shape whether the fix belongs in the value, the derivative, or
   both — and is it ever legitimate to keep the loose value but supply the ideal derivative (value and
   derivative then describing operating points `O(τ)` apart)?

Where a cheap discriminating measurement would localise any of this, name it and we will run it before
building anything — we have a free inner-tolerance knob, an offline attribution pipeline over saved
per-step data, and a per-call gradient probe, and we falsify every proposed mechanism with the
smallest experiment before any refactor.
