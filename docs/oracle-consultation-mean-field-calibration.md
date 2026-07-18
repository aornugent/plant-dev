# Relating a cheaply-computed expected distribution to a nonlinear summary of expensive individual realizations

A numerical-analysis question. No application is named, no solution method is assumed, and no mathematical
formalization is presupposed — each object is given only through the operations available on it, and part of
the question is which formalization fits. Self-contained; assume no earlier context. If the relationship we
ask you to compute is the wrong object, say so.

## Setup (given as operations, not as a chosen object)

A parametric generator `G_θ`, `θ ∈ ℝ^p` (only a few components vary; the rest are fixed, and the varying ones
lie on a known low-dimensional manifold), is run forward in time from an empty state and is reset to empty at
random times. Write `τ` for the time since the last reset; independent instances of `G_θ` occur at all values
of `τ`, with density `w(τ)`. The state of an instance is a finite collection of **elements**, each carrying a
scalar **magnitude**.

Two computations expose `G_θ`, at very different cost:

- **Cheap:** a deterministic solver returns the **expected distribution of the magnitude** across the
  elements, conditional on `τ` — a curve `m(·; θ, τ)` — together with its `τ`-average `M(·; θ)` and the
  gradients in `θ`. (This is an average over the generator's randomness; it is a smooth curve, not a
  realization.)
- **Expensive:** a stochastic simulator returns **one actual realization** — a finite collection of elements
  with their magnitudes.

A known map `H` returns a fixed-length **summary** of a realization's structure. `H` is nonlinear. It
additionally requires an **arrangement of the elements in a space** that the generator does not supply. `H`
can also be applied to the expected distribution `m` (a well-defined but different input), giving a value
that is **biased** relative to the realizations.

## Target

Relate the cheap expected distribution to the summaries of realizations: compute `g(θ) = E[H(realization)]`
— and, where possible, the distribution of `H(realization)` — across the family in `θ`, to controlled
accuracy, using the cheap solver and as few expensive realizations as possible. `∂g/∂θ` is wanted too.

## The difficulty

- `H` is nonlinear, so `E[H(realization)] ≠ H(m)`: applying `H` to the expected distribution is biased, and
  the bias has no a priori sign or size.
- The expected distribution conditional on `τ` is **strongly multimodal and changes shape markedly with
  `τ`** (measured: from a spike, to a spread, to a two-mode form). Its `τ`-average `M` resembles no single
  realization at all.
- A realization is **finite** and carries an **arrangement** that `H` needs but neither the expected
  distribution nor the generator supplies.

## Available structure — any may be load-bearing or incidental; we do not know which

- The gradient `∂m/∂θ` is cheap and exact.
- The expected distribution is available **conditional on `τ`**, not only `τ`-averaged; it is multimodal and
  strongly `τ`-dependent.
- A realization is finite, carrying counting fluctuation the expectation omits.
- `H` needs an arrangement (and an element count) the expected distribution does not carry; `H(m)` is
  computable but biased.
- Ground truth for any fixed `θ` is available by averaging many expensive realizations — the reference any
  cheaper scheme must match, and it must be computed on the full generator, never a simplified proxy.

## Questions (open; please rank the structure and reject the framing if it is wrong)

1. **The formalization.** What mathematical object best captures the relationship between the cheap expected
   distribution and the summaries of realizations? If more than one formalization is natural, say which, and
   whether the choice changes the answer.
2. **The bias.** Bound and characterize `E[H(realization)] − H(m)` from properties of `H` and the generator;
   give computable conditions under which it is negligible.
3. **Minimal information.** The expected distribution is an incomplete summary of a realization. What is the
   least additional information about the generator's output that pins `g(θ)` to target accuracy — and is it
   cheaply available, or reachable only through realizations?
4. **Cheapest scheme.** Compute `g(θ)` and `∂g/∂θ`, across the family, to target error by combining the
   cheap solver (with `∂m/∂θ` and the `τ`-conditional curves) with few expensive realizations. What is the
   cost/error frontier?
5. **The missing arrangement.** `H` needs an arrangement and count the generator omits. How should that be
   supplied or averaged over so the computed `g` reflects the generator and not the supplied arrangement?
6. **What are we missing?** A hidden invariant, a change of variables, or an assumption above that the
   structure quietly contradicts — including whether relating things through the expected distribution is the
   right move at all.
7. **A faithful discriminating experiment.** The single experiment that would most decisively confirm or kill
   your recommended approach — and that **exercises the full generator and map, not a simplified proxy**
   (simplifications here have reversed conclusions before) — carrying your own falsifiable prediction, to run
   before building a full scheme.
