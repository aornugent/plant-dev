# What #553 asks the model, and what ad/V4 asks it

[traitecoevo/plant#553](https://github.com/traitecoevo/plant/pull/553) — *Prototype
reverse-mode AD of SCM outputs* — is open against `develop`, 141 commits over seven
days, and answers the same question ad/V4 answers. It reaches the answer a
different way, and the difference decides what each one can say.

Everything below is read off the trees. `#553` is `upstream/pr553` (`69083fa5`);
`develop` is `95256cf3`; ad/V4 is the merged `ad/V4-reverse-tf24` across odelia,
phylloptim and plant. Where this contradicts either project's own notes, the code
is what was read.

## The whole game

Both return the derivative of a stand census with respect to every trait, from one
solve. Here is each, complete.

**#553**

```r
p   <- run_scm(p, Environment("FF16"), control(), refine_schedule = TRUE)$parameters
scm <- run_scm(p, Environment("FF16"), control(save_RK45_cache = TRUE),
               refine_schedule = FALSE)                       # a second solve
g   <- stand_gradient(scm, metrics = "LAI", feedback = "resident")
g$jacobian    # metrics x traits
```

**ad/V4**

```r
scm <- run_scm(p, Environment("TF24"), Control(node_density_in_birth_date = TRUE),
               refine_schedule = TRUE, record_trajectory = TRUE)
g   <- stand_gradient(scm)
g$gradient    # 3 metrics x 48 traits
g$refusal     # a stated reason where a metric has no derivative
```

Two solves against one is not the point. The point is what the second solve in
`#553` is for. It records a step schedule, a per-stage light field and a cohort
census, and a **separately written integrator** then replays the stand over that
record in an active scalar. ad/V4 records the same trajectory and re-enters
**`Patch::compute_rates`** — the function the forward solve itself called — at an
active scalar.

```
  #553                                   ad/V4
  ────                                   ─────
  SCM::run ─────► step_history           SCM::run ─────► step_record[k]
                  environment_history                    (one per ACCEPTED step)
                  node census                                 │
                       │                                      │
                       ▼                                      ▼
  ff16_cashkarp_replay                   odelia Step::step_adjoint
  rkck_one_step_tf                         │  loads rec[k-1].state
    │  a second RKCK, no error control     │  re-runs 6 stages at active_scalar
    │  light read from the record          │    └─ Patch::compute_rates
    │  ff16_net_from_components            │         └─ compute_environment
    │  (a re-typed copy of the strategy)   │              (the real light field)
    ▼                                      ▼
  one tape over the WHOLE trajectory     sweep, then Tape::clearAll()
                                         → one step of tape, ever
```

`src/ff16_emergent.cpp` contains no `odelia::ode::Solver`, no `advance_adaptive`,
no `run()`. Its only contact with the solved object is `scm->r_patch()`, read for
arrays.

## Seven places that difference shows

### The coordinate, and the difference quotient inside it

plant's size-density equation carries a transport term `−d(height_dt)/d(height)`,
and the model computes that derivative by differencing the growth rate at a
displaced height. `#553` restates the difference at **nine sites** across two
files, each written `const double GEPS = 1e-6;` with a comment naming the control
it is copying, and each **on the adjoint tape**:

```cpp
    S g_back = height_dt_at<S>(pd, F, n, stage, h - S(GEPS));
    S gprime = (r.height_dt - g_back) / S(GEPS);
```

Both operands are active, so the reverse sweep pushes `λ/1e-6` onto one full rate
evaluation and `−λ/1e-6` onto another, and the two cancel. Every census-metric
gradient carries that 1e6 amplification, at every stage of every step of every
cohort. `#553`'s own roadmap names this cancellation as the prime suspect for the
TF24f coupled tape going non-finite past a patch lifetime of five.

ad/V4 does not differentiate a difference quotient, because the term is not there.
`SCM::census_trait_gradient` opens with `require_birth_date_coordinate`, and on the
birth-date coordinate `Individual::log_density_rate` is:

```cpp
  if (control().node_density_in_birth_date) {
    return -rate(MORTALITY_INDEX);          // no transport term, no probe
  }
  return -growth_rate_gradient(environment) - rate(MORTALITY_INDEX);
```

A density in birth date changes only by mortality: nothing moves an individual
along the birth-date axis, so there is no compression term and no displaced-height
probe to differentiate. Six entry points call `require_birth_date_coordinate`, so
the height branch is unreachable from any gradient.

That choice was forced by a different hazard and closes this one as a consequence.
Reserve-gated growth lets a younger cohort overtake an older one; in the height
coordinate that reorders the census quadrature, so the abscissa is itself a state
variable. `#553` works in the height coordinate and sorts the census trapezium by
`as_double(...)` comparisons — the ordering is held constant through
differentiation, and a trait that changes which cohort is taller does not move it.

### The environment is data in one and a function in the other

`#553` stores the light field per RK stage and offers two readings of it.
`feedback = "frozen"` holds the canopy fixed. `feedback = "resident"` rebuilds it
from the frozen knot positions with active knot values. The default is `"frozen"`,
and the author's own `stand_gradient` documentation says what that costs:

> the feedback routinely dominates and flips the sign of the census metrics
> (LAI / biomass / size-moment) relative to the frozen reading

`"resident"` is FF16 only. TF24 raises *"feedback = 'resident' is implemented for
FF16 only so far"*; TF24f's raises *"too stiff"* past a patch lifetime of about
four.

ad/V4 has no mode. `Patch::compute_environment` is templated on the scalar and runs
on the reverse pass like every other part of the rate evaluation, so the
competition profile carries derivatives because the sweep computes it. The same
measurement appears on our side from the other direction: feedback suppresses the
leaf-mass-per-area response about sevenfold and reverses the sign of the seed-mass
response.

Both projects measured the same ecology. One can report it only on request, for one
model.

### The leaf: one theorem, two ways of plumbing it

Neither project tapes the leaf's root-find, for the same reason — `Leaf` is a
`double` class whose golden-section search no active scalar can enter. Both supply
the derivative at the converged point from the envelope theorem and the implicit
function theorem. The plumbing differs at second order.

`#553` writes twelve `Leaf::dprofit_d*` rows by hand over `assim_colimited_ad`,
`hydraulic_cost_ad` and `electron_transport_full` — **re-typed duplicates of
`Leaf::assim_colimited`, `Leaf::hydraulic_cost_TF` and `Leaf::electron_transport`**,
with nothing asserting the two stay in step. Every second derivative TF24f needs is
then a central finite difference over complete leaf solves: `d2p_dpsi2`,
`d2p_dpsidh`, `d2p_dpsidth[k]`, `d2p_dpsidL` and `dprofit_dh` all come out of
`harvest_point`, at `12 + 4T` leaf solves per cohort per RK stage — about 120 at
TF24's trait count, six times a step.

ad/V4 routes all five leaf sites through one `odelia::implicit_value`, which refuses
on a singular Jacobian by name and whose `record_with_derivatives` writes no row
unless every row is finite. Second derivatives come from `kernel_slope_at`, which
seeds two nested tangents and reads the slope and the whole row of mixed partials
out of one evaluation:

```
    slope   = derivative_along(value(y))          =  ∂K/∂x
    row[r]  = derivative_along(derivative(y)[r])  =  ∂²K/∂x ∂argᵣ
```

Seventeen tape statements, against 521 for the nested-active form it replaces. One
finite difference survives on our side, `marginal_collar_slope`, and the site says
why: the analytic route holds four significant digits through a 1e+05 cancellation
and returns an eighth of the answer with the right sign.

This is what blocks `#553`'s TF24 census. Its own gate says so — *"stand_gradient
for TF24 supports offspring_production only (census is a TF24 follow-up; use TF24f
for census metrics)"* — and the guide names the missing piece as *"a
leaf-optimisation cross-sensitivity"*. That is the phylloptim pull request.

### Memory

`#553` opens one `tape.newRecording()` before the whole replay and sweeps after it.
Every step, every one of six stages, every cohort and every quadrature point is
live on that tape at once, and the census path evaluates the 21-point
Gauss–Kronrod rule twice per cohort-stage — once for the rate, once for the
displaced rate the transport term needs. Cohort count and step count both grow with
patch lifetime, so the tape grows roughly as its square. The offspring path already
splits per cohort and records a 25× speedup from doing so; the census path could
and does not.

ad/V4 clears the tape after every step. `Tape::clearAll()` appears twice in all of
odelia, both inside `adjoint.hpp`, and the bound is one step's arithmetic whatever
the run length. What persists is the recording — `n_steps × (n_state + 5
solved_values)` doubles — which is the trajectory, not its derivative.

### A parameter added, and what notices

`#553` restates `FF16_Pars` as `FF16ProdPars<S>`, hand-copied field by field in
**four** places (`FF16_Strategy::prod_pars`, `ff16_prod_pars_to_fwd`, `lift<S>`,
`field_ptrs<S>`), the last carrying a hand-ordered name list that must stay index
aligned with a pointer list. Adding a trait takes five coordinated edits. There is
**no `static_assert` anywhere** in the pull request's `inst/` or `src/`.

The kernel headers have the same shape. `ff16_production_kernel.h`'s pre-existing
125 lines are genuine single-sourcing — `FF16_Strategy` delegates to them. The 492
lines `#553` adds are independent re-implementations of `compute_rates`, the
allocation split, the mortality rates, the heartwood rates and establishment
probability, while the header's own comment still reads *"They are the SINGLE
SOURCE OF TRUTH"*. Edit the strategy and the gradient keeps differentiating the old
formula, correctly, with no compile error.

ad/V4 declares no column count. It derives one, and asserts the derivation:

```cpp
  static_assert(column_count + undifferentiable.size() == field_count, ...);
  static_assert(sizeof(TF24_Pars<double>) == field_count * sizeof(double), ...);
```

A member added to the struct and not to the table is a build error; so is a stale
exclusion name. 67 fields, 19 carrying a written reason for having no derivative,
48 columns.

### The templating axis is present and unexercised

`#553`'s foundation is a third template parameter `S` over `Internals`,
`Individual`, `Node`, `Species` and `Patch`, defaulting to `double`. It touches
every declaration of those five and about sixty out-of-line definitions.

Nothing instantiates it with an active scalar. Every concrete instantiation in
`RcppExports.cpp`, `RcppR6.cpp`, `RcppR6_post.hpp`, `stochastic_patch.h` and
`stochastic_species.h` is two-argument. `basic_internals<S>` is only ever
`basic_internals<double>`; `basic_FF16_Pars<S>` only ever `basic_FF16_Pars<double>`.
The engines touch the hierarchy three times, all two-argument and all `const&` for
reading arrays off a finished run. The gradient arithmetic runs on parallel local
structs — `FF16ProdPars<S>`, `FF16State<S>`, `FullState<S>`, `St7ad<S>` — and a
hand-written stepper.

`Node<T,E,S>`'s ODE-boundary members still take `odelia::ode::iterator`, which is
`double*`, so a `Node<...,ad>` could not be stepped by the solver even if one were
constructed. The header concedes it: those members "stay uncompiled for ad **until
the ODE-state boundary is wired**".

That boundary is what ad/V4 wires. It is why `Internals` had to become
`Internals<double>` and `Individual::state` had to return `const value_type&`, and
why twenty-three headers transitively include `internals.h` and the change arrives
as one commit.

### What the checks compare against

Across every FF16 and TF24 gradient assertion in `#553`, the finite-difference
reference perturbs a trait and re-runs **the same replay the AD differentiates**:
`ff16_stand_gradient_impl` and `ff16_stand_gradient_native` both call
`ff16_stand_gradient_core`, differing only in where the record comes from. Such a
check establishes that the replay is self-consistent. It cannot establish that the
replay is the solver.

One assertion in the pull request compares an AD gradient against a finite
difference of the real `run_scm`: *"tf24f resident LAI gradient flips sign and
tracks the full-SCM FD"*, one metric, one trait, tolerance **0.2**. The guide states
the gap directly:

> Against a *full* `run_scm` finite difference … the coupled `d(LAI)/dθ` differs by
> ~**16–29 % for geometry traits** (`lma` 29 %, `a_l1` 16 %)

and for the birth-rate axis:

> arguably not the wanted derivative, since that part tracks where the solver places
> its grid rather than the biology

Three FD references pick their step by `fd_best()`, which selects the ladder rung
closest to the AD value being tested. The only machine-precision net,
`test-gradient-regression.R`, carries `skip_on_ci()` as of the branch's last commit
because values drift up to ~3e-3 across compilers; it runs on one machine. When the
values it pinned were wrong it recorded them — `8153c924` re-snapshotted three of
ten baselines that had been pinning a zero-height-cohort defect.

ad/V4's ladder is eighteen files, 1,071 lines of `gradient_ladder.cpp` and an
82 KB helper, checking the sweep against six references. Three share no arithmetic
with it: a captured difference of whole runs across five drivers, the right-hand
side differenced against state, and the model rebuilt from its parameters. Six
rungs reference the real solver. `test-gradient-ladder-injection.R` corrupts one
side eight ways — a dropped channel, a flipped sign, a trait column routed nowhere,
a trait column at a fixed fraction — and requires the block check to notice each,
so the suite says whether its checks would fire.

That rung is the one to read for how a reference should be held. It asserts the
uncaptured column set **both ways**, so a column the reference stops carrying fails
it; asserts by name which regimes refuse; and asserts `sum(live) > 200` before
comparing anything, so a vacuous pass is impossible. Re-taken with both sides
censused on one time grid, it now runs 13/13 with no skips — 270 answered columns a
regime, worst residual 1.1e-03 on drought — and `theta` and `omega`, which
disagreed in sign under the old capture, land on the sweep to six figures.

The suite's gaps are elsewhere, and `catalog.md` section E has them: four skips
that always fire, two that fire on the condition the assertion exists to detect,
six bit-identity comparisons with no finite-count guard behind them (and
`identical(NaN, NaN)` is `TRUE` in R), a C++ suite that exits 0 when it did not
run, and a correctness suite whose longest stand is **two years** for a product
measured at a hundred.

## What #553 has that ad/V4 does not

| | #553 | ad/V4 |
|---|---|---|
| models with a census gradient | FF16, TF24f | TF24 |
| models with an offspring gradient | FF16, TF24, TF24f | — |
| per-cohort state Jacobian | FF16, TF24 | — |
| individual grow-to-size gradient | FF16, TF24f | — |
| `d(metric)/d(birth_rate)` | FF16 | no column exists |
| invasion / mutant fitness gradient | FF16, TF24, TF24f | refused; `test-mutant.R` skips all three |
| non-differenced `g'` available | FF16, TF24f, opt-in | not applicable |
| touches the existing tree | additive, 621 deletions | 5,000 deletions |

`node_gradient_exact_ad` is the one worth taking. `#553` adds
`Strategy::growth_rate_gradient_height_ad` so the transport term can be an analytic
derivative instead of a difference, which is the right fix for anyone who needs the
height coordinate. It defaults to `false`, no public gradient function exposes it,
and TF24 has no implementation — but the mechanism exists, and ad/V4 answers the
same hazard by refusing the coordinate rather than by fixing it.

The coverage gap is real and not rhetorical. `#553` answers five gradient kinds
across three models; ad/V4 answers one, for one model, and an FF16 stand handed to
`stand_gradient()` fails in an `Rcpp::as` type error rather than a model-level
refusal. The invasion gradient is the sharpest of these: `#553`'s default
`feedback = "frozen"` reading of `offspring_production` **is** the rare-mutant
invasion gradient, correct as such, for all three models. ad/V4's `run_mutant`
refuses, and its three tests carry the reason — *"run_mutant needs a pass that
replays a recorded field, and nothing records one"*.

## What neither has

Step sizes are frozen in both. odelia's `Step::step_adjoint` takes `const double h =
step_size;` from the record and never registers it as an input, so neither gradient
carries the term through which a trait moves the step controller. `#553` names this
the frozen-grid caveat and measures it at 16–29 %; ad/V4 has not measured it, and
should.

Neither carries hyperparameters. `d/d(lma)` in both holds `k_l`, `r_s` and the rest
of the hyperpar map fixed, so it is about threefold away from the sensitivity an
ecologist means. Because AD and FD perturb identically, no test on either side can
see it.

## The landing question

`#553` does not merge. `git merge-tree upstream/develop upstream/pr553` exits 1 with
16 conflicted paths, one a modify/delete: `src/leaf_model.cpp` was moved out to
phylloptim by `b81786c6` (#591), and `plant/leaf_model.h` is now a 63-line shim
aliasing `phylloptim::Leaf`. The branch's 445-line in-tree leaf, and the 348 lines it
adds to `src/leaf_model.cpp`, target a model plant no longer owns. Its user-facing
guide is 936 lines written into `overstorey-staging/`, which `141dc8df` (#563)
deleted.

The branch is 36 develop commits and about ten weeks behind. Its one merge from
develop merged its own merge-base and took nothing. Among what it lacks: the NSC
storage pool with reserve-gated growth (#554) — the mechanism that forces the
coordinate question above — the birth-date coordinate flag (#590), the phylloptim
leaf migration (#591), the odelia 0.4.0 migration (#643), TF24 height-resistance
from stem anatomy (#617), and the fix for the cohort-density blow-up (#552) its own
roadmap cites as a relative of its stiffness gate. ad/V4 is level with `develop` on
all three packages.

Issue #472, which `#553` cites as its charter, recommends the opposite sequencing:

> Start with **scope (A)** … Treat templating core scalar for end-to-end AD (scope B)
> as separate milestone, **ideally folded into odelia/XAD migration**.

And the branch's own roadmap, Phase 5, says the deliverable is a four-part stacked
sequence cut fresh from the final tree, with PR #541 closed unmerged to make room
for it. `#553` is the undecomposed spike; Phase 5 was not run.

## Shape of the two changes

Against `develop`, generated files excluded:

| | #553 (plant) | ad/V4 (plant) | ad/V4 (all three) |
|---|---|---|---|
| C++ | +7,276 / −248 | +8,068 / −3,636 | +13,508 / −5,746 |
| tests | +2,354 | +9,021 | +13,264 |
| R | +1,213 | +245 | +321 |
| scripts, notes | +1,788 / −115 | +498 / −959 | — |
| commits | 141 | 17 | 45 |

`#553` ships three lines of implementation for every line of test; ad/V4 ships
slightly more test than implementation. Seventy per cent of `#553`'s C++ is three
new `.cpp` files — `ff16_emergent.cpp`, `tf24f_emergent.cpp`, `tf24_emergent.cpp` —
which is where the second model lives. ad/V4's is spread through `scm.h`, `patch.h`,
`species.h` and `individual.h`, because the change is to the model.

The R surfaces differ in kind. `#553` adds 141 entry points, of which 17 are on a
public path, 11 are test scaffolding, 2 are dead, and 111 are RcppR6-generated
`Patch` history accessors — get and set pairs generated for K93 and TF24 as well,
where nothing ever fills them. ad/V4 adds 40 `[[Rcpp::export]]` entries, 7 of them
product and 33 the ladder, none of the 33 in `NAMESPACE`, and 6 R-level exports.

ad/V4 is the larger change, and it is larger because it deletes. `optimize.h`,
`adaptive_interpolator.h`, four `src/` files and the R-side `ode_fit` surface all go,
and what replaces them is a general adjoint over a general ODE solver — odelia's own
suite exercises it on Lorenz and Lotka–Volterra, and no plant type appears anywhere
in its headers.

## Honest state of ad/V4

Not shippable today either, and what remains is one decision and one regression.

`docs/pr/catalog.md` carries no open defect. Its ten — the out-of-bounds write in
`roots.hpp`, the forward solve running different code from its own derivative, the
drought exception, the discarded `reached` detector, `set_extrapolate` — are closed.
What is left is section A1 and section D:

- **One `scientific_version` decision holds three red suites.**
  `test-strategy-tf24.R`/`-tf24f.R` (19), `test-gradient-incidence.R`/`-parity.R`
  (9), and `_snaps/model-version.md` all pin values develop's #617 moved. None is a
  derivative: every referee is green, including phylloptim's transpose identity over
  all four operating-point kinds at 5.1e-11. Re-pinning them accepts an ecological
  change, which is the one thing `AGENTS.md` says must be named.
- **`phylloptim`'s `test_golden` exits 1**, taking `R CMD check` with it. Forty
  fields at cross-platform drift, plus a `psi_stem optima` mismatch at relative
  difference 1 that is structural and unexplained.
- **`run_mutant` is a `stop()` here and works on develop.** #643 restored it for
  TF24 and this branch hands it back broken. The recorder it needs was reached
  through solver hooks the rewrite stopped calling, and the replacement its own
  comment names does not exist.
- **`gradient_ladder.cpp` ships**, 46 symbols in `plant.so` and a quarter of the
  build, with `Rcpp::compileAttributes()` leaving no way to guard it out.

And the suite has soft spots worth naming: two assertions that cannot fail, one
test that always reports SKIP, a whole-run reference that is frozen data with four
stale parameter names silently dropped, and nothing running a stand past two years
for a product aimed at a century.

The difference is where the uncertainty sits. `#553`'s open item is what the
gradient means — whether the replay is the solver, at 16–29 % on geometry traits,
with one check able to see it. ad/V4's are a version number somebody has to name, a
capability to restore, and a reference to recapture at a longer lifetime.
