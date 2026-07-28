# The TF24 leaf as a single differentiable node

A proposal for making TF24's leaf hydraulic optimisation differentiable without an
active scalar ever entering the `Leaf` class, addressed to plant maintainers.

Numbers labelled **measured** were produced in this study, with the instrumentation
described in section 3. Numbers labelled **projected** are arithmetic on measured
quantities. Numbers attributed to earlier work come from this repository's
`docs/v3-facts.md` and the probes under `docs/reference/` on
`claude/odelia-ad-tape-reverse-496fuf`.

---

## 1. The problem

`TF24_Strategy::net_mass_production_dt` runs a leaf-level hydraulic optimisation
once per cohort per Runge-Kutta stage. At production settings
(`max_patch_lifetime = 105.32`, 141 cohorts, 2 829 accepted ODE steps, mean-light
shading) that is **4 372 101 leaf solves** (measured).

Earlier work in this repository measured a leaf solve taken *off* the tape at
approximately **1 600 recorded operations per solve, independent of the number of
solver iterations**. At XAD's 12 bytes per operation that is 19.2 kB per solve, so

    4 372 101 solves x 19.2 kB  ~=  84 GB          (projected)

against a whole-run tape of roughly 220 GB. The leaf is a large fraction of the
recording but not the whole of it.

Size, however, is the secondary problem. The primary problem is that the `Leaf`
class is a poor host for an active scalar. It contains four interpolators built on
a fixed 100-knot grid, roughly thirty loose `double` members with no structural
separation between parameters and per-solve scratch, two caches keyed on exact
`double` comparison, a QAG integrator, a nested root-find, and a golden-section
maximisation. Templating it on the scalar type means auditing every one of those
for active-scalar correctness, and the AD branch's attempt to do so
(`P2c: template Leaf residual + delete FD seam`) is what produced the reverse-sweep
segfault traced to a dangling expression template in the value-graft
(`TF24: fix the dangling value-graft -- ROOT CAUSE of the reverse-sweep segfault`).

This report argues for the opposite direction: **leave the `Leaf` entirely
`double`, and give the tape a single node with a supplied local Jacobian.**

---

## 2. State at develop

### 2.1 The call path

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
    shading model decides how many times optimise_at runs:
        CrownCentre  1 solve at the crown-centre light
        MeanLight    1 solve at the leaf-area-weighted mean light  (TF24 default)
        DeepCrown    one solve per Gauss-Kronrod abscissa (rule 21)
    assimilation_ = leaf.profit_ * area_leaf_ * 60*60*12*365/1e6
    return net_mass_production_dt_A(assimilation_, respiration_, turnover_)
```

`Leaf::find_root_collar_psi` (`leaf_model.cpp`) is:

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

### 2.2 The five early exits

`prepare_collar_solve` returns `false` — meaning it has set the operating point
itself and no search runs — on five conditions. Existing documentation in this
repository refers to "the four leaf early-exits"; there are five.

| | condition | action |
|---|---|---|
| **E1** | `-wettest_soil_layer >= psi_crit` | `set_shutdown_state(-psi_crit)` |
| **E2** | `E_column(-psi_crit, psi_soil_inverted_, psi_crit) < 0` | `set_shutdown_state(-root_psi_crit)` |
| **E3** | `-root_crit >= psi_crit` | `set_shutdown_state(root_crit)` |
| **E4** | `assim_max_ < 0` | operating point at `root_zero_E`, zero transpiration |
| **E5** | `abs(bound_b - bound_a) <= GSS_tol_abs` | collapsed interval, use the midpoint |

Beyond these there is a sixth case that is **not** an early exit and which no
existing document counts: the search runs normally and returns an argmax that
sits on a bracket endpoint. `bound_b = max(-root_crit, -root_psi_crit)`, the
root-hydraulic ceiling. This matters because the envelope theorem argument in
section 5 holds at an interior optimum and does not hold at a boundary one.

### 2.3 Which leaf outputs are load-bearing

`compute_rates` (`tf24_strategy.cpp:151-215`) reads the leaf as follows:

| leaf member | destination | load-bearing for rates? |
|---|---|---|
| `profit_` | `assimilation_` -> `net_mass_production_dt_` -> height, fecundity, area_heartwood, mass_heartwood rates and the mortality argument | **yes** |
| `soil_consumption_[i]` | `evapotranspiration_dt(area_leaf_, i)` -> `vars.set_consumption_rate(i, ...)` -> `Patch::resource_depletion` -> soil rates | **yes** |
| `opt_psi_stem_` | `vars.set_aux(aux_idx_opt_psi_stem, ...)` | no — auxiliary only |
| `root_collar_psi_` | `vars.set_aux(aux_idx_opt_root_psi, ...)` | no |
| `transpiration_` | `vars.set_aux(aux_idx_transpiration, ...)` | no |
| `E_up_` | `vars.set_aux(aux_idx_E_up, ...)` | no |
| `stom_cond_CO2_` | `vars.set_aux(aux_idx_stom_cond_CO2, ...)` | no |

This is a useful narrowing and it does not appear to be recorded anywhere. **For a
census or R0 functional, the leaf node needs derivatives on exactly `profit_` (one
scalar) and `soil_consumption_` (one per soil layer, 5 at the default
configuration): six outputs.** The other five leaf outputs reach auxiliary slots
only and need derivatives solely if a functional reads them. `test-strategy-tf24.R`'s
E-conservation test does read `E_up_` through the auxiliary path, so a functional
built on it would need that seventh row.

### 2.4 Derivative machinery that already exists

develop already contains hand-built exact derivatives of the leaf, added for TF24f's
acclimation tracking:

- `Leaf::dprofit_droot_collar_psi(opt_root_psi)` (`leaf_model.h:332`) — described in
  its own comment as combining "forward-mode AD for the analytic
  photosynthesis/cost algebra, the implicit-function theorem at the `psi_stem_to_ci`
  root-find, and analytic spline derivatives (`Interpolator::deriv`) for the smooth
  transport", replacing a noisy finite difference.
- `Leaf::dE_from_soil_dpsi_collar(P_x_r, psi_soil)` (`leaf_model.h:344`) — analytic
  `d(E_up_)/d(collar potential)`, where "the integral's derivative collapses to
  +/- `root_vuln_integral_from_psi.deriv`".
- `Leaf::evaluate_root_collar_psi` and `Leaf::profit_at_collar_psi`
  (`leaf_model.h:315`, `:323`) — evaluate the leaf at a *given* collar potential
  rather than optimising it.

So the pattern this report proposes is already present in develop for one input
direction. The proposal is to extend it to the full input set and to route it onto
the tape.

### 2.5 One defect worth flagging on the way past

`Leaf::set_shutdown_state` on develop sets three members:

```cpp
void Leaf::set_shutdown_state(double root_collar) {
  root_collar_psi_ = root_collar;
  opt_psi_stem_ = psi_crit;
  profit_ = -R_d_ - hydraulic_cost_TF(psi_crit);
}
```

It does not clear `soil_consumption_`. `set_physiology` calls
`soil_consumption_.resize(soil_number_of_depths_, 0.0)`, and `std::vector::resize`
does not modify existing elements, so when the layer count is unchanged the values
persist. Because the `Leaf` is shared through the strategy's `shared_ptr` across
every cohort of the species, **a cohort taking a shutdown exit contributes the
previous cohort's water draw to `resource_depletion`.** This is a forward-model
defect, not only a gradient one.

The AD branch fixes it (commit `762b7e25`, "fix(tf24): a shut-down leaf clears its
uptake (#55)") by adding `soil_consumption_.assign(soil_number_of_depths_, 0.0)`
and `E_up_ = 0.0`. Section 3 establishes when it is reachable: never on the default
driver, and 199 times in 330 021 solves at a twentyfold rainfall reduction.

---

## 3. Measured incidence of every branch

The five exits and the boundary case were instrumented with counters in a worktree
on develop at `96941d3b`. Runs used `scm_base_parameters("TF24", "TF24_Env")` with
`add_strategies(p0, trait_matrix(0.1978791, "lma"))`, default `Environment("TF24")`,
`Control()`, `refine_schedule = FALSE`.

One build note: **develop's plant does not currently compile against the installed
odelia.** `odelia/ode_util.hpp:62` calls `xad::value` with no XAD include, so
`control.cpp` fails on the first translation unit that reaches
`plant/control.h -> odelia/ode_control.hpp -> odelia/ode_util.hpp`. Forcing
`-include XAD/XAD.hpp` via `PKG_CPPFLAGS` works around it. This is a real
ordering fragility in a header that crosses the package boundary.

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

Readings:

**On the production driver every solve is a strictly interior optimum.** All five
exits have zero incidence over 4.37 million solves, and the narrowest bracket
observed is 1.342 against `GSS_tol_abs = 1e-3` — E5 is not merely unvisited, it is
three orders of magnitude away.

**The boundary regime exists but requires severe drought, and it is not one of the
documented exits.** At a fivefold rainfall reduction nothing changes; at tenfold,
267 of 343 779 solves (0.08%) return an argmax pinned at `bound_b`; at twentyfold,
110 984 of 330 021 (33.6%), plus 199 hits on E2. The failure mode that appears
first is the one nobody was counting.

**Deep-crown does not change the picture, and costs 10.5x.** At life 5, deep-crown
runs 6 038 487 solves against mean-light's 577 791 for the same lifetime, and
produces zero boundary cases even at rainfall 0.1. Whatever else recommends
mean-light as the default, the branch census does not argue against deep-crown on
correctness grounds.

**Two honest caveats.** The rainfall 0.1 and 0.05 runs collapse to roughly 280
accepted ODE steps from 2 153, so the stand is largely dying and the 33.6% is
computed over a small and unrepresentative population — the *existence* of the
regime is established, its frequency under a realistic drought driver is not. And
`min bracket` declines monotonically with drying (1.38 to 0.72), so the trend does
point at E5 eventually, far beyond where the model produces anything.

**Consequence for section 2.5's defect.** The stale-uptake bug is unreachable on
the production driver and reachable under drought. It is a real bug with a narrow
blast radius.

---

## 4. Why the search must not be taped

`util::golden_section_max` (`optimize.h:123-146`):

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

Read the loop as a function of its inputs. The iteration count is fixed by
`(bx - ax)` and `tol` alone, because the bracket shrinks by `1/gr` per iteration
regardless of the objective. The objective enters **only** through the comparison
`fc > fd`, which selects which sub-bracket is kept. The returned value is
`(a + b) / 2`, where `a` and `b` are reached by a sequence of updates whose
positions are golden-ratio subdivisions of the original bracket.

Therefore: **for a fixed comparison pattern, the returned argmax is an exact affine
function of `(ax, bx)` and is completely independent of the objective values.**

Two consequences.

**Taping through the search computes the wrong thing.** It yields
`d(bracket)/d(theta)` composed with the affine map, which is a real quantity but is
not `d(argmax)/d(theta)`. The objective's own sensitivity contributes nothing. This
confirms by direct reading what earlier work in this repository inferred from a
staircase statistic, and sharpens it — the claim is not that the taped derivative
is noisy, it is that the objective's derivative is structurally absent from it.

**develop's comment about this function states the wrong mechanism.**
`optimize.h:113-119` says `brent_fmin`'s "parabolic step makes the argmax a
*non-smooth* function of the inputs", and that the collar solver uses golden section
because the demographic growth-rate gradient "needs that argmax to vary smoothly
with plant state". Golden section's argmax is not smooth either: it is a staircase
in the objective and affine in the bracket. What it actually provides is a
comparison pattern that is *locally constant*, so over a finite-difference step of
`node_gradient_eps = 1e-6` the pattern usually does not change and the argmax moves
affinely with a bracket that itself moves smoothly. That is the property
`Node::growth_rate_gradient` relies on, and it is worth correcting in place because
the stated reason invites someone to treat the argmax as differentiable by
composition.

---

## 5. The correct decomposition, by output

### 5.1 `profit_` needs no argmax derivative at all

`profit_ = profit_psi_stem_TF(opt_psi_stem_, opt_root_psi)` is the objective
evaluated at its own maximiser. At an interior optimum `dP/dq = 0`, so by the
envelope theorem

    d(profit)/d(theta)  =  partial(profit)/partial(theta)  at fixed q*

and the motion of the argmax contributes nothing. This covers the entire carbon
channel: assimilation, net mass production, all four growth rates, and the
mortality argument. The staircase in `q*` is irrelevant to it.

### 5.2 `soil_consumption_` does need it

`soil_consumption_` is set as a side effect of evaluating the objective at the
operating point, so it is a *consumer* of `q*` rather than the objective itself.
The envelope theorem says nothing about `(partial c / partial q) q*'`. Earlier work
in this repository records this as a theorem-level warning; section 7 measures its
size.

For this channel `dq*/d(theta)` is required, and at an interior optimum it comes
from the implicit function theorem applied to the stationarity condition:

    dq*/d(theta)  =  -( partial^2 P / partial q partial theta )
                     / ( partial^2 P / partial q^2 )

with `denom_sign::negative` asserted, since at a maximiser the second derivative is
negative. `odelia::implicit_value` is the existing primitive for this and its
`denom_sign` guard is what turns a fold into a loud stop rather than a division by
approximately zero — the failure mode recorded in this repository as the `b1`
blow-up.

### 5.3 At a boundary optimum the treatment is different and simpler

When the argmax is pinned at `bound_b`, `q*` **is** the bound, so

    dq*/d(theta)  =  d(bound_b)/d(theta),      bound_b = max(-root_crit, -root_psi_crit)

which is analytic: `root_psi_crit` is a closed form in `root_b` and `root_c`, and
`root_crit = find_root_psi(...)` is itself a root-find, so it is another
`implicit_value`. There is no envelope theorem here — `dP/dq != 0` at the bound —
so `profit_` also picks up the boundary term.

### 5.4 The selector is free

The branch indicator is a comparison already available at the end of
`find_root_collar_psi`: whether `|opt_root_psi - bound_b| <= 2 * GSS_tol_abs`. No
new state, no heuristic, no tolerance beyond the one the search already takes.
Section 3 measures how often each branch is taken.

---

## 6. The proposal

**Keep `Leaf` entirely `double`. Compute its value exactly as develop does. Present
the solve to the tape as one node whose local Jacobian is supplied.**

Concretely, at the seam in `net_mass_production_dt`:

1. `optimise_at(radiation)` runs unchanged, in `double`. All four interpolators,
   both caches, the QAG integrator, the nested `psi_stem_to_ci` root-find and the
   golden-section search behave bit-identically to develop. There is no templated
   `Leaf`, so none of section 1's audit is required.
2. The node's differentiable inputs are the arguments to `set_physiology` that
   carry derivatives, plus the seeded traits that reach the leaf through
   `prepare_strategy`:

   | input | source | count |
   |---|---|---|
   | `radiation` | `k_I * max(light, 1e-4) * PPFD` | 1 |
   | `psi_soil` | `environment.get_soil_water_potential_state()` | 5 |
   | `area_leaf_` | aux `competition_effect` = `area_leaf(height)` | 1 |
   | `mass_root_prop_` | `mass_root(area_leaf_)` distributed over layers by `Q` | 5 |
   | `leaf_specific_conductance_max` | `K_s * theta / (height * eta_c)` | 1 |
   | `sapwood_volume_per_leaf_area` | `theta * height * eta_c` | 1 |
   | seeded leaf traits | `vcmax_25`, `jmax_25`, `p_50`, `K_s`, ... | n |

3. The node's outputs are `profit_` and `soil_consumption_[0..4]` — six, per
   section 2.3 — plus any auxiliary slot a functional reads.
4. The local Jacobian is assembled by the rules in section 5: envelope for
   `profit_` at an interior optimum, IFT for `soil_consumption_`, the bound's
   derivative for both at a boundary optimum. develop's
   `dprofit_droot_collar_psi` and `dE_from_soil_dpsi_collar` are the existing
   pieces; the remaining input directions follow the same construction.
5. That Jacobian is written onto the tape as a linear block relating the registered
   inputs to the registered outputs.

Size, for context rather than as the argument: at `n = 4` seeded traits the block
is `(14 + 4) x 6 = 108` doubles, about **0.9 kB**, against roughly **19.2 kB**
recorded per solve today — a factor of about **21**, or roughly **80 GB of the
220 GB** whole-run tape (projected). Under the cohort-granular decomposition of
report 1, peak memory is already bounded without this, so the size reduction is a
secondary benefit. **The primary benefit is that the `Leaf` never sees an active
scalar.**

---

## 7. Evidence

The construction in section 5 was exercised in a standalone system with plant's
coupling structure and none of its physiology (`scratchpad/cohort_toy.cpp`,
described in report 1 section 6). The inner solve was implemented twice: as a
plain implicit root-find, and as a fixed-tolerance golden-section maximisation over
a bracket whose upper bound comes from the soil state, with the envelope theorem
for the objective, IFT for the side output, and the boundary branch.

**This is a toy.** It establishes that the envelope/IFT/boundary decomposition is
arithmetically correct and how large the residuals are. It establishes nothing
about TF24's leaf physiology.

| leaf treatment | interior | boundary | cohort vs whole-run tape | AD vs FD |
|---|---|---|---|---|
| implicit root-find | — | — | 1.4e-14 | **4.5e-10** |
| argmax, all interior | 1 200 | 0 | 8.1e-15 | 1.1e-05 |
| argmax, bound at 0.60 | 1 200 | 0 | 1.4e-14 | 4.0e-06 |
| argmax, bound at 0.30 | 1 183 | 17 | 7.5e-15 | 2.9e-06 |
| argmax, bound at 0.10 | 0 | 1 200 | 9.8e-15 | **3.1e-10** |

**The boundary branch is exact and the interior branch is not.** Fully at the
bound, AD matches FD to 3.1e-10 — because `q*` is then an analytic function of the
bound. Fully interior, it is 1.1e-05. A run mixing the two (17 boundary of 1 200)
does not degrade, so the selector composes; there is no catastrophe at the switch.

**The interior residual is partly the search tolerance.** Sweeping the
golden-section tolerance `tau` at a fixed finite-difference step:

| tau | AD vs FD | tau^(2/3) |
|---|---|---|
| 1e-6 | 2.09e-04 | 1.00e-04 |
| 1e-8 | 3.31e-06 | 4.64e-06 |
| 1e-10 | 9.21e-06 | 2.15e-07 |
| 1e-12 | 5.81e-06 | 1.00e-08 |
| 1e-14 | 5.96e-06 | 4.64e-10 |

From 1e-6 to 1e-8 it tracks `tau^(2/3)`, which is the rate earlier work in this
repository derived for this family of error. Below that it **plateaus at
approximately 6e-6** and tightening the search further does nothing.

**The witness is not vacuous.** Severing the argmax's influence on the side output
— exactly the channel the envelope theorem does not cover — breaks the gradient by
**4.1%** for the root-find and **11.6%** for the argmax, while the decomposition
itself stays at 1e-15. So `dq*/d(theta)` into `soil_consumption_` is load-bearing
at the several-percent level, not a refinement.

**One open finding, localised but not closed.** The 6e-6 plateau is not the
decomposition (1e-15), not the side-output channel (present with IFT enabled), not
the search tolerance (survives `tau = 1e-14`), and not the finite-difference step.
Against the root-find row's 4.5e-10 under otherwise identical treatment, it is
**in the argmax node's own derivative construction**. Two candidates were not
separated:

1. the envelope theorem being applied at an argmax carrying O(`tau`) position error,
   so `partial P / partial q` is not exactly zero where it is assumed to be; or
2. `odelia::implicit_value`'s central difference for `dF/dy`, which uses a fixed
   `eps = 1e-6 * (|y*| + 1)`. In the interior branch the residual `F` is itself
   `dP/dq`, so this probe computes a **second** derivative by differencing a first
   one, and a fixed-scale probe is the wrong tool for that.

Candidate 2 is the more likely and it is cheap to test: make the probe scale-aware
and re-run the `tau` sweep. For context, 6e-6 relative sits four orders below the
FF16 gradient gate that ships today (asserted at 1e-2 while the truth is
approximately 1e-6), so it is not a blocker. It is also not what an exact IFT
should give, so it should be named rather than absorbed.

---

## 8. Constraints

**C1. TF24's net-production gate is a hard, un-smoothed switch, immediately
downstream of `profit_`.** `tf24_strategy.cpp:186` on develop (and `:248` on the AD
branch):

```cpp
if (net_mass_production_dt_ > 0) { ...growth, fecundity, heartwood... }
else                             { ...all four rates set to 0.0... }
```

`smooth_positive` is applied in `ff16_strategy.h` (2 sites) and `k93_strategy.h`
(2 sites) on the AD branch and in **neither** on develop; TF24 has it nowhere in
either tree. So at the carbon compensation point four of TF24's five rates have a
derivative discontinuity, and the leaf node's `profit_` Jacobian is multiplied by
zero on one side of it. This is not caused by the proposal and the proposal does
not fix it, but any FD verification of a TF24 gradient will straddle it if the
finite-difference step crosses the gate for any cohort. It should be counted the
way section 3 counts the leaf branches before it is designed around.

**C2. `dE_from_soil_dpsi_collar` falls back to a central difference.** Its own
documentation (`leaf_model.h:340-343`): "Returns NaN when any layer sits on a branch
kink (`P_x_r == psi_soil[i]`, the gravity-balance point, or `P_x_r == 0`); the
caller (`dprofit_droot_collar_psi`) then falls back to a central difference." That
fallback would sit inside the supplied Jacobian. It needs a decision rather than
inheritance, and the kink incidence should be counted as section 3 counts the exits.

**C3. Two caches must be handled, as in report 1.** `photo_temp_cached_`
(`leaf_model.h:250-252`) persists across cohorts on a key of
`(leaf_temp_, atm_o2_kpa_)` while caching `vcmax_` and `jmax_`, which depend on
`pars.vcmax_25` and `pars.jmax_25` — both declared entries of `TF24_AD_FIELDS`. The
key is a proper subset of the dependencies. Under this proposal the `Leaf` stays
`double`, so the cache cannot poison a tape; but if either parameter is a seeded
input, the *value* the node linearises about must correspond to the seeded value,
and a stale cache breaks that.

**C4. The shutdown-state defect of section 2.5.** Reachable only under drought, but
it is on the path this node replaces and the branch already carries the fix.

**C5. `Leaf` has no structural boundary between parameters and per-solve scratch.**
Roughly thirty loose doubles, five vectors and four interpolators, interleaved,
with nothing marking which are transient. The proposal reduces the consequence —
nothing needs auditing for active-scalar safety — but the input list in section 6
step 2 was assembled by reading `set_physiology`'s signature and would silently
become incomplete if that signature grew. A compile-time tie between the signature
and the node's registered input list would be worth having.

**C6. Only mean-light and crown-centre are covered.** On the AD branch, TF24's
deep-crown assembly raises `util::stop("TF24 active leaf gradient: the deep-crown
assembly is not yet implemented; use shading_model 'mean-light' or
'crown-centre'.")`. Under this proposal deep-crown is 21 nodes per cohort rather
than one, each with its own Jacobian, which is mechanical but is 21 times the work
and is not covered by section 7's evidence.

---

## 9. Implementation order

1. **Land the counters from section 3 behind an environment-variable gate.** They
   are cheap, they turned a suspected blocker into a measured non-event, and they
   are the mechanism for C1 and C2's incidence questions.
2. **Fix `implicit_value`'s `dF/dy` probe scale** and re-run section 7's `tau` sweep.
   If the 6e-6 plateau drops to 1e-9, candidate 2 is confirmed and the interior
   branch is exact. This is the single highest-information cheap test in this report.
3. **Extend `photo_temp_cached_`'s key** to include `vcmax_25` and `jmax_25`.
4. **Port the branch's `set_shutdown_state` fix to develop** — it is a forward-model
   correctness fix independent of any AD work.
5. **Build the node for the interior branch only**, with the boundary branch raising
   a loud stop. Section 3 says the production driver never reaches it, so this is a
   usable intermediate state, and the stop makes the untested path unreachable
   rather than silently wrong.
6. **Add the boundary branch** and verify against a deliberately dried driver where
   section 3 shows it fires.
7. **Count C1's gate crossings and C2's kink incidence**, then decide whether either
   needs treatment.

---

## 10. What would falsify this

- **`profit_` is not the objective at its own maximiser.** If any code path sets
  `profit_` other than by evaluating `profit_psi_stem_TF` at the returned argmax,
  the envelope theorem does not apply there. `set_shutdown_state` is one such path
  (it sets `profit_ = -R_d_ - hydraulic_cost_TF(psi_crit)` directly); section 3
  says it is unreached in production, but the enumeration should be completed.
- **The interior residual does not fall with a scale-aware probe.** Then candidate 1
  of section 7 is live and the envelope application needs revisiting.
- **The supplied Jacobian disagrees with a whole-tape recording of the same solve.**
  Record one leaf solve operation by operation at short lifetime, where the tape
  fits, and compare row by row against the supplied block. This is the direct test
  and it does not need a full SCM run.
- **The branch counters show a nonzero exit incidence on a realistic drought
  driver.** Section 3's drought runs are degenerate (280 steps from 2 153); a
  driver that dries the stand without killing it would settle whether the boundary
  branch is a corner case or a regime.

---

## 11. Relationship to the other reports

- **Report 1 (cohort-granular reverse sweep)** records `Individual::compute_rates`
  on a per-cohort tape. This report determines what that tape contains for TF24: a
  small linear block rather than 1 600 operations of hydraulic solve. The two are
  independent — report 1's decomposition is correct with the leaf recorded
  operation by operation, merely more expensive, and this report's node is useful
  without report 1, merely insufficient to bound peak memory.
- **Report 3 (the light interpolant)** supplies the `radiation` input in section 6
  step 2, and its vertical-gradient output is what allows the crown integral's
  dependence on the cohort's own height to be carried.
