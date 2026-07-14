# Reverse-mode gradients of a structured-population ODE solver: requirements

A self-contained problem statement. No application knowledge is assumed. The goal
is to establish, from first principles, the **complete set of capabilities** a
differentiation layer must provide so that a family of structured-population models
can be differentiated in **reverse mode**, and to ask what the minimal architecture
that delivers them looks like.

---

## 1. The system, abstractly

We integrate a **size- (or stage-) structured population model**: a first-order
transport PDE solved by the **method of characteristics**. Concretely, the state is
a set of **cohorts** (characteristics). Cohort `i` carries a small fixed-width
state vector — a structural coordinate `xᵢ(t)` (e.g. size), a log-density `ℓᵢ(t)`,
and bookkeeping integrals (cumulative reproduction, survival). Their rate laws are:

```
dxᵢ/dt = g(xᵢ, E(t); θ)                         growth
dℓᵢ/dt = −∂g/∂x (xᵢ, E; θ) − μ(xᵢ, E; θ)         density transport + mortality
(plus bookkeeping integrals driven by g, μ, and a fecundity rate f)
```

Three structural facts define the difficulty:

- **The state grows during the solve.** New cohorts are introduced at the boundary
  at a schedule of times; the state-vector dimension increases mid-integration.
- **Cohorts do not interact pairwise. They couple only through one or more shared
  environment fields `E(t)`**, each reconstructed *every step* from the entire
  current population (a low-rank object — a spline / quadrature of an integral over
  all cohorts of their per-cohort effect). Each cohort reads `E` at its own
  coordinate `xᵢ`. Some fields are instantaneous functions of the population; some
  carry their own ODE state (memory).
- **The forward solver is adaptive** (error-controlled step size and cohort
  spacing).

We want the gradient `dM/dθ` of a scalar functional `M` of the terminal (or
time-integrated) state, w.r.t. a parameter vector `θ`, by **reverse-mode automatic
differentiation** — one tape of the solve, one reverse sweep, all of `θ` at once.

`M` is one of: a **census** functional (a moment of the size distribution — total
biomass, density in a size class) or a **lifetime-fitness** functional (survival-
weighted lifetime reproduction, used for evolutionary invasion analysis).

### Coverage target (why the layer must be general, not bespoke)

The layer must serve **four model variants of increasing rate-law complexity**, and
an **added second coupling field with its own state**. Ordered by what they force
the differentiation layer to handle:

- **Tier A** — `g`, `μ`, `f` are closed-form smooth-ish expressions of `(x, E, θ)`.
  Couples through one instantaneous field. *(The minimal case; must work first.)*
- **Tier B** — the rates come from an intermediate physiological sub-model (several
  chained closed-form maps, more parameters, mild non-smoothness).
- **Tier C** — a rate is defined by an **embedded scalar solver**: an inner
  optimization (optimal trait allocation) or root-find run to convergence inside
  `g`. This inner problem is iterative and its argmin/argmax is not naively
  differentiable.
- **Second field** — add a resource field that is **not** an instantaneous function
  of the population but carries **its own ODE state**, coupled back into the rates.

The differentiation layer is written **once**; a model is added by writing its rate
law once (as a scalar-type-generic function) and reusing the layer — **not** by
bespoke per-model adjoint surgery. Tier A is the acceptance gate; C and the second
field are the generality stress tests.

---

## 2. Requirements (tight; scope deliberately narrow)

Only the **gradient capability** of this solver family is in scope. Explicitly out
of scope: the optimizer/estimator that consumes the gradients, model selection,
parallelism, and the forward model's own numerics (taken as given and correct).

- **R1 — Correct reverse gradient, all parameters, one sweep.** `dM/dθ` must match a
  trusted reference to **≤1% relative** (tighter — machine precision — for the
  smooth, uncoupled parameters). Quantity: `|θ|` ≈ 5–20 depending on tier; cohorts
  `N` up to a few hundred; shared-field rank `k` ≈ 15–20 knots.
- **R2 — Independent verification.** The reference in R1 must be computed on a path
  **independent of the reverse sweep** — a forward-mode JVP (`dM/dθ` via tangent
  propagation) and/or finite differences — including a mode that does **not** rely
  on finite differences, because some functionals (`M` integrating exponentials of
  taped states) have no well-conditioned FD.
- **R3 — Forward trajectory preserved.** Turning on differentiation must not change
  the computed trajectory: the active (AD) forward pass must reproduce the plain
  (`double`) solve's values **bit-for-bit**. The gradient must describe the model
  that is actually run, not a nearby smoothed one. *(This constrains how any
  stabilization or smoothing enters: it may change the derivative but not the
  value.)*
- **R4 — One reusable differentiation kit.** Adding a model or a field must not
  require new hand-derived adjoints. The layer exposes a fixed set of primitives;
  each model composes them. Quantity: cost of adding Tier B given Tier A works
  = writing rate laws only, zero new adjoint code.
- **R5 — Reverse-mode cost model.** The gradient for `|θ|` parameters must cost
  `O(1)` forward solves (the reverse-mode win), not `O(|θ|)`. Tape memory bounded by
  `O(state × steps)`; the growing state and per-step field rebuild must not make
  this super-linear.
- **R6 — Every approximation has a named, bounded bias with a diagnostic.** Wherever
  the layer differentiates a *surrogate* instead of the literal operation (see the
  hard components below), the discrepancy must be (a) named, (b) argued small with a
  quantity or scaling, and (c) equipped with a cheap diagnostic that detects when it
  stops being small.

**Scarce resource (derived from R3+R4+R6):** a single differentiation kit must
produce **value-preserving** derivatives for a *heterogeneous* set of numerically
awkward primitives (growing state, reconstructed-field reads, non-smooth clamps,
embedded solvers) — each of which, taped naively, is either wrong or unstable — and
must do so **compositionally**, so that correctness is established per-primitive
once and inherited by every model. The design problem is choosing that primitive
set.

---

## 3. The hard components (comprehensive; what a correct treatment must provide)

Each is a general phenomenon, not model-specific. For the family to be
differentiable, the layer needs a principled, value-preserving, reverse-mode-correct
treatment of **all** of them, composable per R4.

**C1 — Growing state under the tape.** The state vector gains dimensions
mid-integration (cohort introduction at scheduled times). *Needs:* a taping scheme
under which the reverse sweep correctly attributes adjoints across an introduction
boundary — i.e. introduction expressed as an explicit differentiable operation on
the tape (a boundary/birth map), not an opaque resize, and correct linkage between a
cohort's pre- and post-introduction contributions.

**C2 — Adaptive → recorded schedule.** Step sizes and cohort spacing are chosen by
error control; branching on *active* values would poison the tape (the schedule
would spuriously depend on `θ`). *Needs:* record the schedule on a plain pass and
replay it fixed for differentiation. *Accepted bias (R6):* the gradient is of the
fixed-schedule model, not the adaptive one; the schedule's own `θ`-sensitivity is
dropped. Diagnostic + bound required.

**C3 — Coupling through a reconstructed shared field.** Each cohort reads `E` at its
own coordinate; `E` is a low-rank reconstruction from *all* cohorts, rebuilt each
step. The rates depend on both the field **value** and its **spatial slope** (the
transport term `∂g/∂x` includes `∂g/∂E · dE/dx`). *Needs:* the reverse-correct
`θ`-sensitivity of a field read — through the field's dependence on the whole
population's state **and** through the reading cohort's own coordinate — for both the
value and the slope, in a way that does not conflate a cohort's genuine coupling to
the *rest* of the population with artifacts of it being one of the field's own
sources. *(This is the subtlest component; a correct treatment is prerequisite for
any coupled functional.)*

**C4 — Non-smooth primitives.** Rate laws contain `max`/`min`/clamps (rate
positivity, resource floors) and piecewise definitions; their derivative is wrong or
undefined at corners, and cohorts sit on corners with nonzero measure. *Needs:* a
smoothing policy with a controlled scale `ε`, applied so it changes the derivative
near the corner but not the value away from it (R3), with the `ε`-bias named and
bounded (R6).

**C5 — Embedded scalar solvers (Tier C).** A rate is the output of an inner
root-find or optimization run to convergence. Taping the iteration is wrong (its
length/branching are not the derivative) and often non-smooth (argmax). *Needs:*
implicit-function-theorem derivatives for root-finds and envelope-theorem
derivatives for optima — a **supplied-derivative** primitive that replaces the inner
iteration's tape with the analytic sensitivity of its converged solution.

**C6 — Multiple and stateful fields (second field).** More than one coupling field,
at least one carrying its own ODE state (memory), coupled bidirectionally with the
population. *Needs:* the C3 treatment to **compose** over several fields, including
one whose read at time `t` depends on its own past — i.e. the field's adjoint must
flow back through its own dynamics, not just through the instantaneous
reconstruction.

**C7 — Functionals with ill-conditioned references.** Some `M` integrate quantities
that are exponentials of taped states; their finite-difference reference does not
converge (the fixed schedule makes the sensitivity exponentially stiff). *Needs:*
the FD-free forward-JVP reference of R2 as a first-class verification path, not an
afterthought.

---

## 4. The questions

1. **What is the minimal set of primitives** (the "kit" of R4) that covers C1–C7 so
   every model in the coverage target composes them, and correctness is established
   once per primitive? Which components collapse into one primitive and which
   genuinely need their own?
2. For each component, **what is the known-correct reverse-mode construction**, and
   where the literal operation is not differentiable (C1 resize, C2 schedule, C4
   corners, C5 inner solver, C3 field read), **what is the right value-preserving
   surrogate** to differentiate instead — with its bias characterized per R6?
3. **What is the correct taping discipline for the growing state (C1)** in a
   method-of-characteristics solve — is the introduction boundary a gather/birth map
   that must be explicit on the tape, and does a joint growing-state tape admit an
   exact coupling adjoint, or must one reduce to fixed-size per-cohort tapes coupled
   through the shared field?
4. **How should the reconstructed-field coupling (C3) be structured** so a cohort's
   read of a field it helps generate yields a reverse-correct sensitivity to the
   *rest* of the population without a self-reference artifact, and so the same
   structure composes to multiple, possibly stateful, fields (C6)?
5. **Is there a single verification protocol** (R2) — forward-JVP vs reverse-VJP
   agreement, plus a null/insensitive-parameter probe — that certifies each
   primitive and each assembled model, and what are its failure-detection limits?
