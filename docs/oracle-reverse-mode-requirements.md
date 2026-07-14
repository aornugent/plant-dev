# Reverse-mode gradients through a self-consistent coupling field

A domain-agnostic problem statement. No application knowledge is assumed. It fixes
the **requirements** and enumerates the **components** a differentiation layer must
handle to reverse-mode differentiate one specific workflow: a growing ensemble of
characteristics that collectively generate the coupling field they each read back.

---

## 1. The workflow

We integrate a parametrized ODE system forward in time and want the gradient of a
scalar functional `M` of the solution w.r.t. a parameter vector `θ`, by
**reverse-mode automatic differentiation** (AD scalar type substituted for
`double`, tape the solve, one reverse sweep returns `dM/dθ`).

The state is a set of `N` **characteristics** (points). Point `i` carries a small
fixed-width state vector, including a coordinate `xᵢ(t)` that advects under a
velocity, and a transported density `ℓᵢ(t)`:

```
dxᵢ/dt = g(xᵢ, S; θ)                    velocity
dℓᵢ/dt = −∂g/∂x (xᵢ, S; θ) − r(xᵢ, S; θ) transport (compression) + a local loss rate
(+ a few bookkeeping integrals driven by g, r, and other local rates)
```

The one structural feature that defines this workflow — the **self-consistent
coupling field**:

- The points do **not** interact pairwise. They couple **only** through a shared
  field `S(·, t)` — the **environment** — reconstructed **every step from the whole
  ensemble**: `S` is a low-rank object (a `k`-knot spline, `k ≈ 15–20`, knot
  positions fixed) obtained by projecting an integral over **all** points of a
  per-point contribution `φ(xⱼ, stateⱼ; θ)`.
- Each point reads `S` back **at its own coordinate** `xᵢ` — both the **value**
  `S(xᵢ)` and the **spatial slope** `∂S/∂x(xᵢ)` (the transport term needs the
  slope). So **the ensemble generates the field it experiences**: `S` is the
  *resident* field of the ensemble that produced it, and every point is
  simultaneously a **source** of `S` and a **reader** of `S`.

Two more facts of the forward solve, both of which the differentiation must respect:

- **The ensemble grows during the solve.** New points are introduced at a boundary
  on a schedule of times; `N` (and the state-vector dimension, and the source set of
  `S`) increases mid-integration.
- **The solve is adaptive** (error-controlled step size and point spacing).

`M` is a functional of the terminal or time-integrated state (a moment of the point
distribution, or a survival-weighted integral of a local rate).

**Generality target.** The velocity `g`, loss rate `r`, and contribution `φ` range
from closed-form smooth expressions to outputs of an inner sub-model; and the layer
must eventually carry **more than one** field `S`, at least one of which is **not**
an instantaneous function of the ensemble but carries **its own ODE state**
(memory). The differentiation layer is written **once** and reused; a new model or a
new field is added by writing its `g/r/φ` once (scalar-type-generic) and composing
the layer's primitives — not by hand-deriving adjoints.

---

## 2. Requirements (tight; scope narrow)

In scope: the **reverse-mode gradient capability** for this workflow. Out of scope:
the optimizer/estimator that consumes the gradients; the forward numerics
themselves (taken as correct); parallelism.

- **R1 — Correct reverse gradient, all parameters, one sweep.** `dM/dθ` matches a
  trusted reference to **≤1% relative**, machine-precision for parameters that enter
  no coupling term. Quantity: `|θ| ≈ 5–20`; `N` up to a few hundred; field rank
  `k ≈ 15–20`.
- **R2 — Independent verification, including FD-free.** The reference must be
  computed on a path independent of the reverse sweep — a forward-mode JVP and/or
  finite differences — and there must be a mode that does **not** use finite
  differences, because some functionals (integrals of exponentials of taped states)
  have no well-conditioned FD.
- **R3 — Forward trajectory preserved bit-for-bit.** Enabling AD must not change the
  computed trajectory: the active forward pass reproduces the `double` solve's values
  exactly. Any stabilization/smoothing may change a **derivative** but never a
  **value**. The gradient describes the model actually run.
- **R4 — One reusable kit.** Adding a model or a field requires no new hand-derived
  adjoint — only new `g/r/φ`. Correctness is established once per primitive and
  inherited.
- **R5 — Reverse-mode cost.** Gradient for `|θ|` parameters costs `O(1)` forward
  solves, not `O(|θ|)`. Tape memory `O(state × steps)`; neither the per-step field
  rebuild nor the growing ensemble may make this super-linear.
- **R6 — Every approximation named, bounded, diagnosable.** Wherever the layer
  differentiates a **surrogate** rather than the literal operation, the discrepancy
  is (a) named, (b) bounded by a quantity or scaling, (c) equipped with a cheap
  diagnostic that fires when it stops being small.

**Scarce resource (from R3+R4+R6):** a single kit must yield **value-preserving,
reverse-correct** derivatives for the awkward primitives of this workflow — each of
which, taped naively, is wrong or ill-conditioned — and do so **compositionally**.
The design task is choosing that primitive set and, for each primitive whose literal
operation is not differentiable, the right surrogate to differentiate instead.

---

## 3. The components (comprehensive for this workflow)

Each is a general phenomenon. A correct, value-preserving, reverse-mode treatment of
**all** of them, composable per R4, is what "make it work" means. C1–C3 are the
coupling itself; C4–C6 are the enabling machinery the coupling forces.

**C1 — Field value read.** A point's read `S(xᵢ)` depends on `θ` through **the whole
ensemble** (every source's contribution `φⱼ` enters the knots) and through the
point's **own coordinate** `xᵢ`. *Needs:* the reverse-correct sensitivity of a
read of an ensemble-reconstructed field, w.r.t. both channels, without conflating
them.

**C2 — Field slope read (the transport term).** The compression term `∂g/∂x` carries
`∂g/∂S · (∂S/∂x)`; the reverse sweep needs `d(∂S/∂x)/dθ`. The slope of a low-rank
reconstruction read at a moving query is the delicate quantity — its naive
sensitivity is dominated by sub-grid behavior of the reconstruction rather than the
macroscopic field. *Needs:* a well-conditioned, value-preserving construction of the
slope read's `θ`-sensitivity.

**C3 — Self-reference (source = reader).** Because a point contributes to the field
it reads, its read carries a sensitivity to **its own** contribution as well as to
the rest of the ensemble's. A parameter that moves the point strongly can make the
self-part of the read's sensitivity large and artifactual (the point's own imprint
on the coarse field, sweeping past its own frozen read), while the genuine coupling
signal — how the **rest** of the ensemble re-shapes the field around this point —
is what the functional actually needs. *Needs:* a construction that carries the
coupling-to-others sensitivity while not carrying the self-imprint artifact —
**without classifying parameters** (the split is by *source identity*, self vs.
others, a structural label; not by whether a parameter "moves the point").

**C4 — Growing ensemble under the tape.** `N` increases mid-solve; the field's
source set and the state-vector dimension grow at scheduled boundaries. *Needs:* a
taping scheme under which the reverse sweep correctly attributes adjoints across an
introduction boundary — introduction expressed as an explicit differentiable
boundary/birth map, not an opaque resize — and correct linkage of a point's
pre- and post-introduction contributions to the field.

**C5 — Adaptive → recorded schedule.** Step sizes and point spacing are chosen by
error control; branching on active values would make the schedule spuriously depend
on `θ`. *Needs:* record the schedule on a plain pass, replay it fixed for
differentiation. *Accepted bias (R6):* the gradient is of the fixed-schedule model;
the schedule's own `θ`-sensitivity is dropped — bound and diagnostic required.

**C6 — Multiple and stateful fields.** More than one field `S⁽¹⁾, S⁽²⁾, …`, at least
one carrying its own ODE state (memory), coupled back into the rates. *Needs:* C1–C3
to **compose** over several fields, including one whose read at time `t` depends on
its own past — so its adjoint flows back through its own dynamics, not only through
the instantaneous reconstruction.

*(Orthogonal seams that also occur in the general target but are not the coupling
workflow — non-smooth rate primitives requiring controlled smoothing, and inner
root-find/optimizer rates requiring implicit-function/envelope supplied derivatives
— compose with the above through the same "differentiate the mathematics, not the
code" discipline and are out of scope for this statement.)*

**Verification (spans all).** Per R2: forward-mode JVP must equal reverse-mode VJP to
machine precision on every primitive and every assembled model (this certifies the
adjoint is a consistent adjoint of *something*), plus a **null-parameter probe** — a
parameter whose true sensitivity is analytically ~0, so any spurious or dropped term
appears at full magnitude and sign — as the sharpest correctness gate for C1–C3.

---

## 4. The questions

1. **What minimal set of primitives** covers C1–C6 so every model and field composes
   them and correctness is established once per primitive? Which components collapse
   into one primitive and which genuinely need their own?
2. For C1–C3 — the read of a **self-consistent field** — **what is the reverse-correct
   construction** of the value and slope sensitivities that carries coupling-to-others
   while excluding the self-imprint artifact, by source identity and without
   parameter classification? Is the field read best structured as an explicit
   low-rank node (the knot vector) with stored analytic partials `∂(read)/∂(knots)`
   and `∂(knots)/∂(source state)`, so a source can never route its own sensitivity
   into its own read?
3. **What is the correct taping discipline for the growing ensemble (C4)** — is the
   introduction boundary a gather/birth map that must be explicit on the tape, and
   does a joint growing-state tape admit an exact coupling adjoint, or must one reduce
   to fixed-size per-point tapes coupled through the shared field?
4. **How does the C1–C3 construction compose to multiple, possibly stateful, fields
   (C6)** without re-deriving adjoints per field?
5. **What is the tightest verification protocol** (JVP=VJP agreement + null-parameter
   probe) that certifies each primitive and each assembled model, and what are its
   detection limits?
