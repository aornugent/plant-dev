# The TF24 leaf as a single differentiable node

> **Read `06-tf24-dependency-map.md` §6 alongside this.** On the production path the
> collar operating point is a stationary interior maximum (`|∂Π/∂p| ~ 1e-5 … 1e-7` at tight
> tolerance) and the envelope theorem holds to 0.006–0.9% on `d(profit)/dψ`, so this
> report's premise is the right one. What replaces its **Newton polish** is not a
> correction to the geometry but a cheaper construction: report 06 §6.2 collapses the five
> flux adjoints onto one scalar, divides once by `Π_pp`, and takes one gradient of
> `∂Π/∂p` — no root-find at all. The polish figure quoted below (4.541e-10) is a toy
> measurement and is not a production number.
>
> **The branch census below undercounts, and that stands.** It enumerates five early exits
> from `prepare_collar_solve` plus an uncounted sixth case pinned at `bound_b`. The
> zero-flux `psi_upstream >= psi_stem` branch is none of those — it is a jump *inside* the
> objective evaluation, which exit instrumentation cannot see. Its incidence is zero on a
> production run and the jump across it is exactly `R_d`. `../tf24-correctness.md` P0.5 is
> the full manifest.
>
> **`Π_pp` is measured** (`scripts/curvature_probe.R`): negative at 52 of 52 states over
> the argmax's whole feasible domain, `|Π_pp|` from 0.1723 to 15.61, so the single divide
> in §6.2 amplifies a flux adjoint by at most 5.8×. The same sweep finds 15 of those 52
> states with the operating point **pinned at a bound** — every one at `psi_soil ≥ 1.5 MPa`
> and `height ≥ 2 m`, outside the default driver's range but inside the stress banks'. The
> leaf node is therefore two branches and a selector on `|∂Π/∂p|`, and this report's
> section 1 already has the right shape for the bound branch: pinned means `p*` *is* the
> bound, so its derivative is the bound's derivative, analytic and exact.

## 1. The proposal

Everywhere else in plant, a rate is a closed-form function of state and traits. In
TF24 it is not: the plant **chooses** its operating point. `Leaf::find_root_collar_psi`
maximises carbon profit over the root-collar water potential, within a feasibility
interval the soil sets. Differentiating a choice is a different problem from
differentiating an expression, and it has to be treated as one.

The tempting approach — make the `Leaf` scalar-templated so the tape records the
search along with everything else — is wrong twice over.

**It computes the wrong derivative.** `util::golden_section_max` shrinks its bracket by
a fixed ratio per iteration and returns the bracket's midpoint. The iteration count
depends only on the bracket width and the tolerance; the objective enters only through
the comparison that picks which half to keep. So for a fixed comparison pattern the
returned argmax is an exact affine function of the bracket endpoints and is
**independent of the objective's values**. A tape recording the search yields the
derivative of the bracket, not of the argmax. The objective's sensitivity is
structurally absent from it (section 5).

**It puts an active scalar somewhere it cannot safely go.** `Leaf` holds four
interpolators on a fixed 100-knot grid, roughly thirty loose `double` members with no
boundary between parameters and per-solve scratch, two caches keyed on exact `double`
comparison, a QAG integrator, a nested root-find and the golden-section search. Each
is a separate correctness question under an active scalar, and a mistake in any of
them is a wrong gradient rather than a compile error. One class of mistake is already
known: a hand-written value-graft whose lambda has a deduced return type hands the
tape references to expression-template temporaries that die on return, and the reverse
sweep then dereferences reused stack memory — a segfault arbitrarily far from its
cause, invisible to valgrind because the storage is stack.

**The proposal: leave `Leaf` entirely `double`, and give the tape one node whose local
Jacobian is supplied.**

The optimisation structure is what makes this cheap, and most of the work turns out
to be unnecessary:

- **`profit_` is the objective evaluated at its own maximiser.** By the envelope
  theorem `d(profit)/d(theta)` is the partial derivative at *fixed* operating point —
  the argmax's motion contributes nothing. This is the entire carbon channel:
  assimilation, net mass production, all four growth rates, the mortality argument.
  **No argmax derivative is needed for any of it.**
- **`soil_consumption_` is a different matter.** It is set as a side effect at the
  operating point, so it is a consumer of the argmax rather than the objective, and
  the envelope theorem says nothing about it. Here `d(q*)/d(theta)` is genuinely
  required, and the implicit function theorem applied to the stationarity condition
  supplies it.
- **At a boundary optimum both are simpler.** When the argmax is pinned to the
  feasibility bound, `q*` *is* the bound, so its derivative is the bound's derivative
  — analytic, and exact.
- **The selector between the two is free.** Whether the argmax sits on a bracket
  endpoint is a comparison already available where the search returns.

Those are the only four facts needed. Nothing inside `Leaf` is differentiated; the
node relates its inputs to its outputs and the tape sees a small dense block.

**One further step is not optional, and it is the most actionable finding here.**
`golden_section_max` returns the midpoint of a bracket it has narrowed to `tol`, so
`q*` carries an error of up to `tol/2` — and that error enters the derivative through
the point at which the implicit function theorem is linearised. Measured, with the
decomposition otherwise identical: at `tol = 1e-12` the gradient is wrong by 5.8e-06,
and **at TF24's production `GSS_tol_abs = 1e-3` it is wrong by 3.5%.** Newton-polishing
`q*` to a stationary point before using it gives **4.5e-10 at every tolerance tested**,
matching an exact root-find. Tightening the search instead does not work: the error
plateaus at 6e-6 and stops responding.

So the node must polish. It is cheap — one to three Newton steps from within `tol/2` of
the root — and develop already has the exact first derivative it needs
(`dprofit_droot_collar_psi`). Section 7.2 gives the measurements and section 6.1 the
placement.

**Measured, and this is what makes it practical:** across 4 372 101 leaf solves at
production settings, **every one is a strictly interior optimum**. All five of the
solver's early exits have zero incidence and the narrowest feasibility bracket
observed is 1 342 times the tolerance that would collapse it. The boundary branch is
reachable, but it needs a twentyfold rainfall reduction (section 4). So the interior
treatment is the production path and the boundary treatment is insurance.

**Scope.** Six output rows are needed for a census or R0 functional: `profit_` and the
five `soil_consumption_` layers. The leaf's other five outputs reach auxiliary slots
only (section 3.3). The input side is the arguments to `set_physiology` that carry
derivatives, plus whichever of TF24's 51 declared differentiation targets reach the
leaf (section 6.2).

**What this does not fix**, and both matter: TF24's growth gate is a hard un-smoothed
switch immediately downstream of `profit_`, and one of develop's derivative helpers
falls back to a finite difference at a layer kink. Section 8.

---

## 2. Why the leaf, specifically

`TF24_Strategy::net_mass_production_dt` runs the hydraulic optimisation once per
cohort per Runge-Kutta stage. At production settings — `max_patch_lifetime = 105.32`,
141 cohorts, mean-light shading — that is **4 372 101 leaf solves** (measured), in a
53.1 s forward run, over 2 829 accepted ODE steps. **That count and that step count
predate the NSC storage state**; report 01 §2 gives develop's own counts, where the
same structural ratio projects about 8 M solves. The ratio is what this report uses and
it is unaffected: two solves per cohort per stage.

A leaf solve taken off the tape records approximately **1 600 operations, independent
of the number of solver iterations**. At XAD's 12 bytes per operation:

    4 372 101 solves x 19.2 kB  ~=  84 GB          (projected)

against a whole-run tape of roughly 220 GB on the same tree (490 GB on develop's counts,
report 01 §2). So the leaf is a large fraction of the
recording without being all of it, and shrinking it alone does not make a production
gradient possible. Report 1 bounds peak memory; this report is about correctness and
containment, with size as a secondary benefit.

---

## 3. State at develop

### 3.1 The call path

```
TF24_Strategy::compute_rates(environment, vars)                 tf24_strategy.cpp:151
  net_mass_production_dt(environment, height, area_leaf_, height_inverse)
    ... allometry, root mass distribution over soil layers ...
    optimise_at(radiation):                                     tf24_strategy.cpp:401
        leaf.set_physiology(area_leaf_, mass_root_prop_, pars.rho, pars.a_bio,
                            radiation, psi_soil, soil_depths_,
                            leaf_specific_conductance_max, atm_vpd, ca,
                            sapwood_volume_per_leaf_area, leaf_temp,
                            atm_o2_kpa, atm_kpa)
        solve_leaf()  ->  leaf.find_root_collar_psi()
    the shading model decides how many times optimise_at runs:
        CrownCentre  1 solve at the crown-centre light
        MeanLight    1 solve at the leaf-area-weighted mean light  (TF24's default)
        DeepCrown    one solve per Gauss-Kronrod abscissa (rule 21)
    assimilation_ = leaf.profit_ * area_leaf_ * 60*60*12*365/1e6
    return net_mass_production_dt_A(assimilation_, respiration_, turnover_)
```

and the solve itself:

```
find_root_collar_psi()
  if (!prepare_collar_solve(bound_a, bound_b)) return;   // operating point already set
  opt_root_psi = util::golden_section_max(
      [](double bound) { psi_stem = find_psi_stem_from_psi_root(-bound, psi_soil_inverted_);
                         return profit_psi_stem_TF(psi_stem, bound); },
      bound_a, bound_b, GSS_tol_abs);
  opt_psi_stem_    = find_psi_stem_from_psi_root(-opt_root_psi, psi_soil_inverted_);
  root_collar_psi_ = -opt_root_psi;
  profit_          = profit_psi_stem_TF(opt_psi_stem_, opt_root_psi);
```

### 3.2 Six ways the operating point gets set

`prepare_collar_solve` returns `false` — meaning it has set the operating point itself
and no search runs — on five conditions:

| | condition | action |
|---|---|---|
| **E1** | `-wettest_soil_layer >= psi_crit` | `set_shutdown_state(-psi_crit)` |
| **E2** | `E_column(-psi_crit, psi_soil_inverted_, psi_crit) < 0` | `set_shutdown_state(-root_psi_crit)` |
| **E3** | `-root_crit >= psi_crit` | `set_shutdown_state(root_crit)` |
| **E4** | `assim_max_ < 0` | operating point at `root_zero_E`, zero transpiration |
| **E5** | `abs(bound_b - bound_a) <= GSS_tol_abs` | collapsed interval, use the midpoint |

There is a sixth case, and it is the one that matters most for this proposal because
it is **not** an early exit: the search runs normally and returns an argmax sitting on
the bracket endpoint `bound_b = max(-root_crit, -root_psi_crit)`, the root-hydraulic
ceiling. The envelope-theorem argument holds at an interior optimum and does not hold
there. Section 4 counts all six.

### 3.3 Which leaf outputs are load-bearing

`compute_rates` reads the leaf as follows:

| leaf member | destination | needs a derivative? |
|---|---|---|
| `profit_` | `assimilation_` -> `net_mass_production_dt_` -> height, fecundity, area_heartwood, mass_heartwood rates and the mortality argument | **yes** |
| `soil_consumption_[i]` | `evapotranspiration_dt(area_leaf_, i)` -> `vars.set_consumption_rate(i, ...)` -> `Patch::resource_depletion` -> soil rates | **yes** |
| `opt_psi_stem_` | `vars.set_aux(aux_idx_opt_psi_stem, ...)` | no — auxiliary only |
| `root_collar_psi_` | `vars.set_aux(aux_idx_opt_root_psi, ...)` | no |
| `transpiration_` | `vars.set_aux(aux_idx_transpiration, ...)` | no |
| `E_up_` | `vars.set_aux(aux_idx_E_up, ...)` | no |
| `stom_cond_CO2_` | `vars.set_aux(aux_idx_stom_cond_CO2, ...)` | no |

**Six output rows carry the rates: `profit_`, and `soil_consumption_` for each of the
five soil layers.** The other five outputs reach auxiliary slots and need derivatives
only if a functional reads them. `test-strategy-tf24.R`'s E-conservation test reads
`E_up_` through the auxiliary path, so a functional built on that would need a seventh
row.

### 3.4 Derivative machinery develop already has

develop contains hand-built exact derivatives of the leaf, added for TF24f's
acclimation tracking:

- `Leaf::dprofit_droot_collar_psi(opt_root_psi)` — forward-mode AD for the analytic
  photosynthesis and cost algebra, the implicit function theorem at the
  `psi_stem_to_ci` root-find, and analytic spline derivatives via
  `Interpolator::deriv` for the smooth transport. It replaced a noisy finite
  difference.
- `Leaf::dE_from_soil_dpsi_collar(P_x_r, psi_soil)` — analytic
  `d(E_up_)/d(collar potential)`, where the integral's derivative collapses to the
  analytic slope of the pre-integrated vulnerability curve.
- `Leaf::evaluate_root_collar_psi` and `Leaf::profit_at_collar_psi` — evaluate the leaf
  at a *given* collar potential rather than optimising it, which is the entry point a
  supplied Jacobian needs.

So the pattern is already present in develop for one input direction. This proposal
extends it to the full input set and routes it onto the tape.

### 3.5 A defect in the shutdown path

`Leaf::set_shutdown_state` sets three members:

```cpp
void Leaf::set_shutdown_state(double root_collar) {
  root_collar_psi_ = root_collar;
  opt_psi_stem_ = psi_crit;
  profit_ = -R_d_ - hydraulic_cost_TF(psi_crit);
}
```

It does not clear `soil_consumption_`. `set_physiology` calls
`soil_consumption_.resize(soil_number_of_depths_, 0.0)`, and `std::vector::resize`
does not modify existing elements, so at an unchanged layer count the previous values
persist. The `Leaf` is shared through the strategy's `shared_ptr` across every cohort
of the species, so **a cohort taking a shutdown exit contributes the previous
cohort's water draw to `resource_depletion`.** That is a forward-model defect, not
only a gradient one: the uptake is stale and independent of the shut-down plant's own
soil moisture.

The fix is two lines in `set_shutdown_state` — `soil_consumption_.assign(n, 0.0)` and
`E_up_ = 0.0` — and the AD branch already carries it. Section 4 establishes the blast
radius: unreachable on the production driver, 199 occurrences in 330 021 solves at a
twentyfold rainfall reduction.

---

## 4. Measured incidence of every branch

Counters were added to the five exits and the boundary case in a worktree on develop
at `96941d3b`. Runs used `scm_base_parameters("TF24", "TF24_Env")` with
`add_strategies(p0, trait_matrix(0.1978791, "lma"))`, default `Environment("TF24")`,
`Control()`, `refine_schedule = FALSE`. The instrumentation is preserved as
`docs/reports/leaf-branch-census.patch`.

One obstacle worth recording, because it blocks any such run: **develop's plant does
not compile against the installed odelia.** `odelia/ode_util.hpp` calls `xad::value`
without including XAD, so `control.cpp` fails on the first translation unit reaching
`plant/control.h -> odelia/ode_control.hpp -> odelia/ode_util.hpp`. Forcing
`-include XAD/XAD.hpp` through `PKG_CPPFLAGS` works around it; the real fix is an
include in the odelia header.

| configuration | solves | E1 | E2 | E3 | E4 | E5 | pinned at bound_a | pinned at bound_b | min bracket |
|---|---|---|---|---|---|---|---|---|---|
| **life 105.32, mean-light, default rain** | **4 372 101** | 0 | 0 | 0 | 0 | 0 | 0 | **0** | 1.342 |
| life 20, rain 1 | 1 400 715 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.381 |
| life 20, rain 0.5 | 2 563 713 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.057 |
| life 20, rain 0.2 | 2 750 871 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.016 |
| life 20, rain 0.1 | 343 779 | 0 | 0 | 0 | 0 | 0 | 0 | **267** | 0.876 |
| life 20, rain 0.05 | 330 021 | 0 | **199** | 0 | 0 | 0 | 0 | **110 984** | 0.716 |
| life 5, mean-light | 577 791 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.798 |
| life 5, deep-crown | 6 038 487 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.811 |
| life 5, deep-crown, rain 0.1 | 2 826 369 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.109 |

**On the production driver every solve is a strictly interior optimum.** All five
exits are unvisited across 4.37 million solves, and the narrowest bracket is 1.342
against `GSS_tol_abs = 1e-3` — E5 is not merely unreached, it is three orders of
magnitude away.

**The boundary regime is real but needs severe drought, and it is not one of the
documented exits.** A fivefold rainfall reduction changes nothing. At tenfold, 267 of
343 779 solves (0.08%) return an argmax pinned at `bound_b`. At twentyfold, 110 984 of
330 021 (33.6%), plus 199 hits on E2. The first thing to appear is the case nobody was
counting.

**Deep-crown does not change the picture and costs 10.5x.** At life 5 it runs
6 038 487 solves against mean-light's 577 791, and produces zero boundary cases even
at rainfall 0.1.

**Two caveats.** The rainfall 0.1 and 0.05 runs collapse to roughly 280 accepted ODE
steps from 2 153, so the stand is largely dying and the 33.6% is computed over a small
and unrepresentative population — the *existence* of the regime is established, its
frequency under a realistic drought driver is not. And `min bracket` declines
monotonically with drying (1.38 to 0.72), so the trend does point at E5 eventually,
far past where the model produces anything.

---

## 5. Why the search must not be taped

```cpp
double golden_section_max(Function f, double ax, double bx, double tol) {
  const double gr = (std::sqrt(5.0) + 1.0) / 2.0;
  double a = ax, b = bx;
  double c = b - (b - a) / gr;
  double d = a + (b - a) / gr;
  double fc = f(c), fd = f(d);
  while (std::abs(b - a) > tol) {
    if (fc > fd) { b = d; d = c; fd = fc; c = b - (b - a) / gr; fc = f(c); }
    else         { a = c; c = d; fc = fd; d = a + (b - a) / gr; fd = f(d); }
  }
  return (a + b) / 2.0;
}
```

The iteration count is fixed by `(bx - ax)` and `tol` alone, since the bracket shrinks
by `1/gr` each pass regardless of the objective. The objective enters only through
`fc > fd`, which selects which sub-bracket survives. The return value is the midpoint
of a bracket reached by golden-ratio subdivisions of the original.

So **for a fixed comparison pattern the argmax is an exact affine function of
`(ax, bx)` and does not depend on the objective's values at all.** Taping through the
search gives `d(bracket)/d(theta)` pushed through that affine map. That is a real
quantity and it is not the derivative of the argmax.

This also means a comment in `optimize.h` states the wrong reason for a correct
choice. It says `brent_fmin`'s parabolic step makes the argmax non-smooth in its
inputs, and that the collar solver uses golden section because the demographic
growth-rate gradient needs the argmax to vary smoothly with plant state. Golden
section's argmax is not smooth either — it is a staircase in the objective and affine
in the bracket. What it actually gives is a comparison pattern that is *locally
constant*, so across a finite-difference step of `node_gradient_eps = 1e-6` the
pattern usually does not change and the argmax moves affinely with a bracket that
itself moves smoothly. That is the property `Node::growth_rate_gradient` relies on.
The distinction matters because the stated reason invites a reader to treat the argmax
as differentiable by composition, which is exactly the mistake this section rules out.

---

## 6. The node

### 6.1 Construction, by output

**`profit_`, interior optimum.** `profit_ = profit_psi_stem_TF(opt_psi_stem_,
opt_root_psi)` is the objective at its own maximiser, so `dP/dq = 0` and

    d(profit)/d(theta)  =  partial(profit)/partial(theta)   at fixed q*

The argmax's motion contributes nothing. Obtained by evaluating the objective at the
passive argmax.

**Before either: polish `q*`.** Take one to three Newton steps on `dP/dq = 0` from the
search's answer, using `dprofit_droot_collar_psi` for the first derivative. The
linearisation point for everything below must be a stationary point, not a bracket
midpoint (section 7.2). This changes the operating point by up to `GSS_tol_abs/2`,
which moves `profit_` only at second order — it is at an optimum — but moves
`soil_consumption_` at first order, so it is a forward-model change at that scale and
is the one part of this proposal that needs re-blessing.

**`soil_consumption_`, interior optimum.** A consumer of `q*`, so it needs

    dq*/d(theta)  =  -( d2P / dq dtheta ) / ( d2P / dq2 )

from the implicit function theorem applied to stationarity, with
`denom_sign::negative` asserted — at a maximiser the second derivative is negative,
and near a fold it approaches zero, which is where an unguarded division produces the
large spurious gradients this construct is known for. `odelia::implicit_value` is the
existing primitive and its sign guard turns that into a loud stop.

**Both outputs, boundary optimum.** `q*` is the bound, so
`dq*/d(theta) = d(bound_b)/d(theta)` with
`bound_b = max(-root_crit, -root_psi_crit)`. `root_psi_crit` is closed form in
`root_b` and `root_c`; `root_crit` comes from `find_root_psi`, itself a root-find and
so another `implicit_value`. There is no envelope theorem here — `dP/dq != 0` at the
bound — so `profit_` picks up the boundary term too.

**The selector.** `abs(opt_root_psi - bound_b) <= 2 * GSS_tol_abs`, evaluated where
the search returns. No new state and no new tolerance.

### 6.2 Inputs, and how they scale with the target count

The differentiable inputs are the arguments to `set_physiology` that carry
derivatives, plus the seeded traits that reach the leaf through `prepare_strategy`:

| input | source | count |
|---|---|---|
| `radiation` | `k_I * max(light, 1e-4) * PPFD` | 1 |
| `psi_soil` | `environment.get_soil_water_potential_state()` | 5 |
| `area_leaf_` | aux `competition_effect` = `area_leaf(height)` | 1 |
| `mass_root_prop_` | `mass_root(area_leaf_)` distributed over layers by `Q` | 5 |
| `leaf_specific_conductance_max` | `K_s * theta / (height * eta_c)` | 1 |
| `sapwood_volume_per_leaf_area` | `theta * height * eta_c` | 1 |
| seeded targets reaching the leaf | subset of `TF24_AD_FIELDS` | n |

`TF24_AD_FIELDS` declares **51** strategy parameters, so n is realistically tens
rather than a handful, and for a calibration workflow plausibly the full set. The
block is `(14 + n) x 6` entries written to the enclosing tape per solve:

| n | block | against 19.2 kB recorded |
|---|---|---|
| 4 | 1.3 kB | 15x smaller |
| 12 | 1.9 kB | 10x |
| 32 | 3.3 kB | 5.8x |
| 51 | 4.7 kB | 4.1x |

The size benefit therefore shrinks as more targets are seeded, from about 15x to about
4x. **The containment benefit does not depend on n at all**, and it is the reason to
do this: `Leaf` stays `double`, so its interpolators, caches, integrator, root-find and
search are never audited for active-scalar correctness and never can be silently
wrong. Under report 1's cohort-granular decomposition peak memory is already bounded
without any of this, which is why size is secondary here.

### 6.3 What runs unchanged

`optimise_at(radiation)` executes exactly as develop does it, in `double`. Every
interpolator, both caches, the QAG integrator, the nested `psi_stem_to_ci` root-find
and the golden-section search are bit-identical. There is no templated `Leaf` and none
of section 1's audit is required.

---

## 7. Evidence

The construction in section 6 was exercised in a standalone system with plant's
coupling structure and none of its physiology (`scratchpad/cohort_toy.cpp`, described
in report 1 section 7). The inner solve was implemented twice: as a plain implicit
root-find, and as a fixed-tolerance golden-section maximisation over a soil-dependent
bracket, with the envelope theorem for the objective, the implicit function theorem
for the side output, and the boundary branch.

**This is a toy.** It establishes that the envelope / IFT / boundary decomposition is
arithmetically correct and how large its residuals are. It establishes nothing about
TF24's leaf physiology.

### 7.1 The two branches

| leaf treatment | interior | boundary | cohort vs whole-run tape | AD vs FD |
|---|---|---|---|---|
| implicit root-find | — | — | 1.4e-14 | **4.5e-10** |
| argmax, all interior | 1 200 | 0 | 8.1e-15 | 1.1e-05 |
| argmax, bound at 0.60 | 1 200 | 0 | 1.4e-14 | 4.0e-06 |
| argmax, bound at 0.30 | 1 183 | 17 | 7.5e-15 | 2.9e-06 |
| argmax, bound at 0.10 | 0 | 1 200 | 9.8e-15 | **3.1e-10** |

**The boundary branch is exact; the interior branch is not.** Fully at the bound, AD
matches FD to 3.1e-10, because `q*` is then an analytic function of the bound. Fully
interior, 1.1e-05. A run mixing the two (17 boundary of 1 200) does not degrade, so
the selector composes and there is no catastrophe at the switch.

### 7.2 The interior residual, and why it closes

The interior branch's discrepancy is entirely the accuracy of `q*` **as a linearisation
point**. Sweeping the search tolerance, with and without a Newton polish of `q*` before
the implicit function theorem is applied:

| search tolerance | unpolished | polished | ratio |
|---|---|---|---|
| **1e-3** (TF24's `GSS_tol_abs`) | **3.48e-02** | **4.54e-10** | 7.7e7 |
| 1e-4 | 1.41e-02 | 4.54e-10 | 3.1e7 |
| 1e-6 | 2.09e-04 | 3.44e-10 | 6.1e5 |
| 1e-9 | 1.11e-05 | 4.54e-10 | 2.4e4 |
| 1e-12 | 5.81e-06 | 4.54e-10 | 1.3e4 |

Polished, the argmax branch matches the plain root-find reference (4.542e-10) to three
digits at every tolerance, and the search tolerance stops mattering. Unpolished, the
error is **3.5% at the tolerance TF24 actually uses**, and tightening the search does
not rescue it — it plateaus near 6e-6.

Two candidates were eliminated by direct test rather than argument. The envelope
application is **not** implicated: carrying `q*`'s own derivative into `profit_` instead
of evaluating at the passive argmax changes nothing (5.812e-06 either way), and combining
that with the polish gives the same 4.541e-10. And it is not `implicit_value`'s
finite-difference probe scale: the polish leaves that probe untouched and still recovers
exactness.

**The transferable rule:** a search's stopping tolerance is not the accuracy of a
derivative built on its answer. An argmax consumed by anything other than the objective
must be polished to a stationary point before it is used as a linearisation point, and
the required accuracy is set by the derivative, not by the value.

This also characterises develop's demographic transport term.
`Node::growth_rate_gradient` finite-differences the growth rate at
`node_gradient_eps = 1e-6`, and the growth rate depends on `q*`, which moves in steps of
order `GSS_tol_abs = 1e-3`. The stencil is stable only because the comparison pattern is
locally constant across a 1e-6 height perturbation, so `q*` moves affinely with its
bracket — which means the quantity that stencil differentiates is the bracket-affine
surrogate rather than the true optimum. That is consistent with the code working and
with section 5's analysis, and it is worth knowing before anyone tightens or loosens
either tolerance.

---

## 8. Constraints

**C1. TF24's growth gate is a hard un-smoothed switch, immediately downstream of
`profit_`.**

```cpp
if (net_mass_production_dt_ > 0) { ...growth, fecundity, heartwood... }
else                             { ...all four rates set to 0.0... }
```

`smooth_positive` is applied at two sites in `ff16_strategy.h` and two in
`k93_strategy.h` on the AD branch, and at none in either tree for TF24. So at the
carbon compensation point four of TF24's five rates have a derivative discontinuity,
and the leaf node's `profit_` Jacobian is multiplied by zero on one side of it. This
proposal neither causes nor fixes it, but any finite-difference verification of a TF24
gradient will straddle it if the step crosses the gate for any cohort. The incidence
should be counted the way section 4 counts the leaf branches before it is designed
around.

**C2. `dE_from_soil_dpsi_collar` falls back to a central difference.** It returns NaN
when any layer sits on a branch kink — `P_x_r == psi_soil[i]`, the gravity-balance
point, or `P_x_r == 0` — and `dprofit_droot_collar_psi` then substitutes a central
difference. That fallback would sit inside the supplied Jacobian, which is precisely
where a numerical derivative of an active quantity should not be. It needs a decision
rather than inheritance, and the kink incidence should be counted.

**C3. Two caches must be handled, as in report 1.** `photo_temp_cached_` persists
across cohorts on a key of `(leaf_temp_, atm_o2_kpa_)` while caching `vcmax_` and
`jmax_`, which depend on `pars.vcmax_25` and `pars.jmax_25` — both declared entries of
`TF24_AD_FIELDS`. The key is a proper subset of the dependencies. Under this proposal
the `Leaf` stays `double`, so the cache cannot poison a tape; but if either parameter
is a seeded target, the value the node linearises about must correspond to the seeded
value, and a stale cache breaks that.

**C4. The shutdown-state defect of section 3.5.** Reachable only under drought, but it
is on the path this node replaces, and it should be fixed on develop independently of
any AD work.

**C5. `Leaf` has no boundary between parameters and per-solve scratch.** Roughly thirty
loose doubles, five vectors and four interpolators, interleaved, with nothing marking
which are transient. This proposal reduces the consequence — nothing needs auditing
for active-scalar safety — but section 6.2's input list was assembled by reading
`set_physiology`'s signature and would silently become incomplete if that signature
grew. Report 1 section 11 step 4 proposes giving those fields an explicit boundary,
which would make the input list derivable rather than maintained.

**C6. Only mean-light and crown-centre are covered.** TF24's deep-crown assembly
raises a stop on the AD branch's active path. Under this proposal deep-crown is 21
nodes per cohort rather than one, each with its own Jacobian — mechanical, but 21 times
the work, and not covered by section 7's evidence.

---

## 9. What this asks of a Strategy author

The engine's contract does not change: a Strategy implements `compute_rates` and gets a
gradient. But a Strategy containing an inner solve has obligations that no compiler
checks, and TF24 currently meets some of them by accident. Stated as guidance, each
rule with the construct that motivates it:

**1. Return the solution, expose the residual, never expose the search.** For a
quantity defined implicitly the differentiable object is the defining equation. A
search's output is determined by comparisons, so differentiating through it yields
something that is not the derivative of the solution (section 5). `implicit_value`
takes a residual for this reason.

**2. Know which of your outputs are load-bearing.** Only the outputs that reach rates
need derivative rows. TF24 has seven leaf outputs and two of them matter (section 3.3).
Establishing that turned a twelve-row problem into a six-row one.

**3. An objective at its own optimum is free; its other consumers are not.** The
envelope theorem covers `profit_` completely and covers `soil_consumption_` not at all,
and the measured cost of getting that wrong is 4 to 12% (section 7). The question to
ask of every output of an optimisation is whether it *is* the objective or merely reads
the argument that maximised it.

**4. A feasibility bound is part of the model, so its derivative is part of the
answer.** When the optimum sits on a constraint, the constraint's sensitivity *is* the
sensitivity. That branch is exact and cheaper than the interior one, which is the
opposite of what one might expect.

**5. Every early exit sets an operating point — set all of it.** `set_shutdown_state`
sets three members and leaves a fourth stale, and because the object is shared the
stale value belongs to a different plant (section 3.5). An exit that writes a partial
state is a cross-cohort channel.

**6. A guard that returns NaN and falls back to a finite difference is a severance in
disguise.** C2. The fallback is invisible in the value and wrong in the derivative.

**7. Count your branches before designing around them.** Five exits were documented as
four, the sixth case was not documented at all, and it is the only one that appears.
All six turned out to have zero incidence on the production driver, which converted a
suspected blocker into a two-line branch. A counter behind an environment variable is
cheap and it is the difference between designing for the model and designing for a
worry.

**8. Say whether a switch is a kink you mean.** C1's gate may be exactly the intended
biology — a plant with negative carbon balance does not grow. The point is that it
should be a recorded decision rather than an artefact of writing an `if`.

---

## 10. Implementation order

1. **Land the section 4 counters behind an environment-variable gate.** They are cheap,
   they converted a suspected blocker into a measured non-event, and they are the
   mechanism for C1's and C2's incidence questions.
2. **Polish the collar argmax** (section 6.1). At `GSS_tol_abs = 1e-3` this is the
   difference between a 3.5% error and an exact derivative, so it is a prerequisite
   rather than a refinement. It changes `soil_consumption_` at the `tol/2` level, so it
   needs a baseline re-bless.
3. **Fix `set_shutdown_state`** on develop (section 3.5). A forward-model correctness
   fix, independent of AD.
4. **Extend `photo_temp_cached_`'s key** to include `vcmax_25` and `jmax_25`.
5. **Add the `xad::value` include to `odelia/ode_util.hpp`** so develop's plant builds
   against the installed odelia without a workaround.
6. **Build the node for the interior branch only**, with the boundary branch raising a
   loud stop. Section 4 says the production driver never reaches it, so this is a usable
   intermediate state and the stop makes the untested path unreachable rather than
   silently wrong.
7. **Add the boundary branch** and verify against a deliberately dried driver where
   section 4 shows it fires.
8. **Count C1's gate crossings and C2's kink incidence**, then decide whether either
   needs treatment.

---

## 11. What would falsify this

- **`profit_` is not always the objective at its own maximiser.** Any code path that
  sets `profit_` other than by evaluating `profit_psi_stem_TF` at the returned argmax
  breaks the envelope argument there. `set_shutdown_state` is one such path — it sets
  `profit_` directly. Section 4 says it is unreached in production; the enumeration
  should be completed rather than assumed.
- **Polishing does not recover exactness on the real leaf.** Section 7.2 establishes it
  on a toy objective with an analytic second derivative. TF24's objective is a composition
  through `find_psi_stem_from_psi_root`, so its stationarity condition is more expensive
  to Newton on, and whether two or three steps suffice is unmeasured.
- **The supplied Jacobian disagrees with a whole-tape recording of the same solve.**
  Record one leaf solve operation by operation at short lifetime, where the tape fits,
  and compare row by row. This is the direct test and it needs no full SCM run.
- **The counters show nonzero exit incidence on a realistic drought driver.** Section
  4's drought runs are degenerate — 280 steps from 2 153. A driver that dries the stand
  without killing it would settle whether the boundary branch is a corner case or a
  regime.
