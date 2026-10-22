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

## 8. Experiments, in order

1. **The cut in plant:** g_cut = g_invader to about 1e-12 on long drought and episodic, with
   its cost.
2. **One-shot on regnans's toy harnesses** (GM99, DD99, GK98) against `community_solve_singularity()`:
   the same roots, counted in model evaluations.
3. **One-shot on TF24 at m = 1,** two traits, against the roadtest's nested step. The node
   schedule is held through the solve.
4. **Coalitions with a regularised birth-rate step:** split at a branching point, one-shot to
   the pair, and classify. This is the refine step of `assembly.md` §4; the toy's unregularised
   version works but has no margin.
