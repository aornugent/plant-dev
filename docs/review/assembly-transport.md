# Assembly as rate–distortion

**Status.**
- **A derivation, checked on a toy** (`spikes/transport/`: `rd.R`, `probe.R`, `schedule.R`, each with its `.txt`).
- **Starts from:** I8 of the theory search (`search/portfolio.md` §3: "assembly as optimal
  transport"). It takes that idea one step further, to the object that matches the lottery
  exactly.
- **Builds on:**
  - `assembly-geometry.md`: the niche–field duality and the convex non-invadable set;
  - `assembly-mfg.md`;
  - `field-cut.md`: S and g from the cut.

**The claim.**
1. **The equilibrium is a rate–distortion optimum.** Take a lottery metacommunity with global
   seed rain (Levene's soft selection, at the level of species). Its equilibrium maximises
   mean log-fitness minus the mutual information between species and site.
2. **Its generation is Blahut–Arimoto.** One generation of the lottery is one Blahut–Arimoto
   iteration.
3. **The coupling is entropic optimal transport** between the regional pool and the sites.
   The pool is the NPMLE of a mixing distribution.
4. **Field feedback adds a congestion term,** which keeps the problem convex when competition
   is symmetric.

Every object in the formulation is something plant computes or should compute, and the
formulation sets the node schedule's requirements. A prior-art search (§8) found no source
for 1–3.

## 1. The identity

**The setup.**
- Sites s have weight K_s, and a strategy θ_j has per-seed lifetime success W_js = e^{φ_js}.
- Each generation, every site is filled by lottery among the seeds that arrive from a global
  pool P:

    n_js = K_s P_j W_js / f_s,  f_s = Σ_k P_k W_ks,  P′_j = Σ_s n_js.

**The derivation.**
- By the Gibbs (Donsker–Varadhan) identity, ln Σ_j P_j e^{φ_js} = max_q ⟨q, φ_·s⟩ − KL(q ‖ P).
- Summing over sites and maximising over P, the KL terms become a mutual information:

    max_P Σ_s K_s ln Σ_j P_j W_js = max over couplings π with site marginal K of
      ⟨π, φ⟩ − I_π(species; site).                               (1)

**Readings of (1):**
- **Rate–distortion** at unit inverse temperature, with distortion −φ.
- **Blahut–Arimoto.** The alternation "conditional q_s ∝ P e^{φ_·s}, then P = Σ_s K_s q_s" is
  Blahut–Arimoto, and it is the lottery's generation.
- **The equilibrium coupling** has the Sinkhorn form π = diag(P) W diag(K/f). It is the
  entropic OT plan between the pool and the sites.
- **The left side** is Li's (1955) Lyapunov function for the Levene model and the
  log-likelihood of a mixture with mixing distribution P. The ESS pool is the NPMLE
  (Kiefer–Wolfowitz).

**The certificate.**
- The regional invasion fitness D(θ) = Σ_s K_s W(θ, s)/f_s is Lindsay's gradient function.
- Non-invadability, D ≤ 1 everywhere with equality on the support, is necessary and
  sufficient for the global optimum.
- Concavity of the logarithm turns it into a bound:

    L* − L(P) ≤ ln max_θ D(θ).                                  (2)

  The best invader's ln R′ bounds how far the community's log-yield is from the ESS community.

**Toy check (T1):** 8 species and 30 sites.
- The lottery's fixed point, ⟨π, φ⟩ − I(π), and an independent BFGS optimum agree. BFGS stops
  1.5e-6 short.
- The lottery coupling equals Sinkhorn's to 3e-16.
- D = 1 on the support and D < 1 off it.
- A site-common shift of φ (standard deviation 3) moves P by 6e-17.

**Two marginals behave differently:**
- **The site marginal is fixed** (the lottery's capacity).
- **The species marginal is chosen by (1).**

A shift of φ common to every species at one site is absorbed into the site potential
ln(K_s/f_s) and changes nothing. A shift common to one species at every site is a real
advantage.

## 2. Evolution, branching and richness

**Set-up for traits.**
- Let φ(θ; y) = A(S) + S·y, the field-cut embedding, with S = S(θ) and the twist condition
  that θ ↦ S is injective.
- A is the frontier. In `assembly-geometry.md` §4b its conjugate is Ψ(y). Here −A is the
  log-partition of an exponential family in which S is the natural parameter and the site's
  field y the observation.
- For a quadratic frontier A = −|S|²/2c, the kernel is a Gaussian location mixture of
  x_s = c y_s with variance c.

**The canonical equation's fixed point is the codebook centroid.** For ∂_S D = 0:

    S_j = c E_π[y | j],                                          (3)

the Lloyd step of rate–distortion. It is the best response to the sites the species actually
occupies, weighted by its success in each (Holt & Gaines' source–sink weighting).

**Branching is codebook splitting.**
- ∂²_S D at (3) is positive when c λ_max(Cov_π(y | j)) > 1.
- That is the critical temperature of deterministic annealing (Rose 1998). It is also the
  Levene branching condition: the spread of local optima exceeds the width of selection.
- Past the critical point the two species separate as √(c Var − 1), a pitchfork.
- The branching cascade of adaptive dynamics is the annealing schedule of rate–distortion.

**Toy check (T2):** uniform sites on [−R, R], c = 1, so R_c = √3.

| R | species | max D over a fine grid |
|---|---|---|
| 1.70 | 1 | 1.000000 |
| 1.75 | 2 | 1.000000 |
| 3 | 2 | **1.0036** |
| 4 | 3 | 1.000000 |
| 6 | 6 | 1.000000 |
| 8 | 8 | 1.000009 |
| 12 | 18 | 1.000008 |

Past R_c, the separation divided by √(c Var − 1) is 3.01, 2.69, 2.58, 2.48 and 2.40 at
c Var − 1 = 0.009, 0.03, 0.08, 0.20 and 0.33: the square-root law near the split.

**Branching alone does not reach the ESS community.**
- At R = 3, each of the two species' cells has within-cell variance 0.75 < 1, so neither
  branches. Yet a third species invades the gap between them (max D = 1.0036).
- Adaptive dynamics with branching finds a local optimum of (1) and can stop there.
- **The global probe is not optional:** adding the strategy that maximises D. That is the
  lean algorithm's column generation, which is the vertex-direction / support-reduction
  method for the NPMLE (Groeneboom, Jongbloed & Wellner 2008; Wang 2007).
- Bound (2) says when to stop.

**Richness.**
- **1D,** with the probe (`probe.txt`): 2, 3, 3, 6, 9 and 19 species at R = 2, 3, 4, 6, 8 and
  12. The mean spacing falls from 2.5 to 1.2 niche widths, so richness grows faster than the
  field's range.
- **2D,** branching only: 4, 4, 28 and 84 species at R = 2, 3, 4 and 6. R = 3 is trapped
  (max D = 1.038). The run with the probe is in `probe.txt`.
- **The NPMLE literature bounds it:**
  - in 1D, at most C·(range)² atoms for any data (Polyanskiy & Wu 2020, Theorem 1), and
    O(log n) for subgaussian field distributions;
  - for d ≥ 2 the bound is only conjectured as (log n)^{C(d)}, and the support may be
    unbounded even with bounded data (Polyanskiy & Sellke 2025, not checked).

  The field dimension d that we measure is the dimension of that problem.

**Evolution as a flow.**
- Weights move by the lottery (Fisher–Rao) and atom positions by the canonical equation
  (Wasserstein, with M as the metric). Together they form a Wasserstein–Fisher–Rao flow on
  trait measures.
- For a concave objective like (1), Chizat's conic particle method converges globally from a
  wide initial pool.
- This gives the one-shot step a second form: start wide and let weights fall to zero,
  instead of starting with one species and branching.

## 3. Field feedback

**The model.**
- In plant the field is made by the community, so φ_js = φ⁰_js − (A p_s)_j, where p_s is the
  composition at s.
- **With A symmetric positive semidefinite (stabilising, the convexity of
  `assembly-geometry.md` §2),** (1) gains a congestion term,

    max_π ⟨π, φ⁰⟩ − ½ Σ_s K_s ⟨p_s, A p_s⟩ − I_π(species; site),

  still concave and unique. This is the Cournot–Nash-through-OT structure of Blanchet &
  Carlier (2016).
- **A skew part of A** (light's asymmetry, the "zero-sum tournament" of `search/r2-2-…`)
  leaves monotonicity, and so uniqueness, intact, but removes the potential. Assembly then has
  no objective, and simple ascent can circle.

**Toy check (T5):** 5 species and 12 sites.
- A symmetric A, and the same with a skew part 2× and 8× its size, each reached one
  equilibrium from 8 starts (spread < 1e-15).
- The damped iteration (damping 0.2) did not circle at these strengths.

**For plant:**
- (1) and (2) are exact where the field's effect on contrasts does not depend on composition.
  That holds in the founder window, where W₀ ∝ 1/b is the site potential K/f.
- Elsewhere the congestion and skew parts are measurable from the kept sweep's β columns
  (A = ⟨u, O⟩).

## 4. The map onto plant

| Rate–distortion / OT | plant |
|---|---|
| site s, weight K_s | birth date s within a patch, weight p(s), the patch-age density. Across a landscape, a site's record |
| the source measure, quantised | the node schedule |
| distortion −φ(θ, s) | −ln of the lifetime offspring of a seed of θ born at s: the per-node contribution to R′ |
| site potential ln(K_s/f_s) | the site-common part of the field's effect, which composition cannot see |
| natural parameter S_j | the field adjoint the cut zeroes, minus its site-common part |
| codeword update (3) | one canonical-equation step: g from the cut, H from forward-over-reverse |
| splitting test | the H/J classification at a singular strategy |
| Blahut–Arimoto marginal step | the resident's equilibrium in b |
| gradient function D(θ), bound (2) | invasion fitness R′ from `run_mutant`; the certificate, now quantitative |
| support reduction | the lean algorithm: probe, re-equilibrate, drop |
| congestion matrix A | the kept sweep's β columns |
| inverse problem (§5) | the site-selection workflow |

The new parts are bound (2), the requirement for a global probe, and §5–§6.

## 5. Site selection is the inverse problem

**The model.** At a site, the composition is the Gibbs conditional of (1):

  ln q(j | s) = α_j + S_j · y_s − ln Z_s,  α_j = ln P_j + A(S_j).

- With S_j from the cut, this is a multinomial logit in the unknown field y_s, concave
  jointly in (α, y).
- **It is CATS** (Shipley et al. 2006). The traits are mechanistic sensitivities, the
  multipliers are the community-made field, and the prior is the regional pool.
- **CATS's community-weighted-mean constraint** is the dual of y. When sensitivity equals
  impact it is the mass balance of consumption, y_s = y⁰_s − Σ_j p_js C_j.

**Identification.**
- Composition identifies field contrasts between sites.
- The common level needs α, that is the pool and the frontier.

**Toy check (T4):** 6 species, 2 field dimensions, 25 sites, 400 individuals per site.
- With the pool and frontier known, the field is recovered to rms 0.11, against a field
  standard deviation of 1.
- With the pool unknown, the rms is 0.11 after removing one shift common to all sites,
  (−0.31, 0.12).

**For the workflow:** one cut sweep per species at a reference field gives S_j. After that,
every site is a convex fit with no plant run, and plant runs serve only as correctors where
the embedding's error matters.

## 6. What it asks of the node schedule

The theory's requirements of the scheduler, against `OBJECTIVES.md`:

1. **Contrasts, not levels, set composition.**
   - An error in ln W common to every strategy at one birth date is absorbed by the site
     potential and moves neither which species persist, nor their abundance, nor g.
   - It does move the balance F (density).
   - So ε on F stays as written; the selection targets (g, entry and exclusion signs) are on
     contrasts between strategies on one schedule. That is why "Shared" (invaders on their
     resident's schedule) is the right objective: shared nodes make the common error cancel.
2. **Place nodes by quantising the birth-date measure in the field's metric.**
   - The community depends on the sites only through the contrasts of φ(·, s).
   - Quantising s into M cells (masses exact, field at each cell's centroid) costs about
     Σ_cells mass × Var_cell(contrast). That is minimised by node density

       n(s) ∝ ρ(s)^{1/3} ‖∂_s y(s)‖_G^{2/3},                       (4)

     with G = Cov_P(S), the abundance-weighted covariance of the codebook's sensitivities
     (Zador at r = 2; equidistribution).
   - The monitor ‖∂_s y‖_G is the rate at which strategies' relative success changes with
     birth date. It comes from one pilot run, from the per-node contributions of the
     codebook's strategies.
   - Early nodes come out of (4) wherever the field moves fast. Nothing about the patch start
     is assumed.
   - Toy check (`schedule.txt`):
     - **The setup.** A field y(s) = 8e^{−s/0.4} + 2 sin(s/3) over patch ages 0–40 with an
       exponential ρ supports four species, two of them early-patch specialists holding 1.8%.
     - **The result.** Loss in log-yield on the true measure, and the species count:

       | nodes | uniform | geometric (first cell 0.05) | (4) |
       |---|---|---|---|
       | 12 | 0.11, 2 | 0.19, 4 | 1.5e-3, 3 |
       | 24 | 0.11, 2 | 1.0e-2, 4 | 2.5e-4, 3 |
       | 48 | 0.086, 3 | 2.0e-3, 4 | 9.9e-6, 4 |
       | 96 | 7.7e-3, 3 | 3.4e-5, 4 | 4.7e-7, 4 |

     - **Reading it.**
       - Uniform placement never finds the specialists.
       - Placement by (4) is 70–1,000× better in log-yield than geometric from 12 nodes up.
       - Geometric finds the fourth species sooner, because it spends its nodes where the
         rare specialists live. (4) weights them by their mass, which is small.
3. **Tolerance shrinks near a bifurcation.**
   - Whether a strategy branches turns on the sign of c λ_max − 1 (that is, of H), and just
     past it traits move as √(c Var − 1).
   - Near a split, the error allowed in H is the distance to the split. The error allowed in
     the field's spread is that distance squared, measured in traits.
   - `OBJECTIVES.md`'s "the sign of fitness where a decision turns on it" should include the
     sign of H at a singular strategy.
4. **No manufactured ties.**
   - Uniqueness of the assignment needs the twist condition: distinct strategies read the
     field differently.
   - A schedule that gives two strategies identical contrasts across a block of nodes, as
     zero-spread nodes at a tied canopy top did, breaks it. The best response then jumps.

## 7. What it predicts

- **Mutual information between species and site is what specialisation costs.**
  - A landscape supports as many species as the field's spread can pay for, in niche widths,
    at the given dispersal mixing.
  - Global seed rain is β = 1. Local retention raises β, approaching sharp matching
    (unregularised OT, Brenier).
- **Successional richness.** Within a patch, the codebook covers patch age. The number of
  successional strategies grows with the field's arc length over the patch's life, in units
  of niche width, weighted by ρ^{1/3}.
- **Assembly by branching alone stops short** wherever a gap between species' cells is
  invadable but no cell is wide enough to split: the R = 3 case. Communities assembled from a
  regional pool (global probing) should be richer than those built by in situ diversification
  in the same landscape.

## 8. Prior art and what is new

A literature check is recorded in the session. Its scope: about 40 searches. It read primary
text for Polyanskiy–Wu, Frank (2011), Shipley (2010) and Mayer et al.; otherwise it relied on
abstracts.

- **Not found:**
  - the lottery or Levene model as Blahut–Arimoto or rate–distortion;
  - branching as deterministic-annealing phase transitions;
  - the ESS community as an NPMLE, with invasion as Lindsay's gradient;
  - Cournot–Nash-through-OT in ecology;
  - optimal-quantisation or equidistribution node placement for the SCM or EBT;
  - a spatial species–site mutual information tied to growth.
- **Partly found, to cite:**
  - Kondratyev, Monsaingeon & Vorotnikov (2016): fitness-driven dispersal as an unbalanced-OT
    gradient flow, in physical space;
  - Chalub, Monsaingeon, Ribeiro & Souza (2021): the replicator as a Shahshahani flow;
  - Jabin & Liu (2017);
  - Shipley (2010): CATS justified verbally by selection;
  - Warton, Shipley & Hastie (2015): CATS as a Poisson GLM;
  - Mayer, Balasubramanian, Mora & Walczak (2015): an immune repertoire optimised against a
    pathogen distribution concentrates on few clones, the same mathematics as §2;
  - Li (1955) and Nagylaki: the Levene Lyapunov function;
  - Cover (1984) and Csiszár–Tusnády (1984): the multiplicative update.
- **To read before claiming:** Blanchet & Carlier (2016); Rose (1998); Parker, Gedeon &
  Dimitrov (2002); Polyanskiy & Sellke (2025).

## 9. Limits

- **The lottery is exact only where the field acts on all strategies alike.** In plant that
  holds in the founder window and approximately at closure. Elsewhere §3 applies, and light's
  skew part removes the objective. (2) then becomes a heuristic, and convergence needs
  damping or extragradient steps.
- **The quadratic frontier and affine embedding** make the toy a Gaussian mixture. TF24's
  frontier is not quadratic, and its embedding has rank 2–4 with an error.
- **Birth dates are not independent sites:** a seed born at s meets the field from s onward.
  Treating s as a site is exact for R′ (it is an integral over s) but the field y(s) is a
  trajectory, so the monitor in (4) is a per-node contrast rate, not a field value.
- **β = 1 assumes global dispersal each generation.** With partial retention the kernel is
  not exactly e^{βφ}.
