# The time axis: the step controller and its settings

**Status.** The settings below are built on plant's and odelia's TF24 stack and are what the refine
loop runs on (`harness/schedule/refine_case.R`). They are not plant's defaults yet. The one open
piece that the refine loop depends on is a per-run estimate of the tolerance's own error (§ Where
the tolerance error comes from).

This is the time axis of the node schedule in `refine.md`. It distils the step-controller design
(`design-grid-controller.md`, written 21 Oct but mostly settled by 8 Oct), the soil-substep design
(`design-soil-alone.md`), the record of the time axis's debugging (`grid-dynamics.md`) and the
error-mode catalogue (`rootcause/error-modes.md`).

**Sources.** Paths like `measurements/...`, `rootcause/...`, `design-*.md` and `grid-dynamics.md`
are on the tag `archive/trusting-curie`, under `docs/` (rootcause is
`docs/measurements/schedule-search/rootcause/`):
<https://github.com/aornugent/plant-dev/tree/archive/trusting-curie/docs>. `OBJECTIVES.md` is at
this repository's root. §n is a section of `grid-dynamics.md`.

## Superseded on 19 October

The user's decisions after the refine loop and the stack review (`design-grid-controller.md`,
*The user's decisions*):
- **The crown spread is dropped** (PLANT-108). Accuracy is unchanged without it. The replay reads
  less of the error (0.25–0.65 against 0.61–1.09 with the spread), and the loop's bound no longer
  relies on that ratio.
- **The splits at net production's sign changes are dropped** (PLANT-102/103 and odelia's split
  commits). They buy ≤ 0.07ε in the loop's answer, and their gain in reproducibility was measured
  before the soil substeps existed.
- **The ODE tolerance's error belongs to the step controller,** not to the node schedule's bound.

So most of `design-grid-controller.md`'s phase 3 items 2–4 (splits in the forward and the sweep,
curvatures as chords of split gradients) and its item 6 (D, the spread, as the node rule) are
superseded. That doc's body still describes them as in the build. Its acceptance suite survives,
amended, in `validation.md`.

## The setting

What `refine_case.R` sets for every refine run (the five cases' setting, "round 5's"):

| Control field | Value | What it is |
|---|---|---|
| `ode_tol_rel` | 1e-4 | the relative tolerance |
| `ode_tol_abs` | 1e-8 | 1e-4 of the relative: the *tied* tolerance (PLANT-98) |
| `ode_tol_factor_soil` | 10 | the soil's states held 10× looser; the accumulators keep 1 |
| `ode_tol_factor_times`, `_values` | rule A's table for the record | the window's weight over patch age (below) |
| `ode_tol_factor_max` | 100 | the bound on every state's factor after the window multiplies it |
| `ode_step_size_max` | 15/365 | the 15-day cap |
| `ode_soil_substep_max_uptake` | 0.1 | substep the soil while the plants take under a tenth of the water through its layers |
| `node_density_in_birth_date` | TRUE | the birth-date coordinate |

The stepper is Cash–Karp 4(5). The rain's knots are not step targets: a step that spans one
substeps the soil, and the substeps stop at the knot (aornugent/plant#111). On the stack the leaf
solve and the newborn's height stopped once the bracket's ends agreed to 4 DBL_EPSILON relative;
that work was dropped (phylloptim#17 and plant#100, closed 22 Oct), because on phylloptim 0.10 the
replay noise is already 4.0e-13 rms in `ln J`. phylloptim must be 0.9.3 or later (§ Failure modes
still worth guarding, F).

`control_tf24(tol = 3e-5, base = Control())` (aornugent/plant#104) names the same setting once:
the relative tolerance, the absolute at 1e-4 of it, the soil's factor 10, the bound 100 and the
cap. The window's weights stay the caller's. The decision was that, once the setting stops
changing, it becomes plant's defaults in one commit that blesses the references again, and the
function goes. Note that its default tolerance is 3e-5 while the refine loop's evidence is at 1e-4.

**Names.** The design docs say *weight*; the code says *tolerance factor* (it multiplies a state's
error level, so a factor above 1 loosens it). The docs' *soil stepped alone* (or *on its own*) is
the code's soil *substeps*, `ode_soil_substep_max_uptake`, odelia's `HasSoil` and
`uptake_fraction_of_flows()` (`names-subsystem.md`).

### The window's weights (rule A)

R(t) is the share of J still to be earned after t. An error made at t reaches J only through what
is earned after t, so R(t) bounds its weight (§8). On every record 1–99% of J is earned between
t ≈ 13.4–13.7 and 29.2–29.3 (pulsed records) or 10.8–28.5 (constant), yet the controller spends a
third of its steps after t = 25.

*Rule A:* every tolerance factor of a step starting at t is multiplied by
F(t) = 1/clamp(R̂(t)/R₀, r_min, 1), with R₀ = 0.1 and r_min = 0.01 (where the soil's stability
starts to bind, §10). R̂ is the pilot's largest R over the stand and the invaders at `lma`'s range
ends (×0.5, ×2). The weight passes 1 from t ≈ 21.6–23.5 and reaches 100 at t = 33.5–34.5.
- *The pilot:* 54 uniform nodes at 1e-3. It reads the stand's R within 10% wherever R ≥ 1e-3, on
  every record, for 0.25–0.32 of a forward's member-steps. 27 nodes miss dry's tail by 25%.
- *What it buys:* 21.0–22.7% of rows on the pulsed records and 1.9% under constant rain. Every
  quantity of both roles moves at most 0.016ε (§8).
- *The files.* `harness/schedule/data/weights/weight_<record>.rds` are byte-identical to the
  tag's `measurements/grid-dynamics/window/rule_A/`, made by the driver's spike (§8), one per
  record at base traits. The refine cases reuse them: `dry-flat` takes dry's, and the trait-moved
  cases take their record's. plant's own `control_window(pilot, invaders, base, R0, r_min)`
  (aornugent/plant#106) matches them within |ln| 0.12, except on episodic. There the harness's
  pilot lost its `lma` ×2 walk, which raises, and plant's keeps it, so plant's window stays open
  longer, for 10.4% more rows (`measurements/window-pilot/`).

**The window must cover the invaders.** A shared grid's window must cover every invader of the
analysis, and residents moved ×1.1 earn later: their R is 1.23–1.51× θ₀'s on long drought and
1.39–1.80× on episodic (§8). No test has measured an invader or a moved resident run under a
window built at θ₀. `rows-entries.md` therefore turns the window off for rows until its V4
measures entries under it.

## Why each part, and what it bought

- **The tied tolerance** (PLANT-98). It is an enabler; the floor was measured under it.
- **The soil's factor 10.** The soil chain sets the steps: alone it takes 16 447 of the coupled
  run's 17 684 steps on long drought, and it binds 83–91% of the accepted steps (§1). ×10 saves
  20.7% of a gradient run at 3e-5 and passes the accuracy and nudge tests. ×20 is the ceiling
  (−25.4%); ×30, ×50 and ×100 stop converging, because the saturated top layer cycles at the
  explicit limit (§10).
- **The bound of 100.** The soil's 10 times rule A's 100 gives 1000. The error test then accepts
  steps with a soil stage at plant's 1000 MPa ceiling, and both roles' gradients are refused on
  every record. Bounded at 100, every gradient is finite and the combined setting saves 30.6–33.7%
  of a gradient run on three pulsed records (§8).
- **The 15-day cap.** On episodic the `lma` ×2 invader raised a non-finite density on rule A's
  31–38-day steps. Its pools are unstable past 3.73τ_s, 26 days. With a 15-day cap no walk raises,
  at 15, 20 or 22 days; the invader raises only at 26. The cap gives up 0.0–2.4% of rule A's
  saving. It moves the resident's pool traits by up to 0.187ε, which is the cap correcting the
  uncapped run: capped runs are closer to 1e-5 (§8, phase 1c).
- **The soil's substeps** (PLANT-105, `design-soil-alone.md`). Where the plants draw under 10% of
  the water, the soil is integrated on its own under an uptake extrapolated from the last step
  (the slope, recorded on the row and held in replays and the sweep), with a corrector pass, and
  the coupling's error enters the norm at the members' weight. Gates G1–G7 all hold: rows −41.5%
  and −44.8% against bounded Cash–Karp on long drought and episodic, every elasticity within
  0.063ε for both roles; a gradient run takes 0.63 of bounded Cash–Karp's time; off, it is bit for
  bit. Under constant rain it takes 0.98 of the implicit chain's member evaluations, at J +6.9e-8,
  so ARK retired (`measurements/soil-alone/`, S3). It also cures the stiff top soil (mode E2,
  below).
- **The knots inside the step.** As step targets the knots shortened steps about 2× and set half
  of every run's rows. A step that spans a knot without landing it misplaces the rain, and the
  error estimate cannot see it: at 1e-4 without knot stops dry's J moved 7.6ε in ln J and up to
  19ε in elasticities. plant#111 substeps the soil across each knot instead: answers move ≤ 0.23ε,
  rows −10 to −27% (`rootcause/error-modes.md` E1; `round4/{E,G,R,S}/`).
- **The leaf solve to roundoff.** A replay's noise fell from 2.7e-8 to 8.5e-15 in ln J, ln J
  moved −1.5e-6, and a replay costs 1.12× as long. It was built for the splits' gates; whether it
  still pays without them is untested. `refine2/perf.md` proposes the opposite move (roots to a
  relative 1e-10, below).

**The commitment** (`design-grid-controller.md`): the global step is set by the error norm alone,
which weighs each state by its reach into the objectives; whatever the norm cannot see is refined
inside the step, never by shortening it. The 15-day cap is the one exception, read off τ_s rather
than the run. The kill condition: a second component whose error can be neither weighted nor
refined locally, or a cap that costs more than a fifth of the window's saving.

## Rejected and retired

Each with what it measured (`design-grid-controller.md`, *Tried and not kept*; §n):
- **Dormand–Prince 5(4).** 11–15% more rows, stalls at a larger error, 8–38× the stage
  rejections; its stages go negative past 1.04τ (−4.25 on a 15-day step) against Cash–Karp's
  2.16τ. Cash–Karp has a free fourth-order dense output of its own (phase 1b).
- **The implicit chain (ARK) for the soil.** It won phase 1a's pre-registered rule, but on the
  pulsed records ARK with rule A stayed 2.0–2.7× farther from 1e-5 than bounded Cash–Karp at
  3e-5, for only 6–11% less cost, and its embedded estimate misjudges the soil on long steps in either direction (§7, §10). Retired once
  the soil substeps matched it under constant rain.
- **RODAS on the whole stand.** Assessed, not run: plant's forward tangent holds the soil as a
  plain double, so every soil row and column of the Jacobian is zero.
- **The partitioned step.** Its coupling error sat in no norm, so it did not converge (§13). The
  substeps are not that partition: their coupling's error is in the norm.
- **The PI law, the chain seeds, the chain guard.** They turn rejections (paid once) into accepted
  steps (paid in every walk and sweep): 1.00–1.06 of a gradient run, scored in rows (§7).
- **Caps on crossings, onsets and transit; a stability margin on the soil** (9.6% for nothing);
  **capping each pool's motion per step** (14–41% for gradient errors as large or larger);
  **events at class switches.**
- **The knots as step targets,** replaced by plant#111 (above).
- **Splits at net production's sign changes, and the spread:** built, measured, then dropped on
  19 October (above). The splits cut a ±5% nudge's jitter 3–6× before the soil substeps existed
  (error-modes D4).
- **The invader's own sub-steps** where h/τ_eff > 2. Not needed under Cash–Karp with the 15-day
  cap (phase 1c).

## Where the tolerance error comes from

The refine loop's bound covers the node schedule only. The replay reuses the run's own steps, so
no estimate on the node axis can see the tolerance's error.

**What it costs today** (`rootcause/refine2/frontier.md`, libNS):
- dry-lma125 at 1e-4 (near extinction): TF24_cost_scale is 0.61ε off while the replay reads 0.03.
  A 5% tolerance nudge (1.05e-4) moves it 0.42ε, over OBJECTIVES' ε/3. At 3e-5 it is 0.01ε, for
  1.32× the rows. It is the one miss in 376 quantity-cases.
- From 3e-5 to 1e-4 a run keeps 0.744–0.751 of its rows (rows ∝ tol^−0.24) and moves quantities
  up to 0.20ε (episodic-lma).
- At 3e-4 episodic-lma keeps 0.788 of 1e-4's rows and 0.729 of its CPU, and moves the answer by
  at most 0.115ε. This is **the largest saving found** on either axis, and it is not admissible
  until the time axis supplies a tolerance estimate.
- The tolerance's error is flat to 1e-4 (≤ 0.06ε bias, the same in both runs of a pair) and starts
  between 1e-4 and 3e-4. It lies along one hydraulic direction, at 0.17–0.35ε on dry and lma. It is
  not a power law in the tolerance, so no second tolerance reads it (`error-modes.md` D3).

**The mechanism (D1): the leaf switches arm inside a step.** As the soil dries, every resident's
leaf moves from an interior optimum to the boundary (ψ_stem at ψ_crit). On dry, 48 of 56 nodes
switch within 0.44 d, 0.7 d before the seedling's gate shuts. Net production stays smooth, but
transpiration kinks, so the soil's sensitivity to TF24_cost_scale steps from 0.0159 to 0.
Cash–Karp integrates the derivative's jump inside one 1.5–5-day step with an error h·ΔG·φ(u),
φ ∈ [−0.2, 0.2] set by where the stages fall (`error-modes.md` D1; `round4/JT/notes.md`).
- *Order:* zero in node spacing; O(h) in step length, random in φ.
- *Where:* drydowns ending at closing edges, births 3.5–17 y; none after 17.
- *Direction:* one across gates, layouts and tolerances (cosines 0.81–0.97): TF24_cost_scale,
  stem_c, a_l1, R_d_25 against root_P50, a_r1, a, curv_fact_elec_trans.
- *Size:* a ±5% nudge moves an rms 0.02–0.03ε at 1e-4, and 0.048 at 3e-4 (TF24_cost_scale 0.18ε).
- dry-lma125's miss is TF24_cost_scale, on D1's direction, and it is fixed by a tighter tolerance.
  That it is D1 is *inferred*; no run has checked it.

**Single-run signal.** f_hi, the collar solve's marginal profit at the dry end, is computed on
every solve and is smooth through the switch. Its sign changes located all 56 switches within
≤ 5 minutes. A bound (θ/J/ε)·|λ_soil|·h·|ΔG|·0.2 ranks the switch steps so that the top 30 hold
90% of the effect, but it needs the run's own sweep.

**Measured fixes, all in the stepper** (nudge rms at 1e-4, with cost; `error-modes.md` D1):

| Fix | Nudge rms | Cost |
|---|---|---|
| none | 0.02–0.03 | — |
| a stop at each switch | 0.0020 | +12.8% rows |
| a stop only on steps > 0.5 d | 0.0081 | +7.1% rows |
| a split of the soil at the first and last switch | 0.010 | +8.5% evaluations, no extra rows |
| ETT (tolerance ×0.1 within 15 d of closing edges, from the pilot) | 0.025 | +8.6% rows |
| splitting the switching node alone | 0.044 | does nothing |

The arm stop cuts the 3e-4 nudge 24× (D3). These were measured on the lib19/libS builds before
19 October, on nudges of committed runs only. No pair or refine loop has run with any of them.

**D2, the averaged gate** (libAG only, a scratch build): a 2–3-day bump in dE/dt before P = 0,
nudge rms 0.110 at 1e-4; ETT takes it to 0.009 for +11.5% rows. It applies only if the averaged
establishment gate is ever adopted.

**What is missing: a per-run tolerance estimate.** Today a run cannot say how much of its answer is
tolerance error. Candidates, none built:
- the f_hi switch count and the ranked bound above (reads D1 only);
- a stop or soil split at the switches, which removes D1 and leaves a small, flat bias that a
  fixed term could carry, as u_q does on the node axis (*judgement*);
- a ±5% nudge run, which costs a run and reads only the reproducibility part.

With a tolerance estimate, the loop's bound would gain a time term, and 3e-4 could be weighed
against its −27% CPU.

## The error budget between the axes

`geometry.md` §6 (*derived*): cells go as ε_t^(−1/5) in the tolerance and ε_b^(−1/2) in the node
spacing on the square law (ε_b^(−1/4) with two rungs). Cells are fewest when the budget splits
between time and nodes as those exponents do: about 2:5, near even with two rungs. Its operating
point, loosening to about 3e-4 once kinks are cut, assumed the splits, which are now dropped.
Measured since, rows go as tol^−0.24 between 3e-5 and 1e-4 (frontier.md). On hard cases the
tolerance's share is not small: 0.61ε at 1e-4 on dry-lma125. So the claim that node error is about
100× time error (`design-grid-controller.md`, R1 and item 8) holds on the bank's easy cases only.

## Failure modes still worth guarding

From `rootcause/error-modes.md`:
- **E2, stiff top soil under explicit steps.** Heavy rain on a near-saturated top layer gives
  ∂rate/∂θ ≈ −1e4 to −3.6e4 per year. Cash–Karp is unstable past h·μ < −3.73, and the controller
  rides that limit, so the forward map turns briefly chaotic. J survives, but the exact derivative
  is a product of per-step factors up to 1e8–1e10. 2 of 62 saved long-drought runs blew up
  silently (elasticities to 2186), with no refusal. The soil substeps cure it. **Open:** a run
  should report its largest h·stiffness, where over 3.73 means a step ran unstable
  (`round3/D/notes.md`).
- **F, the derivative refuses where the forward caps.** A stage past the root curve's dry end,
  or in a collapsed collar interval, threw in the derivative only. Fixed in phylloptim 0.9.2 and
  0.9.3. The general rule: differentiate what the forward evaluates, bound every weight, check
  stages against the domain.
- **E3, a weight frees stages as well as errors:** the soil ×10 times the window's 100 put stages
  at the 1000 MPa ceiling. Hence the bound of 100.

## Landing it: the tolerance factors first

Of the time axis, only the soil substeps are in an open PR (plant#115, odelia#57). The per-state
tolerance factors and `control_tf24()` are the next piece, and the refine loop's evidence assumes
them. The 19 Oct stack review (`prs/residual-A.md`, PR B) set what lands:
- **odelia:** commit 30f9a7b from the `state-weights` branch. A System fills one positive factor
  per component at the start of a step, and `adjust_step_size` scales each component's error level
  by it, under both the GSL max rule and Hairer's RMS rule, at the outer error test only. A System
  without factors steps bit for bit as before.
- **plant:** the PLANT-100 branch without `ode_tol_factor_accumulator`, plus PLANT-104
  (`control_tf24()`, plant#104). That gives `ode_tol_factor_soil`, the `_times`/`_values` schedule
  and `ode_tol_factor_max`. Port them fresh onto the landed stack, on PLANT-105; do not rebase the
  PLANT-96…110 chain.
- **What it bought** (`prs/measurements.md`, M1, on the substepped soil): a quarter to a third of
  a gradient run, with accuracy unchanged against a 1e-5 reference.
- **Before it opens:** M1 ran on odelia 0.5.0 under GSL's max-norm rule, and odelia now defaults
  to Hairer's RMS norm, so re-time it on one case under that rule. The soil's factor and the time
  schedule were never measured apart; measure each alone, so the PR can say what each buys.
- **The window's weights stay outside plant for now.** `control_window()` was dropped (plant#106,
  closed), so rule A's table is harness data (`harness/schedule/data/weights/`). If the window
  stays, it belongs with the refine loop, built from the loop's own first run, and it must cover
  invaders (above).
- **With the refine loop, later:** about 30 lines of PLANT-110's `diagnose_scm` (each run's
  distance from its grid's run, invaders' ln(θ′/θ), failures) move into the scheduling PR
  (plant#110 stays open for them).

## Open

- **A per-run tolerance estimate** (above). It decides the tolerance (`rows-entries.md`, V1:
  1e-4 tied, an absolute of 1e-4, or 3e-5 tied).
- **The substep threshold's tuning.** It stays at 10% until tuned with the scheduling
  heuristics. Tuning includes making it tighten with the tolerance: J's error stops falling below
  3e-5 (+2.2e-5, +1.6e-8 and +2.3e-5 at 1e-4, 3e-5 and 1e-5, about 0.001ε). The soil spikes read it
  as the threshold's, held fixed while the tolerance tightens; that is untested.
- **Where the threshold sits:** chosen per run (L1) or at the schedule level (L3) with the window
  (`map-schedule-building.md` §6). Whether `control_tf24()` now sets the share by default is
  stated both ways in `design-grid-controller.md` (item 7.2 "not yet done", item 8 "now
  `control_tf24()`'s default"); `refine_case.R` sets it explicitly.
- **The window and invaders** (above), and the window's fixed 0–40-year grid, which breaks any
  simulation length (`refine.md` G4).
- **h·stiffness in the diagnostics** (E2).
- **The setting as plant's defaults,** with references blessed again in one commit.
- **The wobble.** On a frozen grid ln J departs from a smooth curve in `lma` by up to about 1e-7
  and the `lma` elasticity wanders by about 1e-3. It was measured with the splits on; what carries
  it is not traced (§18).
- **The positive part's width** (`storage_prod_eps` 1e-4) is part of TF24's definition: ln J moves
  −0.228 from 1e-4 to 1e-3 and +0.0165 (0.65ε) from 1e-4 to 1e-5. Whether it should narrow is the
  user's decision.

## Known behaviour

Gotchas from the time-axis work (`design-grid-controller.md`, *Running it*), each of which cost a
run or a wrong conclusion:
- **One J is one draw.** Moving tol by 3% moves plain Cash–Karp's J error by 2e-4. Compare
  treatments at nearby tolerances or by their error channels, never by one run.
- **A TF24 run at the default tolerance carries its own time error,** about 0.1% on five-year
  stands. Compare against a run integrated to 1e-6. Long drought's reference J* = 12.6687135 is
  from Cash–Karp at 1e-8; 1e-6 is 6.1e-6 low.
- **A replayed input must be exact:** TF24's leaf solve turns a one-ulp difference upstream into
  1e-9.
- **Two clocks:** a step's state is evaluated at fl(t + h) from the row below. After an entry the
  solver keeps the recorded time, and the System's clock must agree to 2 ulp.
- **An invasion's recording pass re-runs the run,** and reproduces it only while nothing between
  the two calls changes the SCM.
- **A zero pulse is not an entry,** even at an introduction's time.
- **A crossing step often holds class switches too:** separate them before blaming either. A
  switch smoothed within a step is still a kink to the integrator.
- **The pool's kink is a difference of slopes:** its rate's slope is (1 − G)(1 − r) above zero net
  production and r below, so the jump vanishes near r = 0.2.
- **Retaking an interval from the reference's state measures its local error only;** the
  survival error arrives with the state.
- **On pulsed records the soil has no fast mode to separate:** drainage goes as θ^16.14, so after
  rain a layer's relaxation rate is about one over the time since the rain.
- **A lambda returning an active product needs `-> value_type`;** a deduced return type returns an
  expression template over dead operands.
- **R reads a script as it runs:** run from a snapshot. Editing a running driver killed one of
  frontier.md's processes.
- **Load moves CPU:** compare A against B interleaved under the same load, or use rows
  (`refine2/perf.md`).
