# Build plan: exact resident gradients for TF24

**Baselines.** plant `develop` @ `141dc8df`. odelia @ `854a8e183b0eab99c68fdb4d3aa5e5e6f6e1a060`.
Both AD feature branches contain work worth taking; §3 says what.

**Status: under review. Nothing here is built. Phase 0.5's measurements decide four of the
design choices below, so they come before Phase 1.**

---

## 1. Scope

**The prize is TF24 resident gradients at production lifetime.** Exact trait and parameter
gradients of the three census metrics (LAI, biomass, basal area) and R0/offspring for TF24 at
`max_patch_lifetime = 105.32`, with the canopy responding to the trait — verified against a
re-run finite difference, adding no engine vocabulary per model, and without slowing the
forward model.

Deferred, in this order:

| deferred | why it is later, not harder |
|---|---|
| invasion gradients | the invasion gradient is the resident one with the light interpolant's knot adjoints dropped (§2.7). Subtractive, so it follows |
| FF16, K93 | the same engine at a lower difficulty. Once TF24 works they are the templating plus the existing census reduction |
| calibration | needs a decision about intermediate trajectory states first (§6, Phase 4) |
| RODAS | out of scope. RKCK only |
| the stochastic solver | out of scope. It shares the Strategy, so it must keep compiling and its tests must keep passing |

**What TF24-first costs, and how it is paid.** K93 was going to be the first thing to run
because a failure there belongs to the engine and nowhere else. Without it, the first thing
that runs has a leaf and a soil, so attributability has to come from the verification design
rather than from model simplicity. That makes the block-locality checks (§2.5) the *first*
thing built, not a convenience.

The acceptance test is a number and a count. The count: a plant developer adding an emergent
metric writes one scalar-templated reduction and registers a name, touching no tape code and
no odelia code.

**Where the general problem turned out to be the easier one.** Going at TF24 rather than K93 forced
five questions that a simpler model would not have asked, and each was answered in a form that is
not TF24's:

| forced by TF24 | what the answer is |
|---|---|
| an inner optimum | any output that *is* the objective costs nothing; any other output pays for the argmax's motion, through the condition that defines it. Nothing in that is a leaf |
| a shared sub-model with per-solve scratch | one cohort's rates are a function of its declared inputs, checked by permuting a census (P0.10) rather than argued |
| a cohort reading a field built from every cohort | `Environment` declares what a cohort may read from it, as the same triple as its state — so the block's layout is four contiguous segments for any model |
| a reduction that needed a lower limit | it is the inflow boundary, not the smallest cohort — which fixed the water balance, the transport stencil's bottom neighbour and the field's quadrature at once, family-wide (P0.8) |
| a rate defined as a numerical derivative | difference on the grid the model already has, where the spacing has an exact rate (report 04 §2.1) |

So the scope restriction is narrow in what runs, not in what is settled. FF16 and K93 inherit all
five; the invasion gradient is this pass with one step omitted.

---

## 2. The architecture

Reports 00–04 and 07 carry the arguments and the measurements. This section states the
decisions, and spells out only what no report owns.

### 2.1 One implementation of the science, carrying the scalar it is evaluated at

`S = double` is production. No model equation is written twice.

The scalar lives with the types that own the parameters, and the containers read it off `T`, so
**no template parameter is added**:

```cpp
template <typename T, typename E> class Individual {
  using value_type = typename T::value_type;   // and likewise Node, Species, Patch
```

`Patch<T,E>` already declares `using value_type = double;` (`patch.h:22`); the change is to read
it from `T`. The `<T,E>` shape is unchanged, RcppR6's instantiation table keeps its shape, and
`Solver<patch_type>` is unchanged. There is no new System type and no second `Patch`.

**One parameter store per model, templated.** `TF24_Pars<S>`, not a double `pars` plus a separate
active copy, so a named trait registers active directly.

Two properties follow. The gradient reads the model's own allometry, quadrature and reductions,
so there is nothing to keep in agreement. And a model author who adds physiology gets it
differentiated or gets a build failure, never a channel that silently reads zero.

**What this rules out, and TF24 has an instance of it.** `TF24_Strategy` writes `Q` twice — once as
a member and once inlined into the hot-path `compute_competition`, with a comment saying the second
reproduces the first — and the `eta_c` formula three times across two strategies and `CanopyShape`.
P0.12 moves TF24 onto `CanopyShape`, which is the same class FF16 and K93 already call, so the
profile has one home before P1.2b templates it. Two further reasons sit on top of the duplication:
`pow`'s derivative at `u = 0` is `0 · (−inf)` and the field's lowest knot is exactly `z = 0`, so a
seeded `eta` makes one trait's gradient NaN at the first knot of every build; and the eta-specialised
multiply chains are about 9x the general `pow`, worth ~4% of forward time on arithmetic from M2.

`ff16_production_kernel.h` is the larger counter-example: its five elementary
functions are shared with `FF16_Strategy`, but `ff16_net_from_components` recomputes the mass
cascade (`mass_sapwood` written twice, in `ff16_strategy.cpp:39` and in the kernel, with nothing
keeping them equal), `FF16ProdPars<S>` re-declares 18 of `FF16_Pars`' 32 fields, and
`ff16_assimilation_deep_crown_replay` computes assimilation a second way. TF24 has no equivalent,
so the arrangement served one model and did not spread. Under this decision the class *is* the
templated form, so nothing needs a second copy — which also rules out the AD branch's parallel
leaf assembly (§3).

### 2.2 What carries `S`, and what does not

| stays `double` | carries `S` |
|---|---|
| `Control` — never a differentiation target | `TF24_Pars<S>` |
| `ExtrinsicDrivers` and their interpolator — fixed input data | the Strategy's precomputed members (`eta_c`, `height_0`, `area_leaf_0`) |
| `Leaf` — a sub-model with a declared boundary (§2.3) | `Internals<S>` |
| knot fractions, quadrature **abscissae as fractions**, sort keys | `TF24_Environment<S>`'s state; the light interpolant's knot **values**; a field query's **position** |

**A fraction is `double`; a position is not.** The two are easy to run together and they part company
in the crown integral, where the abscissa is the fraction `ξ_j` times the cohort's height. M1 measures
`d(I)/d(height)` as exactly zero if the field is read at that position's value, and M2 finds that a
`double` position with an active `eta` does not compile at all. So on the gradient path a position
carries `S` — passive-valued or not — and what stays `double` is the fraction it is built from.

With `Control` and `ExtrinsicDrivers` out, the double-to-active copy is `TF24_Pars<S2>` from the
values of `pars` and then `prepare_strategy()`. The AD branch's per-strategy field-copy function
carried things that no longer need carrying.

**A gradient is defined against one `Control`.** `GSS_tol_abs`, `ci_abs_tol`,
`node_gradient_eps` and `schedule_eps` all change the trajectory and hence the gradient, so the
entry point records which `Control` it differentiated at and refuses to compare across two.

**`birth_rate` is a target only as a scalar.** `birth_rate_y` becomes `std::vector<S>` with index
0 seedable when `is_variable_birth_rate == false`, an error otherwise.

### 2.3 The cohort block

The recorded unit is one cohort's rate chain at one Runge-Kutta stage. Report 01 §4.1 and §6.2
give the unit, the declared inputs, why the light enters as knot values, why step (b) is a
vector-Jacobian product, and why the seeding order is forced. For TF24 concretely:

**The block is `Individual::compute_rates`.** `Node`'s two demographic equations are outside it:
`log_density_dt` needs a *neighbour's* growth rate under the cohort-grid stencil, and `offspring_dt`
is closed form in a rate the block already emits.

| declared inputs | | outputs | |
|---|---|---|---|
| own ODE state — the strategy's states only | 6 | strategy rates | 6 |
| light interpolant knot **values**, which are `L = exp(-A)` | 65 | per-layer uptake, declared width | 5 |
| knot **slopes**, `dL/dz` — the interpolant's second data vector | 65 | | |
| soil water potential per layer | 5 | | |
| seeded traits | up to 51 | | |

**The knots hold `L`, not `A`.** `TF24_Environment::compute_environment` splines
`exp(-f_compute_competition(height))` (`tf24_environment.h:469-479`), so Beer's law is applied at
the field build and the block reads transmittance. Step (c) therefore chains `dL/dA = -L` before
distributing to `(area_leaf, density, height)`. Distributing `lambda_knot` as though the knots held
summed leaf area is a sign error times a factor of `L` — plausible-looking and silent.

**The Hermite carries slopes, and they are inputs too.** A cubic Hermite span is determined by the
value *and* the slope at each of its two ends, so a query reads four data numbers and the field is two
vectors of 65, not one. The slopes come from their own reduction over cohorts (report 03 §4), so they
are not derivable inside a block. Declaring only the values would leave the light channel a fixed
fraction of itself, with the correct sign and nothing thrown.

The two are not independent, and step (c) owns the link: the field stores `L = exp(-A)`, so
`dL/dz = -L · dA/dz`, and with `s_k` the summed slope kernel at knot `k` the data is `m_k = -y_k s_k`.
So `lambda_m` reaches both — `lambda_y += lambda_m · (-s_k)` and `lambda_s += lambda_m · (-y_k)` —
before either is distributed to the cohorts.

**141 + n in, 11 out.** The uptake vector's *declared width* is the layer count; the entries
actually written are the layers with root mass, which `max_soil_layer` gives and which follows the
rooting depth (report 02 §6.8). An unwritten entry is zero after P0.1, so its output adjoint is
zero and the count above is the right one to declare, seed and assert against. Four things sit on
neither side, and each is a plausible mistake:
`log_density` and `offspring` are not inputs, because `Individual::compute_rates` never reads them;
`log_density_dt` and `offspring_dt` are not outputs; and `g` is `rates[HEIGHT_INDEX]` rather than a
twelfth output.

**The block unpacks its states through `set_state`, not into `states[]`.** `Individual::compute_rates`
reads two aux slots it does not write — `competition_effect = area_leaf(height)` and
`height_inverse = 1/height` — and the only writer is `update_dependent_aux`, called from
`Individual::set_state(int, double)` and from `set_ode_state` (`individual.h:49, 54, 107`). Assigning
the unpacked inputs straight into `vars.states[]` therefore leaves `area_leaf` at whatever the last
forward call left there, which severs `height -> area_leaf` and with it every trait reaching the
rates through leaf area. Unpacking through `set_state` re-derives both on the block's own tape, so
they are inlined functions of `height` (report 00 §1) rather than inputs, and the input count stays
141 + n. `update_dependent_aux` keys on the state index, so per-index recomputation is sufficient.

**The input count is only fixed once P2.1 lands.** 65 is the knot count under §2.6's fixed
fractions; on develop the refiner re-chooses at each introduction and the count runs 33 to 129
(report 03 §1b). So `n_cohort_reads()` is well defined — and T4's size assertion statable — only
after P2.1, which Phase 2 already puts first.

`Leaf` stays `double` inside the block behind a declared boundary — in (soil water potential per
layer, root mass per layer, leaf area, radiation, conductance, its own twelve parameters), out
(profit, one uptake per rooted layer) — with its derivatives arriving as injected partials.
**Report 02 §6 is the design.** Its shape: carbon is an envelope row and free; the five flux
adjoints collapse onto one scalar and one divide; the gradient that closes them factors, so the
`2n + 1` potential, root-mass and leaf-area directions cost two scalars, one closed form and one
recovered on the reverse pass. So the boundary grows with neither the trait count nor the layer
count.

**Where it lives: on `Individual`, with each container packing its own segment.** The block *is*
`Individual::compute_rates` with its inputs declared, so it is that function with a boundary rather
than a new one — which matters because §2.1 rules out the per-model free function. Each of the four
segments is owned by the class that knows its size: states by `Individual` (`state_size()`), the
knot values and resource state by `Environment`, the parameters by the Strategy
(`ad_parameters()`, ordered by the yml). So the input vector is four existing contiguous runs
concatenated, the layout *is* those four sizes, and the pack and the adjoint scatter read them from
the same accessors. One assertion closes it.

**`prepare_strategy()` must not run inside the block** — it builds the `Leaf`'s four 100-knot
interpolators and runs `height_seed()`'s root-find, about 4 million times each. It need not: the
`Leaf`, quadrature rule and shading model are passive, `eta_c` is one closed-form line in
`pars.eta`, and `height_0`/`area_leaf_0` are on the birth path rather than the rate path.

**One thing to state rather than leave to habit.** `compute_rates` reaches parameters through
`strategy->pars`, so the active parameter values live on a shared strategy, re-seeded from the input
vector at the top of every block. That is write-before-read with identical values within a stage —
report 01 §10 rule 2's sanctioned pattern — but on the reverse pass, and it is a requirement. The
defence against a *missing* parameter is `ad_parameters()` coming from the yml (P1.3).

**It generalises, given one declaration.** The four segments are model-independent in shape, and
K93 (3 states, light only), FF16 (5 states) and TF24f (7 states) fit unchanged. The gap is the
middle one: nothing in `Environment` declares **what a cohort may read from it** — 65 knot values, 65 knot
slopes and 5 potentials for TF24, knot values only for FF16, a layer count for a stepped-light model. So
`Environment` gains that as the same triple as its state, which thread 1 has just made
iterator-generic:

```cpp
std::size_t n_cohort_reads() const;
template <typename It> It cohort_reads(It it) const;
template <typename It> It set_cohort_reads(It it);
```

Not speculative — something has to pack TF24's 65 + 5 regardless. Naming it as that triple means
the next model implements a pattern it has already seen.

**The block removes `growth_rate_gradient`'s scratch, and this has no report home.** Today
`Node::growth_rate_gradient` holds `thread_local std::optional<individual_type> scratch` so it
has a mutable `Individual` to perturb height on. Under §2.1 that is a `thread_local` holding
active values across block tape lifetimes, which is the class of fault that segfaults far from
its cause. It is not needed: the block *is* the rate chain as a function of height, so evaluating
it at two heights is two calls with different arguments and nothing to perturb. The scratch
survives only on the pure-double path, and **M5 measured that it is not worth having there either**:
a fresh copy per call costs at most 1.5% of the forward run, against a 1.9% spread between two runs
of the same arm, and reproduces offspring bit-for-bit. So the `thread_local` goes and nothing
replaces it — no member, no scratch, no third arrangement to explain.

### 2.4 Where each part of the reverse pass lives

Report 01 §6.2 explains why: the Cash-Karp tableau and stage states are `private static const` on
`odelia::ode::Step`, so a reverse stage traversal cannot be written in plant. **odelia owns the
within-step recursion; plant owns one new System member and the between-step structure.**

```cpp
// odelia, ode_step.hpp -- the argument order of step(), plus the adjoint it carries
// back. y is the step's start state, so the stage states can be rebuilt; k1..k6 and
// ytmp are already members, so the rebuild needs no new storage.
template <class System>
void Step<System>::step_adjoint(System& system, double time, double step_size,
                                const state_type& y, const state_type& lambda_out,
                                state_type& lambda_in);

// plant, patch.h -- the mirror of ode_rates, and like it, returns the advanced
// output iterator so it composes the same way
template <class ItIn, class ItOut>
ItOut Patch<T,E>::ode_rates_adjoint(ItIn lambda_dydt, ItOut lambda_y);
```

`Patch::ode_rates_adjoint`, given the adjoint of `dydt`:

```
a  the closed-form seeds -- everything a block needs before it can be swept:
     soil adjoint         lambda_uptake per cohort; the drainage cascade is bidiagonal,
                          with the positivity guard's rows zeroed where it fired forward
     transport stencil    lambda_g per cohort, plus a direct lambda_h (§2.6)
     offspring            lambda_fecundity_rate, and a direct lambda_mortality through
                          exp(-M) (`node.h:152-154`) -- a state, not only a rate
b  per cohort: record the block, seed its 11 output adjoints, sweep, read input adjoints
c  light knot adjoints -> (area_leaf, density, height)   two summed reductions, closed form
     slope to value       `m_k = -y_k s_k`, so lambda_m reaches lambda_y and lambda_s (§2.3)
     lower limit          the reductions close on the boundary node, so
                          `d(height_0)/d(trait)` through `height_seed` (P3.1)
     height_max           the knot fractions are held on `u = z / height_max`, so every
                          query carries `1/height_max` and `-z/height_max^2` (P2.1, P3.1)
d  allometry adjoint       closed form
```

The soil guard is `if theta_i <= theta_r and !(rate_i > 0): rate_i = 0`, so where it fired the
forward row is identically zero and the transposed row must be too. Closed form does not mean
unconditional.

These four letters are this plan's. Report 01 §1 splits the same work into five, its (e) being the
assembly `lambda_y_j = direct + field`, which is folded into (c) and (d) here.

**A trait read both inside a cohort and by the field reduction accumulates in two steps, and both
must be added.** Two of TF24's do:

| trait | inside the block, step (b) | in the field, step (c) |
|---|---|---|
| `k_I` | the absorption coefficient: `radiation = k_I · max(L, 1e-4) · PPFD` | the extinction coefficient: `comp(z) = k_I · area_leaf · (1 - u^eta)^2` |
| `eta` | the crown quadrature weight `q(z, h)`, and `eta_c` in the conductance and the sapwood volume | the same `(1 - u^eta)^2` shading kernel |

This is report 01 §6.2's accumulation failure — a fixed fraction of the truth with the correct sign
and nothing thrown — in a second place: **across steps rather than across cohorts.** The
cross-cohort case has a measured signature (41–51%); this one does not, and the two are independent,
so a test for one does not cover the other.

**The stencil is a seed, not a consumer, which is why it is in (a).** A block cannot be swept until
every output adjoint exists, and under §2.6's cohort-grid stencil a cohort's `g` feeds its
neighbours' `log_density_dt` as well as its own — so `lambda_g` is closed form in the stage
recursion's `lambda_log_density_dt` and must be formed first. After the blocks it would seed them
with a `lambda_g` that does not exist yet.

`SCM` keeps the between-step structure. **The inflow boundary contributes state terms, not only
parameter terms, and it contributes them continuously rather than at introduction events.**

The event's shape is the classical one and survives. For linear advection the adjoint runs
backwards in time, so the forward *inflow* boundary is the adjoint's *outflow* boundary: it needs
no adjoint condition and contributes the single term `lambda_n(x_b, t) / g(x_b)`.

What does not survive is "only parameter terms". `log(birth_rate · pr_estab / g)` is not closed
form in parameters — `establishment_probability` runs a full `net_mass_production_dt` at `height_0`
(`tf24_strategy.cpp:704-716`), reading the light field, the soil potentials and a leaf solve, and
`g` is the newborn's own height rate over the same inputs. Both therefore depend on every other
cohort's state. And the dependence is not confined to the 141 events: `Species::compute_competition`
closes its descending trapezium on `new_node` (`species.h:220-223`), so the boundary density is the
field quadrature's lower endpoint at **every stage**. The field is a functional of the state *and*
of the boundary condition, so `lambda_field` carries `∂A/∂n(x_b)` and then the condition's two-term
derivative — one through the flux `B = birth_rate · pr_estab`, one through `g(x_b)`.

Two dependencies, three orders apart, which is what makes this cheap:

| dependency | magnitude |
|---|---|
| `pr_estab` and `g` on *other* cohorts' state, through the field and the soil | O(1). `L` varies 6x across the seedling crown and the floor never binds |
| the boundary density on *itself*, through its own contribution to the field | a contraction of modulus **~1e-3** |

**The `max(light, 1e-4)` clamp cannot sever the first, and this is measured twice.** Over the
seedling crown `[0, height_0 = 0.344195]`, `L` runs **0.1657 to 1.0**, binding at **0 of 141**
introduction steps; the independent census of the field's light column gives minimum
**0.1657209**, 0 of 8 292 values at or below `1e-4` and none negative — the same 0.1657 to four
digits by a second route. It is structural rather than lucky: `L = exp(-A)` with `A` the leaf area
above `z`, so `L` is minimised at the ground by construction, and reaching `1e-4` needs `A ≈ 9.2`
against a maximum `A(0)` of **1.797**.

The self-loop is bounded because the boundary node's absolute contribution to `A` is at most
**1.346e-03** (median 2.1e-06), moving ground light by at most **3.48e-04**, 0 of 141 steps above
`1e-3`. So one Picard step closes the fixed point to ~1e-6 relative and the implicit-function
correction to the derivative is O(1e-3) — §11.2's decision, and the reason the adjoint may take the
naive within-stage derivative.

**So the reason this section gave for `SCM` not growing a `Solver`'s members is void, and no
replacement is asserted here.** The state dependence is real and measured; §11.2 decides what to do
about the lag it creates, and P2.7 lands it. The Leibniz term at the field reduction's lower limit is
owed whichever way that goes: with the boundary node the limit is `height_0` and the term is
`d(height_0)/d(trait)` through `height_seed`; without it the limit is the smallest cohort's height,
which is ODE state, and the term is still there on a different quantity. It is closed form and it
belongs with the knot adjoints (P3.1).

Peak is one cohort's block, constant in run length, stage count and seeded-trait count. The
trajectory is stored in `double`, one state per accepted step, 46.0 MB at production; stage states
are rebuilt by re-running the step rather than stored, so storage does not grow with the stage
count.

**Nothing crosses the boundary to describe the stage structure.** `step_adjoint` is a member of
`Step`, so the tableau it needs is already in scope and no stage count has to be published. That
matters because plant currently hard-codes one across the boundary — `environment_cache(6) { //
length of odelia::ode::Step` — on the mutant path, which §3 leaves dead. RKCK only, per §1.

### 2.5 Verification: local, and at the Patch level

No report owns this, and it is what pays for going at TF24 first.

| | check | what it tests | what it needs |
|---|---|---|---|
| **V1** | one whole-`Patch` recording at one state, against the sum of steps (a)–(d) at the same state | the decomposition | one state. No schedule, no trajectory, no `SCM` surface |
| **V2** | one cohort's block at one stored step, seeded on one output, against a finite difference of the same block, **with the leaf held constant** | one block's adjoint over the allometry, storage and demographic chain, attributably | the trajectory store |
| **V2L** | the leaf's partial derivatives against report 02 §6.9's three identities — stationarity, soil-side against stem-side flux, and the waist residual | the leaf's boundary, where a finite difference is the worse reference | one solved operating point |
| **V3** | one step's `lambda_y` against a finite difference of one step | the stage recursion | one step |
| **V4** | whole-run gradient against a re-run finite difference at production lifetime | the deliverable | everything |

**V2 verifies at stage 0 only.** A block lives at a stage, and stage states are rebuilt rather
than stored, so verifying at stage > 0 would need the rebuild working before it could check
anything. At stage 0 the state *is* the stored trajectory state, exactly. V3 covers the rebuild
and the tableau separately.

**Why the leaf gets its own check.** A re-run finite difference resolves the collar's response to
about four digits, and the residue the uptake partials turn on is four to nine percent of that response,
so a finite difference of the leaf solve cannot measure the quantity it would be checking — a
disagreement reports the reference rather than the scheme. V2 therefore holds the leaf constant,
which is exactly the split P3.2's step order already uses, and V2L takes the leaf's partials against
identities that hold by construction. V4 keeps its re-run finite difference: at the whole-run level
the leaf's partials are one contribution among many and the reference is no longer the limit.

**There is deliberately no whole-run recording.** Supporting one is exactly what made `SCM` grow
a `Solver`'s members on the AD branch, and V1 gets the same evidence about the decomposition from
one state at the `Patch` level, where the System already exists. V1 plus V3 makes a V4
disagreement attributable without it.

### 2.6 Three decisions the reports argue and this plan adopts

**Resident, with invasion following from it** (§2.7 below is the only part with no report home).

**The transport stencil differences across neighbouring cohorts**, not on a `1e-6` sub-grid.
Report 04 §2.1: the cohort-grid difference is not an approximation to `dg/dh` — it is exactly
`d(log dh)/dt`, because the spacing between two characteristics has an exact rate. So it is the
same discretisation as transporting counts, without changing the state or any consumer, and it
makes the scheme conserve individuals up to mortality where a sub-grid probe leaks them at
`O(dh g'')` (report 04 §2.2). It also removes about half of TF24's leaf solves (report 04 §3). A
sub-grid difference divided by `eps` amplifies roundoff by `1/eps` regardless of smoothness,
against a measured minimum spacing of **8.2095e-06** — so the divisor advantage is 3 470x at the
median and only 8x at the first percentile, not the four orders a toy measurement suggested
(report 04 §5). The choice does not rest on it: report 04 §2.1 makes the cohort-grid difference
exact rather than an estimate. Substituting the analytic `dg/dh` removes the upwinding
(report 04 §6).

**The light interpolant is held on `u = z / height_max` with fixed fractions.** This is a
prerequisite for the reverse pass and not only an accuracy choice. `rescale_spline` reads
`spline.get_x()` — the knot set the *previous* build left — and rescales it to the new `height_max`
(`resource_spline.h:152-158`), so the field is a function of the state **and** of which fraction set
is currently loaded. Within an introduction interval that set is constant and the positions come out
at `u_k · height_max` either way, so the build is pure there; across one it is not, because
`introduce_new_node` passes `rescale = false` and the refiner chooses afresh. A reverse traversal
crosses those boundaries backwards, so at 141 of 5 055 steps it would rebuild the field on a fraction
set from the wrong interval — a different knot count, not a small error. Fixing the fractions removes
the carried state, and with it the question.

Report 03 §1b:
`rescale_spline` is not cheaper than building adaptively, so it exists to keep the knot count
fixed across stages, and the map it applies is `x_k = u_k · height_max` — so the normalised form
is bit-identical, the knot positions become constant, and `height_max`'s sensitivity becomes
chain-rule terms in the query rather than a structural approximation. The fitted cubic keeps its
refiner and supplies the fractions; a `hermite_interpolator<S>` evaluates value and slope at them.

**The fractions are uniform, and the open question was a count rather than a state.** M3 asked which
state's refinement should supply them, over four candidate sets and a uniform refinement sweep. What
it found:

| candidate | knots | worst crown-mean shift |
|---|---|---|
| develop's first-step set | 33 | 8.4e-03 |
| develop's mid-run set | 115 | 3.3e-03 |
| uniform | 58 | 2.1e-03 |
| uniform | 65 | 1.7e-03 |
| uniform | 129 | 2.5e-04 |
| every step's set pooled | 279 | 8.0e-07, and circular |

**The error is resolution, not placement.** Doubling the uniform count divides the worst shift by 5.0,
6.7 and 5.6 — about `h^2.5`, which is the right rate for this field rather than a cubic's `h^4`,
because `L = exp(-A)` and `A` breaks in derivative at every cohort height where `Q(z/h)` kinks. So the
failure signature a bad set would show — a shift that does not shrink with knot count — does not
appear, and adaptive refinement could not improve the rate either, since those kinks move with the
state. A refinement-derived set is no better than uniform at equal count and worse at higher count:
uniform at 58 beats the mid-run set at 115 on every statistic, and the first-step set reproduces
uniform-33 to every digit, because at that state the field is flat and the refiner returns an equally
spaced set. The pooled set's exactness is an artefact of its being a superset; what it prices honestly
is 558 data numbers per stage against 130.

So: **uniform fractions, count chosen from the re-blessing tolerance.** 65 gives a worst-case
crown-mean shift of 1.7e-03 and a median of 1.6e-06, and keeps §2.3's input count at 141 + n; 129
buys 2.5e-04 for twice the data and takes it to 269 + n. The reference is develop itself, so these are
the shifts to re-bless against, not accuracy against the true field.

**What fractions gain against knots at the cohort tops, which is the alternative the reports argue.**
Fractions were adopted for structure: `x_k = u_k · height_max` is what `rescale_spline` already
computes, and fixing `u_k` makes the count and the positions run-constant, which is what removes the
carried knot set (above) and what lets the block declare its inputs at all. M3b measures the accuracy
side, and it goes the same way:

| placement | knots | median | p95 | worst | worst span / domain |
|---|---|---|---|---|---|
| uniform | 65 | 1.6e-06 | 1.9e-04 | 1.7e-03 | 1.6e-02 |
| uniform | matched, 3–143 | 2.7e-07 | 3.5e-05 | **7.2e-04** | 7.0e-03 |
| cohort tops | 3–143 | 6.9e-06 | 7.6e-03 | **1.6e-02** | **1.3e-06** |

**Cohort tops are 22× worse at the same count**, because cohort heights cluster and the field's
curvature does not: the minimum interior spacing is 8.2e-06 m on a 17.9 m domain, so a knot per cohort
top crowds many knots inside one bunch and leaves the gaps between bunches unresolved — and the field
bends where leaf area is, not where cohort tops are. It also confirms on the model the collapsing-span
hazard report 01 §7.6 could only refute in a toy: worst span 1.3e-06 of the domain, against a Hermite
that divides by the span width.

Report 03 §5.3's `O(h^4)` stands and is not the same claim: it subdivides cohort-top spans *uniformly*
to 142, 283 and 565 knots, so the kinks sit on knots and the spans are refined. That is the
placement's asymptotic rate; M3b measures the constant at a count a production run can afford. So the
fractions are not a purity tax — at production counts they are also the better placement.

### 2.7 Resident, and how invasion follows

The resident gradient is the one where the canopy responds to the trait. In the reverse pass that
is step (c): the knot-value adjoints propagate back into every cohort's `area_leaf`, density and
height, closing the light loop.

**The invasion gradient is the same pass with step (c) omitted** — the mutant reads a canopy that
does not respond to its trait. One branch in one step, not a second path.

So the resident case is the general one and needs no recorded environment. None of
`environment_history`, `environment_cache`, `save_RK45_cache` or `use_cached_environment` is on
its path, which keeps the two-record arrangement — `step_history` per accepted step,
`environment_history[step][stage]` per stage, resolved by matching time — out of it. Replaying the
wrong one of those gave a gradient wrong by 60×.

### 2.8 How the reverse pass runs

No report carries this. It is the control flow of one gradient evaluation, with the owner of each
line, and it is what §2.4's four letters sit inside.

```
plant, once     run the adaptive pass; the resolved schedule is r_ode_times()      P1.4
odelia, once    replay that schedule, recording (t, h, y) at each accepted step
plant, once     seed lambda on the states the census functional reads at T         P3.6

odelia          Solver::solve_adjoint, for k = K-1 ... 0 over the recorded steps:
                  (t, h, y) = checkpoint k
                  Step::step_adjoint(system, t, h, y, lambda_out, lambda_in):

                    # the rebuild: step()'s own arithmetic, unchanged
                    for stage i = 0 ... 5:
                        derivs(system, Y_i, k_i, t + ah_i h, i)     # plant: rates
                        system.ode_aux(aux_i.begin())               # keep this stage's aux

                    # the sweep: stages in reverse, so lambda_k_i is complete when used
                    lambda_k_i = h c_i lambda_out                   # the tableau's seeds
                    for stage i = 5 ... 0:
                        system.set_ode_state(Y_i, t + ah_i h)       # state and field only: P3.5
                        system.set_ode_aux(aux_i.begin())           # this stage's aux back
                        system.ode_rates_adjoint(lambda_k_i, lambda_Y_i)    # plant: (a)-(d)
                        lambda_in   += lambda_Y_i
                        lambda_k_j  += h a_ij lambda_Y_i   for every earlier stage j
```

**Why the rebuild is forward and the sweep is backward.** `Y_i` needs `k_1 … k_{i-1}`, so the stage
states can only be formed in order. `lambda_k_i` receives from `lambda_Y_j` for every *later* stage
`j`, so a stage's output adjoint is complete only after the stages above it are swept. The two orders
are opposite and neither is a choice.

**`Step` needs no new storage for the rebuild.** `k1`–`k6` and `ytmp` are already its members, and
`Y_i` is one line of the tableau off `y` and the `k`s. What it adds is six aux vectors, sized like the
`k`s.

**Six rate evaluations per step, not twelve.** The rebuild pays them, because `k_i` is what the
tableau needs. The sweep does not: the recordings *are* the cohort rate chain, at the active scalar,
so evaluating rates again in `double` first would compute everything twice. Hence
`system.set_ode_state` on the sweep must establish the state and the field and stop there —
`Patch::set_ode_state` today is `{ load states; set time; check finite; compute_environment;
compute_rates }` in that order (`patch.h:680-702`), so this is exposing its first four lines, not
changing them (P3.5). What it keeps is the field refresh: two reductions filling 130 numbers, whose
kernel sweep report 03 §5.5 measures at 15 µs, against the 2.9 ms a full rate evaluation costs.

**Where each of the three couplings meets the rebuild.**

*The light field.* Its span coefficients are affine in the four data numbers a span touches, so a
query is linear in the knot data and there is no linearisation point to get wrong. The block declares
the 130 data numbers as inputs and builds `hermite_interpolator<S>` from them, so the crown integral's
moving upper bound, `q(z, h)` and the interpolation all land on the block's own tape (§2.3). The knot
positions are `double` and run-constant (P2.1), so nothing structural is recorded and the same span
index serves the forward pass and every block.

**The query position is not one of those `double`s, and the distinction is the whole height channel.**
A crown abscissa is `z_j = h ξ_j`, so the field is read at an active position while being *indexed* at
a passive one. M1 measured what happens if the read freezes it: after the substitution `z = h ξ` the
Yokozawa weight carries no height at all, so the query is height's only route into the integral and
freezing it makes `d(I)/d(height)` **exactly zero**. odelia's older `Interpolator` already owns both
readings — `eval` freezes the query derivative, `eval_with_query_derivative` opts in, and its own
comment names a quadrature abscissa as the case that should — so what is needed is the same pair on
`hermite_interpolator`, which its `value_and_slope` makes one line: `value + slope · (u − to_passive(u))`.
Measured identical to re-evaluating the span polynomial actively, so the cheap form is the right one.

*The soil.* The sweep needs to know which of the positivity guard's rows fired — `theta_i <= theta_r
&& !(rate_i > 0)` zeroes a row forward, so the transposed row must be zero too (§2.4). The condition
is closed form in `theta` and the per-layer uptake, and `theta` is in the stage state, but the uptake
is summed over every cohort by `Patch::compute_rates` into a member and overwritten by the next stage.
So the environment publishes its per-layer uptake to aux and the guard is recomputable on the sweep
from the stage's state and its aux. That is the second reason the environment needs aux (P1.1), and it
is a diagnostic worth having forward.

*The order within a stage.* The aux is restored once, before any block is recorded; each block then
re-derives its own `competition_effect` and `height_inverse` from its unpacked state (§2.3), which
overwrites the restored pair with the same values at the active scalar. Restoring after a block would
replace an active value with a passive one and sever every trait that reaches the rates through leaf
area.

*The leaf.* Its operating point comes back with the aux, and `evaluate_root_collar_psi` refreshes
`psi_soil_inverted_` and the soil-side vulnerability integrals through `prepare_collar_solve` before
the partials read them — which is P0.1's second half, and the reason the 1 µs figure in §8b includes
a prepare. Measured (M7): the restore reproduces all 14 leaf outputs bit-for-bit, and one evaluation
at the stored point lands where the search left the leaf. **Bit-identity on a leaf with no history
needs P0.1**, whose stale deep layers make the outputs a function of the previous cohort's solve.

**What plant adds to be differentiable, in total.** `Patch::ode_rates_adjoint`, `set_ode_aux` on the
containers and the environment, and the split above. `Leaf::input_adjoints` is the model's own
mathematics rather than machinery. Nothing else on the science path acquires a reverse-mode name, and
no Strategy author sees one.

### 2.9 What is stored, what is recomputed, and the XAD boundary

Resident TF24 records two things: **the node schedule** (plant) and **the ODE step times**
(odelia, `advance_fixed`). `r_ode_times()` is the one source of the replay grid. With the schedule
recorded, introduction times are constants, so introductions widen the state without adding a
discontinuity.

**Storage is per accepted step. Everything within a step is recomputed, and one thing is carried
across the rebuild.** §2.8 is the walk. What each candidate for storing costs, at develop's counts
— 5 055 accepted steps, 1 137 ODE states, about 3.9 M (stage, cohort) pairs:

| candidate | size | what it would save | verdict |
|---|---|---|---|
| ODE state per accepted step | **46.0 MB** | the only way back into a step | **stored** |
| stage states, or the six stage rates | 276 MB | the rebuild, about 63 s (§8b) | recomputed: 276 MB is a poor price for one forward pass, and the rates are what the tableau needs anyway |
| the light field's knot data per stage | 37 MB | nothing — the rebuild fills it on its way to the rates, and the refresh is two reductions (P2.1) | recomputed |
| soil water potentials per stage | 1.2 MB | one closed-form curve per layer | recomputed from the soil state |
| each cohort's collar operating point | 31 MB if kept for the run | about **36 s**, and it pins the linearisation point to the forward one | **carried in aux**, six stages of it, live for one step (§2.8) |

The last row needs no mechanism of its own. develop already publishes the operating point to an aux
slot — `aux_idx_opt_root_psi`, alongside `opt_psi_stem_`, `E_up_`, `transpiration_` and `profit_`
(`tf24_strategy.cpp:160-167`) — because they are diagnostics a user reads. The rebuild solves every
cohort's leaf on its way to the rates, so the sweep gets the operating point back with the stage's
aux and evaluates the leaf there: about **1 µs** against **10.2 µs** to search for it again (§8b).
Six stages of aux is about 10 kB, held by `Step` beside `k1`–`k6`. An implementation that re-solves
pays 9.2 µs per (stage, cohort) — 36 s per gradient — and linearises at a point it re-derived rather
than the one the forward pass used. M7 measured the round trip bit-identical at 9 of 9 states, and
found that the operating point is the only thing needing publication — with P0.1 as its condition.

So the transfer is `ode_aux` on the rebuild and `set_ode_aux` on the sweep: the missing fifth member
of a family that already has four, in the vocabulary of the ODE contract rather than of reverse mode.
A model that publishes nothing to aux pays nothing and gains nothing.

**Steps, not stages, is the unit of storage** for three reasons that are all structural. The state
width changes only at introductions, and those land on step boundaries (below). A rejected step is
computed and discarded, so its stages never enter the solution, and `recorded_steps()` already lists
only accepted ones. And a stage is addressed by index rather than by time (below), so a stage-keyed
store would need the step index anyway.

**`Replayable` stays as it is, and the resident pass does not use it.** Its hooks are already called:
`Step::step` runs `record_stage(system, i)` after every stage and the call compiles away for a System
that does not satisfy the concept, and `derivs` chooses `set_ode_state(y, index)` over
`set_ode_state(y, time)` when a System reports a recorded field (`ode_interface.hpp:155-168`). So the
generic per-stage hook exists, and the question is whether the resident pass should use it or a typed
transfer.

**Two different requirements, which is why one concept cannot serve both.** `Replayable` exists for
state a System must **not** recompute, because recomputing would change the answer: a mutant reading a
canopy that must stay the resident's. The resident pass needs state it **need not** recompute, because
recomputing would give the same answer — a pure saving. The first has to be a System-side record,
because only the System knows what to freeze. The second does not: `ode_aux` already serialises it,
`set_ode_aux` restores it, the buffer is the solver's, and nothing in plant acquires a notion of a
stage or of recording.

Generalising the hooks to save arbitrary parts of a System would put that buffer back inside plant,
give the solver something it cannot check, and leave "part" undefined. It would also be for one
consumer: the mutant case already has `Replayable`, calibration wants trajectory states rather than
System records, and TF24's operating point is the aux case above. Reaching for the deeper
`Replayable` depth on the resident path is worse than unnecessary — it reuses recorded field values as
fixed `double`s, which sets the derivative through the field to zero, and that is step (c), the entire
resident channel.

There is no knot-position record — §2.6's fractions are fixed by construction — and no recorded
environment, since §2.7 recomputes it. The quadrature abscissae move with an active integration
bound, and inside the cohort block that is recorded rather than replayed, because both the
quadrature and the bound are on the block's tape.

**Introduction times, step times and stage times, precisely.** Introductions land on step
boundaries **structurally**, not just in measurement: `advance_adaptive` sets
`time = time_max` on its final step (`ode_solver_internal.hpp:304`), so a step always ends
exactly on the event time. Report 01 C5's 141/141 is a consequence. Within a step, RKCK's
stage times are `ah = {1/5, 3/10, 3/5, 1, 7/8}`, so **stage index is not time order**: index 3
(`k5`) is at `t + h` and index 4 (`k6`) at `t + 0.875 h`, and index 5 (`dydt_out`) is at
`t + h` as well. Two stages share a timestamp, so **a stage is addressed by index and never by
time**. develop's `set_ode_state(it, int index)` is index-based and correct; `load_ode_step`
resolves *steps* by time and is also correct.

`k1` is not a stage of its own step: RKCK is first-same-as-last, so `k1` is the previous step's
index-5 evaluation carried by `save_dydt_out_as_in` (`ode_solver_internal.hpp:355`). That is
clean for a reverse traversal — `dydt_out` enters neither the `y` update nor `yerr`
(`ode_step.hpp:140-154`), so it has exactly one consumer and no double counting. The exception
is every introduction: `Patch::introduce_new_nodes` rebuilds the field but does not recompute
rates (`patch.h:621-631`), and `set_state_from_system` then seeds `dydt_in` from the stored
rates and marks them clean (`ode_solver_internal.hpp:146-152`). So at 141 of 5 055 steps,
`k1` is the rate vector from before the newcomer entered the field, entering the update with
weight `c1 = 37/378`. **`lambda_k1` therefore belongs to the step boundary, and the step
boundary is where introductions live** — one seam, to be designed once (§11).

`odelia::ode::Solver` holds an `xad::Tape<double>` member, so plant includes XAD transitively and
always will. The rule is that **no plant file spells `xad::`**, checked by
`grep -r 'xad::' plant/inst plant/src` returning nothing. develop has one violation today, in
`src/leaf_model.cpp`. Forward-mode AD stays in plant — the leaf's gas-exchange optimum has one
input and one output, so forward mode plus the implicit function theorem is the right method —
and only the spelling moves.

---

## 3. What we take

Three names cross from odelia into plant, plus one small helper and one concept. **None exists at
the `854a8e18` baseline** — `implicit_value` and `hermite_interpolator` are on odelia's AD branch,
and `preaccumulate` was added there in `2a60998` and deleted again in `28059bd`. So all of it is
new code written against a design rather than a lift.

**`to_passive` is needed in exactly one shape, and it is not the one the AD branch used it for.**
Nothing on the *value* path converts: comparisons and branches work natively, the cohort order is
structural, the knot fractions are `double` by declaration under §2.6, and the graft idiom belonged to
a mechanism this design does not have. What does convert is an **index or a discrete choice taken from
an active value** — and `CanopyShape<S>`, which §3 takes as one file, already has three: the
`pow_eta` kind selected from `eta`, the box-model threshold `eta_c_`, and the `u <= 0` guard at the
crown base. The interpolant's active-position read is the same shape, `value + slope · (u −
to_passive(u))` (M1). So the rule is that a conversion may pick a branch, an index or a span, and may
never appear in a value a derivative flows through — which is checkable by where it is called rather
than by whether it exists. Note that `CanopyShape`'s `eta_c_` is the box threshold and is `double`,
while `TF24_Strategy<S>::eta_c` is the conductance and sapwood-volume constant and carries `S`: two
names, two jobs, and only one of them is on the gradient path.

| name | prior art | its one consumer in plant |
|---|---|---|
| `vector_jacobian_product` | `preaccumulate` (deleted) solved a different problem — it grafted partials back onto an enclosing tape. There is no enclosing tape here, so the graft, its first-order-only property and its return-type `static_assert` are all beside the point | step (b): the cohort block |
| `OdeElement` | new. Constrains the four recursive helpers so the state-transfer interface stops naming `double` (§11.1) | every container's ODE plumbing |
| `implicit_value(y*, F)` | AD branch, `implicit_node.hpp` | `height_seed`'s `uniroot` on `mass_live_given_height - omega`, so `height_0` and `area_leaf_0` carry the derivatives of `omega`, `lma`, `rho`, `a_l1`, `a_l2`, `theta`, `a_b1` and `a_r1` |
| `CanopyShape<S>` | AD branch, `canopy_shape.h`, and develop's own class underneath it | FF16 and K93 today; **TF24 once P0.12 lands**, which is what stops the profile being written twice and hands TF24 the eta-specialised chains it currently forgoes |
| `hermite_interpolator<S>` | AD branch, `hermite_interpolator.hpp`, **plus an active-position read** — it takes `double u` today, and M1 measures the crown integral's height adjoint as exactly zero without one. `Interpolator`'s `eval` / `eval_with_query_derivative` pair is the shape to copy | the light interpolant's evaluation (§2.6), and the crown integral's abscissae (§2.8) |
| a forward-derivative helper | new, small | `dprofit_droot_collar_psi`, so `src/leaf_model.cpp` stops spelling `xad::fwd` |

Two odelia changes have no plant-visible name: `Step` gains `step_adjoint` and a description of
its stage structure (§2.4), and the vector-Jacobian product reports its recording size so plant
can assert the peak without touching `xad::Tape`.

From plant `develop`: `Control()`'s defaults, `SCM::refine_schedule`, `r_ode_times()`.

**`Species::census<Psi>` is not one of them — it does not exist on develop.** `grep -r census
plant/inst/include/plant plant/R plant/inst/RcppR6_classes.yml` returns nothing at `141dc8df`.
develop has the hand-rolled trapezium in `Species::compute_competition` (`species.h:196-227`) and
nothing else that reduces over the size distribution with a supplied weight. The templated
`census<Psi>` is on the AD branch, so it belongs in the second list below — and it arrives with a
condition: its central expression is written on the **mass chart** (`get_log_mass()`,
`odelia::cohort_spacing`, `on_mass_chart()`), which §7 rules out. What is liftable is its
*off-chart* branch, which is the plain `density * psi` trapezium, plus the boundary logic it
reproduces from develop — `size() == 1 || (!broke && f_last > 0)`, P0.5's row. So P3.6 writes the
reduction against develop's boundary treatment, taking the AD branch's shape and not its state.
This matters because `census<Psi>` is what seeds the whole reverse pass.

**The mutant replay path is already dead on develop, and we leave it dead.**
`Patch::cache_ode_step`, `cache_RK45_step` and `load_ode_step` (`patch.h:727-775`) carry
comments saying odelia calls them; odelia at `854a8e18` does not, and neither does anything in
plant. `save_RK45_cache` defaults false and is set true only in `R/benchmark.R`. So
`environment_history` is always empty, `Patch::set_mutant` stops with "Run a resident first"
(`patch.h:236`), and `run_mutant` pins the replay grid to `patch.step_history`
(`scm.h:309`), which is still `{0.0}` — which is where the 60x came from. Meanwhile odelia at
`854a8e18` carries a *different* replay interface: the `Replayable` concept with
`record_stage` / `record_ode_step` / `replay_step` / `has_recorded_field`
(`ode_interface.hpp:42-48`), which plant does not implement. Phase 4's invasion task therefore
reconnects a dead path to a renamed interface; it does not resume a working one.

From the plant AD branch: the scalar templating as the starting diff, reshaped per §2.1;
`CanopyShape<S>`; birth size through `implicit_value`; the three census metrics as one
codomain-3 functional; `Species::census<Psi>` and `QK` templated; names and pointers from the
yml rather than a macro; and one line of `scm_gradient.h` — the check that the active value
reproduces the double value, which catches a configuration member that failed to cross
double-to-active and is not an acceptance test.


`28059bd` removed 697 lines and four primitives from odelia because nothing but their own
examples called them. Every name in the first table above has a consumer in §6 before it lands.

---

## 4. Documents

One home per fact, and the home is named before the code is written.
`docs/audit-2026-07.md` indexes what is archived.

| document | owns |
|---|---|
| `docs/build-plan.md` | this plan: architecture, what to take, tasks, gates |
| `docs/tf24-correctness.md` | the TF24 forward-model prerequisites |
| `docs/reports/00`–`04`, `07` | the derivations and measurements the plan rests on. Not edited to track progress |
| `odelia/AUTODIFF.md` | the System requirements, including `ode_rates_adjoint` |
| `odelia/ARCHITECTURE.md` | the `Tape` link across the DLL boundary |
| `plant/agents.md` §13 (new) | how a plant model author makes their science differentiable |
| `plant/NEWS.md` | every `old -> new` R-interface change, machine-actionable |

Two rules, enforced per task:

- A task that changes what a model author writes changes `plant/agents.md` §13 in the same PR.
  Past two pages, there is too much to learn.
- A task that adds a name to §3's four justifies it in the PR body.

`plant/agents.md` §13's outline:

1. **Your model is templated on its scalar; `double` is production.** Write the science once.
   If new physiology does not compile at the active scalar, that is the design working.
2. **Fractions are `double`; positions and values carry `S`.** A knot fraction, a quadrature
   abscissa as a fraction of the interval, and a sort key are decided on passive values, and declaring
   them `double` is how you say so. The *position* built from one is not: a crown abscissa is
   `height · ξ_j`, and reading the field at its value rather than at it makes `d/d(height)` exactly
   zero (M1). A knot *count* that depends on an active value makes the recorded computation depend on
   the state.
3. **An inner solve is declared by its residual,** through `implicit_value`. Never
   differentiate the iteration that found the root: `golden_section_max`'s result is affine in
   its bracket and independent of the objective's values, so recording the search returns the
   bracket's derivative.
4. **Never define a rate as a numerical derivative of an active quantity.** If a rate is a
   difference, difference on a grid the model already has.
5. **A clamp, floor, `min`/`max` or `if` on a computed value is a derivative decision.** Put it
   in the switch inventory with the incidence that justifies it.
6. **Never give a deduced return type to anything returning an active value.** XAD operators
   return expression templates holding references to their operands, so a deduced return type
   hands the caller references to temporaries that die on return. The reverse sweep then reads
   reused stack memory and segfaults arbitrarily far from the cause, and valgrind cannot see it
   because the storage is stack. Declare the scalar return type on every such function and
   lambda, including one-line helpers.

---

## 5. Phase 0 — forward-model prerequisites, no AD

[`tf24-correctness.md`](tf24-correctness.md) and report 07. P0.1 is a prerequisite because V1
and V2 compare a decomposed computation against the forward pass, and on develop the forward
pass is order-dependent.

| | task | size | gate |
|---|---|---|---|
| **P0.1** | `soil_consumption_.assign(...)` — stop a cohort reading the previous cohort's deep-layer uptake | 1 line + baselines | a seedling's deep layers read 0 on a leaf that solved a tree first; `solve(seedling); solve(tree); solve(seedling)` bit-identical |
| **P0.2** | zero `soil_consumption_` and `E_up_` in `set_shutdown_state` | 3 lines | a shut-down solve reports zero uptake whatever ran before |
| **P0.3** | `soil_moist_from_psi`'s missing `* 1e6`, plus a round-trip test | 1 line + test | round trip to 1e-12 for θ in (θ_r, θ_sat] |
| **P0.4** | size the resource vector by resource count, not ODE width | small | no `NA_REAL` reaches `resource_depletion` |
| **P0.5** | **the switch inventory** — every clamp, floor, `min`/`max`, ternary and branch on a computed value on TF24's carbon, water, **demographic and field-reduction** paths, classified, each with a measured incidence | doc + probes | every row has a number. Includes `height_max`'s selector (§2.6) and the operating-point selector (§8) |
| **P0.6** | the two ecology decisions: leaf respiration counted twice, and `establishment_probability`'s hard gate | owner's call | a recorded decision either way, with a `scientific_version` bump |
| **P0.7** | `q(z, height)` divides by `z`, so `q(0, h)` is NaN for every `h`, and the light interpolant's lowest knot is exactly `z = 0`. The value's NaN; P0.12 is the derivative's, at the same point | small | `q(0, h)` finite for every `h` |
| **P0.8** | a reduction over the size distribution starts at the boundary node, not at the smallest cohort — three reductions disagree. Family-wide | small + baselines | a one-cohort species draws nonzero water; the light and water reductions integrate the same domain |
| **P0.9** | `ode_rates` is not the derivative of `ode_state` after an introduction, so `k1` is the pre-introduction rate vector at 141 of 5 055 steps. Family-wide | 1 line + baselines | `ode_rates` after `introduce_new_nodes` equals `ode_rates` after a further `compute_rates()` |
| **P0.10** | the shared `Leaf`'s purity is enumerated by reading and never executed | probe | every leaf output bit-identical across permutations of a production state census |
| **P0.11** | the boundary node solves the same leaf twice per stage, at identical arguments — two adjoints where one will do. Family-wide | small | `establishment_probability` at the boundary node bit-identical, and one fewer leaf solve per species per stage |
| **P0.12** | **TF24 writes the canopy profile itself, twice, and pays `pow` for it.** `Q` exists in `TF24_Strategy::Q` and inlined again in the hot-path `compute_competition`; `eta_c`'s formula exists three times; and `pow`'s derivative at `u = 0` is `0 · (−inf)`, which is the field's lowest knot at every build. Moves TF24 onto `CanopyShape`, which FF16 and K93 already use | small + baselines | `CanopyShape::Q` against TF24's over a production census, the shift recorded and re-blessed; no `pow(u, pars.eta)` left in `tf24_strategy.cpp`; `q(0, h)` finite for every `h`. The seeded-`eta` half of that guard needs an active scalar, so it lands with P1.2b |

**What has landed, with the commit that did it, is a table in
[`tf24-correctness.md`](tf24-correctness.md); the evidence is in
[`implementation-notes.md`](implementation-notes.md).** Neither is tracked here — this table stays the
specification.

P0.5 is the input Phase 3 needs: you cannot choose which switches to smooth before knowing
which fire. **P0.6's establishment gate is now settled: the hard gate stays.** Measured on both
sides, its argument's negative values are comparable to its positive ones — the most negative is
about twice the open arm's median — so it separates two real carbon states rather than deciding on
noise, and develop's `storage_prod_eps = 1e-4` would be six times too large to smooth it with. What
survives for Phase 3 is narrower: a re-run finite difference of a census gradient crosses the gate in
the recruitment window, so V4 chooses states and step sizes that avoid it. **P0.6's respiration half
remains the owner's.**

**Which of these gate the engine.** `tf24-correctness.md`'s own split is **P0.1–P0.4, P0.8, P0.9
and P0.10**; P0.5–P0.7 gate TF24's phase only, P0.11 gates the reverse pass's recruitment
channel rather than the forward comparisons, and **P0.12 gates P1.2b** — it decides whether that task
templates one canopy profile or two. The reasons differ and are worth keeping separate.
P0.1 and P0.10 are the same claim at different strengths — that one cohort's rates are a function of
their declared inputs — and V1 and V2 both compare a decomposed computation against the forward
pass, so neither means anything until it holds. P0.4 puts four `NA_REAL` per cohort per stage into
`resource_depletion`, and under a reverse sweep `NaN * 0` is `NaN`, so it poisons the adjoint where
forward it stays latent. P0.8 makes two reductions disagree about where the size distribution
starts. P0.9 makes a reverse traversal differentiate at the wrong point at 141 of 5 055 steps, with
the right sign and nothing thrown.

---

## 5b. Phase 0.5 — measurements that decide the design

None on the critical path; each can kill or confirm one choice in §2.

| | measurement | what it decides | needs |
|---|---|---|---|
| **M1** | **A block with a moving integration bound — run.** `scripts/m1_moving_bound.cpp` | whether the block boundary closes, including the moving bound, and **it does**: the height adjoint matches a central difference to 1.2e-11 … 7.4e-10 at heights 0.3442, 2, 8 and 17.9429, and the knot-value channel to 8 digits. It also found the one thing that has to be added — `hermite_interpolator::eval` takes `double`, and with the query frozen `d(I)/d(height)` is **exactly zero at 4 of 4**, because after `z = h·ξ` the Yokozawa weight carries no height and the query position is height's only route in. The fix is the `value + slope·(u − value_of_u)` graft odelia's older `Interpolator` already owns as `eval_with_query_derivative`, one line over hermite's `value_and_slope`; measured identical to re-evaluating the span polynomial actively | done |
| **M2** | **`CanopyShape<S>` against develop's — run.** `scripts/m2_canopy_shape.cpp` and its `.sh`, which holds both versions in one translation unit rather than porting one | §2.1's shape, and it confirms it. **Bit-identical**: 0 differences over 2 048 (height, position) pairs for each of `q`, `Q`, `leaf_area_above` and `Qp` at eight etas, so the switch on a stored kind costs no digits against the function-pointer dispatch. **The eta channel is live**: `d(Q)/d(eta)` matches a central difference to 7–9 digits at 6 of 8 states, the other two at the reference's floor. **No forward cost**: 59.8 ms against develop's 88.3 ms for 12.8 M `q+Q` at eta 12 — read as an upper bound on the risk, not as the model's number, since P1.2's whole-run benchmark is the gate. And it found that a **`double` position with an active eta does not compile** (XAD's `pow` expression will not convert), so the severance cannot be silent — but every gradient-path caller must reach the profile with an S-valued position, the field build's run-constant knot positions included. Same conclusion as M1 from the other side. P0.12 is what gives TF24 a consumer for it | done |
| **M3** | **The normalised light coordinate, accuracy half — run.** `scripts/m3_fixed_fractions.R`, four candidate fraction sets plus a uniform refinement sweep | §2.6, and it **closes the open choice**: the shift is resolution rather than placement (about `h^2.5`, since `A` breaks in derivative at every cohort height), so uniform fractions at 65 knots give a worst-case crown-mean light shift of 1.7e-03 and a median of 1.6e-06, beating both refinement-derived sets — one of which, at 115 knots, is worse than uniform at 58. What remains is the **bit-identity half**: `x_k = u_k · height_max` is exact arithmetic within an introduction interval, and that is a statement to check against the built interpolant rather than against develop's recorded knots | accuracy half done |
| **M4** | **The transport stencil across neighbouring cohorts.** Value change against the sub-grid stencil on one production run; conditioning of both against a finite difference | §2.6, and the size of the forward-value change to re-bless | `double` for the value; M1 and M2 for the derivative |
| **M5** | **The scratch — run.** `scripts/m5_scratch.R` with `docs/reports/m5-scratch-arms.patch`: `thread_local`, a `Node` member, and a fresh copy per call, selected at runtime so one build serves all three | §2.3's last paragraph, and it settles it more simply than the prior did. Min-of-three: 86.1–86.8 s for the `thread_local`, 87.6 s for both others — **at most ~1.5%**, against a 1.9% spread between two runs of the same arm, and all three reproduce offspring `42.140173575095666` exactly. So no arm is worth choosing on speed, *including the one with no scratch at all*: the `thread_local` can go and nothing has to replace it. The prior — a member is no slower and possibly warmer — is wrong in its second half and irrelevant in its first | done |

| **M6** | **The leaf's boundary — run.** `scripts/leaf_bundle.R`, `leaf_waist.R`, `leaf_waist2.R`, `leaf_waist3.R`, `leaf_translation.R`, `leaf_translation_R.R`, `leaf_uniform_check.R`, `leaf_recover_a.R`, against develop at 5 and 20 layers and two species | report 02 §6, and it confirmed it: the envelope row exact for a leaf trait, the waist's joint residual 2.6e-04 to 9.2e-04 over 41 directions, `waist_b` against its closed form to 0.16–1.04%, `waist_a` recovered to 1e-05, both translation defects exact, and the stationarity gap that makes P2.6 a prerequisite | done |

| **M7** | **The aux round trip — run.** `scripts/aux_round_trip.R`, nine states including three drier than the driver reaches | §2.8's carry, and it confirmed it, **conditional on P0.1**: restoring `set_physiology`'s inputs and evaluating at the stored operating point reproduces all 14 leaf outputs bit-identically after an intervening solve elsewhere (9/9), and one evaluation lands where the search left the leaf (9/9), so the sweep pays an evaluation and not a search. On a *fresh* leaf 8 of 9 are bit-identical and the ninth is P0.1 — the seedling's unrooted layers 3–5 carry the previous cohort's uptake, so today a leaf's outputs are a function of the previous cohort's solve as well as of its own inputs and aux. Nothing beyond the operating point needs publishing. For the soil: the guard reads the stage state, the cascade, `rainfall(time)` and the per-layer uptake and no other member, so aux closes it — and θ's minimum over a production run is **0.1563 against θ_r = 1e-2**, so the zeroed rows are correct and unexercised at this driver | done |
| **M8** | **The descending-height invariant — run.** `scripts/descending_heights.R` | whether `height_max`'s adjoint and the stencil's sign need a guard, and they do not on this configuration: **0 of 10 011** neighbouring pairs non-descending over 142 output times, largest gap `-8.209404e-06`, median spacing 3.527e-03. The closest pair is 8.2 µm apart, which matches report 04 §7.1's boundary-interval minimum
(8.2094e-06) rather than §5's interior figure (8.2095e-06) — §7.1 asks which of the two is a rounding
of the other, and this is a third measurement landing on the first, so `height_max = nodes.front().height()` and `dh > 0` hold — with an 8 µm margin, one species, the default driver | done |

M1, M2 and M5 are done, so M4's derivative half is unblocked as well as its value half. M3's accuracy
half is done and settles §2.6; its bit-identity half waits on P2.1's interpolant existing. M6 is complete, and P3.2 and P3.3 are written against it. M7 and M8 need no AD and run on develop
today; both were added because the reverse pass acquired a dependency the forward model has never been
asked about — M7 for the aux carry, M8 for an invariant three consumers now share. **Both are now
run, and both answered yes**; between them they moved one item, which is that P0.1 now gates the
reverse pass as well as the forward comparisons.

---

## 6. Phases 1–4

One PR per task. Each says what to write, in what order, and what closes it.

### Phase 1 — make the model differentiable and store a trajectory

Nothing here computes a gradient.

---

**P1.1 — the odelia surface.** From `854a8e18` on `master`.

Nothing here is a lift: none of the names exists at the baseline (§3). Three have prior art on
odelia's AD branch, one is new, and one is the concept that stops the state-transfer interface
regressing.

```cpp
// ode_interface.hpp -- the state transfer, at the element's own value_type iterator.
// That is the one thing a double-typed signature gets wrong, and it fails here rather
// than deep inside derivs. The two legacy double typedefs go.
template <typename E>
concept OdeElement = requires(E e,
    typename std::vector<typename E::value_type>::iterator it,
    typename std::vector<typename E::value_type>::const_iterator cit) {
  typename E::value_type;
  { e.ode_state(it) }      -> std::same_as<decltype(it)>;
  { e.ode_rates(it) }      -> std::same_as<decltype(it)>;
  { e.ode_aux(it) }        -> std::same_as<decltype(it)>;
  { e.set_ode_state(cit) } -> std::same_as<decltype(cit)>;
};

template <std::forward_iterator FwdIt, class It>
  requires OdeElement<std::iter_value_t<FwdIt>>
It ode_rates(FwdIt first, FwdIt last, It it);      // and ode_state, ode_aux, set_ode_state

// One block, recorded and swept once. f is generic and is instantiated at the active
// scalar inside, so plant never spells xad::; doubles cross the boundary. Returns the
// recording size, so plant can assert peak without touching xad::Tape. Stops if a tape
// is already active -- the replay is pure double, so the block's tape is the only one.
template <class F>
std::size_t vector_jacobian_product(const std::vector<double>& x,
                                    const std::vector<double>& output_adjoints, F&& f,
                                    std::vector<double>& input_adjoints);

// ode_step.hpp -- step()'s argument order, with y needed to rebuild the stage states
template <class System>
void Step<System>::step_adjoint(System&, double time, double step_size,
                                const state_type& y, const state_type& lambda_out,
                                state_type& lambda_in);
```

The concept constrains the iterator type and nothing else. `ode_size()` and `aux_size()` are the
other two helpers' whole requirement, and a missing member already reports itself; a wrong iterator
type is what produces a page of template errors, so that is what the concept is for.

`set_ode_aux` is an ordinary member, not an opt-in behind a concept. It is the mirror of `ode_aux`, so
the family is five and the solver can assert what it asserts of the other four: the iterator advanced
by `aux_size()`. A hook the System answers by index gives the solver nothing to check, which
disqualifies it here — this machinery exists to stop a silently wrong gradient. odelia's own Systems
have no aux and return the iterator unchanged; `Patch`'s is the one implementation that does work, and
it is written once for all four model pairs.

**`Environment` becomes one of the elements.** `Patch::ode_aux` runs over the species range only
(`patch.h:808-812`), where `ode_state` and `ode_rates` both continue into the environment. That
asymmetry is what leaves the soil's positivity guard unrecoverable on the sweep (§2.9), so the
environment gains `aux_size`, `ode_aux` and `set_ode_aux`, and publishes its per-layer uptake.

The product writes into a buffer the caller owns and returns the recording size. The buffer is
reused across 3.9 M calls; a returned vector would allocate on each, and a `last_recording_size()`
query would be namespace-scope state readable after the call that set it is forgotten.

`needs_time` stays as it is: it is `enable_if` and a detection struct, which new code may not be,
and rewriting it changes the time dispatch for nothing.

Plus `implicit_value` and `hermite_interpolator`, and the non-finite step-size rejection. One
concept covers the whole requirement: with the time dispatch untouched there is nothing for a
System-level one to say. The `r_*` family then names `std::vector<double>::iterator` inline, where
it means something.

**The conversion helper stays where odelia already keeps it, and plant calls it only to choose.**
Nothing on the value path needs it: comparisons and branches work on active values natively (XAD
defines them for `AReal`, expressions, and mixed active/`double` — `BinaryOperators.hpp:99-158`);
cohorts are kept in descending order by construction, so there is no sort key to extract; §2.6's
normalised coordinate makes the knot fractions `double` by declaration; and the graft idiom belonged
to `preaccumulate`'s inject-onto-an-outer-tape mechanism, which this design does not have. What plant
does need it for is picking a branch or an index from an active value — `CanopyShape<S>`'s three uses
(§3) and the interpolant's span index — and `odelia::util::to_passive` in `ode_util.hpp` is where
those already read it. The line to hold is the one the AD branch crossed: a conversion inside a value
whose derivative is wanted, which is how the XAD boundary erodes. The R boundary's extraction is
separate and lives in the `r_*` family.

*Order.* The concept and the four helpers first, since P1.2a depends on them. Then
`vector_jacobian_product`, then `step_adjoint`, then `implicit_value` and `hermite_interpolator`
in either order.
*Must not break* the odelia suite, and `ode_util.hpp` must still include no XAD.
*Closes on* one test per name driven from a System rather than from an example; `step_adjoint`
reproducing a finite difference of one step on the Lorenz System; a negative test — a deliberately
`double`-typed element rejected by `OdeElement` with the error at the helper — and three on the
vector-Jacobian product:

| | test | what it catches |
|---|---|---|
| **T1** | the product against a central finite difference of the same block, on a System small enough to difference | the primitive itself |
| **T2** | `last_recording_size()` invariant across two input counts an order apart, and across two output counts | a block whose recording grows with something it should not |
| **T3** | calling it with a tape already active **stops** | a caller who wrapped the reverse pass in a tape, which would silently record the blocks onto it |

T2 is report 01 §1's central claim reduced to an assertion, and T3 is the precondition that makes
"the block's tape is the only one" checkable rather than assumed.

---

**P1.2a — the state-transfer plumbing, at `S = double`.** Probe-measured (§11.1), so this is a
known quantity rather than an estimate: **26 uses of the two legacy typedefs across 9 headers.**

| file | uses | |
|---|---|---|
| `patch.h` | 6 | deterministic |
| `node.h` | 4 | deterministic |
| `stochastic_patch.h` | 4 | stochastic |
| `environment.h`, `individual.h`, `species.h`, `species_base.h`, `individual_runner.h`, `stochastic_node.h` | 2 each | mixed |

`models/*.h` has none — `TF24_Environment` inherits `Environment`'s. Four of the nine files are
the stochastic and single-individual paths, which never carry an active scalar but do share the
plumbing, so they are in the sweep.

```cpp
template <typename It> It ode_state(It it) const;      // and ode_rates, ode_aux
template <typename It> It set_ode_state(It it);        // Patch also takes (It, double) and (It, int)
```

**Fifteen of the twenty-six are signature-only.** Probe B established that the read-out direction
(`ode_state`, `ode_rates`, `ode_aux`) needs no body changes at all, because `double` to active is
an implicit conversion. Only `set_ode_state` has work behind it, and that work is P1.2b.

*Order.* odelia's helpers and the concept (P1.1) first. Then the six deterministic-path headers,
then the three stochastic ones. Add `#include <plant/individual.h>` to `node.h`, which is missing
it (§11.1).
*Must not break* anything: at `S = double` the deduced `It` **is** `std::vector<double>::iterator`,
so this generates identical object code.
*Closes on* bit-identity — the TF24 and FF16 suites unchanged, the FF16 references unchanged, and
one production run reproducing offspring `4.214017357509567e+01` exactly — **at a pinned build**.
A `-O0` build of the same tree differs by 0.145% in offspring and 0.79% in accepted step count
(report 01 §2), so a gate that does not name its compiler flags measures the compiler.

---

**P1.2b — TF24 templated.** The largest task and the one to break into commits. Probe B named its
four entry points: `Environment::vars.states[i] = *it++`, `Individual::set_state(int, double)`,
`Node::offspring_produced_survival_weighted`, and `Node::set_log_density(double)`.

```cpp
template <typename S = double> struct TF24_Pars { S lma, rho, hmat, omega, ...; };
template <typename S = double> class TF24_Strategy : public Strategy<TF24_Environment<S>> {
  using value_type = S;
  TF24_Pars<S> pars;  S eta_c, height_0, area_leaf_0;  Control control;  Leaf leaf;
};
template <typename S = double> class TF24_Environment { using value_type = S; ... };
template <typename S = double> class Internals { std::vector<S> states, rates, auxs, ...; };
```

Then in each container, one line: `using value_type = typename T::value_type;`. **Six containers,
not four** — `Patch`, `Species`, `SpeciesBase`, `Node`, `Individual` and `Environment`, plus
`ResourceSpline`, which is a plain class today holding a concrete `Interpolator` and which sits on
the R boundary. `SpeciesBase` is the one shared with the stochastic path.

*Commit order, each bit-identical before the next.* (1) `Internals<S>` with `S = double`
everywhere else. (2) `TF24_Pars<S>` and `TF24_Strategy<S>`, `Control` and `ExtrinsicDrivers` left
`double`. (3) `TF24_Environment<S>` and `ResourceSpline<S>`. (4) the six containers reading
`value_type` from `T`. (5) the RcppR6 yml and regeneration. (6) remove `growth_rate_gradient`'s scratch outright. M5 measured
all three arrangements within 1.5% of each other, so nothing replaces it, and P2.4 deletes the
probe that needs it.
*Must not break* `test-strategy-tf24.R`, `test-strategy-tf24f.R`, `test-patch.R`,
`test-individual.R`, the stochastic tests, or the forward benchmark.
*Closes on* bit-identity at a pinned build — the TF24 suite unchanged, and one production run
reproducing offspring `4.214017357509567e+01` to the last bit — plus the forward benchmark inside
the accepted band. **The band is a ratio taken in one session on one machine, never an absolute
time** (§8b): the same tree at `-O2` has run **89.9 s**, **102.9 s** and **86.1 s** in three sessions,
every one reproducing that offspring value exactly and taking the same 5 055 accepted steps. The step
count and the value are properties of the tree and the flags; the seconds are not even reliably the
machine's, since two of those three are the same container image.
*The failure to watch for* is a deduced return type on anything returning an active value. XAD
operators return expression templates holding references to their operands, so the caller gets
references to dead temporaries, the reverse sweep reads reused stack memory, and the segfault
lands arbitrarily far from the cause. Valgrind cannot see it because the storage is stack.

---

**P1.3 — trait registration.** Names and pointers from the RcppR6 yml, which is already the one
source; no macro list.

```cpp
std::vector<S*>          TF24_Strategy<S>::ad_parameters();
std::vector<std::string> TF24_Strategy<S>::ad_parameter_names();
```

Both allocate, so they are called once per gradient evaluation and the pointers are held for the
run — not per block, which would put an allocation inside every cohort's sweep. That is safe for the
same reason §2.3's re-seeding is: the strategy is shared and the fields do not move.

*Closes on* a test asserting the two have the same size and order, and that seeding by name and by
index reach the same field.

---

**P1.4 — the trajectory store.** Replay the resolved schedule in `double`, keeping one state per
accepted step.

```cpp
// One accepted step. The state widens at an introduction, so the record is ragged.
struct ode_step_record { double time; std::vector<double> state; };

std::vector<ode_step_record> SCM<T,E>::store_trajectory();
```

A vector of those is the whole store. There is no wrapper type, because there is nothing for one to
hold besides the vector, and no separate `times`, because a time that lives beside its state cannot
disagree with it — `r_ode_times()` already exists as the schedule and would be a second list to keep
in step.

**Why the states have to be stored at all.** The reverse pass visits accepted steps backwards, and
at each one it sets the patch to that step's state, evaluates the right-hand side there — that is
`ode_rates_adjoint`'s precondition (P3.5) — and rebuilds the step's six stage states by re-running
the step in `double`. So it needs the ODE state vector at every accepted step, and nothing on
develop keeps one. §2.8 is how they are used and §2.9 what else was considered storing. The solver
holds only the current state; `SCM` keeps the schedule, which is times; and `run_scm(collect = TRUE)` collects R lists of the patch at the **142 output times**, not
the 5 055 accepted steps. Storing 5 055 double state vectors, 46.0 MB, is what makes the reverse
pass possible without a tape of the whole run, which is 490 GB (report 01 §2).

Nothing is replayed from a record. The resident pass rebuilds the light field and the soil
potentials from the state it has just set, exactly as the forward pass does (§2.7), so the store
holds state and nothing else.

**The birth values are not stored, because the replay sets them.** `pr_patch_survival_at_birth`
divides the fecundity rate and is not in `ode_state`, so a `Patch` reconstructed from stored state
alone gets `offspring_produced_survival_weighted` wrong and nothing else. P1.4 replays the resolved
schedule — a real run, in order — so `compute_initial_conditions` stamps every `Node` as it is
introduced, and `node_introduction_time` and `patch_density_at_birth` are already `Node` members.
What the reverse pass must not do is rebuild a `Patch` from the records and expect the stamps.

*Order.* Store and replay first. Then give `Species::set_birth_state` a test — today it has none,
and it is the only public route for the stamps if anything ever does need to reconstruct rather than
replay.
*Closes on* the replayed final state being bit-identical to the forward run.
*One state per accepted step is sufficient for the reverse pass only once P2.7 lands; P1.4's own gate
is unaffected, because a replay runs forward.* A sequential replay reproduces
develop's lagged boundary density for free, because it visits the stages in the same order the
forward run did. A reverse traversal does not: it rebuilds a step's stage states after visiting the
step above, so at the step's first stage the boundary node holds a later stage's value. With the lag
closed the stage is a function of `(y, t)`; with it open, each record needs one scalar per species
and the rebuild has to seed it.
*The trap.* Two lists of times exist and only one is the replay grid. `r_ode_times()` is it.
`patch.step_history` is the mutant environment cache's index — `cache_ode_step` pushes a time
alongside each cached `environment_history` entry, and only when `save_RK45_cache` is set
(`patch.h:727-733`), which nothing on the resident path sets. So in production it holds its
initialiser, `{0.0}`, and `SCM::run_mutant` pins the replay grid to it (`scm.h:309`) — the gradient
wrong by 60×.

---

### Phase 2 — the four changes that move forward numbers

They land together so there is one re-blessing rather than four, and P0.6's ecology decisions
belong in the same conversation with the owner (§10). The four are the light interpolant's
coordinate (P2.1), the transport stencil (P2.4), the collar operating point's polish (P2.6), and
the boundary node's lag (P2.7).

---

**P2.1 — the light interpolant on a normalised coordinate.** Report 03 §1b.

```cpp
template <typename S = double>
class ResourceSpline {
  std::vector<double> knot_fractions_;              // u_k, uniform, fixed for the run
  interpolator::Interpolator     fitted_;           // the forward fit; no longer places knots
  interpolator::hermite_interpolator<S> field_;     // evaluates, carries S
  double height_max_, inv_height_max_;              // the reciprocal is the hot-path form
  S get_value_at_height(double z) const;            // field_(z * inv_height_max_)
  void get_value_and_slope_at_height(double z, S& v, S& dvdz) const;
  template <typename Q> S get_value_at_height(Q z) const;   // a crown abscissa: z = h * xi
};
```

The fractions are **uniform at 65**, which M3 settles: the shift against develop is resolution rather
than placement, so a refinement-derived set buys nothing and the count is the only knob (§2.6). The
fitted cubic still exists on the forward path; it no longer chooses the positions.

**Fixed fractions make the knot positions run-constant, and that is what the interpolant should be
built around.** `hermite_interpolator::init` takes positions, values and slopes together and then
`rebuild()`s everything: it validates that the positions ascend, scans them for uniformity, and fills
65 spans of coefficients. Called once per stage — 36 000 times a run — it re-derives structure that
cannot change after P2.1. So the type splits along the line report 03 §7 rule 5 already draws:

```cpp
void set_nodes(const std::vector<double>& x);              // once per run: validate, scan, index
void set_data(const std::vector<S>& y, const std::vector<S>& dydx);   // per stage: 65 spans
```

**A height query is passive; a crown abscissa is not.** The field is read at a fixed height (the crown
centre, a competition knot) and at `z = height · ξ_j` inside the crown integral, and the second carries
the whole height channel — M1 measures it as exactly zero if the query freezes. So the interpolant
needs both readings and `ResourceSpline` passes them through, on the naming `Interpolator` already
uses. The knot positions stay `double` either way; it is the *query* that is sometimes active, and
conflating the two is what makes this look decided when it is not.

Positions are structure and are `double` by type; values and slopes are data and carry `S`. A plant
System then holds one interpolant for the whole run and refreshes two vectors per stage, which is
also why P2.3 has no build cost to trade against: the per-stage work is the two reductions that fill
those vectors, and report 03 §5.5's unattributed 175 µs belongs to `rescale_spline`'s adaptive
machinery and band solve, both of which are gone.

*Why it precedes Phase 3* — §2.6: `rescale_spline` carries the previous build's knot set, so the
field is not a pure function of the state across an introduction, and a reverse traversal crosses
those backwards.

*Order, and the two steps are different in kind.* (1) Add `knot_fractions_` and rebuild through it,
keeping the fitted cubic as the evaluator **and taking the fractions from that interval's own adaptive
fit** — `x_k = u_k · height_max` is then exact arithmetic and this step is bit-identical. (2) Switch
the fractions to uniform-65. This one is **not** bit-identical and is not meant to be: M3 measures the
crown-mean light shift at up to 1.7e-03, so this is the deliberate re-blessing, and it is the step
that removes the carried knot set. Doing (1) and (2) as one change loses the ability to tell a
transcription error from the shift that was expected. (3) Delete `rescale_spline`. (4) Only then bring
in the Hermite (P2.3).
*Touches* every `get_environment_at_height` caller, plus the `cap` argument and the
`max(0.0, spline(height))` undershoot guard, both expressed in absolute height today.
*Closes on* step (1) bit-identical, and step (2)'s shift inside M3's band with baselines re-blessed.

---

**P2.2 — the slope reduction.**

```cpp
// one pass, so pow(z/H, eta) is evaluated once and the two sums associate identically
std::pair<S,S> Patch<T,E>::compute_competition_and_slope(double z) const;
```

The reduction returns the pair and the interpolant query writes through references
(`get_value_and_slope_at_height`, P2.1) — one shape per level, chosen because the reduction is
called once per knot per stage and the query once per quadrature point per cohort.

Merge sources in the **same descending-height order with the same flat-index tie-break** as the
value reduction. A value and a slope from sums that associate differently disagree in their last
bits, which is the pattern report 03 exists to remove reappearing in floating-point association.
Guard `q(0, h)` per P0.7 — it is `0/0` for every `h`, and the field's lowest query is `z = 0`.

*Closes on* agreement with a tight central difference of `compute_competition` across `eta` in
{1,2,4,8,10,12} and one general non-integer `eta`; and the two sums adding the same terms in the
same order, checked rather than asserted.

---

**P2.3 — the Hermite in `ResourceSpline`.** Swap the evaluator, feeding `init(x, y, dydx)` from
P2.2.

*Closes on* O(h⁴) on value and O(h³) on slope **on a smooth test field**, which is where report 03
§5.3 measured 16.0 and 8.0 — its knots sit at the cohort tops *and* subdivide those spans, so every
span is smooth. The production fraction set is uniform (P2.1) and does not align with the cohort
heights, where `Q(z/h)` breaks the field's derivative, so the observed rate there is about `h^2.5`
(M3). That is a rate and not a penalty: at production counts the uniform set is *more* accurate than
cohort tops (M3b, §2.6). So the gate is the scheme's rate on a smooth target, with the production rate
recorded beside it.
*Note* the R-facing state changes shape — the fitted cubic reports (x, y), a Hermite carries
(x, y, m). That is a `NEWS.md` entry.

---

**P2.4 — the transport stencil across cohorts.** Report 04 §2 and §7.

```cpp
// species.h -- g comes from the neighbours' already-computed rates
double Species<T,E>::growth_rate_gradient(std::size_t i) const;   // no one-sided case: see below
```

`node_gradient_eps`, `node_gradient_direction` and `node_gradient_richardson` go from `Control`,
and with them the coupling to `GSS_tol_abs` that nothing else records.

*Order*, from report 04 §7.3, and step 2 is the one that makes M4 attributable.
(1) Add `Species::growth_rate_gradient(i)` beside the existing `Node` one and log both on one
production run — M4's value half, no restructure yet.
(2) Split `Species::compute_rates` into two passes, with pass two still calling `Node`'s sub-grid
stencil. **Bit-identical**, because pass two computes the same quantity from the same inputs — which
isolates "did I break the loop" from "did the value move". The boundary node must be in pass one,
because the lowest cohort differences against it.
(3) Switch pass two to the cohort-grid stencil. This is where the value moves.
(4) Delete `Node::growth_rate_gradient`, `r_growth_rate_gradient`, the `thread_local` scratch,
`Individual::growth_rate_given_height` and the four `node_gradient_*` `Control` fields.

*Requires P0.1 first.* The restructure is value-neutral only after it: pass one is today's loop minus
one line, and today that loop interleaves the probe's leaf solves between the cohorts' own, so
removing them changes what the shared `Leaf` holds unless it is order-independent (report 04 §7.3).

*It is an R-interface change, so `plant/agents.md` §3.3 applies* — a machine-actionable `NEWS.md`
mapping and a **loud** flag, because the meaning changes rather than the name.
`Node::growth_rate_gradient` is in `RcppR6_classes.yml:556` for all four model pairs.
`node$growth_rate_gradient(env)` becomes `species$growth_rate_gradient(i)`; the four
`node_gradient_*` `Control` fields have no replacement.

*Two tests are pinned to the old stencil and must be rewritten, not relaxed.* `test-node.R:21-68`
asserts the node's value equals an R-side backward difference at `node_gradient_eps` **exactly** —
that test *is* the sub-grid stencil's definition. `test-node.R:126` asserts the `ode_rates`
composition through the same call. Report 04 §7.4 lists the four properties that replace them, of
which the identity `log_density_dt + mortality_rate == -d(log dh)/dt` is the one that would catch a
staggering error.

*Closes on* `log_density_dt` matching M4's measured change, with offspring and the three census
metrics re-blessed at a pinned build, the shift recorded, and report 04 §2.2's conservation
diagnostic presented alongside it — a sub-grid probe leaks individuals at `O(dh g'')` and the cohort
grid does not, which is the forward-model argument for the change.
*The ends.* Guarded on the divisor rather than on the cause: `dh == 0` is reached three ways — a
cohort introduced this instant is still a copy of `new_node`, a cohort whose growth has been gated
to zero has never left `height_0`, and two cohorts can coincide — and all three take the compression
of the cohort above.

---

**P2.6 — polish the collar operating point.** Report 02 §6.5. Newton on `R = dΠ/dp` from golden
section's answer, with golden section loosened to land in the Newton basin rather than at
`GSS_tol_abs`.

```cpp
// leaf_model.cpp -- after find_root_collar_psi's search, before the outputs are read
void Leaf::polish_root_collar_psi();      // Newton on dprofit_droot_collar_psi, derivative dR_dcollar
```

*Why it is here and not in Phase 3.* The envelope row that makes carbon free is valid only at a
stationary point, and golden section at production tolerance leaves `|R|` at 8.8e-05 to 1.2e-03
against 1.6e-08 to 4.7e-07 after Newton. The displacement moves `profit_` at second order and
`soil_consumption_` at **first** order, so this is a forward-model change and belongs with the
other two.

*Order.* (1) Polish at the current bracket tolerance and measure the shift in `soil_consumption_`
and in offspring. (2) Loosen the bracket and confirm the polished point is unchanged to the Newton
residual. (3) Re-bless.
*Closes on* `|R|` at the returned point below 1e-07 at every sampled state, the polished operating
point independent of the bracket tolerance, and the forward benchmark no worse — reaching
`GSS_tol_abs = 1e-3` costs seventeen profit evaluations at the measured production bracket and
reaching `1e-1` costs eight, so the two Newton steps are paid for out of the loosening.
*The trap.* `dprofit_droot_collar_psi` leaves the operating-point outputs at its own probe point,
so a polish loop must restore them; develop already does this on the TF24f path
(`tf24f_strategy.cpp:66`). And it reads `psi_soil_inverted_`, which only `prepare_collar_solve`
refreshes — P0.1's second half.

---

**P2.7 — close the boundary node's lag.** §11.2's decision. One extra evaluation of the boundary
node per species per stage, after the field is built, so the density the field's lower interval
carries belongs to the current field rather than to the previous stage's.

```cpp
// patch.h -- inside compute_rates, after compute_environment and the species loop
// One Picard step: the boundary density is a contraction of modulus ~1e-3 in the
// field it helps build, so a second evaluation closes it to ~1e-6 relative.
```

*Why it is a forward change.* Keeping the lag forces a scalar per species to be
carried backwards across stage boundaries — and, at a step's first stage, across the step boundary
through `step_adjoint`, which is odelia's and knows nothing about species. Closing it makes the
stage a function of `(y, t)` alone, which is what lets P1.4 store one state per accepted step and
lets P3.5 rebuild stage states by re-running the step. It moves the field at the boundary node's own
magnitude — at most 3.5e-04 in light, at `ResourceSpline`'s fitting tolerance — so it is a forward
change, and a small one.

*Order.* (1) Add the second evaluation and measure the shift in offspring and in the three census
metrics. (2) Confirm a third evaluation moves nothing at 1e-6 relative, which is the contraction
claim as a check rather than an argument.
*Closes on* the shift recorded and re-blessed with the rest of Phase 2, and on the third-evaluation
check. The forward benchmark should not move measurably: it is one boundary node against 141
cohorts.
*What it does not buy* is accuracy — the lagged and converged values differ by less than the
fitting tolerance (§11.2). It buys the reverse pass a stage that depends on nothing but the state.

---

**P2.5 — account for `rescale_spline`'s cost before it goes.** 17.6 µs of 193.2 is accounted for,
and 175 µs per build over 20 160 builds is 3.5 s. The run it was 3.5 s *of* is not develop's 89.9 s
at `-O2`, so the share needs re-taking against the gate number before it means anything. Worth
knowing whether P2.1 recovers the time or whether it was somewhere else.

*Closes on* the forward benchmark after P2.1, with the difference attributed.

---

### Phase 3 — the reverse pass

Ordered so that each task closes on one of §2.5's checks and a failure has one cause.

---

**P3.1 — the closed-form steps.** Steps (a), (c), (d), with step (b) a stub returning zeros.

```cpp
template <class ItIn, class ItOut>
void Patch<T,E>::ode_rates_adjoint(ItIn lambda_dydt, ItOut lambda_y) {
  soil_adjoint(...);            // (a) bidiagonal drainage cascade, no linear solve
  // (b) stub
  light_knot_adjoint(...);      // (c) knot values -> (area_leaf, density, height),
                                //     the reduction's lower limit, and height_max
  allometry_adjoint(...);       // (d)
}
```

**Step (c) carries four things, and three of them are not the cohort sum.** The knot values and the
knot slopes reach every cohort's leaf area, density and height through their two summed reductions.
Beyond that: the two data vectors are linked by `m_k = -y_k s_k` (§2.3), so `lambda_m` must reach
`lambda_y` and the slope sum before either is distributed. the
reduction's lower limit is the boundary node at `height_0`, so it contributes one evaluation of the
integrand there times `d(height_0)/d(trait)`, which `implicit_value` supplies through `height_seed`
(P1.1). And under P2.1 the knot fractions are held on `u = z / height_max`, so every query carries
`1/height_max` and `-z/height_max^2`, and that adjoint lands on the tallest cohort's height —
`Species::height_max()` is `nodes.front().height()` and relies on the descending order, so within a
species there is no selector; the `max`, and the tie, exist only across species in
`Patch::height_max` (`patch.h:424`).

*Order.* The soil adjoint first, because it is checkable on its own: **V1** with the blocks
stubbed compares the closed-form part against the matching part of a whole-`Patch` recording at one
state. Then the cohort sum, then the lower limit and `height_max`, each against the same **V1** at
one state — they are three separable contributions to one accumulator, so adding them one at a time
keeps a disagreement attributable.
*Watch* step (c) visiting sources in the same order as the forward sum, for P2.2's reason.
*The failure to watch for* is either extra term being silently absent: both are single closed-form
contributions to an accumulator that is nonzero without them, so dropping one gives a plausible
gradient. **V1** catches them only because it compares against a recording that contains them.

---

**P3.2 — the cohort block and the leaf's boundary.** The largest reverse-pass task.

```cpp
// the block: a pure function of its declared inputs
template <class S>
std::vector<S> tf24_cohort_block(const std::vector<S>& inputs,
                                 const TF24_Pars<S>& pars, const Control& control);

// The leaf contracts its own two output adjoints onto its inputs, at the point the
// solve left. Doubles throughout: nothing inside the leaf is recorded.
void Leaf::input_adjoints(double lambda_profit,
                          const std::vector<double>& lambda_uptake,
                          std::vector<double>& input_adjoints) const;
```

The leaf is a vector-Jacobian product, like the block that contains it: two output adjoints in, one
contribution per input out, in `Leaf::inputs()`' order, written into a buffer the cohort loop owns
and reuses. What it sums over is the partial derivative of each output — `profit_`, and each rooted
layer's uptake — with respect to each input, and those are per-solve members of `Leaf`, formed where
`profit_` and `soil_consumption_` themselves are formed. Returning them instead would carry a second
copy of two outputs the forward pass reads off the leaf directly, and allocate four vectors per
(stage, cohort), 3.9 M times.

`Leaf::inputs()` is the one statement of the input order, and both the pack in the cohort block and
the scatter here read it. The assertion is `input_adjoints.size() == inputs().size()` — T4's shape
one level down.

Report 02 §6 derives each of them: §6.1 profit's, which needs no argmax term; §6.2 uptake's direct
dependence on its own layer's potential and on root mass; §6.3 the two coefficients `dR_dflux` and
`dR_dflux_slope` (`a` and `b`) that carry the rest of uptake's dependence through the operating
point; §6.6 uptake's and the stem's response to a uniform drying; §6.7 the pinned case. Two of the
members are the polish's as well — it needs `dR_dcollar` and needs to know whether the point is
pinned — so both are the leaf's own state whether or not a gradient is being taken.

**`dR_dcollar` is a central difference of `dprofit_droot_collar_psi`,** the construction
`scripts/curvature_probe.R` and report 00 §7 measure it with. The closed form needs the second
derivatives that rule out deriving `dR_dflux` (report 02 §6.3). A difference is sound here and
nowhere else on this path: it is all `double`; it enters as a divisor scaling one adjoint rather than
as a channel carrying one, so its relative error passes through instead of compounding; and its
magnitude is measured over the whole feasible domain, 0.17 to 198 by layer count and never near
zero. Its own error is checked by halving the step and requiring less movement than §6.9's
stationarity tolerance.

**Where each partial comes from.** Carbon is an envelope row — `profit_` sits at
its own maximiser, so its sensitivity is direct with the operating point held still, and
nothing about the argmax enters. Water is not stationary, so it carries the operating point's
movement: five flux adjoints collapse onto one scalar per cohort, one divide by `dR_dcollar` gives
the operating point's adjoint, and the gradient that closes it **factors**. `R` reads the soil
potentials, the per-layer root masses and the leaf area only through the soil-to-collar flux
and its collar derivative, so those `2n + 1` directions cost **two scalars**: `dR_dflux_slope` is
closed form in intermediates `R` already computes, and `dR_dflux` is **recovered from one extra
pair of residual evaluations on this pass** in a single potential direction, which identifies
it because that family is rank one. Everything else — radiation, conductance, the leaf's own
twelve parameters — is a parameter derivative of two functions develop already templates and
of two interpolants whose knots are fixed at construction.

**Two rows are computed from a broken symmetry rather than by subtraction.** Uptake responds
to a uniform drying of the whole column only through the cumulative root-vulnerability
integral over a sliding interval, and the stem's response through the transport interpolants'
curvature. Both have closed forms (report 02 §6.6). A whole-solve finite difference cannot
resolve either, so they are computed, not differenced.

**Requires the polish first** (report 02 §6.5): the envelope row is valid only where
`dPi/dp = 0`, and golden section at production tolerance leaves `|R|` at 8.8e-05 to 1.2e-03.
Newton on `R` takes it to 1.6e-08 to 4.7e-07, using `dR_dcollar`, which the leaf holds
either way. Golden section then runs only to the Newton basin. It moves `soil_consumption_` at
first order, so it lands with Phase 2's re-blessing rather than here.

*Requires P0.1 and P0.10.* The first line of the signature calls the block a pure function of its
declared inputs, and P0.10 is what makes that a checked fact rather than a read-derived one.

*Order.* (1) The block with the leaf held constant, so **V2** exercises the allometry, storage and
demographic chain alone. (2) The envelope row and the explicit flux rows. (3) `dR_dflux_slope` from
its closed form, then `dR_dflux` recovered — verified by recovering it from several potential
directions and requiring them to agree, which they do to 1e-05 or better. (4) The two
translation-defect rows. (5) The bound-pinned case and the selector.
*Closes on* **V1** complete, and **V2** at stage 0 for both operating-point cases — the pinned one
needs `psi_soil ≥ 1.5 MPa` at `height ≥ 2 m` (§8). The selector's incidence goes in P0.5's
inventory. Plus three tests where the block meets its inputs, which is where a silent wrong gradient
would come from:

| | test | what it catches |
|---|---|---|
| **T4** | `in.size() == state_size() + n_cohort_reads() + ad_parameters().size()`, and a pack/unpack round trip reproducing the states, the environment reads and the parameters bit-for-bit — **and the dependent aux slots**, which are derived rather than packed (§2.3) | the pack and the adjoint scatter drifting apart on an offset; an unpack that bypasses `set_state` and leaves `area_leaf` stale |
| **T5** | **knot-adjoint accumulation.** One knot value read by `k` cohorts: `lambda_knot` must equal the sum of the `k` contributions, asserted as a value | the same silent failure as the trait case — a fixed fraction of the answer with the correct sign |
| **T6** | trait-adjoint accumulation across cohorts, asserted as a value | measured signature **41–51%** of the truth, correct sign, nothing thrown (report 01 §6.2) |

T5 has no measured signature yet, and T6 does. That asymmetry is the argument for writing T5 as a
value assertion rather than a finiteness check: the failure it guards against is the one the corpus
has already been bitten by once, in the channel next door.
*Three invariants gate it, and none is a finite difference* (report 02 §6.9). A re-run finite
difference of the leaf solve resolves the collar's response to about four digits while the residue
under test is four to nine percent of it, so a disagreement there reports the reference rather than
the scheme. Instead: **stationarity**, `∂R/∂u + Π_pp · dp*/du = 0` for every input, which the
boundary can check against itself at any state; **continuity**, `E_up` from the soil side against
`κ(S(ψ_stem) − S(p))` from the stem side, two different interpolant chains that must agree and the
only check on the interpolant derivatives; and **the waist residual** over all `2n + 1` directions
under one shared pair, which is how a bad recovery of `dR_dflux` announces itself.

*Both bounds are root-finds*, and their derivatives are wanted only where the operating point is
the bound: `root_psi_crit` is closed form in `root_b` and `root_c`, `root_crit` carries its own
implicit-function term, and report 02 §4 measures the incidence as zero at the production driver
and a third of solves at a twentyfold rainfall reduction.

---

**P3.3 — the leaf's own parameter rows.** The twelve parameters that reach the model only
through `Leaf`'s constructor and `set_physiology`: parameter derivatives of `assim_colimited_ad`
and `hydraulic_cost_ad`, both already templated on their scalar in develop, and of the
transpiration and root-vulnerability interpolants, whose control points are fixed at construction
so the parameter is carried by the values (report 03's arrangement, second consumer).

*Why it is separate from P3.2.* P3.2's rows are the same for every model with an inner optimum;
these are TF24's leaf physiology and nothing else shares them. Splitting them means a failure here
cannot be confused with a failure in the waist.

*Closes on* a seeded leaf-only trait end to end. `vcmax_25` is the discriminating one: uptake has
**no** direct dependence on it, so the whole of `d(uptake)/d(vcmax_25)` arrives through the
operating point's movement, and a broken argmax channel returns exactly zero rather than a wrong
number. Also `d(consumption)/dψ`, against the **47.6–53.2%** error that holding the operating point
fixed gives today — an error fully explained by the search's own displacement, so a fix that does
not remove it has not addressed the cause.

---

**P3.4 — remove the last `xad::` from plant.** `xad::fwd<double>` and `xad::derivative` in
`src/leaf_model.cpp` become one odelia helper. Forward mode stays; only the spelling moves.

*Closes on* `grep -r 'xad::' plant/inst plant/src` returning nothing.

---

**P3.5 — the stencil's adjoint, and drive from the stepper.** `lambda_g` is formed in step (a),
before any block is swept, because a block cannot be swept until every output adjoint exists
(§2.4). Under report 04 §7's staggering each cohort pairs with the interval **below** it, so
`g_i` appears in `growth_rate_gradient(i)` and in `growth_rate_gradient(i-1)`: **two**
contributions per cohort, not the three a centred difference would give. Then `Step::step_adjoint`
drives `Patch::ode_rates_adjoint`.

**`Patch::set_ode_state` needs its first four lines callable on their own, and this task exposes
them.** It is `{ load states; set time; check finite; compute_environment; compute_rates }` in that
order (`patch.h:680-702`), and `ode_rates` only reads the stored rates out (`patch.h:802-804`). So
`ode_rates_adjoint` mirrors `ode_rates`' *signature*, not its work, and its precondition is the state
and the field at the stage being differentiated, plus that stage's aux — not a rate evaluation, which
the recordings are. Exposing the first four changes no forward behaviour; the forward path calls the
same lines in the same order. A separate, larger option is to move the rate computation into
`ode_rates` so plant matches every other System, which needs two odelia signatures to take the System
by mutable reference first (`aornugent/plant#65`) — and would make P0.9 unreachable rather than
fixed.

**The rebuild keeps each stage's aux** — six vectors held by `Step` beside `k1`–`k6`, about 10 kB —
and the sweep hands it back with `set_ode_aux` so the leaf reads its operating point and the soil its
per-layer uptake instead of recomputing either (§2.8). `Step` already owns `k1`–`k6` and `ytmp`, so the rebuild allocates nothing. It evaluates **six**
stages, not five: first-same-as-last saves an evaluation on the *forward* pass because `k1` is the
previous step's `dydt_out`, and a reverse traversal has not rebuilt that step yet — it visits the step
above first. So `k1` is re-derived as `f(y, t)` at the step's own start state, which is what P0.9's fix
makes correct at an introduction, where develop's seeded `k1` is the pre-introduction rate vector.

*Closes on* **V3** — one step's `lambda_y` against a finite difference of one step. A lost tableau
term is silent and has no measured signature (report 01 §12), which is the argument for checking
one step rather than the whole run: a whole-run disagreement would not localise it, and there is no
magnitude to recognise it by.

---

**P3.6 — the census metrics and the entry point.**

```cpp
// A weighted reduction over the size distribution, from the boundary node up (P0.8).
template <class Psi> value_type Species<T,E>::census(Psi psi) const;

// The metrics travel as a tuple, so the codomain is sizeof...(Psi) and a fourth metric
// is one word.
using tf24_census = std::tuple<leaf_area, mass_above_ground, area_stem>;
```

`census` takes the weight and nothing else. A metric that reads its own height cut carries it, being
a functor over one cohort's state.

R side: `stand_gradient(scm, metrics, traits)`, doubles in and out, recording the `Control` it
differentiated at. Plus `plant/agents.md` §13.

*Closes on* **V4** — TF24 census and R0 at `max_patch_lifetime = 105.32`, resident, against a
re-run finite difference on the identical resolved schedule, under 2 GB peak — and on the count: a
developer reads §13 and adds a fourth metric without touching tape code.
*The failure to watch for* is trait adjoints not accumulating across cohorts. Treating each cohort
as a separate input gives **41–51%** of the answer with the correct sign and nothing thrown, so the
test asserts the value, not finiteness.

---

### Phase 4 — after the prize

Separate pushes, sequenced by what each needs.

| | what it is | needs first |
|---|---|---|
| **invasion gradients** | omit step (c) (§2.7). `run_mutant` and the replay records it reads are dead on develop and reach a renamed odelia interface, so the first task is to re-diagnose that path rather than resume it (§3) | Phase 3 |
| **FF16 and K93** | the templating plus the existing census reduction; retire `ff16_production_kernel.h`; port the `smooth_positive` clamp fix and K93's `k_I` channel; tighten FF16's gradient test, which passes at 1e-2 where the truth is ~1e-6 | Phase 3 |
| **two species** | two `Leaf` objects, `Species::consumption_rate`'s `size() < 2` per species, and per-species η grouped inside the light reduction. Every incidence number in reports 00 and 07 is single-species | FF16 |
| **calibration** | `least_squares` reads intermediate trajectory states as active values, which a `double` trajectory breaks without a message. Either the functional declares which steps it reads and contributes a per-step adjoint seed, or calibration stores a second denser trajectory. Record the decision before opening it | Phase 3 |
| **node-schedule refinement** | point it at the coupling field. Recording the soil and adding 1.5× cohorts moves R0 ~0%; letting them feed back moves it 69–84% | invasion, for the comparison |
| **TF24f** | the tracked collar state reparameterised onto its feasible interval, so the clamp and its two roles go away. Its `∂Π/∂p` is a rate rather than an optimum's condition, so it pays none of P3.2's argmax machinery — report 00 §7 lists its collar derivative as free | Phase 3, and the owner on `plant#61` |

---

## 7. What we are deliberately not building

- No third template parameter, no new System type, no second `Patch`.
- No whole-run recording (§2.5), and therefore no `Solver` members on `SCM`.
- No second implementation of anything: no separate leaf assembly, no shadow active fields, no
  second parameter struct.
- No capability flags or SFINAE detection structs. A concept and `if constexpr` where a
  compile-time choice is needed.
- No `decide()` type. The switch inventory is a document.
- No check that forward and reverse agree, in place of a finite difference. Exact identities are
  a different thing and are used deliberately: report 02 §6.9's three invariants hold by
  construction rather than by agreement, and they cover the rows where a finite difference is the
  worse reference (P3.2).
- No component-level tape size work: 0.018% of TF24's total against a required factor of
  10²–10³.
- No mass chart.
- No analytic `dg/dh` substituted for the stencil (§2.6) — it removes the upwinding.
- RODAS and the stochastic solver are out of scope; both must keep compiling and passing.
- No disturbance gradients, and no second derivative *of the deliverable* — no Hessian of a
  census metric with respect to traits. `dR_dcollar` is a second derivative of profit in one
  scalar direction and is a member of the leaf (P3.2); so are the interpolant slopes the
  uniform-direction rows read. Those are inside the first-order machinery, not an
  extension of it.
- No smoothing without a measured incidence and a scale sized against data. develop has both
  the precedent (`P_pos`) and the method (`storage_prod_eps`).

---

## 8. The collar's curvature, and the two cases of the operating point

`Π_pp` here is the boundary's `dR_dcollar` (P3.2). `scripts/curvature_probe.R`, against a develop build: a central difference of develop's analytic
`dprofit_droot_collar_psi` about the solved operating point, at `GSS_tol_abs = 1e-10` so the
number is the geometry, each point at three step sizes. Swept over the whole feasible domain of
the maximisation — `psi_soil` from the default driver's 0.015–0.17 MPa down to the stem's
`psi_crit = 7.085`, four heights, five uneven profiles of the kind a drydown produces.

**`Π_pp` is negative at 52 of 52 states**, `|Π_pp|` from **0.1723 to 15.61** (median 4.2), **at five
soil layers**. It scales with the layer count — at twenty layers the same three heights give −14.4,
−71.9 and −198.3 — because more layers mean more conductance and a sharper optimum, so a value
quoted without its layer count says nothing. What does not change is the sign, and that is what the
divide needs: the divide in report 00 §6.2 fails when `Π_pp → 0`, nothing in the domain comes near
it, and the largest amplification of a flux adjoint is **5.8×**. So the interior case is one divide
with no fallback.

| case | count | treatment |
|---|---|---|
| stationary interior maximum (`\|∂Π/∂p\|` at the solver's floor) | **37 / 52** | report 00 §6.2 as written |
| pinned at a bound (`\|∂Π/∂p\|` = 0.054 … 2.12 at tolerance `1e-10`) | **15 / 52** | `p*` is the bound, so its derivative is the bound's derivative |

Every pinned state is at `psi_soil ≥ 1.5 MPa` **and** `height ≥ 2 m`. None is inside the
default driver's `psi_soil` range, which is why report 00's production census finds no pinned
states; the committed rainfall sequences reach 1.5+ MPa. Selection is a comparison on
`|∂Π/∂p|` available where the search returns, and it is a discrete branch on the gradient path,
so P0.5's inventory carries it.

**What the returned point's residual actually is.** At five layers over six production states,
`|R|` at `GSS_tol_abs = 1e-3` is **8.8e-05 to 1.2e-03**, and the displacement from the polished
point is 5e-05 to 2.8e-04 — so `R`/displacement reproduces the directly differenced `Π_pp` to three
or four digits, as the mean value theorem requires. Report 00 §9's `∂Π/∂p` of 11–23 does not
reproduce at these states; it belongs to another configuration and nothing rests on it.
`golden_section_max` returns a point affine in its bracket within one comparison pattern and jumps
when the pattern changes, so the displacement is bracket-scale rather than tolerance-scale
(report 04 §5) — a property of the search, not the objective, so it does not touch report 00
§6.2's derivation. P2.6 removes the residual rather than reasoning around it.

---

## 8b. What the gradient costs

`scripts/gradient_budget.R` and `scripts/leaf_call_cost.R`, on develop `141dc8df` against odelia
`854a8e18`, built `-O2 -DNDEBUG` through `pkgbuild::compile_dll(debug = FALSE)`.
`scm_base_parameters("TF24","TF24_Env")` with `add_strategies(trait_matrix(0.1978791,"lma"))`,
`Control()`, `refine_schedule = FALSE`, `max_patch_lifetime = 105.32`, five soil layers, one
species.

**The forward run, and the two numbers that are not the machine's.** Offspring
`42.14017357509567` and 5 055 accepted steps — the same offspring value report 01 §2 recorded, to
the last digit, on a different box. The wall clock is **102.9 s**, best of two, 0.8% apart, against
89.9 s there. So the value and the step count are properties of the tree and the flags, and the
seconds are not: **every timing gate in this plan is a ratio measured in one session on one
machine**, which is what `profile-plant` says and what the two boxes demonstrate.

**`pkgbuild::compile_dll()`'s default is `-O0`,** which appends `-UNDEBUG -g -O0` after any user
`CXXFLAGS`, so the last `-O` wins and a Makevars asking for `-O2` is silently overridden. Pass
`debug = FALSE`. A timing taken the other way measures the debug build.

**The leaf, per call, net of the R boundary.** An R method call through RcppR6 costs **5.77 µs**
here — measured on a bare field read — which is larger than some of the quantities being timed, so
it is subtracted:

| | measured | net of the call |
|---|---|---|
| `find_root_collar_psi` — prepare + golden section to `1e-3` | 15.97 µs | **10.2 µs** |
| the same at `1e-1` | 11.35 µs | 5.6 µs |
| `evaluate_root_collar_psi` — prepare + one profit evaluation | 6.74 µs | 1.0 µs |
| `dprofit_droot_collar_psi` | — | **3.5 µs** |

**The leaf solve is most of the forward run, and half of the solves are the stencil's probe.**
7.8 M solves (report 01 §2's structural ratio on develop's counts) at 10.2 µs is **80 s**, so against
the 102.9 s run measured beside it the leaf is about **78%** and P2.4 removes about **39%** of forward
time by deleting the probe. **That share is anchored to one wall clock and the wall clock moves**: the
same tree later ran 86.1 s (M5), against which the same 80 s would be 93% — which is too high to
believe and says the per-call cost, the solve count or the clock belong to different sessions. So the
share is the one number here to re-take with its own timing in a single session; the *ratio* P2.4
turns on — one of the two solves per cohort per stage — is structural and does not depend on it.
Measured from the other side, a marginal Richardson probe costs 15.0% of a life-20 run — a lower
bound, because the extra probes reuse caches the first one fills. The test suite's own profiling
note says 50.1% (report 04 §3). The three agree in order and the arithmetic sits between the two
measurements.

**The polish pays for itself.** Loosening the bracket from `1e-3` to `1e-1` saves 4.6 µs; two Newton
steps, each taking `R` and `dR_dcollar` by one difference, cost about four `dprofit` calls, 14 µs.
So P2.6 is not free at these tolerances — it is roughly +9 µs on a 10 µs solve unless the loosening
goes further than `1e-1` or `dR_dcollar` is reused across the two steps, which it can be for one of
them. Budget it as **up to +10% on the forward run**, and take the measurement at P2.6 step (1).

**The reverse pass, per gradient evaluation.** Three terms, against a post-P2.4 forward pass of
about 63 s:

| term | count | unit | total |
|---|---|---|---|
| rebuild the stage states in `double` | one forward RHS per stage | — | ~63 s |
| the leaf's partial derivatives, at the operating point the rebuild kept (§2.9) | 3.9 M (stage, cohort) | 4–6 `dprofit`, 14–21 µs | 55–82 s |
| record and sweep the block | 3.9 M | 3–5× the block's own 6 µs of non-leaf arithmetic | 70–117 s |
| | | | **190–260 s** |

So **a gradient is 2 to 3 forward runs**, for all 51 traits and all three census metrics at once.
The comparison that matters: a central-difference gradient of 51 traits is 102 forward runs, so this
is a **30 to 50×** saving, and V4's finite-difference verification is the expensive half of the
acceptance test rather than the cheap one.

**Re-solving the leaf instead of keeping its operating point adds 36 s** — 9.2 µs per (stage,
cohort), the golden section's own cost (§2.9).

**The one soft number is the record-and-sweep multiplier.** 3–5× is XAD-typical and is not measured
here; it is the term that could double the total. It is measurable before any of plant is written —
T1's harness in P1.1 times a block-shaped System against its own double evaluation — so P1.1 closes
on it and the budget is re-taken then. Everything else in the table is measured or is arithmetic on
measured quantities.

**What the peak is.** 46 MB of trajectory plus one block's recording, flat in run length, stage
count and trait count (report 01 §7.2). The 2 GB gate in V4 has three orders of headroom; it exists
to catch a recording that is not being released, not to be approached.

**Why the block and not the whole step.** Report 01 §2's 490 GB is `1 128 states × 5 055 steps ×
86 kB`, so one *step's* recording is about **97 MB** — inside the same gate. Recording a whole step
would delete the hand-written parts of §2.4: the tape would transpose the tableau, the two field
reductions, the soil cascade and every accumulation, leaving the leaf as the only supplied adjoint.
It is slower — report 01 §7.4 measured a step-local sweep at **4.2×** the forward run against the
block-granular variant's 1.4–1.6×, though against different baselines — and it is the fallback if the
hand-written steps prove hard to keep correct. Nothing in this plan forecloses it: the trajectory, the
aux transfer and `step_adjoint` are the same either way.

---

## 9. Risks, each with the number that would expose it

| risk | how it shows | when we would know |
|---|---|---|
| the block boundary does not close around a moving integration bound | the height adjoint disagrees with a finite difference | **M1 — closed.** It matches to 1e-11, and the one failure mode it found is not a disagreement but a severance: a frozen query position gives exactly zero (§2.8). So the guard is that the crown integral reads the field through the active-position overload, and a test that seeds height alone catches it |
| the forward model slows under templating | benchmark outside the accepted band, or reference numbers move | **M2 — closed for one file**: bit-identical and 0.677x the forward cost at production eta. Then P1.2, gated on the templated build against a develop build **in the same session on the same machine** (§8b). The AD branch's comparison was 49.57 s against 50.31 s — a +1.5% templating cost, and it is the ratio that transfers |
| the normalised coordinate is not bit-identical to `rescale_spline` | a forward shift where none was expected | **M3's remaining half**, at P2.1. Its accuracy half is closed: uniform-65 shifts crown-mean light by at most 1.7e-03 against develop, which is the number to re-bless |
| differencing across cohorts changes the forward value more than expected | `log_density_dt` and offspring move | **M4** |
| removing the scratch slows the forward pass | benchmark | **M5 — closed.** At most 1.5%, inside the same-arm spread |
| a channel exists that templating cannot reach | a derivative obtainable only through a second implementation | P3.1's V1 |
| the decomposition is wrong | V1 fails at one state, with nothing else in the way | P3.1 |
| the stage recursion loses a term | V3 fails on one step. **No measured signature** — report 01 §12 records that C5's 19% belongs to the newborn-adjoint mechanism, not to a lost tableau term, so the only thing known is that it is silent | P3.5 |
| trait adjoints do not accumulate across cohorts | a fixed fraction of the finite difference with the correct sign, nothing thrown. Treating each cohort as a separate input gives 41–51% | P3.6 |
| trait adjoints do not accumulate across *steps* | the same signature, unmeasured. `k_I` and `eta` are read both inside the block and by the field reduction (§2.4), so each needs a step (b) and a step (c) contribution | P3.6, and P3.1's V1 for the step (c) half alone |
| the knot **slopes** are not declared as block inputs | the light channel is a fixed fraction of itself, correct sign, nothing thrown — the same shape as the trait case. T5 covers it only if it seeds both data vectors | P3.1's V1, and T5 written over values *and* slopes |
| the leaf's boundary is wider than §2.3 and report 02 §6.8 declare | P3.2 grows an output nobody declared | P3.2; P0.5's inventory should predict it |
| the leaf's waist does not hold where it has not been measured | the joint residual over the `2n + 1` directions leaves the 1e-04 band, or `dR_dflux` recovered from two potential directions disagrees | P3.2 step (3), and report 02 §11's last two falsifiers |
| the envelope row is used at an unpolished operating point | carbon is right and every uptake row is wrong at first order in the displacement | report 02 §6.5; the polish lands with Phase 2 |
| the gradient is right and too slow to use | the whole-gradient wall clock against §8b's budget. Nothing else catches it: every other gate is a value | P3.6, and partially at P3.2 — one block's sweep times the block count is most of it |
| the boundary node's lag is still open when the reverse pass is written | `step_adjoint` needs a per-species scalar carried across step boundaries, which it cannot have | P2.7, before P3.5. If it slips, `Trajectory` grows a field (P1.4) |
| the value-reproduction check is read as an acceptance test | a 0.2% difference in value has produced a sign-flipped gradient | every gate compares AD against an independent reference — a re-run finite difference everywhere except the leaf's flux rows, where §2.5 says why an identity is the better one |

---

## 10. Review gates on this plan

1. **Does the block boundary close as §2.3 states, with the light entering as knot values?**
   **M1** answers it without plant.
2. **Does the scalar belong on the types that own the parameters, with `<T,E>` unchanged?**
   **M2** for one file; P1.2 for TF24.
3. **Is the normalised light coordinate bit-identical to `rescale_spline`?** Only in P2.1's first
   step, and deliberately not in its second. M3's accuracy half settles the fractions — uniform at
   65 — and prices the switch at a 1.7e-03 crown-mean light shift, so the interpolant change *is* a
   model change and Phase 2 needs the owner for it. The bit-identity to check is step (1)'s.
4. **Is the leaf's boundary as report 02 §6.8 states it** — `2n + 3` geometry and soil inputs
   plus twelve of its own parameters, out to profit and one uptake per rooted layer? A thirteenth
   parameter or a sixth output kind changes P3.2's shape. Note the output arity is
   state-dependent through `max_soil_layer`, so an assertion must read it rather than the layer
   count.
5. **Do P0.6's two ecology decisions bump `scientific_version`?** With P2.1 and P2.4 also
   changing forward numbers, there is a case for taking all four to the owner together.

**Order: M1, M2, M3's accuracy half and M5 are done. M4 remains, and it lands with P2.4 step (1);
(4) before P3.2; (5) before anything is verified against TF24's numbers.**

---

## 11. Four design threads, settled

Each was frontloaded deliberately: the cost of getting one wrong is a wrong gradient that looks
plausible, and all four were cheaper to settle on paper than in a bisect. They were worked in this
order because each constrains the next. What remains open in each is stated at its end.

**11.1 The state-transfer interface. Settled — the shape is P1.1 and P1.2a.**

odelia's System contract is already scalar-generic: its own AD examples template every ODE
method on the iterator (`examples/lorenz_system.hpp:106`), and `least_squares` calls
`ode_state` on an active vector (`gradient.hpp:157`). The legacy `double` typedefs are used in
exactly four places in all of odelia — the recursive element-range helpers at
`ode_interface.hpp:73, 82, 92, 102` — which exist only for plant, because odelia has no
container System. plant's signatures adopt them from there, in **26 places across 9 headers**.

Two compile probes on develop `141dc8df` against odelia `854a8e18` measured the surface rather
than estimating it.

*Probe A*, double containers called with an active iterator: **3 errors**, all the iterator
type. Nothing hidden.

*Probe B*, the two legacy typedefs redefined to name an active iterator — which makes every
plant signature that adopted them active-typed **without editing plant** — **4 errors**, all one
shape:

```
environment.h:40   vars.states[i] = *it++;                        // store is vector<double>
node.h:243         individual.set_state(i, *it++);                // set_state(int, double)
node.h:245         offspring_produced_survival_weighted = *it++;
node.h:246         set_log_density(*it++);                         // takes double
```

**The read-out direction produced no errors at all** — `ode_state`, `ode_rates` and `ode_aux`
write `*it++ = individual.state(i)`, and `double` to active is an implicit conversion. So
templating those signatures is *sufficient*, with no body changes. Only the load direction
fails, and it fails exactly where an active value must be stored into a `double` member. Those
four points are the state vector, which is why the plumbing and the scalar split cleanly into
P1.2a and P1.2b.

The probe reports only what was instantiated, and each `set_ode_state` body stopped at its first
failing assignment, so there is a cascade behind each of the four once the store carries `S`.
What it establishes is that there is no *third* category: no `Rcpp::` conversion, no `util::`
helper taking `double` by value, no arithmetic failure, and nothing in `Species`, `Patch` or
`SpeciesBase` bodies.

Two incidentals from the same probes. plant-develop compiles clean against `854a8e18`, so
report 02 §4's build blocker is AD-branch-only and its §10 item 5 is dead. And `node.h` is not
self-contained — it names `Individual<T,E>` at line 18 without including `plant/individual.h`,
and only compiles because real translation units reach `species_base.h` first by another route.
Harmless today; it bites the first time a translation unit is added, which is what a gradient
entry point is.

**11.2 The boundary node.** Report 01 §3.1 carries the mathematics — it is a flux boundary
condition, `g(x_b) n(x_b) = B(t)`, and the reverse-mode treatment of one is standard and costs a
single term because the forward inflow boundary is the adjoint's outflow boundary. It also carries
the measurements, and they settle the numerical half:

- **The one-stage lag is numerically irrelevant.** The boundary node's whole contribution to the
  light field is bounded by **3.5e-04**, at `ResourceSpline`'s own `1e-4` fitting tolerance, so the
  difference between its lagged and converged value is smaller again. Closing the fixed point buys
  no accuracy.
- **The circularity is real, and the clamp cannot sever it.** `L` over the seedling crown
  `[0, height_0 = 0.344195]` runs **0.1657 to 1.0** against a floor of `1e-4`, binding at **0 of 141**
  introduction steps; the field's own light column gives minimum **0.1657209**, 0 of 8 292 values at
  or below the floor. Structural rather than lucky: `L = exp(-A)`, minimised at the ground by
  construction, and `1e-4` needs `A ≈ 9.2` against a maximum `A(0)` of **1.797**.
- **The channel is continuous, not per-event.** `Species::compute_competition` closes its trapezium
  on `new_node` (`species.h:220-223`), so the boundary density is the field quadrature's lower
  endpoint at every stage. §2.4 carries what that does to the introduction's adjoint.

**Decided: keep the channel and close the lag.** Two facts settle it. `A` is exactly proportional to
`birth_rate` — every cohort's density is seeded as `log(birth_rate * pr_estab / g)` and transported
by a rate independent of it — so `dA/d(log birth_rate) = A` and the boundary node carries *exactly
its share* of that sensitivity, 1.454% at the median. Dropping the channel therefore needs a number
nobody has. And the fixed point

    n_b  ->  B * pr_estab(field(n_b)) / g(field(n_b))

is **a contraction with modulus of order 1e-3**, because the boundary term is at most 1.3e-3 of `A`.
So one extra Picard step converges it to about 1e-6 relative — one additional boundary-node
evaluation per species per stage, not a root-find, and `implicit_value` is not needed. The
implicit-function correction to the derivative is O(1e-3), so the adjoint takes the naive
within-stage derivative and is right to a tenth of a percent.

The reason to close it is structural rather than numerical: keeping the lag forces a scalar to be
carried backwards across stage boundaries and, at a step's first stage, across the step boundary,
through `step_adjoint` — which is odelia's and knows nothing about species. That is mutable state in
the adjoint pass.

**The lag lands as P2.7**, with Phase 2's other three forward changes. §2.4 states the two-term
boundary derivative — through the flux `B = birth_rate · pr_estab`, and through the speed `g` — and
both reach the field and the soil, so the introduction is not a parameter-only seam. The Leibniz term
at the reduction's lower limit is P3.1's, in step (c).

**Open:** the `g > 0 ? ... : log(0)` cliff, which is representational rather than ecological and
belongs with P0.5.

**Closed since this thread was opened:** the light-floor census. Report 07 §1.8's four-orders
disagreement was an artifact — `res$env$light_availability` is 8 292 × 5, and coercing the whole
tibble to one vector censused times, step indices, patch densities and knot heights alongside the
light values, so the "minimum exactly 0" was the ground knot's *height*. Both P0.5 floor rows now
read zero, by two independent routes.

**11.3 Density transport. Settled — report 04 now states it as the design.** The cohort-grid
stencil is exactly `d(log dh)/dt`, so it is the same discretisation as transporting counts without
changing the state or any consumer; it makes the scheme conserve individuals up to mortality; it is
consistent with the flux boundary condition in the collapsing-interval limit; and it removes about
half of TF24's leaf solves.

**The staggering is decided** (report 04 §7): pair each cohort with the interval **below** it. It
is the upwind direction, it is develop's `node_gradient_direction = -1`, it is the staggering
`Species::compute_competition` already uses by closing its trapezium on `new_node`, and it removes
the `size() < 2` case by construction because the boundary node is always a neighbour.

**The seam is one line, and it is now measured.** At the instant of introduction `nodes.back()` is a
copy of `new_node`, so the interval below has zero width — and a rate *is* read there, once per
introduction, through `set_state_from_system`'s first-same-as-last seed. That is the same place as
the stale `k1` (§2.9) and the same place as the boundary node's prescribed density (§11.2).
`tf24-correctness.md` **P0.9** measures it: a pre-existing cohort's rate wrong by more than its own
magnitude at **51 of 141** introductions, and offspring moving **0.2916%** once fixed — twice the
build noise, so attributable. The fix is `compute_rates()` after `compute_environment(false)` in
`introduce_new_nodes`, and it removes all three symptoms. Report 04 §7's stencil carries the remaining
branch with no tolerance in it, guarded on the **divisor** — `dh == 0`, which covers a just-born
cohort, one whose growth has been gated to zero, and two that coincide — rather than on any one of
those causes (P2.4).

**A third reduction has the same cause.** `Species::consumption_rate`'s `size() < 2` returns zero
because a trapezium needs two points, where `compute_competition` integrates from `new_node` up and
never has the problem. **P0.8**: a reduction over the size distribution starts at the boundary, not
at the smallest cohort. Both P0.8 and P0.9 are family-wide and both are engine blockers.

**Open:** the size of the forward-value change (M4), to be presented alongside report 04 §2.2's
conservation diagnostic. The two-pass restructure is designed — report 04 §7.2, sequenced as P2.4
step 2 — with `new_node` in the first pass so the bottom cohort's neighbour is current rather than
lagged.

**11.4 The block's VJP. Settled — §2.3 and §2.4 carry it, report 01 §4.1 and §6.2 the derivation.**
The primitive is a thin wrapper over XAD's tape drivers and nothing more. What needed deciding was
the block's boundary, its layout, and where the code goes, and all three are now stated: the block
is `Individual::compute_rates` (11 out, 141 + n in); the layout is four segments that are already
contiguous, so it is four sizes rather than a table; and the code goes on `Individual` with each
container packing its own segment, which keeps §2.1's rule against a per-model free function.

Three things the design gained by being written out. The transport stencil is a **seed**, so it
belongs with the soil adjoint before the blocks rather than after them (§2.4). `prepare_strategy()`
must not run inside a block. And the shape generalises to other models only if `Environment`
declares what a cohort may read from it, as the same triple as its state.

**Open:** nothing. The test list is written: T1–T3 on the primitive (P1.1) and T4–T6 on the
block's boundary (P3.2). T5's knot-adjoint accumulation has the same silent failure mode as the
trait accumulation and only the latter has a measured signature (41–51%), which is why both are
value assertions.
