# Where TF24's rates are not smooth

An inventory of every point in TF24 where the rates of the ODE system are not
smooth: plant's strategy and environment, phylloptim's leaf solve, and the soil and
light fields between them. It serves aornugent/plant#112: a step's error control
sees the states' error but not their derivatives', so a rate whose derivative jumps
inside a step leaves an O(h·jump) error in the gradient that depends on where the
step's stages fall.

**Code read:** plant `PLANT-110` (`79d5c468`), phylloptim `PHYLLOPTIM-19`
(`29982dc`), odelia `ODELIA-55` (`cb4d262`). The averaged establishment gate is on
plant's `establishment-window` branch (`6613dd24`), not on `PLANT-110`.

**Kinds:**
- **J**: the rate jumps.
- **K**: the rate is continuous and its derivative jumps.
- **C1**: the rate and its first derivative are continuous, and the second jumps.
  This is weaker than K, and is listed so the inventory is complete.
- **W**: the rate is smooth, and changes slope over a width a parameter sets.

**Reach** names whose rates change:
- *node:* the node's own block of nine states.
- *soil:* the five layer moistures, a block every node reads and draws from.
- *ψ → nodes:* a layer's potential, which every node's leaf reads.
- *newest interval:* the newest node's `interval_establishment` and its moment.
- *E:* the averaged gate's species-level state.
- *field:* the light field.

**Trigger:** *state* means the point is met during a step, where the state
reaches it. *known* means it falls at times known before the run.

**Occurrence** on dry comes from one forward run with the JT settings: the inset
schedule (149 nodes), tolerance 3e-4, soil weight ×10, rule A, 15-day cap, splits on,
and soil substeps at 0.1. The build is libD, lib19's plant; it reproduces run A,
with J 1.1962273456 and 4786 steps. The run made 3 764 763 leaf solves in 65 s
(`clamps.R`, `clamps_dry.log`). The counts for the clamps include rejected attempts
and stages. Counts on other records are quoted from older notes.

## The table

| # | Where, what | Kind | Sign value; computed on every evaluation? | Reach | Trigger | Handled today | Occurrence |
|---|---|---|---|---|---|---|---|
| 1 | `TF24_Strategy::compute_rates`: smooth positive part σ(P) of net production | W, η = `storage_prod_eps` 1e-4 kg/yr | P, `net_mass_production_dt` aux; yes | node | state | yes: split at P's sign change | dry: 16 502 node splits; long drought: 9247 sign changes in 726 steps |
| 2 | same: storage growth gate G = logistic((r − a_st2)/w), r = storage/capacity | W, w = `storage_gate_width` 0.1 in r | r − a_st2; r is computed, not kept | node | state | no | dry: 7136 crossings of r = 0.1; median width 20 d against a 5.4-d step |
| 3 | `mortality_storage_dependent_dt`: a_dG1·exp(−a_dG2·r) | W, 1/a_dG2 = 0.05 in r | none (monotone) | node | state | no | with #2; about half #2's width in time |
| 4 | `fraction_allocation_reproduction`: logistic in height | W, hmat/a_f2 = 0.33 m | h − hmat; h is a state | node | state | no | once per node, over years |
| 5 | `net_mass_production_dt`: rooting depth min(h, `rooting_depth_max` 1.5 m) | K | h − 1.5; yes (counted as `rooting_depth`) | node, soil | state | no | 147 of 149 nodes pass it once; 90% of solves are past it |
| 6 | `Q(z_a, d)`: root profile as rooting depth passes the layer boundaries (0.3 … 1.2 m) | C1 | h − z_a; h is a state | node, soil | state | no | up to 4 per node |
| 7 | `radiation_at`, `compute_average_light_environment`: light floor max(light, 1e-4) | K | light − 1e-4; yes | node, soil | state | no | dry: 0 |
| 8 | `establishment_probability`: gate g = P²/(P² + a²) for P > 0, else 0, at the seedling's P = 0 | C1 | P_seed, the boundary node's net production; yes, not in the sign values | newest interval (sharp gate); E (averaged gate) | state | no | every closing and opening edge; dry has 96 edges in b1–25 |
| 9 | same gate, its change of slope near P = a, with a = a_d0 × the seed's leaf area | W, a | none | newest interval; E | state | no | at each closing edge, about 2–3 d wide on dry |
| 10 | phylloptim `maximise_profit_over_collar`: Interior ↔ BoundaryCrit | K in collar, transpiration, uptake; profit C1 | f_hi, dprofit/dcollar at the dry end; yes, not kept | soil | state | no | dry: 14 728 switches in 234 steps, median 51 per step |
| 11 | same: Interior ↔ BoundarySoil | K | f_lo, the same at the wet end; yes, not kept | soil | state | no | dry 0; long drought 0 |
| 12 | `prepare_collar_solve`: dry bound min(root_crit, root_psi_crit), BoundaryCrit ↔ BoundaryRootCrit | K | root_crit − root_psi_crit; both computed, only a bool kept | node, soil | state | no | dry 0; long drought 8–140 solves |
| 13 | same: Determined, where the bracket's width falls to `GSS_tol_abs` 1e-3 MPa | J | bound_b − bound_a − 1e-3; yes | node, soil | state | no | dry 0; long drought 9138–18 715 solves (older runs) |
| 14 | same: HydraulicShutdown, four exits; at the defaults the inverted bracket bound_b < bound_a is met first | J (small; see notes) | bound_b − bound_a, wettest layer − psi_crit, root_crit − psi_crit; yes | node, soil | state | no | dry 0; long drought 0.002% of solves once converged, 4–5 per introduction |
| 15 | same: ShadeDeath, where assim_max < 0 | K (value continuous at root_zero_E; not measured) | assim_max_; yes | node, soil | state | no | 0 on every record measured |
| 16 | `RootSupply::root_vuln_integral_at`, `root_vuln_at`: root curve past its dry end (integral capped past 7.3132 MPa, argument held at 6.8918 MPa) | K | ψ_layer − 7.3132; ψ is computed | soil (that layer), node | state | no | dry: 17 937 capped reads (0.48% of solves); long drought: 822 k of 9.57 M |
| 17 | phylloptim Hermite tables of the root and stem curves (400 knots, about 0.017 MPa apart) | C1 | collar or stem potential − knot | node, soil | state | no | continual; size set by the table's interpolation error |
| 18 | phylloptim colimitation, `curv_fact_colim` 0.99 | W, √(1 − 0.99) ≈ 0.1 relative | A_c − A_j; computed in the ci solve | node, soil | state | no | not measured |
| 19 | `TF24_Environment::layer_rates`: positivity, a layer's rate held at 0 when θ ≤ θ_r = 0.01 | J | θ − θ_r; a state | soil | state | no | dry: 3; episodic: 5 forward, 0 in the sweep |
| 20 | `psi_from_soil_moist`: moisture floor max(θ, θ_r) | K | θ − θ_r; a state | ψ → nodes | state | no | dry: 13; episodic: 240 forward, 0 in the sweep |
| 21 | same: potential ceiling min(ψ, 1000 MPa) | K | ψ − 1000; yes | ψ → nodes | state | no | dry: 14; episodic: 255 forward, 0 in the sweep |
| 22 | `conductivity`: θ held to [0, θ_s] | K | θ − θ_s; a state | soil | state | no | dry: 67 stage evaluations |
| 23 | `layer_rates`: infiltrated share max(0, 1 − a_infil(θ/θ_s)^b_infil) | K | θ − θ_s at a_infil = 1; a state | soil | state | no | dry 0; long drought: 0 on accepted steps at tol ≤ 3e-3 |
| 24 | `compute_rates`: rainfall max(0, rain) | K | rain; yes | soil | known | no | dry: 48 evaluations at an interpolant that cannot fall below zero |
| 25 | odelia `drivers::Function`: monotone Hermite rainfall, at each active knot | C1 | none (a time) | soil | known | yes: a zero-depth pulse at each knot ends a step; soil substeps stop at knots | dry: 2951 active knots |
| 26 | `Species::compute_height_scan`: canopy top h_max = max of the heights; the light knots sit at fractions of it | K | gap between the two tallest heights; not computed | field | state | no | dry 0: the height order never breaks |

**Counts.** Of the 26 entries:
- *By kind:*
  - 3 J (13, 14, 19);
  - 13 K (5, 7, 10–12, 15, 16, 20–24, 26);
  - 4 C1 (6, 8, 17, 25);
  - 6 W (1–4, 9, 18).
- *By reach:*
  - node only: 1–4;
  - node and soil: 5–7, 12–18;
  - soil only, through uptake: 10, 11;
  - the soil's own rates: 19, 22–25;
  - ψ → nodes: 20, 21;
  - newest interval or E: 8, 9;
  - field: 26.
- *Handled today:* two, #1 by the split and #25 by step ends at the knots.

## Notes

**1. σ.** `docs/design-sign-changes.md` §1 has the analysis.
- A node crosses the band |P| < η in τ = η/|dP/dt|. The median h/τ is 4.9e4, so this
  is a kink at any step.
- The split integrates the node again in pieces that meet at P's sign changes. Each
  piece is one Cash–Karp step with no error test of its own.

**2, 3. Storage gate and storage mortality.** After P changes sign, r falls toward 0
or rises toward 1 over the pool's relaxation time. It then passes the gate's centre
a_st2 = 0.1, and mortality's scale 0.05.
- On dry, r crosses 0.1 7136 times, about 24 times per node each way. At each
  crossing, 0.1/|dr/dt| (from the step holding it) is a median 20 d, against a median
  5.4-d step. Falling crossings take 26 d and rising ones 14 d (`r_cross.R`,
  `r_cross_dry.log`).
- In 0.6% of crossings this width is under the step. On dry neither feature is sharp
  against the steps.

**5. Rooting depth.** Above 1.5 m the root profile stops reading height, so
∂uptake/∂h and ∂P/∂h jump.
- Each node meets this once, while growing at a rate of metres per year. The jump in
  time is small. The jump in the θ-derivative's integrand is ∂(uptake)/∂h × ∂h/∂θ, and
  its size is not measured.

**8, 9. The establishment gate.**
- *At P = 0* the gate is C1. Both sides have g = g′ = 0, and g″ goes from 0 to 2/a².
- *The change of slope near P = a* is what matters. Part 2 of
  `schedule-search/round4/JT/notes.md` measured it. On dry, g falls from 0.9 to 0 in
  about 3.5 d, half of it in the last 1.3 d, inside steps of 1.5–2 d.
- *Under the sharp gate* (`PLANT-110`), g′(P)·∂P enters only the newest interval's
  establishment. There it offsets part of #10's error: a build that drops the gate's
  derivative raised the nudge from rms 0.048 to 0.243.
- *Under the averaged gate,* dE/dt = (g − E)/0.05 yr carries the same term into every
  newborn's density. It is about 70% of the nudge left after the stop at #10 (rms
  0.095 → 0.0285). No sign change marks it.

**10. The leaf's arm switch.** This is #112's case.
- Net production is the optimised profit, so P is C1 through the switch, by the
  envelope theorem.
- Uptake is read at the argmax, so the top soil layer's ∂rate/∂`TF24_cost_scale`
  steps 0.0159 → 0.0091 → 0.0036 → 0 as the 9.70 cluster switches. That takes 0.44 d,
  inside a 2-d step.
- Splitting the switching node changes nothing (rms 0.048 → 0.044). Splitting the
  soil at the first and last f_hi sign change of the step gives 0.010. Ending the step
  there gives 0.002.

**11, 12.**
- *#11:* phylloptim's golden grid puts 24 of 288 points on BoundarySoil at 25 °C and
  80 at 40 °C, where profit is negative and the leaf barely transpires. Hot records,
  or runs with the energy balance on, would reach it. Dry and long drought do not.
- *#12:* at a bound the profit reads the bound, so P has the kink too, unlike #10. The
  1e-3 run counted 140 solves (`perf-step-controller.md`). The 48 at worst and 8
  aligned are from `diag-long-drought.md`.

**13, 14. The collapsed bracket and shutdown.** phylloptim#20 measured the jump at
`stem_P50` 3.4287 and `root_P50` 3.4.
- Transpiration goes from 9.7e-9 at ψ_soil 5.86435 (boundary) to 8.13e-8 at 5.8644
  (determined), ×8 across 5e-5 MPa of soil.
- At the determined point, uptake is 1.26e-7 against transpiration 8.09e-8.
- Shutdown follows when the bracket inverts. There uptake and transpiration go to 0
  and the stem sits at psi_crit, so the jump is of the size of Determined's flux.
- On long drought the shutdown that survives convergence is a birth transient: a
  newborn whose roots reach only the dry top layer. Almost all the rest is step
  placement, and a pinned replay removes it at every node count
  (`diag-long-drought.md`, `diag-gradient-aligned.md`).
- The counts were taken on older builds. Since then the dry bound has been clamped
  to root_psi_crit, and phylloptim 0.9.3 differentiates a determined collar.

**16. The root curve past its dry end.**
- Past 7.3132 MPa a layer's G stops growing. Its slope is f_r ≈ 0.5% of the wet value
  just below the cap and 0 above it. This changes the reverse flow into a very dry
  layer.
- It is reached often, on the top layer through each drydown, but the change of slope
  is small.
- The argument held at 6.8918 MPa is read only in the equal-potential branch and the
  slope. Dry reaches it 0 times.

**17. Tables.** Values are read from C1 Hermite tables, while the derivative rows use
the closed-form curves (`closed_form_curve`, `closed_form_integral`). The value's
second derivative jumps at each knot. The argmax then inherits a jump in its first
derivative of the size of the interpolation error. This is not measured, and is
expected to be far below #10.

**18. Colimitation.** At curvature 0.99, the smooth minimum of the Rubisco- and
electron-limited rates changes slope over about ±10% of their ratio. ci falls as the
leaf closes through a drydown, so the leaf may pass from one limit to the other
inside a step. This is not measured.

**19–23. Soil clamps.**
- On episodic every one was met by the forward and none by the sweep, once each state's
  weight was bounded at 100 (`grid-dynamics.md` §8, `probe_epi_*_clamps.log`). Only
  rejected attempts met them; the soil's error test keeps accepted stages off them.
- #19 is a jump in the layer's rate as a function of θ: rate < 0 above θ_r, 0 at it.
- #22 and #23 coincide at θ_s when a_infil = 1. Explicit stages overshoot to them in
  wet spells: 1215–16 410 conductivity evaluations along long drought's tolerance
  ladder (`perf-step-controller.md` §3). No accepted step at tol ≤ 3e-3 ends above θ_s.

**24, 25. Rainfall.**
- The interpolant uses limited slopes and stays inside the range of its values, so
  #24 binds only where an evaluation comes out a hair below zero. That is presumably
  roundoff, near a zero knot.
- The interpolant is C1, and its second derivative jumps at each active knot.
- The harness (`harness/long_drought.R`, `pulse_rows`) puts a zero-depth rainfall
  pulse at each active knot, so every step ends on the knots.
- Under ODELIA-55, a substepped soil also stops its substeps at the knots
  (`Step::choose_substeps`, `Patch::subsystem_knots`).

**26. The canopy top.** The light field is built on 65 knots at fixed fractions of
h_max. If the tallest node changed identity, h_max would have a kink, and through
the interpolation so would the light read at any fixed height. On dry the height
order never breaks, and no other kink in the light field is found.
- Each crown's Q and its slope are zero at the crown's top.
- Re-sorting the crowns does not change the sum.

**Not reached on the birth-date coordinate.**
- `mortality_dt` parks a node's rate at 0 once its hazard reaches
  `establishment_failure_hazard` (750), a J. The hazard grows at most
  d_I + a_dG1 = 5.51 /yr, so 750 needs more than a century.
- `Node::compute_node_rates` holds the log density's rate at 0 for a node with no
  density. On the birth-date path that rate is −mortality, and the density never
  reaches zero.

**Branches of zero width.** These do not count as non-smooth points. In the uptake,
a layer whose potential is within 1e-8 MPa of the collar, or of gravity's balance,
takes a separate formula. The value is continuous across it.

## Discrete actions (plant Events)

Each acts between steps at a time given before the run, and changes the state rather
than the rates. All are step ends today.

| Event | Where | What it changes | Width | Note |
|---|---|---|---|---|
| Node introduction | `Patch::push_nodes`, `Species::introduce_new_node`; at `node_schedule_times` | Adds a node of 9 states: height, mortality, fecundity, area_heartwood, mass_heartwood, storage, offspring_produced_survival_weighted, interval_establishment, interval_establishment_moment. They are seeded from the boundary node: seed height, storage at a_st3 of capacity. The previous newest node's interval rates fall from g(P_seed) to 0, a J at a known time. | +9 | 149 on dry's inset schedule |
| Resource pulse | `TF24_Environment::add_water_pulse_to_layer` | One layer's θ rises by min(depth, capacity)/dz. sum_rainfall, sum_infiltration and sum_pulse_runoff rise by depth, the amount accepted and the excess. | 0 | The harness's zero-depth pulses at the 2951 active knots on dry change nothing and end a step |
| Harvest | `Patch::apply_event`, `scale_node_densities` | For each node whose height is in [size_min, size_max]: log density += log(1 − f), mortality −= log(1 − f) | 0 | Whether a node is in the band is a sign of height − bound, so J jumps in θ wherever a node's height sits at a band edge |
| Climate extreme | same | Every node of the target: log density −= damage, mortality += damage. damage comes from the event's parameters by a half-hourly loop with max(0, level − threshold). | 0 | Does not read the state |

**13, 21 on the bank** (`jump-census/results2.md`, libS, accepted stages).
- Determined collars and potential-ceiling hits occur on three records (long-wet,
  wet-adG2, ld-105), each in a single step late in the run, and only in split substeps.
- Their cause is the split's soil field. It is interpolated across a rain arrival inside
  the step and reads the top layer 100–500× drier than the stages around it.
- Gradient effect: ≤ 5e-5ε.
