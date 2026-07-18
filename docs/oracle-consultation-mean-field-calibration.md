# A forward map from a parametric dynamical generator to a nonlinear observable, and the reformulation that makes it invertible from single realizations

A question in applied mathematics and scientific computing. No application domain is named and no solution
method is assumed; the generating mechanism is described **only through the computations it exposes**, at a
level that names neither an application nor a technique — we want you to supply the technique and to
re-derive the right formulation from the structure. It is self-contained (assume no earlier context).
If we are reasoning about the wrong object, say so.

**What this request is for (so the depth is aimed correctly).** We have a parametric mechanism whose
parameters `θ` we cannot set directly; we have abundant, cheap observations that are nonlinear images of
single realizations of the mechanism; and we want to know — foundationally — **when and how `θ` can be
recovered from those observations**, and in particular whether the *dynamical* content of the mechanism can
be recovered from observations of a *single-time* state. We are asking for investigation of the underlying
structure and the reformulation that makes this well-posed, not a ready-made procedure.

## The objects

**A parametric dynamical generator.** For a parameter `θ ∈ ℝ^p` (small; on a known low-dimensional
manifold), a mechanism runs a deterministic dynamics forward from a fixed baseline state and is returned to
that baseline at reset times; a unit's **progress variable** `τ` is the elapsed time since its last reset.
`θ` parameterises the *dynamics* (the rates of the deterministic flow and of its boundary input); it is the
object we want and cannot set directly. Each unit also carries a small per-unit modifier `ε`, fixed within a
unit, varying across units under an unknown law and not observed. The observed ensemble **superposes units
at all values of `τ`** (with density `w(τ)` set by the reset law) and of `ε`.

**A configuration.** A single realization at `(θ, ε, τ)` is a finite set of **items**, each with a scalar
attribute and a position in a spatial domain — a point set `X` in a configuration space `𝒳`.

**Two computable reductions of the law, of very different cost.** Write `μ` for the law of `X` at
`(θ, ε, τ)`.
- **Cheap:** the conditional mean `m(x; θ, ε, τ)` (the expected density of items over the attribute `x`),
  its superposition `M(x; θ, ε) = ∫ m · w(τ) dτ`, and their gradients in `θ` — all exact and cheap.
- **Expensive:** an exact draw `X ~ μ` (items, attributes, positions). Everything about `μ` beyond its mean
  — the count law, the spatial arrangement, all higher structure — is reachable only this way.

**A nonlinear observation map.** A known map `H : 𝒳 → 𝒴` sends a **full configuration** to a fixed-length
signal; it is nonlinear, many-to-one, and costly, and is defined on configurations (it needs the items'
counts and positions), **not** on the mean `m` unless `m` is first lifted into `𝒳`.

**The data: abundant and cheap.** Many signals `{ y_k }`, each `y_k = H(X_k) + noise`, with `X_k` an
independent draw at the shared `θ` and unit-specific `(ε_k, τ_k)`, gathered over **windows** of the domain
that are ours to choose (a window may cover part of a unit, one unit, or several). Observations are plentiful
and inexpensive; `θ`, and the cost of evaluating the honest forward image of a `θ`, are the scarce things.

## The forward map and its obstructions

Let `F : θ ↦ (law of y)` be the forward map from parameters to the observable. Three obstructions separate
`F` from anything the cheap computation gives directly:

1. **Non-commutation.** `H` does not commute with the mean, and `m` does not determine `μ`; so
   `F(θ) ≠ H(M(θ))`, and the defect `D(θ) = H(M(θ)) − E[H(X)]` has no a priori sign or size. The mean is an
   *incomplete* summary of the law that `H` acts on.
2. **Representation gap.** `𝒳` (counts + positions + attributes) is strictly richer than the mean's natural
   domain (an attribute-density curve). To send `m` through `H` one must **supply degrees of freedom the mean
   does not carry** — a rule making a finite item set from a density, and a rule placing the items in space.
   `y` may depend on those supplied rules as strongly as on `θ`.
3. **Static observation of a dynamical object.** Each `y_k` is an image of a *single-time* state, yet `θ`
   parameterises the *dynamics*. The dynamics enter the data only through the **spread over the progress
   variable `τ`** across the many units — units at different `τ` show different stages of the same
   deterministic flow. Whether a dynamical `θ` is recoverable from this static, `τ`-superposed ensemble is
   not obvious.

## What we want (the foundations, in two linked parts of one problem)

- **Forward.** Compute `F(θ)` — the law, or the needed functionals, of `y` — to controlled accuracy by
  combining the cheap mean (and its gradient) with as few expensive draws as possible; bound and cheaply
  correct the defect `D(θ)`.
- **Inverse.** Determine when `θ` is **recoverable** from `{y_k}` — the injectivity and stability of `F` —
  and, specifically, when a *dynamical* `θ` is recoverable from the *static* ensemble. Name the
  reformulation (a change of state variable, a coordinate, an invariant, a choice of what to compare) that
  makes both parts well-posed and surmounts the representation gap.

## Facts an answer can rely on / constraints

- `m`, `M`, and their gradients in `θ` are cheap and exact; a full draw and `H` are expensive; there is **no
  cheap inverse of `H`**.
- The mean does **not** determine `μ`; `H` is nonlinear and known.
- **Observations are abundant**; the scarce resources are `θ` and the cost of evaluating `F` honestly
  (draw + `H`).
- The internal dynamics is deterministic in the mean and has the qualitative properties listed under
  structural features; **if a further property of it is decisive, name it and how the answer forks on it.**
- The **window/support is ours to choose**; the reset law `w(τ)` and the law of `ε` may be treated as
  parametric unknowns to be recovered alongside `θ`.
- A **synthetic generator at a known `θ*`** can be run (draw + `H`) and any proposed reconstruction must
  return `θ*` — the correctness reference.
- **Soft preference (not a constraint):** a route that leans on the abundant data and the cheap mean,
  spending the expensive forward path sparingly, is worth more than one that evaluates the full draw + `H` at
  every `θ`. If the right move discards this preference, say so.

## Structural features — any may be load-bearing or incidental; we do not know which

Only the mean is cheap (all else needs the expensive draw); the mean is available **phase-resolved**
(`m(·,τ)`), not only superposed; with `τ` the mean **relaxes toward a limit** set by the mechanism's
internal coupling (units at large `τ` resemble one another — possibly uninformative about `θ`); items
interact **only through an aggregate** (the mean is self-consistent without positions, a single realization
is not); `θ` parameterises the **dynamics** while each observation is **static** (dynamics seen only through
the `τ`-spread across units); the **representation gap** (mean = a curve; `H` needs counts + positions); the
**nonlinearity of `H`** (a defect of no fixed sign); **finite-count fluctuations** in one configuration;
**abundant data** against an **expensive forward map**; the **reset unit ≠ the chosen window**; a possible
**non-uniqueness** coupling `θ` to the unobserved laws `(w, ε)` that reproduces the same observable; a
spatial **correlation length** set by the spatial correlation of resets and the range of the coupling.

## Questions (open; please rank the features and reject the framing if the data warrant)

1. **Forward object.** Is the right thing to compute an aggregate of the cheap mean `M(θ)`, or does `F(θ)`
   genuinely require structure of the full law reachable only by the expensive draw? If the latter, is that
   **intrinsic** (`F` depends on the law beyond any cheaply computable summary) or **representational** (a
   cheap route exists from `m` plus `H`)? Bound and correct the defect `D(θ)`.
2. **Invertibility.** When is `θ` recoverable from `{y_k}` — the injectivity and stability of `F`? State the
   precise **obstruction to uniqueness**: which combinations of `θ` and the unobserved laws `(w, ε)` produce
   the same observable?
3. **Static → dynamics (the crux).** The observations are of a single-time state; `θ` is dynamical, entering
   only through the spread over `τ`. When, and by what reformulation, is a **dynamical `θ` recoverable from
   the static, `τ`-superposed ensemble**? Is there a coordinate or invariant in which the dynamics are read
   **directly** off the static observable?
4. **Representation gap.** `𝒳` is richer than the mean's domain, so `H` needs a lift `m ↦ x`. Characterise
   the observable's sensitivity to the (non-unique) lift, and how to choose or average over it so the
   recovered `θ` reflects the data and not the lift.
5. **Support / aggregation scale.** Over what window does a spatial aggregate of `{y_k}` coincide with
   `F(θ)` — dissolving the need to define a reset "unit" — and what sets that scale, computable from the data
   themselves? At the opposite extreme (window ≈ one unit), what is the correct comparison for a **single
   finite realization**?
6. **What are we missing?** A hidden invariant, a change of variables, or an assumption above that the
   structure quietly contradicts — including whether the mean is even the right state variable to reason
   about.
7. A **cheap discriminating experiment** — carrying your own falsifiable prediction — to run before building
   anything.
