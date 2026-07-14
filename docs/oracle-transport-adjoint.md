# Hard-to-differentiate components of a parametrized ODE/PDE solver

A domain-agnostic catalog. No application knowledge is assumed or needed.

We integrate a parametrized system of differential equations forward in time and
want the gradient of a scalar functional `M` of the solution with respect to a
vector of parameters `θ`, by **reverse-mode automatic differentiation** (a
discrete adjoint of the whole solve: run with an AD scalar type substituted for
`double`, taping every operation, then one reverse sweep returns `dM/dθ`). Most
of the code differentiates transparently. A recurring handful of components do
**not** — naive taping gives a wrong or ill-conditioned gradient even though the
forward value is correct. This document states each one abstractly: what it is,
why naive AD fails, and the technique (established or found) that fixes it.

Component 1 is written up in full, including the resolution we arrived at with
outside input; it is the template for the analysis the others need. Components
2–8 are stated more briefly.

---

## 1. Spatial-derivative term of a stabilized transport equation — RESOLVED

### Setup
A conservation law of advection type, `∂n/∂t + ∂/∂x(g·n) = source`, discretized on
a set of points `x_i`. The velocity `g = g(x, θ, S)` is a smooth closed-form
function of the coordinate `x`, the parameters `θ`, and a **coupling field** `S`
reconstructed each step from the whole solution (so the points interact). The
transport needs the spatial derivative `D = ∂g/∂x` at each point, computed as a
one-sided finite difference with a small fixed step `h`: `D = (g(x) − g(x−h))/h`.
`g` contains a smooth but sharply-varying regularized limiter (a softplus-type
surrogate for `max(0,·)` with corner scale `ε`; its second derivative peaks at
`~1/ε`).

### Why naive AD fails
Taping the stencil records its exact θ-derivative `(g_θ(x) − g_θ(x−h))/h`, a
finite difference of the parameter-sensitivity over the tiny fixed `h`. Near the
regularized limiter (`g_xθ ~ 1/ε`) this is huge (`~10⁶`–`10⁷` where the true
gradient is `~10²`). The number is **exact, not rounding** — the numerator is
genuinely `O(1)` there. Recorded pointwise, `M(θ)` carries a sub-grid staircase
(steep ramps of slope `~1/h` separated by flats, because `h ≪` the point
spacing `Δx`); the exact discrete adjoint faithfully reports the local staircase
slope, which is not the macroscopic sensitivity anyone wants.

### What we tried
- **Differentiate the stencil on-tape** (exact discrete adjoint): consistent but
  ill-conditioned as above (`~10⁶`).
- **Use the exact analytic `∂g/∂x` throughout**: we *believed* this was
  forward-unstable, but a control experiment refuted that — running the term
  through the live path with a vanishing step (down to `1e-10`, one-sided *and*
  centred) is stable and matches production. The earlier "instability" was an
  implementation that **froze the coupling field** `S`, dropping the `∂g/∂S·dS/dx`
  term (a different, incomplete derivative). *There is no stability barrier.*
- **Keep the stencil value, inject the exact analytic derivative at fixed `S`**
  (the fixed-coupling partial `∂g/∂x|_S`): stable, well-conditioned, but drops
  the coupling term → a consistent ~1.5% underestimate that grows with coupling.

### Resolution
Record the **total** derivative `D = ∂g/∂x|_S + ∂g/∂S·(dS/dx)`, obtained by a
forward-over-reverse tangent sweep in which the coupling scalar the sweep sees
carries **value** `S(x)` and **tangent** `dS/dx`. Two rules make it work:

1. **`dS/dx` comes from the secant** `(S(x) − S(x−h))/h`, i.e. the same robust
   finite difference of the reconstructed field that the forward solve uses — not
   the field reconstruction's analytic tangent (that channel is unreliable, see
   component 6).
2. **Inject the secant's value but FREEZE its θ-sensitivity.** Taping
   `d(dS/dx)/dθ = (S_θ(x) − S_θ(x−h))/h` is exactly the `h ≪ Δx` staircase again,
   on the coupling channel — it overshoots the gradient by ~2.3×. Its true
   contribution is < 0.5%, so injecting the value and differentiating the *frozen*
   surrogate is both well-conditioned and accurate.

This is the "record the stabilization's value, differentiate a tamer surrogate"
(frozen-limiter) move from adjoint CFD, applied to the coupling secant. Result:
the multi-cohort gradient closed to < 0.5% for the parameters that drive the
velocity directly (one to ~0.03%), forward solution bit-identical.

### Residual / open
The freeze is exact only while `d(dS/dx)/dθ`'s true contribution is small. If a
future functional makes it matter, it needs a *consistent* well-conditioned
channel — the standing candidate is taking the coupling difference over the
actual point spacing `Δx` (a true grid stencil, adjoint scale `O(1/Δx)`) instead
of the sub-grid probe `h`. Established art in the same family: differentiable /
frozen limiters and dual-consistent (SBP-SAT, entropy-stable) schemes; adjoints
at shocks (Giles & Ulbrich — exact discrete adjoints of shock-capturing schemes
oscillate and converge only in a weak/averaged sense, the justification for
trusting the trend not the pointwise tangent); least-squares shadowing for the
chaotic-adjoint extreme.

---

## 2. Implicit quantity defined by a root-find

### Abstract
A value `y*` is defined implicitly as the solution of `F(y*, θ) = 0`, computed by
an iterative solver (Newton, bisection) whose per-iteration arithmetic is either
non-differentiable or pointless to tape.

### Why naive AD fails
Taping the iteration differentiates the *solver's path* (step count, line
searches, tolerances), not the solution map. It is expensive, and at a
tolerance-terminated fixed point the recorded derivative is noisy and
iteration-count-dependent — a discontinuous, wrong `dy*/dθ`.

### Technique
Do not differentiate the iteration. Use the **implicit function theorem**:
`dy*/dθ = −(∂F/∂y)⁻¹ (∂F/∂θ)`, evaluated once at the converged `y*`. Inject `y*`
as an off-tape value with these analytic partials attached (a "supplied
derivative" seam), so the reverse pass distributes adjoints to `θ` through the
IFT formula. `∂F/∂y` and `∂F/∂θ` themselves come from AD of `F` (cheap, `F` is
differentiable) — the only thing excluded from the tape is the *search*.

---

## 3. Optimum of an inner problem (argmin / argmax)

### Abstract
A value is the optimum `v* = min_ψ (or max) φ(ψ, θ, inputs)`, or the optimizer
`ψ*(θ)` itself, produced by an inner optimization AD cannot see through.

### Why naive AD fails
Same as component 2, plus: unrolling the optimizer is memory-heavy and its
tape-derivative is dominated by the optimizer's transient, not the optimum's
dependence on `θ`.

### Technique
**Envelope theorem (Danskin):** at the optimum the derivative of the *optimal
value* w.r.t. a parameter is the *partial* derivative of the objective at `ψ*`,
because `∂φ/∂ψ = 0` there: `dv*/dθ = ∂φ/∂θ (ψ*, θ)`. Inject `v*` with `∂φ/∂θ`
partials (same seam as component 2). One subtlety this application surfaced: if
one of the "parameters" is itself an *active state variable that the objective
also optimizes against implicitly* (here, a shared resource level the optimum
responds to), its envelope partial `∂φ/∂(that state)` is a genuine extra term and
must be included — it is easy to miss because at `ψ*` the *ψ*-gradient is zero,
which can be mistaken for "no sensitivity".

---

## 4. A value that is itself a numerical derivative (higher-order taping)

### Abstract
A site computes a derivative — a finite difference, an interpolant's analytic
slope, a numerical Jacobian — and lets it flow to an output. Component 1 is the
flagship instance; this is the general class.

### Why naive AD fails
The moment the outer reverse pass differentiates it, you are taking a **second**
derivative of a **first-order approximation**. Differentiating an FD stencil
`(f(x)−f(x−h))/h` on-tape amplifies by `1/h` anything non-smooth it straddles;
differentiating an under-resolved interpolant's slope compounds its error.

### Technique
Never differentiate the approximation. Treat the derivative as an exact object:
**forward-over-reverse** (a tangent sweep seeded in the derivative's direction,
carried on the outer adjoint tape) when the underlying code is differentiable, or
**inject it with analytic partials** (components 2–3) when it is opaque. The
general audit rule that catches this class: tag every site with "is this value a
derivative?" — a first-order "is the active scalar present and classified?" check
cannot see it.

---

## 5. Non-smooth operations on the differentiated path (kinks)

### Abstract
`max(0, ·)`, `min(a, b)`, absolute value, clamps, floors, positivity resets,
sign branches — points where the code is continuous but not differentiable.

### Why naive AD fails
AD returns *a* subgradient at the kink, which is correct almost everywhere but
(a) is arbitrary exactly at the kink, and (b) becomes actively dangerous when a
kink sits on a value that is itself differentiated or finite-differenced: an
inner FD stencil straddling the kink is amplified (component 1/4), and the
second derivative is a spike.

### Technique
On a path whose derivative is consumed, replace the kink with a **C∞ smooth
surrogate** that preserves the bound and → the kink as a sharpness parameter
→ ∞ (e.g. `½(x + √(x² + ε²))` for `max(0,x)`; smooth-min; logistic step). Choose
the sharpness so the value change is negligible but the second derivative stays
bounded — there is a real tension (sharper = smaller value change but steeper
`f''`). Kinks *not* on a differentiated path (pure guards, selectors,
finiteness/NaN tests) need no smoothing — but they must be made **scalar-generic
so they never throw on an active intermediate** (read the value, never the tape),
fixed once at the utility definition rather than per call site.

---

## 6. Derivative of a reconstructed field at an evolving query point

### Abstract
A field is reconstructed by interpolation/regression through sample points (a
spline), then queried at a point that is itself an evolving state variable of the
ODE. Two derivative channels exist: w.r.t. the **fitted data** (knot values), and
w.r.t. the **query location** (the interpolant's analytic tangent).

### Why naive AD fails
The data-channel is fine and wanted. The query-tangent channel is a trap: for an
under-resolved reconstruction the analytic tangent is a poor estimate of the true
field slope, and when the query point is an evolving ODE state that error
**compounds across the time integration** (single-case: exact at short horizons,
17× off at long ones). The forward *value* is unaffected — this is purely a
recorded-derivative pathology, so it passes a value check.

### Technique
Make the reconstruction's **default active read freeze the query-point
derivative** (evaluate at the fully-stripped query value, carry only the
data-channel derivative). It is value-identical to a plain read, so it is a no-op
for the forward pass and cannot silently attach the dangerous tangent. Expose the
query-tangent read as an explicit, opt-in method for the rare caller that
genuinely wants it (a well-resolved reconstruction queried at a real
differentiation input). Where a query-*direction* derivative is genuinely needed
on a rate path, get it from a **secant** over the sample spacing, not the analytic
tangent (this is the `dS/dx` rule in component 1).

---

## 7. Discretization decisions taken on the primal value

### Abstract
The solver chooses structure adaptively from the *primal* computation: an adaptive
mesh/refinement picks sample points where the value's local error is large; an
adaptive time-stepper picks step sizes and step *times* from a value-based error
estimate; a reconstruction chooses its node set the same way.

### Why naive AD fails
These decisions are taken in `double` (via the value, not the tape), so within one
fixed structure the gradient is exact, but the **structure itself is a
discontinuous function of `θ`**: a small `θ` change that moves a refinement
boundary or changes a step count makes `M(θ)` jump at the sub-cell / sub-step
scale. The discrete adjoint is exact only *within* a refinement cell / for a fixed
schedule; the sensitivity of the *chosen structure* to `θ` is dropped, and
`d(step-time)/dθ` for an adaptive stepper is not readily available at all.

### Technique / open
Standard practice **freezes the structure**: record the adaptively-chosen
schedule / node set on the primal pass and *replay it fixed* on the differentiated
pass, so the gradient is the exact derivative of the fixed-structure solve (the
approach used here for the growing/adaptive integration). This is consistent and
usually accurate because the dropped term (sensitivity of the discretization
choice) is genuinely small — but it is an unquantified approximation. The open
question mirrors component 1: whether `d(structure)/dθ` ever matters, and if so
whether a consistent well-conditioned channel exists short of a fully
structure-differentiable (e.g. moving-mesh with taped node equations) solver.

---

## 8. State carried across taping boundaries (caches, warm-starts, reused fits)

### Abstract
A quantity computed in one recording is reused in the next: a memoized
sub-solution, a warm-start for an iterative solver, a reconstruction whose knots
are reused/rescaled across steps, a `mutable` cache.

### Why naive AD fails
The cached value carries (or should carry) a derivative from the recording that
produced it; if the tape is reset (`newRecording`) between producer and consumer,
that link is silently severed — the consumer sees a constant where a
`θ`-dependent value should be, an implicit-zero derivative that no value check
catches. Conversely, taping *into* a stale cache double-counts.

### Technique
Make the cache boundary explicit in the derivative bookkeeping: either recompute
the cached quantity inside the consuming recording (so its derivative is live), or
treat the cache as an off-tape input and inject its partials (components 2–4).
Warm-starts are safe *only* for the value — the converged solution's derivative
must still come from the implicit-function / envelope formula at the fixed point,
never from the warm-started iteration. Audit every quantity that survives a
`newRecording` and every `mutable` member on the differentiated path.

---

## Cross-cutting lessons

- **A correct forward value does not imply a correct derivative.** Several of
  these (1, 4, 6, 8) are value-identical to production and wrong only in the tape.
  Any gate that checks values, or checks a single short trajectory, is
  structurally blind to them; the gate must be a multi-step trajectory *with the
  coupling active*, checked against a finite-difference gradient.
- **Classify by relationship to the derivative, not by site.** Off-the-derivative
  (guards) / opaque-off-tape (solves → inject) / on-tape arithmetic / *is-itself-a-
  derivative* (→ higher-order) — the treatment lives at the operation's
  definition, so no call site special-cases and the sanctioned-narrowing list
  stays small.
- **"Record the value, differentiate a tamer surrogate"** recurs (1, 7, 8): when
  the exact derivative of a numerically-stabilized or adaptively-chosen quantity
  is ill-conditioned or unavailable, freezing it and differentiating a smooth
  stand-in is often both well-conditioned and accurate — but it is an
  approximation whose dropped term must be argued small, not assumed zero.
