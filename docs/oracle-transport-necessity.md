# Is the transport-term derivative necessary, or an artifact of the state representation?

For the same two respondents. Domain-agnostic; no application knowledge assumed.
Narrow scope by design: this is *only* about one term — the spatial derivative of
the velocity — and whether the reverse-mode gradient must form its θ-sensitivity at
all. We now suspect the boundary of the problem is where the solution lives: two
structural features (a one-sided aggregate, and a choice of density variable) have
not been used, and either may dissolve the term rather than tame it.

---

## 1. The bounded object

A linear transport (conservation) law with nonlocal coupling, solved by the method
of characteristics:

```
∂ₜ n(x,t) + ∂ₓ[ g(x,S) · n ] = − r(x,S) · n,      x > x_b   (influx at the boundary x_b)
S(·,t) = ψ(A(·,t)),   A(z,t) = ∫_{x ≥ z} κ(z,x) · n(x,t) dx        (ONE-SIDED aggregate)
```

`n` is a density over a coordinate `x`; `g` is the velocity (advects `x`), `r` a loss
rate; `S` is a low-rank reconstructed **coupling field** (`k ≈ 17` knots, `ψ = exp`)
built from a **one-sided** aggregate — only sources with `x ≥ z` contribute at `z`.
Characteristics `xᵢ(t)` solve `dxᵢ/dt = g(xᵢ, S(xᵢ))`; they are introduced at `x_b`
on a fixed schedule and the set grows. We want the reverse-mode gradient `dM/dθ` of a
functional `M`, and the functionals that matter are **moments**: `M = ∫ φ(x) n dx`.

Along a characteristic the density obeys `d(ln n)/dt = −(∂ₓg + r)`. **`∂ₓg` — the
spatial derivative of the velocity, the compression term — is the entire difficulty.**
Everything else (the fixed-field partial, the field *value* read) is settled. The open
object is `d(∂ₓg)/dθ`, and it carries a self-interaction: because a characteristic is
both a source of `S` and a reader of `S` at its own moving coordinate, `∂ₓg` inherits
the field *slope* `∂ₓS(xᵢ)`, and differentiating that produces a self-force term.

## 2. Why the standard adjoint repair fails here (measured)

The natural fix — put `∂ₓg` on the tape as one consistent construction (a secant of
the reconstruction at the active query, both the knot channel and the query-motion
channel live) so that the two halves of the self-interaction cancel — **does not
cancel in this system.** Writing the self-block as `source-motion` (the source's own
contribution moving) plus `query-motion` (the reader riding over its own imprint),
the prediction was that they sum to a benign `O(k/N)` residual. Measured, on a small
ensemble, against a converged finite difference:

- the pure knot channel (query frozen) already over-shoots a trajectory-moving
  parameter by **+2.3×**;
- adding the query-motion channel makes it **worse** (**+3.4×**) — *same sign* — while
  driving a coupling-only (null-channel) parameter to machine-exact.

So the two halves **add, they do not cancel**; the one term that is `+` for a
trajectory-mover is simultaneously the *entire* correct signal for a coupling-only
parameter. Only a full self-consistent finite-difference rebuild (advance the
characteristic *and* rebuild the field with the source at its new position) makes them
cancel — i.e. the cancellation is a property of the forward map, not reproducible by
any pointwise treatment of `∂ₓg` on the tape we have. Conclusion: **faithfully
differentiating `∂ₓg` is likely the wrong boundary.** Hence the two questions below.

## 3. Reframe A — the transport term is a property of the density *variable*, not the model

`∂ₓg` appears only because we transport `ln n`, whose ODE contains it. It is absent
from the *model*: neither the coupling field nor a moment functional contains `∂ₓg`.

Track instead a **conserved weight** per characteristic, `Nᵢ`, the number carried by
the characteristic (its Jacobian-times-density, `Nᵢ = nᵢ · Jᵢ`, `Jᵢ` = local
characteristic spacing). Then:

```
dxᵢ/dt = g(xᵢ, S(xᵢ))                 (unchanged)
dNᵢ/dt = − r(xᵢ, S(xᵢ)) · Nᵢ           (loss only — NO ∂ₓg)
A(z,t) = Σ_{xⱼ ≥ z} κ(z, xⱼ) · Nⱼ      (the aggregate needs only weights + positions)
M      = Σ φ(xᵢ) · Nᵢ                  (a moment needs only weights + positions)
```

`∂ₓg` has vanished from the state, the field, and the functional. It was carrying the
compression of the density; that compression is now represented *geometrically*, by
the characteristics converging or diverging (`d(xᵢ₊₁−xᵢ)/dt = g(xᵢ₊₁)−g(xᵢ)`, a
velocity *difference*, never a derivative). The field is identical (same aggregate,
now over weights), and moments are identical.

**The claim we want checked.** In this representation the coupling field is read
**only as a value** — `g` and `r` see `S(xᵢ)`, never `∂ₓS`. The reverse gradient of
`M` flows through `dxᵢ/dθ`, `dNᵢ/dθ`, and the field's value-sensitivity
`∂S/∂θ|_{positions fixed}` (the knot channel — well-conditioned, and the part already
settled). The field slope `∂ₓS(xᵢ)` still appears, but **only as a coefficient** in
the position adjoint's Jacobian `∂g/∂xᵢ = ∂g/∂x|_S + ∂g/∂S · ∂ₓS(xᵢ)` — used, never
*differentiated with respect to θ*. The pathological object was `d(∂ₓS)/dθ`; it does
not occur. So the self-force, the staircase, the whole `dg/dh` derivative problem
would be **eliminated by construction**, not repaired.

This is the crux question: **is that correct, and if so what is the catch?** Candidate
catches we can see, and want adjudicated:
1. Does anything in the model genuinely need the *pointwise* density `n` (not a
   moment) — a rate that reads `n(xᵢ)`, or a functional that is not a moment? If so
   `n = N/J` needs the spacing `J` (from positions) — still no `∂ₓg`, but a new
   position-difference object enters; is *its* θ-sensitivity benign?
2. The boundary influx sets `Nᵢ` at introduction from the birth flux `B(τᵢ)`; if `B`
   depends on the field or the boundary density, does a boundary term reintroduce a
   slope?
3. Is the position adjoint's use of `∂ₓS(xᵢ)` *as a coefficient* genuinely benign
   (a value, well-conditioned), or does the self-consistency (`xᵢ` is a source of the
   very `S` whose slope it reads) make even the coefficient ill-posed — i.e. does the
   self-force merely move from the transport term into the position adjoint rather
   than vanish? Our reasoning says it is one derivative order lower (slope-as-value,
   not slope-differentiated) and therefore fine, but this is the load-bearing step.

## 4. Reframe B — the one-sided aggregate, so far unused

The aggregate is **one-sided**: `A(z) = ∫_{x ≥ z} κ n dx`. Two consequences we have
not exploited:

- **It explains why the self-interaction is a pure *slope* phenomenon.** By Leibniz,
  `∂ₓA(z) = −κ(z,z) n(z) − ∫_{x ≥ z} ∂ₓκ · n dx`. The first term is a **boundary term
  at `x = z`** — a source sitting exactly at the lower edge of its own support. So a
  characteristic's contribution to the field *value* at its own position is negligible
  (it is at the edge, with nothing of itself above), while its contribution to the
  *slope* is the full edge term. This is exactly what we measure (field value ≈ open at
  the reader; the self-imprint is entirely in the slope) and exactly why differentiating
  the slope produced a self-force while the value read was always clean. In Reframe A
  the slope is never differentiated, so this boundary term never appears — corroborating
  that the transport-term derivative is the whole disease.

- **It offers an *exact*, structural leave-one-out, if a slope is ever needed.** Since a
  source contributes to `A(z)` only for `z ≤ xᵢ`, reading or differencing the field from
  the **excluding side** (`z → xᵢ⁺`, above the source) removes that source's own
  contribution *by the support of the kernel*, with no downdate, no reconstruction
  surgery, no mask. The one-sidedness makes "the field of everyone above me" the
  natural quantity a characteristic couples to. We have been reconstructing this
  clumsily (knot-level downdates that also delete the genuine coupling); the kernel's
  own support may give it for free — and it aligns the self-exclusion with an
  upwind/one-sided read direction rather than a symmetric secant.

## 5. The narrow questions

1. **Is Reframe A valid** — does moving the density variable from transported `ln n`
   (which contains `∂ₓg`) to a conserved weight `N` (which does not) yield the *same*
   `M` while eliminating the transport-term derivative from the reverse pass entirely?
   Is the system then coherently differentiable through **value-only** field reads?

2. **Is question 3.3 the real risk** — does the self-force truly vanish, or does it
   reappear in the position adjoint through `∂ₓS(xᵢ)` as a coefficient? Precisely: is
   using the field slope as a linearization coefficient (not differentiating it)
   well-conditioned even though the reader is a source of that field?

3. **Does the one-sided support give exact self-exclusion** (`z → xᵢ⁺`) wherever a
   slope or field-derivative is genuinely required — as a structural identity rather
   than a numerical downdate — and is that the same object as an upwind read?

4. **If Reframe A is valid, do we ever need `∂ₓg` again** — for a non-moment
   functional, a density-dependent rate, or field stability — or can the whole system
   be posed so the compression term is only ever a *derived diagnostic*, never a taped
   quantity whose θ-derivative is required?
