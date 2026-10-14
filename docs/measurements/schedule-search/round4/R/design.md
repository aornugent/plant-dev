# Design: the soil's substeps land on the rain's knots

Agent R, round 4. Acts on G's finding (`../G/notes.md` §3–§4): every active
rainfall knot ends a main step, 46–56% of rows on rain-frequent records, and the
knots cannot simply go, because a step across knots samples the rain only at its
six stages and its error estimate is blind to what it misses.

**Answer: yes, a small change (about 45 lines of library code), and it extends
the subsystem rather than adding a feature.** Measured on a09's committed
schedules at `1e-4`, it takes rows −21% (dry) and −26% (long-wet), and sweep CPU
−33% and −35%. Every quantity stays within 0.16ε of the knot-stopping base and
the rain's quadrature stays exact (`notes.md`). The soil's substeps already land on a fixed list of stops inside the
step (the stage and sample fractions). The rain's knots join that list. Where a
step does not substep the soil, it ends at the next knot, as the caller's pulses
make it do today. Both halves need one fact the System does not yet give odelia:
where the subsystem's forcing has knots. Nothing else changes: the record already
holds where each substep ends, so replays and the sweep take the knots as
recorded.

## How rain enters today (from the code)

- The rain is a monotone (limited) Hermite cubic through daily values
  (`odelia/drivers.hpp`, `monotone_slopes`), floored at zero. Across a pair of
  zero days it is identically zero.
- It is read in one place, `TF24Environment::layer_rates(time, …)`: the top
  layer's inflow is `rain(t) · max(0, 1 − a_infil (θ₀/θsat)^b_infil)`. Its two
  diagnostic sums (`sum_rainfall`, `sum_infiltration`) read it too. No plant
  rate reads the rain; the plants read the soil's potentials.
- The harness hands every active knot to the run as a zero-depth pulse
  (`harness/long_drought.R` `active_knots()`, `adj_run.R`), so every knot is a
  target of `advance_adaptive` and every step lies inside one cubic span.

What the plants' stages read of the soil inside a main step:

| step | stage i reads the soil from | carries the rain to stage i? |
|---|---|---|
| substepped (uptake share < 0.1) | the predictor's substeps at fraction `ah[i]` (`take_substepped_step`) | yes, as far as the substeps resolve it |
| coupled (share ≥ 0.1, or SHARE off) | Cash–Karp's stage, `y0 + h Σ a_ij k_j` | only through earlier stages' rain samples: the aliasing |

So on a substepped step the stages already read a soil that carries the rain,
not a stale one. What is missing is that the substeps are chosen by an embedded
estimate (`choose_substeps`, `1e-9`) whose first try reaches the first stop at
0.2 of the step: across a knot it has the same blind spot as the main step,
smaller only because substeps are shorter. Landing them on the knots puts every
substep inside one span, where Cash–Karp's quadrature of a cubic is exact.

**The span integral cannot be taken exactly** (the brief's second option): the
inflow is the rain times a share that reads θ₀, so the forcing the soil
integrates is not a function of time alone. Inside one span the substeps
integrate it to `1e-9`; that is the exactness available.

## Triage: 2

One member added to an odelia concept (`HasSubsystem`), one accessor on odelia's
drivers, and the main step's stop rule. Recorded programs keep their format.

## Requirements ledger

- R1 (*Performant*): the knot stops are 47–56% of rows on dry, long-wet, long
  drought, ld-102/105, dry-p50 (26% episodic); the change must take rows off
  them. Of the knot-ending steps in a09's committed runs, those that substep the
  soil hold 59.6% of knot rows on dry and 82.4% on long-wet; on long drought
  (run with SHARE off) none (`knot_split.R`).
- R2 (*Accurate*, *Stable* 3): the rain each run integrates stays exact: G's gate,
  Σ|RK5 − exact| over the intervals that integrate the rain, near 0 (base 1e-4
  over ages 25–40; aliasing G1 2.41 of 5.52).
- R3 (*Accurate*): every quantity within ε/3 of the knot-stopping base.
- R4 (*Stable* 2, the sweep): a replay and the sweep take a step's substeps as
  recorded, so the record must hold every stop the forward took.
- R5 (*never fails*): a knot at a stage fraction, or a step of one knot span,
  must not throw.
- R6: with the knots still passed as pulses, every run is bit for bit (the knots
  then lie at step ends, so nothing lands inside a step).

Scarce resource: rows. A row costs 1.11e-4 s forward and 3.56e-4 s in the sweep
(G §1), and knot stops set half of them; the soil's substeps cost under 1% of a
profile (`design-soil-alone.md` G6), so stops added to them are nearly free.

## The floor

Keep the knots as step targets. Fails R1: 47–56% of rows stay set by the record.

## Candidates

- **A [first thought], move 3 (move the boundary): the knots move from the
  caller's targets into the step.** The System names its subsystem's forcing
  knots in an interval. `choose_substeps` lands on them besides the stage and
  sample fractions; a step that does not substep the subsystem ends at the next
  one. *Pays for* R1 on the substepped share of knot stops, R2 by structure,
  R4 for free (the ends are already recorded). *Costs:* one concept member, one
  drivers accessor, about 30 lines. *Wins when* most knot stops fall on
  substepped steps: dry 60%, long-wet 82% of knot rows.
- **B, move 1 (weaken exactness): drop the knots and take the span integral of
  the rain analytically.** Refuted: the inflow is rain × share(θ₀), so there is
  no span integral of the forcing alone; and the coupled path would still alias
  through its stages. *Wins when* the infiltration is independent of the soil
  (`a_infil = 0`), and only then for the substepped soil.
- **C, move 6 (one mechanism): any step whose span holds a knot substeps the
  soil, whatever the share.** Removes every knot stop, coupled ones too. *Costs:*
  the decision then depends on h, which retries change; on strongly coupled
  steps the coupling error, of lower order than Cash–Karp's, binds
  (`design-soil-alone.md`, "at `1e-7` … binds most steps"), so the saving there
  is unmeasured; and long drought runs with SHARE off because of its gradient
  blow-ups. *Wins when* coupled knot stops dominate: long drought (100% of its
  knot rows today), and dry's remaining 40%.

**Winner: A.** B is refuted by the rate's form. C reaches the coupled 40% on dry
but changes the share's decision, which A keeps; it is the retrofit if A's
measurement shows the coupled stops are what remains (kill condition below).

## The commitment

The rain's knots are stops of the integration that holds the soil: of the
substeps where the step substeps the soil, of the step where it does not. So no
interval that integrates the rain spans a knot.

Kept true by: the stops come from the System's `subsystem_knots(from, to)` inside
odelia's step, not from the caller, and the substeps' list is the record a
replay and the sweep take.

## Kill question

*Assumption:* a large share of knot stops fall on steps that substep the soil.
On dry 59.6% of knot rows (33.6% of all rows), on long-wet 82.4% (39.3%): it
holds there. It is false on long drought as run (SHARE off: 0%) and weaker on
episodic (knots 28% of rows). The design survives for the records that substep
the soil; on long drought it changes nothing.

## What survives deletion

- `HasSubsystem::subsystem_knots(from, to)`: R1, R2. Without it odelia cannot
  stop at a knot the caller no longer passes.
- `drivers::Function::knots(from, to)`: R2. The knots are the series' control
  points where the cubic changes; only the series holds them.
- The stop rule for a coupled step: R2 (the coupled share would alias).
- *Not added:* a record field (the ends are recorded), a Control value (R6
  holds with the pulses kept; the caller drops the pulses to opt in).

## What this settles

- No replay or sweep code changes: the knots are among each row's `ends`.
- Walks are untouched: an invader's evaluations load the stand's field,
  predicted soil included.
- The caller no longer has to know which knots matter, and a caller who passes
  none (agent E's silent 7.6ε) gets the rain integrated exactly anyway.

## What this makes hard

- *Steps whose soil is coupled still stop at every knot* (40% of knot rows on
  dry, all on long drought). Cope: candidate C.
- *A smooth series given densely pays for its knots.* Every control point of a
  variable driver is a knot unless it lies inside a run of equal values, so a
  seasonal sine given at 601 points over 3 years (plant's split and substep
  fixtures) stops each coupled step every 1.8 days, where nothing is missed.
  Cope: the System may report only the knots that matter. For TF24's daily rain
  that is all of them, so the rule here is the harness's own.
- *A subsystem that passes its forcing straight through* puts a bump in what the
  rest reads, which the rest's stages miss however exactly the subsystem is
  integrated: the toy's stiff store (K = 1e4) ends 4.2e-3 from the reference
  with or without this change, against 1.2e-4 stopped at the knots. The change
  fixes the rain's integral; whether TF24's soil holds rain as a rise (as the
  slow store does, 2.0e-3 → 9.7e-7) is what the dry run tests.
- *The two diagnostic sums* (`sum_rainfall`, `sum_infiltration`) stay on the main
  step, so they alias on steps that span knots. They feed nothing; they join the
  error norm at the accumulators' factor.
- *The split's dense output of the soil* is a quartic through the predictor's
  five samples; across a rain onset inside the step it fits a ramp. G found the
  splits were not the blind spot with knots dropped (G4/G5), but this is the
  first setting where steps span onsets with substeps on. Measured below.
- *A TF24 run on a variable record without pulses changes:* its coupled steps
  now end at knots and its substeps land on them. Today plant adds no knot stop
  itself, so such a run is silently wrong: agent E measured J 1.191 → 0.984 on
  dry at `1e-4` (7.6ε in `ln J`, up to 19ε in elasticities), falling only as
  tol^0.24 (`../E/notes.md`). With this change exact rain is a property of the
  soil subsystem, not of the caller; it moves every such run's numbers, toward
  the knot-stopping answer.

## Kill condition

- Rows fall by less than 10% on dry, or a quantity moves more than ε/3 from the
  base, or the gate (Σ|RK5 − exact| over the rain's integration intervals) is not
  near the base's. Then hand off to C or keep the floor.
- If the coupled knot stops are most of what remains, C is the next search.

## The design

odelia (`RAIN-SUBSTEPS` on f19f7de):
1. `drivers::Function::knots(from, to)` and `Drivers::knots(name, from, to)`:
   control points in (from, to), less those inside a run of equal values, where
   the cubic is flat across. A constant has none.
2. `HasSubsystem` gains `subsystem_knots(from, to) → std::vector<double>`.
3. `choose_substeps` stops at the knots' fractions of the step, merged with the
   stage and sample fractions.
4. `SolverInternal::step`: a step that does not substep the subsystem ends at
   the first knot in its span, as it ends at `time_max` (its size is not carried
   on).

plant (`RAIN-SUBSTEPS` on fa9afe76):
1. `TF24Environment::rainfall_knots(from, to)`; `HasSoil` requires it.
2. `Patch::subsystem_knots(from, to)` returns it.

Tests (failing first): odelia's store toy under a pulse train of inflow, whose
substepped steps span knots, against a reference that stops at every knot; and
that a coupled run ends a step on every knot. plant: a TF24 stand on a pulsed
record without knot pulses against the same stand with them.

## As built and measured

- odelia `RAIN-SUBSTEPS` (on f19f7de): `cfee88a` the failing tests (store toy
  under pulses of inflow), `c7a53a4` the change: `drivers.hpp` +27,
  `ode_interface.hpp` +3, `ode_substeps.hpp` +13, `ode_solver_internal.hpp` +16.
- plant `RAIN-SUBSTEPS` (on fa9afe76): `d4c414ee` the failing test (a two-year
  stand on a daily record), `6ac10ce6` the change: `tf24_environment.h` +5,
  `patch.h` +5.
- R0: with the knots still passed, dry is bit for bit with lib19 and lib18.

| | dry | long-wet |
|---|---|---|
| rows | −21.2% | −26.3% |
| steps | −16.0% | −20.5% |
| sweep CPU | −32.5% | −35.5% |
| forward CPU | −10.9% | −17.6% |
| knot-ending steps | 2955 → 1056 (coupled) | 2955 → 484 (coupled) |
| largest move | 0.156ε (TF24_cost_scale) | 0.011ε |
| rms move, `ln J` | 0.046ε, +0.007ε | 0.004ε, +0.002ε |
| Σ\|RK5 − exact\| over the rain's intervals | 1.06e-11 (base 1.06e-11) | 1.27e-10 (base 1.29e-10) |

The kill conditions do not fire. Two warnings stand:
- *The stiff-store limit* (above) did not show in TF24 at these settings.
- *The fixture's cost at matched error:* a young two-year stand needed more
  steps than the knot-stopping run at `1e-5` and `1e-6` (617 vs 457, 912 vs 674),
  though its error fell with the tolerance. Recheck at `3e-4` and on episodic
  before adopting.

*Suites* (`notes.md`): two plant tests fail because of the change. The
gradient ladder's seasonal reference and `test-scm.R`'s substepped share both
run a densely given sine, whose every control point now ends a coupled step.
That is the dense-series cost above, now measured. The knot rule needs
narrowing (rain onsets and ends), or the coupled stops need an opt-in, before
this lands.
