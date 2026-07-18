# Computing the expectation of a nonlinear functional from a cheap mean and expensive samples

A numerical-analysis question. No application, no solution method, and no choice of mathematical
formalization are presupposed — the objects are given only by the operations available on them, and which
formalization fits is part of the question. Self-contained; assume no earlier context. If the quantity we
ask you to compute is the wrong object, say so.

## Setup

`{μ_θ}` is a family of probability distributions of a random object `X`, indexed by `θ ∈ ℝ^p` (only a few
components vary; they lie on a known low-dimensional manifold). `X` takes values in a space on which
averaging is defined; we deliberately do not fix what an element of that space is. Two operations are
available, of very different cost:

- **Cheap, exact:** the mean `m(θ) = E[X]` and its gradient `∂m/∂θ`.
- **Expensive:** a draw `X ~ μ_θ`. Nothing about `μ_θ` beyond its mean is available except through draws.

`H` is a known **nonlinear** functional of `X` (each evaluation costly). It can be applied to a draw, and
also to the mean `m` (a well-defined but different input); the two disagree.

## Target

Compute `g(θ) = E[H(X)]` — and, where possible, the distribution of `H(X)` — across the family in `θ`, to
controlled accuracy, using the cheap mean and as few expensive draws as possible. `∂g/∂θ` is wanted too.

## The difficulty

`m(θ)` is an incomplete summary of `μ_θ`, and `H` is nonlinear, so `g(θ) ≠ H(m(θ))`: the cheap surrogate is
biased, and the bias has no a priori sign or size. `H` is sensitive to exactly the part of `μ_θ` that the
mean discards.

## Available structure — any may be load-bearing or incidental; we do not know which

- The gradient `∂m/∂θ` is cheap and exact.
- Each `μ_θ` decomposes as `∫ μ_{θ,s} w(s) ds` over a scalar index `s`, with every component mean `m(θ,s)`
  cheap and exact; the components are well separated, so `μ_θ` is **multimodal** and its mean `m(θ)` falls
  between the modes, resembling no draw.
- A draw carries fluctuation the mean omits.
- `H(m)` is computable but biased.
- Ground truth for any fixed `θ` is available by averaging many draws — the reference any cheaper scheme
  must match, computed on the full `μ_θ`, never a simplified proxy.

## Questions (open; please rank the structure and reject the framing if it is wrong)

1. **The formalization.** What is the right mathematical object for `X`, and for the relationship between
   `m` and `H(X)`? If more than one formalization is natural, say which, and whether the choice changes the
   answer.
2. **The bias.** Bound and characterize `E[H(X)] − H(m)` from properties of `H` and `μ_θ`; give computable
   conditions under which it is negligible.
3. **Minimal information.** What is the least information about `μ_θ` beyond `m` that pins `g(θ)` to target
   accuracy — and is it cheaply available (for example from the component means) or reachable only through
   draws?
4. **Cheapest scheme.** Compute `g(θ)` and `∂g/∂θ`, across the family, to target error by combining the
   cheap mean (with `∂m/∂θ` and the component means `m(θ,s)`) with few expensive draws. What is the
   cost/error frontier?
5. **What are we missing?** A hidden invariant, a change of variables, or an assumption above that the
   structure quietly contradicts — including whether working through the mean `m` is the right move at all.
6. **A faithful discriminating experiment.** The single experiment that would most decisively confirm or
   kill your recommended approach, exercising the full `μ_θ` and `H` rather than a simplified proxy
   (simplifications here have reversed conclusions before), with your own falsifiable prediction, to run
   before building.
