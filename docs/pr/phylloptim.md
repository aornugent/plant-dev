# phylloptim

**Base** `traitecoevo/phylloptim:master` · **Head** `aornugent/phylloptim:ad/V4-reverse-tf24`
**Tag on merge** `v0.9.0` · **Needs** odelia `v0.5.0` tagged first

Four comments, posted in order.

## Title

Supply exact derivative rows for the leaf solve

## Body

The leaf picks its operating point by root-finding for the root-collar
water potential that maximises gain net of hydraulic risk. A consumer
differentiating this model had to record that search, which
differentiates the solver: what comes back is the sensitivity of
wherever those iterations stopped, and depends on the starting guess and
the convergence tolerance.

`Leaf` is now templated on its scalar and supplies the derivative of the
operating point directly, from the implicit function theorem at the
converged point. The path is `supply_draw_at()` for the soil draw and
its collar response in one walk, `collar_at()` for the potential, then
`outputs_at()` for profit and uptake. `operating_point_kind()` reports
which of four residuals pinned the point; where no derivative exists the
call throws instead of returning a plausible number.
`vulnerability_curve_ncontrol` defaults to 400, not 100, so every
caller's numbers move.

Closes #

---

# Comment 1 — Orientation

## Terms

- **row** — one output's derivatives against a list of inputs. A *supplied* row is computed here and handed to the consumer's tape, never recorded.
- **kind** — `OperatingPointKind`: which condition pinned the operating point. Four have derivatives; two do not.
- **draw** — `SupplyDraw<S>`: the soil water drawn at one collar potential, with the per-layer split and the collar conductance.
- **the three scalars** — `Leaf<S>` instantiates at `double` (the forward solve), `tangent_scalar<double>` (a directional derivative, no tape), and `active_scalar<double>` (plant's reverse recording).

## The path

```
  prepare_collar_solve()              kind := Unsolved
        │
        ▼
  root-find over collar psi           plain double, off any tape
        │
        ├──► Interior                 stationarity of profit
        ├──► BoundaryWet              uptake balance
        ├──► BoundaryCrit             stem continuity at psi_crit      ─┐ four
        ├──► BoundaryRootCrit         the root's critical potential    ─┘ residuals
        │
        └──► HydraulicShutdown        marginal profit returns a literal 0.0
             ShadeDeath               no derivative exists; collar_at throws
        │
        ▼
  supply_draw_at(collar, supply)      one walk: per-layer uptake, total flux,
        │                             collar conductance
        ▼
  collar_at(draw, pars, curvature)    implicit_value node
        │                             absent entirely at S == double
        ▼
  outputs_at(...)  ──►  LeafOutputs<S>{ profit, uptake[] }
```

Two files carry the change: `leaf_model.hpp` (+1622) and `roots.hpp` (+443).

| file | lines | what |
|---|---|---|
| `leaf_model.hpp` | +1622 | `Leaf<S>`, `leaf_pars<S>`, `SupplyDraw`, `PhotoCapacity`, `LeafOutputs`, `OperatingPointKind` |
| `roots.hpp` | +443 | `SupplyAt`, `CollarConductance`, the merged uptake walk |
| `gradient.hpp` | +113 | the `par_*` enumeration moves here; `n_theta` replaces `n_pars` |
| `vulnerability.hpp` | +76 | `weibull_b_from_P50`, `vulnerability_derivatives_at` |
| `closed_form_rows.hpp` | 73 | new |
| `clamp_sites.hpp` | 68 | new |

Read `clamp_sites.hpp` and `vulnerability.hpp` first (144 lines), then
`roots.hpp:357-383`, then `leaf_model.hpp:1199-1253` and `:2023-2082`.
`kernel_slope_at` at `:5573` is self-contained.

---

# Comment 2 — Mechanism

## What replaces recording the root-find

Recording the search returns the sensitivity of where those iterations stopped —
a function of the starting guess, the tolerance and the iteration count. It
converges as the tolerance tightens; at any finite tolerance the error belongs to
the solver's settings.

The implicit function theorem gives the model's derivative directly. With
`F(p*, θ) = 0` defining the point:

```
    dp*/dθ  =  −(∂F/∂p)⁻¹ ∂F/∂θ        at p*
```

Both partials are of the residual, a closed form. The remaining error is the
residual's distance from zero: 1.6 parts in a thousand million million.

The kind selects the residual, not the formula. Fiacco's statement needs no
branch:

```
    dΠ*/du  =  ∂Π̂/∂u|_p  −  Σⱼ μⱼ ∂cⱼ/∂u|_p
```

Every multiplier is zero at an interior optimum, collapsing to the envelope
theorem. At a bound the multiplier is the correction the envelope theorem omits.

## Classification comes from the branch, not the numbers

`dprofit_at_collar_psi` returns a literal `0.0` on its shutdown exit (`:4021`),
before setting the feasibility flag. A `|dprofit| ≈ 0 ⇒ interior` test reads a
shut leaf as stationary, and `marginal_collar_slope` differences that same
sentinel to a curvature of zero, so a second diagnostic confirms the first.

Twelve sites write the kind. `prepare_collar_solve` resets it to `Unsolved` so a
forgotten branch reports unclassified instead of the previous plant's answer, and
`test_operating_point_kind_is_written_by_every_path` (`test_leaf.cpp:816`) holds
all twelve.

## One walk for the draw

Soil layers are strictly parallel:

```
    E_i = (T_collar − psi_soil[i] − grav_head[i]) / r_R_i
```

Nothing couples them but the shared `T_collar`, so `dE_up/dT_collar` is a sum of
per-layer quotient-rule terms that falls out of the loop already accumulating the
draw. Forming it afterwards walks every layer again for numbers the first walk
had, and leaves two spellings that must agree bit for bit.

The collar inside `SupplyDraw` is stored passive whatever the caller hands in:
this is supply at a *point*, and where the point moves is the supplied row's
business. Taking it live records the search that placed it.

At a hydraulic shutdown there is no draw, and not because it would be zero. The
collar sits at the stem's critical potential, past where the uptake model
answers — the integral is exactly zero and `E_up` is not a number.

## `kernel_slope_at` supplies second derivatives

`kernel_slope_at` (`:5573`) returns a kernel's slope as a value, carrying rows
that are the kernel's mixed second partials.

```cpp
  using inner = odelia::ode::tangent_scalar<double>;     // both levels
  constexpr std::size_t n_dir = 1 + sizeof...(Args);     // sit at double
  using outer = typename xad::fwd<inner, n_dir>::active_type;
```

Direction `d` of argument `d` is seeded at the outer level. The inner level of
the first argument alone is seeded. One evaluation, then:

```
    slope   = derivative_along(value(y))          =  ∂K/∂x
    row[r]  = derivative_along(derivative(y)[r])  =  ∂²K/∂x ∂argᵣ
```

Nothing is recorded at either level, because both are `double`.
`record_with_derivatives` attaches the lot as one tape statement.

The alternative — an active scalar nested inside another — is a compile error in
odelia. `dA/dci` and `dC/dsigma` were once taken that way and cost 521 tape
statements against the 17 of the kernel they differentiate.

At `S == double` the outer level is skipped entirely. That path places every
operating point: 2.3 million of them in a century-scale stand run.

## The vulnerability curves

Value from a pre-integrated table, derivatives from the closed form. The value is
the table's because the solve ran on the table; the table's own slope is a
property of the fit, not the curve.

One implementation serves both curves. Written twice, one copy picks up the chain
rule through the shape parameter and the other keeps a partial at fixed scale.
The result is finite, plausible and wrong, and nothing in the output says so.

`single_potential` answers the same methods against one soil potential. Medlyn,
least-cost and Cowan–Farquhar are all formulated that way, so comparing them
under a multi-layer network compares two things at once.

---

# Comment 3 — Contract and failure modes

## A missing `for_each_active` costs four columns, silently

odelia's `visit_active` tries `for_each_active`, then container, then pointer,
then does nothing. `PhotoCapacity` is an input to the `ci` residual's
`implicit_value` (`:5760`):

```cpp
  template <class F>
  void for_each_active(F&& f) const {
    f(vcmax); f(transport); f(curvature); f(respiration);
  }
```

Without it the four photosynthetic rows never arrive. Four trait columns read
exact zero, every number stays finite, nothing is raised. `SupplyDraw` and
`leaf_pars` have the same exposure, which is why the warning sits at the
declaration.

## Claims to test

| claim | where |
|---|---|
| A point is classified by the exit taken, never the numbers | `:4021` returns a literal `0.0` before setting `feasible` |
| Every path out of the solve writes its own rates | `test_leaf.cpp:816`. The documented gap is `:2431` — `optimise()` on the stem route leaves `Unsolved`, so `collar_at` throws |
| Draw and collar are the same point | `check_draw`, `:1331`, an exact `!=` |
| One tape statement per attachment | `implicit_node.hpp:57` |
| A supplied row cannot be refereed by differencing its consumer | the block's forward value does not depend on a recorded input, so differencing returns identically zero on those columns whether the row is right, wrong or absent |

## Migration

`gradient::n_pars` is gone; `n_theta` (19) sizes theta and `phylloptim::n_pars`
(20) sizes the pack. Unqualified `n_pars` inside `namespace gradient` now
resolves to 20 and overruns.

`vulnerability_curve_ncontrol` 100 → 400 moves every caller's numbers.

Consumers call `supply_draw_at` → `collar_at` → `outputs_at`, pass
`marginal_collar_slope()` at `Interior`, branch on `operating_point_kind()`
rather than on returned values, and catch `std::runtime_error` from `check_draw`,
the shutdown refusal, and a failed row report.

---

# Comment 4 — Cost

The leaf's solve is about 360 tape statements. Recorded inline it contributes
those once per recording and once per seed swept — 1440 statement-walks per
solved leaf at three seeds. Supplied, it costs 24.

Not built: a fully analytic block supplying every row with nothing recorded. It
needs eight closed forms that do not exist — four mixed second partials of the
assimilation kernel, four of the cost — while the supply side's 187 statements
stay recorded either way, so the walk count falls to about 772 and not to 24.
Most of the prize is already taken.

The referee does not reach it either. The transpose identity covers four
operating-point kinds, and a forward tangent cannot help: it runs the same
supplied numbers through the same attachment, so a wrong row makes both routes
wrong identically.
