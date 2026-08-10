# TF24, mapped: what the model is, how the computation flows, and where every partial goes

This is the first reading. It states what TF24 computes, in what order, and classifies every
partial derivative a reverse-mode gradient needs into one of five outcomes — *free*, *blocked*,
*split*, *solved* or *sidestepped*.

The others are its detail. [`05-reverse-mode-mathematics.md`](05-reverse-mode-mathematics.md)
states the algebra of the reverse pass, and this report defers to it wherever the two touch:
§6 below is a map of where each partial goes, not a derivation of what it is.
[`06-what-the-gradient-means.md`](06-what-the-gradient-means.md) states what those derivatives
mean, and what it would be wrong to conclude from one.

**The referee is the model, not any gradient implementation.** Everything below is read from
`plant`'s `develop`. A claim here is wrong if the model disagrees with it; that a particular
branch has or has not built something is not a fact about this map.

**One scope statement, because it removes a branch from everything downstream: the reverse-mode
gradient runs on the birth-date coordinate only.** The size distribution can be carried as a density
in height or in birth date, and the forward model supports both; only the second is differentiated.
On it, nothing moves an individual along the abscissa, so the density's compression term does not
exist, the quadrature abscissa is fixed at birth and carries no derivative, and the ordering cannot
invert. §4.4 gives the reason that is a correctness argument rather than a convenience. **Every
derivative statement below is on that coordinate**, and the height coordinate is named only where
the forward model differs.

The point of mapping the flow by hand is that a tape records operation flow *uniformly* —
every multiply costs the same to record and to sweep. Mapping it manually shows where the
structure is not uniform: where a channel is provably zero, where a block is diagonal plus
rank one, where a quantity is already ODE state so its derivative arrives for free. Those are
the places where a hand-built local Jacobian beats a tape by orders of magnitude rather than
by a constant factor.

---

## The physical reading

Almost everything here follows from five statements about what TF24 *is*. A reader holding
these five will predict §6's classification rather than having to learn it.

**1. The cohort optimises, so carbon is stationary and water is not.** Each cohort chooses its
root-collar water potential to maximise carbon profit. At that choice, profit's derivative with
respect to the choice is zero — so profit's sensitivity to anything else, soil or light or a
trait, is its *direct* sensitivity with the choice held still. Uptake is at no optimum. It
merely consumes the choice, so its sensitivity carries the choice's movement too.

This asymmetry is the most consequential fact here: **the carbon half of the leaf costs nothing
to differentiate and the water half is the entire difficulty.** For a purely photosynthetic
trait it is starker — uptake has no direct dependence on such a trait at all, so *all* of its
water sensitivity arrives through the operating point's movement.

**2. Water moves on differences; tissue fails on absolutes.** Uptake is driven by the difference
between a soil layer's potential and the collar's. But loss of conductivity — embolism, in root
and xylem alike — depends on the *absolute* tension. So the model nearly has a symmetry: shift
the whole water column, soil and collar together, and uptake would not change. It does not quite
hold, and the entire defect is the bend of the vulnerability curves across the operating span.

Three consequences, and report 05 §7.3 carries the numbers:

- When the soil dries uniformly the collar follows it closely, so uptake changes by about one
  percent of what the potentials do. The uptake channel is near-singular in the uniform
  direction, amplified fifteen- to twenty-six-fold. A single layer's perturbation is far better
  conditioned, so **a conditioning claim here is meaningless without its direction.**
- **Anything defined as a small difference of large quantities must be computed as itself**,
  from the term that breaks the symmetry — for the uptake, the cumulative root-vulnerability
  integral over an interval whose endpoints both slide. A whole-solve finite difference cannot
  measure that residue, because it resolves the collar's response to about four digits and the
  residue is one percent of it.
- The stem does the opposite. It *amplifies*, falling faster than the soil, because the same
  flux through a less conductive xylem needs a steeper gradient. Collar and stem break the same
  symmetry with opposite signs.

**3. Leaf area cancels out of the water channel.** Per-leaf-area uptake carries a factor
`1/area_leaf`, and the conversion to canopy uptake multiplies by `area_leaf`. So the soil sees
uptake with no leaf-area factor at all. Leaf area reaches the water only through the operating
point, and through root mass's effect on root resistance.

**4. Cohorts see each other through two small objects and nothing else.** The light profile —
one spline — and the soil moisture vector. Everything else is per cohort and independent given
those two. So the all-to-all coupling has the rank of the knot count on the light side and the
layer count on the water side, however many cohorts there are (§2).

**5. A reduction over the size distribution begins at the inflow boundary, not at the smallest
cohort.** The boundary node is always live, its height is always the birth height, and it is the
distribution's lower endpoint. A reduction starting at the smallest *existing* cohort invents a
limit and then needs a rule for when it does not exist. Both field reductions now integrate from
the boundary node; the water reduction did not always, and a transpiring recruit drew nothing
while it did.

## The gradient, end to end

**Forward, once per right-hand-side evaluation.** The soil holds one moisture state per layer,
and a retention curve turns each into a water potential. Every cohort's height and density
together build one light profile. Each cohort then reads that profile over its own crown and the
potentials from every layer, chooses its collar potential, and emits six rates — height,
mortality, fecundity, heartwood area and mass, storage — together with one water draw per layer.
The draws sum into the soil's balance. Two demographic equations per cohort close the system: the
density rate and survival-weighted offspring. A census metric is a weighted sum over the size
distribution, taken from the boundary node upward.

**Backwards, from the metric.** Seed the adjoint on the states the metric reads. Then, at each
step of the trajectory in reverse, the adjoint of the right-hand side goes in four parts:

1. **The closed-form seeds** — everything a cohort's sweep needs before it can run. The soil's
   drainage cascade is bidiagonal, so transposing it is free. Offspring contributes a mortality
   adjoint directly, because it reads that state and not only a rate.
2. **One sweep per cohort** of its own rate chain, from its states, the light profile's knot
   values and slopes, the layer potentials and the traits, to its six rates and its per-layer
   draws. The leaf sits inside this with a boundary rather than a tape: its carbon row is free by
   fact 1, and its water rows need the operating point's movement, obtained from the condition
   that defines the operating point.
3. **The light knot adjoints**, pushed back into every cohort's leaf area, density and height.
   The knots hold transmittance rather than summed leaf area, so this step carries Beer's law's
   own derivative.
4. **The allometry**, closed form.

The trait adjoint accumulates over every cohort, every stage and every step — and a trait read in
two places accumulates in two of the four parts, not one. `k_I` is the absorption coefficient
inside a cohort and the extinction coefficient in the field; `eta` is the crown quadrature
weight, the crown-shape constant, and that same field kernel.

**Where the difficulty is, in one line each.** The leaf, because the operating point is an
optimum rather than a state, and because its water rows are governed by a broken symmetry
(facts 1 and 2). The light, because a cohort reads a field and the field is built from every
cohort. The inflow boundary, because it is a flux condition rather than a value.

---

## 1. The state vector

Three groups of numbers evolve in time. Getting this list right matters, because the reverse pass
is an ODE in the adjoint of exactly these numbers and nothing else.

**Soil — `ode_size() = n_layers + 4`.** At the default of five layers that is nine entries:

    θ_1 … θ_5          volumetric soil moisture per layer     [m³ m⁻³]
    C_1 … C_4          cumulative rainfall, infiltration, deep drainage, total uptake

The four accumulators are diagnostics — **no equation reads their state.** Their *rates* are a
different matter, and §6 turns on the distinction.

**Per cohort — six strategy states.**

    h        height                                            [m]
    M        cumulative mortality (a log-survival)              [-]
    F        cumulative fecundity                               [-]
    A_hw     heartwood area                                     [m²]
    m_hw     heartwood mass                                     [kg]
    S        NSC storage pool                                   [kg]

**Per cohort — the demographic states.**

    ℓ        log cohort density        with n = exp(ℓ)
    Φ        survival-weighted cumulative offspring

**TF24f adds one more per cohort:** `p̃`, a tracked root-collar potential magnitude [MPa].

Two auxiliary quantities are cached rather than integrated, recomputed whenever `h` changes:
`a = area_leaf(h)` and `1/h`. They are not state; treat them as inlined functions of `h`.

---

## 2. The two objects through which cohorts talk to each other

This is the single most important structural fact in the model, so it gets its own section.

A patch holds many cohorts. Each cohort's physiology depends on the others **only** through two
shared objects, both rebuilt once per right-hand-side evaluation: the light profile `L(z)`, a
spline over a knot set built from the summed competition of every cohort; and the soil moisture
vector `θ`, depleted by the uptake vector `U`.

Per stage the patch does:

```
for each species s:  s.compute_rates(env, pr_survival, birth_rate)   # per-cohort work
for i in 0 … ode_size()-1:
    U_i = ( Σ_s  Species_s.consumption_rate(i) ) / area
env.compute_rates(U)                                                 # soil rates
```

So the cohort-to-soil interface is a vector of length `ode_size()`, **regardless of how many
cohorts there are**. In the reverse pass the adjoint of the entire cohort population reaches the
soil through nine numbers, and the soil reaches the entire population through five. That is what
makes a hand-built coupling Jacobian tractable: it is small in the direction that matters, and
the per-cohort work fans out from it.

---

## 3. The soil, forward

Per layer `i`, with per-layer parameter vectors supported and the scalars as fallback:

```
ψ_i(θ_i)  = a_ψ,i · (θ_i / θ_sat,i)^(−n_ψ,i) / 1e6                     [MPa]
            evaluated at max(θ_i, θ_r), θ_r = soil_moist_residual = 1e-2
K_i(θ_i)  = K_sat · (clamp(θ_i, 0, θ_sat,i) / θ_sat,i)^(2 n_ψ,i + 3)
```

With `n_ψ = 6.57` the retention exponent is −6.57 and the conductivity exponent about 16.14.

The balance, and this is the whole soil model:

```
infiltration = max(0, rain(t)) · max( 0, 1 − a_infil · (θ_0/θ_sat,0)^b_infil )
w_in,0 = infiltration
w_in,i = K_{i−1}(θ_{i−1})                       # drainage cascade, downward only
rate_i = ( w_in,i − K_i(θ_i) − U_i ) / dz_i
if θ_i ≤ θ_r  and  not (rate_i > 0):  rate_i = 0     # positivity guard
dθ_i/dt = rate_i
```

and the four accumulator rates:

```
dC_1/dt = rain            dC_2/dt = infiltration
dC_3/dt = K_n(θ_n)        dC_4/dt = Σ_i U_i
```

Five things to notice, all of which come back.

**There is no upward flux between layers.** A layer only receives water from the layer above. Any
upward movement in this model happens *inside the plant*, because per-layer uptake is signed.

**The positivity guard is written `!(rate > 0)`, not `rate < 0`.** That is deliberate: it fires on
`NaN` as well, because `NaN < 0` is false in IEEE-754 but `!(NaN > 0)` is true.

**The conductivity curve clamps θ at both ends**, and the retention curve floors it at `θ_r`. With
the conductivity exponent near 16, the residual floor is effectively unreachable dynamically — the
potential ceiling binds long before it, which is why report 05 §6.2 treats the ceiling as the only
clamp with incidence.

**The infiltration term has a `max(0, ·)`,** and so does the rainfall it multiplies. At
`a_infil = 1` and `θ_0 = θ_sat` the bracket is exactly zero, so this is a kink at saturation, not
merely a clamp far away.

**Two of the four accumulator rates read `θ`.** Infiltration reads `θ_0` and deep drainage reads
`θ_n`. So `∂(soil rates)/∂θ` is bidiagonal **plus two rows**, not bidiagonal alone. And
`dC_4/dt = Σ_i U_i` reads every layer's uptake, so an adjoint seeded on that accumulator reaches
every uptake row — including layers the positivity guard has zeroed, where the moisture adjoint is
exactly zero and the uptake adjoint is not.

---

## 4. One cohort, forward

This is the long section. It is where the coupling lives.

### 4.1 From height to the leaf's inputs

Given `h` and the shared light profile `L`, net mass production assembles everything the leaf
needs:

```
a        = area_leaf(h)                                  # cached aux
m_leaf   = mass_leaf(a);  A_sap = area_sapwood(a);  m_sap = mass_sapwood(A_sap, h)
A_bark   = area_bark(a);  m_bark = mass_bark(A_bark, h);  m_root = mass_root(a)

κ        = K_s · θ_huber / (h · η_c)                     # leaf-specific conductance max
v        = θ_huber · h · η_c                             # sapwood volume per leaf area
η_c      = 1 − 2/(1+η) + 1/(1+2η)                        # from the crown shape parameter
```

Root mass is distributed over layers by the **same cumulative shape function** used for the
canopy, parameterised over depth with its own exponent, down to a rooting depth capped at
`rooting_depth_max`. The loop breaks once the shape function reaches zero, which is a discrete
change in how many layers receive roots.

Then the light aggregation. **Mean-light is the default**, and it is a Gauss-Kronrod integral of
the light profile over the crown:

```
CrownCentre:  one leaf solve at  L(h · η_c)
MeanLight:    one leaf solve at  ∫₀^h max(L(z), 1e-4) · q(z,h) dz      # q integrates to 1
DeepCrown:    one leaf solve per Gauss-Kronrod node
radiation  =  k_I · max(light, 1e-4) · PPFD
```

So the radiation driving one cohort's leaf depends on **many** light knots, not one. Its reverse
form has three parts: the knot values it reads, the `q(z,h)` weighting, and the upper bound `h`,
which is itself an active state. Report 05 §5.2 and §6.1 give the sparsity, which is bounded by
the quadrature rule rather than by the cohort's height.

### 4.2 The leaf solve

Everything above is closed-form algebra. The leaf is not: the cohort *chooses* an operating
point. Write `p` for the root-collar water potential magnitude.

```
Objective, for a candidate p:
    σ(p)   = P( E_up(p)/κ + S_t(p) )                     # stem potential; P, S_t are C² splines
    ci(p)  : root of  A_net(ci)·u = γ_c(σ,p)·(ca − ci)·inv_atm      # inner root-find
    Π(p)   = A_net(ci(p)) − C(σ(p))                      # carbon profit
             A_net(ci) = colimited gross − R_d           # net; R_d subtracted inside
             C(σ)      = g1 · (1 − exp(−(σ/b)^c))^β₂     # hydraulic cost

Per-layer uptake, at any p:
    E_i(p) = ( p − ψ_i − g_i ) / ( a · r_R,i )            # Ohm's law, signed
             g_i   = 9.8e-3 · z_mid,i                     # gravitational head [MPa]
             r_R,i = r_H,i · span_i / ∫_i  +  r_V,i
             span_i = |p − ψ_i| ,  ∫_i = cumulative vulnerability integral over the span
    E_up(p) = Σ_i E_i(p)

Feasible interval:
    b_a = the p at which E_up(p) = 0                      # root-find; the wet bound
    b_b = min( root_crit, root_ψ_crit )                   # the dry bound: the lesser of the
                                                          # collar at which the stem reaches its
                                                          # critical potential and the root's own

The choice, obtained from the condition that defines it rather than by searching Π:
    p* : the root of  ∂Π/∂p = 0  in [b_a, b_b]            # safeguarded, and pinned to a bound
                                                          # where no interior root exists
```

Then the outputs, of which exactly two kinds matter downstream:

```
Π* = Π(p*)                    → carbon
c_i = E_i(p*)                 → water, per layer
```

plus diagnostics that reach auxiliary slots only.

**Three subtleties that are easy to miss and all matter for the map.**

*The leaf area cancels in the water channel.* `E_i` carries a `1/a`, and the conversion back
multiplies by `a`. So the per-cohort water draw is `(p − ψ_i − g_i)/r_R,i` with **no leaf-area
factor at all** — fact 3.

*The uptake vector and the total carry different units by design.* One stays in mol, the other is
converted to kg. Anything forming a Jacobian across the pair has to respect that.

*The operating point is defined by a condition, and it must be obtained from that condition.* A
comparison search over `Π` terminates on bracket width, so it resolves `p*` only to a tolerance and
the offset inside that width moves discontinuously as the comparison sequence flips — the argmax is
piecewise constant at fine scales, and a derivative taken through it comes back exactly zero or
sign-inverted. Solving `∂Π/∂p = 0` resolves it to solver precision instead, and does so **faster**,
because a superlinear root-find reaches a far tighter tolerance in fewer evaluations. Report 02 §1
is the long form. What the map needs from it is that **`p*` is a solved implicit quantity like `ci`
and `σ`, not a search result** — which is what puts it in §6's *solved* row rather than making it a
hazard.

### 4.3 From the leaf to the rates

```
assim   = Π* · a · 60·60·12·365 / 1e6                    # to mol yr⁻¹, 12 h daylength
resp    = respiration(m_leaf, m_sap, m_bark, m_root)
turn    = turnover(m_leaf, m_bark, m_sap, m_root)
P_net   = a_bio · a_y · (assim − resp) − turn            # net mass production
```

Then the storage block, which is where TF24 differs most from older accounts of this model:

```
S       = max( state, 0 )                                # the clamp; read what it does below
S_max   = a_st1 · m_sap                                  # capacity scales with sapwood
r       = min( S / S_max , 1 )                           # relative reserves, in [0,1]
G       = 1 / (1 + exp( −(r − a_st2)/storage_gate_width ))          # smooth reserve gate
P_pos   = ½ ( P_net + √(P_net² + storage_prod_eps²) )               # smooth positive part
growth  = P_pos · G

dh/dt        = dheight_darea_leaf(a) · growth · f_growth(h) · darea_leaf_dmass_live(a)
dF/dt        = fecundity_dt(growth, f_repro(h))
dA_hw/dt     = area_heartwood_dt(a)                      # turnover-driven, ungated
dm_hw/dt     = mass_heartwood_dt(m_sap)                  # turnover-driven, ungated
net_flux     = P_net − growth
dS/dt        = net_flux > 0 ? net_flux : (S/(S + 1e-3·S_max)) · net_flux
dM/dt        = d_I + a_dG1 · exp( −a_dG2 · r )           # storage-dependent mortality
```

**The hard `if (net_mass_production > 0) … else all rates zero` switch is gone.** It has been
replaced by two declared smoothing scales, `storage_prod_eps = 1e-4` on the positive part of net
production and `storage_gate_width = 0.1` on the reserve gate. Mortality no longer reads
instantaneous productivity — which was unbounded — but bounded relative reserves, giving
`dM/dt ∈ [d_I + a_dG1·e^{−a_dG2}, d_I + a_dG1]`. **So the carbon side of TF24 has already had
the "what gradual process is this switch standing in for" treatment applied, and the answer was
reserve dynamics.**

Three consequences of this block, and they are the ones a gradient turns on.

**The reserve deficit is an absorbing flat region, not a draining one.** The outflow gate is built
from the *already-clamped* `S`, so at a negative reserve the gate is `0/(0 + gate_ref)` exactly and
`dS/dt = 0`. The state sits where the overshoot left it, mortality pinned at its maximum, and every
derivative out of the reserve state vanishes until net production turns positive and releases it at
full rate. For a gradient that is worse than a kink, because a draining state at least has
self-sensitivity.

**But the cohort does not go gradient-dark there.** Growth flux reads a reserve gate bounded away
from zero — `G(0) = 0.2689` — so height, fecundity and both heartwood rates keep a live channel.
The expensive interior-case rows are not wasted at a frozen cohort; they are the only live channel
out of it.

**`{S ≤ 0}` and `{P_net ≤ 0}` are the same set, forced by algebra rather than by any driver.**
Release needs `P − G(0)·P_pos > 0`, which for positive `P` is immediate. So a drought raises the
frozen fraction one-for-one: **differentiating a drought is partly differentiating a flat region.**

**And the two smoothing scales are not the same kind of object.** `storage_prod_eps` was sized
against the spread of `|P_net|` and is well chosen. `storage_gate_width` was not: centred at
`a_st2 = 0.1` on `r ∈ [0,1]`, its transition occupies **40 percent of the whole domain**. It is not
a hard switch wearing a smooth coat but a mollifier wide enough to be the model, and it damps the
gradient wherever reserves are high. The distribution of `r` across a stand is the one number this
turns on, and it has never been reported.

### 4.4 The demographic states

On the coordinate the gradient runs on, the density changes only because plants die:

```
dℓ/dt = − dM/dt
```

**That is not a simplification, and the reason is a correctness argument rather than a cost one.**
Carried as a density in height the equation acquires a compression term, the size axis stretching
where growth accelerates with size — but `∂g/∂h` is the compression term of a density in height
*only when `g` is a function of height alone*. TF24's growth rate reads the storage pool through the
reserve gate, so a difference along the cohort grid is a **total** derivative,
`∂g/∂h + Σ_k (∂g/∂s_k)(ds_k/dh)`, and the two candidate stencils are **different operators rather
than two resolutions of one** — they correlate at 0.96 on K93 and at 0.05 on TF24, with opposite
signs over most of the grid. **Carried physiological state invalidates the compression term in
height**, so the choice of coordinate is not a choice of discretisation.

Carrying the density in birth date removes the term rather than discretising it better: nothing
moves an individual along a germination-date axis. It also removes the second physiology solve the
term needed, and it fixes the quadrature abscissa at birth, so the weights carry no derivative.
Report 05 §5.1 and §6.1 give what that buys the reverse pass; report 06 §2 gives what it means.

Two further facts about this axis, both properties of the model:

**Heights can invert, and germination dates cannot.** Reserve-gated growth lets a younger cohort
overtake an older one, so the descending-height ordering the model once relied on is not maintained.
That is the *second* reason this coordinate is the safe one — its abscissa is monotone by
construction — and it is also a trap, because crossing is **more** common here, not less. Any
quantity still taken over height needs a sorted view or it has neighbouring trapezia cancelling
instead of accumulating, and any guard written against *height* order will refuse a stand the
forward model handles correctly. §7 item 4.

**Height growth is strictly positive.** `P_pos` is bounded below by half the smoothing scale and
`G` by `G(0)`, so the `g > 0 ? log(·) : log(0)` arm at the boundary is unreachable.

And birth:

```
pr_estab = net_mass_production_dt(env, h_0, a_0) > 0
             ? 1/((a_d0·a_0/P_net)² + 1) · exp(−recruitment_decay · t)
             : 0
ℓ(birth) = log( birth_rate · pr_estab )
M(birth) = −log( pr_estab )
```

**This is a flux boundary condition, and its reverse-mode treatment is standard and is one term:**
the forward problem's *inflow* boundary is the adjoint problem's *outflow* boundary, and an outflow
boundary needs no condition. It enters the gradient as the adjoint at the boundary times the
boundary condition's own derivative.

Carried in height the same condition acquires a division by the growth rate, which converts the
flux — what the ecology measures — into the density that coordinate stores. That division is where
the boundary's singularity at vanishing growth comes from, and it is absent here.

**The apparent hard switch in `pr_estab` is not one.** The expression is `P²/(P² + k²)` above
threshold and zero below, and as `P → 0⁺` both the value and the first derivative tend to zero. So
it is already `C¹` and the zero arm is its correct `C¹` extension. Mollifying it would be actively
harmful — the biology's own transition scale is narrower than any smoothing width the model uses
elsewhere. What is true is a conditioning fact, not a smoothing argument: report 05 §5.3 gives the
peak and the rule that follows, which is to seed the boundary node's adjoint in `n` rather than in
`ℓ`.

### 4.5 Water aggregation

```
Individual.consumption_rate(i)  = c_i · a                            # the a that cancels
Node.consumption_rate(i)        = Individual.consumption_rate(i) · n ,  n = exp(ℓ)
Species.consumption_rate(i)     = trapezium over the size distribution, from the boundary node up
U_i                             = ( Σ_species … ) / area
```

Then `U` closes the loop into §3, and `θ` feeds back into `ψ` and hence every leaf solve.

**The quadrature weights are built from the abscissa, which is fixed at birth, so they carry no
derivative.** The trapezium's widths are gaps between introduction times, not between heights, and a
transpose must build them that way and omit the weight term entirely. Both `U_i` and the census
inherit that requirement — and the failure mode is a transpose that is internally consistent while
integrating over the wrong axis, which report 05 §6.1 states as four separate conditions because it
is easy to satisfy three of them.

### 4.6 The census functional

```
Ψ  =  Σ_species  trapezium over cohorts of  n_k · ψ(state_k)
```

for `ψ` = leaf area (→ LAI), above-ground mass (→ biomass), or stem basal area. Note `n_k = exp(ℓ_k)`
appears **linearly**. Offspring is `Σ Φ` and carries no density factor, which is why the two
functionals have genuinely different sensitivity structures.

### 4.7 TF24f, in one paragraph, because it changes the problem

TF24f makes the collar potential **an ODE state** rather than an argmax: it evaluates the leaf at
the tracked `p̃` clamped into `[b_a, b_b]`, reads back `∂Π/∂p` there, and sets
`dp̃/dt = k_acclim · ∂Π/∂p` — gradient ascent, seeded at the true optimum at birth. **TF24f has
already dissolved the argmax.** A state's derivative arrives from the adjoint ODE for free; there is
no implicit-function solve and no stationarity condition to differentiate. The price is a lag, an
extra state per cohort, and a clamp whose active set can change. It is not bit-compatible with TF24
and is not trying to be. Report 05 §7.0 classes its operating point as case X, and treating it as
interior divides by a curvature that has no defining relation there.

---

## 5. The forward pass, all together

```
──── once per RHS evaluation ────────────────────────────────────────────────
build L(z) = exp(−Σ_k n_k · comp(h_k))                    # one spline over the knot set;
                                                           # the knots hold L, not the sum
ψ_i ← retention(θ_i)                                       # one per layer, cached
for each cohort k:                                         # independent given (L, ψ)
    x_k ← geometry(h_k), root distribution, κ, v
    r_k ← ∫ light over crown  (mean-light)
    p*_k ← root of ∂Π/∂p = 0 on [b_a, b_b]                 # 1 root-find + 2 for the bounds
    Π_k, c_{k,i} ← leaf outputs at p*_k
    P_net,k ← a_bio a_y (Π_k a_k C − resp) − turn
    growth_k ← P_pos(P_net,k) · G(r_k)
    rates for h, F, A_hw, m_hw, S, M
    dℓ_k/dt ← −dM/dt
U_i ← Σ_k n_k c_{k,i} w_k / area                           # trapezium from the boundary node up,
                                                           # weights from introduction times
dθ_i/dt ← (w_in,i − K_i − U_i)/dz_i
────────────────────────────────────────────────────────────────────────────
```

---

## 6. Where every partial goes

The deliverable. Read §7 before relying on it, and read report 05 for the algebra of any row
marked *solved*.

### Free — no work at all

| partial | why |
|---|---|
| `dθ/dφ` | soil moisture is ODE state, so its parameter sensitivity is carried by the adjoint ODE. No freezing decision, no recording, no choice to make. |
| `dψ_i/dθ_i` | closed form, `−n_ψ ψ/θ`, and correctly **zero** in both clamped regions. |
| `∂(soil rates)/∂θ` | bidiagonal by construction, plus the two accumulator rows of §3. Transposing a bidiagonal is free. |
| `dp̃/dφ` **in TF24f** | the collar potential is state, so the adjoint carries it. TF24f pays no implicit-function cost at all. |
| root-mediated redistribution | the same smooth expression covers a negative per-layer flux, so **no branch is needed** — and a statistic formed on the *total* cannot see one, because signed fluxes sum. It is uncommon and runs downward under gravity head, so it is a free row rather than an important one; what makes it worth listing is that the wet bound of the feasible interval is defined by exactly this cancellation. |
| the quadrature weights | the abscissa is fixed at birth and passive, so `∂w_k/∂(state)` vanishes identically and the weight term is not written at all. The requirement it leaves behind is that the widths come from introduction times (§4.5). |

### Blocked — provably zero, so the channel is deleted

| partial | why |
|---|---|
| `∂Π/∂p` at an interior `p*` | envelope theorem: `p*` maximises `Π`, so the argmax channel contributes **nothing** to the carbon output. This deletes the largest-looking term in the whole map. |
| the collar solve's iterations | never differentiated. The operating point is defined by `∂Π/∂p = 0`, and the implicit function theorem supplies its derivative from that condition, so how the root was reached carries no information (§4.2). The same holds for `ci` and for the two bounds. |
| `ℓ_k →` own cohort's physiology | density enters no cohort rate. It reaches the world only through `U` and through `L`. |
| `∂(anything)/∂C_{1..4}` | the accumulator **states** are never read. Their *rates* are not blocked — see §3 and the *split* row below. |
| `∂h_0/∂φ` | the seed height is `double` by declaration and the strategy's preparation refuses an active scalar, so eight trait rows are **exactly zero by construction** on every census metric. This is imposed, not derived; report 05 §10.1 states the term and what closing it needs. |

### Split — a block that looks dense and is not

| partial | structure |
|---|---|
| `∂c_{k,i}/∂ψ_j` | **diagonal + rank one**: diagonal because `E_i` reads only its own layer's `ψ_i`; rank one because all five layers share the single scalar `p*_k`. |
| cohort ↔ soil | rank `ode_size()`. The whole population talks to the soil through nine numbers. |
| the accumulator rows | `dC_4/dt = Σ U_i` couples every layer's uptake to one adjoint; `dC_2/dt` and `dC_3/dt` each read one moisture state. Two rows and one dense row, on top of the bidiagonal. |
| cohort ↔ cohort | via the light spline, **and via the boundary node**, whose density the field's closing trapezium reads at every stage. The rank is the knot count. |
| the trait channel | separable from the state channel, and both are pulled back by the *same* scalar multiplier, so adding traits does not add solves. |
| a trait read **twice** | `k_I` is the absorption coefficient in a cohort's radiation and the extinction coefficient in the field kernel; `η` is the crown quadrature weight, `η_c`, *and* that same kernel. Both contributions are wanted and they arrive in different steps of the reverse pass, so the trait adjoint is a sum over steps as well as over cohorts. |

### Solved — an implicit relation, differentiated by its defining condition

| quantity | condition | cost |
|---|---|---|
| `p*` (TF24) | `∂Π/∂p = 0` at an interior optimum | one scalar divide by `Π_pp`, then one gradient of `∂Π/∂p`. **Five kinds of point, not one** — report 05 §7.0. |
| `ci` | the stomatal supply–demand balance | one implicit-function term, carried into every derivative passing through assimilation |
| `σ` (stem potential) | the transport splines | analytic spline derivatives |

### Sidestepped — needed in principle, not on the production path

| partial | why |
|---|---|
| `db_a/dφ`, `db_b/dφ` | the two bracket root-finds still run forward; their derivatives are wanted only where the operating point is pinned, which is the *K* branch of report 05 §7.0. |
| `dp*/dφ` as a **matrix** | replaced by one scalar and one gradient. |
| the whole argmax in **TF24f** | it is state. |

**What is not on this table.** The soil's own parameters — saturated conductivity, the retention
curve's scale and exponent, the saturation and residual contents, the ceiling, the infiltration
pair — are properties of the environment rather than of any strategy and appear in no parameter
list. They have no row anywhere. So does the vertical structure of the root coupling. Report 06 §11
states the consequence: **"what if the soil were sandier" cannot be asked.**

---

## 7. Where this map is at risk of being wrong

An oversimplified dependency map is worse than none, because it licenses deleting channels that are
load-bearing. Each item is a way the map could be **wrong**, not merely incomplete.

**Most are live. Two — items 5 and 13 — describe a shape the forward model has since closed**, and
are kept because the shape recurs rather than because the instance is open; they are marked. The
rest are properties of the model and do not close.

**1. "Diagonal in the layer index" is not quite the simple form it looks.** `r_R,i` depends on
`span_i = |p − ψ_i|` and on the vulnerability integral over that span, so `∂E_i/∂ψ_i` carries a term
through `r_R,i` as well as through the numerator. It is still diagonal — layer `i`'s resistance
reads only `ψ_i` and `p` — but not the bare `1/(a·r_R,i)` the Ohm's-law form suggests. The absolute
value also means `span` has a kink at `p = ψ_i`.

**2. The `max(light, 1e-4)` clamp is inside the crown integral,** so where it binds a cohort's
radiation is a *constant* with respect to every other cohort's height. It does not bind on the one
stand this corpus has run — the field is minimised at the ground by construction and its measured
minimum is three orders clear of the floor. But **the floor and the interpolant's monotonicity guard
sit on the same lever**, `k_I · LAI`, and `k_I` is a free parameter a gradient-driven search will
walk. Where either binds the severance is an artefact rather than the model, because the field is
smooth there; the honest treatment is to refuse the row with its incidence counted, not to return a
clamped zero.

**3. A transpose can integrate over the wrong axis and stay internally consistent.** The weights are
constant here, so there is no weight term to forget — the hazard is the opposite one, a transpose
that builds its trapezium widths from heights because that is what the height coordinate needed.
Nothing about the arithmetic complains; the reduction simply becomes the transpose of a function the
forward model is not computing. §4.5 states the requirement and report 05 §6.1 breaks it into the
four conditions it decomposes into.

**4. Cohorts can cross in height, and this coordinate inverts the failure rather than removing it.**
Reserve-gated growth makes crossing a normal event, and on the birth-date abscissa it is *more*
common than on the height one. Two opposite mistakes follow, and a design can make either. Anything
still integrating over **height** — the census, and any user-facing reduction over the size
distribution — needs a sorted view, or neighbouring trapezia cancel instead of accumulating, which
is an error in the objective before any derivative is taken. And any **guard** written as a test of
height ordering will refuse exactly the stands the forward model runs correctly, because the
quantity that must stay monotone here is the abscissa and the abscissa is not height. Both failures
are silent, and they are silent in opposite directions.

**5. The shared `Leaf` is a cross-cohort channel unless every exit writes every field it owns.**
*(Instance closed; the shape is the point.)*
Every cohort of a species writes into one strategy object and therefore one leaf. A buffer sized but
not cleared, or an early exit that sets three members and leaves a fourth stale, makes one plant's
rates depend on the plant solved before it — which breaks the per-cohort independence claimed in §5
and makes the forward pass order-dependent. This has been fixed more than once; it is listed here
because it is structural, not because it is currently broken.

**6. Deep-crown breaks the rank-one structure.** With one leaf solve per quadrature node, each with
its **own** `p*`, the per-cohort argmax channel becomes rank ~21 rather than rank one. Everything in
report 05 §7 still holds per node; the cost claim does not. Mean-light is the default and deep-crown
is a supported option, and the map should not silently assume it away.

**7. The rooting depth cap is a kink in height,** and the root-distribution loop's early break is a
discrete change in how many layers receive roots. Both sit directly on the `h → water` path. A
rooting depth pushed past the soil column silently loses root mass, which report 05 §7.0 requires to
refuse by name.

**8. The storage block's clamps are on the census gradient's path, and one of them is a flat region
rather than a kink.** `max(S,0)` and `min(S/S_max, 1)` bound `r`, and `dS/dt` is continuous in value
but kinked in derivative at `net_flux = 0`. §4.3 gives the reading: the deficit arm is absorbing, it
coincides exactly with negative production, and the stated invariant `S ≥ 0` does not hold of the
integrated state.

**9. `mortality_dt` branches on the finiteness of cumulative mortality,** returning zero when
mortality has saturated. That is a switch on a state, and its active set changes during a run.

**10. The soil potential cache is keyed on an exact `double` comparison of the soil state.** A cache
keyed on bit-equality is a hazard for anything that perturbs state slightly — including a
finite-difference verification of the very gradient this map is for.

**11. The envelope argument depends on `p*` actually being stationary.** The envelope theorem
protects `Π` — the error is second order in the displacement — and it does **not** protect the
fluxes, where the error is first order. So the *blocked* row for the carbon channel and the *solved*
row's linearisation point have very different exposures to the same imprecision, and conflating them
is the error this map most invites. **How well the operating point is determined is therefore set by
the derivative that consumes it, never by what the value needs** — and it is why `p*` is solved to a
tolerance far below the one at which anything else here is called a difference.

**12. The operating point is not always an interior maximum, and the states where it is not are
drought.** Report 05 §7.0's five kinds are consecutive segments of one drydown, so **incidence
measured on a wet driver says nothing about a dry one**, and a curvature sample taken by differencing
about solved operating points cannot falsify a fold — at a point where a maximum was found the
second-order condition already forces `Π_pp ≤ 0`. The selector between the cases must be a decision
tree on what defines the point and never a comparison on the residual, because the marginal-profit
function returns a hard sentinel zero in a no-flow state that no residual test can distinguish from
stationarity.

**13. The birth path evaluates a plant at birth size on the shared leaf,** at a different height from
the cohort loop, so ordering matters. *(Instance closed — the newborn is now solved once per stage —
and the ordering constraint remains.)*

---

## 8. What would falsify this map

- **`Π_pp` is small somewhere reachable.** Then the argmax channel needs more than one divide, and
  the guard belongs on the amplification rather than on the curvature.
- **The operating point is not stationary on a real patch at production tolerance.** Then the
  envelope row is wrong and the carbon channel costs as much as the water channel.
- **The flux adjoint does not collapse onto one scalar** — that is, `∂E_i/∂p` is not the only route
  from `p*` into layer `i`. Re-read the soil-to-collar flux for a second path.
- **The light floor is reached by most cohorts.** Then the light coupling is mostly blocked and
  report 03's accuracy target is over-specified.
- **Deep-crown is the intended production shading model.** Then the rank-one claim is a rank-21
  claim and the cost arithmetic changes.
- **A cohort's rates are not reproducible from its own boundary.** Re-run one cohort from stored
  state plus stored environment reads and compare bit for bit. Any difference locates a carried
  quantity, and §7 item 5 says where to look.
