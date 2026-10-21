# One system, its solver, and what the solver says

This answers four questions:
1. Does differentiating evolution's outcome change the adjoint formulation or
   the scheduling?
2. Can the sequence of linear systems be avoided?
3. Is there a representational inversion in solving, rejecting and deflating?
4. How do Caswell-type sensitivities map onto climate structures B and C, and
   what can be shared?

It ends with the formulation, data structure, algorithm and representation they
point to.

*Derived* means ours and checked by no one; *judgement* is marked; everything
else is cited, and the references were checked against Crossref.

## 1. The system

The evolved community is a list of species i = 1…m, each with traits θ_i (k of
them) and a birth rate b_i. Write x = {(θ_i, ln b_i)}. Its outcome is a root of

  G(x; c) = { g_i(x; c) = 0,  F_i(x; c) = 0 }  for every species i,

where:
- g_i is species i's selection gradient: its invader's ∇_{θ′} ln R′ at θ′ = θ_i,
  with the field held;
- F_i = ln J_i − ln b_i is its demographic balance, with the field responding;
- c is everything held fixed: the climate, the trade-off constants, the
  physiology.

Everything an analysis asks is linear algebra on derivatives of G at a root:

| question | object |
|---|---|
| is this an outcome? | G = 0 |
| how it shifts with c | dx*/dc = −G_x⁻¹ G_c |
| one output y's sensitivity to all of c (calibration, attribution) | dy/dc = −μᵀ G_c, with G_xᵀ μ = ∂y/∂x |
| is it an attractor of evolution? | the eigenvalues of M S, where S = g_θ − g_{ln b} F_{ln b}⁻¹ F_θ is G_x's Schur complement on the traits: the convergence Jacobian, regnans #89's `dg/dx`. M is the mutational covariance |
| is it uninvadable? | the invader Hessian ∂²ln R′/∂θ′² ≤ 0 on each species |
| where species are gained or lost | G_x singular along a path in c |

## 2. What changes in the adjoint formulation and the scheduling

**The adjoint: second order, and climate on the tape.**
- *G_x* needs derivatives of the g rows, which are second derivatives of ln R′.
  Chords of sweeps give them today (two sweeps per direction).
  - The exact form is a forward-over-reverse sweep: a tangent direction carried
    through the adjoint, giving a Hessian-vector product at roughly two to three
    sweeps.
  - Vendored XAD has the nested types (`FReal` inside `AReal`). odelia does not
    expose them; regnans's co-design asked for this as odelia#38.
- *G_c* needs the climate as an input on the tape. Rainfall today enters through
  `extrinsic_drivers.evaluate` as doubles. Its knots would become active inputs,
  alongside the traits. One reverse sweep then gives the sensitivity to every
  day's rain, and that is the attribution.
- **Only one direction at a time is ever needed** (§3). So the formulation needs
  Hessian-vector products and vector–Jacobian products, never a full Hessian.

**The scheduling.**
- Judge the entries of G (g and F) and the products the solver takes (G_x v),
  not every elasticity.
- Hold one grid and one recording across everything one root's solve evaluates:
  the chords in θ and in c, the invaders. That is OBJECTIVES' "Shared",
  extended from θ to c.
- Weight time-step error by the outputs' prices: the adjoint rows for y. That
  is goal-oriented control (Estep 1995; Cao & Petzold 2004, in
  `lateral-econ-physics.md`). For a derivative target it needs the second-order
  adjoint above.

## 3. Avoiding the sequence of linear systems

There are three ways, and they combine.

1. **Adjoint, not tangent, at the outer level** (*derived*).
   - Calibration and attribution want the sensitivity of a few outputs y to
     many inputs c (every day of rain, every physiological constant).
   - Solving G_x z = G_c per input is one solve per day of climate.
   - Solving G_xᵀ μ = ∂y/∂x is one solve per output, then one sweep for μᵀ G_c.
2. **That last sweep is a difference of two climate sweeps** (*derived*).
   - The g part of μᵀ G is Σ_i μ_iᵀ g_i: the derivative of species i's invader
     fitness along the trait direction μ_i.
   - Its gradient with respect to every day's rain is the climate-adjoint sweep
     of an invader displaced along μ_i, minus that of one displaced the other
     way, divided by the displacement.
   - So attributing an evolved trait to each day of climate costs one solve and
     a few sweeps.
3. **Piggyback on the iteration that finds the root.**
   - The adjoint of a contracting fixed-point iteration contracts at the same
     rate, so the adjoint can be iterated alongside the primal with no separate
     solve (Christianson 1994, doi:10.1080/10556789408805572; Griewank & Faure
     2003, doi:10.1007/978-3-642-55508-4_9).
   - regnans runs the canonical equation to reach x* anyway. Carrying μ along it
     costs one extra product per step.
   - Where solves remain, as along a continuation path in c, consecutive systems
     share a Krylov subspace (Parks et al. 2006).

## 4. The representational inversion

**It exists, and it makes the solver's behaviour the classification**
(*derived and judgement*). Solve G = 0 matrix-free by Newton–Krylov (Knoll &
Keyes 2004, doi:10.1016/j.jcp.2003.08.010). The Krylov (Arnoldi) iteration
builds a small Hessenberg matrix, and its eigenvalues (Ritz values) approximate
the operator's. Iterating on the Schur complement S does the same, since
S v = g_θ v − g_{ln b}(F_{ln b}⁻¹(F_θ v)) needs only an m × m solve beside the
products. Read them:

| what the solver does | what it means ecologically |
|---|---|
| converges; the Ritz values of M S have negative real parts | a convergence-stable singular community |
| converges; some have positive real parts | a repeller: a root evolution does not reach |
| needs few Krylov iterations | few eigenvalue clusters (Campbell et al. 1996), which is few selection modes only once preconditioned so that M S is near a multiple of the identity plus a low-rank part (`novelty-revisited.md` §5) |
| converges slowly in some directions | small eigenvalues: near-neutral traits, which is Falster et al. 2017's evolved near-neutrality |
| G_x singular or ill-conditioned along a path in c | a regime boundary: a species gained or lost, or branching |
| deflation finds further distinct roots | alternative stable communities: founder control, expected under one-sided light competition (`lateral-games.md` §3) |
| no convergence, with g discontinuous across a resident | a race with no gradient (constant rain); hand over to one-sided limits and pairwise invasibility |

So an analysis does not compute Hessians, Jacobian eigenvalues and PIPs
separately and then classify. It solves, and reads the classification off the
solve.
- **One caution.** Newton finds repellers as readily as attractors. The
  dynamics' own iteration, x ← x + M g, converges only to attractors. Run the
  Newton–Krylov solve for speed, then check with the Ritz values.

## 5. Caswell-type sensitivity under climate structures B and C

**B: independent weather per patch, at a common birth rate.**
- Each record r is one TF24 run in its own field. Fitness is the mean over
  records, R′ = E_r[R′_r], at a b common to all (Metz & Gyllenberg 2001).
- The sensitivity is the same mean: g = E_r[R′_r g_r]/R′. Each record's term is
  today's Caswell contraction, its density × reproductive value × rate
  sensitivity.
- Its G is the record average of today's G, so every derivative above is too.
- **Shared and incremental computation:**
  - records are independent, so they run in parallel;
  - adding records refines every quantity by an incremental mean;
  - differences between strategies on the same records converge faster than
    levels (the pulse-driven fitness post), and a sweep's gradient is the limit
    of such a difference.
- **B is also the base for C** (*judgement*). Weather that differs between patches
  leaves the regional seed rain stationary, which is what linearising C needs.
  It is a more realistic base than constant rain, which has no gradient at all
  (E8).

**C: B plus shared calendar weather.**
- Weather is split into a regional anomaly, shared by every patch, and local
  weather, independent between patches. The regional seed rain b(t) then varies.
- Linearising around B (Auclert et al. 2021), the regional response to an anomaly
  path is a convolution in calendar time, through the patch-age distribution:
  `(I − S_D 𝒥_b) δb = S_D 𝒥_c δc`.
- 𝒥_b and 𝒥_c are kernels of seed output against seed rain and against anomaly
  by lag. They come from B's recordings, by sweeps.
- An invader's fitness is then its long-run growth rate in the fluctuating
  region. Its mean shift from variability is second order, ½ tr(H C), the
  storage effect and relative nonlinearity together. Hutchinson's trace
  estimator gets it from Hessian-vector products (`lateral-econ-physics.md`
  §5).
- **Shared and incremental computation:**
  - one set of kernels serves every anomaly path, so any shock's response is a
    convolution;
  - a few large droughts are checked against full nonlinear runs.

## 6. The formulation that makes the rest look inevitable

**Formulation.** An eco-evolutionary outcome is a root of one system, G(x; c) = 0:
- each species' selection gradient with the field held;
- each species' demographic balance with the field responding;
- evaluated by individuals growing in a field the community makes.

Prediction, calibration, attribution and classification are then all
derivatives of G at a root:
- tangents for a few directions;
- adjoints for many inputs;
- spectra for stability.

**Data structure.** The recorded community has three layers:
1. **Primal:** each resident's recording, as rows of state and fields, batched
   over records (B) or over disturbance dates and anomalies (C).
2. **Dual:** adjoint rows per output, labelled by the kind of price: held
   (Nash) or responding (planner).
3. **Solution:** x*, the Krylov basis and Ritz values of G_x at x*, and μ for
   each named output, kept so that the next solve along a path starts from them.

Invaders, chords and climate sweeps all read the same recordings. A recording
is valid within a radius in (θ, b, c), and the solution object carries that
radius.

**Algorithm.**
1. Find a root by Newton–Krylov, matrix-free, with G_x v from chords or
   forward-over-reverse sweeps. Start from the predictor dx*/dc of the previous
   root along a path in c.
2. Classify from the Ritz values the solve built. Deflate to find further roots.
   Reject non-convergence with discontinuous g as a race, and hand it to
   pairwise invasibility.
3. Answer outputs by one transpose solve each, recycling the Krylov subspace,
   then one climate sweep pair for μᵀ G_c. Or piggyback μ on the canonical
   equation when that is the route to x*.
4. Continue in c with dx*/dc as the predictor. Detect the singular G_x where
   species change, and trace those boundaries (regnans #84).

**Representation.**
- The field stays inside, mediating.
- Analysis lives in trait × climate coordinates, where its claims do not depend
  on how the field is written.
- Prices are the dual of recordings.
- Climate is structured input on the tape: records, offsets and anomalies.
- Variance is part of the model where weather does not supply it.

**Why it covers realism, speed and elegance** (*judgement*).
- *Realism:* the two-clock climate (B, C), the variance that keeps gradients
  meaningful, and the mechanistic hydraulics and size structure kept intact.
- *Speed:*
  - one solve per output, not per input;
  - Krylov iterations proportional to the number of selection modes;
  - recordings and subspaces reused along every path;
  - sweeps at about two runs each.
- *Elegance:* one system and one solver. Its convergence, its iteration count,
  its singularities and its distinct roots are the ecology's categories: stable
  outcomes, the number of modes, regime boundaries, alternative communities.

## 7. What must be true for this to hold, and the first checks

1. **G_x v by chords agrees with differences of re-solved roots.** This is the
   smallest test in `opportunity.md` §6, dθ*/d(mean rainfall) for one trait.
2. **Krylov iteration counts on the preconditioned G_x** for lma alone, then
   two traits, then all traits on one climate. Their growth with k is H1's
   first number, read as clusters, not rank.
3. **Ritz-value classification** agrees with regnans's classifier on its toy
   models, which have closed forms (`regnans.md` §2).
4. **B with a few records** at a common b: whether the sensitivity's spread across
   records is small enough for the mean to be useful at a practical number of
   records.
