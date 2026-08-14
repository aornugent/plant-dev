# The leaf's supplied rows: where their cost is, and what removes it

After the inflow boundary's rebind stopped rating every cohort, one function is
the reverse pass. `TF24_Strategy::record_leaf_outputs` builds the leaf's supplied
derivatives once per cohort per stage, and it is **86 per cent of what is left**.

This is what it spends, what the corpus already says about each part, and which
parts are removable.

---

## 1. Start here

**The state.** A census gradient on 88 cohorts runs in 378 s against 753 s
before, from two changes that are each bit-identical — `deda52f5` (a rebound
patch builds its boundary node, not every cohort's rates) and `c5e3a5f9` (the
two critical potentials stop being driven). Since then dark respiration has
gained a parameter and a row (`d6a51304`), also with every prior column
bit-identical. What is left is one function, and §2 measures it.

**What is left is four traits, not the whole loop.** A vulnerability-curve
drive costs 92–97 µs and every other trait's costs 2.3, so `b`, `c`, `root_b`
and `root_c` are most of the remaining block. Half of them can be made free by
an identity that already exists upstream; the other half cannot. §4 has the
measurements and §9 the order.

**What to read, and nothing else.** The corpus is large and almost none of it
bears on this.

| question | read |
|---|---|
| what a supplied row is, and what the boundary must guarantee | report 02 §3, §4 |
| why the leaf is entered passively at a solved point | report 02 §1 |
| the rank-two factorisation this work extends | report 05 §7.3, and report 08 §4.1 for its check |
| the tabulation rule that governs the vulnerability rows | report 02 §5, report 05 §7.6 |
| which traits have rows, and the domain a number carries | report 06 §11 |
| the per-cohort decomposition — **confirmed not the cost, do not redesign it** | report 01 |

**The build, and the one trap in it.**

```sh
cd plant
MAKEFLAGS=-j$(nproc) R_MAKEVARS_USER=<Makevars-O2> \
  Rscript -e 'pkgbuild::compile_dll(".", debug = FALSE)'
```

with `Makevars-O2` holding `CXX20FLAGS = -O2 -DNDEBUG -g0`. `compile_dll`
defaults to `-O0`, and `MAKEFLAGS` is empty by default so it builds one
translation unit at a time — a header edit is 25 of them.

⚠️ **`compile_dll` does not treat the INSTALLED phylloptim headers as
dependencies.** After changing phylloptim you must reinstall it *and* force
plant's translation units to rebuild; otherwise nothing recompiles and every
check you run afterwards passes against the old binary. This cost a full
verification cycle and produced a result that had to be withdrawn. Confirm a
rebuild happened before believing any comparison.

Load with `library(odelia)` — never `load_all` — then `pkgload::load_all("plant")`.

**How to verify a change here.** Every change in §9 replaces a differenced
quantity with an analytic one, so the acceptance test is the differenced value
it replaces, at wet, dry and shaded states. That reference exists today and
**stops existing the moment the differencing is deleted**, so capture it first.

The two changes already landed were held to a stronger test, and anything
claiming to be a pure cost removal should be too: gradients **bit-identical**
on `ladder_stand_two_by_two()`, `ladder_stand_introductions()` and an 88-cohort
production stand. Not "within tolerance" — `max abs diff 0.000e+00`. A
tolerance widened around a disagreement is how the defect in
`docs/issue-B-root-cause.md` §6 survived for months.

**The instruments, both already committed.** `ladder_rhs_adjoint_timing_tf24`
times the eight components of one right-hand-side adjoint in situ and reports
whether the parts sum to the whole; `ladder_block_copy_cost_tf24` separates a
block's preamble from its recorded arithmetic. Between them they are how §2's
table was measured, and a per-block cost obtained by dividing a total instead
is attributed by construction rather than measured.

**Two habits worth keeping.** Attribute before optimising — three hypotheses
died here (the tape, the per-block copies, the reduction transposes) before
instrumenting the boundaries settled it. And check a claim against the code
before acting on it: §4's recommendation was reversed once, because a function
that looked unused turned out to be deliberately unwired.

---

## 2. What a call costs

Measured on a single species, `ladder_traits()$fast`, birth rate 1.10, schedule
refined once at a five-year lifetime (88 cohorts), `-O2 -DNDEBUG -g0`.

| | per RHS adjoint |
|---|---|
| `cohort_blocks`, 89 blocks | 108.76 ms |
| `boundary_condition_adjoint` | 17.75 ms |
| everything else | 0.30 ms |

One block is **1.23 ms**, against **0.018 ms** for the same cohort's rates in
plain double — **68 times**. Of that block, the AD machinery is 0.6 per cent:
taping, the sweep, registering 185 inputs and copying the active strategy and
environment together cost 0.007 ms. `record_leaf_outputs` is the rest, and it
runs only at an active scalar.

**So the reverse pass is not paying for reverse mode.** It is paying for a
hand-built Jacobian of the leaf, and the tape is a rounding error beside it.

---

## 3. Where the drives go

The call re-drives the leaf about **forty-six** times, in six families the
corpus treats very differently. That count and the table below are as measured,
*before* `c5e3a5f9` removed four of them and `d6a51304` added two; forty-four
remain. **The drive counts here are not the cost**, because the families differ
by a factor of forty per drive — §4's table is what to price against.

| family | directions | drives | how the row is obtained |
|---|---|---|---|
| **leaf traits** | **14** | **20** | central differences, one trait at a time. Of the fourteen, two carry no row (`vcmax_25`, `jmax_25`) and two are declared zero, so ten are driven — and four of those ten cost forty times the rest |
| root carbon | `L` | 10 | central differences, per layer |
| soil potential | `L` | **0** | the rank-two factorisation |
| conductance | 1 | 2 | central difference |
| radiation | 1 | 2 | central difference |
| curvature | — | 2 | central difference of the marginal profit |
| fitting the pair | 2 | 4 | one potential, one layer resistance |

The soil-potential family is already free:

```cpp
dcollar_dpsi[j] = -(a * dEup_dpsi[j] + b * d2Eup_dcollar_dpsi[j]) / curvature;
```

Five directions, no drives, because report 05 §7.3's factorisation supplies them
from two scalars that two drives already fixed. **It is the only family that
takes that route**, and the two largest families do not.

**The root-carbon family is in the same span and does not use it.** Report 05
§7.3 states the factorisation over `2L+1` state directions — the `L` soil
potentials, the `L` per-layer root masses, and leaf area — and report 08 §4.1
records the check that matters: the pair solved from two directions of
*different families* predicts the remaining nine to a worst `2.4e-05`,
round-off limited. The root masses are inside the verified span. They are
nonetheless differenced, one layer at a time, and that is half of every drive
this function makes.

---

## 4. The root cause, in one sentence

**The leaf's kernels are generic in the variable and concrete in the trait**, so
the leaf can differentiate itself with respect to what it *solves for* and never
with respect to what it *holds*.

```cpp
template <typename T> T assim_rubisco_limited_kernel(T ci) const {
  return (vcmax_ * (ci - gamma_ * umol_per_mol_to_Pa_)) / (ci + km_);
}
template <typename T> T proportion_of_conductivity_kernel(T psi) const {
  return exp(-pow((psi / stem_b), stem_c));
}
```

`T` is the argument. `vcmax_`, `stem_b`, `stem_c` are `double` members. Forward
mode through these yields `dprofit/dpsi` and `d/dci` -- exactly the state
directions the collar solve needs, which is why the leaf already differentiates
itself there and why `dprofit_droot_collar_psi` is exact. It cannot yield
`d/dvcmax` or `d/db` by any amount of forward mode, because the trait is not on
the scalar. **So every trait row has to be obtained by moving a member and
re-solving, and that is the whole of the cost.**

Report 02 §1 is often read as forbidding this. It does not. What it rejects is an
**active leaf** -- "it holds interpolators on fixed grids, loose parameters and
per-solve scratch with no boundary between them, caches keyed on exact
comparison, an integrator and a nested root-find. Each is a separate correctness
question under an active scalar." Every one of those objections is about the
*solver*. None of them is about a three-line pure kernel. And report 02 §4 item 1
sanctions the remedy by name: the solver "may differentiate itself internally by
any means it likes -- **forward-mode on its own kernels**, analytic spline
derivatives, the implicit function theorem at an inner root-find".

**The kernels are the "own kernels".** They contain no interpolator, no cache, no
root-find and no integrator; they are the one part of the leaf where an active
scalar raises no correctness question at all.

### And two of the three trait families need no new derivation whatsoever

| family | traits | the exact route, and where it already is |
|---|---|---|
| photosynthesis and cost | `a`, both `curv_fact_*`, `beta2`, `g1_TF24` — **five, not seven**: `vcmax_25` and `jmax_25` are carried but not differentiable, so they cost no drives and are a completeness item instead (§9) | forward mode on the kernels, once they carry the trait scalar. The `ci` chain is already available: the implicit-function term on the `ci` residual is what `dprofit_at_collar_psi` already uses |
| vulnerability | `c`, `b`, `root_c`, `root_b` | **not the closed form, and a live defect in what is there** -- see below |
| critical potentials | `psi_crit`, `root_psi_crit` | **provably zero here — done, `c5e3a5f9`.** Report 06 §11: they set the dry bound of an interval the operating point is inside, so complementary slackness makes their rows zero at an interior optimum, and interior is the only state the sweep answers |

The third row was the sharpest: four drives per cohort per stage spent measuring
two numbers the corpus proves are zero in the only regime the gradient is scoped
to. That one is done (`c5e3a5f9`), and the row is declared rather than absent.

### The vulnerability row, corrected

An earlier revision of this document said the closed-form derivatives were
implemented and unused, and recommended wiring them. **That was wrong, and
wiring them would introduce the defect report 02 §5 exists to prevent.**

The root supply path does not evaluate the closed form. It evaluates a spline
whose knots are *samples* of it, capped at the closed form's limit:

```cpp
double root_vuln_integral_at(double psi) const {
  return std::min(root_vuln_integral_from_psi.eval(psi),   // a spline
                  root_vuln_integral_limit_);              // the closed form, as a cap
}
```

with `y_integral.push_back(cumulative_vulnerability_integral_at(psi, b, c))`
building the knots. So report 02 §5's ruling applies exactly as written: the
derivative belonging on the tape is the **spline's**, and substituting the closed
form's is the more accurate derivative of a different function. phylloptim says
so at the definition — *"this is deliberately not wired into anything that reads
a spline"* — and that sentence is the design, not an omission.

**The grid moves with a curve trait, and that is a defect for two of the four and
the opposite of one for the other two.** `set_traits` rebuilds the curve when a
curve trait moves:

```cpp
if (stem_curve_moved) setup_transpiration(vulnerability_curve_ncontrol);
if (root_curve_moved) setup_root_vulnerability(vulnerability_curve_ncontrol);
```

and the grid is laid out as `psi_max = vulnerability_psi_max(b, c)` with
`step = psi_max / resolution`, so the knot positions move with `b` and with `c`.
An earlier revision of this document read that as one defect across all four
rows. **It is not, and the difference decides what to build.**

**For `b` and `root_b` the moving grid is what makes the row exact.** Because
every knot position is proportional to `b`, the family of splines indexed by `b`
is exactly self-similar:

    G(psi; s*b, c) = s * G(psi/s; b, c)

which holds for the **spline** and not merely for the integral it approximates,
*because* the grid scales too. So there is no spurious approximation-error term
in `b` at all, and the row can be taken without rebuilding anything — move the
scale and read the same spline at a rescaled argument. Upstream has this as
`perturb_stem_b`, measured against a rebuild at 0–3e-16. Measured here against
a rebuild of the quantities plant actually reads — profit, the marginal profit,
per-layer uptake — the two rows agree to **3.9e-13** at the `1e-3` step this
call uses, and the jitter between neighbouring steps is identical, so the two
routes are the same row.

**For `c` and `root_c` there is no such identity**, the grid moves in shape
rather than scale, and the spurious term is real. Report 05 §7.6 named it:

> the grid must be captured once and held across parameter perturbations so that
> a differenced derivative is not differentiating a moving grid.

**It is now measured, and it is small.** Holding the knot positions and reseeding
the values at the perturbed `c` moves `dprofit/dstem_c` by **9.6e-06 relative**,
systematically, at every step from `1e-2` down to `1e-6`. That is three orders
below the `3.5e-3` at which substituting the closed form disagrees with the
spline, and far below the step's own truncation. So the row is contaminated, the
contamination is a bias rather than noise, and **it is not big enough to justify
a change on correctness grounds** — which is the answer to the question the
previous revision left open.

**What is not small is the cost, and it is the whole of what remains.** Measured
per perturbed evaluation at an interior point:

| family | µs per drive |
|---|---|
| `b`, `c`, `root_b`, `root_c` | **92–97** |
| `beta2`, `a`, both `curv_fact_*`, `g1_TF24`, `vcmax_25` | **2.3** |
| `b` by the homogeneity rescale | **2.0** |

A curve trait's drive is **forty times** a non-curve trait's, because it reseeds
101 incomplete gammas and rebuilds two interpolators. Eight such drives per
cohort per stage is about **760 µs against a measured block of 1230**, so the
four vulnerability traits are most of the block and the photosynthesis family is
about two per cent of it. **The previous revision had this backwards**, ranking
the vulnerability rows as a correctness item that "buys no speed" and the
photosynthesis rows as the cost win.

Two routes follow, and only the first is cheap:

- **Take `b` and `root_b` by the rescale.** Exact, verified against the rebuild,
  and it removes half the curve drives. `perturb_stem_b` exists; the root curve
  needs the same accessor, and the identity is the same one.
- **`c` and `root_c` have no identity and must rebuild.** Retiring the spline for
  the closed form is report 05 §7.6's own prescription and would cover them, but
  it is a forward-model change with a re-blessing rather than a wiring job — and
  upstream built exactly that, measured it disagreeing with the spline by
  `3.5e-3`, and rejected it for report 02 §5's reason.

---

## 5. The root-carbon family, and the one accessor it is missing

Not an oversight in the arithmetic: the supply side has no accessor for the
direction. `roots.hpp` exposes analytic derivatives of uptake with respect to
the **collar** (`duptake_dpsi`, `duptake_dpsi_by_layer`) and with respect to
**soil potential** (`dr_R_dpsi`), and none with respect to a resistance or the
root carbon behind it. Differencing is what is available.

What the factorisation needs for a root-carbon direction is two quantities,
both supply-side:

    dE_up/dr_a            and            d/dr_a ( dE_up/dp )

and both are elementary. Flux through a layer is a quotient,

    E_i = (p - psi_i - g_i) / r_R,i          so      dE_i/dr_R,i = -E_i / r_R,i

and the chain from carbon to resistance is the architecture model's own, which
report 02 §3.3 already characterises: a resistance network is homogeneous of
degree −1 in the root carbon it is built from. Read off `root_network_from_carbon`,

    r_R_H_min[i] = beta_R_H / (rc_i * 2/3)        proportional to 1 / rc_i
    r_R_V[i]     = beta_R_V * dz^2 / (rc_i / 3)   proportional to 1 / rc_i
    r_R_V_sum[i] = sum of r_R_V over layers 0..i

so each partial is the resistance itself over the carbon, with a sign.

**The block is lower-triangular rather than diagonal**, and the vertical sum is
why: water leaving layer `i` travels up through every shallower layer, so
`r_R_V_sum` is cumulative and layer `a`'s carbon reaches every `i >= a`. Only
the horizontal term is diagonal. An implementation that assumes diagonality
gets the shallow layers right and loses the deep ones, which on a drying profile
is the half that carries the flux.

The two quantities the *other* rows in this family need are reachable by the
same chain, and one of them collapses to a scalar already in hand.

**The profit row is free.** At a frozen collar, profit sees root carbon only
through total uptake and thence the stem potential:

    dPi/dr_a = (dPi/dpsi_stem) * (dpsi_stem/dE_up) * (dE_up/dr_a)

Since `sigma = P(E_up/kappa + S_t)`, the middle factor is `P'/kappa`, so the
first two multiply to exactly the product report 05 §7.3 gives in closed form as
`b = -(dPi/dpsi_stem) * P'/kappa`. Hence

    dPi/dr_a  =  -b * dE_up/dr_a

with `b` already fitted from the two directions the call takes anyway. **No
evaluation, no derivation.**

**The frozen per-layer row is the quotient above**, `-E_i/r_R,i` times the
resistance partial, summed over `i` to give `dE_up/dr_a`.

**One term is left and it is the only real work: `d/dr_a (dE_up/dp)`**, the
mixed partial the factorisation's second scalar multiplies. Writing a layer's
resistance as

    r_R,i = A_i * f_i(p) + B_i        A_i = r_R_H_min[i],  B_i = r_R_V_sum[i]

with `f_i(p) = span_i / integral_i`, both `A_i` and `B_i` carry the whole of the
carbon dependence and `f_i` carries the whole of the collar dependence. So
`dE_i/dp` is an elementary function of `(A_i, B_i, f_i, f_i')`, and the mixed
partial follows by differentiating it in `A_i` and `B_i` — two scalars per layer
— and chaining through the two partials above. It is a quotient rule, not a new
model.

**A cheaper intermediate exists and is worth naming**, because it needs no
derivation and is exact to differencing accuracy on a smooth function: difference
`duptake_dpsi_by_layer` itself, rebuilding only the network. That is arithmetic —
no collar solve, no `ci` root-find, no profit evaluation — against a full leaf
re-drive, so it keeps a difference but moves it off the expensive object. It is
the right first step if the mixed partial's derivation is not wanted immediately.

### The derivation, in full, so it does not have to be done twice

Read off `duptake_dpsi_impl`, which is the one loop both public forms use. Per
rooted layer `i`, with `num_i = T - psi_i - grav_i`:

    A_i = r_R_H_min[i]        f_i = span_i / integral_i        B_i = r_R_V_sum[i]
    r_i = A_i * f_i + B_i     E_i = num_i / r_i
    D_i = dE_i/dT = (r_i - num_i * A_i * g_i) / r_i^2        g_i = df_i/dT

`A_i` and `B_i` carry the whole of the carbon dependence; `f_i` and `g_i` carry
the whole of the collar dependence. That separation is what makes the rest
mechanical, and it is verified in the loop rather than assumed: `span`,
`integral` and `dinteg_dT` read the collar, the layer's potential and the root
vulnerability curve, and none of them reads the carbon.

**The sharpest consequence is why these rows cannot be recovered from the collar
rows.** In the collar derivative `dr_i/dT` reduces to `A_i * g_i` exactly, because
`B_i` is the cumulative vertical resistance and has no collar dependence at all --
the vertical term drops out. The carbon direction reaches **both** `A_i` and
`B_i`. So the collar column, however exactly it is known, carries no information
about the vertical half of the network, and that half is the cumulative one that
makes the block lower-triangular. A design that tried to get the carbon rows by
scaling the collar rows would recover the horizontal term and silently lose the
vertical.

**The carbon partials of the two resistances.** Both are proportional to
`1/rc`, and the vertical one is summed over layers at or above `i`:

    dA_i/drc_a = -(A_i / rc_a) * [i == a]
    dB_i/drc_a = -(r_R_V[a] / rc_a) * [a <= i]

`r_R_V[a]` is the per-layer vertical resistance, which the network already
stores beside its cumulative sum. **This is where the lower-triangularity comes
from**, and it is the only part of the block that is not diagonal.

**The resistance and flux partials follow by the quotient rule:**

    dr_i/drc_a = f_i * dA_i/drc_a + dB_i/drc_a
    dE_i/drc_a = -(E_i / r_i) * dr_i/drc_a

**And the mixed partial, by differentiating `D_i` in its two carbon-bearing
scalars:**

    dD_i/dA = [ (f_i - num_i * g_i) * r_i - 2 * f_i * (r_i - num_i * A_i * g_i) ] / r_i^3
    dD_i/dB = [ -r_i + 2 * num_i * A_i * g_i ] / r_i^3
    dD_i/drc_a = dD_i/dA * dA_i/drc_a + dD_i/dB * dB_i/drc_a

Summing `dE_i/drc_a` and `dD_i/drc_a` over `i` gives the two quantities the
factorisation multiplies, and the profit row is `-b` times the first. Nothing
here needs a leaf evaluation.

**Three implementation obligations, none optional.** The loop must keep
`duptake_dpsi`'s kink contract — NaN where the general branch does not hold, so
a caller falls back rather than reading a number the branch cannot supply.
Internal work is in mol and the public form multiplies by `kg_per_mol_h2o`, and
these rows feed a value already in mol, so the conversion has to be applied at
the same place the existing accessors apply it. And a layer with zero carbon has
no resistance and must contribute nothing rather than divide by its carbon.

**The acceptance test is unusually good and should be the whole of it:** the
analytic rows must reproduce the differenced ones they replace, at wet, dry and
shaded states, to the accuracy of the difference. That comparison is available
today, because the differenced version is what is running.

---

## 6. The largest family is also a second copy of phylloptim's gradient module

Twenty-six of the forty-six drives move one leaf trait at a time. The code says
what it is doing and why:

> *The leaf's own traits. It holds them, so the only route to their rows is to
> move one and re-solve: two evaluations each, which is what phylloptim's own
> gradient module pays, and for its reason — these have no closed form.*

The reasoning is right and the conclusion no longer follows, because that module
is now a thing this side can call. Every one of the thirteen is in its parameter
list, and the list is wider than the thirteen:

| this side | `phylloptim::gradient::par_names()` |
|---|---|
| `vcmax_25`, `c`, `b`, `psi_crit`, `root_c`, `root_b`, `root_psi_crit`, `beta2`, `jmax_25`, `a`, both `curv_fact_*`, `g1_TF24` | the same thirteen, as `stem_c`/`stem_b`/`cost_scale_TF24` |
| the conductance direction, differenced | `leaf_specific_conductance_max` |
| the root-carbon directions, differenced per layer | `resistance` |
| — | `R_d_25` |

So about thirty-eight of the drives are re-deriving what one upstream call
produces, and it produces them better:

- **one `prepare_collar_solve` for the whole composite**, where this side pays
  two root-finds per drive (§7);
- **selective rebuild** — `apply(l, th, d, single, p, fast_stem_curve)` is told
  *which* parameter moved, and `takes_shortcut` skips the stem curve for the one
  that does not need it. This side's `drive` lambda passes no such hint, so every
  drive re-seats the whole physiology;
- **`M` and `H` returned rather than consumed**, which is report 05 §7.2's
  `Pi_pu` and `Pi_pp`. This side differences the curvature separately, and its
  own comment on `Result` names `traitecoevo/plant#614` as the consumer, so the
  two sides were already designed toward each other.

**What blocks a straight substitution is the output set, and report 02 §3.0
already named this exact hazard.** Upstream differentiates five outputs — `A`,
`gc`, `psi_stem`, `collar`, `profit` — which is what a gas-exchange calibration
observes plus the one thing plant bills. A stand adjoint needs the sixth,
per-layer uptake, and upstream says why it is absent: *"`uptake` is one R sums
over the finite soil layers, so adding it means reproducing that summation — and
its order — on this side too."* That is report 02 §3.0's two consumers wanting
different output sets, overlapping in exactly one entry, arrived at
independently from the other side.

The composition is nonetheless nearly complete, because the uptake row splits
into a part upstream has and a part it does not:

    dE_i/dtheta  =  dE_i/dtheta |_collar fixed   +   dE_i/dp * dpsi*/dtheta

The second factor **is** upstream's `collar` column — its comment states that
`dcollar/dtheta` equals `dpsi*/dtheta` by construction — and `dE_i/dp` is
`dE_from_soil_dpsi_collar_by_layer`, which this side already reads analytically.
What is missing is only the frozen-collar partial, one per layer per parameter.

So the wiring has a shape rather than a wish: **let the composite emit per-layer
uptake at the perturbed points it is already evaluating.** It performs the two
evaluations regardless; `soil_consumption_` is a member sitting there at each
one. Whether that lands as a sixth output, a caller-supplied sink, or a batch
variant is upstream's design call, and report 02 §3.0's rule says which question
decides it — enumerate the outputs from the consumer's equations, not from what
the solver happens to expose.

**But this is the second-best answer, and it is worth saying why.** Upstream's
composite is *itself* two perturbed evaluations per parameter — its own comment
says so. Calling it would buy one shared collar solve, a selective rebuild, and
one implementation under one set of tests, which is real. It would not buy
exactness, and it would not remove a single re-solve from the arithmetic; it
would move them behind a better-tested boundary. §4's routes remove them. The
two are complementary — take the composite for whatever stays differenced, and
shrink what stays differenced first — but if only one is done, it should not be
this one.

---

## 7. A second cost, independent of the first

Every drive calls `Leaf::evaluate_root_collar_psi`, and that runs
`prepare_collar_solve` on entry — `supply_begin_solve()`, then **two root-finds**
for `root_crit` and `root_zero_E`. At twenty drives that is about forty
root-finds per cohort per stage, most of them recomputing an interval that has
not moved.

phylloptim anticipates this and says so at the call site: `profit_at_collar_psi`
is documented as a separate entry point *"so callers that evaluate several collar
potentials within one step (the centred finite difference) can run
`prepare_collar_solve` once and reuse the soil-side caches across every profit
eval."* plant calls the entry point that re-prepares.

**The bounds do not move for every drive, and which ones they move for decides
what can be hoisted.** Radiation moves no water, so it cannot move an interval
defined by uptake; conductance is a stem quantity while both endpoints are root
ones. Perturbing a soil potential or a layer's carbon does move them. So the
hoist is legitimate exactly where the perturbation is not a supply one, and it
has to be argued per family rather than applied to the loop.

---

## 8. What upstream has that this side does not

`traitecoevo/phylloptim` carried three commits this branch did not have. They are
merged (`35d70d2`), and one of them was a requirement rather than an improvement.
What follows is what came in, because both of the first two change what the
routes below are priced against.

**`507b337`, bounding the root vulnerability curves past the grid.** Report 05
§6.2 states this as a requirement and gives the reason every obvious guard misses
it: the flux stays finite, the total over layers stays positive, and a positivity
guard permits the sign it produces, so nothing catches an unbounded lookup except
the bound itself. Report 05 §7.3 adds the ordering — bounding the integral
precedes building the operating-point selector, because a correct constrained row
evaluated at a bound whose position is set by a corrupted flux is a correct
derivative of the wrong thing.

**`1d1f6c3` solves for leaf temperature inside the collar first-order condition**,
which puts another solve inside the object every drive evaluates. It makes the
cost above worse, and it should land before any drive count is tuned against.

Beyond master, `upstream/prescribed-psi-gradient` is the calibration work, and two
things in it bear directly here.

It keeps the mixed partials and the curvature rather than consuming them:

```cpp
// The mixed partials d2profit/dpsi dtheta, npars long, and dY/dpsi at fixed
// traits. Kept rather than consumed: `-M/H` is what the composite needs, but M
// and H are also the coefficients of a caller's own sensitivity ODE for psi
```

`M` and `H` are report 05 §7.2's `Pi_pu` and `Pi_pp`. plant rebuilds both by hand.
The comment names `traitecoevo/plant#614` as the consumer, so the two sides have
already been designed toward each other.

And its composite rebuilds selectively. `apply(l, th, d, single, p, fast_stem_curve)`
is told **which** parameter moved, and `takes_shortcut` skips the stem curve for
the one parameter that does not need it. plant's `drive` lambda passes no such
hint, so every drive re-seats the whole physiology.

**What upstream does not have is this side's directions.** Its parameter list is
leaf traits plus conductance and a resistance; the per-layer soil potentials and
per-layer root carbon a stand adjoint needs are not in it, and its own note says
`uptake` was left out because it is a sum the caller performs. So the two halves
are complementary rather than redundant: upstream has the composite and the
selective rebuild, this side has the environment rows.

---

## 9. What follows

Ordered by measured share, not by ease. Two items that stood at the head of this
list are **done**, and the drive counts everywhere in this note are the ones
before them:

- **Merging upstream** (`35d70d2`). `507b337` was a stated requirement of report
  05 §6.2, and `1d1f6c3` changes what a drive costs — tuning drive counts against
  a leaf about to grow a temperature solve would have priced the wrong object.
- **Declaring the two critical potentials zero** (`c5e3a5f9`), four drives, with
  the row declared rather than silently absent. Report 06 §11 carries the proof
  and the domain: zero at an interior optimum by complementary slackness, live at
  a pin, and the sweep refuses everything that is not interior.

**Ranked by measured share, which is not how this list used to be ordered.** A
curve trait's drive is 92–97 µs and every other trait's is 2.3, so the four
vulnerability traits are roughly 760 µs of a 1230 µs block and everything else in
the trait loop is about two per cent. §4 carries the table.

1. **Take `b` and `root_b` by the homogeneity rescale.** Four drives at 95 µs
   become four at 2. The identity is exact, holds for the spline because the knot
   grid scales with `b`, and is verified here against a rebuild of the quantities
   plant reads at **3.9e-13**. `perturb_stem_b` already exists upstream and skips
   `set_physiology` as well, since nothing it derives reads `b`. The root curve
   needs the same accessor written against the same identity.
2. **`c` and `root_c` keep their rebuild.** There is no identity for the steepness,
   the closed-form substitute was built upstream and rejected at a systematic
   `3.5e-3`, and the moving-grid contamination measured here is 9.6e-06 — real,
   systematic, and too small to act on. **This is the floor on the leaf's cost
   until the forward model stops reading a spline**, which is a re-blessing rather
   than a wiring job.
3. **Give the kernels their trait scalar** for the photosynthesis and cost family
   — `beta2`, `a`, both `curv_fact_*`, `g1_TF24`. Ten drives, and they are the
   cheap ones: about 23 µs of a 1230 µs block. Worth doing for exactness, not for
   speed, and it is the only item here that changes the leaf rather than a wiring.

**Then the two rows nobody drives, which are a completeness item rather than a
cost one.** `vcmax_25` and `jmax_25` are carried, passed to the leaf, and absent
from the differentiable set because the leaf's temperature block once cached its
derived values under a key of the drivers alone. That key now covers every input
of the block, both among them, and each moves profit — measured at 3.5e-02 and
3.9e-03 per unit. They sit in the 2.3 µs bucket, so two more rows cost about four
microseconds of a block, and they are photosynthetic capacity. Report 06 §11 now
records the absence and that its stated cause has gone.

**And one is done: dark respiration at 25 °C** (`d6a51304`). It was in the same
position — carried by the leaf, not taken by its constructor, so it ran at the
leaf's default with no parameter able to move it. It is now carried at that
default and driven with the other leaf traits, with the census values and all 88
pre-existing columns **bit-identical** and two columns added.

**Then give the supply side its resistance-direction derivatives**, and route the
root-carbon family through the factorisation exactly as the soil-potential family
already is. Ten drives, at 2.3 µs each rather than 95, so this is now a
correctness and exactness item and not a cost one — the earlier ranking had it as
the second-largest saving. The corpus has already verified the prediction it
relies on (report 08 §4.1), and the acceptance test is the one that check uses:
predict the family out of sample and require the worst direction to stay at
round-off.

**Then hoist `prepare_collar_solve`** for the families whose perturbation cannot
move the feasible interval, using the entry point phylloptim provides for it.
Argue the families one at a time; a blanket hoist is wrong for the supply ones.

**What not to do.** Do not attack the tape, the per-cohort recording, or the
decomposition of report 01. Measured, they are 0.6 per cent of a block, and the
peak-memory property that decomposition buys is intact. The cost is the leaf's
hand-built Jacobian and nothing else.

---

## 10. Why this is written down rather than built

The two changes already landed — the rebound patch's boundary node, and the two
critical potentials — are **provable no-ops**: both were verified bit-identical
against the fixtures and a production stand, because neither changes what is
computed, only how much is computed to get there.

Everything in §4 and §5 is a different kind of change. Each replaces a
differenced quantity with an analytic one, so each changes how a number is
produced, and an error in any of them returns a finite, plausible, wrong
gradient rather than a failure. That is the failure mode this whole corpus is
organised against, and the defence against it is a verification campaign per
change, not a passing suite.

So the sequencing rule for whoever picks this up: **land one family at a time,
and hold each to the differenced values it replaces before moving on.** The
differenced implementation is the reference, it exists today, and it stops being
available the moment it is deleted.

---

---

### Provenance

The block decomposition of §2 was measured at `444bcf1a` plus the inflow-boundary
change, on `ad/v3-forward`, with `ladder_rhs_adjoint_timing_tf24` and a temporary
counter in `record_leaf_outputs` since reverted. Component times are per whole
right-hand-side adjoint, averaged over five repetitions; the parts sum to the
total to within 0.01 per cent.

**§4's per-drive costs, the rescale equivalence and the moving-grid term are
measured by `docs/probes/probe_leaf_rows.cpp`**, which runs against phylloptim
directly with no R and no stand — one interior operating point, three soil
layers, `-O2`. Build it as:

```sh
cd phylloptim/tests/cpp
c++ -std=c++20 -O2 -I../../inst/include -I. \
  -I$(Rscript -e 'cat(system.file("include", package="BH"))') \
  -I$(Rscript -e 'cat(system.file("include", package="odelia"))') \
  ../../../docs/probes/probe_leaf_rows.cpp -o /tmp/probe && /tmp/probe
```

It answers four questions and prints numbers rather than verdicts: whether the
homogeneity rescale gives the same row as a rebuild, what the moving knot grid
costs the steepness row, what a drive costs by trait family, and whether the
three traits the leaf holds but plant does not differentiate can be moved at all.
Timings are per drive over 2000 repetitions and will differ between machines; the
**ratio** of 40 between the curve and non-curve families is the durable part, and
the equivalence and contamination figures are properties of the arithmetic.

Drive counts are read from the source, not measured, and §3 says why they are the
wrong thing to price against.
