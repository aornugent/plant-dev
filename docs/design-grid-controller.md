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
  - implicit and multirate treatments of the soil, held to the norm's
    tolerance (the soil's stages do not carry `J`'s time error). The chain
    implicit and out of the norm together is untested (`grid-dynamics.md`
    §10).

  The records are `docs/archive/oracle-consultation-solver-performance.md` and
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
- *Rows are the cost that counts.* A run with every gradient of both roles is
  about seven forwards: the forward, the stand's sweep, the invader's walk (0.8)
  and its sweep. The walk and the sweeps pay each accepted step's members, its
  rows, again; the forward alone pays rejections. Rows come first, then the
  sweep's cost per row (`grid-dynamics.md`, *What a gradient run pays*).

## Step 1: ε

`harness/run_record.R` with `ATOL=1` runs one daily-weather seed of the
long-drought record at `tol = 1e-4` on 108 uniform nodes.
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

## Step 3: the floor, checked run by run

**Why not a bank of references.** A reference and both ladders on eleven
records would cost about 100 CPU hours. The objectives already ask each run to
estimate its own error (*Predictable*, *Diagnosed*). So each grid carries two
companion runs, and the records only test that check where the dynamics differ
from long drought, whose references (steps 1 and 4) show whether it is honest.

**The check,** on every grid the floor builds:
- *A tolerance companion* at `tol` ×1.05: every quantity moves by less than
  ε/6. One companion samples the gradient's noise once, so the limit is half the
  first test's ε/3. On long drought at `1e-5` the largest of seven nudges was
  0.17 of ε/3.
- *A node companion* on half the nodes: every quantity moves by less than ε. If
  the error falls as the spacing squared, the full grid's error is a third of
  the move. Measured, half of 108 is off the square law on every record, and
  only a companion on twice the nodes decides 108, at twice the base run's
  cost.
- *A failed check refines,* the tolerance by 3 or the nodes by 2, and checks
  again: brute force by degrees, which is also the loop the heuristics reuse.
- *It costs* about 1.05× and 0.55× of the base run. A local analysis walks many
  invaders on one grid, which spreads it to about 13%.

**The floor's setting,** to be checked: Cash–Karp under the tied tolerance at
`3e-5`, 108 uniform nodes, the knots as step targets.

**The records,** from `harness/long_drought.R`, one seed each:

| regime | construction | `J` at `1e-4` |
|---|---|---|
| constant | long drought's mean every day: no knots, no dry spells | 1.20 |
| wet | `long-wet`: the same occurrence at mean 5.0, no droughts | |
| episodic | rare wet days (`p01b = 0.03`) with heavy depths, at mean 3.0 | 1.98 |
| dry | seasonal at mean 0.4, near the lowest at which `J` stays above 1 | 1.56 at 0.45, 0.53 at 0.3 |
| long drought | the current spec, with seven nudges around `3e-5` | 12.7 |

Seasonal, long drought without its droughts, is defined but not run.

**What every run saves** (`harness/run_record.R`, written after each phase):
- the setting and versions, the record and its knots, the node schedule;
- the step program and the attempts by outcome;
- each node's birth time, establishment weight and net reproduction ratio;
- the event log;
- `J`, and every gradient and elasticity for the stand and for its invader at
  θ′ = θ;
- each phase's time and the peak memory, and any phase's failure, the rest
  still running.

`harness/spot_check.R` reads a directory of them against
`docs/measurements/eps.csv`.

**Deferred:** each axis's order per regime and the cheapest balanced setting.
They serve the Performant objective, and step 4 measures them against a
heuristic.

**Measured: the spot-check** (`docs/measurements/spot-check.md`), at `3e-5` on
108 nodes, in 37 minutes on four cores.
- *The tolerance check* passes on episodic. It fails by one quantity on wet and
  long drought, the resident's `a_dG1` (0.23–0.24ε against ε/6), and on dry,
  where 21 of the resident's 49 quantities exceed it (`omega` moves 0.65ε). Every
  invader passes but the constant record's.
- *The node check on 54 nodes* fails on every record, by up to 94ε (the
  resident's `a_st3`). Its spacing is longer than long drought's spans between
  gaps in creation, so it does not decide 108 nodes; 215 is the next rung.
- *On the constant record the invader's `J′` is nearly singular* in its traits
  at θ′ = θ: 1424, 1.204 and 0.0028 at `lma`·e^{−0.001}, ×1 and e^{+0.001}, and
  the sweep's elasticity is −1.4e17. The tolerance check flags it. Both are
  artefacts of uniform nodes, resolved below.
- *Nothing failed:* no phase raised and no attempt was refused, and on every run
  the invader at θ′ = θ and the census reproduce `J` exactly.

**Measured: the 215-node rung and dry at `1e-5`** (the same note), seven more
runs: each record on 215 nodes at `3e-5`, and dry at `1e-5` and `1.05e-5` on
108. The 108-node error is estimated as 4/3 of the move to 215 nodes, if the
error falls as the spacing squared. The main traits are `ln J` and the traits
step 1 takes curvatures in (`lma`, `a_dG2`, `hmat`, `stem_P50`, `rho`).

| record | role | main traits' largest 108-node error | quantities over ε | over ε/3 |
|---|---|---|---|---|
| long drought | resident | `lma` 0.42ε | 2 of 49 | 19 |
| long drought | invader | `lma` 0.65ε | 3 | 22 |
| episodic | resident | `lma` 0.18ε | 3 | 7 |
| episodic | invader | `ln J` 0.18ε | 4 | 7 |
| wet | resident | `a_dG2` 0.40ε | 1 | 7 |
| wet | invader | `lma` 1.19ε | 12 | 31 |
| dry | resident | `a_dG2` 0.94ε | 6 | 41 |
| dry | invader | `stem_P50` 0.64ε | 2 | 39 |

- *108 nodes keeps the main traits within ε* on long drought and episodic, not
  for wet's invader, and only just on dry.
- *The 54- and 215-node estimates disagree.* On dry `J` falls 4.6% from 54 nodes
  to 108 and rises 0.7% from 108 to 215, so 54 nodes is off the square law.
- *The constant record does not converge in uniform nodes:* `J` is 0.0008,
  1.204 and 200.7 on 54, 108 and 215 nodes, and the invader's `lma` elasticity
  is −749 on 215. None of them resolves its founders (below).
- *Dry at `1e-5` passes the tolerance check* but for one quantity just over the
  limit, the resident's `TF24_cost_scale` at 0.178ε against ε/6. The largest
  move falls from 0.65ε (`omega`) at `3e-5` to 0.18ε, and the main traits' from
  0.23ε to 0.09ε.
- *So on wet and dry the check points to `1e-5` on 215 nodes,* not yet run as
  one setting, and `1e-5` not on wet. On 215 nodes the main traits' node error
  would be a quarter of 108's, under ε/3 on every record. It would cost about
  2.5× `3e-5` on 108: 215 nodes costs 1.97–2.13× 108 on the four records, and
  `1e-5` costs 1.21× `3e-5` on dry.
- *The small elasticities step 1 flagged miss their ε on every record:* `a_st3`
  (14–71ε for the resident), `a_d0`, `omega` and `a_l1`, and 215 nodes would not
  bring them within it. Their ε is a tenth of a spread they barely have. Their
  errors are small in absolute terms: no small elasticity's 108-node error
  exceeds 0.012 (the resident's `rooting_depth_max` on dry), and `a_st3`'s 71ε
  on episodic is 0.004.
- *With an elasticity's ε at least 0.01,* the 108-node error exceeds ε on three
  quantities outside wet and the constant record, each by under 1.6× (the
  invader's `a_l1` on long drought the largest), and on nine of wet's invader's.
  Whether ε takes that floor is for `OBJECTIVES.md`.

**Measured: how each error scales** (`harness/error_structure.R`, from the runs
on disk; the spot-check note's last section).
- *The time axis is cheap to brute-force.* Steps go as tol^−0.15, while the
  resident's nudge spread falls as tol^0.6–0.8 and its bias from `1e-4` to
  `1e-5` is 0.03ε for the main traits. The invader's spread stays under 0.07ε.
  A rule on this axis can save at most the steps between a passing tolerance
  and one where the bias binds: 1.42× from `1e-5` to `1e-4`, about 2× to
  `1e-3`.
- *The node axis carries the error:* at `3e-5` the move to 215 nodes is 4–46×
  the tolerance nudge's, and the rungs 54, 108 and 215 are on no power law.
  The 54-node rung is what breaks it. On long drought 108, 215 and 429 nodes are
  on the square law for `J` (step 4, *the second reply's tests*).
- *That error lives in births before 3,* as a field part (+1.0 to +2.8% of `J`)
  and a quadrature part (−0.6 to −2.1%) that cancel to +0.3–0.7%. Those 9 of 108
  nodes cost 16% of the member evaluations; uniform refinement spends the other
  84% where at most 27% of the net move lives.
- *On the constant record the first node is all of `J`,* with a net
  reproduction ratio of 0.098, 297 and 9.9e4 on 54, 108 and 215 nodes: a layer
  at the start of the patch that no uniform count resolves.

**Measured: the constant record, resolved** (`harness/first_panel.R`; the
spot-check note's last section).
- *Nothing thins its stand, so the canopy closes for good,* and only the
  founders survive: cohorts born in the first 0.064 years (23 days) reach
  18 m, and every later one stalls under them and starves.
- *Uniform nodes lump the founders into the first node,* with half a spacing of
  recruits, 1.4–5.8× theirs. It shades itself, levels off at 13.7–17.7 m, and
  straddles `hmat` (16.6 m) on the reproduction switch, whose slope is 50: its
  share of production into seed is 1.6e-4, 0.30 and 0.97 on 54, 108 and 215.
- *Resolved, `J` is 288–292* with the first spacing split 8, 32 and 128 ways,
  and 288.2 on plant's default schedule, which puts 57 of 108 nodes before day
  24. The resident's `lma` elasticity is −7.1, not −18.4. The invader's is −194
  by finite differences at 8 and 32 ways, and −173 and −155 swept: a kink at
  θ′ = θ, not a singularity.
- *Elsewhere the first spacing barely matters:* split 8 ways it moves `J` by
  −0.05 to −0.60%, opposite to the move to 215 nodes.
- *The resident's structure transfers; the invader's moves.* Over
  `lma`·e^{±0.02} the resident keeps the same six founders and a smooth `J`
  (333.9 to 251.6). The births carrying 90% of the invader's `J′` end at 2.2,
  0.12 and 0.012 years at ×0.5, ×0.99 and ×1.01, and `J′` is 911, 291.5 and
  0.0026 at ×0.99, ×1 and ×1.01: a contest for the canopy that no schedule
  smooths.
- *So a node rule must resolve the founders where nothing thins the canopy.*
  On this record a spacing of 0.046 years before day 24 already puts `ln J`
  within ε/3 of the finest split's (0.21ε), as 0.012 does (0.30ε). Halving the
  spacing over an early window does not reach it.
- *Later: none of these splits resolves the founders' front.* With the first
  window graded and nodes every 1/16 day around the front, `J` converges at
  289.274, the resident's `lma` elasticity at −6.94 and the invader's at −186.2
  (step 4, *the second reply's tests*).

**Measured so far: the tolerance nudges on long drought.** Seed 31, 108 uniform
nodes, the tied tolerance on `PLANT-98`, at seven tolerances within ±5% of
`1e-4` (`harness/run_record.R`), resident and invader with their sweeps. Each quantity's largest move from the `1e-4` run, against ε/3:
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
- *At `1e-5` everything passes,* for 42% more steps (21 107 against 14 839). The
  resident's largest move is 0.17 of ε/3 (`omega`) and its median 0.06; the
  invader's are 0.13 and 0.06. The five that failed fall about tenfold, though
  the steps grow by only 42%.
- So on this record brute force passes the first test somewhere between `1e-4`
  and `1e-5`.

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

*Measured so far: the floor's resident on long drought.* Seed 31, 108 nodes,
the tied tolerance at `1e-4` on `PLANT-98`, `lma` alone. The resident is pinned
to θ₀'s steps and compared with a run adaptive at the same `lma`
(`harness/curvature.R`).
- `J` agrees to 7.2e-5 at every point.
- From ×0.95 to ×1.1 all 48 elasticities agree within ε, the largest by 0.37ε
  (`omega` at ×1.1), the median by 0.04–0.07ε.
- At ×0.9 two exceed ε, `a_l1` by 1.23ε and `omega` by 1.14ε, and 15 of 48
  exceed ε/3. The median is 0.26ε.
- So the floor's grid holds the resident's gradients from ×0.95 to at least ×1.1
  in `lma`, but not to ×0.9, where `J` is 55% higher. The adaptive runs carry
  the first test's noise too, up to about 0.55ε on the pool's traits.

**(d) Reformulations.** Before accepting the frontier that (a)–(c) trace, ask
whether a different formulation moves it by a large factor in accuracy,
stability, runtime or simplicity:
- goal-oriented control from the sweep's adjoint (Cao and Petzold);
- a crossing treatment that makes a step smooth in where the crossing falls;
- a pool update that is non-negative at every stage;
- a change of variables for the pool;
- a node rule that follows the stand's response rather than `J`'s integrand.

The consultation is `docs/archive/oracle-consultation-grid-controller.md`, and
the reply `docs/archive/oracle-response-grid-controller.md`. Each proposal is
tested on the driver (`harness/ark_prototype.R`) or on plant before anything
is built.

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

**Where the reply leaves the design,** on long drought.
- *The kink binds in two places,* not in `J`: in a curvature taken on one grid
  (13ε for the resident between jumps), and in the resident's pool-trait
  elasticities under step 3's nudges at `1e-4` (five of 48 above ε/3).
- *Both have a fix that needs no code.* A chord over ±1e-2, less its `O(δ²)`
  term, is within 0.2ε of the curvature. At `1e-5` the nudges pass, for 42% more
  steps.
- *So the reply's remedy is worth at most that 42%* on this record: events with
  their crossing times differentiated would let the looser tolerance pass. It
  is an implementation in odelia's recording and sweep, and its cheap cut on
  the driver does not make `J` smooth. Step 3's loosest passing tolerance, on
  the bank, prices it.
- *Its other proposals buy nothing here:* the chain's margin costs 9.6% for no
  radius, span-edge nodes need more nodes than the 108 already inside ε, and
  the refusal's deletion is free but changes nothing.
- *Untested:* step control weighted by the adjoint, the pool as `asinh` (at most
  about 20% here), and a warm-started inner solve. The last is the largest
  lever left, since the inner solve is 85% of the instructions.

**The second reply,** to step 3's measurements (the consultation's follow-up;
the reply is in `docs/archive/oracle-response-grid-controller.md`).
- *The time axis is closed:* run at `1e-5`, take curvatures by the corrected
  chord, and drop the margin and the split. Elasticities below 0.1 need an
  absolute floor on ε.
- *The creation axis is a canopy.* The tall shade the short and not the reverse,
  so a member ends in the canopy or the understory, and birth order is height
  order. So births carry:
  - a first-mover layer at each creation window's opening, of width `L` (about
    0.5 on long drought, the founders' 23 days on the constant record);
  - the windows' edges;
  - a fate front where members switch from one to the other.
- *Its diagnosis:* at a spacing near `L` both parts of the node move are off
  their asymptote, so 54, 108 and 215 nodes fit no power law.
- *Its representation, a second integrator in birth date:*
  - a node at each edge of creation;
  - a first panel of about a day in each window, growing geometrically;
  - a split where neighbours' fates diverge;
  - thinning in the understory;
  - each panel's error from the sweep.
- *On the invader:* the constant record's cliff is the model's, and smooth. A run
  should report the one-sided slopes and a radius `|g|/|g′|` with the gradient.

**The second reply's tests** (`docs/measurements/creation-grid.md`).
- *On the constant record creation does not stop at the front.* It runs at 0.998
  to the first window's close at 5.20, and opens again from 11.11 to the end. So
  the reply's rule as written, ten graded panels to day 23.5 and nothing after,
  is 14% high: the last node takes all later creation, at the state of a member
  that dies.
- *With the understory represented,* ten graded members before the front put `J`
  0.53% (0.21ε) below the converged 289.274, at any spacing after it.
- *The front is under ⅛ day wide,* and its panel is first order. With nodes every
  ⅛ day around it, 102 nodes converge `J` and the resident's gradients. The
  resident's `lma` elasticity is −6.94, against −6.22 without the front and −18.4
  on uniform 108. The invader converges at 1/16 day, 150 nodes, at −186.2.
- *The invader's cliff is the model's, and smooth once the front is resolved.*
  The one-sided slopes close linearly in `u`, `(ln J′)″ ≈ −2.5e4`, a radius of
  0.0075 in `ln lma`. On the 32- and 128-way splits the local slope is the
  front's panel's, −155 and −194.6.
- *On long drought uniform is on the square law from 108 nodes.* From 108 → 215 to
  215 → 429 each part of the move falls 4.1–4.2-fold, and `J`'s ratio is 4.3. The
  54-node rung, longer than the stretches between gaps in creation, was what fit
  no power law. On wet uniform's ratio is 2.6 from 108, and the graded ladder's
  rises from 2.75 to 3.59 by 986 nodes.
- *For `J` the reply's graded grid is no better.* At a matched count its field
  part is half the uniform one's and its quadrature part a fifth. But it loses
  their cancellation, so its `J` is further out at a matched cost: −0.85% for
  1.25e6 member steps against −0.58% for 9.62e5 on long drought.
- *The first-mover layer is not set by the final heights.* On long drought
  members born before 3.1 all end at `x` 1.07–1.08, while their net
  reproduction e-folds every 0.43–0.9.
- *On long drought's graded ladder every gradient is on the square law,* the
  invader's too: 39 of its quantities resolved, with a median ratio of 3.9–4.0,
  one below zero. The 125-node grid's companion estimates its own error to 1.01
  times for the invader and 1.09 for the resident (medians, against the graded
  ladder's extrapolation).
- *On uniform nodes the resident's are, and the invader's are not.* On 33 of the
  invader's 44 resolved quantities the move from 215 to 429 reverses the move
  from 108 to 215; its `lma` goes −27.069, −26.973, −27.004. Its median error is
  0.088ε at 108 nodes, 0.25ε at 215 and 0.10ε at 429, so the companion overstates
  it 2.27-fold.
- *At a matched cost grading wins on the invader's gradients from about 250
  nodes,* 0.040ε against uniform 215's 0.25ε. It halves the resident's at about
  108 nodes, and loses on `J`.
- *Not run:* the sweep's panel estimate needs the sweep's adjoints of the field
  intermediates. The self-term needs a change in plant: `A(x_j; x_j)` is zero,
  since a node has no leaf area above its top, but TF24's shading averages light
  over the crown, which the node's own leaf area shades.

**Where the second reply leaves the design.**
- *The time axis is closed,* as the reply says.
- *On long drought the reply's grading makes the node error predictable.* On its
  graded ladder `J` and both roles' gradients follow the square law, and a
  companion at half the spacing estimates the error. On uniform nodes `J` and the
  resident do so from 108 nodes, but the invader's error changes sign with each
  halving.
- *At a matched cost uniform is ahead on `J`, and grading on the invader's
  gradients from about 250 nodes.* Wet's `J` behaves alike; its gradients on the
  graded ladder are not run.
- *Where nothing thins the canopy, the reply's structure is the rule.* With it
  the constant record converges `J` and both roles' gradients on 150 nodes, where
  no uniform count does. It needs:
  - its first window graded from a day;
  - nodes every 1/16 day around the founders' front;
  - its understory represented, at any spacing.
- *The reply would find the front during the run,* where neighbours' net
  production parts in sign. Here it came from a pilot: across it neighbours'
  mortality integrals at the end differ 70-fold (0.45 against 32). How early the
  run shows it is not measured.
- *What is open is the placing.* Each graded grid here came from a pilot's
  creation record, and the first-mover layer's width is not the final heights'.
  A rule that grades without a pilot is the reply's second integrator, not yet
  built.

**What sets the node error** (long drought; `docs/measurements/creation-grid.md`,
*What sets the node error on long drought*).
- *Two errors of opposite sign, from interpolating in birth date a profile that
  falls by e every `L`.* The interpolant of net reproduction lies above it, so a
  coarser rung's `J` is high. The coarser hats over-count the stand's water use,
  so their members' net reproduction is low
  (`docs/measurements/field-adjoint-map.md`). From uniform 108 to 215 they are −1.53% and
  +1.97% of `J`.
- *Uniform nodes put the field error at the layer's top.* The first two nodes'
  net reproduction is 2.8% and 2.3% low, against 0.7–1.1% for every member born
  before 3.5 on graded G1. The first node's grows with the crowns' sharpness:
  2.1%, 2.8% and 4.7% at `η` = 6, 12 and 24.
- *On uniform nodes the invader's elasticity moves by the difference of two such
  errors at the top,* each about 1.5ε at 108 nodes: in `lma`, +0.30 in the field
  part and −0.29 in the interpolation part from births before 0.5, a net of
  +0.10. By 215 → 429 the field part has fallen 11-fold and the interpolation
  part 4.2-fold, so the net changes sign. The graded opening shrinks them 8-
  and 40-fold.
- *What separates the ladders is how far apart the top's crowns are early in the
  race.* Where neighbouring nodes born before 0.5 differ in height by 1.85 crown
  top layers (`h/η`) or more in the first half year, the invader converges
  erratically and the companion under-reports it. From 1.15 down it is on the
  square law, and the companion reports 1.0–1.2 of the error.
- *The gap's edges are not a cause:* adding or removing them moves no quantity
  outside the small four by more than 0.05ε.

The node axis's proposal is in *After the assessment*.

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

A heuristic is scored on what a run with every gradient pays: rows first, then
the sweep's cost per row, the forward's per row and rejections, at ε on the
gradients' spread under nudges rather than on `J` (`grid-dynamics.md`, *What a
gradient run pays*). The step axis's candidates, ordered so, are that record's
*Next probes*.

**The node axis, proposed from step 4's measurements** (system-design, Tier 2:
a schedule is the seam between plant and every analysis that holds a grid, and
it can still be changed). The measurements are in
`docs/measurements/creation-grid.md`, *What sets the node error on long drought*.

*Ledger.*
- R1, accurate: every quantity within ε. On long drought every grid from 108
  nodes already is, outside the small four; the worst is 0.73ε.
- R4, predictable: a coarser companion reports the error. Measured as its
  estimate over the error, at the median; it should be near 1 and not well
  below.
- R6, shared: one grid for the local analysis at θ₀.
- R7, performant: the fewest member steps for R1 and R4 together.
- *The scarce resource is the member steps at the layer's top.* A node costs
  the steps after its birth, so the first window's nodes cost about twice the
  mean, and the error, 56–58% of `J` and grading's extra nodes are all there.

*The floor,* uniform 108 with a 215 companion, meets R1 on long drought and
fails R4: the companion reports 0.41 of the invader's error at 215 nodes and
0.33 at 429. On the constant record no uniform count converges.

*Candidates.*
- **A, pilot and bisect** [first thought]. A forward pilot, then halve each panel
  where the crown overlap at the top exceeds about 1 or the panel's share of `J`
  exceeds a bound.
  - Commits to placement read off a run at θ₀.
  - Pays for R4 on records unlike long drought.
  - Costs a pilot, about a seventh of a run with every gradient, and a monitor.
  - Wins where the structure is not known in advance: a new kind of record, the
    constant record's front.
- **B, structure and halving.** The first window graded from 0.03 by 1.11 per
  panel to a cap of 0.37, and 108 uniform's nodes after the first gap. A finer
  rung halves every panel, the coarser rung is the companion, and the reported
  value is the extrapolation.
  - Commits to a fixed structure refined only by halving.
  - Pays for R4 (1.03 at G2) and R7 (the invader's median error 0.006ε for
    3.81e6 member steps, against G3's 0.010ε for 5.26e6).
  - Costs two constants read off long drought.
  - Wins on records whose layer sits at the patch's opening.
- **C, the archived controller** (`docs/archive/scope-schedule-controller.md`):
  error maps from the sweep, placement by equidistribution, a certificate.
  - Commits to placement by adjoint-weighted error.
  - Pays for R7 where the error sits away from the opening.
  - Costs the sweep's adjoints of the field intermediates, and a grid that moves
    with θ, against R6. A spike exposes them in plant alone for +12% of a sweep
    and, built on the held run by dropping every other node, predicts the field
    part at 0.99–1.00× for `J` and 0.94–0.99× for the invader
    (`docs/measurements/field-adjoint-map.md`).
  - Wins if those maps become cheap and records differ widely.
- **D, a canopy that cannot comb.** Spread each panel's leaf area over the
  heights its members span, so that the field part at the top no longer depends
  on the spacing there.
  - Commits to a field quadrature smooth in height at any node count.
  - Pays for R4 on uniform nodes, if the comb is the cause.
  - Costs a change in plant's birth-date competition sum, more crown
    evaluations, and every reference.
  - Wins if it makes uniform nodes report the invader's error, which would
    delete B's grading.

*Winner: B,* pending the user's decision on D, which has since met B's kill
condition on long drought (below).
- A's pilot buys nothing on long drought that B's structure lacks; A stays as
  the check.
- C's maps could not be read off plant's sweep when B was picked, and its grid
  would move within a local analysis. The spike since reads them; whether that
  moves the pick is open.
- D can delete B's grading but changes plant and every reference. When B was
  picked the comb as the cause was inferred, not isolated; D has run since
  (below).

*The commitment:* a schedule is a fixed structure refined only by halving every
panel. Kept true by the harness: each rung is `graded_times.R`'s `halve()` of
the rung below, so a finer rung cannot be placed any other way.

*Kill question.* The assumption whose falsity makes B unnecessary is that
uniform nodes cannot report the invader's error. On long drought it holds:
their companions report 0.41 and 0.33 of it. B survives unless D makes them
honest, which on long drought it has (below).

*Consistency.* B's cap is half the spacing that broke and half long drought's
`L`. On wet `L` is 0.56, and the graded `J` reaches the square law only past
494 nodes, so B's constants may be long drought's. The check runs on every
record.

*Deletion.*
- The gap's edge nodes go: they move no quantity by 0.05ε.
- Grading each later window's opening is not needed on long drought, where the
  second window carries 1.2% of `J`.
- A front cluster stays, only for canopies that are never thinned.

*What this settles:* no edge detection in the run, no placement code in plant,
no rebuild within a local analysis.

*What this makes hard:* a record whose layer is narrower than long drought's,
or a strategy with sharper crowns, since the opening scales with `h/η`. Coping:
one rung finer, and A's monitor on a pilot.

*Kill condition:* D making uniform nodes honest for the invader, which hands the
node axis to uniform halving; or a record whose graded rungs give no ratio near
4, which hands it to A.

**D, run** (`docs/measurements/canopy-spread.md`).
- *The comb is the cause,* isolated on the invader's `lma`. Spreading each panel
  takes the field part of 108 → 215 from +0.380 to −0.034, the top's from
  +0.301 to −0.015, and leaves the interpolation part unchanged.
- *Spread uniform nodes report their error on long drought,* which meets B's kill
  condition there. Over all 49 quantities at seed 31 the median ratios are
  3.6–3.9 and the companions 0.93–1.09; the invader's `lma` gives 4.11 and 3.89
  at seeds 101 and 103.
- *What it leaves open:*
  - single spread rungs are coarse (u108 0.7–3ε off), so the rule reports the
    two-rung extrapolation;
  - wet's and dry's spread ladders are not run to u429;
  - the constant record still needs its front nodes;
  - the resident's sweep ran 1.7–3.4× slower spread, being profiled. The
    strategy reply reads it as a sweep bound by its tape, whose field assembly
    grew sixteenfold, and proposes the panel's kernel integrated over its
    height interval, with its adjoint written by hand, at the lumped tape's
    size;
  - it changes plant's birth-date competition sum and every reference.
- *At matched error,* for the invader's `lma`, each with a companion that
  reports its error: spread uniform u108 + u215 costs 2.93e6 member-steps for
  0.006ε, lumped graded G1 + G2 3.81e6 for 0.002ε, and G2 alone 2.56e6 for
  0.044ε.
- Moving the node axis to D changes plant, so it is the user's decision.

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
- `run_record.R` runs one stand and its invader on one record, with their
  gradients, and saves everything a later analysis reads. `spot_check.R`
  checks a directory of those runs against `docs/measurements/eps.csv`, and
  `error_structure.R` reads how their errors scale and where the node error
  lives. `first_panel.R` splits a record's first node spacing, or takes a
  schedule, and reports `J`, the surviving founders, the invader's gradient and
  its one-sided slopes. `graded_times.R` writes the schedules of step 4's second
  tests, and `node_parts.R` splits `J`'s move between nested schedules into its
  field and quadrature parts.
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
- *On pulsed records the soil has no fast mode to separate:* drainage goes as
  `θ^16.14`, so after rain a layer's relaxation rate is about one over the time
  since the rain, and held to the norm's tolerance an implicit soil keeps its
  steps. ARK's longer steps there were inaccurate, and on one its embedded
  estimate put the top layer's error at a fifteenth of its size. Under constant
  rain the soil is stiff and the implicit soil pays (`grid-dynamics.md` §7).
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
