# Reverse-mode differentiation of the TF24 model: the variables, the intermediaries, and the transposes

This document states the mathematics of the reverse-mode trait gradient for the TF24 size- and
trait-structured model. Report 00 states the dependency structure and walks the flow in prose;
this states the derivatives.

It is written to stand on its own, and it names no code deliberately. Nothing here tracks what has
been built or where an implementation departs from the algebra below; that is a different kind of
claim, with a different lifetime, and mixing the two is what makes a document like this go stale.
What is here is what the derivatives *are*, and what a correct implementation of them must satisfy.
Where it disagrees with the code, one of them is wrong and the disagreement is the finding.

---

## 1. What is being differentiated, and why the structure matters

The model carries a density of individuals over a size coordinate, for each of $S$ species,
coupled to a shared light field and a shared soil water column. The solver advances a state
vector $y(t)$ by an embedded Runge–Kutta method, and inserts new degrees of freedom as cohorts
are introduced, so $\dim y$ grows during a run.

We want

$$\nabla_\varphi \mathcal{C}, \qquad \mathcal{C} = \mathcal{C}\big(y(T), \varphi\big)$$

a scalar summary of the stand at time $T$ — a census — where $\varphi \in \mathbb{R}^{P}$ collects
the trait and physiological parameters. For TF24, $P = 44$ per species.

Three properties of this problem set everything that follows.

**Reverse mode is the only affordable direction.** A forward tangent costs one solve per component
of $\varphi$; the adjoint costs one solve plus one sweep regardless of $P$. With $P = 44$ that is
the difference between a feasible computation and an infeasible one.

**One layer of the model is an implicit function.** Each individual's carbon gain is the value of a
maximisation over its own stem water potential, solved numerically. Differentiating through the
solver is neither necessary nor accurate; the envelope theorem and the implicit function theorem
give the derivatives in closed form, and section 7 does that.

**The state grows.** An introduction widens $y$, so the adjoint is not a single backward solve over
a fixed space but a sequence of backward segments, each narrower than the one after it.

---

## 2. Notation

Every quantity below is either a state, a parameter, or an intermediary.

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

**$p$ is the stem water potential throughout, never a parameter index.** Section 7's $\Pi_{pp}$ and
$\Pi_{pu}$ depend on that reading. Other symbols carry more than one meaning across sections: $s$
is a species index and also the scalar of section 7.2; $b$ and $c$ are a birth date and a growth
rate index in this section and the vulnerability-curve parameters in section 7.6; $a$ is a
Runge–Kutta coefficient, a heartwood area, an allometric constant and $1/c$. Read them by section.

### State

| Symbol | Meaning |
|---|---|
| $h_k$ | height of cohort $k$ |
| $\ell_k = \log n_k$ | log of the density carried by cohort $k$ |
| $b_k$ | the time cohort $k$ was introduced |
| $\mu^{\mathrm{cum}}_k,\ F_k$ | cumulative mortality and cumulative fecundity |
| $m^{\mathrm{hw}}_k,\ a^{\mathrm{hw}}_k$ | accumulated heartwood mass and area |
| $r_k$ | non-structural carbon reserve |
| $\theta_j$ | water content of layer $j$ |
| $\psi_j$ | water **potential** of layer $j$, through the retention curve $\psi_j = \psi(\theta_j)$ |
| $y$ | all of the above, species-major |

**The density is carried alongside a cohort's own state, not inside it.** $\ell_k$ is a property of
the cohort as a quadrature node; the six states an individual integrates are height, cumulative
mortality, cumulative fecundity, the two heartwood accumulators and the reserve. Section 5 depends
on this distinction: $\ell_k$ is not an input to the recorded step, and $\dot\ell_k$ is one of its
outputs.

**The recorded step reads soil *potentials*, not water contents.** The retention curve is
evaluated before the step, so $\psi_j$ is what a cohort sees and $\partial\psi/\partial\theta$ is a
factor the reverse pass must supply between the two.

The quadrature abscissa is

$$x_k = \begin{cases} b_k & \text{birth-date coordinate} \\ -h_k & \text{height coordinate} \end{cases}$$

It increases with $k$ in both cases *given the ordering convention* — for $-h_k$ only because a
larger $k$ is younger and therefore shorter, which is the convention section 6 shows breaking. The
reverse-mode gradient is scoped to the birth-date coordinate, where $x_k = b_k$ is fixed at birth
and carries no derivative. This is the single most consequential simplification in the design and
sections 5.1 and 6.1 show why.

### Intermediaries

| Symbol | Meaning |
|---|---|
| $A_k$ | leaf area of cohort $k$, $(h_k/a_{l1})^{1/a_{l2}}$ |
| $E^{\mathrm{comp}}(z)$ | competition experienced at height $z$ |
| $\Lambda_q,\ \Lambda'_q$ | the light field's knot values and slopes |
| $p^\star_k$ | the maximising stem water potential |
| $\Pi_k$ | carbon profit at the optimum |
| $U_{kj}$ | water cohort $k$ draws from layer $j$ |
| $\kappa_k$ | maximum leaf-specific conductance |
| $c^{\mathrm{i}}_k$ | intercellular CO₂, itself a root of a residual |
| $G(\cdot)$ | cumulative vulnerability integral |
| $g_k,\ \mu_k$ | height growth rate, mortality rate |
| $w_k$ | the quadrature weight cohort $k$ carries on the abscissa $x_k$ |
| $z,\ z_q$ | the vertical coordinate, and the knot heights |
| $\tilde Q(\nu)$ | fraction of a crown's leaf area above the relative height $\nu$ |
| $\eta$ | how top-heavy a crown is |
| $k_I$ | light extinction through a unit of leaf area |
| $\mathcal{C}$ | the scalar summary being differentiated |
| $\mathfrak{m}$ | the per-individual quantity the census sums |
| $\varphi$ | the differentiable parameters, $P = 44$ |

---

## 3. The forward model as a composition

Within one evaluation of the rates at one time, the model is a directed acyclic graph. Writing it
as a composition is what makes the transpose mechanical.

$$\varphi \;\xrightarrow{\ (a)\ }\; \text{strategy} \;\xrightarrow{\ (b)\ }\; \{A_k, \kappa_k\} \;\xrightarrow{\ (c)\ }\; \Lambda \;\xrightarrow{\ (d)\ }\; \{p^\star_k, \Pi_k, U_{kj}\} \;\xrightarrow{\ (e)\ }\; \dot y \;\xrightarrow{\ (f)\ }\; \mathcal{U}_j$$

- **(a) strategy preparation** derives the strategy's dependent quantities from $\varphi$: the
  crown-shape constant, the seed height, the seed leaf area, and the derived hydraulic quantities.
  It runs once, before the trajectory, and section 10.1 treats the consequences of where its
  derivatives go.
- **(b) allometry** gives each cohort's size-dependent quantities from $h_k$ and $\varphi$.
- **(c) the light reduction** aggregates over cohorts to give the shared field.
- **(d) the individual** solves its own maximisation given the field. This is the only implicit
  step, and it is per-cohort independent.
- **(e) assembly** writes the rates back into $\dot y$.
- **(f) the water reduction** sums every cohort's per-layer consumption into one number per soil
  layer and hands it to the soil's own rate equation.

**There are two reductions, not one, and they sit on opposite sides of the individual.** The light
reduction is upstream of (d) — cohorts build a field and then read it. The water reduction is
*downstream*, because per-layer consumption is an output of the individual's maximisation. The
diagram $\{p^\star,\Pi,U\} \to \dot y$ hides it. Both scatter on transposition, and a reverse pass
that handles only the upstream one is incomplete rather than approximate.

The important structural fact is that (c) and (f) are reductions and (d) is per-cohort
independent. So the reverse pass is: transpose (f) once, scattering each layer's adjoint back over
every cohort; transpose (e) and (d) cohort by cohort; then transpose (c) once, scattering the
field's adjoint back over every cohort.

---

## 4. The discrete adjoint of the solver

Let the solver advance $y_n \mapsto y_{n+1}$ by

$$Y_i = y_n + \Delta t_n \sum_{l<i} a_{il} k_l, \qquad k_i = f(Y_i, \varphi, t_n + c_i \Delta t_n),$$

$$y_{n+1} = y_n + \Delta t_n \sum_i \beta_i k_i .$$

Given the adjoint $\bar y_{n+1}$ of the state after the step, the step's transpose is

$$\bar k_i = \Delta t_n \beta_i \bar y_{n+1} + \Delta t_n \sum_{l>i} a_{li} \bar Y_l, \qquad \bar Y_i = \left(\frac{\partial f}{\partial y}\Big|_{Y_i}\right)^{\!\top} \bar k_i,$$

swept for $i$ descending, and then

$$\bar y_n = \bar y_{n+1} + \sum_i \bar Y_i, \qquad \bar\varphi \mathrel{+}= \sum_i \left(\frac{\partial f}{\partial \varphi}\Big|_{Y_i}\right)^{\!\top} \bar k_i . \tag{4.1}$$

Four consequences an implementation must respect.

**The step size is held.** $\Delta t_n$ was chosen by the adaptive controller using an error
estimate. Treating it as a differentiable function of $\varphi$ would differentiate the
controller, which is not the model. So $\Delta t_n$ is a recorded constant on the reverse pass, and
a recorded trajectory must store its step sizes rather than recompute them.

**A rejected step contributes nothing.** The controller's rejected attempts are not part of the
trajectory. Excluding them is exact, not an approximation: the state and time are restored, so
neither the trajectory nor any first-same-as-last carry is affected.

**Two stage accumulators start empty, and it is the output weights that vanish, not the abscissae.**
In the Cash–Karp pair $\beta_2 = \beta_5 = 0$, so those two stage sums begin with no terminal
contribution. **No abscissa is zero.** The distinction matters because the two enter (4.1)
differently: a vanishing **weight** still couples through the $a_{li}$ sum, so the stage is not
inert, whereas a vanishing **abscissa** would change where $f$ is evaluated. An implementation that
seeds these accumulators from the abscissae is wrong in a way no test on a smooth problem detects.

**$\bar\varphi$ accumulates over every step and every stage, and over the introduction boundaries
of section 4.1.** There are $6M$ contributions from (4.1) and one per introduction. Both sets are
required; the trait accumulator has two distinct sources and not one.

### 4.1 Introductions: the state changes dimension

Let the run have widths $d_1 < d_2 < \dots < d_B$ over $B$ segments, with an introduction between
consecutive segments. The adjoint sweeps segment $B$ first. At the boundary between segment
$\sigma+1$ and segment $\sigma$, the newly introduced components carry the boundary condition

$$\ell_{\text{new}} = \begin{cases}
\log\!\big(\text{birth\_rate}\cdot\text{pr\_estab}\big) & \text{birth-date coordinate} \\
\log\!\big(\text{birth\_rate}\cdot\text{pr\_estab}\,/\,g\big) & \text{height coordinate}
\end{cases} \tag{4.2}$$

**The division by the growth rate is the height branch only.** On the birth-date coordinate nothing
moves an individual along the abscissa, so the boundary condition is simply the seed arrival times
the establishment probability. The coordinate the gradient runs on is the one without the division.

An introduction also writes the newcomer's height, zeroes its heartwood accumulators, and sets its
initial reserve $r_0 = a_{st3} S_{\max}$, which reads $\varphi$. Equation (4.2) is the density slot
alone; the reserve channel is a second, independent read of $\varphi$ at the same boundary.

**The newcomer's rows are not a function of $\varphi$ alone.** The introduction is evaluated at the
pre-introduction state: the field is rebuilt and the boundary node is placed in it, so the
newcomer's own quantities depend on the state before the introduction as well as on the traits.
Both halves of that derivative are required —
$\partial(\text{newcomer})/\partial y_{\text{before}}$ joins the segment's state adjoint, and
$\partial(\text{newcomer})/\partial\varphi$ joins $\bar\varphi$. An implementation written as
though the newcomer "has no predecessor in $y$" drops the first half entirely.

**The widening is interleaved, not appended.** Newcomers sit at the end of each species' node
block, so introducing into species $s$ shifts every later species and the environment by one node
stride. A narrowing implemented as a truncation of the tail is wrong for every species but the
last.

**Each metric's sweep needs the pre-step states rebuilt.** The states each segment's first step ran
from are not part of the recorded trajectory, so before sweeping, the run must replay every
introduction forward to recover them — and again afterwards, to leave the system repeatable. The
segment picture is not implementable without that replay.

*Requirement.* The narrowing must be applied to every column when several functionals are swept
together, and the segment list must cover every recorded step with no gap. An empty segment list is
not an insensitive stand: it is a sweep that never ran, and the two must be distinguishable.

---

## 5. The recorded cohort step

The unit of the reverse pass is one evaluation of one cohort's physiology at one Runge–Kutta stage.
Its inputs are

$$u_k = \big(\underbrace{h_k,\ \mu^{\mathrm{cum}}_k,\ F_k,\ a^{\mathrm{hw}}_k,\ m^{\mathrm{hw}}_k,\ r_k}_{\text{6 own states}},\ \underbrace{\Lambda, \Lambda'}_{\text{field},\ 2K},\ \underbrace{\psi_{1:L}}_{\text{soil potentials}},\ \underbrace{\varphi}_{P}\big)$$

and its outputs are

$$v_k = \big(\underbrace{\dot h_k,\ \mu_k,\ \dot F_k,\ \dot a^{\mathrm{hw}}_k,\ \dot m^{\mathrm{hw}}_k,\ \dot r_k}_{\text{6 rates}},\ \underbrace{\dot \ell_k}_{\text{density rate}},\ \underbrace{U_{k,1:L}}_{\text{consumption}}\big).$$

At $K = 65$ knots and $L = 5$ soil layers,

$$6 + (2\cdot 65 + 5) + 44 = \mathbf{185}\ \text{inputs}, \qquad 6 + 1 + 5 = \mathbf{12}\ \text{outputs}.$$

**Both counts are configuration-dependent** — they move with the knot count and the layer count —
and neither is a property of the model. What is a property of the model is the *shape*: the input
vector is dominated by the field, and the output vector is six rates, one density rate and one
consumption vector. **The knot count is a compile-time constant, so $K$ does not vary within a run.**

**One rate the stand's fitness is measured from sits outside this block.** The survival-weighted
offspring rate is a cohort-level state whose rate reads the fecundity rate, the cumulative mortality
*state* and the patch survival ratio. It is correctly not one of the twelve outputs, because the block
stops at one individual's physiology. **But a fitness functional's seed does not reach it through the
twelve either** — so a seed built from the six rates, the density rate and the consumption vector
cannot express a question about fitness. That is a limit on what this block can be seeded for, and it
is not a missing output.


### 5.1 The density rate is where the coordinate choice bites

On the birth-date coordinate,

$$\dot \ell_k = -\mu_k, \tag{5.1}$$

whereas on the height coordinate the density is compressed by the growth of the size axis and

$$\dot \ell_k = -\mu_k - \frac{\partial g}{\partial h}\Big|_{h_k}. \tag{5.2}$$

Equation (5.2) is why the height coordinate is expensive to differentiate: $\partial g/\partial h$
requires further solves of the whole individual at displaced heights. A one-sided difference reuses
the rate already computed and costs **one** extra solve; Richardson extrapolation at depth four
costs **eight**. Equation (5.1) needs none of them, because $\mu_k$ is already an output of the
same step.

So the birth-date coordinate removes one extra individual solve per recorded step, or eight under
Richardson. **That is a solve count and not a statement about tape size**; the two are different
quantities.

### 5.2 The field's inputs reach the leaf through one number

This is the economy that makes the design affordable.

A cohort's whole physiology is driven by a **single** scalar derived from the field: the light at
its crown centre, or the leaf-area-weighted mean over its crown, depending on the shading model.
Both supported modes reduce the field to one number before any physiology runs. A third mode,
which photosynthesises at each crown depth and averages afterwards, has no derivative and is
unavailable at an active type.

Therefore for any leaf output $v$,

$$\frac{\partial v}{\partial \Lambda_q} = \frac{\partial v}{\partial \mathcal{R}}\cdot\frac{\partial \mathcal{R}}{\partial \Lambda_q}, \tag{5.3}$$

where $\mathcal{R}$ is the one scalar the physiology receives. So the $12 \times 2K$ block is
$12 + 2K$ numbers rather than $24K$ — **rank one for the leaf's outputs.**

**Rank one is exact on the birth-date coordinate and false on the height coordinate.** On the
height coordinate the density-rate output of (5.2) evaluates the physiology a second time at a
displaced height, and that second evaluation makes its own field query at a different position —
under the mean-light mode, an integral to a different upper limit, which is not a multiple of the
first. So the block has rank at least 2 there, and up to 9 under Richardson at depth four. The
coordinate choice buys the factorisation as well as the solve.

**The scalar the physiology receives is not the field value.** It is the field value scaled by the
extinction coefficient $k_I$ and the incident radiation, and floored away from zero. So the
coupling carries a registered parameter and an extrinsic driver as well as the field, and the floor
severs the row wherever the field is in deep shade. Section 6.1 develops the sparsity of
$\partial\mathcal{R}/\partial\Lambda_q$, which differs between the two modes.

### 5.3 Two states of a cohort are flat, and one of them is where drought lives

Two regimes of the cohort's own dynamics have no derivative to compute, and both matter for
interpreting a gradient rather than for building one.

**The reserve deficit is an absorbing flat region, not a draining one.** The reserve enters the
outflow gate already clamped at zero, and the gate is built from that clamped value, so at a
negative reserve the gate is exactly zero and the reserve's own rate is exactly zero. The state
sits where the overshoot left it; mortality is pinned at its maximum; and **every** derivative out
of the reserve state vanishes — both $\partial r/\partial S$ and
$\partial(\mathrm{d}S/\mathrm{d}t)/\partial S$ — until net production turns positive and releases
it at full rate.

**But the cohort does not go gradient-dark there.** The leaf's rows feed two channels and only one
is flat. Growth flux is positive production times a reserve gate that is bounded away from zero,
and the height, fecundity and both heartwood rates all read it, with the positive part's derivative
equal to $\tfrac12$ at zero production. **So the interior-case rows are neither wasted nor wrong at
a frozen cohort: they are the only live channel out of it.**

**The frozen set and the negative-production set coincide by algebra, on any driver.** Release
needs $P - G(0)\,P_{\text{pos}} > 0$, which for positive $P$ is immediate. So $\{S \le 0\}$ and
$\{P \le 0\}$ agree up to a measure-zero transient — not as a coincidence of one driver, but
forced. A drought raises the fraction one-for-one, which means **differentiating a drought is
differentiating a flat region.** For a gradient this is worse than a draining state, which at
least has self-sensitivity.

**Establishment is stiff, not discontinuous, and needs no smoothing.** The establishment
probability is $P^2/(P^2+k^2)$ times a decay above threshold and zero below. As $P \to 0^+$ both
the value and the first derivative tend to zero, so it is $C^1$ at $P = 0$ and the zero arm is its
correct $C^1$ extension. Mollifying it would be actively harmful: the biology's own transition
scale is narrower than any smoothing width the model uses elsewhere, so a mollifier would widen a
transition the model already resolves and change recruitment. What is true is a conditioning fact:
the derivative peaks at $0.65/k$ at $P = k/\sqrt3$.

**The apparent singularity at a marginal recruit is a coordinate artefact, and it tells you where
the seed goes.** Both the cumulative mortality and the log density diverge logarithmically as
$P\to0^+$, and $\partial\ell/\partial P = 2/P \to \infty$. But $\ell$ reaches everything downstream
only through $n = e^{\ell}$, and on either coordinate $\partial n/\partial P = 2P/k^2 g \to 0$,
with $g$ bounded away from zero. So $n$ and $\partial n/\partial\varphi$ are both $C^1$ and both
tend to zero, the census carries $n$ linearly, and every census gradient through a marginal recruit
exists, is finite, and tends to zero from both sides. **The zero belongs in the derivative:** a
recruit that cannot pay for itself contributes $O(P^2)$, so exactly zero is the correct first-order
answer.

The implementation consequence is a rule about where to seed, not a guard: **seed the boundary
node's adjoint in $n$ rather than in $\ell$.** The seed $n\,\partial\ell/\partial\varphi$ is
$0\cdot\infty$ and must be evaluated as $\partial n/\partial\varphi$.

---

## 6. The environment reductions and their transposes

### 6.1 Light

The competition profile at height $z$ sums over every cohort of every species:

$$E^{\mathrm{comp}}(z) = \sum_s \sum_k w_k \, n_k \, k_I^{(s)} \, A_k \, \tilde{Q}\!\left(\frac{z}{h_k}\right), \tag{6.1}$$

where $\tilde{Q}(\nu) = (1 - \nu^{\eta})^2$ for $\nu \le 1$ and $0$ above, and $w_k$ are the
trapezium weights on the abscissa $x_k$. The field is then a spline through $K$ knots, so the
recorded cohort step reads $(\Lambda_q, \Lambda'_q)$ and not $E^{\mathrm{comp}}$ directly.

Given knot adjoints $\bar\Lambda_q$, the transpose of (6.1) scatters:

$$\bar\ell_k \mathrel{+}= \sum_q \bar\Lambda_q \, w_k \, n_k \, k_I \, A_k \, \tilde{Q}(z_q/h_k) \tag{6.2}$$

$$\bar h_k \mathrel{+}= \sum_q \bar\Lambda_q \, w_k \, n_k \, k_I \left[ A_k' \, \tilde{Q}(z_q/h_k) - A_k \, \tilde{Q}'(z_q/h_k) \frac{z_q}{h_k^2} \right] \;+\; \underbrace{\sum_q \bar\Lambda_q \, n_k \, k_I A_k \tilde{Q} \, \frac{\partial w_k}{\partial h_k}}_{\text{zero on the birth-date coordinate}} \tag{6.3}$$

$$\bar{k}_I^{(s)} \mathrel{+}= \sum_q \bar\Lambda_q \sum_{k \in s} w_k \, n_k \, A_k \, \tilde{Q}(z_q/h_k) \tag{6.4}$$

$$\bar\eta^{(s)} \mathrel{+}= \sum_q \bar\Lambda_q \sum_{k \in s} w_k \, n_k \, k_I^{(s)} A_k \, \frac{\partial \tilde{Q}}{\partial \eta}, \qquad \frac{\partial \tilde{Q}}{\partial \eta} = -2(1-\nu^{\eta})\,\nu^{\eta}\log\nu \ \ (\nu \le 1),\ \ 0 \text{ above} \tag{6.5}$$

$$\bar{a}_{l1},\ \bar{a}_{l2} \mathrel{+}= \sum_q \bar\Lambda_q \sum_{k \in s} w_k \, n_k \, k_I^{(s)} \, \tilde{Q}(z_q/h_k)\,\frac{\partial A_k}{\partial (a_{l1}, a_{l2})}\bigg|_{h_k} \tag{6.6}$$

**$k_I$ and $\eta$ are per-species, so each sum runs over that species' cohorts only.** Summing
over every cohort of every species collapses the species into one scalar.

**Equations (6.4) to (6.6) are trait contributions that arise *inside* the reduction, not inside
any cohort step.** This is the structural point of the section. Four parameters reach the census
through the field build: the extinction coefficient, the crown shape, and the two allometric
constants that set leaf area at fixed height. The allometric pair is the subtle case, because it
*also* has a live path through the cohort step and through the size-space adjoint — so the
reduction's contribution is an addition to a non-zero row rather than the whole of it. Equation
(6.6) is the explicit $\partial A/\partial a_{l1}$, $\partial A/\partial a_{l2}$ at fixed height,
which is a different object from the chain $\partial A/\partial h$ that a size-space adjoint
carries.

**The right-hand sides of (6.4) to (6.6) are already formed as intermediate products inside the
value transpose.** What a correct implementation needs here is a summation, not a derivative.

**The slope channel is a further set of terms.** Section 5 lists $(\Lambda, \Lambda')$ as $2K$
inputs, so the transpose must also contract $\bar\Lambda'_q$ against

$$\partial_z E^{\mathrm{comp}}(z_q) = \sum_s \sum_k w_k \, n_k \, k_I^{(s)} A_k \, \tilde{Q}'(z_q/h_k)\,\frac{1}{h_k}, \tag{6.7}$$

whose $h_k$ transpose carries a $\tilde{Q}''$ term appearing nowhere in (6.3), and whose parameter
transposes are the slope analogues of (6.4) to (6.6).

**And one channel is easy to miss entirely: the boundary condition's own leaf area.** The newcomer
of section 4.1 is evaluated in a field built *without* it, so its seed leaf area reaches the census
through a field it does not contribute to. That is a distinct path from (6.2) to (6.7) and needs
its own transpose.

#### The transposes must follow the coordinate the forward integrates over

The braced term in (6.3) is the weight-derivative term. It exists only because the height
coordinate makes the quadrature abscissa a function of the state. On the birth-date coordinate
$x_k = b_k$ is fixed at birth and passive, so $\partial w_k/\partial h_k = 0$ and the term
vanishes.

**This is a requirement on four separate quantities, and it is easy to satisfy three and miss the
fourth.** A reduction transpose on the birth-date coordinate must:

1. build its trapezium **widths** from birth dates, not heights;
2. omit the weight-derivative term of (6.3) entirely;
3. apply the closing boundary trapezium under the same coordinate condition;
4. test *abscissa* monotonicity rather than height monotonicity when deciding whether to refuse.

The fourth is the one that inverts the failure. Reserve-gated growth lets a younger cohort overtake
an older one, so heights can be non-monotone while birth dates cannot. A guard testing height
order refuses exactly where the forward model runs correctly — and on the birth-date coordinate
crossing is *more* common, not less. A transpose satisfying (1) to (3) and failing (4) is a
transpose that stops on the coordinate it was built for.

**A transpose that is not the transpose of its forward function must be repaired before it is
extended.** Adding the parameter rows (6.4) to (6.6) to a transpose whose widths and guards are
wrong produces wrong rows in the new channel with no signal distinguishing which of the two
defects produced them. Order matters here and it is the reverse of the intuitive one: fix the
transposes, then extend them.

#### What the reduction's structure buys

Two facts about (6.1) that matter downstream.

**The transpose is triangular or banded, not dense.** Equations (6.2) to (6.7) are written as sums
over every cohort, but $\tilde Q$ vanishes above a cohort's own height. Under the mean-light mode
only cohorts taller than knot $q$ contribute, so the reduction is triangular; under crown-centre
only the cohorts whose crown brackets the knot do, so it is banded.

**The recorded step's dependence on the field is sparse, and bounded by the quadrature rule rather
than by the cohort's height.** The field's slopes are **supplied, not solved**: the reduction
evaluates a value and a slope at each knot, and the interpolant stores both as given. So it is a
Hermite interpolant with genuinely local support, and a query inside one span reads exactly two knot
values and two slopes — **four non-zeros.** A crown integral under a fixed $n$-point rule touches at
most $n$ spans, so at most $n+1$ values and $n+1$ slopes; the bound is twice the rule's point count
where the field is read twice per step, and it does **not** grow with height.

> **This sparsity is a property of the recorded step's inputs, and that qualification is
> load-bearing.** An *interpolating* spline — one that solves a tridiagonal system for its slopes —
> has no local support at all: every knot value influences every query, decaying geometrically. Such
> a spline makes "four non-zeros" false, and the distinction is not academic, because this model
> contains both kinds. The vulnerability tabulation is the solved kind. **The light field is not.**
>
> The composed dependence on *cohort state* is a different object and it is **not** four-sparse,
> because each supplied slope is itself a reduction over every cohort. Section 5 lists
> $(\Lambda, \Lambda')$ as $2K$ independent inputs, and the sparsity claim is about the Jacobian with
> respect to **those**. Report 07 §1 exploits it at that boundary, which is where it holds.


**The value of the field is robust; its slope is what ceases to exist.** $E^{\mathrm{comp}}$ is
continuous in its own arguments everywhere it is evaluated — at the crown-top cutoff, at the
canopy cap where leaf area is exactly zero, across the boundary-interval switch, and at the ground
knot for every $\eta$. Each of those is a $C^1$ join where value *and* slope vanish exactly, so
dropping the branch indicator's derivative is **exact** rather than an approximation. The
consequence for an interface is that a value accessor must keep working when a slope accessor
refuses; pairing them forces a forward model with no derivative problem to stop.

**Two structural hazards live on one lever, and it is a registered parameter.** The crown shape
satisfies $\tilde Q(0) = 1$ for every $\eta$, so the field's minimum over its whole domain is at
the ground and equals $\exp(-k_I\,\mathrm{LAI})$. A floor on the light therefore binds when
$k_I\,\mathrm{LAI}$ exceeds the floor's log — and the same lever drives the interpolant's
monotonicity guard, because the ground knot's slope is exactly zero for $\eta > 1$, so the first
span undershoots once the knot values fall far enough. **Both fire under one parameter change, and
$k_I$ is a free parameter a gradient-driven search will walk.** Where either binds, the severance
is an artefact of the guard and not a property of the model, because the field is smooth there. The
honest treatment is to refuse the slope row with its incidence counted, not to return a clamped
zero. **The crown shape is not a lever here**: $\eta$ reshapes the profile and leaves the
ground-level value untouched.

**One consequence for the model's own consumer.** A calibration or an ascent run that walks $k_I$
upward walks the field into the region where the row it is ascending goes to zero. That is a
hazard class the rest of this document does not have: the gradient's consumer driving the model
into the region where the gradient is wrong.

### 6.2 Water

Total draw from layer $j$ aggregates the same way,

$$\mathcal{U}_j = \sum_s \sum_k w_k \, n_k \, U_{kj}, \tag{6.8}$$

and the soil state responds through the retention curve $\psi_j = \psi(\theta_j)$. Its transpose
scatters $\bar{\mathcal{U}}_j$ back onto $\bar U_{kj}$, $\bar \ell_k$ and, on the height
coordinate, the weights. Every requirement of section 6.1's coordinate discussion applies here
unchanged.

**The retention curve's derivative must be supplied between the layer's state and the cohort's
read.** The recorded step reads potentials; the state carries contents. So the reverse pass
multiplies the incoming adjoint by $\partial\psi/\partial\theta = -n_\psi\psi/\theta$, which is
zero in both clamped regions, consistently with the forward's floor and cap. **This is a
hand-supplied derivative beside a passive forward function, and nothing structural enforces the
pairing** — the pattern is correct where it is written and is the shape of a defect wherever it is
omitted. The introduction boundary of section 4.1 is the place it is most easily omitted, because
establishment is the most moisture-sensitive event in the life cycle and a boundary node that takes
its potentials from a cache has no visible dependence on moisture at all.

**The soil's own parameters need rows and the model gives them nowhere to go.** The saturated
conductivity, the retention curve's scale and exponent, the saturation and residual contents, the
potential ceiling, and the infiltration constants are properties of the environment rather than of
any strategy, so they appear in no parameter list. With per-layer vectors that is $4L$ parameters
with no derivative row, and the consequence is a question that cannot be asked: **"what if the soil
were sandier."** The vertical structure of the root coupling is in the same position.

#### Three facts about the soil that change how its clamps read

**The profile drains, and that cascade is where a deep layer's water comes from.** Each layer's
inflow is the conductivity of the layer above it, so water moves down the column explicitly. Rain
enters at the top and reaches depth by drainage, with no plant involved. Measured on a mature stand,
the median inflow to the deepest of five layers is about $0.10\ \mathrm{m\,yr^{-1}}$ against
$6\times10^{-7}$ of uptake — **five orders of magnitude, in favour of drainage.**

**"Conductivity is negligible at operating moisture" is an artefact of where the ratio was taken.**
Conductivity is $K_{\text{sat}}(\theta/\theta_{\text{sat}})^{2n_\psi+3}$ with the exponent about
**16**, so it spans many orders over the moisture range and no single value characterises it. Taken
at the half-saturated state the model is *initialised* in, the ratio to the rainfall forcing is
small — but the model leaves that state within weeks, and at the free-drainage steady state the
definition settles it: $K(\theta_{\text{eq}})$ **is** the rainfall, so the operating ratio is **1**.
Measured: five layers rise from 0.250 to 0.311 in 0.14 yr with total uptake still $4\times10^{-5}$,
which is drainage filling the profile while the plants are irrelevant to it.

So the layers are **not** independent buckets, and any argument resting on their being so — including
the reading that a deep layer's only resupply is a plant pushing water into it — does not hold.

**Hydraulic redistribution is real and deliberately coded, and it is rare and runs downward.** It
occurs on a small minority of steps and carries a vanishing share of total uptake, it is absent
altogether from wet and seasonal runs, and where it occurs it moves water **down** into dry
mid-profile layers under gravity head. It is not deep roots lifting water to a dry surface, and an
ecological reading built on that picture is describing a different model.

**What survives, and it is the instrument point rather than the ecology.** Redistribution needs no
branch, because the same smooth expression covers a negative per-layer flux — and **a statistic
formed on the total uptake cannot see it**, because signed per-layer fluxes sum. That is a claim
about what a measurement can detect, and it holds whether the phenomenon is common or rare. Its
derivative exists in closed form, and its relative accuracy under any differencing scheme is the
worst in the model, precisely because the output *is* the residue of a near-cancellation.


**The root vulnerability integral is bounded above by its own closed-form limit, and that ceiling is
a requirement rather than a guard.** The integral is read from a grid ending where the vulnerability
function reaches a small positive value, and a natural-boundary spline extrapolates past its last
knot with the slope *at* that knot — positive, for this integral. Unbounded, the lookup keeps
growing past its grid instead of approaching its limit; the mean root resistance then saturates, and
a flux with a numerator growing linearly in the layer's potential over a bounded denominator grows
linearly and **negative**: flow from plant to soil, without limit. The complete gamma with the same
prefactor is the value the integral *has* out there rather than an approximation to it, so capping
the value at it is continuous, monotone, and identical to a bare lookup everywhere on the grid.

**The reason it is a requirement is that every net which would catch its absence is the wrong net.**
The flux is **finite**, so a finiteness test passes. Total uptake is a **sum over layers**, so a
positive total hides it. And a negative depletion makes the layer's rate positive, so a positivity
guard permits it. **A dry layer is the route, and it is the only one** — the leaf's own feasible
bracket does not reach past the root grid, because the dry bound is the **lesser** of the two
critical potentials and therefore sits inside it (§7.3). Whole-plant shutdown is decided on the
**wettest** layer, so a wet top layer over a sufficiently dry one below is a live plant whose
deepest layer is out on the extrapolation, and a drying profile produces exactly that arrangement.

**The two clamps are one behaviour.** The potential ceiling always binds before the residual
content floor, because at the floor the retention curve gives a potential many orders of magnitude
past the ceiling. So the floor is invisible and the ceiling is the only clamp with incidence.

**And the clamped derivative is right for the soil and wrong for the loop.** An analytic zero at
the clamp correctly carries soil → plant. The plant → soil direction runs through the uptake
adjoint, which no clamp touches. So at the ceiling the feedback is cut in exactly one direction: a
plant can go on changing a capped layer's moisture and the layer can never signal back.

**Two windows are removable and must not be refused.** Equal potentials across a layer boundary is
the l'Hôpital limit of a span over an integral, continuous in value. A gravity-balanced layer has a
numerator that vanishes while its derivative does not. Both have derivatives; refusing them
discards a defined answer.

---

## 7. The individual's maximisation

This is the mathematical core. Each cohort chooses a stem water potential $p$ to maximise profit,

$$p^\star = \arg\max_{p \in [p_a, p_b]} \Pi(p; u), \qquad \Pi = A\big(c^{\mathrm{i}}(p; u)\big) - \Theta(p; u),$$

with $A$ the assimilation and $\Theta$ the hydraulic cost. Everything downstream — profit, uptake,
and hence growth — is evaluated at $p^\star$, which is obtained numerically from the condition that
defines it. We need derivatives of quantities at $p^\star$ with respect to every input $u$,
**without differentiating the solve that found it** — and, equally, without obtaining $p^\star$ by a
method that determines it less precisely than those derivatives require. Report 02 §1 states why
that second requirement rules out searching the objective.

### 7.0 Five kinds of point, and the taxonomy is the sensitivity theory

Sections 7.1 to 7.6 derive the sensitivity of an interior stationary maximum and of a pinned bound.
Those are **two** kinds of point and the model admits **five**. The three that are missing are the
dangerous ones, because in each the wrong theory returns a finite number rather than failing.

| | kind of point | the profit row | the uptake row |
|---|---|---|---|
| **S** | interior stationary maximum, $\Pi_{pp}<0$ | envelope: $\partial\Pi/\partial u$, free | IFT on $R=0$: $m = -s/\Pi_{pp}$, then $m\,\Pi_{pu}$ |
| **K** | constrained optimum, one bound active, multiplier $\nu = \lvert R\rvert$ | **not** an envelope: $\partial\Pi/\partial u + \nu\,\partial B/\partial u$ | $\partial E_i/\partial u + (\partial E_i/\partial p)\,\partial B/\partial u$ |
| **B** | a feasible point that is not an optimum, still solving a relation in $u$ | plain chain rule; the $p$-channel is the substituted expression's own derivative | same form as K, with $\partial p/\partial u$ from the bound |
| **X** | exogenous operating point — solves no optimisation | a substituted constant, or an ODE state: closed form in a strict subset of inputs, **exactly zero** in the rest | identically zero under shutdown; at a tracked potential, the row at fixed $p$ plus a tracking row |
| **N** | no derivative exists — a fold, a jump, or nothing defined | valid at a fold, one-sided at a jump, absent otherwise | **does not exist** |

#### The table is an outer product, and writing it out hides which axis each entry is on

Every entry above is one instance of the same chain rule. For an output $y_j$ evaluated at the
operating point,

$$\frac{\mathrm{d}y_j}{\mathrm{d}u} \;=\; \underbrace{\frac{\partial y_j}{\partial u}\bigg|_p}_{\text{held}} \;+\; \frac{\partial y_j}{\partial p}\,\frac{\partial p^\star}{\partial u}, \tag{7.0}$$

and the two axes of the table above enter (7.0) in **different factors**:

- **What the output *is*** fixes $\partial y_j/\partial p$ and, for one of them, the held term.
  Three cases, and they are properties of the output rather than of the state: the output that **is**
  the objective, the output that **is** the operating point, and every output that merely reads it.
- **What defines the point** fixes $\partial p^\star/\partial u$ and **nothing else**. Five cases,
  one per row of the table above.

So ten entries are three plus five, and the saving is not the arithmetic — it is that a reader can
see which of the two axes an entry belongs to. A single body per kind, with the output cases written
inside it as conditionals, states the same thing in a form where an error on one axis is
indistinguishable from an error on the other.

**One identity crosses the two axes, and it is the exception that decides the interface.** The
objective's $\partial\Pi/\partial p = 0$ is **not** a property of being the objective. It *is* the
interior stationarity condition, so it holds on kind S and nowhere else: at a pin the same output's
$p$-channel is the multiplier $\nu$, and at an exogenous point it is whatever the substitution left.
The envelope theorem is a statement about **S**, and reading it as a statement about the objective is
how a pinned point comes to be priced by the interior condition.

The consequence for anything supplying these rows is sharp. **The objective's $p$-channel must be a
number that is supplied, not an identity that is assumed** — zero at S, $\nu$ at K, and whatever the
substitution gives at X. An interface that lets a consumer infer it from the output's role is correct
at an interior optimum and silently wrong at exactly the states section 7.4 exists for.

**The other two output cases are genuine identities and hold at every kind.** The operating point's
own $p$-channel is exactly one because it *is* $p$, and its held term is exactly zero because a
partial at fixed $p$ cannot move $p$. Neither reads the state, so neither needs a kind.

**The classification must be a decision tree on what defines the point, never a comparison on the
residual.** Ask in order: did the solve fail to produce a feasible bracket at all (→ X or B, by
which exit); is the operating point a tracked state rather than an argmax (→ X interior, or K when
its clamp binds, never S); is the residual non-finite or the curvature non-negative (→ N, refuse);
is the point interior *and* the marginal-profit evaluation genuinely defined there (→ S); is it at
a bound (→ K).

**Five is the coarsest useful classification and not the natural one.** Three of the five carry an
internal distinction that changes what a caller should do, so a tree that records the branch taken
will find them: **K** splits by *which* bound, since the two endpoints are different functions of
the inputs; **X** splits by *cause* — no tension pays for water, no light pays for respiration, or
feasibility fixed the point with nothing left to optimise — because the first is governed by water,
the second by light, and no rainfall sweep can see the second; and **N** splits by *fault*, an
undefined partial being recoverable where a refused search is not. Reporting the branch is free at
the point of decision and unrecoverable afterwards, which is the whole argument for the tree.

**A small residual is not sufficient for S, and this is the sharpest requirement in the section.**
The marginal-profit function returns a hard sentinel zero in a no-flow or infeasible state. A
convergence test of the form "residual non-finite, or its magnitude within tolerance" cannot
distinguish a sentinel zero from stationarity, so such a state is recorded as an interior optimum.
Then the profit is not stationary, the curvature is zero by the same sentinel, and the argmax
multiplier $m = -s/\Pi_{pp}$ divides by an exact zero with a generically non-zero numerator. **The
test for S must be conjoined with the sentinel's guard evaluating false**, and the guard's own
firing needs a counter.

**And the sentinel's position is structural rather than incidental, which is what makes it
dangerous.** The lower bound of the feasible interval **is** the potential at which total uptake
vanishes — which is exactly the no-flow state the marginal-profit function refuses to differentiate.
So the sentinel does not lurk in the interior waiting to be met: **it sits on one endpoint of the
bracket, by construction, on every solve.** Two consequences follow and they are at different
levels. Any method that evaluates the marginal profit *at* that endpoint is handed a zero that is
not a derivative, so a solve that brackets naively returns the zero-transpiration point as the
optimum — an error in profit of the same order as the profit. And any classifier reaching the same
endpoint inherits the same ambiguity. **A guard placed where the sentinel is produced serves both;
a guard placed at either consumer serves one.**

#### The objective's domain moves with the inputs, and the held partial exists only inside it

$\Pi(p; u)$ is defined on $[p_a(u), p_b(u)]$, and **both endpoints are functions of $u$.** Every
derivative in sections 7.1 to 7.4 is taken strictly inside that interval, and the held partial
$\partial y_j/\partial u|_p$ of (7.0) is a derivative **along a line of constant $p$** — so it exists
only where the perturbed interval still contains the held $p$. That is a condition on the
perturbation, not on the state, and nothing about the base point implies it.

**At an interior point the condition is a margin; at a pin it is violated by construction**, because
$p^\star$ sits a fixed fraction of the interval's width inside the bound it is pinned to, and any
perturbation moving that bound by more than the fraction carries the held $p$ outside. So the held
term of (7.0) is unavailable at a pin for exactly the inputs the bound reads — which is why section
7.4's row is a total and not a sum of two halves.

**And there is no continuous extension to evaluate instead.** Below $p_a$ the flux reverses, so the
downstream potential is *wetter* than the collar and the model substitutes the zero-flux state:
conductance identically zero, intercellular CO₂ at the point where **gross** assimilation vanishes.
Approaching $p_a$ from inside, conductance tends to zero and section 7.5's supply-equals-demand
condition forces **net** assimilation to zero instead. The two limits differ by the dark
respiration, so

$$\lim_{p \downarrow p_a} \Pi(p;u) \;-\; \Pi(p_a;u) \;=\; R_d \tag{7.0b}$$

and this is measured, at two leaf temperatures, in the quantity the identity predicts. At the cooler
one the jump is $0.9999991$ of $R_d$; at the warmer one, where $R_d$ is $2.20$ times larger, it is
$0.9999995$ of it, and on a well-conditioned row the agreement is eight significant figures. The
mechanism is visible in the pair rather than inferred: at the endpoint the conductance is exactly zero
and net assimilation is exactly $-R_d$, while one step inside the conductance is small but non-zero
and net assimilation is $\sim\!10^{-7}$. **The whole jump is in the assimilation term**; the hydraulic
cost is continuous across.

Three things follow, and none of them is numerical:

- **The jump is the model's own zero-flux substitution**, which section 7.5 names as case X. No
  tolerance, step or ordering removes it, and the endpoint's value is not the limit from inside — the
  substitution *creates* the discontinuity rather than recording one.
- **It scales with dark respiration**, so it widens with leaf temperature and with any trait raising
  maintenance cost. It is largest exactly where a drought gradient is being asked for.
- **It is one-sided.** The dry endpoint carries no such substitution and $\Pi$ is continuous across
  it — which is what identifies the cause. This boundary is discontinuous because of what the model
  does when flow stops, not because it is a boundary.

**And the substituted region has width, which is the part that decides how a solve must return.** The
reversal condition is on the *potentials*, not on the endpoint, so the substitution is already active
for a sliver above $p_a$ rather than only at it — measured at about $10^{-6}$ of the interval's width.
That is the same order as the step-in a solve leaves between the bound and the point it returns, and
the coincidence is the reason the arrangement works: **a returned point one step-in inside the bound
is a point just outside the substituted region**, so it carries a real derivative. A step-in chosen
smaller would return points on the substituted branch while reporting them as constrained optima.

**So stepping over the wet endpoint is a consequence and not a defence.** An evaluation at a $p$ the
perturbed state does not admit returns the substituted branch — finite, plausible, and $R_d$ from the
quantity it stands in for. Feasibility must therefore be established **before** evaluating rather
than tested afterwards: a test afterwards is sound only if it can separate the substituted branch
from the intended one, and the two return the same type.

**The asymmetry between the two output kinds is the one thing a two-branch model gets right.** The
profit row survives every degeneracy in this table except a jump of the argmax and an undefined
objective. **The uptake row is the one that ceases to exist.** So the two must be refusable
independently, never as a pair.

**Refusal has no localisation.** A refusal anywhere in one census metric's sweep makes that
metric's entire gradient undefined — a sum has no defined value with an undefined term. Metrics are
independent of each other, so refusal is metric-level: not per-cohort, not per-parameter.

**These five are not unrelated corner cases. They are consecutive segments of one drydown**, and a
real rainfall sequence traverses them in order: **S → K** as the stand goes dry and tall → **B** as
the feasible window closes and the lower bound rises to meet the critical potential → **X** once
the window is gone. That ordering is the reason a selector is worth building once rather than
patched per-case, and it is why incidence measured on a wet driver says nothing about a dry one.

**Two of the five are not plants.** A rejected search step and a non-negative curvature are the
solver reporting that it could not move; no plant is described. Attributing such a point to
whichever bound is *nearer* returns the derivative of a bound the plant is not sitting on — finite,
plausible, wrong. They are one case, not two, and they must refuse.

**And a trait-consistency failure is not a state of the soil at all.** A parameterisation in which
root hydraulics fail before stem hydraulics is a different model, not a dry plant, and **a
gradient-driven trait search is exactly the thing that walks into it.** It must refuse by name.
The same holds for a rooting depth pushed past the soil column, where distributed root mass
silently vanishes.

**One case is the best-conditioned in the model.** At the operating point of zero *total* uptake,
the per-layer fluxes are individually non-zero and sum to zero: **pure root-mediated
redistribution**, and the emitted uptake vector is entirely the symmetry-breaking residue. Its
derivative exists in closed form, and its relative accuracy under any differencing scheme is the
worst in the model precisely because the output *is* the residue. On a drying driver this case is
live, and it is the one that most needs the exact route.

**Where folds should be expected, and why the obvious measurement cannot find them.** The
hydraulic cost is sigmoid in tension for $c>1$, so $-\Theta$ contributes **positive** curvature
below its inflexion and negative above, while assimilation is concave-increasing in its argument. A
difference of a concave gain and an S-shaped cost generically has a region of positive curvature
**on the dry flank**, once the cost's inflexion enters the feasible span — and drying moves the
span onto that flank. A curvature sample taken by differencing *about solved operating points*
cannot falsify this, because at a point where a maximum was found the second-order necessary
condition already forces $\Pi_{pp}\le 0$: **the sample is conditioned on the conclusion.** The
sweep that settles it runs $p$ across the whole feasible interval at dry states.

**The right guard is on the amplification, not on the curvature.** Near a fold
$\partial p^\star/\partial u$ is $O(\lvert\delta u\rvert^{-1/2})$ and does not exist, so a
bracketed fallback would return a number where none does. Refuse the **uptake** rows when
$\lvert m\rvert = \lvert s\rvert/\lvert\Pi_{pp}\rvert$ exceeds a declared ceiling, and **emit the
profit row regardless**, because it is valid at a fold. The pinned branch has its own version of
the same denominator and needs the same ceiling.

**And that ceiling can be applied at exactly one place in the chain, which is a statement about who
holds what.** $m$ contracts the output adjoints against the $p$-channel, so forming it needs
$\bar v$. Whatever supplies the rows does not have $\bar v$; a primitive owning the quotient does not
have it either, because the output sensitivities are applied to the value that primitive returns and
therefore *after* it. Only the consumer assembling the block holds both. The ceiling is the
consumer's, and the two quantities available earlier are not substitutes for it:

- **The denominator alone.** $\Pi_{pp}$ small is necessary for $m$ large and not sufficient, and its
  scale is the objective's — so a ceiling on it has to be re-measured under any reparameterisation
  that rescales profit.
- **$\max_i \lvert\partial p^\star/\partial u_i\rvert$.** This is available at the supplier and is
  not a quantity: it is a maximum over inputs carrying different units — potentials, capacities,
  masses, dimensionless exponents — so which input attains it is a choice of parameterisation rather
  than a property of the operating point, and no single ceiling can be stated for it.

The simplification that does hold is that $m$ is one scalar per seed, so a consumer sweeping several
functionals gets one number each, stated in that functional's own units — which the consumer, and
only the consumer, knows.

**One composition produces a guaranteed non-finite row, and neither this section nor section 6.2
sees it alone.** A per-layer flux derivative is undefined where that layer's flux is zero, and the
lower bound $p_a$ is the collar potential of zero *total* uptake. **For a plant rooted in a single
layer, total and per-layer are the same quantity, so the condition holds identically rather than
approximately.** Shallow plants are single-layer by construction. Section 6.2 calls this window
removable and this section calls case B the best-conditioned in the model; for a shallow-rooted
plant they are the same point, and the composition is a non-finite gradient rather than a refusal
or an answer.

### 7.1 The interior optimum: profit is free

Suppose $p^\star$ is interior, so stationarity holds:

$$g(p^\star, u) \;\equiv\; \frac{\partial \Pi}{\partial p}(p^\star, u) \;=\; 0. \tag{7.1}$$

Let $\Pi^\star(u) = \Pi(p^\star(u), u)$. Then

$$\frac{\partial \Pi^\star}{\partial u} = \underbrace{\frac{\partial \Pi}{\partial p}}_{=\,0} \frac{\partial p^\star}{\partial u} + \frac{\partial \Pi}{\partial u} = \frac{\partial \Pi}{\partial u}.$$

This is the envelope theorem, and it is the single largest economy in the design: **the derivative
of profit needs no sensitivity of the optimiser at all.**

### 7.2 The argmax channel is rank one

Other outputs are not stationary in $p$. Uptake $E(p^\star, u)$ is one. For those we need
$\partial p^\star/\partial u$. Differentiating (7.1),

$$\Pi_{pp} \, \frac{\partial p^\star}{\partial u} + \Pi_{pu} = 0 \qquad\Longrightarrow\qquad \frac{\partial p^\star}{\partial u} = -\frac{\Pi_{pu}}{\Pi_{pp}},$$

with $\Pi_{pp} = \partial^2\Pi/\partial p^2$ a scalar and $\Pi_{pu} = \partial^2 \Pi/\partial p\,
\partial u$ a row vector over the inputs.

In reverse mode we never form $\partial p^\star/\partial u$. Given an output adjoint $\bar v$ on the
outputs $v = f(p^\star, u)$ that are **not** stationary in $p$ — the uptake rows, and explicitly
*not* profit — define the scalar

$$s = \bar{v}^{\!\top} \frac{\partial f}{\partial p}, \qquad m = -\frac{s}{\Pi_{pp}},$$

and then

$$\bar u = \bar{v}^{\!\top}\frac{\partial f}{\partial u} \;+\; m \, \Pi_{pu}. \tag{7.2}$$

**Profit is excluded from $s$ deliberately.** Its $p$-channel is zero at an interior optimum by
section 7.1, and at a bound section 7.4 handles it separately. A definition of $s$ including profit
would double-count it there.

**Why rank one, stated carefully.** $\partial v/\partial u$ picks up $(\partial f/\partial p)
(\partial p^\star/\partial u)$, a column times a row, which is a rank-one matrix **because $p$ is a
scalar**. In reverse mode that matrix never forms: it collapses to the two scalars $s$ and $m$. $m$
is itself a scalar, so it has no outer product with anything, and $m\,\Pi_{pu}$ is a scaled row
vector.

### 7.3 The state reaches the leaf through one scalar, and the marginal profit through two

Everything else in this section reuses derivatives the forward model already needs. $\Pi_{pu}$ does
not: it is a mixed second derivative of the profit, one entry per input, and it must include the
implicit-function term of the $c^{\mathrm{i}}$ root-find of section 7.5.

**It is not an undifferentiated row vector.** Over the $2L+1$ state directions — the $L$ soil
potentials, the $L$ per-layer root masses, and leaf area — it factors exactly:

$$\frac{\partial R}{\partial u} \;=\; a\,\frac{\partial E^{\mathrm{up}}}{\partial u} \;+\; b\,\frac{\partial}{\partial u}\!\left(\frac{\partial E^{\mathrm{up}}}{\partial r}\right), \qquad R = \frac{\partial\Pi}{\partial p}, \tag{7.3}$$

with $a$ and $b$ two scalars shared across all of them.

**This is a chain rule, not a fit.** Writing $\sigma$ for the stem potential, $\kappa$ for the
maximum leaf-specific conductance, $P$ for the transport spline and $S_t$ for the stem's own head
term,

$$\sigma = P\!\left(\tfrac{1}{\kappa}E^{\mathrm{up}} + S_t(p)\right), \qquad
R = G(\sigma, p, \varphi)\; P'(x)\left[\tfrac{1}{\kappa}\frac{\partial E^{\mathrm{up}}}{\partial p} + S_t'(p)\right]$$

with $G = \partial\Pi/\partial\sigma$ and $x$ the spline's argument. The state enters $\sigma$ and
$x$ **only through $E^{\mathrm{up}}$**, and $\partial E^{\mathrm{up}}/\partial p$ enters directly;
intercellular CO₂ reads only $\sigma$, on a state-free bracket, and the assimilation, cost and
conductance derivatives are functions of $c^{\mathrm{i}}$, $\sigma$, $p$ and $\varphi$. So
$R = F(E^{\mathrm{up}},\ \partial E^{\mathrm{up}}/\partial p;\ p, \varphi)$ **identically**, and
rank two is a chain rule through a two-dimensional intermediate.

**The outputs are rank ONE through the same waist, and the two facts are usually stated as one.**
Only $R$ carries the second intermediate, because only $R$ differentiates in $p$. At a **fixed** $p$
the state reaches the stem potential, the intercellular concentration, assimilation, conductance and
profit through $E^{\mathrm{up}}$ **alone**, so for each of them

$$\frac{\partial y_j}{\partial u}\bigg|_p \;=\; \frac{\partial y_j}{\partial E^{\mathrm{up}}}\;\frac{\partial E^{\mathrm{up}}}{\partial u} \tag{7.3a}$$

— one number per output times one vector over the inputs. **Per-layer uptake is the exception and it
is the informative one:** $E_i$ is what the supply produces rather than something the leaf reads, so
it depends on the state directly, and its row is the supply's own Jacobian, which section 3.3 of
report 02 shows is diagonal in the potentials and lower-triangular in the layer masses.

**(7.3a) is measured rather than argued, and the measurement is a scaling rather than a residual.**
Hold the collar, move two layers in opposite directions with the ratio that cancels
$\partial E^{\mathrm{up}}$ to first order, and read the outputs. Moving one layer alone shifts
assimilation by $2.58\times10^{-4}$; the cancelling pair shifts it by $4.66\times10^{-10}$ —
**five and a half orders down** — and each further decade of step divides that by a hundred where the
one-layer control divides by ten. The residual is $1.000$ times what the leftover
$\partial E^{\mathrm{up}}$ alone accounts for, on three pairs of layers and two soil profiles, until
it reaches the outputs' own last bits. Meanwhile the per-layer draws move at **full first order** and
do not cancel, which is the control that makes the test mean something.

So the held block over the $2L+1$ state directions is **not** a matrix to be filled in column by
column. It is one vector from the supply, one number per leaf output, and the supply's own Jacobian
for the uptake outputs — $n_{\text{output}} + n_{\text{input}}$ numbers where the block has
$n_{\text{output}} \times n_{\text{input}}$ entries. That is the same economy section 7.2 takes on
the operating point, applied to a second scalar, and the two compose: the supply is one node, the
operating point is another, and every output hangs off both.

**The second intermediate is the sensitivity of uptake to the collar, not to root mass.** An earlier
form of this section said root mass, and the closed form for $b$ it gives is the collar one:
$\partial R/\partial(\partial E^{\mathrm{up}}/\partial p) = G\,P'/\kappa$ exactly, with
$G = \partial\Pi/\partial\psi_{\text{stem}}$. The rank-two claim and $b$ were right; the sentence
naming the intermediate was not.

**The rank-two claim itself is verified out of sample, and that is worth separating from how the
pair is obtained.** Solving $(a,b)$ from two directions of *different families* — one soil potential
and one layer resistance, condition number 2.6 to 6.7 — and then **predicting** the remaining nine of
the $2L+1$ tests whether the state really does reach $R$ through two intermediates and nothing else.
It does:

| state | $p^\star$ | stationarity | worst predicted | $\psi$-family sv ratio |
|---|---|---|---|---|
| wet | 2.408 | 1.7e-11 | 2.4e-05 | 9.0e-05 |
| dry | 2.858 | 1.1e-15 | **1.0e-06** | 3.9e-04 |
| shaded | 2.175 | 1.4e-15 | 2.8e-05 | 6.1e-05 |
| near-uniform | 2.570 | 1.4e-16 | 2.5e-06 | 1.6e-04 |

The residual scales as $1/h$ over three decades of step with no minimum — round-off rather than
truncation — so the true residual is below those figures, and $(a,b)$ are stable to four significant
figures across them. The uniform-drying direction, which §7.3's conditioning discussion and report
06 §7 both single out, fits best of the four. **The load-bearing claim for the water channel holds.**

**One route to $\partial R/\partial u$ that does not work, because the failure is instructive.**
$R = \partial\Pi/\partial p$, so $\partial R/\partial u$ is the *collar* derivative of
$\partial\Pi/\partial u$ — and $\partial\Pi/\partial u$ has an analytic form: a price times a supply
derivative. Differencing that in the collar would give every direction from two evaluations and no
re-driving. **It is wrong by a factor of 1.40**, because the price is
$\lambda_{\text{multi}} - \lambda_{\text{stem}}$ and the multilayer $\lambda$ is the one the collar
solve *equalises*. The analytic profit row is therefore an expression for $\partial\Pi/\partial u$
**at** the operating point and not away from it. $\partial R/\partial u$ has to come from the
marginal profit itself, which is what makes the factorisation necessary rather than merely cheap.

**Both scalars are partials of a two-argument function, and that is what says how to get them.**
Write $x = E^{\mathrm{up}}/\kappa + S_t(p)$ for the transport coordinate and $W = \partial x/\partial p$
for its collar slope, so that $\sigma = P(x)$ and

$$R \;=\; \Phi(x)\,W, \qquad \Phi(x) \;\equiv\; \frac{\partial\Pi}{\partial x} \;=\; G(\sigma)\,P'(x).$$

Then

$$b \;=\; \frac{\partial R}{\partial(\partial E^{\mathrm{up}}/\partial p)} \;=\; \frac{\Phi(x)}{\kappa} \;=\; \frac{\partial\Pi}{\partial\psi_{\text{stem}}}\cdot\frac{P'}{\kappa}, \qquad a \;=\; \frac{\partial R}{\partial E^{\mathrm{up}}} \;=\; \frac{\Phi'(x)\,W}{\kappa}. \tag{7.3b}$$

**The sign is the one the prose above gives**, not its negative: an earlier form of this line carried
a leading minus, and a profit row built on it comes back as a clean factor of $-1$ against a
difference of the profit at wet, dry and shaded states.

**$b$ is elementary and $a$ needs one more derivative of the transport curve — but both are functions
of a single scalar.** $\Phi$ is a function of $x$ alone at fixed $p$ and $\varphi$. So $a$ is a
derivative in **one** well-scaled argument, obtainable by perturbing $x$ itself: two evaluations of
$\Phi$, once, for the whole state family, with no solve, no supply call and no feasibility question,
because $x$ is a number the transport curve is read at rather than a state the model has to be put
into.

**The same $b$ answers the held profit row, and that is not a coincidence.** At fixed $p$ the state
reaches profit only through $x$, so

$$\frac{\partial\Pi}{\partial u}\bigg|_p \;=\; \frac{\partial\Pi}{\partial x}\cdot\frac{1}{\kappa}\cdot\frac{\partial E^{\mathrm{up}}}{\partial u} \;=\; b\;\frac{\partial E^{\mathrm{up}}}{\partial u}. \tag{7.3c}$$

One scalar converts supply into carbon **and** supply-slope into repricing, because both are the same
question asked of the same transport curve: what one unit of water arriving at the collar is worth.
So the held profit row over every state direction costs one multiplication once $b$ is in hand.

**Two things leave the waist, and both are discrete rather than smooth.** The deepest rooted layer
sets the row's **arity**, so root mass changes the *length* of the vector rather than its entries.
And the two bounds are root-finds over the potentials, which enter no row on the interior branch
and *are* the whole row on the pinned branch.

**The factorisation's conditioning is where the difficulty is, and it is directional.** The $L$
vectors $(\partial E^{\mathrm{up}}/\partial\psi_j,\ \partial^2 E^{\mathrm{up}}/\partial\psi_j
\partial r)$ are numerically collinear — a second singular value of order $10^{-5}$ of the first.
That is simultaneously why one direction suffices to recover $a$ *given* $b$, and why any error in
$b$ is absorbed into $a$ at a ratio of about $10^5$. **A joint residual cannot detect it**, because
a compensating $(a,b)$ pair fits every potential row equally well. So an invariant that checks $a$
at fixed $b$ does not check the pair.

**But that conditioning belongs to a method rather than to the mathematics, and the distinction is
the whole of this section.** $a$ and $b$ are partials of $F$ in its own two arguments, by (7.3b).
Recovering them instead by *solving* for the pair that reproduces two observed state directions is a
choice, and it is the choice that inherits the collinearity: the design matrix is exactly the
near-degenerate one above. Perturbing the arguments has no design matrix at all.

The measurements that follow are therefore a record of what the fitted route costs, and are the
argument against it rather than a guide to using it. Against a difference that rebuilds the strategy
and re-runs on a stand where two species compete:

| how the pair was obtained | the row it was applied to |
|---|---|
| fitted from a soil potential and a layer resistance | 1.06 of the reference |
| $b$ closed form, $a$ solved along a **potential** | 0.83 |
| $b$ closed form, $a$ solved along a **carbon** direction | **0.990**, which is what a direct difference of that row also gives |

The middle row is the one that shows the mechanism. $b$ there is *exact* — it reproduces a difference
of the profit to $5\times10^{-10}$ — and pinning it makes the answer **worse**, because $a$ is then
carried by one differenced state direction and takes all of that direction's error. **Under a fit, an
exact coefficient in a badly placed pair is worse than two inexact ones**, and no residual formed on
the fitted directions can see it. Three defences follow from that and all three are unnecessary: an
anchor direction chosen out of the family the pair will serve, an out-of-sample check to detect the
compensation, and a rule that the anchor must not be a soil potential. **Take the partials in the
coordinates they are partials in and none of the three has anything to guard.**

**And the direction the ecology cares about is the direction that conditioning is worst in.** Water
moves on *differences* of potential while tissue fails on *absolutes*, so along the uniform drying
direction the model is a near-symmetry and the true response is a small residue on a strongly
amplified channel. A one percent error in either scalar is therefore a fifteen- to twenty-six-fold
error in the quantity of interest.

**That amplification is a property of the state directions and no choice of method removes it** — but
it is what decides how the row may be assembled. The general rule is the corpus's own: **anything
defined as a small difference of large quantities must be computed as itself**, never by subtraction
in a caller. Applied here it says the row is $a\,\partial E^{\mathrm{up}}/\partial u + b\,\partial^2
E^{\mathrm{up}}/\partial u\,\partial p$ with each factor supplied by whatever owns it exactly — the
two scalars from (7.3b), the two vectors from the supply — and never a difference taken along a
state direction, because a difference *is* the subtraction the rule forbids, taken in the one
direction where the cancellation is worst.

**In the dry regime the factorisation does not degrade — it collapses.**

| regime | the argmax object | rank over $2L+1$ |
|---|---|---|
| interior, wet | $a\,\partial E^{\mathrm{up}}/\partial u + b\,\partial(\partial E^{\mathrm{up}}/\partial p)/\partial u$ | 2 |
| pinned at zero uptake | $-(\partial E^{\mathrm{up}}/\partial u)\,/\,(\partial E^{\mathrm{up}}/\partial x)$ | **1** |
| pinned at the stem's critical potential | $-(\partial E^{\mathrm{up}}/\partial u)\,/\,(\partial E^{\mathrm{up}}/\partial x - \kappa S'(p_b))$ | **1** |

The second channel dropping out at a bound is legitimate: there the operating point is defined by a
residual in total uptake alone.

**Which parameters are slack at an interior optimum is decided by one question, and it is not which
bound they belong to.** A parameter is slack there exactly when it reaches the outputs through the
bound's residual *and through nothing else*: the constraint is inactive, so its whole contribution is
inactive with it, and the row is zero because of where the point sits rather than because the model
cannot answer. **Both critical potentials meet that condition.** The flux integrates the vulnerability
curve up to the *stem potential the plant is operating at*, not up to a critical potential; the
critical potentials appear in the dry bound's residual, and — for the stem's — as the endpoint of the
bracket the solve searches. Both are inactive strictly inside the interval.

Two things follow that an implementation can get wrong in opposite directions. **A slack zero is not
a structural zero**, because a structural zero claims the parameter reaches nothing on any trajectory
while a slack zero says it goes live the moment the constraint binds — so recording one as the other
tells a reader the model has no answer where it has a state-dependent one. And **slackness is a
property of the point, not of the parameter**: the same parameter that is slack at an interior
optimum carries the whole row at a pin, so a declaration made once per parameter is a claim about the
regime as well.

**The dry bound is the lesser of the two critical potentials, and that ordering is what keeps the
bracket inside the grid.** It is $\min$ of the collar at which the stem reaches its critical
potential and the root's own critical potential, so it is at or wetter than the root's — which sits
comfortably inside the root vulnerability integral's tabulated domain, the grid running on to a
smaller conductivity fraction than the shutoff does. **So the search does not probe past the grid,
and the leaf's bracket is not a route into the extrapolated region.** Section 6.2's dry layer is the
only route.

**The exposure is at the *wet* bound instead, and it is worse there.** The wet bound is the collar
potential at which the per-layer fluxes **sum to zero** — so its position is set by the very
signed-flux cancellation that a badly extrapolated integral inflates, and the sensitivity of uptake
to the collar reads that same tabulation. A bound defined by a cancellation among quantities one of
which is wrong is not approximately right; it moves by whatever the wrong term contributes. And this
is where the pins actually are: **of the pinned operating points on a representative sweep, more
than half sit at the wet bound rather than the dry one.**

So the ordering ruling stands, with its mechanism replaced. **A correct constrained-optimum row
evaluated at a bound whose own position is set by a corrupted flux is a correct derivative of the
wrong thing**, and it will pass every invariant the row has, because the row and the bound are
consistent with each other. Bounding the integral therefore precedes building the selector of
section 7.0; doing them the other way round validates the new branch against the defect and locks it
in.

**And the dry bound is now two different rows, not one.** Which of the two magnitudes wins the
minimum decides the derivative. Where the stem's critical collar wins, the bound is a search result
and $\partial B/\partial u$ is dense, as the table above gives it. Where the **root's** critical
potential wins, the bound is a registered constant: $\partial B/\partial u$ is then **exactly zero
in every state direction** and minus the unit vector in its own parameter direction. That is the
whole row, it is exact, and it is the cheapest branch in the section — but it only exists if the
parameter carries a row at all. Excluded on the old grounds that its branch was unreachable, its
sensitivity reads identically zero on every metric while being genuinely live, and it is the
parameter heading the family a gradient-driven trait search walks into.

### 7.4 The pinned optimum: the envelope theorem does not apply

If the maximiser sits at a bound, $p^\star = B(u)$ with $B$ either the zero-uptake potential $p_a$
or the critical potential $p_b$, then (7.1) is false: $\partial \Pi/\partial p \ne 0$ there.
Instead $p^\star$ follows the bound, $\partial p^\star/\partial u = \partial B/\partial u$, and the
profit term reappears in the adjoint. With

$$w = \bar\Pi \, \frac{\partial \Pi}{\partial p} + s, \qquad \bar u = \bar{v}^{\!\top}\frac{\partial f}{\partial u} + w \, \frac{\partial B}{\partial u}. \tag{7.4}$$

So the pinned branch carrying a profit contribution that the interior branch omits is not an
inconsistency; it is the envelope theorem failing at a boundary.

**The held term of (7.0) exists at a pin, and no finite difference of it does. The distinction is not
pedantic — it decides whether (7.4) can be reported in parts.**

At a pin $p^\star$ sits inside the bound by a fixed fraction $\delta$ of the interval's width. A
perturbation $\mathrm{d}u$ moves the bound by $O(\mathrm{d}u)$, so for all sufficiently small
$\mathrm{d}u$ the held $p^\star$ remains inside the perturbed interval and $\partial y/\partial u|_p$
is an ordinary two-sided derivative. **What fails is the step.** A difference must use a step large
enough to move the outputs above the solve's own floor, and at that step the bound moves further than
$\delta$ — so the arm lands where §7.0b says there is no value, and $\delta$ is not free to enlarge
because it is what keeps the returned point off the discontinuity.

So the two routes to a pinned row are not equivalent, and which one is used decides the shape of the
answer:

| how the row is obtained | what comes back | the economy |
|---|---|---|
| **differenced**, arms following the bound | the **total** directly, and the point must then be reported as not moving, or a consumer counts the bound's movement twice | dense: $n_{\text{output}} \times n_{\text{input}}$ |
| **assembled from closed forms** | the two halves of (7.4) separately, each a formula evaluated at the base state | $n_{\text{output}} + n_{\text{input}}$, as at an interior point |

**The parts economy is therefore a property of having closed forms, not of being interior.** An
earlier reading of this section made it interior-only; that was a statement about the differenced
route mistaken for one about the mathematics. Where the held partial is a formula, nothing is
evaluated at a perturbed state, no arm can leave the feasible interval, and the bound's own row
supplies $\partial B/\partial u$ — so a pin costs exactly what an interior point costs.

**One thing stays forbidden either way.** Recovering the held half from the total by subtraction —
$\partial y/\partial u|_p = \mathrm{d}y/\mathrm{d}u - (\partial y/\partial p)(\partial B/\partial u)$
— is arithmetically true and is a difference of two quantities that nearly cancel in the direction
§7.3 says the ecology lives in. Compute whichever half you report as itself.

The bound itself is implicit. $p_a$ is the collar potential at which uptake vanishes,
$E(p_a, u) = 0$, so

$$\frac{\partial p_a}{\partial u} = -\left(\frac{\partial E}{\partial p}\right)^{\!-1} \frac{\partial E}{\partial u}.$$

**This dichotomy covers two kinds of pin and the model produces four.** A rejected search step and
a non-negative curvature also set a pinned flag while sitting at neither bound, and section 7.0
requires them to refuse rather than to be attributed to the nearer bound.

**A tracked operating point is not a pin at all.** In the acclimating variant the collar potential
is an ODE state clamped into the feasible interval, so neither (7.1) nor
$\Pi_{pp}\,\partial p^\star/\partial u + \Pi_{pu} = 0$ holds. Its rows are case X: the derivative
at fixed $p$, plus a row for the tracked state. Treating it as interior divides by a curvature that
has no defining relation there.

### 7.5 The $c^{\mathrm{i}}$ root-find

Intercellular CO₂ solves a supply-equals-demand residual

$$R(c^{\mathrm{i}}; p, u) = A(c^{\mathrm{i}}) - \frac{g_c(p,u)\,(c^{\mathrm{a}} - c^{\mathrm{i}})}{P_{\mathrm{atm}}} = 0,$$

bracketed on $[\Gamma^\star, c^{\mathrm{a}}]$. By the implicit function theorem

$$\frac{\partial c^{\mathrm{i}}}{\partial \bullet} = -\left(\frac{\partial R}{\partial c^{\mathrm{i}}}\right)^{\!-1} \frac{\partial R}{\partial \bullet},$$

and this term must be carried into every derivative that passes through assimilation, including
$\Pi_{pu}$.

The bracket is valid only when the endpoints straddle zero. Since $R(c^{\mathrm{a}}) =
A(c^{\mathrm{a}}) = A_{\max}$ and $g_c \propto E$, the bracket fails when either $A_{\max} < 0$ or
$E < 0$ — both of which describe an individual that is not producing: respiring more than it fixes,
or unable to move water at all. Those are exactly the states at which the forward model substitutes
$c^{\mathrm{i}} = \Gamma^\star$ with zero flux rather than solving, and they are case X.

**The zero-transpiration exit and the pin at zero uptake are the same plant.** Gross assimilation
failing to cover dark respiration, and the lower bound where water stops paying for carbon, are one
threshold approached from opposite sides: there is no tension at which water pays for carbon. Any
separation between them is control-flow history rather than biology. Note this is the *shade*
mortality regime rather than a drought one — it is governed by light, so no rainfall sweep can see
it.

### 7.6 The transport integral in closed form

Flux from soil to collar integrates a stretched-exponential vulnerability curve,

$$G(m) = \int_0^m \exp\!\left(-\left(\frac{\sigma}{b}\right)^{c}\right)\,\mathrm{d}\sigma = \frac{b}{c}\, \gamma\!\left(\frac{1}{c},\, X\right), \qquad X = \left(\frac{m}{b}\right)^{c},$$

with $\gamma$ the lower incomplete gamma function, and
$E = \kappa\,[\,G(\psi_{\mathrm{stem}}) - G(\psi_{\mathrm{up}})\,]$.

Writing $a = 1/c$ and using the everywhere-convergent series

$$\gamma(a, x) = x^{a} e^{-x} \sum_{n \ge 0} \frac{x^{n}}{a(a+1)\cdots(a+n)} \;\equiv\; x^{a} e^{-x} \, \Sigma(a,x),$$

both derivatives are available in closed form. The $x$ derivative is the integrand,

$$\frac{\partial \gamma}{\partial x} = x^{a-1} e^{-x}, \tag{7.5}$$

and the $a$ derivative follows from $\partial_a$ of each term, since the $n$th term is $x^n$ over
$\prod_{l=0}^{n}(a+l)$:

$$\frac{\partial \gamma}{\partial a} = \log(x)\,\gamma(a,x) + x^{a} e^{-x} \sum_{n\ge 0} \left(-\,t_n \sum_{l=0}^{n} \frac{1}{a+l}\right), \qquad t_n = \frac{x^{n}}{a(a+1)\cdots(a+n)}. \tag{7.6}$$

So one loop with one extra accumulator gives value and both derivatives. Chaining to the parameters
with $\partial X/\partial b = -cX/b$, $\partial X/\partial c = X \log(m/b)$ and $\partial a/\partial
c = -1/c^2$:

$$\frac{\partial G}{\partial m} = \exp\!\left(-\left(m/b\right)^{c}\right)$$

$$\frac{\partial G}{\partial b} = \frac{\gamma}{c} - X \,\frac{\partial \gamma}{\partial x}$$

$$\frac{\partial G}{\partial c} = -\frac{b}{c^{2}}\gamma + \frac{b}{c}\left( X \log(m/b)\, \frac{\partial \gamma}{\partial x} - \frac{1}{c^{2}}\, \frac{\partial \gamma}{\partial a} \right)$$

Note what each parameter needs. Both need the series **value** $\gamma(a,X)$. The curve's position
$b$ needs additionally only $\partial\gamma/\partial x$, equation (7.5), which is elementary;
**only the steepness $c$ reaches $\partial\gamma/\partial a$, equation (7.6).**

**The series' argument is bounded here, and by construction.** The series does overflow in double
precision for large $x$ — $\Sigma$ growing while $e^{-x}$ underflows — and that range is
unreachable in this model. The integral's grid is laid out to the potential at which the
vulnerability function reaches a fixed small fraction, so
$X = \log(1/\text{fraction})$ **identically, for every $b$ and $c$**, and $x \le 4.61$ wherever
this integral is evaluated. Assert the bound; do not add an argument switch the model cannot reach.

**These closed forms replace a tabulation, and what they must replace is the tabulation itself —
not merely its derivative.** The distinction is the sharpest deployment rule in this document.
Where the forward solve evaluates a table, the derivative belonging on the tape is the **table's**,
because a gradient must differentiate the model being evaluated and not the model that model
approximates. Substituting the closed form for the derivative alone is the more accurate derivative
of a *different function*, and it introduces a systematic disagreement — parts in a thousand, for
this integral — that no invariant on the gradient can attribute, because both routes are internally
consistent and neither is refereeing the other.

So the closed forms above are a change to the **forward** model, made once and re-blessed once, after
which the derivative and the value describe the same function. Until then the honest derivative of a
tabulated curve is the tabulation's own.

**And whether the grid may be held across a parameter perturbation depends on who owns the grid.**
An earlier form of this section said it must be — capture it once, so that a differenced derivative is
not differentiating a moving grid. That is right for a grid chosen **independently** of the parameter,
which is report 03 §3.3's case: knot positions tied to a canopy height are a discretisation choice, the
term they contribute is discretisation error, and declining to carry it introduces nothing.

It is **wrong** for a grid the parameter itself defines. Here $\psi_{\max} = b\,\log(100)^{1/c}$, so the
knot positions are a function of the curve's own parameters and the forward model rebuilds them
whenever either moves. The grid is then part of what the parameter *means*, and a derivative taken on a
**held** grid answers a different question.

**But "held" and "not rebuilt" are different conditions, and the curve's two parameters fall on
opposite sides of the difference.** The test to apply is not whether the grid was rebuilt; it is
whether the perturbation carries the grid **to where a rebuild would have put it**. Two ways to
satisfy that, and only one of them is a rebuild.

$G$ is homogeneous of degree one in $(\psi, b)$, so $G(\psi; sb, c) = s\,G(\psi/s; b, c)$ — and
$\psi_{\max}$ carries the same factor $s$, so the rescaled read's domain **is** the rebuilt domain and
its knots **are** the rebuilt knots. Rescaling the base curve is therefore not holding the grid; it is
moving the grid analytically, and it is exact rather than approximate:

$$b\,\frac{\partial G}{\partial b} \;=\; G(\psi) - \psi\,G'(\psi) \tag{7.6a}$$

is Euler's identity applied to the **tabulated** $G$ and $G'$, so it is the table's own
$b$-derivative and not the continuum's. Position is closed-form because the identity holds on the
tabulated function.

**The steepness has no such identity and is the case the ruling was written for.** $c$ reshapes the
curve rather than scaling it: no rescaling of the base table reproduces the table a rebuild at a
moved $c$ would produce, so its row needs the grid genuinely rebuilt and differenced. So the two curve
*positions* have exact rows and the two *steepnesses* do not, and that is a statement about the
Weibull family rather than about any implementation.

**One consequence for which instrument referees which.** The knot *count* is decided by round-off —
a builder accumulating `psi += step` against a `<=` test can give 100 knots on one side of a central
difference and 101 on the other — so **a rebuilt difference carries a discrete artefact that an
identity does not.** Where an identity is available, the rebuild is the noisier of the two and a
disagreement between them is evidence about the reference before it is evidence about the row. Where
no identity is available, the rebuilt difference is the only faithful route and its jitter is the
floor to quote.

The calculus above was verified against an independent high-precision integral and against central
differences of it to better than $10^{-23}$, over $c$ from 0.4 to 12 and $m/b$ from 0.075 to 8.
**Read that as a derivation checked once rather than as a standing guarantee**: a figure at
$10^{-23}$ is below what double precision can carry, so it belongs to an arbitrary-precision
computation done beside the model and not to anything the model can re-run. A claim at that
magnitude is only as good as the artefact that produces it, and a corpus that quotes it without one
is quoting a memory. What a double-precision suite can hold is the series against its own closed
form and against a library's incomplete gamma; that is the check to keep current, and the $10^{-23}$
is the reason to believe the algebra rather than evidence about any code.

### 7.7 The value function's curvature, which the same two numbers already give

The envelope theorem kills the argmax's contribution to profit's **first** derivative. It does not
kill it in the **second**, and the difference is one term built from quantities section 7.2 already
computes.

Differentiate the envelope result $\mathrm{d}\Pi^\star/\mathrm{d}u = \partial\Pi/\partial u$ once
more, remembering that the partial is evaluated at a moving $p^\star$:

$$\frac{\mathrm{d}^2 \Pi^\star}{\mathrm{d}u^2} = \Pi_{uu} + \Pi_{pu}\,\frac{\partial p^\star}{\partial u} = \Pi_{uu} - \frac{\Pi_{pu}^2}{\Pi_{pp}} \;=\; \Pi_{uu} + B, \qquad B \equiv \frac{\Pi_{pu}^2}{\lvert \Pi_{pp}\rvert}. \tag{7.7}$$

**$B$ is non-negative always**, because $\Pi_{pp} < 0$ at a maximum and the numerator is a square.
So **re-optimisation is unconditionally convexifying**: the value function is less concave than the
profit surface at frozen behaviour, never more. That is the same fact that makes a maximum over a
family of functions convex, specialised to one scalar choice.

**It costs one multiply.** Since $\partial p^\star/\partial u = -\Pi_{pu}/\Pi_{pp}$ is the operating
point's own row — already reported wherever the collar's sensitivity is — equation (7.7) rearranges
to

$$B = \lvert \Pi_{pp}\rvert \left(\frac{\partial p^\star}{\partial u}\right)^{\!2},$$

so a caller holding the curvature and the collar column has $B$ without a further evaluation. This
is the third use of the pair $(\Pi_{pp}, \Pi_{pu})$: the multiplier $m$ of section 7.2, the
factorisation of section 7.3, and now the curvature correction.

**The correction is the same order as the thing it corrects, and it can invert it.** Measured over
an ordinary moisture-by-vapour-pressure-deficit envelope at shipped parameters, $B$ has a median of
about **0.74 of the fixed-behaviour curvature**, and over roughly **a third** of that envelope it
exceeds it — so $\Pi_{uu} + B$ and $\Pi_{uu}$ **have opposite signs**. A response that is concave
with behaviour held still is convex once the plant re-optimises. Anything that reads a curvature to
decide a direction — a Jensen argument about environmental variability, a second-order expansion, a
concavity assumption in an optimiser — gets the sign wrong on a third of the domain if it uses the
frozen one.

**And $B$ does not taper into a pin; it falls off one.** The interior expression is smooth right up
to the bound and then stops applying, because at a pin $\partial p^\star/\partial u$ is the bound's
derivative rather than $-\Pi_{pu}/\Pi_{pp}$. A curvature still exists there — the bound moves, and
the value follows it — but it is a different expression. **So pinning is a cliff in this quantity,
not a taper**, and section 7.0's selector governs it exactly as it governs the uptake rows. An
implementation that computes (7.7) wherever the curvature is finite will return a large finite
number just past the point where it ceased to mean anything.

**What this is not.** $B$ is a curvature of one individual's profit with respect to its own inputs.
It is not a curvature of fitness, and the two are separated by the whole of sections 4 to 6 — the
demography, both reductions, and the feedback. Report 06 §7 states the ecological reading and its
limit.

---

## 8. Supplying the individual's derivatives by hand

The maximisation of section 7 is solved in double precision and is not recorded on the tape. Its
derivatives are supplied instead. For an output $v$ whose value the solver has already produced,
the recorded expression is

$$\tilde{v} = v + \sum_i \left(\frac{\partial v}{\partial u_i}\right)\big(u_i - \mathrm{passive}(u_i)\big), \tag{8.1}$$

where $\mathrm{passive}(\cdot)$ strips the derivative and returns the value. Two properties:

1. $\tilde{v} = v$ **exactly**, in value, because every bracket is zero.
2. $\partial \tilde v/\partial u_i$ is the supplied $\partial v/\partial u_i$.

So the tape carries the correct number and the hand-derived derivative, and **this construction
serves forward and reverse mode alike**, which is what keeps a forward tangent available as a
reference.

**Three preconditions of property 1**, none of them stated by (8.1) alone:

1. **The bracket must be zero in value.** This is the precondition, and it is weaker than requiring
   $v$ to enter passively. A construction whose value *and* slope are active is admissible — the
   light interpolant's is, and it is on the census's path — provided each bracket still vanishes.
   What fails is an active $v$ *outside* a zero bracket, which double-counts.
2. **A non-finite *value* of any $u_i$ also poisons $\tilde v$**, since $\infty - \infty$ is not a
   number. This is a separate route from a non-finite derivative.
3. **The $u_i$ must be functionally independent**, or the supplied partials double-count. They are
   independent *at this cut* — radiation, the soil potentials, leaf area, the root mass fractions,
   the conductance — even though several are functions of height further upstream. **The cut is
   what makes property 2 true.**

**A non-finite supplied derivative corrupts the value, not only the adjoint.** If any
$\partial v/\partial u_i$ is not a number then $\mathrm{NaN} \times 0$ is not a number and
$\tilde v$ is poisoned, so a kink that returns non-finite partials makes the gradient and the
forward tangent fail together while the plain double path is unaffected. Section 7.0's single-layer
composition is a derived instance. **The construction therefore needs a finiteness test on the
partials before they meet the brackets** — there is nowhere downstream to put one, because the
value and the derivative are already entangled.

**A closely related mechanism must not be conflated with this one.** Registering the output as a
fresh tape input and attaching a callback that overrides the reverse sweep is a different
construction with three different properties: it carries **no forward tangent**, because a freshly
registered input has no incoming derivative; a non-finite supplied partial corrupts only the
adjoint, because the value never meets the partials; and it needs no zero-valued bracket at all.
The trade is a reference against a robustness.

**Property 1 has a sharp consequence for verification: a finite difference of the recorded step
cannot see an error in a supplied derivative**, because perturbing $u_i$ changes $v$ through the
solver, not through the bracket. Supplied derivatives must be checked against the individual's own
algebra, never against a difference of the step that consumes them.

---

## 9. The census functional and its two terms

A census is a quadrature over the size distribution of a per-individual metric,

$$\mathcal{C} = \sum_s \sum_k w_k \, n_k \, \mathfrak{m}(h_k, \varphi), \tag{9.1}$$

with $\mathfrak{m}$ one of leaf area, above-ground mass, or stem area. Because $\mathfrak{m}$ reads
$\varphi$ directly, the total derivative has two terms:

$$\frac{\partial \mathcal{C}}{\partial \varphi} = \underbrace{\sum_s \sum_k w_k \, n_k \, \frac{\partial \mathfrak{m}}{\partial \varphi}}_{\text{direct, at fixed state}} \;+\; \underbrace{\left(\frac{\partial \mathcal{C}}{\partial y}\right)^{\!\top} \frac{\partial y}{\partial \varphi}}_{\text{through the trajectory, by section 4}} \tag{9.2}$$

The second term is what the adjoint sweep computes, seeded with $\bar y(T) = \partial
\mathcal{C}/\partial y$. The first is not a sensitivity of the state at all and no sweep produces
it.

**The direct term's support is wider than the metric algebra suggests.** Leaf area reads the two
allometric constants. Above-ground mass sums leaf, bark, sapwood and heartwood, with bark and
sapwood each area × height × crown constant × density, so its support is the leaf-mass-per-area,
the wood density, the bark and stem-area constants, the crown constant and both allometric
constants. Stem area reaches the stem-area constants through sapwood and bark. And because the
seed's own quantities are rebuilt when the state is set, the boundary node's density is a full
physiology evaluation through the light field — so most of $\varphi$ takes a non-zero direct term,
not only the parameters appearing in $\mathfrak{m}$.

**The three metrics are one object with three supports.** Each is a per-cohort read of state and
strategy; they differ in which parameters they touch, not in kind. That is what makes section 9.1's
economy available.

**A census is a quadrature and it must be taken on a monotone grid.** Reserve-gated growth lets a
younger cohort overtake an older one, so a grid built from heights can be non-monotone, and on a
crossed grid neighbouring trapezia **cancel instead of accumulating**. This is a defect in the
quantity being differentiated and not merely in its derivative: it makes the objective wrong before
any adjoint runs.

**The size of it is about 4 percent, and it is now measured rather than argued.** On a stand that
inverts in more than half its steps and produces a healthy offspring count, integrating the same
state as-ordered against height-sorted moves the leaf-area census by 3.95 percent, the height moment
by 3.91 percent and the heartwood moment by 4.00 percent. **Same cohorts, same densities, only the
row order differs.** So the whole discrepancy is quadrature error in the objective.

**Guarding the crossing and integrating over the right axis are two requirements, and a reduction
can meet the first while failing the second.** The field reductions fall back to a sorted view and
demonstrably succeed at that — the light profile stays monotone in every step of the same run — and
that says nothing about which variable their trapezium widths are gaps in. Measured on the model:
the value reduction took its widths from the abscissa and the **fused value-and-slope reduction that
actually builds the field** took its widths from heights, so on the birth-date coordinate the two
disagreed by 100 percent relative while agreeing bit for bit on the height coordinate. The census
took heights on either coordinate, as did the transposes of both resource reductions.

**So the requirement is on the quadrature and not on the language, and it is two things:** integrate
over the abscissa the density is a density *in*, and sort or refuse only where that abscissa can
invert. The first is the one that is wrong on every stand rather than only on a crossed one, and a
sorted view is no evidence of it.

**Those two sites need different guards, and reaching for the same one at both is a mistake in
opposite directions.** A census is a quadrature of a density, so its weights must be gaps in the
coordinate the state is carried on. Where that is the birth date, a census whose grid is built from
**heights** is integrating a density in one variable against the spacing of another — wrong in value
on any stand, and merely more visibly wrong on a crossed one. The fix there is the **abscissa**, and
once it is right, monotonicity is free: birth dates are strictly increasing by construction, so the
guard is an assertion and no sort is needed. The user-facing helper that reconstructs a distribution
over height is the other case: it genuinely integrates over height, crossing is real, and it needs a
sort or a refusal.

**And a sort by height on the first site would be actively wrong**, by §6.1's fourth condition: a
guard testing height order refuses exactly where the forward model runs correctly, and on this
coordinate crossing is *more* common, not less.


**A zero and an absence are different at this boundary, and the difference is not cosmetic.** An
unknown parameter must be refused by name. A registered parameter that reaches nothing comes back
as a number — round-off at $10^{-18}$ to $10^{-22}$, which reads as a gradient entry. In a design
where an exact zero is the signature of a missing accumulator and never of true insensitivity, **a
zero needs a mark and an absence needs a refusal.**

**And columns must be named per species.** Concatenating each species' parameter names with no
species prefix yields $S \cdot P$ columns with every name repeated $S$ times. Character indexing
then resolves each name to its *first* match, so a multi-species gradient silently returns species
one's column for every named parameter, and unknown-parameter validation cannot see it. A
single-species test suite never detects this.

### 9.1 Several functionals share one recording

For $F$ functionals the record is common and only the seed differs. Recording once and sweeping $F$
times costs one record plus $F$ sweeps, against $F$ records and $F$ sweeps; **the record
dominates**, so the saving is close to $F$-fold.

**The precondition is that the record really is common, and for one reduction here it is not.** The
census is recorded as a function of the state, so the recording *sets* that state inside itself; each
metric's recording is then a different one and there is nothing to share. Where that holds the
economy is unavailable, and the shape of the mistake is to take it anyway — hoisting the active copy
out of the loop to avoid rebuilding it, which is exactly the aliasing the next paragraph describes.

**The economy has a precondition that is easy to violate and expensive to detect.** Clearing a tape
returns its derivative-slot counter to zero. So any active value constructed *outside* the sweep
loop and read *inside* it refers, after the first clear, to a slot that now belongs to something
else. The first functional is then correct and every later one reads unrelated storage — which is
the worst available failure shape, because a correct first row lends credibility to the rest.

The rule that follows is structural, not a matter of care: **an active copy must be constructed
inside the recording that uses it**, and a driver whose entry clears the tape cannot express
record-once-sweep-many at all. Two further consequences: a value surviving a clear registers as a
variable with no dependencies, so its adjoint sweeps to **exactly zero** — which is why this failure
produces exact zeros in whole column families rather than noise; and a reduction computing all $F$
outputs in every recording wastes more than the $F$-records count suggests.

---

## 10. Where the trait gradient is assembled

Collecting the paths by which $\varphi$ reaches $\mathcal{C}$:

$$\bar\varphi = \underbrace{\sum_s\sum_k w_k n_k \frac{\partial \mathfrak{m}}{\partial \varphi}}_{\text{census, direct}} \;+\; \underbrace{\sum_n \sum_i \left(\frac{\partial f}{\partial \varphi}\right)^{\!\top}\!\bar k_i}_{\text{cohort steps, all stages}} \;+\; \underbrace{\sum_{\text{intro}} \left(\frac{\partial \ell_{\text{new}}}{\partial \varphi}\,\bar\ell_{\text{new}} + \frac{\partial r_0}{\partial \varphi}\,\bar r_0 + \frac{\partial h_0}{\partial \varphi}\,\bar h_0\right)}_{\text{boundary}}$$

$$+ \underbrace{\sum_q \left(\bar\Lambda_q \frac{\partial E^{\mathrm{comp}}}{\partial \varphi} + \bar\Lambda'_q \frac{\partial_z E^{\mathrm{comp}}}{\partial \varphi}\right)}_{\text{light reduction, value and slope}} \;+\; \underbrace{\sum_j \left(\bar{\mathcal{U}}_j \frac{\partial \mathcal{U}_j}{\partial \varphi} + \bar\theta_j \frac{\partial \psi_j}{\partial \varphi}\right)}_{\text{water reduction and retention curve}} \;+\; \underbrace{\bar y(0)^{\!\top} \frac{\partial y(0)}{\partial \varphi}}_{\text{initial condition}} \tag{10.1}$$

**Six paths, and the count is the routes found rather than a closed set.** Two of the six were
missed by an earlier enumeration that declared itself complete, and both are structural rather than
exotic: the water reduction is the exact analogue of the light one, and the initial condition is
where a seed's provisioning enters. A completeness claim in a document like this licenses a reader
to stop looking, so the honest form is a count of routes established.

**The boundary term is three channels, not one.** The density slot of (4.2) is the obvious one. The
initial reserve is a trait times the storage capacity, so how well a seedling is provisioned reads
$\varphi$ directly. And the seed height is the subject of section 10.1.

**Nothing in a size-space adjoint can carry a parameter row.** A reduction transpose that writes
through a structure holding only size and density slots has no route to a trait accumulator,
however correct its arithmetic. This is why sections 6.1 and 6.2's parameter terms are a question
about *where the accumulator is* and not about the derivative — and why the light reduction's four
parameters and the water reduction's parameter half fail for the same structural reason rather than
by coincidence.

**The last segment's state adjoint is the initial-condition term.** A sweep that narrows through
every introduction and then discards the final narrowed vector has computed
$\bar y(0)$ and thrown it away. The reserve channel above has no other path.

### 10.1 The seed's own quantities, and why they are solved rather than carried

The boundary term of (10.1) contains $\partial h_0/\partial\varphi$, and that derivative is not of
the same kind as the rest of this document. Everything else here differentiates a *rate*. This
differentiates the value a state is **given at birth** — an initial-condition sensitivity, resolved
once outside any trajectory.

The seed's height is defined implicitly. With $\omega$ the seed mass and
$F(h;\varphi) = \mathrm{mass}_{\mathrm{live}}(h;\varphi) - \omega$,

$$F(h_0;\varphi) = 0, \qquad \frac{\partial h_0}{\partial \varphi} = -\left(\frac{\partial F}{\partial h}\right)^{-1}\frac{\partial F}{\partial \varphi} \tag{10.2}$$

which is the implicit function theorem applied exactly as §7.2 applies it to the operating point.
Eight parameters reach it — the leaf-mass-per-area, the seed mass fraction, both allometric
constants, wood density, and the stem-area, root and bark constants — and they reach the census
through it on every metric, by both the establishment probability and the density boundary condition
(4.2).

**The search must not be recorded.** A bracketing root-find for $h_0$ is affine in its bracket and
blind to the residual's values, so recording it returns the derivative of the *bracket* rather than of
the height at which the condition holds. That is report 02 §1's ruling — a search is not a definition
— and it applies to construction as squarely as to the leaf. Differentiate the condition.

**The seed's leaf area is not a second quantity.** It is the allometry at $h_0$, so once the height
carries its derivative the leaf area follows, picking up both the allometry's own partials at fixed
height and the chain through the height. Only the two allometric constants have a non-zero partial at
fixed height; every other parameter reaches leaf area through the height alone. **Taking either
against the other held fixed mixes the two channels instead of summing them**, so for this purpose
they are one quantity.

**Where the derivative is formed decides whether it exists.** Preparation resolves $h_0$ before the
traits are differentiable inputs, and a strategy at an active scalar receives that result rather than
re-deriving it. So (10.2) evaluated at construction carries nothing — not incorrectly, but
identically zero, on the forward tangent and the reverse sweep alike. The condition has to be
differentiated where the newborn's state is written, which is inside the recording. Report 04 §2.1
states the requirement and why satisfying it in form is not satisfying it in fact.

**Two consequences for the assembly.** The boundary term's three channels — the density slot, the
initial reserve, and the seed height — are all initial-condition sensitivities, and the third was the
last of them to be obtained from its condition rather than declared. And because the seed height is a
*state's* value, its derivative propagates through the whole of that cohort's subsequent trajectory
rather than acting once: it is the one quantity in this section whose contribution compounds with run
length.

**What no differentiated instrument can referee.** A quantity declared away in construction is zero
on the sweep and on the tangent together, so they agree there for free. Only a reference that
*rebuilds* the strategy from its parameters inherits neither declaration. Its validity is per-fixture
rather than assumed — at production a relative step of $2\times10^{-7}$ in leaf mass per area moves a
mature stand between alive and identically zero — so it is a small-fixture instrument, and report 08
§5 makes it the completeness axis.
