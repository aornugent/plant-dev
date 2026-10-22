# The geometry of assembly: self-limitation is convexity

**Status.** A claim with one test. The projection identity and its consequences are measured
on the worked example (`spikes/assembly-example/`, `project_field()`). The extension to plants
and the crown-shape prediction are *derived* and untested. I have not searched the literature
for the specific links in §3–4; check them before leaning on them.

**The claim.** One geometric quantity sets five things at once:
1. whether coexistence is stable;
2. whether the assembled community is unique or depends on history;
3. whether assembly is a convex problem, so which algorithms carry guarantees;
4. how well conditioned the solve is;
5. how sensitive its predictions are to parameter error.

The quantity is **how a strategy's impact on the field lines up with its own sensitivity to
the field**. In forests, light competition (one-sided, size-asymmetric) pushes it one way and
water (shared, symmetric) the other. Crown architecture, Horn's monolayer–multilayer
trade-off, is the plant's own dial on it.

## 1. Assembly as a projection

For a fixed strategy θ, write the fitness in a field E. Linearised in the field:

  φ(θ; E) ≈ φ(θ; E₀) + ⟨S(θ), E − E₀⟩,

so θ cannot grow on a half-space. The **non-invadable set** is

  𝒩 = { E : φ(θ; E) ≤ 0 for every θ }.

It is the set of fields no strategy can grow in, and it is convex whenever each φ(θ; ·) is
convex in E. In the worked example φ is linear in R for fixed θ, so 𝒩 is an intersection of
half-spaces.

Suppose impacts are minus sensitivities through a fixed positive-definite metric Λ:

  c(θ) = −Λ S(θ).

In MacArthur's model Λ = I, because a consumer depletes what it eats. Then the equilibrium
conditions of §3 of the report are exactly the KKT conditions of

  E* = argmin_{E ∈ 𝒩} ½ ‖E − K‖²_{Λ⁻¹},

with K the field without residents (the supply point). Reading the KKT conditions:
- **E*** is the projection of the supply point onto the non-invadable set;
- **the residents** are the strategies whose half-spaces are active at E*, the supporting
  faces;
- **their densities** are the Lagrange multipliers: K − E* = Λ Σ_j N_j S_j;
- **evolution** places each resident at the θ whose face supports 𝒩 at E*. Pricing,
  max_θ φ(θ; E*), finds the supporting face.
- **m ≤ d** holds because a point of a d-dimensional set is supported by at most d faces
  generically.
- **Supply independence** (report §6): projecting onto a vertex gives the same point for
  every supply in that vertex's normal cone. Only the multipliers, the densities, move.
- **Robustness:** a species persists for supplies inside its normal cone, and the cone's
  angular width is its robustness to perturbations. This is the geometric form of Meszéna's
  |det|.

**Measured.** Cutting planes on the projection call only invader evaluations: project K onto
the cuts so far, price in that field, add the best strategy's cut. With zero resident runs:
- **d = 2:** the community matches the algebra and the lean route to 1e-6.
- **d = 3:** three species, R* and densities, match to 6e-5. Plain cutting planes have a slow
  tail on the curved envelope, so the run hit 100 iterations.
- **d = 3, σ = 0.23:** the cold lean route diverged here. The projection returns a clean
  three-species community, with |F| = 1e-16 and |g| = 2e-5 at one confirming resident run.
- **Projection (6 cuts) then lean:**
  - d = 3: 7 resident runs instead of 27;
  - σ = 0.23: 7 runs, converging where the cold start failed;
  - every case gives the same community, certified.

Modelled wall time on this example is similar to the lean route's, because the cutting-plane
phase re-prices from the full grid each cut. The gain is resident runs and robustness.

## 2. When the projection holds, and the general case

Two conditions made it a projection.

**(A) Each strategy's response to the field is convex in the field.** Then 𝒩 is convex.
- *Holds:* substitutable or linear dependence, as in MacArthur.
- *Fails:* saturating or co-limiting dependence, such as photosynthesis saturating in light,
  or light and water as essential resources (Liebig's law). Tilman's L-shaped
  zero-net-growth isoclines are the classic case. Then 𝒩 can be non-convex, and several
  local projections, several communities, can exist.

**(B) Impact is aligned with sensitivity:** c(θ) = −Λ S(θ) with one Λ for all strategies.
Then the competition kernel

  A(θ, θ′) = −⟨S(θ), c(θ′)⟩ = ⟨S(θ), Λ S(θ′)⟩

is symmetric and positive semidefinite. The community minimises the Lyapunov function
MacArthur found: assembly is convex optimisation over measures on trait space.

**Without (B),** A has a skew part, and the right object is the symmetric part A_s = ½(A + Aᵀ).
- **A_s positive semidefinite on the strategies in play** makes assembly a *monotone*
  variational inequality over measures. That is a "stable game" in Hofbauer & Sandholm's
  sense (2009): externalities are self-defeating. Then:
  - the field E* is unique;
  - the set of communities is convex;
  - projection-type and extragradient methods converge from anywhere;
  - no priority effects.
- **A_s indefinite** loses all of that: several communities, history dependence and
  possibly cycles can appear.

**What A_s ⪰ 0 means biologically.** For two species it is

  A₁₁ ≥ 0,  A₂₂ ≥ 0,  (A₁₂ + A₂₁)² ≤ 4 A₁₁ A₂₂:

each limits itself more than the pair limit each other on average. That is Chesson's
stabilising niche difference. Niche overlap ρ < 1 for a symmetric pair is exactly this
condition, generalised here to any number of species, any traits and any field. **Chesson's
stabilisation is the convexity modulus of the assembly problem.** The smallest eigenvalue of
A_s on the active set is, at once:
- how strongly coexistence is stabilised;
- how far the problem is from losing uniqueness;
- the strong-monotonicity constant that sets convergence rates;
- how well its predictions are determined: predicted densities respond to parameter error
  through A⁻¹, so dN*/dp grows like 1/λ_min.

That is the trade-off: **stabilisation buys computability.**

## 3. Plants: light is one-sided, water is shared

**Light.** Species j's leaves shade every height below them, while i senses light where its
leaves are. So A(i, j) is large when j is taller than i, and near zero when j is shorter. The
kernel is close to triangular in height order: competition is size-asymmetric. A triangular
kernel's symmetric part is indefinite unless self-limitation dominates:

  (A_ij + A_ji)² ≤ 4 A_ii A_jj  with A_ji ≈ 0  ⇒  A_ij² ≤ 4 A_ii A_jj.

Shading of others must stay below twice the geometric mean of the two self-limitations.

**Water.** A shared soil pool that every root draws on gives A ≈ S Sᵀ: symmetric and
positive semidefinite, so convex.

**Self-limitation in light comes from crown depth and conspecific shading:**
- **Deep, multilayer crowns** (Horn 1971) shade their own lower leaves. A_ii is large, so the
  problem stays monotone.
- **Flat-topped monolayer crowns** shade others and barely themselves. A_ii is small, so
  monotonicity can fail.

**Prediction (*derived*):** crown shape is a dial on the computational class of forest
assembly. Under deep crowns or water limitation, the assembled community is unique and found
by convex methods. Under flat crowns and light limitation, expect alternative communities and
history dependence; the regnans hysteresis sweep becomes necessary rather than a check. The
boundary is a measurable eigenvalue crossing zero, so the onset of priority effects should be
predictable from the trait values. In TF24 the crown-shape parameter is the knob to sweep.

## 4. Opinionated choices this licenses

1. **Measure the regime before choosing the algorithm.** The cut gives each resident's S,
   and the sweeps give C, so A on the active set and the tracked candidates costs nothing
   extra. Report two numbers:
   - λ_min(A_s), the stabilisation and convexity margin;
   - the skew ratio ‖A − Aᵀ‖ / ‖A + Aᵀ‖.
2. **Where λ_min(A_s) > 0, assemble in field space.**
   - Use projection or extragradient with cutting planes from pricing. It needs invader runs
     only, is globally convergent, and the community it finds is the community.
   - Polish with the exact Newton master, a handful of resident runs: 27 → 7 on the example.
   - The duality gap of the projection is an a-posteriori bound on the distance to the
     answer, in fitness units. That is the same currency as the scheduler's certified error,
     so one tolerance can govern both.
3. **Where λ_min(A_s) < 0, change the question.** "The community" is not well defined.
   Report the set of communities reached from a declared history: continuation from the
   empty field, and from the neighbour sites. Name the eigen-direction that breaks
   monotonicity, which says which species pair carries the priority effect.
4. **Split light from water.**
   - Water's symmetric, convex part goes to the projection.
   - Light's near-triangular part is solved by ordering species by height and sweeping from
     the top (Gauss–Seidel on the complementarity problem). This is the logic of the
     perfect-plasticity approximation's z*, used as a preconditioner rather than a model.

   Residuals stay exact, so the split costs no correctness, only rate.
5. **Assemble at a stated resolution.** A species' normal-cone width, equivalently its
   multiplier margin, is its robustness. When that is below the model's certified error
   (schedule, climate sampling), the species is not a prediction. Stop pricing there.
   The scheduler's ε then fixes:
   - the effective d (modes with singular values above ε);
   - how many species can be resolved;
   - how accurately each must be computed.

   Precision beyond what stabilisation supports buys nothing.

## 5. Tests, in order

1. **A on TF24.** Compute A from one recording of two or three residents (S from the cut, C
   from the sweeps), with the field-dimension spike's settings. Report λ_min(A_s) and the
   skew ratio. Until the cut is in plant, S and C can come from finite differences.
2. **Sweep TF24's crown-shape parameter** and watch λ_min(A_s). If it crosses zero, run the
   lean route from two different histories at a value past the crossing and see whether
   they disagree.
3. **A toy with one-sided light competition**, a triangular kernel plus self-shading, to
   confirm the crossing and the onset of alternative communities analytically.
4. **The projection with a better localisation** (analytic-centre cutting planes, or
   sliding cuts, where each active cut's θ takes a Newton step instead of adding a new cut).
   Measure pricing cost against the lean route.

## References

- Chesson, P. (2000) *Annu. Rev. Ecol. Syst.* 31: 343–366;
- Hofbauer, J. & Sandholm, W.H. (2009) *J. Econ. Theory* 144: 1665–1693 (stable games);
- Horn, H.S. (1971) *The Adaptive Geometry of Trees*;
- MacArthur, R.H. (1970) *Theor. Popul. Biol.* 1: 1–11;
- Meszéna, G. et al. (2006) *Theor. Popul. Biol.* 69: 68–87;
- Tilman, D. (1982) *Resource Competition and Community Structure*.

All are from memory, unchecked.
