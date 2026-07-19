# Computing a parametric response and its θ-sensitivity across a swept set of known conditions

A numerical-methods question. No application context is needed or given. The objects are a parametric
forward map, its reverse-mode gradient, and a large known set of operating conditions over which the map is
swept. Self-contained; assume no earlier context. We would rather you re-derive the right approach from the
structure than accept the decomposition we describe; if the map is posed in the wrong variables, say so.

## The map

A deterministic map `F(θ, c)`:

- **`θ ∈ ℝ^p`, `p` small** — parameters identical for every evaluation, lying on a known low-dimensional
  manifold (a change in one component is compensated by others). The object of interest.
- **`c`** — known operating conditions (moderate- to high-dimensional: a driving series plus a few scalars),
  **differing from one evaluation to the next and known for each**. The map is swept over a large known set
  of `c`.

Internal structure of one evaluation: an expensive solve produces a **profile `u(θ, c)`** over a scalar
coordinate; a known **nonlinear operator `H`** maps that profile to a fixed-length output `y = F(θ, c)`.
`∂F/∂θ` is available by a reverse-mode pass and matches a finite difference of `F` as computed. One
evaluation is costly; the set of `c` is large.

## The difficulty

- **The `θ`-signal is diffuse.** At any single `c`, `F(·, c)` is weakly sensitive to `θ` — a wide range of
  `θ` reproduces the output at that `c` to within the operator's own discretization error (below). The
  information about `θ` is carried by **how the output varies across the swept `c`**, not by any one
  condition.
- **The operator needs a discretization the profile does not fix.** `H` acts on a finite set of elements
  placed in a space — a discretization of the profile `u` — and `u` fixes the profile but not that
  discretization. `H` applied to the smooth profile directly is a biased surrogate for the true output, and
  the output depends on the discretization to a degree not known a priori.

## What we want

Foundationally: (i) the structure of the `θ`-sensitivity across `c` — which features or projections of the
response are `θ`-sensitive and which are flat; (ii) how to compute `F` and `∂F/∂θ` across the swept set to
target accuracy with the fewest expensive evaluations; (iii) whether `F` is posed in the right variables so
that the `θ`-sensitivity is well-conditioned and the discretization dependence is small.

## Facts an answer can rely on / constraints

- `F` and `∂F/∂θ` are computable and exact — the gradient matches a finite difference of `F` as computed;
  one evaluation is expensive; the set of `c` is large and known.
- `θ` is small and manifold-constrained; `c` is known for every evaluation and is the axis the map is swept
  over.
- `u(θ, c)` is a smooth profile over a scalar coordinate; `H` is nonlinear; `H` requires a discretization of
  `u` that `u` does not fix, so `H(u)` is biased and discretization-dependent.
- Soft preference (not a constraint): a route that leans on the cheap gradient and the smoothness of `F` in
  `(θ, c)`, spending few expensive evaluations, beats dense evaluation. If the right move discards this, say
  so.

## Structural features — any may be load-bearing or incidental; we do not know which

`θ` small and manifold-constrained; `c` high-dimensional, known, and swept; the **diffuse `θ`-signal** (weak
per-`c` sensitivity, informative only across the set); the expensive solve; the **nonlinear operator `H`**
between profile and output; that `H` needs a **discretization of the profile that the profile does not fix**
(biased, discretization-dependent output); the cheap exact `∂F/∂θ`; the smoothness of `F` in `(θ, c)`; one
shared `θ` across a large known set of `c`.

## Questions (open; please rank the features and reject the framing if the data warrant)

1. **Where is the `θ`-information?** Across the swept `c`, which features or projections of the response
   carry `θ` and which are flat? Is it concentrated in particular regions of `c` — so a designed sub-sweep
   captures most of it — or genuinely thin across the whole set?
2. **Cheapest computation.** Compute `F` and `∂F/∂θ` across the swept set to target accuracy with the fewest
   expensive evaluations, exploiting the cheap gradient, the smoothness in `(θ, c)`, and the shared `θ`.
   What is the cost/error frontier, and the scheme that attains it?
3. **Right variables?** Is `F` posed in the right variables — or is there a change of variables (in `θ`, in
   `c`, or in the output) in which the `θ`-sensitivity concentrates and the discretization dependence
   shrinks?
4. **The discretization dependence.** `H` needs a discretization of `u` that `u` does not fix, so `H(u)` is
   biased. Does this matter for the across-`c` `θ`-sensitivity, or does it wash out across the set — and if
   it matters, how should the discretization be chosen or removed so the answer reflects `F`, not the
   discretization?
5. **What are we missing?** A hidden invariant, a change of variables, or an assumption above that the
   structure quietly contradicts.
6. **A faithful discriminating experiment** — exercising the full `F` and `H`, not a simplified proxy
   (simplifications here have reversed conclusions before) — with your own falsifiable prediction, to run
   before building.
