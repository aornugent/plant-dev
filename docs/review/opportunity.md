# The derivative of evolution

The opportunity is bigger than cheaper fitness gradients, or a cheaper assembly
loop. **The outcome of the eco-evolutionary loop, the evolved and assembled
community, becomes a differentiable function of climate and physiology.** That
gives prediction, calibration and attribution for evolved communities. H1 and H2
turn out to be statements about the rank of that function's derivative.

*Established* results are cited; *derived* ones are ours, checked by no one;
*judgement* is marked.

## 1. The outcome is a fixed point, and fixed points can be differentiated without unrolling

The loop nests four fixed points:
1. each leaf's operating point, at every rate evaluation;
2. each resident's demographic equilibrium, F_i = ln J_i − ln b_i = 0;
3. each resident's evolutionary equilibrium, g_i = 0: a singular coalition;
4. the end of assembly: no strategy invades, max ln R′ ≤ 0.

Write the evolved community as x* = (θ_i*, ln b_i*), and its conditions as
G(x*, c) = 0. Here c is everything held fixed: the climate record, mean rainfall
and variability, the trade-off constants, the physiology.

Where G_x is invertible, the implicit function theorem gives

  dx*/dc = −G_x⁻¹ G_c,

with no need to unroll the iterations that found x*.
- *Established elsewhere:* deep equilibrium models differentiate a network's
  fixed point this way (Bai, Kolter & Koltun 2019, arXiv:1909.01377).
  Heterogeneous-agent macroeconomics computes Jacobians of aggregates around a
  stationary state by AD, and gets any shock's equilibrium response by linear
  algebra (Auclert, Bardóczy, Rognlie & Straub 2021, Econometrica 89:2375,
  doi:10.3982/ECTA17434).
- *Status here:*
  - Level 1 is done today: the leaf's implicit differentiation.
  - Level 2 is the equilibrium predictor (`../measurements/regnans-roadtest/rootcause/` §7).
  - Level 3's G_x is regnans PR #89's convergence Jacobian.
  - What is new is chaining them, with c as the climate and physiology.

**The pieces** (*derived*):
- **G_x**, the coalition's Jacobian: each species' g_i and F_i with respect to
  every trait and birth rate.
  - The F rows come from resident sweeps.
  - The g rows are second derivatives: chords of invader sweeps, used
    matrix-free (§3).
- **G_c**, how selection and demography respond to the climate or the physiology.
  - For a few directions (mean rainfall, variance, drought frequency, a trade-off
    constant), it is chords: two perturbed runs per direction.
  - For every day of the record, it is a second-order adjoint: the gradient of
    each g_i with respect to the rain.

## 2. What it unlocks

1. **Prediction.**
   - How an evolved community's traits shift under a change of climate, by
     comparative statics instead of re-running assembly.
   - That is what EEO is for in land-surface models (Harrison et al. 2021,
     doi:10.1111/nph.17558; Franklin et al. 2020, doi:10.1038/s41477-020-0655-x).
     Here it comes from a competitive game, not an assumed criterion.
2. **Calibration.**
   - Fit the trade-off constants and physiology, so that evolved communities
     reproduce observed trait–climate relationships across sites, by gradients
     through the evolutionary equilibrium (a bilevel problem).
   - The EEO model then becomes something one fits and can falsify.
3. **Attribution.** Which features of a climate shape the evolved traits: drought
   frequency or depth, seasonality, single events. This is the evolved-community
   form of adjoint event attribution in climate science.
4. **H1 and H2, restated as properties of dx*/dc.**
   - *H1:* the Jacobian from climate to evolved traits has low rank, and its
     column space lines up with observed trait spectra (Wright et al. 2004;
     Díaz et al. 2016). Few modes of feedback mean few directions in which
     evolved traits can move with climate.
   - *H2:* the number of coexisting species, and that rank, rise with
     variability at a fixed mean.
   - Where species are gained or lost, G_x is singular and dx*/dc diverges. Those
     are the boundaries between regimes, and regnans's boundary continuation
     (#84) traces them. Together they make a phase diagram of evolved communities
     over climate space.

## 3. Why the iteration accelerates, and what other fields call it

The IFT solves across a path of climates, or across assembly iterations, are a
sequence of related linear systems in G_x.
- *Established:* such sequences reuse a Krylov subspace from one solve to the
  next (Parks, de Sturler, Mackey, Johnson & Maiti 2006, doi:10.1137/040607277).
- *Established:* the few directions a function varies most in can be found from
  its gradients (Constantine 2015, Active Subspaces, doi:10.1137/1.9781611973860).
- *Derived:* if H1 holds, G_x acts within a low-dimensional subspace. Matrix-free
  solves (Krylov with Hessian-vector products from chords) then converge in about
  that many iterations, and the subspace found once serves the rest.
- *Judgement:* that is the self-accelerating loop, and the same low rank makes
  every later step cheaper.
- **Several outcomes.** Under one-sided light competition the game is not
  monotone, so founder control and several stable coalitions are expected
  (`lateral-games.md` §3; Adams, Purves & Pacala 2007,
  doi:10.1098/rspb.2007.0891). Deflation finds the distinct solutions of one
  system (Farrell, Birkisson & Funke 2015, doi:10.1137/140984798).

## 4. What the games review adds (`lateral-games.md`)

- **Two adjoints, two kinds of optimum.** The invader's adjoint is the Nash
  costate and the resident's is the planner's (Carmona, Delarue & Lachapelle
  2013). So g against F_θ is the price of anarchy, the commons, per trait.
- **An optimisation principle needs a potential,** and a potential needs a
  symmetric mixed derivative s₁₂: a local test with the chords we already have.
  It is the precondition for any EEO criterion to be exact.
- **Light breaks monotonicity:** several equilibria are generic.
- **The constant-rain race is a tournament with no noise.** It has no smooth
  equilibrium, and polymorphism is the expected outcome (Lazear & Rosen 1981;
  Iwasa, Cohen & León 1985). A spread within cohorts restores smoothness, with
  a width set by the spread.
- **Calendar-time climate couples patches only through the seed rain b(t),**
  which the sequence-space method handles with AD impulse responses.

## 5. Limits

- dx*/dc exists only where the coalition is a non-degenerate, convergence-stable
  attractor. At regime boundaries, at jumps (constant rain) and at the leaf's
  regime switches it does not; continuation and one-sided limits take over.
- G_x needs second derivatives. Matrix-free solves are affordable only if the
  rank is small, which is H1's question.
- Calibration is only as good as the match between the model's traits and the
  measured ones.

## 6. The smallest test

On long drought and episodic, with `lma` evolving alone:
1. Find the singular strategy θ*.
2. Compute dθ*/d(mean rainfall) by the IFT, with chords for G_x and G_c.
3. Compare with re-solving θ* at mean rainfall ± 5%.

If they agree, repeat with two traits, and look at the rank of the 2 × n_c
Jacobian over a few climate directions.
