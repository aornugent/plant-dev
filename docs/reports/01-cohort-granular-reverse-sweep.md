# Cohort-granular reverse-mode gradients for the SCM

A proposal for obtaining exact trait gradients of SCM outputs at production
lifetime, addressed to plant maintainers.

Numbers labelled **measured** were produced in this study and the command that
produced them is given. Numbers labelled **projected** are arithmetic on measured
quantities and are marked as such. Numbers attributed to earlier work come from the
ledgers and probes on `archive/v3-docs-and-probes`.

---

## 1. The proposal

Reverse-mode AD must hold a complete tape before it can walk it backwards, so peak
memory is the whole recorded computation. For the SCM that is the whole run: at TF24
production settings, approximately **490 GB** (section 2). This proposal does not
make the recording smaller. It changes what a recording *is*.

**Store the trajectory in plain `double`. On the reverse pass, record and sweep one
cohort at a time.**

The reason this is possible is a property of the model rather than of the
implementation. Within one Runge-Kutta stage, every cohort influences every other
one **only** through a single scalar field of height. So the per-stage computation is
four layers, and the middle one is thin:

```
     y  =  cohort states (141 x 8)  +  environment states (9)
     |
ALL  |  per cohort, independent, closed form   (allometry: area_leaf, density)
     v
LGT  |  ONE reduction over all cohorts, then an interpolant   (the light field)
     v
RAT  |  per cohort, independent, EXPENSIVE     (rates; for TF24, the leaf solve)
     v
SOIL |  ONE reduction, then the soil           (resource_depletion -> soil rates)
     v
    dydt
```

The reverse pass runs those four layers backwards in a strict order with **no
circular dependency**, and this is the one point that had to be settled before the
design was viable. The graph looks circular — RAT's sweep needs the light adjoints
that LGT produces, and LGT needs the light adjoints that RAT produces — and it is not,
because ALL is a *separate closed-form map* and is adjointed analytically rather than
on a cohort's tape:

```
given lambda (the adjoint of y at the end of this step)

  a   the closed-form seeds -- everything a block's outputs need before it can be swept:
        SOIL adjoint      -> lambda_soil, and lambda_uptake for every cohort
        TRANSPORT stencil -> lambda_g for every cohort, and a direct lambda_h
  b   for each cohort j:  fresh tape; record ONLY cohort j's rates; seed its 11 output
                          adjoints from (a) and from the stage recursion; sweep once;
                          read off lambda_states, lambda_knots, lambda_psi,
                          lambda_traits; RELEASE the tape
                                                     <-- PEAK IS ONE COHORT
  c   LGT adjoint         -> lambda at the field's knots -> lambda_(area_leaf, density, H)
  d   ALL adjoint         -> lambda_y_j (field contribution)   closed form
  e   lambda_y_j = direct + field
```

Step (b) holds all the expensive arithmetic and its tape is released before the next
cohort's is created. Steps (a), (c), (d) are linear or closed-form maps whose
adjoints cost what their forward evaluation costs.

**Both parts of (a) are seeds, which is why they are one step.** A block cannot be swept
until every one of its output adjoints exists, and two of the three sources are closed
form: the soil adjoint supplies `lambda_uptake`, and the transport stencil supplies
`lambda_g` — because under report 04 §2's cohort-grid stencil a cohort's `g` feeds the
`log_density_dt` of its neighbours as well as its own. Only `lambda_rates` for the
remaining states comes straight from the stage recursion. Grouping the stencil with the
soil rather than after the blocks is not a preference; putting it after would seed the
blocks with a `lambda_g` that does not yet exist.

**Three properties make this worth doing:**

- **Peak is flat in run length, and in the stage count.** Measured: ~1.0 kB per cohort
  tape from 60 to 480 steps, while a whole-run tape over the same range grows 20.8 MB to
  169.0 MB. Moving from Euler to a four-stage Runge-Kutta multiplies the whole-run tape
  by the stage count (56.4 MB to 226.1 MB at a matched configuration) and leaves the
  cohort tape at 1.1 kB.
- **Peak is flat in the number of differentiation targets.** Seeding more traits adds
  registered inputs, not recorded operations, so the tape is the same size. One
  sweep still yields every trait's adjoint. This matters because the realistic target
  count is tens, not a handful (section 4.2).
- **No new vocabulary reaches a Strategy author.** `Individual::compute_rates` is
  recorded exactly as it already stands. The decomposition lives entirely in the
  gradient driver.

**What it costs:** a stored plain trajectory (46.0 MB at production, projected), and a
doubling of the plain-`double` work — plant's Runge-Kutta step has six stages, and the
backward pass rebuilds those stage states by re-running the step in `double` rather than
storing them, so each stage is evaluated once forward and once again on the way back.
Each (stage, cohort) pair is then recorded and swept exactly once. **Storage is
independent of the stage count**, which is what makes rebuilding preferable to storing.
Measured wall clock against a whole-run tape over the same trajectory: **1.4 to 1.6x**,
improving as the stand grows (section 7.4). That is the toy's ratio against a whole-run tape,
not against the forward `double` run, and **no equivalent has been measured on TF24** — where a
cohort contains a leaf solve and the toy's cohort does not.

**What it depends on:** that a cohort's rates are a pure function of that cohort's
boundary. Section 5 reads develop against that requirement. On develop it does not hold:
TF24's shared `Leaf` carries deep-layer uptake between cohorts on 33.78% of production
records, and two caches are keyed on less than they depend on. All three are
prerequisites (`../tf24-correctness.md` P0.1, and section 9's C1).

Sections 2 to 8 substantiate the above. Section 10 draws out what the design asks of
someone writing a new Strategy, which is the part that determines whether this is
usable rather than merely correct.

---

## 2. The problem, quantified

At TF24 production settings the run has:

| quantity | develop `141dc8df` | this study, pre-`#517` |
|---|---|---|
| node ODE states | **1 128** | 987 |
| cohorts | **141** | 141 |
| states per cohort | **8** = `state_size()` 6 + log-density + offspring (`node.h:79`) | 7 |
| environment ODE states | **9** | 9 |
| accepted ODE steps | **5 055** | 2 829 |
| leaf optimisations | ~8 M (projected: 141 x 6 stages x 5 055 x 2) | **4 372 101** (instrumented) |
| offspring production | **4.214017357509567e+01** | not recorded |
| forward wall clock | **89.9 s** | 53.1 / 59.5 s |
| per accepted step | **17.8 ms** | 21.0 ms |

**The right-hand column predates the NSC storage state.** `TF24_Strategy::state_size()` is a
compile-time `6` on develop (`tf24_strategy.h:125`), so 987 = 141 x 7 can only come from a
five-state TF24 — the storage pool arrived with `#517` and report 00 §1 records it as new.
Adding a sixth state with its own dynamics also moved the error control, hence 5 055 accepted
steps rather than 2 829. The left-hand column was measured this session on develop `141dc8df`
against odelia `854a8e18`, `scm_base_parameters("TF24", "TF24_Env")` with
`add_strategies(trait_matrix(0.1978791, "lma"))`, `Control()`, `refine_schedule = FALSE`,
compiled `-O2 -DNDEBUG` (`make compile`).

**The forward run is slower only because there are more steps.** Per accepted step it is
*cheaper* than the earlier tree — 17.8 ms against 21.0 — so the 89.9 s is 1.79x the step count
at 0.85x the cost each, and there is no performance regression hiding in it.

**A trajectory is reproducible within one build and not across two.** The same run compiled
`-O0` (`pkgbuild::compile_dll()`'s default) takes **5 095** accepted steps and reports offspring
`4.220134475942768e+01` — 0.79% more steps and **0.145%** different offspring. The model has no
randomness, so this is the adaptive step-size controller amplifying last-bit differences in
arithmetic association into a different accepted grid, and everything downstream inherits it.
Three consequences:

- **Every bit-identity gate names its build.** Comparing a number taken at `-O0` against one
  taken at `-O2` measures the compiler.
- **A forward-value change smaller than about 0.15% in offspring cannot be attributed unless the
  build is pinned.** Within one build the run is deterministic and bit-reproducible, so pinning
  is sufficient — but it has to be deliberate.
- It is the measured reason for a design choice already made: a finite-difference verification
  must run base and perturbed on the **same recorded grid**, not on two adaptive passes, because
  a perturbation that changes the accepted step count changes the answer by more than the
  derivative being measured.

**Within one set of flags it is bit-reproducible across builds, and the clock is not.** Two
independent `-O2` builds of the same tree — one against odelia in a scratch library, one against
the site install — give the same 5 055 steps and the same offspring to the last digit, at 89.9 s
and 92.6 s. So a value gate can demand exact equality, and a **timing gate has about 3% of
run-to-run noise** under it, which is the floor for any accepted band.

The instrumented leaf count stays in the right-hand column because it was instrumented rather
than projected, and it is consistent with its own tree: 141 x 6 x 2 829 x 2 is about 4.8 M
against 4 372 101 measured, the remainder being the stand growing from one cohort to 141. **The
ratio that matters is structural and unaffected**: two leaf solves per cohort per stage, one in
`compute_rates` and one in `growth_rate_gradient`'s probe.

Earlier work measured the reverse tape at approximately **86 kB per node-ODE-state
per step**, flat in stand width over the range it could reach (widths 543 to 606). On develop's
own counts:

    1 128 states x 5 055 steps x 86 kB  ~=  490 GB         (projected)

against 220 GB on the pre-`#517` counts. The problem this report addresses got larger, not
smaller.

TF24 gradients were measured succeeding at `max_patch_lifetime = 1` (3.22 GB) with
the kernel killing the process above 2.5.

Two remedy families have been tried and measured, and both are closed:

- **Recording fewer operations.** Crown preaccumulation at two boundaries (1.49x and
  3.7x), hoisting the query-factor `pow` (1.24x), a leaner interpolant refinement
  (5.89x on the component, **0.018%** on TF24's total). Against a required factor of
  order 10^2 to 10^3, component leanness is not a route.
- **Reusing one tape, rewound between units.** `xad::Tape::resetTo` keeps the
  gradient exact but does not release memory: peak grew 48 kB to 742 kB over 60 to
  960 units, and the time advantage reversed from 1.48x to 8.42x.

---

## 3. State at develop

`SCM::run_next()` advances the ODE solver, which calls `Patch::set_ode_state(it,
time)` at every Runge-Kutta stage. That function (`patch.h:679-702`) is the whole
per-stage computation, in a fixed order:

```
Patch::set_ode_state(const_iterator it, double time)
  1  odelia::ode::set_ode_state(species.begin(), species.end(), it)
        Species::set_ode_state -> Node::set_ode_state -> Individual::set_ode_state
          per state slot:  vars.states[i] = *it++;
                           strategy->update_dependent_aux(i, vars)
              TF24: competition_effect = area_leaf(height); height_inverse = 1/height
          Node also:       set_log_density(*it++)  ->  density = exp(log_density)
  2  environment.set_ode_state(it)                      // 9 environment states
  3  environment.time = time
  4  check_finite_ode_state()                           // #550 guard
  5  compute_environment(true)
        f = [](double x) -> double { return compute_competition(x); }
        environment.compute_environment(f, height_max(), rescale)
          -> ResourceSpline::construct: adaptive cubic fitted to light vs height
  6  compute_rates()
        for each species: Species::compute_rates(env, pr_patch_survival, birth_rate)
          Node::compute_rates -> Individual::compute_rates
            -> TF24_Strategy::compute_rates -> net_mass_production_dt
                 leaf.set_physiology(...); solve_leaf()      // the hydraulic solve
               writes vars.rates and vars.consumption_rates
          Node::compute_rates also:
            log_density_dt = -growth_rate_gradient(env) - mortality
        resource_depletion[i] = sum over species, nodes of consumption_rate(i) / area
        environment.compute_rates(resource_depletion)   // soil rates
```

Two facts that the decomposition rests on, both read directly from the above:

**`compute_environment` reads the ODE state just loaded, plus one lagged scalar per
species.** Step 1 refreshes each cohort's auxiliary slots as it loads each state, through
`update_dependent_aux` (`individual.h:104-110`, `tf24_strategy.cpp:140-147`), and step 5
reads exactly those. It also reads `Species::new_node` — the inflow boundary node — whose
density is written by step 6 of the *previous* evaluation. `Species::compute_competition`
(`species.h:196-224`) closes its descending trapezium on the boundary node:

```cpp
if (size() == 1 || f_h1 > 0) {
  const double h0 = new_node.height(), f_h0 = new_node.compute_competition(height);
  tot += (h1 - h0) * (f_h1 + f_h0);
}
```

That interval is not optional and not a defect: it is the size-density equation's inflow
boundary, and its width is the gap between the smallest cohort and `height_0`. What is
lagged is the boundary node's **density**, `exp(log(birth_rate * pr_estab / g))`
(`node.h:177`), which needs the growth rate at `height_0`, which needs the field. The
relation is implicit, and develop resolves it by one stage of Picard: the field at a stage
uses the boundary density from the stage before.

Three things follow for the decomposition. The per-stage computation is a function of
`(y, t, boundary density from the previous stage)`, so it has one carried scalar per
species that is not ODE state. The reverse pass acquires a stage-to-stage edge, from the
knot adjoints back into the previous stage's boundary node — which runs in the same
direction as the sweep, so nothing becomes circular. And `height_0` is the reduction's
lower integration limit, so the field carries a Leibniz term in `d(height_0)/d(trait)`
that closed-form step (c) must include.

### 3.1 What the boundary node is, and what it is worth

**In the mathematics it is a flux boundary condition.** The size-density equation on
`x >= x_b` with a recruit flux `B(t)` closes with

    g(x_b) n(x_b, t) = B(t)      so      n(x_b) = B / g(x_b)

which is exactly `log(birth_rate * pr_estab / g)` at `node.h:177`. The division is not an
artefact: it converts a flux, which is what the ecology measures, into the density the state
happens to store. Two things follow. The `g -> 0` singularity is **representational** — the code
writes `log(0)` and then zeroes the rate on a finiteness check, where the ecology has recruits
accumulating harmlessly in a size class nobody is leaving. And the field's reduction integrates
over `[x_b, H_max]`, so it needs `n(x_b)` as its left endpoint at every stage: the field is a
functional of the state **and of the boundary condition**.

**The reverse-mode treatment of a flux boundary condition is standard, and it is one term.** The
adjoint of a linear advection problem runs backwards in time, so the forward problem's *inflow*
boundary is the adjoint problem's *outflow* boundary — and an outflow boundary needs no
condition. The boundary enters the gradient as

    dPsi/dB(t) = lambda_n(x_b, t) * d n(x_b)/dB = lambda_n(x_b, t) / g(x_b)

the adjoint at the boundary times the boundary condition's own derivative. No extra adjoint
equation, no boundary data for `lambda`. The design already has this shape for the introduction
*event*; what it needs additionally is the same two-term derivative — one through the flux `B`,
one through the speed `g(x_b)`, the second reaching into the seedling's own physiology — wherever
the field's quadrature reads the left endpoint.

**Measured** (`../../scripts/boundary_node.R`, develop `141dc8df`, odelia `854a8e18`, 141
introduction steps over `[0, 105.32]`). The boundary term is exactly the last trapezium interval
of `Species::compute_competition`, so its contribution is directly computable.

**Absolute, which is the measure that matters:**

| | median | max |
|---|---|---|
| boundary node's contribution to the optical depth `A` | 2.1e-06 | **1.346e-03** |
| its effect on light at ground level | 7.8e-07 | **3.48e-04** |
| steps where that exceeds 1e-3 in light | | **0 / 141** |

So the boundary node never moves the light field by more than **3.5e-04**, which is at
`ResourceSpline`'s own fitting tolerance of `1e-4`.

**Its *share* of the field is not the measure**, and reading it as one is a trap worth recording.
The share at ground level is 1.454% at the median, 12% through the first half-year, and 1.000 at
the first step — but `A(0)` itself runs from 6.0e-10 at the first step to 3.4e-4 at half a year,
against 1.797 at its maximum. Early on the boundary node is most of nothing. A ratio taken where
both terms are near zero says nothing about the field.

Two consequences.

**The one-stage lag is numerically irrelevant.** If the whole term is bounded by 3.5e-04 in light,
the difference between its lagged and its converged value is smaller again. So closing the fixed
point buys no accuracy, and the lag is not a defect to fix.

> **Both statements held, and the lag was closed anyway for a structural reason — landed as P2.7.**
> This bound was confirmed on the built change: the shift against the lag is at most **1.464e-06**
> relative and **0 of 66 290** field builds exceed the 3.5e-04 predicted here. So closing it bought no
> accuracy, exactly as stated. What it bought is that `derivs(y, t)` is now a **bitwise** pure function
> of `(y, t)` — 0 of 1137 components against 92 of 753 before — which is what lets the trajectory store
> keep one state per accepted step and lets the reverse pass rebuild stage states by re-running a step.
> **The mechanism is not the Picard step this corpus first proposed:** one extra evaluation only
> attenuates the carried dependence by the contraction modulus, whereas forming the boundary density in
> a field that *excludes its own interval* and then adding the interval back is exact. Same cost, one
> extra field build per stage. And "the lag is not a defect to fix" was right about the numerics and
> wrong about the consequence — with it open, a per-species scalar has to be carried backwards through
> `step_adjoint`, which is odelia's and knows nothing about species.

**Dropping the boundary node from the field is forward-safe, and it is not free.** The value change
is at the fitting tolerance. What it deletes is the channel through which `birth_rate` and
`pr_estab` reach the field at all, and that channel's *derivative* is unmeasured — a term small in
value can carry a derivative that is not. So this is a decision with a stated trade-off, and the
number that would settle it does not exist until the reverse pass does.

**The circularity is real, and not severed by the clamp.** The relation is implicit because the
boundary density needs `g(height_0)`, which needs the field over `[0, height_0]`. The
`max(light, 1e-4)` clamp would sever that if it bound there, and it does not: over the seedling
crown `L` runs **0.1657 to 1.0** across all 141 steps, four orders clear of the floor. Since
`L = exp(-A)` and `A` is leaf area *above* `z`, `L` is minimised at the ground by construction, so
that is the global minimum of the profile — the floor would need about five times this stand's
optical depth.

**A third census agrees, and the disagreement an earlier version of this section recorded does not
exist.** It attributed to report 07 §1.8 a count of 4.638% of knot values at or below `1e-4` with a
minimum of exactly 0. §1.8 reports the opposite — 0 of 8 292, minimum 0.1657209 — and a re-run of the
production light column this session reproduces exactly that: 8 292 values, minimum **0.1657209**,
none at or below `1e-4`, none negative, ground-level median 0.9997. So the cited conflict was a stale
cross-reference rather than two measurements of one field.

**The plant-soil coupling is narrow in both directions.** Cohorts reach the soil only
through the summed `resource_depletion` vector, and the soil reaches cohorts only
through `get_soil_water_potential_state()` — five layer potentials. Nothing else
crosses.

The AD branch adds `plant/inst/include/plant/scm_gradient.h`, whose `scm_jacobian`
runs an adaptive double pass to fix the schedule, replays it at an active scalar via
`SCM::rebind_from<S>()`, and calls odelia's `compute_jacobian` for one recording and
one sweep per output row. That entry point is correct in structure and is what runs
out of memory. This proposal replaces the single recording it takes, not the entry
point.

---

## 4. The structure being exploited

Section 1's four layers are section 3's call chain read as a data-flow graph. ALL and
RAT are independent across cohorts and are coupled only through LGT's output. That is
the mean-field structure of the model: it is also why
`Patch::compute_environment` is an O(n) build plus O(1) queries rather than an
O(n^2) all-pairs sum (plant's `agents.md` section 12).

The consequence for reverse mode is that **the only quantity that must be held across
the cohort loop is the adjoint of the field**, not the adjoint of any cohort's
internal computation.

### 4.1 The cohort's boundary

**The block is `Individual::compute_rates`, and that is narrower than the demographic
equations.** `Node::compute_rates` adds two more — `log_density_dt` and
`offspring_produced_survival_weighted_dt` — and neither can be inside the block: the first
needs a *neighbour's* growth rate under the cohort-grid stencil (report 04 §2), and the second
is closed form in a rate the block already emits. So the block stops where
`Individual::compute_rates` stops, which is also where §1 says the recording goes.

**The light enters as the interpolant's knot values**, not as light sampled at the crown
abscissae. The abscissae sit at `z = xi_j * height` — `xi_j` a quadrature fraction, not to be confused with
the knot fractions `u_k` of report 03 — so their positions depend on the cohort's own height and
sampled light is an intermediate. Recording the interpolation and the quadrature
inside the block puts the moving-bound term and `q(z, height)` on that block's tape.

For TF24 on develop, where `state_size()` is 6:

| direction | quantity | count |
|---|---|---|
| in | own ODE state — the strategy's states only | 6 |
| in | the light interpolant's knot **values** | 65 |
| in | its knot **slopes**, once the field carries them | 65 |
| in | soil water potential, one per layer | 5 |
| in | seeded differentiation targets | n |
| out | strategy rates | 6 |
| out | per-layer uptake | 5 |

**76 + n in, 11 out** on develop's value-only field; **141 + n** once the field carries a slope per
knot as well, which a cubic Hermite does and a value-fitted spline does not
(`../build-plan.md` §2.3, report 03). The slopes come from their own reduction over cohorts, so a
block cannot derive them. Three things that are *not* on either side, and each
was wrong in an earlier version of this table. `log_density` and `offspring` are not inputs,
because `Individual::compute_rates` never reads them; density reaches the world one level up,
through `Node::consumption_rate` and `Node::compute_competition`. `log_density_dt` and
`offspring_dt` are not outputs, per the paragraph above. And the height growth rate `g` is not a
twelfth output — it is `rates[HEIGHT_INDEX]`, and counting it separately double-counts it.

**The layout needs no table, because every segment is already contiguous.** The states are
`Internals::states`, the knot values are the interpolant's own `y` vector, the resource state is
the environment's state, and the parameters are `ad_parameters()` in the order the RcppR6 yml
declares. So the input vector is four existing runs concatenated, the layout *is* those four
sizes, and the forward pack and the adjoint scatter read them from the same accessors — which is
the only way they cannot drift apart. One assertion closes it:
`in.size() == state_size() + n_cohort_reads() + ad_parameters().size()`, with the environment's
count covering both knot data vectors and the resource state.

**`prepare_strategy()` must not run inside the block.** It builds the `Leaf`'s four 100-knot
interpolators and runs `height_seed()`'s root-find, and doing that per cohort per stage is about
4 million of each. It does not need to: the `Leaf`, the quadrature rule and the shading model are
passive; `eta_c` is one closed-form line in `pars.eta`; and `height_0` and `area_leaf_0` are read
by the birth path, not by the rate path, so `implicit_value`'s root-find is resolved once per
gradient evaluation rather than per block.

### 4.2 On the number of differentiation targets

`TF24_AD_FIELDS` declares **51** strategy parameters — the full trait and physiology
set (`lma`, `rho`, `hmat`, `eta`, ... `vcmax_25`, `p_50`, `K_s`, `jmax_25`, ...), not
a soil-specific subset. `Species::ad_parameters()` returns
`strategy->field_ptrs()`, pointers into the strategy's `pars`, generated from that
one macro list alongside `field_names()` so the two cannot disagree in membership or
order. That is the AD branch's arrangement; `../build-plan.md` P1.3 keeps the property and moves the
source to the RcppR6 yml, which is already the one place names and pointers are declared. K93 declares 11 and FF16 32.

So the realistic target count is **tens**, and for a calibration workflow plausibly
all 51. Environment and driver parameters are *not* in the macro — `birth_rate` is an
extrinsic driver rather than a strategy field, and how it would be seeded is an open
question this proposal does not settle.

This matters for two different quantities, and the distinction is the reason the
design tolerates large n:

- **If the local Jacobian is stored**, its size is `(54 + n) x 12`. At n = 4 that is
  5.6 kB; at n = 51, 10.1 kB. It grows with n, linearly and slowly.
- **If the cohort is re-recorded on the reverse pass — which is what section 1
  proposes — nothing is stored, and peak is flat in n.** Seeding more inputs adds
  registered tape slots, not recorded operations: the arithmetic of
  `Individual::compute_rates` is identical whether one trait is seeded or fifty-one.
  Only the trait-adjoint accumulator grows, by n doubles.

**Time is also flat in n.** A reverse sweep's cost scales with the number of output
rows, not inputs, so one sweep per cohort per step yields all n trait adjoints
together. That is reverse mode's central property and the decomposition preserves it
intact. It is also why reverse mode is the right choice here rather than a
convention: at n in the tens, a forward-mode alternative would cost n passes.

For reference against the recording it replaces: one cohort-step currently records
roughly **600 kB** (7 states x 86 kB), so a stored Jacobian would be a factor of 60
to 107 smaller depending on n, and a re-recorded cohort's tape is bounded by one
cohort's rates regardless.

---

## 5. Is the cohort a legitimate unit?

> **On develop it is not, and the reason is one line of TF24's leaf.** `set_physiology`
> calls `soil_consumption_.resize(n, 0.0)`, whose fill applies only to newly added
> elements, and `E_from_Soil_to_Root_Collar` writes only up to `max_soil_layer`. A
> shallow-rooted cohort therefore reads the previously-solved cohort's deep-layer uptake —
> **33.78%** of production records, measured. `../tf24-correctness.md` P0.1 is the fix; it
> is a prerequisite for this design, because the bit-identity check in §12 cannot pass
> against a forward pass that is order-dependent. The table below is otherwise accurate.

The decomposition is valid only if `Individual::compute_rates` is a pure function of
(its own `Internals`, the environment values it reads, the strategy's parameters). If
it carried information from one cohort to the next, re-running one cohort in
isolation would not reproduce the forward pass.

The risk is concrete. `Individual` holds a `strategy_type_ptr` (`individual.h:179`),
a `std::shared_ptr`, so **every cohort of a species writes into the same
`TF24_Strategy` object.** That object has three mutable members every cohort touches:

| member | verdict |
|---|---|
| `std::vector<double> mass_root_prop_` | scratch. `.assign(soil_number_of_depths_, 0.0)` at the top of every `net_mass_production_dt`, then refilled. Write before read. |
| `quadrature::QK function_integrator` | fixed rule, set once in `prepare_strategy`. Its `last_*` members are diagnostic only. |
| `Leaf leaf` | scratch, for the reason below |
| `Leaf::soil_consumption_` | **carried**, on 33.78% of production records. `set_physiology` calls `.resize`, whose fill reaches only new elements, and the solve writes only to `max_soil_layer`. `../tf24-correctness.md` P0.1 |

A fourth mutable member sits one level up, on `Species` rather than on the `Strategy`, and
it is carried by design:

| member | verdict |
|---|---|
| `Species::new_node` | **carried, deliberately.** The inflow boundary node, refreshed at the end of every `Species::compute_rates` and read by the *next* `compute_environment`. §3 sets out what that means for the decomposition. It is not a purity violation to remove; it is a boundary condition to design |

The `Leaf` is clean for a specific and slightly fragile reason.
`net_mass_production_dt` reaches it only through the local lambda `optimise_at`,
which calls `leaf.set_physiology(...)` **before** `solve_leaf()` on every invocation
(`tf24_strategy.cpp:401`). `Leaf::set_physiology` re-seats every per-solve field: it
assigns `psi_soil_`, rebuilds `grav_head_z_`, `.assign`s `c_r_V_` and `c_r_H_`,
resizes `soil_consumption_`, and sets `transpiration_cached_ = false`. And
`find_root_collar_psi` takes its bracket from `prepare_collar_solve` off the current
soil state and runs a **fresh** `golden_section_max` — there is no warm start. So the
leaf is a function of what `set_physiology` was handed, not of the cohort that used
it last.

Two exceptions were found. Both are correct in value today; both are prerequisites:

1. **`photo_temp_cached_`** (`leaf_model.h:250-252`) persists across cohorts and
   across the whole run, keyed on `(leaf_temp_, atm_o2_kpa_)`. The members it caches
   include `vcmax_` and `jmax_`, which depend on `pars.vcmax_25` and `pars.jmax_25` —
   **both declared entries of `TF24_AD_FIELDS`**. The key is a proper subset of the
   cached values' dependencies. This is safe only because those parameters are
   constant within a run.
2. **`psi_soil_cache_`** (`tf24_environment.h:304-328`) invalidates on
   `psi_soil_cache_state_[i] != vars.state(i)`, an exact `double` comparison against
   soil state. The AD branch closes the analogous hazard elsewhere with
   `if constexpr (!std::is_same_v<S, double>) cache_stale = true;`
   (`tf24_environment.h:394-400` on that branch).

**Conclusion.** The cohort is the right unit, and on develop one cohort's rates are a pure
function of its boundary **after `../tf24-correctness.md` P0.1 lands** — before that,
`soil_consumption_` carries the previous cohort's deep-layer uptake, and what it carries is
that cohort's finite-difference probe at a perturbed height. Two properties that survive
the fix are held by discipline rather than structure: `set_physiology` must re-seat every
per-solve field, and the two caches must be keyed on everything they depend on. Section 10
is about making those structural.

Separately, and at a different level: the *stage* is not a pure function of `(y, t)`,
because the field reads the lagged boundary node (§3). That is a property of the patch, not
of the cohort, and it does not touch the choice of unit.

---

## 6. The reverse pass in detail

### 6.1 Forward

Unchanged from `scm_gradient.h`, except that the trajectory is kept:

1. Run the adaptive double pass (`SCM::refine_schedule()`), resolving the node
   schedule and the ODE grid. `recorded_steps()` is the single source of the replay grid.
2. Replay that schedule in plain `double`, storing the full ODE state at each
   accepted step.

Storage at production: 1 137 states x 8 bytes x 5 055 steps = **46.0 MB** (projected), on
develop's counts from section 2.
This is the whole additional memory the proposal requires.

### 6.2 Backward

> **Three things about step (b) that this section's pseudocode leaves implicit.**
>
> **It is a vector-Jacobian product, not a Jacobian.** The block has **11** outputs for TF24 —
> 6 strategy rates and 5 per-layer uptake, per §4.1 — against **76 + n** inputs (**141 + n** with knot
> slopes, §4.1), and the matrix is
> never formed. Seed all 11 output adjoints and sweep once: cost is one sweep per cohort per stage
> regardless of how many traits are seeded, which is the property section 4.2 claims.
>
> **The primitive is a vector-Jacobian product and nothing more.** Doubles in, doubles out; the
> callable is generic and is instantiated at the active scalar inside, so plant never spells
> `xad::`. It requires no tape to be active on entry — the replay is pure `double` and the block's
> tape must be the only one — and it reports its recording size so the peak can be asserted
> without touching `xad::Tape`. The test on that size is the one that catches a block which has
> accidentally captured something active: peak bounded by one block, invariant in cohort count and
> in seeded-trait count.
>
> **The seeding order is forced.** Every output adjoint must exist before any block is swept, so
> `lambda_uptake` comes from step (a), `lambda_rates` from the stage recursion, and `lambda_g`
> from `lambda_log_density_dt`. There is no circularity and no freedom.
>
> **The stage recursion is not plant's.** The Cash-Karp tableau and stage states are
> `private static const` on `odelia::ode::Step`, so a reverse traversal cannot be written in
> plant. It belongs in odelia, reached through one new System requirement mirroring one that
> already exists: `ode_rates_adjoint(lambda_dydt) -> lambda_y` beside `ode_rates(y) -> dydt`.
> plant then implements `Patch::ode_rates_adjoint` — steps (a) to (e) — and keeps the
> between-step structure.
>
> **The inflow boundary is not parameter-only, and an earlier version of this banner said it
> was.** `log(birth_rate * pr_estab / g)` is not closed form in parameters:
> `establishment_probability` runs a full `net_mass_production_dt` at `height_0`, so both
> `pr_estab` and `g` read the light field and the soil, and both therefore depend on every other
> cohort's state. The dependence is also continuous rather than per-event, because
> `Species::compute_competition` closes its trapezium on `new_node` at every stage. §3.1 carries
> the mathematics — the forward inflow boundary is the adjoint's outflow boundary, one term,
> `lambda_n(x_b,t) / g(x_b)`, and that part stands. What does not stand is the inference that
> `SCM` therefore needs no `Solver` members; `../build-plan.md` §2.4 records that the reason is
> void and asserts no replacement.

Section 1's steps (a) to (e), per step, walking the trajectory backwards. Step (b) in
detail:

```
for each cohort j:
    fresh tape
    register:  own states (6), knot values (65) and slopes (65), soil potential (5), targets (n)
    record:    Individual::compute_rates for this cohort only
    seed:      lambda_rates (6) from the stage recursion, lambda_g from step (a)'s
               stencil, lambda_uptake (5) from step (a)'s soil adjoint
    sweep once
    read off:  lambda_states -> this cohort's lambda_y slots
               lambda_knots  -> the patch-level knot accumulator, for step (c)
               lambda_psi    -> lambda_y's soil slots, through dpsi/dtheta
               lambda_traits -> the run-level accumulator
    release
```

**Two of the four destinations accumulate across cohorts**, and both are load-bearing for the
same reason: one trait is one input read by every cohort, and one knot value is one input read by
every cohort whose crown spans it. The trait case is measured below; the knot case has the same
shape and the same silent failure mode.

**Trait adjoints accumulate over (b) across all cohorts and all steps**, and this is
load-bearing rather than incidental. Because the strategy is shared through a
`shared_ptr` and `ad_parameters()` returns pointers into its `pars`, a single trait is
one input read by every cohort. Earlier work measured that treating each cohort as a
distinct input instead yields **41 to 51%** of the correct answer, with the right
sign and no error raised. It must be tested directly.

### 6.3 What the field adjoint costs

Step (c) requires the adjoint of the light field, and its cost depends on the
interpolant:

- develop fits a **C2 cubic spline** to light values. C2 continuity is enforced by a
  tridiagonal solve over all nodes, so one light read depends on **every** node
  value, and its adjoint is a transposed band solve of run-dependent width.
- A **cubic Hermite** interpolant carrying value and slope at each node is local: one
  read depends on exactly **two** nodes, and its adjoint is O(1) per query. Verified
  rather than assumed: with an active node value registered on a tape,
  `d(eval)/d(node_2)` is 0.55 for a query in a span touching node 2 and **exactly 0**
  for a query two spans away.

Report 3 makes that case. The decomposition here is correct with either; only the
cost differs.

---

## 7. Evidence

A standalone system was built with plant's coupling structure and none of its
physiology: N cohorts, a shared light field with the same `(1 - (z/H)^eta)^2` kernel,
per-cohort rates containing an inner implicit solve, soil water as ODE state depleted
by the cohorts and read back, traits shared across cohorts, explicit Euler stepping,
and a mass-weighted census functional. Source: `scratchpad/cohort_toy.cpp`.

**This is a toy. It establishes that the decomposition and the reverse ordering are
correct, and how peak memory scales. It establishes nothing about TF24's physiology.**
The vacuity question is real — earlier work records a summed-height functional whose
constant adjoint could not detect a 19% error — so the functional here is
mass-weighted, and section 7.3's severance controls confirm the witness responds when
a live channel is cut.

### 7.1 Correctness

With the field queried exactly, isolating the adjoint machinery from interpolation:

| check | result |
|---|---|
| cohort-granular vs one whole-run tape | **1e-14 to 1e-15**, all configurations |
| AD vs central finite differences | **4.5e-10 to 3.4e-9** |
| finite-difference step dependence | improves as the step *grows* (1.9e-8 at 1e-7, 4.5e-10 at 1e-5) |

The last row places the finite difference as the less accurate party, which is the
roundoff-dominated regime earlier work also measured for a single unit.
Configurations: N in {8, 20, 40, 80}, 60 to 480 steps.

### 7.2 Scaling

| N | steps | one whole-run tape | per-cohort tape | field tape | trajectory |
|---|---|---|---|---|---|
| 20 | 60 | 20.8 MB | **1.0 kB** | 330 kB | 0.02 MB |
| 20 | 120 | 41.8 MB | **1.0 kB** | 331 kB | 0.04 MB |
| 20 | 240 | 83.9 MB | **1.0 kB** | 334 kB | 0.08 MB |
| 20 | 480 | 169.0 MB | **1.0 kB** | 339 kB | 0.17 MB |
| 40 | 240 | 321 MB | **1.0 kB** | 1 310 kB | 0.16 MB |
| 80 | 240 | 1 252 MB | **1.0 kB** | 5 184 kB | 0.31 MB |

- **The per-cohort tape is flat in both run length and stand size.** This is the claim
  the proposal rests on.
- The whole-run tape is linear in step count and quadratic in stand size.
- The field-assembly tape is flat in step count and quadratic in stand size (330,
  1 310, 5 184 kB for N of 20, 40, 80 — exactly 4x per doubling). In this toy L2 was
  placed on a tape for convenience rather than adjointed by hand, so this term is an
  implementation choice. It is quadratic because the toy's assembly is an all-pairs
  sum; plant's is O(n) by construction.

At the largest configuration the peak for the cohort path is **5.2 MB against
1 252 MB, a factor of 241**, and the factor grows with run length because the
numerator is flat and the denominator is not.

### 7.3 Under a multi-stage Runge-Kutta step

plant integrates with an adaptive RK45, so the step map is not the one-line Euler
update the sections above use. The toy was extended to classical four-stage RK4 with
the adjoint recursion written against the tableau:

```
lambda_k_i  starts at  h * b_i * lambda_{n+1}
visit stages in REVERSE order, so lambda_k_i is complete when it is used:
  lambda_Y_i, lambda_theta  +=  vjp_rhs(Y_i, lambda_k_i)     // the per-cohort sweeps
  lambda_n += lambda_Y_i
  lambda_k_j += h * a_ij * lambda_Y_i   for every earlier stage j
```

The stage states `Y_i` are rebuilt by re-running the step in `double` rather than
stored, so the trajectory stays at one state per step.

| N | steps | whole-run tape | cohort tape | field tape | trajectory | cohort vs whole |
|---|---|---|---|---|---|---|
| 20 | 40 | 56.0 MB | **1.1 kB** | 331 kB | 0.01 MB | 1.78e-14 |
| 20 | 80 | 112.4 MB | **1.1 kB** | 333 kB | 0.03 MB | 1.41e-14 |
| 20 | 160 | 226.1 MB | **1.1 kB** | 337 kB | 0.06 MB | 1.36e-14 |
| 20 | 320 | 458.2 MB | **1.1 kB** | 349 kB | 0.11 MB | 9.30e-15 |
| 40 | 160 | 862.7 MB | **1.1 kB** | 1 324 kB | 0.11 MB | 3.40e-14 |
| 80 | 160 | 3 361.3 MB | **1.1 kB** | 5 241 kB | 0.21 MB | 1.33e-14 |

Against finite differences at N = 20, 40 steps: **4.80e-10**. Value bit-identical
between the two paths.

Two readings. **The stage structure costs the cohort path nothing** — the tape is one
cohort's rates at one stage, so six stages means six sequential tapes of the same size,
not one six times larger. And **it costs the whole-run path a factor of the stage
count**: at N = 20 and 160 steps, 226.1 MB under RK4 against 56.4 MB under Euler, a
factor of 4.0 for four stages. At the largest configuration the comparison is 5.2 MB
against 3 361 MB, a factor of **646**. The more stages the integrator uses, the larger
the advantage.

### 7.4 Wall clock

Cohort-granular against a whole-run tape over the same RK4 trajectory, best of three:

| N | steps | whole-run (s) | cohort (s) | ratio |
|---|---|---|---|---|
| 20 | 80 | 0.221 | 0.363 | **1.64x** |
| 20 | 160 | 0.453 | 0.728 | **1.61x** |
| 40 | 160 | 1.617 | 2.274 | **1.41x** |

The ratio improves as the stand grows, because the per-step field-assembly work is
shared across cohorts while the per-cohort tape cost is not. For comparison, earlier
work measured a step-local sweep at a flat 4.2x; the cohort-granular variant is
cheaper because the expensive per-cohort recordings are exactly the work the forward
pass already does, rather than a re-run of the whole step's arithmetic.

### 7.5 Under TF24's harder features

The inner solve was replaced with TF24's actual construct: a fixed-tolerance
golden-section maximisation over a bracket whose upper bound comes from the soil
state, with the envelope theorem for the objective and the implicit function theorem
for the side outputs, plus the boundary branch where the argmax lands on the bracket
end.

| leaf treatment | interior | boundary | cohort vs whole | AD vs FD |
|---|---|---|---|---|
| implicit root-find | — | — | 1.4e-14 | 4.5e-10 |
| argmax, all interior | 1 200 | 0 | 8.1e-15 | 1.1e-05 |
| argmax, bound at 0.60 | 1 200 | 0 | 1.4e-14 | 4.0e-06 |
| argmax, bound at 0.30 | 1 183 | **17** | 7.5e-15 | 2.9e-06 |
| argmax, bound at 0.10 | 0 | **1 200** | 9.8e-15 | **3.1e-10** |

**The decomposition is unaffected by any of it.** The argmax, the boundary branch, and
a run mixing the two all reproduce the whole-run tape to 1e-14 or better. The residual
AD-versus-FD discrepancy the argmax introduces is a property of the argmax node and is
report 2's subject.

**The witness is not vacuous.** Severing the argmax's influence on the side output —
the consumer the envelope theorem does not cover — breaks the gradient by **4.1%**
(root-find) and **11.6%** (argmax) while the decomposition stays at 1e-15.

### 7.6 Two defects found while building this

- **`pow(0, eta)` has a NaN derivative with respect to the exponent.**
  `d/d(eta) 0^eta = 0^eta log(0)`. In the toy this made exactly one trait's gradient
  NaN while the others stayed finite and plausible. plant's canopy kernel evaluates
  `pow(z / height, eta)` and the ground-level query is `z = 0`
  (`Patch::compute_competition(0.0)` is called by `Node::compute_competition`).
  Reachability on plant's active path should be checked; the failure mode is a single
  silently-NaN trait.
- **A bounded value with an unbounded derivative.** In an early version the per-cohort
  soil draw did not scale with stand size, so 20 cohorts drove the soil toward the
  pole of `psi = 1/(0.05 + theta)`. The census value stayed at 27 while the gradient
  grew by a factor of 1.85 per step to 6e14. Value-based tests cannot see this, and it
  is why TF24's soil positivity guards exist.

A third hypothesis was tested and **refuted**: that nodes at cohort tops would produce
collapsing spans as cohorts converge in height, making the interpolant ill-conditioned.
Minimum span measured 3.7e-2 over a full run in the toy, never close. **That figure does not
survive on the model**: measured on develop over 9 870 interior intervals the minimum spacing is
**8.2095e-06** and 23.5% are below 1e-4, all in the initial transient where the schedule introduces
cohorts 1e-5 apart in time (`../../scripts/cohort_spacing.R`). The toy's stand was synthetic; the
hypothesis it refuted is refuted only there. Report 04 §5 carries what that costs the conditioning
argument, and report 03 C3 what it costs an interpolant with knots at the cohort tops.

---

## 8. Leverage, projected to plant

| | current | proposed |
|---|---|---|
| peak tape | ~490 GB (86 kB x 1 128 x 5 055) | one cohort-step, ~600 kB |
| plus field adjoint per step | — | O(n) in plant, small |
| plus stored trajectory | — | 46.0 MB |
| plain-double evaluations per stage | 1 | 2 (one forward, one to rebuild the stage state) |
| recordings per (stage, cohort) | 1 | 1 |
| measured wall clock | 1x | 1.4-1.6x |
| scaling in target count n | — | flat in memory and in sweeps |
| new concepts a Strategy author sees | — | none |

The wall-clock cost is measured at **1.4 to 1.6x** and improving with stand size
(section 7.4), against a memory ratio that reaches **646x** at the largest
configuration tested and grows with both run length and stage count. That is the right
shape: a small constant factor in time for a memory saving that grows with everything
the problem grows in.

---

## 9. Constraints

**C1. The two caches in section 5 must be handled first.** `photo_temp_cached_`'s key
omits `vcmax_25` and `jmax_25`; `psi_soil_cache_`'s key is an exact `double`
comparison on soil state.

**C2. Runge-Kutta stage traversal — built and verified, with two gaps.** Section 7.3
implements it for classical RK4 and reproduces the whole-run tape to 1.4e-14. What
remains: the recursion is written against RK4's tableau with each stage depending only
on its immediate predecessor, and Cash-Karp's is denser, so the inner loop must become
a general `sum over j < i` rather than three special cases. And plant's stepper is
**adaptive** — a rejected step is computed and discarded, so the reverse pass must
follow the accepted steps only. `recorded_steps()` already gives exactly those, so this
is a matter of driving from that list rather than a new mechanism.

**C3. The field adjoint's cost depends on the interpolant** (section 6.3).

**C4. Trait adjoint accumulation is untested in plant.** The 41 to 51% figure shows
what a failure looks like and that it fails quietly.

**C5. Introductions inside a step.** `Patch::introduce_new_nodes` changes the ODE
width, and earlier work measured that applying a structural change *between* units
rather than inside one loses the newborn's adjoint — **19% error, correct sign,
silent**, undetectable by a constant-initial-condition toy. Every introduction time
was measured to lie on the ODE grid (141/141 and 233/233 for K93, 141/141 and 161/161
for FF16, 141/141 for TF24), so a step boundary is always available; the ordering
still has to be deliberate.

> **C5 is built (Phase 3, wave 5), and the ordering the section asked to be deliberate is now
> split across the two repositories for a reason the section does not give.**
> `Solver::solve_adjoint` held one System at one width and asserted the recorded state's width at
> every step, so a sweep across an introduction was impossible rather than merely wrong; every run
> widens at each introduction, measured widths `9 17 25 33 41 49 57 65 73` at lifetime 5. odelia now
> takes a segment range — `solve_adjoint(states, lambda, k_first, k_last)`, with the old signature
> delegating — and plant owns the between-segment structure, because **a width alone
> under-determines the narrowing**: `Patch::ode_state` is species-major, so "drop the last node" is
> wrong when an earlier species shed it, and the argument has to be a per-species list that odelia
> cannot form. `Patch::introduction_adjoint` **records the inflow boundary condition at the active
> scalar rather than hand-differentiating it**, so one vector-Jacobian product delivers both terms
> of the two-term derivative plus the state channel — which is also the answer to this section's
> "19% error, correct sign, silent": the newcomers' rows are contracted rather than dropped, and
> dropping them narrows the width just as well and returns a gradient that is finite, correctly
> signed and wrong. odelia's suite gains tests that every interior split of a recording sweeps
> **bit-identically** to the whole sweep. **Peak memory for the entire sweep is 1.5 MB**, 129.9 MB
> to 131.4 MB — §1's central claim, measured for the first time.
>
> **`implicit_value` is absent from plant, so §2.4's `d(height_0)/d(trait)` term does not exist.**
> It is in odelia at `implicit_node.hpp` and has **one** occurrence in the whole plant tree, inside
> a `static_assert` message, so the design's "three names cross from odelia into plant" is two.
> `height_seed` still refuses at an active scalar — it is one of the standing probe's two errors —
> and `height_0` is declared `double`, which is why `omega`'s gradient column is exactly zero
> conditionally rather than structurally: its only other channel is `fecundity_dt`, a terminal
> accumulator no rate and no census metric reads. Evidence in `../implementation-notes.md`,
> *Phase 3, wave 5*.

**C6. The stored trajectory is not sufficient on its own.** Each `Node` carries
`pr_patch_survival_at_birth`, a plain `double` set at birth, not part of `ode_state`,
which **divides** the fecundity rate (`node.h:74` states this; the division is at
`node.h:217`). Omitting it puts the error exclusively in
`offspring_produced_survival_weighted`, verified by discriminating prediction on both
K93 and FF16. It is recoverable deterministically from the schedule and the
disturbance regime, so no derivative is needed, but the reverse pass must restore it.
`Species::set_birth_state(times, patch_density, pr_survival)` exists
(`species.h:132`) and is called by no test.

**C7. The purity property has no structural defence.** Section 5 establishes it by
reading the current code. A future warm start in any inner solver would break it
silently, with every double-valued test still passing. `../tf24-correctness.md` **P0.10** is
the executable form of this constraint: permute a census of production states and require every
leaf output to be bit-identical, which is the only check a reordering can fail and a re-run
cannot.

---

## 10. What this asks of a Strategy author

The design's claim is that it adds no vocabulary. That is true of the *engine*: a
Strategy implements `compute_rates` and gets a gradient. But it does impose
requirements on how a scientific model is *structured*, and they are currently
undocumented and held by discipline rather than by the type system. Section 5 found
TF24 satisfying them, but narrowly, and by accident of one function's habits.

Stated as guidance for someone writing or extending a Strategy, each rule paired with
the concrete instance that motivates it:

**1. Per-cohort state belongs in `Internals`, and nothing may carry between cohorts.**
The reverse pass re-runs one cohort in isolation, so anything the forward pass left on
the shared `Strategy` and read back is invisible to it. `Internals` is the sanctioned
container and it is already the right shape.

**2. Shared mutable members on the `Strategy` are a liability, and the safe pattern is
write-before-read.** `mass_root_prop_` is safe because it is `.assign`ed at the top of
every call. `Leaf leaf` is safe because `set_physiology` re-seats it. Neither is
enforced. A member that is read before being written in the same call is a
cross-cohort channel, and no test would catch it — the forward pass is
order-deterministic, so a stale read reproduces exactly.

**3. A cache must be keyed on everything its value depends on, or not exist.**
`photo_temp_cached_` caches `vcmax_` on a key that omits `vcmax_25`. Correct today
because `vcmax_25` is run-constant; wrong the moment it is not, and a differentiation
target is exactly a parameter someone intends to vary.

**4. Narrow the environment interface.** The cost of differentiating a cohort scales
with how many environment values it reads. TF24 reads the light field's 65 knot values, their 65
slopes once the field carries them (§4.1), and 5 soil potentials. A Strategy that read the whole environment, or queried it at
state-dependent points chosen by a search, would be materially more expensive.

**5. Expose an inner solve's *residual*, not its *search*.** For a quantity defined
implicitly, the differentiable object is the defining equation, not the iteration that
found it. `odelia::implicit_value` takes the residual. `golden_section_max`'s argmax,
by contrast, is affine in its bracket and independent of the objective values, so
differentiating through the search yields something that is not the derivative of the
argmax (report 2 section 4).

**6. Never define a rate as a numerical derivative of an active quantity.**
`Node::growth_rate_gradient` computes `dg/dh` by a finite-difference stencil. The
stencil is a legitimate discretisation — it is the upwind form of the advection term
and the analytic alternative is unstable — but it must be evaluated on quantities that
carry derivatives, or the transport term's parameter sensitivity is dropped.

**7. Say whether a switch is a kink you mean.** TF24's `if (net_mass_production_dt_ >
0)` is a hard un-smoothed gate at the carbon compensation point where FF16 and K93 use
`smooth_positive`. A zero derivative may be exactly what the model means; the point is
that it should be a recorded decision rather than an accident of writing an `if`.

**8. Fixed quadrature rules are structure; adaptive ones are not.** `quadrature::QK`
places nodes as a deterministic affine function of its bounds, so an active bound
tapes correctly. An adaptive rule whose node *count* depends on active values would
make the recorded computation state-dependent.

The engine cannot check most of these. Rules 1 to 3 could plausibly be made
structural — see section 11 step 4 — and doing so would convert the riskiest of them
from convention into compile-time or assertion-time facts.

---

## 11. Implementation order

The ordered work list is `../build-plan.md`. It differs from an earlier draft of this section in
two ways worth stating here, because both change what this design has to prove.

**TF24 first, not K93.** K93 was the natural first witness — no leaf, no soil, closed-form
rates, so a failure belongs to the engine and nowhere else. Going straight at TF24 gives that
up, so attributability has to come from the verification design instead: one whole-`Patch`
recording at one state against the sum of per-cohort blocks at the same state tests the
decomposition; one block at stage 0 against a finite difference of that block tests one block;
one step's `lambda_y` against a finite difference of one step tests the stage recursion. Those
are built before the production gradient, not after it.

**No whole-run recording, at any lifetime.** Section 7's evidence came from comparing the
cohort-granular sweep against a whole-run tape, and that comparison is worth having — but
supporting it in plant is what made the SCM grow a Solver's members on the AD branch. The same
evidence about the decomposition is available from one state at the `Patch` level, where the
System already exists, so the whole-run comparison stays in the toy and does not enter plant.

**Two prerequisites survive from this report's original list**, both now in
`../tf24-correctness.md`: the shared-leaf carry-over (section 5, and P0.1), and
`photo_temp_cached_`'s key omitting `vcmax_25` and `jmax_25` (section 9, C1). The
`psi_soil_cache_` hazard in the same constraint needs re-reading against the resident path,
where the soil state is active every stage.


---

## 12. What would falsify this

Stated as checks rather than arguments, so the answer is a number:

- **A cohort's rates are not reproducible from its boundary.** Re-run one cohort's
  `compute_rates` from stored state plus stored environment reads and compare to the
  forward pass bit for bit. Any difference locates a carried-over quantity section 5
  missed — and rule 2 of section 10 says where to look.
- **Peak does not stay flat.** Report the per-cohort tape at K93 production width and
  lifetime, and at two target counts an order apart. Growth in either says the unit is
  not what section 4 claims.
- **Trait adjoints do not accumulate.** A gradient that is a fixed fraction of the
  finite-difference reference, with the correct sign, is the signature.
- **The RK stage traversal loses a term on Cash-Karp's denser tableau.** Section 7.3
  verified RK4, where each stage depends only on its predecessor. Re-run the same
  three-way comparison — cohort-granular, whole-run tape, finite differences — on the
  full tableau, and against the existing FF16 finite-difference gate. **This failure has no
  measured signature.** C5's 19% belongs to a different mechanism — a structural change applied
  between units rather than inside one, losing the newborn's adjoint — and borrowing it here
  would put a number on a failure nobody has produced. What is known is only that a lost term
  is silent, so the check has to be a comparison rather than a smell test.
