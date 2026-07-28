# The soil–plant coupling: differentiating a plant that chooses

Reports 2 and 3 each take one piece of TF24's carbon economy — the leaf's operating point,
and the light field it reads. This report takes the third and the one that binds them: the
water. Together the three cover every channel through which a trait reaches an emergent
TF24 output.

Every code reference below is TF24 at **develop**, read directly. Where a measurement was
made elsewhere, the text says so and section 12 marks it.

---

## 1. The proposal

In every other plant strategy a rate is a closed-form function of state and traits. TF24's
is not, and the reason is water. Each cohort **chooses** how hard to pull on the soil — it
picks a root-collar water potential that trades carbon gain against hydraulic risk — and the
sum of those choices drains a soil column that is itself ODE state, which then changes what
every cohort will choose next. So the object to be differentiated is not an expression but a
**loop closed through a choice**.

That has one consequence which is easy to state and hard to escape: **the gradient of every
census metric and of R0 passes through this loop.** Soil water is state, so its derivative is
carried for free; but the choice sits inside the loop, evaluated once per cohort per
Runge–Kutta stage, and if the choice is differentiated wrongly then every trait gradient TF24
can produce is wrong by a first-order amount.

Three things are needed, and the third is the one nobody has written down.

**1. Differentiate the choice through the condition that defines it.** develop's code and its
comments present the collar potential as the *maximiser* of carbon profit, and treat it as
smooth. It is neither. The objective has no interior stationary point: measured, it is a flat
shelf, a jump of about 1.5, then a smooth decline at slope **−8.8**, with the operating point
at the corner. The corner is where the inner assimilation solve's productive branch stops
existing. So the operating point is an **active constraint**, and every envelope-style
treatment of it — including the one report 2 proposes — drops a first-order term. What works
is already half-present in develop: a *bracketing* root-find on `dprofit_droot_collar_psi`,
which exists and is exact, safeguarded by the sign of that gradient at each end of the
bracket, with the derivative then taken from whichever condition the search found active.

**2. Assemble the uptake Jacobian with the traversal that already assembles uptake.** The
stand's water draw is a density-weighted trapezium over cohorts, per layer, summed over
species, divided by patch area. Its derivative has exactly that shape. Building it by the
same traversal with the same weights adds **no concept a Strategy author has to learn** —
which is the whole argument for this route over anything that introduces a soil-specific
adjoint vocabulary.

**3. State where a gradient of R0 is an object at all.** R0 is only a meaningful number above
about a 12-year horizon; near extinction it is ill-conditioned for *every* method while its
own trajectory converges cleanly; and at develop's default inner tolerance it is measurably
wrong. A gradient delivered without those bounds is a number a user will trust further than it
deserves. This is not a caveat to bury — it changes what the deliverable is.

**What this report does not claim.** Item 1's severity is *inferred*, not measured: the
prediction that develop's current adjoint is first-order wrong at the corner has never been
tested against a finite difference that re-solves the inner problem. That test is cheap, it is
first in section 10, and everything in items 1 and 2 is conditional on it.

---

## 2. State at develop: one turn of the loop

Five soil layers by default, carried as ODE state — `TF24_Environment::ode_size() > 0`, nine
entries. So `d/dtheta` needs no freezing decision and no recording; the depletion feedback
comes with the state.

Per cohort, per right-hand-side evaluation:

```
vars.state(i)                     soil moisture, ODE state
  -> psi_from_soil_moist          retention curve, floored at soil_moist_residual
  -> psi_soil_[k]                 positive magnitudes
  -> prepare_collar_solve         flips to psi_soil_inverted_, precomputes the
                                  per-layer cumulative-vulnerability lookups
                                  root_vuln_integral_soil_, and derives the
                                  feasible collar interval [bound_a, bound_b]
  -> find_root_collar_psi         util::golden_section_max over that interval,
                                  GSS_tol_abs = 1e-3
  -> opt_psi_stem_, profit_       the operating point
  -> E_from_Soil_to_Root_Collar   soil_consumption_[k] per layer, E_up_ total
  -> set_consumption_rate         per-cohort consumption_rate[k]
  -> Patch::resource_depletion    density-weighted trapezium over cohorts,
                                  summed over species, per patch area
  -> dtheta/dt                    and back to the retention curve
```

Four properties of this loop carry the rest of the report.

### 2.1 The bracket is soil-derived, so soil enters the choice twice

`prepare_collar_solve` derives `[bound_a, bound_b]` from the soil state itself: `bound_a` is
where uptake vanishes, `bound_b` where the stem reaches `psi_crit`. As the soil dries the
interval shrinks toward `psi_crit`. So moisture reaches the operating point **through the
bracket as well as through the objective** — which is what makes its dependence on soil state
different in kind from its dependence on plant height, and why a treatment that captures only
the objective channel is incomplete in a way that is invisible at fixed soil state.

### 2.2 The choice is made by a search whose smoothness develop relies on, and does not have

`find_root_collar_psi` calls `util::golden_section_max` at `GSS_tol_abs = 1e-3`. The code
explains the choice:

> *Unlike Brent, its argmax is a smooth (fixed-iteration) function of the inputs, so the
> operating point varies smoothly with plant height — the demographic growth-rate gradient
> relies on this.*

The stated dependency is real and the stated mechanism is false. Golden-section shrinks its
bracket by a fixed ratio and returns its midpoint; the iteration count depends only on the
bracket width and the tolerance, and the objective enters **only** through the comparison that
picks which half to keep. So for a fixed comparison pattern the returned argmax is an exact
affine function of the bracket endpoints and is **independent of the objective's values**. It
is not smooth in height — it is a staircase, locally flat, with steps of order the tolerance.

The comment is nonetheless valuable, because it names the consumer: `Node::growth_rate_gradient`
finite-differences the growth rate in height at `node_gradient_eps = 1e-6` to obtain the
demographic transport term. That stencil therefore differences a staircase of step `1e-3` at a
probe distance of `1e-6`, and survives only because the comparison pattern is locally constant
so the surrogate is locally affine. **`GSS_tol_abs` and `node_gradient_eps` are coupled**, and
this comment is the only place in the code that hints at it. Report 4 treats the stencil; the
point here is that its safety rests on the argmax's staircase, not on its smoothness.

### 2.3 The dry end amplifies, and the amplifier *is* the coupling

Decomposing the soil Jacobian along real trajectories separates hydrology (infiltration,
drainage, inter-layer cascade) from root uptake. Two stiffnesses appear, from two different
processes:

- **Drainage**, wet. `soil_K_from_soil_theta` is `K_sat · (theta/theta_sat)^(2·n_psi+3)`, an
  exponent of about **16.14**, so `dK/dtheta` reaches ~4600/day near saturation. Large, but
  **episodic** — it needs a fully wet layer.
- **Uptake stress**, dry. `psi_from_soil_moist` goes as `theta^(-n_psi)` with `n_psi ≈ 6.57`,
  so potential diverges and uptake becomes hypersensitive to small moisture changes. Measured
  uptake/hydrology ratio: **8× to 291×**.

In a real transpiring stand the **uptake term is the persistent floor** and drainage is a
spike riding on it; it dominates a semiarid run throughout and shows as dry pockets even in a
wet one. This matters here because the uptake term *is* the soil–plant coupling: **the
stiffness and the gradient channel are the same object.** The divergence exponent is measured
at **−6.56**, i.e. `−n_psi` — so the coordinate the state is carried in is implicated, not
merely the rate.

### 2.4 The coupling's own adjoint is ordered by the light field

The marginal value of soil water to cohort `j`, `lambda_j = (dP_j/dtheta)/(dE_j/dtheta)`,
measured per cohort on an 8-cohort stand with its frozen canopy light:

| theta | mean lambda | spread across cohorts (CV) | max/min |
|---|---|---|---|
| 0.34 (wet) | 3.04e5 | 35.6% | 2.40 |
| 0.26 | 3.31e5 | **60.0%** | **4.14** |
| 0.20 | 3.50e5 | 43.2% | 2.98 |
| 0.16 (dry) | 6.61e5 | 20.0% | 1.64 |

The spread is **systematic, not noise**: `lambda_j` is monotone in cohort height, because the
light gradient down the profile sets marginal water-use efficiency. Taller, better-lit cohorts
value water 2–4× more than shaded ones.

Two things follow. **The light field and the water coupling are one problem seen twice** — the
spread in the water coupling's adjoint is *generated* by the light gradient, so report 3's
accuracy target and this one's are linked through `lambda`. And **the elegant simplification is
dead**: recasting the coupling around a single shared price of water would misprice understory
against canopy by up to 4×. It survives only as a rule for future models (section 9).

---

## 3. The operating point is an active constraint, not a maximum

This is the load-bearing correction, and it invalidates a proposal in report 2.

**The measured geometry.** Mapping the objective finely across its peak at fixed state gives a
flat shelf on the wet side, a jump of about **1.5**, then a smooth monotone decline at slope
**−8.8**. The operating point is the corner at the top of the jump, roughly 0.01 MPa above
`bound_a`. Confirmed across wet-to-dry regimes; never a smooth interior stationary point.

**What the jump is.** Reading the evaluator's internals either side:

| side of the corner | `opt_psi_stem` | `ci` | net assimilation |
|---|---|---|---|
| wet (shelf) | pinned | 4.331 | **−1.5**, the `−R_d` floor |
| dry (live) | tracks the collar | 5.488 (**jumps**) | ~0, then productive |

The inner `ci`/assimilation solve has a productive branch and a non-productive fallback. On the
wet side the productive branch does not exist and the evaluator returns the fallback. The
operating point is **the last collar potential at which the productive branch survives** — a
constraint-activation locus.

**Three consequences, in order of severity.**

*The envelope theorem never applied.* At a true interior maximiser, the objective's error under
a perturbed argmax is second order. Measured, the profit floor scales as `O(eps)` — log-log
slope **1.06** against a predicted 2 — because with no stationary point
`profit(p_hat) − profit(p*) ≈ −8.8 · (p_hat − p*)`. Slope 2 was the sharpest available test of
the envelope framing, and it failed.

*Any adjoint that freezes the operating point is first-order wrong.* With `dprofit/dp ≠ 0` at
the operating point, nothing downstream is stationary — not consumption, not growth, not
profit. Freezing `p*` drops terms of size `(dc/dp, −8.8) · dp*/dstate` in every cohort solve,
into a functional that amplifies about 10×. **Untested; section 10 item 1.**

*Report 2's polish has no root to find.* Report 2 proposes a Newton polish on `dprofit/dp = 0`
behind an implicit-function node. There is no interior point where that holds, and the second
derivative its denominator needs is undefined at a corner. The measurement that made the polish
look successful — a residual of 4.541e-10, flat across tolerances — was taken on a toy whose
objective has a smooth interior maximum by construction, so it never met this geometry.

**The primitive that works, and most of it is already in develop.** A *bracketing* root-find on
the profit gradient rather than a Newton iteration on it. `Leaf::dprofit_droot_collar_psi`
exists on develop and is genuinely analytic: forward-mode AD of the assimilation and
hydraulic-cost algebra for `A'(ci)` and `C'(psi_stem)`, the implicit function theorem on the
stomatal `ci` equation for `dci/dp`, and analytic spline derivatives for the transport chain.
A bracketing method converges to a **sign change**, which is exactly what a corner is, and
needs only the gradient — never the missing second derivative. The safeguard is the endpoint
signs: gradient positive at `bound_a` and negative at `bound_b` means an interior sign-change
root; one-signed across the bracket means the optimum is at the profit-increasing boundary, so
clamp there.

**What a moving boundary costs, quantified.** Separately from the corner's stationarity
problem, any boundary whose *location* depends on the differentiation target contributes a
Leibniz term `[jump] x d(location)/d(theta)`. A subgradient tape drops it entirely; a finite
difference smears it over the perturbation; the ratio between the missing and the smeared term
is unbounded. Measured on a hard moving regime boundary: adjoint-against-FD degrades by
**five to six orders**, and smoothing the boundary at a declared scale restores **~1e-9**.
This is a general statement about differentiating a moving switch and does not depend on which
construct creates it — so it applies to the `ci`-branch corner, to `bound_b` pinning, and to
the shut-down test alike, wherever their locations move with a trait.

**Two distinct objects, not to be conflated.** The corner above is a `ci`-branch feasibility
edge *interior* to the bracket. Separately, the operating point is sometimes **pinned at
`bound_b`**, where `dprofit ≠ 0` for a different reason — the constraint is the bracket end
itself. Both need branch-specific derivatives; section 4's dispatch handles both.

**And one live finite difference inside the analytic gradient**, which report 2 section 8
already flags and this report can now locate exactly. `dprofit_droot_collar_psi`
computes `dE_up/dr` from `dE_from_soil_dpsi_collar`, which **returns NaN near a branch kink**
— a soil-layer crossing — and develop then falls back to a central difference on the transport
at `h = 1e-6`:

```cpp
const double dEup_dr = dE_from_soil_dpsi_collar(r, psi_soil_inverted_);
if (std::isfinite(dEup_dr)) { ... analytic ... }
else { /* central difference at h = 1e-6 */ }
```

So develop's analytic gradient is analytic *except* at layer crossings, where it is a finite
difference of a function containing inner root-finds. The incidence of that fallback on a
production run is **unmeasured**, and it is the one place where the recommended primitive
inherits a numerical seam rather than removing one.

---

## 4. The uptake Jacobian, and the dispatch rule that makes it work

What the coupling needs is `d(consumption_rate[i])/d(theta_k)` per cohort, aggregated to the
stand. Each partial can be a difference of a **closed-form** leaf function at the **fixed**
operating point — no re-solve, and no finite difference through a search.

Two branches, both required:

- **interior optimum** — the implicit function theorem on stationarity:
  `dP*/dpsi_k = −g_k/g_P`, then
  `dc_i/dpsi_k = [dc_i/dpsi_k]_{P* fixed} + (dc_i/dP*)(dP*/dpsi_k)`.
- **boundary-pinned** — the operating point tracks the active bound, so the response comes
  from the implicit function theorem on *that bound's* defining continuity condition:
  `E_column_zero = 0` at `bound_a`, `E_column(·, psi_crit) = 0` at `bound_b`.

Validated against a finite difference of a full operating-point re-solve, 45 soil states,
driest layer 0.2–4.6 MPa, inner tolerance 1e-12:

| | median | p90 | max |
|---|---|---|---|
| all states | 4.2e-5 | 1.4e-4 | 6.1e-4 |
| dry tercile | 4.0e-5 | 2.0e-4 | 6.1e-4 |
| wet tercile | 5.4e-5 | — | 8.6e-5 |

**The dispatch rule is the transferable finding, and it was found the hard way.**
Interior-only was `4.5e-2` wrong in the dry tercile — a real error, not FD noise; it did not
shrink as tolerance and step were tightened. Adding a boundary branch dispatched by a
**residual threshold** (which of the two continuity residuals is near zero at the operating
point) fixed most states but left three at **30–50%**, because the threshold mis-selected.
Dispatching instead on the endpoint gradient signs — **the same test the solve itself used to
choose the operating point** — drove the worst case from `5.0e-1` to `6.1e-4`.

> **Key the derivative branch off the same test the solver used to pick the operating point,
> never off a re-derived proxy for it.**

Error correlates with boundary-pinning (Spearman 0.71 against the stationarity residual), not
with dryness as such; dryness matters only because it makes pinning more frequent as the
feasible interval shrinks.

**On develop at production settings the boundary branch is never taken, so it is insurance
rather than load-bearing.** Report 2's census counted it directly: across **4 372 101** leaf
solves at `max_patch_lifetime = 105.32`, the argmax is pinned at `bound_b` **zero** times, and
at `bound_a` zero times. A fivefold rainfall reduction changes nothing; tenfold gives 267 of
343 779 (0.08%); twentyfold gives 110 984 of 330 021 (33.6%) — but that stand is largely dying
(about 280 accepted steps against 2 153), so the 33.6% is over an unrepresentative population.
The dry-weighted validation sample above, at ~40% pinned, corresponds to that twentyfold
regime. So the interior branch is the production path.

**But report 2's census cannot see the corner, and that is the open measurement.** It
instrumented the five early exits and endpoint-pinning. The corner of section 3 is neither: it
is interior to the bracket and non-stationary. So "every solve is a strictly interior optimum"
means *interior to the feasible interval*, not *at a stationary point* — the two readings are
easy to conflate and only the first was measured. **The corner's incidence on develop is
therefore unknown**, because no counter exists for it. That is a different and more important
number than the pinning fraction, and nothing in either report supplies it.

**Aggregation adds no vocabulary.** The stand Jacobian is the same density-weighted trapezium
over cohorts, summed over species and divided by patch area, that `Patch::resource_depletion`
already runs — the same traversal, the same weights, with the retention factor folded in per
layer so everything above it stays environment-agnostic. The retention chain closing the loop,
`dpsi_inverted_k/dtheta_k = n_psi · psi / theta`, is **exact** — checked against a numerical
derivative of `psi_from_soil_moist` to full precision — and correctly **zero** where the curve
is floored at `soil_moist_residual`.

One caveat carried from the validation: the interior branch's operating-point response is
itself a finite difference of the analytic gradient, which contains inner root-finds. It was
validated at inner tolerance 1e-12; at develop's tolerances this differencing is not obviously
clean, and that is unmeasured.

---

## 5. What the soil never does, and what that licenses

develop's soil rate carries four non-smooth constructs and the leaf carries a shut-down
discontinuity. All five have been treated as things a gradient design must handle. On the
sampled envelope, none is reached.

**Why the dry end is unreachable.** Conductivity goes as the ~16th power of moisture:

| theta | K (mm/day) | psi_soil (MPa) |
|---|---|---|
| 0.428 (saturation) | 1.6e+2 | 0.002 |
| 0.150 | 7.3e-6 | 1.75 |
| 0.120 | 2.0e-7 | 7.6 |
| 0.010 (`soil_moist_residual`) | 3.5e-24 | floored |

By `theta ≈ 0.12` a bare column at half saturation loses **0.015 over ten years**. Drainage
cannot carry the soil into the deep-dry band, and root uptake declines as potential rises. So
residual moisture is an **asymptote approached in infinite time, not a floor hit in finite
time**. Measured minimum over every scenario: **theta = 0.133**, against a residual of 0.010.

**And the guards are measured never to fire.** Instrumented over a scenario bank including a
30-year extended drought: the soil clamp and runoff signatures never fire; the collapsed-bracket
exit never fires; about **99.8%** of cohort solves take the ordinary search branch; the only
discrete event occurring at all fires on under **0.5%** of steps.

**Leaf shutdown is structurally hard to reach, and the mechanism is specific to how the test is
keyed.** `prepare_collar_solve` computes `wettest_soil_layer = max_k(psi_inverted_k)` and shuts
down only when `−wettest_soil_layer >= psi_crit`. So a cohort shuts down only when **every**
rooted layer is drier than critical — one benign layer keeps it transpiring. In a 12-year
zero-rain drydown the top two layers reach 5.13–5.34 MPa against `psi_crit ≈ 5.6` while the
bottom layer sits at **0.37 MPa**; measured with four of five layers past critical and no
shutdown. The stand dies of carbon starvation from the drying topsoil while still rooted into
deep water it never exploits — 38% of rainfall over 16 years leaves as deep drainage, and there
is no upward capillary flux between layers.

**What this licenses, and what it does not.** It upholds the decision not to smooth the soil
kinks: a zero derivative is what the model means at those, and they are not on the sampled path.
It does **not** license removing them — the dry-end floor is held by the *physiology*, not by any
choice of state variable. With the vulnerability shut-off disabled, raw moisture runs to
**−17.85** and a log-depletion chart gives **NaN**; a re-charting of the soil state is not a
substitute for the shut-off.

Nor does it license calling the constructs unreachable in general. **This is an envelope, not a
theorem.** The load-bearing margin is thin: develop's retention curve reaches `psi_crit ≈ 5.9`
at `theta = 0.1246`, and the measured driest layer is **0.133** — `psi = 3.85`, a margin of
**2.05 MPa** or 6% in moisture. A shallower-rooted strategy, a drier driver, or a
root-weighted rather than wettest-layer keying would each close it. An earlier version of this
report read "never fires" as licence; it is better read as *one sampled envelope, with a 6%
margin, on a keying that is itself a modelling choice.*

---

## 5b. The conditioning of the loop, and what its structure permits

Three facts about the loop as an operator. They decide whether the problem is well-posed at
all, and they bound what any solver can buy.

**The coupled fixed point is well-conditioned, so a converged answer exists.** Arnoldi on the
self-consistency map `T: a -> u -> members -> a` at its fixed point: spectral radius
`rho(T') ~ 7-8`, with the dominant modes at negative real parts and large imaginary parts —
far from `+1`. The nearest mode to `+1` is real and sits **0.05-0.2** away, so `(I - T')` is
non-singular and `||(I - T')^-1|| ~ 5-22`. **Nothing sits at `+1` and there is no tight cluster
pinned to it**, which a genuinely marginal mode would produce.

That is the result that makes this whole exercise well-posed: **the continuum R0 exists and is
a stable observable of the model**, so the non-convergence in section 6 is a discretisation
protocol artefact rather than ill-posedness. It also reads the ~23% spread between independently
converged schemes as conditioning (5-22) times an O(1-5%) discretisation error, not a divergence.
Caveats: the matvec carries ~1.8% round-trip noise so subdominant Ritz values are noise-limited,
and it is one sequence at one horizon; the robust reads are `rho ~ 7-8` and the gap at `+1`.

**The large spectral radius is a different fact from the conditioning, and it kills relaxation.**
`rho(T') ~ 7-8` far from `+1` is *good* conditioning but an *amplifying* operator, which is why
iterating the coupling to self-consistency fails (section 7) — and why a small error in uptake is
not a small error in the answer.

**The near-bound eigenvalue is chart-invariant.** Linearising a layer's balance near depletion
gives `lambda = gamma * r / (d * delta*)` — turnover is throughput over stock — which diverges as
the stock depletes. No change of state variable removes it. It splits into two regimes with
different remedies: a **fall** regime, where the input collapses and the step is
accuracy-limited, so no method enlarges those steps; and a **floor** regime, sitting at the
depleted balance, where the step is stability-limited and an implicit method wins. A chart can
delete a clamp and restore floating-point conditioning; it cannot remove this timescale, and it
cannot hold a bound the physics does not (section 5).

**The soil block's structure is favourable and under-exploited.** `TF24_Environment`'s
inter-layer cascade is one-directional — layer `k` drains to `k+1` with no back-transfer — so the
soil Jacobian is **lower-bidiagonal plus diagonal**. Real spectrum, no oscillatory stiffness, and
an implicit step solves it by forward substitution with better adjoint conditioning than a general
solve. At `L <= 5` that is nearly free. `RODAS4(3)` and `ode_jacobian.hpp` are already on odelia
master, and are not reachable from the SCM patch today (no rebind hook, no active scalar) —
which is a plumbing gap, not a design question.

---

## 5c. What the numerics can and cannot buy

Measured levers, including the ones that turned out not to be levers. These bound any solution
without prescribing one.

**The functional needs only the weekly-and-slower envelope of soil moisture — the largest
untaken arbitrage.** Low-passing the soil trajectory and re-advancing the cohorts against it:

| texture removed below | R0 / R0(unfiltered) |
|---|---|
| ~half a day | 1.022 |
| ~2 days | 1.028 |
| ~1 week | 1.136 |
| ~1 month | 2.273 |
| ~3 months | 15.6 |

R0 is invariant to ~3% under removal of *all* sub-2-day texture and bends by 14% at the weekly
scale; the knee sits between weekly and monthly. The shared step is sub-daily (0.07-0.26 day),
so the O(M) cohort block is integrated **30-100x finer than the functional requires**. Caveats:
open-loop (the probe sees the filtered trajectory but does not feed back, and the loop gain is
~10x), one sequence, and soil moisture only. A burst-dominated driver could move the knee finer.
This arbitrage is gated on a cheap refresh of the coupling at the fast rate — which is exactly
what section 4's Jacobian is.

**Order matters more than step size on the cohort block, and the fix costs no vocabulary.** A
first-order advance of the slow block left a **12%** R0 bias at a weekly leg, converging as the
leg shrank (8.4% at 3.5 d, 1.2% at 1.75 d — the first-order signature) so that reaching ~1%
needed a 1.75-day leg and ate the speed win. Raising the coupling order to third fixed it at the
*same* leg while keeping the cohort-solve reduction. Two properties worth carrying: reverse
replay stays safe because the stage count is deterministic, so record and replay take identical
structure; and it was taken as an outright swap rather than a control key, on the explicit
grounds that a key would be "a permanent concept every user must learn."

**A replay cache should store the field, not the builder.** Caching a full environment copy per
Runge-Kutta sub-step included the light interpolant's *adaptive builder* and the band-solve
workspace — build-only state a replay never reads. Storing only knots, values and the environment
ODE state, and rebuilding through the existing initialiser, is a **bit-identical** reconstruction
and took a 12-year run from **>15 GB to 1.14 GB**, with every dependent number reproducing to the
printed digit. This bears on report 1's memory case and on report 3, whose subject *is* the
builder being cached.

**Frozen-field replay is faithful exactly in the rare limit.** The error is O(mass fraction) and
vanishes as the probe's weight does: relative R0 gap **63.4** at mass fraction 0.388, 0.424 at
0.060, 0.036 at 0.0064, 0.003 at 0.0006. So the mutant path is valid where it is used — marginal
members and rare invaders — and invalid for a heavy probe, where feedback is superlinear.

**Down-weighting the step-limiting cohorts is a modest lever, because they overlap the cohorts R0
needs.** About 30% of accepted steps are limited by the soil block, which a cohort-weighted error
norm cannot touch at all; of the cohort-limited remainder, 14-21% are set by a *dominant* cohort
that must keep full weight; and within the marginal rest, **a third to a half are dying** —
heading to the absorbing density boundary, which is precisely what R0 is most sensitive to.
Cleanly reclaimable: roughly **10-20%** of accepted steps. The measured tension is structural: a
cohort crossing the survival threshold has fast local dynamics (so it sets the error norm) *and*
is R0-critical, so the two populations are not separable by weight alone.

---

## 5d. What couples across reports 2, 3 and 5, and is not closed

Five links between the three coupling reports. Each is a statement about data that does not
exist yet, not a proposal.

**The corner is not in report 2's branch census, so that census undercounts.** Report 2
enumerates the leaf's discrete structure as five early exits from `prepare_collar_solve` plus an
uncounted sixth case (the operating point pinned at `bound_b`). The `ci`-branch corner of
section 3 is **none of those**: it is a jump *inside* the objective evaluation — the inner
assimilation solve's productive branch ceasing to exist — reached on every ordinary call, not an
exit from the setup. So the leaf carries at least one discrete structure that the census was
built to enumerate and did not. Whether there are others inside the objective is unexamined;
the census instrumented exits, and this one is not an exit.

**Replacing the search may change what the transport stencil differences, and the sign of that
change is unknown.** develop's comment (section 2.2) states that
`Node::growth_rate_gradient` relies on the argmax varying smoothly with height. Section 3's
bracketing locator removes the `GSS_tol_abs` staircase, which is what fixes R0's value
(section 6). But the stencil's present safety comes *from* the staircase being locally flat: it
differences a surrogate that is locally affine in height. An exactly-located corner varies with
height genuinely — which should be better, unless the corner **swaps branch** as height changes,
in which case the exact operating point jumps and the stencil differences a discontinuity at
`node_gradient_eps = 1e-6`. Nobody has measured whether the corner's location is continuous in
height. This is the one place where a fix in this report could degrade report 4's subject, and
it is cheap to check: track the corner's location across a height sweep at fixed soil state.

**Report 3's slope accuracy target should be set by this report's `lambda`, and is not.**
Section 2.4 establishes that the spread in the water coupling's adjoint is *generated* by the
light gradient down the profile. So an error in the light field's **slope** propagates into
`lambda_j` and hence into the water coupling's adjoint. Report 3 measures its slope error
(1.9e-2 globally normalised at develop's 65 knots, against the value-fitted cubic's 2.9e-2), and
this report measures `lambda`'s spread (CV 20-60%), but **the transfer function between them is
unmeasured** — so neither report can say what slope accuracy the coupling actually requires.
Report 3 currently chooses its knot set on a build-cost argument. It should be chosen on this.

**Report 1's cohort purity is supported by the soil-side reads, and that is worth stating
because report 1 rests on it.** Reading `prepare_collar_solve` at develop: `psi_soil_inverted_`
and the per-layer cumulative-vulnerability lookups `root_vuln_integral_soil_` are **rebuilt at
the top of every solve** from the current soil state, so they are genuine per-solve scratch and
carry no history between cohorts. That is a precondition for report 1's cohort-granular
recording, verified rather than assumed. It does **not** extend to `TF24_Environment`'s
`psi_soil_cache_`, which is a different object keyed on an exact `double` comparison of state,
nor to the shared-`Leaf` staleness of C9.

**Report 1's memory argument has a second axis it does not count.** Report 1 prices reverse-mode
memory in tape bytes. Section 5c's cache measurement is a different axis on the same path: a
replay cache that stored the light interpolant's *builder* rather than its knots cost >15 GB at
12 years and 1.14 GB after, bit-identically. Any per-cohort or per-step recording scheme
inherits that distinction, and report 1 does not currently mention it.

**One quantity all three reports need and none has measured.** The operating point's sensitivity
to state, `dp*/dstate`. Report 2 needs it for its node's local Jacobian; section 4 needs it for
the interior branch of the uptake Jacobian; report 4's stencil differences a growth rate that
depends on it. It has only ever been reached indirectly — through the validated uptake Jacobian,
or inferred from the argmax's behaviour. Measuring it directly at a transpiring state, in both
the interior and boundary-pinned regimes, would serve all three at once and is the natural
companion to section 10 item 1.

---

## 6. Where R0 is an observable, and where it is not

Three measured bounds. None is recorded anywhere a user of a gradient would meet it, and
together they define the envelope in which a gradient of R0 means anything.

**R0 needs a long horizon.** Offspring against patch lifetime, single resident: 3 yr `1.1e-15`,
5 yr `4.1e-13`, 8 yr `5.4e-10`, 12 yr `2.7e-7`, 20 yr `1.4e-5`. Below about 12 years the run is
pre-reproductive and R0 sits on the numerical noise floor. **Verification at short horizon is
void**, however convenient — which rules out the cheap-and-short strategy directly.

**At develop's default inner tolerance, R0 is wrong, non-monotonically.**

| `GSS_tol_abs` | offspring (one scenario, 12 yr, outer tolerance 1e-6) |
|---|---|
| **1e-3 (develop's default)** | **1.412e-7** |
| 1e-4 | 5.90e-8 |
| 1e-5 | 1.413e-7 |
| 1e-6 | 5.871e-8 |
| 1e-8 | 5.868e-8 |

Converged only at 1e-6 and below. A marginal cohort's survival flips with the sub-1e-3 argmax
staircase, so tightening does not monotonically improve it. Section 3's exact locator removes
this at the source — which is the strongest argument for it: the same change fixes the speed,
the gradient, and a wrong value.

**Near extinction the functional is ill-conditioned for every method, while its trajectory is
fine.** Refining a method's *own* time discretisation moves offspring by O(1)–O(10),
**non-monotonically** (one trace: `8.2e-8 → 1.5e-8 → 4.7e-6`), while the soil trajectory
converges to `5.5e-4` on the same refinement. **A trajectory-convergence result is not a
functional-convergence result.**

Two practical consequences for verification:

*The rainfall stress bank is a speed and robustness vehicle, not an accuracy vehicle.* Its six
traces give offspring `1e-8`–`1e-13` even at `birth_rate = 20`; an lma sweep 0.04→1.0 is
monotone-decreasing at best ~`2e-10`; scaling rainfall 1×→20× never lifts one trace above
~`1e-9`. **The same species and birth rate give offspring 1.03 under constant rainfall.** The
traces were built as soil-integrator stress tests, so they sit permanently in the
ill-conditioned regime, and Cash–Karp does not complete three of them at converged tolerance —
a model-level density divergence, not a solver overflow, so no reference exists there either.
Accuracy has to be judged where R0 is O(1): the model's own seasonal driver at the sustaining
rainfall mean with amplitude dialled up. An earlier version of this report had this backwards.

*Both of develop's tolerance families must be stated.* `GSS_tol_abs = 1e-3` is the inner one;
`ode_tol_rel = ode_tol_abs = 1e-4` is the outer. Converging one leaves the other's error in the
reference — elsewhere this invalidated an entire accuracy table, moving one headline from
`1.8e-4` to `3.5e-3`.

**And R0's non-convergence under schedule refinement is entirely the water feedback.** Three
experiments: freeze the soil trajectory and add 1.5× more cohorts without letting them feed
back, and offspring moves by **~0%** (6e-10) — the reproduction quadrature is already converged;
let the same cohorts feed back and it moves **69–84%**; and the shift is diffuse across the
productive early cohorts, with the three largest-changing points carrying 2–3% of the total, so
it is **not** a spike at a cohort crossing the survival threshold. Independently, putting a
denser measure on a *common frozen field* moves R0 by ~0% while letting the field respond moves
it 69–84% — **100% of the change is coupling-field shift, ~0% is quadrature.**

So the schedule is under-resolving the **water-uptake field over time**, and develop's
refinement heuristic — which flags cohorts by their contribution to reproduction — targets a
quantity that is already converged, and has been measured to anti-correlate with the true error.

---

## 7. What is measured out

Recorded so it is not re-derived. Each of these was proposed, built or believed, and then
refuted by measurement.

| claim | refuted by |
|---|---|
| the inner argmax floor drives the ~30% step rejection | rejection fraction invariant to a 1000× change in `GSS_tol_abs` |
| a minimum-step clamp forces uncontrolled accepts | one step at the floor (0.0%); and on develop `ode_step_size_initial` and `ode_step_size_min` are **both 1e-6**, so the two cannot be told apart there |
| a Newton polish on stationarity is the fix | no interior root exists (§3) |
| drainage is the dominant stiffness | uptake stress dominates 8–291× in a transpiring stand (§2.3) |
| an intrinsic survival discontinuity blocks R0's convergence | 100% coupling-field shift, diffuse (§6) |
| the cohort measure is granularity-limited by a heavy atom | heaviest cohort carries ~1.6%, halving per mesh doubling; the ~40% figure misread a second species' share of two-strategy R0 as one cohort's share within one species |
| iterating the coupling to self-consistency removes the global step control | one Picard sweep amplifies by ~10× in every 2-year window, and for expansive positive gain the damped iteration has spectral radius `\|1+9w\| > 1` for **every** `w > 0` |
| the daily forcing lattice explains the cost wall | size-matched, knot-crossing steps reject +12 to +36 pp more — a real third-derivative effect — but only 1.3–3.9 pp of the 27–31% total |
| a shared price of water would collapse the coupling | `lambda_j` spread 2–4× across cohorts, monotone in height (§2.4) |
| envelope smoothness in the adjoint is safe | the corner: nothing is stationary (§3) |

**Two were mine.** Reading §5's never-firing guards as licence rather than as an envelope with
a 6% margin; and importing a dead drought-gradient channel from a branch whose `soil_psi_max_`
member **does not exist on develop** — develop floors moisture inside `psi_from_soil_moist`
instead, 13× below the operating range, so the severance that branch measured is genuinely
unreached here. The pattern in both: taking a measured symptom and its attributed mechanism as
one package.

---

## 8. Constraints

**C1. Soil water must stay ODE state.** Treating it as a background driver drops the depletion
feedback, which §6 shows is 100% of R0's own convergence error.

**C2. Soil enters the choice twice** — objective and bracket (§2.1). A treatment capturing only
the objective is incomplete, invisibly so at fixed soil state.

**C3. `GSS_tol_abs` and `node_gradient_eps` are coupled** through the argmax staircase (§2.2).
Changing the inner search changes what the demographic transport stencil differences.

**C4. develop's analytic profit gradient contains a finite difference** at soil-layer crossings,
`h = 1e-6` (§3). Incidence unmeasured.

**C5. The interior branch's response is a finite difference of that gradient**, validated only
at inner tolerance 1e-12 (§4).

**C6. Boundary-pinning has zero incidence at production** (§4, report 2's census over 4.37M
solves), so §4's boundary branch is insurance. What is unknown is the **corner's** incidence,
which no counter measures — report 2 instrumented exits and endpoint-pinning, and the corner is
neither.

**C7. Values change.** The exact locator moves offspring by 8.2e-5 to 6.8e-4 across a bank — in
the *correct* direction, since the default is wrong by 2.4× in the bifurcation-prone case (§6).
Re-blessing needs the converged reference, not the current one.

**C8. The unreachability results are an envelope with a 6% margin** (§5), on a wettest-layer
keying that is itself a modelling choice.

**C9. `Leaf` is shared through the Strategy pointer**, so the operating point,
`soil_consumption_`, `E_up_` and the soil caches are per-solve scratch on an object several
cohorts see in turn. A shut-down cohort that leaves `soil_consumption_` and `E_up_` stale feeds
a previous cohort's draw into the balance. The general hazard is that any *new* per-solve field
on `Leaf` has the same shape, and nothing structural marks which fields are transient.

**C10. Verification needs a stated regime**: horizon ≥ 12 years, R0 well-conditioned, both
tolerance families converged (§6). No global explicit reference exists on the hard traces.

---

## 9. For the System designer: what this generalises to

None of the following is TF24-specific. They are the shapes that made this model hard to
differentiate, and any scientific model with a choice, a shared resource, or a threshold will
meet them.

**A model that *chooses* is not a model that *computes*, and the derivative comes from the
condition that defines the choice.** Write down what holds at the operating point — a
stationarity condition, a branch-existence condition, an active bound — and differentiate
*that*. "It is the maximum of X" is a description, not a condition; here it was also false. If
the choice can be made by different mechanisms in different regimes, then **the derivative must
branch on the same test the solver used**, never on a re-derived proxy. A residual threshold
that looks equivalent measured 30–50% wrong where the sign test measured 6e-4.

**Ask what gradual process a hard switch is standing in for.** A hard switch in place of a
smooth response costs three things at once: stiffness, a moving non-differentiability, and — if
it saturates rather than vanishing — a dead gradient channel. All three are symptoms of one
misrepresentation, and they come back together when it is fixed. This is the most reliably
positive-sum move available: better mechanism, better conditioning, better derivative, no
trade.

**The coordinate is part of the model.** When the divergence exponent of a coupling equals the
exponent of the curve that defines the state's meaning, the *state variable* is implicated and
not just the rate. Carry state in the variable the process is smooth and bounded in. But be
clear about what a chart can and cannot do: it can delete a clamp and restore floating-point
conditioning; it cannot remove an intrinsic timescale, and it cannot hold a bound that the
physics does not.

**A reduction over members creates a switch keyed on one member.** TF24's shut-down fires only
when *every* rooted layer is past critical, because the test is a `max` over accessible layers.
That is a defensible modelling choice which also makes the event the model exists to represent
nearly unreachable. Whenever a threshold is keyed on an extremum over components, check its
reachability before designing around it — and check whether the keying, not the threshold, is
what you meant.

**The adjoint of a shared resource is a price, and its spread across members decides which
simplifications exist.** If the marginal value of the resource is near-uniform, the coupling can
be posed as a shared tariff and collapses to a gradient flow — the fed-back flux becomes the
objective's own marginal, and the whole control apparatus leaves the inner loop. If it is not,
that route is closed. There is a cheap standing test: sample the control across its feasible
range at fixed state and regress `dP/du` against the flux `E`; the collapse holds only if that
is affine with a member-independent slope. A dozen closed-form evaluations, no re-solves, and
worth running **per new member model** rather than reasoned about. Designing a model so the
fed-back quantity *is* the objective's marginal buys the collapse by construction.

**Assemble a derivative with the traversal that assembles the quantity.** If a flux is a
density-weighted trapezium over members, so is its Jacobian, with the same weights. This is what
keeps the concept count flat as models are added: the Strategy author writes the science once
and the derivative follows the same shape.

**A functional can be ill-conditioned while its trajectory converges.** Check the functional's
conditioning before quoting any gradient of it, and state the regime. A non-monotone tolerance
sweep is a property of the regime, not necessarily a bug. And converging one tolerance family
while another sits at its default produces a reference that is not one.

**Declare per-solve scratch, and clear it on every exit path — including the early ones.** A
field left stale by one exit becomes a previous member's value entering this member's balance.

---

## 10. What to measure, and where the open work lives

Ranked by what each would settle rather than by cost.

1. **Is the frozen-operating-point adjoint first-order wrong at the corner?** Reverse-mode
   `dJ/dtheta` against a finite difference that **re-solves** the inner problem, on a
   transpiring state, in a regime satisfying §6. §3 predicts it fails. Everything in §3 and §4
   is conditional on this, and it is inferred, not measured. *(task 49)*
2. **How often is the operating point at the corner?** Not the same question as pinning, which
   report 2 measured at zero incidence for production. Nothing counts the corner, and its
   incidence decides whether §3 describes the production path or an edge case. *(task 52,
   re-scoped)*
3. **Does the interior branch survive develop's inner tolerances?** Validated only at 1e-12
   (C5). *(task 53)*
4. **How often does `dE_from_soil_dpsi_collar` return NaN on a production run?** C4's fallback
   is an unmeasured finite difference inside the gradient this report recommends. *(new)*
5. **What is the pinning margin under a shallower rooting depth or a drier driver?** §5's 2.05
   MPa is one trait set on one envelope. *(new)*
6. **A multi-level field-shift sequence.** §6 measured one refinement step; a second licenses an
   extrapolated reference and a field-convergence rate. *(task 54's prerequisite)*

Open work by TF24 component, so it can be triaged against the code rather than against this
document:

| component | open items |
|---|---|
| `Leaf` operating point (`find_root_collar_psi`, `prepare_collar_solve`) | 49 corner adjoint; 52 pinning fraction; 53 interior branch at production tolerance; NaN-fallback incidence (new); 32, 33 the TF24f tracked collar |
| `TF24_Environment` soil block | pinning margin under other traits/drivers (new); 48 the kink manifest, for which §5 is the soil half |
| light field (`ResourceSpline`, `CanopyShape`) — report 3 | 50 the unattributed 91% of a spline rebuild; 51 the real-knot-set falsifier; 46 per-species eta |
| node schedule / measure | 54 retarget refinement at the coupling field, not reproduction; 27 the TF24 gradient FD-verification, which C10 re-scopes to ≥ 12 years |
| transport term (`growth_rate_gradient`) — report 4 | C3's coupling to `GSS_tol_abs`; routes A/B/C unmeasured |
| verification surface | 55 the anchor's domain; 44, 45 the R0 restore path |
| engine (report 1) | 35 the step-local sweep; 4, 34 mutant-record cleanup; 47 the calibration contract |
| odelia | 56 the non-finite step guard's full-suite run |

---

## 11. What would falsify this

- **The adjoint matches the re-solving finite difference at the corner.** Then the
  frozen-operating-point channel is adequate, §3's severity is overstated, and only §6's value
  bounds survive.
- **The locator does not flatten R0 across `GSS_tol_abs`.** Then the flip is not driven by the
  argmax staircase, and the 2.4× stands unexplained.
- **Boundary-pinning is rare in run.** Then §4's boundary branch is near-dead weight and the
  interior IFT alone suffices — good news, and measurable before any build.
- **The interior branch degrades at develop's inner tolerance.** Then the cheap
  operating-point response is unavailable where it is wanted.
- **A trait set reaches shutdown or a soil clamp with non-negligible frequency.** Then §5's
  licence lapses for that region.
- **`lambda_j`'s spread collapses on a fuller cohort population.** Then the shared-price route
  reopens and most of §4 is unnecessary.

---

## 12. Measured, versus inferred

**Measured on develop, read directly this session:** the loop of §2 and every symbol in it;
`GSS_tol_abs = 1e-3`, `node_gradient_eps = 1e-6`, `ode_tol_rel/abs = 1e-4`,
`ode_step_size_initial = ode_step_size_min = 1e-6`, `soil_moist_residual = 1e-2`; the
golden-section call and its comment; `dprofit_droot_collar_psi`'s construction and its
`h = 1e-6` NaN fallback; the wettest-layer shut-down keying and the `E_column < 0` exit; the
retention and conductivity exponents; the absence of `soil_psi_max_`.

**Measured elsewhere, mechanism verified against develop:** the corner geometry and the `ci`
jump; the profit floor's slope 1.06; the two-branch Jacobian's accuracy and the residual-dispatch
failure; the exact retention factor; `lambda_j`'s spread; the two-stiffness decomposition; the
R0 tolerance and horizon tables; the field-shift decomposition; the guard incidences; the
conductivity table and `theta_min = 0.133`.

**Inferred, not measured:** that the corner makes develop's *current* adjoint first-order
wrong. The mechanism is sound and two independent reasoners converged on it, but it is an
argument. Section 10 item 1 exists to test it rather than assume it.

**Not applicable to develop, and recorded to prevent re-import:** the branch's
`soil_psi_max_`-driven dead drought-gradient channel (§7).
