# Reverse-mode gradient through a state vector that grows mid-integration

> **RETRACTED — misdiagnosis.** The "growing-state / mid-integration append"
> framing below was wrong. A tangent-connectivity probe and a null-channel FD
> check localized the actual bug to the **frozen coupling secant** in the density-
> transport term (`d(dE/dh)/dθ` dropped) — i.e. **component 1 of
> `oracle-transport-adjoint.md`**, its documented bias-ledger "open" item, *not*
> the append. Evidence: single-cohort (no append at all) `d(log_density)/d(k_I)`
> is spuriously 66 with the secant's θ-sensitivity detached and machine-exact
> (−0.32) with it kept. The append was a red herring — it only changed which
> metric's coupling exposed the pre-existing frozen-secant error. The tradeoff is
> fundamental: detach → direct-effect params exact, coupling-only params wrong
> (missing edge); un-detach at the sub-grid step → coupling params good,
> direct-effect params 2.3× (the `eps≪Δx` staircase); no single secant step fixes
> both. This document is kept only as a record of the eliminated hypothesis; the
> live problem is component 1's open residual. Do not send this to the Oracle.

---

A self-contained problem in differentiable numerical methods. No application
knowledge is assumed. Companion to `oracle-transport-adjoint.md` (a different,
resolved problem in the same solver).

## Setup

Method-of-lines integration of an ODE system. The state vector `y(t)` represents
a set of **bodies** (particles / characteristics). At a set of **known times**,
new bodies are **appended** to `y` — the state vector *grows during the
integration*. Bodies do not interact pairwise; they couple **only through a
shared low-dimensional field** `S`, reconstructed each step from all currently
live bodies (concretely: `S` is a `k`-knot spline fit through the bodies, with
`k` fixed and small, e.g. ~17; each body reads `S` at its own coordinate, and
contributes to the knots that build `S`). We want the gradient of a scalar
functional `M(y(T))` with respect to parameters `θ`, by **reverse-mode automatic
differentiation** (run with an AD scalar type, tape the solve, one reverse
sweep). The append schedule is **recorded on a prior plain-`double` pass and
replayed fixed** (introduction times are constants, not differentiated).

## Symptom

- **All bodies present from t=0 (no mid-run append):** the reverse gradient is
  **machine-exact** (rel ~1e-13) for *every* parameter, coupling fully active.
- **Bodies appended mid-run (the production schedule):** the gradient is
  **wrong — but only for parameters whose effect is routed through the coupling
  field.** A parameter with a large *direct* effect on a body's own dynamics
  looks fine (its error is swamped); a parameter whose *true* sensitivity is
  ~0 (an analytic cancellation) shows the error as **pure spurious signal** —
  wrong sign, orders of magnitude too large. Intermediate cases sit in between
  (tens of percent).
- The **forward values are bit-identical** in all cases, and **forward-mode JVP
  equals reverse-mode VJP to machine precision.** The tape is internally
  self-consistent: it is a consistent adjoint of a subtly *wrong* function.

The single variable that flips the gradient between exact and wrong is **whether
a body is appended mid-integration or the set is fixed from the start.**

## Ruled out (each by a one-line experiment)

- **Field-query derivative handling** — freezing vs carrying the field's
  derivative at a body's own coordinate: unrelated (freezing is correct; carrying
  it reintroduces a *different*, known compounding error).
- **Field-reconstruction resolution** — tightening the spline tolerance 10⁴×
  leaves the spurious term **unchanged**; it is resolution-independent, not an
  interpolation-accuracy effect.
- **The field's algebraic inversion in isolation** — the step that recovers the
  physical coupling variable from the reconstructed field cancels correctly on
  the tape when tested standalone (residual ~1e-2, not the observed ~10²×).
- **Memory reallocation** — the state vector's capacity is **pre-reserved** to
  its final size, so the per-append growth never reallocates; existing elements
  keep their storage and their tape slots.
- **Leaf sharing** — all bodies alias one shared set of parameter leaves, so a
  body appended late inherits the already-seeded leaves rather than minting fresh
  disconnected ones.

So: deterministic replayed schedule, reserved memory, shared leaves, correct
per-step field handling — and still, *appending to the taped state vector
mid-recording* corrupts the cross-body coupling adjoint, while direct
sensitivities and the entire no-append case are exact.

## What two prior implementations did (both imperfect)

1. **Record/replay on a pinned schedule, joint growing state, shared leaves.**
   Exact when coupling is OFF (the field is frozen to recorded values → no
   cross-body derivative). When coupling is ON, it carries a small "accepted"
   residual (~0.1%) that was attributed to finite-difference noise — plausibly
   this same bug, undiagnosed because the validated metrics had large direct
   components that swamped it.
2. **Per-body replay on a frozen schedule.** Replay each body's *fixed-size*
   trajectory independently (no joint growing vector — the tape is straight-line
   per body), and couple only through the shared field reconstructed from all
   bodies. This **avoids the growing-state tape entirely**, but pays a **~20–30%
   accuracy gap** (the gradient is of the frozen-schedule model, not the adaptive
   one) and becomes **stiff/unstable at long horizons or strong coupling** (it
   reuses frozen step sizes where the adaptive forward solve would have
   sub-stepped).

## The questions

1. In reverse-mode AD over a method-of-lines solve where the **state vector grows
   mid-integration** (append at known times, memory reserved, leaves shared), is
   appending to the *taped* state vector mid-recording a **known hazard** for the
   reverse sweep — specifically one that corrupts the **cross-component coupling
   adjoint** while leaving direct sensitivities intact? What is the mechanism, and
   what is the correct handling?
2. Concretely, what must be true of the tape when `y` grows so the reverse sweep
   correctly attributes adjoints across the append boundary — e.g. must the
   append be expressed as an explicit taped operation (a "gather" from the pre-
   append state plus a birth term) rather than a resize-then-overwrite of the
   working vector? Is a resize-then-copy of a vector of AD scalars (existing
   elements re-assigned from the system, new elements appended) a place where
   cross-element adjoint linkage is silently dropped even with storage pinned?
3. Is the **per-body fixed-size replay** (workaround 2) the principled answer
   despite its accuracy and stiffness costs — i.e. is a growing-state reverse
   sweep fundamentally the wrong shape and one should always reduce to
   fixed-size per-body tapes coupled through the shared field? Or is there a way
   to keep the single joint growing-state tape and obtain an exact coupling
   adjoint?

## Facts an answer can rely on

- No-append case: exact to machine precision, coupling fully active — so the
  coupling physics and the reverse machinery are both correct in isolation.
- The error appears *only* with mid-integration append *and* live coupling; it
  is invisible with append-but-no-coupling and with coupling-but-no-append.
- Forward values bit-identical; JVP == VJP to machine precision (not a
  forward/reverse asymmetry — a genuinely dropped dependency, identical in both
  modes).
- Memory reserved (no reallocation), append schedule deterministic and replayed,
  parameter leaves shared across bodies.
- The append is currently implemented as: grow the system's body set, then
  `resize()` the solver's working state vector and **copy the whole system state
  into it** (existing bodies re-assigned, new body's birth state written), then
  continue stepping the joint vector.
