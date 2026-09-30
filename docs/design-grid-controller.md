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
fixed. At θ′ = θ the invader's `J′` equals `J` to 1e-12, and its gradient is
the selection gradient.

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
it. (b) is a new issue on aornugent/plant, on a branch stacked on `PLANT-97`,
which owns the pool.

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

The consultation is `docs/oracle-consultation-grid-controller.md`. Each
proposal is tested on the driver (`harness/ark_prototype.R`) before anything
is built, as the last consultation's were.

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
