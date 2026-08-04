# Reverse-mode differentiation of the TF24 model: the variables, the intermediaries, and the transposes

Written 2026-08-04.

This document states the mathematics of the reverse-mode trait gradient for the TF24
size- and trait-structured model, with every intermediate quantity named and mapped to
the symbol that carries it in the code. Report 00 states the dependency structure and
walks the flow in prose; this states the derivatives. Its purpose is that a reader can
check a line of code against a line of algebra, in both directions.

Sections marked **Gap** are places where the algebra and the implementation disagree
today. Section 11 collects them in dependency order.

---

## 1. What is being differentiated, and why the structure matters

The model carries a density of individuals over a size coordinate, for each of $S$
species, coupled to a shared light field and a shared soil water column. The solver
advances a state vector $y(t)$ by an embedded Runge–Kutta method, and inserts new
degrees of freedom as cohorts are introduced, so $\dim y$ grows during a run.

We want

$$\nabla_\varphi \mathcal{C}, \qquad \mathcal{C} = \mathcal{C}\big(y(T), \varphi\big)$$

a scalar summary of the stand at time $T$ — a census — where $\varphi \in \mathbb{R}^{P}$
collects the trait and physiological parameters. For TF24, $P = 44$ per species.

Three properties of this problem set everything that follows.

**Reverse mode is the only affordable direction.** A forward tangent costs one solve per
component of $\varphi$; the adjoint costs one solve plus one sweep regardless of $P$.
With $P = 44$ that is the difference between a feasible computation and an infeasible
one.

**One layer of the model is an implicit function.** Each individual's carbon gain is the
value of a maximisation over its own stem water potential, solved numerically.
Differentiating through the solver is neither necessary nor accurate; the envelope
theorem and the implicit function theorem give the derivatives in closed form, and
section 7 does that.

**The state grows.** An introduction widens $y$, so the adjoint is not a single backward
solve over a fixed space but a sequence of backward segments, each narrower than the one
after it.

---

## 2. Notation, and the symbol that carries each quantity

Every quantity below is either a state, a parameter, or an intermediary. The third
column is the name in the code; this table is the contract between the algebra and the
implementation.

### Indices

| Symbol | Meaning | Range |
|---|---|---|
| $s$ | species | $1 \dots S$ |
| $k$ | cohort, ordered by the quadrature abscissa | $1 \dots N_s$ |
| $j$ | soil layer | $1 \dots L$ |
| $q$ | knot of the light field | $1 \dots K$ |
| $i$ | Runge–Kutta stage | $1 \dots 6$ |
| $n$ | accepted step of the solver | $1 \dots M$ |
| $\alpha$ | component of $\varphi$ | $1 \dots P$ |

**$p$ is the stem water potential throughout, never a parameter index.** Section 7's
$\Pi_{pp}$ and $\Pi_{pu}$ depend on that reading. Other symbols carry more than one meaning
across sections — $s$ is a species index and also the scalar of section 7.2; $b$ and $c$ are
a birth date and a growth rate index in section 2 and the vulnerability-curve parameters in
section 7.6; $a$ is a Runge–Kutta coefficient, a heartwood area, an allometric constant and
$1/c$. Read them by section.

### State

| Symbol | Code | Meaning |
|---|---|---|
| $h_k$ | `HEIGHT_INDEX` | height of cohort $k$ |
| $\ell_k = \log n_k$ | `Node::log_density` | log of the density carried by cohort $k$. **Not an `Individual` state slot**: it is a `Node` member, with `log_density_dt` and `set_log_density_rate` beside it |
| $b_k$ | `introduction_time()` | the time cohort $k$ was introduced |
| $m^{\mathrm{hw}}_k,\ a^{\mathrm{hw}}_k$ | `state_idx_mass_heartwood`, `state_idx_area_heartwood` | accumulated heartwood. TF24 caches these from the `state_names()` map; `MASS_HEARTWOOD_INDEX` and `AREA_HEARTWOOD_INDEX` are **FF16's** macros |
| $r_k$ | `state_idx_storage` | non-structural carbon reserve, addressed exactly as the heartwood pair is. Only `HEIGHT_INDEX`, `MORTALITY_INDEX` and `FECUNDITY_INDEX` exist as macros |
| $\theta_j$ | `Environment::vars.state(j)` | water content of layer $j$. **Not what the recorded step reads** — see section 5 |
| $\psi_j$ | `get_soil_water_potential_state()`, seated in `psi_soil_cache_` | soil water **potential** of layer $j$: this is what `cohort_reads` pushes |
| $y$ | `Patch::ode_state` | all of the above, species-major |

The quadrature abscissa is

$$x_k = \begin{cases} b_k & \text{birth-date coordinate} \\ -h_k & \text{height coordinate} \end{cases}$$

which is `Species::abscissa_of`. It increases with $k$ in both cases **given the ordering convention** — for $-h_k$ only because a larger $k$ is younger and therefore shorter, which is the convention section 6.2's gap describes breaking. The reverse-mode
gradient is scoped to the birth-date coordinate, where $x_k = b_k$ is fixed at birth and
carries no derivative. This is the single most consequential simplification in the
design and section 6 shows why.

### Intermediaries: the ones that matter

| Symbol | Code | Meaning |
|---|---|---|
| $A_k$ | `area_leaf` | leaf area of cohort $k$, $(h_k/a_{l1})^{1/a_{l2}}$ |
| $E^{\mathrm{comp}}(z)$ | `compute_competition` | competition experienced at height $z$ |
| $\Lambda_q,\ \Lambda'_q$ | knot values and slopes | the light field, as a spline |
| $p^\star_k$ | `opt_psi_stem_`, `root_collar_psi_` | the maximising stem water potential |
| $\Pi_k$ | `Leaf::profit_` | carbon profit at the optimum |
| $U_{kj}$ | `soil_consumption_` | water cohort $k$ draws from layer $j$ |
| $\kappa_k$ | `leaf_specific_conductance_max_` | maximum leaf-specific conductance |
| $c^{\mathrm{i}}_k$ | `ci_` | intercellular CO₂, itself a root of a residual |
| $G(\cdot)$ | `build_cumulative_vulnerability_integral` | cumulative vulnerability integral |
| $g_k$ | `rate(HEIGHT_INDEX)` | height growth rate |
| $\mu_k$ | `rate(MORTALITY_INDEX)` | mortality rate |
| $w_k$ | trapezium weights | the quadrature weight cohort $k$ carries on the abscissa $x_k$ |
| $z,\ z_q$ | heights, knot heights | the vertical coordinate the light field is indexed on |
| $\tilde Q(\nu)$ | `CanopyShape::Q` | fraction of a crown's leaf area above the relative height $\nu$ |
| $\eta$ | `pars.eta` | how top-heavy a crown is |
| $k_I$ | `pars.k_I` | light extinction through a unit of leaf area |
| $\mathcal{C}$ | `Species::census` | the scalar summary being differentiated |
| $\mathfrak{m}$ | a `census_metric` functor | the per-individual quantity the census sums |
| $\varphi$ | `ad_parameters()` | the differentiable parameters, $P = 44$ |

---

## 3. The forward model as a composition

Within one evaluation of the rates at one time, the model is a directed acyclic graph.
Writing it as a composition is what makes the transpose mechanical.

$$\varphi \;\xrightarrow{\ (a)\ }\; \text{strategy} \;\xrightarrow{\ (b)\ }\; \{A_k, \kappa_k\} \;\xrightarrow{\ (c)\ }\; \Lambda \;\xrightarrow{\ (d)\ }\; \{p^\star_k, \Pi_k, U_{kj}\} \;\xrightarrow{\ (e)\ }\; \dot y$$

- **(a) `prepare_strategy`** derives the strategy's dependent quantities from $\varphi$ —
  **and this stage is not on the differentiated chain at all.**
  `TF24_Strategy<S>::prepare_strategy()` **cannot be instantiated at an active scalar**:
  `tf24_strategy.h:1682-1694` carries
  `static_assert(std::is_same_v<S, double>, "Leaf carries double; an active strategy must
  supply the leaf's local Jacobian across this boundary, not template Leaf.")` in its `else`
  branch. What the reverse pass does instead is `rebind_from` (`:565-605`), which copies the
  already-derived quantities **at their `double` values**:
  `out.eta_c = U(eta_c); out.height_0 = height_0; out.area_leaf_0 = U(area_leaf_0);`. And
  `set_block_inputs` (`individual.h:207-224`) writes the parameters and re-applies the states
  but **never calls `prepare_strategy` or `refresh_indices`**. So every
  $\varphi \to$ derived-quantity edge is a **tape constant**, and `height_0 = height_seed()`
  (`:1677`) — which depends on `omega` and `lma`, both in $\varphi$ — has a **silently zero
  derivative**. Stage (a) runs once, at `double`, outside the recording, in
  `make_strategy_ptr` (`:1699-1702`). Read it as a boundary condition on the chain and not a
  link in it.
- **(b) allometry** gives each cohort's size-dependent quantities from $h_k$ and $\varphi$.
- **(c) the field reductions** aggregate over cohorts to give the shared environment.

  **This is not the only many-to-few map, and the correction matters because the second one
  is downstream, not upstream.** `patch.h:1090-1100` sums every cohort of every species'
  `consumption_rate(i)` into one number per soil layer and hands it to
  `env.compute_rates(resource_depletion)` (`:1103`). Its transpose scatters too. It sits
  **after** (d), because $U_{kj}$ is a block *output*, so the diagram
  $\{p^\star,\Pi,U\} \to \dot y$ hides a whole reduction.

  **And on the current tree that forward edge is cut, not merely undrawn.** `patch.h:1101-1104`
  is `resource_depletion.push_back(odelia::util::to_passive(resource_consumed / area));`, with
  the in-place comment that the environment's own store is `Internals<double>` so the uptake is
  read at its value. So the water channel from cohorts back into the soil state carries no
  derivative at all.
- **(d) the individual** solves its own maximisation given the field. This is the only
  implicit step.
- **(e) assembly** writes the rates back into $\dot y$.

The important structural fact is that (c) is a reduction and (d) is a *per-cohort
independent* map. So the reverse pass is: transpose (e) cohort by cohort, transpose (d)
cohort by cohort, then transpose (c) once, which scatters the field's adjoint back over
every cohort. **That is the correct transpose of the forward order for the light channel and
it is incomplete for the water channel**, per the second reduction above.

**Six hops of the implementation are named nowhere in sections 3 and 4.** In descending order:
`Solver::solve_adjoint` (`ode_solver.hpp:268`), `SolverInternal::step_adjoint`
(`ode_solver_internal.hpp:51`), `Step::step_adjoint` (`ode_step.hpp:259`),
`sweep_stages`/`stage_state`/`stage_row` (`:224`, `:195`, `:184`),
`Patch::ode_rates_adjoint` (`patch.h:1747`) and `Patch::cohort_block_adjoint` (`patch.h:1478`).
The mathematics below is right; a reader cannot get from it to the code without this list.

---

## 4. The discrete adjoint of the solver

Let the solver advance $y_n \mapsto y_{n+1}$ by

$$Y_i = y_n + \Delta t_n \sum_{l<i} a_{il} k_l, \qquad k_i = f(Y_i, \varphi, t_n + c_i \Delta t_n),$$

$$y_{n+1} = y_n + \Delta t_n \sum_i \beta_i k_i .$$

Given the adjoint $\bar y_{n+1}$ of the state after the step, the step's transpose is

$$\bar k_i = \Delta t_n \beta_i \bar y_{n+1} + \Delta t_n \sum_{l>i} a_{li} \bar Y_l, \qquad \bar Y_i = \left(\frac{\partial f}{\partial y}\Big|_{Y_i}\right)^{\!\top} \bar k_i,$$

swept for $i$ descending, and then

$$\bar y_n = \bar y_{n+1} + \sum_i \bar Y_i, \qquad \bar\varphi \mathrel{+}= \sum_i \left(\frac{\partial f}{\partial \varphi}\Big|_{Y_i}\right)^{\!\top} \bar k_i . \tag{4.1}$$

Two consequences the implementation must respect.

**The step size is held.** $\Delta t_n$ was chosen by the adaptive controller using an
error estimate. Treating it as a differentiable function of $\varphi$ would
differentiate the controller, which is not the model. So $\Delta t_n$ is a recorded
constant on the reverse pass. This is why a recorded trajectory must store its step
sizes rather than recompute them.

**$\bar\varphi$ accumulates over every step and every stage.** There are $6M$
contributions, and (4.1) is the only place they enter. In the code that accumulator is
`Patch::trait_adjoint`.

### 4.1 Introductions: the state changes dimension

Let the run have widths $d_1 < d_2 < \dots < d_B$ over $B$ segments, with an
introduction between consecutive segments. The adjoint sweeps segment $B$ first. At the
boundary between segment $\sigma+1$ and segment $\sigma$, the newly introduced
components have no predecessor in $y$: their adjoints leave the state and enter
$\bar\varphi$ through the boundary condition

$$\ell_{\text{new}} = \begin{cases}
\log\!\big(\text{birth\_rate}\cdot\text{pr\_estab}\big) & \text{birth-date coordinate} \\
\log\!\big(\text{birth\_rate}\cdot\text{pr\_estab}\,/\,g\big) & \text{height coordinate}
\end{cases} \tag{4.2}$$

**Read from `Node::compute_initial_conditions`.** The division by the growth rate is the
**height** branch only: on the birth-date coordinate there is no $1/g$, because nothing moves
an individual along the birth-date axis. An earlier form gave the divided form
unconditionally, and the gradient runs on the coordinate that does not have it.

which reads $\varphi$ directly and is `Patch::introduction_adjoint`. Then $\bar y$ is
narrowed to $d_\sigma$ and the sweep continues.

*Requirement.* The narrowing must be applied to every column when several functionals
are swept together, and the segment list must cover every recorded step with no gap.
Nothing currently asserts the second.

---

## 5. The recorded cohort step

The unit of the reverse pass is one evaluation of `Individual::compute_rates` for one
cohort at one Runge–Kutta stage, recorded at the active scalar type. Its inputs are

$$u_k = \big(\underbrace{h_k,\ \mu^{\mathrm{cum}}_k,\ F_k,\ a^{\mathrm{hw}}_k,\ m^{\mathrm{hw}}_k,\ r_k}_{\texttt{ode\_state},\ \text{6 states}},\ \underbrace{\Lambda, \Lambda'}_{\text{field},\ 2K},\ \underbrace{\psi_{1:L}}_{\text{soil potentials}},\ \underbrace{\varphi}_{P}\big)$$

**Read from `Individual::block_inputs`**, which is `ode_state`, then
`environment.cohort_reads`, then `ad_parameters()`; and from
`block_input_size() = state_size() + n_cohort_reads() + ad_parameters().size()`.
`TF24_Strategy::state_names()` gives the six as height, mortality, fecundity,
area_heartwood, mass_heartwood, storage — so the own-state block is **six**, and the two
this document had omitted are the cumulative mortality $\mu^{\mathrm{cum}}$ and the
cumulative fecundity $F$.

**$\ell_k$ is not an input.** It is a `Node` member, not an `Individual` state, and
`ode_state` does not carry it: `compute_rates` never reads the density. An earlier form of
this section listed it, and report 01 section 4.1 is **right** about that. It is wrong about
the output — see below.

and its outputs are

$$v_k = \big(\underbrace{\dot h_k,\ \mu_k,\ \dot F_k,\ \dot a^{\mathrm{hw}}_k,\ \dot m^{\mathrm{hw}}_k,\ \dot r_k}_{\texttt{ode\_rates},\ \text{6}},\ \underbrace{\dot \ell_k}_{\text{density rate}},\ \underbrace{U_{k,1:L}}_{\text{consumption}}\big).$$

**Read from `block_output_size() = state_size() + 1 + n_resources()`** and from
`block_outputs`, which emits `ode_rates`, then `log_density_rate(environment)`, then the
consumption rates. **So $\dot\ell_k$ *is* an output** — the `+1` — and report 01 section
4.1 is wrong about that half.

With $K = 65$ (`ResourceSpline::knot_count_ = 65`) and $L = 5$, and
`n_cohort_reads() = 2 * knot_count() + soil_number_of_depths = 135`:

$$6 + 135 + 44 = \mathbf{185}\ \text{inputs}, \qquad 6 + 1 + 5 = \mathbf{12}\ \text{outputs}.$$

**Both counts are configuration-dependent.** 12 holds at five soil layers only, and the
input count moves with the layer count and the knot count. An earlier form of this section
gave 184 from a five-state own block; the six-state read above is the correct one.

The reverse pass forms $\big(\partial v_k / \partial u_k\big)^{\!\top} \bar v_k$.

### 5.2 The field's 130 inputs reach the leaf through one number

This is the economy that makes the design affordable and this document omitted it.

**Read from `TF24_Strategy::net_mass_production_dt`.** There are three shading modes; the
default is `MeanLight`. `DeepCrown` is guarded by
`if constexpr (std::is_same_v<S, double>)` with a `util::stop` in its `else`, so it is not
available at an active type. In each of the two that are, the whole physiology is driven by
a **single** scalar handed to a local `optimise_at(const S& radiation)`:

- `CrownCentre`: `optimise_at(radiation_at(environment.get_environment_at_height(height * eta_c)))`
  — one query.
- `MeanLight`: `optimise_at(radiation_at(function_integrator.integrate(f, S(0.0), height)))`
  with `f` calling `compute_average_light_environment` — a crown integral.

Therefore for any leaf output $v$,

$$\frac{\partial v}{\partial \Lambda_q} = \frac{\partial v}{\partial \mathcal{R}}\cdot\frac{\partial \mathcal{R}}{\partial \Lambda_q},$$

so the $12 \times 130$ block is $12 + 130$ numbers rather than 1560 — **rank one for the leaf's
outputs.**

**It is not rank one for the whole 12-output block at the default coordinate, and the
correction sharpens section 5.1 rather than weakening it.** Output row 7 is
`log_density_rate`, and at `node_density_in_birth_date = false` that contains
`-growth_rate_gradient(environment)`, which runs `compute_rates` again **at a displaced
height** on a copy (`individual.h:257-273`, `:288-296`). The second evaluation makes its own
field query — `get_environment_at_height(height' * eta_c)`, or under `MeanLight` an integral to
a **different upper limit**, which is not a multiple of the first. So the block has **rank at
least 2** at the default and up to 9 under Richardson at depth 4. `cohort_block_adjoint`
concedes the mechanism in place (`patch.h:1555-1557`). **Rank one is exact on the birth-date
coordinate**, where `log_density_rate` is `-rate(MORTALITY_INDEX)` with no second solve — so
the coordinate choice buys the factorisation as well as the solve.

It is
already exploited: `graft_leaf_outputs` receives radiation as one active scalar, so the
supplied derivatives are a row over `2*max_soil_layer + 3 + n_leaf_parameter_inputs` = 28 inputs **when all five layers are
rooted** — `max_soil_layer` is not the layer count but the number of layers carrying non-zero
root mass, recomputed per call (`leaf_model.cpp:278-281`), so the row length varies within a
run and `graft`'s length check is what refuses a mismatch — and the tape carries the second factor
through the recorded spline query. Report 07 section 1 develops the sparsity of that
factor, which differs between the two modes.

### 5.1 The density rate is where the coordinate choice bites

On the birth-date coordinate,

$$\dot \ell_k = -\mu_k, \tag{5.1}$$

whereas on the height coordinate the density is compressed by the growth of the size
axis and

$$\dot \ell_k = -\mu_k - \frac{\partial g}{\partial h}\Big|_{h_k}. \tag{5.2}$$

Equation (5.2) is why the height coordinate is expensive to differentiate:
$\partial g/\partial h$ requires further solves of the whole individual at displaced
heights, and the count depends on a `Control` field. `node_gradient_richardson` defaults to
false, and the one-sided difference then reuses the rate already computed and costs **one**
extra solve. Under Richardson at the default depth of 4 it costs **eight**. Equation (5.1)
needs none of them: $\mu_k$ is already an output of the same step.

So the birth-date coordinate removes one extra individual solve per recorded step at the
default, and eight under Richardson. **Do not read that as halving the recorded tape work**:
solve count and tape work are different quantities and only the first has been counted.

---

## 6. The environment reductions and their transposes

### 6.1 Light

The competition profile at height $z$ sums over every cohort of every species:

$$E^{\mathrm{comp}}(z) = \sum_s \sum_k w_k \, n_k \, k_I^{(s)} \, A_k \, \tilde{Q}\!\left(\frac{z}{h_k}\right), \tag{6.1}$$

where $\tilde{Q}(\nu) = (1 - \nu^{\eta})^2$ for $\nu \le 1$ and $0$ above, and $w_k$ are
the trapezium weights on the abscissa $x_k$. The field is then a spline through $K$
knots, so the recorded cohort step reads $(\Lambda_q, \Lambda'_q)$ and not
$E^{\mathrm{comp}}$ directly.

Given knot adjoints $\bar\Lambda_q$, the transpose of (6.1) scatters:

$$\bar\ell_k \mathrel{+}= \sum_q \bar\Lambda_q \, w_k \, n_k \, k_I \, A_k \, \tilde{Q}(z_q/h_k) \tag{6.2}$$

$$\bar h_k \mathrel{+}= \sum_q \bar\Lambda_q \, w_k \, n_k \, k_I \left[ A_k' \, \tilde{Q}(z_q/h_k) - A_k \, \tilde{Q}'(z_q/h_k) \frac{z_q}{h_k^2} \right] \;+\; \underbrace{\sum_q \bar\Lambda_q \, n_k \, k_I A_k \tilde{Q} \, \frac{\partial w_k}{\partial h_k}}_{\text{zero on the birth-date coordinate}} \tag{6.3}$$

$$\bar{k}_I^{(s)} \mathrel{+}= \sum_q \bar\Lambda_q \sum_{k \in s} w_k \, n_k \, A_k \, \tilde{Q}(z_q/h_k) \tag{6.4}$$

$$\bar\eta^{(s)} \mathrel{+}= \sum_q \bar\Lambda_q \sum_{k \in s} w_k \, n_k \, k_I^{(s)} A_k \, \frac{\partial \tilde{Q}}{\partial \eta}, \qquad \frac{\partial \tilde{Q}}{\partial \eta} = -2(1-\nu^{\eta})\,\nu^{\eta}\log\nu \ \ (\nu \le 1),\ \ 0 \text{ above} \tag{6.5}$$

**$k_I$ and $\eta$ are per-species, so each sum runs over that species' cohorts only.**
Summing over every cohort of every species collapses the species into one scalar. This
matters because closing the gap below means writing these two lines.

**The slope channel is a further set of terms this section does not write.** Section 5 lists
$(\Lambda, \Lambda')$ as $2K$ inputs, so the transpose must also contract $\bar\Lambda'_q$
against

$$\partial_z E^{\mathrm{comp}}(z_q) = \sum_s \sum_k w_k \, n_k \, k_I^{(s)} A_k \, \tilde{Q}'(z_q/h_k)\,\frac{1}{h_k},$$

whose $h_k$ transpose carries a $\tilde{Q}''$ term appearing nowhere above. The
implementation has this channel — its function is `compute_competition_and_slope_adjoint` —
so a reader checking that function against (6.2) and (6.3) will find terms with no
counterpart here. **Writing them out is owed.**

Two things to read off this.

The braced term in (6.3) is the weight-derivative term. It exists only because the
height coordinate makes the quadrature abscissa a function of the state. On the
birth-date coordinate $x_k = b_k$ is fixed at birth and passive, so
$\partial w_k/\partial h_k = 0$ and the term vanishes.

**WARNING: that is the intended state and not the built one.**
`Species::compute_competition_and_slope_adjoint` builds its trapezium widths from node
**heights**, unconditionally, and writes `out[upper].height += edge; out[k].height -= edge;`,
while the forward reduction integrates over `abscissa_of` — `introduction_time()` on the
birth-date branch. **So the adjoint carries this term live on a coordinate where the forward
function has no such dependence, and neither reduction is the transpose of its forward
function there.** `consumption_rate_adjoint` has the same defect.

**This warning understates the defect. A close read found three parts, not one.** The extra
weight term is only the first. **The trapezium *widths* themselves are wrong** on the
birth-date branch, because they too are built from heights. **The boundary condition drops
`|| birth_date`.** And **the `!scan.decreasing` stop fires where the forward runs**, because it
tests height ordering with no coordinate condition while the forward tolerates inverted heights
on birth date.

**And one channel nobody has named: `A0 → n_b → A`** — the boundary condition evaluated in the
boundary-excluded field. It is transposed nowhere. Report 00 section 8 names
the weight term as the one a reader is most likely to forget; the coordinate change removes
the need to remember it *once the reductions follow the coordinate*.

Equations (6.4) and (6.5) are trait contributions that arise *inside the reduction*, not
inside any cohort step.

> **Gap.** The implementation has no path for (6.4) or (6.5).
> `Species::compute_competition_and_slope_adjoint` writes through a `node_size_adjoints*`
> with exactly three members — `area_leaf`, `height`, `log_density` — and no parameter
> member, and `Patch::trait_adjoint` is written only from the cohort step and from the
> introduction boundary. **So this reduction's parameter terms reach no accumulator.**
>
> **For $k_I$ that is incompleteness and not a zero, and an earlier form of this gap had it
> inverted.** `net_mass_production_dt` contains
> `radiation_at = [&](S light) -> S { return pars.k_I * std::max(light, S(0.0001)) * PPFD; }`
> — inside `compute_rates`, inside the recorded step, with `pars.k_I` seated from the step's
> parameter segment. So the cohort-step term carries a non-zero
> $\partial(\text{rates})/\partial k_I$ and the accumulator receives it. $k_I$ is a
> self-shading coefficient on absorbed radiation **as well as** an extinction coefficient in
> the reduction, and only the second contribution is missing. **A row that is non-zero and
> short is worse than a zero, because nothing about it looks wrong.**
>
> **$\eta$ has no row at all, for a different reason.** It is absent from
> `ad_parameters()`, excluded there because $u^{k}\log u$ is NaN at a base of zero. Closing
> this gap gives $\eta$ nothing until it is registered, which is separate work.
>
> **This gap is four parameters wide and not two, on one reading, and that reading is
> contested.** A trace of `Patch::allometry_adjoint` (`patch.h:1735-1740`) finds it folds
> `sizes[k].area_leaf` onto height through `darea_leaf_dheight()` alone:
> `lambda_state[... HEIGHT_INDEX] += sizes[k].height + sizes[k].area_leaf * darea_leaf_dheight;`
> — which is the chain $\partial A/\partial h$, **not** the explicit
> $\partial A/\partial a_{l1}$, $\partial A/\partial a_{l2}$ at fixed $h$. On that reading
> `a_l1` and `a_l2` carry the same structural gap as $k_I$: a non-zero row from the cohort step,
> and the reduction's contribution missing.
>
> **A second trace disagreed**, holding that `a_l1` and `a_l2` arrive through the size-space
> adjoint, which already works, and that this gap's reach is one row and one conditional.
> **The two are not reconciled and this is the one open contradiction in section 6.** The
> line-level argument above is the more specific of the two and should be assumed correct until
> someone measures the `a_l1` column against a central difference, which is the check that
> settles it.
>
> Both right-hand sides above are already computed as intermediate products inside the
> existing transpose, so what is missing is a summation and not a derivative.

### 6.1b The field is twenty-four regimes and six objects, and the value is the robust output

**The mirror of section 7.0, and the asymmetry runs the other way.** For the leaf the profit row
survived every degeneracy and the uptake row ceased to exist. For the field **the value is robust
and the slope is fragile**: $L$ is continuous in the field's own arguments everywhere — at the cap
(where $A(H_{\max}) = 0$ exactly), at the crown-top cutoff, across the boundary-interval switch,
across the sorted-view fallback, under both clamps, and at the ground knot for every $\eta$. The
**slope** is the output that ceases to exist. **The field has no folds and no jumps in its value at
all**; every honest refusal here is about $L'$ or about a transpose.

**Consequence for the interface.** `ResourceSpline::get_value_at_height` must keep working when
`get_value_and_slope_at_height` refuses. The paired accessor cannot express that, and refusing both
together would stop a forward model that has no derivative problem.

**Six objects.** **A** a smooth reduction with a moving domain — twelve of the twenty-four regimes,
including four the reports treat as hazards that are not: the crown-top cutoff, the species'
above-canopy exit, the cap, and the boundary-interval switch are each a $C^1$ join where value *and*
slope vanish exactly, so dropping the branch indicator's derivative is **exact**. **B** a
discretisation whose structure depends on state — the grid. **C** a clamp whose severance is an
artefact. **D** an exogenous field that solves no reduction. **E** a refusal, warranted or not.
**F** the slope of a profile the model does not use.

**Report 03 section 1's central claim is discharged, and the plan should stop carrying it as owed.**
Its premise is that $L'$ is the one quantity plant cannot supply for a crown integral whose domain
moves. It is supplied, structurally rather than by a call site: `QK::integrate` takes its bounds as
the **active** scalar and forms `center` and `half_length` on it (`qk.h:70-72`), so every abscissa is
$z = u_k H$ with the affine map on the tape; and `hermite_interpolator`'s read at an active position
returns `graft(value_at(up), slope_at(up), u, up)` (`hermite_interpolator.hpp:113`, `:165`), which is
`value + \mathrm{d}y/\mathrm{d}u \cdot (u - u_p)`. So

$$\frac{d\Phi}{dH} = \int_0^1\Big[L'(uH)\,u\,q(uH,H) + L(uH)\,\partial_H q\Big]du + \int_0^1 L\,q\,du$$

is complete on the tape, and the Leibniz boundary term is absorbed because the rule is *mapped*
rather than truncated. **Nothing on the physiology path needs to call `slope()`.** Abscissae are
strictly interior, so the crown integral never touches the ground singularity and never touches the
cap.

> **Gap: report 03 section 1b's normalised coordinate does not exist in the code, and its third
> consequence is void.** It rules that holding the field on $u = z/H_{\max}$ turns C1's dropped
> position channel into ordinary chain-rule terms, $\partial/\partial z \to 1/H_{\max}$ and
> $\partial/\partial H_{\max} \to -z/H_{\max}^2$. **Neither term is anywhere in the query path.**
> `rebuild_spline` lays knots at `knot_fractions_[k] * to_passive(height_max)` and
> `get_value_at_height` queries at **absolute** height. Since $u_k = k/64$ is exact, `x.back()`
> equals `height_max` bitwise and the rebuild guard is false only while `height_max` is bit-unchanged
> — so the grid is relaid essentially every stage and the channel is re-formed and re-dropped every
> stage, at the measured 1.891e+01. The correct statement is that the field is held on an **absolute**
> grid whose positions are an affine, passive function of an active `height_max`.

> **Gap, and it is a hazard class this document does not have: the gradient's own consumer can drive
> the model into the region where the gradient is wrong.** $Q(0) = 1$ for every $\eta$, so the
> field's minimum over its whole domain is at the ground knot and equals
> $L(0) = \exp(-k_I\,\mathrm{LAI})$. The $10^{-4}$ floor therefore binds when
> $k_I\,\mathrm{LAI} \ge \ln 10^4 = 9.2103$. Measured on the one stand this corpus has run,
> $A(0) = -\ln(0.1657209) = 1.7975$ at $k_I = 0.5$, so $\mathrm{LAI} = 3.595$ and **the floor binds
> at $k_I \ge 2.562$ at this stand, or $\mathrm{LAI} \ge 18.42$ at this $k_I$.** `k_I` is a
> **registered, free parameter**, so a calibration or a gradient-ascent run that walks it upward
> walks the field into the severed region — where the row it is ascending goes to zero. **Note
> $\eta$ is not a lever**: it reshapes the profile and leaves $A(0)$ untouched, so report 03's
> "denser canopy or a larger $k_I$" is right and any implicit inclusion of canopy shape is not.
>
> **The undershoot guard is on the same lever, and report 03 treats the two as independent zeros.**
> At the ground knot $m_0 = -L\,A'(0) = 0$ exactly for $\eta > 1$, so the first span undershoots
> below $y_0$ when $m_1 h > 3(y_1 - y_0)$ — a Fritsch–Carlson violation, live precisely when a
> recruit bunch sits inside the first span, whose width is $H_{\max}/64 \approx 0.28$ m at
> production, which is where recruits are. It cannot reach below zero while $y_0 = 0.166$; it can
> once $y_0 \sim 10^{-4}$. **Both clamps fire together, under one parameter change.**
>
> Where either binds the severance is an **artefact and not the model** — $L$ is smooth there, and
> the code records that the floor's "original rationale was never recorded". So the honest action is
> to **refuse the slope row with its incidence counted**, not to return the clamped zero.

**And one clamp is dead code.** $\int_0^H q\,dz = Q(0) - Q(H) = 1$, so the crown mean of
already-floored values is at least $10^{-4}$ identically: the outer `max(light, 1e-4)` in
`radiation_at` **can never bind under `MeanLight`**. It binds only where the argument is a single
point query. Two clamps, one comment asserting they match, one structurally unreachable on the
default path.

**A third model reaches the wrong pair, and report 03's own correction banner does not name it.**
That banner resolves `flat-top-box` and `flat-top-soft-box`. `PPA` routes to `leaf_above_deep`, so
`Q_and_q` hands back the smooth Yokozawa pair while FF16's environment builds a **stepped** profile
— the slope of a field the model does not use. And `Q_and_q_dheight` **throws** for
`FlatTopSoftBox`, whose forward field builds happily, so that model's transpose cannot run although
$\partial q/\partial H$ is one line.

**The ground knot at $\eta \le 1$ is a value defect in plain `double`.**
$q(z \to 0) = 2\eta z^{\eta-1}/H^{\eta}$, whose limit is $0$ for $\eta > 1$, $2/H$ at
$\eta = 1$, and $+\infty$ for $\eta < 1$. The code implements the first two by an exact comparison
on $\eta$ and returns $0$ for the third. And $\partial/\partial\eta$ of the ground-knot slope
does not exist at $\eta = 1$, where the guard hard-codes zero. Latent only because $\eta$ is
absent from `ad_parameters()` — **so Task 18 makes it live.**

### 6.2 Water

Total draw from layer $j$ aggregates the same way,

$$\mathcal{U}_j = \sum_s \sum_k w_k \, n_k \, U_{kj},$$

and the soil state responds through the retention curve $\psi_j = \psi(\theta_j)$. Its
transpose scatters $\bar{\mathcal{U}}_j$ back onto $\bar U_{kj}$, $\bar \ell_k$ and, on
the height coordinate, the weights.

**$\partial\psi/\partial\theta$ is transposed, and correctly — say so, because the passive
signature invites the opposite conclusion.** `psi_from_soil_moist` takes and returns `double`
(`tf24_environment.h:484-507`) and the cache stores a tape constant (`:556-560`), so the tape
carries nothing. The derivative is then **restored by hand** in `Patch::cohort_block_adjoint`
(`patch.h:1578-1582`), which multiplies the incoming adjoint by
`environment.dpsi_from_soil_moist_dtheta(...)` — an exact analytic $-n_\psi\psi/\theta$ that
returns 0 in both clamped regions (`tf24_environment.h:609-619`), consistently with the
forward's `soil_moist_residual` floor and `soil_psi_max_` cap.

**Note the pattern, because nothing enforces it:** a passive forward function with a
hand-written derivative beside it, tied together only by a comment
(`tf24_environment.h:621-622`). It is correct here and it is the shape of a defect elsewhere.

**And the soil retention parameters have no row anywhere, by construction.** `K_sat`, `a_psi`,
`n_psi`, `soil_moist_sat`, `soil_moist_residual` and `soil_psi_max_` are plain `double` members
of `TF24_Environment` (`:298-320`), absent from both `TF24_Pars::field_ptrs()` and
`ad_parameters()`. **The `static_assert` at `tf24_strategy.h:147-149` cannot catch this**,
because they are not strategy members. That is the larger of the two water-side omissions, and
it is a stronger statement than the sorting gap below.

> **Gap.** `Species::consumption_rate` now sorts the cohort grid when the abscissa order
> inverts; `consumption_rate_adjoint` still transposes the unsorted trapezium. On an
> inverted grid the two are not transposes of each other, the gradient is finite, and
> nothing raises an error.

---

## 7. The individual's maximisation

This is the mathematical core. Each cohort chooses a stem water potential $p$ to
maximise profit,

$$p^\star = \arg\max_{p \in [p_a, p_b]} \Pi(p; u), \qquad \Pi = A\big(c^{\mathrm{i}}(p; u)\big) - \Theta(p; u),$$

with $A$ the assimilation and $\Theta$ the hydraulic cost. Everything downstream —
profit, uptake, and hence growth — is evaluated at $p^\star$, which is computed
numerically. We need derivatives of quantities at $p^\star$ with respect to every input
$u$, without differentiating the search.

### 7.0 Five cases, and the selector is not a comparison on the residual

**Establish this before reading anything below it.** Sections 7.1 to 7.6 derive the sensitivity of
an interior stationary maximum and of a pinned bound. The implementation can terminate the choice
in **thirteen** distinguishable ways and the design models **two**. Both counts are wrong, and the
design's two is wrong in the more dangerous direction: the thirteen classify *which guard broke the
polish loop*, and several are one mathematical object, while the design's two omit three whole
categories — and in each omitted category the code currently fabricates a finite number.

**The taxonomy is the sensitivity theory, and it is the only thing that should branch.**

| | case | what kind of point it is | the profit row | the uptake row |
|---|---|---|---|---|
| **S** | interior stationary maximum, $\Pi_{pp}<0$ | unconstrained stationary point | envelope: $\partial\Pi/\partial u$, free | IFT on $R=0$: $m = -s/\Pi_{pp}$, then $m\,\Pi_{pu}$ |
| **K** | constrained optimum, one bound active | KKT point, multiplier $\nu = \lvert R\rvert$ | **not** an envelope: $\partial\Pi/\partial u + \nu\,\partial B/\partial u$ | $\partial E_i/\partial u + (\partial E_i/\partial p)\,\partial B/\partial u$ |
| **B** | a feasible point that is not an optimum | substituted, still solves a relation in $u$ | plain chain rule; the $p$-channel is the substituted expression's own derivative | same form as K, with $\partial p/\partial u$ from the bound(s) |
| **X** | exogenous operating point — solves no optimisation | a substituted constant, or an ODE state | closed form in a strict subset of inputs, **exactly zero** in the rest | shutdown: identically zero. TF24f: at fixed $p$, plus a $\tilde p$ row |
| **N** | no derivative exists | a fold, a jump, or nothing defined | valid at a fold, one-sided at a jump, absent otherwise | **does not exist** |

**The mapping, and five of the thirteen collapse.** `COLLAR_INTERIOR` and `COLLAR_EXHAUSTED` are
both **S** — the cap is the same object with a displaced linearisation point, error $\lvert
R\rvert/\lvert\Pi_{pp}\rvert$, so carry the bar rather than a branch. `COLLAR_BOUND_A`,
`COLLAR_BOUND_B` and `COLLAR_BOUND_STEP` are **K**. `E4` and `E5` are **B**. **`E1`, `E2` and `E3`
are one function of $u$ for every output that carries a rate** — all three route through
`set_shutdown_state`, which writes the same `profit_` and the same zeroed uptake, and they differ
only in `root_collar_psi_`, which reaches an aux slot. `COLLAR_BOUND_CURVATURE` and
`COLLAR_R_NONFINITE` are **N**.

**The selector must be a decision tree on what defines the point, not a comparison on $\lvert
R\rvert$.** Ask in this order: did `prepare_collar_solve` return false (→ X or B, by which exit); is
this TF24f (→ X interior, or K when the clamp binds, never S); is the class `R_NONFINITE` or
`BOUND_CURVATURE` (→ N, refuse); is it `INTERIOR` **and** the guard at `leaf_model.cpp:1081`
false (→ S; if the guard is true, → N); is it `BOUND_A`/`BOUND_B` (→ K); is it `BOUND_STEP` (→ K
*after* snapping the forward point to the bound the step's sign names).

> **Gap: there is a fourteenth terminal case, it is not in `collar_class`, and it is on the good
> path.** `dprofit_droot_collar_psi` returns a hard sentinel `0.0` when `psi >= psi_stem` or
> `psi_stem` is non-finite (`:1081-1083`) — its own comment records the state as reproduced at
> `theta = 0.005–0.03` under 1 m/yr rainfall. The polish's convergence test is
> `!std::isfinite(R) || std::abs(R) <= R_tol` (`:930`), which cannot distinguish a sentinel zero
> from stationarity, so it records **`COLLAR_INTERIOR`**. So class S as the code detects it contains
> a subclass in which the leaf is in a no-flow or infeasible state, $\Pi$ is not stationary, and
> $\Pi_{pp} = 0$ by the same sentinel. **$\lvert R\rvert \le R_{\text{tol}}$ is not a sufficient
> test for S**; it must be conjoined with that guard evaluating false, and the guard firing needs its
> own counter.
>
> **And the consequence in the shutdown case is a division by an exact zero.** `E1` to `E5` all
> return `false` from `prepare_collar_solve`, which **clears** `collar_pinned_` (`:740`), and
> `graft_leaf_outputs` runs unconditionally at an active scalar with no test of how the solve
> terminated. So every X and B case takes the **interior** branch. At `E1` the whole soil is drier
> than $\psi_{\text{crit}}$, so both evaluations inside `dR_dcollar_at(p, 1e-6)` return the
> sentinel, **$\Pi_{pp} = 0$ exactly**, and $m = -s/0$ with $s$ generically non-zero. A two-branch
> selector on $\lvert R\rvert$ cannot detect this, because $R$ *is* zero there — that is the whole
> problem.

> **Gap: report 00 section 7's curvature measurement cannot falsify a fold, and this is the third
> instance of the pattern.** It reports $\Pi_{pp}$ negative at 52 of 52 states — measured by
> differencing about **the solved operating point**, i.e. only at points where a maximum was found,
> where $\Pi_{pp}\le 0$ holds by the second-order necessary condition. **The sample is conditioned
> on the conclusion.** That is structurally the same defect as report 02 section 6.9's stationarity
> identity, which cannot referee $\Pi_{pp}$ because it is formed from it. The sweep that would
> settle it runs $p$ across the *whole* feasible interval at dry states.
>
> There is a structural reason to expect folds exactly where the plan says the pin lives. The cost
> $C = g_1(1-e^{-(\sigma/b)^c})^{\beta_2}$ is sigmoid in $\sigma$ for $c>1$, so $-C$ contributes
> **positive** curvature below its inflexion and negative above, while $A(c^{\mathrm i}(p))$ is
> concave-increasing. A difference of a concave gain and an S-shaped cost generically has a region of
> positive curvature **on the dry flank** once the cost's inflexion enters the feasible span — and
> drying moves the span onto that flank. `COLLAR_BOUND_CURVATURE` exists, has a census slot, and
> fires on nothing else; **its incidence is the single number the whole $\Pi_{pp}$ question turns
> on.**
>
> **The right guard is on the amplification, not on $\Pi_{pp}$.** Near a fold
> $\partial p^\star/\partial u$ is $O(\lvert\delta u\rvert^{-1/2})$ and does not exist, so a
> bracketed fallback would return a number where none does. Refuse the **uptake** rows when
> $\lvert m\rvert = \lvert s\rvert/\lvert\Pi_{pp}\rvert$ exceeds a declared ceiling — report 00
> measured its benign value at 5.8 times — and **emit the profit row regardless**, because it is
> valid at a fold. `bound_partials` has its own unguarded version of the same denominator,
> $\partial E^{\mathrm{up}}/\partial p - \kappa S'(b_b)$ at a stem sitting at
> $\psi_{\text{crit}}$ where $S'$ has collapsed (`:1441-1443`).

**The asymmetry the design inherited from report 00's fact 1 is stronger than stated, and it is the
one thing the two-branch model got right.** The profit row survives every degeneracy in this list
except a jump of the argmax and an undefined objective. **The uptake row is the one that ceases to
exist.** So the two output kinds must be refusable **independently**, not as a pair.

**These are not five unrelated corner cases. They are consecutive segments of one drydown**, and a
real rainfall sequence traverses them in order: **S → K** as the stand goes dry and tall → **B** as
the feasible window closes with $b_a \to \psi_{\text{crit}}$ → **X** once the window is gone.
Report 02 section 4's own trend is that ordering seen from outside: the minimum bracket falls
monotonically 1.381 to 0.716 with rainfall, and `E2` first appears at the same arm as 110 984
`bound_b` pins.

**One case is the best-conditioned in the model and the plan treats it as a corner.** At `E4` the
operating point is the root of zero *total* uptake, so the per-layer $E_i$ are individually non-zero
and sum to zero: **pure root-mediated redistribution**, and the emitted uptake vector is entirely
the symmetry-breaking residue of report 00's fact 2. Its derivative exists in closed form, and its
relative accuracy under any differencing scheme is the worst in the model, because the output *is*
the residue. Report 00 section 7 files root-mediated redistribution under *sidestepped* on measured
incidence; on a drying driver it is live, and it is the case that most needs the exact route.

### 7.1 The interior optimum: profit is free

Suppose $p^\star$ is interior, so stationarity holds:

$$g(p^\star, u) \;\equiv\; \frac{\partial \Pi}{\partial p}(p^\star, u) \;=\; 0. \tag{7.1}$$

Let $\Pi^\star(u) = \Pi(p^\star(u), u)$. Then

$$\frac{\partial \Pi^\star}{\partial u} = \underbrace{\frac{\partial \Pi}{\partial p}}_{=\,0} \frac{\partial p^\star}{\partial u} + \frac{\partial \Pi}{\partial u} = \frac{\partial \Pi}{\partial u}.$$

This is the envelope theorem, and it is the single largest economy in the design: **the
derivative of profit needs no sensitivity of the optimiser at all.**

### 7.2 The argmax channel is rank one

Other outputs are not stationary in $p$. Uptake $E(p^\star, u)$ is one. For those we
need $\partial p^\star/\partial u$. Differentiating (7.1),

$$\Pi_{pp} \, \frac{\partial p^\star}{\partial u} + \Pi_{pu} = 0 \qquad\Longrightarrow\qquad \frac{\partial p^\star}{\partial u} = -\frac{\Pi_{pu}}{\Pi_{pp}},$$

with $\Pi_{pp} = \partial^2\Pi/\partial p^2$ a scalar and
$\Pi_{pu} = \partial^2 \Pi/\partial p\, \partial u$ a row vector over the inputs.

In reverse mode we never form $\partial p^\star/\partial u$. Given an output adjoint
$\bar v$ on the outputs $v = f(p^\star, u)$ that are **not** stationary in $p$ — the uptake
rows, and explicitly *not* profit — define the scalar

$$s = \bar{v}^{\!\top} \frac{\partial f}{\partial p}, \qquad m = -\frac{s}{\Pi_{pp}},$$

and then

$$\bar u = \bar{v}^{\!\top}\frac{\partial f}{\partial u} \;+\; m \, \Pi_{pu}. \tag{7.2}$$

**Profit is excluded from $s$ deliberately.** Its $p$-channel is zero at an interior
optimum by section 7.1, and at a bound section 7.4 handles it. `s_adjoint` in the code
accumulates the uptake rows only, and the pinned branch adds the profit term separately; a
definition of $s$ including profit would double-count it there.

**Why rank one, stated carefully.** $\partial v/\partial u$ picks up
$(\partial f/\partial p)(\partial p^\star/\partial u)$, a column times a row, which is a
rank-one matrix **because $p$ is a scalar**. In reverse mode that matrix never forms: it
collapses to the two scalars $s$ and $m$. $m$ is itself a scalar, so it has no outer product
with anything, and $m\,\Pi_{pu}$ is a scaled row vector.

In the code $s$ is `s_adjoint` and $m$ is `mu`; the divisor $\Pi_{pp}$ is `dR_dcollar_at`
— **which is itself a central difference** at $h = 10^{-6}$, sitting in a denominator. The
gap below concerns the parameter half of $\Pi_{pu}$; $\Pi_{pp}$ is differenced as well.

### 7.3 $\Pi_{pu}$ is the one genuinely new object

Everything else in this section reuses derivatives the forward model already needs.
$\Pi_{pu}$ does not: it is a mixed second derivative of the profit, one entry per input,
and it must include the implicit-function term of the $c^{\mathrm{i}}$ root-find
(section 7.5). Report 00 calls it the single new piece of code the design needs.

> **Gap.** The implementation substitutes a two-sided finite difference of
> $\partial \Pi/\partial p$ in $\varphi$ for the parameter half of $\Pi_{pu}$: for each
> parameter that reaches the operating point it perturbs the parameter and re-evaluates.
> This costs **22 of the 30** evaluations of `dprofit_droot_collar_psi` per call on the
> interior path — 11 parameters passing `reaches_operating_point`, two sides each, against 2
> in `dR_dcollar_at`, 2 in `dR_dflux_from_layer`, 2 for radiation and 2 for the conductance.
>  **30 is the maximum and not an invariant**: a parameter sitting at exactly zero is skipped
> (`:1798-1800`, `if (!(h > 0.0)) continue;`).
> An earlier form said 35, which reconciles with no count in the source. Its conditioning has
> never been measured.

### 7.3b The waist: $\Pi_{pu}$ is rank two over the state directions, exactly

**This section is the structure the design's cost claim rests on, and until now it appeared
nowhere in this report.** It was derived in report 00 section 6.2 step 5 and report 02 section
6.3, measured there, and never carried forward — so section 7.3 above presents $\Pi_{pu}$ as an
undifferentiated row vector while the code implements the factorisation at
`leaf_model.cpp:1859-1878`.

**The claim.** For every one of the $2n+1$ state directions — the $n$ soil potentials, the $n$
per-layer root masses, and leaf area —

$$\frac{\partial R}{\partial u} \;=\; a\,\frac{\partial E^{\mathrm{up}}}{\partial u} \;+\; b\,\frac{\partial}{\partial u}\!\left(\frac{\partial E^{\mathrm{up}}}{\partial r}\right), \qquad R = \frac{\partial\Pi}{\partial p},$$

with $a$ and $b$ two scalars shared across all of them.

**It is exact, and it is a chain rule rather than a fit.** Trace every read of $\psi$, root mass
and leaf area in `dprofit_droot_collar_psi` (`:1060-1146`): `psi_stem` is
`transpiration_to_psi_stem(E_up_, psi_root)`, so it reads them only through $E^{\mathrm{up}}$;
`ci` reads only `psi_stem` on a state-free bracket; $A'$, $C'$, $g_c$ and the conductance
derivatives are functions of $(c^{\mathrm i}, \psi_{\text{stem}}, p, \varphi)$; and
`dpsistem_dpsi` (`:1128-1136`) reads them through $E^{\mathrm{up}}$ and
$\partial E^{\mathrm{up}}/\partial r$ and nothing else. `area_leaf_` is read at four sites, all
inside the transport chain. So $R = F(E^{\mathrm{up}}, \partial E^{\mathrm{up}}/\partial r;\, p,
\varphi)$ **identically**, and rank two is a chain rule through a two-dimensional intermediate.
An earlier residual figure of 2.6e-04 was the fitting procedure's own noise; the true residual is
8.3e-09 to 2.6e-08.

**$b$ is closed form and the code agrees term for term.** $R$ sees
$\partial E^{\mathrm{up}}/\partial r$ only through `dpsistem_dpsi`, and
$\partial R/\partial(\texttt{dpsistem\_dpsi}) = A'\,\partial c^{\mathrm i}/\partial\psi_{\text{stem}} - C'$,
which is `dprofit_dpsistem`, while
$\partial(\texttt{dpsistem\_dpsi})/\partial(\partial E^{\mathrm{up}}/\partial r) = -P'/\kappa$.
So $b = -\,\texttt{dprofit\_dpsistem}\cdot P'/\kappa$, which is `:1861` verbatim. **$a$ is not
closed form** — $E^{\mathrm{up}}$ moves $\psi_{\text{stem}}$ and hence $c^{\mathrm i}$, $A'$,
$C'$, $P'$ and $S'$ — which is why the code recovers it from one residual pair.

**Two things leave the waist, and both are discrete rather than smooth.** `max_soil_layer` is the
deepest rooted layer, so root mass changes the row's **arity**; and `bound_a`/`bound_b` are
root-finds over the potentials which enter no row on the interior branch and *are* the whole row on
the pinned branch.

> **Gap, and it is the conditioning question section 7.3 says has never been measured.** $a$ and
> $b$ **cannot be separated along the direction the ecology cares about.** Report 02 section 6.3
> justifies recovering $a$ from a single layer on the grounds that the potential family's second
> singular value is $1.3\times10^{-5}$ of the first — the $n$ vectors
> $(\partial E^{\mathrm{up}}/\partial\psi_j,\ \partial^2 E^{\mathrm{up}}/\partial\psi_j\partial r)$
> are numerically **collinear**. That is simultaneously why one direction suffices *given* $b$ and
> why any error in $b$ is absorbed into $a$ at a ratio of about $10^5$. **The joint residual cannot
> detect it**, because a compensating $(a,b)$ pair fits every potential row equally well — so
> report 02's third invariant checks $a$ at fixed $b$ and not the pair.
>
> $b$'s only independent validation is agreement with a noisy joint fit at 1.04 percent and 0.16
> percent. By report 00's fact 2 the uniform drying direction is a near-symmetry whose true
> response is a 1 percent residue amplified 15 to 26 times, so **a 1 percent error in $b$ is a 15
> to 26 times error in the quantity of interest.** $b$ is therefore unvalidated *for the direction
> it matters in.*
>
> **And the object that would fix it is already in the tree and unused.**
> `Leaf::translation_partials` (`:1303-1337`) computes $\partial E_i/\partial d$ from the
> symmetry-breaking term directly. The $2n+1$ waist rows do not route through it, so the
> near-cancellation is performed by subtraction in the caller — which is exactly what report 00's
> fact 2 forbids: *anything defined as a small difference of large quantities must be computed as
> itself.*

**In the dry regime the waist does not degrade. It collapses.**

| regime | the argmax object | rank over $2n+1$ |
|---|---|---|
| interior, wet | $a\,\partial E^{\mathrm{up}}/\partial u + b\,\partial(\partial E^{\mathrm{up}}/\partial r)/\partial u$ | 2 |
| pinned at `bound_a`, zero uptake | $-(\partial E^{\mathrm{up}}/\partial u)\,/\,(\partial E^{\mathrm{up}}/\partial x)$ | **1** |
| pinned at `bound_b` = stem critical | $-(\partial E^{\mathrm{up}}/\partial u)\,/\,(\partial E^{\mathrm{up}}/\partial x - \kappa S'(p_b))$ | **1** |
| pinned at `bound_b` = **root** critical | early return; every state row left at zero | **0** |

The $b$ channel dropping out at a bound is legitimate — there the operating point is defined by a
residual in $E^{\mathrm{up}}$ alone. **The rank-zero row is not.** `bound_partials:1406-1409`
writes `out[i_par0 + PAR_ROOT_PSI_CRIT] = -1.0` and returns, on the stated reasoning that the
root's ceiling "is an input in its own right and nothing else moves it". But
$\psi^{\text{root}}_{\text{crit}} = b_{\text{root}}(\log 20)^{1/c_{\text{root}}}$, so
**`root_b` and `root_c` read exactly zero there** — at the dry-and-tall states where drought
tolerance is the whole question. That row is correct only under Task 28's pullback, which supplies
those two columns from the $\psi_{\text{crit}}$ column through $J$. **Task 28 is therefore
load-bearing for the drought regime and not a reporting convenience.**

### 7.4 The pinned optimum: the envelope theorem does not apply

If the maximiser sits at a bound, $p^\star = B(u)$ with $B$ either the zero-uptake
potential $p_a$ or the critical potential $p_b$, then (7.1) is false:
$\partial \Pi/\partial p \ne 0$ there. Instead $p^\star$ follows the bound,
$\partial p^\star/\partial u = \partial B/\partial u$, and the profit term reappears in
the adjoint. With

$$w = \bar\Pi \, \frac{\partial \Pi}{\partial p} + s, \qquad \bar u = \bar{v}^{\!\top}\frac{\partial f}{\partial u} + w \, \frac{\partial B}{\partial u},$$

where $\partial B/\partial u$ is `Leaf::bound_partials`. This is why the pinned branch of
the code carries a profit contribution that the interior branch correctly omits: it is
not an inconsistency, it is the envelope theorem failing at a boundary.

The bound itself is implicit. $p_a$ is the collar potential at which uptake vanishes,
$E(p_a, u) = 0$, so

$$\frac{\partial p_a}{\partial u} = -\left(\frac{\partial E}{\partial p}\right)^{\!-1} \frac{\partial E}{\partial u}.$$

### 7.5 The $c^{\mathrm{i}}$ root-find

Intercellular CO₂ solves a supply-equals-demand residual

$$R(c^{\mathrm{i}}; p, u) = A(c^{\mathrm{i}}) - \frac{g_c(p,u)\,(c^{\mathrm{a}} - c^{\mathrm{i}})}{P_{\mathrm{atm}}} = 0,$$

bracketed on $[\Gamma^\star, c^{\mathrm{a}}]$. By the implicit function theorem

$$\frac{\partial c^{\mathrm{i}}}{\partial \bullet} = -\left(\frac{\partial R}{\partial c^{\mathrm{i}}}\right)^{\!-1} \frac{\partial R}{\partial \bullet},$$

and this term must be carried into every derivative that passes through assimilation,
including $\Pi_{pu}$.

The bracket is valid only when the endpoints straddle zero. Since
$R(c^{\mathrm{a}}) = A(c^{\mathrm{a}}) = A_{\max}$ and $g_c \propto E$, the bracket
fails when either $A_{\max} < 0$ or $E < 0$ — both of which describe an individual that
is not producing. Those are exactly the states at which the forward model substitutes
$c^{\mathrm{i}} = \Gamma^\star$ with zero flux rather than solving.

> **Gap, and it is new.** Section 7.4's dichotomy — $p^\star = B(u)$ with $B$ either $p_a$ or
> $p_b$ — **covers two of the four pinned classes.** `polish_root_collar_psi:984-987` sets
> `collar_pinned_` for `COLLAR_BOUND_A`, `COLLAR_BOUND_B`, **`COLLAR_BOUND_STEP` and
> `COLLAR_BOUND_CURVATURE`**, and the last two fire on a *rejected Newton step* or a
> *non-negative curvature* (`:968-971`), not on running out of bracket. `bound_partials`
> nonetheless attributes the point to whichever bound is nearer
> (`:1401-1403`, `const bool at_bound_a = (p - bound_a) < (bound_b - p);`). So for those two
> classes $\partial B/\partial u$ is the derivative of a bound **the operating point is not
> sitting on**, and the adjoint is wrong in a way no bound-detection test would notice.
>
> **And TF24f never pins at all.** `tf24f_strategy.h:148,183-199` uses `prepare_collar_solve`
> and `profit_at_collar_psi` and never calls `polish_root_collar_psi`, while
> `prepare_collar_solve:740` **clears** the flag. TF24f inherits `net_mass_production_dt` and
> so inherits `graft_leaf_outputs` and `input_adjoints`, but its operating point is a
> **tracked ODE state clamped into `[bound_a, bound_b]`** (`:1032`) and not an argmax.
> Therefore on TF24f **section 7.1's stationarity and section 7.2's
> $\Pi_{pp}\,\partial p^\star/\partial u + \Pi_{pu} = 0$ are both false**, `collar_pinned_`
> is `false` even when the clamp lands exactly on a bound, and `input_adjoints` takes the
> interior branch and divides by a differenced $\Pi_{pp}$ that has no defining relation
> there. **Section 7 does not mention TF24f anywhere.**

> **Gap.** The forward path tests both conditions; the derivative path tests one; the
> reverse path tests neither and calls the solver, which raises. The consequence is not a
> bracket that is too narrow — in the $A_{\max}$ case no root exists in the domain at all
> — but a missing guard.

### 7.6 The transport integral in closed form

Flux from soil to collar integrates a stretched-exponential vulnerability curve,

$$G(m) = \int_0^m \exp\!\left(-\left(\frac{\sigma}{b}\right)^{c}\right)\,\mathrm{d}\sigma = \frac{b}{c}\, \gamma\!\left(\frac{1}{c},\, X\right), \qquad X = \left(\frac{m}{b}\right)^{c},$$

with $\gamma$ the lower incomplete gamma function, and
$E = \kappa\,[\,G(\psi_{\mathrm{stem}}) - G(\psi_{\mathrm{up}})\,]$.

Writing $a = 1/c$ and using the everywhere-convergent series

$$\gamma(a, x) = x^{a} e^{-x} \sum_{n \ge 0} \frac{x^{n}}{a(a+1)\cdots(a+n)} \;\equiv\; x^{a} e^{-x} \, \Sigma(a,x),$$

both derivatives are available in closed form. The $x$ derivative is the integrand,

$$\frac{\partial \gamma}{\partial x} = x^{a-1} e^{-x}, \tag{7.3}$$

and the $a$ derivative follows from $\partial_a$ of each term, since the $n$th term is
$x^n$ over $\prod_{l=0}^{n}(a+l)$:

$$\frac{\partial \gamma}{\partial a} = \log(x)\,\gamma(a,x) + x^{a} e^{-x} \sum_{n\ge 0} \left(-\,t_n \sum_{l=0}^{n} \frac{1}{a+l}\right), \qquad t_n = \frac{x^{n}}{a(a+1)\cdots(a+n)}. \tag{7.4}$$

So one loop with one extra accumulator gives value and both derivatives. Chaining to the
parameters with $\partial X/\partial b = -cX/b$, $\partial X/\partial c = X \log(m/b)$
and $\partial a/\partial c = -1/c^2$:

$$\frac{\partial G}{\partial m} = \exp\!\left(-\left(m/b\right)^{c}\right)$$

$$\frac{\partial G}{\partial b} = \frac{\gamma}{c} - X \,\frac{\partial \gamma}{\partial x}$$

$$\frac{\partial G}{\partial c} = -\frac{b}{c^{2}}\gamma + \frac{b}{c}\left( X \log(m/b)\, \frac{\partial \gamma}{\partial x} - \frac{1}{c^{2}}\, \frac{\partial \gamma}{\partial a} \right)$$

Note what each parameter needs. Both need the series **value** $\gamma(a,X)$. $b$ needs
additionally only $\partial\gamma/\partial x$, equation (7.3), which is elementary; **only $c$ reaches
$\partial\gamma/\partial a$, equation (7.4).** An earlier form of this sentence said $b$ needs only the
elementary derivative, which would invite an implementer to skip the series in that row.

**The series' argument is bounded here, and by construction.** The series does overflow in
double precision for large $x$ — $\Sigma$ to infinity while $e^{-x}$ underflows, giving NaN —
and **that range is unreachable in this model.** Read from
`Leaf::build_cumulative_vulnerability_integral`:

```cpp
double psi_max = b * pow(log(1.0 / 0.01), 1.0 / c);
```

so $X(\psi_{\max}) = (\psi_{\max}/b)^{c} = \log 100$ **identically, for every $b$ and
$c$**, and $x \le 4.605$ wherever this integral is evaluated. Write the assertion; do not
add an argument switch this model cannot reach. An earlier form of this section demanded
one.

The calculus above is separately verified: all seven quantities agree with an independent
high-precision integral and with central differences of that integral to better than
1e-23, over $c$ from 0.4 to 12 and $m/b$ from 0.075 to 8.

> **Gap.** The implementation tabulates $G$ on a grid — `build_cumulative_vulnerability_integral`
> at `leaf_model.cpp:1944-1956`, and the derivative used downstream is the **spline's** `deriv`
> and not the closed form. So the closed forms above remove the grid, not merely its cost, and
> that part of this gap stands.
>
> **But the knot-count defect this gap claimed does not exist, and the claim is withdrawn.**
> An earlier form said the knot **count** steps by one under a relative perturbation of
> $10^{-6}$ in $b$ or $c$, with measured errors of 47, 131 and 10,245 times the correct values.
> **The grid is captured once and held.** `input_adjoints:1689-1692` and
> `bound_partials:1455-1459` call `build_cumulative_vulnerability_integral` **before any
> perturbation**, to capture the abscissae; every perturbation afterwards goes through
> `set_transpiration_at(b, c, knots_stem)` and `set_root_vulnerability_at(...)`
> (`:1981-1996`, `:1997-2013`), which re-evaluate the knot **values** at the perturbed
> parameter on the caller's fixed `x`, with `y.size() == x.size()`. `setup_transpiration` and
> `setup_root_vulnerability` are reached from the constructors only, so **no grid is rebuilt
> after construction at all.**
>
> **The 47 is the justification comment at `:1682-1685`, explaining why the capture exists.**
> This is the fourth time this project has recorded a comment describing a hazard as evidence
> of the hazard, when the comment sits above the guard that removes it. The rule that follows
> is: **a comment is never evidence of behaviour.**

---

## 8. Supplying the individual's derivatives by hand

The maximisation of section 7 is solved in double precision and is not recorded on the
tape. Its derivatives are supplied instead. For an output $v$ whose value the solver has
already produced, the recorded expression is

$$\tilde{v} = v + \sum_i \left(\frac{\partial v}{\partial u_i}\right)\big(u_i - \mathrm{passive}(u_i)\big), \tag{8.1}$$

where $\mathrm{passive}(\cdot)$ strips the derivative and returns the value. Two
properties:

1. $\tilde{v} = v$ **exactly**, in value, because every bracket is zero.
2. $\partial \tilde v/\partial u_i$ is the supplied $\partial v/\partial u_i$.

So the tape carries the correct number and the hand-derived derivative, and **this
construction serves forward and reverse mode alike**, which is what keeps a forward tangent
available as a reference. It is `TF24_Strategy::graft`.

**`odelia::ode::supplied_derivative` is a different mechanism and the two must not be
conflated.** It registers the output as a fresh tape input and attaches a checkpoint
callback overriding the reverse sweep only. Three consequences differ: it carries **no
forward tangent**, because a freshly registered input has no incoming derivative; a NaN
supplied partial corrupts only the adjoint and not the value, because the value never meets
the partials; and it needs no zero-valued bracket at all.

**Three preconditions of property 1**, none stated by (8.1) alone:

1. **$v$ must enter passively.** `graft` takes a `double`, so it does. If $v$ were an active
   expression, property 2 fails by double counting.
2. **A NaN or infinite *value* of $u_i$ also poisons $\tilde v$**, since $\infty - \infty$ is
   NaN. The gap below covers a NaN derivative; this is a second route.
3. **The $u_i$ must be functionally independent**, or the supplied partials double count.
   They are independent *at this cut* — radiation, the soil potentials, leaf area, the root
   mass fractions, the conductance — even though several are functions of height further
   upstream. **The cut is what makes property 2 true.**

Property 1 has a sharp consequence for verification: **a finite difference of the
recorded step cannot see an error in a supplied derivative**, because perturbing $u_i$
changes $v$ through the solver, not through the bracket. The supplied derivatives must
be checked against the individual's own algebra, never against a difference of the step
that consumes them.

> **Gap.** Property 1 also means a non-finite supplied derivative corrupts the *value*:
> if $\partial v/\partial u_i$ is NaN then $\mathrm{NaN} \times 0$ is NaN and $\tilde v$
> is NaN. `Leaf::layer_flux_partials` returns all entries NaN at a branch kink — equal
> potentials, gravity balance, or a collar potential within $10^{-8}$ of zero — with no
> caller testing for it, so a kink makes the gradient and the forward tangent NaN
> together. The plain `double` path is unaffected because (8.1) is only assembled at an
> active type.

---

## 9. The census functional and its two terms

A census is a quadrature over the size distribution of a per-individual metric,

$$\mathcal{C} = \sum_s \sum_k w_k \, n_k \, \mathfrak{m}(h_k, \varphi),$$

with $\mathfrak{m}$ one of leaf area, above-ground mass, or stem area. Because
$\mathfrak{m}$ reads $\varphi$ directly, the total derivative has two terms:

$$\frac{\partial \mathcal{C}}{\partial \varphi} = \underbrace{\sum_s \sum_k w_k \, n_k \, \frac{\partial \mathfrak{m}}{\partial \varphi}}_{\text{direct, at fixed state}} \;+\; \underbrace{\left(\frac{\partial \mathcal{C}}{\partial y}\right)^{\!\top} \frac{\partial y}{\partial \varphi}}_{\text{through the trajectory, by section 4}} \tag{9.1}$$

The second term is what the adjoint sweep computes, seeded with
$\bar y(T) = \partial \mathcal{C}/\partial y$. The first is not a sensitivity of the
state at all and no sweep produces it.

For the concrete metrics: $\mathfrak{m} = A(h)$ reads $a_{l1}, a_{l2}$;
the second metric is **`mass_above_ground`** and **not** $m^{\text{leaf}}$: `species.h:36-49`
sums `mass_leaf + mass_bark + mass_sapwood + mass_heartwood`, with `mass_bark` and
`mass_sapwood` both $\text{area}\cdot\text{height}\cdot\eta_c\cdot\rho$ and
$A^{\text{bark}} = a_{b1}A\theta$. So its direct-term support is
$\{\mathrm{lma}, \rho, \theta, a_{b1}, \eta_c, a_{l1}, a_{l2}\}$ — an earlier form named
$A(h)\,\mathrm{lma}$, which is not the metric and understates the support; stem area
reads $\theta$ and $a_{b1}$ through sapwood and bark.

> **Correction, and it is substantive.** The claim that the newly introduced components
> "have no predecessor in $y$, so their adjoints leave the state and enter $\bar\varphi$" is
> **wrong**. `Patch::introduction_adjoint` records `set_ode_state_and_field(x.begin(), ...)`
> **followed by** `introduce_new_node()` (`patch.h:1657-1660`), so the newcomer rows are a
> function of the pre-introduction state — through the field build and the boundary node — as
> well as of $\varphi$. Its input vector is `state_before` **plus** the traits
> (`patch.h:1631-1640`) and **both halves of the result are used**:
> `lambda_before[j] += in_adjoint[j]` (`patch.h:1681`) and
> `trait_adjoint[p] += in_adjoint[...]` (`patch.h:1684`). **An implementation written to the
> original sentence would drop $\partial(\text{newcomer})/\partial y_{\text{before}}$
> entirely.**
>
> Two consequences. **Section 4's "(4.1) is the only place the $6M$ contributions enter" is
> false**: `trait_adjoint` has two write sites, `patch.h:1582` and `patch.h:1684`. And **the
> narrowing is interleaved, not a truncation** — newcomers sit at the end of each species'
> node block, so every later species and the environment shift by one node stride
> (`patch.h:1610-1611`).
>
> **And the widening side is omitted from this report entirely.** Before each metric's sweep
> the run must replay every introduction forward to rebuild the states the blocks' first steps
> ran from, because those states are not recorded: `SCM::widen_over_introductions`
> (`scm.h:723-742`), called at `scm.h:702` for each metric and again at `:717` to leave the
> system repeatable, plus the boundary discovery at `:673-688`. **The segment picture below
> cannot be implemented without it.**
>
> **Gap.** `SCM::census_state_adjoint` registers only $y$ as an input, so the direct term
> of (9.1) is absent. Note also that the seed's support is wider than the metric algebra
> suggests: the recording calls `set_ode_state`, which rebuilds the boundary node (4.2),
> whose density is a full physiology evaluation through the light field. So most of
> $\varphi$ takes a non-zero direct term, not only the parameters that appear in
> $\mathfrak{m}$. ~~Measured: 36 of 44 columns.~~ **The 36 is unsupported — it appears in no
> log in `docs/` or `logpile/`.** 44 is confirmed as the per-species trait count. Settle the 36
> by counting the non-zero direct columns in a run and citing the log.
>
> **Where the term would go, read from the code that already does it.**
> `Patch::introduction_adjoint` is the pattern: append `ad_parameters()` to the input vector
> (`patch.h:1626-1636`) and assign them back inside the recorded lambda **before** the state
> (`patch.h:1650-1655`, whose ordering comment — `area_leaf(height)` reads `lma` — applies
> verbatim). The extra columns then land beside the trajectory term at `scm.h:713`.

### 9.1 Several functionals share one recording

**Name the loop, because the fix depends on which one it is.** `SCM::census_state_adjoint`'s
only loop is **over functionals** (`scm.h:635-639`); the species loop lives inside
`census_over` and no cohort loop is present. `METHOD.md` states the rule and names this site,
and a per-cohort signature is numerically identical with a different fix.

For $F$ functionals the record is common and only the seed differs. Recording once and
sweeping $F$ times costs one record plus $F$ sweeps, against $F$ records and $F$ sweeps;
the record dominates.

> **Gap.** The implementation records $F$ times, and worse: it constructs the copy at the
> active type *once, outside* the loop, while each sweep begins by clearing the tape.
> Clearing returns the derivative-slot counter to zero, so every active value that
> outlives a sweep refers to a slot that now belongs to something else. The first
> functional is correct and every later one reads unrelated storage. Measured: rows agree
> with an independent reference for the first metric and, for the later ones, have the
> wrong sign — `mass_above_ground` adjoint $+1.1236$ against a tangent of $-5.0050$.
>
> **Two other figures in an earlier form of this gap were wrong, and one was fabricated. Both
> are withdrawn.** "A magnitude wrong by 180 times" is **65.7**: `area_stem` adjoint
> $-0.117482$ against a tangent of $-0.0017885$, and the archive states it as 65 times. **"33
> of the 52 state columns exactly zero" corresponds to no measurement that exists.** The
> archive's "33 of 44" is a *trait-masking* count and the "52" is the $\Pi_{pp}$ curvature
> probe's population. Two unrelated measurements were combined into a third that was never
> taken. Settle it, if it is wanted, with `stand_census_state_adjoint` at the stated
> configuration, reporting the state width and the per-row zero count, logged.
>
> **And the causal attribution is a hypothesis, not a measurement.** The aliasing mechanism is
> established in XAD — `clearAll()` pushes a fresh `SubRecording` whose `iDerivative_` is
> value-initialised while a surviving `AReal` keeps its old slot (`odelia/src/Tape.cpp:106-119`,
> `XAD/Tape.hpp:266-300`) — but the only recorded measurement localises the failure to the seed
> and labels its cause an unconfirmed hypothesis, of a **stale aux slot** rather than aliasing.
> Fix only the twin's placement and re-measure the three rows against the tangent; that
> separates the two.
>
> **One obstacle this gap does not state.** `vector_jacobian_product` calls `clearAll()` and
> `newRecording()` on entry (`gradient.hpp:178-185`), so record-once-sweep-$F$-times **is not
> expressible through the present API**: the shared driver must change first. And `reduce`
> already computes **all** $F$ outputs in every recording, so the present waste is larger than
> "$F$ records" suggests. This is
> the rule stated in the project's own method document and obeyed at the two other sites
> that build such copies.

---

## 10. Where the trait gradient is assembled

Collecting the paths by which $\varphi$ reaches $\mathcal{C}$:

$$\bar\varphi = \underbrace{\sum_s\sum_k w_k n_k \frac{\partial \mathfrak{m}}{\partial \varphi}}_{\text{census, direct}} + \underbrace{\sum_n \sum_i \left(\frac{\partial f}{\partial \varphi}\right)^{\!\top}\!\bar k_i}_{\text{cohort steps, all stages}} + \underbrace{\sum_{\text{intro}} \frac{\partial \ell_{\text{new}}}{\partial \varphi}\,\bar\ell_{\text{new}}}_{\text{boundary}} + \underbrace{\sum_q \bar\Lambda_q \frac{\partial E^{\mathrm{comp}}}{\partial \varphi}}_{\text{field reduction}}$$

**An earlier form of this section claimed these four were every place $\varphi$ is read.
That claim was wrong, and a completeness claim is exactly where a document like this does
damage.** At least two further paths exist:

$$+ \underbrace{\sum_j \bar{\mathcal{U}}_j \frac{\partial \mathcal{U}_j}{\partial \varphi} + \sum_j \bar\theta_j \frac{\partial \psi_j}{\partial \varphi}}_{\text{the water reduction and the retention curve}} + \underbrace{\bar y(0)^{\!\top} \frac{\partial y(0)}{\partial \varphi}}_{\text{the initial condition}}$$

The water term is structurally identical to the light term, and section 6.2 omitted it: the
retention curve $\psi_j = \psi(\theta_j)$ reads parameters directly, and the aggregation
reads $\varphi$ through $A_k$ and the weights — all outside any cohort step.

The initial-condition term is the one section 10.1 then spends a paragraph inside, so the
document discussed a component of a term it had just declared absent.

**And the introduction term above is written for the density slot only.** An introduction
also writes $h_0$, zeroes the heartwood states, and sets the initial reserve
$r_0 = a_{st3} S_{\max}$, which reads $\varphi$. That reserve channel is real, non-zero, and
was unlisted.

**The enumeration is now closed, and it is two writers.** An exhaustive search of the
superproject for `trait_adjoint` finds exactly two accumulating sites —
`Patch::cohort_block_adjoint` at `patch.h:1582` and `Patch::introduction_adjoint` at
`patch.h:1684`. Everything else is a declaration, a sizer, a clear, a read, or scratch. Both
are reachable in every run. There is no third accumulator hiding behind an adjacent struct:
`node_size_adjoints` and `node_uptake_adjoints` (`node.h:14-26`) have three members each and no
parameter member, so nothing in the reduction transposes can route to a trait row.

**Two things this section left open are now settled, and both are absences.**

- **The water reduction's parameter half is not implemented.** `consumption_rate_adjoint`
  writes only through `node_uptake_adjoints` (`species.h:1061-1088`), which has no parameter
  member, and neither writer is on its path. ~~reading `TF24_Environment::compute_rates_adjoint`
  would decide it~~ — **that function does not exist**; this section prescribed reading something
  that is not there.
- **The initial-condition term is not implemented.** `census_trait_gradient` sweeps segments
  `[boundary[j], k_last]` only, and after the last iteration (`j == 0`) it assigns
  `lambda = narrowed;` and **never reads `narrowed` again** (`scm.h:704-712`). So
  $\bar y(0)^\top \partial y(0)/\partial\varphi$ is computed and discarded. The reserve channel
  above is real and it has no path.

### 10.1 One term is absent from every path

`rebind_from` constructs the copy at the active type by copying the strategy, but
`prepare_strategy` and the seed height refuse an active scalar, so $h_0$, $A_0$ and
$\eta_c$ enter as values. Hence

$$\frac{\partial h_0}{\partial \varphi} = 0 \tag{10.1}$$

is imposed on both AD paths, forward and reverse.

> **Gap.** Equation (10.1) is false. The seed height solves an implicit condition on the
> strategy and does depend on $\varphi$. Measured as about 3 per cent for
> $\mathrm{lma}$. **No instrument in the present design can referee a fix**: the forward
> tangent imposes the same equation, and a re-run finite difference cannot referee at
> production because a relative step of $2\times 10^{-7}$ in $\mathrm{lma}$ moves a
> mature stand between alive and identically zero. Closing it needs an implicit-value
> treatment of the seed height *and* a new reference.

---

## 11. Summary of the gaps, in dependency order

| | Gap | Section |
|---|---|---|
| 1 | Copy at the active type outlives a cleared tape; every functional after the first reads unrelated storage | 9.1 |
| 2 | Field reduction has no parameter accumulator, so $k_I$ and $\eta$ are identically zero | 6.1 |
| 3 | Census direct term not registered | 9 |
| 4 | No guard on the $c^{\mathrm{i}}$ bracket at a non-producing individual | 7.5 |
| 5 | NaN supplied derivative at a branch kink corrupts the value | 8 |
| 6 | ~~Transport derivatives differenced across a grid whose knot count moves~~ — **struck, the grid is held**; what survives is that the transport derivative is the spline's `deriv` and not the closed form | 7.6 |
| 7 | $\Pi_{pu}$'s parameter half differenced, conditioning unmeasured | 7.3 |
| 8 | Consumption adjoint not the transpose of a sorted forward grid | 6.2 |
| 9 | $\partial h_0/\partial\varphi$ imposed zero; **no forward tangent exists at the SCM level to reference** | 10.1 |
| 10 | **The light reduction is not the transpose of its forward function on the birth-date coordinate** — four line-level discrepancies: the trapezium width, the weight-derivative term, the closing boundary trapezium, and a stop that fires where the forward runs | 6.1 |
| 11 | The water reduction's parameter half, and the initial-condition term, are absent | 10 |

**Two corrections to the order.** **Item 8 must precede item 2**, and this table had them the
other way round: item 2's fix adds parameter rows to a reduction transpose, and adding rows to a
transpose that is not the transpose of its forward function gives wrong rows in the new channel
with no signal about which of the two defects produced them. Fix the transposes, then extend
them. **By the same argument item 10 precedes item 2**, on the light side.

**And item 10's status needs stating plainly.** `node_density_in_birth_date` defaults to
**`false`** (`control.cpp:34`), so those four discrepancies are latent in production SCM and
live only under the opt-in — **which is the coordinate this gradient is scoped to.** They are
pre-work for the gradient, not a defect in the forward model, and that is why they belong in
this table rather than in section 6.1's prose alone.

Items 1 to 3 are missing summations or misplaced constructions and each is a small
change. Items 4 and 5 are missing guards. Item 7 replaces a difference with algebra this document gives in closed form, and item 6 now
does so for cost rather than for correctness. Items 8 and 10 are transposes that stopped
matching their forward functions. Item 11 is two absent summations.

Item 9 is the only one that needs a new instrument before it can be closed, and it is
therefore the only one whose scope is genuinely open. **It is more firmly closed than this
document said**: $h_0$ is `double` **by declaration**, not by a copy that could be tightened
(`tf24_strategy.h:611`, `:625`, and `height_seed()` returns `double` for every `S` at `:1616`),
so equation (10.1) is imposed structurally. `eta_c` and `area_leaf_0` are `S` and passive only
by *value*, so if (10.1) is ever attacked those two are the tractable pair and $h_0$ is not.
**And there is no assembled forward tangent at the SCM level at all** — no
`jacobian_vector_product` or forward driver exists in `scm.h`; `forward_derivative` appears only
inside `Leaf` as a local device. So the reference this gap calls equally blind does not exist to
be blind.
