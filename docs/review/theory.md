# Fitness, coexistence and optimality as derivatives of one map

> Brought verbatim from `archive/trusting-curie` (21 October 2026). Paths under `docs/` that
> are not in this repository are on that tag. Two notes from later reviews:
> - C.4's envelope result (the leaf's implicit-function term drops out of the invader's
>   g at λ_o = 0) contradicts `literature.md` §7(d), which says g includes the operating
>   point's plastic response. C.4 is the more careful reading; it is untested.
>   `eeo-derivatives.md` §3 states the correction and its test.
> - E.1's ranking predates the reformulation in `site-selection.md`, which drops the
>   second-order programme (roots, classification, continuation) in favour of residuals at
>   observed sites.
> - Read against Johnson & Hastings (2022, arXiv:2201.07926 v1, the only version; 22 Oct):
>   - B.1's description of Ellner et al. ("removed and others retained", E shuffled) is not
>     in that preprint. It is probably from their companion, arXiv:2201.07960; unchecked.
>   - B.1 omits their replacement for scaling factors: the simple comparison (each resident
>     weighted 1/(S − 1)) or speed conversion factors a_i/a_s, a_j = 1/generation time.
>   - D.1's third ingredient, "buffered (subadditive) growth", is the reading they dispute.
>     The ingredient is non-additivity, ζ ≠ 0 of either sign; greater buffering lowers most
>     species' storage effect. So D.3's "a buffer, such as a seed-bank state" is not needed
>     for a temporal storage effect; what TF24 lacks is the covariance of environment and
>     competition across calendar time, which D.3's (2) supplies.
>   - B.2's "fitness–density covariance at landing: absent" holds in its landing-indexed,
>     per-generation bookkeeping. In their per-time bookkeeping over patches, a successional
>     niche is fitness–density covariance: their competition–colonization case, where the
>     colonist ends up in recently disturbed patches (their §4.5). Their §5.17 makes the same
>     point: which mechanism a process lands in depends on the scale of the bookkeeping.

A theory note on what TF24 in plant, with all-trait reverse-mode adjoints and
invaders that read a recorded field, can and cannot compute for adaptive
dynamics, modern coexistence theory (MCT) and eco-evolutionary optimality (EEO).

Every claim carries one of three labels:
- **[Established]**: a published result, with its citation (verified against
  Crossref, the publisher or a repository record; see References).
- **[Derived]**: my own derivation for this model. It follows from the
  definitions given here, but nobody has checked it or tested it numerically.
- **[Judgement]**: an assessment or ranking, open to dispute.

Numbers marked **[Measured]** come from plant-dev's own measurement notes:
`docs/measurements/regnans-roadtest/rootcause/README.md` (§§3, 7, 8),
`docs/measurements/equilibrium.md`, `docs/design-workflows.md` and
`docs/measurements/field-adjoint-map.md`.

---

## 0. The model as two maps

### 0.1 Notation

- θ ∈ ℝᵏ: the resident's traits (k ≈ 50 for TF24). θ′: an invader's traits.
- b: the resident's birth rate, the seed rain per unit area. The record c:
  the daily rainfall (and any other extrinsic drivers), indexed by patch age
  a ∈ [0, T], T = 40 yr.
- p(a) = p₀Π(a): the patch-age density. Π(a) is the probability that a patch
  survives undisturbed to age a (Weibull in plant).
- **The field** E(a) = (L(z, a), W_ℓ(a)): the light profile at every height z,
  and the soil water in every layer ℓ, at every rate evaluation of the
  resident's run (`docs/design-invader-environment.md`).
- An individual born at birth date s (the patch age at which it is introduced)
  has state x_s(a). In TF24 that state is height, cumulative hazard m,
  cumulative survival-weighted offspring φ, heartwood area, heartwood mass and
  storage (`tf24_strategy.h`, `state_names`). It evolves as

  dx_s/da = G(x_s(a), θ′, E(a)),  x_s(s) = x₀(θ′, E(s)),

  with dφ/da = f(x) e^{−m} Π(a)/Π(s), where f is the fecundity rate.
- σ(s; θ′, E) collects the survival of dispersal S_D and any establishment
  factor at s.

**The invader map** (field held):

 R′(θ′; E) = ∫₀ᵀ p(s) σ(s) φ_s(T) ds,  φ(θ′, E) := ln R′(θ′; E).  (0.1)

This is plant's `net_reproduction_ratio`. Each node's term is
`weighted_fecundity` = φ_s(T)·p(s)·S_D, and trapezium weights over s give the
integral. It is linear in what is introduced: invaders neither shade nor drink,
and the invader integrates no soil.

**The resident map** (field responding): E = 𝓔(θ, b; c). Its offspring production is

 J(θ, b) = b · R′(θ; 𝓔(θ, b)),  F(θ, b) := ln J − ln b = φ(θ, 𝓔(θ, b)).  (0.2)

**[Measured]** plant's invader at θ′ = θ reproduces R′ = J/b to 1e-12, and the
invader's ln R′ equals F at every birth rate tried (rootcause §§3, 7).

The demographic equilibrium is F(θ, b*(θ)) = 0. Write E*(θ) := 𝓔(θ, b*(θ)) and

 s(θ′, θ) := φ(θ′, E*(θ)),  (0.3)

the invasion fitness of θ′ against a resident θ at equilibrium.

### 0.2 Five identities [Derived]

All five follow from (0.1)–(0.3) by the chain rule, wherever the maps are
differentiable. ⟨·,·⟩ is the pairing of a field sensitivity with a field
perturbation, summed over heights, layers and patch ages.

- **(I1) The selection gradient is a held-field derivative.**
  g(θ, b) := ∂φ/∂θ′ (θ′, 𝓔(θ, b)) at θ′ = θ.
- **(I2) The field-responding derivative is the held one plus a field term.**
  F_θ = g + ⟨φ_E, 𝓔_θ⟩.
- **(I3) The birth-rate slope acts only through the field.**
  F_{ln b} = ⟨φ_E, 𝓔_{ln b}⟩.
- **(I4) The equilibrium curve.**
  d ln b*/dθ = −F_θ / F_{ln b}.
- **(I5) Selection is minus the invader's sensitivity times the equilibrium
  field's response.**
  g = −⟨φ_E, dE*/dθ⟩, where dE*/dθ = 𝓔_θ + 𝓔_{ln b} · d ln b*/dθ.
  Proof: differentiate F(θ, b*(θ)) ≡ 0 and substitute (I2) and (I3).

(I5) is the many-dimensional form of the "pessimisation" argument. Where the
field is effectively one scalar, g = 0 exactly where E* is extremal. Metz,
Mylius & Diekmann (2008) give the general conditions for an optimisation
principle (§C.1).

### 0.3 What the machinery provides

| tool | what it differentiates | cost, forward runs at b* [Measured] | status |
|---|---|---|---|
| resident sweep | ln J (so F) w.r.t. every parameter and ln b, field responding: F_θ, F_{ln b} | 2.3–2.9 | built |
| invader run + sweep | φ w.r.t. every θ′ at fixed E: g at θ′ = θ, or ∇_{θ′}φ anywhere | 0.64 + 2.05 | built (one invader per sweep; several needs the walked-patch fix) |
| two invaders at θe^{±h} | one component of g | 1.24 | built |
| chords of sweeps | rows of second derivatives (Hessian rows; columns of the convergence Jacobian) | about 6 per row at k = 1 | built from the above |
| field-coefficient hook | ∂(J or φ)/∂(coefficient scaling a field defect per panel and time band) | +12% of a sweep | spike patch, not merged |
| adjoints of every state on the tape | λ for each cohort, step and state | already computed in every sweep | not exposed |
| second reverse pass over the resident's tape with the field adjoints dropped | g for every trait, without an invader run | estimated 0.3 | not built |

The field is plain doubles in the invader. So an invader sweep differentiates
nothing in E; the derivative w.r.t. E needs the hook.

---

## A. Invasion fitness and adaptive dynamics

### A.1 Invasion fitness in this model

**[Established]** Invasion fitness is the long-term exponential growth rate of
a rare type in the environment that the residents set (Metz, Nisbet & Geritz
1992). In a fluctuating environment it is the dominant Lyapunov exponent of the
linearised invader dynamics.

**[Established]** Metapopulations with infinitely many patches and global
dispersal have a per-disperser reproduction number, R_m (Metz & Gyllenberg
2001; Gyllenberg & Metz 2001). It relates to fitness the way R₀ does in ordinary
population dynamics. Falster et al. (2017) define invasion fitness for this
class of size-structured, patch-age-structured forest model as the log of the
basic reproduction ratio,
R(x′, x) = ∫₀^∞ P(a) R̃(x′, E_{x,a}) da.
Here P(a) da is the probability that a dispersing seed lands in a patch of age
a, and R̃ is that seed's expected lifetime output of dispersing seeds. That is
(0.1).

**[Established]** Near the diagonal, the per-time growth rate ρ and ln R₀ are
related by ρ ≈ ln R₀ / T_r, with T_r the mean age at reproduction (attributed
to Durinx, Metz & Meszéna 2008 by Metz, Staňková & Johansson 2016). Gradients
therefore scale by 1/T_r: ∂ρ/∂θ′ = g/T_r at θ′ = θ.

**[Derived]** Climate here is a fixed function of patch age, and the
patch-age distribution is stationary. So the regional environment is constant
in time, and the deterministic per-seed R′ is an exact sign-equivalent fitness
proxy. No Lyapunov-exponent machinery is needed. §D covers what this excludes.

### A.2 One-dimensional classification

Let s(θ′, θ) be (0.3), with subscripts 1 and 2 for derivatives in the invader
and the resident argument. Because s(θ, θ) ≡ 0 along the equilibrium curve:

 s₁ + s₂ = 0, and s₁₁ + 2s₁₂ + s₂₂ = 0 on the diagonal.  (A.1)

**[Established]** (Eshel 1983; Christiansen 1991; Geritz et al. 1997, 1998):
- **Selection gradient:** g(θ) = s₁(θ, θ). Singular strategies θ* satisfy
  g(θ*) = 0.
- **ESS (evolutionary stability):** s₁₁(θ*, θ*) < 0.
- **Convergence stability:** dg/dθ = s₁₁ + s₁₂ < 0.
- **Mutual invasibility** of nearby pairs on either side: s₁₁ + s₂₂ > 0.
  By (A.1) this is equivalent to s₁₂ < 0.
- **Evolutionary branching point:** convergence stable but not ESS, i.e.
  s₁₁ > 0 and s₁₁ + s₁₂ < 0.
- **Pairwise invasibility plot (PIP):** the sign of s over (θ, θ′).

**What each needs, in this machinery [Derived]**

| quantity | derivative of | field | provided by |
|---|---|---|---|
| g = s₁ | φ in θ′ at θ′ = θ | held at E(θ, b) | invader sweep (all traits), two invaders (one trait), or the second reverse pass (not built) |
| s₁₁ | φ, second derivative in θ′ | held | chord of invader sweeps at θ′ = θe^{±h} on one record; or second differences of invaders |
| s₁₂ | φ_{θ′} along E*(θ) | responding, with b*(θ) | g at moved residents (each with its own run near b*) |
| dg/dθ | g along the equilibrium curve | responding | chords, see (A.2) |
| PIP | φ at many (θ′, θ) | held per θ | invader runs on each resident's record |

**A shortcut for convergence stability [Derived].** Differentiating g(θ, b*(θ)):

 dg/dθ = ∂g/∂θ|_b + (∂g/∂ln b) · d ln b*/dθ.  (A.2)

∂g/∂θ|_b is a chord of g over residents moved at a fixed birth rate. ∂g/∂ln b
is a chord over birth rates at a fixed θ. d ln b*/dθ comes from one resident
sweep by (I4). No equilibrium needs solving at a moved resident. The error is
O(h²) from the chords plus O(|F|) from standing off the curve. That error is
(∂g/∂ln b)·|F|/|F_{ln b}| = 3.4|F| on long drought [Measured].

**[Measured]** (long drought, b* ≈ 4.68, lma = 0.32, trait moved along the
trade-off, i.e. the hyperparameterisation):
- g = −23.79 (201 introductions).
- F_θ = −5.9 (108 introductions).
- F_{ln b} = −1.75, so d ln b*/d ln lma = −3.37.
- ∂g/∂ln b = −6.0.

So the birth-rate term in (A.2) contributes (−6.0)(−3.37) = +20.2 to dg/d ln lma.

The invader's held-field curvature was measured as −193 ± 5 at r = 1e-2, at a
fixed birth rate. It runs from −161 to −197 over ±3% of lma
(`design-workflows.md`). ∂g/∂θ|_b is unmeasured, so convergence stability at
this point cannot yet be decided. This resident is also not singular (g ≠ 0),
so these numbers classify nothing yet. They show the sizes of the terms.

### A.3 Many traits, and the canonical equation

**[Established]**

- **The canonical equation of adaptive dynamics** (Dieckmann & Law 1996), for
  an unstructured population:
  dθ/dt = ½ μ σ² n̂(θ) C(θ) ∂₁s(θ, θ).
  Here μ is the mutation probability per birth, σ² a variance factor of the
  offspring distribution (written as one constant in some presentations),
  n̂ the equilibrium population size and C the mutational covariance matrix.
  Champagnat, Ferrière & Méléard (2006) gave a rigorous derivation from
  individual-based processes. Durinx, Metz & Meszéna (2008) extended it to
  physiologically structured populations. Metz, Staňková & Johansson (2016)
  list the structured ingredients: equilibrium population size, mean age at
  reproduction, variance of lifetime offspring number, and the mutational
  covariance.
  - Here I write it as dθ/dt = κ(θ) C(θ) g(θ), with κ > 0 a scalar collecting
    those factors.
  - The direction of evolution is C g, and needs all k components of g.
  - In this metapopulation the equilibrium size enters through b* (and its
    patch-age structure). b* is supplied for every trait at once by (I4).
- **Many-dimensional stability.**
  - Mutant Hessian H := s₁₁ (k × k). The singular point is an ESS if H is
    negative definite.
  - Jacobian of the selection gradient along the resident:
    J_g := dg/dθ = s₁₁ + s₁₂.
  - Convergence stability depends on C: the eigenvalues of C J_g must have
    negative real parts.
  - Leimar (2009) defined *strong* convergence stability as convergence
    stability for every mutational covariance under the canonical equation,
    and *absolute* convergence stability as convergence stability under any
    gradualistic adaptive path. He showed that the latter is generically
    absent in more than one dimension.
  - Geritz, Metz & Rueffler (2016) summarise Leimar's result: negative
    definiteness of J_g (equivalently, of its symmetric part) is sufficient for
    robust strong convergence stability, and negative semi-definiteness is
    necessary.
  - They also analyse mutual invasibility near strongly convergence stable
    points in many dimensions. I do not restate their theorem.

**[Derived]** (A.2) generalises:

 J_g = ∂g/∂θ|_b + (∂g/∂ln b) (d ln b*/dθ)ᵀ,  (A.3)

a fixed-b Jacobian plus a rank-one correction. With m coexisting resident
species, the correction has rank m and uses the m × m demographic Jacobian
∂F_i/∂ln b_j (m resident sweeps).

The costs:
- The fixed-b Jacobian needs one moved-resident run per direction, each with an
  invader sweep that returns all k components (a column of J_g).
- The rank-one term needs one chord in b and one resident sweep.
- So J_g costs about k + 2 resident runs and k + 1 invader sweeps. Central
  chords double the runs.
- H costs k invader sweeps on one record (2k central). Several invaders can
  share one walk once the walked-patch fix lands.
- regnans's differences need 1 + 4k² mutants for H and 2k equilibria for J_g
  (`design-workflows.md`).

**[Judgement]** For k ≥ 2 this ordering of costs makes multi-trait
classification practical at all. At k = 50 the full matrices are still about
100 sweeps each, a day of computation at 77 s per forward.

### A.4 What it cannot compute

- **Non-smooth landscapes.** On constant rain, ln R′ is +7.40 at lma × 0.95,
  0 at × 1.00 and −39.85 at × 1.05. The central difference is −40 197 at
  h = 1e-4 and −8 161 at h = 1e-3, and the sweep gives −6.3 million
  (rootcause §8) [Measured]. ln R′ changes by about 8 within ±0.01%: a jump.
  - g does not exist there. Nor do s₁₁ or the canonical equation.
  - The relevant objects are one-sided limits of s at θ′ → θ±.
  - The cause is unknown. Candidates: a priority effect in an even-aged stand,
    a regime switch in the leaf model, or ties between invader and resident
    crowns in the light field.
  - **[Established]** Asymmetric competition can produce dynamics beyond the
    smooth classification. For example, Kisdi (1999) obtains branching under
    asymmetric competition.
- **Discretisation.** A sweep differentiates the discrete scheme, not the
  continuum.
  - On smooth climates sweeps match central differences to 1e-6 (rootcause §8).
  - The invader's gradient converges differently from ln J: at 108
    introductions it is 5.4ε off while ln J is 0.3ε off (rootcause §2)
    [Measured].
  - Curvatures by chords are stable only from about r = 1e-2.

---

## B. Modern coexistence theory

### B.1 The established framework

- **Stabilising and equalising mechanisms.** **[Established]** Chesson (2000a)
  classifies coexistence mechanisms as *equalising* (reducing average fitness
  differences) or *stabilising* (concentrating intraspecific relative to
  interspecific effects). Stabilising mechanisms are fluctuation-independent
  (e.g. resource partitioning) or fluctuation-dependent (relative nonlinearity
  of competition and the storage effect). The spatial theory (Chesson 2000b)
  adds spatial relative nonlinearity, the spatial storage effect and
  fitness–density covariance. The storage effect originates in lottery models
  (Chesson & Warner 1981).
- **The decomposition.** **[Established]** Following Chesson (1994), and in
  the notation of Johnson & Hastings (2022, arXiv:2201.07926, eqs 2–13):
  - The local finite rate of increase of species j is λ_j = g_j(E_j, C_j),
    with E_j an environment-dependent parameter and C_j a competition
    parameter.
  - g_j is expanded to second order about (E_j*, C_j*), giving coefficients
    α^{(1)}, β^{(1)}, α^{(2)}, β^{(2)} and ζ (the mixed second derivative).
    The truncated series is accurate when environmental fluctuations are
    small.
  - Averaging over space x and time t gives the invasion growth rate
    E_t[r_i] ≈ ΔE_i + Δρ_i + ΔN_i + ΔI_i + Δκ_i, each an invader–resident
    comparison.
  - **Relative nonlinearity:** ΔN_i ∝ ½[β_i^{(2)} Var(C_i) − …].
  - **Storage effect:** ΔI_i ∝ [ζ_i Cov(E_i, C_i) − …].
  - **Fitness–density covariance:** Δκ_i = E_t[Cov_x(ν_i, α_i^{(1)}E_i + β_i^{(1)}C_i)] − ….
  - Johnson & Hastings distinguish these *small-noise* mechanisms from *exact*
    ones, built on Chesson's (1994) standard parameters, which sum exactly to
    the invasion growth rate.
- **Simulation-based MCT.** **[Established]** Ellner, Snyder & Adler (2016)
  and Ellner, Snyder, Adler & Hooker (2019) replace the Taylor expansion with
  simulations. They partition growth rates into contributions from mechanisms
  and their interactions, computed by numerical runs "in which some mechanisms
  are removed and others retained". For the storage effect, E is shuffled to
  break its covariance with C (Johnson & Hastings's description of Ellner
  et al. 2016).
- **The critique.** **[Established]** Barabás, D'Andrea & Stump (2018)
  critique the stabilising/equalising decomposition: the concepts are useful
  when used judiciously, but have often been employed in an overly simplified
  way to justify false claims. They also introduce explicit limiting factors
  and a new definition of the scaling factors.
  - Johnson & Hastings (2022) add two further points:
    - Scaling factors are not unique when residents outnumber regulating
      factors, and can distort the other terms.
    - The storage effect "has little to do with bet-hedging or 'storage' via a
      robust life-history stage".
- **Chesson's update.** **[Established]** Chesson (2018) gives general
  definitions of species-level average fitness and of scaling factors. It
  defines stabilising mechanisms as deviations from a reference model in which
  no coexistence is possible, and shows how permanence and stochastic
  persistence theory use invasion rates in complex settings.
- **Niche theory with regulating factors.** **[Established]** Meszéna,
  Gyllenberg, Pásztor & Metz (2006) and Barabás, Pásztor, Meszéna & Ostling
  (2014) write growth rates as functions of *regulating factors*. A species'
  *sensitivity* is the derivative of its growth rate w.r.t. the regulating
  factors. Its *impact* is the derivative of the regulating factors w.r.t. its
  density. The robustness of coexistence depends on how independent these
  vectors are across species. (This is my paraphrase; I could not retrieve the
  2006 full text.)

### B.2 The mapping onto this model [Derived]

| MCT quantity | here |
|---|---|
| competition C_j | the field E = (L(z, a), W_ℓ(a)): one infinite-dimensional regulating variable shared by all species, which differ in where in (z, ℓ, a) they are sensitive |
| environment E_j | the record c(a), which reaches an individual through W (and any extrinsic drivers read directly). Species differ through hydraulics and rooting |
| location x | the landing patch age s. A seed lands in a patch of age s with density p(s); its lifetime success is w_i(s) := σ_i(s) φ_{i,s}(T) |
| time t | patch age a within a life. No regional time: the regional state is stationary |
| invasion growth rate | ln R′_i[E_j] = ln ∫ p(s) w_i(s; E_j) ds, per generation (divide by T_r for per time) |
| resident's growth rate | ln R′_j[E_j] = F_j = 0 at equilibrium |
| fitness–density covariance at landing | absent: every species lands with the same p(s) (global dispersal, no habitat choice). Redistribution after landing is inside w_i(s) |

In this bookkeeping:
- Relative nonlinearity becomes curvature of w_i in the competition it meets,
  integrated over landing ages.
- A storage-like term becomes the covariance over landing ages between a
  cohort's environment and the competition it meets, weighted by the mixed
  second derivative.
- Both are deterministic here: a cohort's environment and its competition are
  both fixed functions of s (§D).

### B.3 Invasion as a path integral in field space [Derived]

Take E_i, the field that species i makes at its own equilibrium, where
φ_i[E_i] = 0. For invader i against resident j:

 ln R′_i[E_j] = φ_i[E_j] − φ_i[E_i] = ∫₀¹ ⟨ δφ_i/δE |_{E_i + τ(E_j − E_i)}, E_j − E_i ⟩ dτ.  (B.1)

- **Exactness.** (B.1) is exact wherever φ_i is differentiable along the
  segment (the fundamental theorem of calculus). Its error is only the
  quadrature in τ.
- **Cost.** Each τ node is one invader run in an interpolated field, plus a
  field-hooked sweep. The interpolated field is a valid input because the
  invader reads the field as data and never re-solves it.
- **First order (one node at τ = 0):** ln R′_i[E_j] ≈ ⟨S_i, E_j − E_i⟩, with
  S_i := δφ_i/δE at E_i. This is the Meszéna form: i invades j where j's field
  is milder than i's own, in the directions i is sensitive to.
- **Mutual invasibility, to first order,** requires
  ⟨S_i, E_j − E_i⟩ > 0 and ⟨S_j, E_i − E_j⟩ > 0. That is impossible if S_i and
  S_j are parallel. Niche difference here means non-collinear sensitivity
  functions over (z, ℓ, a).
- **Many species.** With an infinite-dimensional field, Meszéna et al.'s bound
  on the number of robustly coexisting species is set by how close to linearly
  dependent the species' sensitivity functions are, not by a count of
  regulating variables.

### B.4 Functional derivatives of the invader's ln R′ [Derived]

Let λ_s(a) be the adjoint of a cohort born at s. It solves
dλ_s/da = −(∂G/∂x)ᵀλ_s with λ_s(T) = e_φ (§F). For a perturbation δE:

 δφ = (1/R′) ∫₀ᵀ p(s) [ δσ_s φ_s(T) + σ_s λ_s(s)·δx₀ + σ_s ∫_s^T λ_s(a)·∂_E G(x_s(a), θ′, E(a)) δE(a) da ] ds.  (B.2)

Exchanging the order of integration gives the sensitivity densities.

- **Light:**

 δφ/δL(z, a) = (1/R′) ∫₀^a p(s) σ_s λ_s(a)·∂G/∂L(z)|_{x_s(a)} ds,  (B.3)

  plus a boundary term at s = a from establishment and initial state.
  ∂G/∂L(z) is supported on the crown, z ≤ h_s(a), weighted by its leaf
  distribution.
- **Soil water** δφ/δW_ℓ(a) has the same form with ∂G/∂W_ℓ, which enters
  through the leaf's water supply in each rooted layer.

Causality is built in: the field at age a affects only cohorts born at s ≤ a.

Four properties:
- **Exact in what sense.** (B.3) is the exact first derivative of the
  continuum model. The sweep gives the exact derivative of the discrete scheme
  at each recorded slot (six per step), which converges to (B.3).
- **Feasibility [Measured].** The field-adjoint spike showed that contracting
  field adjoints with field defects predicts the field part of ln J at
  0.991–1.000× of the measured change. It predicts the invader's lma
  elasticity's field part at 0.94–0.99×, for +12% of a sweep. For the invader,
  that part is mostly light.
- **First order only.** Applied to a finite δE, (B.2) is a first-order
  approximation. (B.1) makes it exact.
- **Not available today.** The invader sweep does not differentiate E (plain
  doubles). The coefficient hook must be merged, at one coefficient per
  (panel, time band, channel) or per recorded slot.

### B.5 Attributing selection by birth date, patch age and channel [Derived]

**By birth date, exactly.** φ is the log of an integral that is linear in the
cohorts' contributions:

 g = (1/R′) ∫₀ᵀ p(s) ∂_{θ′}[σ_s φ_s(T)] ds,  (B.4)

an exact additive decomposition of g over birth dates s. plant already reports
each node's weighted fecundity, which gives R′ by s. The per-node gradients
are summed inside the sweep and would need exposing.

**By patch age, exactly.** Within a cohort, by the adjoint representation:

 ∂_{θ′}φ_s(T) = λ_s(s)·∂x₀/∂θ′ + ∫_s^T λ_s(a)·∂G/∂θ′ (x_s(a), θ′, E(a)) da,  (B.5)

an exact additive decomposition of each cohort's gradient over patch age a. It
is also exact over state components, since λ·∂G/∂θ′ is a sum over states. So
g is a double integral over (s, a) of (marginal value of state) ×
(direct effect of the trait on its rate). §F.2 interprets the first factor as
reproductive value.

**What this attribution means.** It credits the trait's *direct* action on
rates at (s, a), each weighted by its downstream consequence. It is unique
given the state variables. Change the state coordinates and the partition
across states changes, though the sum does not.

**By field channel, exactly.** (I5) gives
g = −⟨φ_E, dE*/dθ⟩ = −Σ_channels ∫ (δφ/δE_c)(dE*_c/dθ).
This splits selection into light and water parts, by height or layer and by
patch age. It needs the resident's field tangent along the equilibrium curve:
a forward tangent of the resident run that outputs the field, with the b*
response from (I4). That is one tangent per trait direction, and it is not
built. The alternative is §B.6.

### B.6 The two-stage adjoint [Derived]

Seed the resident's reverse pass with the invader's field sensitivities as the
cotangent of the field, i.e. add δφ_i/δE(a) to the adjoint of each recorded
field at each rate evaluation. That pass returns

 dφ_i/dp|_{via field} = ⟨δφ_i/δE, ∂𝓔/∂p⟩

for every resident parameter p at once: every resident trait, ln b, and every
day's rainfall (the record enters the resident's tape as an input). The cost
is one invader sweep with the hook plus one resident reverse pass.

It yields:
- **Off the diagonal:** the sensitivity of invader i's fitness to every
  trait of resident j, i.e. competitive effect functions. This is what
  Barabás et al. (2014) need for the sensitivity of coexistence.
- **The climate-sensitivity kernel of invasion:** dφ_i/dc(day) through the
  resident.
- **On the diagonal:** dφ/dθ_res = s₂ at fixed b. Then s₂ = −s₁ along the
  curve once the b-response (I4) is added. This gives a consistency check.

The pass is first order in every perturbation. It is not built: the resident
tape must record the field as a differentiable output, which the spike hook
approximates by coefficients.

### B.7 Can adjoints decompose coexistence mechanisms? [Derived, Judgement]

- **Yes, for first-order mechanisms.** The linear terms (ΔE_i and Δρ_i in
  Johnson & Hastings) follow from first derivatives. So do the first-order
  invader–resident comparison ⟨S_i, E_j − E_i⟩ and its attribution over
  (z, ℓ, a).
- **No, for fluctuation-dependent mechanisms, from one sweep.** Relative
  nonlinearity and the storage effect are second-order: curvatures β^{(2)} and
  ζ times variances and covariances. One sweep at one field gives slopes only.
  They need one of:
  - second derivatives, as chords of field-hooked sweeps (two sweeps per
    direction in field space);
  - (B.1) path integrals between the actual field and a field with the
    variation removed;
  - Ellner-style simulations with synthetic fields: the field averaged or
    shuffled over landing ages.

  The third is natural here, because a synthetic field costs one invader run
  and no resident solve. **Limitation:** all invaders in one plant run read one
  field timeline. Giving each landing cohort its own competition trajectory
  (as "remove the variation across s" requires) needs a per-cohort field
  lookup, or one invader run per landing date with a shifted field. Neither
  exists.
- **Non-uniqueness stays.** The choice of scalar E_i(s), C_i(s) summarising
  infinite-dimensional trajectories is not given by the model. Neither are the
  reference values or the resident weights. This is the critique of Barabás
  et al. (2018) and Johnson & Hastings (2022), and adjoints do not remove it.
  The field-space form (B.1) avoids the scalar choice by working with the
  whole field, but then drops the E/C labels.

---

## C. Eco-evolutionary optimality

### C.1 The established positions

- **EEO.** **[Established]** EEO proposes that plant traits and behaviour
  follow optimality principles from natural selection, giving parameter-sparse
  vegetation models. Franklin et al. (2020) propose natural selection,
  self-organisation and entropy maximisation as organising principles.
  Harrison et al. (2021) judge EEO for photosynthesis, respiration and stomatal
  behaviour ready for global models, and EEO at the community level an open
  research area.
- **Stomatal optimality criteria:**
  - Cowan & Farquhar (1977): maximise carbon gain for a given water use, i.e.
    A − λE with λ the marginal carbon cost of water.
  - Prentice et al. (2014): least-cost, balancing the costs of carbon gain and
    water transport.
  - Sperry et al. (2017): gain–risk, photosynthetic gain against hydraulic
    cost.
- **Evolutionary games in plants.** **[Established]** Selection under
  competition differs from optimisation of a fixed objective:
  - height: Givnish (1982); Falster & Westoby (2003);
  - roots: Gersani et al. (2001), "tragedy of the commons as a result of root
    competition";
  - water use: Zea-Cabrera et al. (2006); Wolf, Anderegg & Pacala (2016),
    where carbon maximisation without a water price is the ESS under
    competition for water;
  - allocation: Dybzinski et al. (2011);
  - reviews: McNickle & Dybzinski (2013); Anten & Vermeulen (2016).
- **When evolution optimises.** **[Established]**
  - Metz, Nisbet & Geritz (1992): evolution has no general tendency to
    maximise fitness.
  - Mylius & Diekmann (1995): optimisation needs to be specific about density
    dependence.
  - Metz, Mylius & Diekmann (2008): an optimisation principle exists only if
    the strategy affects fitness in an effectively monotone, one-dimensional
    way (equivalently, the environment does). r or R₀ is maximised only under a
    still more special structure.

### C.2 Three objectives, and when they agree [Derived]

1. **A fixed-environment objective:** maximise φ(θ′; E) at a given field.
   This is the "best response" to a field.
2. **The ESS:** θ* with θ* = argmax_{θ′} φ(θ′; E*(θ*)) locally, i.e. g = 0 and
   s₁₁ < 0. It is the best response to the field it itself makes (a local Nash
   equilibrium).
3. **A stand objective:** maximise the equilibrium seed rain b*(θ). By (I4)
   its gradient is −F_θ/F_{ln b}. F_{ln b} < 0 (−1.75 [Measured]), so it
   points along F_θ, the field-responding derivative of the stand's own
   offspring production at fixed b.

By (I2), at any θ:

 F_θ − g = ⟨φ_E, 𝓔_θ⟩ =: Φ(θ),  (C.1)

the **field term**: how a change in the stand's traits changes the field it
grows in, valued by an individual's sensitivity to that field.

- At the stand optimum θ_G (F_θ = 0): g(θ_G) = −Φ(θ_G).
- So θ_G is singular only if the field term vanishes there.
- If Φ > 0 near θ_G (a higher trait relieves competition), selection pushes
  the trait below the stand optimum. This is the formal statement of a
  tragedy of the commons: the ESS over-invests in the competitive direction.
- An EEO model that optimises a stand-level quantity with the environment
  responding computes θ_G, not the ESS.
- An EEO model that optimises an individual's performance at the *observed*
  field computes a best response. It equals the ESS only if the observed field
  is the one the optimal strategy itself makes, and the objective is lifetime
  fitness (not, say, annual carbon gain).

**A test of an optimisation principle [Derived].** Suppose a b*-maximisation
principle held, in the sense of Metz et al. (2008), with ψ = b*. Then
g = c·∇ln b* with c > 0, so g would be parallel to F_θ in trait space.
- In one dimension this is only a sign condition, and the measured numbers
  (g = −23.8, F_θ = −5.9) satisfy it with c ≈ 7. One trait cannot refute the
  principle.
- With k traits, the angle between g and F_θ is a direct test. Both vectors
  come from one invader sweep and one resident sweep, about 5 forwards for all
  50 traits. A nonzero angle refutes every optimisation principle based on b*.

### C.3 What −5.9 and −23.8 mean [Derived, Judgement]

**[Measured]** Long drought at b*:
- Along the trade-off (the hyperparameterisation): the stand's
  field-responding elasticity F_θ = −5.9 against the held-field selection
  gradient g = −23.8.
- With lma moved alone: −9.96 against −37.1.
- In both cases F_θ/g ≈ 0.25–0.27, so the field term Φ is +17.9 (trade-off)
  and +27.1 (lma alone).
- **Caveat:** the trade-off pair was taken at different introduction counts
  (108 and 201) on the same climate. Its comparison is accurate to the grid
  errors in rootcause §2.

**Reading:**
- A rare individual with 1% lower lma gains about 0.24 in ln R′ in its
  residents' field. A stand of such individuals gains only about 0.06 in its
  own offspring production at fixed seed rain: the stand's own field is then
  more competitive (more leaf area shading and drawing water) and absorbs
  three-quarters of the gain.
- By (I5), the same numbers show selection acts almost entirely through
  competitive displacement of the field: the field's response at the new
  equilibrium is worth −g = 23.8 = 17.9 + 1.75 × 3.37. (This sum is an
  algebraic restatement of (I4), not an independent check.)
- **Ecologically:** at this point both objectives say "lower lma". Selection
  says so about four times more strongly than the stand's interest does. If
  Φ stays positive, the ESS lies at lower lma than the b*-maximising trait:
  over-investment in cheap, fast leaf area, as in the leaf-area and height
  games cited in C.1.
- Whether the directions differ (not just the magnitudes) can only be seen
  with several traits (C.2).

### C.4 Nested optimisation [Derived]

TF24 solves a leaf operating point u* (the root-collar or stem water
potential) at each rate evaluation, per crown layer:

 u*(x, E, θ) = argmax_u π(u; x, E, θ),  π = A(u) − Θ(u) − λ_o E(u),

where:
- A is net assimilation;
- Θ(u) = TF24_cost_scale·(1 − f)^{β₂} is the hydraulic cost;
- λ_o is a water price, zero by default (`phylloptim` `leaf_model.hpp`;
  `TF24_floor`).

From the plant source (`tf24_strategy.h`):
- **Carbon:** net production is built on the layer-integrated profit plus the
  `shadow_cost` λ_o E. So the carbon the plant keeps is A − Θ. Θ is realised
  carbon, while λ_o is a price that changes the aperture and loses no carbon.
- **Water:** the operating point also sets per-layer soil uptake, which feeds
  the patch's water balance in a resident run. An invader integrates no soil.

**Implicit function theorem.** At an interior optimum,
du*/dθ = −π_uu⁻¹ π_uθ (the reverse sweep implements this). It fails where
π_uu = 0, and it is one-sided at regime switches (e.g. hydraulic shutdown).

**Envelope theorem [Established, standard].** d π(u*)/dθ = ∂π/∂θ: the
response of u* does not change the optimised value to first order.

**Consequence for the invader [Derived].** At λ_o = 0, the invader's rates
depend on u* only through P, which is built on the maximised π (summed over
crown layers, each with its own operating point). So at interior operating
points, dG/dθ′ = ∂G/∂θ′: the implicit-function term does not contribute to the
invader's selection gradient.
- It does contribute to the resident's F_θ, through soil uptake and so the
  field.
- At pinned operating points (42 of 240 feasible golden rows sit on a bound),
  du*/dθ = 0 locally, so the conclusion holds there too.
- **Testable:** an invader sweep with the leaf's implicit-function terms
  removed should return the same g, to rounding, wherever no operating point
  switches regime.
- **Caveat:** this rests on reading the code paths named above. If anything
  else in the invader's rates reads the operating point, it fails.

**What differentiating through both levels means.** The outer derivative
measures how fitness responds to a trait, given that the leaf keeps
re-optimising.
- **For a pure decision parameter at an interior optimum** (one entering only
  the decision, like λ_o), that response is zero to first order (envelope
  theorem).
- **For a parameter entering both decision and realised carbon** (like
  TF24_cost_scale, β₂ or the vulnerability curve), it is nonzero and needs
  both levels.

§F.4 turns this into a test of EEO criteria.

---

## D. Fluctuating climate

### D.1 Established theory

- **Fitness in a fluctuating environment.** **[Established]** It is the
  long-run growth rate of a rare type, a dominant Lyapunov exponent (Metz,
  Nisbet & Geritz 1992; Tuljapurkar 1990).
- **Periodic environments.** **[Established]** R₀ is the spectral radius of a
  next-generation operator over the phase of the cycle (Bacaër & Guernaoui
  2006).
- **The storage effect.** **[Established]** It requires:
  - species-specific responses to the environment;
  - covariance between environment and competition;
  - buffered (subadditive) population growth.

  It appears in temporal form (Chesson & Warner 1981; Chesson 1994) and in
  spatial form (Chesson 2000b). Johnson & Hastings (2022) argue that the
  essential ingredient is specialisation on different states of a varying
  environment, not a long-lived stage.

### D.2 What the record is here [Derived]

**Every patch replays the same record from its disturbance.** A drought on day
d of the record hits every patch at age d. So:
- The regional state (b, the patch-age distribution, the population) is
  stationary. Climate variation is variation *along succession*, which in
  Chesson's terms is spatial: patches of different ages see different climate
  on the same calendar day.
- Within a patch, climate and stand development are both functions of a,
  so their association is fixed by the record's alignment with succession. A
  drought in year 2 always meets a stand of seedlings.
- Different records (the bank of eight daily-weather seeds that sets ε in
  `OBJECTIVES.md`) are separate deterministic worlds, each with its own b*.
  Their spread measures sensitivity to the realised record. It is not
  stochastic fitness.

**What it cannot represent:**
1. Synchronous (calendar-time) variation: a regional drought year that hits
   all patches at once, whatever their age.
2. Different climates in patches of the same age.
3. Temporal fluctuations of the regional seed rain b(t), and with them the
   temporal storage effect and temporal relative nonlinearity.
4. A seed bank or dormancy as a buffer: seeds produced are dispersed at once
   (S_D) and establish or die.

**What it can represent:**
- A deterministic "successional storage" structure: a covariance over landing
  ages between a cohort's climate and the competition it meets.
- Spatial relative nonlinearity across patch ages.
- The successional niche itself (Pacala & Rees 1998; Falster et al. 2017).

### D.3 What a storage effect would need, and its cost [Derived]

1. **Independent records per patch.** Each disturbance draws a record ω from a
   stationary process, independently across patches. Infinitely many patches
   and global dispersal keep the metapopulation deterministic and stationary.
   - The invader's fitness is the *arithmetic* mean over records,
     R′_i = E_ω[R′_i(ω)].
   - The residents' equilibrium is E_ω[J(b, ω)] = b at one common b.
   - Gradients average linearly.
   - Jensen's inequality makes ln E_ω R′ ≥ E_ω ln R′: averaging ln J across
     the bank is not the fitness of this world.
   - Environment and competition now covary across patches of the same age, so
     a spatial storage effect can arise.
   - **Cost:** M resident runs at a common b and M invader runs, with no new
     machinery. This is the cheapest substantive extension.
2. **Calendar-time climate.** A patch disturbed at calendar time t₀ sees
   c(t₀ + a). The seed rain b(t) then varies, and fitness is a Lyapunov
   exponent of a renewal process in t₀.
   - For a periodic record of period P, R₀ is the spectral radius of a
     next-generation operator K(t₀, t₀′) over disturbance phase
     (Bacaër & Guernaoui 2006).
   - Building K needs resident runs at many phases, coupled through a periodic
     b(t).
   - **Cost:** a multiple of the phases resolved, and a new equilibrium
     problem (a periodic b(t), not a scalar b*).
3. **A buffer**, such as a seed-bank state, for the temporal storage effect in
   its classical form.

---

## F. The adjoint state as reproductive value, and EEO criteria from costates

### F.1 Established results

- **[Established]** Fisher (1930) defined reproductive value: the expected
  future contribution of an individual of a given age.
- **[Established]** Caswell (1978) gave the eigenvalue sensitivity of a
  projection matrix,
  ∂λ/∂θ = vᵀ(∂A/∂θ)w / ⟨v, w⟩,
  with v the reproductive-value (left) and w the stable-structure (right)
  eigenvectors. For integral projection models the sensitivity kernel is
  v(z′)w(z)/⟨v, w⟩ (Ellner & Rees 2006).
- **[Established]** Hamilton (1966) showed that the force of selection on
  survival at age a scales with the reproduction that remains after a. It
  declines with age.
- **[Established]** Life history as optimal control (Pontryagin's maximum
  principle):
  - Taylor et al. (1974); León (1976); Schaffer (1983), with residual
    reproductive value as the terminal term;
  - King & Roughgarden (1982) and Iwasa & Roughgarden (1984), on allocation
    between vegetative and reproductive growth and between shoot and root;
  - review: Perrin & Sibly (1993).
- **[Established]** Metz, Staňková & Johansson (2016) write the selection
  gradient of a function-valued life-history trait as survivorship times a
  "fitness return". The costates are sensitivities of lifetime offspring
  number to state (body mass, survival). Setting the gradient to zero is the
  marginal value principle, equivalent to the local form of Pontryagin's
  maximum principle.
- **[Established]** Feichtinger et al. (2011) identify reproductive value as
  part of the shadow price of population in demographic optimal control.
- **[Established]** Discrete adjoints of Runge–Kutta schemes are consistent
  approximations of the continuous costates under conditions on the scheme
  (Hager 2000).

### F.2 The invader's adjoint is reproductive value [Derived]

Fix the field E (the invader case). For the cohort born at s:
- Let J_a(x) := φ_s(T) − φ_s(a) be the offspring still to come from age a, as
  a function of the state at a, with the dynamics after a fixed.
- The adjoint solves dλ_s/da = −(∂G/∂x)ᵀλ_s with λ_s(T) = e_φ.
- **Gradient of the cost-to-go (standard in optimal control):**
  λ_s(a) = ∇_x J_a(x_s(a)) for every component except φ, whose adjoint is 1.

Write ℓ_s(a) = e^{−m(a)} Π(a)/Π(s) for survivorship from s to a. Let V_s(a, x)
be the reproductive value of an individual alive at a in state x, i.e.
expected future offspring conditional on survival. Then J_a = ℓ_s(a) V_s(a, x),
and:

- **Hazard component:** λ_m(a) = −ℓ_s(a) V_s(a), because ∂ℓ/∂m = −ℓ.
  The adjoint of cumulative hazard is minus survivorship times reproductive
  value. This is Hamilton's force of selection on mortality at age a, in R₀
  form: ∂R′/∂μ(a) = −∫_a^T ℓ f.
- **Every other component:** λ_x(a) = ℓ_s(a) ∂V_s/∂x. For height, storage and
  heartwood this is survivorship times the marginal reproductive value of that
  state.

So the reverse sweep's adjoint is, exactly, reproductive value in the
continuum. In the discrete scheme it approximates it to the scheme's order.
It is the survivorship-weighted gradient of reproductive value w.r.t. state.

**The selection gradient as a generalised Caswell formula.** Substitute into
(B.4)–(B.5):

 g = (1/R′) ∫₀ᵀ ∫_s^T n(s, a) ∇_x V_s(a)·∂G/∂θ′(x_s(a), θ′, E(a)) da ds + (birth terms),  (F.1)

where:
- n(s, a) := p(s) σ_s ℓ_s(a) is the density of the invader's individuals born
  at s and alive at a, per seed landing. This is the analogue of the stable
  structure w.
- ∇_x V is the analogue of reproductive value v.
- ∂G/∂θ′ is the analogue of ∂A/∂θ.
- R′ = ⟨reproductive value, births⟩ is the analogue of the normalisation
  ⟨v, w⟩.
- The birth terms are ∫p ∂σ/∂θ′ φ_s(T) ds + ∫p σ λ_s(s)·∂x₀/∂θ′ ds.

(F.1) is exact: it is the derivative, not a first-order estimate.
- **Why it holds despite nonlinear individuals:** the invader population is
  linear in its own density (rare, in a held field). The individuals'
  nonlinear, size-structured, time-varying dynamics enter only through the
  linearisation along each trajectory, which the adjoint ODE carries.
- **Why Caswell's formula is a special case:** for a linear time-invariant
  model, V is linear in state and the time integrals collapse to eigenvector
  products.

### F.3 The resident's adjoint: own value plus field externality [Derived]

The resident's sweep differentiates ln J with the field responding. A cohort's
state then also acts on everyone else's fitness through the field it makes.

The adjoint of a resident node's state, divided by the node's density weight,
has two parts:
- **The individual's own marginal reproductive value.** At θ′ = θ this equals
  the invader's λ, because the trajectories coincide.
- **An externality term:** the marginal effect of that individual's state on
  the field, valued by every cohort's field sensitivity.

So

 λ^{res} − λ^{inv} = the marginal externality of the state,  (F.2)

e.g. how much one more unit of an individual's height or root uptake at
(s, a) costs the rest of the stand in offspring. This is the tragedy of the
commons resolved by state, age and birth date.

**Cost:** both adjoints are on tapes already computed (one resident sweep, one
invader sweep at θ′ = θ). Neither is exposed. Normalising node adjoints to
per-individual values needs the node's density and quadrature weight.

### F.4 Deriving or testing EEO criteria from costates [Derived]

**The control problem.** A rare invader chooses an operating point u(a) at
each age in a held field. The lifetime-optimal rule maximises the Hamiltonian
pointwise (Pontryagin):

 H = λ_s(a)·G(x, u, θ′, E(a)).

In TF24, u enters the invader's G only through net production P(u) (§C.4), so

 ∂H/∂u = μ_C(a) ∂P/∂u,  μ_C := λ·∂G/∂P,

where μ_C is the marginal fitness value of carbon at (s, a). Wherever μ_C > 0,
maximising H is the same as maximising P, i.e. maximising A − Θ.

**Result:** in TF24 at λ_o = 0, the leaf's instantaneous profit maximisation
satisfies Pontryagin's condition for the invader's lifetime R′. The costate
factors out because u reaches fitness through one scalar. This is the general
condition under which an instantaneous criterion is lifetime-optimal:
- the control affects the Hamiltonian through one scalar currency;
- that currency has a positive marginal value.

**Prediction (cheap and sharp):** ∂ln R′/∂λ_o = 0 at λ_o = 0 for the invader,
at interior and pinned operating points alike. That is one invader sweep.

**The stand's price of water.** For the resident (field responding),
transpired water leaves the shared soil. The stand-optimal leaf would maximise
A − Θ − λ_W^{stand}(a) E, with

 λ_W^{stand}(a) = (∂ln J/∂W(a)) / (∂ln J/∂P(a)),

the stand's marginal rate of substitution between soil water and carbon, from
the resident's costates (per unit leaf area and time, summed over layers by
uptake). That is a Cowan–Farquhar λ, now derived rather than assumed, and
varying along the record.
- The ESS price is zero: the invader's held-field water value for its own
  transpiration is zero.
- The stand price is λ_W^{stand}.
- The gap between them is the commons in stomatal behaviour. This reproduces,
  inside one model, the argument of Wolf, Anderegg & Pacala (2016) and
  Zea-Cabrera et al. (2006).

**Literature that derives λ from a longer horizon [Established]:**
- Cowan & Farquhar (1977): λ as the marginal carbon cost of water under a
  water budget.
- Mäkelä, Berninger & Hari (1996): optimal control over the expected length of
  a drought. It gives a physical interpretation of the cost of water, which
  depends on soil water.
- Manzoni et al. (2013): λ linked to soil-moisture dynamics and CO₂.
- Lu, Duursma & Medlyn (2016): optimal stomatal behaviour maximising carbon
  gain under stochastic rainfall. The solution method was not verified here.
- Wolf, Anderegg & Pacala (2016): the ESS under competition for water.

All of these maximise carbon, an intermediate currency. The costate framework
supplies the conversion to fitness (μ_C) and tests whether carbon is the right
currency at all.

**Tests of other criteria:**
- **Gain–risk (Sperry et al. 2017).** Its weights (normalisation by A_max and
  by k_max − k_crit) would be the costate ratio μ_D/μ_C for a persistent
  hydraulic-damage state D.
  - TF24 has no such state: Θ is an instantaneous, realised carbon cost, and
    "risk" has no lasting consequence beyond carbon.
  - So within TF24 the test is a consistency check, not a discriminating one.
  - A discriminating test needs a damage state with recovery. Then the costate
    gives the right instantaneous weight μ_D(a)/μ_C(a), and one can ask
    whether a fixed normalisation matches it across ages, sizes and the
    record.
- **Least-cost (Prentice et al. 2014).** It assumes a ratio of unit costs of
  transpiration and carboxylation capacity. With both as states or
  parameters, the costate ratio is a time- and size-varying field. Its
  constancy is the test.

### F.5 What this makes computable [Derived, Judgement]

1. **Maps of reproductive value** V and of its state gradients over
   (birth date × patch age × state), for invaders on any record. Also the
   survivorship-weighted force of selection on mortality, storage and height
   by age.
2. **"When and where selection acts" for each trait:** the integrand of (F.1)
   over (s, a, state), and its split by field channel (B.5). Exact for the
   gradient.
3. **The marginal values of water and light over a climate record:** δφ/δW,
   δφ/δL from the invader (field hook), and λ_W^{stand}, μ_C from the
   resident's costates.
4. **Tests of EEO criteria:**
   - ∂ln R′/∂λ_o = 0 (consistency);
   - the stand's water price against Cowan–Farquhar λ and its dependence on
     soil water (Mäkelä et al. 1996; Manzoni et al. 2013);
   - with a damage state, gain–risk weights against costate ratios.

**Limits:**
- Costates exist along smooth trajectories. At regime switches of the leaf
  (shutdown, pinned bounds) the state adjoint stays defined, but the control's
  sensitivity is one-sided.
- Node adjoints need normalising by density and quadrature weight.
- In the discrete scheme, costates converge to the continuum ones only at the
  scheme's order.
- The resident's costates are not evolutionary reproductive values: they
  include the externality (F.2).

---

## E. Conclusions

### E.1 What exact all-trait adjoints plus recorded-field invaders make computable [Judgement on the ranking]

Ranked by ecological significance. Each entry says what is exact and what it costs.

1. **The full selection gradient g over all ~50 traits at the resident's
   equilibrium, and with it the direction of evolution C g.**
   - Exact (to grid accuracy).
   - Cost: 2.7 forwards, or an estimated 0.3 with the second reverse pass,
     against about 60 by differences.
   - Says which traits are under selection, which way, and how strongly. A
     one-trait analysis cannot.
2. **The field term Φ = F_θ − g for every trait: an ESS-versus-stand-optimum
   ("tragedy of the commons") measure, and its resolution by state (F.2).**
   - Exact.
   - Cost: one resident sweep plus item 1.
   - The angle between g and F_θ tests optimisation principles based on b*
     directly (C.2).
   - Turns a classical qualitative argument (height, roots, leaf area, water
     use) into a number per trait and per climate.
3. **Where and when selection acts.**
   - The exact attribution of g over birth date, patch age and state: costates
     as reproductive value (F.1).
   - Its split into light and water by height or layer and age (B.5, needs the
     field hook and a field tangent or the two-stage adjoint).
   - Answers "is lma selected through establishment or through late shade?"
4. **Sensitivity of fitness, equilibrium seed rain and invasion to the climate
   history:** d ln J/dc(day) from the resident sweep, and dφ_i/dc(day) through
   the two-stage adjoint (B.6).
   - First order.
   - Only parameter gradients are exposed today. The record is on the tape but
     not returned.
5. **Coexistence sensitivity and niche structure:** sensitivity functions
   S_i(z, ℓ, a) from invader field adjoints, impact functions from resident
   field responses, and the first-order and path-integrated
   invader–resident comparison (B.1).
   - Turns "niche difference" into measurable non-collinearity over the
     field's domain (Meszéna et al. 2006; Barabás et al. 2014).
   - First order, or exact by path integration at a few runs per node.
6. **Classification of singular strategies in several traits:** the mutant
   Hessian by chords of invader sweeps, and the convergence Jacobian as a
   fixed-b Jacobian plus a rank-one b correction (A.3).
   - Gives ESS, convergence stability, Leimar's strong convergence stability,
     and the conditions for branching.
   - O(k) sweeps instead of O(k²) runs. Second order by chords (O(h²), stable
     from h ≈ 1e-2).
7. **Tests of EEO criteria against costate prices:** the λ_o consistency test,
   the stand's water price as a derived Cowan–Farquhar λ, and gain–risk or
   least-cost weights once a damage state exists (F.4).
8. **MCT bookkeeping:** first-order mechanism terms with attribution; exact
   decompositions via path integrals or synthetic-field invader runs, which
   need a per-cohort field.
   - Second-order mechanisms (relative nonlinearity, storage) are not given by
     one sweep (B.7).

### E.2 The reframing [Judgement]

The theories in A–C and F are all written in terms of an environmental
feedback loop: a resident sets an environment, and fitness is evaluated in it
(Diekmann, Gyllenberg & Metz 2003; Metz, Mylius & Diekmann 2008; Lion 2018).
- **Adaptive dynamics** needs derivatives of φ(θ′, E) and of E*(θ).
- **MCT** needs φ_i[E_j] and its decomposition.
- **EEO** asks when argmax φ coincides with the optimum of a fixed or
  stand-level objective.

In TF24 the environment is a light profile and soil water over height, depth
and patch age: infinite-dimensional, so these theories have been usable only
qualitatively or through scenario differences.

This machinery factorises the model into exactly those two objects:
- **an expensive, self-consistent resident map** (θ, b, c) ↦ E, whose reverse
  pass carries cotangents of E back to traits, birth rate and every day of the
  record;
- **a cheap invader map** (θ′, E) ↦ ln R′, linear in introductions, whose
  reverse pass gives sensitivities to traits, to the field (with the hook) and
  costates that are reproductive values.

Identities (I1)–(I5), (A.3), (B.1) and (F.1) show that the core quantities of
all three theories are compositions of these two maps' first derivatives. The
second-order ones (Hessians, curvature terms of MCT) are chords of them.

So the shift is:
- **from** "simulate scenarios and difference them"
- **to** "the model is a differentiable map from traits and climate history,
  through a field, to fitness". Selection gradients, field sensitivities,
  costate (reproductive-value) maps and climate-sensitivity kernels become
  first-class outputs of one run and one or two reverse passes.

A second shift: the field becomes the interface between ecology and
evolution. It is the regulating variable of Meszéna's niche theory, made
concrete and differentiable. Selection, coexistence and the commons are all
statements about how sensitivity functions and impact functions on that field
line up.

### E.3 Limits, stated plainly

- **Non-smooth points.** The constant-rain landscape jumps at the resident
  (§A.4). Adjoints give a meaningless derivative there (−6.3 million against a
  jump of about 8 in ln R′). Every quantity above assumes smoothness, and a
  run must detect and report non-differentiability, not return a number.
  Leaf regime switches and sign-change splits give other kinks (one-sided
  derivatives).
- **Second derivatives cost sweeps.**
  - There is no forward-over-reverse mode.
  - Hessians and Jacobians are chords, about 2 sweeps per direction. A full
    k = 50 matrix is about 100 sweeps.
  - Curvatures are stable only from r ≈ 1e-2.
  - The invader's curvature varies about 20% over ±3% of lma.
- **Grid accuracy.**
  - Gradients converge differently from ln J (5.4ε against 0.3ε at 108
    introductions).
  - Constant rain needs front-loaded introductions, and its b* moved from
    24.5 to 45.1 when its schedule was rebuilt.
  - The effect of the absolute tolerance on gradients is unmeasured.
  - Each quantity in E.1 needs its own convergence check against
    `OBJECTIVES.md`'s ε. The refine today checks resident elasticities, not
    invader gradients.
- **First order.** Field sensitivities, climate kernels and two-stage adjoints
  are linear responses. Exactness for finite changes needs path integrals
  (B.1) or forward runs.
- **Fixed climate per patch age.**
  - No synchronous regional variation, no between-patch climate variation at
    a given age, no fluctuating seed rain, no seed bank. So no temporal storage
    effect, and "variable climate" conflates climate with successional timing.
  - Independent records per patch (D.3.1) is the cheapest correction.
  - Calendar-time climate needs a periodic or stochastic renewal formulation.
- **Rare-invader limit.** The held field is exact only at zero invader
  density. Finite-density outcomes (who wins after invasion) need the
  community's equilibrium solved again (supported for several species).
- **Model structure fixes some answers.** TF24's leaf is lifetime-optimal for
  invaders by construction at λ_o = 0 (F.4). Tests of "risk"-based criteria
  need a persistent damage state the model does not have.
- **Not yet built.**
  - exposure of costates and per-node gradients;
  - the field hook (spike only);
  - the resident field tangent and two-stage adjoint;
  - the second reverse pass;
  - per-cohort fields;
  - a sweep after a walk of several invaders (the walked-patch fix).

  Several items in E.1 depend on these.

---

## References

All verified for authors, year, venue and DOI against Crossref or a
repository record. Content claims were checked against abstracts or full text
where accessible, as noted in the text.

- Anten, N.P.R. & Vermeulen, P.J. (2016) Tragedies and crops: understanding natural selection to improve cropping systems. *Trends in Ecology & Evolution* 31, 429–439. doi:10.1016/j.tree.2016.02.010
- Bacaër, N. & Guernaoui, S. (2006) The epidemic threshold of vector-borne diseases with seasonality. *Journal of Mathematical Biology* 53, 421–436. doi:10.1007/s00285-006-0015-0
- Barabás, G., D'Andrea, R. & Stump, S.M. (2018) Chesson's coexistence theory. *Ecological Monographs* 88, 277–303. doi:10.1002/ecm.1302
- Barabás, G., Pásztor, L., Meszéna, G. & Ostling, A. (2014) Sensitivity analysis of coexistence in ecological communities: theory and application. *Ecology Letters* 17, 1479–1494. doi:10.1111/ele.12350
- Caswell, H. (1978) A general formula for the sensitivity of population growth rate to changes in life history parameters. *Theoretical Population Biology* 14, 215–230. doi:10.1016/0040-5809(78)90025-4
- Champagnat, N., Ferrière, R. & Méléard, S. (2006) Unifying evolutionary dynamics: from individual stochastic processes to macroscopic models. *Theoretical Population Biology* 69, 297–321. doi:10.1016/j.tpb.2005.10.004
- Chesson, P. (1994) Multispecies competition in variable environments. *Theoretical Population Biology* 45, 227–276. doi:10.1006/tpbi.1994.1013
- Chesson, P. (2000a) Mechanisms of maintenance of species diversity. *Annual Review of Ecology and Systematics* 31, 343–366. doi:10.1146/annurev.ecolsys.31.1.343
- Chesson, P. (2000b) General theory of competitive coexistence in spatially-varying environments. *Theoretical Population Biology* 58, 211–237. doi:10.1006/tpbi.2000.1486
- Chesson, P. (2018) Updates on mechanisms of maintenance of species diversity. *Journal of Ecology* 106, 1773–1794. doi:10.1111/1365-2745.13035
- Chesson, P.L. & Warner, R.R. (1981) Environmental variability promotes coexistence in lottery competitive systems. *American Naturalist* 117, 923–943. doi:10.1086/283778
- Christiansen, F.B. (1991) On conditions for evolutionary stability for a continuously varying character. *American Naturalist* 138, 37–50. doi:10.1086/285203
- Cowan, I.R. & Farquhar, G.D. (1977) Stomatal function in relation to leaf metabolism and environment. *Symposia of the Society for Experimental Biology* 31, 471–505.
- Dieckmann, U. & Law, R. (1996) The dynamical theory of coevolution: a derivation from stochastic ecological processes. *Journal of Mathematical Biology* 34, 579–612. doi:10.1007/BF02409751
- Diekmann, O., Gyllenberg, M. & Metz, J.A.J. (2003) Steady-state analysis of structured population models. *Theoretical Population Biology* 63, 309–338. doi:10.1016/S0040-5809(02)00058-8
- Durinx, M., Metz, J.A.J. & Meszéna, G. (2008) Adaptive dynamics for physiologically structured population models. *Journal of Mathematical Biology* 56, 673–742. doi:10.1007/s00285-007-0134-2
- Dybzinski, R., Farrior, C., Wolf, A., Reich, P.B. & Pacala, S.W. (2011) Evolutionarily stable strategy carbon allocation to foliage, wood, and fine roots in trees competing for light and nitrogen. *American Naturalist* 177, 153–166. doi:10.1086/657992
- Ellner, S.P. & Rees, M. (2006) Integral projection models for species with complex demography. *American Naturalist* 167, 410–428. doi:10.1086/499438
- Ellner, S.P., Snyder, R.E. & Adler, P.B. (2016) How to quantify the temporal storage effect using simulations instead of math. *Ecology Letters* 19, 1333–1342. doi:10.1111/ele.12672
- Ellner, S.P., Snyder, R.E., Adler, P.B. & Hooker, G. (2019) An expanded modern coexistence theory for empirical applications. *Ecology Letters* 22, 3–18. doi:10.1111/ele.13159
- Eshel, I. (1983) Evolutionary and continuous stability. *Journal of Theoretical Biology* 103, 99–111. doi:10.1016/0022-5193(83)90201-1
- Falster, D.S. & Westoby, M. (2003) Plant height and evolutionary games. *Trends in Ecology & Evolution* 18, 337–343. doi:10.1016/S0169-5347(03)00061-2
- Falster, D.S., FitzJohn, R.G., Brännström, Å., Dieckmann, U. & Westoby, M. (2016) plant: A package for modelling forest trait ecology and evolution. *Methods in Ecology and Evolution* 7, 136–146. doi:10.1111/2041-210X.12525
- Falster, D.S., Brännström, Å., Westoby, M. & Dieckmann, U. (2017) Multitrait successional forest dynamics enable diverse competitive coexistence. *PNAS* 114, E2719–E2728. doi:10.1073/pnas.1610206114
- Feichtinger, G., Kuhn, M., Prskawetz, A. & Wrzaczek, S. (2011) The reproductive value as part of the shadow price of population. *Demographic Research* 24, 709–718. doi:10.4054/DemRes.2011.24.28
- Fisher, R.A. (1930) *The Genetical Theory of Natural Selection*. Clarendon Press, Oxford.
- Franklin, O. et al. (2020) Organizing principles for vegetation dynamics. *Nature Plants* 6, 444–453. doi:10.1038/s41477-020-0655-x
- Geritz, S.A.H., Metz, J.A.J., Kisdi, É. & Meszéna, G. (1997) Dynamics of adaptation and evolutionary branching. *Physical Review Letters* 78, 2024–2027. doi:10.1103/PhysRevLett.78.2024
- Geritz, S.A.H., Kisdi, É., Meszéna, G. & Metz, J.A.J. (1998) Evolutionarily singular strategies and the adaptive growth and branching of the evolutionary tree. *Evolutionary Ecology* 12, 35–57. doi:10.1023/A:1006554906681
- Geritz, S.A.H., Metz, J.A.J. & Rueffler, C. (2016) Mutual invadability near evolutionarily singular strategies for multivariate traits, with special reference to the strongly convergence stable case. *Journal of Mathematical Biology* 72, 1081–1099. doi:10.1007/s00285-015-0944-6
- Gersani, M., Brown, J.S., O'Brien, E.E., Maina, G.M. & Abramsky, Z. (2001) Tragedy of the commons as a result of root competition. *Journal of Ecology* 89, 660–669. doi:10.1046/j.0022-0477.2001.00609.x
- Givnish, T.J. (1982) On the adaptive significance of leaf height in forest herbs. *American Naturalist* 120, 353–381. doi:10.1086/283995
- Gyllenberg, M. & Metz, J.A.J. (2001) On fitness in structured metapopulations. *Journal of Mathematical Biology* 43, 545–560. doi:10.1007/s002850100113
- Hager, W.W. (2000) Runge–Kutta methods in optimal control and the transformed adjoint system. *Numerische Mathematik* 87, 247–282. doi:10.1007/s002110000178
- Hamilton, W.D. (1966) The moulding of senescence by natural selection. *Journal of Theoretical Biology* 12, 12–45. doi:10.1016/0022-5193(66)90184-6
- Harrison, S.P. et al. (2021) Eco-evolutionary optimality as a means to improve vegetation and land-surface models. *New Phytologist* 231, 2125–2141. doi:10.1111/nph.17558
- Iwasa, Y. & Roughgarden, J. (1984) Shoot/root balance of plants: optimal growth of a system with many vegetative organs. *Theoretical Population Biology* 25, 78–105.
- Johnson, E. & Hastings, A. (2022) Resolving conceptual issues in Modern Coexistence Theory. arXiv:2201.07926 (preprint).
- King, D. & Roughgarden, J. (1982) Graded allocation between vegetative and reproductive growth for annual plants in growing seasons of random length. *Theoretical Population Biology* 22, 1–16. doi:10.1016/0040-5809(82)90032-6
- Kisdi, É. (1999) Evolutionary branching under asymmetric competition. *Journal of Theoretical Biology* 197, 149–162. doi:10.1006/jtbi.1998.0864
- Leimar, O. (2009) Multidimensional convergence stability. *Evolutionary Ecology Research* 11, 191–208.
- León, J.A. (1976) Life histories as adaptive strategies. *Journal of Theoretical Biology* 60, 301–335. doi:10.1016/0022-5193(76)90062-X
- Lion, S. (2018) Theoretical approaches in evolutionary ecology: environmental feedback as a unifying perspective. *American Naturalist* 191, 21–44. doi:10.1086/694865
- Lu, Y., Duursma, R.A. & Medlyn, B.E. (2016) Optimal stomatal behaviour under stochastic rainfall. *Journal of Theoretical Biology* 394, 160–171. doi:10.1016/j.jtbi.2016.01.003
- Mäkelä, A., Berninger, F. & Hari, P. (1996) Optimal control of gas exchange during drought: theoretical analysis. *Annals of Botany* 77, 461–468. doi:10.1006/anbo.1996.0056
- Manzoni, S., Vico, G., Palmroth, S., Porporato, A. & Katul, G. (2013) Optimization of stomatal conductance for maximum carbon gain under dynamic soil moisture. *Advances in Water Resources* 62, 90–105. doi:10.1016/j.advwatres.2013.09.020
- McNickle, G.G. & Dybzinski, R. (2013) Game theory and plant ecology. *Ecology Letters* 16, 545–555. doi:10.1111/ele.12071
- Meszéna, G., Gyllenberg, M., Pásztor, L. & Metz, J.A.J. (2006) Competitive exclusion and limiting similarity: a unified theory. *Theoretical Population Biology* 69, 68–87. doi:10.1016/j.tpb.2005.07.001
- Metz, J.A.J. & Gyllenberg, M. (2001) How should we define fitness in structured metapopulation models? Including an application to the calculation of evolutionarily stable dispersal strategies. *Proceedings of the Royal Society B* 268, 499–508. doi:10.1098/rspb.2000.1373
- Metz, J.A.J., Mylius, S.D. & Diekmann, O. (2008) When does evolution optimize? *Evolutionary Ecology Research* 10, 629–654.
- Metz, J.A.J., Nisbet, R.M. & Geritz, S.A.H. (1992) How should we define 'fitness' for general ecological scenarios? *Trends in Ecology & Evolution* 7, 198–202. doi:10.1016/0169-5347(92)90073-K
- Metz, J.A.J., Staňková, K. & Johansson, J. (2016) The canonical equation of adaptive dynamics for life histories: from fitness-returns to selection gradients and Pontryagin's maximum principle. *Journal of Mathematical Biology* 72, 1125–1152. doi:10.1007/s00285-015-0938-4
- Mylius, S.D. & Diekmann, O. (1995) On evolutionarily stable life histories, optimization and the need to be specific about density dependence. *Oikos* 74, 218–224. doi:10.2307/3545651
- Pacala, S.W. & Rees, M. (1998) Models suggesting field experiments to test two hypotheses explaining successional diversity. *American Naturalist* 152, 729–737.
- Perrin, N. & Sibly, R.M. (1993) Dynamic models of energy allocation and investment. *Annual Review of Ecology and Systematics* 24, 379–410. doi:10.1146/annurev.es.24.110193.002115
- Prentice, I.C., Dong, N., Gleason, S.M., Maire, V. & Wright, I.J. (2014) Balancing the costs of carbon gain and water transport: testing a new theoretical framework for plant functional ecology. *Ecology Letters* 17, 82–91. doi:10.1111/ele.12211
- Schaffer, W.M. (1983) The application of optimal control theory to the general life history problem. *American Naturalist* 121, 418–431.
- Sperry, J.S., Venturas, M.D., Anderegg, W.R.L., Mencuccini, M., Mackay, D.S., Wang, Y. & Love, D.M. (2017) Predicting stomatal responses to the environment from the optimization of photosynthetic gain and hydraulic cost. *Plant, Cell & Environment* 40, 816–830. doi:10.1111/pce.12852
- Taylor, H.M., Gourley, R.S., Lawrence, C.E. & Kaplan, R.S. (1974) Natural selection of life history attributes: an analytical approach. *Theoretical Population Biology* 5, 104–122. doi:10.1016/0040-5809(74)90053-7
- Tuljapurkar, S. (1990) *Population Dynamics in Variable Environments*. Lecture Notes in Biomathematics 85, Springer. doi:10.1007/978-3-642-51652-8
- Wolf, A., Anderegg, W.R.L. & Pacala, S.W. (2016) Optimal stomatal behavior with competition for water and risk of hydraulic impairment. *PNAS* 113, E7222–E7230. doi:10.1073/pnas.1615144113
- Zea-Cabrera, E., Iwasa, Y., Levin, S. & Rodríguez-Iturbe, I. (2006) Tragedy of the commons in plant water use. *Water Resources Research* 42, W06D02. doi:10.1029/2005WR004514

Not verifiable here, and so not relied on for specifics:
- Leimar (2009)'s exact matrix criterion, taken from Geritz et al. (2016)'s summary;
- the solution method of Lu et al. (2016);
- the definitions inside Meszéna et al. (2006), paraphrased from memory of the framework;
- Schaffer (1983)'s identification of costates, of which only the residual-reproductive-value terminal term was confirmed;
- the article number W06D02 for Zea-Cabrera et al. (2006), from memory (the DOI is verified).
