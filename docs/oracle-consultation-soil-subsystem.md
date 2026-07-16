# A strongly-forced low-dimensional subsystem that is expensive to resolve — forward and reverse — a targeted consultation

**What this is.** A self-contained, deliberately narrow problem statement for an external reasoner
with no code access and no prior context. A small auxiliary subsystem inside a much larger ODE
integration is expensive to resolve accurately under realistic forcing, and that expense falls on
**both** the forward solve and its reverse-mode gradient. We want to make it performant and correct
in both directions. **Do not presuppose a solution** — in particular do not assume the answer is an
implicit/stiff stepper, a quasi-steady-state elimination, or operator splitting; a measurement below
suggests the usual stiffness remedy does not apply. We suspect the difficulty may be a
representational artifact (the state variable, the near-singular constitutive law, the hard reset)
rather than intrinsic; challenge the framing.

We integrate with an adaptive explicit Runge–Kutta method and differentiate with an XAD
operator-overloading reverse-mode tape. Nothing below is application-specific.

## 1. The subsystem
A low-dimensional state `u ∈ ℝ^L` (`L ≈ 1–5`) evolves alongside a large main system:

```
du_ℓ/dt = ( s_ℓ(t) − w_ℓ(u_ℓ) − σ_ℓ ) / τ_ℓ ,   ℓ = 1..L
w_ℓ(u) = W_ℓ · (u_ℓ / u_sat)^p ,   p ≈ 16 ,   u_ℓ ≥ 0 (enforced by a reset when a step would cross 0)
```
- `s_ℓ(t)` is an **external forcing** that is realistically **rapid and intermittent** (bursts
  separated by quiet intervals), not smooth.
- `w_ℓ` is a **state-dependent loss with a large exponent** (`p ≈ 16`): near-zero when `u` is low,
  steep when `u` is high. Both `w_ℓ` and other quantities read off `u` (below) approach a
  **singularity as `u → 0`** (the reason for the reset).
- `σ_ℓ` is a **sink drawn from the large main system** (see §2).

## 2. The coupling and the cost setting
The main system is a large ODE (dimension `N ≈ 10²–10³`) integrated on a **shared adaptive step
schedule** with `u`. The coupling is **bidirectional**: `σ_ℓ` (the sink) is produced by the main
system's per-element computation, and `u` (via `w_ℓ` and the near-singular reads) feeds **back** into
that computation. The whole thing runs for `10³–10⁵` steps, and we take **reverse-mode gradients** of
scalar reductions of the run with respect to parameters — so every accepted step is both integrated
forward and swept in reverse (taped). Cost is dominated by **step count**: when the shared adaptive
controller shrinks the step, the whole large system pays it, forward and reverse.

## 3. The measured difficulty (the key datum)
Instrumenting realistic runs, the step-size collapse that dominates cost is **accuracy-driven, not
stability-driven**, and it is localised to `u`'s fast transients:
- The controller's smallest steps occur when `u` is **low** (depleted, near the `u→0` singularity),
  where the linear relaxation time `τ/w′(u) ∝ u^{1−p}` is actually **large** (slow). So the small
  steps are **not** the classical stiff-stability limit (which would bind at *high* `u`, where
  relaxation is fast); they are the controller resolving a **genuinely rapid excursion** of `u`
  toward the singular boundary during a forcing burst.
- Quantitatively: `corr(log Δt, log(‖u − u*‖/u)) = −0.91` (`u*` = the instantaneous balance point);
  every smallest-decile step is a far-from-balance transient (`‖u−u*‖/u` up to ~25); ~90% of steps
  are near balance with large steps, ~10% are these tiny-step transients.
- **Consequences that rule out the usual remedies:** a quasi-steady-state elimination of `u`
  (`w(u*) = s − σ`) is invalid in exactly the ~10% of steps that cost the most (there `u` is far from
  `u*`). An A-stable/implicit stepper would **not** enlarge the steps either, because the transient is
  a *real, accuracy-limited* feature of the solution, not a fast mode decaying to a slow manifold.

## 4. What we need
`u` resolved **performantly and correctly in both forward and reverse** under the realistic rapid
forcing of §1 — i.e. the ~10% tiny-step transients made cheap without corrupting the trajectory or
its gradient. The reduction gradients must still match a finite difference of the model as run.

## 5. Facts an answer can rely on
- The subsystem is low-dimensional (`L ≤ 5`); the main system is large and shares its step schedule.
- The forcing `s(t)` is data (recordable), rapid, intermittent.
- The state is nonnegative with a hard reset at 0; the loss and other reads are near-singular as
  `u → 0`.
- A **reformulation is on the table** — of the state variable, the constitutive law near the
  boundary, the reset, or how `u` is stepped relative to the main system — if it makes the resolution
  cheap and keeps the forward values and the reverse gradient correct.
- The measurement in §3 is trustworthy (instrumented on realistic runs); treat "implicit fixes it"
  and "QSS fixes it" as **already refuted** for this subsystem and update accordingly.

## 6. Questions (open; invite reframing)
1. Given §3, **what actually makes this subsystem expensive**, and is it **intrinsic** or an artifact
   of a representational choice we have not questioned — the state variable `u`, the `u^p`
   near-singular loss, or the hard reset at `u → 0`?
2. Is there a **change of variables, regularisation, or local (per-step) analytic treatment** of the
   rapid excursion near the singular boundary that resolves it cheaply **and** stays differentiable in
   reverse mode — without changing the forward values beyond a documented, controlled amount?
3. Should `u` be **decoupled from the main system's shared step schedule** — sub-cycled or given its
   own local error control — so its tiny-step transients do not force the whole large system to small
   steps? If so, what is the correct reverse-mode treatment of a sub-cycled subsystem, and how does
   the bidirectional coupling constrain it?
4. Of the features — the large exponent `p`, the intermittent forcing, the hard reset, the shared
   schedule, the bidirectional coupling — which is load-bearing for the cost, and which is incidental?
5. A **cheap discriminating experiment** for whatever mechanism you judge most likely, to run before
   building.
