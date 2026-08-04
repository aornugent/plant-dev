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
| $m^{\mathrm{hw}}_k,\ a^{\mathrm{hw}}_k$ | `MASS_HEARTWOOD_INDEX`, `AREA_HEARTWOOD_INDEX` | accumulated heartwood |
| $r_k$ | state named `"storage"`, index 5 of `TF24_Strategy::state_names()` | non-structural carbon reserve. **There is no `*_INDEX` constant for it** |
| $\theta_j$ | `Environment::vars.state(j)`, written by `set_soil_water_state` | water content of layer $j$. `soil_moist` is a local variable and an R output key, not the carrier |
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

- **(a) `prepare_strategy`** derives the strategy's dependent quantities from $\varphi$.
- **(b) allometry** gives each cohort's size-dependent quantities from $h_k$ and $\varphi$.
- **(c) the field reductions** aggregate over cohorts to give the shared environment.
  This is the only *many-to-few* map in the chain, and therefore the only place a
  transpose scatters rather than gathers.
- **(d) the individual** solves its own maximisation given the field. This is the only
  implicit step.
- **(e) assembly** writes the rates back into $\dot y$.

The important structural fact is that (c) is a reduction and (d) is a *per-cohort
independent* map. So the reverse pass is: transpose (e) cohort by cohort, transpose (d)
cohort by cohort, then transpose (c) once, which scatters the field's adjoint back over
every cohort.

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

$$n_{\text{new}} = \frac{\text{birth\_rate} \cdot \text{pr\_estab}}{g}, \qquad \ell_{\text{new}} = \log n_{\text{new}}, \tag{4.2}$$

which reads $\varphi$ directly and is `Patch::introduction_adjoint`. Then $\bar y$ is
narrowed to $d_\sigma$ and the sweep continues.

*Requirement.* The narrowing must be applied to every column when several functionals
are swept together, and the segment list must cover every recorded step with no gap.
Nothing currently asserts the second.

---

## 5. The recorded cohort step

The unit of the reverse pass is one evaluation of `Individual::compute_rates` for one
cohort at one Runge–Kutta stage, recorded at the active scalar type. Its inputs are

$$u_k = \big(\underbrace{h_k, \ell_k, m^{\mathrm{hw}}_k, a^{\mathrm{hw}}_k, r_k}_{\text{own state}},\ \underbrace{\Lambda, \Lambda'}_{\text{field},\ 2K},\ \underbrace{\theta_{1:L}}_{\text{soil}},\ \underbrace{\varphi}_{P}\big)$$

and its outputs are

$$v_k = \big(\underbrace{\dot h_k, \dot m^{\mathrm{hw}}_k, \dot a^{\mathrm{hw}}_k, \dot r_k, \dot{(\text{fecundity})}, \mu_k}_{\text{rates}},\ \underbrace{\dot \ell_k}_{\text{density rate}},\ \underbrace{U_{k,1:L}}_{\text{consumption}}\big).$$

For TF24 with $K = 65$ and $L = 5$ this is $5 + 2K + L + P = 184$ inputs and 12 outputs, and the reverse
pass forms $\big(\partial v_k / \partial u_k\big)^{\!\top} \bar v_k$.

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

Given knot adjoints $\bar\Lambda_q$, the transpose of (7.1) scatters:

$$\bar\ell_k \mathrel{+}= \sum_q \bar\Lambda_q \, w_k \, n_k \, k_I \, A_k \, \tilde{Q}(z_q/h_k) \tag{6.2}$$

$$\bar h_k \mathrel{+}= \sum_q \bar\Lambda_q \, w_k \, n_k \, k_I \left[ A_k' \, \tilde{Q}(z_q/h_k) - A_k \, \tilde{Q}'(z_q/h_k) \frac{z_q}{h_k^2} \right] \;+\; \underbrace{\sum_q \bar\Lambda_q \, n_k \, k_I A_k \tilde{Q} \, \frac{\partial w_k}{\partial h_k}}_{\text{zero on the birth-date coordinate}} \tag{6.3}$$

$$\bar{k_I} \mathrel{+}= \sum_q \bar\Lambda_q \sum_k w_k \, n_k \, A_k \, \tilde{Q}(z_q/h_k) \tag{7.4}$$

$$\bar\eta \mathrel{+}= \sum_q \bar\Lambda_q \sum_k w_k \, n_k \, k_I A_k \, \frac{\partial \tilde{Q}}{\partial \eta} \tag{6.5}$$

Two things to read off this.

The braced term in (6.3) is the weight-derivative term. It exists only because the
height coordinate makes the quadrature abscissa a function of the state. On the
birth-date coordinate $x_k = b_k$ is fixed at birth and passive, so
$\partial w_k/\partial h_k = 0$ and the term vanishes identically. Report 00 section 8
names this as the term a reader is most likely to forget; the coordinate change removes
the need to remember it.

Equations (6.4) and (6.5) are trait contributions that arise *inside the reduction*, not
inside any cohort step.

> **Gap.** The implementation has no path for (7.4) or (7.5).
> `Species::compute_competition_and_slope_adjoint` returns `node_size_adjoints`, a
> structure with exactly three members — `area_leaf`, `height`, `log_density` — and no
> parameter member, and `Patch::trait_adjoint` is written only from the cohort step and
> from the introduction boundary. Since $k_I$ enters the model *only* through (7.1), its
> gradient is identically zero for every functional. The same holds for $\eta$. This is a
> missing summation, not a hard derivative: both right-hand sides are already computed as
> intermediate products inside the existing transpose.

### 6.2 Water

Total draw from layer $j$ aggregates the same way,

$$\mathcal{U}_j = \sum_s \sum_k w_k \, n_k \, U_{kj},$$

and the soil state responds through the retention curve $\psi_j = \psi(\theta_j)$. Its
transpose scatters $\bar{\mathcal{U}}_j$ back onto $\bar U_{kj}$, $\bar \ell_k$ and, on
the height coordinate, the weights.

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
$\bar v$ on outputs $v = f(p^\star, u)$, define the scalar

$$s = \bar{v}^{\!\top} \frac{\partial f}{\partial p}, \qquad m = -\frac{s}{\Pi_{pp}},$$

and then

$$\bar u = \bar{v}^{\!\top}\frac{\partial f}{\partial u} \;+\; m \, \Pi_{pu}. \tag{7.2}$$

Because $p$ is a **scalar**, the whole optimiser channel is the outer product
$m \otimes \Pi_{pu}$ — rank one. In the code $s$ is `s_adjoint` and $m$ is `mu`; the
divisor $\Pi_{pp}$ is `dR_dcollar_at`.

### 7.3 $\Pi_{pu}$ is the one genuinely new object

Everything else in this section reuses derivatives the forward model already needs.
$\Pi_{pu}$ does not: it is a mixed second derivative of the profit, one entry per input,
and it must include the implicit-function term of the $c^{\mathrm{i}}$ root-find
(section 7.5). Report 00 calls it the single new piece of code the design needs.

> **Gap.** The implementation substitutes a two-sided finite difference of
> $\partial \Pi/\partial p$ in $\varphi$ for the parameter half of $\Pi_{pu}$: for each
> parameter that reaches the operating point it perturbs the parameter and re-evaluates.
> This costs 22 of the 35 residual evaluations per call, and its conditioning has never
> been measured.

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

**WARNING: the series is convergent everywhere and usable only for small $x$.** The term
ratio is $x/(a+n)$, so convergence begins near $n \approx x$; and the factored form
$x^{a}e^{-x}\Sigma$ separates an overflowing factor from an underflowing one. In double
precision, $X = 3125$ — which is $m/b = 5$ at $c = 5$, inside this model's range — makes
$\Sigma$ overflow to infinity and $e^{-X}$ underflow to zero, so $\gamma$ evaluates to
**NaN**. Verified numerically.

Therefore an implementation must switch: the series for $x \lesssim a+1$, and the continued
fraction for the upper incomplete $Q(a,x)$ with $\gamma = \Gamma(a)\,(1-Q)$ above it. **Never
form $x^{a}e^{-x}$ and $\Sigma$ separately** — accumulate logarithms, or scale the recursion.
Closing the gap below from the series alone replaces a wrong derivative with a NaN.

The calculus above is separately verified: all seven quantities agree with an independent
high-precision integral and with central differences of that integral to better than
1e-23, over $c$ from 0.4 to 12 and $m/b$ from 0.075 to 8.

> **Gap.** The implementation tabulates $G$ on a grid of 100 knots whose upper limit is
> $b\,(\log 100)^{1/c}$ and whose spacing is that limit over the resolution, under a loop
> bound $\psi \le \psi_{\max}$. The knot *count* therefore steps between 100 and 101 under
> a relative perturbation of $10^{-6}$ in $b$ or $c$, and a finite difference across that
> step is not a derivative. Measured errors are 47, 131 and 10,245 times the correct
> values. The closed forms above remove the grid, not merely its cost.

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
$\mathfrak{m} = m^{\text{leaf}} = A(h)\,\mathrm{lma}$ reads $\mathrm{lma}$; stem area
reads $\theta$ and $a_{b1}$ through sapwood and bark.

> **Gap.** `SCM::census_state_adjoint` registers only $y$ as an input, so the direct term
> of (9.1) is absent. Note also that the seed's support is wider than the metric algebra
> suggests: the recording calls `set_ode_state`, which rebuilds the boundary node (4.2),
> whose density is a full physiology evaluation through the light field. So most of
> $\varphi$ takes a non-zero direct term, not only the parameters that appear in
> $\mathfrak{m}$. Measured: 36 of 44 columns.

### 9.1 Several functionals share one recording

For $F$ functionals the record is common and only the seed differs. Recording once and
sweeping $F$ times costs one record plus $F$ sweeps, against $F$ records and $F$ sweeps;
the record dominates.

> **Gap.** The implementation records $F$ times, and worse: it constructs the copy at the
> active type *once, outside* the loop, while each sweep begins by clearing the tape.
> Clearing returns the derivative-slot counter to zero, so every active value that
> outlives a sweep refers to a slot that now belongs to something else. The first
> functional is correct and every later one reads unrelated storage. Measured: rows agree
> with an independent reference for the first metric and, for the later ones, have the
> wrong sign, a magnitude wrong by 180 times, and 33 of the 52 state columns of that configuration exactly zero — a state count, not the 44 parameters. This is
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

**Treat this as the paths found so far, not as a closed set.** The implementation has the
cohort-step term and the introduction term; the census direct term is section 9's gap and
the light reduction is section 6.1's. Whether the water reduction and the initial condition
are implemented has not been established — reading `Patch::ode_rates_adjoint` and
`TF24_Environment::compute_rates_adjoint` against section 6.2 would decide it.

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
| 6 | Transport derivatives differenced across a grid whose knot count moves | 7.6 |
| 7 | $\Pi_{pu}$'s parameter half differenced, conditioning unmeasured | 7.3 |
| 8 | Consumption adjoint not the transpose of a sorted forward grid | 6.2 |
| 9 | $\partial h_0/\partial\varphi$ imposed zero on both AD paths; no available reference | 10.1 |

Items 1 to 3 are missing summations or misplaced constructions and each is a small
change. Items 4 and 5 are missing guards. Items 6 and 7 replace a difference with
algebra this document gives in closed form. Item 8 is a transpose that stopped matching
its forward function. Item 9 is the only one that needs a new instrument before it can
be closed, and it is therefore the only one whose scope is genuinely open.
