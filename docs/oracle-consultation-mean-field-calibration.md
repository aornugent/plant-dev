# Computing the expectation of a nonlinear map under a measure accessed cheaply through its mean and expensively through samples

A numerical-analysis question. No application is named and no method is assumed; each object is given only
through the operations available on it. Self-contained; assume no earlier context. If the quantity we ask
you to compute is the wrong object, say so.

## Setup

`𝒳` is the space of finite point sets on a domain, each point carrying a scalar attribute and a position.
`{μ_θ}` is a family of probability measures on `𝒳`, indexed by `θ ∈ ℝ^p` (`p` small). There are two ways to
access `μ_θ`, of very different cost:

- **Cheap, exact:** the mean `m(θ) = ∫_𝒳 x · μ_θ(dx)` — the intensity of `μ_θ`, a density over the attribute
  — together with its gradient `∂m/∂θ`.
- **Expensive:** an exact sample `X ~ μ_θ` (an actual finite point set). Nothing about `μ_θ` beyond its mean
  — the number of points, their arrangement, any higher moment — is available except through samples.

`H : 𝒳 → ℝ^d` is a known map: **nonlinear**, evaluable on a point set (each evaluation costly), and defined
**on point sets, not on the mean density** — to apply `H` to `m` one must first **lift** `m` to a point set
(choose a count and place the points), which `m` does not determine.

## Target

Compute
```
g(θ) = ∫_𝒳 H(x) · μ_θ(dx) = E_{X∼μ_θ}[H(X)]
```
— and, where possible, the law of `H(X)` — to controlled accuracy, across the family in `θ`, with as few
expensive sample/`H` evaluations as possible. `∂g/∂θ` is wanted too.

## The difficulty, in one fact

`m(θ)` does not determine `μ_θ`, and `H` is nonlinear, so `g(θ) ≠ H(m(θ))`: the cheap surrogate is biased,
and the defect `D(θ) = H(m(θ)) − g(θ)` has no a priori sign or size. And `H(m(θ))` is not even defined until
`m` is lifted to a point set — a choice `g` may depend on as strongly as on `θ`.

## Available structure — any may be load-bearing or incidental; we do not know which

- `∂m/∂θ` is cheap and exact.
- `μ_θ` is a **superposition** `μ_θ = ∫ μ_{θ,s} · w(s) ds` over a scalar index `s`, and each component mean
  `m(θ,s)` is cheap and exact too (only full component samples are expensive).
- A sample is a **finite** point set, carrying the counting and arrangement fluctuation the mean omits.
- `H` reads a point set through its **positions and count**, which the mean density does not carry — this is
  what forces the lift.
- Ground truth for any fixed `θ` is available by averaging many expensive samples: the reference any cheap
  scheme must match.

## Questions (open; please rank the structure and reject the framing if it is wrong)

1. **The defect.** Bound and characterize `D(θ) = H(m(θ)) − g(θ)` from properties of `H` and `μ_θ`; give
   computable conditions under which it is negligible.
2. **Minimal information.** `m` is an incomplete summary of `μ_θ`. What is the least additional information
   about `μ_θ` (a few higher moments? some low-dimensional summary?) that pins `g(θ)` to target accuracy —
   and is that information cheaply available, or reachable only through samples?
3. **Cheapest scheme.** Compute `g(θ)` and `∂g/∂θ`, across the family, to target error by combining many
   cheap means (with `∂m/∂θ`, and the component means `m(θ,s)`) with few expensive samples. What is the
   cost/error frontier, and the scheme that attains it?
4. **The lift.** Because `𝒳` is richer than the mean's domain, `H(m)` requires a lift `m ↦ x`. Characterize
   `g`'s sensitivity to the non-unique lift, and how to choose or average over it so the computed `g`
   reflects `μ_θ` and not the lift.
5. **What are we missing?** A hidden invariant, a change of variables, or an assumption above that the
   structure quietly contradicts — including whether decomposing `g` around the mean `m` is the right move
   at all.
6. A **cheap discriminating experiment** — carrying your own falsifiable prediction — to run before building
   a full scheme.
