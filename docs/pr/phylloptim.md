# phylloptim

**Base** `traitecoevo/phylloptim:master` · **Head** `aornugent/phylloptim:ad/V4-reverse-tf24`
**Tag on merge** `v0.9.0` · **Needs** odelia `v0.5.0` tagged first

Two comments, posted in order.

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

# Comment 1 — What this is and what it changes

## Terms

**Row.** One output's derivatives against a list of inputs. A *supplied* row is
computed here and handed to the consumer's tape as data; the arithmetic that
produced it is never recorded. This is the whole point of the change, and the
word appears everywhere in the diff.

**Kind.** `OperatingPointKind` — which condition pinned the operating point. Six
values: four have derivatives, two do not. The kind is written by the branch the
solve exits through and is the only admissible way to tell them apart, for
reasons in comment 2.

**Draw.** `SupplyDraw<S>` — the water drawn from the soil at one collar
potential, carrying the per-layer split, the total flux and the collar
conductance. It records the collar it was taken at, so its parts cannot come from
different ones.

**The three scalars.** `Leaf<S>` instantiates at `double` for the forward solve,
`tangent_scalar<double>` for a directional derivative with no tape, and
`active_scalar<double>` for plant's reverse recording. One source serves all
three; the alternative was three copies that drift.

## The path a consumer walks

```
  prepare_collar_solve()              kind := Unsolved
        │
        ▼
  root-find over collar psi           plain double, off any tape
        │
        ├──► Interior                 stationarity of profit
        ├──► BoundaryWet              uptake balance                   ─┐ four
        ├──► BoundaryCrit             stem continuity at psi_crit       │ residuals,
        ├──► BoundaryRootCrit         the root's critical potential    ─┘ one formula
        │
        └──► HydraulicShutdown        marginal profit returns a literal 0.0
             ShadeDeath               no derivative exists; collar_at throws
        │
        ▼
  supply_draw_at(collar, supply)      one walk: per-layer uptake, total flux,
        │                             collar conductance
        ▼
  collar_at(draw, pars, curvature)    the implicit_value node
        │                             absent entirely at S == double
        ▼
  outputs_at(...)  ──►  LeafOutputs<S>{ profit, uptake[] }
```

A consumer must call these in order, pass `marginal_collar_slope()` at `Interior`
and nowhere else, and branch on `operating_point_kind()` and never on the
returned values. Three things throw rather than returning a sentinel:
`check_draw` when a draw and a collar disagree, `collar_coords_at` at a shutdown,
and `kernel_slope_at` when a row is not finite.

## What changes for existing code

`vulnerability_curve_ncontrol` moves from 100 to 400. The vulnerability curves
are read from a pre-integrated table and this is how finely that table is cut, so
every caller's numbers move whether or not they take a derivative. The R default
and the C++ constant are separate literals and nothing checks they agree.

`gradient::n_pars` is gone. The `par_*` enumeration now lives in `leaf_model.hpp`
and is re-exported; `n_theta` (19) sizes theta and `phylloptim::n_pars` (20)
sizes the parameter pack. An unqualified `n_pars` written inside `namespace
gradient` still compiles and now resolves to 20, overrunning a 19-long theta by
one, so that spelling needs auditing by hand.

The R signatures are unchanged and `NAMESPACE` gains nothing.

## Files

| file | lines | what |
|---|---|---|
| `leaf_model.hpp` | +1622 | `Leaf<S>`, `leaf_pars<S>`, `SupplyDraw`, `PhotoCapacity`, `LeafOutputs`, `OperatingPointKind` |
| `roots.hpp` | +443 | `SupplyAt`, `CollarConductance`, the merged uptake walk |
| `gradient.hpp` | +113 | the `par_*` enumeration moves here |
| `vulnerability.hpp` | +76 | `weibull_b_from_P50`, `vulnerability_derivatives_at` |
| `closed_form_rows.hpp` | 73 | new |
| `clamp_sites.hpp` | 68 | new |

Nothing is deleted. Read `clamp_sites.hpp` and `vulnerability.hpp` first — 144
lines between them and the rest leans on both. Then `roots.hpp:357-383` for the
two new types and `:811` for the walk that fills them. Then
`leaf_model.hpp:1199-1253` and `:2023-2082`, which is the derivative surface
proper. `kernel_slope_at` at `:5573` is self-contained and can be read at any
point; `closed_form_rows.hpp` reads better last.

---

# Comment 2 — How it works

## What replaces recording the root-find

The operating point is the root-collar water potential at which marginal carbon
gain equals marginal water cost, found by root-finding on the marginal-profit
function in plain `double`. That has not changed and is not differentiated.

What changed is the consumer's route to a derivative. Putting a trait on the tape
and running the root-find live gives a derivative back through every iteration —
the sensitivity of *where that particular sequence of iterations stopped*. It is
a function of the starting guess, the convergence tolerance and the iteration
count. It converges to the right answer as the tolerance tightens, but at any
finite tolerance it is not the right answer, and its error belongs to the
solver's settings rather than to the model.

The implicit function theorem gives the model's derivative directly. With the
point `p*` defined by `F(p*, θ) = 0` for traits `θ`, differentiating that identity
gives

```
    dp*/dθ  =  −(∂F/∂p)⁻¹ ∂F/∂θ        evaluated at p*
```

Both partials are of the residual, which is a closed form, so both are available
without recording anything the solver did. The remaining error is the residual's
own distance from zero, measured on this model at 1.6 parts in a thousand million
million of the answer.

The kind selects which residual, not which formula. Fiacco's statement covers all
four without a branch:

```
    dΠ*/du  =  ∂Π̂/∂u|_p  −  Σⱼ μⱼ ∂cⱼ/∂u|_p
```

At an interior optimum every multiplier `μⱼ` is zero and this collapses to the
envelope theorem — differentiate the objective holding the optimum fixed, which
is the omission the value path already makes. At a bound, the multiplier is
precisely the correction the envelope theorem does not give.

## Why classification cannot read the numbers

`dprofit_at_collar_psi` returns a literal `0.0` on its shutdown and
reversed-gradient exits (`:4021`), before setting the feasibility flag. A test of
the obvious form — marginal profit near zero implies an interior optimum — reads
a shut leaf as stationary.

The trap is that a second opinion confirms the first. `marginal_collar_slope`
forms a curvature by differencing, and differencing that same sentinel returns
zero, so a stationarity test built as residual-over-curvature and a curvature
check taken off the same value agree with each other and are both wrong.

So the kind is written by the branch the solve exited and never inferred
afterwards. Twelve sites write it. `prepare_collar_solve` resets it to `Unsolved`
at the start of every solve, so a branch that forgets reports "unclassified"
instead of the previous plant's answer, and
`test_operating_point_kind_is_written_by_every_path` (`test_leaf.cpp:816`) holds
all twelve to it. One gap is documented rather than fixed: `optimise()` on the
stem route leaves the kind `Unsolved` (`:2431`), so `collar_at` throws instead of
misreporting.

## Why the draw is a single walk

The soil layers are strictly parallel. Each contributes

```
    E_i = (T_collar − psi_soil[i] − grav_head[i]) / r_R_i
```

and nothing couples them except the shared scalar `T_collar`. So
`dE_up/dT_collar` is a plain sum of per-layer quotient-rule terms, and it falls
out of the same loop that is already accumulating the draw — every quantity it
needs is in hand at the moment each layer is visited.

Forming it afterwards means walking every layer again to produce numbers the
first walk already had, and leaves two pieces of code that must agree bit for bit
about a quantity neither of them owns. `roots.hpp:712` states the rule directly:
the collar response comes out of the same walk or not at all.

Two scalar choices inside `SupplyDraw` are deliberate and easy to misread. The
collar is stored **passive** whatever the caller hands in, because this is the
supply at a *point*; where the point itself moves is the supplied row's business,
and taking the collar live here would record the search that placed it. The
per-layer collar slopes are supplied at `double`, because each layer's draw
already carries its own rows and the only channel missing is the collar moving.

At a hydraulic shutdown there is no draw at all, and not because it would be
zero. The collar is held at the stem's critical potential, which is past where
the uptake model answers: the integral is exactly zero and `E_up` is not a
number. Asking costs a stop instead of a wrong row, and every consumer reads zero
at that kind anyway.

## `kernel_slope_at` supplies second derivatives

This one is easy to skim past. `kernel_slope_at` (`:5573`) returns a kernel's
*slope* as its value, carrying rows that are the kernel's *mixed second
partials*.

```cpp
  using inner = odelia::ode::tangent_scalar<double>;     // both levels
  constexpr std::size_t n_dir = 1 + sizeof...(Args);     // sit at double
  using outer = typename xad::fwd<inner, n_dir>::active_type;
```

Direction `d` of argument `d` is seeded to 1 at the outer level, giving `n_dir`
independent directions, one per argument. The inner level of the **first**
argument alone is then seeded, which is what turns the value into a slope. The
kernel is evaluated once, and:

```
    slope   = derivative_along(value(y))          =  ∂K/∂x
    row[r]  = derivative_along(derivative(y)[r])  =  ∂²K/∂x ∂argᵣ
```

One evaluation at `n_dir` directions yields a first derivative and every second
derivative needed to attach it, and because both tangent levels sit at `double`,
nothing reaches a tape at either level. `record_with_derivatives` then puts the
lot on the consumer's tape as a single statement.

The alternative is an active scalar nested inside another, which odelia refuses
at compile time. That prohibition is not theoretical here: `dA/dci` and
`dC/dsigma` were once taken that way and cost 521 tape statements against the 17
of the kernel they differentiate.

At `S == double` the outer level is skipped entirely and only the inner tangent
runs. That matters because the double path is the one that places every operating
point — 2.3 million of them in a century-scale stand run — and paying `n_dir`
directions there for rows nobody reads would be the dominant cost of the whole
model.

This is also why the kernels take the scalars they read instead of the
twenty-slot parameter pack: the cost of this function is `n_dir` times the
kernel's arithmetic, so `n_dir` has to stay small.

## A missing `for_each_active` costs four columns, silently

odelia's `visit_active` dispatches on `for_each_active`, then container, then
pointer — and falls off the end doing nothing for an aggregate that matches none
of them. `PhotoCapacity` is an input to the `ci` residual's `implicit_value`
(`:5760`):

```cpp
  template <class F>
  void for_each_active(F&& f) const {
    f(vcmax); f(transport); f(curvature); f(respiration);
  }
```

Remove that member and the four photosynthetic rows never arrive. Four trait
columns read exact zero, every number stays finite, and nothing is raised. The
same exposure applies to `SupplyDraw` and `leaf_pars`: adding a member to any of
the three without visiting it is a silently wrong answer, which is why the
warning sits at the declaration rather than at the call site.

## The vulnerability curves

Both curves take their value from a pre-integrated table and their derivatives
from the closed form. The split is deliberate. The value comes from the table
because the solve itself ran on the table, so using the closed form there would
answer about a curve the solve never saw. The table's own slope, meanwhile, is a
property of the fit and not of the curve, and the two differ.

One implementation serves both curves, because writing the derivative twice
invites a specific failure: one copy picks up the chain rule through the shape
parameter and the other keeps a partial at fixed scale. The result is finite,
plausible and wrong, and nothing in the output says so.

`single_potential` answers the same methods against a single soil water
potential. Medlyn, least-cost and Cowan–Farquhar are all formulated that way, so
comparing any of them against this model under a multi-layer root network
compares two things at once.

## What is deliberately not built

A fully analytic block — supplying every row with nothing recorded anywhere — is
available in principle and is not built, for two reasons that a future attempt
would meet again.

It needs eight closed forms that do not exist: four mixed second partials of the
assimilation kernel and four of the cost. Each is refereeable, but the supply
side's 187 statements stay recorded either way, so the walk count per solved leaf
falls from 1440 to about 772 and not to 24. Most of the prize is already taken.

And the referee does not reach it. The transpose identity covers four
operating-point kinds, and a forward tangent cannot fill the gap: it runs the same
supplied numbers through the same attachment, so a wrong row makes both routes
wrong in the same way. Coverage, not algebra, is the binding constraint.
