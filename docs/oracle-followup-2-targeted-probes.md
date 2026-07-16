# Follow-up B (targeted probes): specific structural collapses to confirm or reject

A companion to Follow-up A, kept separate on purpose. Where A hands you the fully-specified hard
case and asks openly for structure, this document poses a small set of **specific** candidate
collapses and asks you to confirm, reject, or replace each. Sending the two framings independently
lets convergence (both point at the same reformulation) count as strong evidence and divergence
localise the real fork. Scope is the same hard case: full self-consistent feedback, multivariable
distribution moments, the optimizer-plus-auxiliary-subsystem instance with the density-transport term.

For each probe: is it real in this instance; if so what exactly does it remove; and the cheapest
test that would settle it. "This one is a dead end because …" is as useful as a confirmation.

1. **Eliminate the continuous reconstruction.** The only consumers of the field are reads at the
   ordered population points and the boundary (the compression uses a neighbour secant, not a
   sub-grid field). So the field-at-particles is a triangular, zero-diagonal kernel operator on the
   mass vector followed by a pointwise contraction — no knots, no collocation solve, no basis rows.
   Does this remove the entire spline/reconstruction apparatus, and is its exact adjoint a pair of
   cumulative-sum scans?

2. **Exploit exact kernel separability.** The kernel is a finite sum of separable terms (rank 3 in
   this instance): `κ(z,x)=Σ_p a_p(z)b_p(x)`. The aggregate is then a few one-sided cumulative sums,
   `O(N·rank)` exact, and its transpose is a scan. Does the separated form make the coupling-only
   parameter class analytically clean — i.e. does it explain and remove the pathology those
   parameters showed under naive differentiation — and does it subsume probe 1?

3. **Reduce or close the transport analytically.** With `dmᵢ/dt = −r·mᵢ` (positive exponential of a
   path integral) and the transport-free moment identity, is any part of the gradient closed-form —
   a moment satisfying its own low-dimensional driven ODE, or the per-characteristic mass integrated
   semi-analytically — reducing what must be recorded?

4. **Trivialise the operating point by a change of variables.** `J` is concave with a unique interior
   optimum; `c` is monotone with a unique root. Is there a variable in which the argmax is
   unconstrained/explicit or the KKT system is diagonal/triangular, so the operating-point
   sensitivity is analytical rather than a solved linear system — and does the stationary/non-
   stationary split of `(ρ, σ)` simplify there?

5. **Eliminate the auxiliary subsystem.** Does a quasi-steady-state (its balance solved for `u*`
   given the population sink) or a positivity-preserving change of variable remove the stiffness, the
   resets, and the frozen-replay question at once — and, since each balance is a scalar monotone
   equation, is `u*` closed form?

6. **Close the breakpoint integral.** Using the monotone threshold equation and the smooth branches,
   is the piecewise integral (and its derivative, including the jump term at the moving split) closed
   form rather than split quadrature?

7. **Recover the dropped schedule sensitivity cheaply, if it matters.** If frozen-schedule replay
   proves to drop a material term, does the event structure (insertions at known times, adaptive node
   placement) admit a closed-form event/saltation correction rather than differentiating the adaptive
   process?

8. **The whole-system reframe.** Beyond the mass chart (state axis), is there a second load-bearing
   representation — of the field or the operating point — and do they compose into one reformulation
   that collapses most of the above? If one change dominates, name it.
