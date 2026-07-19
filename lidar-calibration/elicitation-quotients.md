# The effective dimension of a composed parametric map, and the structures that collapse it

A numerical-methods question. No application context is needed or given. The objects are a parametric map
given as a composition, its reverse-mode gradient, and a large known set of conditions over which it is
swept. Self-contained; assume no earlier context. We would rather you re-derive the structure than accept
the decomposition we describe; if the map is best seen another way, say so. We are specifically after
structure that is **not apparent from the parameters or the output alone**.

## The map

A deterministic map `F(θ, c) = H( S(θ, c) )`:

- `θ ∈ ℝ^p`, `p` small, on a known low-dimensional manifold (a change in one component can be compensated by
  others).
- `c` — known conditions, differing from one evaluation to the next and known for each; the map is swept
  over a large known set of `c`.
- `S(θ, c)` — an expensive solve returning a high-dimensional structured state `u`. `S` is assembled from
  **many coupled components**; `u` is their aggregate.
- `H` — a known **nonlinear** operator from the state `u` to a fixed-length output `y = F(θ, c)`. `H` is
  **many-to-one**: distinct states can give the same output.

`∂F/∂θ` is available by a reverse-mode pass (and matches a finite difference of `F` as computed). One
evaluation is expensive; the set of `c` is large.

## The structure we suspect (any may be load-bearing or absent — we do not know which)

The effective number of `θ`-directions the output `y` varies along, across the swept `c`, may be far **below
`p`**, because dimension can collapse at each stage of the composition, and the collapses may compose:

- **At the operator `H`:** a null-space over states — directions of `u` that leave `y` unchanged.
- **At the state map `S`:** its image may lie on a **low-dimensional set** in state-space — the many coupled
  components may be captured by few effective coordinates — so `S` **factors through a low-dimensional
  intermediate** `Ψ(θ, c)` (`u ≈ ι(Ψ)`) even though `u` is high-dimensional. If so, `θ` reaches `y` only
  through `Ψ`.
- **In `θ`:** `∂F/∂θ` may be low-rank, and the subspace of `θ`-directions it varies along may be **shared
  across `c`** (`c`-invariant) or **`c`-dependent**.

## What we want (forward / structural)

- the **effective dimension** of `θ` that `F` varies along across the swept `c`, and its **decomposition by
  source** — operator null-space vs state-image reduction vs `θ`-rank;
- how to **detect** each collapse **cheaply** — from the gradient and a few expensive solves — **without
  assuming its form** (its dimension, the coordinates it collapses onto, or any group it respects);
- whether there is a **change of variables or factorization** — a low-dimensional intermediate `Ψ` the map
  factors through, a symmetry under which `F` (or `S`) is invariant, an invariance of `H` — that exposes a
  collapse **not visible in the naive rank of `∂F/∂θ`**, and in which the problem is better posed;
- which collapses are **shared across `c`** and which are `c`-dependent.

## Facts an answer can rely on / constraints

- `F`, its composition `H∘S`, and `∂F/∂θ` are computable and exact; one evaluation is expensive; the set of
  `c` is large and known.
- `θ` is small and manifold-constrained; `c` is known for every evaluation and is the sweep axis.
- The state `u` is high-dimensional; `H` is known, nonlinear, and many-to-one; `S` is an assembly of many
  coupled components.
- The internals can be probed — Jacobian-vector and vector-Jacobian products, the state `u` itself, the
  individual components — but each probe carries the cost of a solve.
- Soft preference (not a constraint): a route that leans on the cheap gradient and a few solves, rather than
  dense evaluation, is worth more. If the right move discards this, say so.

## Structural features — any may be load-bearing or incidental; we do not know which

The smallness and manifold constraint of `θ`; the known, swept `c`; the composition `H∘S`; the nonlinear,
many-to-one operator `H` (its null-space); the high-dimensional state `u` assembled from many coupled
components; the possibility that `S`'s image is low-dimensional (a factorization through `Ψ`); the possible
low rank of `∂F/∂θ`; whether the subspace it varies along is shared across `c` or `c`-dependent; the
composability of the three collapses; the cheap exact gradient; the expense of a single solve.

## Questions (open; please rank the features and reject the framing if the data warrant)

1. **Effective dimension, decomposed.** What is the effective number of `θ`-directions `F` varies along
   across the swept `c`, and how do you separate the contributions of the operator null-space, the
   state-image reduction, and the `θ`-rank — computably, from the gradient and a few solves?
2. **Detecting the state reduction without assuming its form.** Is there a general method to decide whether
   `S` factors through a low-dimensional intermediate `Ψ`, and to construct `Ψ`, from probes of the state
   across `(θ, c)` — without positing its dimension or coordinates in advance?
3. **Symmetries / invariances to quotient.** Is there a general way to detect a group action or invariance
   under which `F` (or `S`) is unchanged, so the problem can be posed in reduced coordinates — again without
   assuming the group?
4. **Collapse from the coupling.** Can the assembly of many coupled components induce a collective / reduced
   coordinate that further collapses the effective `θ` — and how would you find it numerically?
5. **Sharing across `c`.** Which collapses are the same across `c` and which are `c`-dependent, and how is
   that decided cheaply?
6. **What are we missing?** A hidden invariant, a change of variables, or an assumption above that the
   structure quietly contradicts — including whether the composed-collapse picture is the right lens at all.
7. **A faithful discriminating experiment** — exercising the full `F = H∘S`, not a simplified proxy
   (simplifications here have reversed conclusions before) — carrying your own falsifiable prediction, to run
   before building.
