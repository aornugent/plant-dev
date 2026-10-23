# Assembly and the eco-evolutionary loop with adjoints

**Status.** A design, not built. It takes the forward programme of `eeo-derivatives.md` and
regnans's roadmap (`regnans/ROADMAP.md`, read 22 Oct) and asks what assembly should look
like now that one recorded TF24 run differentiates. Numbers are measured unless marked
*estimated* or *derived*. F is one single-species TF24 forward run at b* (49–77 s).
Measurements cited from the tag `archive/trusting-curie` are the regnans roadtest
(`docs/measurements/regnans-roadtest/rootcause/`, E1–E8) and the regnans review
(`docs/review/regnans.md`).

The field cut and the one-shot solve at the centre of this plan are worked up, with a toy,
in `field-cut.md`. `assembly-report.html` has:
- the mathematics as a report;
- a worked example with the algebra beside the algorithm;
- the lean algorithm that replaces the master/pricing/refine loop of §4.

**The answer.**
- **One recording carries every derivative regnans takes at the residents.** Record the m
  residents once and sweep each species' ln J twice, with the field's adjoints kept and then
  cut. That gives F_i, the m × m Jacobian ∂F_i/∂ln b_j, F_θ for every trait of every species,
  and g for every trait (*derived*; the cut is being proved on a toy, §7).
- **Residents interact only through the field.** So the system's Jacobian is local curvature
  plus a field term of rank about d, Meszéna's regulating dimension. Expensive work scales
  with d + m, not m²k.
- **Assembly is column generation on a complementarity problem.** Births, deaths,
  equilibrium, evolution, merges and labels become one master solve on the residents' tape,
  plus pricing: invader searches in a held field, run in parallel.

## 1. What regnans does today

Read from the code at the local checkout (`R/assembler.R`, `births_maximum.R`,
`community_plant.R`, `community_demography.R`). One round of `assembler_step()` with the
defaults (`birth_type = "maximum"`, `evolve = "none"`):
1. **Birth.** `find_max_fitness()` runs a local maximisation from each resident and from the
   centre: golden section in one trait, Nelder–Mead then L-BFGS-B with finite-difference
   gradients in several. Each evaluation is `run_mutant` on the recorded resident. Building
   the fitness function first re-runs the resident to record it (0.8 F).
2. **Equilibrium.** Fixed-point iteration to `equilibrium_eps = 1e-5`. Each iteration is
   `run_scm(refine_schedule = TRUE)`, with the ODE schedule cleared.
3. **Deaths.** The inviability check calls the runner again, and once per low-abundance
   species it tests.
4. **Evolve.** Off by default. With `evolve = "newton"`, the coalition solve re-runs the
   equilibrium inside every gradient evaluation.

regnans was designed for exact derivatives but built without them. `harness_plant()`
advertises none; every plant derivative is a finite difference. Its cost model assumes
forward-mode tangents and mutants at 0.02–0.1 of a run. On TF24:
- a mutant costs 0.6 F;
- a cold equilibrium by iteration costs about 47 runs;
- a one-trait singular strategy and its classification cost about 608 F (the review's
  arithmetic, from `design-workflows.md` on the tag);
- the roadtest's step took 54–79 minutes.

## 2. What one recording gives

| Quantity | How | Status |
|---|---|---|
| F_i = ln J_i − ln b_i | the tape's value | built |
| ∂F_i/∂ln b_j, m × m (regnans's f_n, E3) | rows `"<i>.offspring_production"` × columns `"<j>.birth_rate"` of one sweep per output | measured for m = 1 (−0.7525, against the secant's −0.7457). The multi-species tape is supported (`test-gradient-ladder-two-species.R`: TF24, census metrics, record once and sweep many); cross-species fitness columns are unmeasured |
| F_θ, every trait of every species, field kept (f_x, E4) | the same sweeps | measured, 51 columns, 2.14 F |
| g_i, every trait, field held (E2) | a second sweep with the field's adjoints cut | **proved on a toy** (`spikes/field-cut/`): equals the invader's gradient bit for bit; not yet in plant. Today: an invader walk and sweep, 0.6 + 1.94 F |
| The commons, F_θ − g | the difference | follows |
| Costates: reproductive-value gradients ℓ∇V by cohort and age | on the tape | not exposed |
| Field sensitivities δφ/δE (Meszéna's S) | the field hook | spike, not merged |
| Census metrics (leaf area, mass) | `stand_gradient()` | in plant#648 |

**Why the cut gives g.**
- At θ′ = θ the invader is the resident: the same nodes, steps and field. R′ = J/b to 1e-12.
- Individuals interact only through the field (light; water through uptake), and b is held.
- So the resident's reverse pass, with every edge from individuals into the field removed,
  is the invader's reverse pass. That includes self-shading, which a rare invader doesn't
  have.
- In adjoint terms (`theory.md` F.3), the resident's costate is its own reproductive value
  plus the externality. Cutting the field removes the externality.

**Cost** (*estimated*): one recording of m species (about 2m F) plus one sweep per output.
Each sweep is marginal on the recording: plant#677's spikes measured one metric at 5× an FF16
run and five at 7×. So F, F_θ and g for all residents cost about one taped run. Today the
same takes 4.7 F per species and an invader run.

## 3. Structure along the causal chain

```
 climate c ─┐
 traits θ_j ─┼─► resident run ─► field E(z, ℓ, a) ─► invader map φ(θ′; E) ─► fitness
 seed rain b_j┘   (all species,     (light by height,      (local in θ′,
                   expensive)        water by layer)        held field)
```

1. **Residents couple only through E.**
2. **Both conditions are invader quantities at the residents' traits:** F_i = φ(θ_i; E) and
   g_i = ∇φ(θ_i; E).
3. **Envelope at the root.** With g_i = 0, ∂F_i/∂θ acts only through E.
4. **The field's effective dimension d bounds the community:** m ≤ d (Meszéna et al. 2006).

So (*derived*):

  G_x = blockdiag(H_i) + Φ_E · E_x.

- **H_i** is each resident's own held-field invader Hessian: local, invader runs only.
- **Φ_E · E_x** has rank about d.

A Krylov solve preconditioned by the H_i should converge in about d + m iterations.

**What the structure means.** The ESS is an inner optimum plus an outer loop:
- **Inner:** each resident's best response in a held field. This is the problem EEO models
  solve.
- **Outer:** field consistency, in about d + m dimensions.

The PPA-family ESS (Dybzinski et al. 2011; Farrior et al. 2013) is the d = 1 case, through
the canopy-closure height z*. If g ∥ F_θ in every trait (`theory.md` C.2, about 5 F), the
feedback is effectively one-dimensional, and the ESS is a single optimisation (Metz, Mylius &
Diekmann 2008).

## 4. Assembly as column generation

The evolutionarily stable community solves, over candidate strategies j,

  b_j ≥ 0,  F_j(b) ≤ 0,  b_j F_j(b) = 0.

FitMax solves it by column generation. The field is the dual price, and invasion fitness is
the reduced cost.

```
 MASTER  one taped run of the active residents per iterate: F, ∂F/∂ln b, g (cut), F_θ;
         semismooth Newton on the complementarity conditions; a column whose b → 0 leaves
 PRICING held field, parallel, invader runs only: gradient ascent of ln R′(θ′; E) in all
         k traits from several starts, steered by sensitivity functions; enter if > 0
 REFINE  active columns move along their own g; a column at a fitness minimum splits along
         the leading eigenvector of its held-field Hessian (Lanczos on invader chords)
 STOP    nothing prices positive, and every active g ≈ 0
```

| regnans step | Here |
|---|---|
| Viable bounds | pricing on the empty field; domain refusals set the edges |
| Birth (FitMax) | pricing, exact all-trait gradients |
| Equilibrium, deaths | no inner loop: each master step moves b with θ, b by Newton predicted through F_θ (`field-cut.md` §3); deaths leave the active set |
| Evolve, merge, daughter | refine |
| Label | the size of the active set |
| Boundaries (#60) | active-set events along a parameter path, by complementarity continuation |
| Classification | local checks at the end |
| Canonical equation | only for trajectories |

**Scaling.**
- **In m:** one run, linear in m, with the m × m Jacobian free. regnans instead pays one
  sequential round per species.
- **In k:** reverse mode costs the same for 1 trait or 50. Neutral directions drift and are
  reported as undetermined. Branching needs only the Hessian's leading direction.
- **Iterations:** about d + m in the master.
- **Pricing dominates:** about 25(m + 1) F per round (*estimated*), all in a held field and
  parallel.

**Sparsity is the theory.** Continuous coexistence is structurally unstable (Meszéna et al.),
so a complementarity solve over a dense pool returns few positive b. Precedents: Nash
equilibria of population games by complementarity solvers; Dantzig–Wolfe column generation;
oligomorphic dynamics (Sasaki & Dieckmann 2011, from memory). No search has been run on the
framing itself.

## 5. Differentiating the evolved outcome

For a scalar outcome L(x*, c) at the root G(x; c) = 0:

  dL/dc = ∂L/∂c − λᵀ G_c,  with  G_xᵀ λ = ∂L/∂x.

- **λ:** a small dense solve, about (d + m)², with H_i⁻¹ applied locally.
- **λᵀ G_c for every c at once:**
  - the F rows come from the stand sweep with c on the tape;
  - the g rows come from a chord of invader sweeps along λ_g, plus the two-stage adjoint.
- **The two-stage adjoint:** the invader's field sensitivities δφ/δE, from the field hook,
  are added as the field's cotangent in the resident's reverse pass. It returns
  ⟨δφ/δE, ∂E/∂p⟩ for every resident input p, including each day's rain. Cost: +12% of a
  sweep plus one resident reverse pass. Not built (`theory.md` B.6).
- **Cost** (*estimated*): about 10 F after the root for every parameter and every day of a
  40-year record. regnans's route costs two equilibrium solves per input.

**L can be a misfit to observations**, Σ(y_obs − y(x*, c))², for calibrating physiology so
the evolved community matches data. The site workflow is the same formula with a smaller
root:

| Root held | G | λ |
|---|---|---|
| eco-evolutionary | (F, g) | (λ_F, λ_g) |
| ecological, site rows balanced | F | λ_F |
| none, site rows unbalanced | — | — |

`site-selection.md`'s calibration, which holds rows, omits the field-mediated term that λ_F
and the two-stage adjoint supply.

**Prices.** Adjoints are prices in units of fitness:

| Price of | Object | Status |
|---|---|---|
| an individual's state at age a | reproductive-value gradient ℓ∇V (`theory.md` F.2) | on the tape |
| a trait, decomposed by birth date, age and state | generalised Caswell (F.1) | g built; decomposition not exposed |
| carbon to an individual | μ_C = λ·∂G/∂P (F.4) | not exposed |
| soil water to the stand | λ_W^stand (F.4) | not exposed |
| a mm of rain on day d, to the stand | E7 rainfall column, d ln J/d rain(d) | on the tape, not returned |
| a mm of rain on day d, to a rare variant | the two-stage adjoint | not built |

A rainfall column is the stand's water price where and when water arrives. Its Caswell-style
breakdown is density × ∇V × ∂(rates)/∂W × ∂W/∂rain(d). The stand's and the invader's columns
differ by the commons in water, day by day. λᵀG_c laid over the record attributes the evolved
outcome to each day's weather: which droughts set the ESS.

## 6. Costs, corrected

A dense Jacobian of the root costs about 3.5m²(k + 1) F (*estimated*): 1,600 at m = 3,
k = 50. And the 50-trait root is ill-posed along near-neutral directions. With the structure
of §3, at m = 3, k = 50, d = 5 and r = 3 per resident (assumed, to be measured):
- a root costs about 100–200 F;
- an all-input adjoint afterwards costs about 10 F.

The feasible problem tracks d + m and each resident's selected rank r, not m²k.

## 7. Risks, chased

- **Multi-species tapes: supported.** Columns are per species; the `"<j>.birth_rate"` columns
  give the m × m Jacobian; a TF24 two-species test records once and sweeps many. Unmeasured on
  TF24 at m ≥ 2: cross-species fitness columns against finite differences, and cost.
- **The field cut: proved on a toy** (`spikes/field-cut/`, C++ against odelia's XAD; 24
  cohorts, a light field and soil water, 1.08 million statements).
  - The cut pass's g equals the invader's at θ′ = θ to 0.0 in every trait.
  - The adjoints it zeroes are the invader's field sensitivities, all 67,559 to 0: the field
    hook comes free.
  - Stepwise, as odelia sweeps, it costs 0.99 of a kept pass, against 4.6–5.4× for the
    invader route.
  - It uses only XAD's public calls, in the pattern of odelia's `implicit_value`: mark the
    position and the field's slots after each field build; sweep to each mark, zero, and
    truncate. The cut pass must be a recording's last.
  - **In plant:**
    - marks in `Patch::compute_environment` (`patch.h:1350`), after
      `compute_environment_excl_capturing()` and `compute_environment_closing()` (:1424,
      :1426), only when the scalar carries adjoints;
    - a visitor listing the field values: TF24's light spline knots, slopes and
      `height_max_`, plus soil water and `psi_soil_`, but not `water_flux`;
    - cut seeds carried beside the kept ones through odelia's `sweep_each_seed`
      (`adjoint.hpp:279`), `state_and_parameter_adjoints` (:386) and the step adjoints
      (`ode_solver.hpp`, `ode_step_rkck.hpp`);
    - the SCM seeds it at `scm.h:1657`.

    Today's invader gradient becomes the tripwire for a missing or misplaced mark. Plant's
    cost ratio is unmeasured. (Line numbers checked against the local checkouts, 22 Oct.)
- **Pricing is non-convex.** It needs several starts, and races (constant rain, set aside)
  make it jump.
- **Several complementarity solutions** (alternative attractors): regnans's hysteresis sweep
  still applies.
- **Degenerate complementarity,** where b_i and F_i are both near 0. Semismooth or
  interior-point methods handle it in theory; on discretised fitness, the sign at the margin
  must be certified (see `../schedule/workflows.md` §6).
- **d and r may be large.** If the field coupling has rank of 10 or more, the master is no
  cheaper than dense. Measure first.
- **regnans's boundary principle** ("never know the light profile"). An opaque
  `regulating_variables` connector exposes S and C as vectors regnans never interprets. That
  is regnans's call; propose it as an issue.

## 8. Experiments, in order

1. **The field cut in plant** (the toy passed, §7): g_tape = g_invader to about 1e-12 on long
   drought and episodic; its cost against 4.7 F.
2. **The C.2 angle,** g against F_θ on two climates (about 5 F each). If they are parallel,
   the ESS is a single optimisation.
3. **d and r at an assembled community:** randomized range finding on the field coupling
   (resident tangents, invaders in perturbed fields), and Lanczos on H_i.
4. **Column generation on regnans's toys** (GK98, DD99, DD99_nd at k = 10–50) with their
   analytic derivatives, against FitMax: the same communities, fewer evaluations, and GK98's
   1 | 2 | 3 regions by active-set continuation.
5. **The master on TF24 with m = 2–3:** the roadtest's step re-timed. Prediction: about 2.4 F
   plus a 1–2-run equilibrium, against 9.4 measured.
6. **The adjoint of the root,** checked against regnans's per-parameter dx*/dp on the same
   held grid, and summed rainfall columns against a re-solve at ±5% rain.

## 9. Against regnans's roadmap

- **Met by one tape:** E1, E2 at the residents, E3, E4, and E5 in the form plant needs (a
  predicted b plus a held schedule; the light profile is not a fixed point here).
- **By chords:** E6 and E6b.
- **Gaps:** E7 (return the rainfall columns); the two-stage adjoint; the field hook.
- **Exceeded:**
  - the joint (n, x) Newton regnans plans, as the master;
  - "10–48 traits co-evolving", in the active subspace;
  - dx*/dp for every parameter and every day, from one adjoint;
  - Meszéna's robustness, |det ∂F/∂ln b|, per community;
  - the commons vector and Caswell attribution in every report;
  - climate, which regnans leaves out of scope.

## 10. Under variable climate

Which climate a run lives in is set by the question (`../schedule/workflows.md` §2) and by what
the model can represent (`theory.md` D.2–D.3). The machinery above holds in two of the three
worlds.

**1. Every patch replays one record from its disturbance (plant today).**
- A drought on day d hits every patch at age d. Climate varies along succession, which is
  spatial in Chesson's terms. The regional state is stationary, with one scalar b*.
- Each record is a separate deterministic world, with its own b*, its own field and its own
  evolutionarily stable community. The spread across records measures sensitivity to the
  realised record; it is not stochastic fitness.
- Everything here applies unchanged: F, g, the cut, the lean step and the projection. The
  measured field dimensions (d ≈ 3 open, ≈ 4–5 closed; `spikes/field-dimension-066/`) are per
  world.
- It cannot represent a regional drought hitting all ages at once, a fluctuating b(t), or a
  seed bank, so it has no temporal storage effect.

**2. A regime row: independent records per patch at a common b** (`theory.md` D.3.1). This is
where the eco-evolutionary loop lives, since the evolutionarily stable community is a regime
question.
- Fitness is the arithmetic mean of R′ over the row's records, exact because each patch's
  record is part of its birth state (Gyllenberg & Metz 2001). It is not the mean of ln R′.
  The equilibrium is E_ω J(b, ω) = b.
- **The machinery carries over:**
  - F = ln E_ω J_ω − ln b;
  - g = Σ_ω R′_ω g_ω / Σ_ω R′_ω, each g_ω from the cut on its own recording;
  - the field is the set of per-record fields, all driven by one b;
  - impacts and sensitivities are per record, and the competition kernel is their R′-weighted
    sum.
- **Convexity survives** (*derived*). Fitness is ln of a mean of exp of per-record fitnesses.
  If each is affine in its own record's field, that is log-sum-exp of affine maps, which is
  convex, so the non-invadable set stays convex.
- **Recordings are independent,** so a row's M resident runs and M invader runs go in parallel:
  up to 16 at the wall cost of one.
- **The row's sampling error, not discretisation, sets the resolution.**
  - One 41-year record carries an sd of about 2.0 in the invader's lma gradient, against
    ε = 0.20. Differences between strategies on shared records need about 7–20 of them
    (*estimated* on a toy).
  - So which species an assembly can resolve, and every sign at a margin, is judged against
    the row's standard error. Discretisation only needs to stay under a tenth of it
    (`workflows.md` §7).
- **d can grow on a row** (*derived*, untested). Environment and competition now covary across
  patches of the same age, so a spatial storage effect can arise. It needs non-additivity
  (Johnson & Hastings 2022), not buffering as such. Each distinguishable environmental state
  can then act as a regulating factor, so d(row) ≥ d(record). Measure it by repeating the
  field-dimension spike on a row.

**3. A history row: one site's calendar record, sliced at disturbance dates.** This serves the
site residual.
- The world it approximates has calendar-time climate (`theory.md` D.3.2): b(t) varies, and
  fitness is a Lyapunov exponent of a renewal process in disturbance date. The row
  approximates it with recordings at one held b.
- For trees, a generation is about as long as the record. ln R′ is then the fitness of one
  generation landing across the record's dates, not an invasion growth rate: a trending
  record has no limiting distribution.
- For short generations, the renewal growth rate and its log-variance are the quantities
  (`workflows.md` §2).
- **There is no equilibrium,** so the root-finding here does not apply. The observed
  community is read as the point its weather history has brought it to (Chesson 2017), and the
  residual reads evolutionary lag. The cut, the per-entry field error and the calibration term
  through the field all still apply, as derivatives on the held row.

**Per generation against per time.** ln R′ is per generation; the long-run rate is about
ρ ≈ ln R′/T_r.
- They share signs and zeros, so invasion decisions and evolutionarily stable conditions
  agree.
- Rankings among strategies with different generation times differ, and so do evolutionary
  paths. Every entry reports T_r from its offspring by date.

## References

Beyond `theory.md`'s list: Dybzinski, R. et al. (2011) *Am. Nat.* 177: 153–166; Farrior, C.E.
et al. (2013) *Am. Nat.* 181: 314–330; Meszéna, G. et al. (2006) *Theor. Popul. Biol.* 69:
68–87; Metz, J.A.J., Mylius, S.D. & Diekmann, O. (2008) *Evol. Ecol. Res.* 10: 629–654;
Sasaki, A. & Dieckmann, U. (2011) *J. Math. Biol.* 63: 601–635 (from memory, unchecked).
