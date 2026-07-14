# Differentiating a self-coupled field read: a first-principles recount

A domain-agnostic problem statement for the Oracle. Supersedes
`oracle-coupling-secant.md` (kept as the running log). No application knowledge is
assumed. The prior statements accreted around one candidate mechanism after
another; this one restarts from the requirements and lets the mechanism be open.

---

## Part 1 — Requirements (built before any mechanism)

The task is a **reverse-mode automatic-differentiation gradient** `dM/dθ` of a
scalar functional `M` of the end state of a coupled ODE solve, w.r.t. a vector of
model parameters `θ`. Requirements as *outcomes*, each with a quantity:

- **R1 — correctness across all parameter classes at once.** The reverse gradient
  must match a converged finite difference to within **≈5% relative** for *every*
  component of `θ`, in a single sweep. Parameters fall (emergently, not by
  declaration) into two classes that stress the same term oppositely:
  - *trajectory-moving* (a.k.a. direct-effect): the parameter strongly moves a
    body's own path through state space (`dx/dθ` large);
  - *coupling-only*: the parameter's entire effect on `M` is routed through the
    shared field; its direct effect on any body's own dynamics is ~0 (`dx/dθ ≈ 0`).
    A coupling-only parameter with true sensitivity ≈0 is a **null channel**: any
    spurious term appears at full magnitude and sign against a true value of ~0.
- **R2 — the differentiated solve must be numerically stable** (its forward
  trajectory must not diverge from the undifferentiated one). This is a real
  constraint, not a mechanism: the naive exact discretization of the term in
  question is a *centred* scheme for a hyperbolic transport equation, which is
  unstable on the coarse grid actually used; the stable scheme is *upwind*
  (one-sided). So the VALUE of the term is fixed by a stability-mandated
  discretization, and only its θ-**derivative** is free to be chosen. Quantity:
  the forward solve must reproduce the recorded trajectory bit-for-bit.
- **R3 — per-step and local.** The fix must be a per-step, per-body local
  computation. The error is already visible with a **single body and one step** —
  it is not an emergent multi-body or long-horizon effect (measured, Part 3). No
  global assembly, no cross-step bookkeeping. Quantity: the shared field is a
  `k`-knot spline, `k ≈ 17`, one field read per body per step.
- **R4 — no per-parameter hand-classification.** The gradient is taken over all of
  `θ` simultaneously through one tape; the fix cannot branch on "is this parameter
  direct or coupling-only" because that label is not available at tape-record time
  and is itself parameter- and state-dependent.

**Challenged upward (requirement vs mechanism):** "keep the finite-difference
value but inject an analytic derivative" — as stated in earlier drafts — is a
*mechanism*, not a requirement. Stripped to outcomes it is exactly R2 (stability
fixes the value) **+** R1 (correctness fixes the derivative). We keep it in that
form and let the mechanism for the derivative be the open question.

**Scarce resource (derived from R1+R3+R4):** a *single* numerical object — "the
slope of the reconstructed shared field, read at a body's own moving coordinate" —
must carry a θ-sensitivity that is **simultaneously** consistent for coupling-only
parameters and inert for trajectory-moving parameters, with **no per-parameter
switch** and **no non-local information**. Every failed approach so far is a
different way of making that one object right for one class and wrong for the
other.

---

## Part 2 — The problem, from first principles

### The setup

`N` bodies (particles / characteristics) integrate an ODE. They do **not** interact
pairwise; they couple **only** through a shared, low-dimensional field `S`,
**reconstructed each step from all bodies** (a `k`-knot spline; knot positions are
frozen `double`, knot values `c` carry θ). Each body reads `S` at its **own
coordinate** `x`, and each body also **contributes to** the knots that build `S`.
That last fact — *the query point is itself a source of the field it queries* — is
the structural feature this recount wants to foreground.

A body's rate law needs the **total spatial derivative** of its velocity `g` along
its own coordinate:

```
D  =  dg/dx  =  ∂g/∂x|_S  +  ∂g/∂S · (dS/dx)
```

`∂g/∂x|_S` (fixed-field partial) is exact by forward-over-reverse and settled.
`dS/dx` is the **slope of the shared field at the body's coordinate** — the
coupling channel. Its *value* is taken as a secant of the reconstructed field and
is settled (R2: it is the stability-mandated upwind stencil). The open object is
its **θ-sensitivity**, `d(dS/dx)/dθ`, which the reverse sweep needs.

### Why `d(dS/dx)/dθ` is the whole problem

`M`'s dependence on `θ` flows through two kinds of term: rates that integrate `g`
(a body's *position*), and rates that integrate `D = dg/dx` (a *transport* /
density-like quantity). The measured localization (Part 3) is sharp: the
position-integrating outputs are **machine-exact** for every parameter, while the
transport-integrating outputs carry the entire error. So `∂g/∂x|_S` and everything
about `g` itself are correct; the error lives **only** in `d(dS/dx)/dθ`.

### The mechanism of the error (what we now believe is really happening)

Decompose `d(dS/dx)/dθ` at the body's coordinate `x` into an **Eulerian** (field
changes at fixed `x`) and a **query-motion** (the body's `x` moves) part:

```
d(dS/dx)/dθ  =  ∂(dS/dx)/∂θ|_x        [Eulerian: Σᵢ (∂/∂θ of the slope basis)·dcᵢ/dθ]
             +  ∂(dS/dx)/∂x · dx/dθ    [query-motion: field curvature × body motion]
```

The empirical finding (Part 3) that reframes everything: for a **trajectory-moving**
parameter, the Eulerian leg is **large and spurious** (it drives the ~10×
overshoot), while there is **no matching well-conditioned partner** to cancel it
(the field's analytic curvature at the read point is ~9 orders of magnitude too
small — the field is locally near-linear). For a **coupling-only** parameter the
Eulerian leg is **small and genuine** and the body barely moves, so nothing needs
cancelling.

The structural suspicion, from "the query is its own source": the spurious Eulerian
leg is the body reading **its own contribution** to the field slope. The field near
a body's coordinate has a sharp feature *because that body is there*; when a
trajectory-moving parameter shifts the body, the reconstructed field's slope at the
**frozen** query coordinate sees that self-feature sweep past — a large
`∂(dS/dx)/∂θ|_x` that is an artifact of self-reference, **not** a real change in how
the *other* bodies couple to this one. The genuine coupling signal (how the rest of
the field shades this body) is small, which is why simply **dropping** the whole
θ-sensitivity is nearly exact for trajectory-movers and catastrophic for
coupling-only parameters (whose only signal it is).

### The question

Is there a **local, per-step, parameter-agnostic** construction of `d(dS/dx)/dθ`
that carries the genuine coupling sensitivity (correct for coupling-only
parameters) while **not** carrying the self-reference artifact (inert for
trajectory-movers) — *without* classifying parameters and *without* non-local
state?

Concretely, we want to know whether the right object is one of:
1. **A field read that excludes the query body's own contribution.** Reconstruct
   `dS/dx` (for the *derivative* channel only) from a field built from *all bodies
   except the querying one* — a leave-one-out / self-consistent-field split — so
   the self-feature that sweeps past under `dx/dθ` is structurally absent. Is this
   the principled meaning of "coupling," and does leave-one-out have a known
   correct adjoint here?
2. **A Lagrangian (material) formulation** that differentiates the slope *following
   the body*, so the Eulerian self-sweep and the query-motion combine into a single
   material rate — but with the correct partner (the earlier attempt used the
   field's analytic curvature as that partner and it was numerically absent; is
   there a different, correct material construction?).
3. **A change of the coupling variable** so that the quantity taped is one whose
   θ-sensitivity is intrinsically free of the self-reference (e.g. couple through
   the knot vector `c` with stored analytic partials `∂(rate)/∂c` and
   `∂c/∂(body state)`, rather than through a slope read at the body's own moving
   coordinate).
4. **Something the requirements imply that we have not seen** — the recount is
   deliberately not committing to a mechanism.

---

## Part 3 — Experimental results (measured, this system)

All figures are reverse- or forward-mode AD vs a converged central finite
difference, on a record/replay solve with a pinned step schedule (introduction
times are `double` constants; the derivative is of the fixed-schedule model).
Forward-mode JVP equals reverse-mode VJP to machine precision throughout — this is
a genuinely dropped/ill-conditioned *term*, identical in both modes, not a
mode-asymmetry bug. Forward values are bit-identical under every derivative
treatment; only the recorded derivative changes.

### 3a. The error is per-step and single-body; it lives only in the transport term

One body, one recorded segment. `metric=position` integrates `g`;
`metric=transport` integrates `D = dg/dx`.

| parameter (class) | position metric | transport metric |
|---|---|---|
| direct #1 (trajectory-moving) | ✓ exact, rel 6e-9 | ✗ **−557 vs −48 (10.7×)** |
| direct #2 (trajectory-moving) | ✓ exact, rel 3e-9 | ✗ **617 vs 62 (8.9×)** |
| coupling-only (null channel) | ✓ ~0 | ✓ −0.322 vs −0.320 (0.7%) |

Position is machine-exact for the trajectory-movers, localizing the entire error to
`d(dS/dx)/dθ`. No multi-body or long-horizon effect is needed to see it.

### 3b. The leg decomposition — why the spurious term has no local partner

At the querying body's own coordinate after one segment (the body is the "tallest",
so the field value there is at its open ceiling, `S=1`, and `dS/dθ ≈ 0` — the body
is essentially uncoupled *in value*, yet the slope's θ-sensitivity is enormous):

| parameter | `dx/dθ` | slope value | Eulerian leg `∂(dS/dx)/∂θ|_x` | query-motion leg (analytic curvature × `dx/dθ`) |
|---|---|---|---|---|
| direct (trajectory-moving) | 87.6 | 0.368 | **326.9** | **2.5e-7 ≈ 0** |
| coupling-only | ~0 | 0.368 | 37.0 | ~0 |

The analytic field curvature at the read point is `≈2.8e-9`; a curvature-based
material-derivative cancellation would need `≈326.9/87.6 ≈ 3.7` — off by nine
orders. The field is locally **near-piecewise-linear** (curvature ~0) yet its
**slope is strongly parameter-sensitive**, because the sharp self-feature moves. A
near-linear segment unties curvature from slope-sensitivity, so the advective
identity `Eulerian = −curvature·dx/dθ` does not hold for this field.

### 3c. What every attempted treatment does (all measured)

| treatment of `d(dS/dx)/dθ` | trajectory-movers | coupling-only (null channel) |
|---|---|---|
| **drop it** (detach θ) | ✓ 0.03–3.5% | ✗ **40–200×, wrong sign** |
| **keep, secant over sub-grid step** `h≪Δx` | ✗ **~2.3–10× overshoot** | ✓ 5–7% |
| **keep, secant over a fixed larger step** `Δx` | mixed | ✗ 40× |
| **keep material derivative, analytic curvature partner** | ✗ **~10× (partner ≈0)** | ✓ ~5% |

Every row is right for one class and wrong for the other — the scarce-resource
statement made concrete. Multi-body census gradients inherit this exactly: on the
production two-cohort metric, dropping gives trajectory-movers to ≤0.5% and
coupling-only 40–200× off; keeping gives coupling-only ≤7% and trajectory-movers
2.3× off.

### 3d. Facts an answer can rely on

- The fixed-field partial `∂g/∂x|_S` and the coupling **value** `dS/dx` (secant)
  are correct and settled; only `d(dS/dx)/dθ` is open.
- The querying body **contributes to** the field it reads (self-reference).
- The discriminant between "genuine" and "spurious" Eulerian leg is `dx/dθ` (how
  much the parameter moves the querying body), but `dx/dθ` is not available as a
  per-parameter switch at tape-record time (R4).
- The field is a small-`k` (~17) spline; knot positions frozen `double`, only knot
  values carry θ.
- Null-channel readout is the cleanest gate: a coupling-only parameter with true
  sensitivity ~0 shows any spurious/dropped term at full magnitude and sign
  (observed **−0.32** true; a dropped term reads **≈66**).
