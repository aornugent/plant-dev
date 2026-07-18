# Follow-on: the global solver already reaches converged accuracy cheaply — does any decomposition beat it?

A numerical-methods question. No application context is needed or given. This **follows four prior
rounds** on the same IVP (the settled facts are restated inline so this stands alone). We have now
**built** the decomposition scheme those rounds pointed to and measured it against the plain global
solver on the real system. The measurements point the other way from where we have been heading, so we
would rather you **re-derive whether the decomposition is warranted at all** than refine it. If the
honest reading is "the global solver is already optimal, stop decomposing," say so; if there is a
factorization we have not seen, name it.

## Settled from prior rounds (treat as established; do not re-litigate)

IVP `y' = f(y,t;θ)`, `y ∈ ℝ^N`, on `[0,T]`, integrated by an **adaptive embedded explicit RK** with a
local-error controller. `y` splits into a **large block `x ∈ ℝ^M`** (`M ≈ 50–800`) and a **small block
`u ∈ ℝ^L`, `L ≤ 5`**, two-way coupled. Downstream we take **reverse-mode gradients** of a scalar
functional `J` w.r.t. a small `θ`.

- The step-controller collapse is **accuracy-driven, not stability-driven** (measured: `corr(logΔt,logd)
  = −0.91`; 100% of steps run 3–4 decades below the explicit stability ceiling, across a 3000× stiffness
  sweep). Consequently the fast excursions of `u` (near a bound `u_min`, under a kinked time-
  inhomogeneity `b(·,t)`) are resolving **genuine solution structure** — any method of comparable order
  must take those steps. QSS reduction, A-stable/implicit stepping, and held/low-order-in-`u` coupling
  are all refuted as step-enlargers.
- Cost structure. Each member `j=1..M` carries a scalar control `p_j` from an inner argmax; then
  `ẋ_j = g(x_j,u,s,p_j)` and the coupling `a_ℓ(x,u) = Σ_j ρ_j c_ℓ(ξ_j,u,p_j)`, `ℓ=1..L`, with
  `u̇_ℓ = b_ℓ(u,t) + [transfer in u] − a_ℓ`. `a` is an **O(M) byproduct of the expensive per-member
  solves** (per-member cost: `u`-dependent setup ≈ 11, one objective ≈ 4.6, full argmax ≈ 21) and is
  genuinely, non-separably `u`-dependent. `ρ_j` is a per-member weight; `ξ_j` an ordered scalar member
  coordinate. The member set `{ξ_j, ρ_j}` is itself part of `y`, advanced by the dynamics and by an
  adaptive insertion schedule that places members to resolve `x(t)` — **not** the coupling integrand.
- The decomposition built (prior rounds' recommendation): a fixed macro grid; per macro step freeze the
  large block, **sub-cycle `u`** with the adaptive RK (or an exact-flow split of `u`'s stiff self-loop
  + ROS on the remainder), reading `a(x,u)` from the frozen large block at each micro step, then advance
  the large block. Two cost levers were on the table: **L1** exact-flow removal of `u`'s stiff self-loop
  (fewer micro steps); **L2** reduce the coupling to `m ≪ M` members (cheaper per micro step). Round 4
  refuted the naive `m`-reduction estimator and prescribed a measure/integrand split (integrate `ρ`
  exactly, reduce only the smooth integrand) with anchoring; it ranked **L1 first** because `n_micro`
  was unmeasured.

## The new information (the payload — measured on the real system)

`n_micro` and the head-to-head against the plain global solver are now measured. Truth for `J` is the
global solver at its convergence plateau.

**(1) The global solver reaches converged `J` cheaply, and only fails past convergence.** Sweeping its
tolerance `τ` on the full coupled system (one representative regime, `M≈90`, horizon 3):

| τ | J | cost | note |
|---|---|---|---|
| 1e-4 | 8.27 | 8 u | loose |
| 1e-5 | 8.43 | 15 u | **converged** |
| 1e-6 | 8.42 | 54 u | converged |
| 1e-7 | 8.43 | 393 u | converged |
| 1e-8 | — | — | **controller cannot meet τ (the "wall")** |

`J` is converged by `τ=1e-5` at **15 cost-units**; the wall is at `τ=1e-8`, **three decades tighter than
convergence** — an accuracy never needed. So the "wall" that motivated a stability-robust method sits far
past the accuracy the functional requires.

**(2) The decomposition is 6–25× more expensive than the global solver at converged accuracy,** because
`n_micro` is irreducible. Measured `n_micro ≈ 10` accuracy-driven micro steps per macro step; each micro
step re-evaluates the O(M) coupling (the expensive member solves), so the decomposition performs ≈13×
more member solves than the global solver (which touches all M members once per accepted step). Head to
head (converged accuracy):

| scheme | cost | J-error vs global-converged |
|---|---|---|
| global solver (τ=1e-5) | 15–120 u | ref |
| decomposition, full-M coupling | 110–725 u | 0.7–23% |
| decomposition, exact-flow split (L1) | ~1.7× the full-M decomposition | — |

**(3) L1 does not reduce `n_micro`.** The exact-flow split of `u`'s stiff self-loop is slower than the
plain adaptive inner at every macro step size H (tested H spanning 1–60× the forcing period): the step
count is set by accuracy, not the stiff self-loop, so removing it changes nothing and the ROS Jacobian
adds cost. Coarsening H to chase a stiff regime hits the macro method's own order-error wall (3% at H=5,
80% at H=60). **L1 is refuted.**

**(4) L2 (member reduction) helps the decomposition internally but never beats the global solver at
usable accuracy.** At the largest case measured (`M=352`): reducing to `m=20` members is 5× faster than
the full-M decomposition but still ≈ the global solver's cost **at 14% J-error**; `m=40` reaches 2.4%
J-error at **2× the global solver's cost**. The crossover `M > ~13·m` predicted by the arithmetic does
appear, but only at member counts where the required `m` for usable accuracy is itself a large fraction
of `M` (the evolved member distribution is not quadrature-friendly, as round 4 found).

**(5) `J` is pathologically sensitive.** Two independently-converged schemes disagree by ~23% on `J` at
`M=352`; small coupling errors amplify ~10× into `J`. The reverse-mode gradient targets exactly this `J`.

## Structural features — any may be load-bearing or incidental; we do not know which

The accuracy-driven (not stability-driven) step collapse; the wall sitting 3 decades past `J`-
convergence; `n_micro ≈ 10` irreducible; the coupling as an **O(M) byproduct of expensive member solves**
that is `u`-dependent and must live inside the fast dynamics; the member set placed to resolve `x(t)` not
the coupling; the skewed evolving weights `ρ`; `J`'s ~10× amplification of coupling error and ~23%
inter-method spread; the exact `∂P/∂p`; the tracked-control option; the reverse-mode tape whose cost
tracks accepted steps; `L ≤ 5`; the large-block rates `ẋ_j` requiring all M solves regardless of scheme;
that the global solver touches all M members exactly **once per accepted step** while any `u`-sub-cycling
touches them **`n_micro` times per macro step**.

## Facts an answer can rely on

- The global solver already reaches converged `J` at modest tolerance and modest cost; its only failure
  is at an accuracy past convergence.
- Any scheme that sub-cycles `u` re-evaluates the O(M) coupling `n_micro ≈ 10` times per macro step; the
  global solver evaluates it once per accepted step. `n_micro` is accuracy-driven and irreducible.
- Reducing the coupling to `m` members is the only per-micro-step cost lever; on the evolved member set
  it needs `m` near `M` for `J`-usable accuracy.
- The `ẋ_j` require all M member solves regardless of how `u` is advanced.
- Reverse-mode gradients of `J` are still wanted; the gradient economics of the decomposition (its
  record-replay tape) vs differentiating the global solver are **not yet measured**.

## Questions (open; please rank the features and reject the framing if the data warrant)

1. Given that the global explicit solver **already reaches converged `J` cheaply** and only fails at an
   accuracy 3 decades past convergence, **is there any decomposition of this system that reduces total
   cost below the global solver at converged `J`-accuracy** — or is the correct conclusion that the
   global solver is optimal here and the decomposition should be abandoned? If a decomposition can win,
   name it and the property it exploits that we have missed.
2. The decomposition's cost is `n_micro × O(M)` because the expensive coupling lives inside the fast
   loop and `n_micro` is irreducible. Is there a factorization that **removes the coupling from the fast
   loop** without a frozen/low-order-in-`u` surrogate (refuted), or that makes the per-micro-step
   coupling genuinely `o(M)` at `J`-usable accuracy on a member set placed to resolve `x`, not the
   coupling?
3. Does the **reverse-mode/gradient** use case change the verdict? Could a decomposition that loses on
   forward cost still win on `dJ/dθ` cost (shorter tape / structured adjoint), enough to justify it — or
   does `J`'s ~10× sensitivity and ~23% inter-method spread make any reduced/approximate gradient
   untrustworthy regardless?
4. Which measured fact is **load-bearing** for the verdict, and which is incidental?
5. **What are we missing?** Is there a structural simplification, a hidden cost, or an assumption in our
   framing (e.g. that a fixed macro grid tied to the forcing kinks is required, or that the functional
   must be taken as given rather than reformulated to be less sensitive) that the data quietly contradict?
