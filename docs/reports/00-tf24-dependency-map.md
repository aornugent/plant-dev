# TF24, mapped: the physical reading, the forward pass, the reverse pass, and where every partial goes

> **This is the first reading, and it is the one report whose framing survived the build
> intact.** Its five physical facts and its five-way classification are what the gradient was
> built from, and §6.2's derivation — the flux adjoints collapsing onto one scalar, one divide
> by `Π_pp`, one gradient of `∂Π/∂p` — is the design as implemented.
>
> Two things to carry while reading it. **It describes develop `141dc8df`, which has no
> automatic differentiation at all**, so every section is about the computation a gradient had
> to be built *onto*. And **§10 item 5 is still owed**: `∇(∂Π/∂p)`'s parameter half is "the
> single new piece of code the whole design needs", it was ordered last, the implementation
> put a central difference in its place, and that stand-in is now the whole cost of a
> gradient. §7's *Genuinely open* and §9's "still inferred" are the sections that own its
> status — not §6.2, which owns its mathematics.
>
> One correction follows.

> **§7's treatment of the four cumulative-flux soil states is falsified. The classification stands
> otherwise.** §7 lists them as *free* — "write-only; nothing reads them, so their adjoints are
> identically zero" — and lists `∂(anything)/∂C_{1..4}` under *blocked*. Building P3.1 step (a)
> measured the opposite: **two of the four rates read θ**, so `∂(soil rates)/∂θ` is bidiagonal **plus
> two aux rows** rather than bidiagonal alone, and **`rate[n+3] = Σ U_i` adds `+λ_{n+3}` to every
> uptake adjoint** — including the layers the positivity guard zeroed, which is why `adj_uptake` is
> nonzero there while `adj_theta` is exactly 0. So the accumulators are read, their adjoints are not
> identically zero, and the channel is not blocked. Confirmed against a finite difference of
> `Environment::compute_rates`. Evidence in `../archive/implementation-notes.md` under *Phase 3, wave 1*, and
> the corrected step (a) is `../archive/build-plan.md` §2.4.
>
> **§6.3's `w_k` is right and is at the wrong level.** The trapezium weights are **per-species**, from
> `Species::consumption_rate`; `Patch::compute_rates` then sums species and divides by area with no
> further weighting. Same evidence.

## 0. What this report is, and how to read it

This report does one thing: it writes out TF24's forward computation as maths and
pseudocode, then derives the reverse-mode pass from it, and then classifies **every**
partial derivative in that pass into one of five outcomes — *free*, *blocked*, *split*,
*solved*, or *sidestepped*.

The point of doing it by hand is that a tape records operation flow automatically and
therefore records it *uniformly*: every multiply costs the same to record and to sweep.
Mapping the flow manually lets us see the places where the structure is not uniform —
where a channel is provably zero, where a 5×5 block is diagonal plus rank one, where a
quantity is already ODE state so its derivative arrives for free. Those are the places
where a hand-built local Jacobian beats a tape by orders of magnitude rather than by a
constant factor. Report 1 found its win that way; this is the same exercise applied to
the water.

**Read it in order, and start with the two unnumbered sections below.** *The physical
reading* states the five facts the rest of this report elaborates, and *the gradient, end to
end* walks the whole computation forwards and then backwards in prose. Between them they are
the orientation; everything numbered after is the detail that supports them. Then sections
1–5 build the forward pass from the soil upward; you need all of it before the reverse pass
in §6 makes sense. §7 is the classification table —
the actual deliverable. §8 is an adversarial review of §7, listing the places where the
map is at risk of being *wrong* rather than merely incomplete; read it before trusting
the table. §9 separates what is measured from what is asserted.

**Scope and provenance.** Everything described is `plant` at **develop `141dc8df`**, read
directly from a clean worktree. Where a measurement was taken on a different tree, §9 says so
explicitly and the number is marked. That distinction matters here: develop's TF24 differs
from the AD feature branch by roughly 1,900 inserted and 1,000 deleted lines, so a number's
tree is part of the number.

**One orienting fact before we start.** On develop, `plant` contains **no automatic
differentiation at all**. There is no active scalar, no tape, no `implicit_value`, no
templated Strategy. `Node`, `Species`, `Patch`, `TF24_Strategy` and `Leaf` are all plain
`double`. So this report is not describing a gradient that exists and needs fixing; it is
describing the forward computation that a gradient would have to be built *onto*, and
identifying the structure that makes that cheap or expensive. Nothing here proposes
templating `Leaf`.

---

## The physical reading

Almost everything in this report follows from five statements about what TF24 *is*. A
reader holding these five will predict §7's classification rather than having to learn it.

**1. The cohort optimises, so carbon is stationary and water is not.** Each cohort chooses
its root-collar water potential to maximise carbon profit. At that choice, profit's
derivative with respect to the choice is zero — so profit's sensitivity to anything else,
soil or light or a trait, is its *direct* sensitivity with the choice held still. Uptake is
at no optimum. It merely consumes the choice, so its sensitivity carries the choice's
movement too.

This asymmetry is the most consequential fact here: **the carbon half of the leaf costs
nothing to differentiate and the water half is the entire difficulty.** For a purely
photosynthetic trait it is starker — uptake has no direct dependence on such a trait at
all, so *all* of its water sensitivity arrives through the operating point's movement.
Measured: profit's sensitivity to `vcmax_25` at a frozen operating point equals the
full-solve value to every digit, while uptake's is exactly zero.

**2. Water moves on differences; tissue fails on absolutes.** Uptake is driven by the
difference between a soil layer's potential and the collar's. But loss of conductivity —
embolism, in root and xylem alike — depends on the *absolute* tension. So the model nearly
has a symmetry: shift the whole water column, soil and collar together, and uptake would
not change. It does not quite hold, and the entire defect is the bend of the vulnerability
curves across the operating span. In a plant whose conductivity did not decline with
tension, uptake would be exactly insensitive to uniform drying.

Three consequences, all measured on develop at 20 layers:

- When the soil dries uniformly the collar follows it closely — `dp*/dψ` = 0.907 to 0.959 —
  so uptake changes by about one percent of what the potentials do. The uptake channel is
  near-singular in the uniform direction, amplification 15× to 26×. A *single* layer's
  perturbation gives 0.79 and only 4.8×, so a conditioning claim here is meaningless
  without its direction.
- A whole-solve finite difference resolves the collar's response to about four digits, so
  it **cannot** measure that one-percent residue. **Anything defined as a small difference
  of large quantities must be computed as itself**, from the term that breaks the symmetry —
  and for the uptake that term is a single one, the cumulative root-vulnerability integral
  over an interval whose endpoints both slide.
- The stem does the opposite. It *amplifies*, falling 1.28 to 2.97 times as fast as the
  soil, because the same flux through a less conductive xylem needs a steeper gradient.
  Collar and stem therefore break the same symmetry with opposite signs.

**3. Leaf area cancels out of the water channel.** Per-leaf-area uptake carries a factor
`1/area_leaf`, and the conversion to canopy uptake multiplies by `area_leaf`. So the soil
sees uptake with no leaf-area factor at all. Leaf area reaches the water only through the
operating point, and through root mass's effect on root resistance (§4.2).

**4. Cohorts see each other through two small objects and nothing else.** The light profile
— one spline — and the soil moisture vector. Everything else is per cohort and independent
given those two. So the all-to-all coupling has the rank of the knot count on the light
side and the layer count on the water side, however many cohorts there are (§2).

**5. A reduction over the size distribution begins at the inflow boundary, not at the
smallest cohort.** The boundary node is always live, its height is always the birth height,
and it is the distribution's lower endpoint. A reduction starting at the smallest *existing*
cohort invents a limit and then needs a rule for when it does not exist.

## The gradient, end to end

**Forward, once per right-hand-side evaluation.** The soil holds one moisture state per
layer, and a retention curve turns each into a water potential. Every cohort's height and
density together build one light profile. Each cohort then reads that profile over its own
crown and the potentials from every layer, chooses its collar potential, and emits six rates
— height, mortality, fecundity, heartwood area and mass, storage — together with one water
draw per layer. The draws sum into the soil's balance. Two demographic equations per cohort
close the system: the density transport term, which differences growth across neighbouring
cohorts, and survival-weighted offspring. A census metric is a weighted sum over the size
distribution, taken from the boundary node upward.

**Backwards, from the metric.** Seed the adjoint on the states the metric reads. Then, at
each step of the trajectory in reverse, the adjoint of the right-hand side goes in four
parts:

1. **The closed-form seeds** — everything a cohort's sweep needs before it can run. The
   soil's drainage cascade is bidiagonal, so transposing it is free. The transport stencil
   supplies each cohort's growth-rate adjoint, which is why it is a seed rather than a
   consumer. Offspring contributes a mortality adjoint directly, because it reads that
   state and not only a rate.
2. **One sweep per cohort** of its own rate chain, from its states, the light profile's knot
   values, the layer potentials and the traits, to its six rates and its per-layer draws.
   The leaf sits inside this with a boundary rather than a tape: its carbon row is free by
   fact 1, and its water rows need the operating point's movement, obtained from the
   condition that defines the operating point. The coefficient that closes the soil channel
   is recovered from one additional pair of residual evaluations on this pass.
3. **The light knot adjoints**, pushed back into every cohort's leaf area, density and
   height. The knots hold transmittance rather than summed leaf area, so this step carries
   Beer's law's own derivative.
4. **The allometry**, closed form.

The trait adjoint accumulates over every cohort, every stage and every step — and a trait
read in two places accumulates in two of the four parts, not one. `k_I` is the absorption
coefficient inside a cohort and the extinction coefficient in the field; `eta` is the crown
quadrature weight, the crown-shape constant, and that same field kernel.

**Where the difficulty is, in one line each.** The leaf, because the operating point is an
optimum rather than a state, and because its water rows are governed by a broken symmetry
(facts 1 and 2). The light, because a cohort reads a field and the field is built from every
cohort. The transport term, because it is a difference across neighbours. The inflow
boundary, because it is a flux condition rather than a value.

---

## 1. The state vector

Three groups of numbers evolve in time. Getting this list right matters, because the
reverse pass is an ODE in the adjoint of exactly these numbers and nothing else.

**Soil — `TF24_Environment`, `ode_size() = n_layers + 4`.** With develop's default of five
layers that is nine entries: five moisture states plus four cumulative-flux accumulators
(rainfall, infiltration, deep drainage, total uptake) which are pure diagnostics — nothing
reads them back.

    θ_1 … θ_5          volumetric soil moisture per layer     [m³ m⁻³]
    C_1 … C_4          cumulative flux accumulators (write-only)

**Per cohort — `TF24_Strategy::state_names()`, six states.**

    h        height                                            [m]
    M        cumulative mortality (a log-survival)              [-]
    F        cumulative fecundity                               [-]
    A_hw     heartwood area                                     [m²]
    m_hw     heartwood mass                                     [kg]
    S        NSC storage pool                                    [kg]

`S` is new relative to older accounts of this model (issue #517) and it changes the
dependency graph substantially; §4.3 explains how.

**Per cohort — `Node`, the demographic states.**

    ℓ        log cohort density        with n = exp(ℓ)
    Φ        survival-weighted cumulative offspring

**TF24f adds one more per cohort:**

    p̃        tracked root-collar potential magnitude            [MPa]

Two auxiliary quantities are cached rather than integrated, recomputed whenever `h`
changes (`update_dependent_aux`): `a = area_leaf(h)` and `1/h`. They are not state; treat
them as inlined functions of `h`.

---

## 2. The two objects through which cohorts talk to each other

This is the single most important structural fact in the model, so it gets its own short
section.

A patch holds many cohorts. Each cohort's physiology depends on the others **only**
through two shared objects, both rebuilt once per right-hand-side evaluation:

1. **The light profile** `L(z)` — a spline over a fixed knot set, built in
   `Patch::compute_environment` from the summed competition of every cohort.
2. **The soil moisture vector** `θ` — five numbers, and the uptake vector `U` that
   depletes it.

Everything else is per-cohort and independent. Concretely, `Patch::compute_rates`
(`patch.h:575`) does:

```
for each species s:  s.compute_rates(env, pr_survival, birth_rate)   # per-cohort work
for i in 0 … ode_size()-1:
    U_i = ( Σ_s  Species_s.consumption_rate(i) ) / area
env.compute_rates(U)                                                  # soil rates
```

So the cohort-to-soil interface is a vector of length `ode_size()`, **regardless of how
many cohorts there are**. In the reverse pass this means the adjoint of the entire cohort
population reaches the soil through nine numbers, and the soil reaches the entire
population through five. That is what makes a hand-built coupling Jacobian tractable: it
is small in the direction that matters and the per-cohort work fans out from it.

---

## 3. The soil, forward

Per layer `i`, with the retention and conductivity curves as develop writes them
(`tf24_environment.h`), and noting that develop supports **per-layer** parameter vectors
(`a_psi_layers`, `n_psi_layers`, `soil_moist_sat_layers`) with the scalars as fallback:

```
ψ_i(θ_i)  = a_ψ,i · (θ_i / θ_sat,i)^(−n_ψ,i) / 1e6                     [MPa]
            evaluated at max(θ_i, θ_r), θ_r = soil_moist_residual = 1e-2
K_i(θ_i)  = K_sat · (θ_i / θ_sat,i)^(2 n_ψ,i + 3)
```

With develop's defaults `n_ψ = 6.57`, so the retention exponent is −6.57 and the
conductivity exponent is ≈ 16.14.

The balance, and this is the whole soil model:

```
infiltration = rain(t) · max( 0, 1 − a_infil · (θ_0/θ_sat,0)^b_infil )
w_in,0 = infiltration
w_in,i = K_{i−1}(θ_{i−1})                       # drainage cascade, downward only
rate_i = ( w_in,i − K_i(θ_i) − U_i ) / dz_i
if θ_i ≤ θ_r  and  not (rate_i > 0):  rate_i = 0     # positivity guard
dθ_i/dt = rate_i
```

Three things to notice, all of which come back later.

**There is no upward flux between layers.** A layer only receives water from the layer
above. Any upward movement in this model happens *inside the plant*, because per-layer
uptake is signed (§4.2).

**The positivity guard is written `!(rate > 0)`, not `rate < 0`.** That is deliberate: it
makes the guard fire on `NaN` as well, because `NaN < 0` is false in IEEE-754 but
`!(NaN > 0)` is true. Develop hardened this after a `NaN` uptake wrote straight into the
soil state.

**The infiltration term has a `max(0, ·)`.** At `a_infil = 1` and `θ_0 = θ_sat` the
bracket is exactly zero, so this is a kink at saturation, not merely a clamp far away.

---

## 4. One cohort, forward

This is the long section. It is where the coupling lives.

### 4.1 From height to the leaf's inputs

Given `h` and the shared light profile `L`, `net_mass_production_dt`
(`tf24_strategy.cpp:347`) assembles everything the leaf needs:

```
a        = area_leaf(h)                                  # cached aux
m_leaf   = mass_leaf(a);  A_sap = area_sapwood(a);  m_sap = mass_sapwood(A_sap, h)
A_bark   = area_bark(a);  m_bark = mass_bark(A_bark, h);  m_root = mass_root(a)

κ        = K_s · θ_huber / (h · η_c)                     # leaf-specific conductance max
v        = θ_huber · h · η_c                             # sapwood volume per leaf area
η_c      = 1 − 2/(1+η) + 1/(1+2η)                        # from pars.eta, in prepare_strategy
```

Root mass is distributed over layers by the **same cumulative shape function** used for
the canopy, but parameterised over depth and with its own exponent:

```
d_root   = min(h, 1.5)                                   # rooting depth, capped
scale    = 83.26 · 0.5 · m_root
prev = 1
for a = 0 … n_layers−1:
    if prev == 0: break
    q_a = Q(z_a, d_root, root_depth_shape_eta)            # fraction of roots below z_a
    mass_root_prop[a] = scale · (prev − q_a)
    prev = q_a
```

Then the light aggregation. Develop offers three shading models; **mean-light is TF24's
default** and is the only one described in detail here:

```
CrownCentre:  one leaf solve at  L(h · η_c)
MeanLight:    one leaf solve at  ∫₀^h max(L(z), 1e-4) · q(z,h) dz      # q integrates to 1
DeepCrown:    one leaf solve per Gauss-Kronrod node, outputs q-weighted and integrated
radiation  =  k_I · max(light, 1e-4) · PPFD
```

`MeanLight` is a Gauss-Kronrod integral of the light profile over the crown, so the
radiation driving one cohort's leaf depends on **many** light knots, not one. Its reverse
form has three parts: the knot values it reads, the `q(z,h)` weighting, and the upper bound
`h`, which is itself an active state. Recording the interpolation and the quadrature inside
the cohort's own block puts all three on that block's tape, so the aggregation's adjoint is
not written out here — `../archive/build-plan.md` §2.3 declares the block's inputs as the knot data rather
than sampled light for exactly this reason.

### 4.2 The leaf solve

Everything above is closed-form algebra. The leaf is not: the cohort *chooses* an
operating point. Write `p` for the root-collar water potential magnitude.

```
Objective, for a candidate p:
    σ(p)   = P( E_up(p)/κ + S_t(p) )                     # stem potential; P, S_t are C² splines
    ci(p)  : root of  A_net(ci)·u = γ_c(σ,p)·(ca − ci)·inv_atm      # inner root-find, TOMS748
    Π(p)   = A_net(ci(p)) − C(σ(p))                      # carbon profit
             A_net(ci) = colimited gross − R_d           # NOTE: net, R_d subtracted inside
             C(σ)      = g1 · (1 − exp(−(σ/b)^c))^β₂     # hydraulic cost

Per-layer uptake, at any p:
    E_i(p) = ( p − ψ_i − g_i ) / ( a · r_R,i )            # Ohm's law, signed
             g_i   = 9.8e-3 · z_mid,i                     # gravitational head [MPa]
             r_R,i = r_H,i · span_i / ∫_i  +  r_V,i
             span_i = |p − ψ_i| ,  ∫_i = cumulative vulnerability integral over the span
    E_up(p) = Σ_i E_i(p)                                  # converted to kg

Feasible interval (prepare_collar_solve):
    b_a : the p at which E_up(p) = 0                      # root-find, TOMS748, tol 1e-4
    b_b = max( root_crit, root_ψ_crit )                   # root-find + closed form

The choice:
    p* = argmax_{p ∈ [b_a, b_b]} Π(p)                     # golden section, GSS_tol_abs = 1e-3
```

Then the outputs, of which exactly two kinds matter downstream:

```
Π* = Π(p*)                    → carbon
c_i = E_i(p*)                 → water, per layer     [soil_consumption_, mol H₂O m⁻² s⁻¹]
```

plus five diagnostics (`opt_psi_stem_`, `root_collar_psi_`, `transpiration_`, `E_up_`,
`stom_cond_CO2_`) that reach aux slots only.

**Two subtleties that are easy to miss and both matter for the map.**

*The leaf area cancels in the water channel.* `E_i` carries a `1/a`, and
`evapotranspiration_dt(a, i) = soil_consumption_[i] · a`. So the per-cohort water draw is
`(p − ψ_i − g_i)/r_R,i` with **no leaf-area factor at all**. Leaf area reaches the water
channel only indirectly, through `p*` and through `r_R,i`'s dependence on root mass.

*`soil_consumption_` and `E_up_` carry different units by design* — the former stays in
mol, the latter is converted to kg. Anything that forms a Jacobian across the pair has to
respect that.

### 4.3 From the leaf to the rates

```
assim   = Π* · a · 60·60·12·365 / 1e6                    # to mol yr⁻¹, 12 h daylength
resp    = respiration(m_leaf, m_sap, m_bark, m_root)
turn    = turnover(m_leaf, m_bark, m_sap, m_root)
P_net   = a_bio · a_y · (assim − resp) − turn            # net mass production
```

Now the storage block (`tf24_strategy.cpp:187–252`), which is where develop differs most
from older descriptions of TF24:

```
S_max   = a_st1 · m_sap                                  # capacity scales with sapwood
r       = min( max(S,0) / S_max , 1 )                    # relative reserves, in [0,1]
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

**Read what has happened here, because it removes a problem that older accounts of this
model treat as central.** The hard `if (net_mass_production > 0) … else all rates zero`
switch is **gone from develop**. It has been replaced by two declared smoothing scales:
`storage_prod_eps = 1e-4` smooths the positive part of net production, and
`storage_gate_width = 0.1` smooths the reserve gate. Mortality no longer reads
instantaneous productivity — which was unbounded — but bounded relative reserves, giving
`dM/dt ∈ [d_I + a_dG1·e^{−a_dG2}, d_I + a_dG1]`. Develop's own comment attributes the
`#550` blow-up to the old form and this to its fix.

So the carbon side of TF24 has *already* had the "what gradual process is this switch
standing in for" treatment applied, and the answer was reserve dynamics. Any proposal to
mollify a growth gate in TF24 is proposing something develop has done.

### 4.4 The demographic states

```
ℓ:   dℓ/dt = − ∂g/∂h  −  dM/dt
     where ∂g/∂h comes from a finite-difference stencil, NOT closed form:
        growth_rate_gradient() perturbs height on a thread-local scratch Individual
        and calls growth_rate_given_height(h ± eps), eps = node_gradient_eps = 1e-6,
        one-sided (node_gradient_direction = −1) by default.
Φ:   dΦ/dt = dF/dt · exp(−M) · pr_patch_survival / pr_patch_survival_at_birth
```

The stencil is the transport (compression) term of the size-density equation. Note what it
costs: `growth_rate_given_height` runs a **complete** rate evaluation, leaf solve
included. So each cohort's `dℓ/dt` requires a second leaf solve per RHS evaluation.

And birth:

```
pr_estab = establishment_probability(env)
         = net_mass_production_dt(env, h_0, a_0) > 0
             ? 1/((a_d0·a_0/P_net)² + 1) · exp(−recruitment_decay · t)
             : 0                                        # ← hard switch, un-smoothed
ℓ(birth) = g > 0 ? log(birth_rate · pr_estab / g) : log(0)
M(birth) = −log(pr_estab)
```

### 4.5 Water aggregation

```
Individual.consumption_rate(i)  = c_i · a                            # the a that cancels
Node.consumption_rate(i)        = Individual.consumption_rate(i) · n ,  n = exp(ℓ)
Species.consumption_rate(i)     = size() < 2 ? 0
                                : trapezium( heights_ascending, per_node_values )
U_i                             = ( Σ_species … ) / area
```

Then `U` closes the loop into §3, and `θ` feeds back into `ψ` and hence every leaf solve.

### 4.6 The census functional

```
Ψ  =  Σ_species  trapezium over cohorts of  n_k · ψ(state_k)
```

for `ψ` = leaf area (→ LAI), above-ground mass (→ biomass), or stem basal area. Note
`n_k = exp(ℓ_k)` appears **linearly**, so the transport term of §4.4 is on the gradient
path of every census metric. R0 / offspring is `Σ Φ` and carries no density factor, which
is why the two functionals have genuinely different sensitivity structures.

### 4.7 TF24f, in one paragraph, because it changes the problem

TF24f (`tf24f_strategy.cpp`) makes the collar potential **an ODE state** rather than an
argmax. `solve_leaf()` evaluates the leaf at the tracked `p̃` (clamped into
`[b_a, b_b]`), reads back `∂Π/∂p` at the clamped point, and `compute_rates` sets
`dp̃/dt = k_acclim · ∂Π/∂p` — gradient ascent, seeded at the true optimum at birth. This
is worth staring at: **TF24f has already dissolved the argmax.** A state's derivative
arrives from the adjoint ODE for free; there is no implicit-function solve and no
stationarity condition to differentiate. The price is a lag (`k_acclim`-dependent), an
extra state per cohort, and a clamp whose active set can change. TF24f is not
bit-compatible with TF24 and is not trying to be.

---

## 5. The forward pass, all together

```
──── once per RHS evaluation ────────────────────────────────────────────────
build L(z) = exp(−Σ_k n_k · comp(h_k))                    # one spline, 33–129 knots;
                                                           # the knots hold L, not the sum
ψ_i ← retention(θ_i)                                       # 5 numbers, cached
for each cohort k:                                         # independent given (L, ψ)
    x_k ← geometry(h_k), root distribution, κ, v
    r_k ← ∫ light over crown  (mean-light)
    p*_k ← argmax Π( · ; ψ, x_k, r_k, φ)                   # golden section + 2 root-finds
    Π_k, c_{k,i} ← leaf outputs at p*_k
    P_net,k ← a_bio a_y (Π_k a_k C − resp) − turn
    growth_k ← P_pos(P_net,k) · G(r_k^storage)
    rates for h, F, A_hw, m_hw, S, M
    ∂g/∂h  ← FD stencil                                    # a SECOND full leaf solve
    dℓ_k/dt ← −∂g/∂h − dM/dt
U_i ← Σ_k n_k c_{k,i} w_k / area                           # trapezium in height
dθ_i/dt ← (w_in,i − K_i − U_i)/dz_i
────────────────────────────────────────────────────────────────────────────
```

---

## 6. The reverse pass

Now the point of the exercise. We want `dΨ/dφ` for a trait vector `φ`, where `Ψ` is a
census metric at some time (or `Σ Φ` for offspring).

### 6.1 The frame

Write the whole state as `y = (θ, {h,M,F,A_hw,m_hw,S}_k, {ℓ,Φ}_k)` and the RHS as
`dy/dt = F(y, φ, t)`. Reverse mode over the ODE carries an adjoint `λ(t)` backwards:

```
λ(T) = ∂Ψ/∂y |_T
dλ/dt = − (∂F/∂y)ᵀ λ
dΨ/dφ = ∂Ψ/∂φ + ∫_0^T (∂F/∂φ)ᵀ λ dt
```

Everything below is about the structure of `(∂F/∂y)ᵀ λ` and `(∂F/∂φ)ᵀ λ`. We never need
`∂F/∂y` as a matrix — only its action on a covector. That distinction does most of the
work.

### 6.2 The leaf's contribution, derived

**Report 02 §6 is the design this derivation became; read it for what the leaf hands back
and how each row is obtained.** What follows is the derivation, which is what makes that
design checkable rather than a list.

Adjoints arrive at the leaf's two output kinds: a scalar `Π̄_k` and a five-vector
`c̄_{k,i}`. We must push them back to `ψ`, to `x_k` (the geometry/light inputs), and to
`φ`.

**Step 1 — the carbon row is an envelope row.** `Π_k = Π(p*_k)` with `p*` a maximiser, so
`∂Π/∂p = 0` there and

```
Π̄_k contributes:   ψ̄_j += Π̄_k · ∂Π/∂ψ_j |_{p* frozen}
                    x̄_k += Π̄_k · ∂Π/∂x_k |_{p* frozen}
                    φ̄   += Π̄_k · ∂Π/∂φ   |_{p* frozen}
```

with **no argmax derivative anywhere**. This is the envelope theorem and it is free.

**Step 2 — collapse the five flux adjoints onto one scalar.** The fluxes are *not* at a
stationary point of anything, so they do need the argmax's motion. But look at the shape:

```
c_{k,i} = E_i(p*_k ; ψ_i, …)
d c_{k,i} = ∂E_i/∂(·) |_{p*}  +  (∂E_i/∂p) · d p*_k
```

`p*_k` is **one scalar shared by all five layers**. So in reverse mode, define

```
s_k = Σ_i  c̄_{k,i} · ∂E_i/∂p |_{p*}                       # ONE number per cohort
```

`s_k` is the adjoint of the operating point. Everything the five flux rows want from the
argmax is contained in it.

**Step 3 — one scalar solve.** Differentiate the condition that defines `p*`, namely
`∂Π/∂p = 0`, by the implicit function theorem:

```
d p*/d(·) = − (∂²Π/∂p∂(·)) / Π_pp ,        Π_pp = ∂²Π/∂p²
```

Substituting into step 2 and grouping:

```
μ_k = − s_k / Π_pp                                        # ONE divide per cohort
```

**Step 4 — the explicit flux channel, which is closed form and diagonal.** `E_i` reads
`ψ_i` and its own layer's resistance only:

```
ψ̄_j += c̄_{k,j} · ∂E_j/∂ψ_j |_{p*}                        # diagonal in the layer index
x̄_k += Σ_i c̄_{k,i} · ∂E_i/∂x_k |_{p*}
```

**Step 5 — the argmax channel, as one gradient of one scalar function.** Its input side
factors: `∂Π/∂p` reads the potentials, the per-layer root masses and the leaf area only
through the soil-to-collar flux and its collar derivative, so this gradient is two scalars
times closed-form vectors however many layers there are (report 02 §6.3).

```
(ψ̄, x̄, φ̄) += μ_k · ∇_{ψ,x,φ} ( ∂Π/∂p ) |_{p*}
```

This is the step that changes the cost picture, and it is the reason to write the reverse
pass out rather than reason about the forward one. Every previous treatment of this
coupling asks for `dp*/dθ` as a **Jacobian**:
five columns for the soil, up to fifty for traits. In reverse mode that object never
appears. What appears is `μ_k` (a scalar) times the **gradient of the scalar function
`∂Π/∂p`**, whose cost is *independent of the number of traits*. `∂Π/∂p` is already
available in closed form on develop (`Leaf::dprofit_droot_collar_psi`: forward-mode AD of
the assimilation and cost algebra, the implicit function theorem at the `ci` root-find,
and analytic spline derivatives for the transport). Differentiating that expression once
gives the entire argmax channel for every input at once.

### 6.3 Pulling back through the aggregations

**Water.** `U_i = Σ_k n_k c_{k,i} w_k / area` with `w_k` the trapezium weights. So

```
c̄_{k,i} = Ū_i · n_k · w_k / area
ℓ̄_k    += Σ_i Ū_i · c_{k,i} · w_k / area · n_k            # since ∂n/∂ℓ = n
h̄_k    += Σ_i Ū_i · n_k · c_{k,i} · ∂w_k/∂h_k / area      # the quadrature-weight term
```

That last line is a term it is easy to forget: the trapezium's weights are built from the
cohort *heights*, so a trait that moves heights moves the quadrature, not just the
integrand.

**Light.** Each cohort's radiation is an integral of `L` over its crown, and `L` is built
from every cohort's competition. So this block is dense across cohorts but of rank equal
to the knot count — a genuine all-to-all, handled once per step rather than per pair.

**Soil.** `dθ_i/dt` depends on `θ_{i−1}` (drainage in), `θ_i` (drainage out, retention)
and `U_i`. So `∂(soil rates)/∂θ` is **bidiagonal** — lower bidiagonal, because the cascade
is downward only. Its transpose is upper bidiagonal. No linear solve is needed anywhere.

**Census.** `∂Ψ/∂ℓ_k = n_k ψ(state_k) w_k`, `∂Ψ/∂state_k = n_k ∂ψ/∂state_k w_k`, plus the
quadrature-weight term again.

---

## 7. Where every partial goes

The deliverable. Read §8 before relying on it.

### Free — no work at all

| partial | why |
|---|---|
| `dθ/dφ` | soil moisture is ODE state, so its parameter sensitivity is carried by the adjoint ODE. No freezing decision, no recording, no choice to make. |
| `dψ_i/dθ_i` | closed form, `−n_ψ ψ/θ`, and correctly **zero** where the curve is floored at `θ_r`. |
| `∂(soil rates)/∂θ` | bidiagonal by construction (downward cascade only). Transposing a bidiagonal is free. |
| `dp̃/dφ` **in TF24f** | the collar potential is state, so the adjoint carries it. TF24f pays no implicit-function cost at all. |
| the four cumulative-flux soil states | write-only; nothing reads them, so their adjoints are identically zero. |

### Blocked — provably zero, so the channel is deleted

| partial | why |
|---|---|
| `∂Π/∂p` at `p*` | envelope theorem: `p*` maximises `Π`, so the argmax channel contributes **nothing** to the carbon output. This deletes the largest-looking term in the whole map. |
| the golden-section search's internals | never differentiated. For a fixed comparison pattern the returned argmax is an exact affine function of the bracket endpoints and independent of the objective's *values*, so taping it would yield the derivative of the bracket, not of the argmax. |
| `ℓ_k →` own cohort's physiology | density enters *nothing* in `TF24_Strategy::compute_rates`. It reaches the world only through `U` and through `L`. |
| `∂(anything)/∂C_{1..4}` | the cumulative-flux accumulators are never read. |

### Split — a block that looks dense and is not

| partial | structure |
|---|---|
| `∂c_{k,i}/∂ψ_j` | **diagonal + rank one**: diagonal because `E_i` reads only its own layer's `ψ_i`; rank one because all five layers share the single scalar `p*_k`. |
| cohort ↔ soil | rank `ode_size()` = 9. The whole population talks to the soil through nine numbers. |
| cohort ↔ cohort | via the light spline, **and via the boundary node one stage later**. `Species::compute_competition` closes its trapezium on `new_node` (`species.h:220-223`), whose density is `log(birth_rate · pr_estab / g)` at the current field — so cohorts also reach each other through the boundary condition, at every stage and not only at introductions. The rank is the knot count, which is **not fixed** on develop: `introduce_new_node` passes `rescale = false`, so the refiner re-chooses the fraction set at each of the 141 introductions and the count runs 33 to 129, mean 58.4 (report 03 §1b). `../archive/build-plan.md` §2.6 fixes the fractions, at which point the rank is 65 values plus 65 slopes. |
| the trait channel | separable from the state channel, and both are pulled back by the *same* `μ_k`, so adding traits does not add solves. |
| a trait read **twice**, once per cohort and once by the field | `k_I` is the absorption coefficient in `radiation = k_I · L · PPFD` and the extinction coefficient in `comp(z) = k_I · a · (1 − u^η)²`; `η` is the crown quadrature weight, `η_c`, *and* that same shading kernel. Both contributions are wanted and they arrive in different steps of the reverse pass, so the trait adjoint is a sum over steps as well as over cohorts. |

### Solved — an implicit relation, differentiated by its defining condition

| quantity | condition | cost |
|---|---|---|
| `p*` (TF24) | `∂Π/∂p = 0` | one scalar divide by `Π_pp`, then one gradient of `∂Π/∂p` |
| `ci` | the stomatal supply–demand balance | already done in develop inside `dprofit_droot_collar_psi` |
| `σ` (stem potential) | the transport splines | analytic spline derivatives, already in develop |
| `h_0` (birth height) | `height_seed()`'s root-find | one implicit-function node; a trait reaches birth size through it |

### Sidestepped — needed in principle, not on the production path

| partial | evidence |
|---|---|
| `db_a/dφ`, `db_b/dφ` (bracket-pinned regimes) | pinning incidence measured **zero** in 10,153 cohort-time records at production lifetime, and zero on a drydown reaching `ψ_soil = 3.74 MPa`. The two bracket root-finds still run forward; their derivatives are never wanted. |
| the zero-flux branch, the `psi_crit` shutdown, root-mediated redistribution | all measured unreached; `E_up < 0` never occurs. |
| the soil clamps and the runoff kink | not reached on the sampled envelope. |
| `dp*/dφ` as a **matrix** | replaced by one scalar and one gradient (§6.2 step 5). |
| the whole argmax in **TF24f** | it is state. |

### Curvature — measured, and the solve is well conditioned

`Π_pp` is the denominator of the whole argmax channel, so §6.2 step 3 stands or falls on
it. Measured (`scripts/curvature_probe.R`): a central difference of develop's analytic
`dprofit_droot_collar_psi` about the solved operating point, at `GSS_tol_abs = 1e-10`, over
the argmax's whole feasible domain — `psi_soil` from the default driver's 0.015–0.17 MPa
down to the stem's `psi_crit = 7.085`, four heights, five heterogeneous profiles.

**`Π_pp` is negative at 52 of 52 states, with `|Π_pp|` from 0.1723 to 15.61 (median 4.2).**
The failure mode of `−s_k/Π_pp` is `Π_pp → 0`, a fold; nothing in the domain comes near it,
and the worst amplification of a flux adjoint through the divide is **5.8×**. So the
one-scalar solve needs no bracketed fallback and no second-order safeguard.

The objective is gently curved, not sharply peaked. One consequence is worth stating
because it is the next thing to measure: with `Π_pp ≈ −4`, displacing `p*` by `1e-4` should
move `∂Π/∂p` by about `4e-4`, and §9 measures 11–23 at `GSS_tol_abs = 1e-3`. So the search
error at production tolerance is not `1e-4`, or those states are in the bound-pinned regime
below. That is a question about `golden_section_max`, not about the geometry, and it does
not touch §6.2's derivation.

### The interior / bound-pinned selector

The same sweep finds the operating point in two regimes, and they need different treatment:

| regime | count | |
|---|---|---|
| stationary interior maximum (`\|∂Π/∂p\|` at the solver floor) | **37 / 52** | §6.2 applies as written |
| **pinned at a bound** (`\|∂Π/∂p\|` = 0.054 … 2.12 at tolerance `1e-10`) | **15 / 52** | `p*` *is* the bound, so `dp*/d(·)` is the bound's derivative — analytic |

Every pinned state is at `psi_soil ≥ 1.5 MPa` **and** `height ≥ 2 m`: dry and tall. None is
inside the default driver's `psi_soil` range, which is why §9's production census finds zero
corner incidence; the committed stress banks reach 1.5+ MPa, so the regime is live there.

The selector is a comparison on `|∂Π/∂p|` against the solver floor, available where the
search returns. It is a discrete branch on the gradient path, so it belongs in the kink
manifest with its incidence.

### Genuinely open — the map does not dispose of these

| partial | status |
|---|---|
| `∂g/∂h`, the transport stencil | computed by finite difference, and it is on the gradient path of **every census metric** because `Ψ` carries `n_k = exp(ℓ_k)`. It is *not* on R0's path. This is report 4's subject. |
| `∂(pr_estab)/∂φ` through the birth switch | `establishment_probability` still carries a hard `if (P_net > 0) … else 0`, un-smoothed, and it multiplies into `ℓ(birth)` and `M(birth)` — hence into every census metric. Develop smoothed the *growth* gate and left this one. |
| `∂r/∂S` at the `max(S,0)` clamp | **active on 13.96%** of production records (§9b), and it zeroes the carbon → mortality → survival → density channel on all of them. Not the coupling, but squarely on the census gradient. |
| the **interior / bound-pinned selector** | a discrete branch on the gradient path: `|∂Π/∂p|` against the solver floor decides whether §6.2's interior solve or the bound's analytic derivative applies. Incidence 15 of 52 across the argmax's feasible domain, all dry and tall. Needs a manifest row. |
| `∇(∂Π/∂p)` | the one genuinely new expression the design needs. |

---

## 8. Adversarial review of the map

An oversimplified dependency map is worse than none, because it licenses deleting channels
that are load-bearing. Here is where §7 is most at risk. Each item is a way the map could
be **wrong**, not merely incomplete.

**1. "Diagonal in the layer index" is not quite true.** `r_R,i` depends on
`span_i = |p − ψ_i|` and on the vulnerability integral over that span, so `∂E_i/∂ψ_i`
carries a term through `r_R,i` as well as through the numerator. It is still diagonal —
layer `i`'s resistance reads only `ψ_i` and `p` — but it is not the simple
`1/(a·r_R,i)` that the Ohm's-law form suggests, and treating it as such would be wrong at
the ~`∂r_R/∂ψ` level. The absolute-value also means `span` has a kink at `p = ψ_i`.

**2. The `max(light, 1e-4)` clamp is inside the crown integral.** So a deeply shaded
cohort's radiation is a *constant* with respect to every other cohort's height. That is a
blocked channel — but the count is now zero. `L` over the field is minimised at the ground by
construction (`L = exp(-A)`), and its measured minimum is **0.1657209** against a floor of `1e-4`:
0 of 8 292 knot values at or below it, and 0 of 141 introduction steps over the seedling crown.
Reaching the floor needs `A ≈ 9.2` against a maximum `A(0)` of 1.797. So the light coupling is
live everywhere it matters, and this row is a hazard for a drier stand rather than for this one.

**3. The trapezium weights depend on state.** §6.3 notes it, and it is the term most
likely to be dropped by someone writing this by hand, because the forward code hides it
inside `util::trapezium(heights, values)`. Both `U_i` and `Ψ` inherit it.

**4. `Species::consumption_rate` returns exactly `0.0` when `size() < 2`.** So a species
with a single cohort draws **no water at all**, and the water channel switches on
discontinuously at the second cohort. This is a discrete event in cohort count, it is not
in anyone's kink inventory, and it happens at the start of every run.

**5. The `Leaf` is shared through the strategy pointer, and develop does not clear it on
every exit.** `set_shutdown_state` on develop sets `root_collar_psi_`, `opt_psi_stem_` and
`profit_` but **does not clear `soil_consumption_` or `E_up_`**; `set_physiology` calls
`resize`, which leaves existing elements untouched at an unchanged layer count. So a
cohort taking a shutdown exit contributes the *previous* cohort's water draw to the
balance. That is a forward-model defect on develop, and for the map it means the
per-cohort independence claimed in §5 has an exception whenever a shutdown fires. (It is
measured unreached on the sampled envelope — which is the only reason the map survives —
but "unreached" and "safe" are different claims.)

**6. DeepCrown breaks the rank-one structure.** With one leaf solve per quadrature node,
each with its **own** `p*`, the per-cohort argmax channel becomes rank ~21, not rank one.
Everything in §6.2 still holds per node, but the cost claim does not. Mean-light is the
default; deep-crown is a supported option and the map should not silently assume it away.

**7. `rooting_depth = min(h, 1.5)` is a kink in height,** and the root-distribution loop
`break`s when `Q` hits zero, which is a discrete change in how many layers receive roots.
Both sit directly on the `h → water` path.

**8. Three new non-smooth points arrived with the storage block, and one of them is
heavily populated.** `max(S,0)` and `min(S/S_max, 1)` are clamps on `r`, and
`dS/dt = net_flux > 0 ? net_flux : floor_gate · net_flux` is continuous in value but
**kinked in derivative** at `net_flux = 0`, since the two arms have slopes `1` and
`floor_gate < 1`. Measured on develop, the `max(S,0)` clamp is active on **13.96%** of
cohort-time records, because storage genuinely goes negative (minimum `−2.2e-3` against a
median of `1.8e-4`) — see §9b. So the map must not report the carbon side as smooth, and
must not assume `S ≥ 0`, which develop's own comment asserts and the run refutes.

**9. `mortality_dt` branches on `is_finite(cumulative_mortality)`,** returning `0` when
mortality has saturated. That is a switch on a state, and its active set changes during a
run.

**10. The `psi_soil_cache_` is keyed on an exact `double` comparison of the soil state.**
It is invalidated on parameter changes, but a cache keyed on bit-equality is a hazard for
anything that perturbs state slightly — including a finite-difference verification of the
very gradient this map is for.

**11. The envelope argument depends on `p*` actually being stationary.** Measured, it is —
`|∂Π/∂p| ~ 10⁻⁶` at a well-located optimum on the production envelope. But at develop's
`GSS_tol_abs = 1e-3` the *returned* point sits `~1e-4` away, where `∂Π/∂p` is 10–23. The
envelope theorem protects `Π` (the error is second order in the displacement), and it does
**not** protect the fluxes. So the map's "blocked" row for the carbon channel is safe at
production tolerance while the "solved" row's linearisation point is not. Those are
different exposures to the same tolerance and conflating them is exactly the error the
previous report made.

**12. Two cohorts can coincide in height.** `trapezium` over coincident nodes and
`growth_rate_gradient`'s `1e-6` probe interact badly in that limit; the map treats cohort
spacing as generic.

**13. `establishment_probability` calls `net_mass_production_dt`,** which runs a *full leaf
solve* on the shared `Leaf` at birth size. So the birth path mutates the same shared
object the cohort loop uses, and it does so at a different `h`. Ordering matters.

**14. The map assumes the operating point is interior everywhere it matters.** §9's
production census finds zero corner incidence at the default driver, and the curvature sweep
shows why that was the wrong place to look: the bound-pinned regime is dry **and** tall,
outside the default driver's `psi_soil` range and inside the stress banks'. §6.2 covers the
interior case; the bound case needs its own branch. `Π_pp` itself is measured and never near
zero, so the interior solve is safe.


---

## 9. Measured, versus inferred, versus branch-measured

The provenance rule matters here because this report replaces one that got it wrong.

**Read directly from develop `141dc8df` this session:** the state vectors and their sizes;
the soil balance, retention and conductivity curves with per-layer parameter support and
the `!(rate > 0)` guard; the leaf solve's structure, `prepare_collar_solve`'s two
root-finds and the golden-section call at `GSS_tol_abs = 1e-3`; the three shading models
and the `1e-4` light floor; the root-mass distribution with its `min(h, 1.5)` cap and
early `break`; the storage block with `a_st1/a_st2/a_st3`, `storage_gate_width = 0.1`,
`storage_prod_eps = 1e-4`, and storage-dependent bounded mortality; the un-smoothed switch
in `establishment_probability`; the transport stencil with `node_gradient_eps = 1e-6`,
one-sided, Richardson off; the aggregation chain `Individual → Node (×density) → Species
(trapezium, 0 for size<2) → Patch (/area) → Environment`; `set_shutdown_state`'s failure
to clear `soil_consumption_`; TF24f's tracked state, `k_acclim = 1`, and its correct
seeding of the storage pool.

**Measured, but on the forward path only, against functions verified byte-identical to
develop:** the operating point is `bound_a` in a single-layer configuration and the offset
equals `grav_head_z_[0]` exactly; the zero-flux branch's `ci` is `gamma_25 ×
umol_per_mol_to_Pa = 4.330575` where net assimilation is exactly `−R_d`; the transpiring
branch's `gc → 0` limit is the root of `A_net = 0` at `5.490638`, obtainable in closed form
as a quadratic; the profit jump across the boundary is exactly `R_d`; zero incidence of
that branch in 10,153 production records; minimum margin `0.03472 MPa`; `E_up < 0` never;
`ψ_soil` range `[0.015, 0.17] MPa` on the default driver and up to `3.74 MPa` on drydown.
`set_leaf_states_rates_from_psi_stem`, `prepare_collar_solve`, `find_root_collar_psi`,
`evaluate_root_collar_psi`, `profit_at_collar_psi` and `E_from_Soil_to_Root_Collar` were
compared function-body-by-function-body against develop and are identical, which is what
licenses carrying these numbers over.

**Re-verified on a develop build.** develop was compiled from the worktree and every
number that had been taken on the feature branch was re-run against it. All of them
reproduce, most to five digits:

| quantity | branch | **develop** |
|---|---|---|
| `∂Π/∂p` at `GSS_tol_abs = 1e-3` | 11.166 / 10.382 / −19.445 / 23.057 | **identical** |
| `∂Π/∂p` at `tol = 1e-12` | 1e-5 … 1e-7 | **1e-5 … 1e-7** (stationary) |
| `p*` displacement at `tol = 1e-3` | 1.03e-4 … 2.04e-4 | **identical** |
| `dp*/dψ` **[one layer at a time, 5 layers]** | 0.9320–0.9958 | **0.9329–0.9958** |
| `dp*/dψ` relative error | 0.39% / 3.68% | **0.39% / 3.68%** |
| `d(profit)/dψ` relative error | 0.006–0.9% | **0.006–0.9%** |
| **`d(consumption)/dψ` relative error** | **47.7–53.2%** | **47.6–53.2%** |

So the cancellation identity holds on develop: absolute error in `dp*/dψ` divided by
`(1 − dp*/dψ)` predicts the flux error to within its own noise (e.g. `0.0038269 / 0.0080286
= 47.7%` against 47.6% measured).

**`Π_pp` was later measured directly and is not `1.1 × 10⁵`.** A central difference of
`dprofit_droot_collar_psi` about the solved point gives `|Π_pp|` of **0.17 to 15.6 at five layers**
and **14.4 to 198 at twenty** (`../archive/build-plan.md` §8, `../../scripts/curvature_probe.R`), negative
at every state sampled. The ratio route is sound — at matched states `R`/displacement reproduces the
direct value to three or four digits — but the pair used here does not belong to one state: at five
layers over six production states `|R|` at `GSS_tol_abs = 1e-3` is 8.8e-05 to 1.2e-03, not 11–23.
So the `1.1 × 10⁵` above, and the `∂Π/∂p` of 11–23 it is computed from, are this configuration's
and reproduce nowhere else. Nothing in the design rests on either.

**Also re-run on develop, with two figures that changed:**

| | branch | **develop** |
|---|---|---|
| zero-flux branch incidence, life 105.32 | 0 | **0** |
| `E_up < 0` (redistribution) | 0 | **0** |
| minimum margin `psi_stem − |collar|` | 0.03472 MPa | **0.02688 MPa** (27× `GSS_tol_abs`; still none below 1e-2) |
| `net_mass_production_dt ≤ 0` | 0.80% | **14.04%** |

The last row is the storage block doing its job: on develop a cohort can sit at negative
net production for a long stretch, drawing reserves down, where the old hard gate zeroed
its rates and killed it. It is *not* a discontinuity count on develop, because `P_pos`
smooths it — see §9b.

**Still inferred, not measured:** `Π_pp`'s sign directly (it is inferred negative from
`p*` being a maximiser and from the sign of `g` either side); the incidence of the light
floor; the incidence of the `size() < 2` water switch; whether `∇(∂Π/∂p)` is well
conditioned anywhere.

**Inferred, not measured:** `Π_pp`'s sign and magnitude; the incidence of the light floor;
the incidence of the `size() < 2` water switch; whether `∇(∂Π/∂p)` is well conditioned
anywhere.

**Not claimed at all:** anything about FF16 or K93; anything about a transported-variable
change; the cost of the reverse pass, which depends on `∇(∂Π/∂p)` and has not been built.

## 9b. Develop's two smoothing scales, measured against what they smooth

A declared smoothing scale is only useful if it is comparable to the spread of its
argument. Much smaller and it is a hard switch wearing a smooth coat — and then its
derivative is a *spike*, which for a gradient is worse than the switch was. Both of
develop's scales were checked against a production run.

**`storage_prod_eps = 1e-4`, smoothing the positive part of net production.** Measured over
10,153 records:

| | |
|---|---|
| `\|P\|` median | 7.3e-2 |
| `\|P\|` 10th percentile | 3.0e-4 |
| `\|P\| < 1 × eps` | **360 (3.55%)** |
| `\|P\| < 10 × eps` | **2,964 (29.2%)** |
| `P ≤ 0` | 1,425 (14.0%) |
| `P ≤ −eps` | 1,395 (13.7%) |

So the smoothing region is genuinely populated — 3.6% of records sit inside one scale
length and 29% within ten. The scale is well chosen: not decorative, and not so wide that
it distorts the healthy population (median `|P|` is 730 scale lengths away). This is the
one place in TF24 where a mollification has been sized against data rather than guessed.

**`storage` goes negative, and the `max(S, 0)` clamp is active on 14% of records.**

| | |
|---|---|
| `storage` minimum | **−2.249e-03** |
| `storage` median | 1.756e-04 |
| `storage ≤ 0` | **1,417 (13.96%)** |

Develop's comment on `dS/dt` says the outflow gate "floors storage at zero so relative
reserves `r` stay in `[0,1]`". **It does not.** The gate `S/(S + 1e-3·S_max)` tends to zero
as `S → 0⁺`, but an explicit stepper overshoots, and once `S < 0` the expression is no
longer a gate at all: with `|S|` comparable to or larger than `gate_ref = 1e-3·S_max` — and
the measured magnitudes are comparable, since median storage is `1.8e-4` — the factor
approaches 1 or changes sign, so the deficit drains at full rate.

The consequence is bounded rather than catastrophic, and that is the `#550` fix working as
intended: `r = min(max(S,0)/S_max, 1)` clamps to `0`, so mortality sits at its finite
maximum `d_I + a_dG1 = 5.6 /yr` instead of spiking. But for the dependency map it matters
twice. The `max(S, 0)` clamp is a **derivative discontinuity active on 14% of records**, and
it zeroes the gradient through `r` on all of them — which is the channel from carbon into
mortality, and hence into survival, density, and every census metric. And the stated
invariant (`S ≥ 0`) does not hold, so anything built on it is unsound.

Neither of these is the leaf–soil coupling. Both are on the census gradient's path, and
neither is in any existing kink inventory.

---

## 10. What to do next, in order

**The live work list is `../archive/build-plan.md` §5–§6.** What follows is this report's own
reading of the order, kept because it is the map's conclusion rather than a plan.

1. **Build the bound branch and the regime selector** (§7). `Π_pp` is measured and well
   conditioned, so §6.2's interior solve is ready; what it lacks is its companion for the
   15-of-52 dry-and-tall states where `p*` is pinned.
2. **Fix the storage floor** (§9b). `S` goes negative and the gate the comment relies on
   stops being a gate there. It is a forward-model correctness item, it is cheap, and it
   removes a clamp that is active on 14% of records from the census gradient's path.
3. **Count the two uncounted switches** — the light floor and `size() < 2` — because both
   are currently assumed live or dead without evidence.
4. **Decide `establishment_probability`.** It is the only *hard* switch left on the carbon
   path and it sits on every census metric's gradient. Develop already smoothed its
   sibling and sized the scale against data (§9b), so both the precedent and the method
   exist.
5. **Then, and only then, build `∇(∂Π/∂p)`.** It is one derivative of one closed-form
   expression, it must include the `ci` root-find's own implicit-function term, and it is
   the single new piece of code the whole design needs.

A note on sequencing that the map makes visible: items 2–4 are all on the census
gradient's path and none of them is the leaf–soil coupling. The coupling's own defect is
now fully characterised (§9's cancellation identity) and its fix is item 5. If the goal is
a correct census gradient, items 2–4 are not a detour around the coupling — they are
channels of the same answer that no amount of work on the leaf will supply.

## 11. What would falsify this map

- **`Π_pp` is small somewhere reachable.** Then the argmax channel needs a bracketed
  fallback and §6.2 is not a one-line solve.
- **The operating point is not stationary on a real patch at production tolerance.** Then
  the envelope row is wrong and the carbon channel costs as much as the water channel.
- **The flux adjoint does not collapse onto one scalar** — i.e. `∂E_i/∂p` is not the only
  route from `p*` into layer `i`. Re-read `E_from_Soil_to_Root_Collar` for a second path.
- **The light floor is reached by most cohorts.** Then the light coupling is mostly
  blocked and report 3's accuracy target is over-specified.
- **Deep-crown is the intended production shading model.** Then the rank-one claim is a
  rank-21 claim and the cost arithmetic changes.
