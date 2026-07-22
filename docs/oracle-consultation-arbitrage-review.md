# Review consult: we built the fast-coupling arbitrage — reduced along a different axis than you recommended, and it works. Critique the whole thing.

A numerical-methods consult. No application context is needed or given. This **follows four
prior rounds** on the same initial-value problem (two problem-characterisation rounds, a
cost-structure round, and a reduced-coupling round whose strategy we then partly diverged
from). All settled facts are restated inline so this **stands alone** — assume none of the
prior thread.

**This round is not a question with a candidate answer to grade.** We have built the scheme,
run it on the real system across a scenario bank, and want your independent judgement on the
*whole design*: what is load-bearing, what is fragile, what we have not tested, and whether
there is a better frame we cannot see. We reduced cost along a **different axis** than the
last round recommended, and it works — so the most useful thing you can do is tell us where
that choice will hurt us, or reject it. **You are explicitly licensed to reject our framing.**

---

## 0. The problem (settled from prior rounds; do not re-litigate)

Initial-value problem `y' = f(y,t;θ)`, `y ∈ ℝ^N`, on `[0,T]` with `T` spanning `10³–10⁴`
natural forcing periods, integrated by an **adaptive embedded explicit Runge–Kutta** with a
local-error step controller. `y` splits into two two-way-coupled blocks:

- a **large block `x ∈ ℝ^M`** (`M ≈ 50–800`, and *growing over `[0,T]`* — see below), a set of
  `M` "members" each carrying an ordered scalar coordinate `ξ_j`, a nonnegative weight `ρ_j`,
  and internal state;
- a **small block `u ∈ ℝ^L`, `L = 5`** (plus 4 pure-quadrature accumulators `ẏ = flux`, no
  feedback — taped but trivial). `u` is a vector of coupled scalar reservoirs.

Downstream we take a **reverse-mode gradient** of a scalar functional `J` w.r.t. a small
parameter vector `θ`; the gradient must match a finite difference of the solver *as run*.

**Member cost model** (consistent units, measured): each member `j` carries a scalar **control
`p_j`** set by an inner **argmax** `p_j* = argmax_p P(p; x_j, u, s(x))` (derivative-free
bracketing search). Per member: `u`-dependent setup ≈ **11**; one objective eval (setup done)
≈ **4.6**; full argmax ≈ **21**. `∂P/∂p` is available **exactly** by the implicit-function
theorem at the optimum.

**The rates and the coupling.**
```
p_j*    = argmax_p P(p; x_j, u, s(x))                          (inner search, per member)
ẋ_j     = g(x_j, u, s(x), p_j*)                                (large-block rate, per member)
a_ℓ(x,u)= Σ_{j=1}^{M} ρ_j · c_ℓ(ξ_j, u, p_j*),   ℓ = 1..L      (THE COUPLING)
u̇_ℓ     = b_ℓ(u,t) + [Tu]_ℓ − κ_ℓ(u_ℓ) − a_ℓ(x,u)             (small-block rate)
```
- `a(x,u)` — the coupling — is a **density-weighted quadrature** `∫ c(ξ,u,p(ξ)) ρ(ξ) dξ` over
  the member coordinate. It is an **O(M) byproduct of the member solves**: no separate cheap
  route exists. `a` is **nonlinearly, non-separably `u`-dependent**.
- `b(u,t)` is a **kinked, piecewise-smooth** forcing (a `max(0, 1 − α(u_1/σ)^β)` gate on an
  externally prescribed drive; the kink grid is known a priori).
- `[Tu]` is a one-directional inter-component cascade within `u` (component `ℓ−1 → ℓ`).
- `κ_ℓ(u_ℓ) = c_ℓ u_ℓ^{q}` is a **near-singular self-loss**, `q = 2n+3 ≈ 16`, with a
  **closed-form, positivity-preserving exact recession** `u(Δt) = [u^{1−q}+(q−1)c Δt]^{−1/(q−1)}`,
  floored at a lower bound `u_min`. `κ′` is enormous at the high-`u` end.

**Settled diagnoses (measured in prior rounds):**
- The single-rate step-controller collapse is **accuracy-driven, not stability-driven**,
  localised to `u`-excursions near `u_min` (where a cheap closed-form part of `u̇` is
  near-singular, non-Lipschitz → the clamp) and to the kinks of `b`.
- **QSS reduction of `u`, A-stable/implicit stepping, and frozen (zeroth-order, held) coupling
  are all refuted as step-enlargers** (measured). The refutation of frozen coupling was stated
  as: *the true fast Jacobian `∂u̇/∂u` includes the coupling's `u`-dependence `−∂a/∂u`, so the
  coupling's `u`-dependence must live inside the fast dynamics.*
- The members are **not free sample points**: `{ξ_j, ρ_j}` are part of `y`, advanced by the
  dynamics and by an **adaptive insertion/refinement schedule that places members to resolve
  `x(t)` — not the coupling integrand `c·ρ`.** The evolved weight profile `ρ(ξ)` is **highly
  skewed** (mass in a few members). `M` grows along `[0,T]`.
- `c` and `p*` are **smooth in `ξ`** (verified on prescribed member sets).
- **The functional `J` is hypersensitive to coupling accuracy** — a ~10× amplification of
  coupling/`u` error into `J` was measured on a mature member set (0.8% in `a` → ~9% in `J`).
  `J` is a time-integral of a member-weighted rate.

**Prior round's endorsement (what you told us last time).** You ranked two levers:
- **Lever 1 (exact-flow split), promoted to primary:** integrate `κ` by its exact recession;
  step the gentle remainder `b + Tu − a`. Exact, no accuracy knob, and it shrinks the
  reverse-mode tape by the same factor as the forward cost. You said: *measure it composed
  before investing in Lever 2; arrange it Strang-style (half-recession ∘ remainder ∘
  half-recession) so the split is 2nd order, and verify the order in J-units because the
  commutator involves `κ′`.*
- **Lever 2 (member-count reduction):** reduce the O(M) coupling to O(m). You corrected our
  botched estimator: **separate measure from integrand** — integrate the skewed `ρ` *exactly*
  over all M (O(M) *arithmetic*, zero member *solves*, via frozen-measure moments
  `G_r = Σ_j ρ_j φ_r(ξ_j)`), reduce only the smooth `c(ξ,·)`; peel the heavy atoms, quadrature
  the tail, **anchor with a per-leg full-M defect `Δ`** and optionally a first-order defect
  `Δ₁ = ∂_u(a_full − a_red)` (you noted this is *not* the refuted linearization — it linearizes
  the *defect* of an exact-in-u model). You flagged Lever 2 as bias-risky, amplified 10× by `J`.
- You also mandated: **re-validate everything in J-units and dJ/dθ via Richardson-in-the-knobs**,
  not adjoint-vs-FD (which certifies consistency with the scheme as run, not reduction bias).

---

## 1. What we built (neutral description)

We kept the **multirate skeleton**: a macro grid (leg size `H`, capped near one natural forcing
period, ≈ 1/50 of the controller's would-be step); per leg we **freeze the whole large block `x`**
(coordinates, weights, controls), **sub-cycle `u`** with a fixed number of micro-steps, then
**advance `x` once across the leg**. We built Lever 1. We did **not** build Lever 2. Instead we
reduced along a third axis you named only in passing (the `Δ₁` idea), and took it further:

### 1a. The coupling as an affine-in-`u` model with its exact Jacobian (the core move)
Per leg, at the leg-start state `u₀`, we capture **once** (O(M), one coupling evaluation plus its
Jacobian as a member-loop byproduct):
```
a₀ = a(x, u₀)              (O(M) quadrature)
G  = ∂a/∂u |_{u₀}          (L×L = 5×5 Jacobian, O(M) byproduct of the same member loop)
```
and within the leg the fast RHS reads the coupling from the **affine model**
```
â(u) = a₀ + G·(u − u₀)          (O(L²) = O(25) per micro-step; NO member solves)
```
So the O(M) coupling cost is paid **once per leg**, not per micro-step. Crucially, the fast
Jacobian `∂u̇/∂u` carries `−G = −∂a/∂u` **exactly at the anchor** (constant across the leg) — i.e.
the coupling's `u`-dependence *does* live inside the fast dynamics, to first order. The model is
exact in value and first derivative at `u₀`, and wrong only at **second order in `(u−u₀)`** within
the leg.

### 1b. A probe-free 2nd-order trust monitor that re-anchors on drift
We re-capture `(a₀, G)` (paying O(M) again, a "re-expansion") mid-leg when a monitor trips:
```
trigger when   e² > tol,     e = ‖â(u) − a₀‖_∞ / ‖a₀‖_∞ = ‖G·(u−u₀)‖_∞ / ‖a₀‖_∞
```
`e²` is the **square** of the relative first-order excursion. We learned this the hard way: an
earlier monitor triggered on the first-order excursion `‖G·(u−u₀)‖` itself and **over-triggered
by 12×**, because `a` genuinely moves a lot within a leg (that motion is the whole point). The
*linearization error* we actually care about is the 2nd-order remainder `~C‖u−u₀‖²`; `e²` is
`O(‖u−u₀‖²)`, the right order, and needs only `a₀` and `G` (no extra probe). Measured
`corr(true a-error, ‖u−u₀‖²) = 0.985`. The count of monitor trips (re-expansions) is bounded
below by 1/leg (the mandatory anchor); the "death mode" would be re-expansion every micro-step
(→ collapses to paying O(M) per step = the thing we are removing).

### 1c. The exact-flow split (Lever 1), as you specified
The fast sub-cycle is Strang `flow(H/2) ∘ remainder(H) ∘ flow(H/2)`, where `flow` is the exact
`κ`-recession and `remainder` steps `b + Tu − â(u)` reading the affine coupling. The `u_min`
floor lives inside the recession.

### 1d. The slow (large-block) advance order — a binding constraint we did not anticipate
For this system the linear-aggregate slow-signal channel of a generic multirate coupling is
**inert** (the coupling has no separate slow-signal output; `a` is consumed entirely inside `u̇`).
So the macro step reduces to: freeze `x`, sub-cycle `u`, advance `x`. The **order of that `x`
advance** turned out to bind the functional accuracy (see §2): a 1st-order (forward-Euler) `x`
advance left an O(H) bias in `J`; we swapped it for a **3rd-order** advance (a standard explicit
3-stage table applied to the frozen-coupling macro step) and the bias collapsed.

### 1e. Reverse mode: record → replay of the discrete branch schedule
The monitor is a **discrete, state-dependent branch** (re-expand or not, decided on the live `u`).
For the adjoint we **record** the per-leg re-expansion micro-step indices on a forward pass, then
**replay** them as a fixed schedule; the taped replay is then the **exact discrete adjoint of the
scheme as run** (branch-free tape). Validated on a self-contained toy of the same structure
(adjoint vs FD `< 1e-6`). **Not yet wired on the real large-block system** (forward only there).

---

## 2. Experimental results (the payload)

**Correctness reference.** "Truth" = the same model integrated by the global adaptive explicit RK
at a converged local tolerance (`1e-12`), reported as the functional `J` (relative error), i.e. in
**J-units** as you mandated. Where that reference does not exist (it crashes — see below) we use
**self-convergence** (Richardson in the scheme's own knobs).

### 2a. The building blocks (each validated in isolation, in the right norm)
- **Inner control as an exact operating point.** Replacing the argmax bracketing search by a
  safeguarded root-find on `∂P/∂p = 0` (with an endpoint-sign boundary safeguard): max rel error
  `6.8e-4`, 1.20× cost. The exact `∂(operating point)/∂u` (implicit-function theorem, two branches
  keyed on the same active-condition test): max `6.1e-4`.
- **The coupling Jacobian `∂a/∂u`** (the `G` above), as a member-loop byproduct, validated against
  finite differences of the assembled coupling: dry-regime median `1.0e-5`; global median `1.2e-4`,
  max `2.3e-3`. (Wet-regime relative error is FD-noise-limited — the coupling scale there is ~10³×
  smaller — not a Jacobian error; an h-sweep confirms convergence to the analytic value.)
- **Offline falsifier of the affine coupling** (before building any solver): a byte-identical
  split micro-stepper run two ways over one leg, differing *only* in the coupling channel — true
  O(M) `a(u)` vs the affine `â(u)` — across a `{low,mid,high-u} × {quiet, moderate-drive, spike-drive}` bank.
  Result: the trust monitor (re-anchor when `e²` would exceed `tol=1e-2`) cuts O(M) evaluations to
  **1–14 of 40** micro-steps (2.9×–40×) while holding the `u`-trajectory error **≤ 5.5e-4**
  everywhere. Without the monitor, a high-`u`, spike-driven re-rise leg reaches **650%** coupling error —
  the monitor is necessary and sufficient. Death mode (re-anchor ≈ every step) does **not** occur
  (worst 14/40).

### 2b. Composed scheme, benign static regime (well-conditioned J)
Constant forcing, `J = O(1)`, converged reference. Per-micro-step coupling replaced by `â`:
- **Forward-Euler slow advance:** `J` rel error **9.8e-3**; O(M) evaluations **40× fewer** than the
  micro-step count; re-expansions **0** (affine model never drifts past tol on a benign leg).
- **3rd-order slow advance:** `J` rel error **2.3e-3** (4× better), same 40× reduction.

### 2c. Composed scheme, survivable *dynamic* regime (well-conditioned J) — the accuracy money-shot
Seasonal forcing at amplitude `A` about a sustaining mean; `J = O(1)` and the reference survives.
`J` relative error vs the converged reference, at the **coarse** (one-period) leg:

| forcing amplitude A | `J` (Euler slow) | `J` (3rd-order slow) | coupling-eval reduction | wall-clock |
|---|---|---|---|---|
| 0 (static) | 2e-3 | 5e-3 | 3.5× | 0.8× |
| 0.3 (moderate) | **12%** | **1.8e-4** | 3.8× | 0.9× |
| 0.6 (strong) | 48% | 15% | 8.9× | 2.1× |
| 0.9 (extreme) | 71% | 27% | 5.8× | 1.5× |

- The **12% at A=0.3 with the Euler slow advance is a real bias** (`J=35`, well-conditioned, not
  hypersensitivity). It is **pure O(H) slow-advance discretization**: refining the leg with the
  Euler advance drives it monotonically to the reference (12% → 8.4% → 1.2% → 0.6% as `H` halves
  four times), first-order — but reaching ~1% needs a leg 4× finer, which erodes the reduction to
  ~2×. **The 3rd-order slow advance gets 1.8e-4 at the coarse leg** — the accuracy without the cost.
- The 15–27% at A≥0.6 is **`J` re-entering ill-conditioning** as the system approaches a collapsed
  state (`J` → 0.77, 0.025); a leg-refinement sweep at A=0.6 shows the *discretization* is resolved,
  so the residual is the functional's own conditioning, not the scheme.

### 2d. The stress bank — the reference itself fails; J is not a usable observable there
Six externally-prescribed dynamic forcing traces (bursts, whiplash, prolonged low-forcing, dry→wet
rewetting, a horizon 3× longer, a monotone drawdown), built as *integrator stress tests*. At a
converged member mesh and inner tolerance:
- **The global adaptive reference crashes on 3 of 6** ("non-finite contribution") — a genuine
  explicit-RK integration failure on the sharp forcing, **independent of the source term's
  magnitude** (we scaled the source term 100× — all still crash). An implicit/stiff integrator is
  **unavailable for this system type** (no active-scalar rebind). So there is **no reference** on
  exactly the traces where the arbitrage matters most.
- **`J` is driven to `1e-8–1e-13` on every trace, at every member trait and every forcing scale**
  (a control-parameter sweep is monotone; a forcing-magnitude sweep 1×–20× never lifts it above
  `~1e-9`). In that regime `J` is a pathological functional: **self-convergence of our own scheme
  is non-monotone across orders of magnitude** (refining the leg 4× moves `J` by `10²–10³` before
  the two finest rungs finally agree to <2%). The `u`-*trajectory* converges fine (≤5.5e-4, §2a);
  the `J`-*integral of it* does not. So on this bank **`J` cannot discriminate any method** — and
  the reference cannot even run.
- **What the bank does show (speed + robustness):** with the 3rd-order slow advance, our scheme
  **completes all 6** (the 1st-order advance had crashed on one, the burst trace — the more
  accurate advance avoids that failure), at **3–10× fewer O(M) coupling evaluations** than the
  reference's RHS-eval count, with the trust monitor's re-expansion rate **0.11–0.53 per leg**
  (death mode absent on every trace). Wall-clock **1.0–3.2×**.

### 2e. Confirmations, refutations, and divergences vs your prior round
- **CONFIRMED — Lever 1 is exact and cheap.** Built exactly as specified (Strang, floor in the
  recession). It works and shrinks the tape.
- **CONFIRMED and EXTENDED — Probe D (`J` amplification).** In benign regimes your ~10× holds
  (0.8%→~9% class). But it is **not a constant**: as the system nears collapse the amplification
  *diverges* — `J` becomes non-convergent and the exact reference crashes. `J`-units are not merely
  ~10× tighter than `u`-units; in the stress regime there is **no finite conversion factor**.
- **FOLLOWED — validate in J-units / Richardson-in-the-knobs.** We did (§2b–2d), not adjoint-vs-FD.
  It is what surfaced the slow-advance order bias and the functional non-convergence.
- **DIVERGED — we did not reduce members (Lever 2). We linearized the coupling in `u` instead.**
  Your Lever 2 reduces the **member (ξ) axis** (O(M)→O(m) per evaluation, with the skewed-measure
  machinery). We instead reduce the **re-evaluation (u/time) axis**: keep **all M members**, pay
  the O(M) coupling + its exact `L×L` Jacobian **once per leg**, and read an **affine-in-`u`** model
  O(L²) per micro-step, re-anchoring on a 2nd-order monitor. This sidesteps the entire
  skewed-measure / member-placement problem (we never subsample members, so there is no measure
  bias and no gradient-channel deletion), at the price of a **2nd-order-in-`u`** model error per
  leg, which the monitor bounds. It is your `Δ₁` first-order-defect idea taken to its limit
  (linearize `a` itself, not the reduction defect), plus a monitor.
  **The open question is whether this escapes the frozen-coupling refutation** (we believe it does —
  we carry `∂a/∂u` exactly, so the fast Jacobian is right at the anchor and drifts only at 2nd
  order) **or quietly re-enters it.**

---

## 3. Structural features — any may be load-bearing or incidental; we do not know which

The exact-flow recession of `κ` (`q≈16`, closed form) and its `u_min` floor; the near-singular
`κ′` at high `u`; the kinked forcing `b`; the one-way cascade `T`; the coupling `a` as an O(M)
byproduct with no cheap route; **members placed for `x(t)`, not for `c·ρ`; skewed evolving `ρ`;
`M` growing over `[0,T]`**; the smoothness of `c, p*` in `ξ`; the **exact `L×L` coupling Jacobian
`∂a/∂u` as a per-leg O(M) byproduct**; the **affine-in-`u` coupling model** and its 2nd-order error;
the **`e²` (squared relative excursion) trust monitor** and its `corr=0.985` with the true error;
the **once-per-leg O(M) anchor** vs **O(L²) per micro-step**; the **3rd-order slow advance** and the
O(H) `J`-bias the 1st-order one left; the inert slow-signal channel (so the macro step is just
freeze/sub-cycle/advance); the fixed micro-step count per leg (not adaptive); the Strang split order
(commutator in `κ′`); the **record→replay of the discrete monitor branch** for the adjoint; the
`J` hypersensitivity (~10× benign, divergent near collapse); the fact that **`ẋ_j` needs all M
member solves per leg regardless of the coupling** (common to every scheme); the exact `∂P/∂p`;
`L=5`; the reference solver's non-finite failure on 3/6 stress traces; the unavailability of an
implicit integrator for this system type.

## 4. Facts an answer can rely on

- `a(x,u)` is obtainable only via the member solves, is non-separably `u`-dependent, and its exact
  `L×L` Jacobian `∂a/∂u` is available as a byproduct of the same O(M) member loop (no extra solves).
- The affine model `â(u)=a₀+G(u−u₀)` is exact in value and first derivative at the anchor; error is
  2nd-order in `(u−u₀)`; the monitor `e²>tol` re-anchors (O(M)) on drift.
- A **full-M coupling evaluation is free at every leg boundary** (the frozen `x` is there); only the
  **per-micro-step** coupling is where O(M) hurts.
- `ẋ_j` requires all M member solves per leg regardless of how `u` is advanced — including 3× the
  member solves per leg under the 3-stage slow advance. This is the per-leg floor cost.
- A documented change of discretization is acceptable **iff** the forward `J` and the reverse-mode
  `dJ/dθ` stay correct. When the arbitrage is disabled the scheme must be **bit-identical** to the
  original single-rate solver (it is: the whole apparatus is gated off by default).
- The reverse-mode replay reproduces the exact discrete adjoint of the scheme as run *for a fixed
  branch schedule*; the schedule is recorded on the forward pass.

## 5. What we'd most value your independent judgement on (open; reject the framing if warranted)

1. **Did we reduce along the right axis?** We linearized the coupling in the small block `u`
   (exact `L×L` Jacobian + 2nd-order monitor, all M members kept) rather than reducing the member
   count. Rank this against your Lever-2 (member reduction) *given* the members are placed for
   `x(t)`, `ρ` is skewed and growing, and `J` is hypersensitive. Which is the better lever, and
   where does the u-linearization fail that member-reduction would not (or vice versa)?
2. **Does the u-linearization escape the frozen-coupling refutation, or re-enter it?** We carry
   `∂a/∂u` exactly at the anchor (fast Jacobian correct there), with a 2nd-order-in-`u` intra-leg
   error bounded by the monitor. Is that genuinely a different class from the refuted held coupling,
   or a subtler version of the same mistake that the benign/survivable data are hiding?
3. **Is freezing the monitor's discrete branch schedule adjoint-consistent?** The re-anchor
   decision is a state-dependent branch on the active `u`. We record it forward and replay it fixed,
   giving the exact adjoint of the scheme-as-run — but the *true* `dJ/dθ` includes the sensitivity
   of *where* re-anchors occur to `θ`. Is the frozen-schedule adjoint correct to the order we need
   (we argue the crossing contributes at `O(perturbation × tol)` because the integrand is continuous
   at a re-anchor), or does it drop a real gradient term? This matters because reverse mode on the
   large-block system is **not yet built** — we want the landmines named first.
4. **The slow-advance order was the binding accuracy constraint, not the split.** A 1st-order `x`
   advance left an O(H) `J`-bias (12% at a one-period leg under dynamic forcing); 3rd-order fixed
   it (1.8e-4). Is order-3 sufficient and necessary, or should we expect **order reduction** from
   the kinked `b` or the near-singular `κ′` at some forcing amplitude we have not probed — and if
   so, what is the right diagnostic?
5. **Is `J` simply the wrong observable in the stress regime?** On the stress bank `J` is
   non-convergent (self-convergence swings `10²–10³`) and the exact reference crashes, yet the
   `u`-trajectory converges to ≤5.5e-4. Is there a **reconditioned functional or regularization**
   that is well-posed under the same dynamics near collapse, or is the near-singular behaviour of
   `J` telling us something structural we should respect rather than smooth?
6. **The cost target.** `ẋ_j` needs all M member solves per leg regardless; the 3-stage slow advance
   triples that; the coupling arbitrage only removes the *per-micro-step* O(M). Wall-clock therefore
   wins only where micro-steps are many (stress episodes: 1.5–3.2×) and is neutral-to-slightly-slower
   at low stress (0.8–0.9×) despite 3.5× fewer coupling evaluations. **Are we optimising a
   non-dominant cost** in the benign regime, and is there a better target (e.g. cheapen the per-leg
   M member solves themselves, or an adaptive slow-advance order)?
7. **Load-bearing vs incidental:** rank the §3 features for the achievable cost/accuracy.
8. **What are we missing?** A structural simplification, a hidden cost, a fragile assumption the data
   quietly contradict, or a frame in which this whole arbitrage is the wrong object now that the
   step-collapse is already solved by the skeleton and only per-step cost remains.
