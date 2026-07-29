# The demographic transport term

The size-density equation's compression term, how plant discretises it, and the
discretisation this design uses instead. Numbers are measured on plant `develop`
`141dc8df` against odelia `854a8e18` unless attributed otherwise.

---

## 1. The term, and why it exists

The size-density equation, in characteristic form along a cohort's trajectory:

    d(log n)/dt  =  -dg/dh  -  mortality

`n` is cohort density, `g` the height growth rate. The `-dg/dh` is the compression term:
cohorts growing at different rates spread apart or squeeze together, and a density held
between them thins or thickens accordingly.

**It exists because the state is a density.** The conserved quantity is the *number* of
individuals between two neighbouring characteristics, and that obeys `dN/dt = -mortality * N`
with no compression term. Section 2 uses this.

`dg/dh` is not available in closed form, so it must be discretised. Which discretisation is
the subject of this report, and it is a forward-model question that a gradient makes
consequential: **a numerical derivative evaluated in plain `double` on a differentiated path
drops the channel it discretises.** Every census metric is a reduction
`sum_i n_i psi(state_i)` with `n_i = exp(l_i)`, so a trait's effect on how density compresses
reaches the answer at first order or not at all.

---

## 2. The discretisation: difference `g` on the cohort grid

    dg/dh  ->  ( g_j - g_{j+1} ) / ( h_j - h_{j+1} )

taking the neighbour below, with cohorts in the descending order `Species` stores them. Both
growth rates are already computed by the same `Species::compute_rates` pass, so this costs
nothing to evaluate and nothing to record.

### 2.1 It is not an approximation to `dg/dh`. It is exact

The spacing between two characteristics has an exact rate, because both of its endpoints are
transported heights:

    dh_j       = h_j - h_{j+1}
    d(dh_j)/dt = g_j - g_{j+1}

So for the count `N_j = n_j dh_j`,

    log n_j       = log N_j - log dh_j
    d(log n_j)/dt = -mortality_j - (1/dh_j) d(dh_j)/dt
                  = -mortality_j - (g_j - g_{j+1}) / (h_j - h_{j+1})

which is the stencil above. Read the other way,

    d(log n)/dt = -mu - d(log dh)/dt   <=>   d(log(n dh))/dt = -mu   <=>   dN/dt = -mu N

**The stencil is exactly `d(log dh)/dt`.** So differencing on the cohort grid and transporting
counts are the same discretisation of the PDE, in different coordinates for the integrator.
Differencing keeps `log_density` as the state, so the census, the light field's reduction and
`Species::consumption_rate` all keep reading `exp(log_density)` and nothing downstream changes.
Transporting counts would change the integrated state, the reconstruction of density from it,
the overflow behaviour at small spacing and the coincident-cohort case, for the same dynamics.

### 2.2 It makes the scheme conserve individuals

Under the cohort-grid stencil, `N_j` obeys `dN_j/dt = -mortality_j N_j` exactly. Under a
sub-grid probe it does not:

    dN_j/dt = N_j * ( (g_j - g_{j+1})/dh_j  -  dg/dh|_point  -  mortality_j )

and the first two terms differ by `O(dh * g'')`. So a sub-grid probe leaks individuals at that
order and the cohort-grid stencil does not. That is a forward-model property, independent of
any derivative, and it is the argument that carries the re-blessing this change needs.

### 2.3 It is consistent with the boundary condition

The equation closes at the birth size with a flux, `g(x_b) n(x_b) = B(t)`, so
`n(x_b) = B/g` — which is `log(birth_rate * pr_estab / g)` at `node.h:177`. As a newborn
interval collapses at introduction, `N -> 0` and `n = N/dh -> B/g`. The degenerate interval is
the limit that recovers the boundary condition, not an edge case to guard.
Report 01 §3.1 carries the boundary condition's reverse-mode treatment.

---

## 3. What it costs and what it buys

**It removes about half of every TF24 leaf solve in a production run.** `Node::compute_rates`
calls `growth_rate_gradient` *after* `individual.compute_rates` (`node.h:132-140`), and
`growth_rate_given_height` runs a complete `compute_rates` including the hydraulic optimisation
(`individual.h:138-143`). So every cohort costs **two** leaf solves per Runge-Kutta stage.
Against report 02's instrumented count on the pre-`#517` tree: 141 cohorts x 6 stages x 2 829
steps x 2 is about 4.8 million against **4 372 101** measured, the remainder being the stand
growing from one cohort to 141. The ratio is structural and holds on any tree.

**Two constructs go away**: the sub-grid probe with its `thread_local` scratch, and
`node_gradient_eps` together with the coupling to `GSS_tol_abs` that section 5 records and
nothing else does.

**It changes the forward value.** `log_density_dt` changes, so offspring and every census metric
move. The size is unmeasured (`../build-plan.md` §5b, M4). Baselines need re-blessing, alongside
§2.2's conservation diagnostic, which is the number worth presenting with it.

---

## 4. State at develop

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

Defaults (`src/control.cpp`): `node_gradient_eps = 1e-6`, `node_gradient_direction = -1`,
`node_gradient_richardson = false`, `node_gradient_richardson_depth = 4`. With
`direction = -1`, `util::gradient_fd` dispatches to `gradient_fd_backward(f, x, dx, fx)`, which
is

    dg/dh  ~=  ( g(h - eps) - fx ) / (-eps)

Three properties of it:

- **`fx` is the already-computed rate**, so the stencil costs one additional evaluation of `g`,
  not two.
- **That one evaluation is a full `compute_rates`**, which for TF24 is a full hydraulic
  optimisation. It is why the `thread_local` exists — the allocation, not the arithmetic, was
  the thing worth removing.
- **The scratch copies the `Individual`, but the `Strategy` is shared.**
  `growth_rate_given_height` calls `compute_rates` on the copy, which writes into the same
  `Leaf`, the same `mass_root_prop_`, the same `function_integrator`. Those are re-seated per
  call, so the value is correct — but the probe and the main evaluation are not as independent
  as the copy suggests. `../tf24-correctness.md` P0.1 is the case where that discipline fails.

`node_gradient_richardson` would be materially worse for a differentiated path:
`gradient_richardson` takes `2 * depth = 8` evaluations at shrinking steps and combines them with
`(a[i+1]*4^m - a[i])/(4^m - 1)`, so section 5's amplification compounds across the extrapolation.
It is off by default and should stay off.

---

## 5. Why not a sub-grid probe, differentiated

Evaluating the existing stencil at the active scalar leaves the value bit-identical — same two
numbers, same subtraction, same division — and yields the derivative of the discretisation
actually solved. It is the change that leaves the forward model alone, and it is still the wrong
one, for two reasons.

**Conditioning, which does not depend on smoothness.** The derivative is

    d/d(theta) [ dg/dh ]  =  ( dg/d(theta)|_{h-eps}  -  dg/d(theta)|_{h} ) / (-eps)

a difference of two parameter-derivatives divided by `1e-6`. Even with exact AD on both terms,
two O(1) quantities carried to a relative accuracy of about `1e-16`, differenced and divided by
`1e-6`, leave an absolute error of about `1e-10`. Whether that matters is its ratio to the second
partial being estimated, and it is present before any non-smoothness. The cohort grid's divisor
is the spacing, whose minimum measured over a full coupled run is **3.7e-02** — four to five
orders larger.

**A staircase, on top of that, and specific to TF24.** TF24's growth rate depends on the leaf's
collar operating point, which comes from `golden_section_max`: affine in its bracket within a
comparison pattern, jumping when the pattern changes. That is a staircase in `h`, and its step is
**bracket-scale rather than tolerance-scale** — which is also what reconciles report 06 §9's
`dPi/dp` of 11-23 at `GSS_tol_abs = 1e-3` with the measured curvature `Pi_pp` of about -4. A
`1e-4` displacement from the optimum would give `4e-4`; a bracket-scale one gives what is
measured. If the error in `dg/d(theta)` is smooth in `h`, the two evaluations nearly cancel; if it
is a staircase, they can sit on different steps and the difference is the full step, amplified by
`1/eps = 1e6`.

**Read the other way, this characterises why develop works today.** The `double` stencil
differences a staircase whose step is `GSS_tol_abs = 1e-3` at a probe distance of `1e-6`, which
should be catastrophic — and is not, because the comparison pattern is locally constant across a
`1e-6` height perturbation, so the operating point moves affinely with its bracket and both
evaluations land on the same step. The quantity `growth_rate_gradient` returns is therefore the
derivative of a bracket-affine surrogate rather than of the true optimum. That is worth knowing
before anyone changes either `node_gradient_eps` or `GSS_tol_abs`, because the two tolerances are
coupled through a mechanism nothing else records.

---

## 6. Why not the analytic derivative

Substituting the closed-form `dg/dh` — whether written by hand or obtained by forward-mode AD of
the rate chain in `h`, which is the same mathematics — **removes the upwinding.** The one-sided
difference is an upwind discretisation of a hyperbolic advection term, so it carries numerical
diffusion; the analytic derivative does not. The AD branch measured the consequence: the
trajectory stays bounded only with the growth clamp smoothed to `eps ~ 5e-2`, a roughly 6% change
to K93's demography.

That is expected behaviour for the substitution rather than a defect to smooth around, and it
means the choice is *which grid to difference on*, not whether to difference.

---

## 7. What it requires

**One staggering decision, from which three rules follow.** `n` lives at nodes and `dh` lives on
intervals, so any `N/dh` correspondence is a choice of staggering. Made once, it settles what the
first cohort does (no neighbour above), what the last does (no neighbour below), and what a
one-cohort species does. Those are not three special cases; they are one decision read three
ways.

The one-cohort case is not hypothetical. `Species::consumption_rate` already returns exactly
`0.0` for `size() < 2`, measured at **0.70%** of output times — and it is the *first* one, the
window in which establishment is decided (report 07 §1.7).

**`Species::compute_rates` becomes two passes.** Today `Node::compute_rates` computes the
individual's rates and then, in the same call, `log_density_dt` (`node.h:132-140`). Cohort `j`
cannot form `log_density_dt` until its neighbours' growth rates exist, so the loop splits: all
individuals' rates first, then all transport rates. `Node::compute_rates` loses its line 138 and
`Species` gains the stencil:

```cpp
double Species<T,E>::growth_rate_gradient(std::size_t i) const;   // one-sided at the ends
```

**The newborn acquires a neighbour it does not have today.**
`Node::compute_initial_conditions` computes the boundary node's rates in isolation and reads
`individual.rate(HEIGHT_INDEX)` for `log_density` (`node.h:164-189`), before the species has
recomputed anyone. The newborn is the shortest cohort, so it is the bottom boundary and one-sided
against the cohort above it — a coupling develop does not have.

---

## 8. What would falsify this

Stated as checks, so the answer is a number.

- **The identity in §2.1 does not hold numerically.** Integrate `log N` alongside `log n` from
  the same initial conditions on one production run and compare reconstructed `n = N/dh` against
  `exp(l)` per cohort per output time. They should agree to integrator tolerance, not to
  roundoff — the two coordinates have different local truncation error — and a systematic drift
  larger than that means the staggering is inconsistent.
- **The conservation claim does not hold.** Log `sum_j N_j` against its analytic mortality loss
  under both stencils. The sub-grid probe should leak at `O(dh g'')` and the cohort grid should
  not.
- **The forward-value change is larger than the model owner will accept.** `log_density_dt`
  changes, so offspring and the three census metrics move. Measured before it lands
  (`../build-plan.md` M4).
- **The dropped channel is negligible.** Take a K93 census gradient with the transport term's
  derivative present and absent. K93 has no leaf, so no staircase and no amplification. If the
  difference is small, none of this matters; that is the number that should have been taken
  before any of it was designed.
- **`growth_rate_given_height(h)` is not bit-identical to the already-computed rate at `h`.**
  One assertion, no new machinery. If they differ, the shared `Strategy` state makes the probe a
  different function from the rate it differences, and §4's third property is worse than
  recorded.

---

## 9. What this asks of a Strategy author

**A rate defined as a numerical derivative must be computed from quantities that carry
derivatives.** The stencil is a legitimate discretisation; evaluating it in `double` on a
differentiated path silently drops the channel it discretises.

**Difference on a grid the model already has, not on one you invent.** In a
method-of-characteristics scheme the cohorts *are* the grid, and the spacing between them has an
exact rate. A probe distance is a tolerance chosen for roundoff, and dividing by it amplifies
roundoff by its reciprocal whether or not the differenced quantity is smooth.

**If you difference something, know its smoothness at your step size.** A probe distance of
`1e-6` against a quantity that moves in steps of `1e-3` is only safe because the steps are locally
flat, and nothing records that dependency.

**Ask what the discretisation conserves.** The compression term is an artefact of representing the
state as a density; the count between characteristics conserves exactly. A discretisation that
recovers that property is more likely to be the right one, and the check is cheaper than the
argument.
