# Hard-to-differentiate components of a parametrized ODE/PDE solver

A domain-agnostic catalog and playbook. No application knowledge is assumed.

We integrate a parametrized system of differential equations forward in time and
want the gradient of a scalar functional `M` of the solution with respect to
parameters `θ`, by **reverse-mode automatic differentiation** (run with an AD
scalar type substituted for `double`, taping every operation; one reverse sweep
returns `dM/dθ`). Most code differentiates transparently. A recurring handful of
components do not — naive taping gives a wrong or ill-conditioned gradient even
though the forward value is correct.

---

## 0. The general problem (state it once — it disciplines everything below)

The program computes `M_h(θ)`, an approximation to a modelled map `M(θ)`, where
`h` stands for **every internal small parameter** — stencil steps, kink widths
`ε`, solver tolerances, sample spacings, accepted time steps. Reverse-mode AD
returns `∇M_h` *exactly*. What is wanted is `∇M` — the derivative of the
resolution-independent part. These agree only under a condition strictly stronger
than value convergence: **gradient consistency**, `∇M_h → ∇M`, which requires the
approximation to be smooth in `θ` **uniformly in `h`**.

Every pathology below is a site where value convergence holds but the
`θ`-Lipschitz constant of the block **diverges as its small parameter is
refined**: `1/h` for the stencils (§1, §4), `1/ε` for the kinks (§5), a
discontinuous iteration count (§2, §3), an error compounding with horizon (§6).
That gives one audit question that finds all of them, including uncatalogued ones:

> **For each block, what happens to its θ-derivative as its internal small
> parameter goes to its limit? If it diverges, oscillates, or jumps, it is a seam.**

And one architectural answer: the tape should see a **composition of
mathematically-defined maps with hand-attached derivatives** (custom VJP/JVP
primitives), while *inside* each seam the implementation is free to be iterative,
branchy, stabilized, or non-smooth. **Differentiate the mathematics, not the
code.** Every fix in this document is an instance of installing such a seam.

---

## 1. Spatial-derivative term of a stabilized transport equation — RESOLVED

### Setup
A conservation law of advection type, `∂n/∂t + ∂/∂x(g·n) = source`, discretized on
points `x_i`. The velocity `g = g(x, θ, S)` is smooth closed-form in the
coordinate `x`, parameters `θ`, and a **coupling field** `S` reconstructed each
step from the whole solution (so the points interact). The transport needs
`D = ∂g/∂x`, computed as a one-sided finite difference with small fixed step `h`:
`D = (g(x) − g(x−h))/h`. `g` contains a smooth but sharply-varying regularized
limiter (softplus-type surrogate for `max(0,·)`, corner scale `ε`, `f'' ~ 1/ε`).

### Why naive AD fails
Taping the stencil records `(g_θ(x) − g_θ(x−h))/h`, a finite difference of the
parameter-sensitivity over the tiny fixed `h`. Near the limiter (`g_xθ ~ 1/ε`)
this is huge — **exact, not rounding** (the numerator is genuinely `O(1)` there).
Recorded pointwise, `M(θ)` carries a sub-grid staircase (ramps of slope `~1/h`
between flats, because `h ≪` the point spacing `Δx`); the exact discrete adjoint
faithfully reports the local staircase slope, not the macroscopic sensitivity.

### What was tried
- **Differentiate the stencil on-tape** (exact discrete adjoint): consistent but
  ill-conditioned as above.
- **Use the exact analytic `∂g/∂x` throughout**: believed forward-unstable, but a
  control experiment refuted that — the term through the primal path with a
  vanishing step (one-sided *and* centred) is stable and matches production. The
  apparent instability came from an implementation that **froze the coupling
  field** `S`, dropping the `∂g/∂S·dS/dx` term (a different, *incomplete*
  derivative). **The third horn of the trilemma never existed** (see the
  completeness lesson in §7).
- **Keep the stencil value, inject the exact derivative at fixed `S`** (the
  partial `∂g/∂x|_S`): stable, well-conditioned, but drops the coupling term → a
  consistent underestimate that grows with coupling strength.

### Resolution
Record the **total** derivative `D = ∂g/∂x|_S + ∂g/∂S·(dS/dx)` by a
forward-over-reverse tangent sweep in which the coupling scalar the sweep sees
carries **value** `S(x)` and **tangent** `dS/dx`. Two rules:

1. **`dS/dx` from the secant** `(S(x) − S(x−h))/h` — the same robust finite
   difference of the reconstructed field the forward solve uses, not the
   reconstruction's analytic tangent (that channel is unreliable, §6).
2. **Inject the secant's value but FREEZE its θ-sensitivity.** Taping
   `d(dS/dx)/dθ = (S_θ(x) − S_θ(x−h))/h` is the `h ≪ Δx` staircase again, on the
   coupling channel — it overshoots the gradient severalfold. Its true
   contribution is negligible, so injecting the value and differentiating the
   *frozen* surrogate is well-conditioned and accurate.

Result: the gradient closed to sub-percent accuracy for the parameters that enter
the velocity directly, forward solution bit-identical.

### Residual / open (a bias-ledger entry — §7)
The freeze is exact only while `d(dS/dx)/dθ`'s true contribution is small — the
same epistemic status the fixed-`S` option had before its bias was found to grow
with coupling. Make the check **standing, not one-off**: occasionally evaluate the
gradient both ways (frozen vs. a `Δx`-stencil θ-sensitivity on the coupling
channel) and monitor the gap as a scalar diagnostic; a new functional or stronger
coupling will show up before it bites. Note the `Δx` version is not merely a
fallback — it is **consistent by construction** (windows tile, adjoint scale
`O(1/Δx)`), so if its cost is acceptable it can *replace* the freeze and retire
the assumption. Second caveat: rules 1 and 2 both assume `S` is smooth at scale
`h`; if the reconstruction ever sharpens (finer features in `S`), the secant
*value* channel can develop its own staircase in `x`. The scale-matching law (§4)
applies to the value too: **the probe step must not undercut the smoothing scale
of what it probes.** Established art in the family: differentiable / frozen
limiters, dual-consistent (SBP-SAT, entropy-stable) schemes, WENO's smooth
nonlinear weights (an existence proof that C∞ stabilization is achievable);
adjoints at shocks (Giles & Ulbrich — exact discrete adjoints of shock-capturing
schemes oscillate and converge only weakly, the justification for trusting the
trend not the pointwise tangent); least-squares shadowing for the chaotic extreme.

---

## 2. Implicit quantity defined by a root-find

**Abstract.** A value `y*` solves `F(y*, θ) = 0`, computed by an iterative solver
whose per-iteration arithmetic is non-differentiable or pointless to tape.

**Why naive AD fails.** Taping the iteration differentiates the *solver's path*
(step count, line searches, tolerances), not the solution map — expensive, and at
a tolerance-terminated fixed point the recorded `dy*/dθ` is noisy and
iteration-count-dependent.

**Technique — implicit function theorem, as a first-class primitive.** Forward
pass runs any solver on plain doubles (invisible to the tape). Reverse pass solves
**one transposed linear system** `(∂F/∂y)ᵀ λ = ȳ` and accumulates
`θ̄ −= (∂F/∂θ)ᵀ λ`. **Never form the inverse.** `∂F/∂y`, `∂F/∂θ` come from AD of
`F` itself. If the forward solver is Newton, reuse the converged Jacobian/factor
— **but only if it is the true Jacobian**; a Broyden/quasi-Newton approximation
converges the forward solve yet silently biases the adjoint. For large contraction
maps `y ← Φ(y,θ)` where factorization is unaffordable, use **Christianson's
reverse fixed-point iteration** `λ ← (∂Φ/∂y)ᵀ λ + ȳ` (converges at the forward
rate).

**Standing defenses.** *Tolerance*: gradient error ≈ terminal residual × `κ(∂F/∂y)`
— gradient accuracy sets the tolerance, not value accuracy; cheapest fix is one
extra Newton step before the adjoint solve. *Branches*: with multiple roots the
gradient is meaningful only if the solver tracks one branch continuously in `θ`;
warm-starting promotes continuity but adds hysteresis (`y*` becomes a function of
history), harmless only under tight convergence. *Singularity*: near a fold the
Jacobian degenerates and the gradient legitimately blows up — monitor a condition
estimate to distinguish "true sensitivity huge" from "seam broken." The seam is
**unit-testable in isolation** against finite differences of `y*(θ)`.

---

## 3. Optimum of an inner problem (argmin / argmax)

**Abstract.** A value is the optimum `v* = opt_ψ φ(ψ, θ)`, or the optimizer
`ψ*(θ)` consumed downstream.

**Why naive AD fails.** As §2, plus: unrolling the optimizer is memory-heavy and
its tape-derivative is dominated by the optimizer's transient.

**Technique — separate the consumers, they need different machinery.**
- *Optimal value* → **envelope theorem (Danskin):** `dv*/dθ = ∂φ/∂θ(ψ*, θ)`,
  since `∂φ/∂ψ = 0` at `ψ*`. Error is **second order** in the inner optimality gap,
  so it tolerates loose inner solves.
- *Optimizer `ψ*`* → **IFT on the stationarity condition** `∇_ψφ = 0` (a Hessian
  solve — §2 with `F = ∇_ψφ`). Error is **first order**, so it needs tight
  convergence.

**Mechanical envelope — stop-gradient on the argmin output.** Evaluate
`φ(detach(ψ*), θ)` with everything else active and let AD collect the partials.
The only path severed is `dψ*/dθ` — precisely the one stationarity kills — and
every other route by which a target enters `φ`, *including implicit ones*, is
picked up automatically. This is the mechanical cure for the "easy-to-miss extra
term": no bookkeeping, no term to forget.

**Content in the constrained case.** The envelope is taken on the Lagrangian,
multipliers appear in the derivative, and an active-set change is a genuine kink
in `v*(θ)` (§5 at the solver level) — if the active set flickers along the
`θ`-path, smooth it structurally (interior-point / log-barrier surrogate), not
pointwise (Fiacco's NLP sensitivity theory). A non-unique optimizer reduces
Danskin to a directional derivative over the solution set; AD returns one
selection — flag it like any subgradient.

---

## 4. A value that is itself a numerical derivative (higher-order taping)

**Abstract.** A site computes a derivative — a finite difference, an interpolant
slope, a numerical Jacobian — and lets it flow to an output. §1 is the flagship;
this is the general class (§6 is another member).

**Why naive AD fails.** The outer reverse pass then takes a **second** derivative
of a **first-order approximation**: differentiating `(f(x)−f(x−h))/h` amplifies by
`1/h` anything non-smooth it straddles; differentiating an under-resolved
interpolant slope compounds its error.

**Decision rule once a site is tagged.** Ask: is this numerical derivative (a) a
cheap stand-in for an *available exact* derivative, or (b) a *deliberately
modified* operator (the discretization **is** the model, e.g. a stabilizing
stencil)? For (a) → replace the value with the exact AD derivative
(forward-over-reverse); the problem evaporates (this is what §1's control
experiment showed was possible once the incomplete-derivative bug was fixed). For
(b) → keep the value and **differentiate the modified equation** (a smooth
closed-form surrogate with the same leading-order behavior) or **freeze** with a
bias-ledger entry (§7).

**Scale-matching law (the quantitative content of §1, §4, §5, §6 at once):**
*every probe step must be at least the smoothing scale of what it probes, and
every smoothing scale must be at least the largest probe step that will straddle
it.* Concretely `ε ≳ κ·h`, and `h ∈ {0 (exact tangent), ~Δx (tiling stencil)}` —
**never in between**, because the in-between region is exactly where staircases
live. If you will ever need Hessian-vector products, all seams must support
**nesting** (custom JVPs of custom VJPs) — design the seam API for second order
now, even if only first order is implemented.

---

## 5. Non-smooth operations on the differentiated path (kinks)

**Abstract.** `max(0,·)`, `min(a,b)`, `abs`, clamps, floors, positivity resets,
sign branches — continuous but not differentiable.

**Why naive AD fails.** AD returns *a* subgradient: correct almost everywhere but
arbitrary at the kink, and dangerous when the kink sits on a value that is itself
differentiated or finite-differenced (an inner stencil straddling it is amplified,
§1/§4).

**Three categories, three treatments.**
1. *Smoothable on a differentiated path* → **C∞ surrogate** preserving the bound
   (`½(x+√(x²+ε²))` for `max(0,x)`; smooth-min; logistic step). The tension is
   *computable*, not qualitative: value budget gives `ε ≤ 2·(allowed value
   change)`; the scale-matching law gives `ε ≥ κ·h` for every straddling stencil
   step. **If the constraint set is empty, the fix is removing the probe (§4's
   decision rule), not a cleverer `ε`.**
2. *Guard / selector / finiteness test* (off the derivative) → no smoothing; make
   it **read the value and never throw on an active intermediate**, fixed once at
   the operation's definition, not per call site.
3. *Event in time* (a reset, switch, or clamp that **activates mid-trajectory**
   and changes trajectory structure) → **do not smooth** (that trades a kink for
   stiffness). Use hybrid-systems sensitivity: locate the event time `t*` by a
   root-find on the event function (§2) and propagate the derivative jump across
   it with the **saltation matrix**. Without it, gradients through any trajectory
   that crosses a reset are wrong however smooth everything else is.

**Two traps.** A subgradient is safe when the trajectory crosses the kink on a
measure-zero set, but **dangerous when the solution sits on it over a finite
region** (an active clamp) — there the one-sided choice is a *modelling decision*
and must be made deliberately, matching the physically meaningful limit. And
piecewise-*constant* selections (argmax over discrete alternatives, table branch
selection) have **zero derivative almost everywhere** — the tape is not
ill-conditioned, it is *blind*; if that dependence matters you need a softmax-style
relaxation or a stochastic estimator, not smoothing.

---

## 6. Derivative of a reconstructed field at an evolving query point

**Abstract.** A field is reconstructed through sample points (e.g. a spline) then
queried at a point that is itself an evolving ODE state. Two derivative channels:
w.r.t. the **fitted data** (wanted), and w.r.t. the **query location** (the
interpolant's analytic tangent).

**Why naive AD fails.** An interpolant with value error `O(Δᵖ)` has slope error
`O(Δᵖ⁻¹)` **with oscillating sign**; when the query point is an evolving state,
that slope error enters the variational (adjoint) equation as a perturbation to
the flow Jacobian and **integrates secularly** — which is why the pathology grows
with horizon while the forward value stays fine (a purely recorded-derivative
failure, invisible to a value check).

**Technique — freeze by default, then harden.** The default active read
**freezes the query-point derivative** (evaluate at the stripped query value,
carry only the data channel); value-identical, a no-op for the forward pass, and
it cannot silently attach the dangerous tangent. Expose the query-tangent as an
explicit opt-in for the rare well-resolved case. Then: (1) **instrument** — count
frozen query-tangent reads per gradient and surface it, since "value-identical"
means no value test catches a caller who needed the tangent; (2) if a
query-*direction* derivative is genuinely needed, take a **secant over the sample
spacing** (not a sub-grid probe — same `h ~ Δx` rule as §1); (3) structurally, if
the solver consumes `dS/dx` as a value it **deserves its own estimator**, not a
byproduct of the value interpolant (smoothing spline with roughness penalty tuned
for derivative accuracy; joint `(S, dS/dx)` Hermite fit; or fit the derivative
directly). **The reconstruction method is an AD decision, not only an accuracy
decision**: monotone interpolants (PCHIP-type) contain limiters, so their *data*
derivative has §5 kinks; linear-in-data reconstructions (splines, kernel
regression) have exact, well-conditioned data channels for free.

---

## 7. The class-level playbook

**The completeness lesson (the most important one).** When a "correct" quantity
appears **unstable**, first verify it is the **complete** quantity. §1's entire
trilemma was anchored on "the analytic operator is forward-unstable" — taken as a
hard fact and designed around for a long time. It was an artifact: the unstable
object was `∂g/∂x` at *frozen* `S`, an **incomplete derivative** missing
`∂g/∂S·dS/dx`. A dropped term in a feedback system masquerades convincingly as a
stability barrier and costs you a constraint you never actually had. The
transferable diagnosis (the `h ≪ Δx` staircase) survived and reappeared on the
coupling channel exactly as predicted; the phantom barrier did not.

**Correct forward value ⇏ correct derivative.** §1, §4, §6 are value-identical to
the plain run and wrong only on the tape. A gate that checks values, or a single
short trajectory, is structurally blind to them. The gate must be a **multi-step
trajectory with the coupling active**, FD-checked.

**Classify by relationship to the derivative, not by site** — into four bins with
fixed treatments, attached to the operation's *definition* (never the call site):
- **replaceable** (numerical derivative standing in for an available exact one) →
  substitute the exact object;
- **deliberately modified** (stabilization that defines the solution) →
  differentiate the modified equation, or freeze with a ledger entry;
- **opaque solve** (iteration to a mathematically characterized point) → IFT /
  Danskin injection;
- **event** (trajectory-structure change) → root-find + saltation.

**The bias ledger.** Every freeze/surrogate is a controlled inconsistency. For
each, record four things: the dropped term; its known scaling (with coupling
strength, horizon, tolerance, `ε`); a cheap **standing** diagnostic that monitors
it; and the consistent-but-expensive fallback it can be compared against on
demand. This turns "argued small, not assumed zero" from a principle into a
practice and leaves an audit trail.

**Verification at three levels** (they catch different failures):
- **dot-product test** `⟨Jv, w⟩ = ⟨v, Jᵀw⟩` — the tape is internally
  self-consistent; catches seam bugs but will happily validate a consistent tape
  of the *wrong* (staircase) function;
- **finite-difference check at the macroscopic scale** — θ-step large enough to
  jump the sub-grid ripple; verifies the gradient is the *useful* one (tightening
  the FD step until it matches the exact tape is the classic self-deception);
- **refinement test** `∇M_h` vs `h`, tolerance, `ε` — verifies gradient
  consistency directly; the only test that detects a diverging Lipschitz constant
  before it bites.

**Hidden-seam checklist for a time-dependent solver:** adaptive step-size
controllers (accepted-step sequence depends discontinuously on `θ` → freeze the
sequence, differentiate at fixed steps; bias vanishes with tolerance, taping the
controller yields garbage); inner linear solves with tolerances (§2 in disguise);
mesh adaptation / remapping (freeze the sequence); lookup tables (§6); norms /
`abs` in error estimators (§5 on a derivative-consumed path); any stochastic
element (fix the random stream across θ-perturbations — common random numbers — or
FD references measure resampling noise).

**Regime boundary — chaos.** If the dynamics are chaotic over the horizon, *no*
seam repair helps: `∇M_h` becomes exact and useless simultaneously, adjoint norms
grow exponentially, and the meaningful object is the derivative of long-time
statistics (least-squares shadowing, NILSS, ensembles). Cheap standing test:
**adjoint-norm growth vs horizon**, run before trusting any long-horizon gradient.

---

## 8. Rethinking the assumptions — two global alternatives

The catalog's implicit commitment is *bit-identical forward solve, discrete
adjoint, surgically repaired seams* — the right default when the forward solution
is validated and near-machine-precision gradient accuracy matters. Two coherent
alternatives are worth knowing.

**Differentiate-then-discretize (continuous adjoint).** Derive the continuous
adjoint ODE/PDE once and discretize it with its own stable scheme. *Every* tape
pathology vanishes simultaneously — there is no tape. Price: a gradient consistent
with the continuum, not with the computed solution (`O(discretization)` bias,
failure of discrete gradient checks, dual-consistency caveats at boundaries and
coupling terms). Dominates when the solver is legacy or non-differentiable, when
discretization error already exceeds the needed gradient accuracy, or when the
seam count is unmanageable. Hybrid: dual-consistent forward schemes (SBP-SAT,
adjoint-consistent DG) make the discrete adjoint *be* a consistent discretization
of the continuous one — both properties at once, at the cost of constraining the
forward scheme.

**Change the objective so the exact derivative is the useful one.** §1 showed the
ill-conditioned gradient was the *true* derivative of a rough `M_h`. Instead of
repairing the tape, smooth `M_h` itself — widened regularization matched to the
grid scale (the modified-equation route), or **randomize** the discretization
(dithered stencil offsets, perturbed optimizers, Gumbel relaxations for discrete
choices) so the pathwise exact gradient is an unbiased estimator of `∇E[M]`, which
is smooth. Dominates when the roughness is intrinsic to the problem class (shocks,
discrete selections, near-chaos) rather than an artifact of one careless stencil.

**They compose:** a discrete adjoint with repaired seams for the smooth core, a
saltation treatment at events, and an averaged objective for one irreducibly rough
channel. The unifying discipline is the same everywhere: **decide what
mathematical map you mean at each boundary, and make the derivative the derivative
of *that*.** The tape is a bookkeeper; it can only ever be as meaningful as the
maps you hand it.
