# Control algorithms with guarantees for a gradient on a shared grid

A self-contained, narrow problem. No application domain is assumed. The target
is not a value but a **derivative**, computed by reverse-mode AD; the forcing is
a known, inhomogeneous record; and the discretisation must be **shared** across
parameter values. We want algorithms whose behaviour is provable rather than
tuned.

## 1. The setting

`y(t) = (u, x)` on `[0, T]`, integrated by an embedded explicit Runge–Kutta pair
under a max-norm local error test.

- `u ∈ ℝ^L`, `L ≤ 5`: a one-way chain with a steep power-law loss
  (`−κ_ℓ u_ℓ^q`, `q ≈ 16`), forced at `ℓ=1` by `s(t)`, and consuming `a_ℓ(x,u)`.
- `x`: a measure transported along characteristics, `M` members. Member `j` is
  created at time `b_j`; those creation times are the characteristic labels and
  are **also** the abscissae of the quadrature over the measure. On that
  coordinate the grid is fixed for all time and the map from creation schedule
  to abscissa is the identity.
- Each member carries a scalar `p_j` solving an inner **constrained**
  optimisation in `(ξ_j, u)`: an interior stationary point or one of three
  active-constraint boundaries. `a_ℓ(x,u) = Σ_j ρ_j c_ℓ(ξ_j,u,p_j)`.
- `J` is a space–time moment of the measure. **`dJ/dθ`, `θ ∈ ℝ^k`, `k ≈ 17`, is
  the quantity of interest**, by reverse-mode AD over the whole trajectory.

Three grids on `[0,T]`: creation times `𝒢_b` (~10²), step times `𝒢_t` (~10³),
forcing knots `𝒢_f` (~10³·²).

## 2. Hard constraints any algorithm must respect

These are properties of the implementation, verified in source, not preferences.

**(H1) Neither grid may depend on `θ`.** The step size is a passive `double` in
the adjoint: the controller is not differentiated. A gradient taken through an
adaptive run is therefore the exact gradient of *the model discretised on that
particular grid*, not of the adaptive procedure as a function of `θ`. Likewise a
creation time that depended on `θ` would contribute an adjoint term that is not
computed. So any `θ`-adaptive choice does not merely roughen `J_h(θ)` — it makes
the reported derivative answer a different question.

**(H2) `𝒢_b ⊂ 𝒢_t`, structurally.** The state dimension grows at each creation,
the solver reallocates, and the integrator refuses to place its clock anywhere
but a recorded step boundary. The realised step grid is
`{supplied} ∪ {creations} ∪ {events} ∪ {T}`; a supplied grid cannot omit one.

**(H3) The creation grid carries four roles at once**: the state dimension, the
quadrature abscissa, the adjoint's range count, and the index by which a
recorded trajectory is reshaped for replay. One vector, four consumers, matched
on exact equality.

**(H4) No data-dependent branch on an active value may enter the tape.**

**(H5) The available L-stable stepper carries no adjoint.** An implicit
treatment of the stiff chain is therefore new work, not a configuration change.

## 3. What is measured

**(M1) The derivative converges at the value's order where the population is on
the interior branch, and half an order slower where it is not.** Over seven
levels of `𝒢_b` from 12 to 697 on one shared `𝒢_t`: with 0% of member-instants
on a constrained branch, `J` gives 1.95–2.02 and `dJ/dθ` ~1.8; with 14%, `J`
gives ~1.87 and `dJ/dθ` **~1.34**.

**(M2) A mechanism for M1 that is not discretisation.** The constrained
branches' locations are set by a bracketing root-find whose stopping tolerance
is hard-coded and used as both absolute and relative, giving a bracket of order
`1e-4` in the control's own units; the value returned is the bracket midpoint.
On the interior branch the control's placement is **envelope-protected** — the
stationarity condition removes its movement from the derivative. On a
constrained branch there is no envelope: the control *is* the bound and its
movement enters at first order. So constrained members carry a derivative error
floored at `1e-4` that no refinement of any grid reaches, while interior members
keep converging.

**(M3) A converged value does not imply a converged derivative, and the gap is
conditioning.** At one creation count: 0.04% error in a functional, 0.9–2.5% in
one of its derivatives, 30–250% in another, one of them sign-wrong. Diagnosed:
that derivative is the sum of two opposing paths with elasticities +0.783 and
−0.791, so the answer is 1% of either term and the condition number is ~100. The
amplification is exact — `err(total) = 100·err(direct) + 101·err(transported)`
reproduces the observed error at six levels across four orders of magnitude and
three sign changes. The differentiation is *not* at fault: at the level where
the sign is wrong, the reverse sweep matches central differences of whole
re-runs to 5 digits and a forward tangent to 10.

**(M4) Only a fixed grid yields a usable derivative at all.** Finite differences
over `δ` from 1e-3 to 1e-9: an adaptive run has **no plateau at any `δ`**
(non-monotone from the second point, four orders and a sign error by 1e-9); a
fixed grid gives a clean monotone three-decade plateau.

**(M5) A step program does not transfer across creation-grid levels.** Captured
at one level and replayed one level finer: 18% wrong, derivatives sign-flipped.
Captured at the *finest* level — which yields a **literally identical** time grid
at every level, the levels being nested bisections — still 11% wrong at the
coarsest. Largest step per window within 1.5× of adaptive at every level, so
step *size* is not the explanation. The union of every level's program
reproduces every adaptive answer to 1e-5, at 2.5–4.5× the steps.

**(M6) Across `θ`, a captured grid holds a wide box but no forcing change.** The
full ±2× box in six parameters holds at a uniform step-shrink factor of 2; 58%
of it at factor 1. Across forcing realisations, zero transfer, and shrinking
does not help — the failure is step *placement*.

**(M7) Resolving the derivative requires coarsening, not only refining.** At the
operating creation count the error is ~1% and one bisection takes it to 0.27%,
which is the size of the finite-difference scatter. No order is estimable from
refinement alone; the orders in M1 are readable only because the grid was
coarsened four halvings below the operating point.

**(M8) The record is a mixture in time.** Quiescent stretches where `s ≡ 0`
exactly and the reconstruction is exactly zero (no kink, no forced stop); dense
stretches of small events; sparse stretches of large events; long absences. The
local regime is a computable property of the record. The knots that matter are a
strict, computable subset: those where `s ≠ 0` on at least one side.

**(M9) At the operating tolerance the time grid, not the creation grid,
dominates under intermittent forcing.** Same creation count, adaptive versus
pinned: 142% apart, while refining the creation grid 8× moves the answer 0.24%.

## 4. What is already settled, and need not be re-derived

- Error shares between two grids of different order should be **proportional to
  order**, not equidistributed — from equal marginal error reduction per unit
  cost under power-law errors and bilinear cost.
- Raising the order of the output quadrature *alone* is wrong here: the
  reconstruction and the functional use the same rule on the same grid, their
  `O(Δb²)` errors cancel in a ratio stable to three digits, and removing one
  makes the reported answer 2.4× worse.
- Multirate collapses into a linearly-implicit treatment of the chain, because
  the expensive coupling term is itself a function of the fast variable.

## 5. Questions

### 5.1 A grid construction with provable properties

Given a known record (M8), the hard constraints (H1–H3), and a target accuracy
in `dJ/dθ`: what is the **minimal well-understood construction** of `𝒢_t` and
`𝒢_b` whose properties can be stated in advance rather than measured after?

The guarantees that would be useful, in order: that the realised grid contains
every structurally required stop (H2) by construction rather than by check; that
its local density is set by a quantity computable from the record before the run
(the post-event relaxation rate is available in closed form from the event size);
that it is `θ`-independent by construction (H1); and that its error in `dJ/dθ` is
bounded by a computable quantity. Which of those four are achievable together,
and which is the first to give way?

### 5.2 Refinement that certifies a derivative

M3 and M7: the usual instruments mislead. A creation count that converges a
functional to 0.04% can leave a derivative 20–60× worse or sign-wrong; and the
operating point is too close to the noise floor for a refinement sequence to
yield an order at all without coarsening below it.

(a) What is the correct stopping rule for a refinement whose target is a
derivative? (b) M3's condition number — the ratio of a component path to the
total — is computable from quantities the sweep already forms. Is that a
sufficient a posteriori indicator, and what covers the cases where no such
decomposition is exposed? (c) Is there a principled reason to run a refinement
study *downward* from the operating point, as M7 forced, and does that change
what the sequence certifies?

### 5.3 An error floor on a subpopulation

M2: part of the population carries a derivative error floored by an inner
tolerance that no grid refinement reaches, and the floored fraction varies
through the record because it is driven by the forcing.

(a) Does a floored subpopulation produce a genuinely fractional convergence
order, or a plateau that a short sequence misreads as one — and what
distinguishes them? (b) What is the honest way to state, and to certify,
convergence of a quantity whose error is the sum of a converging part and a
floored part with a time-varying mixing fraction? (c) Given the floor is an
inner tolerance rather than a grid, what sets its correct value relative to the
discretisation error it must not dominate?

### 5.4 What M5 is telling us

A time grid that is *identical* — same times, to the bit — gives an 11% different
derivative when the creation grid beneath it changes. Step size is excluded as
the explanation. Under H3 the creation grid is also the state dimension, the
quadrature abscissa and the reshape index, so "changing the creation grid" is
not one change.

(a) What is the likely mechanism, and how would one distinguish the candidates
(the quadrature; the changed coupling through a differently-resolved
reconstruction; the replay's reshape; a genuinely different trajectory)?
(b) Does a *designed* grid — one placed from the record rather than captured
from a run — avoid it, or is the sensitivity structural? (c) Is the union of
levels' programs a legitimate instrument for a refinement study, or does it
answer a different question from any single level?

### 5.5 One grid across parameters, with a certificate

M4 and M6: a shared fixed grid is the only thing that yields a usable
derivative, it holds a wide parameter box under a uniform safety factor, and it
does not survive a change of record.

(a) What certificate should accompany a shared grid, given that the quantity to
certify is a derivative and the usual adjoint-weighted residual bounds the
*value*? Is a second-order object required, or is there a cheaper sufficient
condition? (b) What is the principled trigger for recapture inside an
optimisation, and can a trust region in `θ` be *proved* rather than measured?
(c) Since the record is fixed throughout a calibration, is "one designed grid
per record, recaptured on certificate failure" simply correct — and does a
designed grid have a provably wider validity region than a captured one?

### 5.6

Which of H1–H5 and M1–M9 is load-bearing for each answer? What guarantee is
available here that we have not asked for? And which of the four in 5.1 would
you sacrifice first?

## 6. What is free

- The forcing record is known in full in advance, and so is every creation time.
- A step boundary can be forced at any time, with no member attached, by an
  existing mechanism.
- The error norm has an unused derivative-weighted term
  (`rtol·(a_y|y| + a_dydt|h ẏ|) + atol`, with `a_dydt = 0`).
- Instrumentation naming the component that set each step's size, and the
  outcome of every step attempt, exists and is unread.
- `L ≤ 5`; dense linear algebra on the chain is free and its Jacobian is
  analytic and bidiagonal.
- The choice of grid is off the tape: it may depend on anything, including
  quantities from a previous solve — subject only to H1.
- The formulation may change if the change is declared and its effect on
  `dJ/dθ` is budgeted.
