# The leaf's gradients

> **A description of what is there, not a plan.** Nothing here is outstanding work.
> It exists because the leaf is the one place in the tree where a derivative is
> *supplied* rather than recorded, and the reasons for that are spread across three
> packages. The opportunities are collected at the end and none of them is started.
>
> Symbols are named rather than cited by line, because half the `file:line`
> citations in this directory had rotted by the time anyone counted
> (`subtraction-targets.md` 25).

## 1. What the leaf decides, and why a gradient of it is wanted

A TF24 plant chooses how far to open its stomata. Opening them buys carbon and
spends water; the water is drawn up a hydraulic path that becomes exponentially
harder to pull through as it dries. The leaf model resolves that trade by
maximising

    profit(p) = A(p) - C(p)

over `p`, the water potential at the root collar (a positive magnitude, MPa). `A`
is colimited assimilation, `C` is the TF24 hydraulic cost

    C(psi) = cost_scale * (1 - f)^beta2,   f(psi) = exp(-(psi/stem_b)^stem_c)

where `f` is the fraction of stem conductivity surviving at that potential. At the
optimum `dA/dE = lambda`, the marginal carbon gain per unit water — the quantity
that unifies the stomatal optimality models and makes this one comparable to a
fitted Medlyn `g1`.

Two numbers come back out of that solve and both are consumed by the demography:

* **profit** feeds `net_mass_production_dt`, and from there every one of the six
  state rates plus `log_density_dt`.
* **per-layer uptake** is the water actually drawn from each soil layer, which
  closes the patch water balance.

The SCM's reverse pass wants d(census)/d(trait). Traits like `vcmax_25`, `b`, `c`,
`root_b`, `root_c` reach the census *only* through this solve. So the leaf's
derivative is not a refinement — it is the whole of those columns.

**The ecological reading of the arms matters here.** The solve does not always land
inside the feasible interval, and where it lands changes what the derivative *is*:

| arm | ecology | share of the golden grid |
|---|---|---|
| `Interior` | unconstrained optimum, `dprofit == 0` solved for | 198 of 288 at 25 °C; 160 at 40 °C |
| `PinnedWet` | soil wet enough that profit still climbs at the zero-uptake bound | 24 |
| `PinnedDryRootCrit` | pinned at the dry end, `min(root_crit, supply_psi_crit())` | 18 |
| `PinnedDryRootPsiCrit` | the dry end is the trait `root_psi_crit` itself | — |
| `HydraulicShutdown` | stomata shut, no water moves, no gross assimilation | 48 of 576 in the transpose fixture |
| `ShadeDeath` | `assim_max < 0`: respiration exceeds gross uptake | — |

At 40 °C the optimum moves onto the wet bound for a substantial minority of points.
A gradient scheme that only handled the interior case would be wrong on a fifth of
a warm stand, and wrong smoothly.

## 2. The boundary: where the leaf meets plant's tape

`plant` holds one persistent `phylloptim::Leaf` per `TF24_Strategy`, carried at
`double`. The strategy is templated on a scalar `S` that may be a tangent or an
adjoint. `TF24_Strategy<S>::record_leaf_outputs` is the seam.

The rule at that seam, stated in the source:

> Two of the leaf's outputs re-enter the active chain, and they reach the operating
> point differently. PROFIT is the objective at the point the leaf chose, so by the
> envelope theorem its response at an interior optimum is the direct one and the
> point's own movement drops out. PER-LAYER UPTAKE is set as a side effect AT that
> point, so it consumes the choice rather than being it and the movement is part of
> its answer.

So profit and uptake are **recorded**, not supplied: the strategy re-runs the leaf
composition (`supply_draw_at`, `collar_at`, `outputs_at`) at the active scalar and
the tape carries the arithmetic. `carry(...)` pins the *value* to the number the
`double` solve produced, while leaving the tape's derivative in place — the value is
the solve's, the slope is the composition's.

**Exactly one derivative crosses the boundary as a plain number:** `dM/dp`, the
slope of the condition that places an interior collar, computed by
`marginal_collar_slope`. It is handed to `odelia::implicit_value(y_star, dFdy, F)`,
which grafts a derivative onto a value:

    out = value + sum_i  dvalue/dinput_i * (input_i - to_passive(input_i))

Every bracket is exactly zero at the recording point, so the value is unchanged and
the tape learns the row. `implicit_value` refuses a non-finite or zero `dFdy` — that
is a fold, where the implicit function theorem does not apply — and `static_assert`s
that the residual declares its own return type, because a deduced one hands the
graft an expression template referencing dead temporaries.

## 3. Forward and reverse

The asymmetry is the reason the boundary looks the way it does, and it is worth
stating plainly because it is not a modelling choice.

**Forward mode (tangent) carries a direction in and a derivative out.** It composes
by nesting: a `tangent` over a `tangent` gives value, first and second derivatives
and a cross-term in one pass. Seed the collar in the inner layer and a trait in the
outer, and you read

    value().value()            profit
    value().derivative()       M = dprofit/dp
    derivative().value()       dprofit/dtrait at a held collar
    derivative().derivative()  dM/dtrait

all at once. Cost is one pass per input direction, so a full Jacobian costs
`n_in` passes.

**Reverse mode (adjoint) carries a weight back and accumulates over inputs.** One
sweep gives a whole row of `J^T v` regardless of how many inputs there are, which
is why the SCM uses it: 188 block inputs against 12 outputs. Cost is one recording
plus one sweep per output direction.

**Reverse cannot nest a tangent above its own scalar.** The tape records operations
on its scalar type; a tangent layered above it is not a type the tape can record
through. So `dM/dp` — which is a *second* derivative of profit, the slope of a
first derivative — cannot be obtained on the reverse path. Forward mode can nest,
so `dM/dp` is computed there, at `double`, and handed across as a number.

That single fact produces everything downstream:

* one supplied number instead of a taped second derivative;
* `implicit_value` as the mechanism to graft it;
* a class of error that no finite difference of the recorded step can see (§5).

The trade is deliberate and cheap. The alternative — taping the inner solve — would
record every iteration of a root-find, differentiate a convergence criterion, and
produce the derivative of a solver rather than of a model.

## 4. The math, arm by arm

Write `theta` for the traits, `p*` for the chosen collar, `M(p, theta) = dprofit/dp`.

**Interior.** `M(p*, theta) = 0` defines `p*` implicitly. By the envelope theorem,

    d(profit)/d(theta) = partial(profit)/partial(theta) |_{p*}

because `partial(profit)/partial(p) = 0` there. The collar's own movement drops
out, and profit needs no `dp*/dtheta`.

Uptake is a different object. `E_j = E_j(p*, theta)`, and it is not stationary in
`p`, so

    dE_j/d(theta) = partial(E_j)/partial(theta) + partial(E_j)/partial(p) * dp*/d(theta)

and the second term needs the point's movement. The implicit function theorem gives

    dp*/d(theta) = - (partial M/partial theta) / (partial M/partial p)

The denominator is the supplied number. The numerator is taped, because it is a
first derivative of `M` in a trait and forward mode is not required for it.

**The three bounds.** `p*` is not stationary; it *is* a bound, so the envelope
argument does not apply and profit needs the movement too. Each bound is its own
residual and gets its own IFT:

* `PinnedWet`: the residual is the draw's flux, `dF/dy = dflux_dx`.
* `PinnedDryRootCrit`: the residual is `T1` at `psi_crit`; `dF/dy = -kmax*f(x) - dflux_dx`.
* `PinnedDryRootPsiCrit`: `p* = root_psi_crit` exactly. **The bound is the trait.**
  There is no theorem to apply and none is applied: the row is the unit vector in
  `root_psi_crit` and zero elsewhere.

**HydraulicShutdown.** The collar does not move, `supply_draw_at` refuses to draw at
all, uptake and its derivative are identically zero, and profit is
`-R_d - C(psi_crit)`. The collar carries no rows. This is the one arm where holding
the collar passive is indistinguishable from letting it run — which
`test_transpose` now asserts rather than tolerates.

**ShadeDeath.** Uses the wet bound. Its consumptions are not zero; they *sum* to
zero, which is a different statement and matters to the water balance.

**The remaining six kinds throw.** `Determined`, `InfeasibleBracket`, `Prescribed`,
`SolverRefused`, `NonFiniteGradient`, `Unsolved` all raise from `collar_at`, and the
strategy's catch turns that into a refusal that nulls the whole row. A refusal is
not a zero, and the distinction is the reason the refusal channel exists.

## 5. Numerical representation

This is where the model stops being algebra and the choices get load-bearing.

### The vulnerability integral has a closed form and is not used

    G(m) = integral_0^m exp(-(s/b)^c) ds = (b/c) * gamma_lower(1/c, (m/b)^c)

Confirmed symbolically. Its derivatives are clean:

    dG/dm = exp(-(m/b)^c) = f(m)                    fundamental theorem
    dG/db = G/b - (m/b) * f(m)                      homogeneity, G = b*H(m/b)
    dG/dc = closed, but a 2F2 hypergeometric plus polygammas

The `dG/db` identity was checked numerically against a quadrature of the integrand
at `b = 3.9, c = 2.68, m = 5.0`: relative difference **1.6e-10**.

**Production evaluates `G` from a hermite quintic spline table**, seeded from the
closed form, using an in-house incomplete-gamma series rather than Boost's. The
value comes from the table and every slope comes from the curve, and the source is
emphatic about why:

> THE VALUE IS THE TABLE'S AND EVERY SLOPE IS THE CURVE'S. The solve ran on the
> table, so a value from the closed form would move the operating point; the
> table's own slope is a fit of the curve and differs from it by 1.15e-11, so a
> derivative taken from the table is a derivative of the fit.

This is the single most important sentence for anyone building a reference. **A
closed-form `G` is a different model** — it places the operating point somewhere
else. Any independent check must either accept a ~1e-11 floor or be handed the
production operating point.

`G^-1` (`psi_from_transpiration`) has **no closed form** and is a table both ways.
Polishing it breaks the analytic derivatives built on it: on a dry stand, 47 of 47
nodes refuse.

### One name, three functions

The per-layer mean conductivity switches on the width of the layer's potential
interval:

* span below `5e-3` and `lo > 0`: a 7-node Gauss-Legendre sum
* otherwise: a difference of two spline reads divided by the span
* **the active path uses a 1-node midpoint rule instead**, error ~4e-8 at the spans
  it fires below

So `duptake_dpsi` at `double` and `duptake_dpsi` at a tangent are not the same
function, by construction. That is a deliberate speed trade, and it bounds what any
cross-scalar comparison can claim.

### Three nested solves, three tolerances

| solve | for | tolerance | settable? |
|---|---|---|---|
| `find_root_psi` | the bounds `root_crit`, `root_zero_E` | **1e-4** | no, a literal |
| `psi_stem_to_ci` | internal CO2 at a given stem potential | **1e-10** | no, a literal |
| `maximise_profit_over_collar` | `p*` on `dprofit == 0` | `collar_root_tol` = 1e-12 | no, `static constexpr` |

⚠️ **`ci_abs_tol` is NOT the ci tolerance on this path.** It is a `Control` field
defaulting to 1e-3 and it reaches only the off-path `optimise_psi_stem_*` solvers,
so tightening it buys no precision on the production route and is a standing trap
for anyone trying to sharpen a reference. The number that matters is the hardcoded
1e-10 above, and phylloptim's guide records the cost curve that chose it: the knee,
landing 335× closer to a converged solve for +3.4% per solve.

The 1e-10 is described in-source as load-bearing: it sets the floor of what every
reported output of this model *means*. The 1e-4 is why a bound is worth about five
digits and why the bound checks in `test_leaf_gradient` are budgeted near 1e-5.

On the recorded path `psi_stem_to_ci` is replaced by `implicit_value` on the same
residual — the root-find runs once at `double` and the tape gets the IFT row.

### Three production properties, which are not verification gaps

Everything in §6 below is about what the suite can *demonstrate*. These three are
different: they are properties of the shipped model. None is a defect, all three
are deliberate and documented, and they bound what any check can ever claim — so
they belong here rather than in the list of things to fix.

**1. The differentiated model is very slightly not the derivative of the forward
model.** The per-layer mean conductivity uses a 7-node Gauss-Legendre sum at
`double` and a **1-node midpoint rule** on the active path, with an error of about
**4e-8** at the spans the rule fires below. That is a speed trade taken knowingly.
The consequence for verification is the important part: **no cross-scalar
comparison can be held tighter than ~4e-8** on any quantity that reaches a layer
mean, because the two sides are computing marginally different integrals. A check
that demanded 1e-10 there would be measuring the quadrature, not the derivative.

**2. The energy-balance path carries a finite difference inside an analytic
derivative.** `dprofit_energy_balance_term` obtains `dA/dT` by a central difference
at `h = 1e-3` K, and the source says it deliberately cannot be templated — adding
it inline would change FMA contraction on the gate-off path. Today
`use_energy_balance` is off on every TF24 path (`subtraction-targets.md` 22: plant
declares the gate and never wires it), so this is off the recorded route. **If that
gate is ever wired on the templated surface it becomes a recorded row with a
differenced core**, and whoever wires it owns that.

**3. The value of `G` is the table's, and that is correct.** The ~1.15e-11 gap
between the spline and the closed form is not an error to be driven out. The solve
ran on the table, so the table's value is the one the operating point sits at, and
a derivative taken around the closed form would be a derivative at a different
point. Any independent reference either accepts a ~1e-11 floor or takes the
operating point from production.

The first two are worth restating in one line: **the suite's achievable precision
is capped at ~4e-8 wherever a layer mean is involved, and the energy-balance path
has no analytic core to check against.** Neither is a reason to change the model.

### Sizes

The block a rate evaluation presents to the ladder:

    inputs  = 6 states + 130 light (65 knots x value+slope) + 5 psi_soil + 47 traits = 188
    outputs = 6 rates + log_density_dt + 5 uptake                                    =  12

The leaf touches **all 12 output rows** — profit fans into all six rates and
`log_density_dt`, and the five uptakes are outputs directly. Of the inputs, the
~12–14 leaf-own trait columns are the ones nothing but a rebuild can check.

## 6. What checks this today, and what each is blind to

| instrument | what it compares | collar | blind to |
|---|---|---|---|
| `test_leaf_gradient` (phylloptim) | leaf outputs against a **rebuilt model**, differenced | **held** | the interior condition; anything about `p*`'s movement |
| `test_leaf_gradient`, bounds section | each bound against a difference of the bound's own solve | n/a | ~5 digits only, because a bound is found to 1e-4 |
| `test_transpose` (phylloptim) | `<v, Ju>` against `<J^T v, u>` | **live** | a `J` wrong in both directions the same way |
| ladder block difference (plant) | forward tangent against reverse sweep | live | **identically zero on supplied-row columns** |
| `ladder_rate_difference_rebuilt` (plant) | rebuilt strategy, differenced | live | held to **1e-2** — the solve tolerance appearing twice |
| captured reference (plant) | a whole-run difference over five regimes | live | coarse; one number per column per regime |

**The blind spot is structural, and the codebase states it exactly:**

> A finite difference of the recorded step cannot referee a supplied row. The
> recorded expression is the value plus a sum of partials times brackets that are
> each exactly zero, so the block's forward value does not depend on a recorded
> input at all: differencing the block returns identically zero on exactly the
> columns a supplied row occupies, **whether the row is right, wrong, or absent.**

So the escape today is `ladder_rate_difference_rebuilt` — rebuild the strategy so
`prepare_strategy` reconstructs the leaf with the moved trait, and difference the
rates. Both sides then difference a re-solved operating point, which is why it is
held to 1e-2 rather than the 3e-06 the prepared-strategy columns reach. The source
names the fix:

> tightening it needs the analytic route rather than a better step.

**Both supplied numbers now have an instrument**, `test_supplied_rows`, added after
this note was first written. It differences the function each row claims to
describe, at two step sizes, and runs with the suite:

| row | reference | measured |
|---|---|---|
| `duptake_dp[j]` | `supply_draw_at`'s own uptake, re-evaluated at a moved collar. Reads none of the derivative code | 110 rows, worst **1.75e-07**, typically 1e-12 to 1e-10 |
| `marginal_collar_slope` | `marginal_assembled` stepped along the direction the row is taken in | 24 rows, worst **4.92e-10** |

⚠️ **`dM/dp` is a DIRECTIONAL derivative and differencing the collar alone is a
broken reference.** `marginal_collar_slope` seeds five coordinates at once — `p` by
1, `sigma` by `V`, `ci` by `dci_dpsi`, `dEup_dp` by `d2Eup`, `transpiration` by
`dEup` — so it is a derivative along a curve, not a partial. A first attempt here
moved only the collar and disagreed by 40 to 100 per cent, which reads as a broken
row and was a broken check. The five move together or the reference is measuring a
different function.

**What the second row's check does and does not cover.** Stepping along the
supplied direction checks the *assembly's* differentiation; it takes the four chain
rates as given. `dEup` is the sum of the uptake rows, so it is covered by the first
check. `V`, `dci_dpsi` and `d2Eup` are not — they remain the residue, and are what
a symbolic block would still buy.

**One state is reported every run.** The driest single-layer fixture — `psi_soil`
within 1% of `root_psi_crit`, on the 5% conductivity tail — reaches 1.75e-07 with
both step sizes agreeing, so it is a systematic offset near a branch rather than
noise. It is printed rather than absorbed, and the check fails above 1e-6: three
orders below the ~1e-4 the phylloptim guide calls a real difference, five above the
~1e-9 solver floor.

The two probes that once covered the collar row, `probe_marginal_tangent` and
`probe_bound_tangent`, were deleted with the row layer; they were nested tangents
over `profit_at`, so they shared the production assembly and were never independent
either.

## 7. The symbolic block

The opportunity: an independently derived, closed-form `J^T` for the leaf, used as
a reference that shares no arithmetic with the production gradient.

### What is verified tractable

Every special function needed is already on the include path — `vulnerability.hpp`
includes `boost/math/special_functions/digamma.hpp` today, and `gamma.hpp`,
`polygamma.hpp` and `hypergeometric_pFq.hpp` sit beside it.

* `G`, `dG/dm`, `dG/db` in closed form as above. **Production uses its own
  incomplete-gamma series and deliberately not Boost's**, so a Boost-based
  reference is genuinely independent and would referee that series too.
* `dG/dc` either from the 2F2 form or, more cheaply, by differentiating under the
  integral sign — `df/dc` is elementary — and quadraturing to high precision.
* Colimited assimilation: the quadratic-formula `colimit_kernel`, with an analytic
  slope beside it.
* The TF24 hydraulic cost and its slope, both one line over the curve's own slope.
* The two residuals `T1`/`T2` and their IFT quotients: `marginal_assembled` is
  about 25 lines of arithmetic that can be transcribed independently.
* The three bound conditions, which are `E_up = 0`, `T1` at `psi_crit`, and an
  identity.

### What it must concede

It **cannot place the operating point.** Three nested root-finds at three
tolerances produce `p*`, `sigma*`, `ci*`, and the arm; the reference has to be
handed all of them. That is the same concession `implicit_value` already makes, so
it is legitimate — but it means the block checks *the rows at a given point*, not
the point.

It must also reproduce **branch selection**, not just branch algebra. The arm is
decided by `f_lo`/`f_hi` — themselves values of the noisy `dprofit_at_collar_psi` —
at endpoints that are the bounds plus a feasibility step measured at 5.4e-07. And
`ci_at_compensation_point_` silently voids the `T2` IFT, so it is a branch too.

### What it cannot referee, and should not try

* the spline-versus-closed-form value gap (~1.15e-11), which is a deliberate
  property of the model, not an error;
* the layer-mean threshold crossing at span `5e-3`, and the 1-node/7-node
  double-versus-active split;
* the equal-potentials 0/0 lift;
* the energy-balance path, whose `dA/dT` is a central difference at `h = 1e-3` K
  and cannot be templated.

Those stay with `probe_layer_mean`, `probe_coincidence` and `probe_curve_tables` —
which, it is worth noting, nothing builds.

### What it would be worth

A reference of this shape would referee the supplied slope, the trait rows of both
curves, the bound conditions and the whole arm map, at a floor of roughly **1e-11**
against the **1e-2** the rebuild reference manages on those columns. Nine orders,
on the twelve to fourteen columns that no other instrument can see at all.

Estimated at two to four days, most of it in the branch map rather than the algebra.

## 8. Opportunities, ranked

1. **Re-bless `golden/operating_points.tsv`.** The phylloptim C++ suite is red on
   Linux — 223 mismatches over 576 operating points — against two deliberate
   refinements. It must be regenerated on macOS/arm64, where it was made. Until
   then every other signal in that suite arrives in an already-failing run.
2. **Build the probes, or delete them.** Twelve `probe_*.cpp` remain in
   `phylloptim/tests/cpp`, cited in `one-order.md` and `measurements.md` as
   measurements and built by nothing. At least `probe_layer_mean`,
   `probe_coincidence` and `probe_curve_tables` cover gaps §7 says a symbolic block
   cannot. `probe_transpose` was the thirteenth and is now `test_transpose`, which
   is the shape the useful ones should take.
3. **The symbolic block**, scoped as §7 describes: handed the operating point,
   refereeing the rows and the arm map, explicitly not the point or the table gap.
4. **`dprofit_droot_collar_psi`'s energy-balance term.** A finite difference at
   `h = 1e-3` K inside an otherwise analytic derivative, on a path that is off the
   recorded route today but is TF24f's acclimation rate. If the gate is ever wired
   on the templated surface, this becomes a recorded row with a differenced core.
5. **The `1e-4` bound tolerance.** It sets a five-digit ceiling on every bound
   check and on the arm selection that reads `f_lo`/`f_hi`. Whether it can be
   tightened without destabilising the coupled soil-water ODE is an open question
   that `uniroot.hpp`'s own history note half-answers.

---

## Cross-references

* [`one-order.md`](one-order.md) — the leaf's derivative boundary as a completed
  cut: seven kinds of derivative became four. The record of how this shape arrived.
* [`subtraction-targets.md`](subtraction-targets.md) 25 — the test-suite audit,
  including the instruments above and which of them run.
* `phylloptim/PLAN.md` — items 11a (root-finding the first-order condition) and
  11b, which are the arguments for the current collar solve.
