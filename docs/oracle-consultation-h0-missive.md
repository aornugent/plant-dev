# H0 missive: the envelope-collapse condition, and when a coupling admits it

*Short follow-up to the commit-review round. Records the H0 check on our current coupling and poses the
one generalization worth a characterization: when does the envelope identity collapse the control out of
the fast system entirely?*

## What we checked

H0 (from the commit-review response): if the coupling byproduct is the objective's own state-gradient,
`c_ℓ(x_j, u, p_j*) = ∂P/∂u_ℓ` at the optimum, then by the envelope theorem
`a_ℓ(x,u) = Σ_j ∂P/∂u_ℓ = ∂V/∂u_ℓ`, `V := Σ_j max_p P(p; x_j, u, s)`, and the fast dynamics
`u̇ = b − a` become the gradient-coupled system `u̇ = b − ∇_u V` — the per-member control `p*` never
appears (only `V`'s `u`-gradient, which is second-order-insensitive to `p*`-error by stationarity).

## Result on our coupling: it does not hold — for a structural reason worth naming

In our system the fed-back byproduct is a **conserved-resource flux** `E_ℓ` (a rate in the balance
`u̇_ℓ = b_ℓ − E_ℓ`), while `∂P/∂u_ℓ` is the **marginal value** of that resource to the objective — a
different quantity in different units. The flux is a *constraint output* of the inner optimization, not
the *gradient* of its value. They are related only through the constraint's own sensitivity: at the
optimum `∂P/∂u_ℓ = λ_ℓ · ∂E_ℓ/∂u_ℓ`-type expressions, where `λ` is the shadow price of the resource —
so recovering `a` from `∇_u V` would require dividing back through the supply sensitivity, reintroducing
`λ` and the supply map rather than eliminating `p*`. **Envelope smoothness still helps the adjoint**
(differentiating through the optimum, `∂p*/∂input` terms drop) — that is real and we rely on it — but it
does not collapse the forward coupling.

## The generalization (the tantalizing part) — please characterize

The collapse H0 promises is powerful (control gone from the fast block; symmetric coupling Jacobian
`∇²_u V`; `V` smooth even where `p*` is nearly kinked). It hinges entirely on **whether the byproduct
that the fast block reads is the objective's `u`-gradient or a constraint flux.** That is a property of
*how the coupling is posed*, and future instances of this problem family may pose it either way.

**Q: characterize the class of coupling structures for which the envelope collapse holds** — i.e., give
the recognition condition on `(P, the inner constraints, the byproduct map c)` under which
`c_ℓ = ∂P/∂u_ℓ` at the optimum (equivalently, `a = ∇_u V`). Concretely:
1. Is the discriminator exactly *"the fed-back byproduct is the objective's marginal (a value/adjoint
   quantity) vs. a primal constraint flux"* — or is there a broader sufficient condition (e.g. a
   Legendre/Lagrangian duality, a specific separability of `P` in `u`, or a potential/gradient-flow
   structure) under which a constraint-flux coupling can be *rewritten* as a gradient coupling by a
   change of the fast variable or a shadow-price change of coordinates?
2. If a flux-coupled system can be mapped to a gradient-coupled one via the shadow price `λ(u)`, what is
   the cost/conditioning of carrying `λ` as the fast variable instead of `u` — does it move the
   singularity, and does it preserve the tape contracts?
3. What is the minimal check (one identity to test per new instance) that tells us, before building,
   whether a given coupling admits the collapse — so it becomes a standard triage step for each new
   member model, not a per-model afternoon of algebra?

The prize, if the condition is broad: a member model posed in the "marginal-coupled" form would drop the
entire tracked-control / argmax apparatus for free. Knowing the recognition condition tells us whether
to *design future couplings into that form on purpose*.
