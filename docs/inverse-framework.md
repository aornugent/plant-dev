# Cohort inverse framework: fitting stand structure to rainfall-driven recruitment

**Scope.** A statistical framework for estimating a shared plant strategy and a
site-level recruitment history from point samples of forest structure across many
sites, using regional rainfall as the driver and sparse dendrochronology as an
anchor.

**Status.** Design. No implementation exists. §12 is the build order.

**Prerequisite.** §11.1 (storage restoring-rate clamp) gates §7 and §8. Do it first.

---

## 1. Problem statement

An arrival measure `ν(a)` over launch times `a`. Each launch is propagated by a
kernel `h(t;a)` that depends on unknown physiology `θ` and on a shared environment
history `E`. Each is attenuated by an unknown decay `exp(−∫μ)`. The result is
observed through a compressive linear functional at one or few times. Recover the
arrivals, the propagator, and the decay.

This is blind deconvolution with a parametric kernel. Identifiability requires at
least one of four constraints: known kernel, known launch times, sparsity, or
multiple channels sharing one factor. This design buys three (§5).

### 1.1 Coordinates

The framework is posed in **birth-date coordinates**, not height coordinates. The
distinction is structural, not stylistic:

| coordinate | abundance equation | consequence |
|---|---|---|
| height | `d(log n)/dt = −μ − ∂g/∂h` | growth and mortality enter one scalar state additively; indistinguishable by construction |
| birth date | `d(log ν)/dt = −μ` | growth appears nowhere in the abundance equation; it sets only cohort *position* |

The factorisation is therefore:

- **survival → cohort amplitude** (`log ν = log recruitment − accumulated mortality`, additive)
- **growth → cohort position** on the size axis

This is a reparameterisation, not new information. The likelihood still couples both,
because the observable is one integral of the pushforward. What it removes is growth
parameters from the abundance channel — fewer parameters in multiple channels, less
structural collinearity in the Fisher information.

Recruitment is also *event-indexed* in the data ("the wet year of 1998 produced a
pulse"). In birth-date coordinates that is a statement about the model's own abscissa.
In height coordinates it is not expressible without first inverting a growth
trajectory.

### 1.2 Jacobian accounting

If size *densities* are fitted rather than stem-level data, `J = ∂h/∂a` reappears in
the observation model. It has not vanished; it has moved from an integrated ODE state
to a quantity evaluated once at report time. At report time every solved trajectory is
held, so `J` is obtained by differencing neighbouring cohorts' actual heights — the
total derivative, correct by construction, no perturbation. State this before someone
objects that the problem has only been moved.

---

## 2. The three confounds

"Growth vs survival" bundles three distinct confounds. They have different fixes.

| # | confound | breaks on |
|---|---|---|
| 1 | growth × birth date — old-and-slow vs young-and-fast at the same size | known launch times |
| 2 | recruitment amplitude × survival — many born/few survived vs few born/many survived | same cohort observed ≥2 times, or external mortality data |
| 3 | growth × survival proper — slow growers linger in the high-mortality small-size band | size-resolved mortality |

Confound 1 is the one that wrecks single-census fits; rainfall-pinned recruitment
attacks it directly. Confound 2 is the hard one and rainfall pinning does nothing for
it. Confound 3 is the biologically real one that survives the coordinate change.

Confound 1 is a coordinate artefact and dies with §1.1. The framework only has to
fight 2 and 3, and repeat-census increments plus known recruitment dates are the right
instruments.

---

## 3. The crux

Given physiology `θ` **and** the environment history `E`, the prediction is exactly
linear in the recruitment amplitudes:

```
y_j = Σ_i  ν_i · e_j(a_i ; θ, E)
```

The kernel `e_j` folds in each cohort's trajectory `h(t;a_i)` and its survivorship
`exp(−∫μ)`; both are fixed once `θ` and `E` are fixed. All nonlinearity lives in
`E(ν)` — the light field depends on the cohorts being placed.

Consequences:

- **Conditional on `E`, the inverse problem is convex and separable.** Freeze `E` and
  the amplitudes decouple into independent non-negative least-squares solves.
- **Separable nonlinear least squares.** Variable projection (Golub–Pereyra) profiles
  `ν` out analytically, leaving a low-dimensional nonconvex problem in `θ` with an
  exact gradient. Height coordinates do not have this property: recruitment enters
  through `log(b·pr_estab/g)`, with growth in the denominator, so it is not
  linear-separable. **Separability is bought by the coordinate change.**
- **The coupling is strictly lower-triangular in time.** `E(t)` depends only on
  cohorts already born and rainfall already fallen. Forward assembly is a single
  forward sweep in birth date; the adjoint is a single backward sweep (§8).

Nonnegativity kills the closed-form pseudoinverse. Use a projected inner solve and
obtain the outer gradient by the envelope theorem on the active set.

---

## 4. Architecture: two layers

| layer | contents | cardinality | how identified |
|---|---|---|---|
| **global** | shared strategy `θ` on trait axes, its dependence on landscape covariates, the rainfall→establishment response | low (~30) | cross-site diversity + dendro anchors |
| **local** | per-site recruitment amplitudes `ν`, one per candidate cohort | high (~10⁴) | VARPRO-eliminated; never sampled |

This is the local/global split of detector alignment (Millepede). The normal equations
are block-diagonal in the local parameters with a thin coupling to the globals, so
every local block is eliminated analytically, leaving a small reduced system.

**Sparse dendrochronology feeds the global layer.** It cannot constrain every site and
does not have to. It constrains two shared functions, which then propagate to every
site:

1. **Ring-width increment series → the growth kernel directly.** A dated core is a
   sampled `h(t;a)`. That is a direct observation of the propagator — the
   "known kernel" constraint blind deconvolution cannot manufacture.
2. **Which events actually recruited → the establishment response.** Dated cohorts
   say which rainfall events produced recruitment at anchor sites, identifying the
   rainfall→`pr_estab` map.

---

## 5. Identification: three channels, three lag kernels

Rainfall is **not** a valid instrument in the exclusion-restriction sense. With a
carried store it enters recruitment, growth, and drought mortality. Do not write it as
one. Write the kernels.

Identification comes from three observation channels carrying different memory of the
same driver:

| channel | lag kernel | role |
|---|---|---|
| census structure | low-pass — growth through the store smooths the record | the compressive observable |
| ring increments | high-resolution, directly dated | the *clean* tracer: known kernel |
| rainfall→recruitment timing | prompt pulse | pins launch times |

Jointly they identify what none identifies alone. This is the multi-tracer argument
from catchment hydrology: one tracer cannot separate a broad-slow transit kernel from
narrow-fast-plus-mixing; several with different decay constants can.

A little of a clean tracer is worth a lot. Sparse dendro pins the shared functions that
the noisy channels then propagate.

### 5.1 Memory ceiling

The stand state is an environmentally-determined trajectory (AEDT). Two properties are
load-bearing:

- **Backward convergence legitimates burn-in.** The initial condition is forgotten at
  a rate set by density dependence. In birth-date coordinates the memory is readable
  directly: cohorts old enough that `exp(−∫μ)` is negligible contribute nothing to
  either integral. Required burn-in is *computed* from the mortality kernel, not tuned.
- **The decay weights are a ceiling on identifiability.** Strong density dependence =
  fast forgetting = only recent rainfall is recoverable from present structure. Run
  this calculation before promising to estimate a response to a 1970s drought.

### 5.2 Resolution bound

Recruitment is rainfall-pulsed, so the arrival measure is sparse, and recovering a
sparse spike train through a convolution is super-resolution. Stable recovery requires
a minimum separation between spikes relative to kernel width.

Operationally: two rainfall events are separately identifiable only if the size gap
their cohorts have opened exceeds the smearing set by growth rate and within-cohort
variance. Fast growth separates pulses in size; slow growth smears them. This is a
computable, pre-registrable statement of the form *"at this site, rainfall events
closer than N years are not separately recoverable"* — and a precise version of "the
suppressed sapling bank is unidentifiable".

---

## 6. Data model

```
Landscape:                      # 100-500 km scale
    id
    regional_rainfall(t)        # the shared driver
    covariate_fields            # a-priori resolved (topo, hydrology, soil)

RegionalEvent:                  # "the 1998 cohort" - hierarchical latent
    landscape_id
    year
    rainfall_anomaly
    mu_estab                    # latent regional establishment propensity
                                #   -> prior mean for each site's nu

Site:
    landscape_id
    location
    local_modulation            # a-priori: how this site filters regional rainfall
    census[]                    # observed structure at t_obs (>=1; repeat = gold)
    cohorts[]                   # SiteCohort, one per candidate event

SiteCohort:                     # local layer
    site_id
    event_id                    # candidate birth date = event.year (pinned)
    nu                          # amplitude; VARPRO-eliminated, NOT sampled
    dated: bool                 # partial dendro is a per-cohort flag
    ring_series: Optional       # sampled h(t;a) if a core landed here

Strategy(Theta):                # global layer
    trait_axes                  # 2-4 dims (lma, b_0, ...)
    gradient_coeffs             # theta_site = f(covariate_fields; Theta)
    establishment_response      # rainfall_anomaly -> pr_estab
    hyper_variances             # pooling scales for nu across sites
```

Load-bearing fields: `dated`, `ring_series`, `mu_estab`. `dated` makes birth date
optional and lets the likelihood *dispatch* on presence rather than forcing every site
through one code path. `mu_estab` makes "the 1998 cohort" a first-class node that
dendro attaches to at one site and constrains at all.

Adjacent sites (1–5 km, shared topography) and distant sites (100–500 km, different
catchments) enter through the same structure: the distant-catchment decorrelation
identifies the shared response function, the adjacent clusters pin the local variance.

---

## 7. Cohort-response library

The reusable object is an **impulse-response library**: place a unit recruitment pulse
in year `a`, propagate it, record its contribution to every observable. The stand is a
superposition of these responses weighted by `ν`. Valid because the system is linear
conditional on `E` (§3).

```
CohortLibrary:
    query(theta, birth_year, exposure_summary) -> (kernel e[j], trajectory h(t))
```

**Index by exposure summary, not by raw environment.** Use a few integrals —
cumulative shading experienced, cumulative water stress from the a-priori hydrology. If
a cohort's fate is well captured by two or three exposure integrals, two sites where
the 1998 cohort saw similar exposure share a library entry even though their raw
rainfall differed. That is what makes the library reusable across ~100 sites. It is a
testable hypothesis about the model, not an assumption.

### 7.1 Validity window

Reusing a cohort solve computed under `E_ref` in a stand with environment `E` incurs a
linearisation error proportional to `‖E − E_ref‖`. The library is therefore exact where
competition is a mild perturbation — **pre-closure**. In the closed-canopy regime the
linearisation degrades, but there the data are uninformative anyway. The window where
the library is accurate and the window where the data constrain the rates are the same
window. Do not report tight posteriors from stands the library extrapolated into.

### 7.2 Population and persistence

The library is **write-through**, not precomputed-and-frozen:

```
def query(theta, birth_year, exposure):
    e, traj, var = emulator.predict(theta, exposure)
    if var < tol and in_hull(theta, exposure):
        return e, traj                                    # warm: cheap lookup
    e, traj = scm_single_cohort(theta, birth_year, exposure)   # COLD PATH
    emulator.insert(theta, exposure, e, traj)             # active learning
    return e, traj
```

A miss costs one single-cohort solve, not a full stand assembly. The library is seeded
by cold start (§10 B3), grown by misses during the fit, and persisted across runs — so
the marginal cost of each new landscape falls.

**§11.1 gates this.** A clamped response has a kink the emulator cannot interpolate
across, so every query near the kink misses.

---

## 8. Control flow

Four nested levels. The inner two are per-site and parallel; the outer two are global.

```
# ---------- OUTER: global fit over Theta (gradient-based) ----------
def fit(Theta0, landscapes, sites):
    Theta = Theta0
    until converged:
        theta_site = { s: Theta.gradient(s.covariates) for s in sites }

        parfor s in sites:                                   # ~100 sites, parallel
            state[s], nu[s] = assemble_site(s, theta_site[s],
                                            Theta.establishment_response)
            misfit[s]       = site_misfit(s, state[s], nu[s])

        loss = sum(misfit) + pool_penalty(nu, RegionalEvents, Theta.hyper_variances)

        grad  = adjoint_gradient(Theta, state, nu, loss)     # one backward sweep
        Theta = optimizer.step(Theta, grad)
    return Theta, Laplace_cov(adjoint_hessian_lowrank(Theta))


# ---------- INNER: assemble one stand ----------
def assemble_site(s, theta, est_response):
    E  = s.local_modulation.exogenous_environment()   # beta=0: no competition
    nu = None
    for beta in continuation_schedule(0 -> 1):        # coupling homotopy (§8.2)
        until E converged:                            # SCF, DIIS-accelerated
            kernels = [ library.query(theta, c.event.year, exposure(E, c))
                        for c in s.cohorts ]
            nu, active = solve_nu(kernels, s.census, beta, est_response, s)
            E = recompute_environment(nu, kernels, beta)
    return (kernels, nu)
```

| level | grain | count | mode |
|---|---|---|---|
| outer `Theta` | serial | — | gradient descent |
| sites | embarrassingly parallel | ~100 | across cores/nodes |
| continuation `beta` | serial, warm-started | ~5 | within site |
| SCF | serial, DIIS-accelerated | ~3–10 | within `beta` |
| `solve_nu` | convex | — | inside SCF |

### 8.1 `solve_nu` — the convex inner solve

```
def solve_nu(kernels, census, beta, est_prior, dendro):
    A    = assemble_design(kernels)        # A[j,i] = kernel i's contribution to feature j
    P, m = build_prior(est_prior, dendro)  # dated -> near-delta; undated -> shrink to m

    # convex:  min ||A nu - census||^2_Sigma + (nu-m)' P (nu-m)   s.t.  nu >= 0
    nu, active = nnls_qp(A, census, P, m)
    return nu, active
```

Two exposed facts matter downstream. The **active set** (`nu_i` pinned at zero) *is*
the suppressed-sapling bank — the cohorts the data push to zero, and the recurring
unidentifiable set. And the problem is convex given frozen `E`, so there are no local
minima; all nonconvexity has been exported to `θ` and to `E`.

### 8.2 Coupling continuation

Introduce `β ∈ [0,1]` scaling competition. At `β = 0` cohorts are independent, the
environment is exogenous (the a-priori landscape only), the inverse problem is convex
in `ν` and separable across sites, and the library is *exactly* reusable. At `β = 1`
there is full competition. March `β` upward, warm-starting each solve from the last,
iterating the field to self-consistency at each step.

This is numerical continuation: exact, not an approximation. It anneals precisely the
term that creates the difficulty, and it turns "the library is only conditionally
valid" from a caveat into an algorithm. Expect stiffening at high `β` for sites deep in
the closed-canopy regime; refresh library entries there (§7.1).

If trees are **not** age-labelled, a second annealing is needed: soft-assign observed
individuals to candidate rainfall cohorts with a temperature and sharpen as it cools
(the adaptive-vertex-fitter construction). Where dendro dates a cohort the assignment
is hard and this is skipped — **dendro turns adaptive vertex fitting back into ordinary
vertex fitting** at anchor sites.

### 8.3 Where dendro dispatches

```
def site_misfit(s, kernels, nu):
    m = census_misfit(s.census, predict(kernels, nu))      # everyone gets this
    for c in s.cohorts:
        if c.dated:
            # (1) birth date pinned: candidate event confirmed, nu[c] tightly constrained
            # (2) growth-kernel term: observed increments vs modelled trajectory
            m += ring_misfit(c.ring_series, kernels[c].trajectory)
    return m

def pool_penalty(nu, events, hyper):
    # dated cohorts anchor regional mu_estab; undated sites borrow strength
    return sum( logprior(nu[site,event] | events[event].mu_estab, hyper) )
```

A site with zero dendro runs the identical control flow — its `if c.dated` branch is
simply never taken. It inherits identification through `theta_site` (pinned by *other*
sites' cores) and through `mu_estab` (pinned by the regional event). Dendro sites do
not constrain themselves better so much as they calibrate the shared functions that
constrain everyone.

### 8.4 The adjoint

```
def adjoint_gradient(Theta, states, nus, loss):
    grad = 0
    parfor s in sites:
        g_pred = d_misfit_d_prediction(s)              # from the loss (§9)

        # VARPRO / envelope theorem: nu* is optimal in the inner solve, so on the
        # FREE set  dL/dnu . dnu/dTheta = 0.  Do NOT differentiate through nnls_qp.
        # Active (nu=0) components stay active under infinitesimal perturbation.
        g_free = restrict_to_free_set(g_pred, active[s])

        # adjoint through the SCF fixed point  E* = G(E*, nu, Theta):
        #     (I - dG/dE)' lambda_E = seed(g_free)
        # The coupling is causal, so (I - dG/dE) is block LOWER-triangular and
        # lambda_E is ONE BACKWARD SWEEP in birth date. No iterative solve.
        lambda_E = backward_sweep(states[s], g_free)

        grad += project(lambda_E, dG_dTheta) + direct_partial(g_free, Theta)

    grad += pooling_adjoint(nus, RegionalEvents, Theta.hyper_variances)
    return grad
```

`lambda_E(t)` is the **shadow price of shading at time `t`**. A cohort's total
influence on the fit is its contribution to the light field convolved with
`lambda_E`. The library aggregates presence; the adjoint aggregates consequence. The
forward sweep populates the library in time order; the adjoint reads shadow prices in
reverse time order.

What the adjoint buys that the library alone cannot:

1. **All ~30 physiology gradients in one backward sweep**, at the cost of one forward
   assembly, instead of 30 finite-difference re-runs. This is what makes the outer
   `θ` optimisation affordable.
2. **Correct gradients *through* the self-consistent coupling.** Finite-differencing
   the coupled system without re-converging the field gives a wrong gradient. Naive AD
   over the SCF loop gives iteration-count-dependent garbage. The adjoint differentiates
   the *solution* via the implicit function theorem at the fixed point.
3. **A direct read-out of identifiability.** The magnitude of the adjoint sensitivity
   per cohort *is* how much the data constrain that cohort. Negligible sensitivity =
   unidentifiable — and it will be the suppressed sapling bank again.

Two implicit solves must be handled deliberately: the SCF fixed point and the pooling
reduction. Neither is automatic.

---

## 9. The loss

If growth → position and survival → amplitude (§1.1), the discrepancy must separate
position error from mass error. Binned multinomial and L2 losses conflate them: a pure
growth-rate error shifts the predicted distribution and is charged as a mass error in
every bin, contaminating the survival gradient.

Two options occupy the same slot; choose by data type.

- **Stem-level data → point-process likelihood.** The birth-date state *is* a marked
  point process: arrivals at times `a` with marks (establishment size, initial store),
  intensity `b(a)·pr_estab(a)·exp(−∫μ)`, pushed forward deterministically to observed
  size. Write the exact likelihood — a log-Gaussian Cox process for the rainfall-driven
  intensity is the standard Bayesian form. Never bin.
- **Size distributions only → unbalanced optimal transport.** Hellinger–Kantorovich /
  KL-relaxed Sinkhorn decomposes discrepancy explicitly into a transport part (→ growth
  gradient) and a mass creation/destruction part (→ survival gradient) with a tunable
  exchange rate. That is the growth/survival residual split, as a loss. Sinkhorn is
  differentiable and cheap, so it drops into §8.4.

Structurally the census term is an **unfolding** problem either way: recover a true
distribution from a smeared observation through a known response, the response being
the `library.query` kernels. Take the field's hard-won lesson as given: the
unregularised inverse is garbage, and the reported covariance must include the
regularisation bias.

Channel weights (census / rings / rainfall) should not be hand-set. Estimate their
relative precisions as variance components, REML-style.

---

## 10. Cold start

The fit loop assumes a populated library, a `θ₀`, and a warm `E` — each of which the
other two would otherwise have to supply. Cold start manufactures all three from data
and cheap models. Strict dependency order **B1 → B2 → B3 → B4**, descending from
most-direct-data to most-derived.

```
def cold_start(landscapes, sites, dendro):
    # B1: bootstrap the growth kernel DIRECTLY from dendro - no inverse problem.
    #     Ring increments ARE a sampled h(t;a). Fit g(theta,E) by nonlinear
    #     regression of increments on observed local environment. Needs no stand
    #     assembly and no library: a single-cohort forward model only.
    theta_growth0 = fit_growth_to_rings(dendro, landscapes)

    # B2: bootstrap strategy box + environmental gradient with cheap proxies
    theta_box = ballpark_strategy(sites)
    gradient0 = finlay_wilkinson(sites, env_index(landscapes))   # 1-D reaction norm
    Theta0    = assemble(theta_growth0, theta_box, gradient0)

    # B3: bootstrap the LIBRARY by DoE over the plausible box (offline, parallel).
    #     Needs theta_box only, not a fit. Embarrassingly parallel single-cohort solves.
    design = sobol(theta_box, exposure_range)
    emulator.train([scm_single_cohort(*d) for d in design])

    # B4: per-site STATE cold start is FREE, by AEDT backward convergence (§5.1).
    for s in sites: s.E_init = s.local_modulation.exogenous_environment()

    return Theta0, emulator
```

B1 is the keystone: dendro observes the growth kernel directly, so `theta_growth0` is
the one global parameter obtained without solving any inverse problem. That is the cash
value of partial dendro coverage — it does not constrain sites, it bootstraps the
shared kernel, which is what cold start is most starved of.

B4 has a theorem behind it and cannot bias the answer: start from the trivial
no-competition field, integrate forward over the rainfall history, and the initial
guess is forgotten. Cold-starting the *state* is principled; cold-starting `θ` is where
the work is.

```
def run(landscapes, sites, dendro):
    if not warm_cache.exists():
        Theta0, emulator = cold_start(landscapes, sites, dendro)
    else:
        Theta0, emulator = warm_cache.load()
    Theta, cov = fit(Theta0, sites, emulator)
    warm_cache.save(Theta, emulator)
    return Theta, cov
```

**Caveat.** A fit starting far from the truth thrashes the emulator: many misses, many
single-cohort solves, slow early iterations. The mitigation is B1–B2. Better `Theta0`
buys down the cold-path cost of the first fit, so sparse dendro pays twice — once to
identify the kernel, once to keep the emulator in-hull while it learns.

---

## 11. Diagnostics

```
weak_modes    = eig(adjoint_hessian_lowrank)     # what is identified
resolution[s] = superres_separation(theta, s)    # which rainfall events are resolvable
dendro_xval   = holdout_dated_sites_and_predict()
```

- **Weak-mode analysis** reports on the global layer. Eigendecompose the reduced
  Hessian, identify the near-null directions, name them, pin them with external
  constraints. This is standard detector-alignment practice and it runs on **synthetic
  data before any fieldwork**. It converts the identifiability worry from a qualitative
  fear into a spectrum that can be printed, and it says which of the three confounds
  (§2) actually bites at these parameters and this sampling design. Its ceiling is the
  AEDT memory bound (§5.1).
- **Resolution** reports on the local layer (§5.2). Pre-registrable.
- **`dendro_xval`** is the result reviewers will trust. Hold out entire dated sites,
  predict their structure and ages from the shared kernel, report the error. It
  directly measures whether sparse dendro propagates — the claim the whole architecture
  rests on. Budget it from the start.

### 11.1 Blocking defect: the storage restoring-rate clamp

The clamp on `S` (plant §6.1) makes cohort responses non-smooth in ~14% of
cohort-times. This breaks **both** the library emulator (a kink cannot be interpolated
cleanly) and the adjoint (the gradient through a clamp is wrong). Replace it with a
smooth restoring rate below zero. Until then every gradient in §8.4 is suspect and
every emulator query near the kink is a miss.

---

## 12. Build order

1. **Fix §11.1.** Smooth restoring rate. Unlocks the emulator and the adjoint.
2. **Weak-mode analysis on synthetic data.** Cheap, runs before fieldwork, tells you
   what is estimable and what external data buys the most.
3. **Compute the super-resolution separation bound** per site (§5.2). State the
   temporal resolution defensible at each site.
4. **Build the fit as local/global with VARPRO inside SCF** (§8). Stage it: freeze
   mortality globals while fitting positions, then release.
5. **Add the loss** — unbalanced OT for size distributions, point-process likelihood if
   stem-level data exist (§9).
6. **Add `dendro_xval`** and report it.

---

## 13. Borrowed machinery — one-line dictionary

Each is load-bearing at a specific point, not a loose analogy.

| borrowed from | what it is here | where |
|---|---|---|
| detector alignment (Millepede) | local/global split; eliminate locals analytically | §4, §8 |
| weak-mode analysis | near-null directions of the reduced Hessian | §11 |
| vertex fitting | constrain many cohorts to a shared origin (a rainfall event) | §6 `RegionalEvent`, §8.3 pooling |
| adaptive vertex fitting | annealed soft assignment of trees to cohorts | §8.2, only if undated |
| unfolding | recover the true size distribution through a known response | §9 |
| super-resolution | sparse spike-train recovery through a convolution | §5.2, §8.1 |
| unbalanced OT | loss splitting transport (growth) from mass (survival) | §9 |
| point-process likelihood | arrivals-with-marks generative model | §9 |
| impulse response / response matrix | precomputed cohort solves, combined and iterated | §7 |
| numerical continuation | the `β` coupling homotopy | §8.2 |
| SCF + DIIS | self-consistent light field | §8 |
| variable projection (Golub–Pereyra) | eliminate `ν` analytically | §3, §8.4 |
| multi-tracer transit-time analysis | different lag kernels on one driver | §5 |
| AEDT (Chesson) | the converged stand state; burn-in and memory ceiling | §5.1 |
| equifinality / degeneracy | the adversary the architecture exists to fight | throughout |

The consistency check worth stating: every technique that **breaks** degeneracy
(multi-tracer, vertex fitting across decorrelated sites, dendro anchors) feeds the
global layer; every technique that **stabilises the local inverse** (super-resolution,
regularisation, unfolding) lives in `solve_nu`; and the two diagnostics report on the
two layers respectively. Six unrelated disciplines split the problem at the same joint,
which is evidence the joint is real and not an artefact of how `plant` is coded.

---

## 14. Open items

- **Emulator refresh policy.** When to retrain versus incrementally insert, and how
  predictive variance should gate the `solve_nu` regularisation. An uncertain kernel
  should widen the amplitude prior, or extrapolated cohorts get overconfident `ν`.
- **Channel-weight estimation.** REML variance components for census/rings/rainfall
  (§9), rather than hand-set weights.
- **SMC sampler.** If a posterior is wanted rather than MAP + Laplace: introduce one
  rainfall cohort at a time, mirroring the causal forward sweep, with likelihood
  tempering for the growth/survival multimodality.
