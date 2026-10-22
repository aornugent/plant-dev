# The field cut, and assembly without an equilibrium loop

**Status.** A proposal with a working toy (`spikes/field-cut/`), not built in plant. Numbers are
measured on the toy unless marked *estimated*. F is one single-species TF24 forward run at b*
(49–77 s). It sharpens `assembly.md` §2 and §4 and answers one question: with birth-rate and
selection gradients from one recording, does assembly still need its equilibrium step?

**The answer.**
- **The field cut.** Sweep a resident's recording a second time with the field's adjoints
  zeroed wherever the field is built. That pass returns the selection gradient g, exactly the
  invader's, at the cost of one more sweep. Together with the ordinary sweep, one recording
  gives F, ∂F/∂ln b, F_θ and g: every first derivative regnans takes at the residents.
- **The equilibrium condition stays; the equilibrium loop goes.** The evolved community is
  defined by F = 0 and g = 0 together, so equilibrium is half the answer. But it need not be
  converged before every evolutionary step. One recording per step moves birth rates and
  traits together, and lands on the same point.
- **On the toy:**
  - **One species:** a singular strategy costs 14 recordings, against 46 for a nested Newton
    equilibrium and 280 runs plus 13 recordings for regnans's nested iteration. The answers
    agree to 1.5e-8.
  - **Two residents split from the resulting branching point:** 47 recordings, against
    19,080 runs for nested iteration (15 s against 411 s). The nested Newton fails there.
- **No second derivatives.** regnans's planned joint Newton (#53) needs ∂g/∂n and ∂g/∂x,
  which its roadmap calls the hardest quantities. This needs only first derivatives, all of
  them from the one recording.
- **In equations** (§8). The frequency-dependent part of the selection Jacobian factors
  through the field, so its rank is at most d. That bounds what many traits can do (§9):
  - lineages split only along a ≤ d-dimensional subspace U of the trait space;
  - at most d species coexist;
  - every other trait is a held-field best response, the EEO problem, given a species'
    position in U.
- **Faster assembly** (§10): find U first; price a whole candidate pool at once and solve one
  rank-d complementarity problem; then refine only the survivors, one-shot.

## 1. What one recording returns

| Quantity | Sweep | regnans name |
|---|---|---|
| F_i = ln J_i − ln b_i | the recording's value | — |
| ∂F_i/∂ln b_j, m × m | one kept sweep per species | f_n (E3) |
| ∂F_i/∂θ_j with the field responding (F_θ) | the same sweeps | f_x (E4) |
| g_j, every trait of every species, field held | **one** cut sweep, seeded with Σ_i F_i | the selection gradient (E2) |
| the invader's field sensitivity S = δ ln R′/δE | the adjoints the cut zeroes | the field hook |
| reproductive value with and without the externality | the two sweeps' costates | — |

**One cut sweep serves every species.** With the field held, F_i reaches no other species'
inputs. So a single cut sweep seeded with F_1 + … + F_m leaves g_j on species j's traits.
On two species the toy checks that each g_j equals species j's own invader gradient, to 0.0.

## 2. Why the cut gives g

Write invader fitness as ln R′(θ′; E), a function of the invader's traits and the field E it
stands in. The resident's own fitness is the invader at θ′ = θ in the field the residents make:

  F(θ, b) = ln R′(θ; E(θ, b)).

The chain rule splits every resident derivative into a held-field part and a field part:

  F_θ = g + S · E_θ,  F_{ln b} = S · E_{ln b},  with g = ∂ ln R′/∂θ′ and S = ∂ ln R′/∂E.

The reverse pass of F carries adjoints back through E into the inputs. Zeroing them at each
point where E is built removes S · E_θ and S · E_{ln b}, and leaves g. What it zeroes is S.
The commons, F_θ − g = S · E_θ, is what a trait does to the field, priced by the field's
value to an invader.

The mechanism is XAD's public interface, in the pattern odelia's `implicit_value` already
uses. While recording, keep the tape position and the field's slots after each field build.
Then, last to first: sweep to the mark, read and zero those adjoints, truncate. The truncation
means the cut is the last sweep a recording gets. odelia records step by step, so in plant
that means the cut seed is carried beside the kept ones and swept last on each step.

## 3. Do we need the equilibrium step?

**The condition, yes.** g at a seed rain off equilibrium is the gradient in a field the
residents would not make, and the resident is not at its attractor. The evolved community is
the root of

  G(ln b, θ) = (F, g) = 0,

m + mk equations in as many unknowns. Every reported quantity is read there.

**The loop, no.** regnans nests: converge F = 0 at the current θ (7–47 runs), take g, step θ,
converge again. With F_{ln b} and F_θ on the same recording as g, a step can do both at once:

1. **Traits:** δθ from the selection step on g. Here that is quasi-Newton (Broyden), restarted
   from steepest ascent if a step would go against selection. That makes the search follow
   adaptive dynamics to convergence-stable points.
2. **Birth rates:** Newton on F, predicted along the trait step through the implicit-function
   tangent:

     δ ln b = −F_{ln b}⁻¹ (F + F_θ δθ).

After the step the equilibrium residual is second order in the step. So each recording reads g
at a seed rain within O(|δ|²) of equilibrium. The trait iteration therefore sees the same map
the nested route sees, up to second-order terms, and both routes have the same fixed points.
Without the F_θ term, b lags each trait step at first order. That costs 4× as many recordings
on the toy (§4).

This is the one-shot (piggyback) iteration of PDE-constrained optimisation, applied to the
eco-evolutionary root. The nested route corresponds to "nested analysis and design"; this is
"simultaneous analysis and design" without the second derivatives a full joint Newton needs.
Broyden learns the reduced Jacobian from successive g. The cost is superlinear rather than
quadratic convergence.

**What it does not replace:**
- **Classification.** ESS needs the held-field invader Hessian, and convergence stability
  needs the Jacobian of g along the equilibrium. Both are second order: chords of invader
  sweeps and of one-shot steps, or Broyden's estimate as a first look.
- **Trajectories.** The canonical equation asks for b at equilibrium along the path. The
  predictor keeps b within O(h²) of it, so an explicit integrator of order ≤ 2 should take
  one recording per stage. That is untested.
- **Entry and exit.** A species whose b → 0 leaves the active set (`assembly.md` §4). The
  capped Newton step here does not handle it; a complementarity solver would.

## 4. The toy

`spikes/field-cut/one_shot.cpp`, on the stand of `field_cut.cpp` (24 cohorts, a light field
and soil water). A leaf cost on the leaf-area trait gives an interior singular strategy.
Allocation to reproduction and leaf area evolve as logit and log. The stopping rule is
|F| < 1e-10 and |g| < 1e-8 at one point.

| Route, one species | steps | forward runs | recordings | sweeps | seconds |
|---|---|---|---|---|---|
| nested, iteration ln b ← ln b + F (regnans) | 13 | 280 | 13 | 26 | 2.8 |
| nested, Newton on the taped F_{ln b} | 13 | 0 | 46 | 92 | 3.7 |
| **one recording per step** | 14 | 0 | **14** | 28 | **1.2** |
| the same without the F_θ term | 62 | 0 | 62 | 124 | 5.0 |

- All four reach allocation 0.13530, leaf area 1.06861 and ln b* = −0.86116, agreeing to
  1.5e-8.
- **The point is a branching point.** The held-field invader Hessian has eigenvalues −4.4
  and +12.5. The Jacobian of g, with the equilibrium re-solved, has −4.7 and −0.77. It
  attracts, and then it splits: in `assembly.md`'s terms, pricing brings in a second species.
- **Toy timings understate the gain.** Recording costs 7.5 double runs in the toy, against
  about 1–2 in TF24, so counts are the better guide.

**Two residents, split by 0.1 from the branching point** along the Hessian's positive
direction, then solved to their singular coalition (four traits, two birth rates):

| Route, two species | steps | forward runs | recordings | seconds |
|---|---|---|---|---|
| nested, iteration (regnans) | 48 | 19,080 | 48 | 411 |
| nested, Newton on the taped F_{ln b} | — | 0 | 716 | failed |
| **one recording per step** | 47 | 0 | **47** | **15** |

- **Iteration and one-shot reach the same pair:**
  - allocation 0.2310 / 0.1873;
  - leaf area 1.2077 / 1.1540;
  - b = 0.931 / 0.057.

  They agree to about 1e-8.
- **Nested iteration pays about 400 runs per evolutionary step.** Two near-identical
  residents make the map's multiplier close to 1.
- **The nested Newton failed.** Right after the split, the residents are nearly the same
  species, so F_{ln b} is nearly singular: Meszéna's |det| → 0, the robustness of coexistence
  vanishing. With traits held, the equilibrium is barely determined. The plain capped Newton
  wandered along the near-neutral ratio until one ln b underflowed.
- **The one-shot never needs that equilibrium.** Its traits move apart while b settles. It
  inverts the same ill-conditioned F_{ln b}, and survived here. That is not a guarantee
  (§7).
- **The coalition is not classified.**

**Two species, traits held.**
- Newton on the taped 2 × 2 F_{ln b} reaches the coexisting equilibrium (b = 0.0503 and 1.537)
  in 8 recordings. Iteration takes 264 runs: its multiplier is the spectral radius of
  I + F_{ln b}, close to 1 when species interact.
- Every F_{ln b} entry matches central differences to 1e-9–1e-10.
- The one cut sweep's g matches both species' invaders to 0.0. Its ln b adjoints are 0.

## 5. Scaling in m and k

**One step:**
- one recording of the m residents;
- m kept sweeps;
- one cut sweep.

Trait count k does not enter. m enters linearly through the kept sweeps, which give the
m × m F_{ln b}. A nested step costs an equilibrium solve (iteration contracts more slowly as m
grows) plus g. regnans takes g by finite differences: 2k invader runs per species.

**In TF24** (*estimated*):
- A recording plus one sweep is 2.14 F, measured with 51 columns at m = 1.
- A further sweep is about 0.5 run (plant#677's spikes: one metric at 5× an FF16 run, five
  at 7×).
- So one step is about 2.1 + 0.5(m + 1) F: about 3 F at m = 1, 4 F at m = 3.

regnans's nested step at m = 1 is a warm equilibrium (about 7 runs with schedule refinement)
plus 2k invader runs at 0.6 F. That is about 10 F at k = 2 and 67 F at k = 50. Step counts are
similar on the toy, so the gain is about 3× at k = 2 and 20× at k = 50, before multi-species
iteration slows the nested equilibrium further.

## 6. What plant and odelia change

As `assembly.md` §7, with the line references checked there:
- marks in `Patch::compute_environment`, after the field is built and before it is read,
  only when the scalar carries adjoints;
- a visitor listing the field's values (light spline knots, slopes and `height_max_`, soil
  water and `psi_soil_`, not `water_flux`);
- one cut seed carried beside the kept seeds through odelia's step adjoints, swept last;
- the SCM seeding it with Σ_i F_i.

Today's invader gradient is the check: any missing or misplaced mark shows as g_cut ≠ g_invader.

For the scheduler, the one-shot iteration is the case `workflows.md` §6 item 3 anticipated: b
changes every step, so the node schedule is held across a solve and certified once at the
root. Refinement mid-solve would put a discrete jump into G.

## 7. Risks

- **Several roots.** Without the ascent restart, Broyden found a different singular point in
  an earlier toy run: a non-ESS where nearby invaders grow. The restart rule, or the
  classification at the end, is not optional.
- **Far from the root,** g at an unconverged b is a poor guide, and the step caps (0.25 in
  trait, 1 in ln b) matter. A warm start from the previous community is the normal case in
  assembly.
- **Extinction during the solve** needs the complementarity treatment, not a capped Newton.
- **Near-singular F_{ln b} after a split.** |det F_{ln b}| → 0 as two residents coincide. A
  split needs a regularised birth-rate step (Levenberg–Marquardt, or the pair's mean and
  ratio solved separately), and a split distance chosen from the Hessian's curvature, not
  a constant.
- **The cut consumes the recording.** Any sweep wanted after it needs a new recording.
- **Plant's cut cost** is unmeasured; odelia's stepwise sweep keeps each step's tape small,
  which is where the toy measured 0.99 of a kept sweep.

## 8. In equations

**Objects.**
- Species i = 1…m carry traits θ_i ∈ ℝᵏ and seed rain b_i, with β_i = ln b_i.
- The field is E = 𝓔(θ, β): light by height and patch age, and water by layer and time.
- Invader fitness φ(θ′; E) = ln R′ is computed in a held field. A resident is an invader at
  its own traits: F_i(θ, β) = φ(θ_i; 𝓔(θ, β)).
- The local quantities:

  | Symbol | Meaning | Meszéna's name |
  |---|---|---|
  | g_i = ∂_θ′ φ(θ_i; E) | selection gradient | — |
  | S_i = δφ(θ_i; E)/δE | sensitivity | S_i |
  | C_j = ∂𝓔/∂β_j | impact | C_j |
  | H_i = ∂²_θ′θ′ φ | held-field Hessian | s₁₁ in `theory.md` A |
  | G_i = ∂_E g_i = ∂²φ/∂θ′∂E | how selection on i depends on the field | — |

**The chain rule**, with ⟨·,·⟩ the pairing of a sensitivity with a field perturbation:

  ∂F_i/∂β_j = ⟨S_i, C_j⟩,  ∂F_i/∂θ_j = δ_ij g_i + ⟨S_i, ∂𝓔/∂θ_j⟩.

The first is Meszéna's a_ij = S_i·C_j, so |det ∂F/∂β| is the robustness of coexistence.

**The cut.** Reverse mode sums ∂F/∂(input) over paths in the recorded graph. Partition the
paths by whether they pass through a field node. Zeroing each field node's adjoint, once all
of its readers have been swept, deletes exactly the paths through the field. The rest are the
derivative with E held, so ∂_θ_i φ(θ_i; E) = g_i, and 0 for β. Sweeping last to first, the
adjoint a field node holds when zeroed counts only paths that avoid later field nodes; that
is S. And since F_j does not reach θ_i with E held for j ≠ i, a single cut sweep of Σ_j F_j
returns every g_i.

**The root.** The assembled community is x* = (β*, θ*) with

  F(x*) = 0,  g(x*) = 0,  and  max_θ′ φ(θ′; E*) ≤ 0,

and b_i ≥ 0, F_i ≤ 0, b_i F_i = 0 over any candidate pool (`assembly.md` §4).

**The one-shot step.** Record at x_k; read F, F_β, F_θ, g; then

  θ_{k+1} = θ_k + δ_k,  δ_k = −B_k⁻¹ g_k,
  β_{k+1} = β_k − F_β⁻¹ (F_k + F_θ δ_k),

with B_k Broyden's estimate of the reduced Jacobian.

Let β*(θ) solve F(θ, β) = 0, and define the reduced gradient and its Jacobian, the Schur
complement of the full Jacobian:

  ĝ(θ) = g(θ, β*(θ)),  J = ∂ĝ/∂θ = g_θ − g_β F_β⁻¹ F_θ.

Taylor's theorem gives:
- F(x_{k+1}) = O(|Δ_k|²);
- β_{k+1} − β*(θ_{k+1}) = O(|Δ_k|²);
- g(x_{k+1}) = ĝ(θ_{k+1}) + O(|Δ_k|²).

The perturbation is o(|δ|), so Broyden on ĝ keeps its local superlinear convergence
(Dennis–Moré). The fixed points are δ = 0 ⇔ g = 0 and Δβ = 0 ⇔ F = 0: the same root as the
nested route. No second derivative is formed; g_θ and g_β appear only inside J, which B_k
learns.

**Classification at the root,** for one resident (`theory.md` A.3):

  J = H + M,  M = G · dE*/dθ,  dE*/dθ = ∂𝓔/∂θ − C F_β⁻¹ F_θ.

- **ESS:** H ≺ 0.
- **Strongly convergence stable:** J + Jᵀ ≺ 0 (Leimar 2009; Geritz, Metz & Rueffler 2016).
- **Branching:** strongly convergence stable and not ESS.

## 9. What fifty traits can separate

*Derived, not yet tested beyond k = 2.*

**1. M has rank at most d.** M = G · dE*/dθ factors through the field. If the field is
effectively d-dimensional (the modes in which sensitivities differ), then rank M ≤ d,
whatever k is.

**2. Branching needs the field.** Let v be a disruptive direction (vᵀHv > 0) at a strongly
convergence-stable point (vᵀJv < 0). Then

  vᵀMv = ⟨Gᵀv, (dE*/dθ) v⟩ < 0.

A trait direction can split a lineage only if moving along it does two things:
1. it changes which parts of the field the strategy depends on (Gᵀv ≠ 0);
2. it changes the field the strategy makes ((dE*/dθ) v ≠ 0).

The two must have opposite sign: negative frequency dependence. On null(M), which has at
least k − d dimensions, J = H, so convergence stability implies ESS there. Those directions
never split.

**3. At most d species** (Meszéna et al. 2006). Each resident is a zero-height peak of one
landscape φ(·; E*). Given E, the peak conditions g = 0 fix θ, and φ = 0 is then one more
condition on E. m residents put m independent conditions on the field, and they can hold
robustly only if the field has m independent directions that move the S_i. So m ≤ d, with
robustness |det⟨S_i, C_j⟩|.

**4. The rest are slaved.** Split θ = (u, w):
- u ∈ U, at most d dimensions, is where M acts: the separating coordinates;
- w is the rest.

Every resident has g = 0 in the common field, so w_i = w*(u_i; E*): its held-field best
response, given its niche coordinate. Within a community, species differ along at most
m − 1 ≤ d − 1 directions in u, and the other traits follow as syndromes.

**5. EEO and assembly divide the traits.** w*(u; E) is exactly what an EEO model computes:
optimality in a given environment. It is right for the slaved traits when given the right u
and E*. It cannot predict u or E*; those come from frequency dependence, that is from
assembly. This is the formal version of "EEO is a held-field best response" (`theory.md`).

**6. Neutral directions** are null(H) ∩ null(M). They are undetermined, drift, and should be
reported as such.

**What U should contain in TF24** (*hypotheses*, one per field component):

| Field component | Separating direction | Precedent |
|---|---|---|
| light by height | height at maturity, allocation to reproduction | Falster et al. 2017 |
| light by patch age (succession) | growth against shade survival: LMA, wood density | Pacala & Rees 1998; Falster et al. 2017 |
| water by depth | rooting depth and allocation | — |
| water by time (episodic) | hydraulic safety, stomatal strategy, storage | needs the non-additivity of Johnson & Hastings 2022 |

The rest of the 51 (Vcmax/Jmax coordination, leaf N, leaf size, many hydraulic constants)
should be slaved. Most likely d is small (2–4). Two global axes of plant form and function
(Díaz et al. 2016, from memory) would be what d ≈ 3 looks like across communities.

**How to measure U.**
- M = G · dE*/dθ is a rank-d product, and both factors come from machinery already planned.
- **G along the field modes:** g in fields perturbed along each mode, d invader sweeps.
- **dE*/dθ projected on the modes:** d resident reverse passes, each seeded with one mode
  as the field's cotangent. This is the two-stage adjoint's seed.
- **The modes:** the leading principal directions of the sensitivities S over the residents
  and a candidate pool.
- **Cost:** about 2d sweeps for U, against k² for a dense M.

## 10. Faster to an assembled community

From what the derivation buys, roughly in order of gain:

1. **Separating coordinates first.** Find U (§9), then search for coexistence and branching
   in ≤ d dimensions, not k. The slaved traits are k − d per-species best responses in a
   held field: the EEO problem, parallel across species. Pricing, the non-convex step,
   becomes a d-dimensional search that a coarse grid can cover globally.
2. **Price the whole pool at once; solve one low-rank complementarity problem.**
   - One invader run and sweep per candidate l gives φ_l and S_l. Its per-capita trajectory
     also gives its direct impact C_l.
   - Linearise the field about the current community, projected on the d modes:

       F_l ≈ φ_l + ⟨s_l, y⟩,  y = y₀ + Σ_j c_j b_j,  b ≥ 0, F ≤ 0, bF = 0.

   - Its matrix [⟨s_l, c_j⟩] has rank d, so its solution has at most d positive b
     (Meszéna's bound, as linear algebra). It is a d-dimensional problem in the field
     coordinates y.
   - Solve it, re-record the survivors, relinearise. A few rounds replace FitMax's one
     species per round.
   - *Untested.* The direct impact misses the residents' response; relinearising corrects
     it.
3. **Refine only the survivors,** one-shot (§3), in U, with entry and exit handled
   semismoothly in the same iteration.
4. **Warm starts along climate.** E* moves smoothly between nearby sites. The adjoint of the
   root predicts each next community (`assembly.md` §5).
5. **When d = 1, no assembly at all.** The ESS is a single optimisation through a scalar
   environment, such as the PPA's z* (Metz, Mylius & Diekmann 2008). The C.2 angle test
   (`assembly.md` §8) is the cheap check.

**Cost** (*estimated*, TF24, k = 50, d = 3):
- U: about 6 sweeps;
- a pool of 200 candidates in U: 120 F of invader runs, parallel;
- 3–5 relinearisations;
- a one-shot refine of ≤ 3 survivors: 15–50 steps at about 4 F.

That is a few hundred F of CPU and tens of F of wall time. regnans spends about 608 F per
singular strategy (`assembly.md` §1).

## 11. Experiments, in order

1. **The cut in plant:** g_cut = g_invader to about 1e-12 on long drought and episodic, with
   its cost.
2. **One-shot on regnans's toy harnesses** (GM99, DD99, GK98) against `community_solve_singularity()`:
   the same roots, counted in model evaluations.
3. **One-shot on TF24 at m = 1,** two traits, against the roadtest's nested step. The node
   schedule is held through the solve.
4. **Coalitions with a regularised birth-rate step:** split at a branching point, one-shot to
   the pair, and classify. This is the refine step of `assembly.md` §4; the toy's unregularised
   version works but has no margin.
5. **§9 on a toy with many traits.** Give the toy stand a few dozen traits, most of them
   physiology that changes neither field use nor field making. Measure M's rank and U. Check:
   - branching only along U;
   - assembled species differing only in U;
   - the rest at w*(u).
6. **§10's pool linearisation** on regnans's toys and then this stand: how many
   relinearisations to the FitMax community.

## References

Beyond `assembly.md`'s and `theory.md`'s lists:
- Dennis, J.E. & Moré, J.J. (1974) *Math. Comp.* 28: 549–560;
- Díaz, S. et al. (2016) *Nature* 529: 167–171 (from memory);
- Geritz, S.A.H., Metz, J.A.J. & Rueffler, C. (2016) *J. Math. Biol.* 72: 1081–1099;
- Leimar, O. (2009) *Evol. Ecol. Res.* 11: 191–208.
