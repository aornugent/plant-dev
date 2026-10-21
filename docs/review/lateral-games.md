# Lateral fields: mean-field games, evolutionary games, tournaments, the PPA

What four adjacent fields say about TF24's structure: a resident that makes a
field, individuals and an inner optimum that respond to it, invaders read in
the field, and adjoints that are reproductive value. Notation follows
`theory.md` §0 (φ, s(θ′, θ), E, b*, g, F_θ, S, I) and `frontier.md` §2.

Labels:
- **[Verified]**: bibliographic data checked against Crossref. Where a content
  claim is used, it was checked against the abstract or text, as noted. "meta
  only" means only the bibliographic record was checked, and the content claim
  is from the standard literature, not re-read here.
- **[Derived]**: my own argument for this model. Nobody has checked it.
- **[Judgement]**: an assessment, open to dispute.
- **[Not found]**: searched for and not located. That does not mean it does not
  exist.

---

## 0. The shared skeleton

Each field below has a forward equation for a population distribution, a
backward equation for an individual's value, and a fixed point that couples
them through an aggregate. The table gives the exact correspondences. §§1–4
explain each row and where it fails.

| our object | MFG | evolutionary game (Vincent–Brown, McNamara–Houston) | tournament / positional | PPA |
|---|---|---|---|---|
| field E(a): light L(z, a), water W_ℓ(a) | mean field m_t, or the coupling F(x, m_t) it induces | environment, or G's dependence on (u, x) | the distribution of rivals' output; rank | z*(a), plus soil N or water |
| cohort ODEs (McKendrick–von Foerster by characteristics) | Fokker–Planck / continuity equation, in Lagrangian form | forward population projection | none (static) | von Foerster PDEs + integral equation for z* |
| invader's φ(θ′; E) | value of a deviating representative player | G(v, u, x) at focal v | expected payoff of one contestant | Z*-based whole-life performance |
| invader's adjoint λ_s = ℓ ∇V | the HJB value's gradient along a characteristic (the Pontryagin costate) | the DP value function (reproductive value) | none | none |
| resident's adjoint (F.3) | the McKean–Vlasov control costate, with the δ/δm term | none | none | none |
| resident equilibrium F(θ, b*) = 0 | no analogue in the standard MFG, which has fixed mass. Closest: free entry in Hopenhayn (1992); branching MFG | ecological equilibrium x* in G(v, u*, x*) | none | equilibrium monoculture |
| ESS (g = 0, s₁₁ < 0) | Nash equilibrium in a static parameter, with no stability refinement | ESS maximum principle | symmetric Nash equilibrium | ESS allocation (Dybzinski et al. 2011) |
| stand objective b*, F_θ | mean-field control (planner); price of anarchy | none | the efficient prize / effort | monoculture optimum |
| inner leaf optimum | each agent's pointwise Hamiltonian maximisation | none | none | none |
| climate record c(a) | deterministic time-dependence of the data | none | none | none |
| calendar-time climate (not built) | common noise | none | common shock | none |
| within-cohort variance (absent) | idiosyncratic noise (second-order MFG) | errors in decision-making | noise in output (Lazear–Rosen) | none (z* is a step) |

**[Derived] The one structural fact that decides most transfers.** TF24's
individuals do not anticipate. Traits are fixed at birth. The leaf maximises
instantaneous profit, which is Pontryagin-optimal for the invader (`theory.md`
F.4) but uses no future information. So the resident's forward run needs no
backward solution, and the backward pass is used only for derivatives.

A standard MFG is a forward–backward fixed point: the HJB, solved backward,
sets the controls that drive the forward equation. TF24 is therefore:
- a **McKean–Vlasov forward system with its adjoint**, at the level of
  dynamics;
- a **static nonatomic game in θ**, closed by b*, at the level of evolution.

This removes the hardest part of MFG numerics (the forward–backward fixed
point) and keeps the parts that matter here: potential structure,
monotonicity, the Nash/planner gap, common noise and sufficient statistics.

The structure becomes a genuine MFG only if a control is made forward-looking,
for example if the leaf priced water at the stand's or the invader's future
value (F.4's λ_W), rather than through a fixed λ_o.

---

## 1. Mean-field games

### 1.1 The system and the exact correspondence

**[Verified]** Lasry & Lions (2007) and Huang, Malhamé & Caines (2006),
independently, introduced the limit of N-player stochastic differential games
as N → ∞. A representative agent solves an HJB equation, backward in time,
given the flow of measures m_t. The population law solves a Fokker–Planck
(Kolmogorov forward) equation, given the agent's optimal feedback. Equilibrium
is the fixed point. Huang et al. call it the "Nash certainty equivalence"
principle. Carmona & Delarue (2018, two volumes) give the probabilistic (FBSDE)
theory. Cardaliaguet, Delarue, Lasry & Lions (2019) give the master equation.

**[Derived] Lagrangian form = cohorts + AD costates.** Without idiosyncratic
noise (a *first-order* MFG), the HJB −∂_t u + H(x, ∇u, m) = 0 is solved along
characteristics:
- ẋ = ∂_p H;
- ṗ = −∂_x H, with p = ∇u.

This is Pontryagin's system along each trajectory. TF24 has the same parts:
- each cohort is a characteristic of the McKendrick–von Foerster equation;
- the invader's reverse sweep carries λ_s(a) = ℓ_s(a) ∇_x V_s(a) backward along
  the same cohort (`theory.md` F.2);
- running reward f(x) e^{−m} Π;
- killing rate μ plus disturbance, the latter through Π;
- terminal time T.

So plant's "cohort forward, adjoint backward along the cohort" is the
characteristic (Lagrangian) form of a first-order MFG system. The differences:
- The MFG's u is the value; our λ is its state gradient times survivorship.
- The AD adjoint is of the discrete scheme, not of the continuum (Hager 2000,
  in `theory.md`).

**[Verified]** Cardaliaguet & Graber (2015) treat first-order MFGs with local
coupling. They prove existence and uniqueness of weak solutions and
characterise the solution as the minimiser of an optimal control problem of HJ
and continuity equations (abstract checked). First-order MFGs are the class to
read for regularity results, and they need structure (monotonicity, convexity)
that §1.3 shows light competition lacks.

**[Verified, content checked]** Achdou et al. (2022) recast heterogeneous-agent
macroeconomics (Aiyagari–Bewley–Huggett) as an MFG PDE system. Their numerical
appendix discretises the Kolmogorov forward operator as the **transpose** of the
HJB's upwind intensity matrix, "the discretized version of its adjoint". This
is the same duality as plant's (density forward, value backward). In plant, AD
on the characteristic scheme already gives the exact discrete transpose. Their
upwind/transpose construction is what one would copy only if plant ever moved
to a fixed size grid.

**[Derived] Where the correspondence breaks.**
1. **Fitness is R₀ at a renewal equilibrium.** MFG fixes the mass of players.
   Here b is unknown and is closed by F(θ, b) = 0.
   - The nearest MFG variants are with branching (Claisse, Ren & Tan 2023,
     [Verified, abstract checked]: they introduce a branching mechanism so that
     the number of players varies, prove existence and approximate Nash) and
     with absorption (Campi & Fischer 2018 [Verified, meta only]).
   - The nearest *equilibrium* analogue is Hopenhayn (1992) (§1.8).
2. **Coupling is local, within patches.** Patches couple to each other only
   through b. The mean field is therefore two-level: a scalar global aggregate
   b, and per-patch fields E(a) that are deterministic functionals of
   (b, θ, c). That makes the global coupling one-dimensional, which matters
   for common noise (§1.5).
3. **Patches hold few large individuals.** The within-patch deterministic
   density is a large-number limit. Canopy trees in a patch are few, so the
   N-player correction (the MFG "convergence problem") is not small exactly
   where the race happens. [Judgement]
4. **MFG has no convergence stability or branching.** Its stability notions
   are learning dynamics: fictitious play (Cardaliaguet & Hadikhanloo 2017),
   and "stable solutions" that are local attractors of learning in potential
   MFGs (Briani & Cardaliaguet 2018; abstract via arXiv). These are the
   nearest analogues of convergence stability. Nothing in MFG corresponds to
   s₁₁ > 0 and branching, because a single representative agent cannot split.
   Multi-population MFGs take the number of populations as given.

### 1.2 Nash vs mean-field control: the adjoint gap is the δ/δm term

**[Verified, abstract checked]** Carmona, Delarue & Lachapelle (2013):
- Optimising and then taking N → ∞ gives the MFG.
- Taking the limit and then optimising gives control of McKean–Vlasov dynamics
  (the planner).
- Both lead to FBSDEs with distribution-dependent coefficients.
- The MKV adjoint carries an extra term: the expectation of the Hamiltonian's
  derivative in the measure argument.

**[Derived]** This is `theory.md` (F.2) exactly.
- The invader's adjoint is the MFG (Nash) costate.
- The resident's adjoint is the MKV-control costate: the derivative of ln J
  with the field responding.
- λ^res − λ^inv is the δ/δm term: the effect of one individual's state on the
  field, valued at every cohort's field sensitivity.
- Correspondingly g and F_θ are the Nash and planner gradients. On long
  drought they are −23.8 and −5.9 for lma [Measured, `theory.md`].

One caution: the planner's objective is ln J at fixed b, or b*(θ)
(`theory.md` C.2). It is not total welfare in MFG's sense, which would sum
costs over agents at fixed mass.

**[Verified, abstracts checked]**
- Cardaliaguet & Rainer (2019) give a structure condition under which
  efficient MFG equilibria exist, and quantify the inefficiency otherwise.
- Carmona, Graves & Tan (2019) define the price of anarchy for MFGs (the ratio
  of the worst equilibrium social cost to the planner's). They give a
  necessary and sufficient condition for no price of anarchy in
  linear-quadratic extended MFGs.

**[Judgement]** The ratio-of-costs definition does not transfer directly, since
fitness at equilibrium is 1 by construction. What transfers is the
*directional* gap, the angle between g and F_θ in trait space (`frontier.md`
§1.2). It also suggests a scalar: b*(θ_ESS)/max_θ b*(θ).

### 1.3 Potential MFGs, Lasry–Lions monotonicity, and Metz–Mylius–Diekmann

**[Established, standard; Lasry & Lions 2007, verified meta only]**
- **Potential.** If the coupling is the first variation of a functional,
  F(x, m) = δΦ/δm(x), the MFG system is the optimality system of a single
  control problem with Φ in its cost. Equilibria are then its critical points.
  The finite-player analogue is Monderer & Shapley (1996).
- **Monotonicity.** If the coupling is monotone,
  ∫(F(x, m₁) − F(x, m₂)) d(m₁ − m₂) ≥ 0 for a cost F, the equilibrium is
  unique. The interpretation is crowding aversion.
- **[Verified, abstract checked]** Mazuryn & Thygesen (2023) is an ecological
  example. Nash equilibria of their vertical-migration game are equivalent to
  a PDE-constrained optimisation problem, i.e. the game is potential.

**[Derived] In field coordinates.** Write the interaction between strategies
i and j as K_ij = ⟨S(θ_i), I(θ_j)⟩: the effect of j's density on i's ln R′,
through the field (`frontier.md` §2).
- **Potential iff K is symmetric.** For a linear coupling F(x, m) = ∫K(x, y)m(dy),
  a potential exists iff K is symmetric. A sufficient condition is
  I(θ) = M S(θ) for one symmetric M: every strategy's impact is aligned with its
  own sensitivity. This is Meszéna et al.'s (2006) and Tilman's
  impact–sensitivity alignment, reached from the MFG side.
- **Monotonicity iff the symmetric part of K is negative semi-definite** (for
  a fitness, i.e. a reward). Crowding then harms like strategies at least as
  much as unlike ones.
- **Local test for the trait game.** The selection gradient is locally the
  gradient of a potential, g = ∇P, iff J_g = s₁₁ + s₁₂ is symmetric. s₁₁ is a
  Hessian, so this holds iff **s₁₂ is symmetric**. That is checkable from the
  chords already built (`theory.md` A.3).

**[Derived] What each resource does to these properties.**
- **Light** acts through a one-sided kernel.
  - **[Verified, abstract]** Iwasa, Cohen & León (1985): "taller trees shade
    shorter ones, but not the reverse".
  - In fitness terms K_ij = −c·1{h_j > h_i}: a taller class j lowers the
    fitness of a shorter class i, and not the reverse. K is not symmetric, so
    there is no potential.
  - Its symmetric part on n distinct height classes is −(c/2)(𝟙𝟙ᵀ − Id). That
    has eigenvalue −(c/2)(n − 1) on 𝟙, and +c/2 on every direction orthogonal
    to 𝟙. So it is not negative semi-definite: not monotone.
  - Adding self-limitation d within a height class (K_ii = −d) shifts every
    eigenvalue by −d. Monotonicity then holds iff d ≥ c/2, i.e. crowding
    within one's own height class must be at least half the one-sided effect
    of a taller class.
  - So one-sided light competition breaks both the Lasry–Lions uniqueness
    condition and the potential structure. Non-unique equilibria, priority
    effects and founder control are the generic expectation.
  - **[Verified, abstract checked]** Adams, Purves & Pacala (2007) find that
    the general case of height-structured light competition "can produce
    coexistence, founder control or competitive exclusion".
- **Water** in one well-mixed layer acts through one scalar per patch age:
  K(x, y) = a(x) b(y). That is symmetric iff a ∝ b, i.e. a strategy's
  sensitivity to water is proportional to its uptake. With several layers or
  through time it is rank > 1.
- **Relation to Metz, Mylius & Diekmann (2008)** (`theory.md` C.1). MMD's
  condition is that the environment acts in an effectively one-dimensional,
  monotone way. That gives a global optimisation principle: a ψ with
  sign s(θ′, θ) = sign(ψ(θ′) − ψ(θ)) for *all* pairs, not only nearby ones.
  - A potential is weaker: it is local, gives a Lyapunov function for the
    canonical equation (dP/dt = κ gᵀ C g ≥ 0 for C positive definite), and
    says nothing about non-local mutants.
  - MMD ⇒ potential. Potential ⇏ MMD.
  - So "is there a potential?" is the cheap first test, by symmetry of s₁₂ or
    of K. "Is there an optimisation principle?" (MMD) needs the effective rank
    of the field to be one.

### 1.4 First-order MFGs, ties, and smoothing by noise

**[Established]** With idiosyncratic noise (a diffusion term in the agent's
state), the MFG system is parabolic and regularising. In the first-order
(deterministic) case solutions are weak, and equilibria may be measure-valued
or non-smooth (Cardaliaguet & Graber 2015, as above).

**[Verified, abstract checked]** Foguen Tchuendom (2018): in an LQ MFG, a
common noise restores uniqueness; there is a counter-example without it.
**[Verified, meta only]** Delarue (2019): restoring uniqueness by randomising
the equilibria.

**[Derived]** TF24 is a first-order system: cohorts have no within-cohort
variance. The constant-rain pathology is the generic behaviour of first-order
games with discontinuous couplings at ties (§3 makes this exact). Two
different smoothings are available, and they mean different things:
- **Idiosyncratic noise** (growth noise per individual, or a spread of birth
  dates within a cohort). This is a *model change*: it makes the light each
  individual receives a smooth function of its rank.
- **Common noise** (calendar-time climate shared by all patches). This may
  select among multiple equilibria (founder control), but it does not smooth
  the tie inside one patch.

### 1.5 Common noise ↔ calendar-time climate

**[Verified, abstract checked]** Carmona, Delarue & Lacker (2016) define strong
and weak solutions of MFGs with common noise. The mean field becomes the
conditional law given the common noise path. Weak solutions exist under
general assumptions; strong existence and uniqueness need more, via a
Yamada–Watanabe analogue.

**[Derived] Correspondence.** Under calendar-time climate (`theory.md` D.3.2):
- A patch disturbed at t₀ sees c(t₀ + a).
- The conditional law (given the climate path) of patch age × individual
  state is the common-noise mean field.
- Patches couple only through b(t), so the global conditional mean field is
  carried by one scalar process b(t). Each patch's field is then a
  deterministic functional of (t₀, c, b(·), θ).
- Individuals do not anticipate, so there is no expectations fixed point
  (unlike Krusell–Smith, §1.7). The equilibrium is a fixed point of a renewal
  equation in the path b(·), given the climate path. Fitness is a Lyapunov
  exponent.

**[Derived] An algorithm that transfers.** Linearise around the stationary
regional state with stationary climate statistics:

 δJ(t) = Σ_{t′} 𝒥_b(t − t′) δb(t′) + Σ_{t′} 𝒥_c(t − t′) δc(t′).

The kernels depend on t − t′ only (time invariance), so the linear response
of b(·) to any climate path is a Toeplitz solve (FFT). That needs the impulse
responses 𝒥_b, 𝒥_c once, from AD.

**[Verified]** This is the sequence-space approach:
- Auclert, Bardóczy, Rognlie & Straub (2021) (abstract checked): "derivatives
  of perfect-foresight equilibrium mappings between aggregate sequences around
  the steady state", composed and inverted for general-equilibrium responses.
- Boppart, Krusell & Mitman (2018) (meta only): the impulse response as a
  numerical derivative.

It is the cheapest route to calendar-time climate that keeps exact derivatives.
It is first order in the size of the fluctuations.

### 1.6 The master equation ↔ invasion fitness as a functional of the resident

**[Verified, meta only]** Cardaliaguet, Delarue, Lasry & Lions (2019): U(t, x, m)
is the value of a player at state x when the population law is m. Its linear
derivative δU/δm(t, x, y) carries the effect of one more player at y on a
player at x. Well-posedness uses Lasry–Lions monotonicity, and the master
equation controls the N-player → MFG convergence rate.

**[Derived]** Invasion fitness is the master-equation value at the birth state,
with the population law at the resident equilibrium:
s(θ′, θ) = U(x₀(θ′), m*(θ)), with U depending on m only through E. Then
δU/δm(x, y) = ⟨S(x), δE/δm(y)⟩, which is the K_ij of §1.3. So the
**field-coordinates bilinear form (S, I) of `frontier.md` is the linear
derivative of the master equation**, and a library of (φ, S) over strategies
(`frontier.md` §4.3) is a discretised master-equation derivative.

What MFG adds:
- Monotonicity of this bilinear form is the uniqueness condition (§1.3).
- Its size bounds the finite-N error. Here that is the error of the
  infinite-patch, infinite-density limit, not a numerical error.

### 1.7 Multi-population, major/minor, and dimension reduction

**[Verified]**
- **Multi-population MFGs:** Cirant (2015) (meta only). Achdou, Bardi & Cirant
  (2017) (meta only) give segregation models in which non-monotone couplings
  produce multiple equilibria. Each species has its own HJB and Fokker–Planck,
  coupled through the shared mean field. That is the structure of m coexisting
  residents (`theory.md` A.3, rank-m correction).
  - **[Not found]** an MFG result analogous to Meszéna et al.'s bound (number
    of coexisting types ≤ effective dimension of the field).
- **Major/minor players:** Huang (2010); Carmona & Zhu (2016) (meta only).
  - **[Judgement]** The analogy is weak. Climate is exogenous common noise, not
    a player. The resident is the mean field, not a major player. The invader
    is the standard minor deviating player.
  - A real major player would be a manager (harvest policy) or one dominant
    canopy tree per patch. Only the former is a plausible use.
- **Finite-state MFGs:** Gomes, Mohr & Souza (2010) (meta only). These
  correspond to aggregating size into a few classes (understory/canopy, as in
  the PPA, §4).
- **Approximate aggregation under common noise:**
  - **[Verified meta; content via secondary sources]** Krusell & Smith (1998)
    found the mean of the wealth distribution to be a near-sufficient statistic
    for forecasting prices under aggregate shocks. Later work qualifies this to
    "for the evolution of the mean".
  - **[Verified meta only]** Reiter (2009) linearises around the stationary
    distribution. Ahn, Kaplan, Moll, Winberry & Wolf (2018) linearise and then
    reduce the distribution's dimension.
  - **[Derived]** In TF24 the sufficient statistic is given by the physics,
    not approximated. The light profile is L(z, a) = exp(−k Λ(z, a)), where
    Λ(z, a) is the leaf area above z: an upper-tail cumulative distribution of
    the population, weighted by leaf area. Soil water is one scalar per layer.
    Patches couple only through b. The field is already the minimal coupling
    statistic. The open question is its *effective* rank (`frontier.md` H1, H2).

### 1.8 Heterogeneous-agent economics as the closest MFG relative

**[Verified meta; content from the abstract and standard treatments]**
Hopenhayn (1992) gives the stationary equilibrium of an industry with entry,
exit and firm heterogeneity in size and growth. It is a size-structured
population with births (entry) and deaths (exit). The aggregate price is pinned
by a free-entry condition (the value of an entrant equals the sunk entry cost),
and the mass of entrants then clears the market.

**[Derived]** Correspondence:
- free entry ↔ F(θ, b*) = 0;
- mass of entrants ↔ b;
- price ↔ field;
- incumbents' value function ↔ reproductive value.

Hopenhayn's environment is a scalar price, so it is the one-dimensional MMD
case. The entry condition alone fixes the environment, as R* does. TF24 is the
same structure with a function-valued field.

### 1.9 Has anyone connected MFGs to adaptive dynamics, ESS, or forests?

What exists, all [Verified]:
- Cantrell, Cosner, Lam & Mazari-Fouquer (2025, *J. Math. Biol.*), abstract
  checked: an ergodic MFG with local coupling whose density converges to the
  ideal free distribution as the cost of control → 0. Their introduction cites
  earlier work showing that IFD-producing dispersal is an ESS and an NIS (seen
  in a search snippet only).
- Mazuryn & Thygesen (2023, *Bull. Math. Biol.*): diel vertical migration as a
  differential MFG, using fitness. Thygesen & Mazuryn (2022, *Theor. Ecol.*):
  ideal free flows of optimal foragers.
- Tembine, Le Boudec, El-Azouzi & Altman (2009): Markov decision evolutionary
  games, the mean-field limit with individual states and fitness language
  (meta only).
- Hsiao & Nau (2022, AAMAS): an MFG of spatial evolutionary games on graphs
  (meta only).
- The "Hamilton–Jacobi approach" to adaptive dynamics (Diekmann, Jabin,
  Mischler & Perthame 2005) is a different HJ equation: a constrained HJ for
  the trait distribution in the small-mutation limit. It is not an
  individual's HJB, and the two should not be conflated.

**[Not found]** (searches: "mean field game" with adaptive dynamics /
invasion fitness / evolutionarily stable / forest / size-structured / light
competition):
- any paper treating invasion fitness, the canonical equation or ESS of a
  physiologically structured population as an MFG;
- any MFG of forest or size-structured plant competition.

Closest on the forest side, not MFGs:
- Magal & Zhang's size-structured light-competition PDE calibrated to SORTIE
  (arXiv 1609.00185, not verified further);
- the PPA family (§4).

**[Judgement]** The correspondence in §§1.1–1.6 appears to be unpublished.

---

## 2. Evolutionary games with continuous strategies and population dynamics

### 2.1 Vincent & Brown's G-function

**[Verified meta]** Brown & Vincent (1987); Vincent & Brown (2005).
**[Established, standard]**
- The fitness-generating function G(v, u, x) gives the per-capita growth rate
  of a focal individual using v in a community with resident strategies u at
  densities x.
- **ESS maximum principle:** at an ESS coalition u* with ecological
  equilibrium x*, max_v G(v, u*, x*) = G(u*_i, u*, x*) = 0.
- **Darwinian dynamics:** u̇ = σ² ∂G/∂v.
- Structured populations take G as the dominant eigenvalue of a projection
  matrix.

**[Derived] Correspondence.**
- G(v, u, x) ↔ φ(θ′; 𝓔(θ, b)), and x* ↔ b*.
- The maximum principle ↔ s(θ′, θ*) ≤ 0 = s(θ*, θ*).
- Darwinian dynamics ↔ the canonical equation with C = σ²Id.
- An ESS coalition ↔ m coexisting residents.

The G-function's explicit separation of focal strategy, residents' strategies
and densities is exactly the invader / resident / b split.

**[Judgement]** Nothing new for us beyond adaptive dynamics. It is a useful
vocabulary for multi-species "coalitions", and its maximum principle is only
necessary.

### 2.2 Height and life-history games in plants

**[Verified]**
- Givnish (1982) (leaf height in forest herbs).
- Falster & Westoby (2003) (height as an evolutionary game).
- Mäkelä (1985), *Theor. Popul. Biol.* 27: 239–267, "Differential games in
  evolutionary theory: height growth strategies of trees". Metadata verified;
  abstract not obtained, so content not relied on.
- Iwasa, Cohen & León (1985), abstract checked. Note the year: 1985, not 1984.
  - Each tree maximises net production in the light environment its
    neighbours make.
  - Competition is asymmetric.
  - At a monomorphic equilibrium, height rises with density.
  - **When crowns are thin enough, a polymorphic equilibrium with different
    heights at equal fitness appears.**

**[Derived]** The Iwasa et al. polymorphic equilibrium is the plant-height
version of the mixed equilibrium of the all-pay auction (§3.2). Under one-sided
competition with nearly ties, the stable outcome is a distribution of heights
at equal payoff, not a single strategy. That is what the constant-rain
landscape (a jump at θ′ = θ) points to.

### 2.3 State-dependent ESS by dynamic programming (Houston & McNamara)

**[Verified]**
- McNamara & Houston (1996, *Nature*) (meta): state-dependent life histories.
  Reproductive value is a dynamic-programming value function of state and
  time.
- McNamara, Houston & Collins (2001, *SIAM Rev.*) (meta): a review of
  optimality models.
- McNamara, Webb, Collins, Székely & Houston (1997), abstract checked via the
  PubMed record:
  - damped iteration of the best-response map is unreliable for
    state-dependent games, because the map is often discontinuous;
  - **adding errors in decision-making** removes this;
  - they prove general results.

**[Derived] Correspondence.** The McNamara–Houston ESS computation is an MFG
fixed point avant la lettre: backward DP for reproductive value, forward
projection of the state distribution, iterate. Their remedy is a smoothed
(logit-type) best response, which is entropy regularisation in MFG terms. It
transfers in two places:
1. **The inner leaf optimum.** Its regime switches (shutdown, pinned bounds;
   `theory.md` F.5) are the discontinuities of a best-response map. A
   softened operating point (a smooth maximum with a temperature) makes the
   inner map differentiable. It changes the model by a controlled amount and
   gives one-sided limits as the temperature → 0.
2. **The outer trait race.** "Errors" in growth (within-cohort variance) play
   the same role (§3).

---

## 3. Tournaments, contests and positional goods

### 3.1 Lazear–Rosen: the marginal return to effort is the density at the tie

**[Verified meta; the first-order condition is standard]** Lazear & Rosen
(1981): output q_i = μ_i + ε_i, winner-take-prize W₁, loser W₂. The symmetric
first-order condition is

 (W₁ − W₂) · g(0) = c′(μ),

where g is the density of ε_j − ε_i. The incentive is the prize spread times
the probability density of a tie.

Further results:
- **[Verified, via a secondary source; not a precise theorem]** A
  pure-strategy equilibrium requires enough dispersion of the noise. The
  exact condition depends on the noise density and the cost function.
- **[Verified, abstract checked]** Drugov & Ryvkin (2020): equilibrium effort
  falls as noise becomes more dispersed in the dispersive order. Variance
  alone is not the right measure.
- **[Verified meta]** Gerchak & He (2003): in a secondary summary, the
  symmetric prize range is inversely proportional to E[f(X)]. Not checked in
  the text.

**[Derived] Exact transfer to the constant-rain race.** Let an invader and a
resident be born at the same instant. The invader's height h′(a) differs from
the resident's h(a) by δh ≈ (∂h/∂θ)δθ. The invader's light depends on the
leaf area above it, Λ(h′, a). Its derivative in h′ is minus the resident's
leaf-area density at h′. So

 ∂φ/∂θ′ ⊃ ∫ λ_s(a) · ∂G/∂L · k L · ρ_Λ(h′(a), a) · ∂h′/∂θ′ da,

with ρ_Λ the resident's leaf-area density over height:
- **That is Lazear–Rosen's prize spread × tie density.** The prize is the
  light contrast between above and below the resident, valued by reproductive
  value.
- **For one deterministic cohort, ρ_Λ is a Dirac at h(a).** The gradient at
  θ′ = θ does not exist, and the one-sided limits differ by the full prize.
  That matches the measured jump (ln R′ of +7.4 vs −39.9 within ±5%, about 8
  within ±0.01%; `theory.md` A.4).
- **With a within-cohort height spread σ,** ρ_Λ is bounded by about
  (leaf area)/σ:
  - |g| ∝ 1/σ;
  - the step in ln R′ is smoothed over a trait interval of width
    σ/|∂h/∂θ|.
- **The −6.3 million sweep gradient** is then a measure of the scheme's
  effective σ: the resident's height spread as resolved by the introductions
  near a = 0. It is not a property of the continuum.

### 3.2 The zero-noise limit: all-pay auctions have no pure equilibrium

**[Verified]**
- Baye, Kovenock & de Vries (1996) (meta): the all-pay auction with complete
  information has no pure-strategy equilibrium. Its equilibria are in mixed
  strategies and are fully characterised.
- Hirshleifer (1989) (meta): ratio vs difference contest success functions.
- Skaperdas (1996) (meta): axioms for contest success functions.
- Che & Gale (2000) (meta): difference-form contests and the robustness of the
  all-pay auction.
- Nalebuff & Stiglitz (1983) (meta): prizes vs incentives.
- Dasgupta & Maskin (1986) (meta): existence of (mixed) equilibria in games
  with discontinuous payoffs.

**[Derived]** A deterministic even-aged cohort race is the zero-noise limit of a
Lazear–Rosen tournament, equivalently a Tullock contest with exponent → ∞. The
game-theoretic prediction is that no pure (monomorphic) equilibrium exists in
the strategy that sets rank, and the stable outcome is mixed.

The biological counterparts are:
- polymorphic heights (Iwasa et al. 1985, §2.2);
- a distribution of emergence times in a race for early arrival. Iwasa,
  Odendaal, Murphy, Ehrlich & Launer (1983) [Verified meta; content from
  memory] model male butterfly emergence.

For TF24 on constant rain, the expected adaptive-dynamics outcome is therefore
not a smooth singular strategy. Candidates are a polymorphism, or a
distribution of strategies sustained by the race. Classification must use
one-sided limits and PIPs, not g and s₁₁.

### 3.3 Positional goods with a continuum of agents

**[Verified, abstract checked]** Hopkins & Kornienko (2004): utility depends on
rank in the distribution of a positional good. The symmetric Nash equilibrium
overspends on the positional good. Heterogeneity in income makes the
equilibrium a smooth function, analysed with auction techniques. Frank's
positional arms races are the welfare argument; not separately verified here.

**[Verified, abstracts checked]** Rank-based MFGs join the two literatures:
- Nutz & Zhang (2019): agents choose effort, are ranked by completion time,
  and paid by rank.
- Bayraktar, Cvitanić & Zhang (2019): existence, uniqueness and stability of
  the MFG equilibrium for heterogeneous players.
- In both, Brownian noise in each agent's progress is what makes the rank
  distribution smooth.

**[Derived] Correspondence.**
- Light is a positional good: what matters is leaf area above, a rank
  functional weighted by leaf area.
- Hopkins–Kornienko's heterogeneity in income ↔ heterogeneity in birth date
  and growth.
- Their overspending ↔ the gap between g and F_θ (§1.2).
- Their smooth equilibrium requires a continuous distribution of types. In
  TF24 that is a continuous distribution of surviving residents' heights at
  each a, exactly what a single even-aged cohort lacks.

### 3.4 What the economics adds, critically

**[Judgement]**
1. **The exact first-order condition.** It locates the singularity at the tie
   density and says what to measure: the resident's leaf-area density at the
   invader's height, along the life.
2. **The existence result.** Noise must be sufficient for a pure equilibrium.
   So a smooth ESS on constant rain requires physical within-cohort variation.
   Numerical smoothing alone would change the answer without justification.

**Where it breaks:**
- In tournaments the noise is in the outcome, given effort. In TF24 the
  relevant noise is in individual growth and birth date. That variance
  compounds over life, and survival filters it: the surviving distribution of
  heights is not a fixed additive noise.
- The "prize" is not fixed. It is the light contrast at the resident's crown,
  set by the resident's own leaf area, so prize and density move together.

---

## 4. The perfect plasticity approximation

### 4.1 The structure

**[Verified, abstracts and text checked]**
- Strigul, Pristinski, Purves, Dushoff & Pacala (2008): the PPA is von Foerster
  PDEs coupled with an integral equation. It gives equilibrium abundances,
  stability and two-species coexistence conditions analytically.
- Purves, Lichstein, Strigul & Pacala (2008, *PNAS*, text checked): "all crown
  area above a critical height Z* receives full sunlight and … all other crown
  area is in the understory". Z* is set so that the sun-exposed crown area
  does not exceed ground area. In the flat-top case, trees taller than Z* are
  fully sunlit and shorter ones fully shaded. Growth and mortality depend only
  on species and canopy status. Ẑ* predicts the late-successional winner.
- Adams, Purves & Pacala (2007), abstract checked: in general, competition for
  light can give coexistence, founder control or exclusion. When species
  differ in everything except crown transmissivity, competition is
  hierarchical, and **the analogue of R* is the height at which trees enter
  the canopy in an equilibrium monoculture**.
- Dybzinski et al. (2011) and Farrior et al. (2013) (meta; abstracts in
  `literature.md`) compute ESS allocations in this framework, for light and
  nitrogen and for light and water. Dybzinski et al. find that ESS allocations
  do not maximise monoculture growth.
- Also relevant: Kohyama & Takada (2009), abstract checked, stratified
  populations where one-sided competition permits coexistence that two-sided
  competition does not; and Detto, Levine & Pacala (2022), meta only.

### 4.2 Correspondence and dimension

**[Derived]**
1. **The light field collapses to one scalar per patch age.** The PPA replaces
   L(z, a) by z*(a). For an individual, the field is "above or below z*(a)".
   So the effective light coordinate of E is the function a ↦ z*(a): one
   number per patch age instead of a profile.
2. **In a closed-canopy stationary forest, z* is constant.** With
   Dybzinski/Farrior's gap-free equilibrium assumption, the light environment
   is one scalar.
   - With nitrogen or water as a second scalar, the environment is
     two-dimensional.
   - **This is why those ESS calculations are tractable, and why Adams et
     al.'s special case gives an R*-like pessimisation principle.** It is the
     MMD one-dimensional case (§1.3).
3. **In plant's metapopulation, z*(a) varies with patch age.** The environment
   is a function, and no optimisation principle follows in general. The PPA
   reduces dimension per age; it does not make the environment
   one-dimensional.
4. **The PPA does not remove the race; it sharpens it.**
   - Light is a step at z*.
   - Take one even-aged resident cohort at canopy closure. Then z* equals the
     cohort's height, and the tie is split.
   - An invader cohort taller by ε is entirely in the canopy.
   - Every PPA analysis avoids this through assumptions the deterministic
     cohort model lacks: random individual fates and many ages at once in a
     stationary closed canopy.

### 4.3 What transfers

**[Judgement]**
1. **z*(a) as a coordinate for the light field.**
   - From the resident's run, compute z*(a) as the height at which cumulative
     crown (or leaf) area equals ground area.
   - Project the invader's light sensitivity δφ/δL(z, a) (the field hook)
     onto δφ/δz*(a), and measure the residual.
   - A small residual means the light field's effective dimension is one per
     age. That bears directly on `frontier.md` H1 and H2.
2. **Ẑ* (Adams et al.) as a check on g in the long-lived, closed-canopy limit.**
   Where the late-successional part of the record dominates selection, the
   sign of g should follow the change in monoculture Ẑ*. A disagreement points
   to the early-successional or water channels.

---

## 5. Recommendations for our representation

1. **Name the two adjoints by their MFG roles, and expose both** (§1.2).
   - The invader costate is the Nash costate. The resident costate is the
     McKean–Vlasov control costate.
   - Their difference is the δ/δm term, the commons resolved by state, age and
     birth date.
   - Report the angle between g and F_θ as a directional "price of anarchy".
2. **Test for potential structure before looking for optimisation
   principles** (§1.3).
   - Check symmetry of s₁₂ from the existing chords. Or, with the field hook,
     check symmetry of K_ij = ⟨S(θ_i), I(θ_j)⟩ over a strategy library.
   - If K is symmetric, evolution follows the gradient of a potential, a
     Lyapunov function for the canonical equation. This is expected when
     water in one layer is limiting, and not when light is.
   - Rank one is MMD's stronger condition.
3. **Report Lasry–Lions monotonicity as a diagnostic.** Use the sign of the
   symmetric part of K. Where it fails, expect several equilibria and founder
   control (Adams et al. 2007). Locate them with PIPs; local gradients will
   miss them.
4. **Treat the constant-rain race as a tie density, and represent it on
   purpose.**
   - **Diagnostic.** The gradient's tie term is reproductive value × light
     contrast × the resident's leaf-area density at the invader's height
     (§3.1). Report that density along the life. When it is resolved by one
     node, flag the gradient as non-existent and return one-sided limits.
   - **Physical model choice.** If smooth answers are wanted, add
     within-cohort variance as a property of the model, either:
     - (a) a birth-date spread for each introduction, i.e. finite-width
       cohorts;
     - (b) a diffusion term in growth, i.e. a second-order MFG.

     Set σ from observed height variation in even-aged stands, and hold it
     fixed. It is a model parameter, not a numerical knob; the objectives'
     reproducibility criteria apply only after it is fixed.
   - **Expect a mixed or polymorphic outcome** in the σ → 0 limit (§3.2,
     Iwasa et al. 1985), not a smooth ESS.
5. **Smooth the inner optimum the same way, if corners matter.** Use a
   softened leaf operating point with a temperature, and report the
   zero-temperature limit (McNamara et al. 1997).
6. **Build calendar-time climate as common noise through b(t) only** (§1.5).
   - The cheapest exact-derivative route: AD impulse responses of seed output
     to b and to climate at a lag, assembled as Toeplitz kernels around the
     stationary state.
   - The linear response of b(·) to any climate path is then a convolution
     solve, and fitness a linearised Lyapunov exponent.
   - Full nonlinear common-noise equilibria (Carmona–Delarue–Lacker) are not
     needed for small fluctuations.
7. **Use z*(a) and water by layer as the first reduced coordinates of the
   field** (§4.3). Measure what they miss before investing in randomised SVD
   of the full field (`frontier.md` §4.4).
8. **What not to import.**
   - Forward–backward MFG solvers (Achdou–Capuzzo-Dolcetta finite differences;
     Benamou–Carlier augmented Lagrangian; fictitious play) are not needed for
     the resident run, because individuals do not anticipate.
   - They become relevant only if a control is made forward-looking, or for
     multi-species assembly, where fictitious play over traits is a damped
     best-response iteration with known local convergence for potential games
     (Briani & Cardaliaguet 2018).

---

## References

All entries checked against Crossref for authors, year, venue and DOI.
"Abstract checked" means a content claim used above was compared with the
abstract or text. "Meta only" means only bibliographic data was checked.

- Achdou, Y., Bardi, M. & Cirant, M. (2017) Mean field games models of segregation. *Math. Models Methods Appl. Sci.* 27, 75–113. doi:10.1142/S0218202517400036 (meta only)
- Achdou, Y. & Capuzzo-Dolcetta, I. (2010) Mean field games: numerical methods. *SIAM J. Numer. Anal.* 48, 1136–1162. doi:10.1137/090758477 (meta only)
- Achdou, Y., Han, J., Lasry, J.-M., Lions, P.-L. & Moll, B. (2022; online 2021) Income and wealth distribution in macroeconomics: a continuous-time approach. *Rev. Econ. Stud.* 89, 45–86. doi:10.1093/restud/rdab002 (abstract checked; transpose statement checked in the authors' numerical appendix)
- Adams, T.P., Purves, D.W. & Pacala, S.W. (2007) Understanding height-structured competition in forests: is there an R* for light? *Proc. R. Soc. B* 274, 3039–3048. doi:10.1098/rspb.2007.0891 (abstract checked)
- Ahn, S., Kaplan, G., Moll, B., Winberry, T. & Wolf, C. (2018) When inequality matters for macro and macro matters for inequality. *NBER Macroeconomics Annual* 32, 1–75. doi:10.1086/696046 (meta only)
- Auclert, A., Bardóczy, B., Rognlie, M. & Straub, L. (2021) Using the sequence-space Jacobian to solve and estimate heterogeneous-agent models. *Econometrica* 89, 2375–2408. doi:10.3982/ECTA17434 (abstract checked)
- Baye, M.R., Kovenock, D. & de Vries, C.G. (1996) The all-pay auction with complete information. *Econ. Theory* 8, 291–305. doi:10.1007/BF01211819 (meta only)
- Bayraktar, E., Cvitanić, J. & Zhang, Y. (2019) Large tournament games. *Ann. Appl. Probab.* 29, 3695–3744. doi:10.1214/19-AAP1490 (abstract checked)
- Benamou, J.-D. & Carlier, G. (2015) Augmented Lagrangian methods for transport optimization, mean field games and degenerate elliptic equations. *J. Optim. Theory Appl.* 167, 1–26. doi:10.1007/s10957-015-0725-9 (meta only)
- Boppart, T., Krusell, P. & Mitman, K. (2018) Exploiting MIT shocks in heterogeneous-agent economies: the impulse response as a numerical derivative. *J. Econ. Dyn. Control* 89, 68–92. doi:10.1016/j.jedc.2018.01.002 (meta only)
- Briani, A. & Cardaliaguet, P. (2018; online 2017) Stable solutions in potential mean field game systems. *NoDEA* 25, art. 1. doi:10.1007/s00030-017-0493-3 (abstract via arXiv 1612.01877)
- Brown, J.S. & Vincent, T.L. (1987) A theory for the evolutionary game. *Theor. Popul. Biol.* 31, 140–166. doi:10.1016/0040-5809(87)90026-8 (meta only)
- Campi, L. & Fischer, M. (2018) N-player games and mean-field games with absorption. *Ann. Appl. Probab.* 28, 2188–2242. doi:10.1214/17-AAP1354 (meta only)
- Cantrell, R.S., Cosner, C., Lam, K.-Y. & Mazari-Fouquer, I. (2025) Mean field games and ideal free distribution. *J. Math. Biol.* 91. doi:10.1007/s00285-025-02276-z (abstract checked)
- Cardaliaguet, P., Delarue, F., Lasry, J.-M. & Lions, P.-L. (2019) *The Master Equation and the Convergence Problem in Mean Field Games.* Annals of Mathematics Studies 201, Princeton University Press. doi:10.23943/princeton/9780691190716.001.0001 (meta only)
- Cardaliaguet, P. & Graber, P.J. (2015) Mean field games systems of first order. *ESAIM: COCV* 21, 690–722. doi:10.1051/cocv/2014044 (abstract checked)
- Cardaliaguet, P. & Hadikhanloo, S. (2017) Learning in mean field games: the fictitious play. *ESAIM: COCV* 23, 569–591. doi:10.1051/cocv/2016004 (meta only)
- Cardaliaguet, P. & Lehalle, C.-A. (2018; online 2017) Mean field game of controls and an application to trade crowding. *Math. Financ. Econ.* 12, 335–363. doi:10.1007/s11579-017-0206-z (meta only)
- Cardaliaguet, P. & Rainer, C. (2019) On the (in)efficiency of MFG equilibria. *SIAM J. Control Optim.* 57, 2292–2314. doi:10.1137/18M1172363 (abstract checked)
- Carmona, R. & Delarue, F. (2018) *Probabilistic Theory of Mean Field Games with Applications* I and II. Springer. doi:10.1007/978-3-319-58920-6; doi:10.1007/978-3-319-56436-4 (meta only)
- Carmona, R., Delarue, F. & Lachapelle, A. (2013; online 2012) Control of McKean–Vlasov dynamics versus mean field games. *Math. Financ. Econ.* 7, 131–166. doi:10.1007/s11579-012-0089-y (abstract checked via search record)
- Carmona, R., Delarue, F. & Lacker, D. (2016) Mean field games with common noise. *Ann. Probab.* 44, 3740–3803. doi:10.1214/15-AOP1060 (abstract checked)
- Carmona, R., Graves, C.V. & Tan, Z. (2019) Price of anarchy for mean field games. *ESAIM: Proc. Surveys* 65, 349–383. doi:10.1051/proc/201965349 (abstract checked)
- Carmona, R. & Zhu, X. (2016) A probabilistic approach to mean field games with major and minor players. *Ann. Appl. Probab.* 26, 1535–1580. doi:10.1214/15-AAP1125 (meta only)
- Che, Y.-K. & Gale, I. (2000) Difference-form contests and the robustness of all-pay auctions. *Games Econ. Behav.* 30, 22–43. doi:10.1006/game.1998.0709 (meta only)
- Cirant, M. (2015) Multi-population mean field games systems with Neumann boundary conditions. *J. Math. Pures Appl.* 103, 1294–1315. doi:10.1016/j.matpur.2014.10.013 (meta only)
- Claisse, J., Ren, Z. & Tan, X. (2023) Mean field games with branching. *Ann. Appl. Probab.* 33, 1034–1075. doi:10.1214/22-AAP1835 (abstract checked)
- Dasgupta, P. & Maskin, E. (1986) The existence of equilibrium in discontinuous economic games, I: theory. *Rev. Econ. Stud.* 53, 1–26. doi:10.2307/2297588 (meta only)
- de Roos, A.M. (1988) Numerical methods for structured population models: the escalator boxcar train. *Numer. Methods Partial Differ. Equ.* 4, 173–195. doi:10.1002/num.1690040303 (meta only; not used for a content claim)
- Delarue, F. (2019) Restoring uniqueness to mean-field games by randomizing the equilibria. *Stoch. PDE: Anal. Comp.* 7, 598–678. doi:10.1007/s40072-019-00135-9 (meta only)
- Detto, M., Levine, J.M. & Pacala, S.W. (2022) Maintenance of high diversity in mechanistic forest dynamics models of competition for light. *Ecol. Monogr.* 92, e1500. doi:10.1002/ecm.1500 (meta only)
- Diekmann, O., Jabin, P.-E., Mischler, S. & Perthame, B. (2005) The dynamics of adaptation: an illuminating example and a Hamilton–Jacobi approach. *Theor. Popul. Biol.* 67, 257–271. doi:10.1016/j.tpb.2004.12.003 (meta only)
- Drugov, M. & Ryvkin, D. (2020) How noise affects effort in tournaments. *J. Econ. Theory* 188, 105065. doi:10.1016/j.jet.2020.105065 (abstract checked)
- Dybzinski, R., Farrior, C., Wolf, A., Reich, P.B. & Pacala, S.W. (2011) Evolutionarily stable strategy carbon allocation to foliage, wood, and fine roots in trees competing for light and nitrogen. *Am. Nat.* 177, 153–166. doi:10.1086/657992 (abstract summary via search)
- Falster, D.S. & Westoby, M. (2003) Plant height and evolutionary games. *Trends Ecol. Evol.* 18, 337–343. doi:10.1016/S0169-5347(03)00061-2 (as in `theory.md`)
- Farrior, C.E., Dybzinski, R., Levin, S.A. & Pacala, S.W. (2013) Competition for water and light in closed-canopy forests. *Am. Nat.* 181, 314–330. doi:10.1086/669153 (meta only)
- Foguen Tchuendom, R. (2018; online 2016) Uniqueness for linear-quadratic mean field games with common noise. *Dyn. Games Appl.* 8, 199–210. doi:10.1007/s13235-016-0200-8 (abstract checked via RePEc)
- Gerchak, Y. & He, Q.-M. (2003) When will the range of prizes in tournaments increase in the noise or in the number of players? *Int. Game Theory Rev.* 5, 151–165. doi:10.1142/S0219198903000957 (meta only; content claim from a search summary)
- Givnish, T.J. (1982) On the adaptive significance of leaf height in forest herbs. *Am. Nat.* 120, 353–381. doi:10.1086/283995 (as in `theory.md`)
- Gomes, D.A., Mohr, J. & Souza, R.R. (2010) Discrete time, finite state space mean field games. *J. Math. Pures Appl.* 93, 308–328. doi:10.1016/j.matpur.2009.10.010 (meta only)
- Hirshleifer, J. (1989) Conflict and rent-seeking success functions: ratio vs. difference models of relative success. *Public Choice* 63, 101–112. doi:10.1007/BF00153394 (meta only)
- Hopenhayn, H.A. (1992) Entry, exit, and firm dynamics in long run equilibrium. *Econometrica* 60, 1127–1150. doi:10.2307/2951541 (abstract via the Econometric Society record; free-entry detail from standard treatments)
- Hopkins, E. & Kornienko, T. (2004) Running to keep in the same place: consumer choice as a game of status. *Am. Econ. Rev.* 94, 1085–1107. doi:10.1257/0002828042002705 (abstract checked)
- Hsiao, V. & Nau, D. (2022) A mean field game model of spatial evolutionary games. *Proc. AAMAS 2022*, 606–614. doi:10.65109/syja4336 (meta only; DOI as returned by Crossref)
- Huang, M. (2010) Large-population LQG games involving a major player: the Nash certainty equivalence principle. *SIAM J. Control Optim.* 48, 3318–3353. doi:10.1137/080735370 (meta only)
- Huang, M., Malhamé, R.P. & Caines, P.E. (2006) Large population stochastic dynamic games: closed-loop McKean–Vlasov systems and the Nash certainty equivalence principle. *Commun. Inf. Syst.* 6, 221–252. doi:10.4310/CIS.2006.v6.n3.a5 (meta only)
- Iwasa, Y., Cohen, D. & León, J.A. (1985) Tree height and crown shape, as results of competitive games. *J. Theor. Biol.* 112, 279–297. doi:10.1016/S0022-5193(85)80288-5 (abstract checked)
- Iwasa, Y., Odendaal, F.J., Murphy, D.D., Ehrlich, P.R. & Launer, A.E. (1983) Emergence patterns in male butterflies: a hypothesis and a test. *Theor. Popul. Biol.* 23, 363–379. doi:10.1016/0040-5809(83)90024-2 (meta only)
- Kohyama, T. & Takada, T. (2009) The stratification theory for plant coexistence promoted by one-sided competition. *J. Ecol.* 97, 463–471. doi:10.1111/j.1365-2745.2009.01490.x (abstract checked)
- Krusell, P. & Smith, A.A., Jr. (1998) Income and wealth heterogeneity in the macroeconomy. *J. Polit. Econ.* 106, 867–896. doi:10.1086/250034 (meta only; content via secondary sources)
- Lasry, J.-M. & Lions, P.-L. (2007) Mean field games. *Japanese J. Math.* 2, 229–260. doi:10.1007/s11537-007-0657-8 (meta only)
- Lazear, E.P. & Rosen, S. (1981) Rank-order tournaments as optimum labor contracts. *J. Polit. Econ.* 89, 841–864. doi:10.1086/261010 (meta only)
- Mäkelä, A. (1985) Differential games in evolutionary theory: height growth strategies of trees. *Theor. Popul. Biol.* 27, 239–267. doi:10.1016/0040-5809(85)90001-2 (meta only)
- Mazuryn, M. & Thygesen, U.H. (2023) Mean field games for diel vertical migration with diffusion. *Bull. Math. Biol.* 85. doi:10.1007/s11538-023-01154-3 (abstract checked)
- McNamara, J.M. & Houston, A.I. (1996) State-dependent life histories. *Nature* 380, 215–221. doi:10.1038/380215a0 (meta only)
- McNamara, J.M., Houston, A.I. & Collins, E.J. (2001) Optimality models in behavioral biology. *SIAM Rev.* 43, 413–466. doi:10.1137/S0036144500385263 (meta only)
- McNamara, J.M., Webb, J.N., Collins, E.J., Székely, T. & Houston, A.I. (1997) A general technique for computing evolutionarily stable strategies based on errors in decision-making. *J. Theor. Biol.* 189, 211–225. doi:10.1006/jtbi.1997.0511 (abstract checked via search record)
- Monderer, D. & Shapley, L.S. (1996) Potential games. *Games Econ. Behav.* 14, 124–143. doi:10.1006/game.1996.0044 (meta only)
- Nalebuff, B.J. & Stiglitz, J.E. (1983) Prizes and incentives: towards a general theory of compensation and competition. *Bell J. Econ.* 14, 21–43. doi:10.2307/3003535 (meta only)
- Nutz, M. & Zhang, Y. (2019) A mean field competition. *Math. Oper. Res.* 44, 1245–1263. doi:10.1287/moor.2018.0966 (abstract checked)
- Purves, D.W., Lichstein, J.W., Strigul, N. & Pacala, S.W. (2008) Predicting and understanding forest dynamics using a simple tractable model. *PNAS* 105, 17018–17022. doi:10.1073/pnas.0807754105 (text checked for the Z* definition)
- Reiter, M. (2009) Solving heterogeneous-agent models by projection and perturbation. *J. Econ. Dyn. Control* 33, 649–665. doi:10.1016/j.jedc.2008.08.010 (meta only)
- Skaperdas, S. (1996) Contest success functions. *Econ. Theory* 7, 283–290. doi:10.1007/BF01213906 (meta only)
- Strigul, N., Pristinski, D., Purves, D., Dushoff, J. & Pacala, S. (2008) Scaling from trees to forests: tractable macroscopic equations for forest dynamics. *Ecol. Monogr.* 78, 523–545. doi:10.1890/08-0082.1 (abstract checked)
- Tembine, H., Le Boudec, J.-Y., El-Azouzi, R. & Altman, E. (2009) Mean field asymptotics of Markov decision evolutionary games and teams. *Proc. GameNets 2009*, 140–150. doi:10.1109/GAMENETS.2009.5137395 (meta only)
- Thygesen, U.H. & Mazuryn, M. (2022) Ideal free flows of optimal foragers: vertical migrations in the ocean. *Theor. Ecol.* 15, 213–224. doi:10.1007/s12080-022-00538-w (meta only)
- Vincent, T.L. & Brown, J.S. (2005) *Evolutionary Game Theory, Natural Selection, and Darwinian Dynamics.* Cambridge University Press. doi:10.1017/CBO9780511542633 (meta only)

**Not verified, so not relied on for specifics:**
- the exact pure-strategy existence condition in Lazear & Rosen (1981);
- Frank's positional-goods books;
- Tullock (1980) (book chapter, no DOI checked);
- the content of Mäkelä (1985);
- whether de Roos's EBT carries within-cohort variance (searches found first
  moments only, so it is not cited for that);
- Magal & Zhang (arXiv 1609.00185).
