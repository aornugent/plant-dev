# The ecology of the plant SCM, and the mathematics of its adjoint

**What this is.** A mathematical account of the system `plant`/`odelia` implement —
first the *ecology* (two nested dynamical systems: a physiologically optimising
individual, and a size-structured population that shades itself), then the *adjoint and
gradient* machinery that differentiates stand-level outputs with respect to traits. The
code is the representation; this document is the model the code represents. Symbols are
collected in the glossary (§13); equation tags `[eqn N]` match the labels in
`tf24_strategy.h`.

Two ideas recur and are worth stating up front, because most of the design follows from
them:

1. **The whole model is a differentiation of a maximum and of fixed points.** The leaf
   operates at a carbon-profit *optimum*; the plant is born at the height that solves a
   mass constraint; the internal CO₂ solves a supply = demand balance; the stand's light
   field is a self-consistent aggregate. Every one of these is an implicit relation, and
   its derivative is governed by the envelope theorem or the implicit-function theorem —
   never by differentiating the solver that finds it.
2. **The population physics is transport-free in the quantity we measure.** Everything
   the census reports is a moment of a conserved density; the growth-compression term
   that dominates the naive gradient error is, in the continuum, not present in any
   moment's time-derivative. Getting the discrete adjoint right is the art of preserving
   that cancellation.

---

## Part I — The ecology

### 1. The system is two nested dynamical systems

```
         trait vector θ  (LMA, wood density, p50, k_I, ...)
                 │
                 ▼
   ┌─────────────────────────────┐   E(z,t): light + soil water
   │  INDIVIDUAL (per plant)     │◄──────────────────────────────┐
   │  • leaf gas-exchange optimum │                               │
   │  • whole-plant carbon budget │                               │
   │  • ODE for state y(t)        │                               │
   └──────────────┬──────────────┘                               │
                  │  growth g, mortality r, fecundity            │
                  ▼                                              │
   ┌─────────────────────────────┐                               │
   │  POPULATION                  │  n(x,t): density over size x  │
   │  ∂ₜn + ∂ₓ(g n) = −r n         │───────────────────────────────┘
   │  (McKendrick–von Foerster)   │   the stand shades itself
   └─────────────────────────────┘
```

The inner system converts a plant's size and its environment into demographic rates. The
outer system transports a density of plants along the growth field those rates define.
They are coupled: the environment $E$ that each plant reads is an aggregate of the whole
population (taller plants shade shorter ones; all plants draw down soil water). A trait
$\theta$ enters at the bottom and its effect emerges at the top — hence *emergent* trait
gradients.

`FF16` is the classic carbon-only strategy (Falster et al. 2016). `TF24` replaces its
fixed light-response curve with an explicit **leaf hydraulic optimisation**; `TF24f` is a
fast variant that tracks the optimum with an extra ODE state instead of re-solving it
(§4.5). All three share the population layer and the allometry; they differ only in how
they resolve the leaf.

---

### 2. The individual, part 1: allometry and the carbon budget

A plant's entire size is indexed by one state, **height** $h$; every other size follows
from allometric scaling. Leaf area is the pivot:

$$
a_\ell(h) = \left(\frac{h}{a_{\ell 1}}\right)^{1/a_{\ell 2}}
\qquad\Longleftrightarrow\qquad
h = a_{\ell 1}\, a_\ell^{\,a_{\ell 2}}. \tag{eqn 2,3}
$$

The tissue pools are all linear or bilinear in $a_\ell$ and $h$:

$$
\begin{aligned}
m_{\text{leaf}} &= \phi\, a_\ell, & \text{(}\phi=\text{LMA)}\\
a_{\text{sap}} &= \theta\, a_\ell, & m_{\text{sap}} &= \rho\,\eta_c\, h\, a_{\text{sap}}
   = \rho\,\eta_c\,\theta\, h\, a_\ell,\\
a_{\text{bark}} &= a_{b1}\, a_{\text{sap}}, & m_{\text{bark}} &= a_{b1}\, m_{\text{sap}},\\
m_{\text{root}} &= a_{r1}\, a_\ell,
\end{aligned}
\tag{eqn 1,4,5,7}
$$

with the crown-shape constant $\eta_c = 1 - \dfrac{2}{1+\eta} + \dfrac{1}{1+2\eta}$
(a moment of the vertical leaf-area profile $Q$, §3.2). These give the **live mass**
$m_{\text{live}} = m_{\text{leaf}} + m_{\text{sap}} + m_{\text{bark}} + m_{\text{root}}$
and, crucially for growth, the marginal cost of new leaf area
$\dfrac{\mathrm{d}m_{\text{live}}}{\mathrm{d}a_\ell}
= \phi + \rho\eta_c a_{\ell1}\theta(a_{\ell2}+1)a_\ell^{a_{\ell2}} + a_{b1}(\cdots) + a_{r1}$
[eqn 18], whose reciprocal $\mathrm{d}a_\ell/\mathrm{d}m_{\text{live}}$ converts a mass
increment into a leaf-area increment.

**Net production.** The whole-plant carbon budget over a year is

$$
P(h, E) \;=\; a_{\text{bio}}\,a_y\,\big(A(h,E) - R(h)\big) \;-\; T(h),
\tag{eqn 15}
$$

where $A$ is canopy-integrated assimilation (§4), $R = r_\ell m_{\text{leaf}} +
r_b m_{\text{bark}} + r_s m_{\text{sap}} + r_r m_{\text{root}}$ is maintenance
respiration [eqn 13], $T = k_\ell m_{\text{leaf}} + \cdots + k_r m_{\text{root}}$ is
tissue turnover [eqn 14], $a_y$ is the carbon-use (growth-respiration) efficiency and
$a_{\text{bio}}$ the CO₂→dry-mass conversion. $P$ is the surplus available for growth and
reproduction, and is the single scalar through which the leaf optimisation reaches
demography.

---

### 3. The individual, part 2: the demographic ODE

Each plant carries a five-component state that the SCM integrates:

$$
y = \big(h,\; \mu,\; F,\; a_{\text{hw}},\; m_{\text{hw}}\big),
$$

height, cumulative mortality (a hazard integral), fecundity (cumulative offspring),
heartwood area and heartwood mass. Their rates (in `compute_rates`):

**Growth.** Surplus not spent on reproduction buys leaf area, which buys height:

$$
\frac{\mathrm{d}h}{\mathrm{d}t}
= \underbrace{\frac{\mathrm{d}h}{\mathrm{d}a_\ell}}_{a_{\ell1}a_{\ell2}\,a_\ell^{a_{\ell2}-1}}
  \cdot \underbrace{\frac{\mathrm{d}a_\ell}{\mathrm{d}m_{\text{live}}}}_{\text{[eqn 18]}}
  \cdot \big(1-\varphi_r(h)\big)\, P,
\qquad P>0,
\tag{growth}
$$

and $\mathrm{d}h/\mathrm{d}t = 0$ when $P\le 0$ (a plant in deficit does not shrink; it
dies faster, below).

**Reproduction.** The reproductive fraction is a logistic switch on maturation,

$$
\varphi_r(h) = \frac{a_{f1}}{1 + \exp\!\big(a_{f2}(1 - h/h_{\text{mat}})\big)},
\tag{eqn 16}
$$

turning on as $h$ approaches the maturation height $h_{\text{mat}}$, and

$$
\frac{\mathrm{d}F}{\mathrm{d}t} = \frac{\varphi_r(h)\, P}{\omega + a_{f3}},
\tag{eqn 17}
$$

the reproductive surplus divided by the cost per offspring (seed mass $\omega$ plus
accessory cost $a_{f3}$).

**Mortality.** The plant carries a cumulative hazard $\mu$, with survival
$S(t) = e^{-\mu(t)}$, driven by a growth-independent floor plus a term that explodes as
per-area productivity falls:

$$
\frac{\mathrm{d}\mu}{\mathrm{d}t}
= d_I \;+\; a_{dG1}\,\exp\!\Big(-a_{dG2}\,\frac{P}{a_\ell}\Big).
\tag{eqn 21}
$$

A well-lit, fast-growing plant ($P/a_\ell$ large) approaches the intrinsic floor $d_I$; a
suppressed plant ($P/a_\ell \to 0^+$) suffers hazard $d_I + a_{dG1}$.

**Establishment.** A germinating seedling survives establishment with probability

$$
p_{\text{est}} = \frac{1}{\big(a_{d0}\,a_{\ell,0}/P_0\big)^2 + 1}\;e^{-\text{decay}\cdot t},
\qquad P_0 = P(h_0, E),\ \ a_{\ell,0}=a_\ell(h_0),
$$

zero when the seedling's net production $P_0 \le 0$ — i.e. a seed cannot establish where
its own physiology cannot break even. This term is where the light and water environment
gate recruitment.

The demographic map, then, is: environment $E \Rightarrow$ leaf optimum $\Rightarrow P
\Rightarrow (g,\,r,\,\text{fecundity})$, with $g = \mathrm{d}h/\mathrm{d}t$ the growth
(characteristic) velocity and $r = \mathrm{d}\mu/\mathrm{d}t$ the mortality rate that the
population PDE consumes.

---

### 4. The individual, part 3: the leaf hydraulic optimisation (the TF24 core)

This is where TF24 earns its cost and its accuracy. For every plant at every step, the
model resolves the **leaf water potential** the plant should operate at, trading carbon
gain against hydraulic risk. It is an optimisation wrapped around a root-find wrapped
around the ODE.

#### 4.1 Photosynthetic demand (Farquhar)

Assimilation as a function of internal CO₂ partial pressure $c_i$ colimits a
Rubisco-limited and an electron-transport-limited rate. With Michaelis constant
$K_m$, CO₂ compensation point $\Gamma^\ast$, and dark respiration $R_d$:

$$
A_c(c_i) = \frac{V_{\max}\,(c_i - \Gamma^\ast)}{c_i + K_m},
\qquad
A_j(c_i) = \frac{J}{4}\cdot\frac{c_i - \Gamma^\ast}{c_i + 2\Gamma^\ast},
$$

$$
A(c_i) = \frac{A_c + A_j - \sqrt{(A_c+A_j)^2 - 4\,\theta_{\text{col}}\,A_c A_j}}
              {2\,\theta_{\text{col}}} \;-\; R_d,
$$

a smooth (curvature $\theta_{\text{col}}$) minimum of the two. The electron-transport
rate $J$ is itself the non-rectangular-hyperbola colimitation of light and capacity,

$$
J = \frac{aI + J_{\max} - \sqrt{(aI + J_{\max})^2 - 4\,\theta_J\,a I\,J_{\max}}}
         {2\,\theta_J},
$$

with $I$ = PPFD, $a$ the quantum yield, $\theta_J$ the curvature. $V_{\max}, J_{\max},
\Gamma^\ast, K_m, R_d$ carry peaked-Arrhenius temperature dependence,
$k(T) = k_{25}\,e^{E_a\Delta}\cdot\frac{1+e^{(d_S\,T_{25}-H_d)/RT_{25}}}
{1+e^{(d_S T - H_d)/RT}}$.

#### 4.2 Hydraulic supply (Weibull vulnerability)

The xylem's fractional conductivity falls with tension along a Weibull curve,

$$
k(\psi)/k_{\max} = \exp\!\big(-(\psi/b)^c\big),
\tag{vulnerability}
$$

so the **supply-side transpiration** driven by a potential drop from upstream $\psi_u$ to
the leaf $\psi_{\text{stem}}$ is the integral of conductivity over that interval,

$$
E_{\text{supply}}(\psi_{\text{stem}},\psi_u)
= k_{\max}\!\!\int_{\psi_u}^{\psi_{\text{stem}}}\!\!\exp\!\big(-(\psi/b)^c\big)\,\mathrm{d}\psi
= k_{\max}\big[G(\psi_{\text{stem}}) - G(\psi_u)\big],
$$

where $G(m) = \int_0^m e^{-(s/b)^c}\mathrm{d}s = \frac{b}{c}\,\gamma\!\big(\tfrac1c,
(m/b)^c\big)$ is a lower incomplete gamma — precomputed once as a spline so each
evaluation is two lookups. (This closed form matters twice: it removes quadrature bias
from the value, and its *analytic derivative* is what the acclimation gradient uses in
§10.3.)

Transpiration pulls CO₂ in through the same stomata, so the diffusive supply of carbon is
proportional to $E$: converting water flux to a stomatal conductance to CO₂,

$$
g_c = \frac{P_{\text{atm}}\, E_{\text{supply}}\, M_{\text{H₂O}}}{\text{VPD}\cdot 1.67},
$$

and the leaf's operating $c_i$ is the **supply = demand** balance

$$
\underbrace{A(c_i)}_{\text{demand (biochem.)}}
\;=\;
\underbrace{g_c\,(c_a - c_i)/P_{\text{atm}}}_{\text{supply (diffusion)}},
\tag{$c_i$ root-find}
$$

solved for $c_i \in (\Gamma^\ast, c_a]$ by a bracketing root-finder (TOMS748). This is a
genuine implicit relation and its derivative reappears in §10.

#### 4.3 Soil → root-collar → stem transport

Upstream of the stem is a multi-layer soil-to-root pathway. Each soil layer $i$ presents
a horizontal root resistance modulated by the layer's mean root-conductivity over the
potential interval, plus a vertical resistance, and a gravitational head
$\rho g z_i$. Balancing uptake against transpiration gives, per layer,

$$
E_i = \frac{\psi_{\text{soil},i} - P_{x,r} - \rho g z_i}{a_\ell\, r_{R,i}},
\qquad
r_{R,i} = \frac{r^{\min}_{R,H,i}\,(P_{\max}-P_{\min})}{\int_{P_{\min}}^{P_{\max}} f_r\,\mathrm{d}\psi}
          + r_{R,V,i},
$$

and the total uptake $E_{\uparrow}(P_{x,r}) = \sum_i E_i$. The **root-collar potential**
$P_{x,r}$ is fixed by soil→collar→leaf continuity,

$$
E_{\uparrow}(P_{x,r}) = E_{\text{supply}}(\psi_{\text{stem}}, -P_{x,r}),
\tag{continuity}
$$

another root-find nested inside the optimisation.

#### 4.4 The profit optimum

Bringing supply and demand together, the leaf chooses its operating potential to maximise
**carbon profit** = assimilation minus a hydraulic risk cost. TF24 uses the cost of
Trugman–Feng type,

$$
\text{cost}(\psi_{\text{stem}})
= g_1\big(1 - k(\psi_{\text{stem}})/k_{\max}\big)^{\beta_2}
= g_1\big(1 - e^{-(\psi_{\text{stem}}/b)^c}\big)^{\beta_2},
$$

a penalty that grows from zero (fully turgid) toward $g_1$ (all conductivity lost), and

$$
\boxed{\;
\psi^\ast = \arg\max_{\psi\in[\psi_{\text{soil}},\,\psi_{\text{crit}}]}
\ \Pi(\psi;\theta,E),
\qquad
\Pi = A(c_i(\psi)) - \text{cost}(\psi).
\;}
\tag{leaf optimum}
$$

The maximisation is a Brent/golden-section search over collar potential; each function
evaluation solves the $c_i$ balance (§4.2) and the continuity root-find (§4.3). At the
optimum the profit gradient vanishes, $\partial\Pi/\partial\psi\big|_{\psi^\ast} = 0$ —
the fact §7 turns into the entire leaf-sensitivity strategy. The resulting $\Pi(\psi^\ast)$,
scaled to canopy area and annualised, is the assimilation $A$ feeding $P$ in (eqn 15).

#### 4.5 TF24f: acclimation as gradient ascent

Re-solving (leaf optimum) from scratch every step is the model's dominant cost. `TF24f`
observes that $\psi^\ast$ moves *slowly* as the plant grows and the light shifts, and
carries it as an **extra ODE state** relaxing toward the optimum:

$$
\frac{\mathrm{d}\psi}{\mathrm{d}t} = k\,\frac{\partial \Pi}{\partial \psi}.
\tag{acclimation}
$$

The fixed point of this ODE is exactly $\partial\Pi/\partial\psi = 0$, i.e. the optimum,
so $\psi$ tracks the moving target without ever solving for it — needing only the
*gradient* $\partial\Pi/\partial\psi$, not the argmax. Two facts make it a genuine model
rather than a mere accelerator: at finite gain $k$ it is a physically meaningful
**acclimation lag**; and a centred estimate of the gradient sits at the true optimum to
$O(h^2)$, so the steady-state offset from TF24 is sub-millivolt. The optimal $k$ is
counter-intuitively *small* — large $k$ stiffens the ODE and amplifies gradient noise —
and a newborn must be seeded at its optimum (one full solve at birth) or shaded recruits
escape suppression. The route to tightening the match further is a *smooth/analytic*
$\partial\Pi/\partial\psi$ (§10.3), which is also exactly what the reverse-mode gradient
needs.

---

### 5. The population: McKendrick–von Foerster and the SCM

#### 5.1 The transport law

The stand is a density $n(x,t)$ over size $x$ (height), obeying a conservation law with
growth as advection and mortality as decay:

$$
\partial_t\, n(x,t) + \partial_x\big[\,g(x,E;\theta)\,n\,\big] = -\,r(x,E;\theta)\,n,
\qquad x > x_b,
\tag{MvF}
$$

with a boundary influx at the birth size $x_b$ set by seed production and establishment,
$g(x_b)\,n(x_b,t) = (\text{seed rain})\cdot p_{\text{est}}$. The growth field $g$ and
mortality $r$ are the individual rates of §3.

**Self-shading coupling.** The environment is a one-sided aggregate of the whole density.
The competitive (light-extinction) contribution of a plant of height $h$ at query height
$z$ is [eqn 11]

$$
\kappa(z,h) = k_I\, a_\ell(h)\,\Big(1 - (z/h)^{\eta}\Big)^2 \quad (z\le h),\ \ 0\ \text{else},
$$

which vanishes on the diagonal ($\kappa(h,h)=0$: a plant does not shade its own top) and
is built from the vertical leaf-area profile: the density of leaf area at height $z$ is
$q(z,h) = 2\eta(1-(z/h)^\eta)(z/h)^\eta / z$ [eqn 9] and the fraction above $z$ is
$Q(z,h) = (1-(z/h)^\eta)^2$ [eqn 10]. The environment is then the functional

$$
E(z,t) = \psi\!\left(\int_{x\ge z} \kappa(z,x)\,n(x,t)\,\mathrm{d}x\right),
$$

so the stand shades itself: $g$ and $r$ read $E$, which is a moment of $n$.

#### 5.2 Census functionals are moments

Every stand-level output the model produces — number, biomass, basal area, leaf-area
index, offspring production — is a **moment** of the size density at (or integrated over)
time:

$$
M = \int \varphi(x)\, n(x,T)\,\mathrm{d}x,
$$

with $\varphi \equiv 1$ (number), $\varphi = m(x)$ (biomass), etc. The competition field
itself is such a moment. These $M$ are the quantities Part II differentiates with respect
to traits.

#### 5.3 Solve-by-characteristics (the SCM)

The PDE is solved by the method of characteristics: the density is represented by a set
of **cohorts** $x_i(t)$ (points on the characteristic curves), each advected by the growth
field and each carrying a **log-density** $\ell_i$:

$$
\frac{\mathrm{d}x_i}{\mathrm{d}t} = g\big(x_i, E(x_i)\big),
\qquad
\frac{\mathrm{d}\ell_i}{\mathrm{d}t} = -\,\partial_x g - r.
\tag{characteristics}
$$

The $-\partial_x g$ term is **compression**: where the growth field converges
($\partial_x g < 0$), characteristics crowd together and the pointwise density rises. New
cohorts enter at the birth boundary on an adaptive schedule, so the cohort set *grows*
over the run. Moments are evaluated by **trapezoidal quadrature over the cohorts**, whose
weights are the cohort spacings $\Delta x_i = x_i - x_{i+1}$:

$$
M \approx \sum_i \tfrac12(\Delta x_i)\,(\varphi_i n_i + \varphi_{i+1} n_{i+1}),
\qquad n_i = e^{\ell_i}.
$$

#### 5.4 The conservation identity (which §11 must preserve)

The compression term $\partial_x g$ is the only piece of (characteristics) that is not a
closed-form rate, and it is a red herring for every moment. Integrating (MvF) against a
test function $\varphi$ and by parts,

$$
\frac{\mathrm{d}M}{\mathrm{d}t}
= \int\big(\varphi' g - \varphi r\big)\,n\,\mathrm{d}x + \text{boundary flux},
$$

**$\partial_x g$ does not appear.** Equivalently, the *conserved mass per cohort*
$m_i = e^{\ell_i}\Delta x_i$ obeys the transport-free law
$\mathrm{d}m_i/\mathrm{d}t = -r\,m_i$, because the $-\partial_x g$ in $\mathrm{d}\ell_i/\mathrm{d}t$
cancels the $+\partial_x g$ implicit in the evolving spacing
$\mathrm{d}(\Delta x_i)/\mathrm{d}t = g(x_i) - g(x_{i+1}) \approx \partial_x g\cdot\Delta x_i$.
The physics every census measures is transport-free; $\partial_x g$ is on the tape only
because we chose to transport a pointwise log-density. Hold onto this — it is the whole
story of §11.

---

## Part II — The adjoint and the gradient

### 6. What we differentiate, and why reverse mode

The object of interest is the **emergent Jacobian**

$$
J = \frac{\partial(\text{metrics})}{\partial(\text{traits})}
\in \mathbb{R}^{n_{\text{out}}\times n_{\text{in}}},
$$

with $n_{\text{out}} \approx 4$ census/fitness outputs and $n_{\text{in}} \approx 50$
trait parameters (`TF24_AD_FIELDS` lists them). Outputs $\ll$ inputs, so the **reverse
(adjoint) mode** is optimal: one recorded forward pass plus one adjoint sweep per *output*
delivers a full gradient row over *all* inputs at once. Forward mode would cost one pass
per input. Reverse mode is used for the gradient; forward mode survives only as the leaf's
internal IFT (§10) and as the correctness oracle (§8.1).

### 7. Reverse-mode AD is the discrete adjoint

A run is a composition of elementary operations $f = f_L\circ\cdots\circ f_1$. Writing the
intermediate adjoint (cotangent) $\bar v = (\partial M/\partial v)^\top$, reverse mode
propagates it backward through each operation by the local vector-Jacobian product

$$
\bar v_{k-1} = \Big(\frac{\partial f_k}{\partial v_{k-1}}\Big)^{\!\top}\bar v_k,
$$

seeded with $\bar M = 1$ and read off at the inputs as $\bar\theta = (\partial M/\partial
\theta)^\top$. This is *exactly* the discrete adjoint of the ODE integrator: XAD records
the tape of operations on the forward solve, then sweeps it once per output. `odelia`
wraps this as `compute_jacobian` (record once, `codomain` adjoint rows) and
`compute_gradient` (the single row of a scalar functional). The functional is a **pure
reduction** — it reads the replayed solver's state and returns scalars; it never drives
the integration (that is the driver's job), which keeps "what is measured" orthogonal to
"how it is replayed."

#### 7.1 The dot-product identity as an FD-free oracle

Forward mode computes a Jacobian-vector product $Jv$ (a tangent carried alongside the
value, no tape); reverse mode computes a vector-Jacobian product $J^\top u$. They are dual
and must satisfy, for any $v,u$,

$$
\langle Jv,\; u\rangle = \langle v,\; J^\top u\rangle.
$$

Checking this for random $v,u$ is a **finite-difference-free correctness test**: one
forward pass, one reverse pass, no perturbation and no inner re-solve. It is the primary
guard that the reverse gradient is internally consistent (the census bug of §11 was one
that passed this test yet was still wrong — see there).

### 8. Record → replay: making an adaptive map differentiable

The SCM is riddled with **adaptive** constructions — the RK step-size controller, the
light-spline knots, the crown-depth quadrature subdivision, the cohort-introduction
schedule. Each exists to *place nodes to hit a tolerance without knowing the answer*, and
each involves `double`-valued branching that is not differentiable and would corrupt a
tape. But on a gradient pass the adaptive run **has already happened**, so the placement
is known. The primitive:

> **Record** where the double (adaptive) pass placed its nodes and schedule. **Replay**
> pinned to those nodes with the active (AD) scalar — no adaptive branching — and read the
> adjoints.

The differentiation trick, stated once: on replay the node **positions** are frozen
doubles (no branching to corrupt the tape) while the node **values** stay active — so the
gradient flows through *what the nodes hold*, never through *where they sit*. Positions are
recorded per accepted step (representative to within the step controller's own tolerance);
values are recorded per RK stage (a real quantity each stage genuinely consumes).

This freeze applies at four independent depths that compose (`ad-record-replay.md`,
`ad-infrastructure-design.md §7`):

| Level | Freezes | Removes non-differentiability from |
|---|---|---|
| **L0** node schedule | which cohorts exist, when introduced | adaptive cohort introduction |
| **L1** ODE step times | the accepted RK step grid | adaptive step-size control |
| **L2** quadrature/spline knots | height-quadrature abscissae, light-spline knots | adaptive refinement |
| **L3** resident canopy | the environment focal cohorts read | canopy feedback |

A cohort introduction, on a frozen schedule, is *not a discontinuity*: $t_{\text{intro}}$
is a constant ($\mathrm{d}t_{\text{intro}}/\mathrm{d}\theta = 0$), so it merely widens the
state (adds tape variables) without injecting a non-differentiable jump. That is precisely
why the schedule must be frozen — an adaptive, trait-dependent schedule would not be
differentiable.

### 9. The envelope theorem at the leaf optimum (the crux for TF24)

The leaf solves an optimisation $\psi^\ast(\theta,E) = \arg\max_\psi \Pi(\psi;\theta,E)$
every step. Naively, a trait gradient of the profit would have to differentiate *through*
the optimiser (a golden-section search — non-differentiable branching, and expensive). The
**envelope theorem** removes the need entirely. Since $\psi^\ast$ is an interior maximum,
$\partial_\psi \Pi|_{\psi^\ast} = 0$, and the total derivative of the *optimised* value is

$$
\frac{\mathrm{d}}{\mathrm{d}\theta}\,\Pi\big(\psi^\ast(\theta),\theta\big)
= \underbrace{\frac{\partial \Pi}{\partial \theta}}_{\text{explicit}}
 + \underbrace{\frac{\partial \Pi}{\partial \psi}}_{=\,0}\cdot\frac{\mathrm{d}\psi^\ast}{\mathrm{d}\theta}
= \boxed{\ \frac{\partial \Pi}{\partial \theta}\bigg|_{\psi=\psi^\ast}\ }.
$$

So the trait sensitivity of the leaf is just the partial derivative of profit **at the
fixed optimum** — no re-optimisation, first-order exact. In code this is
`leaf_profit_at_fixed_collar`: reconstruct a `double` leaf at a perturbed parameter but the
*held* optimum collar potential, and take a central finite difference,

$$
\frac{\partial \Pi}{\partial \theta_j}\bigg|_{\psi^\ast}
\approx \frac{\Pi(\theta_j+h) - \Pi(\theta_j-h)}{2h},
\qquad h = 10^{-6}(|\theta_j| + 10^{-6}),
$$

evaluated once per seeded parameter per cohort per step. The same construction supplies the
extra channels the resident coupling needs (§9.1). For `TF24f`, whose leaf runs at a
*tracked* $\psi$ that is **not** the optimum, $\partial_\psi\Pi \ne 0$ and the envelope
term does not vanish — a collar-$\psi$ channel must be added (§10.3).

#### 9.1 Channels through the leaf

The finite difference is taken not only over parameters but over every quantity the leaf
reads that is active on the tape, each becoming one input of the supplied-derivative seam:

| Channel | Perturb | Active on |
|---|---|---|
| trait $\theta_j$ | the parameter, at fixed $\psi^\ast$ | always (if seeded) |
| height $h$ | the held height (conductance, sapwood volume, $a_\ell$) | the growth state |
| light openness | the canopy openness the leaf sees | **resident** pass (self-shading) |
| soil $\psi_{\text{soil},\ell}$ | each layer's held potential | **resident** pass (soil feedback) |
| collar $\psi$ | — (zero by envelope for TF24) | **TF24f** only |

On a mutant (invasion) pass the light and soil are recorded `double` background, so those
tape slots are invalid and a pair-filter drops the channels — the derivative through the
canopy is zero *by construction*, which is exactly the invasion semantics (§12).

### 10. Injecting off-tape derivatives: the supplied-derivative seam and the IFT

#### 10.1 The seam mechanism

A value the forward pass computes *off* the tape — a root-find or optimiser result, a
`double` leaf output — has known analytic partials but no recorded operations. `odelia`'s
`supplied_derivative` injects them. It registers the off-tape value $y$ as a fresh tape
leaf, then installs a reverse-sweep callback that, on reaching $y$, reads the accumulated
output adjoint $\bar y$ and distributes it to the inputs:

$$
\bar x_i \mathrel{+}= \bar y\,\frac{\partial y}{\partial x_i}\qquad\text{for each }i.
$$

This is precisely the local VJP (§7) of an implicit node whose Jacobian is supplied rather
than recorded — the generic seam for any IFT/optimiser result. The leaf profit enters the
tape this way: $\Pi(\psi^\ast)$ becomes an active leaf carrying the envelope partials of
§9, so the reverse sweep traverses `density → leaf optimum → trait` natively, on one tape,
capturing the cross-term that a linearised frozen harvest would zero.

#### 10.2 Implicit-function-theorem derivatives

Wherever the forward run *solves* rather than *evaluates*, the derivative comes from the
IFT, not from differentiating the solver. For a solved relation $\mathcal{G}(y^\ast,x)=0$,

$$
\frac{\mathrm{d}y^\ast}{\mathrm{d}x}
= -\Big(\frac{\partial \mathcal{G}}{\partial y}\Big)^{-1}\frac{\partial \mathcal{G}}{\partial x}.
$$

Two instances:

- **Birth height** (`lift_birth_height`). The birth height solves
  $\mathcal{G}(h,\theta) = m_{\text{live}}(h;\theta) - \omega = 0$. The root $h^\ast$ is
  found in `double`; then one Newton step at the active parameters yields both the exact
  value (bit-identical to the double root) *and* the IFT derivative
  $\mathrm{d}h^\ast/\mathrm{d}\theta = -(\partial_\theta\mathcal{G})/(\partial_h\mathcal{G})$
  for every trait at once, with $\partial_h\mathcal{G}$ a `double` central difference. The
  trick `S(h*) - corr + to_passive(corr)` keeps the *value* frozen while letting only the
  *derivative* of the correction flow — a clean value/derivative split.
- **Internal CO₂** (§4.2). $c_i^\ast$ solves the supply=demand residual
  $\mathcal{G}(c_i; \psi_{\text{stem}}, \psi) = A(c_i) - g_c(c_a-c_i)/P_{\text{atm}} = 0$,
  giving $\mathrm{d}c_i/\mathrm{d}p = -(\partial_p\mathcal{G})/(\partial_{c_i}\mathcal{G})$.

#### 10.3 The analytic acclimation gradient (a worked composite)

`TF24f` needs $\partial\Pi/\partial\psi$ smoothly — both to drive the acclimation ODE
(§4.5) and as the collar-$\psi$ channel partial for the reverse seam (§9). Rather than a
noisy finite difference, `dprofit_droot_collar_psi` assembles it analytically, and it is a
small anthology of the whole toolkit at once:

$$
\frac{\partial\Pi}{\partial\psi}
= A'(c_i)\,\frac{\mathrm{d}c_i}{\mathrm{d}\psi} \;-\; C'(\psi_{\text{stem}})\,\frac{\mathrm{d}\psi_{\text{stem}}}{\mathrm{d}\psi},
$$

combining (i) **forward-mode AD** for the analytic algebra $A'(c_i)$ and the cost slope
$C'(\psi_{\text{stem}})$; (ii) the **IFT** at the $c_i$ balance,
$\mathrm{d}c_i/\mathrm{d}\psi = \mathrm{d}c_i/\mathrm{d}\psi_{\text{stem}}\cdot
\mathrm{d}\psi_{\text{stem}}/\mathrm{d}\psi + \partial c_i/\partial\psi$; and (iii)
**analytic spline derivatives** (`Interpolator::deriv`) for the smooth transport
$\mathrm{d}\psi_{\text{stem}}/\mathrm{d}\psi = P'(E_{\psi})\big[-E_\uparrow'(r)/k_{\max} +
S'(\psi)\big]$, where $S,P$ are the pre-integrated vulnerability spline and its inverse and
$E_\uparrow'$ is the analytic soil-uptake derivative. Only at a per-layer branch kink (a
measure-zero set) does it fall back to a central difference. The pre-integrated-gamma form
of §4.2 is what makes $S'$ available in closed form.

### 11. The census-gradient cancellation (geometric compression)

Here the population conservation identity (§5.4) becomes a hard requirement on the discrete
adjoint. The compression term $\partial_x g$ enters the discrete model **twice**:

1. **explicitly**, in the log-density ODE $\mathrm{d}\ell_i/\mathrm{d}t = -\partial_x g - r$;
2. **implicitly**, in the quadrature weights, via the evolving spacings
   $\mathrm{d}(\Delta x_i)/\mathrm{d}t = g(x_i) - g(x_{i+1}) \approx \partial_x g\cdot\Delta x_i$.

These are the *same continuous quantity* and (§5.4) they cancel in every moment. Whether
they cancel *on the reverse tape* depends on whether they are the **same discrete
expression**. Historically they were not: a one-sided finite-difference stencil about each
cohort's own height in the $\ell$-ODE, versus a neighbour spacing in the quadrature. Their
*values* nearly agree (so the primal is fine and the mass identity holds numerically), but
their *parameter-derivatives* are computed by two unrelated formulas, so
$\partial(\partial_x g)/\partial\theta$ does **not** cancel. The residual is an $O(1)$
gradient error, worst for parameters (like $k_I$) whose only route to the census is through
the coupling $\partial_x g$ carries:

| parameter | reverse-mode AD | converged FD | status |
|---|---|---|---|
| $b_0$ | 318.7 | 319.4 | ~0.2% (fine) |
| $k_I$ | **−27.1** | **0.144** | wrong sign, ~190× |

Note this error *passed* the JVP=VJP oracle (§7.1): the reverse sweep was a faithful
adjoint of the discrete forward map — it was the discrete map itself whose gradient
disagreed with the model-as-run.

**The fix (`node_geometric_compression`)** makes the two copies *literally the same
operator* — the neighbour difference over the same cohort spacings the quadrature uses,

$$
\partial_x g \;=\; \frac{g(x_{i-1}) - g(x_{i+1})}{x_{i-1} - x_{i+1}}
\quad\text{(interior; one-sided at boundaries)}.
$$

Now the explicit and implicit $\partial_x g$ are the same expression in the same variables;
their derivatives are identical *by construction*, cancel exactly on the reverse tape, and
the census gradient collapses to the transport-free continuum truth — to machine precision
across both parameter classes ($\cos(\text{ad},\text{fd}) = 1.000000$ vs the pre-fix
$0.970$). It remains a valid characteristic method (the difference is Lagrangian, computed
on the moving cohorts, so no Eulerian numerical diffusion). Because it slightly changes the
forward trajectory (~0.2% on K93 offspring), it is opt-in: ordinary simulations reproduce
the published model bit-for-bit; differentiable runs enable it so the gradient is the
derivative of the trajectory actually run. The deeper lesson: *a well-conditioned
derivative injected onto a pristine value is the derivative of a different model* — you
cannot keep the old forward and bolt on a good gradient; the discretisation and its adjoint
must be the same object.

It currently applies to strategies whose whole rate path is forward-mode-instantiable
(K93). FF16/TF24/TF24f keep the stencil because their differentiated metric (mutant
fitness) does not route through $\partial_x g$ (§12), so geometric compression offers them
nothing and would be pure regression risk.

### 12. Two feedback semantics: resident vs invasion

The same recorded run yields two genuinely different gradients, depending on how the canopy
(L3) is read on the active pass:

| Workflow | SCM entry | Canopy on replay | Cross-term | Meaning |
|---|---|---|---|---|
| **Resident / total** | `run()` | **recomputed live** from active cohorts | present | $\mathrm{d}(\text{metric})/\mathrm{d}\theta$ with full self-feedback |
| **Mutant / invasion** | `run_mutant()` | **frozen** recorded `double` | zero | selection gradient of a rare mutant in a fixed stand |

For the resident gradient the environment must be **recomputed** from the re-evolved active
cohorts (only the light-spline knot *positions* are frozen; the *values* come from the
replay), so a trait re-shades the stand through $a_\ell$ — replaying the frozen environment
here would silently collapse it to the invasion gradient. For the invasion gradient the
mutant reads the resident's recorded environment as pure `double` background, off the tape,
so $\partial/\partial(\text{canopy}) = 0$ — a rare mutant does not perturb the stand it
invades; positive fitness ⇒ it can invade.

This distinction is not a tolerance detail: the canopy feedback can **dominate and reverse
the sign** of a response (e.g. it flips the sign of biomass sensitivity to birth rate).
"Which feedback" is a modelling choice. The same coupled resident replay, with a likelihood
functional instead of an emergent metric on top, is what calibration to data uses — a
different *functional*, not a different *replay* — and the density-feedback derivative
$\mathrm{d}R_0/\mathrm{d}(\text{birth rate})$ (mutant framing) is the enabling piece for the
demographic-equilibrium ($R_0=1$) and invasion analyses.

**Why TF24 census sits on the same footing as FF16.** A trait shift moves the per-cohort
leaf optimum → growth → census density. Because the whole `run_mutant`/`run` replay runs on
**one tape** with the leaf IFT delivered as a supplied derivative (§10.1), the reverse sweep
traverses `density → optimum → trait` natively — including the cross-term through the
density — rather than a linearised harvest that would zero it.

---

### 13. Symbol glossary

| Symbol | Meaning |
|---|---|
| $h,\ a_\ell$ | plant height; leaf area, $a_\ell=(h/a_{\ell1})^{1/a_{\ell2}}$ |
| $m_\bullet,\ a_\bullet$ | tissue masses / areas (leaf, sapwood, bark, root, heartwood) |
| $\phi=$ LMA, $\rho$ | leaf mass per area; wood density |
| $\theta$ (context) | sapwood:leaf area ratio (allometry) **or** trait vector (AD); disambiguated locally |
| $\eta,\ \eta_c$ | crown-shape exponent; crown-shape constant $1-\tfrac{2}{1+\eta}+\tfrac{1}{1+2\eta}$ |
| $P$ | net mass production $= a_{\text{bio}}a_y(A-R)-T$ |
| $A,\ R,\ T$ | assimilation; respiration; turnover |
| $\varphi_r(h)$ | reproductive allocation fraction (logistic in $h/h_{\text{mat}}$) |
| $g,\ r$ | growth rate $\mathrm{d}h/\mathrm{d}t$; mortality rate $\mathrm{d}\mu/\mathrm{d}t$ |
| $\mu,\ S=e^{-\mu}$ | cumulative mortality hazard; survival |
| $c_i,\ c_a$ | internal / ambient CO₂ partial pressure |
| $A_c,A_j,J$ | Rubisco-, electron-limited assimilation; electron-transport rate |
| $\psi,\ \psi_{\text{stem}},\ \psi_{\text{crit}}$ | water potential (signed/magnitude by context); stem; critical |
| $P_{x,r}$ | root-collar potential |
| $k(\psi)/k_{\max}=e^{-(\psi/b)^c}$ | Weibull xylem vulnerability curve |
| $\Pi=A-\text{cost}$ | leaf carbon profit; $\psi^\ast=\arg\max_\psi\Pi$ |
| $E_{\text{supply}},\ E_\uparrow$ | supply-side transpiration; soil→collar uptake |
| $k$ (TF24f) | acclimation gain in $\mathrm{d}\psi/\mathrm{d}t=k\,\partial_\psi\Pi$ |
| $n(x,t)$ | size density; $\ell_i=\ln n_i$ cohort log-density |
| $\kappa,\ E(z)$ | competition kernel; light/water environment (a moment of $n$) |
| $M=\int\varphi\,n\,\mathrm{d}x$ | a census moment (number, biomass, basal area, LAI) |
| $\partial_x g$ | growth compression (the §5.4 / §11 term) |
| $J,\ Jv,\ J^\top u$ | emergent Jacobian; forward JVP; reverse VJP |
| $\bar v$ | adjoint (cotangent) of $v$ |

### 14. Sources

Ecology: `plant/inst/include/plant/models/tf24_strategy.h`,
`plant/src/tf24_strategy.cpp`, `plant/src/leaf_model.cpp`,
`plant/overstorey-staging/guides/tf24-hydraulics-and-acclimation.qmd`. Adjoint:
`odelia/inst/include/odelia/gradient.hpp`,
`odelia/inst/include/odelia/supplied_derivative.hpp`, and the design docs
`docs/ad-infrastructure-design.md`, `docs/ad-record-replay.md`,
`docs/ad-census-gradients.md`.
