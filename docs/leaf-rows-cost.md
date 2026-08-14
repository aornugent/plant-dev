# The leaf's supplied rows: where their cost is, and what removes it

After the inflow boundary's rebind stopped rating every cohort, one function is
the reverse pass. `TF24_Strategy::record_leaf_outputs` builds the leaf's supplied
derivatives once per cohort per stage, and it is **86 per cent of what is left**.

This is what it spends, what the corpus already says about each part, and which
parts are removable.

---

## 1. Start here

**The state.** One right-hand-side adjoint of an 88-cohort patch is **111.7 ms**,
down from 126.8 at the start of this work and with three trait rows *added*
along the way. `cohort_blocks` is 95.5 of it — about **1.07 ms per block**
against 0.018 ms for the same cohort's rates in plain double. §10 lists what
landed, what was withdrawn, and what is next.

**Two items are next, and they are independent of each other.**

1. **Seed the vulnerability knots from the package's own series** rather than
   boost's incomplete gamma. This is the last large cost item: 80.2 µs against
   13.2 for the same 100 knots, which takes a curve drive from ~93 µs to ~26 and
   is on the order of **1.8×** on the whole adjoint. It changes the seeding
   arithmetic and **not** which function is differentiated, so it is not §5's
   mistake — but it moves the golden file and needs a re-blessing.
2. **The photosynthesis family's rows.** `a`, `curv_fact_elec_trans` and
   `curv_fact_colim`, six drives. The profit row is derived and verified in §10;
   the marginal row needs `A''` and a mixed second partial, and both need a trait
   scalar threaded through kernels that reach assimilation through a `double`
   member. Read §4 before starting: that threading *is* §4's prescription.

**Read §5 before touching the vulnerability curve at all.** A held grid has been
proposed twice, built twice, and refuted twice by the same instrument, and the
reasoning behind it survives review every time.

**What to read, and nothing else.** The corpus is large and almost none of it
bears on this.

| question | read |
|---|---|
| what a supplied row is, and what the boundary must guarantee | report 02 §3, §4 |
| why the leaf is entered passively at a solved point | report 02 §1 |
| the rank-two factorisation this work extends | report 05 §7.3, and report 08 §4.1 for its check |
| the tabulation rule that governs the vulnerability rows | report 02 §5, report 05 §7.6, then §5 here |
| which traits have rows, and the domain a number carries | report 06 §11 |
| the per-cohort decomposition — **confirmed not the cost, do not redesign it** | report 01 |
| whether a grid may be held across a perturbation | report 05 §7.6, corrected — the test is whether the forward model rebuilds it |
| why a pair of coefficients must be anchored in the family it serves | report 05 §7.3 |
| why the completeness fixture needs two species | report 08 §5.4 |

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

**How to verify a change here, and this is the part the session that wrote it
kept getting wrong.** Three instruments, in increasing order of what they can
see, and the cheap ones cannot substitute for the dear one:

1. **Against differencing at the leaf**, at wet, dry and shaded states, with a
   probe under `docs/probes/`. Fast, and it settles whether an expression is the
   derivative of what it claims. It cannot settle whether the claim is the right
   one — two routes to the same wrong function agree here perfectly.
2. **Against the differenced rows it replaces, at the stand.** Bit-identity for a
   pure cost removal (`max abs diff 0.000e+00`, never a tolerance), and otherwise
   a column-by-column comparison. This localises a change; **88 of 90 columns
   bit-identical says a change is confined, not that it is right.**
3. **Against `ladder_run_difference_pair()`** — a difference that rebuilds the
   strategy and re-runs, on the stand where the species compete. **This is the
   only one that has ever caught anything here**, and it caught three separate
   things. A single-species reference agreed to `1e-06` with rows that were six
   per cent out.

⚠️ **It carries a step-stability guard and the guard is the point.** Read at one
step, that same reference gave 0.275, 0.131, 0.122 and 0.126 across four — a
factor of two — and a reading taken at `1e-5` was used to reverse a decision
before the guard existed. Report 08 §4.7's fifth trap is exactly this.

**And capture the reference before deleting the differencing.** Every analytic
row's acceptance test is the differenced value it replaces, and that value stops
existing the moment the differencing is deleted.

**The instruments, both already committed.** `ladder_rhs_adjoint_timing_tf24`
times the eight components of one right-hand-side adjoint in situ and reports
whether the parts sum to the whole; `ladder_block_copy_cost_tf24` separates a
block's preamble from its recorded arithmetic. Between them they are how §2's
table was measured, and a per-block cost obtained by dividing a total instead
is attributed by construction rather than measured.

**Four habits, each of which was learned by not having it.**

**Attribute before optimising.** Three hypotheses about where the cost was died
before instrumenting the boundaries settled it.

**Check a claim against the code before acting on it.** §5's first recommendation
was reversed because a function that looked unused was deliberately unwired.

**A design that survives review can still fail a reference.** Two did here, and
both were built, landed behind a measurement, and withdrawn. Neither was
careless; both were refuted only by the instrument that shares no assumption with
them. Budget for that outcome rather than treating it as failure.

**An exact ingredient does not make a correct row.** The closed-form second
coefficient is right to `5e-10` and using it made a stand column *worse*, because
it moved where the remaining error landed. That was the diagnosis, not a puzzle
— see report 05 §7.3.

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

## 5. The vulnerability curve, traced op by op

The four curve traits are most of the block (§4), and the route out is neither the
closed-form substitution report 02 §5 forbids nor a resignation to rebuilding.
This section traces every operation the traits reach, forwards and backwards, and
the design falls out of one structural fact about the interpolant.

### Forward, stem side: `b` and `c` reach profit twice, and only one route is a table

`set_traits` rebuilds when either moves, and the rebuild is three steps:

1. **The grid.** `psi_max = b * log(100)^(1/c)`, `step = psi_max / resolution`, then
   `x = {0}` and `for (psi = step; psi <= psi_max; psi += step) x.push_back(psi)`.

   ⚠️ **The knot count is decided by round-off.** The loop accumulates and tests
   `<=`, so whether the last knot lands inside `psi_max` depends on the drift of
   99 additions. Measured: a `1e-5` relative move in `c` gives **100 knots on one
   side of a central difference and 101 on the other**, with the extra knot a
   whole step further out. The grid does not merely move — its cardinality jumps.
2. **The knot values**, `y_i = (b/c) * gamma_lower(1/c, (x_i/b)^c)`, from boost.
   Measured at 100 knots: **80.2 µs**, and this is the whole of the rebuild's cost.
3. **Two interpolators**, `transpiration_from_psi.init(x, y)` and
   `psi_from_transpiration.init(y, x)` — the second is the *inverse*, the same pair
   swapped. Both with extrapolation off. **3.40 µs each.**

Every read goes through four accessors that apply `s = stem_b / stem_b_spline_`,
so the transport channel is: `transpiration = kmax * (G(psi_stem) - G(psi_up))`,
`transpiration_to_psi_stem = G^-1(E/kmax + G(psi_up))`, and
`stem_curve_integral_deriv` inside the marginal-profit and conductance chains.

**And there is a second channel that is not a table at all.** The hydraulic cost is

    C(psi) = cost_scale * (1 - exp(-(psi/b)^c))^beta2

evaluated as a closed-form kernel, with no spline anywhere in it. So `b` and `c`
reach profit through **the transport integral, which is tabulated, and the cost,
which is not** — and forward mode on the cost kernel already gives its half
exactly. Any design that treats "the vulnerability rows" as one problem is
treating two.

> ⚠️ One inconsistency found while tracing, worth recording because it is
> invisible. `lambda_TF24` forms `dE/dpsi` as `kmax * f(psi)` from the **closed
> form**, while the solve forms the same quantity from
> `stem_curve_integral_deriv` — the **spline's** derivative. The two differ by the
> spline's approximation error. `lambda` is a reported diagnostic and not on the
> solve path, so this is a reporting mismatch rather than a defect; it becomes one
> the moment anything referees one against the other.

### Forward, root side: three objects and a closed-form constant

`setup_vulnerability` builds, from `root_b` and `root_c`: the conductivity spline
`root_vuln_from_psi` with knots `exp(-(x_i/root_b)^root_c)` and extrapolation
**off**, its argument clamped to the last knot on read; the integral spline
`root_vuln_integral_from_psi` with extrapolation **on** and its *value* capped;
`root_vuln_last_knot_`; and `root_vuln_integral_limit_ = (b/c) * Gamma(1/c)`, which
is closed form. The two splines are bounded by different mechanisms — argument
clamp against value cap — and §6's flux loop reads both.

### The homogeneity in `b`, verified across all four root objects

Because every knot position is proportional to `b`, the whole apparatus is exactly
self-similar in it: `G` scales by `s` with its argument divided by `s`; **`f_r`'s
knot values do not move at all**, since `x_i / b` is `b`-independent; the last knot
scales; the limit scales. Measured, `f_r`'s knots are identical to **4.6e-15** and
the limit scales to **1e-16**.

**But measured between two independently rebuilt curves the last knot disagrees by
`1e-2`, not `1e-16`** — because the knot count jumped 100 → 101. At `s = 1.2`,
where the two counts happen to match, every one of the four agrees to round-off.
So the identity holds for the continuum, and for the *spline* only at equal knot
count. **A rebuild can break it; a rescale cannot, because a rescale never
rebuilds.** That makes `perturb_stem_b` strictly better than the rebuild it
replaces rather than merely cheaper.

### Backward: what a row needs

Per curve trait, plant needs the profit row at a frozen collar (which the envelope
makes the total), `dR/dtheta` for `R = dprofit/dcollar` so the collar's own
response follows as `-(dR/dtheta)/curvature`, and each layer's `dE_i/dtheta` at a
frozen collar. Today each is one central difference over two full solves, and each
solve pays a rebuild.

### The structural fact, and the design that follows

**The interpolant is exactly linear in its knot values.** odelia's spline
assembles its band matrix from the knot positions alone, applies it to the
right-hand side, and takes natural boundary conditions; every coefficient is
linear in `y`. Its own header says so — the solve is *"a constant-double band
matrix applied to an active RHS"*. So at a fixed grid

    G_spline(psi; theta) = SUM_i L_i(psi) * y_i(theta)
    dG_spline/dtheta     = SUM_i L_i(psi) * dy_i/dtheta

— **the derivative of the spline is the spline through the knots' own
derivatives, on the same grid.** Measured against a central difference of a
reseeded value spline, worst over nine points across the domain:

| step in `c` | worst relative disagreement |
|---|---|
| `1e-3` | 5.1e-06 |
| `1e-5` | **1.0e-09** |
| `1e-7` | 3.4e-08 |

`h^2` down to `1e-5` and round-off below it. **A vanishing-with-`h` disagreement is
the signature of an identity; an approximation would leave a floor.**

Two consequences, and together they are the design.

**A perturbed spline costs one `init`, not 80 µs of gammas.** At a fixed grid
`y_i(theta ± h) = y_i(theta) ± h * dy_i/dtheta` exactly, so a perturbed evaluation
needs no incomplete gamma at all.

**And the knots' derivatives are cheaper than the knots.**
`cumulative_vulnerability_integral_derivatives_at` sums its own
everywhere-convergent series and returns the value, `dG/dpsi`, `dG/db` and `dG/dc`
together: **13.2 µs for 100 knots, against 80.2 µs for boost's value alone.**
Seeding the derivative grid is six times cheaper than seeding the value grid is
today.

**This is not the substitution report 02 §5 forbids, and the distinction is
exact.** That rule forbids replacing the *table's* derivative with the *closed
form's*. Here the table stays the value, and the closed form is used only for how
the table's knots move — which is how the forward model computes those knots in
the first place. The function differentiated is the function evaluated. What
upstream built and rejected was the other thing: reading `G` itself from the
closed form, which disagreed with the spline by a systematic `3.5e-3`.

**The arithmetic.** Four traits, two sides each:

| | per cohort per stage |
|---|---|
| today | 8 × (80.2 gammas + 2 × 3.40 init + 2.3 solve) ≈ **744 µs** |
| designed | 13.2 once + 8 × (2 × 3.40 init + 2.3 solve) ≈ **86 µs** |

about **eight to nine times** on the part of the block that dominates it, and it
**removes** the grid-motion term rather than measuring it — the correctness fix
arrives with the speed rather than costing extra. `b` and `root_b` are cheaper
still, needing no `init` at all.

### ⚠️ Arbitrated against a rebuilding reference, and the design above is WRONG

Everything from "The structural fact" to here was built, landed behind a flag and
measured, and **the measurement reverses it.** It is kept rather than deleted
because the reasoning is exactly the reasoning report 02 §5 exists to catch, and
it survived two rounds of verification before an independent instrument killed it.

The route was tried first for `b`, where the identity is exact and needs no
derivative spline at all. Landed, it gave **1.18× on the whole right-hand-side
adjoint** — 185.3 µs saved per block against a predicted 186 — with the census
value unchanged and **88 of 90 gradient columns bit-identical**, the two moved
columns being exactly the two the change touches. Every check that reads the
sweep against itself passed.

Then the two routes were arbitrated against `ladder_run_difference`, which
perturbs the parameter, **rebuilds the strategy** and re-runs the model, so it
uses neither route:

| the `b` column | ratio to the rebuilding reference |
|---|---|
| rebuild (what is there) | **1.000002** |
| homogeneity rescale | 0.99981 |

**The rescale is a hundred times further from the reference.** And the reason is
the one this document already carries about the vulnerability integral: *the
forward model rebuilds*. `set_traits` rebuilds the spline when a curve trait
moves, so the function plant evaluates as a function of `b` **has the grid moving
with `b` inside it**. The rescale differentiates a different function — the base
spline stretched — and the difference is the interpolation error's own dependence
on the trait, which is not spurious here because the grid is *defined by* the
parameter.

**So the moving grid is part of the model, not an artefact of differencing it**,
and the derivative-spline route for `c` fails for the same reason: it computes the
fixed-grid derivative, and the fixed grid is not the model's.

**This contradicts report 05 §7.6 as applied to this grid**, and the disagreement
is the finding. That rule — capture the grid once and hold it across parameter
perturbations — is right where a grid is a discretisation choice made independently
of the parameter, which is report 03 §3.3's knot positions tied to canopy height.
It is wrong where the grid is a function of the parameter itself, as
`psi_max = b * log(100)^(1/c)` is. The two cases need separating in the corpus, and
the test is whether the forward model rebuilds the grid when the parameter moves.

**What survives.** The linearity of the interpolant in its knot values is a real
structural fact, measured, and it stays true — it is simply the derivative of the
wrong function here. The series being six times cheaper than boost's value is also
real and is worth taking on its own: it would make the *rebuild* cheaper, which is
the route that is correct. That is the route worth pricing next, and it needs no
identity and no held grid — seed the rebuilt knots from the series rather than from
boost, and the 80.2 µs becomes 13.2 with the grid still moving as the model moves
it.

**And the general lesson, which cost this session two rounds.** A leaf-level check
that the two routes agree to 3.9e-13 was not evidence: it compared the routes to
*each other*. Eighty-eight bit-identical columns were not evidence either — they
say the change is localised, not that it is right. **Only the instrument that
shares neither route could tell**, and it is the completeness axis report 08 §5
already names for exactly this.

### The one hole in it, and how it closes

`psi_from_transpiration` is built as `init(y, x)`: its knot **values** are the
potentials, which do not move with a trait at a fixed grid, and its knot
**positions** are `y`, which do. **So the linearity argument does not cover the
inverse spline**, and a design that assumed it did would leave the inverse
transport channel differentiating a moving grid while believing it had stopped.

It closes without a second spline. The inverse is defined by `G(psi; theta) = w`,
so implicit differentiation gives

    dG^-1/dtheta |_w  =  -(dG/dtheta) / (dG/dpsi),   both evaluated at psi = G^-1(w)

with `dG/dtheta` from the derivative spline and `dG/dpsi` from the accessor the
model already reads. Exact, and it needs no rebuild either.

### What this does not do

It removes the rebuild, not the differencing. The row is still a central
difference over two solves, so it keeps that difference's truncation and its
step-choice question. Making the row analytic is a further step — forward mode
through the leaf with the trait carried on the scalar, which the derivative spline
would supply the tangent for — and it is not needed to collect the eight-fold.

---

## 6. The root-carbon family, and the one accessor it is missing

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

### ⚠️ Built, refereed and put back — what is exact and what is not

The whole of this section was implemented and measured. **The per-layer supply
derivatives are exact and are kept; routing the collar's own response through them
is not, and was reverted.**

`MultiLayerRoots::duptake_droot_carbon` gives `dE_i/drc_a` and `d(dE_i/dp)/drc_a`
as two lower-triangular blocks. Against differencing the rebuilt network at wet,
dry and shaded states: **worst 1.0e-10 to 3.5e-10**, the central difference's own
accuracy, with the strictly upper entries exactly zero. The derivation above is
right, the triangularity is right, and the three obligations are real.

**What failed is the step this section does not derive: `dR/drc`.** The
implementation took it from report 05 §7.3's factorisation,
`dR/drc = a·dE_up/drc + b·d(dE_up/dp)/drc`, which is exact in principle — `R` does
depend on the state through only those two intermediates. It fails in practice
because **the pair is fitted from nearly collinear directions** (measured
determinant `1.8e-14`), so a compensating `(a,b)` reproduces every direction
inside their span and none outside it. Root carbon is outside it.

Refereed on the two-species stand against a difference that rebuilds the strategy
and re-runs — which needed building, because the existing helper makes only
single-species stands — **and read at the step where that difference has
converged**, which is not where it was first read:

| species 2's `a_r1` | ratio to the reference, step `1e-3` |
|---|---|
| **differenced** | **0.990 / 0.996 / 0.981** |
| analytic, fitted pair | 1.062 / 1.029 / 1.134 |
| analytic, closed-form second scalar | 0.830 / 0.927 / 0.649 |

> ⚠️ **The first reading of this table was taken at `1e-5` and was wrong.** That
> column's reference runs 0.275, 0.131, 0.122, 0.126 over steps `1e-6` to `1e-3` —
> a factor of two — and only settles at the coarse end. Report 08 §5.1 requires
> step-stability as the check on this reference and §4.7's fifth trap names this
> exact failure; the guard is now inside `ladder_run_difference_pair` so it cannot
> be skipped again. **The ordering above survived the correction and the
> magnitudes did not**, which is the good case: a decision made on a bad number
> that happened to be right is still a decision that has to be re-made.

**And the second scalar was not the fault — it is the first.** Report 05 §7.3 says
one of the two is closed form; it now is, on the leaf, and it is right — it
reproduces a difference of the profit to **5e-10** where the fitted one carried
`1e-03`. Using it makes the stand column **worse**, and that is the diagnosis
rather than a puzzle: with `b` pinned to its exact value, `a` is solved from one
differenced potential direction, so the whole of that direction's differencing
error lands in `a` instead of being spread across the pair. The fitted pair looks
better on the fitted directions for the same reason it fails off them.

**So what had to improve is the first coefficient — and it did not need deriving.**
The two coefficients are definite numbers, so any two independent directions
recover them in exact arithmetic; the choice of directions decides only where the
arithmetic's error lands. The fix is therefore not a more accurate `a` but a
better-placed one: **read `b` in closed form and solve `a` along a CARBON
direction**, whose supply derivatives the soil side now answers analytically, so
the direction costs two evaluations and no more. The potentials then absorb
whatever is left, and they are the family that cannot see it — collinear to a part
in `10^4`, so a compensating pair fits them equally well.

Refereed on the competing stand, at the converged step:

| species 2's `a_r1` | ratio to the reference |
|---|---|
| differenced, what it replaces | 0.990 / 0.996 / 0.981 |
| **carbon-anchored, analytic** | **0.990 / 0.996 / 0.981** |
| potential-anchored, closed `b` | 0.830 / 0.927 / 0.649 |
| fitted pair | 1.062 / 1.029 / 1.134 |

Every one of the ninety-four columns is within `1.1e-04` of the version it
replaces and the census values are identical. **Twelve drives per cohort per stage
become two**, and the family's rows stop being differences at all bar the single
anchor.

**The reason deriving `a` was not needed is worth keeping**, because it generalises
past this row: when a factorisation is exact and the trouble is conditioning, the
cheap fix is to move the directions, not to remove the differencing.

**Three things worth carrying.**

A single-species arbitration is not evidence for this family. Both trait sets
passed at **1e-06** against the rebuilding reference on single-species stands and
the defect is only visible with competition — because without it no cohort sits
far from the direction the pair was fitted in.

A sign error hid inside all of this, and it is now corrected in report 05 §7.3:
the second scalar is `G·P'/κ` as the prose says, not its negative as the display
said. A profit row built on the display comes back as a clean factor of `-1`.

And the arithmetic never justified the risk: this family is ten drives at 2.3 µs
against a 1230 µs block, so the whole prize was **1.03×**. The measurements were
worth taking; landing it was not.

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

## 7. The largest family is also a second copy of phylloptim's gradient module

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
  two root-finds per drive (§8);
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
would move them behind a better-tested boundary. §4 and §5's routes remove them. The
two are complementary — take the composite for whatever stays differenced, and
shrink what stays differenced first — but if only one is done, it should not be
this one.

---

## 8. A second cost, independent of the first

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

## 9. What upstream has that this side does not

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

## 10. What follows

### Done

- **Merging upstream** (`35d70d2`). `507b337` was a stated requirement of report
  05 §6.2, and `1d1f6c3` changes what a drive costs.
- **The two critical potentials declared zero** (`c5e3a5f9`), four drives, with
  the row declared rather than silently absent.
- **Dark respiration at 25 °C given a parameter and a row** (`d6a51304`). It was
  carried by the leaf, not taken by its constructor, so it ran at the leaf's
  default with nothing able to move it.
- **Photosynthetic capacity and the electron-transport maximum given rows**
  (`11fa956b`). Both were withheld because the leaf's temperature block once
  cached their derived values under a key of the drivers alone; that key now
  covers every input of the block. Each of these three landed with the census
  values and **every prior column bit-identical**.
- **The root-carbon family taken analytically** (`5a5e3984`, with
  `duptake_droot_carbon` and `dmarginal_profit_duptake_slope` upstream). Twelve
  drives per cohort per stage become two. §6 carries the derivation, the
  arbitration and the two failed attempts that preceded it.

### Withdrawn, and §5 says why

- **The homogeneity rescale for `b` and `root_b`**, and **the derivative-spline
  seeding for `c` and `root_c`**. Both were built and measured — the first landed
  at **1.18× on the whole right-hand-side adjoint** with 88 of 90 columns
  bit-identical — and both differentiate the wrong function. `set_traits` rebuilds
  the curve when a curve trait moves, so the grid moving with the trait is part of
  the model rather than an artefact of differencing it, and a reference that
  rebuilds says so.

### What is left, by measured share

**One item is most of the remaining cost, and it is not a gradient change.**
A curve trait's drive is 92–97 µs against every other trait's 2.3, so `b`, `c`,
`root_b` and `root_c` are still about 700 µs of a 1120 µs block. The rebuild
decomposes as **80.2 µs of boost's incomplete gamma** plus 3.4 µs per interpolator,
and the package's own everywhere-convergent series returns the value **and both
trait partials** for **13.2 µs**. So seeding the knots from the series instead of
boost takes a curve drive from ~93 µs to ~26 µs — **on the order of 1.8× on the
right-hand-side adjoint**, with the grid still moving exactly as the model moves
it, so it is not §5's mistake.

What it costs is a **re-blessing**: the two routes agree to `1.2e-15` per knot, and
the nested solves amplify that to the solver's own floor, so the golden file moves.
That is a forward-model change made once, which is the shape report 05 §7.6
prescribes for this curve — just not the change §5 tried to make.

**Then the exactness items, which are not cost items.**

- **`beta2` and `g1_TF24` are done.** They reach profit through the hydraulic
  cost and nothing else, so with `q = 1 - f(psi_stem)` and `C = cost_scale * q^beta2`
  every row is elementary: `dC/dscale = C/scale`, `dC/dbeta2 = C log q`, and the
  same two over `C'` for the marginal row. Four drives gone, verified at 2.5e-13
  against differencing and 0.9997–0.9999 against the two-species reference.

  **Their frozen-collar uptake rows were already exactly zero** — at a fixed
  collar a carbon-side trait moves no water, and the difference was returning
  bit-identical uptake either side. So that half of the exactness was never
  available to win, which is worth knowing before pricing the rest of the family.
- **`a`, `curv_fact_elec_trans` and `curv_fact_colim` remain, and their profit
  row is derived and measured.** At a frozen collar these three move nothing but
  assimilation — the stem potential, the stomatal conductance and the hydraulic
  cost are all fixed, and the only thing that responds is the intercellular CO2
  the residual places. Writing the residual as the model does,
  `g = A_net * umol_to_mol - gc (ca - ci) inv_atm`, the implicit-function term
  collapses:

      dci/dtheta = -(dA/dtheta) umol_to_mol / g_ci
      dPi/dtheta = dA/dtheta (1 - A' umol_to_mol / g_ci)
                 = dA/dtheta * gc * inv_atm / g_ci

  because `g_ci = A' umol_to_mol + gc inv_atm` by definition. **One kernel partial
  at fixed `ci`, times a factor the solve already forms** — no solve, no root-find,
  no supply. Measured against differencing the solve at wet, dry and shaded, with
  `dA/dtheta` itself taken by differencing the *kernel* at fixed `ci`:

  | trait | wet | dry | shaded |
  |---|---|---|---|
  | `a` | 4.7e-08 | 4.8e-07 | 7.4e-11 |
  | `curv_fact_elec_trans` | 5.8e-10 | 8.3e-09 | 2.1e-09 |
  | `curv_fact_colim` | 9.4e-06 | 1.8e-06 | 3.9e-10 |

  **What is not done is the marginal row, and it is the half that gates the
  drives.** `dcollar/dtheta` needs `dR/dtheta`, and with
  `dci/dp = D K`, `D = dgc/dpsi_stem * dpsi_stem/dp + dgc/dp`,
  `K = (ca - ci) inv_atm / g_ci`, and `R = A' D K - C' dpsi_stem/dp`:

      dR/dtheta = D [ (dA'/dtheta) K + A' dK/dtheta ]
      dA'/dtheta = d2A/dtheta dci + A'' dci/dtheta
      dK/dtheta  = -[ (dci/dtheta) inv_atm g_ci + (ca - ci) inv_atm umol dA'/dtheta ] / g_ci^2

  so it needs `A''` and the mixed `d2A/dtheta dci`. Both are on a kernel with no
  interpolator, cache or root-find in it, so report 02 §4 item 1 sanctions taking
  them by forward mode — but the kernels are §4's problem exactly: `a` and the
  electron-transport curvature reach `A` only through `electron_transport_`, a
  `double` member, so a trait scalar has to be threaded before forward mode can
  see them. **Until both halves are done there is no drive to remove**, and the
  profit half alone replaces a difference accurate to about `1e-6` with a
  prediction accurate to about `1e-6`, which is not worth landing on its own.
- **Hoist `prepare_collar_solve`** for the families whose perturbation cannot move
  the feasible interval, using the entry point phylloptim provides. Argue the
  families one at a time; a blanket hoist is wrong for the supply ones (§8).
- **§7's composite** for whatever stays differenced, which after the above is the
  curvature, the radiation row, the conductance row and the single carbon anchor.

### What not to do

Do not attack the tape, the per-cohort recording, or the decomposition of report
01. Measured, they are **0.6 per cent of a block**, and the peak-memory property
that decomposition buys is intact.

Do not re-derive a held grid for the vulnerability curve without reading §5 first.
It has now been proposed twice, built twice, and refuted twice by the same
instrument.

---

## 11. Why this is written down rather than built

The two changes already landed — the rebound patch's boundary node, and the two
critical potentials — are **provable no-ops**: both were verified bit-identical
against the fixtures and a production stand, because neither changes what is
computed, only how much is computed to get there.

Everything in §4, §5 and §6 is a different kind of change. Each replaces a
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
