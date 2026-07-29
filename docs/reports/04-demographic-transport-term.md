# The demographic transport term

A sketch, for deepening. It concerns `Node::growth_rate_gradient` and the parameter
sensitivity of cohort density. The problem is established by reading develop; the three
candidate solutions are argued but not yet measured, and section 6 says what to measure.

---

## 1. The proposal

Cohort density evolves by

    d(log_density)/dt  =  -dg/dh  -  mortality

where `g` is the height growth rate and `-dg/dh` is the advection (compression) term of
the size-density equation. `dg/dh` is not available in closed form, so develop computes
it with a finite-difference stencil — and evaluates that stencil in plain `double`.

**Consequence: the parameter derivative of the transport term is dropped, so
`d(census)/d(trait)` is missing a first-order channel.** Every census metric is a
mass-weighted reduction `sum_i n_i psi(state_i)` with `n_i = exp(log_density_i)`, so a
trait's effect on how density compresses as cohorts grow does not reach the answer at
all. On the AD branch this is explicit: the active arm of `growth_rate_gradient`
computes the stencil in `double` on a scratch copy and returns `value_type(fd_value)`,
discarding the derivative.

The existing workaround is to change what the ODE transports, choosing a variable in
which the compression term cancels identically so that no numerical derivative appears
on the differentiated path. That works, and it is invasive: it changes the integrated
state, the reconstruction of density from it, the overflow behaviour at small cohort
spacing, and the coincident-cohort case. **This report is about doing without it.**

**The claim to attack is a conflation.** develop's own account of the stencil says two
things, and only the first is true:

1. *The stencil's value defines the production trajectory.* The one-sided difference is
   the discretisation actually solved, and substituting the analytic `dg/dh` changes the
   trajectory — measured on the AD branch as needing a growth clamp smoothed to
   `eps ~ 5e-2` to stay bounded, a roughly 6% change to K93's demography.
2. *Therefore the stencil must be evaluated in `double`.* This does not follow.

A finite-difference stencil is an ordinary differentiable function of the quantities it
differences. Evaluating both growth-rate evaluations at the active scalar leaves the
value bit-identical — same arithmetic, same order — while the derivative becomes the
derivative of the scheme plant actually solves. Nothing about the trajectory changes.

**Three routes, and they are not equivalent:**

| | route | value change | cost | differentiable |
|---|---|---|---|---|
| **A** | evaluate the existing stencil actively | none | already paid forward; one extra recording per cohort per stage | yes, amplifying roundoff by `1/eps` |
| **B** | difference across neighbouring cohorts instead of a sub-grid probe — **chosen** | yes, unquantified | **free** both directions | yes, amplifying by `1/spacing` |
| **C** | smooth the growth clamp, then use analytic `dg/dh` | yes, and it removes the upwinding | cheapest per call | yes, and unstable for that reason |

**The decision is B**, and section 1b sets out why. In short: any first difference of active
derivatives divided by `eps` amplifies roundoff by `1/eps` whether or not the differenced
quantity is smooth, the cohort spacing is four to five orders larger than `1e-6`, differencing
on the cohort grid is the discretisation a method-of-characteristics scheme already has, and it
costs nothing in either direction. C is rejected on principle: substituting the analytic
`dg/dh` removes the upwinding.

**One hard dependency, and it is a measurement rather than a fix.** Route A divides a
difference of two derivatives by `node_gradient_eps = 1e-6`, so it amplifies any error in
`dg/d(trait)` that is not smooth in `h` by a factor of `1/eps`. TF24's growth rate depends
on a leaf operating point whose displacement from the true optimum moves in steps with
height (section 5). Whether that amplification is real at production settings is measured
before route A is built (`../build-plan.md` §5b, M4), on K93 first as a control. Route B's
divisor is the cohort spacing rather than `1e-6`, five or more orders larger, so it is far
more tolerant.

Route A's forward cost is already paid. `Node::compute_rates` calls `growth_rate_gradient`
after `individual.compute_rates`, and that evaluates `growth_rate_given_height` on a
`thread_local` scratch — so the second rate evaluation, including TF24's leaf solve, is
already in the measured 53 s. Route A costs recording it, not evaluating it.

---

## 1b. The decision: difference across cohorts

Four reasons, in order of weight.

**1. Conditioning, and it does not depend on smoothness.** Route A's derivative is a first
difference of two parameter-derivatives divided by `node_gradient_eps = 1e-6`. Even with exact
AD on both terms, two O(1) quantities carried to a relative accuracy of about 1e-16, differenced
and divided by 1e-6, leave an absolute error of about 1e-10. Whether that matters is the ratio
of that error to the second partial being estimated, and it is present before any staircase.
Section 5's staircase is the extra, TF24-specific amount on top of it. Route B's divisor is the
cohort spacing, whose minimum measured over a full coupled run is **3.7e-02** — four to five
orders larger.

**2. It is the discretisation the scheme already has.** In a method-of-characteristics scheme
the cohorts *are* the grid. Differencing `g` between neighbouring cohorts is the natural upwind
stencil on that grid; a `1e-6` probe discretises on a grid that does not exist, and then has to
be told how far to probe.

**3. It costs nothing either direction.** The neighbours' rates are already computed, so there
is no extra evaluation forward and nothing extra to record in reverse. Route A's forward cost is
also already paid — `Node::compute_rates` calls `growth_rate_gradient` after
`individual.compute_rates`, so the second rate evaluation including TF24's leaf solve is in the
measured 53 s — but route A still has to *record* it, and route B does not.

**4. It keeps the reverse pass's cohort unit intact.** Under the cohort-block decomposition each
block emits its own `g`. Route B's stencil is then a closed-form combination of three
neighbouring blocks' outputs, so it belongs with the soil and allometry adjoints as a
closed-form step rather than inside a block. Route A's stencil is intra-cohort, so it forces the
block to cross the leaf's boundary twice — once at `h`, once at `h - eps` — with two sets of
injected partials, and the first set has to be read before the second overwrites the leaf's
outputs.

### Why route C is wrong rather than merely unstable

The AD branch found that substituting the analytic `dg/dh` needs the growth clamp smoothed to
`eps ~ 5e-2` to stay bounded, a roughly 6% change to K93's demography, and section 6 asks
whether that means the stencil is load-bearing for stability. It does, and for a reason that is
not about clamps: **the one-sided difference is an upwind discretisation of a hyperbolic
advection term, so it carries numerical diffusion, and the analytic derivative does not.**
Replacing it removes the stabilisation. That is expected behaviour for the substitution, not a
defect to smooth around, and it means the choice is *which grid to difference on*, not whether
to difference.

Section 6's open question therefore resolves without the measurement it asks for: the
stabilisation claim is true, and it does not favour A over B, because both difference.

### What it costs

A change to the forward value, unquantified. `log_density_dt` changes, so offspring and every
census metric move. That needs measuring before it lands, and baselines re-blessing after —
less of an obstacle than it was, since the shared-leaf fix re-blesses TF24's baselines anyway.

Two constructs go away with it: the sub-grid probe, and `node_gradient_eps` together with the
coupling to `GSS_tol_abs` that section 5 records and nothing else does.

---

## 2. State at develop

`Node::compute_rates`:

```cpp
log_density_dt = - growth_rate_gradient(environment)
                 - individual.rate(MORTALITY_INDEX);
```

`Node::growth_rate_gradient`:

```cpp
thread_local std::optional<individual_type> scratch;
if (scratch.has_value()) { *scratch = individual; } else { scratch.emplace(individual); }
individual_type& p = *scratch;
auto fun = [&](double h) -> double { return p.growth_rate_given_height(h, environment); };

const Control& control = individual.control();
const double eps = control.node_gradient_eps;
if (control.node_gradient_richardson) {
  return util::gradient_richardson(fun, individual.state(HEIGHT_INDEX), eps,
                                   control.node_gradient_richardson_depth);
} else {
  return util::gradient_fd(fun, individual.state(HEIGHT_INDEX), eps,
                           individual.rate(HEIGHT_INDEX),
                           control.node_gradient_direction);
}
```

with `Individual::growth_rate_given_height`:

```cpp
double growth_rate_given_height(double height, const environment_type& environment) {
  set_state(HEIGHT_INDEX, height);
  compute_rates(environment);
  return rate(HEIGHT_INDEX);
}
```

Relevant defaults (`src/control.cpp`): `node_gradient_eps = 1e-6`,
`node_gradient_direction = -1`, `node_gradient_richardson = false`,
`node_gradient_richardson_depth = 4`.

So on the production path, with `direction = -1`, `util::gradient_fd` dispatches to
`gradient_fd_backward(f, x, dx, fx)` = `gradient_fd_forward(f, x, -dx, fx)`, which is

    dg/dh  ~=  ( g(h - eps) - fx ) / (-eps)

Three properties of this that matter:

- **`fx` is `individual.rate(HEIGHT_INDEX)`, already computed** by the enclosing
  `compute_rates`. The stencil therefore costs exactly **one** additional evaluation of
  `g`, not two.
- **That one evaluation is a full `compute_rates`** on a scratch `Individual`. For TF24
  that means a full leaf hydraulic optimisation, so the stencil roughly doubles the
  per-cohort rate cost. It is the reason the `thread_local` scratch exists — the
  allocation, not the arithmetic, was the thing worth removing.
- **The scratch is a copy of the `Individual`, but the `Strategy` is shared.**
  `growth_rate_given_height` calls `compute_rates` on the copy, which writes into the
  same `Leaf`, the same `mass_root_prop_`, the same `function_integrator`. Those are
  scratch and are re-seated per call, so the value is correct — but it means the probe
  and the main evaluation are not as independent as the copy suggests, which bears on
  section 5's open question.

If `node_gradient_richardson` were enabled it would be materially worse for this
purpose: `gradient_richardson` takes `2 * depth = 8` evaluations at shrinking steps and
combines them with `(a[i+1]*4^m - a[i])/(4^m - 1)`, so the amplification of section 5
compounds across the extrapolation. It is off by default and should stay off on any
differentiated path.

---

## 3. Route A — evaluate the existing stencil actively

Replace the `double` probe with an active one:

    dg/dh  =  ( g_active(h - eps) - g_active(h) ) / (-eps)

where `g_active(h)` is the same `growth_rate_given_height` at the working scalar, and
`g_active(h)` is the rate already on the tape.

**Value:** bit-identical. Same two numbers, same subtraction, same division.

**Derivative:** the derivative of the discretisation being solved. Not the derivative of
the continuum `dg/dh`, which is the point — the trajectory is the discretisation's, so
the exact gradient of the model as implemented is the discretisation's derivative.

**Cost:** one extra *active* rate evaluation per cohort per Runge-Kutta stage, replacing
one *double* evaluation. Under report 1's cohort-granular decomposition this widens the
arithmetic inside a cohort's tape without widening the cohort's interface, so the peak
tape is unchanged and the cost is time. Without that decomposition it roughly doubles
the recorded tape for the per-cohort rate path, which for TF24 is the dominant term.

**This is the route that leaves the forward model alone**, and for that reason it should
be built first even if B or C ends up preferred.

---

## 4. Route B — difference across neighbouring cohorts

Cohorts within a species are ordered by height and all of their rates are computed in
the same `Species::compute_rates` pass. So the growth rate at the neighbouring height is
already in hand, and

    dg/dh  ~=  ( g_{j} - g_{j-1} ) / ( h_{j} - h_{j-1} )

costs nothing at all — no scratch `Individual`, no extra `compute_rates`, no leaf solve.
It is differentiable by construction, since both terms are active quantities the pass
already produced. Taking the lower neighbour keeps it one-sided in the same direction as
`node_gradient_direction = -1`.

**What it changes.** The divisor becomes the cohort spacing rather than `1e-6`, so the
value is a genuinely different — coarser — approximation to `dg/dh`. Whether that is
better or worse is a question about the scheme rather than about AD: for a
method-of-characteristics discretisation, differencing the advection term on the grid the
characteristics actually occupy is the conventional choice, and a sub-grid probe five
orders below the spacing is not obviously the more faithful one. It also removes the
`thread_local` scratch and its shared-`Strategy` entanglement entirely.

**What it needs.** A boundary rule at the top and bottom cohort, a rule for coincident
or near-coincident heights (the spacing appears in a denominator), and a decision about
what happens when a species has one cohort. None of these is hard; all of them are
decisions rather than derivations.

**Why it is attractive despite changing the value:** it is free, it is differentiable
without any active probe, and its amplification factor in section 5 is `1/spacing`
rather than `1/eps` — smaller by five orders or more.

---

## 5. The amplification hazard, and why it couples to the leaf

Route A's derivative is

    d/d(theta) [ dg/dh ]  =  ( dg/d(theta)|_{h-eps}  -  dg/d(theta)|_{h} ) / (-eps)

a difference of two parameter-derivatives divided by `eps = 1e-6`. If the error in
`dg/d(theta)` is a **smooth** function of `h`, the two errors are nearly equal and the
difference cancels to `O(eps * d(error)/dh)` — harmless. If the error is a **staircase**
in `h`, the two evaluations can sit on different steps and the difference is the full
step, amplified by `1/eps = 10^6`.

TF24's growth rate depends on the leaf's collar operating point, which comes from
`golden_section_max` and moves in steps: it is affine in its bracket within a comparison
pattern and jumps when the pattern changes. That is a staircase in `h`, and its step is
**bracket-scale rather than tolerance-scale** — which is also what reconciles report 06 §9's
`dPi/dp` of 11-23 at `GSS_tol_abs = 1e-3` with the measured curvature `Pi_pp` of about -4.
A `1e-4` displacement from the optimum would give `4e-4`; a bracket-scale one gives what is
measured.

So the size of the step, and therefore whether route A amplifies it, is the quantity to
measure rather than to argue about. M4 measures it directly by taking the stencil's trait
derivative from a tape at `node_gradient_eps` of 1e-4, 1e-6 and 1e-8: if the amplification
is real, agreement with a finite difference degrades as `eps` shrinks.

This is also, read the other way, a characterisation of why develop works today. The
`double` stencil differences a staircase whose step size is `GSS_tol_abs = 1e-3` at a
probe distance of `1e-6`, which should be catastrophic — and is not, because the
comparison pattern is locally constant across a `1e-6` height perturbation, so `q*` moves
affinely with its bracket and the two evaluations land on the same step. The quantity
`growth_rate_gradient` returns is therefore the derivative of a bracket-affine surrogate
rather than of the true optimum. That is worth knowing before anyone changes either
`node_gradient_eps` or `GSS_tol_abs`, because the two tolerances are coupled through a
mechanism nothing currently records.

Route B's divisor is the cohort spacing, so the same staircase is amplified by
`1/spacing` instead. That is the strongest technical argument for B.

---

## 6. An open question about the stabilisation claim

The AD branch records that substituting the analytic `dg/dh` destabilises the density
transport, and that the trajectory only stays bounded with the growth clamp smoothed to
`eps ~ 5e-2`. Taken at face value that says the stencil is load-bearing for stability.
But the backward difference at `eps = 1e-6` differs from the analytic derivative by
`O(1e-6 * g'')`, so the two cannot differ enough to change stability *unless the function
being differenced is not smooth at that scale*. Two candidates, and they have different
consequences:

- **The clamp corner.** `g` passes through a positive-part clamp at the carbon
  compensation point. A one-sided backward difference never straddles the corner; the
  analytic derivative at the corner is undefined and either one-sided value is a valid
  subgradient, but a solver that lands exactly on it can pick badly. If this is the
  cause, the direct fix is to smooth the clamp — which the AD branch already does for
  FF16 and K93 via `smooth_positive`, and for TF24 nowhere — and then `dg/dh` can be
  analytic. That is **route C**.
- **The probe is not differencing the same function.** `growth_rate_given_height` runs a
  full `compute_rates` on a scratch `Individual` that shares the `Strategy`'s `Leaf` and
  buffers. If any of that shared state makes `g(h - eps)` subtly not the same function as
  the `g(h)` already computed, the stencil is not `(g(h-eps) - g(h))/(-eps)` at all, and
  its apparent stabilising effect is an artefact of the discrepancy rather than of
  upwinding.

**These are distinguishable by measurement, and the distinction decides route C.** The
discriminating test is cheap: evaluate `g` at `h` twice — once through the enclosing
`compute_rates` and once through `growth_rate_given_height(h, env)` — and compare. If
they are bit-identical, candidate 2 is dead and the clamp is the story. If they are not,
the stencil's meaning needs re-establishing before anything is built on it.

---

## 7. What to measure next

In the order that resolves the most per unit effort:

1. **Is `growth_rate_given_height(h)` bit-identical to the already-computed rate at
   `h`?** Section 6's discriminating test. One assertion, no build beyond plant itself,
   and it decides whether the stencil is what it appears to be.
2. **How large is the dropped channel?** Take a K93 census gradient — K93 is the simplest
   strategy and its gradient is already finite-difference verified — with the transport
   term's derivative present and absent. The difference is the size of what develop
   currently discards. This is the number that says whether any of this matters, and it
   should have been measured before the workaround was adopted.
3. **Route A on K93.** No leaf, so no staircase and no amplification: it isolates the
   active stencil from section 5's hazard. Verify against the existing finite-difference
   gate, and confirm the value is bit-identical.
4. **Route B on K93.** Measure the value change against route A, on the same trajectory.
   This is the number that decides whether free-and-coarser is acceptable.
5. **Count the clamp crossings.** How often does a cohort sit near the carbon
   compensation point on a production run, counted the way report 2 counts the leaf
   branches. If the answer is never, route C's stability concern is moot and the analytic
   derivative is available; if it is often, the clamp needs smoothing on its own merits.
6. **Route A on TF24.** The amplified residual of section 5,
   measured rather than bounded.

Steps 1, 2 and 5 need no new machinery and no gradient engine.

---

## 8. What this asks of a Strategy author

**A rate defined as a numerical derivative must be computed from quantities that carry
derivatives.** This is the whole report in one line. The stencil is a legitimate
discretisation; evaluating it in `double` on a differentiated path silently drops the
channel it discretises.

**If you difference something, know its smoothness at your step size.** A probe distance
of `1e-6` against a quantity that moves in steps of `1e-3` is only safe because the steps
are locally flat, and nothing records that dependency. Prefer a difference whose divisor
is a grid spacing you control over one whose divisor is a tolerance chosen for
roundoff.

**Prefer the neighbour you already have to the probe you have to construct.** A
per-cohort quantity that a neighbouring cohort has already computed is free, exactly
differentiable, and cannot go stale. A scratch copy sharing mutable state with the
original is none of those things.

**Changing the integrated state is a large step; take the small ones first.** Choosing a
transported variable so that an awkward term cancels is a real technique and it is not
the first thing to try. The order that respects the forward model is: make the existing
discretisation differentiable, then question the discretisation, then question the
variable.
