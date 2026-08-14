# The leaf's supplied rows: where their cost is, and what removes it

After the inflow boundary's rebind stopped rating every cohort, one function is
the reverse pass. `TF24_Strategy::record_leaf_outputs` builds the leaf's supplied
derivatives once per cohort per stage, and it is **86 per cent of what is left**.

This is what it spends, what the corpus already says about each part, and which
parts are removable.

---

## 1. What a call costs

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

## 2. Where the drives go

The call re-drives the leaf about twenty times. They fall into four families,
and the corpus treats them very differently.

| family | directions | drives | how the row is obtained |
|---|---|---|---|
| soil potential | `L` | **0** | the rank-two factorisation |
| root carbon | `L` | **10** | central differences, per layer |
| conductance | 1 | 2 | central difference |
| radiation | 1 | 2 | central difference |
| curvature | — | 2 | central difference of the marginal profit |
| fitting the pair | 2 | 4 | one potential, one layer resistance |

The soil-potential family is already free:

```cpp
dcollar_dpsi[j] = -(a * dEup_dpsi[j] + b * d2Eup_dcollar_dpsi[j]) / curvature;
```

Five directions, no drives, because report 05 §7.3's factorisation supplies them
from two scalars that two drives already fixed.

**The root-carbon family is in the same span and does not use it.** Report 05
§7.3 states the factorisation over `2L+1` state directions — the `L` soil
potentials, the `L` per-layer root masses, and leaf area — and report 08 §4.1
records the check that matters: the pair solved from two directions of
*different families* predicts the remaining nine to a worst `2.4e-05`,
round-off limited. The root masses are inside the verified span. They are
nonetheless differenced, one layer at a time, and that is half of every drive
this function makes.

---

## 3. Why it is differenced, and what is missing

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

and only layer `a`'s resistance moves when layer `a`'s carbon does, so the block
is **diagonal**. The chain from carbon to resistance is the architecture model's
own, and report 02 §3.3 already states its shape: a resistance network is
homogeneous of degree −1 in the root carbon it is built from, so scaling carbon
by `1/A` scales resistances by exactly `A`.

The two quantities the *other* rows in this family need are reachable by the
same chain. Per-layer uptake at a frozen collar is the derivative above. The
profit row is an envelope row, and profit sees root carbon only through the stem
potential, so it is

    dPi/dr_a = (dPi/dpsi_stem) * (dpsi_stem/dE_up) * (dE_up/dr_a)

whose first two factors are exactly the product report 05 §7.3 gives in closed
form as `b = -(dPi/dpsi_stem) * P' / kappa`. Nothing new has to be derived.

---

## 4. A second cost, independent of the first

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

## 5. What upstream has that this side does not

`traitecoevo/phylloptim` carries three commits this branch has not merged, and
one of them is a requirement rather than an improvement.

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

## 6. What follows

Ordered by measured share, not by ease.

**First, merge upstream.** `507b337` is a stated requirement of report 05 §6.2,
and `1d1f6c3` changes what a drive costs. Tuning drive counts against a leaf that
is about to grow a temperature solve prices the wrong object.

**Then give the supply side its resistance-direction derivatives**, and route the
root-carbon family through the factorisation exactly as the soil-potential family
already is. This is ten of about twenty drives, and the corpus has already
verified the prediction it relies on (report 08 §4.1). The acceptance test is the
one that check already uses: predict the family out of sample and require the
worst direction to stay at round-off.

**Then hoist `prepare_collar_solve`** for the families whose perturbation cannot
move the feasible interval, using the entry point phylloptim provides for it.
Argue the families one at a time; a blanket hoist is wrong for the supply ones.

**What not to do.** Do not attack the tape, the per-cohort recording, or the
decomposition of report 01. Measured, they are 0.6 per cent of a block, and the
peak-memory property that decomposition buys is intact. The cost is the leaf's
hand-built Jacobian and nothing else.

---

### Provenance

Measured at `444bcf1a` plus the inflow-boundary change, on `ad/v3-forward`, with
`ladder_rhs_adjoint_timing_tf24` and a temporary counter in `record_leaf_outputs`
since reverted. Component times are per whole right-hand-side adjoint, averaged
over five repetitions; the parts sum to the total to within 0.01 per cent. Drive
counts are read from the source, not measured.
