# Design: a step and node controller for TF24's gradients

The goal is in `OBJECTIVES.md`. A **grid** is a run's node introductions (birth
dates) together with its ODE steps. Heuristics choose the grid so that reverse
mode gives `ln J`, gradients (as elasticities) and curvatures within ε, for
residents and invaders, on any rainfall record, at the least runtime. The
**four tests** of stability are reproducible, continuous in the traits,
predictable and never fails. The **floor** is brute force: uniform nodes,
plain error control, no heuristics.

The design is an assessment first, and code only where the assessment finds
something worth building:

1. **ε**, from the spread across realistic records.
2. **The enablers:** the two changes that make brute force pass the four tests
   on plant's own solver.
3. **The floor on a bank of records:** the reference, the error model of each
   axis, and the cheapest balanced setting.
4. **The headroom:** how much faster a grid can be at ε, how far it transfers,
   and whether a reformulation moves either by a large factor.
5. **Local analyses on one grid:** fitness landscapes and curvatures.

Heuristics follow the assessment, only where step 4 finds headroom. Where it
finds none, brute force at the balanced setting is the answer.

## What the design rests on

Measured on the long-drought record, one species at `lma = 0.32`, lifetime 40,
on the birth-date coordinate. The time-axis facts are from TF24 v12 (plant
`PLANT-97`) on 108 uniform nodes. The node-axis and transfer facts are from an
earlier build (plant `6613dd24`) at `ode_tol = 1e-3`
(`docs/measurements/perf-node-schedule.md`, `perf-across-theta.md`), and need
re-measuring under the enablers.

**The time axis.**
- *Steps must land on the rainfall's knots.* Zero-depth pulses at every active
  knot are step targets (#96). Without them `J` is 68% low at `tol = 1e-3`.
- *The NSC pool's absolute tolerance must scale with the pool.* Under the shared
  `tol·(|S| + 1)` in kg, a near-empty pool's relative error does not follow the
  tolerance, and mortality turns it into survival error (`∂m/∂ln S = −0.276`
  over a dry stretch). Plant's default at `tol = 1e-4` is +8.1e-4 in `J`.
  A per-pool absolute part of `tol·c·r₀·S_max` (`c = 1e-3`, `r₀ = 0.05`) on
  the driver keeps `J` within about 0.5·tol from `1e-3` to `3e-5`, for 16% more
  member evaluations.
- *The gradient's error sits on the steps where a node's net production
  crosses zero downward.* On one grid the gradient is a staircase in the
  crossing's position (step 5), so its error is first order in those steps'
  length whatever the method's order. The step controller's error estimate
  reports about a third of a crossing step's local error. Capping crossing steps at one day halves `lma`'s draw and
  quarters `a_dG2`'s for 5% more member evaluations. What remains at
  `tol = 1e-4` is 1–4e-4 relative (2e-4 to 1e-3 as elasticities).
- *The pool's stage guard, not positivity, stops pinned grids and invaders.*
  With the guard off, invaders from `lma` ×0.7 to ×2 run, a grid pinned at θ₀
  runs `lma` ×0.8 within 1.1e-4 of its reference, and every step's end stays
  above zero.
- *Tried and not kept:*
  - locating each crossing and stepping onto it (+2.6e-4 at `1e-4`, for about
    3× the cost);
  - re-integrating a crossing node on its own;
  - a wider positive part of net production (a model change that moves `J` by
    3.9%);
  - the crossing correction of Shelley and Tao, which halves `J`'s and `lma`'s
    draw and leaves `a_dG2`'s;
  - capping each pool's motion per step, which removes `J`'s bias and leaves
    the gradients' errors as large or larger, for 14–41% more;
  - implicit and multirate treatments of the soil (the soil's stages do not
    carry `J`'s time error).

  The records are `docs/oracle-consultation-solver-performance.md` and
  `docs/archive/scope-imex-stepper.md`.

**The node axis.**
- *The schedule's error is mostly the stand's response.* At uniform 215, 96% of
  `J`'s error is the competition field's quadrature, not `J`'s own trapezium.
- *`refine_schedule` refines for the wrong thing.* All its flags come from the
  competition term, and 59% fall where filling moves `J` less than the
  re-roll floor.
- *A cost-weighted schedule read off one pilot run is 2.8× cheaper than
  uniform at 1e-3 in `J`.* Its density is `∝ (|w″|/12 / member cost)^(1/3)`,
  read off uniform 108.
  - Its error is not monotone in the node count. It stays under 1e-3 only
    from 220 nodes, where it is 1.2× cheaper than uniform.
  - Designs from the rainfall alone, the tail or bands did not beat it.
- *Nodes cost members, not steps.* Steps are `10 732 + 0.95·nodes`, while the
  member evaluations scale with the node count.
- *The re-roll floor:* moving every node by 1e-5 to 1e-4 yr moves `J` by about
  6e-5 at `tol = 1e-3`, because the steps land elsewhere.

**Transfer.** A schedule built at θ₀ holds across `lma` ×0.7–×1.2, `hmat`
×0.8–×1.1 and `stem_P50` ×0.9–×1.25 to 2.8e-3 in `J`. Rebuilt at each θ it is
worse. A pinned θ₀ step program keeps `J` within 1.1e-3, but its steps' error
ratios, re-formed at θ ≠ θ₀, are 6–12.

**Reverse mode and invaders.** `stand_gradient()` differentiates the discrete
model on the grid the run took, so every column comes from one sweep of about
2.6 forward runs. An invader replays the resident's recording (#95), so every
invader of a resident shares its grid, and its sweep holds the resident's field
fixed. At θ′ = θ the invader's `J′` equals `J` exactly, and its gradient is the
selection gradient.

## Step 1: ε

`harness/eps_spread.R` runs one daily-weather seed of the long-drought record
at `tol = 1e-4` on 108 uniform nodes.
- It records `ln J` and every trait's elasticity, for the resident and for the
  invader at θ′ = θ.
- Over eight seeds with the drought years fixed, ε for each quantity is a tenth
  of its standard deviation.
- At one seed, the run at `tol = 1e-5`, and the one on 215 nodes, check that
  the setting's own error is small against the spread.
- ε is set once and held across the bank. A constant record has no spread of
  its own.

**Result** (`docs/measurements/eps-spread.md`).
- Over the eight seeds, `J` runs from 7.5 to 13.5. `ln J` has sd 0.25, so ε is 0.025.
- For the elasticities:

  | trait | resident: sd | resident: ε | invader: sd | invader: ε |
  |---|---|---|---|---|
  | `lma` (its own column) | 0.87 | 0.087 | 1.98 | 0.20 |
  | `a_dG2` | 0.19 | 0.019 | 0.50 | 0.050 |
  | `hmat` | 0.82 | 0.082 | 0.82 | 0.082 |
  | `stem_P50` | 0.67 | 0.067 | 2.17 | 0.22 |

  The other traits' ε run from 4e-5 (the invader's `a_d0`) to 1.2 (the invader's
  `curv_fact_colim`).
- *For `ln J` and the main elasticities the setting's own error is small against the
  spread.* At seed 31:
  - tightening `tol` from `1e-4` to `1e-5` moves `ln J` by 0.3% of its sd, and `lma`
    and `a_dG2` by at most 3.4%;
  - going from 108 to 215 nodes moves `ln J` by 1.7%, and `lma` and `a_dG2` by at most
    4.3% (the invader's `lma`). Extrapolated with the 429-node run, the 108-node error
    in `ln J` is about 2.2% of its sd;
  - for these quantities the node axis has 2.4–6× margin on ε, and the time axis about
    30×;
  - across the 48 traits with a spread, the median move is 0.4–3% of the sd;
  - the gradient errors measured on the driver, 1–4e-4 relative, are 50–200× below
    `a_dG2`'s ε.
- *Eleven moves exceed ε.*
  - Ten are in small elasticities, below 0.1 in size: `a_d0`, `a_st3`, `d_I` and the
    invader's `omega`. The eleventh is the invader's `a_l1`.
  - All but one move by 0.10–0.21 of their sd. The exception is the resident's
    `a_st3`, which moves by 2.3 sd between 108 and 215 nodes (−0.0026 to −0.0013). For
    that trait the node error is larger than its spread across records.
- *Quantities with no spread take no ε.* `S_D`'s elasticity is exactly 1 and `a_f3`'s
  exactly −0.75 on every record.
- *`J` falls in two groups across the records:* 7.5–8.0 and 12.4–13.5, with one record
  at 9.3. The spread in `ln J` is mostly which group a record falls in.
- *The invader's elasticities are not the resident's.*
  - `lma`'s is 2.7–3.3 times the resident's, and `a_dG2`'s 2.8–4.5 times. Over the 48
    traits, the median of `|invader/resident − 1|` is 1.4.
  - Finite differences at seed 31 confirm both: the sweep agrees to 7e-4 and 6e-5 for
    the resident, and to 1e-5 and 1e-6 for the invader.
  - The gap is the field's response to the resident's traits.
- *The sd itself is uncertain.* From eight records, its 90% interval is 0.71–1.80
  times the estimate.
- *A replayed step program is not exact.* Setting a run's own `p$ode_times` and
  `p$ode_step_sizes` reproduces `J` only to +5.1e-8, where `run_scm`'s documentation
  says the replay is exact.
- *What it means.* On this climate, accuracy does not bind at `tol = 1e-4` on 108
  nodes for `ln J` and the main elasticities, though a few small ones already exceed
  ε on the node axis. The questions for steps 3 and 4 are how far each axis can be loosened
  within ε, and whether the other regimes bind sooner. At looser tolerances the
  gradients, not `J`, are expected to bind first.
- *Cost.* A forward run took 81 s (median), and the resident's sweep 3.5 forward
  runs, since it repeats the run. A whole seed took 12.1 min for resident and invader
  with their sweeps: 15 min at `1e-5`, and 22 min on 215 nodes.
- *Curvatures, measured after.* `harness/curvature.R` takes the curvature
  `d e/d ln lma` of each elasticity `e` on the eight records, from reverse-mode
  gradients at `lma·e^{±0.01}` on one grid, under the tied tolerance on
  `PLANT-98`. `lma`'s own row is the chord less its `O(δ²)` term, which step
  4's first test puts within 0.2ε of the smooth value at seed 31; the others
  are the chord.

  | curvature in `lma` of | resident: mean, sd, ε | invader: mean, sd, ε |
  |---|---|---|
  | `lma`'s elasticity | −39, 11.6, 1.2 | −152, 40, 4.0 |
  | `a_dG2`'s | 0.94, 0.81, 0.081 | 8.8, 2.0, 0.20 |
  | `hmat`'s | −28, 11.4, 1.1 | −46, 18, 1.8 |
  | `stem_P50`'s | 27, 8.6, 0.86 | 98, 27, 2.7 |

## Step 2: the enablers

**Purpose.** Brute force on plant's solver passes the four tests: `J` and the
gradients follow the tolerance, nudges don't move them, and nothing throws for
residents or invaders over the trait range.

**(a) The pool's tolerance.**
- *The floor:* tie plant's shared absolute tolerance to the relative one,
  `ode_tol_abs = 1e-4·ode_tol_rel`. It is a setting, not code. Measured on
  v12t, long drought, 108 uniform nodes:
  - at `tol = 1e-4` it takes `J` from +8.1e-4 to +3.7e-5, for 26% more steps
    (11 814 to 14 846);
  - along the ladder `J`'s error is −4.0e-4, +3.3e-6, +3.7e-5 and −1.2e-5 at
    `tol = 1e-3, 3e-4, 1e-4, 3e-5`, within 0.46·tol at every rung, though its
    sign wanders where the per-pool scale's stays negative;
  - over seven tolerances within ±5% of `1e-4`, the median is +3.8e-5 and the
    standard deviation 1.6e-5, against the per-pool scale's −4.0e-5 and
    1.2e-5;
  - it costs 28% more step attempts than plant's default, where the
    per-pool scale costs 16% more member evaluations: about 10% dearer.

  On this record it matches the per-pool scale, so it is the setting the
  assessment uses.
- *The alternative, if the floor fails test 1 or 3 or costs too much on the
  bank:* a per-state absolute scale that a System may declare, as it may
  already declare `ode_state_valid()`. odelia's controller multiplies
  `tol_abs` by it, and TF24 declares `c·r₀·S_max` for its pool. This is the
  driver's per-pool scale, and it needs one concept in odelia and one method
  on plant's patch and strategy.
- *Decision rule:* keep the floor unless, on the bank, its nudges' spread
  exceeds a third of ε, or it costs more than 15% over the per-pool scale at
  matched error. The per-pool scale already runs on the driver
  (`POOL_FLOOR=1e-3`), so this comparison needs no new code.

**(b) The stage guard.** Delete TF24's stage check (`storage <
−storage_domain_tol·storage_max` throws), together with `storage_domain_tol`.
Keep the refusal of a step whose end leaves a pool below zero
(`Patch::ode_state_valid`).
- *Why it is safe:* storage mortality `a_dG1·exp(−a_dG2·r)` is finite below
  zero. A stage that overshoots gives large but finite rates, so the step's
  error estimate rejects it, and the end-state refusal keeps every committed
  pool non-negative.
- *Tests that change:* three expect "storage is negative"
  (`test-mutant.R:244`, `test-strategy-tf24.R:710, 747`). They become
  statements of what now happens: the invader runs, the rates at a negative
  stage are finite and restoring, the pinned run completes or is refused at
  its end state.
- *Pass:*
  - invaders from `lma` ×0.7 to ×2 on the long-drought resident run;
  - wherever `J′` is not negligible, it is within three times the base run's
    own error, against the same invaders on a base run at `tol = 1e-6`;
  - residents are bit-identical on a record where the guard never fired;
  - the FF16 reference tests are unchanged.

**Where it lands.** (a) is a setting in the harness until the bank confirms
it. (b) is aornugent/plant#98, on `PLANT-98` stacked on `PLANT-97`, which owns
the pool.

**(b) as measured.**
- *Where the guard never fired,* three TF24 stands are bit-identical.
- *The invaders* from `lma` ×0.7 to ×2 on the long-drought resident reproduce the
  probe build's guard-off `J′` to every digit, at `tol = 1e-3` and `1e-6`.
- *The resident at `tol = 1e-3`:*
  - `J` moves 12.66564 → 12.66219;
  - attempts thrown fall 149 → 0, 22 step ends are refused instead, and rejections
    for accuracy rise 1910 → 2011;
  - the attempts overall fall 0.6%.
- *At `tol = 1e-4` with the tied tolerance,* `J` moves by 1.2e-6.
- *The whole-run gradient reference moves on two of its five stands.* On the drought
  and seasonal ladder stands one refused attempt each set the base run's steps.
  Without it the sweep still agrees with a fresh difference of whole runs to 2.4e-4.
  - At the default tolerance the worst column moves from −1271.8 to −1638.7.
  - At `tol = 1e-6` and `1e-7` both builds agree, at −1565.9 and −1568.9.
  - So the default tolerance's gradients on these stands are 4–19% draws on where the
    steps land. The reference is recaptured.
- *The limit.* A walk has no error estimate, so a stage far below empty is committed
  there. At a zero relaxation offset on the height coordinate, the invader at
  `lma` ×1.05 now fails because its density overflows, not at the stage. The
  offset (#97) and the birth-date coordinate are what keep the measured invaders
  clear of this.

## Step 3: the floor on a bank of records

**The bank.** From `harness/long_drought.R`'s generator, each at two
daily-weather seeds except the constant record:

| regime | construction |
|---|---|
| constant | the long-drought mean every day: no knots, no dry spells |
| seasonal | the long-drought spec without its drought years |
| wet | `long-wet`: the same occurrence at mean 5.0, no droughts |
| dry | seasonal at the lowest mean at which the resident's `J` stays above 1 |
| episodic | rare wet days (`p01b` ≈ 0.03) with heavy gamma depths, same mean |
| long drought | the current spec |

The traits are θ₀, plus `lma` ×0.5 and ×2, where only the chosen setting and
its reference run.

**Brute force.** Uniform nodes, Cash–Karp under the enablers' setting, the
knots as step targets, no other heuristic.

**Per record, at θ₀, residents and invaders at θ′ = θ:**
- *The time ladder:* `tol = 1e-3, 3e-4, 1e-4, 3e-5` at 215 nodes.
- *The node ladder:* 108, 215, 429 and 857 nodes at `tol = 3e-5`.
- *The reference:* the finest rung on each axis combined, checked against one
  rung finer on the axis that dominates its error.
- *Nudges:* seven tolerances within ±5% of `1e-4`, and the introductions
  shifted by a quarter spacing at 215 nodes.

**What it yields.**
- The four tests' verdicts.
- The error model per axis: the constant and order for `ln J` and for each
  elasticity.
- The cheapest pair of tolerance and node count whose combined error is
  within ε. This is the split where each axis's marginal cost per unit of
  error is equal, and it is the first aligned setting, before any heuristic.

A failure is a System × Solver block still in the way, and it is debugged
before step 4.

**Cost.**
- Each ladder rung is a forward run, a sweep, an invasion and its sweep:
  about 7 forward runs. The nudges measure residents only, at about 3.6
  forward runs each.
- The node ladder's finest rungs dominate. That comes to about 5–7 CPU hours
  per record, 60–75 for the bank, and roughly a day of wall time on three
  cores.
- Run the long-drought record first, then episodic and dry, where the
  crossings are.
- Step 1's timings are the first check on these figures.

**Measured so far: the tolerance nudges on long drought.** Seed 31, 108 uniform
nodes, the tied tolerance on `PLANT-98`, at seven tolerances within ±5% of
`1e-4` (`harness/eps_spread.R` with `ATOL=1e-4`), resident and invader with
their sweeps. Each quantity's largest move from the `1e-4` run, against ε/3:
- `ln J` moves by 1.6e-5, 500× inside.
- *The invader passes everywhere:* its largest elasticity move is 0.32 of ε/3
  (`a_d0`), and `lma`'s is 0.03.
- *The resident fails on five of its 48 elasticities,* all in the storage pool's
  mortality and cost: `a_dG1` 1.65, `d_I` 1.61, the relaxation offset 1.38,
  `a_dG2` 1.21 and `TF24_cost_scale` 1.17 times ε/3. `lma`'s is 0.58, and the
  median 0.53.
- So brute force at this setting does not pass the first test for the resident.
  The moves are of the size of the gradient's noise on one grid that step 4's
  first test finds. The invader's are 8–400× smaller in absolute terms; its
  gradient holds the field fixed, where the resident's carries the field's
  response.
- The build without the end-state refusal gives the same seven runs bit for
  bit (step 4, *The refusal*).

## Step 4: the headroom

The question is how far from the floor a grid can be pushed, on each regime:
the runtime at ε, and the transfer radius.

**(a) The grid tuned to θ₀.**
- *Nodes:* the cost-weighted equidistribution read off a pilot. A second
  version reads the stand's response from band fills, as the node-schedule
  note did.
- *Steps:* adaptive, with crossing steps capped at one day.
- *Measured:* its runtime at ε against the floor's balanced setting.

**(b) The grid from the rainfall alone.** Step targets and caps from the
record (knots, onsets, dry spans), and node density from the record. The
rainfall does not move with θ, so what this captures transfers for free, and
only the trait-driven remainder trades speed against radius. On the node axis
the earlier rainfall-only designs lost to the cost-weighted one for `J`.
Re-test one design at two counts for the gradients.

**(c) The transfer radius of (a), (b) and the floor.** Residents pinned at
`lma` ×0.9, 0.95, 1.05 and 1.1. Invaders at θ′ ×0.5, 0.7, 1.4 and 2 on the
resident's recording. The radius is the largest move in `ln θ` over which the
four tests hold at ε.

**(d) Reformulations.** Before accepting the frontier that (a)–(c) trace, ask
whether a different formulation moves it by a large factor in accuracy,
stability, runtime or simplicity:
- goal-oriented control from the sweep's adjoint (Cao and Petzold);
- a crossing treatment that makes a step smooth in where the crossing falls;
- a pool update that is non-negative at every stage;
- a change of variables for the pool;
- a node rule that follows the stand's response rather than `J`'s integrand.

The consultation is `docs/oracle-consultation-grid-controller.md`, and the
reply `docs/oracle-response-grid-controller.md`. Each proposal is tested on
the driver (`harness/ark_prototype.R`) or on plant before anything is built.

**The reply.**
- *Its claim:* a node's crossing of zero net production is a kink at any step
  size, and one grid sees it at three orders. `J`'s error is second order in
  the crossing step, with zero mean over where the crossing falls. The
  gradient's is first order. The second derivative, taken on the grid between
  the gradient's jumps, is off at zeroth order at any tolerance, by
  `−Σ_c (λ_c·Δ_c)(∂t_c/∂θ)²` over the crossings `c`. The jumps restore the
  chord across them, not the value between them.
- *Its remedy:* find each crossing on the member's own interpolant, split that
  member's update there, and differentiate the crossing time in the sweep
  through the implicit-function theorem, as the inner solve is. It puts the
  cost at 4%, and says curvatures then follow from gradient differences over
  ±1–2% on one grid.
- *Its other proposals:*
  - creation nodes at the edges of each span where newborns grow, none inside
    the gaps;
  - step control weighted by the sweep's adjoint;
  - a stability margin `h|λ_chain| ≤ 0.5β` for the soil;
  - the pool as `asinh(S/S_ref)`;
  - deleting every refusal, the end-state one included;
  - the walked error ratio as a run's radius diagnostic;
  - a warm-started inner solve, which it puts at 2–3× on the member loop.

**The reply's tests,** on long drought at seed 31, 108 uniform nodes and
`tol = 1e-4`.

*The bias.* `harness/curvature.R` on `PLANT-98` with the tied tolerance takes
`H(δ) = (e(δ) − e(−δ))/2δ` for `lma`'s elasticity `e`, from reverse-mode
gradients at `lma·e^{±δ}`: the resident pinned to θ₀'s steps, and the invader
walked through θ₀'s recording.

| δ | 1e-6 | 1e-5 | 1e-4 | 1e-3 | 1e-2 | 3e-2 |
|---|---|---|---|---|---|---|
| resident | −58.8 | −57.2 | −53.2 | −47.1 | −44.2 | −43.7 |
| invader | −206.2 | −206.0 | −204.4 | −201.8 | −192.7 | −182.8 |

- *The second differences of `ln J`* are −54.8, −47.2, −44.0 and −43.8 for the
  resident at δ = 1e-4 to 3e-2, and −205.3, −201.4, −196.6 and −185.7 for the
  invader.
- *The smooth value.* The chord's `O(δ²)` term is twice the second
  difference's, so `2·(ln J)″ − chord` cancels it. That gives −43.9 and −43.8
  for the resident at 1e-2 and 3e-2. For the invader it gives −200.9 and
  −200.5 at 1e-3 and 1e-2, and −188.7 at 3e-2, where the higher-order terms
  are not small.
- *Between jumps the grid's second derivative is 15 below that for the
  resident (34%), and 6 below for the invader (3%).* On each side of θ₀ the
  slope between jumps is steeper than the chords, so the jumps are upward, as
  the reply's `K″` has them. So the claim holds.
- *The jumps' size.* Over consecutive intervals the resident's slopes run from
  −34 to −59: its elasticity strays from a smooth one by about 0.01 (1e-3 of
  itself), and the invader's by 5e-4 to 1e-3 (3e-5 of itself). A chord over
  ±δ is off by about that over δ: ±1 for the resident at δ = 1e-2.
- *Against adaptive runs,* each on its own grid at `lma·e^{±δ}`, the resident's
  chords are −43.1 and −43.6 at δ = 1e-2 and 3e-2, and −43.7 combined at both.
  The frozen grid's combined values are within 0.2 of that.
- *The gradient itself differs between grids.* At `lma·e^{0.01}` the pinned and
  the adaptive run's `lma` elasticities differ by 0.025, and by 0.001–0.007 at
  the other three points. The resident's ε/3 is 0.029.
- *Against ε for curvatures* (step 1), the value between jumps is off by 13ε
  for the resident and 1.4ε for the invader, so the claim is not moot here.
  The chord less its `O(δ²)` term at δ = 1e-2 is within 0.2ε for both. The plain
  chord at 1e-2 is not, for the invader: its `O(δ²)` term is 7.8, or 2ε.

*The margin and the walked ratio.* The driver at the per-pool scale, with the
stage guard out of reach, builds θ₀'s grid with and without the margin and
walks each at `lma` ×0.9 to ×1.1.
- The margin costs 16% more steps and 9.6% more member evaluations
  (5.90e6 against 5.38e6), for the same `J` to 4e-7.
- Walked, the largest error ratio and the count above 1.1:

  | grid | ×0.9 | ×0.95 | ×1.05 | ×1.1 |
  |---|---|---|---|---|
  | plain | 65, 288 | 55, 242 | 10, 90 | 14, 118 |
  | with the margin | 130, 282 | 13, 233 | 13, 81 | 13, 100 |

- In both, the storage pools set the ratio on 82–97% of the steps above 1.1,
  and the soil on 2–18%.
- Against adaptive runs at `1e-5`, the walked `J` is off by −3.0e-5 to +8.0e-5
  on the plain grid and −1.2e-4 to +1.0e-5 with the margin, where θ₀'s own
  runs are off by −6.0e-5. That is 200× inside ε.
- So the margin buys no radius here, and the walked ratio does not measure one:
  the pools set it, and a ratio of 65 goes with an error in `J` of 1e-4.

*The split, as a first cut.* The driver's `LOCAL` re-integrates each member
whose `P` changes sign across a step on its own, in two Cash–Karp sub-steps
split at the crossing, with the rest of the state read from the step's
interpolant. On a replay it finds the crossing again at the replay's θ, to
`|P| < 5e-11`. It has neither the reply's fixed event structure nor the
class switch's event. On the per-pool scale's grid at `1e-4`, second
differences of `ln J` in `lma` (through the trait):

| `r` in `lma·(1 ± r)` | 1e-4 | 1e-3 | 1e-2 |
|---|---|---|---|
| plain | −31.3 | −22.1 | −19.2 |
| split | −222 | −20.4 | −19.6 |

- At 1e-3 the split is nearer the wide chord than the plain grid is, as the
  claim has it.
- But the split's `J` jumps by 1.7e-6 between `lma` ×1 and ×(1 + 1e-4), so no
  small difference survives it. Finding the crossings to `|P| < 5e-4` instead
  changes `J` by 5e-7 and leaves the jump.
- The jump is the split's structure changing. Of the 9231 crossings, four move
  to the next step between the two, and one member's dip below zero, down and
  up within 1e-5 of a time unit, disappears. The reply's fixed event structure
  is what holds the first kind; the second it calls the model's own.
- It costs 4× a plain replay on the driver, where each member's sub-step
  evaluates the whole patch.

*The refusal.* A build of `PLANT-98` without TF24's `non_negative_states()`,
so with no end-state refusal, runs step 3's seven tolerance nudges.
- On `PLANT-98` the refusal turns away one attempt in each run, of about 18 200.
  Without it the error test rejects that attempt instead, and the retry is the
  same size, so every run is the same bit for bit.
- So on this record the refusal is redundant, and deleting it changes nothing.
  Whether it is elsewhere, the bank says.

**What it yields.** Per regime: the speedup at ε for (a) and (b), the radius of
each, and a verdict on each reformulation. A heuristic is built only where
the speedup is worth its code.

## Step 5: local analyses on one grid

**The staircase.** Take `J = y(1)` for `y′ = max(0, θ − t)` under Euler. Its
gradient in θ is a staircase, correct to within a step, and its second
derivative by automatic differentiation is zero where the true one is 1. On
one grid, TF24's gradient jumps each time, as θ′ moves, a node's zero crossing
of net production slides past an RK stage. So a curvature has to come from
gradient differences over a trait step wide enough to average the jumps, or
from steps that are smooth in where the crossing falls.

**On the long-drought and episodic records, on the floor's and step 4's
grids:**
- *An invader landscape,* `J′(θ′)` over ×0.5–×2 of the resident on its one
  recording, against brute force. It passes when it is continuous and within
  ε, and nothing throws.
- *The curvature at θ′ = θ,* `d² ln J′/d(ln θ′)²`, from central differences
  of reverse-mode gradients at θ′ = θ·e^{±δ} for δ = 1e-3, 3e-3, 1e-2 and
  3e-2, on plant and on the driver with and without the crossing correction.
  The answer is the smallest δ at which the curvature is within its ε.
- *The resident's own curvature* on grids pinned within ±10% of θ₀.

**Pass.** Each is within its ε at some δ inside the analysis window.

**Measured so far.** Step 4's first test is this ladder at seed 31 on the
floor's grid, from δ = 1e-6 to 3e-2: the chord over ±1e-2 less its `O(δ²)` term
is the curvature to about ±1 for the resident and better for the invader.

## After the assessment: the heuristics

Each heuristic is a rule, a guarantee and a check:
- the guarantee is the four tests at ε on the bank;
- the check runs every time and reports the error estimate, θ's distance from
  the grid's θ₀ against the radius, and failures.

Degrading is one loop: build a grid, check it, refine where the check fails,
and at worst reach brute force.

The leading candidate for the node axis is the archived controller
(`docs/archive/scope-schedule-controller.md` §2–§3):
- two error maps from the sweep, the adjoint-weighted local error of each step
  and the value per unit of recruitment at each cohort;
- placement by equidistribution;
- the budget split between the axes;
- a certificate that decides when to rebuild.

It is built only if step 4 shows it pays for itself.

## Running it

**Session start** (AGENTS.md): `git submodule update --init --recursive`, and
`add_repo` for `aornugent/odelia`, `aornugent/plant` and `aornugent/phylloptim`.

**A private library,** with `DEV` under the scratchpad:

```bash
mkdir -p $DEV/lib_stack
git -C odelia     fetch origin claude/trusting-curie-4i9n3l
git -C odelia     worktree add --detach $DEV/odelia05 origin/claude/trusting-curie-4i9n3l
git -C phylloptim worktree add --detach $DEV/phylloptim09 378b083
git -C plant      fetch origin PLANT-95
git -C plant      worktree add -b PLANT-95 $DEV/stack origin/PLANT-95
export R_LIBS=$DEV/lib_stack MAKEFLAGS=-j4
for pkg in odelia05 phylloptim09 stack; do
  R CMD INSTALL --no-docs --library=$DEV/lib_stack $DEV/$pkg > $DEV/install_$pkg.log 2>&1 || { echo "FAILED $pkg"; break; }
done
```

- **Build times.** odelia builds in 26 s and plant in about 3 min.
  - After an odelia edit, reinstall plant with `--preclean`: it compiles
    odelia's headers and does not track them.
  - A new value exposed to R needs an entry in `inst/RcppR6_classes.yml`, and
    `RcppR6::RcppR6()` before the rebuild.
- **The v12 build** with zero pulses as step targets merges the two branches,
  one at a time, and `harness/` runs on it:
  1. `git -C plant worktree add -b v12-targets $DEV/v12t origin/PLANT-95`
  2. `git -C $DEV/v12t merge origin/PLANT-96` (a fast-forward)
  3. `git -C $DEV/v12t merge origin/PLANT-97`, keeping both `NEWS.md`
     entries in the one conflict
  4. Install odelia05, phylloptim09 and `$DEV/v12t` into a library of their
     own.
- **The probe build** is `harness/tf24_probe.patch` applied to v12t. It adds
  the driver's `CLASS_EVENTS` and `CLASS_LOG`, a wider positive part
  (`TF24_PROD_EPS`, `TF24_PROD_EPS_REL`) and a settable stage guard
  (`TF24_DOMAIN_TOL`).
  - Apply it with `git -C $DEV/v12probe apply "$PWD/harness/tf24_probe.patch"`
    from the plant-dev root.
  - It puts the leaf's operating-point class in the thirteenth auxiliary.
  - With the default environment it reproduces v12t bit for bit.
- **Tests** run with `TESTTHAT_PARALLEL=false`, by AGENTS.md's tiers:
  `testthat::test_file(..., package = "plant", load_package = "installed")`
  after `library(odelia)`.
  - On `PLANT-95` the full serial suite passes 4651 and fails 2, in 9.1 min;
    odelia passes 325.
  - The two failures are older than #95: `test-mutant.R`'s "mutant method
    works" on FF16's ten-mutant panels, which are pinned to `develop`.
  - odelia's `test-implicit-value.R` has 5 errors: its snippet passes a braced
    list to a `std::span` parameter, which this compiler refuses.

**The harness.**
- `long_drought.R` holds the record generator and `run_J`.
- `ark_prototype.R` is an R driver that reproduces plant's Cash–Karp run bit
  for bit, with options for step rules and replays (see its header).
- `eps_spread.R` does step 1.
- `curvature.R` takes reverse-mode gradients at `lma·e^{±δ}` on one grid, for
  the curvatures of steps 1, 4 and 5.
- `v12_steps.R`, `error_channels.R`, `j_error_trace.R` and `soil_bound.R`
  record and decompose a run's steps and errors.

**Known behaviour.**
- *One `J` is one draw:* moving tol by 3% moves plain Cash–Karp's `J` error by
  2e-4. Compare treatments by nearby tolerances or by their channels
  (`harness/error_channels.R`), never by one run.
- *A split reference stops converging near its resolution:* split 8, 16 and 32
  ways, the driver's 1e-6 grid moves by 3e-5 in `lma` and 1.3e-4 in `a_dG2`.
- *The reference for long drought at θ₀ is `J* = 12.6687135`,* from Cash–Karp
  at `1e-8`. The run at `1e-6` is 6.1e-6 low.
- *A TF24 run at the default tolerance carries its own time error,* about 0.1%
  on five-year stands. Compare against a run integrated to `1e-6`.
- *`lma`'s pinned difference has a floor near 1e-5,* on residents too.
- *A crossing step often holds class switches too:* split them apart before
  blaming either.
- *A switch smoothed within a step is still a kink to the integrator.*
- *The pool's kink is a difference of slopes:* its rate has slope `(1 − G)(1 −
  r)` in net production above zero and `r` below, so the jump vanishes near
  `r = 0.2`.
- *A crossing correction needs the crossing from the stages, and a sharp
  switch.* From the step's ends the crossing's place misses by a tenth of the
  step. A node whose net production moves less than about 100ε across the step
  has no kink at the step's scale.
- *A correction put on the tape must be zero in value,* or the sweep no longer
  repeats the run's values.
- *Retaking an interval from the reference's state measures its local error
  only:* the survival error arrives with the state.
- *The soil has no fast mode to take implicitly:* drainage goes as `θ^16.14`, so
  after rain a layer's relaxation rate is about one over the time since the rain.
  ARK's longer steps there were inaccurate, and on one its embedded estimate put
  the top layer's error at a fifteenth of its size.
- *A replayed input must be exact:* TF24's leaf solve turns a one-ulp
  difference upstream into 1e-9.
- *A slot's choices are a sequence:* TF24's leaf points are read in order, so
  only a full evaluation may read a full evaluation's slot.
- *Two clocks:* a step's `at_state` ran at `fl(t + h)` from the row below. After
  an entry the solver keeps the recorded time, and the System's clock must
  agree to 2 ulp.
- *An invasion's recording pass re-runs the run,* and reproduces it only while
  nothing between the two calls changes the SCM.
- *A zero pulse is not an entry,* even at an introduction's time. `entries()`,
  `size`, the walks and `event_log` never see it.
- *A lambda returning an active product needs `-> value_type`:* a deduced
  return type hands back an expression template over dead operands.
- *R reads a script as it runs:* run from a snapshot.
- *`queue.sh` needs absolute paths.*
