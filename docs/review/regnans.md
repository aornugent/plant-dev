# Review: regnans (traitecoevo/regnans) against plant's TF24 adjoint, recorded-field invaders and equilibrium continuation

Reviewed: `/home/user/traitecoevo/regnans` at master `61746b0` ("Map coexistence boundaries in parameter space (#84)", 2026-10-13), plus the unmerged remote branches `origin/plant-integration` (PR #87) and `origin/canonical-implicit-jacobian` (PR #89), read with `git diff`/`git log` only. Issues and PRs were read through GitHub web pages (issues #22, #43, #60, #88; PR #87; the open/closed issue and PR lists; plant#650 and plant#677). Background: `/home/user/plant-dev/docs/design-workflows.md` and `/home/user/plant-dev/docs/measurements/regnans-roadtest/rootcause/README.md`.

Convention in this document: **Read** marks what the code, docs or tracker say. **Inferred** marks my own reasoning or arithmetic. Costs in "forwards" are TF24 forward runs at `b*` on long drought (about 77 s at 201 introductions), taken from rootcause README §2 and §4 unless stated otherwise.

---

## 0. Headline findings

1. **Read:** regnans is a general adaptive-dynamics toolkit for numerically solved models. Its stated design premise is exact derivatives from plant. ROADMAP §"Design principles" 2 says: "Algorithms here are chosen on the assumption that exact derivatives exist". On master, every derivative of plant is still a finite difference. `harness_plant()` advertises no derivatives (`provides` is empty).
2. **Read:** the plant bridge on master runs FF16 only, at patch lifetime 30, on the height coordinate. `harness_plant(model = "TF24")` is metadata. No environment, rainfall record or events reach `run_scm()`. PR #87 (open) moves the bridge to the birth-date coordinate and adds a frozen discretisation for stencils. It also adds an opt-in exact mutant gradient for FF16 only (`plant_mutant_gradient()`, via `plant::stand_gradient()` through `hyperpar`).
3. **Read:** PR #87 measured an FF16 sweep at about 26 mutant replays, and plant#677 measured it at 21–32× the run it differentiates. On that evidence it added to ROADMAP: "the table's AD columns are optimistic by an order of magnitude". Exact gradients are opt-in "until plant#677". **Inferred:** our TF24 sweep costs 2.05–2.9 forwards (rootcause §2.2, design-workflows R5). That is roughly a tenfold better ratio than FF16's. The case for gradients in regnans therefore rests on a number regnans has not seen. Measuring the TF24 ratio on regnans's own footing is the first thing to share.
4. **Read:** open issue #88 and PR #89 add `derivative_control(resident_jacobian = "implicit")`. This computes `dn*/dx = −S_n⁻¹ S_x` and `dg/dx = G_x + G_n dn*/dx` from a "fixed-environment" Jacobian of `(G, S)` in `(x, n)`, with no equilibrium solves. Its blocks come from one function, `fixed_environment_jacobian()`, which is "where a harness that can differentiate its demography ... would supply these blocks". **Inferred:** this is the same algebra as our continuation predictor, `d ln b*/dθ = −(∂F/∂θ)/(∂F/∂ ln b)` with `F = ln J − ln b`. One stand sweep supplies `S_x` (every trait) and `S_n`. Chords of invader sweeps supply `G_x` and `G_n`. It is the most direct entry point for our machinery.
5. **Read:** "joint eco-evolutionary Newton on `(n, x)`" is a planned roadmap row tied to #53. Its text: "solve `n = f(n, x)` and `g(x, n) = 0` together in one Newton on `(n, x)` instead of nesting an equilibrium solve inside every gradient evaluation". **Inferred:** this is the rootcause §7 loop: step along the curve `F = 0` and root-find `g = 0` in `(θ, ln b)`. That loop is estimated at about 18 forwards against about 84 for a singular strategy and its classification at k = 1. regnans has already named it as wanted but has not built it.
6. **Read:** ROADMAP Tier B lists "**High-dimensional trait evolution**: 10–48 TF24 traits co-evolving. Reverse mode gives all partials in about one run". Phase 3 lists "high-dimensional trait evolution". No issue tracks it, and no test evolves more than one plant trait. **Inferred:** our all-trait gradient is the enabling primitive, but regnans's high-k machinery is dense and would not scale to 50 traits as written. The mutant Hessian takes `1 + 4k²` mutants. The resident Jacobian takes `2mk` equilibrium solves. `nleqslv` uses a dense Jacobian. The trait bounds are a box with clamping.
7. **Read:** regnans has no treatment of environmental variability. No function averages fitness over climate records, and nothing names rainfall, climate or disturbance. ROADMAP marks "stochastic quasi-stationary states" out of scope. **Inferred:** a deterministic 40-year rainfall record still gives a fixed point in `b`, so everything works per record. Fitness across a bank of records would have to live in a harness.
8. **Read:** I found no statement about eco-evolutionary optimality (EEO) or trait-ecology hypotheses in the repo, the overstorey adaptive-dynamics page, or issues #22, #43 and #60. Purpose statements are methodological. Verbatim quotes are in §7.

---

## 1. What regnans computes, and the mathematics

### 1.1 Objects and pipeline (Read)

- `community` (`R/community.R`: `community_start`, `community_add`, `community_drop`, `community_reset`, `trait_matrix`). The object holds `bounds` (a k×2 box), a `traits` matrix with one row per resident, `birth_rate` (one per resident; for toy harnesses this is density), `demography_control`, `derivative_control`, `fitness_control`, `model_support` (for plant: `p`, `plant_control`, cached `node_schedule_times`, `node_schedule_ode_times`, `node_schedule_ode_step_sizes`), `harness`, and `trait_scale` (`"log"` or `"linear"`, one for all traits).
- `community_reset()` clears the fitness function, derivatives, selection gradient, solver state, and the node schedule and ODE times. It runs on every `community_add()` and `community_drop()`.
- Typical pipeline: `community_start() |> community_add() |> community_demography() |> community_selection_gradient()`.

### 1.2 Invasion fitness (Read)

- For plant (`plant_community_update_fitness_function()` in `R/community_plant.R`):
  - The function reruns the resident with `run_scm(p, ctrl)`, which replays the stored ODE times and step sizes, and sets `resident_fitness = log(scm$net_reproduction_ratios)`.
  - The fitness closure is `x ↦ log(R′)`, via `plant::add_mutant(p, traits, hyperpar, birth_rate = 0)` then `scm$run_mutant(p_mutants)`.
  - So fitness is **ln R′ of a rare mutant (birth rate 0) on the resident's recorded run**, through plant's hyperparameterisation (`plant_community_hyperpar()` → `plant::param_hyperpar(p)`).
  - With no resident, mutants run with zero birth rate and integrate freely. This is "fundamental fitness", used for viable bounds.
- For explicit harnesses (`R/harness.R`): `fitness(x_mut, x_res, n_res, pars)`, a per-capita rate for DD99 and a log ratio for the others, about 0 at the resident.
- **Inferred:** a resident is rerun to be recorded after every equilibrium. design-workflows' commitment ("the fitness function closes over that run and has no `run_scm` of its own") would remove that replay, which is 0.82 forwards per candidate.

### 1.3 Demographic equilibrium (Read; `R/community_demography.R`, `R/util_nlsolve.R`)

- The equilibrium is a fixed point `n = f(n)` of the harness's demography runner. For plant, `f` is `b ↦ offspring_production(b)` from `run_scm(p, ctrl, refine_schedule = TRUE)`, with ODE times cleared so each call integrates freely and refines the node schedule.
- Solvers, chosen by `demographic_step_control(equilibrium_solver_name = )`:
  - `"model"` (toy harnesses' own equilibrium);
  - `"single_step"`;
  - `"equilibrium_iteration"` (plant's default; fixed-point iteration to `equilibrium_eps = 1e-5`, `equilibrium_nsteps = 100`);
  - `"equilibrium_solve_newton"`: the package's Newton–Broyden. It takes one finite-difference Jacobian, applies Broyden rank-one updates and a backtracking line search, caps the step at e² in log density, and keeps the Jacobian in `community$demography_state` for the next nearby solve (#56, #65, #68);
  - `"equilibrium_solve_nleqslv"`, `"equilibrium_solve_dfsane"` (root-finding on `n − f(n)`, on `log n` by default);
  - `"equilibrium_hybrid"`.
- `util_nlsolve()` reports `converged` only when the residual is within `tol` (#74/#75).
- Start: `birth_rate_initial = 1e-3`, or the previous solve's birth rates as a warm start (`singularity_seed_birth_rate()`).
- The runner resets the node schedule to defaults when birth rates jump by more than `equilibrium_large_birth_rate_change = 10` (an absolute value).

### 1.4 Selection gradient (Read; `R/solve_attractors.R`, `R/derivatives.R`, `R/util_gradient.R`)

- `community_selection_gradient()` calls `community_fitness_gradient(community, y = residents)`. That dispatches to the harness's `fitness_derivatives$gradient`, or to `fd_fitness_gradient()`.
- The finite difference is a central difference at relative step `d_gradient = 1e-4` (absolute `eps_gradient = 1e-4` near zero), with `r_gradient = 1` Richardson level. That is `2k` mutants plus the centre, all in one fitness call (one `run_mutant`).
- Derivatives are with respect to **raw** traits. Consumers apply trait-scale chain rules: on a log scale the residual is `g·x`, the gradient in `log x`.

### 1.5 Mutant Hessian (Read)

- `community_fitness_hessian()` → `fd_fitness_hessian()` → `util_hessian()`.
- Second differences at `d_second = 1e-3` and its half, Richardson-extrapolated (`r_hessian = 2`). That is `1 + 4k²` mutants in one fitness call.
- Toy harnesses supply closed forms.

### 1.6 Convergence (resident) Jacobian (Read)

- `community_selection_gradient_jacobian()` → `resident_jacobian()` → `util_jacobian()`. This is a central difference of the stacked selection gradients over every resident trait, at `d_second = 1e-3`.
- Each stencil point is a full equilibrium solve, so the cost is `2mk` solves.
- Each point is solved to `min(equilibrium_eps, step³)` (`stencil_community()`, #80).
- Each point starts from the centre's densities and solver state, so the result is identical with or without a parallel plan.
- The same stencil gives `attr(J, "birth_rate_jacobian")`, which is `dn*/dx`.
- PR #89 (open) adds the implicit route: `implicit_resident_jacobian()` and `fixed_environment_jacobian()`. It costs `2m(k+1)` runs at given traits and densities and no solves.

### 1.7 Singular strategies (Read; `R/singularity.R`)

- `community_solve_singularity(community, x0, bounds, solver = c("nleqslv", "newton", "dfsane", "bracket"), tol = 1e-6, jacobian = )` roots the stacked selection gradients of `m` residents in `k` traits on the trait scale.
- The equilibrium is re-solved inside every residual evaluation (`singularity_gradient_fn()`), warm-started from the previous densities.
- `nleqslv` and `newton` take the Jacobian from the derivative layer. `"bracket"` is `uniroot` and applies only for m = k = 1.
- Candidates are clamped to the box. A root on an edge warns, or errors with `edge_ok = FALSE`.
- Merged residents (closer than the Jacobian step) are refused, and a coalition that merges or loses a resident is reported lost.

### 1.8 Classification (Read; `community_classify_singularity()`)

- **ESS:** each resident's mutant Hessian is negative definite (`ess_i`).
- **Convergence stability:** eigenvalues of `diag(speeds)·J` have negative real parts. Speeds default to the residents' equilibrium densities, matching the canonical equation; `"equal"` or a vector are allowed.
- **Strong convergence stability:** the symmetric part of `J` is negative definite (Leimar 2009, cited in the roxygen).
- **Protected coexistence** for coalitions (`coalition_invasion_fitness()` → `community_invasion_when_rare()`): each resident, made rare, invades the community the others settle at, with infeasible equilibria pruned. This costs `m` more solves.
- Verdicts: `CSS`, `branching point` (not ESS, CS), `Garden of Eden` (ESS, not CS), `repeller`, `degenerate` (an eigenvalue within `tol = 1e-8`), `unprotected`.
- `branching_direction` is the leading Hessian eigenvector of an invadable resident.
- Diagnostics: `newton_reach` (the step `J⁻¹g` relative to box width, warned above 1e-3) and a near-merged coalition warning.

### 1.9 Canonical equation, trajectories (Read; `R/canonical.R`)

- `community_canonical_equation()` integrates `dz_i/dt = ½ μ ñ_i V ∇_z s(z_i)` (Dieckmann & Law 1996) on the trait scale.
  - `V` is `canonical_control(vcv = )`, a full k×k mutational covariance, defaulting to `diag(mutation_sd²)` with `mutation_sd` 2% of the trait range.
  - `ñ_i` is relative density (`density = TRUE`).
- The equilibrium is re-solved at every right-hand-side evaluation (`canonical_rhs()`), warm-started from the last birth rates. Stepping uses odelia's `OdeSolver` (`"rodas"` default, `"rkck"`, `"dopri"`).
- RODAS's Jacobian comes from `canonical_jacobian()`, which is the resident Jacobian plus the densities' Jacobian carried through the speed (#80/#81).
- Branching: a stationary resident at a fitness minimum branches after a waiting time.
  - The rate is `λ = μ ñ ∫ M(δ) p_est(δ) 1[coexist(δ)] dδ`, with `p_est = min(1, 2s)`, integrated by Gauss–Hermite along the branching direction (`canonical_branch_rate()`).
  - Modes: expected, stochastic or immediate.
- Immigration arrives from a pool at a rate. Extinction, merging and polishing (`canonical_polish()` → `community_solve_singularity()`) are handled.
- `canonical_community(ce, time)` rebuilds the community at a recorded time.
- There is no separate "trait-substitution sequence" function. The stochastic assembler (`birth_type = "stochastic"`, `community_new_types_stochastic()`, `make_mutation_stochastic_naive()` with a `vcv`) plays that role.

### 1.10 Assembly (Read; `R/assembler.R`, `R/births*.R`, `R/deaths.R`)

- `assembler_start()`, `assembler_run()`, `assembler_control()`.
- Births:
  - `"maximum"` (FitMax): `find_max_fitness()` via `maximize_scaled()`. In one trait this is golden section bracketed by the sampled landscape; in N-D it is `dfoptim::nmkb` then derivative-free `optim(L-BFGS-B)`.
  - `"stochastic"`: mutants with `vcv` on the trait scale, and immigrants by Latin hypercube.
- Deaths: inviable residents are removed, via `plant_community_check_for_inviable_strategies()`, which reaches plant directly and is a known violation.
- `evolve = "none" | "newton" | "canonical"` (new in #84): residents evolve to their singular coalition between births.
- Refusals: `max_residents` and `edge_tol`.

### 1.11 Coexistence: mutual invasibility and boundaries (Read; `R/pip.R`, `R/boundary.R`, `R/boundary_branch.R`, #51, #60/#84)

- **PIP:** `community_pip()` solves residents on a grid with interpolated seeds and refines the resident axis. Zero contours are found by Newton (`newton_bracketed()`) on the model gradient. `pip_mutual()` and `plot(type = "mip")` give the mutual invasibility plot; `community_tep()` gives the trait-evolution plot.
- **Label (#84):** `community_label()` is the size of the evolutionarily stable community. It is reached by rounds of residents evolving to their singular coalition and one immigrant at the fitness maximum over the box, until nothing invades. Its status is `stable`, `capped`, `edge` or `unresolved`.
- **Scouting, bisection, sweeps:** `boundary_design()`, `boundary_scout()`, `boundary_bisect()`, and `boundary_sweep()` (hysteresis from alternative attractors).
- **`community_solve_boundary()`:** a square Newton solve on the nested augmented system, one parameter free.
  - Invasion type: `nk + k + 1` equations (residents' gradients, `∂s/∂y(y*) = 0`, `s(y*) = 0`).
  - Branching type: `nk + 1` (gradients and `det H` of one resident).
  - Its Jacobian is `community_boundary_jacobian()`. Resident columns come from the stencil, `y*` columns exactly from the mutant derivatives, and parameter columns from the parameter stencil.
- **`community_continue_boundary()`:** pseudo-arclength in two parameters, with tangent-turn rejection (dot product < 0.9) and test functions `density`, `resident_curvature`, `peak_curvature`, `separation`, `other_peak` and `bordered`. Events are located by Illinois false position. Points are verified cold afterwards.
- **`boundary_switch()`** starts the branch an event seeds, and `boundary_diagram()` collects branches.
- Oracles: GK98 symmetric three-patch in `(d, κ)`, where 1→2 is `d = √((2+κ)/2)` and 2→3 is transversal; and the DD99 pitchfork.

### 1.12 Parameter sensitivity and continuation of singular strategies (Read; `R/continuation.R`, #54)

- `community_parameter_sensitivity()` computes `dx*/dp = −J⁻¹ ∂g/∂p`.
  - `J` is the resident Jacobian.
  - `∂g/∂p` is `community_selection_gradient_parameter_jacobian()`: central differences through a caller-supplied `p -> community` map, two equilibrium solves per parameter.
- `community_continue_singularity()` is natural-parameter continuation. The sensitivity predicts, `community_solve_singularity(jacobian = )` corrects, and the classifier marks verdict changes.
- `community_parameter_map()` builds the map for explicit harnesses. For plant the caller writes it (the smoke test continues along `hmat`).

### 1.13 Multi-trait (k-dimensional) machinery (Read)

Everything listed above is dimension-agnostic by design. Principle 5 retired the `_1D`/`_2d` siblings (#58).

- `harness_dd99_nd()` (product Gaussians, Ito & Dieckmann 2007) is the k-trait oracle. Its Hessian is `diag(r(1/σ_C,d² − 1/σ_K,d²))`, and the classifier picks out the branching axis.
- The two-trait DD99 assembly gives about 27 species.
- Viable bounds in k dimensions take the smallest box containing the positive-fitness region. Each edge is where the profile `max over other traits` crosses zero (`viable_profile()`, `positive_1d()`).
- Limits: the fitness landscape grid and the plots are 1-D or 2-D, and the Bayesian-optimisation landscape is 1-D only.
- **Inferred:** the costs scale as `1 + 4k²` mutants for the Hessian, `2mk` equilibrium solves for `J`, and dense linear algebra. That is fine at k ≤ 3 and impractical at k ≈ 50 on plant.

### 1.14 Environmental variability and stochasticity (Read)

- **No** treatment of environmental variability. Nothing in `R/` names climate, rainfall, weather, records or disturbance. The plant `Parameters` come from `model_support$p`; whatever plant carries there reaches the runs, and nothing else does.
- Stochastic elements are evolutionary only: stochastic assembly, stochastic branching waiting times, and immigration draws. Seeds are handled by `preserve_seed()` and `with_seed()`, and a parallel plan never moves the caller's RNG (#59).
- ROADMAP "Scope": "resident attractors that are not fixed points (limit cycles, stochastic quasi-stationary states) ... are deferred".
- **Inferred:** TF24 on a fixed 40-year daily rainfall record over a patch's life is deterministic forcing within a patch, so `b ↦ J(b)` is still a map with a fixed point, and regnans applies per record. Combining records (eight seeds of one climate) is not a regnans concept. It would be a harness whose fitness is the mean `ln R′` across records (a fitness-averaging assumption to be stated), or one record per analysis. The rootcause §8 finding (constant rain: `ln R′` jumps by about 8 within ±0.01% of `lma`) would defeat regnans's root-finders. Principle 5 anticipates this kind of thing: "Any method that root-finds or continues on gradients carries refusal and outlier diagnostics".

---

## 2. The harness and the toy models

### 2.1 Connector design (Read; `R/harness.R`)

The pipeline reaches a model only through these connectors (ROADMAP principle 1, AGENTS "Model harnesses"):

| connector | role | plant implementation |
|---|---|---|
| `community_parameters()` | model parameters | `plant_community_parameters()`: `generate_strategy(p, traits, hyperpar, birth_rate)`, plus cached node and ODE schedule |
| `community_make_demography_runner()` | closure `b ↦ offspring` | `plant_community_make_demography_runner()`: clears ODE times, `run_scm(refine_schedule = TRUE)` every call |
| `community_demography_runner_cleanup()` | writes `b*`, schedule and progress back | `plant_community_demography_runner_cleanup()` |
| `community_viable_bounds()` | viable trait box (empty community) | `community_viable_fitness()` |
| `community_check_for_inviable_strategies()` | residents to drop | `plant_community_check_for_inviable_strategies()` (calls plant directly; on the housekeeping list) |
| `community_update_fitness_function()` | invasion-fitness closure | `plant_community_update_fitness_function()` (resident re-run and `run_mutant`) |
| `community_model_equilibrium()` (optional) | model's own equilibrium | toy harnesses only |

PR #87 adds two optional connectors: `community_discretisation()` and `community_freeze_discretisation()`.

**Derivative contract** (principle 2; `R/derivatives.R`):
- A harness declares `h$provides`. The vocabulary planned in ROADMAP is `fitness_gradient`, `fitness_jet2`, `fitness_parameter_gradient`, `demography_jacobian_n`, `demography_jacobian_x` and `demography_jacobian_p`. Only `fitness_gradient` and `fitness_hessian` are implemented as `fitness_derivative_names`.
- `harness_fd()` fills the rest by finite differences.
- `harness_check_derivatives()` is the CI contract against finite differences.

Connector derivatives are with respect to raw traits. Trait-scale chain rules live in regnans. "The environment never crosses the boundary."

`harness_plant(model, version)` on master forwards to the `plant_community_*` functions. `model` is metadata. PR #87 adds `fitness_gradient = c("fd", "model")`, which refuses TF24.

### 2.2 Toy models (Read)

| harness | model | what it validates |
|---|---|---|
| `harness_dd99()` | Dieckmann & Doebeli 1999 Lotka–Volterra with Gaussian K and competition kernel. `s(y) = r(1 − Σ N_i C(y−x_i)/K(y))`; `x* = x0`, branching iff `σ_C < σ_K`; Hessian `r(1/σ_C² − 1/σ_K²)`, Jacobian `−r/σ_K²` | Singular strategy and classification, closed-form PIP contours, the DD99 pair, triple and coalition sensitivity, the pitchfork boundary `σ_C = σ_K` (branching-type residual), the unit-circle branching locus (continuation closure), the canonical equation's branching into mirror daughters |
| `harness_dd99_nd()` | DD99 in k traits, product Gaussians (Ito & Dieckmann 2007) | Multi-trait solving and classification, branching direction selecting the narrow-kernel axis, 2-D assembly |
| `harness_gk98()` | Geritz, Kisdi, Meszéna & Metz 1998 Levene soft selection, symmetric three patches `μ = (−d, 0, d)`. `x* = 0`, branching iff `d/σ > √(3/2)` | Coalitions, the canonical equation's dimorphism matching the TEP, and the #60 oracle: nested 1\|2\|3 regions in `(d, κ)`, a closed-form 1→2 pitchfork and transversal 2→3 boundary, a subcritical turn at `(√3, 4)` |
| `harness_gm99()` | Geritz, van der Meijden & Metz 1999 seed-size safe-site lottery, a Poisson sum. No closed-form `x*`; branching at large `α·R` | Root-finding where only numerics exist, an asymmetric dimorphism, equilibrium invariant `W_m(m) = 1`, a slow-contracting equilibrium map (the case for Newton), second branching along `α` |
| `harness_jj12()` | Johansson & Jonzén 2012 bird arrival time (Brännström et al. 2013 §4). CSS `x* = x_opt − aσ²` | Exact benchmark for gradient and singularity solvers; sensitivity `dx*/dσ² = −a` |
| `helper-harness-map.R` (test-only) | Arbitrary map `n ↦ map(n)` with a tunably slow fixed point | Equilibrium root-finders |

- Every toy supplies a closed-form gradient and Hessian in C++ (`src/DD99.cpp`, `GK98.cpp`, `GM99.cpp`, `JJ12.cpp`).
- Their demography runner is the one-generation map `n ↦ n·exp(s(x; x, n))`, so every solver genuinely iterates (#55, principle 6).
- The test count is 1829 on master and 1848 on PR #87, against 401 at `56ad241`, which design-workflows cites.
- **Inferred:** none of the toys has a large number of traits linked by trade-offs, an environment record, or a gradient connector over non-evolving parameters. A toy for "all-parameter gradient" testing would need adding, for example DD99_nd with k = 10–50 and a hyperparameter map.

---

## 3. ROADMAP.md, NEWS.md and the commit trajectory

### 3.1 ROADMAP structure (Read)

**Scope:**
- A toolkit for models whose invasion fitness and equilibrium are computed numerically, plant first.
- Out of scope: the genetic basis of traits, and attractors that are not fixed points (#43).

**Design principles:**
1. Model-agnostic through the harness. One violation: `plant_community_check_for_inviable_strategies()`.
2. Derivatives are part of the contract, and algorithms are designed for exact derivatives: "Newton rather than fixed-point iteration, implicit rather than explicit steppers, contour continuation rather than grids, gradient-based rather than derivative-free optimisation". The decided interface shape is in §2.1. "Requesting derivatives also means 'freeze the discretisation'." The equilibrium sensitivity is `dn*/dθ = (I − f_n)⁻¹ f_θ`.
3. Every model-supplied derivative is checkable against finite differences in CI. plant will need `tol_rel` near 1e-2.
4. The plant boundary stays narrow: "If regnans ever needs to know what a light profile is, the boundary has leaked."
5. Derivatives of a discretised trajectory are not smooth near events. The `hmat` cell measured 211× the median, so "refusal and outlier diagnostics and periodic cold finite-difference verification".
6. Reference models have analytic answers but are exercised as numerical models.

**Code discipline:** eleven rules. They include bit-identical refactors, "every number has an oracle", fail loudly, one access point, controls rather than hidden state, visible cost (`evaluations`), and plan before code.

**"What exact derivatives change" (Tier A/B/C) and a cost table** in `R` units:
- `m ≈ 0.02–0.1 R` per mutant;
- `E_FD ≈ 10–50 R` per fixed-point equilibrium;
- `E_AD ≈ 4–8 R` per Newton equilibrium with exact `∂f/∂n` and a warm start.
- PR #87 adds a warning that the AD columns are "optimistic by an order of magnitude" on FF16.

### 3.2 Every inventory row: status and dependencies (Read)

| Section | Item | Functions | Status | Tier | Depends on / tracking |
|---|---|---|---|---|---|
| Model interface | Harness contract, six connectors | `harness_plant()`, `harness_explicit()` | done | — | #33 |
| | Reference models with analytic oracles | `harness_dd99/_nd/gk98/gm99/jj12()` | done (closed-form gradient and Hessian for all) | — | — |
| | Reference models run as numerical models | one-generation map runner; `"model"` solver | done | — | #55 |
| | Derivative connectors, `harness_fd()`, dispatch | `R/derivatives.R` | done for the mutant direction; resident Jacobian by stencil "until plant E3/E4"; demography Jacobians "arrive with the Newton solver" | A enabler | #50, #80; implicit route PR #89 / #88 |
| | Parameter Jacobian of the selection gradient | `community_selection_gradient_parameter_jacobian()` | done by finite differences; exact needs mixed second derivatives and E7 | B | #54, #80 |
| | Derivative verification contract | `harness_check_derivatives()` | done | — | #50 |
| | Warm-started resident solve | runner, `model_support` | **blocked** | B | plant#650 E5 |
| | (PR #87) Finite differences on one discretisation | `community_discretisation()`, `community_freeze_discretisation()`, `stencil_community()` | done on branch | A enabler | plant#653 |
| | (PR #87) Exact mutant gradient from plant | `harness_plant(fitness_gradient = "model")`, `plant_mutant_gradient()` | done on branch for FF16; off by default | A | plant#650 E2, plant#677 |
| Resident equilibrium | Iteration, nleqslv, dfsane, hybrid, single step | `community_demography()` | done | — | #74 |
| | Newton–Broyden with Jacobian carry-over | `equilibrium_solve_newton` | done. Measured: GM99 PIP 274 evaluations against 743 for iteration; Newton about 10 at one species and 47 at sixteen; "exact ∂f/∂n ... (plant E3) removes that overhead"; plant keeps iteration as default "until Newton is timed on the SCM" | B | #56 |
| | Equilibrium sensitivity `(I − f_n)⁻¹ f_θ` | `community_equilibrium_sensitivity()` | **planned; exact version blocked** (the function does not exist on master) | B | #50; plant#650 E3, E4, E7; odelia#39 |
| | Joint eco-evolutionary Newton on `(n, x)` | — | **planned** | B | #53 |
| Invasion analysis | Invasion fitness | `fitness_function`, `max_growth_rate()` | done | — | — |
| | Landscape, grid | `community_fitness_landscape()` | done | C | — |
| | Landscape, Bayesian optimisation | `fitness_landscape_control(method = "bayesopt")` | done in 1-D | C | — |
| | Gradient-enhanced surrogates | — | **planned** | B | #50 (downstream) |
| | Maximum of fitness | `max_fitness()`, `maximize_scaled()` | done | A | — |
| | Viable bounds, any dimension | `community_viable_fitness()` | done | C | — |
| | PIP and exact zero contours | `community_pip()` | done | C | #51 |
| | MIP, TEP | `pip_mutual()`, `community_tep()` | done | C | #51 |
| Selection and singular strategies | Selection gradient (finite difference) | `community_selection_gradient()` | done | A | — |
| | Singular strategy, any dimension | `community_solve_singularity()` | done | A | #49, #58 |
| | Classification | `community_classify_singularity()` | done | A | #49 |
| | Polymorphic singular coalitions | same two functions, m residents | done | B | #53 |
| | Parameter sensitivity and continuation of `x*` | `community_parameter_sensitivity()`, `community_continue_singularity()`, `community_parameter_map()` | done | B | #54 |
| Evolutionary dynamics and assembly | Maximum-fitness assembly | `assembler_run(birth_type = "maximum")` | done | A | — |
| | Stochastic assembly | `birth_type = "stochastic"`, `mutational_vcv_proportion()` | done | C | — |
| | Deaths and inviable removal | `community_deaths()` | done; plant-coupled check to retire | — | — |
| | Canonical equation with branching, waiting times and immigration | `community_canonical_equation()` | done | A then B | #52 |
| | Canonical equation, stiff and implicit, multi-trait | `canonical_control(stepper = "rodas")` | **partial**: Jacobian by finite differences across residents "until equilibrium sensitivities are exact" | B | #50, (#88); plant#650 E3, E4 (E6b) |
| | Tidy output, plots | `tidy_assembly()`, `plot_community()` | done | — | — |
| Parameter space | Coexistence boundaries by continuation | `R/boundary.R`, `R/boundary_branch.R` | done on finite differences on toys. Open: switching at a crossing branch (`bordered`) and past peak annihilation (`peak_curvature`), `other_peak` in more than one trait, curvature-relative label tolerances. "On plant, blocked on E1–E6" | B | #60 (open) |
| | Loci of branching points and ESS boundaries | `community_solve_boundary(type = "branching")` etc. | done on finite differences | B | #60 |
| Acceleration | Parallel map | `regnans_map()`, `regnans_chunks()` | done | C | #59 |
| | Caching via logpile | — | **planned, in plant** | C | plant#651 (E9) |
| | Emulators | landscapes | partial | C | `scripts/gps/` |

**"Decided" blocks:** #80 (cube-of-step tolerance; RODAS Jacobian from the layer), #54 (map design, sensitivities in raw units), #60 (label semantics, oracles, nested rather than joint system, Newton not nleqslv, continuation, tests, switching, verification, degenerate meetings, hysteresis), #59 (what crosses to a worker, RNG, which paths are routed), #88 (PR #89 branch).

### 3.3 "What regnans needs from plant", E1–E9 (Read, ROADMAP)

| | Endpoint | Consumers named | Priority |
|---|---|---|---|
| E1 | `R0_i` and `offspring_production_i` as differentiable metrics, FF16 and TF24 | everything | first |
| E2 | Mutant gradient `∂s(y)/∂y`, environment frozen, a *set* of mutants per recorded resident | selection gradient, FitMax births, N-D Newton, gradient-enhanced landscapes | first |
| E3 | Birth-rate axis `∂R0_i/∂b_j` (`f_n`) | Newton equilibrium, implicit sensitivity, joint Newton | first ("Largest multiplier") |
| E4 | Resident feedback `∂R0_i/∂x_j` (`f_x`) | implicit sensitivity, convergence Jacobian, coalitions, canonical Jacobian | Phase 3 |
| E5 | Warm-startable resident solve (birth rates, node schedule with ODE times and steps, environment) | Newton and continuation steps at about a tenth of a cold run | — |
| E6 | Mutant Hessian or directional 2-jet (`active<active<double>>`) | ESS test, branching in the canonical equation, `∂²r/∂y² → 0` test | Phase 3 |
| E7 | Non-strategy parameters (disturbance interval, patch lifetime) | `dx*/dp`, parameter continuation | lowest first-order |
| E6b | Mixed `∂(∂s/∂y)/∂x_j`, `∂(∂s/∂y)/∂b_j` | exact convergence Jacobian only | lowest |
| E8 | Discipline: refusal with reason, recorded control, R-callable finite-difference check, an `events` hook for the `hmat` crossing, frozen discretisation; notes plant#653 jumps of about 5e-5 in `log R0` | all | — |
| E9 | `enable_logpile(path)` | invisible cache | — |

**Sequencing:**
- **Phase 0 (finite differences):** items 1–9 done (#50, #51, #52/#56, #53, #54, #59, #60). Item 10 (housekeeping) is open.
- **Phase 1 (E1 and E2):** done on the PR #87 branch for FF16, with seven sub-steps. "TF24's fitness is not yet differentiable" in their reading.
- **Phase 2 (E3, then E7):** Newton by default; exact `community_equilibrium_sensitivity()`.
- **Phase 3 (E4, E6, E6b):** exact `dg/dx`, continuation stages 2–5 on plant, high-dimensional trait evolution.

**Housekeeping:**
- `plant_community_check_for_inviable_strategies()` reaches plant directly and hard-codes `eps_test`.
- `equilibrium_extinct_birth_rate` is absolute.
- Dead code in `R/util.R`: `maximize_logspace`, `closest_log`, `rescale`, `unrescale`, `norm2`.
- Copy-paste `@title` on `demographic_step_control()`.

### 3.4 NEWS.md (Read, development version)

- **Changes to results:**
  - Stencil solves to the cube of the step (#80).
  - RODAS Jacobian from `community_selection_gradient_jacobian()` (120–238 solves, not 427–2178).
  - A "merge" event.
  - `canonical_control()` defaults `rtol = 1e-2`, `atol = 1e-4`.
- **New features:**
  - `community_label()`, `boundary_scout()`, `boundary_design()`, `boundary_control()`, `boundary_bisect()`, `boundary_sweep()`, `community_solve_boundary()`, `community_continue_boundary()`, `boundary_switch()`, `boundary_diagram()`;
  - `assembler_control(evolve, max_residents, edge_tol, branch_offset)`;
  - `attr(J, "birth_rate_jacobian")`.
- **Dependency:** migrated to plant `develop@8657b3a` (plant#648: `use_ode_times` and `save_RK45_cache` removed; ODE schedule replay).
- PR #87 adds: the frozen discretisation (FF16 lma 0.15: −1619, 193, 107 become −1955, −2346, −2290 at steps 1e-2, 1e-3, 1e-4); the birth-date coordinate by default (equilibria move about 1%); `harness_plant(fitness_gradient = "model")`; plant `bd09645d`.
- PR #89 adds `derivative_control(resident_jacobian = "implicit")`.

### 3.5 Commit trajectory (Read, `git log -60`)

- **June 2026:** ported equilibrium and fitness out of plant (#20, #23), renamed `plant.assembly` to `regnans`, added toy harnesses (#33), testing (#27, #36).
- **July–August:** a few fixes (#41 logger, #44 exports, #46 default parameters, #47).
- **6–7 October:** a burst of 25 commits, all by Daniel Falster.
  - ROADMAP added (`1536e92`);
  - derivative layer (#61);
  - PIPs (#62, #64);
  - Newton–Broyden (#65, #68);
  - canonical equation (#66, #67, #69);
  - one entry point per method (#72);
  - coalitions (#73, #76);
  - `util_nlsolve` fix (#75);
  - sensitivity and continuation (#77);
  - parallel map (#78).
- **10–14 October:**
  - plant#648 migration (#83);
  - stencil tolerance and RODAS Jacobian (#81, #82);
  - coexistence boundaries (#84; #85 and #86 folded in);
  - branches for PR #87 (plant integration, 14 October);
  - PR #89 (implicit Jacobian, 16 October).

**Inferred:** the trajectory is a rapid build-out of the adaptive-dynamics method inventory on toy models with finite differences, now turning to plant integration. The authors are reacting to measured costs. They switched the exact gradient off and made the frozen discretisation the lever "that needed no AD".

---

## 4. Issues and PRs relevant to plant, gradients, multi-trait, climate, coexistence, EEO, performance

**Open:**

- **#60 [evol assembly] Map coexistence boundaries in parameter space by continuation** (epic, cross-package).
  - Scouting, then bisection, then pseudo-arclength on the augmented system (`2n + 2` equations in `2n + 3` unknowns in the handoff; nested in the implementation).
  - Stage gate: warm-start cost ratio of about 0.1 means proceed, about 0.5 means rays. Measured 0.19 in time and 0.67 in runs at a 1% `hmat` step.
  - The handoff's plant asks: invasion fitness "without a full forward simulation"; a forward 2-jet in the mutant direction; an equilibrium solve accepting an initial guess including the light profile; a recommendation to put the environment into the unknowns; "prefer forward sensitivity equations over AD through an adaptive stepper".
  - Budget: about 520 runs (about 200 cold-equivalents) for three nested curves in 2-D. Known risks: missed components, codim-2 points, search-box artefacts, hysteresis.
  - Stages 1–5 done on toys (#84). Plant is blocked on E1–E6. Climate and disturbance are not mentioned.
- **#88 [evol assembly] Resident Jacobian through the equilibrium by implicit differentiation** (task), with **PR #89** open.
  - Implicit route, fixed-environment blocks by finite differences, default `"stencil"` "until measured on plant", which needs #87's frozen discretisation.
  - Oracles: DD99 single, pair, triple and two-trait, GK98, GM99, JJ12. The prototype agreed with the stencil to about 1e-7 relative.
  - Cost: `2(mk + m)` fixed-environment runs. RODAS's Jacobian falls from about 4–9× the explicit pairs to 1.1–1.5×.
  - Follow-ups: flip the default on plant; the `dg/dp` analogue; analytic toy blocks.
- **PR #87 "Integrate plant's FF16 gradients (plant#650)"** (open, no reviews).
  - Birth-date coordinate; frozen discretisation for stencils; opt-in `plant_mutant_gradient()`.
  - Measured: FF16 sweep 0.70 s against a 0.027 s replay (about 26×) at lifetime 30; a two-column finite difference 0.12 s. Plant's gradient agrees with the finite difference to 7e-5–9e-4 away from the resident and 5e-3 at it.
  - Side finding: `hmat = 10`, lifetime 30 sits on a "maturation cliff" (log R from +2.2 to −11.7 across ±1% lma).
  - Not done: exact `(I − f_n)⁻¹ f_x` and exact `f_n`, because sweeps cost more than frozen differences "until plant#677".

**Closed (most relevant):**

- **#43 Stiff-aware nested solver for multi-trait adaptive dynamics** (epic, closed 6 October).
  - Three levels: RODAS on the canonical equation; Newton on the fixed point reusing the factorisation; explicit physiology inside.
  - Proposed a custom implicit-function-theorem derivative for the fixed point (no tape through Newton) and an `active<active<double>>` second order, forward-over-forward, because "trait dimension is usually small compared with demographic state".
  - Closed with RODAS and Newton–Broyden landed; exact work moved to plant#650, #50 and Phase 3.
  - **Inferred:** the "trait dimension is small" premise is the one our all-trait reverse sweep inverts.
- **#50** Derivative connectors, `harness_fd()`, dispatch layer (task, closed via #61).
- **#52** Canonical equation with branching (epic, closed).
- **#53** Polymorphic singular coalitions (closed; the joint `(n, x)` Newton remains a planned row).
- **#54** Parameter sensitivity and continuation (closed).
- **#56** [speed] Newton equilibrium with warm start and Broyden (closed).
- **#59** [speed] Parallel evaluation (closed): fork-only for solved plant communities; the grid landscape is not routed, since plant#656 (51 mutants in one call 0.73 s).
- **#80** Finite-difference Jacobian only as accurate as the solves (closed): cube-of-step rule.
- **#74** `util_nlsolve` false convergence (bug, closed).
- **#58** One entry point per method (closed).
- **#55** Reference models as numerical models (closed).
- **#51** PIPs (closed).
- **#33** Toy models (closed).
- **#32** Migrate to consolidated `run_scm` (closed).
- **#22** [evol assembly] Enable evolutionary dynamics and community assembly (epic, 2024; closed 6 October 2026). The acceptance criteria are quoted in §7.
- **#34** [speed] GM99 Poisson sum (closed).
- **#40** Speed up slow tests (closed).
- Older (#1–#15) are 2015–2023 housekeeping.

**Cross-repo issues referenced:**
- **plant#650** (E1–E9 epic, open; plant#657 and #658 added FF16 work);
- **plant#677** (sweep about 32× a run on FF16; PRs plant#679 and odelia#78 bring it to about 21×; open);
- **plant#653** (fitness jumps across residents from discretisation);
- **plant#651** (logpile);
- **plant#656** (fixed).

Not found on any page read: an issue on TF24 in regnans, an issue on climate or environmental drivers in regnans, or an issue on EEO.

---

## 5. Would our machinery change each item? (Inferred throughout, with numbers from the two background docs)

The four capabilities:
- **G:** exact all-trait gradients. The stand's sweep gives `∂ ln J/∂θ` for every θ and `∂ ln J/∂ ln b`. An invader's walk plus sweep gives `∂ ln R′/∂θ′` for every θ′, chained through the hyperparameterisation.
- **H:** Hessian rows by chords of sweeps.
- **W:** invaders read on a recorded resident field (`run_mutant`).
- **C:** the equilibrium followed by continuation, with predictor `Δ ln b = −(F + ∂F/∂θ·Δθ)/(∂F/∂ ln b)`.

Unit costs used:
- forward 1;
- stand sweep 2.3;
- invader walk 0.64 + sweep 2.05;
- two-invader difference 1.24;
- warm secant equilibrium 1–2 runs (cold about 4–6);
- regnans's iteration about 47 runs to 1e-5 from b = 1 (design-workflows R5).

**W is mostly not new to regnans.** It already reads mutants on the resident's recorded run through `scm$run_mutant`. What is new:
- (a) walking *the equilibrium's last run* rather than a replay made after it, which saves 0.82 forwards per equilibrium;
- (b) several invaders per walk sharing nothing in cost (rootcause §3.3). That changes nothing about regnans's batching but does mean "one call, 51 mutants" (#59) is not a saving on TF24 the way plant#656 made it on FF16.

| Item | Effect | Concrete reason |
|---|---|---|
| Harness contract | Needs extension (newly possible) | TF24 needs environment and events through `model_support` and given node times (design-workflows work item 1). An all-parameter gradient needs a connector (§6). |
| Reference models | Irrelevant | They would implement any new connector by closed form or finite differences. |
| Derivative dispatch | Faster from k ≥ 2, more accurate always | G replaces `fd_fitness_gradient()` for plant TF24. At k = 1 the difference is cheaper (1.24 against 2.7). The sweep removes the `d_gradient` knob and the plant#653 step jumps (0.23 every 2e-5 relative in lma on FF16) as error sources in the gradient. PR #87's `plant_mutant_gradient()` is the slot; it reads only the k evolving columns of a sweep that has all of them. |
| Parameter Jacobian `∂g/∂p` | Partly newly exact; faster | `∂g/∂p = ∂²s/∂y∂p|_inv + ∂²s/∂y∂p|_res-field + G_n·dn*/dp`. The first term for **every** p comes from H: a chord of the invader sweep in the evolving trait y, 2 walks and sweeps ≈ 5.4 forwards. `dn*/dp` for every p comes from one stand sweep (`−S_p/S_n`). `G_n` comes from one chord in b (2 resident runs at fixed b, each with a walk and sweep ≈ 7.4). The resident-field term needs a chord per p, or a second-order adjoint not built. Today each p costs 2 equilibrium solves (≈ 8–12 runs warm). Non-strategy p (climate, disturbance, E7) is not covered by our adjoint as far as I know. |
| Verification contract | Applies directly | `harness_check_derivatives()` at `tol_rel ~1e-2` is the same check our sweeps pass against differences. |
| Warm-started resident solve (E5) | Newly possible in the form that matters | For a forward-in-age SCM the only fixed point is b. "Environment as initial guess" (E5, #60 handoff) does not apply to plant's structure. A good b (C's predictor) plus given node times is the warm start. rootcause §7: predicted b* 5.56 against true 5.48 (0.015 off in ln b, \|F\| = 0.026), against 3 runs from the roadtest's guess. |
| Fixed-point iteration (default) | Much faster replaced | A secant in ln b: 6 cold, 4 warm, 1–2 with the predictor, against about 47–51 for iteration from 1e-3 (design-workflows table: 7.3× on the reference analysis). Not a gradient matter: no sweep is needed for m = 1, since the secant gives `∂F/∂ ln b` free (−0.7457 against the sweep's −0.7525). |
| Newton–Broyden | Faster with C | For m = 1, the Jacobian is the secant slope. For m > 1, `f_n` by sweeps costs n sweeps (one row each) against n frozen runs, so finite differences still win unless the sweep is under 1 run. C's predictor seeds it. |
| Equilibrium sensitivity `(I − f_n)⁻¹ f_θ` (planned) | **Newly exact for every θ in one stand sweep** (m = 1) | `d ln b*/d ln θ = −e/f′`: elasticity over slope (design-workflows item 5; rootcause §7). For m species, m stand sweeps give `f_x` and `f_n` rows. This fills `community_equilibrium_sensitivity()` and `attr(J, "birth_rate_jacobian")` without any stencil. |
| Joint eco-evolutionary Newton on (n, x) (planned, #53) | **Newly practical; the largest saving** | This is rootcause §7's loop: one resident run per iterate, `F` and `∂F/∂θ`, `∂F/∂ ln b` from the stand sweep, `g` from two invaders (k = 1) or an invader sweep (all k). Estimated about 18 forwards for a singular strategy and its classification at k = 1, against about 84 for the finite-difference floor and 608 for regnans as it stands (design-workflows table). It needs `g` only to \|F\| < 0.02 (`dg/d ln b = −6.0`, E5), not regnans's 1e-5. |
| Invasion fitness | Small saving (W) | The fitness function stops re-running the resident: 0.82 forwards per candidate, 13 runs (about 15%) of the reference analysis. |
| Landscape grid | Irrelevant to gradients; slower than FF16 intuition | A 9-invader landscape is 9 walks (818 s). Fork-parallel across cores helps (design-workflows C: 54 mutants in about 10.4 forwards on 4 cores). |
| Bayesian-optimisation landscape | Irrelevant | 1-D, derivative-free. |
| Gradient-enhanced surrogates (planned) | **Newly possible** | Each invader walk and sweep gives 1 value and about 50 slopes. With H, also Hessian rows. |
| Maximum fitness (FitMax births) | Faster from k ≥ 2 | `maximize_scaled()` calls derivative-free L-BFGS-B (finite differences inside `optim`). Passing G makes each iterate one walk and sweep. In 1-D golden section stays. Needs the PLANT-95 walked-patch fix for several invaders per sweep. |
| Viable bounds | Modest | Newton on `s(y) = 0` with an exact slope. In k-D each profile point is a (k−1)-D maximisation, where G matters. With 50 traits a box from profiles is not feasible either way (§6). |
| PIP contours, MIP, TEP | Modest (C seeds residents) | Contours already use the model gradient; with G that is exact. `pip_interpolate_seeds()` could be replaced by first-order seeds `b + (db*/dx)Δx`. Each resident still needs its equilibrium. |
| Selection gradient | k = 1: slower (2.7 against 1.24) but exact and all-trait; k ≥ 2: faster | rootcause §4: "sweeps pay from two evolving traits". At 50 traits: 2.7 against about 100 mutant walks. |
| Singular strategy, any k | k = 1: about 5× fewer forwards via C; k ≥ 2: needs G; k ≈ 50: needs new solvers | Today each residual is a full equilibrium (cold or warm iteration) plus a gradient. The Newton Jacobian is `2mk` equilibrium solves. With C and #88: no nested equilibria, Jacobian columns as fixed-environment chords. For k ≈ 50 a dense Jacobian is 100 chords (≈ 100 × 3.7 forwards), so Broyden or Newton–Krylov with chord products is needed. |
| Classification | Cheaper and more robust | ESS: at k = 1, two invaders at `θ e^{±0.05}` (rootcause), since `ln R′(θ) = F` is known. With H at k = 1 a row costs about 6 against 3.9 for 5 mutants, at k = 2, 11.9 against 13.1. Convergence: the sign of dg/dθ along the curve comes from the secant iterates (free), or #88's implicit route with `G_x`, `G_n` by chords and `S_x`, `S_n` from one stand sweep, no equilibrium solves. Removes the classifier's second solve of the singular resident. H also avoids TF24's step sensitivity (curvature stable from r ≈ 1e-2; at 1e-3 the split resident's second difference moves 0.47ε). |
| Coalitions | Faster per resident gradient; protected coexistence unchanged | Each resident's gradient needs its own invader; a walk carries several invaders at linear cost. The `mk × mk` Jacobian by implicit route needs m stand sweeps and `2mk` fixed-environment chords. The leave-one-out solves stay; C seeds them. |
| Parameter sensitivity and continuation of x* | Faster; partly exact for all p | See the `∂g/∂p` row. Each continuation corrector equilibrium is warm-started by C in both θ and p (for p a strategy parameter, `d ln b*/dp` is in the stand sweep). |
| FitMax assembly | Modest (as FitMax births) | — |
| Stochastic assembly | Irrelevant | Derivative-free, embarrassingly parallel by design (Tier C). |
| Deaths | Irrelevant | — |
| Canonical equation | Faster per right-hand side (C); **multi-trait newly possible** (G) | The right-hand side is an equilibrium plus a gradient. C makes the equilibrium 1–2 runs (predicted b) rather than an iteration warm-started from the old b. G gives the 50-trait gradient so `V∇s` can be formed for a 50×50 `V`. RODAS's Jacobian at k = 50 is the expensive part; explicit steppers or a low-rank or Broyden Jacobian are the practical route. rootcause estimate: about 6 forwards per step for every trait, or 3.6 with a second reverse pass. |
| Canonical, stiff and implicit, multi-trait (partial) | #88 plus chords make it solve-free | Blocks: `S_x`, `S_n` from stand sweeps; `G_x`, `G_n` by chords of invader sweeps; this is E6b by differences of exact gradients. |
| Coexistence boundaries (#60) | Faster corrector; still dominated by labels | Resident columns come from the implicit route. `y*` columns are already exact from mutant derivatives (H gives the `∂²s/∂y²` entries). The parameter column for strategy parameters comes from the stand sweep plus chords; for climate parameters it stays a finite difference. The label (assembly with evolve per point) is the dominant cost and gains only through faster singular-coalition solves and C seeds. `fitness_tol` must sit above plant's fitness noise (about 1e-4 noted). |
| Loci of branching points | Faster, needs third-order | The residual uses `det H`, so its Jacobian needs derivatives of H. H by chords, then differences of chords. Exact third order is not available. |
| Parallel map | Applies unchanged | Forked workers sharing a recorded run (0.45 GB a record per fork). Sweep tapes add memory not measured here. regnans already refuses external pointers under multisession. |
| Caching (logpile) | Irrelevant | Orthogonal. |
| Emulators | Newly possible as gradient-enhanced | As the surrogate row. |
| plant E1–E8 (for TF24) | Mostly met by our machinery | E1 (`J`, `R′` differentiable on TF24): yes. E2 (invader gradient, frozen field): walk plus sweep. E3 (m = 1): birth-rate column, or the secant. E4: stand sweep with field responding, every trait. E5: as above. E6: chords. E6b: chords over moved residents and b. E7: unknown for non-strategy parameters. E8: birth-date coordinate with splits and given node times is the frozen discretisation; the "events hook" corresponds to our splits at sign changes. |
| Housekeeping | Irrelevant | — |

**Open issues:**
- **#60:** as in the table. Our machinery helps stages 3–5's Jacobians on plant. It does not touch the label's assembly cost or the climate-parameter columns.
- **#88:** the most direct fit. Our stand sweep is `[S_x | S_n]` for every trait in one pass. Chords of invader sweeps are `[G_x | G_n]` with every trait as rows. This replaces `fixed_environment_jacobian()`'s `2(mk + m)` finite-difference runs. At k = 1 the difference is cheap anyway (4 runs, plus each run's gradient); at k ≥ 2 the sweep columns pay. The "default stays stencil until measured on plant" condition is something we can measure for them on TF24.

---

## 6. Gaps: what regnans would need to exploit all-trait gradients (Inferred, with code references)

1. **A plant bridge that runs TF24 on this plant** (design-workflows item 1):
   - environment and events through `model_support` into `run_scm` and `run_mutant`;
   - node times given, never refined (`plant_community_make_demography_runner()` sets `refine_schedule = TRUE` on every call);
   - records kept on every equilibrium run, with the fitness function walking the last (remove the `run_scm(p, ctrl)` in `plant_community_update_fitness_function()`);
   - `community_reset()` should not wipe a given schedule (PR #87's `frozen` survives reset, a partial fix);
   - `harness_plant(model = "TF24", fitness_gradient = "model")` must stop refusing TF24 (PR #87 line `if (fitness_gradient == "model" && model != "FF16") stop(...)`).
2. **A gradient connector over all parameters, not only the evolving traits.**
   - `fitness_derivative_names` has `fitness_gradient` and `fitness_hessian` with k columns. ROADMAP lists `fitness_parameter_gradient` and `demography_jacobian_x/_p` as planned names.
   - Needed:
     - (a) invader `∂ ln R′/∂θ′` for every parameter, from one walk and sweep;
     - (b) stand `∂ ln J/∂θ` for every parameter and `∂ ln J/∂ ln b`, from one stand sweep, which fills `fixed_environment_jacobian()`'s `S` blocks and `community_equilibrium_sensitivity()`;
     - (c) toy implementations by differences (design-workflows: "a gradient connector, which the toy harnesses implement by differences").
   - The column naming is plant's `"<species>.<parameter>"`. regnans would need to map columns to its `trait_names` and keep the rest for the report.
3. **An "answer's report"** (design-workflows items 5 and 6). At a final singular strategy:
   - every parameter's elasticity, `d ln b*/d ln θ` for every θ, and the invader's all-parameter selection gradient (about 7 forwards once);
   - an error estimate from a companion run at looser tolerance;
   - for each answer, its distance from the grid's θ₀ against the radius (OBJECTIVES "Diagnosed").
   - regnans's outputs (`singularity_classification`, `tidy_assembly()`, `regnans_branch`) have no fields for these. Cost is counted only as equilibrium `evaluations`, plus `environments` in PR #89, not as walks or sweeps.
4. **The joint (θ, ln b) solver** (the planned #53 row): residual `(F, g)`, with the Jacobian `[[∂F/∂θ, ∂F/∂ ln b], [∂g/∂θ, ∂g/∂ ln b]]` assembled from one stand sweep, `g` from the invader, and chords or secant updates. The tolerance on \|F\| should follow from `dg/d ln b` (rootcause: \|F\| < 0.02 for ε/3), not from `equilibrium_eps = 1e-5` and the cube-of-step rule.
5. **Mutational covariance M and the G-matrix.**
   - `canonical_control(vcv)` takes a full k×k `V` on the trait scale and defaults to diagonal.
   - The stochastic assembler needs `vcv` (`mutational_vcv_proportion()` is diagonal, proportional to range).
   - The classifier ignores M except through speeds (eigenvalues of `diag(speeds) J`) and strong convergence stability (any M).
   - Missing: a way to state M over 50 traits; the mapping between plant's hyperparameterised traits and the parameter space a sweep differentiates (the gradient must be the total derivative through `hyperpar`, as PR #87 notes: "without it lma's column is a partial, 5× off"); and a projection of all-parameter gradients onto the evolving subspace or the trade-off manifold.
   - With 50 traits, M decides which directions evolve. That is a modelling input regnans has no default for.
6. **High-dimensional singular-point and classification solvers.**
   - `nleqslv` and `newton` with a dense `mk × mk` Jacobian from `2mk` solves, or `2m(k+1)` fixed-environment runs, do not scale to k ≈ 50 on plant.
   - Needed: Broyden or limited-memory quasi-Newton with chord-product refreshes; Newton–Krylov with `J·v` from one chord pair; Lanczos for the leading Hessian eigenvalue (the branching direction) from `H·v` chords rather than `util_hessian()`'s `1 + 4k²` mutants and a full `eigen()`.
   - Plus a symmetrisation rule for chord Hessians, and a step choice for chords (r ≈ 1e-2, design-workflows "Curvatures as chords").
7. **Trait bounds in many dimensions.**
   - Bounds are a box. Candidates are clamped (`pmin`/`pmax`). An edge is a warning or an error. Viable bounds are a box from profile maximisations.
   - With 50 traits many will sit at bounds or at physiological limits (corner solutions). Needed:
     - an active-set or KKT treatment (a projected gradient; singularity conditions only on free traits; a report of which traits are bound);
     - per-trait scales (`trait_scale` is one value for all traits);
     - bounds that come from plant's own domain refusals rather than a box.
8. **Refusals and discontinuities.**
   - rootcause §8 (constant rain, a jump in `ln R′` at the resident) and the FF16 maturation cliff (PR #87) show landscapes where no gradient exists.
   - regnans's solvers need plant's refusal objects carried into `util_nlsolve` as domain errors, and a report of where a gradient was refused. The canonical equation already uses `odelia::domain_error()`.
9. **Environmental variability.** There is no concept of a bank of records. Fitness over records (mean `ln R′`, or per-record answers with ε from their spread) would live in a harness. Nothing in regnans averages, weights or reports across records.
10. **Cost model.** ROADMAP's cost table (`m ≈ 0.02–0.1 R`, `E_AD ≈ 4–8 R`) and PR #87's FF16 sweep ratio both differ from TF24's measured units. On TF24, an invader walk is 0.64–0.77 forwards, not 0.02–0.1. The table would need re-deriving per model before regnans picks defaults.

---

## 7. How regnans frames its purpose (Read; verbatim)

- **README**, opening:
  > "The [{regnans}](https://github.com/traitecoevo/regnans) package extends {plant} to model community assembly and trait evolution, by repeatedly invading trait space, solving each community to demographic equilibrium, and following selection gradients to evolutionary attractors."
- **README**, "Where it is going":
  > "The aim is a reasonably comprehensive toolkit of adaptive-dynamics methods for *numerically solved* models, designed around the exact derivatives that `plant` is gaining through automatic differentiation."
  - Next up: "the canonical equation's Jacobian from equilibrium sensitivities once `plant` exposes the Jacobians, so RODAS stops paying one equilibrium solve per unknown"; "Newton equilibrium solves on exact `∂f/∂n`, and exact parameter sensitivities of attractors"; "coexistence boundaries and loci of branching points through parameter space."
- **DESCRIPTION**:
  > "Assembles ecological communities of competing strategies using the plant model, by iterating demography to equilibrium, computing selection gradients and invasion fitness, and solving for evolutionary attractors."
- **ROADMAP**, Scope:
  > "`regnans` is a toolkit of adaptive-dynamics methods for models whose invasion fitness and demographic equilibrium are **computed numerically** — the `plant` size-structured forest model first, but any model that can be wired to the harness interface. The ambition is a reasonably comprehensive set of the standard adaptive-dynamics analyses (invasion fitness, equilibria, selection gradients, singular strategies and their classification, evolutionary dynamics, community assembly, bifurcation structure in parameter space), built so that they work on expensive numerical models rather than only on closed-form toy models."
- **ROADMAP**, Tier B:
  > "**High-dimensional trait evolution**: 10–48 TF24 traits co-evolving. Reverse mode gives all partials in about one run; finite differences cost `k` runs per gradient and derivative-free search is hopeless."
  > "**Parameter sensitivity of evolutionary outcomes**, `dx*/dp` for every model parameter in one adjoint sweep."
  > "**Active-subspace reduction** of the fitness landscape from gradient covariances, and **gradient-enhanced emulators**"
- **ROADMAP**, Evolutionary dynamics (on assembly algorithms):
  > "Biologically, the algorithms represent different processes — mutation of residents at some rate, immigration from a regional pool, the relative speed of demography and evolution — and so different models of how a community comes to be."
  - It also cites FitMax ("in earlier work with Rich FitzJohn") against "the stochastic assembly of Falster, Brännström, Westoby & Dieckmann (2017, PNAS)".
- **Issue #22** (2024 epic): aim "so that we can investigate questions of community assembly and trait evolution", with acceptance criteria beginning "Given a trait-based tradeoff, we can" (mutant fitness, equilibrium, landscape, 1-D/nD attractors, "assemble communities under different assumptions of community assembly").
- **overstorey Theory → Adaptive dynamics**: "can it increase in the environment created by the strategies already present?"; "We focus on phenotype-dependent fitness."; "We do not model the genetic basis of trait inheritance or expression." It cites Falster, Brännström, Westoby & Dieckmann (2015, bioRxiv) for the fitness calculation.

**Not found:** eco-evolutionary optimality, named trait-ecology hypotheses, target papers beyond the 2017 PNAS assembly comparison, or any climate or rainfall question. **Inferred:** the stated purpose is methodological (a complete adaptive-dynamics toolkit for expensive models). The scientific targets implied are community assembly and trait evolution under trade-offs, coexistence structure in parameter space, and FitMax versus stochastic assembly. Tier B's "10–48 TF24 traits co-evolving" is the closest statement to our all-trait work, and it is an aspiration with no issue behind it.

---

## 8. Corrections to our background docs implied by regnans HEAD (Read, then Inferred)

`design-workflows.md` "What regnans does today" describes `56ad241`. At `61746b0`:

- **Fixed (#83):** `use_ode_times` and `save_RK45_cache`.
- **Still true:** the runner refines on every call, except for PR #87 stencils; no environment or events; `community_reset()` clears the schedule.
- **Superseded:** "Every derivative is a difference" still holds on master. A dispatch layer (#61), an opt-in plant gradient (PR #87, FF16) and an implicit resident Jacobian (PR #89) now exist.
- **Superseded:** "401 tests" is now 1829, or 1848 on PR #87.
- **Superseded:** "Singular strategies are roots ... `uniroot` in one trait, `nleqslv` or `dfsane` in k" now also includes the package's `newton`, coalitions of m residents, and a starting `jacobian =`.
- **Superseded:** the equilibrium default is still iteration, with Newton–Broyden available and carried between solves.

`design-workflows.md`'s R7 question ("is a plant analysis evolving two or more traits planned?") is answered in ROADMAP only as the Tier B aspiration and Phase 3. No tracked work exists.
