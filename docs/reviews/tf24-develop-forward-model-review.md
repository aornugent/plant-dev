# Reports 05–07 against TF24@develop: what the forward model actually does

A review of the ecology and mathematics asserted in
[`05-reverse-mode-mathematics.md`](../reports/05-reverse-mode-mathematics.md),
[`06-what-the-gradient-means.md`](../reports/06-what-the-gradient-means.md) and
[`07-structure-worth-exploiting.md`](../reports/07-structure-worth-exploiting.md),
tested against `plant` at `origin/develop` (`7b5012c2`, TF24@v4).

Every number below was measured, not read. Scripts are transient; the commands that
produce each figure are named in the text so they can be re-run.

**§6 re-runs all of it against the leaf refactor** — `traitecoevo/plant` develop at
`74b10ed7` (TF24@v8), where the leaf model has moved out to the standalone `phylloptim`
package. Sections 1–5 are the review as first written, against `aornugent/plant`
`7b5012c2`; §6 says which findings survived, which were fixed, and what the refactor
changed.

---

## 0. What was tested, and how

`plant-dev`'s submodule pointer for `plant` is on the AD lineage, not on `develop`, so
the review used `origin/develop` directly. That pointer's `odelia` (`cc6571c`) does not
compile against `develop` — `odelia`'s `r_ode_rates` takes the system by const reference
there, and `develop`'s `Patch` evaluates rates in that call. `odelia` `master`
(`3bc605b`, "Take the System by mutable reference where the rates are read") is the
matching version; with it `make compile` is clean.

Method: read the whole TF24 path (`tf24_strategy.{h,cpp}`, `tf24f_strategy.*`,
`leaf_model.{h,cpp}`, `tf24_environment.h`, `canopy_shape.h`, `resource_spline.h`,
`node.h`, `species.h`, `gradient.h`), then drive it from R — the `Leaf` submodel
directly, individuals in constructed environments, and full `run_scm` runs — and compare
against the reports' claims.

**One framing point before the details.** Reports 05–07 are written about a
*birth-date-coordinate* reverse mode. TF24@develop integrates the **height coordinate
only**: `Node::compute_rates` sets `log_density_dt = -growth_rate_gradient - mortality`
(report 05's eq. 5.2) and `compute_initial_conditions` sets
`log_density = log(birth_rate * pr_estab / g)` — the boundary condition *with* the
division by growth rate. Every claim in the reports scoped to the birth-date coordinate
is therefore a claim about a discretisation that does not exist in this model, and the
reports are right to record (06 §11) that the two coordinates are different functions.
Claims about the height coordinate's *cost* do check out exactly: `node_gradient_direction
= -1` gives a one-sided difference reusing the computed rate (**1 extra solve**), and
`gradient_richardson` at `node_gradient_richardson_depth = 4` does 4 iterations × 2
evaluations (**8 solves**).

---

## 1. Defects in TF24@develop found while testing

### D1. `Leaf::dprofit_droot_collar_psi` throws in shade; TF24f cannot run a suppressed plant

**Reachable from the public API and fatal to the run.** A TF24f individual at 5 m on wet
soil (θ = 0.214) with canopy openness ≤ 0.0295 aborts:

```
psi_stem_to_ci failed: Error in function boost::math::tools::toms748_solve<double>:
Parameters a and b do not bracket the root: a=4.3305749999999996; min=4.330575;
max=40.000000; psi_stem=0.170872; psi_upstream=0.170867
```

| openness | `assim_max_` | `dprofit(collar = 1.0)` | `dprofit(optimum)` |
|---|---|---|---|
| 0.0500 | +0.96609 | −2.9988 | +0.0047639 |
| 0.0320 | +0.11585 | −3.0402 | +4.4658e−05 |
| 0.0305 | +0.04417 | −3.0423 | +0.0028501 |
| **0.0295** | **−0.00368** | **THROWS** | **THROWS** |
| 0.0200 | −0.46107 | THROWS | THROWS |

**Root cause.** The value path applies *two* substitutions in
`set_leaf_states_rates_from_psi_stem`: `psi_upstream >= psi_stem` (no flow) **and**
`assim_max_ < 0` (respiration exceeds the best possible gain), both setting
`ci_ = gamma_*umol_per_mol_to_Pa` with zero flux. `dprofit_droot_collar_psi` replicates
only the first (`if (!isfinite(psi_stem) || psi >= psi_stem) return 0.0;`) and then calls
`psi_stem_to_ci` directly. With `assim_max_ < 0` the residual `A(ci)·umol_to_mol −
gc(ca−ci)/(atm·kPa)` is negative at both bracket ends, TOMS748 reports no bracket, and
`util::stop` kills the run. The in-code comment above that guard describes fixing exactly
this failure for the no-flow case; the `assim_max_ < 0` case was left out.

The trigger is `assim_max_ < 0` alone, **not** proximity to a bound: it throws at a collar
potential in the middle of the feasible interval too.

Scope: `use_ad_gradient = true` is TF24f's default. The finite-difference fallback
survives, because it goes through `profit_at_collar_psi` → `profit_psi_stem_TF` →
the substitution — but it returns **exactly 0** there, which is report 05 §7.0's sentinel
zero: the tracked state simply freezes.

| openness | `use_ad_gradient = TRUE` | `use_ad_gradient = FALSE` |
|---|---|---|
| 0.05 | dψ/dt = 0.00476386 | dψ/dt = 0.00483308 |
| 0.02 | THROWS | dψ/dt = 0 |
| 0.001 | THROWS | dψ/dt = 0 |

Ecological scope: openness 0.0295 is `exp(-k_I·LAI)` at k_I·LAI ≈ 3.5, i.e. LAI ≈ 7 at
the default k_I. Below that the whole understorey is in the state that throws. A default
TF24f run survives only because the default stand reaches LAI 4.2 (ground light 0.12).

*Fix*: give `dprofit_droot_collar_psi` the same `assim_max_ < 0` exit as the value path,
returning the analytic derivative of the substituted expression (profit = −R_d −
Θ(psi_stem), so dΠ/dψ = −Θ′(psi_stem)·dpsi_stem/dψ) rather than 0, since that branch does
have a derivative. Add a test at openness 0.02.

### D2. At the operating point of a mature default stand, most cohorts are **not** at an interior optimum

The collar optimum leaves the interior and pins to the upper bound (the collar at which
the stem reaches `psi_crit`) at a soil potential well inside the model's normal range:

| θ | ψ_soil (MPa) | bound_a | optimum | bound_b | dΠ/dp at the optimum | kind |
|---|---|---|---|---|---|---|
| 0.214 | 0.1691 | 0.1709 | 1.7736 | 2.4306 | −1.23e−04 | S (interior) |
| 0.170 | 0.7673 | 0.7690 | 2.4092 | 2.7311 | +6.02e−04 | S (interior) |
| 0.160 | 1.1427 | 1.1445 | 2.8208 | 2.9316 | −4.00e−04 | S (interior) |
| 0.155 | 1.4078 | 1.4095 | 3.0788 | **3.0792** | **+0.12743** | **K (upper bound)** |
| 0.150 | 1.7462 | 1.7479 | 3.2748 | 3.2752 | +0.83827 | K (upper bound) |
| 0.130 | 4.4709 | 4.4727 | 5.2263 | 5.2267 | +4.47902 | K (upper bound) |

Interior/pinned boundary, by bisection: **ψ_soil = 1.34 MPa at 5 m**, and it moves the way
report 05 §7.0 predicts — taller plants pin earlier: 1.88 MPa at 1 m, 1.69 at 2 m, 1.34 at
5 m, 1.10 at 10 m.

A default `run_scm` (lma 0.0825, hmat 5, patch lifetime 20, rainfall 1 m/yr) settles at
**θ ≈ 0.143–0.155, ψ_soil ≈ 1.38–2.37 MPa** — past that boundary. Classifying the final
stand's 99 cohorts at the run's own soil state gives **62 pinned (K), 37 interior (S)**.

This is the forward-model fact behind report 05 §7.1's "single largest economy in the
design". The envelope theorem does not apply to the majority of a mature stand at the
default configuration, so the pinned branch (§7.4) is the main case, not the exception.
Report 06's "Sometimes the optimum is not interior" understates it. (The classification
held light at 1 to isolate the soil transition; real cohorts also sit in shade, which
pushes the optimum toward the *lower* bound — at openness 0.05 the optimum is 0.2988
against a lower bound of 0.1709.)

### D3. The R census helper has no ordering guard, and the error is measurable

The two C++ reductions sort when heights invert (`Species::compute_competition_unordered`,
`Species::consumption_rate`, #571/#574). `integrate_over_size_distribution` in
`R/tidy_outputs.R` does `-trapezium(height, density * .x)` on whatever order the tidy
frame carries.

Height inversion is not hypothetical on develop. A run started from θ = 0.10 (a legitimate
dry initial condition) inverts in **57 of 99 steps**, up to **18 inversions in one step**,
while producing 525 offspring. On the final step, the same state integrated as-ordered
versus height-sorted:

| census | as-ordered | height-sorted | error |
|---|---|---|---|
| Σ w n h | 22.997032 | 22.130695 | **+3.91 %** |
| Σ w n A_leaf | 4.2544257 | 4.0929236 | **+3.95 %** |
| Σ w n m_heartwood | 9.1955007 | 8.8415611 | **+4.00 %** |

Same cohorts, same densities, only the row order differs — so it is pure quadrature error
in the objective, before any derivative. Report 05 §9 and 06 §8 call this "the chain's
first link and the least guarded"; that is correct, and the number is ~4 % on this stand.
(The C++ light profile from the same run is monotone in 99/99 steps: the sorted fallback
works.)

### D4. The root vulnerability integral extrapolates linearly, and unbinds the wrong-way flux

Confirmed exactly as report 05 §6.2 describes, and quantified. The cumulative-vulnerability
knot grid ends where conductivity reaches 1 % (`build_cumulative_vulnerability_integral`,
`psi_max = b·log(1/0.01)^(1/c)`), i.e. **6.8918 MPa** for the root curve, which already
captures **99.856 %** of the whole integral (3.46078 of G(∞) = 3.46578). Beyond it the
spline extrapolates **linearly with slope 0.010360** (the exact integrand at the last knot
is 0.010001), so the integral grows without bound where the true one has converged:

| m (MPa) | spline | exact | ratio |
|---|---|---|---|
| 6.892 | 3.46078 | 3.46078 | 1.000 |
| 10 | 3.49298 | 3.46578 | 1.008 |
| 100 | 4.42541 | 3.46578 | 1.277 |
| 1000 | 13.74976 | 3.46578 | **3.968** |
| 3000 | 34.47052 | 3.46578 | **9.946** |

Consequence in the flux, measured on a real root system (10 m plant, 5 layers, collar at
−1 MPa, layer 1 wet):

| ψ of the dry layers | E per dry layer (mol m⁻² s⁻¹) | with the exact integral |
|---|---|---|
| 0.169 | +1.118e−06 | +1.118e−06 |
| 3 | −2.685e−06 | −2.685e−06 |
| 10 | −9.301e−06 | −9.261e−06 |
| 100 | −3.098e−05 | −2.294e−05 |
| 1000 (the ceiling) | **−1.396e−04** | −2.646e−05 |
| 3000 | −3.754e−04 | −2.676e−05 |

So the wrong-way (plant → soil) flux is **real in the model itself** — it starts as soon as
a layer is drier than the collar, around ψ ≈ 1 MPa, and with the exact integral it
saturates at a finite −2.7e−05 — and the extrapolation is what removes the bound: **4×
inflated at the ψ = 1e3 MPa ceiling**, and linear in the ceiling thereafter. Report 05's
mechanism ("the integral keeps growing past its grid rather than clamping … grows linearly
and negative … raising the ceiling makes it worse linearly") is right in every part.

Every "net" the report says would miss it does miss it, verified end-to-end on a live
plant (wet top layer at 0.30, four drier layers):

| θ of layers 2–5 | ψ (MPa) | uptake L1 | uptake L5 | **sum** | net production | dh/dt |
|---|---|---|---|---|---|---|
| 0.15 | 1.75 | 1.174e−03 | **−5.512e−07** | +1.149e−03 | 6.44 | 1.33 |
| 0.11 | 13.4 | 1.560e−03 | −9.439e−06 | +1.152e−03 | 4.30 | 0.885 |
| 0.08 | 108.6 | 2.033e−03 | −2.302e−05 | +1.099e−03 | 1.63 | 0.336 |
| 0.0571 | 995.2 | 4.765e−03 | −1.165e−04 | +8.165e−05 | −21.78 | ~0 |

A plant growing at dh/dt = 0.34 m/yr while pumping water into a 108 MPa layer, with a
positive total uptake the whole time — and drawing 4.4× more from the wet layer than it
did when the profile was uniform. Whole-plant shutdown is decided on the wettest layer
(`prepare_collar_solve`: `-wettest_soil_layer >= psi_crit`), exactly as reported.

**Incidence, which the reports overstate.** Reducing rainfall does *not* reach this region:
the stand self-limits, because plants stop transpiring as production goes negative and the
soil stops drying. ψ_max over the run:

| rainfall (m/yr) | offspring | ψ_soil max | past the root grid (6.89)? |
|---|---|---|---|
| 1.00 | 445.4 | 2.463 | no |
| 0.50 | 0.0290 | 4.538 | no |
| 0.25 | 1.1e−08 | 5.098 | no |
| 0.10 | 2.3e−10 | 5.185 | no |
| 0.05 | 3.2e−11 | 5.213 | no |
| 1.00, θ₀ = 0.10 | 525.3 | **25.061** | **yes** |

The extrapolated region is reached only from an initial condition drier than θ ≈ 0.122
(ψ = 6.89 MPa), and then only during the wetting transient. Report 05 §6.2's "its
reachability is ordinary, not extreme" is not supported for develop's default drivers; it
is an initial-condition and transient hazard.

### D5. Two derivations of the same vulnerability curve disagree — verified, with the ratios

Report 07 §3's claim, confirmed to the digit. C++ `TF24_Pars` derives `c` from `p_50` and
a fixed 88 %-loss anchor; `TF24_hyperpar` derives `p_50` from `K_s` and `c` from a
trade-off with `B_c2 = 0`:

| | C++ default | R hyperpar (K_s = 1) | ratio |
|---|---|---|---|
| p_50 | 1.850000 | 2.888726 | 1.5615 |
| c | 1.089985 | 2.040000 | **1.8716** |
| b | 2.589437 | 3.457268 | 1.3351 |
| psi_crit | 7.085493 | 5.919880 | 0.8355 |

`B_c2 = 0` makes the R-side `c` a constant (2.04 at K_s = 0.2 and at K_s = 5) — report 07's
"degenerating to a constant under one of its own settings". `jmax_25 = 1.64·vcmax_25` is a
fixed multiple in C++ while the R route takes it as an independent input; the unused
`vcmax_25_to_jmax_25 = 1.67` in `leaf_model.h` is a third value for the same ratio.

The two routes give a stem `psi_crit` differing by 1.17 MPa, which by D2 moves the
interior/pinned boundary — so this is not a cosmetic disagreement.

### D6. The curve carries three independent numbers for two degrees of freedom, and one is inert

- `pars$p_50 <- 3.5` changes nothing: `c` and `b` are default-member-initialisers evaluated
  at construction and `p_50` is never read again. Measured: c, b, psi_crit, height_0 all
  identical. Report 06 §7 and 07 §3 are right that "setting it in this model changes
  nothing".
- `pars$b <- 1.2*b` leaves `psi_crit` at its old value (7.085493 where consistency requires
  8.50259). Nothing detects the inconsistency; `prepare_strategy` passes both to `Leaf`.

### D7. Ten registered parameters reach no equation

`TF24_Pars` has **59** fields. Eight are never read outside the struct: `p_50`, `beta1`,
`var_sapwood_volume_cost`, `nmass_l`, `nmass_s`, `nmass_b`, `nmass_r`, `dmass_dN`. Two more
(`a_p1`, `a_p2`) reach only `assimilation_leaf`, called only from `assimilation()`, which is
marked "not in use for TF24" and whose call site in `net_mass_production_dt` is commented
out. `root_psi_crit` reaches only an unreachable branch (D8) and a shut-down diagnostic.

### D8. The root-critical clamp is dead code

`bound_b = std::max(-root_crit, -root_psi_crit)`. `root_crit` comes from `find_root_psi`
over `[-psi_crit, wettest_soil_layer]` with both endpoints ≤ 0, so `-root_crit ≥ 0`, while
`root_psi_crit` is a positive magnitude, so `-root_psi_crit = −5.87 < 0`. The maximum always
selects `-root_crit`. Report 05 §7.3's "the root-critical clamp is therefore unreachable"
is correct.

### D9. Two stale comments about extrapolation

`setup_root_vulnerability` says `root_vuln_from_psi.set_extrapolate(true)` means "clamp to
last value beyond range", and `dE_from_soil_dpsi_collar` says both splines "clamp-to-last-
value, #527". Neither is what happens: the odelia spline extrapolates with the quadratic
`m_b[n−1]h² + m_c[n−1]h + y[n−1]`, which for the natural right boundary is linear in the
end slope. Verified: linear input data extrapolates exactly linearly to m = 1000, and the
vulnerability integral's extrapolated slope is constant at 0.010360. The load-bearing
guard in `E_from_Soil_to_Root_Collar` ("root_vuln_from_psi LINEARLY extrapolates NEGATIVE")
has it right; the other two comments contradict it.

---

## 2. Where reports 05–07 are wrong

### C1. The light interpolant is **not** locally supported — "four non-zeros" is false

Report 05 §6.1: "A cubic interpolant with local support means a single query loads one span
— four non-zeros." Report 07 §1 builds its priority-2 recommendation on it ("**four**
non-zeros out of 2K").

An interpolating cubic spline's *coefficients* solve a tridiagonal system over all knots,
so the value at a query depends on **every** knot value. Measured on the actual light
spline (33 knots over [0, 20], query at 9.5, inside span 16):

```
knot:  13        14        15        16        17        18        19        20
d/dy: -0.00788  +0.02942  -0.10978  +0.92172  +0.20689  -0.05329  +0.01428  -0.00383
```

**33 of 33 knots non-zero.** Decay is geometric at ratio ≈ 0.268 per knot (the expected
2−√3 for this tridiagonal inverse). Above 1e−6 of the largest entry: **20 of 33 knots**;
above 1e−3: 10.

This is what makes their own measurement ("maximum of 78 of 130 columns, mean 58.7") exceed
their structural bound of 44: the measurement was right, the mechanism was wrong. The
consequence for report 07 §7's priority 2 is real: the sparsity is a *thresholded*
sparsity, so exploiting it changes the answer by the discarded tail rather than only the
cost, and the threshold has to be declared and bounded.

### C2. "In Cash–Karp c₂ = c₅ = 0" names the wrong coefficients

The stepper is GSL's RKCK (`odelia/ode_step.hpp`). Its abscissae are
`ah[] = {1/5, 0.3, 3/5, 1, 7/8}` — none zero. What vanishes is the pair of **output
weights**: only `c1 = 37/378`, `c3 = 250/621`, `c4 = 125/594`, `c6 = 512/1771` exist,
because β₂ = β₅ = 0. The report's conclusion (two of the six stage adjoint accumulators
start empty) is right; in its own notation of eq. (4.1) the vanishing symbols are β₂, β₅,
not c₂, c₅. Worth fixing because the two enter the reverse sweep differently — a stage
weight of zero still couples through `a_li`, a zero abscissa would change where `f` is
evaluated.

### C3. "Drainage is negligible; the only resupply a deep layer has is a plant pushing water into it" — refuted

Report 05 §6.2 and 06 §6.2 rest this on "conductivity at operating moisture is of order
10⁻³ of the rainfall forcing". At θ = 0.214 that is right: K = 2.26e−03 m/yr against 1
m/yr. But K = K_sat·(θ/θ_sat)^(2n_psi+3) with exponent **16.14**, so a single operating
moisture cannot characterise it:

| θ | ψ (MPa) | K (m/yr) | K / rainfall |
|---|---|---|---|
| 0.428 | 0.0018 | 163 | 163 |
| 0.300 | 0.0184 | 0.527 | **0.53** |
| 0.214 | 0.1691 | 2.26e−03 | 2.3e−03 |
| 0.150 | 1.746 | 7.29e−06 | 7.3e−06 |
| 0.100 | 25.06 | 1.05e−08 | 1.1e−08 |

Measured directly: a run started at θ = 0.10 in every layer refills **all five layers** to
θ ≈ 0.31 by t = 0.5 yr, by drainage, with no plant involvement in the deep layers.
Cumulative drainage over that run is 0.61 m against 20 m of rainfall (3 %), not 0.1 %.

The claim is true at the mature stand's *equilibrium* (θ ≈ 0.143 → K/rain ≈ 3e−06, even
more negligible than stated) and false during any wet transient. The ecological inference
that hydraulic redistribution is a deep layer's only resupply does not follow.

### C4. "No plant in this corpus has ever been run … in drought: soil potential never drier than 0.17 MPa, which is the initial condition" — refuted

0.17 MPa is exactly the default initial condition (θ = θ_sat/2 = 0.214 → ψ = 0.16912 MPa),
so the report correctly identifies where that number comes from. But the model dries well
past it under its own dynamics: a default run reaches ψ = 2.46 MPa and *settles* at
1.38–2.37 MPa; halving rainfall reaches 4.54 MPa; a twentieth reaches 5.21 MPa. Since
1.34 MPa is where the leaf optimum stops being interior (D2), the mature stand's own
equilibrium is on the far side of the transition the report treats as unvisited.

### C5. The mean-light bias sits at the canopy top, not "mid-canopy" — and here is the per-plant measurement

Report 06 §5 says the per-plant carbon bias "has never been measured", and locates the
misrepresented plants as "mid-canopy and gap-edge individuals". Measured, aggregating the
leaf submodel over a crown exactly as `net_mass_production_dt` does (canopy 20 m carrying
6 m²/m², k_I·LAI = 3):

| focal height | mean crown light | Π(mean-light) | Π(deep-crown) | ratio |
|---|---|---|---|---|
| 0.5–12 m | 0.0498–0.0500 | — | — | **1.0000** |
| 16 | 0.05724 | 0.54309 | 0.54200 | 1.0020 |
| 18 | 0.08983 | 1.24340 | 1.19830 | 1.0376 |
| **20** | 0.31659 | 4.22270 | 3.29170 | **1.2829** |
| 21 | 0.54337 | 5.29810 | 4.15690 | 1.2745 |
| 25 | 0.93318 | 4.88780 | 4.72390 | 1.0347 |
| 30 | 0.99223 | 4.05400 | 4.03870 | 1.0038 |

The reason the bias is confined to the canopy-top band is the report's *own* observation
about crown shape, applied twice. Q(ν) = (1−ν^12)² is ≈ 1 below ν = 0.8, so the light
profile is nearly flat through the bottom 60 % of the canopy — light 0.049787 at the
ground, 0.050441 at 0.6·CH, 0.074136 at 0.8·CH, 0.53 at 0.95·CH. A plant is
misrepresented only where its own leaf band (86.7 % of its leaf in the top 20 % of *its*
height) overlaps the canopy's gradient band (the top 20 % of *canopy* height). Suppressed
plants see a uniform light and the bias is < 0.1 %; well-emergent plants are in full sun
and the bias is 0.4 %. It peaks at the cohort just reaching the canopy top.

Report 06's ecological conclusion survives — the biased cohort is the one whose fate
decides whether a stem escapes — but "mid-canopy and gap-edge" is the wrong location, and
"nearly exact for an emergent" holds only for a *well*-emergent plant, not for the plant
that is only just emergent, which is the worst case.

The Jensen premise itself holds: profit is concave in absorbed radiation (slopes
monotonically decreasing over openness 1e−4 to 1), so the direction of the bias is
guaranteed for the TF24 value function, not just for photosynthesis.

### C6. The 3.33× offspring ratio does not carry over to develop's defaults

Report 06 §5: "Mean light gives lifetime offspring production 3.33 times the deep-crown
mode's — 8.28 against 2.48 — at a patch lifetime of 20, one trait, one species", with the
caveat "at a configuration that is not production". Measured at develop defaults (lma
0.0825, hmat 5, patch lifetime 20, birth rate 20, 5 soil layers):

| shading model | offspring production | min ground light | wall clock |
|---|---|---|---|
| mean-light (TF24 default) | 445.37 | 0.12166 | 11 s |
| deep-crown | 369.31 | 0.10985 | 143 s |
| crown-centre | 537.95 | 0.12437 | 8 s |

**Ratio 1.206**, not 3.33 (and crown-centre/deep-crown = 1.457). The report's structural
point stands — the stand-level ratio (1.21) exceeds the stand-average per-plant bias
(≈ 1.00–1.03, since only canopy-top cohorts are biased), so there *is* demographic
amplification — but the magnitude is configuration-specific and the disclosure "the
objective is biased by 3.33 times" should not be carried forward.

### C7. Report 05 §7.3's "the search probes past the root integral's last knot" is true by 0.19 MPa, and it is not the route that matters

The collar search domain is `[-psi_crit, wettest]` with stem `psi_crit = 7.0855` and the
root grid ending at **6.8918** — so the excursion is real but **0.1937 MPa (2.8 %)** wide,
where the extrapolation error is ~0.1 %. The route that actually reaches the badly
extrapolated region is a dry *layer* (D4): any layer with θ < 0.122 is read past the knot,
and at the ψ = 1e3 MPa ceiling the argument is 145× the domain. Also worth recording: the
*stem's* own grid ends at 10.5123 MPa, beyond `psi_crit`, and both stem splines are built
with `set_extrapolate(false)` — the stem side is never extrapolated.

### C8. P = 44 is not develop's parameter count

`TF24_Pars` exposes **59** fields to R. With the 10 dead ones of D7 removed, 49 remain
live. Report 06 §11's "eleven registered-looking parameters that reach no equation, and the
half-loss potential" is close in spirit to D7's ten-plus-`p_50`, but the total is 59, not
44, and the input-count arithmetic of report 05 §5 (6 + 2K + L + P = 185 at K = 65) should
carry that.

### C9. Two smaller completeness notes on report 05 §5

- The recorded step has a **ninth** output the list omits:
  `offspring_produced_survival_weighted_dt`, a `Node`-level ODE state whose rate reads the
  fecundity rate, the mortality *state* and the patch-survival ratio. It is the quantity
  fitness is measured from, so a fitness functional's seed does not reach it through the
  six rates plus density plus uptake.
- K is not fixed **within** a run. Knot counts across one 99-step run: min 33, median 33,
  max 99 (33 for 73 steps, then 39, 41, 51, 61×2, 63×7, 65×4, 67×2, 69, 73×2, 75, 77×2,
  83, 99). So "185 inputs" varies from 121 to 253 during a single trajectory.

---

## 3. Confirmed, with the measurement

Everything in this section checked out. Where the report gave a number, the measured value
is beside it.

**Crown shape and light** (report 05 §6.1, 06 §5)
- Q̃(ν) = (1−ν^η)², zero above the crown: exact.
- 86.7 % of leaf area in the top 20 % of height → **86.7283 %**; above half height 99.95 %
  → **99.95118 %**; η_c(12) = 0.886154.
- Q̃(0) = 1 for every η → verified for η ∈ {1,2,4,8,12,20}; ∂Q̃/∂ν at ν = 0 is −2 at η = 1
  and 0 for every η > 1, so the ground knot's slope is exactly zero, as claimed.
- Field = exp(−Σ k_I A Q̃) (Beer's law in `compute_environment`), so its minimum is at the
  ground and equals exp(−k_I·LAI): measured min ground light 0.121661 against
  exp(−2.1065) = 0.121661.
- The scalar the physiology receives is the field value × k_I × PPFD, floored at 1e−4
  (`radiation_at`) — a registered parameter and an extrinsic driver between field and leaf,
  exactly as §5.2 says. The 1e−4 floor never binds in a default run (min field 0.1217);
  `ResourceSpline::get_value_at_height` separately clamps spline undershoot at 0 (#253).

**Reserve dynamics** (report 05 §5.3, 06 §5)
- Gate G(r) = logistic((r − a_st2)/0.1), a_st2 = 0.1: **G(0) = 0.26894** ("a plant with
  empty reserves still grows at 27 percent of its production rate"), G(1) = 0.9998766.
- Gate derivative ratio G′(a_st2)/G′(1) = **2026** ("three orders of magnitude smaller").
- 10–90 % transition band **0.439 wide**, of which 0.320 lies inside [0,1] — the report's
  "40 percent of the whole domain" is the nominal band.
- The frozen state is exactly flat: at S ≤ 0 with P < 0, dS/dt = **−0** (exactly), dh/dt =
  8.98e−10 (the smooth positive part, still live), mortality pinned at **5.51** =
  d_I + a_dG1. Every derivative out of the reserve vanishes; the growth channel does not.
- Release is immediate and at full rate: at S ≤ 0 with P > 0, dS/dt = **0.90422** =
  P·(1 − G(0)) to all digits, identically for S = 0, −1e−3 and −1.
- The frozen set and the negative-production set coincide: in the default run's final
  stand, **42 frozen of 99** against **43 with negative net production**.
- In that stand the gate is bimodal — min 0.2689, median 0.9986 — so the gradient is damped
  for the healthy majority (G′ = 0.0134 at the median r = 0.759 against 2.5 at the centre),
  as report 06 says.

**Establishment** (report 05 §5.3, 06 §5)
- Form is P²/(P² + k²) × exp(−recruitment_decay·t), zero for P ≤ 0, with
  k = a_d0·area_leaf_0 = **1.209e−05**.
- C¹ at P = 0: value 1.0e−12 and derivative 1.65e−01 at P = 1e−6·k.
- Derivative peaks at P = k/√3 with value **0.6495/k** (exactly 3√3/8 = 0.649519).
- The stiffness is sharper than the report suggests: pr_estab is 0.998 at openness 1, 0.806
  at 0.2, and **exactly 0** at 0.1 and below (birth-size production turns negative), so
  recruitment is effectively a threshold in canopy openness near 0.15.

**Soil** (report 05 §6.2)
- ∂ψ/∂θ = −n_psi·ψ/θ: numeric −5.1920 against analytic −5.1920.
- The potential ceiling always binds before the residual floor: the ceiling (1e3 MPa) binds
  at θ = 0.0571, the floor is 0.0100, and the unclamped retention curve at the floor is
  9.3e+07 MPa. So the floor is invisible and the ceiling is the only clamp with incidence.
- Rain reaches the top layer only (`water_input = infiltration` for i = 0,
  `water_flux[i−1]` below); every soil parameter (a_psi, n_psi, K_sat, θ_sat, a_infil,
  b_infil, depth, the residual floor, the ceiling) is an environment member and appears in
  no strategy parameter list.
- Per-layer negative flux needs no branch: the same general expression covers it (verified
  numerically, D4).

**The individual's decision** (report 05 §7)
- Π = A(c^i(p)) − Θ(p) with Θ = g1·(1 − exp(−(p/b)^c))^β₂; the maximisation is over the
  **root-collar** potential by golden section, with psi_stem following from continuity.
- Bounds are the collar at zero uptake and the collar at which the stem reaches psi_crit,
  as described; the root-critical clamp is dead (D8).
- Interior optimum verified: dΠ/dp = −1.23e−04 at the golden-section argmax, curvature
  −4.265 < 0, and the grid argmax agrees to 2e−3 (the GSS tolerance).
- The c^i root-find is bracketed on [Γ*, c_a] with residual
  A(c^i)·umol_to_mol − g_c(c_a − c^i)/(atm·kPa) — exactly report 05 §7.5's R — and the
  forward model substitutes c^i = Γ* with zero flux when `psi_upstream >= psi_stem` or
  `assim_max_ < 0`, which is the report's case X.
- The zero-transpiration exit and the pin at zero uptake really are the same plant
  approached from two sides, and it is a *shade* regime: measured threshold **canopy
  openness 0.0296** (absorbed PPFD 26.6 μmol m⁻² s⁻¹), where profit becomes exactly
  constant at −1.52475 = −R_d − Θ(psi_crit), so every derivative through carbon is exactly
  zero below it. Report 06's "probably the most under-measured state in this model" is
  right, and it is not rare: it is the whole understorey of any stand with k_I·LAI ≳ 3.5.
- S → K → X really are consecutive segments of one drydown, and the traversal is measured
  in D2 (S below 1.34 MPa, K above, shutdown at ψ_soil ≥ psi_crit where psi_stem = collar =
  7.0855 and E_up = 0).
- The `dprofit_droot_collar_psi` sentinel zero exists exactly as described (`return 0.0` on
  the shutdown/infeasible exits).
- The acclimating variant is case X, not a pin: TF24f's collar potential is an ODE state
  clamped into the feasible interval by `profit_at_collar_psi`, with
  dψ/dt = k_acclim·dΠ/dψ.

**The transport integral** (report 05 §7.6)
- G(m) = (b/c)·γ(1/c, (m/b)^c) is literally the code's knot seeding
  (`boost::math::tgamma_lower(1/c, pow(psi/b, c))`, #468).
- X = log(1/fraction) identically for every b, c: measured **4.605170** = log(100) for both
  the stem and root grids, so the series argument is bounded by 4.61 wherever this integral
  is evaluated — exactly as claimed, with the fraction being 1 % rather than the 5 % the
  report's `psi_crit` discussion implies.
- The closed forms have not replaced the tabulation on develop: the spline is still there,
  seeded from the closed form at the knots.

**The solver and the reductions** (report 05 §4, §6)
- Cash–Karp (GSL RKCK) confirmed; β₂ = β₅ = 0 (see C2).
- One-sided FD costs 1 extra solve, Richardson depth 4 costs 8.
- Both reductions are trapezium rules over the node list as quadrature grid, and both take
  a sorted path when the ordering breaks (#571/#574) — so the forward model tolerates a
  crossed stand while the R census does not (D3).
- Two reductions on opposite sides of the individual, as §3 says: the light reduction is
  upstream (cohorts build the field, then read it), the water reduction downstream
  (`set_consumption_rate` per layer from the solved leaf).

**Boundary conditions** (report 05 §4.1)
- The initial reserve is `a_st3 · S_max` with S_max = a_st1·mass_sapwood — a trait times the
  storage capacity, a second independent read of φ at the introduction boundary.
- `set_initial_states` runs before the first rate evaluation, and TF24f additionally seeds
  its tracked state at the optimum.

---

## 4. Not testable against develop

These are properties of code that is not on `develop`, and nothing here confirms or refutes
them: the 3.041 % extinction-coefficient shortfall; the 87 % dominant-height adjoint term;
the rank-2 factorisation of Π_pu and its 1e−5 second singular value; the 15–26×
amplification along the uniform-drying direction; the ~3 % birth-size consequence; the
per-species column-naming collapse; the tape-clear/record-once-sweep-many hazard. The
birth-date coordinate itself does not exist on develop (see §0), so its quarter-difference
in leaf-area sensitivity and sign change in above-ground-mass sensitivity cannot be checked
here either.

---

## 5. Ranked follow-up

1. **D1** — a public entry point aborts the run in ordinary shade, and the default gradient
   path is the one that aborts. Smallest fix, largest blast radius.
2. **D2** — if the majority of a mature stand is at a bound, the pinned branch is the main
   case for any drought or trait conclusion, and the "profit is free" economy is not
   available where it matters. Worth stating in the model's own documentation, not only in
   the gradient design.
3. **D3** — a ~4 % error in the objective on a state the forward model produces. One `sort`
   in `integrate_over_size_distribution`, mirroring what the C++ reductions already do.
4. **D5/D6** — one curve, two derivations differing by 1.87× in steepness and 1.17 MPa in
   `psi_crit`, plus three independently settable numbers for two degrees of freedom. This
   is a forward-model correctness item that changes D2's threshold.
5. **D4** — bound the vulnerability integral at G(∞) instead of extrapolating (the exact
   limit is (b/c)Γ(1/c), one `gamma` call), or refuse past the last knot. Low incidence on
   default drivers, unbounded consequence when reached.
6. **D7/D9** — dead parameters and contradictory comments; cheap, and both mislead a reader
   into thinking a lever exists.

---

## 6. Re-run against the leaf refactor (plant `74b10ed7`, TF24@v8, phylloptim 0.1.0)

`traitecoevo/plant` develop is 7 commits ahead of the `aornugent` fork's develop and is a
clean fast-forward of it. Those commits move the leaf gas-exchange and hydraulics model
out to **`phylloptim`** (#591), pin `odelia (>= 0.2.1)` (#597), add the birth-date
coordinate as an opt-in `Control` flag (#590), and integrate the environment in the
stochastic solver (#593). Build chain: `odelia` 0.2.1 → `phylloptim` 0.1.0 → `plant`.

The strategy header records the science the swap carried, and the accounting is worth
reading in full because it inverts its own expectation: **v5** derives the leaf's
ppm→Pa conversion from `atm_kpa` instead of the hard-coded 0.1013 (= 101.3 kPa), which
moved one-species SCM offspring +2.4% because `TF24_Environment`'s `atm_kpa` default was
**100.5** — "an artefact, not a site elevation" — so **v8** pins the driver to 101.3 and
the whole branch collapses to **−0.20%** against develop, with the seeded stochastic
counts matching bit for bit. The pressure fix was ~25× the rest of the swap put together.

### Fixed by the refactor

**D8 (dead root-critical clamp) — fixed, and by the same diagnosis.** v7's note:
"the clamp was written as a std::max against a *signed* root_psi_crit, so it could never
bind and the solver optimised over a collar the root system cannot supply. **The window
is 1.2 MPa wide at TF24's defaults** — psi_crit = 7.085493 against root_psi_crit =
5.870283". Those are exactly the numbers in §1 D8/C7 (phylloptim #24, plant #584).

**The sentinel zero is now documented and reportable.** `dprofit_droot_collar_psi` gained
a `feasible` out-parameter precisely so a caller root-finding on `dprofit == 0` can tell
a stationary point from a shut-down sentinel — report 05 §7.0's requirement, met. Its
comment measures the trap: profit at the sentinel is −1.897 against 2.516 at the true
optimum, and the region is "at most 3.46e-07 MPa into the bracket, median 1.22e-08",
"which is exactly why it would survive casual testing."

**D2 is corroborated independently.** phylloptim's own golden-grid measurement:
constrained (pinned) optima are "**42 of the 240 feasible golden-grid rows** … a branch
that has to be written rather than a corner case". Measured again here through the plant
path, the stem pins at `psi_crit` from θ = 0.155 (ψ_soil = 1.41 MPa) and shuts down at
θ = 0.121 (ψ = 7.16 MPa) — the same transition as §1 D2, which put the interior/pinned
boundary at 1.34 MPa.

### Still open, verified on the refactored tree

**D1 — survives byte-identically.** A TF24f individual at 5 m on **wet** soil
(θ = 0.214, ψ_soil = 0.169 MPa) still aborts the run for canopy openness ≤ 0.0295, with
the same message and the same `psi_stem = 0.170872` against `psi_upstream = 0.170867`:

| openness | TF24@v8 result |
|---|---|
| 0.05 | net −0.90214, dψ/dt −3.55e−15 |
| 0.03 | net −1.017, dψ/dt −0.0746815 |
| **0.029 and below** | **THROWS `psi_stem_to_ci failed: … a and b do not bracket the root`** |

Upstream has this as **#576** with two fix branches, neither merged into develop. I built
`fix/tf24f-shutdown-gradient-576-v2` and tested it: **it does close this route** —
openness 0.029 and below return dψ/dt = 0 with no throw, because `assim_max_ < 0` is one
of `prepare_collar_solve`'s early exits and the new guard bails on all of them.

One thing to keep when that branch lands. Its comment explains the abort as hydraulic
shutdown — "the collar sits where the soil cannot supply the demanded flux at all, so
uptake there is negative … phylloptim's `find_psi_stem_from_psi_root` throws". That is a
*different* route from the one reproduced here: this plant is on wet soil, is not in
hydraulic shutdown, and the throw is in `psi_stem_to_ci`, not
`find_psi_stem_from_psi_root`. The guard catches both because it is placed at
`prepare_collar_solve`, but the recorded reason covers only one, and the new coverage
lives in `test-tf24-arid-corner.R` — so a later narrowing of the guard to "only
shutdown" would silently reopen the shade route. A shade case (θ = 0.214, openness
0.02) belongs in that test file beside the arid ones.

**D3 — unchanged.** `integrate_over_size_distribution` still has no `sort`/`order`, while
the C++ reductions still sort. Same dry-start run (θ₀ = 0.10, patch lifetime 20), same
outcome: **57 of 99 steps invert**, max 18 inversions in a step, and on the final step

| census | as-ordered | height-sorted | error |
|---|---|---|---|
| Σ w n h | 23.010621 | 22.145727 | **+3.91 %** |
| Σ w n A_leaf | 4.2563058 | 4.0950784 | **+3.94 %** |
| Σ w n m_heartwood | 9.1977289 | 8.8444089 | **+3.99 %** |

**D4 — unchanged, and re-verified against odelia 0.2.1.** `phylloptim/roots.hpp` still
builds the root grid to the 1 % point and still sets `set_extrapolate(true)` on both root
splines; the odelia 0.2.1 spline still extrapolates linearly past the last knot, slope
**0.010360**, against an exact integral that has converged: 13.74976 vs 3.46578 at
m = 1000, i.e. **3.97× inflated**. The dry-start run reaches ψ_soil = 25.061 MPa, so the
extrapolated region is live in it.

**D5, D6, D7 — unchanged.** C++ c = 1.089985 against the R hyperpar's 2.040000 (**ratio
1.8716**), psi_crit 7.085493 against 5.919880; `pars$p_50 <- 3.5` is still inert;
`pars$b <- 1.2*b` still leaves `psi_crit` stale at 7.085493 where consistency requires
8.502591. `TF24_Pars` is now **61** fields (was 59) and every dead parameter named in D7
is still there — `p_50`, `beta1`, `var_sapwood_volume_cost`, the four `nmass_*`,
`dmass_dN`, `a_p1`, `a_p2`, `root_psi_crit`.

**D9 — unchanged.** `roots.hpp:259` still says `set_extrapolate(true); // clamp to last
value beyond range`, which is not what the spline does.

### What #590 does to the review's framing

§0 said the birth-date coordinate does not exist in this model. **It does now**, as
`Control$node_density_in_birth_date`, defaulting to off. So reports 05–07's coordinate is
implementable here, and the two can be compared directly. On the same configuration
(lma 0.0825, hmat 5, patch lifetime 5, birth rate 20, the same node schedule):

| coordinate | offspring production | steps | wall clock |
|---|---|---|---|
| height (default) | 81.853869 | 89 | 6 s |
| birth date | 466.914500 | 89 | 3 s |

**A factor of 5.70 in the objective, not in a sensitivity.** Report 06 §11 warns that the
two coordinates are different functions and quantifies it in sensitivities (a quarter for
leaf-area/lma, a sign change for above-ground mass); measured here the *objective itself*
moves 5.7×. The likely reason is the one report 06 §11 names — on the birth-date
coordinate the introduction schedule **is** the quadrature grid, and this schedule was
refined for the height coordinate — which makes the schedule non-transferable rather than
either answer wrong. Whichever it is, a birth-date run needs its own schedule refinement
before its offspring production means anything, and the flag being opt-in and off by
default is the right default until that exists.

### Practical notes for the workspace

- `phylloptim` is header-only for consumers: `plant/inst/include/plant/leaf_model.h` is
  now a thin re-export (`#include <phylloptim.hpp>`, `using Leaf = ::phylloptim::Leaf`),
  so `plant` compiles its headers and links no phylloptim objects. It must still be
  *installed* for `LinkingTo` to find them.
- `plant` needs `odelia >= 0.2.1`. Both forks were behind when this section was written
  and have since been brought current: `aornugent/plant` develop fast-forwarded 7 commits
  to `74b10ed7` (which is where #590 and the refactor land), and `aornugent/odelia` master
  reset to upstream's `4b9668e` (v0.2.1) — it had diverged by one commit, an
  equivalent, differently-hashed change for #46, which upstream supersedes and which
  remains reachable from `p0/ode-rates-mutable` and `p3/odelia-integration`. Both
  submodule pointers are now reachable from the forks' own default branches.
- A pointer naming an upstream-only SHA would have worked anyway: GitHub fork networks
  share objects, and `git fetch <fork-url> <upstream-sha>` was verified to succeed for
  both `plant` and `odelia` before the forks were moved.
- `aornugent/phylloptim` is in sync with `traitecoevo/phylloptim` (both `e265c6b`).
