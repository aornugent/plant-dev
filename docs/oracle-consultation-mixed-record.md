# Sizing a locally-varying discretisation from a known, inhomogeneous forcing record

A self-contained follow-on problem. No application domain is assumed. A prior
round settled how to split error between two discretisations for **one fixed
forcing realisation** when the realisation is statistically homogeneous. It is
not. This asks what changes when the record is a mixture in time, and when the
quantity of interest is a derivative.

## 1. The system, briefly

`y(t) = (u, x)` on `[0, T]`.

`u ∈ ℝ^L`, `L ≤ 5`: a one-way chain with a steep diagonal loss,
`u̇_ℓ = s(t)·[ℓ=1] − κ_ℓ u_ℓ^q + κ_{ℓ−1} u_{ℓ−1}^q − a_ℓ(x,u)`, `q ≈ 16`,
lower bound `u_ℓ > u_min`. Its relaxation time is ~300× shorter than the scale
on which `x` moves.

`x` is a measure transported along characteristics, `μ_t = Σ_j ρ_j δ_{ξ_j}`,
with `M` members. Member `j` is created at time `b_j`; the creation times are the
**characteristic labels** and are the abscissae of the quadrature over `μ_t`.
On that axis the grid is fixed for all time and the map from creation schedule
to quadrature abscissa is the identity. `a_ℓ(x,u) = Σ_j ρ_j c_ℓ(ξ_j,u,p_j)`
where `p_j` solves an inner constrained scalar optimisation in `(ξ_j, u)` whose
solution is piecewise-smooth with switching surfaces.

The output `J` is a space–time moment of `μ`. **`dJ/dθ` is the quantity of
interest**, `θ ∈ ℝ^k`, `k ≈ 17`, by reverse-mode AD over the trajectory.

Three grids, all on `[0,T]`: the creation times `𝒢_b` (≈88), the step times
`𝒢_t` (≈530–1017), and the forcing knots `𝒢_f` (1825). `𝒢_b ⊂ 𝒢_t`.

## 2. What is settled, and the assumption it rested on

For a fixed realisation, with cost bilinear `C ≈ N_t(αM + β)`, `β/(αM) ≈ 0.16`,
and errors as power laws `e_b = A M^{−p}`, `e_t = B N_t^{−q}`, minimising cost
at fixed total error gives `p·e_b·(1 + β/αM) = q·e_t` — error shares in
proportion to convergence order, not equidistribution. With `p = 2` (the
quadrature on the label axis is currently a trapezoid rule) and `q = 5`, that is
`e_b ≈ 2.2 e_t`.

That derivation treats `p`, `q`, `A`, `B` as constants over `[0, T]`. **They are
not.** The forcing `s(t)` is intermittent and inhomogeneous: within a single
record there are long quiescent stretches where `s ≡ 0` exactly, stretches of
many small events, stretches of few large events, and stretches of prolonged
absence. Each produces a different local regime:

- where `s ≡ 0` the reconstruction of `s` is identically zero and smooth, no
  step is forced by the forcing, and `N_t` is free;
- where events are dense, `N_t` has a floor of a few steps per event that no
  tolerance removes, and `M` becomes the only free variable;
- where events are sparse but large, the floor is small but each event drives a
  transient whose rate is known in closed form from the event size.

## 3. Measured

**(E1)** The forcing knots matter only where `s ≠ 0` on at least one side. Over
quiescent stretches the reconstruction is exactly zero and contributes no kink.
So the alignment set is a strict, computable subset of `𝒢_f`, and its size
varies by orders of magnitude between stretches of one record.

**(E2)** Under smooth sustained forcing 77% of accepted steps are set by the
stability of the chain's terminal component, not by accuracy — `h·|λ| ≈ 3.5–5.3`
pinned across a 100× sweep of the loss coefficient. So `N_t` is currently not a
design variable at all. Removing that constraint (a linearly-implicit stage on
the `L`-component chain) is planned.

**(E3) The reported error is the residual of a cancellation.** Under a smooth
record, at `M = 88` on the label coordinate, the *reconstruction* error of the
forward solve is −0.617%, the output quadrature's own error is +0.359%, and the
reported total is −0.259%. Both are `O(Δb²)`; their ratio is −0.582, −0.581,
−0.580 at successive refinement levels. The mechanism is that the forward solve
reaches the coupling `a_ℓ` through reductions over the **same nodes under the
same rule** as the output functional. Replacing the output rule with a cubic
spline cuts the quadrature term 148–258× and makes the reported answer **2.4×
worse**, uniformly. Changing only the reconstruction coordinate leaves the
quadrature term unchanged (+0.353%) and moves the reconstruction term to
−1.425%, ratio −0.248. Against all of this the time error is 6.6e-8.

**(E4) Switching is temporal; kinks on the quadrature axis are rare and
undetectable.** Over a run, 70% of member-instants sit on the interior branch
and 30% on one active constraint under sustained stress — but at any given
instant, and at the final state of every record tested, the whole population is
on a single branch. Non-smoothness in `b` does occur: 4–6 adjacent nodes, in the
two most stressed records, carrying 1.4–1.8% of `J`. A global high-order rule
degrades 5.7× to 120× inside the one panel holding a kink, but those panels are
5.7–6.7% of a residual already 170–190× below the trapezium's. A composite rule
restarting at the kink is 0.5–2.2% **worse** than ignoring it — segments on a
five-nodes-per-rung grid are too short to pay for themselves. A detector
restricted to the default node samples cannot locate the kinks at all.

**(E7) The grid's spacing doublings dominate the high-order residual.** The
creation grid is dyadic, `Δ = 2^⌊log₂(0.2 t)⌋` clamped, so the spacing doubles
at 16 of 87 intervals. Those 16 carry 26% of `J` but 54–71% of a cubic spline's
residual, against 40% of the trapezium's. A control grid with the same clamps,
span and node count but a smooth ratio (`Δ = max(1e-5, 0.147 t)`, one extra
node) improves every term at once: trapezium −12%, spline −35%, reconstruction
−14%, reported error −0.259% → −0.219%, and local rules recover their design
order (an observed 5.31 becomes 5.97).

**(E5) Two kinds of event, with different consequences for the derivative.** At
a switching surface of the inner problem the rate is continuous, so a discrete
adjoint with the event pinned to a grid point is first-order correct. At an
arrival on the inequality boundary carried by each member the rate jumps, and
the exact sensitivity carries a term `(f⁻ − f⁺)·dt_e/dθ` that a pinned-event
adjoint does not contain.

**(E6)** With `𝒢_t` frozen, finite differences of `J` in `θ` show a clean
three-decade plateau; with adaptive stepping there is no plateau at any
perturbation size. This establishes that the discrete derivative is
reproducible. It does not establish that it is accurate: the convergence of
`dJ_h/dθ` under refinement has not been measured.

## 4. Questions

### 4.1 A discretisation that varies within the record

The record is known in full in advance, and the local regime is a computable
property of it (E1). What is the minimal, well-understood way to size a
**locally-varying** pair of grids from such a record — as opposed to one global
`(M, N_t)` pair? Is the correct object a local version of the same balance,
equalising marginal error reduction per unit cost *per stretch*, with the
per-stretch orders and constants estimated once? What breaks when the local
orders differ between stretches — quiescent stretches supporting high order in
time while event-dense stretches are capped by the event floor?

In particular: the allocation is derived by minimising cost at fixed total
error, and total error is a sum over stretches while cost is also a sum over
stretches, but the two grids are coupled globally (the same `M` serves the whole
record, since a member created in one stretch persists into all later ones). Is
`M` genuinely a global variable while `N_t` is local, and if so what is the right
formulation — a single constraint with a local density of steps, or something
else?

### 4.2 Does the balance hold for the derivative?

The settled balance used the convergence orders of `J`. The quantity of interest
is `dJ/dθ`. Differentiating a quadrature rule does not in general preserve its
order, and the same is true of a Runge–Kutta pair's global error under
parameter differentiation.

(a) For a `θ`-independent discretisation, do `dJ_h/dθ` and `J_h` converge at the
same order in each grid, and if not, what are the orders? (b) If they differ,
the balance ratio changes — what is it? (c) Are the *constants* systematically
worse for the derivative, so that a target on `dJ/dθ` implies a materially finer
discretisation than the same relative target on `J`? (d) What is the cheapest
reliable way to measure the derivative's convergence order empirically, given
that the reference is unknown and finite differencing has its own floor?

### 4.3 Pruning the alignment set

Under dense small events (E1) the alignment set alone could dominate `N_t`. The
adjoint of the forcing, `λ_{u_1}(t)`, prices which events `J` actually responds
to.

(a) Is "align to the events whose adjoint-weighted contribution exceeds a
threshold, and step over the rest" sound, and what is the right threshold in
terms of the error budget? (b) Stepping over an unaligned event reintroduces a
local order loss — is it enough that the adjoint says `J` does not care, or does
the local error still pollute the trajectory in a way the adjoint's
linearisation does not see? (c) The adjoint is `θ`-dependent, so a pruned
alignment set is `θ`-dependent. Does that reintroduce the non-smoothness in
`θ` that a fixed grid was adopted to remove, and if so is the remedy to prune
once at a nominal `θ` and freeze, or to prune on a `θ`-independent surrogate?

### 4.4 An error cancellation between the forward solve and the output

E3: the reported error is the residual of a near-cancellation between two
`O(Δb²)` terms of opposite sign, in a ratio stable to three digits across
refinement levels, arising because the reconstruction and the functional use the
same rule on the same grid. Raising the order of the functional alone destroys
it and makes the answer 2.4× worse.

(a) Is this supraconvergence — a structural property of matched rules — or a
coincidence of this integrand? What conditions make it reliable, and how would
one test reliability rather than observing it? (b) If structural, is the right
design to *preserve* it deliberately: keep the rules matched and raise both
orders together? Does raising both together preserve the cancellation or destroy
it? (c) The ratio is −0.58 in one coordinate and −0.24 in another, so the
cancellation is partial and coordinate-dependent. Is there a principled way to
make it exact, or to construct the output rule so its error tracks the
reconstruction's? (d) What is the right error *estimator* under a cancellation?
The current one is a Richardson estimate of the output rule's own local error —
it measures a term that exists to cancel another, and it drives the grid
refinement.

### 4.5 A dominant term that does not converge

Under mixed records the decomposition changes character: the quadrature term
stays near 0.36%, while the reconstruction term is **16–31% and does not
converge under refinement** — one record gives −16.2%, −41.2%, +4.6% at
successive levels. It is not a time-integration artefact; the decomposition
repeats to four digits at a 10⁴× tighter time tolerance. In those same records
`J` is between 4.3e-11 and 7.5e-10.

(a) What are the candidate causes of a non-convergent `O(Δb²)` reconstruction
term under inhomogeneous forcing, and how would one distinguish them? (b) Does a
near-zero functional make relative error meaningless here, or is relative error
the right measure because the quantity of interest is effectively a derivative
of its logarithm? (c) If the dominant term does not converge, is a balance
between the two grids meaningful at all, or is recovering convergence the whole
of the first task?

### 4.6 The derivative's missing event term

E5: arrivals on the per-member inequality boundary contribute a sensitivity term
a pinned-event adjoint omits. The planned remedy is to reformulate the
constraint so the boundary is approached asymptotically and never arrived at
(a change of variable to the logarithm of the constrained quantity, since the
drain vanishes at the boundary), removing the event entirely.

(a) Is that sufficient to make `dJ/dθ` correct rather than merely consistent, or
does the reformulated dynamics carry its own bias in the derivative? (b) How
should the residual be verified, given that the quantity being checked is
exactly what no finite difference on the unreformulated model can measure?
(c) Is there a cheap a posteriori check that the omitted term is small, usable
*before* committing to the reformulation?

### 4.7

Which of E1–E7 is load-bearing for each answer, and which incidental? Given a
requirement for accurate derivatives across records that mix all of these local
regimes, what is the smallest set of changes and in what order? What has not
been asked?

## 5. Constraints an answer can rely on

- The forcing record is known in full before the run, and the local regime is a
  deterministic function of it.
- Reverse-mode AD is required; the quadrature axis is the only coordinate that
  supports it. The choice of grid is off the tape (the step sequence is recorded
  and replayed), so grid decisions may depend on anything, including quantities
  from a previous solve.
- `L ≤ 5`; dense linear algebra on the chain is free, its Jacobian analytic and
  bidiagonal.
- Cost is counted in right-hand-side evaluations; a member loop dominates them,
  `O(M)` with one inner solve per member.
- The model's formulation may be changed if the change is declared and its
  effect on `J` and on `dJ/dθ` is budgeted.
